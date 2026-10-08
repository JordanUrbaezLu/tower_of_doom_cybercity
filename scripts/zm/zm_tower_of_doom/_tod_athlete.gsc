// =============================================================================
// _tod_athlete.gsc — ATHLETE, the SLASHER's mobility upgrade (domain 43)
//
// v16    (2026-09-01): "a new upgrade to melee where they can slide faster and
//         jump higher ... called athlete ... 5 tiers 10% slide speed each tier
//         and 25% jump height increase each tier" + "make it so that you dont
//         really lose speed when you jump out of a slide and you have athlete".
// v16.1  (2026-09-01, after the user PLAYED v16): "that slide speed boost never
//         transfers momentum properly to the jump so you slow down a ton" —
//         jump_max_velocity found and set to 1000 (the mistake, see v16.31).
// v16.23 (2026-09-02, after the user PLAYED v16.21): "athlete is not so smooth.
//         It kind of speed boosts when you jump out of a slide ... It also
//         needs more aerial handling meaning you can keep velocity but change
//         directions in the air very very easily ... increases with each
//         level ... comical for now ... Smoothness should not be comical."
// v16.24 (2026-09-02, after the user PLAYED v16.23): "its for sure comical.
//         But we know its possible. Now its about smoothing it out and making
//         it make sense ... keep max momentum up to 120 degrees in front of
//         them ... poll every 10ms ... i can slide and then go backwards max
//         speed. Obviously that doesnt make sense."
// v16.28 (2026-09-02, fresh-eyes review; user: "Do what ever players would
//         find intuitive and a bit beyond that to make it fun.") Six fixes.
// v16.31 (2026-09-02, after the user PLAYED v16.28): "When jumping out of my
//         slide im launching. We need a creative way to keep the speed of the
//         player throught the slide jump with calculations or something ...
//         Still feels like i slide then jump and my jump is launching me in
//         the direction. Like its a stutter step and randomly gain speed".
//         And, to be clear: "this really only needs to apply to players with
//         athlete. I have no complains about how it works without athlete ...
//         All these changes are for the athlete upgrade." — so EVERY engine
//         dvar this file touches now rests at STOCK and moves only while an
//         athlete is in the state that consumes it.
// v16.33 (2026-09-02, after the user PLAYED v16.31): "Still not super smooth
//         you should be able to change direction as much. here should be a
//         max steer limit. Also still kinda launching. I think it got better
//         tho." — a hard STEER BUDGET per air episode, a lower eased rate, and
//         the cap PRE-ARMED while an athlete is grounded (the first-50 ms hop
//         was launching against a poisoned rest value; see PRE-ARM below).
// v16.34 (2026-09-02): "Any chance of adding wall running for athlete?" —
//         EXPERIMENTAL WALL-RUN, athletes only (see WALL-RUN below). UNPLAYED.
//
// HOW IT PLAYS (per level, additive across levels)
//   * slides start 10% faster (so they also run longer);
//   * jumps go 25% higher;
//   * a jump straight out of a slide leaves the ground at EXACTLY the slide's
//     speed and rises to exactly the level's height, with no script write at
//     all — the engine does both, client-predicted (lane 1, v16.31);
//   * IN THE AIR you steer with the STRAFE axis: push left/right and your
//     velocity heading curves that way (relative to where you look) at
//     90 + 30/Lv deg/s (120 .. 240), eased, speed unchanged, and BY AT MOST
//     20 + 8/Lv degrees (28 .. 60) off the line you launched on — the steer
//     budget of that jump. Forward/back on the stick never steer — aiming
//     behind you while you hop away does not pull you back into the horde;
//   * momentum is FREE anywhere in the front hemisphere of your launch line
//     (the cone; inert under a 60-deg budget, kept as the safety net);
//   * (v16.34, experimental) you can WALL-RUN: jump at a wall and run along
//     it — the engine's own BO3 wall-run, switched off for zombies by stock
//     and switched back on here for athletes only.
//   Every script write in this file has a `self` receiver; the three engine
//   dvars are written just-in-time (below) so they act on one player at a time.
//
// -----------------------------------------------------------------------------
// WALL-RUN (v16.34, EXPERIMENTAL — read this before trusting it)
// -----------------------------------------------------------------------------
// BO3's wall-run is an ENGINE feature (the MP advanced movement). Stock zombies
// turns it off with one line, `SetDvar( "wallrun_enabled", 0 )` in _zm.gsc:221,
// beside doublejump / juke / sprintLeap / playerEnergy. The API also carries a
// PER-PLAYER gate, `<player> AllowWallRun( <on off> )` ("Sets whether the
// player can wall run"), and a server-side `IsWallRunning()`. So:
//   * the master switch goes back to 1 for the match (probe-first),
//   * EVERY player is denied at spawn (AllowWallRun false, before the watcher's
//     first tick), and the watcher allows it only while the ATHLETE level is
//     above 0 — re-applied whenever the cached state disagrees, and the cache
//     is cleared on every spawn in case stock resets the flag,
//   * while IsWallRunning() the engine owns movement: this file publishes
//     "airborne" (the stumble lane), parks lanes 3 and 4, and the tick after
//     the run ends starts a fresh air episode with NO edge — the wall-jump off
//     the wall is the engine's own launch (wallRun_jumpHeight /
//     wallRun_jumpVelocity), never multiplied or insured.
// WHAT IS NOT KNOWN (one dev test answers all of it; the dev print now lists
// the wallRun_* family): whether the engine's initiation rules, tuned for MP
// boost-jumps — wallRun_minJumpHeight(Enable), wallRun_peakTest,
// wallRun_minTriggerSpeed, wallRun_minZVel — let a zombies jump attach at all
// (the athlete's 2.25x jump helps); whether the zombies player animation set
// has wall-run states (first person is camera roll + viewmodel; third person
// matters in co-op); and whether playerEnergy_enabled 0 leaves the run bounded
// by wallRun_maxTimeMs alone. Geometry is fine: every parapet carries a 112
// clip cap and every door an anti-vault clip, so a wall-run cannot leave a
// flight or pass a shut door. TOD_ATH_WALLRUN 0 removes the whole lane.
//
// -----------------------------------------------------------------------------
// THE v16.31 FINDING — jump_max_velocity IS THE SLIDE-JUMP LAUNCH SPEED
// -----------------------------------------------------------------------------
// Treyarch: "The max velocity of the players jump if they enter it from a
// slide." v16.1 read that as a CLAMP on the slider's own speed and set it to
// 1000 so the clamp "stopped". The complaint pattern says otherwise:
//   engine default (v16)  -> "you slow down a ton"      (launch = the default)
//   1000 (v16.21)         -> "kind of speed boosts"     (launch up to 1000, the
//                                                        script cut it a tick later)
//   1000, no cut (v16.28) -> "launching ... stutter step and randomly gain speed"
// The engine LAUNCHES a slide-jump at up to jump_max_velocity — an assignment
// or a cap on its own boost, the trace's `jmv=` vs `launch=` tells which — and
// it does so on the CLIENT, at frame rate. A script that notices one server
// frame later and cuts the speed back is the "stutter step"; without the cut
// it is the "launch". So the value must be RIGHT BEFORE THE JUMP, and "right"
// is a per-player number (the slider's own speed). The dvar is global.
//
// THE JUST-IN-TIME RULE (lane 1): a global dvar becomes per-player if it is
// written from the one player who is in the state that consumes it, every
// frame of that state, and rested otherwise. A slide-jump can only happen
// while sliding, so every SLIDING tick of an athlete writes
//   jump_max_velocity = that player's current horizontal speed
//   jump_height       = the engine's base height x (1 + 0.25 * Lv)
// and the first non-sliding tick rests both at the engine's PRISTINE defaults.
// The engine's own launch is then the slide speed and the level's height, by
// construction, client-predicted, zero script writes on the slide-jump. The
// same rule carries the landing stumble (jump_slowdownEnable, off since v16.2
// on the user's "forward velocity" steer): OFF while an athlete is airborne,
// stock otherwise. In co-op the values are the MAX over everyone currently in
// the state (jit_update); the exposure is a non-athlete slide-jumping INSIDE
// an athlete's slide (~0.5 s windows) or landing inside an athlete's flight
// (~1 s windows) getting the athlete's numbers — the script insurance below
// cannot see a non-athlete, so that is the accepted cost, documented in
// docs/62 §9.9. The rest values are STOCK — which also undoes v16.1/v16.2's
// silent whole-map changes (every class launched at up to 1000 out of a slide
// and lost its landing stumble from v16.1 to v16.28, and nobody but the
// slasher was tested). User 2026-09-02: "this really only needs to apply to
// players with athlete."
//
// PRISTINE CAPTURE: dvars persist across map loads within one GAME session,
// so the value read at init may be OUR previous write. The first init of a
// game session (no tod_ath_jit_written marker yet) stores the live values in
// script dvars (tod_ath_orig_*) and every later init reads THOSE and never
// captures again. A session that already ran v16.1..v16.28 has 1000 live at
// its first capture: that value is REFUSED (v16.33), forgotten, and the rest
// falls back to the engine's own slide_speedBase (then 400) until the game is
// restarted and a clean capture happens. The dev print reports all of it.
//
// PRE-ARM (v16.33 — "still kinda launching"): the watcher only sees a slide
// on the first SERVER tick after it began, so a slide-hop pressed inside the
// slide's first 50 ms launches against whatever the cap was BEFORE the slide.
// With a poisoned rest that was 1000 — a rocket, "randomly". While an athlete
// is grounded the cap is now held at the engine's own slide start speed (the
// measured slide_ref, else slide_speedBase), so that early hop keeps exactly
// the speed it had — the lane-2 multiply had not landed either. The height is
// NOT pre-armed: jump_height would then boost every jump of every player
// while an athlete stands anywhere, which is the whole-map change the user
// ruled out; an early hop gets the one-frame vz multiply instead.
//
// -----------------------------------------------------------------------------
// THE MODEL — momentum is PRESERVED at every edge, never ADDED
// -----------------------------------------------------------------------------
// The only speed source above sprint is the slide-start multiply (the spec).
// Every other write either copies the current magnitude (steering), trims it
// (the cone), or — insurance only — restores the slide's magnitude when the
// engine's launch disagrees with it by more than friction can explain.
//
// LANE 1 — ENGINE, just-in-time (above), three dvars: jump_max_velocity and
//   jump_height while an athlete SLIDES, jump_slowdownEnable while an athlete
//   is AIRBORNE. Probe-first: an unregistered dvar is never written (SetDvar
//   would mint a dead script dvar and look like success) and that lane simply
//   stays off.
//
// LANE 2 — SCRIPT, per player, the SLIDE START: on the first sliding tick the
//   horizontal velocity becomes BASE x (1 + 0.10*Lv), one-shot (sliding writes
//   stick — map 1 measured this — so a per-tick multiply would compound).
//   THE CLEAN-ENTRY RULE: if the player entered the slide from a normal speed
//   (previous tick under TOD_ATH_CLEAN_ENTRY), BASE is what the engine started
//   THIS slide at, and that number is remembered as the player's slide
//   reference. If they entered it FAST (a slide-jump landing rolled straight
//   into a slide), BASE is the remembered reference, raise-only. ONE dev
//   reading retires this rule if `eng` is constant across slides (docs/62 §9.5).
//
// LANE 3 — SCRIPT, per player, THE JUMP EDGE. An edge is ground->air, or
//   air->air with vz rising by TOD_ATH_HOP_DVZ (the bunny hop), inside the
//   engine's launch band, WITH a jump press inside TOD_ATH_JUMP_LATCH_MS.
//   Modes: "slide" (the previous tick was sliding — lane 1 was in force at the
//   launch), "standup" (within TOD_ATH_DIRECT_MS of a slide but grounded
//   frames in between — the engine treats it as a normal jump), "run", "hop".
//   * height: the vz multiply (z only, sqrt of the height factor) on every
//     mode EXCEPT "slide" when the JIT height lane is on — the engine already
//     launched at the boosted height and a write would double it;
//   * INSURANCE, "slide" only: the launch should equal the last sliding tick's
//     speed (that is what lane 1 wrote). More than TOD_ATH_EDGE_BOOST above it
//     means lane 1 was not in force (unregistered, or a remote client's copy
//     lagging) and the speed is cut back; more than TOD_ATH_EDGE_CLAMP below it
//     is a shortfall friction cannot produce and the speed is put back. Either
//     write is one frame late — the stutter — so they exist to be measured
//     (`launch=B>A`, B==A is the success signature), not to be relied on.
//
// LANE 4 — SCRIPT, per player, STRAFE STEERING + THE STEER BUDGET + THE CONE:
//   every airborne tick the strafe axis of the movement stick
//   (GetNormalizedMovement()[1] — the LEFT stick / A-D, confirmed live in
//   v16.23) becomes a wish direction to the left or right OF THE VIEW, and the
//   velocity HEADING rotates toward it by up to (TOD_ATH_AIR_TURN_BASE +
//   TOD_ATH_AIR_TURN_PER_LV * Lv) * deflection * tick degrees, EASED (never
//   more than TOD_ATH_AIR_EASE of the remaining gap in one frame, so the curve
//   arrives instead of snapping), inside a TOD_ATH_AIR_DEADBAND, and NEVER
//   further than (TOD_ATH_AIR_STEER_MAX_BASE + TOD_ATH_AIR_STEER_MAX_PER_LV *
//   Lv) degrees from the heading the air episode began on — the STEER BUDGET
//   (v16.33, user: "there should be a max steer limit"). The magnitude is
//   untouched by the rotation. THE CONE: every air episode is ANCHORED on the heading and
//   speed it began with (its first airborne tick; re-anchored if an external
//   impulse throws the speed past cap x TOD_ATH_AIR_REANCHOR). The cap =
//   launch speed x air_retain(deviation from the anchor): 1.0 in the front
//   hemisphere, linear to TOD_ATH_AIR_REVERSE_KEEP at 180 deg, never under
//   TOD_ATH_AIR_CAP_FLOOR. Speed above the cap is trimmed.
//   THERE IS NO 10 ms LANE (the user asked for one): the server frame is 50 ms
//   (shared.gsh:264 `SERVER_FRAME .05`), every script wait rounds up to it, no
//   faster wait exists in T7 GSC, and Treyarch's dvar table carries no server
//   tick-rate dvar. Smoothness is STEP SIZE PER FRAME and FEWER WRITES — which
//   is exactly why v16.31 moved the slide-jump off script entirely.
//   WHY A SERVER ROTATION AND NOT THE ENGINE'S OWN AIR CONTROL: the engine's
//   air accelerate rides the move-speed scale, which ALSO drives ground
//   acceleration and is still in force on the landing frames until the server
//   sees the landing — at the scales this needs, a landing rocket. An analysis,
//   not a measurement; worth one dev jump before it is called dead for good.
//
// -----------------------------------------------------------------------------
// MEASUREMENT (tod_dev builds only — the ship state prints nothing)
// -----------------------------------------------------------------------------
//   * dev_print_movement_dvars() at the dev block in _tod_main::init — now also
//     the two JIT lanes: live value, rest value, pristine value, and the
//     POISONED warning.
//   * One bold line per slide: "ATH slide eng=E set=S next=N end=Z Tms
//     clean=C ref=R".
//   * One bold line per air episode that began with an edge: "ATH jump
//     slide|standup|run|hop|nojump pre=P jmv=J jh=H launch=B>A vz=V minair=M
//     air=Nt turn=T/Smax strafe=R dev=D keep=K% land=L +300ms=Q". On a "slide"
//     line: B == P == J is lane 1 working (the engine launched at the slide
//     speed); B == J != P means the dvar is an ASSIGNMENT and P was stale;
//     B >> J means the dvar is not in force on this host; A != B means the
//     insurance wrote (the stutter). "nojump" while sprinting up a flight is
//     the crest-hop measurement.
//
// Domain 43 in _tod_upgrade_ui::domain_id + tod_upgrade.lua DOMAIN/DETAIL[43]
// (LOCKSTEP: 120 + 60/Lv deg/s and the 35% reversal figure are copied into
// DETAIL[43].act). This module imports _tod_upgrades for get_level;
// _tod_upgrades never imports us (the KB cycle rule) and reads nothing of ours.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#using scripts\zm\zm_tower_of_doom\_tod_upgrades;   // get_level

