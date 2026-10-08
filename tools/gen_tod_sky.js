#!/usr/bin/env node
// tools/gen_tod_sky.js — THE CYBERCITY SKY (v17.71 → v17.87, 2026-09-05; v19.19 SMOOTH SOLIDS, 2026-09-16)
//
// Renders the map's own sky: a synthwave neon-grid metropolis on an
// EQUIRECTANGULAR lat-long panorama, the exact format every BO3 sky uses
// (materialType "sky_latlong_hdr", 8192x4096, one image on the stock T6 dome
// mesh — see docs/104_cybercity_sky.md for the proof chain).
//
// WHY PROCEDURAL AND NOT COMMISSIONED ART: a lat-long sky wraps at its left
// and right edge with clampU/clampV = 1, so the seam is whatever is baked in.
// Treyarch's shipped Miami sky matches column 0 to column 8191 within 0.06 of
// 65535; an image generator cannot promise that, and a mismatched seam draws a
// vertical line from horizon to zenith that a player on a spiral stair spins
// past every lap. Here EVERY value is a function of (azimuth, elevation) and
// the city is placed in world space and ray-cast per column, so the seam is
// exact BY CONSTRUCTION — az = (x + 0.5) / W * 2pi is periodic in W.
//
// THE PICTURE (display-referred, what the player should SEE):
//   SKY   a vertical gradient (theme), nebula with FILAMENTS and DUST LANES,
//         a milky-way band, a coloured star field with glints, THE MOON
//         (cratered, limb-darkened, haloed), planets with an atmosphere limb,
//         two black holes of DIFFERENT designs that LENS the stars behind them,
//         an aurora opposite the moon, three laser bars, and TWO CLOUD DECKS
//         on real planes above the eye (foreshortened toward the horizon, lit
//         from below by the city, silvered by the moon) that pass in front of
//         everything above.
//   CITY  ~2000 wireframe blocks on a street lattice out to 12k, then a FAR
//         RING of megastructures (13k..30k: mega-towers, arcologies, twin
//         towers with sky-bridges, megablocks) — all ray-cast per column with
//         real perspective; setback tiers, antennas of four kinds, glyph
//         billboards, holographic panels floating over the roofs, elevated
//         RING HIGHWAYS on pylons, searchlight beams, ground reflections,
//         street traffic and high air-lane traffic, three landmarks.
//   BELOW a Tron grid plane receding into the horizon haze.
//   then a bloom pass over everything emissive.
//
// DEPTH (v17.87, user: "everything is at the same layer ... ours looks
// cartoony and backgroundy rather than atmospheric"). A lat-long sky has no
// parallax, so depth has to be PAINTED: atmospheric perspective. Every drawn
// thing carries its distance d and two curves of it —
//   fog(d)      = exp(-d / HAZE_D)   surface CONTRAST: fills converge on the sky
//                                    colour behind them, neon edges pale toward
//                                    the haze, the face grid dissolves by ~8k
//   lightFog(d) = exp(-d / LIGHT_D)  point LIGHTS carry farther than surfaces:
//                                    hazed towers keep sparse twinkling windows
// plus a LIGHT-POLLUTION DOME at the horizon whose strength follows the real
// skyline density per bearing (GLOW_AZ, accumulated from the geometry), so far
// silhouettes stand against a lit smog band instead of a flat gradient. Two
// composition LANES (toward the moon, toward the low ringed giant) cap building
// heights so the bodies rise BEHIND the skyline rather than sitting on it.
// The body clearance against the skyline is printed on every run — read it.
//
// EXPOSURE — SKY_GAIN, AND THE SKY IS A LIGHT SOURCE (v17.74, docs/104 §4).
// The material displays the file through skyScaleRGB 1097.5 (pack-constant)
// AND bakes it into the world as ambient light through skyStops 10.0 (cloned
// from Miami, whose file is near-black). The pack keeps image mean × 2^skyStops
// ≈ 1.3; gain 0.06 scored ~4.0 and lit every wall olive-yellow while blowing
// the sky white. The STATS line printed at the end is that score — v17.82
// shipped at 0.478 with an R/G/B share of 22/27/51 AT FULL SIZE (a 2048
// preview reads ~1.7x higher: line weight does not scale with W, so compare
// like with like), and a picture change must hold it (move SKY_GAIN, not the
// picture) or the world's lighting moves too.
//
// QUALITY (v18.87, 2026-09-13 — learned from Tower II's hellscape sky v0.5-v0.7, docs/104 §4g):
//   * the sky is PAINTED at 2x the shipped size (--ss 2: 16384x8192) and resolved to
//     8192x4096 with a wrap-aware Lanczos-2 — true anti-aliasing on every neon edge,
//     rail, trail and star instead of the painter's one-axis coverage estimates;
//   * the noise tables are read with Catmull-Rom (no linear facets in the gradients);
//   * three clamped unsharp passes run AFTER the resolve at the shipped size, tuned on
//     the simulated in-game view (night_ingame_*.png: 1080p at cg_fov 65, bilinear);
//   * the EXR is written DIRECTLY as half floats by our own ZIP16 writer — the old
//     12-bit LUT -> 16-bit PNG -> ffmpeg chain quantised the dark sky to a few hundred
//     steps and banded the gradients; half keeps ~11 bits at every level;
//   * SKY_GAIN is SOLVED so the sky-light score lands on --target-score (0.478, the
//     v17.82 figure) instead of being hand-held — a picture change can no longer move
//     the world's lighting by accident. --gain still overrides.
//   Every feature COUNT and detail GATE keys on the SHIPPED pixel (PXO / OW), every
//   radius and line weight on the RENDER pixel (PX / LW = final weight x SS), so --ss
//   changes how cleanly the picture is resolved, never what is in it, and the 2048
//   preview now draws the SAME buildings as the 8192 ship (the old size gate was on W).
//
// ATMOSPHERE (v18.87, user: "make it even more atmospheric"): every surface is seen
// THROUGH three layers of air that each carry their own light —
//   GROUND MIST   a lit fog bank on the city plane (0..MIST_TOP), patchy in world XY,
//                 carrying the glow dome's colour per bearing: the feet of the towers
//                 and the far grid dissolve into lit haze, the reflections drown in it;
//   HAZE STRATA   two thin horizontal layers hanging BETWEEN the towers (z 560 / 1180)
//                 that a ray crosses on its way to a surface behind them — the towers
//                 read sliced by drifting bands of smog, the strongest depth cue there is;
//   MOON SHAFTS   crepuscular rays from the moon through the gaps of the low cloud deck;
//   THE STORM     one cell in the low deck far from the moon, lit from inside, with a
//                 single hazed bolt down to the far ring;
//   AIRSHIPS      two dirigibles over the mid city, dark hulls with a neon rim and a
//                 holo billboard on the flank, depth-tested against the towers.
//   All of it is a function of (azimuth, elevation) or world XY, so the seam is untouched.
//
// DEPTH (v19.69, 2026-10-02, docs/169; user: "enhancements in the skybox in terms of depth and atmosphere") —
//   CLOUD CEILING  the two cloud decks were painted only BEHIND the city, so a tower taller than the low deck stood
//                  crisp in front of the cloud it should vanish into; every surface above a deck is now seen through
//                  that deck's own coverage at the ray's crossing (cloudCeil): towers rise into the overcast.
//   UNDERGLOW      each downtown cluster lights the cloud base above it (underglowAt) — the overcast carries the
//                  shape of the city under it instead of one tint per bearing.
//   BEAM HITS      a searchlight whose foot is under the low deck stops in a lit patch on the cloud base where the
//                  deck is thick; a lamp that stands INSIDE the deck is dimmed by it and glows in it.
//   SMOKE PLUMES   six thin vent plumes off mid-height roofs, leaning down-wind, lit at the foot by the roof's neon.
//   Each has its own TOD_SKY_SKIP key (ceiling / underglow / beamhits / plumes); all four skipped reproduces the
//   v19.68 previews pixel-for-pixel (proven 2026-10-02: 0 of 42 preview images differ). TOD_SKY_PLUMEDBG=1 prints
//   every plume / beam decision while rendering.
//
// USAGE
//   node tools/gen_tod_sky.js [--theme night|sunset]   full 8192x4096 -> EXR + previews (~minutes)
//   node tools/gen_tod_sky.js --width 2048 --preview-only  quick look, no EXR
//   --ss N        supersample factor (default 2; --ss 1 = the v17.87 paint path)
//   --sharpen "3:0.38,3:0.45,5:0.25"  unsharp passes as radius:amount; none = off
//   --target-score 0.478   the sky-light score to solve SKY_GAIN for; --gain G pins it instead
//   --no-judge    skip the 16-bit judging PNG in %TEMP%\tod_sky
//   node tools/gen_tod_sky.js --gdt              (re)write source_data/tod_skybox.gdt
//   node tools/gen_tod_sky.js --tint 1,0.2,0.2   tint the sky (= the sky LIGHT) in linear light, mean held (§4b)
//   TOD_SKY_PREVIEW_DIR=<dir>  write the previews somewhere other than docs/sky_preview
//   TOD_SKY_SKIP=rings,beams,holo,air,far,mist,strata,shafts,storm,ships,tether,round,crown,slope,
//                ceiling,underglow,beamhits,plumes   bisect aid (and the v19.69 depth pass's per-feature revert)
// OUTPUTS
//   source_data/tod_skybox/_images/i_skybox_tod_cybercity.exr   THE ASSET (half, zip16)
//   docs/sky_preview/<theme>_sky_equirect.png + <theme>_view_*.png + <theme>_ingame_*.png
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { execFileSync } = require('child_process');

const REPO = path.resolve(__dirname, '..');
// PERF NOTE (v18.87, from Tower II's v0.5): every top-level stage is an IIFE `(() => { ... })();`, NOT a bare block. A
// script's top-level function that outgrows V8's optimised-bytecode limit (~60 KB) is never optimised, and EVERY top-level
// loop then runs 2-30x slow. Keep new stages inside functions.
const args = process.argv.slice(2);
const argv = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const has = k => args.includes(k);

// ---------------------------------------------------------------- knobs
const OW = parseInt(argv('--width', '8192'), 10);       // the SHIPPED width
// v18.88 (user: "I don't mind the size tradeoff"): widths ABOVE 8192 are "8192 with a bigger supersample that is never
// resolved away" — the approved 8192 picture at 2x the pixels. OW_BASE is the approved size the counts, gates and the
// final line weight are defined for; HI = OW / OW_BASE multiplies every drawn measure exactly, and the default --ss
// drops to 1 there so the paint stays at 16384 wide (the 2x paint of a 16384 ship would be 537 M px: 8.6 GB of floats).
const OW_BASE = Math.min(OW, 8192), HI = OW / OW_BASE;
// ⚠️ PROVEN 2026-09-13: a 16384x8192 EXR is REFUSED by the mod tools' image converter — linker "(image ...exr)
// unsupported size." then "image 'i_skybox_tod_cybercity' is missing" (the ONLY 16384-wide image in the install is a
// 16384x64 caustic strip, so the cap is on the 8192-per-axis product/height, not "no 16k at all"). The build FAILED
// and the deployed .ff had no sky until an 8192 re-render. 8192x4096 is this pipeline's ceiling; the >8192 path
// below is kept for the record and refused here unless --i-know-16k-fails is passed for a converter re-test.
if (OW > 8192 && !has('--i-know-16k-fails')) throw new Error(`--width ${OW}: the BO3 image converter refuses skies wider than 8192 ("unsupported size", proven 2026-09-13, docs/104 §4g). Ship 8192.`);
const RS = parseFloat(argv('--ss', OW > 8192 ? '1' : '2'));   // the RESOLVE ratio: painted at OW*RS, Lanczos-resolved to OW before sharpen/bloom
const SS = RS * HI;                                      // the DRAWING scale: every render-pixel measure = the approved 8192 measure x SS
const W = Math.round(OW * RS);                           // RENDER size while painting (the tail after the resolve uses FW/FH)
const H = W / 2;
const FULL = OW >= 8192;
const PXO = OW_BASE / 8192;                              // APPROVED pixel scale: feature COUNTS and detail GATES (content does not change with --ss or --width above 8192)
const PX = W / 8192;                                     // RENDER pixel scale: radii, lengths drawn in render pixels
const LW = (1.0 + 0.9 * PXO) * SS;                       // line weight in RENDER px = the approved final weight (~1.9 px at 8192, v17.73) x SS
const GAIN_ARG = argv('--gain', null);                   // v18.87: SKY_GAIN is SOLVED for --target-score at the end (§4c) unless --gain pins it
const TARGET_SCORE = parseFloat(argv('--target-score', '0.324'));   // v18.97: the score the v18.96 gain (0.01661) lands at once the peak knee removes the glare (28% of the mean WAS glare); v18.96: 0.45; v17.82: 0.478 at FULL size (mean linear x 2^skyStops 10); v17.87 held it by hand at gain 0.024
let SKY_GAIN = GAIN_ARG !== null ? parseFloat(GAIN_ARG) : 0.024;   // the v17.87 value until the solve replaces it
const SEED = parseInt(argv('--seed', '7'), 10);
const THEME = argv('--theme', 'night');
const THEMES = {
  night: {
    // v17.82 (user: "deepen the contrast, lower all this glowing"): every sky/haze level ~30% down
    // v18.87 (user: "a deeper dark more detailed sky"): zenith/high/mid another ~15% down; the gain solve holds the world light, so the lights gain contrast
    // v18.96 (user: "a tiny bit darker, enhance the contrast"): every sky level another ~18% down and the light target 0.478 -> 0.45,
    // so the base goes darker while the solved gain lifts the neon against it
    zen: [0.0025, 0.0025, 0.014], high: [0.009, 0.011, 0.051], mid: [0.025, 0.021, 0.108],
    low: [0.057, 0.037, 0.176], horSun: [0.123, 0.082, 0.254], horAway: [0.086, 0.049, 0.201],
    haze: [0.074, 0.049, 0.172], horBand: [0.02, 0.012, 0.04],   // v17.87: the glow dome carries the horizon now; the band is half
    sunEl: 16, sunR: 5.5, moon: true, sunTop: [0.92, 0.96, 1.00], sunMid: [0.80, 0.88, 1.00], sunBot: [0.62, 0.72, 0.98],
    bloomWide: 0.07, bloomWideR: 0.22, bloomTight: 0.22, bloomTightR: 0.04, bloomCol: [0.55, 0.72, 1.00],
    starThresh: 0.87, nebulaA: [0.05, 0.021, 0.11], nebulaB: [0.042, 0.093, 0.145], milky: 0.09, aurora: 1.15,   // v17.82: stars halved (was 0.60), aurora was 1.7
    hueWeights: [['cyan', 40], ['blue', 16], ['magenta', 20], ['violet', 12], ['orange', 4], ['gold', 4], ['red', 4]],
    // v17.87 DEPTH: light-pollution dome, two cloud decks, nebula structure
    glow: 0.22, glowWarm: [0.62, 0.24, 0.62], glowCool: [0.16, 0.52, 0.70],
    cloudDark: [0.040, 0.030, 0.080], cloudLit: [0.50, 0.22, 0.50], cloudMoon: [0.40, 0.48, 0.68], cirrus: [0.22, 0.26, 0.46],
    nebFil: 0.10, nebFilCol: [0.55, 0.30, 0.95], nebDust: 0.40,
    // v18.87 ATMOSPHERE: ground mist, haze strata, moon shafts, the storm cell, airships
    mist: 1.5, mistCol: [0.40, 0.30, 0.64], mistWarm: [0.78, 0.36, 0.62], mistCool: [0.28, 0.60, 0.78],
    strata: 1.0, strataCol: [0.34, 0.24, 0.56],
    shafts: 0.26, shaftCol: [0.62, 0.72, 1.00],
    storm: 1.0, stormCol: [0.80, 0.72, 1.00], ships: 1.0,
  },
  sunset: {
    zen: [0.030, 0.018, 0.100], high: [0.10, 0.04, 0.28], mid: [0.30, 0.09, 0.50],
    low: [0.62, 0.18, 0.55], horSun: [0.95, 0.42, 0.32], horAway: [0.62, 0.22, 0.52],
    haze: [0.55, 0.20, 0.46], horBand: [0.05, 0.02, 0.03],
    sunEl: 7, sunR: 12, moon: false, sunTop: [1.00, 0.96, 0.62], sunMid: [1.00, 0.62, 0.30], sunBot: [1.00, 0.20, 0.60],
    bloomWide: 0.18, bloomWideR: 0.22, bloomTight: 0.35, bloomTightR: 0.09, bloomCol: [1.00, 0.42, 0.30],
    starThresh: 0.70, nebulaA: [0.16, 0.05, 0.20], nebulaB: [0.0, 0.0, 0.0], milky: 0.0, aurora: 0.0,
    hueWeights: [['cyan', 40], ['magenta', 26], ['violet', 12], ['orange', 7], ['gold', 6], ['red', 5], ['green', 4]],
    glow: 0.18, glowWarm: [0.95, 0.45, 0.30], glowCool: [0.70, 0.25, 0.55],
    cloudDark: [0.16, 0.06, 0.20], cloudLit: [1.00, 0.50, 0.40], cloudMoon: [1.00, 0.75, 0.50], cirrus: [0.80, 0.45, 0.55],
    nebFil: 0.0, nebFilCol: [0, 0, 0], nebDust: 0.0,
    mist: 0.50, mistCol: [0.70, 0.32, 0.50], mistWarm: [0.95, 0.45, 0.30], mistCool: [0.70, 0.30, 0.55],
    strata: 0.40, strataCol: [0.60, 0.28, 0.45],
    shafts: 0.12, shaftCol: [1.00, 0.75, 0.45],
    storm: 0.0, stormCol: [1, 1, 1], ships: 1.0,
  },
};
const T = THEMES[THEME]; if (!T) throw new Error('unknown --theme ' + THEME);

const EYE = 220;            // eye height above the city plane (v17.72: was 900 — the skyline sat below eye level)
const SUN_AZ = Math.PI;     // sun/moon dead centre of the panorama
const SUN_EL = T.sunEl * Math.PI / 180;
const SUN_R = T.sunR * Math.PI / 180;
const CELL = 90;            // wireframe cell on faces
const FLOOR = 90;
const GRID = 220;           // ground grid pitch
const LOT = 420;            // street lattice pitch
const CITY_R = 12000;       // v17.87: the lattice stops here (was 15000) — beyond it the FAR RING
const FAR_R0 = 12500, FAR_R1 = 26000;   // the far ring of megastructures
const INNER_R = 1100;       // empty plaza around the eye
const HAZE_D = 7500;        // v17.87: surface-contrast e-fold (was FOG_D 12000 for everything — far towers kept 30% contrast = the flatness)
const LIGHT_D = 15000;      // point lights carry farther than surface contrast
const CLOUD_LOW_Z = 2600, CLOUD_HIGH_Z = 9000;   // the two cloud decks (world units above the city plane)
const TAU = Math.PI * 2;
const D2R = Math.PI / 180;
// v18.87 ATMOSPHERE — the air between the eye and every surface (see veil() below)
const MIST_TOP = 300;        // the ground mist bank: full density at the plane, gone by this height
const MIST_D = 900;         // v18.87 tuning: 5200 -> 3200 -> 1400 -> 900 before the bank read as a lit fog on the 2048 previews         // optical e-fold of a ray running inside the bank
const STRATA = [             // thin haze layers hanging between the towers: height, half-thickness, world-noise pitch, opacity
  { z: 560, hh: 110, pitch: 2600, k: 0.70, seed: 303 },
  { z: 1180, hh: 90, pitch: 3400, k: 0.50, seed: 404 },
];
const STORM_AZ_OFF = 2.55;   // the storm cell sits this far round from the moon (radians), in the low deck
const SHIP_DEFS = [          // dirigibles over the mid city: bearing from the moon, range, height, length
  { azOff: 2.35, d: 2100, z: 1560, len: 900, hue: 'magenta', adHue: 'cyan' },    // close overhead: ~24 deg long
  { azOff: -1.45, d: 5200, z: 3650, len: 1500, hue: 'cyan', adHue: 'gold' },     // mid distance, high: ~16 deg long
];

const HUE = {
  cyan: [0.25, 0.95, 1.00], magenta: [1.00, 0.28, 0.85], violet: [0.62, 0.35, 1.00], orange: [1.00, 0.55, 0.18],
  gold: [1.00, 0.85, 0.30], red: [1.00, 0.20, 0.22], blue: [0.30, 0.50, 1.00], green: [0.30, 1.00, 0.55],
};
const HAZE = T.haze;

// ---------------------------------------------------------------- helpers
let rngState = SEED >>> 0 || 1;
function rnd() { let x = rngState; x ^= x << 13; x >>>= 0; x ^= x >>> 17; x ^= x << 5; x >>>= 0; rngState = x; return x / 4294967296; }
function h2(i, j) { const x = Math.sin(i * 127.1 + j * 311.7 + 0.37) * 43758.5453; return x - Math.floor(x); }
// integer-mixed hash + value noise for the cloud planes (world coordinates, so seamless by construction)
function hq(i, j, s) { let h = (Math.imul(i | 0, 374761393) + Math.imul(j | 0, 668265263) + Math.imul(s | 0, 2246822519)) | 0; h = Math.imul(h ^ (h >>> 13), 1274126177); h ^= h >>> 16; return (h >>> 0) / 4294967296; }
function vnq(x, y, s) { const ix = Math.floor(x), iy = Math.floor(y), tx = smooth(x - ix), ty = smooth(y - iy); return lerp(lerp(hq(ix, iy, s), hq(ix + 1, iy, s), tx), lerp(hq(ix, iy + 1, s), hq(ix + 1, iy + 1, s), tx), ty); }
function fbm2(x, y, s, oct) { let sum = 0, amp = 1, norm = 0; for (let o = 0; o < oct; o++) { sum += vnq(x, y, s + o * 17) * amp; norm += amp; amp *= 0.5; x = x * 2.03 + 11.3; y = y * 2.03 + 7.1; } return sum / norm; }
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = t => t * t * (3 - 2 * t);
const mix3 = (A, B, t) => [lerp(A[0], B[0], t), lerp(A[1], B[1], t), lerp(A[2], B[2], t)];
const wrapAz = a => Math.atan2(Math.sin(a), Math.cos(a));
const fogOf = d => Math.exp(-d / HAZE_D);
const lightFogOf = d => Math.exp(-d / LIGHT_D);

const R = new Float32Array(W * H), G = new Float32Array(W * H), B = new Float32Array(W * H);
const Z = new Float32Array(W * H).fill(Infinity);   // depth of the nearest opaque surface per pixel (boxes write it; curve items test it)
const EW = W >> 2, EH = H >> 2;
const ER = new Float32Array(EW * EH), EG = new Float32Array(EW * EH), EB = new Float32Array(EW * EH);

const elOfRow = y => (0.5 - (y + 0.5) / H) * Math.PI;
const rowOfEl = el => (0.5 - el / Math.PI) * H - 0.5;
const azOfCol = x => (x + 0.5) / W * TAU;
function put(x, y, r, g, b) { const o = y * W + x; R[o] = r; G[o] = g; B[o] = b; }
function blend(x, y, r, g, b, a) { const o = y * W + x; R[o] = lerp(R[o], r, a); G[o] = lerp(G[o], g, a); B[o] = lerp(B[o], b, a); }
function addc(x, y, r, g, b, a) { const o = y * W + x; R[o] += r * a; G[o] += g * a; B[o] += b * a; }
function emit(x, y, r, g, b, k) {
  const ex = x >> 2, ey = y >> 2; if (ex < 0 || ex >= EW || ey < 0 || ey >= EH) return;
  const o = ey * EW + ex; ER[o] += r * k; EG[o] += g * k; EB[o] += b * k;
}
// an anti-aliased dot at a continuous pixel position (x wraps); additive or blended
function dotAA(px, py, rad, col, a, additive, depth) {
  for (let yy = Math.floor(py - rad - 1); yy <= Math.ceil(py + rad + 1); yy++) {
    if (yy < 0 || yy >= H) continue;
    for (let xx = Math.floor(px - rad - 1); xx <= Math.ceil(px + rad + 1); xx++) {
      const cov = clamp(rad + 0.5 - Math.hypot(xx + 0.5 - px, yy + 0.5 - py), 0, 1) * a; if (cov <= 0) continue;
      const x = ((xx % W) + W) % W;
      if (depth !== undefined && Z[yy * W + x] < depth) continue;
      if (additive) addc(x, yy, col[0], col[1], col[2], cov); else blend(x, yy, col[0], col[1], col[2], cov);
    }
  }
}

// periodic value noise at 1/8 res, read back bilinearly
const NW = W >> 3, NH = H >> 3;
const OCT_DEFAULT = [[6, 1.0], [12, 0.5], [24, 0.25], [48, 0.12], [96, 0.06]];
const OCT_FINE = [[8, 1.0], [16, 0.6], [32, 0.4], [64, 0.3], [128, 0.2], [256, 0.12]];
function makeNoise(seedK, stretch, octaves = OCT_DEFAULT) {
  const out = new Float32Array(NW * NH);
  for (let y = 0; y < NH; y++) {
    const v = y / NH;
    for (let x = 0; x < NW; x++) {
      const u = x / NW; let sum = 0, norm = 0;
      for (const [nx, amp] of octaves) {
        const fx = u * nx, fy = v * nx * stretch;
        const ix = Math.floor(fx), iy = Math.floor(fy), tx = smooth(fx - ix), ty = smooth(fy - iy);
        const a = h2(ix % nx + seedK, iy), b = h2((ix + 1) % nx + seedK, iy), c = h2(ix % nx + seedK, iy + 1), d = h2((ix + 1) % nx + seedK, iy + 1);
        sum += lerp(lerp(a, b, tx), lerp(c, d, tx), ty) * amp; norm += amp;
      }
      out[y * NW + x] = sum / norm;
    }
  }
  return out;
}
const OCT_GRAIN = [[24, 1.0], [48, 0.7], [96, 0.5], [192, 0.4], [384, 0.3], [768, 0.2]];   // v18.87: the fine nebula grain the 2x paint can carry
const NOISE_A = makeNoise(0, 5), NOISE_B = makeNoise(1000, 2.2), NOISE_C = makeNoise(2000, 1.6, OCT_FINE), NOISE_D = makeNoise(3000, 1.2, OCT_GRAIN);
// v18.87 QUALITY: Catmull-Rom in both axes (x wraps, y clamps). Bilinear on the 1/8-res tables left visible linear facets
// in the sky base, the nebula and the smog. NEVER scale the x argument — it breaks the period.
function cub(a, b, c, d, t) { return b + 0.5 * t * (c - a + t * (2 * a - 5 * b + 4 * c - d + t * (3 * (b - c) + d - a))); }
function noise(F, x, y) {
  const fx = ((x / 8) % NW + NW) % NW, fy = clamp(y / 8, 0, NH - 1.001);
  const ix = Math.floor(fx), iy = Math.floor(fy), tx = fx - ix, ty = fy - iy;
  const x0 = (ix + NW - 1) % NW, x2 = (ix + 1) % NW, x3 = (ix + 2) % NW;
  const y0 = Math.max(iy - 1, 0), y2 = Math.min(iy + 1, NH - 1), y3 = Math.min(iy + 2, NH - 1);
  const rowv = r => { const o = r * NW; return cub(F[o + x0], F[o + ix], F[o + x2], F[o + x3], tx); };
  return clamp(cub(rowv(y0), rowv(iy), rowv(y2), rowv(y3), ty), 0, 1);
}

// the sky gradient by elevation (el >= 0) and the moon-side weight
function skyGrad(el, sunSide) {
  const t = clamp(el / (Math.PI / 2), 0, 1);
  if (t > 0.5) return mix3(T.high, T.zen, smooth((t - 0.5) / 0.5));
  if (t > 0.22) return mix3(T.mid, T.high, smooth((t - 0.22) / 0.28));
  if (t > 0.08) return mix3(T.low, T.mid, smooth((t - 0.08) / 0.14));
  return mix3(mix3(T.horAway, T.horSun, sunSide), T.low, smooth(t / 0.08));
}
// THE LIGHT-POLLUTION DOME (v17.87): strength per bearing from the real skyline (GLOW_AZ, filled by the geometry pass),
// falling off with elevation like smog lit from below; warm/cool alternates around the horizon
const GLOW_BINS = 720;
const GLOW_RAW = new Float64Array(GLOW_BINS), GLOW_AZ = new Float32Array(GLOW_BINS).fill(1);
function glowAt(az) { const f = (((az / TAU) % 1) + 1) % 1 * GLOW_BINS; const i = Math.floor(f) % GLOW_BINS, t = f - Math.floor(f); return lerp(GLOW_AZ[i], GLOW_AZ[(i + 1) % GLOW_BINS], t); }
function glowDome(az, el) {
  const v = Math.exp(-Math.max(el, 0) / (8.5 * D2R)) * smooth(clamp((el + 2.5 * D2R) / (3.5 * D2R), 0, 1));
  if (v < 0.002) return null;
  const mixK = clamp(0.5 + 0.35 * Math.sin(az * 2 + 0.9) + 0.15 * Math.sin(az * 5 - 1.1), 0, 1);
  const col = mix3(T.glowCool, T.glowWarm, mixK);
  const a = T.glow * glowAt(az) * v;
  return [col[0] * a, col[1] * a, col[2] * a];
}
function skyBaseAt(az, el) {
  const c = skyGrad(el, 0.5 + 0.5 * Math.cos(wrapAz(az - SUN_AZ)));
  const gd = glowDome(az, el);
  return gd ? [c[0] + gd[0], c[1] + gd[1], c[2] + gd[2]] : c;
}
const SKIP = new Set((process.env.TOD_SKY_SKIP || '').split(','));   // bisect aid: see TOD_SKY_SKIP in the header for every key

