// test_mage_bolt_reload.js — v18.77: the lightning staff's invisible shot
// counter. Runs the ACTUAL GSC helpers (bolt_count_shot, staff_clip_target,
// bolt_reload_reset) and the ammo watcher's pin decision with a mocked player:
//   * N lightning shots -> the clip is emptied and pinned at 0 (engine reload)
//   * fire / ice shots never count; a lightning shot on the counter only
//   * ANY reload start resets the count and lifts the pin, finished or not
//   * a fresh body starts at zero; q0 and q1 variants both count
// v18.99 adds the two powerups the counter has to answer to:
//   * INFINITE AMMO suspends it — shots stop counting, a standing debt is
//     wiped, the clip is never pinned to 0, and the count restarts after
//   * MAX AMMO resets it, above the ARCHMAGE gate (structural check)
//   node tools/test_mage_bolt_reload.js
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '../scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'), 'utf8');
function body(name) {
  const at = src.indexOf('function ' + name + '(');
  assert.ok(at >= 0, name);
  const start = src.indexOf('{', at);
  let end = start + 1, depth = 1;
  while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
  return src.slice(start + 1, end - 1).replace(/\/\/.*$/gm, '')
    .replace(/self (\w+)\(/g, '$1(').replace(/self\./g, 'S.')
    // JS permits undefined != "lightning"; native GSC throws. Model that
    // boundary so non-staff shots cannot silently pass this test again.
    .replace(/(staff_element\(\s*weapon\s*\)|element)\s*([!=]=)\s*"lightning"/g,
      (_, left, op) => `${op === '!=' ? '!' : ''}gscStringEqual(${left}, "lightning")`);
}
const N = Number(src.match(/#define\s+TOD_MAGE_BOLT_SHOTS_PER_RELOAD\s+(\d+)/)[1]);
assert.equal(N, 20, 'the user asked for every 20 shots (2026-09-11; 15 before)');
// IS_TRUE MUST MODEL THE MACRO, NOT `=== true` (v18.99). shared.gsh:251 is
// `( isdefined( __a ) && __a )`, so the INTEGER 1 is true — and the stock
// powerup stores 1/0, never a boolean (_zm_powerup_infiniteammo.gsc:120).
// The old `v === true` mock was stricter than the game and failed a correct
// implementation on its first run; a mock tighter than the macro can just as
// easily pass a broken one, so the controls below pin both ends.
const env = { S: {}, clip: 5, level: {}, isdefined: v => v !== undefined, TOD_MAGE_BOLT_SHOTS_PER_RELOAD: N,
              IS_TRUE: v => v !== undefined && v !== 0 && v !== false && v !== '' };
assert.equal(env.IS_TRUE(1), true, 'the macro: integer 1 is true');
assert.equal(env.IS_TRUE(0), false, 'the macro: integer 0 is false');
assert.equal(env.IS_TRUE(undefined), false, 'the macro: undefined is false');
// the powerup's own storage shape, not a boolean of our choosing
const infinite = on => { env.level.zombie_vars = { zombie_powerup_infiniteammo_on: on ? 1 : 0 }; };
env.gscStringEqual = (left, right) => {
  if (left === undefined) throw new Error('GSC undefined/string comparison');
  return left === right;
};
assert.throws(() => env.gscStringEqual(undefined, 'lightning'), /undefined\/string/, 'native comparison negative control');
env.SetWeaponAmmoClip = (w, n) => { env.clip = n; };
env.IsSubStr = (s, k) => s.includes(k);
vm.createContext(env);
vm.runInContext(`function staff_element(weapon) {${body('staff_element')}}
function staff_clip_target(weapon) {${body('staff_clip_target')}}
function bolt_count_shot(weapon) {${body('bolt_count_shot')}}
function bolt_reload_reset() {${body('bolt_reload_reset')}}
function bolt_reload_suspended() {${body('bolt_reload_suspended')}}`, env);
assert.equal(env.bolt_reload_suspended(), false, 'no zombie_vars at all = not suspended');
const W = { lightning: { name: 'tod_staff_lightning_q0', clipSize: 6 }, lightning1: { name: 'tod_staff_lightning_q1', clipSize: 6 },
            fire: { name: 'tod_staff_fire_q0', clipSize: 6 }, ice: { name: 'tod_staff_ice_q1', clipSize: 6 }, gun: { name: 'ak47_zm', clipSize: 30 } };

env.S = {}; env.clip = 5;
for (let i = 1; i < N; i++) {
  env.bolt_count_shot(W.lightning);
  assert.equal(env.S.tod_mage_bolt_shots, i);
  assert.equal(env.S.tod_mage_bolt_reload_due, undefined, 'not due before the limit');
  assert.equal(env.staff_clip_target(W.lightning), 5, 'pinned one short before the limit');
  assert.equal(env.clip, 5, 'clip untouched before the limit');
}
env.bolt_count_shot(W.lightning);
assert.equal(env.S.tod_mage_bolt_shots, N);
assert.equal(env.S.tod_mage_bolt_reload_due, true, 'due at the limit');
assert.equal(env.clip, 0, 'the clip is emptied on the spot');
assert.equal(env.staff_clip_target(W.lightning), 0, 'the watcher keeps it at 0');
assert.equal(env.staff_clip_target(W.lightning1), 0, 'the packed variant is the same staff');
assert.equal(env.staff_clip_target(W.fire), 5, 'fire is never pinned to 0');
assert.equal(env.staff_clip_target(W.ice), 5, 'ice is never pinned to 0');
assert.equal(env.staff_clip_target(W.gun), 29, 'a non-staff weapon remains valid while lightning reload is owed');
// more shots past the limit (cannot happen with an empty clip, but must not wrap)
env.bolt_count_shot(W.lightning); assert.equal(env.S.tod_mage_bolt_reload_due, true); assert.equal(env.clip, 0);
// any reload start resets
env.bolt_reload_reset();
assert.equal(env.S.tod_mage_bolt_shots, 0); assert.equal(env.S.tod_mage_bolt_reload_due, undefined);
assert.equal(env.staff_clip_target(W.lightning), 5, 'pin lifted after a reload start');
// fire and ice shots do not count; a gun never counts
env.S = {}; env.clip = 5;
for (let i = 0; i < 40; i++) { env.bolt_count_shot(W.fire); env.bolt_count_shot(W.ice); env.bolt_count_shot(W.gun); env.bolt_count_shot(undefined); }
assert.equal(env.S.tod_mage_bolt_shots, undefined, 'only lightning counts');
assert.equal(env.clip, 5);
// mixed: 14 lightning, then fire, then 1 lightning -> due
for (let i = 0; i < N - 1; i++) env.bolt_count_shot(W.lightning);
env.bolt_count_shot(W.fire); assert.equal(env.S.tod_mage_bolt_reload_due, undefined);
env.bolt_count_shot(W.lightning1); assert.equal(env.S.tod_mage_bolt_reload_due, true, 'q1 shots count on the same counter');

// ---- v18.99 INFINITE AMMO: shoot forever, no reload -----------------------
// (a) a debt already owed is lifted the moment the drop lands, mid-debt.
env.S = {}; env.clip = 5; infinite(false);
for (let i = 0; i < N; i++) env.bolt_count_shot(W.lightning);
assert.equal(env.S.tod_mage_bolt_reload_due, true); assert.equal(env.staff_clip_target(W.lightning), 0);
infinite(true);
assert.equal(env.staff_clip_target(W.lightning), 5, 'Infinite Ammo lifts the pin without a reload');
// (b) shots during the drop never count, and the standing debt is wiped
env.bolt_count_shot(W.lightning);
assert.equal(env.S.tod_mage_bolt_shots, 0, 'the shot does not count');
assert.equal(env.S.tod_mage_bolt_reload_due, undefined, 'the debt is wiped');
for (let i = 0; i < N * 3; i++) env.bolt_count_shot(W.lightning);
assert.equal(env.S.tod_mage_bolt_reload_due, undefined, `${N * 3} shots under the drop still owe nothing`);
assert.equal(env.staff_clip_target(W.lightning), 5, 'never pinned while it holds');
// (c) when it ends the player gets a FULL count, not an instant reload
infinite(false);
assert.equal(env.staff_clip_target(W.lightning), 5, 'no debt the moment it ends');
for (let i = 1; i < N; i++) { env.bolt_count_shot(W.lightning); assert.equal(env.S.tod_mage_bolt_reload_due, undefined); }
env.bolt_count_shot(W.lightning);
assert.equal(env.S.tod_mage_bolt_reload_due, true, `a fresh ${N} shots after the drop, then the reload`);
// (d) the other staffs are unaffected either way
infinite(true); assert.equal(env.staff_clip_target(W.fire), 5); assert.equal(env.staff_clip_target(W.gun), 29);
infinite(false);

// ---- v18.99 MAX AMMO resets the counter -----------------------------------
const ma = body('max_ammo');
assert.ok(ma.includes('bolt_reload_reset()'), 'a Max Ammo resets the lightning counter');
assert.ok(ma.indexOf('bolt_reload_reset()') < ma.indexOf('arch_level() < 1'),
  'the reset is ABOVE the ARCHMAGE gate — ammo back is not what the card buys');
assert.ok(/SetWeaponAmmoClip\(\s*held/.test(ma) && ma.includes('IsReloading()'),
  'the held staff is topped up on the spot, never mid-reload');
const cs = body('bolt_count_shot');
assert.ok(cs.indexOf('bolt_reload_suspended()') < cs.indexOf('tod_mage_bolt_shots++'),
  'the suspend check runs before the counter moves');

// wiring: the watchers call the helpers at the right moments
const watch = body('staff_ammo_watch');
assert.ok(watch.includes('target = staff_clip_target( weapon )') && watch.includes('SetWeaponAmmoClip( weapon, target )'), 'ammo watcher pins to the helper');
assert.ok(!/clipSize - 1/.test(watch), 'the watcher no longer hard-codes one short');
const shots = body('shot_id_watch');
assert.ok(shots.includes('waittill( "weapon_fired", weapon )') && shots.includes('bolt_count_shot( weapon )'), 'weapon_fired counts');
const reload = body('reload_mana_watch');
assert.ok(reload.indexOf('waittill( "reload_start" )') < reload.indexOf('bolt_reload_reset()'), 'reload_start resets');
assert.ok(body('on_player_spawned').includes('bolt_reload_reset()'), 'fresh body, fresh count');
console.log(`lightning reload: every ${N} shots the clip pins to 0 for the engine's own reload; fire/ice/guns never count; any reload start resets; q0/q1 share the counter; INFINITE AMMO suspends it and wipes the debt; MAX AMMO resets it. PASS`);
