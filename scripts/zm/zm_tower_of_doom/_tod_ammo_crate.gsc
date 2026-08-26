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
// PORTED from map 1's _acc_ammo_crate.gsc, SIMPLIFIED per the user's spec:
// map 1 priced by PaP state (base / PaP'd / wonder tiers); this is a FLAT 5000
// for any weapon that has ammo. Same asset, same script-spawn recipe.
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
// So tools/gen_tower_map.js emits a SOLID brush tucked inside the crate mesh
// (search "ammo crate body"), inset 4 units on every face so the model hides
// it. Bounds there are measured off the decompressed xmodel and depend on
// TOD_CRATE_X / TOD_CRATE_Y / TOD_CRATE_SCALE / TOD_CRATE_YAW below —
// **MOVE THE CRATE HERE AND YOU MUST MOVE THE BRUSH THERE**, or the collision
// stays behind and the lint will not catch it (a solid brush on a floor is a
// legal thing to build; it only knows invisible ones are wrong).
//
// NO LONGER GSC-ONLY: changing crate placement is now a full build + LED bake.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;      // can_player_purchase / minus_to_player_score
#using scripts\zm\_zm_utility;    // is_player_valid

#using scripts\zm\zm_tower_of_doom\_tod_crown_data;   // crown_crate_org/yaw (GENERATED)

#insert scripts\shared\shared.gsh;

// The crate model. Precache AFTER every #using/#insert — the "No generated
// data" compile trap (CLAUDE.md GSC dialect).
#precache( "model", "west_ammo_crate_model" );

#define TOD_CRATE_COST     5000   // flat, any weapon that has ammo (user 2026-08-24)
#define TOD_CRATE_SCALE    2.5    // map 1's tuned visual scale for this model
#define TOD_CRATE_TRIG_R   72     // grown with the model (64 is flush at 1x)
#define TOD_CRATE_TRIG_H   80

#namespace tod_ammo_crate;

// PLACEMENT — one per breather balcony, EAST edge, backed against the east
// parapet and facing west into the balcony.
//
// The four breather laps (10/20/30/40) are all EVEN, so every balcony sits in
// the MIRRORED frame: floor x[-800,-256] y[-992,-416]. This spot was chosen by
// measuring against everything already on that balcony — it is 230u from the
// nearest neighbour and 54u off the east parapet (the crate's half-extent is
// ~36u, so it clears):
//   perk pads (S rail)      x -360 / -536, y -959   (_tod_perk_scatter)
//   upgrade station (W)     x -760,        y -600   (_tod_upgrades)
//   teleport pad            x -640,        y -800   (_tod_teleport)
//   breather PaP (N edge)   x -320,        y -470   (_tod_powerups)
//   >> AMMO CRATE (E edge)  x -310,        y -700   <<
// KEEP THAT LIST IN LOCKSTEP: the generator's BR_DEPTH/BR_EAST comment names
// the scripted furniture that does NOT follow a balcony resize automatically.
// If the balcony is ever resized again, this crate is a fifth item to re-place.
#define TOD_CRATE_X      -310
#define TOD_CRATE_Y      -700
#define TOD_CRATE_YAW     270    // facing WEST (-x), into the balcony. This map's
                                 // vending convention is yaw 0 = facing -y, so
                                 // 90 = +x (the W-wall station), 270 = -x.

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

	// Breather mid-slab heights — the SAME four z values used by the perk
	// scatter pads, the teleporter source pads and the upgrade stations.
	// (lap-1)*LAP_RISE + 192, laps 10/20/30/40 at LAP_RISE 384.
	zs = array( 3648, 7488, 11328, 15168 );

	for ( i = 0; i < zs.size; i++ )
		place( ( TOD_CRATE_X, TOD_CRATE_Y, zs[ i ] ), TOD_CRATE_YAW );

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
	t SetHintString( "Hold ^3[{+activate}]^7 ^5AMMO CRATE ^2[Cost: " + TOD_CRATE_COST + "]" );
	t thread use_loop();
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

		if ( !( player zm_score::can_player_purchase( TOD_CRATE_COST ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		player zm_score::minus_to_player_score( TOD_CRATE_COST );
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
