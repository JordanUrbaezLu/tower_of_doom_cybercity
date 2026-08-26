// =============================================================================
// _tod_perk_scatter.gsc — RANDOM PERK PLACEMENT + POST-BOSS RESHUFFLE
// (user 2026-08-20: perks "randomly placed at start of each map so each game
// is different... the round after each boss fight, 6,11,16,etc they will
// randomly shuffle... every perk will move from its spot into a new spot").
//
// PORTED from map 1's _acc_perk_scatter (the proven system, incl. its
// drop-in animation). Mechanically it RELOCATES the stock-spawned machine
// assemblies — stock perk_machine_spawn_init builds each machine out of 4
// script entities (t_use "zombie_vending" trigger, t_use.machine model,
// t_use.bump, t_use.clip) and everything downstream resolves BY NAME, so
// rewriting origins is safe (shipped precedent: zm_nuked, ohm-nabar).
//
// MAP 1 CORRECTNESS RULES PRESERVED (do not "simplify"):
//  - TWO-PHASE nav cut: ALL clips ConnectPaths at their old pads BEFORE any
//    move+DisconnectPaths — the calls are not refcounted; serializing
//    per-machine leaves a pad's navmesh open under a solid clip in any
//    permutation cycle (map 1 adversarial review, 3x confirmed).
//  - t.machine.b_keep_when_turned_off = true on every captured machine
//    EXCEPT Quick Revive (the stock solo 3-buy epilogue is the one live
//    turn_perk_off path; QR is FIXED to its base pad and keeps pure-stock
//    solo behavior).
//  - Only the visible MODEL glides in (MoveTo 0.8s from 60u up) — trigger/
//    bump/clip snap instantly, so the glide can never trap anyone.
//  - Host-based FX/SFX only (bare server PlayFX does not render — map 1's
//    five-module warning): burst rides a tag_origin host, sounds ride a
//    temp script_origin emitter.
//  - Anyone standing on an arrival pad is placed out the machine face.
//
// TOWER DELTAS vs map 1: pads > perks, so OPEN PADS ARE SHUFFLED TOO (map 1
// had equal counts; unshuffled pads would always fill lowest-index first);
// MULE KICK is excluded from capture (fixed roof machine); shuffle rounds =
// the round AFTER each Panzer round (tod_bosses::panzer_due( r - 1 )); the
// pin/mega/glow/facing integrations are map-1 systems and are stripped.
//
// The 6 machines PARK along the base-arena N wall in the .map (generator) —
// if capture ever fails, they remain buyable there (graceful degradation).
// =============================================================================

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_tower_of_doom\_tod_bosses;       // panzer_due (shuffle = round after a Panzer round)
#using scripts\zm\zm_tower_of_doom\_tod_perk_lights;  // glow re-pulse after a move (the latch rule)

#precache( "fx", "_custom/acc/fx_acc_derez_blink" );
#precache( "fx", "dlc0/factory/fx_teleporter_elec_strike_os" );

#define TOD_SCATTER_TRIG_Z        60    // stock: t_use sits at pad origin +z60
#define TOD_SCATTER_BUMP_Z        20
#define TOD_SCATTER_UNSTICK_R     55
#define TOD_SCATTER_UNSTICK_ZBAND 110
#define TOD_SCATTER_UNSTICK_PUSH  85
#define TOD_SCATTER_DROP_Z        60    // model materializes this far up...
#define TOD_SCATTER_GLIDE_SEC     0.8   // ...and glides down over this (0.4 read as "nothing" on map 1)
#define TOD_SCATTER_FX_Z          40    // de-rez burst height at the vacated pad
#define TOD_SCATTER_ARRIVE_FX_Z   90    // arrival burst ABOVE the descending model
#define TOD_SCATTER_MIN_MACHINES  8   // v6: + DoubleTap + Deadshot (user "perk at each level")
// COHERENCE WATCH (user 2026-08-24: "electric cherry machine has no trigger to
// buy it"). Tolerance = the stock use-trigger's 40u radius plus slack; past this
// the model and its prompt are in different places. Checked on a slow cadence —
// this is a safety net, not a driver.
#define TOD_SCATTER_COHERE_SEC    5    // first check, after the opening glide has landed
#define TOD_SCATTER_COHERE_TOL    96

#namespace tod_perk_scatter;

