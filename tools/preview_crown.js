#!/usr/bin/env node
// ---------------------------------------------------------------------------
// preview_crown.js — render the generated .map as SVG so a silhouette can be
// judged WITHOUT a 60-second LED bake and a game launch.
//
// WHY THIS EXISTS (2026-08-25): the crown was redesigned from "a castle with
// spikes" into a literal crown, and the only way to tell whether a pile of
// axis-aligned boxes READS as a crown is to look at it. Booting the game to
// check a silhouette costs a full build + bake + load + a 50-floor climb.
// This parses the .map the generator just wrote and draws it.
//
//   node tools/preview_crown.js                       # the crown, 4 views
//   node tools/preview_crown.js --filter "^crown"     # only crown brushes
//   node tools/preview_crown.js --all                 # the whole tower
//   node tools/preview_crown.js --out docs/crown      # output prefix
//
// It reads ONLY the .map (never the generator's internals), so it stays honest:
// what it draws is what cod2map will be handed.
// ---------------------------------------------------------------------------
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const REPO = path.join(__dirname, '..');
const MAP_IN = path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map');

// --- args ------------------------------------------------------------------
const argv = process.argv.slice(2);
function arg(name, def) {
  const i = argv.indexOf(name);
  return i >= 0 && argv[i + 1] !== undefined ? argv[i + 1] : def;
}
const SHOW_ALL = argv.includes('--all');
const FILTER = new RegExp(arg('--filter', SHOW_ALL ? '.' : '^(crown|mast|terrace|causeway (F|J4)|diadem)'), 'i');
const OUT_PREFIX = arg('--out', path.join(REPO, 'docs', 'crown_preview'));

// --- parse the .map --------------------------------------------------------
// The generator's box() emits a fixed 6-plane template. Face order and which
// coordinate is load-bearing on each line:
//   1: z1 (3rd number)   2: z2 (3rd)   3: y1 (2nd)
//   4: x2 (1st)          5: y2 (2nd)   6: x1 (1st)
// Anything that does not match that template is a non-AABB brush and is
// reported rather than silently dropped.
function parseMap(text) {
  const lines = text.split(/\r?\n/);
  const brushes = [];
  let label = null, oddities = 0;
  for (let i = 0; i < lines.length; i++) {
    const m = /^\/\/ brush \d+ [—-] (.*)$/.exec(lines[i]);
    if (m) { label = m[1].trim(); continue; }
    if (lines[i].trim() !== '{' || label === null) continue;
    const faces = [];
    let j = i + 1, mat = null;
    for (; j < lines.length && lines[j].trim() !== '}'; j++) {
      const f = /^\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s+(\S+)/.exec(lines[j]);
      if (f) { faces.push(f.slice(1, 10).map(Number)); mat = mat || f[10]; }
    }
    if (faces.length === 6) {
      const b = {
        label, mat,
        z1: faces[0][2], z2: faces[1][2],
        y1: faces[2][1], y2: faces[4][1],
        x1: faces[5][0], x2: faces[3][0],
      };
      if (b.x2 > b.x1 && b.y2 > b.y1 && b.z2 > b.z1) brushes.push(b);
      else oddities++;
    } else if (faces.length) oddities++;
    label = null;
    i = j;
  }
  return { brushes, oddities };
}

