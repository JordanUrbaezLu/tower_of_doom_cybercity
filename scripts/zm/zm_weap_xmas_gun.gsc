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
#using scripts\zm\_zm_score;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_usermap;
#using scripts\zm\_zm_spawner;

#using scripts\zm\cheese_man\zombie_slow_util;

#using scripts\shared\ai\systems\gib;

#insert scripts\zm\zm_weap_xmas_gun.gsh;

#namespace zm_weap_xmas_gun;

REGISTER_SYSTEM_EX( "zm_weap_xmas_gun", &init, &main, undefined )

//auto executed first
function init()
{
	level.weap_xmas_gun = GetWeapon(XMAS_GUN);
	level.weap_xmas_gun_up = GetWeapon(XMAS_GUN_UP);
	callback::on_connect( &on_player_connect );

	util::registerClientSys("XMASGunSounds");

	if(XMAS_GUN_IN_MYSTERY_BOX)
	{
		zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/xmas_gun_weapon.csv", 1);
	}
	else
	{
		zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/xmas_gun_weapon_no_box.csv", 1);
	}
}

//auto executed second
function main()
{
	zm_spawner::register_zombie_damage_callback(&on_zombie_damage);
	clientfield::register( "missile", "xmas_gun_proj_stop", VERSION_SHIP, 1, "int" );
	clientfield::register( "actor", "zm_xmas_frz", VERSION_SHIP, 1, "int" );

	callback::on_connect( &track_xmas_gun_state );

	//zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/xmas_gun_weapon.csv", 1);
}




function on_player_connect(  )
{
	self endon("disconnect");

	for(;;)
	{
		self waittill("missile_fire", projectile, weapon);
		if(weapon.rootWeapon == level.weap_xmas_gun || weapon.rootWeapon == level.weap_xmas_gun_up)
		{
			projectile thread wait_explode();
		}
	}
}

function wait_explode()
{
	self waittill("death");
	if(!isdefined(self))
	{
		return;
	}
	//IPrintLnBold("EXPLODE");
	self clientfield::set("xmas_gun_proj_stop",1);
}


function on_zombie_damage( mod, hit_location, hit_origin, player, amount, weapon, direction_vec, tagName, modelName, partName, dFlags, inflictor, chargeLevel )
{
	if(!isdefined(weapon))
	{
		return false;
	}

	// [tod 2026-08-20] NEUTRALIZED: the map drives Gift-of-Death damage as a
	// FIXED shots-to-kill model (2 zombie / 10 protector / 30 panzer) via the
	// actor-damage chain (tod_powerups::xmas_fixed_shots_cb + the boss wraps),
	// NOT the pack's hit-count instakill. The pack's own DoDamage(MOD_RIFLE_
	// BULLET) would DOUBLE-apply (the natural explosion is already shaped by
	// our callback) and its add_slow "lasts forever" but the zombie-speed
	// sweep clobbers it in <=1.5s (same fight as the timewarp). So this now
	// only pops the frost SHADER and returns false — natural explosive damage
	// (shaped to hp/2+1 by our callback) stands, plus stock scoring.
	if(weapon.rootWeapon != level.weap_xmas_gun && weapon.rootWeapon != level.weap_xmas_gun_up)
	{
		return false;
	}

	self clientfield::set("zm_xmas_frz",1);   // frost shader pop only — NO slow, NO extra damage
	return false;
}

function check_for_freeze(player,mod,hit_location,weapon)
{
	waittillframeend; //Wait for after damage is applied

	if(self.health <= 0)
	{
		//IPrintLnBold("ZOMBIE DEAD. SKIPPING");
		return;
	}

	self slow_util::add_slow(XMAS_GUN_SLOW_SPEED,undefined,"xmas_frz");

}

/*
function freeze_kill( mod, hit_location, hit_origin, player, amount, weapon, direction_vec, tagName, modelName, partName, dFlags, inflictor, chargeLevel )
{
	self clientfield::set("zm_xmas_frz",1);
	self slow_util::add_slow(0.05,undefined,"xmas_frz");
	wait 2;

	if(!isdefined(self))
	{
		return;
	}

	do_damage = self.health + 100;
	self DoDamage(do_damage, hit_origin, player, inflictor, hit_location, mod, dFlags, weapon);
}*/

