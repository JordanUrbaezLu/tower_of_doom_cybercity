// Execute the shipping movement policy with mocked native locomotion. Verify
// promotion, steady sweeps, drift, pauses/risers, native slows, and rate restores.
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert/strict');
const root = path.join(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'scripts/zm/zm_tower_of_doom/_tod_zombie_speed.gsc'), 'utf8');
const sprinter = fs.readFileSync(path.join(root, 'scripts/zm/zm_tower_of_doom/_tod_sprinter.gsc'), 'utf8');
const constants = Object.fromEntries([...source.matchAll(/^#define\s+(\w+)\s+([-\d.]+)/gm)].map(m => [m[1], Number(m[2])]));
const offset = Number(sprinter.match(/^#define\s+TOD_SPRINT_SPEED_ADD\s+([-\d.]+)/m)[1]);
assert.equal(offset, -10, 'the walk does not silently retune the existing armored offset');
assert.match(sprinter, /self\.tod_zspeed_round_add = TOD_SPRINT_SPEED_ADD;\s*self tod_zombie_speed::apply_speed_for_round\( tod_zombie_speed::current_round\(\) \);/, 'promotion applies through the speed owner');

function extract(src, name) {
    const match = new RegExp('function ' + name + '\\( ([^)]*) \\)|function ' + name + '\\(\\)').exec(src);
    assert.ok(match, name);
    const start = src.indexOf('{', match.index);
    let end = start + 1, depth = 1;
    while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
    return {params: (match[1] || '').trim(), code: src.slice(start + 1, end - 1).replace(/\/\/[^\n]*/g, '')};
}
function translate(src, name) {
    const {params, code} = extract(src, name);
    let b = code.replace(/\/#|#\//g, '')
        .replace(/self zombie_utility::set_zombie_run_cycle_override_value\(/g, 'setCycle(')
        .replace(/self ASMSetAnimationRate\(/g, 'setRate(')
        .replace(/self (under_anim_slow|slow_mult|log_armored_walk|GetEntityNumber)\(/g, '$1(');
    for (const [k, v] of Object.entries(constants)) b = b.replace(new RegExp('\\b' + k + '\\b', 'g'), String(v));
    const locals = [...new Set([...b.matchAll(/^\s*(\w+)\s*=/gm)].map(m => m[1]))];
    return `function ${name}(${params}) { ${locals.length ? 'let ' + locals.join(',') + ';' : ''} ${b} }`;
}
function scenario(src) {
    const ctx = {self: {}, level: {tod_dev: true}, now: 1000, cycleCalls: 0, rates: [], logs: []};
    ctx.IS_TRUE = x => x === true;
    ctx.isdefined = x => x !== undefined;
    ctx.GetTime = () => ctx.now;
    ctx.GetEntityNumber = () => 123;
    ctx.PrintLn = line => ctx.logs.push(line);
    ctx.under_anim_slow = () => ctx.self.nativeSlow === true;
    // This reproduces the stock override refusal: forgetting to clear it
    // records a restore and never changes the native gait.
    ctx.setCycle = gait => {
        if (ctx.self.zombie_move_speed_override !== undefined) {
            ctx.self.zombie_move_speed_restore = gait;
            return;
        }
        ctx.cycleCalls++;
        ctx.self.zombie_move_speed = gait;
        ctx.self.variant_type = gait === 'walk' ? 4 : 2;
        ctx.self.zombie_move_speed_override = gait;
    };
    ctx.setRate = rate => ctx.rates.push(rate);
    vm.createContext(ctx);
    for (const name of ['full_round', 'zspeed_step', 'rate_for_round', 'slow_mult', 'apply_speed_for_round', 'log_armored_walk'])
        vm.runInContext(translate(src, name), ctx);
    return ctx;
}
const near = (a, b) => assert.ok(Math.abs(a - b) < 1e-9, `${a} != ${b}`);
function run(src) {
    const c = scenario(src);
    c.self = {zombie_move_speed: 'walk', zombie_arms_position: 'up'};
    c.apply_speed_for_round(1);
    assert.equal(c.self.zombie_move_speed, 'sprint');
    assert.equal(c.self.zombie_arms_position, 'up', 'ordinary arms untouched');
    near(c.rates.at(-1), .8);
    assert.equal(c.logs.length, 0, 'ordinary zombie has no armored log');
    const stockCalls = c.cycleCalls;
    c.apply_speed_for_round(1);
    assert.equal(c.cycleCalls, stockCalls, 'steady ordinary sweep does not reroll');

    c.self.tod_is_sprinter = true; c.self.tod_zspeed_round_add = offset;
    c.apply_speed_for_round(20);
    assert.equal(c.self.zombie_move_speed, 'walk', 'promotion uses the distinct walk');
    assert.equal(c.self.zombie_move_speed_override, 'walk');
    assert.equal(c.self.zombie_arms_position, 'down', 'blade arms hang down');
    near(c.rates.at(-1), .8 + 9 * (.2 / 17));
    assert.match(c.logs.at(-1), /\[TOD_ARMORED_WALK\].*ent=123.*gait=walk.*arms=down.*variant=4.*round=20.*round_add=-10/);
    const calls = c.cycleCalls, logs = c.logs.length;
    for (let i = 0; i < 20; i++) c.apply_speed_for_round(20);
    assert.equal(c.cycleCalls, calls, 'walk variant stays stable over sweeps');
    assert.equal(c.logs.length, logs, 'steady sweep emits no spam');

    c.self.zombie_move_speed = 'sprint'; c.self.zombie_move_speed_override = 'sprint';
    c.self.zombie_arms_position = 'up'; c.apply_speed_for_round(20);
    assert.equal(c.self.zombie_move_speed, 'walk', 'stock drift repaired');
    assert.equal(c.self.zombie_arms_position, 'down');
    assert.equal(c.cycleCalls, calls + 1, 'one native repair');

    for (const field of ['is_boss', 'tod_boss_custom_speed', 'tod_frozen', 'in_the_ground', 'nativeSlow']) {
        c.self[field] = true;
        const before = [c.cycleCalls, c.rates.length, c.logs.length];
        c.apply_speed_for_round(30);
        assert.deepEqual([c.cycleCalls, c.rates.length, c.logs.length], before, field + ' owns locomotion');
        delete c.self[field];
    }
    c.level.tod_upgrade_pause = true;
    const rates = c.rates.length; c.apply_speed_for_round(30);
    assert.equal(c.rates.length, rates, 'upgrade pause owns the rate');
    c.level.tod_upgrade_pause = false;

    c.self.tod_slow_until = 2000; c.self.tod_slow_mult = .6;
    c.apply_speed_for_round(30);
    near(c.rates.at(-1), (1 + 2 * .0021) * .6);
    c.now = 2000; c.apply_speed_for_round(30);
    near(c.rates.at(-1), 1 + 2 * .0021);
    assert.equal(c.self.zombie_move_speed, 'walk', 'slow expiry retains armored walk');
    c.level.tod_rampage_on = true; c.apply_speed_for_round(30);
    near(c.rates.at(-1), 1 + 10 * .0028);
    assert.match(c.logs.at(-1), /rampage=true/);
    c.level.tod_dev = false;
    const beforeLogs = c.logs.length; c.apply_speed_for_round(31);
    assert.equal(c.logs.length, beforeLogs, 'ship state emits no logs');
    assert.equal(c.self.zombie_move_speed, 'walk', 'walking is independent of dev mode');
}
run(source);
for (const [name, mutated] of [
    ['ordinary gait on armored', source.replace('gait = "walk";', 'gait = "sprint";')],
    ['raised blade arms', source.replace('self.zombie_arms_position = "down";', 'self.zombie_arms_position = "up";')],
    ['missing override release', source.replace('self.zombie_move_speed_override = undefined;', '')],
    ['promotion frees native slow', source.replace('if ( self under_anim_slow() )\n\t\treturn;', '')]
]) {
    assert.notEqual(mutated, source, name + ' mutation applied');
    assert.throws(() => run(mutated), undefined, name + ' must be detected');
}
console.log('ARMORED_WALK_OK: distinct walk/arms-down, stable variants, drift repair, boss/freeze/riser/native-slow guards, round/rampage/slow restores, change-only dev logs; four negative controls.');