// ---------------------------------------------------------------------------
// Pads. Origins at floor z, 33u standoff off the backing wall face (map 1's
// live-verified convention — flush mounts sink the model into the wall).
// yaw: back-to-NORTH-wall = 359.999 (the p7_zm_vending_* models' visual
// front is model-local -Y); S wall = 180, W wall = 90, E wall = 270.
// front = unit vector out of the machine face (drives the unstick push).
// Lap math (generator): NW landing top = (lap-1)*768 + 384, spans
// x[-416,-256] y[256,416]; breather balcony top = (lap-1)*768 + 192, spans
// x[256,544] y[416,688]; roof = 19200.
// ---------------------------------------------------------------------------

function build_pads()
{
	// BREATHERS ONLY (user 2026-08-20: "perks are in random spots... only be
	// in the breather areas and that's it"): 2 pads per balcony x 4 breathers.
	// Odd floors (5/15) NE balcony — machines back the far N rail, face south;
	// even floors (10/20) SW, mirrored. Floor mid z = (floor-1)*384 + 192.
	//
	// QUICK REVIVE IS THE ONE CARVE-OUT (user 2026-08-20, the solo-safety
	// review): it is PINNED to the base arena, not a breather. Reaching the
	// floor-5 breather costs 9,375 points of doors, so pinning QR there left a
	// solo player with NO self-revive for ~10k points — one down ended the run.
	// The pad sits on the revive machine's own N-wall parking spot, so the
	// machine simply never moves. Every OTHER machine still scatters across
	// breathers only. (Granting the perk early is NOT an alternative: the stock
	// vending trigger refuses any buy while the player already holds the perk,
	// _zm_perks.gsc:545 — that would lock the player out of buying lives.)
	//
	// 9 pads / 9 MACHINES since 2026-08-25 — every pad is filled and each breather
	// carries TWO (user: "2 on each breather"). PhD Flopper was the ninth: it came
	// off the crown and into the scatter pool ("I dont want a perk on the crown"),
	// which is what closed the gap. Before that it was 8 machines, QR locked the
	// base and the other 7 shuffled into 8 breather pads, so ONE breather pad sat
	// empty every run and that breather had only one machine.
	//
	// KEEP THE COUNTS EQUAL. Adding a pad without a machine reopens the empty-pad
	// case; adding a machine without a pad leaves it parked at the base N wall,
	// which is the fallback row, not a bug — but it will not scatter.
	// v8 (user 2026-08-21): the tower doubled to 50 floors, so the breathers
	// respaced to laps 10/20/30/40 (gen_tower_map.js BREATHER_LAPS). All four
	// are EVEN laps now, so every balcony sits on the MIRRORED (SW) side —
	// machines back the far S rail facing north, yaw 180 / front (0,1,0).
	// Breather mid z = (lap-1)*384 + 192.
	pads = [];
	pads[ pads.size ] = make_pad( "base arena (N wall)",       (  -75,  500,     0 ), 359.999, ( 0, -1, 0 ), "specialty_quickrevive", false );
	// v9.37: the breathers grew (gen_tower_map.js BR_DEPTH 576 / BR_EAST 384 —
	// floor x[-800,-256] y[-992,-416]); the pads keep backing the far S rail
	// (y = -(PX+BR_DEPTH) + 33 = -959, was -783). x unchanged.
	pads[ pads.size ] = make_pad( "floor 10 breather (east)",  ( -360, -959,  3648 ), 180,     ( 0,  1, 0 ), undefined, false );
	pads[ pads.size ] = make_pad( "floor 10 breather (west)",  ( -536, -959,  3648 ), 180,     ( 0,  1, 0 ), undefined, false );
	pads[ pads.size ] = make_pad( "floor 20 breather (east)",  ( -360, -959,  7488 ), 180,     ( 0,  1, 0 ), undefined, false );
	pads[ pads.size ] = make_pad( "floor 20 breather (west)",  ( -536, -959,  7488 ), 180,     ( 0,  1, 0 ), undefined, false );
	pads[ pads.size ] = make_pad( "floor 30 breather (east)",  ( -360, -959, 11328 ), 180,     ( 0,  1, 0 ), undefined, false );
	pads[ pads.size ] = make_pad( "floor 30 breather (west)",  ( -536, -959, 11328 ), 180,     ( 0,  1, 0 ), undefined, false );
	pads[ pads.size ] = make_pad( "floor 40 breather (east)",  ( -360, -959, 15168 ), 180,     ( 0,  1, 0 ), undefined, false );
	pads[ pads.size ] = make_pad( "floor 40 breather (west)",  ( -536, -959, 15168 ), 180,     ( 0,  1, 0 ), undefined, false );
	return pads;
}