#insert scripts\shared\shared.gsh;

#define TOD_ATH_DOMAIN          "athlete"

// THE USER'S NUMBERS. All PER LEVEL and ADDITIVE across levels — "+25% each
// tier" is +25/50/75/100/125% total, not 1.25^n.
#define TOD_ATH_JUMP_PER_LV     0.25   // +25% apex HEIGHT per level
#define TOD_ATH_SLIDE_PER_LV    0.10   // +10% slide START SPEED per level (velocity multiply, lane 2)

// ---- LANE 1: ENGINE DVARS, JUST-IN-TIME (read the header) --------------------
#define TOD_MOVE_SLIDE_JUMP_TRACK      1    // 1 = jump_max_velocity follows the sliding athlete's speed every sliding tick (and is pre-armed at the slide start speed while grounded)
#define TOD_MOVE_SLIDE_JUMP_REST       0    // rest value when nobody slides: 0 = the engine's pristine default; >0 = this number
#define TOD_MOVE_SLIDE_JUMP_FALLBACK   400  // rest when the pristine default is unknown or poisoned AND slide_speedBase is unregistered
#define TOD_MOVE_SLIDE_JUMP_HEIGHT_JIT 1    // 1 = jump_height follows the sliding athlete's height factor (no vz write on a slide-jump)
#define TOD_MOVE_LAND_STUMBLE_OFF      1    // 1 = jump_slowdownEnable 0 while an athlete is AIRBORNE, stock otherwise (was a global write v16.2..v16.28)
// ---- WALL-RUN (v16.34, experimental) -------------------------------------------
#define TOD_ATH_WALLRUN                1    // 1 = wallrun_enabled 1 for the match + AllowWallRun(true) for athletes only (false for everyone else); 0 = stock (off)
// THE WALL-RUN LADDER (v16.38): each wallRun_* dvar below is published while an
// athlete is airborne as pristine x mult(level) and rested otherwise. Only
// athletes can be in the state (AllowWallRun), so no other player ever feels it.
#define TOD_ATH_WR_TIME_PER_LV   0.25  // wallRun_maxTimeMs x (1 + this*Lv): longer runs (Lv5 2.25x)
#define TOD_ATH_WR_SPEED_PER_LV  0.05  // wallRun_speedScale x (1 + this*Lv): faster along the wall (Lv5 +25%)
#define TOD_ATH_WR_EASE_PER_LV   0.08  // wallRun_minTriggerSpeed / minJumpHeight / minMaintainSpeed x (1 - this*Lv): easier to start and keep (Lv5 60%)
// The push OFF the wall rides the slide ladder: wallRun_jumpVelocity x (1 + 0.10*Lv).
// wallRun_jumpHeight is DELIBERATELY NOT SCALED (user 2026-09-02: "do we get at
// risk for slasher players to jump off the map?"): every drop-facing edge on
// both towers is a 56 rail + a 112 clip cap = 168 above the deck, sized against
// a 39-unit stock jump; a x2.25 wall-jump of unknown stock height could have
// cleared it. The engine's own climb along a wall (wallRun_maxHeight) is not
// scaled either and is now in the dev print — if a wall-jump ever reads within
// reach of 168, raise gen_tower_map RAIL_CAP_H (a full build), never the ladder.

