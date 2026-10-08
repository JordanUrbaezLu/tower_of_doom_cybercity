// Exercise the actual fire-only cooldown controller; native input/animation
// behavior still needs BO3. No Take/Give or forced weapon swap is involved.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const path = require('path');
const src = fs.readFileSync(path.join(__dirname, '../scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'), 'utf8');
function body(name) {
    const start = src.indexOf('{', src.indexOf('function ' + name + '('));
    let end = start + 1, depth = 1;
    while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
    return src.slice(start + 1, end - 1)
        .replace(/self laststand::player_is_in_laststand\(\)/g, 'isDown()')
        .replace(/self\s+(\w+)\s*\(/g, '$1(');
}
const env = { IS_TRUE: v => v === true, isdefined: v => v !== undefined,
    IsAlive: p => p.alive, isDown: () => env.down,
    GetTime: () => env.time, GetCurrentWeapon: () => env.weapon,
    staff_element: w => w && w.element,
    DisableWeaponFire: () => {env.disabled++; env.nativeBlocked = true;},
    EnableWeaponFire: () => {env.enabled++; env.nativeBlocked = false;},
    // RAPID FLAME (v19.25): the card's level, injected the way the GSC reads it.
    get_level: (p, key) => (key === 'mage_rate' ? env.rateLevel : 0),
    Int: n => Math.trunc(n),
};
vm.createContext(env);
vm.runInContext(`function update() { let element, blocked; ${body('fire_recovery_update')} }`, env);
const cooldown = Number(src.match(/#define\s+TOD_MAGE_FIRE_RECOVERY_MS\s+(\d+)/)[1]);
assert.equal(cooldown, 1573);

// ---- RAPID FLAME: the fire staff's rate card (domain 57, v19.25) -----------
// The cooldown is no longer a constant, so the LADDER is exercised through the
// real function rather than recomputed here. `body()` strips the `self` receiver
// but not a namespace, so the one cross-module call is rewritten by name.
const ratePerLv = Number(src.match(/#define\s+TOD_MAGE_FIRE_RATE_PER_LV\s+([0-9.]+)/)[1]);
const rateMaxLv = Number(src.match(/#define\s+TOD_MAGE_FIRE_RATE_MAX_LV\s+(\d+)/)[1]);
assert.equal(ratePerLv, 0.10, 'user 2026-09-21: 5 levels, 10% each');
assert.equal(rateMaxLv, 5);
vm.runInContext(`function rate() { let lv, ms; ${body('fire_recovery_ms')
    .replace(/tod_upgrades::get_level\(/g, 'get_level(')
    .replace(/TOD_MAGE_FIRE_RECOVERY_MS/g, String(cooldown))
    .replace(/TOD_MAGE_FIRE_RATE_PER_LV/g, String(ratePerLv))
    .replace(/TOD_MAGE_FIRE_RATE_MAX_LV/g, String(rateMaxLv))} }`, env);
env.self = {};
// LINEAR on the cooldown, which is what "10% each level" means for every other
// rate ladder in this map (the skirmisher's FIRE RATE card is -8% fire time/Lv).
for (const [lv, want] of [[0,1573],[1,1415],[2,1258],[3,1101],[4,943],[5,786]]) {
    env.rateLevel = lv;
    assert.equal(env.rate(), want, 'RAPID FLAME Lv' + lv);
}
// Lv5 is DOUBLE the shots per second. That is the card's whole point and it is
// deliberate; if it needs a nerf, move TOD_MAGE_FIRE_RATE_PER_LV, not this test.
assert.ok(Math.abs((cooldown / env.rate()) - 2) < 0.01, 'Lv5 doubles the fire rate');
// Levels the ladder cannot deal (dark pool, dev grant, a future max bump that
// forgets this file) are clamped rather than driving the cooldown to zero.
env.rateLevel = 99; assert.equal(env.rate(), 786, 'over-max clamps to Lv5');
env.rateLevel = -3; assert.equal(env.rate(), 1573, 'negative clamps to Lv0');
env.rateLevel = 0;
function begin() {
    Object.assign(env, {self: {tod_mage_armed:true, alive:true, tod_mage_fire_ready_ms:1573},
        weapon:{element:'fire'}, time:0, down:false, disabled:0, enabled:0, nativeBlocked:false});
    env.update(); assert.equal(env.nativeBlocked, true);
}
begin(); env.time=1572; env.update(); assert.equal(env.nativeBlocked,true);
env.time=1573; env.update(); assert.equal(env.nativeBlocked,false);
env.update(); assert.equal(env.disabled,1); assert.equal(env.enabled,1);
for(const destination of ['lightning','ice',undefined]) {
    begin(); env.time=200; env.weapon={element:destination}; env.update();
    assert.equal(env.nativeBlocked,false,'other weapons can fire');
    env.time=800; env.weapon={element:'fire'}; env.update();
    assert.equal(env.nativeBlocked,true,'swap back does not reset cooldown');
    env.time=1600; env.update(); assert.equal(env.nativeBlocked,false);
}
for(const state of ['dead','down','disarmed']) {
    begin();
    if(state==='dead') env.self.alive=false;
    if(state==='down') env.down=true;
    if(state==='disarmed') env.self.tod_mage_armed=false;
    env.update(); assert.equal(env.nativeBlocked,false,state+' releases our firing flag');
}
begin(); env.self.tod_menu_frozen=true; env.time=1700; env.update();
assert.equal(env.self.tod_menu_frozen,true,'menu ownership untouched');
assert.equal(env.nativeBlocked,false);
begin(); env.self.tod_mage_fire_ready_ms=undefined; env.update();
assert.equal(env.nativeBlocked,false,'undefined deadline releases stale flag');
// v18.99c: ICE IS OFF THIS CONTROLLER. v18.94 put it here to free the weapon
// switch and the staff then fired as fast as the trigger could be clicked —
// fire is `Charge Shot` (the engine fires on release, so the flag is read on
// the next press), ice is `Single Shot` and the flag did not hold it. Ice's
// cadence is its native fireTime again (0.8 s since v18.99d); this controller
// is fire's alone.
assert(!/TOD_MAGE_ICE_RECOVERY_MS/.test(src), 'ice must not ride the script fire cooldown again');
assert(!/tod_mage_ice_ready_ms/.test(src), 'no ice deadline left behind');
begin(); env.self.tod_mage_fire_ready_ms=1573; env.weapon={element:'ice'}; env.update();
assert.equal(env.nativeBlocked,false,'ice is never blocked by this controller, even mid-fire-cooldown');
env.weapon={element:'lightning'}; env.update(); assert.equal(env.nativeBlocked,false,'lightning never blocked');
const controller = src.slice(src.indexOf('function fire_recovery_watch('),src.indexOf('// Time the trigger hold'));
assert(!/\b(DisableWeapons|EnableWeapons|SwitchToWeaponImmediate|TakeWeapon|GiveWeapon|FreezeControls)\(/.test(controller));
assert(!/endon\( "(death|tod_mage_disarm)" \)/.test(controller),'cleanup must survive death/disarm');
assert(controller.includes('GetTime() + self fire_recovery_ms()'),
    'the deadline must come from the RAPID FLAME-aware reader, not the raw constant');
console.log('Fire cooldown passed: 1.573s base cadence scaling to 0.786s at RAPID FLAME Lv5, ice and lightning never gated by it, swap-back deadline, death/disarm cleanup, menu ownership. Ice cadence is native fireTime 0.8. Native playtest required.');
