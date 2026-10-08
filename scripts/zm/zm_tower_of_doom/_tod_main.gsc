// =============================================================================
// _tod_main.gsc — orchestrator for the small stuff (proof-of-life banner,
// dev sandbox). Grows as [tod] systems are added; each new module gets its own
// file + a scriptparsetree line in zone_source/zm_tower_of_doom.zone.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_score;
#using scripts\zm\zm_tower_of_doom\_tod_cyber_zombies;
// DEV-ONLY reach (dev_crown_test): the stock power entry point and the perk
// unpause it is always paired with, plus the crown's generated anchors and the
// finale's gate. All four are behind level.tod_dev; with it false nothing here
// runs, but the #usings stay so the file always compiles either way.
#using scripts\zm\_zm_power;
#using scripts\zm\_zm_perks;
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;
#using scripts\zm\zm_tower_of_doom\_tod_doors;
#using scripts\zm\zm_tower_of_doom\_tod_finale;
#using scripts\zm\zm_tower_of_doom\_tod_spire;        // HARNESS #8 ONLY (spire spawn, 2026-09-02) — remove with it
#using scripts\zm\zm_tower_of_doom\_tod_spire_data;   // HARNESS #6 ONLY (summit warp) — rides out with it

#using scripts\zm\zm_tower_of_doom\_tod_zombie_speed;
#using scripts\zm\zm_tower_of_doom\_tod_perk_lights;
#using scripts\zm\zm_tower_of_doom\_tod_perk_anims;
#using scripts\zm\zm_tower_of_doom\_tod_classes;
#using scripts\zm\zm_tower_of_doom\_tod_dev_mage;
#using scripts\zm\zm_tower_of_doom\_tod_upgrades;
#using scripts\zm\zm_tower_of_doom\_tod_runandgun;   // RUN AND GUN (skirmisher ammo saver, domain 23)
#using scripts\zm\zm_tower_of_doom\_tod_bat_inspect; // THE BAT'S INSPECT on the low-ready lane, cancellable (2026-10-02)
#using scripts\zm\zm_tower_of_doom\_tod_uniques;     // CLASS TIER uniques: fire-streak + sprint watchers (docs/25 §9)
#using scripts\zm\zm_tower_of_doom\_tod_distraction; // DISTRACTION (assault thrown decoy, domain 41)
#using scripts\zm\zm_tower_of_doom\_tod_athlete;     // ATHLETE (slasher slide/jump, domain 43)
#using scripts\zm\zm_tower_of_doom\_tod_riotshield;  // RIOT SHIELD (universal recharging shield, domain 45)
#using scripts\zm\zm_tower_of_doom\_tod_mage_elements;   // THE MAGE (docs/114) -- gated OFF in _tod_mage.gsh
// #using scripts\zm\zm_tower_of_doom\_tod_thunder_smash;   // v19.39: THUNDER SMASH removed (see _tod_upgrades add_domain note)
#using scripts\zm\zm_tower_of_doom\_tod_atmosphere;
#using scripts\zm\zm_tower_of_doom\_tod_gameover;     // party_push (v19.63: the party facts the pause menu reads)
#using scripts\zm\zm_tower_of_doom\_tod_ammo_crate;   // buyable ammo at every breather (2026-08-24)
#using scripts\zm\zm_tower_of_doom\_tod_base_sign;    // v19.69: Nikolai's CYBERCITY sign on the core's west face
#using scripts\zm\zm_tower_of_doom\_tod_rocket;       // v19.68r: THE ROCKETS, the post-crown EXTRACT / ASCEND ships (docs/170)
#using scripts\zm\zm_tower_of_doom\_tod_power_terminal; // v19.69: Nikolai's Grid Terminal V5 is the power switch's panel
#using scripts\zm\zm_tower_of_doom\_tod_perk_drink;   // PERK DRINK sfx: cap pop + gulp (docs/43 item 1)
#using scripts\zm\zm_tower_of_doom\_tod_rampage;      // RAMPAGE INDUCER: the opt-in hard mode (v14.20)
#using scripts\zm\zm_tower_of_doom\_tod_killconfirm;  // ELITE KILL CONFIRM: red crosshair snap + ding, elites only (v18.96)
#using scripts\zm\zm_tower_of_doom\_tod_secret;       // THE TEDDY BEAR SONG HUNT: the map's first secret (v18.96)

#insert scripts\shared\shared.gsh;

#namespace tod_main;

