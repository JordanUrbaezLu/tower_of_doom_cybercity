// =============================================================================
// _tod_teleport.gsc — BREATHER TELEPORTERS (v9.37, user 2026-08-23: "Every
// platform will have a teleporter that will link back to the first starting
// floor. There will be a wait period before you can use it again so you cant
// just spam it. We have this implementation in the other map with models and
// everything and fx. Wait period is 1 minute. Only players on the teleporter
// will be teleported.")
//
// Port of map 1's _acc_teleporter.gsc (its docs/44 workstream C) cut to the
// tower's shape: FOUR source pads, one per breather balcony (laps 10/20/30/
// 40), all linked ONE WAY to a single ARRIVAL pad on the base arena's west
// ring. Per-pad 60s cooldown (each breather is its own device). No unlock
// gate, no dvars, no toasts (map doctrine: no floaty captions) — a deny is the
// stock no-purchase sound + the static "recharging" hint, and the pad's idle
// BEAM is the ready light: beam on = ready, beam off = recharging.
//
// THE PAD = the assembled Der Eisendrache teleporter (map 1's Program115-style
// build): four stock p7_zm_der_teleporter quarter-wedges at yaw 0/90/180/270
// tile the ring, + blue/red wire pieces + the glass dome, all SetScale 2.5
// (~167u wide) and sunk map 1's eyeball-tuned -52 so the rim sits ~11u proud.
// FLAT — no step-up clips (map 1: entity clips are navmesh-invisible = a
// zombie snag / safe-spot exploit). Players stand inside the walk-through
// ring; the models are not solid.
//
// THE SEQUENCE (map 1's Kino wind-up, NO player lock): trigger -> CHARGE 2.2s
// (charge FX at torso height + the rising hum; everyone keeps full control)
// -> DISCHARGE (flash + de-rez + warp boom) -> everyone standing within
// TOD_TP_GATHER of the pad AT THAT MOMENT warps (step off during the charge
// and you stay), fanned onto a ring at the arrival pad so capsules never
// stack -> materialize beam + boom at the arrival pad. EVERY FX rides a
// tag_origin host (PlayFxOnTag) — bare PlayFX does not render in this build
// (map 1's _acc_perk_lights rule; its v3 sequence was invisible for exactly
// that). Hosts are throwaway (fx_burst) except the idle beam.
//
// ARRIVAL SAFETY: the destination is the base arena ring — the start zone,
// always enabled — so no zonemgr enable is needed (map 1 needed one for its
// door-gated lab). Riders land at floor z (the ground slab's top is z=0).
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_utility;
#using scripts\zm\zm_tower_of_doom\_tod_breather_data;  // GENERATED — spur pad + arrival anchors (v13)
#using scripts\zm\zm_tower_of_doom\_tod_doors;          // v13.9: a down-ride opens the bay from the inside (force_open_by_flag)
#using scripts\zm\zm_tower_of_doom\_tod_perk_scatter;   // derez_burst / play_sound_at_origin (host-based, proven)

#insert scripts\shared\shared.gsh;

// AFTER every #using/#insert — between them it kills the compile ("No
// generated data", live 2026-08-20). Models + FX are stock; the matching
// xmodel,/fx, zone lines force-pack them (the finale-props rule).
#precache( "model", "p7_zm_der_teleporter" );
#precache( "model", "p7_zm_der_teleporter_pad_wires_blue" );
#precache( "model", "p7_zm_der_teleporter_pad_wires_red" );
#precache( "model", "p7_zm_der_teleporter_pad_glass" );
#precache( "fx", "dlc0/factory/fx_teleporter_beam_factory" );
#precache( "fx", "dlc4/genesis/fx_sophia_elec_charge_teleporter" );
#precache( "fx", "dlc1/castle/fx_elec_teleport_flash_lg" );
#precache( "fx", "dlc5/theater/fx_teleport_flashback_kino" );

#namespace tod_teleport;

