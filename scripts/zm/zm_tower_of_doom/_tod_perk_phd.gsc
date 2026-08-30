// =============================================================================
// _tod_perk_phd.gsc — PhD FLOPPER, replacing Mule Kick on the crown.
//
// (user 2026-08-25: "We need to take out mule kick and replace with a perk that
// makes sense" -> "We can add PHD. Make sure all the UI is implemented
// correctly and everything. Its from Map 1 so we should be easy here".)
//
// WHY MULE KICK HAD TO GO, and it is not taste. Mule Kick's third weapon slot is
// NOT granted by its perk threads — those are empty — it comes from a direct
// HasPerk check inside stock get_player_weapon_limit (_zm_utility.gsc:5866).
// This map carries exactly two primaries by design (class gun + tier sidearm),
// runs with the stock too-many-weapons monitor DELIBERATELY OFF (v9.18), and
// _tod_upgrades::reconcile_twin's own comment names the hazard: "a third primary
// = the engine silently drops one: the inventory-overflow trap". Mule Kick was
// arming that trap on every player who bought it.
//
// WHY PhD FITS THIS MAP SPECIFICALLY: it is a 50-floor open-air tower with a
// 19,200-unit drop, so FALL DAMAGE is the signature hazard — and the heavy's
// tier-2 sidearm is an RPG with a 250-unit blast whose self-damage is a known,
// accepted sharp edge (see the RPG entry in tools/gen_tod_twins.js). PhD answers
// both with one perk.
//
// ---------------------------------------------------------------------------
// THE PIPELINE: registered OVER stock `specialty_electriccherry`, and that is
// free real estate ON THIS MAP even though it would not be on map 1.
//
// Read this before "fixing" the apparent contradiction: this map DOES have an
// Electric Cherry, but it lives on `specialty_combat_efficiency` — a from-
// scratch registration in _tod_perk_electric_cherry.gsc. The STOCK cherry
// specialty is therefore fully registered (the entry script #usings
// _zm_perk_electric_cherry for its tesla-FX functions, and its REGISTER_SYSTEM
// runs the whole 6-call chain) and COMPLETELY UNUSED. So PhD inherits a working
// machine/bottle/clientfield/power scaffold for free and collides with nothing.
//
// This is the same hijack map 1 used (_acc_perk_phd_flopper.gsc) — there it was
// forced, because specialty_phdflopper is a zero-init stub in BO3 with no stock
// ability and no shipped vending model. Nothing here changes that; we simply
// arrive at the same door from the other side.
//
// The perk's underlying specialty stays PERK_ELECTRIC_CHERRY for all
// HasPerk / rotation / HUD plumbing; only PRESENTATION (icon, name, hint, cost)
// and ABILITY are PhD.
//
// ---------------------------------------------------------------------------
// WHAT WAS DROPPED FROM MAP 1'S VERSION, deliberately:
//   * the MEGA tier ("PhD Slider") and its slide-to-explode nova — this map has
//     NO Mega Bottles (CLAUDE.md), so has_mega_perk has no meaning here. Map 1
//     gated the slide nova to Mega only, which means BASE PhD there behaved
//     exactly as it does here: immunity + explode-on-down.
//   * _acc_coop_scaling::regular_hp_mult() — that scaled the FROZEN Mega nova
//     damage, and there is no frozen Mega damage without a Mega tier.
// If you ever want the slide nova on base, map 1's phd_slide_watcher() is the
// recipe: trigger off the engine isSliding() (BO3 zombies has the sprint-slide
// but NO dolphin-dive), on a cooldown so it is not a spammable free AOE.
// =============================================================================

#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_perks.gsh;

// Roof perk, bought at the top of a 50-floor climb — priced with Mule Kick's
// old 4000, which the Aetherium perk card also displays. Change BOTH or the
// card lies about the price.
// PhD's machine identity. ONE NAME, THREE PLACES — the use trigger's `.target`,
// the machine's `.targetname` (both in phd_machine_setup) and the perk's
// `radiant_machine_name` (in install_machine_kvps). Stock resolves the machine
// AND its trigger through the last one, so if these ever disagree the perk goes
// unbuyable and strips itself. Same invariant _tod_perk_electric_cherry keeps
// with EC_RADIANT_MACHINE.
#define TOD_PHD_RADIANT_MACHINE "tod_vending_phd"
#define TOD_PHD_COST            2000   // 4000 -> 2000 (user 2026-08-27)
#define TOD_PHD_EXPLODE_RADIUS  220
#define TOD_PHD_EXPLODE_DAMAGE  1000

