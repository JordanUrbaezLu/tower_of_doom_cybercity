// Execute the shipping GSC state and inventory code with native calls mocked.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const source=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_thunder_smash.gsc','utf8');
const twins=fs.readFileSync('source_data/tod_weapon_twins.gdt','utf8');
const unique=fs.readFileSync('source_data/tod_thunder_smash.gdt','utf8');
const fullWeapons=new Set([...fs.readFileSync('zone_source/tod_twins.zpkg','utf8').matchAll(/^weaponfull,([^\r\n]+)/gm)].map(m=>m[1].replace(/_zm$/,'')));
const attachmentAssets=new Set([...unique.matchAll(/"([^"]+)"\s*\(\s*"attachmentunique.gdf"/g)].map(m=>m[1]));
const binding=new Map([...twins.matchAll(/"(leviathan[^"\n]+)_zm"\s*\(\s*"bulletweapon.gdf"\s*\)\s*\{([^}]+)\}/g)]
 .map(m=>[m[1],m[2].match(/"attachmentUnique"\s+"([^"]*)"/)[1]]));
assert.equal(binding.size,13);
function body(name){const s=source.replace(/\/\/[^\n]*/g,'');let a=s.indexOf('{',s.indexOf('function '+name+'(')),z=a+1,d=1;assert(a>=0,name);while(d){if(s[z]==='{')d++;if(s[z]==='}')d--;z++;}return s.slice(a+1,z-1);}
function trans(s){return s.replace(/foreach\s*\(\s*(\w+)\s+in\s+([^\n]+)\s*\)/g,'for (const $1 of $2)')
 .replace(/\b(self|player|owner|level)\s+(?:thread\s+)?(?:\w+::)?(\w+)\(/g,'$1.$2(')
 .replace(/tod_classes::/g,'').replace(/&"/g,'"').replace(/\bwait\s+([\d.]+);/g,'yield $1;');}
let clock=0,missing=false,impacts=0,logs=[];
const ctx={isdefined:v=>v!==undefined&&v!==null,IS_TRUE:v=>v===true,IsSubStr:(s,k)=>s.includes(k),
 array:(...x)=>x,SpawnStruct:()=>({}),GetTime:()=>clock,IsAlive:p=>p.alive,tier:p=>p.tod_tier,
 pap_camo_options:p=>p.camo,log:s=>logs.push(s),TOD_SMASH_ANIMATION_MS:2100,TOD_SMASH_IMPACT_MS:967,
 try_smash_arc:()=>({airborne:true}),update_smash_arc:()=>{},impact:()=>impacts++,
 level:{weaponNone:null,endon:()=>{},perform:(p,t)=>{ctx.pending=[p,t];}},
 WeaponHasAttachment:(w,a)=>w.attachments.includes(a),
 GetWeapon:(name)=>missing||!fullWeapons.has(name)||!attachmentAssets.has(binding.get(name)+'_gmod7')?ctx.root:{name,rootWeapon:ctx.root,attachments:['gmod7']},int:n=>Math.trunc(n)||0};
vm.createContext(ctx);
for(const [name,args,locals,gen] of [
 ['cooldown_ms','rank',''],['hammer','weapon',''],['cast_attachment','weapon',''],
 ['equipped','player',''],['blocked','player',''],['owns_cast','player,token',''],
 ['start','rank','original,root,cast,token,resolved,attached'],['finish','owner,token,reason','current',true],
 ['send_hud','code,percent,seconds',''],
 ['cast_percent','token','percent'],
 ['perform','owner,token','started,motion,reason,elapsed,landed,i',true],
 ['tactical_pin','active','grenade,saved,clip,stock']]){
 vm.runInContext('function'+(gen?'*':'')+' '+name+'('+args+'){'+(locals?'let '+locals+';':'')+trans(body(name))+'}',ctx);
}
// Consume finish's native settle frame in callers; expose the coroutine too so
// cancellation while returning can be tested independently.
ctx.finishSteps=ctx.finish;
ctx.finish=(...args)=>{for(const seconds of ctx.finishSteps(...args))clock+=seconds*1000;};
function player(name='leviathan_k0',ammo=3){
 ctx.root={name,attachments:[]};ctx.root.rootWeapon=ctx.root;
 const p={tod_class:'slasher',tod_tier:3,tod_smash_life:{},tod_smash_uses:0,camo:124,alive:true,ground:true,items:new Map(),events:[]};
 const key=w=>w.name+':'+w.attachments.join(',');p.current=ctx.root;p.items.set(key(ctx.root),{weapon:ctx.root,clip:ammo,stock:17});
 Object.assign(p,{GetCurrentWeapon:()=>p.current,GetEntityNumber:()=>1,player_is_in_laststand:()=>p.down,
 IsMantling:()=>false,IsWallRunning:()=>false,IsThrowingGrenade:()=>p.throwing,IsOnGround:()=>p.ground,PlaySound:()=>{},
 DisableWeaponFire:()=>p.fire=false,EnableWeaponFire:()=>p.fire=true,AllowMelee:v=>p.melee=v,
 HasWeapon:w=>p.items.has(key(w)),GetWeaponAmmoClip:w=>p.items.get(key(w)).clip,GetWeaponAmmoStock:w=>p.items.get(key(w)).stock,
 SetWeaponAmmoClip:(w,n)=>p.items.get(key(w)).clip=n,SetWeaponAmmoStock:(w,n)=>p.items.get(key(w)).stock=n,
 TakeWeapon:w=>{p.events.push('take');for(const [k,v] of p.items)if(v.weapon.rootWeapon===w.rootWeapon)p.items.delete(k);if(p.current?.rootWeapon===w.rootWeapon)p.current=null;},
 GiveWeapon:(w,c)=>{assert.equal(c,p.camo);p.events.push('give');p.items.set(key(w),{weapon:w,clip:999,stock:999});},
 ShouldDoInitialWeaponRaise:(w,v)=>p.events.push(v?'first':'normal'),SwitchToWeaponImmediate:w=>{p.current=w;p.events.push('switch');}});
 ctx.self=p;return p;
}
assert.deepEqual([0,1,2,3,6].map(n=>ctx.cooldown_ms(n)),[45000,45000,35000,25000,25000]);
let cases=0;
for(const up of [false,true])for(let k=0;k<=(up?6:5);k++)for(const ammo of [0,7]){
 const p=player('leviathan'+(up?'_up':'')+'_k'+k,ammo),original=ctx.root;
 assert(ctx.equipped(p));p.tod_tier=2;assert(!ctx.equipped(p));p.tod_tier=3;
 ctx.start(2);const token=p.tod_smash_cast;assert(token);assert.equal(p.tod_smash_left,35000);
 assert(!p.events.includes('switch'),'cast must not switch in the take/give frame');
 assert.deepEqual(p.events.slice(0,2),['take','give']);assert.equal(p.GetWeaponAmmoClip(token.weapon),ammo);assert.equal(p.items.size,1);
 assert.equal(p.fire,false);assert.equal(p.melee,false);assert.equal(p.tod_swap_busy,true);
 ctx.finish(p,token,'test');assert.equal(p.current,original);assert.equal(p.GetWeaponAmmoClip(original),ammo);assert.equal(p.GetWeaponAmmoStock(original),17);
 assert.equal(p.items.size,1);assert.equal(p.fire,true);assert.equal(p.melee,true);assert.equal(p.tod_swap_busy,false);assert.equal(p.tod_smash_left,0);cases++;
}
// Failed asset resolution must leave the inventory and cooldown alone.
let p=player();missing=true;ctx.start(1);assert.equal(p.events.length,0);assert.equal(p.tod_smash_cast,undefined);missing=false;
// Reproduce the native failure: zoned assets exist, but the base omits au_.
const good=binding.get(ctx.root.name);binding.set(ctx.root.name,good.replace(/^au_/,''));
ctx.start(1);assert.equal(p.events.length,0,'bad attachment base must refuse');binding.set(ctx.root.name,good);
// Reproduce the second native failure: valid AUs, but a bare weapon zone entry.
fullWeapons.delete(ctx.root.name);ctx.start(1);assert.equal(p.events.length,0,'bare zone entry must refuse');fullWeapons.add(ctx.root.name);
// Cast fill uses elapsed animation time; cooldown has its own progress.
for(const [elapsed,want] of [[-1,0],[0,0],[1050,50],[2100,100],[5000,100]]){
 clock=100+elapsed;assert.equal(ctx.cast_percent({raise_ms:100}),want);
}
assert.equal(ctx.cast_percent({id:0}),0,'no progress before equip starts');
// Execute the actual sender through the native event registration/count rules.
const precached=new Set([...source.matchAll(/#precache\(\s*"eventstring",\s*"([^"]+)"\s*\)/g)].map(m=>m[1]));
let packet;
p.LuiNotifyEvent=(event,count,...values)=>{assert(precached.has(event),'event name not precached');assert.equal(count,values.length,'wrong payload count');packet=values;};
for(const state of [0,1,2,3,4,26]){ctx.send_hud(state,37,29);assert.deepEqual(packet,[state,37,29]);}
assert.throws(()=>p.LuiNotifyEvent('tod_thunder_smash',2,37,29,0),'former missing count argument');
assert.throws(()=>p.LuiNotifyEvent('unprecached',3,2,100,0));
// Completion hits once, preserves cooldown; holding LB cannot retrigger in watch.
p=player();ctx.start(3);let t=p.tod_smash_cast;clock=0;impacts=0;
for(const seconds of ctx.perform(p,t))clock+=seconds*1000;
assert.equal(impacts,1);assert.equal(p.tod_smash_uses,1);assert.equal(p.tod_smash_left,25000);assert.equal(p.tod_smash_cast,undefined);
// Native can swallow equip requests. Retry during setup, never restart a swing.
p=player();ctx.start(1);t=p.tod_smash_cast;clock=0;impacts=0;
const normalSwitch=p.SwitchToWeaponImmediate;let switches=0;
p.SwitchToWeaponImmediate=w=>{switches++;if(switches>2)normalSwitch(w);};
for(const seconds of ctx.perform(p,t))clock+=seconds*1000;
assert.equal(impacts,1);assert.equal(switches,4,'three setup attempts and one ordinary return');
// Missing native equips time out, refund and release the controls.
p=player();ctx.start(1);t=p.tod_smash_cast;clock=0;impacts=0;
p.SwitchToWeaponImmediate=()=>{};
for(const seconds of ctx.perform(p,t))clock+=seconds*1000;
assert.equal(impacts,0);assert.equal(p.tod_smash_left,0);assert.equal(p.tod_swap_busy,false);
// Abort before impact refunds, after impact spends; every exit releases locks.
for(const trigger of ['pause','down','death','switch','grenade'])for(const after of [false,true]){
 p=player();ctx.start(1);t=p.tod_smash_cast;clock=0;impacts=0;let gen=ctx.perform(p,t);
 for(let r=gen.next();!r.done;r=gen.next()){
  clock+=r.value*1000;
  if(clock>(after?1200:400)){
   if(trigger==='pause')ctx.level.tod_upgrade_pause=true;
   if(trigger==='down')p.down=true;
   if(trigger==='death')p.alive=false;
   if(trigger==='grenade')p.throwing=true;
   if(trigger==='switch')p.current={name:'sidearm',attachments:[],rootWeapon:{}};
  }
 }
 assert.equal(impacts,after?1:0);assert.equal(p.tod_smash_left,after?45000:0);assert.equal(p.fire,true);assert.equal(p.tod_swap_busy,false);
 if(trigger==='death')assert.equal(p.items.size,0);
 if(trigger==='switch')assert.equal(p.current.name,'sidearm');
 ctx.level.tod_upgrade_pause=false;
}
// A new life or lost cast never re-gives the captured weapon.
p=player();ctx.start(1);t=p.tod_smash_cast;p.tod_smash_life={};let before=p.events.length;ctx.finish(p,t,'stale');assert.equal(p.events.length,before);
p=player();ctx.start(1);t=p.tod_smash_cast;p.items.clear();ctx.finish(p,t,'lost');assert.equal(p.items.size,0);
// Tactical reservation preserves refills and never touches lethal ammo.
p=player();const grenade={name:'monkey',rootWeapon:{},attachments:[]};p.current_tactical_grenade=grenade;
p.items.set('monkey:',{weapon:grenade,clip:2,stock:0});ctx.tactical_pin(true);assert.equal(p.GetWeaponAmmoClip(grenade),0);
p.SetWeaponAmmoClip(grenade,3);ctx.tactical_pin(true);ctx.tactical_pin(false);assert.equal(p.GetWeaponAmmoClip(grenade),3);
// Execute the watch's cooldown and button-edge statements, including menu-held LB.
const tick=body('watch').slice(body('watch').indexOf('now = GetTime();'),body('watch').indexOf('rank = tod_upgrades::'));
vm.runInContext('function tick(){'+trans(tick)+'}',ctx);ctx.previous=0;ctx.was_pressed=false;ctx.self=p;p.SecondaryOffhandButtonPressed=()=>p.press;
p.tod_smash_left=1000;clock=100;ctx.tick();assert.equal(p.tod_smash_left,900);
ctx.level.tod_upgrade_pause=true;p.press=true;clock=200;ctx.tick();assert(ctx.edge);assert.equal(p.tod_smash_left,900);
ctx.level.tod_upgrade_pause=false;clock=300;ctx.tick();assert(!ctx.edge);assert.equal(p.tod_smash_left,800);
// Impact target/damage loop, excluding only vector arithmetic and native FX.
let targets=[];Object.assign(ctx,{int:Math.trunc,TOD_SMASH_RADIUS:300,GetAIArray:()=>targets,
 Distance:(a,b)=>Math.abs(a[0]-b[0]),BulletTrace:(a,b)=>({fraction:b[1]===99?0.5:1}),
 is_boss_or_elite:v=>v.elite,PlayFX:()=>{}});
let impactBody=body('impact').slice(body('impact').indexOf('round_hp ='));
impactBody=trans(impactBody).replace(/tod_upgrades::/g,'').replace(/origin \+ \( 0, 0, 24 \)/g,'origin')
 .replace(/victim DoDamage\(/g,'victim.DoDamage(');
vm.runInContext('function damageLoop(owner,token){let origin=owner.origin,round_hp,targets,hits,elites,trace,elite,damage;'+impactBody+'}',ctx);
let actual=[];p=player();p.origin=[0,0,0];ctx.level.zombie_health=1200;
for(const [elite,x,wall] of [[false,20,0],[true,40,0],[false,500,0],[false,50,99]]){
 let v={alive:true,health:7500,elite,origin:[x,wall,0]};
 v.DoDamage=(d,point,a)=>{assert.equal(v.tod_smash_attacker,p);assert.equal(v.tod_smash_hit_ms,clock);actual.push(d);};targets.push(v);
}
ctx.damageLoop(p,{rank:2,id:1,original:ctx.root});assert.deepEqual(actual,[7501,4800]);
for(const v of targets)assert.equal(v.tod_smash_attacker,undefined);
console.log(`Thunder Smash: ${cases} hammer/ammo combinations, cast/abort/one impact, pause/held input, life ownership, tactical refill and ordinary/elite/range/occlusion damage pass.`);
