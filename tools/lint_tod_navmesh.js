#!/usr/bin/env node
// =============================================================================
// lint_tod_navmesh.js — READ THE NAVMESH cod2map ACTUALLY WROTE and prove the
// towers are ONE connected walk each. Gate, not advisory.
//
// WHY THIS EXISTS (2026-09-04, user: "random spots on the map zombies won't
// attack you ... around floor 42-44 they won't but above and below they will ...
// there are spots where you just can't get targeted").
//
// Zombies do not chase the player. They chase `player.last_valid_position`, the
// player's cached navmesh point (stock player_shared::last_valid_position),
// and they need a PATH to it. Both are navmesh questions, so "won't attack HERE"
// is always "the mesh under HERE is wrong". Every previous pass on this bug
// reasoned about the mesh from the .map, the seeds and the .hkt BYTE SIZE,
// because nothing could read the mesh itself. This tool reads it.
//
// WHAT IT FOUND THE FIRST TIME IT RAN: 18 connected components. The tower was
// cut into horizontal SLABS — z 0..6170, 6228..6938, 7045..12314, 12342..14618,
// 14785..16154, 16321+ — and the spire, 10,000 units away, was cut at the SAME
// heights. Faces exist on every flight (a vertex census is green), but the
// faces on either side of each seam have oppositeFace = -1: the slabs are not
// stitched. Floor 43 (z 16128-16512) sits on the 16154/16321 seam; floor 17 on
// the 6170 one (the v17.7 "no mesh above floor 17" outage was this seam PLUS
// pruning); floors 19, 33 and 39 on the others. A player standing on a seam
// island cannot be reached from either side, and a zombie chasing across a
// seam stops dead.
//
// THE CAUSE (proven by compile + re-read, ~45 s a round): every seam was inside
// the E flight of ODD laps 17/19/33/39/43 — the same laps on both towers, which
// rules out anything spatial and points at per-lap arithmetic. The stair ramp
// wedge's top plane passed EXACTLY through every tread's front-top nosing edge,
// handing Havok a walkable plane with fifteen coplanar contact lines per flight;
// its overlapping-triangle fixup slivers that, and on laps whose plane
// arithmetic (a function of y and z only — hence identical 10,000 units away in
// x) rounds badly, the ramp's faces come out unstitched. Disabling the
// simplifier's height partitioning through a per-map settings override changed
// the face count and left every seam, so that was NOT it. The fix is RAMP_LIFT
// (2) in gen_tower_map.js: the whole wedge sits 2 above the nosings, no tread
// edge touches the plane, and the same mesh re-read as 2 components (tower +
// crown road, spire). This tool is what proved that and keeps proving it on
// every full build (build_map.ps1, right after cod2map).
//
// FILE FORMAT (Havok 2014.2 binary tagfile, reverse-read from the bytes; every
// claim below was validated against the mesh it decoded — a/b < V, oppositeFace
// < F, startEdge[i+1]-startEdge[i] == numEdges[i] for all 1262 faces):
//   * magic CAB00D1E D011FACE; several tagfiles concatenated (settings, user
//     edge pairs, cluster graph, query mediator + hkaiNavMesh).
//   * ints are LEB128 varints with the SIGN IN THE LOW BIT (3 -> -1, 8 -> 4).
//   * an array of structs is [count][member bitfield][per present member:
//     one type varint, then `count` values] — struct-of-arrays.
//   * hkaiNavMesh members in order: faces{startEdgeIndex, startUserEdgeIndex,
//     numEdges, numUserEdges, clusterIndex, padding}, edges{a, b, oppositeEdge,
//     oppositeFace, flags, paddingByte, userEdgeCost}, vertices (hkVector4 =
//     4 float32, IN METRES: game units / 39.3701, plain x,y,z order).
//   The object data follows the LAST type descriptor of the tagfile that
//   declares hkaiNavMesh; we anchor on that and search a short window for the
//   faces array signature (count, bitfield, type 8, ascending run from 0).
//
// USAGE
//   node tools/lint_tod_navmesh.js [path/to/zm_tower_of_doom_navmesh.hkt]
//        [--json out.json] [--verbose] [--no-gate]
//   Default path = the mod tools' share/raw/maps/zm/<map>_navmesh.hkt.
//   Exit 1 when the gate fails (see GATE below). --no-gate = report only.
//
// GATE. Regions are classified by face centroid: TOWER (|x|,|y| < 700, the
// 50-floor spiral incl. the base arena), SPIRE (|x-10240| < 1000), OTHER (the
// crown, causeway, breather spurs, teleport bay). The gate requires:
//   1. every TOWER floor's faces (per-floor z bands of LAP_RISE 384) share ONE
//      component with floor 1 — no slab seams, no islands;
//   2. every SPIRE floor's faces share one component with spire floor 1;
//   3. no island (component) of >= ISLAND_MIN_FACES faces inside either tower.
//   Singleton slivers OUTSIDE the towers are reported, not failed.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const M = 39.3701;                 // Havok metres -> game units
const LAP_RISE = 384;
const TOWER_FLOORS = 50;
// v17.69: the spire's lap count is READ from the generated data (spire_laps()),
// never written here — a literal 100 failed the first 70-lap build on floors
// 72..100 'NO FACES'. No spire data file = no spire = zero floors checked.
const SPIRE_FLOORS = (() => {
  const f = path.join(__dirname, '..', 'scripts', 'zm', 'zm_tower_of_doom', '_tod_spire_data.gsc');
  if (!fs.existsSync(f)) return 0;
  const m = fs.readFileSync(f, 'utf8').match(/function spire_laps\(\)\s*\{\s*return\s+(\d+);/);
  if (!m) throw new Error('lint_tod_navmesh: _tod_spire_data.gsc has no spire_laps() — regenerate (node tools/gen_tower_map.js)');
  return parseInt(m[1], 10);
})();
const SPIRE_X = 10240;
const ISLAND_MIN_FACES = 1;        // any island inside a tower fails

const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const opt = (n) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : undefined; };
const VERBOSE = flag('--verbose');
const NO_GATE = flag('--no-gate');

