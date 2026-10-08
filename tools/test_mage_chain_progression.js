const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const src=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc','utf8');
const up=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc','utf8');
function block(s,a){a=s.indexOf('{',a);let b=a+1,d=1;while(d){if(s[b]==='{')d++;if(s[b]==='}')d--;b++;}return s.slice(a+1,b-1);}
const env={get_level:p=>p.lv,has_dark:p=>p.dark,int:Math.trunc,isdefined:v=>v!==undefined,IS_TRUE:v=>v===true,IsPlayer:p=>p.player,sprinter_armor_frac:()=>.4,level:{},attacker:{player:true},push:()=>{}};
for(const m of src.matchAll(/#define\s+(TOD_MAGE_CHAIN_\w+)\s+([\d.]+)/g))env[m[1]]=Number(m[2]);vm.createContext(env);
for(const n of ['chain_targets','chain_fraction'])vm.runInContext('function '+n+'(player){let lv,n;'+block(src,src.indexOf('function '+n+'(')).replace(/tod_upgrades::/g,'')+'}',env);
const branch=block(up,up.indexOf('if ( IS_TRUE( self.tod_mage_chain_hit ) )'));
vm.runInContext('function callback(damage){let arc;'+branch.replace(/attacker tod_upgrade_ui::push_dmg_num\(/g,'push(')+'}',env);
const expected=[0,1,2,2,3,3,4,4,5,5,6];
for(let lv=0;lv<=12;lv++)for(const dark of [false,true]){
 const p={lv,dark};assert.equal(env.chain_targets(p),lv===0?0:expected[Math.min(lv,10)]+(dark?1:0));
 const fraction=.5*(1+.05*Math.min(lv,10));assert.equal(env.chain_fraction(p),fraction);
 for(const damage of [100,1000,9999])for(const armor of [false,true]){
  const share=Math.max(1,Math.trunc(damage*env.chain_fraction(p)));env.self={tod_mage_chain_hit:true,tod_is_sprinter:armor};
  assert.equal(env.callback(share),Math.max(1,armor?Math.trunc(share*.4):share));assert.equal(env.self.tod_mage_chain_hit,undefined);
 }
}
assert.equal(env.chain_fraction({lv:0}),.5);assert.equal(env.chain_fraction({lv:10}),.75);
console.log('Chain progression passed: Lv0-12, Dark extra arcs, 50% base/75% cap, integer damage, armored targets and callback passthrough.');
