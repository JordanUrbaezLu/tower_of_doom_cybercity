// =============================================================================
// _tod_ammo_crate.gsc — a buyable AMMO CRATE on every breather balcony, plus
// one in the CROWN HALL (v12)
// (user 2026-08-24: "adding an ammo box at every breather area? Will cost 5k
// for ammo. We have these ammo crates from the other map we can just reuse";
// user 2026-08-26: "we need an ammo crate in that room").
//
// WHY IT BELONGS HERE: the breathers are the map's only rest stops, and this
// map has NO mystery box and NO wallbuys — every round of ammo comes from the
// class gun's reserve, SCAVENGER, BULLET FEED or a Max Ammo drop. Past ~round
// 25 the reserve curve goes negative and there is nothing to spend points on
// mid-climb. A flat 5k refill at the four rest stops is the sink.
//
// PORTED from map 1's _acc_ammo_crate.gsc. v13.23 (user 2026-08-29): pricing
// is BY PAP STATE again — 2500 for a base gun, 5000 for a PaP'd one (map 1's
// own scheme, minus the wonder tier), applying to EVERY crate. The original
// tower spec was a flat 5000; that lasted 2026-08-24 -> 08-29. Same asset,
// same script-spawn recipe. A SIXTH crate sits at the BASE (core WEST face
// since v14.2 — the v13.23 east-face spot sat under lap 1's east flight and
// its script-clip carves severed the stair navmesh; see the long note in
// spawn_all). Since v14.3 ALL SIX static crates share one contract: origin
// from generated data, collision a generator-cut clip brush in the .map.
// crate_clips() below survives ONLY for the spire's dynamic crates.
//
// ASSET: the [West] Ammo Crates pack (Westchief596; ZeRoY's S4 ammo-crate model
// + textures). The GDT lives INSTALL-SIDE at
// <modtools>\source_data\acc_west_ammo_crate.gdt and is SHARED WITH MAP 1 —
// referenced only, never edited (the shared-GDT rule: editing it would retune
// map 1). Our side is one `xmodel,west_ammo_crate_model` zone line.
//
// SCALE 2.5x, inherited from map 1's live tuning (user there 2026-07-12: "these
// tiny boxes you have to look down to even see"). The raw model is ~29x33x25
// units — knee-high — so at 2.5x it reads as a real crate at ~72x83x63.
//
// COLLISION LIVES IN THE .map, NOT HERE (v10.25, user 2026-08-24: "Also the
// ammo crates dont have clips"). v10.22 spawned this model NOT SOLID on
// purpose and that call is now reversed — you could walk through the crates.
//
// It could not be fixed on this side. The xmodel has NO collision data at all
// (acc_west_ammo_crate.gdt: CollisionMap "" and BulletCollisionFile ""), so
// Solid() on the script_model has nothing to switch on; and a script-spawned
// clip entity would need DisconnectPaths and would still be invisible geometry
// standing on a walkable balcony, which is precisely what
// lint_tod_geometry CHECK 1 exists to catch.
//
// So tools/gen_tower_map.js emits a clip brush tucked inside the crate mesh
// (search "ammo crate body"). v13 closed the old drift trap: the breather
// crate origin now lives ONCE, in the generator's BR_FURN table, which cuts
// that clip AND emits _tod_breather_data.gsc::crate_org() — this file reads
// the same value the brush was cut from, so clip and model cannot separate.
//
// STILL NOT GSC-ONLY: moving the crate means editing BR_FURN in the
// generator, and that is a regen + full build + LED bake.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;      // can_player_purchase / minus_to_player_score
#using scripts\zm\_zm_utility;    // is_player_valid
#using scripts\zm\_zm_weapons;    // is_weapon_upgraded (v13.23 two-tier pricing)

#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // crate_org/yaw + breather_zs (GENERATED, v13)
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;   // crown_crate_org/yaw (GENERATED)

#insert scripts\shared\shared.gsh;

