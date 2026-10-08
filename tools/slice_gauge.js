#!/usr/bin/env node
// =============================================================================
// slice_gauge.js — cuts a TOWER GAUGE delivery into the images the HUD stamps.
// zlib only, no PNG library in the tree.
//
//   node tools/slice_gauge.js <delivery_dir>                   tower set, check only
//   node tools/slice_gauge.js <delivery_dir> --write           tower set, check + write
//   node tools/slice_gauge.js <delivery_dir> --spire [--write] the ENDLESS SPIRE set
//
// TWO PROFILES, ONE TOOL (docs/70 §B, docs/71 §B.1). A delivery is three
// PIXEL-REGISTERED 180x1440 masters (dark / lit / down) — the engine draws the
// dark master as the backing and stamps full-width band crops of the lit (or
// down) master onto every cell — so this tool is the ONLY place the art grid
// is turned into files. The grid constants in PROFILES are LOCKSTEP with the
// TOWER GAUGE block in ui/uieditor/menus/hud/tod_upgrade.lua.
//
//   tower  25 cells, pitch 42, from y 290 (docs/70 §5)  -> i_tod_gauge_*
//   spire  35 cells, pitch 30, from y 290 (docs/105; 50 at 21 until v17.69)  -> i_tod_spire_*
//
// Outputs (source_data/tod_ui_images/_images/), per profile:
//   <prefix>dark.png          the dark master, whole
//   <prefix>c01..cNN.png      lit master, cell f's band: y = cell0 + (N-f)*pitch, full width
//   <prefix>d01..dNN.png      down master, cell f's band — ONE PER CELL, never a
//                             shared tile: the plate carries a top-to-bottom
//                             vignette under every cell (measured on the tower
//                             set: cell 13's down band differs from cell 25's in
//                             ~1900 px), so a tile cut at one height and stamped
//                             at another prints a faint rectangle of the wrong
//                             shade. A per-cell crop composites exactly.
//   <prefix>crown.png | summit.png   lit master, y 0..290 (the top + the neck —
//                             the neck is identical in every master, so a halo
//                             that reaches it is covered, not seamed)
//   <prefix>base.png          lit master, y 1340..1440 — the base cap lit; the
//                             Lua stamps it once cell 1 lights
//   i_tod_gauge_boss.png      tower only — the pip, whole (the spire reuses it)
//   i_tod_spire_summit_won.png  spire only, OPTIONAL — from spire_won.png 0..290
//
// CHECKS (all must pass before --write does anything): sizes; registration
// (the alpha silhouette of every master agrees with the dark one); the
// band-line rule (every cut row y = cell0 + pitch*k, k = 0..N, identical in
// lit/down and dark — row cell0 is the top crop's bottom edge and the last is
// the base crop's top edge, so a stamped tile never shows a seam); the neck
// identical; every hub/lounge cell's lit plate distinct from the cell below.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const W = 180, H = 1440, NECK_Y = 270, PIP_W = 72, PIP_H = 42;
const OUT_DIR = path.join(__dirname, '..', 'source_data', 'tod_ui_images', '_images');

const PROFILES = {
  tower: {
    prefix: 'i_tod_gauge_', cells: 25, pitch: 42, cell0: 290, topCrop: 290, topName: 'crown',
    files: { dark: 'gauge_dark.png', lit: 'gauge_lit.png', down: 'gauge_down.png' },
    pip: 'gauge_boss.png', won: null,
    hubs: [5, 10, 15, 20],
  },
  spire: {
    // v17.69: 70 floors -> 35 cells at pitch 30 (35 x 30 = 1050 = 1340 - 290, so
    // the summit/neck/base rows are the tower's own). LOCKSTEP with SP_CELLS /
    // SP_PITCH in tod_upgrade.lua and TOD_GAUGE_SPIRE_CELLS in _tod_gauge.gsc.
    prefix: 'i_tod_spire_', cells: 35, pitch: 30, cell0: 290, topCrop: 290, topName: 'summit',
    files: { dark: 'spire_dark.png', lit: 'spire_lit.png', down: 'spire_down.png' },
    pip: null, won: 'spire_won.png',
    hubs: [5, 10, 15, 20, 25, 30, 35],
  },
};

// ---- minimal PNG codec (8-bit RGB / RGBA, non-interlaced) ----
const CRC_T = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1); t[n] = c >>> 0; } return t; })();
function crc32(buf) { let c = 0xFFFFFFFF; for (let i = 0; i < buf.length; i++) c = CRC_T[(c ^ buf[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data) { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type, 'ascii'), data]); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td)); return Buffer.concat([len, td, crc]); }

