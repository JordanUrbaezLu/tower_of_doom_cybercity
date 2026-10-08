// =============================================================================
// _tod_rocket.gsc — THE ROCKETS (docs/170, 2026-10-02).
//
// User: "I wonder if we can enhance the extract or ascend meaning we use the
// rocket ships built in the props and place at each spot. Instead of the
// teleporters after the crown fight is over. Then the colorful one goes to
// endless spire but we can also add some cinematic animtion scene where the
// rockets lifts of once players select ascned and they view from the rocket
// pov as it flies to the endless spire. Then it crashes into the ground and
// they spawn in and it starts. Of ocurse visuals, sounds, and everything for
// qualit eed to be accounted for" + "And if you extract same thing but the
// extract ship goes striaght up and the game ends few seconds later".
//
// THE SHIPS are two of Nikolai's Meshy models (tools/fan_props/build_fan_props.py,
// art/fan_props/manifest.json): `tod_rocket_spire` (the colourful one) and
// `tod_rocket_extract` (the cyber-outline one), 440 tall, exported LYING DOWN
// (nose = model +X, pivot on the axis at the fins' feet), so a ship in flight
// is aimed with VectorToAngles( nose ) and stands up at pitch -90.
//
// THE FLOW (the notify contract _tod_finale / _tod_spire already speak):
//   1. "tod_choice_begin" (the song is over, the world paused and wiped) ->
//      both ships come DOWN out of the sky into the crown hall on their own
//      flames (rockets_arrive): the extract ship onto the sanctuary over the
//      extraction pad, the spire ship onto the uplink dais. Anyone standing
//      where a ship sets down is moved off its footprint first. Each ship's
//      clip goes solid; the two boarding prompts arm (the existing EXTRACT /
//      ASCEND strings - not one new hint string).
//   2. FIRST COMMITTED HOLD WINS for the whole party (the approved choice
//      design): "tod_extract" or "tod_ascend" fires and both prompts retire.
//   3. THE RIDE - every living player boards: a cut through black onto the
//      ship (the letterbox + no HUD, TodRocketCine.lua), the camera a CHASE
//      camera behind and above it (one tag_origin mover per rider,
//      PlayerLinkToDelta with no view arc - Tower II's played lane, its
//      docs/196), the ship stepped every server frame with the camera on the
//      same clock. v19.68s (user: "permanently above the ship so you can see
//      it like in third person but also see where its heading" + "always have
//      the ship slightly seen at bottom of screen and able to see ahead"): the
//      ship sits low in the frame and the view looks along the flight.
//        EXTRACT  ignition, liftoff, STRAIGHT UP out of the crown; a few seconds
//                 into the climb the game ends (_tod_finale::depart ends it when
//                 ride_extract returns) and the ship keeps climbing behind the
//                 YOU ESCAPED THE TOWER screen until stock's intermission fade.
//        ASCEND   ignition, liftoff, straight up out of the crown, then ONE long
//                 arc over the top toward the ENDLESS SPIRE (the camera swinging
//                 up behind the ship) into a straight dive at the spire's foot;
//                 an alarm, the engine fails, the scream, and a CRASH nose-down
//                 into the arena's north-west corner floor (the walls broken):
//                 white, the boom, and the riders are standing at the arrival
//                 looking at the burning wreck as the white burns away.
//                 _tod_spire runs ascend_run in the white (tod_rocket_impact).
//
// EVERY FLIGHT IS DATA: the keys (points + unit tangents) come from GENERATED
// _tod_crown_data.gsc (gen_tower_map.js, the ROCKETS block), the script walks
// a cubic Hermite through them on an arc-length table, and the timeline is a
// piecewise-linear speed profile scaled to the path's length. tools/rocket/
// test_rocket_ride.js RUNS these functions (gsc_eval) and proves the hull and
// the camera clear every visible brush, the camera never steps more than a
// limit per frame, and every beat fits its ride.
//
// WHAT A RIDER IS SPARED (the flag is self.tod_rocket_riding, Tower II's set):
//   * stock's OUT-OF-PLAYABLE-AREA kill: the ride leaves every zone for
//     seconds; level.player_out_of_playable_area_monitor_callback answers
//     "spare" for a rider and defers to any earlier callback otherwise;
//   * DAMAGE: a callback FIRST in stock's player damage chain returns 0;
//   * TARGETING: zm_utility::increment_ignoreme for the ride (paired once);
//   * the crown's containment watch (_tod_finale) skips a rider.
//   A downed player at boarding is revived for free (stock auto_revive): the
//   party won the crown, and a crawler cannot ride a camera.
//
// DIAGNOSTICS: [TOD_ROCKET] INIT / ARRIVE / LAND / PUSH / ARM / CHOICE / RIDE / BOARD /
// BEAT / CAM / FX / CLIP / IMPACT / WRECK / FREE / ABORT. TOD_RK_LOG 1 prints with
// dev OFF for the first playtests (the user tests dev-off builds too) - zero it
// before a publish.
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_utility;
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;    // GENERATED: the ships' spots, triggers, flight keys, profile
#using scripts\zm\zm_tower_of_doom\_tod_spire_data;    // GENERATED: the crash, the wreck, the arrival
#using scripts\zm\zm_tower_of_doom\_tod_perk_scatter;  // play_sound_at_origin (the host-based 3D lane) + derez_burst

#insert scripts\shared\shared.gsh;

// AFTER every #using / #insert (the map's dialect trap).
#precache( "model", "tod_rocket_spire" );
#precache( "model", "tod_rocket_extract" );
#precache( "model", "tod_rocket_wreck" );
#precache( "eventstring", "tod_rocket_cine" );   // TodRocketCine.lua (a LuiNotifyEvent name must be precached)
// THE EFFECTS (docs/170 §FX). Every one is precached here AND zoned (`fx,` lines).
#precache( "fx", "tod/rocket/fx_rk_flame" );                              // the engine: Tower II's afterburner (its sky fleet), +X aft
#precache( "fx", "dlc1/castle/fx_rocket_exhaust_torch" );                // Der Eisendrache's launch torch: liftoff + the braking burn
#precache( "fx", "dlc1/castle/fx_rocket_spark_ignition" );                // Der Eisendrache: the ignition sparks
#precache( "fx", "dlc1/castle/fx_rocket_smk_donut_fast" );                // ... the liftoff smoke ring + fire shockwave
#precache( "fx", "dlc1/castle/fx_rocket_smk_afterburn" );                 // ... the smoke left on the pad
#precache( "fx", "dlc5/zmhd/fx_geotrail_jet_contrail" );                  // the contrail behind the climb
#precache( "fx", "killstreaks/fx_vtol_exp_smoke_trail" );                 // the burning trail of the dying ship
#precache( "fx", "electric/fx_elec_sparks_burst_xlg_os" );                // the malfunction (zoned since the rampage pass)
#precache( "fx", "dlc1/castle/fx_mech_dmg_sparks" );                      // ... and its sparking hull (Panzer damage)
#precache( "fx", "dlc5/tomb/fx_tomb_mech_death" );                        // THE CRASH: the blast (the Panzer's death, zoned for it)
#precache( "fx", "dlc1/castle/fx_mech_jump_landing" );                    // ... the ground impact ring (zoned with the Panzer)
#precache( "fx", "smoke/fx_smk_crashed_veh_dmg" );                        // THE WRECK: fire + smoke off the hull
#precache( "fx", "fire/fx_fire_ground_rubble_50x50" );                    // ... the fire at the nose (TRAILBLAZER's: authored Z-up)
#precache( "fx", "smoke/fx_smk_column_wind_slow_lg_dark" );               // ... the black column over the spire base
#precache( "fx", "dlc1/castle/fx_dust_landingpad" );                      // THE LANDING: the touchdown dust ring
#precache( "fx", "dlc1/castle/fx_steam_hpressure_md_castle" );            // ... the vents blowing off after it

// ---------------------------------------------------------------------------
// The knobs. Seconds unless noted.
// ---------------------------------------------------------------------------
#define TOD_RK_LOG               0       // 2026-10-02: ZEROED for the pre-publish test (was 1 = logs with dev OFF for the first playtests)
#define TOD_RK_REV               "rockets_2"   // 2: the chase camera + the crash on the corner floor (v19.68s)
#define TOD_RK_STEP              0.05    // one server frame: every flight is stepped at this rate
#define TOD_RK_LOOKAHEAD         2       // each step aims this many frames ahead over as many frames (Tower II's
                                         // trajectory fix: the client always extrapolates a segment that outlives the
                                         // 50 ms snapshot, so a late snapshot never clamps and jumps)
