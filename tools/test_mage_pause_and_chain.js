// Two mage timing rules, run as the SHIPPING GSC rather than a copy of it.
//
//  1. COOLDOWNS DO NOT ADVANCE THROUGH A WORLD PAUSE. Every value in
//     tod_mage_cd is an absolute GetTime() stamp -- BLINK's recharge deadline
//     and HEALING AURA's post-cast lock -- and GetTime() runs during a pause.
//     cd_pause_watch pushes future deadlines forward so a frozen, invulnerable
//     player does not come out of a card event with charges they never waited
//     for. The other two mage timers already did this their own way
//     (mana_watch skips the tick, charge_regen holds its countdown) and are
//     asserted here too, so a future edit cannot quietly break one of the three.
//
//  2. CHAIN LIGHTNING ARCS ONCE PER SHOT. upgrade_damage_cb threads staff_hit
//     once per DAMAGED ACTOR and a staff bolt is splash, so the arc selection
//     used to run once per splash victim -- 4 arcs per body in a crowd instead
//     of 4 per trigger pull.
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const SRC = 'scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc';
const src = fs.readFileSync(SRC, 'utf8').replace(/\r/g, '');

function body(name) {
  const clean = src.replace(/\/\/[^\n]*/g, '');
  const at = clean.indexOf('function ' + name + '(');
  assert.ok(at >= 0, 'no function ' + name + ' in ' + SRC);
  const a = clean.indexOf('{', at);
  let b = a + 1, d = 1;
  while (d) { if (clean[b] === '{') d++; if (clean[b] === '}') d--; b++; }
  return clean.slice(a + 1, b - 1);
}

let checks = 0;
const ok = (c, m) => { assert.ok(c, m); checks++; };

// ---------------------------------------------------------------------------
// 1. cd_pause_watch, run as a coroutine over a scripted pause timeline.
// ---------------------------------------------------------------------------
{
  const gsc = body('cd_pause_watch');
  // Translate the GSC loop into JS: `self` is the player object, `wait` yields,
  // and the two array helpers are the engine's.
  const js = gsc
    .replace(/self endon\([^)]*\);/g, '')
    .replace(/self notify\([^)]*\);/g, '')
    .replace(/\bself\./g, 'self.')
    .replace(/for \( ;; \)/, 'for ( ; tick < TIMELINE.length ; )')
    .replace(/wait 0\.25;/, 'step();')
    .replace(/GetArrayKeys\(([^)]*)\)/g, 'Object.keys($1)')
    .replace(/keys\.size/g, 'keys.length')   // GSC .size -> JS .length
    .replace(/IS_TRUE\(([^)]*)\)/g, '(($1) === true)')
    .replace(/isdefined\(([^)]*)\)/g, '(($1) !== undefined)')
    .replace(/\bGetTime\(\)/g, 'GetTime()');

  function run(timeline, cds) {
    const env = {
      TIMELINE: timeline, tick: 0, level: {}, self: { tod_mage_cd: Object.assign({}, cds) },
      _now: 0,
      GetTime: () => env._now,
      step() {
        const t = env.TIMELINE[env.tick++];
        env._now += t.ms;
        env.level.tod_upgrade_pause = t.paused ? true : undefined;
      },
    };
    vm.createContext(env);
    vm.runInContext('(function(){ let now, delta, last, keys, i, k; last = GetTime(); ' + js + ' })()', env);
    return { cd: env.self.tod_mage_cd, now: env._now };
  }

  // 4 s of pause in the middle of a 6 s window. A Blink deadline 5 s out must
  // come out ~4 s further away; the idle marker 0 must not move at all.
  const T = [];
  for (let i = 0; i < 4; i++) T.push({ ms: 250, paused: false });   // 1 s live
  for (let i = 0; i < 16; i++) T.push({ ms: 250, paused: true });   // 4 s paused
  for (let i = 0; i < 4; i++) T.push({ ms: 250, paused: false });   // 1 s live
  const r = run(T, { mage_blink: 5000, mage_heal: 3000, idle: 0 });

  // Slop is bounded by one poll at each edge of the pause; assert the window.
  const pushed = r.cd.mage_blink - 5000;
  ok(pushed >= 3750 && pushed <= 4250, 'BLINK deadline moved by ~4 s of pause, got ' + pushed);
  const heal = r.cd.mage_heal - 3000;
  ok(heal >= 3750 && heal <= 4250, 'HEALING AURA lock moved by ~4 s of pause, got ' + heal);
  ok(r.cd.idle === 0, 'an idle (0) deadline is never pushed, got ' + r.cd.idle);

  // With no pause at all, nothing moves — the watcher must be inert in normal play.
  const live = run(T.map(t => ({ ms: t.ms, paused: false })), { mage_blink: 5000, idle: 0 });
  ok(live.cd.mage_blink === 5000, 'no pause = no shift, got ' + live.cd.mage_blink);
  ok(live.cd.idle === 0, 'no pause = idle untouched');

  // A deadline already in the past stays in the past: a cooldown that finished
  // before the pause began must not be resurrected by it.
  const past = run(T, { mage_blink: -1 });
  ok(past.cd.mage_blink === -1, 'an elapsed deadline is not pushed, got ' + past.cd.mage_blink);
}

