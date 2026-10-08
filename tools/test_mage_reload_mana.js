// Run the actual GSC reward coroutine with simulated engine events/states.
// Native notification timing still needs an in-game check after compilation.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const path = require('path');
const src = fs.readFileSync(path.join(__dirname, '../scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'), 'utf8');
function body(name) {
    const start = src.indexOf('{', src.indexOf(`function ${name}(`));
    let end = start + 1, depth = 1;
    while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
    return src.slice(start + 1, end - 1)
        .replace(/self endon\(/g, 'endOn(')
        .replace(/self waittill\(\s*"([^"]+)"\s*\);/g, 'yield "$1";')
        .replace(/wait 0\.(05|25);/g, 'yield "tick";')
        .replace(/self notify\(/g, 'notify(')
        .replace(/self laststand::player_is_in_laststand\(\)/g, 'isDown()')
        .replace(/self\s+(\w+)\s*\(/g, '$1(');
}
const env = {self: {}, level: {}, reloading: true, sprinting: false, melee: false, down: false, stopEvents: new Set(), pushes: []};
Object.assign(env, {
    isdefined: v => v !== undefined, IS_TRUE: v => v === true, int: Math.trunc,
    endOn: e => env.stopEvents.add(e), GetCurrentWeapon: () => env.weapon,
    IsReloading: () => env.reloading, IsSprinting: () => env.sprinting,
    IsMeleeing: () => env.melee, isDown: () => env.down,
    mana_push: n => env.pushes.push(n),
    arch_level: () => env.archLevel,
});
for (const name of ['TOD_MAGE_MANA_MAX', 'TOD_MAGE_RELOAD_MANA', 'TOD_MAGE_RELOAD_MANA_WINDOW_MS'])
    env[name] = Number(src.match(new RegExp('#define\\s+' + name + '\\s+(\\d+)'))[1]);
// v18.76: the reward is paced by a window; the clock is ours to advance.
env.now = 100000;
env.GetTime = () => env.now;
vm.createContext(env);
vm.runInContext(`function mana_now() { ${body('mana_now')} }
function mana_add(n) { ${body('mana_add')} }
function* attempt(weapon) { ${body('reload_mana_complete')} }`, env);
let step, co;
function begin(mana = 20) {
    env.self = {tod_mage_mana: mana, tod_mage_armed: true}; env.level = {};
    env.archLevel = 1;
    env.reloading = true; env.sprinting = env.melee = env.down = false;
    env.weapon = {name: 'tod_staff_ice_q1'}; env.stopEvents = new Set(); env.pushes = [];
    co = env.attempt(env.weapon); step = co.next(); assert.equal(step.value, 'reload');
}
function send(event) {
    if (env.stopEvents.has(event)) { co.return(); step = {done: true}; }
    else if (!step.done && step.value === event) step = co.next();
}
begin(); send('tick'); assert.equal(env.self.tod_mage_mana, 20, 'starting alone cannot pay');
send('reload'); assert.equal(step.value, 'tick');
assert.equal(env.self.tod_mage_mana, 20, 'ammo notification must not pay before the animation tail');
env.reloading = false; send('tick'); assert.equal(env.self.tod_mage_mana, 25);
send('reload'); send('tick'); assert.equal(env.self.tod_mage_mana, 25, 'one reward per attempt');
// v18.76 — THE WINDOW: a second completed reload inside it plays but pays
// nothing; one past it pays again. Same player object, clock advanced by hand.
{
    const paidAt = env.self.tod_mage_reload_paid_ms;
    assert.equal(paidAt, env.now, 'the first reward stamps the clock');
    const again = () => {
        env.reloading = true; env.stopEvents = new Set(); env.pushes = [];
        co = env.attempt(env.weapon); step = co.next(); assert.equal(step.value, 'reload');
        send('reload'); env.reloading = false; send('tick');
    };
    env.now = paidAt + env.TOD_MAGE_RELOAD_MANA_WINDOW_MS - 1; again();
    assert.equal(env.self.tod_mage_mana, 25, 'inside the window: no second payment');
    assert.equal(env.self.tod_mage_reload_paid_ms, paidAt, 'an unpaid reload does not move the window');
    env.now = paidAt + env.TOD_MAGE_RELOAD_MANA_WINDOW_MS; again();
    assert.equal(env.self.tod_mage_mana, 30, 'at the window edge: paid again');
    assert.equal(env.self.tod_mage_reload_paid_ms, env.now, 'and the window restarts');
    env.now = 100000;
}
for (const event of ['weapon_fired', 'weapon_change', 'sprint_begin', 'melee_swipe', 'death', 'disconnect', 'tod_mage_disarm', 'tod_mage_reload_watch', 'tod_mage_reload_attempt']) {
    for (const afterAmmo of [false, true]) {
        begin(); if (afterAmmo) send('reload'); send(event);
        env.reloading = false; send('reload'); send('tick');
        assert.equal(env.self.tod_mage_mana, 20, `cancel ${event} afterAmmo=${afterAmmo}`);
    }
}
for (const mode of ['sprint', 'melee', 'down', 'switch', 'class', 'pause', 'menu', 'archmage']) {
    begin(); send('reload');
    if (mode === 'sprint') env.sprinting = true;
    if (mode === 'melee') env.melee = true;
    if (mode === 'down') env.down = true;
    if (mode === 'switch') env.weapon = {name: 'tod_staff_fire_q0'};
    if (mode === 'class') env.self.tod_mage_armed = false;
    if (mode === 'pause') env.level.tod_upgrade_pause = true;
    if (mode === 'menu') env.self.tod_menu_frozen = true;
    if (mode === 'archmage') env.self.tod_mage_demigod = true;
    env.reloading = false; send('tick'); assert.equal(env.self.tod_mage_mana, 20, mode);
}
begin(98); send('reload'); env.reloading = false; send('tick'); assert.equal(env.self.tod_mage_mana, 100);
assert.equal(env.pushes.at(-1), 100, 'HUD receives the capped reward');
console.log('Reload mana passed: full completion only, single reward, 18 cancellation cases, state guards, Archmage exclusion and cap.');
begin(0); env.archLevel = 0; send('reload'); env.reloading = false; send('tick');
assert.equal(env.self.tod_mage_mana, 0, 'locked Archmage cannot earn reload mana');
env.mana_add(100); assert.equal(env.mana_now(), 0, 'all locked mana income is blocked');
env.self.tod_mage_mana = 90; assert.equal(env.mana_now(), 0, 'clear stale pre-unlock mana');
env.archLevel = 1; env.mana_add(5); assert.equal(env.mana_now(), 5, 'first card enables income from zero');

// The native reload needs real reserve ammo and a space in the magazine.
// Replenishment must never fill that space while the animation is running.
Object.assign(env, {
    notify: () => {}, staff_element: w => w && w.staff ? (w.el || 'ice') : undefined,
    IsSwitchingWeapons: () => env.switching,
    GetWeaponAmmoStock: () => env.stock, GetWeaponAmmoClip: () => env.clip,
    SetWeaponAmmoStock: (_,n) => { env.stock=n; env.writes++; },
    SetWeaponAmmoClip: (_,n) => { env.clip=n; env.writes++; },
});
// v18.99: staff_clip_target now asks bolt_reload_suspended() (Infinite Ammo).
// level.zombie_vars is absent here, so the helper reports "not suspended" and
// this file keeps testing the ordinary pin.
vm.runInContext(`function bolt_reload_suspended() { ${body('bolt_reload_suspended')} }
function staff_clip_target(weapon) { ${body('staff_clip_target')} }
function* ammo() { let weapon, target; ${body('staff_ammo_watch')} }`, env);   // v18.77: the pin is a helper now
env.weapon = {staff:true,clipSize:1000}; env.clip=1000; env.stock=0;
env.reloading=env.switching=env.down=false; env.writes=0;
const refill=env.ammo(); refill.next();
assert.equal(env.clip,999); assert.equal(env.stock,1000);
refill.next(); assert.equal(env.writes,2,'no redundant ammo writes');
for(const state of ['reloading','switching','down']) {
    env[state]=true; env.clip=998; env.stock=999;
    refill.next(); assert.equal(env.clip,998); assert.equal(env.stock,999);
    env[state]=false;
}
env.weapon={staff:false}; refill.next(); assert.equal(env.writes,2,'nonstaff ammo untouched');
refill.return();
console.log('Optional reload ammo passed: reserve, reload space, and no writes during reload/swap/down or to other weapons.');
// v18.77 — the lightning reload pin: while a reload is owed the watcher holds
// the clip at ZERO (the engine's own auto-reload takes over) and still refills
// the reserve; the moment the pin lifts it is one short again.
env.weapon = {staff:true, el:'lightning', clipSize:6}; env.clip=5; env.stock=6;
env.reloading=env.switching=env.down=false; env.writes=0;
env.self.tod_mage_bolt_reload_due = true;
const pin=env.ammo(); pin.next(); assert.equal(env.clip,0,'pinned at 0 while owed'); assert.equal(env.stock,6);
env.stock=2; pin.next(); assert.equal(env.stock,6,'reserve refilled while owed'); assert.equal(env.clip,0);
env.self.tod_mage_bolt_reload_due = undefined; pin.next(); assert.equal(env.clip,5,'one short again once lifted');
env.weapon = {staff:true, el:'fire', clipSize:6}; env.self.tod_mage_bolt_reload_due = true; env.clip=5; pin.next(); assert.equal(env.clip,5,'fire never pins to 0');
console.log('Lightning reload pin passed: 0 while owed, reserve still refilled, lifted on reset, fire untouched.');
