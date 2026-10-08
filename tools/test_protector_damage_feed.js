const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const source = fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_bosses.gsc', 'utf8');
let a = source.indexOf('{', source.indexOf('function rp_damage_feed(')), b = a + 1, depth = 1;
while (depth) { if (source[b] === '{') depth++; if (source[b] === '}') depth--; b++; }
const body = source.slice(a + 1, b - 1).replace(/\/\/[^\n]*/g, '').replace('self tod_upgrades::upgrade_damage_cb(', 'upgrade(');
const env = {self:{}, now:1000, popups:[], isdefined:x=>x!==undefined,
 isplayer:p=>p?.player, IsSubStr:(a,b)=>a.includes(b), GetTime:()=>env.now,
 upgrade:()=>{env.self.tod_actor_cb_ms=env.now;env.popups.push(6000);return 6000;}};
vm.createContext(env);
vm.runInContext('function hit(inflictor,attacker,damage,flags,meansOfDeath,weapon,point,dir,hitLoc,offsetTime,boneIndex,modelIndex){'+body+'}',env);
// Three simultaneous ice impacts: fallback, normal chain, and mixed routing.
for (let mask=0;mask<8;mask++) {
 env.self={};env.popups=[];let total=0;
 for(let i=0;i<3;i++) {
  const incoming=(mask&(1<<i)) ? env.upgrade() : 20000;
  total+=env.hit(null,{player:true},incoming,0,i?'MOD_PROJECTILE_SPLASH':'MOD_PROJECTILE',{name:'tod_staff_ice_q1'},null,null,'none',0,0,0);
 }
 assert.equal(total,18000,'all three impacts scaled once, routing '+mask);
 assert.deepEqual(env.popups,[6000,6000,6000],'all three impacts displayed once');
 assert.equal(env.self.tod_actor_cb_ms,undefined,'event stamp consumed');
}
// Unchanged sentinel and non-player callers remain pass-through.
env.self={};env.upgrade=()=>{env.self.tod_actor_cb_ms=env.now;return -1;};
assert.equal(env.hit(null,{player:true},123,0,'MOD_PROJECTILE',{name:'other'}),123);
assert.equal(env.self.tod_actor_cb_ms,undefined);
assert.equal(env.hit(null,null,456),456);
console.log('Protector damage feed: all eight normal/fallback routing combinations apply and display each impact exactly once; passthrough preserved.');
