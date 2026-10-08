#!/usr/bin/env node
// gen_tod_camo.js — THE PACK III CAMO: "NEON CITY" (v17.89, 2026-09-05)
//
// User: "Can you look into making one camo for the map. It'll be sick and cyber
// colorful for 3rd pap." — the sky's own language (docs/104) on the gun: a
// dark gunmetal panel base, a cyan Tron grid, magenta circuit traces with a
// scrolling wireframe SKYLINE of lit windows, gold nodes — three emissive
// layers the shader scrolls at their own rates, so the city drifts across the
// weapon.
//
// THE RECIPE IS A COPY, NOT A DESIGN (v17.35-v17.50 postmortem, memory
// `pap-camo-materials-never-linked`). Four builds of our own camo material
// linked perfectly and never drew a pixel; the only custom camo materials in
// this install that a released pack actually ships on a gun's MAIN surface
// (material1_N_material) are MadGaz's `wpn_t9_camo_madgaz1..9`
// (`_mg_custom_camos.gdt`, used by owens_weapons' cosplay shotgun). So:
//
//   * the MATERIAL block is `wpn_t9_camo_madgaz1` copied field for field — the
//     techset (lit_emissive_scroll_3layer_transparent_plus_camo), useAsCamo 1,
//     the scroll constants (cg00..cg10, gUVScroll0x), the gloss/heatmap
//     built-ins ($white_gloss / $env_cone_lut), everything — and ONLY the four
//     map references and the four tints move. Field-diffed against the source
//     on every run: anything else differing is a throw.
//   * the IMAGE blocks are copies of the images that material uses — its
//     diffuse (`i_wpn_t9_camo_madgaz3_c`), its emissive layer
//     (`i_wpn_t9_camo_madgaz3_ce2`) and its normal (`i_wpn_t9_camo_madgaz2_n`)
//     — with only the name and baseImage moved. The proven pack ships BOTH
//     RGB and RGBA PNGs (mg_TREE1.png is RGB, mg_orange_em1.png RGBA), so the
//     v17.36 "no alpha = invisible" theory was at most half the story; the
//     layers here still carry alpha = luminance because the layer image it
//     copies does.
//   * COLOUR LIVES IN THE TINTS, as it does in every MadGaz material: the layer
//     images are GREYSCALE patterns and colorTint1..3 colour them per layer.
//     v17.35-39 baked colour into the textures and set every tint white — the
//     one arrangement no shipped camo uses.
//
// WHERE IT GOES (gen_tod_twins.js, the CAMO_PAP3_TABLE lane): every packed twin
// gets its own copy of its port's weaponcamotable in which the base-121 asset
// is copied with index 123 (Revelations PaP 3 — the PACK III slot,
// TOD_PAP_CAMO_T3) pointed at `tod_camo_pap3`, and index 122 pointed at
// `mtl_origins_camo_alt` (MadGaz's second-surface material, in this build for
// months) as THE CONTROL. Index 121 stays stock. One build, read on a PACK III
// gun with the dev camo browser (crouch):
//   123 draws                      -> done; the recipe is proven
//   123 blank, 122 draws           -> our material/images are wrong; diff again
//   122 blank, 121 draws           -> custom materials do not paint through
//                                     this lane at all
//   121 blank                      -> the table COPY breaks the lane
//
// OUTPUT
//   source_data/tod_camo/_images/i_tod_camo_pap3_{c,ea,eb,n}.png   4 textures
//   source_data/tod_camo.gdt                                       4 images + 1 material
//   docs/camo_preview/pap3_*.png                                   the four maps + a composite
// RUN: node tools/gen_tod_camo.js     (then node tools/gen_tod_twins.js, then a FULL build)

'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const REPO = path.resolve(__dirname, '..');
const IMG_DIR = path.join(REPO, 'source_data', 'tod_camo', '_images');
const OUT_GDT = path.join(REPO, 'source_data', 'tod_camo.gdt');
const PREVIEW_DIR = path.join(REPO, 'docs', 'camo_preview');

