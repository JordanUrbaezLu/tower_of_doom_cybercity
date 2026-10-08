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
// v17.38 (user 2026-09-04: "master ammo crates so we dont ever have to touch
// them again"): EVERY crate in the map is on that contract now — the spire's
// arena, shelf and hub crates included. There are no script clips left
// anywhere (crate_clips() is gone), the facing is one convention
// (gen_tower_map.js CRATE_YAW_*: front = yaw + 90), the occupancy box is
// rotated to each crate's real yaw by crateBox(), and the trigger recipe
// below reads its two numbers out of GENERATED _tod_breather_data.gsc.
//
// ASSET (v19.69, user 2026-10-02: "Replace the ammo crates with the new model from
// props (nikolai)"; v19.69b "I think ammo crate was updated to a new clean v6"):
// `tod_ammo_chest` — Nikolai's AMMO BOX V6, a lidless open case: the Meshy shell with
// the bullet / lightning panel and glowing blue strips, and his modelled interior -
// straight compartments, brass rifle and pistol rounds, red shotgun shells, blue
// cells with lit energy bands. Built by tools/fan_props/build_fan_props.py TO THE
// CRATE CONTRACT: front = model +Y (yaw + 90, unchanged), the back edge 37 behind the
// origin, the front 32 ahead, 98 across, 29 tall. It ships at its game size: NO
// SetScale (the West crate needed 2.5x). (v19.69's first chest, his lidded "Cyber
// Ammo Chest", was replaced the same day; he dropped it from the pack.)
// Map-owned GDT: source_data/tod_fan_props.gdt; zone line `xmodel,tod_ammo_chest`.
// Until v19.69 this was the [West] Ammo Crates pack (Westchief596 / ZeRoY's S4
// crate, `west_ammo_crate_model` at SetScale 2.5, a GDT shared with map 1 and
// never edited) — unzoned now, untouched on disk.
//
// COLLISION LIVES IN THE .map, NOT HERE (v10.25, user 2026-08-24: "Also the
// ammo crates dont have clips"). v10.22 spawned this model NOT SOLID on
// purpose and that call is now reversed — you could walk through the crates.
//
// It could not be fixed on this side. The xmodel has NO player collision at all
// (the West crate's GDT: CollisionMap "" and BulletCollisionFile ""; the v19.69
// chest the same — its BulletCollisionLOD "High" stops bullets, not players), so
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
#using scripts\zm\_zm_weapons;
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;   // toast (v19.58: say WHY a refill is refused)    // is_weapon_upgraded (v13.23 two-tier pricing)

#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // crate_org/yaw + breather_zs (GENERATED, v13)
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;   // crown_crate_org/yaw (GENERATED)

#insert scripts\shared\shared.gsh;
#insert scripts\zm\zm_tower_of_doom\_tod_toast.gsh;

// The crate model. Precache AFTER every #using/#insert — the "No generated
// data" compile trap (CLAUDE.md GSC dialect).
#precache( "model", "tod_ammo_chest" );

