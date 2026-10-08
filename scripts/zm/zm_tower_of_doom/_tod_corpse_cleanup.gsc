// =============================================================================
// _tod_corpse_cleanup.gsc — delete zombie bodies so they never eat the actor cap
//
// WHY THIS EXISTS (user 2026-08-25: "can we go to 45 for the whole game not just
// boss. I think we need to be carefull and make sure bodies get clean up
// quickly. Maybe couple seconds after dying.")
//
// THE CAP IS TWO NUMBERS, NOT ONE, and they count different things:
//   level.zombie_ai_limit     stock 24 -> ai_limit_for_party() 30/35/40/45
//       gates get_current_zombie_count() = GetAITeamArray(zombie_team) MINUS
//       anything carrying ignore_enemy_count. Every boss in this map sets that,
//       so this number is LIVE ZOMBIES ONLY — bosses are invisible to it.
//   level.zombie_actor_limit  stock 31 -> TOD_ACTOR_LIMIT 60
//       gates get_current_actor_count() = GetAiSpeciesArray(zombie_team,"all")
//       PLUS GetCorpseArray() (zombie_utility.gsc:2264-2276). That one counts
//       EVERYTHING: zombies, bosses, and every body still lying on the floor.
// Neither is an engine limit — both are `if (!isdefined(...))` defaults in
// _zm.gsc:337-343. The real ceiling is 64, netcode-imposed.
//
// SO THE BODIES ARE THE PROBLEM. Raise the live cap to 45 without touching
// corpses and the actor count is 45 zombies + up to a dozen elites + every body
// killed in the last few seconds — straight through 60 and into stock's spawn
// stall. A merely Ghost()'d corpse is invisible but STILL COUNTS. Only Delete()
// takes it out of the array.
//
// THIS IS NOT A MEMORY LEAK, AND THE DISTINCTION MATTERS (user: "This is where
// possible memory leak can break the game"). A corpse is a normal server entity
// on stock's own timer — the engine recycles it, and stock's spawn gate calls
// clear_all_corpses() the moment the actor count is hit (_zm.gsc:3740-3744), so
// bodies can never accumulate without bound even with this file deleted. What
// they CAN do is sit in the count long enough to throttle spawning, which reads
// in game as the horde going thin. Deleting them early strictly REDUCES entity
// pressure; it never adds any.
// The one genuine unbounded-growth risk in this design would be the per-corpse
// thread itself, so it is a straight line with one wait and no loop, it holds no
// reference after Delete(), and it cannot outlive the entity (see below).
//
// PORTED from map 1's _acc_corpse_cleanup.gsc, which ships this to run
// ACC_AI_LIMIT 50 / ACC_ACTOR_LIMIT 56. Two deliberate changes:
//   * LINGER 2s, not 0. Map 1 vanishes bodies on the death frame. The ask here
//     was "a couple seconds after dying", so the body drops, reads as a kill,
//     and then goes.
//   * THE LINGER IS ADAPTIVE. Two seconds of visible body is a luxury, and it is
//     the first thing given up when the board is full — see corpse_remove().
//     Map 1 did not need this because its linger was zero.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;   // v19.18d — tod_hoop_watch, the client-side flight log (lockstep _tod_hoop.csc)
#using scripts\shared\system_shared;        // v19.18d — REGISTER_SYSTEM for the clientfield's registration window
#using scripts\shared\util_shared;

#using scripts\shared\ai\zombie_utility;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_score;      // add_to_player_score — the hoop's payout (never write player.score)
#using scripts\zm\_zm_utility;    // play_sound_at_pos
#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // base_hoop_lo/_hi (GENERATED — pure data, imports nothing, no cycle)

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// The hoop's kill-feed label (KF_HOOP in zm_aetherium.str; the compiler
// prepends the filename). Precached AFTER every #using/#insert — the rule.
#precache( "string", "ZM_AETHERIUM_KF_HOOP" );

#namespace tod_corpse_cleanup;

// v19.18d — the actor clientfield that starts the CLIENT's flight log for a
// bat-flung body (_tod_hoop.csc, LOCKSTEP). Registered here, in the
// registration window, and only ever set to 1 at the launch.
REGISTER_SYSTEM( "tod_corpse_cleanup", &__init__, undefined )

function __init__()
{
	clientfield::register( "actor", "tod_hoop_watch", VERSION_SHIP, 1, "int" );
}

