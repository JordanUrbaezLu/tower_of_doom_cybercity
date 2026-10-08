// tools/lint_tod_perches.js — the PERCH gate (v19.71, 2026-10-03). Runs on every full
// build (build_map.ps1, after the geometry lint).
//
// WHY THIS EXISTS
// ---------------
// A Workshop tester, playing the Slasher with the ATHLETE wall-run: "I just tested the
// ammo box on first floor and first attempt am on top of the box and cant be hit ... Same
// thing with quick revive ... I was able to replicate this with rampage also ... I'm sure
// these could be found on each floor." The user: "Wall running seems to have not been
// thought through enough ... think and resolve any potential gaps."
//
// A PERCH is a surface a player can stand on that the horde cannot walk onto and cannot
// swing at: the top of a prop's collision, a ledge, a lintel, the top of an invisible
// rail cap. Zombies path on the navmesh, which only joins floors a STEP_MAX step apart,
// and a zombie swings only when the player is within 64 of it in 3D (stock
// zombieShouldMeleeCondition) — so a player 58 up on a crate's clip column was out of
// reach of the whole horde. Every prop in this map stood in for its missing collision
// with a FLAT-TOPPED box; the athlete jumps 2.25x higher and runs on walls, so every one
// of those tops became reachable the day wall-running shipped (v16.34), and the v19.69
// Ammo Box V6 (29 tall, its clip still 58) made the crate top a perch for any class.
//
// THE MODEL lives in tools/perch_core.js and is shared with gen_tower_map.js: the
// generator's PERCH SEAL pass closes every perch the model finds before it writes the
// .map, and THIS tool re-proves the finished .map from scratch. Props get designed caps
// (PERCH CAPS block in the generator: steep player-only wedges leaning into the prop's
// wall — map 1, abandoned_cyber_city_zombies add_prop_clips.js, learned that 56 degrees
// still let BO3 players stand and 72 did not); everything else the model flags is raised
// out of reach or sealed to the brush above it.
//
// THE GATE: zero perches, except families written into lint_tod_perches.baseline.json
// with a reason. The baseline may only shrink.
//
// WHAT IT CANNOT SEE
//   * SCRIPT-SPAWNED COLLISION (the stock zm_collision_perks1 boxes under the perk
//     machines, the altars, the uplink, the PaPs) and SCRIPT BRUSHMODELS (doors, gates,
//     the rocket clips): a .map parse of worldspawn is static. The generator caps those
//     at their FIXED anchors (the PERCH CAPS block lists every one); this tool checks
//     the brushes, not the script.
//   * DROPS from a higher floor onto a ledge below it. Every place this map lets a
//     player stand above a ledge (stairs, galleries, the causeway) is railed and capped.
//   * The exact wall-run envelope. REACH_V / REACH_H are generous on purpose; a surface
//     beyond them is assumed unreachable, and that is the assumption to revisit if a
//     tester ever finds a perch this tool calls clear.
//
// Usage:  node tools/lint_tod_perches.js            check against the baseline
//         node tools/lint_tod_perches.js --update   accept current as baseline
//         node tools/lint_tod_perches.js --verbose  every perch, with coordinates
//         node tools/lint_tod_perches.js --near X,Y,Z[,R]   only perches within R (256) of a point
//         node tools/lint_tod_perches.js some.map   lint a candidate file instead
//         node tools/lint_tod_perches_selftest.js   prove it still catches a perch
'use strict';
const fs = require('fs');
const path = require('path');
const PC = require('./perch_core');

const REPO = path.join(__dirname, '..');
const ARGS = process.argv.slice(2);
const ARG_MAP = ARGS.find(a => !a.startsWith('--') && /\.map$/i.test(a));
const MAP = ARG_MAP || path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map');
const BASELINE = path.join(__dirname, 'lint_tod_perches.baseline.json');
const ARG_UPDATE = ARGS.includes('--update');
const ARG_VERBOSE = ARGS.includes('--verbose');
const NEAR = (() => { const i = ARGS.indexOf('--near'); if (i < 0) return null; const v = ARGS[i + 1].split(',').map(Number); return { p: v.slice(0, 3), r: v[3] || 256 }; })();

function run() {
  const raw = PC.parseMapWorld(fs.readFileSync(MAP, 'utf8'));
  const { brushes, perches, params: P } = PC.analyze(raw, NEAR ? { near: NEAR } : {});

  const fam = l => l.replace(/\d+/g, '#');
  const byFam = new Map();
  for (const p of perches) {
    const k = fam(p.label);
    if (!byFam.has(k)) byFam.set(k, { fam: k, brushes: 0, samples: 0, minDz: Infinity, ex: p });
    const e = byFam.get(k);
    e.brushes++; e.samples += p.n;
    if (p.dz < e.minDz) { e.minDz = p.dz; e.ex = p; }
  }
  const fams = [...byFam.values()].sort((a, b) => a.minDz - b.minDz);
  console.log('perch lint — standable tops the horde cannot walk onto or swing at, within athlete reach');
  console.log(`  envelope: ${P.STEP_MAX + 1}..${P.REACH_V} up from a floor, within ${P.REACH_H} across, nothing in the way;` +
              ` crouch headroom ${P.HEAD}; melee ${P.ZM_MELEE}`);
  console.log(`  brushes ${brushes.length}, perch faces ${perches.length} in ${fams.length} families`);
  for (const e of fams) {
    console.log(`    ${String(e.brushes).padStart(4)} x  ${e.fam.padEnd(52)} lowest ${Math.round(e.minDz)} up   e.g. (${Math.round(e.ex.x)}, ${Math.round(e.ex.y)}, ${Math.round(e.ex.z)})`);
    if (ARG_VERBOSE) for (const p of perches.filter(q => fam(q.label) === e.fam))
      console.log(`           ${p.label}  (${Math.round(p.x)}, ${Math.round(p.y)}, ${Math.round(p.z)})  ${Math.round(p.dz)} up, ${Math.round(p.d)} across from (${p.f.map(Math.round)}), ${p.n} samples`);
  }

  const summary = {};
  for (const e of fams) summary[e.fam] = e.brushes;
  if (ARG_UPDATE) {
    const old = fs.existsSync(BASELINE) ? JSON.parse(fs.readFileSync(BASELINE, 'utf8')) : {};
    fs.writeFileSync(BASELINE, JSON.stringify({ why: old.why || {}, families: summary }, null, 2) + '\n');
    console.log(`\n  baseline written -> ${path.basename(BASELINE)} (every family needs a reason in "why")`);
    return 0;
  }
  if (NEAR) return 0;
  const base = fs.existsSync(BASELINE) ? JSON.parse(fs.readFileSync(BASELINE, 'utf8')) : { why: {}, families: {} };
  const worse = [];
  for (const [k, n] of Object.entries(summary)) {
    const was = (base.families || {})[k] || 0;
    if (n > was) worse.push(`${k}: ${was} -> ${n}`);
    else if (!(base.why || {})[k]) worse.push(`${k}: accepted with no written reason in the baseline's "why"`);
  }
  if (worse.length) {
    console.error('\nperch lint FAILED — a perch the generator did not close (or one nobody has explained):');
    for (const w of worse) console.error('  ' + w);
    console.error('  Fix it in gen_tower_map.js (PERCH CAPS / PERCH SEAL), never by editing the baseline.');
    return 1;
  }
  const better = Object.keys(base.families || {}).filter(k => (summary[k] || 0) < base.families[k]);
  console.log(better.length ? `\n  OK — fewer perches than the baseline: ${better.join(', ')}` : '\n  OK — no perches beyond the written exceptions.');
  return 0;
}

process.exit(run());
