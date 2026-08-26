// =============================================================================
// _tod_luck.gsc — THE LUCK BAR (user 2026-08-20): per-player 0..100%, shown
// bottom-left, SPENT on upgrade rolls (higher bar = better rarity odds),
// FULL RESET to 0 after each upgrade event (user decision).
//
// SOURCES (LAST HIT TAKES ALL — user: "Last hit will get all points for
// luck. Whether thats a zombie protector or panzer"):
//   zombie kill      +normalized (see below); headshot kills x1.5
//   Rogue Protector  +4  (the killer)
//   Panzer           +20 (the killer)
//   revive           +15 (the reviver)
//   door purchase    +8  (the buyer — _tod_doors calls in)
//   going down       -25
//
// THE BALANCE CORE (solo/duo/trio/quad fairness as rounds scale): raw
// per-kill luck would explode with round size and starve co-op players
// (zombies split p ways). Instead each round computes
//     luck_per_kill = KILL_BUDGET * players / round_zombie_total
// so a player killing their FAIR SHARE of any round earns ~KILL_BUDGET
// regardless of round number or lobby size: solo clears the whole round =
// +40; in a quad the round is ~bigger but split 4 ways — each fair share
// still = +40. Round size comes from the stock spawn-budget formula
// (zm::get_zombie_count_for_round, _zm.gsc:3842 - the same number the endless
// flow spends). More zombies per round -> less luck per kill, automatically.
//
// The permanent LUCK upgrade domain = +10% GAIN RATE per level (user pick):
// every gain is multiplied by (1 + 0.10 * luck_level). Losses are not.
//
// HUD: all-LUI (v6 — the server hudelem bar never sat cleanly in the frame
// art's window). Every bar change pushes tod_upgrade_ui::set_luck_pct, which
// drives the EXISTING todUpgLuck clientfield (bar/10, 0..10) — zero new
// clientuimodel bits (pool is at its 61-bit ceiling); tod_upgrade.lua's
// LuckSegs render 10 segments inside the i_tod_luck_frame window.
//
// Public API:
//   add( player, amount )      — luck gain (gain-rate mult applies)
//   drain( player, amount )    — luck loss (no mult)
//   get( player )              — current 0..100
//   spend( player )            — zero the bar + refresh HUD (post-upgrade)
//   on_zombie_kill( attacker, b_headshot ) — the normalized kill award
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm;           // get_zombie_count_for_round (the spawn budget)
#using scripts\zm\_zm_spawner;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_tower_of_doom\_tod_upgrades;
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;   // set_luck_pct (no cycle: upgrade_ui imports only shared)

#define TOD_LUCK_MAX           100
#define TOD_LUCK_KILL_BUDGET   18     // fair-share round clear ~= this much luck (was 40 — user 2026-08-20: "way too easy, basically maxed every time")
#define TOD_LUCK_HEADSHOT_MULT 1.5
#define TOD_LUCK_PROTECTOR     4      // the killer (last hit)
#define TOD_LUCK_PANZER        20     // the killer (last hit)
#define TOD_LUCK_REAVER        6      // the killer (last hit) — elite, between a wave unit and the Panzer
#define TOD_LUCK_HELLHOUND     3      // the killer (last hit) — pack elite; below a Reaver because they arrive 3-5 at a time
#define TOD_LUCK_REVIVE        15
#define TOD_LUCK_DOOR          8.75   // x1.75 (user 2026-08-21: "opening a door gives luck, 1.75x it"); was 5 (2026-08-20 nerf from 8). BUYER ONLY — _tod_doors passes the purchasing player.
#define TOD_LUCK_DOWN          25     // lost on going down
#define TOD_LUCK_GAIN_PER_LVL  0.10   // the LUCK domain: +10% gain rate / Lv

#namespace tod_luck;

function init()
{
	level thread per_round_rate();
	callback::on_spawned( &on_player_spawned );
	zm_spawner::register_zombie_death_event_callback( &on_zombie_death );
}

// ---------------------------------------------------------------------------
// The per-round kill rate — recomputed at every round boundary.
// ---------------------------------------------------------------------------