// --- palette ---------------------------------------------------------------
// Approximate the neon pack's look. Not exact — the point is silhouette and
// material GROUPING, so gold reads as gold and clip reads as nothing.
// THE PALETTE IS THE MEASURED EMISSIVE VALUE LADDER, not a guess at hue.
// Every entry is keyed to `colorTint1 x scaleRGB` read out of
// emox_mwiii_vertigo_assets.gdt (2026-08-25), converted with the usual
// 0.2126R + 0.7152G + 0.0722B. The relative brightnesses below are what the
// game will actually show, because these materials are self-lit.
//
//   yellow 13.5 | white 13.1 | orange 8.5 | yellow_tinted 7.8 | orange_tinted
//   5.8 | pap 5.1 | yellow_tinted_edge 3.9 | purple_tinted 2.9 | dark_white 2.8
//   | off 0.0
//
// SUFFIX ORDER MATTERS: `_tinted_edge` must be tested before `_tinted`, and
// `_tinted` before the plain colour, or every variant collapses into one swatch
// and the ladder — the only real design tool on this map — becomes invisible in
// the very renders being used to judge it.
const COLORS = [
  [/clip(_player)?$/i, null],             // invisible: never drawn (v13: breather window guards are clip_player)
  [/^sky$/i, null],
  [/(volume|sun_volume|umbra|fpstool)/i, null],
  [/_off$/i, '#0c0e13'],                  // 0.0 — the pack's only true black
  [/dark_white/i, '#4d525b'],             // 2.8 — the only neutral dark
  [/yellow_tinted_edge/i, '#7d6620'],     // 3.9 — dim gold, 512 tile
  [/orange_tinted/i, '#b0621a'],          // 5.8 — brass, the dark foil
  [/_pap\b/i, '#6f5aa8'],                 // 5.1 — iridescent, scrolls
  [/yellow_tinted/i, '#c9a52e'],          // 7.8 — gold panel
  [/orange/i, '#ff9a3c'],                 // 8.5
  [/white/i, '#eef2f8'],                  // 13.1 — ermine
  [/yellow/i, '#ffe45c'],                 // 13.5 — bright gold, the brightest
  [/red_tinted_edge/i, '#b8332e'],
  [/blue_tinted_edge/i, '#2f5fb8'],
  [/green_tinted_edge/i, '#2f9e63'],
  [/cyan/i, '#3ad6ea'],
  [/pink/i, '#ff5fb0'],
  [/purple_tinted/i, '#6b4bb0'],          // 2.9 — velvet
  [/purple/i, '#a06bff'],
  [/green/i, '#45e08a'],
  [/red/i, '#e8433f'],
  [/dark_blue/i, '#131b33'],
  [/blue/i, '#3b6ee0'],
];
function colorOf(mat) {
  for (const [re, c] of COLORS) if (re.test(mat)) return c;
  return '#7c8699';
}
function shade(hex, k) {
  const n = parseInt(hex.slice(1), 16);
  const r = Math.min(255, Math.round(((n >> 16) & 255) * k));
  const g = Math.min(255, Math.round(((n >> 8) & 255) * k));
  const b = Math.min(255, Math.round((n & 255) * k));
  return `#${((r << 16) | (g << 8) | b).toString(16).padStart(6, '0')}`;
}

