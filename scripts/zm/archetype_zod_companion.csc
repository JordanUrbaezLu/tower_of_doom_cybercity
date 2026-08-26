#using scripts\shared\ai\systems\fx_character;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "client_fx", "zombie/fx_robot_helper_revive_player_zod_zmb" );
#precache( "client_fx", "destruct/fx_dest_robot_head_sparks" );
#precache( "client_fx", "destruct/fx_dest_robot_body_sparks" );

#namespace zodcompanionclientutils;

REGISTER_SYSTEM_EX( "zm_zod_companion", &__init__, undefined, undefined )

function __init__()
{
	clientfield::register( "allplayers", "being_robot_revived", VERSION_SHIP, 1, "int", &play_revival_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	ai::add_archetype_spawn_function( "zod_companion", &zodcompanionspawnsetup );
	level._effect[ "fx_dest_robot_head_sparks" ] = "destruct/fx_dest_robot_head_sparks";
	level._effect[ "fx_dest_robot_body_sparks" ] = "destruct/fx_dest_robot_body_sparks";
	level._effect[ "companion_revive_effect" ] = "zombie/fx_robot_helper_revive_player_zod_zmb";
	// ai::add_archetype_spawn_function( "robot", &zodcompanionspawnsetup );
}

function private zodcompanionspawnsetup( localClientNum )
{
	entity = self;
	GibClientUtils::AddGibCallback( localClientNum, entity, 8, &zodcompanionheadgibfx );
	GibClientUtils::AddGibCallback( localClientNum, entity, 8, &_gibCallback );
	GibClientUtils::AddGibCallback( localClientNum, entity, 16, &_gibCallback );
	GibClientUtils::AddGibCallback( localClientNum, entity, 32, &_gibCallback );
	GibClientUtils::AddGibCallback( localClientNum, entity, 128, &_gibCallback );
	GibClientUtils::AddGibCallback( localClientNum, entity, 256, &_gibCallback );
	FxClientUtils::PlayFxBundle( localClientNum, entity, entity.fxdef );
}

function zodcompanionheadgibfx( localClientNum, entity, gibFlag )
{
	if ( !isDefined( entity ) || !entity isAi() || !isAlive( entity ) )
		return;
	
	if ( isDefined( entity.mindcontrolheadfx ) )
	{
		stopFx( localClientNum, entity.mindcontrolheadfx );
		entity.mindcontrolheadfx = undefined;
	}
	entity.headgibfx = playFXOnTag( localClientNum, level._effect[ "fx_dest_robot_head_sparks" ], entity, "j_neck" );
	playSound( 0, "prj_bullet_impact_robot_headshot", entity.origin );
}

function zodcompaniondamagedfx( localClientNum, entity )
{
	if ( !isDefined( entity ) || !entity isAi() || !isAlive( entity ) )
		return;
	
	entity.damagedfx = playFXOnTag( localClientNum, level._effect["fx_dest_robot_body_sparks"], entity, "j_spine4" );
}

function zodcompanionclearfx( localClientNum, entity )
{
	if ( !isDefined( entity ) || !entity isAi() )
		return;
	
}

function private _gibCallback( localClientNum, entity, gibFlag )
{
	if ( !isDefined( entity ) || !entity isAi() )
		return;
	
	switch ( gibFlag )
	{
		case 8:
			break;
		case 16:
			break;
		case 32:
			break;
		case 128:
			break;
		case 256:
			break;
		
	}
}

function play_revival_fx( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( isDefined( self.robot_revival_fx ) && oldVal == 1 && newVal == 0 )
		stopFx( localClientNum, self.robot_revival_fx );
	
	if ( newVal === 1 )
	{
		self playSound( 0, "evt_civil_protector_revive_plr" );
		self.robot_revival_fx = playFXOnTag( localClientNum, level._effect[ "companion_revive_effect" ], self, "j_spineupper" );
	}
}

