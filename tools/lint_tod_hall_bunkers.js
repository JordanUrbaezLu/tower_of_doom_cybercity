#!/usr/bin/env node
// tools/lint_tod_hall_bunkers.js — THE NO-BUNKER GATE for the spire's trial halls.
//
// WHY THIS EXISTS (user 2026-09-10): "the layout of each trial is the same.
// Everyone just bunker up in the little cubby and withstands the trial. I dont
// want that to be allowed."
//
// A trial is a 70 s hold-out in a sealed room. A BUNKER is any spot in that
// room where the party can stand with enemies arriving from ONE narrow
// direction and nothing ever rising behind them. Every hall shipped with two
// such spots built into the SHELL — the sunken porch behind the sealed gate
// (three walls, a 140-wide mouth, nothing spawning within 300u) and the roofed
// alcove under the SE landing (three walls, a 180-wide mouth, OUTSIDE the trial
// box so nothing could ever spawn or land in it) — and v17.86's set-pieces
// added more (a caged pen with one 64-wide gate, a walled room with one door).
// Seven "different" halls all had the same answer.
//
// WHAT IT PROVES, per hall, from the EMITTED .map (never the layout table):
//
//   For every 20u cell a body can stand on at hall level (steps of <= 13
//   count as floor; anything solid between knee and head is a blocker,
//   the SEALED hall gate included), cast 72 rays over standable floor and
//   measure the OPEN ARC: the angular width from which a zombie on foot can
//   reach that cell across RAY_LEN units. A plain room corner is 90 degrees;
//   the porch pocket is ~63; a caged pen is ~25. Cells under ARC_MIN are
//   grouped into POCKETS (4-connected).
//
//   Open rays are also grouped into APPROACH SECTORS (runs of open rays with
//   a gap of SECTOR_GAP degrees or more between runs). A corridor has two
//   sectors (both ends), a room with doors on several sides has several; a
//   cubby has ONE. Only cells with a single sector count toward a bunker —
//   a spot you can be flanked at is not a cubby, however narrow its arc.
//
//   A pocket is a BUNKER when MIN_CELLS or more of its cells are one-sector
//   cells AND no riser sits INSIDE it (within RISER_IN of one of its cells) —
//   with _tod_endless_rounds' follow-the-party pick, a riser in the pocket
//   means the horde rises among whoever hides there, which is the one thing
//   that makes a pocket untenable. A riser at the MOUTH does not count: it
//   feeds the funnel.
//
// The gate FAILS on any bunker of MIN_CELLS cells or more, in any hall. No
// baseline, no regression gate: the number is zero.
//
//   node tools/lint_tod_hall_bunkers.js              -> verdict + every pocket
//   node tools/lint_tod_hall_bunkers.js --png DIR    -> + arc heatmaps, one PNG per hall
//   node tools/lint_tod_hall_bunkers.js --all        -> list every pocket incl. disarmed ones
//   node tools/lint_tod_hall_bunkers.js --probe X,Y[,N] -> trace the rays from local (X,Y) in hall N (default 1)
//   node tools/lint_tod_hall_bunkers.js --map PATH     -> lint another .map (tools/lint_tod_hall_bunkers_selftest.js)
//
// WHAT IT CANNOT SEE: script-spawned collision (PaP cabinet clips, crate
// models — the crate BODY is a .map clip and is seen), elites that land by
// PositionQuery rather than rise, and the navmesh itself (lint_tod_navmesh.js
// owns that). A pass means the geometry offers no quiet three-walled spot.
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const REPO = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
// --map PATH reads another .map (the selftest's broken copies); the anchors always come from the repo's generated data
const MAP = args.includes('--map') ? args[args.indexOf('--map') + 1] : path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map');
const DATA = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_spire_data.gsc');
const pngDir = args.includes('--png') ? args[args.indexOf('--png') + 1] : null;
const showAll = args.includes('--all');
const probe = args.includes('--probe') ? args[args.indexOf('--probe') + 1].split(',').map(Number) : null;

