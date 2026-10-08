// =============================================================================
// _tod_rampage.gsc — THE RAMPAGE INDUCER (v14.20, user 2026-08-30)
//
// The map's own CYBER Rampage Inducer (2026-10-02; BO6's essence canister
// v18.99h-v19.68k, a ww2_circuit_breaker before that) on the arena floor
// against the BASE ARENA's south wall, across from Quick Revive (in the
// teleport bay until v18.99f), that the party can throw at any time (no seal
// since v19.0). While ON the tower runs HARD MODE, and the device turns
// rampage red (its _on twin), runs its fast loop, SPARKS and crackles as the
// tell. (This header said "rounds 1-8 ... SEALS at round 9" until 2026-10-02 -
// that rule was retired in v19.0; see THERE IS NO SEAL below.)
//
// WHAT IT ACTUALLY DOES — four levers, each owned by the module that owns that
// system. This file writes ONE field and nothing else:
//   1. SPEED   — the sprint ramp completes at round 10 instead of 18
//                (_tod_zombie_speed::full_round)
//   2. ELITES  — double the throughput of every elite type
//                (_tod_bosses::elite_mult)
//   3. PACING  — spawn delay x0.80, floor 0.25 -> 0.20
//                (_tod_endless_rounds::tod_spawn_delay)
//   4. THE HUD — the luck bar swaps to the red/purple art set
//                (todRampage clientfield -> tod_upgrade.lua)
// Added since: elites/bosses x1.25 HP (v14.25) -> x1.5 (v18.74), two Panzers
// on a boss round (v14.27), the old +0.28%/round speed tail (v18.11), and —
// v18.74, after "rampage feels easier" — +3 on the elite roof
// (_tod_bosses::elite_roof_all), +10 zombies at once
// (_tod_corpse_cleanup::ai_limit_for_party) and horde HP x1.2
// (_tod_zombie_speed::rampage_horde_mult). Every one reads the same field.
//
// STATE SURFACE: level.tod_rampage_on, a plain level boolean. THIS FILE IS ITS
// ONLY WRITER; every consumer above field-reads it with an IS_TRUE that treats
// the absent field as false, so the whole feature no-ops to byte-identical
// current behaviour in any build where it is not installed or not thrown. No
// consumer imports this module and this module imports no consumer — the
// no-cycle rule map 1's rampage was built on.
//
// NO DVAR TOGGLE EXISTS, DELIBERATELY. Map 1's original Inducer died in six
// iterations and the FIRST failure was a leftover dvar watcher that polled the
// dvar and switched the device back off a second later ("sprints a few seconds
// then stops"). The station is the only writer. This map's doctrine says the
// same thing from the other direction: one compile-time level.tod_dev flag, no
// console dvars, ever.
//
// THERE IS NO SEAL. RAMPAGE TOGGLES ALL MATCH (v19.0, user: "I want to remove
// the round 9 rampage lock. It will be toggleable throughout the game").
//
// It used to lock at round 9 — map 1's no-take-backs rule, moved late because
// the device then lived behind the enter_tpbay door and a round-5 seal was
// unreachable for trio and quad. BOTH HALVES OF THAT ARGUMENT ARE DEAD.
// v18.99f moved the inducer OUT of the bay onto the open arena floor at
// (-280, -516), so there is no door to earn and no earning window to protect;
// and the user has replaced the no-take-backs rule itself with a free switch.
// The whole seal went with it: the round constant, locked(), lock_watcher,
// seal_banner, the tod_rampage_sealed eventstring, the Lua banner widget and
// the baked plate are all RETIRED WHOLE (half a retirement is either dead
// weight or a white square — this map's standing rule).
//
// WHAT A FREE TOGGLE ACTUALLY MEANS, because the levers are not uniform:
//   * MOST revert live — the elite roof, the AI limit, the spawn floors and
//     the director's reads are all IS_TRUE( level.tod_rampage_on ) per use,
//     so OFF is felt within a couple of seconds or at the next rollover.
//   * SPAWN-TIME HP IS NOT RETROACTIVE, in either direction. An elite, a
//     sprinter or a horde zombie banks its multiplier when it spawns, so
//     flipping OFF does not soften what is already on the deck, and flipping
//     ON does not harden it. That is correct and is how it always behaved.
//   * THE WARDEN KING LATCHES AT king_setup. His HP, his sprint thread and the
//     per-zombie sprint stamp are taken once when he lands. Toggling during the
//     summit fight changes nothing about HIM; it still changes the adds.
// None of that is new — removing the seal only means the switch keeps working.
//
// THE FIVE OTHER MAP-1 FAILURE MODES, and why each is impossible here:
//   F2 one-way toggle ("if(active) continue") -> every use flips the state.
//   F3 raw ASMSetAnimationRate overshoot fighting another writer -> this module
//      writes NO rate. It moves the round at which the EXISTING curve tops out,
//      and the existing keep-alive is what applies it.
//   F4 a one-shot override decaying on stock locomotion re-evals ("stops after
//      a minute") -> the 1.5 s keep-alive sweep re-asserts every zombie, so a
//      toggle retro-applies to live AI within one sweep in BOTH directions,
//      with no apply pass of our own.
//   F5 the sweep freezing a boss by stomping its custom ASM -> the rampage read
//      sits INSIDE apply_speed_for_round, downstream of its is_boss early
//      return. Bosses are excluded by absence of a call, not by a flag.
//   F6 hint-string routing hijack -> RAMPAGE is the guard word; the hints below
//      carry no " for ", no "[cost:]", no door/pack/perk vocabulary.
// =============================================================================

