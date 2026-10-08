// The lead tester's 2026-09-24 report: executes the actual GSC/generated logic
// for each fix (translated function bodies, mocked natives) and pins the
// source shapes a translation cannot reach. Run from anywhere: node tools/test_tester_fixes_0924.js
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict'), path = require('path');
const root = path.resolve(__dirname, '..');
const read = f => fs.readFileSync(path.join(root, f), 'utf8').replace(/\r\n/g, '\n');
const noComments = s => s.replace(/\/\/[^\n]*/g, '');
function body(src, name) {
  src = noComments(src);
  const at = src.indexOf('function ' + name + '(');
  assert(at >= 0, 'function ' + name + ' not found');
  let a = src.indexOf('{', at), b = a + 1, d = 1;
  while (d) { if (src[b] === '{') d++; if (src[b] === '}') d--; b++; }
  return src.slice(a + 1, b - 1);
}
// GSC -> JS for the small bodies below: foreach, .size, namespaces and the
// `ent Method( args )` call form (named per call so nothing is guessed).
function js(src, methods) {
  let s = src.replace(/foreach \( (\w+) in ([^)]+) \)/g, 'for (const $1 of $2)')
    .replace(/\.size\b/g, '.length')
    .replace(/\b\w+::/g, '');
  for (const m of methods)
    s = s.replace(new RegExp('([\\w.\\]\\[]+) ' + m + '\\(', 'g'), m + '($1,');
  return s;
}
const classes = read('scripts/zm/zm_tower_of_doom/_tod_classes.gsc');
const entry = read('scripts/zm/zm_tower_of_doom.gsc');
const bosses = read('scripts/zm/zm_tower_of_doom/_tod_bosses.gsc');
const hounds = read('scripts/zm/zm_tower_of_doom/_tod_hellhounds.gsc');
const mechz = read('scripts/zm/mechz_spiki.gsc');
const mage = read('scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc');
const rounds = read('scripts/zm/zm_tower_of_doom/_tod_endless_rounds.gsc');
const qr = read('scripts/zm/zm_tower_of_doom/_tod_perk_lights.gsc');
const crate = read('scripts/zm/zm_tower_of_doom/_tod_ammo_crate.gsc');
const breather = read('scripts/zm/zm_tower_of_doom/_tod_breather_data.gsc');
const gameover = read('scripts/zm/zm_tower_of_doom/_tod_gameover.gsc');
const secret = read('scripts/zm/zm_tower_of_doom/_tod_secret.gsc');
const board = read('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumScoreboard.lua');
const hud = read('ui/uieditor/menus/hud/AetheriumHud.lua');
const startMenu = read('ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua');
let checks = 0;
const ok = (c, m) => { assert(c, m); checks++; };

// ---- 1. RK5: stock's Easter-egg reward points at the start pistol ----------
{
  const code = noComments(entry);
  const main = code.indexOf('zm_usermap::main();');
  const start = code.indexOf('level.start_weapon = GetWeapon( "pistol_standard" );');
  const ee = code.indexOf('level.super_ee_weapon = level.start_weapon;');
  ok(main >= 0 && start > main && ee > start, 'super_ee_weapon must be overridden AFTER zm_usermap::main (init_levelvars) and after start_weapon');
  // the repair lane: take_foreign_secondaries reaps any RK5, keeps the class sidearm
  const env = { isdefined: x => x !== undefined, IsSubStr: (s, k) => s.includes(k), TOD_RK5_STEM: 'pistol_burst',
    secondary_all_stems: () => ['s1_bulldog', 't9_magnum', 'pistol_standard', 't9_amp63'],
    taken: [], logs: [], loadout_dev_log: m => env.logs.push(m),
    GetWeaponsListPrimaries: p => p.weapons, TakeWeapon: (p, w) => env.taken.push(w.name), GetEntityNumber: () => 0 };
  vm.createContext(env);
  vm.runInContext('function take(self, keep_stem) {' + js(body(classes, 'take_foreign_secondaries'), ['GetWeaponsListPrimaries', 'TakeWeapon', 'GetEntityNumber']) + '}', env);
  const player = { weapons: [{ name: 't9_ak47_up_r1' }, { name: 't9_magnum_b' }, { name: 'pistol_burst' }, { name: 'pistol_standard' }] };
  env.take(player, 't9_magnum');
  ok(env.taken.includes('pistol_burst') && env.taken.includes('pistol_standard') && !env.taken.includes('t9_magnum_b') && !env.taken.includes('t9_ak47_up_r1'),
    'RK5 + foreign MR6 reaped, class sidearm and primary kept: ' + env.taken);
  ok(env.logs.some(l => l.includes('RK5 reaped')), 'the RK5 reap is logged');
  env.taken = []; env.take({ weapons: [{ name: 'pistol_burst_upgraded' }] }, '');
  ok(env.taken.includes('pistol_burst_upgraded'), 'a mage (empty keep stem) also loses a packed RK5');
}

