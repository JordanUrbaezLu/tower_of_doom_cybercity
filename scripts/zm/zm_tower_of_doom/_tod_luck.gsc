// =============================================================================
// _tod_luck.gsc — THE LUCK BAR (user 2026-08-20): per-player 0..100%, shown
// bottom-left, SPENT on upgrade rolls (higher bar = better rarity odds),
// FULL RESET to 0 after each upgrade event (user decision).
//
// OVERCHARGE — THE SECRET BAND (v14.9, user 2026-08-30): the bar SECRETLY
// keeps tracking past 100, up to TOD_LUCK_OVERMAX (150). The HUD shows the
// same full bar the whole way (no pips fire in the band — the band is a
// secret), and the odds keep improving underneath (roll_rarity reads the raw
// bar). AT 150 the secret announces itself: the full-bar art starts an
// electric-zap ANIMATION (overcharge_driver cycles todUpgLuck 11..14 — four
// baked frames, server-driven at the proven ~7 Hz blink cadence, randomized
// order) and a semi-deep electric zap fires every ~3s (v14.9b spacing —
// PlayLocalSound every TOD_LUCK_OVER_ZAP_TICKS frames, deliberately NOT a
// looping alias: a retriggered one-shot cannot get stuck when a stop path is
// missed, which is this map's whole looping-sound scar tissue). At 150 the upgrade deal
// guarantees BOTH cards ULTIMATE (_tod_upgrades TOD_UPG_GUAR_BOTH_BAR —
// LOCKSTEP with TOD_LUCK_OVERMAX). The state ends the moment the bar drops
// below 150 (down -25, or the post-event reset) — the driver polls and
// self-terminates, restoring the real HUD value.
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
// clientuimodel bits (pool is at its 61-bit ceiling); tod_upgrade.lua swaps
// between 11 baked bar images (i_tod_luck_00..10, one per level).
//
// Public API:
//   add( player, amount )      — luck gain (gain-rate mult applies)
//   drain( player, amount )    — luck loss (no mult)
//   get( player )              — current 0..150 (>100 = the secret band)
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
// v14.9 OVERCHARGE CEILING (user 2026-08-30): the bar secretly tracks past 100
// up to here. Everything VISIBLE still keys off TOD_LUCK_MAX (the HUD's 10
// segments, the pips); this is the true clamp in set_bar, the odds keep riding
// the raw value in roll_rarity, and AT this value the overcharge state fires
// (animation + zap SFX + both-ULTIMATE deal). LOCKSTEP PAIR with
// TOD_UPG_GUAR_BOTH_BAR in _tod_upgrades.gsc and with
// TOD_UPG_LUCK_OVERMAX_PCT in _tod_upgrade_ui.gsc — all three must move
// together (defines are per-file; the modules cannot share one).
#define TOD_LUCK_OVERMAX       150
#define TOD_LUCK_KILL_BUDGET   18     // fair-share round clear ~= this much luck (was 40 — user 2026-08-20: "way too easy, basically maxed every time")
#define TOD_LUCK_HEADSHOT_MULT 1.5
#define TOD_LUCK_PROTECTOR     4      // the killer (last hit)
#define TOD_LUCK_PANZER        20     // the killer (last hit)
#define TOD_LUCK_REAVER        6      // the killer (last hit) — elite, between a wave unit and the Panzer
#define TOD_LUCK_HELLHOUND     3      // the killer (last hit) — pack elite; below a Reaver because they arrive 3-5 at a time
#define TOD_LUCK_SPRINTER      4      // the killer (last hit) — same as a wave unit (was the catch-all's value by accident since v13.7; explicit since v14.8)
#define TOD_LUCK_REVIVE        15
// DOOR BUY = A FLAT 10% OF THE BAR (user 2026-08-27: "lets make buying a door
// 10% luck increase"). History: 8 -> 5 (2026-08-20 nerf) -> 8.75 (2026-08-21,
// "opening a door gives luck, 1.75x it") -> 10 now, which is also the first time
// this number is a round share of the bar rather than the product of two
// tunings: ten doors is exactly a full bar, and one door lights exactly one of
// the HUD's ten segments. BUYER ONLY — _tod_doors passes the purchasing player,
// so it does not pay the whole party.
//
// The LUCK domain still multiplies it (+10% gain rate/Lv), so a maxed LUCK
// player banks 15 per door and reaches the ULTIMATE guarantee in seven.
#define TOD_LUCK_DOOR          10
// DUPLICATE-DROP CONSOLATION (user 2026-08-30: "if a player already has a
// pap gun but gets a pap drop they will get 20% luck. And if they get a perk
// bottle with max perks they will get 10% luck"). Paid by _tod_powerups via
// level.tod_luck_dupe_fn (set in init below — powerups cannot #using this
// module: powerups -> luck -> upgrades -> powerups is the cycle the KB
// forbids). Routed through add(), so the LUCK domain's gain rate multiplies
// these like every other source, and the segment pips fire.
#define TOD_LUCK_PAP_DUPE      20     // PaP drop, everything already packed
#define TOD_LUCK_PERK_DUPE     10     // perk bottle, every sellable perk owned
#define TOD_LUCK_DOWN          25     // lost on going down
#define TOD_LUCK_GAIN_PER_LVL  0.10   // the LUCK domain: +10% gain rate / Lv

