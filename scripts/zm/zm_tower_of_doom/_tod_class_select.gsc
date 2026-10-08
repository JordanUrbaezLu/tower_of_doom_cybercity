// =============================================================================
// _tod_class_select.gsc — the game-start class draft (user 2026-08-19: "each
// player must select a class before the game starts. That will be 60s max (was 30s until v15)
// unless everyone selected. If not selected itll pick a random class").
//
// Flow: after the intro blackscreen, the world pauses (the SAME
// set_world_pause the upgrade events use — round-1 spawning holds on the
// stock world_is_paused flag), every player gets the 4-card class panel
// (tod_class_select.lua). Lock or 60s timeout (random class) — when everyone
// is done the world unpauses and round 1 begins. Players who lock early get
// their controls back; the pick is PERMANENT (stations removed 2026-08-20).
//
// CLIENTFIELD BUDGET (the 2026-08-19 overflow lesson — map load ABORTS to
// the lobby when clientuimodel overflows): this panel owns only todClsShow
// (2 bits). Focus, countdown and the hold bar RIDE the upgrade panel's
// todUpgFocus / todUpgTime / todUpgHold — the two panels are never on screen
// together (draft = pre-round-1; upgrades = round 2+), and each Lua hides
// itself unless its own Show field is live. The countdown is HALVED into the
// 4-bit todUpgTime (60s -> 15 at quarter-second resolution; the Lua displays x4). The picked class is
// whatever todUpgFocus holds when todClsShow goes to 2.
//
// Class ids: 1 SKIRMISHER / 2 ASSAULT / 3 HEAVY / 4 SLASHER / 5 MAGE (docs/114,
// gated OFF -- only dealt when TOD_CLS_COUNT is 5) — MUST mirror
// tod_class_select.lua's CLASSES table and class_key() below.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\zm_tower_of_doom\_tod_mage.gsh;   // TOD_MAGE_ENABLED + TOD_CLS_COUNT (docs/114)

#using scripts\zm\zm_tower_of_doom\_tod_classes;
#using scripts\zm\zm_tower_of_doom\_tod_upgrades;

#precache( "lui_menu", "tod_class_select" );

// THE DRAFT IS 60 SECONDS (v15 item 17, user 2026-08-31: "Change class
// selection to 1 minute"). Was 30.
//
// ⚠️ THIS NUMBER IS CONSTRAINED BY A CLIENTFIELD, NOT BY TASTE. todUpgTime is a
// FOUR-BIT field (max 15) and the countdown is encoded into it by division, so
// the timeout must divide into 15 buckets or fewer. 30s did that at HALF-second
// resolution (30/2 = 15, exactly full). 60s does NOT fit at half-seconds
// (60/2 = 30, which needs 5 bits), so the encoding moved to QUARTER-seconds:
// 60/4 = 15, again exactly full.
//
// WHY NOT JUST SPEND A BIT: the clientuimodel pool sits at 60 of a PROVEN 61-bit
// ceiling, and overflow is a map-load abort to the lobby, not a glitch. The last
// free bit is not worth a countdown's resolution.
//
// WHAT IT COSTS: the panel's timer now ticks in 4-second steps (60, 56, 52...)
// instead of 2. Keep TOD_CLS_TIMEOUT a multiple of 4 and <= 60, or the display
// truncates. tod_class_select.lua multiplies by 4 to decode — LOCKSTEP.
#define TOD_CLS_TIMEOUT     60
// TOD_CLS_COUNT MOVED to _tod_mage.gsh (2026-09-07): the card count and the
// MAGE gate are one decision, and a GSC #define does not cross files, so they
// have to share a header or drift. tod_class_select.lua's CLASS_N is the Lua
// mirror; build_map.ps1 asserts all three literals agree.
#define TOD_CLS_HOLD_SECS   0.5

#namespace tod_class_select;