// ---------------------------------------------------------------- v18.87 ATMOSPHERE: the air in front of every surface
// veil(az, t, z) = how much of a surface point at bearing az, range t, height z is hidden by the lit air between it and
// the eye, and by what colour. Two kinds of layer, each integrated along the ray from the eye (height EYE) to the point:
//   GROUND MIST   density 1 at the city plane falling to 0 at MIST_TOP, patchy in world XY (fbm2: seamless by
//                 construction). The ray's path inside the bank is the part of it below MIST_TOP; optical depth =
//                 that length / MIST_D x the bank density at the path's midpoint. The eye is INSIDE the bank (EYE <
//                 MIST_TOP), so a tower's feet and the far grid dissolve while its upper floors are clear.
//   HAZE STRATA   thin layers at STRATA[i].z; the ray crosses a layer once if the point is beyond it in height, and
//                 runs 2hh x t/|z-EYE| inside it — a layer seen edge-on is a solid band, seen steeply it is a wisp —
//                 weighted by the layer's patchiness at the crossing's world XY, fading with range like any surface.
// The colour is the glow dome's warm/cool per bearing (the mist is lit by the city under it), converging on the sky
// behind it with range. Returns [alpha, r, g, b] or null. Pass t = Infinity for a sky ray (direction (az, el)).
const MIST_CACHE = { az: NaN, col: null };
function airCol(az, t) {
  if (az !== MIST_CACHE.az) {
    const g = glowAt(az);
    const mixK = clamp(0.5 + 0.35 * Math.sin(az * 2 + 0.9) + 0.15 * Math.sin(az * 5 - 1.1), 0, 1);   // the dome's own warm/cool alternation
    const c = mix3(T.mistCool, T.mistWarm, mixK), k = 0.26 + 0.44 * g;
    MIST_CACHE.az = az; MIST_CACHE.col = [lerp(T.mistCol[0], c[0], 0.55) * k, lerp(T.mistCol[1], c[1], 0.55) * k, lerp(T.mistCol[2], c[2], 0.55) * k];
  }
  return MIST_CACHE.col;
}
// v19.69 THE CLOUD CEILING (docs/169; user 2026-10-02: "enhancements in the skybox in terms of depth and atmosphere").
// The two cloud decks were painted only BEHIND the city (the sky pass runs first and every tower is drawn over it), so
// a tower taller than the low deck stood crisp in front of the very cloud it should vanish into. A ray from the eye to
// a surface point ABOVE a deck crosses that deck's plane on the way; the deck's own coverage and colour at the
// crossing (the sky pass's formula, verbatim, so a cloud runs straight on across a tower's silhouette) now hide the
// point, deepening over CEIL_DEPTH above the cloud base - towers rise out of the mid city and disappear into the
// overcast, the far ring's megastructures stand in and out of drifting cloud. The high cirrus does the same, thinly,
// to the few giants that reach it. TOD_SKY_SKIP=ceiling restores the old picture exactly.
const CEIL_DEPTH = 650, CEIL_K = 0.92, CIRRUS_DEPTH = 1600, CIRRUS_K = 0.85;
// v19.69 THE UNDERLIT OVERCAST (docs/169): the low deck took the city's light per BEARING only (glowAt), so the cloud
// over a downtown was no brighter than the cloud over an empty quarter of the same bearing. Each downtown cluster now
// lights the cloud base right above it - a soft pool in a warm or cool neon, strongest over the densest district -
// so the overcast carries the shape of the city under it. Applied only where there IS cloud (it rides the cloud's own
// colour), in the sky pass and in the cloud ceiling alike. LOCKSTEP: these are the city IIFE's `clusters` /
// `farClusters` (az, range, radius, height multiplier) - asserted equal there. TOD_SKY_SKIP=underglow removes it.
const UG_NEAR = [[SUN_AZ + 2.2, 3800, 2400, 4.2], [SUN_AZ - 1.9, 5400, 3000, 5.0], [SUN_AZ + 0.9, 7200, 2800, 3.6],
                 [SUN_AZ - 0.6, 9000, 3400, 3.2], [SUN_AZ + 3.0, 8000, 2400, 3.8]];
const UG_FAR = [[SUN_AZ + 2.6, 19000, 5500, 1.7], [SUN_AZ - 1.3, 22000, 6500, 1.6]];
const UG_K = 0.30;                                                   // the pool's strength at its centre, x the cluster's multiplier share
const UG_COLS = [[1.00, 0.36, 0.78], [0.30, 0.85, 1.00], [1.00, 0.55, 0.30], [0.62, 0.40, 1.00], [0.30, 0.95, 0.85], [1.00, 0.40, 0.70], [0.45, 0.70, 1.00]];
const UG_SRC = [...UG_NEAR, ...UG_FAR].map(([a, d, rad, m], i) => ({ x: Math.cos(a) * d, y: Math.sin(a) * d, r: rad * 1.35, k: UG_K * (m - 1) / 4, col: UG_COLS[i % UG_COLS.length] }));
function underglowAt(X, Y) {
  if (SKIP.has('underglow')) return null;
  let r = 0, g = 0, b = 0;
  for (const s of UG_SRC) {
    const q = ((X - s.x) * (X - s.x) + (Y - s.y) * (Y - s.y)) / (s.r * s.r);
    if (q > 9) continue;
    const w = s.k * Math.exp(-q * 1.1);
    r += s.col[0] * w; g += s.col[1] * w; b += s.col[2] * w;
  }
  return (r + g + b) > 1e-4 ? [r, g, b] : null;
}
function cloudCeil(az, t, z, c, s) {
  if (SKIP.has('ceiling') || !(z > CLOUD_LOW_Z) || !(t > 1)) return null;
  const dz = z - EYE, el = Math.atan2(dz, t), cosEl = Math.max(0.02, Math.cos(el));
  const hf = smooth(clamp((el - 0.8 * D2R) / (3.2 * D2R), 0, 1));
  if (hf <= 0) return null;
  const daz = wrapAz(az - SUN_AZ), msd = Math.hypot(daz * cosEl, el - SUN_EL);
  const moonK = T.moon ? Math.exp(-msd * msd / (2 * 0.30 * 0.30)) : Math.exp(-msd * msd / (2 * 0.5 * 0.5));
  let a = 0, cr = 0, cg = 0, cb = 0;
  // the HIGH cirrus first (it is the farther crossing), the low deck composited over it
  if (z > CLOUD_HIGH_Z) {
    const tt = t * (CLOUD_HIGH_Z - EYE) / dz, X = c * tt, Y = s * tt;
    const dn = fbm2(X / 7000 + 9.1, Y / 1900 + 4.4, 202, 4);
    const cov = smooth(clamp((dn - 0.55) / 0.13, 0, 1)) * 0.42;
    if (cov > 0.002) {
      let cc = [T.cirrus[0] + T.cloudMoon[0] * moonK * 0.8, T.cirrus[1] + T.cloudMoon[1] * moonK * 0.8, T.cirrus[2] + T.cloudMoon[2] * moonK * 0.8];
      cc = mix3(cc, skyBaseAt(az, el), (1 - Math.exp(-tt / 30000)) * 0.8);
      a = cov * hf * smooth(clamp((z - CLOUD_HIGH_Z) / CIRRUS_DEPTH, 0, 1)) * CIRRUS_K;
      cr = cc[0]; cg = cc[1]; cb = cc[2];
    }
  }
  {
    const tt = t * (CLOUD_LOW_Z - EYE) / dz, X = c * tt, Y = s * tt;
    const dn = fbm2(X / 2300 + 3.7, Y / 2300 - 1.9, 101, 4);
    let sk = 0;
    if (T.storm > 0 && !SKIP.has('storm')) { const sd = Math.hypot(wrapAz(az - STORM_AZ) * cosEl, el - STORM_EL); sk = Math.exp(-sd * sd / (2 * 0.10 * 0.10)) * T.storm; }
    let cov = smooth(clamp((dn - 0.50) / 0.22, 0, 1));
    if (sk > 0.01) cov = Math.max(cov, smooth(clamp(sk * 1.4, 0, 1)) * (0.5 + 0.5 * smooth(clamp((dn - 0.30) / 0.30, 0, 1))));
    if (cov > 0.002) {
      const litK = clamp(glowAt(az) * (0.45 + 0.55 * Math.exp(-tt / 9000)), 0, 1);
      let cc = mix3(T.cloudDark, T.cloudLit, litK * (0.5 + 0.5 * cov));
      cc = [cc[0] + T.cloudMoon[0] * moonK * 0.9, cc[1] + T.cloudMoon[1] * moonK * 0.9, cc[2] + T.cloudMoon[2] * moonK * 0.9];
      cc = mix3(cc, skyBaseAt(az, el), (1 - Math.exp(-tt / 16000)) * 0.85);
      const ug = underglowAt(X, Y);
      if (ug) { const uk = Math.exp(-tt / 16000); cc = [cc[0] + ug[0] * uk, cc[1] + ug[1] * uk, cc[2] + ug[2] * uk]; }
      const la = cov * 0.80 * hf * smooth(clamp((z - CLOUD_LOW_Z) / CEIL_DEPTH, 0, 1)) * CEIL_K;
      if (la > 0.002) {
        const na = la + a * (1 - la);
        cr = (la * cc[0] + a * (1 - la) * cr) / na; cg = (la * cc[1] + a * (1 - la) * cg) / na; cb = (la * cc[2] + a * (1 - la) * cb) / na;
        a = na;
      }
    }
  }
  return a > 0.002 ? [a, cr, cg, cb] : null;
}
function veil(az, t, z, c, s) {
  const cl = cloudCeil(az, t, z, c, s);
  const vl = veilAir(az, t, z, c, s);
  if (!cl) return vl;
  if (!vl) return cl;
  // the mist and the strata hang NEARER the eye than the deck's crossing: they go over the cloud
  const a = vl[0], na = a + cl[0] * (1 - a);
  return [na, (a * vl[1] + cl[0] * (1 - a) * cl[1]) / na, (a * vl[2] + cl[0] * (1 - a) * cl[2]) / na, (a * vl[3] + cl[0] * (1 - a) * cl[3]) / na];
}
function veilAir(az, t, z, c, s) {
  const doMist = T.mist > 0 && !SKIP.has('mist'), doStrata = T.strata > 0 && !SKIP.has('strata');
  if (!doMist && !doStrata) return null;
  let a = 0, cr = 0, cg = 0, cb = 0;
  const dz = z - EYE;
  if (doMist) {
    // the path inside the bank: all of it if the point is below MIST_TOP, else up to where the ray climbs out
    const L = dz > MIST_TOP - EYE ? t * (MIST_TOP - EYE) / dz : t;
    if (L > 1) {
      const um = L / 2, hm = EYE + dz * um / t;
      const Xm = c * um, Ym = s * um;
      const n = fbm2(Xm / 1700 + 0.7, Ym / 1700 - 2.3, 505, 3);
      const patch = 0.30 + 1.45 * smooth(clamp((n - 0.36) / 0.30, 0, 1));
      const dens = clamp(1 - hm / MIST_TOP, 0, 1);
      const tau = L / MIST_D * dens * patch * T.mist;
      const ma = 1 - Math.exp(-tau);
      if (ma > 0.002) {
        const mc = airCol(az, t);
        const sb = skyBaseAt(az, 0);
        const far = 1 - Math.exp(-um / 9000);                   // a far bank converges on the horizon sky
        a = ma; cr = lerp(mc[0], sb[0] * 1.1, far); cg = lerp(mc[1], sb[1] * 1.1, far); cb = lerp(mc[2], sb[2] * 1.1, far);
      }
    }
  }
  if (doStrata && dz > 0) {
    for (const ly of STRATA) {
      const dl = ly.z - EYE; if (dl <= 0) continue;
      let tL, run;
      if (dz > dl + ly.hh) { tL = t * dl / dz; run = Math.min(2 * ly.hh * t / dz, 9000); }                 // crosses the whole layer
      else if (dz > dl - ly.hh) { tL = t * dl / dz; run = Math.min((dz - (dl - ly.hh)) * t / dz, 9000) * 0.5; }   // the point sits inside it
      else continue;
      if (!(tL > 1)) continue;
      const XL = c * tL, YL = s * tL;
      const n = fbm2(XL / ly.pitch + ly.seed * 0.37, YL / ly.pitch - ly.seed * 0.11, ly.seed, 3);
      const dens = smooth(clamp((n - 0.44) / 0.22, 0, 1));
      if (dens <= 0.002) continue;
      const la = (1 - Math.exp(-run / 500)) * dens * ly.k * T.strata * Math.exp(-tL / 16000);
      if (la <= 0.002) continue;
      const g = glowAt(az), sb = skyBaseAt(az, Math.atan(dl / tL));
      const hz = 1 - Math.exp(-tL / HAZE_D);
      const lc = [lerp(T.strataCol[0] * (0.45 + 0.55 * g), sb[0] * 1.25, hz), lerp(T.strataCol[1] * (0.45 + 0.55 * g), sb[1] * 1.25, hz), lerp(T.strataCol[2] * (0.45 + 0.55 * g), sb[2] * 1.25, hz)];
      // composite this layer OVER what is already veiled (the strata are nearer than the mist's far reach)
      const na = a + la - a * la;
      cr = (a * (1 - la) * cr + la * lc[0]) / Math.max(na, 1e-6);
      cg = (a * (1 - la) * cg + la * lc[1]) / Math.max(na, 1e-6);
      cb = (a * (1 - la) * cb + la * lc[2]) / Math.max(na, 1e-6);
      a = na;
    }
  }
  return a > 0.002 ? [a, cr, cg, cb] : null;
}
// the strata seen against the SKY (a ray at elevation el crosses every layer above the eye once; the mist is the ground's)
function skyStrata(az, el, c, s) {
  if (!(T.strata > 0) || SKIP.has('strata') || el <= 0.25 * D2R) return null;
  const tn = Math.tan(el);
  let a = 0, cr = 0, cg = 0, cb = 0;
  for (const ly of STRATA) {
    const dl = ly.z - EYE; if (dl <= 0) continue;
    const tL = dl / tn, run = Math.min(2 * ly.hh / tn, 9000);
    const XL = c * tL, YL = s * tL;
    const n = fbm2(XL / ly.pitch + ly.seed * 0.37, YL / ly.pitch - ly.seed * 0.11, ly.seed, 3);
    const dens = smooth(clamp((n - 0.44) / 0.22, 0, 1));
    if (dens <= 0.002) continue;
    const la = (1 - Math.exp(-run / 500)) * dens * ly.k * T.strata * Math.exp(-tL / 16000);
    if (la <= 0.002) continue;
    const g = glowAt(az), sb = skyBaseAt(az, el), hz = 1 - Math.exp(-tL / HAZE_D);
    const lc = [lerp(T.strataCol[0] * (0.45 + 0.55 * g), sb[0] * 1.25, hz), lerp(T.strataCol[1] * (0.45 + 0.55 * g), sb[1] * 1.25, hz), lerp(T.strataCol[2] * (0.45 + 0.55 * g), sb[2] * 1.25, hz)];
    const na = a + la - a * la;
    cr = (a * (1 - la) * cr + la * lc[0]) / Math.max(na, 1e-6); cg = (a * (1 - la) * cg + la * lc[1]) / Math.max(na, 1e-6); cb = (a * (1 - la) * cb + la * lc[2]) / Math.max(na, 1e-6);
    a = na;
  }
  return a > 0.002 ? [a, cr, cg, cb] : null;
}

// LASER BARS: [azimuth, half-span, elevation, colour, half-width px]
const LASERS = [
  [SUN_AZ + 1.9, 0.75, 14 * D2R, HUE.cyan, (1.4 * PXO + 0.6) * SS],
  [SUN_AZ - 2.3, 0.55, 19 * D2R, HUE.magenta, (1.2 * PXO + 0.6) * SS],
  [SUN_AZ + 0.35, 0.40, 23 * D2R, HUE.violet, (1.0 * PXO + 0.6) * SS],
];
// milky way: a great circle tilted 62 deg from the zenith, crossing the sky away from the moon
const MW_N = (() => { const tilt = 62 * D2R, a = SUN_AZ + 1.0; return [Math.sin(tilt) * Math.cos(a), Math.sin(tilt) * Math.sin(a), Math.cos(tilt)]; })();
const AUR_AZ = SUN_AZ + Math.PI;

// COMPOSITION LANES (v17.87): building heights are capped under these bearings so a body RISES BEHIND
// the skyline instead of being pasted over it. maxEl = the skyline's ceiling in that lane (degrees).
const GIANT_AZ = SUN_AZ + 1.15;
const LANES = [
  { name: 'moon', az: SUN_AZ, half: 0.42, maxEl: 10 },
  { name: 'giant', az: GIANT_AZ, half: 0.32, maxEl: 8.5 },
  { name: 'storm', az: SUN_AZ + STORM_AZ_OFF, half: 0.30, maxEl: 7 },   // v18.87: the storm cell and its bolt show over a low skyline
  { name: 'rust', az: SUN_AZ + 0.55, half: 0.12, maxEl: 32 },            // v18.87: the far ring re-rolled and put a mega-tower top across the rust planet's lower limb
];
function laneCap(cx, cy, halfDiag) {
  const az = Math.atan2(cy, cx), d = Math.max(1, Math.hypot(cx, cy) - halfDiag);
  const reach = Math.atan2(halfDiag, d);                                     // v18.87: a box is in a lane if any of its EXTENT is, not only its centre — a 5,000-long megablock centred outside the rust lane still put its roof across the planet
  let cap = Infinity;
  for (const ln of LANES) if (Math.abs(wrapAz(az - ln.az)) < ln.half + reach) cap = Math.min(cap, EYE + d * Math.tan(ln.maxEl * D2R));
  return cap;
}
const inLane = (az, pad) => LANES.some(ln => Math.abs(wrapAz(az - ln.az)) < ln.half + (pad || 0));
// v18.87: THE ORBITAL TETHER — a cable from an anchor mega-tower in the far ring up to the zenith, a station on it
const TETHER = { az: SUN_AZ - 1.62, d: 19000, anchorH: 8200, stationEl: 47 * D2R, col: [0.35, 0.90, 1.00] };

// ---------------------------------------------------------------- 1b. PLANETS + BLACK HOLES (v17.82, redesigned v17.87)
// user 2026-09-05 (v17.82): "less stars in the sky with some planets and blackholes here and there";
// user 2026-09-05 (v17.87): "blackholes look like they are just cropped in rather than be part of the sky ...
// like stickers we just copied and placed". So: the GIANT sits LOW (el 12.5) and rises behind the far
// skyline through the horizon haze with a moonlet above it; every planet has an atmosphere limb and a
// scatter halo; the two holes are DIFFERENT DESIGNS — 'edge' (Gargantua: thin near-edge-on disc, lensed
// arch, warm) and 'face' (the Maelstrom: inclined spiral vortex, blue-white photon ring, POLAR JETS,
// violet) — both LENS the stars and nebula behind them (Einstein radius `lens`, in disc units) and both
// trail a gas halo out to 7 radii that fades into the nebula. The clouds pass in front of all of them.
// Bodies live in disc space (sdx, sdy) = angular offset / radius, x scaled by cos(el) so a disc is
// round on the sphere; every body is placed by azimuth relative to the moon (SUN_AZ), so the wrap seam
// is untouched. Planets emit NOTHING into the bloom but their limb.
const BODIES = (THEME !== 'night' ? [] : [
  { kind: 'planet', name: 'giant',   az: GIANT_AZ,        el: 12.5, r: 5.2, colA: [0.80, 0.56, 0.34], colB: [0.96, 0.84, 0.62], spot: [0.92, 0.36, 0.22], bands: 16, ring: { inner: 1.40, outer: 2.35, tilt: 0.26, col: [0.78, 0.70, 0.56] }, light: [0.70, 0.35, 0.55], atmo: [1.00, 0.80, 0.55] },
  { kind: 'planet', name: 'moonlet', az: GIANT_AZ - 0.16, el: 25.5, r: 0.55, colA: [0.55, 0.52, 0.50], colB: [0.80, 0.78, 0.74], bands: 0, light: [0.70, 0.35, 0.55], atmo: null },
  { kind: 'planet', name: 'rust',    az: SUN_AZ + 0.55,   el: 36,   r: 2.0, colA: [0.78, 0.34, 0.20], colB: [0.92, 0.52, 0.30], bands: 0, light: [-0.85, 0.20, 0.35], atmo: [1.00, 0.55, 0.35] },
  { kind: 'planet', name: 'ice',     az: SUN_AZ - 2.40,   el: 63,   r: 1.5, colA: [0.50, 0.76, 0.94], colB: [0.80, 0.92, 1.00], bands: 6, light: [0.90, 0.15, 0.30], atmo: [0.60, 0.85, 1.00] },
  { kind: 'hole',   name: 'gargantua', variant: 'edge', az: SUN_AZ + 1.30, el: 60, r: 5.0, tilt: 0.16, discOut: 3.4, lens: 1.35 },
  { kind: 'hole',   name: 'maelstrom', variant: 'face', az: SUN_AZ - 0.85, el: 61, r: 2.6, tilt: 0.55, discOut: 3.2, lens: 1.50 },
]).map(bd => {
  const r = bd.r * D2R, pxR = r * W / TAU;
  const L = bd.light ? (() => { const n = Math.hypot(bd.light[0], bd.light[1], bd.light[2]); return bd.light.map(v => v / n); })() : null;
  const reach = bd.kind === 'hole' ? 7.0 : (bd.ring ? bd.ring.outer + 0.45 : 1.45);
  return { ...bd, elR: bd.el * D2R, r, pxR, cosEl: Math.cos(bd.el * D2R), L, reach, edge: Math.max(0.02, 1.5 / pxR) };
});
const HOLES = BODIES.filter(b => b.kind === 'hole');
function shadePlanet(bd, sdx, sdy, sdd, r, g, b, x, y) {
  const L = bd.L;
  let ringCov = 0, ringCol = null;
  if (bd.ring) {
    const rr = Math.hypot(sdx, sdy / bd.ring.tilt);
    if (rr > bd.ring.inner - 0.05 && rr < bd.ring.outer + 0.05) {
      const win = smooth(clamp((rr - bd.ring.inner) / 0.12, 0, 1)) * (1 - smooth(clamp((rr - bd.ring.outer + 0.15) / 0.15, 0, 1)));
      const grain = 0.45 + 0.55 * noise(NOISE_B, rr * 900, 17);
      const gap = 1 - 0.85 * Math.exp(-Math.pow((rr - 1.98) / 0.04, 2));
      const lit = 0.45 + 0.55 * clamp(0.5 + 0.8 * (sdx * L[0] + sdy * L[1]), 0, 1);
      ringCov = win * grain * gap * 0.85;
      ringCol = [bd.ring.col[0] * lit, bd.ring.col[1] * lit, bd.ring.col[2] * lit];
    }
  }
  const behind = ringCov > 0 && sdy > 0;                       // upper half of the ellipse = the far side
  if (behind && sdd >= 1) { r = lerp(r, ringCol[0], ringCov); g = lerp(g, ringCol[1], ringCov); b = lerp(b, ringCol[2], ringCov); }
  if (sdd < 1 + bd.edge) {
    const nz = Math.sqrt(Math.max(0, 1 - sdd * sdd));
    const diff = clamp(sdx * L[0] + sdy * L[1] + nz * L[2], 0, 1);
    const shade = 0.05 + 0.95 * Math.pow(smooth(clamp(diff * 1.35, 0, 1)), 0.85);
    const lat = sdy * 0.95 + nz * 0.30;
    let col;
    if (bd.bands > 0) {
      const bv = 0.5 + 0.5 * Math.sin(lat * bd.bands + 2.2 * noise(NOISE_A, lat * 700 + 300, 9 + bd.r * 1000) + noise(NOISE_B, sdx * 120 + lat * 500, 5) * 1.5);
      col = mix3(bd.colA, bd.colB, bv);
      if (bd.spot) { const sd = Math.hypot(sdx - 0.35, (lat + 0.22) * 1.8); if (sd < 0.20) col = mix3(col, bd.spot, smooth(clamp((0.20 - sd) / 0.05, 0, 1))); }
    } else {
      const tv = noise(NOISE_A, sdx * 400 + 900, sdy * 400 + 200) * 0.7 + noise(NOISE_B, sdx * 900, sdy * 900 + 800) * 0.3;
      col = mix3(bd.colA, bd.colB, clamp((tv - 0.35) * 2.2, 0, 1));
    }
    const k = shade * (1 - 0.40 * sdd * sdd);
    const edge = clamp((1 - sdd) / bd.edge, 0, 1);
    r = lerp(r, col[0] * k, edge); g = lerp(g, col[1] * k, edge); b = lerp(b, col[2] * k, edge);
  }
  if (ringCov > 0 && !behind) { r = lerp(r, ringCol[0], ringCov); g = lerp(g, ringCol[1], ringCov); b = lerp(b, ringCol[2], ringCov); }
  if (bd.atmo && sdd > 0.96) {
    // v17.87: an atmosphere limb on the lit side + a soft scatter halo — a body IN a sky, not a sticker on it
    const lit = clamp(0.20 + 0.80 * (sdx * L[0] + sdy * L[1]) / Math.max(sdd, 1e-6), 0, 1);
    const rim = Math.exp(-Math.pow((sdd - 1.0) / 0.035, 2)) * lit * 0.55;
    const halo = (sdd > 1 ? Math.exp(-(sdd - 1) / 0.30) : 1) * 0.035 * (0.4 + 0.6 * lit);
    const k = rim + halo;
    r += bd.atmo[0] * k; g += bd.atmo[1] * k; b += bd.atmo[2] * k;
    if (rim > 0.1) emit(x, y, bd.atmo[0], bd.atmo[1], bd.atmo[2], rim * 0.15);
  }
  return [r, g, b];
}
function shadeHole(bd, sdx, sdy, sdd, r, g, b, x, y) {
  const edgeOn = bd.variant === 'edge';
  const well = 0.30 + 0.70 * smooth(clamp((sdd - 1.0) / 3.2, 0, 1));   // the field empties toward the shadow
  r *= well; g *= well; b *= well;
  const HOT = edgeOn ? [1.00, 0.93, 0.80] : [0.85, 0.95, 1.00], WARM = edgeOn ? [1.00, 0.48, 0.14] : [0.95, 0.30, 0.85];
  const GLOWC = edgeOn ? [1.0, 0.72, 0.40] : [0.65, 0.60, 1.00];
  const dop = 1 + 0.55 * clamp(-sdx / Math.max(sdd, 1e-6), -1, 1);     // the approaching (left) side is beamed
  let glow = 0;
  const ang = Math.atan2(sdy / bd.tilt, sdx);
  const rr = Math.hypot(sdx, sdy / bd.tilt);
  // GAS HALO (v17.87): streamers spiralling in from 7 radii, brightest in the disc plane, fading into the nebula
  if (sdd > 1.2) {
    const plane = 0.35 + 0.65 * Math.exp(-Math.pow(sdy / (edgeOn ? 0.9 : 2.2), 2));
    const stream = 0.5 + 0.5 * noise(NOISE_B, (ang + 0.9 * Math.log(sdd)) * 260 + 500, sdd * 90 + bd.r * 4000);
    const I = Math.exp(-(sdd - 1.2) / 1.9) * plane * stream * (edgeOn ? 0.075 : 0.06);
    const col = edgeOn ? [1.0, 0.62, 0.30] : [0.55, 0.40, 1.00];
    r += col[0] * I; g += col[1] * I; b += col[2] * I; glow += I * 0.5;
  }
  if (edgeOn) {
    if (sdd > 1 && sdd < 2.1) {                                          // the far half, lensed into an arch over (and a sliver under) the shadow
      const up = sdy / sdd;
      const archW = up > 0 ? smooth(clamp((sdd - 1.0) / 0.12, 0, 1)) * (1 - smooth(clamp((sdd - 1.35) / 0.75, 0, 1))) * Math.pow(up, 0.7)
                           : smooth(clamp((sdd - 1.0) / 0.06, 0, 1)) * (1 - smooth(clamp((sdd - 1.12) / 0.30, 0, 1))) * Math.pow(-up, 0.9) * 0.7;
      if (archW > 0) {
        const col = mix3(HOT, WARM, smooth(clamp((sdd - 1.05) / 0.9, 0, 1)));
        const I = archW * dop * (0.9 + 0.5 * noise(NOISE_B, Math.atan2(sdy, sdx) * 400, sdd * 300)) * 0.9;
        r += col[0] * I; g += col[1] * I; b += col[2] * I; glow += I;
      }
    }
    if (sdd < 1 + bd.edge) {                                             // the shadow
      const edge = clamp((1 - sdd) / bd.edge, 0, 1);
      r = lerp(r, 0, edge); g = lerp(g, 0, edge); b = lerp(b, 0, edge);
    }
    const sig = Math.max(0.035, 1.4 / bd.pxR);                           // the photon ring
    const pr = Math.exp(-Math.pow((sdd - 1.03) / sig, 2)) * 1.3;
    if (pr > 0.01) { r += pr; g += pr * 0.88; b += pr * 0.72; glow += pr; }
    if (rr > 1.45 && rr < bd.discOut + 0.3) {                             // the disc: near half in front of everything, far half only well outside the shadow
      const side = sdy < 0 ? 1 : smooth(clamp((sdd - 1.4) / 0.7, 0, 1));
      const win = smooth(clamp((rr - 1.45) / 0.18, 0, 1)) * (1 - smooth(clamp((rr - bd.discOut + 0.5) / 0.8, 0, 1))) * side;
      if (win > 0) {
        const streak = 0.55 + 0.45 * noise(NOISE_B, Math.atan2(sdy / bd.tilt, sdx) * 500 + rr * 60, rr * 260 + 40);
        const I = win * streak * dop * (1.35 / (rr * rr)) * 1.6;
        const col = mix3(HOT, WARM, smooth(clamp((rr - 1.5) / 1.6, 0, 1)));
        const cov = clamp(win * 1.5, 0, 1);
        r = lerp(r, col[0] * I, cov); g = lerp(g, col[1] * I, cov); b = lerp(b, col[2] * I, cov); glow += I * cov * 0.4;
      }
    }
  } else {
    // THE MAELSTROM: an inclined spiral vortex — three log-spiral arms, hot core, magenta rim — and polar jets
    if (rr > 1.15 && rr < bd.discOut + 0.4) {
      const arm = 0.5 + 0.5 * Math.cos(3 * ang - 4.2 * Math.log(rr) + 1.4 * noise(NOISE_B, ang * 200 + rr * 60, rr * 300 + 900));
      const win = smooth(clamp((rr - 1.15) / 0.15, 0, 1)) * (1 - smooth(clamp((rr - bd.discOut + 0.6) / 0.9, 0, 1)));
      const I = win * (0.30 + 0.70 * Math.pow(arm, 2.2)) * (1.5 / (rr * rr)) * 2.6 * dop;
      const col = mix3(HOT, WARM, smooth(clamp((rr - 1.2) / 1.6, 0, 1)));
      const cov = clamp(win * (0.55 + 0.45 * arm) * 1.3, 0, 1);
      r = lerp(r, col[0] * I, cov); g = lerp(g, col[1] * I, cov); b = lerp(b, col[2] * I, cov); glow += I * cov * 0.4;
    }
    const jx = Math.abs(sdx), jy = Math.abs(sdy);
    if (jy > 0.85 && jy < 6.8) {                                         // the jets, along the spin axis, flaring and fading outward
      const wj = 0.09 + 0.075 * jy;
      const jet = Math.exp(-(jx * jx) / (2 * wj * wj)) * Math.exp(-(jy - 0.85) / 2.4) * (0.8 + 0.4 * noise(NOISE_A, jy * 300 + 200, jx * 900)) * 1.4;
      r += jet * 0.55; g += jet * 0.78; b += jet * 1.00; glow += jet * 0.6;
    }
    if (sdd < 1 + bd.edge) { const edge = clamp((1 - sdd) / bd.edge, 0, 1); r = lerp(r, 0, edge); g = lerp(g, 0, edge); b = lerp(b, 0, edge); }
    const sig = Math.max(0.035, 1.4 / bd.pxR);
    const pr = Math.exp(-Math.pow((sdd - 1.03) / sig, 2)) * 1.2;
    if (pr > 0.01) { r += pr * 0.85; g += pr * 0.95; b += pr; glow += pr; }
  }
  if (glow > 0.05) emit(x, y, GLOWC[0], GLOWC[1], GLOWC[2], glow * 0.22);
  return [r, g, b];
}