function defaultHkt() {
  const roots = [
    'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130',
  ];
  for (const r of roots) {
    const p = path.join(r, 'share/raw/maps/zm/zm_tower_of_doom_navmesh.hkt');
    if (fs.existsSync(p)) return p;
  }
  return null;
}

const HKT = args.find(a => !a.startsWith('--') && a.endsWith('.hkt')) || defaultHkt();
if (!HKT || !fs.existsSync(HKT)) { console.error('lint_tod_navmesh: no .hkt found (' + HKT + ')'); process.exit(2); }
const buf = fs.readFileSync(HKT);
const N = buf.length;

// ---- varints ----------------------------------------------------------------
function vread(pos) {
  let v = 0, s = 0, i = pos;
  for (;;) { const b = buf[i++]; v += (b & 0x7f) * Math.pow(2, s); s += 7; if (!(b & 0x80)) break; if (s > 63 || i > N) throw new Error('bad varint @' + pos); }
  return [v, i];
}
const sm = (v) => (v & 1) ? -Math.floor(v / 2) : v / 2;   // sign in the low bit
function readArr(pos, n) { const [t, p0] = vread(pos); const out = new Array(n); let p = p0; for (let k = 0; k < n; k++) { const [v, q] = vread(p); out[k] = sm(v); p = q; } return [t, out, p]; }

// ---- locate the hkaiNavMesh object ----------------------------------------
function lastIndexOfStr(s, from) { const b = Buffer.from(s, 'latin1'); return buf.lastIndexOf(b, from === undefined ? N : from); }
const meshType = lastIndexOfStr('hkaiNavMesh\u0000') >= 0 ? lastIndexOfStr('hkaiNavMesh\u0000') : lastIndexOfStr('hkaiNavMesh');
if (meshType < 0) { console.error('lint_tod_navmesh: no hkaiNavMesh type in file'); process.exit(2); }
// the tagfile's descriptor list ends with hkaiStreamingSetVolumeConnection's last member
const anchor = buf.indexOf(Buffer.from('oppositeCellIndex', 'latin1'), meshType);
if (anchor < 0) { console.error('lint_tod_navmesh: descriptor anchor not found'); process.exit(2); }

function findFaces(from) {
  for (let s = from; s < from + 96; s++) {
    try {
      const [c, p1] = vread(s); const F = sm(c);
      if (F < 100 || F > 200000) continue;
      const [bits, p2] = vread(p1);
      if (!(bits & 1)) continue;
      const [t, p3] = vread(p2);
      if (t !== 8) continue;
      let p = p3, prev = -1, ok = true;
      for (let k = 0; k < Math.min(F, 64); k++) { const [v, q] = vread(p); const d = sm(v); if (k === 0 && d !== 0) { ok = false; break; } if (d < prev) { ok = false; break; } prev = d; p = q; }
      if (ok) return { F, bits, pos: p1 };
    } catch (e) { /* keep scanning */ }
  }
  return null;
}
const fh = findFaces(anchor + 'oppositeCellIndex'.length);
if (!fh) { console.error('lint_tod_navmesh: faces array not found after descriptor table'); process.exit(2); }