// --- THE AUDIBLE LUCK LADDER (2026-08-29, docs/43 items 1-2) ----------------
// The bar drove everything in this map and made no sound from round 1 to the
// finale. Two cues, deliberately paired:
//   * tod_headshot_ding  — headshot KILL, the shooter only. Map 1's Apex ding
//     (acc\fx\headshot_ding.wav), the user's explicit pick.
//   * tod_luck_pip01..10 — one per HUD segment that lights, a major scale
//     climbing 16 semitones so "nearly full" is audible without looking.
// They compound on purpose: a headshot kill pays 1.5x luck, so the shot that
// dings is the shot most likely to light a segment a beat later.
#define TOD_LUCK_SEGS          10     // must match the HUD's segment count
#define TOD_LUCK_PIP_DELAY     0.12   // pip lands just AFTER the ding, never on top of it

// --- OVERCHARGE cadence (v14.9; SFX spacing retuned v14.9b) -----------------
// Frame swap at ~7 Hz — the SAME server-driven cadence as the card focus blink
// (TOD_UPG_BLINK_SECS 0.15 in _tod_upgrade_ui.gsc), because that is the one
// animation rate this UI has ever proven; the Lua doctrine forbids client
// UITimers.
// The zap SFX fires every N frame ticks. v14.9 shipped 7 (1.05s, a continuous
// crackle bed); the user played it and asked for "a semi deep zzz and plays
// every few seconds" — so v14.9b spaces it to 20 ticks = 3.0s and the wav is
// now a single discrete deep zap (~1.3s with a decay tail), not a bed. The
// wav must stay SHORTER than this interval or consecutive zaps overlap.
#define TOD_LUCK_OVER_FRAME_SECS 0.15
#define TOD_LUCK_OVER_ZAP_TICKS  20

#namespace tod_luck;

function init()
{
	level thread per_round_rate();
	callback::on_spawned( &on_player_spawned );
	zm_spawner::register_zombie_death_event_callback( &on_zombie_death );

	// The duplicate-drop consolation lane for _tod_powerups (see the
	// TOD_LUCK_*_DUPE defines — the pointer exists because a #using from
	// powerups would close an import cycle).
	level.tod_luck_dupe_fn = &dupe_award;
}

// PUBLIC via level.tod_luck_dupe_fn. kind: "pap" (drop grabbed with every
// packable gun already packed, +20) or "perk" (bottle grabbed with every
// sellable perk owned, +10). Values live HERE like every luck number.
function dupe_award( player, kind )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return;
	n = TOD_LUCK_PERK_DUPE;
	if ( isdefined( kind ) && kind == "pap" )
		n = TOD_LUCK_PAP_DUPE;
	add( player, n );
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
	else if ( isdefined( kind ) && kind == "sprinter" )
	{
		// v14.8 hardening: the sprinter shipped v13.7 with NO branch and rode
		// the catch-all — the exact trap the hellhound comment above warns
		// about. It paid TOD_LUCK_SPRINTER's value by luck, not by intent;
		// now it pays it by name, and a Protector retune can't drag it along.
		add( killer, TOD_LUCK_SPRINTER );
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
	// v14.9: the TRUE clamp is the overcharge ceiling; TOD_LUCK_MAX is only
	// the top of the VISIBLE bar now (HUD, pips). The 100..150 band is the
	// secret — nothing on screen or in the ear distinguishes 100 from 149.
	if ( v > TOD_LUCK_OVERMAX )
		v = TOD_LUCK_OVERMAX;
	if ( v < 0 )
		v = 0;
	// SEGMENT PIP. Read the old value BEFORE the write, and fire only on an
	// UPWARD segment crossing. Two things this deliberately does not do:
	// it never pips on the post-event reset to 0 (that is a downward crossing
	// of every segment at once), and it never pips on a partial gain inside a
	// segment — the ear only hears the bar when it actually gains a notch.
	old = bar_of( player );
	player.tod_luck_bar = v;
	seg_old = int( old * TOD_LUCK_SEGS / TOD_LUCK_MAX );
	seg_new = int( v * TOD_LUCK_SEGS / TOD_LUCK_MAX );
	// Clamp BOTH to the HUD's segment count so the secret band is silent: the
	// 10th pip still fires once on crossing 100, and 110/120/130/140/150 fire
	// nothing (both sides read as "segment 10").
	if ( seg_old > TOD_LUCK_SEGS )
		seg_old = TOD_LUCK_SEGS;
	if ( seg_new > TOD_LUCK_SEGS )
		seg_new = TOD_LUCK_SEGS;
	if ( seg_new > seg_old )
		player thread segment_pip( seg_new );
	// OVERCHARGE edge: only set_bar can ever RAISE the bar (the direct writers
	// in _tod_upgrades/_tod_spire only ever zero it), so the upward crossing
	// into 150 is fully owned here. The driver polls its own exit condition,
	// so the downward edge needs no code at all.
	if ( v >= TOD_LUCK_OVERMAX && old < TOD_LUCK_OVERMAX )
		player thread overcharge_driver();
	player thread refresh_hud();
}