// ---- 2. Zombie Blood: the closest-player override filters its own list ------
{
  const env = { isdefined: x => x !== undefined,
    is_player_valid: (p, checkIgnore) => !!p && p.alive !== false && !p.down && !(checkIgnore && p.ignoreme),
    ArrayGetClosest: (o, arr) => arr.reduce((b, p) => (b === undefined || Math.abs(p.x - o) < Math.abs(b.x - o)) ? p : b, undefined) };
  vm.createContext(env);
  vm.runInContext('function pick(self, origin, players) {' + js(body(entry, 'tod_closest_player'), []) + '}', env);
  const blood = { name: 'blood', x: 1, ignoreme: true }, near = { name: 'near', x: 5 }, downed = { name: 'down', x: 0, down: true };
  ok(env.pick({}, 0, [blood, near, downed]) === near, 'the Panzer lane skips Zombie Blood and downed players');
  ok(env.pick({}, 0, [blood, downed]) === undefined, 'nobody targetable -> undefined (stock fallback filters)');
  ok(env.pick({ zombie_poi: {} }, 0, [near]) === undefined, 'the POI carve-out is kept');
}

// ---- 3. Zombie Blood: every boss aggro site asks the TARGETABLE question ------
{
  const code = noComments(bosses);
  const retarget = body(bosses, 'retarget_loop'), hunt = body(bosses, 'hunt_players'), fire = body(bosses, 'fire_loop');
  ok(retarget.includes('is_player_valid( p, true )') && retarget.includes('drop_untargetable( "panzer" )'), 'Panzer retarget honours ignoreme and drops');
  ok(hunt.includes('is_player_valid( p, true )') && hunt.includes('drop_untargetable( "protector" )'), 'Protector hunt honours ignoreme and drops');
  ok((fire.match(/is_player_valid\( self\.(enemy|favoriteenemy), true \)/g) || []).length === 2, 'Protector never fires at an ignored player');
  ok(/zm_utility::is_player_valid\( p, true \)\s*\)\s*continue;\s*if \( DistanceSquared\( self\.origin, p\.origin \) > TOD_RP_ZAP_RANGE/.test(code), 'no zap pulse for an ignored player');
  ok(/function pick_target_player\( targetable = false \)/.test(code) && body(bosses, 'pick_target_player').includes('is_player_valid( players[ i ], targetable )'), 'spawn anchoring keeps its old answer by default');
  const hw = body(hounds, 'hound_target_watch');
  ok(hw.includes('is_player_valid( self.favoriteenemy, true )') && hw.includes('pick_target_player( true )'), 'hounds re-target only to targetable players');
  ok(noComments(mechz).includes('if(!zm_utility::is_player_valid(self, 1))'), 'the claw refuses an ignored player');
  // drop_untargetable, executed
  const env = { isdefined: x => x !== undefined, isplayer: x => !!x && x.player === true, IS_TRUE: x => x === true,
    is_player_valid: (p, c) => !(c && p.ignoreme), logs: [], blood_dev_log: m => env.logs.push(m),
    GetEntityNumber: e => e.num, goals: [], SetGoal: (e, g) => env.goals.push(g) };
  vm.createContext(env);
  vm.runInContext('function drop(self, kind) {' + js(body(bosses, 'drop_untargetable'), ['GetEntityNumber', 'SetGoal']) + '}', env);
  const boss = { num: 40, origin: 7, favoriteenemy: { player: true, num: 1, ignoreme: true, tod_in_blood: true } };
  env.drop(boss, 'panzer');
  ok(boss.favoriteenemy === undefined && env.goals[0] === 7 && env.logs[0].includes('blood=true'), 'an ignored target is dropped, the boss stands, the drop is logged');
  const keep = { num: 41, origin: 8, favoriteenemy: { player: true, num: 2 } };
  env.drop(keep, 'panzer');
  ok(keep.favoriteenemy !== undefined && env.goals.length === 1, 'a still-targetable target is kept');
}

// ---- 4. Music: no stock round-over cue from the endless round wait ----------
ok(!/sndMusicSystem_PlayState/.test(noComments(rounds)), 'the round_end music state is gone from _tod_endless_rounds');

// ---- 5. Quick Revive: co-op waits for power before stamping the BUY hint ----
{
  const b = body(qr, 'solo_qr_price_fix');
  const wait = b.indexOf('flag::wait_till( "power_on" )'), guard = b.lastIndexOf('if ( !solo )', wait), stamp = b.indexOf('SetHintString');
  ok(wait > 0 && guard > 0 && wait - guard < 200 && stamp > wait, 'the co-op branch waits for power before the first SetHintString');
  ok(b.indexOf('t.power_on = true;') > wait, 'nothing marks the trigger powered before the co-op power wait');
}

