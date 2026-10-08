// Native machine animation sequences from the installed WetEgg SAT pack.
// Uses stock perk_purchased (the pack's activateMachineFX event does not exist
// in vanilla _zm_perks). Always use the trigger's current machine pointer.
// AnimScripted is stopped BEFORE scatter writes an origin or starts MoveTo.
//
// 2026-09-23 (v19.44) - THE VOLLEY NEVER FIRED: the user's log showed the fire
// clip's wait returning in the SAME frame it started (ANIM_START/ANIM_DONE both
// ms=188100, VOLLEY shots=0) while the intro and outro ran their full 1.2 s and
// 5.1 s. The fire clip is the only one carrying script notes ("Self Notify"
// x16), and a note in an AnimScripted clip wakes the clip's OWN done-notify
// (stock's DoNoteTracks/waittillmatch( done, "end" ) idiom exists for exactly
// this), so `waittill( done )` returned on the frame-1 note, the sequence moved
// to the outro, and the listener died on its endon before any shot notify could
// reach it. Two rules now: (1) a clip is finished ONLY when the done-notify
// carries "end"; (2) the 16 traces are SCHEDULED from the clip's start on its
// authored shot frames (`volley_frames`, lockstep with the GDT / importer) and
// never driven by the notes. The notes stay in the GDT for the client-side
// gunshot/flash cues; `doubletap_note_probe` only records whether a Self Notify
// ever reaches script by name, for the record.
//
// 2026-09-23 (v19.48) - THE COWBOY AIMS. The first real volley (user: "I did
// hear the shots now ... didn't see it work") fired all sixteen shots on their
// frames and hit NOTHING: `hit=0` x16, fractions 0.77 / 0.07 / 1.0 = the far
// wall, the near wall and the open window. Every trace left the muzzle in ONE
// fixed level line, and a zombie is never standing in that line. A shot now
// PICKS its zombie (`volley_target`: nearest in the barrel's front fan, on this
// deck, with a clear world-only sight line to its chest) and the level trace is
// only the fallback for an empty room. The same log proved the SELF_NOTE lane:
// a "Self Notify" note DOES deliver `self notify( <note>, <param> )` on the
// script_model (sixteen SELF_NOTE lines, alternating muzzles) as well as waking
// the done-notify; the schedule stays the owner because it is gate-tested.
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#insert scripts\shared\shared.gsh;

#precache( "xanim", "p9_fxanim_zm_gp_speed_cola_initiate" );
#precache( "xanim", "p9_fxanim_zm_gp_speed_cola_initiate_off" );
#precache( "xanim", "p9_fxanim_zm_gp_speed_cola_loop" );
#precache( "xanim", "t10_fxanim_zm_machine_d_mod_idle" );
#precache( "xanim", "tod_doubletap_intro" );
#precache( "xanim", "tod_doubletap_fire" );
#precache( "xanim", "tod_doubletap_outro" );
#precache( "xanim", "anim_68e0495f3599ef44" );
#precache( "xanim", "tod_wisp_activate" );
#using_animtree( "tod_perk_machines" );
#namespace tod_perk_anims;

// Donor projectile damage and maximum travel (2500 units/s * 5 seconds).
// Tower traces these shots to avoid adding another registered weapon asset.
#define TOD_DOUBLE_TAP_DAMAGE 10000
#define TOD_DOUBLE_TAP_RANGE 12500
// The fire clip runs at 30 fps; a shot frame f lands f/30 s after AnimScripted.
#define TOD_DOUBLE_TAP_FPS 30
// A trace that starts inside the machine's stock collision clip (or the gun's
// own bullet mesh) returns fraction 0 at its start; the retry begins this far
// down the barrel, clear of any vending footprint.
#define TOD_DOUBLE_TAP_RETRY_STEP 32
// v19.48 - the aimed shot. A candidate is a live zombie within RANGE, within
// AIM_DZ of the muzzle's height (this deck, not the flight below) and inside
// the front fan of the barrel (the flat direction to it dots the barrel's
// heading at AIM_COS or better = 70 degrees either side). Nearest first; a
// candidate behind cover is passed over for the next-nearest, AIM_TRIES times.
// The sight line runs to AIM_Z above the zombie's feet and is world-only, so a
// player standing in front of the machine never shields the zombie behind them.
#define TOD_DOUBLE_TAP_AIM_COS 0.342
#define TOD_DOUBLE_TAP_AIM_Z 40
#define TOD_DOUBLE_TAP_AIM_DZ 200
#define TOD_DOUBLE_TAP_AIM_TRIES 3
#define TOD_DOUBLE_TAP_LOS_FRAC 0.95

