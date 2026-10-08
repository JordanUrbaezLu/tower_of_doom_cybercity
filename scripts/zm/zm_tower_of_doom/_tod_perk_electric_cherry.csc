// =============================================================================
// _tod_perk_electric_cherry.csc — DEATH PERCEPTION, client half (v13.19).
// LINEAGE FILENAME KEPT to pair with the .gsc (see its header doctrine — the
// zone/radiant/specialty wiring reference the cherry name and renaming buys
// nothing a player can see). PORTED from the sibling map's shipped module
// (tower_of_doom_II_hellbound _tod_perk_death_perception.csc, HELLBOUND v2):
// registers the SAME two clientfields as the .gsc, with the drawing callbacks.
//
// The outline is stock machinery: duplicate_render's "player_keyline"
// offscreen filter (registered by stock _zm.csc:212, material
// mc/hud_keyline_zm_player, DR_CULL_NEVER — draws through walls; the material
// ships with the filter registration, no zone line needed). We set its
// "keyline_active" flag per enemy, per pulse, gated on LOCAL ownership —
// only the holder's machine outlines the enemies.
//
// v19.72 (2026-10-03, user: "Can death perception be buffed to all enemies not
// just zombies?"). The server pulse now pings every elite too (Panzer, Warden
// King, spire Wardens, Rogue Protector, hellhound, Reaver — the .gsc header).
// Two client changes ride with it:
//   1. AN OUTLINE CLEARS WHEN ITS ENEMY DIES (dp_death_watch). The flag is only
//      ever written by a ping, and nothing pings the dead, so whatever the last
//      ping set stayed on the body. A dead Protector / hound / Reaver stays an
//      Actor entity for its corpse linger (5 s, memory pending-hound-actor-leak)
//      and would have glowed through walls like a live one. IsAlive on a client
//      actor is stock's own idiom (_zm_perk_widows_wine.csc, zombie_death.csc).
//   2. SPLIT-SCREEN: ANY LOCAL OWNER LIGHTS THE OUTLINES (dp_any_local_owner).
//      duplicate_render state is per ENTITY, not per screen — apply_filter calls
//      addduplicaterenderoption with no localClientNum, and _update_dr_filters
//      kills the previous update on every call. So the per-screen answer the
//      hellbound port computed was decided by whichever local client's callback
//      ran LAST: player 2 owning the perk lit both screens, player 1 owning it
//      lit neither. Ownership is still recorded per local client (the guard in
//      dp_owner_cb is the 2026-08-30 lobby-leak fix and stays); only the
//      decision reads them together. One local client = exactly the old rule.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define DP_REV          "all_enemies_1"   // v19.72 - the [TOD_DP_C] INIT marker
#define DP_DEATH_POLL   0.25              // seconds between IsAlive checks on an outlined enemy
#define DP_LOG_FIRST    3                 // horde ON / CLEAR_DEATH lines printed before going quiet...
#define DP_LOG_EVERY    100               // ...then one in every DP_LOG_EVERY (elites always print)

#namespace tod_perk_electric_cherry;

REGISTER_SYSTEM( "tod_perk_electric_cherry", &__init__, undefined )

function __init__()
{
	clientfield::register( "toplayer", "tod_dp_owner", VERSION_SHIP, 1, "int", &dp_owner_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor",    "tod_dp_ping",  VERSION_SHIP, 1, "counter", &dp_ping_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	dp_log( "INIT rev=" + DP_REV );
}

// self = the player whose field changed — NOT necessarily the local player.
// Keyed by localClientNum (hellbound review fix): a shared boolean leaked the
// outlines to the second screen in splitscreen. (v19.72: the keying stays, but
// see the header - the draw decision reads every local owner together, because
// the outline itself is per entity.)
//
// THE LOCAL GUARD IS LOAD-BEARING (2026-08-30, 3-player live report: one
// player bought Death Perception and EVERY player could see the horde through
// walls). The hellbound comment this ported claimed "toplayer fires only on
// the owning machine" — that holds for a remote client in the common case,
// but NOT universally: the host's client VM processes every player's
// playerstate, and a spectated player's toplayer fields are delivered to
// whoever is viewing through them (that is how spectate mirrors the owner's
// personal HUD). Either path fires this callback with self = SOMEBODY ELSE
// and, ungated, latched this machine's ownership gate to true — and nothing
// ever fired a matching 0 for the local player, so the outlines stayed on
// for the rest of the match. Stock's own pattern for exactly this
// (_gadget_armor.csc:37): accept the value only when self IS the local
// player. Cost: a dead player spectating the DP owner no longer inherits the
// outlines mid-spectate — correct, the perk is personal.
function dp_owner_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( self != GetLocalPlayer( localClientNum ) )
		return;
	if ( !isdefined( level.tod_dp_local ) )
		level.tod_dp_local = [];
	was = IS_TRUE( level.tod_dp_local[ localClientNum ] );
	now = ( isdefined( newVal ) && newVal > 0 );
	level.tod_dp_local[ localClientNum ] = now;
	if ( was != now )
		dp_log( "OWNER lc=" + localClientNum + " on=" + now );
}