// ---- 6. Ammo crate: the runtime trigger IS the generator's, and covers ------
{
  const num = n => +breather.match(new RegExp('function crate_trig_' + n + '\\(\\)\\s*\\{ return (-?\\d+); \\}'))[1];
  const OUT = num('out'), LAT = num('lat'), LIFT = num('lift'), R = num('r');
  // v19.69: Nikolai's chest (98 across, centred) moved the trigger to the front face
  // line, on the centre line: 44/13 -> 38/0; v19.69b his lidless V6 is shallower: 33/0
  // (gen_tower_map.js CRATE_TRIG_*).
  ok(OUT === 33 && LAT === 0 && LIFT === 60 && R === 100, 'generated crate trigger numbers');
  const t = body(crate, 'trig_org_for');
  ok(t.includes('crate_trig_out()') && t.includes('crate_lat( yaw )') && t.includes('crate_trig_lat()') && t.includes('crate_trig_lift()'), 'the script uses all four generated numbers');
  ok(body(crate, 'crate_lat').includes('yaw + 180') && body(crate, 'crate_front').includes('yaw + 90'), 'front = yaw + 90, lateral = yaw + 180');
  ok(!/TOD_CRATE_TRIG_LIFT/.test(noComments(crate)), 'no second lift constant left in the script');
  // AnglesToForward in the engine's convention; the E-yaw box from gen_tower_map's crateBox.
  const fwd = yaw => [Math.cos(yaw * Math.PI / 180), Math.sin(yaw * Math.PI / 180)];
  const LOCAL = { f1: -37, f2: 33, l1: -49, l2: 49 }, C = 16;   // v19.69b: tod_ammo_chest (V6)'s box (the West crate's was f -37..38, l -19..45)
  for (const yaw of [0, 90, 180, 270]) {
    const f = fwd(yaw + 90), l = fwd(yaw + 180);
    const trig = [f[0] * OUT + l[0] * LAT, f[1] * OUT + l[1] * LAT];
    const at = (F, L) => [f[0] * F + l[0] * L, f[1] * F + l[1] * L];
    const spots = [];
    for (let L = LOCAL.l1 - C; L <= LOCAL.l2 + C; L += 2) spots.push([LOCAL.f2 + C, L]);
    for (let F = LOCAL.f1; F <= LOCAL.f2 + C; F += 2) spots.push([F, LOCAL.l1 - C], [F, LOCAL.l2 + C]);
    for (const [F, L] of spots) { const p = at(F, L); ok(Math.hypot(p[0] - trig[0], p[1] - trig[1]) <= R + 1e-9, `yaw ${yaw}: (${F},${L}) outside the trigger`); }
    // the OLD recipe really did miss the far half of a long side (the report)
    const old = [f[0] * 56, f[1] * 56], far = at(LOCAL.f1, LOCAL.l1 - C);
    ok(Math.hypot(far[0] - old[0], far[1] - old[1]) > 72, `yaw ${yaw}: the old trigger reached the far end (negative control)`);
  }
}