function make_pad( disp, origin, yaw, front, fixed_spec, priority )
{
	pad = SpawnStruct();
	pad.disp = disp;
	pad.origin = origin;
	pad.yaw = yaw;
	pad.front = front;
	pad.push = TOD_SCATTER_UNSTICK_PUSH;
	pad.fixed_spec = fixed_spec;
	pad.locked_spec = undefined;
	pad.priority = priority;     // filled FIRST by apply_scatter (breathers)
	// v10.3: the pad's FLOOR, for the no-same-floor shuffle rule. Lap floors
	// start at z0 in 384 steps; the base arena is floor 0.
	pad.floor = ( ( origin[ 2 ] < 1 ) ? 0 : ( 1 + int( origin[ 2 ] / 384 ) ) );
	return pad;
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
	level.tod_scatter_pads = build_pads();
	level.tod_scatter_where = [];      // spec -> pad index
	level.tod_scatter_machines = [];   // spec -> the "zombie_vending" trigger

	if ( !isdefined( level._effect ) )
		level._effect = [];
	level._effect[ "tod_derez" ]     = "_custom/acc/fx_acc_derez_blink";
	level._effect[ "tod_derez_zap" ] = "dlc0/factory/fx_teleporter_elec_strike_os";

	level thread round_watcher();
	level thread capture_and_open();
	level thread qr_clip_watch();
	level thread coherence_watch();
}

// QUICK REVIVE'S SOLO EPILOGUE LEAVES AN INVISIBLE WALL (v9.31, user
// 2026-08-23: "on the first floor there is some invisible wall at the corner
// near quick revive"). Stock _zm_perk_quick_revive::revive_solo_fx: after the
// third solo use the machine flies up and away, then `machine_clip Hide()` +
// ConnectPaths() — but Hide() only stops RENDERING; the zm_collision_perks1
// model stock spawned as the machine's collision stays SOLID, so the spot
// where QR stood is an invisible block for the rest of the run. On stock maps
// QR sits in an alcove and nobody notices; ours stands free on the base N
// wall. Stock never NotSolid()s that clip anywhere (unhide_quickrevive only
// Show()s it again), so the clip's solidity is mirrored onto the machine's
// own hidden state here: gone (model deleted by turn_perk_off, or its
// replacement flagged ishidden) -> NotSolid; visible again (hot-join
// unhide) -> Solid, exactly when stock Show()s it. Handles come from stock's
// level.quick_revive_machine(_clip) first, the scatter's captured trigger as
// the fallback. Idempotent: only acts on the edge.
function qr_clip_watch()
{
	level endon( "end_game" );

	was_gone = false;
	for ( ;; )
	{
		wait 0.5;
		if ( !isdefined( level.tod_scatter_machines ) )
			continue;
		t = level.tod_scatter_machines[ "specialty_quickrevive" ];

		clip = undefined;
		if ( isdefined( level.quick_revive_machine_clip ) )
			clip = level.quick_revive_machine_clip;
		else if ( isdefined( t ) && isdefined( t.clip ) )
			clip = t.clip;
		if ( !isdefined( clip ) )
			continue;

		m = level.quick_revive_machine;
		if ( !isdefined( m ) && isdefined( t ) )
			m = t.machine;
		gone = ( !isdefined( m ) || IS_TRUE( m.ishidden ) );

		if ( gone && !was_gone )
			clip NotSolid();
		else if ( !gone && was_gone )
			clip Solid();
		was_gone = gone;
	}
}

// Shuffle on the round AFTER each Panzer round (ship: 6, 11, 16...; dev:
// panzer 3/3 -> 4, 7, 10...). Polls round_number — the tod round-hook
// pattern (endless rounds have no reliable between-round notify).
function round_watcher()
{
	level endon( "end_game" );

	last = ( isdefined( level.round_number ) ? level.round_number : 1 );
	for ( ;; )
	{
		wait 1;
		r = level.round_number;
		if ( !isdefined( r ) || r == last )
			continue;
		last = r;
		// v10.3 (playtest 2026-08-23: "Perks need to move around more often...
		// whatever that number is subtract by 1"): the old trigger was the
		// round AFTER each Panzer = every 5 rounds (6, 11, 16...). Minus one =
		// EVERY 4 (5, 9, 13, ...), decoupled from the Panzer entirely — the
		// tie to his round was flavour, not load-bearing, and it is exactly
		// what made the cadence drift from what the user believed it was.
		if ( r > 4 && ( ( r - 1 ) % 4 ) == 0 )
		{
			// Never shuffle INTO the upgrade-choice freeze (round starts
			// trigger both; unstick_players would SetOrigin frozen pickers —
			// verify pass 2026-08-20).
			while ( IS_TRUE( level.tod_upgrade_pause ) )
				wait 0.25;
			level thread apply_scatter( false );
		}
	}
}

