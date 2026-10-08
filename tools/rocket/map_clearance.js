'use strict';
// map_clearance.js - "how far is this point from the nearest VISIBLE brush?" for the rocket rides (docs/170).
//
// Reads map_source/zm/zm_tower_of_doom.map (worldspawn AND every brush entity - the crown door, the gates and the
// spire slabs are script_brushmodels and are drawn), decodes each brush's planes with tools/convex_brush.js and
// keeps the ones a camera could SEE: a brush counts when any face wears a material that is not a tool texture
// (clip / caulk / trigger / portal / volume / sky ...). A script_model rocket has no collision at all, so these are
// VISUAL clearances: a hull through a wall, a camera inside a brush.
//
// distance(p) = the largest plane distance of the nearest brush = a LOWER BOUND of the true distance outside a
// convex brush (exact against a face, short of it near an edge or a corner), negative inside. So "distance(p) > r"
// PROVES a sphere of radius r at p touches nothing; a fail near a corner may be a false alarm, never the reverse.
//
//   const M = loadMap();  M.distance([x,y,z], maxR) -> { d, brush } ; M.brushes ; M.skyBox
const fs = require('fs');
const path = require('path');
const CB = require('../convex_brush.js');

const REPO = path.resolve(__dirname, '..', '..');
const MAP = path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map');
// tool materials: never drawn (a brush made only of these is invisible to the camera)
const TOOL = /(clip|caulk|nodraw|trigger|portal|hint|skip|volume|umbra|lightgrid|probe|origin|mantle|aiclip|monster|^sky|\/sky)/i;
const TOOL_ENT = /^(volume|trigger|info_volume|reflection_probe|umbra|lightgrid|sun_volume)/i;

