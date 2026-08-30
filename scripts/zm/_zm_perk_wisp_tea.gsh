// WISP TEA SETTINGS (vendored from WetEgg's SATPerksCode pack, 2026-08-30 —
// tower deltas: the localized-hint + machine-anim defines are GONE, see the
// .gsc header for why; everything else is the pack's own tuning).

#define WISP_TEA_PERK_COST					            300   // user 2026-08-30 ("It should be 300"; pack default 4000). LOCKSTEP: AetheriumPerks.lua's WISP TEA cost row shows this number on the card.

#define WISP_TEA_PERK_BOTTLE_WEAPON			            "sat_perk_can_wisp_tea"

#define WISP_TEA_MACHINE_DISABLED_MODEL		            "sat_zm_machine_w_mod_fxanim"
#define WISP_TEA_MACHINE_ACTIVE_MODEL			        "sat_zm_machine_w_mod_fxanim_on"
#define WISP_TEA_RADIANT_MACHINE_NAME			        "sat_vending_wisp_tea"

#define WISP_TEA_WISP_MODEL                             "vfx_sat_fxp_zm_ai_wisp_tea_mask_airflow_01"

#define WISP_TEA_MACHINE_LIGHT_FX			            "_wetegg/sat/perks/fx_wisp_tea_light"
#define WISP_TEA_MACHINE_LIGHT_FX_NAME			        "sat_wisp_tea_light"

#define WISP_TEA_SPECIALTY                              "specialty_nomotionsensor"

#define WISP_TEA_JINGLE                                 "mus_perk_wisptea_jingle"
#define WISP_TEA_STING                                  "mus_perk_wisptea_stinger"

#define WISP_TEA_CLIENTFIELD         			        "hudItems.perks.wisp_tea"

#define WISP_TEA_WISP_DURATION                          30
#define WISP_TEA_WISP_MOVE_SPEED                        225
#define WISP_TEA_WISP_MAX_DISTANCE_TO_PLAYER            400

#define WISP_TEA_COOLDOWN_TIME                          120 //BO7 time is 120 (2 minutes)
#define WISP_TEA_WISP_SPAWN_CHANCE                      20 //One in x chance of activating when hitting a zombie
#define WISP_TEA_DAMAGE_SEGMENTS                        3 //How many hits for wisp to kill
#define WISP_TEA_NON_ZOMBIE_DAMAGE                      1000 //Damage to deal to enemies that aren't base zombies

#define WISP_TEA_WISP_FX    			                "_wetegg/sat/perks/fx_wisp_tea_wisp"
#define WISP_TEA_WISP_TRAIL_FX  			            "_wetegg/sat/perks/fx_wisp_tea_wisp_trail"