// the template's home — same detection rule as build_map.ps1
function toolsRoot() {
  const roots = [
    'C:\\Program Files (x86)\\Steam\\steamapps\\common',
    'D:\\Steam\\steamapps\\common',
    'E:\\Steam\\steamapps\\common',
    'C:\\Steam\\steamapps\\common',
  ];
  for (const lib of roots) {
    if (!fs.existsSync(lib)) continue;
    for (const d of fs.readdirSync(lib)) {
      if (!d.startsWith('Call of Duty Black Ops III')) continue;
      const full = path.join(lib, d);
      if (fs.existsSync(path.join(full, 'bin', 'modlauncher.exe'))) return full;
    }
  }
  throw new Error('could not auto-detect the Mod Tools root');
}

const TOOLS = toolsRoot();
const TEMPLATE_GDT = path.join(TOOLS, 'source_data', '_mg_custom_camos.gdt');
const TEMPLATE_MTL = 'wpn_t9_camo_madgaz1';            // a MAIN-surface camo from a released pack
const TEMPLATE_IMG = { c: 'i_wpn_t9_camo_madgaz3_c', e: 'i_wpn_t9_camo_madgaz3_ce2', n: 'i_wpn_t9_camo_madgaz2_n' };

const SIZE = 1024;   // the camo tiles over the whole weapon; the proven pack's are 2048, ours were 1024 through every attempt and converted fine
const NAME = 'tod_camo_pap3';
const IMG = 'i_tod_camo_pap3';

// the palette — the sky's (tools/gen_tod_sky.js HUE) — as the per-layer TINTS
const TINT = {
  base:    '0.976471 0.970382 0.957321 1',   // the template's own near-white base multiplier
  layer00: '0.20 0.85 1.00 1',               // cyan   — the Tron grid, coarse scroll
  layer01: '1.00 0.25 0.80 1',               // magenta — traces + the skyline
  layer02: '0.85 0.62 0.18 1',               // gold   — the grid again, fine scroll (softer than the cyan so the two grids do not sum to white)
};

// ---------------------------------------------------------------------------
// a minimal PNG encoder — RGBA8, filter none
// ---------------------------------------------------------------------------
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    t[n] = c;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xFFFFFFFF;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}
// rgb = w*h*3 bytes; alpha = w*h bytes or null (opaque)
function writePNG(file, w, h, rgb, alpha) {
  const raw = Buffer.alloc(h * (1 + w * 4));
  for (let y = 0; y < h; y++) {
    const row = y * (1 + w * 4);
    raw[row] = 0;
    for (let x = 0; x < w; x++) {
      const s = (y * w + x) * 3, d = row + 1 + x * 4;
      raw[d] = rgb[s]; raw[d + 1] = rgb[s + 1]; raw[d + 2] = rgb[s + 2];
      raw[d + 3] = alpha ? alpha[y * w + x] : 255;
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
  ]));
}