function track_xmas_gun_state()
{
	self endon("disconnect");

	WAIT_SERVER_FRAME;
	level flag::wait_till("initial_blackscreen_passed");

	self.bellSoundModel = util::spawn_model( "tag_origin", self GetTagOrigin("tag_weapon_right") );
	self.bellSoundModel EnableLinkTo();
	self.bellSoundModel LinkTo(self,"tag_weapon_right");

	//self.lastHeldXmas = false;

	for(;;)
	{
		// [tod] Losing the emitter would throw on GetEntityNumber() below and kill
		// this thread outright — which leaves the bells running with no code left
		// to stop them. Re-make it instead. A fresh entity number is fine: the
		// deleted one takes its voices with it.
		if ( !isdefined( self.bellSoundModel ) )
		{
			self.bellSoundModel = util::spawn_model( "tag_origin", self GetTagOrigin("tag_weapon_right") );
			if ( isdefined( self.bellSoundModel ) )
			{
				self.bellSoundModel EnableLinkTo();
				self.bellSoundModel LinkTo(self,"tag_weapon_right");
			}
			self.tod_bell_off_sends = 0;
			wait 0.2;
			continue;
		}

		if(!(self GetCurrentWeapon() == level.weap_xmas_gun || self GetCurrentWeapon() == level.weap_xmas_gun_up))
		{
			//if(IS_TRUE(self.lastHeldXmas))
			{
				// [tod] THE STUCK-SLEIGH-BELL FIX (beta report 2026-08-23: "constant
				// ringing and never went away"). The ON state below is BROADCAST to
				// every player (foreach GetPlayers), but this OFF state was sent to
				// SELF ONLY — util_shared's third arg is the RECIPIENT, so every
				// other client started the three LOOPING bell aliases and was never
				// told to stop. Result: once anyone picked up the Gift of Death and
				// lost it, every OTHER player heard sleigh bells at that player's
				// hand for the rest of the match, with no recovery path in script.
				// SOLO WAS ALWAYS CLEAN (GetPlayers() is the holder), which is
				// exactly why this survived testing — it is a CO-OP-ONLY bug.
				// The fix is symmetry: the stop goes wherever the start went.
				//
				// [tod 2026-08-25] AND THE STOP NEEDS RETRIES. This used to re-send
				// a byte-identical string every 0.2s forever, which sounds robust
				// and is the opposite: the engine dispatches a client system only
				// when its state CHANGES (callbacks_shared.csc::CodeCallback_
				// StateChange), so all those repeats collapsed into ONE delivery
				// per ON->OFF transition. If that single delivery landed on a frame
				// where the client could not resolve the emitter, the stop was gone
				// for good. Vary the third field (the client ignores `speed` on a
				// -1) so each of the first few sends is a genuine state change and
				// the client gets several chances — then go quiet, instead of
				// writing an unchanging state O(players^2) times a second for the
				// rest of the match.
				if ( !isdefined( self.tod_bell_off_sends ) )
				{
					self.tod_bell_off_sends = 0;
				}

				if ( self.tod_bell_off_sends < 8 )   // 8 sends over ~1.6s
				{
					string = "" + self.bellSoundModel GetEntityNumber() + "|" + -1 + "|" + self.tod_bell_off_sends + "|";
					foreach ( player in GetPlayers() )
					{
						player util::setClientSysState("XMASGunSounds", string, player);
					}
					self.tod_bell_off_sends++;
				}
				//self.lastHeldXmas = false;
			}
			//WAIT_SERVER_FRAME;
			wait 0.2;
			continue;
		}

		//self.lastHeldXmas = true;

		// Holding again — re-arm the stop retries for the next time it is lost.
		self.tod_bell_off_sends = 0;

		volume = 0;
		speed = 0;
		if(self IsSliding())
		{
			volume = 0.45;
			speed = 2;
		}
		else if(self IsSprinting())
		{
			volume = 0.25;
			speed = 1;
		}
		else if(!self IsOnGround())
		{
			velocity = self GetVelocity()[2];
			velocity = Abs(velocity);
			volume = velocity / 900;
			volume = Max(volume, 0.1);
			speed = 1;
			//IPrintLnBold("JUMPING " + velocity);
		}
		else//!self IsFiring()) //Since firing pushes you back slightly //nvm whatever
		{
			velocity = self GetVelocity();
			velocity = Abs(velocity[0]) + Abs(velocity[1]);
			volume = velocity / 3500;
		}

		//Make the bells jingle when turn the camera quickly
		if(CAMERA_BELL_JINGLE)
		{
			angles = self GetPlayerAngles();
			if(isdefined(self.lastAngles))
			{
				angle_dif = angles - self.lastAngles;
				angle_dif = angle_convert(angle_dif);
				angle_dif = Abs(angle_dif[0]) + Abs(angle_dif[1]) + Abs(angle_dif[2]);

				//IPrintLnBold(angle_dif);

				
				if(angle_dif > 1)
				{
					volume += Min(angle_dif / 400,0.5);

					if(angle_dif > 100)
					{
						speed = Max(speed,1); //Make sure speed is at least 1
					}
				}

				
			}
			self.lastAngles = angles;
		}


		//IPrintLnBold(volume);
		string = "" + self.bellSoundModel GetEntityNumber() + "|" + volume + "|" + speed + "|";

		foreach(player in GetPlayers())
		{
			player util::setClientSysState("XMASGunSounds", string, player);
		}
		

		WAIT_SERVER_FRAME;
	}
}

//Wraps angle difference so it doesn't break when going from a negative to a positive
/*Now, my friend, I know what you might be saying, "But CheeseMan, you idiot! This can be done so simply with the modulo operation!" 
And that may seem to be the case at first, in fact you may even spend several hours attempting to get that to work, but unfortunatly this acursed game engine has different ideas.
You see for reasons beyond my puny comprehension if you try and do the modulo (%) operation on a vector, or a piece of a vector, or an int or float that was once upon a time a part of a vector it will simply not work.
And you may ask why? As I did. "My fellow man, what did the logs say? Surely they would give a useful insight that would solve this quarrel." Ah yes, of course I set this game of ours to developer 2, enabled logfile,
and looked at the holy text console_mp.log, and it bestowed upon me the error "pair has unmatching types 'float' and 'float'" Fucking eqsuite.
Now a foolish man like myself could easily drive himself further into madness to solve this error. Even recruit the help of those cut from the same cloth - I'm looking at you Rayjiun.
But... it's December 27th, and this was supposed to be a gun for people to use in their Christmas maps, so I'm doing it this way and moving on with my god damn life.*/
function angle_convert(angle)
{
	new_vec = ( angle_component_convert(angle[0]) , angle_component_convert(angle[1]) , angle_component_convert(angle[2]) );

	return new_vec;
}

function angle_component_convert(value)
{
	new_val = value;

	if(value > 180)
	{
		new_val -= 360;
	}
	else if(value < -180)
	{
		new_val += 360;
	}

	return new_val;
}