// =============================================================================
// _tod_upgrade_ui.gsc — upgrade-choice UI, server half (logic + input).
//
// v2 = real LUI (ui/uieditor/menus/hud/tod_upgrade.lua, the map 1 4-file
// contract: this #precache + OpenLUIMenu, the CSC LuiLoad, the zone rawfile
// line). This module owns STATE + INPUT; the Lua is a dumb renderer fed by
// all-INT clientuimodel clientfields (18 as of v4.4, registered here + in
// the .csc twin in EXACT lockstep — a width/order mismatch corrupts the bit
// layout; APPEND ONLY). This module is the ONE home for every clientuimodel
// registration (upgrade panel + damage numbers + mag chip + class draft).
//
// Input (v4.4): a card is ALWAYS focused — D-PAD/stick switches, HOLD JUMP
// 0.5s locks (with a hold-progress bar via todUpgHold), release cancels.
// Focus pulse is SERVER-driven (this loop toggles bright/dim ~7 Hz — client
// UITimers are the map 1 leak trap). Sounds: tick on switch, confirm on
// lock, SUPER/ULTIMATE stings on reveal (aliases in sound/aliases/tod_ui.csv).
//
// tod_upgrades calls `player present_choice( opts, timeout )` -> returns 1|2.
// =============================================================================

#using scripts\shared\callbacks_shared;   // on_connect -> the per-life overlay rebuild
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "lui_menu", "tod_upgrade" );

// Hold-to-lock duration. -35% (user 2026-08-21): 0.5 -> 0.325s.
#define TOD_UPG_HOLD_SECS   0.325
#define TOD_UPG_BLINK_SECS  0.15
// Damage-number accumulation window — one server frame. See push_dmg_num.
#define TOD_DMGNUM_WINDOW   0.05

#namespace tod_upgrade_ui;

REGISTER_SYSTEM( "tod_upgrade_ui", &__init__, undefined )

function __init__()
{
	// MUST match _tod_upgrade_ui.csc EXACTLY (scope/name/version/bits/type,
	// same order). Our clientuimodel pool is otherwise empty.
	// CLASS TIERS widening (2026-08-22, docs/25 §8 Phase 0): the domain-id
	// fields grow 5 -> 6 bits (ids 1..63; the tier card is 24 and the per-gun
	// uniques 25..31 did not fit in 31). Paid for by todMagBonus 7 -> 1 — the
	// virtual mag pool was deleted 2026-08-20 and the field has read 0 ever
	// since. Net 61 -> 57 custom bits. ORDER UNCHANGED.
	clientfield::register( "clientuimodel", "todUpgShow",  VERSION_SHIP, 2, "int" );
	clientfield::register( "clientuimodel", "todUpgAD",    VERSION_SHIP, 6, "int" );   // 6 bits: domain ids 1..63 (was 5, 2026-08-22)
	clientfield::register( "clientuimodel", "todUpgAR",    VERSION_SHIP, 2, "int" );
	clientfield::register( "clientuimodel", "todUpgAL",    VERSION_SHIP, 4, "int" );
	clientfield::register( "clientuimodel", "todUpgBD",    VERSION_SHIP, 6, "int" );   // 6 bits: domain ids 1..63 (was 5, 2026-08-22)
	clientfield::register( "clientuimodel", "todUpgBR",    VERSION_SHIP, 2, "int" );
	clientfield::register( "clientuimodel", "todUpgBL",    VERSION_SHIP, 4, "int" );
	clientfield::register( "clientuimodel", "todUpgLuck",  VERSION_SHIP, 4, "int" );
	clientfield::register( "clientuimodel", "todUpgFocus", VERSION_SHIP, 3, "int" );
	clientfield::register( "clientuimodel", "todUpgTime",  VERSION_SHIP, 4, "int" );   // seconds left, 15..0
	clientfield::register( "clientuimodel", "todMagBonus", VERSION_SHIP, 1, "int" );   // DEAD field (mag pool deleted 2026-08-20); 7 -> 1 bit 2026-08-22, always 0
	// Crosshair damage number (map 1's encoding): min(dmg,2047)*4 +
	// headshot*2 + parity (parity flips per push so identical numbers re-pop).
	clientfield::register( "clientuimodel", "todDmgNum",  VERSION_SHIP, 13, "int" );
	// Hold-to-lock progress 0..15 (the fill bar — SHARED by the upgrade panel
	// and the class draft; the two are never on screen together).
	clientfield::register( "clientuimodel", "todUpgHold", VERSION_SHIP, 4, "int" );
	// Class draft (_tod_class_select.gsc drives; tod_class_select.lua
	// renders): ONLY Show is class-specific — focus/time/hold RIDE the
	// todUpgFocus/todUpgTime/todUpgHold fields above (time is HALVED
	// server-side: 30s -> 15, the Lua displays x2). Show: 0 off / 1 choosing
	// / 2 locked-flash (the picked class = todUpgFocus at that moment).
	//
	// BUDGET (hard lesson 2026-08-19): the clientuimodel pool is SHARED with
	// stock zmhud.* + the Aetherium kit. 83 custom bits OVERFLOWED the pool
	// (Com_ERROR "clientuimodel is out of space" evicting zmhud.swordState =
	// map load aborts to the lobby). 61 custom bits was the last
	// PROVEN-BOOTED budget; this layout = 57 (the 2026-08-22 widening above
	// trimmed 4). Adding ANY field needs an equal trim.
	clientfield::register( "clientuimodel", "todClsShow",  VERSION_SHIP, 2, "int" );
	// THE FINALE ROAD BANNER (v10.26) — 1 bit, on/off. The blink is done
	// client-side in tod_upgrade.lua, so the wire only ever carries the state
	// change: two writes per game, not one per flash.
	// BUDGET: this takes the layout from 57 to 58 of the 61 PROVEN-BOOTED bits.
	// Three left. The next field still has to pay for itself by trimming one.
	clientfield::register( "clientuimodel", "todFinaleWarn", VERSION_SHIP, 1, "int" );

	// Guarantees every panel is down when the run ends — see clear_ui_on_end.
	level thread clear_ui_on_end();

	// The per-life overlay rebuild — see player_lui_life for the why.
	callback::on_connect( &on_player_connect );
}