// True while any local client on THIS machine owns the perk. A local client
// that has left (split-screen guest dropping out) no longer has a local player,
// so its stale entry cannot keep the outlines on for the one still playing.
function dp_any_local_owner()
{
	if ( !isdefined( level.tod_dp_local ) )
		return false;
	foreach ( lcn, owned in level.tod_dp_local )
	{
		if ( IS_TRUE( owned ) && isdefined( GetLocalPlayer( lcn ) ) )
			return true;
	}
	return false;
}

// self = the enemy actor. Fires on EVERY pulse increment, on every client;
// applies or clears the keyline against the local gate — which is what makes
// buy/loss/late-spawn all self-heal within one pulse. A dead actor is never
// lit (v19.72), and the first time an enemy IS lit it gets one watcher that
// clears the outline when it dies.
function dp_ping_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	on = ( dp_any_local_owner() && IsAlive( self ) );
	self duplicate_render::set_dr_flag( "keyline_active", on );
	self duplicate_render::update_dr_filters( localClientNum );
	if ( on && !IS_TRUE( self.tod_dp_watching ) )
	{
		self.tod_dp_watching = true;
		dp_note( self, localClientNum, "ON", undefined );
		self thread dp_death_watch( localClientNum );
	}
}

// self = an outlined enemy. One per entity (the outline is per entity, see the
// header). Ends with the entity; on death it clears the keyline that the last
// ping left on. A perk loss in between is the pings' job, not this one's - this
// only ever turns an outline OFF, so it can never light anything.
function dp_death_watch( localClientNum )
{
	self endon( "entityshutdown" );

	watched_from = GetRealTime();
	while ( IsAlive( self ) )
		wait DP_DEATH_POLL;

	self.tod_dp_watching = undefined;
	self duplicate_render::set_dr_flag( "keyline_active", false );
	self duplicate_render::update_dr_filters( localClientNum );
	dp_note( self, localClientNum, "CLEAR_DEATH", GetRealTime() - watched_from );
}

// Bounded evidence for a playtest: every elite prints its ON and its
// CLEAR_DEATH (a few dozen a match); the horde prints its first DP_LOG_FIRST of
// each and then one in every DP_LOG_EVERY, with a running count.
function dp_note( ent, localClientNum, what, ms )
{
	arch = "unknown";
	if ( isdefined( ent.archetype ) )
		arch = ent.archetype;
	n = undefined;
	if ( arch == "zombie" )
	{
		if ( !isdefined( level.tod_dp_horde_notes ) )
			level.tod_dp_horde_notes = [];
		if ( !isdefined( level.tod_dp_horde_notes[ what ] ) )
			level.tod_dp_horde_notes[ what ] = 0;
		level.tod_dp_horde_notes[ what ] = level.tod_dp_horde_notes[ what ] + 1;
		n = level.tod_dp_horde_notes[ what ];
		if ( n > DP_LOG_FIRST && ( n % DP_LOG_EVERY ) != 0 )
			return;
	}
	msg = what + " lc=" + localClientNum + " arch=" + arch + " ent=" + ent GetEntityNumber();
	if ( isdefined( n ) )
		msg = msg + " n=" + n;
	if ( isdefined( ms ) )
		msg = msg + " watched_ms=" + ms;
	dp_log( msg );
}

// State changes only; prints in developer runs (the user's launcher) only.
function dp_log( msg )
{
	line = "[TOD_DP_C] rt=" + GetRealTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