function decodePNG(file) {
  const b = fs.readFileSync(file);
  if (b.readUInt32BE(0) !== 0x89504E47) throw new Error(`${file}: not a PNG`);
  let pos = 8, w = 0, h = 0, depth = 0, ctype = 0, interlace = 0; const idat = [];
  while (pos < b.length) {
    const len = b.readUInt32BE(pos), type = b.toString('ascii', pos + 4, pos + 8), data = b.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); depth = data[8]; ctype = data[9]; interlace = data[12]; }
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    pos += 12 + len;
  }
  if (depth !== 8 || (ctype !== 6 && ctype !== 2) || interlace !== 0) throw new Error(`${file}: unsupported PNG (depth ${depth}, colortype ${ctype}, interlace ${interlace})`);
  const bpp = ctype === 6 ? 4 : 3, stride = w * bpp;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const out = Buffer.alloc(w * h * 4);
  let prev = Buffer.alloc(stride), cur = Buffer.alloc(stride);
  for (let y = 0; y < h; y++) {
    const ft = raw[y * (stride + 1)], row = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let i = 0; i < stride; i++) {
      const a = i >= bpp ? cur[i - bpp] : 0, up = prev[i], c = i >= bpp ? prev[i - bpp] : 0; let v = row[i];
      if (ft === 1) v += a; else if (ft === 2) v += up; else if (ft === 3) v += (a + up) >> 1;
      else if (ft === 4) { const p = a + up - c, pa = Math.abs(p - a), pb = Math.abs(p - up), pc = Math.abs(p - c); v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? up : c); }
      cur[i] = v & 0xFF;
    }
    for (let x = 0; x < w; x++) { const o = (y * w + x) * 4, i = x * bpp; out[o] = cur[i]; out[o + 1] = cur[i + 1]; out[o + 2] = cur[i + 2]; out[o + 3] = bpp === 4 ? cur[i + 3] : 255; }
    [prev, cur] = [cur, prev];
  }
  return { w, h, d: out };
}