// ---------------------------------------------------------------------------
// MACHINE / TRIGGER COHERENCE (user 2026-08-24: "electric cherry machine has no
// trigger to buy it").
//
// READ THIS BEFORE "FIXING" IT PROPERLY: this is a SELF-HEAL, not a diagnosis.
// Cherry's whole paper trail was walked and every link checks out —
//   * the .map struct is a script_struct / targetname zm_perk_machine carrying
//     model + script_noteworthy + the script_string that matches
//     "zclassic_perks_start_room", so perk_machine_spawn_init accepts it;
//   * that function builds the "zombie_vending" trigger UNCONDITIONALLY for any
//     accepted struct (_zm_perks.gsc:1511) — there is no perk-registration gate
//     on the trigger at all;
//   * register_perk_machine really does install ec_machine_setup as
//     .perk_machine_set_kvps, so the machine gets its unique radiant name and
//     the trigger gets .target pointing at it (stock leaves BOTH as
//     "vending_sleight" until that callback runs — that WOULD produce exactly
//     this symptom, and it is wired correctly);
//   * standard_powered_items registers every zombie_vending trigger it can see
//     at "start_zombie_round_logic", cherry included;
//   * and the turn_perk_off Delete-respawn trap — which strands our cached
//     t.machine — is already defused by b_keep_when_turned_off in
//     capture_and_open below.
//
// What the SYMPTOM proves regardless of cause: a machine MODEL and its USE
// TRIGGER ended up in different places. That is the only way to see a machine
// and have nothing to press. So rather than guess, enforce the invariant the
// scatter is supposed to maintain — trigger sits TOD_SCATTER_TRIG_Z above its
// machine — and re-align when it drifts.
//
// THE TRIGGER MOVES TO THE MACHINE, never the reverse: the model is what the
// player can see, so it is the source of truth for where the perk "is".
//
// QUICK REVIVE IS EXCLUDED and that exclusion is load-bearing: its solo
// epilogue (stock revive_solo_fx) deliberately FLIES THE MACHINE AWAY, so a
// drift check would chase the trigger into the sky.
//
// Under dev it prints what it found, which is the real point — one dev run now
// answers whether cherry drifts, never gets a machine, or was never captured.
// ---------------------------------------------------------------------------

// The machine entity for a captured trigger, re-resolved if the cached pointer
// died. t.target is the machine's radiant targetname for EVERY perk (stock sets
// both, the per-perk kvps callback overrides both), so this works for the whole
// roster and not just cherry. Last match wins — a turn_perk_off replacement is
// spawned after the original.
function machine_for( t )
{
	if ( isdefined( t.machine ) )
		return t.machine;
	if ( !isdefined( t.target ) )
		return undefined;
	ents = GetEntArray( t.target, "targetname" );
	for ( i = ents.size - 1; i >= 0; i-- )
	{
		if ( isdefined( ents[ i ] ) )
			return ents[ i ];
	}
	return undefined;
}

function coherence_watch()
{
	level endon( "end_game" );

	wait TOD_SCATTER_COHERE_SEC;
	for ( ;; )
	{
		if ( isdefined( level.tod_scatter_machines ) )
		{
			keys = GetArrayKeys( level.tod_scatter_machines );
			for ( i = 0; i < keys.size; i++ )
			{
				if ( keys[ i ] == "specialty_quickrevive" )
					continue;   // its epilogue flies the machine off on purpose
				t = level.tod_scatter_machines[ keys[ i ] ];
				if ( !isdefined( t ) )
					continue;
				m = machine_for( t );
				if ( !isdefined( m ) )
				{
					dev_print( "perk_scatter: " + keys[ i ] + " has NO machine entity" );
					continue;
				}
				t.machine = m;   // re-link, in case the cached pointer had died
				want = t.origin - ( 0, 0, TOD_SCATTER_TRIG_Z );
				d = Distance( m.origin, want );
				if ( d <= TOD_SCATTER_COHERE_TOL )
					continue;
				dev_print( "perk_scatter: " + keys[ i ] + " trigger drifted " + int( d ) + "u — re-aligning to the machine" );
				t.origin = m.origin + ( 0, 0, TOD_SCATTER_TRIG_Z );
				if ( isdefined( t.bump ) )
					t.bump.origin = m.origin + ( 0, 0, TOD_SCATTER_BUMP_Z );
				if ( isdefined( t.clip ) )
				{
					t.clip.origin = m.origin;
					t.clip.angles = m.angles;
					t.clip DisconnectPaths();
				}
			}
		}
		wait 5;
	}
}

