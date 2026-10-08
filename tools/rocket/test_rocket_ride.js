'use strict';
// test_rocket_ride.js - THE ROCKETS' BUILD GATE (docs/170). Runs on EVERY build, -GscOnly included: the flights,
// the beats and the wiring all live in GSC / zone / alias edits that a script-only build ships.
//
//  1. THE FLIGHTS - the shipping _tod_rocket.gsc and the GENERATED _tod_crown_data / _tod_spire_data, flown frame by
//     frame (ride_sim.js, the GSC run as written by gsc_eval.js) against the generated .map (ride_check.js): every
//     flight (both rides, both landings) must have ZERO hull / camera / camera-step / sky failures.
//  2. THE TIMELINE - every beat fits its ride: the extract's END a few seconds into the climb and before its path
//     ends, its riders let go inside stock's intermission fade; the spire ride's ignite < flame < lift < failure <
//     scream < impact, the chase camera settled behind the ship before the failure; and the letterbox watchdog
//     outlasts the longest ride (LOCKSTEP: TOD_RK_CINE_WATCHDOG_MS == TodRocketCine.lua WATCHDOG_MS).
//  3. THE WIRING - every precached effect / model has its zone line and a real source (no 5 KB stub .efx: the mod
//     tools ship hundreds that link clean and draw nothing), every effect key is precached, every sound define has an
//     alias row (sound/aliases/tod_rocket.csv, or a stock csv the szc loads) whose wav exists, the szc loads
//     tod_rocket.csv, every tod_crown_data:: / tod_spire_data:: call resolves in the generated data, the clip targets
//     exist in the .map, the GDT carries the three models, the finale / spire / main scripts call in, and the two
//     boarding prompts reuse the EXISTING hint strings (the triggerstring budget: the rockets mint none).
//  4. NEGATIVE CONTROLS - a camera snap, a landing through the floor, a missing zone line, a lost alias row and a
//     watchdog shorter than the ride must each FAIL the same checks.
//
//   node tools/rocket/test_rocket_ride.js            (exit 1 on any failure)
const fs = require('fs');
const path = require('path');
const SIM = require('./ride_sim.js');
const RC = require('./ride_check.js');
const { loadMap } = require('./map_clearance.js');
const { V } = require('./gsc_eval.js');

const REPO = path.resolve(__dirname, '..', '..');
const TOOLS = process.env.TOD_MODTOOLS || 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const SCRIPTS = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom');
const rd = p => fs.readFileSync(p, 'utf8');
const fail = [];
const ok = msg => console.log('  ok  ' + msg);
const bad = msg => { fail.push(msg); console.log('  FAIL ' + msg); };

// --------------------------------------------------------------------------------------------------------------
// the sources
// --------------------------------------------------------------------------------------------------------------
const T = {
  gsc: rd(path.join(SCRIPTS, '_tod_rocket.gsc')),
  crown: rd(path.join(SCRIPTS, '_tod_crown_data.gsc')),
  spire: rd(path.join(SCRIPTS, '_tod_spire_data.gsc')),
  finale: rd(path.join(SCRIPTS, '_tod_finale.gsc')),
  spireMod: rd(path.join(SCRIPTS, '_tod_spire.gsc')),
  main: rd(path.join(SCRIPTS, '_tod_main.gsc')),
  zone: rd(path.join(REPO, 'zone_source', 'zm_tower_of_doom.zone')),
  szc: rd(path.join(REPO, 'sound', 'zoneconfig', 'zm_tower_of_doom.szc')),
  csv: rd(path.join(REPO, 'sound', 'aliases', 'tod_rocket.csv')),
  gdt: rd(path.join(REPO, 'source_data', 'tod_fan_props.gdt')),
  lua: rd(path.join(REPO, 'ui', 'uieditor', 'widgets', 'HUD', 'AetheriumWidgets', 'TodRocketCine.lua')),
  map: path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map'),
};
const defs = SIM.readDefines(T.gsc);
const num = k => {
  if (!(k in defs)) throw new Error('missing #define ' + k);
  return Number(String(defs[k]).replace(/[()]/g, ''));
};