#define TOD_RK_SUB               32      // arc-length samples per Hermite segment
#define TOD_RK_EYE               60      // standing eye height: the rider's mover sits this far below the camera point
#define TOD_RK_MODEL_SPIRE       "tod_rocket_spire"
#define TOD_RK_MODEL_EXTRACT     "tod_rocket_extract"
#define TOD_RK_MODEL_WRECK       "tod_rocket_wreck"
#define TOD_RK_CINE_WATCHDOG_MS  32000   // LOCKSTEP TodRocketCine.lua WATCHDOG_MS (test_rocket_ride reads both)
#define TOD_RK_RIDE_TIMEOUT      25      // s: a ride whose end beat never fires is ended here (riders let go, bars off)

// THE BOARDING: a cut through black onto the hull
#define TOD_RK_BLACK_IN_MS       350
#define TOD_RK_BLACK_HOLD        0.45    // s of black: the riders are linked inside it (a snapped view is never seen)
#define TOD_RK_BLACK_OUT_MS      500

// THE ARRIVAL (the ships come down when the choice opens)
#define TOD_RK_LAND_SECS         6.2     // first sight to touchdown, each ship
#define TOD_RK_LAND_STAGGER      1.4     // the spire ship touches down this long after the extract ship
#define TOD_RK_PUSH_LEAD         0.9     // s before touchdown a player under a ship is moved off its footprint
#define TOD_RK_PUSH_PAD          56      // ... to this far outside the feet circle
#define TOD_RK_LAND_TORCH_AT     0.62    // the braking burn: the launch torch lights this far into the landing
#define TOD_RK_TORCH_SECS        2.6     // the launch torch burns this long from liftoff (then the cruise flame alone)

// THE EXTRACT RIDE (t from the reveal: the moment the black lifts)
#define TOD_RK_X_IGNITE          0.3     // the ignition sparks
#define TOD_RK_X_FLAME           1.1     // the engine lights
#define TOD_RK_X_LIFT            1.9     // LIFTOFF (the speed profile starts here)
#define TOD_RK_X_END             5.6     // the game ends (YOU ESCAPED THE TOWER): 3.7 s into the climb ("a few seconds later")
#define TOD_RK_X_FREE_AFTER_END  6.0     // the riders are let go inside stock's intermission fade (black from ~+6.1 s)

// THE ASCEND RIDE (t from the reveal)
#define TOD_RK_S_IGNITE          0.3
#define TOD_RK_S_FLAME           1.2
#define TOD_RK_S_LIFT            2.2
#define TOD_RK_S_TRAIL_AFTER     0.7     // the contrail lights this long after liftoff
#define TOD_RK_S_ALARM_LEAD      3.6     // s before the impact: the engine fails (alarm, sparks, the burning trail)
#define TOD_RK_S_SCREAM_LEAD     1.35    // s before the impact: the dive's rising scream (tod_rk_charge is 1.35 s)
#define TOD_RK_S_WHITE_IN_MS     60      // the crash: white in ...
#define TOD_RK_S_WHITE_HOLD      0.75    // ... held while the riders are set down at the Spire ...
#define TOD_RK_S_WHITE_OUT_MS    1500    // ... then it burns away through fire-orange onto the wreck
#define TOD_RK_S_FREE_AFTER      1.1     // s after the white starts clearing: the bars open, the HUD returns

// THE SOUNDS (sound/aliases/tod_rocket.csv, plus stock aliases already in the bank)
#define TOD_RK_SND_ROAR          "tod_rk_roar"       // 3D loop on the ship: the engine
#define TOD_RK_SND_IGNITE        "tod_rk_ignite"     // 3D: the ignition
#define TOD_RK_SND_LIFTOFF       "tod_rk_liftoff"    // 3D: the liftoff blast
#define TOD_RK_SND_RUMBLE        "tod_rk_rumble"     // 2D: the long low roll under a liftoff / the crash
#define TOD_RK_SND_WIND          "tod_rk_wind"       // 3D loop on each rider's mover
#define TOD_RK_SND_BOARD         "tod_rk_board"      // 2D: systems online
#define TOD_RK_SND_SCREAM        "tod_rk_charge"     // 2D: the dive builds into the impact
#define TOD_RK_SND_BOOM          "tod_rk_boom"       // 2D: THE CRASH
#define TOD_RK_SND_LAND          "zmb_mechz_arrive_land"         // stock (mechz_spiki.csv): the touchdown thud
#define TOD_RK_SND_IDLE          "tod_rk_idle"       // 3D loop: a ship on its pad
#define TOD_RK_SND_FIRE          "tod_rk_fire"       // 3D loop: the wreck burning
#define TOD_RK_SND_ALARM         "zmb_ai_mechz_incoming_alarm"   // stock (mechz_spiki.csv): the cockpit alarm
#define TOD_RK_SND_DEBRIS        "zmb_ai_mechz_destruction"      // stock: metal tearing after the crash

#namespace tod_rocket;

// =============================================================================
// INIT (from _tod_main::init, after zm_usermap::main - no clientfield here)
// =============================================================================
function init()
{
	if ( !tod_crown_data::rocket_enabled() )
		return;

	level._effect[ "tod_rk_flame" ]       = "tod/rocket/fx_rk_flame";
	level._effect[ "tod_rk_torch" ]       = "dlc1/castle/fx_rocket_exhaust_torch";
	level._effect[ "tod_rk_ignite" ]      = "dlc1/castle/fx_rocket_spark_ignition";
	level._effect[ "tod_rk_ring" ]        = "dlc1/castle/fx_rocket_smk_donut_fast";
	level._effect[ "tod_rk_padsmoke" ]    = "dlc1/castle/fx_rocket_smk_afterburn";
	level._effect[ "tod_rk_contrail" ]    = "dlc5/zmhd/fx_geotrail_jet_contrail";
	level._effect[ "tod_rk_burntrail" ]   = "killstreaks/fx_vtol_exp_smoke_trail";
	level._effect[ "tod_rk_sparkburst" ]  = "electric/fx_elec_sparks_burst_xlg_os";
	level._effect[ "tod_rk_sparkloop" ]   = "dlc1/castle/fx_mech_dmg_sparks";
	level._effect[ "tod_rk_blast" ]       = "dlc5/tomb/fx_tomb_mech_death";
	level._effect[ "tod_rk_impact" ]      = "dlc1/castle/fx_mech_jump_landing";
	level._effect[ "tod_rk_wreckfire" ]   = "smoke/fx_smk_crashed_veh_dmg";
	level._effect[ "tod_rk_nosefire" ]    = "fire/fx_fire_ground_rubble_50x50";
	level._effect[ "tod_rk_column" ]      = "smoke/fx_smk_column_wind_slow_lg_dark";
	level._effect[ "tod_rk_landdust" ]    = "dlc1/castle/fx_dust_landingpad";
	level._effect[ "tod_rk_vent" ]        = "dlc1/castle/fx_steam_hpressure_md_castle";

	// the measured hull, once (every camera step reads it)
	level.tod_rk_body = tod_crown_data::rocket_body_r();
	level.tod_rk_len = tod_crown_data::rocket_len();

	// THE HOOKS go in before the first wait (Tower II's order): live before anyone can ride.
	level.tod_rk_prev_oopa_cb = level.player_out_of_playable_area_monitor_callback;
	level.player_out_of_playable_area_monitor_callback = &playable_area_cb;
	if ( !isdefined( level.player_damage_callbacks ) )
		level.player_damage_callbacks = [];
	ArrayInsert( level.player_damage_callbacks, &ride_damage_guard, 0 );

	// The clips start OPEN: the dais and the sanctuary are floor until a ship stands on them.
	clip_set( tod_crown_data::rocket_clip_target( "spire" ), false );
	clip_set( tod_crown_data::rocket_clip_target( "extract" ), false );

	level.tod_rockets_ready = true;    // read by _tod_finale (choice + depart) and _tod_spire (choice_watch)
	rk_log( "INIT rev=" + TOD_RK_REV + " len=" + level.tod_rk_len + " body_stations=" + level.tod_rk_body.size
		+ " spire_at=" + tod_crown_data::rocket_org( "spire" ) + " extract_at=" + tod_crown_data::rocket_org( "extract" )
		+ " crash_tip=" + tod_spire_data::rocket_crash_tip() + " damage_cbs=" + level.player_damage_callbacks.size
		+ " log=" + TOD_RK_LOG );
	level thread choice_watch();
}

function choice_watch()
{
	level endon( "end_game" );
	level waittill( "tod_choice_begin" );
	level thread rockets_arrive();
}

// =============================================================================
// THE PURE PART - the flight and the camera are functions of time and data
// only, so tools/rocket/test_rocket_ride.js can run them as written. NO macros,
// NO entities, NO waits in here, and every division forces a float.
// =============================================================================

// smoothstep: 0 -> 1 with no speed at either end
function rk_ease( x )
{
	if ( x <= 0 )
		return 0;
	if ( x >= 1 )
		return 1;
	return x * x * ( 3 - 2 * x );
}