function dev_log( message )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_PERK_ANIM] ms=" + GetTime() + " " + message;
	/# PrintLn( line ); #/
}

function init()
{
	level.tod_perk_anim_move = &pause_for_move;
	level.tod_perk_anim_retire = &retire;
	callback::on_spawned( &on_player_spawned );
	level thread discover();
	dev_log( "INIT rev=4 shots=" + volley_frames().size + " lane=aimed damage=" + TOD_DOUBLE_TAP_DAMAGE + " sound_rows=14" );
}

function kind_for( specialty )
{
	if ( specialty == "specialty_fastreload" ) return "speed";
	if ( specialty == "specialty_doubletap2" ) return "doubletap";
	if ( specialty == "specialty_nomotionsensor" ) return "wisp";
	return undefined;
}

function powered( trigger )
{
	if ( !isdefined( trigger ) || !isdefined( trigger.machine )
	  || !isdefined( trigger.script_noteworthy ) || !IS_TRUE( trigger.power_on ) )
		return false;
	spec = trigger.script_noteworthy;
	if ( !isdefined( level.machine_assets ) || !isdefined( level.machine_assets[ spec ] ) )
		return false;
	return ( trigger.machine.model == level.machine_assets[ spec ].on_model );
}

function discover()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	for ( ;; )
	{
		foreach ( t in GetEntArray( "zombie_vending", "targetname" ) )
			bind( t );
		wait 1;
	}
}

function bind( trigger )
{
	if ( !isdefined( trigger.machine ) || !isdefined( trigger.script_noteworthy ) )
		return;
	kind = kind_for( trigger.script_noteworthy );
	if ( !isdefined( kind ) || isdefined( trigger.machine.tod_perk_anim_kind ) )
		return;
	trigger.machine.tod_perk_anim_kind = kind;
	dev_log( "BIND kind=" + kind + " machine=" + trigger.machine GetEntityNumber() + " origin=" + trigger.machine.origin );
	trigger.machine thread machine_watch( trigger );
}

function machine_watch( trigger )   // self = actual machine model
{
	self endon( "entityshutdown" );
	self endon( "tod_perk_anim_retired" );
	level endon( "end_game" );
	last_power = undefined;
	last_model = undefined;
	for ( ;; )
	{
		if ( IS_TRUE( self.tod_perk_anim_retired ) || !isdefined( trigger )
		  || !isdefined( trigger.machine ) || trigger.machine != self )
		{
			self stop();
			return;
		}
		if ( !IS_TRUE( self.tod_perk_anim_moving ) )
		{
			on = powered( trigger );
			if ( IS_TRUE( level.tod_upgrade_pause ) && IS_TRUE( self.tod_perk_anim_busy ) )
			{
				dev_log( "CANCEL reason=world_pause machine=" + self GetEntityNumber() );
				self stop();
				self.tod_perk_anim_resume = true;
			}
			power_changed = !isdefined( last_power ) || last_power != on;
			if ( power_changed || !isdefined( last_model ) || last_model != self.model
			  || IS_TRUE( self.tod_perk_anim_resume ) )
			{
				dev_log( "REST kind=" + self.tod_perk_anim_kind + " machine=" + self GetEntityNumber() + " power=" + on + " model=" + self.model );
				self stop();
				self.tod_perk_anim_resume = false;
				self thread rest_pose( on, power_changed );
				last_power = on;
				last_model = self.model;
			}
		}
		wait 0.1;
	}
}

function stop()
{
	if ( IS_TRUE( self.tod_perk_anim_busy ) )
		dev_log( "CANCEL machine=" + self GetEntityNumber() + " phase=" + self.tod_perk_anim_phase + " shots=" + self.tod_perk_anim_shots + " hits=" + self.tod_perk_anim_hits );
	self notify( "tod_perk_anim_cancel" );
	self.tod_perk_anim_busy = false;
	self.tod_perk_anim_firing = false;
	if ( IS_TRUE( self.tod_perk_anim_playing ) )
	{
		self StopAnimScripted( 0, true );
		self.tod_perk_anim_playing = false;
	}
}

