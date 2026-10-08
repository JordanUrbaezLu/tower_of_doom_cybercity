// =============================================================================
// _tod_base_sign.gsc — THE CYBERCITY SIGN on the tower wall over the spawn (v19.69)
// (user 2026-10-02: "Add the Tower of Doom Cybercity sign part of tower wall where
// players spawn at").
//
// THE MODEL: Nikolai's neon TOWER OF DOOM / CYBERCITY sign from his Meshy pack,
// REBUILT AS A CLEAN RELIEF (v19.69, user 2026-10-02: "The sign looks a little janky
// ... It almost looks meshed") — `tod_cybercity_sign2`, built by
// tools/fan_props/build_sign_relief.py from his full-detail sign rendered straight on:
// 60K triangles, one 4096 front-projected colour sheet, flat side colours, no crinkle
// normal map. The first cut (`tod_cybercity_sign`, build_fan_props.py: his mesh
// decimated to 12K on his own UV islands) stays defined in source_data/tod_fan_props.gdt:
// the ROLLBACK is these three defines + precaches and the zone's xmodel lines.
// Front = model +X; origin = its BACK plane, horizontal centre, bottom edge.
//
// POWER (user 2026-10-02: "can we give the sign an on and off state and turning power
// on lights it up?"): it hangs DARK (`_off`: the neon dimmed to unlit glass, no glow)
// until stock sets power_on, then a neon start — two stutters, a dim catch (`_dim`, a
// third of the glow), the full light. All three are skinOverride twins of ONE mesh, so
// every step is one SetModel. Power turned on before the sign spawns = ON, no flicker.
//
// THE SPOT: the core's WEST face — the tower wall the spawn band stands beside
// (the eight initial spawns are x -462..-498 on the west band), lit by the spawn's
// own warm light, centred on the W spine's lit line, above the base ammo chest.
// The anchor is GENERATED (_tod_breather_data.gsc base_sign_org/yaw, from
// gen_tower_map.js BASE_SIGN), and the generator asserts it clear of lap 2's W
// flight overhead, the chest underneath and the face's corners, from the model's
// measured size. Move it there, never here.
//
// A script_model like every other map-owned prop (the finale's carved-GDT rule:
// script_model + SetModel + a zone `xmodel,` line, never a baked misc_model). No
// collision: it hangs 100 units up the wall, above any head.
// =============================================================================

#using scripts\shared\flag_shared;

#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // GENERATED — base_sign_org/yaw

#insert scripts\shared\shared.gsh;

#precache( "model", "tod_cybercity_sign2" );
#precache( "model", "tod_cybercity_sign2_off" );
#precache( "model", "tod_cybercity_sign2_dim" );

#namespace tod_base_sign;

#define TOD_SIGN_MODEL     "tod_cybercity_sign2"       // ON
#define TOD_SIGN_MODEL_OFF "tod_cybercity_sign2_off"   // power off: the neon dark
#define TOD_SIGN_MODEL_DIM "tod_cybercity_sign2_dim"   // the flicker's half step
#define TOD_SIGN_REVISION  "sign_relief_3"   // = art/fan_props/sign_relief.json "revision"; logged at INIT
#define TOD_SIGN_POWER_LAG 0.4               // the current reaches the sign a beat after the switch

function init()
{
	level thread place();
}

function place()
{
	level endon( "end_game" );

	// Like every scripted fixture: the wall is there from frame one, but spawning
	// props before the blackscreen races the stock world init.
	level flag::wait_till( "initial_blackscreen_passed" );

	org = tod_breather_data::base_sign_org();
	yaw = tod_breather_data::base_sign_yaw();
	m = Spawn( "script_model", org );
	if ( !isdefined( m ) )
	{
		dev_log( "FAIL spawn returned undefined (entity pool full) org=" + org );
		return;   // a missing sign is cosmetic; never throw
	}
	m.angles = ( 0, yaw, 0 );
	power = ( level flag::exists( "power_on" ) && level flag::get( "power_on" ) );
	if ( power )
		m SetModel( TOD_SIGN_MODEL );
	else
		m SetModel( TOD_SIGN_MODEL_OFF );
	level.tod_base_sign = m;
	dev_log( "INIT rev=" + TOD_SIGN_REVISION + " model=" + TOD_SIGN_MODEL + " org=" + org + " yaw=" + yaw + " ent=" + m GetEntityNumber() + " power_on=" + power );
	if ( !power )
		m thread light_on_power();
}

// Dark until power_on, then a neon start: each step is a model and how long it holds;
// the last is ON for good. A deleted sign (the spire teardown) ends the thread.
function light_on_power()
{
	self endon( "death" );
	level endon( "end_game" );

	if ( !level flag::exists( "power_on" ) )
	{
		dev_log( "FAIL no power_on flag - the sign stays dark" );
		return;
	}
	level flag::wait_till( "power_on" );
	t0 = GetTime();
	wait TOD_SIGN_POWER_LAG;
	steps = array( TOD_SIGN_MODEL_DIM, TOD_SIGN_MODEL_OFF, TOD_SIGN_MODEL, TOD_SIGN_MODEL_OFF,
	               TOD_SIGN_MODEL_DIM, TOD_SIGN_MODEL_OFF, TOD_SIGN_MODEL_DIM, TOD_SIGN_MODEL );
	holds = array( 0.1, 0.15, 0.05, 0.35, 0.1, 0.1, 0.25, 0 );
	for ( i = 0; i < steps.size; i++ )
	{
		self SetModel( steps[ i ] );
		if ( holds[ i ] > 0 )
			wait holds[ i ];
	}
	dev_log( "LIT power_on_to_lit_ms=" + ( GetTime() - t0 ) + " steps=" + steps.size + " model=" + TOD_SIGN_MODEL );
}

function dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_SIGN] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
