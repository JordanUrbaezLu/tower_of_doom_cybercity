// =============================================================================
// _tod_powerups.csc — client half of the map's custom powerup drops.
// Stock contract (_zm_powerup_free_perk.csc precedent): the csc must
// include_zombie_powerup ITSELF (only the server side auto-includes via
// register_powerup), then add_zombie_powerup — with the SAME clientfield
// name/version as the gsc for the timed admin gun, or the toplayer
// clientfield registration mismatches at load.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_powerups;

#namespace tod_powerups;

REGISTER_SYSTEM( "tod_powerups", &__init__, undefined )

function __init__()
{
	// instant — no HUD timer field (admin gun removed on user order 2026-08-20)
	zm_powerups::include_zombie_powerup( "tod_free_pap" );
	zm_powerups::add_zombie_powerup( "tod_free_pap" );

	// [tod 2026-08-21] Free Pack-a-Punch (ZoekMeMaar model) + Zombie Blood
	// (NSZ model). Both instant/no-timer, so no clientfield to keep in
	// lockstep — but the csc MUST include+add each one itself or the client
	// never learns the powerup exists and the drop renders wrong.
	zm_powerups::include_zombie_powerup( "tod_pap" );
	zm_powerups::add_zombie_powerup( "tod_pap" );

	// ZOMBIE BLOOD — RE-ENABLED 2026-08-26, RESTORING THE LOCKSTEP THIS FILE'S
	// OWN HEADER DEMANDS. The drop was disabled on both halves on 2026-08-21;
	// when the user asked for it back on 2026-08-25 only the SERVER half was
	// switched on (register + add + the two setters in _tod_powerups.gsc), and
	// this half stayed commented out. Per the contract at the top of this
	// file, register_powerup auto-includes on the server ONLY — the csc must
	// include+add itself or the client never learns the powerup exists and the
	// drop renders wrong.
	// TIMED SINCE 2026-08-26 ("zombie blood doesn't show in the bar"): the
	// clientfield arg here MUST match the gsc add_zombie_powerup's
	// client_field_name (both "tod_zombie_blood", both VERSION_SHIP, both
	// 2-bit "toplayer") or the registration mismatches at load. This add also
	// enrolls the field in set_clientfield_code_callbacks' pass, which is what
	// lets the Aetherium tray row (AetheriumPowerupsContainer.lua) see it.
	zm_powerups::include_zombie_powerup( "tod_zombie_blood" );
	zm_powerups::add_zombie_powerup( "tod_zombie_blood", "tod_zombie_blood" );
}
