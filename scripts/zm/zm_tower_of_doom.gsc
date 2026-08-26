// =============================================================================
// zm_tower_of_doom.gsc — server entry script.
//
// Structure = the stock usermap template + the [tod] hooks. Conventions and
// stock-API traps inherited from zm_abandoned_cyber_city (see CLAUDE.md +
// docs/BO3_MAPMAKING_KB.md — read those before touching stock interfaces).
// =============================================================================

#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\compass;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_utility.gsh;

#using scripts\zm\_load;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;

#using scripts\shared\ai\zombie_utility;

//Perks
#using scripts\zm\_zm_pack_a_punch;
#using scripts\zm\_zm_pack_a_punch_util;
#using scripts\zm\_zm_perk_additionalprimaryweapon;
#using scripts\zm\_zm_perk_doubletap2;
#using scripts\zm\_zm_perk_deadshot;
// [tod] Stock cherry pipeline — REQUIRED by _tod_perk_electric_cherry (it calls
// the stock tesla-FX functions, which only render because this init registers
// the pipeline + its clientfields; map 1 had it via PhD's hijack). Matching
// #using in the entry .csc REQUIRED (clientfield lockstep).
#using scripts\zm\_zm_perk_electric_cherry;
#using scripts\zm\_zm_perk_juggernaut;
#using scripts\zm\_zm_perk_quick_revive;
#using scripts\zm\_zm_perk_sleight_of_hand;
#using scripts\zm\_zm_perk_staminup;
// [tod] Widow's Wine — pure stock module (machine assets supplied by the
// module; map 1 needed no zone lines). Matching #using in the entry .csc.
#using scripts\zm\_zm_perk_widows_wine;

//Powerups
#using scripts\zm\_zm_powerup_double_points;
#using scripts\zm\_zm_powerup_carpenter;
#using scripts\zm\_zm_powerup_fire_sale;
#using scripts\zm\_zm_powerup_free_perk;
#using scripts\zm\_zm_powerup_full_ammo;
#using scripts\zm\_zm_powerup_insta_kill;
#using scripts\zm\_zm_powerup_nuke;
// (the stock Death Machine drop — _zm_powerup_weapon_minigun — rides in
// transitively via zm_usermap on BOTH sides; its own gate governs drops)
// [tod] Logical's Powerups (vendored 2026-08-20; REGISTER_SYSTEM self-init —
// matching #usings in the entry .csc; clientfield lockstep)
#using scripts\zm\logical\powerups\_zm_powerup_timewarp;
#using scripts\zm\logical\powerups\_zm_powerup_infiniteammo;
// [tod] our drops: free Pack-a-Punch + the Death Machine grant override
#using scripts\zm\zm_tower_of_doom\_tod_powerups;
// [tod] Gift of Death (Xmas Gun) — REGISTER_SYSTEM_EX self-init; #using arms
// it. MUST also be in the entry .csc (clientfield lockstep: xmas_gun_proj_stop
// + zm_xmas_frz). Its own module #usings cheese_man\zombie_slow_util.
#using scripts\zm\zm_weap_xmas_gun;

//Traps
#using scripts\zm\_zm_trap_electric;

// Aetherium HUD (Owen-C137 kit — per its README, ABOVE zm_usermap)
#using scripts\zm\_zm_aetherium_hud;

#using scripts\zm\zm_usermap;

