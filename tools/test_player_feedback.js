// Execute the changed GSC helpers with mocked players/time; no engine substitute.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const mage=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc','utf8');
const tp=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_teleport.gsc','utf8');
function body(src,name){
    src=src.replace(/\/\/[^\n]*/g,'');
    let a=src.indexOf('{',src.indexOf('function '+name+'(')),b=a+1,d=1;
    assert(a>=0,name);while(d){if(src[b]==='{')d++;if(src[b]==='}')d--;b++;}
    return src.slice(a+1,b-1);
}
const env={isdefined:v=>v!==undefined,IsAlive:p=>p.alive,int:Math.trunc,
    array:(...v)=>v,abs:Math.abs,clock:1000,flags:{},hits:[],revives:[],sounds:[],notifies:[],
    level:{tod_tp_trigs:[]},players:[],endOn:()=>{},GetTime:()=>env.clock,
    Distance:(a,b)=>Math.hypot(...a.map((n,i)=>n-b[i])),Distance2D:(a,b)=>Math.hypot(a[0]-b[0],a[1]-b[1]),
    GetPlayers:()=>env.players,touch:(p,lv)=>env.hits.push({p,lv}),noop:()=>{},
    heal:(p,n)=>{p.healed=(p.healed||0)+n;},revive:p=>env.revives.push(p),
    flagExists:k=>k in env.flags,flagGet:k=>env.flags[k]};