// --- 3d --------------------------------------------------------------------
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const norm = (a) => { const l = Math.hypot(...a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };

// The 6 faces of an AABB, each as 4 corner indices + an outward normal.
const CORNERS = (b) => [
  [b.x1, b.y1, b.z1], [b.x2, b.y1, b.z1], [b.x2, b.y2, b.z1], [b.x1, b.y2, b.z1],
  [b.x1, b.y1, b.z2], [b.x2, b.y1, b.z2], [b.x2, b.y2, b.z2], [b.x1, b.y2, b.z2],
];
// FACE SHADING — DELIBERATELY ALMOST FLAT, and that is not laziness.
//
// Every material in the emox vertigo pack is `lit_emissive_advanced` (verified
// against the GDT 2026-08-25: 27 of 30 are that, the other 3 are the scroll
// variants). They are SELF-LIT. A face pointing down and a face pointing at the
// sky emit exactly the same. The crown also carries only two light entities on
// its whole fabric.
//
// So the game does NOT shade this thing by face direction, and an earlier
// version of this file did — with spreads of 0.45 to 1.15. That flattered every
// ledge, corbel, astragal and step in the renders and would have sent this
// project spending brushes on relief that produces NO value change in game.
// The k values below are near 1.0: just enough to keep an edge legible in a
// still image, not enough to invent contrast that will not be there.
//
// THE CONSEQUENCE FOR DESIGN: on this map, relief only pays when it (a) breaks
// the silhouette against sky or a darker neighbour, or (b) CARRIES A DIFFERENT
// MATERIAL. Value comes from the material ladder — plain 15 / _tinted 10 /
// _tinted_edge 5 / off 0 — never from geometry catching light.
const FACES = [
  { idx: [0, 3, 2, 1], n: [0, 0, -1], k: 0.88 },  // bottom
  { idx: [4, 5, 6, 7], n: [0, 0, 1], k: 1.06 },   // top
  { idx: [0, 1, 5, 4], n: [0, -1, 0], k: 1.00 },  // south
  { idx: [2, 3, 7, 6], n: [0, 1, 0], k: 0.94 },   // north
  { idx: [1, 2, 6, 5], n: [1, 0, 0], k: 1.02 },   // east
  { idx: [3, 0, 4, 7], n: [-1, 0, 0], k: 0.96 },  // west
];

function makeCamera(eye, target, fovDeg, W, H) {
  const fwd = norm(sub(target, eye));
  const right = norm(cross(fwd, [0, 0, 1]));
  const up = cross(right, fwd);
  const f = (H / 2) / Math.tan((fovDeg * Math.PI / 360));
  return {
    eye, fwd,
    project(p) {
      const d = sub(p, eye);
      const z = dot(d, fwd);
      if (z <= 1) return null;
      return [W / 2 + dot(d, right) * f / z, H / 2 - dot(d, up) * f / z, z];
    },
  };
}
// Orthographic camera: no perspective, for a true elevation/silhouette read.
function makeOrtho(dir, upHint, scale, W, H, centre) {
  const fwd = norm(dir);
  const right = norm(cross(fwd, upHint));
  const up = cross(right, fwd);
  return {
    eye: [centre[0] - fwd[0] * 1e6, centre[1] - fwd[1] * 1e6, centre[2] - fwd[2] * 1e6],
    fwd,
    project(p) {
      const d = sub(p, centre);
      return [W / 2 + dot(d, right) * scale, H / 2 - dot(d, up) * scale, 1e6 + dot(d, fwd)];
    },
  };
}

// --- a tiny software rasterizer + PNG writer -------------------------------
// SVG is the archival format, but nothing in this toolchain can LOOK at an SVG.
// PNG is what a human (or an agent) can actually open, so every view is written
// both ways. No dependencies: scanline-fill the same painter-sorted polygons,
// then deflate into a PNG with node's own zlib.
function rasterize(polys, W, H, bg) {
  const px = Buffer.alloc(W * H * 3);
  for (let y = 0; y < H; y++) {
    const t = y / H;
    const c = bg(t);
    for (let x = 0; x < W; x++) { const o = (y * W + x) * 3; px[o] = c[0]; px[o + 1] = c[1]; px[o + 2] = c[2]; }
  }
  for (const p of polys) {
    const rgb = [parseInt(p.fill.slice(1, 3), 16), parseInt(p.fill.slice(3, 5), 16), parseInt(p.fill.slice(5, 7), 16)];
    const vs = p.poly;
    let ymin = Infinity, ymax = -Infinity;
    for (const v of vs) { ymin = Math.min(ymin, v[1]); ymax = Math.max(ymax, v[1]); }
    const y0 = Math.max(0, Math.ceil(ymin)), y1 = Math.min(H - 1, Math.floor(ymax));
    for (let y = y0; y <= y1; y++) {
      const xs = [];
      for (let i = 0, n = vs.length; i < n; i++) {
        const a = vs[i], b = vs[(i + 1) % n];
        if ((a[1] <= y && b[1] > y) || (b[1] <= y && a[1] > y))
          xs.push(a[0] + (y - a[1]) / (b[1] - a[1]) * (b[0] - a[0]));
      }
      xs.sort((m, n) => m - n);
      for (let k = 0; k + 1 < xs.length; k += 2) {
        const xa = Math.max(0, Math.ceil(xs[k])), xb = Math.min(W - 1, Math.floor(xs[k + 1]));
        for (let x = xa; x <= xb; x++) { const o = (y * W + x) * 3; px[o] = rgb[0]; px[o + 1] = rgb[1]; px[o + 2] = rgb[2]; }
      }
    }
  }
  return px;
}
function writePng(file, px, W, H) {
  const raw = Buffer.alloc((W * 3 + 1) * H);
  for (let y = 0; y < H; y++) { raw[y * (W * 3 + 1)] = 0; px.copy(raw, y * (W * 3 + 1) + 1, y * W * 3, (y + 1) * W * 3); }
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td) >>> 0);
    return Buffer.concat([len, td, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
  ]));
}
let CRC_T = null;
function crc32(buf) {
  if (!CRC_T) {
    CRC_T = new Int32Array(256);
    for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; CRC_T[n] = c; }
  }
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_T[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return c ^ -1;
}
const SKY_BG = (t) => [Math.round(5 + 30 * t), Math.round(10 + 16 * t), Math.round(24 + 34 * t)];