#using scripts\shared\callbacks_shared;   // on_spawned — the per-life HUD re-push
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;   // set_rampage (the HUD swap; upgrade_ui imports only shared — no cycle)
#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // base_inducer_org/_trig/_yaw (GENERATED — pure data, imports nothing, no cycle)

#insert scripts\shared\shared.gsh;

#precache( "fx", "electric/fx_elec_spark_loop_sm" );
// THE GLOW (v18.99i). Two looping effects written by tools/gen_tod_inducer_fx.py
// from map 1's amber perk aura, each keeping that donor's real dynamic light.
// A precache makes them LOADABLE; the `fx,tod/fx_tod_inducer_*` lines in the
// .zone are what PACK them; level._effect below is what script can reach.
// Miss any one of the three and the device sits there dark with no error.
#precache( "fx", "tod/fx_tod_inducer_idle" );
#precache( "fx", "tod/fx_tod_inducer_on" );
// 2026-10-01: THE FLIP, SEEN (tools/gen_rampage_fx.py; switch_burst). ON = an
// orange shockwave across the arena floor + a spark fountain + a flash; OFF = a
// puff of smoke and falling sparks. The tower's strips are _tod_rampage.csc's.
#precache( "fx", "tod/rampage/fx_rampage_on" );
#precache( "fx", "tod/rampage/fx_rampage_on_light" );
#precache( "fx", "tod/rampage/fx_rampage_off" );
// 2026-10-02: THE CYBER INDUCER IS ANIMATED - two looping clips on its own bones
// (tools/inducer_cyber/anim_spec.py; LOCKSTEP with animtrees/tod_inducer.atr,
// the two `xanim,` zone lines and source_data/tod_inducer_cyber.gdt).
#precache( "xanim", "tod_inducer_cyber_loop_idle" );
#precache( "xanim", "tod_inducer_cyber_loop_on" );
#using_animtree( "tod_inducer" );