// v10.3 (playtest 2026-08-23: "teleporters take way too long to activate"):
// charge 2.2 -> 0.8s and cooldown 60 -> 30s. The 2.2s Kino wind-up was pure
// theatre inherited from map 1; at 0.8 the flash/derez still read.
#define TOD_TP_COOLDOWN_SEC   60   // 30 -> 45 -> 60, both 2026-08-29 (final: "Make the recharge on teleporters 1 minute")
#define TOD_TP_CHARGE_SEC     0.8
#define TOD_TP_TRIG_RADIUS    110     // the assembled pad is ~167 wide — stand in the ring
#define TOD_TP_TRIG_HEIGHT    96
// TOD_TP_BAY_TRIG_R IS GONE (v10.24). It existed only because the v10.22 bay
// was squeezed into the arena's east strip, where 170u spacing was all there
// was and the trigger had to shrink to 85 to fit it. The bay now has its own
// ROOM, so the pads sit 220 apart and spawn_pad's normal TOD_TP_TRIG_RADIUS
// (110) applies again — bigger, more forgiving triggers and one less special
// case.
#define TOD_TP_GATHER         120     // riders within this (2D) at FIRE time — v10.4: must be >= TOD_TP_TRIG_RADIUS (110), else a player who ACTIVATED from the trigger rim is excluded by his own ride (audit find)
#define TOD_TP_GATHER_Z       80      // ...and on the pad's floor (the balcony below shares no x/y, this is belt-and-braces)
#define TOD_TP_RING           48      // fan-out ring at the arrival pad (no capsule stack)
#define TOD_TP_PAD_SCALE      2.5     // Program115 assembly scale
#define TOD_TP_PAD_ZOFF       -52     // map 1's sink: rim ~11u proud of the floor
// ARRIVAL — inside the TELEPORT BAY, between the door and the row of pads.
// v10.24 (user: "Someone placed the telepoerter under the stairs. Thats a
// horrible spot. Just add a new area at spawn where these teleporters live").
// THE v10.22 BAY WAS UNDER THE STAIRCASE. It ran down the arena's east strip at
// x=360 — but lap 1's east flight occupies x[256,416] climbing the east face,
// so three of the four pads sat directly beneath the treads. The east strip
// read as "the only clear straight run in the arena" on a plan view, and a plan
// view has no z. That is the whole bug.
//
// The bay is now its own ROOM south of the arena (see TPB_* in
// tools/gen_tower_map.js), punched through the south wall directly behind the
// spawn band. Nothing is above it.
//
// The arrival sits at the room's centre-north, 300u off the nearest pad — the
// v10.4/v10.24 rule is that a landing spot must be further than TOD_TP_GATHER
// (120) from EVERY pad, or a rider is swept along by someone else's ride the
// moment they land. Here the margin is 199u rather than the 44u the arena
// version could afford. Facing NORTH so you land looking at the doorway with
// the whole bank of machines at your back.
#define TOD_TP_BASE_ORG       ( 0, -620, 0 )
#define TOD_TP_BASE_YAW       90                      // facing NORTH, out the door

// THE BAY IS GATED (v10.25, user: "it shoud cost money to open that room"), and
// the DOWN pads are gated on the same flag as the up pads — which is a
// correctness requirement, not a design flourish. The arrival sits INSIDE the
// room; if a breather pad still worked while the door was shut, a rider would
// land in a sealed box with a slab they might not be able to afford. Gating
// both directions removes that soft-lock entirely and makes the bay read as one
// purchase: buy it once and the network is on, both ways.
// A locked pad is not a dead end for the player — pad_locked() just denies with
// the stock no-purchase sound and the pad's beam stays off, and walking down
// was always available.
#define TOD_TP_BAY_FLAG       "enter_tpbay"
// SOURCE pads: one per breather — and since v13 the pad is OFF the room floor
// entirely, out on the SPUR: through the doorway in the lounge's outer (S)
// wall, down a 320-long open-air gantry, onto a 288x288 platform floating in
// the void, porter at its centre. Coordinates come from GENERATED
// _tod_breather_data.gsc (tp_pad_org / tp_arrival_org — the door-data
// no-drift contract; the generator asserts the pad's 110u trigger against
// every other lounge trigger and against the platform rails). Up-riders land
// on the GANTRY, 160u toward the room: outside the pad's 120u gather, so an
// arrival is never swept along by the next departure (the v10.4 rule — the
// offset now rides in the generated data, not in a define here).

