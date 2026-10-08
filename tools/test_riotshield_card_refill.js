// test_riotshield_card_refill.js — v18.99c: a RIOT SHIELD card must hand the
// shield back even when the shield is BROKEN and recharging.
//
// The reported bug (user, 2026-09-13): "I had no riot shield, and I got a riot
// shield upgrade card, and it didn't refill my riot shield when it should. That
// is the requirement. I thought we fixed this before. Sometimes it seems to
// work, but this time it didn't."
//
// THE EARLIER FIX WAS A DIFFERENT CASE. v17.10's swap_shield refill covers a
// card taken while you are HOLDING a shield. A card taken while the shield was
// broken fell into reconcile()'s recharging branch, whose only effect was
// re-deriving the deadline at the new (faster) rate — so it LOOKED like it
// worked whenever that new deadline had already passed, and did nothing at all
// when it had not. That is the whole intermittency.
//
// This runs the ACTUAL reconcile() body with a mocked player.
//   node tools/test_riotshield_card_refill.js
const fs = require('fs'), vm = require('vm'), assert = require('assert/strict'), path = require('path');
const src = fs.readFileSync(path.join(__dirname, '../scripts/zm/zm_tower_of_doom/_tod_riotshield.gsc'), 'utf8');

function body(name) {
  const at = src.indexOf('function ' + name + '(');
  assert.ok(at >= 0, name);
  const start = src.indexOf('{', at);
  let end = start + 1, depth = 1;
  while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
  return src.slice(start + 1, end - 1)
    .replace(/\/\/.*$/gm, '')
    // method-call form -> plain calls on the mock
    .replace(/self (install_scaler|held_shield|shield_is_dead|clear_shield|give_shield|swap_shield|reconcile|notify)\(/g, '$1(')
    .replace(/tod_upgrades::get_level\(\s*self\s*,\s*TOD_SHIELD_DOMAIN\s*\)/g, 'getLevel()')
    .replace(/shield_hp\(\s*lvl\s*,\s*self\s*\)/g, 'shieldHp(lvl)')
    .replace(/recharge_ms\(\s*lvl\s*,\s*self\s*\)/g, 'rechargeMs(lvl)')
    .replace(/self\./g, 'S.')
    // whatever is left is a bare `self` argument (isdefined( self ), IsAlive( self ))
    .replace(/\bself\b/g, 'S');
}

const env = {
  IS_TRUE: v => v !== undefined && v !== 0 && v !== false && v !== '',
  isdefined: v => v !== undefined,
  IsAlive: () => true,
  level: { weaponNone: 'none' },
};
env.log = [];
env.S = {};
env.getLevel = () => env.lvl;
env.shieldHp = lv => ({ 0: 0, 1: 200, 2: 300, 3: 370, 4: 450, 5: 500 })[lv];
env.rechargeMs = lv => ({ 1: 240, 2: 210, 3: 180, 4: 150, 5: 120 })[lv] * 1000;
env.weapon_for_level = lv => (lv >= 5 ? 'log_riotshield_zm' : 'zod_riotshield');
env.GetTime = () => env.time;
env.install_scaler = () => {};
env.held_shield = () => env.held;
env.shield_is_dead = () => env.dead === true;
env.clear_shield = () => { env.held = undefined; env.log.push('clear'); };
env.give_shield = w => { env.held = w; env.log.push('give:' + w); };
env.swap_shield = (a, b) => { env.held = b; env.log.push('swap:' + b); };
env.notify = s => env.log.push('notify:' + s);
vm.createContext(env);
vm.runInContext(`function reconcile() {${body('reconcile')}}`, env);

function start({ lvl, held, recharging, brokeAt, until, hpSeen, time = 100000 }) {
  env.lvl = lvl; env.held = held; env.dead = false; env.time = time; env.log = [];
  env.S = {};
  if (hpSeen !== undefined) env.S.tod_shield_hp_seen = hpSeen;
  if (recharging) { env.S.tod_shield_broke_at = brokeAt; env.S.tod_shield_recharge_until = until; }
}

// ---- THE BUG: a card lands while the shield is broken and recharging -------
// Lv2 shield (300 HP) broke 10 s ago; its 210 s recharge has 200 s to run.
// The card takes it to Lv3 (370 HP).
start({ lvl: 3, held: undefined, recharging: true, brokeAt: 90000, until: 300000, hpSeen: 300 });
env.reconcile();
assert.equal(env.S.tod_shield_recharge_until, undefined, 'the card ENDS the recharge');
assert.equal(env.S.tod_shield_broke_at, undefined, 'the break stamp is cleared with it');
assert.ok(env.log.includes('notify:tod_shield_recharge_loop'), 'the counter is stopped before the give (one owner)');
assert.ok(env.log.some(l => l.startsWith('give:')), 'THE SHIELD IS HANDED BACK — the reported requirement');
assert.equal(env.held, 'zod_riotshield');

// the same at the very start of a long recharge — the case that used to do nothing
start({ lvl: 5, held: undefined, recharging: true, brokeAt: 99000, until: 339000, hpSeen: 450 });
env.reconcile();
assert.equal(env.held, 'log_riotshield_zm', 'a Lv5 card hands back the Lv5 model at once');
assert.equal(env.S.tod_shield_recharge_until, undefined);

// ---- THE RECHARGE STILL MEANS SOMETHING ------------------------------------
// A routine reconcile (maintain loop / respawn) does NOT end it: same HP as
// last time, so `improved` is false and the old shortening behaviour stands.
start({ lvl: 2, held: undefined, recharging: true, brokeAt: 90000, until: 300000, hpSeen: 300 });
env.reconcile();
assert.equal(env.S.tod_shield_recharge_until, 90000 + 210000, 'no card = deadline re-derived, not lifted');
assert.equal(env.held, undefined, 'no card = no shield back');
assert.ok(!env.log.some(l => l.startsWith('give:')), 'the recharge is still a real wait');

// and it can only ever SHORTEN a wait, never lengthen one
start({ lvl: 1, held: undefined, recharging: true, brokeAt: 90000, until: 200000, hpSeen: 200 });
env.reconcile();
assert.equal(env.S.tod_shield_recharge_until, 200000, 'a slower rate never pushes the deadline out');

// ---- THE CASES THAT ALREADY WORKED MUST KEEP WORKING -----------------------
// v17.10: a card while HOLDING a shield refills it through swap_shield.
start({ lvl: 3, held: 'zod_riotshield', recharging: false, hpSeen: 300 });
env.reconcile();
assert.ok(env.log.includes('swap:zod_riotshield'), 'holding + card = the refill swap');

// the Lv5 model promotion
start({ lvl: 5, held: 'zod_riotshield', recharging: false, hpSeen: 450 });
env.reconcile();
assert.ok(env.log.includes('swap:log_riotshield_zm'), 'Lv5 swaps the model in');

// the FIRST card, never owned before: straight give, no recharge involved
start({ lvl: 1, held: undefined, recharging: false });
env.reconcile();
assert.equal(env.held, 'zod_riotshield', 'the first card hands one out');

// never owned the domain: the slot is left exactly as found
start({ lvl: 0, held: undefined, recharging: false });
env.reconcile();
assert.equal(env.held, undefined);
assert.equal(env.log.length, 0, 'no domain = no writes at all');

// holding the right shield at the same strength: nothing happens
start({ lvl: 3, held: 'zod_riotshield', recharging: false, hpSeen: 370 });
env.reconcile();
assert.ok(!env.log.some(l => l.startsWith('swap:') || l.startsWith('give:')), 'no change = no re-give');

// a DEAD shield in the slot is reaped and replaced even without a card
start({ lvl: 2, held: 'zod_riotshield', recharging: false, hpSeen: 300 });
env.dead = true;
env.reconcile();
assert.ok(env.log.includes('clear'), 'the dead-shield sweep still runs');

console.log('riot shield card refill: a card ENDS a recharge and hands the shield back; routine reconciles still wait; holding/promotion/first-card/no-domain paths unchanged. PASS');