// SHOTGUNS READ ONE PELLET (user 2026-08-25: "when i use a shot gun the damage
// indicators dont add up ... Im shooting the executioner and it shows 150 to the
// head but its killing the zombie on round 10").
//
// THE CAUSE IS THE CHANNEL, NOT THE MATH. todDmgNum is ONE clientuimodel field,
// and a networked field carries only its LAST value per server snapshot. A
// pellet shotgun raises one damage event PER PELLET, all inside the same server
// frame, so the eight writes below collapsed into one and the player saw a
// single pellet. The Executioner is 50/pellet x 8; a headshot is x3 = 150 per
// pellet — exactly the number reported — while the zombie actually ate 1,200.
// Nothing was wrong with the damage; only with what got drawn.
//
// MAP 1 HIT THIS AND SOLVED IT DIFFERENTLY: _acc_dev.gsc queues every event in a
// ring buffer and drains ONE per ~0.025s, so a shotgun reads as a fast flurry of
// eight separate numbers. That works, and it is why that map needed a parity bit
// and a self-terminating push loop. WE SUM INSTEAD, because the user asked for
// "a single damage number" and because summing is strictly cheaper: one network
// write per shot instead of eight, no drain loop to stall, and no queue to
// overflow on a Death Machine.
//
// THE WINDOW IS ONE SERVER FRAME. Pellets from one trigger pull all land in the
// same frame, so 0.05s captures a shot completely while staying at or below the
// fastest fireTime in the roster (Death Machine 0.05, PaP MP7 0.0512) — and on
// those two, merging two consecutive bullets into one number is a readability
// win rather than a loss. The window is FIXED, not extended per hit, so
// sustained fire can never accumulate without ever flushing.
//
// It also merges one shot across MULTIPLE zombies (a penetrating round, a pellet
// spread over a crowd). That is deliberate: the number answers "what did that
// shot do", which is the question being asked.
// PUBLIC — accumulate a crosshair damage number. self = the attacking player.
// The actual push happens in dmg_num_flush one frame later.
function push_dmg_num( dmg, headshot )
{
	if ( !isdefined( dmg ) || dmg <= 0 )
		return;
	if ( !isdefined( self.tod_dmg_acc ) )
		self.tod_dmg_acc = 0;
	self.tod_dmg_acc += dmg;
	if ( IS_TRUE( headshot ) )
		self.tod_dmg_acc_head = true;   // any pellet in the head colours the number
	if ( !IS_TRUE( self.tod_dmg_acc_on ) )
	{
		self.tod_dmg_acc_on = true;
		self thread dmg_num_flush();
	}
}

// self = the attacking player. Threaded, because push_dmg_num is called from
// inside damage callbacks and a callback must never wait.
function dmg_num_flush()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	wait TOD_DMGNUM_WINDOW;

	total = self.tod_dmg_acc;
	head  = IS_TRUE( self.tod_dmg_acc_head );
	self.tod_dmg_acc = 0;
	self.tod_dmg_acc_head = false;
	self.tod_dmg_acc_on = false;

	if ( isdefined( total ) && total > 0 )
		self push_dmg_num_now( total, head );
}