// ---- 7. End-of-game stats: the forced board shows, the menu waits -----------
{
  ok(board.includes('Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN ) or todForced()') && board.includes('Engine.CreateModel( Engine.GetModelForController( controller ), "forceScoreboard" )'),
    'AetheriumScoreboard answers stock\'s forceScoreboard');
  // v19.68r (docs/170): the HUD's hide writers are ONE rule (todHide + TodHudApply, Tower II's) - the forced board
  // is a LATCHED reason in it, and any reason hides the HUD pieces.
  ok(hud.includes('local function TodHudApply()') && /local base = \( todHide\.scoreboard or todHide\.force or todHide\.ui or todHide\.veil \) and 0 or 1/.test(hud)
     && /"forceScoreboard" \), function \( model \)\s*if Engine\.GetModelValue\( model \) == 1 then\s*todHide\.force = true\s*TodHudApply\(\)/.test(hud),
    'the HUD hides under the forced board');
  const off = body(gameover, 'offer_restart_on_end');
  const w = off.indexOf('wait TOD_GO_STATS_SECS;'), rel = off.indexOf('LUINotifyEvent( &"force_scoreboard", 1, 0 );');
  ok(+gameover.match(/#define TOD_GO_STATS_SECS\s+(\d+)/)[1] >= 8 && w > 0 && rel > w && !/\bwait 3;/.test(off), 'the stats window precedes the release and the menu');
  const need = +gameover.match(/#define TOD_GO_STATS_SECS\s+(\d+)/)[1] + 0.1 + +gameover.match(/#define TOD_GO_DECIDE_SECS\s+(\d+)/)[1];
  ok(need < +gameover.match(/#define TOD_GO_FAILSAFE_SECS\s+(\d+)/)[1], 'the failsafe still fires after the main flow');
  ok(body(gameover, 'init').includes('SetDvar( "tod_go_won", "" );') && off.includes('SetDvar( "tod_go_won", ( ( won ) ? "1" : "" ) );'), 'the win title dvar is scrubbed and set');
  ok(startMenu.includes('TodGoWon(controller) and "Victory" or "Game Over"'), 'the menu titles a win "Victory"');
}

// ---- 8. Downed mage: mana_push reports state 4 in last stand ----------------
{
  const env = { IS_TRUE: x => x === true, isdefined: x => x !== undefined, sent: [],
    player_is_in_laststand: p => p.down === true, arch_level: p => p.arch, mana_send: (p, v, s) => env.sent.push([v, s]) };
  vm.createContext(env);
  vm.runInContext('function push(self, value) {' + js(body(mage, 'mana_push'), ['player_is_in_laststand', 'arch_level', 'mana_send']) + '}', env);
  env.push({ down: true, arch: 3, tod_mage_demigod: true }, 80);
  env.push({ down: false, arch: 0 }, 50);
  env.push({ down: false, arch: 2 }, 50);
  ok(JSON.stringify(env.sent) === JSON.stringify([[0, 4], [0, 3], [50, 0]]), 'downed -> 4 (even mid-Archmage), locked -> 3, filling -> 0: ' + JSON.stringify(env.sent));
}

// ---- 9. The bear: a blade swing counts, in reach, in front, in sight --------
{
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const len = v => Math.hypot(v[0], v[1], v[2]);
  const env = { isdefined: x => x !== undefined, IS_TRUE: x => x === true, level: {}, logs: [], dev_log: m => env.logs.push(m),
    int: Math.trunc, Length: len, VectorNormalize: v => { const l = len(v); return v.map(c => c / l); },
    VectorDot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2], AnglesToForward: a => a,
    GetEye: p => p.eye, GetPlayerAngles: p => p.dir, BulletTracePassed: () => env.clear, clear: true, sub,
    TOD_SECRET_MELEE_REACH: +secret.match(/#define TOD_SECRET_MELEE_REACH\s+(\d+)/)[1],
    TOD_SECRET_MELEE_DOT: +secret.match(/#define TOD_SECRET_MELEE_DOT\s+([\d.]+)/)[1] };
  vm.createContext(env);
  const src = js(body(secret, 'melee_hits_bear'), ['GetEye', 'GetPlayerAngles']).replace(/bear\.origin - eye/g, 'sub(bear.origin, eye)');
  vm.runInContext('function swing(self) {' + src + '}', env);
  const bear = (idx, origin) => ({ tod_secret_idx: idx, origin });
  const player = { eye: [0, 0, 60], dir: [1, 0, 0] };
  env.level.tod_secret_bears = [bear(0, [70, 0, 14])];
  ok(env.swing(player) === env.level.tod_secret_bears[0], 'a swing at a floor bear 70 out counts');
  env.level.tod_secret_bears = [bear(0, [-70, 0, 14])];
  ok(env.swing(player) === undefined, 'a bear behind the swing does not');
  env.level.tod_secret_bears = [bear(2, [60, 0, 254])];
  ok(env.swing(player) === undefined, 'the hoop bear (~190 above the eye) stays a shot');
  env.clear = false; env.level.tod_secret_bears = [bear(1, [60, 0, 14])];
  ok(env.swing(player) === undefined, 'no hit through a wall'); env.clear = true;
  env.level.tod_secret_bears = [Object.assign(bear(1, [60, 0, 14]), { tod_secret_hit: true })];
  ok(env.swing(player) === undefined, 'a bear already found is not found twice');
  const watch = body(secret, 'shot_watch'), mw = body(secret, 'melee_watch');
  ok(/"weapon_melee", "weapon_melee_power"/.test(watch) && watch.includes('self thread melee_watch( note );') && !/waittill_any/.test(watch), 'one plain waittill loop per melee notify');
  ok(!/endon\( "death" \)/.test(mw) && mw.includes('self waittill( note );') && mw.includes('bear thread bear_found( bear.tod_secret_idx, self );'), 'the melee watcher survives deaths and lands on bear_found');
}

console.log(`Tester fixes 2026-09-24 passed (${checks} checks): RK5 reward and reap, Zombie Blood targeting (override, retarget, Protector, hounds, claw), no round-over cue, co-op QR waits for power, crate trigger covers the long sides at every yaw (old recipe fails its negative control), end-of-game stats window + Victory title, downed-mage HUD state, bear melee lane.`);
