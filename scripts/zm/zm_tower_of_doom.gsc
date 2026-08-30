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
// v13.6 — ALXS CW/BO6 Pack-a-Punch (the crown machine; replaces the stock
// vending_weapon_upgrade prefab there). Models/anims Madgaz + Owen C137,
// script RiDD_Alexis31 et al — full credits in CREDITS.md. Its assets ride
// zone include `alxs_cwpap`; its sounds ride the szc ALIAS entry.
#using scripts\zm\zm_cwpap;
#using scripts\zm\_zm_perk_additionalprimaryweapon;
#using scripts\zm\_zm_perk_doubletap2;
// [tod] v14.16 — WISP TEA (BO7, vendored WetEgg module) replaces Deadshot in
// the scatter roster. It occupies Deadshot's old #using slot in BOTH entry
// scripts so the clientuimodel registration order stays matched (its 2-bit
// hudItems field lands where Deadshot's freed 2 bits were). Matching #using
// in the entry .csc REQUIRED (clientfield lockstep).
#using scripts\zm\_zm_perk_wisp_tea;
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
#using scripts\zm\zm_tower_of_doom\_tod_stray;
// THE ARMORED SPRINTER — elite #3 since the 2026-08-29 ladder re-deal (lap-30
// door; hounds moved to lap 40). Conversion-based: promotes horde spawns, so
// it has NO entry-.csc counterpart and no clientfields of its own — the smoke
// is server PlayFxOnTag on an already-zoned fx, the clank a stock alias.
#using scripts\zm\zm_tower_of_doom\_tod_sprinter;
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
// [tod] THE ENDLESS SPIRE (v14, docs/44): the post-victory endless mode — the
// win offers EXTRACT (the old ending) or a one-way ascension to a second
// 100-floor tower with the full grant (all perks, maxed class). Talks to
// _tod_finale by level notifies only; no-ops if the spire geometry is absent.
#using scripts\zm\zm_tower_of_doom\_tod_spire;

