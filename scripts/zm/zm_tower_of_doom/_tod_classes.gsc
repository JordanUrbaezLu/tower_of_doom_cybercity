// =============================================================================
// _tod_classes.gsc — the class system: 4 classes x 3 TIERS of guns.
//
// CLASS TIERS (docs/25, user 2026-08-22): a class is an identity (move speed,
// the draft, the domain pool gate); what the player HOLDS is the gun of their
// current TIER (player.tod_tier, 1..3). A TIER card (dealt by _tod_upgrades
// once the class gun is PaP'd) promotes the tier: a new gun, GUN-scoped
// upgrades reset, CLASS-scoped ones (DMG REDUCTION, LUCK) kept.
//
// Every module resolves "the class gun" PER PLAYER through gun( player ) —
// never through a class-level primary (that coupling is what tiers broke).
//
// LADDERS (user 2026-08-22):
//   SKIRMISHER  MAC-10        -> MP5        -> MP7
//   ASSAULT     Enfield       -> Krig 6     -> AK-47
//   HEAVY       Stoner 63     -> HK21       -> Death Machine
//   SLASHER     Combat Knife  -> Katana     -> STORMBREAKER (the Leviathan port)
// PHASE 1 (this file) ships the NULL LADDER — every tier is today's T1 gun —
// which proves the card / reset / swap / latch flow with ZERO new assets.
// Phase 2 swaps the stems in ONE GUN PER BUILD (docs/25 §7, §11).
//
// SCALABILITY DOCTRINE (the "no twin matrix" answer, see _tod_upgrades.gsc):
// a gun costs its generated variant forms only (base tune x ladder x base/_up);
// every upgrade the tower grants is SCRIPT-side state. Map 1 measured the
// engine's registration ceiling (~230 safe, silent 0xC0000005 boot AV past
// it, docs/21 §A) — tools/gen_tod_twins.js prints the ledger and throws > 200.
//
// Adding a gun (docs/25 §7, condensed): screen the GDT for a live altWeapon
// (boot trap), add it to gen_tod_twins.js (variants + zone + CSV rows) and
// gen_tod_sounds.js, then ONE register_gun line here. Boot-test after EVERY
// gun added — never batch (map 1's hard rule).
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\zm\_zm_utility;    // include_weapon (PaP table repair)
#using scripts\zm\_zm_weapons;    // add_zombie_weapon (PaP table repair)
#using scripts\shared\util_shared;
#using scripts\zm\_zm_utility;

#insert scripts\shared\shared.gsh;

#define TOD_TIER_MAX        3

// PER-CLASS SECONDARIES (user 2026-08-23: "we need to look into secondarys now
// ... I think we give the knife an automatic pistol CW APM63. The current
// pistol will go to the LMG class. The CW MAGNUM will go to the Assault class.
// For SMG we can give it weakend version of the Ghosts Bulldog").
// Was ONE global TOD_CLASS_SECONDARY "pistol_standard" for every class.
//
// EXPLICITLY NO TWINS (user: "They will all have PaP versions but thats about
// it") — each is base + its PaP form and nothing else, so none of these go
// through gen_tod_twins.js and none carry a variant ladder. 6 registrations,
// taking the ledger 159 -> 165 against the 200 guard.
//
// TWO NAME CORRECTIONS, both verified against the installed GDTs:
//   * the CW machine pistol is the AMP63, not "APM63"  -> t9_amp63
//   * the only Bulldog installed is the ADVANCED WARFARE port (s1_bulldog),
//     not the Ghosts one. Both are shotguns, so the intent carries.
// The AMP63's PaP asset breaks the port convention — it is
// t9_amp63_rdw_up_zm, NOT t9_amp63_up. That is harmless because the weapons
// CSV carries an explicit `upgrade_name` column (field 2), so PaP resolves by
// table lookup rather than by suffix. Do NOT "fix" it by assuming _up.
// AW Bulldog — the skirmisher's emergency shotgun. Now the GENERATED variant
// (v10.8, user 2026-08-23: "clip size can double for base and pap bulldog"):
// s1_bulldog_b carries clip 12 / dmg 120 and s1_bulldog_up_b clip 18 / dmg 240,
// emitted by tools/gen_tod_twins.js from skye_s1_bulldog.gdt exactly like every
// other twin. The stock s1_bulldog asset cannot be edited in place, so the buff
// only reaches the player through THIS name — pointing back at the bare stem
// silently reverts the whole change. The old ×0.5/×0.75 script nerf is gone too
// (damage_mult_for now returns 1.0 for it).
// ---- THE SECONDARY TABLE — 12 SIDEARMS, ONE PER (CLASS, TIER) --------------
// (user 2026-08-24: "every tier for every class needs its own secondary ...
// each teir of secondsries will get better just like the primaries do".)
// Was FOUR names, one per class, tier-blind.
//
// GIVE NAME (what GetWeapon is handed) and MATCH STEM (the substring shared by
// that sidearm's base and PaP asset names) are SEPARATE for every row, and they
// have to be. See the v10.8/v10.23 trap that motivated the original four:
//     pistol_standard -> pistol_standard_upgraded    stem contains base
//     t9_amp63        -> t9_amp63_rdw_up             stem contains base
//     s1_bulldog_b    -> s1_bulldog_up_b             stem does NOT
// The generated twins put their variant suffix at the END, so matching on the
// full give name silently stops seeing PACK-A-PUNCHED sidearms — and because
// this map deliberately runs with the stock too-many-weapons monitor OFF
// (v9.18: it confiscated class guns), the consequence is walking around holding
// two sidearms in primary slots, not a tidy auto-reap.
//
// EVERY TIER-2 AND TIER-3 NAME IS A GENERATED TWIN (tools/gen_tod_twins.js) and
// carries the "_b" suffix. Pointing any of these at the bare stock stem hands
// out the UN-NORMALIZED port — the Klauser ships at damage 20 and the RPG at
// 5250, so that mistake is silent in one direction and catastrophic in the
// other. If a name here and the generator's emitted name ever disagree, the
// class draft hands out a weapon that does not exist.
//
// KEEP THE TWO SWITCHES BELOW IN LOCKSTEP: secondary_name() and
// secondary_stem() are indexed by the same (class, tier) pair and a row added
// to one but not the other fails open (falls through to the heavy T1 pistol).
#define TOD_SEC_SKIRMISHER_1 "s1_bulldog_b"        // AW Bulldog      (shotgun)
#define TOD_SEC_SKIRMISHER_2 "t8_sg12_b"           // BO4 SG12        (shotgun)
#define TOD_SEC_SKIRMISHER_3 "t6_spas12_b"         // BO2 SPAS-12     (shotgun)
#define TOD_SEC_ASSAULT_1    "t9_magnum_b"         // CW Magnum       (revolver)
#define TOD_SEC_ASSAULT_2    "t8_mog12_b"          // BO4 Mog 12      (shotgun)
#define TOD_SEC_ASSAULT_3    "t6_executioner_b"    // BO2 Executioner (revolver shotgun)
#define TOD_SEC_HEAVY_1      "pistol_standard"     // the starter MR6 (keeps its script x7.2)
#define TOD_SEC_HEAVY_2      "t6_rpg_b"            // BO2 RPG         (launcher)
#define TOD_SEC_HEAVY_3      "t9_nail_gun_b"       // CW Nail Gun     (projectile, no splash)
#define TOD_SEC_SLASHER_1    "t9_amp63"            // CW AMP63        (machine pistol)
#define TOD_SEC_SLASHER_2    "iw7_udm_b"           // IW UDM 45       (machine pistol)
#define TOD_SEC_SLASHER_3    "t8_rk7_b"            // BO4 RK7 Garrison(auto pistol)

