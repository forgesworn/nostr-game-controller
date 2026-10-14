import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const {finalizeEvent,verifyEvent} = createRequire(import.meta.url)('nostr-tools');
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