function per_round_rate()
{
	level endon( "end_game" );

	level.tod_luck_per_kill = 1.0;
	last = 0;
	for ( ;; )
	{
		r = level.round_number;
		if ( isdefined( r ) && r != last )
		{
			last = r;
			p = GetPlayers().size;
			if ( p < 1 )
				p = 1;
			total = zm::get_zombie_count_for_round( r, p );
			if ( !isdefined( total ) || total < 1 )
				total = 24;
			level.tod_luck_per_kill = TOD_LUCK_KILL_BUDGET * p / total;
		}
		wait 1;
	}
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

function add( player, amount )
{
	if ( !isdefined( player ) || !isplayer( player ) || !isdefined( amount ) )
		return;
	// LUCK domain: gain-rate boost (user pick — gains only, never losses)
	lvl = tod_upgrades::get_level( player, "luck" );
	if ( lvl > 0 )
		amount = amount * ( 1.0 + lvl * TOD_LUCK_GAIN_PER_LVL );

	set_bar( player, bar_of( player ) + amount );
}

function drain( player, amount )
{
	if ( !isdefined( player ) || !isplayer( player ) || !isdefined( amount ) )
		return;
	set_bar( player, bar_of( player ) - amount );
}

function get( player )
{
	return int( bar_of( player ) );
}

// The upgrade event consumed the bar (user: full reset to 0).
function spend( player )
{
	set_bar( player, 0 );
}

// The normalized zombie-kill award (last hit takes all).
function on_zombie_kill( attacker, b_headshot )
{
	amt = level.tod_luck_per_kill;
	if ( !isdefined( amt ) )
		amt = 1.0;
	if ( IS_TRUE( b_headshot ) )
		amt = amt * TOD_LUCK_HEADSHOT_MULT;
	add( attacker, amt );
}

// Boss LAST HIT takes the full luck award (user 2026-08-20). kind =
// "panzer" | "protector". Called from _tod_bosses' death paths.
function boss_kill( killer, kind )
{
	if ( !isdefined( killer ) || !isplayer( killer ) )
		return;
	if ( isdefined( kind ) && kind == "panzer" )
	{
		add( killer, TOD_LUCK_PANZER );
		// (on-screen text removed 2026-08-20 — user: no floaty text)
	}
	else if ( isdefined( kind ) && kind == "reaver" )
	{
		add( killer, TOD_LUCK_REAVER );
	}
	else if ( isdefined( kind ) && kind == "hellhound" )
	{
		// EXPLICIT BRANCH REQUIRED, not optional. The final else below is a
		// CATCH-ALL paying TOD_LUCK_PROTECTOR, so passing an unmatched kind
		// compiles clean and silently pays the wrong number — a quiet balance
		// bug rather than a fatal. Hounds die in packs, so their per-kill luck
		// sits below a Reaver's.
		add( killer, TOD_LUCK_HELLHOUND );
	}
	else
	{
		add( killer, TOD_LUCK_PROTECTOR );   // wave units stay quiet (no spam)
	}
}

// Door purchase (called from _tod_doors on a successful buy).
function door_buy( player )
{
	add( player, TOD_LUCK_DOOR );
	// (door text removed 2026-08-20 — user: no floaty text)
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

function bar_of( player )
{
	if ( !isdefined( player.tod_luck_bar ) )
		player.tod_luck_bar = 0;
	return player.tod_luck_bar;
}

function set_bar( player, v )
{
	if ( v > TOD_LUCK_MAX )
		v = TOD_LUCK_MAX;
	if ( v < 0 )
		v = 0;
	player.tod_luck_bar = v;
	player thread refresh_hud();
}

// self = the dying zombie (zm_spawner death event contract); attacker = killer.
// Bosses never reach this (they are not zombie-archetype) — their luck pays
// from _tod_bosses' death paths.
function on_zombie_death( attacker )
{
	if ( !isdefined( attacker ) || !isplayer( attacker ) )
		return;
	// self.damagelocation is THE engine-set field (stock _zm_spawner reads it
	// everywhere; "damageloc" does not exist — verify pass 2026-08-20).
	// neck counts deliberately (stock is_headshot is head/helmet only).
	b_head = ( isdefined( self.damagelocation ) &&
	           ( self.damagelocation == "head" || self.damagelocation == "helmet" || self.damagelocation == "neck" ) );
	on_zombie_kill( attacker, b_head );
}

// ---------------------------------------------------------------------------
// Per-player watchers: HUD + revives + downs
// ---------------------------------------------------------------------------

function on_player_spawned()   // self = player (callback::on_spawned)
{
	self endon( "disconnect" );

	if ( !IS_TRUE( self.tod_luck_watchers_on ) )
	{
		self.tod_luck_watchers_on = true;
		self thread ensure_hud();
		self thread revive_watcher();
		self thread down_watcher();
	}
	self thread refresh_hud();
}

// Reviver credit: the stock revive notifies "player_revived" ON the revived
// player with the reviver as the arg (map 1's savior hook rides the same).
function revive_watcher()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( "player_revived", reviver );
		if ( isdefined( reviver ) && isplayer( reviver ) && reviver != self )
		{
			add( reviver, TOD_LUCK_REVIVE );
			// (on-screen text removed 2026-08-20 — user: no floaty text)
		}
	}
}

// Down penalty + HUD SYNC: edge-detect the laststand transition, and
// self-heal the HUD against ANY direct bar writer (the upgrade event zeroes
// player.tod_luck_bar directly — the no-cycle direction; this poll catches
// it within 0.5s — verify pass 2026-08-20).
function down_watcher()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	was_down = false;
	shown = -1;
	for ( ;; )
	{
		wait 0.5;
		now = ( self laststand::player_is_in_laststand() );
		if ( now && !was_down )
		{
			drain( self, TOD_LUCK_DOWN );
			// (on-screen text removed 2026-08-20 — user: no floaty text)
		}
		was_down = now;

		v = int( bar_of( self ) );
		if ( v != shown )
		{
			shown = v;
			self thread refresh_hud();
		}
	}
}

// ---------------------------------------------------------------------------
// The bar (all-LUI): push bar/10 into the todUpgLuck clientfield; the Lua's
// LuckSegs (tod_upgrade.lua) light 1 segment per 10%. Gold-at-hot + the "%"
// readout live client-side too.
// ---------------------------------------------------------------------------

function ensure_hud()
{
	self endon( "disconnect" );
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	self thread refresh_hud();
}

function refresh_hud()   // self = player
{
	self tod_upgrade_ui::set_luck_pct( bar_of( self ) );
}