// ---- AIR STEERING (lane 4) ----------------------------------------------------
// Turn rate = BASE + PER_LV * Lv deg/s: 120/150/180/210/240 = 6..12 deg per
// server frame, scaled by the strafe deflection (a keyboard reads 1). v16.33
// halved the v16.28 ladder for smoothness — the budget below makes the total
// turn per jump what the player feels, not the rate.
#define TOD_ATH_AIR_TURN_BASE   90
#define TOD_ATH_AIR_TURN_PER_LV 30
// THE STEER BUDGET: the heading may leave the launch line by at most
// BASE + PER_LV * Lv degrees per air episode: 28/36/44/52/60.
#define TOD_ATH_AIR_STEER_MAX_BASE   20
#define TOD_ATH_AIR_STEER_MAX_PER_LV 8
// EASE: a frame never closes more than this fraction of the remaining gap.
#define TOD_ATH_AIR_EASE        0.6
// 0 = only the strafe axis steers; 1 = the full stick in the view frame
// ("fly where you look", v16.23/24 behaviour).
#define TOD_ATH_AIR_STEER_FWD   0
// THE CONE: full width, centred on the launch heading. 180 = the front hemisphere.
#define TOD_ATH_AIR_CONE_DEG    180
// Fraction of the launch speed left at a full 180-deg reversal; linear from the
// cone edge to there.
#define TOD_ATH_AIR_REVERSE_KEEP 0.35
// The cap never drops under this (u/s): walking pace.
#define TOD_ATH_AIR_CAP_FLOOR   200
// Speed past cap x this in one tick is an external impulse: re-anchor, never fight.
#define TOD_ATH_AIR_REANCHOR    1.25
// Strafe deflection under this = no steering input this tick.
#define TOD_ATH_AIR_DEADZONE    0.25
// No write when the heading is already within this many degrees of the wish.
#define TOD_ATH_AIR_DEADBAND    3
// +1: GetNormalizedMovement()[1] > 0 is RIGHT — confirmed in play, v16.23.
#define TOD_ATH_AIR_RIGHT_SIGN  1

// THE ANTI-COMPOUNDING CEILING — a safety wall on the slide multiply (and so
// on the largest value lane 1 ever writes), not a tuning knob.
#define TOD_ATH_SPEED_MAX       800

// A slide entered under this speed (previous tick) is a CLEAN entry (lane 2).
#define TOD_ATH_CLEAN_ENTRY     440

// ---- THE JUMP EDGE (lane 3) ---------------------------------------------------
// Insurance bands, "slide" jumps only. Above: the engine launched faster than
// the slide speed lane 1 wrote (lane 1 not in force) — cut. Below: a shortfall
// friction cannot produce (~20% per 50 ms) — restore.
#define TOD_ATH_EDGE_BOOST      0.15
#define TOD_ATH_EDGE_CLAMP      0.40
// A jump press inside this window makes an edge a JUMP. A tap lasts 60-100 ms.
#define TOD_ATH_JUMP_LATCH_MS   100
// Air->air with vz rising by more than this in one tick is a bunny hop whose
// ground contact fell between two server frames.
#define TOD_ATH_HOP_DVZ         100
// A jump edge this soon after the last sliding tick, with grounded frames in
// between, is a "standup" jump (trace label; the engine treats it as a run jump).
#define TOD_ATH_DIRECT_MS       150