// The crate model. Precache AFTER every #using/#insert — the "No generated
// data" compile trap (CLAUDE.md GSC dialect).
#precache( "model", "west_ammo_crate_model" );

#define TOD_CRATE_COST_BASE 2500  // non-PaP'd weapon (user 2026-08-29: "2500 for non pap")
#define TOD_CRATE_COST_PAP  5000  // PaP'd weapon (was the flat price for everything, 2026-08-24 -> 08-29)
#define TOD_CRATE_SCALE    2.5    // map 1's tuned visual scale for this model
#define TOD_CRATE_TRIG_R   72     // grown with the model (64 is flush at 1x)
#define TOD_CRATE_TRIG_H   80

#namespace tod_ammo_crate;

// PLACEMENT — one per breather lounge, EAST wall, facing west into the room
// (unchanged by v13: the crate was fine where it was — it was the PaP that
// crowded it, and the PaP moved to the W wall). The origin comes from
// GENERATED _tod_breather_data.gsc, cut from the generator's BR_FURN table,
// which also cuts the collision clip and asserts this trigger clears every
// other lounge trigger by both radii + 64. Vending yaw convention: 0 = front
// toward -y, 90 = +x, 270 = -x.

function init()
{
	level thread spawn_all();
}

function spawn_all()
{
	level endon( "end_game" );

	// Wait for the blackscreen like every other scripted fixture — the
	// balconies are .map geometry present from frame one, but spawning props
	// pre-blackscreen races the stock world init.
	level flag::wait_till( "initial_blackscreen_passed" );

	// THE BASE CRATE (v13.23, user 2026-08-29: "add an ammo crate at spawn").
	//
	// v14.3 — PERFECTED: origin/yaw now ride GENERATED _tod_breather_data.gsc
	// (base_crate_org/base_crate_yaw) and the collision is a generator-cut
	// "base ammo crate body" clip brush in the .map, exactly like the other
	// five crates — NO script clips, NO DisconnectPaths, nothing here the
	// geometry lint can't see. The generator (gen_tower_map.js BASE_CRATE)
	// also ASSERTS the box clear of the lap-1 E flight and the west walkway
	// >= 128u, so the v13.23 mistake is now mechanically impossible.
	//
	// THE HISTORY THAT FORCED THIS (keep it — it is the whole design): v13.23
	// hand-placed the crate at (320,0,0), "the emptiest documented base wall"
	// — empty because LAP 1'S EAST FLIGHT RUNS OVER IT (x[256,416]; the same
	// strip the teleport bay was moved out of in v10.25). Its three
	// script-clip DisconnectPaths carves severed the stair navmesh BOTH ways
	// (Workshop report Pinkbrotha4310 2026-08-30: zombies below wouldn't
	// climb, zombies above wouldn't come down). v14.2 moved it to the core
	// WEST face (-320,0,0), yaw 270, still with script clips; v14.3 moved the
	// truth into the generator. The west face is clear by construction: W
	// flights belong to EVEN laps, so the first stair over this strip is lap
	// 2's at z=384.
	place( tod_breather_data::base_crate_org(), tod_breather_data::base_crate_yaw() );

	// Lounge mid-slab heights — the same generated list every other piece of
	// breather furniture reads ((lap-1)*LAP_RISE + 192, laps 10/20/30/40).
	zs = tod_breather_data::breather_zs();

	for ( i = 0; i < zs.size; i++ )
		place( tod_breather_data::crate_org( zs[ i ] ), tod_breather_data::crate_yaw() );

	// THE CROWN HALL CRATE (v12, user 2026-08-26: "we need an ammo crate in
	// that room"). The hold-out room's own restock — a fifth crate on the
	// east wall, mirroring the upgrade station on the west. Coordinates come
	// from GENERATED _tod_crown_data.gsc (the door-data no-drift contract):
	// the generator emits the matching collision clip ("crown hall ammo crate
	// body") from the same table, already parity-mirrored, so this call is
	// correct at either crown parity without knowing which one shipped.
	place( tod_crown_data::crown_crate_org(), tod_crown_data::crown_crate_yaw() );
}

