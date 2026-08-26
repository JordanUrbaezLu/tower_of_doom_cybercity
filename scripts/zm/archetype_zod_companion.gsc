#using scripts\shared\ai\archetype_cover_utility;
#using scripts\shared\ai\archetype_locomotion_utility;
#using scripts\shared\ai\archetype_mocomps_utility;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\ai_blackboard;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\systems\ai_squads;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\systems\debug;
#using scripts\shared\ai\systems\destructible_character;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\systems\shared;
#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai_shared;
#using scripts\shared\animation_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\gameskill_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\spawner_shared;
#using scripts\zm\_zm;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_spawner;
#using scripts\zm\archetype_zod_companion_interface;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\animation_state_machine.gsh;

#namespace archetype_zod_companion;

function autoexec main()
{
	clientfield::register( "allplayers", "being_robot_revived", VERSION_SHIP, 1, "int" );
	spawner::add_archetype_spawn_function( "zod_companion", &zodcompanionbehavior::archetypezodcompanionblackboardinit );
	spawner::add_archetype_spawn_function( "zod_companion", &zodcompanionserverutils::zodcompanionsoldierspawnsetup );
	zodcompanioninterface::registerzodcompanioninterfaceattributes();
	zodcompanionbehavior::RegisterBehaviorScriptFunctions();
}

#namespace zodcompanionbehavior;

function RegisterBehaviorScriptFunctions()
{
	BT_REGISTER_API( "zodCompanionTacticalWalkActionStart", &zodcompaniontacticalwalkactionstart );
	BT_REGISTER_API( "zodCompanionAbleToShoot", &zodcompanionabletoshoot );
	BT_REGISTER_API( "zodCompanionShouldTacticalWalk", &zodcompanionshouldtacticalwalk );
	BT_REGISTER_API( "zodCompanionMovement", &zodcompanionmovement );
	BT_REGISTER_API( "zodCompanionDelayMovement", &zodcompaniondelaymovement );
	BT_REGISTER_API( "zodCompanionSetDesiredStanceToStand", &zodcompanionsetdesiredstancetostand );
	BT_REGISTER_API( "zodCompanionFinishedSprintTransition", &zodcompanionfinishedsprinttransition );
	BT_REGISTER_API( "zodCompanionSprintTransitioning", &zodcompanionsprinttransitioning );
	BT_REGISTER_API( "zodCompanionKeepsCurrentMovementMode", &zodcompanionkeepscurrentmovementmode );
	BT_REGISTER_API( "zodCompanionCanJuke", &zodcompanioncanjuke );
	BT_REGISTER_API( "zodCompanionCanPreemptiveJuke", &zodcompanioncanpreemptivejuke );
	BT_REGISTER_API( "zodCompanionJukeInitialize", &zodcompanionjukeinitialize );
	BT_REGISTER_API( "zodCompanionPreemptiveJukeTerminate", &zodcompanionpreemptivejuketerminate );
	BT_REGISTER_API( "zodCompanionTargetService", &zodcompaniontargetservice );
	BT_REGISTER_API( "zodCompanionTryReacquireService", &zodcompaniontryreacquireservice );
	BT_REGISTER_API( "manage_companion_movement", &manage_companion_movement );
	BT_REGISTER_API( "zodCompanionCollisionService", &zodcompanioncollisionservice );
}

function private mocompIgnorePainFaceEnemyInit( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity.blockingPain = 1;
	entity OrientMode( "face enemy" );
	entity animMode( "pos deltas" );
}

function private mocompIgnorePainFaceEnemyTerminate( entity, mocompAnim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration )
{
	entity.blockingPain = 0;
}

function private archetypezodcompanionblackboardinit()
{
	entity = self;
	entity.pushable = 1;
	blackboard::CreateBlackBoardForEntity( entity );
	ai::CreateInterfaceForEntity( entity );
	entity AiUtility::RegisterUtilityBlackboardAttributes();
	blackboard::RegisterBlackBoardAttribute( self, "_locomotion_speed", "locomotion_speed_sprint", undefined );
	blackboard::RegisterBlackBoardAttribute( self, "_move_mode", "normal", undefined );
	blackboard::RegisterBlackBoardAttribute( self, "_gibbed_limbs", undefined, &archetypezodcompaniongib );
}

function private archetypezodcompaniongib()
{
	entity = self;
	rightArmGibbed = GibServerUtils::IsGibbed( entity, 16 );
	leftArmGibbed = GibServerUtils::IsGibbed( entity, 32 );
	if ( rightArmGibbed && leftArmGibbed )
		return "both_arms";
	else if ( rightArmGibbed )
		return "right_arm";
	else if ( leftArmGibbed )
		return "left_arm";
	
	return "none";
}

