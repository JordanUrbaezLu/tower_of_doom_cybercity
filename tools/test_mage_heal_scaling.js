const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const src=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc','utf8');
function body(name){const clean=src.replace(/\/\/[^\n]*/g,'');let a=clean.indexOf('{',clean.indexOf('function '+name+'(')),b=a+1,d=1;while(d){if(clean[b]==='{')d++;if(clean[b]==='}')d--;b++;}return clean.slice(a+1,b-1);}
const env={isdefined:v=>v!==undefined,isplayer:p=>p.player,int:Math.trunc,GetTime:()=>env.now,now:0};
for(const m of src.matchAll(/#define\s+(TOD_MAGE_\w+)\s+([\d.]+)/g))env[m[1]]=Number(m[2]);
vm.createContext(env);
for(const [name,args,locals] of [['heal_hp_per_second','lv',''],['heal_damage_taken','lv',''],['heal_tick_amount','lv,tick','rate'],['aura_touch','lv',''],['aura_level','player','lv,stamp'],['aura_dr','player','lv']])
 vm.runInContext(`function ${name}(${args}){${locals?'let '+locals+';':''}${body(name)}}`,env);
const expectedHP=[6.5,7.15,7.8,8.45,9.1,9.75],expectedDR=[.675,.662,.649,.636,.623,.61];   // 2026-09-09 x0.65 (was 10..15 / .5..0.4)
const recipient={player:true,card:0};env.self=recipient;
for(let lv=1;lv<=6;lv++){
 assert(Math.abs(env.heal_hp_per_second(lv)-expectedHP[lv-1])<1e-9);
 assert(Math.abs(env.heal_damage_taken(lv)-expectedDR[lv-1])<1e-9);
 let total=0;for(let i=0;i<10;i++) {const n=env.heal_tick_amount(lv,i);assert(Number.isInteger(n));total+=n;}
 assert.equal(total,Math.trunc(expectedHP[lv-1]*5),'fractional HP/s: the five-second total is the floor of the sum, never every pulse rounded up');
 recipient.tod_mage_aura_levels=[];env.aura_touch(lv);
 assert.equal(env.aura_level(recipient),lv,'recipient uses caster level despite having no card');
 assert(Math.abs(env.aura_dr(recipient)-expectedDR[lv-1])<1e-9);
}
recipient.tod_mage_aura_levels=[];env.now=1000;env.aura_touch(6);
env.now=1500;env.aura_touch(1);assert.equal(env.aura_level(recipient),6,'weaker pulse cannot overwrite stronger DR');
env.now=1700;assert.equal(env.aura_level(recipient),6,'grace includes its boundary');
env.now=1701;assert.equal(env.aura_level(recipient),1,'weaker pulse cannot prolong stronger DR');
env.now=2201;assert.equal(env.aura_dr(recipient),1,'leaving all auras removes resistance');
assert.equal(env.aura_dr({player:true}),1,'new players have no protection');
assert.equal(env.aura_dr(undefined),1);
assert(Math.abs(env.heal_hp_per_second(6)-9.75)<1e-9);assert(Math.abs(env.heal_damage_taken(-1)-.675)<1e-9);
// DARK HEALING AURA (2026-09-09): the seventh rung -- 20 HP/s and 65% resistance; anything above clamps to it.
assert(Math.abs(env.heal_hp_per_second(7)-13)<1e-9);assert(Math.abs(env.heal_hp_per_second(99)-13)<1e-9);
assert(Math.abs(env.heal_damage_taken(7)-.5775)<1e-9);assert(Math.abs(env.heal_damage_taken(99)-.5775)<1e-9);
recipient.tod_mage_aura_levels=[];env.now=5000;env.aura_touch(7);assert.equal(env.aura_level(recipient),7,'dark rung is the strongest aura');
assert(src.includes('p aura_touch( lv );'));
assert(src.includes('p tod_upgrades::trickle_heal( heal_tick_amount( lv, i ) );'));
console.log('Healing Aura passed: Lv1-6 healing/resistance, exact five-second totals, caster-to-teammate strength, overlap precedence/expiry and no-aura state.');
