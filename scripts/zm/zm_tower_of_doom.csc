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
#using scripts\zm\zm_tower_of_doom\_tod_perk_electric_cherry;   // v13.19 — DEATH PERCEPTION outline callbacks (lineage name, see its header)
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;
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

function main()
{
	zm_usermap::main();

	include_weapons();

	// Upgrade-choice LUI (the 4-file contract: GSC #precache lui_menu +
	// OpenLUIMenu, this LuiLoad, the zone rawfile line, the .lua itself).
	LuiLoad( "ui.uieditor.menus.hud.tod_upgrade" );
	// Class-draft LUI (same contract; GSC half = _tod_class_select.gsc)
	LuiLoad( "ui.uieditor.menus.hud.tod_class_select" );

	util::waitforclient( 0 );
}

function include_weapons()
{
	zm_weapons::load_weapon_spec_from_table( "gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1 );
}