// The engine's own launch band. A BO3 jump leaves the ground at roughly
// sqrt(2*g*jump_height) = ~250 u/s (g 800, jump_height 39); the JIT height at
// Lv5 (2.25x) launches at ~375; a step off a ledge is ~0.
#define TOD_ATH_JUMP_VZ_MIN     10
#define TOD_ATH_JUMP_VZ_MAX     520

// 0.05 = the server frame (shared.gsh SERVER_FRAME); the only cadence there is.
#define TOD_ATH_TICK            0.05
#define TOD_ATH_IDLE_TICK       1.0

// Trace: ground ticks after a landing before the jump summary prints (6 = 300 ms).
#define TOD_ATH_TRACE_LAND_TICKS 6

#namespace tod_athlete;

function init()
{
	// Runs from _tod_main::init(), i.e. AFTER zm_usermap::main() -> _zm.gsc has
	// set stock's own movement dvars, so ours lands last.
	apply_engine_movement_tuning();
	callback::on_spawned( &on_player_spawned );
}

// ---------------------------------------------------------------------------
// LANE 1 — engine dvars. Probe first; capture the pristine defaults once per
// Steam session; rest both JIT dvars at their rest values.
// ---------------------------------------------------------------------------
function apply_engine_movement_tuning()
{
	level.tod_ath_dvar_before = [];

	j = SpawnStruct();
	// A fresh GAME session carries no marker: the live values are the engine's
	// own. Every later map load in the same session finds the marker and must
	// not capture — the live values may be ours.
	fresh = ( GetDvarString( "tod_ath_jit_written", "" ) == "" );
	j.fresh        = fresh;
	j.pristine_jmv = jit_capture( "jump_max_velocity",  "tod_ath_orig_jmv", fresh );
	j.pristine_jh  = jit_capture( "jump_height",        "tod_ath_orig_jh",  fresh );
	j.pristine_js  = jit_capture( "jump_slowdownEnable", "tod_ath_orig_js", fresh );
	SetDvar( "tod_ath_jit_written", "1" );
	// The engine's own slide start speed: the pre-arm value while an athlete is
	// grounded, and the fallback rest when the pristine cap is unknown.
	j.slide_base = 0;
	if ( GetDvarString( "slide_speedBase", "" ) != "" )
		j.slide_base = GetDvarFloat( "slide_speedBase", 0 );
	// POISON: a session that ran v16.1..v16.28 has 1000 (our own constant) live
	// at its first capture. Refuse it, forget it (so a game restart captures the
	// real default), and rest on the engine's slide start speed instead.
	j.poisoned = false;
	if ( j.pristine_jmv >= 999 )
	{
		j.poisoned     = true;
		j.pristine_jmv = -2;
		SetDvar( "tod_ath_orig_jmv", "" );
	}
	j.ok_jmv = ( TOD_MOVE_SLIDE_JUMP_TRACK && level.tod_ath_dvar_before[ "jump_max_velocity" ] != "" );
	j.ok_jh  = ( TOD_MOVE_SLIDE_JUMP_HEIGHT_JIT && level.tod_ath_dvar_before[ "jump_height" ] != "" );
	j.ok_js  = ( TOD_MOVE_LAND_STUMBLE_OFF && level.tod_ath_dvar_before[ "jump_slowdownEnable" ] != "" );
	if ( TOD_MOVE_SLIDE_JUMP_REST > 0 )
		j.rest_jmv = TOD_MOVE_SLIDE_JUMP_REST;
	else if ( j.pristine_jmv >= 0 )
		j.rest_jmv = j.pristine_jmv;
	else if ( j.slide_base > 1 )
		j.rest_jmv = j.slide_base;
	else
		j.rest_jmv = TOD_MOVE_SLIDE_JUMP_FALLBACK;
	j.rest_jh = ( ( j.pristine_jh > 0 ) ? j.pristine_jh : 39 );
	j.rest_js = ( ( j.pristine_js >= 0 ) ? j.pristine_js : 1 );
	// "Never written" markers so the first jit_update() writes the rest values
	// even if a previous map load left something else in the dvar.
	j.cur_jmv = -1;
	j.cur_jh  = -1;
	j.cur_js  = -1;

	// WALL-RUN master switch (v16.34). Per-player permission is AllowWallRun,
	// applied in on_player_spawned / wallrun_allow — this only re-enables the
	// engine mechanic stock zombies turned off.
	j.ok_wr = false;
	if ( TOD_ATH_WALLRUN )
	{
		set_engine_dvar( "wallrun_enabled", 1 );
		j.ok_wr = ( level.tod_ath_dvar_before[ "wallrun_enabled" ] != "" );
	}
	// THE LADDER's dvars (v16.38): pristine captured on first sight — no build
	// before v16.38 ever wrote them, so the live value is the engine's own even
	// in a continued game session (first_ever). Rested at pristine below.
	// wallRun_jumpHeight is NOT in this list on purpose — see the ladder comment.
	j.wr_names = array( "wallRun_maxTimeMs", "wallRun_speedScale", "wallRun_jumpVelocity",
	                    "wallRun_minTriggerSpeed", "wallRun_minJumpHeight", "wallRun_minMaintainSpeed" );
	j.wr_pristine = [];
	j.wr_cur      = [];
	for ( i = 0; i < j.wr_names.size; i++ )
	{
		n = j.wr_names[ i ];
		j.wr_pristine[ n ] = jit_capture( n, "tod_ath_orig_" + n, fresh, true );
		j.wr_cur[ n ]      = -1;
	}

	level.tod_ath_jit = j;
	jit_update();
}

// The per-level multiplier for one wall-run dvar (1 at level 0 = pristine).
function wr_mult( name, lvl )
{
	if ( !isdefined( lvl ) || lvl <= 0 )
		return 1;
	if ( name == "wallRun_maxTimeMs" )
		return 1 + ( TOD_ATH_WR_TIME_PER_LV * lvl );
	if ( name == "wallRun_speedScale" )
		return 1 + ( TOD_ATH_WR_SPEED_PER_LV * lvl );
	if ( name == "wallRun_jumpHeight" )
		return 1;   // never scaled — the 168-unit rail caps were sized against a stock jump
	if ( name == "wallRun_jumpVelocity" )
		return 1 + ( TOD_ATH_SLIDE_PER_LV * lvl );
	// the thresholds: minTriggerSpeed, minJumpHeight, minMaintainSpeed
	m = 1 - ( TOD_ATH_WR_EASE_PER_LV * lvl );
	if ( m < 0.2 )
		m = 0.2;
	return m;
}

// Per-player permission for the engine's wall-run. Re-applied whenever the
// cached state disagrees; on_player_spawned clears the cache so a respawn
// re-applies it even if stock reset the flag.
function wallrun_allow( on )   // self = player
{
	want = ( ( TOD_ATH_WALLRUN && on ) ? 1 : 0 );
	if ( isdefined( self.tod_ath_wr_state ) && self.tod_ath_wr_state == want )
		return;
	self AllowWallRun( want == 1 );
	self.tod_ath_wr_state = want;
}

// The pristine value of an engine dvar for this game session: -1 if the dvar
// is not registered in this build (then nothing is ever written to it), -2 if
// it is unknown (no stored capture and this is not a fresh session, so the
// live value may be our own previous write). A fresh session stores the live
// value in a script dvar and every later init reads that.
function jit_capture( name, orig_key, fresh, first_ever )
{
	before = GetDvarString( name, "" );
	level.tod_ath_dvar_before[ name ] = before;
	if ( before == "" )
		return -1;
	if ( GetDvarString( orig_key, "" ) == "" )
	{
		// first_ever: a dvar no earlier build ever wrote may be captured even in
		// a continued session — the live value can only be the engine's.
		if ( !fresh && !IS_TRUE( first_ever ) )
			return -2;
		SetDvar( orig_key, before );
	}
	return GetDvarFloat( orig_key, 0 );
}