// self = player. THE OVERCHARGE STATE (v14.9): runs exactly while the bar sits
// at TOD_LUCK_OVERMAX. Every tick it swaps the HUD bar to a random one of the
// four zap frames (todUpgLuck 11..14 — the 4-bit field's spare values, zero
// new clientuimodel bits; the never-repeat step matters because the LUI model
// only notifies subscribers on a CHANGE, so a repeated value would freeze the
// animation for a tick). Every TOD_LUCK_OVER_ZAP_TICKS ticks it fires the
// deep zap — PlayLocalSound like every luck cue (per-client, full volume,
// a teammate's overcharge never buzzes in your ears), and NEVER a looping
// alias: when this thread dies, silence follows within one wav tail, with no
// stop ritual to miss (the stuck-loop scar tissue in the memory notes).
// EXIT is by poll: the bar leaving 150 (down -25, event spend, spire reset —
// including the DIRECT writers that bypass set_bar) ends the state within one
// 0.15s tick, and the final refresh_hud restores the real bar image.
function overcharge_driver()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	if ( IS_TRUE( self.tod_luck_overcharged ) )
		return;   // one driver per player — set_bar can race the edge
	self.tod_luck_overcharged = true;

	last = 0;
	tick = 0;
	while ( bar_of( self ) >= TOD_LUCK_OVERMAX )
	{
		f = 11 + RandomInt( 4 );
		if ( f == last )
			f = 11 + ( ( f - 11 + 1 ) % 4 );   // step to the next frame instead of repeating
		last = f;
		self tod_upgrade_ui::set_luck_over_frame( f );

		if ( ( tick % TOD_LUCK_OVER_ZAP_TICKS ) == 0 )
			self PlayLocalSound( "tod_luck_overmax_zap" );
		tick++;

		wait TOD_LUCK_OVER_FRAME_SECS;
	}

	self.tod_luck_overcharged = false;
	self thread refresh_hud();
}

// self = player. One rung of the ladder. Threaded with a short delay so that on
// a headshot kill — which pays 1.5x and is the most likely thing to light a
// segment — the ding reads first and the pip answers it.
function segment_pip( seg )
{
	self endon( "disconnect" );
	level endon( "end_game" );
	if ( seg < 1 )
		seg = 1;
	if ( seg > TOD_LUCK_SEGS )
		seg = TOD_LUCK_SEGS;
	wait TOD_LUCK_PIP_DELAY;
	alias = "tod_luck_pip";
	if ( seg < 10 )
		alias = alias + "0";
	alias = alias + seg;
	self PlayLocalSound( alias );
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
	// HEADSHOT-KILL DING, shooter only (map 1's _acc_damage.gsc:1358 pattern —
	// PlayLocalSound is per-client, so full volume with no world falloff, and a
	// teammate's headshots never ring in your ears).
	//
	// KILL, not hit — the same call map 1 makes, and for the same reason: a ding
	// on every headshot HIT machine-guns against round-30 health pools.
	// on_zombie_death IS the death event, so it fires once per kill and needs no
	// bullet gate to stop AoE chains re-triggering it.
	//
	// Gated on b_head EXACTLY as the luck award is, deliberately: the ding then
	// means "that paid the 1.5x headshot bonus" and can never disagree with the
	// bar it is about to move.
	if ( b_head )
		attacker PlayLocalSound( "tod_headshot_ding" );
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
// The bar (all-LUI): push bar/10 into the todUpgLuck clientfield; the Lua
// (tod_upgrade.lua) swaps in the baked i_tod_luck_NN image for that level —
// gold-at-hot (8..9) and the MAX state are baked into the art.
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
