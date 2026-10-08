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

// v16.78 THE COMBO TELL — three stock FX, all pcloud-free (the TOD_PHD_FX_*
// defines below). Each needs this #precache AND its `fx,` line in zone_source,
// or PlayFX no-ops in silence (the ambient-fx lane rule).
#precache( "fx", "zombie/fx_trail_rpg_purple_doa" );
#precache( "fx", "zombie/fx_raygun_impact_purple_doa" );
#precache( "fx", "zombie/fx_exp_rpg_purple_doa" );

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

// ---------------------------------------------------------------------------
// PhD GRENADES (v16.48, user 2026-09-02: "PHD is not that important on this
// map. Can we add PHD grenades then? Typically grenades get a buff when this
// happens on other custom maps").
//
// The honest read of PhD on this map: fall immunity matters on a 50-floor
// tower, self-explosive immunity matters to exactly one sidearm (the heavy's
// RPG), and the down-flop fires once per down. A perk you buy on the roof
// deserves a reason to exist every round. So: while you hold PhD, every LETHAL
// grenade you throw detonates as a flop nova at its impact point — the perk's
// own explosion FX + earthquake, and every non-boss zombie within
// TOD_PHD_EXPLODE_RADIUS takes TOD_PHD_GRENADE_HEALTH_FRAC of the round's
// zombie health (floor TOD_PHD_EXPLODE_DAMAGE) ON TOP of the frag's own
// damage. At 0.5 two frags clear a crowd at any round; the down-flop keeps its
// full 1.0. Kill credit is the thrower's (DoDamage attacker), so points, luck
// and the elite reward flow as for any grenade kill.
//
// HOW IT IS WIRED: give_phd threads phd_grenade_watcher on the holder; it
// listens on the engine's "grenade_fire" (grenade, weapon) notify — the same
// contract stock's beginGrenadeTracking rides — keeps ONLY the player's lethal
// (zm_utility::get_player_lethal_grenade; the tactical is DISTRACTION's decoy
// and must stay a decoy), and threads phd_grenade_track ON THE GRENADE so a
// deleted grenade ends the wait instead of leaking a thread. take_phd's
// existing "tod_phd_stop" notify ends the watcher, and a HasPerk check at the
// explosion covers a perk lost mid-flight. Self-damage is already zero through
// phd_damage_override, so the classic feet-frag works.
// ---------------------------------------------------------------------------
#define TOD_PHD_GRENADE             1     // 1 = a PhD holder's lethal grenades detonate as flop novas; 0 = the v16.47 perk (immunity + down-flop only)
#define TOD_PHD_GRENADE_HEALTH_FRAC 0.5   // fraction of the round's zombie health the grenade nova deals (the down-flop deals 1.0); floor TOD_PHD_EXPLODE_DAMAGE
// v16.57 PhD + WIDOW'S WINE (user 2026-09-02: "PHD Flopper Widow's Wine combo
// doesn't work. Typically they will expand out into children and turn into
// like a web of grenades"): a holder of BOTH perks throws a Widow's grenade
// that, at its impact, SPLITS into child Widow's grenades launched in an even
// ring (MagicGrenadeType as the thrower — the same call stock's
// contact-explosion lane uses, so kills, cocoons and the elite reward credit
// the player), each detonating on its own short fuse into its own web — a web
// of grenades around the flop nova. Children are FREE (no clip cost). Gated on
// the thrown weapon BEING the Widow's grenade (stock swaps it in as the lethal
// on the buy), not on the perk alone.
//
// v16.70 THE NEST IS EXPLICIT AND BOUNDED (user 2026-09-03: "I think we have
// them infinite and they should nest at 3 levels max"). v16.57 claimed the
// children "NEVER split again: MagicGrenadeType raises no grenade_fire on the
// player, so the watcher never sees them — no recursion by construction". That
// was an assumption about the engine that nobody had watched hold, and the
// first real throw is the evidence against it: if the engine DOES raise
// "grenade_fire" for a script-launched grenade (it is the owner's grenade, and
// stock's own multi-detonation lane in shared/weapons/_weapons.gsc guards its
// children by giving them a DIFFERENT weapon, not by trusting silence), every
// child was a fresh lethal to the watcher — 6 more per burst per second,
// without end. So the recursion is now DECLARED, not inferred from what the
// engine will or will not notify:
//   * every tracked grenade carries its GENERATION: 1 = the thrown grenade,
//     2 = its children, 3 = theirs. A grenade splits only while its generation
//     is below TOD_PHD_WIDOW_DEPTH, so the cascade is finite by arithmetic;
//   * CHILDREN ARE RECOGNISED BY A STAMP ON THE ENTITY, never by timing.
//     v16.70 tried "one tracker per grenade, last one wins": the split
//     threaded its tracker AFTER MagicGrenadeType returned, betting that any
//     grenade_fire the engine raised for the child had already fired. The
//     v16.72 build proved the bet wrong (user: "I threw one and it never
//     stopped spreading"): the engine DOES raise grenade_fire for a
//     script-launched grenade, and it raises it LATER — on a following
//     frame — so the watcher's generation-1 tracker arrived last, won the
//     dedupe, and every child was a fresh throw again. Now (v16.78):
//       - phd_widow_split stamps `child.tod_phd_gen` on the entity the
//         MagicGrenadeType call returns (stock reads that return value too,
//         _zm_craftables.gsc:883), and the watcher SKIPS any grenade that
//         already carries the stamp — the deferred notify finds it tagged;
//       - for the other ordering (a notify raised INSIDE the call, before the
//         stamp can land) the split declares how many children it is about to
//         launch (`tod_phd_child_pending`, a TOD_PHD_WIDOW_CHILD_WINDOW_MS
//         window) and the watcher consumes those first;
//       - and phd_grenade_track REFUSES TO DOWNGRADE: a tracker may never set
//         a lower generation than the entity already carries, so a stray
//         generation-1 tracker on a stamped child is a no-op. Three
//         independent layers; the cascade needs all three to fail at once;
//   * the flop nova fires for the THROWN grenade only. A nova per child was
//     the other half of what made the runaway cascade unplayable — 25 novas at
//     half the round's health each is not a perk, it is a wipe button.
// v16.72 (user 2026-09-03: "the widow's grenade when you also have phd will
// explode into 8 minigrenades when it explodes that also explode"): EIGHT on
// the first burst. Searched for a source to match — BO3 stock and Zombies
// Chronicles (Widow's REPLACED PhD there), BO6 (no Widow's), BO7 (both perks,
// eight augments each: PhD = Double Whammy / Slider / Dr Ram / Gravity MD,
// Widow's = Tangled Web / Web Spinner / Hatchling (a spider ally) / Widow's
// Bite + minors), the Modme and Workshop PhD packs — nothing anywhere splits
// a Widow's grenade. The nearest official thing is BO4's Cluster Grenade (one
// lethal → a ring of minis that each explode), which is the shape built here.
// "MINI" IS NOT LITERAL: a child is a full Widow's grenade (same model, blast
// and web) launched by MagicGrenadeType; a physically smaller child needs a
// second weapon asset, and the weapon ledger sits at its 223/224 ceiling
// (LEDGER_GUARD, tools/gen_tod_twins.js) — not a lane this map has.
// THE SHIPPED SHAPE (user 2026-09-03, final word: "one grenade and 8 children
// when you have both perks. No more. So 9 total"): DEPTH 2 — the thrown
// grenade bursts into a ring of eight, each of those bursts into its own web,
// and that is the end of it. 1 + 8 = 9 grenades / 9 webs, all within ~1 s.
// The generation machinery above is what makes "no more" a fact rather than a
// hope; DEPTH 3 + CHILDREN_DEEP is the deeper nest if it is ever wanted back.
#define TOD_PHD_WIDOW_COMBO         1     // 1 = the split; 0 = a Widow's grenade is just a flop nova
#define TOD_PHD_WIDOW_DEPTH         2     // generations that EXIST: 1 = no split, 2 = one ring and STOP (shipped), 3 = the ring splits once more
#define TOD_PHD_WIDOW_CHILDREN      8     // children per split at the FIRST split (the thrown grenade's burst), evenly spaced, random phase (user: "8 minigrenades")
#define TOD_PHD_WIDOW_CHILDREN_DEEP 2     // children per split at every DEEPER split (generation 2 and beyond) — UNUSED at DEPTH 2
#define TOD_PHD_WIDOW_SPEED         220   // outward launch speed of each child (u/s)
#define TOD_PHD_WIDOW_LIFT          160   // upward launch component (u/s) — a short lob, not a roll
#define TOD_PHD_WIDOW_FUSE          1.0   // seconds to each child's own detonation
// v16.78 THE COMBO TELL (user 2026-09-03: "with phd the web nades need a
// purple glow and explosion. That's the whole point, it's both combined and the
// purple small glow tells that"). Every combo grenade — the one thrown and
// each child — trails a small purple glow in flight (a looping trail FX on a
// tag_origin host LinkTo'd to the grenade: the map's proven server lane,
// derez_burst_run's; a bare PlayFXOnTag on a weapon model is the lane the perk
// glow found does not draw) and bursts purple: the thrown grenade's nova swaps
// its orange def_explosion for a purple RPG blast, each child pops a purple
// ray-gun impact over its web. A PhD holder's plain FRAG keeps the orange
// nova — the purple is the Widow's half of the handshake. All three are stock
// DOA/zombie FX, pcloud-free, colorGraph rows read (1, 0, 1) / (1, 0, 0.92) —
// checked, not assumed: zombie/fx_bmode_glow_hook_zod_zmb was the first pick
// for the glow and its rows read ORANGE (1, 0.54, 0).
#define TOD_PHD_WIDOW_GLOW            1     // 1 = purple trail + purple bursts on combo grenades; 0 = the stock web FX only
#define TOD_PHD_FX_TRAIL              "zombie/fx_trail_rpg_purple_doa"      // looping, magenta, size 1-15: the in-flight glow
#define TOD_PHD_FX_POP                "zombie/fx_raygun_impact_purple_doa"  // one-shot, purple, size 80-200: a child's burst
#define TOD_PHD_FX_BOOM               "zombie/fx_exp_rpg_purple_doa"        // one-shot RPG blast: the thrown grenade's nova, combo only
#define TOD_PHD_FX_BURST_HOST_SECS    2.0   // how long a burst's tag_origin host lives (the FX must outlive it, not the reverse)
#define TOD_PHD_WIDOW_CHILD_WINDOW_MS 500   // a declared-but-unseen child is forgotten after this — never let it eat the player's next real throw

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
		return 0;
	case "MOD_GRENADE":
	case "MOD_GRENADE_SPLASH":
	case "MOD_PROJECTILE":
	case "MOD_PROJECTILE_SPLASH":
	case "MOD_EXPLOSIVE":
	case "MOD_EXPLOSIVE_SPLASH":
		// SELF-inflicted only (bug review 2026-09-22, F16). Without the attacker
		// test this zeroed the Panzer's electroball and the Rogue Protector's
		// zap too — and every spire player holds PhD, so the King lost one of
		// his three attacks. The header always said "self-explosive immunity".
		if ( isdefined( e_attacker ) && e_attacker == self )
			return 0;
		if ( isdefined( e_inflictor ) && isdefined( e_inflictor.owner ) && e_inflictor.owner == self )
			return 0;
		return n_damage;
	}
	return n_damage;
}

