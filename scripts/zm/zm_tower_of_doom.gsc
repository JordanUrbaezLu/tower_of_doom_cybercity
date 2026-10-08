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
#using scripts\zm\zm_tower_of_doom\_tod_cyber_zombies;

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
#using scripts\zm\zm_tower_of_doom\_tod_perk_widows;   // Widow's Wine 25% nerf (v17.52): proc rates + web durations, cascades to the PhD children
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
#using scripts\zm\zm_tower_of_doom\_tod_spire_data;   // v17.92 — the spire zone chain is DERIVED from the generated names, never counted by hand again

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
#precache("triggerstring", "ZOMBIE_PERK_DOUBLETAP", "3500");     // NOT stock's 2000 — this map overrides it. 3000 -> 3500 (user 2026-09-01); the OLD pair is replaced, not kept, because a pair no machine sells is a permanent cache slot spent on a dead string (same reasoning as the deleted Deadshot pair below).
// ZOMBIE_PERK_DEADSHOT pair REMOVED v14.16 — Deadshot retired for Wisp Tea,
// and a precached pair for a perk no machine sells is a permanent BG-cache
// slot spent on a dead string. Wisp Tea needs NO line here: like EC/PhD above
// it registers a LITERAL hint ("... [Cost: &&1]"), which substitutes at
// runtime rather than from a precached pair.
#precache("triggerstring", "ZOMBIE_PERK_WIDOWSWINE", "4000");
// v19.76 — the thinned rising-dirt effects (tools/gen_tod_riser_fx.py; set in main)
#precache( "fx", "tod/zombie/fx_tod_rise_burst" );
#precache( "fx", "tod/zombie/fx_tod_rise_billow" );
#precache( "fx", "tod/zombie/fx_tod_rise_dust" );

//*****************************************************************************
// MAIN
//*****************************************************************************