// cubic Hermite and its derivative
function rk_hermite( p0, m0, p1, m1, u )
{
	u2 = u * u;
	u3 = u2 * u;
	return p0 * ( 2 * u3 - 3 * u2 + 1 ) + m0 * ( u3 - 2 * u2 + u ) + p1 * ( -2 * u3 + 3 * u2 ) + m1 * ( u3 - u2 );
}

function rk_hermite_d( p0, m0, p1, m1, u )
{
	u2 = u * u;
	return p0 * ( 6 * u2 - 6 * u ) + m0 * ( 3 * u2 - 4 * u + 1 ) + p1 * ( -6 * u2 + 6 * u ) + m1 * ( 3 * u2 - 2 * u );
}

// A path through keys (points + UNIT tangents). Segment k's tangents are scaled by its chord, and an arc-length
// table (TOD_RK_SUB samples a segment) maps a distance along the path to a segment and a parameter.
function rk_path( pts, tans )
{
	path = SpawnStruct();
	path.pts = pts;
	path.m0 = [];
	path.m1 = [];
	path.ts = [];
	path.tk = [];
	path.tu = [];
	path.ts[ 0 ] = 0;
	path.tk[ 0 ] = 0;
	path.tu[ 0 ] = 0;
	n = 1;
	s = 0;
	for ( k = 0; k < pts.size - 1; k++ )
	{
		chord = Distance( pts[ k ], pts[ k + 1 ] );
		path.m0[ k ] = tans[ k ] * chord;
		path.m1[ k ] = tans[ k + 1 ] * chord;
		prev = pts[ k ];
		for ( j = 1; j <= TOD_RK_SUB; j++ )
		{
			u = j * 1.0 / TOD_RK_SUB;
			p = rk_hermite( pts[ k ], path.m0[ k ], pts[ k + 1 ], path.m1[ k ], u );
			s = s + Distance( prev, p );
			prev = p;
			path.ts[ n ] = s;
			path.tk[ n ] = k;
			path.tu[ n ] = u;
			n++;
		}
	}
	path.len = s;
	return path;
}

// -> struct { p, d }: the point and the unit direction at distance s along the path
function rk_path_at( path, s )
{
	n = path.ts.size;
	i = n - 1;
	if ( s <= 0 )
		i = 1;
	else if ( s < path.len )
	{
		lo = 0;
		hi = n - 1;
		while ( hi - lo > 1 )
		{
			mid = int( ( lo + hi ) / 2 );
			if ( path.ts[ mid ] < s )
				lo = mid;
			else
				hi = mid;
		}
		i = hi;
	}
	k = path.tk[ i ];
	u1 = path.tu[ i ];
	u0 = path.tu[ i - 1 ];
	if ( path.tk[ i - 1 ] != k )
		u0 = 0;
	s0 = path.ts[ i - 1 ];
	s1 = path.ts[ i ];
	f = 0;
	if ( s1 > s0 )
		f = ( s - s0 ) / ( s1 - s0 );
	if ( f < 0 )
		f = 0;
	if ( f > 1 )
		f = 1;
	u = u0 + ( u1 - u0 ) * f;
	r = SpawnStruct();
	r.p = rk_hermite( path.pts[ k ], path.m0[ k ], path.pts[ k + 1 ], path.m1[ k ], u );
	r.d = VectorNormalize( rk_hermite_d( path.pts[ k ], path.m0[ k ], path.pts[ k + 1 ], path.m1[ k ], u ) );
	return r;
}

// A piecewise-linear speed profile (key times tk, key speeds vk) scaled so its distance equals the path's length:
// the SHAPE of the ride (when it is slow, when it is fast) is the keys, the length is the path's.
function rk_speed_plan( tk, vk, length )
{
	d = 0;
	for ( i = 1; i < tk.size; i++ )
		d = d + ( vk[ i - 1 ] + vk[ i ] ) * 0.5 * ( tk[ i ] - tk[ i - 1 ] );
	sp = SpawnStruct();
	sp.tk = tk;
	sp.scale = length / d;
	sp.vk = [];
	for ( i = 0; i < vk.size; i++ )
		sp.vk[ i ] = vk[ i ] * sp.scale;
	sp.len = length;
	sp.t0 = tk[ 0 ];
	sp.t_end = tk[ tk.size - 1 ];
	return sp;
}

// distance along the path t seconds into the ride (0 before the profile's first key: the ship sits on its pad)
function rk_dist_at( sp, t )
{
	if ( t <= sp.tk[ 0 ] )
		return 0;
	s = 0;
	for ( i = 1; i < sp.tk.size; i++ )
	{
		t0 = sp.tk[ i - 1 ];
		t1 = sp.tk[ i ];
		v0 = sp.vk[ i - 1 ];
		v1 = sp.vk[ i ];
		if ( t < t1 )
		{
			dt = t - t0;
			a = ( v1 - v0 ) / ( t1 - t0 );
			return s + v0 * dt + 0.5 * a * dt * dt;
		}
		s = s + ( v0 + v1 ) * 0.5 * ( t1 - t0 );
	}
	return sp.len;
}

// angles for a +X-nosed model pointing along d (straight up keeps the fallback yaw: VectorToAngles has none)
function rk_dir_angles( d, yaw_fb )
{
	a = VectorToAngles( d );
	if ( abs( d[ 0 ] ) + abs( d[ 1 ] ) < 0.03 )
		return ( AngleClamp180( a[ 0 ] ), yaw_fb, 0 );
	return ( AngleClamp180( a[ 0 ] ), AngleClamp180( a[ 1 ] ), 0 );
}

// THE SHIP at time t: struct { s, org (the pivot: the feet), dir (along the path), nose, ang }.
// A LANDING keeps its nose up (tail first on its flame), leaning off its sideways travel.
function rk_state( plan, t )
{
	st = SpawnStruct();
	st.s = rk_dist_at( plan.sp, t );
	at = rk_path_at( plan.path, st.s );
	st.org = at.p;
	st.dir = at.d;
	st.nose = at.d;
	if ( plan.nose_up )
		st.nose = VectorNormalize( ( 0, 0, 1 ) - ( at.d[ 0 ], at.d[ 1 ], 0 ) * 0.35 );
	st.ang = rk_dir_angles( st.nose, plan.yaw0 );
	return st;
}

// the hull's body radius at x along the ship (41 measured stations, art/fan_props/manifest.json)
function rk_body_r( prof, len, x )
{
	f = x * 40.0 / len;
	if ( f <= 0 )
		return prof[ 0 ];
	if ( f >= 40 )
		return prof[ 40 ];
	i = int( f );
	return prof[ i ] + ( prof[ i + 1 ] - prof[ i ] ) * ( f - i );
}

// THE CAMERA at time t, given the ship there (st) - THE CHASE CAMERA (v19.68s; user: "permanently above the ship so
// you can see it like in third person but also see where its heading" + "always have the ship slightly seen at bottom
// of screen and able to see ahead of the ship"). One rule for the whole ride:
//   * the camera sits BEHIND the ship's centre along the flight (b) and off it on the ship's "up" side (h). That side
//     is u = R x d: R is the ship's right hand (generated, horizontal), d the flight direction, so u is "up" while
//     the ship flies level, the camera's start side while it climbs straight up, and forward-and-up in the dive -
//     which puts the camera right above the ship looking down the dive. Nothing flips: u turns with the flight.
//   * the view looks at the ship's centre turned `tilt` degrees toward the flight: the ship always sits `tilt` below
//     the middle of the frame and the rest of the frame is where it is going.
//   * on the pad the camera starts beside the ship (b0 / h0: behind would be under the floor) and settles to the
//     chase over `settle` seconds from liftoff, falling back as the ship pulls away; while the ship climbs straight
//     up the chase sits further out to the side (bc / hc) so the view never looks straight up, and it moves behind
//     and above (b1 / h1) as the flight levels out.
function rk_cam( c, st, prof, len, t )
{
	d = st.dir;
	ctr = st.org + st.nose * ( len * 0.5 );
	u = VectorCross( c.right, d );
	if ( Length( u ) < 0.05 )
		u = ( 0, 0, 1 );
	u = VectorNormalize( u );
	// flying level or down: behind and above (b1 / h1); climbing straight up: further out to the side (bc / hc), so
	// the view never looks straight up (a near-vertical view spins on its yaw)
	f = rk_ease( ( c.cz_climb - d[ 2 ] ) / ( c.cz_climb - c.cz_cruise ) );
	bs = c.bc + ( c.b1 - c.bc ) * f;
	hs = c.hc + ( c.h1 - c.hc ) * f;
	w = rk_ease( ( t - c.lift_at ) / c.settle );
	b = c.b0 + ( bs - c.b0 ) * w;
	h = c.h0 + ( hs - c.h0 ) * w;
	cam = SpawnStruct();
	cam.org = ctr - d * b + u * h;
	vs = VectorNormalize( ctr - cam.org );
	k = d - vs * VectorDot( d, vs );
	if ( Length( k ) < 0.01 )
		k = u;
	k = VectorNormalize( k );
	cam.look = VectorNormalize( vs * cos( c.tilt ) + k * sin( c.tilt ) );
	a = VectorToAngles( cam.look );
	cam.ang = ( AngleClamp180( a[ 0 ] ), AngleClamp180( a[ 1 ] ), 0 );
	cam.side = u;
	return cam;
}

