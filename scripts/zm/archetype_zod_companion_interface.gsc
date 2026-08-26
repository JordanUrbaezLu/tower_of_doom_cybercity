#using scripts\shared\ai\systems\ai_interface;
#using scripts\zm\archetype_zod_companion;

#namespace zodcompanioninterface;

function registerzodcompanioninterfaceattributes()
{
	ai::RegisterMatchedInterface( "zod_companion", "sprint", 0, array( 1, 0 ) );
}