// ---------------------------------------------------------------------------
// canvas helpers — everything wraps, so every pattern tiles by construction
// ---------------------------------------------------------------------------
function canvas(w, h, rgb) {
  const buf = Buffer.alloc(w * h * 3);
  for (let i = 0; i < w * h; i++) { buf[i * 3] = rgb[0]; buf[i * 3 + 1] = rgb[1]; buf[i * 3 + 2] = rgb[2]; }
  return buf;
}
const wrap = (v, n) => ((v % n) + n) % n;
const clamp255 = v => v < 0 ? 0 : v > 255 ? 255 : v;
// additive plot with a soft falloff — `a` 0..1
function plot(buf, w, h, x, y, rgb, a) {
  if (a <= 0) return;
  const i = (wrap(y | 0, h) * w + wrap(x | 0, w)) * 3;
  for (let k = 0; k < 3; k++) buf[i + k] = clamp255(buf[i + k] + rgb[k] * a);
}
// a glowing line: a hot core plus a falloff halo, drawn on the wrapped canvas
function line(buf, w, h, x0, y0, x1, y1, rgb, width, glow) {
  const dx = x1 - x0, dy = y1 - y0;
  const steps = Math.ceil(Math.max(Math.abs(dx), Math.abs(dy))) * 2 + 1;
  const r = Math.max(width, glow);
  for (let s = 0; s <= steps; s++) {
    const t = s / steps;
    const cx = x0 + dx * t, cy = y0 + dy * t;
    for (let oy = -r; oy <= r; oy++) for (let ox = -r; ox <= r; ox++) {
      const d = Math.hypot(ox, oy);
      let a;
      if (d <= width / 2) a = 1;
      else if (d <= r) a = Math.pow(1 - (d - width / 2) / (r - width / 2 + 0.001), 2.2) * 0.55;
      else continue;
      plot(buf, w, h, cx + ox, cy + oy, rgb, a);
    }
  }
}
function rect(buf, w, h, x, y, rw, rh, rgb, a) {
  for (let oy = 0; oy < rh; oy++) for (let ox = 0; ox < rw; ox++) plot(buf, w, h, x + ox, y + oy, rgb, a);
}
// deterministic PRNG — the textures must be byte-identical run to run
function mulberry32(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const lum = (buf, i) => buf[i * 3] * 0.299 + buf[i * 3 + 1] * 0.587 + buf[i * 3 + 2] * 0.114;

// ---------------------------------------------------------------------------
// THE ART — NEON CITY. Layers are GREYSCALE (white on black): the material's
// tints colour them. The base is the one coloured map.
// ---------------------------------------------------------------------------
const W = [255, 255, 255], MID = [150, 150, 150], DIM = [70, 70, 70];

// BASE (_c): dark gunmetal navy plating — beveled panels of two sizes, a faint
// hex-cell etch, hairline seams, and a few dim "window" rectangles so the
// unlit metal already reads as a city block at arm's length.
function baseMap() {
  const w = SIZE, h = SIZE;
  const c = canvas(w, h, [11, 16, 30]);
  const rnd = mulberry32(0xC17E);
  // plating: 128-cells split into panels; each panel a slightly different navy
  for (let py = 0; py < h; py += 128) for (let px = 0; px < w; px += 128) {
    const split = rnd() < 0.45;
    const panels = split ? [[px, py, 128, 64], [px, py + 64, 128, 64]] : [[px, py, 128, 128]];
    for (const [x, y, pw, ph] of panels) {
      const k = 0.85 + rnd() * 0.5;
      const col = [Math.round(11 * k), Math.round(16 * k), Math.round(30 * k)];
      for (let oy = 0; oy < ph; oy++) for (let ox = 0; ox < pw; ox++) {
        const i = (wrap(y + oy, h) * w + wrap(x + ox, w)) * 3;
        c[i] = col[0]; c[i + 1] = col[1]; c[i + 2] = col[2];
      }
      // bevel: a lighter top/left edge, a darker bottom/right
      rect(c, w, h, x, y, pw, 2, [22, 30, 48], 0.9);
      rect(c, w, h, x, y, 2, ph, [22, 30, 48], 0.9);
      rect(c, w, h, x, y + ph - 2, pw, 2, [0, 0, 0], 0.6);
      rect(c, w, h, x + pw - 2, y, 2, ph, [0, 0, 0], 0.6);
    }
  }
  // hex etch: a faint honeycomb, very low contrast
  const R = 22, dx = R * 1.5, dy = R * Math.sqrt(3);
  for (let row = 0; row * dy < h + dy; row++) for (let col = 0; col * dx < w + dx; col++) {
    const cx = col * dx, cy = row * dy + (col % 2 ? dy / 2 : 0);
    for (let k = 0; k < 6; k++) {
      const a0 = Math.PI / 3 * k, a1 = Math.PI / 3 * (k + 1);
      line(c, w, h, cx + R * Math.cos(a0), cy + R * Math.sin(a0), cx + R * Math.cos(a1), cy + R * Math.sin(a1), [14, 34, 52], 1, 1);
    }
  }
  // dim windows: tiny rectangles, a hint of the lit city in the metal
  for (let n = 0; n < 900; n++) {
    const x = rnd() * w, y = rnd() * h;
    const cool = rnd() < 0.6;
    rect(c, w, h, x, y, 3 + (rnd() * 4 | 0), 2 + (rnd() * 3 | 0), cool ? [20, 60, 80] : [70, 24, 60], 0.55 + rnd() * 0.4);
  }
  return c;
}

// LAYER A (_ea): THE TRON GRID — major lines every 128, minor every 32, bright
// nodes on some crossings, a few long avenue traces. Greyscale. Drawn at two
// scales by the shader (layer 00 cyan / layer 02 gold).
function layerGrid() {
  const w = SIZE, h = SIZE;
  const e = canvas(w, h, [0, 0, 0]);
  const rnd = mulberry32(0x7043D);
  for (let x = 0; x < w; x += 32) line(e, w, h, x, 0, x, h, DIM, 1, 1);
  for (let y = 0; y < h; y += 32) line(e, w, h, 0, y, w, y, DIM, 1, 1);
  for (let x = 0; x < w; x += 128) line(e, w, h, x, 0, x, h, W, 3, 8);
  for (let y = 0; y < h; y += 128) line(e, w, h, 0, y, w, y, W, 3, 8);
  for (let x = 0; x < w; x += 128) for (let y = 0; y < h; y += 128) {
    if (rnd() > 0.40) continue;
    rect(e, w, h, x - 6, y - 6, 13, 13, W, 1.0);
    rect(e, w, h, x - 10, y - 10, 21, 21, MID, 0.35);
  }
  for (let i = 0; i < 8; i++) {                   // avenue traces, one cell off the majors
    const y = (rnd() * 8 | 0) * 128 + 64, x = (rnd() * 8 | 0) * 128;
    line(e, w, h, x, y, x + 256 + (rnd() * 3 | 0) * 128, y, W, 2, 5);
  }
  return e;
}

// LAYER B (_eb): CIRCUIT + SKYLINE — board traces with pads and vias, "data"
// dashes along them, and two horizontal bands of wireframe towers with lit
// windows (the city itself, which the shader scrolls across the gun).
function layerCircuit() {
  const w = SIZE, h = SIZE;
  const e = canvas(w, h, [0, 0, 0]);
  const rnd = mulberry32(0x1CE04);
  const G = 32;
  // traces: axis-aligned random walks, pads at the corners
  for (let n = 0; n < 40; n++) {
    let x = (rnd() * (w / G) | 0) * G, y = (rnd() * (h / G) | 0) * G, horiz = rnd() < 0.5;
    const legs = 4 + (rnd() * 5 | 0);
    for (let l = 0; l < legs; l++) {
      const len = (1 + (rnd() * 4 | 0)) * G, dir = rnd() < 0.5 ? 1 : -1;
      const nx = horiz ? x + len * dir : x, ny = horiz ? y : y + len * dir;
      line(e, w, h, x, y, nx, ny, MID, 2, 5);
      // data dashes riding the trace
      const segs = Math.max(1, len / G | 0);
      for (let s = 0; s < segs; s++) if (rnd() < 0.35) {
        const t0 = (s + 0.2) / segs, t1 = (s + 0.6) / segs;
        line(e, w, h, x + (nx - x) * t0, y + (ny - y) * t0, x + (nx - x) * t1, y + (ny - y) * t1, W, 3, 6);
      }
      x = nx; y = ny; horiz = !horiz;
      if (rnd() < 0.45) rect(e, w, h, x - 4, y - 4, 9, 9, W, 0.8);
    }
  }
  for (let n = 0; n < 60; n++) rect(e, w, h, rnd() * w, rnd() * h, 4, 4, W, 0.7);   // vias
  // the skyline bands: two rows of wireframe towers standing on a ground line
  for (const gy of [300, 812]) {
    line(e, w, h, 0, gy, w, gy, W, 2, 6);
    let x = 0;
    while (x < w) {
      const bw = 24 + (rnd() * 56 | 0), bh = 40 + Math.pow(rnd(), 1.6) * 190;
      const x1 = Math.min(x + bw, w);
      if (x1 - x > 12) {
        // outline
        line(e, w, h, x, gy, x, gy - bh, MID, 2, 4);
        line(e, w, h, x1, gy, x1, gy - bh, MID, 2, 4);
        line(e, w, h, x, gy - bh, x1, gy - bh, MID, 2, 4);
        // windows
        for (let wy = gy - bh + 8; wy < gy - 6; wy += 10) for (let wx = x + 5; wx < x1 - 4; wx += 8) if (rnd() < 0.55) rect(e, w, h, wx, wy, 3, 4, W, 0.9);
        // an antenna on the tall ones
        if (bh > 150 && rnd() < 0.6) { const ax = (x + x1) / 2; line(e, w, h, ax, gy - bh, ax, gy - bh - 30, MID, 1, 3); rect(e, w, h, ax - 1, gy - bh - 32, 3, 3, W, 1); }
      }
      x = x1 + 6 + (rnd() * 10 | 0);
    }
  }
  return e;
}

// the normal map is DERIVED from the layers: the traces and grid lines stand
// proud of the plating, so their luminance gradient is the height field
function normalFromMask(mask, w, h, strength) {
  const L = new Float32Array(w * h);
  for (let i = 0; i < w * h; i++) L[i] = lum(mask, i) / 255;
  const out = Buffer.alloc(w * h * 3);
  const at = (x, y) => L[wrap(y, h) * w + wrap(x, w)];
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const gx = (at(x + 1, y - 1) + 2 * at(x + 1, y) + at(x + 1, y + 1)) - (at(x - 1, y - 1) + 2 * at(x - 1, y) + at(x - 1, y + 1));
    const gy = (at(x - 1, y + 1) + 2 * at(x, y + 1) + at(x + 1, y + 1)) - (at(x - 1, y - 1) + 2 * at(x, y - 1) + at(x + 1, y - 1));
    let nx = -gx * strength, ny = -gy * strength, nz = 1;
    const len = Math.hypot(nx, ny, nz); nx /= len; ny /= len; nz /= len;
    const i = (y * w + x) * 3;
    out[i] = Math.round((nx * 0.5 + 0.5) * 255); out[i + 1] = Math.round((ny * 0.5 + 0.5) * 255); out[i + 2] = Math.round((nz * 0.5 + 0.5) * 255);
  }
  return out;
}