// LIVE ZOMBIES. 45 (user 2026-08-25), against stock 24 and map 1's proven 50.
// Under map 1's own note — "4-player netcode may strain near the ceiling; if it
// rubber-bands, drop toward ~40" — 45 sits between its shipped 50 and that
// floor, which is the cautious read of a number that is already known to work
// one map over.
// PARTY-AWARE SINCE v18.11 (user 2026-09-07: "People are seriously complaining
// about the difficulty. Is there a limit of zombies on map by players?").
//
// THE ANSWER WAS NO, AND THAT WAS THE PROBLEM. This was a flat 45 for one player
// or four. Stock's default is 24 solo, so a solo player was holding ~1.9x stock
// concurrency and FOUR TIMES the per-player pressure of a quad (45 each against
// 11.25 each) - on an open staircase 160 units wide with a drop on one side.
//
// AND ELITES DO NOT COUNT TOWARD IT. Every elite in this map sets
// ignore_enemy_count, so this number is trash zombies ONLY: the Panzer, the
// Protectors, the Reavers, the hounds and the sprinters all stand on TOP of it.
//
// THE LADDER: 30 / 35 / 40 / 45. The quad number is unchanged, deliberately -
// 45 is the figure the user asked for by name on 2026-08-25 and the one co-op
// has actually been played on, so this cut cannot touch a party size that has
// evidence behind it. Solo still sits well above stock's 24, so the map keeps
// its identity; it just stops asking one player to hold a four-player wall.
//
// ⚠️ THIS IS THE THIRD SOLO NERF IN THREE VERSIONS - v18.1 cut the combined
// elite roof 12 -> 5 and removed the solo horde-health surcharge, and neither
// has been played. If solo now reads TOO EASY, this ladder is the first thing to
// walk back, not the elite roof: concurrency is the lever a player feels most
// directly, and it is the one that moved last.
//
// A NOTE ON v18.1's OWN AUDIT: its table recorded this row as "24 solo / 9.3
// trio", figures computed from coop_ai_limit() - which had been DEAD since
// v10.26. The one number that most defines solo pressure was mis-recorded in the
// pass written to relieve solo. Read ai_limit_for_party(), never a quoted total.
#define TOD_AI_LIMIT_SOLO   30
#define TOD_AI_LIMIT_PER    5     // per extra player
#define TOD_AI_LIMIT_MAX    45    // the quad ceiling, and the pre-v18.11 flat value
// RAMPAGE (v18.74, user 2026-09-10: "zombies alive at once jumps 10"). ADDED
// on top of the party figure AFTER the clamp, so hard mode is 40/45/50/55 —
// it was a flat 45 from v18.11, which at quad was no step at all. 55 + the
// rampage elite roof (14 at quad) is over TOD_ACTOR_LIMIT 60; that is the
// documented-safe overflow (stock clears corpses and waits 0.1 s), so at quad
// the last few of the 55 arrive as bodies leave rather than all standing.
#define TOD_RAMPAGE_AI_LIMIT_ADD 10

// LIVE ZOMBIES + BOSSES + BODIES. The headroom over TOD_AI_LIMIT is 15, and it
// is sized for the worst realistic board rather than the average one:
//     45 live zombies (the QUAD ceiling - ai_limit_for_party() since v18.11;
//        smaller parties leave more headroom, never less, so this sizing holds)
//   +  up to ~12 elites (panzer 1 + protectors 8 + reavers 3; the hound
//      director's own combined guard is 9)
//   +  bodies killed inside the linger window
// which can exceed 60 in a quad late round — and that is FINE, because going
// over does not crash: stock's gate calls clear_all_corpses() and waits 0.1s
// (_zm.gsc:3740). The adaptive linger below is what keeps it from getting there
// in the first place. 60 also leaves 4 under the 64 engine ceiling.
#define TOD_ACTOR_LIMIT     60

// How long a body stays visible before it is deleted, when there is room for it.
#define TOD_CORPSE_LINGER   2.0

// THE SAFETY VALVE. When the actor count is within this many of TOD_ACTOR_LIMIT,
// the linger is skipped and the body is deleted on the spot. This is what makes
// the 2s cosmetic rather than structural: at a quiet moment you get bodies on
// the floor, and the instant the board fills they stop existing, so corpses can
// never be the reason a zombie fails to spawn.
#define TOD_CORPSE_PANIC    10

