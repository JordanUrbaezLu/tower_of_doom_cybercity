// =============================================================================
// _tod_perk_lights.gsc — perk machine + Pack-a-Punch GLOW when power turns on
// (server half). DIRECT PORT of map 1's _acc_perk_lights (the auras ARE the
// power visual — the stock off_model->on_model swap shows no visible delta in
// this build, refuted live on map 1).
//
// MECHANISM (map 1, root-caused): server-side PlayFX does NOT render in this
// build. The path that renders is the CLIENT VM: the SERVER (this file) only
// sets a per-machine "todPerkGlow" colour-index clientfield once the
// "power_on" flag is set; the CLIENT (_tod_perk_lights.csc) PlayFXOnTag's the
// looped glow FX. Registration MUST be in lockstep with the .csc twin
// (scope/name/version/bits/type identical or the bit layout desyncs).
//
// REKICK (map 1's Paradise lesson, generalized for a vertical tower): the
// clientfield LATCHES at power-on, but an FX spawned far from the viewer never
// becomes visible on approach. So each glow ent re-pulses ONCE the first time
// a player gets near it (edge-triggered, 0->idx a snapshot apart).
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define TOD_GLOW_REKICK_DIST 700   // re-pulse a machine's glow when a player first gets this close

#namespace tod_perk_lights;

REGISTER_SYSTEM( "tod_perk_lights", &__init__, undefined )

function __init__()
{
	// scriptmover scope = the pool stock power-ups use for their glow clientfield;
	// script_models (machine + PaP host) are scriptmover-scope ents. 4 bits = 0..15.
	clientfield::register( "scriptmover", "todPerkGlow", VERSION_SHIP, 4, "int" );
}

// Threaded from tod_main::init() (gameplay time — NOT from __init__, which
// would risk the flag-wait-from-init crash).
function init()
{
	level thread power_glow_watch();
}

function power_glow_watch()
{
	level endon( "end_game" );

	level flag::wait_till( "initial_blackscreen_passed" );

	while ( !( level flag::exists( "power_on" ) && level flag::get( "power_on" ) ) )
		wait( 0.25 );

	glow_all_machines();
	level thread glow_rekick_watch();
}

function glow_all_machines()
{
	if ( isdefined( level.tod_perk_glow_done ) && level.tod_perk_glow_done )
		return;
	level.tod_perk_glow_done = true;

	level.tod_glow_ents = [];

	// Every perk machine carries the stock "zombie_vending" trigger whose
	// .machine is the renderable script_model (VERIFIED map 1:
	// perk_machine_spawn_init blesses trigger.machine).
	triggers = GetEntArray( "zombie_vending", "targetname" );
	foreach ( t in triggers )
	{
		if ( !isdefined( t.machine ) )
			continue;
		idx = perk_color_index( t.script_noteworthy );
		t.machine clientfield::set( "todPerkGlow", idx );
		t.machine.tod_glow_idx = idx;
		level.tod_glow_ents[ level.tod_glow_ents.size ] = t.machine;
	}

	// Pack-a-Punch: the "pack_a_punch" noteworthy ent is the USE TRIGGER (not a
	// renderable scriptmover), so glow an invisible tag_origin host at its spot.
	pap = GetEntArray( "pack_a_punch", "script_noteworthy" );
	if ( pap.size > 0 && isdefined( pap[ 0 ] ) )
	{
		host = spawn( "script_model", pap[ 0 ].origin + ( 0, 0, -50 ) );
		host setmodel( "tag_origin" );
		level.tod_pap_glow_host = host;   // keep a ref so it is not GC'd
		host clientfield::set( "todPerkGlow", 10 );
		host.tod_glow_idx = 10;
		level.tod_glow_ents[ level.tod_glow_ents.size ] = host;
	}
}

// Edge-triggered per-ent re-pulse: the first time any player closes within
// TOD_GLOW_REKICK_DIST of a glow ent (after power), blink its field 0 -> idx so
// the client replays the FX where the player can actually see it.
function glow_rekick_watch()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait 1;
		if ( !isdefined( level.tod_glow_ents ) )
			continue;

		foreach ( e in level.tod_glow_ents )
		{
			if ( !isdefined( e ) || IS_TRUE( e.tod_glow_rekicked ) )
				continue;

			foreach ( p in GetPlayers() )
			{
				if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
					continue;
				if ( Distance( p.origin, e.origin ) > TOD_GLOW_REKICK_DIST )
					continue;

				e.tod_glow_rekicked = true;
				e clientfield::set( "todPerkGlow", 0 );
				e thread reglow( e.tod_glow_idx );
				break;
			}
		}
	}
}

function reglow( idx )   // self = the machine model / glow host
{
	level endon( "end_game" );
	wait 0.25;   // > one snapshot, so the 0 actually transmits before the re-set
	if ( isdefined( self ) )
		self clientfield::set( "todPerkGlow", idx );
}

// specialty string -> colour index (the .csc maps each index to an FX).
// VERIFIED keys (map 1): Double Tap = specialty_doubletap2, Stamin-Up =
// specialty_staminup. Unknown -> 10 (teal).
function perk_color_index( specialty )
{
	if ( !isdefined( specialty ) )
		return 10;
	switch ( specialty )
	{
		case "specialty_armorvest":               return 1;   // Jugg         - red
		case "specialty_fastreload":              return 2;   // Speed Cola   - green
		case "specialty_doubletap2":              return 3;   // Double Tap   - yellow
		case "specialty_staminup":                return 4;   // Stamin-Up    - orange
		// Mule Kick RETIRED 2026-08-25 (replaced by PhD Flopper on the crown).
		// Kept as a live case, not deleted: the perk is still REGISTERED by stock, so
		// a stray machine or a debug grant would otherwise fall through to no colour.
		case "specialty_additionalprimaryweapon": return 5;   // (retired)   - amber
		case "specialty_quickrevive":             return 6;   // Quick Revive - blue
		case "specialty_deadshot":                return 7;   // Deadshot     - blacklight
		case "specialty_widowswine":              return 8;   // Widow's Wine - white
		case "specialty_electriccherry":          return 9;   // PhD Flopper  - purple
		case "specialty_combat_efficiency":       return 9;   // Electric Cherry (_tod_perk_electric_cherry rides this unused specialty) - purple
		default:                                  return 10;  // generic / PaP - teal
	}
}

// Public: drive the coloured-glow FX on ANY scriptmover ent (future systems).
function set_glow( ent, color_index )
{
	if ( !isdefined( ent ) )
		return;
	ent clientfield::set( "todPerkGlow", color_index );
}