// ---------------------------------------------------------------------------
// GDT — copies of the proven blocks with only the named fields moved
// ---------------------------------------------------------------------------
function extractBlock(text, asset, gdf) {
  const decl = `"${asset}" ( "${gdf}" )`;
  const start = text.indexOf(decl);
  if (start === -1) throw new Error(`asset ${asset} (${gdf}) not found in ${TEMPLATE_GDT}`);
  const open = text.indexOf('{', start);
  let depth = 0, end = -1;
  for (let j = open; j < text.length; j++) {
    if (text[j] === '{') depth++;
    else if (text[j] === '}') { depth--; if (depth === 0) { end = j; break; } }
  }
  if (end === -1) throw new Error('unbalanced braces in the template GDT');
  return text.slice(text.lastIndexOf('\n', start) + 1, end + 1);
}
function fieldsOf(block) {
  const o = {};
  for (const l of block.split(/\r?\n/)) { const m = l.match(/^\s*"([A-Za-z0-9_]+)"\s+"(.*)"\s*$/); if (m) o[m[1]] = m[2]; }
  return o;
}
// set "key" "value" lines; every key must exist in the block (a silently-missed
// field is a material that renders wrong with nothing to say so)
function setFields(block, fields) {
  const hit = new Set();
  const out = block.split(/\r?\n/).map(l => {
    const m = l.match(/^(\s*)"([A-Za-z0-9_]+)"\s+"(.*)"\s*$/);
    if (!m || !(m[2] in fields)) return l;
    hit.add(m[2]);
    return `${m[1]}"${m[2]}" "${fields[m[2]]}"`;
  }).join('\n');
  for (const k of Object.keys(fields)) if (!hit.has(k)) throw new Error(`template has no field "${k}" — the template moved`);
  return out;
}
function rename(block, from, to, gdf) { return block.replace(`"${from}" ( "${gdf}" )`, `"${to}" ( "${gdf}" )`); }
// the GDT path form the sky GDT uses (proven to convert): backslashes, tools-root relative
const gdtPath = png => `source_data\\\\tod_camo\\\\_images\\\\${png}`;