// The engine's own slide START speed for the pre-arm: the measured reference
// from this player's last clean slide, else the slide_speedBase dvar, else 0
// (no pre-arm — the cap simply rests).
function slide_base_speed( slide_ref )
{
	if ( isdefined( slide_ref ) && slide_ref > 1 )
		return slide_ref;
	j = level.tod_ath_jit;
	if ( isdefined( j ) && j.slide_base > 1 )
		return j.slide_base;
	return 0;
}

// THE ARBITER. Called by any watcher whose published state changed. The slide
// dvars follow the MAX over every athlete currently sliding; the stumble is
// off while ANY athlete is airborne; everything rests at stock otherwise.
// Writes only on change (a decaying slide is one write per tick).
function jit_update()
{
	j = level.tod_ath_jit;
	if ( !isdefined( j ) )
		return;
	want_v = 0;
	want_h = 0;
	any_air = false;
	want_lvl = 0;   // the highest ATHLETE level currently airborne: the wall-run ladder's input
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( isdefined( p.tod_ath_slide_sp ) && p.tod_ath_slide_sp > want_v )
			want_v = p.tod_ath_slide_sp;
		if ( isdefined( p.tod_ath_slide_jh ) && p.tod_ath_slide_jh > want_h )
			want_h = p.tod_ath_slide_jh;
		if ( IS_TRUE( p.tod_ath_air ) )
			any_air = true;
		if ( isdefined( p.tod_ath_air_lvl ) && p.tod_ath_air_lvl > want_lvl )
			want_lvl = p.tod_ath_air_lvl;
	}
	if ( want_v <= 0 )
		want_v = j.rest_jmv;
	if ( want_h <= 0 )
		want_h = j.rest_jh;
	want_s = ( any_air ? 0 : j.rest_js );
	if ( j.ok_jmv && Abs( want_v - j.cur_jmv ) >= 1 )
	{
		SetDvar( "jump_max_velocity", want_v );
		j.cur_jmv = want_v;
	}
	if ( j.ok_jh && Abs( want_h - j.cur_jh ) >= 0.5 )
	{
		SetDvar( "jump_height", want_h );
		j.cur_jh = want_h;
	}
	if ( j.ok_js && want_s != j.cur_js )
	{
		SetDvar( "jump_slowdownEnable", want_s );
		j.cur_js = want_s;
	}
	// THE WALL-RUN LADDER: every registered wallRun_* dvar = pristine x
	// mult(highest airborne athlete level); pristine when nobody is airborne.
	if ( IS_TRUE( j.ok_wr ) )
	{
		for ( i = 0; i < j.wr_names.size; i++ )
		{
			n  = j.wr_names[ i ];
			pr = j.wr_pristine[ n ];
			if ( pr < 0 )
				continue;   // unregistered, or unknown — never written
			want = pr * wr_mult( n, want_lvl );
			if ( Abs( want - j.wr_cur[ n ] ) >= 0.001 )
			{
				SetDvar( n, want );
				j.wr_cur[ n ] = want;
			}
		}
	}
}

// SetDvar on an UNREGISTERED name silently creates a dead script dvar, so an
// absent dvar is skipped and recorded rather than "set".
function set_engine_dvar( name, value )
{
	before = GetDvarString( name, "" );
	level.tod_ath_dvar_before[ name ] = before;
	if ( before == "" )
		return;
	SetDvar( name, value );
}

// DEV ONLY (called from the tod_dev block in _tod_main::init). The slide/jump
// engine family as the engine reports it right now, plus the JIT lanes' state.
function dev_print_movement_dvars()
{
	names = array( "jump_max_velocity", "jump_height", "jump_slowdownEnable",
	               "slide_speedBase", "slide_speed", "slide_maxTimeBase",
	               "slide_min_continue_velocity", "slide_friction_amount",
	               "slide_outSpeedScale", "slide_outShouldScaleSpeed", "slide_outAllowSprint",
	               "slide_subsequentSlideScale", "slide_enable_tweak_left_right", "friction",
	               "wallrun_enabled", "wallRun_maxTimeMs", "wallRun_minJumpHeight", "wallRun_minJumpHeightEnable",
	               "wallRun_peakTest", "wallRun_minTriggerSpeed", "wallRun_minZVel", "wallRun_speedScale",
	               "wallRun_jumpHeight", "wallRun_jumpVelocity", "wallRun_maxHeight", "wallRun_combatEnable", "wallRun_viewmodelAnimEnable" );
	for ( i = 0; i < names.size; i++ )
	{
		v = GetDvarString( names[ i ], "" );
		if ( v == "" )
			v = "<UNREGISTERED>";
		was = "";
		if ( isdefined( level.tod_ath_dvar_before ) && isdefined( level.tod_ath_dvar_before[ names[ i ] ] ) )
		{
			b = level.tod_ath_dvar_before[ names[ i ] ];
			if ( b != "" && b != v )
				was = " (was " + b + " at init)";
		}
		tod_quiet_print( "dvar " + names[ i ] + " = " + v + was );
	}
	j = level.tod_ath_jit;
	if ( isdefined( j ) )
	{
		tod_quiet_print( "jit session " + ( j.fresh ? "FRESH (captured now)" : "continued (stored captures)" ) + " slide_base=" + j.slide_base );
		tod_quiet_print( "jit jump_max_velocity: " + ( j.ok_jmv ? "ON" : "off" ) + " rest=" + j.rest_jmv + " pristine=" + j.pristine_jmv + " (-2 = unknown)" );
		tod_quiet_print( "jit jump_height: " + ( j.ok_jh ? "ON" : "off" ) + " rest=" + j.rest_jh + " pristine=" + j.pristine_jh );
		tod_quiet_print( "jit jump_slowdownEnable: " + ( j.ok_js ? "ON" : "off" ) + " rest=" + j.rest_js + " pristine=" + j.pristine_js );
		if ( IS_TRUE( j.ok_wr ) )
		{
			for ( i = 0; i < j.wr_names.size; i++ )
			{
				n = j.wr_names[ i ];
				tod_quiet_print( "wr " + n + " pristine=" + j.wr_pristine[ n ] + " Lv5=" + ( j.wr_pristine[ n ] * wr_mult( n, 5 ) ) );
			}
		}
		if ( j.poisoned )
			IPrintLnBold( "ATH: the captured jump_max_velocity was 1000 (our old constant) - REFUSED; resting on slide_speedBase. Restart the GAME once for the real default" );
		if ( j.pristine_js == 0 && j.ok_js )
			tod_quiet_print( "ATH: jump_slowdownEnable pristine is 0 - ZM never had the stumble, OR v16.2's write was captured: restart the GAME once" );
	}
}

// ---------------------------------------------------------------------------
// self = player. One watcher per player for the whole game.
// ---------------------------------------------------------------------------
function on_player_spawned()
{
	// RESPAWN LATCH, in the FUNCTION and not at the registration site, so it
	// covers any future caller. callback::callback THREADS every registered func
	// on every dispatch, and a co-op bleed-out respawn dispatches
	// "spawned_player" TWICE — without this the player accumulates a second
	// immortal watcher per life. Same shipped idiom as _tod_distraction,
	// _tod_runandgun, _tod_uniques, _tod_luck and _tod_powerups. The field
	// survives death because the ZM player entity is never deleted. Do NOT use
	// callback::remove_on_spawned — it deregisters for EVERY player.
	// WALL-RUN (v16.34): every spawn starts DENIED — the watcher allows it for
	// athletes on its next tick. Clearing the cache first makes that re-apply
	// even if stock reset the engine flag on respawn.
	self.tod_ath_wr_state = undefined;
	self wallrun_allow( false );

	if ( IS_TRUE( self.tod_athlete_watch_on ) )
		return;
	self.tod_athlete_watch_on = true;
	self thread watch();
}