// MATCH STEMS, in lockstep with the twelve names above.
// t6_executioner is the one stem that must catch THREE assets, not two: its PaP
// form is dual wield, so t6_executioner_rdw_up_b (the half the player fires) and
// the stock t6_executioner_ldw_up_zm both have to be reaped on a class switch.
// The bare stem covers all three, which is exactly why this is a stem and not a
// name.
#define TOD_SECSTEM_SKIRMISHER_1 "s1_bulldog"
#define TOD_SECSTEM_SKIRMISHER_2 "t8_sg12"
#define TOD_SECSTEM_SKIRMISHER_3 "t6_spas12"
#define TOD_SECSTEM_ASSAULT_1    "t9_magnum"
#define TOD_SECSTEM_ASSAULT_2    "t8_mog12"
#define TOD_SECSTEM_ASSAULT_3    "t6_executioner"
#define TOD_SECSTEM_HEAVY_1      "pistol_standard"
#define TOD_SECSTEM_HEAVY_2      "t6_rpg"
#define TOD_SECSTEM_HEAVY_3      "t9_nail_gun"
#define TOD_SECSTEM_SLASHER_1    "t9_amp63"
#define TOD_SECSTEM_SLASHER_2    "iw7_udm"
#define TOD_SECSTEM_SLASHER_3    "t8_rk7"

#namespace tod_classes;

