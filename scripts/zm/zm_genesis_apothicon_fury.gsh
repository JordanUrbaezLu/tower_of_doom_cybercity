#define APOTHICAN_FURY_DEBUG 												0 // DEBUG FOR IMMEDIATE TESTING, FURYS WILL SPAWN EVERY ROUND AFTER ROUND 1

// [acc] 0 = NO special fury rounds - _acc_fury.gsc drives all spawning (trench elite, user 2026-07-03)
#define APOTHICAN_FURY_USE_SPECIAL_FURY_ROUNDS 			0 // IF YOU WANT FURY "ROUNDS"
// [acc] SWAPPED off zombie/fx_meatball_impact_ground_tell_zod_zmb - pack references it but does NOT
// ship it (dangling fx = fatal, see memory silent-weapon-conversion-kill-dangling-refs). The Civil
// Protector pack ships this equivalent ground-tell ring (already zone-listed).
#define APOTHICON_FURY_GROUND_TELL_FX 							"zombie/fx_robot_helper_ground_tell_zod_zmb"
#define APOTHICON_FURY_SPAWN_IN_FX 									"dlc4/genesis/fx_apothicon_fury_spawn_in"
#define APOTHICON_FURY_SPAWN_IN_EXP_FX 							"dlc4/genesis/fx_apothicon_fury_spawn_in_exp"

#define APOTHICAN_FURY_PER_PLAYER			 							4 // NUMBER OF FURYS THAT WILL SPAWN AT ONE TIME PER PLAYER
#define APOTHICAN_FURY_PER_ROUND			 							8 // NUMBER OF FURYS THAT WILL SPAWN_PER_ROUND ( TIMES BY NUMBER OF PLAYERS )
#define APOTHICAN_FURY_HEALTH_MAX_START 							1.2 // MAX HEALTH MULTIPLIER ROUND 0 - 20
#define APOTHICAN_FURY_HEALTH_MAX_2 								1.5 // MAX HEALTH MULTIPLIER ROUND 20 - 50
#define APOTHICAN_FURY_HEALTH_MAX_3 								1.7 // HEALTH MULTIPLIER AFTER ROUND 50
#define APOTHICAN_FURY_HEALTH_CAP 									2147483647
#define APOTHICAN_FURY_END_POWERUP 									"full_ammo" // POWERUP LAST FURY WILL DROP
