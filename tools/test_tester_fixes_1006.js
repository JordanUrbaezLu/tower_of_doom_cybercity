// tools/test_tester_fixes_1006.js — the lead tester's Oct 4-6 2026 list, the ten fixes
// the user signed off on (v19.76). Server half; the HUD half is test_tester_fixes_1006.lua.
//
// EXECUTED (the shipping GSC bodies, translated, against mocks):
//   1  the spire's bypass watchdog sends a player above a TRIAL-sealed door back to
//      the hall and opens an ordinary door free as before (+ negative control: the
//      v19.75 body opens the trial door);
//   4  unpaused_wait counts only unpaused frames; powerup_pause_hold hands back the
//      stock clocks' 0.05 only while paused and only for live power-ups;
//   2  the summit respawn lock over the .map's real respawn groups;
//   7  the King bar push block in the gauge heartbeat (off on a fresh game, on at
//      the landing, 1 s re-send, re-armed per life, off at the win);
// PINNED (source shape, each with the line that would regress it):
//   2  king_win keeps the summit gate shut and the containment box; the .map's summit
//      rails reach both corners and the gate, and the gate carries its player clip;
//   3  no first-raise flourish on card swaps / the PaP drop / the sidearm (swap_primary,
//      give_secondary); a tier promotion (every class) and the paid machine keep theirs;
//   4  Zombie Blood / Infinite Ammo / Time Warp skip their tick while paused; Double
//      Points' grab is the pause-aware copy;
//   5  the closing song is Pauseable and the finale's clock probe is wired;
//   6  the thinned riser effects are precached, zoned and assigned on both VMs;
//   7  the King bar eventstring is precached in _tod_gauge and _tod_spire no longer pushes it.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert/strict');

const REPO = path.join(__dirname, '..');
const rd = p => fs.readFileSync(path.join(REPO, p), 'utf8');
const spire = rd('scripts/zm/zm_tower_of_doom/_tod_spire.gsc');
const sdata = rd('scripts/zm/zm_tower_of_doom/_tod_spire_data.gsc');
const pu = rd('scripts/zm/zm_tower_of_doom/_tod_powerups.gsc');
const up = rd('scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc');
const cls = rd('scripts/zm/zm_tower_of_doom/_tod_classes.gsc');
const fin = rd('scripts/zm/zm_tower_of_doom/_tod_finale.gsc');
const ia = rd('scripts/zm/logical/powerups/_zm_powerup_infiniteammo.gsc');
const tw = rd('scripts/zm/logical/powerups/_zm_powerup_timewarp.gsc');
const mainGsc = rd('scripts/zm/zm_tower_of_doom.gsc');
const mainCsc = rd('scripts/zm/zm_tower_of_doom.csc');
const zone = rd('zone_source/zm_tower_of_doom.zone');
const csv = rd('sound/aliases/tod_ui.csv');
const map = rd('map_source/zm/zm_tower_of_doom.map');

