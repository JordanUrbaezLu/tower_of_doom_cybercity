// tools/lint_tod_geometry_selftest.js — does the geometry lint still bite?
//
// lint_tod_geometry.js currently reports zero holes and zero misplaced walls
// across the whole map. That is either very good news or a broken lint, and the
// two look identical from the outside. This proves it is the former by breaking
// the map on purpose, three ways, and requiring the lint to catch each one.
//
// It never touches the real .map — every mutation is written to a scratch copy.
//
// Run it whenever lint_tod_geometry.js is edited, and whenever its baseline is
// reset to zero. Usage: node tools/lint_tod_geometry_selftest.js
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO = path.join(__dirname, '..');
const MAP = path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map');
const LINT = path.join(__dirname, 'lint_tod_geometry.js');
const SCRATCH = fs.mkdtempSync(path.join(os.tmpdir(), 'tod-lint-selftest-'));

const src = fs.readFileSync(MAP, 'utf8');

// Split into "// brush N — label" + its body, so a mutation can name what it hits.
function brushBlocks(text) {
  const out = [];
  const re = /^\/\/ brush (\d+) — (.*)$/gm;
  let m, prev = null;
  while ((m = re.exec(text))) {
    if (prev) out.push({ ...prev, end: m.index });
    prev = { label: m[2], start: m.index };
  }
  if (prev) out.push({ ...prev, end: text.indexOf('\n}\n', prev.start) + 3 });
  return out;
}
const blocks = brushBlocks(src);

function run(file) {
  try {
    const out = execFileSync(process.execPath, [LINT, file], { encoding: 'utf8' });
    return { code: 0, out };
  } catch (e) {
    return { code: e.status === undefined ? -1 : e.status, out: (e.stdout || '') + (e.stderr || '') };
  }
}

const cases = [];

// --- 1. PUNCH A HOLE: delete a stretch of causeway rail ---------------------
// The exact defect the road builder is designed to make impossible: a length of
// deck edge with nothing beside it, over 19,000 units of open sky.
{
  const victims = blocks.filter(b => /^causeway rail /.test(b.label)).slice(0, 6);
  if (victims.length < 6) throw new Error('self-test: expected causeway rails to delete');
  let text = src;
  for (const v of [...victims].reverse()) text = text.slice(0, v.start) + text.slice(v.end);
  const f = path.join(SCRATCH, 'hole.map');
  fs.writeFileSync(f, text);
  cases.push({ name: 'HOLE — 6 causeway rails deleted', file: f, expect: /unguarded edges   [1-9]/ });
}

