// Exercise the shipping GSC predicate and the stock filter's removal order.
const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const code = read('scripts/zm/zm_tower_of_doom/_tod_cyber_zombies.gsc');
const body = code.match(/function ignore_spawner\( spawner \)\s*\{([\s\S]*?)\n\}/)[1];
const execute = new Function('spawner', 'level', 'isdefined', 'IS_TRUE', body);
const ignored = (spawner, dev) => execute(spawner, {tod_dev: dev}, x => x !== undefined, x => x !== undefined && !!x);
const stock = {script_string: 'tod_cyber_stock'};
const cyber = {script_string: 'tod_cyber_dev'};
for (const dev of [undefined, false, true]) {
  for (const order of [[stock, cyber], [cyber, stock]]) {
    const selected = [...order];
    // Stock _zm_spawner::init removes entries in a forward loop.
    for (let i = 0; i < selected.length; i++) {
      if (ignored(selected[i], dev)) selected.splice(i, 1);
    }
    assert.deepEqual(selected, [cyber]);
  }
  assert.equal(ignored({}, dev), false);
  assert.equal(ignored({script_string: 'unrelated_factory'}, dev), false);
}
const entry = read('scripts/zm/zm_tower_of_doom.gsc');
const resolve = entry.indexOf('\ttod_resolve_dev_flags();');
const install = entry.indexOf('\ttod_cyber_zombies::install_spawn_filter();');
const bootstrap = entry.indexOf('\tzm_usermap::main();');
assert(resolve >= 0 && resolve < install && install < bootstrap);
assert.match(code, /level\.ignore_spawner_func = &ignore_spawner;/);
const map = read('map_source/zm/zm_tower_of_doom.map');
const factories = map.split(/^\/\/ entity \d+.*$/m).filter(block => /"classname" "actor_spawner_zm_(?:factory_zombie|tod_cyber_horde)"/.test(block));
assert.equal(factories.length, 2);
for (const [name, marker] of [['factory_zombie', 'tod_cyber_stock'], ['tod_cyber_horde', 'tod_cyber_dev']]) {
  const factory = factories.find(x => x.includes('actor_spawner_zm_' + name + '"'));
  assert(factory.includes('"script_string" "' + marker + '"'));
  assert(factory.includes('"script_noteworthy" "zombie_spawner"'));
  assert(factory.includes('"origin" "470 470 208"'));
}
// Negative control: restore the old restriction; ordinary matches must fail.
const broken = new Function('spawner', 'level', 'isdefined', 'IS_TRUE', body.replace('return false; // Historical', 'return !IS_TRUE( level.tod_dev ); // Historical'));
assert.equal(broken(cyber, {tod_dev: false}, x => x !== undefined, x => !!x), true);
assert.equal(ignored(cyber, false), false);
// Appearance is universal, but diagnostic callbacks still cost nothing outside dev.
assert.match(code, /function init\(\)\s*\{\s*if \( !IS_TRUE\( level.tod_dev \) \)\s*return;/);
assert(!code.includes('restore_sprinter_head'));
const sprinter = read('scripts/zm/zm_tower_of_doom/_tod_sprinter.gsc');
const promotion = sprinter.match(/function promote_to_sprinter\(\)\s*\{([\s\S]*?)\n\}/)[1];
assert(!/\b(?:Attach|Detach)\s*\(/.test(promotion)); // Attachment changes belong to the guarded cosmetic helper.
assert.match(promotion, /tod_cyber_zombies::apply_sprinter_equipment\(\)/);
const headMap = code.match(/function armored_head_for\( head \)\s*\{([\s\S]*?)\n\}/)[1];
const mapHead = new Function('head', 'isdefined', headMap);
for (const [head,index] of [['tod_cyber_head',1],['tod_cyber_hhead1',1],['tod_cyber_hhead2',2],['tod_cyber_bhead2',2],['tod_cyber_hhead3',3],['tod_cyber_bhead3',3],['c_zom_der_zombie_head1',1],['c_zom_der_zombie_head2',2],['c_zom_der_zombie_head3',3]]) {
  assert.equal(mapHead(head,x=>x!==undefined),'tod_cyber_sprinter_head'+index);
}
for (const head of [undefined,'','unknown','tod_cyber_sprinter_head1']) assert.equal(mapHead(head,x=>x!==undefined),undefined);
const kit = code.match(/function apply_sprinter_equipment\(\)\s*\{([\s\S]*?)\n\}/)[1];
assert.match(kit,/IS_TRUE\( self.head_gibbed \) \|\| GibServerUtils::IsGibbed\( self, GIB_TORSO_HEAD_FLAG \)/);
assert(kit.indexOf('reason=head_removed') < kit.indexOf('self Detach'));
assert(kit.indexOf('reason=unknown_head') < kit.indexOf('self Detach'));
assert(kit.indexOf('self Detach( old_head') < kit.indexOf('self Attach( new_head'));
assert.match(kit,/self.gib_data.head = new_head;/);
assert.match(kit,/self.gib_data.hatmodel = undefined;/);
assert(!/\bwait\b/.test(kit.replace(/\/\/[^\n]*/g,'')));
// Execute the shipping cosmetic helper against both stock gib-data layouts.
const runKit = new Function('self','isdefined','IS_TRUE','armored_head_for','dev_log','value',
  kit.replace('GibServerUtils::IsGibbed( self, GIB_TORSO_HEAD_FLAG )','self.nativeHeadGone')
    .replace('GIB_HEAD_MODEL( self )','(self.gib_data ? self.gib_data.head : self.head)')
    .replace('GIB_HAT_MODEL( self )','(self.gib_data ? self.gib_data.hatmodel : self.hatmodel)')
    .replace(/self GetEntityNumber\(\)/g,'self.GetEntityNumber()')
    .replace(/self (Detach|Attach)\(/g,'self.$1(')
    .replace(/^(\s*)(old_head|new_head|hat) =/gm,'$1let $2 ='));
function applyKit(state) {
  const events=[];const logs=[];
  const actor={...state,GetEntityNumber:()=>27,Detach:(...x)=>events.push(['detach',...x]),Attach:(...x)=>events.push(['attach',...x])};
  runKit(actor,x=>x!==undefined,x=>!!x,h=>mapHead(h,x=>x!==undefined),s=>logs.push(s),v=>v===undefined?'unset':String(v));
  return {actor,events,logs};
}
for (const nested of [false,true]) {
  const initial={head:'tod_cyber_bhead3',hatmodel:'tod_cyber_helmet_trooper',health:712,no_gib:true};
  if(nested) initial.gib_data={head:initial.head,hatmodel:initial.hatmodel};
  const result=applyKit(initial);
  assert.deepEqual(result.events,[['detach','tod_cyber_helmet_trooper',''],['detach','tod_cyber_bhead3',''],['attach','tod_cyber_sprinter_head3','']]);
  assert.equal(result.actor.head,'tod_cyber_sprinter_head3');assert.equal(result.actor.hatmodel,undefined);
  assert.equal(result.actor.health,712);assert.equal(result.actor.no_gib,true);
  if(nested){assert.equal(result.actor.gib_data.head,result.actor.head);assert.equal(result.actor.gib_data.hatmodel,undefined);}
  assert.deepEqual(applyKit(result.actor).events,[]); // repeated promotion cannot stack a second visor/head
}
for(const extra of [{head_gibbed:true},{nativeHeadGone:true},{head:undefined},{head:'unrecognized'}]) {
  const result=applyKit({head:'tod_cyber_head',hatmodel:'hat',...extra});
  assert.deepEqual(result.events,[]);assert.equal(result.actor.hatmodel,'hat');
}
assert.deepEqual(applyKit({head:'tod_cyber_hhead2'}).events,[['detach','tod_cyber_hhead2',''],['attach','tod_cyber_sprinter_head2','']]);
assert.match(sprinter, /#define TOD_SPRINT_BODY_MODEL\s+"tod_cyber_sprinter"/);
assert.match(promotion, /self.no_gib = true;/);
assert.match(promotion, /tod_cyber_zombies::log_sprinter_promotion\(\)/);
console.log('Cyber spawn selection PASS: every mode uses cyber mix; exactly one factory in either order; bootstrap timing, generated map and dev-only diagnostics verified.');