#define TOD_CRATE_MODEL     "tod_ammo_chest"   // v19.69: Nikolai's chest, built at game size (no SetScale)
#define TOD_CRATE_REVISION  "fan_props_2"      // = art/fan_props/manifest.json "revision"; logged once
#define TOD_CRATE_COST_BASE 2500  // non-PaP'd weapon (user 2026-08-29: "2500 for non pap")
#define TOD_CRATE_COST_PAP  5000  // PaP'd weapon (was the flat price for everything, 2026-08-24 -> 08-29)
#define TOD_CRATE_TOAST_MS 3000   // v19.58: refusal toast throttle (the trigger is a HOLD)
// THE TRIGGER (v17.38, user: "check the trigger on all ammo crates. Some of them
// are off and you cant get ammo unless at a certain angle"). Radius and
// front-offset come from GENERATED _tod_breather_data.gsc (crate_trig_r /
// crate_trig_out) — the same numbers the generator asserts against every other
// vendor trigger. WHY THE OFFSET: the trigger used to sit ON the model origin
// with radius 72, and the crate's own collision holds a player's origin
// >= 38 + ~16 (capsule) = 54u from that origin — an 18u usable band, only on
// the face's centre line. Off-axis by a step, or standing naturally, and there
// was no prompt. The trigger now sits crate_trig_out() (56) IN FRONT of the
// origin, the stations' and PaP machines' own grammar, so the band runs from
// the face to ~128u out and ±72 across it. Height and lift unchanged: the
// cylinder tests the player's bounding box (memory trigger-origin-under-decal)
// and +40 keeps the origin above every 1u floor decal in the map.
// 2026-09-24 — THE LONG SIDES (lead tester: "on the middle to far left side in
// front of the ammo box you cannot get a prompt ... Almost like prompt ends half
// way through"). The trigger is now centred on the clip box's own line
// (crate_trig_lat 13), 6u off its front face (crate_trig_out 44), LIFTED to
// crate_trig_lift 60 so a standing player's sight line to it passes over the 58u
// clip from the long sides (the trigger does a sight trace, and a clip brush
// blocked it), radius crate_trig_r 100. All four numbers are GENERATED and
// proven in gen_tower_map.js (crateTrig's assert block). The lift used to be
// the TOD_CRATE_TRIG_LIFT 40 define here; 60 is stock's own perk-machine
// trigger recipe (_zm_perks.gsc:1513, origin + 60, height 80).
#define TOD_CRATE_TRIG_H    80

#namespace tod_ammo_crate;

// PLACEMENT — one per breather lounge, EAST wall, facing west into the room
// (unchanged by v13: the crate was fine where it was — it was the PaP that
// crowded it, and the PaP moved to the W wall). The origin comes from
// GENERATED _tod_breather_data.gsc, cut from the generator's BR_FURN table,
// which also cuts the collision clip and asserts this trigger clears every
// other lounge trigger by both radii + 64. CRATE FACING (v17.37): front =
// yaw + 90 — 90 faces WEST (-x), 270 EAST, 0 NORTH, 180 SOUTH. The old note
// here ("0 = front toward -y, 90 = +x, 270 = -x") was the belief every tower
// crate was placed under, and it was backwards; gen_tower_map.js CRATE_YAW_*
// carries the record.

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

// =============================================================================
// ONE CRATE, ONE RECIPE (v14.58, user 2026-08-31: "All ammo crates should work
// the same"). The three functions below are the WHOLE definition of an ammo
// crate — model, trigger and hint — and BOTH spawners call them: place() here
// for the six static crates, and _tod_spire::spawn_crate for the spire's
// dynamic arena/hub/shelf ones. The spire already shared use_loop() (so the
// pricing and every refusal branch were one implementation), but it hand-rolled
// its own model, its own trigger dims and — the one that mattered — its own
// COPY of the hint literal, kept in step only by a "keep in LOCKSTEP" comment.
// Two copies of a string that names two prices is exactly the drift trap this
// repo keeps paying for, and it also spent TWO permanent triggerstring slots
// for one prompt. Now there is one literal and one slot for every crate in the
// map, at either end of the game.
// =============================================================================

