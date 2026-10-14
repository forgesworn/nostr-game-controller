import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {finalizeEvent,verifyEvent} from 'nostr-tools';
import { isControllerSpec,resolveControllerLayout,defaultControllerLayout,controllerProfileFromEvent,CONTROLLER_PROFILE_KIND_DRAFT,formatPairingCode,normalizePairingCode } from './dist/index.js';
const fixture = JSON.parse(readFileSync(new URL('./fixtures/controller-profile-fixtures.json',import.meta.url)));
test('shared profiles validate, retain every action, and fall back on collisions',()=> {
  for(const vector of fixture.cases) {
    assert.equal(isControllerSpec(vector.spec),vector.valid,vector.name);
    if(vector.valid && vector.spec.layout) for(const [w,h] of fixture.viewports) {
      const controls = resolveControllerLayout(vector.spec,w,h);
      if(vector.fallbackPortrait && w <= h) assert.equal(controls,null,vector.name);
      else { assert.ok(controls,`${vector.name} ${w}x${h}`); assert.deepEqual(Object.keys(controls).sort(),Object.keys(vector.spec.slots).sort()); }
    }
  }
  const valid = structuredClone(fixture.cases[1].spec); valid.extra = 'x'.repeat(49152); assert.equal(isControllerSpec(valid),false);
  valid.extra = valid; assert.equal(isControllerSpec(valid),false);
});
test('default browser geometry matches every native fixture',()=> {
  const vectors = JSON.parse(readFileSync(new URL('./fixtures/thumb-layout-fixtures.json',import.meta.url))).cases;
  for(const v of vectors) {
    const map = defaultControllerLayout(v.width,v.height,v.keys); assert.deepEqual(Object.keys(map).sort(),v.keys.slice().sort(),v.name);
    for(const p of Object.values(map)) { assert.ok(p.zone.x >= -.001 && p.zone.y >= -.001 && p.zone.x+p.zone.width <= v.width+.001 && p.zone.y+p.zone.height <= v.height+.001,v.name); assert.ok(p.zone.width >= 48 && p.zone.height >= 48,v.name); }
  }
});
test('Nostr profiles require the expected publisher, game, protocol and valid signature',()=> {
  const event = {id:'a'.repeat(64),pubkey:'b'.repeat(64),sig:'c'.repeat(128),created_at:1,kind:CONTROLLER_PROFILE_KIND_DRAFT,tags:[['d','rocket-rally'],['protocol','nostr-game-controller','1']],content:JSON.stringify(fixture.cases[1].spec)};
  assert.deepEqual(controllerProfileFromEvent(event,event.pubkey,'rocket-rally',()=>true),fixture.cases[1].spec);
  assert.equal(controllerProfileFromEvent(event,'d'.repeat(64),'rocket-rally',()=>true),null);
  assert.equal(controllerProfileFromEvent(event,event.pubkey,'different-game',()=>true),null);
  assert.equal(controllerProfileFromEvent(event,event.pubkey,'rocket-rally',()=>false),null);
  assert.equal(controllerProfileFromEvent(event,event.pubkey,'rocket-rally',async()=>true),null);
  assert.equal(controllerProfileFromEvent({...event,tags:[...event.tags,['d','rocket-rally']]},event.pubkey,'rocket-rally',()=>true),null);
  assert.equal(controllerProfileFromEvent({...event,content:'{}'},event.pubkey,'rocket-rally',()=>true),null);
});
test('readable codes leave protocol IDs and URLs alone',()=> {
  assert.equal(formatPairingCode('ABCDEF'),'ABC DEF'); assert.equal(normalizePairingCode('abc-def'),'ABCDEF');
  assert.equal(formatPairingCode('custom-id'),'custom-id');
});

test('NIP-01 signature verification rejects modified controller content',()=> {
  const signed = finalizeEvent({created_at:1,kind:CONTROLLER_PROFILE_KIND_DRAFT,tags:[['d','rocket-rally'],['protocol','nostr-game-controller','1']],content:JSON.stringify(fixture.cases[1].spec)},new Uint8Array(32).fill(7));
  assert.ok(controllerProfileFromEvent(signed,signed.pubkey,'rocket-rally',verifyEvent));
  const modified = JSON.parse(JSON.stringify(signed)); modified.content = JSON.stringify(fixture.cases[0].spec);
  assert.equal(controllerProfileFromEvent(modified,signed.pubkey,'rocket-rally',verifyEvent),null);
});

