#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\aat_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_score;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_utility.gsh;

// Kill feed string precache
#precache( "string", "ZM_AETHERIUM_KF_ELIMINATION" );
#precache( "string", "ZM_AETHERIUM_KF_CRITICAL" );
#precache( "string", "ZM_AETHERIUM_KF_MELEE" );
#precache( "string", "ZM_AETHERIUM_KF_BURNED" );
#precache( "string", "ZM_AETHERIUM_KF_BLAST_FURNACE" );
#precache( "string", "ZM_AETHERIUM_KF_DEAD_WIRE" );
#precache( "string", "ZM_AETHERIUM_KF_FIRE_WORKS" );
#precache( "string", "ZM_AETHERIUM_KF_THUNDER_WALL" );
#precache( "string", "ZM_AETHERIUM_KF_TURNED" );
#precache( "string", "ZM_AETHERIUM_KF_ZOMBIE_DOG" );
#precache( "string", "ZM_AETHERIUM_KF_ROCKET_SHIELD" );
#precache( "string", "ZM_AETHERIUM_KF_GRENADE" );
#precache( "string", "ZM_AETHERIUM_KF_MONKEY_BOMB" );
#precache( "string", "ZM_AETHERIUM_KF_LIL_ARNIE" );
#precache( "string", "ZM_AETHERIUM_KF_RAGNAROK_DG4" );

#namespace zm_aetherium_hud;

REGISTER_SYSTEM_EX( "zm_aetherium_hud", &__init__, &__main__, undefined )

function __init__()
{
	// Register health clientfield for each player using world (vanilla pattern)
	// Use com_maxclients to support up to 8 players (BO6 Overhaul pattern)
	for( i = 0; i < GetDvarInt( "com_maxclients" ); i++ )
	{
		clientfield::register( "world", "player_health_" + i, VERSION_SHIP, 7, "float" );
	}
	
	// Register packed player states clientfield (all 4 players in 1 field)
	// 8 bits total: Player 0 (bits 0-1), Player 1 (bits 2-3), Player 2 (bits 4-5), Player 3 (bits 6-7)
	// Each player uses 2 bits: 0=alive, 1=downed, 2=dead
	clientfield::register( "world", "player_states_packed", VERSION_SHIP, 8, "int" );
	
	// Register on_connect callback to start per-player health monitoring
	callback::on_connect( &on_player_connect );
}

function __main__()
{
	// Main initialization
	
	// Override perk machine cursor hints (custom Lua notification handles display)
	level thread override_perk_hints();
	
	// Register zombie damage callback for kill feed
	zm::register_zombie_damage_override_callback(&zombie_death_callback);
	
	// Start player state monitoring
	level thread monitor_player_states();
}

function on_player_connect()
{
	// Start per-player health monitoring thread
	self thread set_player_health_clientfield();
	
	// Start third person toggle handler
	self thread menu_option_third_person_handler();
}

function set_world_clientfield( name, val )
{
	if( IS_EQUAL( level clientfield::get( name ), val ) )
	{
		return;
	}

	level clientfield::set( name, val );
}

function set_player_health_clientfield()
{
	self endon( "disconnect" );
	self notify( "set_player_health_clientfield" );
	self endon( "set_player_health_clientfield" );
	
	while( true )
	{
		WAIT_SERVER_FRAME;
		health = ( zm_utility::is_player_valid( self ) ? float( self.health / self.maxhealth ) : 0 );
		level set_world_clientfield( "player_health_" + self GetEntityNumber(), health );
	}
}

function override_perk_hints()
{
	// Wait for game to start
	level flag::wait_till("initial_blackscreen_passed");
	
	// Don't modify perk triggers - keep hints active so cursorHintText model is populated
	// Lua will handle hiding default cursor hint visual and showing custom notification
}

//=============================================================================
// KILL FEED SYSTEM
//=============================================================================