function init()
{
	level.tod_classes = [];
	level.tod_class_count = 0;
	// Registration ORDER = the class id the draft (_tod_class_select::class_key,
	// tod_class_select.lua) and the TIER card's class code use: 1 SKIRMISHER /
	// 2 ASSAULT / 3 HEAVY / 4 SLASHER. Never reorder.
	register_class( "skirmisher", "SKIRMISHER", ( -390, -280, 0 ) );
	register_class( "assault",    "ASSAULT",    ( -280, -280, 0 ) );
	register_class( "heavy",      "HEAVY",      ( -170, -280, 0 ) );
	register_class( "slasher",    "SLASHER",    (  -60, -280, 0 ) );

	// PaP table repair — see repair_weapon_table(). Threaded, waits for the
	// blackscreen flag so stock's weapons table is fully built first.
	level thread repair_weapon_table();

	// ---- TIER LADDERS — PHASE 1 NULL LADDER (every tier = the T1 gun) -------
	// register_gun( class, tier, stem, pap suffix, variant axes, alt weapon, grant )
	//   stem     the runtime asset stem; variants are stem[+pap][+suffix]
	//            (asset ids may carry a trailing _zm the engine strips — the
	//            knife does; runtime names are bare, so stems never carry it)
	//   axes     the gun's generated twin ladder(s) -> the variant suffix
	//            (_f1h2 / _r0m3 / _p1 / _k4); undefined = a single base form "_b"
	//   alt      an extra weapon given with the gun (the slasher's bowie)
	//   grant    a domain key set to Lv1 the moment the gun arrives by tier-up
	//            (the Stormbreaker arrives with THOR'S THUNDER) — Phase 2
	// SMG CLASS UPDATE (user 2026-08-23, v9.44): FIRE RATE (f) is the MAC-10's
	// alone, HANDLING (h) is every SMG, MAG SIZE (m) left the class. Axis
	// letters + ORDER mirror gen_tod_twins.js LADDER.skirmisher exactly — the
	// variant suffix is composed from this list (_f1h2 / _h3).
	register_gun( "skirmisher", 1, "t9_mac10",             "_up", axes2( "firerate", "f", "handling", "h" ), undefined,     undefined );   // Phase 2a: MAC-10 opens the run
	register_gun( "skirmisher", 2, "t9_mp5",               "_up", axes1( "handling", "h" ),                 undefined,     undefined );   // v9.44: f-ladder retired
	register_gun( "skirmisher", 3, "t6_mp7",               "_up", axes1( "handling", "h" ),                 undefined,     undefined );   // Phase 2d: the BO2 MP7 — v9.44: m -> h
	register_gun( "assault",    1, "t5_enfield",           "_up", axes2( "recoil", "r", "magsize", "m" ),   undefined,     undefined );   // Phase 2b: Enfield opens the run
	register_gun( "assault",    2, "t9_krig6",             "_up", axes2( "recoil", "r", "magsize", "m" ),    undefined,     undefined );
	register_gun( "assault",    3, "t9_ak47",              "_up", axes2( "recoil", "r", "magsize", "m" ),   undefined,     undefined );   // Phase 2e: the CW AK-47
	register_gun( "heavy",      1, "t9_stoner63",          "_up", axes1( "penetration", "p" ),              undefined,     undefined );
	// PENETRATION MOVED HK21 -> DEATH MACHINE (user 2026-08-24). This list, the
	// LADDER axes in tools/gen_tod_twins.js and set_guns( "penetration" ) in
	// _tod_upgrades.gsc are three views of ONE fact — the variant suffix is
	// composed from the axes named here, so any one of them left behind makes
	// the script ask GetWeapon for a form the generator never emitted.
	register_gun( "heavy",      2, "t5_hk21",              "_up", undefined,                               undefined,     undefined );   // Phase 2c: the BO1 HK21 — p-ladder retired 2026-08-24, one "_b" form
	register_gun( "heavy",      3, "t6_death_machine",     "_up", axes1( "penetration", "p" ),              undefined,     undefined );   // Phase 2f: the BO2 Death Machine — carries the p-ladder since 2026-08-24
	register_gun( "slasher",    1, "t9_me_knife_american", "_up", axes1( "knifespeed", "k" ),               "bowie_knife", undefined );
	register_gun( "slasher",    2, "t9_me_wakizashi",      "_up", axes1( "knifespeed", "k" ),               "bowie_knife", undefined );   // Phase 2h: the KATANA (pmr360's BOCW Wakizashi)
	register_gun( "slasher",    3, "leviathan",            "_up", axes1( "knifespeed", "k" ),               "bowie_knife", "thunder" );   // Phase 2g: STORMBREAKER (the Leviathan port) arrives with THOR'S THUNDER Lv1

	// ---- ASSET TAILS (2026-08-23) -----------------------------------------
	// Some ports name their generated forms with a TRAILING "_zm" AFTER the
	// ladder suffix, and it is not consistent between a gun's base and PaP
	// forms. The generator (gen_tod_twins.js LADDER[].forms[].name) is the
	// source of truth; these three lines mirror it, and variant_name() below is
	// the ONLY place that assembles a name from the parts.
	//
	// WHAT THIS BUG COST (user 2026-08-23: "why couldnt i pap my enfield"): the
	// script built "t9_me_knife_american_k3" while the asset is
	// "t9_me_knife_american_k3_zm", so GetWeapon returned weaponNone and
	// reconcile_twin took its "variant not linked" early-out. Silently. That
	// meant KNIFE SPEED never moved a blade on ANY of the three slasher guns,
	// and a PaP'd Enfield could not walk its recoil/mag ladder either — no
	// error, no log line, the upgrade just did nothing.
	//
	// If a NEW gun is added, check its forms[].name in the generator and add a
	// line here when either form carries a tail. The generator's csv/zone
	// cross-check catches the CSV half of this class of bug; this is the GSC half.
	// NO set_tails CALLS. This was briefly wrong in the other direction on
	// 2026-08-23 and it BROKE THE KNIFE, so the evidence is written down here:
	//
	//   THE ENGINE STRIPS A TRAILING "_zm" FROM A WEAPON ASSET NAME.
	//   The script name is the asset name WITHOUT it.
	//
	// Proof, three independent shipped sources:
	//   * map 1 zones ONLY "leviathan_zm" / "leviathan_up_zm" and its weapons
	//     CSV says "leviathan,leviathan_up" — and map 1's Leviathan works.
	//   * map 1 zones ONLY "freezegun_zm" / "freezegun_upgraded_zm"; CSV says
	//     "freezegun,freezegun_upgraded".
	//   * THIS map: the asset is "t9_amp63_rdw_up_zm" and the hand-authored CSV
	//     row is "t9_amp63,t9_amp63_rdw_up" — note "_rdw" is KEPT and only
	//     "_zm" is dropped, so it is that exact suffix and not a general rule.
	// And the live one: the slasher has been carrying a working blade the whole
	// time while the script asked GetWeapon for "<stem>_k0" against an asset
	// named "<stem>_k0_zm".
	//
	// So variant_name() returns the BARE name, weapon_or_zm() below tries the
	// "_zm" form as a fallback anyway (cheap, and it removes the guess), and the
	// generator strips "_zm" when it writes the weapons CSV.

	// MELEE DAMAGE PER BLADE (docs/25 §6 MELEE_TIER_DMG — the generator bakes
	// the same numbers into the assets; this table is the script-side mirror,
	// because weapon objects do not expose meleeDamage to script). [base, PaP]
	//
	// CURRENTLY UNCONSUMED (2026-08-24): melee_dmg() below had exactly one
	// caller — CHAIN LUNGE's DoDamage — and that module was removed. The table
	// is kept because it is the readable mirror of the generator's numbers and
	// the hook any future script-side melee hit will need. If nothing has
	// consumed it by the next melee pass, DELETE it rather than let two copies
	// of one number drift apart (this repo has already paid for that once, in
	// _tod_bosses.gsc's hand-copied upgrade constants).
	level.tod_melee_dmg = [];
	// MELEE LADDER (user 2026-08-23: "they are scaling way too high... once you
	// get the katana you can one hit rest of game... I see 20k which is crazy").
	// MUST STAY IN LOCKSTEP with MELEE_TIER_DMG in tools/gen_tod_twins.js — the
	// GSC value drives any script-side DoDamage, the generator value drives the
	// asset's meleeDamage. They are two copies of one number.
	//
	// The old ladder was 1700/20000, 20000/40000, 40000/80000. Its real flaw
	// was not the top end but the FIRST STEP: the knife's PaP was a x11.8 jump
	// (1700 -> 20000) while every other step doubled, so a PaP'd TIER-1 knife
	// already hit as hard as the katana — 20000 one-hits to round 38, or round
	// 54 with the DAMAGE domain maxed. That is the whole game, which is exactly
	// what the user reported.
	//
	// Now a clean x2 ladder that mirrors the GUN rule (tier N base = tier N-1
	// PaP). Against this map's zombie HP (stock curve x TOD_ZHEALTH_MULT 1.25:
	// r20 ~3.4k, r30 ~8.8k, r40 ~22.8k) the one-hit reach is:
	//   knife  2000 -> r14   PaP  4000 -> r21
	//   katana 4000 -> r21   PaP  8000 -> r29
	//   storm  6800 -> r28   PaP 13600 -> r35   (r43 with DAMAGE 10)
	// STORMBREAKER -15% (user 2026-08-24: "Storm breaker needs an all around
	// nerf by like 15%") — 8000/16000 -> 6800/13600. It is the one rung that now
	// breaks "tier N base = tier N-1 PaP": a PaP'd katana (8000) out-hits a fresh
	// axe (6800) until the axe is PaP'd. ~1 round of one-hit reach, accepted as
	// the direct cost of nerfing the top rung on its own.
	// So every tier buys ~7-8 more rounds of one-hitting and melee stops being
	// a free win around r36 — strong, never permanent.
	register_melee_dmg( "t9_me_knife_american", 2000, 4000 );
	register_melee_dmg( "t9_me_wakizashi",      4000, 8000 );
	register_melee_dmg( "leviathan",            6800, 13600 );   // -15% 2026-08-24

	check_stem_prefixes();

	callback::on_spawned( &on_player_spawned );

	// Class-switch STATIONS REMOVED (user 2026-08-20: "you are not able to
	// switch class once game has started"). The game-start draft assigns the
	// class permanently.
}

