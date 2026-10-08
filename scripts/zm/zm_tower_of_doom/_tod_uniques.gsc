// =============================================================================
// _tod_uniques.gsc — per-player INPUT WATCHERS for the CLASS TIER unique
// upgrades (docs/25 §9, 2026-08-22). The upgrade EFFECTS live in
// _tod_upgrades.gsc (damage chain / kill hook / move-speed owner); this module
// only keeps two cheap per-player facts fresh so those hooks can read them:
//
//   self.tod_fire_streak / tod_fire_last_ms — consecutive class-gun shots with
//       no gap longer than TOD_STREAK_GAP_MS (OVERDRIVE on the MP7, MEAT
//       GRINDER on the Death Machine). `weapon_fired` is the engine's per-shot
//       player notify (every bullet of an automatic, loop-fire included) — the
//       same lane RUN AND GUN rides.
//   self.tod_sprint_seen_ms — the last poll that SAW the player sprinting
//       (DRAW CUT on the katana: a swing inside 0.4s of a sprint). Polled at
//       20 Hz — no engine notify for sprint edges is relied on, and a
//       "last seen" stamp (not a stop EDGE) stays correct whichever way the
//       engine orders sprint-exit vs the melee hit (review 2026-08-22).
//       tod_sprint_end_ms (the stop edge) is kept for anything else.
//   self.tod_lmgs_hot / tod_lmgs_since_ms — has this player sprinted without a
//       break for TOD_LMGS_ARM_MS (FULL STEAM, domain 42, the heavy's v15
//       replacement for MOBILITY). "Break" means losing sprint OR TAKING
//       DAMAGE (v16) — the damage half reads _tod_upgrades' tod_last_dmg_ms,
//       a plain field, so this module still imports no tod module. Unlike the two above, this one CALLS OUT on
//       its edges — through level.tod_apply_speed_fn, never a #using — because
//       a move-speed change has to land on the frame it is earned.
//
// Imports NO tod module (so _tod_upgrades can read these fields without a
// cycle); init from _tod_main, scriptparsetree line in the zone.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#define TOD_STREAK_GAP_MS   500    // a longer pause between shots ends the streak
#define TOD_SPRINT_POLL     0.05   // 20 Hz sprint-edge poll
// FULL STEAM (domain 42, v15): unbroken sprint this long arms the speed bonus.
// LOCKSTEP with TOD_LMGS_ARM_MS in _tod_upgrades.gsc — a GSC #define is
// file-local, so the value genuinely lives in two places. Change both.
#define TOD_LMGS_ARM_MS     800    // 1000 -> 800 (user 2026-09-01: "Full steam should work at 0.8s instead of 1s")

#namespace tod_uniques;

function init()
{
	callback::on_spawned( &on_player_spawned );
}

// self = player. One watcher pair per player for the whole game (the latch
// survives respawns; the threads end on disconnect only).
function on_player_spawned()
{
	if ( IS_TRUE( self.tod_uniq_watch_on ) )
		return;
	self.tod_uniq_watch_on = true;
	self thread fire_streak_watch();
	self thread sprint_watch();
}

// self = player
function fire_streak_watch()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self.tod_fire_streak = 0;
	self.tod_fire_last_ms = 0;
	for ( ;; )
	{
		self waittill( "weapon_fired", w );
		now = GetTime();
		if ( ( now - self.tod_fire_last_ms ) > TOD_STREAK_GAP_MS )
			self.tod_fire_streak = 0;
		self.tod_fire_streak++;
		self.tod_fire_last_ms = now;

		// ---- DEV PROBE: DOES weapon_fired FIRE PER BULLET ON THE MINIGUN? ----
		// (v15 item 4. tod_dev-gated; ships silent.)
		//
		// OVERDRIVE's ONLY input is this notify, and the Death Machine is the
		// map's only fireType "Minigun" — every other weapon is Full Auto, Melee
		// or Single. If the engine raises this once per TRIGGER PULL rather than
		// once per BULLET on that fire type, the streak never climbs, OVERDRIVE
		// pays ZERO, and no percentage buff can fix it. The header above asserts
		// per-bullet ("every bullet of an automatic, loop-fire included") but
		// cites no source, and it was written when OVERDRIVE lived on the MP7 —
		// a Full Auto SMG — so it is evidence about the MP7 and nothing else.
		//
		// This is the "symptom is an absence" shape: buffing a dead input looks
		// exactly like the buff failing. MEASURE FIRST.
		//
		// HOW TO READ IT: hold the trigger on the Death Machine for ~2 seconds.
		//   streak climbing 10, 20, 30...  -> per BULLET. The notify is fine and
		//                                     OVERDRIVE just needs bigger numbers.
		//   streak stuck at 1 or 2         -> per TRIGGER PULL. OVERDRIVE is dead
		//                                     on this gun and needs a new input
		//                                     (an ammoInClip delta watcher), not
		//                                     a bigger percentage.
		// Every 10th shot only — a minigun at full rate would flood the console
		// and the flood itself would be unreadable.
		if ( IS_TRUE( level.tod_dev ) && ( self.tod_fire_streak % 10 ) == 0 )
		{
			wn = "?";
			if ( isdefined( w ) && isdefined( w.name ) )
				wn = w.name;
			tod_quiet_print( "fire: " + wn + " streak=" + self.tod_fire_streak );
		}
	}
}

