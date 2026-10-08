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
// order) and a semi-deep electric zap fires every ~3s, at most seven times
// per overcharge (v18.46 cap; v14.9b spacing —
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
//   Reaver / Hound / armored Sprinter +6 / +3 / +4 (the killer)
//   door purchase    +10 (the buyer — tower doors, including power/roof/bay)
//   duplicate PaP/perk drop +20 / +10 (the grabber)
//   going down       -15
// Ordinary zombie/headshot kills pay immediately without souls (2026-09-23).
// Other positive sources release a homing soul and pay only on arrival;
// values/multipliers are snapshotted at the source. Panzer remains killer-only
// (user reconfirmed 2026-09-22). See docs/155_luck_orbs.md for the full audit.
//
// THE BALANCE CORE (solo/duo/trio/quad fairness as rounds scale): raw
// per-kill luck would explode with round size and starve co-op players
// (zombies split p ways). Instead each round computes
//     luck_per_kill = KILL_BUDGET * players / round_zombie_total
// so a player killing their FAIR SHARE of any round earns ~KILL_BUDGET
// regardless of round number or lobby size: solo clears the whole round =
// +18; in a quad the round is ~bigger but split 4 ways — each fair share
// still = +18 before the late-round boost. Round size comes from the stock spawn-budget formula
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
//   add( player, amount, org, source ) — direct ordinary kill, otherwise orb
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
#using scripts\zm\zm_tower_of_doom\_tod_killconfirm;  // elite red crosshair marker; luck audio belongs to orbs
#using scripts\zm\zm_tower_of_doom\_tod_luck_orbs;

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
// [v17.1] THE LATE-ROUND KILL BOOST (user 2026-09-03: *"specifically on zombie
// kills we need a slight buff later rounds ... 4% extra after round 15"*, with
// a worked table: r16 104%, r17 108%, r18 112%).
//
// WHY THE NORMALIZATION ALONE WAS NOT ENOUGH. per_round_rate() divides the
// budget by the round's zombie count, which is EXACTLY right if you clear the
// round — a full clear always pays TOD_LUCK_KILL_BUDGET whatever the round
// number. Late game you cannot clear: stock's count grows with the SQUARE of
// the round past 10 (get_zombie_count_for_round, _zm.gsc:3853), the endless
// twist starts the next round on the last SPAWN rather than the last kill, so
// the horde outruns you and you take a shrinking SHARE of a per-kill value that
// is itself shrinking quadratically. Two other late-game losses compound it:
// door income (TOD_LUCK_DOOR, 10 a door) stops entirely once the tower is
// bought, and a DOWN used to cost 25 against a round's fair share of 18 — cut
// to 15 the same day (see the define) for exactly that reason.
//
// LINEAR, NOT COMPOUNDING — and the difference matters enormously here. The
// user's own table (104 / 108 / 112) is linear, which is the safe reading:
//   linear      r20 1.20   r30 1.60   r40 2.00   r50 2.40   r100 4.40
//   compounding r20 1.22   r30 1.80   r40 2.67   r50 3.95   r100 27.6  <-- no
// They are near-identical for the first few rounds and diverge violently by
// spire depth, so "4% a round" has to be written down as which one it is.
//
// WHERE IT SATURATES, so nobody is surprised later: a fair-share full clear
// pays 18 x mult, so it reaches the 100 bar cap around round 130 — deep spire
// territory. Deliberately NOT capped: an artificial ceiling nobody asked for is
// the kind of silent divergence that gets rediscovered as a bug, and the bar
// cap already bounds the outcome.
//
// The SPIRE stacks cleanly: its halved round budget already doubles the
// per-kill value through the same hook, and a full clear still pays the
// fair-share figure — this multiplier scales that, it does not bypass it.
#define TOD_LUCK_LATE_FROM     15     // rounds ABOVE this get the boost
#define TOD_LUCK_LATE_PER_RND   0.04  // +4% of the base rate per round past it
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
// A DOWN COSTS 15 (user 2026-09-03: "Going down can be -15%"). Was 25, which
// was set when a round's fair share was 40 — after the 2026-08-20 cut to 18 a
// single down cost MORE THAN A WHOLE ROUND OF KILLS, so late game one bad
// round could outweigh two good ones. 15 also lands it exactly on
// TOD_LUCK_REVIVE, so a teammate picking you up now returns to the party
// precisely what the down took from you.
#define TOD_LUCK_DOWN          15     // lost on going down
#define TOD_LUCK_GAIN_PER_LVL  0.10   // the LUCK domain: +10% gain rate / Lv

