// _tod_perk_widows.gsc — WIDOW'S WINE 25% NERF (v17.52, user 2026-09-04:
// "nerf it like 25% overall and that will cascade down to widow phd nades").
//
// WHAT WIDOW'S ACTUALLY IS ON THIS MAP. The grenade deals ZERO health damage:
// stock's zombie damage callback (_zm_perk_widows_wine.gsc:221) catches every
// hit whose damageweapon is the web grenade, webs the zombie and returns TRUE,
// and _zm_spawner.gsc:1926/2055 returns before any damage is applied. So there
// is no damage number to cut. Its strength is CONTROL, on three axes:
//   * the CONTACT AUTO-WEB — every zombie melee on a holder with >0 grenades
//     detonates a free web (the death-preventer; level.perk_damage_override
//     slot, _zm.gsc:5231-5240);
//   * the MELEE WEB — 50% cocoon chance per Widow's-knife hit
//     (WW_MELEE_COCOON_CHANCE, compile-time, unreachable);
//   * the WEB DURATIONS — cocoon 16 s at 0.1 anim rate within 100 u, slow 12 s
//     at 0.7 within 256 u (WIDOWS_WINE_*_DURATION, compile-time).
//
// THE PORT. Map 1 shipped exactly this at 50% (_acc_perks.gsc ww_nerf_install
// + ww_duration_watchdog, user 2026-07-17, play-proven). Stock's numbers are
// #defines a usermap cannot edit, but every lever has a script seam:
//   * the two stock handlers are plain pointers in level.perk_damage_override /
//     level.zombie_damage_callbacks, so ww_install SWAPS them IN PLACE for
//     wrappers that coin-flip before delegating (array order — and so dispatch
//     order against PhD's own override — is preserved). Pointer-compare on
//     function refs is the stock-sanctioned idiom (_zm_perk_widows_wine.gsc:202).
//   * stock's effect threads endon their own extend-notifies and reset state
//     at expiry (:453-464 / :504-515), so a per-AI watchdog force-fires that
//     exact expiry at TOD_WW_*_DURATION instead of stock's.
// Web STRENGTH (the 0.1 / 0.7 rates) and the RADII are untouched: the nerf is
// uptime and proc rate, not identity. The radii are compared inside stock's
// own function; shrinking them means re-implementing the response, and 25%
// does not earn that.
//
// THE CASCADE IS BY CONSTRUCTION. _tod_perk_phd's combo children are real
// Widow's grenades (MagicGrenadeType of level.w_widows_wine_grenade) that run
// through the same stock zombie damage response, so the duration cap applies
// to every web they lay and the contact-proc cut applies to the perk as a
// whole. Nothing in _tod_perk_phd changes. (The combo's NOVA is a PhD knob —
// TOD_PHD_GRENADE_HEALTH_FRAC — and is deliberately not part of this.)
//
// COMPATIBILITY. The watchdog replays stock's expiry cleanup verbatim (anim
// rate 1.0, wrap clientfield 0, both b_widows_wine_* flags false), so
// _tod_zombie_speed's keepalive and _tod_stray re-adopt the zombie exactly as
// after a natural expiry — both key on those flags. The v16.72 PhD glow host
// and the v16.78 child window never see this file.
//
// THE KNOBS. 25% overall: 75% of stock on every axis.
#define TOD_WW_CONTACT_PROC_CHANCE  0.75   // stock 1.0: every melee procs the auto-web
#define TOD_WW_MELEE_PREROLL        0.75   // x stock's internal 0.50 -> net 37.5% melee-web chance
#define TOD_WW_COCOON_DURATION      12.0   // stock WIDOWS_WINE_COCOON_DURATION 16.0
#define TOD_WW_SLOW_DURATION        9.0    // stock WIDOWS_WINE_SLOW_DURATION 12.0

#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_perk_widows_wine;   // pointer refs + delegation targets

#namespace tod_perk_widows;