function encodePNG(img) {
  const { w, h, d } = img, raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; d.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

function crop(img, x0, y0, cw, ch) {
  const d = Buffer.alloc(cw * ch * 4);
  for (let y = 0; y < ch; y++) img.d.copy(d, y * cw * 4, ((y0 + y) * img.w + x0) * 4, ((y0 + y) * img.w + x0 + cw) * 4);
  return { w: cw, h: ch, d };
}
// pixels that differ by more than `tol` on any channel, within a row range
function diffRows(a, b, y0, y1, tol = 2) {
  let n = 0;
  for (let y = y0; y < y1; y++) for (let x = 0; x < a.w; x++) { const o = (y * a.w + x) * 4; for (let k = 0; k < 4; k++) if (Math.abs(a.d[o + k] - b.d[o + k]) > tol) { n++; break; } }
  return n;
}
// pixels whose alpha PRESENCE (>0) disagrees — the silhouette test
function diffSilhouette(a, b) {
  let n = 0;
  for (let i = 3; i < a.d.length; i += 4) if ((a.d[i] > 0) !== (b.d[i] > 0)) n++;
  return n;
}

// ---- main ----
const args = process.argv.slice(2);
const dir = args.find(a => !a.startsWith('--'));
const write = args.includes('--write');
// --band-tol N: the cut-row tolerance (default 6). v17.70: the 35-cell spire
// delivery draws every plate edge-to-edge in its band (no plate-dark margin),
// so EVERY cut row is a plate outline that is bright in the lit master and dim
// in the dark one (~110-124 px of 180) — the trail's top is a lit plate under
// a dark one, which is the read a bar should have, not a seam. Inspected on
// the review sheet before the override was used; say so when you use it.
const bandTol = (() => { const i = args.indexOf('--band-tol'); return i >= 0 ? parseInt(args[i + 1], 10) : 6; })();
if (bandTol !== 6) console.log(`WARN band-line tolerance overridden to ${bandTol} px (default 6) — only after the review sheet was inspected`);
const P = PROFILES[args.includes('--spire') ? 'spire' : 'tower'];
if (!dir) { console.error('usage: node tools/slice_gauge.js <delivery_dir> [--spire] [--write]'); process.exit(2); }

const cellTop = f => P.cell0 + (P.cells - f) * P.pitch;
const baseY = P.cell0 + P.cells * P.pitch;   // 1340 for both profiles
const bandEqual = (img, f, g, tol = 2) => diffRows(crop(img, 0, cellTop(f), W, P.pitch), crop(img, 0, cellTop(g), W, P.pitch), 0, P.pitch, tol);
const two = f => String(f).padStart(2, '0');

const img = {};
for (const [k, f] of Object.entries(P.files)) img[k] = decodePNG(path.join(dir, f));
if (P.pip) img.pip = decodePNG(path.join(dir, P.pip));
if (P.won && fs.existsSync(path.join(dir, P.won))) img.won = decodePNG(path.join(dir, P.won));

const fails = [];
const check = (ok, msg) => { console.log(`${ok ? 'ok  ' : 'FAIL'} ${msg}`); if (!ok) fails.push(msg); };
console.log(`profile ${P.prefix}  cells ${P.cells}  pitch ${P.pitch}  cell0 ${P.cell0}  base ${baseY}`);

for (const k of ['dark', 'lit', 'down']) check(img[k].w === W && img[k].h === H, `${P.files[k]} is ${img[k].w}x${img[k].h} (want ${W}x${H})`);
if (img.pip) check(img.pip.w === PIP_W && img.pip.h === PIP_H, `${P.pip} is ${img.pip.w}x${img.pip.h} (want ${PIP_W}x${PIP_H})`);
if (img.won) check(img.won.w === W && img.won.h === H, `${P.won} is ${img.won.w}x${img.won.h} (want ${W}x${H})`);
else if (P.won) console.log(`info ${P.won} not delivered (optional) — no *_${P.topName}_won tile`);
if (fails.length) { console.error('size check failed'); process.exit(1); }

for (const k of ['lit', 'down', ...(img.won ? ['won'] : [])]) {
  const s = diffSilhouette(img.dark, img[k]);
  check(s <= 200, `registration dark vs ${k}: ${s} silhouette pixels differ (tolerance 200)`);
}

let worst = { lit: 0, down: 0, won: 0 }, worstRow = -1;
for (let k = 0; k <= P.cells; k++) {
  const y = P.cell0 + k * P.pitch;
  for (const m of Object.keys(worst)) { if (!img[m]) continue; const n = diffRows(img.dark, img[m], y, y + 1); if (n > worst[m]) { worst[m] = n; if (m === 'lit') worstRow = y; } }
}
check(worst.lit <= bandTol, `band lines lit vs dark: worst cut row differs in ${worst.lit} px (row ${worstRow}; tolerance ${bandTol})`);
check(worst.down <= bandTol, `band lines down vs dark: worst cut row differs in ${worst.down} px (tolerance ${bandTol})`);
if (img.won) check(worst.won <= bandTol, `band lines won vs dark: worst cut row differs in ${worst.won} px (tolerance ${bandTol})`);

const neck = diffRows(img.dark, img.lit, NECK_Y, P.topCrop);
check(neck <= 6, `neck (${NECK_Y}..${P.topCrop}) lit vs dark: ${neck} px differ (tolerance 6)`);
if (img.won) {
  const wonBody = diffRows(img.lit, img.won, P.topCrop, H);
  check(wonBody <= 6, `won vs lit below the ${P.topName} crop: ${wonBody} px differ (the won master may only change the ${P.topName}; tolerance 6)`);
  console.log(`info won: ${P.topName} band lit vs won differs in ${diffRows(img.lit, img.won, 0, P.topCrop)} px (the beacon)`);
}

console.log(`info base: lit vs dark differs in ${diffRows(img.dark, img.lit, baseY, H)} px below the cells (the base tile lights with cell 1)`);
console.log(`info down: cell ${Math.ceil(P.cells / 2)}'s down band vs cell ${P.cells}'s differs in ${bandEqual(img.down, Math.ceil(P.cells / 2), P.cells)} px (vignette — why the down tiles are per cell)`);
console.log(`info lit: hub cell ${P.hubs[0]} vs regular cell ${P.hubs[0] - 1} differ in ${bandEqual(img.lit, P.hubs[0], P.hubs[0] - 1)} px (the hub read is the wider plate)`);
const hubsDistinct = P.hubs.every(f => bandEqual(img.lit, f, f - 1) > 100);
check(hubsDistinct, `every hub/lounge cell (${P.hubs.join('/')}) has a distinct lit plate from the cell below it`);
// a lit regular cell must actually differ from its dark plate (an unlit master handed in as "lit" would pass everything above)
const litVsDark = diffRows(crop(img.dark, 0, cellTop(1), W, P.pitch), crop(img.lit, 0, cellTop(1), W, P.pitch), 0, P.pitch);
check(litVsDark > 100, `cell 1 lit vs dark differ in ${litVsDark} px (the lit master really is lit)`);

if (fails.length) { console.error(`\n${fails.length} check(s) failed — nothing written.`); process.exit(1); }
if (!write) { console.log('\nall checks passed (dry run; add --write to cut the tiles)'); process.exit(0); }

const written = [];
const put = (name, im) => { const p = path.join(OUT_DIR, name); fs.writeFileSync(p, encodePNG(im)); written.push(`${name} ${im.w}x${im.h}`); };
put(`${P.prefix}dark.png`, img.dark);
for (let f = 1; f <= P.cells; f++) put(`${P.prefix}c${two(f)}.png`, crop(img.lit, 0, cellTop(f), W, P.pitch));
for (let f = 1; f <= P.cells; f++) put(`${P.prefix}d${two(f)}.png`, crop(img.down, 0, cellTop(f), W, P.pitch));
put(`${P.prefix}${P.topName}.png`, crop(img.lit, 0, 0, W, P.topCrop));
put(`${P.prefix}base.png`, crop(img.lit, 0, baseY, W, H - baseY));
if (img.pip) put(`${P.prefix}boss.png`, img.pip);
if (img.won) put(`${P.prefix}${P.topName}_won.png`, crop(img.won, 0, 0, W, P.topCrop));
console.log(`\nwrote ${written.length} files to ${OUT_DIR}:`);
for (const w of written) console.log('  ' + w);
