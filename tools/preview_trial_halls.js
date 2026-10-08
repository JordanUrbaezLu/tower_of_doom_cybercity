#!/usr/bin/env node
// preview_trial_halls.js — top-down plan of every spire hub hall, drawn from
// the EMITTED brushes (map_source/zm/zm_tower_of_doom.map), one PNG per hall
// plus a contact sheet. No bake, no Radiant, ~1 s.
//
//   node tools/preview_trial_halls.js            -> docs/109_trial_halls/hall_<N>.png + sheet.png
//   node tools/preview_trial_halls.js --out DIR
//
// It reads the same brush labels the geometry lint reads ("spire hub lapNN …",
// plus every spire brush whose footprint falls inside the drum at hall level),
// so what it draws is what cod2map will compile — the layout TABLE is not
// consulted. Colour = the vertigo material's hue; brightness = height above
// the hall floor (floor slabs dark, tall things bright), so a tall wall and a
// low wall read apart at a glance. The porch, notch, S lane and vendor
// triggers are drawn as outlines. Same PNG writer as preview_crown.js.
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const REPO = path.resolve(__dirname, '..');
const MAP = path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map');
const DATA = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_spire_data.gsc');
const args = process.argv.slice(2);
const outDir = args.includes('--out') ? args[args.indexOf('--out') + 1] : path.join(REPO, 'docs', '109_trial_halls');

