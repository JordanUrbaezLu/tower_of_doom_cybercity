// =============================================================================
// _tod_power_terminal.gsc — THE POWER SWITCH IS NIKOLAI'S GRID TERMINAL (v19.69)
// (user 2026-10-02: "We can add the grid terminal as well to replace the power
// switch").
//
// THE MODEL: his Grid Terminal V5 — `tod_power_terminal`, built by
// tools/fan_props/build_fan_props.py (one LOD; GRID CONTROL / RESTART SEQUENCE
// REQUIRED / HOLD TO INITIATE, its screens and HOLD button cut into a glow map).
// Front = model +X; origin = its BACK plane, horizontal centre, floor.
//
// THE SWITCH ITSELF IS STILL STOCK (_zm_power::electric_switch): the generator
// emits the trigger_use `use_elec_switch`, an invisible handle (stock rolls it and
// plays the flip / turn-on sounds from it, at the HOLD button) and the spark point,
// in place of the lever prefab. This file only hangs the panel; nothing here takes
// part in turning the power on.
//
// THE SPOT: the power hall's east end wall, facing west down the hall, beside the
// song-hunt bear. The anchor is GENERATED (_tod_breather_data.gsc
// base_power_terminal_org/yaw, from gen_tower_map.js POWER_TERM), and the generator
// asserts it clear of the hall walls, the bear and the POWER word above it, and cuts
// its clip ('base power terminal body') from the model's measured size. Move it
// there, never here.
//
// A script_model like every other map-owned prop (the finale's carved-GDT rule:
// script_model + SetModel + a zone `xmodel,` line, never a baked misc_model).
//
// THE POWER-ON ANIMATION (v19.69, user 2026-10-02: "the power has no animation from
// on to off ... Like a knob turning or a switch or power visual going up on the
// screen. The old switch would move the lever when turned on as an animation").
// Two more pieces, built by tools/fan_props/build_power_anim.py (art/fan_props/
// power_anim.json; the panel itself is untouched):
//   THE DIAL  - the HOLD button's segmented bolt ring as its own disc. At the press it
//               spins two turns and stops upright, then lights (tod_power_dial_on). The
//               button plate is level with its rim, so a press-in would open a gap.
//   THE SCREEN - his five display plates again, 0.35 in front of the baked ones, one
//               skin per frame: the screens drop out (dark), the RESTART GRID steps
//               light one by one while the progress bar fills (f1..f3), then ON - the
//               header reads POWER RESTORED, the bar is full, SYNC COMPLETE. Hidden until
//               the press: before it the panel's own baked screen shows.
// The boot starts on the SAME press stock's electric_switch takes (both wait on the
// trigger's "trigger" notify; stock then rolls its invisible handle, sparks, plays
// zmb_switch_flip / zmb_turn_on and sets power_on 0.3 s later). Power turned on any
// other way (a dev harness) shows the ON state directly.
//
// Dev log tag: [TOD_POWER_TERM] (tod_dev) — INIT with the anchor, or FAIL; PIECES;
// BOOT_START / BOOT_FRAME / BOOT_DONE; ON_DIRECT.
// =============================================================================

#using scripts\shared\flag_shared;

#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // GENERATED — base_power_terminal_org/yaw

#insert scripts\shared\shared.gsh;

#precache( "model", "tod_power_terminal" );
#precache( "model", "tod_power_screen" );
#precache( "model", "tod_power_screen_dark" );
#precache( "model", "tod_power_screen_f1" );
#precache( "model", "tod_power_screen_f2" );
#precache( "model", "tod_power_screen_f3" );
#precache( "model", "tod_power_dial" );
#precache( "model", "tod_power_dial_on" );

#namespace tod_power_terminal;

#define TOD_POWER_TERM_MODEL     "tod_power_terminal"
#define TOD_POWER_TERM_REVISION  "fan_props_4"   // = art/fan_props/manifest.json "revision"; logged at INIT
#define TOD_POWER_ANIM_REVISION  "power_anim_1"  // = art/fan_props/power_anim.json "revision"; logged at PIECES

// THE DIAL's centre in the panel's own frame (front +X, origin = its back plane):
// LOCKSTEP art/fan_props/power_anim.json "dial" x / y / z - build_power_anim.py --check
// fails the build if these drift (the disc would spin off the button).
#define TOD_PDIAL_X              10.484
#define TOD_PDIAL_Y              -1.384
#define TOD_PDIAL_Z              28.075
#define TOD_PDIAL_TURNS          720     // two whole turns: it stops upright
#define TOD_PDIAL_SPIN           1.4     // seconds; eases in over the first quarter, out over the last 45%
#define TOD_PBOOT_DARK           0.15    // the screens drop out for this long at the press
#define TOD_PBOOT_STEP           0.35    // then each of the three RESTART GRID steps

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

	org = tod_breather_data::base_power_terminal_org();
	yaw = tod_breather_data::base_power_terminal_yaw();
	m = Spawn( "script_model", org );
	if ( !isdefined( m ) )
	{
		dev_log( "FAIL spawn returned undefined (entity pool full) org=" + org );
		return;   // a missing panel is cosmetic: the switch's trigger is the map's own; never throw
	}
	m.angles = ( 0, yaw, 0 );
	m SetModel( TOD_POWER_TERM_MODEL );
	level.tod_power_terminal = m;
	trigs = GetEntArray( "use_elec_switch", "targetname" );   // 1 until the power is bought (stock deletes it), else 0
	power = ( level flag::exists( "power_on" ) && level flag::get( "power_on" ) );
	dev_log( "INIT rev=" + TOD_POWER_TERM_REVISION + " model=" + TOD_POWER_TERM_MODEL + " org=" + org + " yaw=" + yaw
		+ " ent=" + m GetEntityNumber() + " switch_triggers=" + trigs.size + " power_on=" + power );
	level thread power_anim( org, yaw );
}