// [tod] custom modules
#using scripts\zm\zm_tower_of_doom\_tod_main;
#using scripts\zm\zm_tower_of_doom\_tod_corpse_cleanup;
#using scripts\zm\zm_tower_of_doom\_tod_endless_rounds;
#using scripts\zm\zm_tower_of_doom\_tod_doors;
#using scripts\zm\zm_tower_of_doom\_tod_zombie_speed;
#using scripts\zm\zm_tower_of_doom\_tod_perk_lights;
// Bosses: Panzer + Rogue Protector (vendored packs ride in transitively via
// _tod_bosses' own #usings; kills grant event luck for the upgrade rolls)
#using scripts\zm\zm_tower_of_doom\_tod_bosses;
// THE REAVER — elite unlocked by the LAP 20 breather door (docs/28). The HB21
// Apothicon Fury pack rides in transitively via _tod_reaver's own #using of
// zm_genesis_apothicon_fury (REGISTER_SYSTEM_EX autoexec); the matching #using
// in the entry .csc is REQUIRED or the "apothicon_fury_spawn_meteor"
// clientfield mismatches between server and client.
#using scripts\zm\zm_tower_of_doom\_tod_reaver;
// HELLHOUNDS — elite #3, unlocked by the LAP 30 breather door: the stock
// zm_factory dog archetype driven as a tower elite. NO entry-.csc counterpart,
// DELIBERATELY: _zm_ai_dogs.csc already rides in via zm_usermap.csc and
// registers the "dog_fx" clientfield, so both halves are ALREADY in lockstep.
// Adding a #using on this side only would BREAK it. level.dog_rounds_allowed
// stays 0 — this is a pack elite, never a dog round.
#using scripts\zm\zm_tower_of_doom\_tod_hellhounds;
// Game-start class draft (each player picks a class before round 1; 30s cap)
#using scripts\zm\zm_tower_of_doom\_tod_class_select;
// [tod] Electric Cherry — the map-1 FINISHED custom perk on the unused
// specialty_combat_efficiency (real West-pack vending model). REGISTER_SYSTEM
// autoexec registers it at load — this #using is what pulls it into the
// compile so that runs (no init call in main() needed; map 1 precedent).
#using scripts\zm\zm_tower_of_doom\_tod_perk_electric_cherry;
#using scripts\zm\zm_tower_of_doom\_tod_perk_phd;   // PhD Flopper — replaces Mule Kick on the crown
// [tod] Perk scatter (random opening layout + post-Panzer reshuffle) + the
// LUCK BAR (0-100%, spends on upgrade rolls)
#using scripts\zm\zm_tower_of_doom\_tod_perk_scatter;
#using scripts\zm\zm_tower_of_doom\_tod_luck;
// [tod] Tower gauge: publishes the player's floor + the lowest live boss's
// floor to the HUD (int-only LuiNotifyEvent lane — costs no clientuimodel bits)
#using scripts\zm\zm_tower_of_doom\_tod_gauge;
// [tod] THE ENDING (v9): the Crown's buyable uplink -> hold-out -> extraction
// pad -> custom end screen. Geometry anchors ride in from the GENERATED
// _tod_crown_data (its own #using inside the module).
#using scripts\zm\zm_tower_of_doom\_tod_finale;
#using scripts\zm\zm_tower_of_doom\_tod_gameover;
#using scripts\zm\zm_tower_of_doom\_tod_teleport;

// Perk machine hint strings (cost substitution variants — the string+cost pair
// must be precached or the buy hint shows blank; map 1 pattern).
#precache("triggerstring", "ZOMBIE_PERK_WIDOWSWINE", "4000");

//*****************************************************************************
// MAIN
//*****************************************************************************

