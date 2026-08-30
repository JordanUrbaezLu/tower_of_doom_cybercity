// tools/lint_tod_geometry.js — the HOLES AND MISPLACED WALLS gate.
//
// WHY THIS EXISTS
// ---------------
// user 2026-08-23, on expanding the finale road: "Keep adding geometry, one
// thing to be carefull of are holes and miss placed walls."
//
// Both failures are silent. A hole is a gap in a rail over 19,000 units of open
// sky — nothing reports it, the map builds, bakes and boots, and the first
// anyone hears is a player falling. A misplaced wall is worse, because it is
// invisible: this map shipped one for weeks (the lap-1 "rail cap E" starting at
// knee height ON the arena floor instead of on top of the rail) and it was
// reported three separate times as "there's an invisible barrier somewhere" and
// hunted by eye before it was found.
//
// gen_tower_map.js's road builder already refuses to emit a road with either
// defect — it declares deck as grid cells and DERIVES the rails, so a hole
// would have to be a hole in the cell list. But a builder that checks itself
// proves nothing about a bug in the builder. This tool parses the FINISHED .map
// from scratch, knows nothing about the cell list, and re-proves the same
// properties from the brushes that actually shipped.
//
// WHAT IT PROVES
//
//   1. NO MISPLACED WALL   no INVISIBLE blocker intrudes into the volume a
//                          player stands in, anywhere a player can stand.
//   2. NO UNGUARDED EDGE   every standing surface whose neighbour is not floor
//                          has something chest-high beside it.
//   3. REACHABILITY        two named routes stay walkable: base arena -> terrace
//                          (the climb every player makes) and terrace -> citadel
//                          (the finale road). Plus a detachment count, gated on
//                          increase, for everything else.
//
// WHAT IT CANNOT SEE — and this matters more than what it can:
//
//   * SCRIPT-SPAWNED COLLISION. A .map parse is static. The 52 door slabs, the
//     causeway gate while shut, the perk machines after they scatter, and every
//     runtime DisconnectPaths() are invisible to it. Blockers are taken from
//     WORLDSPAWN ONLY, so door slabs (which are entities) drop out and what gets
//     proved is the ALL-DOORS-BOUGHT world — which is the state worth proving,
//     but it is not the only state the game has.
//   * ANYTHING A PREFAB BRINGS. Prefab collision is not in this file.
//   * WHETHER THE NAVMESH AGREES. Zombies path on the navmesh, not on this.
//   * A GAP NARROWER THAN THE SAMPLING GRID, in geometry not aligned to it.
//     Columns snap DOWN, so coverage is over-reported by up to G-1 units — the
//     one direction that can HIDE a hole rather than invent one. The CAUSEWAY is
//     exact (the road builder asserts every coordinate is a multiple of ROAD_G,
//     which is this G); the TOWER is not, and is the half this tool is weakest
//     on. Every run prints which is which, so the limit and the pass are read in
//     the same breath. Details in the note above the snap helper in run().
//
// IF THIS TOOL GOES RED ON A MAP SOMEBODY HAS WALKED, SUSPECT THIS TOOL.
// Twice on the day it was written, a new check failed on known-good geometry
// and both times the check was wrong, not the map (see the stacked-floor note
// in run() and the stepsTo comment). A human having completed the route is
// stronger evidence than a static sampler, and "fixing" the map to satisfy an
// unproven check would be the actual regression. Reach for
// lint_tod_geometry_selftest.js and a probe before reaching for the generator.
// The one thing never to do is edit the baseline to make it green.
//
//   So a PASS means "no static hole and no static invisible wall". It does not
//   mean "the map is fine", and it is not a substitute for walking it.
//
// Usage:  node tools/lint_tod_geometry.js            check against the baseline
//         node tools/lint_tod_geometry.js --update   accept current as baseline
//         node tools/lint_tod_geometry.js --crown    narrow to the finale road
//         node tools/lint_tod_geometry.js --verbose  every finding, with coordinates
//         node tools/lint_tod_geometry.js some.map   lint a candidate file instead
//         node tools/lint_tod_geometry_selftest.js   prove it still catches a hole
'use strict';
const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..');
const ARG_MAP = process.argv.slice(2).find(a => !a.startsWith('--'));
const MAP = ARG_MAP || path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map');
const BASELINE = path.join(__dirname, 'lint_tod_geometry.baseline.json');

const ARG_UPDATE = process.argv.includes('--update');
// WHOLE MAP BY DEFAULT. It was crown-only at first, on the assumption that
// linting 50 laps of spiral would drown the signal — it does not. --crown
// narrows to the finale road when that is the only thing being changed.
const ARG_ALL = !process.argv.includes('--crown');
const ARG_VERBOSE = process.argv.includes('--verbose');

