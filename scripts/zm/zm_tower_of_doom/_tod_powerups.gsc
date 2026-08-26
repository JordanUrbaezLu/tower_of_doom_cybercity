// =============================================================================
// _tod_powerups.gsc — the map's custom powerup DROPS.
//
//   "tod_free_pap"  — the PERK BOTTLE drop. Instant, grabber-only, gated on
//     power. Grants a random perk the grabber does not already own.
//     NAME IS HISTORICAL: it granted a free Pack-a-Punch until 2026-08-21,
//     when the user reported (twice) that "the perk drop doesn't give me any
//     perks" — the drop uses the stock zombie_pickup_perk_bottle model, so it
//     READS as a perk drop and a PaP grant was invisible/confusing. The
//     powerup id is kept so the .csc include and the clientfield stay in
//     lockstep; only the grant changed. If every perk is already owned the
//     drop is still CONSUMED (a GiveMaxAmmo consolation) rather than left
//     stranded — on solo there is no teammate to leave it for.
//
// The OP weapon drop is the Gift of Death (Xmas Gun) — install_gift_of_death()
// overrides the stock Death Machine grant + installs fixed-shots damage. This
// module also reworks INSTA-KILL into a team-wide 3x damage window.
//
// (The admin-gun drop was removed on user order 2026-08-20.)
//
// Client half: _tod_powerups.csc (include + add for tod_free_pap).
// =============================================================================

#using scripts\shared\flag_shared;   // power_on gate on the free-PaP drop
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_perks;      // give_random_perk — the bottle grants a PERK
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;      // breather Pack-a-Punch charges points
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;   // can_upgrade_weapon / get_upgrade_weapon (vendor stock lane)
#using scripts\zm\zm_tower_of_doom\_tod_classes;   // is_class_primary (vendor: which lane)
#using scripts\zm\_zm_weapons;
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;   // push_dmg_num (crosshair numbers)

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_powerups.gsh;

#precache( "string", "" );
#precache( "model", "p7_zm_vending_packapunch_on" );   // breather Pack-a-Punch vendor mesh

// Gift of Death (Xmas Gun) grants on the Death Machine drop with FIXED
// shots-to-kill, round-independent: damage = health / shots, per archetype.
// 15 — HALF of stock N_POWERUP_DEFAULT_TIME (user 2026-08-25: "Make zombie blood
// last half as long as it currently does"). This is a BALANCE call, and the
// distinction matters for whoever tunes it next: the powerup was briefly cut to
// 10 earlier today for PERFORMANCE, on a rationale that turned out to be false
// (see the re-add note in init() — Zombie Blood never slowed the game; Time Warp
// did). It went back to 30, and this 15 is the deliberate balance choice on top
// of the corrected baseline, not a repeat of that mistake.
//
// The reason a shorter window earns its keep now: level.zombie_ai_limit went
// 24 -> 45 on 2026-08-25, so a window in which nothing dies fills a much bigger
// board than the 30 was originally tuned against.
#define TOD_BLOOD_SECS     15

// DROP RATES (user 2026-08-24: "We need to reduce the rate of pap drops cause
// they drop very often. I would say lets half the rate it currently is. And we
// need to drop the rate of death machine drop too. We can do half as well").
//
// HOW HALVING WORKS HERE, because it is not a weight table: stock picks a drop by
// shuffling level.zombie_powerups and taking the first entry whose
// func_should_drop_with_regular_powerups returns true — and on a false it picks
// AGAIN in a while(1) (_zm_powerups.gsc:377-386). So a should-drop that returns
// true only half the time gives that powerup exactly half its old share of
// drops, and the re-roll hands the other half to the rest of the pool. No stock
// edit, no weight plumbing, and the total drop RATE is unchanged — only the mix.
//
// The loop terminates because the always-drop powerups (insta-kill, double
// points, max ammo, nuke, carpenter) never refuse.
// HALVED AGAIN 2026-08-24 (user: "we need to fix is the amount of pap power up
// drops that drop. Lets reduce that probability again"). 50 -> 25, so the PaP
// now takes a QUARTER of the share it had before the first cut. Read the
// mechanism note below before changing it again: this is not a weight, it is a
// per-roll gate, and the re-roll hands the refused share to the rest of the
// pool — so 25 means "a quarter as often", not "25% of all drops".
// The DEATH MACHINE is deliberately untouched at 50: only PaP was named.
#define TOD_PAP_DROP_PCT      25   // free-PaP drop: a quarter of its former share
#define TOD_MINIGUN_DROP_PCT  50   // Death Machine (= the Gift of Death here): same
#define XMAS_ZOMBIE_SHOTS  2     // normal zombie (bosses handled in _tod_bosses)
#define TOD_BREATHER_PAP_COST  5000   // stock PaP price

#namespace tod_powerups;

REGISTER_SYSTEM( "tod_powerups", &__init__, undefined )

