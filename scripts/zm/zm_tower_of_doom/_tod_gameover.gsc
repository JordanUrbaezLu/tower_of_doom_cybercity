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
//   2. after the TOD_GO_STATS_SECS stats window (the intermission camera cut +
//      stock's GAME OVER / "survived N rounds" text over the forced scoreboard,
//      which AetheriumScoreboard shows since 2026-09-24; a 3s settle before
//      that), release the scoreboard stock
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
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_utility;
#using scripts\zm\zm_tower_of_doom\_tod_gauge;   // floor_reached (the loss screen's floor line)
#insert scripts\shared\shared.gsh;

#precache( "eventstring", "tod_gameover" );   // v19.58 the end-screen lines, drawn by AetheriumScoreboard.lua
#precache( "eventstring", "tod_party" );      // v19.63 party facts for the pause / game-over menu (party_push)

#namespace tod_gameover;

#define TOD_GO_STOCK_PARK_SECS   120   // stock's intermission wait, stretched behind our window
#define TOD_GO_DECIDE_SECS       60    // no choice in this long -> auto End Game
#define TOD_GO_FAILSAFE_SECS     90    // independent watchdog (main <=71s, this 90s, stock ~120s)
// THE STATS WINDOW (2026-09-24, lead tester: "Something to add in the UI at
// endgame when you win, We cant see how many kills we got or end game stats
// kills, downs, points head shots"). Stock forces the scoreboard up at end_game
// (_zm.gsc :6204); AetheriumScoreboard.lua now answers that force, so the board
// with points / kills / headshots / downs / revives is what everyone sees for
// this long before the restart menu opens. Was a flat 3 s settle (v9.24).
#define TOD_GO_STATS_SECS        10

// =============================================================================
// v19.63 RESTART AND END GAME ARE SERVER CALLS NOW (Workshop: Tixy 2026-09-07
// "Fix restart level button please, it kicks the other player out in coop!";
// Biffbrooks11 2026-09-29 "When my buddy and I die, the restart button doesn't
// work leaving hitting 'End Game' as our only option. This disconnects us from
// each other.").
//
// Both menu lanes used to run a CONSOLE COMMAND ON THE PRESSING MACHINE
// (Engine.Exec map_restart / disconnect). On a listen host that reloads or
// drops the host alone: the connected peer lands on the main menu, the party is
// gone. v19.16 answered by HIDING Restart in co-op, which is the second report
// word for word ("the restart button doesn't work").
//
// Stock has the server-side call for exactly this: `map_restart( true )` is how
// every round-based MP mode restarts the level WITH EVERY CLIENT STILL
// CONNECTED (mp/zm gametypes/_globallogic.gsc round switch), and stock ZM's own
// wipe-restart dev lane (_zm.gsc :6197/:6245) is the same call. It persists the
// game[] array, so stock writes game["state"] = "playing" first - mirrored here
// (end_game had set it to "postgame"). And ExitLevel( false ) is stock's own
// terminal call: the whole party returns to the lobby TOGETHER, which is what
// "End Game" should mean for a host - not a disconnect that strands the peer.
//
// THE LANE: the menu sends "tod_go|restart" / "tod_go|end" on the StartMenu_Main
// menu-response channel (proven: the scoreboard's tod_sb and the v19.60 key
// diagnostic both arrive on it, from the pause menu, in the user's logs). Only
// the HOST's request acts - restarting is the host's call, so the Lua shows the
// button to the host alone (party_push tells each client whether it is one).
// A peer's End Game stays a local leave (its own disconnect), as Leave Game is.
//
// party_push( go ) is the one publisher of the party facts the Lua needs for
// that decision: humans in the party, "you are the host", and "the game-over
// menu is up" - the SetDvar channel this file used before is host-machine
// only, so a peer could never read it. Sent on every party change and as a 5 s
// heartbeat by _tod_main::party_dvar_watch (a late HUD gets it inside 5 s),
// and once more with go=1 right before the game-over menu opens.
// Log: [TOD_GAMEOVER] MENU / RESTART / END / PARTY, printed in developer runs
// (the user's launcher) regardless of tod_dev - it is a handful of lines per
// match and the restart itself is the evidence.
// =============================================================================
#define TOD_GO_MENU  "StartMenu_Main"   // LOCKSTEP: AetheriumStartMenu.lua SendMenuResponse menu name
#define TOD_GO_KEY   "tod_go"           // LOCKSTEP: the response prefix

