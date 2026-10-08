#!/usr/bin/env node
// =============================================================================
// gen_pap_badge_placeholder.js — author the PACK-A-PUNCH TIER BADGE's two
// source files (v17.33) so the feature is wired, packed and PLAYABLE before the
// commissioned art lands.
//
// WHY PLACEHOLDERS AT ALL, when the house rule is "baked art beats anything
// drawn in code" (memory: images-over-lui). Because the alternative was worse
// in both directions. Referencing i_tod_hud_pap_* before the images exist is a
// WHITE SQUARE on the HUD — RegisterImage on an unzoned name does not fail, it
// draws one, which is the entire reason lint_tod_assets.js has a GATE A. And
// NOT referencing them means the wiring lands in a second build, so the drop
// stops being a file swap and becomes a code change with its own gates.
//
// These are deliberately PLAIN: flat navy plate, cyan keyline, steel-white
// roman numeral, nothing else. They are correct — right sizes, right palette,
// right ink margins, right baseline — and they are not trying to be the final
// art. docs/96 is the commission; when it comes back, drop the two delivered
// files in and re-slice. No wiring changes, no flag to flip.
//
// PALETTE — sampled from the shipped gun HUD, not invented (docs/95):
//   #E8EEF6 STEEL WHITE   the numeral
//   #5BC8FF ELECTRIC CYAN keylines
//   #131B38 DEEP NAVY     the plate body
//   #0A1020 OUTLINE BLACK the hard outline
//
//   node tools/gen_pap_badge_placeholder.js
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const OUT = path.join(__dirname, '..', 'source_data', 'tod_ui_images', '_images');

