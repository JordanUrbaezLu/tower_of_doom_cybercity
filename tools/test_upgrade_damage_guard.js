// upgrade_damage_cb's "nothing modified -> return -1" guard, run as the
// SHIPPING TEXT rather than a copy of it.
//
// WHY THIS FILE EXISTS. Returning -1 tells the stock chain "I changed nothing",
// and stock then applies the RAW damage -- so every multiplier applied above
// the guard must also be TESTED by the guard, or it is silently discarded for
// any player who happens to have no other term active. That has now been the
// same bug three times: v13.7's sprinter_armor_frac, v16's
// slasher_sidearm_boss_mult (both fixed in v16.3), and v18.59's mage staff
// multiplier + script-paid PACK II/III.
//
// The mage is the worst case because its ENTIRE power budget is that one
// multiplier and it can never satisfy the other terms: umult is
// skirmisher/heavy, bmult is assault's GIANT SLAYER, gunslinger is slasher,
// splash carries no hit location so the headshot clause is always true, and
// gun_balance_mult has no staff branch. Only the universal DAMAGE domain and an
// armored-sprinter victim could rescue it.
//
// The negative control at the bottom is the point of the file: it strips the
// two new terms back out and requires the mage case to FAIL, so a future edit
// that quietly drops them cannot leave this test green.
const fs = require('fs'), assert = require('assert/strict');
const SRC = 'scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc';
const src = fs.readFileSync(SRC, 'utf8').replace(/\r/g, '');

// ---- the guard's own text, lifted from the file --------------------------
function guardText(text) {
  const ret = text.indexOf('return -1;   // nothing modified');
  assert.ok(ret > 0, 'the -1 fast path is gone from ' + SRC);
  // walk back to the `if (` that owns it
  const open = text.lastIndexOf('\tif (', ret);
  assert.ok(open > 0 && open < ret, 'could not find the guard condition');
  const cond = text.slice(open + '\tif ('.length, text.lastIndexOf(')', ret));
  return cond.replace(/\/\/[^\n]*/g, ' ').replace(/\s+/g, ' ').trim();
}

const cond = guardText(src);

// ---- the capture sites the guard depends on ------------------------------
// A guard term is only meaningful if the variable it reads is the SAME value
// that was multiplied in. Assert both halves at both sites.
assert.match(src, /pap_mult = tod_classes::pap_tier_mult\( attacker, weapon \);/,
  'PACK II/III is no longer captured into pap_mult');
assert.match(src, /damage = damage \* pap_mult;/,
  'pap_mult is captured but no longer applied to damage');
assert.match(src, /mage_mult = \[\[ level\.tod_mage_staff_mult \]\]\( attacker, self, weapon \);/,
  'the mage staff multiplier is no longer captured into mage_mult');
assert.match(src, /mult = mult \* mage_mult;/,
  'mage_mult is captured but no longer applied to mult');
assert.match(src, /\tmage_mult = 1\.0;/,
  'mage_mult must default to 1.0 so the guard is valid with the class gated off');

// ---- evaluate the real condition -----------------------------------------
// Every name below is either a local the callback computes or one of the four
// helper calls it makes; the condition is otherwise valid JS as written.
function evaluate(condText, s) {
  const fn = new Function(
    'dmult', 'balance', 'dmg_lvl', 'hs_lvl', 'headshot', 'umult', 'bmult',
    'mage_mult', 'pap_mult', 'attacker', 'self', 'weapon', 'is_melee',
    'melee_boss_mult', 'sprinter_armor_frac', 'slasher_sidearm_boss_mult', 'gunslinger_bonus',
    'return ( ' + condText + ' );');
  return fn(
    s.dmult, s.balance, s.dmg_lvl, s.hs_lvl, s.headshot, s.umult, s.bmult,
    s.mage_mult, s.pap_mult, {}, {}, {}, s.is_melee,
    () => s.melee_boss, () => s.sprinter_armor, () => s.slasher_sidearm, () => s.gunslinger);
}

