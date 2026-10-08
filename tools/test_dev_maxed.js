// Execute the actual grant and diagnostic wrapper with native services mocked.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const main=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_main.gsc','utf8');
const upgrades=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc','utf8');
function body(source,name){
 const s=source.replace(/\/\/[^\n]*/g,'');const start=s.indexOf('{',s.indexOf('function '+name+'('));
 assert(start>=0,name);let end=start+1,depth=1;while(depth){if(s[end]==='{')depth++;if(s[end]==='}')depth--;end++;}return s.slice(start+1,end-1);
}
function translate(s){return s.replace(/&"/g,'"').replace(/\.size\b/g,'.length')
 .replace(/foreach\s*\(\s*(\w+)\s+in\s+([^\n]+)\s*\)/g,'for (const $1 of $2)')
 .replace(/\b(player|self)\s+tod_upgrades::dev_grant_maxed\( self \)/g,'(yield* dev_grant_maxed(self))')
 .replace(/\b(player|self|level)\s+(?:tod_classes::)?(\w+)\(/g,'$1.$2(')
 .replace(/tod_classes::|tod_upgrades::|tod_gauge::|tod_upgrade_ui::/g,'')
 .replace(/player \[\[ level\.(\w+) \]\]\(\)/g,'level.$1.call(player)')
 .replace(/\bwait\s+([^;]+);/g,'yield $1;');}
assert(/if \( IS_TRUE\( level.tod_dev \) \|\| IS_TRUE\( level.tod_dev_maxed \) \)\s*level thread dev_maxed_harness/.test(main));
assert(body(main,'dev_maxed_harness').includes('!IS_TRUE( players[ i ].tod_dev_mage_dummy )'));
assert(body(main,'dev_maxed_harness').indexOf('tod_class_select_done')<body(main,'dev_maxed_harness').indexOf('dev_class_max_loadout'));
function run(key,{dev=true,flag=false,dummy=false,failTier=false}={}){
 const logs=[],events=[];const domains=[{key:'shared',cap:5},{key:'dr',cap:{skirmisher:3,mage:3,slasher:5,assault:9,heavy:10}[key]},
  {key:'class',cap:7},{key:'mage_fire',cap:4,tier:2},{key:'mage_ice',cap:6,tier:3}];
 const primary={name:'primary'};
 const p={tod_class:key,tod_tier:1,tod_levels:{},tod_dev_mage_dummy:dummy,
  endon:()=>{},GetEntityNumber:()=>0,class_primary_in_inventory:()=>primary,
  LuiNotifyEvent:()=>{},pap_secondary:()=>events.push('sidearm'),
  apply_move_speed:()=>events.push('speed'),reconcile_twin:()=>events.push('inventory'),refresh_upgrade_list:()=>events.push('ui'),IPrintLnBold:()=>{}};
 const ctx={self:p,player:p,level:{tod_dev:dev,tod_dev_maxed:flag,tod_domains:domains,endon:()=>{}},
  IS_TRUE:v=>v===true,isdefined:v=>v!==undefined&&v!==null,isplayer:v=>v===p,
  tier:p=>p.tod_tier,tier_max:()=>3,mark_top_reached:()=>events.push('floor'),pap_first_grant:()=>events.push('pap'),
  tier_up:p=>{if(failTier)return false;p.tod_tier++;events.push('tier'+p.tod_tier);return true;},
  domain_available:(p,d)=>!d.tier||(p.tod_class==='mage'&&p.tod_tier>=d.tier),
  domain_max:(p,d)=>d.cap,get_level:(p,k)=>p.tod_levels[k]||0,sync_max:(p,d)=>d.cap,domain_id:k=>k,
  dev_class_max_log:s=>logs.push(s)};
 vm.createContext(ctx);
 vm.runInContext('function* dev_grant_maxed(player){'+translate(body(upgrades,'dev_grant_maxed'))+'}',ctx);
 vm.runInContext('function* grant(){'+translate(body(main,'dev_class_max_loadout'))+'}',ctx);
 const gen=ctx.grant();for(let n=0;n<100;n++){if(gen.next().done)return {p,logs,events,domains};}assert.fail('grant hung');
}
for(const key of ['skirmisher','assault','heavy','slasher','mage']){
 const r=run(key);assert.equal(r.p.tod_class,key);assert.equal(r.p.tod_tier,3);
 for(const d of r.domains)if(!d.tier||key==='mage')assert.equal(r.p.tod_levels[d.key],d.cap,key+' '+d.key);
 assert(r.logs.some(s=>s.startsWith('READY ')&&s.includes('missing=0')));
 assert(r.events.includes('sidearm')&&r.events.includes('inventory')&&r.events.includes('ui'));
}
for(const opts of [{dev:false},{dummy:true}]){const r=run('mage',opts);assert.equal(r.p.tod_tier,1);assert.equal(r.events.length,0);}
assert.equal(run('mage',{dev:false,flag:true}).p.tod_tier,3);
assert(run('mage',{failTier:true}).logs.some(s=>s.startsWith('INCOMPLETE ')));
console.log('Dev maxed: all five chosen classes retain identity, reach tier 3 and class caps; Mage unlock ordering, inventory/UI reconciliation, ship/dummy exclusion and incomplete-grant diagnostics pass.');
