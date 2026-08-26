// =============================================================================
// *** RETIRED 2026-08-24 — THIS MODULE IS NOT IN THE BUILD. ***
//
// User: "we need to remove chain lunge from the game. It doesnt work" — the
// second time it was reported broken (see the REWRITTEN note below, which was
// the first). Unlinked rather than deleted: the scripts/ tree is untracked
// beyond the initial commit, so a delete here is unrecoverable, and the input /
// steering / landing loop is the only working reference for driving a player
// through the air on this map.
//
// WHAT WAS UNWIRED (all four are required to bring it back):
//   * zone_source/zm_tower_of_doom.zone — the scriptparsetree line
//   * _tod_main.gsc                     — the #using + tod_lunge::init()
//   * _tod_upgrades.gsc                 — the #using, add_domain( "lunge" ),
//                                         the reset_gun_state line, and the
//                                         on_class_gun_kill hook
//   * ui/.../tod_upgrade.lua            — CARD_SLUG[22] + DETAIL[22] (the
//                                         DOMAIN[22] row is still there, inert)
// The three i_tod_card_chain_lunge_* zone lines were dropped too; the PNGs are
// still in source_data.
//
// tod_classes::melee_dmg() was this module's ONLY caller and is now unconsumed —
// see the note there before it drifts.
// =============================================================================
// _tod_lunge.gsc — CHAIN LUNGE, the SLASHER's mobility upgrade (user
// 2026-08-22: "knife again right after a kill and you lunge fast onto another
// zombie, chainable indefinitely"). REWRITTEN 2026-08-22 after the first cut
// never fired in play (user: "the chain lunge doesn't work").
//
// HOW IT PLAYS
//   A knife kill opens a LUNGE WINDOW. Swing again inside the window with a
//   zombie in front of you and in reach -> you are launched onto it and the
//   blade lands on arrival (a real MOD_MELEE hit with the knife, so DAMAGE /
//   CLEAVE / THOR / LEECH / BOUNTY all fire exactly as for a swing). That kill
//   opens the next window: hold the rhythm and you chain across the horde.
//   Per level the window stays open longer and the reach grows.
//
// WHY THE FIRST CUT NEVER FIRED (three independent faults, all fixed here):
//   1. INPUT. The combat knife is the Slasher's PRIMARY, so "knife again" is
//      the FIRE button (LMB / RT) — the old loop edge-detected ONLY
//      MeleeButtonPressed() (V / R3), which a knife-primary player never uses.
//      Now a swing is any rising edge of AttackButtonPressed() OR
//      MeleeButtonPressed() OR the engine's own IsMeleeing() swing state.
//   2. FLIGHT. One SetVelocity with a 40u z-pop: the player movement code
//      overwrites a grounded player's velocity every frame (map 1's
//      _acc_movement finding — impulses only stick while airborne/sliding),
//      so the lunge died in a frame or two. Now: a real hop (Z_POP 120) AND
//      the horizontal velocity is RE-AIMED at the (moving) target every
//      server tick until arrival — a homing dash, not a single kick.
//   3. LANDING. A fixed 80u arrive test against a single impulse that
//      undershot = no hit, no next window, silent. With steering the arrival
//      is reliable; the momentum is killed on landing so you stop ON the
//      zombie, not past it.
//
// ENGINE LEVERS (all stock-verified):
//   * player SetVelocity(v) — stock knockback idiom (_siegebot.gsc:765).
//   * AttackButtonPressed / MeleeButtonPressed / IsMeleeing / IsOnGround —
//     stock bot + player code (_bot_combat.gsc:371, _bot.gsc:600-601).
//   * DoDamage( dmg, org, attacker, inflictor, "none", "MOD_MELEE", 0, weapon )
//     — the stock 8-arg form (_zm_ai_wasp.gsc:1309): routes through zm's
//     actor-damage chain (upgrade_damage_cb) and stamps damagemod/damageweapon
//     so _tod_upgrades::on_class_gun_kill credits the kill and re-opens the
//     window.
//
// NO #using of _tod_upgrades (it imports us — the KB cycle rule): the level is
// handed in by the caller, and the knife is read off the player's hands.
// =============================================================================

#using scripts\shared\ai\zombie_utility;
#using scripts\shared\callbacks_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
// CLASS TIERS (2026-08-22): the landing hit deals the HELD blade's damage
// (knife 1700/20000, katana 20000/40000, Stormbreaker 40000/80000) —
// _tod_classes imports no tod module, so this is cycle-free.
#using scripts\zm\zm_tower_of_doom\_tod_classes;

#insert scripts\shared\shared.gsh;

