#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\compass;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_utility.gsh;

#using scripts\zm\_load;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_spawner;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_usermap;

#namespace slow_util;

//IS_UTIL

REGISTER_SYSTEM_EX( "zombie_slow_util", &init, &main, undefined )

//auto executed first
function init()
{
	zm_spawner::register_zombie_death_event_callback(&zombie_death_reset);
}

//auto executed second
function main()
{
	
}

function calculate_slow()
{
	speed = 1;

	foreach(factor in self.slows)
	{
		speed *= factor;
	}

	self ASMSetAnimationRate(speed);
	//IPrintLnBold("ZM SPEED SET TO: " + speed);
}

//self is a zombie
//duration optional (will last forever if left undefined)
function add_slow(slow_factor,duration,id="base")
{
	if(!isdefined(self.slows))
	{
		self.slows = [];
	}

	self.slows[id] = slow_factor;

	notify_string = id + "_slow_updated";
	self notify(notify_string);

	self calculate_slow();

	self thread wait_remove_slow(id,duration);
}

function private wait_remove_slow(id,duration)
{
	if(!isdefined(duration))
	{
		return;
	}

	self endon("death");
	notify_string = id + "_slow_updated";
	self endon(notify_string);

	wait duration;

	self.slows[id] = undefined;

	self calculate_slow();
}

//self is a zombie
function remove_slow(id)
{
	if(!isdefined(self.slows))
	{
		return;
	}

	notify_string = id + "_slow_updated";
	self notify(notify_string);

	self.slows[id] = undefined;

	self calculate_slow();
}

function zombie_death_reset(attacker)
{
	self.slows = [];

    self ASMSetAnimationRate(1);
}