function init()
{
	level endon( "end_game" );

	// Sprint-from-round-1 speed curve (registers its spawn callback; safe pre-blackscreen)
	tod_zombie_speed::init();
	tod_cyber_zombies::init();
	// Perk machine + PaP power-on glow auras (waits for the power flag itself)
	tod_perk_lights::init();
	tod_perk_anims::init();
	// Class system (3 classes, base-arena select stations) + the upgrade tower
	tod_classes::init();
	tod_upgrades::init();
	// (CHAIN LUNGE removed 2026-08-24 — user: "it doesnt work". _tod_lunge.gsc
	// is off the zone; see the note at its old add_domain in _tod_upgrades.gsc.)
	// RUN AND GUN: per-player weapon_fired watcher (registers on_spawned; safe pre-blackscreen)
	tod_runandgun::init();
	// THE BAT'S INSPECT: per-player reload-press watcher (on_spawned; safe pre-blackscreen)
	tod_bat_inspect::init();
	// CLASS TIER uniques: fire-streak + sprint-edge watchers (on_spawned; safe pre-blackscreen)
	tod_uniques::init();
	// DISTRACTION (v14.59, domain 41; Cymbal Monkey-only since v16.49): opts
	// the monkey out of stock's Max Ammo refill and installs an on_spawned
	// reconcile. Must run after zm_usermap::main() has registered the tactical
	// list - this whole block already does.
	tod_distraction::init();
	tod_athlete::init();
	// RIOT SHIELD (v16.63, domain 45): registers the Lv5 cyber shield as
	// equipment (the base shield is stock-registered through zm_usermap) and
	// installs an on_spawned reconcile + the break/recharge watchers. Same
	// ordering need as DISTRACTION: after zm_usermap::main().
	tod_riotshield::init();
	// AFTER tod_upgrades::init() and tod_classes::init(), both of which it reads.
	// Returns immediately while TOD_MAGE_ENABLED is 0.
	tod_mage_elements::init();
	// tod_thunder_smash::init();   // v19.39: removed from the map, kept for a later restore
	// The neon city smog (thick at street level, clear by mid-tower)
	tod_atmosphere::init();
	// AMMO CRATE on each breather balcony (waits for the blackscreen itself)
	tod_ammo_crate::init();
	tod_base_sign::init();     // v19.69: the CYBERCITY sign over the spawn (waits for the blackscreen itself)
	// v19.68r THE ROCKETS (docs/170): the rider hooks now (out-of-area, damage), the ships when THE CHOICE opens
	tod_rocket::init();
	tod_power_terminal::init(); // v19.69: the power switch's Grid Terminal panel (waits for the blackscreen itself)
	// RAMPAGE INDUCER (v14.20) — the opt-in hard mode. Spawns its station and
	// sets level.tod_rampage_on = false; every consumer treats the absent or
	// false field as normal difficulty, so ORDER DOES NOT MATTER here: the
	// speed curve, the elite directors and the spawn resolver all field-read it
	// with IS_TRUE and none of them run before this line anyway. Placed after
	// the crate purely to keep the world-object inits together.
	tod_rampage::init();
	tod_killconfirm::init();   // v18.96
	tod_secret::init();        // v18.96 (places the bears after the blackscreen)
	// PARTY SIZE -> LUI. Started here (pre-blackscreen) so the dvar is never
	// unset the first time a menu reads it. See party_dvar_watch.
	level thread party_dvar_watch();
	// PERK DRINK RETIRED (v14.19b, user: "we would need to remove our custom
	// audio then"): the scripted cap-pop + gulp was built for the SILENT stock
	// bottles ("whatever you hear rides in the perk bottle's viewmodel
	// animation" — its own header, prophetically). The BO7 cans' gesture anim
	// now carries real notetrack foley (grab/crack/drink/toss), so the timer
	// cues would LAYER glass-bottle sounds over can sounds on every buy. The
	// module + its #using above + zone line stay for the recipe; this call is
	// the ONE switch. Re-enable only if the drinks ever go back to bottles.
	// tod_perk_drink::init();

	level flag::wait_till( "initial_blackscreen_passed" );

	// Proof-of-life: the build is live and module init ran.
	welcome_banner();
	if ( IS_TRUE( level.tod_dev ) )
		level thread tod_dev_mage::run();

	// DEV MONEY, ON ITS OWN GATE (2026-09-07). It used to sit inside the
	// tod_dev block below, which meant "I want unlimited money" also bought
	// upgrades every round, a Panzer from round 3 and a TIER card on every
	// deal. Those are four different wishes and they now have two switches.
	// tod_dev still implies money, so no armed session loses anything.
	if ( IS_TRUE( level.tod_dev ) || IS_TRUE( level.tod_dev_money ) )
		level thread dev_money_loop();

	// EVERY TOWER DOOR OPEN, on its own switch (user 2026-09-07: "can you open
	// up all the doors in dev mode?"). Same reasoning as the money split above:
	// tod_dev is a BUNDLE, and "I want to walk the tower" should not also buy an
	// upgrade every round and start Panzers at round 3. tod_dev still implies it,
	// so an armed tod_dev session loses nothing.
	if ( IS_TRUE( level.tod_dev ) || IS_TRUE( level.tod_dev_doors ) )
		level thread dev_open_doors_harness();

	// TIER 3 + EVERY DOMAIN MAXED, on its own switch (user 2026-09-07: "when I
	// respawn into the map, give me all my abilities. I don't wanna have to
	// unlock them ... just give me my tier three weapon, with max upgrades").
	// For the MAGE this is not a convenience, it is the only way to reach two of
	// the four elements at all: FIRE needs tier 2 and ICE tier 3.
	// 2026-09-27: the user now wants whichever class they PICK fully maxed in
	// dev mode. Keep the real draft; grant only after its first deal closes.
	if ( IS_TRUE( level.tod_dev ) || IS_TRUE( level.tod_dev_maxed ) )
		level thread dev_maxed_harness();

	if ( IS_TRUE( level.tod_dev ) )
	{
		// dev_crown_test() REMOVED AGAIN 2026-08-26, after the user's ending
		// retest passed. It is a throwaway harness for testing the top of the
		// map (open every door, force power through the stock entry point, open
		// the causeway gate, warp everyone to the terrace on spawn and on every
		// respawn) and it has now been written-then-deleted twice. Do NOT re-add
		// it inline or leave it dormant behind tod_dev; write it fresh if the
		// ending needs testing again. Recipe, so it is cheap to re-derive:
		//   tod_doors::dev_open_all_doors()          — flags AND slabs AND navmesh
		//   zm_power::turn_power_on_and_open_doors() — never poke "power_on" by
		//   zm_perks::perk_unpause_all_perks()         hand; it leaves perks paused
		//   tod_finale::gate_open()                  — else risers past it are cut
		//   callback::on_spawned( &warp )            — respawn too, not just spawn
		// Terrace centre is ( 0, 368, 19400 ), yaw 90, clear of the station.
		dev_print_sprint_dvars();   // v15 item 20 — see the function header
		// v16.1 — the slide/jump engine dvar family (jump_max_velocity etc.) as
		// the engine reports it, plus what _tod_athlete wrote. See its header.
		tod_athlete::dev_print_movement_dvars();
		// HARNESS #9 (2026-09-03, user: "Dont spawn me in at endless spire with
		// all perks. Just do a regular spawn at spawn on dev and god mode. On dev
		// mode the alter should be unlimited and all doors should be unlocked
		// already"): a PLAIN base spawn — no warp, no ascension, no perk grant —
		// with every buyable door open from the first second (flags, breather
		// unlocks, slabs, navmesh, retired prompts: tod_doors::dev_open_all_doors
		// does all four). Power is NOT flipped (the switch at the bottom still
		// works; the user asked for doors). The altar is already unlimited on
		// dev (station_depleted). NINTH WRITE; delete with the dev flags.
		// HARNESS #8 RE-THREADED (2026-09-04, user: "In dev mode spawn me at the
		// spire so i can test" — the PaP camo control needs the spire machines,
		// the only ones that sell PACK II/III). It powers on through the stock
		// entry, opens every tower door, fires the ascension (no finale), and
		// drops a DEV WARP pad beside the spire arrival that opens doors 1-10
		// and places the party on hub 10's landing — the PaP is in that hall.
		// #9's plain spawn is the line below it; swap them back when asked.
		// 2026-09-05 v17.81a (user: "I need dev and god mode on and spawn at spire"): #8 LIVE, #9 parked.
		// 2026-09-05 20:5x (user: "spawn me at the first tower instead of endless spire. All doors open"): #9 LIVE, #8 parked.
		// 2026-09-10 (user: "Spawn me at endless tower in dev mode so i can test"
		// — THE OPEN HALLS, v18.78: all seven halls to try): #8 LIVE again, now
		// with a warp pad on EVERY hub landing (each hold = the next hub, 70 wraps
		// to 10), so the session is seven halls and not one hall plus a 60-floor
		// climb. #9 stays parked: tod_dev_doors runs the same door open above.
		// PARKED for the v18.82 PUBLISH (tenth write, tenth removal). Uncomment the
		// line below with the dev flags to test the trial halls hub by hub.
		// 2026-10-01 (user: "Lets build 1 first" - the trial halls' effects): #8 LIVE,
		// the HALLS variant (false): ascend after the first deal, warp pads hub to
		// hub; Trial VII's win opens the way to the summit and the King. PARK IT
		// (comment this line) with the dev flags before any publish.
		// 2026-10-02: PARKED with the dev flags for the pre-publish test (user: "disable dev and god mode").
		// level thread dev_spire_harness( false );
		// Moved onto tod_dev_doors below so it can be armed WITHOUT the rest of
		// the tod_dev bundle. Left here so an armed tod_dev session is unchanged.
		// level thread dev_open_doors_harness();   // HARNESS #9
		// HARNESS #8 (2026-09-02, v16.22: spawn straight into THE ENDLESS SPIRE +
		// a hub-10 warp pad). Its function, dev_spire_warp_hub and the two spire
		// #usings are in this file: DELETE all of it with the dev flags.
		// HARNESS #7 REMOVED 2026-08-31 for the publish build (the fog/spire
		// run: terrace warp on spawn AND on a 20s sweep for players already
		// in, all doors/power/perks/gate open, ascension-latched so it stopped
		// yanking spire players back). SEVENTH WRITE, SEVENTH REMOVAL.
		// Recipe delta vs the base recipe above, worth keeping because this
		// one cost a wasted playthrough: `callback::on_spawned` ALONE DOES NOT
		// WARP THE FIRST LIFE — this dev block runs after
		// `flag::wait_till("initial_blackscreen_passed")`, by which point every
		// player has already spawned, so the callback only ever catches
		// RESPAWNS. Any future warp harness must ALSO sweep the players who
		// are already in (loop them, SetOrigin, re-assert for ~20s so the
		// class draft cannot undo it), and gate that sweep on
		// tod_spire_active/tod_ascend so it does not drag spire players home.
		// HARNESS #6 REMOVED 2026-08-29 night (the spire verify run: terrace
		// warp on spawn/respawn until ascension + a dev summit-warp pad at the
		// spire arena; deleted for the v14.1 publish — sixth write, sixth
		// removal). Recipe delta vs the base recipe above: also gate the warp
		// on tod_spire_active/tod_ascend so it stops yanking spire players
		// back, keep the causeway gate CLOSED (the uplink buy opening it is
		// part of what the run verifies), and put the summit pad at
		// arrival_org + (400, 350, 0), warping to summit_exfil_org + (0, 270, 0).
		// dev_crown_test() REMOVED AGAIN 2026-08-29 ~4:50am (harness #5, the
		// PaP-verification warp, removed with the same night's disarm). Five
		// writes, five removals — the recipe above stays current.
		// dev_crown_test() REMOVED AGAIN 2026-08-27 evening (harness #4, written
		// that afternoon for the road-ramp/finale test, deleted for the v12.15
		// publish). Four writes, four removals — the recipe above stays current;
		// write it fresh, never re-add it dormant.
	}

}