// Let the engine finish its own death processing (notetracks, drops) before the
// entity goes. Stock's giant-cleanup uses the same brief wait before Delete
// (zm_giant_cleanup_mgr.gsc:236-241).
#define TOD_CORPSE_SETTLE   0.05

// --- THE BAT HOME RUN: how far a swatted body flies (v19.10, user 2026-09-15:
// "is it possible to make the launch distance variable?") ------------------
// It was two literals inside bat_home_run, 180 forward and 110 up, so every
// body left the bat on exactly the same arc. Three things move it now:
//
//   1. THE BASE, tunable here rather than buried in the function.
//   2. A PER-SWING ROLL in [1 - VAR, 1 + VAR]. One roll scales BOTH axes, so
//      the arc keeps its shape and only its length changes — rolling the two
//      independently makes short hits float and long ones skim, which reads
//      as a bug rather than as variety.
//   3. A PACKED BONUS. A Pack-a-Punched bat hits for double (register_melee_dmg
//      1600/3200), so it should visibly throw further; the test is the same
//      "_up" substring the rest of the map uses to spot a packed weapon.
//
// Distance is roughly linear in the impulse, so FWD is the "how far" knob and
// UP is the "how high" one. Keep UP under FWD or bodies go straight up.
#define TOD_BAT_FLING_FWD       180     // forward impulse, the base swing
#define TOD_BAT_FLING_UP        110     // vertical impulse, the base swing
#define TOD_BAT_FLING_VAR       0.35    // +/- fraction rolled per swing (0 = fixed)
#define TOD_BAT_FLING_PAP_MULT  1.60    // a packed bat throws this much further

// THE HOME RUN: 1% of killing hits send the body twice as far as the roll can
// otherwise reach (user: "a super rare launch distance that sends the zombies
// 2x max and its 1% chance of happening"). 2x MAX, not 2x average — the
// ceiling of the normal roll is 1 + TOD_BAT_FLING_VAR, so this is exactly
// double the best ordinary swing rather than double a typical one.
#define TOD_BAT_CRIT_PCT        1       // percent of bat kills that go long
#define TOD_BAT_CRIT_MULT       2.0     // multiple of the NORMAL ROLL CEILING

// THE HOOP (v19.18, user 2026-09-16: "a hole inside the tower where you can
// attempt to launch zombies into the hole for like an extra 20 dollars ... a
// fun little game for slasher players"). The recess is cut by the generator
// into the core's south face above the base upgrade station, and its box rides
// in through GENERATED tod_breather_data::base_hoop_lo/_hi — the target the
// player sees IS the volume tested here. A packed bat already throws x1.6
// further (TOD_BAT_FLING_PAP_MULT), which is the "make even more money" the
// user described: the same 20, landed more often.
//
// THE ARC IS COMPUTED, NOT OBSERVED (v19.18d). TWO probes on 2026-09-16
// (docs/147) settled it: the server sees NOTHING of a launched ragdoll —
// not when the body is ragdolled dead (v19.18), not when it is ragdolled
// alive and killed a frame later, stock's gravity-spikes order (v19.18c).
// Origin static, spine tag +12..+50 and settling, no "actor_corpse", ever.
// The flight every player sees is CLIENT physics, and a client cannot tell
// the server anything. So the server scores the shot it MADE: from the launch
// point and the impulse it chose, hoop_arc integrates a ballistic arc
// (v = impulse x TOD_HOOP_ARC_KH/KZ per axis, gravity TOD_HOOP_GRAVITY) one server frame at
// a time, stops at the first world hit (BulletTrace, world only) or the
// first sample inside the box (grown TOD_HOOP_SLOP), and pays on "basket".
// The body's picture and the server's arc agree only as well as
// TOD_HOOP_ARC_KH/KZ do — MEASURED from the client log on 2026-09-16 (tools/hoop_calibrate.py)
// it: _tod_hoop.csc watches the same body on the client (clientfield
// tod_hoop_watch) and prints [TOD_HOOP_C] SAMPLE / FLIGHT lines with the real
// apex and landing, beside the server's [TOD_HOOP] ARC line for the same
// entity. K = (client apex - launch z) solved against the server's v_z:
// apex = (v_z K)^2 / (2 g). Read docs/147 §calibration before touching K.
// Logs are gated on TOD_HOOP_LOG so the user's dev-OFF build records them
// (their launcher already enables devblock prints).
#define TOD_HOOP_PTS        50          // paid to the swinger per body that lands in the hoop (20 -> 50 on 2026-10-01, lead tester: "too unnoticeable ... buff it to 50+" - the low-kill Slasher's early boost)
#define TOD_HOOP_SLOP       24          // box grown this much on every side (v19.20b: a body that clips the rim and falls out still counts; 48 was "not even close")
#define TOD_HOOP_ARC_KH     3.1         // MEASURED (2026-09-16 run 16:34, 29 launches paired with the client's real flights,
#define TOD_HOOP_ARC_KZ     4.4         // tools/hoop_calibrate.py): units/s of flight per unit of LaunchRagdoll impulse, HORIZONTAL
                                        // (median K_h 3.10) and VERTICAL (median K_z 4.40) - the ragdoll bleeds horizontal speed
                                        // and keeps its vertical. One K per axis reproduces all 5 real baskets of that run with one
                                        // false positive at slop 24; the v19.20 fan (2.8..6.0, slop 48) paid 16 of 29 - the user:
                                        // "every hit is a false positive ... it just needs to go in the hole".