// -----------------------------------------------------------------------------
// THE POWER-ON ANIMATION (see the header)
// -----------------------------------------------------------------------------
function power_anim( org, yaw )
{
	level endon( "end_game" );

	angles = ( 0, yaw, 0 );
	dial = Spawn( "script_model", org + RotatePoint( ( TOD_PDIAL_X, TOD_PDIAL_Y, TOD_PDIAL_Z ), angles ) );
	if ( isdefined( dial ) )
	{
		dial.angles = angles;
		dial SetModel( "tod_power_dial" );
	}
	screen = Spawn( "script_model", org );   // the plates are authored in the panel's own frame: same origin, same angles
	if ( isdefined( screen ) )
	{
		screen.angles = angles;
		screen SetModel( "tod_power_screen_dark" );
		screen Hide();                       // until the press: the panel's own baked screen shows
	}
	level.tod_pterm_dial = dial;
	level.tod_pterm_screen = screen;
	dev_log( "PIECES rev=" + TOD_POWER_ANIM_REVISION + " dial_ent=" + ( isdefined( dial ) ? dial GetEntityNumber() : -1 )
		+ " dial_org=" + ( isdefined( dial ) ? dial.origin : ( 0, 0, 0 ) ) + " screen_ent=" + ( isdefined( screen ) ? screen GetEntityNumber() : -1 ) );

	if ( !level flag::exists( "power_on" ) )
	{
		dev_log( "FAIL no power_on flag - the pieces stay in their OFF look" );
		return;
	}
	if ( level flag::get( "power_on" ) )
	{
		show_on( "already_on" );
		return;
	}
	trig = GetEnt( "use_elec_switch", "targetname" );
	if ( isdefined( trig ) )
		level thread boot_on_press( trig );
	else
		dev_log( "BOOT no use_elec_switch trigger - waiting for power_on only" );

	level flag::wait_till( "power_on" );
	WAIT_SERVER_FRAME;                       // the press and the flag can land in one frame: let the boot claim it first
	if ( !IS_TRUE( level.tod_pterm_booting ) && !IS_TRUE( level.tod_pterm_on ) )
		show_on( "power_on_without_the_press" );
}

// Waits on the stock switch's own trigger, beside stock's electric_switch (one notify,
// two listeners). Runs on LEVEL, not the trigger: stock deletes the trigger once the
// power is on, and a thread owned by it would die with it mid-boot.
function boot_on_press( trig )
{
	level endon( "end_game" );
	trig endon( "death" );
	trig waittill( "trigger", who );
	level thread boot( who );
}

function boot( who )
{
	level endon( "end_game" );
	if ( IS_TRUE( level.tod_pterm_booting ) || IS_TRUE( level.tod_pterm_on ) )
		return;
	level.tod_pterm_booting = true;
	t0 = GetTime();
	dial = level.tod_pterm_dial;
	screen = level.tod_pterm_screen;
	by = "?";
	if ( isdefined( who ) && IsPlayer( who ) )
		by = who.name;
	dev_log( "BOOT_START by=" + by + " dial=" + isdefined( dial ) + " screen=" + isdefined( screen ) );
	if ( isdefined( dial ) )
		dial RotateRoll( TOD_PDIAL_TURNS, TOD_PDIAL_SPIN, TOD_PDIAL_SPIN * 0.25, TOD_PDIAL_SPIN * 0.45 );
	frames = array( "tod_power_screen_dark", "tod_power_screen_f1", "tod_power_screen_f2", "tod_power_screen_f3" );
	holds = array( TOD_PBOOT_DARK, TOD_PBOOT_STEP, TOD_PBOOT_STEP, TOD_PBOOT_STEP );
	for ( i = 0; i < frames.size; i++ )
	{
		if ( isdefined( screen ) )
		{
			screen SetModel( frames[ i ] );
			screen Show();
		}
		dev_log( "BOOT_FRAME " + frames[ i ] + " at_ms=" + ( GetTime() - t0 ) );
		wait holds[ i ];
	}
	if ( isdefined( screen ) )
		screen SetModel( "tod_power_screen" );   // the base model = ON
	dev_log( "BOOT_FRAME tod_power_screen (on) at_ms=" + ( GetTime() - t0 ) );
	if ( isdefined( dial ) )
	{
		left = TOD_PDIAL_SPIN - ( GetTime() - t0 ) / 1000.0;
		if ( left > 0 )
			wait left;                       // the spin's own end, upright
		dial SetModel( "tod_power_dial_on" );
	}
	level.tod_pterm_on = true;
	level.tod_pterm_booting = false;
	dev_log( "BOOT_DONE ms=" + ( GetTime() - t0 ) + " dial_roll=" + ( isdefined( dial ) ? dial.angles[ 2 ] : 0 ) );
}

function show_on( reason )
{
	level.tod_pterm_on = true;
	if ( isdefined( level.tod_pterm_screen ) )
	{
		level.tod_pterm_screen SetModel( "tod_power_screen" );
		level.tod_pterm_screen Show();
	}
	if ( isdefined( level.tod_pterm_dial ) )
		level.tod_pterm_dial SetModel( "tod_power_dial_on" );
	dev_log( "ON_DIRECT reason=" + reason );
}

function dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_POWER_TERM] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