function zombie_death_callback( death, inflictor, attacker, damage, flags, mod, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{
	// Process both regular zombies and zombie dogs
	if( IsDefined( self ) && IS_EQUAL( self.team, level.zombie_team ) )
	{
		// Handle Rocket Shield kills FIRST (explosive projectile damage)
		if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( weapon ) && ( weapon.name == "zod_riotshield" || weapon.name == "zod_riotshield_upgraded" ) )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = level.zombie_vars["zombie_score_bonus_burn"];
			text = &"ZM_AETHERIUM_KF_ROCKET_SHIELD";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle Grenade kills (frag grenades)
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( weapon ) && ( weapon.name == "frag_grenade" || IsSubStr( weapon.name, "grenade" ) ) )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = level.zombie_vars["zombie_score_bonus_burn"];
			text = &"ZM_AETHERIUM_KF_GRENADE";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle Monkey Bomb kills
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( weapon ) && weapon.name == "cymbal_monkey" )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = level.zombie_vars["zombie_score_bonus_burn"];
			text = &"ZM_AETHERIUM_KF_MONKEY_BOMB";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle Li'l Arnie kills (BO3 octobomb)
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( weapon ) && ( weapon.name == "octobomb" || weapon.name == "octobomb_upgraded" ) )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = level.zombie_vars["zombie_score_bonus_burn"];
			text = &"ZM_AETHERIUM_KF_LIL_ARNIE";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle Ragnarok DG-4 kills (gravity spikes specialist weapon)
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( weapon ) && weapon.name == "hero_gravityspikes_melee" )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = level.zombie_vars["zombie_score_bonus_burn"];
			text = &"ZM_AETHERIUM_KF_RAGNAROK_DG4";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle zombie dog kills (check character model)
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( self.model ) && IsSubStr( self.model, "hellhound" ) )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = 0;
			text = &"ZM_AETHERIUM_KF_ZOMBIE_DOG";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle Fireworks weapon model kills (attacker is the floating weapon model)
		else if( death && IsDefined( attacker ) && IsDefined( attacker.b_aat_fire_works_weapon ) && attacker.b_aat_fire_works_weapon )
		{
			// Attacker is the Fireworks weapon model - credit the owner
			if( IsDefined( attacker.owner ) && IsPlayer( attacker.owner ) )
			{
				player_points = zm_score::get_zombie_death_player_points();
				points = level.zombie_vars["zombie_score_bonus_burn"];
				text = &"ZM_AETHERIUM_KF_FIRE_WORKS";
				
				player_points += points;
				player_points *= level.zombie_vars[attacker.owner.team]["zombie_point_scalar"];
				
				// Send to the player who owns the Fireworks weapon
				attacker.owner LuiNotifyEvent( &"score_event", 2, text, player_points );
			}
		}
		// Handle turned zombie kills (when turned zombie kills another zombie via melee)
		else if( death && IsDefined( attacker ) && IsDefined( attacker.aat_turned ) && attacker.aat_turned )
		{
			// Attacker is a turned zombie - need to find the player who turned it
			// Check all players to see who has this weapon with turned AAT
			players = GetPlayers();
			foreach( player in players )
			{
				// Check if this player could have turned the zombie
				// (turned zombies are within range of player who turned them)
				if( Distance( attacker.origin, player.origin ) < 2000 )
				{
					player_points = zm_score::get_zombie_death_player_points();
					points = level.zombie_vars["zombie_score_bonus_burn"];
					text = &"ZM_AETHERIUM_KF_TURNED";
					
					player_points += points;
					player_points *= level.zombie_vars[player.team]["zombie_point_scalar"];
					
					// Send to the player who turned the zombie
					player LuiNotifyEvent( &"score_event", 2, text, player_points );
					break; // Only credit one player
				}
			}
		}
		// Handle normal zombie kills (including AAT kills) - exclude dogs
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IS_EQUAL( self.team, level.zombie_team ) && IS_EQUAL( self.archetype, "zombie" ) )
		{
			player_points = zm_score::get_zombie_death_player_points();
			kill_bonus = get_kill_type_bonus( mod, sHitLoc, weapon, attacker, player_points );
			points = kill_bonus[0];
			text = kill_bonus[1];
			
			// Double points for insta-kill melee
			if( level.zombie_vars[attacker.team]["zombie_powerup_insta_kill_on"] == 1 && mod == "MOD_UNKNOWN" )
			{
				points *= 2;
			}
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];

			// [tod 2026-08-23] BOUNTY in the popup (user: "the points display in
			// center of screen should take into account if you have a money
			// upgrade. So im getting 110 on headshot but it shows +100. It
			// should show +110"). The kit recomputes the kill's nominal value
			// here and never saw the BOUNTY bonus, which _tod_upgrades pays from
			// a LATER death-event callback — so the HUD under-reported every
			// class-gun kill for any player carrying the domain.
			// ADDED AFTER the point_scalar on purpose: the bonus is awarded as
			// raw score by add_to_player_score and is not scaled, so adding it
			// here is what makes the popup equal the actual score change.
			// Read-only preview through a level function pointer — the vendored
			// kit must never #using a tod module (cycle rule).
			if ( isdefined( level.tod_bounty_preview_fn ) )
				player_points += [[ level.tod_bounty_preview_fn ]]( attacker, weapon, mod, sHitLoc );

			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
	}

	return false;
}