function capture_and_open()
{
	level endon( "end_game" );

	// Vending triggers spawn async during stock perk init — poll (map 1's
	// capture idiom). Accept a late partial capture over never scattering.
	machines = [];
	for ( tries = 0; tries < 120; tries++ )
	{
		machines = scatter_vending_triggers();
		if ( machines.size >= TOD_SCATTER_MIN_MACHINES )
			break;
		wait 0.5;
	}

	if ( machines.size == 0 )
	{
		dev_print( "perk_scatter: NO vending triggers captured — scatter disabled" );
		return;
	}
	if ( machines.size < TOD_SCATTER_MIN_MACHINES )
		dev_print( "perk_scatter: only " + machines.size + "/" + TOD_SCATTER_MIN_MACHINES + " machines captured — scattering those" );

	level.tod_scatter_machines = machines;

	// WAIT FOR THE CLIPS BEFORE MOVING ANYTHING — the fix for the base-N-wall
	// invisible wall (user 2026-08-23, reported twice).
	// The poll above waits for the VENDING TRIGGERS, which are .map entities
	// present from the first frame, so it can succeed before stock perk init
	// has spawned a single collision. Stock (_zm_perks.gsc:1551-1559) spawns
	// each clip at `s_spawn_pos.origin` — the .map PARK position — and only
	// THEN sets `t_use.clip`. Move the machines in that window and
	// move_machine's `if ( isdefined( t.clip ) )` is simply skipped: the clip
	// is born afterwards at the park spot and nothing ever moves it. All 8
	// machines park along the base N wall (PERK_PARK_Y 500) where QUICK REVIVE
	// is pinned, so the orphans stack up in the one corner every player walks
	// through on round 1.
	// Waiting for the precondition is not "winning a race" — it is refusing to
	// start until the thing we are about to move actually exists.
	// BOUNDED (10s): a machine can legitimately have no clip
	// (level._no_vending_machine_auto_collision), so this must never hang the
	// opening layout; a partial wait still beats scattering blind.
	for ( tries = 0; tries < 100; tries++ )
	{
		missing = 0;
		k = GetArrayKeys( machines );
		for ( i = 0; i < k.size; i++ )
		{
			t = machines[ k[ i ] ];
			if ( isdefined( t ) && !isdefined( t.clip ) )
				missing++;
		}
		if ( missing == 0 )
			break;
		wait 0.1;
	}

	keys = GetArrayKeys( machines );
	for ( i = 0; i < keys.size; i++ )
	{
		// Stock turn_perk_off Delete-respawns the model unless this
		// stock-sanctioned field is set — which would strand every captured
		// handle. QR excluded (the one live off-path is its solo epilogue;
		// QR never moves after opening placement).
		if ( keys[ i ] != "specialty_quickrevive" )
			machines[ keys[ i ] ].machine.b_keep_when_turned_off = true;
	}

	// Opening layout: random per run, applied while the class-draft/
	// blackscreen still hides the map (silent — no FX).
	apply_scatter( true );
}

// Every zombie_vending trigger EXCEPT Mule Kick (fixed on the roof, never
// scattered — the tower's carve-out; PaP is not a zombie_vending).
function scatter_vending_triggers()
{
	out = [];
	triggers = GetEntArray( "zombie_vending", "targetname" );
	for ( i = 0; i < triggers.size; i++ )
	{
		t = triggers[ i ];
		if ( !isdefined( t ) || !isdefined( t.script_noteworthy ) )
			continue;
		if ( t.script_noteworthy == "specialty_additionalprimaryweapon" )
			continue;   // Mule Kick — roof fixture
		if ( !isdefined( t.machine ) )
			continue;   // assembly not finished spawning yet
		out[ t.script_noteworthy ] = t;
	}
	return out;
}

// ---------------------------------------------------------------------------
// The scatter (map 1's two-phase structure verbatim)
// ---------------------------------------------------------------------------