// `want` next to `now` (each angle within 180 of the entity's own), so a RotateTo always takes the short way
function rk_step_ang( now, want )
{
	return ( now[ 0 ] + AngleClamp180( want[ 0 ] - now[ 0 ] ), now[ 1 ] + AngleClamp180( want[ 1 ] - now[ 1 ] ), now[ 2 ] + AngleClamp180( want[ 2 ] - now[ 2 ] ) );
}

// THE PLANS - one per flight. kind = "spire" | "extract" (the rides) or "land_spire" | "land_extract" (the arrival).
function rk_plan( kind, keys, tans, yaw0, tk, vk, nose_up )
{
	plan = SpawnStruct();
	plan.kind = kind;
	plan.path = rk_path( keys, tans );
	plan.sp = rk_speed_plan( tk, vk, plan.path.len );
	plan.yaw0 = yaw0;
	plan.nose_up = nose_up;
	return plan;
}

// THE CAMERA PLAN (the chase camera, rk_cam). Distances in units from the ship's centre, the tilt in degrees,
// times in ride seconds.
function rk_cam_plan( kind, right, lift_at, len )
{
	c = SpawnStruct();
	c.kind = kind;
	c.right = right;      // the ship's right hand (generated): the camera's "up" turns about it with the flight
	c.lift_at = lift_at;  // the ride's liftoff: the camera starts beside the ship and settles behind it from here
	c.settle = 2.5;
	c.b0 = 40;            // on the pad: 40 back along the flight (a little below the ship's centre) ...
	c.h0 = 300;           // ... and 300 out on the camera's side - beside the ship, looking up past it
	c.bc = 380;           // climbing straight up: 380 below the ship's centre ...
	c.hc = 420;           // ... and 420 out to the side (the view ~60 deg up, never straight up)
	c.b1 = 600;           // flying level or diving: 600 behind the ship's centre ...
	c.h1 = 230;           // ... and 230 above it
	c.cz_climb = 0.95;    // the flight within ~18 deg of straight up = the climb setting ...
	c.cz_cruise = 0.5;    // ... 60 deg or more off it = the chase setting
	c.tilt = 18;          // the ship sits this far below the middle of the frame; the rest is where it is going
	c.len = len;
	return c;
}

// The plans the game flies, built from the GENERATED keys. Speeds: units / s at each key time (the ride's own
// clock; the profile starts at liftoff and is scaled to the path's length, so only its SHAPE is authored here).
function plan_ride( kind )
{
	if ( kind == "spire" )
	{
		tk = array( TOD_RK_S_LIFT, TOD_RK_S_LIFT + 2.4, TOD_RK_S_LIFT + 4.0, TOD_RK_S_LIFT + 7.0, TOD_RK_S_LIFT + 9.4, TOD_RK_S_LIFT + 10.4 );
		vk = array( 0, 1900, 3000, 3400, 5600, 6200 );
		return rk_plan( kind, tod_crown_data::rocket_keys( "spire" ), tod_crown_data::rocket_tans( "spire" ), tod_crown_data::rocket_yaw( "spire" ), tk, vk, false );
	}
	tk = array( TOD_RK_X_LIFT, TOD_RK_X_LIFT + 3.7, TOD_RK_X_LIFT + 6.3, TOD_RK_X_LIFT + 12.0 );
	vk = array( 0, 1700, 2150, 2150 );
	return rk_plan( kind, tod_crown_data::rocket_keys( "extract" ), tod_crown_data::rocket_tans( "extract" ), tod_crown_data::rocket_yaw( "extract" ), tk, vk, false );
}

function plan_land( kind )
{
	// fast out of the sky, a long braking burn, a soft touchdown (the profile's last key = touchdown)
	tk = array( 0, TOD_RK_LAND_SECS * 0.45, TOD_RK_LAND_SECS * 0.82, TOD_RK_LAND_SECS );
	vk = array( 3400, 1500, 320, 45 );
	return rk_plan( "land_" + kind, tod_crown_data::rocket_land_keys( kind ), tod_crown_data::rocket_land_tans( kind ), tod_crown_data::rocket_yaw( kind ), tk, vk, true );
}

function plan_cam( kind, ride )
{
	// the ship's right hand (generated per ride: the camera's start side is z x it), settling from liftoff
	lift = TOD_RK_X_LIFT;
	if ( kind == "spire" )
		lift = TOD_RK_S_LIFT;
	return rk_cam_plan( kind, tod_crown_data::rocket_cam_right( kind ), lift, level.tod_rk_len );
}

// =============================================================================
// THE ARRIVAL - both ships come down out of the sky when the choice opens.
// =============================================================================
function rockets_arrive()
{
	level endon( "end_game" );

	level.tod_rk_ships = [];
	level.tod_rk_landed = 0;
	t0 = GetTime();
	level thread ship_land( "extract", 0 );
	level thread ship_land( "spire", TOD_RK_LAND_STAGGER );
	rk_log( "ARRIVE land_secs=" + TOD_RK_LAND_SECS + " stagger=" + TOD_RK_LAND_STAGGER );

	// both down (or failed: a ship that could not spawn counts so the prompts still arm on the other)
	while ( level.tod_rk_landed < 2 )
		wait 0.1;
	rockets_arm();
	rk_log( "ARRIVE_DONE ms=" + ( GetTime() - t0 ) + " spire=" + isdefined( level.tod_rk_ships[ "spire" ] )
		+ " extract=" + isdefined( level.tod_rk_ships[ "extract" ] ) );
}

function ship_land( kind, delay )
{
	level endon( "end_game" );
	if ( delay > 0 )
		wait delay;

	plan = plan_land( kind );
	st = rk_state( plan, 0 );
	model = TOD_RK_MODEL_EXTRACT;
	if ( kind == "spire" )
		model = TOD_RK_MODEL_SPIRE;
	ship = Spawn( "script_model", st.org );
	if ( !isdefined( ship ) )
	{
		level.tod_rk_landed++;
		rk_log( "ABORT land kind=" + kind + " why=ship_spawn_failed" );
		return;
	}
	ship SetModel( model );
	ship.angles = st.ang;
	ship.tod_rk_kind = kind;
	level.tod_rk_ships[ kind ] = ship;

	// the engine on the way down (a host on the bell, its +X pointing out of the nozzle)
	flame = engine_host( ship, "tod_rk_flame" );
	ship PlayLoopSound( TOD_RK_SND_ROAR, 0.5 );
	rk_log( "LAND_START kind=" + kind + " from=" + st.org + " len=" + int( plan.path.len ) + " secs=" + plan.sp.t_end
		+ " scale=" + plan.sp.scale + " flame_host=" + isdefined( flame ) );

	pad = tod_crown_data::rocket_org( kind );
	pushed = false;
	torch = undefined;
	n = int( plan.sp.t_end / TOD_RK_STEP + 0.5 );
	for ( i = 1; i <= n; i++ )
	{
		j = i + TOD_RK_LOOKAHEAD - 1;
		if ( j > n )
			j = n;
		secs = ( j - i + 1 ) * TOD_RK_STEP;
		sj = rk_state( plan, j * TOD_RK_STEP );
		ship MoveTo( sj.org, secs );
		ship RotateTo( rk_step_ang( ship.angles, sj.ang ), secs );
		if ( !isdefined( torch ) && i * TOD_RK_STEP >= plan.sp.t_end * TOD_RK_LAND_TORCH_AT )
			torch = engine_host( ship, "tod_rk_torch" );
		if ( !pushed && ( n - i ) * TOD_RK_STEP <= TOD_RK_PUSH_LEAD )
		{
			pushed = true;
			clear_footprint( kind, pad );
		}
		wait TOD_RK_STEP;
	}

	// TOUCHDOWN: exactly on the pad, upright, the engine cut, dust and a thud, the vents blow off.
	ship.origin = pad;
	ship.angles = ( -90, tod_crown_data::rocket_yaw( kind ), 0 );
	if ( isdefined( flame ) )
		flame Delete();
	if ( isdefined( torch ) )
		torch Delete();
	ship StopLoopSound( 1 );
	level thread fx_burst( "tod_rk_landdust", pad + ( 0, 0, 4 ), ( -90, 0, 0 ), 4 );
	level thread fx_burst( "tod_rk_vent", pad + ( 0, 0, 24 ), ( -90, 0, 0 ), 5 );
	tod_perk_scatter::play_sound_at_origin( pad, TOD_RK_SND_LAND, 4 );
	Earthquake( 0.32, 0.8, pad, 900 );
	// Push again in the clip's own frame (2026-10-02 review): anyone who stepped back
	// onto the pad in the last TOD_RK_PUSH_LEAD would be shut inside the solid - in
	// solo that is a softlock at the end of a run (the doors' rule: clear, then close).
	clear_footprint( kind, pad );
	clip_set( tod_crown_data::rocket_clip_target( kind ), true );
	level thread ship_idle( ship );
	level.tod_rk_landed++;
	rk_log( "LAND kind=" + kind + " at=" + pad + " yaw=" + tod_crown_data::rocket_yaw( kind ) );
}

