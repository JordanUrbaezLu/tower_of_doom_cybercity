// The tower gauge's boss pip: the HIGHEST live PANZER, never an elite.
// (v19.46, user 2026-09-23: "that icon should only be used for panzers, it
// should not be used for elites, and if there's multiple panzers it should be
// the highest most panzer".) Runs the actual GSC bodies of is_panzer() and
// boss_floor() from _tod_gauge.gsc against mocked entities.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const path = require('path');
const root = path.resolve(__dirname, '..');
const src = fs.readFileSync(path.join(root, 'scripts/zm/zm_tower_of_doom/_tod_gauge.gsc'), 'utf8');
function body(name) {
    const at = src.indexOf('function ' + name + '(');
    assert(at >= 0, name);
    const start = src.indexOf('{', at);
    let end = start + 1, depth = 1;
    while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
    return src.slice(start + 1, end - 1)
        .replace(/foreach \( b in ai \)/g, 'for (const b of ai)')
        .replace(/\.size\b/g, '.length')
        .replace(/\( isdefined\( level\.zombie_team \) \? level\.zombie_team : "axis" \)/g, '(isdefined(level.zombie_team) ? level.zombie_team : "axis")');
}
const CELLS = 25, LAP_RISE = 384, ROOF = 19200;
// IS_TRUE is `isdefined( x ) && x`: GSC truthiness, so the pack's numeric 1 counts.
const env = {IS_TRUE:v => v !== undefined && !!v, isdefined:v => v !== undefined, IsAlive:e => !!e?.alive,
    GetAITeamArray:team => {env.teams.push(team); return env.ai;},
    cells_for_mode:() => CELLS,
    // The real floor_of(): z<0 -> 0, two real floors per cell, roof -> 26.
    floor_of:z => z < 0 ? 0 : (z >= ROOF ? CELLS + 1 : Math.floor(z / LAP_RISE / 2) + 1),
    level:{}, teams:[], ai:[]};