#namespace tod_perk_phd;

REGISTER_SYSTEM( "tod_perk_phd", &__init__, undefined )

function __init__()
{
	level thread install();
}

// Threaded: the stock cherry pipeline's own REGISTER_SYSTEM has to have run
// before level._custom_perks[ PERK_ELECTRIC_CHERRY ] exists to overwrite.
function install()
{
	level endon( "end_game" );

	// Wait for the pipeline rather than assume ordering between two autoexec
	// systems. Bounded: if the stock module is ever dropped from the entry
	// script's #usings, PhD disables itself instead of wedging a level thread.
	waited = 0;
	while ( ( !isdefined( level._custom_perks )
	       || !isdefined( level._custom_perks[ PERK_ELECTRIC_CHERRY ] ) ) && waited < 10 )
	{
		wait 0.1;
		waited += 0.1;
	}
	if ( !isdefined( level._custom_perks ) || !isdefined( level._custom_perks[ PERK_ELECTRIC_CHERRY ] ) )
		return;   // stock cherry pipeline missing — perk disabled, map still loads

	level._custom_perks[ PERK_ELECTRIC_CHERRY ].cost = TOD_PHD_COST;

	// HINT RECIPE, inherited from map 1's UI audit (2026-07-10): [{+activate}]
	// is the use key and &&1 is the COST substitution that stock SetHintString
	// fills in. Baking a literal cost here instead makes any discount invisible
	// on the wall — the machine would keep advertising the old number.
	level._custom_perks[ PERK_ELECTRIC_CHERRY ].hint_string = "Hold ^3[{+activate}]^7 for ^5PhD FLOPPER^7 [Cost: &&1]";

	// DIRECT OVERWRITE, not register_perk_threads: that helper only assigns when
	// the field is undefined, and the stock cherry pipeline has already set its
	// own. Same note map 1 carries.
	level._custom_perks[ PERK_ELECTRIC_CHERRY ].player_thread_give = &give_phd;
	level._custom_perks[ PERK_ELECTRIC_CHERRY ].player_thread_take = &take_phd;

	// ==========================================================================
	// THE MACHINE IDENTITY — AND STOCK'S IS STAMIN-UP'S, VERBATIM.
	// (user 2026-08-25: "We have an issue where phd is using staminup machine??")
	//
	// This is a Treyarch copy-paste bug, not ours. Compare the two stock files:
	//     _zm_perk_staminup.gsc:78-90        electric_cherry:115-127
	//     use_trigger.script_sound  = "mus_perks_stamin_jingle"      IDENTICAL
	//     use_trigger.script_string = "marathon_perk"                IDENTICAL
	//     use_trigger.script_label  = "mus_perks_stamin_sting"       IDENTICAL
	//     use_trigger.target        = "vending_marathon"             IDENTICAL
	//     perk_machine.script_string= "marathon_perk"                IDENTICAL
	//     perk_machine.targetname   = "vending_marathon"             IDENTICAL
	// `electric_cherry_perk_machine_setup` is a straight copy of
	// `staminup_perk_machine_setup` that nobody renamed. So ANY machine on the
	// cherry specialty takes the STAMIN-UP identity — same targetname, same
	// script_string, same jingle — and on this map that machine is PhD Flopper.
	// Two machines then answer to "vending_marathon", and the scatter resolves a
	// machine through `t.target` (_tod_perk_scatter, the GetEntArray at :298), so
	// the collision is not cosmetic.
	//
	// Same DIRECT OVERWRITE reason as the threads above: register_perk_machine
	// only assigns `perk_machine_set_kvps` when it is undefined, and stock's is
	// already in. Re-asserted here as a backstop; the AUTHORITATIVE call is the
	// one from the entry script — see install_machine_kvps().
	install_machine_kvps();

	// Explosion-on-down replaces stock cherry's electrocution-on-down. _zm skips
	// the standard laststand visionset for cherry holders, so re-apply it.
	level.custom_laststand_func = &phd_laststand;

	// The defining trait. Registered ONCE; _zm iterates every registered
	// override on player damage and the returned value REPLACES the damage.
	zm_perks::register_perk_damage_override_func( &phd_damage_override );
}

