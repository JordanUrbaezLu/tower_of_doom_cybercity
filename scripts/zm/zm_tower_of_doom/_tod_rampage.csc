// =============================================================================
// _tod_rampage.csc — RAMPAGE SHOWS ON THE TOWER (2026-10-01)
//
// User: "for the rampage visual lets make the tower show it instead of the
// player. I know the tower has this strip going along the sides" -> the plan
// they signed ("Go"). The strips are the column's four CORE SPINES
// (gen_tower_map.js v16.13 facelift section 7): a 32-wide lit bar down the middle
// of every face, base to crown, in the district's colour. While Rampage is on,
// the strips BURN red-orange - a flickering hot core, a red halo, a wide red
// haze, sparks spitting off - and nothing travels (user 2026-10-02, after the
// first look: "remove the shooting lines and make the visuals on the tower a
// bit stronger. I dont want the shooting visual effects" - the comets and the
// climbing surge are gone). Switching it on flashes every strip at once
// (fx_rampage_flare); switching it off lets them calm (StopFX: the glows that
// are lit fade out where they hang).
//
// WHY HERE, CLIENT-SIDE: the server already tells every player whether Rampage
// is on - the todRampage HUD value (_tod_upgrade_ui.gsc registers it,
// _tod_rampage.gsc pushes it on every flip and every spawn). Reading it costs
// no new network field (a new field is a boot-only-verified change) and no
// server entities; and only the client can run the lit laps AROUND ITS OWN
// PLAYER - TOD_RAMPAGE_BELOW below and TOD_RAMPAGE_ABOVE above - starting and
// stopping them as the player climbs, so the whole 50-lap column never runs at
// once. Nothing runs farther than TOD_RAMPAGE_REACH from the column's axis (the
// Endless Spire and the crown road have no strips).
//
// THE EFFECT FRAME: PlayFx( origin on the face, forward = world UP, up = the
// face's outward normal ) - the way dom.csc lays flat effects, turned onto a
// wall: X climbs the lap, Z stands proud of the face, Y runs across the strip.
// The effects are tools/gen_rampage_fx.py; its --check holds the geometry below
// to gen_tower_map.js and the HUD value's name to _tod_upgrade_ui.gsc.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#precache( "client_fx", "tod/rampage/fx_rampage_spine" );
#precache( "client_fx", "tod/rampage/fx_rampage_flare" );

#define TOD_RAMPAGE_CORE          256    // LOCKSTEP: gen_tower_map.js CORE (the column's half-width)
#define TOD_RAMPAGE_LAP_RISE      384    // LOCKSTEP: gen_tower_map.js LAP_RISE
#define TOD_RAMPAGE_LAPS          50     // LOCKSTEP: gen_tower_map.js LAPS (the strips stop at the capital)
#define TOD_RAMPAGE_PROUD         1      // the effect origin's distance off the face
#define TOD_RAMPAGE_BELOW         3      // lit laps below the player's own
#define TOD_RAMPAGE_ABOVE         6      // ... and above it (2026-10-02: one more - the column reads from farther)
#define TOD_RAMPAGE_REACH         1400   // farther than this from the column's axis: nothing runs
#define TOD_RAMPAGE_FLARE_BATCH   10     // laps flared per client frame on the flip (all 50 in five frames: one flash, not a wave)
#define TOD_RAMPAGE_POLL          0.2

#namespace tod_rampage;

REGISTER_SYSTEM( "tod_rampage", &__init__, undefined )

function __init__()
{
	level._effect[ "tod_rampage_spine" ] = "tod/rampage/fx_rampage_spine";
	level._effect[ "tod_rampage_flare" ] = "tod/rampage/fx_rampage_flare";
	callback::on_localclient_connect( &tower_watch );
}

// The server's own Rampage state, as this player's HUD has it.
function rampage_on( localClientNum )
{
	m = GetUIModel( GetUIModelForController( localClientNum ), "todRampage" );
	if ( !isdefined( m ) )
		return false;
	v = GetUIModelValue( m );
	return ( isdefined( v ) && v > 0 );
}

// The four faces of lap k: the origin on the strip at the lap's foot, and the
// face's outward normal (N, S, E, W).
function face_org( f, k )
{
	z = k * TOD_RAMPAGE_LAP_RISE;
	d = TOD_RAMPAGE_CORE + TOD_RAMPAGE_PROUD;
	switch ( f )
	{
		case 0:  return ( 0, d, z );
		case 1:  return ( 0, 0 - d, z );
		case 2:  return ( d, 0, z );
	}
	return ( 0 - d, 0, z );
}

