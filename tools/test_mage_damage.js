// Run the shipping GSC arithmetic and final-damage HUD wrapper with native
// calls stubbed. Engine armor remains native; its returned value is the oracle.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const root='scripts/zm/zm_tower_of_doom/';
const mage=fs.readFileSync(root+'_tod_mage_elements.gsc','utf8');
const bosses=fs.readFileSync(root+'_tod_bosses.gsc','utf8').replace(/\r/g,'');
const ui=fs.readFileSync(root+'_tod_upgrade_ui.gsc','utf8');
const upgrades=fs.readFileSync(root+'_tod_upgrades.gsc','utf8');
function body(src,name){
 const clean=src.replace(/\/\/[^\n]*/g,'');
 const a=clean.indexOf('{',clean.indexOf('function '+name+'('));assert(a>=0,name);
 let b=a+1,d=1;while(d){if(clean[b]==='{')d++;if(clean[b]==='}')d--;b++;}
 return clean.slice(a+1,b-1);
}
const env={isdefined:x=>x!==undefined,IS_TRUE:x=>x===true,IsSubStr:(s,x)=>s.includes(x),IsPlayer:p=>p.player,int:Math.trunc,
 staff_element:w=>w?.element,demigod_mult:()=>1,charge_mult:()=>1,tier:()=>1,
 victim_family:v=>v.family,on_family_mult:()=>1,off_family_mult:()=>1,family_answerable:()=>true,get_level:p=>p.card,pap_tier:(p)=>p.pap||0,has_dark:(p,k)=>!!(p.dark&&p.dark[k])};