// (welcome text removed 2026-08-20 — user: no floaty text; the stub stays
// because init() still calls it as a proof-of-life marker.)
// PARTY SIZE -> LUI (2026-09-07). AetheriumStartMenu hides RESTART LEVEL and
// RESTART MAP in co-op (they reload the level under the host and drop the peer),
// and that gate needs a party count it can TRUST.
//
// ⚠️ Engine.GetPlayerCount() IS NOT THAT COUNT, and the way it looked like one
// is the lesson. The kit's Leave Game lane calls it — which is exactly why it
// was taken as proven — but THAT CALL SITE'S TWO BRANCHES ARE IDENTICAL:
//
//     if playerCount and playerCount <= 1 then  <disconnect>  else  <disconnect>  end
//
// so its return value has never decided anything and a wrong value was
// invisible there. Gating a real button on it removed the button in SOLO
// (user 2026-09-07: "I didnt see it in solo"), which is the first time anything
// in this map ever read that function's answer. A call nobody has watched
// DECIDE something is not a proven call, however many times it appears.
//
// GetPlayers().size is authoritative and server-side. It reaches Lua on the
// same dvar channel _tod_gameover uses for tod_go_active — that one IS proven,
// because the two-entry game-over menu has shipped on it since v9.24 and is the
// only thing that makes that menu appear.
//
// HOST-MACHINE ONLY, like every SetDvar here, and the failure direction is
// chosen: a co-op PEER reads "" and keeps the button. A peer pressing it drops
// only themselves; the HOST pressing it drops the whole party, and the host is
// the one seat this covers reliably. Solo also keeps the button if the read
// ever fails, so the worst case is the behaviour we had before the gate.
//
// Polled rather than event-driven: it must follow joins, leaves, disconnects
// and host migration, and one cheap compare a second covers all of them without
// a callback per lane. The dvar is only WRITTEN when the number moves.
function party_dvar_watch()
{
	level endon( "end_game" );

	last = -1;
	last_remote = -1;
	next_push = 0;
	for ( ;; )
	{
		// v19.59: count HUMANS. The dev Mage preview (_tod_dev_mage) is a native
		// test client, so GetPlayers() read 2 in a solo dev run and the pause /
		// game-over menus hid RESTART as if it were co-op (user 2026-09-27: "Why
		// is there no restart button on solo?"). Bots never own a menu seat.
		n = tod_gameover::party_humans();
		// [2026-10-01] and how many of them sit at ANOTHER machine: the pause
		// menu restarts with the kit's own console command when this is 0 (solo /
		// split-screen) and asks the server only when it is not (online co-op).
		// The dvar is the host machine's instant answer before the first event.
		remote = tod_gameover::party_remote_humans();
		changed = ( n != last || remote != last_remote );
		if ( changed )
		{
			last = n;
			last_remote = remote;
			SetDvar( "tod_party", "" + n );
			SetDvar( "tod_party_remote", "" + remote );
			tod_gameover::go_log( "PARTY humans=" + n + " remote=" + remote
				+ " restart_lane=" + ( ( remote > 0 ) ? "server" : "kit" ) );
		}
		// v19.63: the same facts on a lane a PEER can read - the dvar above is
		// host-machine only, so a co-op peer's pause menu could never tell it
		// was a peer and its Restart dropped that player alone. Pushed on every
		// change and every 5 s (a HUD built after the change gets it inside 5 s).
		if ( changed || GetTime() >= next_push )
		{
			next_push = GetTime() + 5000;
			tod_gameover::party_push( 0 );
		}
		wait 1;
	}
}