// PROVE THE COPY: the emitted block must differ from its template in exactly the
// allowed fields and nothing else
function assertCopy(name, emitted, template, allowed) {
  const A = fieldsOf(template), B = fieldsOf(emitted);
  const diff = [...new Set([...Object.keys(A), ...Object.keys(B)])].filter(k => A[k] !== B[k]);
  const bad = diff.filter(k => !allowed.includes(k));
  if (bad.length) throw new Error(`${name}: differs from its template in fields not on the allow list: ${bad.join(', ')}`);
  return diff;
}

function main() {
  fs.mkdirSync(IMG_DIR, { recursive: true });
  fs.mkdirSync(PREVIEW_DIR, { recursive: true });
  const t0 = Date.now();

  // ---- the art
  const c = baseMap(), ea = layerGrid(), eb = layerCircuit();
  const both = Buffer.alloc(SIZE * SIZE * 3);
  for (let i = 0; i < both.length; i++) both[i] = clamp255(ea[i] * 0.6 + eb[i]);
  const n = normalFromMask(both, SIZE, SIZE, 2.4);
  const alphaOf = buf => { const a = Buffer.alloc(SIZE * SIZE); for (let i = 0; i < SIZE * SIZE; i++) a[i] = Math.round(lum(buf, i)); return a; };

  // stale files from the three-tier era go — a PNG nothing names is dead weight in the repo
  for (const f of fs.readdirSync(IMG_DIR)) if (!f.startsWith(IMG + '_')) fs.unlinkSync(path.join(IMG_DIR, f));

  writePNG(path.join(IMG_DIR, `${IMG}_c.png`), SIZE, SIZE, c);               // opaque, coloured
  writePNG(path.join(IMG_DIR, `${IMG}_ea.png`), SIZE, SIZE, ea, alphaOf(ea)); // greyscale, alpha = luminance
  writePNG(path.join(IMG_DIR, `${IMG}_eb.png`), SIZE, SIZE, eb, alphaOf(eb));
  writePNG(path.join(IMG_DIR, `${IMG}_n.png`), SIZE, SIZE, n);               // opaque
  for (const f of fs.readdirSync(IMG_DIR)) if (![`${IMG}_c.png`, `${IMG}_ea.png`, `${IMG}_eb.png`, `${IMG}_n.png`].includes(f)) fs.unlinkSync(path.join(IMG_DIR, f));

  // ---- a composite preview: base x tint + the three tinted layers, as the shader roughly composes them
  {
    const tintOf = s => s.split(' ').slice(0, 3).map(Number);
    const tb = tintOf(TINT.base), t0c = tintOf(TINT.layer00), t1c = tintOf(TINT.layer01), t2c = tintOf(TINT.layer02);
    const comp = Buffer.alloc(SIZE * SIZE * 3);
    for (let i = 0; i < SIZE * SIZE; i++) for (let k = 0; k < 3; k++) {
      const v = c[i * 3 + k] * tb[k] + ea[i * 3 + k] * t0c[k] * 0.9 + eb[i * 3 + k] * t1c[k] * 0.9 + ea[i * 3 + k] * t2c[k] * 0.35;
      comp[i * 3 + k] = clamp255(v);
    }
    writePNG(path.join(PREVIEW_DIR, 'pap3_composite.png'), SIZE, SIZE, comp);
    writePNG(path.join(PREVIEW_DIR, 'pap3_base.png'), SIZE, SIZE, c);
    writePNG(path.join(PREVIEW_DIR, 'pap3_layer_grid.png'), SIZE, SIZE, ea);
    writePNG(path.join(PREVIEW_DIR, 'pap3_layer_circuit.png'), SIZE, SIZE, eb);
  }

  // ---- the GDT: proven blocks, four maps + four tints moved, proven by diff
  const text = fs.readFileSync(TEMPLATE_GDT, 'latin1');
  const blocks = [];
  const imgSpec = [
    ['c', TEMPLATE_IMG.c], ['ea', TEMPLATE_IMG.e], ['eb', TEMPLATE_IMG.e], ['n', TEMPLATE_IMG.n],
  ];
  for (const [suffix, tmplName] of imgSpec) {
    const tmpl = extractBlock(text, tmplName, 'image.gdf');
    let blk = rename(tmpl, tmplName, `${IMG}_${suffix}`, 'image.gdf');
    blk = setFields(blk, { baseImage: gdtPath(`${IMG}_${suffix}.png`) });
    assertCopy(`${IMG}_${suffix}`, blk, tmpl, ['baseImage']);
    blocks.push(blk);
  }
  const mtlTmpl = extractBlock(text, TEMPLATE_MTL, 'material.gdf');
  let mtl = rename(mtlTmpl, TEMPLATE_MTL, NAME, 'material.gdf');
  const moved = {
    colorMap: `${IMG}_c`, colorMap00: `${IMG}_ea`, colorMap01: `${IMG}_eb`, colorMap02: `${IMG}_ea`, normalMap: `${IMG}_n`,
    colorTint: TINT.base, colorTint1: TINT.layer00, colorTint2: TINT.layer01, colorTint3: TINT.layer02,
  };
  mtl = setFields(mtl, moved);
  const diff = assertCopy(NAME, mtl, mtlTmpl, Object.keys(moved));
  const F = fieldsOf(mtl);
  if (F.useAsCamo !== '1' || !/plus_camo$/.test(F.materialType)) throw new Error(`${NAME}: the template is not a camo material any more (useAsCamo ${F.useAsCamo}, ${F.materialType})`);
  blocks.push(mtl);

  fs.writeFileSync(OUT_GDT, '{\n' + blocks.join('\n') + '\n}\n', 'latin1');
  console.log(`wrote ${path.relative(REPO, OUT_GDT)}: 4 images + 1 material (${NAME}), template ${TEMPLATE_MTL} / ${F.materialType}, moved fields: ${diff.join(', ')}`);
  console.log(`wrote ${path.relative(REPO, IMG_DIR)}/${IMG}_{c,ea,eb,n}.png  (${SIZE}x${SIZE} RGBA, tiling, deterministic)  previews -> ${path.relative(REPO, PREVIEW_DIR)}`);
  console.log(`tints: 00 cyan ${TINT.layer00} | 01 magenta ${TINT.layer01} | 02 gold ${TINT.layer02}`);
  console.log(`done ${((Date.now() - t0) / 1000).toFixed(1)}s. NEXT: node tools/gen_tod_twins.js   then a FULL build (GDT change)`);
}

main();
