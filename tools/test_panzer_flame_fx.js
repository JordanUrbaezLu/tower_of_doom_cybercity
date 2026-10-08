// Execute the shipping visual-state owner/watch against a stock-style flame
// sequence with NO animation notetracks. No claim about native rendering.
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const src = fs.readFileSync('scripts/zm/mechz_spiki.gsc', 'utf8');
function body(name) {
  const clean = src.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
  const at = clean.indexOf('function ' + name + '(');
  assert(at >= 0, name);
  const start = clean.indexOf('{', at); let end = start + 1, depth = 1;
  while (depth) { if (clean[end] === '{') depth++; if (clean[end] === '}') depth--; end++; }
  return clean.slice(start + 1, end - 1);
}
const writes = [];
const actor = {alive:true};
const ctx = {self:actor, level:{tod_dev:false}, IS_TRUE:v=>v===true||v===1,
  isdefined:v=>v!==undefined&&v!==null, isalive:v=>v.alive, int:Number,
  emit:(e,k,v)=>writes.push([k,v]), GetTime:()=>0};
vm.createContext(ctx);
const setter = body('acc_ft_visual_state').replace(/if\(IS_TRUE\(level.tod_dev\)\)[\s\S]*$/, '')
  .replace(/entity clientfield::set\(/g, 'emit(entity, ');
const watch = body('acc_ft_visual_watch').replace(/wait 0\.05;/g, 'yield 0.05;');
vm.runInContext('function acc_ft_visual_state(entity,on){'+setter+'}\nfunction* watch(){'+watch+'}', ctx);
const run=ctx.watch();
run.next(); assert.deepEqual(writes.map(x=>x[1]), [0]);
actor.isShootingFlame=true; run.next(); // stock starts; no start_ft call
assert.equal(writes.at(-1)[1],1);
for(let i=0;i<30;i++) run.next();
assert.equal(writes.length,2,'steady flame must not spam the clientfield');
actor.isShootingFlame=false; run.next(); // interruption; no stop_ft call
assert.equal(writes.at(-1)[1],0);
actor.isShootingFlame=true; run.next(); // second stock-only attack
actor.alive=false; assert.equal(run.next().done,true);
assert.deepEqual(writes.map(x=>x[1]),[0,1,0,1,0],'death clears the corpse FX');
assert(body('acc_mechz_flame_player_cb').indexOf('acc_ft_visual_state') <
       body('acc_mechz_flame_player_cb').indexOf('acc_player_flame_damage'),
       'stock damage lane must mirror FX before burning');
console.log('Panzer FX: stock-only starts, interruptions, repeats, change gating and death cleanup pass.');
