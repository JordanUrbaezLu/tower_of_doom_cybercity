// Execute the real pause writer and elite watcher over a simulated GSC clock.
// Native capture 20260910_223618: pause on/off=69550; hound 54 then stalled.
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const path = require('path');
const root = path.join(__dirname, '../scripts/zm/zm_tower_of_doom');
function body(file, name) {
  const src = fs.readFileSync(path.join(root, file), 'utf8').replace(/\/\/[^\n]*/g, '');
  const at = src.indexOf('function ' + name + '(');
  assert.ok(at >= 0, name);
  const start = src.indexOf('{', at);
  let end = start + 1, depth = 1;
  while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
  return src.slice(start + 1, end - 1);
}
function js(src) {
  return src.replace(/(?:self|level) endon\([^;]+;/g, '')
    .replace(/foreach\s*\(\s*(\w+)\s+in\s+(\w+)\s*\)/g, 'for (const $1 of $2)')
    .replace(/\b(\w+)\s+(\w+)::(\w+)\(/g, '$1.$3(')
    .replace(/\b(self|z|p)\s+(\w+)\(/g, '$1.$2(')
    .replace(/wait 0\.25;/g, 'yield 250;');
}
const writer = js(body('_tod_upgrades.gsc', 'set_world_pause'));
const watcher = js(body('_tod_bosses.gsc', 'boss_pause_watch'));
function run(old = false) {
  const writes = [], events = [];
  const env = { clockMs: 0, level: { tod_dev: false }, self: { health: 100 },
    GetTime: () => env.clockMs, GetPlayers: () => [], GetAITeamArray: () => [env.self],
    isdefined: v => v !== undefined, isalive: e => e.health > 0, isplayer: () => false,
    IS_TRUE: v => v === true, dbg: s => events.push(s), dev_ai_ent: () => 54 };
  Object.assign(env.level, { exists: () => true, init() {}, set() {}, clear() {} });
  env.self.ASMSetAnimationRate = rate => { env.self.rate = rate; writes.push([env.clockMs, rate]); };
  env.self.under_anim_slow = () => false;
  vm.createContext(env);
  const code = old ? watcher.replace('was_paused || IS_TRUE( self.tod_elite_pause_pending )', 'was_paused') : watcher;
  vm.runInContext(`function set_world_pause(on) {${writer}}
    function* boss_pause_watch(base_rate) {${code}}`, env);
  const co = env.boss_pause_watch(0.85);
  assert.equal(co.next().value, 250);
  return { env, writes, events, pause(on, ms) { env.clockMs = ms; env.set_world_pause(on); },
    tick(ms) { env.clockMs = ms; return co.next(); } };
}

// Negative control: the old edge-only condition leaves the actual writer's
// 0.05 stamped indefinitely when both edges occur between watcher polls.
let r = run(true);
r.pause(true, 100); r.pause(false, 100);
for (let ms = 250; ms <= 1000; ms += 250) r.tick(ms);
assert.equal(r.env.self.rate, 0.05, 'reproduces the original missed-edge defect');

r = run();
r.pause(true, 100); r.pause(false, 100); r.tick(250);
assert.equal(r.env.self.rate, 0.85, 'same-frame pause restores the real elite base rate');
assert.equal(r.env.self.tod_elite_pause_pending, undefined);
const count = r.writes.length; r.tick(500);
assert.equal(r.writes.length, count, 'no continuous rate override after release');

r = run(); r.env.self.tod_bt_idle_on_pause = true;
r.pause(true, 100); r.tick(250); r.tick(500);
assert.equal(r.env.self.rate, 0.05);
assert.equal(r.env.self.zombie_think_done, false, 'Fury stays parked throughout a real pause');
r.pause(false, 600); r.tick(750);
assert.equal(r.env.self.rate, 0.85);
assert.equal(r.env.self.zombie_think_done, 1);
assert.equal(r.env.self.tod_bt_parked, undefined);

r = run(); r.env.self.tod_dropping = true;
r.pause(true, 100); r.pause(false, 100); r.tick(250);
assert.equal(r.env.self.rate, 0.05, 'entrance retains rate ownership');
assert.equal(r.env.self.tod_elite_pause_pending, true, 'restore is not lost during entrance');
r.env.self.tod_dropping = false; r.tick(500);
assert.equal(r.env.self.rate, 0.85);

for (const until of [1000, 200]) {
  r = run(); Object.assign(r.env.self, { tod_eslow_until: until, tod_eslow_mult: 0.45 });
  r.pause(true, 100); r.pause(false, 100); r.tick(250);
  assert.equal(r.env.self.rate, until > 250 ? 0.85 * 0.45 : 0.85,
    'unexpired player slow retained; expired slow discarded');
}
r = run(); r.env.level.tod_dev = true;
r.pause(true, 100); r.pause(false, 100); r.pause(true, 200); r.pause(false, 200); r.tick(250);
assert.equal(r.env.self.rate, 0.85);
assert.equal(r.env.self.tod_ai_diag_pause_write, 200);
assert.equal(r.env.self.tod_ai_diag_pause_resume, 250);
assert.equal(r.events.length, 1);
assert.match(r.events[0], /PAUSE_RESTORE.*missed_edge=true/);
console.log('PASS: actual pause writer/watcher; old missed-edge reproduction, short/long/repeated pauses, Fury park, drop ownership, live/expired slows, dev diagnostics.');