function private zodcompaniondelaymovement( entity )
{
	entity pathMode( "move delayed", 0, RandomFloatRange( 1, 2 ) );
}

function private zodcompanionmovement( entity )
{
	if ( blackboard::GetBlackBoardAttribute( entity, "_stance" ) != "stand" )
		blackboard::SetBlackBoardAttribute( entity, "_desired_stance", "stand" );
	
}

function zodcompanioncanjuke( entity )
{
	if ( !IS_TRUE( entity.steppedOutOfCover) && AiUtility::canJuke( entity ) )
	{
		jukeEvents = blackboard::GetBlackboardEvents( "robot_juke" );
		tooCloseJukeDistanceSqr = 57600;
		foreach ( event in jukeEvents )
		{
			if ( event.data.entity != entity && distance2DSquared( entity.origin, event.data.origin ) <= tooCloseJukeDistanceSqr )
				return 0;
			
		}
		return 1;
	}
	return 0;
}

function zodcompanioncanpreemptivejuke( entity )
{
	if ( !isdefined( entity.enemy ) || !isPlayer( entity.enemy ) )
		return 0;
	
	if ( blackboard::GetBlackBoardAttribute( entity, "_stance" ) == "crouch" )
		return 0;
	
	if ( !entity.shouldPreemptiveJuke )
		return 0;
	
	if ( isdefined( entity.nextPreemptiveJuke ) && entity.nextPreemptiveJuke > GetTime() )
		return 0;
	
	if ( entity.enemy PlayerAds() < entity.nextPreemptiveJukeAds )
		return 0;
	
	if ( DistanceSquared( entity.origin, entity.enemy.origin ) < 360000 )
	{
		angleDifference = absAngleClamp180( entity.angles[ 1 ] - entity.enemy.angles[ 1 ] );
		
		if ( angleDifference > 135 )
		{
			enemyAngles = entity.enemy GetGunAngles();
			toEnemy = entity.enemy.origin - entity.origin;
			forward = anglesToForward( enemyAngles );
			dotProduct = abs( VectorDot( VectorNormalize( toEnemy ), forward ) );
			
			if ( dotProduct > .9848 )
				return zodcompanioncanjuke( entity );
			
		}
	}
	return 0;
}

function private _IsValidPlayer( player )
{
	if ( !isDefined( player ) || !isAlive( player ) || !isPlayer( player ) || player.sessionstate == "spectator" || player.sessionstate == "intermission" || player laststand::player_is_in_laststand() || player.ignoreme )
		return 0;
	
	return 1;
}

function private _FindClosest( entity, entities )
{
	closest = spawnStruct();
	if ( entities.size > 0 )
	{
		closest.entity = entities[ 0 ];
		closest.DistanceSquared = distanceSquared( entity.origin, closest.entity.origin );
		for ( index = 1; index < entities.size; index++ )
		{
			distanceSquared = distanceSquared( entity.origin, entities[ index ].origin );
			if ( DistanceSquared < closest.distanceSquared )
			{
				closest.distanceSquared = distanceSquared;
				closest.entity = entities[ index ];
			}
		}
	}
	return closest;
}

function private zodcompaniontargetservice( entity )
{
	if ( zodcompanionabletoshoot( entity ) )
		return 0;
	
	if ( IS_TRUE( entity.ignoreall ) )
		return 0;
	
	aiEnemies = [];
	playerEnemies = [];
	ai = getAIArray();
	players = getPlayers();
	positionOnNavMesh = GetClosestPointOnNavMesh( entity.origin, 200 );
	if ( !isdefined( positionOnNavMesh ) )
		return;
	
	foreach ( value in ai )
	{
		if ( value.team != entity.team && IsActor( value ) && !isdefined( entity.favoriteenemy ) )
		{
			enemyPositionOnNavMesh = GetClosestPointOnNavMesh( value.origin, 200 );
			if ( isdefined( enemyPositionOnNavMesh ) && entity FindPath( positionOnNavMesh, enemyPositionOnNavMesh, 1, 0 ) )
				aiEnemies[ aiEnemies.size ] = value;
			
		}
	}
	foreach ( value in players )
	{
		if ( _IsValidPlayer( value ) )
		{
			enemyPositionOnNavMesh = GetClosestPointOnNavMesh( value.origin, 200 );
			if ( isdefined( enemyPositionOnNavMesh ) && entity FindPath( positionOnNavMesh, enemyPositionOnNavMesh, 1, 0 ) )
				playerEnemies[ playerEnemies.size ] = value;
			
		}
	}
	closestPlayer = _FindClosest( entity, playerEnemies );
	closestAI = _FindClosest( entity, aiEnemies );
	if ( !isdefined( closestPlayer.entity ) && !isdefined( closestAI.entity ) )
		return;
	else if ( !isdefined( closestAI.entity ) )
		entity.favoriteenemy = closestPlayer.entity;
	else if ( !isdefined( closestPlayer.entity ) )
		entity.favoriteenemy = closestAI.entity;
	else if ( closestAI.DistanceSquared < closestPlayer.DistanceSquared )
		entity.favoriteenemy = closestAI.entity;
	else
		entity.favoriteenemy = closestPlayer.entity;
	
}