function register_class( key, display, station_org )
{
	c = SpawnStruct();
	c.key = key;
	c.display = display;
	c.station_org = station_org;   // vestigial (stations removed 2026-08-20), harmless
	c.tiers = [];
	level.tod_class_count++;
	c.id = level.tod_class_count;  // 1..4, registration order (see init)
	level.tod_classes[ key ] = c;
}

function register_gun( class_key, tier, stem, up_suffix, axes, alt, grant )
{
	g = SpawnStruct();
	g.class_key = class_key;
	g.tier = tier;
	g.stem = stem;
	g.up_suffix = up_suffix;   // the port's PaP form suffix ("_up" skye / "_upgraded" stock-style)
	g.axes = axes;             // array of { domain, letter } or undefined
	g.alt = alt;               // extra class weapon (slasher's bowie) or undefined
	g.grant = grant;           // domain key granted at Lv1 on arrival, or undefined
	level.tod_classes[ class_key ].tiers[ tier ] = g;
}

function register_melee_dmg( stem, base, up )
{
	m = SpawnStruct();
	m.stem = stem;
	m.base = base;
	m.up = up;
	level.tod_melee_dmg[ level.tod_melee_dmg.size ] = m;
}

// PUBLIC — the melee damage the held blade deals (base or PaP form by name).
// Unknown blade -> the knife's PaP value (the pre-tier behaviour).
function melee_dmg( weapon )
{
	if ( isdefined( weapon ) && isdefined( weapon.name ) && isdefined( level.tod_melee_dmg ) )
	{
		for ( i = 0; i < level.tod_melee_dmg.size; i++ )
		{
			m = level.tod_melee_dmg[ i ];
			if ( !IsSubStr( weapon.name, m.stem ) )
				continue;
			if ( IsSubStr( weapon.name, "_up" ) )
				return m.up;
			return m.base;
		}
	}
	// Unknown blade -> the KNIFE'S BASE. Was 20000 (the old knife-PaP value),
	// which after the 2026-08-23 retune would have made any unrecognised blade
	// hit 5x harder than the top-tier Stormbreaker's base. A fallback should be
	// the floor of the ladder, never above its ceiling.
	return 2000;
}

