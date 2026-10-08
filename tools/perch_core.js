'use strict';
// tools/perch_core.js — THE PERCH MODEL, shared by the generator's PERCH SEAL pass
// (gen_tower_map.js, which closes every perch it finds before writing the .map) and
// tools/lint_tod_perches.js (which re-proves the finished .map from scratch, every build).
// One model, two callers: the gate can never disagree with the fixer about what a
// perch is, and the fixer can never "fix" something the gate would still call open.
//
// A PERCH is an upward face a player can rest on, with crouch headroom above it, that
//   * is not a floor the horde walks (a DECK the navmesh covers, or a stair-ramp top),
//   * has no zombie-standable floor close enough below it for a melee swing to land
//     (stock zombie.gsc zombieShouldMeleeCondition: origin-to-origin 3D <= 64), and
//   * is within athlete reach of a walkable floor: more than STEP_MAX and at most
//     REACH_V above it, at most REACH_H across, with nothing in between that rises
//     past both ends (a rail and its cap, a wall, the core).
// Every number is a parameter (DEFAULTS below); both callers pass the same object.
//
// Input brushes: [{ label, planes }] — planes from convex_brush.readPlanes (the .map's
// own plane text), so an axial box and a sloped wedge go through exactly one path.
const CB = require('./convex_brush');

const DEFAULTS = {
  STEP_MAX: 18,      // BO3 walks up this without a jump; the navmesh joins floors this far apart
  HEAD: 48,          // crouch headroom: a player who fits crouched can perch (standing is 72)
  HALF: 15,          // player box half-width
  REACH_V: 200,      // athlete Lv5 jump (2.25 x 39 = ~88) + a wall-run rise + the kick off the wall, generous
  REACH_H: 192,      // how far across from a floor a wall-run kick can carry, generous
  SAMPLE: 8,         // top-face sampling step
  G: 20,             // floor sampling grid
  ZM_MELEE: 64,      // stock ZM_MELEE_DIST (zombie.gsh)
  MELEE_GAP: 24,     // the closest a zombie's origin gets across to a player standing on a prop
  // THE FIELD EVIDENCE OVERRULES THE ARITHMETIC: by stock's 3D melee distance a zombie
  // beside the 40-tall Rampage inducer body could swing at a player on it — and the
  // Workshop tester stood there untouched ("I was able to replicate this with rampage
  // also"). A player off the navmesh is chased to his last valid position, not engaged.
  // So the melee rule only clears a top lower than this; anything this high above the
  // floor beside it is a perch however close the horde can stand.
  HIT_DZ_MAX: 30,
};

// --- floors: what the horde walks on (mirrors lint_tod_geometry's taxonomy) ----
const PAL = ['blue', 'cyan', 'green', 'orange', 'pink', 'purple', 'red', 'yellow'];
const DECK_MATS = new Set(['mwiii_vertigo_retro_synth_dark_blue_tinted']);
for (const c of PAL) { DECK_MATS.add(`mwiii_vertigo_retro_synth_${c}_tinted`); DECK_MATS.add(`mwiii_vertigo_retro_synth_${c}_tinted_edge`); }
const DECK_LABELS = /^(ground slab|power hall floor|tp bay floor)$/;
const MAX_SLAB = 64;
// A stair ramp's top IS the zombie floor on a flight (plain clip since v16.61a).
const RAMP_LABEL = /stair ramp|ramp wedge|road stair ramp|ramp$/;

// worldspawn only: everything after "// entity 1" is an entity (script_brushmodels
// toggle at runtime and are the script's business, not this model's)
function parseMapWorld(text) {
  const end = text.indexOf('// entity 1 ');
  const world = end >= 0 ? text.slice(0, end) : text;
  const lines = world.split(/\r?\n/);
  const out = [];
  let label = null, buf = null;
  for (const ln of lines) {
    const lm = ln.match(/^\/\/ brush \d+ — (.*)$/);
    if (lm) { label = lm[1]; continue; }
    if (ln === '{' && label !== null) { buf = []; continue; }
    if (buf && ln === '}') {
      out.push({ label, planes: CB.readPlanes(buf.join('\n')) });
      buf = null; label = null; continue;
    }
    if (buf) buf.push(ln);
  }
  return out;
}