// THE MODEL (2026-10-02) - the CYBER Rampage Inducer, authored for this map in a
// live Blender MCP studio (tools/inducer_cyber/, master
// art/rampage_inducer_cyber/rampage_inducer_cyber.blend; user: "a redesign ...
// more cyber like that is nicer for our map"). An armoured plinth with a
// RAMPAGE display, a copper power coil, four bowed ribs caging a levitating
// Fury crystal cluster in a plasma column, a finned crown with four claws and a
// beacon. 44 x 44 x 67, front on local +X, ONE model with five animated bones.
// It replaces BO6's essence canister (tod_inducer, v18.99h-v19.68k), whose
// GDT and model files stay on disk unzoned as the rollback.
//
// THE LIT TWIN: the same mesh with both materials swapped for their `_on`
// variants through skinOverride. OFF wears cyan standby trims and a dim amber
// core (the user's v18.99i "dim orange lamp"); ON turns every trim rampage red
// and the core into a hot orange burn - baked OFF and ON glow maps, one atlas.
#define TOD_RAMPAGE_MODEL        "tod_inducer_cyber"
#define TOD_RAMPAGE_MODEL_ON     "tod_inducer_cyber_on"
// THE MOTION: idle = the crystal turns and bobs, the shards orbit, two segmented
// halos counter-spin, the beacon shutter sweeps (12 s loop); on = the same, four
// times faster, the crystal shivering, the beacon sweeping like an alarm (3 s).
// SetModel restarts a scripted anim, so anim_set() re-plays after every swap
// (the perk machines' rest_pose does the same on a model change).
#define TOD_RAMPAGE_ANIM_IDLE    "tod_inducer_cyber_loop_idle"
#define TOD_RAMPAGE_ANIM_ON      "tod_inducer_cyber_loop_on"
#define TOD_RAMPAGE_ANIM_NOTIFY  "tod_inducer_anim"
// PLACEMENT — THE GENERATOR OWNS IT (v18.99g). The pedestal brush and these
// three anchors are cut from the SAME constants in gen_tower_map.js (the
// TELEPORT BAY block, "base inducer plinth") and emitted into the GENERATED
// _tod_breather_data.gsc, so the brush and the device can never drift. This is
// the base ammo crate's own no-drift contract, and it is here because v18.99f
// hand-typed the coordinates and shipped a DEAD TRIGGER:
//
// ⚠️ THE TRIGGER ORIGIN MUST NOT BE INSIDE THE PEDESTAL. v18.99f put the
// trigger at the device's own x/y, which is inside the plinth brush, and a
// trigger_radius_use whose ORIGIN lies in any solid NEVER PROMPTS — the user
// read that as "way too high to even trigger". It is the map's fourth payment
// on the same trap (extraction obelisk, hall crate, crown altar; memory
// trigger-origin-under-decal). base_inducer_trig() is 56 units out in FRONT of
// the pedestal on open floor, the ammo crate / upgrade station grammar, and the
// generator THROWS if that point ever lands back inside the brush.
//
// HEIGHT: the cyber inducer stands on the floor, 67 tall, the crystal at eye
// level minus a head. Its BODY CLIP (generated, z 0..40) stops players walking
// through it, so the trigger now rides ABOVE the clip at
// base_inducer_trig_lift() (44) - generated beside the clip so the two heights
// cannot drift; a clip under the origin would block the use sight-trace.
#define TOD_RAMPAGE_TRIG_H       80
// The sparks fly off the two FRONT claw tips (art master, stage 05: local
// (9.0, +-9.0, 63.4)) - fwd 9 and the host spread 9 put one host on each.
#define TOD_RAMPAGE_FX_FWD       9
#define TOD_RAMPAGE_FX_Z         63.4
// trigger_radius_use refires EVERY FRAME while +activate is held. Map 1 found
// 500 ms let a held key flip-flop the state twice a second; 2 s is one toggle
// per deliberate press.
#define TOD_RAMPAGE_DEBOUNCE_MS  2000
// Spark cadence while ON. The FX is a LOOP so it needs placing once, but the
// SOUND is a 1.86 s one-shot fired on this timer — an intermittent crackle
// reads as a failing breaker, and a one-shot sidesteps the StopLoopSound
// handle-ownership trap entirely (memory loop-sound-stop-by-handle).
// v18.99k (user: "we need to spark probably two times as much"): cadence halved
// AND two spark hosts instead of one (TOD_RAMPAGE_SPARK_HOSTS).
#define TOD_RAMPAGE_SPARK_MIN    1.0
#define TOD_RAMPAGE_SPARK_MAX    2.25
#define TOD_RAMPAGE_SPARK_HOSTS  2
#define TOD_RAMPAGE_SPARK_SPREAD 9      // units each host sits off the axis: one per front claw tip

#namespace tod_rampage;