function init()
{
	level endon( "end_game" );

	level.tod_class_select_done = false;

	level flag::wait_till( "initial_blackscreen_passed" );
	wait 0.5;   // let the stock HUD settle before the panel fades in

	// DEV SHORT-CIRCUIT (user 2026-09-01: "in dev mode spawn me in with maxed
	// out mp7 skirmisher class"; 2026-09-02: "spawn me in at max slasher" —
	// the class below is whichever the current test session asked for, it has
	// been skirmisher and slasher). SKIPS THE DRAFT ENTIRELY: no panel, no 60s
	// timer, no world pause. Everyone is that class at tier 3 with every
	// domain maxed, which is the state a balance change has to be judged in.
	//
	// It returns BEFORE set_world_pause( true ) below, so the pause is never
	// taken and there is nothing to release — an early return here cannot
	// strand a frozen world. That ordering is load-bearing; do not move this
	// block below the pause.
	//
	// tod_class_select_done is still set, because _tod_classes::on_player_spawned
	// reads it to decide whether a classless late-joiner gets a random class.
	// Leaving it false would make every respawn classless.
	// DEV SHORT-CIRCUIT REMOVED 2026-09-03 (user: "I dont want all upgrades
	// either" / "why does the icon show assault but im slasher"). The block that
	// lived here under level.tod_dev skipped the draft, forced EVERY player to
	// one class (slasher since 2026-09-02, skirmisher before) and threaded
	// tod_upgrades::dev_grant_maxed — a test harness for a damage-ceiling read,
	// left armed. On dev the map now runs the REAL draft like a ship build: pick
	// a class through the same panel. As of 2026-09-27, _tod_main maxes that
	// CHOSEN class in dev mode after the first card panel closes.

	// Hold round-1 spawning + freeze anything already alive (none, normally).
	// 2026-09-13 staff test: assign through the real class/body/HUD path before
	// acquiring the world pause. _tod_main's existing maxed harness owns the
	// single upgrade grant after this completion flag; do not grant twice.
	if ( IS_TRUE( level.tod_dev ) && IS_TRUE( level.tod_dev_mage_test ) )
	{
		players = GetPlayers();
		foreach ( p in players )
		{
			if ( !isdefined( p ) || !isplayer( p ) ) continue;
			tod_classes::assign_class( p, "mage" );
			p LuiNotifyEvent( &"tod_upg_class", 1, tod_classes::class_id( "mage" ) );
			p thread tod_classes::give_class_loadout();
			p.tod_cls_done = true;
		}
		level.tod_class_select_done = true;
		line = "[TOD_STAFF_TEST] ms=" + GetTime() + " AUTO_CLASS class=mage players=" + players.size;
		/#
		PrintLn( line );
		#/
		return;
	}

	tod_upgrades::set_world_pause( true );

	players = GetPlayers();
	foreach ( p in players )
	{
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p.tod_cls_done = false;
		p thread player_select();
	}

	// Wait for everyone DEALT into the draft (tod_cls_done defined) — a player
	// who hot-joins mid-draft is NOT counted (they were never dealt a panel;
	// the sweep below classes them). Disconnects drop out of GetPlayers.
	for ( ;; )
	{
		wait 0.25;
		waiting = 0;
		players = GetPlayers();
		foreach ( p in players )
		{
			if ( isdefined( p ) && isplayer( p ) &&
			     isdefined( p.tod_cls_done ) && !p.tod_cls_done )
				waiting++;
		}
		if ( waiting == 0 )
			break;
	}

	level.tod_class_select_done = true;

	// Sweep: anyone still classless (hot-joined mid-draft) gets a random
	// class now — never leave a player pistol-only.
	players = GetPlayers();
	foreach ( p in players )
	{
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		if ( !isdefined( p.tod_class ) )
		{
			tod_classes::assign_class( p, class_key( 1 + RandomInt( TOD_CLS_COUNT ) ) );
			p thread tod_classes::give_class_loadout();
			// (on-screen text removed 2026-08-20 — user: no floaty text)
		}
	}

	// THE ROUND-1 UPGRADE (user 2026-08-20: "when you pick your class you
	// will get an upgrade too. So 1, 4, 8, 12, ..."): the world is still
	// held — deal the first cards right as the class panels close. The
	// event's own pause nesting is idempotent with ours.
	wait 0.5;   // a beat between the class flash and the cards
	tod_upgrades::run_upgrade_event();

	tod_upgrades::set_world_pause( false );
}

// id 1..5 -> the _tod_classes registry key (5 = MAGE, gated OFF, docs/114). Mirror tod_class_select.lua.
function class_key( id )
{
	// Draft positions only; registry/HUD class IDs remain unchanged.
	// Mirror DISPLAY_CLASSES in tod_class_select.lua.
	if ( TOD_MAGE_ENABLED )
	{
		if ( id == 3 )
			return "mage";
		if ( id == 4 )
			return "heavy";
		if ( id == 5 )
			return "slasher";
	}
	switch ( id )
	{
		case 1: return "skirmisher";
		case 2: return "assault";
		case 3: return "heavy";
		case 4: return "slasher";
		case 5: return "mage";   // docs/114 -- only reachable when TOD_CLS_COUNT is 5
	}
	return "assault";
}