function init()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );

	fx_register();
	level.tod_tp_trigs = [];

	// v10.3 — TWO-WAY (user: "They should be two way as well. Which means we
	// need 5 different porters at spawn"). The base arena now carries FIVE
	// porters: the shared ARRIVAL pad (all breather pads still land here) plus
	// four UP pads, one per breather, each locked behind that breather's own
	// lap door — teleporting up must never skip a door the climb still owes
	// (flags come from _tod_doors, live once the door is bought). Up-riders
	// land on the breather's own pad ring; its trigger is a use-trigger, so
	// standing on it is harmless.
	//
	// Base placement (arena half 540, core 256): every pad centre keeps 150u+
	// clear of the class stations (y -280, x -390..-60), the QR pin (-75,500),
	// spawn (~0,-490) and the corner risers (+-470,+-470); the assemblies are
	// walk-through models, only the 110u triggers must not overlap.
	// (The standalone arrival assembly + its idle beam were REMOVED in v10.22 -
	// see TOD_TP_BASE_ORG. It was the 5th "porter" the user asked to delete:
	// trigger-less decoration that read as a broken pad. Riders now land in
	// front of the bay, which is its own landmark.)

	zs = tod_breather_data::breather_zs();
	for ( i = 0; i < zs.size; i++ )
		level thread spawn_pad( tod_breather_data::tp_pad_org( zs[ i ] ), 0, TOD_TP_BASE_ORG, TOD_TP_BASE_YAW,
			// LEADS WITH THE NOUN. PromptDefault strips "Hold [{+activate}]" before
			// drawing, so the old line reached the screen as the fragment
			// "to teleport to the base" — the same dangling-preposition bug the
			// altar copy was rewritten to fix in v10.x (audit 2026-08-25).
			// v13.6: bay-door gate REMOVED (user: "The teleporters are blocked if
			// the main door on floor one is not opened. Lets remove that check.")
			// — undefined lock flag = power is the only gate on the DOWN ride.
			// CONSEQUENCE, accepted by the user: porting down pre-bay-door lands
			// you inside the sealed bay; the door buys from both sides (750).
			"Hold ^3[{+activate}]^7 ^5TELEPORTER^7 - down to the BASE", undefined );

	// THE TELEPORTER BAY (v10.25) — four up-pads in a 2x2 block, read like a
	// keypad: front row floors 10 / 20, back row 30 / 40, left to right.
	//
	// A 2x2 IS WHAT MAKES THE ROOM SMALL. TOD_TP_TRIG_RADIUS is 110, so centres
	// must be 220 apart for the four use-triggers to be tangent rather than
	// overlapping (overlapping use-triggers make the prompt a coin flip — the
	// v10.4 rule). In a LINE that forces 828 units of pads before any margin; in
	// a square it is 388 x 388, and the room came down from 960x640 to 480x560.
	//
	// Clearances, all measured against the room (tools/gen_tower_map.js TPB_*):
	//   room interior      x[-240,240]  y[-1280,-560]   (deepened 2026-08-27)
	//   pad half-extent    84 (the assembly is ~167 across)
	//   pads x -+110       -> 26..194, so 46u of floor to each side wall
	//   trigger rim x -+220 -> 20u short of the wall
	//   the two rows       52u apart at the pad edges — still walkable between
	//   back row to the south wall  132u   (was 56u)
	//   arrival (0,-620) to the nearest pad (-+110,-840) = 246u (was 178u),
	//     comfortably past the 120u gather (the arena bay managed 164u, and its
	//     first cut shipped at 116u — INSIDE the gather — which was a live bug)
	//   risers (-+205,-600) to the nearest pad = 258u (was 186u), past the ~165u
	//     at which a zombie climbs out on top of somebody mid-teleport
	//
	// ROWS MOVED 80 SOUTH 2026-08-27 to stop the ARRIVAL DECAL from drawing
	// through the front-row pad decals — they overlapped by 66 x 36 units. Purely
	// visual: the centres were already 178u apart, so nothing ever malfunctioned.
	// THESE FOUR COORDINATES ARE HARDCODED AND MIRROR gen_tower_map.js
	// TPB_PAD_YN / TPB_PAD_YS. There is no generated bridge — change one without
	// the other and the trigger stops sitting on the pad you can see.
	// The risers are in the ZONE, not here — tpbay_zone in the generator. They
	// exist because the user asked for spawns in the room, and they are safe to
	// have (unlike in the power hallway) precisely because this room is its own
	// zone: nothing spawns here until the door is bought.
	up_orgs = [];
	up_orgs[ 0 ] = ( -110, -840, 0 );   // FLOOR 10  front-left
	up_orgs[ 1 ] = (  110, -840, 0 );   // FLOOR 20  front-right
	up_orgs[ 2 ] = ( -110, -1060, 0 );  // FLOOR 30  back-left
	up_orgs[ 3 ] = (  110, -1060, 0 );  // FLOOR 40  back-right
	// v10.4 (audit find): up-riders used to land ring-fanned around the
	// breather DOWN pad's own centre — inside its gather, so if that pad was
	// mid-charge the arrivals were instantly warped straight back down. They
	// land OFFSET instead — since v13 on the spur GANTRY, 160u toward the room
	// (tod_breather_data::tp_arrival_org; the generator asserts the offset
	// clears the 120u gather).
	up_flags = array( "enter_lap10", "enter_lap20", "enter_lap30", "enter_lap40" );
	up_hints = [];
	// LEAD WITH THE NOUN — PromptDefault strips "Hold [{+activate}]", so these
	// used to render as "to teleport to FLOOR 10" (audit 2026-08-25). No "for"
	// in any of them, so the perk-card router still cannot claim the line, and
	// no cost bracket, because the pads charge nothing.
	up_hints[ 0 ] = "Hold ^3[{+activate}]^7 ^5TELEPORTER^7 - up to FLOOR 10";
	up_hints[ 1 ] = "Hold ^3[{+activate}]^7 ^5TELEPORTER^7 - up to FLOOR 20";
	up_hints[ 2 ] = "Hold ^3[{+activate}]^7 ^5TELEPORTER^7 - up to FLOOR 30";
	up_hints[ 3 ] = "Hold ^3[{+activate}]^7 ^5TELEPORTER^7 - up to FLOOR 40";
	// yaw 90 = the assemblies face NORTH, back toward the door and the arrival
	// spot, so walking in you are looking at the front of all four machines.
	// No trig_r argument any more — spawn_pad's default TOD_TP_TRIG_RADIUS (110)
	// is what the room was sized for.
	for ( i = 0; i < 4; i++ )
		level thread spawn_pad( up_orgs[ i ], 90, tod_breather_data::tp_arrival_org( zs[ i ] ), 90,
			up_hints[ i ], up_flags[ i ] );
}