function private zodcompaniontacticalwalkactionstart( entity )
{
	entity orientMode( "face enemy" );
}

function private zodcompanionabletoshoot( entity )
{
	return entity.weapon.name != level.weaponNone.name && !GibServerUtils::IsGibbed( entity, 16 );
}

function private zodcompanionshouldtacticalwalk( entity )
{
	if ( !entity hasPath() )
		return 0;
	
	return 1;
}

function private zodcompanionjukeinitialize( entity )
{
	AiUtility::chooseJukeDirection( entity );
	entity clearPath();
	jukeInfo = spawnstruct();
	jukeInfo.origin = entity.origin;
	jukeInfo.entity = entity;
	blackboard::AddBlackboardEvent( "robot_juke", jukeInfo, 2000 );
}

function private zodcompanionpreemptivejuketerminate( entity )
{
	entity.nextPreemptiveJuke = getTime() + randomIntRange( 4000, 6000 );
	entity.nextPreemptiveJukeAds = RandomFloatRange( 0.5, 0.95 );
}

function private zodcompaniontryreacquireservice( entity )
{
	if ( !isdefined( entity.reacquire_state ) )
		entity.reacquire_state = 0;
	
	if ( !isdefined( entity.enemy ) )
	{
		entity.reacquire_state = 0;
		return 0;
	}
	if ( entity HasPath() )
		return 0;
	
	if ( !zodcompanionabletoshoot( entity ) )
		return 0;
	
	if ( entity cansee( entity.enemy ) && entity CanShootEnemy() )
	{
		entity.reacquire_state = 0;
		return 0;
	}
	dirToEnemy = VectorNormalize( entity.enemy.origin - entity.origin );
	forward = AnglesToForward( entity.angles );
	if ( vectorDot( dirToEnemy, forward ) < .5 )
	{
		entity.reacquire_state = 0;
		return 0;
	}
	switch ( entity.reacquire_state )
	{
		case 0:
		case 1:
		case 2:
		{
			step_size = 32 + entity.reacquire_state * 32;
			reacquirePos = entity ReacquireStep( step_size );
			break;
		}
		case 4:
		{
			if ( !entity cansee( entity.enemy ) || !entity canShootEnemy() )
				entity FlagEnemyUnattackable();
			
			break;
		}
		default:
		{
			if ( entity.reacquire_state > 15 )
			{
				entity.reacquire_state = 0;
				return 0;
			}
			break;
		}
	}
	if ( IsVec( reacquirePos ) )
	{
		entity usePosition( reacquirePos );
		return 1;
	}
	entity.reacquire_state++;
	return 0;
}