// PUBLIC — THE one place a variant asset name is assembled. Every caller that
// used to concatenate stem + up_suffix + suffix by hand must come through here,
// or the tails above are silently dropped again.
function variant_name( g, is_up, suffix )
{
	if ( !isdefined( g ) )
		return "";
	n = g.stem;
	if ( is_up )
		n += g.up_suffix;
	return n + suffix;
}

// ---------------------------------------------------------------------------
// PACK-A-PUNCH SELF-REPAIR (2026-08-23)
// ---------------------------------------------------------------------------
// Stock PaP resolves an upgrade PURELY through level.zombie_weapons[base].upgrade,
// which is built once from the weapons stringtable. If a row's upgrade_name does
// not resolve to a real weapon, stock stores weaponNone there — and because
// weaponNone IS a defined value, can_upgrade_weapon() answers TRUE. The machine
// then takes the points and hands back nothing. That failure is completely
// silent: no error, no log, PaP just "doesn't work".
//
// This pass runs after the table is built and re-points any class-gun row whose
// upgrade is missing at the weapon we KNOW is linked, found through
// weapon_or_zm() so it works whichever spelling the engine ended up using. It
// repairs the symptom regardless of which of the three name sources is at
// fault, which is what a beta needs — the alternative is another guess.
//
// It only ever touches rows for OUR registered class guns, and only rows that
// are already broken, so a correct table is left completely untouched.
function repair_weapon_table()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );

	made = 0;
	foreach ( ck in GetArrayKeys( level.tod_classes ) )
	{
		c = level.tod_classes[ ck ];
		for ( t = 1; t <= c.tiers.size; t++ )
		{
			g = c.tiers[ t ];
			if ( !isdefined( g ) )
				continue;
			made += repair_gun_rows( g );
		}
	}
	level.tod_pap_rows_repaired = made;
}

// Walk every ladder combination this gun can reach and make sure the weapons
// table carries a row whose upgrade RESOLVES. Level bound is a flat 0..5: the
// real caps live in the generator's AXIS table and in add_domain, and importing
// _tod_upgrades to read them would be a cycle (it imports us). Over-scanning is
// free — a combination that does not exist simply fails to resolve and is
// skipped, and this runs once at level start.
function repair_gun_rows( g )
{
	n = 0;
	if ( !isdefined( g.axes ) || g.axes.size == 0 )
		return repair_one_row( g, "_b" );

	if ( g.axes.size == 1 )
	{
		for ( a = 0; a <= 5; a++ )
			n += repair_one_row( g, "_" + g.axes[ 0 ].letter + a );
		return n;
	}

	for ( a = 0; a <= 5; a++ )
	{
		for ( b = 0; b <= 5; b++ )
			n += repair_one_row( g, "_" + g.axes[ 0 ].letter + a + g.axes[ 1 ].letter + b );
	}
	return n;
}

// One (base, PaP) pair. Returns 1 if it (re-)registered the pair.
//
// WHY RE-REGISTER RATHER THAN PATCH THE STRUCT: stock's own add_zombie_weapon
// builds the row exactly the way PaP expects (including weapon_classname and
// the zombie_weapons_upgraded back-reference). Hand-building a struct that only
// LOOKS right is how a silent half-fix happens.
//
// AND WHY IT DOES NOT MATTER which spelling is correct: resolved_name() returns
// whichever of "<name>" / "<name>_zm" actually resolves to a linked weapon, so
// this repairs the table under either engine behaviour. That is deliberate —
// the naming question cost two wrong fixes on 2026-08-23 and this closes it by
// asking the engine at runtime instead of inferring from build artifacts.
function repair_one_row( g, suffix )
{
	base_n = resolved_name( variant_name( g, false, suffix ) );
	if ( !isdefined( base_n ) )
		return 0;
	up_n = resolved_name( variant_name( g, true, suffix ) );
	if ( !isdefined( up_n ) )
		return 0;

	base_w = GetWeapon( base_n );
	if ( isdefined( level.zombie_weapons ) && isdefined( level.zombie_weapons[ base_w ] ) )
	{
		st = level.zombie_weapons[ base_w ];
		if ( isdefined( st.upgrade ) && st.upgrade != level.weaponNone )
			return 0;   // already correct — leave stock's row exactly as it is
	}

	// include first: add_zombie_weapon early-returns on a non-included weapon.
	zm_utility::include_weapon( base_n, false );
	zm_utility::include_weapon( up_n, false );
	zm_weapons::add_zombie_weapon( base_n, up_n, undefined, 1250, "rifle", undefined, undefined, undefined, false, "" );
	return 1;
}

// -> the spelling of `name` that resolves to a real weapon, or undefined.
function resolved_name( name )
{
	if ( !isdefined( name ) || name == "" )
		return undefined;
	w = GetWeapon( name );
	if ( isdefined( w ) && w != level.weaponNone )
		return name;
	w = GetWeapon( name + "_zm" );
	if ( isdefined( w ) && w != level.weaponNone )
		return name + "_zm";
	return undefined;
}