function get_kill_type_bonus( mod, hit_location, weapon, attacker, player_points = undefined )
{
	ret_val = array( 0, &"ZM_AETHERIUM_KF_ELIMINATION" );
	
	// Check for AAT kills - different AATs use different damage types:
	// - Blast Furnace, Dead Wire, Turned: MOD_UNKNOWN
	// - Thunder Wall: MOD_IMPACT
	// - Fireworks: weapon projectile damage (various types)
	if( IsDefined( attacker ) && IsDefined( weapon ) )
	{
		weapon = aat::get_nonalternate_weapon( weapon );
		aat_name = attacker.aat[weapon];
		
		// Check if this kill was caused by an AAT
		if( IsDefined( aat_name ) )
		{
			// Thunder Wall uses MOD_IMPACT damage
			if( aat_name == "zm_aat_thunder_wall" && mod == "MOD_IMPACT" )
			{
				ret_val[0] = level.zombie_vars["zombie_score_bonus_burn"];
				ret_val[1] = &"ZM_AETHERIUM_KF_THUNDER_WALL";
				return ret_val;
			}
			// Most AATs use MOD_UNKNOWN - only show when AAT triggers
			else if( mod == "MOD_UNKNOWN" )
			{
				switch( aat_name )
				{
					case "zm_aat_blast_furnace":
						ret_val[0] = level.zombie_vars["zombie_score_bonus_burn"];
						ret_val[1] = &"ZM_AETHERIUM_KF_BLAST_FURNACE";
						return ret_val;
					
					case "zm_aat_dead_wire":
						ret_val[0] = level.zombie_vars["zombie_score_bonus_burn"];
						ret_val[1] = &"ZM_AETHERIUM_KF_DEAD_WIRE";
						return ret_val;
					
					case "zm_aat_turned":
						ret_val[0] = level.zombie_vars["zombie_score_bonus_burn"];
						ret_val[1] = &"ZM_AETHERIUM_KF_TURNED";
						return ret_val;
					
					default:
						break;
				}
			}
		}
	}
	
	// Melee kill
	if( mod == "MOD_MELEE" )
	{
		ret_val[0] = level.zombie_vars["zombie_score_bonus_melee"];
		ret_val[1] = &"ZM_AETHERIUM_KF_MELEE";
		return ret_val;
	}
	
	// Burned kill
	if( mod == "MOD_BURNED" )
	{
		ret_val[0] = level.zombie_vars["zombie_score_bonus_burn"];
		ret_val[1] = &"ZM_AETHERIUM_KF_BURNED";
		return ret_val;
	}
	
	// Hit location bonuses
	if( IsDefined( hit_location ) )
	{
		switch( hit_location )
		{
			case "head":
			case "helmet":
				ret_val[0] = level.zombie_vars["zombie_score_bonus_head"];
				ret_val[1] = &"ZM_AETHERIUM_KF_CRITICAL";
				break;
			
			case "neck":
				ret_val[0] = level.zombie_vars["zombie_score_bonus_neck"];
				ret_val[1] = &"ZM_AETHERIUM_KF_ELIMINATION";
				break;
			
			case "torso_upper":
			case "torso_lower":
				ret_val[0] = level.zombie_vars["zombie_score_bonus_torso"];
				ret_val[1] = &"ZM_AETHERIUM_KF_ELIMINATION";
				break;
			
			default:
				break;
		}
	}
	
	return ret_val;
}

// Third Person Camera Toggle Handler (BO6 Overhaul Pattern)
function menu_option_third_person_handler()
{
	self endon( "disconnect" );
	self notify( "menu_option_third_person_handler" );
	self endon( "menu_option_third_person_handler" );
	
	while( true )
	{
		self waittill( "menuresponse", menu, response );
		
		split_string = strtok( response, "|" );
		option_name = split_string[0];
		option_value = split_string[1];
		
		if( IS_EQUAL( menu, "StartMenu_Main" ) && IS_EQUAL( option_name, "ui_menu_option_third_person" ) )
		{
			if( int( option_value ) == 1 )
			{
				// Enable third person with proper camera positioning
				// Range: 120 (camera distance from player - closer)
				// Height Offset: 30 (camera height above player)
				self setclientthirdperson( 1, 120, 30 );
			}
			else
			{
				// Disable third person
				self setclientthirdperson( 0 );
			}
		}
	}
}
function monitor_player_states()
{
	level endon( "end_game" );
	
	// Track last state to avoid unnecessary updates
	level.player_last_states = [];
	level.player_last_states[0] = -1;
	level.player_last_states[1] = -1;
	level.player_last_states[2] = -1;
	level.player_last_states[3] = -1;
	
	while( true )
	{
		players = GetPlayers();
		state_changed = false;
		
		foreach( player in players )
		{
			entityNum = player GetEntityNumber();
			
			// Determine player state
			player_state = 0; // Default: Alive
			
			// Check dead/spectator FIRST (highest priority)
			if( player.sessionstate == "spectator" || 
			    player.sessionstate == "intermission" || 
			    player.sessionstate == "dead" )
			{
				player_state = 2; // Dead/Spectator
			}
			// Then check downed
			else if( player laststand::player_is_in_laststand() )
			{
				player_state = 1; // Downed
			}
			// else: player_state = 0 (Alive)
			
			// Only update if state changed
			if( player_state != level.player_last_states[entityNum] )
			{
				level.player_last_states[entityNum] = player_state;
				state_changed = true;
			}
		}
		
		// Pack all 4 player states into a single integer and send once
		if( state_changed )
		{
			packed_value = 0;
			packed_value = packed_value | ( level.player_last_states[0] << 0 );  // Player 0: bits 0-1
			packed_value = packed_value | ( level.player_last_states[1] << 2 );  // Player 1: bits 2-3
			packed_value = packed_value | ( level.player_last_states[2] << 4 );  // Player 2: bits 4-5
			packed_value = packed_value | ( level.player_last_states[3] << 6 );  // Player 3: bits 6-7
			
			level clientfield::set( "player_states_packed", packed_value );
		}
		
		wait( 0.5 ); // Check twice per second
	}
}