// --------------------------------------------------------------------------------------------------------------
// 1. THE FLIGHTS
// --------------------------------------------------------------------------------------------------------------
console.log('[1] the flights (ride_sim + ride_check against the generated .map)');
const R = SIM.loadRocket();
const built = SIM.buildPlans(R);
const M = loadMap(T.map);
const report = RC.check(R, built, M);
function flightFails(r) { return r.hull_fails + r.cam_fails + r.step_fails + r.sky_fails; }
for (const k of Object.keys(report)) {
  const r = report[k];
  const line = `${k}: len ${r.len} t_end ${(+r.t_end).toFixed(2)} vmax ${r.max_speed} hull_clear ${r.min_hull_clear}`
    + (r.min_cam_dist !== null ? ` cam_dist ${r.min_cam_dist} cam_step_max ${r.max_cam_step}` : '');
  if (flightFails(r) === 0) ok(line);
  else bad(`${line} - hull ${r.hull_fails} cam ${r.cam_fails} step ${r.step_fails} sky ${r.sky_fails} `
    + JSON.stringify({ hull: r.first_hull_fails.slice(0, 2), cam: r.first_cam_fails.slice(0, 2), step: r.first_step_fails.slice(0, 2), sky: r.first_sky_fails.slice(0, 2) }));
}
for (const k of ['spire', 'extract', 'land_spire', 'land_extract'])
  if (!report[k]) bad('flight ' + k + ' was not flown');

// --------------------------------------------------------------------------------------------------------------
// 2. THE TIMELINE
// --------------------------------------------------------------------------------------------------------------
function timeline(d, watchdogLua, tImpSpire, tEndExtract, cam) {
  const out = [];
  const n = k => Number(String(d[k]).replace(/[()]/g, ''));
  const climb = n('TOD_RK_X_END') - n('TOD_RK_X_LIFT');
  if (!(climb >= 2 && climb <= 6)) out.push(`extract END ${climb.toFixed(2)} s into the climb (want 2..6: "the game ends a few seconds later")`);
  if (!(n('TOD_RK_X_END') < tEndExtract)) out.push('extract END after its path ends (the ship must still be climbing)');
  if (!(n('TOD_RK_X_IGNITE') < n('TOD_RK_X_FLAME') && n('TOD_RK_X_FLAME') < n('TOD_RK_X_LIFT'))) out.push('extract ignite < flame < lift');
  // stock _zm::end_game -> intermission() ~0.15 s after end_game; player_intermission waits 5, fades 1 s, then sets
  // the intermission sessionstate and SetOrigins: the riders are let go deep in the fade, before that SetOrigin
  const free = n('TOD_RK_X_FREE_AFTER_END');
  if (!(free >= 5.8 && free <= 6.05)) out.push(`extract riders freed ${free} s after END (want 5.8..6.05: inside stock's fade, before its SetOrigin)`);
  if (!(n('TOD_RK_S_IGNITE') < n('TOD_RK_S_FLAME') && n('TOD_RK_S_FLAME') < n('TOD_RK_S_LIFT'))) out.push('spire ignite < flame < lift');
  const failAt = tImpSpire - n('TOD_RK_S_ALARM_LEAD');
  if (!(failAt > n('TOD_RK_S_LIFT') + n('TOD_RK_S_TRAIL_AFTER') + 1)) out.push(`spire failure at ${failAt.toFixed(2)} s is not well after the contrail`);
  if (!(n('TOD_RK_S_ALARM_LEAD') > n('TOD_RK_S_SCREAM_LEAD') && n('TOD_RK_S_SCREAM_LEAD') > n('TOD_RK_S_WHITE_IN_MS') / 1000)) out.push('spire alarm lead > scream lead > white-in');
  if (cam) {
    // the chase camera settles behind the ship before anything happens to it (spire) / before the end (extract)
    if (!(cam.lift_at + cam.settle <= failAt)) out.push('spire camera: still settling behind the ship when the engine fails');
    if (!(n('TOD_RK_X_LIFT') + cam.settle <= n('TOD_RK_X_END'))) out.push('extract camera: still settling behind the ship at the END');
  }
  const board = 0.05 + n('TOD_RK_BLACK_HOLD') + 0.1;
  const spireScreen = board + tImpSpire + n('TOD_RK_S_WHITE_IN_MS') / 1000 + 0.05 + n('TOD_RK_S_WHITE_HOLD') + n('TOD_RK_S_FREE_AFTER');
  const extractScreen = board + n('TOD_RK_X_END');
  const longest = Math.max(spireScreen, extractScreen);
  const wd = n('TOD_RK_CINE_WATCHDOG_MS');
  if (wd !== watchdogLua) out.push(`LOCKSTEP: TOD_RK_CINE_WATCHDOG_MS ${wd} != TodRocketCine.lua WATCHDOG_MS ${watchdogLua}`);
  if (!(wd >= (longest + 8) * 1000)) out.push(`watchdog ${wd} ms does not outlast the longest ride ${longest.toFixed(2)} s by 8 s`);
  if (!(wd <= 60000)) out.push(`watchdog ${wd} ms: a lost OFF would hide the HUD for over a minute`);
  return { out, longest };
}
console.log('[2] the timeline');
const wdLua = Number((/local WATCHDOG_MS = (\d+)/.exec(T.lua) || [])[1]);
const spireCam = built.plans.spire.cam;
const TL = timeline(defs, wdLua, report.spire.t_end, report.extract.t_end, spireCam);
if (TL.out.length) TL.out.forEach(bad);
else ok(`beats fit (spire impact ${(+report.spire.t_end).toFixed(2)} s, extract END ${num('TOD_RK_X_END')} s, longest screen ${TL.longest.toFixed(2)} s, watchdog ${wdLua} ms)`);