function body(src, name) {
  const at = src.indexOf('function ' + name + '(');
  if (at < 0) throw new Error('no function ' + name);
  const start = src.indexOf('{', at);
  let end = start + 1, depth = 1;
  while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
  return src.slice(start + 1, end - 1);
}
const KW = new Set(['return', 'if', 'while', 'for', 'else', 'wait', 'case', 'new', 'typeof', 'in', 'of', 'const', 'let']);
// GSC -> JS for the small, flat bodies run here (no vectors, no threads that matter)
function gsc(s) {
  s = s.replace(/\/\/[^\n]*/g, '').replace(/\/#[\s\S]*?#\//g, '');
  s = s.replace(/(\w+)\s+endon\([^;]*;/g, '');
  s = s.replace(/foreach\s*\(\s*(\w+)\s+in\s+([^)]+?)\s*\)/g, 'for (const $1 of $2)');
  s = s.replace(/for\s*\(\s*;\s*;\s*\)/g, 'for (let __once = 0; __once < 1; __once++)');
  s = s.replace(/\b(\w+)\s+thread\s+([\w:]+)\s*\(/g, (m, o, f) => `${f.split('::').pop()}(${o}, `);
  s = s.replace(/\b(\w+)\s+([A-Za-z_][\w]*(?:::\w+)?)\s*\(/g, (m, o, f) => (KW.has(o) ? m : `${f.split('::').pop()}(${o}, `));
  s = s.replace(/\b\w+::(\w+)\s*\(/g, '$1(');
  s = s.replace(/\bint\(/g, 'Math.trunc(');
  return s;
}
const arr = a => { a.size = a.length; return a; };

// =============================================================================
// 1. THE TRIAL SKIP — the watchdog, executed
// =============================================================================
{
  const wd = body(spire, 'door_bypass_watchdog');
  assert.ok(/hub = trial_hub_for_sale\(\);\s*if \( seal_active\(\) && hub > 0 \)\s*\{\s*p trial_bypass_return\( hub \);\s*continue;/.test(wd),
    '1: the watchdog asks the seal BEFORE it may open a door, and sends the player back');
  const run = (src, scene) => {
    const ctx = {
      Math, undefined, calls: [], notes: [],
      isdefined: x => x !== undefined && x !== null, IS_TRUE: x => x === true,
      isplayer: p => !!(p && p.player), isalive: p => !!(p && p.alive),
      GetPlayers: () => arr(scene.players),
      in_spire: () => true,
      notify: (o, n) => ctx.notes.push(n),
      trial_bypass_return: (p, hub) => ctx.calls.push([p.id, hub]),
      level: Object.assign({}, scene.level),
    };
    vm.createContext(ctx);
    vm.runInContext(`function trial_hub_of_door(n) {${gsc(body(sdata, 'trial_hub_of_door'))}}
      function is_hub(n) {${gsc(body(sdata, 'is_hub'))}}
      function trial_hub_for_sale() {${gsc(body(spire, 'trial_hub_for_sale'))}}
      function seal_active() {${gsc(body(spire, 'seal_active'))}}
      function tick() {${gsc(src).replace(/wait [0-9.]+;/g, '')}}`, ctx);
    vm.runInContext('tick()', ctx);
    return ctx;
  };
  const above = { id: 0, player: true, alive: true, origin: [0, 0, 3840 + 300] };
  const below = { id: 1, player: true, alive: true, origin: [0, 0, 3840 + 100] };
  // door 11 is the trial door of hub 10 (door z 3840), sealed until the trial is won
  let c = run(wd, { players: [above, below], level: { tod_spire_next_door_z: 3840, tod_spire_next_door_n: 11, tod_spire_trial_seal: true } });
  assert.deepEqual(c.calls, [[0, 10]], '1: the player above the sealed trial door goes back to hub 10, the one below stays');
  assert.deepEqual(c.notes, [], '1: a trial-sealed door is NEVER opened free');
  assert.ok(!c.level.tod_spire_door_bypassed, '1: no bypass marker on a sealed door');
  // door 12 is an ordinary door: the failed-door safety net still opens it
  c = run(wd, { players: [above], level: { tod_spire_next_door_z: 3840, tod_spire_next_door_n: 12 } });
  assert.deepEqual(c.notes, ['tod_spire_door_bought'], '1: an ordinary door past which a player stands still opens free');
  assert.equal(c.level.tod_spire_door_bypassed, true);
  assert.deepEqual(c.calls, []);
  // the trial door AFTER the win: the seal is gone, so it behaves like any door
  c = run(wd, { players: [above], level: { tod_spire_next_door_z: 3840, tod_spire_next_door_n: 11 } });
  assert.deepEqual(c.notes, ['tod_spire_door_bought'], '1: a won trial door is an ordinary door again');
  // nobody past the door: nothing
  c = run(wd, { players: [below], level: { tod_spire_next_door_z: 3840, tod_spire_next_door_n: 11, tod_spire_trial_seal: true } });
  assert.deepEqual([c.calls, c.notes], [[], []], '1: nobody above the threshold, nothing happens');
  // NEGATIVE CONTROL: the v19.75 body (no seal question) opens the sealed trial door
  const old = wd.replace(/hub = trial_hub_for_sale\(\);\s*if \( seal_active\(\) && hub > 0 \)\s*\{[\s\S]*?continue;[^}]*\}/, '');
  assert.notEqual(old, wd, 'negative control built');
  c = run(old, { players: [above], level: { tod_spire_next_door_z: 3840, tod_spire_next_door_n: 11, tod_spire_trial_seal: true } });
  assert.deepEqual(c.notes, ['tod_spire_door_bought'], 'negative control: the old watchdog opened the trial door - the bug the tester hit');
  // the return trip itself: a downed player is left alone, the toast and the log are sent
  const ret = body(spire, 'trial_bypass_return');
  assert.ok(/if \( self laststand::player_is_in_laststand\(\) \)\s*return;/.test(ret), '1: a downed player is not teleported');
  assert.ok(ret.includes('tod_spire_data::trial_mark_org( hub, z )') && ret.includes('GetClosestPointOnNavMesh( dest, 64, 15 )'), '1: the destination is the hall mark, snapped to the navmesh');
  assert.ok(ret.includes('self tod_upgrade_ui::toast( TOD_TOAST_TRIAL_SEALED, hub );'), '1: the player is told why');
  assert.ok(ret.includes('TRIAL_BYPASS_BLOCKED'), '1: the evidence line');
  assert.ok(/level\.tod_spire_next_door_z = tod_spire_data::spire_door_z\( n \);\s*level\.tod_spire_next_door_n = n;/.test(spire), '1: the door manager publishes the door number');
  assert.ok(rd('scripts/zm/zm_tower_of_doom/_tod_toast.gsh').includes('#define TOD_TOAST_TRIAL_SEALED      11'), '1: the toast id');
  assert.ok(rd('ui/uieditor/menus/hud/tod_upgrade.lua').includes('[ 11 ] = { GOLD, "THE TRIAL BELOW IS NOT WON", "WIN IT TO CLIMB" }'), '1: the toast words (LOCKSTEP with the id)');
  console.log('1 trial skip: sealed trial door -> back to the hall, ordinary door -> opens as before, won door -> ordinary; negative control reproduces the skip - PASS');
}

// =============================================================================
// 2. THE SUMMIT — the gate stays shut, the box stays, the rails close
// =============================================================================
{
  const kw = body(spire, 'king_win');
  assert.ok(!/gate Hide\(\)|gate NotSolid\(\)|gate ConnectPaths\(\)/.test(kw), '2: king_win no longer opens the summit gate');
  assert.ok(kw.includes('level.tod_trial_box = tod_spire_data::summit_box();'), '2: the containment box stays on the summit (nothing spawns stranded below the shut gate)');
  assert.ok(kw.includes('level.tod_trial_active = undefined;'), '2: the trial cadence still ends');
  // the .map: brush extents by label, from the plane text (axial boxes)
  const CB = require('./convex_brush');
  const brush = label => {
    const i = map.indexOf('// brush ');
    const re = new RegExp('// brush \\d+ — ' + label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\r?\\n\\{\\r?\\n([\\s\\S]*?)\\r?\\n\\}');
    const m = map.match(re);
    assert.ok(m, 'brush ' + label);
    return CB.hull(CB.readPlanes(m[1]));
  };
  const S = brush('spire summit well rail S'), R = brush('spire summit rim rail'), E = brush('spire summit well rail E');
  assert.ok(S.lo[0] <= R.lo[0] + 0.01, '2: the well rail S reaches the rim rail\'s outer x (SW corner closed)');
  assert.ok(S.hi[0] >= E.hi[0] - 0.01, '2: the well rail S reaches the east rail\'s outer x (SE corner closed)');
  assert.ok(R.hi[1] >= 10240 * 0 + 272 - 0.01, '2: the rim rail runs on to the gate\'s north face (y 272) - the slot is closed');
  // the gate entity: two brushes, the second a player clip from the gate top up
  const gm = map.match(/\/\/ entity \d+ — spire summit gate[\s\S]*?(?=\/\/ entity \d+ — )/);
  assert.ok(gm, 'the summit gate entity');
  const gtxt = gm[0];
  const nb = (gtxt.match(/\n\{/g) || []).length;
  assert.ok(nb >= 2 && /clip_player/.test(gtxt) && /27464/.test(gtxt), '2: the summit gate carries its player clip up to the seals\' height');
  // THE RESPAWN LOCK (review): with the gate shut for good, a respawn may only come
  // back on the deck. Executed over the .map's real respawn groups.
  const kr = body(spire, 'king_run');
  const dp = kr.indexOf('gate DisconnectPaths();'), rl = kr.indexOf('summit_respawn_only();');
  assert.ok(dp >= 0 && rl > dp, '2: the respawn lock runs at the seal, after the gate is solid');
  const groups = [...map.matchAll(/"script_noteworthy" "(\w+)"\r?\n"target" "tod_respawn_\w+"/g)].map(m => ({ script_noteworthy: m[1], locked: false }));
  assert.ok(groups.length >= 8 && groups.some(g => g.script_noteworthy === 'spire_summit_zone'), '2: the .map has the spire respawn groups incl. the summit\'s');
  const rctx = { Math, undefined, logs: [], isdefined: x => x !== undefined && x !== null,
    get_array: (v, k) => arr(v === 'player_respawn_point' && k === 'targetname' ? groups : []),
    king_log: m => rctx.logs.push(m) };
  vm.createContext(rctx);
  vm.runInContext(`function __zones() {${gsc(body(sdata, 'spire_zone_names'))}}
    function spire_zone_names() { const a = __zones(); a.size = a.length; return a; }
    function summit_respawn_only() {${gsc(body(spire, 'summit_respawn_only'))}}`, rctx);
  vm.runInContext('summit_respawn_only()', rctx);
  for (const g of groups)
    assert.equal(g.locked, g.script_noteworthy !== 'spire_summit_zone', '2: ' + g.script_noteworthy + (g.script_noteworthy === 'spire_summit_zone' ? ' stays open' : ' is locked'));
  assert.ok(/kept=1 locked=\d+/.test(rctx.logs[0]), '2: the lock logs what it did: ' + rctx.logs[0]);
  // the kept box must not keep the trials' rise-at-your-feet bias on after the King
  const er = rd('scripts/zm/zm_tower_of_doom/_tod_endless_rounds.gsc');
  assert.ok(er.includes('if ( IS_TRUE( level.tod_trial_active ) && spots.size > 1 && RandomInt( 100 ) < TOD_TRIAL_NEAR_PCT )'), '2: the near-player rise bias is a FIGHT rule (trials + the King), not a box rule');
  console.log('2 summit: gate stays shut + box kept at the win; rail S reaches both corners; the rim rail meets the gate; the gate is clipped above; only the summit respawn group stays open - PASS');
}

// =============================================================================
// 3. NO FLOURISH ON AN UPGRADE SWAP
// =============================================================================
{
  const sp = body(up, 'swap_primary');
  const give = sp.indexOf('want = self tod_classes::give_camo_weapon( want );');
  const off = sp.indexOf('self ShouldDoInitialWeaponRaise( want, false );');
  const sw = sp.indexOf('self SwitchToWeaponImmediate( want );');
  assert.ok(give >= 0 && off > give && sw > off, '3: swap_primary turns the first raise off AFTER the give and BEFORE the switch');
  assert.ok(/if \( tod_classes::pap_staff_id\( want \) == 0 && !machine_show && !IS_TRUE\( showcase \) \)\s*self ShouldDoInitialWeaponRaise\( want, false \);/.test(sp), '3: staffs keep their own presentation (give_camo_weapon decides), and so do the paid machine and the promotion');
  assert.ok(/^function swap_primary\( w, want, fresh, showcase \)/m.test(up), '3: swap_primary takes the optional showcase flag');
  const callers = [...up.matchAll(/swap_primary\(([^;]*)\);/g)].map(m => m[1].split(',').length);
  assert.deepEqual(callers.sort(), [3, 4], '3: exactly two callers - reconcile_twin with three args (no showcase), tier_up with four');
  // THE PAID MACHINE KEEPS ITS SHOW (review): zm_cwpap stamps the 5,000 buy, swap_primary
  // honours a FRESH crossing within 3 s of it and spends the stamp either way.
  const cw = rd('scripts/zm/zm_cwpap.gsc');
  const grant = cw.indexOf('tod_classes::pap_first_grant( player, weapon );'), stamp = cw.indexOf('player.tod_pap_flourish_ms = GetTime();');
  assert.ok(grant >= 0 && stamp > grant && stamp - grant < 800, '3: the machine stamps the buy right after granting the pack');
  assert.ok(sp.includes('machine_show = ( IS_TRUE( fresh ) && isdefined( self.tod_pap_flourish_ms ) && ( GetTime() - self.tod_pap_flourish_ms ) <= 3000 );')
    && sp.indexOf('self.tod_pap_flourish_ms = undefined;') > sp.indexOf('machine_show ='), '3: a fresh swap within 3 s of the buy keeps the flourish; the stamp is spent');
  const tu = body(up, 'tier_up');
  // THE PROMOTION IS THE SHOWCASE (user, on the review): every class's tier-up
  // keeps the new weapon's first raise - the Mage's added staff included.
  const mg0 = tu.indexOf('want = player tod_classes::give_camo_weapon( want );');
  const mageGift = tu.slice(mg0, tu.indexOf('player SwitchToWeapon( want );', mg0));
  assert.ok(mg0 >= 0 && mageGift.length > 0 && !mageGift.includes('ShouldDoInitialWeaponRaise'), '3: the Mage\'s tier-up staff keeps its first raise (the promotion showcase)');
  assert.ok(tu.includes('ok = player swap_primary( old, want, true, true );'), '3: every other class promotes through swap_primary WITH the showcase');
  const gs = body(cls, 'give_secondary');
  assert.ok(/w = self give_camo_weapon\( w \);\s*self GiveStartAmmo\( w \);[\s\S]{0,400}if \( pap_staff_id\( w \) == 0 \)\s*self ShouldDoInitialWeaponRaise\( w, false \);/.test(gs), '3: the promoted sidearm too');
  console.log('3 upgrade flourish: off on card twin swaps, the free PaP drop and the sidearm; ON for every tier promotion (the Mage staff too) and the paid machine - PASS');
}

// =============================================================================
// 4. POWER-UPS PAUSE WITH THE CARDS — executed
// =============================================================================
{
  // unpaused_wait as a frame-stepped generator
  const src = gsc(body(pu, 'unpaused_wait')).replace(/wait 0\.05;/g, 'yield;');
  const ctx = { IS_TRUE: x => x === true, level: {} };
  vm.createContext(ctx);
  vm.runInContext(`function* unpaused_wait(secs) {${src}}`, ctx);
  const frames = (secs, pausedAt) => {
    const g = ctx.unpaused_wait(secs);
    let f = 0;
    for (;;) { ctx.level.tod_upgrade_pause = pausedAt(f); if (g.next().done) return f; f++; }
  };
  assert.equal(frames(30, () => false), 600, '4: 30 s unpaused = 600 frames');
  assert.equal(frames(30, f => f >= 100 && f < 400), 900, '4: a 15 s card pause adds exactly 300 frames');
  assert.equal(frames(1, () => false), 20);
  // NEGATIVE CONTROL: a plain wait (the old insta-kill) ignores the pause
  vm.runInContext('function* plain(secs) { let l = secs; while (l > 0) { yield; l -= 0.05; } }', ctx);
  { const g = ctx.plain(30); let f = 0; while (!g.next().done) f++; assert.equal(f, 600, 'negative control: the plain wait ends at 600 frames whatever the pause'); }

  // powerup_pause_hold, one frame
  const hold = gsc(body(pu, 'powerup_pause_hold')).replace(/wait 0\.05;/g, '');
  const run = (paused, scene) => {
    const c = { Math, undefined, isdefined: x => x !== undefined && x !== null, IS_TRUE: x => x === true,
      array: (...a) => arr(a), GetPlayers: () => arr(scene.players), level: { tod_upgrade_pause: paused, zombie_vars: scene.vars } };
    vm.createContext(c);
    vm.runInContext(`function tick() {${hold}}`, c);
    vm.runInContext('tick()', c);
    return c;
  };
  const mk = () => ({
    vars: { allies: { zombie_powerup_double_points_on: true, zombie_powerup_double_points_time: 12,
                      zombie_powerup_insta_kill_on: false, zombie_powerup_insta_kill_time: 30 } },
    players: [{ team: 'allies', zombie_vars: { zombie_powerup_minigun_on: true, zombie_powerup_minigun_time: 7 } },
              { team: 'allies', zombie_vars: { zombie_powerup_minigun_on: false, zombie_powerup_minigun_time: 0 } }],
  });
  let s = mk(); run(true, s);
  assert.ok(Math.abs(s.vars.allies.zombie_powerup_double_points_time - 12.05) < 1e-9, '4: a live team clock gets its 0.05 back while paused');
  assert.equal(s.vars.allies.zombie_powerup_insta_kill_time, 30, '4: an idle clock is never touched');
  assert.ok(Math.abs(s.players[0].zombie_vars.zombie_powerup_minigun_time - 7.05) < 1e-9, '4: the Gift of Death clock is held');
  assert.equal(s.players[1].zombie_vars.zombie_powerup_minigun_time, 0, '4: no Gift, no clock');
  s = mk(); s.players.push({ team: 'allies', zombie_vars: {} }); run(true, s);
  assert.ok(Math.abs(s.vars.allies.zombie_powerup_double_points_time - 12.05) < 1e-9, '4: the team clock is held ONCE per team, not once per player');
  s = mk(); run(false, s);
  assert.equal(s.vars.allies.zombie_powerup_double_points_time, 12, '4: nothing is held while the world runs');

  // the rest, pinned
  assert.ok(/unpaused_wait\( N_POWERUP_DEFAULT_TIME \);\s*level\.tod_dmg_mult = 1;/.test(body(pu, 'instakill_3x_override')), '4: Insta-Kill counts unpaused time');
  assert.ok(/unpaused_wait\( N_POWERUP_DEFAULT_TIME \);\s*level\.zombie_vars\[ team \]\[ "zombie_point_scalar" \] = 1;/.test(body(pu, 'double_points_paused')), '4: Double Points counts unpaused time');
  assert.ok(pu.includes('level._custom_powerups[ "double_points" ].grab_powerup = &grab_double_points_paused;') && pu.includes('level thread powerup_pause_hold();'), '4: the Double Points grab is replaced and the hold runs');
  const zbw = body(pu, 'zombie_blood_window');
  assert.ok(/wait 0\.05;\s*(\/\/[^\n]*\s*)*if \( IS_TRUE\( level\.tod_upgrade_pause \) \)\s*continue;\s*self\.zombie_vars\[ "zombie_powerup_zombie_blood_time" \] = self\.zombie_vars\[ "zombie_powerup_zombie_blood_time" \] - 0\.05;/.test(zbw), '4: Zombie Blood skips its tick while paused');
  for (const [src, v] of [[ia, 'infiniteammo'], [tw, 'timewarp']])
    assert.ok(new RegExp('wait\\( 0\\.05 \\);\\s*(//[^\\n]*\\s*)*if \\( IS_TRUE\\( level\\.tod_upgrade_pause \\) \\)\\s*continue;\\s*level\\.zombie_vars\\["zombie_powerup_' + v + '_time"\\]').test(src), '4: ' + v + ' skips its tick while paused');
  console.log('4 power-ups: unpaused_wait +300 frames for a 15 s pause (plain wait: none), the stock clocks held once per team only while paused, every timed power-up wired - PASS');
}

// =============================================================================
// 5. THE FINALE'S SONG PAUSES
// =============================================================================
{
  const lines = csv.split(/\r?\n/), hdr = lines[0].split(',');
  const row = lines.find(l => l.startsWith('tod_music_finale,')).split(',');
  assert.equal(row[hdr.indexOf('Pauseable')], 'yes', '5: the closing song pauses with a solo pause');
  for (const tag of ['"START"', '"SEAL hold_s="', '"PYLON "', '"READY"']) assert.ok(fin.includes('finale_clock_log( ' + tag), '5: clock probe ' + tag);
  assert.ok(fin.includes('level.tod_finale_utc_start  = GetUTC();'), '5: wall time captured with the song');
  console.log('5 finale pause: tod_music_finale Pauseable, the game-vs-wall clock probe at start / seal / each pylon / ready - PASS');
}

// =============================================================================
// 6. THE SMOKE
// =============================================================================
{
  for (const n of ['rise_burst', 'rise_billow', 'rise_dust']) {
    const fx = 'tod/zombie/fx_tod_' + n;
    assert.ok(mainGsc.includes(`level._effect[ "${n}" ]`) && mainGsc.includes(`"${fx}"`) && mainGsc.includes(`#precache( "fx", "${fx}" );`), '6: server ' + n);
    assert.ok(mainCsc.includes(`level._effect[ "${n}" ]`) && mainCsc.includes(`#precache( "client_fx", "${fx}" );`), '6: client ' + n);
    assert.ok(zone.includes('fx,' + fx), '6: zoned ' + n);
    assert.ok(fs.existsSync(path.join(REPO, 'share/raw/fx/' + fx + '.efx')), '6: source ' + n);
  }
  // after zm_usermap::main on both sides (stock assigns them inside / before it)
  for (const [src, side] of [[mainGsc, 'server'], [mainCsc, 'client']]) {
    const m = src.indexOf('zm_usermap::main();'), a = src.indexOf('level._effect[ "rise_dust" ]');
    assert.ok(m >= 0 && a > m, '6: the ' + side + ' override comes after zm_usermap::main');
  }
  console.log('6 smoke: the thinned rise effects precached, zoned and assigned after stock on both VMs - PASS');
}

// =============================================================================
// 7. THE KING BAR (server) — executed + pinned
// =============================================================================
{
  // The lane lives in the gauge heartbeat (review, v19.76): every fresh HUD and every
  // fresh GAME gets an explicit state on its first tick, so a bar left on by the last
  // game (the HUD menu survives map_restart) cannot hide the next game's gauge.
  const gauge = rd('scripts/zm/zm_tower_of_doom/_tod_gauge.gsc');
  const uiGsc = rd('scripts/zm/zm_tower_of_doom/_tod_upgrade_ui.gsc');
  const loop = body(gauge, 'gauge_loop');
  const at = loop.indexOf('kb = king_bar_permille();');
  assert.ok(at >= 0, '7: the gauge heartbeat feeds the King bar');
  // the push block: from the read to the end of its if
  let i = loop.indexOf('{', loop.indexOf('if (', at)), depth = 1, j = i + 1;
  while (depth) { if (loop[j] === '{') depth++; if (loop[j] === '}') depth--; j++; }
  const block = loop.slice(at, j);
  const ctx = { Math, undefined, sent: [], now: 0, isdefined: x => x !== undefined && x !== null, level: {},
    GetTime: () => ctx.now, LuiNotifyEvent: (p, ev, n, a, b) => ctx.sent.push([ev, n, a, b]) };
  vm.createContext(ctx);
  vm.runInContext(`function king_bar_permille() {${gsc(body(gauge, 'king_bar_permille'))}}
    function tick(p) {${gsc(block).replace(/&"/g, '"')}}`, ctx);
  const pm = f => { ctx.level.tod_king_hp_frac = f; return ctx.king_bar_permille(); };
  assert.deepEqual([pm(undefined), pm(1), pm(0.5), pm(0.9996), pm(0.0004), pm(1.3), pm(-0.2)], [-1, 1000, 500, 1000, 0, 1000, 0], '7: permille clamps and rounds; -1 = no fight');
  const p = {};
  const step = (frac, ms) => { ctx.level.tod_king_hp_frac = frac; ctx.now = ms; ctx.sent = []; ctx.tick(p); return ctx.sent.map(s => s.slice(2).join(',')); };
  assert.deepEqual(step(undefined, 0), ['0,0'], '7: a fresh player gets OFF on the first tick (the map_restart latch)');
  assert.deepEqual(step(undefined, 350), [], '7: OFF is change-gated (no spam in tower play)');
  assert.deepEqual(step(1.0, 700), ['1,1000'], '7: his landing turns the bar on, full');
  assert.deepEqual(step(1.0, 1050), [], '7: no change, inside the second - nothing');
  assert.deepEqual(step(1.0, 1750), ['1,1000'], '7: the 1 s re-send while the fight is on');
  assert.deepEqual(step(0.42, 2100), ['1,420'], '7: a change goes at once');
  delete p.tod_king_bar_shown;   // player_lui_life on a respawn
  assert.deepEqual(step(0.42, 2200), ['1,420'], '7: a respawned HUD learns the bar on its first tick');
  assert.deepEqual(step(0, 2550), ['1,0'], '7: his death empties it');
  assert.deepEqual(step(undefined, 2900), ['0,0'], '7: king_win clearing the fraction turns it off');
  assert.ok(gauge.includes('#precache( "eventstring", "tod_king_bar" );') && gauge.indexOf('#precache( "eventstring", "tod_king_bar" );') < gauge.indexOf('#namespace tod_gauge;'), '7: the eventstring is precached (LuiNotifyEvent is silent without it)');
  assert.ok(!spire.includes('tod_king_bar') && !spire.includes('king_bar_push_all'), '7: _tod_spire no longer pushes the bar itself (one owner)');
  assert.ok(/level\.tod_king_hp_frac = \( boss\.health \* 1\.0 \) \/ boss\.maxhealth;/.test(body(spire, 'king_hp_bar')), '7: king_hp_bar still publishes the fraction the bar reads');
  assert.ok(body(spire, 'king_win').includes('level.tod_king_hp_frac = undefined;'), '7: the win clears it (the bar goes, the gauge + luck bar come back)');
  assert.ok(uiGsc.includes('self.tod_king_bar_shown = undefined;'), '7: player_lui_life re-arms it per life');
  console.log('7 king bar (server): permille clamps; off on a fresh game, on at the landing, 1 s re-send, re-armed per life, off at the win - PASS');
}
console.log('tester fixes 1006 (server half): all checks PASS');
