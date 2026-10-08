// Max Ammo fills the Archmage mana bar (2026-09-09): runs the SHIPPING
// _tod_mage_elements::max_ammo body and checks the gates and both call sites.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const path = require('path');
const src = fs.readFileSync(path.join(__dirname, '../scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'), 'utf8');
const pu = fs.readFileSync(path.join(__dirname, '../scripts/zm/zm_tower_of_doom/_tod_powerups.gsc'), 'utf8');
function body(name) {
    const start = src.indexOf('{', src.indexOf(`function ${name}(`));
    let end = start + 1, depth = 1;
    while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
    return src.slice(start + 1, end - 1)
        .replace(/self arch_level\(\)/g, 'self.archLevel')
        .replace(/self mana_push\(/g, 'pushes.push(')
        // v18.99: a Max Ammo also clears the lightning staff's owed reload and
        // tops the held staff's clip up on the spot (never mid-reload).
        .replace(/self bolt_reload_reset\(\)/g, 'boltResets.push(self)')
        .replace(/self GetCurrentWeapon\(\)/g, 'self.held')
        .replace(/self IsReloading\(\)/g, '(self.reloading === true)')
        .replace(/self staff_clip_target\(([^)]*)\)/g, 'clipTarget($1)')
        .replace(/self SetWeaponAmmoClip\(/g, 'clipWrite(self, ');
}
// IS_TRUE models the macro (shared.gsh:251 `( isdefined( __a ) && __a )`), so
// an integer 1 counts — see test_mage_bolt_reload.js, where a `=== true` mock
// failed a correct implementation.
const env = { pushes: [], boltResets: [], clipWrites: [], isdefined: v => v !== undefined,
              IS_TRUE: v => v !== undefined && v !== 0 && v !== false && v !== '',
              IsPlayer: p => !!(p && p.player),
              staff_element: w => (w && w.name && w.name.indexOf('tod_staff_') === 0) ? 'lightning' : undefined,
              clipTarget: w => w.clipSize - 1 };
env.clipWrite = (p, w, n) => env.clipWrites.push({ w: w.name, n });
const STAFF = { name: 'tod_staff_lightning_q0', clipSize: 6 };
env.TOD_MAGE_MANA_MAX = Number(src.match(/#define\s+TOD_MAGE_MANA_MAX\s+(\d+)/)[1]);
vm.createContext(env);
vm.runInContext(`function max_ammo(self) { ${body('max_ammo')} }`, env);
const mage = (extra = {}) => ({ player: true, tod_mage_armed: true, tod_mage_mana: 12, archLevel: 1, held: STAFF, ...extra });
let p;
p = mage(); env.max_ammo(p); assert.equal(p.tod_mage_mana, 100); assert.deepEqual(env.pushes, [100]);
env.pushes = [];
p = mage({ archLevel: 0 }); env.max_ammo(p); assert.equal(p.tod_mage_mana, 12, 'locked bar untouched'); assert.equal(env.pushes.length, 0);
p = mage({ tod_mage_armed: false }); env.max_ammo(p); assert.equal(p.tod_mage_mana, 12, 'non-mage untouched');
p = mage({ tod_mage_demigod: true }); env.max_ammo(p); assert.equal(p.tod_mage_mana, 100, 'fills mid-form');
p = { tod_mage_armed: true, tod_mage_mana: 12, archLevel: 1 }; env.max_ammo(p); assert.equal(p.tod_mage_mana, 12, 'non-player');
env.max_ammo(undefined);
p = mage({ archLevel: 6, tod_mage_mana: 100 }); env.max_ammo(p); assert.equal(p.tod_mage_mana, 100, 'full stays full, not over');
// ---- v18.99: the Max Ammo clears the lightning staff's owed reload --------
// (user: "on max ammo ... the lightning staff clip needs to reset"). Stock's
// full_ammo cannot see this one: the debt is a script counter plus a pinned
// clip, so the staff was the only weapon a Max Ammo did nothing for.
env.pushes = []; env.boltResets = []; env.clipWrites = [];
p = mage(); env.max_ammo(p);
assert.equal(env.boltResets.length, 1, 'the counter is reset');
assert.deepEqual(env.clipWrites, [{ w: STAFF.name, n: 5 }], 'the held staff is refilled on the spot');
// and WITHOUT the ARCHMAGE card, which only gates the mana fill
env.boltResets = []; env.clipWrites = []; env.pushes = [];
p = mage({ archLevel: 0 }); env.max_ammo(p);
assert.equal(env.boltResets.length, 1, 'a mage with no ARCHMAGE card still gets their ammo back');
assert.equal(env.pushes.length, 0, 'but no mana is filled');
// mid-reload the clip is left alone (writing it can finish/cancel the reload)
env.boltResets = []; env.clipWrites = [];
p = mage({ reloading: true }); env.max_ammo(p);
assert.equal(env.boltResets.length, 1); assert.equal(env.clipWrites.length, 0, 'never written mid-reload');
// a non-mage is untouched on both lanes
env.boltResets = []; env.clipWrites = [];
p = mage({ tod_mage_armed: false }); env.max_ammo(p);
assert.equal(env.boltResets.length, 0); assert.equal(env.clipWrites.length, 0);
// holding a gun (not a staff): the counter still resets, no clip write
env.boltResets = []; env.clipWrites = [];
p = mage({ held: { name: 'ak47_zm', clipSize: 30 } }); env.max_ammo(p);
assert.equal(env.boltResets.length, 1); assert.equal(env.clipWrites.length, 0, 'only a staff is topped up');

assert.ok(/level\.tod_mage_max_ammo\s*=\s*&max_ammo;/.test(src), 'pointer installed');
const i = pu.indexOf('self waittill( "zmb_max_ammo" )');
assert.ok(i > 0 && pu.indexOf('[[ level.tod_mage_max_ammo ]]()', i) > i, 'max_ammo_clip_watch calls the pointer after the notify');
console.log('test_mage_max_ammo OK (mana fill + the v18.99 lightning reload reset)');