function face_normal( f )
{
	switch ( f )
	{
		case 0:  return ( 0, 1, 0 );
		case 1:  return ( 0, -1, 0 );
		case 2:  return ( 1, 0, 0 );
	}
	return ( -1, 0, 0 );
}

// The lap this player stands in, or -1 when they are away from the column.
function player_lap( localClientNum )
{
	p = GetLocalPlayer( localClientNum );
	if ( !isdefined( p ) )
		return -1;
	org = p.origin;
	if ( ( org[ 0 ] * org[ 0 ] + org[ 1 ] * org[ 1 ] ) > TOD_RAMPAGE_REACH * TOD_RAMPAGE_REACH )
		return -1;
	lap = int( Floor( org[ 2 ] / TOD_RAMPAGE_LAP_RISE ) );
	if ( lap < 0 )
		lap = 0;
	if ( lap > TOD_RAMPAGE_LAPS - 1 )
		lap = TOD_RAMPAGE_LAPS - 1;
	return lap;
}

function lap_start( localClientNum, k )
{
	ids = [];
	for ( f = 0; f < 4; f++ )
		ids[ ids.size ] = PlayFx( localClientNum, level._effect[ "tod_rampage_spine" ], face_org( f, k ), ( 0, 0, 1 ), face_normal( f ) );
	return ids;
}

// StopFX, not KillFX: the glows already lit fade out where they hang.
function lap_stop( localClientNum, ids )
{
	foreach ( id in ids )
	{
		if ( isdefined( id ) )
			StopFX( localClientNum, id );
	}
}

// One per local client, for the whole match: follow the switch and the player.
function tower_watch( localClientNum )
{
	level notify( "tod_rampage_watch_" + localClientNum );
	level endon( "tod_rampage_watch_" + localClientNum );

	active = [];          // lap -> its four effect ids
	was_on = false;
	first = true;         // the first read is a join or a reload, never a flip: no flare
	shown = -2;
	for ( ;; )
	{
		on = rampage_on( localClientNum );
		lap = player_lap( localClientNum );
		if ( on && !was_on )
		{
			if ( !first && lap >= 0 )
				level thread flare( localClientNum );
			rampage_log( "ON lc=" + localClientNum + " flare=" + ( !first && lap >= 0 ) + " lap=" + lap );
		}
		else if ( !on && was_on )
			rampage_log( "OFF lc=" + localClientNum + " lit=" + active.size );
		was_on = on;
		first = false;

		want = [];
		if ( on && lap >= 0 )
		{
			for ( k = lap - TOD_RAMPAGE_BELOW; k <= lap + TOD_RAMPAGE_ABOVE; k++ )
			{
				if ( k >= 0 && k < TOD_RAMPAGE_LAPS )
					want[ k ] = true;
			}
		}
		foreach ( k in GetArrayKeys( active ) )
		{
			if ( !isdefined( want[ k ] ) )
			{
				lap_stop( localClientNum, active[ k ] );
				active[ k ] = undefined;
			}
		}
		foreach ( k in GetArrayKeys( want ) )
		{
			if ( !isdefined( active[ k ] ) )
				active[ k ] = lap_start( localClientNum, k );
		}
		if ( on && lap != shown )
		{
			rampage_log( "LIT lc=" + localClientNum + " lap=" + lap + " laps=" + active.size );
			shown = lap;
		}
		else if ( !on )
			shown = -2;
		wait TOD_RAMPAGE_POLL;
	}
}

// The flip: every strip on the column flashes bright where it stands - all 50
// laps inside five client frames, so it reads as one flash, not a climb.
function flare( localClientNum )
{
	for ( k = 0; k < TOD_RAMPAGE_LAPS; k++ )
	{
		for ( f = 0; f < 4; f++ )
			PlayFx( localClientNum, level._effect[ "tod_rampage_flare" ], face_org( f, k ), ( 0, 0, 1 ), face_normal( f ) );
		if ( ( k % TOD_RAMPAGE_FLARE_BATCH ) == TOD_RAMPAGE_FLARE_BATCH - 1 )
			WAIT_CLIENT_FRAME;
	}
}

// State changes only; prints in developer runs (the user's launcher) only.
function rampage_log( msg )
{
	line = "[TOD_RAMPAGE_C] rt=" + GetRealTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