function init()
{
	level.tod_rampage_on = false;
	level.tod_rampage_debounce_until = 0;
	level.tod_rampage_fx = undefined;

	// The precache at the top of this file makes the asset LOADABLE; the
	// `fx,electric/fx_elec_spark_loop_sm` line in the .zone is what actually
	// PACKS it; and this handle is what script can reach. All three are
	// required — miss the zone line and the feature toggles, sounds and
	// silently never sparks, with no error anywhere.
	level._effect[ "tod_rampage_spark" ] = "electric/fx_elec_spark_loop_sm";
	level._effect[ "tod_inducer_idle" ] = "tod/fx_tod_inducer_idle";
	level._effect[ "tod_inducer_on" ]   = "tod/fx_tod_inducer_on";
	level._effect[ "tod_rampage_on" ] = "tod/rampage/fx_rampage_on";
	level._effect[ "tod_rampage_on_light" ] = "tod/rampage/fx_rampage_on_light";
	level._effect[ "tod_rampage_off" ] = "tod/rampage/fx_rampage_off";

	callback::on_spawned( &on_player_spawned );
	level thread station_setup();
}

// ---------------------------------------------------------------------------
// THE STATION
// ---------------------------------------------------------------------------

function station_setup()
{
	level endon( "end_game" );

	// v18.99f put the inducer on the OPEN ARENA FLOOR — it is not behind the
	// teleport-bay door any more, so it is reachable from spawn with no purchase.
	// (This comment used to argue the opposite and outlived the move by a day.)
	org = tod_breather_data::base_inducer_org();

	m = Spawn( "script_model", org );
	m.angles = ( 0, tod_breather_data::base_inducer_yaw(), 0 );
	m SetModel( TOD_RAMPAGE_MODEL );
	// NOT SOLID and NO DisconnectPaths — same as map 1's station and this map's
	// ammo crates. A script_model is non-solid by default; the cyber inducer's
	// COLLISION is a generated clip brush ("base rampage inducer body", z 0..40)
	// that the navmesh compiler and the geometry lint both see. Never add a
	// script clip here (the base crate's DisconnectPaths under a stair flight is
	// the cautionary tale; the geometry lint cannot see script collision).
	level.tod_rampage_model = m;
	dev_log( "MODEL revision=cyber_core_1 model=" + TOD_RAMPAGE_MODEL + " origin=" + org
	         + " anims=" + TOD_RAMPAGE_ANIM_IDLE + "/" + TOD_RAMPAGE_ANIM_ON
	         + " trig_lift=" + tod_breather_data::base_inducer_trig_lift() );

	// Lit from the moment it spawns, not from the first toggle: OFF is a dim
	// orange lamp, which is what tells a player this is a device at all.
	tell_apply();

	// FLOOR-relative and ALL AROUND the device (v18.99k, user: "it should be
	// kind of in a radius all around it"): the generated trig point IS the
	// device's own x/y, radius base_inducer_trig_r. The lift (2026-10-02) is the
	// GENERATED base_inducer_trig_lift() - above the body clip, so the origin is
	// in open air and the use sight-trace never hits the clip (dead-trigger trap).
	t = Spawn( "trigger_radius_use",
	           tod_breather_data::base_inducer_trig() + ( 0, 0, tod_breather_data::base_inducer_trig_lift() ),
	           0, tod_breather_data::base_inducer_trig_r(), TOD_RAMPAGE_TRIG_H );
	t TriggerIgnoreTeam();      // REQUIRED or a script-spawned use-trigger is never usable
	t SetCursorHint( "HINT_NOICON" );
	t SetHintString( hint_for_state() );
	level.tod_rampage_trig = t;

	level thread spark_think();
	level thread teardown_watcher();

	for ( ;; )
	{
		t waittill( "trigger", player );
		if ( !isdefined( player ) || !isplayer( player ) )
			continue;

		// Never accept a press through the upgrade-choice freeze — players are
		// frozen and every other use-loop in this map refuses here.
		if ( IS_TRUE( level.tod_upgrade_pause ) )
		{
			player PlaySound( "zmb_no_purchase" );
			dev_log( "REFUSED: upgrade/station pause holds the world (the only refusal left since v19.0)" );
			continue;
		}

		if ( GetTime() < level.tod_rampage_debounce_until )
			continue;
		level.tod_rampage_debounce_until = GetTime() + TOD_RAMPAGE_DEBOUNCE_MS;

		level.tod_rampage_on = !IS_TRUE( level.tod_rampage_on );
		dev_log( "toggle by " + player.playername + " -> " + ( ( IS_TRUE( level.tod_rampage_on ) ) ? "ON" : "OFF" )
		         + " round=" + ( ( isdefined( level.round_number ) ) ? level.round_number : -1 )
		         + " (v19.0: no seal — this can happen at any round, any number of times)" );
		// THE TELL FOLLOWS THE SWITCH IN THE SAME FRAME (v18.99k). It used to be
		// applied by spark_think's poll, which sleeps up to 4.5 s while ON, so a
		// press could sit unanswered for seconds - the user's "sometimes the
		// indication that it's on doesn't work".
		tell_apply();
		// 2026-10-01: the flip, seen - a shockwave on ON, a puff of smoke on OFF.
		// (The tower's strips follow on every client: _tod_rampage.csc reads the
		// todRampage HUD value push_hud_all sends below.)
		level thread switch_burst( IS_TRUE( level.tod_rampage_on ) );
		// 2026-10-02: THE FLIP, HEARD - the user's Rampage ON / OFF stings (downloaded,
		// reworked into the map's own cyber sound: tools/rampage_sfx/
		// build_rampage_sfx.py; sound/aliases/tod_ui.csv rows, 3D, full volume within
		// 1200 so the arena hears it). Played FROM THE DEVICE, like its crackle. The stock
		// purchase cha-ching is GONE from the flip (user: "Remove the cha ching").
		// A plain if/else, NOT a ternary call argument: the first cut passed an unwrapped
		// ternary straight to PlaySound and the linker refused the whole file ("No
		// generated data for _tod_rampage.gsc", 2026-10-02 16:51).
		sting_alias = "tod_rampage_off";
		if ( IS_TRUE( level.tod_rampage_on ) )
			sting_alias = "tod_rampage_on";
		if ( isdefined( level.tod_rampage_model ) )
			level.tod_rampage_model PlaySound( sting_alias );
		dev_log( "STING " + sting_alias + " from_device=" + isdefined( level.tod_rampage_model ) );
		t SetHintString( hint_for_state() );

		// NO ON-SCREEN TEXT ON TOGGLE (v14.49, user 2026-08-31: "I had asked to
		// remove all copy UI when Rampage is on ... i turned it on and saw some
		// text UI in center of screen I dont want any of that. All i want is
		// that when you turn it on and it gets to round 9 that the image
		// shows"). announce() is GONE, both the ON and the OFF lines.
		//
		// THE FEEDBACK IS NOT LOST, which is why this is safe to simply delete:
		// the ON / OFF sting above (the cha-ching until 2026-10-02) fires on every flip, the breaker's own hint
		// re-stamps to its ON/OFF form on the line above that, the breaker
		// SPARKS continuously while armed, and the luck bar swaps to the red
		// art set. Four channels, none of them text. The seal banner at round 9
		// is then the ONLY thing that ever prints to the middle of the screen.
		push_hud_all();
	}
}