#define TOD_HOOP_GRAVITY    800         // u/s^2 the arc falls under (stock bg_gravity)
#define TOD_HOOP_ARC_DT     0.08        // the arc step (s); the fan traces one whole arc per server frame
#define TOD_HOOP_ARC_SECS   3.0         // an arc is abandoned after this long
#define TOD_HOOP_ARC_LIFT   32          // the arc starts this far above the feet (the body's centre)
#define TOD_HOOP_LOG        0           // 0 = SHIP (v19.22). 1 prints [TOD_HOOP]/[TOD_BAT] without tod_dev, for calibrating the arc against the client log (docs/147); tod_dev still prints either way.
#define TOD_HOOP_SFX        "tod_hoop_score"     // v19.21: the user's success sting (tod_ui.csv, 3D, sound_assets/tod/sfx/tod_hoop_score.wav), played IN THE WORLD
#define TOD_HOOP_SFX_SECS   5                   // the emitter lives this long (the sting is 3.4 s)
#define TOD_HOOP_SFX_ORG    ( 0, -950, 60 )      // ... at the centre of the four teleporter UP pads, eye height - "anyone around will hear it when anyone scores"
#define TOD_BAT_LINGER      3.5         // a flung body's linger (s) — the arc's own clock runs under it

// PUBLIC — how many live zombies may stand at once for the CURRENT party size.
// 30 solo / 35 / 40 / 45, clamped both ends, PLUS TOD_RAMPAGE_AI_LIMIT_ADD while
// the breaker is thrown (40 / 45 / 50 / 55). A fifth body cannot exist in ZM,
// but the clamp costs nothing and a 0-player frame (everyone disconnecting) must
// not return a negative.
function ai_limit_for_party()
{
	np = GetPlayers().size;
	if ( np < 1 )
		np = 1;
	n = TOD_AI_LIMIT_SOLO + ( np - 1 ) * TOD_AI_LIMIT_PER;
	if ( n > TOD_AI_LIMIT_MAX )
		n = TOD_AI_LIMIT_MAX;
	// RAMPAGE IS THE HARD MODE (v18.11, user 2026-09-07: "I want rampage to be
	// the difficult mode"). v18.11 held the pre-relief FLAT 45 here, which was
	// a 15-zombie step at solo and NO step at quad; v18.74 (user 2026-09-10:
	// "zombies alive at once jumps 10") makes it +10 over the party figure at
	// every size, so the step is the same for everyone and the player chose it.
	if ( IS_TRUE( level.tod_rampage_on ) )
		n = n + TOD_RAMPAGE_AI_LIMIT_ADD;
	return n;
}

