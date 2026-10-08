'use strict';
// ride_check.js - THE CLEARANCE + SMOOTHNESS CHECK for every rocket flight (docs/170), shared by the gate
// (test_rocket_ride.js) and by re-authoring (design runs pass explicit keys through ride_sim.buildPlans).
//
// For every server frame of every flight:
//   * THE HULL: spheres along the ship's axis every 20 units, each the measured MAX radius there (fins
//     included) + HULL_MARGIN, must clear every VISIBLE brush (map_clearance: a lower-bound distance, so a pass is
//     a proof). Exempt: the first EXEMPT_LIFT units of a launch near its pad, and the last EXEMPT_CRASH seconds of
//     the spire ride (the nose going into the corner IS the crash) - and a landing's last EXEMPT_LIFT units.
//   * THE CAMERA (rides only): its point must clear every visible brush by CAM_MARGIN, stay inside the sky
//     seal, sit outside the hull (its distance from the axis > the body radius there + 8), and turn no more than
//     CAM_STEP_MAX degrees between frames (a rider's view never snaps) - up to the crash's white.
//   * THE SKY: every hull sphere inside the sealed sky volume.
const path = require('path');
const fs = require('fs');
const { loadMap } = require('./map_clearance.js');
const SIM = require('./ride_sim.js');

const HULL_MARGIN = 12;
const CAM_MARGIN = 28;
const CAM_STEP_MAX = 7.5;        // deg per 50 ms frame (150 deg/s) - Tower II's camera gate
const EXEMPT_LIFT = 160;         // units of travel off (or onto) a pad where the feet / floor contact is exempt
const EXEMPT_CRASH = 0.45;       // s before the spire ride's end: the hull entering the corner

const REPO = path.resolve(__dirname, '..', '..');

function maxProfile() {
  const m = JSON.parse(fs.readFileSync(path.join(REPO, 'art', 'fan_props', 'manifest.json'), 'utf8')).props;
  const a = m.rocket_spire.rocket.profile, b = m.rocket_extract.rocket.profile;
  return a.map((p, i) => [p[0], Math.max(p[2], b[i][2]), Math.max(p[1], b[i][1])]);
}

function angDiff(a, b) {
  const d = x => { let y = ((x % 360) + 540) % 360 - 180; return Math.abs(y); };
  return Math.max(d(a[0] - b[0]), d(a[1] - b[1]));
}

function check(R, built, M, opts = {}) {
  const prof = maxProfile();
  const { plans, len, body } = built;
  const report = {};
  for (const kind of Object.keys(plans)) {
    const P = plans[kind];
    const ride = !kind.startsWith('land_');
    const frames = SIM.fly(R, P, len, body, ride);
    const pad = frames[0].org;
    const tEnd = frames[frames.length - 1].t;
    const hullFails = [], camFails = [], stepFails = [], skyFails = [];
    let minHull = Infinity, minHullAt = null, minCam = Infinity, minCamAt = null, maxStep = 0, maxStepAt = 0, maxSpeed = 0;
    for (let i = 0; i < frames.length; i++) {
      const f = frames[i];
      if (i > 0) {
        const v = Math.hypot(...[0, 1, 2].map(a => f.org[a] - frames[i - 1].org[a])) / (f.t - frames[i - 1].t);
        if (v > maxSpeed) maxSpeed = v;
      }
      const offPad = Math.hypot(...[0, 1, 2].map(a => f.org[a] - pad[a]));
      const endOrg = frames[frames.length - 1].org;
      const toEnd = Math.hypot(...[0, 1, 2].map(a => f.org[a] - endOrg[a]));
      let exempt = false;
      if (ride && offPad < EXEMPT_LIFT) exempt = true;
      if (!ride && toEnd < EXEMPT_LIFT) exempt = true;
      if (kind === 'spire' && f.t > tEnd - EXEMPT_CRASH) exempt = true;
      if (!exempt) {
        for (let x = 0; x <= len; x += 20) {
          const st = Math.min(40, Math.round(x * 40 / len));
          const r = prof[st][1] + HULL_MARGIN;
          const c = [0, 1, 2].map(a => f.org[a] + f.nose[a] * x);
          const res = M.distance(c, r + 600);
          const clear = res.d - r;
          if (clear < minHull) { minHull = clear; minHullAt = { t: f.t, x, c: c.map(Math.round), by: res.brush ? res.brush.mats[0] : '' }; }
          if (clear < 0) hullFails.push({ t: +f.t.toFixed(2), x, c: c.map(Math.round), d: +res.d.toFixed(1), r, by: res.brush ? res.brush.mats[0] + ' ' + res.brush.ent : '' });
          if (!M.insideSky(c, r)) skyFails.push({ t: f.t, x, c: c.map(Math.round) });
        }
      }
      if (ride && f.cam) {
        const camLive = kind !== 'spire' || f.t < tEnd - 0.06;
        if (camLive) {
          const co = f.cam.org;
          const res = M.distance(co, 400);
          const clear = res.d - CAM_MARGIN;
          if (res.d < minCam) { minCam = res.d; minCamAt = { t: f.t, c: co.map(Math.round), by: res.brush ? res.brush.mats[0] : '' }; }
          if (clear < 0) camFails.push({ t: +f.t.toFixed(2), c: co.map(Math.round), d: +res.d.toFixed(1), by: res.brush ? res.brush.mats[0] + ' ' + res.brush.ent : '' });
          if (!M.insideSky(co, 40)) skyFails.push({ t: f.t, cam: co.map(Math.round) });
          // outside the hull: distance from the axis vs the body radius at the camera's station
          const rel = [0, 1, 2].map(a => co[a] - f.org[a]);
          const along = rel[0] * f.nose[0] + rel[1] * f.nose[1] + rel[2] * f.nose[2];
          const off = Math.hypot(...[0, 1, 2].map(a => rel[a] - f.nose[a] * along));
          const st = Math.min(40, Math.max(0, Math.round(along * 40 / len)));
          if (along >= 0 && along <= len && off < prof[st][2] + 8) camFails.push({ t: +f.t.toFixed(2), inside_hull: true, off: +off.toFixed(1), body: prof[st][2] });
          if (i > 0 && frames[i - 1].cam) {
            const dA = angDiff(f.cam.ang, frames[i - 1].cam.ang);
            if (dA > maxStep) { maxStep = dA; maxStepAt = f.t; }
            if (dA > CAM_STEP_MAX) stepFails.push({ t: +f.t.toFixed(2), step: +dA.toFixed(2) });
          }
        }
      }
    }
    report[kind] = {
      len: Math.round(P.plan.path.len), t_end: P.plan.sp.t_end, speed_scale: +P.plan.sp.scale.toFixed(3), max_speed: Math.round(maxSpeed),
      min_hull_clear: +minHull.toFixed(1), min_hull_at: minHullAt, min_cam_dist: ride ? +minCam.toFixed(1) : null, min_cam_at: minCamAt,
      max_cam_step: +maxStep.toFixed(2), max_cam_step_at: maxStepAt,
      hull_fails: hullFails.length, cam_fails: camFails.length, step_fails: stepFails.length, sky_fails: skyFails.length,
      first_hull_fails: hullFails.slice(0, 6), first_cam_fails: camFails.slice(0, 6), first_step_fails: stepFails.slice(0, 4), first_sky_fails: skyFails.slice(0, 3),
      frames,
    };
  }
  return report;
}

module.exports = { check, maxProfile, HULL_MARGIN, CAM_MARGIN, CAM_STEP_MAX, EXEMPT_LIFT, EXEMPT_CRASH };
