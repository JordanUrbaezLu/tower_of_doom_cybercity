// Execute the actual synchronous GSC volley helper with native calls mocked.
// This checks filtering/ownership/aim geometry, not BO3 projectile collision.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const path = require('path');
const src = fs.readFileSync(path.join(__dirname, '../scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'), 'utf8');
function body(name) {
    const begin = src.indexOf('{', src.indexOf(`function ${name}(`));
    let end = begin + 1, depth = 1;
    while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
    return src.slice(begin + 1, end - 1);
}
const adapted = body('ice_side_shots')
    .replace(/self GetEye\(\)/g, 'GetEye()')
    .replace(/self GetPlayerAngles\(\)/g, 'GetPlayerAngles()')
    .replace('forward + right * ( side * 0.140540835 )', 'add(forward, scale(right, side * 0.140540835))')
    .replace('start + direction * 16384', 'add(start, scale(direction, 16384))')
    // v18.93: the side missiles launch VOLLEY_START units ahead of the eye, not from it.
    .replace('GetEye() + forward * TOD_MAGE_ICE_VOLLEY_START', 'add(GetEye(), scale(forward, VOLLEY_START))');
const VOLLEY_START = Number(src.match(/#define\s+TOD_MAGE_ICE_VOLLEY_START\s+(\d+)/)[1]);
assert.equal(VOLLEY_START, 88);
const env = {
    shots: [], self: {}, angles: [0, 0, 0],
    isdefined: v => v !== undefined, IsSubStr: (s, sub) => s.includes(sub),
    add: (a, b) => a.map((v, i) => v + b[i]), scale: (a, k) => a.map(v => v * k),
    VectorNormalize: a => a.map(v => v / Math.hypot(...a)), GetEye: () => [10, 20, 60],
    AnglesToForward: ([p, y]) => { p *= Math.PI / 180; y *= Math.PI / 180; return [Math.cos(p) * Math.cos(y), Math.cos(p) * Math.sin(y), -Math.sin(p)]; },
    AnglesToRight: ([, y]) => [Math.sin(y * Math.PI / 180), -Math.cos(y * Math.PI / 180), 0],
};
env.GetPlayerAngles = () => env.angles;
env.VOLLEY_START = VOLLEY_START;
env.MagicBullet = (...args) => env.shots.push(args);
vm.createContext(env);
vm.runInContext(`function staff_element(weapon) { ${body('staff_element')} }
function fire(weapon) { let element, start, angles, forward, right, side, direction; ${adapted} }`, env);
for (const weapon of [undefined, {}, {name: 'none'}, {name: 'tod_staff_fire_q0'}, {name: 'tod_staff_lightning_q1'}, {name: 'ice_gun'}]) {
    env.shots = []; env.fire(weapon); assert.equal(env.shots.length, 0);
}
let checks = 0;
for (const suffix of ['q0', 'q1']) for (const pitch of [-89, -45, 0, 45, 89]) for (const yaw of [0, 90, 210, 359]) {
    const weapon = {name: `tod_staff_ice_${suffix}`, attachments: ['retained']};
    env.angles = [pitch, yaw, 0]; env.shots = []; env.fire(weapon);
    assert.equal(env.shots.length, 2, 'only two additions to the native center shot');
    const forward = env.AnglesToForward(env.angles), right = env.AnglesToRight(env.angles);
    const dot = (a, b) => a.reduce((sum, v, i) => sum + v * b[i], 0);
    const dirs = env.shots.map(([w, start, end, owner]) => {
        assert.equal(w, weapon); assert.equal(owner, env.self);
        const eye = env.GetEye();
        const launch = start.map((v, i) => v - eye[i]);
        assert.ok(Math.abs(Math.hypot(...launch) - VOLLEY_START) < 1e-6, 'side missiles start VOLLEY_START ahead of the eye');
        assert.ok(Math.abs(dot(env.VectorNormalize(launch), forward) - 1) < 1e-6, 'launch offset is straight ahead');
        const delta = end.map((v, i) => v - start[i]);
        assert.ok(Math.abs(Math.hypot(...delta) - 16384) < 1e-6);
        const dir = env.VectorNormalize(delta);
        assert.ok(Math.abs(Math.acos(dot(dir, forward)) * 180 / Math.PI - 8) < 1e-5);
        return dir;
    });
    assert.ok(dot(dirs[0], right) < 0 && dot(dirs[1], right) > 0);
    checks++;
}
console.log(`Ice volley: ${checks} variant/aim cases pass; non-ice filtered, two symmetric side shots, weapon and owner preserved.`);
