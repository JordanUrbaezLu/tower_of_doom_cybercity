#!/usr/bin/env node
// ---------------------------------------------------------------------------
// measure_lit_area.js — what the LED bake ACTUALLY costs, measured before you
// spend two minutes finding out.
//
// WHY THIS EXISTS (2026-08-25). The project spent a long time believing the LED
// bake tracked BRUSH COUNT, because that is the number the generator prints.
// It does not. The decisive datum: the SAME 4,700 brushes bake in 38.2 s at
// CR_SCALE 1.0 and 126.2 s at CR_SCALE 1.4 — 3.3x the time for ~2x the LIT
// SURFACE AREA, with the brush count identical. See docs/34_crown_redesign.md.
//
// So this sums the surface area of every LIT face in the generated .map and
// groups it by what part of the map it belongs to. Run it after a geometry
// change and BEFORE tools/_bake_test.ps1: if the area barely moved, the bake
// will barely move, and you have saved yourself the wait. If it jumped, you
// already know why.
//
// It is a BUDGET INSTRUMENT, not a gate — there is no pass/fail. The gate is
// still _bake_test.ps1, because the failure mode (brush.cpp:1860) is a D3D
// allocation on the bake host and no static measurement can predict it.
//
//   node tools/measure_lit_area.js
//   node tools/measure_lit_area.js --map some/other.map
//
// Faces in clip / sky / caulk / nodraw and the tool-material volume brushes are
// excluded: they carry no lightmap chart and are free.
// ---------------------------------------------------------------------------
'use strict';
const fs = require('fs');
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
let label = null, skipped = 0;

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
  if (faces.length === 6 && mat) {
    // the box() plane template: [z1, z2, y1, x2, y2, x1]
    const z1 = faces[0][2], z2 = faces[1][2], y1 = faces[2][1], y2 = faces[4][1], x1 = faces[5][0], x2 = faces[3][0];
    const dx = x2 - x1, dy = y2 - y1, dz = z2 - z1;
    if (dx > 0 && dy > 0 && dz > 0) {
      if (UNLIT.test(mat)) { skipped++; }
      else {
        const g = groupOf(label);
        const e = acc.get(g) || { n: 0, area: 0 };
        e.n++; e.area += 2 * (dx * dy + dy * dz + dx * dz);
        acc.set(g, e);
      }
    }
  } else if (faces.length) skipped++;
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
console.log();
console.log('  RULE OF THUMB for a detail pass: a 200-unit cube is ~0.24M u^2, so 300 of them');
console.log(`  is ~72M = ${((72e6 / totA) * 100).toFixed(0)}% of the current total. Small relief is nearly free; what costs`);
console.log('  is any NEW LARGE SURFACE. Bake anyway — this predicts nothing, it only explains.');
