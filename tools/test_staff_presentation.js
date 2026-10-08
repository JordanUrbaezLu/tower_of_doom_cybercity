// Execute the actual GSC routing and inventory paths under a small native mock.
// This proves state/ammo ownership; it cannot prove native model/clip playback.
const fs=require('fs'), vm=require('vm'), assert=require('assert/strict');
const classes=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_classes.gsc','utf8');
const upgrades=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc','utf8');
const pap=fs.readFileSync('scripts/zm/zm_cwpap.gsc','utf8');
function body(src,name) {
  src=src.replace(/\/\/[^\n]*/g,'');
  const at=src.indexOf('function '+name+'(');assert(at>=0,name);
  const a=src.indexOf('{',at);let z=a+1,depth=1;
  while(depth){if(src[z]==='{')depth++;if(src[z]==='}')depth--;z++;}
  return src.slice(a+1,z-1);
}
function translate(s) {
  return s.replace(/foreach\s*\(\s*(\w+)\s+in\s+([^\n]+)\s*\)/g,'for (const $1 of $2)')
    .replace(/\b(self|player)\s+thread\s+(?:\w+::)?(\w+)\(/g,'$1.$2(')
    .replace(/\b(self|player)\s+(?:\w+::)?(\w+)\(/g,'$1.$2(')
    .replace(/level\s+(\w+)\(/g,'level.$1(').replace(/tod_classes::/g,'')
    .replace(/\bwait\s*\(\s*([^;]+)\s*\);/g,'yield $1;')
    .replace(/\bwait\s+([^;]+);/g,'yield $1;')
    .replace(/\bcamo_stamp\(/g,'self.camo_stamp(')
    .replace(/\bpap_camo_options\(/g,'self.pap_camo_options(');
}
const names=['lightning','fire','ice'], roots=new Map(), variants=new Map();
for(const e of names)for(const q of [0,1]) {
  const w={name:'tod_staff_'+e+'_q'+q,attachments:[],clipSize:1000,maxAmmo:1000};w.rootWeapon=w;
  roots.set(w.name,w);variants.set(w.name,{...w,attachments:['gmod6']});
}
for(const q of [0,1])for(const d of [0,1]) {
 const w={name:'tod_staff_ice_q'+q+'d'+d,attachments:[],clipSize:1000,maxAmmo:1000};w.rootWeapon=w;
 roots.set(w.name,w);variants.set(w.name,{...w,attachments:['gmod6']});
}
let ctx={isdefined:v=>v!==undefined&&v!==null,IS_TRUE:v=>v===true,IsSubStr:(s,k)=>s.includes(k),array:(...x)=>x,
 level:{weaponNone:null,endon:()=>{},use_papknuckles:false},TOD_PAP_TIER_HOLD_SECS:.5,
 GetWeapon:(n,a)=>ctx.missing?roots.get(n):(a?.length?variants:roots).get(n),
 pap_tier:(p,w)=>p.tiers[names.find(e=>w.name.includes(e))]||0,
 staff_presentation_log:()=>{},weapon_or_zm:n=>roots.get(n),
 gun:()=>({}),gun_for_weapon:(p,w)=>w&&w.name.startsWith('tod_staff_')?{stem:w.rootWeapon.name.replace(/_q\d+(?:d\d+)?$/,''),up_suffix:''}:undefined,
 variant_name:(g,up,s)=>g.stem+s};
vm.createContext(ctx);
for(const [name,args,locals,src,generator] of [
 ['pap_staff_id','weapon','',classes,false],['staff_is_packed','weapon','',classes,false],
 ['staff_presentation','player,weapon','root,packed',classes,false],
 ['give_camo_weapon','weapon','first_raise,staff',classes,false],
 ['camo_regive','weapon,raise,initial_raise','clip,stock',classes,false],
 ['reconcile_twin','','g,weapons,is_up,suffix,want_name,want,plain,crossing',upgrades,false],
 ['swap_primary','w,want,fresh','clip,stock,cur,held,same_root,i,new_clip,new_stock',upgrades,true],
 ['giveWeaponRepacked','weapon','hands',pap,true]]) {
 const declaration=locals?'let '+locals+';':'';
 vm.runInContext('function'+(generator?'*':'')+' '+name+'('+args+'){'+declaration+translate(body(src,name))+'}',ctx);
}
function drain(gen) {let count=0;for(const delay of gen){assert(++count<60);assert(delay>=0);} }
function player() {
 const p={tiers:{},items:new Map(),current:null,events:[],q:0,down:false};
 Object.assign(p,{
  endon:()=>{},notify:()=>{},GetCurrentWeapon:()=>p.current,
  GetWeaponsListPrimaries:()=>[...p.items.keys()],HasWeapon:w=>p.items.has(w),
  GetWeaponAmmoClip:w=>p.items.get(w).clip,GetWeaponAmmoStock:w=>p.items.get(w).stock,
  GiveWeapon:w=>{for(const old of p.items.keys())if(old.rootWeapon===w.rootWeapon)p.items.delete(old);p.items.set(w,{clip:1000,stock:1000});p.events.push(['give',w]);},
  // Model the risk deliberately: native take by the shared root can remove
  // either attachment set. A take-after-give regression loses the packed gun.
  TakeWeapon:w=>{for(const old of p.items.keys())if(old.rootWeapon===w.rootWeapon)p.items.delete(old);if(p.current?.rootWeapon===w.rootWeapon)p.current=null;p.events.push(['take',w]);},
  SetWeaponAmmoClip:(w,n)=>{assert(p.items.has(w));p.items.get(w).clip=n;},
  SetWeaponAmmoStock:(w,n)=>{assert(p.items.has(w));p.items.get(w).stock=n;},
  GiveStartAmmo:w=>{assert(p.items.has(w));p.items.set(w,{clip:1000,stock:1000});},
  SwitchToWeapon:w=>{assert(p.items.has(w));p.current=w;},SwitchToWeaponImmediate:w=>{assert(p.items.has(w));p.current=w;},
  ShouldDoInitialWeaponRaise:(w,on)=>{assert(p.items.has(w));p.events.push(['flourish',w,on]);},
  staff_presentation_log:(w,s)=>p.events.push(['log',w,s]),pap_camo_options:()=>0,camo_stamp:()=>{},
  player_is_in_laststand:()=>p.down,ensure_equipped:()=>{},camo_regive_reassert:()=>{},
  twin_suffix_for:g=> '_q'+p.q+(p.useDoubleTapAxes&&g.stem==='tod_staff_ice'?'d'+p.d:''),
  give_camo_weapon:w=>ctx.give_camo_weapon(w),camo_regive:(...a)=>ctx.camo_regive(...a),
  swap_primary:(...a)=>drain(ctx.swap_primary(...a)),weapon_give:w=>p.GiveWeapon(w)
 });p.takeWeapon=p.TakeWeapon;p.switchToWeapon=p.SwitchToWeapon;ctx.self=p;return p;
}
for(const e of names)for(const q of [0,1])for(const tier of [0,1,2,3]) {
 const p=player(),base=roots.get('tod_staff_'+e+'_q'+q);p.tiers[e]=tier;
 const want=tier?variants.get(base.name):base;
 assert.equal(ctx.staff_presentation(p,base),want);
 assert.equal(ctx.give_camo_weapon(base),want);assert(p.items.has(want));
 assert.deepEqual(p.events.find(x=>x[0]==='flourish'),['flourish',want,true]);
 p.items.get(want).clip=7;p.items.get(want).stock=31;
 ctx.camo_regive(want,false);assert.deepEqual(p.items.get(want),{clip:7,stock:31});
}
for(const e of names)for(const q of [0,1]) {
 const p=player();p.q=q;
 for(const other of names){const w=roots.get('tod_staff_'+other+'_q'+q);p.items.set(w,{clip:7,stock:31});}
 const base=roots.get('tod_staff_'+e+'_q'+q),packed=variants.get(base.name);p.current=base;p.tiers[e]=1;
 ctx.reconcile_twin();assert.equal(p.current,packed);assert.equal(p.items.size,3);
 assert.deepEqual(p.items.get(packed),{clip:1000,stock:1000});
 for(const [w,ammo] of p.items)if(w!==packed){assert(!ctx.staff_is_packed(w));assert.equal(ammo.clip,7);}
 const count=p.events.length;ctx.reconcile_twin();assert.equal(p.events.length,count,'idempotent attachment reconciliation');
 p.items.get(packed).clip=9;p.items.get(packed).stock=23;p.q=1-q;
 // Inventory order can put another staff first; run the normal one-per-tick walk.
 for(let i=0;i<3;i++)ctx.reconcile_twin();
 const next=variants.get('tod_staff_'+e+'_q'+(1-q));assert(p.items.has(next));assert.equal(p.items.size,3);
 assert.deepEqual(p.items.get(next),{clip:9,stock:23});
 assert.deepEqual(p.events.filter(x=>x[0]==='flourish'&&x[1]===next).at(-1),['flourish',next,false]);
}
for(const down of [false,true])for(const tier of [1,2,3]) {
 const p=player(),base=roots.get('tod_staff_ice_q0'),packed=variants.get(base.name);
 const old=tier===1?base:packed;p.items.set(old,{clip:7,stock:31});p.current=old;p.tiers.ice=tier;p.down=down;
 drain(ctx.giveWeaponRepacked(old));assert(p.items.has(packed));assert.equal(p.items.size,1);
 assert.deepEqual(p.items.get(packed),{clip:1000,stock:1000});assert.equal(p.tod_tier_busy,undefined);
 assert.equal(p.current,down?null:packed);assert(p.events.some(x=>x[0]==='flourish'&&x[2]));
}
// Concurrent balance work adds a native ice Double Tap axis. It must keep the
// identical presentation attachment and must not replay acquisition flourishes.
for(const q of [0,1])for(const tier of [0,1,2,3]) {
 const p=player();p.q=q;p.d=0;p.useDoubleTapAxes=true;p.tiers.ice=tier;
 const old=(tier?variants:roots).get('tod_staff_ice_q'+q+'d0');p.items.set(old,{clip:11,stock:17});p.current=old;
 p.d=1;ctx.reconcile_twin();
 const next=(tier?variants:roots).get('tod_staff_ice_q'+q+'d1');assert.equal(p.current,next);
 assert.deepEqual(p.items.get(next),{clip:11,stock:17});assert.equal(p.items.size,1);
 assert.deepEqual(p.events.filter(x=>x[0]==='flourish').at(-1),['flourish',next,false]);
}
const p=player(),w=roots.get('tod_staff_fire_q0');p.tiers.fire=1;ctx.missing=true;
assert.equal(ctx.staff_presentation(p,w),w);assert.equal(ctx.staff_presentation(p,w),w);
assert.equal(p.events.filter(x=>x[0]==='log').length,1,'missing attachment logs once without removing weapon');
const p2=player();p2.q=0;p2.tiers.fire=1;
const kept=variants.get('tod_staff_fire_q1');p2.items.set(kept,{clip:7,stock:19});p2.current=kept;
ctx.reconcile_twin();assert.equal(p2.current,kept);assert.equal(p2.items.size,1,'missing destination attachment retains existing packed gun');
console.log('Staff presentation passed: all elements/handling/tier states, independent ownership, first equip, PaP return/downed return, free-PaP reconciliation, same-root safety, ammo preservation and missing-asset fallback.');