// ---------------------------------------------------------------------------
// 2. The other two timers must keep their own pause handling.
// ---------------------------------------------------------------------------
ok(/wait 1;\s*if \( IS_TRUE\( level\.tod_upgrade_pause \) \)\s*continue;/.test(src.replace(/\/\/[^\n]*/g, '')),
  'mana_watch no longer skips its tick while the world is paused');
ok(/wait 0\.25;\s*if \( IS_TRUE\( level\.tod_upgrade_pause \) \)\s*continue;\s*left -= 0\.25;/.test(src.replace(/\/\/[^\n]*/g, '')),
  'charge_regen no longer holds its countdown while the world is paused');
ok(/self thread cd_pause_watch\(\);/.test(src), 'cd_pause_watch is never started');

// ---------------------------------------------------------------------------
// 3. CHAIN LIGHTNING: one arc selection per shot, over the real staff_hit.
// ---------------------------------------------------------------------------
{
  const gsc = body('staff_hit');
  // Remove the per-shot claim from the GSC (brace-matched, not regex-guessed)
  // so the negative control is the SAME function minus exactly that block.
  function stripClaim(text) {
    const at = text.indexOf('if ( isdefined( attacker.tod_mage_shot_id ) )');
    assert.ok(at >= 0, 'the per-shot claim is gone from staff_hit');
    const a = text.indexOf('{', at);
    let b = a + 1, d = 1;
    while (d) { if (text[b] === '{') d++; if (text[b] === '}') d--; b++; }
    return text.slice(0, at) + text.slice(b);
  }
  // Each of these three is the ONLY statement of an `if`, so they must become a
  // no-op rather than vanish — deleting them outright leaves a dangling `if`
  // and the whole translation stops parsing.
  const translate = t => t
    .replace(/burn_dev_log\([^;]*\);/g, ';')                          // v19.26 dev log, nested parens
    .replace(/self thread elite_burn\([^;]*\);/g, 'burn(self);')      // v19.26 FIRE BLAST elite burn
    .replace(/self tod_zombie_speed::slow_elite\([^;]*\);/g, ';')    // v19.26 elite slow lane
    .replace(/self clientfield::set\([^)]*\);/g, ';')
    .replace(/self tod_zombie_speed::slow\([^;]*\);/g, ';')
    .replace(/tod_upgrades::is_boss_or_elite\(([^)]*)\)/g, 'is_boss_or_elite($1)')
    .replace(/tod_upgrades::get_level\(([^)]*)\)/g, 'get_level($1)')
    .replace(/ai thread chain_fx\(\);/g, 'fx(ai);')
    .replace(/\bIS_TRUE\(([^)]*)\)/g, '(($1) === true)')
    .replace(/isdefined\(([^)]*)\)/g, '(($1) !== undefined)')
    .replace(/foreach \( ai in ([^)]*) \)/g, 'for (const ai of $1)')
    .replace(/near\[ near\.size \] = ai;/g, 'near.push(ai);')
    .replace(/near\.size/g, 'near.length')
    .replace(/ai DoDamage\(([^;]*)\);/g, 'DoDamage(ai);');
  const js = translate(gsc);

  const env = {
    arcs: 0, level: { zombie_team: 'axis' },
    staff_element: () => 'lightning',
    chain_targets: () => 4,
    chain_fraction: () => 0.5,
    boss_kind: () => undefined,
    get_level: () => 0,
    IsAlive: () => true,
    Distance: () => 10,
    ArraySortClosest: (a, o, n) => a.slice(0, n),
    GetAITeamArray: () => env.horde,
    DoDamage: () => { env.arcs++; },
    fx: () => { env.fxHosts++; },
    fxHosts: 0,
    int: Math.trunc,
    TOD_MAGE_CHAIN_RADIUS: 220, TOD_MAGE_CHAIN_FRAC: 0.5,
    TOD_MAGE_ICE_SLOW_BASE: 1, TOD_MAGE_ICE_SLOW_PER_LV: 0.4, TOD_MAGE_ICE_SLOW_MULT: 0.80,
    // v19.26: the fire/ice arms are never entered by a lightning bolt, but the
    // translation must still resolve their helpers.
    staff_elite: () => false, ice_slow_mult: () => 0.45, is_boss_or_elite: () => false, burn: () => {},
  };
  vm.createContext(env);
  vm.runInContext('function staff_hit(self, attacker, weapon, dmg){ let el, n, share, near, i, ai, lv, secs, mult; ' + js + ' }', env);

  // Ten bodies in the blast. Every one of them gets its own staff_hit call,
  // exactly the way upgrade_damage_cb threads it.
  const bolt = (attacker, victims, dmg) => victims.forEach(v => env.staff_hit(v, attacker, {}, dmg));
  env.horde = Array.from({ length: 12 }, (_, i) => ({ origin: [i, 0, 0], id: i }));

  const player = { tod_mage_shot_id: 1 };
  env.arcs = 0;
  bolt(player, env.horde.slice(0, 10), 1000);
  ok(env.arcs === 4, 'one bolt into 10 bodies arcs 4 times, got ' + env.arcs);

  // The next trigger pull is a new shot and chains again.
  player.tod_mage_shot_id = 2;
  env.arcs = 0;
  bolt(player, env.horde.slice(0, 10), 1000);
  ok(env.arcs === 4, 'the next shot chains again, got ' + env.arcs);

  // A sub-threshold splash victim must NOT consume the shot's arc selection.
  player.tod_mage_shot_id = 3;
  env.arcs = 0;
  bolt(player, env.horde.slice(0, 3), 1);      // under the dmg < 2 floor
  ok(env.arcs === 0, 'trivial splash damage arcs nothing, got ' + env.arcs);
  bolt(player, env.horde.slice(3, 6), 1000);   // the real hit, same shot
  ok(env.arcs === 4, 'the real hit of that shot still chains, got ' + env.arcs);

  // Two mages firing in the same frame must not consume each other's shot.
  const a = { tod_mage_shot_id: 9 }, b = { tod_mage_shot_id: 9 };
  env.arcs = 0;
  bolt(a, env.horde.slice(0, 5), 1000);
  bolt(b, env.horde.slice(0, 5), 1000);
  ok(env.arcs === 8, 'two mages chain independently, got ' + env.arcs);

  // NEGATIVE CONTROL: without the per-shot claim this is once per victim.
  const naive = translate(stripClaim(gsc));
  assert.notEqual(naive, js, 'negative control could not strip the per-shot claim');
  vm.runInContext('function naive_hit(self, attacker, weapon, dmg){ let el, n, share, near, i, ai; ' + naive + ' }', env);
  const c = { tod_mage_shot_id: 1 };
  env.arcs = 0;
  env.horde.slice(0, 10).forEach(v => env.naive_hit(v, c, {}, 1000));
  ok(env.arcs === 40, 'negative control: without the claim, 10 splash victims arc 40 times, got ' + env.arcs);
}

console.log('mage pause + chain passed: ' + checks +
  ' assertions over the shipping cd_pause_watch and staff_hit, both negative controls fire.');