function hspeed( v )
{
	return Sqrt( ( v[ 0 ] * v[ 0 ] ) + ( v[ 1 ] * v[ 1 ] ) );
}

// Publish this player's state to the arbiter: sliding speed and JIT height
// (0/0 = not sliding), airborne flag. Only an ATHLETE ever publishes non-zero
// values — the idle lane and every guard publish zeros.
function jit_publish( sp, jh, air, air_lvl )   // self = player
{
	changed = ( !isdefined( self.tod_ath_slide_sp ) || Abs( self.tod_ath_slide_sp - sp ) >= 1
	            || !isdefined( self.tod_ath_slide_jh ) || Abs( self.tod_ath_slide_jh - jh ) >= 0.5
	            || !isdefined( self.tod_ath_air ) || self.tod_ath_air != air
	            || !isdefined( self.tod_ath_air_lvl ) || self.tod_ath_air_lvl != air_lvl );
	self.tod_ath_slide_sp = sp;
	self.tod_ath_slide_jh = jh;
	self.tod_ath_air      = air;
	self.tod_ath_air_lvl  = air_lvl;   // this athlete's level while airborne, else 0 (the wall-run ladder)
	if ( changed )
		jit_update();
}

// THE WATCHER. Lanes 2, 3 and 4, all per-player, all writing only through
// `self`, AT MOST ONE SetVelocity PER TICK: every lane edits the same
// (out_x, out_y, out_z) and the write happens once at the bottom, so the lanes
// compose instead of clobbering.
function watch()   // self = player
{
	self endon( "disconnect" );
	level endon( "end_game" );

	was_ground    = true;
	was_slide     = false;
	prev_sp       = 0;        // horizontal speed at the end of the previous tick (post-write)
	prev_vz       = 0;        // vertical speed at the end of the previous tick (post-write)
	last_slide_ms = -100000;  // GetTime() of the last sliding tick
	jump_seen_ms  = -100000;  // GetTime() the jump button was last seen down
	slide_ref     = 0;        // the engine's own slide start speed from the last CLEAN entry
	air_yaw       = 0;        // the cone's anchor: heading the current air episode began with
	air_ref       = 0;        // ... and its speed (0 = no episode in progress)
	air_cap       = 0;        // the cap in force last tick (the re-anchor test)
	was_wallrun   = false;    // the engine owned movement last tick (v16.34)
	self trace_reset();
	self jit_publish( 0, 0, false, 0 );

	for ( ;; )
	{
		lvl = tod_upgrades::get_level( self, TOD_ATH_DOMAIN );
		// DARK UPGRADE (v17.10): +2 EFFECTIVE levels -- an ATHLETE computing as 7.
		// This domain is linear in level on every one of its lanes, so this is the
		// one place in the feature where a level bump is the RIGHT expression
		// rather than the trap: nothing here is a clamped table lookup.
		//
		// wallrun_allow reads the RAW level below on purpose -- a dark bit can only
		// exist on a MAXED domain, but gating an engine movement mode on a derived
		// number is how a future refactor arms wall-run for someone with no ATHLETE.
		self wallrun_allow( lvl > 0 );
		if ( lvl > 0 && tod_upgrades::has_dark( self, TOD_ATH_DOMAIN ) )
			lvl += 2;

		// IDLE LANE — no level, no work. A domain reset (tier promotion, spire
		// teardown) simply lands here next tick with nothing to clear.
		if ( lvl <= 0 )
		{
			was_slide  = false;
			was_ground = true;
			prev_sp    = 0;
			prev_vz    = 0;
			air_ref    = 0;
			self jit_publish( 0, 0, false, 0 );
			wait TOD_ATH_IDLE_TICK;
			continue;
		}

		wait TOD_ATH_TICK;

		// GUARDS. Dead, downed, spectating, menu-frozen or mantling players get
		// nothing. laststand matters specifically — `isalive` is TRUE in last
		// stand (down-path-stock-contracts). A mantle is an engine-scripted
		// move; a velocity write mid-mantle would fight it. was_ground is left
		// FALSE so a mantle that ends airborne cannot read as a launch.
		if ( !isdefined( self ) || !IsAlive( self ) || self laststand::player_is_in_laststand() || IS_TRUE( self.tod_menu_frozen ) || self IsMantling() || isdefined( self.tod_smash_cast ) )
		{
			was_ground = false;
			was_slide  = false;
			prev_sp    = 0;
			prev_vz    = 0;
			air_ref    = 0;
			self jit_publish( 0, 0, false, 0 );
			continue;
		}

		now      = GetTime();
		onground = self IsOnGround();
		v        = self GetVelocity();
		sp       = hspeed( v );
		// IsSliding() is the ONLY proven slide detector: GetStance() never
		// returns a slide value, a BO3 slide is entered from a standing sprint,
		// and the MP "slide_begin"/"slide_end" notifies do not fire in ZM.
		sliding  = ( self IsSliding() && onground );
		if ( self JumpButtonPressed() )
			jump_seen_ms = now;
		jumped = ( ( now - jump_seen_ms ) <= TOD_ATH_JUMP_LATCH_MS );

		// ---- WALL-RUN (v16.34): the engine owns movement while it runs -------
		// Publish "airborne" (the stumble lane), park every other lane, and let
		// the tick after the run ends start a fresh air episode with NO edge:
		// the wall-jump is the engine's own launch, never multiplied or insured.
		wallrun = ( TOD_ATH_WALLRUN && self IsWallRunning() );
		if ( wallrun )
		{
			if ( !was_wallrun )
				self trace_wallrun_start( now, sp );
			self jit_publish( 0, 0, true, lvl );
			air_ref     = 0;
			was_wallrun = true;
			was_ground  = false;
			was_slide   = false;
			prev_sp     = sp;
			prev_vz     = v[ 2 ];
			continue;
		}
		skip_edge = false;
		if ( was_wallrun )
		{
			self trace_wallrun_end( now, sp );
			was_wallrun = false;
			skip_edge   = true;
			air_ref     = 0;
		}

		out_x = v[ 0 ]; out_y = v[ 1 ]; out_z = v[ 2 ];
		dirty = false;

		// ---- LANE 2: SLIDE START — the one slide-speed lane -------------------
		if ( sliding && !was_slide )
		{
			eng   = sp;   // what the engine started the slide at
			clean = ( prev_sp <= TOD_ATH_CLEAN_ENTRY );
			if ( clean && eng > 1 )
				slide_ref = eng;
			base = ( clean ? eng : slide_ref );
			if ( base > 1 && sp > 1 )
			{
				want = base * ( 1 + ( TOD_ATH_SLIDE_PER_LV * lvl ) );
				if ( want > TOD_ATH_SPEED_MAX )
					want = TOD_ATH_SPEED_MAX;
				// Same heading, more of it — RAISE-ONLY, so a slide the engine
				// already started faster than the spec is left alone.
				if ( want > sp )
				{
					out_x = v[ 0 ] * want / sp;
					out_y = v[ 1 ] * want / sp;
					dirty = true;
					sp    = want;
				}
			}
			self trace_slide_start( now, eng, sp, clean, slide_ref );
		}
		else if ( sliding )
		{
			self trace_slide_tick( sp );
		}
		else if ( was_slide )
		{
			self trace_slide_end( now );
		}

		// ---- LANE 1: JUST-IN-TIME — the engine's slide-jump numbers follow the
		// slider (published every sliding tick with the post-write speed, so the
		// first tick's multiply is already in it; zeros on the first tick after),
		// and the landing stumble is off while this athlete is airborne.
		if ( sliding )
		{
			last_slide_ms = now;
			jh = level.tod_ath_jit.rest_jh * ( 1 + ( TOD_ATH_JUMP_PER_LV * lvl ) );
			self jit_publish( sp, jh, false, 0 );
		}
		else if ( onground )
		{
			// PRE-ARM (v16.33): the cap is held at the engine's own slide start
			// speed while this athlete is grounded, so a slide-hop pressed before
			// the first sliding tick keeps exactly the speed it had.
			self jit_publish( slide_base_speed( slide_ref ), 0, false, 0 );
		}
		else
		{
			self jit_publish( 0, 0, true, lvl );
		}

		// ---- LANE 3: THE JUMP EDGE ----------------------------------------------
		edge = false;
		if ( !onground && !skip_edge && v[ 2 ] > TOD_ATH_JUMP_VZ_MIN && v[ 2 ] < TOD_ATH_JUMP_VZ_MAX )
		{
			if ( was_ground )
				edge = true;
			else if ( v[ 2 ] > ( prev_vz + TOD_ATH_HOP_DVZ ) )
				edge = true;
		}
		if ( edge )
		{
			air_ref = 0;
			pre     = prev_sp;
			before  = sp;
			jmv_at  = level.tod_ath_jit.cur_jmv;
			jh_at   = level.tod_ath_jit.cur_jh;
			if ( jumped )
			{
				if ( !was_ground )
					mode = "hop";
				else if ( was_slide )
					mode = "slide";
				else if ( ( now - last_slide_ms ) <= TOD_ATH_DIRECT_MS )
					mode = "standup";
				else
					mode = "run";

				if ( mode == "slide" && pre > 1 && sp > 1 )
				{
					// INSURANCE. Lane 1 wrote `pre` as the launch cap on the
					// tick before; the engine's launch should BE pre. Either
					// write here is one frame late and shows as the stutter —
					// the trace tells us whether they ever fire.
					if ( sp > ( pre * ( 1 + TOD_ATH_EDGE_BOOST ) ) || sp < ( pre * ( 1 - TOD_ATH_EDGE_CLAMP ) ) )
					{
						out_x = v[ 0 ] * pre / sp;
						out_y = v[ 1 ] * pre / sp;
						dirty = true;
						sp    = pre;
					}
				}
				// THE HEIGHT. On a slide-jump with the JIT height lane in force
				// the engine already launched at the boosted height; a write
				// would double it. Every other mode gets the vz multiply.
				if ( !( mode == "slide" && level.tod_ath_jit.ok_jh ) )
				{
					out_z = v[ 2 ] * jump_vel_scale( lvl );
					dirty = true;
				}
				self trace_jump( now, mode, pre, jmv_at, jh_at, before, sp, out_z );
			}
			else
			{
				// Ground -> air with no jump press: a ramp-crest hop, a step off
				// a ledge with upward vz, a mantle exit. Untouched, traced.
				self trace_jump( now, "nojump", pre, jmv_at, jh_at, before, sp, v[ 2 ] );
			}
		}

		// ---- LANE 4: STRAFE STEERING + THE CONE ----------------------------------
		if ( !onground && sp > 1 )
		{
			c_yaw = VectorToAngles( ( out_x, out_y, 0 ) )[ 1 ];

			// THE ANCHOR: the heading and speed this air episode began with.
			// Re-taken when an external impulse throws the speed past the cap by
			// TOD_ATH_AIR_REANCHOR: a boss fling is never fought.
			if ( air_ref <= 0 || sp > ( air_cap * TOD_ATH_AIR_REANCHOR ) )
			{
				air_yaw = c_yaw;
				air_ref = sp;
				air_cap = sp;
				if ( air_cap < TOD_ATH_AIR_CAP_FLOOR )
					air_cap = TOD_ATH_AIR_CAP_FLOOR;
			}

			m = self GetNormalizedMovement();
			if ( isdefined( m ) )
			{
				fwd_in   = m[ 0 ] * TOD_ATH_AIR_STEER_FWD;
				right_in = m[ 1 ] * TOD_ATH_AIR_RIGHT_SIGN;
				mag_in   = Sqrt( ( fwd_in * fwd_in ) + ( right_in * right_in ) );
				if ( mag_in >= TOD_ATH_AIR_DEADZONE )
				{
					if ( mag_in > 1 )
						mag_in = 1;
					yaw   = self GetPlayerAngles()[ 1 ];
					f     = AnglesToForward( ( 0, yaw, 0 ) );
					r     = AnglesToRight( ( 0, yaw, 0 ) );
					wish  = ( ( f[ 0 ] * fwd_in ) + ( r[ 0 ] * right_in ), ( f[ 1 ] * fwd_in ) + ( r[ 1 ] * right_in ), 0 );
					w_yaw = VectorToAngles( wish )[ 1 ];
					gap   = AngleClamp180( w_yaw - c_yaw );
					if ( Abs( gap ) >= TOD_ATH_AIR_DEADBAND )
					{
						// ANALOG: a half-pushed stick turns at half the rate.
						step_max = ( TOD_ATH_AIR_TURN_BASE + ( TOD_ATH_AIR_TURN_PER_LV * lvl ) ) * mag_in * TOD_ATH_TICK;
						// EASE: a frame never closes more than TOD_ATH_AIR_EASE of the
						// remaining gap — the curve arrives, it does not snap.
						ease = Abs( gap ) * TOD_ATH_AIR_EASE;
						if ( step_max > ease )
							step_max = ease;
						step  = gap;
						if ( step > step_max )
							step = step_max;
						else if ( step < ( 0 - step_max ) )
							step = 0 - step_max;
						// THE STEER BUDGET: never further than steer_max from the
						// heading this air episode began on, either way.
						steer_max = TOD_ATH_AIR_STEER_MAX_BASE + ( TOD_ATH_AIR_STEER_MAX_PER_LV * lvl );
						cur_dev   = AngleClamp180( c_yaw - air_yaw );
						new_dev   = cur_dev + step;
						if ( new_dev > steer_max )
							step = steer_max - cur_dev;
						else if ( new_dev < ( 0 - steer_max ) )
							step = ( 0 - steer_max ) - cur_dev;
						if ( Abs( step ) > 0.05 )
						{
							c_yaw = c_yaw + step;
							nf    = AnglesToForward( ( 0, c_yaw, 0 ) );
							out_x = nf[ 0 ] * sp;
							out_y = nf[ 1 ] * sp;
							dirty = true;
							self trace_turn( Abs( step ), right_in );
						}
					}
				}
			}

			// THE CONE. How far the heading now sits from the launch line decides
			// how much of the launch speed may be carried — a pure function of the
			// current deviation, never under the floor. Speed above it is trimmed,
			// the engine's own small airborne additions included.
			dev = Abs( AngleClamp180( c_yaw - air_yaw ) );
			cap = air_ref * air_retain( dev );
			if ( cap < TOD_ATH_AIR_CAP_FLOOR )
				cap = TOD_ATH_AIR_CAP_FLOOR;
			air_cap = cap;
			if ( sp > cap )
			{
				out_x = out_x * cap / sp;
				out_y = out_y * cap / sp;
				sp    = cap;
				dirty = true;
			}
			self trace_cone( dev, ( ( air_ref > 0 ) ? ( cap / air_ref ) : 1 ) );
		}
		else if ( onground )
		{
			air_ref = 0;   // grounded: the episode and its anchor are over
		}

		if ( dirty )
			self SetVelocity( ( out_x, out_y, out_z ) );

		// ---- TRACE bookkeeping (no writes) --------------------------------------
		if ( !onground )
			self trace_air_tick( sp );
		else if ( !was_ground )
			self trace_land( now, sp );
		else
			self trace_ground_tick( sp );

		prev_sp    = sp;
		prev_vz    = out_z;
		was_ground = onground;
		was_slide  = sliding;
	}
}