// --- the contract ------------------------------------------------------------
const CELL = 20;        // grid pitch (units)
const HALF = 470;       // hall local extent scanned (the drum is at +-456)
const BODY_R = 14;      // a blocker within this of a cell's footprint blocks it (fence gaps are 16: blocked)
const STEP_MAX = 13;    // a height change a walker takes without a jump (the fan / dais steps are 12)
const STAND_LO = -40, STAND_HI = 140;  // a floor top in this band is standable: fan steps to -36, dais tiers to +36, and since
                                       // v18.80 the ROOM-SCALE decks / stages to +72 (their rails at h+56 are clip-capped, so
                                       // their tops read blocked). Every cell is judged at ITS OWN top — a platform's
                                       // cells see down its stairs and along it — so a one-stair platform is a pocket
                                       // unless a riser stands ON it. Tall-wall tops (160+) stay out of the band.
const RAYS = 72;        // 5 degrees
const RAY_LEN = 160;    // a ray must run this far over walkable floor to count as an approach direction
const ARC_MIN = 80;     // degrees: a plain room corner measures ~90-95 (probe one: --probe -410,410); anything tighter is a pocket
const RISER_IN = 40;    // a riser within this of a pocket cell is INSIDE the pocket (disarms it)
const MIN_CELLS = 2;    // a pocket with fewer one-sector cells than this is a crevice, not a bunker (a body is one cell)
const SECTOR_GAP = 30;  // degrees of closed rays that separate two approach sectors

