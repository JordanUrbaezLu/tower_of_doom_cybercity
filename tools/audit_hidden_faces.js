#!/usr/bin/env node
// ---------------------------------------------------------------------------
// audit_hidden_faces.js — find geometry that is paid for and never seen.
//
// WHY THIS EXISTS (2026-08-25). A design review of the crown found FOUR separate
// elements buried inside other elements — two jewel bosses sealed in the
// frontispiece, the mouth jambs sealed in it as well, a keystone 93% behind the
// Cullinan's bezel, and an arch segment 90% inside the front cross. Every one was
// found BY HAND, by a human reading coordinates out of the .map. That does not
// scale and it does not repeat.
//
// A buried brush is pure cost: it carries lit faces into the LED bake's atlas and
// renders nothing. Worse, a brush that is buried on ONE face and coplanar with
// its neighbour is a z-fight — two materials fighting for the same pixels, which
// looks like a driver bug in game.
//
// So this samples every face of every brush in a label group and reports the ones
// nothing can see. It is an ADVISORY tool, not a gate: a partly-buried brush is
// often correct (a tenon keying into a wall is SUPPOSED to be buried), and only a
// human can say which. It tells you where to look.
//
//   node tools/audit_hidden_faces.js                    # the crown
//   node tools/audit_hidden_faces.js --group "^causeway"
//   node tools/audit_hidden_faces.js --min 60           # report >=60% hidden
//
// METHOD: for each face, sample a grid of points 1 unit OUTSIDE it and test
// containment against every other brush in the group. A face is hidden when every
// sample is inside something. Sampling, not exact CSG, because the answer only
// has to be good enough to point at — and being approximate keeps it honest:
// it can miss a sliver, so a clean report is not a proof.
// ---------------------------------------------------------------------------
'use strict';
const fs = require('fs');
const CB = require('./convex_brush');
const path = require('path');

const REPO = path.join(__dirname, '..');
const argv = process.argv.slice(2);
const arg = (n, d) => { const i = argv.indexOf(n); return i >= 0 && argv[i + 1] !== undefined ? argv[i + 1] : d; };
const MAP = arg('--map', path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map'));
const GROUP = new RegExp(arg('--group', '^crown '));
const MIN = Number(arg('--min', '50'));
const N = 4;   // samples per axis on each face -> N*N per face

const UNLIT = /^(clip|sky|caulk|nodraw|volume|sun_volume|umbra_volume|volume_fpstool|trigger)/;

// --- parse ------------------------------------------------------------------
const lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
const B = [];
let label = null;
for (let i = 0; i < lines.length; i++) {
  const m = /^\/\/ brush \d+ [—-] (.*)$/.exec(lines[i]);
  if (m) { label = m[1].trim(); continue; }
  if (lines[i].trim() !== '{' || label === null) continue;
  const f = []; let mat = null, j = i + 1;
  for (; j < lines.length && lines[j].trim() !== '}'; j++) {
    const g = /^\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s+(\S+)/.exec(lines[j]);
    if (g) { f.push(g.slice(1, 10).map(Number)); mat = mat || g[10]; }
  }
  if(f.length>=4 && mat && GROUP.test(label) && !UNLIT.test(mat)) {
    B.push({label,mat,...CB.hull(f.map(v=>CB.plane([v.slice(0,3),v.slice(3,6),v.slice(6,9)],mat)))});
  }
  label = null; i = j;
}
if (!B.length) { console.error(`no brushes matched ${GROUP}`); process.exit(1); }

const inside = (b, x, y, z) => x > b.x1 && x < b.x2 && y > b.y1 && y < b.y2 && z > b.z1 && z < b.z2 && b.planes.every(p=>CB.dot(p.n,[x,y,z])<p.d-0.01);

// --- per-face occlusion -----------------------------------------------------
const FACES = [
  ['-x', b => [b.x1, b.y1, b.y2, b.z1, b.z2, 0], (b, u, v) => [b.x1 - 1, u, v]],
  ['+x', b => [b.x2, b.y1, b.y2, b.z1, b.z2, 0], (b, u, v) => [b.x2 + 1, u, v]],
  ['-y', b => [b.y1, b.x1, b.x2, b.z1, b.z2, 1], (b, u, v) => [u, b.y1 - 1, v]],
  ['+y', b => [b.y2, b.x1, b.x2, b.z1, b.z2, 1], (b, u, v) => [u, b.y2 + 1, v]],
  ['-z', b => [b.z1, b.x1, b.x2, b.y1, b.y2, 2], (b, u, v) => [u, v, b.z1 - 1]],
  ['+z', b => [b.z2, b.x1, b.x2, b.y1, b.y2, 2], (b, u, v) => [u, v, b.z2 + 1]],
];

const rows = [];
let totArea = 0, hidArea = 0;
for (const b of B) {
  let area=0,hidden=0,nHid=0;const hidNames=[];
  for(const [fi,f] of b.faces.entries()) {
    let covered=0,total=0;
    // Triangle-fan barycentric samples lie on the ACTUAL polygon, including
    // bevels and sloping surfaces. AABB faces no longer invent hidden area.
    for(let t=1;t<f.vertices.length-1;t++)for(let i=0;i<N;i++)for(let j=0;j<N-i;j++) {
      const u=(i+0.33)/N,v=(j+0.33)/N;if(u+v>=1)continue;
      const p=f.vertices[0].map((x,k)=>x*(1-u-v)+f.vertices[t][k]*u+f.vertices[t+1][k]*v+f.n[k]);
      total++;if(B.some(o=>o!==b && inside(o,...p)))covered++;
    }
    area+=f.area;if(total && covered===total){hidden+=f.area;nHid++;hidNames.push(String(fi));}
  }
  totArea += area; hidArea += hidden;
  const pct = area ? (hidden / area) * 100 : 0;
  if (pct >= MIN) rows.push({ label: b.label, mat: b.mat, pct, nHid, nFaces:b.faces.length, area, hidden, faces: hidNames.join(',') });
}

rows.sort((a, b) => b.pct - a.pct || b.hidden - a.hidden);

console.log(`hidden-face audit — ${path.relative(REPO, MAP)}   group ${GROUP}`);
console.log(`${B.length} lit brushes examined, ${N * N} samples per face\n`);
if (!rows.length) {
  console.log(`  nothing at or above ${MIN}% hidden. (Sampled, not exact — a thin sliver can escape it.)`);
} else {
  console.log('  ' + 'brush'.padEnd(34) + 'hidden'.padStart(8) + 'faces'.padStart(7) + '  buried faces');
  console.log('  ' + ''.padEnd(74, '-'));
  for (const r of rows.slice(0, 40))
    console.log('  ' + r.label.slice(0, 33).padEnd(34) + (r.pct.toFixed(0) + '%').padStart(8) +
      (r.nHid + '/' + r.nFaces).padStart(7) + '  ' + r.faces);
  if (rows.length > 40) console.log(`  ... and ${rows.length - 40} more at or above ${MIN}%`);
}
console.log(`\n  ${(hidArea / 1e6).toFixed(1)}M of ${(totArea / 1e6).toFixed(1)}M u^2 of face area is buried ` +
  `(${((hidArea / totArea) * 100).toFixed(1)}%).`);
console.log('  ADVISORY, not a gate: a tenon keyed into a wall is SUPPOSED to be buried.');
console.log('  What matters is a brush buried on ALL faces (pure cost) or one whose');
console.log('  visible face is COPLANAR with a neighbour in another material (a z-fight).');
