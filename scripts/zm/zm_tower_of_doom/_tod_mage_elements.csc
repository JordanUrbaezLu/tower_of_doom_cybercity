// Persistent first-person staff auras follow the CLIENT weapon change, like
// stock _zm_weap_riotshield / _zm_weap_raygun_mark3. Replicated elements can
// arrive after the viewmodel changes. Never use them to choose the aura.
// KillFX removes existing particles too; StopFX lets the old aura linger.

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// v18.93: the Origins tip glows at 125% (tools/bo6_extraction/build_bo6_ice_fx.py, user:
// "enhance the frost, flame and electricity fx on each staff ... like 25% more").
#precache( "client_fx", "tod/bo6/fx_tod_staff_glow_elec" );
#precache( "client_fx", "tod/bo6/fx_tod_staff_glow_fire" );
#precache( "client_fx", "tod/bo6/fx_tod_staff_glow_ice" );
#precache( "client_fx", "tod/mage/fx_staff_lightning_chain_clean" );
// 2026-10-01: ARCHMAGE ON THE WORLD (tools/gen_archmage_fx.py; see arch_form_cb).
#precache( "client_fx", "tod/mage/fx_archmage_circle" );
#precache( "client_fx", "tod/mage/fx_archmage_inner" );
#precache( "client_fx", "tod/mage/fx_archmage_column" );
#precache( "client_fx", "tod/mage/fx_archmage_column_1p" );
#precache( "client_fx", "tod/mage/fx_archmage_light" );
#precache( "client_fx", "tod/mage/fx_archmage_light_1p" );
#precache( "client_fx", "tod/mage/fx_archmage_rise" );
#precache( "client_fx", "tod/mage/fx_archmage_rise_1p" );
#precache( "client_fx", "tod/mage/fx_archmage_rise_light" );
#precache( "client_fx", "tod/mage/fx_archmage_fade" );

#define TOD_STAFF_GLOW_FIELD   "tod_staff_glow"   // LOCKSTEP with _tod_mage_elements.gsc
#define TOD_STAFF_GLOW_TAG     "tag_upg"          // the Origins staff view model's tip tag (tod_staff_view: tag_weapon / tag_upg / tag_antennea_le4)
#define TOD_STAFF_GLOW_TAG_ICE "tag_bo6_glow"     // v18.89: the BO6 ice assembly (tod_bo6_ice_vm) has no tag_upg; this socket sits in its tip crystal

#define TOD_ARCH_FX_FIELD     "tod_arch_form"   // LOCKSTEP with _tod_mage_elements.gsc (gen_archmage_fx.py --check)
#define TOD_ARCH_FX_ON        1                 // the form is running
#define TOD_ARCH_FX_FADE      2                 // its timer ran out: the collapse plays
#define TOD_ARCH_CIRCLE_SPIN  22                // deg/s: the rainbow ring and its runes
#define TOD_ARCH_INNER_SPIN   -35               // deg/s: the gold inner ring turns the other way
#define TOD_ARCH_COLUMN_SPIN  140               // deg/s: the column's motes spiral because their host turns
#define TOD_ARCH_HOST_PITCH   -90               // hosts face UP: flat sprites lie on the floor (memory flat-ground-fx-rules)

#namespace tod_mage_elements;

REGISTER_SYSTEM( "tod_mage_elements", &__init__, undefined )

