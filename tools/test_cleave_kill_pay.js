// tools/test_cleave_kill_pay.js — CLEAVE KILL MONEY (2026-10-04, user: "Slashers cleave
// kills should be 75% of base kills. Lets fix that and make sure the display money is
// proper as well").
//
// Runs the SHIPPING GSC bodies (cleave_kill_claim / cleave_kill_settle /
// cleave_kill_points / cleave_death_score / bounty_kill_value / bounty_preview from
// _tod_upgrades.gsc, and the Aetherium kill popup's tod_popup_points arm from
// _zm_aetherium_hud.gsc) against a model of stock's death flow, and proves:
//   * a cleave KILL pays 75% of the stock melee kill (120 -> 90), x Double Points;
//   * the kill popup shows exactly what was paid, BOUNTY included, at every level;
//   * a cleave hit that does NOT kill hands the kill back to stock untouched;
//   * elites, a kill another script already paid, and a downed killer are left alone;
//   * cleave_splash claims BEFORE the DoDamage and settles AFTER it.
// Negative control: the same swing WITHOUT the claim pays stock's bare 50.
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');
const assert = require('assert/strict');

const REPO = path.join(__dirname, '..');
const STOCK = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/share/raw/scripts/zm';
const up = fs.readFileSync(path.join(REPO, 'scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc'), 'utf8');
const hud = fs.readFileSync(path.join(REPO, 'scripts/zm/_zm_aetherium_hud.gsc'), 'utf8');
const score = fs.readFileSync(path.join(STOCK, '_zm_score.gsc'), 'utf8');
const spawner = fs.readFileSync(path.join(STOCK, '_zm_spawner.gsc'), 'utf8');