// THE END-SCREEN LINES IN THE MAP'S TYPEFACE (v19.58, user 2026-09-27: "replace
// all the text on the screen ... add the typography for the map"). The stock
// "You Survived N Rounds" line and our "GAME OVER - FLOOR N" line are server
// hudelem TEXT, which the engine always draws in its own font. Both are now
// drawn by the forced end scoreboard (AetheriumScoreboard.lua, "tod_gameover":
// kind, rounds, floor) and the hudelems carry no words:
//   kind 1 = loss (GAME OVER - FLOOR N + YOU SURVIVED N ROUNDS)
//   kind 2 = a won ending (the banner ART says it; YOU SURVIVED N ROUNDS under it)
// Stock sets the survived text and fades it in right AFTER the custom callback,
// in the same frame, so the stock line is faded back out one frame later.
// Called from each custom_game_over_hud_elem (lost / escaped / spire).
function end_screen_push( survived, kind, floor )   // self = player
{
	if ( !isdefined( floor ) )
		floor = 0;
	rounds = 1;
	if ( isdefined( level.round_number ) && level.round_number > 1 )
		rounds = level.round_number;
	self LuiNotifyEvent( &"tod_gameover", 3, kind, rounds, floor );
	self thread hide_stock_line( survived );
}

function hide_stock_line( survived )
{
	wait 0.05;
	if ( !isdefined( survived ) )
		return;
	survived FadeOverTime( 0.05 );
	survived.alpha = 0;
}

function init()
{
	SetDvar( "tod_go_active", "" );   // stale-dvar scrub (see header)
	SetDvar( "tod_go_won", "" );      // same scrub for the win title (2026-09-24)
	// v16.3 — the LOSS screen carries the floor (see lost_game_over). Installed
	// at init; the two WIN paths overwrite it at their own moment
	// (_tod_finale escaped_game_over, _tod_spire spire_game_over).
	level.custom_game_over_hud_elem = &lost_game_over;
	callback::on_connect( &on_player_connect );
	level thread offer_restart_on_end();
	level thread gameover_failsafe();
	level thread restart_back_log();
	level thread leftover_bot_sweep();
	level thread go_request_watch();
}

// [2026-10-01] THE HOST'S REQUEST, READ FROM THE HOST MACHINE'S OWN DVAR. The
// user's co-op test (stand-in teammate, 13:10 build): the game-over Restart Map
// "does nothing" - the menu sent its tod_go|restart response and go_menu_watch
// never logged it. Stock's end_game marks the match ended (setmatchflag
// "game_ended" 1, level.intermission), and from then on a menu response does not
// reach script; mid-game pause-menu responses do (the same log). So the menu ALSO
// writes dvar tod_go_request: on the host's machine the menu and the server share
// one dvar table (proven both ways - tod_go_active server -> menu since v9.24,
// tod_go_restart_mark menu -> server in that same 13:10 log), and a teammate's
// machine runs no server, so only the host can ever reach this. The menu
// response stays as a second lane; host_restart / host_end run once (latch).
// No end_game endon: game over is exactly when this matters.
function go_request_watch()
{
	SetDvar( "tod_go_request", "" );   // never act on a request left from a previous level
	for ( ;; )
	{
		wait 0.1;
		want = GetDvarString( "tod_go_request" );
		if ( !isdefined( want ) || want == "" )
			continue;
		SetDvar( "tod_go_request", "" );
		go_log( "REQUEST via=host_dvar want=" + want + " players=" + GetPlayers().size
			+ " remote=" + party_remote_humans() + " gameover=" + IS_TRUE( level.tod_go_menu_open ) );
		if ( want == "restart" )
			level thread host_restart();
		else if ( want == "end" )
			level thread host_end();
	}
}