function give_phd()
{
	// The immunity is a level-wide damage override gated on HasPerk and the
	// down-nova fires from the laststand hook; the grenade watcher (v16.48) is
	// the perk's only per-player state, and take_phd's "tod_phd_stop" ends it.
	if ( TOD_PHD_GRENADE )
		self thread phd_grenade_watcher();
}

// PhD GRENADES. self = player. One per holder (the notify/endon pair below
// makes a re-give safe); ends when the perk is taken or the player leaves.
function phd_grenade_watcher()
{
	self endon( "disconnect" );
	self endon( "tod_phd_stop" );
	self notify( "tod_phd_grenade_watch" );
	self endon( "tod_phd_grenade_watch" );

	for ( ;; )
	{
		self waittill( "grenade_fire", grenade, weapon );
		if ( !isdefined( grenade ) || !isdefined( weapon ) )
			continue;
		// LETHALS ONLY. The tactical is DISTRACTION's decoy (the Cymbal Monkey) and
		// must stay a decoy, not a bomb.
		lethal = self zm_utility::get_player_lethal_grenade();
		if ( !isdefined( lethal ) || lethal == level.weaponNone || weapon != lethal )
			continue;
		// v16.78 CHILDREN ARE NOT THROWS. A grenade phd_widow_split launched
		// carries `tod_phd_gen` (stamped on the entity MagicGrenadeType returned)
		// and already has its tracker; the engine raises grenade_fire for it a
		// frame later, and this is where that notify lands. Skip it — and count
		// it against the split's declared children so the pending window drains.
		if ( isdefined( grenade.tod_phd_gen ) )
		{
			self phd_child_seen();
			continue;
		}
		// The other ordering: a notify raised INSIDE the MagicGrenadeType call,
		// before the split could stamp the entity. The split declared how many
		// are coming; consume one.
		if ( self phd_child_seen() )
			continue;
		// Generation 1: a grenade the PLAYER threw. Stamp it so no later thread
		// can mistake it for anything else, and track it.
		grenade.tod_phd_gen = 1;
		grenade thread phd_grenade_track( self, weapon, 1 );
	}
}

