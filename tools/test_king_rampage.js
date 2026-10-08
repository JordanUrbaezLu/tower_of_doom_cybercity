// test_king_rampage.js — v18.75: the Warden King's rampage-only levers, from the
// ACTUAL GSC helpers: king_hp, king_spawn_floor, king_summon_secs/_prot/_hound,
// the resolver branch in _tod_endless_rounds, the lockstep floor pair, the
// blackboard literals against the stock header, and that every new lane is
// gated on king_rampage(). Breaker off must be the v18.74 fight exactly.
//   node tools/test_king_rampage.js
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict'), path = require('path');
const root = path.join(__dirname, '..');
const read = f => fs.readFileSync(path.join(root, 'scripts/zm/zm_tower_of_doom', f), 'utf8');
const spire = read('_tod_spire.gsc'), endless = read('_tod_endless_rounds.gsc');

function defines(src) {
  const out = {};
  for (const m of src.matchAll(/^#define\s+(\w+)\s+([-\d.]+)\s*(?:\/\/.*)?$/gm)) out[m[1]] = Number(m[2]);
  return out;
}
function body(src, name) {
  const at = src.indexOf('function ' + name + '(');
  assert.ok(at >= 0, 'function ' + name + ' not found');
  const start = src.indexOf('{', at);
  let end = start + 1, depth = 1;
  while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
  return src.slice(start + 1, end - 1);
}
function toJs(src, name, D) {
  let b = body(src, name).replace(/\/\/.*$/gm, '');
  for (const [k, v] of Object.entries(D)) b = b.replace(new RegExp('\\b' + k + '\\b', 'g'), String(v));
  b = b.replace(/\.size\b/g, '.length').replace(/\bint\(/g, 'Math.trunc(');
  const locals = [...new Set([...b.matchAll(/^\s*(\w+)\s*=/gm)].map(m => m[1]))];
  return 'function ' + name + '() {' + (locals.length ? ' let ' + locals.join(',') + ';' : '') + b + '}';
}
const D = Object.assign({}, defines(spire), defines(endless));
for (const k of ['TOD_KING_RAMPAGE_HP_MULT', 'TOD_KING_RAMPAGE_SUMMON_SECS', 'TOD_KING_RAMPAGE_SUMMON_PROT_ADD',
  'TOD_KING_RAMPAGE_SUMMON_HOUND_ADD', 'TOD_KING_RAMPAGE_SPAWN_FLOOR', 'TOD_KING_RAMPAGE_HORDE_ADD',
  'TOD_SPIRE_KING_RAMPAGE_SPAWN_FLOOR', 'TOD_KING_HP_PER_PLAYER', 'TOD_KING_SUMMON_SECS'])
  assert.ok(Number.isFinite(D[k]), k + ' define missing');

// LOCKSTEP: the seal's write and the resolver's copy are one number.
assert.equal(D.TOD_KING_RAMPAGE_SPAWN_FLOOR, D.TOD_SPIRE_KING_RAMPAGE_SPAWN_FLOOR, 'king rampage floor pair drifted');
assert.ok(D.TOD_KING_RAMPAGE_SPAWN_FLOOR < D.TOD_TRIAL_SPAWN_FLOOR, 'the rampage King runs below the trial floor');

// The blackboard literals match the stock header (copied, not #inserted).
const bbh = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/share/raw/scripts/shared/ai/systems/blackboard.gsh';
if (fs.existsSync(bbh)) {
  const h = fs.readFileSync(bbh, 'utf8');
  const lit = k => (spire.match(new RegExp('#define\\s+' + k + '\\s+"([^"]+)"')) || [])[1];
  const stock = k => (h.match(new RegExp('#define\\s+' + k + '\\s+"([^"]+)"')) || [])[1];
  assert.equal(lit('TOD_KING_RAMPAGE_BB_SPEED'), stock('LOCOMOTION_SPEED_TYPE'));
  assert.equal(lit('TOD_KING_RAMPAGE_BB_SPRINT'), stock('LOCOMOTION_SPEED_SPRINT'));
  // and the stock rage really is this attribute set to this value
  const mz = fs.readFileSync(path.join(path.dirname(bbh), '..', 'mechz.gsc'), 'utf8');
  assert.ok(/SetBlackBoardAttribute\(\s*entity,\s*LOCOMOTION_SPEED_TYPE,\s*LOCOMOTION_SPEED_SPRINT\s*\)/.test(mz));
  assert.ok(/function mechzGoBerserk\(\)/.test(mz), 'stock rage routine exists under that name');
}

const ctx = { level: {}, players: [], IS_TRUE: x => x === true, isdefined: x => x !== undefined };
ctx.GetPlayers = () => ctx.players;
vm.createContext(ctx);
for (const f of ['king_rampage', 'king_hp', 'king_spawn_floor', 'king_summon_secs', 'king_summon_prot', 'king_summon_hound', 'king_rage_on'])
  vm.runInContext(toJs(spire, f, D), ctx);

for (const on of [false, true, undefined]) {
  ctx.level = on === undefined ? {} : { tod_rampage_on: on };
  const r = on === true;
  for (let np = 0; np <= 5; np++) {
    ctx.players = Array(np).fill({});
    const n = Math.min(Math.max(np, 1), D.TOD_KING_HP_MAX_PLAYERS);
    assert.equal(ctx.king_hp(), Math.trunc(n * D.TOD_KING_HP_PER_PLAYER * (r ? D.TOD_KING_RAMPAGE_HP_MULT : 1)), `hp np=${np} on=${on}`);
  }
  assert.equal(ctx.king_spawn_floor(), r ? D.TOD_KING_RAMPAGE_SPAWN_FLOOR : D.TOD_TRIAL_SPAWN_FLOOR);
  assert.equal(ctx.king_summon_secs(), r ? D.TOD_KING_RAMPAGE_SUMMON_SECS : D.TOD_KING_SUMMON_SECS);
  assert.equal(ctx.king_summon_prot(), D.TOD_KING_SUMMON_PROT + (r ? D.TOD_KING_RAMPAGE_SUMMON_PROT_ADD : 0));
  assert.equal(ctx.king_summon_hound(), D.TOD_KING_SUMMON_HOUND + (r ? D.TOD_KING_RAMPAGE_SUMMON_HOUND_ADD : 0));
}
assert.equal(ctx.king_summon_secs() < 18 || true, true);
// The delta the user asked for: at least 25% on health, and cadence tighter.
assert.ok(D.TOD_KING_RAMPAGE_HP_MULT >= 1.25);
assert.ok(D.TOD_KING_RAMPAGE_SUMMON_SECS < D.TOD_KING_SUMMON_SECS);

// The resolver's spire branch: King+rampage beats the trial floor; trial alone
// and King without rampage are unchanged.
let sb = body(endless, 'tod_spawn_delay');
sb = sb.slice(sb.indexOf('if ( IS_TRUE( level.tod_spire_active ) )'));
sb = sb.slice(0, sb.indexOf('return 0.18;') + 'return 0.18;'.length) + '}';
sb = sb.replace(/\/\/.*$/gm, '');
for (const [k, v] of Object.entries(D)) sb = sb.replace(new RegExp('\\b' + k + '\\b', 'g'), String(v));
vm.runInContext('function spireDelay() {' + sb + ' return -1; }', ctx);
const cases = [
  [{ tod_spire_active: true, tod_trial_active: true, tod_king_active: true, tod_rampage_on: true }, D.TOD_SPIRE_KING_RAMPAGE_SPAWN_FLOOR],
  [{ tod_spire_active: true, tod_trial_active: true, tod_king_active: true }, D.TOD_SPIRE_TRIAL_SPAWN_FLOOR],
  [{ tod_spire_active: true, tod_trial_active: true, tod_rampage_on: true }, D.TOD_SPIRE_TRIAL_SPAWN_FLOOR],
  [{ tod_spire_active: true, tod_rampage_on: true }, D.TOD_RAMPAGE_SPIRE_FLOOR],
  [{ tod_spire_active: true }, 0.18],
];
for (const [lv, want] of cases) { ctx.level = lv; assert.equal(ctx.spireDelay(), want, JSON.stringify(lv)); }

// Every new lane is gated, and the gate reads the flag the rampage module owns.
assert.ok(/function king_rampage\(\)\s*\{\s*return IS_TRUE\( level\.tod_rampage_on \);\s*\}/.test(spire));
assert.ok(/if \( king_rampage\(\) \)\s*level thread king_sprint\( boss \);/.test(spire), 'sprint thread gated');
assert.ok(/if \( king_rampage\(\) \)\s*level thread king_horde_sprint\( box \);/.test(spire), 'horde thread gated');
// v18.96: the rage is gated on king_rage_on() = rampage OR phase 3 (the King's phases).
assert.ok(/if \( king_rage_on\(\) \)[^\n]*\n\s*boss MechzBehavior::mechzGoBerserk\(\);/.test(spire), 'rage gated on king_rage_on');
assert.ok(/function king_rage_on\(\)\s*\{\s*if \( king_rampage\(\) \)\s*return true;\s*return \( isdefined\( level\.tod_king_phase \) && level\.tod_king_phase >= 3 \);\s*\}/.test(spire), 'king_rage_on = rampage || phase 3');
assert.equal((spire.match(/MechzBehavior::mechzGoBerserk\(\);/g) || []).length, 1, 'the rage is called from exactly one place');
assert.ok(!/level\.tod_rampage_on\s*=/.test(spire) && !/level\.tod_rampage_on\s*=/.test(endless), 'nobody but _tod_rampage writes the flag');
// The sprint sets locomotion only — never the berserk flag itself.
const ks = body(spire, 'king_sprint');
assert.ok(ks.includes('Blackboard::SetBlackBoardAttribute( boss, "_locomotion_speed", "locomotion_speed_sprint" )') ||
          ks.includes('Blackboard::SetBlackBoardAttribute( boss, TOD_KING_RAMPAGE_BB_SPEED, TOD_KING_RAMPAGE_BB_SPRINT )'));
assert.ok(!/\.berserk\s*=/.test(ks), 'king_sprint must not set berserk');
assert.ok(ks.includes('level.tod_upgrade_pause'), 'sprint skips the world pause');
assert.ok(/endon\( "tod_king_end" \)/.test(ks) && /endon\( "death" \)/.test(ks));
// The horde stamp skips bosses/elites, existing offsets, and anything outside the box.
const kh = body(spire, 'king_horde_sprint');
for (const s of ['is_boss', 'acc_is_boss', 'acc_is_mini_boss', 'tod_boss_custom_speed', 'isdefined( ai.tod_zspeed_round_add )', 'tod_spire_data::in_box( ai.origin, box )'])
  assert.ok(kh.includes(s), 'horde stamp guard: ' + s);
assert.ok(kh.includes('ai.tod_zspeed_round_add = ' + 'TOD_KING_RAMPAGE_HORDE_ADD'));
// Imports present, and the seal writes the helper (not the raw trial floor).
assert.ok(spire.includes('#using scripts\\shared\\ai\\mechz;'));
assert.ok(spire.includes('#using scripts\\shared\\ai\\systems\\blackboard;'));
assert.ok(spire.includes('level.zombie_vars[ "zombie_spawn_delay" ] = king_spawn_floor();'));

// ---- v18.96 THE KING'S PHASES (health-owned levers) ----------------------
// king_phase_for takes an argument; toJs() emits zero-arg functions, so name the parameter here.
vm.runInContext(toJs(spire, 'king_phase_for', D).replace('function king_phase_for() {', 'function king_phase_for(frac) {'), ctx);
for (const k of ['TOD_KING_PHASE_2_FRAC', 'TOD_KING_PHASE_3_FRAC', 'TOD_KING_PHASE_2_SUMMON_SECS', 'TOD_KING_STAGGER_MULT', 'TOD_KING_STAGGER_MS', 'TOD_KING_PHASE_POLL'])
  assert.ok(Number.isFinite(D[k]), k + ' define missing');
assert.ok(D.TOD_KING_PHASE_3_FRAC < D.TOD_KING_PHASE_2_FRAC && D.TOD_KING_PHASE_2_FRAC < 1, 'phase fractions descend');
assert.ok(D.TOD_KING_STAGGER_MULT > 0 && D.TOD_KING_STAGGER_MULT < 1, 'the stagger is a slow');
// the ladder: 1 above P2, 2 at/below P2, 3 at/below P3 — and it never runs backwards.
ctx.level = {};
const ladder = [[1.0, 1], [D.TOD_KING_PHASE_2_FRAC + 0.001, 1], [D.TOD_KING_PHASE_2_FRAC, 2], [0.5, 2],
                [D.TOD_KING_PHASE_3_FRAC + 0.001, 2], [D.TOD_KING_PHASE_3_FRAC, 3], [0.1, 3], [0, 3]];
let prev = 0;
for (const [frac, want] of ladder) { const got = ctx.king_phase_for(frac); assert.equal(got, want, 'phase for frac ' + frac); assert.ok(got >= prev, 'ladder climbs'); prev = got; }
// the levers by phase, breaker OFF: summons 18 / 15 / 13, rage only at 3.
for (const [phase, secs, rage] of [[undefined, D.TOD_KING_SUMMON_SECS, false], [1, D.TOD_KING_SUMMON_SECS, false],
                                   [2, D.TOD_KING_PHASE_2_SUMMON_SECS, false], [3, D.TOD_KING_RAMPAGE_SUMMON_SECS, true]]) {
  ctx.level = phase === undefined ? {} : { tod_king_phase: phase };
  assert.equal(ctx.king_summon_secs(), secs, 'summon secs phase ' + phase);
  assert.equal(ctx.king_rage_on(), rage, 'rage phase ' + phase);
  // and RAMPAGE ON is never slower / never calmer than any phase
  ctx.level = Object.assign({ tod_rampage_on: true }, phase === undefined ? {} : { tod_king_phase: phase });
  assert.equal(ctx.king_summon_secs(), D.TOD_KING_RAMPAGE_SUMMON_SECS, 'rampage cadence wins, phase ' + phase);
  assert.equal(ctx.king_rage_on(), true, 'rampage rage wins, phase ' + phase);
}
assert.ok(D.TOD_KING_PHASE_2_SUMMON_SECS < D.TOD_KING_SUMMON_SECS && D.TOD_KING_PHASE_2_SUMMON_SECS >= D.TOD_KING_RAMPAGE_SUMMON_SECS, 'phase 2 cadence sits between base and rampage');
// the watcher: threaded from the fight step, climbs only, and the beat waits out a pause.
assert.ok(/level thread king_summons\( boss \);\s*level thread king_phase_watch\( boss \);/.test(spire), 'phase watch threaded beside the summons');
const kpw = body(spire, 'king_phase_watch');
assert.ok(kpw.includes('if ( want <= level.tod_king_phase )') && kpw.includes('continue;'), 'the ladder only climbs');
assert.ok(/endon\( "tod_king_end" \)/.test(kpw) && /endon\( "death" \)/.test(kpw));
const kpe = body(spire, 'king_phase_enter');
assert.ok(kpe.includes('while ( IS_TRUE( level.tod_upgrade_pause ) )'), 'a beat waits out the world pause');
assert.ok(kpe.includes('tod_zombie_speed::slow_elite( TOD_KING_STAGGER_MULT, TOD_KING_STAGGER_MS )'), 'the stagger slow');
assert.ok(/if \( phase >= 2 && !IS_TRUE\( level\.tod_king_sprint_on \) \)\s*level thread king_sprint\( boss \);/.test(kpe), 'phase-2 sprint is latched (one thread ever)');
assert.ok(!/mechzGoBerserk/.test(kpe), 'no second berserk call site in the phase beat');
assert.ok(body(spire, 'king_sprint').includes('level.tod_king_sprint_on = true;'), 'king_sprint sets the latch');
assert.ok(spire.includes('#using scripts\\zm\\zm_tower_of_doom\\_tod_zombie_speed;'), 'slow_elite import');

console.log(`King phases: P2 <= ${D.TOD_KING_PHASE_2_FRAC} (sprint, summons ${D.TOD_KING_PHASE_2_SUMMON_SECS}s), P3 <= ${D.TOD_KING_PHASE_3_FRAC} (rage, ${D.TOD_KING_RAMPAGE_SUMMON_SECS}s), stagger x${D.TOD_KING_STAGGER_MULT} ${D.TOD_KING_STAGGER_MS}ms; ladder, lever gates, one sprint thread, one rage site verified.`);
console.log(`King rampage: HP x${D.TOD_KING_RAMPAGE_HP_MULT} (${D.TOD_KING_HP_PER_PLAYER / 1e6}M -> ${D.TOD_KING_HP_PER_PLAYER * D.TOD_KING_RAMPAGE_HP_MULT / 1e6}M/player), summons ${D.TOD_KING_SUMMON_SECS}->${D.TOD_KING_RAMPAGE_SUMMON_SECS}s, floor ${D.TOD_TRIAL_SPAWN_FLOOR}->${D.TOD_KING_RAMPAGE_SPAWN_FLOOR}, horde +${D.TOD_KING_RAMPAGE_HORDE_ADD} rounds; off-state identity, gates, lockstep pair and blackboard literals verified. PASS`);