// ---------------------------------------------------------------------------
// THE TELL — sparks and crackle for the rest of the match while ON
// ---------------------------------------------------------------------------

// The FX is a LOOP, so it is placed ONCE on the transition to ON and killed on
// the transition to OFF. Server-side PlayFX renders for LOOPING effects (map 1
// proved this both ways: its ambient fx_at loops render, its bare one-shots do
// not) — which is exactly why this uses a loop FX and not a repeated burst.
// THE ONE OWNER OF THE VISUAL STATE (v18.99k). Idempotent: it compares the
// flag to what is currently shown and does nothing if they agree, so it is
// safe to call from the use loop (the real driver), from station_setup, and
// from spark_think's poll as a backstop.
function tell_apply()
{
	on = IS_TRUE( level.tod_rampage_on );
	if ( isdefined( level.tod_rampage_tell_on ) && level.tod_rampage_tell_on == on )
		return;
	level.tod_rampage_tell_on = on;

	glow_set( on );
	if ( on )
		spark_fx_start();
	else
		spark_fx_stop();
}

function spark_think()
{
	level endon( "end_game" );

	for ( ;; )
	{
		tell_apply();
		on = IS_TRUE( level.tod_rampage_on );

		if ( on )
		{
			m = level.tod_rampage_model;
			if ( isdefined( m ) )
				m PlaySound( "tod_rampage_spark" );
			wait ( TOD_RAMPAGE_SPARK_MIN + RandomFloat( TOD_RAMPAGE_SPARK_MAX - TOD_RAMPAGE_SPARK_MIN ) );
		}
		else
		{
			wait 0.5;
		}
	}
}