// Perk machine hint strings (cost substitution variants — the string+cost pair
// must be precached or the buy hint shows blank; map 1 pattern).
//
// THE OTHER SIX WERE MISSING (found 2026-08-27 while retuning perk costs).
// Precaching a localized hint is PER MAP — nothing in zm_usermap, _zm_perks or
// any stock perk module precaches these, and stock maps carry their own list
// (see zm_giant.gsc:104-109). Map 1 precaches all eleven of its pairs; this map
// carried exactly one, so every perk whose hint is a LOCALIZED string was
// rendering its buy prompt with a blank cost.
//
// Electric Cherry and PhD are NOT in this list and do not need to be: both are
// custom perks registered with a LITERAL hint string ("... [Cost: &&1]"), and a
// literal takes its substitution at runtime rather than from a precached pair.
// That is also why they were never affected by the omission.
//
// EACH COST NEEDS ITS OWN LINE — the pair is the key, not the string. Change a
// perk's cost and you must add the new pair here or the hint blanks again, which
// is exactly how this stayed invisible: the values below MUST match
// tod_set_perk_costs() and the stock defaults it leaves alone.
#precache("triggerstring", "ZOMBIE_PERK_QUICKREVIVE", "500");    // solo
#precache("triggerstring", "ZOMBIE_PERK_QUICKREVIVE", "1500");   // co-op
#precache("triggerstring", "ZOMBIE_PERK_MARATHON", "2000");      // Stamin-Up (stock)
#precache("triggerstring", "ZOMBIE_PERK_JUGGERNAUT", "2500");    // Juggernog (stock)
#precache("triggerstring", "ZOMBIE_PERK_FASTRELOAD", "3000");    // Speed Cola (stock)
#precache("triggerstring", "ZOMBIE_PERK_DOUBLETAP", "3000");     // NOT stock's 2000 — this map overrides it
// ZOMBIE_PERK_DEADSHOT pair REMOVED v14.16 — Deadshot retired for Wisp Tea,
// and a precached pair for a perk no machine sells is a permanent BG-cache
// slot spent on a dead string. Wisp Tea needs NO line here: like EC/PhD above
// it registers a LITERAL hint ("... [Cost: &&1]"), which substitutes at
// runtime rather than from a precached pair.
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

	// THE 41 DOOR TRIGGERSTRINGS ARE HANDLED IN THE GENERATOR NOW, NOT HERE.
	//
	// Stock _zm_blockers::door_init ends in
	// set_hint_string(self,"default_buy_door",cost) ->
	// SetHintString(&"ZOMBIE_BUTTON_BUY_OPEN_DOOR_COST", cost), which mints ONE
	// PERMANENT BG-cache 'triggerstring' slot per DISTINCT cost. Per-lap pricing
	// put 41 distinct zombie_cost values in the .map, so stock burned 41 of the
	// match's 250 on prompts nobody ever sees (_tod_doors.gsc TriggerEnable(false)s
	// all 53 a second later). tools/gen_tower_map.js now emits a CONSTANT
	// zombie_cost of 1000, so the .map carries one value and stock mints one slot.
	//
	// A RUNTIME FLATTEN USED TO LIVE HERE AND IT WAS A SILENT NO-OP (found
	// 2026-08-30). Its comment claimed it "MUST run BEFORE zm_usermap::main()
	// — that is where stock's __init__ pass fires init_blockers". That premise
	// was FALSE. _zm_blockers.gsc registers &__init__ through REGISTER_SYSTEM_EX,
	// and shared.gsh names that parameter __func_init_preload; preloads run in
	// system::run_pre_systems(), whose only caller is
	// callbacks_shared.gsc::CodeCallback_PreInitialization — documented in stock
	// as "Called by code before level main but after autoexecs". So door_init had
	// already minted all 41 slots before main() executed its first line, and
	// nothing assigned after that could take one back.
	//
	// WHAT MADE IT INVISIBLE: GetEntArray returns the ents FINE that early, so the
	// loop ran, the dev print reported "flattened zombie_cost on 53 doors", and
	// the fix read as verified while saving exactly zero. If you ever need to
	// prove a triggerstring fix again, count DISTINCT STRINGS — never trust a
	// print that only proves a loop executed.
	zm_usermap::main();

	// NO PERK LIMIT (playtest 2026-08-23: "There should be no perk limit").
	// Stock _zm_perks::init hardcodes 4; it has run by this point (the system
	// inits fire inside zm_usermap::main), so setting it here wins.
	// 9 -> 10 (v14): the roster has been TEN since PhD Flopper joined the
	// scatter (9 machines + roof Mule Kick) — 9 was a stale count that quietly
	// blocked holding the full set, and the spire's ascension grant hands out
	// all ten.
	level.perk_purchase_limit = 10;

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

	// [tod] MELEE KILL MONEY: 130 -> 120 (user 2026-08-26: "knife kills go down
	// from 130 to 120"). Stock pays a melee kill as
	// get_zombie_death_player_points() 50 + zombie_vars["zombie_score_bonus_melee"],
	// and that bonus ships at 80 (_zm.gsc:1243) = the 130 being nerfed. 70 lands
	// the total on 120.
	//
	// DIRECT ASSIGNMENT, NOT zombie_utility::set_zombie_var: with its default
	// args that function IS this one line, and calling it would cost a #using
	// for nothing (this file's #using/#precache ordering is a known compile
	// trap). The var is NOT team-dimensioned — _zm_score.gsc reads it as
	// level.zombie_vars["zombie_score_bonus_melee"] at both of its sites (the
	// kill-bonus switch and the ballistic-knife case), unlike zombie_point_scalar
	// which is per-team. level.zombie_vars is fully populated by now:
	// zm_usermap::main() ran ~30 lines above, and nothing re-seeds these
	// afterwards (stock writes the score vars exactly once).
	//
	// TWO MIRRORS MUST MOVE WITH IT or the HUD lies about what it paid:
	//   _tod_upgrades::bounty_kill_value()  — BOUNTY's % base + its popup preview
	//   AetheriumPlayerInfo.lua death_melee — the "+120" that pops on screen
	// This hits the SLASHER hardest by design: its class primary IS the blade,
	// so every one of its kills takes the -7.7%.
	level.zombie_vars[ "zombie_score_bonus_melee" ] = 70;

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

	// [tod] TARGETING FIX (2026-08-30, 3-player live report: "zombies wouldn't
	// target the closest player — they got stuck targeting one player only",
	// plus stair spawns idling until approached). Stock zm_usermap_ai installs
	// factory_closest_player as level.closest_player_override: a per-zombie
	// STICKY target (kept as long as that player stays valid) refreshed at most
	// one zombie per server frame, with the "closest" measured by a live
	// PathDistance() probe — and when that probe returns undefined for every
	// candidate, the fallback is the FIRST valid entry of the players array,
	// i.e. THE HOST, for every zombie that asks (zm_usermap_ai.gsc:143-162).
	// On a 19,000-unit spiral the probe is exactly what fails at range, so the
	// whole horde converges on one player and stays there. Replacing the policy
	// with a stateless straight-line pick (stock's own default when no override
	// is installed — _zm_utility.gsc:1482) kills the sticky cache, the host
	// fallback AND the per-frame path generation in one move. Assigned here in
	// main(), which runs after zm_usermap_ai's autoexec, so ours wins.
	level.closest_player_override = &tod_closest_player;

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

	// THE ARMORED SPRINTER (v13.7): dormant until the LAP 30 breather door is
	// bought, then every 3rd round 1+players/2 of the round's OWN spawns are
	// promoted — chain-armor skin, smoke tell, +15-round sprint, bullets x1/4.
	// Converted horde, not spawned elites: they count toward the round and
	// take no finale boss slot.
	level thread tod_sprinter::init();

	// HELLHOUNDS: dormant until the LAP 40 breather door is bought (moved from
	// lap 30 in the 2026-08-29 ladder re-deal — the sprinter has that slot),
	// then a PACK on that round and every 3rd after (dev: every 2nd). Roof 4,
	// and they only ever fill SPARE elite capacity (combined roof 9) so a pack
	// can never be the thing that starves the horde at stock's 31-actor gate.
	level thread tod_hellhounds::init();
	// STRAY RELOCATION (user 2026-08-30: "when you go all the way down the tower
	// with teleporter the zombies try to run down ... I dont want to kill them off
	// but have them spawn near the player if they are too far"). Zombies stranded
	// laps away from every player — after a teleporter ride, a long descent, or a
	// co-op split — are silently ForceTeleported onto a riser near the nearest
	// upright player, and ONLY onto a spot nobody can currently see. It NEVER
	// kills and never writes level.zombie_total, which is what the endless-round
	// twist reads (_tod_endless_rounds::tod_round_wait) — so the round contract
	// is untouched by construction.
	level thread tod_stray::init();

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

	// THE ENDLESS SPIRE (v14, docs/44): seals the 100 spire door slabs, inits
	// the enter_spireN flags, and waits for the finale's choice phase. Returns
	// immediately if the spire geometry is not in the .map.
	level thread tod_spire::init();
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

	// THE POWER HALL (v13.1) — the map's third gated annex, and a zone for
	// exactly the reason the teleport bay is one. The user asked for a riser in
	// the hallway to break the dead-end camp there (2026-08-28); the hallway is
	// sealed behind the enter_power door, so on base_zone's ticket that riser
	// would have been live from round 1 and spawned zombies into a corridor
	// whose navmesh is cut. gen_tower_map.js moved the hall's volume out of
	// base_zone and into power_zone in the same pass — the two MUST move
	// together, or the hall is either double-covered or covered by nothing.
	zm_zonemgr::add_adjacent_zone( "base_zone", "power_zone", "enter_power" );

	// THE ENDLESS SPIRE (v14, docs/44): the ascension itself is the chain's
	// root flag (set by _tod_spire when the party teleports), then one chunk
	// zone per 5 floors, each chained on its FIRST floor's door; the summit
	// rides the last door's flag. MUST match the generator's SP_LAPS /
	// SP_ZONE_CHUNK (tools/gen_tower_map.js SECTION 6 — the zone names come
	// from generated _tod_spire_data.gsc::spire_zone_names()).
	zm_zonemgr::add_adjacent_zone( "roof_zone", "spire_base_zone", "tod_ascension" );
	zm_zonemgr::add_adjacent_zone( "spire_base_zone", "spire_c1_zone", "enter_spire1" );
	for ( i = 1; i < 20; i++ )
	{
		zm_zonemgr::add_adjacent_zone( "spire_c" + i + "_zone", "spire_c" + ( i + 1 ) + "_zone", "enter_spire" + ( i * 5 + 1 ) );
	}
	zm_zonemgr::add_adjacent_zone( "spire_c20_zone", "spire_summit_zone", "enter_spire100" );
}