// TENS ENCODING (2026-08-20 — the old raw cap of 2047 flattened insta-kill
// 3x headshots into a fixed "2047"; user read it as broken): the 11-bit
// value now carries dmg/10, the Lua displays x10. Cap = 20,470 shown,
// rounded to the nearest 10 (nothing meaningful is single-digit here).
// SUMMING MAKES THAT CAP EASIER TO REACH — a PaP shotgun headshot is now one
// number rather than eight — but it cannot be widened: todDmgNum is 13 bits and
// 2047*4+3 is exactly 8191, and the clientuimodel pool is at 57 of the 61
// PROVEN-BOOTED bits, so a wider field would have to be paid for by trimming
// another one.
function push_dmg_num_now( dmg, headshot )
{
	dmg = int( ( dmg + 5 ) / 10 );
	if ( dmg > 2047 )
		dmg = 2047;
	if ( dmg < 1 )
		dmg = 1;
	if ( !isdefined( self.tod_dmg_parity ) )
		self.tod_dmg_parity = 0;
	self.tod_dmg_parity = 1 - self.tod_dmg_parity;
	v = dmg * 4 + self.tod_dmg_parity;
	if ( IS_TRUE( headshot ) )
		v += 2;
	self clientfield::set_player_uimodel( "todDmgNum", v );
}

// PUBLIC — the finale road banner. self = player. on/off only; the blinking is
// the Lua's job (CoD.TodFinaleWarn in tod_upgrade.lua), so a 90-second warning
// costs exactly two network writes.
// EVERY PANEL CLEARS ON end_game (audit 2026-08-25). todUpgShow is only zeroed
// on the NORMAL exit of a card pick, and the HEAVENLY GIFT ALTAR deliberately
// does NOT pause the world — so a wipe, or the finale ending, while a card was
// up left the panel frozen over the game-over screen. Same class of bug as the
// finale banner leak, and the same shape of fix: one thread with NO endon, so
// it is guaranteed to run on every exit path including ones added later.
function clear_ui_on_end()
{
	level waittill( "end_game" );
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p set_field( "todUpgShow", 0 );
		p set_field( "todClsShow", 0 );
		p set_field( "todUpgHold", 0 );
		p set_finale_warn( false );
	}
}

function set_finale_warn( on )
{
	v = 0;
	if ( IS_TRUE( on ) )
		v = 1;
	self clientfield::set_player_uimodel( "todFinaleWarn", v );
}

// DEAD SINCE 2026-08-20 (the virtual mag pool was deleted) — kept only so the
// Lua's MagChip subscription has a model. The field is 1 bit now (2026-08-22);
// never push anything but 0 through it.
function set_mag_bonus( n )   // self = player
{
	if ( n > 1 )
		n = 1;
	self clientfield::set_player_uimodel( "todMagBonus", n );
}

// self = player. Open the always-on overlay once (additive — cannot break the
// stock HUD; the widget stays invisible until todUpgShow goes nonzero).
function ensure_menu()
{
	if ( !isdefined( self.tod_upg_menu ) )
		self.tod_upg_menu = self OpenLUIMenu( "tod_upgrade" );
}

// ---------------------------------------------------------------------------
// PER-LIFE OVERLAY REBUILD (live report 2026-08-26: "when you get finished and
// you spectate your team and respawn half of the UI go away ... you can't
// choose the upgrade ... can't see the luck ... can't see where are you in
// the map").
//
// THE ENGINE CLOSES A PLAYER'S OpenLUIMenu MENUS ON THE DEATH -> SPECTATE
// TRANSITION, and ensure_menu()'s handle guard reads self.tod_upg_menu — a
// SERVER-side field that transition never clears — so after a respawn the
// guard was permanently satisfied and the menu never reopened. The player
// lost the entire tod_upgrade overlay for the rest of the match: upgrade
// cards, luck bar, tower gauge, damage numbers, finale banner — exactly the
// list in the report. (The upgrade EVENTS still ran server-side; the player
// was choosing blind.)
//
// This is map 1's fix ported (_acc_lui::player_lui_init; its user report
// 2026-06-24 was the same bug: "drops + perks don't show after a player dies
// and respawns"): reopen once per LIFE, then re-arm every change-gated feed
// so it re-pushes CURRENT state into the just-opened menu. Map 1 proved both
// halves: a value that hasn't changed since its last push never repaints a
// fresh menu on its own, and a same-value set_player_uimodel re-set DOES
// repaint once the GSC-side change tracker is cleared. "spawned_player"
// fires on the initial spawn AND every co-op respawn (stock _zm.gsc notify),
// so one loop covers both.
//
// The Aetherium kit needs none of this: it replaces T7Hud_zm_factory, the
// stock HUD menu, whose lifecycle the engine itself re-runs per spawn. The
// class-draft menu (tod_class_select) is round-1-once in a paused world and
// is never needed again, so it is deliberately not rebuilt here.
// ---------------------------------------------------------------------------
function on_player_connect()
{
	self thread player_lui_life();
}