for(const src of [mage,tp])for(const m of src.matchAll(/#define\s+(TOD_\w+)\s+([\d.]+)/g))env[m[1]]=Number(m[2]);
vm.createContext(env);
for(const [name,args,locals] of [['heal_radius','lv',''],['heal_hp_per_second','lv',''],['heal_tick_amount','lv,tick','rate'],['recharge_percent','left,total','pct']])
    vm.runInContext(`function ${name}(${args}){let ${locals||'unused'};${body(mage,name)}}`,env);
for(const lv of [0,1,2,3,4,5,6,7,99]){
    const r=env.heal_radius(lv);assert(Number.isFinite(r));assert(r>=256&&r<=416);
}
assert.equal(env.heal_radius(7),env.heal_radius(6),'Dark retains Lv6 range');
assert(mage.includes('radius = heal_radius( lv );'));
let pulse=body(mage,'heal_pulse')
    .replace(/self endon\(/g,'endOn(')
    .replace(/foreach \( p in GetPlayers\(\) \)/g,'for (const p of GetPlayers())')
    .replace(/p laststand::player_is_in_laststand\(\)/g,'p.down')
    .replace(/p thread heal_revive\( self \)/g,'revive(p)')   // 2026-10-01: heal_revive = stock auto_revive + the "+" burst
    .replace(/self heal_area_start\([^;]*\);/g,'noop();')    // 2026-10-01: the ground area is a visual; this test is the healing math
    .replace(/p aura_touch\( lv \)/g,'touch(p,lv)')
    .replace(/p aura_bar\( true \)/g,'noop()').replace(/p heal_visual_touch\(\)/g,'noop()')
    .replace(/p tod_upgrades::trickle_heal\( heal_tick_amount\( lv, i \) \)/g,'heal(p,heal_tick_amount(lv,i))')
    .replace(/p PlayLocalSound\( "tod_mage_heal" \)/g,'noop()')
    .replace(/IS_TRUE\( p.tod_mage_healed_tell \)/g,'(p.tod_mage_healed_tell===true)')
    .replace(/wait TOD_MAGE_HEAL_TICK_SECS;/g,'yield;');
vm.runInContext(`function* pulse(lv){let radius,raised,i;${pulse}}`,env);
for(const lv of [1,6,7]){
    const r=env.heal_radius(lv);
    const player=(x,down=false)=>({alive:true,origin:[x,0,0],maxhealth:150,down});
    env.self=player(0);env.players=[env.self,player(r-1),player(r+1),player(100,true)];env.hits=[];env.revives=[];
    for(const _ of env.pulse(lv)){}
    assert(env.self.healed>0);assert(env.players[1].healed>0);assert.equal(env.players[2].healed,undefined);
    assert.equal(env.revives.length,lv>=6?1:0,'revive once, only at Lv6/Dark');
    if(lv===7)assert.equal(env.self.healed,65,'Dark strength is not clamped with radius');
}
for(const [left,total,want] of [[20,20,0],[10,20,50],[0,20,99],[-1,20,99],[30,20,0],[undefined,20,0]])
    assert.equal(env.recharge_percent(left,total),want);
let regen=body(mage,'charge_regen').replace(/self endon\(/g,'endOn(').replace(/self notify\(/g,'endOn(')
    .replace(/self charges_now\(\)/g,'self.tod_mage_charges').replace(/self charges_max\(\)/g,'self.cap')
    .replace(/self cooldown_scale\(\)/g,'1').replace(/wait 0.25;/g,'yield;')
    .replace(/IS_TRUE\( level.tod_upgrade_pause \)/g,'(level.tod_upgrade_pause===true)');
vm.runInContext(`function* regen(){let secs,left;${regen}}`,env);
env.self={tod_mage_charges:0,cap:2};env.level.tod_upgrade_pause=false;const timer=env.regen();timer.next();
const full=env.self.tod_mage_heal_recharge_left;
for(let n=0;n<8;n++)timer.next();assert.equal(env.self.tod_mage_heal_recharge_left,full-2);
env.level.tod_upgrade_pause=true;for(let n=0;n<20;n++)timer.next();assert.equal(env.self.tod_mage_heal_recharge_left,full-2);
env.level.tod_upgrade_pause=false;for(let n=0;n<500&&!timer.next().done;n++){}
assert.equal(env.self.tod_mage_charges,2);
let sendBody=body(mage,'recharge_send')
    .replace(/self charges_now\(\)/g,'self.healCount').replace(/self charges_max\(\)/g,'self.healMax')
    .replace(/self blink_charges_now\(\)/g,'self.blinkCount').replace(/self blink_capacity\(\)/g,'self.blinkMax')
    .replace(/self blink_recharge_ms\(\)/g,'self.blinkInterval')
    .replace(/self LuiNotifyEvent\( &"tod_mage_recharge", 2, heal, blink \)/g,'notifies.push([heal,blink])');
vm.runInContext(`function rechargeSend(){let heal,blink;${sendBody}}`,env);
env.self={healCount:0,healMax:0,blinkCount:0,blinkMax:0};env.notifies=[];env.rechargeSend();
assert.deepEqual(Array.from(env.notifies[0]),[-1,-1],'locked indicators hidden');
env.self={healCount:1,healMax:2,blinkCount:1,blinkMax:2,blinkInterval:10000,
    tod_mage_heal_recharge_left:10,tod_mage_heal_recharge_secs:20,tod_mage_cd:{mage_blink:env.clock+5000}};
env.rechargeSend();assert.deepEqual(Array.from(env.notifies[1]),[50,50],'stored spare charges do not hide progress');
env.rechargeSend();assert.equal(env.notifies.length,2,'unchanged progress is not resent');
env.self.healCount=2;env.self.blinkCount=2;env.rechargeSend();assert.deepEqual(Array.from(env.notifies[2]),[-1,-1]);
let cast=body(mage,'cast_blink').replace(/self ready\( "mage_blink" \)/g,'self.ready')
    .replace(/self laststand::player_is_in_laststand\(\)/g,'self.down')
    .replace(/self blink_level\(\)/g,'1').replace(/self GetPlayerAngles\(\)/g,'[0,0,0]')
    .replace(/\( fwd\[ 0 \], fwd\[ 1 \], 0 \)/g,'[fwd[0],fwd[1],0]')
    .replace(/self blink_landing\( fwd, dist \)/g,'self.landing')
    .replace(/self LuiNotifyEvent\( &"tod_mage_blink_blocked", 1, 1 \)/g,'notifies.push("blocked")')
    .replace(/self blink_spend\(\)/g,'self.spent++').replace(/self SetOrigin\( land \)/g,'self.origin=land')
    .replace(/self PlayLocalSound\( "zmb_bgb_abh_teleport_in" \)/g,'noop()')
    // 2026-10-01: v19.11 added the tutorial cast counter to cast_blink and this
    // mock never learned it (a pre-existing break, found reviewing docs/167).
    .replace(/self tut_count\( "blink" \)/g,'noop()');
env.AnglesToForward=()=>[1,0,0];env.LengthSquared=()=>1;env.VectorNormalize=v=>v;env.blink_fx=()=>{};
vm.runInContext(`function castBlink(){let lv,dist,fwd,land;${cast}}`,env);
env.self={ready:true,down:false,spent:0,origin:[0,0,0]};env.notifies=[];env.castBlink();
assert.equal(env.self.spent,0);assert.deepEqual(env.notifies,['blocked'],'blocked landing acknowledges input without spending');
env.self.landing=[320,0,0];env.castBlink();assert.equal(env.self.spent,1);assert.equal(env.notifies.length,1);
env.self.ready=false;env.castBlink();assert.equal(env.notifies.length,1,'cooldown is not a blocked landing');
for(const [name,args,locals] of [['pad_lock_reason','lock_flag','unused'],['pad_locked','lock_flag','unused'],['recharge_seconds','until','left'],['recharge_pad_for','player','best,nearest,i,t,d']]){
    const b=body(tp,name).replace(/level flag::exists\(/g,'flagExists(').replace(/level flag::get\(/g,'flagGet(').replace(/level.tod_tp_trigs.size/g,'level.tod_tp_trigs.length');
    vm.runInContext(`function ${name}(${args}){let ${locals};${b}}`,env);
}
assert.equal(env.pad_lock_reason(undefined),1);
env.flags={power_on:true,enter_lap10:false};assert.equal(env.pad_lock_reason('enter_lap10'),2);
assert.equal(env.pad_lock_reason(undefined),0,'down ride only needs power');
env.flags.enter_lap10=true;assert.equal(env.pad_locked('enter_lap10'),false);
for(const [delta,seconds] of [[60000,60],[59001,60],[59000,59],[1,1],[0,0],[-1,0]])assert.equal(env.recharge_seconds(env.clock+delta),seconds);
env.level.tod_tp_trigs=[{tod_tp_src:[-110,0,0],tod_tp_radius:110},{tod_tp_src:[110,0,0],tod_tp_radius:110},{tod_tp_src:[-110,0,384],tod_tp_radius:110}];
assert.equal(env.recharge_pad_for({alive:true,origin:[-100,0,0]}),0);
assert.equal(env.recharge_pad_for({alive:true,origin:[100,0,0]}),1);
assert.equal(env.recharge_pad_for({alive:true,origin:[-100,0,384]}),2);
assert.equal(env.recharge_pad_for({alive:true,origin:[0,200,0]}),-1);
assert.equal(env.recharge_pad_for({alive:false,origin:[-100,0,0]}),-1);
console.log('Player feedback GSC: Dark Aura range/healing/revive, paused recharge, teleporter locks/seconds/adjacent pads/heights pass.');