function main()
{
	// DEV MODE — ONE compile-time flag, same doctrine as map 1 (its CLAUDE.md
	// "Dev/test mode"). Arm a test session by flipping to true + rebuild; the
	// ship state is false. NEVER a dvar, NEVER a launch flag.
	tod_resolve_dev_flags();
	tod_cyber_zombies::install_spawn_filter();

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

	// v19.76 — THE RISING DIRT, THINNED (lead tester Nikolai, Oct 2026: "the
	// smoke/dust visual effects generated when zombies emerge from the floor are
	// too dense ... Tone down the opacity and visual lifetime"). Stock's
	// zombie_rise_dust_fx (_zm_spawner) replays rise_dust ON THE SERVER every 0.3 s
	// for up to 5.5 s a zombie - on top of the client's own identical loop - so this
	// side is pointed at the thinned copy too (zm_tower_of_doom.csc owns the
	// client's). Stock assigned these in zm_usermap's autoexec init_fx, which has
	// run by now, so the assignment holds. tools/gen_tod_riser_fx.py is the source.
	level._effect[ "rise_burst" ]  = "tod/zombie/fx_tod_rise_burst";
	level._effect[ "rise_billow" ] = "tod/zombie/fx_tod_rise_billow";
	level._effect[ "rise_dust" ]   = "tod/zombie/fx_tod_rise_dust";

	// PERK LIMIT — NONE (v16.80, 2026-09-03; user: "remove the perk limit so
	// revert back how it use to be"). Stock _zm_perks::init hardcodes 4
	// (_zm_perks.gsc:43); this lifts it above anything the map can sell, so
	// every machine is buyable and the perk bottle is never refused for a cap.
	//
	// HISTORY. "NO PERK LIMIT (playtest 2026-08-23)" set 10 here and was
	// play-proven for eight days. v14.56 (2026-08-31) capped perks at 4 with
	// the PERK SLOTS card (domain 40, +1 slot/Lv, max 5 = the 9-machine
	// roster) as the way past it, and moved this assignment to
	// _tod_upgrades::init beside the domain. It shipped without a change note;
	// the Workshop thread's verdict (Bobby, three comments 09-01..09-03:
	// "wasting these awesome upgrades on a DAMN PERK SLOT") plus the draw
	// odds (A band, ~1 offer in 7 deals, so the cap read as a hard 4) ended
	// it. The domain is retired (id 40 stays mapped, its add_domain is a
	// `// Was:` line) and the per-player hook
	// level.get_player_perk_purchase_limit is gone with it, so stock's
	// zm_utility::get_player_perk_purchase_limit returns THIS number verbatim.
	//
	// DELIBERATELY ABOVE THE ROSTER, NOT EQUAL TO IT. The map sells nine
	// (count zm_perk_machine entities in the .map — never a prose list; every
	// prose count of this roster has been wrong at least once). A tenth
	// machine must not need a lockstep edit here: that lockstep is exactly
	// what v14.56 created and what this removes. Nothing stock reads the
	// number except the vending gate and the random-perk bottle
	// (_zm_perk_random.gsc:210/240), so a large value has no other effect.
	// Lives HERE, after zm_usermap::main (which is after stock's 4), on
	// purpose — ONE writer, in the file that owns the map's stock overrides.
	// PERK LIMIT — OWNED BY _tod_upgrades AGAIN (v17.3). v16.80 put a constant
	// 16 here, deliberately above the nine-machine roster, when the PERK SLOTS
	// domain was retired. The domain is back at the user's request, so the cap
	// and the card that raises it live together in _tod_upgrades::init, which
	// also sets level.get_player_perk_purchase_limit. This assignment stays as
	// the PRE-INIT default only — stock reads it if anything asks before that
	// init runs.
	level.perk_purchase_limit = 4;

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

	// [tod] v14.28 — STOCK'S HEALTH REBOOT MUST AGREE WITH THE 150 BASE (user
	// 2026-08-30: "jugg on this map will get you to 200 not 250" + "I have 210
	// but level 3 vitality... I just went back down to 200").
	//
	// Stock rebuilds a player's max HP FROM SCRATCH off this zombie_var in
	// perk_set_max_health_if_jugg's "health_reboot" case (_zm_perks.gsc:826),
	// and that case fires from FOUR places: every round transition
	// (_zm.gsc:4521), laststand revive x2, and jugg LOSS. With the stock 100
	// here, every one of those recomputed max = 100 (+100 jugg), throwing away
	// our 150 base AND every VITALITY level. The asymmetry that made it read
	// as "vitality breaks when you get jugg": WITHOUT jugg the reboot lands at
	// 100, BELOW the body-loop floor (150+10xVIT), and the floor silently
	// repairs it within a second — WITH jugg it lands at 200, ABOVE a Lv3
	// floor of 180, and the raise-only floor cannot see anything wrong. The
	// user's 210 was a vitality card bought while jugg was up (apply_upgrade's
	// additive +10), eaten by the next round's reboot back to 200.
	//
	// 150 here makes stock's own recompute agree with us by construction:
	// reboot = 150 (+100 jugg) = 250, matching the additive purchase path.
	// VITALITY on top is the body-loop floor's job (jugg-aware since v14.28 —
	// see _tod_upgrades). Blast radius audited 2026-08-30: this var is read
	// NOWHERE except perk_set_max_health_if_jugg's health_reboot and
	// jugg_upgrade-without-jugg branches — both are exactly "what is base max
	// HP", which on this map is 150. Same post-usermap timing contract as the
	// score var above (_zm.gsc:1229 seeded it to 100 during the bootstrap).
	// LOCKSTEP: TOD_UPG_BASE_HP in _tod_upgrades.gsc is 150 — a GSC #define is
	// file-local, so this literal cannot reference it; move them together.
	level.zombie_vars[ "player_base_health" ] = 150;

	// [tod] Custom per-perk costs — runs AFTER zm_usermap::main() populated
	// level._custom_perks (stock widows registered in the bootstrap; the cherry
	// registered via its REGISTER_SYSTEM autoexec), BEFORE the first tick /
	// first machine read. Map 1's set_perk_costs pattern.
	tod_set_perk_costs();
	// [tod] v14.17 — BO7 drink cans for every perk (same timing contract as
	// the costs pass above; see the function's header).
	tod_set_perk_cans();

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
	// NO RK5 EASTER-EGG REWARD (2026-09-24, lead tester: "some of us spawn with
	// RK5 ... it will be on every class including mage ... When I get downed it
	// wont spawn the default grenade pistol it pulls out RK5 ... Id recommend
	// just banning / removing this"). Stock _zm_utility::give_start_weapon hands
	// level.super_ee_weapon (pistol_burst, the RK5) as a SECOND start gun to any
	// player whose DARKOPS_GENESIS_SUPER_EE stat is set (_zm.gsc init_levelvars
	// sets it, inside zm_usermap::main above). This map's class loadout only
	// strips its own twelve sidearm stems, so the RK5 rode along on every class:
	// a fourth weapon beside the mage's three staffs, the best-ranked pistol in
	// stock's last-stand pick (so a co-op crawler drew it instead of our down
	// pistol), and a gun the mage HUD drew as a staff with no ammo. Pointing the
	// reward at the start weapon itself makes stock's second give a no-op
	// (weapon_give sees HasWeapon and only refills). _tod_classes::
	// take_foreign_secondaries also reaps any RK5 as a belt-and-braces lane.
	level.super_ee_weapon = level.start_weapon;
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

	// WIDOW'S WINE 25% NERF (v17.52): swaps stock's two Widow's handlers for
	// rate-limited wrappers and caps the web durations. Must run AFTER stock's
	// REGISTER_SYSTEM pass (it does — this is main()) and BEFORE the first
	// zombie spawns (the watchdog is on_ai_spawned).
	tod_perk_widows::init();

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
	// zone per 5 floors; the summit rides the last door's flag. MUST match
	// the generator's SP_LAPS / SP_ZONE_CHUNK (tools/gen_tower_map.js
	// SECTION 6 — zone names from generated _tod_spire_data.gsc).
	// v14.36 RE-KEY — ONE DOOR PER FLOOR (tower-matched), so door n IS floor n
	// and the keying is direct again: chunk k+1 (floors 5k+1..5k+5) is admitted
	// by the door on its FIRST floor, enter_spire{5k+1}. This reverts v14.23's
	// int((5k+2)/2) lap-pair arithmetic, which existed only because doors then
	// covered two floors each.
	// GETTING THIS WRONG IS THE OUT-OF-PLAYABLE INSTAKILL: a chunk whose flag
	// never fires is a DISABLED zone, and stock's monitor answers a player
	// standing in one with the Samantha laugh and an unrevivable kill (live
	// 2026-08-30, the v14.1-mover failure mode). Keep this in lockstep with
	// the generator's SP_ZONE_CHUNK and SPIRE_DOORS.
	zm_zonemgr::add_adjacent_zone( "roof_zone", "spire_base_zone", "tod_ascension" );
	// v17.92 — DERIVED, NOT COUNTED. This chain was written for the 100-lap
	// spire (c1..c20, summit on enter_spire100) and nobody moved it when v17.69
	// cut the spire to 70 laps = 14 chunks. So every match since registered six
	// zones that do not exist (c15..c20): twelve `undefined is not a field
	// object` throws in _zm_zonemgr at init, each followed by a 70-line
	// info_volume dump (4,690 lines of one console_mp.log) — and, worse, the
	// SUMMIT was chained only from the phantom c20, so spire_summit_zone could
	// never enable: a player on the summit deck was standing in a DISABLED
	// zone, which is the Samantha-laugh instakill the comment above warns
	// about. The chain now walks tod_spire_data::spire_zone_names() — base,
	// the chunks, the summit — with each chunk admitted by the door on its
	// first floor (zone_chunk floors per chunk) and the summit by the LAST door,
	// exactly the rule the 100-lap version encoded as a literal.
	spz = tod_spire_data::spire_zone_names();
	zc  = tod_spire_data::zone_chunk();
	for ( i = 0; i < spz.size - 1; i++ )
	{
		if ( i == 0 )
			fl = "enter_spire1";                                       // base -> c1: door 1
		else if ( i == spz.size - 2 )
			fl = "enter_spire" + tod_spire_data::spire_door_count();   // last chunk -> summit: the last door
		else
			fl = "enter_spire" + ( i * zc + 1 );                       // c<i> -> c<i+1>: the door on c<i+1>'s first floor
		zm_zonemgr::add_adjacent_zone( spz[ i ], spz[ i + 1 ], fl );
	}
}

