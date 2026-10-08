// Elite / Panzer mana bonus (2026-09-09): runs the SHIPPING elite_mana /
// elite_mana_value / mana_add bodies out of _tod_mage_elements.gsc and checks
// the round-scaled curve, the killer-only + armed + unlocked + demigod gates,
// the 100 cap, and that both _tod_bosses payout lanes call the hook.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const path = require('path');
const src = fs.readFileSync(path.join(__dirname, '../scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'), 'utf8');
const bosses = fs.readFileSync(path.join(__dirname, '../scripts/zm/zm_tower_of_doom/_tod_bosses.gsc'), 'utf8');

function body(name) {
    const start = src.indexOf('{', src.indexOf(`function ${name}(`));
    let end = start + 1, depth = 1;
    while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
    return src.slice(start + 1, end - 1)
        .replace(/attacker mana_add\(/g, 'mana_add(attacker, ')
        .replace(/self\.tod_mage_/g, 'self.tod_mage_')
        .replace(/self arch_level\(\)/g, 'arch_level(self)');
}
const env = {level: {}};
Object.assign(env, {
    isdefined: v => v !== undefined, IS_TRUE: v => v === true, IsPlayer: p => !!(p && p.player),
});
for (const name of ['TOD_MAGE_MANA_MAX', 'TOD_MAGE_MANA_ELITE', 'TOD_MAGE_MANA_PANZER', 'TOD_MAGE_MANA_ELITE_FULL_ROUND', 'TOD_MAGE_MANA_ELITE_FLOOR'])
    env[name] = Number(src.match(new RegExp('#define\\s+' + name + '\\s+([0-9.]+)'))[1]);
vm.createContext(env);
vm.runInContext(`
function arch_level(self) { return self.archLevel; }
function mana_add(self, n) { ${body('mana_add')} }
function elite_mana_value(kind, r) { ${body('elite_mana_value')} }
function elite_mana(attacker, kind) { ${body('elite_mana')} }`, env);
const v = (k, r) => env.elite_mana_value(k, r);
const near = (a, b, msg) => assert.ok(Math.abs(a - b) < 1e-9, `${msg}: ${a} != ${b}`);

// --- the curve: full through round 10, 10/r after, floor at a quarter ---
for (let r = 1; r <= 10; r++) { near(v('ROGUE PROTECTOR', r), 5, `elite r${r}`); near(v('PANZER', r), 15, `panzer r${r}`); }
near(v('REAVER', 20), 2.5, 'elite r20'); near(v('PANZER', 20), 7.5, 'panzer r20');
near(v('HELLHOUND', 30), 5 / 3, 'elite r30'); near(v('PANZER', 30), 5, 'panzer r30');
near(v('SPRINTER', 40), 1.25, 'elite r40'); near(v('PANZER', 40), 3.75, 'panzer r40');
near(v('SPRINTER', 100), 1.25, 'elite floor r100'); near(v('PANZER', 250), 3.75, 'panzer floor r250');
near(v(undefined, 5), 5, 'unknown kind = elite'); near(v('PANZER', undefined), 15, 'no round = full');
for (let r = 1; r <= 120; r++) assert.ok(v('PANZER', r) <= v('PANZER', r - 1 || 1) + 1e-9, `monotone r${r}`);
// worst waves stay bounded: a capped 8-Protector wave, a 4-Warden trial
assert.ok(8 * v('ROGUE PROTECTOR', 24) <= 20, 'r24 wave <= 20');
assert.ok(8 * v('ROGUE PROTECTOR', 60) <= 10.01, 'r60 wave ~10');
assert.ok(4 * v('PANZER', 70) <= 15.01, 'four wardens r70 ~15');

// --- the hook: killer only, armed, unlocked, not during demigod, capped ---
function mage(mana = 0, extra = {}) { return {player: true, tod_mage_armed: true, tod_mage_mana: mana, archLevel: 1, ...extra}; }
let p;
env.level = {round_number: 5};
p = mage(10); env.elite_mana(p, 'PANZER'); near(p.tod_mage_mana, 25, 'panzer +15');
p = mage(10); env.elite_mana(p, 'REAVER'); near(p.tod_mage_mana, 15, 'elite +5');
env.level = {round_number: 40};
p = mage(10); env.elite_mana(p, 'PANZER'); near(p.tod_mage_mana, 13.75, 'panzer r40 +3.75');
env.level = {};
p = mage(10); env.elite_mana(p, 'HELLHOUND'); near(p.tod_mage_mana, 15, 'no round number = full');
p = mage(98); env.elite_mana(p, 'PANZER'); near(p.tod_mage_mana, 100, 'capped at 100');
p = mage(10, {archLevel: 0}); env.elite_mana(p, 'PANZER'); near(p.tod_mage_mana, 0, 'locked bar stays zero');
p = mage(10, {tod_mage_armed: false}); env.elite_mana(p, 'PANZER'); near(p.tod_mage_mana, 10, 'non-mage untouched');
p = mage(10, {tod_mage_demigod: true}); env.elite_mana(p, 'PANZER'); near(p.tod_mage_mana, 10, 'no gain during ARCHMAGE');
p = {tod_mage_mana: 10, tod_mage_armed: true, archLevel: 1}; env.elite_mana(p, 'PANZER'); near(p.tod_mage_mana, 10, 'non-player attacker');
env.elite_mana(undefined, 'PANZER');

// --- both _tod_bosses payout lanes reach the hook, with the label ---
assert.ok(/level\.tod_mage_elite_mana \]\]\( attacker, name \)/.test(bosses), 'grant_elite_reward passes the label');
assert.ok(/level\.tod_mage_elite_mana \]\]\( killer, "PANZER" \)/.test(bosses), 'boss-round Panzer lane pays');
assert.ok(/level\.tod_mage_elite_mana\s*=\s*&elite_mana;/.test(src), 'pointer installed in init');
console.log('test_mage_elite_mana OK');