// [2026-10-01] DID THE RESTART COME BACK UP? Both restart lanes leave a mark in
// a dvar before restarting (a dvar outlives the level): "kit" = the console
// restart (solo / split-screen, set by AetheriumStartMenu's TodKitRestart),
// "server" = the host's server restart (online co-op, host_restart below). The
// new level logs RESTART_BACK, then RESTART_UP the moment stock's start-up lets
// the game begin (_zm::onAllPlayersReady sets all_players_connected; it waits,
// with no timeout, until the PLAYING players equal the lobby's expected count).
// RESTART_BACK with no RESTART_UP is a restart that froze, and the RESTART_WAIT
// counts say what held it. Printed in developer runs (the user's launcher).
function restart_back_log()
{
	mark = GetDvarString( "tod_go_restart_mark" );
	if ( !isdefined( mark ) || mark == "" )
		return;
	SetDvar( "tod_go_restart_mark", "" );
	t0 = GetTime();
	go_log( "RESTART_BACK lane=" + mark + " " + restart_counts() );
	while ( !level flag::exists( "all_players_connected" ) )
		wait 0.05;
	for ( i = 0; i < 120; i++ )   // 60 s
	{
		if ( level flag::get( "all_players_connected" ) )
		{
			go_log( "RESTART_UP lane=" + mark + " after_ms=" + ( GetTime() - t0 ) + " " + restart_counts() );
			return;
		}
		if ( i > 0 && i % 10 == 0 )
			go_log( "RESTART_WAIT lane=" + mark + " after_ms=" + ( GetTime() - t0 ) + " " + restart_counts() );
		wait 0.5;
	}
	go_log( "RESTART_STUCK lane=" + mark + " after_ms=" + ( GetTime() - t0 ) + " " + restart_counts() );
}

function restart_counts()
{
	bots = 0;
	playing = 0;
	players = GetPlayers();
	foreach ( p in players )
	{
		if ( p IsTestClient() )
			bots++;
		if ( p.sessionstate == "playing" )
			playing++;
	}
	return "players=" + players.size + " bots=" + bots + " playing=" + playing
		+ " expected=" + GetNumExpectedPlayers() + " connected=" + GetNumConnectedPlayers();
}

// DEV ONLY: a test client still connected from BEFORE a restart (a restart keeps
// connected clients - that is how a co-op teammate survives one). The dev Mage
// preview bot is not in the lobby, so stock's start-up count could wait on it for
// ever; drop it in the new level's first 30 s. The dev preview adds a fresh one
// on its own schedule, and marks it (tod_dev_mage_dummy) in the same frame as
// AddTestClient, so a fresh bot is never mistaken for a leftover.
function leftover_bot_sweep()
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	for ( i = 0; i < 120; i++ )
	{
		foreach ( p in GetPlayers() )
		{
			if ( isdefined( p ) && ( p IsTestClient() ) && !IS_TRUE( p.tod_dev_mage_dummy ) && !IS_TRUE( p.tod_go_dropping ) )
			{
				p.tod_go_dropping = true;
				go_log( "RESTART_BOT_DROP ent=" + p GetEntityNumber() + " " + restart_counts() );
				level thread hold_end_game_check_for_drop( p );
				p BotDropClient();
			}
		}
		wait 0.25;
	}
}

// Dropping a client runs stock's disconnect check (_zm_gametype::onPlayerDisconnect
// -> zm::checkForAllDead), which ENDS THE GAME when nobody is up - and in the new
// level's first frames the host has not spawned yet. User 2026-10-01: "it makes me
// restart the map twice in coop" - the log: RESTART_UP after 500 ms, then the
// game-over menu again 10 s later (the restarted game ended itself at the drop);
// the second restart was clean. Hold stock's own end-game guard (the counter
// zm_utility::increment/decrement_no_end_game_check) until a human is actually up;
// stock's decrement re-runs the check itself, so nothing is skipped. Dev only:
// a shipping game has no test client to drop.
function hold_end_game_check_for_drop( bot )
{
	zm_utility::increment_no_end_game_check();
	t0 = GetTime();
	while ( GetTime() - t0 < 30000 )
	{
		if ( !isdefined( bot ) && restart_human_up() )
			break;
		wait 0.25;
	}
	zm_utility::decrement_no_end_game_check();
	go_log( "RESTART_BOT_DROP_DONE held_ms=" + ( GetTime() - t0 ) + " " + restart_counts() );
}

function restart_human_up()
{
	foreach ( p in GetPlayers() )
	{
		if ( isdefined( p ) && !( p IsTestClient() ) && p.sessionstate == "playing"
			&& !( p laststand::player_is_in_laststand() ) )
			return true;
	}
	return false;
}

function on_player_connect()
{
	self thread go_menu_watch();
}