function player_lui_life()
{
	self endon( "disconnect" );
	level flag::wait_till( "initial_blackscreen_passed" );

	b_first = true;
	for ( ;; )
	{
		// Respawns need a beat for the fresh client HUD to settle before the
		// reopen lands (map 1's 0.5s). Match start opens near-instantly so
		// the overlay is up the moment the fade lifts.
		if ( b_first )
			wait 0.05;
		else
			wait 0.5;
		b_first = false;

		if ( isdefined( self.tod_upg_menu ) )
			self CloseLUIMenu( self.tod_upg_menu );
		self.tod_upg_menu = undefined;
		self ensure_menu();
		wait 0.1;   // let the menu instantiate client-side before data lands

		// Re-arm the change-gated feeds so each re-pushes into the new menu:
		// the tower gauge + boss pip + max-HP lanes (_tod_gauge's 0.35s loop
		// re-sends the moment its per-player trackers read undefined) ...
		self.tod_gauge_f = undefined;
		self.tod_gauge_bf = undefined;
		self.tod_gauge_mh = undefined;
		// ... and the luck bar, whose pushes only ride luck CHANGES —
		// re-assert the current value directly. The upgrade cards need
		// nothing (every event re-sets its fields from scratch, todUpgShow
		// 0->1 included) and the finale banner's blink re-pushes all players
		// every cycle, so both self-heal.
		pct = 0;
		if ( isdefined( self.tod_luck_bar ) )
			pct = self.tod_luck_bar;
		self set_luck_pct( pct );

		self waittill( "spawned_player" );   // next death -> respawn: rebuild
	}
}

// domain key -> the Lua DOMAIN table id (MUST mirror tod_upgrade.lua AND the
// register_domains order in _tod_upgrades.gsc). v4 matrix 2026-08-19.
function domain_id( key )
{
	switch ( key )
	{
		case "damage":     return 1;
		case "dr":         return 2;
		case "bounty":     return 3;
		case "luck":       return 4;
		case "sprint":     return 5;
		case "headshot":   return 6;
		case "magsize":    return 7;
		case "reserve":    return 8;
		case "mobility":   return 9;
		case "bulletfeed": return 10;
		case "echo":       return 11;
		case "regen":      return 12;
		case "leech":      return 13;
		case "cleave":     return 14;
		case "firerate":   return 15;
		case "handling":   return 16;
		case "recoil":     return 17;
		case "knifespeed": return 18;
		case "penetration": return 19;
		case "thunder":     return 20;
		case "sprintfire":  return 21;
		case "lunge":       return 22;   // CHAIN LUNGE (2026-08-22)
		case "runandgun":   return 23;   // RUN AND GUN (2026-08-22) — skirmisher ammo saver
		// CLASS TIERS (docs/25, 2026-08-22). The field is 6 bits now (1..63).
		case "tier":        return 24;   // the TIER card — AL/BL carry (class-1)*2 + (tier-2)
		case "adrenaline":  return 25;   // MP5  (skirmisher T2) — kills grant a speed burst
		case "overdrive":   return 26;   // Death Machine (heavy T3, moved off the MP7 2026-08-23)
		case "killreload":  return 27;   // ASSAULT, any gun (un-bound from the Krig 2026-08-23)
		case "impact":      return 28;   // ASSAULT, any gun (un-bound from the AK-47 2026-08-23)
		case "suppress":    return 29;   // HK21 (heavy T2)      — hits slow the horde
		case "grinder":     return 30;   // Death Machine (heavy T3) — keep firing, hit harder
		case "drawcut":     return 31;   // Katana (slasher T2)  — swings out of a sprint hit harder
		case "sprintarmor": return 32;   // SPRINT ARMOR (2026-08-23) — skirmisher + slasher, -5%/Lv damage while sprinting
		case "secondwind":  return 33;   // SECOND WIND (2026-08-23) — skirmisher, MP7-bound, sprint to heal 1%/Lv per second
		case "momentum":    return 34;   // MOMENTUM (2026-08-23) — skirmisher class domain, damage scales with move speed
		case "bossdmg":     return 35;   // GIANT SLAYER (2026-08-23, v9.45) — assault, +4%/Lv vs the boss/elite triad (4% since 2026-08-26)
		case "backarmor":   return 36;   // BACK ARMOR (2026-08-23, v9.45) — assault + heavy, -10%/Lv from a rear arc
		case "march":       return 37;   // FORCED MARCH (2026-08-24) — assault, AK-47-bound, +5% move speed/Lv (no card art yet: 37 > PAUSE_PLATE_MAX, renders as text)
		// NOTE "echo" (11), "grinder" (30) and "lunge" (22) are still mapped above
		// even though all three domains were removed (echo + grinder 2026-08-23,
		// CHAIN LUNGE 2026-08-24). This switch is a KEY->id map, not an ordered
		// list, so a stale case is inert and removing one would only risk
		// disturbing ids that the Lua and the pause plates depend on.
	}
	return 0;
}

