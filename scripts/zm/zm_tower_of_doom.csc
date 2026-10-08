// =============================================================================
// zm_tower_of_doom.csc — client entry script (stock template structure).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\audio_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_load;
#using scripts\zm\_zm_weapons;

//Perks
#using scripts\zm\_zm_pack_a_punch;
#using scripts\zm\zm_cwpap;   // v13.6 — ALXS CW/BO6 PaP client half (crown machine)
#using scripts\zm\_zm_perk_additionalprimaryweapon;
#using scripts\zm\_zm_perk_doubletap2;
// [tod] v14.16 — Wisp Tea client half, in Deadshot's old slot — MUST match
// the entry .gsc #using (clientfield lockstep).
#using scripts\zm\_zm_perk_wisp_tea;
// [tod] Client half of the stock cherry pipeline (_tod_perk_electric_cherry
// rides its tesla FX) — MUST match the entry .gsc #using or the clientfield
// registration mismatches at load (map 1 pattern).
#using scripts\zm\_zm_perk_electric_cherry;
#using scripts\zm\_zm_perk_juggernaut;
#using scripts\zm\_zm_perk_quick_revive;
#using scripts\zm\_zm_perk_sleight_of_hand;
#using scripts\zm\_zm_perk_staminup;
// [tod] Widow's Wine client half — MUST match the entry .gsc #using.
#using scripts\zm\_zm_perk_widows_wine;

//Powerups
#using scripts\zm\_zm_powerup_double_points;
#using scripts\zm\_zm_powerup_carpenter;
#using scripts\zm\_zm_powerup_fire_sale;
#using scripts\zm\_zm_powerup_free_perk;
#using scripts\zm\_zm_powerup_full_ammo;
#using scripts\zm\_zm_powerup_insta_kill;
#using scripts\zm\_zm_powerup_nuke;
// [tod] Logical's Powerups + our custom drops — MUST match the entry .gsc
// #usings (clientfield lockstep: timewarp/infiniteammo/powerup_admin_gun)
#using scripts\zm\logical\powerups\_zm_powerup_timewarp;
#using scripts\zm\logical\powerups\_zm_powerup_infiniteammo;
#using scripts\zm\zm_tower_of_doom\_tod_powerups;
// [tod] Gift of Death (Xmas Gun) client half — clientfield lockstep with the
// entry .gsc (xmas_gun_proj_stop + zm_xmas_frz)
#using scripts\zm\zm_weap_xmas_gun;

//Traps
#using scripts\zm\_zm_trap_electric;

// Aetherium HUD (Owen-C137 kit — per its README, ABOVE zm_usermap)
#using scripts\zm\_zm_aetherium_hud;

#using scripts\zm\zm_usermap;

// [tod] client modules (clientfield lockstep with the .gsc twins)
#using scripts\zm\zm_tower_of_doom\_tod_perk_lights;
#using scripts\zm\zm_tower_of_doom\_tod_hoop;   // v19.18d — the bat hoop's client flight log (actor field lockstep with _tod_corpse_cleanup.gsc)
#using scripts\zm\zm_tower_of_doom\_tod_perk_electric_cherry;   // v13.19 — DEATH PERCEPTION outline callbacks (lineage name, see its header)
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;
#using scripts\zm\zm_tower_of_doom\_tod_mage_elements;   // v18.32 — the staff glow (toplayer field lockstep with the .gsc)
#using scripts\zm\zm_tower_of_doom\_tod_rampage;   // 2026-10-01 — Rampage on the column's strips (reads the todRampage HUD value; no field of its own)
// Boss packs (REGISTER_SYSTEM self-init — the #using alone wires them; MUST
// be present whenever the .gsc halves are in the fastfile: clientfield
// lockstep) + the tod boss FX pulse module
#using scripts\zm\mechz_spiki;
#using scripts\zm\zm_zod_robot;
// THE REAVER's pack (HB21 Apothicon Fury). Same REGISTER_SYSTEM_EX contract:
// this #using is what registers the client half of the
// "apothicon_fury_spawn_meteor" clientfield — omit it and server/client
// clientfield indices desync.
#using scripts\zm\zm_genesis_apothicon_fury;
#using scripts\zm\zm_tower_of_doom\_tod_boss_fx;