// ---------------------------------------------------------------- 2. THE CITY — geometry first (v17.87: the sky pass reads it)
console.log(`building ${W}x${H} theme=${THEME} ...`);
const t0 = Date.now();
function pickHue() { let t = rnd() * T.hueWeights.reduce((s, w) => s + w[1], 0); for (const [k, w] of T.hueWeights) if ((t -= w) <= 0) return k; return 'cyan'; }
const items = [];   // every drawable: {d, draw()} — painter's order, far first
const boxes = [];   // every box, for the skyline profile / searchlights / the glow dome
const FILL = [0.012, 0.010, 0.032];

function rayBox(c, s, bx) {
  let tmin = -Infinity, tmax = Infinity, face = 0;
  if (Math.abs(c) < 1e-9) { if (0 < bx.x0 || 0 > bx.x1) return null; }
  else { let t1 = bx.x0 / c, t2 = bx.x1 / c, f = c > 0 ? 1 : 2; if (t1 > t2) { const tt = t1; t1 = t2; t2 = tt; } if (t1 > tmin) { tmin = t1; face = f; } if (t2 < tmax) tmax = t2; }
  if (Math.abs(s) < 1e-9) { if (0 < bx.y0 || 0 > bx.y1) return null; }
  else { let t1 = bx.y0 / s, t2 = bx.y1 / s, f = s > 0 ? 3 : 4; if (t1 > t2) { const tt = t1; t1 = t2; t2 = tt; } if (t1 > tmin) { tmin = t1; face = f; } if (t2 < tmax) tmax = t2; }
  if (tmax <= tmin || tmax <= 0 || tmin <= 0) return null;
  return [tmin, tmax, face];
}
function azSpan(bx) {
  const cAz = Math.atan2((bx.y0 + bx.y1) / 2, (bx.x0 + bx.x1) / 2);
  let half = 0;
  for (const [px, py] of [[bx.x0, bx.y0], [bx.x1, bx.y0], [bx.x0, bx.y1], [bx.x1, bx.y1]]) half = Math.max(half, Math.abs(wrapAz(Math.atan2(py, px) - cAz)));
  return [Math.floor((cAz - half) / TAU * W) - 1, Math.ceil((cAz + half) / TAU * W) + 1];
}

// A BOX: x0..x1, y0..y1, z0..z1 (absolute heights above the city plane), hue,
// lit = window density 0..1, plain = edges only (antennas), sign = {face,u0,u1,z0,z1,col},
// refl = mirror the base into the ground. Depth model (v17.87) in the header.
function drawBox(bx) {
  const [col0, col1] = azSpan(bx);
  const fog = fogOf(bx.d), lfog = lightFogOf(bx.d);
  const hue = HUE[bx.hue];
  const gridK = smooth(clamp((fog - 0.08) / 0.45, 0, 1));      // the face grid dissolves beyond ~8k
  const lineK = 0.16 + 0.84 * fog;                              // edges keep 16% at infinity
  const hazeK = Math.pow(1 - fog, 0.75);                        // how far the fill has gone toward the sky behind it
  const midEl = clamp(Math.atan(((bx.z0 + bx.z1) / 2 - EYE) / bx.d), 0, 18 * D2R);
  const winK = 0.35 + 0.65 * lfog;
  const dotP = fog < 0.45 ? 0.06 * (0.5 + (bx.lit || 0)) * (1 - fog) : 0;   // sparse point lights on hazed buildings
  const roofVisible = bx.z1 < EYE, underVisible = bx.z0 > EYE;
  const reflLen = bx.refl ? Math.round(((28 + 40 * fog) * PXO + 6) * SS) : 0;
  for (let xx = col0; xx <= col1; xx++) {
    const x = ((xx % W) + W) % W;
    const az = azOfCol(x), c = Math.cos(az), s = Math.sin(az);
    const hit = rayBox(c, s, bx); if (!hit) continue;
    const [tIn, tOut, face] = hit;
    const sb = skyBaseAt(az, midEl);                            // the sky this box stands in
    const fc = [lerp(FILL[0], sb[0] * 0.58, hazeK), lerp(FILL[1], sb[1] * 0.58, hazeK), lerp(FILL[2], sb[2] * 0.58, hazeK)];
    const lc = [lerp(hue[0], sb[0] * 2.0 + 0.10, hazeK * 0.9), lerp(hue[1], sb[1] * 2.0 + 0.10, hazeK * 0.9), lerp(hue[2], sb[2] * 2.0 + 0.10, hazeK * 0.9)];
    const wc = mix3(hue, sb, (1 - lfog) * 0.6);                 // window / point-light colour
    let u, faceLen, ndot;
    if (face === 1 || face === 2) { u = s * tIn - bx.y0; faceLen = bx.y1 - bx.y0; ndot = Math.abs(c); }
    else { u = c * tIn - bx.x0; faceLen = bx.x1 - bx.x0; ndot = Math.abs(s); }
    const fp = Math.max(tIn * TAU / W / Math.max(0.15, ndot), 1.0);
    const du = Math.abs(u - Math.round(u / CELL) * CELL);
    const cornerD = Math.min(u, faceLen - u);
    const covV = bx.plain ? 0 : clamp(1 - du / (Math.max(fp, 2.0) * LW), 0, 1) * gridK;
    const covCorner = clamp(1 - cornerD / (Math.max(fp * 1.2, 2.5) * LW), 0, 1);
    const cellIdx = Math.floor(u / CELL);
    const topEl = Math.atan((bx.z1 - EYE) / tIn), botEl = Math.atan((bx.z0 - EYE) / tIn);
    const topRow = rowOfEl(topEl), botRow = rowOfEl(botEl);
    const y0 = Math.max(0, Math.floor(topRow)), y1 = Math.min(H - 1, Math.ceil(botRow));
    const sign = bx.sign && bx.sign.face === face && u >= bx.sign.u0 && u <= bx.sign.u1 ? bx.sign : null;
    for (let y = y0; y <= y1; y++) {
      const covTop = Math.min(clamp(y + 0.5 - topRow + 0.5, 0, 1), clamp(botRow - (y + 0.5) + 0.5, 0, 1));
      if (covTop <= 0) continue;
      const el = elOfRow(y);
      const z = EYE + Math.tan(el) * tIn;
      const rowsPerUnit = (tIn / (tIn * tIn + (z - EYE) * (z - EYE))) * (H / Math.PI);
      const dz = Math.abs(z - Math.round(z / FLOOR) * FLOOR);
      const covH = bx.plain ? 0 : clamp(1 - dz * rowsPerUnit / (1.1 * LW), 0, 1) * gridK;
      const covEdge = Math.max(clamp(0.4 + LW - Math.abs(y + 0.5 - topRow), 0, 1), clamp(0.4 + LW - Math.abs(y + 0.5 - botRow), 0, 1));
      const fl = Math.floor(z / FLOOR);
      let cr = fc[0], cg = fc[1], cb = fc[2];
      // ground glow up the face + window density
      const gl = 0.10 * clamp(1 - (z - bx.z0) / 900, 0, 1) * fog;
      cr = lerp(cr, lc[0], gl); cg = lerp(cg, lc[1], gl); cb = lerp(cb, lc[2], gl);
      if (!bx.plain && bx.lit > 0 && h2(cellIdx * 7 + face * 131, fl + Math.floor(bx.d)) > 1 - bx.lit * 0.42) {
        const wk = (0.16 + 0.22 * h2(cellIdx * 3 + fl * 17, face)) * winK;
        cr = lerp(cr, wc[0], wk); cg = lerp(cg, wc[1], wk); cb = lerp(cb, wc[2], wk);
      }
      if (dotP > 0 && !bx.plain && h2(cellIdx * 31 + fl * 7, face + 77) < dotP) {   // a lit window far away is a point of light
        const k = 1.5 * (0.6 + 0.4 * h2(cellIdx, fl + 5));
        cr = wc[0] * k; cg = wc[1] * k; cb = wc[2] * k;
        emit(x, y, wc[0], wc[1], wc[2], 0.10 * covTop);
      }
      if (sign && z >= sign.z0 && z <= sign.z1) {
        // v18.87: a sign is a LIGHT, so it carries on lfog (the far-ring mega-billboards would vanish on fog); glyph rows
        // scale with the sign so a 2,000-unit holo wall on a megastructure reads as text blocks, not a 3-row strip
        const rows = sign.rows || 3;
        const gw = (sign.z1 - sign.z0) * 0.55 * 3 / rows, gu = Math.floor((u - sign.u0) / gw), gz = Math.floor((z - sign.z0) / ((sign.z1 - sign.z0) / rows));
        const border = (u - sign.u0 < gw * 0.25) || (sign.u1 - u < gw * 0.25) || (z - sign.z0 < (sign.z1 - sign.z0) * 0.12 / (rows / 3)) || (sign.z1 - z < (sign.z1 - sign.z0) * 0.12 / (rows / 3));
        const glyph = !border && h2(gu * 13 + gz, sign.seed) > 0.48;
        const sk = (border ? 0.95 : glyph ? 0.22 : 0.85) * (sign.holo ? (((y / SS) | 0) % 3 === 0 ? 0.6 : 1.0) : 1);
        const sf = lerp(fog, lfog, 0.7);
        cr = lerp(cr, sign.col[0], sk * sf); cg = lerp(cg, sign.col[1], sk * sf); cb = lerp(cb, sign.col[2], sk * sf);
        if (!glyph) emit(x, y, sign.col[0], sign.col[1], sign.col[2], 0.22 * sf * sf);
      }
      let li = Math.max(covV * 0.75, covH * 0.75, covCorner * 1.0, covEdge * 1.0);
      li *= lineK;
      cr = lerp(cr, lc[0] * 1.15, li); cg = lerp(cg, lc[1] * 1.15, li); cb = lerp(cb, lc[2] * 1.15, li);
      // v18.87 ATMOSPHERE: the lit air between the eye and this point (ground mist at the feet, the strata it stands behind)
      let vk = 1;
      const vl = veil(az, tIn, z, c, s);
      if (vl) { cr = lerp(cr, vl[1], vl[0]); cg = lerp(cg, vl[2], vl[0]); cb = lerp(cb, vl[3], vl[0]); vk = 1 - vl[0]; }
      blend(x, y, cr, cg, cb, covTop);
      if (covTop > 0.5) Z[y * W + x] = tIn;
      if (li > 0.45) emit(x, y, lc[0], lc[1], lc[2], li * 0.28 * covTop * fog * fog * vk);
    }
    // reflection of the base into the ground plane (v18.87: drowned by the mist the foot stands in)
    if (reflLen > 0 && bx.z0 === 0) {
      const b0 = Math.ceil(botRow);
      const vl = veil(az, tIn, 0, c, s), rk = vl ? 1 - vl[0] : 1;
      for (let k = 1; k <= reflLen; k++) {
        const y = b0 + k, ys = b0 - k; if (y >= H || ys < 0) break;
        const a = 0.20 * (1 - k / reflLen) * fog * rk;
        const o = ys * W + x;
        blend(x, y, R[o], G[o], B[o], a);
      }
    }
    // roof (eye above) / underside (eye below a raised box)
    const face2 = roofVisible ? bx.z1 : underVisible ? bx.z0 : null;
    if (face2 !== null) {
      const nearEl = Math.atan((face2 - EYE) / tIn), farEl = Math.atan((face2 - EYE) / tOut);
      const rA = Math.min(rowOfEl(nearEl), rowOfEl(farEl)), rB = Math.max(rowOfEl(nearEl), rowOfEl(farEl));
      const ry0 = Math.max(0, Math.floor(rA)), ry1 = Math.min(H - 1, Math.ceil(rB));
      for (let y = ry0; y <= ry1; y++) {
        const cov = Math.min(clamp(y + 0.5 - rA + 0.5, 0, 1), clamp(rB - (y + 0.5) + 0.5, 0, 1)); if (cov <= 0) continue;
        const el = elOfRow(y), tt = (face2 - EYE) / Math.tan(el);
        const X = c * tt, Y = s * tt;
        const fpT = tt * TAU / W, fpR = Math.abs((EYE - face2) / (Math.sin(el) * Math.sin(el))) * (Math.PI / H);
        const fpp = Math.max(fpT, fpR, 1.5);
        const dX = Math.abs(X - Math.round(X / CELL) * CELL), dY = Math.abs(Y - Math.round(Y / CELL) * CELL);
        const gcov = bx.plain ? 0 : Math.max(clamp(1 - dX / (fpp * LW), 0, 1), clamp(1 - dY / (fpp * LW), 0, 1)) * gridK;
        const ecov = Math.max(clamp(0.4 + LW - Math.abs(y + 0.5 - rA), 0, 1), clamp(0.4 + LW - Math.abs(y + 0.5 - rB), 0, 1));
        const li = Math.max(gcov * 0.7, ecov) * lineK;
        const rf = mix3(fc, [0.02, 0.02, 0.05], 0.3);
        blend(x, y, lerp(rf[0], lc[0] * 1.15, li), lerp(rf[1], lc[1] * 1.15, li), lerp(rf[2], lc[2] * 1.15, li), cov);
        if (cov > 0.5) Z[y * W + x] = Math.min(Z[y * W + x], tt);
        if (li > 0.45) emit(x, y, lc[0], lc[1], lc[2], li * 0.25 * cov * fog * fog);
      }
    }
  }
}
// ---------------------------------------------------------------- v19.19 SMOOTH SOLIDS (ported from Tower II's v0.7, its docs/63)
// user 2026-09-16: "not everything is so blocky ... more sharp". The skyline had ONE solid primitive, the axis-aligned
// box: every antenna mast was a thin box, every setback a flat step, the ziggurat / arcology tapers were stacks of
// shrinking boxes. A PROFILE SOLID is the fix: its cross-section is a FUNCTION of height, sec(z) -> {cx, cy, hx, hy},
// and each column MARCHES z at ~2.5 samples per screen row solving the section analytically — a circle when o.round
// (masts, collars, spires: no faces, so no face-flip shading), otherwise an axis-aligned rectangle (sloped setbacks,
// pitched tops, tapering tiers). The columns the section only partly covers get FRACTIONAL coverage (covX), so a mast
// thins out instead of snapping off at a whole pixel. Shading is drawBox's own recipe (haze fill, window cells, the
// neon cell grid, corner + top/bottom rims, the veil, the emit) so a solid sits in the same light as the box it tops;
// round sections add a cylindrical falloff. drawBox itself is untouched — the box masses render as before.
const ROW_T = new Float32Array(H).fill(Infinity), ROW_Z = new Float32Array(H), ROW_L = new Float32Array(H), ROW_U = new Float32Array(H), ROW_N = new Float32Array(H), ROW_C = new Float32Array(H), ROW_F = new Int8Array(H);
function drawSolid(o) {
  const [col0, col1] = azSpan(o);
  const fog = fogOf(o.d), lfog = lightFogOf(o.d);
  const hue = HUE[o.hue];
  const gridK = smooth(clamp((fog - 0.08) / 0.45, 0, 1));
  const lineK = 0.16 + 0.84 * fog;
  const hazeK = Math.pow(1 - fog, 0.75);
  const midEl = clamp(Math.atan(((o.z0 + o.z1) / 2 - EYE) / o.d), 0, 18 * D2R);
  const winK = 0.35 + 0.65 * lfog;
  const dotP = fog < 0.45 ? 0.06 * (0.5 + (o.lit || 0)) * (1 - fog) : 0;
  const hz = o.z1 - o.z0;
  const ch = Math.PI / W;                                                        // a column's angular half-width
  const dNear = Math.max(50, o.d - halfDiag(o.x1 - o.x0, o.y1 - o.y0));
  const n = clamp(Math.ceil(hz / dNear * (H / Math.PI) * 2.5) + 6, 10, 20000);   // z samples: ~2.5 per screen row at the near range
  for (let xx = col0; xx <= col1; xx++) {
    const x = ((xx % W) + W) % W;
    const az = azOfCol(x), c = Math.cos(az), s = Math.sin(az);
    let rMin = Infinity, rMax = -Infinity, prevR;
    // ---- march the section up the solid, keeping the nearest sample per row
    for (let k = 0; k <= n; k++) {
      const z = o.z0 + hz * k / n;
      const S = o.sec(z);
      const along = c * S.cx + s * S.cy; if (along <= 0) continue;
      const perp = -s * S.cx + c * S.cy;                                          // signed lateral offset of the axis from the ray
      const dc = Math.hypot(S.cx, S.cy);
      let tIn, tOut, lat, u, nd, face, covX;
      if (o.round) {
        const r = S.hx;
        const ah = Math.asin(Math.min(1, r / dc)), da = wrapAz(Math.atan2(S.cy, S.cx) - az);
        covX = clamp((Math.min(da + ah, ch) - Math.max(da - ah, -ch)) / (2 * ch), 0, 1); if (covX <= 0) continue;
        if (Math.abs(perp) < r) { const q = Math.sqrt(r * r - perp * perp); tIn = along - q; tOut = along + q; lat = perp / r; }
        else { tIn = tOut = Math.sqrt(Math.max(1, dc * dc - r * r)); lat = perp > 0 ? 1 : -1; }
        u = r * Math.asin(clamp(lat, -1, 1)) + S.cx * 0.01;                         // arc length from the near meridian
        nd = Math.sqrt(Math.max(0, 1 - lat * lat)); face = 5;
      } else {
        const bx = { x0: S.cx - S.hx, x1: S.cx + S.hx, y0: S.cy - S.hy, y1: S.cy + S.hy };
        let ah = 0; const cAz = Math.atan2(S.cy, S.cx);
        for (const [px, py] of [[bx.x0, bx.y0], [bx.x1, bx.y0], [bx.x0, bx.y1], [bx.x1, bx.y1]]) ah = Math.max(ah, Math.abs(wrapAz(Math.atan2(py, px) - cAz)));
        const da = wrapAz(cAz - az);
        covX = clamp((Math.min(da + ah, ch) - Math.max(da - ah, -ch)) / (2 * ch), 0, 1); if (covX <= 0) continue;
        const hit = rayBox(c, s, bx);
        if (hit) {
          [tIn, tOut, face] = hit;
          if (face === 1 || face === 2) { u = s * tIn - bx.y0; nd = Math.abs(c); lat = 1 - 2 * Math.min(u, 2 * S.hy - u) / Math.max(1, 2 * S.hy); }
          else { u = c * tIn - bx.x0; nd = Math.abs(s); lat = 1 - 2 * Math.min(u, 2 * S.hx - u) / Math.max(1, 2 * S.hx); }
        } else { tIn = tOut = Math.sqrt(Math.max(1, dc * dc - S.hx * S.hx - S.hy * S.hy)); u = 0; nd = 0.5; lat = 1; face = 1; }
      }
      // v19.19b: the NEAR edge only. Spanning near..far rows at one z painted the end slices as discs — a comb
      // fringe at every foot (the ground-contact disc, which a box never draws either). Consecutive samples are
      // joined so a slope stays continuous.
      const rN = rowOfEl(Math.atan((z - EYE) / tIn));
      if (prevR === undefined) prevR = rN;
      const rA = Math.min(rN, prevR), rB = Math.max(rN, prevR); prevR = rN;
      if (rA < rMin) rMin = rA; if (rB > rMax) rMax = rB;
      const y0 = Math.max(0, Math.floor(rA)), y1 = Math.min(H - 1, Math.ceil(rB));
      for (let y = y0; y <= y1; y++) {
        if (tIn < ROW_T[y]) { ROW_T[y] = tIn; ROW_Z[y] = z; ROW_L[y] = lat; ROW_U[y] = u; ROW_N[y] = nd; ROW_F[y] = face; }
        if (covX > ROW_C[y]) ROW_C[y] = covX;
      }
    }
    if (rMin === Infinity) continue;
    // ---- paint the column (drawBox's recipe)
    const sb = skyBaseAt(az, midEl);
    const fc = [lerp(FILL[0], sb[0] * 0.58, hazeK), lerp(FILL[1], sb[1] * 0.58, hazeK), lerp(FILL[2], sb[2] * 0.58, hazeK)];
    const lc = [lerp(hue[0], sb[0] * 2.0 + 0.10, hazeK * 0.9), lerp(hue[1], sb[1] * 2.0 + 0.10, hazeK * 0.9), lerp(hue[2], sb[2] * 2.0 + 0.10, hazeK * 0.9)];
    const wc = mix3(hue, sb, (1 - lfog) * 0.6);
    const ya = Math.max(0, Math.floor(rMin)), yb = Math.min(H - 1, Math.ceil(rMax));
    for (let y = ya; y <= yb; y++) {
      const tIn = ROW_T[y]; if (tIn === Infinity) continue;
      const lat = ROW_L[y], u = ROW_U[y], nd = ROW_N[y], covX = ROW_C[y];
      ROW_T[y] = Infinity; ROW_C[y] = 0;
      // v19.19b: the EXACT height at this row (drawBox's own z), not the sample's — the sample grid quantised z and
      // dashed every floor ring
      const z = clamp(EYE + Math.tan(elOfRow(y)) * tIn, o.z0, o.z1);
      const cov = Math.min(clamp(y + 0.5 - rMin + 0.5, 0, 1), clamp(rMax - (y + 0.5) + 0.5, 0, 1)) * covX;
      if (cov <= 0.002) continue;
      const S = o.sec(z), halfW = o.round ? S.hx : Math.max(S.hx, S.hy);
      const fp = Math.max(tIn * TAU / W / Math.max(0.15, nd), 1.0);
      const rowsPerUnit = (tIn / (tIn * tIn + (z - EYE) * (z - EYE))) * (H / Math.PI);
      const du = Math.abs(u - Math.round(u / CELL) * CELL);
      const dz = Math.abs(z - Math.round(z / FLOOR) * FLOOR);
      const covV = o.plain ? 0 : clamp(1 - du / (Math.max(fp, 2.0) * LW), 0, 1) * gridK;
      const covH = o.plain ? 0 : clamp(1 - dz * rowsPerUnit / (1.1 * LW), 0, 1) * gridK;
      const edgeD = (1 - Math.abs(lat)) * halfW;                                  // distance in from the silhouette / the face corner
      const covCorner = clamp(1 - edgeD / (Math.max(fp * 1.2, 2.5) * LW), 0, 1);
      const covEdge = Math.max(o.capTop === false ? 0 : clamp(0.4 + LW - Math.abs(y + 0.5 - rMin), 0, 1), o.capBot === false ? 0 : clamp(0.4 + LW - Math.abs(y + 0.5 - rMax), 0, 1));
      const cellIdx = Math.floor(u / CELL), fl = Math.floor(z / FLOOR);
      const shade = o.round ? 0.80 + 0.30 * nd : 1;                               // a round section turns away from the eye
      let cr = fc[0] * shade, cg = fc[1] * shade, cb = fc[2] * shade;
      const gl = 0.10 * clamp(1 - (z - o.z0) / 900, 0, 1) * fog * (o.z0 < 50 ? 1 : 0.35);
      cr = lerp(cr, lc[0], gl); cg = lerp(cg, lc[1], gl); cb = lerp(cb, lc[2], gl);
      if (!o.plain && o.lit > 0 && h2(cellIdx * 7 + 5 * 131, fl + Math.floor(o.d)) > 1 - o.lit * 0.42) {
        const wk = (0.16 + 0.22 * h2(cellIdx * 3 + fl * 17, 5)) * winK;
        cr = lerp(cr, wc[0], wk); cg = lerp(cg, wc[1], wk); cb = lerp(cb, wc[2], wk);
      }
      if (dotP > 0 && !o.plain && h2(cellIdx * 31 + fl * 7, 5 + 77) < dotP) {
        const k = 1.5 * (0.6 + 0.4 * h2(cellIdx, fl + 5));
        cr = wc[0] * k; cg = wc[1] * k; cb = wc[2] * k;
        emit(x, y, wc[0], wc[1], wc[2], 0.10 * cov);
      }
      let li = Math.max(covV * 0.75, covH * 0.75, covCorner * 1.0, covEdge * 1.0);
      li *= lineK;
      cr = lerp(cr, lc[0] * 1.15, li); cg = lerp(cg, lc[1] * 1.15, li); cb = lerp(cb, lc[2] * 1.15, li);
      let vk = 1;
      const vl = veil(az, tIn, z, c, s);
      if (vl) { cr = lerp(cr, vl[1], vl[0]); cg = lerp(cg, vl[2], vl[0]); cb = lerp(cb, vl[3], vl[0]); vk = 1 - vl[0]; }
      blend(x, y, cr, cg, cb, cov);
      if (cov > 0.5) Z[y * W + x] = tIn;
      if (li > 0.45) emit(x, y, lc[0], lc[1], lc[2], li * 0.28 * cov * fog * fog * vk);
    }
  }
}