function body(src, name) {
  const at = src.indexOf('function ' + name + '(');
  if (at < 0) throw new Error('no function ' + name);
  const start = src.indexOf('{', at);
  let end = start + 1, depth = 1;
  while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
  return src.slice(start + 1, end - 1);
}
function define(src, name) {
  const m = src.match(new RegExp('#define\\s+' + name + '\\s+("[^"]*"|[-0-9.]+)'));
  if (!m) throw new Error('no #define ' + name);
  return m[1].startsWith('"') ? m[1].slice(1, -1) : parseFloat(m[1]);
}
const gsc = s => s
  .replace(/\/\/[^\n]*/g, '')
  .replace(/\/#\s*PrintLn\(\s*line\s*\);\s*#\//g, 'log(line);')
  .replace(/attacker zm_spawner::player_can_score_from_zombies\(\)/g, 'player_can_score_from_zombies(attacker)')
  .replace(/attacker zm_score::player_add_points\(/g, 'player_add_points(attacker, ')
  .replace(/attacker zm_score::add_to_player_score\(/g, 'add_to_player_score(attacker, ')
  .replace(/attacker GetEntityNumber\(\)/g, '0')
  .replace(/zm_utility::|zm_score::/g, '')
  .replace(/\bint\(/g, 'Math.trunc(')
  .replace(/\[\[ level\.tod_bounty_preview_fn \]\]/g, 'level.tod_bounty_preview_fn');

const FRAC = define(up, 'TOD_CLEAVE_KILL_FRAC');
const EVENT = define(up, 'TOD_CLEAVE_SCORE_EVENT');
assert.equal(FRAC, 0.75, 'TOD_CLEAVE_KILL_FRAC is the user\'s 75%');

// --- pin the stock behaviour the model below stands in for ---------------------
assert.ok(score.includes('player_points = [[ level.a_func_score_events[ event ] ]]( event, mod, hit_location, zombie_team, damage_weapon );'), 'stock: registered score events are dispatched with mod as the 2nd arg');
assert.ok(score.includes('player_points = multiplier * zm_utility::round_up_score( player_points, 10 );'), 'stock: points x Double Points after the 10s rounding');
assert.ok(/if\( !zm_utility::is_player_valid\( self \) \)\s*\{\s*return;/.test(score), 'stock: a downed scorer is not paid');
{
  const zdp = body(spawner, 'zombie_death_points');
  const drop = zdp.indexOf('zombie_can_drop_powerups( zombie )'), latch = zdp.indexOf('IS_TRUE(zombie.deathpoints_already_given)');
  assert.ok(drop >= 0 && latch > drop, 'stock: the powerup roll comes BEFORE the deathpoints latch (a claimed cleave kill still drops powerups)');
}
assert.ok(up.includes('zm_score::register_score_event( TOD_CLEAVE_SCORE_EVENT, &cleave_death_score );'), 'the cleave score event is registered');

// --- the model ------------------------------------------------------------------
const ctx = {
  Math, undefined,
  isdefined: x => x !== undefined && x !== null,
  IS_TRUE: x => x === true,
  IS_EQUAL: (a, b) => a === b,
  IsPlayer: p => !!(p && p.player),
  IsAlive: z => !!(z && z.health > 0),
  IsSubStr: (s, k) => String(s).includes(k),
  GetTime: () => 1000,
  is_player_valid: p => !!(p && !p.downed),
  player_can_score_from_zombies: p => !p.inhibit,
  get_points_multiplier: p => ctx.level.zombie_vars[p.team].zombie_point_scalar,
  get_zombie_death_player_points: () => 50,
  round_up_score: (s, v) => { s = Math.trunc(s); const n = s - s % v; return n < s ? n + v : n; },
  TOD_CLEAVE_KILL_FRAC: FRAC, TOD_CLEAVE_SCORE_EVENT: EVENT,
  TOD_UPG_BOUNTY_PER_LVL: define(up, 'TOD_UPG_BOUNTY_PER_LVL'), TOD_DARK_BOUNTY_ADD: define(up, 'TOD_DARK_BOUNTY_ADD'),
  logs: [], log: l => ctx.logs.push(l),
  events: {},
  level: { tod_dev: true, zombie_team: 'axis', zombie_vars: { zombie_score_bonus_melee: 70, allies: { zombie_point_scalar: 1 } } },
  get_level: (p, d) => (d === 'bounty' ? p.bounty || 0 : 0),
  has_dark: (p, d) => d === 'bounty' && !!p.darkBounty,
};
// stock player_add_points, reduced to the lines a registered event reaches
ctx.player_add_points = (self, event, mod, hit, isdog, team, weapon) => {
  if (!ctx.is_player_valid(self)) return;
  const mult = ctx.get_points_multiplier(self);
  let pts = event === 'death' ? 50 + (mod === 'MOD_MELEE' ? 70 : 0) : ctx.events[event](event, mod, hit, team, weapon);
  pts = mult * ctx.round_up_score(pts, 10);
  self.score += ctx.round_up_score(pts, 10);
};
vm.createContext(ctx);
for (const f of ['mage_kill_points', 'bounty_kill_value', 'bounty_preview', 'cleave_kill_points', 'cleave_kill_claim', 'cleave_kill_settle', 'cleave_death_score']) {
  const sig = up.match(new RegExp('function ' + f + '\\(([^)]*)\\)'))[1].replace(/\s*=\s*undefined/g, '');
  vm.runInContext(`function ${f}(${sig}) {${gsc(body(up, f))}}`, ctx);
}
ctx.add_to_player_score = (p, pts) => { p.score += ctx.round_up_score(pts, 10); };
// BOUNTY's REAL bank (self = the dead zombie)
vm.runInContext(`function bounty_bank_kill(self, attacker) {${gsc(body(up, 'bounty_bank_kill'))}}`, ctx);
ctx.events[EVENT] = ctx.cleave_death_score;
ctx.level.tod_bounty_preview_fn = ctx.bounty_preview;
// the kill popup's tod_popup_points arm, verbatim
{
  const arm = body(hud, 'zombie_death_callback');
  const a = arm.indexOf('if ( isdefined( self.tod_popup_points ) )');
  assert.ok(a >= 0, 'the popup still has its tod_popup_points arm');
  const open = arm.indexOf('{', a);
  let e = open + 1, d = 1;
  while (d) { if (arm[e] === '{') d++; if (arm[e] === '}') d--; e++; }
  const src = gsc(arm.slice(a, e)).replace(/attacker LuiNotifyEvent\([^;]*;/, 'attacker.popup = player_points;');
  assert.ok(/tod_bounty_preview_fn\( attacker, weapon, mod, sHitLoc, self \)/.test(src), 'the popup hands the victim to the BOUNTY preview');
  vm.runInContext(`function popupArm(self, attacker, weapon, mod, sHitLoc) { ${src} }`, ctx);
}
// stock's death flow, as far as money goes: popup on the killing blow, then
// zombie_death_points (latch -> bare 50 for a hit-type-less script kill), then
// on_class_gun_kill's BOUNTY bank (the same arithmetic as the preview).
// on_class_gun_kill's BOUNTY lane, in its shipping order (pinned below): a cleave
// kill banks ahead of the damageweapon gate, every other kill after it.
function bountyBank(z, p) {
  if (z.tod_cleave_kill_pts !== undefined) ctx.bounty_bank_kill(z, p);
  if (z.damageweapon === undefined) return;
  if (z.tod_cleave_kill_pts === undefined) ctx.bounty_bank_kill(z, p);
}
function doDamage(z, dmg, p) {
  z.health -= Math.trunc(dmg * (z.armor || 1));
  if (z.health > 0) return;
  z.damagemod = 'MOD_UNKNOWN'; z.damagelocation = 'none';
  const w = z.noWeapon ? undefined : { name: 'none' };   // what the engine hands a weaponless DoDamage
  z.damageweapon = w;
  if (z.archetype === 'zombie' && ctx.is_player_valid(p)) {
    if (z.tod_popup_points !== undefined) ctx.popupArm(z, p, w, 'MOD_UNKNOWN', 'none');
    else p.popup = 50 * ctx.get_points_multiplier(p) + ctx.bounty_preview(p, w, 'MOD_UNKNOWN', 'none', z);
  }
  if (!z.deathpoints_already_given) { z.deathpoints_already_given = true; ctx.player_add_points(p, 'death', 'MOD_UNKNOWN', 'none', undefined, 'axis', {}); }
  bountyBank(z, p);
}
function swing(z, p, dmg, claim = true) {
  p.score = 0; delete p.popup; p.tod_bounty_bank = p.bank0 || 0;
  const pts = claim ? ctx.cleave_kill_claim(z, p) : 0;
  doDamage(z, dmg, p);
  if (pts > 0) ctx.cleave_kill_settle(z, p, pts, {});
  return p;
}
const zombie = (o = {}) => Object.assign({ team: 'axis', archetype: 'zombie', health: 100 }, o);
const player = (o = {}) => Object.assign({ player: true, team: 'allies', score: 0 }, o);

// on_class_gun_kill must bank a cleave kill's BOUNTY before its weapon gate, and skip it below
{
  const k = body(up, 'on_class_gun_kill');
  const early = k.search(/if \( isdefined\( self\.tod_cleave_kill_pts \) \)\s*self bounty_bank_kill\( attacker \);/);
  const gate = k.indexOf('if ( !isdefined( self.damageweapon ) )');
  const late = k.indexOf('if ( !isdefined( self.tod_cleave_kill_pts ) )');
  assert.ok(early >= 0 && gate > early && late > gate, 'on_class_gun_kill: cleave BOUNTY before the weapon gate, every other kill after it');
  assert.ok((k.match(/bounty_bank_kill\(/g) || []).length === 2, 'on_class_gun_kill banks BOUNTY in exactly two places');
}
let cases = 0;
for (const noWeapon of [false, true])
for (const scalar of [1, 2])
  for (const bounty of [0, 1, 3, 5])
    for (const dark of [false, true])
      for (const bank0 of [0, 4, 9.5]) {
        if (dark && bounty === 0) continue;
        ctx.level.zombie_vars.allies.zombie_point_scalar = scalar;
        const p = swing(zombie({ noWeapon }), player({ bounty, darkBounty: dark, bank0 }), 500);
        const rate = bounty > 0 ? ctx.TOD_UPG_BOUNTY_PER_LVL * bounty + (dark ? ctx.TOD_DARK_BOUNTY_ADD : 0) : 0;
        const bankAfter = bank0 + 90 * rate;
        const want = 90 * scalar + (bounty > 0 && bankAfter >= 10 ? Math.trunc(bankAfter / 10) * 10 : 0);
        const tag = `scalar ${scalar} bounty ${bounty} dark ${dark} bank ${bank0} weapon ${noWeapon ? 'none recorded' : 'placeholder'}`;
        assert.equal(p.score, want, 'paid: ' + tag);
        assert.equal(p.popup, p.score, 'popup == paid: ' + tag);
        cases++;
      }
ctx.level.zombie_vars.allies.zombie_point_scalar = 1;
assert.equal(ctx.cleave_kill_points(), 90, '75% of the 120 melee kill');
assert.ok(ctx.logs.some(l => l.includes('[TOD_CLEAVE]') && l.includes('KILL_PAY') && l.includes('nominal=90')), 'dev log names the payout');

// a cleave hit that does not kill gives the kill back to stock untouched
{
  const z = zombie({ health: 1000 });
  const p = swing(z, player(), 100);
  assert.equal(p.score, 0); assert.equal(p.popup, undefined);
  assert.ok(!z.deathpoints_already_given && z.tod_popup_points === undefined && z.tod_cleave_kill_pts === undefined, 'survivor: latch + stamps cleared');
  // ...and its real kill (a normal melee swing) pays stock's 120 later
  p.score = 0; z.health = 0; z.damagemod = 'MOD_MELEE';
  z.deathpoints_already_given = true; ctx.player_add_points(p, 'death', 'MOD_MELEE', 'torso', undefined, 'axis', {});
  assert.equal(p.score, 120);
  // sprinter armor: damage that looks lethal is not, and nothing is paid
  const s = zombie({ health: 300, armor: 0.25 });
  assert.equal(swing(s, player(), 400).score, 0);
  assert.ok(!s.deathpoints_already_given);
  cases += 3;
}
// left alone: elites, a kill another script already paid, a downed killer
for (const arch of ['mechz', 'zod_companion', 'zombie_dog', 'apothicon_fury']) {
  const z = zombie({ archetype: arch });
  assert.equal(ctx.cleave_kill_claim(z, player()), 0, arch + ' is not claimed');
  assert.ok(z.tod_popup_points === undefined); cases++;
}
assert.equal(ctx.cleave_kill_claim(zombie({ tod_popup_points: 30, deathpoints_already_given: true }), player()), 0, 'TRAILBLAZER already owns that kill');
assert.equal(ctx.cleave_kill_claim(zombie(), player({ downed: true })), 0, 'a downed killer is not paid');
assert.equal(ctx.cleave_kill_claim(zombie(), player({ inhibit: true })), 0, 'a scoring-inhibited killer is not paid');
cases += 3;

// cleave_splash: claim BEFORE the DoDamage, settle AFTER it
{
  const sp = body(up, 'cleave_splash');
  const c = sp.indexOf('pts = cleave_kill_claim( z, attacker );'), d = sp.indexOf('z DoDamage('), s = sp.indexOf('cleave_kill_settle( z, attacker, pts, weapon );');
  assert.ok(c >= 0 && d > c && s > d, 'cleave_splash: claim -> DoDamage -> settle');
  cases++;
}

// negative control: the same lethal swing without the claim pays the bare 50
{
  const p = swing(zombie(), player(), 500, false);
  let caught = false;
  try { assert.equal(p.score, 90); } catch (e) { caught = true; }
  assert.ok(caught && p.score === 50 && p.popup === 50, 'negative control: no claim = stock 50');
}
console.log(`Cleave kill pay passed (${cases} cases): a cleave kill pays 90 (75% of the 120 melee kill) x Double Points plus BOUNTY on the 90 (with or without a recorded weapon), the popup equals the payout at every level, survivors/elites/claimed/downed are left to stock; negative control caught.`);
