// =============================================================================
// _tod_class_select.gsc — the game-start class draft (user 2026-08-19: "each
// player must select a class before the game starts. That will be 30s max
// unless everyone selected. If not selected itll pick a random class").
//
// Flow: after the intro blackscreen, the world pauses (the SAME
// set_world_pause the upgrade events use — round-1 spawning holds on the
// stock world_is_paused flag), every player gets the 4-card class panel
// (tod_class_select.lua). Lock or 30s timeout (random class) — when everyone
// is done the world unpauses and round 1 begins. Players who lock early get
// their controls back; the pick is PERMANENT (stations removed 2026-08-20).
//
// CLIENTFIELD BUDGET (the 2026-08-19 overflow lesson — map load ABORTS to
// the lobby when clientuimodel overflows): this panel owns only todClsShow
// (2 bits). Focus, countdown and the hold bar RIDE the upgrade panel's
// todUpgFocus / todUpgTime / todUpgHold — the two panels are never on screen
// together (draft = pre-round-1; upgrades = round 2+), and each Lua hides
// itself unless its own Show field is live. The countdown is HALVED into the
// 4-bit todUpgTime (30s -> 15; the Lua displays x2). The picked class is
// whatever todUpgFocus holds when todClsShow goes to 2.
//
// Class ids: 1 SKIRMISHER / 2 ASSAULT / 3 HEAVY / 4 SLASHER — MUST mirror
// tod_class_select.lua's CLASSES table and class_key() below.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\zm_tower_of_doom\_tod_classes;
#using scripts\zm\zm_tower_of_doom\_tod_upgrades;

#precache( "lui_menu", "tod_class_select" );

#define TOD_CLS_TIMEOUT     30
#define TOD_CLS_COUNT       4
#define TOD_CLS_HOLD_SECS   0.5

#namespace tod_class_select;

function init()
{
	level endon( "end_game" );

	level.tod_class_select_done = false;

	level flag::wait_till( "initial_blackscreen_passed" );
	wait 0.5;   // let the stock HUD settle before the panel fades in

	// Hold round-1 spawning + freeze anything already alive (none, normally).
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

// id 1..4 -> the _tod_classes registry key. Mirror tod_class_select.lua.
function class_key( id )
{
	switch ( id )
	{
		case 1: return "skirmisher";
		case 2: return "assault";
		case 3: return "heavy";
		case 4: return "slasher";
	}
	return "assault";
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

	self set_field( "todUpgFocus", 1 );
	self set_field( "todUpgTime", int( ( TOD_CLS_TIMEOUT + 1 ) / 2 ) );   // halved (Lua x2)
	self set_field( "todUpgHold", 0 );
	self set_field( "todClsShow", 1 );
	self PlayLocalSound( "tod_class_open" );

	// Soft-freeze (FreezeControls kills all input reads — live-test find):
	// movement pinned + weapons disabled, button/stick reads stay live.
	self tod_upgrades::menu_freeze( true );

	sel = self run_select_input( TOD_CLS_TIMEOUT );

	// Timeout = random class (the user's rule).
	if ( sel == 0 )
	{
		sel = 1 + RandomInt( TOD_CLS_COUNT );
		// (on-screen text removed 2026-08-20 — user: no floaty text)
	}

	tod_classes::assign_class( self, class_key( sel ) );
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

	sel = 1;
	held = 0;
	last_dpad = 0;
	last_stick = 0;
	last_fwd = 0;    // W/S edge latch (v10.18 full-WASD)
	// v10.19 KBM widening (same pass as the upgrade panel — see the comment
	// there): mouse1 = previous card, mouse2 = next card; USE [F] joins JUMP
	// as hold-to-lock. Attack/ads latches SEEDED so a held trigger at open
	// cannot move focus on the first tick.
	// v10.20 — the real keyboard lane (full reasoning at the twin block in
	// _tod_upgrade_ui.gsc): ActionSlot3/4 are the controller D-PAD and no
	// keyboard key binds to them, and GetNormalizedMovement reads ~0 under the
	// menu freeze. Action buttons are what both devices actually bind, and
	// map 1's shipped keyboard picker (_acc_leaderboard.gsc:588-596) proves
	// MELEE + ADS work in-game on a keyboard. Four buttons for redundancy.
	last_atk = ( ( self AttackButtonPressed() ) ? 1 : 0 );
	last_ads = ( ( self AdsButtonPressed() ) ? 1 : 0 );
	last_mel = ( ( self MeleeButtonPressed() ) ? 1 : 0 );
	last_rld = ( ( self ReloadButtonPressed() ) ? 1 : 0 );
	use_armed = 0;
	last_focus = 1;
	last_half = int( ( timeout + 1 ) / 2 );
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
		half = int( ( secs + 1 ) / 2 );
		if ( half != last_half )
		{
			self set_field( "todUpgTime", half );
			last_half = half;
		}

		// --- focus cycling: PER-SOURCE edge latches -------------------------
		d_dir = 0;
		if ( self ActionSlotThreeButtonPressed() )
			d_dir = -1;
		else if ( self ActionSlotFourButtonPressed() )
			d_dir = 1;

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
		// ACTION BUTTONS (v10.20): mouse1 = previous, mouse2 = next, MELEE and
		// RELOAD = next (wrapping). Pre-spawn menu, no weapon in hand, so these
		// reads are pure input here.
		atk = ( ( self AttackButtonPressed() ) ? 1 : 0 );
		ads = ( ( self AdsButtonPressed() ) ? 1 : 0 );
		mel = ( ( self MeleeButtonPressed() ) ? 1 : 0 );
		rld = ( ( self ReloadButtonPressed() ) ? 1 : 0 );

		move = 0;
		if ( d_dir != 0 && d_dir != last_dpad )
			move = d_dir;
		else if ( s_dir != 0 && s_dir != last_stick )
			move = s_dir;
		else if ( f_dir != 0 && f_dir != last_fwd )
			move = f_dir;
		else if ( atk && !last_atk )
			move = -1;
		else if ( ads && !last_ads )
			move = 1;
		else if ( ( mel && !last_mel ) || ( rld && !last_rld ) )
			move = 1;
		last_dpad = d_dir;
		last_stick = s_dir;
		last_fwd = f_dir;
		last_atk = atk;
		last_ads = ads;
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