function default_focus()
{
	return ( ( TOD_MAGE_ENABLED ) ? 3 : 1 );
}

function set_field( name, v )   // self = player
{
	self clientfield::set_player_uimodel( name, v );
}

// self = player. The full select interaction — same buttons as the upgrade
// cards (D-pad/stick moves, HOLD JUMP locks), riding the shared fields.
function player_select()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self.tod_cls_menu = self OpenLUIMenu( "tod_class_select" );

	self set_field( "todUpgFocus", default_focus() );
	self set_field( "todUpgTime", int( ( TOD_CLS_TIMEOUT + 3 ) / 4 ) );   // QUARTERED (Lua x4) — 4-bit field, see TOD_CLS_TIMEOUT
	self set_field( "todUpgHold", 0 );
	self set_field( "todClsShow", 1 );
	self PlayLocalSound( "tod_class_open" );

	// Soft-freeze (FreezeControls kills all input reads — live-test find):
	// movement pinned + weapons disabled, button/stick reads stay live.
	self tod_upgrades::menu_freeze( true );

	// [v16.93] THE DEVICE-READ PROBE — the missing piece for the design the user
	// asked for twice: *"the class menu continuously switching input assets
	// depending on what it detects, and after your first selection it stays with
	// that input for rest of game"*.
	//
	// THAT DESIGN IS RIGHT AND HAS NEVER BEEN BUILDABLE, for a reason worth
	// stating plainly: nothing has ever DETECTED anything. The lock buttons are
	// jump and use, which exist on both devices, so a lock-in proves nothing;
	// and the action-slot latch (tod_input_pad) is not a device proof either
	// (v16.81 — a keyboard binds 1-4 to action slots). Every "detection" in this
	// map so far has been a guess about which BUTTON was pressed, never about
	// which DEVICE pressed it. Freezing a guess at lock-in would only make the
	// wrong answer permanent, which is why it was refused rather than shipped.
	//
	// GetControllerType() is the first real candidate: mod tools API docs,
	// CLIENT/SERVER: Server, per-player, "returns the controller type of the
	// player". Stock never calls it anywhere in share/raw, so its return values
	// are UNKNOWN — it may report the pad MODEL rather than keyboard-vs-pad, and
	// may return nothing useful with no pad attached. So this prints it rather
	// than branching on it: one dev line at draft open, one at lock-in, and the
	// values decide whether the user's design can ship. DO NOT write a predicate
	// against this until the two readings (keyboard-only, and pad-in-hand) are
	// known — a guessed predicate is exactly the failure above with extra steps.
	if ( IS_TRUE( level.tod_dev ) )
	{
		ct = self GetControllerType();
		self tod_quiet_print_to( "^3[dev] GetControllerType at draft open = " + ( ( isdefined( ct ) ) ? ct : "UNDEFINED" ) );
	}

	sel = self run_select_input( TOD_CLS_TIMEOUT );

	if ( IS_TRUE( level.tod_dev ) )
	{
		ct2 = self GetControllerType();
		self tod_quiet_print_to( "^3[dev] GetControllerType at lock-in  = " + ( ( isdefined( ct2 ) ) ? ct2 : "UNDEFINED" )
			+ "  (pad-latch says " + ( ( IS_TRUE( self.tod_input_pad ) ) ? "PAD" : "kbm" ) + ")" );
	}

	// Timeout = random class (the user's rule).
	if ( sel == 0 )
	{
		sel = 1 + RandomInt( TOD_CLS_COUNT );
		// (on-screen text removed 2026-08-20 — user: no floaty text)
	}

	tod_classes::assign_class( self, class_key( sel ) );
	// v16.3 — tell this client's HUD Lua the class NOW: the deal panel's class
	// badge and the pause menu read CoD.TodClass, and _tod_upgrades only pushes
	// it before each deal. Same precached eventstring (_tod_upgrades.gsc).
	self LuiNotifyEvent( &"tod_upg_class", 1, tod_classes::class_id( class_key( sel ) ) );
	self thread tod_classes::give_class_loadout();

	// Confirm flash: focus carries the pick while Show==2 (the Lua reads it).
	self set_field( "todUpgFocus", sel );
	self set_field( "todUpgTime", 0 );
	self set_field( "todClsShow", 2 );
	self PlayLocalSound( "tod_class_jackin" );

	self tod_upgrades::menu_freeze( false );   // walk the (frozen) base while others pick

	wait 1.6;
	self set_field( "todClsShow", 0 );
	self set_field( "todUpgFocus", 0 );
	self set_field( "todUpgHold", 0 );

	self.tod_cls_done = true;
}