function main()
{
	// DEV MODE — ONE compile-time flag, same doctrine as map 1 (its CLAUDE.md
	// "Dev/test mode"). Arm a test session by flipping to true + rebuild; the
	// ship state is false. NEVER a dvar, NEVER a launch flag.
	tod_resolve_dev_flags();

	// VERIFIED on map 1: must be set BEFORE zm_usermap::main() — the hook is
	// consumed synchronously inside the bootstrap (DEFAULT() only assigns when
	// undefined, so pre-setting wins).
	level._zombie_custom_add_weapons = &custom_add_weapons;

	// SAME WINDOW, SAME REASON. PhD Flopper rides the stock electric-cherry
	// pipeline, and stock's machine setup for that specialty is a verbatim copy
	// of STAMIN-UP's (both set targetname "vending_marathon" — a Treyarch
	// copy-paste). Our replacement has to be in place before
	// `zm_perks::init()` runs `perk_machine_spawn_init()`, which happens inside
	// zm_usermap::main() -> _zm.gsc. After that the machines exist and
	// overwriting the pointer is a silent no-op. Every REGISTER_SYSTEM __init__
	// has already run by the time we get here, so the perk pipeline exists.
	tod_perk_phd::install_machine_kvps();

	// No hellhound rounds — the endless tower flow stays pure zombie waves.
	// (Stock DEFAULTs dog_rounds_allowed to 1 inside zm_usermap::main; presetting
	// 0 makes the tracker never start. Proven on map 1.)
	level.dog_rounds_allowed = 0;

	zm_usermap::main();

	// NO PERK LIMIT (playtest 2026-08-23: "There should be no perk limit").
	// Stock _zm_perks::init hardcodes 4; it has run by this point (the system
	// inits fire inside zm_usermap::main), so setting it here wins. 9 = every
	// perk this map sells (the 8 scattered machines + roof Mule Kick), i.e.
	// effectively unlimited without disturbing whatever stock arithmetic
	// reads the field.
	level.perk_purchase_limit = 9;

	// [tod 2026-08-22] STOCK ANTI-CHEAT CONFISCATION — OFF. THIS MAP OWNS THE
	// PLAYER'S INVENTORY.
	// Stock `_zm.gsc` threads player_too_many_weapons_monitor on every player:
	// every 3s it counts primaries that are is_weapon_included ||
	// is_weapon_upgraded and, above the 2-weapon limit, runs the takeaway
	// sequence — a zombie laugh, then SwitchToWeapon + TakeWeapon on EVERY
	// primary, a points penalty, and a fresh start pistol.
	// Our twin/tier/PaP swaps are GIVE-before-TAKE by design (map 1's proven
	// order), so a player legitimately holds a transient THIRD primary
	// (pistol + base form + new form) for up to ~1s whenever the immediate
	// switch is eaten (mid-sprint / mid-raise / mid-reload / ADS) — and an
	// upgrade pick unfreezes weapons one line before the swap, so mid-raise is
	// the common case. If the 3s tick lands in that window the player loses
	// EVERYTHING and is left on the pistol, with no way back (the class gun is
	// only ever given at spawn).
	// This was inert until v9.14: without the weapons-table stringtable zone
	// line, level.zombie_weapons had no class-gun rows, so the monitor's list
	// was always empty. Zoning the CSV (the roof-PaP fix) armed it.
	// LIVE REPORT 2026-08-22: "I randomly lost my enfield ... I kept hearing
	// the teddy bear" = level.zmb_laugh_alias, played twice by the takeaway.
	level.player_too_many_weapons_monitor = false;

	// [tod] Custom per-perk costs — runs AFTER zm_usermap::main() populated
	// level._custom_perks (stock widows registered in the bootstrap; the cherry
	// registered via its REGISTER_SYSTEM autoexec), BEFORE the first tick /
	// first machine read. Map 1's set_perk_costs pattern.
	tod_set_perk_costs();

	// [tod] Gift of Death: redirect the Death Machine drop to the Xmas Gun +
	// install its fixed-shots damage. AFTER zm_usermap::main() (stock minigun
	// seeded its grant weapon) and BEFORE tod_main::init() threads the upgrade
	// damage callback, so ours registers first in the actor-damage chain.
	tod_powerups::install_gift_of_death();

	// Setup the level's zombie zone volumes (graph wired in the init func below)
	level.zones = [];
	level.zone_manager_init_func = &usermap_test_zone_init;
	init_zones[ 0 ] = "base_zone";
	level thread zm_zonemgr::manage_zones( init_zones );

	level.pathdist_type = PATHDIST_ORIGINAL;

	// Starting loadout / economy
	level.start_weapon = GetWeapon( "pistol_standard" );
	level.default_laststandpistol = GetWeapon( "pistol_standard_upgraded" );
	level.default_solo_laststandpistol = GetWeapon( "pistol_standard_upgraded" );
	level.player_starting_points = 500;

	// THE TWIST — endless rounds: the next round starts the moment the last
	// zombie of the current round SPAWNS. No between-round pause, ever.
	tod_endless_rounds::init();

	// CORPSE CLEANUP + THE CONCURRENCY CAPS (v10.26). Owns level.zombie_ai_limit
	// (45) and level.zombie_actor_limit (60) as well as the body delete, because
	// the raised cap is only safe BECAUSE bodies are deleted — corpses count
	// toward the actor limit and would otherwise throttle the horde. Init'd here,
	// ahead of the boss and round modules, so the caps are live before anything
	// can spawn.
	tod_corpse_cleanup::init();

	// Buyable stairwell doors (map triggers are dead for generated maps —
	// script-spawned buy triggers drive them; the map 1 recipe).
	level thread tod_doors::init();

	// Remaining [tod] systems (banner, dev sandbox)
	level thread tod_main::init();

	// Bosses (PANZER every 5th round with his own music; ROGUE PROTECTOR
	// wave every 3rd round, wave size = round x 2; kills pay event luck +
	// points to everyone)
	level thread tod_bosses::init();

	// THE REAVER: dormant until the LAP 20 breather door is bought, then a
	// bamfing Apothicon elite on that round and every 4th after (dev: every
	// 2nd). Concurrency roof 3.
	level thread tod_reaver::init();

	// HELLHOUNDS: dormant until the LAP 30 breather door is bought, then a PACK
	// on that round and every 3rd after (dev: every 2nd). Roof 4, and they only
	// ever fill SPARE elite capacity (combined roof 9) so a pack can never be
	// the thing that starves the horde at stock's 31-actor gate.
	level thread tod_hellhounds::init();

	// Class draft: world holds after the blackscreen until every player has
	// picked (or 30s -> random). Round 1 spawning waits on the pause flag.
	level thread tod_class_select::init();

	// Perk scatter: 6 perks land on random pads at load, reshuffle (with the
	// drop-in animation) on the round after each Panzer.
	level thread tod_perk_scatter::init();

	// The luck bar (kills/headshots/revives/doors/boss last-hits -> better
	// upgrade rolls; resets to 0 after each upgrade event).
	level thread tod_luck::init();

	// The tower gauge feed (floor + boss floor -> the HUD indicator).
	level thread tod_gauge::init();

	// THE ENDING (v9): the Crown's uplink, pylons, extraction pad and the
	// "YOU ESCAPED THE TOWER" end screen. Its props + triggers spawn after
	// the blackscreen; nothing here gates on it.
	level thread tod_finale::init();

	// GAME-OVER DECISION MENU (v9.24): on end_game (wipe OR the finale's win)
	// stock's 15s auto-exit is parked and the pause menu force-opens in its
	// two-entry RESTART MAP / END GAME mode — no lobby round-trip to retry.
	level thread tod_gameover::init();

	// BREATHER TELEPORTERS (v9.37): a Der Eisendrache pad on every breather,
	// one-way back to the base's west ring, 60s per-pad cooldown, riders =
	// whoever is on the pad when it fires.
	level thread tod_teleport::init();
}