// -> true while a lock flag exists and is still unset (the door unbought).
function pad_locked( lock_flag )
{
	// v13.6 (user 2026-08-29: "Teleporters are only blocked by floor level and
	// power now" / "they can always go down if power is on"): POWER gates every
	// pad — there was NO power check here before, only door flags. The four
	// DOWN pads now pass lock_flag undefined (power is their whole gate); the
	// four UP pads keep their enter_lapN flags ("floor level").
	if ( !( level flag::exists( "power_on" ) && level flag::get( "power_on" ) ) )
		return true;
	if ( !isdefined( lock_flag ) )
		return false;
	if ( !( level flag::exists( lock_flag ) ) )
		return false;   // flags register at _tod_doors init — treat early reads as open
	return !( level flag::get( lock_flag ) );
}

function fx_register()
{
	if ( !isdefined( level._effect ) )
		level._effect = [];
	level._effect[ "tod_tp_beam" ]   = "dlc0/factory/fx_teleporter_beam_factory";      // idle pad beam = the ready light
	level._effect[ "tod_tp_charge" ] = "dlc4/genesis/fx_sophia_elec_charge_teleporter"; // the wind-up
	level._effect[ "tod_tp_flash" ]  = "dlc1/castle/fx_elec_teleport_flash_lg";         // the bright discharge
	level._effect[ "tod_tp_kino" ]   = "dlc5/theater/fx_teleport_flashback_kino";       // arrival "materialize" beam
}