const FACE_MEMBERS = ['startEdgeIndex', 'startUserEdgeIndex', 'numEdges', 'numUserEdges', 'clusterIndex', 'padding'];
const EDGE_MEMBERS = ['a', 'b', 'oppositeEdge', 'oppositeFace', 'flags', 'paddingByte', 'userEdgeCost'];
const F = fh.F;
const faces = {};
let pos = fh.pos;
{
  const [bits, p] = vread(pos); pos = p;
  for (let m = 0; m < FACE_MEMBERS.length; m++) {
    if (!(bits & (1 << m))) continue;
    const [t, arr, q] = readArr(pos, F); faces[FACE_MEMBERS[m]] = arr; pos = q;
  }
}
for (const need of ['startEdgeIndex', 'numEdges']) if (!faces[need]) { console.error('lint_tod_navmesh: faces lack ' + need); process.exit(2); }
let consistent = 0;
for (let i = 0; i + 1 < F; i++) if (faces.startEdgeIndex[i + 1] - faces.startEdgeIndex[i] === faces.numEdges[i]) consistent++;
if (consistent !== F - 1) { console.error(`lint_tod_navmesh: face table inconsistent (${consistent}/${F - 1}) — format drift, refusing to judge`); process.exit(2); }
const E_expect = faces.startEdgeIndex[F - 1] + faces.numEdges[F - 1];

const edges = {};
let E;
{
  const [c, p1] = vread(pos); E = sm(c);
  if (E !== E_expect) { console.error(`lint_tod_navmesh: edge count ${E} != implied ${E_expect}`); process.exit(2); }
  const [bits, p2] = vread(p1); pos = p2;
  for (let m = 0; m < EDGE_MEMBERS.length; m++) {
    if (!(bits & (1 << m))) continue;
    if (EDGE_MEMBERS[m] === 'userEdgeCost') { const [t, q0] = vread(pos); pos = q0 + 4 * E; continue; }
    const [t, arr, q] = readArr(pos, E); edges[EDGE_MEMBERS[m]] = arr; pos = q;
  }
}
for (const need of ['a', 'b', 'oppositeFace']) if (!edges[need]) { console.error('lint_tod_navmesh: edges lack ' + need); process.exit(2); }
const V = Math.max(...edges.a, ...edges.b) + 1;
for (const o of edges.oppositeFace) if (o >= F) { console.error('lint_tod_navmesh: oppositeFace out of range'); process.exit(2); }

// vertices: float32 x4 in metres, right after the edge arrays (short header)
let vstart = null;
for (let s = pos - 4; s < pos + 24; s++) {
  if (s < 0 || s + 16 * V > N) continue;
  let ok = true;
  for (let k = 0; k < V; k++) {
    const i = s + 16 * k; const x = buf.readFloatLE(i), y = buf.readFloatLE(i + 4), z = buf.readFloatLE(i + 8);
    if (!(Number.isFinite(x) && Number.isFinite(y) && Number.isFinite(z) && Math.abs(x) < 1500 && Math.abs(y) < 1500 && z > -100 && z < 1500)) { ok = false; break; }
  }
  if (ok) { vstart = s; break; }
}
if (vstart === null) { console.error('lint_tod_navmesh: vertex array not found after edges'); process.exit(2); }
const P = new Array(V);
for (let k = 0; k < V; k++) { const i = vstart + 16 * k; P[k] = [buf.readFloatLE(i) * M, buf.readFloatLE(i + 4) * M, buf.readFloatLE(i + 8) * M]; }

// ---- centroids, components ---------------------------------------------------
const C = new Array(F);
for (let f = 0; f < F; f++) {
  const s = faces.startEdgeIndex[f], n = faces.numEdges[f]; let cx = 0, cy = 0, cz = 0;
  for (let e = s; e < s + n; e++) { const p = P[edges.a[e]]; cx += p[0]; cy += p[1]; cz += p[2]; }
  C[f] = [cx / n, cy / n, cz / n];
}
const comp = new Int32Array(F).fill(-1); let nc = 0;
for (let f = 0; f < F; f++) {
  if (comp[f] >= 0) continue; const st = [f]; comp[f] = nc;
  while (st.length) { const g = st.pop(); const s = faces.startEdgeIndex[g], n = faces.numEdges[g]; for (let e = s; e < s + n; e++) { const o = edges.oppositeFace[e]; if (o >= 0 && comp[o] < 0) { comp[o] = nc; st.push(o); } } }
  nc++;
}
const compSize = new Array(nc).fill(0); for (let f = 0; f < F; f++) compSize[comp[f]]++;
function region(c) { if (Math.abs(c[0]) < 700 && Math.abs(c[1]) < 700) return 'tower'; if (Math.abs(c[0] - SPIRE_X) < 1000 && Math.abs(c[1]) < 1000) return 'spire'; return 'other'; }