test('the virtual phone preserves physical HAT directions, buttons and other pads',async()=> {
  const {applyPhoneGamepad,neutralPhone}=await import('./dist/browser.js');
  const descriptor=Object.getOwnPropertyDescriptor(globalThis,'navigator'),priorWindow=globalThis.window;
  const physical={id:'Generic X-Box pad',index:0,mapping:'',axes:[0,0,0,0,0,0,-1,1],buttons:Array.from({length:17},(_,i)=>({pressed:i===3,touched:i===3,value:i===3 ? 1 : 0})),vibrationActuator:{type:'dual-rumble'}};
  const second={id:'Other physical pad',index:1};const original=()=>[physical,second];
  Object.defineProperty(globalThis,'navigator',{configurable:true,value:{getGamepads:original}});
  globalThis.window={dispatchEvent:()=>true};
  try {
    applyPhoneGamepad({connected:true,axes:[.6,0,0,0],buttons:[true,...Array(16).fill(false)]});
    const [pad,other]=navigator.getGamepads();assert.equal(pad.mapping,'standard');assert.equal(pad.axes[0],.6);
    for(const i of [0,3,13,14])assert.equal(pad.buttons[i].pressed,true,String(i));assert.equal(pad.buttons[12].pressed,false);assert.equal(pad.buttons[15].pressed,false);
    assert.equal(pad.vibrationActuator,physical.vibrationActuator);assert.equal(other,second);
    applyPhoneGamepad(neutralPhone());assert.equal(navigator.getGamepads()[0],physical);
  } finally {if(descriptor)Object.defineProperty(globalThis,'navigator',descriptor);else delete globalThis.navigator;globalThis.window=priorWindow;}
});

test('a Gamestr game definition owns its controller profile and ordinary game metadata',async()=> {
  const {controllerProfileFromGameDefinition}=await import('./dist/index.js');
  const profile=fixture.cases[1].spec,game={manifestVersion:2,gameId:'rocket-rally',name:'Rocket Rally',url:'https://play.example.com/',players:{min:1,max:4},scoreKind:30762,controller:{adapter:'native',phoneProtocol:'gamestr-controller-v1',profile}};
  assert.deepEqual(controllerProfileFromGameDefinition(game),profile);
  for(const patch of [{manifestVersion:1},{gameId:'../escape'},{url:'http://play.example.com/'},{url:'https://user:secret@play.example.com/'},{controller:{...game.controller,profile:{version:1,slots:{}}}},{extra:'x'.repeat(65536)}])assert.equal(controllerProfileFromGameDefinition({...game,...patch}),null);
  assert.equal(controllerProfileFromGameDefinition({...game,controller:{...game.controller,phoneProtocol:undefined}}),null);
});

test('NIP-89 discovery binds the controller to the complete signed game definition',async()=> {
  const {controllerProfileFromGameDefinitionEvent,GAME_DEFINITION_KIND}=await import('./dist/index.js');
  const profile=fixture.cases[1].spec,game={manifestVersion:2,gameId:'rocket-rally',name:'Rocket Rally',url:'https://play.example.com/',controller:{adapter:'native',phoneProtocol:'gamestr-controller-v1',profile}};
  const signed=finalizeEvent({created_at:1,kind:GAME_DEFINITION_KIND,tags:[['d','gamestr-game:rocket-rally'],['t','gamestr-game'],['k','30762'],['web',game.url]],content:JSON.stringify({name:game.name,website:game.url,gamestr_manifest:game})},new Uint8Array(32).fill(8));
  assert.deepEqual(controllerProfileFromGameDefinitionEvent(signed,signed.pubkey,game.gameId,verifyEvent),profile);
  assert.equal(controllerProfileFromGameDefinitionEvent(signed,'a'.repeat(64),game.gameId,verifyEvent),null);
  assert.equal(controllerProfileFromGameDefinitionEvent(signed,signed.pubkey,'different-game',verifyEvent),null);
  assert.equal(controllerProfileFromGameDefinitionEvent(signed,signed.pubkey,game.gameId,async()=>true),null);
  const changed=JSON.parse(JSON.stringify(signed));const content=JSON.parse(changed.content);content.gamestr_manifest.controller.profile=fixture.cases[0].spec;changed.content=JSON.stringify(content);
  assert.equal(controllerProfileFromGameDefinitionEvent(changed,signed.pubkey,game.gameId,verifyEvent),null);
  for(const patch of [{tags:[...signed.tags,['d','gamestr-game:rocket-rally']]},{tags:signed.tags.filter(t=>t[0]!=='web')},{kind:30393}])assert.equal(controllerProfileFromGameDefinitionEvent({...signed,...patch},signed.pubkey,game.gameId,()=>true),null);
  assert.equal(controllerProfileFromGameDefinitionEvent({...signed,content:JSON.stringify({gamestr_manifest:{...game,gameId:'different-game'}})},signed.pubkey,game.gameId,()=>true),null);
  assert.equal(controllerProfileFromGameDefinitionEvent({...signed,content:JSON.stringify({website:'https://different.example/',gamestr_manifest:game})},signed.pubkey,game.gameId,()=>true),null);
  assert.deepEqual(controllerProfileFromGameDefinitionEvent(signed,signed.pubkey,game.gameId,event=>{event.content='{}';return true}),profile);
});