// Called from zm_tower_of_doom::main() — after every REGISTER_SYSTEM __init__
// (stock's Widow's registration among them) has populated both arrays.
function init()
{
	if ( !isdefined( level.w_widows_wine_grenade ) )
	{
		if ( IS_TRUE( level.tod_dev ) )
			tod_quiet_print( "tod ww nerf: stock widow's wine never registered - skipped" );
		return;
	}

	n_swapped = 0;

	if ( isdefined( level.perk_damage_override ) )
	{
		for ( i = 0; i < level.perk_damage_override.size; i++ )
		{
			if ( level.perk_damage_override[ i ] == &zm_perk_widows_wine::widows_wine_damage_callback )
			{
				level.perk_damage_override[ i ] = &ww_contact_web_wrapper;
				n_swapped++;
			}
		}
	}

	if ( isdefined( level.zombie_damage_callbacks ) )
	{
		for ( i = 0; i < level.zombie_damage_callbacks.size; i++ )
		{
			if ( level.zombie_damage_callbacks[ i ] == &zm_perk_widows_wine::widows_wine_zombie_damage_response )
			{
				level.zombie_damage_callbacks[ i ] = &ww_melee_web_wrapper;
				n_swapped++;
			}
		}
	}

	// Both pointers must have been found — a silent miss here is the nerf
	// half-installed with nothing to say so.
	if ( IS_TRUE( level.tod_dev ) )
		tod_quiet_print( "tod ww nerf: swapped " + n_swapped + "/2 stock handlers" );

	callback::on_ai_spawned( &ww_on_ai_spawned );
}

// self = the damaged PLAYER (level.perk_damage_override slot). Coin-flip gate
// in front of the stock contact auto-web. Signature = the stock dispatch
// (_zm.gsc:5235); a defined return REPLACES iDamage, undefined leaves it alone.
// v18.9 — AN ATTACKER THAT CANNOT BE WEBBED DOES NOT GET TO SPEND THE CHARGE
// (user 2026-09-07: "Dogs dont trigger widows wine ... protectors have the same
// gap as dogs"). Workshop report, CZ 2026-09-06: "dogs are taking all widows
// nades before i can even kill them".
//
// WHY THIS IS NOT A HOUND-ONLY FIX. The contact web is delivered through stock's
// zombie-damage callback lane, and that lane is threaded from
// zm_spawner::enemy_death_detection, which only runs for actors registered
// through a stock SPAWNER. This map SpawnActor's its elites directly, so the
// PANZER, the ROGUE PROTECTOR and the HELLHOUND never carry the lane and can
// never be webbed by anything. The REAVER is the one exception and is
// deliberately NOT in this list: its vendored pack threads enemy_death_detection
// itself, so it webs today and must keep doing so. The ARMORED SPRINTER is a
// promoted horde zombie that came through a spawner, so it keeps the lane too.
//
// WHAT THIS COSTS, said plainly because it is a trade and not a free win: the
// delegated call also burst-webs the ordinary zombies AROUND the player, so
// being hit by one of these three used to buy a panic cocoon of the surrounding
// horde at the price of one grenade. That panic button is gone for them. The
// user's call, twice stated: the charge must not be spent on an attacker the
// perk cannot touch.
//
// Keyed on tod_boss_kind, which every one of these stamps on its spawn frame.
function ww_attacker_unwebbable( e )
{
	if ( !isdefined( e ) || !isdefined( e.tod_boss_kind ) )
		return false;
	return ( e.tod_boss_kind == "hellhound"
	      || e.tod_boss_kind == "panzer"
	      || e.tod_boss_kind == "protector" );
}

function ww_contact_web_wrapper( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
	// Stock rule preserved UNCONDITIONALLY: your own (or a teammate's) web
	// explosion never hurts you.
	if ( isdefined( sWeapon ) && sWeapon == level.w_widows_wine_grenade )
		return 0;

	// v18.9 — see ww_attacker_unwebbable above. Placed BEFORE the proc roll so
	// these three neither spend a grenade nor consume the coin flip; the melee
	// lands exactly as it would with no perk.
	if ( ww_attacker_unwebbable( eAttacker ) )
		return;

	// The nerf: a denied proc means the melee lands like you have no perk,
	// and no grenade is spent.
	if ( RandomFloat( 1.0 ) > TOD_WW_CONTACT_PROC_CHANCE )
		return;

	return self zm_perk_widows_wine::widows_wine_damage_callback( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime );
}