// --------------------------------------------------------------------------------------------------------------
// 3. THE WIRING
// --------------------------------------------------------------------------------------------------------------
function csvRows(text) {
  const lines = text.split(/\r?\n/).filter(l => l.trim());
  const split = l => { const o = []; let cur = '', q = false; for (const ch of l) { if (ch === '"') q = !q; else if (ch === ',' && !q) { o.push(cur); cur = ''; } else cur += ch; } o.push(cur); return o; };
  const hdr = split(lines[0]);
  const iName = hdr.indexOf('Name'), iFile = hdr.indexOf('FileSpec'), iCtx = hdr.indexOf('ContextType');
  return lines.slice(1).map(split).map(r => ({ name: r[iName], file: r[iFile], ctx: iCtx >= 0 ? r[iCtx] : '' }));
}
function szcSources(text) {
  return [...text.matchAll(/"Filename"\s*:\s*"([^"]+)"/g)].map(m => m[1]);
}
function efxReal(p) {
  // a real effect, not one of the mod tools' 5 KB stubs (memory stub-efx-in-mod-tools): size + a visual
  if (!fs.existsSync(p)) return 'missing';
  const t = fs.readFileSync(p, 'utf8');
  if (t.length < 6000) return `a ${t.length}-byte stub`;
  // every visual (sprite material, model, sub-effect) is a quoted name on its own line inside an element's block
  if (!/^\t\t"[\w\/.]+"\s*$/m.test(t)) return 'no visual';
  return '';
}
function wiring(W) {
  const out = [];
  const zoneLines = new Set(W.zone.split(/\r?\n/).map(l => l.trim()));
  // the module itself
  if (!zoneLines.has('scriptparsetree,scripts/zm/zm_tower_of_doom/_tod_rocket.gsc')) out.push('zone: no scriptparsetree line for _tod_rocket.gsc');
  for (const lua of ['TodRocketCine.lua', 'TodHudVeil.lua'])
    if (!zoneLines.has('rawfile,ui/uieditor/widgets/HUD/AetheriumWidgets/' + lua)) out.push('zone: no rawfile line for ' + lua);
  // precaches -> zone lines -> sources
  const pre = [...W.gsc.matchAll(/^#precache\(\s*"(\w+)",\s*"([^"]+)"\s*\);/gm)].map(m => ({ kind: m[1], name: m[2] }));
  const fxPre = new Set(pre.filter(p => p.kind === 'fx').map(p => p.name));
  for (const p of pre) {
    if (p.kind === 'fx') {
      if (!zoneLines.has('fx,' + p.name)) out.push('zone: no fx line for ' + p.name);
      const repoSrc = path.join(REPO, 'share', 'raw', 'fx', p.name + '.efx');
      const toolSrc = path.join(TOOLS, 'share', 'raw', 'fx', p.name + '.efx');
      const why = efxReal(fs.existsSync(repoSrc) ? repoSrc : toolSrc);
      if (why) out.push(`fx source ${p.name}: ${why}`);
    } else if (p.kind === 'model') {
      if (!zoneLines.has('xmodel,' + p.name)) out.push('zone: no xmodel line for ' + p.name);
      if (!new RegExp('"' + p.name + '" \\( "xmodel\\.gdf" \\)').test(W.gdt)) out.push('tod_fan_props.gdt: no xmodel block for ' + p.name);
    }
  }
  if (!pre.some(p => p.kind === 'eventstring' && p.name === 'tod_rocket_cine')) out.push('the tod_rocket_cine eventstring is not precached');
  for (const m of W.gsc.matchAll(/level\._effect\[\s*"(\w+)"\s*\]\s*=\s*"([^"]+)"/g))
    if (!fxPre.has(m[2])) out.push(`effect ${m[1]} = ${m[2]} is not precached`);
  // every effect key the script plays (any "tod_rk_*" literal handed to an effect helper) is registered
  for (const m of W.gsc.matchAll(/(?:fx_burst|fx_burst_after|engine_host|engine_burst|fx_play_on_new_host)\(([^;]*)\)/g))
    for (const k of m[1].matchAll(/"(tod_rk_\w+)"/g))
      if (!new RegExp('level\\._effect\\[\\s*"' + k[1] + '"\\s*\\]\\s*=').test(W.gsc)) out.push(`effect key ${k[1]} is played but never registered`);
  // sounds
  const sources = szcSources(W.szc);
  if (!sources.includes('tod_rocket.csv')) out.push('szc: tod_rocket.csv is not a source');
  const ours = csvRows(W.csv);
  for (const r of ours) {
    if (r.ctx) out.push(`tod_rocket.csv ${r.name}: a ContextType row is silent in this map`);
    const f = r.file.replace(/\\/g, '/');
    if (!fs.existsSync(path.join(REPO, 'sound_assets', f)) && !fs.existsSync(path.join(TOOLS, 'sound_assets', f)))
      out.push(`tod_rocket.csv ${r.name}: wav ${f} is in neither sound_assets`);
  }
  const ourNames = new Set(ours.map(r => r.name));
  let stockRows = null;
  for (const m of W.gsc.matchAll(/^#define\s+(TOD_RK_SND_\w+)\s+"([^"]+)"/gm)) {
    const alias = m[2];
    if (ourNames.has(alias)) continue;
    if (alias.startsWith('tod_rk_')) { out.push(`${m[1]} = ${alias}: no row in tod_rocket.csv`); continue; }
    if (!stockRows) {
      stockRows = new Map();
      for (const src of sources) {
        const p = fs.existsSync(path.join(REPO, 'sound', 'aliases', src)) ? path.join(REPO, 'sound', 'aliases', src) : path.join(TOOLS, 'share', 'raw', 'sound', 'aliases', src);
        if (!fs.existsSync(p) || src === 'tod_rocket.csv') continue;
        for (const r of csvRows(fs.readFileSync(p, 'utf8'))) if (!stockRows.has(r.name)) stockRows.set(r.name, { src, file: r.file });
      }
    }
    const row = stockRows.get(alias);
    if (!row) { out.push(`${m[1]} = ${alias}: in no alias csv the szc loads`); continue; }
    const f = row.file.replace(/\\/g, '/');
    if (!fs.existsSync(path.join(REPO, 'sound_assets', f)) && !fs.existsSync(path.join(TOOLS, 'sound_assets', f)))
      out.push(`${m[1]} = ${alias} (${row.src}): wav ${f} missing`);
  }
  // the generated data
  for (const [ns, text] of [['tod_crown_data', W.crown], ['tod_spire_data', W.spire]]) {
    for (const m of new Set([...W.gsc.matchAll(new RegExp(ns + '::(\\w+)', 'g'))].map(x => x[1])))
      if (!new RegExp('function\\s+' + m + '\\s*\\(').test(text)) out.push(`${ns}::${m} is not in the generated data`);
  }
  // the callers
  if (!/^\s*tod_rocket::init\(\s*\);/m.test(W.main)) out.push('_tod_main.gsc never calls tod_rocket::init()');
  if (!/tod_rocket::ride_extract\(\s*\)/.test(W.finale)) out.push('_tod_finale.gsc never calls tod_rocket::ride_extract()');
  if (!/tod_rocket::ride_spire\(\s*\)/.test(W.spireMod)) out.push('_tod_spire.gsc never calls tod_rocket::ride_spire()');
  for (const [file, text] of [['_tod_main.gsc', W.main], ['_tod_finale.gsc', W.finale], ['_tod_spire.gsc', W.spireMod]])
    if (!/#using scripts\\zm\\zm_tower_of_doom\\_tod_rocket;/.test(text)) out.push(file + ' has no #using for _tod_rocket');
  if (!/IS_TRUE\(\s*p\.tod_rocket_riding\s*\)/.test(W.finale)) out.push('_tod_finale.gsc crown_containment_watch does not spare a rider');
  // the prompts: the existing strings, not new ones
  for (const m of W.gsc.matchAll(/board_trigger\(\s*"(\w+)",\s*"([^"]+)"\s*\)/g)) {
    const lit = 'SetHintString( "' + m[2] + '" )';
    if (!W.finale.includes(lit) && !W.spireMod.includes(lit)) out.push(`the ${m[1]} prompt "${m[2]}" is a NEW hint string (reuse the existing one)`);
  }
  return out;
}
console.log('[3] the wiring');
const W = { gsc: T.gsc, crown: T.crown, spire: T.spire, finale: T.finale, spireMod: T.spireMod, main: T.main, zone: T.zone, szc: T.szc, csv: T.csv, gdt: T.gdt };
const wired = wiring(W);
if (wired.length) wired.forEach(bad);
else ok('zone / sources / aliases / wavs / generated data / callers / prompts all wired');
// the clips: the generated targets must exist as entities in the .map
const mapText = fs.readFileSync(T.map, 'utf8');
for (const kind of ['spire', 'extract']) {
  const tn = R.g.call('tod_crown_data::rocket_clip_target', [kind]);
  if (!tn || !mapText.includes('"targetname" "' + tn + '"')) bad(`clip ${kind}: targetname "${tn}" is not in the .map`);
  else ok(`clip ${kind}: ${tn} in the .map`);
}

// --------------------------------------------------------------------------------------------------------------
// 4. NEGATIVE CONTROLS - the same checks must catch a broken input
// --------------------------------------------------------------------------------------------------------------
console.log('[4] negative controls');
function control(name, broke) { if (broke) ok('control caught: ' + name); else bad('NEGATIVE CONTROL NOT CAUGHT: ' + name); }
{
  // a chase camera that jumps from beside the ship on its pad to behind it in 0.1 s (two frames)
  const cam = Object.assign({}, built.plans.spire.cam, { settle: 0.1 });
  const r = RC.check(R, { plans: { spire: { plan: built.plans.spire.plan, cam } }, len: built.len, body: built.body }, M).spire;
  control('a camera snap (settle in 0.1 s)', r.step_fails > 0);
}
{
  // the extract ship landing 300 under its pad (through the hall floor)
  const keys = R.g.call('tod_crown_data::rocket_land_keys', ['extract']).map(k => V(k[0], k[1], k[2] - 300));
  const tans = R.g.call('tod_crown_data::rocket_land_tans', ['extract']);
  const Ts = num('TOD_RK_LAND_SECS');
  const plan = R.g.call('rk_plan', ['land_extract', keys, tans, R.g.call('tod_crown_data::rocket_yaw', ['extract']), [0, Ts * 0.45, Ts * 0.82, Ts], [3400, 1500, 320, 45], true]);
  const r = RC.check(R, { plans: { land_extract: { plan } }, len: built.len, body: built.body }, M).land_extract;
  control('a landing through the hall floor', r.hull_fails > 0);
}
control('a missing fx zone line', wiring(Object.assign({}, W, { zone: W.zone.replace(/^fx,dlc1\/castle\/fx_rocket_exhaust_torch\r?$/m, '') })).length > 0);
control('a lost alias row', wiring(Object.assign({}, W, { csv: W.csv.split(/\r?\n/).filter(l => !l.startsWith('tod_rk_roar,')).join('\n') })).length > 0);
control('a new hint string', wiring(Object.assign({}, W, { gsc: W.gsc.replace('^2EXTRACT^7 - leave the tower', '^2EXTRACT^7 - leave by rocket') })).length > 0);
control('a watchdog shorter than the ride', timeline(Object.assign({}, defs, { TOD_RK_CINE_WATCHDOG_MS: '10000' }), 10000, report.spire.t_end, report.extract.t_end, spireCam).out.length > 0);
control('the riders freed after stock sets them down', timeline(Object.assign({}, defs, { TOD_RK_X_FREE_AFTER_END: '6.5' }), wdLua, report.spire.t_end, report.extract.t_end, spireCam).out.length > 0);

if (fail.length) {
  console.log(`test_rocket_ride FAILED (${fail.length})`);
  process.exit(1);
}
console.log('test_rocket_ride OK: 4 flights clear, the beats fit, the wiring holds, 7 negative controls caught');