// Build the assembled Der Eisendrache pad from the stock fragments (map 1's
// exact arrangement): 4 body wedges at 0/90/180/270, blue wires at 90/270,
// red at 0/180, the glass dome at 180 — every piece shares the pad origin
// (each is a quarter-wedge pivoted at the pad centre).
function spawn_der_teleporter( origin, yaw_base )
{
	base = origin + ( 0, 0, TOD_TP_PAD_ZOFF );
	spawn_der_piece( "p7_zm_der_teleporter", base, yaw_base + 0 );
	spawn_der_piece( "p7_zm_der_teleporter", base, yaw_base + 90 );
	spawn_der_piece( "p7_zm_der_teleporter", base, yaw_base + 180 );
	spawn_der_piece( "p7_zm_der_teleporter", base, yaw_base + 270 );
	spawn_der_piece( "p7_zm_der_teleporter_pad_glass", base, yaw_base + 180 );
	spawn_der_piece( "p7_zm_der_teleporter_pad_wires_blue", base, yaw_base + 90 );
	spawn_der_piece( "p7_zm_der_teleporter_pad_wires_blue", base, yaw_base + 270 );
	spawn_der_piece( "p7_zm_der_teleporter_pad_wires_red",  base, yaw_base + 0 );
	spawn_der_piece( "p7_zm_der_teleporter_pad_wires_red",  base, yaw_base + 180 );
}

function spawn_der_piece( model, origin, yaw )
{
	m = Spawn( "script_model", origin );
	if ( !isdefined( m ) )
		return undefined;   // entity pool full — skip the piece, never throw
	m SetModel( model );
	m.angles = ( 0, yaw, 0 );
	m SetScale( TOD_TP_PAD_SCALE );
	return m;
}

// The idle beam on a permanent tag_origin host (the derez host pattern minus
// the delete). Returns the host so a pad can switch it off while recharging.
function spawn_beam( origin )
{
	h = Spawn( "script_model", origin + ( 0, 0, 2 ) );
	if ( !isdefined( h ) )
		return undefined;
	h SetModel( "tag_origin" );
	PlayFxOnTag( level._effect[ "tod_tp_beam" ], h, "tag_origin" );
	return h;
}