// A player carrying nothing at all: no DAMAGE, no Insta-Kill, no class unique,
// ordinary victim, non-melee. This is the state the guard was written for.
const NEUTRAL = {
  dmult: 1, balance: 1.0, dmg_lvl: 0, hs_lvl: 0, headshot: false, umult: 0, bmult: 0,
  mage_mult: 1.0, pap_mult: 1.0, is_melee: false,
  melee_boss: 1.0, sprinter_armor: 1.0, slasher_sidearm: 1.0, gunslinger: 0.0,
};
const S = o => Object.assign({}, NEUTRAL, o);

// silent === the callback returns -1 and stock applies the raw damage.
const silent = o => evaluate(cond, S(o));

let checks = 0;
function want(label, opts, expected) {
  assert.equal(silent(opts), expected, label);
  checks++;
}

// The case the guard is FOR: nothing was modified, so say nothing.
want('a bare player with no terms stays silent', {}, true);

// THE MAGE. Every one of these is a real shipping combination.
//   tier ladder alone (T1 0.736 / T2 1.60 / T3 3.16 as of 2026-09-09)
//   x matchup (lightning-vs-Panzer 5.60 is the largest)
//   x FIRE BLAST / ICE SHATTER / ARCHMAGE / the fire charge
// and the off-family multipliers, which are BELOW 1.0 for lightning and fire --
// those must break the guard too, or an off-family hit would land UNPENALISED.
for (const m of [0.736, 1.60, 3.16, 0.45, 0.83, 2.36, 3.16 * 5.60, 3.16 * 3.61 * 2.20]) {
  want('a mage staff multiplier of ' + m + ' must reach the victim', { mage_mult: m }, false);
}
// A mage holding a NON-staff (the Death Machine gift gun) gets 1.0 back from
// staff_mult, and must behave exactly as before this fix.
want('a mage holding a non-staff is unchanged', { mage_mult: 1.0 }, true);

// PACK II / PACK III, on any class, with no DAMAGE level yet.
for (const p of [1.5, 2.25]) {
  want('a PACK re-pack of x' + p + ' must reach the victim', { pap_mult: p }, false);
}
want('tier 0/1 PaP returns 1.0 and stays silent', { pap_mult: 1.0 }, true);

// Both at once -- a packed mage is the common case in the spire.
want('a packed mage is not silent', { mage_mult: 3.16, pap_mult: 2.25 }, false);

// The terms that were ALREADY tested must still break it (v16.3 regression).
want('DAMAGE level breaks silence', { dmg_lvl: 1 }, false);
want('Insta-Kill breaks silence', { dmult: 2 }, false);
want('sprinter armor breaks silence', { sprinter_armor: 0.34 }, false);
want('melee-vs-boss halving breaks silence', { melee_boss: 0.5, is_melee: true }, false);
want('the slasher sidearm boss lane breaks silence', { slasher_sidearm: 2.25 }, false);
want('GUNSLINGER breaks silence', { gunslinger: 0.4 }, false);
want('a headshot with a HEADSHOT level breaks silence', { hs_lvl: 3, headshot: true }, false);
want('a HEADSHOT level without a headshot stays silent', { hs_lvl: 3, headshot: false }, true);
want('gun balance breaks silence', { balance: 7.2 }, false);

// ---- NEGATIVE CONTROL ----------------------------------------------------
// Strip the two new terms and require the mage and PaP cases to regress. If
// this block ever passes, the test above is measuring nothing.
const stripped = cond.replace(/&& mage_mult == 1\.0 /, '').replace(/&& pap_mult == 1\.0 /, '');
assert.notEqual(stripped, cond, 'negative control could not find the terms to strip');
assert.equal(evaluate(stripped, S({ mage_mult: 3.16 })), true,
  'negative control: without the term, a tier-3 mage SHOULD be wrongly silent');
assert.equal(evaluate(stripped, S({ pap_mult: 2.25 })), true,
  'negative control: without the term, a PACK III holder SHOULD be wrongly silent');

console.log('upgrade_damage_cb guard passed: ' + checks +
  ' scenarios over the shipping condition, both capture sites wired, negative control fires.');