function init()
{
	// THE CAPS ARE SET HERE, not in the entry script, so the number and the
	// mechanism that makes it safe live in one file. Live values — stock's spawn
	// loop re-reads both every iteration (_zm.gsc:3735/3740), so this does not
	// need to beat any particular init to the punch.
	level.zombie_ai_limit    = ai_limit_for_party();
	level.zombie_actor_limit = TOD_ACTOR_LIMIT;

	// v18.11 — AND IT FOLLOWS THE PARTY. Polled rather than hooked on
	// connect/disconnect: stock re-reads the field on every spawn pass, so a 2 s
	// cadence is exact enough and needs no callback plumbing. This is the SAME
	// shape the retired coop_ai_limit() used, now living in the file that OWNS
	// the field — which is the whole reason that one had to be retired: two
	// writers on one field, and the looping one always wins.
	//
	// ONE WRITER, and it must stay that way. If a future change wants a
	// different concurrency during some phase, it belongs in
	// ai_limit_for_party(), not in a second thread.
	level thread ai_limit_watch();

	zm_spawner::register_zombie_death_event_callback( &on_zombie_death );
	bat_log( "INIT rev=3 killing_hits_only=1 all_swings=1 fwd=" + TOD_BAT_FLING_FWD
	       + " up=" + TOD_BAT_FLING_UP + " var=" + TOD_BAT_FLING_VAR
	       + " pap=" + TOD_BAT_FLING_PAP_MULT + " crit_pct=" + TOD_BAT_CRIT_PCT );
	// Diagnostics observe real swings only. Dev mode must never aim for the
	// player or manufacture kills (the retired hoop calibration probe did both).
	hoop_log( "INIT rev=7 manual_hits_only=1 pts=" + TOD_HOOP_PTS + " kh=" + TOD_HOOP_ARC_KH + " kz=" + TOD_HOOP_ARC_KZ + " g=" + TOD_HOOP_GRAVITY + " lift=" + TOD_HOOP_ARC_LIFT + " slop=" + TOD_HOOP_SLOP
	        + " lo=" + tod_breather_data::base_hoop_lo() + " hi=" + tod_breather_data::base_hoop_hi() );
}

// Keeps level.zombie_ai_limit in step with the party. Writes only on a CHANGE so
// the common case is a compare, and so a debug read of the field is not a moving
// target every two seconds.
function ai_limit_watch()
{
	level endon( "end_game" );

	last = level.zombie_ai_limit;
	for ( ;; )
	{
		wait 2;
		lim = ai_limit_for_party();
		if ( lim != last )
		{
			last = lim;
			level.zombie_ai_limit = lim;
		}
	}
}

// self = the killed zombie. One dispatch per death, synchronous with the rest of
// the death chain (points, luck, class-gun kill credit), so this must not block:
// it threads and returns.
function on_zombie_death( attacker )
{
	if ( !isdefined( self ) )
		return;

	self bat_home_run( attacker );

	// BOSSES OWN THEIR DEATHS. Every boss in this map is stamped is_boss +
	// acc_is_boss + acc_is_mini_boss (_tod_bosses.gsc:1010-1012, :1415-1417),
	// and the vendored packs run their own death sequences — a Panzer spawns a
	// death-anim clone and deletes itself. Deleting the body out from under that
	// is how you lose the animation, or worse. They are also a handful of
	// entities, not forty-five, so they are not what the cap is about.
	if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
		return;

	self thread corpse_remove();
}

// Presentation only, dispatched AFTER stock confirms a death. Do not predict a
// kill from raw damage or call DoDamage: armour, score and upgrades stay owned
// by their existing paths. No splash and no explosion effects. Elite packs own
// their death sequences; only ordinary zombie bodies use this ragdoll lane.
function bat_home_run( attacker )
{
	if ( !isdefined( attacker ) || !IsPlayer( attacker ) ) return;
	if ( !isdefined( self.damageweapon ) || !isdefined( self.damageweapon.name ) ) return;
	if ( !IsSubStr( self.damageweapon.name, "t9_me_baseballbat_" ) ) return;
	if ( !isdefined( self.damagemod ) || !IsSubStr( self.damagemod, "MELEE" ) ) return;
	if ( IS_TRUE( self.tod_bat_launched ) ) return;
	if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) || IS_TRUE( self.tod_is_sprinter ) || isdefined( self.tod_boss_kind ) )
	{
		bat_log( "SKIP ent=" + self GetEntityNumber() + " reason=elite_death_owner" );
		return;
	}
	// Every lethal bat swing flings; no input or inferred animation gate.
	// (v19.18c's pre-death lane is RETIRED — ragdolling the live body bought
	// the server nothing it could read; see the hoop block above.)
	self bat_fling( attacker, self.damageweapon.name, "death" );
}

