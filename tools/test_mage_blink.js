// Execute the actual synchronous GSC charge helpers with mocked time/player.
// This small syntax adapter is not a GSC VM; the real build checks the dialect.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const path = require('path');
const src = fs.readFileSync(path.join(__dirname, '../scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'), 'utf8');
const names = ['blink_capacity', 'blink_recharge_ms', 'blink_charges_now', 'blink_spend'];
const helpers = names.map(name => {
    const start = src.indexOf('{', src.indexOf('function ' + name + '('));
    assert(start >= 0, name);
    let end = start + 1, depth = 1;
    while (depth) {
        if (src[end] === '{') depth++;
        if (src[end] === '}') depth--;
        end++;
    }
    const body = src.slice(start + 1, end - 1)
        .replace(/self\s+(\w+)\s*\(/g, '$1(')
        .replace(/\bself\./g, 'player.')
        .replace(/tod_upgrades::has_dark\( self, "mage_blink" \)/g, 'blink_dark()');
    return `function ${name}() { let lv, secs, cap, now, charges, interval; ${body} }`;
}).join('\n');
const env = { player: {}, level: 0, clock: 10000, hud: -1, dark: false,
    isdefined: v => v !== undefined, int: Math.trunc };
for (const name of ['TOD_MAGE_BLINK_CD', 'TOD_MAGE_BLINK_CD_LV', 'TOD_MAGE_BLINK_RECHARGE_SCALE']) {
    env[name] = Number(src.match(new RegExp('#define\\s+' + name + '\\s+([\\d.]+)'))[1]);
}
vm.createContext(env);
vm.runInContext(`
    function blink_level() { return level; }
    function cooldown_scale() { return 1; }
    function GetTime() { return clock; }
    function charges_now() { return 0; }
    function blink_dark() { return dark === true; }
    function abil_send(heal, blink) { hud = blink; }
    ${helpers}
`, env);
function reset(lv) { env.player = {}; env.level = lv; env.clock = 10000; }
function count() { return env.blink_charges_now(); }
function spend() { env.blink_spend(); }
function deadline() { return env.player.tod_mage_cd.mage_blink; }

for (const [lv, cap] of [[0,0], [1,1], [2,1], [3,2], [4,2], [5,2]]) {
    reset(lv);
    assert.equal(count(), cap, `level ${lv} capacity`);
    for (let i = 0; i < cap; i++) spend();
    assert.equal(count(), 0);
    const due = deadline();
    spend(); // a third cast, or a locked cast, consumes nothing and resets nothing
    assert.equal(count(), 0);
    assert.equal(deadline(), due);
    if (cap) {
        env.clock = due - 1;
        assert.equal(count(), 0, 'not ready before the deadline');
        env.clock++;
        assert.equal(count(), 1, 'one charge per recharge');
        env.clock += 100000;
        assert.equal(count(), cap, 'never banks more than capacity');
    }
}
reset(3); spend(); const due = deadline();
env.clock += 2000; spend();
assert.equal(deadline(), due, 'second use preserves first recharge progress');
assert.equal(env.hud, 0, 'spend publishes remaining count');
env.player.tod_mage_cd.mage_blink -= 2400; // any external edit of the shared timer (the elite refund used to; removed 2026-09-09)
env.clock = due - 2400;
assert.equal(count(), 1, 'an earlier deadline restores one charge early');
const lv3ms = Math.trunc((env.TOD_MAGE_BLINK_CD - 3 * env.TOD_MAGE_BLINK_CD_LV) * env.TOD_MAGE_BLINK_RECHARGE_SCALE * 1000);
assert.equal(lv3ms, 10800, 'Lv3 recharge is 6 s x 1.8 since 2026-09-09');
assert.equal(deadline(), due - 2400 + lv3ms);
reset(2); spend(); const beforeUpgrade = deadline();
env.level = 3;
assert.equal(count(), 1, 'Lv3 grants its new charge while the old one recharges');
assert.equal(deadline(), beforeUpgrade, 'upgrade preserves active recharge');
spend(); assert.equal(count(), 0);
env.level = 4; assert.equal(count(), 0, 'Lv4 adds no third slot or free refill');
// DARK BLINK (2026-09-09): a third stored charge, only on top of the two-charge cap.
reset(5); env.dark = true; assert.equal(count(), 3, 'dark blink stores three');
spend(); spend(); spend(); assert.equal(count(), 0); env.clock += 100000; assert.equal(count(), 3, 'refills to three');
reset(2); env.dark = true; assert.equal(count(), 1, 'dark cannot add a charge below Lv3'); env.dark = false;
env.level = 0; assert.equal(count(), 0, 'locked state stays empty');
env.level = 1; assert.equal(count(), 1, 'unlock grants first charge');
console.log('Blink charge checks passed: levels 0–5, exhaustion, sequential recharge, second use, elite refund and upgrades.');

for (let lv=1;lv<=5;lv++) { reset(lv); assert.equal(env.blink_recharge_ms(), [0,14400,12600,10800,9000,7200][lv]); }   // x1.8 since 2026-09-09 (x1.5: 12000..6000)