function welcome_banner()
{
}

// DEV ONLY (level.tod_dev hardcoded true + rebuild): keep everyone rich so
// doors/perks/box can be tested without farming.
// DEV ONLY (v15 item 20) — ARE THE SPRINT-TUNING DVARS REGISTERED IN RETAIL?
//
// ⚠️ THIS WAS WRITTEN ONCE ON 2026-09-01 AND VANISHED FROM THE FILE the same
// night (both the call and the body), during a pass another session made here.
// Restored. If it disappears again, suspect a concurrent edit rather than
// rewriting it a third time.
//
// User: "Can we make the skirmisher omni directional? He is able to run and gun
// but he stops running if you run at an angle." There is NO script lever for
// this — the whole T7 sprint surface is AllowSprint / IsSprinting /
// SetSprintDuration / SetSprintCooldown / SetClientPlayerSprintTime /
// SprintButtonPressed / SprintUpRequired, and none of them touch the direction
// cone. But Treyarch's own dvar string table (recovered from
// bin/cod2map64.exe) contains, verbatim:
//     player_sprintForwardMinimum — "The minimum forward deflection required to
//                                    maintain a sprint"
// which is exactly the knob. Setting engine movement dvars from GSC is stock
// practice: share/raw/scripts/zm/_zm.gsc SetDvars the sibling sprintLeap_enabled
// in the ZM path with no cheat gate.
//
// ⚠️ WHY A PRINT BEFORE A WRITE. SetDvar on an UNREGISTERED dvar silently
// creates a dead script dvar and no-ops — failure is INDISTINGUISHABLE FROM
// SUCCESS. The table was read out of a TOOL exe; the retail exe is packed and
// hashes dvar names, so scanning it proves nothing either way.
//
// HOW TO READ IT: a NUMBER means the dvar is live and the next build can set it.
// <UNREGISTERED> means the whole dvar lane is dead and the fallback is the
// SetMoveSpeedScale approximation (no sprint animation, but the gun stays up).
//
// STILL UNPROVEN EVEN IF THEY PRINT: co-op replication — this repo states that
// "host SetDvar never replicates to co-op peers", and sprint is client-predicted.
// Test in co-op, never solo only. And the dvar is GLOBAL: there is no per-player
// equivalent, so it would give omni-sprint to ALL FOUR classes, and a skirmisher
// who keeps sprinting while strafing has the GUN DOWN unless they own SPRINT FIRE.
function dev_print_sprint_dvars()
{
	names = array( "player_sprintForwardMinimum", "player_sprintStrafeSpeedScale",
	               "player_sprintSpeedScale", "player_strafeSpeedScale",
	               "player_backSpeedScale", "player_strafeAnimCosAngle" );
	for ( i = 0; i < names.size; i++ )
	{
		v = GetDvarString( names[ i ], "" );
		if ( v == "" )
			v = "<UNREGISTERED>";
		tod_quiet_print( "dvar " + names[ i ] + " = " + v );
	}
}

