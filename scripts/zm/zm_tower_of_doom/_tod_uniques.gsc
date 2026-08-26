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
//
// Imports NO tod module (so _tod_upgrades can read these fields without a
// cycle); init from _tod_main, scriptparsetree line in the zone.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#define TOD_STREAK_GAP_MS   500    // a longer pause between shots ends the streak
#define TOD_SPRINT_POLL     0.05   // 20 Hz sprint-edge poll

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
	}
}

// self = player
function sprint_watch()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self.tod_sprint_end_ms = 0;
	self.tod_sprint_seen_ms = 0;
	was = false;
	for ( ;; )
	{
		wait TOD_SPRINT_POLL;
		s = self IsSprinting();
		if ( s )
			self.tod_sprint_seen_ms = GetTime();
		if ( was && !s )
			self.tod_sprint_end_ms = GetTime();
		was = s;
	}
}