function apply_scatter( b_initial )
{
	level endon( "end_game" );

	pads = level.tod_scatter_pads;
	machines = level.tod_scatter_machines;
	if ( !isdefined( machines ) || machines.size == 0 )
		return;

	moves = [];

	// FIXED pads (QR -> base west): placed once at the opening layout only.
	if ( b_initial )
	{
		for ( i = 0; i < pads.size; i++ )
		{
			if ( !isdefined( pads[ i ].fixed_spec ) )
				continue;
			m = machines[ pads[ i ].fixed_spec ];
			if ( !isdefined( m ) )
				continue;
			moves[ moves.size ] = make_move( m, i, pads[ i ].fixed_spec );
			pads[ i ].locked_spec = pads[ i ].fixed_spec;
		}
	}

	// Rotating pool = every captured perk minus fixed; open pads = every pad
	// without a locked occupant. BOTH lists are shuffled — the tower has
	// more pads than perks, and unshuffled pads would always fill in index
	// order (map 1 had equal counts, so it never needed this).
	specs = [];
	keys = GetArrayKeys( machines );
	for ( i = 0; i < keys.size; i++ )
	{
		if ( spec_is_fixed( keys[ i ] ) )
			continue;
		specs[ specs.size ] = keys[ i ];
	}

	open_pads = [];
	for ( i = 0; i < pads.size; i++ )
	{
		if ( !isdefined( pads[ i ].locked_spec ) )
			open_pads[ open_pads.size ] = i;
	}

	specs = shuffle( specs );
	open_pads = shuffle( open_pads );

	// PRIORITY pads (the breather balconies) are filled FIRST — every
	// breather always holds a perk (user 2026-08-20); the rest of the
	// machines spread across the per-floor pads.
	pri = [];
	rest = [];
	for ( i = 0; i < open_pads.size; i++ )
	{
		if ( IS_TRUE( pads[ open_pads[ i ] ].priority ) )
			pri[ pri.size ] = open_pads[ i ];
		else
			rest[ rest.size ] = open_pads[ i ];
	}
	open_pads = [];
	for ( i = 0; i < pri.size; i++ )
		open_pads[ open_pads.size ] = pri[ i ];
	for ( i = 0; i < rest.size; i++ )
		open_pads[ open_pads.size ] = rest[ i ];

	n = specs.size;
	if ( open_pads.size < n )
		n = open_pads.size;

	// NO SAME-FLOOR MOVES (playtest 2026-08-23: "a perk cannot swap to the
	// same floor even if its in the other slot"): if a machine's newly drawn
	// pad is on the floor it already occupies (the breathers carry TWO pads
	// each, so the blind shuffle produced exactly that), swap its draw with a
	// later machine whose floors are compatible both ways. One repair pass —
	// if no legal swap exists (tiny pad pool late in a pathological draw) the
	// same-floor move stands rather than a machine going unplaced.
	for ( i = 0; i < n; i++ )
	{
		cur = machine_floor( specs[ i ] );
		if ( !isdefined( cur ) )
			continue;                                   // opening layout — no current pad
		if ( pads[ open_pads[ i ] ].floor != cur )
			continue;
		for ( j = i + 1; j < n; j++ )
		{
			cur_j = machine_floor( specs[ j ] );
			ok_i = ( pads[ open_pads[ j ] ].floor != cur );
			ok_j = ( !isdefined( cur_j ) || pads[ open_pads[ i ] ].floor != cur_j );
			if ( ok_i && ok_j )
			{
				tmp = open_pads[ i ];
				open_pads[ i ] = open_pads[ j ];
				open_pads[ j ] = tmp;
				break;
			}
		}
	}

	for ( i = 0; i < n; i++ )
		moves[ moves.size ] = make_move( machines[ specs[ i ] ], open_pads[ i ], specs[ i ] );

	// Phase 1: reopen EVERY mover's old footprint before anything is cut
	// (ConnectPaths/DisconnectPaths are not refcounted — map 1's rule).
	for ( i = 0; i < moves.size; i++ )
	{
		t = moves[ i ].t;
		if ( isdefined( t ) && isdefined( t.clip ) )
			t.clip ConnectPaths();
	}

	// Phase 2: relocate + cut each new footprint.
	for ( i = 0; i < moves.size; i++ )
	{
		mv = moves[ i ];
		move_machine( mv.t, pads[ mv.pad_idx ], mv.spec, b_initial );
		level.tod_scatter_where[ mv.spec ] = mv.pad_idx;
	}

	level notify( "tod_perk_scatter_applied" );

	if ( !b_initial )
		announce_scatter();
	debug_dump( b_initial );
}

// -> the floor of the pad this machine currently occupies, or undefined
// before the opening layout has placed it.
function machine_floor( spec )
{
	if ( !isdefined( level.tod_scatter_where ) || !isdefined( level.tod_scatter_where[ spec ] ) )
		return undefined;
	return level.tod_scatter_pads[ level.tod_scatter_where[ spec ] ].floor;
}