function private manage_companion_movement( entity )
{
	self endon( "death" );
	if ( IS_TRUE( level.b_robot_leader ) )
		self.leader = level.b_robot_leader;
	
	if ( !isdefined( entity.n_revive_cooldown ) )
		entity.n_revive_cooldown = 0;
	
	if ( entity.bulletsInClip < entity.weapon.clipSize )
		entity.bulletsInClip = entity.weapon.clipSize;
	
	if ( entity.reviving_a_player === 1 )
		return;
	
	if ( entity.b_robot_finished === 1 )
		return;
	
	if ( entity.b_chasing_teleporting_player === 1 || entity.teleporting === 1 )
		return;

	if ( !isdefined( entity.leader ) )   // [acc] COOP CRASH GUARD: leader (a player) disconnected - the leader-relative
		return;                          // movement below (entity.leader.teleporting/.is_flung/...) would deref undefined and throw

	if ( entity.leader.teleporting === 1 )
	{
		entity thread zodrobotchaseteleportingplayer( entity.leader.teleport_location );
		return;
	}
	if ( entity.robot_chasing_player === 1 )
		return;
	
	if ( entity.leader.is_flung  === 1 )
		entity thread robot_companion_chase_player( entity.leader.fling_land_pos );
	
	foreach ( player in level.players )
	{
		if ( player laststand::player_is_in_laststand() && entity.reviving_a_player === 0 && player.reviveTrigger.beingRevived !== 1 )
		{
			time = getTime();
			if ( distanceSquared( entity.origin, player.origin ) <= 1024 * 1024 && time >= entity.n_revive_cooldown )
			{
				entity.reviving_a_player = 1;
				entity zod_companion_revive_player( player );
				return;
			}
		}
	}
	if ( !isDefined( entity.robot_last_move_evaluate ) )
		entity.robot_last_move_evaluate = getTime();
	
	if ( getTime() >= entity.robot_last_move_evaluate && isDefined( level.active_powerups ) && level.active_powerups.size > 0 )
	{
		if ( !isDefined( entity.go_to_powerup_chance ) )
			entity.go_to_powerup_chance = 0;
		
		foreach ( powerup in level.active_powerups )
		{
			if ( isInArray( entity.robot_powerup, powerup.powerup_name ) )
			{
				dist = DistanceSquared( entity.origin, powerup.origin );
				if ( dist <= 147456 && randomInt( 100 ) < 50 + 10 * entity.go_to_powerup_chance )
				{
					entity setGoal( powerup.origin, 1 );
					entity.robot_last_move_evaluate = getTime() + randomIntRange( 2500, 3500 );
					entity.next_move_time = getTime() + randomIntRange( 2500, 3500 );
					entity.go_to_powerup_chance = 0;
					return;
				}
				entity.go_to_powerup_chance = entity.go_to_powerup_chance + 1;
			}
		}
		entity.robot_last_move_evaluate = GetTime() + randomIntRange( 333, 666 );
	}
	land_damage_distance_sq = 256 * 256;
	if ( isdefined( entity.leader ) )
		entity.v_robot_land_position = entity.leader.origin;
	
	if ( isdefined( entity.pathGoalPos ) )
		dist_check_start_point = entity.pathGoalPos;
	else
		dist_check_start_point = entity.origin;
	
	if ( isdefined( entity.enemy ) && entity.enemy.archetype == "parasite" )
	{
		height_difference = abs( entity.origin[ 2 ] - entity.enemy.origin[ 2 ] );
		max_distance = ( 1.5 * height_difference ) * ( 1.5 * height_difference );
		if ( DistanceSquared( dist_check_start_point, entity.enemy.origin ) < max_distance )
			entity pick_new_movement_point();
		
	}
	if ( DistanceSquared( dist_check_start_point, entity.v_robot_land_position ) > land_damage_distance_sq || DistanceSquared( dist_check_start_point, entity.v_robot_land_position) < 4096 )
		entity pick_new_movement_point();
	
	if ( GetTime() >= entity.next_move_time )
		entity pick_new_movement_point();
	
}

function private zodcompanioncollisionservice( entity )
{
	if ( isDefined( entity.dontPushTime ) )
	{
		if ( getTime() < entity.dontPushTime )
			return 1;
		
	}
	robot_stuck = 0;
	zombies = getAITeamArray( level.zombie_team );
	foreach ( zombie in zombies )
	{
		if ( zombie == entity )
			continue;
		
		dist_sq = distanceSquared( entity.origin, zombie.origin );
		if ( dist_sq < 14400 )
		{
			if ( IS_TRUE( zombie.cant_move ) )
			{
				zombie thread robot_delay_can_push_actors();
				robot_stuck = 1;
			}
		}
	}
	if ( robot_stuck )
	{
		entity pushActors( 0 );
		entity.dontPushTime = getTime() + 2000;
		return 1;
	}
	entity pushActors( 1 );
	return 0;
}

function private robot_delay_can_push_actors()
{
	self endon( "death" );
	self pushActors( 0 );
	wait 2;
	self pushActors( 1 );
}
/*
function private function_f62bd05c( target_entity, max_distance )
{
	entity = self;
	var_c96da0a0 = target_entity.origin;
	if ( DistanceSquared( entity.origin, var_c96da0a0 ) > max_distance * max_distance )
		return 0;
	
	path = entity CalcApproximatePathToPosition( var_c96da0a0 );
	segmentLength = 0;
	for ( index = 1; index < path.size; index++ )
	{
		currentSegLength = Distance( path[ index - 1 ], path[ index ] );
		if ( currentSegLength + segmentLength > max_distance )
			return 0;
		
		segmentLength = segmentLength + currentSegLength;
	}
	return 1;
}
*/
function private zodrobotchaseteleportingplayer( v_teleport_location )
{
	self.b_chasing_teleporting_player = 1;
	self setGoal( v_teleport_location, 1 );
	self waittill( "goal" );
	wait 1;
	self.b_chasing_teleporting_player = 0;
}