// self = player. Returns the locked class id 1..4, or 0 on timeout.
// D-PAD LEFT/RIGHT (actionslot 3/4) or the move stick CYCLES focus across
// the 4 cards — PER-SOURCE edge latches (one shared latch cross-fires) —
// and HOLD JUMP locks, with the hold bar on todUpgHold. Focus render is a
// steady bright accent (no server blink — the shared 3-bit focus field only
// carries 0..4; the hold bar is the lock feedback).
function run_select_input( timeout )
{
	self endon( "disconnect" );

	sel = default_focus();
	held = 0;
	last_dpad = 0;
	last_stick = 0;
	last_fwd = 0;    // W/S edge latch (v10.18 full-WASD)
	// v10.19 KBM widening (same pass as the upgrade panel — see the comment
	// there): mouse1 = previous card, mouse2 = next card; USE [F] joins JUMP
	// as hold-to-lock. Offhand/melee/reload latches SEEDED (v16.57) so a held trigger at open
	// cannot move focus on the first tick.
	// v10.20 — the real keyboard lane (full reasoning at the twin block in
	// _tod_upgrade_ui.gsc): ActionSlot3/4 are the controller D-PAD and no
	// keyboard key binds to them, and GetNormalizedMovement reads ~0 under the
	// menu freeze. Action buttons are what both devices actually bind, and
	// map 1's shipped keyboard picker (_acc_leaderboard.gsc:588-596) proves
	// MELEE + ADS work in-game on a keyboard. Four buttons for redundancy.
	// v16.57: the OFFHAND PAIR replaced fire/aim as the directional lane (twin
	// of the block in _tod_upgrade_ui::wait_for_choice — read it for the why).
	last_sec = ( ( self SecondaryOffhandButtonPressed() ) ? 1 : 0 );
	last_frag = ( ( self FragButtonPressed() ) ? 1 : 0 );
	last_mel = ( ( self MeleeButtonPressed() ) ? 1 : 0 );
	last_rld = ( ( self ReloadButtonPressed() ) ? 1 : 0 );
	use_armed = 0;
	last_focus = sel;
	// QUARTER-seconds, ceiling: int((n+3)/4). See TOD_CLS_TIMEOUT for why 4.
	last_quarter = int( ( timeout + 3 ) / 4 );
	hold_shown = 0;
	// JUMP RELEASE GATE — the twin of the one in _tod_upgrade_ui::wait_for_choice,
	// and the more important of the two: this panel opens right after the intro
	// blackscreen, when a player mashing jump through the load is entirely
	// ordinary, and the class pick is PERMANENT. Without this a held jump locks
	// SKIRMISHER ~0.5s in, before the cards have even been read. Holds only count
	// after the button has been seen released.
	jump_armed = 0;
	waited = 0;

	while ( waited < timeout )
	{
		secs = int( timeout - waited + 0.999 );
		quarter = int( ( secs + 3 ) / 4 );
		if ( quarter != last_quarter )
		{
			self set_field( "todUpgTime", quarter );
			last_quarter = quarter;
		}

		// --- focus cycling: PER-SOURCE edge latches -------------------------
		d_dir = 0;
		if ( self ActionSlotThreeButtonPressed() )
			d_dir = -1;
		else if ( self ActionSlotFourButtonPressed() )
			d_dir = 1;
		// DEVICE LATCH SEED (v14.20). Nothing in THIS menu changes behaviour —
		// the draft is a pre-spawn panel with no weapon in hand, so its extra
		// lanes were never the awkward ones and they all stay live here. The
		// write exists because the UPGRADE panel gates on this field, and the
		// draft is the earliest place in a match a player can prove they are on
		// a controller: ActionSlotThree/Four are the d-pad. (v16.81: NOT a
		// device proof after all — the player's own players/bindings_0.cfg
		// binds keyboard 1-4 to +actionslot 1/2/4/3, so a KBM player tapping 3
		// or 4 sets this too; the upgrade panel now gates only its STATION
		// lanes on it and keeps every lane live at round events.) Latching
		// here is what makes the ROUND-1 upgrade event already d-pad-only
		// instead of teaching itself one menu too late. Plain field, no import
		// (the KB cycle rule); it rides the player entity, so it survives the
		// spawn that follows this menu. Full contract at the twin block in
		// _tod_upgrade_ui::wait_for_choice.
		if ( d_dir != 0 && !IS_TRUE( self.tod_input_pad ) )
		{
			// v16.3 — twin of _tod_upgrade_ui::pad_latch (inlined: this file does
			// not import that module). The notify flips both LUI menus from the
			// keyboard plates (the PC default) to the pad plates; the eventstring
			// is precached in _tod_upgrade_ui.gsc.
			self.tod_input_pad = true;
			self LuiNotifyEvent( &"tod_input_pad", 1, 1 );
		}

		s_dir = 0;
		m = self GetNormalizedMovement();
		if ( isdefined( m ) )
		{
			if ( m[ 1 ] < -0.4 )
				s_dir = -1;
			else if ( m[ 1 ] > 0.4 )
				s_dir = 1;
		}

		// FULL WASD (v10.18, user 2026-08-24 — same pass as the upgrade
		// panel): W/S cycle the 4 cards exactly like A/D. W = previous,
		// S = next; the row wraps, so no direction can strand focus. Own
		// PER-SOURCE latch (this function's own header lesson: one shared
		// latch cross-fires between sources). Arrow keys ride the same axes
		// iff bound to movement — GSC has no raw-key read.
		f_dir = 0;
		if ( isdefined( m ) )
		{
			if ( m[ 0 ] > 0.4 )
				f_dir = -1;
			else if ( m[ 0 ] < -0.4 )
				f_dir = 1;
		}

		// MOUSE (v10.19): mouse1 = previous, mouse2 = next (the draft has no
		// weapons yet — pre-spawn menu — so the reads are pure input here).
		// ACTION BUTTONS (v10.20; v16.57): TACTICAL = previous, LETHAL = next —
		// the offhand pair sits left/right on every pad layout, which fire/aim
		// never did (see _tod_upgrade_ui::wait_for_choice) — MELEE and RELOAD =
		// next (wrapping). Pre-spawn menu, no weapon in hand, so these
		// reads are pure input here.
		sec = ( ( self SecondaryOffhandButtonPressed() ) ? 1 : 0 );
		frg = ( ( self FragButtonPressed() ) ? 1 : 0 );
		mel = ( ( self MeleeButtonPressed() ) ? 1 : 0 );
		rld = ( ( self ReloadButtonPressed() ) ? 1 : 0 );

		move = 0;
		if ( d_dir != 0 && d_dir != last_dpad )
			move = d_dir;
		else if ( s_dir != 0 && s_dir != last_stick )
			move = s_dir;
		else if ( f_dir != 0 && f_dir != last_fwd )
			move = f_dir;
		else if ( sec && !last_sec )
			move = -1;
		else if ( frg && !last_frag )
			move = 1;
		else if ( ( mel && !last_mel ) || ( rld && !last_rld ) )
			move = 1;
		last_dpad = d_dir;
		last_stick = s_dir;
		last_fwd = f_dir;
		last_sec = sec;
		last_frag = frg;
		last_mel = mel;
		last_rld = rld;

		if ( move != 0 )
		{
			sel = sel + move;
			if ( sel < 1 )
				sel = TOD_CLS_COUNT;
			if ( sel > TOD_CLS_COUNT )
				sel = 1;
			held = 0;
			self PlayLocalSound( "tod_ui_tick" );
		}

		// --- hold JUMP or USE to lock (v10.19: USE [F] joins for KBM) -------
		b_jump = self JumpButtonPressed();
		b_use = self UseButtonPressed();
		if ( !b_use )
			use_armed = 1;
		if ( b_jump || ( b_use && use_armed ) )
		{
			// Jump held from before the panel opened — ignore until released
			// (use has its own arm above, same reason).
			if ( ( b_jump && jump_armed ) || ( b_use && use_armed ) )
			{
				held += 0.05;
				if ( held >= TOD_CLS_HOLD_SECS )
				{
					self set_field( "todUpgHold", 15 );
					return sel;
				}
			}
		}
		else
		{
			jump_armed = 1;   // released at least once — holds count from here
			held = 0;
		}

		hv = int( held / TOD_CLS_HOLD_SECS * 15 );
		if ( hv > 15 )
			hv = 15;
		if ( hv != hold_shown )
		{
			self set_field( "todUpgHold", hv );
			hold_shown = hv;
		}

		if ( sel != last_focus )
		{
			self set_field( "todUpgFocus", sel );
			last_focus = sel;
		}

		wait 0.05;
		waited += 0.05;
	}

	return 0;   // timeout
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