// --- movement constants (mirrored from gen_tower_map.js) ---------------------
const G = 20;              // sampling grid; matches the generator's ROAD_G/PARA
const STEP_MAX = 18;       // BO3 walks up to this without a jump
const STAND_LO = 2;        // a player's shins, above the floor
const STAND_HI = 70;       // a player's head. Solid in here means you cannot stand.
const GUARD_LO = 4;        // a guard must start at or below this...
const GUARD_HI = 52;       // ...and reach at least this, or it will not stop a body

// ---------------------------------------------------------------------------
// MATERIAL TAXONOMY — the whole lint rests on this table.
// ---------------------------------------------------------------------------
// Peer review (2026-08-23) got this right and it is worth restating: do NOT
// infer "floor" from shape. This map deliberately puts invisible clip on top of
// every rail so the tops are not standable (RAIL_CAP_H). A sampler that treats
// any horizontal surface as floor finds every rail top as floor, then finds the
// intentional cap above it, and reports the map's most carefully designed
// feature as the invisible-barrier bug.
//
// So: an explicit table, and an UNKNOWN MATERIAL IS A HARD FAILURE. A new
// material silently defaulting to "not a blocker" is how a lint quietly stops
// working six versions after the person who wrote it stopped looking.
//
// Every entry was derived by mapping each material back to the brush LABELS that
// use it in the generated .map, not by reading the generator's MAT table and
// guessing — several materials serve two purposes and only the labels say which.
const DECK = 'deck', BLOCK = 'block';
const PAL = ['blue', 'cyan', 'green', 'orange', 'pink', 'purple', 'red', 'yellow'];
const MATERIALS = new Map([
  // dark_blue_tinted: ground slab, crown hall floor, power hall floor, and the
  // ziggurat tiers under the hall.
  ['mwiii_vertigo_retro_synth_dark_blue_tinted', DECK],
  ['clip', BLOCK],   // rail caps, base clip, doorway clips
  // clip_player: player-only clip. The stair ramps use it as WEDGES (non-AABB,
  // never parsed here); v13 adds the first AXIAL uses — the breather-lounge
  // WINDOW guards, which fill the open window band so players stay inside
  // while bullets pass. BLOCK is the honest class: for every check in this
  // file (guards, walls, standability) a player-clip stops a body exactly
  // like a solid does. Note CHECK 1's misplaced-wall test matches `clip`
  // EXACTLY, not this — a stray clip_player on a floor would not be flagged;
  // don't use clip_player where plain clip serves.
  ['clip_player', BLOCK],
  ['sky', BLOCK],
  // pap: the core capital band and the mast tiers. Nothing STANDS on either, so
  // not floor — but both are solid, and the capital band is the tower core
  // itself. Calling it "decoration" cost 51 false unguarded edges along the
  // terrace's south lip, where the thing guarding you is the core you are
  // standing on. THERE IS NO NON-SOLID WORLDSPAWN BRUSH in this map: triggers
  // and volumes are entities and never reach this parser. If a genuinely
  // non-solid worldspawn material ever appears, give it a class deliberately.
  ['mwiii_vertigo_retro_synth_pap', BLOCK],
  // white: the CIRCLET's ermine rim (v11, gen_tower_map.js section 5f.3) — the
  // fur roll at the bottom of the crown's band, and the widest, brightest line
  // in the whole silhouette from the base arena. BLOCK, deliberately: it is a
  // 256-tall ring hanging 19,000 units in the air with nothing on top of it and
  // no way to reach it, so classing it DECK would invent ~800 unguarded edges
  // out of pure decoration. This is the ONLY plain colour outside the PAL loop
  // below, because the vertigo pack has no `white_tinted` / `white_tinted_edge`
  // (verified against emox_mwiii_vertigo_assets.gdt, 30 materials, 2026-08-25).
  ['mwiii_vertigo_retro_synth_white', BLOCK],
  // dark_white: the CIRCLET's ermine spots (v11.2, gen_tower_map.js section
  // 5f.10). Heraldic ermine is white with dark tails, and this pack has exactly
  // two materials darker than the velvet — `dark_white` (a neutral 0.188 grey,
  // measured value 2.8) and `off` (scaleRGB 0, pure black). `dark_white` is the
  // one chosen: against the ermine's 13.1 it is a 4.7:1 contrast, which reads as
  // a dark MATERIAL, where pure black on a night skybox reads as a hole punched
  // through the crown. BLOCK for the same reason `white` above is: these are
  // 224-tall studs on a ring 19,000 units in the air that nothing can reach.
  ['mwiii_vertigo_retro_synth_dark_white', BLOCK],
]);

