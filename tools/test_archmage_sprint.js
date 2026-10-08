// Actual shared native-perk owner, with native player calls mocked.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),path=require('path');
const root=path.resolve(__dirname,'..');
const src=fs.readFileSync(path.join(root,'scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc'),'utf8');
const mage=fs.readFileSync(path.join(root,'scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'),'utf8').replace(/\r/g,'');
let start=src.indexOf('{',src.indexOf('function apply_sprint_fire(')),end=start+1,depth=1;
while(depth){if(src[end]==='{')depth++;if(src[end]==='}')depth--;end++;}
const body=src.slice(start+1,end-1)
 .replace(/self laststand::player_is_in_laststand\(\)/g,'self.down')
 .replace(/self (HasPerk|SetPerk|UnsetPerk)\(/g,'$1(');
const env={IS_TRUE:x=>x===true,IsAlive:p=>p.alive,get_level:p=>p.card,
 HasPerk:()=>env.perk,SetPerk:()=>{env.perk=true;env.grants++;},UnsetPerk:()=>{env.perk=false;env.removes++;}};
vm.createContext(env);vm.runInContext(`function apply(){let arch;${body}}`,env);
for(const active of [false,true])for(const armed of [false,true])for(const alive of [false,true])
for(const down of [false,true])for(const card of [0,1])for(const prior of [false,true]) {
 env.self={tod_mage_demigod:active,tod_mage_armed:armed,alive,down,card};
 env.perk=prior;env.grants=env.removes=0;
 const expected=card>0||(active&&armed&&alive&&!down);
 env.apply();assert.equal(env.perk,expected);
 const changes=env.grants+env.removes;env.apply();assert.equal(env.grants+env.removes,changes,'idempotent maintenance');
}
env.self={tod_mage_demigod:true,tod_mage_armed:true,alive:true,down:false,card:0};
env.perk=false;env.apply();assert.equal(env.perk,true,'activation');
env.self.tod_mage_demigod=undefined;env.apply();assert.equal(env.perk,false,'expiry');
env.self.card=1;env.self.tod_mage_demigod=true;env.apply();
env.self.tod_mage_demigod=undefined;env.apply();assert.equal(env.perk,true,'owned Sprint Fire survives expiry');
assert(mage.includes('self.tod_mage_demigod = true;\n\tself tod_upgrades::apply_sprint_fire();'));
assert(mage.includes('self.tod_mage_demigod = undefined;\n\tself tod_upgrades::apply_sprint_fire();'));
assert(mage.includes('self.tod_mage_armed = is_mage;\n\t\tself tod_upgrades::apply_sprint_fire();'));
const loop=src.slice(src.indexOf('function body_systems_loop('));
assert(loop.includes('self apply_sprint_fire();'));
console.log('Archmage sprint fire passed: 64 ownership/state cases, immediate activation/expiry/class-change hooks, idempotent upkeep, and permanent card preservation. Native sprint animation needs testing.');