// PUBLIC - push the party facts to every human's HUD (see the v19.63 block).
// go = 1 means the game-over menu is opening. Test clients (the dev Mage
// preview) are not humans and own no menu seat.
//
// [2026-10-01, docs/167 item 9 follow-up] THE HOST VALUE SAYS WHICH RESTART TO
// USE: 0 = not at the host's machine (no Restart); 1 = at the host's machine
// with a teammate on ANOTHER machine (online co-op: the server restart below,
// the only lane that keeps that teammate); 2 = at the host's machine and EVERY
// human is on it (solo / split-screen: the Aetherium kit's own console restart,
// which worked for months - user: "the stock aetherium HUD had this perfectly
// set up"). Packed into the existing arg so the event stays 3 ints.
// LOCKSTEP: AetheriumHud.lua (host >= 1, local = 2), test_coop_restart_lane.js.
function party_push( go )
{
	n = party_humans();
	remote = party_remote_humans();
	players = GetPlayers();
	foreach ( p in players )
	{
		if ( !isdefined( p ) || !isplayer( p ) || ( p IsTestClient() ) )
			continue;
		host = 0;
		if ( p go_is_host() )
			host = ( ( remote > 0 ) ? 1 : 2 );
		p LuiNotifyEvent( &"tod_party", 3, n, host, go );
	}
	return n;
}

// Humans in the game (test clients are not - except the dev co-op stand-in).
function party_humans()
{
	n = 0;
	foreach ( p in GetPlayers() )
	{
		if ( !( p IsTestClient() ) || coop_mock_teammate( p ) )
			n++;
	}
	return n;
}

// Humans NOT sitting at the host's machine (online co-op teammates). A
// split-screen guest is IsLocalToHost(), so solo and split-screen read 0.
function party_remote_humans()
{
	n = 0;
	foreach ( p in GetPlayers() )
	{
		if ( coop_mock_teammate( p ) || ( !( p IsTestClient() ) && !( p IsLocalToHost() ) ) )
			n++;
	}
	return n;
}

// DEV ONLY (level.tod_dev + level.tod_dev_coop_mock, zm_tower_of_doom.gsc): the
// dev Mage preview bot stands in for a teammate on ANOTHER PC, so one person can
// drive the online co-op restart lane. Never true in a shipping build (both
// flags false; -Publish refuses them armed).
function coop_mock_teammate( p )
{
	return IS_TRUE( level.tod_dev ) && IS_TRUE( level.tod_dev_coop_mock )
		&& isdefined( p ) && ( p IsTestClient() ) && IS_TRUE( p.tod_dev_mage_dummy );
}

// self = player. One plain waittill loop for the whole connection (the
// scoreboard_watch shape). Acts only on the host's request.
function go_menu_watch()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "menuresponse", menu, response );
		if ( !isdefined( menu ) || !isdefined( response ) || menu != TOD_GO_MENU )
			continue;
		parts = StrTok( response, "|" );
		if ( parts.size < 2 || parts[ 0 ] != TOD_GO_KEY )
			continue;
		host = self go_is_host();
		go_log( "MENU ent=" + self GetEntityNumber() + " host=" + host + " lobby_host=" + self IsHost()
			+ " local_to_host=" + self IsLocalToHost() + " want=" + parts[ 1 ]
			+ " players=" + GetPlayers().size + " remote=" + party_remote_humans()
			+ " gameover=" + IS_TRUE( level.tod_go_menu_open ) );
		if ( !host )
			continue;
		if ( parts[ 1 ] == "restart" )
			level thread host_restart();
		else if ( parts[ 1 ] == "end" )
			level thread host_end();
	}
}

// self = player. WHO MAY RESTART OR END FOR THE PARTY (2026-10-01, docs/167 item
// 10: "Restart is still completely missing from the split-screen UI"). The host,
// AND every player sitting at the host's machine: a split-screen guest is
// IsLocalToHost() but not IsHost(), and stock's own pause menu offers Restart to
// anyone on the lobby-host machine (datasources.lua IsLobbyHost, per machine).
// An online peer on another machine stays out - it is neither.
function go_is_host()
{
	return ( self IsHost() || self IsLocalToHost() );
}

// Stock's round-switch recipe: game["state"] back to "playing", then the
// server-side restart that keeps every client connected. Once only.
function host_restart()
{
	if ( IS_TRUE( level.tod_go_leaving ) )
		return;
	level.tod_go_leaving = true;
	level.tod_go_done = true;
	go_log( "RESTART map_restart players=" + GetPlayers().size + " " + restart_counts() );
	SetDvar( "tod_go_restart_mark", "server" );   // restart_back_log reads it in the new level
	LUINotifyEvent( &"force_scoreboard", 1, 0 );
	game[ "state" ] = "playing";
	map_restart( true );
	wait 666;   // never returns past the restart
}

