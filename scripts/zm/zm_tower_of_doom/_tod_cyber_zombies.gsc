// Cyber appearance is owned by the character asset, including every gib model.
// Select its factory in every mode, before stock spawn initialization.
#using scripts\shared\callbacks_shared;
#using scripts\shared\ai\systems\gib;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\ai\systems\gib.gsh;

#precache( "xmodel", "c_zom_der_zombie_head1" );
#precache( "xmodel", "tod_cyber_sprinter_head1" );
#precache( "xmodel", "tod_cyber_sprinter_head2" );
#precache( "xmodel", "tod_cyber_sprinter_head3" );

#namespace tod_cyber_zombies;

function install_spawn_filter()
{
	// _zm_spawner::init consumes this during zm_usermap::main, before it
	// registers spawn functions. Both factories retain native character/gibs.
	level.ignore_spawner_func = &ignore_spawner;
}

function ignore_spawner( spawner )
{
	if ( !isdefined( spawner.script_string ) )
		return false;
	if ( spawner.script_string == "tod_cyber_dev" )
		return false; // Historical map marker; appearance is now enabled in all modes.
	if ( spawner.script_string == "tod_cyber_stock" )
		return true;
	return false;
}

function init()
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	level.tod_cyber_dev_seen = 0;
	level.tod_cyber_dev_tracked = 0;
	dev_log( "START rev=8 regular_refs=1,2 armored_ref=3 dev_only=0 appearance_slots=4_of_4 native_character=1 native_gibs=1 armored_walk=arms_down_v1 back_spikes=1.30 helmet=executioner_enclosed_v1 finish=shared_worn_gunmetal_v1 tank=removed eye_strength=14 eye_core=16 factories=" + level.zombie_spawners.size );
	callback::on_ai_spawned( &on_spawned );
}

// Cosmetic roster detection; no gameplay or dismemberment decisions live here.
function is_cyber_body( model )
{
	return model == "tod_cyber_body" || model == "tod_cyber_trooper_body"
		|| model == "tod_cyber_relay_body" || model == "tod_cyber_sprinter";
}

function log_sprinter_promotion()
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	dev_log( "ELITE_PROMOTE ent=" + self GetEntityNumber() + " body=" + value( self.model )
		+ " head=" + value( self.head ) + " headgone=" + value( self.head_gibbed )
		+ " model_scale=1.33 helmet=executioner_enclosed_v1 finish=shared_worn_gunmetal_v1 mouth_guard=integrated_folded_jaw_v2 tank=removed sword_arms=elbow_to_tip_spikes_v3 eye_strip=executioner_red_14_v1 eye_strength=14 eye_core=16 forehead_shield=removed back_spikes=1.30 walk=arms_down_v1" );
}

// Same original head identity, with reference-three equipment only on sprinters.
// Keep the mapping explicit: an unknown or absent attachment is never guessed.
function armored_head_for( head )
{
	if ( !isdefined( head ) )
		return undefined;
	if ( head == "tod_cyber_head" || head == "tod_cyber_hhead1" || head == "c_zom_der_zombie_head1" )
		return "tod_cyber_sprinter_head1";
	if ( head == "tod_cyber_hhead2" || head == "tod_cyber_bhead2" || head == "c_zom_der_zombie_head2" )
		return "tod_cyber_sprinter_head2";
	if ( head == "tod_cyber_hhead3" || head == "tod_cyber_bhead3" || head == "c_zom_der_zombie_head3" )
		return "tod_cyber_sprinter_head3";
	return undefined;
}

function apply_sprinter_equipment()
{
	if ( IS_TRUE( self.head_gibbed ) || GibServerUtils::IsGibbed( self, GIB_TORSO_HEAD_FLAG ) )
	{
		dev_log( "ELITE_KIT_SKIP ent=" + self GetEntityNumber() + " reason=head_removed" );
		return;
	}
	old_head = GIB_HEAD_MODEL( self );
	new_head = armored_head_for( old_head );
	if ( !isdefined( new_head ) )
	{
		dev_log( "ELITE_KIT_SKIP ent=" + self GetEntityNumber() + " reason=unknown_head head=" + value( old_head ) );
		return;
	}
	// There is no wait between detach and attach; keep both stock gib-data layouts in sync.
	hat = GIB_HAT_MODEL( self );
	if ( isdefined( hat ) && hat != "" )
		self Detach( hat, "" );
	self Detach( old_head, "" );
	self Attach( new_head, "" );
	self.head = new_head;
	self.hatmodel = undefined;
	if ( isdefined( self.gib_data ) )
	{
		self.gib_data.head = new_head;
		self.gib_data.hatmodel = undefined;
	}
	dev_log( "ELITE_KIT ent=" + self GetEntityNumber() + " ref=3 old=" + old_head + " new=" + new_head + " hat=" + value( hat ) );
}

function on_spawned()
{
	self thread inspect_spawn();
}

function inspect_spawn()
{
	self endon( "death" );
	// Native character assignment runs after on_ai_spawned dispatch.
	wait 0.1;
	if ( !isdefined( self.archetype ) || self.archetype != "zombie" )
		return;
	level.tod_cyber_dev_seen++;
	if ( !is_cyber_body( self.model ) )
	{
		if ( level.tod_cyber_dev_seen <= 8 )
			dev_log( "STOCK ent=" + self GetEntityNumber() + " body=" + value( self.model ) + " hp=" + self.health );
		return;
	}
	if ( level.tod_cyber_dev_tracked >= 24 )
		return;
	level.tod_cyber_dev_tracked++;
	dev_log( "SPAWN ent=" + self GetEntityNumber() + " body=" + self.model
		+ " head=" + value( self.head ) + " hp=" + self.health
		+ " gibdef=" + value( self.gibdef ) + " no_gib=" + value( self.no_gib ) );
	self thread inspect_death();
	previous = "";
	while ( isdefined( self ) )
	{
		state = value( self.model ) + "/" + value( self.gib_state ) + "/" + value( self.head_gibbed );
		if ( state != previous )
		{
			dev_log( "STATE ent=" + self GetEntityNumber() + " body/gib/headgone=" + state );
			previous = state;
		}
		wait 0.25;
	}
}

function inspect_death()
{
	num = self GetEntityNumber();
	self waittill( "death" );
	if ( isdefined( self ) )
		dev_log( "DEATH ent=" + num + " body=" + value( self.model )
			+ " gib=" + value( self.gib_state ) + " headgone=" + value( self.head_gibbed ) );
}

function value( v )
{
	if ( !isdefined( v ) )
		return "unset";
	return "" + v;
}

function dev_log( text )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	msg = "[TOD_CYBER] t=" + GetTime() + " " + text;
	/# PrintLn( msg ); #/
}
