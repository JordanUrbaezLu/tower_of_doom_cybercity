// =============================================================================
// _tod_runandgun.gsc — RUN AND GUN, the SKIRMISHER's ammo upgrade (user
// 2026-08-22: "if you shoot while you run you take up less bullets — 3 levels";
// v16.50, user 2026-09-02: "make run and gun 5 tiers. 16% 28% 38% 46% 52%").
//
// HOW IT PLAYS
//   While you are ON THE MOVE (running at speed or sprinting — not standing,
//   not creeping in ADS) every shot has a chance to cost no ammo: the round
//   is put straight back in the mag the instant it fires.
//   Lv1 16% / Lv2 28% / Lv3 38% / Lv4 46% / Lv5 52% — a STAGE TABLE (steps
//   12/10/8/6, diminishing), not a per-level rate; read rng_pct(). Was
//   20/35/50 over 3 levels until v16.50. Standing still pays full price. Pairs with
//   SPRINT FIRE (domain 21) — sprint-firing is the purest form of "run".
//
// THE DAMAGE HALF LIVES ELSEWHERE (v14.11, user 2026-08-30: "Run and gun
// should increase damage while running too. At the same rates"): moving shots
// also hit +16/28/38/46/52% harder, applied in _tod_upgrades::unique_damage_mult.
// It CANNOT live here (that module never imports us — the KB cycle rule), so
// the numbers and the movement test are LOCKSTEP DUPLICATES: this file's
// TOD_RNG_PCT_L1..L5 / MIN_SPEED and is_running() must always agree with
// _tod_upgrades' TOD_UPG_RNG_DMG_L1..L5 / MIN_SPEED and its inline moving
// check, or the card's two halves trigger on different definitions of
// "moving". Change one file, change the other (and DETAIL[23] in the Lua).
//
// ENGINE LEVERS
//   * `self waittill( "weapon_fired", weapon )` — the engine notifies the
//     player once per shot (every bullet of an automatic), carrying the weapon
//     object. No polling, no fire-rate assumptions.
//   * GetVelocity() (2D speed) + IsSprinting() decide "running".
//   * GetWeaponAmmoClip / SetWeaponAmmoClip refund into the CURRENT mag,
//     capped at weapon.clipSize — so a MAG SIZE twin's bigger clip is honoured
//     and nothing ever overflows.
//
// Domain id 23 in _tod_upgrade_ui::domain_id + tod_upgrade.lua DOMAIN (ids
// are APPEND-ONLY; 22 is CHAIN LUNGE). This module imports _tod_upgrades for
// get_level (upgrades never imports us — the KB cycle rule).
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#using scripts\zm\zm_tower_of_doom\_tod_upgrades;   // get_level

#insert scripts\shared\shared.gsh;

#define TOD_RNG_DOMAIN        "runandgun"
// THE LADDER (v16.50): % of moving shots that are free, by level. LOCKSTEP
// with TOD_UPG_RNG_DMG_L1..L5 in _tod_upgrades.gsc (x0.01) and DETAIL[23] in
// tod_upgrade.lua. Domain max 5 in add_domain — a 6th level would read L5.
#define TOD_RNG_PCT_L1        16
#define TOD_RNG_PCT_L2        28
#define TOD_RNG_PCT_L3        38
#define TOD_RNG_PCT_L4        46
#define TOD_RNG_PCT_L5        52
#define TOD_RNG_MIN_SPEED     120    // u/s 2D: faster than an ADS creep, slower than a run (base run ~190)

#namespace tod_runandgun;

function init()
{
	callback::on_spawned( &on_player_spawned );
}

// self = player. One watcher per player for the whole game (the latch
// survives respawns; the thread itself ends on disconnect only).
function on_player_spawned()
{
	if ( IS_TRUE( self.tod_rng_watch_on ) )
		return;
	self.tod_rng_watch_on = true;
	self thread shot_watch();
}

// self = player
function shot_watch()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( "weapon_fired", w );

		lvl = tod_upgrades::get_level( self, TOD_RNG_DOMAIN );
		if ( lvl <= 0 )
			continue;
		if ( !IsAlive( self ) || self laststand::player_is_in_laststand() )
			continue;
		if ( !isdefined( w ) )
			w = self GetCurrentWeapon();
		if ( !isdefined( w ) || w == level.weaponNone )
			continue;
		// ANY weapon you are holding (user 2026-08-23: widen the upgrades to the
		// secondary). Was class-gun-only, with the pistol and the wonder weapon
		// paying full price — but RUN AND GUN is an AMMO-ECONOMY card, and an
		// ammo card that switches off exactly when you are dry on the class gun
		// and have drawn the sidearm is off at the only moment it was wanted.
		// The refund below already targets the weapon that FIRED, so opening
		// this needs no other change.
		if ( !( self is_running() ) )
			continue;

		pct = rng_pct( lvl );
		// DARK UPGRADE (v17.10): 52% -> 100% (was 77, user 2026-09-05). One table
		// feeds BOTH halves of this domain (free shots and the damage bonus), so
		// the step lands on both by construction -- which is what the card
		// promises. LOCKSTEP: TOD_DARK_RNG_ADD 0.48 in _tod_upgrades.gsc.
		if ( tod_upgrades::has_dark( self, TOD_RNG_DOMAIN ) )
			pct += 48;
		if ( RandomInt( 100 ) >= pct )
			continue;

		// the shot is free: put the round back in the mag (never past its size)
		clip = self GetWeaponAmmoClip( w );
		cap  = w.clipSize;
		if ( isdefined( cap ) && cap > 0 && clip < cap )
			self SetWeaponAmmoClip( w, clip + 1 );
	}
}

// The stage table. Clamped at both ends so a level past the domain max (or a
// stale 0) can never index off the ladder.
function rng_pct( lvl )
{
	if ( lvl <= 1 ) return TOD_RNG_PCT_L1;
	if ( lvl == 2 ) return TOD_RNG_PCT_L2;
	if ( lvl == 3 ) return TOD_RNG_PCT_L3;
	if ( lvl == 4 ) return TOD_RNG_PCT_L4;
	return TOD_RNG_PCT_L5;
}

// "Running" = sprinting, or moving at run speed on the ground plane.
function is_running()   // self = player
{
	if ( self IsSprinting() )
		return true;
	v = self GetVelocity();
	return ( ( v[ 0 ] * v[ 0 ] + v[ 1 ] * v[ 1 ] ) >= TOD_RNG_MIN_SPEED * TOD_RNG_MIN_SPEED );
}