#define TOD_LUNGE_WINDOW_BASE_MS 1500   // Lv1 window after a knife kill...
#define TOD_LUNGE_WINDOW_PER_LV  250    // ...+250ms per level (Lv5 = 2.5s)
#define TOD_LUNGE_GRACE_MS       120    // presses in the first 120ms are the killing swing's own press
#define TOD_LUNGE_RANGE_BASE     220    // Lv1 reach (u)...
#define TOD_LUNGE_RANGE_PER_LV   60     // ...+60u per level (Lv5 = 520u)
#define TOD_LUNGE_MAX_DZ         96     // same flight only (a few steps up/down) — never a lunge onto another lap
#define TOD_LUNGE_CONE_DOT       0.5    // target must be within ~60 deg of view (2D)
#define TOD_LUNGE_SPEED_MIN      700    // u/s — short hops still read as a lunge
#define TOD_LUNGE_SPEED_MAX      1400   // u/s — the long reach at Lv5
#define TOD_LUNGE_SPEED_PER_U    4      // speed = remaining distance x this, clamped
#define TOD_LUNGE_Z_POP          120    // leaves the ground (~0.3s airtime @ g800) so the impulse is honoured
#define TOD_LUNGE_ARRIVE_U       90     // "landed" = this close to the target (zombie bbox ~30 + blade reach)
#define TOD_LUNGE_MAX_MS         800    // give up the flight after this (520u @ 1400 = 0.37s; margin for a fleeing target)
#define TOD_LUNGE_TICK           0.05   // steering / input cadence (20 Hz — the acc_weapon_abilities idiom)
// The lunge hit does NOT use this — do_lunge() calls tod_classes::melee_dmg( knife ),
// so it always tracks the held blade's real per-tier/PaP damage and needs no
// maintenance when the ladder moves. Kept only as documentation of that fact.
// (It read 20000 until 2026-08-23, i.e. the old knife-PaP value, which after the
// melee retune would have been more than the Stormbreaker's PaP.)
#define TOD_LUNGE_DMG            2000   // knife BASE — reference only, not the damage dealt
#define TOD_LUNGE_SFX            "tod_warp"   // the scatter's 3D warp whoosh (tod_ui.csv) — the lunge's tell

#namespace tod_lunge;

function init()
{
	callback::on_spawned( &on_player_spawned );
}

// Spawn hygiene: a death mid-lunge must not leave the flags armed.
function on_player_spawned()
{
	self.tod_lunging = false;
	self.tod_lunge_until = 0;
	self.tod_lunge_grace_until = 0;
}

// PUBLIC — called by _tod_upgrades::on_class_gun_kill after every knife kill.
// lvl = the player's CHAIN LUNGE level (0 = not owned -> no-op). self = player.
function open_window( lvl )
{
	if ( !isdefined( lvl ) || lvl <= 0 )
		return;
	if ( !isdefined( self ) || !IsPlayer( self ) || !IsAlive( self ) )
		return;

	now = GetTime();
	self.tod_lunge_lvl = lvl;
	self.tod_lunge_until = now + TOD_LUNGE_WINDOW_BASE_MS + ( lvl - 1 ) * TOD_LUNGE_WINDOW_PER_LV;
	// the press that made THIS kill is still down / still animating — never
	// let it count as the "again"
	self.tod_lunge_grace_until = now + TOD_LUNGE_GRACE_MS;

	if ( !IS_TRUE( self.tod_lunge_loop_on ) )
		self thread input_loop();
}

// A swing is starting: any of the three signals. The knife-primary's swing is
// the FIRE button; the melee key also swings; IsMeleeing is the engine's own
// "in a melee animation" state and catches both regardless of binding.
function swing_down()   // self = player
{
	return ( self AttackButtonPressed() || self MeleeButtonPressed() || self IsMeleeing() );
}

// self = player. Lives only while a window is open; re-threaded by the next
// open_window once it has returned (tod_lunge_loop_on is the latch).
function input_loop()
{
	self endon( "disconnect" );
	self endon( "death" );
	level endon( "end_game" );

	self.tod_lunge_loop_on = true;

	// EDGE detection: the swing that made the kill is very likely still held
	// / still animating when the window opens — wait for a release before we
	// accept a press.
	was_down = self swing_down();

	while ( GetTime() < self.tod_lunge_until )
	{
		down = self swing_down();
		if ( down && !was_down && GetTime() >= self.tod_lunge_grace_until
		  && !IS_TRUE( self.tod_lunging ) && self can_lunge() )
		{
			target = self find_target( self.tod_lunge_lvl );
			if ( isdefined( target ) )
			{
				self.tod_lunge_until = 0;   // the window is CONSUMED by the lunge;
				                            // the landing kill opens the next one
				self thread do_lunge( target );
			}
		}
		was_down = down;
		wait TOD_LUNGE_TICK;
	}

	self.tod_lunge_loop_on = false;
}

// Not while downed, menu-frozen, or during the upgrade world pause (no free
// hits on a frozen horde — the same rule upgrade_damage_cb enforces).
function can_lunge()   // self = player
{
	if ( !IsAlive( self ) || ( self laststand::player_is_in_laststand() ) )
		return false;
	if ( IS_TRUE( self.tod_menu_frozen ) || IS_TRUE( level.tod_upgrade_pause ) )
		return false;
	return true;
}