// ---------------------------------------------------------------------------
// THE MACHINE OVERRIDE HAS A DEADLINE, AND install() CANNOT GUARANTEE IT.
//
// `perk_machine_set_kvps` is consumed by `perk_machine_spawn_init()`, which runs
// SYNCHRONOUSLY inside `zm_perks::init()` — and `zm_perks::init()` is called from
// _zm.gsc's main "//Systems" block (:362). Once it has run, the machines are
// already built and overwriting the pointer afterwards does NOTHING AT ALL, with
// no error: the Stamin-Up identity just quietly ships.
//
// install() is `level thread`ed and CAN wait (it polls 0.1s at a time for the
// stock cherry pipeline to exist). If it ever takes that wait, it wakes up on the
// far side of zm_perks::init() and the override is too late. Today it happens not
// to — the stock cherry #using is at zm_tower_of_doom.gsc:47 and ours at :115, so
// the pipeline already exists on the first check and install() runs straight
// through — but that is an ORDERING ASSUMPTION between two autoexec systems, and
// the comment on install() itself says not to make one.
//
// So this is called DIRECTLY from zm_tower_of_doom.gsc::main(), before
// zm_usermap::main(). That is deterministic: every REGISTER_SYSTEM __init__ has
// finished by the time the entry script's main() body runs (so the pipeline
// exists), and zm_usermap::main() is what eventually reaches zm_perks::init()
// (so the machines are not built yet). It is the same "must be set BEFORE
// zm_usermap::main()" window that _zombie_custom_add_weapons uses a few lines up.
//
// Idempotent, so install() re-asserting it costs nothing.
// ---------------------------------------------------------------------------
function install_machine_kvps()
{
	if ( !isdefined( level._custom_perks ) || !isdefined( level._custom_perks[ PERK_ELECTRIC_CHERRY ] ) )
		return;
	level._custom_perks[ PERK_ELECTRIC_CHERRY ].perk_machine_set_kvps = &phd_machine_setup;

	// ==========================================================================
	// AND radiant_machine_name MUST MOVE WITH IT. Renaming the entities without
	// this made PhD UNBUYABLE — a worse bug than the one the rename fixed.
	//
	// `perk_machine_think` (_zm_perks.gsc:124-125) resolves BOTH halves of the
	// machine through this one name:
	//     machine          = getentarray( radiant_machine_name, "targetname" )
	//     machine_triggers = GetEntArray ( radiant_machine_name, "target"     )
	// Stock set it to "vending_electriccherry" via
	// register_perk_host_migration_params. Point the entities at
	// TOD_PHD_RADIANT_MACHINE and leave this behind, and both lookups return
	// EMPTY: the machine never gets SetModel/Solid/perk_fx, and — the fatal one —
	// `set_power_on(true)` (:148) never reaches the trigger. `.power_on` is
	// written nowhere else in this map, so it stays undefined, and
	// vending_trigger_post_think (:661) takes the `!IS_TRUE(self.power_on)`
	// branch: one second after you drink it, perk_pause UnsetPerk's PhD from
	// every player and has_perk_paused stops the machine re-selling it.
	//
	// This map's own Electric Cherry keeps the invariant (EC_RADIANT_MACHINE is
	// used for .target, .targetname AND the host-migration registration, see the
	// note at its ec_machine_setup). PhD now does the same. ONE NAME, THREE
	// PLACES — if you change it, change all three.
	level._custom_perks[ PERK_ELECTRIC_CHERRY ].radiant_machine_name = TOD_PHD_RADIANT_MACHINE;
}