// --- the spire's anchors, read from the generated data (never guessed) ------
const data = fs.readFileSync(DATA, 'utf8');
const num = (re) => { const m = data.match(re); if (!m) throw new Error('spire data: ' + re); return +m[1]; };
const SP_X = num(/function spire_x\(\)\s*\{\s*return\s+(-?\d+);/), SP_Y = num(/function spire_y\(\)\s*\{\s*return\s+(-?\d+);/);
const HUBS = data.match(/function hub_laps\(\)\s*\{\s*return array\(([^)]*)\)/)[1].split(',').map(s => +s.trim());
const hubZ = lap => (lap - 1) * 384 + 192;   // hub_z(): the hall floor = the mid landing
const marks = [...data.matchAll(/case (\d+): return \( (-?\d+), (-?\d+), z \+ (\d+) \);\s*\/\/ (.*)/g)];
const layoutName = i => (marks[i] ? marks[i][5].trim() : `hall ${i + 1}`);
const markOf = i => marks[i] ? [+marks[i][2] - SP_X, +marks[i][3] - SP_Y] : null;
const wardens = marks.slice(marks.length / 2);
const wardenOf = i => wardens[i] ? [+wardens[i][2] - SP_X, +wardens[i][3] - SP_Y] : null;

// --- parse worldspawn boxes (the lint's parser, trimmed) ---------------------
function parseWorld(text) {
  const end = text.indexOf('// entity 1 ');
  const lines = (end >= 0 ? text.slice(0, end) : text).split(/\r?\n/);
  const out = [];
  let label = null;
  for (let i = 0; i < lines.length; i++) {
    const lm = lines[i].match(/^\/\/ brush \d+ — (.*)$/);
    if (lm) { label = lm[1]; continue; }
    if (lines[i] !== '{' || label === null) continue;
    const planes = []; let mat = null;
    for (let j = i + 1; j < lines.length && lines[j] !== '}'; j++) {
      const pm = lines[j].match(/^ \( (\S+) (\S+) (\S+) \) \( (\S+) (\S+) (\S+) \) \( (\S+) (\S+) (\S+) \) (\S+) /);
      if (!pm) continue;
      const v = pm.slice(1, 10).map(Number); mat = pm[10];
      const verts = [[v[0], v[1], v[2]], [v[3], v[4], v[5]], [v[6], v[7], v[8]]];
      for (let a = 0; a < 3; a++) if (verts[0][a] === verts[1][a] && verts[1][a] === verts[2][a]) planes.push([a, verts[0][a]]);
    }
    if (planes.length === 6 && mat) {
      const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
      for (const [a, v] of planes) { lo[a] = Math.min(lo[a], v); hi[a] = Math.max(hi[a], v); }
      out.push({ label, mat, lo, hi });
    }
    label = null;
  }
  return out;
}

// --- colours: the material's hue family --------------------------------------
const HUE = {
  yellow: [255, 210, 60], red: [255, 70, 70], blue: [90, 150, 255], dark_blue: [40, 70, 200], cyan: [80, 220, 255],
  green: [90, 255, 120], orange: [255, 140, 40], purple: [190, 100, 255], pink: [255, 120, 200], light_pink: [255, 170, 210],
  white: [240, 240, 255], dark_white: [120, 120, 130], pap: [255, 230, 120], off: [30, 30, 30],
};
function matColour(mat) {
  if (mat === 'clip' || mat === 'clip_player') return null;   // invisible: drawn as hatch outline only
  const m = mat.match(/^mwiii_vertigo_retro_synth_([a-z_]+?)(?:_tinted(?:_edge)?)?$/);
  const base = m ? (HUE[m[1]] || [200, 200, 200]) : [160, 160, 160];
  const filled = /_tinted/.test(mat);
  return filled ? base : base.map(v => Math.round(v * 0.75));
}

// --- raster -------------------------------------------------------------------
const HALF = 480, SCALE = 0.5;                  // hall ±480 local -> 480 px
const W = Math.round(HALF * 2 * SCALE), H = W, PAD = 28;
function makeCanvas(w, h) { const px = Buffer.alloc(w * h * 3, 18); return { w, h, px }; }
function fillRect(c, x1, y1, x2, y2, rgb) {
  x1 = Math.max(0, Math.floor(x1)); y1 = Math.max(0, Math.floor(y1)); x2 = Math.min(c.w, Math.ceil(x2)); y2 = Math.min(c.h, Math.ceil(y2));
  for (let y = y1; y < y2; y++) for (let x = x1; x < x2; x++) { const o = (y * c.w + x) * 3; c.px[o] = rgb[0]; c.px[o + 1] = rgb[1]; c.px[o + 2] = rgb[2]; }
}
function strokeRect(c, x1, y1, x2, y2, rgb, dash) {
  x1 = Math.floor(x1); y1 = Math.floor(y1); x2 = Math.ceil(x2) - 1; y2 = Math.ceil(y2) - 1;
  const put = (x, y, i) => { if (dash && (i % 6) >= 3) return; if (x < 0 || y < 0 || x >= c.w || y >= c.h) return; const o = (y * c.w + x) * 3; c.px[o] = rgb[0]; c.px[o + 1] = rgb[1]; c.px[o + 2] = rgb[2]; };
  let i = 0;
  for (let x = x1; x <= x2; x++, i++) { put(x, y1, i); put(x, y2, i); }
  for (let y = y1; y <= y2; y++, i++) { put(x1, y, i); put(x2, y, i); }
}
// 5x7 bitmap font for labels (digits, caps, a few marks)
const FONT = {
  A: '0E1F1B1F1B1B1B', B: '1E1B1E1B1B1B1E', C: '0E1B1818181B0E', D: '1E1B1B1B1B1B1E', E: '1F18181E18181F', F: '1F18181E181818', G: '0E1B181F1B1B0F',
  H: '1B1B1B1F1B1B1B', I: '0E060606060E00', J: '070303031B1B0E', K: '1B1B1E1C1E1B1B', L: '18181818181B1F', M: '111B1F1F151111', N: '111919151313111',
  O: '0E1B1B1B1B1B0E', P: '1E1B1B1E181818', Q: '0E1B1B1B1F0E03', R: '1E1B1B1E1C1E1B', S: '0F181E0F03031E', T: '1F060606060606', U: '1B1B1B1B1B1B0E',
  V: '1B1B1B1B1B0E04', W: '1111111515151B', X: '1B1B0E040E1B1B', Y: '1B1B0E06060606', Z: '1F03060C18181F', ' ': '00000000000000', '-': '0000001F000000',
  0: '0E1B1B1B1B1B0E', 1: '060E06060606060E', 2: '0E1B03060C181F', 3: '1E03030E03031E', 4: '1B1B1B1F030303', 5: '1F18181E03031E', 6: '0E18181E1B1B0E',
  7: '1F0303060C0C0C', 8: '0E1B1B0E1B1B0E', 9: '0E1B1B0F03030E', '.': '00000000000606', ':': '00060600060600', '/': '01030306060C18', '(': '0306060606 0603', ')': '180C0C0C0C0C18',
};
function text(c, x, y, str, rgb, s = 2) {
  let cx = x;
  for (const ch of str.toUpperCase()) {
    const g = FONT[ch] || FONT[' '];
    for (let r = 0; r < 7; r++) {
      const bits = parseInt(g.slice(r * 2, r * 2 + 2), 16);
      for (let col = 0; col < 5; col++) if (bits & (1 << (4 - col))) fillRect(c, cx + col * s, y + r * s, cx + col * s + s, y + r * s + s, rgb);
    }
    cx += 6 * s;
  }
}
function writePng(file, c) {
  const raw = Buffer.alloc((c.w * 3 + 1) * c.h);
  for (let y = 0; y < c.h; y++) { raw[y * (c.w * 3 + 1)] = 0; c.px.copy(raw, y * (c.w * 3 + 1) + 1, y * c.w * 3, (y + 1) * c.w * 3); }
  const crcTable = []; for (let n = 0; n < 256; n++) { let cc = n; for (let k = 0; k < 8; k++) cc = (cc & 1) ? (0xedb88320 ^ (cc >>> 1)) : (cc >>> 1); crcTable[n] = cc >>> 0; }
  const crc = b => { let cc = 0xffffffff; for (const x of b) cc = crcTable[(cc ^ x) & 0xff] ^ (cc >>> 8); return (cc ^ 0xffffffff) >>> 0; };
  const chunk = (type, d) => { const len = Buffer.alloc(4); len.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(type), d]); const cr = Buffer.alloc(4); cr.writeUInt32BE(crc(td)); return Buffer.concat([len, td, cr]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(c.w, 0); ihdr.writeUInt32BE(c.h, 4); ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}

// --- draw one hall ------------------------------------------------------------
const brushes = parseWorld(fs.readFileSync(MAP, 'utf8'));
const toPx = (x, y) => [(x + HALF) * SCALE, (HALF - y) * SCALE];   // +y up on the page (north up)
function drawHall(i, lap) {
  const z0 = hubZ(lap);
  const c = makeCanvas(W, H + PAD * 2);
  const inHall = b => b.hi[0] > SP_X - HALF && b.lo[0] < SP_X + HALF && b.hi[1] > SP_Y - HALF && b.lo[1] < SP_Y + HALF
                   && b.hi[2] > z0 - 60 && b.lo[2] < z0 + 170;   // floor-standing things only: the last hall's capital (a 192 ceiling) and the summit deck are above this
  const list = brushes.filter(inHall).sort((a, b) => a.hi[2] - b.hi[2]);   // low first, tall on top
  for (const b of list) {
    const col = matColour(b.mat);
    const [x1, y2] = toPx(b.lo[0] - SP_X, b.lo[1] - SP_Y), [x2, y1] = toPx(b.hi[0] - SP_X, b.hi[1] - SP_Y);
    if (!col) continue;
    const top = b.hi[2] - z0;                                  // height above the hall floor
    const k = top <= 1 ? 0.35 : top <= 13 ? 0.5 : top <= 60 ? 0.7 : top <= 140 ? 0.85 : 1.0;
    // 1u inlays and 12u steps get their own brightness so the floor art reads
    fillRect(c, x1, y1 + PAD, x2, y2 + PAD, col.map(v => Math.round(v * k)));
  }
  for (const b of list) if (b.mat === 'clip' || b.mat === 'clip_player') {
    const [x1, y2] = toPx(b.lo[0] - SP_X, b.lo[1] - SP_Y), [x2, y1] = toPx(b.hi[0] - SP_X, b.hi[1] - SP_Y);
    if (/cap$/.test(b.label) || /ammo crate body/.test(b.label)) strokeRect(c, x1, y1 + PAD, x2, y2 + PAD, [255, 255, 255], true);
  }
  // the approach lane, the porch and the mark / warden
  const box = (x1, x2, y1, y2, rgb) => { const [px1, py2] = toPx(x1, y1), [px2, py1] = toPx(x2, y2); strokeRect(c, px1, py1 + PAD, px2, py2 + PAD, rgb, true); };
  box(-256, -80, -256, -96, [120, 255, 120]);                  // approach lane (must stay clear)
  const mk = markOf(i), wd = wardenOf(i);
  if (mk) { const [px, py] = toPx(mk[0], mk[1]); strokeRect(c, px - 6, py - 6 + PAD, px + 6, py + 6 + PAD, [255, 255, 255]); text(c, px + 9, py - 5 + PAD, 'MARK', [255, 255, 255], 1); }
  if (wd) { const [px, py] = toPx(wd[0], wd[1]); strokeRect(c, px - 8, py - 8 + PAD, px + 8, py + 8 + PAD, [255, 80, 80]); text(c, px + 11, py - 5 + PAD, 'WARDEN', [255, 80, 80], 1); }
  text(c, 6, 8, `TRIAL ${['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'][i]} - ${layoutName(i)}  FLOOR ${lap}`, [255, 255, 255], 2);
  text(c, 6, H + PAD + 8, 'N UP  ENTRANCE SW  DASHED GREEN = APPROACH LANE  WHITE DASH = CLIP CAP', [150, 150, 150], 1);
  return c;
}

fs.mkdirSync(outDir, { recursive: true });
const halls = HUBS.map((lap, i) => drawHall(i, lap));
halls.forEach((c, i) => writePng(path.join(outDir, `hall_${i + 1}.png`), c));
// contact sheet: 4 x 2
const cols = 4, rows = Math.ceil(halls.length / cols);
const sheet = makeCanvas(cols * halls[0].w, rows * halls[0].h);
halls.forEach((c, i) => {
  const ox = (i % cols) * c.w, oy = Math.floor(i / cols) * c.h;
  for (let y = 0; y < c.h; y++) c.px.copy(sheet.px, ((oy + y) * sheet.w + ox) * 3, y * c.w * 3, (y + 1) * c.w * 3);
});
writePng(path.join(outDir, 'sheet.png'), sheet);
console.log(`wrote ${halls.length} hall plans + sheet.png to ${outDir}`);