// the idle: a low hum off the ship while it waits on its pad, once the landing roar has faded out of the
// entity's one loop-sound slot (and never once a choice is made: the ride owns the ship's sounds then)
function ship_idle( ship )
{
	level endon( "end_game" );
	wait 1.1;
	if ( isdefined( ship ) && !isdefined( level.tod_rk_chosen ) )
		ship PlayLoopSound( TOD_RK_SND_IDLE, 1 );
}

// Anyone standing where a ship is about to set down is moved just off its footprint (outward along the line
// from the ship's axis, onto the floor at their own height), so a ship can never land on a player.
function clear_footprint( kind, pad )
{
	r = tod_crown_data::rocket_feet_r() + TOD_RK_PUSH_PAD;
	players = GetPlayers();
	foreach ( p in players )
	{
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		dz = p.origin[ 2 ] - pad[ 2 ];
		if ( dz < -120 || dz > 300 )
			continue;
		d = ( p.origin[ 0 ] - pad[ 0 ], p.origin[ 1 ] - pad[ 1 ], 0 );
		if ( Length( d ) >= r )
			continue;
		dir = ( 0, -1, 0 );                       // dead centre: out toward the nave (the gate side)
		if ( Length( d ) > 1 )
			dir = VectorNormalize( d );
		dest = ( pad[ 0 ], pad[ 1 ], p.origin[ 2 ] ) + dir * r;
		p SetOrigin( dest );
		tod_perk_scatter::derez_burst( dest );
		rk_log( "PUSH kind=" + kind + " player=" + p GetEntityNumber() + " to=" + dest );
	}
}

// =============================================================================
// THE PROMPTS - first committed hold wins
// =============================================================================
function rockets_arm()
{
	level endon( "end_game" );
	if ( isdefined( level.tod_rk_chosen ) )
		return;
	level.tod_rk_trigs = [];
	// BOTH prompts arm even if a ship failed to spawn (the pool was full): ride_extract / ride_spire return false
	// without a ship and their callers fall back to the old send-off / the teleport, so a choice is never lost.
	// The strings are the existing ones (_tod_finale / _tod_spire): not one new hint string.
	// v19.68t (user: "The trigger for the ascend or extract space ships should be all around the spaceship. Not just
	// one side"): each ship arms a RING of prompts - every open spot gen_tower_map.js rkRing found on its push ring
	// (up to 8; a spot inside a solid is dropped there). level.tod_rk_trigs is ONE flat list of every prompt.
	n_extract = board_trigger( "extract", "Hold ^3[{+activate}]^7 ^2EXTRACT^7 - leave the tower" );
	n_spire = board_trigger( "spire", "Hold ^3[{+activate}]^7 ^5ASCEND^7 - to THE ENDLESS SPIRE / ^1one way, no return" );
	rk_log( "ARM extract=" + n_extract + " spire=" + n_spire + " (prompts round each ship)" );
}

// One trigger per open spot round the ship (tod_crown_data::rocket_trigs, spot 0 = the nave side); all of a ship's
// spots share its hint and its one choice. Returns how many armed.
function board_trigger( kind, hint )
{
	n = 0;
	spots = tod_crown_data::rocket_trigs( kind );
	foreach ( org in spots )
	{
		t = Spawn( "trigger_radius_use", org, 0, tod_crown_data::rocket_trig_r(), tod_crown_data::rocket_trig_h() );
		if ( !isdefined( t ) )
			continue;
		t TriggerIgnoreTeam();     // REQUIRED for a script-spawned use-trigger
		t SetCursorHint( "HINT_NOICON" );
		t SetHintString( hint );
		level thread board_watch( t, kind );
		level.tod_rk_trigs[ level.tod_rk_trigs.size ] = t;
		n++;
	}
	return n;
}

function board_watch( t, kind )
{
	level endon( "end_game" );
	for ( ;; )
	{
		t waittill( "trigger", player );
		if ( isdefined( level.tod_rk_chosen ) )
			return;
		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( !( zm_utility::is_player_valid( player ) ) )
			continue;
		if ( player zm_utility::in_revive_trigger() )
			continue;   // a revive press is not a choice
		break;
	}
	level.tod_rk_chosen = kind;
	retire_triggers();
	rk_log( "CHOICE kind=" + kind + " by=" + player GetEntityNumber() );
	// the existing contract: _tod_finale::choice_phase hears tod_extract (-> depart -> ride_extract),
	// _tod_spire::choice_watch hears tod_ascend (-> ride_spire -> ascend_run in the white)
	if ( kind == "extract" )
		level notify( "tod_extract" );
	else
		level notify( "tod_ascend" );
}

function retire_triggers()
{
	if ( !isdefined( level.tod_rk_trigs ) )
		return;
	foreach ( t in level.tod_rk_trigs )
	{
		if ( isdefined( t ) )
		{
			t SetHintString( "" );
			t TriggerEnable( false );
		}
	}
}

// =============================================================================
// THE RIDES
// =============================================================================

// EXTRACT. Called by _tod_finale::depart (which owns ending the game): returns at the END beat, with the ride
// still climbing; its tail lets the riders go inside stock's intermission fade.
function ride_extract()
{
	ship = undefined;
	if ( isdefined( level.tod_rk_ships ) )
		ship = level.tod_rk_ships[ "extract" ];
	if ( !isdefined( ship ) )
	{
		rk_log( "ABORT ride=extract why=no_ship" );
		return false;
	}
	level.tod_rk_ride = SpawnStruct();
	level thread ride_run( "extract", ship );
	msg = level util::waittill_any_timeout( TOD_RK_RIDE_TIMEOUT, "tod_rk_extract_end" );
	if ( msg == "timeout" )
		ride_rescue( "extract" );
	return true;
}

// ASCEND. Called by _tod_spire::choice_watch: returns in the WHITE of the crash, with every rider already set
// down at the Spire's arrival ring (facing the wreck), so ascend_run can flip the world while nothing can be seen.
function ride_spire()
{
	ship = undefined;
	if ( isdefined( level.tod_rk_ships ) )
		ship = level.tod_rk_ships[ "spire" ];
	if ( !isdefined( ship ) )
	{
		rk_log( "ABORT ride=spire why=no_ship" );
		return false;
	}
	level.tod_rk_ride = SpawnStruct();
	level thread ride_run( "spire", ship );
	msg = level util::waittill_any_timeout( TOD_RK_RIDE_TIMEOUT, "tod_rocket_impact" );
	if ( msg == "timeout" )
		ride_rescue( "spire" );
	return true;
}

// A ride whose end beat never came (a beat thread died): stop stepping, give everyone their screen and their body
// back where they are. The caller carries on - depart ends the game, ascend_run teleports the party to the Spire
// (no wreck: tod_ascend_by_rocket stays unset, so it plays its own arrival flash).
function ride_rescue( kind )
{
	ride = level.tod_rk_ride;
	ride.cut = true;
	cine_all( 0, 400 );
	n = 0;
	if ( isdefined( ride.riders ) )
	{
		foreach ( p in ride.riders )
		{
			if ( !isdefined( p ) )
				continue;
			p rider_free( undefined, 0 );
			n++;
		}
	}
	rk_log( "ABORT ride=" + kind + " why=timeout_" + TOD_RK_RIDE_TIMEOUT + "s riders_freed=" + n );
}

