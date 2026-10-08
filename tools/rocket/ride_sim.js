'use strict';
// ride_sim.js - fly the rocket rides OFFLINE with the shipping GSC (docs/170).
//
// Loads scripts/zm/zm_tower_of_doom/_tod_rocket.gsc (+ the GENERATED _tod_crown_data.gsc / _tod_spire_data.gsc
// for the keys) into gsc_eval.js and steps every flight exactly as the game does (TOD_RK_STEP frames): the ship's
// pivot and nose from rk_state, the camera from rk_cam. Shared by the build gate (test_rocket_ride.js) and by
// anyone re-authoring a flight:  node tools/rocket/ride_sim.js [--gsc <file>] [--json]
const fs = require('fs');
const path = require('path');
const { gscLoad, V } = require('./gsc_eval.js');

const REPO = path.resolve(__dirname, '..', '..');
const SCRIPTS = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom');

function readDefines(text) {
  const d = {};
  for (const line of text.split(/\r?\n/)) {
    const m = /^#define\s+(\w+)\s+(.+?)\s*(\/\/.*)?$/.exec(line);
    if (m && !/\(/.test(m[1])) d[m[1]] = m[2];
  }
  return d;
}

function loadRocket(opts = {}) {
  const gscFile = opts.gsc || path.join(SCRIPTS, '_tod_rocket.gsc');
  const text = fs.readFileSync(gscFile, 'utf8');
  const defines = readDefines(text);
  const texts = [['tod_rocket', text]];
  const crown = opts.crown || path.join(SCRIPTS, '_tod_crown_data.gsc');
  const spire = opts.spire || path.join(SCRIPTS, '_tod_spire_data.gsc');
  if (fs.existsSync(crown)) texts.push(['tod_crown_data', fs.readFileSync(crown, 'utf8')]);
  if (fs.existsSync(spire)) texts.push(['tod_spire_data', fs.readFileSync(spire, 'utf8')]);
  const g = gscLoad(texts, defines);
  return { g, defines, text };
}

const num = (defines, k) => Number(String(defines[k]).replace(/[()]/g, ''));

// Build the plans the way plan_ride / plan_cam / plan_land do, from explicit keys (re-authoring) or from the
// generated data (the gate).
function buildPlans(R, keysOverride) {
  const { g, defines } = R;
  const gen = k => g.call('tod_crown_data::' + k[0], k.slice(1));
  const len = keysOverride ? keysOverride.len : g.call('tod_crown_data::rocket_len', []);
  const body = keysOverride ? keysOverride.body : g.call('tod_crown_data::rocket_body_r', []);
  g.level.tod_rk_len = len;
  g.level.tod_rk_body = body;
  const plans = {};
  for (const kind of ['spire', 'extract']) {
    let plan;
    if (keysOverride) {
      const K = keysOverride[kind];
      const lift = kind === 'spire' ? num(defines, 'TOD_RK_S_LIFT') : num(defines, 'TOD_RK_X_LIFT');
      plan = g.call('rk_plan', [kind, K.keys, K.tans, K.yaw, K.tk.map(t => t + lift), K.vk, false]);
    } else {
      plan = g.call('plan_ride', [kind]);
    }
    let cam;
    if (keysOverride) {
      const K = keysOverride[kind];
      const lift = kind === 'spire' ? num(defines, 'TOD_RK_S_LIFT') : num(defines, 'TOD_RK_X_LIFT');
      cam = g.call('rk_cam_plan', [kind, K.right, lift, len]);
    } else {
      cam = g.call('plan_cam', [kind, plan]);
    }
    plans[kind] = { plan, cam };
    let land;
    if (keysOverride) {
      const L = keysOverride['land_' + kind];
      const T = num(defines, 'TOD_RK_LAND_SECS');
      land = g.call('rk_plan', ['land_' + kind, L.keys, L.tans, keysOverride[kind].yaw, [0, T * 0.45, T * 0.82, T], [3400, 1500, 320, 45], true]);
    } else {
      land = g.call('plan_land', [kind]);
    }
    plans['land_' + kind] = { plan: land };
  }
  return { plans, len, body };
}

// step a flight: -> [{ t, org, nose, cam? }]
function fly(R, P, len, body, withCam) {
  const { g, defines } = R;
  const step = num(defines, 'TOD_RK_STEP');
  const plan = P.plan;
  const n = Math.round(plan.sp.t_end / step);
  const out = [];
  for (let i = 0; i <= n; i++) {
    const t = i * step;
    const st = g.call('rk_state', [plan, t]);
    const f = { t, s: st.s, org: st.org, nose: st.nose, ang: st.ang };
    if (withCam) f.cam = g.call('rk_cam', [P.cam, st, body, len, t]);
    out.push(f);
  }
  return out;
}

module.exports = { loadRocket, buildPlans, fly, readDefines, num };

if (require.main === module) {
  const R = loadRocket();
  const { plans, len, body } = buildPlans(R);
  for (const k of Object.keys(plans)) {
    const P = plans[k];
    console.log(k, 'len', Math.round(P.plan.path.len), 't_end', P.plan.sp.t_end, 'scale', P.plan.sp.scale.toFixed(3));
  }
}