// self = the zombie (alive on the normal lane, dead on the fallback). ONE
// owner of the roll, the impulse, the launch, the log and the hoop watcher.
function bat_fling( attacker, weapon_name, lane )
{
	dir = bat_launch_dir( attacker );

	// ONE roll, both axes — see the TOD_BAT_FLING_* block for why.
	scale = 1.0;
	if ( TOD_BAT_FLING_VAR > 0 )
		scale = RandomFloatRange( 1.0 - TOD_BAT_FLING_VAR, 1.0 + TOD_BAT_FLING_VAR );

	// THE HOME RUN. Rolled BEFORE the PaP multiplier so a packed bat does not
	// change how often it happens, only how far it goes when it does.
	crit = ( RandomInt( 100 ) < TOD_BAT_CRIT_PCT );
	if ( crit )
		scale = ( 1.0 + TOD_BAT_FLING_VAR ) * TOD_BAT_CRIT_MULT;

	if ( IsSubStr( weapon_name, "_up" ) )
		scale *= TOD_BAT_FLING_PAP_MULT;

	impulse = VectorScale( dir, TOD_BAT_FLING_FWD * scale )
	        + ( 0, 0, TOD_BAT_FLING_UP * scale );
	self.tod_bat_launched = true;
	self StartRagdoll();
	self LaunchRagdoll( impulse );
	// The CLIENT's flight log for this body (_tod_hoop.csc) — the one lane
	// that can see where the ragdoll really goes.
	self clientfield::set( "tod_hoop_watch", 1 );
	bat_log( "LAUNCH ent=" + self GetEntityNumber() + " player=" + attacker GetEntityNumber()
	       + " weapon=" + weapon_name + " lane=" + lane
	       + " all_swings=1 crit=" + crit + " scale=" + scale + " impulse=" + impulse );
	// THE HOOP — every fling is a shot at it. Threaded so the death chain never waits.
	self thread hoop_arc( attacker, impulse, scale, crit );
}

// THE LAUNCH DIRECTION (v19.18b). The swing used to be flattened to the yaw
// alone, which fixed the arc's SHAPE: with FWD 180 / UP 110 a body is only
// ~0.3 x its distance high at the apex, so it reaches the hoop's floor (240)
// some 780 units out — outside the arena — and the first playtest found the
// user launching from the teleport bay into the arena wall's top. An UPWARD
// aim now steepens the launch (the hoop is a skill shot: look up and swing); a
// DOWNWARD aim is still flattened, because a body driven into the floor is a
// body that goes nowhere. The base UP stays, so a level swing is unchanged.
function bat_launch_dir( attacker )
{
	fwd = AnglesToForward( attacker GetPlayerAngles() );
	if ( fwd[ 2 ] < 0 )
		fwd = ( fwd[ 0 ], fwd[ 1 ], 0 );
	return VectorNormalize( fwd );
}

// self = the flung body. THE SERVER'S ARC: integrate the launch it chose,
// one frame at a time, in real time (so the payout lands about when the
// body visibly arrives), stop at the first world hit or the first sample in
// the box. Runs on the body so it ends by itself if the engine recycles it
// (TOD_BAT_LINGER holds the body past TOD_HOOP_ARC_SECS). [TOD_HOOP] ARC.
function hoop_arc( attacker, impulse, scale, crit )
{
	lo = tod_breather_data::base_hoop_lo();
	hi = tod_breather_data::base_hoop_hi();
	p0 = self.origin + ( 0, 0, TOD_HOOP_ARC_LIFT );
	ent = self GetEntityNumber();
	// v19.20b: ONE arc, per-axis constants measured from the client's real flights (no fan, no guessing)
	v = ( impulse[ 0 ] * TOD_HOOP_ARC_KH, impulse[ 1 ] * TOD_HOOP_ARC_KH, impulse[ 2 ] * TOD_HOOP_ARC_KZ );
	// v19.20c: ON THE DEATH FRAME THE BODY IS STILL SOLID and a BulletTrace from inside it returns fraction 0 at
	// p0 - every arc of the 16:54 run "hit" at its own launch point (t=0.08, end == from). The 16:34 fan hid it: its
	// first arc died the same way and the later ones, a frame on, flew. Trace one frame later (corpse_remove has
	// made the body NotSolid by then) and ignore the body itself either way.
	wait TOD_HOOP_ARC_DT;
	if ( !isdefined( self ) )
		return;
	r = hoop_trace_arc( p0, v, lo, hi, self );
	hoop_log( "ARC ent=" + ent + " from=" + p0 + " impulse=" + impulse + " kh=" + TOD_HOOP_ARC_KH + " kz=" + TOD_HOOP_ARC_KZ + " v=" + v
	        + " result=" + r[ "result" ] + " t=" + r[ "t" ] + " apex=" + r[ "apex" ] + " end=" + r[ "end" ] + " hit=" + r[ "hit" ]
	        + " scale=" + scale + " crit=" + crit );
	if ( r[ "result" ] != "basket" )
		return;
	// pay when the body would arrive, on the SWINGER's thread so the corpse's deletion cannot swallow it
	if ( isdefined( attacker ) && IsPlayer( attacker ) )
		attacker thread hoop_pay_after( r[ "t" ], r[ "end" ], scale, crit, "arc" );
	else
		hoop_log( "SCORE unpaid (swinger gone) at=" + r[ "end" ] + " lane=arc" );
}

