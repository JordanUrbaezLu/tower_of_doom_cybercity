// Execute the real death hook against mocked native physics; asset/balance gates
// also ensure every speed/PaP variant remains a bat and uses the supplied hit WAV.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const src=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_corpse_cleanup.gsc','utf8');
// Cleanup/hoop diagnostics may observe deaths, never steer players or create
// damage. The old calibration loop ran during every dev-mode user playtest.
function assertPassiveCleanup(source){
 const live=source.replace(/\/\*[\s\S]*?\*\//g,'').replace(/\/\/[^\n]*/g,'');
 assert(!/\b(?:SetPlayerAngles|DoDamage)\s*\(/.test(live),'cleanup must not aim for players or manufacture kills');
}
assertPassiveCleanup(src);
for(const forbidden of ['p SetPlayerAngles( ang );','best DoDamage( 9999 );'])
 assert.throws(()=>assertPassiveCleanup(src+'\nfunction bad_probe(){'+forbidden+'}'),/cleanup must not/);
console.log('Hoop diagnostics: no forced player aim or synthetic kills, with regression controls PASS.');
function body(name){const clean=src.replace(/\/\/[^\n]*/g,'');let a=clean.indexOf('{',clean.indexOf('function '+name+'(')),b=a+1,d=1;while(d){if(clean[b]==='{')d++;if(clean[b]==='}')d--;b++;}return clean.slice(a+1,b-1);}
// v19.10: the TOD_BAT_* knobs are READ OUT OF THE GSC, never restated here — a
// test that hardcodes the number it is checking only proves it can copy.
const D=n=>{const m=src.match(new RegExp('#define\\s+'+n+'\\s+([-\\d.]+)'));
 assert(m,'missing #define '+n);return parseFloat(m[1]);};
const near=(a,b,m)=>assert(Math.abs(a-b)<1e-6,m+` (got ${a}, want ${b})`);
const BAT={FWD:D('TOD_BAT_FLING_FWD'),UP:D('TOD_BAT_FLING_UP'),VAR:D('TOD_BAT_FLING_VAR'),
 PAP:D('TOD_BAT_FLING_PAP_MULT'),CRIT_PCT:D('TOD_BAT_CRIT_PCT'),CRIT:D('TOD_BAT_CRIT_MULT')};
const env={IS_TRUE:x=>x===true,isdefined:x=>x!==undefined,IsPlayer:x=>x.player,
 IsSubStr:(s,v)=>s.includes(v),bat_log:()=>{},AnglesToForward:()=>[1,0,0],
 VectorNormalize:v=>v,VectorScale:(v,n)=>v.map(x=>x*n),
 TOD_BAT_FLING_FWD:BAT.FWD,TOD_BAT_FLING_UP:BAT.UP,TOD_BAT_FLING_VAR:BAT.VAR,
 TOD_BAT_FLING_PAP_MULT:BAT.PAP,TOD_BAT_CRIT_PCT:BAT.CRIT_PCT,TOD_BAT_CRIT_MULT:BAT.CRIT,
 // The two random rolls are driven by the test.
 RandomFloatRange:(a,b)=>a+(b-a)*env.roll,
 RandomInt:n=>env.critRoll,
 ragdoll:()=>env.ragdolls++,launch:v=>{env.launches++;env.impulse=v;}};
env.roll=0.5;env.critRoll=99;
vm.createContext(env);
// v19.18c: the launch lives in bat_fling (one owner for the pre-death lane and
// the death fallback); the death hook is exercised with it inlined.
let code=body('bat_home_run')
 .replace(/self bat_fling\( attacker, self\.damageweapon\.name, "death" \);/,()=>`{const weapon_name=self.damageweapon.name,lane="death";${body('bat_fling')}}`)
 .replace(/attacker GetPlayerAngles\(\)/g,'[]')
 .replace(/self GetEntityNumber\(\)/g,'1').replace(/attacker GetEntityNumber\(\)/g,'0')
 .replace(/\( dir\[0\], dir\[1\], 0 \)/g,'[dir[0],dir[1],0]')
 .replace(/VectorScale\( dir, TOD_BAT_FLING_FWD \* scale \)\s*\+ \( 0, 0, TOD_BAT_FLING_UP \* scale \)/g,
          '[dir[0]*TOD_BAT_FLING_FWD*scale,dir[1]*TOD_BAT_FLING_FWD*scale,TOD_BAT_FLING_UP*scale]')
 .replace(/self StartRagdoll\(\)/g,'ragdoll()').replace(/self LaunchRagdoll\(/g,'launch(')
 // v19.18: the hoop watcher is threaded after the launch; counted, not run, here.
 .replace(/self thread hoop_arc\( attacker, impulse, scale, crit \);/g,'watched();')
 .replace(/self clientfield::set\( "tod_hoop_watch", 1 \);/g,'cfset();')
 // v19.18b: the direction comes from bat_launch_dir (tested on its own below).
 .replace(/bat_launch_dir\( attacker \)/g,'[1,0,0]');
env.watches=0;env.watched=()=>{env.watches++;};env.cfsets=0;env.cfset=()=>{env.cfsets++;};
assert(!/GetPlayerAngles/.test(code),'bat_home_run no longer computes the direction inline');
assert(/bat_fling/.test(body('bat_home_run')),'the death hook launches through bat_fling');
// v19.18d: the pre-death lane is RETIRED WHOLE — nothing in the damage chain may withhold a bat hit.
assert(!/bat_prelaunch/.test(src),'bat_prelaunch is gone');
{const up=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc','utf8');
 assert(!/tod_bat_prelaunch/.test(up),'the damage chain no longer withholds bat kills');}
assert(!/VectorScale\( dir, 180 \)/.test(code),'the fixed 180/110 impulse is gone');
assert(!/bat_lunge|ButtonPressed/.test(src),'no inferred lunge or input gate remains');
vm.runInContext(`function test(attacker){let dir,impulse;${code}}`,env);
const victim=(name='t9_me_baseballbat_k0',extra={})=>({damageweapon:{name},damagemod:'MOD_MELEE',...extra});
// ONE launch per death, on every speed rung, base and packed. roll 0.5 = the
// midpoint of the band, so the expected impulse is exactly the base x any PaP.
for(const up of ['', '_up'])for(let k=0;k<6;k++){
 const pap=up==='_up'?BAT.PAP:1;
 env.roll=0.5;env.critRoll=99;
 env.self=victim(`t9_me_baseballbat${up}_k${k}`);env.ragdolls=env.launches=0;
 env.test({player:true});env.test({player:true});assert.equal(env.launches,1);assert.equal(env.ragdolls,1);
 near(env.impulse[0],BAT.FWD*pap,'fwd');near(env.impulse[1],0,'lateral');near(env.impulse[2],BAT.UP*pap,'up');
}

// LUNGE ONLY — a plain swipe kills without throwing the body.
env.roll=0.5;env.critRoll=99;
env.self=victim();env.ragdolls=env.launches=0;env.test({player:true});
assert.equal(env.launches,1,'a killing swipe must fling');
assert.equal(env.ragdolls,1,'a killing swipe ragdolls');


// THE BAND: the roll scales both axes together and never inverts the arc.
{const seen=[];
 for(const r of [0,0.5,1]){
  env.roll=r;env.critRoll=99;env.self=victim();env.launches=0;env.test({player:true});
  seen.push(env.impulse[0]);
  assert(Math.abs(env.impulse[2]/env.impulse[0]-BAT.UP/BAT.FWD)<1e-9,'arc shape holds across the roll');
 }
 near(seen[0],BAT.FWD*(1-BAT.VAR),'floor of the band');
 near(seen[2],BAT.FWD*(1+BAT.VAR),'ceiling of the band');
 assert(seen[0]<seen[1]&&seen[1]<seen[2],'the roll actually varies the distance');}

// THE HOME RUN: 1% of bat kills go 2x the CEILING, and the odds do not move with PaP.
{env.roll=0.5;env.critRoll=0;env.self=victim();env.launches=0;env.test({player:true});
 const ceiling=BAT.FWD*(1+BAT.VAR);
 near(env.impulse[0],ceiling*BAT.CRIT,'crit is 2x the roll ceiling, not 2x average');
 env.critRoll=BAT.CRIT_PCT;env.self=victim();env.launches=0;env.test({player:true});
 near(env.impulse[0],BAT.FWD,'one past the threshold is an ordinary swing');
 env.critRoll=0;env.self=victim('t9_me_baseballbat_up_k0');env.launches=0;env.test({player:true});
 near(env.impulse[0],ceiling*BAT.CRIT*BAT.PAP,'PaP scales a crit too');}
env.roll=0.5;env.critRoll=99;
for(const extra of [{damagemod:'MOD_BURNED'},{damageweapon:undefined},{damagemod:undefined},
 ...['is_boss','acc_is_boss','acc_is_mini_boss','tod_is_sprinter'].map(k=>({[k]:true})),{tod_boss_kind:'panzer'}]){
 env.self=victim(undefined,extra);env.launches=0;env.test({player:true});assert.equal(env.launches,0);
}
for(const name of ['t9_me_wakizashi_k0','leviathan_k0','pistol_standard']){
 env.self=victim(name);env.launches=0;env.test({player:true});assert.equal(env.launches,0);
}
assert(!/DoDamage|PlayFX\(/.test(body('bat_home_run')),'death presentation never adds damage or explosions');
const gdt=fs.readFileSync('source_data/tod_weapon_twins.gdt','utf8');
const blocks=[...gdt.matchAll(/"(t9_me_baseballbat[^"\n]+)" \( "bulletweapon.gdf" \)\s*\{([\s\S]*?)\n\t\}/g)];
assert.equal(blocks.length,12);
for(const [,name,block] of blocks){
 const f=Object.fromEntries([...block.matchAll(/"([^"\n]+)" "([^"\n]*)"/g)].map(m=>[m[1],m[2]]));
 assert.equal(+f.meleeDamage,name.includes('_up')?3520:1760);   // v19.63 slasher +10% (was 3200:1600)
 // 2026-10-02: NO LUNGE (user: "remove the lunge on the bat ... [we cannot] animate
 // out of the lunge if we have a swing ready"): the bat is on the roster-wide
 // MELEE_NO_LUNGE now - meleeChargeRange IS the lunge, meleeLungeRange the step.
 assert.equal(+f.meleeChargeRange,0,`${name}: the lunge is gone`);assert.equal(+f.meleeLungeRange,0,`${name}: no step-in`);
 assert.equal(f.meleeChargeAnim,'vm_t9_bat_melee_in');assert.equal(f.playerAnimType,'sword');
 assert.equal(f.gunModel,'wpn_t9_baseballbat_view');assert.equal(f.worldModel,'wpn_t9_baseballbat_world');
 // 2026-10-01 (docs/167 item 6): a lunge KILL never holds the blade longer than
 // a swing - the fatal recovery rides SLASHER_SWING_MULT / PaP / KNIFE SPEED now.
 assert(+f.meleeChargeFatalTime<=+f.meleeTime,`${name}: lunge kill recovery ${f.meleeChargeFatalTime} > swing ${f.meleeTime}`);
}
// 2026-10-01 (docs/167 item 5): EVERY BLADE FORM (bat, katana, Stormbreaker) - the
// inspect clip is OFF the reload lane and the reload is one frame, so a
// controller's X (+usereload) at a door buys instead of locking the blade.
{
 const blades=[...gdt.matchAll(/"((?:t9_me_baseballbat|t9_me_wakizashi|leviathan)[^"\n]*_zm)" \( "bulletweapon.gdf" \)\s*\{([\s\S]*?)\n\t\}/g)];
 assert.equal(blades.length,37,'12 bat + 12 katana + 13 Stormbreaker forms');
 for(const [,name,block] of blades){
  const f=Object.fromEntries([...block.matchAll(/"([^"\n]+)" "([^"\n]*)"/g)].map(m=>[m[1],m[2]]));
  assert.equal(f.reloadAnim,'',`${name}: reloadAnim must be empty (the inspect blocked use + attack)`);
  for(const k of ['reloadTime','reloadEmptyTime','reloadAddTime','reloadEmptyAddTime'])
   assert(+f[k]>0&&+f[k]<=0.05,`${name}: ${k} ${f[k]} must be one frame`);
  assert.equal(+f.meleeQueueMeleeEarlyTime,0.35,`${name}: melee queue window`);
 }
}
// 2026-10-02: THE INSPECT IS BACK, ON THE LOW-READY LANE (user: "We also broke the
// inspect on the bat. Please fix"). The reload lane stays one-frame (above); the
// clip rides lowReadyLoopAnim and _tod_bat_inspect.gsc enters / leaves low-ready
// around a reload press, leaving it on any swing - never a blocking reload again.
{
 const mod=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_bat_inspect.gsc','utf8');
 const live=mod.replace(/\/\*[\s\S]*?\*\//g,'').replace(/\/\/[^\n]*/g,'');
 const secs=parseFloat((mod.match(/#define\s+TOD_BAT_INSPECT_SECS\s+([\d.]+)/)||[])[1]);
 assert(secs>0,'TOD_BAT_INSPECT_SECS defined');
 for(const [,name,block] of blocks){
  const f=Object.fromEntries([...block.matchAll(/"([^"\n]+)" "([^"\n]*)"/g)].map(m=>[m[1],m[2]]));
  assert.equal(f.lowReadyLoopAnim,'vm_t9_bat_inspect',`${name}: the inspect clip rides low-ready`);
  near(+f.lowReadyLoopTime,secs,`${name}: lowReadyLoopTime must equal TOD_BAT_INSPECT_SECS`);
  assert.equal(+f.lowReadyInTime,0,`${name}: instant in`);assert.equal(+f.lowReadyOutTime,0,`${name}: instant out`);
 }
 assert(/SetLowReady\(\s*true\s*\)/.test(live)&&/SetLowReady\(\s*false\s*\)/.test(live),'the module enters AND leaves low-ready');
 assert(/ReloadButtonPressed\(\)/.test(live),'the reload press starts the inspect');
 for(const btn of ['AttackButtonPressed','MeleeButtonPressed','SprintButtonPressed'])
  assert(live.includes(btn+'()'),`a ${btn} leaves the inspect`);
 assert(live.includes('"t9_me_baseballbat_"'),'bat only');
 assert(/endon\(\s*"disconnect"\s*\)/.test(live)&&!/endon\(\s*"death"\s*\)/.test(live),'a death must still reach SetLowReady( false )');
 assert(!/DoDamage|PlaySound|SetPlayerAngles|GiveWeapon|TakeWeapon/.test(live),'the inspect is presentation only');
 const main=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_main.gsc','utf8').replace(/\/\/[^\n]*/g,'');
 assert(main.includes('#using scripts\\zm\\zm_tower_of_doom\\_tod_bat_inspect;')&&/tod_bat_inspect::init\(\)/.test(main),'wired in _tod_main');
 const zone=fs.readFileSync('zone_source/zm_tower_of_doom.zone','utf8');
 assert(zone.includes('scriptparsetree,scripts/zm/zm_tower_of_doom/_tod_bat_inspect.gsc'),'the module is zoned');
 console.log('Bat inspect: low-ready lane, '+secs+' s lockstep on 12 forms, leaves on swing/sprint/switch/down, wired + zoned.');
}
assert(!gdt.includes('"t9_me_knife_american_k'),'knife variants retired');
for(const row of fs.readFileSync('sound/aliases/tod_baseball_bat.csv','utf8').trim().split(/\r?\n/).slice(1)){
 const f=row.split(',');if(f[0]==='fly_melee_t9_bat_crowd'||f[0]==='tod_bat_swing')continue;
 assert.equal(f[3],'tod\\baseball_bat\\hit.wav');assert.equal(f[8],'');
}
console.log('Bat: 12 variants, preserved damage, NO lunge, impact WAV, death-only single launch and elite/non-bat exclusions PASS.');

// Execute the actual delayed Cleave sound selector. Changing held weapon cannot
// affect it: the strike weapon is a parameter retained across the wait.
const upgrades=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc','utf8');
let echo=upgrades.match(/function cleave_echo\( weapon \)\s*\{([\s\S]*?)\n\}/)[1]
 .replace(/\/\/[^\n]*/g,'').replace(/(?:self|level) endon\([^;]+;/g,'')
 .replace(/wait TOD_UPG_CLEAVE_ECHO_SECS;/,'')
 .replace(/self PlayLocalSound\(/,'record(');
env.TOD_UPG_CLEAVE_ECHO_SFX='fly_melee_swipe_player_t9_knife_h';env.record=s=>{env.sound=s;};
vm.runInContext(`function echo(weapon){let sfx;${echo}}`,env);
for(const name of ['t9_me_baseballbat_k0','t9_me_baseballbat_up_k5']){
 env.echo({name});assert.equal(env.sound,'fly_melee_swipe_player_t9_bat');
}
for(const weapon of [undefined,{name:'t9_me_wakizashi_k0'},{name:'leviathan_k0'}]){
 env.echo(weapon);assert.equal(env.sound,env.TOD_UPG_CLEAVE_ECHO_SFX);
}
console.log('Cleave: actual strike weapon selects bat sound; other blades keep their sound.');

const batSource=fs.readFileSync('source_data/tod_baseball_bat.gdt','utf8');
for(const name of ['vm_t9_bat_melee_miss','vm_t9_bat_melee_miss_02','vm_t9_bat_melee_in']){
 const block=batSource.match(new RegExp('"'+name+'" \\( "xanim.gdf" \\)\\s*\\{([\\s\\S]*?)\\n\\t\\}'))[1];
 assert(block.includes('"customnote1action" "2D Sound"'));
 assert(block.includes('"customnote1actionparam1" "tod_bat_swing"'));
 assert(block.includes('"customnote1frame" "4"'));
}
console.log('Swish: both empty swing clips and the lunge carry a native sound note.');
const swishes=fs.readFileSync('sound/aliases/tod_baseball_bat.csv','utf8').trim().split(/\r?\n/).map(r=>r.split(',')).filter(r=>r[0]==='tod_bat_swing');
assert.equal(swishes.length,2);
assert.equal(new Set(swishes.map(r=>r[3])).size,2);
for(const row of swishes){
 assert.equal(row[42],'1','equal native selection probability');
 assert(fs.existsSync('sound_assets/'+row[3].replace(/\\/g,'/')));
 assert.equal(row[8],'','no secondary whoosh layered on top');
}
console.log('Whiffs: two distinct supplied WAVs share one equally weighted random alias.');

// ---------------------------------------------------------------------------
// THE HOOP (v19.18): the bat target above the base upgrade station.
// ---------------------------------------------------------------------------
// 1. Every fling threads the watcher, AFTER the launch (a watcher on a body
//    that never left the ground would just time out, but the order is the
//    contract: the impulse is applied before anyone reads the spine).
{
 const hr=body('bat_fling');
 const li=hr.indexOf('LaunchRagdoll('),wi=hr.indexOf('thread hoop_arc('),ci=hr.indexOf('clientfield::set( "tod_hoop_watch", 1 )');
 assert(li>0&&wi>li,'bat_fling threads hoop_arc after LaunchRagdoll');
 assert(ci>li&&ci<wi,'the client flight log is armed after the launch');
 // Live: one launch = one watcher; a refused death (elite) = no watcher.
 env.roll=0.5;env.critRoll=99;env.self=victim();env.launches=0;env.watches=0;env.cfsets=0;env.test({player:true});
 assert.equal(env.launches,1);assert.equal(env.watches,1,'the fling arms exactly one hoop arc');assert.equal(env.cfsets,1,'and one client flight log');
 env.self=victim(undefined,{is_boss:true});env.launches=0;env.watches=0;env.cfsets=0;env.test({player:true});
 assert.equal(env.watches,0,'no fling, no watcher');
}
// 1b. THE LOFT (v19.18b): an upward aim keeps its pitch, a downward aim is
//     flattened, a level aim is unchanged — exercised through the real helper.
{
 let d=body('bat_launch_dir').replace(/attacker GetPlayerAngles\(\)/g,'attacker.ang')
  .replace(/\( fwd\[ 0 \], fwd\[ 1 \], 0 \)/g,'[fwd[0],fwd[1],0]');
 const denv={AnglesToForward:a=>a,VectorNormalize:v=>{const n=Math.hypot(...v);return v.map(x=>x/n);}};
 vm.createContext(denv);
 vm.runInContext(`function dir(attacker){let fwd;${d}}`,denv);
 const near3=(v,w)=>v.forEach((x,i)=>assert(Math.abs(x-w[i])<1e-9,`dir ${v} vs ${w}`));
 near3(denv.dir({ang:[0.6,0,0.8]}),[0.6,0,0.8]);              // aimed up: loft kept
 near3(denv.dir({ang:[0.6,0,-0.8]}),[1,0,0]);                 // aimed down: flattened
 near3(denv.dir({ang:[0,1,0]}),[0,1,0]);                      // level: unchanged
}
// 2. The box test is inclusive on every axis and rejects each axis alone.
// v19.18c: the box is grown by TOD_HOOP_SLOP on every side (a body draped
// over the rim still counts); inclusive at the grown edge, out one past it.
env.TOD_HOOP_SLOP=D('TOD_HOOP_SLOP');
vm.runInContext(`function inside(p,lo,hi){${body('hoop_inside')
 .replace(/lo - \( TOD_HOOP_SLOP, TOD_HOOP_SLOP, TOD_HOOP_SLOP \)/,'lo.map(x=>x-TOD_HOOP_SLOP)')
 .replace(/hi \+ \( TOD_HOOP_SLOP, TOD_HOOP_SLOP, TOD_HOOP_SLOP \)/,'hi.map(x=>x+TOD_HOOP_SLOP)')}}`,env);
{
 const S=env.TOD_HOOP_SLOP;assert(S>0&&S<=32,'a rim-sized slop (v19.20b: 24 - a body clipping the rim still counts, nothing wider)');
 const lo=[-48,-272,200],hi=[48,-192,296];
 for(const p of [[0,-230,250],[-48-S,-272-S,200-S],[48+S,-192+S,296+S]])assert(env.inside(p,lo,hi),'inside '+p);
 for(const p of [[49+S,-230,290],[-49-S,-230,290],[0,-273-S,290],[0,-191+S,290],[0,-230,199-S],[0,-230,297+S]])assert(!env.inside(p,lo,hi),'outside '+p);
}
// 3. hoop_score pays ONCE per body, through zm_score, with the kit popup and
//    the 3D cue — and a swinger who left is a basket nobody is paid for.
{
 const HP=D('TOD_HOOP_PTS');
 let code=body('hoop_score')
  .replace(/attacker zm_score::add_to_player_score\( TOD_HOOP_PTS \)/,'score(attacker,TOD_HOOP_PTS)')
  .replace(/attacker LuiNotifyEvent\( &"score_event", 2, &"ZM_AETHERIUM_KF_HOOP", TOD_HOOP_PTS \)/,'popup(attacker,TOD_HOOP_PTS)')
  .replace(/score_emitter\(\)/,'sfx(TOD_HOOP_SFX_ORG)')
  .replace(/attacker GetEntityNumber\(\)/g,'0');
 assert(!/zm_score|LuiNotifyEvent|play_sound|PlayLocalSound/.test(code),'every native call in hoop_score is mocked');
 Object.assign(env,{TOD_HOOP_PTS:HP,TOD_HOOP_SFX_ORG:[0,-950,60],TOD_HOOP_SFX_SECS:5,hoop_log:()=>{},score:(a,n)=>{env.paid+=n;},popup:()=>{env.popups++;},sfx:()=>{env.sfxs++;}});
 vm.runInContext(`function hscore(attacker,p,scale,crit,lane){${code}}`,env);
 env.paid=0;env.popups=0;env.sfxs=0;
 env.hscore({player:true},[0,-230,250],1,false);
 assert.equal(env.paid,HP,'one basket pays exactly TOD_HOOP_PTS');
 assert.equal(env.popups,1);assert.equal(env.sfxs,1);
 env.paid=0;env.popups=0;
 env.hscore(undefined,[0,-230,250],1,false);
 assert.equal(env.paid,0,'no swinger, no payout');
 assert.equal(HP,50,'the user asked for 20 (v19.18); the lead tester for 50 (2026-10-01: "buff it to 50+")');
 // v19.20: the once-per-fling guarantee moved to hoop_arc (one hoop_pay_after per fling, on the SWINGER's thread)
 const ha=body('hoop_arc');
 assert.equal((ha.match(/hoop_pay_after\(/g)||[]).length,1,'hoop_arc pays through exactly one hoop_pay_after');
 assert(/attacker thread hoop_pay_after\(/.test(ha),'the payout thread is the swinger\'s, not the corpse\'s');
 assert(!/self hoop_score/.test(ha),'the corpse never pays itself');
 assert(/self endon\( "disconnect" \)/.test(body('hoop_pay_after')),'the payout waits on the swinger and dies with them');
}
// 3b. THE ARC (v19.20b): the real hoop_trace_arc integrator, native calls mocked, driven with the PER-AXIS
//     constants hoop_arc uses. A launch aimed at the box from the arena floor scores; a ceiling in the way stops
//     it; the same launch aimed away misses. Then the real run: the four launches of the 2026-09-16 16:34 log the
//     client measured INSIDE the hole must score, and the two it measured on the wall under it must not.
{
 const KH=D('TOD_HOOP_ARC_KH'),KZ=D('TOD_HOOP_ARC_KZ'),G=D('TOD_HOOP_GRAVITY'),LIFT=D('TOD_HOOP_ARC_LIFT'),DT=D('TOD_HOOP_ARC_DT'),SECS=D('TOD_HOOP_ARC_SECS');
 assert(KH>0&&KZ>0&&G>0&&DT>0&&SECS>0);
 let code=body('hoop_trace_arc')
  .replace(/p0 \+ VectorScale\( v, t \) \+ \( 0, 0, -0\.5 \* TOD_HOOP_GRAVITY \* t \* t \)/,'[p0[0]+v[0]*t,p0[1]+v[1]*t,p0[2]+v[2]*t-0.5*TOD_HOOP_GRAVITY*t*t]')
  .replace(/hoop_inside\(/g,'inside(').replace(/BulletTrace\(/g,'btrace(').replace(/trace\[ "(\w+)" \]/g,'trace.$1')
  .replace(/r = \[\];/,'r = {};').replace(/r\[ "(\w+)" \]/g,'r.$1');
 assert(!/BulletTrace|hoop_inside/.test(code),'every native call in hoop_trace_arc is mocked');
 // the world: the core's south face is the plane y = -256 for |x| < 400 (the hole is the box cut into it); the floor is z = 0
 Object.assign(env,{TOD_HOOP_GRAVITY:G,TOD_HOOP_ARC_LIFT:LIFT,TOD_HOOP_ARC_DT:DT,TOD_HOOP_ARC_SECS:SECS,
  btrace:(a,b)=>{ const hitY=(a[1]<=-256&&b[1]>-256&&Math.abs(b[0])<400), hitZ=(b[2]<0&&a[2]>=0), hitC=(env.ceiling!==undefined&&b[2]>env.ceiling);
   if(!hitY&&!hitZ&&!hitC) return{fraction:1,position:b};
   const f=hitC?(env.ceiling-a[2])/(b[2]-a[2]):hitY?(-256-a[1])/(b[1]-a[1]):(0-a[2])/(b[2]-a[2]);
   return{fraction:f,position:[a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f,a[2]+(b[2]-a[2])*f]};}});
 vm.runInContext(`function tarc(p0,v,lo,hi,ignore){let r,p,t,apex,q,trace;${code}}`,env);
 const lo=[-48,-272,200],hi=[48,-192,296];
 const fly=(from,imp)=>env.tarc([from[0],from[1],from[2]+LIFT],[imp[0]*KH,imp[1]*KH,imp[2]*KZ],lo,hi).result;
 // the solved launch: v that lands the arc's centre on the box centre from (0,-700,0) in T = 1 s
 const p0=[0,-700,LIFT],tgt=[0,-232,248],T=1.0;
 const v=[(tgt[0]-p0[0])/T,(tgt[1]-p0[1])/T,(tgt[2]-p0[2]+0.5*G*T*T)/T];
 env.ceiling=undefined;
 assert.equal(env.tarc(p0,v,lo,hi).result,'basket','an arc through the box scores');
 env.ceiling=200;
 assert.equal(env.tarc(p0,v,lo,hi).result,'miss','a ceiling at 200 stops the arc short of the box');
 env.ceiling=undefined;
 assert.equal(env.tarc(p0,[v[0],-v[1],v[2]],lo,hi).result,'miss','the same launch aimed away misses');
 // THE REAL RUN (tmp/elite_tracking/runs/20260916_163412_910_98bfb53a): launch origin + impulse from [TOD_BAT] LAUNCH,
 // the verdict from [TOD_HOOP_C] BASKET/FLIGHT (the client saw the ragdoll itself). in = measured inside the hole.
 const RUN=[
  {from:[-163.324,-668.932,0.125],imp:[61.7734,170.836,111.015],in:true},    // ent 25 ms 80000: landed (-1,-276,203)
  {from:[-166.569,-743.532,0.125],imp:[77.3118,213.359,138.682],in:true},    // ent 28 ms 86550: landed (13,-215,247)
  {from:[-202.655,-798.61,0.9517],imp:[80.0562,220.933,143.605],in:true},    // ent 29 ms 87550: landed (25,-201,248)
  {from:[100.741,-650.25,0.125],imp:[-35.7243,126.539,80.3519],in:false},    // ent 30 ms 73450: hit the face at z 33
  {from:[-170.83,-692.134,0.125],imp:[44.5413,122.922,79.8984],in:false},    // ent 27 ms 85700: hit the face at z 50
 ];
 for(const r of RUN) assert.equal(fly(r.from,r.imp)==='basket',r.in,'real launch '+JSON.stringify(r.imp)+' should '+(r.in?'score':'miss'));
 const ha=body('hoop_arc');
 assert(/impulse\[ 0 \] \* TOD_HOOP_ARC_KH, impulse\[ 1 \] \* TOD_HOOP_ARC_KH, impulse\[ 2 \] \* TOD_HOOP_ARC_KZ/.test(ha),'hoop_arc flies per-axis constants');
 assert(!/TOD_HOOP_ARC_K_MIN|for \( k =/.test(ha),'the fan is gone');
 assert.equal((ha.match(/hoop_trace_arc\(/g)||[]).length,1,'one arc per fling');
 assert(/wait TOD_HOOP_ARC_DT;[\s\S]*hoop_trace_arc\( p0, v, lo, hi, self \)/.test(ha),'v19.20c: the arc is traced a frame after the launch, ignoring the body (the death-frame trace started inside it)');
 assert(/BulletTrace\( p, q, false, ignore \)/.test(body('hoop_trace_arc')),'the integrator passes the body through to every trace');
 assert(/score_emitter\(\);/.test(body('hoop_score')),'v19.22: the cue is played by a spawned emitter at the bay centre');
 {const em=body('score_emitter');
  assert(/Spawn\( "script_origin", TOD_HOOP_SFX_ORG \)/.test(em),'the emitter is a script_origin at the bay centre');
  assert(/e PlaySound\( TOD_HOOP_SFX \)/.test(em),'... which PLAYS the alias itself (the lane the laugh uses)');
  assert(/if \( !isdefined\( e \) \)/.test(em),'... guarded against an exhausted entity pool');
  assert(/self Delete\(\)/.test(body('score_emitter_cleanup')),'... and deletes itself after the clip');
  assert(!src.includes('tod_perk_scatter'),'v19.22: no _tod_perk_scatter import (it closed a module cycle)');}
 {const csv=fs.readFileSync('sound/aliases/tod_ui.csv','utf8'); const m=csv.match(/^tod_hoop_score,.*$/m); assert(m,'the cue alias is one the map ships'); assert(/,3d,/.test(m[0])&&/tod_hoop_score\.wav/.test(m[0]),'... a 3D alias on the banked wav'); assert(fs.existsSync('sound_assets/tod/sfx/tod_hoop_score.wav'),'the wav is in the bank tree');}
 {const org=src.match(/#define TOD_HOOP_SFX_ORG\s+\( ([-\d.]+), ([-\d.]+), ([-\d.]+) \)/); assert(org,'TOD_HOOP_SFX_ORG defined'); const tp=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_teleport.gsc','utf8'); const pads=[...tp.matchAll(/up_orgs\[ \d \] = \(\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\s*\);/g)].map(m=>[+m[1],+m[2],+m[3]]); assert.equal(pads.length,4,'four up pads'); const cx=pads.reduce((a,p)=>a+p[0],0)/4, cy=pads.reduce((a,p)=>a+p[1],0)/4; assert.equal(+org[1],cx,'cue x = the up pads centre'); assert.equal(+org[2],cy,'cue y = the up pads centre'); assert(+org[3]>=48&&+org[3]<=72,'cue at eye height');}
}
// 3c. The CLIENT flight log's box is LOCKSTEP with the generated one, and the
//     actor clientfield is registered on both VMs with the same shape.
{
 const csc=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_hoop.csc','utf8');
 const C=n=>{const m=csc.match(new RegExp('#define\\s+'+n+'\\s+([-\\d.]+)'));assert(m,'csc define '+n);return parseFloat(m[1]);};
 const bd=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_breather_data.gsc','utf8');
 const v=n=>bd.match(new RegExp('function '+n+'\\(\\)\\s*\\{\\s*return \\( ([-\\d.]+), ([-\\d.]+), ([-\\d.]+) \\);'))?.slice(1,4).map(Number);
 const lo=v('base_hoop_lo'),hi=v('base_hoop_hi');
 assert.deepEqual([C('TOD_HOOP_C_X1'),C('TOD_HOOP_C_Y1'),C('TOD_HOOP_C_Z1')],lo,'csc box lo = generated lo');
 assert.deepEqual([C('TOD_HOOP_C_X2'),C('TOD_HOOP_C_Y2'),C('TOD_HOOP_C_Z2')],hi,'csc box hi = generated hi');
 assert.equal(C('TOD_HOOP_C_SLOP'),D('TOD_HOOP_SLOP'),'same slop');
 assert(/clientfield::register\( "actor", "tod_hoop_watch", VERSION_SHIP, 1, "int" \);/.test(src),'gsc registers the actor field');
 assert(/clientfield::register\( "actor", "tod_hoop_watch", VERSION_SHIP, 1, "int", &watch_cb/.test(csc),'csc registers the same field with its callback');
 assert(/scriptparsetree,scripts\/zm\/zm_tower_of_doom\/_tod_hoop\.csc/.test(fs.readFileSync('zone_source/zm_tower_of_doom.zone','utf8')),'csc zoned');
 assert(/#using scripts\\zm\\zm_tower_of_doom\\_tod_hoop;/.test(fs.readFileSync('scripts/zm/zm_tower_of_doom.csc','utf8')),'csc wired from the map csc');
}
// 4. LOCKSTEP: the box the script reads is the recess the generator cut. The
//    rim bars in the .map frame exactly base_hoop_lo/_hi (rim standoff
//    included in lo.y), and the lap-1 south-face boxes carry the cut.
{
 const bd=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_breather_data.gsc','utf8');
 const v=n=>bd.match(new RegExp('function '+n+'\\(\\)\\s*\\{\\s*return \\( ([-\\d.]+), ([-\\d.]+), ([-\\d.]+) \\);'))?.slice(1,4).map(Number);
 const lo=v('base_hoop_lo'),hi=v('base_hoop_hi');
 assert(lo&&hi,'base_hoop_lo/_hi are emitted');
 assert(lo[0]<hi[0]&&lo[1]<hi[1]&&lo[2]<hi[2],'a real box');
 const map=fs.readFileSync('map_source/zm/zm_tower_of_doom.map','utf8');
 const brush=label=>{const i=map.indexOf('// brush ');let m,re=/\/\/ brush \d+ — (.*)\n\{([\s\S]*?)\n\}/g,out=null;while((m=re.exec(map))){if(m[1]===label){out=m[2];break;}}return out;};
 const ext=(text)=>{const xs=[],ys=[],zs=[];for(const l of text.split('\n')){const m=l.match(/^ \( (\S+) (\S+) (\S+) \) \( (\S+) (\S+) (\S+) \) \( (\S+) (\S+) (\S+) \)/);if(!m)continue;const n=m.slice(1,10).map(Number);if(n[0]===n[3]&&n[3]===n[6])xs.push(n[0]);if(n[1]===n[4]&&n[4]===n[7])ys.push(n[1]);if(n[2]===n[5]&&n[5]===n[8])zs.push(n[2]);}return{x:[Math.min(...xs),Math.max(...xs)],y:[Math.min(...ys),Math.max(...ys)],z:[Math.min(...zs),Math.max(...zs)]};};
 const bot=ext(brush('core hoop rim bottom')),top=ext(brush('core hoop rim top')),W=ext(brush('core hoop rim W')),E=ext(brush('core hoop rim E')),board=ext(brush('core hoop backboard'));
 assert.equal(bot.z[1],lo[2],'rim bottom bar meets the box floor');
 assert.equal(top.z[0],hi[2],'rim top bar meets the box ceiling');
 assert.equal(W.x[1],lo[0]);assert.equal(E.x[0],hi[0]);
 assert.equal(bot.y[0],lo[1],'the box starts at the rim standoff');
 assert.equal(board.y[1],hi[1],'the box ends at the recess back wall');
 for(const l of ['core band lap1 spine NS below hoop','core band lap1 spine NS above hoop','core band lap1 SW W of hoop','core band lap1 SE E of hoop'])assert(brush(l),'recess piece '+l);
 assert(!brush('core band lap2 SW W of hoop'),'only lap 1 is cut');
 assert(/REFERENCE\s+KF_HOOP\s*\r?\nLANG_ENGLISH\s+"Score"/.test(fs.readFileSync('localizedstrings/zm_aetherium.str','utf8')),'the kill-feed string exists');
 assert(/#precache\( "string", "ZM_AETHERIUM_KF_HOOP" \)/.test(src),'and is precached');
 console.log(`Hoop: box x[${lo[0]},${hi[0]}] y[${lo[1]},${hi[1]}] z[${lo[2]},${hi[2]}] matches the cut rim; single payout of ${D('TOD_HOOP_PTS')} through zm_score.`);
}