function drawBeaconAt(cx, cy, z, col) {
  const az = Math.atan2(cy, cx), dc = Math.hypot(cx, cy);
  const el = Math.atan((z - EYE) / dc);
  const lf = lightFogOf(dc);
  const px = az / TAU * W, py = rowOfEl(el) - 1.0 * SS;
  const rad = Math.max(1.6 * SS, 2.4 * PX) * (0.6 + 0.4 * lf);
  const c = col || [1.3, 0.25, 0.25];
  dotAA(px, py, rad, c, 0.5 + 0.5 * lf, false, dc - 30);
  dotAA(px, py, rad * 0.7, [c[0] * 0.8, c[1] * 0.6, c[2] * 0.6], 0.9 * lf, false, dc - 30);
  // bloom
  for (let yy = Math.floor(py - rad); yy <= Math.ceil(py + rad); yy++) for (let xx = Math.floor(px - rad); xx <= Math.ceil(px + rad); xx++) { if (yy < 0 || yy >= H) continue; emit(((xx % W) + W) % W, yy, c[0], c[1] * 0.6, c[2] * 0.6, 0.6 * lf); }
}
function drawBeacon(bx) { drawBeaconAt((bx.x0 + bx.x1) / 2, (bx.y0 + bx.y1) / 2, bx.z1, bx.beaconCol); }
// TRAFFIC: a light-trail along an avenue (axis 'x': the line X = pos, running in Y from t0 to t1); head = a bright dot at the head end
function drawStreak(st) {
  const col = HUE[st.hue], z = st.z;
  const pA = Math.atan2(st.axis === 'x' ? st.t0 : st.pos, st.axis === 'x' ? st.pos : st.t0);
  const pB = Math.atan2(st.axis === 'x' ? st.t1 : st.pos, st.axis === 'x' ? st.pos : st.t1);
  const cAz = pA + wrapAz(pB - pA) / 2, half = Math.abs(wrapAz(pB - pA)) / 2 + 0.002;
  const col0 = Math.floor((cAz - half) / TAU * W) - 1, col1 = Math.ceil((cAz + half) / TAU * W) + 1;
  const wpx = (1.5 * PXO + 0.6) * SS;
  for (let xx = col0; xx <= col1; xx++) {
    const x = ((xx % W) + W) % W;
    const az = azOfCol(x), c = Math.cos(az), s = Math.sin(az);
    const den = st.axis === 'x' ? c : s; if (Math.abs(den) < 1e-6) continue;
    const dist = st.pos / den; if (dist <= 0) continue;
    const t = (st.axis === 'x' ? s : c) * dist;
    if (t < Math.min(st.t0, st.t1) || t > Math.max(st.t0, st.t1)) continue;
    const range = Math.hypot(dist, t);
    const fog = lightFogOf(range);
    const el = Math.atan((z - EYE) / range);
    const row = rowOfEl(el);
    const along = (t - st.t0) / (st.t1 - st.t0);                       // 0 tail .. 1 head
    const vl = veil(az, range, z, c, s), vk = vl ? 1 - vl[0] : 1;      // v18.87: street traffic runs inside the mist and under the strata
    const inten = (st.head ? 0.06 + 1.1 * Math.pow(along, 3.0) : 0.45 + 0.75 * Math.pow(along, 2.0)) * (0.35 + 0.65 * fog) * vk;
    for (let y = Math.floor(row - wpx - 1); y <= Math.ceil(row + wpx + 1); y++) {
      if (y < 0 || y >= H) continue;
      const cov = clamp(wpx + 0.5 - Math.abs(y + 0.5 - row), 0, 1) * inten; if (cov <= 0) continue;
      if (Z[y * W + x] < range) continue;
      blend(x, y, col[0] * 1.2, col[1] * 1.2, col[2] * 1.2, cov);
      emit(x, y, col[0], col[1], col[2], cov * 0.6 * fog);
    }
  }
  if (st.head) {
    const hx = st.axis === 'x' ? st.pos : st.t1, hy = st.axis === 'x' ? st.t1 : st.pos;
    const range = Math.hypot(hx, hy), lf = lightFogOf(range);
    const px = Math.atan2(hy, hx) / TAU * W, py = rowOfEl(Math.atan((z - EYE) / range)) + 0.5 * SS;
    const hc = mix3(col, [1, 1, 1], 0.55);
    dotAA(px, py, (1.3 * PXO + 0.7) * SS, hc, 0.5 + 0.5 * lf, false, range);
    emit(Math.floor(px) % W, Math.floor(py), hc[0], hc[1], hc[2], 0.5 * lf);
  }
}
// ELEVATED RING HIGHWAY (v17.87): a circle of radius R at height z round (cx, cy) — two rails + traffic dashes,
// drawn as anti-aliased dots along the curve so it is exact in the equirect; chunked by ring angle for painter's order
const RAIL_GIRDER = 110, RAIL_BRACE_U = 360;   // v18.89: the truss under every deck (depth, post spacing in world units)
function drawRingChunk(rg, phi0, phi1) {
  // v17.87b: a DECK, not a ribbon — a dark filled face between two thin neon rails, cross-ties every 1.5 deg of ring
  // angle, traffic dashes on the top rail; every dot depth-tested against the buildings at its own range.
  // v18.88 THE RAIL PASS (user: "I saw some train railroads ... did you deeply enhance those?"): TRAINS — strings of
  // lit cars riding the top rail with window rows, a headlight, tail lights and a glow trail; STATIONS — a platform
  // band, a canopy with a lit strip under it, a glyph board and two lamp posts where the line passes a tower; the far
  // rim sinks deeper into the smog (FAR_K); the line can be a SPAN of the circle (rg.p0..p1) so a huge ring is a
  // straight-looking line across the city.
  const hue = HUE[rg.hue], hue2 = HUE[rg.hue2 || 'gold'];
  let tmin = Infinity;
  for (let k = 0; k <= 4; k++) { const ph = lerp(phi0, phi1, k / 4); tmin = Math.min(tmin, Math.hypot(rg.cx + rg.R * Math.cos(ph), rg.cy + rg.R * Math.sin(ph))); }
  const dphi = Math.max(1e-5, 0.55 * tmin / (rg.R * W / TAU));
  const CAR_H = 105, CAR_LEN = 190, CAR_GAP = 22, N_WIN = 6;          // world units; a car is a lit box riding the top rail
  const ST_PLAT = 44, ST_CAN = 200, ST_STRIP = 156, ST_SIGN0 = 70, ST_SIGN1 = 130;
  for (let phi = phi0; phi < phi1; phi += dphi) {
    const X = rg.cx + rg.R * Math.cos(phi), Y = rg.cy + rg.R * Math.sin(phi);
    const t = Math.hypot(X, Y), az = Math.atan2(Y, X);
    const fog = fogOf(t), lfog = lightFogOf(t), hazeK = Math.pow(1 - fog, 0.75);
    const farK = 0.30 + 0.70 * Math.exp(-t / 12000);                   // v18.88: the far rim sinks into the smog
    const px = ((az / TAU * W) % W + W) % W, x = Math.floor(px) % W;
    const sb = skyBaseAt(az, clamp(Math.atan((rg.z - EYE) / t), 0, 18 * D2R));
    const lc = [lerp(hue[0], sb[0] * 2.0 + 0.10, hazeK * 0.9), lerp(hue[1], sb[1] * 2.0 + 0.10, hazeK * 0.9), lerp(hue[2], sb[2] * 2.0 + 0.10, hazeK * 0.9)];
    const fc = [lerp(FILL[0], sb[0] * 0.58, hazeK), lerp(FILL[1], sb[1] * 0.58, hazeK), lerp(FILL[2], sb[2] * 0.58, hazeK)];
    const rowAt = z => rowOfEl(Math.atan((z - EYE) / t)) + 0.5 * SS;
    const pyT = rowAt(rg.z), pyB = rowAt(rg.z - rg.deck);
    const railW = clamp(rg.thick / t * (W / TAU), 0.35 * SS, 1.4 * SS) * LW / SS;
    const vl = veil(az, t, rg.z, Math.cos(az), Math.sin(az)), vk = (vl ? 1 - vl[0] : 1) * farK;   // v18.87: the far rim runs behind the strata
    const I0 = (0.16 + 0.84 * fog) * vk;
    // a vertical band of the column between two heights, depth-tested, with fractional end rows
    const band = (zLo, zHi, r, g, b, a) => {
      const yA = rowAt(zHi), yB = rowAt(zLo);
      for (let yy = Math.floor(yA); yy <= Math.ceil(yB); yy++) {
        if (yy < 0 || yy >= H) continue;
        const cov = Math.min(clamp(yy + 0.5 - yA + 0.5, 0, 1), clamp(yB - (yy + 0.5) + 0.5, 0, 1)) * a; if (cov <= 0) continue;
        if (Z[yy * W + x] < t) continue;
        blend(x, yy, r, g, b, cov);
      }
    };
    // the deck face — v18.89 (user: "doesn't look like it fits in well"): the flat slab is now a face in the CITY'S
    // grammar — dark glass, a neon grid at CELL spacing along the line that dissolves with range exactly as the
    // towers' does, lit rails as its edges — and it writes depth so the trains and dots test against it
    const sAlong = phi * rg.R;                                              // arc length along the line, world units
    const fp = Math.max(t * TAU / W, 1.0);                                  // world units per column at this range
    const gridK = smooth(clamp((fog - 0.08) / 0.45, 0, 1)), lineK = 0.16 + 0.84 * fog;
    const duT = Math.abs(sAlong - Math.round(sAlong / CELL) * CELL);
    const covTie = clamp(1 - duT / (Math.max(fp, 2.0) * LW), 0, 1) * gridK;
    const dfc = mix3(fc, [0.02, 0.02, 0.05], 0.25);
    for (let yy = Math.floor(pyT); yy <= Math.ceil(pyB); yy++) {
      if (yy < 0 || yy >= H) continue;
      const cov = Math.min(clamp(yy + 0.5 - pyT + 0.5, 0, 1), clamp(pyB - (yy + 0.5) + 0.5, 0, 1)); if (cov <= 0) continue;
      if (Z[yy * W + x] < t) continue;
      const li = covTie * 0.75 * lineK;
      let cr = lerp(dfc[0], lc[0] * 1.15, li), cg = lerp(dfc[1], lc[1] * 1.15, li), cb = lerp(dfc[2], lc[2] * 1.15, li);
      if (vl) { cr = lerp(cr, vl[1], vl[0]); cg = lerp(cg, vl[2], vl[0]); cb = lerp(cb, vl[3], vl[0]); }
      blend(x, yy, cr, cg, cb, cov * (0.86 + 0.14 * farK));
      if (cov > 0.5) Z[yy * W + x] = Math.min(Z[yy * W + x], t);
      if (li > 0.45) emit(x, yy, lc[0], lc[1], lc[2], li * 0.28 * cov * fog * fog * vk);
    }
    // THE GIRDER (v18.89): a truss under the deck — a see-through dark band, a post every RAIL_BRACE_U with a zigzag
    // brace between posts, a lit bottom chord; the braces only resolve once the girder is a few pixels tall
    const pyG = rowAt(rg.z - rg.deck - RAIL_GIRDER);
    const gRows = pyG - pyB;
    const ph = ((sAlong / RAIL_BRACE_U) % 1 + 1) % 1, tri = ph < 0.5 ? ph * 2 : 2 - ph * 2;
    const duP = Math.abs(sAlong - Math.round(sAlong / RAIL_BRACE_U) * RAIL_BRACE_U);
    const covPost = clamp(1 - duP / (Math.max(fp, 2.0) * LW), 0, 1);
    const braceK = clamp((gRows - 3 * SS) / (5 * SS), 0, 1) * gridK;
    for (let yy = Math.floor(pyB); yy <= Math.ceil(pyG); yy++) {
      if (yy < 0 || yy >= H) continue;
      const cov = Math.min(clamp(yy + 0.5 - pyB + 0.5, 0, 1), clamp(pyG - (yy + 0.5) + 0.5, 0, 1)); if (cov <= 0) continue;
      if (Z[yy * W + x] < t) continue;
      const v = clamp((yy + 0.5 - pyB) / Math.max(1e-3, gRows), 0, 1);
      const covX = clamp(1 - Math.abs(v - tri) * gRows / (1.1 * LW), 0, 1) * braceK;
      const li = Math.max(covX * 0.8, covPost * 0.9 * gridK) * lineK;
      blend(x, yy, dfc[0], dfc[1], dfc[2], cov * 0.35 * vk);
      if (li > 0.02) blend(x, yy, lc[0], lc[1], lc[2], cov * li * vk);
    }
    dotAA(px, pyG, railW * 0.7, lc, clamp(I0 * 0.6, 0, 1), false, t);          // the bottom chord
    // the rails
    const I = I0;
    dotAA(px, pyT, railW, [lc[0] * 1.15, lc[1] * 1.15, lc[2] * 1.15], clamp(I, 0, 1), false, t);
    dotAA(px, pyB, railW * 0.8, [lc[0] * 1.0, lc[1] * 1.0, lc[2] * 1.0], clamp(I * 0.7, 0, 1), false, t);
    if (fog > 0.3 && Z[Math.floor(pyT) * W + x] >= t) emit(x, Math.floor(pyT), hue[0], hue[1], hue[2], 0.16 * fog * farK);
    // STATIONS (v18.88)
    let inStation = false;
    for (const st of rg.stations || []) {
      const dd = wrapAz(phi - st.phi); if (Math.abs(dd) > st.half) continue;
      inStation = true;
      const pc = mix3(fc, [0.02, 0.02, 0.05], 0.30);
      band(rg.z, rg.z + ST_PLAT, pc[0], pc[1], pc[2], 0.95 * vk);                                    // the platform (v18.89: dark glass, lit edge)
      band(rg.z + ST_CAN - 16, rg.z + ST_CAN, pc[0], pc[1], pc[2], 0.95 * vk);                        // v18.89: the canopy slab under its lit edge
      dotAA(px, rowAt(rg.z + ST_PLAT), railW * 0.9, lc, clamp(I * 0.8, 0, 1), false, t);              // its lit edge
      dotAA(px, rowAt(rg.z + ST_CAN), railW * 1.3, [lc[0] * 1.1, lc[1] * 1.1, lc[2] * 1.1], clamp(I, 0, 1), false, t);   // the canopy
      const wc = mix3([1.0, 0.96, 0.88], sb, (1 - lfog) * 0.5);
      dotAA(px, rowAt(rg.z + ST_STRIP), railW * 0.7, wc, clamp(0.85 * vk, 0, 1), false, t);          // the lit strip under it
      if (Z[Math.floor(rowAt(rg.z + ST_STRIP)) * W + x] >= t) emit(x, Math.floor(rowAt(rg.z + ST_STRIP)), wc[0], wc[1], wc[2], 0.35 * lfog * farK);
      if (Math.abs(dd) < st.half * 0.28) {                                                             // the glyph board
        const gu = Math.floor((dd + st.half * 0.28) / (st.half * 0.56) * 9);
        const yA = rowAt(rg.z + ST_SIGN1), yB = rowAt(rg.z + ST_SIGN0);
        for (let yy = Math.floor(yA); yy <= Math.ceil(yB); yy++) {
          if (yy < 0 || yy >= H || Z[yy * W + x] < t) continue;
          const cov = Math.min(clamp(yy + 0.5 - yA + 0.5, 0, 1), clamp(yB - (yy + 0.5) + 0.5, 0, 1)); if (cov <= 0) continue;
          const gz = Math.floor((yy - yA) / Math.max(1, yB - yA) * 3);
          const border = gu === 0 || gu === 8 || gz === 0 && (yy - yA) < 1.5 * SS;
          const glyph = !border && h2(gu * 13 + gz * 7, st.seed) > 0.45;
          const sk = (border ? 0.9 : glyph ? 0.2 : 0.75) * (0.4 + 0.6 * lfog) * vk;
          blend(x, yy, hue2[0], hue2[1], hue2[2], cov * sk);
          if (!glyph) emit(x, yy, hue2[0], hue2[1], hue2[2], 0.18 * cov * lfog * farK);
        }
      }
      for (const e of [-1, 1]) if (Math.abs(wrapAz(phi - (st.phi + e * st.half * 0.92))) < dphi * 0.6) {   // two lamp posts
        band(rg.z + ST_PLAT, rg.z + ST_CAN, lc[0] * 0.8, lc[1] * 0.8, lc[2] * 0.8, 0.9 * vk);
      }
    }
    // TRAINS (v18.88) — a string of cars riding the top rail; u runs 0 (tail) .. len (head) in ring angle
    let onTrain = false;
    for (const tr of rg.trains || []) {
      const u = tr.dir > 0 ? wrapAz(phi - tr.phi) : wrapAz(tr.phi - phi);
      if (u < 0 || u >= tr.len) continue;
      const pitch = (CAR_LEN + CAR_GAP) / rg.R, ci = Math.floor(u / pitch), uc = u - ci * pitch;
      if (uc > CAR_LEN / rg.R) continue;                                  // the gap between cars
      onTrain = true;
      const fCar = uc / (CAR_LEN / rg.R);
      const bc = mix3(fc, [0.02, 0.02, 0.05], 0.35);                     // v18.89: dark glass like the towers (was a pale strip)
      band(rg.z, rg.z + CAR_H, bc[0], bc[1], bc[2], 0.97 * vk);                                      // the body
      const wi = Math.floor(fCar * N_WIN), wf = fCar * N_WIN - wi;
      const lit = h2(ci * 5 + wi, tr.seed) > 0.22, wc = mix3(mix3([0.80, 0.92, 1.0], hue, 0.30), sb, (1 - lfog) * 0.5);   // v18.89: cool, in the line's hue
      if (fCar < 0.07 || fCar > 0.93) band(rg.z, rg.z + CAR_H, lc[0] * 1.1, lc[1] * 1.1, lc[2] * 1.1, clamp(I, 0, 1));   // v18.89: neon car ends
      if (lit && wf > 0.16 && wf < 0.84) { band(rg.z + CAR_H * 0.40, rg.z + CAR_H * 0.66, wc[0], wc[1], wc[2], 0.75 * vk); if (Z[Math.floor(rowAt(rg.z + CAR_H * 0.55)) * W + x] >= t) emit(x, Math.floor(rowAt(rg.z + CAR_H * 0.55)), wc[0], wc[1], wc[2], 0.22 * lfog * farK); }
      dotAA(px, rowAt(rg.z + CAR_H), railW * 1.1, [lc[0] * 1.1, lc[1] * 1.1, lc[2] * 1.1], clamp(I, 0, 1), false, t);   // the roof rim
      { const uc2 = mix3(hue, [1, 1, 1], 0.5), yU = rowAt(rg.z + 10); dotAA(px, yU, railW * 0.9, uc2, clamp(I * 0.9, 0, 1), false, t); if (Z[Math.floor(yU) * W + x] >= t) emit(x, Math.floor(yU), uc2[0], uc2[1], uc2[2], 0.25 * lfog * farK); }   // v18.89: the lit underframe
      if (ci === tr.nCars - 1 && fCar > 0.86) {                            // the headlight
        const hc = [1.2, 1.15, 1.05]; const yH = rowAt(rg.z + CAR_H * 0.30);
        dotAA(px, yH, railW * 1.6, hc, clamp(0.5 + 0.5 * lfog, 0, 1) * vk, false, t); emit(x, Math.floor(yH), hc[0], hc[1], hc[2], 0.9 * lfog * farK);
      }
      if (ci === 0 && fCar < 0.12) {                                       // the tail lights
        const tc = [1.2, 0.18, 0.18]; const yH = rowAt(rg.z + CAR_H * 0.30);
        dotAA(px, yH, railW * 1.2, tc, clamp(0.5 + 0.5 * lfog, 0, 1) * vk, false, t); emit(x, Math.floor(yH), tc[0], tc[1], tc[2], 0.6 * lfog * farK);
      }
    }
    // the glow trail the train leaves on the rail behind its tail (a maglev's charged track), fading over 1.6 car lengths
    for (const tr of rg.trains || []) {
      const back = tr.dir > 0 ? wrapAz(tr.phi - phi) : wrapAz(phi - tr.phi);
      const trail = 1.6 * (CAR_LEN + CAR_GAP) / rg.R;
      if (back > 0 && back < trail) { const k = (1 - back / trail) * 0.6 * lfog * farK; const tc = mix3(hue, [1, 1, 1], 0.4); dotAA(px, pyT, railW * 1.3, tc, clamp(k, 0, 1), false, t); emit(x, Math.floor(pyT), tc[0], tc[1], tc[2], k * 0.8); }
    }
    // traffic on the top rail (not under a train or a station)
    if (!onTrain && !inStation) {
      let dash = 0;
      for (const [dp, dl] of rg.dashes) { const dd = Math.abs(wrapAz(phi - dp)); if (dd < dl) dash = Math.max(dash, 1 - dd / dl); }
      if (dash > 0) { const dc = mix3(hue, [1, 1, 1], 0.5); dotAA(px, pyT - railW * 0.8, railW * 1.5, dc, dash * (0.35 + 0.65 * lfog) * farK, false, t); emit(x, Math.floor(pyT), dc[0], dc[1], dc[2], dash * 0.5 * lfog * farK); }
    }
  }
}
// SEARCHLIGHT (v17.87): a beam from a roof into the sky, in pixel space (near-vertical, so straight is right), additive
// v19.69 THE BEAM MEETS THE CLOUD (docs/169): the low deck's coverage in a SKY direction - the sky pass's own formula -
// for the searchlights below. A beam that climbs to the deck's height and finds cloud there ENDS in a soft lit patch on
// the cloud base (an ellipse: the deck is seen obliquely); through a gap it carries on and fades as before.
function lowDeckCov(az, el) {
  if (el <= 0.8 * D2R) return 0;
  const cosEl = Math.max(0.02, Math.cos(el));
  const tt = CLOUD_LOW_Z / Math.tan(el), X = Math.cos(az) * tt, Y = Math.sin(az) * tt;
  const dn = fbm2(X / 2300 + 3.7, Y / 2300 - 1.9, 101, 4);
  let cov = smooth(clamp((dn - 0.50) / 0.22, 0, 1));
  if (T.storm > 0 && !SKIP.has('storm')) {
    const sd = Math.hypot(wrapAz(az - STORM_AZ) * cosEl, el - STORM_EL), sk = Math.exp(-sd * sd / (2 * 0.10 * 0.10)) * T.storm;
    if (sk > 0.01) cov = Math.max(cov, smooth(clamp(sk * 1.4, 0, 1)) * (0.5 + 0.5 * smooth(clamp((dn - 0.30) / 0.30, 0, 1))));
  }
  return cov * smooth(clamp((el - 0.8 * D2R) / (3.2 * D2R), 0, 1));
}
function beamHit(bm, cx, cy, cov) {
  const w = ((1.6 + 7.0 * 0.35) * PXO + 0.7) * SS;               // the beam's width where it meets the deck
  const rx = w * 9.0, ry = w * 2.8, I = bm.k * 0.55 * cov;
  for (let yy = Math.floor(cy - ry * 2.2); yy <= Math.ceil(cy + ry * 2.2); yy++) {
    if (yy < 0 || yy >= H) continue;
    for (let xx = Math.floor(cx - rx * 2.2); xx <= Math.ceil(cx + rx * 2.2); xx++) {
      const x = ((xx % W) + W) % W, o = yy * W + x;
      if (Z[o] < bm.depth) continue;                                 // a nearer tower hides the patch
      const dx = (xx + 0.5 - cx) / rx, dy = (yy + 0.5 - cy) / ry, q = dx * dx + dy * dy;
      if (q > 4.8) continue;
      const v = I * Math.exp(-q * 1.6) * (0.75 + 0.5 * noise(NOISE_C, x, yy * 1.3));
      addc(x, yy, bm.col[0], bm.col[1], bm.col[2], v);
      if (q < 0.6) emit(x, yy, bm.col[0], bm.col[1], bm.col[2], v * 0.6);
    }
  }
}
function drawBeam(bm) {
  const steps = bm.len / 0.7;
  // v19.69: the deck's height along this beam, as a pixel row (the beam stands at the roof's range)
  const hits = !SKIP.has('beamhits') && bm.d !== undefined && bm.roof < CLOUD_LOW_Z - 120;
  const hitRow = hits ? rowOfEl(Math.atan((CLOUD_LOW_Z - EYE) / bm.d)) : -Infinity;
  // a lamp ON a tower that reaches into the overcast: the cloud around it (the ceiling's own veil at the roof) dims the
  // beam and the light diffuses into a glow inside the cloud - the beam no longer leaves a top the ceiling has hidden
  let dimK = 1;
  if (!SKIP.has('beamhits') && bm.d !== undefined && !hits) {
    const az0 = azOfCol(((Math.round(bm.px) % W) + W) % W);
    const v = cloudCeil(az0, bm.d, bm.roof + 40, Math.cos(az0), Math.sin(az0));
    if (v && v[0] > 0.05) { dimK = 1 - 0.85 * v[0]; beamHit(bm, bm.px, bm.py - 2 * SS, v[0] * 0.9); }
    if (process.env.TOD_SKY_PLUMEDBG) console.log(`    beam in cloud: roof ${bm.roof.toFixed(0)} d ${bm.d.toFixed(0)} veil ${v ? v[0].toFixed(2) : 0} -> beam x${dimK.toFixed(2)}`);
  }
  if (process.env.TOD_SKY_PLUMEDBG && hits) console.log(`    beam: from row ${bm.py.toFixed(0)} len ${bm.len.toFixed(0)} lean ${bm.ang.toFixed(2)} deck row ${hitRow.toFixed(0)} d ${bm.d.toFixed(0)} roof ${bm.roof.toFixed(0)}`);
  for (let i = 0; i < steps; i++) {
    const s = i * 0.7, f = s / bm.len;
    const cx = bm.px + Math.sin(bm.ang) * s, cy = bm.py - Math.cos(bm.ang) * s;
    if (cy < 0) break;
    if (hits && cy <= hitRow) {
      const cov = lowDeckCov(azOfCol(((Math.round(cx) % W) + W) % W), elOfRow(Math.max(0, Math.round(cy))));
      if (cov > 0.30) {                                                 // the cloud stops the beam
        if (process.env.TOD_SKY_PLUMEDBG) console.log(`    beam hit: x ${cx.toFixed(0)} y ${cy.toFixed(0)} (az ${(azOfCol(((Math.round(cx) % W) + W) % W) / D2R).toFixed(1)} el ${(elOfRow(Math.round(cy)) / D2R).toFixed(1)}) cov ${cov.toFixed(2)} d ${bm.d.toFixed(0)}`);
        beamHit(bm, cx, cy, cov); break;
      }
    }
    const w = ((1.6 + 7.0 * f) * PXO + 0.7) * SS;
    let I = bm.k * (1 - f) * (1 - f) * 0.11;
    if (dimK !== 1) I *= dimK;
    dotAA(cx, cy, w, bm.col, I * 0.55, true, bm.depth);          // a soft cross-section: core, mid, skirt
    dotAA(cx, cy, w * 1.9, bm.col, I * 0.28, true, bm.depth);
    dotAA(cx, cy, w * 3.2, bm.col, I * 0.12, true, bm.depth);
    if ((i & 3) === 0) emit(Math.floor(((cx % W) + W) % W), Math.floor(cy), bm.col[0], bm.col[1], bm.col[2], I * 0.8);
  }
}
// v19.69 ROOFTOP PLUMES (docs/169): steam and exhaust rising off a dozen mid-city roofs - soft billowing columns lit
// from below by the building's own neon, leaning down one wind, thinning as they rise, depth-tested so a nearer tower
// cuts them and they veil the towers behind. Drawn as a sheet facing the eye at the roof's range (a lat-long sky has
// no parallax, so a volume and its facing sheet are the same picture).
const WIND_AZ = SUN_AZ + 0.6;   // the bearing the plumes lean toward
const PLUME_SPREAD = 0.16;       // how fast a column widens as it rises (width = vent + height x this); 0.5 drew a 70-degree haze sheet
function drawPlume(p) {
  const az0 = Math.atan2(p.y, p.x), hueC = HUE[p.hue];
  const dbg = process.env.TOD_SKY_PLUMEDBG ? { n: 0, hid: 0, strong: 0, cols: 0, rows: 0 } : null;
  const fog = fogOf(p.d), hazeK = Math.pow(1 - fog, 0.75);
  const perp = Math.sin(WIND_AZ - az0);                              // the wind's component across the line of sight
  const halfMax = (p.w0 + p.h * PLUME_SPREAD) * 2.4 + Math.abs(perp) * p.h * 0.55;
  const span = Math.atan2(halfMax, p.d);
  const c0 = Math.floor((az0 - span) / TAU * W), c1 = Math.ceil((az0 + span) / TAU * W);
  const r0 = Math.max(0, Math.floor(rowOfEl(Math.atan((p.z + p.h - EYE) / p.d))) - 2), r1 = Math.min(H - 1, Math.ceil(rowOfEl(Math.atan((p.z - EYE) / p.d))));
  for (let xx = c0; xx <= c1; xx++) {
    const x = ((xx % W) + W) % W, az = azOfCol(x);
    const u = wrapAz(az - az0) * p.d;
    for (let y = r0; y <= r1; y++) {
      if (dbg) dbg.n++;
      if (Z[y * W + x] < p.d - 30) { if (dbg) dbg.hid++; continue; }   // a nearer surface
      const el = elOfRow(y), hgt = EYE + Math.tan(el) * p.d - p.z;
      if (hgt < 0 || hgt > p.h) continue;
      const f = hgt / p.h, width = p.w0 + hgt * PLUME_SPREAD;
      const q = (u - perp * p.h * 0.55 * Math.pow(f, 1.35)) / width;
      if (q * q > 6) continue;
      const n = fbm2(q * 1.25 + p.seed, hgt / 230 + p.seed * 0.37, 707, 3);
      const dens = Math.exp(-q * q * 2.2) * (0.30 + 1.0 * n) * Math.pow(1 - f, 1.3) * smooth(clamp(hgt / 50, 0, 1));
      const a = clamp(dens * 0.80, 0, 0.85) * (0.45 + 0.55 * fog);
      if (a < 0.004) continue;
      const lit = Math.exp(-hgt / (p.h * 0.28));                      // the neon under it lights its foot
      const base = mix3(mix3(airCol(az, p.d), [0.62, 0.55, 0.80], 0.35), [hueC[0] * 0.80, hueC[1] * 0.80, hueC[2] * 0.80], lit * 0.85);
      const col = mix3(base, skyBaseAt(az, el), hazeK * 0.75);
      blend(x, y, col[0], col[1], col[2], a);
      if (dbg && a > 0.15) dbg.strong++;
    }
  }
  if (dbg) console.log(`    plume at az ${(az0 / D2R).toFixed(1)}: cols ${c1 - c0 + 1} rows ${r1 - r0 + 1} px tested ${dbg.n} hidden ${dbg.hid} strong(a>0.15) ${dbg.strong}`);
}
// HOLOGRAPHIC PANEL (v17.87): a translucent glyph screen floating over the roofs — a vertical plane along one axis
function drawHolo(hp) {
  const col = HUE[hp.hue];
  const pA = Math.atan2(hp.axis === 'x' ? hp.u0 : hp.pos, hp.axis === 'x' ? hp.pos : hp.u0);
  const pB = Math.atan2(hp.axis === 'x' ? hp.u1 : hp.pos, hp.axis === 'x' ? hp.pos : hp.u1);
  const cAz = pA + wrapAz(pB - pA) / 2, half = Math.abs(wrapAz(pB - pA)) / 2 + 0.002;
  const col0 = Math.floor((cAz - half) / TAU * W) - 1, col1 = Math.ceil((cAz + half) / TAU * W) + 1;
  const gw = (hp.z1 - hp.z0) / 5;
  for (let xx = col0; xx <= col1; xx++) {
    const x = ((xx % W) + W) % W;
    const az = azOfCol(x), c = Math.cos(az), s = Math.sin(az);
    const den = hp.axis === 'x' ? c : s; if (Math.abs(den) < 1e-6) continue;
    const dist = hp.pos / den; if (dist <= 0) continue;
    const t = (hp.axis === 'x' ? s : c) * dist;
    if (t < hp.u0 || t > hp.u1) continue;
    const u = t - hp.u0, uLen = hp.u1 - hp.u0;
    const range = Math.hypot(dist, t), lf = lightFogOf(range), fog = fogOf(range);
    const gu = Math.floor(u / gw);
    const topRow = rowOfEl(Math.atan((hp.z1 - EYE) / range)), botRow = rowOfEl(Math.atan((hp.z0 - EYE) / range));
    const y0 = Math.max(0, Math.floor(topRow)), y1 = Math.min(H - 1, Math.ceil(botRow));
    const bu = u < uLen * 0.04 || uLen - u < uLen * 0.04;
    for (let y = y0; y <= y1; y++) {
      const cov = Math.min(clamp(y + 0.5 - topRow + 0.5, 0, 1), clamp(botRow - (y + 0.5) + 0.5, 0, 1)); if (cov <= 0) continue;
      const z = EYE + Math.tan(elOfRow(y)) * range;
      const gz = Math.floor((z - hp.z0) / gw);
      const border = bu || z - hp.z0 < gw * 0.18 || hp.z1 - z < gw * 0.18;
      const glyph = !border && h2(gu * 13 + gz * 7, hp.seed) > 0.46;
      const scan = (((y / SS) | 0) % 3 === 0) ? 0.55 : 1.0;                  // scanlines in FINAL pixels
      const a = (border ? 0.70 : glyph ? 0.42 : 0.09) * scan * (0.3 + 0.7 * lf) * cov;
      const flick = 0.8 + 0.4 * h2((y / (4 * SS)) | 0, hp.seed + 3);
      if (Z[y * W + x] < range) continue;
      blend(x, y, col[0] * 1.1 * flick, col[1] * 1.1 * flick, col[2] * 1.1 * flick, a);
      if (border || glyph) emit(x, y, col[0], col[1], col[2], a * 0.35 * fog);
    }
  }
}