function dev_money_loop()
{
	level endon( "end_game" );
	for ( ;; )
	{
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			player = players[ i ];
			if ( isdefined( player ) && isdefined( player.score ) && player.score < 100000 )
				player zm_score::add_to_player_score( 100000 - player.score );
		}
		wait 2;
	}
}

// ===========================================================================
// HARNESS #8 — SPIRE SPAWN (user 2026-09-02: "spawn me in the spire so I can
// test the new changes"). EIGHTH WRITE. Fresh per the recipe doctrine in
// init(); DELETE this block, its #using and its thread line with the dev
// flags before publishing — never leave it dormant.
//
// What it does, in order:
//   1. waits for the dev class short-circuit (maxed SLASHER) to land
//   2. the base recipe: stock power entry + perk unpause + every tower door
//   3. fires the ascension exactly as THE CHOICE does (notify + ascend_run).
//      The finale never starts; its tod_ascend listeners are endons, so a
//      notify nobody is waiting on is harmless. ascend_run's own grant_all
//      then adds the nine perks on top of the maxed class.
//   4. a DEV WARP pad at the spire arrival (harness #6's spot). Hold it and
//      doors 1..10 open FREE through door_manager's own bypass lane (the same
//      notify + marker the watchdog fires), with the honour-guard drops
//      suppressed for the ~3 s it takes by parking tod_panzer_alive at the
//      cap — door_guard_panzers bails on its first check and the counter is
//      restored. Then the party is placed on DOOR 10's landing, OUTSIDE the
//      trial box (its z1 is the door threshold + 40), so the walk up into
//      the hall, the arrival chime and the 2 s closing tell all play for real.
// ===========================================================================
// HARNESS #9 — DEV: EVERY DOOR OPEN AT START (2026-09-03). Waits for the
// door module's own ready flag exactly as #8 did (the buy triggers must exist
// before dev_open_all_doors retires them, or the doorways keep prompting),
// then opens all 53 through the ONE lane that also flags the zones, arms the
// breather elites and cuts the navmesh. No warp, no power, no perks.
function dev_open_doors_harness()
{
	level endon( "end_game" );
	for ( i = 0; i < 40 && !IS_TRUE( level.tod_doors_ready ); i++ )
		wait 0.5;
	if ( !IS_TRUE( level.tod_doors_ready ) )
	{
		IPrintLnBold( "DEV: doors never reported ready - not opened" );
		return;
	}
	tod_doors::dev_open_all_doors();
	IPrintLnBold( "DEV: every door is open" );
}

// EVERY PLAYER TO TIER 3 WITH EVERY DOMAIN AT ITS CAP. Nothing new is written
// here: tod_upgrades::dev_grant_maxed already does exactly this job through the
// real primitives (it stamps the floor high-water rather than waiving the gate,
// promotes, PaPs primary and sidearm, then walks every domain the player can
// reach to its cap and fires the real LUI sync). It simply had no live caller —
// its only one was inside the parked spire harness below.
//
// ORDER IS LOAD-BEARING FOR THE MAGE: domain_available refuses mage_fire below
// tier 2 and mage_ice below tier 3, so the tier ladder must run BEFORE the
// domain max-out or two of the four elements are silently skipped.
// dev_grant_maxed already does tier first — do not reorder it.
function dev_maxed_harness()
{
	level endon( "end_game" );

	// The draft lands on an ALREADY-SPAWNED player, so waiting on the class
	// being chosen is mandatory: granting before it would max a classless
	// player and skip every class-scoped domain.
	while ( !IS_TRUE( level.tod_class_select_done ) )
		wait 0.5;

	// Let the round-1 deal finish. Rewriting levels underneath an open card
	// panel means the panel is showing numbers that are already stale.
	wait 1;
	while ( IS_TRUE( level.tod_upgrade_pause ) )
		wait 0.25;

	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) && !IS_TRUE( players[ i ].tod_dev_mage_dummy ) )
		{
			if ( IS_TRUE( level.tod_dev_mage_test ) )
				players[ i ] thread dev_staff_test_loadout();
			else
				players[ i ] thread dev_class_max_loadout();
		}
	}
}

// Every chosen class uses the existing tier/PaP/domain grant. Log the actual
// result so a completed user test proves all class-specific caps were reached.
function dev_class_max_loadout()
{
	self endon( "disconnect" );
	self endon( "death" );
	level endon( "end_game" );
	if ( !IS_TRUE( level.tod_dev ) && !IS_TRUE( level.tod_dev_maxed ) ) return;
	if ( !isdefined( self.tod_class ) || IS_TRUE( self.tod_dev_mage_dummy ) ) return;
	player_id = self GetEntityNumber();
	dev_class_max_log( "BEGIN player=" + player_id + " class=" + self.tod_class );
	self tod_upgrades::dev_grant_maxed( self );
	wait 0.5;
	checked = 0;
	missing = 0;
	foreach ( d in level.tod_domains )
	{
		if ( !tod_upgrades::domain_available( self, d ) ) continue;
		checked++;
		actual = tod_upgrades::get_level( self, d.key );
		cap = tod_upgrades::domain_max( self, d );
		if ( actual < cap )
		{
			missing++;
			dev_class_max_log( "CAP_MISSING class=" + self.tod_class + " domain=" + d.key + " actual=" + actual + " cap=" + cap );
		}
	}
	state = "READY";
	if ( missing > 0 || checked == 0 || tod_classes::tier( self ) != tod_classes::tier_max() ) state = "INCOMPLETE";
	dev_class_max_log( state + " player=" + player_id + " class=" + self.tod_class
		+ " tier=" + tod_classes::tier( self ) + " domains=" + checked + " missing=" + missing );
	if ( IS_TRUE( level.tod_dev_all_perks ) )
		self dev_all_perks();
}

