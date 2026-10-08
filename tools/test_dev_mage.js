// Execute the actual dev-client controller with native calls mocked.
// Tests lifecycle/weapon state, not whether BO3 renders or admits a test client.
const fs=require('fs'), vm=require('vm'), assert=require('assert/strict');
const src=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_dev_mage.gsc','utf8');
function body(name,source=src){
  const s=source.replace(/\/\/[^\n]*/g,'');
  const a=s.indexOf('{',s.indexOf('function '+name+'('));
  assert(a>=0,name);let z=a+1,d=1;
  while(d){if(s[z]==='{')d++;if(s[z]==='}')d--;z++;}return s.slice(a+1,z-1);
}
function translate(s){return s
  .replace(/\blevel\s+thread\s+tod_mage_elements::(\w+)\(/g,'level.$1(')
  .replace(/foreach\s*\(\s*(\w+)\s+in\s+([^\n]+)\s*\)/g,'for (const $1 of $2)')
  .replace(/\bbot\s+thread\s+zm::(\w+)\(/g,'bot.$1(')
  .replace(/\b(bot|owner|self|level)\s+(?:tod_classes::)?(\w+)\(/g,'$1.$2(')
  .replace(/tod_classes::|util::/g,'')
  .replace(/\.size\b/g,'.length')
  .replace(/\( 0, angles\[1\], 0 \)/g,'[0,angles[1],0]')
  .replace(/\bwait\s+([^;]+);/g,'yield $1;');}
function scenario({dev=true,count=1,admit=true,spawn=true,lateSpectator=false,recover=true,arch=undefined,source=src}={}){
  let now=0,addedAt,parked=false;const events=[],dvars={},forms=new Map();
  const owner={origin:[0,0,0],IPrintLnBold:s=>events.push(['toast',s])};
  const bot={sessionstate:spawn?'playing':'spectator',pers:{},tod_levels:spawn?{}:undefined,
    player_initialized:spawn,spectator_respawn:spawn?{}:undefined,
    items:new Set(),tiers:{},current:null,
    IsTestClient:()=>true,BotDropClient:()=>events.push(['drop']),GetEntityNumber:()=>1,
    BotTakeManualControl:()=>events.push(['manual']),BotSetMoveMagnitude:n=>assert.equal(n,0),
    BotReleaseButtons:()=>{},SetOrigin:p=>events.push(['place',p]),SetPlayerAngles:()=>{},EnableInvulnerability:()=>{},
    GetWeaponsListPrimaries:()=>[...bot.items],HasWeapon:w=>bot.items.has(w),
    TakeWeapon:w=>{bot.items.delete(w);events.push(['take',w]);},
    give_staff:w=>{bot.items.add(w);events.push(['give',w]);},
    SwitchToWeaponImmediate:w=>{assert(bot.items.has(w));bot.current=w;events.push(['switch',w]);},staff_log:()=>{}};
  bot.spectator_respawn_player=()=>{
    assert(bot.tod_dev_mage_dummy && bot.IsTestClient());
    assert.equal(bot.sessionstate,'spectator');assert(bot.player_initialized && bot.spectator_respawn);
    events.push(['respawn',now]);if(recover)bot.sessionstate='playing';
  };
  const names=['tod_staff_lightning_q0','tod_staff_fire_q0','tod_staff_ice_q0d0'];
  for(const [i,n] of names.entries())for(const packed of [false,true])forms.set(n+packed,{name:n+(packed?'+gmod6':''),id:i+1,packed});
  const ctx={level:{tod_dev:dev,tod_class_select_done:true,endon:()=>{},tod_dev_arch_test:arch,
      dev_arch_preview:b=>events.push(['arch_preview',now,b])},
    IS_TRUE:v=>v===true,isdefined:v=>v!==undefined&&v!==null,IsAlive:v=>v!==undefined,
    GetDvarInt:n=>dvars[n]||0,SetDvar:(n,v)=>dvars[n]=v,GetTime:()=>now,
    GetHostPlayer:()=>owner,GetPlayers:()=>Array(count).fill(owner),place:()=>[128,0,2],
    VectorToAngles:()=>[0,180,0],array:(...x)=>x,Int:v=>Number(v),
    AddTestClient:()=>{events.push(['add']);addedAt=now;return admit?bot:undefined;},
    assign_class:(b,k)=>assert.equal(k,'mage'),weapon_or_zm:n=>forms.get(n+false),
    pap_tier_set:(b,w,t)=>b.tiers[w.id]=t,
    staff_presentation:(b,w)=>forms.get(names[w.id-1]+!!b.tiers[w.id]),
    staff_is_packed:w=>w.packed,pap_staff_id:w=>w.id,log:s=>events.push(['log',s,now])};
  // The module's own numeric #defines (the Archmage preview cadence) as globals.
  for(const m of source.matchAll(/^#define\s+(\w+)\s+(\d+)\s*$/gm))ctx[m[1]]=Number(m[2]);
  vm.createContext(ctx);
  const functions=[['enabled',''],['ready','bot'],['remove','bot,reason'],['show_staff','bot,index'],['run','']];
  if(source.includes('function wait_ready('))functions.push(['spawn_state','bot'],['wait_ready','bot,owner']);
  for(const [n,args] of functions){
    let code=translate(body(n,source));
    // Vector maths belongs to the native placement check, tested separately in game.
    code=code.replace('owner.origin - point','owner.origin');
    if(n==='run')code=code.replace(/wait_ready\( bot, owner \)/g,'(yield* wait_ready( bot, owner ))');
    vm.runInContext('function'+(['run','wait_ready'].includes(n)?'*':'')+' '+n+'('+args+'){'+code+'}',ctx);
  }
  const gen=ctx.run();
  function step(){const r=gen.next();if(!r.done){assert(r.value>=0);now+=r.value*1000;
    // Reproduce the user's native log: initial playing state is transient.
    if(lateSpectator && addedAt!==undefined && now-addedAt>=500 && !parked){bot.sessionstate='spectator';parked=true;}
  }return r;}
  function until(pred,max=250){for(let i=0;i<max;i++){if(pred())return;const r=step();if(r.done){assert(pred(),'controller ended before condition');return;}}assert.fail('controller hung');}
  return {ctx,bot,owner,events,dvars,step,until};
}
for(const opts of [{dev:false},{count:4},{admit:false}]){
  const s=scenario(opts);let done=false;for(let i=0;i<8&&!done;i++)done=s.step().done;
  assert(done);assert.equal(s.events.filter(e=>e[0]==='add').length,opts.admit===false?1:0);
}
{
  const s=scenario({spawn:false});s.until(()=>s.events.some(e=>e[0]==='drop'));
  assert(!s.events.some(e=>e[0]==='switch'));assert.equal(s.ctx.level.tod_dev_mage_bot,undefined);
}
{
  // No secondary flag or console setup is supplied: dev mode alone starts it.
  const s=scenario({lateSpectator:true});s.until(()=>s.events.some(e=>e[0]==='switch'));
  assert.equal(s.events.filter(e=>e[0]==='respawn').length,1);
  assert(!s.events.some(e=>e[0]==='drop'),'late join must remain in the match');
  assert.equal(s.bot.sessionstate,'playing');
  assert(s.events.some(e=>e[0]==='log'&&e[1].includes('state=spectator')));
  s.dvars.tod_mage_dummy=0;s.until(()=>s.events.some(e=>e[0]==='drop'));
}
{
  const s=scenario({lateSpectator:true,recover:false});s.until(()=>s.events.some(e=>e[0]==='drop'));
  assert.equal(s.events.filter(e=>e[0]==='respawn').length,3,'failed stock returns have a finite retry budget');
  assert(!s.events.some(e=>e[0]==='log'&&e[1].startsWith('READY')),'never announce a spectator as ready');
}
{
  const s=scenario({spawn:false});s.step();s.step();s.dvars.tod_mage_dummy=0;
  s.until(()=>s.events.some(e=>e[0]==='drop'));
  assert(!s.events.some(e=>e[0]==='respawn'),'cancel during setup does not force a spawn');
}
{
  const s=scenario();s.until(()=>s.events.some(e=>e[0]==='switch'));
  assert.equal(s.bot.tod_class,'mage');assert.equal(s.bot.tod_tier,3);assert.equal(s.bot.tod_dev_mage_dummy,true);
  assert.equal(s.events.filter(e=>e[0]==='add').length,1);
  s.until(()=>s.events.filter(e=>e[0]==='switch').length===6,300);
  assert.deepEqual(s.events.filter(e=>e[0]==='switch').map(e=>[e[1].id,e[1].packed]),[[1,false],[2,false],[3,false],[1,true],[2,true],[3,true]]);
  assert.equal(s.bot.items.size,3,'same-element replacement does not leak weapon inventory');
  s.dvars.tod_mage_dummy_slot=2;s.step();assert.equal(s.bot.current.id,2);assert.equal(s.bot.current.packed,false);
  const switches=s.events.filter(e=>e[0]==='switch').length;
  for(let i=0;i<60;i++)s.step();assert.equal(s.events.filter(e=>e[0]==='switch').length,switches,'pinned slot stays selected');
  s.ctx.level.tod_upgrade_pause=true;s.dvars.tod_mage_dummy_slot=6;
  for(let i=0;i<60;i++)s.step();assert.equal(s.bot.current.id,2,'no weapon changes under a card pause');
  s.ctx.level.tod_upgrade_pause=false;s.step();assert.equal(s.bot.current.id,3);assert(s.bot.current.packed);
  s.dvars.tod_mage_dummy=0;s.until(()=>s.events.some(e=>e[0]==='drop'));
  assert.equal(s.ctx.level.tod_dev_mage_bot,undefined);
}
{
  const s=scenario();s.until(()=>s.events.some(e=>e[0]==='switch'));
  s.ctx.owner=undefined;s.until(()=>s.events.some(e=>e[0]==='drop'));
}
{
  // tod_dev_arch_test (2026-10-01): the dummy shows the Archmage form 8 s after READY,
  // then every 30 s, on the dummy, never under a card pause; nothing without the flag.
  const s=scenario({arch:true});s.until(()=>s.events.filter(e=>e[0]==='arch_preview').length===2,800);
  const ready=s.events.find(e=>e[0]==='log'&&e[1].startsWith('READY'))[2];
  const p=s.events.filter(e=>e[0]==='arch_preview');
  assert(p.every(e=>e[2]===s.bot),'the preview plays on the dummy');
  assert(p[0][1]-ready>=s.ctx.TOD_DEV_ARCH_PREVIEW_FIRST && p[0][1]-ready<s.ctx.TOD_DEV_ARCH_PREVIEW_FIRST+500,'first preview '+(p[0][1]-ready));
  assert(Math.abs(p[1][1]-p[0][1]-s.ctx.TOD_DEV_ARCH_PREVIEW_EVERY)<=250,'cadence '+(p[1][1]-p[0][1]));
  assert(s.events.some(e=>e[0]==='toast'&&/Archmage/.test(e[1])),'the tester is told');
  s.ctx.level.tod_upgrade_pause=true;for(let i=0;i<200;i++)s.step();
  assert.equal(s.events.filter(e=>e[0]==='arch_preview').length,2,'no preview under a card pause');
  s.ctx.level.tod_upgrade_pause=false;s.step();
  assert.equal(s.events.filter(e=>e[0]==='arch_preview').length,3,'the overdue preview plays on the unpause');
  const q=scenario();q.until(()=>q.events.some(e=>e[0]==='switch'));for(let i=0;i<400;i++)q.step();
  assert(!q.events.some(e=>e[0]==='arch_preview'||(e[0]==='toast'&&/Archmage/.test(e[1]))),'nothing without tod_dev_arch_test');
}
const upgrades=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc','utf8');
assert(/IS_TRUE\( level\.tod_dev \) && IS_TRUE\( p\.tod_dev_mage_dummy \) \)\s*continue;/.test(upgrades),'preview client cannot hold an upgrade choice open');
const main=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_main.gsc','utf8');
assert(/if \( IS_TRUE\( level\.tod_dev \) \)\s*level thread tod_dev_mage::run\(\);/.test(main),'dev mode automatically starts the preview');
if(process.argv.includes('--old-reproduction')){
  const old=fs.readFileSync('tmp/staff_dummy_spawn_20260923/before/_tod_dev_mage.gsc','utf8');
  const s=scenario({lateSpectator:true,source:old});s.ctx.level.tod_dev_mage_dummy=true;
  s.until(()=>s.events.some(e=>e[0]==='drop'));
  assert(!s.events.some(e=>e[0]==='switch'));
  assert(s.events.some(e=>e[0]==='log'&&e[1].startsWith('READY')),'old bug announces READY then immediately drops');
  console.log('Original script reproduces native READY + immediate REMOVE with zero displayed staffs.');
}
console.log('Dev Mage: automatic dev startup, transient playing-to-spectator recovery, bounded failed recovery, setup cancellation, full lobby/failure/timeout, six forms, inventory, pin/pause/stop and disconnect cleanup, Archmage preview cadence passed. Native visuals still need user testing.');
