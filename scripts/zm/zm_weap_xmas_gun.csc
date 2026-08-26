#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\math_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\duplicaterender.gsh;

#insert scripts\zm\zm_weap_xmas_gun.gsh;


#precache( "client_fx", "xmas_gun/xmas_gun_projectile" );
#precache( "client_fx", "xmas_gun/xmas_gun_zmb_freeze" );

#namespace zm_weap_xmas_gun; 

REGISTER_SYSTEM_EX( "zm_weap_xmas_gun", &__init__, &__main__, undefined )

function __init__()
{
	duplicate_render::set_dr_filter_framebuffer_duplicate("zm_xmas_frz", 98, "zm_xmas_frz", undefined, DR_TYPE_FRAMEBUFFER_DUPLICATE, "mc/mtl_xmas_freeze", DR_CULL_NEVER);

	level._effect["xmas_gun_proj"] = "xmas_gun/xmas_gun_projectile";
	callback::add_weapon_type(XMAS_GUN, &proximity_spawned);
	callback::add_weapon_type(XMAS_GUN_UP, &proximity_spawned);
	clientfield::register("missile", "xmas_gun_proj_stop", VERSION_SHIP, 1, "int", &fx_stop, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
	clientfield::register("actor", "zm_xmas_frz", VERSION_SHIP, 1, "int", &zom_freeze, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT);
	level._effect["xmas_gun_zmb_freeze"] = "xmas_gun/xmas_gun_zmb_freeze";

	level.sleigh_bell_sounds = array( "sleigh_bells_loop_base" , "sleigh_bells_loop_30" , "sleigh_bells_loop_60" );
}

function __main__()
{
	util::register_system("XMASGunSounds", &set_xmas_gun_sounds);
}

function proximity_spawned(localclientnum)
{
	self util::waittill_dobj(localclientnum);

	if(!isdefined(self) || self isgrenadedud())
	{
		return;
	}

	self.fx = PlayFXOnTag(localClientNum, level._effect["xmas_gun_proj"], self, "tag_origin");
}

function fx_stop(localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
	if(isdefined(self.fx))
	{
		DeleteFX(localclientnum, self.fx);
	}
}

function zom_freeze(localClientNum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump)
{
	PlayFXOnTag(localClientNum, level._effect["xmas_gun_zmb_freeze"], self, "j_spine4");

	self duplicate_render::set_dr_flag("zm_xmas_frz", 1);
	self duplicate_render::update_dr_filters(localClientNum);
	self MapShaderConstant(localClientNum, 0, "scriptVector0", 1.0); 

	start_time = self GetClientTime();
	end_time = start_time + int(1 * 1000); //1 = fade_time
	val = 0.0;

	while(isdefined(self) && val < 0.6)
	{
		self MapShaderConstant(localClientNum, 0, "scriptVector0", val);
		val = self lerp(start_time, end_time);
		WAIT_CLIENT_FRAME;
	}
    
	if(isdefined(self))
	{
		//self duplicate_render::set_dr_flag("zm_xmas_frz", 1);
		//self duplicate_render::update_dr_filters(localClientNum);
		self MapShaderConstant(localClientNum, 0, "scriptVector0", 0.6);
	}
}

function private lerp( start_time, end_time )
{
	if((end_time - start_time) <= 0)
		return 1;
	
	now = self GetClientTime();
	frac = float(end_time - now) / float(end_time - start_time);
	frac = 1-frac;

	return math::clamp(frac, 0, 0.6);
}


// [tod] THE SLEIGH-BELL STOP IS BY HANDLE, NOT BY FADE TIME.
// (beta 2026-08-25: "permanent rattle ring sound that didnt go away", ~round 28.)
//
// StopLoopSound HAS DIFFERENT SIGNATURES IN THE TWO VMs, and that is the whole
// bug. SERVER-side it takes a FADE TIME (mechz_spiki.gsc:1755,
// `self.m_claw StopLoopSound(1)`). CLIENT-side it takes the SOUND HANDLE that
// PlayLoopSound returned — stock proves it twice, _hive_gun.csc:120
// `self StopLoopSound( sound )` and mechz.csc:158
// `self stoploopsound( self.sndLoopID )`.
//
// The 2026-08-23 pass called `entity StopLoopSound(fade_time)` with fade_time
// == 3 — handing the integer 3 to a parameter that wants a handle — and the
// handles were being DISCARDED at the PlayLoopSound call anyway. So it stopped
// nothing. Every set of three LOOPING voices ever started stayed alive for the
// rest of the match, merely MUTED: SetLoopState is alias-keyed and only changes
// VOLUME. Once a second pickup started a second generation of voices on the
// same entity the older ones were no longer addressable by alias at all — and
// they ring, forever, at whatever volume they were last set to. Several Gift of
// Death pickups over ~28 rounds is all it takes.
//
// Fix: KEEP the handles, stop BY handle, and never start a generation without
// stopping the previous one first. There is no other way to silence a voice
// from script — the alias mute below is belt-and-braces, not the mechanism.
function private bells_stop( entity, fade_time )
{
	if ( !isdefined( entity ) )
		return;

	// Cheap, and covers any voice the alias does still address — including a
	// generation started before this file grew a handle latch. Callers pass the
	// pack's OWN fade values (3 to ramp, 10000 for immediate); the units are not
	// documented anywhere and this is no place to invent a third one.
	for ( i = 0; i < level.sleigh_bell_sounds.size; i++ )
	{
		entity SetLoopState( level.sleigh_bell_sounds[i], 0, 1, fade_time, fade_time );
	}

	// THIS is the line that actually stops sound.
	if ( isdefined( entity.bellLoopHandles ) )
	{
		for ( i = 0; i < entity.bellLoopHandles.size; i++ )
		{
			entity StopLoopSound( entity.bellLoopHandles[i] );
		}
	}

	entity.bellLoopHandles = undefined;
	entity.bellsPlaying = false;
	entity.last_volume = 0;
}

function set_xmas_gun_sounds(localClientNum, newState, oldState)
{
	newStateArray = StrTok(newState, "|");

	entity_num = Int(newStateArray[0]);
	WAIT_CLIENT_FRAME; //This is needed. Okay then.
	entity = GetEntByNum( localClientNum , entity_num );

	// [tod] A method call on an undefined entity is a script error, and a script
	// error HERE kills the handler — which is exactly how one missed stop turns
	// permanent, because the engine dispatches this system only on a state
	// CHANGE (callbacks_shared.csc::CodeCallback_StateChange) and the old server
	// code re-sent a byte-identical stop string forever, so nothing ever
	// re-delivered it. The server now sends the stop several times with a
	// varying token; this guard is what makes those retries reachable.
	if ( !isdefined( entity ) )
		return;

	volume = Float(newStateArray[1]);
	speed = Int(newStateArray[2]);

	fade_time = 3;

	if(volume == -1)
	{
		bells_stop( entity, fade_time );
		return;
	}

	if(!IS_TRUE(entity.bellsPlaying) && volume > 0)
	{
		// Never stack a second generation on top of a first — the orphaned
		// voices from a stacked start are unaddressable and are the ringing.
		// 10000 = the pack's own "set it now" value, so the mute cannot still be
		// ramping when the new volume is set on the same alias two lines down.
		bells_stop( entity, 10000 );

		handles = [];
		for ( i = 0; i < level.sleigh_bell_sounds.size; i++ )
		{
			h = entity PlayLoopSound( level.sleigh_bell_sounds[i] );
			if ( isdefined( h ) )
			{
				handles[ handles.size ] = h;
			}
			entity SetLoopState( level.sleigh_bell_sounds[i], volume, 1, 10000, 10000 );
		}

		entity.bellLoopHandles = handles;
		entity.bellsPlaying = true;
		entity.last_volume = 0;
		return;
	}

	//Set max rate of decay
	if( isdefined(entity.last_volume) && volume < entity.last_volume )
	{
		//IPrintLnBold("VOLUME PRE ADJUST: " + volume);
		volume = Max( volume , entity.last_volume - 0.015 );
		//IPrintLnBold("VOLUME POST ADJUST: " + volume);
	}

	if(speed == 0)
	{
		entity SetLoopState(level.sleigh_bell_sounds[0], volume, 1, fade_time, fade_time);
		entity SetLoopState(level.sleigh_bell_sounds[1], 0, 1, fade_time, fade_time);
		entity SetLoopState(level.sleigh_bell_sounds[2], 0, 1, fade_time, fade_time);
	}
	else if(speed == 1)
	{
		entity SetLoopState(level.sleigh_bell_sounds[0], 0, 1, fade_time, fade_time);
		entity SetLoopState(level.sleigh_bell_sounds[1], volume, 1, fade_time, fade_time);
		entity SetLoopState(level.sleigh_bell_sounds[2], 0, 1, fade_time, fade_time);
	}
	else if(speed == 2)
	{
		entity SetLoopState(level.sleigh_bell_sounds[0], 0, 1, fade_time, fade_time);
		entity SetLoopState(level.sleigh_bell_sounds[1], 0, 1, fade_time, fade_time);
		entity SetLoopState(level.sleigh_bell_sounds[2], volume, 1, fade_time, fade_time);
	}

	//entity SetLoopState("sleigh_bells_loop", volume, 1, fade_time, fade_time);
	entity.last_volume = volume;
}