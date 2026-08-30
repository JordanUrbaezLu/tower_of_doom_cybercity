// =============================================================================
// _tod_perk_electric_cherry.csc — DEATH PERCEPTION, client half (v13.19).
// LINEAGE FILENAME KEPT to pair with the .gsc (see its header doctrine — the
// zone/radiant/specialty wiring reference the cherry name and renaming buys
// nothing a player can see). PORTED from the sibling map's shipped module
// (tower_of_doom_II_hellbound _tod_perk_death_perception.csc, HELLBOUND v2):
// registers the SAME two clientfields as the .gsc, with the drawing callbacks.
//
// The outline is stock machinery: duplicate_render's "player_keyline"
// offscreen filter (registered by stock _zm.csc:212, material
// mc/hud_keyline_zm_player, DR_CULL_NEVER — draws through walls; the material
// ships with the filter registration, no zone line needed). We set its
// "keyline_active" flag per zombie, per pulse, gated on LOCAL ownership —
// only the holder's screen outlines the horde.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace tod_perk_electric_cherry;

REGISTER_SYSTEM( "tod_perk_electric_cherry", &__init__, undefined )

function __init__()
{
	clientfield::register( "toplayer", "tod_dp_owner", VERSION_SHIP, 1, "int", &dp_owner_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor",    "tod_dp_ping",  VERSION_SHIP, 1, "counter", &dp_ping_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

// self = the player whose field changed — NOT necessarily the local player.
// Keyed by localClientNum (hellbound review fix): a shared boolean leaked the
// outlines to the second screen in splitscreen.
//
// THE LOCAL GUARD IS LOAD-BEARING (2026-08-30, 3-player live report: one
// player bought Death Perception and EVERY player could see the horde through
// walls). The hellbound comment this ported claimed "toplayer fires only on
// the owning machine" — that holds for a remote client in the common case,
// but NOT universally: the host's client VM processes every player's
// playerstate, and a spectated player's toplayer fields are delivered to
// whoever is viewing through them (that is how spectate mirrors the owner's
// personal HUD). Either path fires this callback with self = SOMEBODY ELSE
// and, ungated, latched this machine's ownership gate to true — and nothing
// ever fired a matching 0 for the local player, so the outlines stayed on
// for the rest of the match. Stock's own pattern for exactly this
// (_gadget_armor.csc:37): accept the value only when self IS the local
// player. Cost: a dead player spectating the DP owner no longer inherits the
// outlines mid-spectate — correct, the perk is personal.
function dp_owner_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( self != GetLocalPlayer( localClientNum ) )
		return;
	if ( !isdefined( level.tod_dp_local ) )
		level.tod_dp_local = [];
	level.tod_dp_local[ localClientNum ] = ( isdefined( newVal ) && newVal > 0 );
}

// self = the zombie actor. Fires on EVERY pulse increment, on every client;
// applies or clears the keyline against the local gate — which is what makes
// buy/loss/late-spawn all self-heal within one pulse.
function dp_ping_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	on = ( isdefined( level.tod_dp_local ) && IS_TRUE( level.tod_dp_local[ localClientNum ] ) );
	self duplicate_render::set_dr_flag( "keyline_active", on );
	self duplicate_render::update_dr_filters( localClientNum );
}