function render(brushes, cam, W, H, title, sub1) {
  const polys = [];
  for (const b of brushes) {
    const col = colorOf(b.mat);
    if (!col) continue;
    const c = CORNERS(b);
    const cen = [(b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2, (b.z1 + b.z2) / 2];
    for (const f of FACES) {
      // backface cull against the view direction toward this face's centre
      const fc = f.idx.reduce((a, i) => [a[0] + c[i][0] / 4, a[1] + c[i][1] / 4, a[2] + c[i][2] / 4], [0, 0, 0]);
      const view = norm(sub(fc, cam.eye));
      if (dot(f.n, view) > -0.02) continue;
      const pts = f.idx.map(i => cam.project(c[i]));
      if (pts.some(p => p === null)) continue;
      polys.push({
        d: Math.hypot(...sub(cen, cam.eye)),
        fill: shade(col, f.k),
        poly: pts.map(p => [p[0], p[1]]),
        pts: pts.map(p => `${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(' '),
      });
    }
  }
  polys.sort((a, b) => b.d - a.d);   // painter: far first
  const out = [];
  out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`);
  out.push(`<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">` +
    `<stop offset="0" stop-color="#050a18"/><stop offset="0.6" stop-color="#0d1330"/>` +
    `<stop offset="1" stop-color="#241a3a"/></linearGradient></defs>`);
  out.push(`<rect width="${W}" height="${H}" fill="url(#sky)"/>`);
  for (const p of polys) out.push(`<polygon points="${p.pts}" fill="${p.fill}" stroke="${shade(p.fill, 0.55)}" stroke-width="0.4"/>`);
  out.push(`<text x="14" y="26" font-family="monospace" font-size="15" fill="#8fa0bd">${title}</text>`);
  if (sub1) out.push(`<text x="14" y="46" font-family="monospace" font-size="11" fill="#5f6f8d">${sub1}</text>`);
  out.push('</svg>');
  return { svg: out.join('\n'), polys };
}

// --- main ------------------------------------------------------------------
const { brushes: all, oddities } = parseMap(fs.readFileSync(MAP_IN, 'utf8'));
const sel = all.filter(b => FILTER.test(b.label));
if (!sel.length) { console.error(`no brushes matched ${FILTER}`); process.exit(1); }

const ex = sel.reduce((a, b) => ({
  x1: Math.min(a.x1, b.x1), x2: Math.max(a.x2, b.x2),
  y1: Math.min(a.y1, b.y1), y2: Math.max(a.y2, b.y2),
  z1: Math.min(a.z1, b.z1), z2: Math.max(a.z2, b.z2),
}), { x1: 1e9, x2: -1e9, y1: 1e9, y2: -1e9, z1: 1e9, z2: -1e9 });
const centre = [(ex.x1 + ex.x2) / 2, (ex.y1 + ex.y2) / 2, (ex.z1 + ex.z2) / 2];
const span = Math.max(ex.x2 - ex.x1, ex.y2 - ex.y1, ex.z2 - ex.z1);

const W = 1400, H = 1000;
const drawn = sel.filter(b => colorOf(b.mat));
const stamp = `${drawn.length} drawn / ${sel.length} selected / ${all.length} in map` +
  `  •  x[${ex.x1},${ex.x2}] y[${ex.y1},${ex.y2}] z[${ex.z1},${ex.z2}]`;

// THE TWO VIEWS THAT DECIDE THE DESIGN, both at real in-game eye positions
// rather than a flattering 3/4 orbit:
//   STREET  — standing in the base arena at z=64, looking up 19,000 units.
//             This is the "magnetize" test: if the crown does not pull the eye
//             from here, it does not do its job.
//   APPROACH— standing on the terrace where the causeway starts, eye height 64.
//             This is what the player sees for the whole last mile.
// Both are point-mirrored by the crown's own parity: read the hall centre out
// of the selection instead of assuming +y.
const EYE = 64;
const HALL_C = [centre[0], centre[1], 19392];
const SGN = HALL_C[1] >= 0 ? 1 : -1;
const streetCam = makeCamera([0, -470 * SGN, EYE], HALL_C, 62, W, H);
const approachCam = makeCamera([0, 480 * SGN, 19392 + EYE],
  [HALL_C[0], HALL_C[1], HALL_C[2] + span * 0.22], 65, W, H);

// GATE — standing on the causeway 700 units short of the crown's mouth, eye
// height 64. The one part of the crown every player is guaranteed to see from
// arm's length, so it is the one that has to survive close inspection.
//
// ANCHORED ON REAL BRUSHES, NOT ON THE SELECTION'S BOUNDING BOX. The first
// version of this camera was `HALL_C[1] - 1632 - 900`, where 1632 was CR_HY at
// CR_SCALE 1.0 and HALL_C was the bbox centre of whatever the --filter happened
// to select. Both inputs moved, so the one view whose entire job is to prove
// close-up quality was rendering from a distance that changed with the filter.
//
// AND "700 UNITS BACK ON FLAT ROAD" IS NOT A PLACE A PLAYER CAN STAND. Measured
// off the generated .map: the crown's south face is at y 6912, the J4 merge ends
// at 6880, so the head-on flat run in front of the mouth is 192 UNITS — under a
// second at a sprint. What the player actually approaches down is THE PLANK: the
// centre route of the second fork, 120 wide and raised 192 above the deck,
// running from y 4960 to 6240. That is where the crown is seen head-on from
// 700-2000 units out, slightly above the road. It is the money view and it is a
// real player position, so that is where this camera goes.
const plank = sel.find(b => /^causeway P plank 2/.test(b.label))
  || sel.find(b => /^causeway P plank \d/.test(b.label));
const mouthB = sel.find(b => /^crown mouth soffit/.test(b.label));
const MOUTH_Y = mouthB ? (SGN > 0 ? mouthB.y1 : mouthB.y2) : HALL_C[1] - 2288 * SGN;
const gateEye = plank
  ? [0, (SGN > 0 ? plank.y2 : plank.y1), plank.z2 + EYE]
  : [0, MOUTH_Y - 900 * SGN, 19392 + 192 + EYE];
const gateCam = makeCamera(gateEye, [0, MOUTH_Y + 400 * SGN, 19392 + 700], 68, W, H);

// DETAIL — a close, slightly raking look at the SOUTH band, off to one side of
// the mouth. The far read was solved by size; everything added after that is for
// the walk-up, and this is the only view at which a 128-unit moulding means
// anything.
// IT LOOKS AT THE SOUTH FACE ON PURPOSE. An earlier version orbited to the
// crown's south-EAST corner, which is 1,400 units above the road in open air —
// a viewpoint no player can ever occupy, judging a face nobody stands in front
// of. Every reachable close view of this crown is from the south: the terrace,
// the plank, the mouth, and the hall floor.
const detailCam = makeCamera(
  [1500, (MOUTH_Y - 1750) * SGN, 19392 + 260],
  [200, (MOUTH_Y + 200) * SGN, 19392 + 780], 46, W, H);
// INTERIOR — standing on the hall floor just inside the gate, looking NORTH
// across the room and up at whatever of the crown clears the 576 wall. This is
// the hold-out view: where the party spends the last 101 seconds of the run, and
// the only place the crown is seen from inside. Eye height 64, on the axis.
// NOTE the hall is at HYC = 8608 and does NOT move with the crown's CR_CY.
const interiorCam = makeCamera([0, (8608 - 620) * SGN, 19392 + EYE],
  [0, (8608 + 700) * SGN, 19392 + 1500], 72, W, H);

const views = [
  ['gate', render(sel, gateCam, W, H,
    'CROWN — THE MOUTH (on the causeway, 900 units out)', stamp)],
  ['detail', render(sel, detailCam, W, H,
    'CROWN — DETAIL (close three-quarter on the band, SE quarter)', stamp)],
  ['interior', render(sel, interiorCam, W, H,
    'CROWN — INTERIOR (on the hall floor, the hold-out view)', stamp)],
  ['street', render(sel, streetCam, W, H,
    'CROWN — THE STREET VIEW (base arena, eye height 64, looking up 19,000 units)', stamp)],
  ['approach', render(sel, approachCam, W, H,
    'CROWN — THE APPROACH (standing on the terrace, start of the causeway)', stamp)],
  // The view that matters: a player on the causeway, BELOW and in front.
  ['hero', render(sel,
    makeCamera([centre[0] - span * 0.55, ex.y1 - span * 1.15, ex.z1 - span * 0.55],
      [centre[0], centre[1], centre[2] - span * 0.05], 46, W, H), W, H,
    'CROWN — hero view (from below, off the approach)', stamp)],
  // Straight up from directly underneath: what the underside reads as.
  ['under', render(sel,
    makeCamera([centre[0], centre[1] - span * 0.35, ex.z1 - span * 1.3],
      [centre[0], centre[1], centre[2]], 52, W, H), W, H,
    'CROWN — from underneath (the approach from the tower)', stamp)],
  // True elevation: the silhouette, no perspective to flatter it.
  ['elevation', render(sel,
    makeOrtho([0, 1, 0], [0, 0, 1], (H * 0.86) / span, W, H, centre), W, H,
    'CROWN — south elevation (orthographic silhouette)', stamp)],
  ['plan', render(sel,
    makeOrtho([0, 0, -1], [0, 1, 0], (H * 0.86) / span, W, H, centre), W, H,
    'CROWN — plan (from above)', stamp)],
];

fs.mkdirSync(path.dirname(OUT_PREFIX), { recursive: true });
for (const [name, view] of views) {
  fs.writeFileSync(`${OUT_PREFIX}_${name}.svg`, view.svg, 'utf8');
  writePng(`${OUT_PREFIX}_${name}.png`, rasterize(view.polys, W, H, SKY_BG), W, H);
  console.log(`wrote ${OUT_PREFIX}_${name}.{svg,png}`);
}
console.log(`  ${stamp}`);
if (oddities) console.log(`  NOTE: ${oddities} brush(es) were not the AABB template (non-axis-aligned?) and were skipped`);