// RAMPAGE — A DOWN IS A PARTY EVENT (v14.36, user 2026-08-30: "On rampage if a
// player goes down everyone loses 50% luck"). The SIXTH rampage lever, and the
// first one that is not about the enemy at all: it attacks the party's shared
// card economy instead of the horde's stat block.
//
// MULTIPLICATIVE, not a flat subtraction — "loses 50%" reads as HALVE THE BAR,
// and halving is the version that scales: it costs a banked player 50 and a
// broke player almost nothing, so the punishment tracks how much you had to
// lose. That also makes it bite hardest at exactly the moment the party cares
// most — a full bar or an OVERCHARGE at 150 drops to 75 and falls out of the
// guaranteed-ultimate band, which is the loudest possible consequence and
// needs no new cue to be felt.
//
// APPLIES TO EVERY PLAYER INCLUDING THE ONE WHO WENT DOWN, and it is ON TOP OF
// that player's existing TOD_LUCK_DOWN (15 since 2026-09-03). Deliberate, and the alternative was
// considered: making the halving REPLACE the 25 would mean a low-bar player
// under RAMPAGE loses LESS than the same player in a normal match (bar 10:
// halve = -5, versus the flat -25 that floors them). A hard mode must never be
// softer than the base game on any input, so the base penalty stays untouched
// and this stacks on top. Net effect at a full bar: the downed player pays
// 62.5, everyone else pays 50.
#define TOD_LUCK_DOWN_PARTY_MULT 0.5
// v16.59 REVERTED (user 2026-09-02: "we need to revert the losing luck when
// player goes down on rampage"). The v14.38 party halving is OFF: a down under
// RAMPAGE now costs the downed player the ordinary TOD_LUCK_DOWN 15 and nobody
// else anything — identical to a normal match. party_down_drain() and its
// contract comment stay so the lever is one flip away; the switch below is the
// only gate on the call in down_watcher.
#define TOD_LUCK_RAMPAGE_PARTY_DRAIN 0   // 1 = v14.38 rule (a RAMPAGE down halves EVERY bar); 0 = off (v16.59)

// --- THE AUDIBLE LUCK LADDER -----------------------------------------------
// User 2026-09-22: replace the Apex ding with Origins soul/collection sounds.
// Orbs own release/travel/arrival; segments 1..9 keep their climbing chimes.
// At 100, the pack's collection-complete cue replaces the tenth chime.
#define TOD_LUCK_SEGS          10     // must match the HUD's segment count
#define TOD_LUCK_PIP_DELAY     0.12   // pip follows the orb arrival cue

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
#define TOD_LUCK_OVER_ZAP_LIMIT  7    // silence after seven actual plays; animation continues

#namespace tod_luck;

function init()
{
	tod_luck_orbs::init( &orb_received );
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
function dupe_award( player, kind, org )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return;
	if ( !isdefined( kind ) ) kind = "perk";
	n = TOD_LUCK_PERK_DUPE;
	if ( isdefined( kind ) && kind == "pap" )
		n = TOD_LUCK_PAP_DUPE;
	add( player, n, org, "duplicate_" + kind );
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
			// [tod 2026-09-09] PUBLISHED for anyone else normalising by round
			// size -- the mage's mana bar is the second customer. One writer,
			// one stock call, no second per-round watcher: this loop already
			// runs and already has the number.
			level.tod_round_zombie_total = total;
			base = TOD_LUCK_KILL_BUDGET * p / total;
			// [v17.1] late-round boost — linear, see the defines
			if ( r > TOD_LUCK_LATE_FROM )
				base = base * ( 1.0 + TOD_LUCK_LATE_PER_RND * ( r - TOD_LUCK_LATE_FROM ) );
			level.tod_luck_per_kill = base;
		}
		wait 1;
	}
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

function add( player, amount, org, source )
{
	if ( !isdefined( player ) || !isplayer( player ) || !isdefined( amount ) || amount <= 0 )
		return;
	// LUCK domain: gain-rate boost (user pick — gains only, never losses)
	lvl = tod_upgrades::get_level( player, "luck" );
	gain = lvl * TOD_LUCK_GAIN_PER_LVL;
	// LUCK has NO dark step since 2026-09-05 (user: "Remove dark luck"); the
	// v17.10 x2.00 lane (+0.50 gain) was retired here and in set_no_dark().
	if ( gain > 0 )
		amount = amount * ( 1.0 + gain );

	// Ordinary kills retain their luck, but no soul FX/audio or mover is needed.
	// Elite bonuses arrive separately through boss_kill, including Sprinters
	// that also earn this normal zombie-death reward.
	if ( isdefined( source ) && ( source == "zombie" || source == "headshot" ) )
	{
		before = bar_of( player );
		set_bar( player, before + amount );
		tod_luck_orbs::log( "DIRECT p=" + player GetEntityNumber() + " source=" + source + " amount=" + amount + " before=" + before + " after=" + bar_of( player ) );
		return;
	}

	// Snapshot the gain rate at the source. A card picked while this orb is
	// travelling must not multiply an already-earned reward a second time.
	tod_luck_orbs::emit( player, amount, org, source );
}