function prepare(raw) {
  const brushes = [];
  for (const r of raw) {
    if (!r.planes || r.planes.length < 4) continue;
    let h;
    try { h = CB.hull(r.planes); } catch (e) { continue; }
    const axial = r.planes.every(q => Math.abs(Math.abs(q.n[0]) + Math.abs(q.n[1]) + Math.abs(q.n[2]) - 1) < 1e-6);
    const topFace = h.faces.reduce((a, f) => (f.n[2] > 0.99 && (!a || f.d > a.d) ? f : a), null);
    const mat = topFace ? topFace.mat : r.planes[0].mat;
    const b = { label: r.label, planes: r.planes, h, axial, mat, lo: h.lo, hi: h.hi, src: r };
    b.isRamp = RAMP_LABEL.test(b.label);
    b.isDeck = b.axial && (DECK_MATS.has(b.mat) || DECK_LABELS.test(b.label)) && (b.hi[2] - b.lo[2]) <= MAX_SLAB;
    brushes.push(b);
  }
  return brushes;
}

// analyze(raw, opts) -> { brushes, perches: [{ idx, label, n, x, y, z, dz, d, f, face }] }
//   face = { x1, x2, y1, y2, z1, z2 } the flagged face's bounds (what a seal must cover)
//   opts.near = { p: [x,y,z], r } restricts the search (the lint's --near)
function analyze(raw, opts = {}) {
  const P = Object.assign({}, DEFAULTS, opts);
  const { STEP_MAX, HEAD, HALF, REACH_V, REACH_H, SAMPLE, G, ZM_MELEE, MELEE_GAP, HIT_DZ_MAX } = P;
  const NEAR = opts.near || null;
  const brushes = prepare(raw);

  // spatial hash of every solid (everything in worldspawn is solid to a player), in
  // 3D: this map stacks 50 + 70 laps over the same few hundred square units, so an
  // xy-only hash hands every query the whole tower.
  const CELL = 128, ZCELL = 256;
  const hash = new Map();
  const ck = (i, j, k) => `${i},${j},${k}`;
  brushes.forEach((b, idx) => {
    for (let i = Math.floor(b.lo[0] / CELL); i <= Math.floor(b.hi[0] / CELL); i++)
      for (let j = Math.floor(b.lo[1] / CELL); j <= Math.floor(b.hi[1] / CELL); j++)
        for (let k = Math.floor(b.lo[2] / ZCELL); k <= Math.floor(b.hi[2] / ZCELL); k++) {
          const key = ck(i, j, k);
          if (!hash.has(key)) hash.set(key, []);
          hash.get(key).push(idx);
        }
  });
  // de-duplicated without a Set: a per-query stamp (this runs millions of times)
  const stamp = new Int32Array(brushes.length);
  let qid = 0;
  const near = (x1, x2, y1, y2, z1, z2) => {
    qid++;
    const out = [];
    const i1 = Math.floor(x1 / CELL), i2 = Math.floor(x2 / CELL), j1 = Math.floor(y1 / CELL), j2 = Math.floor(y2 / CELL);
    const k1 = Math.floor(z1 / ZCELL), k2 = Math.floor(z2 / ZCELL);
    for (let i = i1; i <= i2; i++)
      for (let j = j1; j <= j2; j++)
        for (let k = k1; k <= k2; k++) {
          const l = hash.get(ck(i, j, k));
          if (!l) continue;
          for (const idx of l) if (stamp[idx] !== qid) { stamp[idx] = qid; out.push(idx); }
        }
    return out;
  };
  // Is the player box centred (cx,cy), bottom z0, top z0+HEAD, free of every solid?
  const boxFree = (cx, cy, z0, skip) => {
    const x1 = cx - HALF, x2 = cx + HALF, y1 = cy - HALF, y2 = cy + HALF, z1 = z0 + 0.5, z2 = z0 + HEAD;
    for (const idx of near(x1, x2, y1, y2, z1, z2)) {
      if (idx === skip) continue;
      const b = brushes[idx];
      if (b.hi[0] <= x1 + 0.01 || b.lo[0] >= x2 - 0.01 || b.hi[1] <= y1 + 0.01 || b.lo[1] >= y2 - 0.01 || b.hi[2] <= z1 || b.lo[2] >= z2) continue;
      if (b.axial) return false;
      // convex: sample the box footprint against the brush's vertical span
      for (const fx of [x1 + 0.5, cx, x2 - 0.5]) for (const fy of [y1 + 0.5, cy, y2 - 0.5]) {
        const s = CB.verticalSpan(b.planes, fx, fy);
        if (s && s[0] < z2 && s[1] > z1) return false;
      }
    }
    return true;
  };

  // FLOOR POINTS: every walkable surface sampled on a G grid (decks + ramp tops),
  // bucketed into BUCKET-sized cells so a perch only looks at its neighbourhood.
  const BUCKET = 64, ZB = 128;
  const fl = new Map();
  const bk = (x, y, z) => `${Math.floor(x / BUCKET)},${Math.floor(y / BUCKET)},${Math.floor(z / ZB)}`;
  const addFloor = (x, y, z) => {
    const k = bk(x, y, z);
    if (!fl.has(k)) fl.set(k, []);
    fl.get(k).push([x, y, z]);
  };
  for (const b of brushes) {
    if (!b.isDeck && !b.isRamp) continue;
    for (let x = b.lo[0] + G / 2; x < b.hi[0]; x += G)
      for (let y = b.lo[1] + G / 2; y < b.hi[1]; y += G) {
        if (b.isDeck) { addFloor(x, y, b.hi[2]); continue; }
        const s = CB.verticalSpan(b.planes, x, y);
        if (s) addFloor(x, y, s[1]);
      }
  }
  // a floor point counts for the horde only if a body fits on it (no solid in the
  // zombie's height above it) — the deck runs on under every prop's clip column
  const floorOpen = (f) => {
    if (f.open !== undefined) return f.open;
    f.open = true;
    for (const idx of near(f[0], f[0], f[1], f[1], f[2] + 1, f[2] + 60)) {
      const b = brushes[idx];
      if (f[0] < b.lo[0] || f[0] > b.hi[0] || f[1] < b.lo[1] || f[1] > b.hi[1]) continue;
      const sp = b.axial ? [b.lo[2], b.hi[2]] : CB.verticalSpan(b.planes, f[0], f[1]);
      if (sp && sp[0] < f[2] + 60 && sp[1] > f[2] + 1) { f.open = false; break; }
    }
    return f.open;
  };
  const floorsNear = (x, y, r, z1, z2) => {
    const out = [];
    for (let i = Math.floor((x - r) / BUCKET); i <= Math.floor((x + r) / BUCKET); i++)
      for (let j = Math.floor((y - r) / BUCKET); j <= Math.floor((y + r) / BUCKET); j++)
        for (let k = Math.floor(z1 / ZB); k <= Math.floor(z2 / ZB); k++) {
          const l = fl.get(`${i},${j},${k}`);
          if (l) for (const p of l) out.push(p);
        }
    return out;
  };
  // THE PATH. A floor only reaches a perch if nothing stands in the way: a solid on
  // the straight run between them that rises past both ends (a rail and its cap, a
  // wall, the core) has to be cleared, which is more height than the perch itself —
  // so that floor does not count. Sampled every 12 units in plan.
  const pathClear = (f, p, skip) => {
    const top = Math.max(f[2], p[2]);
    const d = Math.hypot(p[0] - f[0], p[1] - f[1]);
    const n = Math.max(1, Math.ceil(d / 12));
    for (let s = 1; s < n; s++) {
      const t = s / n, x = f[0] + (p[0] - f[0]) * t, y = f[1] + (p[1] - f[1]) * t;
      for (const idx of near(x, x, y, y, top, top + 48)) {
        if (idx === skip) continue;
        const b = brushes[idx];
        if (x < b.lo[0] || x > b.hi[0] || y < b.lo[1] || y > b.hi[1]) continue;
        const sp = b.axial ? [b.lo[2], b.hi[2]] : CB.verticalSpan(b.planes, x, y);
        if (!sp) continue;
        // in the way: it starts below the climb's top and rises well past it
        if (sp[0] < top + 24 && sp[1] > top + 48) return false;
      }
    }
    return true;
  };
  // F = the floors gathered ONCE for the whole face (see the face loop)
  const reachFrom = (F, x, y, z, skip) => {
    const cand = [];
    for (const f of F) {
      const dx = f[0] - x, dy = f[1] - y;
      const d = Math.sqrt(dx * dx + dy * dy);
      if (d > REACH_H) continue;
      const dz = z - f[2];
      if (dz > REACH_V || dz < -STEP_MAX) continue;
      if (dz <= STEP_MAX && d <= G * 1.5) return { connected: true };
      // a zombie standing on this floor can still swing at a player up here
      if (dz >= 0 && dz < HIT_DZ_MAX && Math.hypot(Math.max(d, MELEE_GAP), dz) <= ZM_MELEE && floorOpen(f)) return { connected: true };
      if (dz <= STEP_MAX) continue;
      cand.push({ f, d, dz });
    }
    cand.sort((a, b) => a.dz - b.dz || a.d - b.d);
    for (const c of cand) if (pathClear(c.f, [x, y, z], skip)) return { dz: c.dz, d: c.d, fz: c.f[2], f: c.f };
    return null;
  };
  const anyFloorInReach = (x1, x2, y1, y2, z1, z2) => {
    const cx = (x1 + x2) / 2, cy = (y1 + y2) / 2, r = REACH_H + Math.hypot(x2 - x1, y2 - y1) / 2;
    for (const f of floorsNear(cx, cy, r, z1 - REACH_V, z2 + STEP_MAX)) {
      const dz1 = z1 - f[2], dz2 = z2 - f[2];
      if (dz2 >= -STEP_MAX && dz1 <= REACH_V) return true;
    }
    return false;
  };

  // candidate top faces: every upward face flat enough to stand on (n.z >= 0.7, i.e.
  // under ~45.6 deg — steeper and a player slides) of every brush that is not a floor
  const SHIFTS = [[0, 0], [HALF - 1, 0], [-(HALF - 1), 0], [0, HALF - 1], [0, -(HALF - 1)],
                  [HALF - 1, HALF - 1], [HALF - 1, -(HALF - 1)], [-(HALF - 1), HALF - 1], [-(HALF - 1), -(HALF - 1)]];
  const perches = [];
  for (let idx = 0; idx < brushes.length; idx++) {
    const b = brushes[idx];
    if (b.isDeck || b.isRamp) continue;
    for (const f of b.h.faces) {
      if (f.n[2] < 0.7) continue;
      const fx1 = Math.min(...f.vertices.map(v => v[0])), fx2 = Math.max(...f.vertices.map(v => v[0]));
      const fy1 = Math.min(...f.vertices.map(v => v[1])), fy2 = Math.max(...f.vertices.map(v => v[1]));
      const fz1 = Math.min(...f.vertices.map(v => v[2])), fz2 = Math.max(...f.vertices.map(v => v[2]));
      if (NEAR && (fx2 < NEAR.p[0] - NEAR.r || fx1 > NEAR.p[0] + NEAR.r || fy2 < NEAR.p[1] - NEAR.r || fy1 > NEAR.p[1] + NEAR.r)) continue;
      if (!anyFloorInReach(fx1, fx2, fy1, fy2, fz1, fz2)) continue;
      const F = floorsNear((fx1 + fx2) / 2, (fy1 + fy2) / 2, REACH_H + Math.hypot(fx2 - fx1, fy2 - fy1) / 2, fz1 - REACH_V, fz2 + STEP_MAX);
      const pts = [];
      for (let x = fx1 + Math.min(SAMPLE / 2, (fx2 - fx1) / 2); x <= fx2 + 0.01; x += SAMPLE)
        for (let y = fy1 + Math.min(SAMPLE / 2, (fy2 - fy1) / 2); y <= fy2 + 0.01; y += SAMPLE) pts.push([x, y]);
      let hit = null, nHit = 0;
      for (const [x, y] of pts) {
        const s = b.axial ? [b.lo[2], b.hi[2]] : CB.verticalSpan(b.planes, x, y);
        if (!s) continue;
        const z = s[1];
        if (NEAR && Math.hypot(x - NEAR.p[0], y - NEAR.p[1], z - NEAR.p[2]) > NEAR.r) continue;
        const r = reachFrom(F, x, y, z, idx);
        if (!r || r.connected) continue;
        // can a player's box rest on this point? the box centred on it, or shifted
        // most of a box each way (a box may overhang the edge it stands on)
        let ok = false;
        for (const [ox, oy] of SHIFTS) if (boxFree(x + ox, y + oy, z, idx)) { ok = true; break; }
        if (!ok) continue;
        nHit++;
        if (!hit || r.dz < hit.dz) hit = { x, y, z, dz: r.dz, d: r.d, f: r.f };
      }
      if (hit) perches.push({ idx, label: b.label, n: nHit, ...hit, face: { x1: fx1, x2: fx2, y1: fy1, y2: fy2, z1: fz1, z2: fz2 } });
    }
  }
  return { brushes, perches, params: P };
}

module.exports = { DEFAULTS, parseMapWorld, prepare, analyze };