function ride_run( kind, ship )
{
	plan = plan_ride( kind );
	cam = plan_cam( kind, plan );
	ride = level.tod_rk_ride;
	ride.kind = kind;
	ride.plan = plan;
	ride.cam = cam;
	ride.riders = [];
	ride.t0 = GetTime();

	// the other ship has no part in this: its prompt is retired, its idle stops
	other = "spire";
	if ( kind == "spire" )
		other = "extract";
	if ( isdefined( level.tod_rk_ships[ other ] ) )
		level.tod_rk_ships[ other ] StopLoopSound( 1 );
	ship StopLoopSound( 0.5 );

	rk_log( "RIDE kind=" + kind + " path_len=" + int( plan.path.len ) + " t_end=" + plan.sp.t_end + " scale=" + plan.sp.scale );

	// 1. THE BOARDING - letterbox + black for everyone (spectators watch through a rider's eyes)
	cine_all( 1, 400 );
	wait 0.05;
	cine_all( 3, TOD_RK_BLACK_IN_MS );
	wait TOD_RK_BLACK_HOLD;
	st0 = rk_state( plan, 0 );
	c0 = rk_cam( cam, st0, level.tod_rk_body, level.tod_rk_len, 0 );
	players = GetPlayers();
	foreach ( p in players )
	{
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( isdefined( p.sessionstate ) && p.sessionstate != "playing" )
			continue;
		if ( p rider_board( c0 ) )
			ride.riders[ ride.riders.size ] = p;
	}
	foreach ( p in GetPlayers() )
		p PlayLocalSound( TOD_RK_SND_BOARD );
	// the crash site streams in while they fly (the textures the reveal shows)
	if ( kind == "spire" )
	{
		foreach ( p in ride.riders )
			p zm_utility::create_streamer_hint( tod_spire_data::rocket_crash_tip() + ( 0, 0, 200 ), ( 0, 0, 0 ), 0.9, 30 );
	}
	clip_set( tod_crown_data::rocket_clip_target( kind ), false );   // nobody walks into the ship any more
	rk_log( "BOARD kind=" + kind + " riders=" + ride.riders.size + " cam0=" + c0.org + " ang0=" + c0.ang );
	wait 0.1;
	cine_all( 4, TOD_RK_BLACK_OUT_MS );

	// 2. THE FLIGHT - every server frame: the ship and every rider's camera, aimed LOOKAHEAD frames ahead
	if ( kind == "spire" )
		level thread beats_spire( ship, plan );
	else
		level thread beats_extract( ship, plan );

	t_stop = plan.sp.t_end;
	n = int( t_stop / TOD_RK_STEP + 0.5 );
	worst = 0;
	for ( i = 1; i <= n; i++ )
	{
		if ( !isdefined( ship ) )
			break;
		j = i + TOD_RK_LOOKAHEAD - 1;
		if ( j > n )
			j = n;
		secs = ( j - i + 1 ) * TOD_RK_STEP;
		tj = j * TOD_RK_STEP;
		sj = rk_state( plan, tj );
		cj = rk_cam( cam, sj, level.tod_rk_body, level.tod_rk_len, tj );
		ship MoveTo( sj.org, secs );
		ship RotateTo( rk_step_ang( ship.angles, sj.ang ), secs );
		want = cj.org - ( 0, 0, TOD_RK_EYE );
		foreach ( p in ride.riders )
		{
			if ( !isdefined( p ) || !isdefined( p.tod_rk_mover ) )
				continue;
			m = p.tod_rk_mover;
			m MoveTo( want, secs );
			m RotateTo( rk_step_ang( m.angles, cj.ang ), secs );
		}
		ride.t = ( i - 1 ) * TOD_RK_STEP;
		ride.st = sj;
		// the camera check the user's first play needs: where the eye really is vs the plan (a few times a ride)
		if ( ( i % 40 ) == 0 && ride.riders.size > 0 && isdefined( ride.riders[ 0 ] ) )
		{
			r0 = ride.riders[ 0 ];
			ci = rk_cam( cam, rk_state( plan, ( i - 1 ) * TOD_RK_STEP ), level.tod_rk_body, level.tod_rk_len, ( i - 1 ) * TOD_RK_STEP );
			err = Distance( r0 GetEye(), ci.org );
			if ( err > worst )
				worst = err;
			rk_log( "CAM kind=" + kind + " t=" + ride.t + " ship=" + ship.origin + " eye=" + r0 GetEye() + " plan_eye=" + ci.org
				+ " eye_err=" + err + " ang=" + r0 GetPlayerAngles() + " plan_ang=" + ci.ang );
		}
		if ( IS_TRUE( ride.cut ) )
			break;
		wait TOD_RK_STEP;
	}
	ride.done = true;
	rk_log( "FLIGHT_END kind=" + kind + " frames=" + n + " worst_eye_err=" + worst + " cut=" + IS_TRUE( ride.cut ) );
}

// --- the riders -------------------------------------------------------------
// self = player. Takes everything a rider gives up; rider_free gives it back. -> true when boarded.
function rider_board( c0 )
{
	if ( self laststand::player_is_in_laststand() )
	{
		self zm_laststand::auto_revive( self );   // stock's free revive (its solo Quick Revive lane)
		rk_log( "REVIVE player=" + self GetEntityNumber() + " (downed at boarding)" );
	}
	m = Spawn( "script_model", c0.org - ( 0, 0, TOD_RK_EYE ) );
	if ( !isdefined( m ) )
	{
		rk_log( "ABORT rider=" + self GetEntityNumber() + " why=mover_spawn_failed" );
		return false;
	}
	m SetModel( "tag_origin" );
	m.angles = c0.ang;
	self.tod_rocket_riding = true;    // FIRST: the hooks spare a rider from this line on
	self.tod_rk_mover = m;
	self zm_utility::increment_ignoreme();
	self.tod_rk_ignore = true;
	if ( !IS_TRUE( self.tod_menu_frozen ) )
	{
		self DisableWeapons();
		self DisableOffhandWeapons();
		self.tod_rk_arms = true;
	}
	self HideViewModel();
	self Ghost();                      // nobody sees four players hanging off a rocket (the thrasher's lane)
	self AllowCrouch( false );
	self AllowProne( false );
	self AllowJump( false );
	self SetStance( "stand" );
	self PlayerLinkToDelta( m, "tag_origin", 1, 0, 0, 0, 0 );   // locked on the camera path (Tower II's lane)
	level thread rider_guard( self, m );
	return true;
}

// Level-threaded: a rider who disconnects mid-ride leaves no mover behind.
function rider_guard( p, m )
{
	p waittill( "disconnect" );
	if ( isdefined( m ) )
		m Delete();
}

// self = player. Gives back everything rider_board took. Idempotent. `place` = an origin to set down at.
function rider_free( place, yaw )
{
	if ( !IS_TRUE( self.tod_rocket_riding ) )
		return;
	self Unlink();
	if ( isdefined( place ) )
	{
		self SetOrigin( place );
		self SetVelocity( ( 0, 0, 0 ) );
		self SetPlayerAngles( ( 0, yaw, 0 ) );
	}
	if ( isdefined( self.tod_rk_mover ) )
	{
		self.tod_rk_mover StopLoopSound( 0.5 );
		self.tod_rk_mover Delete();
	}
	self.tod_rk_mover = undefined;
	self Show();
	self ShowViewModel();
	self AllowCrouch( true );
	self AllowProne( true );
	self AllowJump( true );
	if ( IS_TRUE( self.tod_rk_arms ) )
	{
		self.tod_rk_arms = undefined;
		if ( !IS_TRUE( self.tod_menu_frozen ) )
		{
			self EnableWeapons();
			self EnableOffhandWeapons();
		}
	}
	if ( IS_TRUE( self.tod_rk_ignore ) )
	{
		self.tod_rk_ignore = undefined;
		self zm_utility::decrement_ignoreme();
	}
	self.tod_rocket_riding = undefined;
}

// --- the beats --------------------------------------------------------------
function beats_extract( ship, plan )
{
	ride = level.tod_rk_ride;
	ride_wait( TOD_RK_X_IGNITE );
	ignite( ship );
	ride_wait( TOD_RK_X_FLAME - TOD_RK_X_IGNITE );
	ride.flame = engine_host( ship, "tod_rk_flame" );
	ship PlayLoopSound( TOD_RK_SND_ROAR, 0.6 );
	pad_smoke( tod_crown_data::rocket_org( "extract" ) );
	quake_on( ship, 0.22, 1.0, 1400 );
	ride_wait( TOD_RK_X_LIFT - TOD_RK_X_FLAME );
	liftoff( ship, "extract" );
	ride_wait( 0.7 );
	ride.trail = engine_host( ship, "tod_rk_contrail" );
	level thread quake_follow( ship, 0.30, TOD_RK_X_END - TOD_RK_X_LIFT - 0.7 );
	ride_wait( TOD_RK_X_END - TOD_RK_X_LIFT - 0.7 );

	// THE END: the bars go (the end screen takes the frame), the game ends on _tod_finale's thread. The ship
	// keeps climbing behind YOU ESCAPED THE TOWER; the riders are let go inside stock's intermission fade.
	cine_all( 0, 400 );
	rk_beat( "END_GAME", ship );
	level notify( "tod_rk_extract_end" );
	level thread extract_tail( ship );
}