// The pure arc: from p0 with velocity v under TOD_HOOP_GRAVITY, stepped by TOD_HOOP_ARC_DT for up to
// TOD_HOOP_ARC_SECS, stopped by the first world hit (BulletTrace, world only) or by falling 256 under
// the launch floor. `ignore` = the body (its own collision must not stop its own arc). Returns result
// (basket|miss), t, apex, end, hit ("none" or the hit point).
function hoop_trace_arc( p0, v, lo, hi, ignore )
{
	r = [];
	r[ "result" ] = "miss";
	r[ "hit" ] = "none";
	p = p0;
	t = 0;
	apex = p0[ 2 ];
	while ( t < TOD_HOOP_ARC_SECS )
	{
		t += TOD_HOOP_ARC_DT;
		q = p0 + VectorScale( v, t ) + ( 0, 0, -0.5 * TOD_HOOP_GRAVITY * t * t );
		if ( q[ 2 ] > apex )
			apex = q[ 2 ];
		if ( hoop_inside( q, lo, hi ) )
		{
			p = q;
			r[ "result" ] = "basket";
			break;
		}
		trace = BulletTrace( p, q, false, ignore );
		if ( trace[ "fraction" ] < 1 )
		{
			p = trace[ "position" ];
			r[ "hit" ] = p;
			if ( hoop_inside( p, lo, hi ) )
				r[ "result" ] = "basket";
			break;
		}
		p = q;
		if ( q[ 2 ] < p0[ 2 ] - 256 )
			break;   // fallen well below the launch floor: it is down
	}
	r[ "t" ] = t;
	r[ "apex" ] = apex;
	r[ "end" ] = p;
	return r;
}

// self = the swinger. Waits out the flight, then pays (hoop_score checks the player is still here).
function hoop_pay_after( delay, p, scale, crit, lane )
{
	self endon( "disconnect" );
	level endon( "end_game" );
	if ( delay > 0 )
		wait min( delay, TOD_HOOP_ARC_SECS );
	hoop_score( self, p, scale, crit, lane );
}

// Inclusive axis-aligned box test on a point. lo/hi are the generated corners.
function hoop_inside( p, lo, hi )
{
	lo = lo - ( TOD_HOOP_SLOP, TOD_HOOP_SLOP, TOD_HOOP_SLOP );
	hi = hi + ( TOD_HOOP_SLOP, TOD_HOOP_SLOP, TOD_HOOP_SLOP );
	return ( p[ 0 ] >= lo[ 0 ] && p[ 0 ] <= hi[ 0 ]
	      && p[ 1 ] >= lo[ 1 ] && p[ 1 ] <= hi[ 1 ]
	      && p[ 2 ] >= lo[ 2 ] && p[ 2 ] <= hi[ 2 ] );
}

