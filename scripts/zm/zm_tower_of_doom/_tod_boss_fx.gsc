// =============================================================================
// _tod_boss_fx.gsc — boss client-FX pulses, server half. NO healthbars (user
// 2026-08-19: "They wont have healthbars or anything").
//
// Ported from map 1's _acc_boss_nameplate minus every bar/LUI piece — what
// survives is the load-bearing FX plumbing: server-side PlayFX/PlaySound on
// ACTORS does not render (map 1 lesson, perk-glow precedent), so each Rogue
// Protector attack pulses a 2-bit actor clientfield counter and the .csc twin
// plays the muzzle flash / zap arc / rocket boom CLIENT-side. todBossName
// exists only to trigger the .csc SetDrawName("") stomp (the HB21 pack names
// its robot "Civil Protector" overhead; belt-and-braces with the vendored
// name strip in zm_zod_robot.csc).
//
// CF LOCKSTEP: the four registrations here MUST match _tod_boss_fx.csc
// exactly (scope/name/version/bits/type, same order). APPEND ONLY.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace tod_boss_fx;

REGISTER_SYSTEM( "tod_boss_fx", &__init__, undefined )

function __init__()
{
	clientfield::register( "actor", "todBossName",  VERSION_SHIP, 3, "int" );
	clientfield::register( "actor", "todBossShot",  VERSION_SHIP, 2, "int" );
	clientfield::register( "actor", "todBossZap",   VERSION_SHIP, 2, "int" );
	clientfield::register( "actor", "todBossMahem", VERSION_SHIP, 2, "int" );
}

// PUBLIC — mark a freshly spawned boss: fires the .csc name stomp. idx is a
// cosmetic type id (1 = protector, 2 = panzer) in case a client consumer ever
// wants it; any nonzero value triggers the stomp.
function attach( boss, idx )
{
	if ( !isdefined( boss ) )
		return;
	boss clientfield::set( "todBossName", idx );
}

// PUBLIC — one Rogue Protector GUN shot (energy muzzle flash + RW1 report).
// 2-bit wrap counter: consecutive values always differ, so every shot fires
// the client callback.
function shot_pulse( boss )
{
	pulse( boss, "todBossShot" );
}

// PUBLIC — one close-range ZAP burst (electric arc + spark report).
function zap_pulse( boss )
{
	pulse( boss, "todBossZap" );
}

// PUBLIC — the 5th-shot ROCKET (muzzle flash + mahem explosion report).
function mahem_pulse( boss )
{
	pulse( boss, "todBossMahem" );
}

function pulse( boss, field )
{
	if ( !isdefined( boss ) )
		return;
	if ( !isdefined( boss.tod_fx_val ) )
		boss.tod_fx_val = [];
	if ( !isdefined( boss.tod_fx_val[ field ] ) )
		boss.tod_fx_val[ field ] = 0;
	boss.tod_fx_val[ field ] = ( boss.tod_fx_val[ field ] + 1 ) % 4;
	boss clientfield::set( field, boss.tod_fx_val[ field ] );
}