function extract_tail( ship )
{
	ride = level.tod_rk_ride;
	wait TOD_RK_X_FREE_AFTER_END;
	ride.cut = true;
	// stock's player_intermission fades to black at +5 s and sets the riders down at the base's intermission
	// struct at +6 s; let them go inside the black, onto that point, so its SetOrigin meets an unlinked player.
	spot = struct::get( "intermission", "targetname" );
	foreach ( p in ride.riders )
	{
		if ( !isdefined( p ) )
			continue;
		if ( isdefined( spot ) )
		{
			yaw = 0;
			if ( isdefined( spot.angles ) )
				yaw = spot.angles[ 1 ];
			p rider_free( spot.origin, yaw );
		}
		else
			p rider_free( undefined, 0 );
	}
	rk_log( "FREE ride=extract riders=" + ride.riders.size + " at_intermission=" + isdefined( spot ) );
}

function beats_spire( ship, plan )
{
	ride = level.tod_rk_ride;
	t_imp = plan.sp.t_end;
	ride_wait( TOD_RK_S_IGNITE );
	ignite( ship );
	ride_wait( TOD_RK_S_FLAME - TOD_RK_S_IGNITE );
	ride.flame = engine_host( ship, "tod_rk_flame" );
	ship PlayLoopSound( TOD_RK_SND_ROAR, 0.6 );
	pad_smoke( tod_crown_data::rocket_org( "spire" ) );
	quake_on( ship, 0.22, 1.0, 1400 );
	ride_wait( TOD_RK_S_LIFT - TOD_RK_S_FLAME );
	liftoff( ship, "spire" );
	ride_wait( TOD_RK_S_TRAIL_AFTER );
	ride.trail = engine_host( ship, "tod_rk_contrail" );
	level thread quake_follow( ship, 0.26, 3.0 );
	foreach ( p in ride.riders )
	{
		if ( isdefined( p ) && isdefined( p.tod_rk_mover ) )
			p.tod_rk_mover PlayLoopSound( TOD_RK_SND_WIND, 1.5 );
	}

	// THE FAILURE - the alarm in the cockpit, sparks off the hull, the engine coughs, it burns
	ride_wait( t_imp - TOD_RK_S_ALARM_LEAD - TOD_RK_S_LIFT - TOD_RK_S_TRAIL_AFTER );
	foreach ( p in ride.riders )
	{
		if ( isdefined( p ) )
			p PlayLocalSound( TOD_RK_SND_ALARM );
	}
	spark = hull_host( ship, 0.55 );
	ride.spark = spark;
	level thread fx_play_on_new_host( spark, "tod_rk_sparkloop", "tod_rk_sparkburst" );
	if ( isdefined( ride.trail ) )
		ride.trail Delete();
	ride.trail = engine_host( ship, "tod_rk_burntrail" );
	level thread quake_follow( ship, 0.34, TOD_RK_S_ALARM_LEAD );
	rk_beat( "FAIL", ship );

	// THE DIVE - the scream builds into the ground
	ride_wait( TOD_RK_S_ALARM_LEAD - TOD_RK_S_SCREAM_LEAD );
	foreach ( p in ride.riders )
	{
		if ( isdefined( p ) )
			p PlayLocalSound( TOD_RK_SND_SCREAM );
	}
	rk_beat( "SCREAM", ship );
	ride_wait( TOD_RK_S_SCREAM_LEAD - TOD_RK_S_WHITE_IN_MS / 1000.0 );

	// THE CRASH
	crash( ship );
}

// THE CRASH - white, the boom, the riders set down at the arrival looking at the wreck, the world flips under the
// white (tod_rocket_impact -> _tod_spire::ascend_run), the white burns away onto the burning wreck.
function crash( ship )
{
	ride = level.tod_rk_ride;
	cine_all( 5, TOD_RK_S_WHITE_IN_MS );
	foreach ( p in GetPlayers() )
	{
		p PlayLocalSound( TOD_RK_SND_BOOM );
		p PlayRumbleOnEntity( "damage_heavy" );
	}
	hold = TOD_RK_S_WHITE_IN_MS / 1000.0 + 0.05;
	wait hold;
	ride.cut = true;   // the flight loop stops stepping (the ship is about to go)

	tip = tod_spire_data::rocket_crash_tip();
	// the ship becomes the wreck: the flying model goes, the burnt one stands in the corner
	if ( isdefined( ride.flame ) )
		ride.flame Delete();
	if ( isdefined( ride.trail ) )
		ride.trail Delete();
	if ( isdefined( ride.spark ) )
		ride.spark Delete();
	if ( isdefined( ship ) )
	{
		ship StopLoopSound( 0.1 );
		ship Delete();
	}
	level thread wreck_spawn();
	level thread fx_burst( "tod_rk_blast", tip + ( 0, 0, 40 ), ( -90, 0, 0 ), 8 );
	level thread fx_burst( "tod_rk_impact", tip + ( 0, 0, 2 ), ( -90, 0, 0 ), 8 );
	level thread fx_burst( "tod_rk_ring", tip + ( 0, 0, 6 ), ( -90, 0, 0 ), 6 );
	mid = tod_spire_data::rocket_wreck_org() + AnglesToForward( tod_spire_data::rocket_wreck_angles() ) * ( level.tod_rk_len * 0.5 );
	level thread fx_burst_after( 0.3, "tod_rk_blast", mid, ( -90, 0, 0 ), 8 );
	tod_perk_scatter::play_sound_at_origin( tip, TOD_RK_SND_DEBRIS, 6 );
	foreach ( p in GetPlayers() )
		p PlayLocalSound( TOD_RK_SND_RUMBLE );

	// the riders: down at the arrival ring, facing the wreck (ascend_run's own placement repeats this ring)
	arrival = tod_spire_data::arrival_org();
	yaw = tod_spire_data::rocket_arrival_yaw();
	k = 0;
	foreach ( p in ride.riders )
	{
		if ( !isdefined( p ) )
			continue;
		ang = k * 90;
		p rider_free( arrival + ( cos( ang ) * 56, sin( ang ) * 56, 0 ), yaw );
		k++;
	}
	Earthquake( 0.55, 2.2, arrival, 1600 );
	rk_beat( "IMPACT", undefined );
	rk_log( "IMPACT tip=" + tip + " riders_set=" + k + " arrival=" + arrival + " face_yaw=" + yaw );

	// the other ship has no reason to stay in a world that is about to be torn down
	if ( isdefined( level.tod_rk_ships[ "extract" ] ) )
	{
		level.tod_rk_ships[ "extract" ] StopLoopSound( 0.1 );
		level.tod_rk_ships[ "extract" ] Delete();
	}
	clip_set( tod_crown_data::rocket_clip_target( "extract" ), false );
	if ( isdefined( level.tod_rk_trigs ) )
	{
		foreach ( t in level.tod_rk_trigs )
		{
			if ( isdefined( t ) )
				t Delete();
		}
		level.tod_rk_trigs = [];
	}
	level.tod_ascend_by_rocket = true;   // ascend_run: no teleport flash, face the wreck
	level notify( "tod_rocket_impact" );

	// THE REVEAL
	wait TOD_RK_S_WHITE_HOLD;
	cine_all( 6, TOD_RK_S_WHITE_OUT_MS );
	wait TOD_RK_S_FREE_AFTER;
	cine_all( 0, 650 );
	rk_log( "FREE ride=spire riders=" + ride.riders.size + " ms=" + ( GetTime() - ride.t0 ) );
}

// THE WRECK - the burnt twin, nose-down in the arena's NW corner floor, burning (its generated clip keeps players
// off it; the corner walls are broken where it leans out over them).
function wreck_spawn()
{
	org = tod_spire_data::rocket_wreck_org();
	w = Spawn( "script_model", org );
	if ( !isdefined( w ) )
	{
		rk_log( "ABORT wreck why=spawn_failed" );
		return;
	}
	w SetModel( TOD_RK_MODEL_WRECK );
	w.angles = tod_spire_data::rocket_wreck_angles();
	level.tod_rk_wreck = w;
	tip = tod_spire_data::rocket_crash_tip();
	// fire off the hull's middle, fire at the nose, and the black column over the base
	fwd = AnglesToForward( w.angles );
	hull = wreck_host( org + fwd * ( level.tod_rk_len * 0.55 ), ( -90, 0, 0 ) );
	nose = wreck_host( tip - fwd * 34, ( 0, 0, 0 ) );        // where the nose went into the floor (the fire is Z-up)
	col = wreck_host( org + fwd * ( level.tod_rk_len * 0.2 ), ( -90, 0, 0 ) );
	level thread fx_play_on_new_host( hull, "tod_rk_wreckfire" );
	level thread fx_play_on_new_host( nose, "tod_rk_nosefire" );
	level thread fx_play_on_new_host( col, "tod_rk_column" );
	if ( isdefined( hull ) )
		hull PlayLoopSound( TOD_RK_SND_FIRE, 1 );
	rk_log( "WRECK at=" + org + " angles=" + w.angles + " hosts=" + isdefined( hull ) + "," + isdefined( nose ) + "," + isdefined( col ) );
	// the fire burns down once the party is well up the climb (the smoke column keeps marking the crash)
	level thread wreck_burn_down( hull, nose );
}

