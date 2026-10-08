#!/usr/bin/env node
// install_spire_art.js — phase-2 art install for THE ENDLESS SPIRE (docs/44).
// Copies the five PNGs into _images/ and clones the proven GDT block pairs
// (i_tod_win_banner/tod_win_banner for banners, the win_emblem pair for the
// emblem) with only the identifier and colorMap substituted — 5 hand-copies
// of a ~200-key material block is how typos ship. Idempotent: existing
// assets are skipped. Run from anywhere: node tools/spire_wip/install_spire_art.js
'use strict';
const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..', '..');
const GDT = path.join(REPO, 'source_data', 'tod_ui_images.gdt');
const IMG_DIR = path.join(REPO, 'source_data', 'tod_ui_images', '_images');
const ART_DIR = path.join(__dirname, 'art');

// name -> template pair to clone
const ASSETS = [
  { name: 'i_tod_choice_banner',     mat: 'tod_choice_banner',     tpl: 'banner' },
  { name: 'i_tod_spire_banner',      mat: 'tod_spire_banner',      tpl: 'banner' },
  { name: 'i_tod_spire_over_banner', mat: 'tod_spire_over_banner', tpl: 'banner' },
  { name: 'i_tod_spire_win_banner',  mat: 'tod_spire_win_banner',  tpl: 'banner' },
  { name: 'i_tod_spire_emblem',      mat: 'tod_spire_emblem',      tpl: 'emblem' },
];
const TPL = {
  banner: { img: 'i_tod_win_banner', mat: 'tod_win_banner' },
  emblem: { img: 'i_tod_win_emblem', mat: 'tod_win_emblem' },
};

let gdt = fs.readFileSync(GDT, 'utf8');

// Extract one top-level asset block: from `"name" ( "kind" )` through its
// brace-matched close, inclusive of the leading tab and trailing newline.
function extractBlock(name, kind) {
  const header = `\t"${name}" ( "${kind}" )`;
  const start = gdt.indexOf(header);
  if (start < 0) throw new Error(`template block not found: ${name} (${kind})`);
  let i = gdt.indexOf('{', start);
  let depth = 0;
  for (; i < gdt.length; i++) {
    if (gdt[i] === '{') depth++;
    else if (gdt[i] === '}') { depth--; if (depth === 0) break; }
  }
  const end = gdt.indexOf('\n', i) + 1;
  return gdt.slice(start, end);
}

// 1. the PNGs
for (const a of ASSETS) {
  const src = path.join(ART_DIR, a.name + '.png');
  const dst = path.join(IMG_DIR, a.name + '.png');
  if (!fs.existsSync(src)) throw new Error(`missing art: ${src}`);
  fs.copyFileSync(src, dst);
  console.log(`png  -> ${path.relative(REPO, dst)}`);
}

// 2. the GDT blocks — appended before the file's final closing brace.
const closeIdx = gdt.lastIndexOf('}');
if (closeIdx < 0) throw new Error('GDT: no closing brace');
let add = '';
for (const a of ASSETS) {
  const t = TPL[a.tpl];
  if (!gdt.includes(`\t"${a.name}" ( "image.gdf" )`)) {
    let b = extractBlock(t.img, 'image.gdf');
    b = b.split(`"${t.img}"`).join(`"${a.name}"`)
         .split(`_images/${t.img}.png`).join(`_images/${a.name}.png`);
    add += b;
    console.log(`gdt  image    ${a.name}  (from ${t.img})`);
  } else console.log(`gdt  image    ${a.name}  already present — skipped`);
  if (!gdt.includes(`\t"${a.mat}" ( "material.gdf" )`)) {
    let b = extractBlock(t.mat, 'material.gdf');
    b = b.split(`"${t.mat}"`).join(`"${a.mat}"`)
         .split(`"${t.img}"`).join(`"${a.name}"`);   // colorMap
    add += b;
    console.log(`gdt  material ${a.mat}  (from ${t.mat})`);
  } else console.log(`gdt  material ${a.mat}  already present — skipped`);
}
if (add) {
  gdt = gdt.slice(0, closeIdx) + add + gdt.slice(closeIdx);
  fs.writeFileSync(GDT, gdt, 'utf8');
  console.log('GDT updated. REMINDER: a .gdt change is ALWAYS a FULL build.');
} else console.log('GDT unchanged.');
console.log('zone lines still needed (WIRING.md §6): image,<name> + material,<mat> per asset.');