function usermap_test_zone_init()
{
	// Spiral zone graph: base arena -> lap 1 -> ... -> lap 25 -> rooftop, one
	// door flag per lap start (+ the rooftop flight). MUST match the
	// generator's LAPS constant (tools/gen_tower_map.js).
	laps = 50;   // v8 (user 2026-08-21): tower DOUBLED — must match gen_tower_map.js LAPS

	zm_zonemgr::add_adjacent_zone( "base_zone", "lap1_zone", "enter_lap1" );
	for ( i = 1; i < laps; i++ )
	{
		zm_zonemgr::add_adjacent_zone( "lap" + i + "_zone", "lap" + ( i + 1 ) + "_zone", "enter_lap" + ( i + 1 ) );
	}
	zm_zonemgr::add_adjacent_zone( "lap" + laps + "_zone", "roof_zone", "enter_roof" );

	// THE TELEPORT BAY (v10.25) — a gated annex hanging off the base arena, not
	// a rung of the spiral. It is a zone of its own purely so its two risers
	// stay asleep behind the door; base_zone is live from round 1, so risers in
	// a sealed room would burn actor slots on zombies nobody could reach. The
	// flag is the same one the bay door sets and the same one both directions of
	// the teleport network check (_tod_teleport TOD_TP_BAY_FLAG).
	zm_zonemgr::add_adjacent_zone( "base_zone", "tpbay_zone", "enter_tpbay" );
}