// [tod] The closest-player policy for trash-zombie targeting (see the long
// note at the assignment in main()). The zombie_poi carve-out is kept from the
// stock factory version: a live point of interest (Widow's Wine web,
// monkey-style attractors) owns the zombie, and returning undefined here hands
// zombieFindFlesh to its POI branch instead of a player chase
// (_zm_behavior.gsc:269-286).
//
// IT FILTERS ITS OWN LIST NOW (2026-09-24, lead tester: "I have zombie blood
// but panzer still is trying to hit me with flame thrower, or melee ... He is
// still chasing me"). This comment used to say the list arrives "already
// filtered down to valid, non-ignored candidates" — true for ONE of its two
// callers. zm_utility::get_closest_valid_player (trash zombies, the Fury)
// culls on am_i_valid first; zombie_utility::get_closest_valid_player (the
// PANZER's stock target service, mechz.gsc:230) does not, because its cull
// loop is dead code in stock (`done = true; while ( targets.size && !done )`,
// zombie_utility.gsc:70). So the Panzer was handed every player, including a
// Zombie Blood player (ignoreme) and a downed one, and took the closest.
// is_player_valid( p, true ) is exactly the am_i_valid test (_zm.gsc:7100), so
// the trash-zombie path is unchanged. With nobody targetable this returns
// undefined, and zombie_utility's own fallback loop then filters properly.
function tod_closest_player( origin, players )
{
	if ( isdefined( self.zombie_poi ) )
		return undefined;
	targets = [];
	foreach ( p in players )
	{
		if ( zm_utility::is_player_valid( p, true ) )
			targets[ targets.size ] = p;
	}
	if ( targets.size == 0 )
		return undefined;
	return ArrayGetClosest( origin, targets );
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
	costs[ "specialty_doubletap2" ]        = 3500; // Double Tap 2 (v6 scatter pool). 3000 -> 3500 (user 2026-09-01). LOCKSTEP: the #precache triggerstring pair at the top of this file.
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

// [tod] v14.17 — EVERY PERK DRINKS FROM ITS BO7 CAN (user 2026-08-30, after
// seeing Wisp Tea's: "yeah we can add this. We would need to change the sfx
// to match the animation"). The drink animation belongs to the perk's BOTTLE
// WEAPON: stock's perk_give_bottle_begin/end read ONLY
// level._custom_perks[perk].perk_bottle_weapon (_zm_perks.gsc:1002/:1025 —
// no other source, verified), and STOCK modules register into _custom_perks
// too (the costs pass above already overrides their .cost there). So one
// post-registration stamp swaps every drink to the SATPerks BO7 can, whose
// viewmodel carries the BO7 drink gesture. THE SFX COME WITH IT BY
// CONSTRUCTION: the gesture anim fires sound notetracks
// (ps_wfoly_plr_can_drink_grab/_open/_drink/_throw/_land), packed via
// sound/aliases/tod_perk_cans.csv — no scripted timing anywhere, so the
// audio cannot drift from the animation. Wisp Tea is absent here on purpose
// (its module registers its own can). Same timing contract as
// tod_set_perk_costs. Each can weapon needs its `weapon,<name>_zm` zone
// line (GetWeapon takes the no-_zm form — the zone file's :98 convention).
// machine_assets[spec].weapon is stamped in the same beat where the entry
// exists — the wisp module sets both fields, and keeping the pair coherent
// costs one line (stock reads it on the host-migration lane).
function tod_set_perk_cans()
{
	if ( !isdefined( level._custom_perks ) )
		return;

	cans = [];
	cans[ "specialty_armorvest" ]               = "t10_perk_can_juggernog";
	cans[ "specialty_fastreload" ]              = "t10_perk_can_speed_cola";
	cans[ "specialty_quickrevive" ]             = "t10_perk_can_quick_revive";
	cans[ "specialty_staminup" ]                = "t10_perk_can_staminup";
	cans[ "specialty_doubletap2" ]              = "t10_perk_can_double_tap";
	cans[ "specialty_widowswine" ]              = "sat_perk_can_widows_wine";
	// this map's Death Perception rides the combat_efficiency specialty...
	cans[ "specialty_combat_efficiency" ]       = "t10_perk_can_death_perception";
	// ...and PhD rides the stock cherry specialty (see the Lua's long note).
	cans[ "specialty_electriccherry" ]          = "t10_perk_can_phd_flopper";
	// MULE KICK — RETIRED WHOLE, v17.10 (2026-09-04). The comment that used to
	// sit here said "the fixed roof machine still sells it" and that machine does
	// not exist: the .map carries nine zombie_vending triggers and none of them is
	// specialty_additionalprimaryweapon, nothing anywhere grants the perk, and
	// _tod_perk_scatter skips the specialty as a "roof fixture" that was removed.
	// So the can could never be drunk. `weapon,sat_perk_can_mule_kick_zm` is gone
	// from the .zone with this line — one registration back under the ledger
	// guard, and a half-retirement closed.
	// The PNG/model stay in source_data; only the reachable half is retired.

	keys = GetArrayKeys( cans );
	for ( i = 0; i < keys.size; i++ )
	{
		perk = keys[ i ];
		if ( !isdefined( level._custom_perks[ perk ] ) )
			continue;
		w = GetWeapon( cans[ perk ] );
		level._custom_perks[ perk ].perk_bottle_weapon = w;
		if ( isdefined( level.machine_assets ) && isdefined( level.machine_assets[ perk ] ) )
			level.machine_assets[ perk ].weapon = w;
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
	//
	// SHIP STATE — BOTH OFF. Armed once on 2026-08-30 for the v14.17–v14.22
	// test pass at the user's request, disarmed the same evening on their
	// follow-up ("do a full rebuild with dev and god mode off once you are
	// done"). Every build since has been disarmed.
	//
	// ⚠️ READ THE ASSIGNMENTS, NOT THIS COMMENT. Between the disarm and
	// 2026-08-30 21:0x this block still said "ARMED — TEST BUILD" over
	// `= false;` — stale prose I wrote when arming and did not follow down when
	// the flags flipped. Two separate sessions hit it, and both had to warn
	// each other "the assignments are the truth". A comment that contradicts
	// the line under it is worse than no comment: it is the artifact people
	// quote when they are too rushed to read the code. If you arm these, put
	// the reason HERE and delete it in the same commit that disarms.
	//
	// WHAT ARMING CHANGES, for whoever needs it next: dev gates the money loop,
	// early Panzer/boss intervals, 100% tier-card odds and unlimited station
	// uses; god makes the player unkillable. Caveat worth keeping — god mode
	// MASKS the out-of-playable instakill, because that monitor deals raw
	// DoDamage; the audible tell is the Sam laugh (-21, 2026-08-30).
	//
	// A PUBLISH IS NEVER A RELABEL OF AN ARMED ARTIFACT: flags false, then a
	// fresh FULL build, then publish.
	// (The 2026-08-31 publish build disarmed both and removed HARNESS #7 from
	// _tod_main in the same pass; the two always move together.)
	//
	// DISARMED FOR THE v14.59 PUBLISH BUILD (user 2026-08-31: "Also take off dev
	// and god mode and do a fullrebuild prep for publish"). The v14.56 PERK SLOTS
	// test session is over and its ARMED block is deleted here, in the same edit
	// that flips the flags — which is the rule three lines up, and the rule exists
	// because a stale "ARMED — TEST BUILD" comment once sat over `= false;` for a
	// day and cost two sessions warning each other that the assignments are the
	// truth. A comment that outlives its build is worse than no comment.
	//
	// DISARMED 2026-09-01 evening (user: "Can you remove dev and god mode and
	// rebuild"). The 2026-09-01 ATHLETE test session was armed earlier that day
	// ("turn on dev and god mode and ill run a test") and its ARMED block is
	// deleted here, in the same edit that flips the flags — the rule above.
	// That session's questions were never answered in play (the user reported
	// they had not tested v16, v16.1 or v16.2), so they stay OPEN and are
	// recorded in docs/62_slasher_movement_research.md §7 rather than here:
	// the slide-jump trace (`ATH slide` / `ATH jump` lines) and the movement
	// dvar print only exist in a tod_dev build, so THIS build gives feel, not
	// numbers. Re-arm to read them.
	// DISARMED FOR THE v16.55 PUBLISH BUILD (user 2026-09-02: "Okay lets remove
	// all of the dev hardcoded things and let prep for full build and publish").
	// The v16.21 max-slasher test session is over and its ARMED block is deleted
	// here, in the same edit that flips the flags — the rule above. That session
	// armed the _tod_class_select dev short-circuit (no draft, everyone a tier-3
	// slasher with every slasher domain capped) purely to read a damage ceiling;
	// nothing about it belongs in a shipped build.
	// TEST SESSION — BOTH STILL ARMED (user 2026-09-03: *"No i want both on. Im
	// saying there are extra elites when dev is on. I want to remove that
	// specific thing"*). *** BOTH MUST GO BACK TO false BEFORE PUBLISHING ***
	// — and this ARMED block is deleted in the same edit that flips them.
	//
	// ⚠️ ONE ITEM LEFT THE ARMED STATE IN v16.87 AND IS NOT COMING BACK: dev no
	// longer touches ENEMY CADENCE. Every elite family used to run a dev
	// interval about twice the shipping one — Panzer r3 then /3, Reaver /2,
	// hellhound /2, sprinter /2, against ship 5 then /5, /4, /3, /3 — so an
	// armed session was a measurably different game and every armed playtest
	// tested numbers the map does not ship. All four families are play-proven,
	// so the acceleration had no job left. The branches and their five
	// TOD_*_DEV defines are GONE from `_tod_bosses`, `_tod_hellhounds`,
	// `_tod_reaver` and `_tod_sprinter`; the full note is on panzer_due.
	// **Do not re-add a dev cadence to one family alone** — that is the lockstep
	// this removed. To test a family, drop its SHIP #define for the session.
	//
	// So the ship-deltas block at the top of this function is now stale on the
	// Panzer/Reaver lines: dev still changes upgrades-every-round, the TIER card
	// rate, station uses, dev money, the diagnostics and demigod — but NOT how
	// often anything spawns.
	// DISARMED FOR THE v17.7 PUBLISH BUILD (2026-09-03, user: "Okay it works.
	// Prepare for publish build"). The armed session verified THE TOWER
	// NAVMESH SEED FIX in game — zombies target above floor 17 and Cymbal
	// Monkeys survive the throw, with no Samantha laugh, which was the agreed
	// reading. Its ARMED block is deleted here, in the same edit that flips the
	// flags, per the rule above. HARNESS #9 stays in _tod_main: it is gated on
	// tod_dev and does nothing in a shipped build.
	// TEST SESSION (user 2026-09-04: "please enable dev and god mode so i can
	// test the mock players HUD as well" + "Make sure doors are all opened as
	// well in dev mode") — armed for the v17.36 HUD-typeface pass.
	//
	// DOORS: nothing new was written for that. HARNESS #9 already lives in
	// _tod_main::init() behind this flag and opens all 53 through
	// tod_doors::dev_open_all_doors() (flags, breather unlocks, slabs, navmesh,
	// retired prompts) once the door module reports ready. Power is still NOT
	// flipped — the switch at the bottom works, and the ask was doors.
	//
	// THE MOCK PARTY IS TWO HALVES AND ONLY THIS ONE SELF-GATES. This flag arms
	// _zm_aetherium_hud::mock_party_feed (the bars that MOVE); the fake
	// names/scores/medallions come from TOD_MOCK_PARTY in AetheriumHud.lua,
	// which Lua cannot gate on tod_dev and which is armed by hand in the same
	// edit. *** ALL THREE MUST GO BACK TO false BEFORE PUBLISHING *** —
	// build_map.ps1 -Publish refuses the Lua one, and warns on these two.
	// TEST SESSION 2026-09-05 (user: "Turn on dev and god mode and spawn me at
	// the base tower with all doors opened"). *** BOTH MUST GO BACK TO false
	// BEFORE PUBLISHING *** — build_map.ps1 -Publish warns on them.
	// DISARMED FOR THE v17.95 PUBLISH BUILD (2026-09-05, user: "do a full prep
	// for publish"). The armed run that ends here was the 2026-09-05 spire
	// session: it play-proved the Warden King's summit fight up to the dark
	// deals (the seal, the landing and the max-out all fired) and produced the
	// v17.94 freeze fixes, plus the hound/spire log fixes of v17.92. HARNESS #8
	// and #9 both stay in _tod_main::init(): both sit inside its
	// IS_TRUE( level.tod_dev ) block and do nothing in a shipped build, which is
	// the standing #9 has had since the v17.7 publish. Ship deltas vs the armed
	// state this whole session was tested under are listed at the top of this
	// function — the big ones are upgrades every 4th round instead of every
	// round, Panzer from round 5 instead of 3, the TIER card at 20% instead of
	// 100%, stations capped at 5 uses, the full 191 s finale song, and the real
	// economy instead of the dev money loop.
	// TEST SESSION 2026-09-05 20:5x (user: "enable dev and god mode. I need to get
	// screenshots ... disable the logs that show up on bottom left ... spawn me at
	// the first tower instead of endless spire. All doors open"): dev + god ON,
	// HARNESS #9 live in _tod_main (plain base spawn, every tower door open),
	// and the NEW tod_dev_quiet flag mutes every bottom-left dev print (each
	// print site routes through a per-file tod_quiet_print wrapper, v17.97).
	// *** ALL THREE MUST GO BACK TO false BEFORE PUBLISHING *** — -Publish warns
	// on dev/god; quiet is harmless shipped (nothing prints without dev) but
	// flip it too so the ship state stays three falses.
	// DISARMED FOR THE v17.98 PUBLISH BUILD (2026-09-05 21:xx, user: "turn it all
	// off and prep for publish full rebuild"). The armed run that ends here was
	// the screenshot session (v17.97). HARNESS #9 stays threaded in _tod_main
	// inside its IS_TRUE( level.tod_dev ) block — inert shipped, as since v17.7.
	// TEST SESSION 2026-09-07 (user: "turn on god and dev mode as well",
	// then immediately narrowed it: "dont give me all my upgrade. I just
	// want the unlimited money and god mode").
	//
	// SO tod_dev STAYS OFF. It is a BUNDLE, not a switch -- arming it also
	// gives an upgrade event EVERY round, a Panzer from round 3 on a /3
	// interval, Reaver /2, a TIER card on EVERY deal and unlimited station
	// uses. The user asked for two of those things and none of the rest, and
	// the upgrade spam in particular would drown the very thing being
	// tested. The money loop is now reachable on its own flag below.
	//
	// SHIP STATE — DISARMED for the v18.82 PUBLISH (user 2026-09-10: "prepare a
	// full publish ... Tested and everything is good"). They were armed that day
	// for the floor-10 walkthrough and then the trial-hall test session; harness
	// #8 is parked in _tod_main::init with this edit. build_map.ps1 -Publish
	// refuses while any level.tod_(dev*|god) reads true.
	// SHIP STATE AGAIN 2026-09-13 (v18.98 publish): every flag below false.
	// The staff-test arming of the same day (dev/god/mage_test/maxed) is history.
	// 2026-09-15 (user: "dev mode and god mode should be true. You just need to
	// remove the extra stuff dev mode may be doing that I dont want"). tod_dev is
	// ARMED, and the three lanes of it that were NOT wanted moved onto their own
	// opt-in flags this build: the maxed tier-3 loadout -> tod_dev_maxed
	// (_tod_main::init), the card deal every round + the 100% tier card ->
	// tod_dev_upgrades (_tod_upgrades), unlimited altar uses -> tod_dev_altar.
	// What tod_dev still does: the money loop, and dev logging. Boss cadence has
	// been off it since v16.87.
	level.tod_dev = true;    // 2026-10-07: user requests dev/god and one armored zombie per round for model/walk testing.
	level.tod_god = true;    // 2026-10-07: armed for the user's armored-zombie playtest.
	level.tod_dev_mage_test = false; // 2026-09-13: DISARMED for the v18.98 publish

	// DEV: THE CO-OP RESTART STAND-IN (2026-10-01, user: "Ill also need a way to
	// test coop so maybe we can mock players best possible. I need to test the
	// restart button"). With tod_dev, the Mage preview bot (_tod_dev_mage) joins at
	// round TOD_DEV_COOP_MOCK_ROUND instead of right after the first deal, and from
	// then on it counts as a TEAMMATE ON ANOTHER PC (_tod_gameover::
	// coop_mock_teammate): the host's Restart / End Game take the online co-op lane
	// (the server restart), and when every real player is down the game ends like a
	// wiped party (the bot cannot die). The rounds before it are a normal solo game,
	// so one build tests both. Name starts with tod_dev: -Publish refuses it.
	level.tod_dev_coop_mock = false;  // 2026-10-01: DISARMED - the restart test passed (one press, RESTART_UP 500 ms); the dummy joins right after the first deal again.

	// DEV: THE ARCHMAGE LOOK (2026-10-01, user: "Lets start with archmage. High
	// quality viusals"). With tod_dev: the mana bar refills 3 s after each form
	// (_tod_mage_elements::dev_arch_refill) so the effect can be watched form after
	// form, and the Mage dummy shows the effect every 30 s so it can be seen from
	// outside (tod_dev_mage::run -> dev_arch_preview, visual only). Name starts with
	// tod_dev: -Publish refuses it.
	level.tod_dev_arch_test = false;  // 2026-10-02: DISARMED for the pre-publish test (was ARMED 2026-10-01 for the Archmage look).

	// DEV: EVERY PERK EXCEPT QUICK REVIVE right after the dev class max
	// (_tod_main::dev_all_perks; user 2026-10-01: "spawn me in on dev mode with max
	// perks so i can see the widoes wine change with mage"). Needs tod_dev (the max
	// runs from it). Name starts with tod_dev: -Publish refuses it.
	level.tod_dev_all_perks = false;  // 2026-10-02: DISARMED for the pre-publish test (was ARMED 2026-10-01 for the Mage + Widow's Wine look).

	// DEV: THE ZOMBIE BLOOD SHELF (2026-09-30, user: "can you spawn some in fornt of
	// me in spawn. In dev mode"). With tod_dev, a fan of Zombie Blood drops in front
	// of the host at spawn once the first deal is done, refilled after each grab -
	// _tod_powerups::dev_blood_shelf. Name starts with tod_dev: -Publish refuses it.
	level.tod_dev_blood_shelf = false;  // 2026-09-30: DISARMED for the v19.66 publish.
	// Mage preview player now starts automatically with tod_dev; no extra toggle.

	// DEV MONEY ALONE (2026-09-07). Tops every player up to 100,000 every
	// 2s, and does NOTHING else -- the one piece of tod_dev worth having on
	// its own, because buying doors is how you reach the floors the class
	// tiers gate on. Read by _tod_main::init beside the tod_dev block.
	level.tod_dev_money = false;   // 2026-09-15: DISARMED for the v19.10 publish

	// TEST SESSION: every tower door open from spawn (user 2026-09-07). Same
	// publish gate as god/money -- build_map.ps1 -Publish refuses while armed.
	level.tod_dev_doors = false;  // 2026-09-15: normal door progression.

	// TEST SESSION: tier 3 staff + every domain at its cap on spawn (user
	// 2026-09-07). Name MUST start with tod_dev — build_map.ps1's publish gate
	// matches level\.tod_(dev\w*|god), so this is caught automatically.
	level.tod_dev_maxed = false;   // Independent shortcut; 2026-09-27: tod_dev itself now maxes the chosen class too.

	// TEST SESSION: the UPGRADE-PANEL boost that used to ride level.tod_dev
	// (2026-09-15). Two lanes, one flag: a card deal EVERY round from round 2
	// instead of every 4th (_tod_upgrades::upgrade_round_watch) and
	// tier_card_pct() returning 100 instead of TOD_TIER_CARD_PCT. Both are
	// promotion-flow test lanes; neither belongs in a session that just wants
	// god + money + doors, and a card panel every round is the loud one.
	// Name starts with tod_dev so build_map.ps1:250 still refuses -Publish.
	level.tod_dev_upgrades = false;   // 2026-09-15: normal cadence, normal tier odds.

	// UNLIMITED UPGRADE-ALTAR USES (user 2026-09-07: "on dev mode can you make
	// me have unlimited alter uses at spawn"). Read by
	// _tod_upgrades::station_depleted beside the tod_dev test it already had --
	// that lane has been there since 2026-08-21, but it hangs off the BUNDLE,
	// and the bundle is exactly what this session is keeping off. Third flag
	// cut off tod_dev for the same reason as the first two, and the last word
	// on why is the block above: it is not a switch.
	//
	// NOT scoped to the spawn altar. The ask names it because that is where you
	// stand while building a loadout, but a cap that reappears at the first
	// breather is a worse surprise than one that never appears, and the tod_dev
	// behaviour this mirrors was always every terminal.
	//
	// Caught by the SAME publish gate: build_map.ps1's pattern is
	// `level\.tod_(dev\w*|god)\s*=\s*true` (:250), so any tod_dev<anything>
	// refuses -Publish without a further edit there. Verified by running it.
	level.tod_dev_altar = false;   // 2026-09-09: normal playtest; altar debug bypass disabled.

	level.tod_dev_quiet = false;   // 2026-09-23: DISARMED for the v19.50 publish (armed with tod_dev on 2026-09-21 so IPrintLn spam did not cover the RAPID FLAME cards). Console PrintLn logs and IPrintLnBold toasts are unaffected either way.
	                              // WHEN IT IS ARMED it is armed WITH tod_dev on purpose: a
	                              // prompt-card walkthrough is a judgement of the CARDS, and an
	                              // armed build otherwise pours scatter/hellhound/input-probe
	                              // IPrintLn over the HUD — the very thing being looked at.
	                              // This is the screenshot lane v17.97 added for that case.
}