function private robot_companion_chase_player( flung_to_pos )
{
	self.robot_chasing_player = 1;
	near_traverse = getNodeArray( "flinger_traversal", "script_noteworthy" );
	go_to_loc = ArrayGetClosest( flung_to_pos, near_traverse );
	self SetGoal( go_to_loc.origin, 1 );
	self waittill( "goal" );
	wait 1;
	self.robot_chasing_player = 0;
}

function private pick_new_movement_point()
{
	queryResult = positionQuery_Source_Navigation( self.v_robot_land_position, 96, 256, 256, 20, self );
	if ( queryResult.data.size )
	{
		if ( isdefined( self.enemy ) && self.enemy.archetype == "parasite" )
			Array::filter( queryResult.data, 0, &robot_can_chase_parasite, self.enemy );
		
	}
	if ( queryResult.data.size )
	{
		point = queryResult.data[ RandomInt( queryResult.data.size ) ];
		pathSuccess = self FindPath( self.origin, point.origin, 1, 0 );
		if ( pathSuccess )
			self.companion_destination = point.origin;
		else
		{
			self.next_move_time = getTime() + randomIntRange( 500, 1500 );
			return;
		}
	}
	self SetGoal( self.companion_destination, 1 );
	self.next_move_time = getTime() + randomIntRange( 20000, 30000 );
}

function private robot_can_chase_parasite( parasite )
{
	point = self;
	height_difference = abs( point.origin[ 2 ] - parasite.origin[ 2 ] );
	max_distance = ( 1.5 * height_difference ) * ( 1.5 * height_difference );
	return distanceSquared( point.origin, parasite.origin ) > max_distance;
}

function private zodcompanionsetdesiredstancetostand( behaviorTreeEntity )
{
	currentStance = blackboard::GetBlackBoardAttribute( behaviorTreeEntity, "_stance" );
	if ( currentStance == "crouch" )
		blackboard::SetBlackBoardAttribute( behaviorTreeEntity, "_desired_stance", "stand" );
	
}

function zod_companion_revive_player( player )
{
	self endon( "revive_terminated" );
	self endon( "end_game" );
	player endon( "disconnect" );   // [acc] COOP CRASH GUARD: the downed player can leave mid-revive; this thread
	                                // derefs `player` across several waits (setGoal/goal/robot_revive_complete) and
	                                // would throw "not an entity". endon aborts cleanly; the monitor thread resets the robot.
	if ( !IS_TRUE( self.reviving_a_player ) )
		self.reviving_a_player = 1;
	
	player.being_revived_by_robot = 0;
	self thread zod_companion_monitor_revive_attempt( player );
	self.ignoreall = 1;
	queryResult = positionQuery_Source_Navigation( player.origin, 64, 96, 48, 18, self );
	if ( queryResult.data.size )
	{
		point = queryResult.data[ randomInt( queryResult.data.size ) ];
		self.companion_destination = point.origin;
	}
	if ( !isdefined( self.companion_destination ) )   // [acc] nav query returned no point AND no prior goal: fall back
		self.companion_destination = player.origin;   // to the downed player so setGoal/waittill never act on undefined
	self setGoal( self.companion_destination, 1 );
	self waittill( "goal" );
	// [acc] 4p guard (2026-07-06 sweep): a teammate can win the revive race (or the downed player
	// bleeds out) while the robot walks - player.reviveTrigger is then undefined and the write below
	// threw. Bail + cleanup so the robot re-arms for the next down.
	if ( !isdefined( player.reviveTrigger ) || !IS_TRUE( player.laststand ) )
	{
		self zod_companion_revive_cleanup( player );
		return;
	}
	level.reviving_a_player = 1;
	player.reviveTrigger.beingRevived = 1;
	player.being_revived_by_robot = 1;
	vector = vectorNormalize( player.origin - self.origin );
	angles = vectorToAngles( vector );
	self teleport( self.origin, angles );
	self thread animation::Play( "ai_robot_base_stn_exposed_revive", self, angles, 1.5 );
	wait .67;
	player clientfield::set( "being_robot_revived", 1 );
	self waittill( "robot_revive_complete" );
	if ( level.players.size == 1 && level flag::get( "solo_game" ) )
		self.n_revive_cooldown = getTime() + 10000;
	else
		self.n_revive_cooldown = getTime() + 5000;
	
	player notify( "stop_revive_trigger" );
	if ( isPlayer( player ) )
		player allowJump( 1 );
	
	player.laststand = undefined;
	player thread zm_laststand::revive_success( self, 0 );
	level.reviving_a_player = 0;
	players = getPlayers();
	if ( players.size == 1 && level flag::get( "solo_game" ) && IS_TRUE( player.waiting_to_revive ) )
	{
		level.solo_game_free_player_quickrevive = 1;
		player thread zm_perks::give_perk( "specialty_quickrevive", 0 );
	}
	self zod_companion_revive_cleanup( player );
}