// Nearest live regular zombie inside the reach, on (roughly) this flight, and
// inside the view cone. Bosses are never lunge targets (their custom
// locomotion + the stun-immune contract in _tod_bosses). self = player.
function find_target( lvl )
{
	range = TOD_LUNGE_RANGE_BASE + ( lvl - 1 ) * TOD_LUNGE_RANGE_PER_LV;
	r2 = range * range;
	eye = self GetEye();
	fwd = AnglesToForward( self GetPlayerAngles() );
	f2 = VectorNormalize( ( fwd[ 0 ], fwd[ 1 ], 0 ) );

	team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
	zombies = GetAITeamArray( team );
	best = undefined;
	best_d2 = r2 + 1;
	foreach ( z in zombies )
	{
		if ( !isdefined( z ) || !isalive( z ) )
			continue;
		if ( IS_TRUE( z.is_boss ) || IS_TRUE( z.acc_is_boss ) || IS_TRUE( z.acc_is_mini_boss ) || IS_TRUE( z.tod_boss_custom_speed ) )
			continue;
		if ( !( z zombie_utility::is_zombie() ) )
			continue;
		if ( IS_TRUE( z.tod_frozen ) )
			continue;
		// same flight only: the spiral stacks laps 384u apart and a lunge is a
		// horizontal dash with a small hop — a target a lap up/down is unreachable
		if ( Abs( z.origin[ 2 ] - self.origin[ 2 ] ) > TOD_LUNGE_MAX_DZ )
			continue;

		d2 = DistanceSquared( self.origin, z.origin );
		if ( d2 > r2 || d2 >= best_d2 )
			continue;

		// in front of the player (2D — pitch must not veto a lunge on stairs)
		to = VectorNormalize( ( z.origin[ 0 ] - eye[ 0 ], z.origin[ 1 ] - eye[ 1 ], 0 ) );
		if ( VectorDot( to, f2 ) < TOD_LUNGE_CONE_DOT )
			continue;

		best = z;
		best_d2 = d2;
	}
	return best;
}

// speed for the remaining gap: every lunge lands in roughly the same beat
function lunge_speed( dist )
{
	sp = dist * TOD_LUNGE_SPEED_PER_U;
	if ( sp < TOD_LUNGE_SPEED_MIN ) sp = TOD_LUNGE_SPEED_MIN;
	if ( sp > TOD_LUNGE_SPEED_MAX ) sp = TOD_LUNGE_SPEED_MAX;
	return sp;
}

// horizontal unit vector from the player to the target's chest
function to_target_h( target )   // self = player
{
	to = ( target.origin + ( 0, 0, 40 ) ) - self.origin;
	h = ( to[ 0 ], to[ 1 ], 0 );
	if ( Length( h ) < 1 )
		return ( 0, 0, 0 );
	return VectorNormalize( h );
}

// The flight + the landing hit. self = player.
function do_lunge( target )
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self.tod_lunging = true;

	knife = self GetCurrentWeapon();   // the class knife (base / PaP / twin) in hand
	PlaySoundAtPosition( TOD_LUNGE_SFX, self.origin );

	// TAKE-OFF: aim the horizontal velocity at the target and HOP. The hop is
	// what makes the engine honour the impulse (a grounded player's velocity
	// is rewritten by the movement code every frame).
	h = self to_target_h( target );
	dist = Distance( self.origin, target.origin );
	self SetVelocity( h * lunge_speed( dist ) + ( 0, 0, TOD_LUNGE_Z_POP ) );

	// FLIGHT: steer every tick — re-aim the horizontal component at wherever the
	// zombie is NOW, keep the engine's vertical component (gravity stays honest),
	// land when within reach. On the ground the re-assert behaves as a dash.
	landed = false;
	t0 = GetTime();
	while ( GetTime() - t0 < TOD_LUNGE_MAX_MS )
	{
		wait TOD_LUNGE_TICK;
		if ( !IsAlive( self ) || !isdefined( target ) || !isalive( target ) )
			break;
		dist = Distance( self.origin, target.origin );
		if ( dist <= TOD_LUNGE_ARRIVE_U )
		{
			landed = true;
			break;
		}
		v = self GetVelocity();
		h = self to_target_h( target );
		sp = lunge_speed( dist );
		self SetVelocity( ( h[ 0 ] * sp, h[ 1 ] * sp, v[ 2 ] ) );
	}

	if ( landed && isdefined( target ) && isalive( target ) && self can_lunge() )
	{
		// stop ON the zombie, not past it (keep only a downward fall)
		v = self GetVelocity();
		vz = ( ( v[ 2 ] < 0 ) ? v[ 2 ] : 0 );
		self SetVelocity( ( 0, 0, vz ) );

		// A real knife hit: MOD_MELEE + the knife as the weapon, so the whole
		// melee stack (DAMAGE, CLEAVE, THOR, LEECH, BOUNTY) and the kill credit
		// (damagemod/damageweapon -> on_class_gun_kill -> next window) behave
		// exactly as for a swing. Stock 8-arg DoDamage (_zm_ai_wasp.gsc:1309).
		// Damage = the held blade's meleeDamage (per tier / PaP form) — the
		// TOD_LUNGE_DMG constant is the fallback for an unknown blade.
		target DoDamage( tod_classes::melee_dmg( knife ), self.origin, self, self, "none", "MOD_MELEE", 0, knife );
	}

	self.tod_lunging = false;
}