// One source pad: the assembly, the idle beam, a use-trigger, and its loop.
// hint_ready = this pad's ready hint (per destination); lock_flag = a door
// flag that must be SET before the pad works (undefined = always unlocked).
// trig_r (v10.22): the BAY pads pass a tighter radius than the default. The
// v10.4 rule "every use-trigger 220u+ from its nearest triggered neighbour" is
// about the RADII touching, not the centres - a 95u radius lets the bay sit at
// 200u spacing and still satisfy it, which is what makes four pads fit between
// the power door and the NE riser. Breather pads omit it and keep the default.
function spawn_pad( src, src_yaw, dst, dst_yaw, hint_ready, lock_flag, trig_r = TOD_TP_TRIG_RADIUS )
{
	level endon( "end_game" );

	spawn_der_teleporter( src, src_yaw );

	// Script-spawned use-trigger => TriggerIgnoreTeam is REQUIRED (no prompt
	// otherwise). Raised 32u so the cursor lands.
	t = Spawn( "trigger_radius_use", src + ( 0, 0, 32 ), 0, trig_r, TOD_TP_TRIG_HEIGHT );
	t TriggerIgnoreTeam();
	t SetCursorHint( "HINT_NOICON" );
	t.tod_tp_src = src;
	t.tod_tp_hint_ready = hint_ready;
	t.tod_tp_lock_flag = lock_flag;
	t.tod_tp_cooldown_until = 0;
	level.tod_tp_trigs[ level.tod_tp_trigs.size ] = t;

	refresh( t );                 // ready: beam on + the use hint
	level thread state_ticker( t );

	for ( ;; )
	{
		t waittill( "trigger", player );
		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( !zm_utility::is_player_valid( player ) )
			continue;   // downed / spectating
		// A teammate is down under your feet and you are holding USE to revive
		// them — do NOT charge the pad and warp away, leaving them to bleed out
		// on a floor nobody else can reach. Reviving polls the raw USE button
		// (_zm_laststand.gsc:1129) independently of which prompt is drawn, so
		// without this the revive press fires the teleporter too.
		// SOUNDED, unlike the door/crate/PaP guards: this pad's mute refusals are
		// exactly what produced the 2026-08-26 "teleporter wasn't activated"
		// report, so every refusal here now announces itself.
		if ( player zm_utility::in_revive_trigger() )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		// THE WORLD IS FROZEN FOR AN UPGRADE PICK — refuse, but SAY SO.
		//
		// THIS SILENCE IS THE "TELEPORTER WASN'T ACTIVATED" BUG (live report
		// 2026-08-26: "A player died and i got to a floor 30 with teleporter and
		// it wasnt activated. But before that I was using teleporters fine").
		// The pad was refusing CORRECTLY and the refusal was completely mute: no
		// sound, no hint change, beam still lit. Indistinguishable from a dead
		// trigger, so it read as a broken teleporter.
		//
		// AND THE WINDOW IS WIDE, WHICH IS WHY THIS IS REACHABLE EVERY FOURTH
		// ROUND RATHER THAN BEING A FREAK COINCIDENCE. run_upgrade_event holds
		// the pause until every participant picks or 20s elapse, but
		// player_choice_flow calls menu_freeze(false) PER PLAYER the instant
		// that player locks a card. So the first player to choose is unfrozen
		// and running around a still-paused world for the remaining ~13-18s —
		// free to walk onto a pad that will ignore them without a peep. A player
		// who was DOWN or DEAD when the event fired is excluded from the event
		// entirely (_tod_upgrades.gsc:1672), so they are never frozen at all and
		// hit this window from the very first second.
		//
		// Every OTHER refusal in this loop plays zmb_no_purchase; this one now
		// matches them. DELIBERATELY NOT a fourth "paused" state in refresh():
		// that would flicker the pad beam off and on every four rounds and burn
		// a triggerstring slot for no gain.
		if ( IS_TRUE( level.tod_upgrade_pause ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		if ( IS_TRUE( t.tod_tp_busy ) )
			continue;   // a charge is already running on this pad

		// LOCKED (an up pad whose breather door is unbought) or recharging ->
		// the stock deny sound (no caption).
		if ( pad_locked( t.tod_tp_lock_flag ) || GetTime() < t.tod_tp_cooldown_until )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		// Arm the cooldown BEFORE the warp so a second press can't double-fire,
		// flip the pad to its recharging look, then run the sequence.
		t.tod_tp_cooldown_until = GetTime() + TOD_TP_COOLDOWN_SEC * 1000;
		t.tod_tp_busy = true;
		refresh( t );
		do_teleport( src, dst, dst_yaw );
		t.tod_tp_busy = undefined;
	}
}

// Ready state -> beam + hint, applied on the EDGE only (two constant hint
// strings — the engine caps the triggerstring cache at 250 UNIQUE strings, so
// never a per-second countdown in the hint).
function refresh( t )
{
	if ( !isdefined( t ) )
		return;
	// Three states now (constant strings only — the triggerstring cache):
	// locked (door unbought) / recharging / ready.
	state = "ready";
	if ( pad_locked( t.tod_tp_lock_flag ) )
		state = "locked";
	else if ( GetTime() < t.tod_tp_cooldown_until )
		state = "recharge";
	if ( isdefined( t.tod_tp_state ) && t.tod_tp_state == state )
		return;
	prev = t.tod_tp_state;   // undefined on the very first call (spawn_pad init)
	t.tod_tp_state = state;
	if ( state == "ready" )
	{
		if ( !isdefined( t.tod_tp_beam ) )
			t.tod_tp_beam = spawn_beam( t.tod_tp_src );
		t SetHintString( t.tod_tp_hint_ready );
		// RECHARGE-COMPLETE cue (2026-08-29, docs/43) — the beam snapping back on
		// was the map's one state change with a visual and no sound at all.
		//
		// GATED ON prev == "recharge" AND NOTHING ELSE, which is the whole trick:
		// refresh() also runs once per pad from spawn_pad (:320) with prev
		// undefined, so an ungated call here would fire every teleporter in the
		// map simultaneously at level start. The locked -> ready edge is excluded
		// too: that is a breather door being bought, which already has its own
		// purchase feedback, and it would double up on it.
		if ( isdefined( prev ) && prev == "recharge" )
			tod_perk_scatter::play_sound_at_origin( t.tod_tp_src, "tod_teleport_ready", 4 );
	}
	else
	{
		if ( isdefined( t.tod_tp_beam ) )
			t.tod_tp_beam Delete();
		t.tod_tp_beam = undefined;
		if ( state == "locked" )
			// user 2026-08-24: "Teleporter text should be more specific when you
			// havent unlocked the area. Something like this teleporter is offline.
			// And no cost text." Was "^1LINK OFFLINE^7 - open this floor's breather
			// door" — "LINK OFFLINE" read as jargon and the trailing clause read as
			// a price/requirement. Plain sentence, nothing that looks like a cost.
			t SetHintString( "^1This teleporter is offline" );
		else
			t SetHintString( "^1Teleporter recharging..." );
	}
}

// Catches the cooldown-elapsed edge (beam back on, hint back to usable).
function state_ticker( t )
{
	level endon( "end_game" );
	for ( ;; )
	{
		wait 1;
		if ( !isdefined( t ) )
			return;
		refresh( t );
	}
}

// Throwaway FX host: PlayFxOnTag on a tag_origin for `secs`, then delete. NO
// endon — a thread killed mid-wait would orphan the host with a looping FX
// playing (map 1 review).
function fx_burst( key, origin, secs )
{
	h = Spawn( "script_model", origin );
	if ( !isdefined( h ) )
		return;
	h SetModel( "tag_origin" );
	PlayFxOnTag( level._effect[ key ], h, "tag_origin" );
	wait secs;
	if ( isdefined( h ) )
		h Delete();
}

// The bright DISCHARGE at a pad: flash + the de-rez burst (numbers + zap) +
// the warp boom.
function discharge( origin )
{
	level thread fx_burst( "tod_tp_flash", origin + ( 0, 0, 4 ), 2.0 );
	tod_perk_scatter::derez_burst( origin );
	tod_perk_scatter::play_sound_at_origin( origin, "tod_warp", 3 );
}

// Kino teleport, no player lock: CHARGE (FX at torso height + hum) -> fire.
function do_teleport( src, dst, dst_yaw )
{
	level thread fx_burst( "tod_tp_charge", src + ( 0, 0, 40 ), TOD_TP_CHARGE_SEC + 0.5 );
	// tod_teleport_fire (2026-08-29, docs/43): the map's own 2.2s time-distortion
	// warp, replacing the ported acc hum. Emitted at SRC, so what each side hears
	// differs and that is correct:
	//   * the RIDER hears its first TOD_TP_CHARGE_SEC (0.8s) — the wind-up — and
	//     then leaves, so it is cut off mid-sweep by the arrival discharge at dst.
	//     The cut IS the translocation; do not "fix" it by re-playing the full
	//     asset at dst, which would read as two teleports.
	//   * anyone LEFT BEHIND near the pad hears the whole 2.2s.
	// Side effect worth keeping: tod_warp now only marks the two DISCHARGES, so
	// departure and arrival no longer open with the identical cue.
	tod_perk_scatter::play_sound_at_origin( src, "tod_teleport_fire", 4 );
	wait TOD_TP_CHARGE_SEC;

	discharge( src );   // departure flash + boom

	// Gather at FIRE time: whoever is standing on the pad NOW rides. Valid
	// players only — a downer mid-charge simply doesn't warp.
	riders = [];
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !zm_utility::is_player_valid( p ) )
			continue;
		if ( Distance2D( p.origin, src ) > TOD_TP_GATHER )
			continue;
		if ( abs( p.origin[ 2 ] - src[ 2 ] ) > TOD_TP_GATHER_Z )
			continue;
		riders[ riders.size ] = p;
	}

	for ( i = 0; i < riders.size; i++ )
	{
		ang = i * 360 / riders.size;
		off = ( cos( ang ) * TOD_TP_RING, sin( ang ) * TOD_TP_RING, 0 );   // ring so capsules don't stack
		riders[ i ] SetOrigin( dst + off );
		riders[ i ] SetPlayerAngles( ( 0, dst_yaw, 0 ) );
	}

	// v13.9 (user live report: ported down pre-door, "went to 1 health and
	// hear the teddy bear like I was out of bounds" — exactly what it was:
	// the sealed bay's zone was INACTIVE, and stock's playable-area monitor
	// punished them for standing in it). A DOWN ride now opens the bay door
	// from the inside, free: zone live, monitor satisfied, risers wake,
	// zombies path in through the open doorway — no invulnerable camp room,
	// no stranded actors, and the user's "power is the only gate going down"
	// rule carried to its conclusion. dst z < 100 discriminates the base bay
	// (z 0) from the breather gantry arrivals (z 3648+); empty rides skip.
	if ( riders.size > 0 && dst[ 2 ] < 100 )
		tod_doors::force_open_by_flag( "enter_tpbay" );

	// A ride moves players thousands of units in ONE FRAME, which every
	// distance-watching system reads as "the thing I am watching just stalled".
	// tod_bosses::tod_boss_stuck_watch resets its no-progress accumulator on this
	// counter — without it, a breather ride makes `best` unbeatable and the
	// watchdog relocates a boss that was never stuck, which is exactly the
	// "elites randomly spawn at you when you are too far away" report.
	if ( riders.size > 0 )
	{
		level.tod_tp_stamp = ( ( isdefined( level.tod_tp_stamp ) ) ? level.tod_tp_stamp + 1 : 1 );
		// The ride is the ONE moment we know for certain a party just abandoned a
		// floor. _tod_stray waits out the zone manager's riser rebuild, then runs
		// hot for 6s so the horde arrives instead of walking forty floors down.
		// NOTIFY ONLY — no import in either direction, so _tod_stray can be
		// deleted without touching this file and this line becomes a no-op.
		level notify( "tod_stray_pump" );
	}

	// ARRIVAL: materialize beam + flash + boom at the base pad (fires even
	// for an empty ride — the device still discharged).
	level thread fx_burst( "tod_tp_kino", dst + ( 0, 0, 4 ), 3.0 );
	discharge( dst );
}
