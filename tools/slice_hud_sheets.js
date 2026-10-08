#!/usr/bin/env node
// =============================================================================
// slice_hud_sheets.js — cut the four delivered gun-HUD sheets into their cells,
// and DERIVE the typeface metrics from the artwork.
//
// WHY SHEETS AT ALL. docs/95 asked the generator for four SHEETS rather than 59
// separate files, because consistency across N separately-generated images is
// where art packs fail: fifty-nine glyphs asked for fifty-nine times come back
// with fifty-nine stroke weights and fifty-nine light directions. Drawn as one
// image in one pass they cannot. This tool is the other half of that deal.
// Same trick tools/slice_gauge.js already uses to cut 54 gauge tiles.
//
// WHY THE METRICS ARE DERIVED AND NOT HAND-AUTHORED. A proportional bitmap font
// needs an advance width per glyph. Typing 42 numbers into a Lua table creates a
// second source of truth that nothing regenerates — the exact shape CLAUDE.md
// warns about ("name the constant, point at the file"). Instead every cell's ink
// is measured from its own alpha channel and the advance table is EMITTED into
// TodGlyphMetrics.lua. Redraw a glyph narrower and the spacing follows on the
// next slice; the art and its metrics cannot drift.
//
//   node tools/slice_hud_sheets.js --check [--src DIR]   verify, report, write nothing
//   node tools/slice_hud_sheets.js        [--src DIR]    slice + emit metrics
//   node tools/slice_hud_sheets.js --wire                print GDT blocks + zone lines
//
// --check is the gate to run BEFORE installing a drop. It proves the canvas is
// exactly the promised size (the cutting is arithmetic, not vision — a sheet two
// pixels too wide slices wrong on every cell), that no drawing crosses a cell
// boundary, and that every glyph in a typeface row shares one baseline. A glyph
// four pixels off its baseline makes the ammo counter visibly wobble as the
// number changes, and that is not something anyone will spot by eye on a sheet.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const REPO = path.resolve(__dirname, '..');
const OUT_DIR = path.join(REPO, 'source_data', 'tod_ui_images', '_images');
const METRICS = path.join(REPO, 'ui', 'uieditor', 'widgets', 'HUD', 'AetheriumWidgets', 'TodGlyphMetrics.lua');
// The MANIFEST exists so lint_tod_assets.js can cover these names in GATE A.
// Every one of them is built by CONCATENATION at runtime ("i_tod_hud_d" .. c),
// which a Lua-literal scan cannot see — the exact blind spot the 8 tier cards
// fell into, where a deleted zone line would have been a white square nothing
// caught. Generated rather than hand-listed so a new cell covers itself.
const MANIFEST = path.join(__dirname, 'tod_hud_glyphs.generated.json');

const argv = process.argv.slice(2);
const CHECK = argv.includes('--check');
const WIRE = argv.includes('--wire');
const srcIdx = argv.indexOf('--src');
const SRC = srcIdx >= 0 ? argv[srcIdx + 1] : OUT_DIR;

// ---------------------------------------------------------------------------
// minimal PNG codec (8-bit RGBA/RGB, non-interlaced) — zlib only, no library
// ---------------------------------------------------------------------------
function decodePNG(file) {
  const b = fs.readFileSync(file);
  if (b.readUInt32BE(0) !== 0x89504E47) throw new Error(`${file}: not a PNG`);
  let o = 8, w, h, ct, depth, interlace, idat = [];
  while (o < b.length) {
    const len = b.readUInt32BE(o), type = b.toString('ascii', o + 4, o + 8);
    const data = b.slice(o + 8, o + 8 + len);
    if (type === 'IHDR') {
      w = data.readUInt32BE(0); h = data.readUInt32BE(4);
      depth = data[8]; ct = data[9]; interlace = data[12];
    } else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    o += 12 + len;
  }
  if (depth !== 8 || (ct !== 6 && ct !== 2) || interlace !== 0)
    throw new Error(`${file}: unsupported PNG (depth ${depth}, colortype ${ct}, interlace ${interlace})`);
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const ch = ct === 6 ? 4 : 3, stride = w * ch, out = Buffer.alloc(h * stride);
  let p = 0;
  for (let y = 0; y < h; y++) {
    const ft = raw[p++], line = raw.slice(p, p + stride); p += stride;
    for (let x = 0; x < stride; x++) {
      const a = x >= ch ? out[y * stride + x - ch] : 0;
      const bb = y > 0 ? out[(y - 1) * stride + x] : 0;
      const c = (x >= ch && y > 0) ? out[(y - 1) * stride + x - ch] : 0;
      let v = line[x];
      if (ft === 1) v += a;
      else if (ft === 2) v += bb;
      else if (ft === 3) v += (a + bb) >> 1;
      else if (ft === 4) {
        const pp = a + bb - c, pa = Math.abs(pp - a), pb = Math.abs(pp - bb), pc = Math.abs(pp - c);
        v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? bb : c);
      }
      out[y * stride + x] = v & 255;
    }
  }
  return { w, h, ch, d: out };
}

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