function zod_companion_monitor_revive_attempt( player )
{
	self endon( "revive_terminated" );
	while ( 1 )
	{
		if ( !isdefined( player ) )   // [acc] COOP CRASH GUARD: player disconnected mid-revive - reset the robot
		{                             // (cleanup fires "revive_terminated" to end the revive thread) and stop before derefing undefined
			self zod_companion_revive_cleanup( player );
			return;
		}
		if ( isdefined( player.reviveTrigger ) && player.reviveTrigger.beingRevived === 1 && player.being_revived_by_robot !== 1 )
			self zod_companion_revive_cleanup( player );
		
		if ( !player laststand::player_is_in_laststand() )
			self zod_companion_revive_cleanup( player );
		
		wait .05;
	}
}

function zod_companion_revive_cleanup( player )
{
	self.ignoreall = 0;
	self.reviving_a_player = 0;
	if ( isdefined( player ) )
	{
		if ( isdefined( player.being_revived_by_robot ) && player.being_revived_by_robot == 1 )   // [acc] field may be unset if the revive bailed pre-start
			player.being_revived_by_robot = 0;
		
		player clientfield::set( "being_robot_revived", 0 );
	}
	self notify( "revive_terminated" );
}

function private zodcompanionfinishedsprinttransition( behaviorTreeEntity )
{
	behaviorTreeEntity.sprint_transition_happening = 0;
	if ( blackboard::GetBlackBoardAttribute( behaviorTreeEntity, "_locomotion_speed" ) == "locomotion_speed_walk" )
	{
		behaviorTreeEntity ai::set_behavior_attribute( "sprint", 1 );
		blackboard::SetBlackBoardAttribute( behaviorTreeEntity, "_locomotion_speed", "locomotion_speed_sprint" );
	}
	else
	{
		behaviorTreeEntity ai::set_behavior_attribute( "sprint", 0 );
		blackboard::SetBlackBoardAttribute( behaviorTreeEntity, "_locomotion_speed", "locomotion_speed_walk" );
	}
}

function private zodcompanionkeepscurrentmovementmode( behaviorTreeEntity )
{
	max_dist = 262144;
	min_dist = 147456;
	dist = distanceSquared( behaviorTreeEntity.origin, behaviorTreeEntity.v_robot_land_position );
	if ( dist > max_dist && blackboard::GetBlackBoardAttribute( behaviorTreeEntity, "_locomotion_speed" ) == "locomotion_speed_walk" )
		return 0;
	
	if ( dist < min_dist && blackboard::GetBlackBoardAttribute( behaviorTreeEntity, "_locomotion_speed" ) == "locomotion_speed_sprint" )
		return 0;
	
	return 1;
}

function private zodcompanionsprinttransitioning( behaviorTreeEntity )
{
	if ( behaviorTreeEntity.sprint_transition_happening === 1 )
		return 1;
	
	return 0;
}

#namespace zodcompanionserverutils;

function private _tryGibbingHead( entity, damage, hitLoc, isExplosive )
{
	if ( isExplosive && RandomFloatRange( 0, 1 ) <= .5 )
		GibServerUtils::GibHead( entity );
	else if ( isInArray( Array( "head", "neck", "helmet" ), hitLoc ) && randomFloatRange( 0, 1 ) <= 1 )
		GibServerUtils::GibHead( entity );
	else if ( entity.health - damage <= 0 && RandomFloatRange( 0, 1 ) <= .25 )
		GibServerUtils::GibHead( entity );
	
}