function place( org, yaw )
{
	m = Spawn( "script_model", org );
	m.angles = ( 0, yaw, 0 );
	m SetModel( "west_ammo_crate_model" );
	m SetScale( TOD_CRATE_SCALE );
	// (not solid — see the header)

	t = Spawn( "trigger_radius_use", org + ( 0, 0, 40 ), 0, TOD_CRATE_TRIG_R, TOD_CRATE_TRIG_H );
	t TriggerIgnoreTeam();      // REQUIRED for a script-spawned use-trigger
	t SetCursorHint( "HINT_NOICON" );
	// HINT ROUTING (the Aetherium buyable-UI rules, memory
	// aetherium-and-upgrade-input): PromptDefault strips "Hold " and the
	// [{+activate}] token, so the line must READ CORRECTLY starting at the
	// NOUN — here "AMMO CRATE - ...". A price bracket is safe on a
	// HINT_NOICON trigger (the wallbuy router needs [cost:] AND an icon), and
	// there is no "for" + perk-name, so the perk-card router cannot claim it.
	// v13.23: two-tier price — the hint is static per trigger, so it names
	// BOTH prices; the charge reads the held weapon's PaP state at use time.
	t SetHintString( "Hold ^3[{+activate}]^7 ^5AMMO CRATE ^2[Cost: " + TOD_CRATE_COST_BASE + " / PaP'd " + TOD_CRATE_COST_PAP + "]" );
	t thread use_loop();
	return m;
}

// Script collision for DYNAMICALLY-PLACED crates — since v14.3 that means
// ONLY the spire's arena/shelf crates (_tod_spire::spawn_crate; they
// materialize and de-rez at runtime, so a baked clip brush cannot serve
// them). Every STATIC crate — the four breathers, the crown hall AND the
// base crate — gets a generator-cut "ammo crate body" clip brush instead.
// Recipe: the v13.9 PaP machine pattern, three zm_collision_perks1 spread
// ±48 along AnglesToRight, each DisconnectPaths'd per the navmesh rule.
// KNOWN SLOP, accepted for the spire only ("robust rather than exact", the
// upgrade-station doctrine): at vending yaws AnglesToRight points out the
// FRONT, so the row runs front-to-back — a ~25u invisible lip beyond the
// mesh face and a thin uncovered sliver on the +y flank (the mesh sits
// offset +13y from its origin, measured in the generator's crate box).
// NEVER call this for a crate that stands anywhere near a stair flight —
// these carves are invisible to the geometry lint, which is exactly how the
// v13.23 base crate severed the lap-1 stair (see spawn_all's history note).
function crate_clips( m )
{
	right = AnglesToRight( m.angles );
	offs = array( -48, 0, 48 );
	clips = [];
	for ( ci = 0; ci < offs.size; ci++ )
	{
		c = Spawn( "script_model", m.origin + VectorScale( right, offs[ ci ] ), 1 );
		c.angles = m.angles;
		c SetModel( "zm_collision_perks1" );
		c.script_noteworthy = "clip";
		c DisconnectPaths();
		clips[ clips.size ] = c;
	}
	m.tod_clips = clips;
}