// DEV: EVERY PERK THE MAP SELLS (level.tod_dev_all_perks, 2026-10-01; user:
// "spawn me in on dev mode with max perks so i can see the widoes wine change with
// mage"). The spire's own grant - the live scatter roster through stock's
// zm_perks::give_perk, so every perk's give hook runs (Widow's Wine swaps in its
// web grenades: the Mage's web tile) - minus Quick Revive, so a solo down still
// ends the game for the restart test. Once, after the class max; a down strips
// them like any perk.
function dev_all_perks()
{
	self tod_spire::perma_perks_give( false );
	if ( !isdefined( self ) )
		return;
	held = 0;
	roster = 0;
	if ( isdefined( level.tod_scatter_machines ) )
	{
		foreach ( spec in GetArrayKeys( level.tod_scatter_machines ) )
		{
			roster++;
			if ( self HasPerk( spec ) )
				held++;
		}
	}
	dev_class_max_log( "PERKS player=" + self GetEntityNumber() + " class=" + self.tod_class
		+ " held=" + held + "/" + roster + " widows_wine=" + self HasPerk( "specialty_widowswine" )
		+ " quick_revive_skipped=1" );
}

function dev_class_max_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) && !IS_TRUE( level.tod_dev_maxed ) ) return;
	line = "[TOD_DEV_MAX] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

// Isolated test diagnostics. Uses the existing grant, records actual caps and
// weapon state, and starts a cheap event-driven shot log. No gameplay callback
// or per-frame logger is added. Keep the presentation label honest until the
// completed BO6 assets are actually integrated and deployed.
function dev_staff_test_loadout()
{
	self endon( "disconnect" );
	level endon( "end_game" );
	player_id = self GetEntityNumber();
	dev_staff_test_log( "GRANT_BEGIN player=" + player_id + " class=" + self.tod_class );
	self tod_upgrades::dev_grant_maxed( self );
	wait 0.5;
	missing = 0;
	checked = 0;
	foreach ( d in level.tod_domains )
	{
		if ( !tod_upgrades::domain_available( self, d ) ) continue;
		checked++;
		actual = tod_upgrades::get_level( self, d.key );
		cap = tod_upgrades::domain_max( self, d );
		if ( actual < cap )
		{
			missing++;
			dev_staff_test_log( "CAP_MISSING domain=" + d.key + " actual=" + actual + " cap=" + cap );
		}
	}
	ice_found = false;
	weapons = self GetWeaponsListPrimaries();
	foreach ( weapon in weapons )
	{
		if ( tod_classes::pap_staff_id( weapon ) == 3 )
		{
			self SwitchToWeapon( weapon );
			ice_found = true;
			break;
		}
	}
	state = "READY";
	if ( missing > 0 || !ice_found || tod_classes::tier( self ) != 3 ) state = "GRANT_INCOMPLETE";
	dev_staff_test_log( state + " player=" + player_id + " class=" + self.tod_class
		+ " tier=" + tod_classes::tier( self ) + " god=" + IS_TRUE( level.tod_god )
		+ " domains=" + checked + " missing=" + missing + " ice_found=" + ice_found
		+ " presentation=bo6_v18.89 charge_enabled=0" );
	self thread dev_staff_test_shots();
}

function dev_staff_test_shots()
{
	self endon( "disconnect" );
	self endon( "death" );
	level endon( "end_game" );
	self notify( "tod_staff_test_shots" );
	self endon( "tod_staff_test_shots" );
	player_id = self GetEntityNumber();
	count = 0;
	for ( ;; )
	{
		self waittill( "weapon_fired", weapon );
		if ( !isdefined( weapon ) ) weapon = self GetCurrentWeapon();
		if ( !isdefined( weapon ) || tod_classes::pap_staff_id( weapon ) == 0 ) continue;
		count++;
		dev_staff_test_log( "SHOT player=" + player_id + " count=" + count
			+ " weapon=" + weapon.name + " staff=" + tod_classes::pap_staff_id( weapon ) );
	}
}

function dev_staff_test_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) || !IS_TRUE( level.tod_dev_mage_test ) ) return;
	line = "[TOD_STAFF_TEST] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

