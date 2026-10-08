// test_mage_fixes_0910.js — v18.76: the player-report fixes of 2026-09-10.
//   * item 2  — door frontier: _tod_bosses::door_frontier_z evaluated from the
//               ACTUAL body with mocked flags + the GENERATED door data
//   * item 4  — ARCHMAGE teardown: demigod_run hands off to one demigod_end,
//               the guard fires on death / disarm and runs the same teardown
//   * item 6  — the lethal tile dims for the aura lock (abil_send clamps on
//               ready(), heal_lock_tell re-sends when the lock lifts)
//   * item 8  — a fresh mage sees DIM tiles (0), never HIDDEN (-1), and one hint
//   * item 9  — the reload window define is real (the reload test drives it)
//   node tools/test_mage_fixes_0910.js
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict'), path = require('path');
const root = path.join(__dirname, '..');
const read = f => fs.readFileSync(path.join(root, 'scripts/zm/zm_tower_of_doom', f), 'utf8');
const mage = read('_tod_mage_elements.gsc'), bosses = read('_tod_bosses.gsc'), doors = read('_tod_door_data.gsc');
function body(src, name) {
  const at = src.indexOf('function ' + name + '(');
  assert.ok(at >= 0, 'function ' + name + ' not found');
  const start = src.indexOf('{', at);
  let end = start + 1, depth = 1;
  while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
  return src.slice(start + 1, end - 1);
}
const defines = src => { const o = {}; for (const m of src.matchAll(/^#define\s+(\w+)\s+([-\d.]+)/gm)) o[m[1]] = Number(m[2]); return o; };

// ---------------------------------------------------------------- item 2: the door frontier
{
  const D = defines(bosses);
  for (const k of ['TOD_BOSS_FRONTIER_DOOR_Z', 'TOD_BOSS_FRONTIER_LIFT', 'TOD_BOSS_FRONTIER_LAPS']) assert.ok(Number.isFinite(D[k]), k);
  // the generated door table: flag -> org z
  const doorZ = new Map();
  for (const m of doors.matchAll(/case "([a-z_0-9]+)":\s*\n\s*info\.org = \(\s*[-\d.]+,\s*[-\d.]+,\s*([-\d.]+)\s*\);/g)) doorZ.set(m[1], Number(m[2]));
  assert.ok(doorZ.has('enter_lap1') && doorZ.has('enter_lap50') && doorZ.has('enter_roof'), 'door table parsed');
  // door n sits DOOR_Z above lap n's floor: the define matches the generator
  for (let n = 1; n <= 50; n++) assert.equal(doorZ.get('enter_lap' + n) - D.TOD_BOSS_FRONTIER_DOOR_Z, (n - 1) * 384, 'lap ' + n + ' door floor');
  assert.equal(doorZ.get('enter_roof') - D.TOD_BOSS_FRONTIER_DOOR_Z, 50 * 384);

  let b = body(bosses, 'door_frontier_z').replace(/\/\/.*$/gm, '');
  for (const [k, v] of Object.entries(D)) b = b.replace(new RegExp('\\b' + k + '\\b', 'g'), String(v));
  b = b.replace(/level flag::exists\(/g, 'flagExists(').replace(/level flag::get\(/g, 'flagGet(')
       .replace(/tod_door_data::get_door_info\(/g, 'doorInfo(').replace(/\bundefined\b/g, 'undefined');
  const locals = [...new Set([...b.matchAll(/^\s*(\w+)\s*=/gm)].map(m => m[1]))];
  const ctx = { level: {}, IS_TRUE: x => x === true, isdefined: x => x !== undefined, open: new Set(), known: null };
  ctx.flagExists = f => ctx.known ? ctx.known.has(f) : true;
  ctx.flagGet = f => ctx.open.has(f);
  ctx.doorInfo = f => doorZ.has(f) ? { org: [0, 0, doorZ.get(f)] } : undefined;
  vm.createContext(ctx);
  vm.runInContext('function door_frontier_z() { let ' + locals.join(',') + ';' + b + '}', ctx);
  const floor = n => (n - 1) * 384 + D.TOD_BOSS_FRONTIER_LIFT;
  // nothing bought: the frontier is lap 1's floor (the base arena stays legal)
  ctx.open = new Set(); assert.equal(ctx.door_frontier_z(), floor(1));
  // laps 1..k bought: the frontier is door k+1's landing
  for (const k of [1, 2, 9, 10, 27, 49]) {
    ctx.open = new Set(Array.from({ length: k }, (_, i) => 'enter_lap' + (i + 1)));
    assert.equal(ctx.door_frontier_z(), floor(k + 1), 'frontier after ' + k + ' laps');
  }
  // a gap counts from the LOWEST shut door, not the highest bought one
  ctx.open = new Set(['enter_lap1', 'enter_lap2', 'enter_lap4']); assert.equal(ctx.door_frontier_z(), floor(3));
  // all 50 laps but not the roof: the roof door is the frontier
  ctx.open = new Set(Array.from({ length: 50 }, (_, i) => 'enter_lap' + (i + 1))); assert.equal(ctx.door_frontier_z(), 50 * 384 + D.TOD_BOSS_FRONTIER_LIFT);
  ctx.open.add('enter_roof'); assert.equal(ctx.door_frontier_z(), undefined, 'everything bought: no frontier');
  // the spire has its own chain and boxes: never enforced there
  ctx.open = new Set(); ctx.level = { tod_spire_active: true }; assert.equal(ctx.door_frontier_z(), undefined); ctx.level = {};
  // a flag stock has not initialised yet reads as NO frontier, never as sealed
  ctx.known = new Set(); assert.equal(ctx.door_frontier_z(), undefined); ctx.known = null;
  // the pick applies it once per pick, before the zone gate, tower only
  const pick = body(bosses, 'pick_spawn_point');
  assert.ok(/frontier = door_frontier_z\(\);/.test(pick), 'computed once per pick');
  assert.ok(pick.indexOf('p[ 2 ] > frontier') < pick.indexOf('get_zone_from_position'), 'frontier before the zone gate');
  assert.ok(bosses.includes('#using scripts\\zm\\zm_tower_of_doom\\_tod_door_data;'));
  // the landing itself is legal, the first tread past the slab is not
  const f = floor(3); assert.ok(2 * 384 <= f && 2 * 384 + 12 > f, 'lift keeps the landing, rejects the first tread');
  console.log('item 2: door frontier — 12 flag states, generator lockstep, pick ordering. ok');
}

// ---------------------------------------------------------------- item 4: ARCHMAGE teardown
{
  const strip = s => s.replace(/\/\/.*$/gm, '');
  const run = strip(body(mage, 'demigod_run')), guard = strip(body(mage, 'demigod_guard')), end = strip(body(mage, 'demigod_end'));
  assert.ok(run.includes('self thread demigod_guard();'), 'run starts the guard');
  assert.ok(/self notify\( "tod_mage_demigod_end" \);\s*self demigod_end\( true \);/.test(run), 'timer end: stand the guard down, then teardown with sound');
  assert.ok(!/self\.tod_mage_demigod = undefined/.test(run), 'run no longer carries its own teardown copy');
  for (const s of ['self.tod_mage_demigod = undefined', 'tod_mage_demigod_mult = undefined', 'tod_mage_demigod_speed = undefined', 'tod_mage_demigod_pct = undefined', 'apply_sprint_fire()', 'apply_move_speed()'])
    assert.ok(end.includes(s), 'demigod_end: ' + s);
  assert.ok(/if \( sound \)\s*self PlayLocalSound\( "tod_mage_stance_off" \);/.test(end), 'stance-off only on the timer end');
  assert.ok(guard.includes('self util::waittill_any( "death", "tod_mage_disarm" );'), 'guard waits on death / disarm');
  assert.ok(guard.indexOf('self demigod_end( false );') < guard.indexOf('self notify( "tod_mage_demigod_run" );'), 'guard tears down BEFORE raising the event it endons');
  for (const e of ['"tod_mage_demigod_run"', '"tod_mage_demigod_end"', '"disconnect"']) assert.ok(guard.includes('self endon( ' + e + ' )'), 'guard endon ' + e);
  assert.equal((mage.match(/function demigod_end\(/g) || []).length, 1);
  console.log('item 4: ARCHMAGE ends with the body and with the class; one teardown. ok');
}

// ---------------------------------------------------------------- items 6 + 8: the tiles and the hint
{
  const send = body(mage, 'abil_send').replace(/\/\/.*$/gm, '');
  assert.ok(!/= -1;/.test(send), 'abil_send never sends -1 (hidden) for a mage any more');
  assert.ok(/if \( self charges_max\(\) < 1 \|\| charges < 0 \)\s*charges = 0;/.test(send), 'locked lethal -> 0 (dim)');
  assert.ok(/if \( self blink_capacity\(\) < 1 \|\| blink_charges < 0 \)\s*blink_charges = 0;/.test(send), 'locked tactical -> 0 (dim)');
  assert.ok(/if \( charges > 0 && !self ready\( "mage_heal" \) \)\s*charges = 0;/.test(send), 'aura lock dims the lethal tile');
  // evaluate the clamp as JS
  let b = send.replace(/self LuiNotifyEvent\([^;]*\);/, 'sent = [charges, blink_charges];').replace(/self (\w+)\(/g, '$1(').replace(/self\./g, 'S.');
  const ctx = { S: {}, sent: null, isdefined: x => x !== undefined, charges_max: () => 3, blink_capacity: () => 2, ready: () => true };
  vm.createContext(ctx);
  vm.runInContext('function abil_send(charges, blink_charges) {' + b + '}', ctx);
  const cases = [
    // [charges_max, blink_cap, ready, in c, in b] -> [out c, out b]
    [[0, 0, true, -1, -1], [0, 0]],   // fresh mage: dim, not hidden
    [[3, 2, true, 2, 1], [2, 1]],     // normal
    [[3, 2, false, 2, 1], [0, 1]],    // aura lock: lethal dims, blink untouched
    [[3, 2, false, 0, 0], [0, 0]],
    [[0, 2, true, 5, 2], [0, 2]],     // lethal locked, blink live
  ];
  for (const [[cm, bc, rdy, c, bl], want] of cases) {
    ctx.charges_max = () => cm; ctx.blink_capacity = () => bc; ctx.ready = () => rdy; ctx.S = {}; ctx.sent = null;
    ctx.abil_send(c, bl);
    assert.equal(JSON.stringify(ctx.sent), JSON.stringify(want), JSON.stringify([cm, bc, rdy, c, bl]));   // vm arrays are another realm: compare by value
  }
  // the lock tell brackets exactly the aura's own lock and re-sends through the same gate
  const cast = body(mage, 'cast_heal'), tell = body(mage, 'heal_lock_tell');
  assert.ok(cast.includes('self arm_cooldown( "mage_heal", TOD_MAGE_HEAL_TICKS * TOD_MAGE_HEAL_TICK_SECS );'));
  assert.ok(cast.includes('self thread heal_lock_tell( TOD_MAGE_HEAL_TICKS * TOD_MAGE_HEAL_TICK_SECS );'));
  assert.equal((tell.match(/self abil_send\( self charges_now\(\), self blink_charges_now\(\) \);/g) || []).length, 2, 'send at lock, send at release');
  assert.ok(/wait secs \+ 0\.05;/.test(tell));
  // the Lua draws 0 as a DIM tile (everHad true), which is the whole point of sending 0 instead of -1
  const lua = fs.readFileSync(path.join(root, 'ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumLoadout.lua'), 'utf8');
  assert.ok(/self\.lethal\.everHad = charges >= 0/.test(lua) && /elseif slot\.everHad then\s*slot\.tile:setAlpha\( 0\.40 \)/.test(lua), 'Lua: 0 with everHad draws dim');
  // the hint: once, only while something is locked, delayed, ends on disarm
  const arm = body(mage, 'class_arm_watch'), hint = body(mage, 'mage_first_hint');
  assert.ok(/if \( !IS_TRUE\( self\.tod_mage_hint_shown \) && \( self arch_level\(\) < 1 \|\| self charges_max\(\) < 1 \|\| self blink_capacity\(\) < 1 \) \)/.test(arm), 'hint gated on something locked, once');
  assert.ok(arm.includes('self.tod_mage_hint_shown = true;') && arm.includes('self thread mage_first_hint();'));
  assert.ok(hint.includes('self endon( "tod_mage_disarm" );') && /wait 4;/.test(hint) && /IPrintLnBold\( "MAGE: HEALING AURA, BLINK and ARCHMAGE unlock with their upgrade cards" \)/.test(hint));
  console.log('items 6 + 8: tiles dim (never hidden), aura lock dims the lethal, one first-arm hint. ok');
}

// ---------------------------------------------------------------- item 9: the window exists (behaviour in test_mage_reload_mana.js)
{
  const D = defines(mage);
  assert.ok(D.TOD_MAGE_RELOAD_MANA_WINDOW_MS >= 5000, 'reload reward window');
  const r = body(mage, 'reload_mana_complete');
  assert.ok(r.indexOf('tod_mage_reload_paid_ms + TOD_MAGE_RELOAD_MANA_WINDOW_MS') < r.indexOf('self mana_add( TOD_MAGE_RELOAD_MANA );'), 'window checked before the payment');
  console.log('item 9: reload reward window ' + D.TOD_MAGE_RELOAD_MANA_WINDOW_MS + ' ms, checked before payment. ok');
}
console.log('test_mage_fixes_0910: PASS');