// self = the trigger
function use_loop()
{
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( "trigger", player );

		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( !zm_utility::is_player_valid( player ) )
			continue;                       // downed / spectating
		if ( player laststand::player_is_in_laststand() )
			continue;
		// A revive press is not a purchase (_zm_blockers.gsc:307). Reviving polls
		// the raw USE button (_zm_laststand.gsc:1129), so without this the press
		// that revives a teammate also charges for a refill. Silent, like the
		// branch above: the player is holding use.
		if ( player zm_utility::in_revive_trigger() )
			continue;
		// World frozen for an upgrade pick — refuse, but SAY SO. A mute refusal
		// is indistinguishable from a dead trigger (the same silence made a
		// teleporter read as broken on 2026-08-26; see the long note at
		// _tod_teleport.gsc's copy of this branch). The window is up to ~20s
		// every fourth round, and a player who already locked their card — or
		// who was down/dead and sat the event out — is unfrozen and walking
		// around inside it. Every other refusal in this loop already sounds.
		if ( IS_TRUE( level.tod_upgrade_pause ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		weapon = player GetCurrentWeapon();

		// NOTHING TO REFILL -> refuse and charge NOTHING. Taking 5000 points
		// for a no-op is the worst thing this trigger could do, so the melee
		// gate comes before the wallet check. The blades are the slasher's
		// whole ladder plus the bowie alt (see _tod_classes::register_melee_dmg
		// — keep the stems in step with that list).
		if ( !has_ammo( weapon ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		// ALREADY FULL -> REFUSE, AND CHARGE NOTHING (audit 2026-08-25).
		// GiveMaxAmmo on a full reserve is a no-op, so the crate happily took
		// 5,000 points and did nothing. Easiest to hit right after a Max Ammo
		// drop — which is exactly when a player is most likely to walk past it.
		// Ordered BEFORE the wallet check for the same reason the melee gate is:
		// taking points for nothing is the worst thing this trigger can do.
		if ( player GetWeaponAmmoStock( weapon ) >= weapon.maxAmmo )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		// v13.23 two-tier: the held weapon's PaP state picks the price.
		//
		// TWO CHECKS, NOT ONE (2026-08-30, live report: a PaP'd gun bought
		// crown-crate ammo at the 2500 base price). The old comment claimed
		// "the class-gun _up twins ARE upgraded forms, so is_weapon_upgraded
		// covers them natively" — WRONG for part of the roster.
		// is_weapon_upgraded answers from level.zombie_weapons_upgraded, which
		// is loaded from zm_levelcommon_weapons.csv — and that CSV's rows for
		// the _zm-SUFFIXED twin families (the Enfield ladder, the knives,
		// leviathan) name the forms WITHOUT the _zm suffix the shipped assets
		// carry, so the table rows point at weapons that don't exist and a
		// held t5_enfield_up_*_zm reads as not-upgraded. The name check covers
		// every generated PaP form ("_up" / "_up_*"), the stock "_upgraded"
		// forms (MR6), and can't drift when the generator grows a new family;
		// the stock check stays for anything named differently. (The ~1s
		// pre-reconcile window after a tier card remains the one edge, and it
		// under-charges rather than over-charges.)
		cost = TOD_CRATE_COST_BASE;
		if ( zm_weapons::is_weapon_upgraded( weapon ) || IsSubStr( weapon.name, "_up" ) )
			cost = TOD_CRATE_COST_PAP;

		if ( !( player zm_score::can_player_purchase( cost ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		player zm_score::minus_to_player_score( cost );
		player PlaySound( "zmb_cha_ching" );
		// Fills the shared RESERVE; the magazine tops off on the next reload,
		// exactly like the stock Max Ammo powerup.
		player GiveMaxAmmo( weapon );
		wait 0.75;                          // debounce a held [activate]
	}
}

// -> true if `weapon` is something GiveMaxAmmo can meaningfully fill.
// The map's melee weapons carry no reserve, so a refill would be a silent
// no-op the player paid 5000 for.
function has_ammo( weapon )
{
	if ( !isdefined( weapon ) || weapon == level.weaponNone )
		return false;
	if ( !isdefined( weapon.name ) )
		return false;

	// The slasher ladder + the bowie alt. Substring match covers every
	// generated variant form (_k0.._k4, _up, the trailing _zm).
	if ( IsSubStr( weapon.name, "me_knife_american" ) )
		return false;
	if ( IsSubStr( weapon.name, "me_wakizashi" ) )
		return false;
	if ( IsSubStr( weapon.name, "leviathan" ) )
		return false;
	if ( IsSubStr( weapon.name, "bowie" ) )
		return false;

	return true;
}
