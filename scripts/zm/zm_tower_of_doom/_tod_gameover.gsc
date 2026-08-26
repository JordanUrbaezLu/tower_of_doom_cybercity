// =============================================================================
// _tod_gameover.gsc — the GAME-OVER DECISION MENU (v9.24, user 2026-08-23: "We
// need a fast restart menu after a game loss. Or else this is just annoying
// that you have to go back and everything. The other map had something like
// this").
//
// Port of map 1's retry-on-death v3 (_acc_leaderboard.gsc::offer_retry_on_death
// + docs/40) WITHOUT the leaderboard plumbing. On end_game:
//   1. synchronously park stock's auto-exit — _zm.gsc::end_game reads
//      level.zombie_vars["zombie_intermission_time"] (stock 15s) at :6208,
//      long after the notify, then ExitLevel(false) at :6250;
//   2. after a 3s settle (the intermission camera cut + stock's GAME OVER /
//      "survived N rounds" text fade in behind), release the scoreboard stock
//      forced up at :6204 (LUINotifyEvent force_scoreboard 1,0 — stock's own
//      release call, :6244), set the host-side dvar tod_go_active=1,
//      RE-ENABLE the ingame menu stock disabled at :6043 (SetMatchFlag
//      disableIngameMenu 0 — that flag is the ONLY gate, which is itself the
//      proof the menu works at intermission) and force-open StartMenu_Main on
//      every player (OpenMenu, the stock builtin _zm.gsc:636);
//   3. AetheriumStartMenu.lua's dvar-gated game-over mode then shows exactly
//      two native up/down entries — RESTART MAP (Engine.Exec map_restart: the
//      pause menu's own Restart Level lane — a full script restart WITHOUT the
//      lobby round-trip) and END GAME (the Leave Game disconnect lane). Both
//      act from the menu itself and tear the VM down; nothing returns here.
//   4. no choice in TOD_GO_DECIDE_SECS -> ExitLevel(false), stock's terminal
//      call; an independent failsafe exits at TOD_GO_FAILSAFE_SECS if this
//      thread ever died; stock's own parked wait is the last net. The game can
//      never sit on the death screen forever.
//
// The dvar is HOST-machine only: co-op peers get the normal pause list (Leave
// Game works there; restarting is the host's call). Dvars persist across
// map_restart within one app session, so init SCRUBS it — a leftover "1"
// would turn the next game's mid-run pause menu into the two-entry list.
// This also fires after the FINALE's win (it ends via the same end_game) —
// Restart Map / End Game after escaping is the right offer there too.
// Solo note: an open menu pauses the server and freezes the countdown — by
// design (a player IN the menu is deciding, not AFK); ESC closes it like any
// pause menu and ESC reopens it (the ingame menu stays enabled).
// NO dev dvars and no live-disable switch — ship behavior (map doctrine).
// =============================================================================
#using scripts\shared\util_shared;
#insert scripts\shared\shared.gsh;

#namespace tod_gameover;

#define TOD_GO_STOCK_PARK_SECS   120   // stock's intermission wait, stretched behind our window
#define TOD_GO_DECIDE_SECS       60    // no choice in this long -> auto End Game
#define TOD_GO_FAILSAFE_SECS     90    // independent watchdog (main <=63s, this 90s, stock ~120s)

function init()
{
	SetDvar( "tod_go_active", "" );   // stale-dvar scrub (see header)
	level thread offer_restart_on_end();
	level thread gameover_failsafe();
}

// Deliberately NO endon("end_game") — this RUNS at end_game.
function offer_restart_on_end()
{
	level waittill( "end_game" );

	// Claim the frame synchronously on the notify: stock reads this value well
	// after it, so the 15s auto-exit is parked before it can ever be scheduled.
	level.zombie_vars[ "zombie_intermission_time" ] = TOD_GO_STOCK_PARK_SECS;

	wait 3;
	if ( GetPlayers().size == 0 )
		return;

	// Release the scoreboard stock forced up right before intermission.
	LUINotifyEvent( &"force_scoreboard", 1, 0 );

	// THE MENU: flip AetheriumStartMenu into its two-entry mode, re-enable the
	// ingame menu, force it open on everyone.
	SetDvar( "tod_go_active", "1" );
	SetMatchFlag( "disableIngameMenu", 0 );
	wait 0.1;   // let the dvar land before the menu's createMenu reads it
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
			players[ i ] OpenMenu( "StartMenu_Main" );
	}

	// Both choices act from the menu (map_restart / disconnect tear the VM
	// down mid-wait — the intended exits). This only completes with NO choice.
	wait TOD_GO_DECIDE_SECS;
	level.tod_go_done = true;   // stands the failsafe down
	ExitLevel( false );         // the stock terminal call
}

// LAST-RESORT EXIT WATCHDOG: fully independent of the main flow — if no
// decision landed by now (main thread errored/died), exit exactly like stock.
function gameover_failsafe()
{
	level waittill( "end_game" );
	wait TOD_GO_FAILSAFE_SECS;
	if ( IS_TRUE( level.tod_go_done ) )
		return;
	ExitLevel( false );
}