function private _tryGibbingLimb( entity, damage, hitLoc, isExplosive )
{
	if ( GibServerUtils::IsGibbed( entity, 32 ) || GibServerUtils::IsGibbed( entity, 16 ) )
		return;
	
	if ( isExplosive && randomFloatRange( 0, 1 ) <= 0.25 )
	{
		if ( entity.health - damage <= 0 && entity.allowdeath && math::cointoss() )
			GibServerUtils::GibRightArm( entity );
		else
			GibServerUtils::GibLeftArm( entity );
		
	}
	else if ( isInArray( array( "left_hand", "left_arm_lower", "left_arm_upper" ), hitLoc ) )
		GibServerUtils::GibLeftArm( entity );
	else if ( entity.health - damage <= 0 && entity.allowdeath && isInArray( array( "right_hand", "right_arm_lower", "right_arm_upper" ), hitLoc ) )
		GibServerUtils::GibRightArm( entity );
	else if ( entity.health - damage <= 0 && entity.allowdeath && randomFloatRange( 0, 1 ) <= 0.25 )
	{
		if ( math::cointoss() )
			GibServerUtils::GibLeftArm( entity );
		else
			GibServerUtils::GibRightArm( entity );
		
	}
}

function private _tryGibbingLegs( entity, damage, hitLoc, isExplosive, attacker )
{
	if ( !isdefined( attacker ) )
		attacker = entity;
	
	canGibLegs = entity.health - damage <= 0 && entity.allowdeath;
	canGibLegs = canGibLegs || ( entity.health - damage / entity.maxhealth <= .25 && distanceSquared( entity.origin, attacker.origin ) <= 360000 && entity.allowdeath );
	if ( entity.health - damage <= 0 && entity.allowdeath && isExplosive && randomFloatRange( 0, 1 ) <= 0.5 )
	{
		GibServerUtils::GibLegs( entity );
		entity StartRagdoll();
	}
	else if ( canGibLegs && isInArray( Array( "left_leg_upper", "left_leg_lower", "left_foot" ), hitLoc ) && randomFloatRange( 0, 1 ) <= 1 )
	{
		if ( entity.health - damage > 0 )
			entity.becomeCrawler = 1;
		
		GibServerUtils::GibLeftLeg( entity );
	}
	else if ( canGibLegs && isInArray( Array( "right_leg_upper", "right_leg_lower", "right_foot" ), hitLoc ) && randomFloatRange( 0, 1 ) <= 1 )
	{
		if ( entity.health - damage > 0 )
			entity.becomeCrawler = 1;
		
		GibServerUtils::GibRightLeg( entity );
	}
	else if ( entity.health - damage <= 0 && entity.allowdeath && RandomFloatRange( 0, 1 ) <= .25 )
	{
		if ( math::cointoss() )
			GibServerUtils::GibLeftLeg( entity );
		else
			GibServerUtils::GibRightLeg( entity );
		
	}
}

function private zodcompaniongibdamageoverride( inflictor, attacker, damage, flags, meansOfDeath, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	entity = self;
	if ( entity.health - damage / entity.maxhealth > .75 )
		return damage;
	
	GibServerUtils::ToggleSpawnGibs( entity, 1 );
	// VERIFIED(acc) 2026-07-15: was "MOD_PROJECTIVLE_SPLASH" - the PACK AUTHOR's typo (the string exists
	// nowhere in the stock scripts; stock spells it MOD_PROJECTILE_SPLASH, e.g. mp\gametypes\
	// _globallogic_player.gsc:1892). The misspelt entry could never match a real meansOfDeath, so projectile
	// splash never counted as explosive for gibbing. Do NOT "correct" this back on a pack re-vendor.
	isExplosive = isInArray( array( "MOD_GRENADE", "MOD_GRENADE_SPLASH", "MOD_PROJECTILE", "MOD_PROJECTILE_SPLASH", "MOD_EXPLOSIVE" ), meansOfDeath );
	_tryGibbingHead( entity, damage, hitLoc, isExplosive );
	_tryGibbingLimb( entity, damage, hitLoc, isExplosive );
	_tryGibbingLegs( entity, damage, hitLoc, isExplosive, attacker );
	return damage;
}

function private zodcompaniondestructdeathoverride( inflictor, attacker, damage, flags, meansOfDeath, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	entity = self;
	if ( entity.health - damage <= 0 )
	{
		DestructServerUtils::ToggleSpawnGibs( entity, 1 );
		pieceCount = DestructServerUtils::GetPieceCount( entity );
		possiblePieces = [];
		for ( index = 1; index <= pieceCount; index++ )
		{
			if ( !DestructServerUtils::IsDestructed( entity, index ) && RandomFloatRange( 0, 1 ) <= 0.2 )
				possiblePieces[ possiblePieces.size ] = index;
			
		}
		gibbedPieces = 0;
		for ( index = 0; index < possiblePieces.size && possiblePieces.size > 1 && gibbedPieces < 2; index++ )
		{
			randomPiece = randomIntRange( 0, possiblePieces.size - 1 );
			if ( !DestructServerUtils::IsDestructed( entity, possiblePieces[ randomPiece ] ) )
			{
				DestructServerUtils::DestructPiece( entity, possiblePieces[ randomPiece ] );
				gibbedPieces++;
			}
		}
	}
	return damage;
}

