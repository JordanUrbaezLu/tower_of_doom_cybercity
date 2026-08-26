#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace zm_aetherium_hud;

REGISTER_SYSTEM_EX( "zm_aetherium_hud", &__init__, &__main__, undefined )

function set_ui_model_value( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	//  - create model using exact fieldName
	setuimodelvalue( createuimodel( getuimodelforcontroller( localClientNum ), fieldName ), newVal );
}

function __init__()
{
	// Register health clientfield callbacks for each player using world
	// Use com_maxclients to support up to 8 players 
	for( i = 0; i < GetDvarInt( "com_maxclients" ); i++ )
	{
		clientfield::register( "world", "player_health_" + i, VERSION_SHIP, 7, "float", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	}
	
	// Register packed player states clientfield
	clientfield::register( "world", "player_states_packed", VERSION_SHIP, 8, "int", &player_states_callback, 0, 0 );
    
	// Load the Aetherium HUD
	LuiLoad( "ui.uieditor.menus.HUD.AetheriumHud" );
}

function __main__()
{
	// Client-side HUD logic
	// Pre-create player state models
	for( i = 0; i < 4; i++ )
	{
		model = getuimodelforcontroller( 0 );
		if( IsDefined( model ) )
		{
			stateModel = createuimodel( model, "player_state_" + i );
			setuimodelvalue( stateModel, 0 );
		}
	}
}

function player_states_callback( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	// Unpack all 4 player states from the single packed value
	player0_state = ( newval >> 0 ) & 3;  // Extract bits 0-1
	player1_state = ( newval >> 2 ) & 3;  // Extract bits 2-3
	player2_state = ( newval >> 4 ) & 3;  // Extract bits 4-5
	player3_state = ( newval >> 6 ) & 3;  // Extract bits 6-7
	
	// Update UI models for each player
	model = getuimodelforcontroller( localclientnum );
	if( IsDefined( model ) )
	{
		// Player 0
		setuimodelvalue( createuimodel( model, "player_state_0" ), player0_state );
		
		// Player 1
		setuimodelvalue( createuimodel( model, "player_state_1" ), player1_state );
		
		// Player 2
		setuimodelvalue( createuimodel( model, "player_state_2" ), player2_state );
		
		// Player 3
		setuimodelvalue( createuimodel( model, "player_state_3" ), player3_state );
	}
}