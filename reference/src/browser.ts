import {isControllerSpec} from './controller-profile.js';
import type {ControllerSpec} from './index.js';
export interface PhoneSnapshot { connected: boolean; axes: number[]; buttons: boolean[] }
export const neutralPhone = (): PhoneSnapshot => ({connected:false,axes:[0,0,0,0],buttons:Array(17).fill(false)})
export function parsePhoneSnapshot(value: unknown): PhoneSnapshot | null {
  if(!value || typeof value !== 'object') return null
  const v = value as PhoneSnapshot
  if(Object.keys(v).sort().join(',') !== 'axes,buttons,connected' || typeof v.connected !== 'boolean'
    || !Array.isArray(v.axes) || v.axes.length !== 4 || !v.axes.every(x=>typeof x === 'number' && Number.isFinite(x) && Math.abs(x)<=1)
    || !Array.isArray(v.buttons) || v.buttons.length !== 17 || !v.buttons.every(x=>typeof x === 'boolean')) return null
  return v.connected ? {connected:true,axes:[...v.axes],buttons:[...v.buttons]} : neutralPhone()
}
/** Self-contained because Electron serialises this function into the game world. */
export function applyPhoneGamepad(snapshot: PhoneSnapshot): void {
  const root = window as Window & {__gamestrPhonePad?: {state:PhoneSnapshot; original:()=> (Gamepad|null)[]; installed:()=> (Gamepad|null)[]}}
  if(!root.__gamestrPhonePad) {
    if(!snapshot.connected) return
    const original = navigator.getGamepads?.bind(navigator) ?? (()=>[])
    const holder = {state:snapshot,original,installed:()=>[] as (Gamepad|null)[]}
    holder.installed = () => {
      const pads = Array.from(holder.original()), s = holder.state
      if(!s.connected) return pads
      const physical = pads[0]
      const phone = {id:'Gamestr Joystick phone',index:0,connected:true,mapping:'standard',timestamp:performance.now(),axes:s.axes.map((v,i)=>Math.abs(v)>.01 ? v : physical?.axes[i] ?? 0),buttons:s.buttons.map((v,i)=>({pressed:v || !!physical?.buttons[i]?.pressed,touched:v || !!physical?.buttons[i]?.touched,value:v ? 1 : physical?.buttons[i]?.value ?? 0})),vibrationActuator:null} as unknown as Gamepad
      pads[0] = phone; return pads
    }
    try {Object.defineProperty(navigator,'getGamepads',{configurable:true,value:holder.installed})} catch {return}
    root.__gamestrPhonePad = holder
    const event = new Event('gamepadconnected'); Object.defineProperty(event,'gamepad',{value:holder.installed()[0]}); window.dispatchEvent(event)
  }
  const holder = root.__gamestrPhonePad!
  holder.state = snapshot
  if(!snapshot.connected) {
    // Keep the existing wrapper neutral rather than replacing another library's hook.
    const event = new Event('gamepaddisconnected'); Object.defineProperty(event,'gamepad',{value:{id:'Gamestr Joystick phone',index:0,connected:false}}); window.dispatchEvent(event)
    if(navigator.getGamepads === holder.installed) Object.defineProperty(navigator,'getGamepads',{configurable:true,value:holder.original})
    delete root.__gamestrPhonePad
  }
}

export const ARCADE_CONTROLLER_PROTOCOL = 'gamestr-controller-v1';
/** Publisher-side opt-in. This channel carries input/profile data only. */
export function installArcadeGameController(options: {allowedOrigins: string[]; profile: ControllerSpec}): () => void {
  if(!isControllerSpec(options.profile)) throw Error('Invalid controller profile');
  const allowed = options.allowedOrigins.filter(origin=> {
    try {const u=new URL(origin);return u.origin === origin && (u.protocol==='https:' || u.protocol==='http:' && ['localhost','127.0.0.1'].includes(u.hostname));} catch{return false;}
  });
  let port:MessagePort|null=null,lastInput=0,disposed=false;
  const reset=()=> {applyPhoneGamepad(neutralPhone());port?.close();port=null;};
  let announced = false;
  const ready=()=> {
    // Electron's isolated preload can accept the same declarative definition.
    if(!announced) {announced = true;window.postMessage({protocol:'gamestr-controller-profile-v1',spec:options.profile},location.origin);}
    if(!port && window.opener) for(const origin of allowed) window.opener.postMessage({protocol:ARCADE_CONTROLLER_PROTOCOL,type:'ready',spec:options.profile},origin);
  };
  const onConnect=(event:MessageEvent)=> {
    if(disposed || event.source !== window.opener || !allowed.includes(event.origin) || event.data?.protocol !== ARCADE_CONTROLLER_PROTOCOL || event.data?.type !== 'connect' || event.ports.length !== 1) return;
    if(port) {event.ports[0]!.close();return;}
    port=event.ports[0]!;lastInput=performance.now();
    port.onmessage=message=> {
      if(message.data?.protocol !== ARCADE_CONTROLLER_PROTOCOL || message.data?.type !== 'input') return;
      const snapshot=parsePhoneSnapshot(message.data.state);if(!snapshot)return;
      lastInput=performance.now();applyPhoneGamepad(snapshot);
    };
    port.start();
  };
  window.addEventListener('message',onConnect);
  const started=performance.now();
  const timer=window.setInterval(()=> {if(port && performance.now()-lastInput>750)reset();if(performance.now()-started<15000)ready();},100);
  const dispose=()=> {if(disposed)return;disposed=true;window.clearInterval(timer);window.removeEventListener('message',onConnect);window.removeEventListener('pagehide',dispose);reset();};
  window.addEventListener('pagehide',dispose);ready();return dispose;
}