// Stock's terminal call: the party returns to the lobby together.
function host_end()
{
	if ( IS_TRUE( level.tod_go_leaving ) )
		return;
	level.tod_go_leaving = true;
	level.tod_go_done = true;
	go_log( "END ExitLevel players=" + GetPlayers().size );
	ExitLevel( false );
	wait 666;
}

// Assembled outside the developer block, printed inside it (the proven
// pattern). Not gated on tod_dev - see the v19.63 block for why.
function go_log( msg )
{
	line = "[TOD_GAMEOVER] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

// Stock _zm::end_game calls this per player INSTEAD of its own game_over /
// survived setup when it is defined ( player, game_over_elem, survived_elem ),
// then sets the survived text + fade itself (the same contract
// _tod_finale::escaped_game_over rides). This is the LOSS screen: stock's exact
// geometry, with the floor the party reached on the GAME OVER line — the map's
// headline number was absent at the one moment players screenshot (repo review
// 2026-09-01). Highest floor across the party, since the run is shared;
// floor_reached is each player's alive-only high-water. A plain-string SetText
// mints one config string per distinct text, which is fine ONCE at end_game.
function lost_game_over( player, game_over, survived )
{
	best = 0;
	foreach ( p in GetPlayers() )
	{
		f = tod_gauge::floor_reached( p );
		if ( f > best )
			best = f;
	}

	game_over.alignX = "center";
	game_over.alignY = "middle";
	game_over.horzAlign = "center";
	game_over.vertAlign = "middle";
	game_over.y -= 130;
	game_over.foreground = true;
	game_over.fontScale = 3;
	game_over.alpha = 0;
	game_over.color = ( 1.0, 1.0, 1.0 );
	game_over.hidewheninmenu = true;
	// v19.58: the words are drawn by the end scoreboard in the map's typeface
	// (end_screen_push below); this elem stays empty and invisible.
	player end_screen_push( survived, 1, best );
	if ( player IsSplitScreen() )
	{
		game_over.fontScale = 2;
		game_over.y += 40;
	}

	survived.alignX = "center";
	survived.alignY = "middle";
	survived.horzAlign = "center";
	survived.vertAlign = "middle";
	survived.y -= 100;
	survived.foreground = true;
	survived.fontScale = 2;
	survived.alpha = 0;
	survived.color = ( 1.0, 1.0, 1.0 );
	survived.hidewheninmenu = true;
	if ( player IsSplitScreen() )
	{
		survived.fontScale = 1.5;
		survived.y += 40;
	}
}

// Deliberately NO endon("end_game") — this RUNS at end_game.
function offer_restart_on_end()
{
	level waittill( "end_game" );

	// Claim the frame synchronously on the notify: stock reads this value well
	// after it, so the 15s auto-exit is parked before it can ever be scheduled.
	level.zombie_vars[ "zombie_intermission_time" ] = TOD_GO_STOCK_PARK_SECS;

	// Read the result NOW, on the notify frame: both win paths set their latch
	// before end_game (_tod_finale escape, _tod_spire summit_win).
	won = ( IS_TRUE( level.tod_escaped ) || IS_TRUE( level.tod_spire_won ) );

	wait TOD_GO_STATS_SECS;   // the forced scoreboard: everyone's end-of-game stats
	if ( GetPlayers().size == 0 )
		return;

	// Release the scoreboard stock forced up right before intermission.
	LUINotifyEvent( &"force_scoreboard", 1, 0 );

	// THE MENU: flip AetheriumStartMenu into its two-entry mode, re-enable the
	// ingame menu, force it open on everyone. tod_go_won titles it "Victory"
	// instead of "Game Over" after an escape or a conquered spire (2026-09-24).
	SetDvar( "tod_go_won", ( ( won ) ? "1" : "" ) );
	SetDvar( "tod_go_active", "1" );
	level.tod_go_menu_open = true;
	n = party_push( 1 );   // v19.63: every client, host or peer, learns the menu is up
	go_log( "PARTY go=1 humans=" + n + " won=" + won );
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
	if ( IS_TRUE( level.tod_go_leaving ) )
		return;                 // a host restart / end already claimed the exit
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