function set_field( name, v )   // self = player
{
	self clientfield::set_player_uimodel( name, v );
}

// PUBLIC — live luck-bar push, 0..100 -> tens (self = player). The top-left
// luck bar is all-LUI now (tod_upgrade.lua's LuckSegs watch todUpgLuck);
// _tod_luck calls this on every bar change. present_choice re-sets the same
// field at event time for the card readout — same scale, no conflict.
function set_luck_pct( pct )
{
	v = int( pct / 10 );
	if ( v > 10 )
		v = 10;
	if ( v < 0 )
		v = 0;
	// The HUD menu hosts the LuckSegs — but never OpenLUIMenu pre-blackscreen
	// (the field set itself is safe anytime; the menu reads it on subscribe).
	if ( level flag::get( "initial_blackscreen_passed" ) )
		self ensure_menu();
	self set_field( "todUpgLuck", v );
}

// self = player. opts = array of 1-2 option structs (see _tod_upgrades).
// Returns 1 or 2.
function present_choice( opts, timeout )
{
	self endon( "disconnect" );

	self ensure_menu();

	a = opts[ 0 ];
	self set_field( "todUpgAD", domain_id( a.domain ) );
	self set_field( "todUpgAR", a.rarity );
	self set_field( "todUpgAL", a.cur );

	if ( isdefined( opts[ 1 ] ) )
	{
		b = opts[ 1 ];
		self set_field( "todUpgBD", domain_id( b.domain ) );
		self set_field( "todUpgBR", b.rarity );
		self set_field( "todUpgBL", b.cur );
	}
	else
	{
		self set_field( "todUpgBD", 0 );
	}

	// Card readout = the LUCK BAR in tens (0..10 -> "LUCK n0%" in the Lua).
	luck = 0;
	if ( isdefined( self.tod_luck_bar ) )
		luck = int( self.tod_luck_bar / 10 );
	if ( luck > 10 )
		luck = 10;
	self set_field( "todUpgLuck", luck );

	self set_field( "todUpgFocus", 1 );   // left card focused by default
	self set_field( "todUpgTime", int( timeout ) );
	self set_field( "todUpgHold", 0 );
	self.tod_upg_hold_shown = 0;
	self set_field( "todUpgShow", 1 );

	// RARITY STING (user 2026-08-19: "sounds that happen when you pull a super
	// or ultimate"): the reveal plays the highest rarity's sting.
	best_rarity = opts[ 0 ].rarity;
	if ( isdefined( opts[ 1 ] ) && opts[ 1 ].rarity > best_rarity )
		best_rarity = opts[ 1 ].rarity;
	if ( best_rarity >= 3 )
		self PlayLocalSound( "tod_ultimate_sting" );
	else if ( best_rarity == 2 )
		self PlayLocalSound( "tod_super_sting" );

	// The freeze is the CALLER's job now (tod_upgrades::menu_freeze — the
	// soft-freeze: FreezeControls kills ALL input reads, live-test 2026-08-19).

	self.tod_upg_timed_out = false;
	choice = self wait_for_choice( opts, timeout );

	// confirm flash (Lua: chosen card teal, other recedes), then hide
	self set_field( "todUpgFocus", 0 );
	self set_field( "todUpgTime", 0 );
	self set_field( "todUpgShow", ( ( choice == 1 ) ? 2 : 3 ) );
	wait 0.7;
	self set_field( "todUpgShow", 0 );

	return choice;
}

