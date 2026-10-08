// =============================================================================
// _tod_hoop.csc — THE CLIENT SEES THE FLIGHT (v19.18d, docs/147)
//
// A launched ragdoll is CLIENT physics: two server probes on 2026-09-16 read
// nothing of it (origin static, no corpse entity), and a client cannot notify
// the server. So the server scores a COMPUTED arc (_tod_corpse_cleanup::hoop_arc)
// and this module is the ruler it is calibrated with: the server sets the
// actor clientfield tod_hoop_watch to 1 at the launch, the client samples the
// body's origin every TOD_HOOP_C_TICK for TOD_HOOP_C_SECS and prints
//   [TOD_HOOP_C] SAMPLE ent=.. n=.. org=..          every TOD_HOOP_C_EVERY ticks
//   [TOD_HOOP_C] FLIGHT ent=.. from=.. apex=.. land=.. dist=.. in_box=..
// beside the server's [TOD_HOOP] ARC line for the same entity number.
// Diagnostics only: nothing here pays, plays or draws. The box is LOCKSTEP
// with GENERATED tod_breather_data::base_hoop_lo/_hi (tools/test_baseball_bat.js
// asserts the six numbers) because a .csc cannot #using a server module.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace tod_hoop;

#define TOD_HOOP_C_LOG    0      // 0 = SHIP (v19.22): this module is a DIAGNOSTIC and watch_cb returns immediately, so a shipped fling costs the client nothing. 1 = calibrating (docs/147).
#define TOD_HOOP_C_SECS   3.0    // watch this long
#define TOD_HOOP_C_TICK   0.05
#define TOD_HOOP_C_EVERY  5      // a SAMPLE line every this many ticks (0.25 s)
#define TOD_HOOP_C_SLOP 24     // = TOD_HOOP_SLOP on the server
// LOCKSTEP: base_hoop_lo/_hi in _tod_breather_data.gsc
#define TOD_HOOP_C_X1   -48
#define TOD_HOOP_C_X2    48
#define TOD_HOOP_C_Y1  -272
#define TOD_HOOP_C_Y2  -192
#define TOD_HOOP_C_Z1   200
#define TOD_HOOP_C_Z2   296

REGISTER_SYSTEM( "tod_hoop", &__init__, undefined )

function __init__()
{
	// MUST match _tod_corpse_cleanup.gsc EXACTLY. Not zero-on-new-ent: a body
	// that is already flying when a client joins still gets its log.
	clientfield::register( "actor", "tod_hoop_watch", VERSION_SHIP, 1, "int", &watch_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

// self = the flung zombie, on this client.
function watch_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	// v19.22 SHIP GATE: the whole module is diagnostics. With TOD_HOOP_C_LOG 0 no watcher is
	// started at all — a flung body costs every client exactly one ignored clientfield write,
	// not a 60-tick sampling thread. The field stays registered (both VMs, lockstep) so the
	// shapes never diverge; only the work is gated.
	if ( !TOD_HOOP_C_LOG )
		return;
	if ( !isdefined( newVal ) || newVal == 0 )
		return;
	self thread flight_watch( localClientNum );
}

function in_box( p )
{
	return ( p[ 0 ] >= TOD_HOOP_C_X1 - TOD_HOOP_C_SLOP && p[ 0 ] <= TOD_HOOP_C_X2 + TOD_HOOP_C_SLOP
	      && p[ 1 ] >= TOD_HOOP_C_Y1 - TOD_HOOP_C_SLOP && p[ 1 ] <= TOD_HOOP_C_Y2 + TOD_HOOP_C_SLOP
	      && p[ 2 ] >= TOD_HOOP_C_Z1 - TOD_HOOP_C_SLOP && p[ 2 ] <= TOD_HOOP_C_Z2 + TOD_HOOP_C_SLOP );
}

// self = the flung zombie. Ends by itself when the entity goes away.
function flight_watch( localClientNum )
{
	self endon( "entityshutdown" );
	ent = self GetEntityNumber();
	p0 = self.origin;
	apex = p0[ 2 ];
	far = 0;
	inbox = false;
	last = p0;
	n = 0;
	ticks = int( TOD_HOOP_C_SECS / TOD_HOOP_C_TICK );
	while ( n < ticks )
	{
		p = self.origin;
		last = p;
		if ( p[ 2 ] > apex )
			apex = p[ 2 ];
		d = Distance2D( p, p0 );
		if ( d > far )
			far = d;
		if ( !inbox && in_box( p ) )
		{
			inbox = true;
			hoop_c_log( "BASKET ent=" + ent + " n=" + n + " org=" + p );
		}
		n++;
		if ( ( n % TOD_HOOP_C_EVERY ) == 0 )
			hoop_c_log( "SAMPLE ent=" + ent + " n=" + n + " org=" + p );
		wait TOD_HOOP_C_TICK;
	}
	hoop_c_log( "FLIGHT ent=" + ent + " from=" + p0 + " apex=" + apex + " land=" + last + " dist=" + int( far ) + " in_box=" + inbox );
}

function hoop_c_log( msg )
{
	if ( !TOD_HOOP_C_LOG ) return;
	line = "[TOD_HOOP_C] " + msg;
	/#
	PrintLn( line );
	#/
}
