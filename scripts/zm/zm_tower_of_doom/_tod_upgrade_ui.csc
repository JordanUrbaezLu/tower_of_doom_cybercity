// =============================================================================
// _tod_upgrade_ui.csc — clientfield registration twin (client VM).
//
// A clientuimodel field needs BOTH VMs to register it or the model never
// exists client-side (map 1 docs/19: no callback handler needed — the engine
// auto-pipes the value into the LUI model the widgets subscribe to).
// MUST match _tod_upgrade_ui.gsc EXACTLY: scope/name/version/bits/type, same
// order — a mismatch corrupts the bit layout and hangs load.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace tod_upgrade_ui;

REGISTER_SYSTEM( "tod_upgrade_ui", &__init__, undefined )

function __init__()
{
	clientfield::register( "clientuimodel", "todUpgShow",  VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	// 6-bit domain ids since 2026-08-22 (CLASS TIERS, docs/25 §8) — paid for by
	// todMagBonus 7 -> 1 below. Widths MUST match the .gsc twin line for line.
	clientfield::register( "clientuimodel", "todUpgAD",    VERSION_SHIP, 6, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "todUpgAR",    VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "todUpgAL",    VERSION_SHIP, 4, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "todUpgBD",    VERSION_SHIP, 6, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "todUpgBR",    VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "todUpgBL",    VERSION_SHIP, 4, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "todUpgLuck",  VERSION_SHIP, 4, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "todUpgFocus", VERSION_SHIP, 3, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "todUpgTime",  VERSION_SHIP, 4, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "todMagBonus", VERSION_SHIP, 1, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );   // dead field, 7 -> 1 (2026-08-22)
	// 13 -> 14 bits in LOCKSTEP with the .gsc register (v13.9 reduced/red bit —
	// mismatched widths here are the boot-fatal clientfield desync).
	clientfield::register( "clientuimodel", "todDmgNum",  VERSION_SHIP, 15, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );   // 14 -> 15 (2026-09-09): scale bit, LOCKSTEP with the GSC
	// THE FINALE ROAD BANNER (v10.26) — mirrors the server registration in
	// _tod_upgrade_ui.gsc bit for bit. A mismatch here is a silent desync, not
	// an error: the field simply never arrives.
	// SHARED hold bar + the class draft's Show (focus/time ride todUpgFocus/
	// todUpgTime — see the .gsc twin's BUDGET note: 57 custom bits total
	// since the 2026-08-22 trim, 61 = the proven ceiling; the pool overflow
	// class aborts map load to the lobby).
	clientfield::register( "clientuimodel", "todUpgHold", VERSION_SHIP, 4, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "clientuimodel", "todClsShow",  VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	// APPENDED LAST, matching _tod_upgrade_ui.gsc. Order does NOT affect the bit
	// layout — clientfields are keyed by NAME, and the pool total is 58 of the 61
	// proven bits either way — but the two files claim to be twins, so they read
	// as twins.
	clientfield::register( "clientuimodel", "todFinaleWarn", VERSION_SHIP, 1, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	// RAMPAGE INDUCER (v14.20) — mirrors the .gsc twin BIT FOR BIT and in the
	// SAME ORDER. A width or order mismatch here is not an error, it is a
	// silent desync: the field simply never arrives. Appended last in both VMs.
	clientfield::register( "clientuimodel", "todRampage",  VERSION_SHIP, 1, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	// v17.93 FULL STEAM wind, player-only — LOCKSTEP with the .gsc twin (see there).
	clientfield::register( "toplayer", "todSteamWind", VERSION_SHIP, 1, "int", &steam_wind_cb, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
}

// v17.93 FULL STEAM's wind, on THIS machine only. self = the player whose
// field changed — NOT necessarily the local player: the host's client VM sees
// every player's toplayer fields, and a spectator sees the spectated player's
// (the Death Perception outline leak of 2026-08-30, _tod_perk_electric_cherry
// .csc). The local guard is what makes "player-only" true.
// CLIENT-SIDE StopLoopSound TAKES THE HANDLE PlayLoopSound RETURNED (memory
// loop-sound-stop-by-handle; stock _hive_gun.csc:120) — never a fade time.
// The alias is 2D + LOOPING (sound/aliases/tod_ui.csv), so played here it is
// non-positional for the owner and inaudible to everyone else.
function steam_wind_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( self != GetLocalPlayer( localClientNum ) )
		return;
	if ( isdefined( self.tod_steam_wind_snd ) )
	{
		self StopLoopSound( self.tod_steam_wind_snd );
		self.tod_steam_wind_snd = undefined;
	}
	if ( isdefined( newVal ) && newVal > 0 )
		self.tod_steam_wind_snd = self PlayLoopSound( "tod_full_steam_wind" );   // LOCKSTEP: TOD_LMGS_SFX in _tod_upgrades.gsc
}