// --- anchors from the generated data (never guessed) --------------------------
const data = fs.readFileSync(DATA, 'utf8');
const num = (re) => { const m = data.match(re); if (!m) throw new Error('spire data: ' + re); return +m[1]; };
const SP_X = num(/function spire_x\(\)\s*\{\s*return\s+(-?\d+);/), SP_Y = num(/function spire_y\(\)\s*\{\s*return\s+(-?\d+);/);
const HUBS = data.match(/function hub_laps\(\)\s*\{\s*return array\(([^)]*)\)/)[1].split(',').map(s => +s.trim());
const hubZ = lap => (lap - 1) * 384 + 192;   // hub_z(): the hall floor = the mid landing
const marks = [...data.matchAll(/case (\d+): return \( (-?\d+), (-?\d+), z \+ (\d+) \);\s*\/\/ (.*)/g)];
const layoutName = i => (marks[i] ? marks[i][5].trim() : `hall ${i + 1}`);

// --- parse EVERY brush, with its owning entity's classname/targetname ---------
function parseAll(text) {
  const lines = text.split(/\r?\n/);
  const out = [];
  let label = null, depth = 0, ent = null;
  for (let i = 0; i < lines.length; i++) {
    const ln = lines[i];
    const lm = ln.match(/^\/\/ (?:brush \d+|entity \d+) — (.*)$/);
    if (lm) { label = lm[1]; continue; }
    if (ln === '{') {
      depth++;
      if (depth === 1) ent = { classname: 'worldspawn', targetname: '', label };
      if (depth >= 2 || (depth === 1 && ent && false)) {
        // a brush block (depth 2 inside an entity; worldspawn's brushes are also depth 2)
      }
      continue;
    }
    if (ln === '}') { depth--; if (depth === 0) ent = null; continue; }
    if (depth === 1 && ent) {
      const km = ln.match(/^"(\w+)" "(.*)"$/);
      if (km) { if (km[1] === 'classname') ent.classname = km[2]; if (km[1] === 'targetname') ent.targetname = km[2]; if (km[1] === 'script_noteworthy') ent.noteworthy = km[2]; if (km[1] === 'origin') ent.origin = km[2].split(' ').map(Number); }
      continue;
    }
    if (depth === 2) {
      // collect the brush planes until the closing brace
      const planes = []; let mat = null;
      let j = i;
      for (; j < lines.length && lines[j] !== '}'; j++) {
        const pm = lines[j].match(/^ \( (\S+) (\S+) (\S+) \) \( (\S+) (\S+) (\S+) \) \( (\S+) (\S+) (\S+) \) (\S+) /);
        if (!pm) continue;
        const v = pm.slice(1, 10).map(Number); mat = pm[10];
        const verts = [[v[0], v[1], v[2]], [v[3], v[4], v[5]], [v[6], v[7], v[8]]];
        for (let a = 0; a < 3; a++) if (verts[0][a] === verts[1][a] && verts[1][a] === verts[2][a]) planes.push([a, verts[0][a]]);
      }
      if (planes.length === 6 && mat) {
        const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
        for (const [a, v] of planes) { lo[a] = Math.min(lo[a], v); hi[a] = Math.max(hi[a], v); }
        out.push({ label: label || '', mat, lo, hi, classname: ent ? ent.classname : 'worldspawn', targetname: ent ? ent.targetname : '' });
      }
      i = j; depth--;   // consumed the brush's closing brace
      continue;
    }
  }
  return out;
}
// entities with an origin (the risers) — a second, simpler pass
function parseStructs(text) {
  const out = [];
  const re = /^\{\s*\nguid "[^"]*"\n((?:"[^"]+" "[^"]*"\n)+)\}/gm;
  let m;
  while ((m = re.exec(text))) {
    const kv = {};
    for (const row of m[1].trim().split('\n')) { const km = row.match(/^"(\w+)" "(.*)"$/); if (km) kv[km[1]] = km[2]; }
    if (kv.classname === 'script_struct' && kv.origin) out.push({ ...kv, org: kv.origin.split(' ').map(Number) });
  }
  return out;
}

const mapText = fs.readFileSync(MAP, 'utf8');
const brushes = parseAll(mapText);
const structs = parseStructs(mapText);
if (!brushes.some(b => /^spire hub lap\d+ hall floor/.test(b.label))) throw new Error('no spire hub hall brushes found — is the map generated?');

// --- per-hall raster ----------------------------------------------------------
// THE SEALED HALL in local coords: everything inside the drum EXCEPT the W
// flight's slot + the SW landing (x < -CORE for y < the NW piece's notch) and
// the S lane + SW landing (y < -CORE west of the S lane's end wall). The SE
// alcove under the SE landing (x > 236, y < -256) IS reachable from the E
// gallery and IS scanned — it is one of the two pockets this gate exists for.
const sealedHall = (x, y) => !(x < -256 && y < 64) && !(y < -256 && x < 236);
const N = Math.floor((HALF * 2) / CELL);                 // cells per side
const cx = i => -HALF + CELL * i + CELL / 2;              // cell centre (local)
function scanHall(hub, hubIndex) {
  const L = hubZ(hub);
  const isGate = b => b.classname === 'script_brushmodel' && b.targetname === `tod_spire_hall_gate${hub}`;
  // brushes that matter at this hall: inside the drum's footprint, within the standing band
  const local = brushes.filter(b => b.hi[0] > SP_X - HALF && b.lo[0] < SP_X + HALF && b.hi[1] > SP_Y - HALF && b.lo[1] < SP_Y + HALF
    && b.hi[2] > L + STAND_LO - 20 && b.lo[2] < L + STAND_HI + 80
    && (b.classname === 'worldspawn' || isGate(b)));
  const floors = local.filter(b => b.mat !== 'clip' && b.mat !== 'clip_player' && b.hi[2] >= L + STAND_LO && b.hi[2] <= L + STAND_HI);
  const top = new Float32Array(N * N).fill(NaN);          // standable floor top per cell (world z), NaN = none
  for (let iy = 0; iy < N; iy++) for (let ix = 0; ix < N; ix++) {
    const x = SP_X + cx(ix), y = SP_Y + cx(iy);
    // floor: the highest qualifying top under this cell's centre
    let T = NaN;
    for (const b of floors) if (x >= b.lo[0] && x <= b.hi[0] && y >= b.lo[1] && y <= b.hi[1]) { if (isNaN(T) || b.hi[2] > T) T = b.hi[2]; }
    if (isNaN(T)) continue;
    if (!sealedHall(cx(ix), cx(iy))) continue;   // outside the gate: the W flight's slot, the SW landing, the S lane
    // blocked: anything solid (clips included, the sealed gate included) inside the body band over this footprint (+ body radius)
    const x1 = x - CELL / 2 - BODY_R, x2 = x + CELL / 2 + BODY_R, y1 = y - CELL / 2 - BODY_R, y2 = y + CELL / 2 + BODY_R;
    let blocked = false;
    for (const b of local) {
      if (b.lo[2] >= T + 70 || b.hi[2] <= T + STEP_MAX + 1) continue;   // a step you can walk up is not a blocker
      if (b.hi[0] <= x1 || b.lo[0] >= x2 || b.hi[1] <= y1 || b.lo[1] >= y2) continue;
      blocked = true; break;
    }
    if (!blocked) top[iy * N + ix] = T;
  }
  const at = (ix, iy) => (ix < 0 || iy < 0 || ix >= N || iy >= N) ? NaN : top[iy * N + ix];
  // open arc per standable cell
  const arc = new Float32Array(N * N).fill(NaN);
  const sectors = new Uint8Array(N * N);
  for (let iy = 0; iy < N; iy++) for (let ix = 0; ix < N; ix++) {
    const T0 = at(ix, iy);
    if (isNaN(T0)) continue;
    let open = 0;
    const openRay = new Uint8Array(RAYS);
    for (let r = 0; r < RAYS; r++) {
      const a = (2 * Math.PI * r) / RAYS, dx = Math.cos(a), dy = Math.sin(a);
      let prev = T0, ok = true;
      for (let d = CELL / 2; d <= RAY_LEN; d += CELL / 2) {
        const px = cx(ix) + dx * d, py = cx(iy) + dy * d;
        const jx = Math.floor((px + HALF) / CELL), jy = Math.floor((py + HALF) / CELL);
        const T = at(jx, jy);
        if (isNaN(T) || Math.abs(T - prev) > STEP_MAX) { ok = false; break; }
        prev = T;
      }
      if (ok) { open++; openRay[r] = 1; }
    }
    arc[iy * N + ix] = (open * 360) / RAYS;
    // sectors: runs of open rays, circular, split by a closed gap >= SECTOR_GAP
    {
      const gap = Math.round(SECTOR_GAP / (360 / RAYS));
      let n = 0;
      if (open > 0 && open < RAYS) {
        // start scanning just after a closed run so the wrap does not split a sector
        let start = 0; while (openRay[start]) start++;
        let closed = gap, inRun = false;
        for (let k = 0; k < RAYS; k++) {
          const r = (start + k) % RAYS;
          if (openRay[r]) { if (!inRun && closed >= gap) n++; inRun = true; closed = 0; }
          else { closed++; if (closed >= gap) inRun = false; }
        }
        if (n === 0) n = 1;
      } else if (open === RAYS) n = 4;
      sectors[iy * N + ix] = n;
    }
  }
  // --probe X,Y : trace every ray from the cell under local (X,Y) in the FIRST hall
  if (probe && hubIndex === (probe.length > 2 ? probe[2] - 1 : 0)) {
    const ix = Math.floor((probe[0] + HALF) / CELL), iy = Math.floor((probe[1] + HALF) / CELL);
    console.log(`probe cell (${cx(ix)}, ${cx(iy)}): floor top ${isNaN(at(ix, iy)) ? 'NONE (blocked or void)' : (at(ix, iy) - L) + ' above hall'}  arc ${arc[iy * N + ix]}  sectors ${sectors[iy * N + ix]}`);
    for (let r = 0; r < RAYS; r += 6) {
      const a = (2 * Math.PI * r) / RAYS, dx = Math.cos(a), dy = Math.sin(a);
      let prev = at(ix, iy), trail = [];
      for (let d = CELL / 2; d <= RAY_LEN; d += CELL / 2) {
        const jx = Math.floor((cx(ix) + dx * d + HALF) / CELL), jy = Math.floor((cx(iy) + dy * d + HALF) / CELL);
        const T = at(jx, jy);
        trail.push(isNaN(T) ? 'X' : (T - L));
        if (isNaN(T) || Math.abs(T - prev) > STEP_MAX) break;
        prev = T;
      }
      console.log(`  ray ${String(r * 5).padStart(3)}deg: ${trail.join(' ')}`);
    }
  }
  // risers at this hall's level
  const risers = structs.filter(s => s.script_noteworthy === 'riser_location' && s.org[2] - L >= STAND_LO - 20 && s.org[2] - L <= STAND_HI   // v18.80: deck-top risers count
    && Math.abs(s.org[0] - SP_X) < HALF && Math.abs(s.org[1] - SP_Y) < HALF).map(s => [s.org[0] - SP_X, s.org[1] - SP_Y]);
  // pockets: 4-connected clusters of low-arc cells
  const seen = new Uint8Array(N * N);
  const pockets = [];
  for (let iy = 0; iy < N; iy++) for (let ix = 0; ix < N; ix++) {
    const k = iy * N + ix;
    if (seen[k] || isNaN(arc[k]) || arc[k] >= ARC_MIN) continue;
    const cells = []; const stack = [[ix, iy]]; seen[k] = 1;
    while (stack.length) {
      const [px, py] = stack.pop(); cells.push([px, py]);
      for (const [qx, qy] of [[px + 1, py], [px - 1, py], [px, py + 1], [px, py - 1]]) {
        if (qx < 0 || qy < 0 || qx >= N || qy >= N) continue;
        const q = qy * N + qx;
        if (seen[q] || isNaN(arc[q]) || arc[q] >= ARC_MIN) continue;
        seen[q] = 1; stack.push([qx, qy]);
      }
    }
    let sx = 0, sy = 0, minArc = 360, one = 0;
    for (const [px, py] of cells) { sx += cx(px); sy += cx(py); minArc = Math.min(minArc, arc[py * N + px]); if (sectors[py * N + px] <= 1) one++; }
    const c = [Math.round(sx / cells.length), Math.round(sy / cells.length)];
    let riserIn = null, nearest = Infinity;
    for (const r of risers) {
      let dmin = Infinity;
      for (const [px, py] of cells) dmin = Math.min(dmin, Math.hypot(cx(px) - r[0], cx(py) - r[1]));
      nearest = Math.min(nearest, dmin);
      if (dmin <= RISER_IN) riserIn = r;
    }
    const where = whereIs(c, cells.map(([px, py]) => [cx(px), cx(py)]));
    pockets.push({ cells, n: cells.length, one, centre: c, minArc: Math.round(minArc), riserIn, nearest: Math.round(nearest), where,
      bunker: one >= MIN_CELLS && !riserIn });
  }
  pockets.sort((a, b) => b.n - a.n);
  return { hub, hubIndex, L, top, arc, sectors, risers, pockets, name: layoutName(hubIndex) };
}
// named by ANY cell in the two shell pockets (a pocket that runs out of the porch
// into the doorway's corner has its centroid outside the porch), else by centroid
function whereIs([x, y], cells) {
  const pts = cells || [[x, y]];
  if (pts.some(([px, py]) => px < -160 && py < -96 && py > -256)) return 'SW PORCH POCKET (behind the sealed gate)';
  if (pts.some(([px, py]) => px > 256 && py < -256)) return 'SE ALCOVE (under the SE landing)';
  const ns = y > 150 ? 'N' : y < -100 ? 'S' : '';
  const ew = x > 150 ? 'E' : x < -150 ? 'W' : '';
  return (ns + ew) || 'centre';
}

// --- PNG heatmaps (the preview tool's writer) ---------------------------------
function makeCanvas(w, h) { return { w, h, px: Buffer.alloc(w * h * 3, 18) }; }
function fillRect(c, x1, y1, x2, y2, rgb) {
  x1 = Math.max(0, Math.floor(x1)); y1 = Math.max(0, Math.floor(y1)); x2 = Math.min(c.w, Math.ceil(x2)); y2 = Math.min(c.h, Math.ceil(y2));
  for (let y = y1; y < y2; y++) for (let x = x1; x < x2; x++) { const o = (y * c.w + x) * 3; c.px[o] = rgb[0]; c.px[o + 1] = rgb[1]; c.px[o + 2] = rgb[2]; }
}
function writePng(file, c) {
  const raw = Buffer.alloc((c.w * 3 + 1) * c.h);
  for (let y = 0; y < c.h; y++) { raw[y * (c.w * 3 + 1)] = 0; c.px.copy(raw, y * (c.w * 3 + 1) + 1, y * c.w * 3, (y + 1) * c.w * 3); }
  const crcTable = []; for (let n = 0; n < 256; n++) { let cc = n; for (let k = 0; k < 8; k++) cc = (cc & 1) ? (0xedb88320 ^ (cc >>> 1)) : (cc >>> 1); crcTable[n] = cc >>> 0; }
  const crc = b => { let cc = 0xffffffff; for (const x of b) cc = crcTable[(cc ^ x) & 0xff] ^ (cc >>> 8); return (cc ^ 0xffffffff) >>> 0; };
  const chunk = (type, d) => { const len = Buffer.alloc(4); len.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(type), d]); const cr = Buffer.alloc(4); cr.writeUInt32BE(crc(td)); return Buffer.concat([len, td, cr]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(c.w, 0); ihdr.writeUInt32BE(c.h, 4); ihdr[8] = 8; ihdr[9] = 2;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}
const FONT = { A: '0E1F1B1F1B1B1B', B: '1E1B1E1B1B1B1E', C: '0E1B1818181B0E', D: '1E1B1B1B1B1B1E', E: '1F18181E18181F', F: '1F18181E181818', G: '0E1B181F1B1B0F', H: '1B1B1B1F1B1B1B', I: '0E060606060E00', J: '070303031B1B0E', K: '1B1B1E1C1E1B1B', L: '18181818181B1F', M: '111B1F1F151111', N: '111919151313111', O: '0E1B1B1B1B1B0E', P: '1E1B1B1E181818', Q: '0E1B1B1B1F0E03', R: '1E1B1B1E1C1E1B', S: '0F181E0F03031E', T: '1F060606060606', U: '1B1B1B1B1B1B0E', V: '1B1B1B1B1B0E04', W: '1111111515151B', X: '1B1B0E040E1B1B', Y: '1B1B0E06060606', Z: '1F03060C18181F', ' ': '00000000000000', '-': '0000001F000000', 0: '0E1B1B1B1B1B0E', 1: '060E06060606060E', 2: '0E1B03060C181F', 3: '1E03030E03031E', 4: '1B1B1B1F030303', 5: '1F18181E03031E', 6: '0E18181E1B1B0E', 7: '1F0303060C0C0C', 8: '0E1B1B0E1B1B0E', 9: '0E1B1B0F03030E', '.': '00000000000606', ':': '00060600060600', '/': '01030306060C18', '(': '03060606060603', ')': '180C0C0C0C0C18' };
function text(c, x, y, str, rgb, s = 2) {
  let px = x;
  for (const ch of str.toUpperCase()) {
    const g = FONT[ch] || FONT[' '];
    for (let r = 0; r < 7; r++) { const bits = parseInt(g.slice(r * 2, r * 2 + 2), 16); for (let col = 0; col < 5; col++) if (bits & (1 << (4 - col))) fillRect(c, px + col * s, y + r * s, px + col * s + s, y + r * s + s, rgb); }
    px += 6 * s;
  }
}
function heat(a) {   // arc -> colour: red (0) .. yellow (ARC_MIN) .. green (180) .. blue-white (360)
  if (a < ARC_MIN) { const t = a / ARC_MIN; return [220, Math.round(40 + 140 * t), 40]; }
  if (a < 180) { const t = (a - ARC_MIN) / (180 - ARC_MIN); return [Math.round(200 - 140 * t), 200, 60]; }
  const t = Math.min(1, (a - 180) / 180); return [Math.round(60 + 60 * t), Math.round(200 - 60 * t), Math.round(60 + 180 * t)];
}
function drawHall(h) {
  const S = 1, PAD = 28, W = N * CELL * S / 2;   // 0.5 px per unit
  const c = makeCanvas(W, W + PAD * 2);
  const toPx = (x, y) => [(x + HALF) / 2, (HALF - y) / 2 + PAD];
  for (let iy = 0; iy < N; iy++) for (let ix = 0; ix < N; ix++) {
    const k = iy * N + ix;
    if (isNaN(h.top[k])) continue;
    const [px, py] = toPx(cx(ix) - CELL / 2, cx(iy) + CELL / 2);
    const col = isNaN(h.arc[k]) ? [40, 40, 40] : heat(h.arc[k]);
    fillRect(c, px, py, px + CELL / 2, py + CELL / 2, (h.arc[k] < ARC_MIN && h.sectors[k] >= 2) ? [Math.round(col[0] * 0.55), Math.round(col[1] * 0.55), Math.round(col[2] * 0.55)] : col);
  }
  for (const p of h.pockets) if (p.n >= MIN_CELLS) {
    const col = p.bunker ? [255, 255, 255] : [120, 120, 255];
    for (const [ix, iy] of p.cells) { const [px, py] = toPx(cx(ix) - CELL / 2, cx(iy) + CELL / 2); fillRect(c, px, py, px + 2, py + 2, col); fillRect(c, px + 8, py + 8, px + 10, py + 10, col); }
  }
  for (const r of h.risers) { const [px, py] = toPx(r[0], r[1]); fillRect(c, px - 4, py - 4, px + 4, py + 4, [0, 0, 0]); fillRect(c, px - 2, py - 2, px + 2, py + 2, [255, 255, 255]); }
  const bunkers = h.pockets.filter(p => p.bunker).length;
  text(c, 6, 8, `${h.name} FLOOR ${h.hub}  BUNKERS ${bunkers}`, bunkers ? [255, 90, 90] : [120, 255, 120], 2);
  text(c, 6, W + PAD + 8, 'RED = ONE-WAY ARC UNDER ' + ARC_MIN + '  DIM = TWO-WAY SLOT  WHITE = BUNKER  BLUE = RISER INSIDE  SQUARES = RISERS', [150, 150, 150], 1);
  return c;
}

// --- run ------------------------------------------------------------------------
const halls = HUBS.map((hub, i) => scanHall(hub, i));
let fail = 0;
for (const h of halls) {
  const bunkers = h.pockets.filter(p => p.bunker);
  fail += bunkers.length;
  const stand = Array.from(h.top).filter(v => !isNaN(v)).length;
  console.log(`hall ${h.hubIndex + 1} ${h.name} (floor ${h.hub}): ${stand} standable cells, ${h.risers.length} risers, ${h.pockets.filter(p => p.n >= MIN_CELLS).length} pockets, ${bunkers.length} BUNKER${bunkers.length === 1 ? '' : 'S'}`);
  for (const p of h.pockets) {
    if (!p.bunker && !showAll) continue;
    if (p.n < MIN_CELLS && !showAll) continue;
    console.log(`   ${p.bunker ? 'BUNKER ' : 'pocket '} ${String(p.n).padStart(3)} cells (${String(p.one).padStart(3)} one-way) at (${p.centre[0]}, ${p.centre[1]})  min arc ${p.minArc}  ${p.riserIn ? `riser inside at (${p.riserIn[0]}, ${p.riserIn[1]})` : `nearest riser ${p.nearest === Infinity ? 'none' : p.nearest + 'u away'}`}  — ${p.where}`);
  }
}
if (pngDir) {
  fs.mkdirSync(pngDir, { recursive: true });
  const cs = halls.map(drawHall);
  cs.forEach((c, i) => writePng(path.join(pngDir, `bunkers_${i + 1}.png`), c));
  const cols = 4, rows = Math.ceil(cs.length / cols);
  const sheet = makeCanvas(cols * cs[0].w, rows * cs[0].h);
  cs.forEach((c, i) => { const ox = (i % cols) * c.w, oy = Math.floor(i / cols) * c.h; for (let y = 0; y < c.h; y++) c.px.copy(sheet.px, ((oy + y) * sheet.w + ox) * 3, y * c.w * 3, (y + 1) * c.w * 3); });
  writePng(path.join(pngDir, 'bunkers_sheet.png'), sheet);
  console.log(`wrote ${cs.length} heatmaps + bunkers_sheet.png to ${pngDir}`);
}
console.log(fail ? `\nHALL BUNKERS: FAIL — ${fail} bunker pocket${fail === 1 ? '' : 's'} (arc < ${ARC_MIN} deg over ${RAY_LEN}u from ONE direction, >= ${MIN_CELLS} such cells, no riser inside)` : `\nHALL BUNKERS: OK — no one-way quiet spot in any hall`);
process.exit(fail ? 1 : 0);