// THE GLOW - the device's own state tell (v18.99i, user: "it needs to glow a
// dim orange of some sort. And then when it's on, it needs to pulse a deeper
// orange. And that's the indicator that it's on. But when it's off, it just
// has, like, a dim kinda lamp, orange light lamp").
//
// ONE HOST, RE-MADE ON EVERY CHANGE. There is no StopFX for a tag-played loop,
// so swapping effects means deleting the host and spawning a new one - the same
// contract spark_fx_stop() below uses, and the one the perk-glow and boss-FX
// systems use. The host sits at the device's own origin; each effect carries
// its own spawnOrgZ (35 since 2026-10-02: the cyber inducer's crystal), which
// puts the light at the heart of the device.
//
// Server-side PlayFXOnTag is valid because BOTH effects loop. A one-shot played
// this way renders nothing (memory ambient-fx-server-loop-lane), which is also
// why the pulse is baked into the effect's own light curve rather than driven
// by a script timer.
function glow_set( on )
{
	if ( isdefined( level.tod_rampage_glow ) )
	{
		level.tod_rampage_glow Delete();
		level.tod_rampage_glow = undefined;
	}

	m = level.tod_rampage_model;
	if ( !isdefined( m ) )
		return;

	// The model IS the glow: OFF wears the dim-lamp materials, ON the hot ones.
	if ( on )
		m SetModel( TOD_RAMPAGE_MODEL_ON );
	else
		m SetModel( TOD_RAMPAGE_MODEL );
	// ...and the swap restarts its motion, so the state's loop plays again.
	anim_set( on );

	e = Spawn( "script_model", m.origin );
	e SetModel( "tag_origin" );
	e.angles = m.angles;
	level.tod_rampage_glow = e;

	if ( on )
		PlayFXOnTag( level._effect[ "tod_inducer_on" ], e, "tag_origin" );
	else
		PlayFXOnTag( level._effect[ "tod_inducer_idle" ], e, "tag_origin" );
}

// THE MOTION (2026-10-02, user: "Make sure to add animations"). The inducer's
// five bones (crystal, shards, two halos, beacon shutter) run one looping clip
// per state: TOD_RAMPAGE_ANIM_IDLE (12 s, calm) or TOD_RAMPAGE_ANIM_ON (3 s,
// four times faster, the crystal shivering, the beacon sweeping like an alarm).
// The perk machines' proven lane: UseAnimTree + AnimScripted by name on a
// script_model, re-played after every SetModel (a swap restarts the anim, which
// the flip's own flash hides). glow_set is the one caller.
function anim_set( on )
{
	m = level.tod_rampage_model;
	if ( !isdefined( m ) )
		return;
	clip = TOD_RAMPAGE_ANIM_IDLE;
	if ( on )
		clip = TOD_RAMPAGE_ANIM_ON;
	m notify( "tod_inducer_anim_restart" );
	m thread anim_play( clip );
}