// THE CONE CURVE: fraction of the launch speed the player may carry at `dev`
// degrees off the launch heading. 1.0 inside +-half the cone, then linear
// down to TOD_ATH_AIR_REVERSE_KEEP at a full 180-deg reversal. On the 180-deg
// cone: 90 deg 1.00 · 120 deg 0.78 · 150 deg 0.57 · 180 deg 0.35
function air_retain( dev )
{
	half = TOD_ATH_AIR_CONE_DEG * 0.5;
	if ( dev <= half )
		return 1;
	t = ( dev - half ) / ( 180 - half );
	if ( t > 1 )
		t = 1;
	return 1 - ( t * ( 1 - TOD_ATH_AIR_REVERSE_KEEP ) );
}

// ---------------------------------------------------------------------------
// THE PHYSICS CONVERSION — the one function that must not be "simplified".
// ---------------------------------------------------------------------------
// The user's number is HEIGHT. This lever is VELOCITY. Apex height goes as v^2
// (h = v^2 / 2g), so to multiply height by k you multiply velocity by sqrt(k).
// Writing `v[2] * (1 + 0.25*lvl)` instead would deliver +56% height at Lv1 and
// 3.8x at Lv5. (The JIT jump_height lane needs no conversion — it sets the
// HEIGHT directly, and the engine derives the velocity.)
//
// The ladder this produces (height -> velocity):
//   Lv1  1.25x -> 1.118   Lv2  1.50x -> 1.225   Lv3  1.75x -> 1.323
//   Lv4  2.00x -> 1.414   Lv5  2.25x -> 1.500
function jump_vel_scale( lvl )
{
	if ( !isdefined( lvl ) || lvl <= 0 )
		return 1;
	return Sqrt( 1 + ( TOD_ATH_JUMP_PER_LV * lvl ) );
}

