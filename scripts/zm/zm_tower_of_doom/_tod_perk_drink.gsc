// =============================================================================
// ⚠️ DORMANT SINCE v14.19b (2026-08-30) — nothing calls init(). The BO7 drink
// cans (tod_set_perk_cans, v14.17) brought notetrack-driven foley riding the
// gesture anim itself, and the user retired this scripted lane to avoid
// glass-bottle audio layering over can audio ("we would need to remove our
// custom audio then"). The ONE switch is the commented init() call in
// _tod_main.gsc; the tod_perk_open/tod_perk_gulp aliases + wavs stay packed
// (harmless, and pulling them is a bank rebuild for nothing). Everything
// below is the working recipe as retired — including the hard-won timing
// lesson — for if the drinks ever go back to silent bottles.
// =============================================================================
// _tod_perk_drink.gsc — the perk BUY sound: a bottle cap popping, then a gulp.
//
// (user 2026-08-29: "I basically need a sound of opening a glass bottle soda
// and one fresh gulp" — the first item off docs/43_sound_audit.md.)
//
// WHY THIS EXISTS: stock BO3's only per-drink audio is the BURP, and it is one
// alias reused twelve ways — zm_usermap.gsc:357-369 sets
// level.exert_sounds[1..4]["burp"][0..2] = "evt_belch" for all four characters
// and all three variation slots. The drink itself has no script-side sound at
// all; whatever you hear rides in the perk bottle's viewmodel animation. So a
// perk purchase — 2500-8000 points, one of the loudest decisions in a run —
// lands with a jingle and a belch and nothing in between.
//
// ---------------------------------------------------------------------------
// THE TIMING, AND WHY IT IS BUILT TO BE RETUNED
//
// Stock's drink sequence (_zm_perks.gsc:604-625) runs:
//
//   player notify( "perk_purchased", perk )     <- t=0, points are gone
//   sndPerksJingles_Player(1)                   <- the perk's own sting
//   vending_trigger_post_think():
//       perk_give_bottle_begin()                <- GiveWeapon + SwitchToWeapon
//                                                  ...the RAISE animation
//       waittill "weapon_change_complete"       <- bottle is up, at the lips
//       wait_give_perk()  (<=0.5s for "burp")   <- the drink
//       perk_give_bottle_end()                  <- switch back
//       notify( "burp" )                        <- SCRIPT-fired, not a notetrack
//
// BOTH cues are now PLAIN DELAYS off "perk_purchased", and the second one is a
// correction worth recording.
//
// The first pass anchored the gulp on the engine event "weapon_change_complete"
// — the bottle finishing its raise — on the reasoning that a real event beats a
// tuned constant and survives an animation swap. That reasoning was sound and
// the result was still WRONG. User verdict, 2026-08-29, after playing it:
// "the gulp actually needs to go 0.85s after. It cant wait till after cause the
// drink is out of the hand already." By the time the raise event fires, the
// bottle is already back down — so the event marks the END of the drink, not
// the start of it. There is no engine event for "bottle is at the lips", which
// is the moment we actually want, so the honest implementation is a number.
//
// THE LESSON: an event anchor is only better than a constant when the event
// marks the moment you want. Anchoring to the nearest available event and
// nudging with an offset just hides a constant behind a false guarantee.
//
// RETUNING IS CHEAP AND THAT IS THE POINT. The wavs are already in the bank, so
// changing these two numbers is GSC-only — a `-GscOnly` build, ~4 minutes.
// Adding or replacing a WAV is a FULL build. The expensive half is done once and
// the timing gets walked in as many times as it takes.
//
// ONE ASSET QUIRK, for whoever tunes this next: tod_perk_open.wav does NOT open
// with the pop. It runs cap-scrape (0 -> 0.19s), silence (-> 0.30s), then the
// pop and fizz (-> 0.94s). So the audible POP lands ~0.30s after
// TOD_DRINK_OPEN_DELAY, not on it. Tune by what you hear, but know the offset
// is there before you conclude a number is wrong.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

// --- the two tuning knobs. BOTH are absolute, measured from the buy ----------
// (GscOnly to change — the wavs are already in the bank.)
// FINAL — set from the user's own ears in game over four passes, 2026-08-29:
// 0.25/event-anchored -> 0.75/1.60 -> 0.60/0.90 -> 0.55/0.90 -> 0.60/0.90.
//
// THESE NUMBERS NOW MEAN WHAT THEY SAY, which was not true before. The original
// tod_perk_open.wav was 0.96s and held TWO blocks — a cap crack (0 -> 0.16) and
// then a swelling carbonation fizz (0.31 -> 0.94) — so the delay below did not
// line up with anything the player could point at, and the fizz ran on under the
// gulp. User verdict: "all i want is a soda bottle open sound at 0.6 and 0.9 a
// gulp ... it doesnt flow well with how fast the player drinks."
//
// The wav is now the CAP CRACK ONLY, trimmed to 0.20s and starting on the
// transient. So the cap is heard AT TOD_DRINK_OPEN_DELAY exactly, the gulp at
// TOD_DRINK_GULP_DELAY exactly, and the 0.30s between them is the real gap. No
// hidden in-file offset to reason around any more — if a cue sounds late, move
// its number by how late it sounds.
#define TOD_DRINK_OPEN_DELAY    0.80   // bottle cap, this long after "perk_purchased"
#define TOD_DRINK_GULP_DELAY    0.90   // gulp,       this long after "perk_purchased"

#namespace tod_perk_drink;

function init()
{
	callback::on_spawned( &on_player_spawned );
}

// self = player. ONE watcher per player for the whole game — the latch survives
// respawns, and the thread only ends on disconnect. Same shape as
// _tod_runandgun::on_player_spawned, and for the same reason: a co-op bleed-out
// respawn dispatches on_player_spawned twice (_tod_powerups.gsc:970-972).
function on_player_spawned()
{
	if ( IS_TRUE( self.tod_drink_watch_on ) )
		return;
	self.tod_drink_watch_on = true;
	self thread drink_watch();
}

// self = player
function drink_watch()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( "perk_purchased" );
		self thread drink_sfx();
	}
}

// self = player. PlayLocalSound throughout: this is a first-person foley cue and
// belongs to the drinker only. A teammate two floors up hearing someone else's
// gulp at full volume would be worse than silence — the same reasoning as the
// scavenger clink (_tod_upgrades.gsc:850-859).
function drink_sfx()
{
	self endon( "disconnect" );
	self endon( "player_downed" );
	self endon( "perk_abort_drinking" );
	level endon( "end_game" );

	wait TOD_DRINK_OPEN_DELAY;
	self PlayLocalSound( "tod_perk_open" );

	// Both knobs are absolute from the buy, so the second wait is the gap
	// between them. Keep them in that order; a gulp before the pop is a bug.
	wait ( TOD_DRINK_GULP_DELAY - TOD_DRINK_OPEN_DELAY );
	self PlayLocalSound( "tod_perk_gulp" );
}
