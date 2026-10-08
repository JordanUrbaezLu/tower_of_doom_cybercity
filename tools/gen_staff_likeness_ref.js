// =============================================================================
// gen_staff_likeness_ref.js — docs/128: the mage staff LIKENESS reference.
//
// The problem docs/128 exists to fix is that the six shipped mage assets (three
// weapon HUD icons, three class/tier cards) draw staffs that do not resemble the
// staffs actually held in game. The in-game staffs are the ported BO3 Origins
// elemental staffs: a shared shaft (tod_staff_view) plus a per-element tip
// (tod_staff_tip_lightning|fire|water_view).
//
// docs/124's board proved a STYLE gap by measuring ink/saturation/tones. This is
// a different claim — a SUBJECT gap — so the useful artefact is not a statistic,
// it is a legible picture of each real staff head beside the icon that is meant
// to depict it.
//
// Output, into docs/128_staff_ref/:
//   head_<elem>.png            a 2x close-up of the staff head, cropped from the
//                              first-person screenshot and nearest-neighbour
//                              doubled so the silhouette reads at a glance
//   icon_vs_head_<elem>.png    that close-up beside the CURRENT shipped icon at
//                              2x its true on-screen size (288x132 -> 144x66 on
//                              screen -> 288x132 here), on one neutral ground
//
// Crops were read off the three screenshots by hand; they are stated as
// fractions of each image so they survive a re-shoot at another resolution only
// if the framing matches, which is why the source files are committed beside
// them rather than regenerated.
//
//   node tools/gen_staff_likeness_ref.js
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const REPO = path.resolve(__dirname, '..');
const IMG = path.join(REPO, 'source_data', 'tod_ui_images', '_images');
const REF = path.join(REPO, 'docs', '128_staff_ref');

// The gun icon draws into a 96x44 LUI box on a panel that is NOT under
// TodScaleHud, so at 1920x1080 it is 144x66 real pixels off a 288x132 source.
// Shown here at 2x that, i.e. back at native, to sit level with the 2x head crop.
const DW = 288, DH = 132;

// crop boxes as [x0, y0, x1, y1] fractions of the source screenshot, chosen to
// hold the whole head plus a little shaft and nothing else
const ELEMS = [
  {
    key: 'lightning', label: 'LIGHTNING',
    shot: 'ingame_lightning_staff.png', icon: 'i_tod_hud_gun_staff1.png',
    box: [0.02, 0.13, 0.56, 0.62],
  },
  {
    key: 'fire', label: 'FIRE',
    shot: 'ingame_fire_staff.png', icon: 'i_tod_hud_gun_staff2.png',
    box: [0.03, 0.22, 0.64, 0.60],
  },
  {
    key: 'ice', label: 'ICE',
    shot: 'ingame_ice_staff.png', icon: 'i_tod_hud_gun_staff3.png',
    box: [0.01, 0.24, 0.60, 0.72],
  },
];

// ---------------------------------------------------------------------------
// PNG codec (8-bit RGBA, non-interlaced) — same shape as tools/slice_gauge.js
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
  // normalise to RGBA
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
function crop(im, box) {
  const x0 = Math.round(box[0] * im.w), y0 = Math.round(box[1] * im.h);
  const x1 = Math.round(box[2] * im.w), y1 = Math.round(box[3] * im.h);
  const w = x1 - x0, h = y1 - y0, out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) im.d.copy(out, y * w * 4, ((y0 + y) * im.w + x0) * 4, ((y0 + y) * im.w + x0 + w) * 4);
  return { w: w, h: h, d: out };
}
// nearest-neighbour resample: no interpolation, so a pixel-art icon stays crisp
function scale(im, w, h) {
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

const GROUND = [16, 20, 32, 255];   // the HUD's own near-black, so the icon reads as it does in game
const RULE = [90, 112, 150];
const PAD = 18, GAP = 22;

ELEMS.forEach(function (e) {
  const shot = decodePNG(path.join(REF, e.shot));
  const head = scale(crop(shot, e.box), 0, 0).w ? null : null; // placeholder, replaced below
  const c = crop(shot, e.box);
  const up = scale(c, c.w * 2, c.h * 2);
  fs.writeFileSync(path.join(REF, 'head_' + e.key + '.png'), encodePNG(up));

  // side by side: head close-up | current icon at native 288x132 on the HUD ground
  const icon = decodePNG(path.join(IMG, e.icon));
  const iconUp = scale(icon, DW, DH);
  const W = PAD + up.w + GAP + DW + PAD;
  const H = PAD + Math.max(up.h, DH) + PAD;
  const board = blank(W, H, GROUND);
  paste(board, up, PAD, PAD + Math.round((Math.max(up.h, DH) - up.h) / 2));
  rect(board, PAD + up.w + Math.round(GAP / 2), PAD, 1, H - 2 * PAD, RULE);
  paste(board, iconUp, PAD + up.w + GAP, PAD + Math.round((Math.max(up.h, DH) - DH) / 2));
  fs.writeFileSync(path.join(REF, 'icon_vs_head_' + e.key + '.png'), encodePNG(board));

  console.log('  ' + e.label.padEnd(10) +
    ' head ' + up.w + 'x' + up.h +
    '  ->  head_' + e.key + '.png, icon_vs_head_' + e.key + '.png (' + W + 'x' + H + ')');
});
console.log('docs/128_staff_ref: wrote 6 files (3 head close-ups, 3 comparisons)');