function private zodcompaniondamageoverride( inflictor, attacker, damage, flags, meansOfDeath, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	entity = self;
	if ( hitLoc == "helmet" || hitLoc == "head" || hitLoc == "neck" )
		damage = int( damage * .5 );
	
	return damage;
}

function private findClosestNavMeshPositionToEnemy( enemy )
{
	enemyPositionOnNavMesh = undefined;
	for ( toleranceLevel = 1; toleranceLevel <= 4; toleranceLevel++ )
	{
		enemyPositionOnNavMesh = GetClosestPointOnNavMesh( enemy.origin, 200 * toleranceLevel );
		if ( isdefined( enemyPositionOnNavMesh ) )
			break;
		
	}
	return enemyPositionOnNavMesh;
}

function private zodcompanionsoldierspawnsetup()
{
	entity = self;
	entity.combatmode = "cover";
	entity.fullHealth = entity.health;
	entity.controlLevel = 0;
	entity.steppedOutOfCover = 0;
	entity.startingWeapon = entity.weapon;
	entity.jukeDistance = 90;
	entity.jukeMaxDistance = 600;
	entity.entityRadius = 15;
	entity.var_9f44813a = entity.accuracy;
	entity.highlyawareradius = 256;
	entity.treatAllCoversAsGeneric = 1;
	entity.onlyCrouchArrivals = 1;
	entity.nextPreemptiveJukeAds = RandomFloatRange( 0.5, 0.95 );
	entity.shouldPreemptiveJuke = math::cointoss();
	entity.reviving_a_player = 0;
	AiUtility::AddAIOverrideDamageCallback( entity, &DestructServerUtils::handleDamage );
	AiUtility::AddAIOverrideDamageCallback( entity, &zodcompaniondamageoverride );
	AiUtility::AddAIOverrideDamageCallback( entity, &zodcompaniongibdamageoverride );
	entity.v_robot_land_position = entity.origin;
	entity.next_move_time = GetTime();
	entity.allow_zombie_to_target_ai = 1;
	entity.ignoreme = 1;
	entity thread zodcompanionutility::manage_robot_powerups();
	entity thread zodcompanionutility::manage_companion();
}

#namespace zodcompanionutility;

function manage_companion()
{
	self endon( "death" );
	while ( 1 )
	{
		if ( !self.reviving_a_player )
		{
			if ( !isdefined( self.leader ) || !self.leader.eligible_leader )
				self define_new_leader();
			
		}
		wait .5;
	}
}

function manage_robot_powerups()
{
	self.robot_powerup = [];
	self.robot_powerup[ 0 ] = "double_points";
	self.robot_powerup[ 1 ] = "fire_sale";
	self.robot_powerup[ 2 ] = "insta_kill";
	self.robot_powerup[ 3 ] = "nuke";
	self.robot_powerup[ 4 ] = "full_ammo";
	self.robot_powerup[ 5 ] = "insta_kill_ug";
}

function define_new_leader()
{
	if ( isDefined( level.b_robot_leader ) && level.b_robot_leader.eligible_leader )
	{
		self.leader = level.b_robot_leader;
		break;
	}
	closest_leader = get_potential_leaders( self );
	closest_distance = undefined;
	closest_distance = 1000000;
	if ( closest_leader.size == 0 )
	{
		self.leader = undefined;
		break;
	}
	foreach ( potential_leader in closest_leader )
	{
		dist = pathDistance( self.origin, potential_leader.origin );
		if ( isdefined( dist ) && dist < closest_distance )
		{
			closest_distance = dist;
			self.leader = potential_leader;
		}
	}
}

function get_potential_leaders( companion )
{
	closest_leader = [];
	foreach ( player in level.players )
	{
		if ( !isDefined( player.eligible_leader ) )
			player.eligible_leader = 1;
		
		if ( isdefined( player.eligible_leader ) && player.eligible_leader && companion findPath( companion.origin, player.origin ) )
			closest_leader[ closest_leader.size ] = player;
		
	}
	return closest_leader;
}