// Pays the swinger for one basket (hoop_arc calls it at most once per fling, on the
// swinger's own thread - v19.20 - so the corpse's deletion cannot swallow the payout).
// The swinger may have left the match by now, in which case the basket counts but
// nobody is paid. The kill-feed line rides the kit's own score_event lane with a
// map-owned string (KF_HOOP in zm_aetherium.str), so the popup is the same shape as
// every other point award on the HUD.
function hoop_score( attacker, p, scale, crit, lane )
{
	if ( !isdefined( attacker ) || !IsPlayer( attacker ) )
	{
		hoop_log( "SCORE unpaid (swinger gone) at=" + p + " lane=" + lane );
		return;
	}
	attacker zm_score::add_to_player_score( TOD_HOOP_PTS );
	attacker LuiNotifyEvent( &"score_event", 2, &"ZM_AETHERIUM_KF_HOOP", TOD_HOOP_PTS );
	score_emitter();   // v19.21c: a spawned script_origin PlaySound — the lane the teddy laugh is heard on; the stock position call was silent
	hoop_log( "SCORE player=" + attacker GetEntityNumber() + " pts=" + TOD_HOOP_PTS
	        + " at=" + p + " lane=" + lane + " scale=" + scale + " crit=" + crit );
}

// THE PAYOUT CUE (v19.22). A custom 3D alias is only audible in this map when it is played BY AN
// ENTITY: spawn a script_origin at the spot, PlaySound on it, delete it after the clip. That is the
// lane the teddy-bear laugh uses (the perk-scatter module owns an identical helper) and it is proven
// stock's PlaySoundAtPosition played nothing for this alias at any volume (v19.21/v19.21b).
// It is INLINE rather than a call into that module because importing it closed a module cycle
// (cleanup -> scatter -> bosses -> cleanup) which compiled but had never been played — eight lines
// are cheaper than a publish resting on that (v19.22 crash audit).
function score_emitter()
{
	e = Spawn( "script_origin", TOD_HOOP_SFX_ORG );
	if ( !isdefined( e ) )
		return;   // entity pool full — drop the cue, never throw
	e PlaySound( TOD_HOOP_SFX );
	e thread score_emitter_cleanup();
}

function score_emitter_cleanup()   // self = the temp emitter
{
	level endon( "end_game" );
	wait TOD_HOOP_SFX_SECS;
	if ( isdefined( self ) )
		self Delete();
}

function hoop_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) && !TOD_HOOP_LOG ) return;
	line = "[TOD_HOOP] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

function bat_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) && !TOD_HOOP_LOG ) return;
	line = "[TOD_BAT] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

// self = the corpse. A straight line: no loop, one conditional wait, and every
// step re-checks that the entity still exists — the engine can recycle a corpse
// underneath us at any time, and after Delete() nothing here holds a reference.
// linger: optional override of TOD_CORPSE_LINGER. v17.96 — elites pass a longer
// one so a Protector's fall / a Reaver's death swap can still be read before the
// body goes; the adaptive branch below still Ghosts immediately near the cap.
function corpse_remove( linger )
{
	if ( !isdefined( linger ) )
		linger = TOD_CORPSE_LINGER;
	// A bat-flung body is in the air for longer than the floor linger, and
	// hoop_arc runs on it: give it TOD_BAT_LINGER (v19.18c).
	if ( IS_TRUE( self.tod_bat_launched ) && linger < TOD_BAT_LINGER )
		linger = TOD_BAT_LINGER;
	// DE-COLLIDE ON THE DEATH FRAME, always, whatever the linger. A fresh body
	// that still blocks movement is the thing players actually feel — 45 of them
	// on a 160-wide staircase would be a wall. This is free and immediate.
	self NotSolid();

	// ADAPTIVE: only spend the two seconds if the board can afford them.
	// Re-checked here rather than at death time because the interesting case is
	// a burst of kills — the first few bodies linger, and by the time the count
	// climbs the rest are going straight out.
	// A BAT-FLUNG BODY KEEPS ITS LINGER EVEN UNDER PRESSURE (v19.18): it is in
	// the air, hoop_watch is reading it, and ghosting it on the death frame
	// would make every fling on a full board vanish mid-arc. There are only
	// ever a handful of them, so this cannot be what fills the pool.
	if ( IS_TRUE( self.tod_bat_launched ) || zombie_utility::get_current_actor_count() < ( TOD_ACTOR_LIMIT - TOD_CORPSE_PANIC ) )
	{
		wait linger;
		if ( !isdefined( self ) )
			return;   // the engine already recycled it — nothing to do
	}
	else
	{
		// Board is full: hide it now so the delete does not read as a body
		// blinking out of existence in front of the player.
		self Ghost();
	}

	wait TOD_CORPSE_SETTLE;
	if ( isdefined( self ) )
		self Delete();
}