// an effect host on the wreck (undefined when the entity pool refuses one: the wreck still stands)
function wreck_host( org, ang )
{
	h = Spawn( "script_model", org );
	if ( !isdefined( h ) )
		return undefined;
	h SetModel( "tag_origin" );
	h.angles = ang;
	return h;
}

function wreck_burn_down( hull, nose )
{
	level endon( "end_game" );
	wait 150;
	if ( isdefined( hull ) )
	{
		hull StopLoopSound( 3 );
		hull Delete();
	}
	if ( isdefined( nose ) )
		nose Delete();
	rk_log( "WRECK_BURNDOWN" );
}

// --- the shared beats -------------------------------------------------------
function ignite( ship )
{
	h = engine_host( ship, "tod_rk_ignite" );
	level.tod_rk_ride.ignite = h;
	tod_perk_scatter::play_sound_at_origin( ship.origin, TOD_RK_SND_IGNITE, 4 );
	foreach ( p in level.tod_rk_ride.riders )
	{
		if ( isdefined( p ) )
			p PlayRumbleOnEntity( "damage_light" );
	}
	rk_beat( "IGNITE", ship );
}

function liftoff( ship, kind )
{
	ride = level.tod_rk_ride;
	if ( isdefined( ride.ignite ) )
		ride.ignite Delete();
	pad = tod_crown_data::rocket_org( kind );
	level thread fx_burst( "tod_rk_ring", pad + ( 0, 0, 6 ), ( -90, 0, 0 ), 6 );
	level thread engine_burst( ship, "tod_rk_torch", TOD_RK_TORCH_SECS );
	tod_perk_scatter::play_sound_at_origin( pad, TOD_RK_SND_LIFTOFF, 6 );
	Earthquake( 0.42, 1.6, pad, 2200 );
	foreach ( p in GetPlayers() )
	{
		p PlayLocalSound( TOD_RK_SND_RUMBLE );
		p PlayRumbleOnEntity( "damage_heavy" );
	}
	rk_beat( "LIFTOFF", ship );
}

function pad_smoke( pad )
{
	level thread fx_burst( "tod_rk_padsmoke", pad + ( 0, 0, 8 ), ( -90, 0, 0 ), 8 );
}

// a shake that follows a moving ship (Earthquake measures from where it was called: re-issue it along the way)
function quake_follow( ship, scale, secs )
{
	n = int( secs / 0.5 );
	for ( i = 0; i < n; i++ )
	{
		if ( !isdefined( ship ) || IS_TRUE( level.tod_rk_ride.cut ) )
			return;
		Earthquake( scale, 0.7, ship.origin, 2400 );
		wait 0.5;
	}
}

function quake_on( ship, scale, secs, r )
{
	if ( isdefined( ship ) )
		Earthquake( scale, secs, ship.origin, r );
}

// A host on the ship's engine bell, its +X pointing OUT of the nozzle (the ship's -X): every engine effect plays
// along its host's forward. Linked, so it rides the ship; deleting it is how an effect stops.
function engine_host( ship, key )
{
	h = Spawn( "script_model", ship.origin );
	if ( !isdefined( h ) )
		return undefined;
	h SetModel( "tag_origin" );
	h LinkTo( ship, "tag_origin", ( tod_crown_data::rocket_bell_x(), 0, 0 ), ( 0, 180, 0 ) );
	level thread fx_play_on_new_host( h, key );
	return h;
}

// an engine effect for `secs` (the launch torch): its own host on the bell, deleted after
function engine_burst( ship, key, secs )
{
	h = engine_host( ship, key );
	if ( !isdefined( h ) )
		return;
	wait secs;
	if ( isdefined( h ) )
		h Delete();
}

// a host on the hull's skin (frac = how far up the hull), facing out of the hull's back
function hull_host( ship, frac )
{
	h = Spawn( "script_model", ship.origin );
	if ( !isdefined( h ) )
		return undefined;
	h SetModel( "tag_origin" );
	x = level.tod_rk_len * frac;
	h LinkTo( ship, "tag_origin", ( x, 0, rk_body_r( level.tod_rk_body, level.tod_rk_len, x ) ), ( -90, 0, 0 ) );
	return h;
}

// THE RULE (this map, 2026-10-01): an effect played on a host made in the same server frame reaches the client
// before the host and is dropped - two frames, then play.
function fx_play_on_new_host( host, key, key2 )
{
	WAIT_SERVER_FRAME;
	WAIT_SERVER_FRAME;
	if ( !isdefined( host ) )
		return;
	PlayFXOnTag( level._effect[ key ], host, "tag_origin" );
	if ( isdefined( key2 ) )
		PlayFXOnTag( level._effect[ key2 ], host, "tag_origin" );
	rk_log( "FX " + key + ( ( isdefined( key2 ) ) ? ( " + " + key2 ) : "" ) + " at=" + host.origin );
}

// a one-shot at a point: a host for `secs` (a bare server PlayFX one-shot does not draw)
function fx_burst( key, org, ang, secs )
{
	h = Spawn( "script_model", org );
	if ( !isdefined( h ) )
	{
		rk_log( "FX_FAIL " + key + " host" );
		return;
	}
	h SetModel( "tag_origin" );
	h.angles = ang;
	WAIT_SERVER_FRAME;
	WAIT_SERVER_FRAME;
	if ( !isdefined( h ) )
		return;
	PlayFXOnTag( level._effect[ key ], h, "tag_origin" );
	rk_log( "FX " + key + " at=" + org );
	wait secs;
	if ( isdefined( h ) )
		h Delete();
}

// the same, `delay` seconds later (the crash's second blast down the hull)
function fx_burst_after( delay, key, org, ang, secs )
{
	wait delay;
	fx_burst( key, org, ang, secs );
}

// wait `secs` of the ride (server frames); the ride never pauses (the world is already paused for the choice)
function ride_wait( secs )
{
	if ( secs > 0 )
		wait secs;
}

// --- the screen (TodRocketCine.lua) -----------------------------------------
// state: 0 off / 1 on (bars, HUD hidden) / 3 black in / 4 black out / 5 white in + hold / 6 white out
function cine_all( state, ms )
{
	foreach ( p in GetPlayers() )
	{
		if ( isdefined( p ) && isplayer( p ) )
			p LuiNotifyEvent( &"tod_rocket_cine", 2, state, ms );
	}
}

// --- the clips (generated script_brushmodels, docs/170) -----------------------
function clip_set( target, solid )
{
	if ( !isdefined( target ) || target == "" )
		return;
	e = GetEnt( target, "targetname" );
	if ( !isdefined( e ) )
	{
		rk_log( "CLIP_MISSING " + target );
		return;
	}
	if ( solid )
	{
		e Solid();
		e DisconnectPaths();
	}
	else
	{
		e NotSolid();
		e ConnectPaths();
	}
	rk_log( "CLIP " + target + " solid=" + solid );
}

// =============================================================================
// THE HOOKS
// =============================================================================

// stock's out-of-playable-area callback: TRUE = punish, FALSE = spare. self = player.
function playable_area_cb()
{
	if ( IS_TRUE( self.tod_rocket_riding ) )
		return false;
	if ( isdefined( level.tod_rk_prev_oopa_cb ) )
		return self [[ level.tod_rk_prev_oopa_cb ]]();
	return true;
}

// FIRST in stock's player damage chain: 0 for a rider, -1 (untouched) for everyone else.
function ride_damage_guard( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
	if ( IS_TRUE( self.tod_rocket_riding ) )
		return 0;
	return -1;
}

// =============================================================================
// LOGS - assembled outside the developer block, printed inside it (the proven pattern)
// =============================================================================
function rk_beat( tag, ship )
{
	where = "";
	if ( isdefined( ship ) )
		where = " ship=" + ship.origin + " ang=" + ship.angles;
	t = 0;
	if ( isdefined( level.tod_rk_ride ) && isdefined( level.tod_rk_ride.t ) )
		t = level.tod_rk_ride.t;
	rk_log( "BEAT " + tag + " t=" + t + where );
}

function rk_log( msg )
{
	if ( !TOD_RK_LOG && !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_ROCKET] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