function __init__()
{
	// FREE PACK-A-PUNCH (instant). register_powerup auto-includes the name
	// server-side; ORDER: every level.zombie_powerups[name].* setter (e.g.
	// can_pick_up_in_last_stand) MUST come AFTER add_zombie_powerup — the
	// struct it writes only exists post-add (live crash 2026-08-20).
	// DROP MODEL = the stock perk bottle (user 2026-08-20: the scaled Chaos
	// PaP-machine mesh read as an unrecognizable "frame" and its base-pivot
	// offset the visual from the grab origin — "couldn't grab it"). The bottle
	// is a clean, centered, reliably-grabbable powerup that still glows blue
	// on solo. (A PaP-machine-look drop needs a pivot-centered custom mesh —
	// revisit later.)
	zm_powerups::register_powerup( "tod_free_pap", &grab_free_pap );
	zm_powerups::powerup_set_prevent_pick_up_if_drinking( "tod_free_pap", true );
	// POWER GATE (user 2026-08-21: "those drops should only start dropping
	// once power is on"). should_drop_free_pap replaces the stock always-drop.
	zm_powerups::add_zombie_powerup( "tod_free_pap", "zombie_pickup_perk_bottle", &"", &should_drop_free_pap, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE );
	zm_powerups::powerup_set_can_pick_up_in_last_stand( "tod_free_pap", 0 );

	// ---------------------------------------------------------------------
	// FREE PACK-A-PUNCH (user 2026-08-21) — its OWN drop again, now that a
	// real pickup model exists. Model `free_packapunch` = ZoekMeMaar's
	// purpose-built gold mini-PaP (pivot-CENTRED; the chaos machine mesh was
	// base-pivoted and read as a frame at drop scale). CREDIT ZoekMeMaar.
	// Power-gated for the same reason the perk bottle is: a free PaP before
	// the switch is thrown would skip the map's whole power gate.
	// ---------------------------------------------------------------------
	zm_powerups::register_powerup( "tod_pap", &grab_pap );
	zm_powerups::powerup_set_prevent_pick_up_if_drinking( "tod_pap", true );
	// HALVED 2026-08-24 — its own gate now, not the shared should_drop_free_pap.
	// The PERK BOTTLE (tod_free_pap, above) keeps the plain power gate: the user
	// asked about "pap drops", and the bottle is a random PERK, not a PaP.
	zm_powerups::add_zombie_powerup( "tod_pap", "free_packapunch", &"", &should_drop_pap, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE );
	zm_powerups::powerup_set_can_pick_up_in_last_stand( "tod_pap", 0 );

	// ---------------------------------------------------------------------
	// ZOMBIE BLOOD (user 2026-08-21) — model + vox from the NSZ powerup pack
	// (CREDIT NSZ). Grabber-only: for TOD_BLOOD_SECS the zombies stop
	// targeting you and you cannot be hurt. NO screen effect — the visionset
	// that used to be here was UNREGISTERED IN THIS MAP and a live bug; the long
	// note in zombie_blood_window() explains what it broke and what a real one
	// needs.
	//
	// RE-ENABLED 2026-08-25 — AND THE 2026-08-21 REMOVAL WAS A MISATTRIBUTION.
	// Worth recording properly, because the CHANGELOG states the old rationale as
	// fact and it does not hold.
	//
	// (It came back at its original 30s on 2026-08-25 and was then HALVED to 15
	// the same day on user instruction — "make zombie blood last half as long as
	// it currently does". TOD_BLOOD_SECS is 15; an earlier version of this
	// comment still said "AT ITS ORIGINAL 30s" and contradicted the #define four
	// screens up. Corrected 2026-08-26.)
	//
	// The drop was disabled in v8.5 citing "remove blood money or fix it - it
	// slows the whole game, not just zombies", with a rationale about a 30s
	// ignoreme window ballooning the horde and an "ignoreme repath storm"
	// tanking the server frame. Two things are wrong with that:
	//
	//   1. THE COMPLAINT WAS ABOUT TIME WARP (user 2026-08-25: "when I said that
	//      I was talking about the time warp drop not zombie blood"). The SAME
	//      v8.5 batch carries a Time Warp entry quoting the same sentence — one
	//      complaint applied to two systems, and the wrong one was removed.
	//   2. THE RATIONALE DOES NOT SURVIVE READING THE CODE. zombie_blood_window
	//      sets a flag, enables invulnerability and waits; the laststand guard is
	//      one waittill. No loop, no per-frame work, and ignoreme is a single
	//      field on the PLAYER — there is no repath storm.
	//
	// WHAT ACTUALLY FIXED IT is in the same batch: Logical's Time Warp pack was
	// calling player-only SetMoveSpeedScale on EVERY axis AI EVERY FRAME, bosses
	// included (custom-locomotion bosses stutter when their rate is stomped).
	// tod_warp_target() in scripts/zm/logical/powerups/_zm_powerup_timewarp.gsc
	// :163 now excludes bosses and non-zombies, and the loop re-asserts at 4 Hz
	// (wait 0.25, :204) instead of per frame. Verified still live 2026-08-25.
	//
	// THE ONE REAL CAVEAT: level.zombie_ai_limit went 24 -> 45 today, so 30s in
	// which nothing dies fills a bigger board than it used to. That is a BALANCE
	// question for play, not the performance problem this was blamed for.
	// Shorten the window if it feels bad; do not shorten it "for frame time".
	// ---------------------------------------------------------------------
	// TRAY TIMER (live report 2026-08-26: "zombie blood doesn't show in the
	// bar"): the trailing three args put the window on the Aetherium powerup
	// tray via the STOCK timed-powerup lane — add_zombie_powerup registers the
	// 2-bit "toplayer" clientfield, and stock's powerup_hud_monitor drives it
	// every server frame from the per-player on/time vars that
	// zombie_blood_window() now maintains (grabber-only powerups read
	// player.zombie_vars and are gated on player._show_solo_hud — the exact
	// contract the stock Death Machine uses, _zm_powerup_weapon_minigun.gsc).
	// The clientfield name MUST match the .csc add AND the tray row in
	// AetheriumPowerupsContainer.lua ("tod_zombie_blood" in all three).
	zm_powerups::register_powerup( "tod_zombie_blood", &grab_zombie_blood );
	zm_powerups::powerup_set_prevent_pick_up_if_drinking( "tod_zombie_blood", true );
	zm_powerups::add_zombie_powerup( "tod_zombie_blood", "zombie_blood", &"", &zm_powerups::func_should_always_drop, POWERUP_ONLY_AFFECTS_GRABBER, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE, undefined, "tod_zombie_blood", "zombie_powerup_zombie_blood_time", "zombie_powerup_zombie_blood_on" );
	zm_powerups::powerup_set_can_pick_up_in_last_stand( "tod_zombie_blood", 0 );

	// BREATHER PACK-A-PUNCH vendors (see below) — one per rest balcony.
	level thread breather_pap_spawn();
	level thread pap_power_hint();   // "REQUIRES POWER" copy while the switch is off
}

// ---------------------------------------------------------------------------
// BREATHER PACK-A-PUNCH (user 2026-08-22) — a standalone vendor per balcony
// ---------------------------------------------------------------------------
// WHY IT EXISTS: the CLASS TIER card requires the class gun Pack-a-Punched
// (tier_card_eligible), but the map's only PaP machine sits in the CROWN,
// above all 50 laps — unreachable during the climb where the gun is actually
// maxed. So the promotion could never fire (user: "I maxed out my Enfield and
// was never able to upgrade my class"). One machine per breather (floors
// 10/20/30/40) makes PaP reachable, which makes the tier ladder reachable.
//
// WHY SCRIPT-SPAWNED AND NOT THE STOCK PREFAB — HARD-WON, DO NOT "SIMPLIFY":
// a SECOND stock `zm_pack_a_punch` zbarrier FATALS THE MAP LOAD. Stock
// _zm_pack_a_punch::spawn_init renames EVERY such zbarrier to the shared
// "vending_packapunch", then vending_weapon_upgrade() does a SINGULAR
// GetEnt("vending_packapunch") that errors with two or more. Map 1 paid for
// this exact lesson (its CHANGELOG, "Working 2nd Pack-a-Punch in Paradise":
// standalone custom vendor, never the stock zbarrier) and v9.16 re-paid it —
// 4 breather PaP prefabs in the .map and the map would not load. This vendor
// never carries that targetname, so the crown machine is untouched.
//
// HOW IT PACKS: NOT via the stock upgrade path. It latches
// player.tod_pap_owned — the SAME proven lane the free-PaP drop uses
// (grab_pap below) — and _tod_upgrades::reconcile_twin pulls the class gun to
// its `_up` form on its next 1s tick, building a variant name we KNOW the
// generator emitted. NO DIRECT CALL, DELIBERATELY: _tod_upgrades #usings THIS
// module, so importing it back would be a circular #using (the KB cycle rule).
function breather_pap_spawn()
{
	level endon( "end_game" );
	// This is threaded from __init__ (system registration), which runs EARLIER
	// than the tod module init() chain — the flag may not be defined yet, and
	// flag::wait_till on an undefined flag is not safe. Wait for it to EXIST
	// first, then for it to be set.
	while ( !( level flag::exists( "initial_blackscreen_passed" ) ) )
		wait 0.05;
	level flag::wait_till( "initial_blackscreen_passed" );

	// Breather laps are 10/20/30/40 — all EVEN, so every balcony is the
	// mirrored (SW) one: floor x[-800,-256], y[-992,-416] (gen_tower_map.js,
	// v9.37 expansion). Already occupied: the two PERK pads on the south wall
	// (y -959, x -360 / -536), the UPGRADE STATION on the west wall (model
	// -760,-600; trigger -704,-600, radius 64) and the TELEPORTER pad in the
	// SE quarter (-640,-800, ~167u ring, trigger radius 110). The PaP takes
	// the NORTH edge facing SOUTH into the floor — yaw 359.999 = front toward
	// -y, the live-verified vending convention on this map. Nearest neighbour
	// (the teleporter trigger) is ~430u away, well clear of our 64u radius.
	// Breather mid z = (lap-1) * 384 + 192.
	zs = array( 3648, 7488, 11328, 15168 );
	foreach ( z in zs )
		breather_pap_place( ( -320, -470, z ), ( -320, -526, z ), 359.999 );
}