function spec_is_fixed( spec )
{
	pads = level.tod_scatter_pads;
	for ( i = 0; i < pads.size; i++ )
	{
		if ( isdefined( pads[ i ].fixed_spec ) && pads[ i ].fixed_spec == spec )
			return true;
	}
	return false;
}

// Fisher-Yates (works for value arrays — specs and pad-index lists alike).
function shuffle( arr )
{
	for ( i = arr.size - 1; i > 0; i-- )
	{
		j = RandomInt( i + 1 );
		tmp = arr[ i ];
		arr[ i ] = arr[ j ];
		arr[ j ] = tmp;
	}
	return arr;
}

function make_move( t, pad_idx, spec )
{
	mv = SpawnStruct();
	mv.t = t;
	mv.pad_idx = pad_idx;
	mv.spec = spec;
	return mv;
}

// The move recipe. The caller has ALREADY ConnectPaths'd this clip at the
// old pad (phase 1) — this only relocates and cuts the new pad.
function move_machine( t, pad, spec, b_silent )
{
	if ( !isdefined( t ) )
		return;
	// Re-resolve rather than bail: a dead cached pointer used to mean this
	// machine silently stopped moving forever, which leaves its trigger behind
	// at the last pad — one of the two shapes the "no trigger" report can take.
	t.machine = machine_for( t );
	if ( !isdefined( t.machine ) )
		return;

	old_org = t.machine.origin;
	yaw = pad.yaw;

	if ( IS_TRUE( b_silent ) )
	{
		t.machine.origin = pad.origin;
	}
	else
	{
		// The tuned presentation (map 1's second pass — the first read as
		// "nothing"): materialize 60u up, glide down 0.8s, de-rez + warp
		// boom at BOTH pads, arrival burst ABOVE the model, landing punch.
		t.machine.origin = pad.origin + ( 0, 0, TOD_SCATTER_DROP_Z );
		t.machine MoveTo( pad.origin, TOD_SCATTER_GLIDE_SEC );
		derez_burst( old_org + ( 0, 0, TOD_SCATTER_FX_Z ) );
		play_sound_at_origin( old_org, "tod_warp", 2 );
		derez_burst( pad.origin + ( 0, 0, TOD_SCATTER_ARRIVE_FX_Z ) );
		play_sound_at_origin( pad.origin, "tod_warp", 2 );
		level thread land_punch( t.machine, pad.origin );
	}
	t.machine.angles = ( 0, yaw, 0 );

	// The clip is guaranteed to exist here: capture_and_open waits for every
	// captured machine's t.clip before it ever calls this (the base-N-wall
	// invisible-wall fix, 2026-08-23). The isdefined guard stays as a cheap
	// belt-and-braces for the bounded-wait timeout case — a machine that
	// legitimately has no collision must still move.
	if ( isdefined( t.clip ) )
	{
		t.clip.origin = pad.origin;
		t.clip.angles = ( 0, yaw, 0 );
		t.clip DisconnectPaths();
	}

	t.origin = pad.origin + ( 0, 0, TOD_SCATTER_TRIG_Z );
	if ( isdefined( t.bump ) )
		t.bump.origin = pad.origin + ( 0, 0, TOD_SCATTER_BUMP_Z );

	// Stock perk_fx's b_keep branch parks an unlinked FX host — drag it
	// along so nothing orphans at an old pad.
	if ( isdefined( t.machine.s_fxloc ) )
		t.machine.s_fxloc.origin = pad.origin;

	// GLOW after the move (verify pass 2026-08-20): the tower's todPerkGlow
	// clientfield LATCHES and its approach-rekick is one-shot per machine —
	// clear the latch so the next approach re-pulses, and re-pulse now for
	// anyone already nearby (map 1's glow-rekick rule).
	t.machine.tod_glow_rekicked = false;
	if ( IS_TRUE( level.tod_perk_glow_done ) )
		level thread reglow_after_move( t.machine, spec );

	unstick_players( pad );
}

function reglow_after_move( machine, spec )
{
	level endon( "end_game" );
	tod_perk_lights::set_glow( machine, 0 );
	wait 0.25;   // > one snapshot so the 0 transmits before the re-set
	if ( isdefined( machine ) )
		tod_perk_lights::set_glow( machine, tod_perk_lights::perk_color_index( spec ) );
}