// PUBLIC — GetWeapon for a variant name, tolerant of the "_zm" asset tail.
// Every shipped precedent says the bare name is the right one (see the block in
// register_guns), so that is tried FIRST; the tailed form is a belt-and-braces
// fallback so a future port that behaves differently degrades to "works"
// instead of "the upgrade silently does nothing", which is how the blade bug
// hid for weeks.
function weapon_or_zm( name )
{
	if ( !isdefined( name ) || name == "" )
		return undefined;
	w = GetWeapon( name );
	if ( isdefined( w ) && w != level.weaponNone )
		return w;
	w = GetWeapon( name + "_zm" );
	if ( isdefined( w ) && w != level.weaponNone )
		return w;
	return undefined;
}

function axes1( d1, l1 )
{
	a = [];
	a[ 0 ] = axis( d1, l1 );
	return a;
}

function axes2( d1, l1, d2, l2 )
{
	a = [];
	a[ 0 ] = axis( d1, l1 );
	a[ 1 ] = axis( d2, l2 );
	return a;
}

function axis( domain, letter )
{
	x = SpawnStruct();
	x.domain = domain;
	x.letter = letter;
	return x;
}

// STEM-PREFIX TRAP: is_class_primary matches by substring, so two stems in one
// ladder where one is a prefix of the other ("t9_mp5" / "t9_mp5k") would
// cross-match. Identical stems (the null ladder) are fine. Dev-visible only.
function check_stem_prefixes()
{
	foreach ( c in level.tod_classes )
	{
		for ( i = 1; i <= TOD_TIER_MAX; i++ )
		{
			for ( j = 1; j <= TOD_TIER_MAX; j++ )
			{
				if ( i == j || !isdefined( c.tiers[ i ] ) || !isdefined( c.tiers[ j ] ) )
					continue;
				a = c.tiers[ i ].stem;
				b = c.tiers[ j ].stem;
				if ( a != b && IsSubStr( b, a ) )
				{
					level.tod_stem_clash = a + " < " + b;
					/# PrintLn( "^1[tod] STEM PREFIX CLASH in class " + c.key + ": " + a + " is a prefix of " + b ); #/
				}
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Lookups — every "what gun does this player hold" question goes through here
// ---------------------------------------------------------------------------

function tier_max()
{
	return TOD_TIER_MAX;
}

function get_class( player )
{
	if ( !isdefined( player ) || !isdefined( player.tod_class ) )
		return undefined;
	return level.tod_classes[ player.tod_class ];
}

// The player's tier (1 until a TIER card is taken).
function tier( player )
{
	if ( !isdefined( player ) || !isdefined( player.tod_tier ) )
		return 1;
	return player.tod_tier;
}

// 1..4 for the draft / tier-card class code, 0 if unknown.
function class_id( key )
{
	if ( !isdefined( key ) || !isdefined( level.tod_classes[ key ] ) )
		return 0;
	return level.tod_classes[ key ].id;
}

function gun_at( class_key, t )
{
	if ( !isdefined( class_key ) || !isdefined( level.tod_classes[ class_key ] ) )
		return undefined;
	c = level.tod_classes[ class_key ];
	// a tier with no registered gun falls back to the highest registered
	// below it — never hand out nothing
	for ( i = t; i >= 1; i-- )
	{
		if ( isdefined( c.tiers[ i ] ) )
			return c.tiers[ i ];
	}
	return undefined;
}

// The gun struct the player holds NOW (their class + tier), or undefined.
function gun( player )
{
	if ( !isdefined( player ) || !isdefined( player.tod_class ) )
		return undefined;
	return gun_at( player.tod_class, tier( player ) );
}

// The gun the NEXT tier would hand out, or undefined at the top.
function next_gun( player )
{
	if ( !isdefined( player ) || !isdefined( player.tod_class ) )
		return undefined;
	t = tier( player ) + 1;
	if ( t > TOD_TIER_MAX )
		return undefined;
	if ( !isdefined( level.tod_classes[ player.tod_class ].tiers[ t ] ) )
		return undefined;
	return level.tod_classes[ player.tod_class ].tiers[ t ];
}

function gun_stem( player )
{
	g = gun( player );
	if ( !isdefined( g ) )
		return undefined;
	return g.stem;
}

// The level-0 variant suffix of a gun ("_f0h0" / "_r0m0" / "_p0" / "_k0", or
// "_b" for an axis-less gun) — the form give_class_loadout and a tier-up hand
// out; _tod_upgrades::reconcile_twin then walks it to the player's levels.
function base_suffix( g )
{
	if ( !isdefined( g ) || !isdefined( g.axes ) || g.axes.size == 0 )
		return "_b";
	s = "_";
	for ( i = 0; i < g.axes.size; i++ )
		s += g.axes[ i ].letter + "0";
	return s;
}

// The weapon object for a gun's level-0 form; falls back to the RAW stem (the
// four T1 raw assets are zoned) and finally undefined — callers must check.
function base_weapon( g )
{
	if ( !isdefined( g ) )
		return undefined;
	w = weapon_or_zm( variant_name( g, false, base_suffix( g ) ) );
	if ( isdefined( w ) && w != level.weaponNone )
		return w;
	w = GetWeapon( g.stem );
	if ( isdefined( w ) && w != level.weaponNone )
		return w;
	return undefined;
}

// ---------------------------------------------------------------------------
// Spawn / give
// ---------------------------------------------------------------------------

// self = player. Fires on every spawn (initial + round respawns) — re-give
// the loadout every time (respawned players lose weapons). Class assignment:
// the game-start draft (_tod_class_select) owns it; a classless player only
// gets a RANDOM class here when they arrive AFTER the draft closed (drop-in
// join). Before/during the draft, stay classless — the draft assigns.
function on_player_spawned()
{
	self endon( "disconnect" );

	if ( !isdefined( self.tod_class ) && IS_TRUE( level.tod_class_select_done ) )
		assign_class( self, random_class_key() );

	self thread give_class_loadout();   // no-op while still classless
}

function random_class_key()
{
	keys = GetArrayKeys( level.tod_classes );
	return keys[ RandomInt( keys.size ) ];
}

function assign_class( player, key )
{
	player.tod_class = key;
	if ( !isdefined( player.tod_tier ) )
		player.tod_tier = 1;
	player notify( "tod_class_assigned" );
}

// self = player. Gives the CURRENT TIER's gun (a respawn after a tier-up gets
// the promoted gun, never the T1 one), its alt, and the secondary.
function give_class_loadout()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	g = gun( self );
	if ( !isdefined( g ) )
		return;

	wait 0.5;   // let the stock loadout give (start pistol) finish first

	if ( !( self has_gun( g ) ) )
	{
		want = base_weapon( g );
		if ( isdefined( want ) )
		{
			self GiveWeapon( want );
			self GiveStartAmmo( want );
			self SwitchToWeapon( want );
		}
	}

	// the alt melee (the slasher's bowie replaces the base knife everywhere)
	if ( isdefined( g.alt ) )
	{
		alt = GetWeapon( g.alt );
		if ( isdefined( alt ) && alt != level.weaponNone && !( self HasWeapon( alt ) ) )
			self GiveWeapon( alt );
	}

	// TIER-KEYED: a respawn after a tier-up must hand back the sidearm that
	// matches the promoted gun, exactly the way the primary already does
	// (`gun( self )` above resolves by tier). Passing the class alone would
	// quietly demote every player back to their T1 sidearm on death.
	self give_secondary( g.class_key, tier( self ) );
}

// self = player. Strip any OTHER class's sidearm before handing out this
// class's. Needed the moment secondaries went per-class: the base stations let
// a player switch class mid-run, and sidearms sit in PRIMARY slots — so without
// this, one switch leaves you holding two and the stock too-many-weapons
// monitor that would normally reap the extra is deliberately OFF on this map
// (v9.18: it was confiscating class guns). Matched on the STEM, because the
// PaP form is a separate asset name — "t9_amp63_rdw_up_zm" and "s1_bulldog_up"
// both have to be caught, not just the base.
function take_foreign_secondaries( keep_stem )
{
	// MATCH on the stems, never on the give names — see the TOD_SEC_* block.
	// ALL TWELVE, not just this class's three. A player who switches class at a
	// base station keeps whatever they were carrying, so the sidearm to reap can
	// belong to any class AND any tier — and since v10.24 a tier-up inside one
	// class also has an old sidearm to clear. Reaping only the current class's
	// rows would leave the tier-1 shotgun in a primary slot next to the tier-3
	// one, which is precisely the two-sidearms bug this function exists to stop.
	stems = secondary_all_stems();

	weapons = self GetWeaponsListPrimaries();
	for ( i = 0; i < weapons.size; i++ )
	{
		w = weapons[ i ];
		if ( !isdefined( w ) || !isdefined( w.name ) )
			continue;
		if ( IsSubStr( w.name, keep_stem ) )
			continue;   // the sidearm we are keeping, in any form — leave it
		for ( j = 0; j < stems.size; j++ )
		{
			if ( stems[ j ] == keep_stem )
				continue;
			if ( IsSubStr( w.name, stems[ j ] ) )
			{
				self TakeWeapon( w );
				break;
			}
		}
	}
}

// PUBLIC — every sidearm match stem in the map, all four classes x three tiers.
function secondary_all_stems()
{
	return array( TOD_SECSTEM_SKIRMISHER_1, TOD_SECSTEM_SKIRMISHER_2, TOD_SECSTEM_SKIRMISHER_3,
	              TOD_SECSTEM_ASSAULT_1,    TOD_SECSTEM_ASSAULT_2,    TOD_SECSTEM_ASSAULT_3,
	              TOD_SECSTEM_HEAVY_1,      TOD_SECSTEM_HEAVY_2,      TOD_SECSTEM_HEAVY_3,
	              TOD_SECSTEM_SLASHER_1,    TOD_SECSTEM_SLASHER_2,    TOD_SECSTEM_SLASHER_3 );
}

// A tier clamped into 1..TOD_TIER_MAX. Every lookup below runs through this so
// an undefined or out-of-range tier can never fall off the end of a switch and
// return a sidearm for a tier that does not exist.
function sec_tier_clamp( tier )
{
	if ( !isdefined( tier ) || tier < 1 )
		return 1;
	if ( tier > TOD_TIER_MAX )
		return TOD_TIER_MAX;
	return tier;
}

// PUBLIC — the sidearm ASSET NAME for a (class, tier). An unknown class falls
// back to the starter pistol, which is always registered, so a classless or
// mis-keyed player can never end up with no secondary at all.
function secondary_name( class_key, tier )
{
	t = sec_tier_clamp( tier );
	if ( isdefined( class_key ) )
	{
		switch ( class_key )
		{
			case "skirmisher":
				if ( t == 1 ) return TOD_SEC_SKIRMISHER_1;
				if ( t == 2 ) return TOD_SEC_SKIRMISHER_2;
				return TOD_SEC_SKIRMISHER_3;
			case "assault":
				if ( t == 1 ) return TOD_SEC_ASSAULT_1;
				if ( t == 2 ) return TOD_SEC_ASSAULT_2;
				return TOD_SEC_ASSAULT_3;
			case "heavy":
				if ( t == 1 ) return TOD_SEC_HEAVY_1;
				if ( t == 2 ) return TOD_SEC_HEAVY_2;
				return TOD_SEC_HEAVY_3;
			case "slasher":
				if ( t == 1 ) return TOD_SEC_SLASHER_1;
				if ( t == 2 ) return TOD_SEC_SLASHER_2;
				return TOD_SEC_SLASHER_3;
		}
	}
	return TOD_SEC_HEAVY_1;   // pistol_standard
}

// PUBLIC — the MATCH STEM for a (class, tier). Same shape and same fallback as
// secondary_name; keep the two switches in lockstep.
function secondary_stem( class_key, tier )
{
	t = sec_tier_clamp( tier );
	if ( isdefined( class_key ) )
	{
		switch ( class_key )
		{
			case "skirmisher":
				if ( t == 1 ) return TOD_SECSTEM_SKIRMISHER_1;
				if ( t == 2 ) return TOD_SECSTEM_SKIRMISHER_2;
				return TOD_SECSTEM_SKIRMISHER_3;
			case "assault":
				if ( t == 1 ) return TOD_SECSTEM_ASSAULT_1;
				if ( t == 2 ) return TOD_SECSTEM_ASSAULT_2;
				return TOD_SECSTEM_ASSAULT_3;
			case "heavy":
				if ( t == 1 ) return TOD_SECSTEM_HEAVY_1;
				if ( t == 2 ) return TOD_SECSTEM_HEAVY_2;
				return TOD_SECSTEM_HEAVY_3;
			case "slasher":
				if ( t == 1 ) return TOD_SECSTEM_SLASHER_1;
				if ( t == 2 ) return TOD_SECSTEM_SLASHER_2;
				return TOD_SECSTEM_SLASHER_3;
		}
	}
	return TOD_SECSTEM_HEAVY_1;
}

// PUBLIC — self = player. Swap the sidearm to the one this (class, tier) owns.
// Called by the tier-up path and by give_class_loadout via its own inline pair.
// Returns true if the player is holding the right sidearm when it returns.
function give_secondary( class_key, tier )
{
	keep = secondary_name( class_key, tier );
	self take_foreign_secondaries( secondary_stem( class_key, tier ) );

	w = GetWeapon( keep );
	if ( !isdefined( w ) || w == level.weaponNone )
		return false;

	// OWNERSHIP IS TESTED ON THE STEM, NOT THE BASE NAME (2026-08-25).
	//
	// HasWeapon( base ) is FALSE once the sidearm has been Pack-a-Punched — the
	// PaP form is a different asset (t8_sg12_up_b, not t8_sg12_b). So a player
	// who packs their secondary and then respawns, switches class, or tiers up
	// was handed a SECOND, un-packed copy of it: two sidearms in primary slots,
	// on a map where the stock too-many-weapons monitor is deliberately OFF
	// (v9.18). take_foreign_secondaries cannot save us either — it matches the
	// same stem and correctly leaves the packed one alone.
	//
	// This is the same rule has_gun() already applies to the class primary: hold
	// ANY form of it and you own it. It matters far more now that packing a
	// secondary before the primary is a normal thing to do.
	if ( self holds_secondary_stem( secondary_stem( class_key, tier ) ) )
		return true;

	self GiveWeapon( w );
	self GiveStartAmmo( w );
	return true;
}

// self = player. Holds ANY form (base / PaP / twin variant) of a sidearm stem.
function holds_secondary_stem( stem )
{
	if ( !isdefined( stem ) || stem == "" )
		return false;
	weapons = self GetWeaponsListPrimaries();
	foreach ( w in weapons )
	{
		if ( isdefined( w ) && isdefined( w.name ) && IsSubStr( w.name, stem ) )
			return true;
	}
	return false;
}

// self = player. Holds ANY form (base / PaP / twin variant) of gun g.
function has_gun( g )
{
	if ( !isdefined( g ) )
		return false;
	weapons = self GetWeaponsListPrimaries();
	foreach ( w in weapons )
	{
		if ( isdefined( w ) && IsSubStr( w.name, g.stem ) )
			return true;
	}
	return false;
}

// Public: is this weapon the player's class primary — the CURRENT tier's gun
// in any form (base, PaP, any twin variant: every variant name embeds the
// stem), or that gun's alt weapon (the bowie counts for every kill hook).
function is_class_primary( player, weapon )
{
	g = gun( player );
	if ( !isdefined( g ) || !isdefined( weapon ) || !isdefined( weapon.name ) )
		return false;
	if ( IsSubStr( weapon.name, g.stem ) )
		return true;
	return ( isdefined( g.alt ) && IsSubStr( weapon.name, g.alt ) );
}