// One vendor: the machine model plus its own use trigger.
function breather_pap_place( model_org, trig_org, yaw )
{
	m = Spawn( "script_model", model_org );
	m.angles = ( 0, yaw, 0 );
	m SetModel( "p7_zm_vending_packapunch_on" );   // packed (assetlist-verified)
	// DELIBERATELY NOT SOLID: the navmesh ignores entity collision entirely
	// (KB §navmesh), so a solid machine would need DisconnectPaths and would
	// still be a grinding spot for the horde on a small balcony. The model is
	// the landmark; the trigger is the interaction.

	t = Spawn( "trigger_radius_use", trig_org, 0, 64, 100 );
	t TriggerIgnoreTeam();      // REQUIRED for a script-spawned use-trigger
	t SetCursorHint( "HINT_NOICON" );
	t SetHintString( "Hold ^3[{+activate}]^7 ^5PACK-A-PUNCH ^2[Cost: " + TOD_BREATHER_PAP_COST + "]" );
	t thread breather_pap_use_loop();
	t thread breather_pap_power_hint();   // <- the unpowered state (2026-08-25)
}

// self = trigger. THE UNPOWERED STATE FOR THE FOUR BREATHER PACK-A-PUNCHES
// (live report 2026-08-25: "pack when power isnt on it doesnt say turn on power
// like other powered system").
//
// THESE FOUR ARE THE ONLY PACK-A-PUNCHES A PLAYER CAN REACH BEFORE THE FINALE,
// so they are the machines the report is about. Until now they carried ONE
// hint, stamped once at spawn, advertising the full buy card and a 5,000 price
// while power was off — and breather_pap_use_loop refused with nothing but a
// deny sound. The machine looked broken rather than unpowered.
//
// THE WORDING IS NOT FREE, AND THIS IS THE TRAP THAT MADE THE FIRST ATTEMPT AT
// THIS DEAD ON ARRIVAL. ZMCursorHintNew.lua routes hints by keyword:
//   isPAPHint (:205-213)  ->  "pack" AND "punch"  ->  the STATIC Pack-a-Punch
//                             card, which draws its own fixed title, blurb and
//                             cost and NEVER reads the hint text. Any power copy
//                             containing the machine's own name is therefore
//                             invisible by construction.
//   isPowerRequiredHint (:156-162)  ->  the literal substring
//                             "you must turn on the power first"  ->  the kit's
//                             dedicated Power Required card.
// So the line below deliberately does NOT name the machine, and DOES carry that
// exact sentence — which is also what every perk machine says, i.e. literally
// "like other powered systems".
//
// Edge-driven, not polled: two SetHintString calls per machine per game. Every
// distinct hint string costs a slot in the engine's trigger-string table, which
// is the config-string discipline the door price watcher documents.
function breather_pap_power_hint()
{
	level endon( "end_game" );

	// The flag may not exist yet — waiting on a flag that has not been created
	// negates undefined and fatals the server script (the 2026-08-25 crash
	// documented in pap_power_hint below).
	while ( !( level flag::exists( "power_on" ) ) )
		wait 0.1;

	if ( level flag::get( "power_on" ) )
		return;                       // already powered — the buy line stands

	if ( !isdefined( self ) )
		return;
	self SetHintString( "^1NO POWER^7 - you must turn on the power first" );

	level flag::wait_till( "power_on" );
	if ( !isdefined( self ) )
		return;
	self SetHintString( "Hold ^3[{+activate}]^7 ^5PACK-A-PUNCH ^2[Cost: " + TOD_BREATHER_PAP_COST + "]" );
}