// ---------------------------------------------------------------------------
// THE SHEETS. Cell order is reading order: left to right, then top to bottom.
// `kind: 'type'` marks a typeface row whose glyphs must share one baseline.
// ---------------------------------------------------------------------------
const L = 'abcdefghijklmnopqrstuvwxyz'.split('');
const SHEETS = [
  {
    // v17.41 (docs/99) — THE WHOLE WEAPON SET ON ONE SHEET, 28 cells, and the
    // history of how it got here in three lines:
    //   v17.9  (docs/95) 12 CATEGORY cells on i_tod_hud_gun_sheet.png (6x2);
    //   v17.12 (docs/97) +katana +gift as single files (7x2 composite);
    //   v17.40 (docs/98) 20 PER-GUN cells on i_tod_hud_gun_sheet2.png (5x4),
    //          the six category cells (smg rifle lmg shotgun pistol akimbo)
    //          RETIRED — "the RPK and the Stoner have the same image";
    //   v17.41 (docs/99) all 28 redrawn TOGETHER on this sheet so that a Black
    //          Ops player can name each gun from the icon (Magnum was a
    //          carbine, Nail Gun a compressor, Death Machine a box, RPG a tube)
    //          and so the set carries ONE line weight — two passes already
    //          differed, a third touching half would have put three on one HUD.
    // Order is by the CLASS that carries the weapon (skirmisher 1-6, assault
    // 7-12, heavy 13-18, slasher 19-26, extras 27-28), so each row on screen
    // reads as one player's kit and every promotion is a bigger gun of the same
    // family beside the last. The 28 NAMES are unchanged from v17.40 — the
    // GDT, the zone and the Lua tables did not move; only this row did.
    // Drop: files - 2026-09-04T173900.362.zip, exactly 2016x528 as asked.
    // The two older masters stay in _sheets/ as history and are not read.
    file: 'i_tod_hud_gun_sheet3.png', w: 2016, h: 528, cw: 288, ch: 132, cols: 7, rows: 4,
    names: ['mac10', 'mp5', 'mp7', 'bulldog', 'sg12', 'spas12', 'enfield',
            'krig6', 'ak47', 'magnum', 'mog12', 'executioner', 'stoner63', 'hk21',
            'minigun', 'mr6', 'launcher', 'nailgun', 'blade', 'katana', 'axe',
            'amp63', 'udm', 'rk7', 'executioner_akimbo', 'amp63_akimbo', 'gift', 'shield'].map(n => 'i_tod_hud_gun_' + n),
  },
  {
    // v18.58 (docs/124) — THE MAGE'S THREE STAFFS, on the sheet3 cell exactly.
    // They are a fourth row of the gun set in every way but the file: same
    // 288x132 cell, same three tones, and they share the loadout panel's one
    // icon slot with the 28 above. They arrived as their own sheet rather than
    // a re-cut sheet3 because their SUBJECTS were already right — the docs/120
    // mage drop drew them beside 25 upgrade CARDS instead of beside these guns,
    // and came back with coloured gems, five tones and half the ink coverage of
    // the set. Re-cutting all 31 to fix three would have risked the 28.
    // Measured on the drop, against the 28's own figures: ink 29.8-33.6%
    // (set mean 36.1, floor 19.7), bright saturated pixels 0.55-0.64% (set mean
    // 0.2, and blade/katana are 0.6/0.5), tones exactly 3, palette exactly
    // #E8EEF6 / #62779C / #0A1020. The old cells were 16-19% ink, 12-14%
    // saturated and 5 tones. Order is the TOD_GUN_CAT order in
    // AetheriumLoadout.lua, which is the ELEMENT and not a tier:
    // staff1 lightning, staff2 fire, staff3 ice.
    // Drop: files - 2026-09-09T030612.703.zip, exactly 864x132 as asked; its
    // three loose cells were byte-identical to these slices (0 differing px).
    file: 'i_tod_hud_gun_staff_sheet.png', w: 864, h: 132, cw: 288, ch: 132, cols: 3, rows: 1,
    names: ['staff1', 'staff2', 'staff3'].map(n => 'i_tod_hud_gun_' + n),
  },
  {
    // v17.12: 3x1 -> 4x1. "web" RETIRED and replaced by "spider" — a grenade
    // with a web drawn on it is unreadable at 36x36, and a spider silhouette is
    // not. "spider_phd" is the same spider in violet, for a player holding
    // Widow's Wine AND PhD Flopper; the two are selected from perk state, which
    // is the only channel that can tell those apart (PhD changes what the
    // grenade DOES, not which weapon is held).
    file: 'i_tod_hud_offhand_sheet.png', w: 512, h: 128, cw: 128, ch: 128, cols: 4, rows: 1,
    names: ['monkey', 'frag', 'spider', 'spider_phd'].map(n => 'i_tod_hud_off_' + n),
  },
  {
    // v17.33 — THE PACK-A-PUNCH TIER BADGE. Three cells, one per pack level,
    // drawn as one image for the same reason every other sheet here is: the
    // escalation I -> II -> III only reads if the three share a stroke weight
    // and a fill logic, and three separately-generated glyphs do not.
    // Same 128x128 cell as the offhand glyphs — the badge is drawn into the
    // same 24x24 canvas box, so it must carry the same ink margins.
    // v17.60: the shipped cells are docs/102's COMMISSIONED machine glyphs
    // (1/2/3 bolts), delivered as loose 128x128 files, not a sheet — so no
    // i_tod_hud_pap_sheet.png exists and this entry is dormant. A future sheet
    // drop slices through it; do NOT rebuild the sheet from the placeholder.
    file: 'i_tod_hud_pap_sheet.png', w: 384, h: 128, cw: 128, ch: 128, cols: 3, rows: 1,
    names: ['1', '2', '3'].map(n => 'i_tod_hud_pap_' + n),
  },
  {
    file: 'i_tod_hud_digits.png', w: 1664, h: 160, cw: 128, ch: 160, cols: 13, rows: 1, kind: 'type', set: 'digits',
    chars: '0123456789/+-'.split(''),
    names: ['d0', 'd1', 'd2', 'd3', 'd4', 'd5', 'd6', 'd7', 'd8', 'd9',
            'dslash', 'dplus', 'ddash'].map(n => 'i_tod_hud_' + n),
  },
  {
    file: 'i_tod_hud_letters.png', w: 1200, h: 224, cw: 80, ch: 112, cols: 15, rows: 2, kind: 'type', set: 'letters',
    chars: L.concat(['-', "'", '$', '.']),
    names: L.map(c => 'i_tod_hud_l' + c)
      .concat(['i_tod_hud_lhyphen', 'i_tod_hud_lapos', 'i_tod_hud_lmoney', 'i_tod_hud_ldot']),
    // ---------------------------------------------------------------------
    // CELL 28 WAS THE AMPERSAND AND IS NOW THE MONEY SYMBOL (v19.2, user:
    // "Our HUD uses this symbol in the player HUD when showing amount of money
    // you have. You can reuse that"). The delivered ampersand read as an "8" at
    // every size, so it was SKIPPED and AetheriumLoadout expands "&" to " AND "
    // — a dead cell in a sheet that is otherwise exactly full (15x2 = 30 cells
    // for 30 characters). The map's own points icon is composited into it, on
    // the ampersand's own ink bottom so the row's baseline check is unchanged,
    // and its advance is MEASURED from the new art like every other glyph.
    // "&" keeps expanding to " AND "; nothing rendered it before and nothing
    // does now. If a corrected ampersand ever lands it needs a NEW cell, not
    // this one.
    // ---------------------------------------------------------------------
  },
];

