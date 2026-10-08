// The client registers BOTH CSV names in level.weapon_costs; this is a
// different budget from the weapon-asset registration ledger. The observed
// 304-key table overflowed SetWeaponCosts at match startup (2026-09-08).
// 240 is our conservative table budget, leaving room for stock/script adds;
// it is not a claim about the engine's undocumented exact capacity.
const fs = require('fs');
const path = require('path');
const MAX_TABLE_WEAPON_COSTS = 240;
function verifyWeaponCosts(text) {
    const rows = text.trim().split(/\r?\n/).map(line => line.split(','));
    if (rows[0][0] !== 'weapon_name') throw new Error('Missing weapon-table header');
    const costs = new Set(), bases = new Set();
    for (const row of rows.slice(1)) {
        if (!row[0]) throw new Error('Blank weapon-table row');
        if (bases.has(row[0])) throw new Error('Duplicate weapon-table base: ' + row[0]);
        bases.add(row[0]);
        for (const name of row.slice(0, 2)) if (name) costs.add(name);
    }
    if (costs.size > MAX_TABLE_WEAPON_COSTS)
        throw new Error(`Weapon-cost table has ${costs.size} entries; budget ${MAX_TABLE_WEAPON_COSTS}. This can stop match startup even when the weapon asset ledger passes.`);
    return {rows: rows.length - 1, costs: costs.size};
}
module.exports = {verifyWeaponCosts, MAX_TABLE_WEAPON_COSTS};
if (require.main === module) {
    const result = verifyWeaponCosts(fs.readFileSync(path.join(__dirname, '../gamedata/weapons/zm/zm_levelcommon_weapons.csv'), 'utf8'));
    console.log(`Weapon-cost table passed: ${result.costs}/${MAX_TABLE_WEAPON_COSTS} entries across ${result.rows} rows.`);
}