// self = trigger
function breather_pap_use_loop()
{
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( "trigger", player );

		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( player laststand::player_is_in_laststand() )
			continue;
		// A revive press is not a purchase (_zm_blockers.gsc:307 — stock checks
		// this on every buy path). Reviving polls the raw USE button
		// (_zm_laststand.gsc:1129), so without this the press that revives a
		// teammate ALSO buys a 5000-point pack. Silent, like the laststand
		// branch above: the player is holding use.
		if ( player zm_utility::in_revive_trigger() )
			continue;
		// Power gates every PaP on this map (the switch is at the base).
		if ( !( level flag::exists( "power_on" ) ) || !( level flag::get( "power_on" ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		// (v10.4, audit find: the tod_pap_owned refusal used to sit HERE, above
		// the lane split — so once the class primary was packed the vendor
		// refused EVERYTHING, including a sidearm the stock lane below could
		// upgrade fine. The latch check now lives inside the class-gun lane,
		// where it belongs: it is a fact about the class gun only.)
		// Never while holding a temporary powerup gun — its restore would
		// fight the swap (same guard grab_pap uses).
		if ( isdefined( player.zombie_vars ) && IS_TRUE( player.zombie_vars[ "zombie_powerup_minigun_on" ] ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		if ( !( player zm_score::can_player_purchase( TOD_BREATHER_PAP_COST ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		// v10.3 (playtest 2026-08-23: "Enfield, Knife, MR6. Pap machine doesnt
		// work but grabbing the power up worked for MR6"): the vendor used to
		// latch tod_pap_owned UNCONDITIONALLY — which only reconcile_twin acts
		// on, and reconcile only ever touches the CLASS PRIMARY. Paying while
		// holding the MR6 (or any sidearm) took the points and did NOTHING.
		// The free-PaP drop never had this hole: grab_pap has always carried a
		// second, stock-path lane for non-class weapons. The vendor now has
		// the same two lanes:
		//  - class primary in hand -> the latch (reconcile swaps within 1s;
		//    since v10.2 the lookup resolves either asset spelling)
		//  - anything else in hand -> the stock upgrade path, inline
		w = player GetCurrentWeapon();
		// v10.7 (peer catch off CZ's second comment, 2026-08-23): the v10.3 lane
		// keyed PURELY off the weapon in hand — so a player holding their PISTOL
		// paid 5000 and got a PaP'd pistol while the class gun stayed dry. On a
		// map whose identity is the class gun, with the pistol as the starting
		// weapon, that is "my AR didn't get pap'd" with the points buying the
		// wrong thing instead of nothing. The sidearm lane now opens ONLY once
		// the class gun is ALREADY packed: the class gun is always the vendor's
		// first sale regardless of what is in hand (the latch lane below packs
		// it even while a sidearm is held — reconcile swaps it in inventory),
		// and the MR6-after-class-gun case the playtest reported stays served.
		// v10.30 (user 2026-08-25: "When i pack my secondary before my primary is
		// packed and im holding my secondary when i pap my primary will get
		// papped. It should pap the gun im holding"). THE v10.7 GATE IS REMOVED:
		// this lane no longer requires the class gun to be packed first.
		//
		// WHAT v10.7 WAS PROTECTING AND WHY IT NO LONGER APPLIES: back then the
		// only sidearm was the starting MR6, so "pack what is in hand" mostly
		// meant "accidentally pack the pistol you spawned holding" and lose 5000.
		// Since the secondary ladder (2026-08-24) every class carries a real,
		// chosen, tier-appropriate sidearm that a player may very reasonably want
		// packed first — and the gate made that impossible, silently packing the
		// PRIMARY instead while the player watched their secondary stay dry.
		// Taking the points and upgrading a gun the player is not holding is the
		// worse failure of the two.
		//
		// THE TRADE IS ACCEPTED, NOT OVERLOOKED: holding the MR6 at the vendor
		// now packs the MR6. That is the standard zombies contract — the machine
		// packs what you are holding — and it is predictable, which the two-lane
		// rule never was.
		if ( isdefined( w ) && w != level.weaponNone
		     && !( tod_classes::is_class_primary( player, w ) ) )
		{
			if ( !( zm_weapons::can_upgrade_weapon( w ) ) )
			{
				player PlaySound( "zmb_no_purchase" );
				continue;   // already upgraded / not upgradable — refuse, keep the points
			}
			up = zm_weapons::get_upgrade_weapon( w, false );
			if ( !isdefined( up ) )
			{
				player PlaySound( "zmb_no_purchase" );
				continue;
			}
			player PlaySound( "zmb_cha_ching" );
			player zm_score::minus_to_player_score( TOD_BREATHER_PAP_COST );
			player TakeWeapon( w );
			up = player zm_weapons::weapon_give( up );
			if ( isdefined( up ) )
			{
				player GiveStartAmmo( up );
				player notify( "weapon_give", up );
				player SwitchToWeapon( up );
			}
			else
			{
				player zm_weapons::weapon_give( w );   // give failed — never strand them unarmed
			}
			player PlayLocalSound( "free_packapunch_vox" );
			wait 0.5;
			continue;
		}

		// CLASS-GUN LANE: refuse a second buy on an already-packed class gun
		// (the latch survives until a tier-up clears it).
		if ( IS_TRUE( player.tod_pap_owned ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		player PlaySound( "zmb_cha_ching" );
		player zm_score::minus_to_player_score( TOD_BREATHER_PAP_COST );
		player.tod_pap_owned = true;   // reconcile_twin swaps to the _up form within 1s
		player PlayLocalSound( "free_packapunch_vox" );
		wait 0.5;   // debounce a held use
	}
}

// ---------------------------------------------------------------------------
// FREE PACK-A-PUNCH DROP (user 2026-08-21) — its own drop, own model
// ---------------------------------------------------------------------------
// WHY THIS DOES NOT USE THE STOCK UPGRADE PATH: the previous version called
// can_upgrade_weapon -> get_upgrade_weapon -> TakeWeapon/weapon_give, and it
// PaP'd the PISTOL fine but never the class guns (user report). Rather than
// keep guessing at which stock gate rejected the twins, we latch a flag and
// let _tod_upgrades::reconcile_twin do the swap — it builds
// `<primary><up_suffix><twin suffix>`, a name we KNOW the generator emitted,
// and it already owns the proven give->switch->ammo-delta->take-last order.
// Non-class weapons (the pistol) still take the stock path, which demonstrably
// works for them.
// self = the drop entity; player = the toucher. Return TRUE = NOT consumed.
function grab_pap( player )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return true;
	if ( player laststand::player_is_in_laststand() )
		return true;
	if ( isdefined( player.is_drinking ) && player.is_drinking > 0 )
		return true;
	// never PaP a temporary weapon-powerup gun (Gift of Death / Death Machine)
	if ( isdefined( player.zombie_vars ) && IS_TRUE( player.zombie_vars[ "zombie_powerup_minigun_on" ] ) )
		return true;

	player PlayLocalSound( "free_packapunch_vox" );

	// CLASS GUN — the reliable lane. We only LATCH the flag; the swap itself
	// happens on the next tick of _tod_upgrades::body_systems_loop, which
	// already calls reconcile_twin() once a second.
	// NO DIRECT CALL, DELIBERATELY: _tod_upgrades #usings THIS module (for
	// max_ammo_clip_watch), so importing it back would be a circular #using —
	// the KB cycle rule. The <=1s latency is invisible next to the pickup
	// animation.
	// v10.30 (user 2026-08-25: "Free pap drop should pap the gun you have out").
	// MATCHED TO THE VENDOR. This used to pack the CLASS GUN first no matter
	// what was in hand, and only fell through to the held weapon once the class
	// gun was already packed — the same asymmetry the breather vendor had, and
	// the same surprise: grab the drop holding your sidearm and your PRIMARY
	// quietly got packed instead.
	//
	// ORDER, and why the fallbacks are in this order: the drop must NEVER be
	// stranded — on solo there is no teammate to leave it for, so every path
	// below ends in something being consumed.
	//   1. holding a NON-class weapon that can be upgraded -> pack THAT (stock path)
	//   2. otherwise, class gun not yet packed             -> latch it
	//   3. otherwise                                        -> consolation max ammo
	// Step 2 is what catches "holding an already-packed sidearm": rather than
	// waste the drop, it goes to the class gun, which is still the most valuable
	// thing it can do at that moment.
	w = player GetCurrentWeapon();

	held_is_class = ( isdefined( w ) && w != level.weaponNone
	                  && tod_classes::is_class_primary( player, w ) );

	// CLASS GUN — the reliable lane, taken when the class gun is what is in
	// hand. We only LATCH the flag; reconcile_twin does the swap within 1s.
	if ( held_is_class && !IS_TRUE( player.tod_pap_owned ) )
	{
		player.tod_pap_owned = true;
		return;   // consumed
	}

	// NON-CLASS WEAPON IN HAND — the stock upgrade path, on the gun you are
	// actually holding.
	if ( !held_is_class && isdefined( w ) && w != level.weaponNone && zm_weapons::can_upgrade_weapon( w ) )
	{
		up = zm_weapons::get_upgrade_weapon( w, false );
		if ( isdefined( up ) )
		{
			player TakeWeapon( w );
			up = player zm_weapons::weapon_give( up );
			if ( isdefined( up ) )
			{
				player GiveStartAmmo( up );
				player notify( "weapon_give", up );
				player SwitchToWeapon( up );
				return;   // consumed
			}
			// give failed — hand the original back rather than strand them
			player zm_weapons::weapon_give( w );
		}
	}

	// FALLBACK 2: the held weapon could not take it (already packed, or not
	// upgradable, or the give failed). Spend it on the class gun if that is
	// still dry — better than burning the drop on ammo.
	if ( !IS_TRUE( player.tod_pap_owned ) )
	{
		player.tod_pap_owned = true;
		return;   // consumed
	}

	// FALLBACK 3: everything that could be packed already is — consolation ammo.
	if ( isdefined( w ) && w != level.weaponNone )
		player GiveMaxAmmo( w );
	// consumed
}

// ---------------------------------------------------------------------------
// ZOMBIE BLOOD (user 2026-08-21) — the panic button
// ---------------------------------------------------------------------------
// For TOD_BLOOD_SECS the grabber is INVISIBLE to the horde and cannot be hurt.
// `player.ignoreme` is the stock lever the AI honours for target selection —
// far simpler and safer than the pack's own enemy-override hook, which would
// have needed a patch into the zombie targeting path.
// EnableInvulnerability covers the frame or two where an already-swinging
// zombie would otherwise land a hit.
function grab_zombie_blood( player )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return true;
	if ( player laststand::player_is_in_laststand() )
		return true;

	player thread zombie_blood_window();
	// consumed
}

// self = player
function zombie_blood_window()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	// Re-grabbing RESTARTS the window rather than stacking two threads that
	// would each try to clear the state (the second clear would end it early).
	self notify( "tod_blood_restart" );
	self endon( "tod_blood_restart" );

	self PlayLocalSound( "zombie_blood_vox" );
	self.ignoreme = true;
	self.tod_in_blood = true;
	self EnableInvulnerability();

	// HUD TRAY FEED (2026-08-26). Stock's powerup_hud_monitor reads these two
	// per-player vars every server frame for any grabber-only powerup whose
	// add_zombie_powerup carried a clientfield (ours does now, see __init__) —
	// but ONLY while player._show_solo_hud is true; that flag is the stock
	// gate on the whole per-player branch (weapon_powerup sets it the same way
	// for the Death Machine window). The countdown loop below replaces the old
	// plain `wait TOD_BLOOD_SECS` so the monitor sees the time shrink and runs
	// the expiring-flash stages itself.
	if ( !isdefined( self.zombie_vars ) )
		self.zombie_vars = [];
	self.zombie_vars[ "zombie_powerup_zombie_blood_on" ] = 1;
	self.zombie_vars[ "zombie_powerup_zombie_blood_time" ] = TOD_BLOOD_SECS;
	self._show_solo_hud = true;

	// NO VISIONSET HERE, AND THE ONE THAT USED TO BE HERE WAS A LIVE BUG
	// (2026-08-26). The line read:
	//
	//     self visionset_mgr::activate( "overlay", "zm_bgb_in_plain_sight", self, 2, 15, 2 );
	//
	// `zm_bgb_in_plain_sight` IS NOT REGISTERED IN THIS MAP. visionset_mgr
	// resolves by REGISTRATION, not by asset existence, so that alone is fatal.
	//
	// BE PRECISE, because the first version of this comment was WRONG and said
	// "the name was invented" (corrected 2026-08-26 after adversarial review).
	// THE NAME IS REAL — retail ships both the vision and the gum scripts:
	//     zone_source/all/assetlist/zm_common.csv:1831
	//         rawfile,vision/zm_bgb_in_plain_sight.vision
	//     zone_source/all/assetlist/zm_patch.csv:489-490
	//         _zm_bgb_in_plain_sight.gsc / .csc
	//
	// What is true is narrower, and still fatal: the mod tools ship only a STUB
	// BGB system (share/raw/scripts/zm/_zm_bgb.gsc is 17 lines of empty function
	// bodies, and no per-gum scripts exist at all), so whatever registers this
	// visionset at retail is in no tree we compile — and NOTHING in this usermap
	// calls visionset_mgr::register_info for it. A sweep of all 1223 script-like
	// files under the mod tools root finds the literal ONLY in this comment; the
	// single stock occurrence of the concept is the boolean
	// `entity.enemy.bgb_in_plain_sight_active` (shared/ai/zombie.gsc:393).
	//
	// So: the asset existing does not help us. activate() looks the name up in
	// level.vsmgr, and an unregistered name is simply absent from that table.
	//
	// WHY THAT WAS NOT MERELY COSMETIC: visionset_mgr::activate opens with
	//
	//     if ( level.vsmgr[type].info[name].state.should_activate_per_player )
	//
	// (visionset_mgr_shared.gsc:52) — an UNCONDITIONAL field dereference. With
	// the name unregistered, `.info[name]` is undefined and `.state` on undefined
	// is a script runtime error, so this thread DIED ON THIS LINE. Everything
	// below it never ran: the laststand guard never started, the wait never
	// elapsed, and zombie_blood_clear() NEVER FIRED — which left the grabber
	// `ignoreme = true` and INVULNERABLE for the rest of the match off a single
	// pickup. The powerup was a permanent god-mode toggle, not a 15s window.
	//
	// Zombie Blood is deliberately left with NO screen effect rather than a
	// substitute one: the mechanic is carried by ignoreme + invulnerability, the
	// grab already announces itself with zombie_blood_vox, and inventing a second
	// visionset name is exactly how this bug happened. If a visual is wanted
	// later it needs a REAL registration — visionset_mgr::register_info in an
	// __init__ plus the asset on a `visionset,` line in the .zone — and it must
	// be verified in game, not assumed.

	// Going down mid-window must not leave the player permanently ignored.
	self thread zombie_blood_laststand_guard();

	// Count the window down where the HUD monitor can watch it (a re-grab
	// kills this thread via tod_blood_restart and the fresh thread re-sets
	// the time to full — same restart contract as before).
	while ( IS_TRUE( self.tod_in_blood ) && self.zombie_vars[ "zombie_powerup_zombie_blood_time" ] > 0 )
	{
		// KEEP-ALIVE — the same doctrine as the zombie-gait sweep, and for the
		// same reason: a one-shot write gets undone by a system that owns the
		// field on a timer.
		//
		// STOCK OWNS .ignoreme THROUGH A REFCOUNT, AND CLEARS IT 2 SECONDS AFTER
		// A REVIVE (N_REVIVE_VISIBILITY_DELAY, _zm_laststand.gsc:42, applied at
		// :1374/:1472) — that pending decrement writes the boolean
		// UNCONDITIONALLY (_zm_utility.gsc:3852). So: go down, get revived, grab
		// a blood drop inside the next 2s, and the decrement fires mid-window and
		// kills 13 of the 15 seconds of invisibility while invulnerability stays
		// on. Reads to the player as "zombie blood did nothing". Reachable SOLO
		// too — Quick Revive's auto_revive arms the same delay.
		//
		// The IS_TRUE( tod_in_blood ) term in the loop head is LOAD-BEARING:
		// zombie_blood_clear() sets tod_in_blood undefined, so a mid-window down
		// stops this re-assert instead of forcing ignoreme = true onto a crawler
		// and stealing stock's last-stand reference.
		self.ignoreme = true;
		wait 0.05;
		self.zombie_vars[ "zombie_powerup_zombie_blood_time" ] = self.zombie_vars[ "zombie_powerup_zombie_blood_time" ] - 0.05;
	}

	self zombie_blood_clear();
}

// self = player
function zombie_blood_laststand_guard()
{
	self endon( "disconnect" );
	self endon( "tod_blood_restart" );
	level endon( "end_game" );

	self waittill( "player_downed" );
	// THIS GUARD OUTLIVES ITS OWN WINDOW. Nothing notifies it when the 15s
	// expires normally, and its endons are only disconnect / tod_blood_restart /
	// end_game — so it stays parked here and fires on an UNRELATED down rounds
	// later, stripping stock's last-stand ignoreme (making the player instantly
	// targetable the moment they are revived) along with the rest of the blood
	// state. Latent since the powerup was written; it got sharper on 2026-08-26
	// when zombie_blood_clear() gained the HUD-timer writes.
	//
	// tod_in_blood is set on entry and cleared by zombie_blood_clear() on EVERY
	// exit path, so it is the exact, future-proof test — better than adding a
	// "blood over" notify and a fourth endon, because it stays correct against
	// any future exit that calls clear() directly. (Until now the field had two
	// writes and zero readers repo-wide, which is the tell that this is what it
	// was always meant for.)
	if ( !IS_TRUE( self.tod_in_blood ) )
		return;   // window already ended — this down is not ours to clear
	self zombie_blood_clear();
}

// self = player. Idempotent — safe to call from either exit path.
function zombie_blood_clear()
{
	if ( !isdefined( self ) )
		return;
	// DON'T STOMP STOCK'S REFCOUNT. Last stand does not own .ignoreme directly —
	// it owns a COUNT (_zm_laststand.gsc:201 set_ignoreme(true) ->
	// zm_utility::increment_ignoreme, _zm_utility.gsc:3833) and derives the
	// boolean from it. A hard `false` here clears the boolean while the count is
	// still 1, which destroys the 2-second post-revive visibility grace
	// (N_REVIVE_VISIBILITY_DELAY) — the revived player becomes targetable the
	// instant they stand up. Recompute from the count exactly as stock does at
	// _zm_utility.gsc:3852.
	//
	// FIELD SPELLING IS STOCK'S OWN TYPO — `ignorme_count`, no second "e"
	// (_zm_utility.gsc:3835, verified by eye 2026-08-26). Misspelling it yields
	// undefined and silently reverts to the old hard-false with NO compile error
	// and no lint catch.
	//
	// DELIBERATELY NOT increment_ignoreme/decrement_ignoreme: clear() can run
	// twice for one window (the laststand guard and the loop exit), and a double
	// decrement would steal stock's own last-stand reference — trading a
	// cosmetic bug for a real one. This recompute is idempotent.
	self.ignoreme = ( isdefined( self.ignorme_count ) && self.ignorme_count > 0 );
	self.tod_in_blood = undefined;
	self DisableInvulnerability();
	// (no visionset to deactivate — see the note in zombie_blood_window)

	// Take the tray icon down with the window.
	if ( isdefined( self.zombie_vars ) )
	{
		self.zombie_vars[ "zombie_powerup_zombie_blood_on" ] = 0;
		self.zombie_vars[ "zombie_powerup_zombie_blood_time" ] = 0;
	}
	// Drop the solo-HUD gate only if no OTHER grabber-only window still needs
	// it — the Death Machine (= Gift of Death) rides the stock minigun vars,
	// and zeroing the flag mid-window would blank ITS tray icon. The Logical
	// packs' solo_hud_fix loops re-assert the flag themselves, so they never
	// need protecting here. IS_TRUE, not a raw read: this map never inits the
	// minigun var on players who haven't grabbed one (the v8.4 boot-fix rule).
	if ( !( isdefined( self.zombie_vars ) && IS_TRUE( self.zombie_vars[ "zombie_powerup_minigun_on" ] ) ) )
		self._show_solo_hud = false;
}

// ---------------------------------------------------------------------------
// MAX AMMO ALSO FILLS THE CLIP (user 2026-08-21)
// ---------------------------------------------------------------------------
// Stock full_ammo calls GiveMaxAmmo per weapon, which refills the RESERVE
// only — grab it mid-magazine and you still have to reload. The stock powerup
// notifies each affected player "zmb_max_ammo" (_zm_powerup_full_ammo.gsc
// :79), so we ride that instead of overriding the powerup: top every primary's
// clip to clipSize WITHOUT charging the reserve (the reserve was just filled).
// Threaded per player from tod_main's spawn hook.
function max_ammo_clip_watch()   // self = player
{
	// RESPAWN LATCH. This is registered via callback::on_spawned, and
	// callback::callback THREADS every registered func on every dispatch — while
	// a co-op bleed-out respawn dispatches "on_player_spawned" TWICE (_zm.gsc
	// :3338 in spectator_respawn, then _globallogic_spawn.gsc:465 in spawnPlayer,
	// which the custom path returns into with no early exit). With only
	// disconnect/end_game endons the thread is per-life immortal on a player
	// entity that is never deleted, so every respawn added TWO more copies —
	// 60-120 stale sweeps on one player over a long endless run.
	// The latch goes in the FUNCTION, not at the registration site, so it covers
	// any future caller. Same shipped idiom as _tod_uniques, _tod_runandgun and
	// _tod_luck; the field survives death because the ZM player entity is never
	// deleted. Do NOT use callback::remove_on_spawned — it deregisters for EVERY
	// player, not just the respawner.
	if ( IS_TRUE( self.tod_max_ammo_clip_on ) )
		return;
	self.tod_max_ammo_clip_on = true;

	self endon( "disconnect" );
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( "zmb_max_ammo" );
		wait 0.05;   // let the stock GiveMaxAmmo pass finish first

		if ( !isdefined( self ) || !IsAlive( self ) )
			continue;
		weapons = self GetWeaponsListPrimaries();
		foreach ( w in weapons )
		{
			if ( !isdefined( w ) || w == level.weaponNone )
				continue;
			if ( w.clipSize <= 0 )
				continue;   // melee / equipment
			if ( self GetWeaponAmmoClip( w ) < w.clipSize )
				self SetWeaponAmmoClip( w, w.clipSize );
		}
	}
}

// Drop gate — the perk bottle only enters the rotation once the power is
// on ("power_on" is a FLAG, never a bool field; flag::get is the read).
// Guarded with flag::exists because this can be polled before _zm's flag init.
// ---------------------------------------------------------------------------
// PACK-A-PUNCH: "REQUIRES POWER" COPY (user 2026-08-25)
// ---------------------------------------------------------------------------
// "It was because power was off. Lets make sure it has power offline copy. It
// didnt and I kept trying to pap when power wasnt on."
//
// Stock DOES set a hint for this — _zm_pack_a_punch.gsc:354 does
// SetHintString( &"ZOMBIE_NEED_POWER" ) — and on this map it renders as
// NOTHING, so the machine is silently inert and reads as broken. It cost a
// full round-trip of "PaP is broken again" to find that out.
//
// WHY NOT JUST SUPPLY THE STRING: localizedstrings/zm_aetherium.str cannot
// define it. The T7 string compiler auto-prepends the FILENAME to every
// REFERENCE key (see that file's FILENOTES), so a key written as
// ZOMBIE_NEED_POWER becomes ZM_AETHERIUM_ZOMBIE_NEED_POWER and the stock
// reference is unreachable from our file. A literal hint string is the only
// lever, which is the same thing the ammo crate and every buyable door do.
//
// SAFE AGAINST STOCK OVERWRITING IT: stock's pap_trigger_hintstring_monitor
// does `level waittill( "Pack_A_Punch_on" )` BEFORE its update loop
// (_zm_pack_a_punch.gsc:151-170), so while power is off nothing else writes the
// trigger's hint. The moment power lands we stop touching it and stock's
// monitor owns the string again — we deliberately do not set a powered hint,
// because stock's is the one that knows the weapon and the cost.
function pap_power_hint()
{
    level endon( "end_game" );

    // Same exists-poll breather_pap_spawn() uses above, and for the same reason:
    // this module's __init__ runs early enough that even
    // "initial_blackscreen_passed" may not be created yet. Most tod modules can
    // call wait_till on it bare; the two threads started from THIS __init__
    // cannot, which is precisely the distinction the note at the top of
    // breather_pap_spawn draws.
    while ( !( level flag::exists( "initial_blackscreen_passed" ) ) )
        wait 0.1;
    level flag::wait_till( "initial_blackscreen_passed" );

    // WAIT FOR THE FLAG TO EXIST BEFORE READING OR WAITING ON IT.
    //
    // THIS LINE CRASHED THE MAP (2026-08-25, shipped for one build):
    // "cannot cast undefined to bool ... scripts/shared/flag_shared.gsc".
    // flag::get() returns self.flag[ name ], which is UNDEFINED for a flag that
    // does not exist yet, and flag::wait_till() is a `while ( !get( name ) )` —
    // so waiting on a not-yet-created flag negates undefined and fatals the
    // server script. It presented as random because it is a race: only when this
    // thread reaches the wait before _zm's flag init does.
    //
    // "power_on" is a STOCK flag and this module only READS it — nothing here
    // creates a flag. should_drop_free_pap() below has carried the same
    // flag::exists guard, and the same reason, since it was written; that
    // precedent was there to follow and this did not follow it.
    //
    // The combined `exists( x ) && get( x )` form used in _tod_finale and
    // _tod_perk_lights is fine and was NOT the bug here — the bug was waiting on
    // a flag without checking it exists at all.
    while ( !( level flag::exists( "power_on" ) ) )
        wait 0.1;

    if ( level flag::get( "power_on" ) )
        return;   // powered before we got here — leave stock's hint alone

    trigs = GetEntArray( "pack_a_punch", "script_noteworthy" );
    if ( trigs.size == 0 )
        return;

    // THIS PASS USED TO WRITE "^5PACK-A-PUNCH^7 - ^3REQUIRES POWER^7" HERE AND
    // IT WAS WRONG TWICE OVER (audit 2026-08-25):
    //
    //   1. IT COULD NEVER BE READ. ZMCursorHintNew.lua:205-213 routes any hint
    //      containing "pack" AND "punch" to the STATIC Pack-a-Punch card, which
    //      renders its own fixed title/blurb/cost and never looks at the text.
    //      The words were drawn nowhere, in any state.
    //   2. IT WAS A REGRESSION. Stock ships &"ZOMBIE_NEED_POWER" on this
    //      trigger, and THAT string already routes to the kit's Power Required
    //      card (isPowerRequiredHint, :156-162). Overwriting it replaced a
    //      working card with an invisible one.
    //
    // So the string is gone and stock's own is left alone. The pass now only
    // fixes the CURSOR ICON, which is still worth doing.
    //
    // NOTE ON REACH: this targets script_noteworthy "pack_a_punch", which stock
    // stamps on the ONE zbarrier-derived trigger — the CROWN PaP. That machine
    // sits behind the roof door at the top of a 50-floor climb, so in practice
    // nobody is standing at it with the power off. The reachable machines are
    // the four breather vendors, and they are handled by
    // breather_pap_power_hint() above.
    foreach ( t in trigs )
    {
        if ( !isdefined( t ) )
            continue;
        t SetCursorHint( "HINT_NOICON" );
    }

    // Nothing to hand back any more — we never took the string. Left as a
    // no-op wait so the thread still ends on the flag rather than lingering.
    level flag::wait_till( "power_on" );
}

function should_drop_free_pap()
{
	if ( !( level flag::exists( "power_on" ) ) )
		return false;
	return ( level flag::get( "power_on" ) );
}

// The FREE-PAP drop's gate: the power rule above, then a coin flip that halves
// its share of the rotation (user 2026-08-24 — see TOD_PAP_DROP_PCT).
function should_drop_pap()
{
	if ( !should_drop_free_pap() )
		return false;
	return ( RandomInt( 100 ) < TOD_PAP_DROP_PCT );
}

// The DEATH MACHINE drop's gate — installed OVER stock's by install_gift_of_death
// so whatever stock decides still applies, with our coin flip on top.
function tod_should_drop_minigun()
{
	if ( isdefined( level.tod_minigun_stock_should_drop )
	  && ![[ level.tod_minigun_stock_should_drop ]]() )
		return false;
	return ( RandomInt( 100 ) < TOD_MINIGUN_DROP_PCT );
}

// self = the drop entity; player = the toucher. Return TRUE = NOT consumed
// (the grab loop keeps polling — the drop stays for someone who can use it).
// Runs synchronously in the grab poll: the upgrade happens THIS frame so the
// held weapon can't change between check and apply (the ZoekMeMaar Mule-Kick
// dupe was exactly that race).
function grab_free_pap( player )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return true;
	if ( player laststand::player_is_in_laststand() )
		return true;
	if ( isdefined( player.is_drinking ) && player.is_drinking > 0 )
		return true;

	// A PERK the grabber does not already own. give_random_perk builds the
	// not-owned list itself and returns undefined when every perk is held —
	// in that case DON'T strand the drop (solo has no teammate to save it
	// for): consume it and refill ammo as the consolation, the same rule the
	// old PaP grant used.
	got = player zm_perks::give_random_perk();
	if ( !isdefined( got ) )
	{
		w = player GetCurrentWeapon();
		if ( isdefined( w ) && w != level.weaponNone )
			player GiveMaxAmmo( w );
	}
	// consumed (no return value) — stock plays zmb_powerup_grabbed + hides it
}


// ---------------------------------------------------------------------------
// GIFT OF DEATH (Xmas Gun) — the Death Machine drop grants it, with FIXED
// shots-to-kill (2 zombie / 10 Rogue Protector / 30 Panzer), round-independent.
// Called from main() AFTER zm_usermap::main() (stock minigun __init__ seeded
// level.zombie_powerup_weapon["minigun"]) and BEFORE tod_main::init() (so our
// actor callback registers ahead of _tod_upgrades::upgrade_damage_cb).
// ---------------------------------------------------------------------------

function install_gift_of_death()
{
	// Redirect the stock Death Machine grant (grant + timed-take + last-stand-
	// take all read this one level field) to the Gift of Death (base form).
	if ( GetWeapon( "xmas_gun" ) != level.weaponNone )
		level.zombie_powerup_weapon[ "minigun" ] = GetWeapon( "xmas_gun" );

	// DEATH MACHINE DROP RATE HALVED (user 2026-08-24). Stock's own gate is
	// CAPTURED rather than replaced — the same latch idiom as
	// level.tod_mechz_stock_damage_func — so minigun_no_drop's "somebody is
	// already holding one" rule keeps working and we only add the coin flip.
	if ( isdefined( level.zombie_powerups ) && isdefined( level.zombie_powerups[ "minigun" ] ) )
	{
		level.tod_minigun_stock_should_drop = level.zombie_powerups[ "minigun" ].func_should_drop_with_regular_powerups;
		level.zombie_powerups[ "minigun" ].func_should_drop_with_regular_powerups = &tod_should_drop_minigun;
	}

	zm::register_actor_damage_callback( &xmas_fixed_shots_cb );

	// INSTA-KILL rework (user 2026-08-20: "insta kill should grant all players
	// 3x damage output, different than base"). The stock insta_kill_powerup
	// checks level.insta_kill_powerup_override and runs it INSTEAD of setting
	// the one-shot flag — so ours grants a team-wide 3x damage window. The mult
	// is read at the ZOMBIE final-damage sites only: upgrade_damage_cb (all
	// player weapons) + xmas_fixed_shots_cb (the Gift of Death). BOSSES are
	// deliberately EXEMPT — their damage is fixed/round-independent by design
	// (Gift of Death 2/10/30 shots; the mechz wrap runs last and would rescale
	// anything set upstream). level.tod_dmg_mult defaults to 1.
	level.tod_dmg_mult = 1;
	level.insta_kill_powerup_override = &instakill_3x_override;
}

// Runs INSTEAD of the base insta-kill (stock threads it from insta_kill_powerup
// with (drop_item, player)). Shows the stock insta-kill HUD icon + timer but
// grants 3x damage for the duration rather than the one-shot. Re-grab restarts
// the window via the tod_instakill_<team> notify/endon.
function instakill_3x_override( drop_item, player )
{
	team = player.team;
	level notify( "tod_instakill_" + team );
	level endon( "tod_instakill_" + team );

	level thread zm_powerups::show_on_hud( team, "insta_kill" );   // icon + countdown
	level.tod_dmg_mult = 3;
	// (3X announce removed 2026-08-20 — the tripled crosshair numbers ARE the tell)
	wait N_POWERUP_DEFAULT_TIME;
	level.tod_dmg_mult = 1;
}

// Level actor-damage callback — NORMAL ZOMBIES only. Bosses take their fixed
// shots in their own guaranteed callbacks (_tod_bosses), because the mechz
// damage wrap runs AFTER the level chain and would rescale anything set here.
// self = the AI taking damage. Return -1 = not our concern (chain continues).
function xmas_fixed_shots_cb( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{
	if ( !isdefined( weapon ) || !isdefined( weapon.name ) || !IsSubStr( weapon.name, "xmas_gun" ) )
		return -1;   // not the Gift of Death — let the rest of the chain run
	// Bosses are handled in _tod_bosses (the wrap would rescale a value here).
	if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
		return -1;
	// No free damage on the frozen horde during an upgrade pick.
	if ( IS_TRUE( level.tod_upgrade_pause ) )
		return 0;
	// Guard 0/spurious events + same-frame dedupe (verify 2026-08-20): keeps it
	// exactly 2 shots even if a direct impact + splash ever co-fire one frame.
	if ( !isdefined( damage ) || damage <= 0 )
		return -1;
	now = GetTime();
	if ( isdefined( self.tod_xmas_hit_ms ) && self.tod_xmas_hit_ms == now )
		return 1;
	self.tod_xmas_hit_ms = now;

	hp = ( isdefined( self.maxhealth ) ? self.maxhealth : self.health );
	// INSTA-KILL 3x window multiplies output (level.tod_dmg_mult; default 1).
	dmult = ( isdefined( level.tod_dmg_mult ) ? level.tod_dmg_mult : 1 );
	final = int( ( hp / XMAS_ZOMBIE_SHOTS ) * dmult ) + 1;   // 2 hits from full, any round
	if ( isdefined( attacker ) && isplayer( attacker ) )
		attacker tod_upgrade_ui::push_dmg_num( final, false );   // crosshair number parity
	return final;
}