// ---------------------------------------------------------------------------
// TRACE — tod_dev builds only. One bold line per slide, one per air episode.
// Every function here returns immediately in the ship state.
// ---------------------------------------------------------------------------
function trace_wallrun_start( now, sp )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	tr.w_t0 = now; tr.w_sp = sp;
}

function trace_wallrun_end( now, sp )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	self IPrintLnBold( "ATH wallrun " + ( now - tr.w_t0 ) + "ms in=" + Int( tr.w_sp ) + " out=" + Int( sp ) );
}

function trace_reset()   // self = player
{
	tr = SpawnStruct();
	tr.w_t0 = 0; tr.w_sp = 0;
	tr.s_t0 = 0; tr.s_eng = 0; tr.s_set = 0; tr.s_next = -1; tr.s_end = 0; tr.s_ticks = 0; tr.s_clean = 0; tr.s_ref = 0;
	tr.j_mode = "none"; tr.j_pre = 0; tr.j_jmv = 0; tr.j_jh = 0; tr.j_before = 0; tr.j_after = 0; tr.j_vz = 0;
	tr.a_min = 0; tr.a_ticks = 0; tr.t_sum = 0; tr.t_max = 0; tr.t_r = 0;
	tr.c_dev = 0; tr.c_keep = 1;
	tr.l_sp = 0; tr.l_left = 0; tr.pending = false;
	self.tod_ath_tr = tr;
}

function trace_slide_start( now, eng, set, clean, ref )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	tr.s_t0 = now; tr.s_eng = eng; tr.s_set = set; tr.s_next = -1; tr.s_end = set; tr.s_ticks = 1;
	tr.s_clean = ( clean ? 1 : 0 ); tr.s_ref = ref;
}

function trace_slide_tick( sp )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	if ( tr.s_next < 0 )
		tr.s_next = sp;   // did the lane-2 write STICK? (compare with s_set)
	tr.s_end = sp;
	tr.s_ticks++;
}

function trace_slide_end( now )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	self IPrintLnBold( "ATH slide eng=" + Int( tr.s_eng ) + " set=" + Int( tr.s_set ) + " next=" + Int( tr.s_next )
	                   + " end=" + Int( tr.s_end ) + " " + ( now - tr.s_t0 ) + "ms clean=" + tr.s_clean + " ref=" + Int( tr.s_ref ) );
}

function trace_jump( now, mode, pre, jmv, jh, before, after, vz )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	tr.j_mode = mode; tr.j_pre = pre; tr.j_jmv = jmv; tr.j_jh = jh; tr.j_before = before; tr.j_after = after; tr.j_vz = vz;
	tr.a_min = after; tr.a_ticks = 0; tr.t_sum = 0; tr.t_max = 0; tr.t_r = 0;
	tr.c_dev = 0; tr.c_keep = 1;
	tr.l_sp = 0; tr.l_left = 0; tr.pending = true;
}

function trace_turn( step, right_in )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	if ( !tr.pending )
		return;
	tr.t_sum += step;
	if ( step > tr.t_max )
	{
		tr.t_max = step;
		tr.t_r   = right_in;
	}
}

function trace_cone( dev, keep )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	if ( !tr.pending )
		return;
	if ( dev > tr.c_dev )
		tr.c_dev = dev;
	if ( keep < tr.c_keep )
		tr.c_keep = keep;
}

function trace_air_tick( sp )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	if ( !tr.pending )
		return;
	tr.a_ticks++;
	if ( sp < tr.a_min )
		tr.a_min = sp;
}

function trace_land( now, sp )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	if ( !tr.pending )
		return;
	tr.l_sp   = sp;
	tr.l_left = TOD_ATH_TRACE_LAND_TICKS;
}

function trace_ground_tick( sp )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tr = self.tod_ath_tr;
	if ( !tr.pending || tr.l_left <= 0 )
		return;
	tr.l_left--;
	if ( tr.l_left > 0 )
		return;
	tr.pending = false;
	self IPrintLnBold( "ATH jump " + tr.j_mode + " pre=" + Int( tr.j_pre ) + " jmv=" + Int( tr.j_jmv ) + " jh=" + Int( tr.j_jh )
	                   + " launch=" + Int( tr.j_before ) + ">" + Int( tr.j_after )
	                   + " vz=" + Int( tr.j_vz ) + " minair=" + Int( tr.a_min ) + " air=" + tr.a_ticks + "t turn=" + Int( tr.t_sum ) + "/" + Int( tr.t_max )
	                   + " strafe=" + Int( tr.t_r * 10 ) + " dev=" + Int( tr.c_dev ) + " keep=" + Int( tr.c_keep * 100 ) + "%"
	                   + " land=" + Int( tr.l_sp ) + " +" + ( TOD_ATH_TRACE_LAND_TICKS * 50 ) + "ms=" + Int( sp ) );
}

// ---------------------------------------------------------------------------
// v17.97 — DEV PRINTS ARE MUTABLE. level.tod_dev_quiet (set beside tod_dev in
// zm_tower_of_doom::tod_resolve_dev_flags) silences every bottom-left IPrintLn
// in this file — screenshot sessions want dev + god with a clean HUD. Each
// print site's own tod_dev gate is unchanged; this is one extra gate under it.
// IPrintLnBold (real game toasts) is not routed here.
function tod_quiet_print( msg )
{
	if ( IS_TRUE( level.tod_dev_quiet ) )
		return;
	IPrintLn( msg );
}

function tod_quiet_print_to( msg )   // self = the player to print to
{
	if ( IS_TRUE( level.tod_dev_quiet ) )
		return;
	self IPrintLn( msg );
}