function loadMap(file = MAP) {
  const text = fs.readFileSync(file, 'utf8');
  const brushes = [];
  let sky = null;
  // walk the file: entities { ... brushes { ... } ... }; a brush block is one { } holding plane lines
  let depth = 0, entKv = {}, brushText = null, entClass = null;
  const lines = text.split(/\r?\n/);
  for (const raw of lines) {
    const line = raw.trim();
    if (line === '{') {
      depth++;
      if (depth === 1) { entKv = {}; entClass = null; }
      else if (depth === 2) brushText = [];
      continue;
    }
    if (line === '}') {
      if (depth === 2 && brushText) {
        const planes = CB.readPlanes(brushText.join('\n'));
        if (planes.length >= 4) {
          let h = null;
          try { h = CB.hull(planes); } catch (e) { h = null; }
          if (h) {
            const mats = planes.map(p => p.mat);
            const visible = mats.some(m => !TOOL.test(m)) && !TOOL_ENT.test(entClass || '');
            const isSky = mats.some(m => /(^|\/)sky/i.test(m));
            brushes.push({ planes, lo: h.lo, hi: h.hi, mats, visible, isSky, ent: entClass || 'worldspawn', target: entKv.targetname || '' });
          }
        }
      }
      if (depth === 2) brushText = null;
      depth--;
      continue;
    }
    if (depth === 1) {
      const m = /^"([^"]+)"\s+"([^"]*)"/.exec(line);
      if (m) { entKv[m[1]] = m[2]; if (m[1] === 'classname') entClass = m[2]; }
    } else if (depth === 2 && brushText) {
      brushText.push(line);
    }
  }
  // THE SKY SEAL: the box the six sky slabs enclose (the camera must stay inside it)
  const skies = brushes.filter(b => b.isSky);
  if (skies.length) {
    const lo = [0, 1, 2].map(i => Math.min(...skies.map(b => b.lo[i])));
    const hi = [0, 1, 2].map(i => Math.max(...skies.map(b => b.hi[i])));
    // interior = between the slabs: each slab is thin on one axis; the interior bound on an axis is the inner face
    const inner = [[-Infinity, Infinity], [-Infinity, Infinity], [-Infinity, Infinity]];
    for (const b of skies) {
      const ext = [0, 1, 2].map(i => b.hi[i] - b.lo[i]);
      const thin = ext.indexOf(Math.min(...ext));
      const mid = (b.lo[thin] + b.hi[thin]) / 2, centre = (lo[thin] + hi[thin]) / 2;
      if (mid < centre) inner[thin][0] = Math.max(inner[thin][0], b.hi[thin]);
      else inner[thin][1] = Math.min(inner[thin][1], b.lo[thin]);
    }
    sky = { outer: { lo, hi }, inner: inner.map(([a, b]) => [a, b]) };
  }
  const vis = brushes.filter(b => b.visible && !b.isSky);
  // spatial grid (CELL^3 buckets by bounding box)
  const CELL = 1024;
  const grid = new Map();
  const key = (i, j, k) => i + ',' + j + ',' + k;
  vis.forEach((b, idx) => {
    for (let i = Math.floor(b.lo[0] / CELL); i <= Math.floor(b.hi[0] / CELL); i++)
      for (let j = Math.floor(b.lo[1] / CELL); j <= Math.floor(b.hi[1] / CELL); j++)
        for (let k = Math.floor(b.lo[2] / CELL); k <= Math.floor(b.hi[2] / CELL); k++) {
          const kk = key(i, j, k);
          if (!grid.has(kk)) grid.set(kk, []);
          grid.get(kk).push(idx);
        }
  });
  function brushDist(b, p) {
    let m = -Infinity;
    for (const pl of b.planes) {
      const d = pl.n[0] * p[0] + pl.n[1] * p[1] + pl.n[2] * p[2] - pl.d;
      if (d > m) m = d;
    }
    return m;
  }
  // nearest visible brush within maxR (returns d = maxR when nothing is closer); `ignore(b)` skips a brush
  function distance(p, maxR = 512, ignore = null) {
    let best = maxR, who = null;
    const r = Math.ceil(maxR / CELL);
    const ci = Math.floor(p[0] / CELL), cj = Math.floor(p[1] / CELL), ck = Math.floor(p[2] / CELL);
    const seen = new Set();
    for (let i = ci - r; i <= ci + r; i++)
      for (let j = cj - r; j <= cj + r; j++)
        for (let k = ck - r; k <= ck + r; k++) {
          const list = grid.get(key(i, j, k));
          if (!list) continue;
          for (const idx of list) {
            if (seen.has(idx)) continue;
            seen.add(idx);
            const b = vis[idx];
            // cheap reject: the box distance is a lower bound too
            const bx = Math.max(b.lo[0] - p[0], 0, p[0] - b.hi[0]);
            const by = Math.max(b.lo[1] - p[1], 0, p[1] - b.hi[1]);
            const bz = Math.max(b.lo[2] - p[2], 0, p[2] - b.hi[2]);
            if (Math.hypot(bx, by, bz) >= best) continue;
            if (ignore && ignore(b)) continue;
            const d = brushDist(b, p);
            if (d < best) { best = d; who = b; }
          }
        }
    return { d: best, brush: who };
  }
  function insideSky(p, margin = 0) {
    if (!sky) return true;
    return [0, 1, 2].every(i => p[i] > sky.inner[i][0] + margin && p[i] < sky.inner[i][1] - margin);
  }
  return { brushes, visible: vis, distance, insideSky, sky, file };
}

module.exports = { loadMap, TOOL, TOOL_ENT };

if (require.main === module) {
  const M = loadMap();
  console.log('brushes', M.brushes.length, 'visible', M.visible.length, 'sky inner', JSON.stringify(M.sky && M.sky.inner));
  for (const p of [[0, 8608, 19500], [0, 8608, 24000], [0, 9112, 24200], [9840, 0, 60]]) {
    const r = M.distance(p, 2000);
    console.log('distance', p.join(','), '=', r.d.toFixed(1), r.brush ? r.brush.mats[0] + ' ' + r.brush.ent : '');
  }
}