// self = the damaged ZOMBIE (level.zombie_damage_callbacks slot). Pre-roll ONLY
// the melee-web path (stock then rolls its own 50%); web-grenade hits always
// delegate so thrown grenades, contact bursts and the PhD children keep webbing
// everything they catch — their nerf is the duration cap. Returning false =
// web denied, dispatch falls through to normal damage, same as when stock
// declines a hit.
function ww_melee_web_wrapper( str_mod, str_hit_location, v_hit_origin, e_player, n_amount, w_weapon, direction_vec, tagName, modelName, partName, dFlags, inflictor, chargeLevel )
{
	b_web_grenade_hit = isdefined( self.damageweapon ) && self.damageweapon == level.w_widows_wine_grenade;

	if ( !b_web_grenade_hit && IS_EQUAL( str_mod, "MOD_MELEE" ) && RandomFloat( 1.0 ) > TOD_WW_MELEE_PREROLL )
		return false;

	return self zm_perk_widows_wine::widows_wine_zombie_damage_response( str_mod, str_hit_location, v_hit_origin, e_player, n_amount, w_weapon, direction_vec, tagName, modelName, partName, dFlags, inflictor, chargeLevel );
}

// self = a freshly spawned AI (callback::on_ai_spawned).
function ww_on_ai_spawned()
{
	self thread ww_web_apply_listener();
	self thread ww_duration_watchdog();
}

// self = an AI. Stamps the LAST web application: stock re-fires these two
// notifies on EVERY (re-)application as its extend mechanism
// (_zm_perk_widows_wine.gsc:420/473), so a fresh grenade on an already-webbed
// zombie re-arms the shortened clock instead of being eaten by it. (Our own
// forced-expiry notifies land here too — harmless, the flags are already down.)
function ww_web_apply_listener()
{
	self endon( "death" );
	for ( ;; )
	{
		self util::waittill_any( "widows_wine_cocoon", "widows_wine_slow" );
		self.tod_ww_web_applied_ms = GetTime();
	}
}

// self = an AI. Force-expires an active web at TOD_WW_*_DURATION by firing
// stock's OWN extend/expiry notifies (endon-kills the stock effect threads, so
// their full-length timers can never fire later) and replaying stock's exact
// expiry cleanup (_zm_perk_widows_wine.gsc:458-464 / :509-515).
function ww_duration_watchdog()
{
	self endon( "death" );

	for ( ;; )
	{
		wait 0.25;

		if ( !IS_TRUE( self.b_widows_wine_cocoon ) && !IS_TRUE( self.b_widows_wine_slow ) )
			continue;

		// Cocoon outranks slow (a mid-window slow->cocoon upgrade re-fired the
		// cocoon notify, so the listener already restarted the clock).
		cap_sec = ( ( IS_TRUE( self.b_widows_wine_cocoon ) ) ? TOD_WW_COCOON_DURATION : TOD_WW_SLOW_DURATION );

		if ( !isdefined( self.tod_ww_web_applied_ms ) )
			self.tod_ww_web_applied_ms = GetTime();   // flag seen before any notify (belt & braces)

		if ( GetTime() - self.tod_ww_web_applied_ms < int( cap_sec * 1000 ) )
			continue;

		self notify( "widows_wine_cocoon" );
		self notify( "widows_wine_slow" );
		self notify( "widows_wine_cocoon_zombie_score" );   // the webbed point-drip stops at expiry too
		self ASMSetAnimationRate( 1.0 );
		self clientfield::set( "widows_wine_wrapping", 0 );
		self.b_widows_wine_cocoon = false;
		self.b_widows_wine_slow = false;
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
