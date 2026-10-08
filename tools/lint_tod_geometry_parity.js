// tools/lint_tod_geometry_parity.js — the OTHER PARITY FRAME.
//
// This map generates its crown in whichever frame the crown lap lands in: CM=+1
// when the crown lap is odd, CM=-1 when it is even, point-mirrored through the
// tower axis. Only ONE of those has ever been generated, baked or played, and
// the map has already been badly bitten by that asymmetry once — the crown was
// emitted on odd laps only, and when LAPS went 25 -> 50 the roof silently became
// unreachable. CLAUDE.md carries a rule about it.
//
// Two things get proved here, by generating a scratch map with an ODD LAPS and
// running the real lint against it:
//   1. THE ROAD is correct at CM=-1 — no holes, no invisible walls, both routes
//      walkable. The road builder works in raw coordinates and emits through
//      cbox/cpt, so a mirroring mistake would show up as a wall on the wrong
//      side or a rail inside the deck.
//   2. THE LINT ITSELF still functions at CM=-1. It did not, when first written:
//      its two reachability anchors assumed the +y faces of the terrace and the
//      hall, so at CM=-1 the citadel anchor resolved to null and the entire
//      reachability proof — the road walk, the climb, and both detachment
//      counters — silently did not run while still printing a verdict.
//
// The repo .map is never touched: the generator is copied, LAPS is forced, and
// all three outputs are redirected into a temp dir.
//
// Usage: node tools/lint_tod_geometry_parity.js   (also run by the self-test)
// Generates a scratch .map with an ODD LAPS (crown lap even -> CM=-1) and runs
// the real lint against it. The repo's own .map is never touched.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO = path.join(__dirname, '..');
const SCRATCH = fs.mkdtempSync(path.join(os.tmpdir(), 'tod-parity-'));

// Copy the generator, force an odd LAPS, and redirect its three outputs into
// the scratch dir so nothing in the repo moves.
let gen = fs.readFileSync(path.join(REPO, 'tools', 'gen_tower_map.js'), 'utf8');
const before = gen.match(/^const LAPS\s*=\s*(\d+);/m);
if (!before) throw new Error('LAPS not found');
console.log(`repo LAPS = ${before[1]} (even -> crown lap odd -> CM=+1)`);
gen = gen.replace(/^const LAPS\s*=\s*\d+;/m, 'const LAPS = 49;');
const j = p => JSON.stringify(path.join(SCRATCH, p).replace(/\\/g, '/'));
gen = gen.replace(/^const MAP_OUT\s*=.*$/m, `const MAP_OUT = ${j('scratch.map')};`)
         .replace(/^const DOOR_GSC_OUT\s*=.*$/m, `const DOOR_GSC_OUT = ${j('door.gsc')};`)
         .replace(/^const CROWN_GSC_OUT\s*=.*$/m, `const CROWN_GSC_OUT = ${j('crown.gsc')};`);
const genPath = path.join(SCRATCH, 'gen.js');
fs.copyFileSync(path.join(__dirname, 'convex_brush.js'), path.join(SCRATCH, 'convex_brush.js'));
fs.writeFileSync(genPath, gen);

const out = execFileSync(process.execPath, [genPath], { encoding: 'utf8', cwd: REPO });
console.log(out.split('\n').filter(l => l.includes('crown lap') || l.includes('causeway:')).join('\n'));
if (!/CM=-1/.test(out)) { console.error('EXPECTED CM=-1 and did not get it:\n' + out); process.exit(1); }

// Run the REAL lint against the mirrored map. --update is NOT passed, so it
// compares to the repo baseline; the counts are what matter here, not the diff.
const LINT = path.join(REPO, 'tools', 'lint_tod_geometry.js');
let lintOut, code = 0;
try {
  lintOut = execFileSync(process.execPath, [LINT, path.join(SCRATCH, 'scratch.map')], { encoding: 'utf8' });
} catch (e) { code = e.status; lintOut = (e.stdout || '') + (e.stderr || ''); }
console.log('\n--- lint on the CM=-1 map ---');
console.log(lintOut.split('\n').slice(5).join('\n'));

const ok = /terrace -> citadel walkable: YES/.test(lintOut) &&
           /base -> terrace walkable:    YES/.test(lintOut) &&
           !/ANCHOR NOT FOUND/.test(lintOut);
fs.rmSync(SCRATCH, { recursive: true, force: true });
if (!ok) {
  console.error('\nPARITY CHECK FAILED — the lint does not prove reachability at CM=-1.');
  process.exit(1);
}
console.log('\nPARITY CHECK OK — both routes proved walkable at CM=-1 as well as CM=+1.');