// self = player. TRUE when a child the split declared is still owed a
// grenade_fire — and consumes it. The declaration expires after
// TOD_PHD_WIDOW_CHILD_WINDOW_MS so a notify the engine never sends cannot be
// charged to the player's next real throw.
function phd_child_seen()
{
	if ( !isdefined( self.tod_phd_child_pending ) || self.tod_phd_child_pending <= 0 )
		return false;
	if ( !isdefined( self.tod_phd_child_time ) || ( GetTime() - self.tod_phd_child_time ) > TOD_PHD_WIDOW_CHILD_WINDOW_MS )
	{
		self.tod_phd_child_pending = 0;
		return false;
	}
	self.tod_phd_child_pending--;
	return true;
}

// self = a tracked grenade, threaded ON it so a deleted grenade (a dud, a
// cleanup) ends the wait instead of leaking a thread. `player` is the thrower,
// `weapon` what it was thrown as, `n_gen` its generation (1 = thrown by the
// player; the define block owns the ladder).
function phd_grenade_track( player, weapon, n_gen )
{
	if ( !isdefined( n_gen ) )
		n_gen = 1;
	// NEVER DOWNGRADE (v16.78): the entity's stamp is the truth about what this
	// grenade is. A tracker arriving with a LOWER generation than the stamp is
	// the watcher mistaking a child for a throw — the exact error that ran away
	// twice — and it does nothing.
	if ( isdefined( self.tod_phd_gen ) && self.tod_phd_gen > n_gen )
		return;
	self.tod_phd_gen = n_gen;
	// One tracker per grenade: the last one started is the one that survives.
	self notify( "tod_phd_track" );
	self endon( "tod_phd_track" );

	// THE COMBO: a Widow's grenade in the hands of a player holding both perks.
	// Decided at launch so the in-flight tell can start now.
	b_combo = ( TOD_PHD_WIDOW_COMBO && isdefined( player ) && isdefined( weapon )
	  && isdefined( level.w_widows_wine_grenade ) && weapon == level.w_widows_wine_grenade
	  && ( player HasPerk( PERK_WIDOWS_WINE ) ) && ( player HasPerk( PERK_ELECTRIC_CHERRY ) ) );
	host = undefined;
	if ( b_combo && TOD_PHD_WIDOW_GLOW )
		host = self phd_glow_host();

	self waittill( "explode", v_pos );
	if ( !isdefined( v_pos ) && isdefined( self ) )
		v_pos = self.origin;
	// The glow ends with the grenade: its host goes now, and the loop with it.
	if ( isdefined( host ) )
		host Delete();
	if ( !isdefined( player ) || !isdefined( v_pos ) )
		return;
	if ( !( player HasPerk( PERK_ELECTRIC_CHERRY ) ) )
		return;   // the perk was lost mid-flight: a plain frag / a plain web
	if ( IS_TRUE( level.tod_dev ) )
		tod_quiet_print( "PHD gen " + n_gen + " burst" + ( ( b_combo ) ? " (combo)" : "" ) );
	// THE FLOP NOVA — the thrown grenade only (v16.70; the define block says
	// why). Purple when it is the combo (v16.78); a child pops purple instead.
	if ( n_gen == 1 )
		player phd_nova( v_pos, TOD_PHD_GRENADE_HEALTH_FRAC, b_combo );
	else if ( b_combo && TOD_PHD_WIDOW_GLOW )
		level thread phd_fx_burst( v_pos, TOD_PHD_FX_POP );
	// THE WIDOW'S SPLIT (v16.57), BOUNDED BY GENERATION (v16.70).
	if ( b_combo && n_gen < TOD_PHD_WIDOW_DEPTH && ( player HasPerk( PERK_WIDOWS_WINE ) ) )
		player phd_widow_split( v_pos, n_gen + 1 );
}