// Clip brushes that are DELIBERATELY invisible blockers, matched by brush label.
// Read the long note at CHECK 1 before adding to this list. Every entry marks a
// place where a VISIBLE, script-spawned model has no collision of its own and a
// clip brush stands in for it — which this lint cannot see, because it parses
// brushes only.
//   `ammo crate body` — the four breather ammo crates (2026-08-24) plus the
//   crown hall crate (v12, 2026-08-26; label `crown hall ammo crate body`). The model is
//   acc_west_ammo_crate, which ships CollisionMap "" and BulletCollisionFile "",
//   so Solid() has nothing to switch on. A SOLID brush was tried first and was
//   worse in both directions: it showed through the mesh, and it swallowed the
//   crate's trigger_radius_use origin so the crate could not be bought at all.
const MODEL_CLIP_COLUMNS = /ammo crate body$/;
// PALETTE FAMILIES. The suffix carries the meaning:
//   <colour>              plain  -> parapets, rails, base walls, door slabs. BLOCK.
//   <colour>_tinted       -> stair treads, and the core's decorative band rings.
//   <colour>_tinted_edge  -> landings, breather floors, the terrace, the causeway
//                            deck, the extraction pad, the pylon plinths.
for (const c of PAL) {
  MATERIALS.set(`mwiii_vertigo_retro_synth_${c}`, BLOCK);
  MATERIALS.set(`mwiii_vertigo_retro_synth_${c}_tinted`, DECK);
  MATERIALS.set(`mwiii_vertigo_retro_synth_${c}_tinted_edge`, DECK);
}
// DECK AND BLOCK ARE NOT EXCLUSIVE. A solid brush BLOCKS along its whole body
// whatever its material; the material only decides whether its TOP FACE is also
// somewhere you can stand. Treating them as exclusive made the whole-map pass
// report 96 unguarded edges along the inner rail of lap 50's flights — the edge
// facing the tower's own core column, which is about as guarded as a thing can
// be. The core is built from a floor-class material, so under the old model it
// counted as neither floor (too thick for a slab) nor wall (wrong class) and
// simply vanished.
//
// The thickness test still earns its keep: it stops the core's band rings and
// the pylon plinths from offering standing room at their tops. A brush it
// rejects is no longer discarded, it is just a wall.
const MAX_SLAB = 64;

// A blocker only counts as a WALL if you cannot step onto it. Anything whose top
// is within a stride of the floor is a STAIR, and this map is made of stairs —
// without this every tread would report the tread above it as a wall across the
// player's shins, which is what a staircase is.
const isStep = (b, floorZ) => b.hi[2] <= floorZ + STEP_MAX;

// ---------------------------------------------------------------------------
// Parse the worldspawn brushes.
// ---------------------------------------------------------------------------
// Every brush in this file is written by gen_tower_map.js's box(), so every one
// is an axis-aligned box on a fixed 6-plane family. Rather than trusting the
// PLANE ORDER, each plane is read for whichever of x/y/z is constant across its
// three vertices — that is the axis it bounds. Order-independent, so a future
// change to the plane family cannot silently produce garbage boxes.
function parseWorld(text) {
  const endMarker = text.indexOf('// entity 1 ');
  const world = endMarker >= 0 ? text.slice(0, endMarker) : text;
  const lines = world.split(/\r?\n/);
  const brushes = [];
  const unknown = new Map();
  let label = null;

  for (let i = 0; i < lines.length; i++) {
    const lm = lines[i].match(/^\/\/ brush \d+ — (.*)$/);
    if (lm) { label = lm[1]; continue; }
    if (lines[i] !== '{' || label === null) continue;

    const planes = [];
    let mat = null;
    for (let j = i + 1; j < lines.length && lines[j] !== '}'; j++) {
      const pm = lines[j].match(
        /^ \( (\S+) (\S+) (\S+) \) \( (\S+) (\S+) (\S+) \) \( (\S+) (\S+) (\S+) \) (\S+) /);
      if (!pm) continue;
      const v = pm.slice(1, 10).map(Number);
      mat = pm[10];
      const verts = [[v[0], v[1], v[2]], [v[3], v[4], v[5]], [v[6], v[7], v[8]]];
      for (let a = 0; a < 3; a++)
        if (verts[0][a] === verts[1][a] && verts[1][a] === verts[2][a])
          planes.push([a, verts[0][a]]);
    }
    if (planes.length !== 6 || !mat) { label = null; continue; }

    const b = { label, mat, lo: [Infinity, Infinity, Infinity], hi: [-Infinity, -Infinity, -Infinity] };
    for (const [axis, val] of planes) {
      if (val < b.lo[axis]) b.lo[axis] = val;
      if (val > b.hi[axis]) b.hi[axis] = val;
    }
    const kind = MATERIALS.get(mat);
    if (kind === undefined) unknown.set(mat, (unknown.get(mat) || 0) + 1);
    b.kind = kind;
    b.isDeck = kind === DECK && (b.hi[2] - b.lo[2]) <= MAX_SLAB;
    b.isBlock = true;             // everything in worldspawn is solid
    brushes.push(b);
    label = null;
  }
  return { brushes, unknown };
}