vm.createContext(env);
env.TOD_GAUGE_PIPS_MAX = Number(src.match(/#define TOD_GAUGE_PIPS_MAX (\d+)/)[1]);
for (const [name, args, locals] of [['is_panzer', 'b', ''], ['boss_cells', '', 'team,ai,found,panzers,elites,cells,f,result,c'],
    ['boss_floor', '', 'pips'], ['pack_pips', 'pips,first', 'hi,lo']])
    vm.runInContext(`function ${name}(${args}) { ${locals ? 'let ' + locals + ';' : ''} ${body(name)} }`, env);

const cellZ = c => (c - 1) * 2 * LAP_RISE + 10;   // a z inside real floor 2c-1 -> cell c
const panzer = (cell, extra = {}) => ({alive:true, is_boss:true, acc_is_boss:true, acc_is_mini_boss:true, tod_boss_kind:'panzer', is_mechz:1, origin:[0, 0, cellZ(cell)], ...extra});
const protector = cell => ({alive:true, is_boss:true, acc_is_boss:true, acc_is_mini_boss:true, tod_boss_kind:'protector', origin:[0, 0, cellZ(cell)]});
const reaver = cell => ({alive:true, is_boss:true, acc_is_boss:true, acc_is_mini_boss:true, tod_boss_kind:'reaver', origin:[0, 0, cellZ(cell)]});
const hound = cell => ({alive:true, tod_boss_kind:'hellhound', origin:[0, 0, cellZ(cell)]});
const zombie = cell => ({alive:true, origin:[0, 0, cellZ(cell)]});
function pip(ai, team) {
    env.ai = ai; env.level = team ? {zombie_team:team} : {}; env.teams = [];
    return env.boss_floor();
}

// Identity: either mark alone is a Panzer; neither is not.
assert.equal(env.is_panzer(panzer(1)), true);
assert.equal(env.is_panzer({tod_boss_kind:'panzer'}), true, 'the map lane stamp alone');
assert.equal(env.is_panzer({is_mechz:1}), true, 'the pack archetype flag alone (mechz_spiki sets a numeric 1)');
assert.equal(env.is_panzer({is_mechz:0}), false, 'a cleared pack flag is not a Panzer');
assert.equal(env.is_panzer(protector(3)), false);
assert.equal(env.is_panzer(reaver(3)), false);
assert.equal(env.is_panzer(hound(3)), false);
assert.equal(env.is_panzer(zombie(3)), false);

// Nothing alive, or only ordinary zombies: no pip.
assert.equal(pip([]), 0);
assert.equal(pip([zombie(4), zombie(9)]), 0);
assert.deepEqual(env.teams, ['axis'], 'defaults to the axis team');
assert.equal(pip([zombie(4)], 'zm_team'), 0); assert.deepEqual(env.teams, ['zm_team'], 'reads level.zombie_team');

// ELITES NEVER WEAR THE PIP: a Protector wave or a Reaver alone = no pip,
// and they cannot drag the pip below a live Panzer either.
assert.equal(pip([protector(9), protector(9), reaver(12), hound(2)]), 0, 'elites alone: no pip');
assert.equal(env.level.tod_gauge_pip_elites, 3, 'the three flagged elites are counted as passed over (the hound carries no boss flag)');
assert.equal(env.level.tod_gauge_pip_panzers, 0);
assert.equal(pip([protector(2), panzer(5), reaver(1)]), 5, 'the Panzer, not the lower elites (the old rule showed cell 1)');
assert.equal(pip([protector(20), panzer(5)]), 5, 'nor a higher elite');

// SEVERAL PANZERS: the highest one.
assert.equal(pip([panzer(3), panzer(7)]), 7);
assert.equal(pip([panzer(7), panzer(3)]), 7, 'order-independent');
assert.equal(pip([panzer(3), panzer(7), panzer(5, {alive:false}), panzer(20, {alive:false})]), 7, 'dead Panzers are ignored');
assert.equal(env.level.tod_gauge_pip_panzers, 2);
assert.equal(pip([panzer(3), undefined, panzer(7)]), 7, 'a deleted slot is skipped');

// The King / a Warden carries the pack flag; the rooftop and the base clamp
// into the 1..25 band the Lua draws.
assert.equal(pip([{alive:true, is_mechz:true, origin:[0, 0, ROOF + 500]}]), CELLS, 'a Panzer on the roof pins to the top cell');
assert.equal(pip([{alive:true, tod_boss_kind:'panzer', origin:[0, 0, -200]}]), 1, 'a Panzer in the base arena pins to cell 1');
assert.equal(pip([panzer(25), panzer(24)]), 25);

// SEVERAL PIPS (user, the same hour: "if there's two panzers and they're on
// separate floors, maybe we can show two indicators"): boss_cells() lists the
// distinct cells, highest first, at most TOD_GAUGE_PIPS_MAX; pack_pips packs
// two cells per int (hi*64 + lo), LOCKSTEP with the Lua decode.
function cellsOf(ai) { env.ai = ai; env.level = {}; return Array.from(env.boss_cells()); }   // Array.from: the vm realm's Array is not deepStrictEqual to the host's
assert.equal(env.TOD_GAUGE_PIPS_MAX, 4, 'the Lua pool GA_PIPS is 4');
assert.deepEqual(cellsOf([]), []);
assert.deepEqual(cellsOf([protector(3), reaver(9)]), [], 'elites never earn a pip');
assert.deepEqual(cellsOf([panzer(3), panzer(7)]), [7, 3], 'two floors, two pips, highest first');
assert.deepEqual(cellsOf([panzer(5), panzer(5), {alive:true, tod_boss_kind:'panzer', origin:[0, 0, cellZ(5) + LAP_RISE]}]), [5], 'same cell (the two real floors it folds) = one pip');
assert.deepEqual(cellsOf([panzer(1), panzer(2), panzer(3), panzer(4), panzer(5), panzer(6)]), [6, 5, 4, 3], 'more than four floors: the four highest');
assert.deepEqual(cellsOf([panzer(7), protector(20), panzer(3, {alive:false}), panzer(12)]), [12, 7]);
assert.deepEqual(cellsOf([{alive:true, is_mechz:1, origin:[0, 0, ROOF + 100]}, panzer(2)]), [CELLS, 2], 'roof clamp still applies per pip');
assert.equal(env.pack_pips([7, 3], 0), 7 * 64 + 3);
assert.equal(env.pack_pips([7, 3], 2), 0, 'no third/fourth pip packs to 0');
assert.equal(env.pack_pips([25, 24, 10, 2], 0), 25 * 64 + 24);
assert.equal(env.pack_pips([25, 24, 10, 2], 2), 10 * 64 + 2);
assert.equal(env.pack_pips([], 0), 0);
assert(env.pack_pips([52, 52, 52, 52], 0) <= 4095, 'a spire cell pair fits the safe int range');
for (const [cells, expect] of [[[], 0], [[9], 9], [[12, 4], 12]]) { env.ai = cells.map(c => panzer(c)); env.level = {}; assert.equal(env.boss_floor(), expect, 'boss_floor is the first pip'); }

// The feeds: tod_pips carries the pips (2 args, change-gated per player),
// tod_floor keeps its shape, the old lowest-boss rule is gone from the code.
assert(src.includes('p LuiNotifyEvent( &"tod_pips", 2, pa, pb );'));
assert(src.includes('p LuiNotifyEvent( &"tod_floor", 2, f, boss_f );'));
assert(src.includes('#precache( "eventstring", "tod_pips" );'), 'an unprecached eventstring never fires');
assert(src.includes('for ( c = cells; c >= 1; c-- )') && !src.includes('f < best'), 'highest first, never lowest');
const code = src.replace(/\/\/.*$/gm, '');
assert(!/if \( !IS_TRUE\( b\.is_boss \) && !IS_TRUE\( b\.acc_is_boss \)/.test(code), 'the boss flags no longer select the pip');
assert(src.includes('dev_log( "PIP cells="'), 'the change-gated PIP log exists for the playtest');
const lua = fs.readFileSync(path.join(root, 'ui/uieditor/menus/hud/tod_upgrade.lua'), 'utf8');
assert(lua.includes('local GA_PIPS = 4'), 'Lua pip pool LOCKSTEP with TOD_GAUGE_PIPS_MAX');
assert(lua.includes('ev ~= "tod_pips"') && lua.includes('gaPips[ 1 ] = math.floor( a / 64 )') && lua.includes('gaPips[ 2 ] = a % 64'), 'Lua decodes hi*64 + lo');
assert(!/GaugeBoss[^a-zA-Z]/.test(lua.replace(/--.*$/gm, '')), 'the single-pip element is gone from live Lua');
assert(lua.indexOf('local gaClimbed, gaMode') < lua.indexOf('local function gaPlacePip'), 'the pip helpers close over a declared gaMode');
console.log('Tower gauge boss pips: Panzer only (map stamp or pack flag), one pip per floor that holds one, highest four, elites never, dead/deleted skipped, roof/base clamps, tod_pips packing LOCKSTEP with the Lua.');