// ---------------------------------------------------------------- v18.87 CYBER ART: airships, the storm bolt
// AIRSHIP: a dirigible drawn in disc space (sdx along the hull, sdy up; both in half-lengths), depth-tested at its range.
// Dark hull converging on the sky with range, a neon rim, three longitudinal ribs, tail fins, a lit gondola, a holo
// billboard on the flank with scanlines, red/green running lights and a white strobe. Placed by bearing from the moon.
function drawAirship(sh) {
  const az = SUN_AZ + sh.azOff, d = sh.d, elc = Math.atan((sh.z - EYE) / d), cosEl = Math.cos(elc);
  const aL = (sh.len / 2) / d, ASP = 0.30;
  const fog = fogOf(d), lfog = lightFogOf(d), hazeK = Math.pow(1 - fog, 0.75), lineK = 0.16 + 0.84 * fog;
  const hue = HUE[sh.hue], ad = HUE[sh.adHue];
  const sb = skyBaseAt(az, elc);
  const fc = [lerp(FILL[0] * 1.3, sb[0] * 0.58, hazeK), lerp(FILL[1] * 1.3, sb[1] * 0.58, hazeK), lerp(FILL[2] * 1.3, sb[2] * 0.58, hazeK)];
  const lc = [lerp(hue[0], sb[0] * 2.0 + 0.10, hazeK * 0.9), lerp(hue[1], sb[1] * 2.0 + 0.10, hazeK * 0.9), lerp(hue[2], sb[2] * 2.0 + 0.10, hazeK * 0.9)];
  const ew = LW * (TAU / W) / aL;                                            // the rim's width in disc units
  const c0 = Math.floor((az - aL * 1.25 / cosEl) / TAU * W), c1 = Math.ceil((az + aL * 1.25 / cosEl) / TAU * W);
  const r0 = Math.max(0, Math.floor(rowOfEl(elc + aL * 0.75))), r1 = Math.min(H - 1, Math.ceil(rowOfEl(elc - aL * 0.75)));
  const under = mix3(fc, airCol(az, d), 0.45);                              // the belly catches the city light
  for (let xx = c0; xx <= c1; xx++) {
    const x = ((xx % W) + W) % W, pxAz = azOfCol(x);
    const sdx = wrapAz(pxAz - az) * cosEl / aL;
    for (let y = r0; y <= r1; y++) {
      if (Z[y * W + x] < d) continue;
      const sdy = (elOfRow(y) - elc) / aL;
      const q = Math.sqrt(sdx * sdx + (sdy / ASP) * (sdy / ASP));
      let cr = 0, cg = 0, cb = 0, a = 0, li = 0;
      if (q < 1 + ew) {
        const inside = clamp((1 + ew * 0.5 - q) / ew, 0, 1);
        const belly = smooth(clamp((-sdy / ASP + 0.2) / 1.2, 0, 1)) * 0.55;
        cr = lerp(fc[0], under[0], belly); cg = lerp(fc[1], under[1], belly); cb = lerp(fc[2], under[2], belly);
        // ribs along the hull + the rim
        let rib = 0; for (const ry of [-0.5, 0, 0.5]) rib = Math.max(rib, clamp(1 - Math.abs(sdy / ASP - ry * Math.sqrt(Math.max(0, 1 - sdx * sdx))) / (ew * 1.2), 0, 1) * 0.35);
        li = Math.max(clamp(1 - Math.abs(q - 1) / ew, 0, 1), rib) * lineK;
        // the billboard on the flank
        if (sdx > -0.62 && sdx < 0.30 && Math.abs(sdy / ASP) < 0.42) {
          const uu = (sdx + 0.62) / 0.92, vv = (sdy / ASP + 0.42) / 0.84;
          const border = uu < 0.05 || uu > 0.95 || vv < 0.08 || vv > 0.92;
          const glyph = !border && h2(Math.floor(uu * 14) * 13 + Math.floor(vv * 4), sh.d | 0) > 0.47;
          const scan = (((y / SS) | 0) % 3 === 0) ? 0.6 : 1.0;
          const sk = (border ? 0.85 : glyph ? 0.16 : 0.62) * scan * (0.4 + 0.6 * lfog);
          cr = lerp(cr, ad[0], sk); cg = lerp(cg, ad[1], sk); cb = lerp(cb, ad[2], sk);
          if (!glyph) emit(x, y, ad[0], ad[1], ad[2], 0.18 * lfog * inside);
        }
        a = inside;
      }
      // tail fins (two, above and below the hull at the tail) and the gondola under the belly
      if (sdx < -0.72 && sdx > -1.06) { const fw = 0.16 + 0.42 * clamp((-0.72 - sdx) / 0.34, 0, 1); if (Math.abs(sdy / ASP) < fw / ASP * ASP + 0.02 && Math.abs(sdy) < fw) { const edge = clamp((fw - Math.abs(sdy)) / (ew * ASP * 1.5), 0, 1); cr = fc[0]; cg = fc[1]; cb = fc[2]; li = Math.max(li, (1 - edge) * lineK); a = Math.max(a, 1); } }
      if (Math.abs(sdx + 0.05) < 0.18 && sdy < -ASP * 0.92 && sdy > -ASP * 0.92 - 0.075) {
        const wu = Math.floor((sdx + 0.23) / 0.06), win = wu % 2 === 0 && h2(wu, sh.d | 0) > 0.3;
        cr = fc[0] * 0.9; cg = fc[1] * 0.9; cb = fc[2] * 0.9;
        if (win) { const wc = mix3([1.0, 0.85, 0.55], sb, (1 - lfog) * 0.6); cr = wc[0] * 0.9; cg = wc[1] * 0.9; cb = wc[2] * 0.9; emit(x, y, wc[0], wc[1], wc[2], 0.10 * lfog); }
        li = Math.max(li, clamp(1 - Math.abs(sdy + ASP * 0.92 + 0.0375) / 0.03, 0, 1) * 0.5 * lineK); a = Math.max(a, 1);
      }
      if (a <= 0) continue;
      cr = lerp(cr, lc[0] * 1.15, li); cg = lerp(cg, lc[1] * 1.15, li); cb = lerp(cb, lc[2] * 1.15, li);
      blend(x, y, cr, cg, cb, a);
      if (a > 0.5) Z[y * W + x] = d;
      if (li > 0.45) emit(x, y, lc[0], lc[1], lc[2], li * 0.25 * a * fog * fog);
    }
  }
  // running lights: red tail, green nose, white strobe on the spine
  const pxOf = (sx, sy) => [((az + sx * aL / cosEl) / TAU * W), rowOfEl(elc + sy * aL)];
  for (const [sx, sy, col, k] of [[-1.0, 0, [1.2, 0.2, 0.2], 0.9], [1.0, 0, [0.2, 1.1, 0.4], 0.9], [0, ASP + 0.02, [1.2, 1.2, 1.3], 1.1]]) {
    const [px, py] = pxOf(sx, sy), rad = (1.1 * PXO + 0.6) * SS * (0.6 + 0.4 * lfog);
    dotAA(px, py, rad, col, (0.5 + 0.5 * lfog) * k, false, d - 1);
    for (let yy = Math.floor(py - rad); yy <= Math.ceil(py + rad); yy++) for (let xx = Math.floor(px - rad); xx <= Math.ceil(px + rad); xx++) { if (yy < 0 || yy >= H) continue; emit(((xx % W) + W) % W, yy, col[0], col[1], col[2], 0.5 * lfog); }
  }
}
// THE BOLT: one branching lightning stroke from the storm cell's cloud base down to the far ring, in pixel space,
// jittered by a hashed random walk (deterministic), hazed at its range, depth-tested; the cell's in-cloud glow is
// painted by the sky pass (see the low deck block)
function drawBolt(bt) {
  const lf = lightFogOf(bt.d), core = [1.00, 0.96, 1.10], glow = T.stormCol;
  const wCore = (0.9 * PXO + 0.5) * SS, wGlow = wCore * 3.5;
  const stroke = (az0, el0, el1, n, seed, amp, k) => {
    let paz = az0, pel = el0, drift = 0;
    for (let i = 1; i <= n; i++) {
      const f = i / n;
      drift += (h2(i, seed) - 0.5) * amp - drift * 0.18;                       // a random walk pulled back toward the trunk's axis
      const naz = az0 + drift, nel = lerp(el0, el1, f);
      const x0 = paz / TAU * W, y0 = rowOfEl(pel), x1 = naz / TAU * W, y1 = rowOfEl(nel);
      const len = Math.hypot(x1 - x0, y1 - y0), steps = Math.max(2, Math.ceil(len / (0.6 * SS)));
      for (let s = 0; s <= steps; s++) {
        const px = lerp(x0, x1, s / steps), py = lerp(y0, y1, s / steps);
        const I = k * (0.35 + 0.65 * lf) * (1 - 0.35 * f);
        dotAA(px, py, wGlow, glow, I * 0.10, true, bt.d);
        dotAA(px, py, wCore, core, I * 0.85, false, bt.d);
        if ((s & 3) === 0) emit(Math.floor(((px % W) + W) % W), Math.floor(py), glow[0], glow[1], glow[2], I * 0.9);
      }
      paz = naz; pel = nel;
    }
    return [paz, pel];
  };
  const [maz, mel] = stroke(bt.az, bt.el0, bt.el1, 22, 901, 0.55 * D2R, 1.0);
  stroke(bt.az + (h2(3, 901) - 0.5) * 0.6 * D2R, lerp(bt.el0, bt.el1, 0.30), lerp(bt.el0, bt.el1, 0.62), 9, 902, 0.7 * D2R, 0.45);
  stroke(bt.az + (h2(7, 901) - 0.5) * 0.6 * D2R, lerp(bt.el0, bt.el1, 0.55), lerp(bt.el0, bt.el1, 0.80), 7, 903, 0.6 * D2R, 0.35);
  void maz; void mel;
}