// ---------------------------------------------------------------------------
function run() {
  const { brushes, unknown } = parseWorld(fs.readFileSync(MAP, 'utf8'));

  if (unknown.size) {
    console.error('geometry lint ABORTED — unclassified material(s):');
    for (const [m, n] of unknown) console.error(`  ${m}  (${n} faces)`);
    console.error('\nAdd each to MATERIALS in this file as deck/block. Refusing to guess:');
    console.error('a material defaulting to "not a blocker" would make every check below');
    console.error('quietly optimistic.');
    process.exit(1);
  }

  const road = brushes.filter(b => b.label.startsWith('causeway'));
  if (!road.length) { console.error('geometry lint: no causeway brushes found'); process.exit(1); }
  const rx1 = Math.min(...road.map(b => b.lo[0])) - 256;
  const rx2 = Math.max(...road.map(b => b.hi[0])) + 256;
  const ry1 = Math.min(...road.map(b => b.lo[1])) - 256;
  const ry2 = Math.max(...road.map(b => b.hi[1])) + 256;
  const rz1 = Math.min(...road.map(b => b.lo[2])) - 256;
  const rz2 = Math.max(...road.map(b => b.hi[2])) + 256;
  // A BRUSH is kept if it overlaps the region at all — a wall half in and half
  // out still guards the half that is in. A COLUMN is only ANALYSED if it is
  // inside. These are different tests, and conflating them was a real bug: the
  // 1536-deep crown hall floor came in whole while the wall guarding its far
  // side sat 1200 units outside the region and was dropped, so the lint reported
  // the hall's entire north edge as an unguarded 19,000-unit drop that is in
  // fact a wall. Analyse only what the region covers, or it invents holes at its
  // own boundary.
  const inRegion = b => ARG_ALL || (b.hi[0] > rx1 && b.lo[0] < rx2 && b.hi[1] > ry1 &&
                                    b.lo[1] < ry2 && b.hi[2] > rz1 && b.lo[2] < rz2);
  const inCol = (gx, gy) => ARG_ALL || (gx >= rx1 && gx < rx2 && gy >= ry1 && gy < ry2);

  // SAMPLING EXACTNESS — how far to trust the two halves of this report.
  //
  // Columns are snapped DOWN, so a brush covering only part of a 20-unit column
  // still marks the whole column. Coverage is over-reported by up to G-1 units,
  // and that is the one direction that can HIDE a hole rather than invent one.
  //
  // On the CAUSEWAY the error is exactly zero, and provably: the road builder
  // asserts every coordinate is a multiple of ROAD_G, and ROAD_G is this G. The
  // road is what this tool was written to check, and there it is exact.
  //
  // On the TOWER it is not. The spiral is built on TREAD 32 / PX 416 / CORE 256,
  // so landing rims fall mid-column. Sampling strictly instead — counting a
  // column as floor only when a slab covers it entirely — was tried and is
  // unusable: 18,326 unguarded edges, essentially every landing rim in the map,
  // because the strict rule drops the very column the rail stands in. A finer
  // grid would fix it properly (the GCD of the tower constants is 4) at 25x the
  // columns and the runtime.
  //
  // So the tower half is APPROXIMATE and could miss a gap narrower than G in
  // non-aligned geometry. That is printed in the report rather than left here,
  // because a caveat nobody sees is a caveat nobody weighs.
  const snap = v => Math.floor(v / G) * G;
  const kkey = (gx, gy) => `${gx},${gy}`;
  const aligned = b => [0, 1].every(a => b.lo[a] % G === 0 && b.hi[a] % G === 0);
  // What matters for sampling is the brushes that ANSWER the questions: floors
  // (is there ground here?) and rails (is this edge guarded?). The road's
  // decorative portal frames sit outside the rails at x +/-(100..124) and are
  // neither, so their being off-grid changes no verdict — but it is called out
  // rather than filtered silently, because "exact" should mean exact.
  const roadFloors = road.filter(b => b.isDeck);
  const roadRails = road.filter(b => !b.isDeck && b.label.startsWith('causeway rail'));
  const roadExact = roadFloors.every(aligned) && roadRails.every(aligned);
  const roadOffGrid = road.filter(b => !aligned(b)).length;
  const offGrid = brushes.filter(b => b.isDeck && inRegion(b) && !aligned(b)).length;

  // ---------------------------------------------------------------------------
  // A COLUMN HAS MANY FLOORS. This is a 50-storey tower: at almost any (x,y) the
  // spiral passes overhead a dozen times, and the base arena sits under all of
  // it. The first cut stored ONE floor per column — the highest — and the result
  // was that the arena floor was overwritten by a stair tread 19,000 units above
  // it. Only 261 of 1047 arena columns survived, the climb read as severed, and
  // the "WHOLE MAP" banner was covering an analysis that had quietly discarded
  // every floor below the top one. The causeway numbers happened to be right,
  // because nothing walkable is above the causeway — which is exactly the kind of
  // accident that lets a broken tool look correct.
  //
  // So a NODE is (column, floor height), and there are as many nodes per column
  // as there are distinct floor surfaces stacked in it.
  // ---------------------------------------------------------------------------
  const blockIdx = new Map();
  for (const b of brushes) {
    if (!b.isBlock || !inRegion(b)) continue;
    for (let x = snap(b.lo[0]); x < b.hi[0]; x += G)
      for (let y = snap(b.lo[1]); y < b.hi[1]; y += G) {
        const k = kkey(x, y);
        if (!blockIdx.has(k)) blockIdx.set(k, []);
        blockIdx.get(k).push(b);
      }
  }
  const floors = new Map();   // column -> Map(z -> label)
  for (const b of brushes) {
    if (!b.isDeck || !inRegion(b)) continue;
    for (let x = snap(b.lo[0]); x < b.hi[0]; x += G)
      for (let y = snap(b.lo[1]); y < b.hi[1]; y += G) {
        if (!inCol(x, y)) continue;
        const k = kkey(x, y);
        if (!floors.has(k)) floors.set(k, new Map());
        const m = floors.get(k);
        if (!m.has(b.hi[2])) m.set(b.hi[2], b.label);
      }
  }

  const nkey = (k, z) => `${k}@${z}`;
  const findings = { walls: [], holes: [], unreachable: 0, unreachableTower: 0,
                     unreachableSpireFromTower: 0, spireDetached: null, spireReachesSummit: null,
                     reachTerraceToCitadel: false, baseReachesTerrace: null, anchorMissing: null };

  // --- CHECK 1: MISPLACED WALLS — INVISIBLE ONES ONLY ---------------------
  // The first cut reported any blocker standing in a walkable column and
  // produced 695 hits, essentially all "crown wall W intrudes on crown hall
  // floor" — a wall built on a floor, which is what a room is. Unusable, and a
  // lint nobody can read is a lint nobody runs.
  //
  // The defect this map actually shipped was specifically INVISIBLE: a clip
  // brush at knee height on the arena floor with no rail under it, hunted by eye
  // across three bug reports because there was nothing to see. A visible wall in
  // an odd place is a design question and the eye is better at it; an invisible
  // one is undetectable by eye and trivial to detect here.
  const stand = new Map();    // node key -> { k, z, label }
  let floorNodes = 0;
  for (const [k, m] of floors) {
    const list = blockIdx.get(k) || [];
    for (const [z, label] of m) {
      floorNodes++;
      const hits = list.filter(b => b.lo[2] < z + STAND_HI && b.hi[2] > z + STAND_LO && !isStep(b, z));
      // INTENTIONAL INVISIBLE CLIP — a clip standing in for a script-spawned
      // model's missing collision. This lint parses BRUSHES ONLY, so it cannot
      // see that something visible is standing in the column; that is a
      // structural blind spot, not a false rule, and the only honest fix is to
      // name the exceptions.
      //
      // THE BAR FOR ADDING ONE IS HIGH. It must be a clip that a player can SEE
      // the reason for — i.e. a visible model occupies the same space — and the
      // model must genuinely have no collision of its own. The ammo crates
      // qualify: acc_west_ammo_crate.gdt ships CollisionMap "" and
      // BulletCollisionFile "", so Solid() has nothing to switch on and a brush
      // is the only way to stop players walking through them.
      //
      // Do NOT add an entry to silence a clip you have not explained. The bug
      // this check caught for real was a knee-height clip on the arena floor
      // with nothing to see, hunted by eye across three bug reports.
      const clip = hits.find(b => b.mat === 'clip' && !MODEL_CLIP_COLUMNS.test(b.label));
      const solid = hits.find(b => b.mat !== 'clip');
      if (clip && !solid) {
        findings.walls.push({ col: k, z, floor: label, wall: clip.label, wallZ: [clip.lo[2], clip.hi[2]] });
        continue;
      }
      if (!solid) stand.set(nkey(k, z), { k, z, label });
    }
  }

  // Is this column guarded against a walk-off from a floor at height z? A guard
  // has to stop a body: start at or below shin height and reach chest height. A
  // 12-unit step in the neighbouring column is not a guard, it is the next stair.
  const guarded = (k, z) => {
    const list = blockIdx.get(k);
    if (!list) return null;
    for (const b of list)
      if (b.lo[2] <= z + GUARD_LO && b.hi[2] >= z + GUARD_HI) return b;
    return null;
  };
  // EVERY floor a walker could step onto in a neighbouring column — not just
  // the nearest. Returning only the nearest was a real bug: where a column
  // stacks two surfaces inside one stride (a tread and the landing it joins),
  // the nearest one may be the blocked one, and the walk would stop dead at a
  // join that is perfectly walkable in game. It cost the terrace -> citadel
  // proof, which failed while the road was demonstrably continuous.
  const DIRS = [[-G, 0], [G, 0], [0, -G], [0, G]];
  const stepsTo = (nk, z) => {
    const m = floors.get(nk);
    if (!m) return [];
    const out = [];
    for (const [nz] of m) if (Math.abs(nz - z) <= STEP_MAX) out.push(nz);
    return out;
  };

  // --- CHECK 2: UNGUARDED EDGES ------------------------------------------
  for (const node of stand.values()) {
    const [gx, gy] = node.k.split(',').map(Number);
    for (const [dx, dy] of DIRS) {
      const nk = kkey(gx + dx, gy + dy);
      if (!inCol(gx + dx, gy + dy)) continue;   // the region ends here, not the floor
      if (stepsTo(nk, node.z).length) continue;               // the floor continues
      if (guarded(nk, node.z)) continue;                      // a rail, a wall, the core
      findings.holes.push({ col: nk, from: node.label, z: node.z });
    }
  }

  // --- CHECK 3: REACHABILITY ---------------------------------------------
  // THE TWO MOUTHS, FOUND IN EITHER PARITY FRAME.
  //
  // The first cut took the terrace's MAX-y lip and the hall floor's MIN-y lip
  // as "the doorstep" and "just inside the citadel". That is only true at
  // CM=+1. The crown is point-mirrored when the crown lap is even, so at CM=-1
  // the hall sits at y[-HN,-HS] and lo[1]+G lands in its far interior, under
  // `crown wall N`. The anchor resolved to null, anchorMissing was set, and
  // EVERYTHING inside `if (from && to)` — the road walk, the climb, and both
  // detachment counters — silently did not run, on a road that was perfectly
  // walkable. A reviewer reproduced it by generating with an odd LAPS.
  //
  // This map has been bitten by parity before, badly enough that CLAUDE.md
  // carries a rule about it: the crown was once emitted only on odd laps and
  // the roof silently became unreachable when LAPS changed. A lint that dies
  // in the frame nobody has played is worse than no lint, because it still
  // prints a verdict.
  //
  // So the anchors are derived from the ROAD, which is already in world frame:
  // take whichever face of the terrace / hall faces the causeway. Correct in
  // both frames, with no reference to CM at all.
  const roadMidY = road.length
    ? road.reduce((a, b) => a + (b.lo[1] + b.hi[1]) / 2, 0) / road.length : 0;
  const anchorNode = (label) => {
    const b = brushes.find(x => x.label === label);
    if (!b) return null;
    // the face nearer the road is the one the road meets
    const faces = Math.abs(b.lo[1] - roadMidY) < Math.abs(b.hi[1] - roadMidY)
      ? [b.lo[1] + G / 2, b.hi[1] - G / 2] : [b.hi[1] - G / 2, b.lo[1] + G / 2];
    for (const ay of faces) {
      const k = kkey(snap(0), snap(ay));
      // THE ANCHOR IS THE BRUSH'S OWN TOP SURFACE, not "the first standable floor
      // in that column". Taking the first made both headline routes tautologies,
      // and it took a reviewer deleting all 52 lap-1 brushes to expose it: a
      // column has many floors (that is the whole point of the model), and the
      // terrace's column ALSO contains the base arena slab at z=0, 19,392 units
      // below it — emitted far earlier, so first in insertion order. So the
      // "terrace" anchor was the arena floor, the "base" anchor was also a
      // ground-slab node, and `base -> terrace` compared a ground-slab node
      // against a flood rooted on a ground-slab node: YES by construction, on a
      // map whose climb had been amputated. Meanwhile `terrace -> citadel` was
      // really arena -> citadel, so a break anywhere in 50 laps reddened the
      // FINALE ROAD line and pointed the reader at the causeway.
      if (stand.has(nkey(k, b.hi[2]))) return nkey(k, b.hi[2]);
    }
    return null;
  };
  const from = anchorNode('terrace');
  const to = anchorNode('crown hall floor');
  // An anchor that cannot be found is a FAILURE, never a skipped check. A lint
  // that quietly stops checking is worse than none, because it still prints a pass.
  if (!from || !to)
    findings.anchorMissing = `terrace=${from ? 'ok' : 'NOT FOUND'} citadel=${to ? 'ok' : 'NOT FOUND'}`;

  if (from && to) {
    const seen = new Set([from]);
    const st = [from];
    while (st.length) {
      const cur = stand.get(st.pop());
      const [gx, gy] = cur.k.split(',').map(Number);
      for (const [dx, dy] of DIRS) {
        const nk = kkey(gx + dx, gy + dy);
        for (const nz of stepsTo(nk, cur.z)) {
          const nn = nkey(nk, nz);
          if (seen.has(nn) || !stand.has(nn)) continue;
          seen.add(nn); st.push(nn);
        }
      }
    }
    findings.reachTerraceToCitadel = seen.has(to);

    // DETACHMENT. Floor a player can never reach is not by itself a safety bug —
    // this map has plenty of legitimately unreachable surfaces (mast tiers, the
    // core roof, the ziggurat under the hall) — but a piece that USED to be
    // reachable and stopped is almost always a step that grew past STEP_MAX or a
    // landing that drifted off its neighbour.
    //
    // Two buckets, because they behave differently (peer review 2026-08-23, and
    // this was a real gap: the count used to be filtered to causeway/terrace
    // labels, so all 50 floors of spiral were sampled for walls and edges but
    // EXCLUDED from the detachment check — a landing adrift at floor 23 passed
    // clean. That matters more now that zombies spawn ON the breather balconies
    // rather than only walking to them).
    //
    //   road  — expected to be ZERO. Every part of the causeway and terrace is
    //           reachable or the finale is broken.
    //   tower — a nonzero BASELINE, gated on increase. The absolute number is
    //           decoration; a rise means something just came adrift.
    for (const node of stand.values()) {
      if (seen.has(nkey(node.k, node.z))) continue;
      if (node.label.startsWith('causeway') || node.label.startsWith('terrace')) findings.unreachable++;
      // v14: the SPIRE is a deliberate island — teleport-only, no walkable
      // route from the tower BY DESIGN, so its nodes must not drown the tower
      // bucket (100 floors ≈ 80k nodes would gate every future edit). It gets
      // its own bucket and its own flood proof below.
      else if (node.label.startsWith('spire')) findings.unreachableSpireFromTower++;
      else findings.unreachableTower++;
    }

    // THE CLIMB. Every player walks it, and with door slabs excluded (entities)
    // this is the all-doors-bought world, so the base arena must connect to the
    // terrace. Free: the flood already spread, so this is a lookup. ANY arena
    // column will do — asking for a specific one is how this first went wrong,
    // since (0,0) is dead centre of the arena, which is where the core stands.
    let base = null;
    for (const node of stand.values())
      if (node.label === 'ground slab') { base = nkey(node.k, node.z); if (seen.has(base)) break; }
    findings.baseReachesTerrace = base ? seen.has(base) : null;
  }

  // --- THE SPIRE ISLAND (v14, docs/44) ------------------------------------
  // Teleport-only by design, so the main flood can never reach it. When spire
  // brushes exist it gets the SAME treatment the tower gets: a flood rooted on
  // its own arrival slab, a named route proof (arena -> summit apron), and a
  // detachment counter gated on increase. No spire in the map = fields stay
  // null and every verdict below is byte-identical to the pre-spire lint.
  if (brushes.some(b => b.label === 'spire ground slab')) {
    let seed = null;
    for (const node of stand.values())
      if (node.label === 'spire ground slab') { seed = nkey(node.k, node.z); break; }
    if (seed) {
      const seenS = new Set([seed]);
      const st2 = [seed];
      while (st2.length) {
        const cur = stand.get(st2.pop());
        const [gx, gy] = cur.k.split(',').map(Number);
        for (const [dx, dy] of DIRS) {
          const nk = kkey(gx + dx, gy + dy);
          for (const nz of stepsTo(nk, cur.z)) {
            const nn = nkey(nk, nz);
            if (seenS.has(nn) || !stand.has(nn)) continue;
            seenS.add(nn); st2.push(nn);
          }
        }
      }
      findings.spireReachesSummit = false;
      findings.spireDetached = 0;
      for (const node of stand.values()) {
        if (!node.label.startsWith('spire')) continue;
        if (node.label === 'spire summit apron' && seenS.has(nkey(node.k, node.z)))
          findings.spireReachesSummit = true;
        if (!seenS.has(nkey(node.k, node.z))) findings.spireDetached++;
      }
    } else {
      findings.spireReachesSummit = false;   // a spire with no standable arrival is broken outright
    }
  }

  // --- report -------------------------------------------------------------
  const summary = {
    floorNodes,
    standableNodes: stand.size,
    misplacedWalls: findings.walls.length,
    unguardedEdges: findings.holes.length,
    unreachableRoadNodes: findings.unreachable,
    unreachableTowerNodes: findings.unreachableTower,
    baseReachesTerrace: findings.baseReachesTerrace,
    terraceReachesCitadel: findings.reachTerraceToCitadel,
    spireDetached: findings.spireDetached,
    spireReachesSummit: findings.spireReachesSummit,
  };

  console.log('geometry lint — STATIC GEOMETRY ONLY');
  console.log('  (worldspawn brushes; script-spawned collision — door slabs, the causeway');
  console.log('   gate while shut, scattered perk machines, every runtime DisconnectPaths —');
  console.log('   is NOT modelled. A pass is not a substitute for walking it.)');
  console.log('');
  console.log(`  region            ${ARG_ALL ? 'WHOLE MAP' : `crown  x[${rx1},${rx2}] y[${ry1},${ry2}] z[${rz1},${rz2}]`}`);
  console.log(`  floor surfaces    ${summary.floorNodes}  (${summary.standableNodes} standable)`);
  console.log(`  sampling          ${G}u grid — causeway floors+rails ${roadExact ? 'EXACT' : 'NOT GRID-ALIGNED (see source)'}` +
              `${roadOffGrid ? ` (${roadOffGrid} decorative road brush(es) off-grid, neither floor nor guard)` : ''};` +
              ` ${offGrid} off-grid floor brush(es) elsewhere sampled APPROXIMATELY`);
  console.log(`  misplaced walls   ${summary.misplacedWalls}`);
  console.log(`  unguarded edges   ${summary.unguardedEdges}`);
  console.log(`  detached: road    ${summary.unreachableRoadNodes}    tower ${summary.unreachableTowerNodes}`);
  // Say plainly which half of this is whole-map. Walls and edges are sampled
  // everywhere; the traversal claims are two named routes and nothing else.
  console.log(`  base -> terrace walkable:    ${summary.baseReachesTerrace === null ? 'ANCHOR MISSING' : (summary.baseReachesTerrace ? 'YES' : 'NO')}`);
  console.log(`  terrace -> citadel walkable: ${summary.terraceReachesCitadel ? 'YES' : 'NO'}`);
  if (summary.spireReachesSummit !== null) {
    console.log(`  spire arena -> summit walkable: ${summary.spireReachesSummit ? 'YES' : 'NO'}`);
    console.log(`  detached: spire   ${summary.spireDetached}    (spire-from-tower ${findings.unreachableSpireFromTower} — teleport-only BY DESIGN, not gated)`);
  }
  if (findings.anchorMissing)
    console.error(`  ANCHOR NOT FOUND — the reachability proof did not run: ${findings.anchorMissing}`);

  const show = (title, rows, fmt) => {
    if (!rows.length) return;
    console.log(`\n  ${title}:`);
    const seen = new Map();
    for (const r of rows) seen.set(fmt(r), (seen.get(fmt(r)) || 0) + 1);
    let n = 0;
    const cap = ARG_VERBOSE ? Infinity : 25;
    for (const [k, c] of seen) {
      if (n++ >= cap) { console.log(`    ... and ${seen.size - cap} more distinct (--verbose for all)`); break; }
      console.log(`    ${k}${c > 1 ? `   (x${c})` : ''}`);
    }
  };
  show('MISPLACED WALLS — invisible solid where a player stands', findings.walls,
       r => `"${r.wall}" [z ${r.wallZ[0]}..${r.wallZ[1]}] intrudes on "${r.floor}" (floor z ${r.z})`);
  show('UNGUARDED EDGES — you can walk off here', findings.holes,
       r => `off "${r.from}" at z ${r.z}` + (ARG_VERBOSE ? `  -> col (${r.col})` : ''));

  // --- baseline diff ------------------------------------------------------
  // The absolute numbers on a 4,000-brush generated map will always carry some
  // legitimate oddities. What is worth gating on is CHANGE: "this rewrite
  // introduced three new holes" is actionable in a way a raw count is not.
  const GATED = ['misplacedWalls', 'unguardedEdges', 'unreachableRoadNodes', 'unreachableTowerNodes'];
  if (ARG_UPDATE) {
    fs.writeFileSync(BASELINE, JSON.stringify(summary, null, 2) + '\n');
    console.log(`\n  baseline written -> ${path.basename(BASELINE)}`);
    return 0;
  }
  if (!fs.existsSync(BASELINE)) {
    console.log('\n  no baseline yet — run with --update once these numbers are understood.');
    return (summary.terraceReachesCitadel && !findings.anchorMissing) ? 0 : 1;
  }
  const base = JSON.parse(fs.readFileSync(BASELINE, 'utf8'));
  const worse = [];
  for (const k of GATED) if (summary[k] > (base[k] || 0)) worse.push(`${k}: ${base[k]} -> ${summary[k]}`);
  // v14: the spire's own gates, active only when spire brushes exist. A map
  // without them keeps null fields and these lines never fire.
  if (summary.spireReachesSummit === false) worse.push('spire arena -> summit is NOT walkable');
  if (summary.spireDetached !== null && summary.spireDetached > (base.spireDetached || 0))
    worse.push(`spireDetached: ${base.spireDetached || 0} -> ${summary.spireDetached}`);
  if (!summary.terraceReachesCitadel) worse.push('terrace -> citadel is NO LONGER walkable');
  if (summary.baseReachesTerrace === false) worse.push('base -> terrace is NO LONGER walkable — the climb is severed');
  if (summary.baseReachesTerrace === null) worse.push('base anchor missing — the climb was not checked');
  if (findings.anchorMissing) worse.push('reachability anchors missing: ' + findings.anchorMissing);
  if (worse.length) {
    console.error('\ngeometry lint FAILED — regression against the baseline:');
    for (const w of worse) console.error('  ' + w);
    return 1;
  }
  const better = GATED.filter(k => summary[k] < (base[k] || 0)).map(k => `${k}: ${base[k]} -> ${summary[k]}`);
  console.log(better.length ? `\n  OK — improved: ${better.join(', ')}` : '\n  OK — no regression against baseline.');
  return 0;
}

process.exit(run());