// THE HINT. Read the triggerstring budget note before touching this: a DISTINCT
// string is a PERMANENT engine slot, cap 250 a match, never freed (CLAUDE.md
// "TRIGGERSTRING BUDGET"). This function existing is what keeps every crate on
// ONE slot — call it, never re-type the literal.
//
// COPY (user 2026-08-31: "We shoudl say Regulat $2500 and Pack a Punch $5000").
//
// GRAMMAR — PromptDefault.lua parses this into a structured card:
//     Hold [btn] <TITLE> - <detail 1> / <detail 2> [Cost: N]
// so this renders as the title "AMMO CRATE" over two detail lines,
// "Regular $2500" and "Pack a Punch $5000". Leading with the NOUN is required:
// the card drops "Hold [btn]" and draws its own key glyph, so a line that began
// with "for"/"to" would reach the screen as a dangling fragment.
//
// "PACK A PUNCH" IS ONLY SAFE HERE BECAUSE THE ROUTER CLAIMS THE NOUN FIRST.
// ZMCursorHintNew.lua's isPAPHint() sends anything containing both "pack" and
// "punch" to the Pack-a-Punch card; classifyHint() tests the TOD_NOUNS list
// (which holds "ammo crate") BEFORE it, so this line lands on the default card.
// If you rename this prompt, rename it in TOD_NOUNS in the same commit.
//
// NO "[Cost: N]" BRACKET, deliberately: there are two prices and the card has
// one price row. The card reads the "$" and still says "To Buy" in its footer.
//
// THIS STRING MUST STAY CONSTANT, and the spire is why. Its shelf crates
// re-enter the ±3-floor window over and over (_tod_spire::crate_window runs
// every 2s for a 100-floor climb), so spawn_trigger — and therefore
// SetHintString — is called an UNBOUNDED number of times. That costs zero
// extra slots today only because this returns the same characters every time.
// Interpolate any runtime value here (a floor number, a player's price) and
// the unbounded call count becomes an unbounded SLOT count, straight into the
// 250 cap. tools/lint_tod_hints.js fails the build on a variable hint that has
// not declared its bound, which is the guard for exactly this.
// (The old wording also relied on "[cost:" being harmless on a HINT_NOICON
// trigger because the wallbuy router "needs [cost:] AND an icon". That premise
// was FALSE — the icon guard never fired, and this crate drew the "Wall Weapon"
// card in game for months. Fixed in the router; not relied on here either way.)
function crate_hint()
{
	return ( "Hold ^3[{+activate}]^7 ^5AMMO CRATE^7 - Regular ^2$" + TOD_CRATE_COST_BASE
	         + "^7 / Pack a Punch ^2$" + TOD_CRATE_COST_PAP );
}

// The crate MODEL. Returns undefined if the entity pool is full — every caller
// must cope (a missing crate is buyable elsewhere), which is why the spire's
// window manager checks. Not solid: the collision is a generator-cut clip
// brush inside the mesh, for EVERY crate (v17.38) — see the header.
function spawn_model( org, yaw )
{
	m = Spawn( "script_model", org );
	if ( !isdefined( m ) )
		return undefined;
	m.angles = ( 0, yaw, 0 );
	m SetModel( TOD_CRATE_MODEL );
	if ( !IS_TRUE( level.tod_crate_model_logged ) )
	{
		level.tod_crate_model_logged = true;   // once: the spire's window re-spawns shelf crates all climb
		dev_log( "MODEL rev=" + TOD_CRATE_REVISION + " model=" + TOD_CRATE_MODEL + " first_org=" + org + " yaw=" + yaw
			+ " trig_out=" + tod_breather_data::crate_trig_out() + " trig_lat=" + tod_breather_data::crate_trig_lat() );
	}
	return m;
}

function dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_CRATE] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

// -> the crate's FRONT as a unit vector (front = yaw + 90; see the placement
// note above). Yaw only — a crate never pitches.
function crate_front( yaw )
{
	return AnglesToForward( ( 0, yaw + 90, 0 ) );
}

// -> the crate's LATERAL axis: the front turned +90 (yaw + 180), the direction
// the clip box sits 13u off the origin (gen_tower_map.js crateLat: [-f.y, f.x]).
function crate_lat( yaw )
{
	return AnglesToForward( ( 0, yaw + 180, 0 ) );
}

// -> where this crate's trigger goes: crate_trig_out() in front of the origin,
// crate_trig_lat() across onto the box's own centre line, crate_trig_lift() up.
// One function so the six static crates and the spire's dynamic ones can never
// place it two ways — and it is the generator's crateTrig, number for number.
function trig_org_for( org, yaw )
{
	return org + VectorScale( crate_front( yaw ), tod_breather_data::crate_trig_out() )
		+ VectorScale( crate_lat( yaw ), tod_breather_data::crate_trig_lat() )
		+ ( 0, 0, tod_breather_data::crate_trig_lift() );
}