// --- PNG out (same encoder as tools/slice_hud_sheets.js) ---------------------
const CRC_T = (() => { const t = []; for (let n = 0; n < 256; n++) { let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
function crc32(buf) { let c = 0xFFFFFFFF; for (const B of buf) c = CRC_T[(c ^ B) & 255] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const cc = Buffer.alloc(4); cc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, cc]);
}
function encodePNG(img) {
  const stride = img.w * 4, raw = Buffer.alloc(img.h * (stride + 1));
  for (let y = 0; y < img.h; y++) {
    raw[y * (stride + 1)] = 0;
    img.d.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.w, 0); ihdr.writeUInt32BE(img.h, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

const img = (w, h) => ({ w, h, d: Buffer.alloc(w * h * 4, 0) });
function px(im, x, y, [r, g, b], a = 255) {
  if (x < 0 || y < 0 || x >= im.w || y >= im.h) return;
  const i = (y * im.w + x) * 4;
  im.d[i] = r; im.d[i + 1] = g; im.d[i + 2] = b; im.d[i + 3] = a;
}
function rect(im, x0, y0, w, h, c, a = 255) {
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) px(im, x, y, c, a);
}
// hollow rectangle of thickness t, drawn INWARD from the given box
function frame(im, x0, y0, w, h, t, c, a = 255) {
  rect(im, x0, y0, w, t, c, a);
  rect(im, x0, y0 + h - t, w, t, c, a);
  rect(im, x0, y0, t, h, c, a);
  rect(im, x0 + w - t, y0, t, h, c, a);
}

const STEEL = [0xE8, 0xEE, 0xF6];
const CYAN  = [0x5B, 0xC8, 0xFF];
const NAVY  = [0x13, 0x1B, 0x38];
const INK   = [0x0A, 0x10, 0x20];

// ---------------------------------------------------------------------------
// THE TILE — 276x192, the offhand tile's exact source size, because the badge
// is drawn into the same 46x32 canvas box and any other source aspect would
// stretch. Body, hard outline, and a cyan rule along the TOP edge only: that
// asymmetry is what stops it reading as a third inventory slot at a glance.
// ---------------------------------------------------------------------------
function tile() {
  const im = img(276, 192);
  rect(im, 0, 0, 276, 192, INK);                 // hard outline / body ground
  rect(im, 6, 6, 264, 180, NAVY);                // the calm dark face
  rect(im, 6, 6, 264, 10, CYAN);                 // top rule — the badge marker
  frame(im, 6, 6, 264, 180, 3, CYAN, 90);        // quiet keyline all round
  // corner notches, bottom two only — the second asymmetry cue
  rect(im, 6, 170, 26, 16, CYAN, 150);
  rect(im, 244, 170, 26, 16, CYAN, 150);
  return im;
}

// ---------------------------------------------------------------------------
// THE NUMERALS — one 384x128 sheet, three 128x128 cells, so it slices through
// tools/slice_hud_sheets.js exactly as the delivered sheet will.
//
// Bars, not letterforms. At 36x36 physical pixels a serifed I is mush; three
// thick vertical bars are unmistakable, and they carry the escalation on their
// own without a second hue (the user's call: stay in palette). Bar WIDTH drops
// as the count rises so the group keeps one optical mass, and the ink box is
// the same for all three — that is what stops the badge jittering when a tier
// is bought.
// ---------------------------------------------------------------------------
function numerals() {
  const im = img(384, 128);
  const INK_X0 = 22, INK_W = 84, INK_Y0 = 26, INK_H = 76;   // shared ink box
  const GAP = [0, 0, 14, 12];                                // gap by bar count
  const BW  = [0, 30, 24, 18];                               // bar width

  for (let n = 1; n <= 3; n++) {
    const ox = (n - 1) * 128;
    const bw = BW[n], gap = GAP[n];
    const total = n * bw + (n - 1) * gap;
    let x = ox + INK_X0 + Math.round((INK_W - total) / 2);
    for (let b = 0; b < n; b++) {
      // hard dark offset first (rule 3 of docs/95: it must read on a bright
      // background), then the steel face on top of it
      rect(im, x + 3, INK_Y0 + 3, bw, INK_H, INK);
      rect(im, x, INK_Y0, bw, INK_H, STEEL);
      // cyan cap and foot — the house two-tone
      rect(im, x, INK_Y0, bw, 6, CYAN);
      rect(im, x, INK_Y0 + INK_H - 6, bw, 6, CYAN);
      x += bw + gap;
    }
  }
  return im;
}

// v17.60/v17.68 GUARD — EVERYTHING THIS SCRIPT DRAWS IS RETIRED. docs/102's
// drop (2026-09-04) replaced i_tod_hud_pap_1..3 with commissioned machine
// glyphs, and docs/103's drop (2026-09-05) replaced i_tod_hud_pap_tile with
// the commissioned plate. Both live under the SAME NAMES this script writes,
// so a plain re-run would clobber shipped art. Every job is therefore opt-in:
// --tile writes the placeholder plate, --numerals the numeral sheet (which
// then needs slice_hud_sheets.js to reach pap_1..3). With no flag it writes
// NOTHING and says so. Kept at all as the escape hatch if a drop ever has to
// be pulled.
const WANT_TILE     = process.argv.includes('--tile');
const WANT_NUMERALS = process.argv.includes('--numerals');
fs.mkdirSync(OUT, { recursive: true });
const jobs = [];
if (WANT_TILE)     jobs.push(['i_tod_hud_pap_tile.png', tile()]);
if (WANT_NUMERALS) jobs.push(['i_tod_hud_pap_sheet.png', numerals()]);
for (const [name, im] of jobs) {
  const p = path.join(OUT, name);
  fs.writeFileSync(p, encodePNG(im));
  console.log(`wrote ${p}  (${im.w}x${im.h})  -- OVERWROTE COMMISSIONED ART under this name`);
}
if (!jobs.length) console.log('nothing written: the badge art is COMMISSIONED since v17.60/v17.68 (docs/102, docs/103). --tile and/or --numerals to force the placeholders back.');
if (WANT_NUMERALS) console.log('\nnow run:  node tools/slice_hud_sheets.js   (this OVERWRITES the shipped i_tod_hud_pap_1..3)');