// [tod] The closest-player policy for trash-zombie targeting (see the long
// note at the assignment in main()). Called by zm_utility::get_closest_valid_
// player with self = the asking AI and `players` already filtered down to
// valid, non-ignored candidates — this function ONLY picks among them.
// The zombie_poi carve-out is kept from the stock factory version: a live
// point of interest (Widow's Wine web, monkey-style attractors) owns the
// zombie, and returning undefined here hands zombieFindFlesh to its POI
// branch instead of a player chase (_zm_behavior.gsc:269-286).
function tod_closest_player( origin, players )
{
	if ( isdefined( self.zombie_poi ) )
		return undefined;
	return ArrayGetClosest( origin, players );
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
	// specialty_combat_efficiency ROW DELETED (v13.20, publish-sweep find):
	// this table runs AFTER the module's autoexec registration, so the stale
	// Electric-Cherry-era 2000 here silently DEFEATED Death Perception's
	// EC_COST 1500 — the exact multi-site trap the domain-retune checklist
	// documents. The module's EC_COST is the single source of truth now;
	// never re-add a row for this specialty.
	costs[ "specialty_electriccherry" ]     = 2000; // PhD Flopper — registered OVER the stock cherry specialty (_tod_perk_phd); keep in lockstep with TOD_PHD_COST and the Aetherium perk card
	costs[ "specialty_doubletap2" ]        = 3000; // Double Tap 2 (v6 scatter pool)
	// specialty_deadshot ROW DELETED (v14.16 — Deadshot retired for Wisp Tea).
	// Wisp Tea's cost is WISP_TEA_PERK_COST in _zm_perk_wisp_tea.gsh — the
	// module registers it itself; a row here would re-create the v13.20
	// stale-price trap this comment block already documents.

	keys = GetArrayKeys( costs );
	for ( i = 0; i < keys.size; i++ )
	{
		perk = keys[ i ];
		if ( isdefined( level._custom_perks[ perk ] ) )
			level._custom_perks[ perk ].cost = costs[ perk ];
	}
}