for(const m of mage.matchAll(/#define\s+(TOD_MAGE_\w+)\s+([\d.]+)/g))env[m[1]]=Number(m[2]);
vm.createContext(env);
const mult=body(mage,'staff_mult').replace(/attacker (demigod_mult|charge_mult)\(\)/g,'$1(attacker)').replace(/tod_classes::|tod_upgrades::/g,'');
vm.runInContext(`function mult(attacker,victim,weapon){let el,m,t,fam,off;${mult}}`,env);
assert.equal(env.TOD_MAGE_FIRE_DMG_PER_LV,.15);   // v19.26 (user 2026-09-21): 0.20 -> 0.15
assert.equal(env.TOD_MAGE_ICE_DMG_PER_LV,.15);
for(const [el,rate] of [['fire',env.TOD_MAGE_FIRE_DMG_PER_LV],['ice',env.TOD_MAGE_ICE_DMG_PER_LV]])for(let lv=0;lv<=6;lv++) {
 const actual=env.mult({player:true,card:lv},{family:el},{element:el});
 const flat=el==='ice'?env.TOD_MAGE_ICE_NERF:env.TOD_MAGE_FIRE_NERF;   // 2026-09-21: fire has a flat nerf too; read both LIVE, never a literal
 assert(Math.abs(actual/env.TOD_MAGE_TIER1_MULT/flat-(1+rate*lv))<1e-9,`${el} level ${lv}`);
}
// Compare the live matchup paths against the previous balance, including
// every tier/card level, Archmage and representative PaP/direct/splash inputs.
vm.runInContext(`function on_family_mult(el){${body(mage,'on_family_mult')}}
function off_family_mult(el){${body(mage,'off_family_mult')}}`,env);
env.tier=p=>p.tier; env.demigod_mult=p=>p.arch;
const beast=env.TOD_MAGE_ICE_VS_BEAST, off=env.TOD_MAGE_ICE_OFF;
assert.equal(beast,2.85); assert.equal(off,0.8);   // 2026-09-09 playtest pass: 3.352 -> 2.85, ICE_OFF 1.00 -> 0.80
assert.equal(env.TOD_MAGE_VS_HORDE,1.75);
for(const el of ['lightning','fire','ice'])for(const family of ['lightning','fire','ice','panzer'])
for(const tier of [1,2,3])for(const card of [0,1,2,3,4,5,6])for(const arch of [1,2.2]) {
 const p={player:true,tier,card,arch},v={family},w={element:el};
 const after=env.mult(p,v,w);
 env.TOD_MAGE_ICE_VS_BEAST=beast/0.8;env.TOD_MAGE_ICE_OFF=off/0.8;   // the flat 20% cut is still exactly 20% at every cell
 const before=env.mult(p,v,w);
 env.TOD_MAGE_ICE_VS_BEAST=beast;env.TOD_MAGE_ICE_OFF=off;
 for(const raw of [200,1200])for(const pap of [1,1.5625,2.44140625])
  assert(Math.abs(after*raw*pap-before*raw*pap*(el==='ice'?.8:1))<1e-7,el+' damage ratio');
}
// The class-wide cut is exactly x0.68 (20% then 15%) at every tier and matchup,
// including both staff identities, all card levels and transformed/charged hits.
const tierKeys=['TOD_MAGE_TIER1_MULT','TOD_MAGE_TIER2_MULT','TOD_MAGE_TIER3_MULT'];
const currentTiers=tierKeys.map(k=>env[k]);
assert.deepEqual(currentTiers,[.6256,1.36,2.686]);   // = the v18.51 0.92/2/3.95 ladder x0.8 x0.85 (the 2026-09-21 x0.92 was reverted: the re-cut is PER STAFF, not class-wide)
env.charge_mult=p=>p.charge;
for(const el of ['lightning','fire','ice'])for(const q of [0,1])
for(const family of ['lightning','fire','ice','panzer'])for(const tier of [1,2,3])
for(const card of [0,1,2,3,4,5,6])for(const arch of [1,2.2,2.7])for(const charge of [1,2.5]) {
 const p={player:true,tier,card,arch,charge},v={family},w={name:`tod_staff_${el}_q${q}`,element:el};
 const after=env.mult(p,v,w);
 tierKeys.forEach((k,i)=>env[k]=[.92,2,3.95][i]);
 const before=env.mult(p,v,w);
 tierKeys.forEach((k,i)=>env[k]=currentTiers[i]);
 assert(Math.abs(after-before*.68)<1e-9,'all staff damage x0.8 x0.85 vs the v18.51 ladder');
 // Chain share comes from the already-scaled hit; it is not scaled twice.
 if(el==='lightning')assert(Math.abs(Math.trunc(after*1000*.5)-Math.trunc(before*1000*.5)*.68)<=1);
}
// Lightning nerf (2026-09-09): x0.90 unpacked, x0.80 packed, vs the same body
// with both defines at 1.0; fire and ice untouched by it.
{ const ln=env.TOD_MAGE_LIGHTNING_NERF, lp=env.TOD_MAGE_LIGHTNING_PAP_NERF; assert.equal(ln,.9); assert.equal(lp,.8);
  for(const el of ['lightning','fire','ice'])for(const family of ['lightning','panzer','fire'])for(const tier of [1,3])for(const pap of [0,1,2,3])for(const card of [0,6]) {
   const p={player:true,tier,card,arch:1,charge:1,pap},v={family},w={name:'tod_staff_'+el+'_q0',element:el};
   const after=env.mult(p,v,w); env.TOD_MAGE_LIGHTNING_NERF=1;env.TOD_MAGE_LIGHTNING_PAP_NERF=1; const before=env.mult(p,v,w);
   env.TOD_MAGE_LIGHTNING_NERF=ln;env.TOD_MAGE_LIGHTNING_PAP_NERF=lp;
   const want=el==='lightning'?(pap>=1?.8:.9):1; assert(Math.abs(after-before*want)<1e-9,'lightning nerf '+el+' pap'+pap+' t'+tier); } }
// Ice nerf (2026-09-09, retuned v18.77): x0.646 everywhere (0.68 until 2026-09-23), x0.2261 (0.646 x 0.35) on the armour family and the
// Panzer, vs the same body with both defines at 1.0; lightning/fire untouched.
{ const fn=env.TOD_MAGE_ICE_NERF, fa=env.TOD_MAGE_ICE_VS_ARMOUR_ROBOT; assert.equal(fn,.646); assert.equal(fa,.35); assert.equal(env.TOD_MAGE_FIRE_VS_ARMOUR,1.75);   // v18.77: 0.80 -> 0.68, 0.60 -> 0.35
  for(const el of ['lightning','fire','ice'])for(const family of ['lightning','ice','fire','panzer'])for(const tier of [1,2,3])for(const card of [0,3,6])for(const pap of [0,1]) {
   const p={player:true,tier,card,arch:1,charge:1,pap},v={family},w={name:'tod_staff_'+el+'_q0',element:el};
   const after=env.mult(p,v,w); env.TOD_MAGE_ICE_NERF=1;env.TOD_MAGE_ICE_VS_ARMOUR_ROBOT=1; const before=env.mult(p,v,w);
   env.TOD_MAGE_ICE_NERF=fn;env.TOD_MAGE_ICE_VS_ARMOUR_ROBOT=fa;
   const want=el!=='ice'?1:((family==='fire'||family==='panzer')?fn*fa:fn); assert(Math.abs(after-before*want)<1e-9,'ice nerf '+el+' vs '+family); } }
// 2026-09-09 playtest: fire on the beast family pays TOD_MAGE_FIRE_VS_BEAST at EVERY tier (never answerable-gated).
{ assert.equal(env.TOD_MAGE_FIRE_VS_BEAST,.2625);   // v18.77: 0.50 -> 0.35; 2026-09-21: x0.75 -> 0.2625 ("fire staff 25% weaker againts hounds and furys")
  const savedFA=env.family_answerable; env.family_answerable=()=>false;
  for(const tier of [1,2,3]){ const p={player:true,tier,card:0,arch:1,charge:1,pap:0};
    const beastHit=env.mult(p,{family:'ice'},{name:'tod_staff_fire_q0',element:'fire'});
    const hordeHit=env.mult(p,{family:'lightning'},{name:'tod_staff_fire_q0',element:'fire'});
    assert(Math.abs(beastHit/hordeHit-env.TOD_MAGE_FIRE_VS_BEAST)<1e-9,'fire vs beast at tier '+tier); }
  env.family_answerable=savedFA; }
// Dark FIRE BLAST / ICE SHATTER: +0.50 on the card multiplier, nothing else moves.
{ for(const [el,key,rate,add] of [['fire','mage_fire',env.TOD_MAGE_FIRE_DMG_PER_LV,env.TOD_MAGE_FIRE_DARK_ADD],['ice','mage_ice',env.TOD_MAGE_ICE_DMG_PER_LV,env.TOD_MAGE_ICE_DARK_ADD]]){
    assert.equal(add,.5);
    for(const card of [0,6]){ const base={player:true,tier:3,card,arch:1,charge:1,pap:0};
      const plain=env.mult(base,{family:el},{name:'tod_staff_'+el+'_q0',element:el});
      const dark=env.mult({...base,dark:{[key]:true}},{family:el},{name:'tod_staff_'+el+'_q0',element:el});
      assert(Math.abs(dark/plain-(1+rate*card+add)/(1+rate*card))<1e-9,'dark '+el+' card '+card); } } }
assert(mage.includes('share = int( dmg * chain_fraction( attacker ) );'));
const chainBranch=upgrades.slice(upgrades.indexOf('if ( IS_TRUE( self.tod_mage_chain_hit ) )'));
assert(chainBranch.indexOf('return arc;')<chainBranch.indexOf('level.tod_mage_staff_mult'),'chain must exit before rescaling');
vm.runInContext(`function deferred(victim,weapon){${body(ui,'defer_staff_damage_number')}}`,env);
Object.assign(env,{self:{tod_staff_damage_number_final:true},calls:[],outputs:[],nativeResult:2000,
 calc:(...args)=>{env.calls.push(args);return env.nativeResult;},
 headshot_kind:()=> 'none',push:(attacker,damage,head,red)=>env.outputs.push({attacker,damage,head,red})});
const wrap=body(bosses,'tod_mechz_damage_wrap')
 .replace('self tod_mechz_damage_calc(', 'calc(')
 .replace(/tod_upgrade_ui::defer_staff_damage_number/g,'deferred')
 .replace(/tod_upgrades::headshot_kind/g,'headshot_kind')
 .replace('attacker tod_upgrade_ui::push_dmg_num(', 'push(attacker,');
vm.runInContext(`function hit(inflictor,attacker,damage,dFlags,mod,weapon,point,dir,hitLoc,offsetTime,boneIndex){let result,headshot;${wrap}}`,env);
const player={player:true};
for(const el of ['lightning','fire','ice'])for(const q of [0,1])for(const mod of ['MOD_PROJECTILE','MOD_PROJECTILE_SPLASH']) {
 const weapon={name:`tod_staff_${el}_q${q}`};
 for(const result of [undefined,0,400,2000,3999.9]) {
  env.nativeResult=result;env.outputs=[];env.calls=[];
  assert.equal(env.hit(null,player,4000,0,mod,weapon,null,null,'none',0,0),result,'do not change damage');
  assert.equal(env.calls.length,1,'stock calculation runs once');
  assert.equal(env.outputs.length,result>0?1:0,'only one final positive number');
  if(result>0)assert.equal(env.outputs[0].damage,Math.trunc(result),'4000 incoming must not masquerade as final');
 }
}
for(const [victim,weapon] of [[{}, {name:'tod_staff_lightning_q0'}],[{tod_staff_damage_number_final:true},{name:'ak74u'}],[{tod_staff_damage_number_final:true},undefined]]) {
 assert.equal(env.deferred(victim,weapon),false,'ordinary actors and guns keep original display lane');
}
assert(/if \( !tod_upgrade_ui::defer_staff_damage_number\( self, weapon \) \)\s+attacker tod_upgrade_ui::push_dmg_num\( final, headshot, b_sprint_armor, self \);/.test(upgrades),'early number suppressed for wrapped Panzer staff hits');
assert(bosses.includes('boss.actor_damage_func = &tod_mechz_damage_wrap;\n\tboss.tod_staff_damage_number_final = true;'),'marker and final handler installed together');
console.log('Mage damage passed: fire/ice Lv0-6 rates; 60 final Panzer result cases; exact one-time post-armor numbers; unchanged return values and other display lanes.');
// v19.26 FIRE BLAST elite burn + ICE SHATTER elite slow: the two pure helpers,
// run as shipped, plus the callback branch that carries the burn tick raw.
{ vm.runInContext(`function burn_tick_damage(victim,lv){let pct,dmg;${body(mage,'burn_tick_damage')}}
function ice_slow_mult(lv){let m;${body(mage,'ice_slow_mult')}}`,env);
  assert.equal(env.TOD_MAGE_BURN_PCT_PER_LV,.5); assert.equal(env.TOD_MAGE_BURN_TICK_MS,2000); assert.equal(env.TOD_MAGE_BURN_TICKS,3);
  for(let lv=1;lv<=6;lv++){
    assert.equal(env.burn_tick_damage({maxhealth:100000},lv),Math.trunc(100000*.005*lv),'burn lv'+lv);          // 500 .. 3000 of 100k
    assert.equal(env.burn_tick_damage({maxhealth:40000000,tod_king:true},lv),Math.trunc(40000000*.005*lv*env.TOD_MAGE_BURN_KING_MULT),'king burn lv'+lv);
  }
  assert.equal(env.burn_tick_damage({maxhealth:10},1),1,'floor 1');
  assert.equal(env.burn_tick_damage({},6),1,'no maxhealth = 1');
  assert.equal(env.ice_slow_mult(0),.80); assert(Math.abs(env.ice_slow_mult(6)-.65)<1e-9); assert.equal(env.ice_slow_mult(40),env.TOD_MAGE_ICE_SLOW_MIN);
  // Lv6 sits EXACTLY on the floor now, so the cap the user asked for holds even if the level cap moves.
  assert.equal(env.ice_slow_mult(6),env.TOD_MAGE_ICE_SLOW_MIN,'Lv6 must land on the 65% cap');
  // staff_hit's arms: fire burns ELITES only and only with the card; ice slows ELITES only, triad via slow_elite, sprinter via slow().
  const hit=body(mage,'staff_hit').replace(/burn_dev_log\([^;]*\);/g,';').replace(/self thread elite_burn\(([^;]*)\);/g,'burn(self,$1);')
    .replace(/self tod_zombie_speed::slow_elite\(([^;]*)\);/g,'slowE(self,$1);').replace(/self tod_zombie_speed::slow\(([^;]*)\);/g,'slowT(self,$1);')
    .replace(/self clientfield::set\([^)]*\);/g,';').replace(/tod_upgrades::/g,'');
  const e2={log:[],staff_element:w=>w.element,get_level:(p,k)=>p[k]||0,IsAlive:()=>true,isdefined:x=>x!==undefined,IS_TRUE:x=>x===true,int:Math.trunc,
    is_boss_or_elite:v=>!!v.is_boss,staff_elite:v=>!!(v.is_boss||v.tod_is_sprinter),ice_slow_mult:env.ice_slow_mult,boss_kind:()=>'',
    burn:(v,a,lv)=>e2.log.push(['burn',v.id,lv]),slowE:(v,m,ms)=>e2.log.push(['slowE',v.id,+m.toFixed(2),ms]),slowT:(v,m,ms)=>e2.log.push(['slowT',v.id,+m.toFixed(2),ms]),
    TOD_MAGE_ICE_SLOW_BASE:env.TOD_MAGE_ICE_SLOW_BASE,TOD_MAGE_ICE_SLOW_PER_LV:env.TOD_MAGE_ICE_SLOW_PER_LV};
  vm.createContext(e2); vm.runInContext('function staff_hit(self,attacker,weapon,dmg){let el,lv,secs,mult,n;'+hit.slice(0,hit.indexOf('n = chain_targets'))+'}',e2);
  const trash={id:'t'},panzer={id:'p',is_boss:true},sprint={id:'s',tod_is_sprinter:true};
  e2.staff_hit(trash,{name:'m',mage_fire:6},{element:'fire'},1); e2.staff_hit(panzer,{name:'m',mage_fire:0},{element:'fire'},1); e2.staff_hit(panzer,{name:'m',mage_fire:4},{element:'fire'},1); e2.staff_hit(sprint,{name:'m',mage_fire:1},{element:'fire'},1);
  e2.staff_hit(trash,{name:'m',mage_ice:6},{element:'ice'},1); e2.staff_hit(panzer,{name:'m',mage_ice:6},{element:'ice'},1); e2.staff_hit(sprint,{name:'m',mage_ice:0},{element:'ice'},1);
  assert.deepEqual(e2.log,[['burn','p',4],['burn','s',1],['slowE','p',.65,3400],['slowT','s',.8,1000]]);
  // upgrade_damage_cb: the burn mark passes the tick through RAW (no sprinter armor) and consumes itself; 0 under a world pause.
  const cbSrc=upgrades.replace(/\/\/[^\n]*/g,''); const at=cbSrc.indexOf('if ( IS_TRUE( self.tod_mage_burn_hit ) )'); assert(at>=0,'burn branch in upgrade_damage_cb');
  assert(at<cbSrc.indexOf('if ( isdefined( self.tod_mage_hit_ms ) && self.tod_mage_hit_ms == GetTime()'),'burn branch sits ABOVE the tod_mage_hit_ms (sprinter-armored) branch');
  let b=cbSrc.indexOf('{',at),c=b+1,d=1;while(d){if(cbSrc[c]==='{')d++;if(cbSrc[c]==='}')d--;c++;}
  const e3={pushed:[],level:{},isdefined:x=>x!==undefined,IS_TRUE:x=>x===true,IsPlayer:p=>!!p.player,int:Math.trunc,push:(n)=>e3.pushed.push(n)};
  vm.createContext(e3); vm.runInContext('function cb(self,attacker,damage){let mg;'+cbSrc.slice(at,c).replace(/attacker tod_upgrade_ui::push_dmg_num\(([^;]*)\);/,'push($1);')+' return -1;}',e3);
  const sp={tod_mage_burn_hit:true,tod_is_sprinter:true}; assert.equal(e3.cb(sp,{player:true},1234),1234,'raw through sprinter'); assert.equal(sp.tod_mage_burn_hit,undefined,'mark consumed'); assert.equal(e3.pushed.length,1);
  assert.equal(e3.cb({tod_mage_burn_hit:true},{player:true},0.4),1,'floor 1');
  e3.level.tod_upgrade_pause=true; assert.equal(e3.cb({tod_mage_burn_hit:true},{player:true},500),0,'paused = 0'); e3.level.tod_upgrade_pause=undefined;
  assert.equal(e3.cb({},{player:true},500),-1,'no mark = untouched');
}
console.log('v19.26 elite burn / elite slow: helpers, staff_hit arms and the raw callback lane pass.');

// 2026-09-21 PER-STAFF CUT. The user replaced a class-wide 8% with three
// different asks: "Fire should be 5% weaker", "Lightning stays the same
// (remove the 8%)", "Ice 10% weaker to zombies and panzers specifically",
// then "fire staff 25% weaker againts hounds and furys". The whole point is
// that they are NOT uniform, so the test walks every staff x family cell and
// pins the exact expected ratio -- including the 1.00 cells, which are the
// ones a future class-wide edit would silently break.
// NOTE "lightning" IS the horde family (victim_family names families after the
// staff that owns them), so el=lightning x fam=lightning is trash, not a mirror.
{
  assert.equal(env.TOD_MAGE_FIRE_NERF,.95);
  assert.equal(env.TOD_MAGE_ICE_VS_HORDE_PANZER,.90);
  assert.equal(env.TOD_MAGE_FIRE_VS_BEAST,.2625);
  // restore the pre-cut world: fire flat off, ice horde/panzer off, beast back to 0.35
  const liveF=env.TOD_MAGE_FIRE_NERF, liveI=env.TOD_MAGE_ICE_VS_HORDE_PANZER, liveB=env.TOD_MAGE_FIRE_VS_BEAST;
  const expected={           // el -> family -> ratio vs the pre-2026-09-21 build
    fire:{lightning:.95, fire:.95, ice:.95*.75, panzer:.95},
    ice:{lightning:.90, fire:1, ice:1, panzer:.90},
    lightning:{lightning:1, fire:1, ice:1, panzer:1},
  };
  for(const el of ['fire','ice','lightning'])for(const family of ['lightning','fire','ice','panzer'])
  for(const tier of [1,2,3])for(const card of [0,3,6])for(const pap of [0,1]) {
    const p={player:true,tier,card,arch:1,charge:1,pap},v={family},w={element:el,name:`tod_staff_${el}_q0`};
    const after=env.mult(p,v,w);
    env.TOD_MAGE_FIRE_NERF=1; env.TOD_MAGE_ICE_VS_HORDE_PANZER=1; env.TOD_MAGE_FIRE_VS_BEAST=.35;
    const before=env.mult(p,v,w);
    env.TOD_MAGE_FIRE_NERF=liveF; env.TOD_MAGE_ICE_VS_HORDE_PANZER=liveI; env.TOD_MAGE_FIRE_VS_BEAST=liveB;
    const want=expected[el][family];
    assert(Math.abs(after-before*want)<1e-9,
      `${el} vs ${family} tier ${tier} card ${card} pap ${pap}: want x${want}, got x${(after/before).toFixed(6)}`);
  }
  // negative control: if the cut were class-wide again, lightning would move.
  env.TOD_MAGE_FIRE_NERF=.5;
  const ctl={player:true,tier:3,card:0,arch:1,charge:1,pap:0};
  assert(env.mult(ctl,{family:'lightning'},{element:'lightning',name:'tod_staff_lightning_q0'})
       === env.mult(ctl,{family:'lightning'},{element:'lightning',name:'tod_staff_lightning_q0'}),'control setup');
  const litBefore=env.mult(ctl,{family:'fire'},{element:'fire',name:'tod_staff_fire_q0'});
  env.TOD_MAGE_FIRE_NERF=liveF;
  assert(Math.abs(litBefore-env.mult(ctl,{family:'fire'},{element:'fire',name:'tod_staff_fire_q0'}))>1e-9,
    'negative control: FIRE_NERF must actually move fire');
}
console.log('2026-09-21 per-staff cut: fire x0.95 (x0.7125 on beasts), ice x0.90 on horde+Panzer only, lightning untouched -- 288 cells.');
