// test_zombie_blood_filter.js - v19.65: Zombie Blood's own screen filter, wired
// through visionset_mgr (_tod_powerups.gsc + .csc). Static + a timing model.
//
// WHY THIS EXISTS: Zombie Blood's visual was removed on 2026-08-26 because it
// activated a visionset_mgr name that nothing REGISTERED - activate() hard-errors
// on that, the window thread died, and one pickup left the player ignored and
// invulnerable for the rest of the match. This pins every link of the new chain:
//   1. both halves register the SAME lower-case name, version and lerp steps, in
//      their first-frame REGISTER_SYSTEM __init__ (register_info lower-cases what
//      it STORES, activate() looks up what it is GIVEN - a capital letter is the
//      August crash again);
//   2. the priority is unique among the overlays this map and stock ZM register;
//   3. the filter material is Treyarch's Zombie Blood filter, present in the
//      retail zm_common asset list;
//   4. the window starts the filter AFTER its state writes and in its OWN thread,
//      clear() stops it in its own thread, and stop's notify comes last;
//   5. THE TIMING, modelled frame by frame from the real defines: the fade reaches
//      zero on the frame the window expires; a re-grab never dips and restarts
//      the clock; a down cuts it the same frame.
//   node tools/test_zombie_blood_filter.js
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const root = path.join(__dirname, '..');
const read = f => fs.readFileSync(path.join(root, f), 'utf8').replace(/\r\n/g, '\n');
const gsc = read('scripts/zm/zm_tower_of_doom/_tod_powerups.gsc');
const csc = read('scripts/zm/zm_tower_of_doom/_tod_powerups.csc');
const num = (src, k) => Number((src.match(new RegExp('#define\\s+' + k + '\\s+([-\\d.]+)')) || [])[1]);
const str = (src, k) => (src.match(new RegExp('#define\\s+' + k + '\\s+"([^"]+)"')) || [])[1];
const body = (src, name) => {
  const i = src.indexOf('\nfunction ' + name + '(');
  assert.ok(i >= 0, 'function ' + name + ' exists');
  const j = src.indexOf('\n}', i);
  return src.slice(i, j + 2);
};
let checks = 0;
const ok = (c, m) => { assert.ok(c, m); checks++; };

// ---- 1. the registration, both halves --------------------------------------
const NAME = str(gsc, 'TOD_BLOOD_VSMGR');
ok(NAME && NAME === str(csc, 'TOD_BLOOD_VSMGR'), 'same overlay name on both halves');
ok(NAME === NAME.toLowerCase(), 'the name is lower case (register_info stores it lowered; activate looks it up as given)');
const LERP = num(gsc, 'TOD_BLOOD_VS_LERP');
ok(LERP > 1 && LERP === num(csc, 'TOD_BLOOD_VS_LERP'), 'same lerp step count on both halves');
ok(gsc.includes('#using scripts\\shared\\visionset_mgr_shared;') && csc.includes('#using scripts\\shared\\visionset_mgr_shared;'), 'both halves #using visionset_mgr_shared');
ok(csc.includes('#using scripts\\shared\\filter_shared;') && csc.includes('#using scripts\\shared\\callbacks_shared;'), 'client #using filter + callbacks');
const gInit = body(gsc, '__init__'), cInit = body(csc, '__init__');
ok(gsc.includes('REGISTER_SYSTEM( "tod_powerups", &__init__, undefined )') && csc.includes('REGISTER_SYSTEM( "tod_powerups", &__init__, undefined )'), 'both registrations run from REGISTER_SYSTEM __init__ (first frame)');
ok(gInit.includes('visionset_mgr::register_info( "overlay", TOD_BLOOD_VSMGR, VERSION_SHIP, TOD_BLOOD_VS_PRIO, TOD_BLOOD_VS_LERP, true, &visionset_mgr::ramp_in_out_thread_per_player, false );'), 'server: per-player overlay, ramp_in_out lerp thread, in __init__');
ok(cInit.includes('visionset_mgr::register_overlay_info_style_filter( TOD_BLOOD_VSMGR, VERSION_SHIP, TOD_BLOOD_VS_LERP, TOD_BLOOD_FILTER_INDEX, TOD_BLOOD_FILTER_PASS, TOD_BLOOD_FILTER, TOD_BLOOD_FILTER_FADE );'), 'client: filter-style overlay in __init__');
ok(cInit.includes('callback::on_localclient_connect( &blood_filter_map );') && cInit.includes('callback::on_localplayer_spawned( &blood_filter_map );'), 'client maps the material at connect and spawn');
ok(body(csc, 'blood_filter_map').includes('filter::map_material_if_undefined( localClientNum, TOD_BLOOD_FILTER );'), 'client fills level.filter_matid for the overlay');