function play( animation, done, wait_end )
{
	self UseAnimTree( #animtree );
	self.tod_perk_anim_playing = true;
	if ( wait_end )
	{
		self.tod_perk_anim_phase = animation;
		dev_log( "ANIM_START machine=" + self GetEntityNumber() + " clip=" + animation );
		self thread animation_timeout( animation, done );
	}
	self AnimScripted( done, self.origin, self.angles, animation );
	if ( wait_end )
	{
		// Every script note in the clip arrives on this same notify with the
		// note as its argument (the fire clip's frame-1 note ended the old
		// bare waittill in 0 ms). Only "end" finishes the clip.
		for ( ;; )
		{
			self waittill( done, note );
			if ( !isdefined( note ) ) note = "undefined";
			if ( note == "end" ) break;
			dev_log( "NOTE machine=" + self GetEntityNumber() + " clip=" + animation + " note=" + note );
		}
		self notify( "tod_perk_anim_clip_over" );
		dev_log( "ANIM_DONE machine=" + self GetEntityNumber() + " clip=" + animation );
	}
}

function animation_timeout( animation, done )
{
	self endon( "entityshutdown" );
	self endon( "tod_perk_anim_cancel" );
	self endon( "tod_perk_anim_clip_over" );
	level endon( "end_game" );
	// Longest finite clip is Speed Cola's 10.7-second power-on. AnimScripted uses string names;
	// GetAnimLength expects an animation value, so do not pass that string to it.
	wait 15;
	dev_log( "ANIM_TIMEOUT machine=" + self GetEntityNumber() + " clip=" + animation );
	// Stop the stuck purchase and let the power watcher restore the idle pose.
	self.tod_perk_anim_resume = true;
	self stop();
}

function rest_pose( on, power_changed )
{
	self endon( "entityshutdown" );
	self endon( "tod_perk_anim_cancel" );
	level endon( "end_game" );
	kind = self.tod_perk_anim_kind;
	if ( kind == "speed" )
	{
		if ( on )
		{
			if ( power_changed )
				self play( "p9_fxanim_zm_gp_speed_cola_initiate", "tod_speed_on_done", true );
			self play( "p9_fxanim_zm_gp_speed_cola_loop", "tod_speed_loop_done", false );
		}
		else
			self play( "p9_fxanim_zm_gp_speed_cola_initiate_off", "tod_speed_off_done", false );
	}
	else if ( kind == "doubletap" )
		self play( "t10_fxanim_zm_machine_d_mod_idle", "tod_doubletap_idle_done", false );
	else if ( kind == "wisp" && on )
		self play( "anim_68e0495f3599ef44", "tod_wisp_idle_done", false );
}

function on_player_spawned()
{
	if ( IS_TRUE( self.tod_perk_anim_purchase_watch ) ) return;
	self.tod_perk_anim_purchase_watch = true;
	self thread purchase_watch();
}

function purchase_watch()   // self = buyer
{
	self endon( "disconnect" );
	level endon( "end_game" );
	for ( ;; )
	{
		self waittill( "perk_purchased", specialty );
		kind = kind_for( specialty );
		if ( !isdefined( kind ) || kind == "speed" ) continue;
		foreach ( t in GetEntArray( "zombie_vending", "targetname" ) )
		{
			if ( !isdefined( t.script_noteworthy ) || t.script_noteworthy != specialty ) continue;
			bind( t );
			if ( !powered( t ) || IS_TRUE( t.machine.tod_perk_anim_moving )
			  || IS_TRUE( t.machine.tod_perk_anim_retired ) || IS_TRUE( t.machine.tod_perk_anim_busy )
			  || IS_TRUE( level.tod_upgrade_pause ) )
			{
				dev_log( "BUY_SKIP kind=" + kind + " buyer=" + self GetEntityNumber() + " powered=" + powered( t ) + " moving=" + IS_TRUE( t.machine.tod_perk_anim_moving ) + " busy=" + IS_TRUE( t.machine.tod_perk_anim_busy ) + " paused=" + IS_TRUE( level.tod_upgrade_pause ) );
				continue;
			}
			t.machine stop();
			t.machine thread purchase_sequence( self, t );
			break;
		}
	}
}

function purchase_sequence( buyer, trigger )
{
	self endon( "entityshutdown" );
	self endon( "tod_perk_anim_cancel" );
	level endon( "end_game" );
	self.tod_perk_anim_busy = true;
	self.tod_perk_anim_shots = 0;
	self.tod_perk_anim_hits = 0;
	dev_log( "BUY kind=" + self.tod_perk_anim_kind + " machine=" + self GetEntityNumber() + " buyer=" + buyer GetEntityNumber() );
	if ( self.tod_perk_anim_kind == "doubletap" )
	{
		self play( "tod_doubletap_intro", "tod_doubletap_intro_done", true );
		self.tod_perk_anim_firing = true;
		// The volley is scheduled from the clip's start (this frame), one trace
		// per authored shot frame; the clip's notes only feed the client cues.
		self thread doubletap_note_probe();
		self thread doubletap_volley( buyer, trigger, GetTime() );
		self play( "tod_doubletap_fire", "tod_doubletap_loop_done", true );
		self.tod_perk_anim_firing = false;
		self notify( "tod_perk_anim_volley_over" );
		dev_log( "VOLLEY machine=" + self GetEntityNumber() + " shots=" + self.tod_perk_anim_shots + " expected=" + volley_frames().size + " hits=" + self.tod_perk_anim_hits );
		self play( "tod_doubletap_outro", "tod_doubletap_outro_done", true );
	}
	else if ( self.tod_perk_anim_kind == "wisp" )
		self play( "tod_wisp_activate", "tod_wisp_buy_done", true );
	self.tod_perk_anim_busy = false;
	dev_log( "BUY_DONE machine=" + self GetEntityNumber() + " kind=" + self.tod_perk_anim_kind );
	self rest_pose( powered( trigger ), false );
}

function shot_denial( buyer, trigger )
{
	if ( !IS_TRUE( self.tod_perk_anim_firing ) || !IS_TRUE( self.tod_perk_anim_busy ) ) return "inactive";
	if ( IS_TRUE( self.tod_perk_anim_moving ) || IS_TRUE( self.tod_perk_anim_retired ) ) return "moving_or_retired";
	if ( !powered( trigger ) || trigger.machine != self ) return "power_or_replaced";
	if ( IS_TRUE( level.tod_upgrade_pause ) ) return "world_pause";
	if ( !isdefined( buyer ) || !IsPlayer( buyer ) || !IsAlive( buyer ) ) return "buyer_gone";
	return "";
}

// The fire clip's authored shot frames (30 fps), left pistol first and then
// strictly alternating. LOCKSTEP with SHOTS in
// tools/import_perk_machine_presentation.py and the clip's GDT notes;
// tools/test_perk_anims.js and verify_perk_machine_presentation.py pin it.
function volley_frames()
{
	return array( 1, 8, 15, 21, 24, 27, 34, 35, 42, 43, 49, 52, 59, 61, 67, 70 );
}

function volley_muzzle( index )
{
	return ( ( ( index % 2 ) == 0 ) ? "j_pistol_le_muzzle" : "j_pistol_ri_muzzle" );
}

function volley_pistol( index )
{
	return ( ( ( index % 2 ) == 0 ) ? "j_pistol_le" : "j_pistol_ri" );
}

// Diagnostic only: records whether a "Self Notify" note ever reaches script
// by its own name. It never fires a shot; the scheduled volley owns those.
function doubletap_note_probe()
{
	self endon( "entityshutdown" );
	self endon( "tod_perk_anim_cancel" );
	self endon( "tod_perk_anim_volley_over" );
	level endon( "end_game" );
	for ( ;; )
	{
		self waittill( "tod_doubletap_shot", muzzle );
		if ( !isdefined( muzzle ) ) muzzle = "undefined";
		dev_log( "SELF_NOTE machine=" + self GetEntityNumber() + " muzzle=" + muzzle );
	}
}

// One trace per authored shot frame, timed from the fire clip's start.
function doubletap_volley( buyer, trigger, start_ms )
{
	self endon( "entityshutdown" );
	self endon( "tod_perk_anim_cancel" );
	self endon( "tod_perk_anim_volley_over" );
	level endon( "end_game" );
	frames = volley_frames();
	dev_log( "VOLLEY_START machine=" + self GetEntityNumber() + " start_ms=" + start_ms + " shots=" + frames.size );
	for ( i = 0; i < frames.size; i++ )
	{
		due = start_ms + int( ( frames[ i ] * 1000 ) / TOD_DOUBLE_TAP_FPS );
		remaining = due - GetTime();
		if ( remaining > 0 )
		{
			if ( remaining < 50 ) remaining = 50;
			wait ( remaining * 0.001 );
		}
		self doubletap_shot( buyer, trigger, i );
	}
}

// Is this entity a live zombie? Membership in the zombie team's AI array, the
// same call volley_target picks from. NEVER GetAIArray( "axis" ): the user's
// second log (v19.48) had the engine throw "parameter 2 does not exist" on it
// and "Object must be an array" on the foreach over its undefined result, on
// EVERY shot, so a correctly aimed and sighted zombie read hit=0 sixteen times.
// Stock calls GetAIArray() with no arguments; the team form is GetAITeamArray.
function enemy_actor( victim )
{
	if ( !isdefined( victim ) || !IsAlive( victim ) ) return false;
	team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
	foreach ( enemy in GetAITeamArray( team ) )
		if ( victim == enemy ) return true;
	return false;
}

// v19.48 - the zombie this shot is aimed at. self = the machine. Returns a
// struct: .ent = the target (undefined when nobody is in front), .trace = the
// world-only sight line that reached its chest, .dist = its distance, .checked
// = how many candidates were traced. Nearest first; a candidate behind cover is
// logged (SHOT_COVER) and passed over for the next-nearest. The sight line
// starts TOD_DOUBLE_TAP_RETRY_STEP down the line, clear of the machine's own
// footprint, and ignores the stock perk clip, so only the world can block it.
function volley_target( origin, direction, trigger )
{
	pick = SpawnStruct();
	pick.checked = 0;
	team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
	ai = GetAITeamArray( team );
	tried = [];
	for ( n = 0; n < TOD_DOUBLE_TAP_AIM_TRIES; n++ )
	{
		best = undefined;
		best_d = TOD_DOUBLE_TAP_RANGE;
		foreach ( z in ai )
		{
			if ( !isdefined( z ) || !IsAlive( z ) )
				continue;
			id = z GetEntityNumber();
			if ( isdefined( tried[ id ] ) )
				continue;
			if ( Abs( z.origin[ 2 ] - origin[ 2 ] ) > TOD_DOUBLE_TAP_AIM_DZ )
				continue;
			d = Distance( origin, z.origin );
			if ( d < 1 || d >= best_d )
				continue;
			to = z.origin - origin;
			flat = VectorNormalize( ( to[ 0 ], to[ 1 ], 0 ) );
			if ( flat[ 0 ] * direction[ 0 ] + flat[ 1 ] * direction[ 1 ] < TOD_DOUBLE_TAP_AIM_COS )
				continue;
			best = z;
			best_d = d;
		}
		if ( !isdefined( best ) )
			break;
		id = best GetEntityNumber();
		tried[ id ] = true;
		pick.checked++;
		chest = best.origin + ( 0, 0, TOD_DOUBLE_TAP_AIM_Z );
		line = VectorNormalize( chest - origin );
		blocker = self;
		if ( isdefined( trigger ) && isdefined( trigger.clip ) ) blocker = trigger.clip;
		from = origin + line * TOD_DOUBLE_TAP_RETRY_STEP;
		trace = BulletTrace( from, chest, false, blocker );
		if ( trace[ "fraction" ] >= TOD_DOUBLE_TAP_LOS_FRAC )
		{
			pick.ent = best;
			pick.trace = trace;
			pick.dist = best_d;
			return pick;
		}
		dev_log( "SHOT_COVER machine=" + self GetEntityNumber() + " candidate=" + id + " dist=" + int( best_d ) + " fraction=" + trace[ "fraction" ] );
	}
	return pick;
}

function doubletap_shot( buyer, trigger, index )
{
	reason = self shot_denial( buyer, trigger );
	if ( reason != "" )
	{
		dev_log( "SHOT_SKIP machine=" + self GetEntityNumber() + " n=" + ( index + 1 ) + " reason=" + reason );
		return;
	}
	muzzle = volley_muzzle( index );
	pistol = volley_pistol( index );
	self.tod_perk_anim_shots++;
	// The animated pistol root's +X is the barrel (the muzzle tag has an
	// identity bind rotation). Its heading follows the cowboy's aim; its pitch
	// swings up to 9 degrees over the clip, so the shot is levelled at muzzle
	// height, the way the donor fired its projectiles.
	origin = self GetTagOrigin( muzzle );
	aim = AnglesToForward( self GetTagAngles( pistol ) );
	direction = ( aim[ 0 ], aim[ 1 ], 0 );
	if ( Length( direction ) < 0.5 ) direction = AnglesToForward( ( 0, self.angles[ 1 ], 0 ) );
	direction = VectorNormalize( direction );
	// v19.48: the cowboy aims. The nearest zombie in the barrel's front fan
	// with a clear sight line takes the shot; the level trace is the fallback
	// for an empty room (and the only lane that can hit a player or a wall).
	pick = self volley_target( origin, direction, trigger );
	dist = -1;
	if ( isdefined( pick.ent ) )
	{
		stage = "aimed";
		trace = pick.trace;
		victim = pick.ent;
		dist = int( pick.dist );
	}
	else
	{
		stage = "level";
		trace = BulletTrace( origin, origin + direction * TOD_DOUBLE_TAP_RANGE, true, self );
		if ( trace[ "fraction" ] <= 0.0001 )
		{
			// Started inside a solid (the stock perk clip or the gun's own bullet
			// mesh): retry from clear air down the barrel, ignoring the clip.
			blocker = self;
			if ( isdefined( trigger.clip ) ) blocker = trigger.clip;
			retry_from = origin + direction * TOD_DOUBLE_TAP_RETRY_STEP;
			trace = BulletTrace( retry_from, retry_from + direction * TOD_DOUBLE_TAP_RANGE, true, blocker );
			stage = "retry";
		}
		victim = trace[ "entity" ];
	}
	hit = enemy_actor( victim );
	victim_id = -1;
	before = -1;
	after = -1;
	struck = "world";
	if ( isdefined( victim ) )
	{
		victim_id = victim GetEntityNumber();
		if ( isdefined( victim.classname ) ) struck = victim.classname;
	}
	if ( hit )
	{
		self.tod_perk_anim_hits++;
		before = victim.health;
		// Credit the buyer while isolating machine fire from held-weapon procs.
		victim.tod_perk_machine_hit = true;
		victim DoDamage( TOD_DOUBLE_TAP_DAMAGE, trace[ "position" ], buyer, self, "none", "MOD_PROJECTILE", 0, GetWeapon( "none" ) );
		if ( isdefined( victim ) )
		{
			victim.tod_perk_machine_hit = undefined;
			after = victim.health;
		}
	}
	dev_log( "SHOT machine=" + self GetEntityNumber() + " n=" + self.tod_perk_anim_shots + " muzzle=" + muzzle + " stage=" + stage + " candidates=" + pick.checked + " origin=" + origin + " direction=" + direction + " dist=" + dist + " struck=" + struck + " hit=" + hit + " fraction=" + trace[ "fraction" ] + " victim=" + victim_id + " hp=" + before + "->" + after );
}

// Called synchronously before scatter changes origin/angles or begins MoveTo.
function pause_for_move( seconds )
{
	self notify( "tod_perk_anim_move_restart" );
	self.tod_perk_anim_moving = true;
	self stop();
	self thread resume_after_move( seconds );
}

function resume_after_move( seconds )
{
	self endon( "entityshutdown" );
	self endon( "tod_perk_anim_move_restart" );
	self endon( "tod_perk_anim_retired" );
	level endon( "end_game" );
	if ( seconds < 0.05 ) seconds = 0.05;
	wait seconds;
	if ( IS_TRUE( self.tod_perk_anim_retired ) ) return;
	self.tod_perk_anim_moving = false;
	self.tod_perk_anim_resume = true;
}

function retire()
{
	self.tod_perk_anim_retired = true;
	self notify( "tod_perk_anim_retired" );
	self stop();
}