let nB = 0, nTier = 0, nAnt = 0, nSign = 0, nFar = 0, nHolo = 0, nBeam = 0, nSt = 0, nAir = 0, nMega = 0, nShip = 0;
const glowAcc = o => {
  const cx = (o.x0 + o.x1) / 2, cy = (o.y0 + o.y1) / 2, az = Math.atan2(cy, cx);
  const w = Math.max(o.x1 - o.x0, o.y1 - o.y0) * Math.max(0, o.z1 - o.z0) * (0.35 + (o.lit || 0)) * lightFogOf(o.d) / Math.max(o.d, 500);
  GLOW_RAW[Math.floor((((az / TAU) % 1) + 1) % 1 * GLOW_BINS) % GLOW_BINS] += w;
};
const addBox = (o) => { o.d = o.d || Math.hypot((o.x0 + o.x1) / 2, (o.y0 + o.y1) / 2); if (!Number.isFinite(o.d)) throw new Error('addBox: d is not finite'); items.push({ d: o.d, draw: () => drawBox(o), box: o }); boxes.push(o); glowAcc(o); return o; };
const halfDiag = (w, dep) => Math.hypot(w, dep) / 2;
let nSolid = 0, nRound = 0, nCrown = 0, nDome = 0;
// register a PROFILE SOLID (v19.19): sec(z) over z0..z1; the bounding box (column span, skyline profile, glow dome,
// the body-clearance print) is sampled from the section. Same ledger as a box, so every consumer of `boxes` sees it.
const addSolid = (o) => {
  let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
  for (let k = 0; k <= 32; k++) { const S = o.sec(o.z0 + (o.z1 - o.z0) * k / 32); x0 = Math.min(x0, S.cx - S.hx); x1 = Math.max(x1, S.cx + S.hx); y0 = Math.min(y0, S.cy - S.hy); y1 = Math.max(y1, S.cy + S.hy); }
  o.x0 = x0; o.x1 = x1; o.y0 = y0; o.y1 = y1;
  o.d = o.d || Math.hypot((x0 + x1) / 2, (y0 + y1) / 2);
  if (!Number.isFinite(o.d)) throw new Error('addSolid: d is not finite — a NaN d breaks the painter sort for the WHOLE city');
  items.push({ d: o.d, draw: () => drawSolid(o), solid: o }); boxes.push(o); glowAcc(o); nSolid++;
  return o;
};
// a ROUND BODY: a tube whose radius follows prof(f) (f = 0 at the base, 1 at the top) — a mast, a collar, a column
function roundBody(cx, cy, z0, h, prof, opts = {}) {
  return addSolid({ z0, z1: z0 + h, round: true, hue: opts.hue, lit: opts.lit || 0, plain: !!opts.plain, capTop: opts.capTop !== false, capBot: opts.capBot !== false, d: opts.d,
    sec: z => { const f = clamp((z - z0) / h, 0, 1); const r = Math.max(1.0, prof(f)); return { cx, cy, hx: r, hy: r }; } });
}
// a SPIRE: a round cone, slightly concave (curve > 1 hollows the flanks), from width w at z0 to a point at z0 + h
function spire(cx, cy, z0, w, h, opts = {}) {
  const curve = opts.curve || 1.18;
  return roundBody(cx, cy, z0, h, f => w / 2 * Math.pow(1 - f, curve), { hue: opts.hue, lit: opts.lit || 0, plain: opts.plain !== false, d: opts.d, capBot: false });
}
// a HIP CAP: a rectangular slope from (w0 x d0) at z0 to (w1 x d1) at z0 + h, centred on (cx, cy) — the pitch on a
// setback (every tier step used to be a flat ledge), a pyramid when the top closes to a point
function hipCap(cx, cy, z0, w0, d0, w1, d1, h, opts = {}) {
  return addSolid({ z0, z1: z0 + h, round: false, hue: opts.hue, lit: opts.lit || 0, plain: !!opts.plain, capTop: opts.capTop !== false, capBot: opts.capBot !== false, d: opts.d,
    sec: z => { const f = clamp((z - z0) / h, 0, 1); return { cx, cy, hx: Math.max(1, lerp(w0, w1, f) / 2), hy: Math.max(1, lerp(d0, d1, f) / 2) }; } });
}
// the SETBACK between a box and the smaller box that will stand on it: a sloped band capH tall (the lower box's own
// hue / window density); returns the z the upper box starts at. zCap binds it to the composition lanes.
function setback(bx, nw, nd, hue, lit, d, zCap, frac) {
  const cx = (bx.x0 + bx.x1) / 2, cy = (bx.y0 + bx.y1) / 2, w = bx.x1 - bx.x0, dep = bx.y1 - bx.y0;
  const capH = Math.min((frac || 0.10) * Math.min(w, dep), (zCap === undefined ? Infinity : zCap) - bx.z1);
  if (capH < 3 || SKIP.has('slope')) return bx.z1;
  hipCap(cx, cy, bx.z1, w, dep, nw, nd, capH, { hue, lit, d: d - 0.5, capBot: false });
  return bx.z1 + capH;
}
function antennaOn(top, hue, baseD, zCap) {
  const cx = (top.x0 + top.x1) / 2, cy = (top.y0 + top.y1) / 2;
  let ah = 120 + rnd() * 520 + top.z1 * 0.08;
  if (zCap !== undefined) ah = Math.min(ah, zCap - top.z1);           // the composition lanes bind the mast too
  if (ah < 40) return null;
  const aw = 14 + rnd() * 10;
  // v19.19: the mast is a ROUND TAPER (w -> 0.3 w), not a thin box; the collars are round discs
  const ant = roundBody(cx, cy, top.z1, ah, f => lerp(aw / 2, aw * 0.15, f), { hue, plain: true, d: baseD - 3, capBot: false });
  const v = rnd();                                                   // v17.87: four kinds of mast, not one stick
  if (v < 0.32) for (const f of [0.45, 0.80]) roundBody(cx, cy, top.z1 + ah * f - 12, 24, () => aw * 1.7, { hue, plain: true, d: baseD - 3.5 });
  else if (v < 0.52) addBox({ x0: cx + aw / 2, x1: cx + aw / 2 + 70, y0: cy - 40, y1: cy + 40, z0: top.z1 + ah * 0.6 - 30, z1: top.z1 + ah * 0.6 + 30, hue, lit: 0, d: baseD - 3.5 });
  else if (v < 0.68) items.push({ d: baseD - 4, draw: () => drawBeaconAt(cx, cy, top.z1 + ah * 0.55, [1.1, 1.1, 1.2]) });
  items.push({ d: baseD - 4, draw: () => drawBeacon(ant) }); nAnt++;
  return ant;
}
(() => {
  const clusters = [
    [SUN_AZ + 2.2, 3800, 2400, 4.2], [SUN_AZ - 1.9, 5400, 3000, 5.0], [SUN_AZ + 0.9, 7200, 2800, 3.6],
    [SUN_AZ - 0.6, 9000, 3400, 3.2], [SUN_AZ + 3.0, 8000, 2400, 3.8],
  ].map(([a, d, rad, m]) => ({ x: Math.cos(a) * d, y: Math.sin(a) * d, rad, m }));
  if (JSON.stringify(clusters.map(c => [c.x, c.y, c.rad, c.m])) !== JSON.stringify(UG_NEAR.map(([a, d, rad, m]) => [Math.cos(a) * d, Math.sin(a) * d, rad, m]))) throw new Error('UG_NEAR no longer matches the city clusters (v19.69 lockstep)');
  const N = Math.ceil(CITY_R / LOT);
  for (let i = -N; i <= N; i++) for (let j = -N; j <= N; j++) {
    rngState = (hq(i, j, SEED) * 4294967295) >>> 0 || 1;                    // v18.87: per-lot stream (see the note above the loop in docs/104 4g)
    const cx = i * LOT + (rnd() - 0.5) * 80, cy = j * LOT + (rnd() - 0.5) * 80;
    const d = Math.hypot(cx, cy);
    if (d < INNER_R || d > CITY_R) continue;
    if ((i % 4 === 0 || j % 4 === 0) && rnd() < 0.85) continue;
    if (rnd() < 0.22) continue;
    let mult = 1;
    for (const c of clusters) { const dd = Math.hypot(cx - c.x, cy - c.y); if (dd < c.rad) mult = Math.max(mult, 1 + (c.m - 1) * smooth(1 - dd / c.rad)); }
    const w = LOT * (0.42 + rnd() * 0.36), dep = LOT * (0.42 + rnd() * 0.36);
    let h = (260 + Math.pow(rnd(), 1.6) * 1100) * mult;
    if (rnd() < 0.06) h *= 1.8;
    const zCap = laneCap(cx, cy, halfDiag(w, dep));
    h = Math.min(h, 6500, zCap);
    if (h < 120) continue;
    if (Math.atan(w / d) * OW_BASE / TAU < 2.0) continue;                    // v18.87: the size gate keys on the SHIPPED pixel, so every --width / --ss draws the same city
    const hue = pickHue();
    const litRoll = rnd();
    const lit = litRoll < 0.25 ? 0 : litRoll < 0.7 ? 0.35 + rnd() * 0.3 : 0.7 + rnd() * 0.3;
    const near = d < 6000;
    const base = { x0: cx - w / 2, x1: cx + w / 2, y0: cy - dep / 2, y1: cy + dep / 2, z0: 0, z1: h, hue, lit, refl: near };
    // billboard on the face toward the eye, mid/near only
    if (near && h > 500 && rnd() < 0.28) {
      const face = Math.abs(cx) > Math.abs(cy) ? (cx > 0 ? 1 : 2) : (cy > 0 ? 3 : 4);
      const len = (face <= 2) ? dep : w;
      const sh = Math.min(h * 0.28, 260 + rnd() * 160), sz0 = h * (0.35 + rnd() * 0.4);
      const sc = [HUE.magenta, HUE.cyan, HUE.gold, HUE.orange, HUE.green][Math.floor(rnd() * 5)];
      base.sign = { face, u0: len * 0.12, u1: len * 0.88, z0: sz0, z1: Math.min(h - 40, sz0 + sh), col: sc, seed: Math.floor(rnd() * 1000) };
      nSign++;
    }
    // v19.19 SHAPES: a fifth of the lattice is ROUND (a cylinder tower, cone-frustum setbacks) and a fifth of the box
    // towers wear a PYRAMID crown. The roll is a per-lot hash, OFF the rng stream, so every other roll below is unchanged.
    const shape = h2(i * 13 + j * 7, SEED + 99);
    const isRound = shape < 0.20 && !base.sign && h > 300 && !SKIP.has('round');
    let baseObj;
    if (isRound) { const r = Math.min(w, dep) / 2; baseObj = roundBody(cx, cy, 0, h, () => r, { hue, lit, d }); nRound++; }
    else baseObj = addBox(base);
    base.d = baseObj.d;                                                        // the tiers / crown / mast key off base.d (a round lot never went through addBox)
    nB++;
    // setback tiers: 1-2 shrinking boxes stacked on tall buildings
    if (h > 900 && rnd() < 0.42) {
      let bx = baseObj; const tiers = 1 + (rnd() < 0.4 ? 1 : 0);
      for (let k = 0; k < tiers; k++) {
        const sh = bx.z1 - bx.z0, ins = 0.12 + rnd() * 0.16;
        const nw = (bx.x1 - bx.x0) * (1 - 2 * ins), nd = (bx.y1 - bx.y0) * (1 - 2 * ins);
        if (isRound) {                                                                  // v19.19: a cone frustum, then a narrower drum
          const r0 = (bx.x1 - bx.x0) / 2, r1 = nw / 2, capH = Math.min(0.20 * r0, zCap - bx.z1);
          if (capH < 3) break;
          roundBody(cx, cy, bx.z1, capH, f => lerp(r0, r1, f), { hue, lit, d: base.d - 1.5 - k, capBot: false });
          const zs = bx.z1 + capH, th = Math.min(sh * (0.30 + rnd() * 0.35), zCap - zs);
          if (th < 40) break;
          bx = roundBody(cx, cy, zs, th, () => r1, { hue, lit, d: base.d - 1 - k });
          nTier++;
          continue;
        }
        const zs = setback(bx, nw, nd, hue, lit, base.d - 1 - k, zCap);               // v19.19: the step is a slope
        const th = Math.min(sh * (0.30 + rnd() * 0.35), zCap - zs);
        if (th < 40) break;
        bx = addBox({ x0: (bx.x0 + bx.x1) / 2 - nw / 2, x1: (bx.x0 + bx.x1) / 2 + nw / 2, y0: (bx.y0 + bx.y1) / 2 - nd / 2, y1: (bx.y0 + bx.y1) / 2 + nd / 2, z0: zs, z1: zs + th, hue, lit, d: base.d - 1 - k });
        nTier++;
      }
      base.top = bx;
    }
    // v19.19: a PYRAMID crown on a fifth of the untiered box towers
    if (!isRound && !base.top && shape >= 0.20 && shape < 0.40 && h > 700 && !SKIP.has('crown')) {
      const ch = Math.min(Math.min(w, dep) * 0.7, zCap - h);
      if (ch > 30) { base.top = hipCap(cx, cy, h, w, dep, w * 0.12, dep * 0.12, ch, { hue, lit: lit * 0.6, d: base.d - 1.5, capBot: false }); nCrown++; }
    }
    // antenna spire + beacon on the tallest
    const top = base.top || baseObj;
    if (top.z1 > 1500 && rnd() < 0.55) antennaOn(top, hue, base.d, zCap);
    else if (top.z1 > 1500 && rnd() < 0.5) items.push({ d: base.d - 3, draw: () => drawBeacon(top) });
  }
  rngState = (SEED * 2654435761) >>> 0 || 1;                                  // v18.87: fixed stream for the landmarks and everything after the lattice
  // LANDMARKS — one per quarter, each unmistakable
  {
    // the ziggurat: 7 shrinking tiers, gold, opposite the moon
    const a = SUN_AZ + Math.PI + 0.55, dz = 5200, cx = Math.cos(a) * dz, cy = Math.sin(a) * dz;
    let wdt = 1900, z = 0;
    // v19.19: each tier's ledge is a sloped gold band (a faceted pyramid, not a stair); the finial is a round taper
    for (let k = 0; k < 7; k++) { const th = 200 - k * 10; const bx = addBox({ x0: cx - wdt / 2, x1: cx + wdt / 2, y0: cy - wdt / 2, y1: cy + wdt / 2, z0: z, z1: z + th, hue: 'gold', lit: 0.5, refl: k === 0, d: dz - k }); z = setback(bx, wdt * 0.80, wdt * 0.80, 'gold', 0.5, dz - k, undefined, 0.16); wdt *= 0.80; }
    const cap = roundBody(cx, cy, z, 700, f => lerp(30, 6, f), { hue: 'gold', plain: true, d: dz - 8, capBot: false });
    items.push({ d: dz - 9, draw: () => drawBeacon(cap) });
  }
  {
    // the gate: two red towers and a beam across, on the moon side left
    const a = SUN_AZ - 0.95, dg = 4600, cx = Math.cos(a) * dg, cy = Math.sin(a) * dg;
    const px = -Math.sin(a), py = Math.cos(a);                          // perpendicular
    for (const sgn of [-1, 1]) {
      const tx = cx + px * sgn * 900, ty = cy + py * sgn * 900;
      addBox({ x0: tx - 170, x1: tx + 170, y0: ty - 170, y1: ty + 170, z0: 0, z1: 3400, hue: 'red', lit: 0.6, refl: true, d: dg });
    }
    const bx0 = Math.min(cx - px * 900, cx + px * 900) - 120, bx1 = Math.max(cx - px * 900, cx + px * 900) + 120;
    const by0 = Math.min(cy - py * 900, cy + py * 900) - 120, by1 = Math.max(cy - py * 900, cy + py * 900) + 120;
    addBox({ x0: bx0, x1: bx1, y0: by0, y1: by1, z0: 2900, z1: 3100, hue: 'red', lit: 0.2, d: dg - 2 });
  }
  {
    // the floating platform: a wide slab hanging in the air, violet, moon side right
    const a = SUN_AZ + 1.62, dp = 6200, cx = Math.cos(a) * dp, cy = Math.sin(a) * dp;
    addBox({ x0: cx - 1100, x1: cx + 1100, y0: cy - 700, y1: cy + 700, z0: 2300, z1: 2520, hue: 'violet', lit: 0.3, d: dp });
    addBox({ x0: cx - 380, x1: cx + 380, y0: cy - 260, y1: cy + 260, z0: 2520, z1: 3150, hue: 'violet', lit: 0.6, d: dp - 1 });
    const m = roundBody(cx, cy, 3150, 550, f => lerp(18, 4, f), { hue: 'violet', plain: true, d: dp - 2, capBot: false });   // v19.19: round taper
    items.push({ d: dp - 3, draw: () => drawBeacon(m) });
  }
  // THE FAR RING (v17.87) — megastructures 13k..30k: the city that keeps going. Two far downtowns cluster them.
  {
    const farClusters = [[SUN_AZ + 2.6, 19000, 5500, 1.7], [SUN_AZ - 1.3, 22000, 6500, 1.6]].map(([a, d, rad, m]) => ({ x: Math.cos(a) * d, y: Math.sin(a) * d, rad, m }));
    if (JSON.stringify(farClusters.map(c => [c.x, c.y, c.rad, c.m])) !== JSON.stringify(UG_FAR.map(([a, d, rad, m]) => [Math.cos(a) * d, Math.sin(a) * d, rad, m]))) throw new Error('UG_FAR no longer matches the far clusters (v19.69 lockstep)');
    for (let k = 0; k < 170 && !SKIP.has('far'); k++) {
      rngState = (hq(k, 1000 + SEED, 3) * 4294967295) >>> 0 || 1;           // v18.87: per-slot stream
      const az = rnd() * TAU, d = FAR_R0 + Math.pow(rnd(), 0.85) * (FAR_R1 - FAR_R0);
      const cx = Math.cos(az) * d, cy = Math.sin(az) * d;
      let mult = 1;
      for (const c of farClusters) { const dd = Math.hypot(cx - c.x, cy - c.y); if (dd < c.rad) mult = Math.max(mult, 1 + (c.m - 1) * smooth(1 - dd / c.rad)); }
      const hue = pickHue(), type = rnd();
      const elCap = EYE + d * Math.tan(40 * D2R);
      const lit = 0.3 + rnd() * 0.6;
      if (type < 0.45) {                                                  // MEGA-TOWER: 2-3 tiers + mast
        const w = 700 + rnd() * 800, dep = w * (0.7 + rnd() * 0.6);
        const h = Math.min((5000 + rnd() * 9000) * mult, elCap, laneCap(cx, cy, halfDiag(w, dep)));
        if (h < 400) continue;
        const base = { x0: cx - w / 2, x1: cx + w / 2, y0: cy - dep / 2, y1: cy + dep / 2, z0: 0, z1: h * 0.55, hue, lit };
        if (rnd() < 0.40) {                                               // v18.87: a MEGA-BILLBOARD — a holo glyph wall on the face toward the eye
          const face = Math.abs(cx) > Math.abs(cy) ? (cx > 0 ? 1 : 2) : (cy > 0 ? 3 : 4);
          const len = (face <= 2) ? dep : w, bh = h * 0.55, sz0 = bh * (0.30 + rnd() * 0.25), sh = bh * 0.28;
          const sc = [HUE.magenta, HUE.cyan, HUE.gold, HUE.violet][Math.floor(rnd() * 4)];
          base.sign = { face, u0: len * 0.10, u1: len * 0.90, z0: sz0, z1: sz0 + sh, col: sc, seed: Math.floor(rnd() * 1000), rows: 5, holo: true };
          nMega++;
        }
        const roundMega = !base.sign && h2(k, SEED + 5) < 0.35 && !SKIP.has('round');                      // v19.19: a third of the mega-towers are round drums
        let bx = roundMega ? roundBody(cx, cy, 0, h * 0.55, () => Math.min(w, dep) / 2, { hue, lit, d }) : addBox(base);
        if (roundMega) nRound++;
        const tiers = 1 + (rnd() < 0.6 ? 1 : 0);
        for (let q = 0; q < tiers; q++) {
          const ins = 0.12 + rnd() * 0.14, nw = (bx.x1 - bx.x0) * (1 - 2 * ins), nd = (bx.y1 - bx.y0) * (1 - 2 * ins);
          let zs;
          if (roundMega) { const r0 = (bx.x1 - bx.x0) / 2, capH = Math.min(0.20 * r0, h - bx.z1); if (capH < 3) break; roundBody(cx, cy, bx.z1, capH, f => lerp(r0, nw / 2, f), { hue, lit, d: d - 1.5 - q, capBot: false }); zs = bx.z1 + capH; }
          else zs = setback(bx, nw, nd, hue, lit, d - 1 - q, h);                     // v19.19: sloped setback
          const th = (h - zs) * (q === tiers - 1 ? 1 : 0.5 + rnd() * 0.3);
          if (th < 40) break;
          bx = roundMega ? roundBody(cx, cy, zs, th, () => nw / 2, { hue, lit, d: d - 1 - q })
                         : addBox({ x0: cx - nw / 2, x1: cx + nw / 2, y0: cy - nd / 2, y1: cy + nd / 2, z0: zs, z1: zs + th, hue, lit, d: d - 1 - q });
        }
        if (rnd() < 0.7) antennaOn(bx, hue, d, laneCap(cx, cy, halfDiag(w, dep))); else items.push({ d: d - 3, draw: () => drawBeacon(bx) });
        nFar++;
      } else if (type < 0.65) {                                           // ARCOLOGY: five shrinking tiers
        let wdt = 2600 + rnd() * 1600, z = 0;
        const cap = Math.min(elCap, laneCap(cx, cy, wdt / 2));
        const th0 = (800 + rnd() * 600) * mult;
        for (let q = 0; q < 5 && z < cap; q++) { const th = Math.min(th0 * (1 - q * 0.08), cap - z); const bx = addBox({ x0: cx - wdt / 2, x1: cx + wdt / 2, y0: cy - wdt / 2, y1: cy + wdt / 2, z0: z, z1: z + th, hue, lit: lit * 0.8, d: d - q }); z = setback(bx, wdt * 0.78, wdt * 0.78, hue, lit * 0.8, d - q, cap, 0.12); wdt *= 0.78; }   // v19.19: sloped flanks between the tiers
        if (h2(k, SEED + 6) < 0.5 && !SKIP.has('round')) { const rt = wdt / 0.78 / 2, dh = rt * 0.9; if (z + dh <= cap) { roundBody(cx, cy, z, dh, f => rt * Math.sqrt(Math.max(0, 1 - f * f)), { hue, lit: lit * 0.8, d: d - 6, capBot: false }); z += dh; nDome++; } }   // v19.19: a DOME on half the arcologies
        if ((z >= cap * 0.9 || rnd() < 0.5) && z + 500 <= cap) { const m = roundBody(cx, cy, z, 500, f => lerp(22, 5, f), { hue, plain: true, d: d - 7, capBot: false }); items.push({ d: d - 8, draw: () => drawBeacon(m) }); }
        nFar++;
      } else if (type < 0.85) {                                           // TWINS + sky-bridges
        const w = 550 + rnd() * 350, gapd = 1300 + rnd() * 600;
        const alongY = Math.abs(cx) > Math.abs(cy);                       // spread across the line of sight
        const h = Math.min((4500 + rnd() * 5000) * mult, elCap, laneCap(cx, cy, halfDiag(w + gapd, w)));
        if (h < 400) continue;
        for (const sgn of [-1, 1]) {
          const tx = cx + (alongY ? 0 : sgn * gapd / 2), ty = cy + (alongY ? sgn * gapd / 2 : 0);
          addBox({ x0: tx - w / 2, x1: tx + w / 2, y0: ty - w / 2, y1: ty + w / 2, z0: 0, z1: h, hue, lit, d });
          if (h * 1.14 <= elCap) spire(tx, ty, h, w * 0.9, h * 0.14, { hue, d: d - 0.5 });                      // v19.19: a concave spire on each twin
        }
        for (const f of [0.55, 0.86]) {
          const bz = h * f;
          addBox({ x0: cx - (alongY ? w * 0.35 : gapd / 2), x1: cx + (alongY ? w * 0.35 : gapd / 2), y0: cy - (alongY ? gapd / 2 : w * 0.35), y1: cy + (alongY ? gapd / 2 : w * 0.35), z0: bz, z1: bz + 140, hue, lit: 0.2, d: d - 2 });
        }
        const mid = { x0: cx - 20, x1: cx + 20, y0: cy - 20, y1: cy + 20, z1: h };
        items.push({ d: d - 3, draw: () => drawBeacon(mid) });
        nFar++;
      } else {                                                            // MEGABLOCK: a long wall of city
        const alongY = Math.abs(cx) > Math.abs(cy);
        const len = 3000 + rnd() * 2200, dep = 500 + rnd() * 300;
        const w = alongY ? dep : len, dp = alongY ? len : dep;
        const h = Math.min((2200 + rnd() * 2600) * mult, elCap, laneCap(cx, cy, halfDiag(w, dp)));
        if (h < 300) continue;
        const bx = addBox({ x0: cx - w / 2, x1: cx + w / 2, y0: cy - dp / 2, y1: cy + dp / 2, z0: 0, z1: h, hue, lit: lit * 0.9 });
        if (rnd() < 0.6) { const zs = setback(bx, w * 0.6, dp * 0.6, hue, lit * 0.9, bx.d - 1, elCap, 0.08); addBox({ x0: cx - w * 0.3, x1: cx + w * 0.3, y0: cy - dp * 0.3, y1: cy + dp * 0.3, z0: zs, z1: zs + h * 0.5, hue, lit, d: bx.d - 1 }); }   // v19.19: sloped shoulder
        nFar++;
      }
    }
  }
  rngState = (SEED * 40503 + 12345) >>> 0 || 1;                                // v18.87: fixed stream after the far ring
  // RING HIGHWAYS (v17.87): two elevated rings on pylons, the eye OUTSIDE each so each is a sweeping arc —
  // near rim high and bright, far rim low and hazed, one passing behind the gate towers.
  // v18.88 THE RAIL PASS: a third line — THE CROSSTOWN, a 30k-radius arc (reads straight) passing 2,600 south of the
  // eye at z 950 — trains and stations on every line, gantry cross-beams and a light on every pylon.
  const RINGS = [
    { cx: 5200, cy: -3000, R: 3600, z: 1500, hue: 'cyan', hue2: 'gold', thick: 12, deck: 64, nTrains: 2, nStations: 2 },
    { cx: -6600, cy: 5200, R: 4600, z: 2300, hue: 'magenta', hue2: 'cyan', thick: 12, deck: 64, nTrains: 2, nStations: 2 },
    { cx: 0, cy: -32600, R: 30000, z: 950, hue: 'gold', hue2: 'magenta', thick: 10, deck: 56, p0: Math.PI / 2 - 0.30, p1: Math.PI / 2 + 0.30, pylonStep: 720 / 30000, nTrains: 2, nStations: 2, ch: 40 },
  ];
  let nTrain = 0, nStation = 0;
  for (const rg of RINGS) {
    if (SKIP.has('rings')) break;
    const p0 = rg.p0 === undefined ? 0 : rg.p0, p1 = rg.p1 === undefined ? TAU : rg.p1, span = p1 - p0;
    rg.dashes = []; for (let k = 0; k < 14; k++) rg.dashes.push([p0 + rnd() * span, (0.012 + rnd() * 0.02) * Math.min(1, 3600 / rg.R)]);
    const carPitch = (190 + 22) / rg.R;
    // trains and stations sit on the NEAR rim (the ring angle facing the eye), where the line is big and bright — the
    // first placement scattered them round the circle and most landed on the hazed far rim behind the towers
    const nearPhi = rg.p0 === undefined ? Math.atan2(-rg.cy, -rg.cx) : (p0 + p1) / 2, nearK = Math.min(1, 3600 / rg.R);
    rg.trains = []; for (let k = 0; k < rg.nTrains; k++) { const nCars = 6 + Math.floor(rnd() * 3); rg.trains.push({ phi: nearPhi + (k === 0 ? -0.42 : 0.30) * nearK + (rnd() - 0.5) * 0.10 * nearK, nCars, len: nCars * carPitch, dir: k === 0 ? 1 : -1, seed: Math.floor(rnd() * 1000) }); nTrain++; }
    rg.stations = []; for (let k = 0; k < rg.nStations; k++) { rg.stations.push({ phi: nearPhi + (k === 0 ? -0.06 : 0.78) * nearK + (rnd() - 0.5) * 0.06 * nearK, half: 420 / rg.R, seed: Math.floor(rnd() * 1000) }); nStation++; }
    for (const tr of rg.trains) { const pm = tr.phi + tr.dir * tr.len / 2, X = rg.cx + rg.R * Math.cos(pm), Y = rg.cy + rg.R * Math.sin(pm), dd = Math.hypot(X, Y); (globalThis.RAIL_VIEWS = globalThis.RAIL_VIEWS || []).push([`view_train_${globalThis.RAIL_VIEWS.length}`, Math.atan2(Y, X), Math.atan((rg.z - EYE) / dd) / D2R]); }
    for (const st of rg.stations) { const X = rg.cx + rg.R * Math.cos(st.phi), Y = rg.cy + rg.R * Math.sin(st.phi), dd = Math.hypot(X, Y); (globalThis.RAIL_VIEWS = globalThis.RAIL_VIEWS || []).push([`view_station_${globalThis.RAIL_VIEWS.length}`, Math.atan2(Y, X), Math.atan((rg.z - EYE) / dd) / D2R]); }
    const CH = rg.ch || 96;
    for (let k = 0; k < CH; k++) {
      const q0 = p0 + span * k / CH, q1 = p0 + span * (k + 1) / CH, pm = (q0 + q1) / 2;
      const dm = Math.hypot(rg.cx + rg.R * Math.cos(pm), rg.cy + rg.R * Math.sin(pm));
      items.push({ d: dm, draw: () => drawRingChunk(rg, q0, q1) });
    }
    const step = rg.pylonStep || TAU / 30;
    for (let ph = p0; ph < p1 - 1e-9; ph += step) {                       // pylons: every 12 degrees of a ring, every 720 units of the crosstown
      const X = rg.cx + rg.R * Math.cos(ph), Y = rg.cy + rg.R * Math.sin(ph), dp = Math.hypot(X, Y);
      if (dp < INNER_R) continue;
      const zTop = rg.z - rg.deck - RAIL_GIRDER;                                                                                                            // v18.89: the pylon meets the girder's chord
      addBox({ x0: X - 22, x1: X + 22, y0: Y - 22, y1: Y + 22, z0: 0, z1: zTop, hue: rg.hue, lit: 0 });                                                     // v18.89: gridded like the towers (was plain)
      addBox({ x0: X - 64, x1: X + 64, y0: Y - 64, y1: Y + 64, z0: zTop - 26, z1: zTop, hue: rg.hue, lit: 0, plain: true, d: dp - 0.5 });                 // v18.88: the pylon head (a 300-square plate read as a lamp shade on the first preview)
      const bc = mix3(HUE[rg.hue], [1, 1, 1], 0.35);
      items.push({ d: dp - 1, draw: () => drawBeaconAt(X, Y, zTop - 40, bc) });                                                                     // v18.88: a pylon light
    }
  }
  // HOLOGRAPHIC PANELS (v17.87): translucent glyph screens floating over the mid-rise roofs
  for (let k = 0; k < 40 && nHolo < 9 && !SKIP.has('holo'); k++) {
    const az = rnd() * TAU, d = 2600 + rnd() * 2800;
    if (inLane(az, 0.12)) continue;
    const cx = Math.cos(az) * d, cy = Math.sin(az) * d;
    const alongY = Math.abs(cx) > Math.abs(cy);                          // the plane faces the eye
    const wdt = 600 + rnd() * 500, hgt = 320 + rnd() * 300, z0 = 1900 + rnd() * 1000;
    const hue = rnd() < 0.5 ? 'cyan' : rnd() < 0.5 ? 'magenta' : 'green';
    items.push({ d, draw: () => drawHolo(alongY ? { axis: 'x', pos: cx, u0: cy - wdt / 2, u1: cy + wdt / 2, z0, z1: z0 + hgt, hue, seed: Math.floor(rnd() * 1000) }
                                            : { axis: 'y', pos: cy, u0: cx - wdt / 2, u1: cx + wdt / 2, z0, z1: z0 + hgt, hue, seed: Math.floor(rnd() * 1000) }) });
    nHolo++;
  }
  // SEARCHLIGHTS (v17.87): beams from the tallest roofs near and far, alternating lean
  {
    const tallest = boxes.filter(b => !b.plain && b.z1 > 1400).sort((a, b) => (b.z1 / Math.pow(b.d, 0.6)) - (a.z1 / Math.pow(a.d, 0.6)));
    const used = [];
    for (const b of tallest) {
      if (nBeam >= 7) break;
      const cx = (b.x0 + b.x1) / 2, cy = (b.y0 + b.y1) / 2, az = Math.atan2(cy, cx);
      if (used.some(u => Math.abs(wrapAz(u - az)) < 0.28) || inLane(az, 0.1)) continue;
      used.push(az);
      const el = Math.atan((b.z1 - EYE) / b.d);
      const px = az / TAU * W, py = rowOfEl(el);
      const lean = (nBeam % 2 ? 1 : -1) * (0.12 + rnd() * 0.30);
      const len = (90 + rnd() * 160) * PX * 4 * (0.5 + 0.5 * lightFogOf(b.d));   // render px (pure multiple of PX: scales with --ss by itself)
      const col = rnd() < 0.5 ? [0.75, 0.90, 1.0] : rnd() < 0.5 ? [1.0, 0.75, 0.95] : [1.0, 0.95, 0.85];
      if (SKIP.has('beams')) break;
      items.push({ d: b.d - 5, draw: () => drawBeam({ px, py, ang: lean, len, col, k: 0.35 + 0.65 * lightFogOf(b.d), depth: b.d - 5, d: b.d, roof: b.z1 }) });   // v19.69: d + roof for the cloud hit
      nBeam++;
    }
  }
  // v19.69 ROOFTOP PLUMES — a dozen exposed mid-city roofs (no tier or crown standing on them), spread round the
  // horizon, out of the composition lanes. Picked by a per-box HASH, never the rng stream, so nothing else moves.
  if (!SKIP.has('plumes')) {
    const covered = (b) => boxes.some(o => o !== b && Math.abs(o.z0 - b.z1) < 2 && o.x0 < b.x1 && o.x1 > b.x0 && o.y0 < b.y1 && o.y1 > b.y0);
    const elTop = o => Math.atan((o.z1 - EYE) / Math.max(50, o.d - halfDiag(o.x1 - o.x0, o.y1 - o.y0)));
    const hidden = (b, h) => {                                        // a nearer tower standing over half the plume's height
      const az0 = Math.atan2((b.y0 + b.y1) / 2, (b.x0 + b.x1) / 2), need = Math.atan((b.z1 + 0.5 * h - EYE) / b.d), half = Math.atan2(h * 0.35, b.d);
      return boxes.some(o => o.d < b.d - 150 && !o.plain && elTop(o) > need && Math.abs(wrapAz(Math.atan2((o.y0 + o.y1) / 2, (o.x0 + o.x1) / 2) - az0)) < half + Math.atan2(halfDiag(o.x1 - o.x0, o.y1 - o.y0), o.d));
    };
    const cand = boxes.filter(b => !b.plain && b.z1 >= 380 && b.z1 <= 2300 && b.d >= 1500 && b.d <= 6000 && (b.x1 - b.x0) >= 180 && (b.y1 - b.y0) >= 180)
      .map(b => ({ b, k: hq(Math.round(b.x0), Math.round(b.y0), SEED + 4242) }))
      .sort((p, q) => p.k - q.k);
    const used = [];
    let nPlume = 0;
    for (const { b, k } of cand) {
      if (nPlume >= 12) break;
      const cx = (b.x0 + b.x1) / 2, cy = (b.y0 + b.y1) / 2, az = Math.atan2(cy, cx);
      const h = 700 + 900 * hq(nPlume, 77, SEED);
      if (inLane(az, 0.08) || used.some(u => Math.abs(wrapAz(u - az)) < 0.34) || covered(b) || hidden(b, h)) continue;
      used.push(az);
      const p = { x: cx, y: cy, z: b.z1, d: b.d, hue: b.hue, h, w0: Math.min(b.x1 - b.x0, b.y1 - b.y0) * 0.22, seed: Math.floor(k * 1000) % 97 };
      items.push({ d: b.d - 2, draw: () => drawPlume(p) });
      if (process.env.TOD_SKY_PLUMEDBG) console.log(`    plume ${nPlume}: az ${(az / D2R).toFixed(1)} d ${p.d.toFixed(0)} roof ${p.z.toFixed(0)} h ${p.h.toFixed(0)} el ${(Math.atan((p.z - EYE) / p.d) / D2R).toFixed(1)}..${(Math.atan((p.z + p.h - EYE) / p.d) / D2R).toFixed(1)} hue ${p.hue}`);
      nPlume++;
    }
    console.log(`  plumes: ${nPlume} rooftop plumes (${cand.length} candidate roofs)`);
  }
  // TRAFFIC — light-trails along the avenues (every 4th lattice line) at two heights, plus AIR LANES (v17.87)
  for (let k = -8; k <= 8; k++) {
    const pos = k * 4 * LOT + LOT / 2;
    for (const axis of ['x', 'y']) for (let n = 0; n < 3; n++) {
      const hue = rnd() < 0.5 ? 'cyan' : rnd() < 0.5 ? 'red' : 'gold';
      const len = 900 + rnd() * 2600, start = (rnd() - 0.5) * 2 * CITY_R * 0.8;
      const dir = rnd() < 0.5 ? 1 : -1;
      const t0 = start, t1 = start + dir * len;
      const near = Math.max(INNER_R, Math.min(Math.abs(t0), Math.abs(t1)));
      const dd = Math.hypot(pos, near);
      if (dd > CITY_R * 0.8 || Math.abs(pos) < 900 || dd < 1600) continue;   // v17.87: the k=0 avenue passed 210 from the eye and swept the sky
      const z = 380 + rnd() * 900;
      items.push({ d: dd, draw: () => drawStreak({ axis, pos, t0, t1, z, hue }) }); nSt++;
    }
  }
  for (let k = 0; k < 60 && nAir < 30 && !SKIP.has('air'); k++) {
    const axis = rnd() < 0.5 ? 'x' : 'y', pos = (rnd() - 0.5) * 2 * 9000, start = (rnd() - 0.5) * 2 * 9000;
    const dd0 = Math.hypot(pos, start);
    if (dd0 < 2200 || dd0 > 11000) continue;
    const len = Math.min(160 + rnd() * 380, dd0 * 0.045), dir = rnd() < 0.5 ? 1 : -1, t0 = start, t1 = start + dir * len;   // <= ~2.6 degrees long
    const dd = dd0;
    const z = 1800 + rnd() * 2600;
    const hue = rnd() < 0.6 ? 'cyan' : rnd() < 0.5 ? 'magenta' : 'gold';
    items.push({ d: dd, draw: () => drawStreak({ axis, pos, t0, t1, z, hue, head: true }) }); nAir++;
  }
  // v18.87 CYBER ART: the tether's anchor (a far-ring megastructure at TETHER.d), the airships, the storm bolt
  if (!SKIP.has('tether')) {
    const cx = Math.cos(TETHER.az) * TETHER.d, cy = Math.sin(TETHER.az) * TETHER.d, hA = TETHER.anchorH;
    const b0 = addBox({ x0: cx - 620, x1: cx + 620, y0: cy - 620, y1: cy + 620, z0: 0, z1: hA * 0.45, hue: 'cyan', lit: 0.7, d: TETHER.d });
    const z1 = setback(b0, 760, 760, 'cyan', 0.7, TETHER.d - 1, undefined, 0.12);                                  // v19.19: sloped setbacks
    const b1 = addBox({ x0: cx - 380, x1: cx + 380, y0: cy - 380, y1: cy + 380, z0: z1, z1: hA * 0.78, hue: 'cyan', lit: 0.6, d: TETHER.d - 1 });
    const z2 = setback(b1, 360, 360, 'cyan', 0.6, TETHER.d - 2, undefined, 0.12);
    addBox({ x0: cx - 180, x1: cx + 180, y0: cy - 180, y1: cy + 180, z0: z2, z1: hA, hue: 'cyan', lit: 0.4, d: TETHER.d - 2 });
    for (const sgn of [-1, 1]) addBox({ x0: cx - 900, x1: cx + 900, y0: cy + sgn * 700 - 90, y1: cy + sgn * 700 + 90, z0: hA * 0.40, z1: hA * 0.46, hue: 'cyan', lit: 0.2, d: TETHER.d - 3 });
  }
  if (T.ships > 0 && !SKIP.has('ships')) for (const sh of SHIP_DEFS) { items.push({ d: sh.d, draw: () => drawAirship(sh) }); nShip++; }
  if (T.storm > 0 && !SKIP.has('storm')) items.push({ d: 9000, draw: () => drawBolt({ az: SUN_AZ + STORM_AZ_OFF + 0.02, el0: 14.2 * D2R, el1: 6.4 * D2R, d: 9000 }) });
  items.sort((a, b) => b.d - a.d);
  console.log(`  city: ${nB} blocks, ${nTier} setback tiers, ${nAnt} antennas, ${nSign} billboards, ${nFar} far megastructures (${nMega} mega-billboards), ${RINGS.length} rail lines (${nTrain} trains, ${nStation} stations), ${nHolo} holo panels, ${nBeam} searchlights, ${nSt} street trails, ${nAir} air lanes, ${nShip} airships, 3 landmarks + the tether anchor, ${nSolid} smooth solids (${nRound} round towers, ${nCrown} pyramid crowns, ${nDome} domes)`);
})();
// the light-pollution profile: blur the accumulated bearing weights and normalise round 1
(() => {
  const tmp = new Float64Array(GLOW_BINS);
  let mean = 0; for (let i = 0; i < GLOW_BINS; i++) mean += GLOW_RAW[i]; mean /= GLOW_BINS;
  for (let i = 0; i < GLOW_BINS; i++) { let s = 0, n = 0; for (let k = -24; k <= 24; k++) { const wgt = Math.exp(-k * k / (2 * 9 * 9)); s += GLOW_RAW[(i + k + GLOW_BINS) % GLOW_BINS] * wgt; n += wgt; } tmp[i] = s / n / Math.max(mean, 1e-9); }
  for (let i = 0; i < GLOW_BINS; i++) GLOW_AZ[i] = clamp(0.40 + 0.60 * tmp[i], 0.35, 1.75);
})();
// v18.87: the moon shafts' ray pattern — periodic value noise round the moon (three octaves of sectors)
const SHAFT_N = 720, SHAFT_TAB = (() => { const t = new Float32Array(SHAFT_N); for (let i = 0; i < SHAFT_N; i++) { let s = 0, nn = 0; for (const [k, a] of [[14, 1.0], [28, 0.6], [56, 0.35], [112, 0.2]]) { const f = i / SHAFT_N * k, j = Math.floor(f), tt = smooth(f - j); s += lerp(h2(j % k, 77 + k), h2((j + 1) % k, 77 + k), tt) * a; nn += a; } t[i] = s / nn; } return t; })();
const shaftAt = phi => { const f = (((phi / TAU) % 1) + 1) % 1 * SHAFT_N, i = Math.floor(f) % SHAFT_N; return lerp(SHAFT_TAB[i], SHAFT_TAB[(i + 1) % SHAFT_N], f - Math.floor(f)); };
const STORM_AZ = SUN_AZ + STORM_AZ_OFF, STORM_EL = 16 * D2R;   // the cell sits over the mid city (deck range ~9k), big enough to read: sigma 0.10 rad
// the skyline profile (per column, radians) — for the body clearance print
const SKYLINE = new Float32Array(W).fill(-1);
for (const o of boxes) {
  const [c0, c1] = azSpan(o);
  const dNear = Math.max(50, o.d - halfDiag(o.x1 - o.x0, o.y1 - o.y0));
  const te = Math.atan((o.z1 - EYE) / dNear);
  for (let xx = c0; xx <= c1; xx++) { const x = ((xx % W) + W) % W; if (te > SKYLINE[x]) SKYLINE[x] = te; }
}
for (const bd of BODIES) {
  const halfAng = (bd.kind === 'hole' ? 1.6 : (bd.ring ? bd.ring.outer : 1.05)) * bd.r / bd.cosEl;
  const c0 = Math.floor((bd.az - halfAng) / TAU * W), c1 = Math.ceil((bd.az + halfAng) / TAU * W);
  let mx = -1; for (let xx = c0; xx <= c1; xx++) mx = Math.max(mx, SKYLINE[((xx % W) + W) % W]);
  const bottom = bd.elR - (bd.ring ? bd.ring.tilt * bd.ring.outer * bd.r : bd.r);
  const gap = (bottom - mx) / D2R;
  console.log(`  body ${bd.name.padEnd(10)} el ${bd.el}° r ${(bd.r / D2R).toFixed(1)}° — skyline under it ${(mx / D2R).toFixed(1)}°: ${gap >= 0 ? `clear by ${gap.toFixed(1)}°` : `the skyline covers its lower ${(-gap).toFixed(1)}°${bd.name === 'giant' ? ' (intended: it rises behind the city)' : ' <-- CHECK'}`}`);
}
console.log(`  geometry ${((Date.now() - t0) / 1000).toFixed(1)}s`);