// --- 2. MISPLACE A WALL: drop an invisible clip onto the road --------------
// The lap-1 "rail cap E" bug, reproduced: a clip brush standing on a walkable
// deck with no visible solid to account for it. Invisible in game, and the only
// reason it was ever found the first time was three players complaining.
{
  // v12: 'causeway C spine' became THE NARROWS; the equivalent on-axis flat
  // deck at TOP2 is the narrows' south throat. Same probe, new victim.
  const deck = blocks.find(b => b.label === 'causeway N throat south');
  if (!deck) throw new Error('self-test: causeway N throat south not found');
  // READ THE SPINE'S REAL BOUNDS. The probe used to hardcode x[-40,40]
  // y[3700,3760] — the spine's CM=+1 position. At CM=-1 the crown mirrors and
  // the spine is at negative y, so the probe landed in open sky, nothing
  // reported it, and the self-test declared the misplaced-wall check broken
  // when only the probe was. That check guards the exact defect the user named,
  // and this is the only thing that proves it still bites.
  const body = src.slice(deck.start, deck.end);
  const nums = [...body.matchAll(/\( (\S+) (\S+) (\S+) \)/g)].map(m => m.slice(1).map(Number));
  const zTop = Math.max(...nums.map(v => v[2]));
  // The spine brush's own x/y extent, taken from its axis-aligned planes the
  // same way the lint does: a plane is the axis that is constant across its
  // three vertices.
  const planes = [];
  for (let i = 0; i < nums.length; i += 3)
    for (let a = 0; a < 3; a++)
      if (nums[i][a] === nums[i + 1][a] && nums[i + 1][a] === nums[i + 2][a]) planes.push([a, nums[i][a]]);
  const xs = planes.filter(p => p[0] === 0).map(p => p[1]);
  const ys = planes.filter(p => p[0] === 1).map(p => p[1]);
  const cx = (Math.min(...xs) + Math.max(...xs)) / 2;
  const cy = (Math.min(...ys) + Math.max(...ys)) / 2;
  // A 40-unit-tall clip sitting on the spine's deck: too tall to step over.
  const t = 'clip 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';
  const bad = [
    '// brush 99998 — SELFTEST misplaced wall',
    '{',
    ' guid "{7D0DB000-70D0-4E0A-8A3F-0000000FFFF1}"',
    ` ( 134.5 459.5 ${zTop} ) ( 86.5 459.5 ${zTop} ) ( 86.5 419.5 ${zTop} ) ${t}`,
    ` ( 94.5 419.5 ${zTop + 40} ) ( 94.5 459.5 ${zTop + 40} ) ( 142.5 459.5 ${zTop + 40} ) ${t}`,
    ` ( 86.5 ${cy - 30} 88 ) ( 134.5 ${cy - 30} 88 ) ( 134.5 ${cy - 30} 0 ) ${t}`,
    ` ( ${cx + 40} 415.5 88 ) ( ${cx + 40} 455.5 88 ) ( ${cx + 40} 455.5 0 ) ${t}`,
    ` ( 138.5 ${cy + 30} 88 ) ( 90.5 ${cy + 30} 88 ) ( 90.5 ${cy + 30} 0 ) ${t}`,
    ` ( ${cx - 40} 459.5 88 ) ( ${cx - 40} 419.5 88 ) ( ${cx - 40} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
  const f = path.join(SCRATCH, 'wall.map');
  fs.writeFileSync(f, src.slice(0, deck.start) + bad + '\n' + src.slice(deck.start));
  cases.push({ name: 'MISPLACED WALL — invisible clip on the spine', file: f, expect: /misplaced walls   [1-9]/ });
}

// --- 3. SEVER THE ROAD: delete a whole flat piece --------------------------
// Reachability, which is the check that says the finale is completable at all.
{
  // v12: every route still crosses THE NARROWS, so deleting its south throat
  // (the spine's successor) leaves a 160-unit gap the flood cannot cross.
  const victims = blocks.filter(b => b.label === 'causeway N throat south' ||
                                     b.label === 'causeway N throat south under-glow');
  if (!victims.length) throw new Error('self-test: causeway N throat south not found');
  let text = src;
  for (const v of [...victims].reverse()) text = text.slice(0, v.start) + text.slice(v.end);
  const f = path.join(SCRATCH, 'severed.map');
  fs.writeFileSync(f, text);
  cases.push({ name: 'SEVERED — the narrows throat deleted', file: f, expect: /walkable: NO/ });
}

// --- 3b. SEVER THE CLIMB: delete lap 1 ------------------------------------
// The base arena has exactly one way out — lap 1. Deleting it amputates the
// climb while leaving the finale road untouched, so the two headline routes
// must disagree: base -> terrace NO, terrace -> citadel YES.
//
// This case exists because a reviewer ran exactly this experiment and got
// "base -> terrace: YES" on the amputated map. The anchors were resolving to
// the FIRST standable floor in their column, and the terrace's column also
// contains the base arena slab 19,392 units below it — so the check was
// comparing a ground-slab node against a flood rooted on a ground-slab node,
// and could not print NO. Both headline lines were tautologies and the
// "climb is modelled" case below was asserting on one of them.
{
  const victims = blocks.filter(b => /^lap1 /.test(b.label));
  if (!victims.length) throw new Error('self-test: no lap1 brushes found');
  let text = src;
  for (const v of [...victims].reverse()) text = text.slice(0, v.start) + text.slice(v.end);
  const f = path.join(SCRATCH, 'noclimb.map');
  fs.writeFileSync(f, text);
  cases.push({ name: 'SEVERED CLIMB — lap 1 deleted', file: f,
               expect: /base -> terrace walkable:    NO/ });
  cases.push({ name: 'SEVERED CLIMB — the ROAD is still reported fine', file: f,
               expect: /terrace -> citadel walkable: YES/ });
}

// --- 4. THE STACKED-FLOOR MODEL still works --------------------------------
// A regression guard for a real bug (2026-08-23). The lint originally stored
// ONE floor height per (x,y) column — the highest — which is fine for a field
// and useless for a 50-storey tower: at almost any (x,y) the spiral passes
// overhead a dozen times, so the base arena floor was overwritten by a stair
// tread 19,000 units above it. Only 261 of 1047 arena columns survived and the
// climb read as SEVERED on a map a human had demonstrably walked end to end.
//
// The causeway numbers were RIGHT throughout, because nothing walkable sits
// above the causeway — which is exactly the accident that lets a broken tool
// look correct. Two assertions, either of which would have caught it:
cases.push({ name: 'STACKED FLOORS — the climb is modelled', file: MAP,
             expectOut: /base -> terrace walkable:    YES/ });
// AND the control must be walkable end to end, or case 3 above proves nothing:
// it asserts "walkable: NO" after deleting the spine, and if the UNMODIFIED map
// already printed NO — which is what the CM=-1 anchor bug did — that case would
// have reported PASS whether or not anything was ever deleted. A test that
// cannot distinguish the broken case from the healthy one is not a test.
cases.push({ name: 'NON-VACUOUS — the control road is walkable', file: MAP,
             expectOut: /terrace -> citadel walkable: YES/ });
cases.push({ name: 'STACKED FLOORS — columns carry multiple floors', file: MAP,
             // ~65k floor surfaces over ~18k columns. Anywhere near 1:1 means
             // the stacking has collapsed back to one-floor-per-column.
             expectOut: /floor surfaces    (2[5-9]|[3-9])\d{4}/ });

// --- 5. CONTROL: the real map must still pass ------------------------------
cases.push({ name: 'CONTROL — the shipping map', file: MAP, expectPass: true });

let bad = 0;
for (const c of cases) {
  const r = run(c.file);
  if (c.expectOut) {
    const ok = c.expectOut.test(r.out);
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${c.name} — ${ok ? 'held' : 'DID NOT HOLD'}`);
    if (!ok) { bad++; console.log(r.out.split('\n').map(l => '        ' + l).join('\n')); }
    continue;
  }
  if (c.expectPass) {
    const ok = r.code === 0;
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${c.name} — lint exit ${r.code}, expected 0`);
    if (!ok) { bad++; console.log(r.out.split('\n').map(l => '        ' + l).join('\n')); }
    continue;
  }
  const caught = c.expect.test(r.out);
  console.log(`${caught ? 'PASS' : 'FAIL'}  ${c.name} — lint ${caught ? 'caught it' : 'DID NOT CATCH IT'}`);
  if (!caught) { bad++; console.log(r.out.split('\n').map(l => '        ' + l).join('\n')); }
}

fs.rmSync(SCRATCH, { recursive: true, force: true });

// --- 6. THE OTHER PARITY FRAME --------------------------------------------
// Everything above runs against the map as generated today, which is one of the
// two frames this generator can produce. Delegated to its own tool because it
// has to run the generator; see its header for why it exists.
try {
  const pout = execFileSync(process.execPath, [path.join(__dirname, 'lint_tod_geometry_parity.js')], { encoding: 'utf8' });
  console.log('PASS  PARITY — road and lint both hold at CM=-1');
} catch (e) {
  bad++;
  console.log('FAIL  PARITY — CM=-1 check did not pass');
  console.log(((e.stdout || '') + (e.stderr || '')).split('\n').map(l => '        ' + l).join('\n'));
}
if (bad) {
  console.error(`\nself-test FAILED: ${bad} case(s). lint_tod_geometry.js is not detecting what it claims to.`);
  process.exit(1);
}
console.log('\nself-test OK — the lint catches holes, misplaced walls and a severed road,');
console.log('and still passes the shipping map. Its zero is a real zero.');
