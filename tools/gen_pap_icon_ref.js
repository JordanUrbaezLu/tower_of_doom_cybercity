// =============================================================================
// gen_pap_icon_ref.js — docs/131: why the PaP tier badge reads worse than the
// two offhand tiles that sit on the same HUD row, at the same size.
//
// User, 2026-09-10, with a screenshot: "Our pap icon looks like ass in game.
// But both blink and healing aura look great."
//
// THE POINT THIS TOOL EXISTS TO PROVE: it is not a resolution problem and not a
// box problem. Read straight off AetheriumLoadout.lua:
//
//   offhand icon  x0+5 .. x0+29, 572..596   = 24 x 24 canvas units
//   PaP glyph     x0+4 .. x0+30, 571..597   = 26 x 26 canvas units
//
// The PaP glyph gets a BIGGER box than blink and heal and still loses. So the
// fault is composition and contrast inside the cell, which is what the metrics
// below measure. (Same lesson as memory `low-detail-is-rarely-low-resolution`:
// measure how the cell is used before asking for more pixels.)
//
// The metric that carries the argument is LARGEST CONNECTED INK COMPONENT as a
// share of all ink. One bold symbol scores near 100%; two half-size objects
// sharing a cell score near 50-60%, and at 39 px neither of them survives.
//
// Output, into docs/131_pap_ref/:
//   pap_vs_offhand.png    all five icons at 4x, good set beside bad set, on the
//                         HUD's own near-black, with the real on-screen row
//                         underneath at true 1080p size for the honest read
//   onscreen_row.png      just that true-size row, isolated
//
//   node tools/gen_pap_icon_ref.js
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const REPO = path.resolve(__dirname, '..');
const IMG = path.join(REPO, 'source_data', 'tod_ui_images', '_images');
const REF = path.join(REPO, 'docs', '131_pap_ref');

// LUI canvas is 1280x720; at 1920x1080 every canvas unit is 1.5 real pixels.
// (Same factor derived in tools/gen_staff_likeness_ref.js from the gun bay.)
const SCALE_1080 = 1.5;
const PAP_BOX = 26;                       // canvas units, AetheriumLoadout.lua:1443
const OFF_BOX = 24;                       // canvas units, AetheriumLoadout.lua:1346
const PAP_PX = Math.round(PAP_BOX * SCALE_1080);   // 39
const OFF_PX = Math.round(OFF_BOX * SCALE_1080);   // 36

const BAD = [
  { slug: 'i_tod_hud_pap_1', label: 'PAP 1', px: PAP_PX },
  { slug: 'i_tod_hud_pap_2', label: 'PAP 2', px: PAP_PX },
  { slug: 'i_tod_hud_pap_3', label: 'PAP 3', px: PAP_PX },
];
const GOOD = [
  { slug: 'i_tod_hud_off_blink', label: 'BLINK', px: OFF_PX },
  { slug: 'i_tod_hud_off_heal', label: 'HEAL', px: OFF_PX },
];

// ---------------------------------------------------------------------------
// PNG codec (8-bit RGBA/RGB, non-interlaced) — same shape as tools/slice_gauge.js
// ---------------------------------------------------------------------------
function decodePNG(file) {
  const b = fs.readFileSync(file);
  let o = 8, w, h, ct, depth, il;
  const idat = [];
  while (o < b.length) {
    const len = b.readUInt32BE(o), t = b.toString('ascii', o + 4, o + 8);
    const d = b.slice(o + 8, o + 8 + len);
    if (t === 'IHDR') { w = d.readUInt32BE(0); h = d.readUInt32BE(4); depth = d[8]; ct = d[9]; il = d[12]; }
    else if (t === 'IDAT') idat.push(d);
    else if (t === 'IEND') break;
    o += 12 + len;
  }
  if (depth !== 8 || (ct !== 6 && ct !== 2) || il !== 0) {
    throw new Error(path.basename(file) + ': unsupported PNG (depth ' + depth + ' colourtype ' + ct + ')');
  }
  const bpp = ct === 6 ? 4 : 3;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const st = w * bpp, lines = Buffer.alloc(h * st);
  let p = 0;
  for (let y = 0; y < h; y++) {
    const ft = raw[p++], ln = raw.slice(p, p + st); p += st;
    for (let x = 0; x < st; x++) {
      const a = x >= bpp ? lines[y * st + x - bpp] : 0;
      const bb = y > 0 ? lines[(y - 1) * st + x] : 0;
      const c = (x >= bpp && y > 0) ? lines[(y - 1) * st + x - bpp] : 0;
      let v = ln[x];
      if (ft === 1) v += a; else if (ft === 2) v += bb; else if (ft === 3) v += (a + bb) >> 1;
      else if (ft === 4) {
        const pp = a + bb - c, pa = Math.abs(pp - a), pb = Math.abs(pp - bb), pc = Math.abs(pp - c);
        v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? bb : c);
      }
      lines[y * st + x] = v & 255;
    }
  }
  if (bpp === 4) return { w: w, h: h, d: lines };
  const out = Buffer.alloc(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    out[i * 4] = lines[i * 3]; out[i * 4 + 1] = lines[i * 3 + 1];
    out[i * 4 + 2] = lines[i * 3 + 2]; out[i * 4 + 3] = 255;
  }
  return { w: w, h: h, d: out };
}