function anim_play( clip )   // self = the inducer model
{
	self endon( "tod_inducer_anim_restart" );
	self endon( "death" );
	level endon( "end_game" );
	// A model set THIS frame (the spawn, or the ON/OFF swap) gets two server
	// frames first - the same settle every new FX host in this map gets.
	WAIT_SERVER_FRAME;
	WAIT_SERVER_FRAME;
	if ( !isdefined( self ) )
		return;
	if ( IS_TRUE( self.tod_inducer_animating ) )
		self StopAnimScripted( 0, true );
	self UseAnimTree( #animtree );
	self AnimScripted( TOD_RAMPAGE_ANIM_NOTIFY, self.origin, self.angles, clip );
	self.tod_inducer_animating = true;
	dev_log( "ANIM clip=" + clip + " model=" + self.model + " rampage=" + IS_TRUE( level.tod_rampage_on ) );
}

function spark_fx_start()
{
	if ( isdefined( level.tod_rampage_fx ) )
		return;
	m = level.tod_rampage_model;
	if ( !isdefined( m ) )
		return;

	// The FX hosts are their own script_models rather than a tag on the
	// inducer: the sparks sit on the two FRONT CLAW TIPS (TOD_RAMPAGE_FX_*),
	// which the model's bones do not carry (tag_origin is at its base).
	// TOD_RAMPAGE_SPARK_HOSTS of them, fanned TOD_RAMPAGE_SPARK_SPREAD off the
	// axis - the stock loop's own cadence is fixed inside the .efx, so "twice
	// the sparks" is two loops, not one loop asked to hurry.
	fwd = AnglesToForward( m.angles );
	right = AnglesToRight( m.angles );
	org = m.origin + VectorScale( fwd, TOD_RAMPAGE_FX_FWD ) + ( 0, 0, TOD_RAMPAGE_FX_Z );

	level.tod_rampage_fx = [];
	for ( i = 0; i < TOD_RAMPAGE_SPARK_HOSTS; i++ )
	{
		side = 1;
		if ( ( i % 2 ) == 1 )
			side = -1;
		e = Spawn( "script_model", org + VectorScale( right, side * TOD_RAMPAGE_SPARK_SPREAD ) );
		e SetModel( "tag_origin" );
		e.angles = m.angles;
		PlayFXOnTag( level._effect[ "tod_rampage_spark" ], e, "tag_origin" );
		level.tod_rampage_fx[ level.tod_rampage_fx.size ] = e;
	}
}

function spark_fx_stop()
{
	if ( !isdefined( level.tod_rampage_fx ) )
		return;
	// Deleting the host is what stops a looping FX — there is no StopFX for a
	// tag-played loop. Same lane the perk-glow and boss-FX systems use.
	foreach ( e in level.tod_rampage_fx )
	{
		if ( isdefined( e ) )
			e Delete();
	}
	level.tod_rampage_fx = undefined;
}

// ---------------------------------------------------------------------------
// THE FLIP, SEEN (2026-10-01; the Rampage-on-the-tower plan the user signed)
// ---------------------------------------------------------------------------
// One burst per flip at the device: ON = an orange shockwave across the arena
// floor, a red second wave, a floor flash, a spark fountain, rising embers and
// an orange flash light; OFF = a puff of smoke, falling sparks and a ring that
// collapses into the device (tools/gen_rampage_fx.py). The host FACES UP (the
// rings lie on the floor) and plays two server frames after it exists: an
// effect played on a host made in the same frame never reaches the client (the
// Healing Aura's lesson, memory flat-ground-fx-rules). Called from the use loop
// only - never at load, never from the spark poll.
function switch_burst( on )
{
	m = level.tod_rampage_model;
	if ( !isdefined( m ) )
		return;
	h = Spawn( "script_model", m.origin );
	if ( !isdefined( h ) )
	{
		dev_log( "SWITCH_FX_FAIL no_entity" );
		return;
	}
	h SetModel( "tag_origin" );
	h.angles = ( -90, 0, 0 );
	h thread switch_burst_play( on );
}

function switch_burst_play( on )   // self = the burst's host
{
	WAIT_SERVER_FRAME;
	WAIT_SERVER_FRAME;
	if ( !isdefined( self ) )
		return;
	if ( on )
	{
		PlayFXOnTag( level._effect[ "tod_rampage_on" ], self, "tag_origin" );
		PlayFXOnTag( level._effect[ "tod_rampage_on_light" ], self, "tag_origin" );
	}
	else
		PlayFXOnTag( level._effect[ "tod_rampage_off" ], self, "tag_origin" );
	dev_log( "SWITCH_FX " + ( ( on ) ? "on (shockwave + flash)" : "off (smoke puff)" ) + " at=" + self.origin );
	wait 3;
	if ( isdefined( self ) )
		self Delete();
}

// ---------------------------------------------------------------------------
// THE HUD SWAP — the red/purple luck bar
// ---------------------------------------------------------------------------

// Pushed on EVERY spawn, not just on toggle. The engine closes a player's LUI
// menus on death -> spectate and the HUD is rebuilt per life, so a
// toggle-only push would leave a revived player looking at an amber bar in a
// rampaged match. Also covers a late joiner, who has no toggle to hear.
//
// callback::on_spawned is the map's own per-player hook (_tod_classes:265,
// _tod_luck:142, _tod_lunge:106) and it fires on respawn as well as first
// spawn — which is the whole requirement here. Registered in init(), so it is
// safe pre-blackscreen like the others.
function on_player_spawned()   // self = player
{
	// One frame of settle so the HUD exists before the field is written — the
	// same deferral the rest of the upgrade UI uses on spawn.
	wait 0.05;
	if ( !isdefined( self ) || !isplayer( self ) )
		return;
	self tod_upgrade_ui::set_rampage( level.tod_rampage_on );
}

function push_hud_all()
{
	foreach ( p in GetPlayers() )
	{
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p tod_upgrade_ui::set_rampage( level.tod_rampage_on );
	}
}

// ---------------------------------------------------------------------------
// THE SPIRE
// ---------------------------------------------------------------------------

// The flag itself SURVIVES ascension by design (user 2026-08-30: "lets also
// make sure rampage inducer works with Endless Spire") — every consumer keeps
// reading it up there, and _tod_endless_rounds tightens the spire's own spawn
// floor when it is set.
//
// What must NOT survive is the STATION. _tod_spire::teardown_tower deletes the
// old world's script entities from an ENUMERATED list, and a module it has
// never heard of is not on it — so without this the breaker, its trigger and
// its FX host would leak three gentities into the mode whose binding constraint
// is the ~1024-gentity budget, and the trigger would still be usable in mid-air
// where the bay used to be.
function teardown_watcher()
{
	level endon( "end_game" );
	level waittill( "tod_ascend" );

	if ( isdefined( level.tod_rampage_trig ) )
	{
		level.tod_rampage_trig Delete();
		level.tod_rampage_trig = undefined;
	}
	if ( isdefined( level.tod_rampage_glow ) )
	{
		level.tod_rampage_glow Delete();
		level.tod_rampage_glow = undefined;
	}
	// The FX host goes with the world; the spire has its own look and a spark
	// hanging in the void is not part of it. The FLAG stays set — the hard mode
	// continues, only its physical switch is gone (it was sealed rounds ago
	// anyway, so nothing becomes unreachable that was not already).
	spark_fx_stop();
	if ( isdefined( level.tod_rampage_model ) )
	{
		level.tod_rampage_model Delete();
		level.tod_rampage_model = undefined;
	}
}

// TWO CONSTANT STRINGS, and they must stay constant.
//
// It was FOUR until v19.0 — the two extra were the sealed forms, and retiring
// the round lock HANDED TWO PERMANENT ENGINE SLOTS BACK to a map that can only
// ever have 250. Fewer distinct strings is never a lint failure; more is a
// crash that blames an innocent object.
//
// SetHintString mints ONE PERMANENT engine slot per DISTINCT string, capped at
// 250 for the whole match and never freed. Four literals is four slots against
// a map already carrying ~140 — fine. Interpolating ANY many-valued runtime
// value here (party size, round, a price) would mint a slot per value and is
// the crash this map has already paid for once.
//
// ROUTING: RAMPAGE is the guard word. The Aetherium cursor-hint router hijacks
// hints containing "[cost:]", door/open/clear vocabulary, pack+punch, perk
// names, or "hold" AND "for" together — so none of those appear below. Note
// there is no " for " anywhere in these strings; that is deliberate, not style.
function hint_for_state()
{
	// " - " (v14.58): PromptDefault splits the noun from its detail on the
	// FIRST " - ", so RAMPAGE gets the title band and the state gets the detail.
	if ( IS_TRUE( level.tod_rampage_on ) )
		return "Hold ^3[{+activate}]^7 ^1RAMPAGE^7 - currently ^2ON^7";
	return "Hold ^3[{+activate}]^7 ^1RAMPAGE^7 - currently ^1OFF^7";
}

// ---------------------------------------------------------------------------
// DEV LOG — this lane shipped with NO diagnostics at all until v19.0, so a
// playtest of the toggle left nothing behind to read. Tag [TOD_RAMPAGE].
//
// The string is assembled OUTSIDE the developer block and only PrintLn sits
// inside it: the native loader rejects an unwrapped call despite a clean
// compile, and literals built inside the block come out blank (CLAUDE.md).
// ---------------------------------------------------------------------------
function dev_log( msg )
{
    if ( !IS_TRUE( level.tod_dev ) ) return;
    line = "[TOD_RAMPAGE] ms=" + GetTime() + " " + msg;
    /#
    PrintLn( line );
    #/
}