// ---------------------------------------------------------------------------
// ink bounding box of one cell, from its alpha channel
// ---------------------------------------------------------------------------
const A_MIN = 24;   // below this an "edge" is antialiasing, not ink
function inkBox(img, x0, y0, cw, ch) {
  let minX = 1e9, maxX = -1, minY = 1e9, maxY = -1;
  for (let y = 0; y < ch; y++) {
    for (let x = 0; x < cw; x++) {
      const i = ((y0 + y) * img.w + (x0 + x)) * img.ch;
      const a = img.ch === 4 ? img.d[i + 3] : 255;
      if (a < A_MIN) continue;
      if (x < minX) minX = x; if (x > maxX) maxX = x;
      if (y < minY) minY = y; if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return null;
  return { x0: minX, x1: maxX, y0: minY, y1: maxY, w: maxX - minX + 1, h: maxY - minY + 1 };
}

function cut(img, x0, y0, cw, ch) {
  const out = { w: cw, h: ch, ch: 4, d: Buffer.alloc(cw * ch * 4) };
  for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
    const s = ((y0 + y) * img.w + (x0 + x)) * img.ch, t = (y * cw + x) * 4;
    out.d[t] = img.d[s]; out.d[t + 1] = img.d[s + 1]; out.d[t + 2] = img.d[s + 2];
    out.d[t + 3] = img.ch === 4 ? img.d[s + 3] : 255;
  }
  return out;
}

// ---------------------------------------------------------------------------
if (WIRE) {
  const all = [];
  for (const S of SHEETS) S.names.forEach(n => { if (!(S.skip || []).includes(n)) all.push(n); });
  all.push('i_tod_hud_weapon_panel', 'i_tod_hud_offhand_tile');
  console.log('// ---- zone_source/zm_tower_of_doom.zone ----');
  for (const n of all) console.log('image,' + n);
  console.log('\n// ---- source_data/tod_ui_images.gdt ----');
  for (const n of all) {
    console.log(`\t"${n}.png" ( "image.gdf" )`);
    console.log('\t{');
    console.log('\t\t"baseImage" "tod_ui_images/_images/' + n + '.png"');
    console.log('\t\t"colorSRGB" "1"');
    console.log('\t\t"compressionMethod" "uncompressed"');
    console.log('\t\t"coreSemantic" "sRGB3chAlpha"');
    console.log('\t\t"imageType" "Texture"');
    console.log('\t\t"noPicMip" "1"');
    console.log('\t\t"semantic" "diffuseMap"');
    console.log('\t\t"type" "image"');
    console.log('\t}');
  }
  process.exit(0);
}

let problems = 0, written = 0;
const metrics = {};
// v17.33 — WHICH SHEETS WERE ACTUALLY READ. See the metrics guard below.
const sliced = new Set();

for (const S of SHEETS) {
  const p = path.join(SRC, S.file);
  if (!fs.existsSync(p)) { console.log(`MISSING  ${S.file}`); problems++; continue; }
  const img = decodePNG(p);
  sliced.add(S.file);

  // GATE 1 — exact canvas. The cutting is arithmetic; two pixels wrong here
  // slices every cell wrong and nothing downstream would notice.
  if (img.w !== S.w || img.h !== S.h) {
    console.log(`SIZE     ${S.file}: got ${img.w}x${img.h}, need ${S.w}x${S.h}`);
    problems++; continue;
  }
  if (img.ch !== 4) { console.log(`ALPHA    ${S.file}: no alpha channel`); problems++; continue; }
  if (S.names.length !== S.cols * S.rows) {
    console.log(`CONFIG   ${S.file}: ${S.names.length} names for ${S.cols * S.rows} cells`);
    problems++; continue;
  }

  console.log(`\n${S.file}  ${img.w}x${img.h}  ${S.cols}x${S.rows} of ${S.cw}x${S.ch}`);
  const rowsInk = [];

  for (let i = 0; i < S.names.length; i++) {
    const c = i % S.cols, r = Math.floor(i / S.cols);
    const x0 = c * S.cw, y0 = r * S.ch;
    const box = inkBox(img, x0, y0, S.cw, S.ch);
    const name = S.names[i];
    const skipped = (S.skip || []).includes(name);

    if (!box) { console.log(`  EMPTY  cell ${i} (${name})`); problems++; continue; }

    // GATE 2 — nothing may touch a cell boundary. A glyph that bleeds into its
    // neighbour cuts into the next image and there is no visual tell on the
    // sheet itself.
    const touches = box.x0 === 0 || box.y0 === 0 || box.x1 === S.cw - 1 || box.y1 === S.ch - 1;
    if (touches) { console.log(`  BLEED  cell ${i} (${name}) ink touches the cell edge`); problems++; }

    if (S.kind === 'type') {
      if (!rowsInk[r]) rowsInk[r] = [];
      // A skipped cell still counts toward the BASELINE check — it is drawn on
      // the sheet and its alignment is evidence about the sheet — but it must
      // NOT get a metrics entry, because there is no image for the renderer to
      // draw. A metric without art is the same half-retirement as art without a
      // zone line: one of them is dead weight and the other is a white square.
      rowsInk[r].push({ i, name, ch: S.chars[i], box });
      // KEYED BY SET, not flat. Both sheets carry a "-" and they are DIFFERENT
      // GLYPHS: the digit sheet's is the wide no-magazine marker a blade shows
      // in place of an ammo count, the letter sheet's is the in-word hyphen in
      // "AK-47". A flat table lets whichever sheet is processed last silently
      // overwrite the other, and the tell would have been a subtly wrong dash in
      // one of two places — the kind of thing that ships.
      if (!skipped) {
        const set = S.set;
        metrics[set] = metrics[set] || { cw: S.cw, ch: S.ch, g: {} };
        metrics[set].g[S.chars[i]] = { adv: box.w, x: box.x0, w: box.w };
      }
    }

    const flag = skipped ? '  [SKIPPED - see the note in the SHEETS table]' : '';
    console.log(`  cell ${String(i).padStart(2)}  ${name.padEnd(22)} ink ${String(box.w).padStart(3)}x${String(box.h).padStart(3)}` +
                ` at (${String(box.x0).padStart(3)},${String(box.y0).padStart(3)})${flag}`);

    if (!CHECK && !skipped) {
      fs.writeFileSync(path.join(OUT_DIR, name + '.png'), encodePNG(cut(img, x0, y0, S.cw, S.ch)));
      written++;
    }
  }

  // GATE 3 — ONE BASELINE PER TYPEFACE ROW. A glyph sitting high or low makes
  // the ammo counter visibly bounce as the number changes, and that is not
  // something anyone spots by looking at a sheet.
  //
  // ⚠️ THIS GATE WAS WRONG THE FIRST TIME IT RAN, and the way it was wrong is
  // worth keeping. It measured max-minus-min y1 across the whole row, which
  // reported the 2026-09-03 drop as having a 40px baseline spread on the digits
  // and 9px on the letters. Both readings were false, and for two DIFFERENT
  // reasons — each of them a shape the brief had explicitly ASKED FOR:
  //   * "+" is drawn deliberately HIGH (it is a count prefix, "+3", so it is
  //     centred on the digits' upper half, not on the baseline). "-" likewise
  //     sits at mid height. A spread test that includes them measures the
  //     design, not an error.
  //   * "Q" has a descending tail, because the brief asked for "a bold tail
  //     that breaks the outline" so it cannot be confused with O. A descender
  //     is CORRECT and min/max cannot tell it from a dropped glyph.
  // A gate that fires on the thing you asked for gets ignored, and then it is
  // not a gate. So: skip the marks that are off-baseline by design, measure
  // against the MEDIAN rather than the extremes, and NAME the outliers instead
  // of reporting a number nobody can act on.
  // "$" JOINS THE MARKS (v19.2). It is the map's own points icon dropped into
  // cell 28, not a drawn letter, so it is no more cap-height than "." or "'" —
  // and it must be out of the MEDIAN too, or one symbol would drag the letters'
  // measured cap down and re-space the whole sheet. Same reasoning the other
  // four marks are here for.
  const OFF_BASELINE = "+-'.$";       // by design, per the prompts in docs/95
  const DESCENDERS = 'qQ';            // by design, same
  for (let r = 0; r < rowsInk.length; r++) {
    const row = (rowsInk[r] || []).filter(g => !OFF_BASELINE.includes(g.ch));
    if (row.length < 3) continue;
    const med = arr => { const s = [...arr].sort((a, b) => a - b); return s[Math.floor(s.length / 2)]; };
    const baseline = med(row.map(g => g.box.y1));
    const capMed = med(row.map(g => g.box.h));
    // Hand the measured baseline and cap height to the renderer. A NAME mixes
    // both sheets ("AK-47", "MP117 REDACTOR"), and the two were drawn on
    // different cells — digits 128x160 with a 137 cap, letters 80x112 with an
    // 89 cap. Without these the Lua would need two hardcoded ratios to sit them
    // on one line, i.e. exactly the second source of truth this tool exists to
    // avoid. Measured once, per set, from the art.
    if (S.set && metrics[S.set]) {
      const m = metrics[S.set];
      if (m.baseline === undefined || r === 0) { m.baseline = baseline; m.cap = capMed; }
    }
    const off = row.filter(g => Math.abs(g.box.y1 - baseline) > 6 && !DESCENDERS.includes(g.ch));
    const cap = row.filter(g => Math.abs(g.box.h - capMed) > 9);
    console.log(`  row ${r}: baseline y1=${baseline}, cap height ${capMed}` +
                `  (${row.length} glyph(s) measured; ${OFF_BASELINE.split('').filter(c => (rowsInk[r] || []).some(g => g.ch === c)).length} off-baseline mark(s) excluded by design)`);
    if (off.length) {
      console.log(`  BASELINE row ${r}: ${off.map(g => `"${g.ch}" ${g.box.y1 - baseline > 0 ? '+' : ''}${g.box.y1 - baseline}px`).join(', ')} — the line will visibly step`);
      problems++;
    }
    if (cap.length) {
      console.log(`  CAPHEIGHT row ${r}: ${cap.map(g => `"${g.ch}" ${g.box.h - capMed > 0 ? '+' : ''}${g.box.h - capMed}px`).join(', ')}`);
      problems++;
    }
  }
}

// ---------------------------------------------------------------------------
// EMIT THE DERIVED METRICS
// ---------------------------------------------------------------------------
// v17.33 GUARD — DO NOT EMIT A PARTIAL TYPEFACE.
//
// The delivered sheets are consumed and not kept in the repo; only the sliced
// cells ship. So a later run that slices ONE new sheet (adding the PaP badge was
// the first) finds i_tod_hud_digits.png and i_tod_hud_letters.png MISSING,
// measures no glyphs for them, and — before this guard — wrote TodGlyphMetrics.lua
// out anyway with whatever it did measure. That silently DELETES the advance
// table for the entire shipped typeface: every number and every weapon name in
// the gun HUD, the round readout included, laid out on missing metrics.
//
// The metrics file is all-or-nothing, so its write is too. If any type sheet is
// absent the existing file is left exactly as it is and the run says so.
const typeSheets = SHEETS.filter(S => S.kind === 'type');
const typeMissing = typeSheets.filter(S => !sliced.has(S.file));
if (!CHECK && typeMissing.length && typeSheets.length !== typeMissing.length) {
  console.log(`\nNOTE: metrics NOT rewritten — ${typeMissing.map(S => S.file).join(', ')} absent.`);
  console.log('      TodGlyphMetrics.lua left untouched. Re-slice with every type sheet present to regenerate it.');
}
if (!CHECK && !typeMissing.length && Object.keys(metrics).length) {
  const esc = c => (c === '\\' ? '\\\\' : c === '"' ? '\\"' : c);
  const lines = [];
  lines.push('-- GENERATED by tools/slice_hud_sheets.js — DO NOT EDIT BY HAND.');
  lines.push('--');
  lines.push('-- Advance widths for the custom HUD typeface, MEASURED from the delivered');
  lines.push('-- sheets\' own alpha channels. Hand-authoring these would create a second');
  lines.push('-- source of truth that nothing regenerates; deriving them means a redrawn');
  lines.push('-- glyph re-spaces itself on the next slice and the art cannot drift from its');
  lines.push('-- metrics. Same doctrine as the generated _tod_door_data.gsc.');
  lines.push('--');
  lines.push('--   cw/ch     the cell each glyph was cut from');
  lines.push('--   baseline  y of the baseline WITHIN that cell');
  lines.push('--   cap       cap height in cell pixels');
  lines.push('--   g[c].adv  ink width in SOURCE pixels; g[c].x its left edge');
  lines.push('--');
  lines.push('-- KEYED BY SET because both sheets carry a "-" and they are different');
  lines.push('-- glyphs: digits["-"] is the wide marker a weapon with no magazine shows in');
  lines.push('-- place of an ammo count, letters["-"] is the in-word hyphen in "AK-47".');
  lines.push('');
  lines.push('CoD.TodGlyphMetrics = {');
  for (const [set, m] of Object.entries(metrics)) {
    lines.push(`\t${set} = {`);
    lines.push(`\t\tcw = ${m.cw}, ch = ${m.ch}, baseline = ${m.baseline}, cap = ${m.cap},`);
    lines.push('\t\tg = {');
    for (const [c, gm] of Object.entries(m.g)) {
      lines.push(`\t\t\t["${esc(c)}"] = { adv = ${gm.adv}, x = ${gm.x}, w = ${gm.w} },`);
    }
    lines.push('\t\t},');
    lines.push('\t},');
  }
  lines.push('}');
  lines.push('');
  fs.writeFileSync(METRICS, lines.join('\n'), 'utf8');
  const counts = Object.entries(metrics).map(([k, v]) => `${k} ${Object.keys(v.g).length}`).join(', ');
  console.log(`\nmetrics -> ${path.relative(REPO, METRICS)}  (${counts})`);
}

// THE MANIFEST IS NOT GATED ON THE METRICS. v17.33: it used to be written from
// inside the block above, which meant a run that could not regenerate the
// typeface also could not register a NEW image name for GATE A — and the run
// that adds a sheet is exactly the run where both of those are true at once.
// Its contents come from the SHEETS table alone, never from measured data, so
// it is always safe to write.
if (!CHECK) {
  const shipped = [];
  for (const S of SHEETS) for (const n of S.names) if (!(S.skip || []).includes(n)) shipped.push(n);
  // Standalone files — delivered whole rather than cut from a sheet, so they
  // are not in any SHEETS row and must be listed by hand.
  shipped.push('i_tod_hud_weapon_panel', 'i_tod_hud_offhand_tile', 'i_tod_hud_pap_tile');
  fs.writeFileSync(MANIFEST, JSON.stringify({
    why: 'GENERATED by tools/slice_hud_sheets.js. Read by tools/lint_tod_assets.js so GATE A '
       + 'covers the gun-HUD images, whose names AetheriumLoadout.lua builds by concatenation '
       + 'and which a Lua-literal scan therefore cannot see. Do not edit by hand.',
    images: shipped.sort(),
  }, null, 2) + '\n');
  console.log(`manifest -> ${path.relative(REPO, MANIFEST)}  (${shipped.length} shipped image name(s))`);
}

console.log(`\n${CHECK ? 'CHECK' : 'SLICE'}: ${written} image(s) written, ${problems} problem(s)`);
process.exit(problems ? 1 : 0);