// self = player
function sprint_watch()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self.tod_sprint_end_ms = 0;
	self.tod_sprint_seen_ms = 0;
	// LMG SPRINT / "FULL STEAM" (domain 42, v15 item 24) — the sustained-sprint
	// latch. tod_lmgs_since_ms is the time the CURRENT unbroken sprint began (0
	// = not sprinting); tod_lmgs_hot is the boolean the move-speed owner reads.
	self.tod_lmgs_since_ms = 0;
	self.tod_lmgs_hot = false;
	was = false;
	for ( ;; )
	{
		wait TOD_SPRINT_POLL;
		s = self IsSprinting();
		if ( s )
			self.tod_sprint_seen_ms = GetTime();
		if ( was && !s )
			self.tod_sprint_end_ms = GetTime();

		// ---- FULL STEAM latch ------------------------------------------------
		// Arms after TOD_LMGS_ARM_MS of UNBROKEN sprint and disarms the instant
		// sprint drops. Deliberately keyed on IsSprinting alone, NOT on a
		// velocity floor: the card the user asked for pays "run max speed",
		// and IsSprinting is the engine's own answer to that. It also means the
		// heavy loses the boost on a corner or a strafe — which is the drawback
		// that makes a +0.216 flat bonus (v16.8: ladder x TOD_LMGS_MULT) fair on the slowest class.
		//
		// ⚠️ KNOWN AND ACCEPTED: BO3 breaks sprint when the movement input goes
		// off-axis, so a heavy who strafes mid-run drops FULL STEAM and restarts
		// the 0.8 s clock. That is engine behaviour with no script lever — the
		// whole sprint API surface is AllowSprint / IsSprinting /
		// SetSprintDuration / SetSprintCooldown / SetClientPlayerSprintTime /
		// SprintButtonPressed / SprintUpRequired, and none of it touches the
		// direction cone. If this ever feels bad, tune TOD_LMGS_ARM_MS.
		hot_was = IS_TRUE( self.tod_lmgs_hot );
		if ( s )
		{
			if ( self.tod_lmgs_since_ms == 0 )
				self.tod_lmgs_since_ms = GetTime();

			// TAKING DAMAGE BREAKS THE RUN (v16, user 2026-09-01: "for the full
			// steam if you take damage it stops your boosted speed as well").
			// Restarting the clock rather than just clearing `hot` is what makes
			// it a real interruption: a hit costs you the boost AND the full
			// 0.8s wind-up again, so the heavy has to disengage and re-commit.
			//
			// NO NEW DAMAGE HOOK IS NEEDED, and that is why this is three lines.
			// tod_last_dmg_ms already exists for RECOVERY and is stamped by TWO
			// independent lanes in _tod_upgrades.gsc — the engine's own "damage"
			// notify plus a health-DROP poll as backup — and both threads start
			// unconditionally for every player, not just RECOVERY holders. It
			// also already filters FRIENDLY FIRE, so a teammate's splash or your
			// own PhD dive will not rob you of the boost, which matches what
			// stock's regen does and is almost certainly what the user means by
			// "take damage".
			//
			// A PLAIN FIELD READ, deliberately: this module imports no tod module
			// (see the header) and must not start now. Reading a field another
			// module owns costs nothing and keeps the no-cycle rule intact.
			//
			// The comparison is exactly "damage landed AFTER this sprint began" —
			// tod_lmgs_since_ms is stamped when the sprint starts, so a hit taken
			// before it can never match.
			if ( isdefined( self.tod_last_dmg_ms ) && self.tod_last_dmg_ms > self.tod_lmgs_since_ms )
				self.tod_lmgs_since_ms = GetTime();

			self.tod_lmgs_hot = ( ( GetTime() - self.tod_lmgs_since_ms ) >= TOD_LMGS_ARM_MS );
		}
		else
		{
			self.tod_lmgs_since_ms = 0;
			self.tod_lmgs_hot = false;
		}
		// EDGE-TRIGGERED, never every tick: apply_move_speed is a SetMoveSpeedScale
		// call and this loop runs at 20 Hz on every player in the match.
		// Through the level pointer, never a #using — this module imports no tod
		// module on purpose (see the header), which is what lets _tod_upgrades
		// read these fields without a cycle.
		if ( hot_was != IS_TRUE( self.tod_lmgs_hot ) )
		{
			if ( isdefined( level.tod_apply_speed_fn ) )
				self [[ level.tod_apply_speed_fn ]]();
			// v16: the blue screen wash + the trigger sound, on the SAME edge so the
			// feedback and the speed can never disagree about whether it is hot.
			if ( isdefined( level.tod_lmgs_fx_fn ) )
				self [[ level.tod_lmgs_fx_fn ]]( IS_TRUE( self.tod_lmgs_hot ) );
		}

		was = s;
	}
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