function __init__()
{
	level._effect[ "tod_staff_glow_1" ] = "tod/bo6/fx_tod_staff_glow_elec";
	level._effect[ "tod_staff_glow_2" ] = "tod/bo6/fx_tod_staff_glow_fire";
	level._effect[ "tod_staff_glow_3" ] = "tod/bo6/fx_tod_staff_glow_ice";
	level._effect[ "tod_mage_chain" ] = "tod/mage/fx_staff_lightning_chain_clean";
	level._effect[ "tod_arch_circle" ] = "tod/mage/fx_archmage_circle";
	level._effect[ "tod_arch_inner" ] = "tod/mage/fx_archmage_inner";
	level._effect[ "tod_arch_column" ] = "tod/mage/fx_archmage_column";
	level._effect[ "tod_arch_column_1p" ] = "tod/mage/fx_archmage_column_1p";
	level._effect[ "tod_arch_light" ] = "tod/mage/fx_archmage_light";
	level._effect[ "tod_arch_light_1p" ] = "tod/mage/fx_archmage_light_1p";
	level._effect[ "tod_arch_rise" ] = "tod/mage/fx_archmage_rise";
	level._effect[ "tod_arch_rise_1p" ] = "tod/mage/fx_archmage_rise_1p";
	level._effect[ "tod_arch_rise_light" ] = "tod/mage/fx_archmage_rise_light";
	level._effect[ "tod_arch_fade" ] = "tod/mage/fx_archmage_fade";

	// Preserve the server/client field layout. Late snapshots must not
	// restart an old aura; the local weapon owns presentation now.
	callback::on_spawned( &glow_on_spawned );
	clientfield::register( "toplayer", TOD_STAFF_GLOW_FIELD, VERSION_SHIP, 2, "int", undefined, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "tod_mage_chain_fx", VERSION_SHIP, 2, "int", &chain_fx_cb, !CF_HOST_ONLY, CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "allplayers", TOD_ARCH_FX_FIELD, VERSION_SHIP, 2, "int", &arch_form_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

// ---- ARCHMAGE ON THE WORLD (2026-10-01; user: "Lets start with archmage. High
// quality viusals") ----------------------------------------------------------------
// Before this the form was invisible to everyone but the Mage. The server only
// says ON / FADE / OFF on tod_arch_form; everything visual happens here, per local
// client, because only the client can:
//  * follow the Mage every rendered frame (three client hosts at their origin);
//  * turn those hosts - the rainbow ring one way, the gold inner ring the other,
//    the column fast enough that its motes spiral (the effects carry no rotation
//    of their own; tools/gen_archmage_fx.py says why);
//  * KillFX: every particle goes the instant the form does (a server host's
//    long-lived particles would stay behind where the form ended);
//  * give the Mage's OWN view a quieter version - the ring, the runes and a dim
//    light at the feet, motes that die below eye height, no column, no fountain,
//    no flash light: nothing rises across the crosshair (the 1P rule, v18.91/93).
// The rise and fade one-shots play at the feet with the ground's up as the
// effect's forward, the way dom.csc draws its zones.
function arch_form_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( newVal == TOD_ARCH_FX_ON )
	{
		// A state the entity shutdown already tore down is dead, not live: start again.
		if ( isdefined( self.tod_arch_fx ) && isdefined( self.tod_arch_fx[ localClientNum ] ) && !IS_TRUE( self.tod_arch_fx[ localClientNum ].dead ) )
			return;
		// Only a real activation bursts - not a late join or a re-entering entity.
		fresh = ( !bInitialSnap && !bNewEnt && oldVal != TOD_ARCH_FX_ON );
		self thread arch_fx_start( localClientNum, fresh );
		return;
	}
	self arch_fx_stop( localClientNum, ( newVal == TOD_ARCH_FX_FADE && !bInitialSnap ), "field=" + newVal );
}

function arch_fx_start( localClientNum, fresh )   // self = the Archmage
{
	own = ( self == GetLocalPlayer( localClientNum ) );   // the Mage's own first-person view
	state = SpawnStruct();
	state.fx = [];
	state.hosts = [];
	state.t0 = GetRealTime();
	foreach ( spin in array( TOD_ARCH_CIRCLE_SPIN, TOD_ARCH_INNER_SPIN, TOD_ARCH_COLUMN_SPIN ) )
	{
		h = Spawn( localClientNum, self.origin, "script_model" );
		h SetModel( "tag_origin" );
		h.angles = ( TOD_ARCH_HOST_PITCH, 0, 0 );
		h.tod_spin = spin;
		state.hosts[ state.hosts.size ] = h;
	}
	if ( !isdefined( self.tod_arch_fx ) )
		self.tod_arch_fx = [];
	self.tod_arch_fx[ localClientNum ] = state;
	self thread arch_fx_shutdown_watch( localClientNum, state );
	if ( fresh )
	{
		org = self.origin;
		PlayFx( localClientNum, level._effect[ ( own ? "tod_arch_rise_1p" : "tod_arch_rise" ) ], org, ( 0, 0, 1 ), ( 1, 0, 0 ) );
		if ( !own )
			PlayFx( localClientNum, level._effect[ "tod_arch_rise_light" ], org, ( 0, 0, 1 ), ( 1, 0, 0 ) );
	}
	WAIT_CLIENT_FRAME;   // attach on the hosts' second frame
	if ( IS_TRUE( state.dead ) || !isdefined( self ) )
		return;
	circle = state.hosts[ 0 ];
	state.fx[ state.fx.size ] = PlayFXOnTag( localClientNum, level._effect[ "tod_arch_circle" ], circle, "tag_origin" );
	state.fx[ state.fx.size ] = PlayFXOnTag( localClientNum, level._effect[ ( own ? "tod_arch_light_1p" : "tod_arch_light" ) ], circle, "tag_origin" );
	state.fx[ state.fx.size ] = PlayFXOnTag( localClientNum, level._effect[ "tod_arch_inner" ], state.hosts[ 1 ], "tag_origin" );
	state.fx[ state.fx.size ] = PlayFXOnTag( localClientNum, level._effect[ ( own ? "tod_arch_column_1p" : "tod_arch_column" ) ], state.hosts[ 2 ], "tag_origin" );
	arch_fx_log( "START lc=" + localClientNum + " player=" + self GetEntityNumber() + " view=" + ( own ? "own" : "team" )
		+ " burst=" + fresh + " fx=" + state.fx.size + " hosts=" + state.hosts.size );
	self arch_fx_follow( state );
}

// Every rendered frame: the hosts stand on the Mage and turn at their own rates
// (the stock client-model turn, _character_customization.csc).
function arch_fx_follow( state )   // self = the Archmage
{
	self endon( "entityshutdown" );
	while ( !IS_TRUE( state.dead ) && isdefined( self ) )
	{
		secs = ( GetRealTime() - state.t0 ) / 1000.0;
		org = self.origin;
		foreach ( h in state.hosts )
		{
			if ( !isdefined( h ) )
				continue;
			h.origin = org;
			h.angles = ( TOD_ARCH_HOST_PITCH, AbsAngleClamp360( h.tod_spin * secs ), 0 );
		}
		WAIT_CLIENT_FRAME;
	}
}

function arch_fx_stop( localClientNum, fade, why )   // self = the Archmage
{
	if ( !isdefined( self.tod_arch_fx ) || !isdefined( self.tod_arch_fx[ localClientNum ] ) )
		return;
	state = self.tod_arch_fx[ localClientNum ];
	self.tod_arch_fx[ localClientNum ] = undefined;
	self notify( "tod_arch_fx_end_" + localClientNum );
	fade_org = undefined;
	if ( fade )
		fade_org = self.origin;
	arch_fx_teardown( localClientNum, state, fade_org, why + " player=" + self GetEntityNumber() );
}

// The entity can go before the field does (a disconnect): tear down from the state
// alone, never from the departing entity.
function arch_fx_shutdown_watch( localClientNum, state )   // self = the Archmage
{
	self endon( "tod_arch_fx_end_" + localClientNum );
	self waittill( "entityshutdown" );
	arch_fx_teardown( localClientNum, state, undefined, "entityshutdown" );
}

function arch_fx_teardown( localClientNum, state, fade_org, why )
{
	if ( IS_TRUE( state.dead ) )
		return;
	state.dead = true;
	foreach ( id in state.fx )
	{
		if ( isdefined( id ) )
			KillFX( localClientNum, id );   // KillFX, not StopFX: the particles go too
	}
	if ( isdefined( fade_org ) )
		PlayFx( localClientNum, level._effect[ "tod_arch_fade" ], fade_org, ( 0, 0, 1 ), ( 1, 0, 0 ) );
	foreach ( h in state.hosts )
	{
		if ( isdefined( h ) )
			h Delete();
	}
	arch_fx_log( "STOP lc=" + localClientNum + " " + why + " collapse=" + isdefined( fade_org ) + " fx=" + state.fx.size );
}

// State changes only (a few lines per form); prints in developer runs only.
function arch_fx_log( msg )
{
	line = "[TOD_ARCH_FX_C] rt=" + GetRealTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

function chain_fx_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self notify( "tod_mage_chain_refresh_" + localClientNum );
	self chain_fx_stop( localClientNum );
	if ( newVal <= 0 || !IsAlive( self ) )
		return;
	if ( !isdefined( self.tod_chain_fx ) )
		self.tod_chain_fx = [];
	self.tod_chain_fx[ localClientNum ] = PlayFXOnTag( localClientNum, level._effect[ "tod_mage_chain" ], self, "j_spineupper" );
	self thread chain_fx_cleanup( localClientNum );
}

function chain_fx_cleanup( localClientNum )
{
	self endon( "tod_mage_chain_refresh_" + localClientNum );
	self util::waittill_any_timeout( 1.5, "death", "entityshutdown" );
	self chain_fx_stop( localClientNum );
}

function chain_fx_stop( localClientNum )
{
	if ( isdefined( self.tod_chain_fx ) && isdefined( self.tod_chain_fx[ localClientNum ] ) )
	{
		KillFX( localClientNum, self.tod_chain_fx[ localClientNum ] );
		self.tod_chain_fx[ localClientNum ] = undefined;
	}
}

function glow_on_spawned( localClientNum )
{
	if ( self != GetLocalPlayer( localClientNum ) )
		return;

	self notify( "tod_staff_glow_restart" );
	self glow_stop( localClientNum );
	self thread glow_watch( localClientNum );
	self thread glow_cleanup( localClientNum );
}

function glow_watch( localClientNum )
{
	self endon( "tod_staff_glow_restart" );
	self endon( "tod_staff_glow_stop" );
	self endon( "death" );
	self endon( "disconnect" );
	self endon( "entityshutdown" );

	self glow_replace( localClientNum, GetCurrentWeapon( localClientNum ) );
	for ( ;; )
	{
		self waittill( "weapon_change", weapon );
		// Replace even for q0 <-> q1 of the same element: the viewmodel changes.
		// No settle timer or delayed callback can restore the previous aura.
		self glow_replace( localClientNum, weapon );
	}
}

function glow_cleanup( localClientNum )
{
	self endon( "tod_staff_glow_restart" );
	self util::waittill_any( "death", "disconnect", "entityshutdown" );
	self notify( "tod_staff_glow_stop" );
	self glow_stop( localClientNum );
}

function glow_stop( localClientNum )
{
	if ( isdefined( self.tod_staff_glow_fx ) )
	{
		KillFX( localClientNum, self.tod_staff_glow_fx );
		self.tod_staff_glow_fx = undefined;
	}
}

function glow_replace( localClientNum, weapon )
{
	self glow_stop( localClientNum );
	if ( self != GetLocalPlayer( localClientNum ) )
		return;
	val = staff_glow_value( weapon );
	if ( val == 0 )
		return;
	tag = ( ( val == 3 ) ? TOD_STAFF_GLOW_TAG_ICE : TOD_STAFF_GLOW_TAG );
	self.tod_staff_glow_fx = PlayViewmodelFX( localClientNum, level._effect[ "tod_staff_glow_" + val ], tag );
}

// Match the server's staff_element naming, including generated variants.
function staff_glow_value( weapon )
{
	if ( !isdefined( weapon ) || !isdefined( weapon.name ) || !IsSubStr( weapon.name, "tod_staff_" ) )
		return 0;
	if ( IsSubStr( weapon.name, "lightning" ) )
		return 1;
	if ( IsSubStr( weapon.name, "fire" ) )
		return 2;
	if ( IsSubStr( weapon.name, "ice" ) )
		return 3;
	return 0;
}
