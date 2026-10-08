// _tod_bat_inspect.gsc - THE BAT'S INSPECT, ON THE LOW-READY LANE (2026-10-02).
//
// User: "We also broke the inspect on the bat. Please fix. And i think we need to
// remove the lunge on the bat. We tried to fix multiple times where we can animate
// out of the lunge if we have a swing ready and same with inspect but just doesnt
// seem we can solve. If you can solve that would be great".
//
// THE HISTORY. The T9 bat port put its inspect clip (vm_t9_bat_inspect, 1.8 s) in
// reloadAnim: the RELOAD press played it, a reload cannot be cancelled from script,
// a pad's X is +usereload (the same button as every buy), and the blade could not
// swing while it ran. v19.68 (docs/167 item 5) took it OFF the reload lane - no
// reload animation, a one-frame reload. That fixed the buys and lost the inspect.
//
// THE LANE NOW. The same clip is ALSO the bat's lowReadyLoopAnim (port-authored:
// lowReadyLoopTime 1.8, in/out = the idle at 0 s). Low-ready is an engine WEAPON
// STATE that script enters and leaves at will - `self SetLowReady( true/false )`,
// which stock zombies itself uses (_zm_magicbox::give_hero_weapon lowers the blade
// while swapping back). So the inspect is: a reload press while holding the bat
// enters low-ready, the clip plays, and low-ready ends when the clip does. It is
// CANCELLABLE BY CONSTRUCTION: the hold is a script loop that leaves low-ready the
// frame the player presses attack / melee / sprint, switches weapon, goes down or
// has the weapons disabled (cards, the draft). The reload lane stays one-frame, so
// a pad's X at a door still BUYS - there is no reload left to block it.
//
// UNPROVEN until the user plays it (no agent launch, ever):
//   * that SetLowReady plays lowReadyLoopAnim on a melee-class weapon in a usermap
//     (the clip, its length and the state are all the engine's; nothing here
//     animates);
//   * whether the engine lets a swing interrupt low-ready on its own, or holds the
//     swing until the script leaves the state - the loop leaves it on the press
//     either way, so at worst the FIRST tap during an inspect raises the bat and
//     the next tap swings.
// If the clip does not play at all, the lane is wrong, not the timing: read the
// user's console for START/END pairs (they prove only that the script ran).
//
// Logs (tod_dev): [TOD_BAT_INSPECT] INIT / START / END reason= / DENY reason=.
#using scripts\shared\callbacks_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#namespace tod_bat_inspect;

#define TOD_BAT_INSPECT_STEM   "t9_me_baseballbat_"
#define TOD_BAT_INSPECT_SECS   1.8      // LOCKSTEP: lowReadyLoopTime on all 12 bat forms (tools/test_baseball_bat.js pins the pair)

function init()
{
	callback::on_spawned( &on_player_spawned );
	dev_log( "INIT rev=lowready_1 secs=" + TOD_BAT_INSPECT_SECS );
}

// self = player. One watcher per player for the whole game (survives respawns;
// ends on disconnect only) - the RUN AND GUN pattern.
function on_player_spawned()
{
	if ( IS_TRUE( self.tod_bat_inspect_watch ) )
		return;
	self.tod_bat_inspect_watch = true;
	self thread press_watch();
}

// self = player. Edge-detects the reload press (a keyboard's R, a pad's X).
function press_watch()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	last = false;
	for ( ;; )
	{
		WAIT_SERVER_FRAME;
		down = self ReloadButtonPressed();
		if ( down && !last )
			self inspect_try();
		last = down;
	}
}

// self = player. Every refusal is logged with its reason; a refusal is silent
// to the player on purpose (the press did nothing visible before v19.68 either
// unless the clip played).
function inspect_try()
{
	if ( IS_TRUE( self.tod_bat_inspecting ) )
		return;
	if ( !IsAlive( self ) || self laststand::player_is_in_laststand() )
		return;
	w = self GetCurrentWeapon();
	if ( !isdefined( w ) || w == level.weaponNone || !isdefined( w.name ) || !IsSubStr( w.name, TOD_BAT_INSPECT_STEM ) )
		return;
	if ( self IsSwitchingWeapons() || self IsThrowingGrenade() || self IsMeleeing() )
	{
		dev_log( "DENY reason=busy player=" + self GetEntityNumber() );
		return;
	}
	// A press that arrives WITH a swing never lowers the bat into the swing.
	if ( self AttackButtonPressed() || self MeleeButtonPressed() )
	{
		dev_log( "DENY reason=swinging player=" + self GetEntityNumber() );
		return;
	}
	if ( IS_TRUE( level.tod_upgrade_pause ) || !( self util::isWeaponEnabled() ) )
	{
		dev_log( "DENY reason=frozen player=" + self GetEntityNumber() );
		return;
	}
	self thread inspect_run( w );
}

// self = player. Enter low-ready, hold it for the clip, leave it - early on
// anything the player would rather be doing. No endon( "death" ): a death mid-
// inspect must still reach SetLowReady( false ), so the loop reads IsAlive.
function inspect_run( w )
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self.tod_bat_inspecting = true;
	self SetLowReady( true );
	t0 = GetTime();
	dev_log( "START player=" + self GetEntityNumber() + " weapon=" + w.name );

	reason = "done";
	while ( ( GetTime() - t0 ) < ( TOD_BAT_INSPECT_SECS * 1000 ) )
	{
		WAIT_SERVER_FRAME;
		if ( !IsAlive( self ) || self laststand::player_is_in_laststand() )
		{
			reason = "down";
			break;
		}
		if ( self AttackButtonPressed() || self MeleeButtonPressed() )
		{
			reason = "swing";
			break;
		}
		if ( self SprintButtonPressed() )
		{
			reason = "sprint";
			break;
		}
		cur = self GetCurrentWeapon();
		if ( !isdefined( cur ) || cur != w || self IsSwitchingWeapons() )
		{
			reason = "weapon_change";
			break;
		}
		if ( IS_TRUE( level.tod_upgrade_pause ) || !( self util::isWeaponEnabled() ) )
		{
			reason = "frozen";
			break;
		}
	}

	self SetLowReady( false );
	self.tod_bat_inspecting = false;
	dev_log( "END player=" + self GetEntityNumber() + " reason=" + reason + " held_ms=" + ( GetTime() - t0 ) );
}

function dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_BAT_INSPECT] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
