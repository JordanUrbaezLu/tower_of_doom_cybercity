#using scripts\codescripts\struct;

#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_powerups;

#insert scripts\zm\_zm_powerups.gsh;
#insert scripts\zm\_zm_utility.gsh;

#insert scripts\zm\logical\powerups\_zm_powerup_infiniteammo.gsh;

#namespace zm_powerup_infiniteammo;

REGISTER_SYSTEM( "zm_powerup_infiniteammo", &init, undefined )

//*****************************************************************************
// MAIN
//*****************************************************************************
	
function init()
{
	zm_powerups::include_zombie_powerup( "infiniteammo" );
	zm_powerups::add_zombie_powerup( "infiniteammo", INFINITEAMMO_POWERUP_CLIENTFIELD );
}