// Called only by the delivery manager after actual mover-to-player contact.
function orb_received( player, amount )
{
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

// RAMPAGE ONLY — one player going down HALVES EVERY player's bar (v14.36).
// Called from down_watcher on the laststand EDGE, so it fires once per down.
//
// ONE READER of level.tod_rampage_on in this file, right here. _tod_rampage.gsc
// is the sole WRITER and nothing is imported in either direction — the same
// field-read contract _tod_zombie_speed::full_round uses. With the field absent
// or false this function is never called at all, so RAMPAGE-off behaviour is
// byte-identical to before.
//
// EVERY WRITE GOES THROUGH set_bar, deliberately, because set_bar is the single
// owner of four things this must not re-implement: the 0/150 clamp, the HUD
// refresh, the segment-pip rule (downward crossings are silent, so a halving
// makes no ding — correct, the bar dropping IS the read), and the OVERCHARGE
// state. That last one matters most: overcharge_driver polls its own exit, so
// halving a 150 bar to 75 ends the zap animation and its 3s deep-zap within one
// 0.15s tick with nothing to clean up here.
//
// GetPlayers() is the whole connected party, which is what "everyone" means.
// Players who are themselves down, or dead and spectating, are included on
// purpose — a bar is a bar, and skipping them would hand a wiped-out teammate
// an untouched bar to walk back in with. In SOLO "everyone" is one player, so
// the lever still bites: a solo down costs 62.5 of a full bar instead of 25.
//
// NO DEBOUNCE, per the spec: two players going down inside the same 0.5s
// down_watcher tick fire this twice and the bar quarters. That is two downs and
// two penalties, and it is the correct reading of "if a player goes down" — but
// it IS the sharpest edge in the feature, so it is the first knob to revisit if
// co-op wipes feel unrecoverable.
function party_down_drain()
{
	foreach ( p in GetPlayers() )
	{
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		set_bar( p, bar_of( p ) * TOD_LUCK_DOWN_PARTY_MULT );
	}
}

// The upgrade event consumed the bar (user: full reset to 0).
function spend( player )
{
	set_bar( player, 0 );
}

// The normalized zombie-kill award (last hit takes all).
function on_zombie_kill( attacker, b_headshot, org )
{
	amt = level.tod_luck_per_kill;
	if ( !isdefined( amt ) )
		amt = 1.0;
	if ( IS_TRUE( b_headshot ) )
		amt = amt * TOD_LUCK_HEADSHOT_MULT;
	source = ( IS_TRUE( b_headshot ) ? "headshot" : "zombie" );
	add( attacker, amt, org, source );
}

// Boss LAST HIT takes the full luck award (user 2026-08-20). kind =
// "panzer" | "protector". Called from _tod_bosses' death paths.
function boss_kill( killer, kind, org )
{
	if ( !isdefined( killer ) || !isplayer( killer ) )
		return;
	// v18.96 — ELITE KILL CONFIRM: red marker + ding for the killer, elites only
	// (user: "Zombies would get annoying"). This is the one call every elite
	// death already funnels through with its killer, so it hangs here.
	tod_killconfirm::elite_kill( killer, kind );
	if ( isdefined( org ) ) org += ( 0, 0, 40 );
	if ( isdefined( kind ) && kind == "panzer" )
	{
		add( killer, TOD_LUCK_PANZER, org, "panzer" );
		// (on-screen text removed 2026-08-20 — user: no floaty text)
	}
	else if ( isdefined( kind ) && kind == "reaver" )
	{
		add( killer, TOD_LUCK_REAVER, org, "reaver" );
	}
	else if ( isdefined( kind ) && kind == "hellhound" )
	{
		// EXPLICIT BRANCH REQUIRED, not optional. The final else below is a
		// CATCH-ALL paying TOD_LUCK_PROTECTOR, so passing an unmatched kind
		// compiles clean and silently pays the wrong number — a quiet balance
		// bug rather than a fatal. Hounds die in packs, so their per-kill luck
		// sits below a Reaver's.
		add( killer, TOD_LUCK_HELLHOUND, org, "hellhound" );
	}
	else if ( isdefined( kind ) && kind == "sprinter" )
	{
		// v14.8 hardening: the sprinter shipped v13.7 with NO branch and rode
		// the catch-all — the exact trap the hellhound comment above warns
		// about. It paid TOD_LUCK_SPRINTER's value by luck, not by intent;
		// now it pays it by name, and a Protector retune can't drag it along.
		add( killer, TOD_LUCK_SPRINTER, org, "sprinter" );
	}
	else
	{
		add( killer, TOD_LUCK_PROTECTOR, org, "protector" );
	}
}

// Door purchase (called from _tod_doors on a successful buy).
function door_buy( player, org )
{
	add( player, TOD_LUCK_DOOR, org, "door" );
	// (door text removed 2026-08-20 — user: no floaty text)
}

// Elite death notifies can race native corpse deletion. Keep a tiny position
// record while it lives; the death handler takes the exact origin when still
// available and otherwise uses this last position (never the killer's spot).
function track_source( actor )
{
	record = SpawnStruct();
	record.org = actor.origin;
	actor thread track_source_origin( record );
	return record;
}

function track_source_origin( record )
{
	self endon( "death" );
	self endon( "entityshutdown" );
	level endon( "end_game" );
	while ( isdefined( self ) && IsAlive( self ) )
	{
		record.org = self.origin;
		wait 0.1;
	}
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
	zaps_played = 0;
	while ( bar_of( self ) >= TOD_LUCK_OVERMAX )
	{
		f = 11 + RandomInt( 4 );
		if ( f == last )
			f = 11 + ( ( f - 11 + 1 ) % 4 );   // step to the next frame instead of repeating
		last = f;
		self tod_upgrade_ui::set_luck_over_frame( f );

		// THE ZAP IS GATED ON THE PLAYER HAVING SOMETHING TO SPEND IT ON
		// (v14.23, user: "player has no more upgrades so they cant even get
		// rid of the luck sfx"). A fully-maxed player CANNOT clear this bar:
		// the only thing that resets luck is taking a card, and roll_options
		// returns undefined for them — so the cue that means "your next deal
		// is guaranteed ULTIMATE" was promising a deal that will never come,
		// every ~3 seconds, for the rest of the run.
		//
		// The ANIMATION deliberately keeps running: it is silent and it is
		// still TRUE (the bar really is overcharged), so the state stays
		// legible without being audible. Only the noise stops.
		//
		// POLLED, NOT LATCHED, and inside the loop on purpose: a class-tier
		// promotion resets every gun-scoped domain and hands a maxed player
		// real headroom again — remaining zaps may resume then. Headroom
		// changes do not refill the seven-play allowance. Only a new
		// overcharge (after leaving the ceiling) gets a fresh allowance.
		if ( ( tick % TOD_LUCK_OVER_ZAP_TICKS ) == 0
		  && zaps_played < TOD_LUCK_OVER_ZAP_LIMIT
		  && tod_upgrades::has_upgrade_headroom( self ) )
		{
			self PlayLocalSound( "tod_luck_overmax_zap" );
			zaps_played++;
		}
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
	alias = segment_alias( seg );
	self PlayLocalSound( alias );
	if ( seg == TOD_LUCK_SEGS )
		tod_luck_orbs::log( "BAR_AUDIO p=" + self GetEntityNumber() + " cue=collection_full bar=" + bar_of( self ) );
}

function segment_alias( seg )
{
	if ( seg == TOD_LUCK_SEGS ) return "tod_luck_soul_full";
	return "tod_luck_pip0" + seg;
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
	// Headshots still boost normal kill luck; ordinary kills have no soul.
	on_zombie_kill( attacker, b_head, self.origin + ( 0, 0, 32 ) );
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
			add( reviver, TOD_LUCK_REVIVE, self.origin + ( 0, 0, 32 ), "revive" );
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
			// RAMPAGE (v14.36): the down also halves EVERY player's bar. Fired
			// AFTER the personal 25 so the downed player pays both, and placed
			// inside the same edge test so it can never double-fire on one down.
			// Threaded off, not called inline: party_down_drain touches every
			// player and each set_bar spawns a refresh_hud thread, and this poll
			// loop must not be the thing that stalls behind them.
			if ( TOD_LUCK_RAMPAGE_PARTY_DRAIN && IS_TRUE( level.tod_rampage_on ) )   // v16.59: switch OFF — see the define
				thread party_down_drain();
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