// self = a combo grenade. Spawns the in-flight tell: a tag_origin host riding
// the grenade (LinkTo) with the looping purple trail on it — the same host lane
// as _tod_perk_scatter's derez_burst_run, because a bare PlayFXOnTag on a
// weapon model is exactly what the perk glow found does not draw from the
// server. Returns the host; the tracker deletes it at the burst.
function phd_glow_host()
{
	h = Spawn( "script_model", self.origin );
	if ( !isdefined( h ) )
		return undefined;
	h SetModel( "tag_origin" );
	h LinkTo( self );
	PlayFxOnTag( TOD_PHD_FX_TRAIL, h, "tag_origin" );
	return h;
}

// level thread. A one-shot burst at v_pos on its own short-lived tag_origin
// host (bare server PlayFX one-shots do not draw — the ambient-fx lane rule).
function phd_fx_burst( v_pos, fx )
{
	h = Spawn( "script_model", v_pos );
	if ( !isdefined( h ) )
		return;
	h SetModel( "tag_origin" );
	PlayFxOnTag( fx, h, "tag_origin" );
	wait TOD_PHD_FX_BURST_HOST_SECS;
	if ( isdefined( h ) )
		h Delete();
}

// self = player (the thrower — MagicGrenadeType credits self). v_pos = the
// parent's burst point; n_gen = the generation the CHILDREN are (2 for the
// thrown grenade's ring, 3 for the ring's own children). An even ring at a
// random phase, each child lobbed outward and up so it lands a body-length or
// two away before its own fuse. Every child is STAMPED and tracked HERE, which
// is the only way a child ever splits again — and the only way it is stopped
// from doing so past TOD_PHD_WIDOW_DEPTH.
function phd_widow_split( v_pos, n_gen )
{
	if ( !isdefined( self ) || !isplayer( self ) )
		return;
	if ( !isdefined( n_gen ) )
		n_gen = 2;
	n = ( ( n_gen <= 2 ) ? TOD_PHD_WIDOW_CHILDREN : TOD_PHD_WIDOW_CHILDREN_DEEP );
	if ( n <= 0 )
		return;
	// DECLARE THE CHILDREN before the first launch (phd_child_seen): if the
	// engine raises grenade_fire inside the call, the watcher knows to skip it.
	self.tod_phd_child_pending = n;
	self.tod_phd_child_time = GetTime();
	yaw0 = RandomFloat( 360 );
	for ( i = 0; i < n; i++ )
	{
		fwd = AnglesToForward( ( 0, yaw0 + i * ( 360 / n ), 0 ) );
		vel = fwd * TOD_PHD_WIDOW_SPEED + ( 0, 0, TOD_PHD_WIDOW_LIFT );
		child = self MagicGrenadeType( level.w_widows_wine_grenade, v_pos + ( 0, 0, 24 ), vel, TOD_PHD_WIDOW_FUSE );
		if ( !isdefined( child ) )
			continue;
		// THE STAMP — the entity now says what it is, for any notify that
		// arrives later (the define block has the whole argument).
		child.tod_phd_gen = n_gen;
		child thread phd_grenade_track( self, level.w_widows_wine_grenade, n_gen );
	}
	if ( IS_TRUE( level.tod_dev ) )
		tod_quiet_print( "PHD WIDOW: ring of " + n + " (gen " + n_gen + ")" );
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
	self phd_nova( self.origin, 1.0 );
}