// ---------------------------------------------------------------- 1. sky, moon, stars, bodies, glow, clouds, ground
(() => {
  const tS = Date.now();
  const STAR_CELL = Math.max(6, Math.round(W / 300));
  const SCX = Math.ceil(W / STAR_CELL);
  const GROUND = [0.010, 0.012, 0.045], GLINE = [0.22, 0.95, 1.00], GLINE5 = [1.00, 0.30, 0.85];
  const elAnchor = Math.atan((TETHER.anchorH - EYE) / TETHER.d), tetherLF = lightFogOf(TETHER.d), tetherHW = (0.8 * PXO + 0.45) * SS * (TAU / W);
  for (let y = 0; y < H; y++) {
    const el = elOfRow(y);
    const t = clamp(el / (Math.PI / 2), 0, 1);
    const cosEl = Math.max(0.02, Math.cos(el));
    for (let x = 0; x < W; x++) {
      const az = azOfCol(x);
      const daz = wrapAz(az - SUN_AZ);
      const sunSide = 0.5 + 0.5 * Math.cos(daz);
      const c = Math.cos(az), s = Math.sin(az);
      let r, g, b;
      if (el >= 0) {
        [r, g, b] = skyGrad(el, sunSide);
        // GRAVITATIONAL LENSING (v17.87): where the background is READ from. A source at angle beta from a
        // hole appears at theta = (beta + sqrt(beta^2 + 4 thetaE^2)) / 2, so the pixel at theta shows the
        // sky at beta = theta - thetaE^2 / theta — stars smear into arcs, the ring inside thetaE is the
        // mirrored inner image, the nebula swirls. Nothing else in the sky changes.
        let laz = az, lel = el;
        for (const hd of HOLES) {
          const sdx = wrapAz(az - hd.az) * hd.cosEl / hd.r, sdy = (el - hd.elR) / hd.r, sdd = Math.hypot(sdx, sdy);
          if (sdd > 5.0 || sdd < 1e-4) continue;
          const k = clamp((sdd - hd.lens * hd.lens / sdd) / sdd, -2.5, 1);
          laz = hd.az + wrapAz(laz - hd.az) * k; lel = hd.elR + (lel - hd.elR) * k;
        }
        const lx = (((laz / TAU * W) % W) + W) % W, ly = clamp(rowOfEl(lel) + 0.5, 0, H - 1e-3);   // lensed pixel-centre coords
        const lt = clamp(lel / (Math.PI / 2), 0, 1), lcos = Math.max(0.02, Math.cos(lel));
        // two-tone nebula + FILAMENTS and DUST LANES (v17.87) from the fine map
        const nA = noise(NOISE_A, lx, ly) - 0.5, nB = Math.max(0, noise(NOISE_B, lx + W / 3, ly) - 0.58) * 2.4;
        const hz = clamp(1 - lt * 1.4, 0, 1) * 0.6 + 0.25;
        r += nA * T.nebulaA[0] * hz * 2 + nB * T.nebulaB[0]; g += nA * T.nebulaA[1] * hz * 2 + nB * T.nebulaB[1]; b += nA * T.nebulaA[2] * hz * 2 + nB * T.nebulaB[2];
        if (T.nebDust > 0 || T.nebFil > 0) {
          const nC = noise(NOISE_C, lx, ly * 1.3);                 // never scale the x (wrapping) argument — it breaks the period
          const dust = smooth(clamp((0.40 - nC) / 0.10, 0, 1)) * T.nebDust * smooth(clamp((lt - 0.05) / 0.2, 0, 1));
          const fil = Math.pow(Math.max(0, nC - 0.54) * 2.2, 1.6) * T.nebFil * (0.4 + 0.6 * nB);
          r = r * (1 - dust) + fil * T.nebFilCol[0]; g = g * (1 - dust) + fil * T.nebFilCol[1]; b = b * (1 - dust) + fil * T.nebFilCol[2];
          // v18.87 DETAIL: fine grain inside the nebula (the 2x paint can carry it) — where there is nebula, never on the plain dark
          const grain = (noise(NOISE_D, lx, ly) - 0.5) * (0.35 + nB * 1.6 + fil * 6) * 0.040 * smooth(clamp((lt - 0.06) / 0.25, 0, 1));
          r += grain * (T.nebulaA[0] + T.nebulaB[0]) * 4; g += grain * (T.nebulaA[1] + T.nebulaB[1]) * 4; b += grain * (T.nebulaA[2] + T.nebulaB[2]) * 4;
        }
        // milky way band (lensed direction)
        let mw = 0;
        if (T.milky > 0) {
          const dx = lcos * Math.cos(laz), dy = lcos * Math.sin(laz), dz = Math.sin(lel);
          const dot = dx * MW_N[0] + dy * MW_N[1] + dz * MW_N[2];
          mw = Math.exp(-(dot * dot) / (2 * 0.11 * 0.11)) * (0.55 + 0.9 * noise(NOISE_B, lx, ly * 1.7)) * smooth(clamp(lt / 0.25, 0, 1));
          r += mw * T.milky * 0.9; g += mw * T.milky * 0.85; b += mw * T.milky * 1.25;
        }
        // horizon band (thin; the glow dome below carries the body of it)
        const hb = Math.exp(-(el * el) / (2 * Math.pow(1.6 * D2R, 2)));
        r += hb * T.horBand[0]; g += hb * T.horBand[1]; b += hb * T.horBand[2];
        // bloom round the disc
        const sd = Math.hypot(daz, (el - SUN_EL) * 1.15);
        const bloom = Math.exp(-sd * sd / T.bloomWideR) * T.bloomWide + Math.exp(-sd * sd / T.bloomTightR) * T.bloomTight;
        r += bloom * T.bloomCol[0]; g += bloom * T.bloomCol[1]; b += bloom * T.bloomCol[2];
        // stars — round on the sphere: pixel dx is scaled by cos(el), density thinned by cos(el); read at the LENSED position
        if (lt > 0.06) {
          const cx = Math.floor(lx / STAR_CELL), cy = Math.floor(ly / STAR_CELL);
          let sv = 0, sc = null;
          const thresh = T.starThresh - mw * 0.18;
          for (let j = -1; j <= 1; j++) for (let i = -2; i <= 2; i++) {
            const ccx = ((cx + i) % SCX + SCX) % SCX, ccy = cy + j;
            const hh = h2(ccx, ccy);
            if (hh < thresh || h2(ccx + 3, ccy + 5) > lcos) continue;
            const sx = (ccx + h2(ccx, ccy + 99)) * STAR_CELL, sy = (ccy + h2(ccx + 99, ccy)) * STAR_CELL;
            const rad = (0.45 + Math.pow(h2(ccx + 7, ccy + 3), 8) * 2.6) * (0.6 + 0.4 * LW / SS) * SS;   // the approved FINAL radius x SS
            let ddx = lx - sx; if (ddx > W / 2) ddx -= W; if (ddx < -W / 2) ddx += W;
            ddx *= lcos;
            const ddy = ly - sy;
            const d = Math.hypot(ddx, ddy);
            let v = 0;
            if (d < rad + SS) v = clamp((rad + 0.6 * SS - d) / SS, 0, 1);
            if (rad > 1.7 * SS && v < 1) {      // glints on the bright ones
              const ax = Math.abs(ddx), ay = Math.abs(ddy), L = rad * 3.2;
              if ((ax < 0.7 * SS && ay < L) || (ay < 0.7 * SS && ax < L)) v = Math.max(v, 0.6 * (1 - Math.max(ax, ay) / L));
            }
            if (v > sv) {
              sv = v * (0.35 + 0.65 * h2(ccx + 1, ccy + 1));
              const ch = h2(ccx + 11, ccy + 13);
              sc = ch < 0.6 ? [1, 1, 1] : ch < 0.85 ? [0.78, 0.88, 1.0] : [1.0, 0.88, 0.72];
            }
          }
          if (sv > 0) {
            const fade = smooth(clamp((lt - 0.06) / 0.30, 0, 1)) * (1 - bloom * 1.5);
            const v = sv * Math.max(0, fade);
            r += v * sc[0]; g += v * sc[1]; b += v * sc[2];
            if (v > 0.8) emit(x, y, sc[0], sc[1], sc[2], v * 0.12);
          }
        }
        // THE MOON / THE SUN
        const sdx = daz / SUN_R, sdy = (el - SUN_EL) / SUN_R;
        const sdd = Math.hypot(sdx, sdy);
        if (T.moon) {
          if (sdd < 1.0) {
            const v = (sdy + 1) / 2;
            const sc = v > 0.5 ? mix3(T.sunMid, T.sunTop, (v - 0.5) / 0.5) : mix3(T.sunBot, T.sunMid, v / 0.5);
            const cn = noise(NOISE_B, (sdx + 1) * W * 0.06, (sdy + 1) * H * 0.12);
            const crater = Math.max(0, cn - 0.5) * 0.9;
            const limb = 1 - 0.28 * sdd * sdd;
            const edge = clamp((1 - sdd) / 0.03, 0, 1);
            const k = (1 - crater) * limb;
            r = lerp(r, sc[0] * 1.10 * k, edge); g = lerp(g, sc[1] * 1.10 * k, edge); b = lerp(b, sc[2] * 1.10 * k, edge);
            if ((x & 3) === 0 && (y & 3) === 0) emit(x, y, sc[0], sc[1], sc[2], 0.7);
          } else if (sdd < 2.6) {
            const halo = Math.exp(-Math.pow(sdd - 1.55, 2) / 0.12) * 0.07;
            r += halo * 0.8; g += halo * 0.9; b += halo * 1.1;
          }
        } else if (sdd < 1.0) {
          const v = (sdy + 1) / 2;
          const sc = v > 0.5 ? mix3(T.sunMid, T.sunTop, (v - 0.5) / 0.5) : mix3(T.sunBot, T.sunMid, v / 0.5);
          let slot = 1;
          if (v < 0.62) { const ph = (v / 0.62) * 12, fr = ph - Math.floor(ph); slot = fr < (0.55 - v * 0.7) ? 0 : 1; }
          const edge = clamp((1 - sdd) / 0.04, 0, 1);
          if (slot) { r = lerp(r, sc[0] * 1.15, edge); g = lerp(g, sc[1] * 1.15, edge); b = lerp(b, sc[2] * 1.15, edge); if ((x & 3) === 0 && (y & 3) === 0) emit(x, y, sc[0], sc[1], sc[2], 0.9); }
        }
        // PLANETS + BLACK HOLES (§1b) — over the stars and the moon halo, under the glow, the aurora and the clouds
        for (const bd of BODIES) {
          const bdx = wrapAz(az - bd.az) * bd.cosEl / bd.r, bdy = (el - bd.elR) / bd.r;
          const bdd = Math.hypot(bdx, bdy);
          if (bdd > bd.reach) continue;
          const o = bd.kind === 'hole' ? shadeHole(bd, bdx, bdy, bdd, r, g, b, x, y) : shadePlanet(bd, bdx, bdy, bdd, r, g, b, x, y);
          r = o[0]; g = o[1]; b = o[2];
        }
        // THE ORBITAL TETHER (v18.87) — a cable from the anchor tower's top toward the zenith, climber lights up it, a
        // station at TETHER.stationEl; it fades out above 70 deg (at the pole every column converges, so it must end
        // before the top rows) and the glow dome, the clouds and the strata all pass in front of it
        if (!SKIP.has('tether') && el > elAnchor - 0.3 * D2R && el < 86 * D2R) {
          const tdx = wrapAz(az - TETHER.az) * cosEl;
          const cov = clamp(1 - Math.abs(tdx) / tetherHW, 0, 1);
          const hiFade = 1 - smooth(clamp((el - 66 * D2R) / (18 * D2R), 0, 1));
          if (cov > 0) {
            const I = cov * (0.30 + 0.70 * Math.exp(-(el - elAnchor) / (30 * D2R))) * (0.35 + 0.65 * tetherLF) * hiFade;
            const climber = Math.exp(-Math.pow((((el - elAnchor) / (2.4 * D2R)) % 1 + 1) % 1 - 0.5, 2) / (2 * 0.06 * 0.06));
            r = lerp(r, TETHER.col[0] * (0.55 + 0.9 * climber), I * 0.9); g = lerp(g, TETHER.col[1] * (0.55 + 0.9 * climber), I * 0.9); b = lerp(b, TETHER.col[2] * (0.55 + 0.9 * climber), I * 0.9);
            if (climber > 0.5 && I > 0.3) emit(x, y, TETHER.col[0], TETHER.col[1], TETHER.col[2], I * climber * 0.5);
          }
          // the station: a hub with a ring of lights and two counterweight arms, 1.6 deg across
          const sdy = (el - TETHER.stationEl) / (0.55 * D2R), sdx = tdx / (0.55 * D2R), sd = Math.hypot(sdx, sdy);
          if (sd < 1.8) {
            const hubA = smooth(clamp((0.55 - sd) / 0.12, 0, 1)) * 0.95;
            const ringA = clamp(1 - Math.abs(sd - 1.05) / 0.10, 0, 1) * 0.85;
            const armA = (Math.abs(sdy) < 0.09 && Math.abs(sdx) < 1.7) ? 0.75 : 0;
            const lampA = (ringA > 0.4 && h2(Math.floor(Math.atan2(sdy, sdx) / TAU * 16 + 16), 55) > 0.35) ? 1 : 0;
            const dark = mix3([0.02, 0.02, 0.05], skyGrad(el, sunSide), 0.35);
            const aa = Math.max(hubA, armA);
            if (aa > 0) { r = lerp(r, dark[0], aa); g = lerp(g, dark[1], aa); b = lerp(b, dark[2], aa); }
            const lit = Math.max(ringA * (0.45 + 0.55 * lampA), hubA * clamp(1 - Math.abs(sd - 0.5) / 0.1, 0, 1) * 0.9);
            if (lit > 0) { r = lerp(r, TETHER.col[0] * 1.2, lit * 0.9); g = lerp(g, TETHER.col[1] * 1.2, lit * 0.9); b = lerp(b, TETHER.col[2] * 1.2, lit * 0.9); if (lit > 0.5) emit(x, y, TETHER.col[0], TETHER.col[1], TETHER.col[2], lit * 0.4); }
          }
        }
        // THE LIGHT-POLLUTION DOME (v17.87) — smog lit from below, following the skyline; veils whatever sits low
        const gd = glowDome(az, el);
        if (gd) { const smog = 0.78 + 0.44 * noise(NOISE_A, x + W / 7, y * 2.5); r += gd[0] * smog; g += gd[1] * smog; b += gd[2] * smog; }
        // AURORA — curtains opposite the moon, green at the foot fading violet upward
        if (T.aurora > 0) {
          const d = wrapAz(az - AUR_AZ);
          if (Math.abs(d) < 1.25 && el > 12 * D2R && el < 52 * D2R) {
            const span = smooth(clamp((1.25 - Math.abs(d)) / 0.45, 0, 1));
            const u = (d + 1.25) / 2.5;                                            // 0..1 across the band
            const curtain = Math.pow(noise(NOISE_A, u * W * 0.55, (40 + 30 * Math.sin(u * 19)) * PX), 1.5);   // v18.87: the table row keys on the render scale, so every width reads the same curtain
            const wave = Math.sin(u * 23 + Math.cos(u * 7) * 2) * 3 * D2R;
            const foot = 17 * D2R + wave, vv = clamp((el - foot) / (32 * D2R), 0, 1);
            const vert = Math.pow(1 - vv, 1.6) * smooth(clamp((el - foot + 2 * D2R) / (3 * D2R), 0, 1));
            const a = T.aurora * span * curtain * vert;
            const col = mix3([0.15, 1.0, 0.55], [0.55, 0.25, 1.0], vv);
            r += a * col[0]; g += a * col[1]; b += a * col[2];
          }
        }
        // CLOUDS (v17.87) — two decks on real planes above the eye: foreshortened toward the horizon, the low deck
        // lit from below by the city and silvered near the moon, the cirrus thin and moonlit; both in front of the bodies
        if (el > 0.8 * D2R) {
          const hf = smooth(clamp((el - 0.8 * D2R) / (3.2 * D2R), 0, 1));
          const msd = Math.hypot(daz * cosEl, el - SUN_EL);
          const moonK = T.moon ? Math.exp(-msd * msd / (2 * 0.30 * 0.30)) : Math.exp(-msd * msd / (2 * 0.5 * 0.5));
          // MOON SHAFTS (v18.87 ATMOSPHERE) — crepuscular rays from the moon, scattered in the air UNDER the low deck
          // where the deck has a gap toward the moon (the deck is sampled 45% of the way from this pixel to the disc);
          // a periodic ray pattern round the disc, fading with angle; behind the clouds, in front of the bodies
          if (T.shafts > 0 && !SKIP.has('shafts') && msd > SUN_R * 1.12 && msd < 0.80) {
            const phi = Math.atan2(el - SUN_EL, daz * cosEl);
            const gaz = SUN_AZ + daz * 0.45, gel = Math.max(SUN_EL + (el - SUN_EL) * 0.45, 1.5 * D2R);
            const gtt = CLOUD_LOW_Z / Math.tan(gel), gX = Math.cos(gaz) * gtt, gY = Math.sin(gaz) * gtt;
            const gdn = fbm2(gX / 2300 + 3.7, gY / 2300 - 1.9, 101, 3);
            const gap = 1 - smooth(clamp((gdn - 0.50) / 0.22, 0, 1));
            const I = T.shafts * Math.exp(-msd / 0.28) * smooth(clamp((msd - SUN_R * 1.12) / 0.05, 0, 1)) * Math.pow(Math.max(0, (shaftAt(phi) - 0.38) / 0.62), 1.5) * (0.20 + 0.80 * gap) * hf;
            r += I * T.shaftCol[0]; g += I * T.shaftCol[1]; b += I * T.shaftCol[2];
          }
          {
            const tt = CLOUD_LOW_Z / Math.tan(el), X = Math.cos(az) * tt, Y = Math.sin(az) * tt;
            const dn = fbm2(X / 2300 + 3.7, Y / 2300 - 1.9, 101, 4);
            // THE STORM CELL (v18.87): one cell in the deck far from the moon, guaranteed cloud, lit from inside
            let sk = 0;
            if (T.storm > 0 && !SKIP.has('storm')) { const sd = Math.hypot(wrapAz(az - STORM_AZ) * cosEl, el - STORM_EL); sk = Math.exp(-sd * sd / (2 * 0.10 * 0.10)) * T.storm; }
            let cov = smooth(clamp((dn - 0.50) / 0.22, 0, 1));
            if (sk > 0.01) cov = Math.max(cov, smooth(clamp(sk * 1.4, 0, 1)) * (0.5 + 0.5 * smooth(clamp((dn - 0.30) / 0.30, 0, 1))));   // guaranteed cloud, ragged by the deck's own noise
            if (cov > 0.002) {
              const litK = clamp(glowAt(az) * (0.45 + 0.55 * Math.exp(-tt / 9000)), 0, 1);
              let cc = mix3(T.cloudDark, T.cloudLit, litK * (0.5 + 0.5 * cov));
              cc = [cc[0] + T.cloudMoon[0] * moonK * 0.9, cc[1] + T.cloudMoon[1] * moonK * 0.9, cc[2] + T.cloudMoon[2] * moonK * 0.9];
              cc = mix3(cc, skyBaseAt(az, el), (1 - Math.exp(-tt / 16000)) * 0.85);
              const ug = underglowAt(X, Y);                                // v19.69 the underlit overcast
              if (ug) { const uk = Math.exp(-tt / 16000); cc = [cc[0] + ug[0] * uk, cc[1] + ug[1] * uk, cc[2] + ug[2] * uk]; }
              if (sk > 0.01) {                                                   // the cell glows from within: a veined, off-centre flash
                const vein = 0.6 + 0.8 * noise(NOISE_C, x, y * 1.6);
                const lit = sk * (0.35 + 0.65 * cov) * vein;
                cc = [cc[0] + T.stormCol[0] * lit * 0.85, cc[1] + T.stormCol[1] * lit * 0.85, cc[2] + T.stormCol[2] * lit * 0.85];
                if (lit > 0.25 && (x & 1) === 0 && (y & 1) === 0) emit(x, y, T.stormCol[0], T.stormCol[1], T.stormCol[2], lit * 0.35 * cov);
              }
              const a = cov * 0.80 * hf;
              r = lerp(r, cc[0], a); g = lerp(g, cc[1], a); b = lerp(b, cc[2], a);
            }
          }
          {
            const tt = CLOUD_HIGH_Z / Math.tan(el), X = Math.cos(az) * tt, Y = Math.sin(az) * tt;
            const dn = fbm2(X / 7000 + 9.1, Y / 1900 + 4.4, 202, 4);
            const cov = smooth(clamp((dn - 0.55) / 0.13, 0, 1)) * 0.42;
            if (cov > 0.002) {
              let cc = [T.cirrus[0] + T.cloudMoon[0] * moonK * 0.8, T.cirrus[1] + T.cloudMoon[1] * moonK * 0.8, T.cirrus[2] + T.cloudMoon[2] * moonK * 0.8];
              cc = mix3(cc, skyBaseAt(az, el), (1 - Math.exp(-tt / 30000)) * 0.8);
              const a = cov * hf;
              r = lerp(r, cc[0], a); g = lerp(g, cc[1], a); b = lerp(b, cc[2], a);
            }
          }
        }
        // LASER BARS
        for (const [baz, span, bel, col, wpx] of LASERS) {
          const d = wrapAz(az - baz);
          if (Math.abs(d) > span) continue;
          const dy = Math.abs(rowOfEl(bel) - y);
          const endf = smooth(clamp((span - Math.abs(d)) / (span * 0.35), 0, 1));
          const cov = clamp(wpx - dy, 0, 1) * endf;
          if (cov > 0) { r = lerp(r, col[0] * 1.3, cov); g = lerp(g, col[1] * 1.3, cov); b = lerp(b, col[2] * 1.3, cov); emit(x, y, col[0], col[1], col[2], cov * 0.9); }
        }
        // THE HAZE STRATA against the sky (v18.87) — the nearest thing on a sky ray, so they go over everything above
        const st = skyStrata(az, el, c, s);
        if (st) { r = lerp(r, st[1], st[0]); g = lerp(g, st[2], st[0]); b = lerp(b, st[3], st[0]); }
      } else {
        // GROUND GRID — dissolving into the horizon haze (v17.87: lines to 10% at infinity, the far plane takes the dome's colour)
        const dist = EYE / Math.tan(-el);
        const fog = Math.exp(-dist / 6500);
        const nad = smooth(clamp((el + Math.PI / 2) / (35 * D2R), 0, 1));
        const X = c * dist, Y = s * dist;
        const fpT = dist * TAU / W, fpR = EYE / (Math.sin(el) * Math.sin(el)) * (Math.PI / H);
        const fp = Math.max(fpT, Math.abs(fpR) * 0.9);
        const dX = Math.abs(X - Math.round(X / GRID) * GRID), dY = Math.abs(Y - Math.round(Y / GRID) * GRID);
        const kx = Math.round(X / GRID), ky = Math.round(Y / GRID);
        const lw = Math.max(fp * 0.9, 2.5) * LW;
        const covX = clamp(1 - dX / lw, 0, 1), covY = clamp(1 - dY / lw, 0, 1);
        const cxl = (kx % 5) === 0 ? GLINE5 : GLINE, cyl = (ky % 5) === 0 ? GLINE5 : GLINE;
        const cov = Math.max(covX, covY);
        const lc = covX >= covY ? cxl : cyl;
        const gd = glowDome(az, 0) || [0, 0, 0];
        const farCol = [HAZE[0] * 0.6 + gd[0] * 2.2, HAZE[1] * 0.6 + gd[1] * 2.2, HAZE[2] * 0.6 + gd[2] * 2.2];
        const base = mix3(GROUND, farCol, (1 - fog) * 0.9);
        let lineI = cov * (0.10 + 0.90 * fog) * nad * 1.1;
        r = lerp(base[0], lc[0], lineI); g = lerp(base[1], lc[1], lineI); b = lerp(base[2], lc[2], lineI);
        // GROUND MIST (v18.87 ATMOSPHERE): the grid runs INTO the lit bank — far lines drown, the plane takes the mist's colour
        const vl = veil(az, dist, 0, c, s);
        if (vl) { r = lerp(r, vl[1], vl[0]); g = lerp(g, vl[2], vl[0]); b = lerp(b, vl[3], vl[0]); lineI *= 1 - vl[0]; }
        const dim = (0.45 + 0.55 * smooth(clamp((el + 6 * D2R) / (6 * D2R), 0, 1))) * nad;   // v17.74: the lower hemisphere is a light source to the bake too — stock skies are BLACK below (ramped, v17.87)
        r *= dim; g *= dim; b *= dim;
        if (lineI > 0.5) emit(x, y, lc[0], lc[1], lc[2], lineI * 0.35);
        const hb = Math.exp(-(el * el) / (2 * Math.pow(1.2 * D2R, 2)));
        r += hb * T.horBand[0] * 0.8; g += hb * T.horBand[1] * 0.8; b += hb * T.horBand[2] * 0.8;
      }
      put(x, y, r, g, b);
    }
    if ((y & 255) === 0) process.stdout.write(`  sky ${Math.round(y / H * 100)}%\r`);
  }
  console.log(`  sky pass ${((Date.now() - tS) / 1000).toFixed(1)}s`);
})();

// ---------------------------------------------------------------- 2b. mountains — a hazed ridge beyond the far ring
(() => {
  const D_M = 34000, baseEl = Math.atan(-EYE / D_M);
  const edge = HUE.violet;
  for (let x = 0; x < W; x++) {
    const u = x / W; let hgt = 0;
    for (const [n, amp] of [[7, 1], [15, 0.5], [31, 0.25], [63, 0.12]]) { const f = u * n, i = Math.floor(f), tt = smooth(f - i); hgt += lerp(h2(i % n, 501), h2((i + 1) % n, 501), tt) * amp; }
    hgt = (hgt / 1.87) * 3.2 + 0.6;
    const az = azOfCol(x), daz = wrapAz(az - SUN_AZ), c = Math.cos(az), s = Math.sin(az);
    hgt *= 0.55 + 0.45 * Math.min(1, Math.abs(daz) / 0.9);
    if (inLane(az, 0)) hgt = Math.min(hgt, 1.2);
    const sb = skyBaseAt(az, hgt * D2R * 0.5);
    const fill = [sb[0] * 0.70, sb[1] * 0.70, sb[2] * 0.70];
    const topRow = rowOfEl(hgt * D2R), botRow = rowOfEl(baseEl);
    const y0 = Math.max(0, Math.floor(topRow)), y1 = Math.min(H - 1, Math.ceil(botRow));
    for (let y = y0; y <= y1; y++) {
      const cov = clamp(y + 0.5 - topRow + 0.5, 0, 1); if (cov <= 0) continue;
      let fr = fill[0], fg = fill[1], fb = fill[2];
      const vl = veil(az, D_M, EYE + Math.tan(elOfRow(y)) * D_M, c, s);        // v18.87: the ridge is behind every layer of air there is
      if (vl) { fr = lerp(fr, vl[1], vl[0]); fg = lerp(fg, vl[2], vl[0]); fb = lerp(fb, vl[3], vl[0]); }
      blend(x, y, fr, fg, fb, cov * 0.85);
      const ecov = clamp(1.6 * SS - Math.abs(y + 0.5 - topRow), 0, 1) * 0.25 * (vl ? 1 - vl[0] : 1);
      if (ecov > 0) blend(x, y, lerp(fr, edge[0], 0.5), lerp(fg, edge[1], 0.5), lerp(fb, edge[2], 0.5), ecov);
    }
  }
})();

// ---------------------------------------------------------------- 3. draw the city, far first
(() => {
  const t1 = Date.now();
  const PIX = process.env.TOD_SKY_PIXDBG ? process.env.TOD_SKY_PIXDBG.split(',').map(Number) : null;
  for (const it of items) {
    let before = null;
    if (PIX) before = [R[PIX[1] * W + PIX[0]], R[PIX[1] * W + W - 1]];
    it.draw();
    if (PIX) { const a = R[PIX[1] * W + PIX[0]], b = R[PIX[1] * W + W - 1]; if (a !== before[0] || b !== before[1]) console.log(`  PIX d=${it.d.toFixed(0)} L ${before[0].toFixed(3)}->${a.toFixed(3)} R ${before[1].toFixed(3)}->${b.toFixed(3)} :: ${it.box ? JSON.stringify(it.box, (k, v) => typeof v === 'number' ? Math.round(v * 100) / 100 : v) : it.draw.toString().replace(/s+/g, ' ').slice(6, 90)}`); }
  }
  console.log(`  city pass ${((Date.now() - t1) / 1000).toFixed(1)}s`);
})();

// ---------------------------------------------------------------- 3b. RESOLVE — v18.87 QUALITY: filter the supersampled paint down to the shipped size
// Lanczos-2, separable, wrapping in x (the seam stays periodic) and clamping in y. Every neon edge, rail, trail, star
// and glyph was painted at SS x the shipped pixel, so this is true anti-aliasing rather than the per-primitive coverage
// estimates the painter uses. Row-streamed: the vertical taps are gathered into ONE render-width row, then filtered
// across, so the only extra memory is the three final channels. Everything after this point reads FW/FH/FR/FG/FB.
const FW = OW, FH = OW / 2;
const rowOfElF = el => (0.5 - el / Math.PI) * FH - 0.5, elOfRowF = y => (0.5 - (y + 0.5) / FH) * Math.PI;
const [FR, FG, FB] = (W === OW) ? [R, G, B] : (() => {
  const t3 = Date.now(), A = 2;
  const lanczos = x => { x = Math.abs(x); if (x < 1e-6) return 1; if (x >= A) return 0; const px = Math.PI * x; return A * Math.sin(px) * Math.sin(px / A) / (px * px); };
  function taps(nOut, nIn, wrap) {                     // flat tap tables: NT taps per output pixel (zero-weighted where the window runs short)
    const NT = Math.ceil(2 * A * RS) + 1, idx = new Int32Array(nOut * NT), wt = new Float32Array(nOut * NT);
    for (let o = 0; o < nOut; o++) {
      const c = (o + 0.5) * RS - 0.5, i0 = Math.floor(c - A * RS + 1); let sum = 0;
      for (let k = 0; k < NT; k++) { const i = i0 + k, w = lanczos((i - c) / RS); idx[o * NT + k] = wrap ? ((i % nIn) + nIn) % nIn : clamp(i, 0, nIn - 1); wt[o * NT + k] = w; sum += w; }
      for (let k = 0; k < NT; k++) wt[o * NT + k] /= sum;
    }
    return { NT, idx, wt };
  }
  const TX = taps(FW, W, true), TY = taps(FH, H, false), NTX = TX.NT, NTY = TY.NT;
  const row = new Float32Array(W), out = [];
  for (const ch of [R, G, B]) {
    const dst = new Float32Array(FW * FH);
    for (let y = 0; y < FH; y++) {
      row.fill(0);
      const t = y * NTY;
      for (let k = 0; k < NTY; k++) { const srow = TY.idx[t + k] * W, w = TY.wt[t + k]; if (w === 0) continue; for (let x = 0; x < W; x++) row[x] += ch[srow + x] * w; }
      const orow = y * FW;
      for (let x = 0; x < FW; x++) { let acc = 0; const tx = x * NTX; for (let k = 0; k < NTX; k++) acc += row[TX.idx[tx + k]] * TX.wt[tx + k]; dst[orow + x] = acc < 0 ? 0 : acc; }
    }
    out.push(dst);
  }
  console.log(`  resolve ${RS}x ${W}x${H} -> ${FW}x${FH} (lanczos-${A}, ${NTX}x${NTY} taps) ${((Date.now() - t3) / 1000).toFixed(1)}s`);
  return out;
})();

