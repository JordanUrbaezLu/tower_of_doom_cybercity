// Crosshair damage numbers: ONE NUMBER PER ZOMBIE (v19.47, user 2026-09-23:
// "I don't think I ever want to see the damage numbers combine for multiple
// zombies"). Runs the actual GSC bodies of push_dmg_num / dmg_num_flush /
// send_dmg_num from _tod_upgrade_ui.gsc against a mocked LuiNotifyEvent and
// a stepped clock, and pins the Lua decode to the GSC encode.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const path = require('path');
const root = path.resolve(__dirname, '..');
const src = fs.readFileSync(path.join(root, 'scripts/zm/zm_tower_of_doom/_tod_upgrade_ui.gsc'), 'utf8');
function body(name) {
    const at = src.indexOf('function ' + name + '(');
    assert(at >= 0, name);
    const start = src.indexOf('{', at);
    let end = start + 1, depth = 1;
    while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
    return src.slice(start + 1, end - 1)
        .replace(/(\w+) GetEntityNumber\(\)/g, 'GetEntityNumber($1)')
        .replace(/\.size\b/g, '.length')
        .replace(/(?:self|level) endon\(/g, 'endOn(')
        .replace(/self thread (\w+)\(/g, 'startThread("$1", ')
        .replace(/self LuiNotifyEvent\(/g, 'LuiNotifyEvent(')
        .replace(/&"/g, '"')
        .replace(/self send_dmg_num\(/g, 'send_dmg_num(')
        .replace(/self (\w+)\(/g, '$1(')
        .replace(/wait ([^;]+);/g, 'yield $1;');
}
const env = {IS_TRUE:v => v !== undefined && !!v, isdefined:v => v !== undefined,
    GetEntityNumber:e => e.id, SpawnStruct:() => ({}), GetTime:() => env.time, int:Math.trunc,
    GetArrayKeys:a => Object.keys(a).map(Number),
    LuiNotifyEvent:(name, argc, ...args) => {assert.equal(argc, args.length); env.events.push({name, args});},
    dmgnum_log:line => env.logs.push(line),
    endOn:e => env.ends.add(e), startThread:(name, ...args) => env.threads.push([name, ...args]),
    TOD_DMGNUM_WINDOW:Number(src.match(/#define TOD_DMGNUM_WINDOW\s+([\d.]+)/)[1]),
    TOD_DMGNUM_BURST:Number(src.match(/#define TOD_DMGNUM_BURST\s+(\d+)/)[1]),
    TOD_DMGNUM_PENDING:Number(src.match(/#define TOD_DMGNUM_PENDING\s+(\d+)/)[1]),
    TOD_DMGNUM_CAP:Number(src.match(/#define TOD_DMGNUM_CAP\s+(\d+)/)[1]),
    TOD_DMGNUM_BURN_KEY:Number(src.match(/#define TOD_DMGNUM_BURN_KEY\s+(\d+)/)[1]),
    level:{tod_dev:true}};
vm.createContext(env);
// GSC `[]` is an associative array: model it with a plain object (keys are ints).
const gscArray = /= \[\];/g;
for (const [name, args, locals, generator] of [
    ['push_dmg_num', 'dmg,headshot,reduced,victim,burn', 'key,e', false],
    ['dmg_num_flush', '', 'q,keys,sent,carried,i,e,late', true],
    ['send_dmg_num', 'e', 'dmg,flags', false],
]) vm.runInContext(`function${generator ? '*' : ''} ${name}(${args}) { ${locals ? 'let ' + locals + ';' : ''} ${body(name).replace(gscArray, '= {};').replace(/\.length\b/g, '.__len')} }`, env);
// `.length` on the associative queue means "number of keys" in GSC (.size); give objects
// that in BOTH realms (vm-created literals inherit the context's Object.prototype).
const lenGetter = "Object.defineProperty(Object.prototype, '__len', {get() { return Array.isArray(this) ? this.length : Object.keys(this).length; }, configurable:true});";
eval(lenGetter);
vm.runInContext(lenGetter, env);

function reset() { Object.assign(env, {self:{id:0}, events:[], logs:[], ends:new Set(), threads:[], time:1000}); }
const z = id => ({id});
function pushAll(hits) { for (const [dmg, hs, red, victim] of hits) env.push_dmg_num(dmg, hs, red, victim); }
// Run one flush thread to completion, advancing the clock at every wait.
function flush() {
    const co = env.dmg_num_flush();
    let step = co.next(), waits = 0;
    while (!step.done) { assert.equal(step.value, env.TOD_DMGNUM_WINDOW); env.time += 50; waits++; step = co.next(); }
    return waits;
}
const amounts = () => env.events.map(e => e.args[0]);

// A fire-staff splash over five zombies: five events in ONE frame, no sum.
reset();
pushAll([[200000, false, false, z(10)], [200000, false, false, z(11)], [200000, false, false, z(12)], [200000, false, false, z(13)], [200000, false, false, z(14)]]);
assert.deepEqual(env.threads, [['dmg_num_flush']], 'one flush thread per burst');
assert.equal(env.events.length, 0, 'nothing sent from inside the callback');
assert.equal(flush(), 1, 'one window, then everything went out');
assert.deepEqual(amounts(), [200000, 200000, 200000, 200000, 200000], 'five numbers, never one million');
assert(env.events.every(e => e.name === 'tod_dmg' && e.args[1] === 0));
assert.equal(env.self.tod_dmg_acc_on, false, 'the flush retires itself');
assert(env.logs.some(l => l.startsWith('FLUSH ') && l.includes('zombies=5 sent=5 carried=0')));

// One shot on ONE zombie still reads as one number: eight pellets merge,
// a head pellet colours it, an armored pellet reddens it (red bit 2, head bit 1).
reset();
for (let i = 0; i < 8; i++) env.push_dmg_num(150, i === 3, false, z(7));
flush();
assert.deepEqual(env.events.map(e => e.args), [[1200, 1]], 'a shotgun on one zombie is one number, headshot-coloured');
reset();
env.push_dmg_num(90, true, false, z(7)); env.push_dmg_num(60, false, true, z(7));
flush();
assert.deepEqual(env.events.map(e => e.args), [[150, 3]], 'head + reduced flags both carried');
assert.equal(env.logs.filter(l => l.startsWith('FLUSH ')).length, 0, 'a single-zombie frame is not logged');

// Two zombies from one penetrating round: two numbers, each its own hit.
reset();
pushAll([[400, true, false, z(1)], [400, false, false, z(2)]]);
flush();
assert.deepEqual(env.events.map(e => e.args), [[400, 1], [400, 0]]);

// BURN (v19.50): a fire tick carries bit 3 (orange) and pools under its OWN
// key, so a bullet and a burn on the same zombie in one frame are two numbers
// (amber 300, orange 40), never one orange 340. A burn on an armored sprinter
// keeps the reduced bit too (4 + 2); the Lua lets orange win.
reset();
env.push_dmg_num(300, false, false, z(9)); env.push_dmg_num(40, false, false, z(9), true);
env.push_dmg_num(25, false, true, z(9), true);   // a second tick / an armored one in the same frame merges with the burn lane only
flush();
assert.deepEqual(env.events.map(e => e.args).sort((a, b) => a[0] - b[0]), [[65, 6], [300, 0]], 'burn is its own number and its own flag');
assert(env.TOD_DMGNUM_BURN_KEY > 2048, 'burn key clears every entity number');
reset(); env.push_dmg_num(50, false, false, z(4), false); env.push_dmg_num(50, false, false, z(4)); flush();
assert.deepEqual(env.events.map(e => e.args), [[100, 0]], 'burn=false and burn omitted are the same plain lane');

// No victim known: those hits pool in the unknown bucket, apart from the rest.
reset();
pushAll([[100, false, false, undefined], [100, false, false, undefined], [100, false, false, z(3)]]);
flush();
assert.deepEqual(amounts().sort((a, b) => a - b), [100, 200]);

// A crowd past the per-frame burst carries into the NEXT frame, still one
// number per zombie, none dropped, none summed.
reset();
const crowd = [];
for (let i = 0; i < 11; i++) crowd.push([1000 + i, false, false, z(100 + i)]);
pushAll(crowd);
const waits = flush();
assert.equal(waits, 2, 'eight this frame, three the next');
assert.equal(env.events.length, 11);
assert.deepEqual(amounts().sort((a, b) => a - b), crowd.map(c => c[0]).sort((a, b) => a - b), 'every zombie kept its own number');
assert(env.logs.some(l => l.includes('zombies=11 sent=8 carried=3')));
assert(env.logs.some(l => l.includes('zombies=3 sent=3 carried=0')));

// A zombie hit again while its number waited in the carry: the two hits stay
// ONE number for that ONE zombie (never two zombies in one number).
reset();
pushAll(crowd);
const co = env.dmg_num_flush();
let step = co.next(); env.time += 50;          // first window
step = co.next();                              // first frame sent 8, carried 3, now waiting
assert.equal(env.events.length, 8);
env.push_dmg_num(5, false, false, z(110));     // zombie 110 was carried; hit again during the wait
env.time += 50; step = co.next();
assert(step.done);
assert.equal(env.events.length, 11);
assert(amounts().includes(1010 + 5), 'the carried hit and the new hit merged for that zombie');

// The pending ceiling drops a NEW zombie's number (not an existing one's hit),
// logs it, and never blocks a callback.
reset();
for (let i = 0; i < env.TOD_DMGNUM_PENDING + 5; i++) env.push_dmg_num(10, false, false, z(500 + i));
env.push_dmg_num(90, false, false, z(500));   // an already-queued zombie still accumulates (the 5th arg is the burn flag now, so no note string here)
assert.equal(Object.keys(env.self.tod_dmg_q).length, env.TOD_DMGNUM_PENDING);
assert.equal(env.logs.filter(l => l.startsWith('DROP ')).length, 5);
assert.equal(env.self.tod_dmg_q[501].dmg, 100);
flush();
assert.equal(env.events.length, env.TOD_DMGNUM_PENDING);

// Encoding: exact integers, capped at the seven-glyph pool, floored at 1;
// zero and negative pushes are ignored.
reset();
env.push_dmg_num(12345678, false, false, z(1)); env.push_dmg_num(0, true, true, z(2)); env.push_dmg_num(-5, true, true, z(3));
flush();
assert.deepEqual(env.events.map(e => e.args), [[env.TOD_DMGNUM_CAP, 0]]);
assert.equal(env.TOD_DMGNUM_CAP, 9999999);
reset(); env.push_dmg_num(0.4, false, false, z(1)); flush();
assert.deepEqual(amounts(), [1], 'a sub-unit hit still shows 1');

// Lifetime and lanes: the flush endons disconnect / end_game, the event is
// precached, the retired clientfield is untouched (61-bit layout), and the
// Lua decode is the mirror of the encode.
const flushBody = body('dmg_num_flush');
for (const e of ['disconnect', 'end_game']) assert(flushBody.includes('"' + e + '"'));
assert(src.includes('#precache( "eventstring", "tod_dmg" );'), 'an unprecached eventstring never fires');
assert(src.includes('clientfield::register( "clientuimodel", "todDmgNum",  VERSION_SHIP, 15, "int" );'), 'the clientfield stays registered: APPEND ONLY, proven 61 bits');
const code = src.replace(/\/\/.*$/gm, '');
assert(!code.includes('set_player_uimodel( "todDmgNum"'), 'nothing writes the retired field');
assert(!code.includes('function push_dmg_num_now'), 'the old encoder is gone');
for (const f of ['_tod_upgrades.gsc', '_tod_bosses.gsc', '_tod_powerups.gsc']) {
    const s = fs.readFileSync(path.join(root, 'scripts/zm/zm_tower_of_doom', f), 'utf8');
    for (const m of s.matchAll(/push_dmg_num\(([^;]*)\);/g)) {
        const args = m[1].split(',').map(x => x.trim());
        assert(args.length === 4 || args.length === 5, f + ': every caller names its victim: ' + m[0]);
        assert.equal(args[3], 'self', f + ': the victim is the damaged actor: ' + m[0]);
        if (args.length === 5) assert.equal(args[4], 'true', f + ': the fifth argument is the burn flag, literal true: ' + m[0]);
    }
}
// The three burn lanes (TRAILBLAZER x2, FIRE BLAST elite burn) are the ONLY
// callers passing burn; everything else stays on the 4-arg plain lane.
{
    const up = fs.readFileSync(path.join(root, 'scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc'), 'utf8').replace(/\/\/.*$/gm, '');
    const burnCalls = [...up.matchAll(/push_dmg_num\(([^;]*)\);/g)].filter(m => m[1].split(',').length === 5);
    assert.equal(burnCalls.length, 3, 'exactly the three burn pushes carry the flag');
    const trail = up.slice(up.indexOf('if ( IS_TRUE( self.tod_trail_hit ) )'), up.indexOf('if ( IS_TRUE( self.tod_wisp_hit ) )'));
    assert.equal([...trail.matchAll(/push_dmg_num\(([^;]*), true \);/g)].length, 2, 'both TRAILBLAZER exits burn');
    const mage = up.slice(up.indexOf('if ( IS_TRUE( self.tod_mage_burn_hit ) )'), up.indexOf('self.tod_smash_hit_ms == GetTime()'));
    assert.equal([...mage.matchAll(/push_dmg_num\(([^;]*), true \);/g)].length, 1, 'the FIRE BLAST burn tick burns');
}
const lua = fs.readFileSync(path.join(root, 'ui/uieditor/menus/hud/tod_upgrade.lua'), 'utf8');
assert(lua.includes('if ev ~= "tod_dmg" then return end'), 'Lua listens on tod_dmg');
assert(lua.includes('local hs  = ( flags % 2 ) >= 1') && lua.includes('local red = ( math.floor( flags / 2 ) % 2 ) >= 1') && lua.includes('local burn = ( math.floor( flags / 4 ) % 2 ) >= 1'), 'Lua flag bits mirror send_dmg_num');
assert(lua.includes('spawnNum( dmg, hs, red, burn )') && lua.includes('local c  = burn and DMG_COLOR_BURN or ( red and DMG_COLOR_RED or ( hs and DMG_COLOR_HS or DMG_COLOR ) )'), 'burn is drawn in its own colour and wins over red');
{
    const burnRgb = lua.match(/local DMG_COLOR_BURN\s*=\s*\{\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)\s*\}/);
    assert(burnRgb, 'DMG_COLOR_BURN defined');
    const [r, g, b] = burnRgb.slice(1).map(Number);
    assert(r >= 0.9 && g > 0.35 && g < 0.7 && b < 0.2, 'DMG_COLOR_BURN reads as orange: red high, green in the middle, blue near zero');
}
assert(!/"todDmgNum"/.test(lua.replace(/--.*$/gm, '')), 'Lua no longer reads the retired field');
assert(/local DMG_POOL\s*=\s*(\d+)/.test(lua) && Number(lua.match(/local DMG_POOL\s*=\s*(\d+)/)[1]) >= env.TOD_DMGNUM_BURST, 'the Lua pool holds a full burst');
console.log('Damage numbers: one per zombie (five from a splash, one per shotgun target), flags carried, bursts of ' + env.TOD_DMGNUM_BURST + ' per frame with carry, pending ceiling drops logged, exact amounts capped at ' + env.TOD_DMGNUM_CAP + ', callers name their victim, Lua decode LOCKSTEP.');