function floorTable(regionName, floors, xOff) {
  const rows = []; let baseComp = null; const bad = [];
  for (let fl = 1; fl <= floors + 1; fl++) {
    const zl = (fl - 1) * LAP_RISE - 8, zh = fl * LAP_RISE + 8;
    const fs2 = []; for (let f = 0; f < F; f++) if (region(C[f]) === regionName && C[f][2] >= zl && C[f][2] <= zh) fs2.push(f);
    if (fl === 1 && fs2.length) baseComp = comp[fs2[0]];
    const comps = [...new Set(fs2.map(f => comp[f]))].sort((a, b) => b - a);
    const foreign = comps.filter(c => c !== baseComp);
    if (fs2.length === 0 && fl <= floors) bad.push({ fl, why: 'NO FACES' });
    if (foreign.length) bad.push({ fl, why: 'split: comps ' + comps.map(c => `${c}(${compSize[c]})`).join(' ') });
    rows.push({ fl, faces: fs2.length, comps, foreign: foreign.length > 0 });
  }
  return { baseComp, rows, bad };
}
const tower = floorTable('tower', TOWER_FLOORS, 0);
const spire = floorTable('spire', SPIRE_FLOORS, SPIRE_X);

// ---- report -----------------------------------------------------------------
console.log(`navmesh ${path.basename(HKT)}: ${F} faces, ${E} edges, ${V} verts, ${nc} components (${fs.statSync(HKT).size} bytes)`);
const byRegion = {};
for (let f = 0; f < F; f++) { const r = region(C[f]); byRegion[comp[f]] = byRegion[comp[f]] || {}; byRegion[comp[f]][r] = (byRegion[comp[f]][r] || 0) + 1; }
const order = [...Array(nc).keys()].sort((a, b) => compSize[b] - compSize[a]);
for (const c of order) {
  const zs = []; for (let f = 0; f < F; f++) if (comp[f] === c) zs.push(C[f][2]);
  console.log(`  comp ${String(c).padStart(3)}  faces ${String(compSize[c]).padStart(5)}  ${JSON.stringify(byRegion[c]).padEnd(40)} z ${Math.min(...zs).toFixed(0)}..${Math.max(...zs).toFixed(0)}`);
}
function printTable(name, t) {
  if (!VERBOSE && t.bad.length === 0) { console.log(`${name}: all ${t.rows.length - 1} floors in component ${t.baseComp} — connected`); return; }
  console.log(`${name}: base component ${t.baseComp}`);
  for (const r of t.rows) if (VERBOSE || r.foreign || r.faces === 0) console.log(`   floor ${String(r.fl).padStart(3)}  faces ${String(r.faces).padStart(3)}  comps ${JSON.stringify(r.comps)}${r.foreign ? '   <-- SEAM / ISLAND' : ''}`);
}
printTable('TOWER', tower);
printTable('SPIRE', spire);
// --islands (v17.70): where ARE the foreign components? One line per component
// that is not its tower's base: size + the centroid of its first face, so a
// single-face island can be matched to a brush without a bisect.
if (flag('--islands')) {
  for (const [name, t] of [['TOWER', tower], ['SPIRE', spire]]) {
    const seen = new Set();
    for (const r of t.rows) for (const c of r.comps) {
      if (c === t.baseComp || seen.has(c)) continue; seen.add(c);
      let f0 = -1; for (let f = 0; f < F; f++) if (comp[f] === c) { f0 = f; break; }
      const c0 = C[f0];
      console.log(`  ${name} island comp ${c} (${compSize[c]} faces) first face at ${c0.map(v => v.toFixed(0)).join(' ')}`);
    }
  }
}

const jsonOut = opt('--json');
if (jsonOut) fs.writeFileSync(jsonOut, JSON.stringify({ hkt: HKT, F, E, V, components: nc, compSize, tower, spire }, null, 1));

const failures = [];
for (const b of tower.bad) failures.push(`tower floor ${b.fl}: ${b.why}`);
for (const b of spire.bad) failures.push(`spire floor ${b.fl}: ${b.why}`);
if (failures.length) {
  console.log(`\nNAVMESH ${NO_GATE ? 'WARNINGS' : 'GATE FAILED'} (${failures.length}):`);
  for (const f of failures) console.log('  ' + f);
  console.log('A seam means zombies cannot path across it and a player standing on it cannot be reached; see the header of this tool.');
  if (!NO_GATE) process.exit(1);
} else {
  console.log('\nNAVMESH GATE OK: both towers are single connected walks.');
}