const CRC_T = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c; }
  return t;
})();
function crc32(buf) { let c = 0xFFFFFFFF; for (let i = 0; i < buf.length; i++) c = CRC_T[(c ^ buf[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function encodePNG(img) {
  const st = img.w * 4, raw = Buffer.alloc(img.h * (st + 1));
  for (let y = 0; y < img.h; y++) { raw[y * (st + 1)] = 0; img.d.copy(raw, y * (st + 1) + 1, y * st, y * st + st); }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.w, 0); ihdr.writeUInt32BE(img.h, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

// ---------------------------------------------------------------------------
function blank(w, h, rgba) {
  const d = Buffer.alloc(w * h * 4);
  for (let i = 0; i < w * h; i++) { d[i * 4] = rgba[0]; d[i * 4 + 1] = rgba[1]; d[i * 4 + 2] = rgba[2]; d[i * 4 + 3] = rgba[3]; }
  return { w: w, h: h, d: d };
}
// nearest-neighbour: keeps the 4x boards honest about the real pixel grid
function scaleNN(im, w, h) {
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    const sy = Math.min(im.h - 1, Math.floor(y * im.h / h));
    for (let x = 0; x < w; x++) {
      const sx = Math.min(im.w - 1, Math.floor(x * im.w / w));
      im.d.copy(out, (y * w + x) * 4, (sy * im.w + sx) * 4, (sy * im.w + sx) * 4 + 4);
    }
  }
  return { w: w, h: h, d: out };
}
// box-average: what the GPU actually does shrinking 128 -> 39, so the true-size
// row shows the blur the player sees rather than a crisp lie
function scaleBox(im, w, h) {
  const out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    const y0 = Math.floor(y * im.h / h), y1 = Math.max(y0 + 1, Math.floor((y + 1) * im.h / h));
    for (let x = 0; x < w; x++) {
      const x0 = Math.floor(x * im.w / w), x1 = Math.max(x0 + 1, Math.floor((x + 1) * im.w / w));
      let r = 0, g = 0, b = 0, a = 0, n = 0;
      for (let sy = y0; sy < y1; sy++) for (let sx = x0; sx < x1; sx++) {
        const o = (sy * im.w + sx) * 4, al = im.d[o + 3] / 255;
        r += im.d[o] * al; g += im.d[o + 1] * al; b += im.d[o + 2] * al; a += im.d[o + 3]; n++;
      }
      const o = (y * w + x) * 4, aa = a / n;
      const wsum = (aa / 255) * n || 1;
      out[o] = Math.round(r / wsum); out[o + 1] = Math.round(g / wsum);
      out[o + 2] = Math.round(b / wsum); out[o + 3] = Math.round(aa);
    }
  }
  return { w: w, h: h, d: out };
}
function paste(dst, src, dx, dy) {
  for (let y = 0; y < src.h; y++) {
    const ty = dy + y; if (ty < 0 || ty >= dst.h) continue;
    for (let x = 0; x < src.w; x++) {
      const tx = dx + x; if (tx < 0 || tx >= dst.w) continue;
      const s = (y * src.w + x) * 4, t = (ty * dst.w + tx) * 4;
      const a = src.d[s + 3] / 255;
      if (a <= 0) continue;
      for (let c = 0; c < 3; c++) dst.d[t + c] = Math.round(src.d[s + c] * a + dst.d[t + c] * (1 - a));
      dst.d[t + 3] = Math.max(dst.d[t + 3], src.d[s + 3]);
    }
  }
}
function rect(dst, x, y, w, h, rgb) {
  for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) {
    if (i < 0 || j < 0 || i >= dst.w || j >= dst.h) continue;
    const o = (j * dst.w + i) * 4;
    dst.d[o] = rgb[0]; dst.d[o + 1] = rgb[1]; dst.d[o + 2] = rgb[2]; dst.d[o + 3] = 255;
  }
}

// ---------------------------------------------------------------------------
// the metrics
// ---------------------------------------------------------------------------
// ink coverage, saturated share and tones use the SAME definitions as
// tools/gen_staffhud_ref.js::stat so numbers stay comparable across docs.
// biggest/blobs are new here and are the ones that carry this brief.
function stat(slug) {
  const im = decodePNG(path.join(IMG, slug + '.png'));
  const w = im.w, h = im.h, d = im.d;
  let ink = 0, satHi = 0;
  const cols = new Map();
  const on = new Uint8Array(w * h);
  let bx0 = 1e9, by0 = 1e9, bx1 = -1, by1 = -1;
  for (let i = 0; i < w * h; i++) {
    const o = i * 4;
    if (d[o + 3] < 128) continue;
    ink++; on[i] = 1;
    const x = i % w, y = (i - x) / w;
    if (x < bx0) bx0 = x; if (x > bx1) bx1 = x;
    if (y < by0) by0 = y; if (y > by1) by1 = y;
    const r = d[o], g = d[o + 1], b = d[o + 2];
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
    if (mx > 90 && (mx - mn) / mx > 0.40) satHi++;
    const k = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
    cols.set(k, (cols.get(k) || 0) + 1);
  }
  let tones = 0;
  cols.forEach(function (n) { if (n > ink * 0.02) tones++; });

  // connected components over inked pixels (4-neighbour), largest as % of ink
  const seen = new Uint8Array(w * h);
  const sizes = [];
  const stack = new Int32Array(w * h);
  for (let i = 0; i < w * h; i++) {
    if (!on[i] || seen[i]) continue;
    let sp = 0, n = 0;
    stack[sp++] = i; seen[i] = 1;
    while (sp > 0) {
      const p = stack[--sp]; n++;
      const x = p % w, y = (p - x) / w;
      if (x > 0 && on[p - 1] && !seen[p - 1]) { seen[p - 1] = 1; stack[sp++] = p - 1; }
      if (x < w - 1 && on[p + 1] && !seen[p + 1]) { seen[p + 1] = 1; stack[sp++] = p + 1; }
      if (y > 0 && on[p - w] && !seen[p - w]) { seen[p - w] = 1; stack[sp++] = p - w; }
      if (y < h - 1 && on[p + w] && !seen[p + w]) { seen[p + w] = 1; stack[sp++] = p + w; }
    }
    sizes.push(n);
  }
  sizes.sort((a, b) => b - a);
  const big = sizes.filter(n => n > ink * 0.02);   // blobs carrying >=2% of ink

  return {
    w: w, h: h,
    ink: 100 * ink / (w * h),
    sat: 100 * satHi / ink,
    tones: tones,
    biggest: 100 * (sizes[0] || 0) / ink,
    blobs: big.length,
    bbox: 100 * ((bx1 - bx0 + 1) * (by1 - by0 + 1)) / (w * h),
  };
}

const rows = [];
GOOD.concat(BAD).forEach(function (e) { rows.push({ e: e, s: stat(e.slug) }); });

const num = (v, dp) => v.toFixed(dp === undefined ? 1 : dp);
console.log('');
console.log('  icon                  box   ink%  sat%  tones  biggest blob%  blobs>=2%  bbox%');
rows.forEach(function (r) {
  console.log('  ' + r.e.slug.padEnd(22) + String(r.e.px + 'px').padEnd(6) +
    num(r.s.ink).padStart(5) + num(r.s.sat).padStart(6) + String(r.s.tones).padStart(6) +
    num(r.s.biggest).padStart(14) + String(r.s.blobs).padStart(10) + num(r.s.bbox).padStart(8));
});
const gm = k => GOOD.reduce((a, e) => a + rows.find(r => r.e.slug === e.slug).s[k], 0) / GOOD.length;
const bm = k => BAD.reduce((a, e) => a + rows.find(r => r.e.slug === e.slug).s[k], 0) / BAD.length;
console.log('');
console.log('  GOOD mean (blink, heal)   ' + num(gm('ink')).padStart(9) + num(gm('sat')).padStart(6) +
  num(gm('tones')).padStart(6) + num(gm('biggest')).padStart(14) + num(gm('blobs')).padStart(10) + num(gm('bbox')).padStart(8));
console.log('  BAD mean (pap 1..3)       ' + num(bm('ink')).padStart(9) + num(bm('sat')).padStart(6) +
  num(bm('tones')).padStart(6) + num(bm('biggest')).padStart(14) + num(bm('blobs')).padStart(10) + num(bm('bbox')).padStart(8));
console.log('');

// ---------------------------------------------------------------------------
// the boards
// ---------------------------------------------------------------------------
const GROUND = [16, 20, 32, 255];     // the HUD's own near-black
const RULE = [90, 112, 150];
const Z = 4;                          // 128 -> 512 on the study board
const PAD = 20, GAP = 24;

fs.mkdirSync(REF, { recursive: true });

// board 1: the five icons at 4x, good | bad, plus the true-size row beneath
(function () {
  const cellW = 128 * Z, cellH = 128 * Z;
  const gw = GOOD.length * cellW + (GOOD.length - 1) * GAP;
  const bw = BAD.length * cellW + (BAD.length - 1) * GAP;
  const W = PAD + gw + GAP * 2 + 1 + GAP * 2 + bw + PAD;
  const rowH = 96;
  const H = PAD + cellH + GAP + rowH + PAD;
  const board = blank(W, H, GROUND);

  let x = PAD;
  GOOD.forEach(function (e) {
    paste(board, scaleNN(decodePNG(path.join(IMG, e.slug + '.png')), cellW, cellH), x, PAD);
    x += cellW + GAP;
  });
  x = x - GAP + GAP * 2;
  rect(board, x, PAD, 2, cellH, RULE);
  x += 2 + GAP * 2;
  BAD.forEach(function (e) {
    paste(board, scaleNN(decodePNG(path.join(IMG, e.slug + '.png')), cellW, cellH), x, PAD);
    x += cellW + GAP;
  });

  // true on-screen size, in HUD order, box-filtered like the GPU does
  let rx = PAD;
  const ry = PAD + cellH + GAP + Math.round((rowH - PAP_PX) / 2);
  GOOD.concat(BAD).forEach(function (e) {
    paste(board, scaleBox(decodePNG(path.join(IMG, e.slug + '.png')), e.px, e.px), rx, ry);
    rx += e.px + 16;
  });

  fs.writeFileSync(path.join(REF, 'pap_vs_offhand.png'), encodePNG(board));
  console.log('  docs/131_pap_ref/pap_vs_offhand.png  ' + W + 'x' + H);
})();

// board 2: the true-size row alone, nothing to distract from how small it is
(function () {
  const all = GOOD.concat(BAD);
  const W = PAD * 2 + all.reduce((a, e) => a + e.px + 16, 0) - 16;
  const H = PAD * 2 + PAP_PX;
  const board = blank(W, H, GROUND);
  let x = PAD;
  all.forEach(function (e) {
    paste(board, scaleBox(decodePNG(path.join(IMG, e.slug + '.png')), e.px, e.px),
      x, PAD + Math.round((PAP_PX - e.px) / 2));
    x += e.px + 16;
  });
  fs.writeFileSync(path.join(REF, 'onscreen_row.png'), encodePNG(board));
  console.log('  docs/131_pap_ref/onscreen_row.png    ' + W + 'x' + H +
    '   (blink/heal ' + OFF_PX + 'px, pap ' + PAP_PX + 'px at 1080p)');
})();
console.log('');