// v19.76 — the thinned rising-dirt effects (tools/gen_tod_riser_fx.py; set in main)
#precache( "client_fx", "tod/zombie/fx_tod_rise_burst" );
#precache( "client_fx", "tod/zombie/fx_tod_rise_billow" );
#precache( "client_fx", "tod/zombie/fx_tod_rise_dust" );

function main()
{
	zm_usermap::main();

	// v19.76 — THE RISING DIRT, THINNED (lead tester Nikolai, Oct 2026: "fast-
	// spawning zombies create a cumulative smoke effect that completely obscures
	// the screen"). Stock's _zm.csc init_riser_fx assigned these inside the call
	// above; every rising zombie then plays rise_burst, rise_billow and rise_dust
	// every 0.3 s for up to 5.5 s (zombie_rise_fx). Same files the server side
	// uses (zm_tower_of_doom.gsc) - smoke and dust thinned, rock and debris kept.
	level._effect[ "rise_burst" ]  = "tod/zombie/fx_tod_rise_burst";
	level._effect[ "rise_billow" ] = "tod/zombie/fx_tod_rise_billow";
	level._effect[ "rise_dust" ]   = "tod/zombie/fx_tod_rise_dust";

	include_weapons();

	// Upgrade-choice LUI (the 4-file contract: GSC #precache lui_menu +
	// OpenLUIMenu, this LuiLoad, the zone rawfile line, the .lua itself).
	LuiLoad( "ui.uieditor.menus.hud.tod_upgrade" );
	// Class-draft LUI (same contract; GSC half = _tod_class_select.gsc)
	LuiLoad( "ui.uieditor.menus.hud.tod_class_select" );

	util::waitforclient( 0 );

	// ---------------------------------------------------------------------
	// NO OVERRIDE OF character_fire_death_torso HERE — AND THAT IS THE POINT
	// (v16.91, reverting v16.90's override; user: "on this map when i get a
	// nuke i can see the zombies are burned").
	//
	// v16.90 pointed both fire handles at fire/fx_fire_ai_human_torso_loop on
	// the theory that stock's "zombie/fx_fire_torso_zmb" could never draw,
	// because THAT FILE IN THE MOD TOOLS is a 5,092-byte placeholder whose one
	// material is `gfx_debug_missing_fx`. The theory was wrong, and the reason
	// is worth keeping:
	//
	//   A STUB IN share\raw IS A MISSING *SOURCE*, NOT A MISSING *ASSET*.
	//   Treyarch shipped placeholder .efx sources for effects they did not
	//   release, but the real COMPILED effects are in the base-game fastfiles.
	//   An effect your map never zones resolves from those at runtime and
	//   renders perfectly — the nuke burn does, and always has here.
	//   You only inherit the placeholder when YOUR zone packs it, because then
	//   your fastfile supplies the empty version. `zombie/fx_fire_torso_zmb`
	//   is NOT in this map's zone, which is exactly why the nuke burns.
	//
	// So the nuke's fire needs nothing from us. Overriding these handles would
	// have quietly replaced the nuke's own look map-wide with a different fire,
	// which is the opposite of what was asked for.
	//
	// v18.12 — TRAILBLAZER NO LONGER RIDES THIS LANE. It used to increment the
	// same `zm_nuked` field and inherit the nuke fire for free; it now sets
	// `arch_actor_fire_fx` = 2 (BURN_CORPSE) instead, because a trail kill
	// reading as "somebody pulled a Nuke" was the whole complaint. That lane is
	// registered by stock's own archetype_shared autoexec and carries its own
	// FX and burn loop, so it needs nothing from this file either — and, like
	// the nuke's, its effects must NOT be zoned here or we would pack the
	// placeholder over the working stock ones.
	//
	// Do not "fix" a blank effect by swapping the handle until you have checked
	// whether your zone is the thing packing the placeholder over it.
	// ---------------------------------------------------------------------
}

function include_weapons()
{
	zm_weapons::load_weapon_spec_from_table( "gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1 );
}