function dev_spire_harness( king_test )
{
	level endon( "end_game" );

	// 1. the REAL draft ends (the dev short-circuit went 2026-09-03), then the
	//    ceiling loadout — v17.82a (user 2026-09-05: "In dev mode give me max
	//    upgrades as well and tier 3 max"): tod_upgrades::dev_grant_maxed on
	//    every player = T3 + PaP'd primary and sidearm + every domain at its
	//    cap, through the real primitives (floor gate STAMPED, not waived).
	//    2026-09-10: dev_maxed_harness (its own switch, implied by tod_dev)
	//    already does this once the round-1 deal is down, so the grant here
	//    runs ONLY when neither switch is armed — two dev_grant_maxed threads
	//    racing tier_up on one player is not a state anyone has tested.
	while ( !IS_TRUE( level.tod_class_select_done ) )
		wait 0.5;
	if ( !IS_TRUE( level.tod_dev ) && !IS_TRUE( level.tod_dev_maxed ) )
	{
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
				players[ i ] thread tod_upgrades::dev_grant_maxed( players[ i ] );
		}
	}
	wait 4;
	// the round-1 deal is a world pause with cards up; ascending under it would
	// tear the tower down beneath an open panel. Bounded like dev_maxed_harness.
	for ( i = 0; i < 120 && IS_TRUE( level.tod_upgrade_pause ); i++ )
		wait 0.25;
	while ( !IS_TRUE( level.tod_spire_ready ) )
		wait 0.5;

	// 2. never poke "power_on" by hand — it leaves the perk machines paused.
	//    The tower doors are dev_open_doors_harness's job whenever tod_dev or
	//    tod_dev_doors is armed (both are today); this only fills in for a bare
	//    harness, so the slabs are never opened twice.
	zm_power::turn_power_on_and_open_doors();
	zm_perks::perk_unpause_all_perks();
	for ( i = 0; i < 20 && !IS_TRUE( level.tod_doors_ready ); i++ )
		wait 0.5;
	if ( IS_TRUE( level.tod_doors_ready ) && !IS_TRUE( level.tod_dev ) && !IS_TRUE( level.tod_dev_doors ) )
		tod_doors::dev_open_all_doors();
	wait 1;

	// 2b. THE PARTY GOES UP AT ROUND 5 (user 2026-10-02: "on round 5 send me to
	//     the endless spire so i can test out those changes"; the v19.68j pad
	//     beside the Rampage switch is gone): the Rampage switch lives in the base
	//     arena the ascension tears down, so the tower is tried first. The halls
	//     variant only - the King test still warps straight to the summit.
	if ( !IS_TRUE( king_test ) )
		dev_ascend_at_round( 5 );

	// 3. THE CHOICE. v19.68r THE ROCKETS (docs/170; user 2026-10-02: the post-crown teleporters become Nikolai's
	//    rockets): the party is set in the crown hall with THE CHOICE open, as if the crown fight had just been
	//    won - both ships come down, the two prompts arm, and the ride decides. ASCEND flies the colourful ship to
	//    the Spire (ascend_run runs in the crash's white; this harness carries on below); EXTRACT flies the other
	//    one straight up and ends the game. Without the rockets, or for the King test: the old instant ascent.
	if ( !IS_TRUE( king_test ) && IS_TRUE( level.tod_rockets_ready ) )
	{
		IPrintLnBold( "DEV: THE CHOICE - the rockets are landing in the crown hall" );
		tod_finale::dev_open_choice();
		level waittill( "tod_ascension" );
	}
	else
	{
		IPrintLnBold( "DEV: ascending to THE ENDLESS SPIRE" );
		level notify( "tod_ascend" );
		level thread tod_spire::ascend_run();
	}
	wait 3;

	// 3b. EVERY SPIRE DOOR OPEN (v17.56, user: "In dev mode we need to open all
	//     spire doors as well") — flags, slabs, riser gate; the sequential
	//     manager stands down. The pads below are pure warps.
	tod_spire::dev_open_all_doors();
	if ( IS_TRUE( king_test ) )
	{
		// Bypass the climb, but retain the real summit_station -> king_fight
		// path and its upgrade burst. Do not pre-max the test player's cards.
		hubs = tod_spire_data::hub_laps();
		for ( i = 0; i < hubs.size; i++ )
			level.tod_spire_trial_won[ hubs[ i ] ] = true;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
				continue;
			p SetOrigin( tod_spire_data::summit_exfil_org() + ( 0, i * 48, 8 ) );
			p SetPlayerAngles( ( 0, 160, 0 ) );
		}
		line = "[TOD_KING_TEST] summit_warp players=" + players.size + " god=" + level.tod_god;
		/#
		PrintLn( line );
		#/
		IPrintLnBold( "DEV: WARDEN KING TEST - GOD MODE" );
		return;
	}

	// 4. THE WARP PADS (2026-09-10, the open-halls test). One beside the arrival
	//    and one on EVERY hub's door landing — the landing BEFORE the door, which
	//    on a hub is the NW landing under the hall's NW region: 192 below the hall
	//    floor and outside trial_box (z1 = hall - 88), so nobody standing on it
	//    counts as "in" and the seal cannot close on the pad. Each pad sends the
	//    living party to the NEXT hub's landing — 10, 20 ... 70, then 10 again —
	//    so all seven halls can be tried in one session: win the trial, walk back
	//    down the W flight to the landing, hold the pad. Persistent, refused while
	//    a trial holds the spire sealed. ONE hint string for all eight pads (the
	//    triggerstring budget); lint_tod_hints carries this file's row.
	hubs = tod_spire_data::hub_laps();
	level thread dev_spire_pad( tod_spire_data::arrival_org() + ( 400, 350, 0 ), hubs[ 0 ] );
	for ( i = 0; i < hubs.size; i++ )
	{
		info = tod_spire_data::get_spire_door_info( hubs[ i ] );
		if ( !isdefined( info ) )
			continue;
		// the landing's outer corner on the "before" side of the slab (see
		// dev_spire_warp_hub for the parity), 54 outboard of the path centre:
		// radius 64 does not reach the warp spot, and the flight's mouth is clear
		side = ( ( ( hubs[ i ] % 2 ) == 1 ) ? -1 : 1 );
		org = ( info.org[ 0 ] - 54, info.org[ 1 ] + ( side * 139 ), tod_spire_data::spire_door_z( hubs[ i ] ) );
		level thread dev_spire_pad( org, hubs[ ( i + 1 ) % hubs.size ] );
	}
}

