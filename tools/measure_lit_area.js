#!/usr/bin/env node
// ---------------------------------------------------------------------------
// measure_lit_area.js — what the LED bake ACTUALLY costs, measured before you
// spend two minutes finding out.
//
// Sums authored lit face areas, including true convex crown faces. This is
// an input surface-area measure, not frame time, final CSG area or a prediction
// of bake duration. The native bake remains the pass/fail gate.
// Usage: node tools/measure_lit_area.js [--map candidate.map]
'use strict';
const fs = require('fs');
const CB = require('./convex_brush');
const path = require('path');

const REPO = path.join(__dirname, '..');
const argv = process.argv.slice(2);
const mi = argv.indexOf('--map');
const MAP = mi >= 0 && argv[mi + 1] ? argv[mi + 1] : path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map');

// Materials that never take a lightmap chart, so never cost bake time.
const UNLIT = /^(clip|sky|caulk|caulk_shadow|nodraw|nodraw_notsolid|portal|portal_nodraw|volume|sun_volume|umbra_volume|volume_fpstool|trigger)/;

// Label -> group. Ordered: first match wins.
const GROUPS = [
  [/^crown (band|ermine|rim|astragal|mouth|cullinan|jewel|frontispiece|rib)/, 'crown band'],
  [/^crown skirt/, 'crown skirt'],
  [/^crown point/, 'crown points'],
  [/^crown (arch|monde|finial|beacon|front cross)/, 'crown upper'],
  [/^crown pendilia/, 'crown pendilia'],
  [/^crown (hall|wall|cornice|gate|cap|ring inlay)/, 'crown hall'],
  [/^crown (step|stair)/, 'crown stair'],
  [/^(uplink|extraction|pylon)/, 'crown hall'],
  [/^causeway/, 'causeway'],
  [/^(core|mast)/, 'core + mast'],
  [/^(terrace)/, 'terrace'],
  [/^(base|ground|power)/, 'base arena'],
  [/^(lap|floor|breather|landing|door)/, 'the spiral'],
];
const groupOf = (label) => {
  for (const [re, g] of GROUPS) if (re.test(label)) return g;
  return 'other';
};

const lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
const acc = new Map();
let label = null, skipped = 0, nonAxial = 0;
const nonAxialLabels = new Set();

for (let i = 0; i < lines.length; i++) {
  const m = /^\/\/ brush \d+ [—-] (.*)$/.exec(lines[i]);
  if (m) { label = m[1].trim(); continue; }
  if (lines[i].trim() !== '{' || label === null) continue;
  const faces = [];
  let mat = null, j = i + 1;
  for (; j < lines.length && lines[j].trim() !== '}'; j++) {
    const f = /^\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s+(\S+)/.exec(lines[j]);
    if (f) { faces.push(f.slice(1, 10).map(Number)); mat = mat || f[10]; }
  }
  // UNLIT first, BEFORE the box-template read (2026-08-27): the stair ramp
  // wedges are clip_player with two sloped planes — index-reading those through
  // the box template produced a garbage box that silently failed the dx/dy/dz
  // check and vanished from BOTH totals, so TOTAL stopped summing to the
  // generator's brush count with no tell. An unlit brush is skipped whatever
  // its shape; a LIT brush with a sloped face gets its own reported bucket.
  if (faces.length && mat && UNLIT.test(mat)) { skipped++; }
  else if (faces.length >=4 && mat) {
    const h=CB.hull(faces.map(v=>CB.plane([v.slice(0,3),v.slice(3,6),v.slice(6,9)],mat)));
    const g=groupOf(label),e=acc.get(g)||{n:0,area:0};
    e.n++;e.area+=h.faces.reduce((a,f)=>a+f.area,0);acc.set(g,e);
  }
  label = null;
  i = j;
}

const rows = [...acc.entries()].sort((a, b) => b[1].area - a[1].area);
const totA = rows.reduce((s, r) => s + r[1].area, 0);
const totN = rows.reduce((s, r) => s + r[1].n, 0);

console.log(`lit surface area — ${path.relative(REPO, MAP)}`);
console.log();
console.log('  ' + 'group'.padEnd(16) + 'brushes'.padStart(9) + 'lit area (M u^2)'.padStart(19) + 'share'.padStart(8));
console.log('  ' + ''.padEnd(52, '-'));
for (const [g, e] of rows)
  console.log('  ' + g.padEnd(16) + String(e.n).padStart(9) +
    (e.area / 1e6).toFixed(1).padStart(19) + ((e.area / totA) * 100).toFixed(1).padStart(7) + '%');
console.log('  ' + ''.padEnd(52, '-'));
console.log('  ' + 'TOTAL'.padEnd(16) + String(totN).padStart(9) + (totA / 1e6).toFixed(1).padStart(19));
console.log();
const crown = rows.filter(r => r[0].startsWith('crown ')).reduce((s, r) => s + r[1].area, 0);
console.log(`  the crown is ${((crown / totA) * 100).toFixed(0)}% of all lit area in the map ` +
  `(${(crown / 1e6).toFixed(0)}M of ${(totA / 1e6).toFixed(0)}M u^2).`);
console.log(`  ${skipped} unlit/degenerate brush(es) excluded (clip, sky, tool materials).`);
if (nonAxial) {
  console.log(`  WARNING: ${nonAxial} LIT brush(es) have sloped faces this tool cannot measure:`);
  for (const l of nonAxialLabels) console.log(`    ${l}`);
  console.log('  Their area is NOT in the totals above — measure by hand before trusting a delta.');
}
console.log();
console.log('  RULE OF THUMB for a detail pass: a 200-unit cube is ~0.24M u^2, so 300 of them');
console.log(`  is ~72M = ${((72e6 / totA) * 100).toFixed(0)}% of the current total. Small relief is nearly free; what costs`);
console.log('  is any NEW LARGE SURFACE. Bake anyway — this predicts nothing, it only explains.');