// The crate USE TRIGGER, already threaded on the shared use_loop. Takes the yaw
// because the trigger stands IN FRONT of the crate (see the define block).
function spawn_trigger( org, yaw )
{
	t = Spawn( "trigger_radius_use", trig_org_for( org, yaw ), 0, tod_breather_data::crate_trig_r(), TOD_CRATE_TRIG_H );
	if ( !isdefined( t ) )
		return undefined;
	t TriggerIgnoreTeam();      // REQUIRED for a script-spawned use-trigger
	t SetCursorHint( "HINT_NOICON" );
	t SetHintString( crate_hint() );
	t thread use_loop();
	return t;
}

function place( org, yaw )
{
	m = spawn_model( org, yaw );
	spawn_trigger( org, yaw );
	return m;
}

// (crate_clips() lived here from v13.9 to v17.38 — three zm_collision_perks1
// colliders spread along AnglesToRight, which at a crate's yaw is its FRONT
// axis, so the row ran front-to-back and planted an invisible lip beyond the
// face. Every crate now has a generator-cut box rotated to its own yaw; the
// spire's shelf boxes are resident, which is safe because a player on a shelf
// is inside the ±3-floor crate window by definition.)

// self = the trigger
function use_loop()
{
	// self endon( "death" ) — MAP 1 HAS IT AND WE DID NOT (v14.58, found by the
	// map-wide prompt audit). It is invisible for the six static crates, whose
	// triggers are never deleted, and it matters for the SPIRE: crate_window()
	// re-runs every 2s and _tod_spire::delete_crate Deletes the trigger this
	// thread is blocked on, over a 100-floor climb with players moving up and
	// down. Cheap insurance on the map's binding constraint (the ~1024-gentity
	// budget) and it costs the static crates nothing.
	self endon( "death" );
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
			player crate_refusal_toast( TOD_TOAST_CRATE_NOTHING );   // v19.58
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
			player crate_refusal_toast( TOD_TOAST_CRATE_FULL );   // v19.58
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
		// v17.70: a crate with its own flat price (the summit's 1000 — the
		// trigger carries it, and its own constant hint; _tod_spire sets both)
		if ( isdefined( self.tod_crate_cost ) )
			cost = self.tod_crate_cost;

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

// v19.58 (display-vs-reality audit): the crate's prompt shows a price to
// EVERY player - it is one shared hint - so a Mage (staffs) or a blade holder
// saw "$2500" and got only a deny sound. The refusal now says why, in the
// map's typeface. Throttled: the trigger is a HOLD and re-fires while held.
function crate_refusal_toast( id )   // self = player
{
	if ( isdefined( self.tod_crate_toast_ms ) && ( GetTime() - self.tod_crate_toast_ms ) < TOD_CRATE_TOAST_MS )
		return;
	self.tod_crate_toast_ms = GetTime();
	self tod_upgrade_ui::toast( id );
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
	if ( IsSubStr( weapon.name, "me_baseballbat" ) )
		return false;
	if ( IsSubStr( weapon.name, "me_wakizashi" ) )
		return false;
	if ( IsSubStr( weapon.name, "leviathan" ) )
		return false;
	if ( IsSubStr( weapon.name, "bowie" ) )
		return false;

	// THE MAGE'S STAFFS (v19.38). They never run dry — staff_ammo_watch in
	// _tod_mage_elements keeps the clip and reserve topped up — but their
	// reserve can never reach maxAmmo either (the watcher tops it to clipSize
	// 1000 against a maxAmmo of 1001), so the ALREADY FULL check above never
	// fired and the crate charged a Mage 2,500 points for a no-op. Every
	// staff form (base, _q0/_q1, the ice _d twins) carries this prefix; it is
	// the same test _tod_mage_elements::staff_element uses.
	if ( IsSubStr( weapon.name, "tod_staff_" ) )
		return false;

	return true;
}