// Landing punch: the stock perk power-on ka-chunk + machine shake when the
// glide touches down — instantly reads as "a machine just came alive here".
function land_punch( machine, org )
{
	level endon( "end_game" );

	wait TOD_SCATTER_GLIDE_SEC;
	if ( !isdefined( machine ) )
		return;

	machine Vibrate( ( 0, -100, 0 ), 0.3, 0.4, 3 );
	play_sound_at_origin( org, "zmb_perks_power_on", 2 );
	derez_burst( org + ( 0, 0, TOD_SCATTER_FX_Z ) );
}

function unstick_players( pad )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isdefined( p.origin ) )
			continue;
		if ( Distance2D( p.origin, pad.origin ) > TOD_SCATTER_UNSTICK_R )
			continue;
		if ( abs( p.origin[ 2 ] - pad.origin[ 2 ] ) > TOD_SCATTER_UNSTICK_ZBAND )
			continue;
		p SetOrigin( pad.origin + pad.front * pad.push );
	}
}

function announce_scatter()
{
	// First scatter explains the mechanic; after that the moving machines
	// are the tell (map 1: the every-time banner got annoying).
	if ( IS_TRUE( level.tod_scatter_announced ) )
		return;
	level.tod_scatter_announced = true;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		// (scatter text removed 2026-08-20 — user: no floaty text)
	}
}

function debug_dump( b_initial )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	tag = ( ( IS_TRUE( b_initial ) ) ? "opening layout" : "scatter" );
	keys = GetArrayKeys( level.tod_scatter_where );
	for ( i = 0; i < keys.size; i++ )
	{
		pad = level.tod_scatter_pads[ level.tod_scatter_where[ keys[ i ] ] ];
		players = GetPlayers();
		for ( j = 0; j < players.size; j++ )
		{
			if ( isdefined( players[ j ] ) )
				players[ j ] IPrintLn( "[scatter] " + tag + " " + keys[ i ] + " -> " + pad.disp );
		}
	}
}

// RE-GATED 2026-08-24 for the PUBLISH build. It was briefly un-gated the same
// night (the map-wont-load hunt, when arming level.tod_dev was the suspect —
// resolved: the user's INSTALL was broken, a redownload fixed it; the dev-flag
// suspicion in tod_resolve_dev_flags was never confirmed and the cherry
// diagnostic never got a run). A published map must not print yellow debug text
// at spawn, so the gate is back. To hunt the cherry bug (docs/32): arm
// level.tod_dev + rebuild, and if THAT load fails the dev-flag suspicion gets
// its answer too.
function dev_print( msg )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	players = GetPlayers();
	if ( players.size > 0 && isdefined( players[ 0 ] ) )
		players[ 0 ] IPrintLn( "^3" + msg );
}

// ---------------------------------------------------------------------------
// Host-based FX/SFX primitives (map 1's rule: bare server PlayFX does not
// render, a 3D alias on a moving ent trails — both need throwaway hosts).
// ---------------------------------------------------------------------------

function derez_burst( origin )
{
	if ( !isdefined( origin ) )
		return;
	level thread derez_burst_run( origin );
}

function derez_burst_run( origin )
{
	// No endon(end_game) — the thread lives 0.5s and an endon mid-wait would
	// orphan the host with the LOOPING numbers FX playing (map 1 review).
	// The zap gets its OWN 1.0s host (map 1's play_fx_burst — killing it at
	// the numbers' 0.5s cut the strike short; verify pass 2026-08-20).
	level thread zap_burst_run( origin );
	h = Spawn( "script_model", origin );
	if ( !isdefined( h ) )
		return;
	h SetModel( "tag_origin" );
	PlayFxOnTag( level._effect[ "tod_derez" ], h, "tag_origin" );
	wait 0.5;
	if ( isdefined( h ) )
		h Delete();
}

function zap_burst_run( origin )
{
	h = Spawn( "script_model", origin );
	if ( !isdefined( h ) )
		return;
	h SetModel( "tag_origin" );
	PlayFxOnTag( level._effect[ "tod_derez_zap" ], h, "tag_origin" );
	wait 1.0;
	if ( isdefined( h ) )
		h Delete();
}

function play_sound_at_origin( origin, alias, life_sec )
{
	if ( !isdefined( origin ) || !isdefined( alias ) || alias == "" )
		return;
	e = Spawn( "script_origin", origin );
	if ( !isdefined( e ) )
		return;   // entity pool full — drop the sound, never throw
	e PlaySound( alias );
	e thread emitter_cleanup( life_sec );
}

function emitter_cleanup( life_sec )   // self = the temp emitter
{
	level endon( "end_game" );
	if ( !isdefined( life_sec ) )
		life_sec = 12;
	wait life_sec;
	if ( isdefined( self ) )
		self Delete();
}
