// =============================================================================
// _tod_boss_fx.csc — boss client-FX pulses, client half (LOCKSTEP twin of
// _tod_boss_fx.gsc — same fields, same order, same bits; APPEND ONLY).
//
// Callbacks run with self = the boss actor. bInitialSnap is guarded so a
// late-joining client never fires a phantom pulse (map 1's recipe verbatim).
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "client_fx", "_owens_effects/t9_semiauto_cosplay/fx_muz_energy_shotgun_3p" );  // GUN muzzle flash
#precache( "client_fx", "electric/fx_elec_sparks_burst_xsm_omni_blue_os" );               // ZAP electric arc

#namespace tod_boss_fx;

REGISTER_SYSTEM( "tod_boss_fx", &__init__, undefined )

function __init__()
{
	clientfield::register( "actor", "todBossName",  VERSION_SHIP, 3, "int", &name_cb,  !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "todBossShot",  VERSION_SHIP, 2, "int", &shot_cb,  !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "todBossZap",   VERSION_SHIP, 2, "int", &zap_cb,   !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "todBossMahem", VERSION_SHIP, 2, "int", &mahem_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

// Floating-name STOMP: the HB21 archetype may set "Civil Protector" over the
// robot's head at spawn — render the empty string the moment the server marks
// the boss. (The vendored zm_zod_robot.csc name-set is also commented out;
// this covers any path that re-sets it.)
function name_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self SetDrawName( "" );
}

// GUN shot: energy muzzle flash on the weapon hand + the RW1 NPC report,
// positional at the boss.
function shot_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( IS_TRUE( bInitialSnap ) )
		return;
	PlayFxOnTag( localClientNum, "_owens_effects/t9_semiauto_cosplay/fx_muz_energy_shotgun_3p", self, "tag_weapon_right" );
	self PlaySound( localClientNum, "wpn_s1_rw1_shot_npc" );
}

// ZAP burst: a small blue arc at the gun hand (a big burst on tag_origin reads
// as a self-detonation — map 1 lesson) + his spark report.
function zap_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( IS_TRUE( bInitialSnap ) )
		return;
	PlayFxOnTag( localClientNum, "electric/fx_elec_sparks_burst_xsm_omni_blue_os", self, "tag_weapon_right" );
	self PlaySound( localClientNum, "fly_bot_head_sparks_burst" );
}

// ROCKET: muzzle flash + the mahem explosion report (the projectile itself
// carries its own trail/explosion FX — it is a real s1_mahem).
function mahem_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( IS_TRUE( bInitialSnap ) )
		return;
	PlayFxOnTag( localClientNum, "_owens_effects/t9_semiauto_cosplay/fx_muz_energy_shotgun_3p", self, "tag_weapon_right" );
	self PlaySound( localClientNum, "wpn_s1_mahem_explosion_npc" );
}