// THE ROUND-<n> ASCENT (2026-10-02, user: "on round 5 send me to the endless
// spire"): the harness waits here until round n has begun, then for any card
// deal the rollover opened (ascending under an open panel tears the tower down
// beneath it - the round-1 wait above, same bound), and returns to ascend.
function dev_ascend_at_round( n )
{
	level endon( "end_game" );

	IPrintLnBold( "DEV: Rampage is in the base arena - THE CHOICE opens in the crown hall at round " + n );
	while ( !isdefined( level.round_number ) || level.round_number < n )
		wait 0.5;
	for ( i = 0; i < 120 && IS_TRUE( level.tod_upgrade_pause ); i++ )
		wait 0.25;
	line = "[TOD_DEV] ms=" + GetTime() + " ASCEND_AT_ROUND round=" + level.round_number + " pause=" + IS_TRUE( level.tod_upgrade_pause );
	/#
	PrintLn( line );
	#/
}

// One dev warp pad: a use-trigger at org that sends the living party to hub
// <hub>'s door landing (dev_spire_warp_hub). Persistent — hold it as often as
// wanted. Refused while a trial (or the King, who sets the same field) holds
// the spire sealed: the pads all stand outside the seals, but a warp mid-trial
// would drop the party onto another hub while the fight is still counting them.
function dev_spire_pad( org, hub )
{
	level endon( "end_game" );

	t = Spawn( "trigger_radius_use", org + ( 0, 0, 32 ), 0, 64, 96 );
	t TriggerIgnoreTeam();      // REQUIRED for a script-spawned use-trigger
	t SetCursorHint( "HINT_NOICON" );
	t SetHintString( "Hold ^3[{+activate}]^7 ^5TELEPORTER^7 - DEV WARP to the NEXT HUB" );
	for ( ;; )
	{
		t waittill( "trigger", player );
		if ( !isdefined( player ) || !isplayer( player ) || !isalive( player ) )
			continue;
		if ( IS_TRUE( level.tod_trial_active ) )
		{
			IPrintLnBold( "DEV: a trial is running - the pad waits for it" );
			wait 1;
			continue;
		}
		dev_spire_warp_hub( hub );
		wait 1;
	}
}

// Opens doors 1..hub through the manager (guards suppressed), then places every
// living player on the landing BEFORE door <hub>, facing the doorway and the
// flight that climbs into the hall.
function dev_spire_warp_hub( hub )
{
	level endon( "end_game" );

	saved = ( ( isdefined( level.tod_panzer_alive ) ) ? level.tod_panzer_alive : 0 );
	level.tod_panzer_alive = 99;
	opened = 0;
	for ( n = 1; n <= hub; n++ )
	{
		if ( !isdefined( level.tod_spire_next_door_z ) )
			break;   // the manager is past its last door
		if ( level flag::exists( "enter_spire" + n ) && level flag::get( "enter_spire" + n ) )
			continue;   // already open (a real buy)
		level.tod_spire_door_bypassed = true;
		level notify( "tod_spire_door_bought" );
		// the manager sets the door's flag right after it consumes the notify;
		// waiting on it proves this one landed before the next is sent
		if ( level flag::exists( "enter_spire" + n ) )
			level flag::wait_till_timeout( 2, "enter_spire" + n );
		else
			wait 0.2;
		opened++;
	}
	wait 1;   // every door_guard_panzers thread takes its first (bailing) check
	level.tod_panzer_alive = saved;

	info = tod_spire_data::get_spire_door_info( hub );
	if ( !isdefined( info ) )
		return;
	// THE LANDING BEFORE THE DOOR, facing the flight. An ODD door's slab sits at
	// y -256 with the SE landing to its SOUTH and the E flight climbing north
	// beyond it; an EVEN door's slab sits at y +256 with the NW landing to its
	// NORTH and the W flight climbing south (gen_tower_map.js SPIRE_DOORS + 6b:
	// "NW landing -> W flight south"). Every hub is even. Until 2026-09-10 this
	// placed everyone at y - 60 facing +y for BOTH parities, which on a hub is
	// the first tread PAST the door, looking back at it.
	odd = ( ( hub % 2 ) == 1 );
	pos = ( info.org[ 0 ], info.org[ 1 ] + ( ( odd ) ? -74 : 74 ), tod_spire_data::spire_door_z( hub ) + 8 );
	yaw = ( ( odd ) ? 90 : 270 );
	players = GetPlayers();
	k = 0;
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		p SetOrigin( pos + ( ( ( k % 2 ) * 40 ) - 20, 0, 0 ) );
		p SetPlayerAngles( ( 0, yaw, 0 ) );   // into the doorway, up the flight, the hall beyond
		k++;
	}
	// (v17.56: every door is already open via tod_spire::dev_open_all_doors, so
	// the loop above frees nothing — it exits at once on next_door_z undefined.)
	IPrintLnBold( "DEV: warped to hub " + hub + " - walk up the flight into the hall to start the trial" );
}

// ---------------------------------------------------------------------------
// v17.97 — DEV PRINTS ARE MUTABLE. level.tod_dev_quiet (set beside tod_dev in
// zm_tower_of_doom::tod_resolve_dev_flags) silences every bottom-left IPrintLn
// in this file — screenshot sessions want dev + god with a clean HUD. Each
// print site's own tod_dev gate is unchanged; this is one extra gate under it.
// IPrintLnBold (real game toasts) is not routed here.
function tod_quiet_print( msg )
{
	if ( IS_TRUE( level.tod_dev_quiet ) )
		return;
	IPrintLn( msg );
}

function tod_quiet_print_to( msg )   // self = the player to print to
{
	if ( IS_TRUE( level.tod_dev_quiet ) )
		return;
	self IPrintLn( msg );
}