// ---- 2. unique priority -------------------------------------------------------
const PRIO = num(gsc, 'TOD_BLOOD_VS_PRIO');
const STOCK_OVERLAY_PRIOS = [21, 22, 27, 60, 61];   // gel splat, health blur, flashback, trap electric, factory teleport
ok(!STOCK_OVERLAY_PRIOS.includes(PRIO), 'priority clear of stock ZM overlays');
const repoPrios = [];
for (const dir of ['scripts']) {
  const walk = d => fs.readdirSync(path.join(root, d), { withFileTypes: true }).forEach(e => {
    const p = d + '/' + e.name;
    if (e.isDirectory()) return walk(p);
    if (!/\.gsc$/.test(e.name)) return;
    const s = read(p);
    for (const m of s.matchAll(/visionset_mgr::register_info\(\s*"overlay"\s*,\s*[^,]+,\s*[^,]+,\s*([A-Za-z_0-9.]+)/g)) repoPrios.push(m[1]);
  });
  walk(dir);
}
ok(repoPrios.filter(p => p === 'TOD_BLOOD_VS_PRIO' || Number(p) === PRIO).length === 1, 'no other overlay in the repo uses the same priority');

// ---- 3. the material ----------------------------------------------------------
ok(str(csc, 'TOD_BLOOD_FILTER') === 'generic_filter_zombie_blood', "Treyarch's Zombie Blood filter material");
const assetlist = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/zone_source/all/assetlist/zm_common.csv';
if (fs.existsSync(assetlist)) {
  const al = fs.readFileSync(assetlist, 'utf8');
  ok(/^material,generic_filter_zombie_blood\s*$/m.test(al) && /^techset,zombie_blood#/m.test(al), 'retail zm_common carries the material + its zombie_blood techset');
}
ok(num(csc, 'TOD_BLOOD_FILTER_PASS') === 0 && num(csc, 'TOD_BLOOD_FILTER_FADE') === 0, 'pass 0 / constant 0 = the stock generic_filter amount');
// v19.65b - THE TINT (user, first build: "definitely a distortion but no tint"). The
// shader (zombie_blood.techsetdef -> postfx/zombie_blood.hlsl, disassembled) reads
// scriptVector0 only: .x warp, .y colour layer + blood motes, .z colour-mask reach.
// Stock's filter style writes ONE constant, so the custom enable must write all three
// and the tint needs BOTH .y and .z above zero.
ok(num(csc, 'TOD_BLOOD_WARP') > 0 && num(csc, 'TOD_BLOOD_TINT') > 0 && num(csc, 'TOD_BLOOD_MASK') > 0, 'warp, tint and mask are all non-zero (tint needs constants 1 AND 2)');
const iReg = cInit.indexOf('visionset_mgr::register_overlay_info_style_filter(');
const iHook = cInit.indexOf('level.vsmgr_filter_custom_enable[ TOD_BLOOD_FILTER ] = &blood_filter_enable;');
ok(iReg >= 0 && iHook > iReg, 'the custom enable is installed in __init__, after the registration (visionset_mgr has made the table by then)');
const en = body(csc, 'blood_filter_enable');
ok(en.includes('setfilterpassenabled( lcn, curr_info.filter_index, curr_info.pass_index, true );') && en.includes('filter::mapped_material_id( curr_info.material_name )'), 'custom enable sets the material and enables the pass');
ok(en.includes('curr_info.pass_index, 0, TOD_BLOOD_WARP * f );') && en.includes('curr_info.pass_index, 1, TOD_BLOOD_TINT * f );') && en.includes('curr_info.pass_index, 2, TOD_BLOOD_MASK );'), 'constants 0 (warp) and 1 (tint) follow the fade, 2 (mask reach) is set');
ok(en.includes('f = state.curr_lerp;'), 'the fade is the manager lerp (the server timing)');
// v19.65b - THE STOCK SWITCH-OFF TRAP (the user's first test logged "undefined is not
// an array index" in visionset_mgr_shared.csc as Zombie Blood ended): its FILTER
// disable branch indexes custom_disable[ curr_info.material_name ] with the slot it
// switches TO ("__none", no material_name) and throws before disabling the pass.
// The guard gives every overlay info a placeholder material_name; it must run at
// connect AND before each switch-on (so it has always run before a switch-off).
const guard = body(csc, 'blood_filter_guard_infos');
ok(guard.includes('foreach ( name, info in level.vsmgr[ "overlay" ].info )') && guard.includes('if ( isdefined( info ) && !isdefined( info.material_name ) )'), 'guard fills ONLY missing material names, across every overlay info');
ok(body(csc, 'blood_filter_map').includes('blood_filter_guard_infos();'), 'guard runs at local-client connect / spawn');
ok(en.indexOf('blood_filter_guard_infos();') >= 0 && en.indexOf('blood_filter_guard_infos();') < en.indexOf('setfilterpassenabled('), 'guard runs at every switch-on, before the pass is enabled');
const tsd = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/share/raw/techsetdefs_stable/2d/zombie_blood.techsetdef';
if (fs.existsSync(tsd)) {
  const t = fs.readFileSync(tsd, 'utf8');
  ok(t.includes('source = "postfx/zombie_blood.hlsl"') && t.includes('Texture( "colorMap" )') && t.includes('float1( "warpPixels" )'), 'the techset is the one the constant map was read from');
}

// ---- 4. the wiring in the window --------------------------------------------
const win = body(gsc, 'zombie_blood_window');
const iRegrab = win.indexOf('b_regrab = IS_TRUE( self.tod_in_blood );');
const iInBlood = win.indexOf('self.tod_in_blood = true;');
const iTime = win.indexOf('self.zombie_vars[ "zombie_powerup_zombie_blood_time" ] = TOD_BLOOD_SECS;');
const iStart = win.indexOf('self thread zombie_blood_fx_start( b_regrab );');
const iLoop = win.indexOf('while ( IS_TRUE( self.tod_in_blood )');
ok(iRegrab >= 0 && iRegrab < iInBlood, 'regrab is read BEFORE tod_in_blood is set');
ok(iStart > iInBlood && iStart > iTime && iStart < iLoop, 'filter starts after every state write, before the countdown');
// Comments are stripped first: the window keeps the August line quoted in its
// history note (memory comments-are-data-to-a-scanner).
const code = s => s.replace(/\/\/.*$/gm, '');
ok(!/visionset_mgr::activate/.test(code(win)), 'the window never calls activate itself (only the threaded start does)');
ok((code(gsc).match(/visionset_mgr::activate\(/g) || []).length === 1 && body(gsc, 'zombie_blood_fx_start').includes('visionset_mgr::activate( "overlay", TOD_BLOOD_VSMGR, self, ramp_in, &zombie_blood_fx_hold, TOD_BLOOD_FX_OUT );'), 'exactly one activate, with the countdown-driven hold');
ok(!/zm_bgb_in_plain_sight"\s*,/.test(gsc.replace(/\/\/.*$/gm, '')), 'the August unregistered name is not called anywhere (comments aside)');
const clr = body(gsc, 'zombie_blood_clear');
ok(clr.includes('self thread zombie_blood_fx_stop('), 'clear() stops the filter in its own thread');
const stop = body(gsc, 'zombie_blood_fx_stop');
ok(stop.lastIndexOf('self notify( "tod_blood_fx_done" );') > stop.indexOf('visionset_mgr::deactivate( "overlay", TOD_BLOOD_VSMGR, self );'), "stop's notify comes after the deactivate (the end_game watcher calls it inline)");
ok(body(gsc, 'zombie_blood_fx_end_game').includes('level waittill( "end_game" );'), 'the game-over screen loses the filter');
const hold = body(gsc, 'zombie_blood_fx_hold');
ok(hold.includes('while ( IS_TRUE( self.tod_in_blood ) && zombie_blood_left( self ) > TOD_BLOOD_FX_OUT )'), 'hold = the window countdown, released TOD_BLOOD_FX_OUT early');

// ---- 5. THE TIMING MODEL ------------------------------------------------------
// Server frames of 50 ms. The window: time = SECS, then each frame `wait 0.05`
// followed by time -= 0.05, loop while in_blood && time > 0, then clear().
// The ramp thread (stock ramp_in_out_thread_per_player_internal): ramp in over
// ramp_in (lerp = elapsed/ramp_in, set each frame, WAIT_SERVER_FRAME), hold
// (zombie_blood_fx_hold: WAIT_SERVER_FRAME while in_blood && time > FX_OUT),
// ramp out over FX_OUT (lerp = remaining/FX_OUT), then deactivate.
const SECS = num(gsc, 'TOD_BLOOD_SECS'), FX_IN = num(gsc, 'TOD_BLOOD_FX_IN'), FX_OUT = num(gsc, 'TOD_BLOOD_FX_OUT');
ok(FX_IN + FX_OUT < SECS, 'fades fit inside the window');
const F = 0.05;
function simulate(events) {   // events: { regrab: [frames], down: frame }
  const s = { time: SECS, inBlood: true, clearFrame: null, lerp: 0, fxOn: true, phase: 'in', t0: 0, rampIn: FX_IN, log: [] };
  for (let f = 1; f < 2000; f++) {
    const now = f * F;
    if (events.regrab && events.regrab.includes(f)) {   // the new window: time full, ramp-in 0, fresh ramp thread
      s.time = SECS; s.inBlood = true; s.fxOn = true; s.phase = 'in'; s.t0 = now; s.rampIn = 0; s.clearFrame = null;
    }
    if (events.down === f && s.inBlood) { s.inBlood = false; s.clearFrame = f; s.fxOn = false; s.lerp = 0; s.offFrame = f; }   // the laststand guard -> clear() -> stop
    // window loop body: wait 0.05 then decrement (this frame's tick)
    if (s.inBlood && s.clearFrame === null) {
      s.time = Math.round((s.time - F) * 1000) / 1000;
      if (s.time <= 0) { s.inBlood = false; s.clearFrame = f; }
    }
    // ramp thread
    if (s.fxOn) {
      if (s.phase === 'in') {
        const frac = s.rampIn <= 0 ? 1 : Math.min(1, (now - s.t0) / s.rampIn);
        s.lerp = frac; if (frac >= 1) s.phase = 'hold';
      }
      if (s.phase === 'hold' && !(s.inBlood && s.time > FX_OUT)) { s.phase = 'out'; s.tOut = now; }
      if (s.phase === 'out') {
        s.lerp = Math.max(0, 1 - (now - s.tOut) / FX_OUT);
        if (s.lerp <= 0) { s.fxOn = false; s.offFrame = f; }
      }
      if (s.lerp > 0) s.lastOn = f;
    }
    if (s.clearFrame !== null && s.clearFrame === f && s.fxOn) { s.fxOn = false; s.lerp = 0; s.offFrame = f; }   // clear() -> stop
    s.log.push(s.lerp);
    if (!s.inBlood && !s.fxOn && s.clearFrame !== null && f > s.clearFrame + 5) break;
  }
  return s;
}
{ // a plain grab: the fade ends with the window
  const s = simulate({});
  ok(Math.abs(s.clearFrame * F - SECS) < 1e-9, 'window expires at ' + SECS + ' s');
  ok(Math.abs(s.offFrame - s.clearFrame) <= 1, `filter reaches zero within one frame of expiry (off ${s.offFrame * F}s vs expiry ${s.clearFrame * F}s)`);
  ok(s.log.slice(Math.round(FX_IN / F), Math.round((SECS - FX_OUT) / F) - 1).every(v => v === 1), 'full strength from the end of the fade-in to the start of the fade-out');
}
const at = (s, f) => s.log[f - 1];   // log[i] holds frame i + 1
{ // a re-grab in the middle: no dip, the clock restarts
  const g = Math.round(8 / F);
  const s = simulate({ regrab: [g] });
  ok(at(s, g - 1) === 1 && at(s, g) === 1 && at(s, g + 1) === 1, 'a mid-window re-grab never dips');
  ok(Math.abs(s.clearFrame - (g + SECS / F)) <= 1 && Math.abs(s.offFrame - s.clearFrame) <= 1, 'the re-grab window ends 15 s later, filter with it');
}
{ // a re-grab during the final fade: back to full at once
  const g = Math.round((SECS - FX_OUT / 2) / F);
  const s = simulate({ regrab: [g] });
  ok(at(s, g - 1) < 1 && at(s, g) === 1, 'a re-grab during the fade snaps back to full');
}
{ // a down: cut the same frame
  const d = Math.round(5 / F);
  const s = simulate({ down: d });
  ok(s.offFrame === d && at(s, d - 1) === 1 && at(s, d) === 0, 'a down cuts the filter the frame it clears');
}
console.log(`Zombie Blood filter wiring + timing: ${checks} checks passed (name "${NAME}", prio ${PRIO}, ${LERP} steps, in ${FX_IN}s / out ${FX_OUT}s inside ${SECS}s)`);