// ---------------------------------------------------------------------------
// PhD's own machine identity, replacing the Stamin-Up copy-paste stock ships on
// the cherry specialty (see the block in init above).
//
// Every field has to move, not just the targetname:
//   target / targetname  — the collision that matters. The scatter finds a
//     machine by GetEntArray( t.target, "targetname" ), so while PhD answered to
//     "vending_marathon" it and the real Stamin-Up machine were the same lookup.
//   script_string        — read by the audio/bump plumbing to tell machines
//     apart; leaving it "marathon_perk" keeps them the same machine to anything
//     that keys on it.
//   script_sound/label   — the jingle and the sting. MULE KICK's are used here
//     because Mule Kick was retired from this map on 2026-08-25 (PhD replaced
//     it), so its aliases are real, shipped, and now unowned — the only free
//     jingle pair on the roster. Every other one belongs to a machine we sell.
// ---------------------------------------------------------------------------
function phd_machine_setup( use_trigger, perk_machine, bump_trigger, collision )
{
	use_trigger.script_sound   = "mus_perks_mulekick_jingle";
	use_trigger.script_string  = "tod_phd_perk";
	use_trigger.script_label   = "mus_perks_mulekick_sting";
	use_trigger.target         = TOD_PHD_RADIANT_MACHINE;
	perk_machine.script_string = "tod_phd_vending";
	perk_machine.targetname    = TOD_PHD_RADIANT_MACHINE;
	if ( isdefined( bump_trigger ) )
		bump_trigger.script_string = "tod_phd_vending";
}

// ---------------------------------------------------------------------------
// Fall + self-explosive immunity. self = the damaged player.
// Signature matches the 10-arg dispatch in _zm; return the final damage.
// ---------------------------------------------------------------------------
function phd_damage_override( e_inflictor, e_attacker, n_damage, str_flags, str_mod, w_weapon, v_point, v_dir, str_hit_loc, n_offset_time )
{
	if ( !( self HasPerk( PERK_ELECTRIC_CHERRY ) ) )
		return n_damage;

	switch ( str_mod )
	{
	case "MOD_FALLING":
	case "MOD_GRENADE":
	case "MOD_GRENADE_SPLASH":
	case "MOD_PROJECTILE":
	case "MOD_PROJECTILE_SPLASH":
	case "MOD_EXPLOSIVE":
	case "MOD_EXPLOSIVE_SPLASH":
		return 0;
	}
	return n_damage;
}

function give_phd()
{
	// Nothing per-player to start: the immunity is a level-wide damage override
	// gated on HasPerk, and the nova fires from the laststand hook. Kept as an
	// explicit empty give so the pipeline has a function to call and the pairing
	// with take_phd stays obvious.
}

function take_phd( b_pause, str_perk, str_result )
{
	self notify( "tod_phd_stop" );
}

// PhD-flavoured laststand: you flop, you go boom. self = player, threaded by _zm.
function phd_laststand()
{
	VisionSetLastStand( "zombie_last_stand", 1 );
	self phd_explode();
}

// The down-nova. self = player.
function phd_explode()
{
	self endon( "disconnect" );

	v_burst = self.origin;

	// VISUAL: the framework's stock ORANGE explosion. level._effect is populated
	// by the framework so this needs no #precache and no new asset — and it
	// carries its own boom, so it doubles as the sound. Guarded because an
	// unregistered handle would fatal PlayFX.
	// (Map 1 tried an electric-spark FX here first and the user reported it read
	// as sparks rather than an explosion — def_explosion is the right one.)
	if ( isdefined( level._effect ) && isdefined( level._effect[ "def_explosion" ] ) )
		PlayFX( level._effect[ "def_explosion" ], v_burst );
	Earthquake( 0.4, 0.75, v_burst, 400 );

	// Damage trash in radius. Scales with the round so it stays a real clear at
	// depth rather than a firework: the round's own zombie health is the floor.
	n_damage = TOD_PHD_EXPLODE_DAMAGE;
	if ( isdefined( level.zombie_health ) && level.zombie_health > n_damage )
		n_damage = level.zombie_health;

	n_radius_sq = TOD_PHD_EXPLODE_RADIUS * TOD_PHD_EXPLODE_RADIUS;
	zombies = GetAITeamArray( level.zombie_team );
	for ( i = 0; i < zombies.size; i++ )
	{
		z = zombies[ i ];
		if ( !isdefined( z ) || !IsAlive( z ) )
			continue;
		// BOSSES ARE EXEMPT — the map's standing boss-damage doctrine: their
		// damage is fixed and round-independent by design.
		if ( IS_TRUE( z.is_boss ) || IS_TRUE( z.acc_is_boss ) || IS_TRUE( z.acc_is_mini_boss ) )
			continue;
		if ( DistanceSquared( z.origin, v_burst ) > n_radius_sq )
			continue;
		z DoDamage( n_damage, v_burst, self );
	}
}