function custom_add_weapons()
{
	zm_weapons::load_weapon_spec_from_table( "gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1 );
}

// [tod] Custom per-perk costs (map 1's set_perk_costs pattern verbatim). The
// perk cost is read from level._custom_perks[specialty].cost; set it before
// the first purchase. Only the two newly wired perks are priced here — the
// already-wired perks (jugg/sleight/quickrevive/staminup) keep stock costs.
function tod_set_perk_costs()
{
	if ( !isdefined( level._custom_perks ) )
		return;

	costs = [];
	costs[ "specialty_widowswine" ]        = 4000; // Widow's Wine (matches the ZOMBIE_PERK_WIDOWSWINE "4000" precache)
	costs[ "specialty_combat_efficiency" ] = 3000; // Electric Cherry (_tod_perk_electric_cherry; also set in its register_perk_basic_info)
	costs[ "specialty_electriccherry" ]     = 4000; // PhD Flopper — registered OVER the stock cherry specialty (_tod_perk_phd); keep in lockstep with TOD_PHD_COST and the Aetherium perk card
	costs[ "specialty_doubletap2" ]        = 3000; // Double Tap 2 (v6 scatter pool)
	costs[ "specialty_deadshot" ]          = 3500; // Deadshot Daiquiri (v6 scatter pool)

	keys = GetArrayKeys( costs );
	for ( i = 0; i < keys.size; i++ )
	{
		perk = keys[ i ];
		if ( isdefined( level._custom_perks[ perk ] ) )
			level._custom_perks[ perk ].cost = costs[ perk ];
	}
}

function tod_resolve_dev_flags()
{
	// SHIP STATE: both false. To arm a test session, hardcode true + rebuild.
	// ARMED = dev: upgrades EVERY round + Panzer from round 3 (interval 3) +
	// Reaver interval 2 + dev money + no per-station cap + TIER card on every
	// deal + a 20s uplink hold-out + scatter/boss diagnostics;
	// god = demigod (damage lands, health floors at 1 — never a down).
	//
	// SHIPPED 2026-08-23 (user: "turn off dev and god mode. Im going to play a
	// real run") — first real run of this map. Ship deltas vs the armed state
	// the whole build history was tested under:
	//   upgrades  every round -> every 4th (TOD_UPG_EVERY_N_SHIP)
	//   Panzer    r3 then /3  -> r5 then /5
	//   Reaver    /2          -> /4 (still gated on the lap-20 door)
	//   TIER card 100% deals  -> 20% (TOD_TIER_CARD_PCT)
	//   stations  unlimited   -> 5 uses each (TOD_STATION_USES_PER)
	//   uplink    25s song    -> the full 191s song (TOD_FINALE_SONG_SECS)
	//   money     dev_money_loop stops — the real economy applies
	//   damage    demigod OFF — downs and bleedouts are live
	// ⚠️ ARMING level.tod_dev BREAKS THE MAP LOAD (2026-08-24, three builds in a
	// row). It was armed at the user's request, and the map stopped loading —
	// 2:00, 2:03 and 2:12 all failed where the 1:54 ship build had just been
	// played. Those two booleans were the ONLY code difference between them, so
	// this is not a correlation: something behind the dev gate kills the load.
	//
	// NOT YET DIAGNOSED — see docs/32. The dev-gated init work is small and worth
	// suspecting in this order: dev_money_loop (_tod_main.gsc) reads player.score,
	// which this repo's own doctrine forbids touching; debug_dump
	// (_tod_perk_scatter.gsc) dereferences pad.disp with no guard; and the dev
	// hellhound/Panzer/Reaver intervals pull enemies far earlier than ship.
	// God mode is only two sites in the damage chain and does no init work, so it
	// is the less likely half — bisect dev alone before blaming it.
	//
	// DO NOT re-arm either flag to "just check something" without expecting the
	// load to fail. The one dev feature worth having — the perk-scatter
	// diagnostic — was un-gated instead (see dev_print in _tod_perk_scatter.gsc),
	// so the cherry hunt does not need this flag at all.
	// SHIP STATE — both OFF (user 2026-08-24: "trun off god and dev mode.
	// Rebuild once all done"). This is a PUBLISH-CANDIDATE build.
	//
	// Consequence to know: dev_print in _tod_perk_scatter.gsc is gated on
	// tod_dev, so the ELECTRIC CHERRY diagnostic and the menu input probes go
	// SILENT here — correct for a published map (no debug text on screen), but
	// it means the cherry bug (docs/32) still has no named root cause. Its
	// SELF-HEAL (machine_for + coherence_watch) ships active regardless.
	// SHIP STATE — BOTH OFF (user 2026-08-25: "rebuild full with dev and god mode
	// hard coded off. Ill give a quick test and publish"). This is a
	// PUBLISH-CANDIDATE build; the 2026-08-25 test session that armed them both
	// is over.
	//
	// Everything the armed state changed is listed in the ship-deltas block
	// above — read it before wondering why upgrades are rarer, the Panzer is
	// later, or downs suddenly matter again. None of that is a regression; it is
	// the real economy the map is balanced for.
	// TEST SESSION (user 2026-08-25: "hardcode dev and god mode true and rebuild.
	// Ill test like that"). *** BOTH MUST GO BACK TO false BEFORE PUBLISHING. ***
	// ⚠️ THE "ARMING tod_dev BREAKS THE LOAD" WARNING ABOVE IS DEAD — READ THIS.
	// It was written 2026-08-24 after three builds in a row failed to load with
	// dev armed. The cause was a DYING GAME INSTALL: once the user redownloaded
	// the game, a dev+god-armed build loaded and played fine the same day. The
	// three suspects listed above (dev_money_loop reading player.score,
	// debug_dump's unguarded pad.disp, the dev enemy cadences) were never
	// validated and never reproduced. The paragraph is kept because the wrong
	// theory and how it died are worth remembering — but do NOT let it stop you
	// arming these flags. See the memory note `dev-mode-breaks-map-load`.
	//
	// (The crown test harness has been armed and removed TWICE now — 2026-08-25
	// and again 2026-08-26 for an ending retest, deleted the same night once the
	// user confirmed the ending. Both times it was WRITTEN FRESH rather than
	// left dormant behind this flag, and that is the habit to keep: four calls
	// are easier to re-derive than a stale harness is to audit for what it still
	// silently forces. tod_dev no longer warps anyone anywhere; it gates
	// dev_money_loop, the per-station cap and the diagnostics only.)
	//   tod_god  — demigod: damage lands, health floors at 1, never a down.
	// *** BOTH MUST GO BACK TO false BEFORE PUBLISHING. *** Everything the armed
	// state changes to the economy is in the ship-deltas block above: upgrades
	// every round, Panzer from r3, Reaver /2, TIER card on every deal, unlimited
	// station uses and dev money.
	//
	// THE FINALE IS NO LONGER SHORTENED BY THIS FLAG (corrected 2026-08-26). This
	// block used to warn that an armed build gets "a 20s uplink hold-out instead
	// of the 191s song". That stopped being true on 2026-08-25: see the block
	// comment above road_secs()/song_secs() in _tod_finale.gsc:790, which says
	// the two numbers must NEVER branch on tod_dev again, because the short dev
	// clock ended the run with most of the wav still playing and cost two
	// confusing test sessions. An armed build now plays the ending exactly as a
	// shipped one does: 90s of road, then whatever is left of the 191s song.
	//
	// AND IT PUTS DEBUG TEXT ON SCREEN, which is worth knowing before you judge
	// the map's look while armed: _tod_perk_scatter::debug_dump IPrintLn's a line
	// per machine at load and on every reshuffle, dev_print narrates the scatter,
	// the hellhound module prints, and the upgrade-card input probe prints once a
	// second while a card is open. That is deliberate diagnostics, but it runs
	// against this map's standing "no floaty text" rule, so do not report it as a
	// bug and do not screenshot the HUD from an armed build.
	// SHIP STATE — BOTH OFF. Disarmed 2026-08-26 after the user's ending retest
	// ("All looks good to me"), and the crown test harness was DELETED with them:
	// dev_crown_test() and dev_warp_to_terrace() are gone from _tod_main.gsc,
	// along with the thread line in init(). Nothing in this build warps, forces
	// power, or opens the causeway gate.
	level.tod_dev = false;
	level.tod_god = false;
}