// THE NOVA. self = player (the attacker, for kill credit); v_burst = the centre
// (the player on a down, the impact point for a grenade); n_frac = the fraction
// of the round's zombie health dealt — 1.0 for the down-flop, the v16.48
// grenade uses TOD_PHD_GRENADE_HEALTH_FRAC — floored at TOD_PHD_EXPLODE_DAMAGE.
function phd_nova( v_burst, n_frac, b_purple )
{
	self endon( "disconnect" );

	if ( !isdefined( n_frac ) || n_frac <= 0 )
		n_frac = 1.0;

	// VISUAL: the framework's stock ORANGE explosion. level._effect is populated
	// by the framework so this needs no #precache and no new asset — and it
	// carries its own boom, so it doubles as the sound. Guarded because an
	// unregistered handle would fatal PlayFX.
	// (Map 1 tried an electric-spark FX here first and the user reported it read
	// as sparks rather than an explosion — def_explosion is the right one.)
	// v16.78: the COMBO's nova (a Widow's grenade, both perks held) is the
	// purple RPG blast on a tag_origin host — the combo's tell. Everything else
	// (a frag, the down-flop) keeps the orange.
	if ( IS_TRUE( b_purple ) && TOD_PHD_WIDOW_GLOW )
		level thread phd_fx_burst( v_burst, TOD_PHD_FX_BOOM );
	else if ( isdefined( level._effect ) && isdefined( level._effect[ "def_explosion" ] ) )
		PlayFX( level._effect[ "def_explosion" ], v_burst );
	Earthquake( 0.4, 0.75, v_burst, 400 );

	// Damage trash in radius. Scales with the round so it stays a real clear at
	// depth rather than a firework: the round's own zombie health (x n_frac) is
	// the floor.
	n_damage = TOD_PHD_EXPLODE_DAMAGE;
	if ( isdefined( level.zombie_health ) && ( level.zombie_health * n_frac ) > n_damage )
		n_damage = level.zombie_health * n_frac;

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

// ---------------------------------------------------------------------------
// v17.97 — DEV PRINTS ARE MUTABLE. level.tod_dev_quiet (set beside tod_dev in
// zm_tower_of_doom::tod_resolve_dev_flags) silences every bottom-left IPrintLn
// in this file — screenshot sessions want dev + god with a clean HUD. Each
// print site's own tod_dev gate is unchanged; this is one extra gate under it.
// IPrintLnBold (real game toasts) is not routed here.
function tod_quiet_print( msg )
{
	if ( IS_TRUE( level.tod_dev_quiet ) )
		return;
	IPrintLn( msg );
}

function tod_quiet_print_to( msg )   // self = the player to print to
{
	if ( IS_TRUE( level.tod_dev_quiet ) )
		return;
	self IPrintLn( msg );
}