// ---------------------------------------------------------------- 3c. SHARPEN — wrap-aware unsharp masks on the resolved image (the bloom is added after, so it never rings)
// v18.87, from Tower II's v0.6: the passes are tuned against the SIMULATED IN-GAME VIEW (night_ingame_*.png below —
// cg_fov 65 at 16:9 is 80.7 deg, so 1080p shows 0.96 texel per pixel and the GPU's bilinear resample softens every edge by
// up to half a texel). Three passes: 3x3 at 0.38, 3x3 at 0.45, 5x5 at 0.25. Every pass clamps to 0.6..1.5x the source
// pixel, which is what keeps the neon lines, the stars and the windows from ringing. --sharpen "r:a,..." overrides;
// --sharpen none skips.
(() => {
  const t3 = Date.now();
  const spec = argv('--sharpen', '3:0.38,3:0.45,5:0.25');
  // above 8192 each pass's radius is scaled by HI (3 -> 5 at 16384: the kernel stays the same size in APPROVED pixels)
  const passes = spec === 'none' ? [] : spec.split(',').map(t => t.split(':').map(Number)).map(([r, a]) => [HI > 1 ? Math.round(r * HI) | 1 : r, a]);
  const src = new Float32Array(FW * FH);
  for (const [rad, amt] of passes) {
    const r = rad >> 1, n = rad * rad;
    for (const ch of [FR, FG, FB]) {
      src.set(ch);
      for (let y = r; y < FH - r; y++) {
        for (let x = 0; x < FW; x++) {
          let sum = 0;
          for (let dy = -r; dy <= r; dy++) { const row = (y + dy) * FW; for (let dx = -r; dx <= r; dx++) { let xx = x + dx; if (xx < 0) xx += FW; else if (xx >= FW) xx -= FW; sum += src[row + xx]; } }
          const v = src[y * FW + x], o = v + amt * (v - sum / n);
          ch[y * FW + x] = o < v * 0.6 ? v * 0.6 : o > v * 1.5 ? v * 1.5 : o;
        }
      }
    }
  }
  console.log(`  sharpen ${passes.map(([r, a]) => `${r}x${r}@${a}`).join(' + ') || 'none'} ${((Date.now() - t3) / 1000).toFixed(1)}s`);
})();

// ---------------------------------------------------------------- 4. bloom (at the SHIPPED size; the emit grid is render/4, so one cell spans FW/EW final px)
(() => {
  const t2 = Date.now();
  const rad = Math.max(2, Math.round(6 * PX));                // emit cells — the grid scales with the render, so this is the same ANGULAR radius at any --ss
  const tmp = new Float32Array(EW * EH);
  function boxBlur(src) {
    for (let y = 0; y < EH; y++) {
      let acc = 0; const row = y * EW;
      for (let i = -rad; i <= rad; i++) acc += src[row + ((i % EW) + EW) % EW];
      for (let x = 0; x < EW; x++) { tmp[row + x] = acc / (2 * rad + 1); acc += src[row + ((x + rad + 1) % EW)] - src[row + ((x - rad + EW) % EW)]; }
    }
    for (let x = 0; x < EW; x++) {
      let acc = 0;
      for (let i = -rad; i <= rad; i++) acc += tmp[clamp(i, 0, EH - 1) * EW + x];
      for (let y = 0; y < EH; y++) { src[y * EW + x] = acc / (2 * rad + 1); acc += tmp[clamp(y + rad + 1, 0, EH - 1) * EW + x] - tmp[clamp(y - rad, 0, EH - 1) * EW + x]; }
    }
  }
  for (const ch of [ER, EG, EB]) { for (let i = 0; i < ch.length; i++) if (ch[i] > 1.15) ch[i] = 1.15; boxBlur(ch); boxBlur(ch); boxBlur(ch); }
  const GLOW = 0.05, EK = FW / EW;                           // v17.74: 0.30 ("white glow" on the buildings); v17.82: 0.14 — "everything just looks like its glowing"; v18.97: 0.05 — "remove all the crazy white glow"
  for (let y = 0; y < FH; y++) {
    const fy = clamp(y / EK - 0.5, 0, EH - 1.001), iy = Math.floor(fy), ty = fy - iy, iy1 = Math.min(iy + 1, EH - 1);
    for (let x = 0; x < FW; x++) {
      const fx = ((x / EK - 0.5) % EW + EW) % EW, ix = Math.floor(fx), tx = fx - ix, ix1 = (ix + 1) % EW;
      const o = y * FW + x;
      const w00 = (1 - tx) * (1 - ty), w10 = tx * (1 - ty), w01 = (1 - tx) * ty, w11 = tx * ty;
      const a = iy * EW + ix, b = iy * EW + ix1, c = iy1 * EW + ix, d = iy1 * EW + ix1;
      FR[o] += GLOW * (ER[a] * w00 + ER[b] * w10 + ER[c] * w01 + ER[d] * w11);
      FG[o] += GLOW * (EG[a] * w00 + EG[b] * w10 + EG[c] * w01 + EG[d] * w11);
      FB[o] += GLOW * (EB[a] * w00 + EB[b] * w10 + EB[c] * w01 + EB[d] * w11);
    }
  }
  console.log(`  bloom ${((Date.now() - t2) / 1000).toFixed(1)}s`);
})();

// ---------------------------------------------------------------- 4a. THE PEAK KNEE (v18.97, docs/104 §4k)
// User: "the buildings have these white glares ... a blur and you can't see the buildings properly". That is the IMAGE:
// a lit edge is written at display 1.15 (linear 1.36) over a sky base near 0.1 (linear 0.006) — 200x — and the engine's
// HDR bloom turns every lit edge, window, sign and headlight into a white halo. The previews never showed it because they
// are display-referred. Every display value above KNEE is soft-clipped toward KNEE_MAX, per channel (hue kept), so the
// peaks sit ~40x over the base instead of ~200x. Runs before the gain solve, so the solve sees the compressed picture.
const KNEE = parseFloat(argv('--knee', '0.45')), KNEE_MAX = parseFloat(argv('--knee-max', '0.62'));
(() => {
  if (!(KNEE > 0) || KNEE >= 2) return;
  const range = KNEE_MAX - KNEE;
  const knee = v => v <= KNEE ? v : KNEE + range * (1 - Math.exp(-(v - KNEE) / range));
  let hot = 0, tot = 0;
  for (let i = 0; i < FR.length; i++) {
    if (FR[i] > KNEE || FG[i] > KNEE || FB[i] > KNEE) hot++; tot++;
    FR[i] = knee(FR[i]); FG[i] = knee(FG[i]); FB[i] = knee(FB[i]);
  }
  console.log(`  knee ${KNEE} -> max ${KNEE_MAX}: ${(hot / tot * 100).toFixed(2)}% of pixels were above the knee`);
})();

// ---------------------------------------------------------------- 4b. TINT (v17.77, the red-light test)
// `--tint r,g,b` multiplies every pixel IN LINEAR LIGHT. The sky is the map's ambient light
// (§4 above: the bake integrates this picture through skyStops), so one knob tints the
// visible sky AND the sky light in the same move — there is no separate "sky light colour"
// key anywhere in the ssi or the material. The linear channel-sum mean is HELD: this file is
// blue-dominant, so a bare red multiply would also darken the world ~3x and the test would
// read as "dark", not "red". The arrays hold DISPLAY values (linear = v^2.2 x gain), so a
// linear tint t lands as a display multiplier t^(1/2.2). Neutral 1,1,1 is byte-identical
// output; a tinted run suffixes its previews `_tint` so the approved docs/sky_preview set is
// not overwritten.
const TINT = argv('--tint', '1,1,1').split(',').map(Number);
const TINTED = TINT.length === 3 && TINT.some(v => v !== 1);
const TINT_TAG = TINTED ? '_tint' : '';
if (TINTED) (() => {
  const lin = [0, 0, 0];
  for (let i = 0; i < FR.length; i++) { lin[0] += Math.pow(Math.max(FR[i], 0), 2.2); lin[1] += Math.pow(Math.max(FG[i], 0), 2.2); lin[2] += Math.pow(Math.max(FB[i], 0), 2.2); }
  const tot = lin[0] + lin[1] + lin[2];
  const k = tot / Math.max(lin[0] * TINT[0] + lin[1] * TINT[1] + lin[2] * TINT[2], 1e-12);
  const m = TINT.map(t => Math.pow(t * k, 1 / 2.2));
  for (let i = 0; i < FR.length; i++) { FR[i] *= m[0]; FG[i] *= m[1]; FB[i] *= m[2]; }
  const share = a => a.map(v => (v / tot * 100).toFixed(0) + '%').join('/');
  console.log(`  tint ${TINT.join(',')} (linear) x${k.toFixed(2)} to hold the mean; display mult ${m.map(v => v.toFixed(3)).join('/')}; linear R/G/B share ${share(lin)} -> ${share(lin.map((v, i) => v * TINT[i] * k))}`);
})();

// ---------------------------------------------------------------- 4c. STATS + THE GAIN SOLVE (v18.87) — the sky-light score
// linear = display^2.2 x SKY_GAIN; score = mean x 2^skyStops(10) = mean x 1024. v17.82 at FULL size: 0.478, share
// 22/27/51 (2048 preview: 0.834 — line weight does not scale with W). v18.87: the gain is SOLVED so the score lands on
// --target-score whatever the picture does; the world's lighting therefore cannot move with a picture change.
(() => {
  let sU = [0, 0, 0], sA = [0, 0, 0], nU = 0, nA = 0;
  const lin1 = v => Math.pow(clamp(v, 0, 2), 2.2);
  for (let y = 0; y < FH; y += 3) for (let x = 0; x < FW; x += 3) {
    const o = y * FW + x, lr = lin1(FR[o]), lg = lin1(FG[o]), lb = lin1(FB[o]);
    sA[0] += lr; sA[1] += lg; sA[2] += lb; nA++;
    if (y < FH / 2) { sU[0] += lr; sU[1] += lg; sU[2] += lb; nU++; }
  }
  const mA1 = (sA[0] + sA[1] + sA[2]) / (3 * nA), mU1 = (sU[0] + sU[1] + sU[2]) / (3 * nU), tot = sA[0] + sA[1] + sA[2];
  if (GAIN_ARG === null) SKY_GAIN = TARGET_SCORE / 1024 / mA1;
  const mA = mA1 * SKY_GAIN, mU = mU1 * SKY_GAIN;
  console.log(`  STATS [${FW}x${FH}${HI > 1 ? `, x${HI} of the approved 8192` : ''}] mean(all) ${mA.toExponential(3)} mean(upper) ${mU.toExponential(3)} score(x1024) ${(mA * 1024).toFixed(3)} rgb share ${sA.map(v => (v / tot * 100).toFixed(0)).join('/')}  gain ${SKY_GAIN.toFixed(5)} (${GAIN_ARG === null ? `solved for ${TARGET_SCORE}` : 'pinned by --gain'}; v17.87 shipped 0.024)  [v17.82 @8192: 0.478, 22/27/51]`);
  if (FULL && GAIN_ARG === null && (SKY_GAIN < 0.012 || SKY_GAIN > 0.048)) throw new Error(`GAIN: the solve landed at ${SKY_GAIN.toFixed(4)}, outside 0.012..0.048 — the picture's mean moved more than 2x from v17.87; read the STATS before shipping`);
})();

// ---------------------------------------------------------------- 5. outputs
function crc32(buf) {
  let c; const t = crc32.t || (crc32.t = (() => { const t = []; for (let n = 0; n < 256; n++) { c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })());
  let r = 0xFFFFFFFF; for (let i = 0; i < buf.length; i++) r = t[(r ^ buf[i]) & 255] ^ (r >>> 8); return (r ^ 0xFFFFFFFF) >>> 0;
}
function pngChunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function writePng(file, w, h, depth, channels, rowFn) {
  const bpp = channels * (depth / 8), stride = 1 + w * bpp;
  const raw = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) { raw[y * stride] = 0; rowFn(y, raw, y * stride + 1); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = depth; ihdr[9] = channels === 4 ? 6 : 2;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), pngChunk('IHDR', ihdr), pngChunk('IDAT', zlib.deflateSync(raw, { level: 6 })), pngChunk('IEND', Buffer.alloc(0))]));
}
const tone = v => clamp(v, 0, 1);
const previewDir = process.env.TOD_SKY_PREVIEW_DIR || path.join(REPO, 'docs', 'sky_preview');
fs.mkdirSync(previewDir, { recursive: true });
(() => {
  const PW = Math.min(2048, FW), PH = PW / 2, k = FW / PW;
  writePng(path.join(previewDir, `${THEME}${TINT_TAG}_sky_equirect.png`), PW, PH, 8, 3, (y, buf, o) => {
    for (let x = 0; x < PW; x++) {
      let r = 0, g = 0, b = 0, n = 0;
      for (let j = 0; j < k; j++) for (let i = 0; i < k; i++) { const s = (y * k + j) * FW + x * k + i; r += FR[s]; g += FG[s]; b += FB[s]; n++; }
      buf[o + x * 3] = tone(r / n) * 255; buf[o + x * 3 + 1] = tone(g / n) * 255; buf[o + x * 3 + 2] = tone(b / n) * 255;
    }
  });
})();
function sample(az, el) {
  const fx = ((az / TAU * FW - 0.5) % FW + FW) % FW, fy = clamp(rowOfElF(el), 0, FH - 1.001);
  const ix = Math.floor(fx), iy = Math.floor(fy), tx = fx - ix, ty = fy - iy, ix1 = (ix + 1) % FW, iy1 = Math.min(iy + 1, FH - 1);
  const a = iy * FW + ix, b = iy * FW + ix1, c = iy1 * FW + ix, d = iy1 * FW + ix1;
  const w00 = (1 - tx) * (1 - ty), w10 = tx * (1 - ty), w01 = (1 - tx) * ty, w11 = tx * ty;
  return [FR[a] * w00 + FR[b] * w10 + FR[c] * w01 + FR[d] * w11, FG[a] * w00 + FG[b] * w10 + FG[c] * w01 + FG[d] * w11, FB[a] * w00 + FB[b] * w10 + FB[c] * w01 + FB[d] * w11];
}
// a perspective view of the sphere: VW x VH at the given horizontal fov, looking along vaz at pitch vpitchDeg, bilinear
function writeView(file, VW, VH, hfov, vaz, vpitchDeg) {
  const f = (VW / 2) / Math.tan(hfov / 2);
  const cp = Math.cos(vpitchDeg * D2R), sp = Math.sin(vpitchDeg * D2R);
  writePng(file, VW, VH, 8, 3, (y, buf, o) => {
    for (let x = 0; x < VW; x++) {
      const dx = f, dy = (x + 0.5 - VW / 2), dz = -(y + 0.5 - VH / 2);
      const fx = dx * cp - dz * sp, fz = dx * sp + dz * cp, fy = dy;
      const len = Math.hypot(fx, fy, fz);
      const [r, g, b] = sample(vaz + Math.atan2(fy, fx), Math.asin(fz / len));
      buf[o + x * 3] = tone(r) * 255; buf[o + x * 3 + 1] = tone(g) * 255; buf[o + x * 3 + 2] = tone(b) * 255;
    }
  });
}
const VIEWS = [
  ['view_sun', SUN_AZ, 4], ['view_city_a', SUN_AZ + 2.2, 4], ['view_city_b', SUN_AZ - 1.9, 6],
  ['view_landmarks', SUN_AZ + Math.PI + 0.3, 8], ['view_gate', SUN_AZ - 0.95, 10],
  ['view_up', SUN_AZ + 0.9, 45], ['view_down', SUN_AZ - 0.6, -30],
  ['view_hole', SUN_AZ + 1.30, 52], ['view_maelstrom', SUN_AZ - 0.85, 55], ['view_giant', GIANT_AZ, 9], ['view_ice', SUN_AZ - 2.55, 55], ['view_rust', SUN_AZ + 0.55, 32],
  ['view_ring_a', Math.atan2(-3000, 5200), 12], ['view_ring_b', Math.atan2(5200, -6600), 14], ['view_far', SUN_AZ + 2.6, 9],
  // v18.87
  ['view_tether', TETHER.az, 28], ['view_station', TETHER.az, 47], ['view_storm', STORM_AZ, 6], ['view_ship_a', SUN_AZ + SHIP_DEFS[0].azOff, Math.atan((SHIP_DEFS[0].z - EYE) / SHIP_DEFS[0].d) / D2R], ['view_ship_b', SUN_AZ + SHIP_DEFS[1].azOff, Math.atan((SHIP_DEFS[1].z - EYE) / SHIP_DEFS[1].d) / D2R], ['view_mist', SUN_AZ + 2.9, -4],
  ...(globalThis.RAIL_VIEWS || []),
  ['view_crosstown', -Math.PI / 2, 14], ['view_crosstown_w', -Math.PI / 2 - 0.9, 10], ['view_ring_a_hi', Math.atan2(-3000, 5200) + 0.5, 20],
];
for (const [name, vaz, vpitchDeg] of VIEWS) writeView(path.join(previewDir, `${THEME}${TINT_TAG}_${name}.png`), 960, 540, 90 * D2R, vaz, vpitchDeg);
console.log(`  previews -> ${path.relative(REPO, previewDir) || previewDir}`);
// v18.87: THE IN-GAME VIEW — 1920x1080 at cg_fov 65 (horizontal at 4:3, Hor+ -> 80.7 deg at 16:9), sampled BILINEARLY
// from the shipped-size buffers exactly as the GPU samples the texture. 0.96 texel per screen pixel at 1080p: this is the
// image to judge SHARPNESS on (the 90-deg views above are 2x minified and the 2048 equirect is 4x). Crop 1:1 first.
(() => {
  const VW = 1920, VH = 1080;
  const vfov = 2 * Math.atan(Math.tan(65 * D2R / 2) / (4 / 3)), hfov = 2 * Math.atan(Math.tan(vfov / 2) * VW / VH);
  const INGAME = [['moon', SUN_AZ, 6], ['city', SUN_AZ + 2.2, 4], ['tether', TETHER.az, 22], ['giant', GIANT_AZ, 9], ['ship', SUN_AZ + SHIP_DEFS[0].azOff, Math.atan((SHIP_DEFS[0].z - EYE) / SHIP_DEFS[0].d) / D2R]];
  for (const [name, vaz, vpitchDeg] of INGAME) writeView(path.join(previewDir, `${THEME}${TINT_TAG}_ingame_${name}.png`), VW, VH, hfov, vaz, vpitchDeg);
  console.log(`  in-game views (${VW}x${VH}, hfov ${(hfov / D2R).toFixed(1)} deg, ${(hfov / TAU * FW / VW).toFixed(2)} texel/px) -> ${THEME}_ingame_*.png`);
})();
(() => {
  // the wrap pair (col FW-1 | col 0) against its own neighbour pairs and the whole-image adjacent mean: a periodic
  // image puts the wrap within the noise of its neighbours; a broken period shows as an outlier (v17.87: the old
  // check compared against ONE arbitrary column pair and read a ring rail crossing a row at the seam as a break)
  const pairDelta = (x0, x1) => { let s = 0; for (let y = 0; y < FH; y++) { const a = y * FW + x0, b = y * FW + x1; s += Math.abs(FR[a] - FR[b]) + Math.abs(FG[a] - FG[b]) + Math.abs(FB[a] - FB[b]); } return s / FH; };
  const seam = pairDelta(FW - 1, 0), nbr = (pairDelta(0, 1) + pairDelta(FW - 2, FW - 1)) / 2;
  let all = 0; for (let y = 0; y < FH; y += 3) { let s = 0; for (let x = 1; x < FW; x++) { const a = y * FW + x - 1, b = a + 1; s += Math.abs(FR[a] - FR[b]) + Math.abs(FG[a] - FG[b]) + Math.abs(FB[a] - FB[b]); } all += s / (FW - 1); }
  const step = all / Math.ceil(FH / 3);
  if (process.env.TOD_SKY_SEAMDBG) { const rows = []; for (let y = 0; y < FH; y++) { const a = y * FW, b = y * FW + FW - 1; rows.push([Math.abs(FR[a] - FR[b]) + Math.abs(FG[a] - FG[b]) + Math.abs(FB[a] - FB[b]), y]); } rows.sort((p, q) => q[0] - p[0]); console.log('  seam worst rows: ' + rows.slice(0, 12).map(([d, y]) => `y${y} el ${(elOfRowF(y) / D2R).toFixed(1)}° d ${d.toFixed(3)} L[${[FR[y*FW],FG[y*FW],FB[y*FW]].map(v=>v.toFixed(2))}] R[${[FR[y*FW+FW-1],FG[y*FW+FW-1],FB[y*FW+FW-1]].map(v=>v.toFixed(2))}]`).join(' | ')); }
  console.log(`  seam check: wrap delta ${seam.toFixed(5)} vs its neighbour pairs ${nbr.toFixed(5)} (${(seam / Math.max(nbr, 1e-9)).toFixed(2)}x) vs whole-image adjacent mean ${step.toFixed(5)} (${(seam / Math.max(step, 1e-9)).toFixed(2)}x)`);
  if (seam > 2.5 * Math.max(nbr, step)) throw new Error('SEAM: the wrap column pair is an outlier — something in the render is not periodic in W');
})();
// v18.87 QUALITY: the EXR is written DIRECTLY as half floats (ZIP16, channels A B G R — the layout ffmpeg produced before).
// The old path quantised every value to 12 bits (a 4096-entry LUT) and then to 16-bit LINEAR PNG before ffmpeg made it
// half; at this file's mean that left the dark sky with coarse steps. Half floats keep ~11 bits of precision at EVERY level.
const toLinear = v => Math.pow(clamp(v, 0, 2), 2.2) * SKY_GAIN;
function writeExrHalf(file, w, h, chans) {            // chans: [[name, Float32Array (display-referred, 0..2) | null (= 1)], ...]
  const names = chans.map(c => c[0]).sort();
  const byName = Object.fromEntries(chans);
  const parts = [];
  const u32 = n => { const b = Buffer.alloc(4); b.writeInt32LE(n); return b; };
  const f32 = n => { const b = Buffer.alloc(4); b.writeFloatLE(n); return b; };
  const attr = (name, type, val) => parts.push(Buffer.from(name + '\0' + type + '\0'), u32(val.length), val);
  parts.push(Buffer.from([0x76, 0x2f, 0x31, 0x01]), u32(2));
  const chl = [];
  for (const n of names) chl.push(Buffer.from(n + '\0'), u32(1), Buffer.from([0, 0, 0, 0]), u32(1), u32(1));
  chl.push(Buffer.from([0]));
  attr('channels', 'chlist', Buffer.concat(chl));
  attr('compression', 'compression', Buffer.from([3]));                       // ZIP_COMPRESSION: 16 scanlines per chunk
  const box = Buffer.concat([u32(0), u32(0), u32(w - 1), u32(h - 1)]);
  attr('dataWindow', 'box2i', box); attr('displayWindow', 'box2i', box);
  attr('lineOrder', 'lineOrder', Buffer.from([0]));
  attr('pixelAspectRatio', 'float', f32(1));
  attr('screenWindowCenter', 'v2f', Buffer.concat([f32(0), f32(0)]));
  attr('screenWindowWidth', 'float', f32(1));
  parts.push(Buffer.from([0]));
  const header = Buffer.concat(parts);
  const LINES = 16, nChunks = Math.ceil(h / LINES);
  const table = Buffer.alloc(nChunks * 8);
  const chunks = [];
  let offset = header.length + table.length;
  const lineBytes = names.length * w * 2;
  const raw = new ArrayBuffer(LINES * lineBytes), rawU8 = new Uint8Array(raw), rawH = new Float16Array(raw);
  const re = new Uint8Array(LINES * lineBytes);
  for (let ci = 0; ci < nChunks; ci++) {
    const y0 = ci * LINES, nl = Math.min(LINES, h - y0), size = nl * lineBytes;
    let hi = 0;
    for (let l = 0; l < nl; l++) {
      const row = (y0 + l) * w;
      for (const n of names) {
        const src = byName[n];
        if (src === null) { for (let x = 0; x < w; x++) rawH[hi++] = 1; }
        else for (let x = 0; x < w; x++) rawH[hi++] = toLinear(src[row + x]);
      }
    }
    // OpenEXR zip: split even/odd bytes into the two halves, then byte-delta predictor, then deflate; store raw if that is not smaller
    const half = (size + 1) >> 1;
    for (let i = 0, a = 0, b = half; i < size; i += 2) { re[a++] = rawU8[i]; if (i + 1 < size) re[b++] = rawU8[i + 1]; }
    let p = re[0];
    for (let i = 1; i < size; i++) { const v = re[i]; re[i] = (v - p + 384) & 255; p = v; }
    let data = zlib.deflateSync(re.subarray(0, size), { level: 6 });
    if (data.length >= size) data = Buffer.from(rawU8.subarray(0, size));
    const head = Buffer.alloc(8); head.writeInt32LE(y0, 0); head.writeInt32LE(data.length, 4);
    table.writeBigUInt64LE(BigInt(offset), ci * 8);
    chunks.push(head, data); offset += 8 + data.length;
  }
  fs.writeFileSync(file, Buffer.concat([header, table, ...chunks]));
}
if (FULL && !has('--preview-only')) {
  if (typeof Float16Array === 'undefined') throw new Error('Float16Array missing — Node 24+ is required for the half-float EXR writer');
  const outDir = path.join(REPO, 'source_data', 'tod_skybox', '_images');
  fs.mkdirSync(outDir, { recursive: true });
  const exr = path.join(outDir, 'i_skybox_tod_cybercity.exr');
  const t3 = Date.now();
  writeExrHalf(exr, FW, FH, [['R', FR], ['G', FG], ['B', FB], ['A', null]]);
  console.log(`  EXR ${((Date.now() - t3) / 1000).toFixed(1)}s -> ${path.relative(REPO, exr)} (${(fs.statSync(exr).size / 1048576).toFixed(1)} MB, half, zip16), gain ${SKY_GAIN.toFixed(5)}, theme ${THEME}${TINTED ? `, TINT ${TINT.join(',')}` : ''}`);
  if (!has('--no-judge') && FW <= 8192) {
    // the JUDGING image: the same linear values as the EXR, 16-bit PNG — lift a native crop with pow(v*6, 0.45) to read the darks
    const scratch = process.env.TOD_SKY_SCRATCH || path.join(require('os').tmpdir(), 'tod_sky');
    fs.mkdirSync(scratch, { recursive: true });
    const png16 = path.join(scratch, 'i_skybox_tod_cybercity_16.png');
    const t4 = Date.now();
    writePng(png16, FW, FH, 16, 4, (y, buf, o) => {
      const row = y * FW;
      for (let x = 0; x < FW; x++) {
        const p = o + x * 8;
        buf.writeUInt16BE(Math.round(clamp(toLinear(FR[row + x]), 0, 1) * 65535), p);
        buf.writeUInt16BE(Math.round(clamp(toLinear(FG[row + x]), 0, 1) * 65535), p + 2);
        buf.writeUInt16BE(Math.round(clamp(toLinear(FB[row + x]), 0, 1) * 65535), p + 4);
        buf.writeUInt16BE(65535, p + 6);
      }
    });
    console.log(`  judge png16 ${((Date.now() - t4) / 1000).toFixed(1)}s -> ${png16}`);
  }
}

// ---------------------------------------------------------------- 6. --gdt
// Clones the Miami chain out of the INSTALLED Nastian GDT (image, material,
// xmodel, ssi) with the names and the two references repointed, into a repo
// GDT of our own. Never edit acc_nastian_t9_skyboxes.gdt: it is shared with
// map 1 and Tower II at the tools root.
if (has('--gdt')) {
  const roots = ['C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130'];
  const src = roots.map(r => path.join(r, 'source_data', 'acc_nastian_t9_skyboxes.gdt')).find(f => fs.existsSync(f));
  if (!src) throw new Error('acc_nastian_t9_skyboxes.gdt not found in the mod tools');
  const text = fs.readFileSync(src, 'utf8');
  const block = (name, gdf) => { const m = text.match(new RegExp(`\\t"${name}" \\( "${gdf}" \\)\\r?\\n\\t\\{[\\s\\S]*?\\n\\t\\}`)); if (!m) throw new Error(`block ${name} (${gdf}) not found`); return m[0]; };
  const IMG = 'i_skybox_tod_cybercity', MTL = 'mtl_skybox_tod_cybercity', MDL = 'skybox_tod_cybercity', SSI = 'tod_ssi_cybercity';
  const img = block('skybox_t9_miami_mp_ft', 'image.gdf').replace('"skybox_t9_miami_mp_ft"', `"${IMG}"`).replace(/"baseImage" "[^"]*"/, '"baseImage" "source_data\\\\tod_skybox\\\\_images\\\\i_skybox_tod_cybercity.exr"');
  const mtl = block('mtl_skybox_t9_mp_miami', 'material.gdf').replace('"mtl_skybox_t9_mp_miami"', `"${MTL}"`).replace('"colorMap" "skybox_t9_miami_mp_ft"', `"colorMap" "${IMG}"`);
  const mdl = block('skybox_t9_mp_miami', 'xmodel.gdf').replace('"skybox_t9_mp_miami"', `"${MDL}"`).replace('"skinOverride" "mtl_skybox_default mtl_skybox_t9_mp_miami"', `"skinOverride" "mtl_skybox_default ${MTL}"`);
  const ssi = block('acc_ssi_miami_night', 'ssi.gdf').replace('"acc_ssi_miami_night"', `"${SSI}"`).replace('"skyboxmodel" "skybox_t9_mp_miami"', `"skyboxmodel" "${MDL}"`);
  for (const [s, must] of [[img, IMG], [mtl, MTL], [mdl, MDL], [ssi, SSI]]) if (!s.includes(`"${must}"`)) throw new Error('rename failed for ' + must);
  if (!img.includes('tod_skybox') || !mtl.includes(`"${IMG}"`) || !mdl.includes(MTL) || !ssi.includes(MDL)) throw new Error('reference repoint failed');
  const out = `{\n${img}\n${mtl}\n${mdl}\n${ssi}\n}\n`;
  const dst = path.join(REPO, 'source_data', 'tod_skybox.gdt');
  fs.writeFileSync(dst, out);
  console.log(`  gdt -> ${path.relative(REPO, dst)} (${out.split('\n').length} lines)`);
}
console.log(`done ${((Date.now() - t0) / 1000).toFixed(1)}s`);