// self = player. MENU-style input (user 2026-08-18): a card is ALWAYS focused
// (left by default, blinking); switch focus with D-PAD LEFT/RIGHT (actionslot
// 3/4), the MOVE STICK / strafe keys, or AIM/FIRE as fallbacks; HOLD JUMP (A /
// space) for 0.5s to lock the focused card in (blink speeds up while held).
// Timeout locks whatever is focused. Controls are frozen — none of these
// inputs leak into gameplay.
function wait_for_choice( opts, timeout )
{
	self endon( "disconnect" );

	two = isdefined( opts[ 1 ] );
	sel = 1;         // focused card: 1 left, 2 right
	held = 0;
	phase = 0;       // blink phase 0/1
	blink_t = 0;
	last_focus = 0;
	last_secs = int( timeout );
	last_strafe = 0; // KBM strafe edge latch (v10.3)
	last_fwd = 0;    // KBM W/S edge latch (v10.18 — full-WASD, user 2026-08-24)
	// v10.19 (user retest: "Controller works fine but keyboard still does
	// nothing"): the whole KBM lane so far rides GetNormalizedMovement + the
	// jump read, and NEITHER has ever been live-verified on a keyboard — map
	// 1's freeze lesson and every menu test since were controller runs. So the
	// menu now ALSO listens on reads the engine core exercises constantly and
	// that a keyboard definitely owns: MOUSE1 = left card, MOUSE2 = right card
	// (weapons are DisableWeapons'd for every choice — player_choice_flow wraps
	// present_choice in menu_freeze — so the press cannot fire the gun), and
	// HOLD USE [F] locks alongside JUMP. On controller these add RT/LT/X as
	// bonus inputs, which is harmless.
	// SEEDED latches: attack/ads are sampled ONCE before the loop so a button
	// already held when the panel opens (RT mid-fight) cannot flip focus on the
	// first tick. USE gets the jump treatment (arm-on-release) because the
	// STATION is opened by hold-F — without arming, the buy hold would
	// insta-lock the left card.
	// v10.20 — THE ACTUAL KEYBOARD LANE, and why it is these four buttons.
	// RESEARCH RESULT (workflow 2026-08-24, five parallel source audits):
	//   * ActionSlotThree/Four ARE THE CONTROLLER D-PAD, provably — stock maps
	//     them at util_shared.gsc:2404 ( _button_funcs[ BUTTON_RIGHT ] =
	//     &ActionSlotFourButtonPressed ). BO3 PC binds NO keyboard key to an
	//     action slot in zombies, so on a keyboard they are permanently false.
	//     That is the whole "controller works, keyboard does nothing" report:
	//     the working input was always the D-PAD.
	//   * GetNormalizedMovement is documented as "the player's MOVEMENT
	//     normalized" — not the movement INPUT — and every card flow wraps this
	//     in menu_freeze(), which pins SetMoveSpeedScale to 0.001. A
	//     movement-derived read under a 0.001 pin is ~0 FOR BOTH DEVICES. It is
	//     kept below as a free bonus lane, but nothing depends on it, and
	//     Treyarch never calls it anywhere in shareaw.
	// SO THE LANE IS ACTION BUTTONS, which BOTH devices bind by default. The
	// precedent is the author's OWN SHIPPED CODE: map 1's leaderboard consent
	// card (_acc_leaderboard.gsc:588-596) is an in-game hold-to-choose picker
	// driven by MeleeButtonPressed + AdsButtonPressed, played on keyboard.
	// FOUR buttons, not two, deliberately: menu_freeze calls DisableWeapons(),
	// and if that ever suppresses the attack/ads reads, MELEE and RELOAD are an
	// independent path to the same result. Redundancy is the point.
	last_atk = ( ( self AttackButtonPressed() ) ? 1 : 0 );
	last_ads = ( ( self AdsButtonPressed() ) ? 1 : 0 );
	last_mel = ( ( self MeleeButtonPressed() ) ? 1 : 0 );
	last_rld = ( ( self ReloadButtonPressed() ) ? 1 : 0 );
	use_armed = 0;
	probe_t = 0;     // dev input probe cadence
	// (The v10.19 LUI keyboard bridge was REMOVED in v10.20 — see the input
	// research note at the latch block above. It never had a precedent: every
	// OpenLUIMenu menu in stock, in map 1 and in this map is display-only, and
	// a HUD-layer menu is not on the focused menu stack, so its button
	// callbacks were never dispatched to. Replaced by the action-button lane.)
	last_dpad = 0;   // d-pad edge latch (v10.4): level reads re-asserted a held
	                 // direction every tick and snapped focus back against a
	                 // fresh strafe flip (audit find)
	// JUMP RELEASE GATE (co-op audit 2026-08-23): the loop samples
	// JumpButtonPressed() with no press-edge, so a player ALREADY holding jump
	// when the panel opens accumulates `held` from frame one and auto-locks the
	// left card ~0.3s later, before they have read either option. That is not a
	// corner case: menu_freeze uses AllowJump(false), which suppresses the hop
	// but NOT the button read, and the round-1 event drops its cards while
	// players who locked their class early are free-running the base. The
	// personal station is worse — the world is not paused there, so a dodge-hop
	// mid-fight pays for a card. Holds only count once we have seen the button
	// RELEASED at least once, so a press must start after the panel is up.
	jump_armed = 0;
	waited = 0;

	while ( waited < timeout )
	{
		// countdown readout (whole seconds, only on change)
		secs = int( timeout - waited + 0.999 );
		if ( secs != last_secs )
		{
			self set_field( "todUpgTime", secs );
			last_secs = secs;
		}

		// WENT DOWN MID-CARD -> RELEASE THEM NOW (live-report audit 2026-08-26).
		//
		// THE CALLER'S menu_freeze STILL HOLDS DisableWeapons(), AND STOCK NEVER
		// UNDOES IT. This is the whole reason this guard exists, and it is worth
		// stating precisely because it is counter-intuitive: stock's last-stand
		// path does NOT use DisableWeapons at all — it uses DisableWeaponCycling
		// (_zm_laststand.gsc:290) and restores with EnableWeaponCycling +
		// EnableOffhandWeapons (:369-403). Nothing on the down, bleedout or
		// revive path ever calls EnableWeapons(). So a player who goes down
		// while the cards are up is handed the last-stand pistol by
		// _zm.gsc:2826-2892 (GiveWeapon + SwitchToWeapon), holds it on screen,
		// AND CANNOT FIRE IT — for up to TOD_UPG_CHOICE_TIMEOUT + the 0.7s
		// confirm flash. Stock itself uses DisableWeapons this way as a firing
		// lock (_zm.gsc:4855, playerzombie_downed_state).
		//
		// menu_freeze's own laststand check (_tod_upgrades.gsc:1087) is a
		// ONE-SHOT ENTRY test — it refuses to freeze someone already down, and
		// never looks again. This is the other half of that rule.
		//
		// REACHABLE despite the world being paused: the pause freezes AI, but
		// the Panzer's FLAMETHROWER BURN is stock _burnplayer.gsc's own per-player
		// damage loop and knows nothing about level.tod_upgrade_pause, so it keeps
		// ticking (_tod_bosses.gsc records the same exemption for the through-wall
		// shield). Panzers land every 5th round, events every 4th, and the
		// endless-rounds twist starts the next round while the last one's Panzer
		// is still alive — so the overlap is routine, not freak. A Protector
		// rocket already in flight and an in-flight melee notetrack do it too.
		//
		// `break`, NOT `return`: it falls into the existing timeout exit below
		// (tod_upg_timed_out = true; return sel), so no new exit path is created
		// and the caller still unfreezes on return. THE UPGRADE IS NOT
		// FORFEITED — apply_upgrade only refuses a timed-out TIER card, and
		// player_choice_flow already falls back to the other card; a domain card
		// pays out normally. Refusing a tier promotion mid-crawl is exactly the
		// rule the station path already enforces.
		if ( self laststand::player_is_in_laststand() )
			break;

		// --- focus switching: D-PAD ONLY ------------------------------------
		// User 2026-08-21: "change the controls of the upgrade menu to only
		// use the dpad". ActionSlotThree/Four ARE the d-pad left/right reads.
		// The old ADS/FIRE and movement-stick fallbacks are gone — with the
		// personal station no longer freezing the player, strafing to dodge
		// was silently flipping the card, and aiming/firing to fight was
		// selecting one.
		want = sel;
		d_dir = 0;
		if ( self ActionSlotThreeButtonPressed() )
			d_dir = 1;
		else if ( self ActionSlotFourButtonPressed() )
			d_dir = 2;
		if ( d_dir != 0 && d_dir != last_dpad )
			want = d_dir;   // edge-latched (v10.4) — a fresh press only
		last_dpad = d_dir;
		// KBM (playtest 2026-08-23: "Make sure KBM can pick the cards and
		// upgrades"): ActionSlot 3/4 are the D-PAD reads — a keyboard player
		// had NO way to move focus. A/D (the strafe axis; left stick on pad)
		// now switches too, EDGE-LATCHED like the class draft: only a FRESH
		// push flips, so holding a strafe to dodge flips once, not per-tick.
		// That per-tick flipping is what got the stick read removed on
		// 2026-08-21 — the latch is the difference, and KBM access outranks
		// the residual single flip (user directive).
		strafe = 0;
		mv = self GetNormalizedMovement();
		if ( isdefined( mv ) )
		{
			if ( mv[ 1 ] < -0.4 )
				strafe = -1;
			else if ( mv[ 1 ] > 0.4 )
				strafe = 1;
		}
		if ( strafe != 0 && strafe != last_strafe )
			want = ( ( strafe < 0 ) ? 1 : 2 );
		last_strafe = strafe;
		// FULL WASD (user 2026-08-24, from beta comments: "the upgrade menu
		// needs to be fully keyboard accessable. WASD, up left down right").
		// W/S = the forward axis (mv[0]); with exactly TWO cards side by side
		// there is no "up card", so a fresh W or S press flips focus to the
		// OTHER card — every direction key now moves focus, none is dead.
		// Same PER-SOURCE edge latch as the strafe (the draft's cross-fire
		// lesson): sign is irrelevant to a flip, so W-vs-S never inverts.
		// ARROW KEYS ride this same read, but only for players whose arrows
		// are BOUND to movement — GSC has no raw-key read, so unbound arrows
		// are invisible to script. WASD is the guaranteed lane.
		fwd = 0;
		if ( isdefined( mv ) )
		{
			if ( mv[ 0 ] < -0.4 )
				fwd = -1;
			else if ( mv[ 0 ] > 0.4 )
				fwd = 1;
		}
		if ( fwd != 0 && fwd != last_fwd )
			want = ( ( sel == 1 ) ? 2 : 1 );
		last_fwd = fwd;
		// ACTION BUTTONS (v10.20) — the keyboard lane. All edge-latched and
		// pre-seeded (see the latch block above), so a button already held when
		// the panel opens cannot flip focus on tick one.
		//   MOUSE1 / RT      -> LEFT card
		//   MOUSE2 / LT      -> RIGHT card
		//   MELEE (V / R3)   -> flip to the other card
		//   RELOAD (R / X)   -> flip to the other card
		atk = ( ( self AttackButtonPressed() ) ? 1 : 0 );
		ads = ( ( self AdsButtonPressed() ) ? 1 : 0 );
		mel = ( ( self MeleeButtonPressed() ) ? 1 : 0 );
		rld = ( ( self ReloadButtonPressed() ) ? 1 : 0 );
		if ( atk && !last_atk )
			want = 1;
		else if ( ads && !last_ads )
			want = 2;
		else if ( ( mel && !last_mel ) || ( rld && !last_rld ) )
			want = ( ( sel == 1 ) ? 2 : 1 );
		last_atk = atk;
		last_ads = ads;
		last_mel = mel;
		last_rld = rld;
		if ( !two )
			want = 1;
		if ( want != sel )
		{
			sel = want;
			held = 0;   // switching resets any lock progress
			phase = 0;
			blink_t = 0;
			self PlayLocalSound( "tod_ui_tick" );   // focus moved
		}

		// --- hold JUMP or USE to lock (v10.19: USE [F] joins for KBM) -------
		// Each button arms on its own first RELEASE (jump: pre-open hops; use:
		// the station is BOUGHT with hold-F, so the same finger is still down
		// when this panel opens). An armed hold on EITHER accumulates.
		b_jump = self JumpButtonPressed();
		b_use = self UseButtonPressed();
		if ( !b_jump )
			jump_armed = 1;
		if ( !b_use )
			use_armed = 1;
		if ( ( b_jump && jump_armed ) || ( b_use && use_armed ) )
		{
			held += 0.05;
			if ( held >= TOD_UPG_HOLD_SECS )
			{
				self set_field( "todUpgHold", 15 );
				self PlayLocalSound( "tod_ui_lock" );
				return sel;
			}
		}
		else
		{
			held = 0;
		}

		// DEV INPUT PROBE (v10.19): one line per second of exactly what the
		// server reads from this player — the tool that ends the "keyboard
		// does nothing" guessing. Read it off a KEYBOARD run: whichever
		// column stays 0 while the key is held is the dead read.
		if ( IS_TRUE( level.tod_dev ) )
		{
			probe_t += 0.05;
			if ( probe_t >= 1.0 )
			{
				probe_t = 0;
				mvp = self GetNormalizedMovement();
				fwd_p = 0;
				str_p = 0;
				if ( isdefined( mvp ) )
				{
					fwd_p = int( mvp[ 0 ] * 10 );
					str_p = int( mvp[ 1 ] * 10 );
				}
				self IPrintLn( "^3inp mv=" + fwd_p + "," + str_p
					+ " j=" + ( ( b_jump ) ? 1 : 0 ) + " u=" + ( ( b_use ) ? 1 : 0 )
					+ " m1=" + atk + " m2=" + ads + " mel=" + mel + " rld=" + rld
					+ " d34=" + ( ( self ActionSlotThreeButtonPressed() ) ? 1 : 0 )
					+ ( ( self ActionSlotFourButtonPressed() ) ? 1 : 0 ) );
			}
		}

		// hold-progress fill (0..15) — the bar under the focused card
		hv = int( held / TOD_UPG_HOLD_SECS * 15 );
		if ( hv > 15 )
			hv = 15;
		if ( !isdefined( self.tod_upg_hold_shown ) || self.tod_upg_hold_shown != hv )
		{
			self set_field( "todUpgHold", hv );
			self.tod_upg_hold_shown = hv;
		}

		// --- focus blink (faster while locking) ----------------------------
		blink_t += 0.05;
		interval = ( ( held > 0 ) ? ( TOD_UPG_BLINK_SECS * 0.5 ) : TOD_UPG_BLINK_SECS );
		if ( blink_t >= interval )
		{
			blink_t = 0;
			phase = 1 - phase;
		}

		focus = ( ( sel == 1 ) ? ( ( phase == 0 ) ? 1 : 2 ) : ( ( phase == 0 ) ? 3 : 4 ) );
		if ( focus != last_focus )
		{
			self set_field( "todUpgFocus", focus );
			last_focus = focus;
		}

		wait 0.05;
		waited += 0.05;
	}

	self.tod_upg_timed_out = true;
	return sel;   // timeout — lock whatever is focused
}