// (tod_doors_flatten_map_cost() was deleted 2026-08-30 — it ran too late to do
// anything. The constant zombie_cost is emitted by tools/gen_tower_map.js now;
// see the note above zm_usermap::main() in main().)

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
	// SHIP STATE — BOTH OFF. Re-disarmed 2026-08-27 after the terrace test run
	// (armed earlier that day for the extraction/teleporter/pause-menu pass), and
	// dev_crown_test()/dev_warp_to_terrace() were DELETED from _tod_main.gsc again
	// with them. That harness has now been written and removed three times; the
	// recipe lives in the comment beside the dev block in _tod_main::init() so the
	// fourth time is cheap. Nothing in this build warps, forces power, or opens
	// the causeway gate.
	// SHIP STATE — BOTH OFF. Re-disarmed 2026-08-27 evening for the v12.15
	// publish, together with harness #4 (dev_crown_test/dev_warp_to_terrace
	// DELETED from _tod_main.gsc for the fourth time — the recipe comment
	// there survives, the code never does). Nothing in this build warps,
	// forces power, or opens the causeway gate.
	// TEST SESSION (user 2026-08-28: "Can you hardcode enabke dev and god
	// mode") — armed for the v13 breather-lounge walk-through. No harness
	// this time: the lounges are on the normal climb, dev money + god cover
	// the doors and the risk. *** BOTH MUST GO BACK TO false BEFORE
	// PUBLISHING. ***
	// SHIP STATE — BOTH OFF (user 2026-08-29: "turn of the falgs and do a full
	// rebuidl for publish"). The 2026-08-28/29 test marathon that armed them is
	// over. This is a PUBLISH-CANDIDATE build: real economy, real downs, ship
	// cadences — every delta is in the ship-deltas block at the top of this
	// function.
	//
	// TEST SESSION (user 2026-08-29, sprinter round-1 flood verification) —
	// ARMED, then DISARMED the same night (user: "remove the dev changes and
	// everything for this new enemy... im done testing"). The flood harness
	// itself is REMOVED from _tod_sprinter (recipe comment survives there).
	//
	// DISARMED for the PUBLISH CANDIDATE (user 2026-08-29: "you can remove dev
	// and god mode flags and do a full rebuild and ill test oen last time to
	// publish"). Both false = ship state.
	//
	// Verified at the disarm, not assumed — the whole point of this flip is that
	// nothing dev-only survives it:
	//   * the warp harness (dev_crown_test / dev_crown_warp) is GONE from
	//     _tod_main.gsc; only the historical "removed again" comments remain.
	//   * all five on-screen debug prints are behind tod_dev and go inert here:
	//     _tod_hellhounds.gsc:144, _tod_perk_scatter.gsc:816 and :835,
	//     _tod_upgrade_ui.gsc:736, zm_cwpap.gsc:159.
	//   * every other tod_dev use is a VALUE GATE (Panzer/Reaver/hound/sprinter
	//     intervals, tier-card odds, station uses, dev money) and resolves to its
	//     ship value with the flag false — those are supposed to stay.
	//   * the sprinter DEV_R1 round-1 flood is comment-only recipe
	//     (_tod_sprinter.gsc:104-105), not live code.
	// DISARMED for the v14.1 PUBLISH (user 2026-08-29 night: "Revert all the
	// hardcode changes so we can publish"). Harness #6 DELETED from _tod_main
	// (sixth write, sixth removal), the v13.26 DP breadcrumbs removed from
	// _tod_perk_electric_cherry.gsc+.csc (the .csc pair was UNGATED — it would
	// have printed for every player), and the crown-altar diagnosis
	// instruments (floating marker / heartbeat / stations-placed print)
	// removed from _tod_upgrades. The altar hardening itself (manager-first
	// station_place + guarded spawns) and the dev-gated lane diagnostics
	// (altar spawn-fail/press/deny prints, spire target probe, cwpap:159)
	// ship dormant, per the v13.17 doctrine. Both false = ship state.
	// TEST SESSION (user 2026-08-30: "Can you enable hard code dev and god mode?
	// And rebuild") — ARMED for the v14.16 test pass (Wisp Tea replacing
	// Deadshot, and the v14.14 triggerstring fix's first real run).
	// *** BOTH MUST GO BACK TO false BEFORE PUBLISHING. ***
	//
	// This build is NOT a publish candidate. Everything the armed state changes
	// is in the ship-deltas block at the top of this function: upgrades every
	// round, Panzer from r3, Reaver /2, TIER card on every deal, unlimited
	// station uses, dev money, and on-screen diagnostic text (scatter dump per
	// machine at load and on every reshuffle, hellhound prints, the upgrade-card
	// input probe once a second while a card is open). Do not judge the map's
	// look from this build and do not screenshot the HUD from it.
	//
	// The 2026-08-24 "arming tod_dev breaks the load" scare is DEAD — it was a
	// dying game install, fixed by a redownload. See the paragraph above and the
	// memory note `dev-mode-breaks-map-load`. Arm freely.
	//
	// NO WARP HARNESS in this build (that would be #7). Nothing warps, forces
	// power, or opens the causeway gate — the recipe is in the comment beside
	// the dev block in _tod_main::init() if the ending needs retesting.
	// SHIP STATE — BOTH OFF. Disarmed 2026-08-30 after the user's v14.16 test
	// pass ("Okay looks good. Prep for publish"). This is the PUBLISH CANDIDATE
	// build: real economy, real downs, ship cadences, no on-screen diagnostics.
	// Every delta back to ship is in the block at the top of this function.
	//
	// No harness to remove this time — none was written for the v14.16 pass
	// (the lounges and the perk scatter are both on the normal climb).
	level.tod_dev = false;
	level.tod_god = false;
}
