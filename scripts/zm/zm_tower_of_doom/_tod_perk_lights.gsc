// =============================================================================
// _tod_perk_lights.gsc — perk machine + Pack-a-Punch GLOW when power turns on
// (server half). DIRECT PORT of map 1's _acc_perk_lights (the auras ARE the
// power visual — the stock off_model->on_model swap shows no visible delta in
// this build, refuted live on map 1).
//
// MECHANISM (map 1, root-caused): server-side PlayFX does NOT render in this
// build. The path that renders is the CLIENT VM: the SERVER (this file) only
// sets a per-machine "todPerkGlow" colour-index clientfield once the
// "power_on" flag is set; the CLIENT (_tod_perk_lights.csc) PlayFXOnTag's the
// looped glow FX. Registration MUST be in lockstep with the .csc twin
// (scope/name/version/bits/type identical or the bit layout desyncs).
//
// REKICK (map 1's Paradise lesson, generalized for a vertical tower): the
// clientfield LATCHES at power-on, but an FX spawned far from the viewer never
// becomes visible on approach. So each glow ent re-pulses ONCE the first time
// a player gets near it (edge-triggered, 0->idx a snapshot apart).
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define TOD_GLOW_REKICK_DIST 700   // re-pulse a machine's glow when a player first gets this close

#namespace tod_perk_lights;

REGISTER_SYSTEM( "tod_perk_lights", &__init__, undefined )

function __init__()
{
	// scriptmover scope = the pool stock power-ups use for their glow clientfield;
	// script_models (machine + PaP host) are scriptmover-scope ents. 4 bits = 0..15.
	clientfield::register( "scriptmover", "todPerkGlow", VERSION_SHIP, 4, "int" );
}

// Threaded from tod_main::init() (gameplay time — NOT from __init__, which
// would risk the flag-wait-from-init crash).
function init()
{
	level thread power_glow_watch();
	level thread bo7_machine_assets_pass();   // v13.3b — see the pass's header
	level thread solo_qr_price_fix();         // v18.15 — a PRICE fix, not a gate; see its header
}

// SOLO QUICK REVIVE IS A PRICE FIX, NOT A GATE (v18.15).
//
// THE RULE, from the user 2026-09-07 after playing v18.14: "You should be able
// to buy a quick revive before turning on power on the solo. It should still be
// five hundred, and it should still work." That is also exactly what stock
// does, and it is classic-zombies tradition. This function exists ONLY to make
// the price and the sign correct; it must never stand between the player and
// the machine.
//
// TWO BUGS AND ONE SELF-INFLICTED REGRESSION, in order, because the shape of
// the mistake matters more than the fix:
//
// 1. v13.5/v13.6 tried to GATE this, to satisfy an older reading of the map
//    rule "every perk dark and unbuyable until the switch". It gated it by
//    writing `t.power_on = false` on the vending trigger, believing that field
//    "drives stock's native refusal AND the kit's Power Required card".
//    IT DRIVES NEITHER. In _zm_perks.gsc the buy loop (~:537-609) tests
//    HasPerk, custom_perk_validation, points and the perk limit and NEVER reads
//    .power_on; the field is read only at the end of vending_trigger_post_think
//    (~:659-665) — the "machine was powered down WHILE DRINKING" safety —
//    as `if ( !IS_TRUE( self.power_on ) ) { wait 1; perk_pause( ... ); }`.
//    So the sale went through and the perk was UnsetPerk'd a second later. In
//    solo the give hook had already run (self.lives = 1, solo_lives_given++)
//    and take_quick_revive_perk has an EMPTY body, so the player was left
//    holding a life with no perk: player_laststand (_zm.gsc:2521-2527) needs
//    BOTH, so the next down skipped last stand entirely and ended the run.
//    That is the Workshop report (fckspencer 2026-09-07, "quick revive not
//    working on solo ... i just die, no effect from quick revive").
//
// 2. v18.14 fixed the poisoning by TAKING THE TRIGGER OFF THE AIR until power
//    (TriggerEnable(false)). The perk stopped being stolen — and stopped being
//    BUYABLE, which nobody had asked for. The user found it in one session:
//    "that's a new regression just introduced." The error was treating a stale
//    design note in this file's own header as the requirement, instead of
//    asking what the behaviour should be. A ten-day-old bug does not license a
//    behaviour change smuggled in beside its fix.
//
// SO, NOW: no gate of any kind. .power_on is LEFT TRUE where stock stamps it
// (_zm_perk_quick_revive.gsc:202), which is what keeps the post-purchase pause
// from ever arming — that single non-write is the whole fix for bug 1. Do NOT
// write that field false here again, for any reason.
//
// WHAT IS STILL WORTH DOING, and why it has to wait for stock:
//   * THE PRICE. Stock registers QR's cost through revive_cost_override(),
//     which prices by GetPlayers().size — and at registration that count is
//     ZERO, so solo evaluates as "not solo" and 1500 sticks. Stock's own
//     repricer (update_quick_revive) runs only from the HOT-JOIN check, a
//     no-op in a solo game. The value is LATCHED onto the trigger as t.cost
//     (_zm_perks.gsc ~:496-500), so the fix must land on the trigger, not on
//     the _custom_perks table, and must land AFTER the latch.
//   * THE SIGN. Stock stamps the buy hint ONCE (~:528-531) with that same 1500
//     local and never re-stamps it — the think then parks in waittill("trigger")
//     forever. So v13.6 corrected the CHARGE and left the SIGN reading 1500,
//     which is the half the player actually reads. Re-stamped here with the
//     same hint_string and 500: one extra DISTINCT triggerstring for the match
//     (500 is a compile-time constant, so it can never mint a second).
//   * THE MESH. Solo QR is genuinely powered and selling from round 1, so it
//     should LOOK powered; coherence_pass already lights it off the same true
//     .power_on. The explicit SetModel is the immediate one, so the machine is
//     never briefly dark on a machine you can already use.
//
// The 10 s cap on the stamp wait is so a surprise flow can never hang us; if it
// expires we still write the price, which is strictly better than not.
// Co-op (v19.11 + 2026-09-24): the same re-assert with 1500, but only AFTER the
// power switch — see the co-op wait below. (This line used to say co-op was
// "untouched"; v19.11 changed that and the header did not follow.)
function solo_qr_price_fix()
{
	level endon( "end_game" );

	// v19.11 — CO-OP WAS PRICED 500 (Workshop / user 2026-09-15: "QR is broken
	// ... For coop it says 500. We just need two prices 500 solo and 1500
	// coop"). The gate below used to be `GetPlayers().size != 1` evaluated the
	// instant the FIRST player existed — and in co-op the host exists alone for
	// a moment before the second client finishes connecting, so a two-player
	// game passed the solo test and this function then re-asserted 500 onto the
	// trigger for 20 s, stamping over stock's correct 1500. THE PARTY SIZE IS NOT
	// KNOWN UNTIL STOCK SAYS SO: _zm.gsc waits for every expected player, sets
	// "all_players_connected", and only THEN decides "solo_game" from the
	// settled count. Wait for that flag and read that decision — the same two
	// facts stock's own laststand / solo-revive lanes run on.
	//
	// TWO PRICES, ONE PER BRANCH, BOTH ASSERTED THE SAME WAY. Solo keeps the
	// 500 fix exactly as it was. Co-op now runs the same re-assert loop with
	// 1500 — stock already lands 1500 there, but stock's own cost function
	// (revive_cost_override -> use_solo_revive) prices by the LIVE player count
	// at whatever instant it is called, and the whole point of this pass is
	// that nothing about this price may depend on a moment. The pair
	// (hint_string, 1500) is the string stock itself mints, so the co-op branch
	// costs no triggerstring slot.
	while ( !level flag::exists( "all_players_connected" ) )
		wait 0.25;   // stock inits the flag in zm::init; never wait on a flag before it exists
	level flag::wait_till( "all_players_connected" );
	solo = ( level flag::exists( "solo_game" ) && level flag::get( "solo_game" ) );
	price = 1500;
	if ( solo )
		price = 500;
	qr_price_dev_log( "party settled: players=" + GetPlayers().size + " solo_game=" + solo + " -> price " + price );

	t = undefined;
	triggers = GetEntArray( "zombie_vending", "targetname" );
	foreach ( tr in triggers )
	{
		if ( isdefined( tr.script_noteworthy ) && tr.script_noteworthy == "specialty_quickrevive" )
			t = tr;
	}
	if ( !isdefined( t ) )
		return;

	// CO-OP WAITS FOR THE SWITCH (2026-09-24, lead tester: "When at quick revive
	// it shows you can purchase it even without power yet you cannot, make it so
	// it prompts you to turn on power"). Unpowered co-op QR is parked in stock's
	// vending_trigger_think at `level waittill( perk + "_power_on" )` wearing
	// stock's "You must turn on the power first!" hint, which the prompt router
	// draws as the POWER REQUIRED card. The v19.11 co-op branch did not wait:
	// the stamp wait below timed out after 10 s (t.power_on stays false until
	// power), and the re-assert then stamped the BUY hint — a "Hold to buy" card
	// on a machine whose buy loop was not listening yet. Solo is unaffected
	// (stock powers solo QR from round 1; the user's rule, see the header).
	if ( !solo )
	{
		qr_price_dev_log( "co-op: waiting for power before re-stamping the price" );
		level flag::wait_till( "power_on" );
		qr_price_dev_log( "co-op: power on, re-stamping " + price );
	}

	// Wait out stock's one-shot stamps — t.power_on going true is the observable
	// end of its solo pass (~+3.0s) — then override the LATCHED field.
	for ( i = 0; i < 40 && !IS_TRUE( t.power_on ); i++ )
		wait 0.25;

	t.cost = price;   // the latched field the hint substitution and the charge both read
	if ( isdefined( level._custom_perks ) && isdefined( level._custom_perks[ "specialty_quickrevive" ] ) )
		level._custom_perks[ "specialty_quickrevive" ].cost = price;   // consistency for any later reader

	// Belt and braces: a LIVE trigger must never carry a false .power_on, or every
	// purchase gets paused a second later. Stock stamps it true; this covers the
	// path where its pass did not finish inside the cap above.
	t.power_on = true;

	// AND THE SIGN IS RE-ASSERTED, NOT STAMPED ONCE (v18.16). v18.15 wrote the
	// price and the hint a single time and shipped; the user photographed the
	// machine still reading 1500 on the very next build. The reason is a race we
	// cannot observe from here: stock's own stamp is the LAST line of a long
	// preamble in vending_trigger_think — after the QR block waits for
	// "start_zombie_round_logic", after SetHintString(&"ZOMBIE_NEED_POWER"), and
	// after a variable-length choke loop that waits one network frame PER VENDING
	// TRIGGER (level._perkmachinenetworkchoke). Our own start is gated on stock
	// stamping t.power_on from a different thread. Which lands last depends on
	// machine count and frame timing, so a single write is a coin flip, and it
	// came up tails in play.
	//
	// Re-asserting for 20 s is the honest fix: it cannot lose, and it costs
	// NOTHING against the 250-triggerstring cap because the cap counts DISTINCT
	// STRINGS — forty writes of the same (hint_string, 500) pair are one slot,
	// the same slot the first write already took. 20 s is far past anything stock
	// does at round-one init, and the loop then stops rather than running all
	// match.
	//
	// t.cost is re-written each pass for the same reason. It is the field the
	// CHARGE reads, and stock latches its own value into it in that same preamble
	// — so whichever of us went first, the player is charged 500.
	//
	// The _custom_perks entry is left at the int 500 set above: it is what stock
	// reads if anything ever re-derives the cost, and an int there beats the
	// registered &revive_cost_override pointer, which prices by GetPlayers().size
	// at whatever moment it happens to be called.
	for ( i = 0; i < 40; i++ )   // 40 x 0.5s = 20s
	{
		if ( !isdefined( t ) )
			return;
		if ( t.cost != price )
			qr_price_dev_log( "re-assert: trigger cost was " + t.cost + ", writing " + price );
		t.cost = price;
		if ( isdefined( level._custom_perks ) && isdefined( level._custom_perks[ "specialty_quickrevive" ] )
		  && isdefined( level._custom_perks[ "specialty_quickrevive" ].hint_string ) )
			t SetHintString( level._custom_perks[ "specialty_quickrevive" ].hint_string, price );
		wait 0.5;
	}

	if ( isdefined( level._custom_perks ) && isdefined( level._custom_perks[ "specialty_quickrevive" ] )
	  && isdefined( level._custom_perks[ "specialty_quickrevive" ].hint_string ) )
		t SetHintString( level._custom_perks[ "specialty_quickrevive" ].hint_string, price );
	qr_price_dev_log( "done: trigger cost " + t.cost + " (solo=" + solo + ")" );

	if ( solo && isdefined( t.machine ) && isdefined( level.machine_assets )
	  && isdefined( level.machine_assets[ "specialty_quickrevive" ] )
	  && isdefined( level.machine_assets[ "specialty_quickrevive" ].on_model ) )
		t.machine SetModel( level.machine_assets[ "specialty_quickrevive" ].on_model );
}

// v19.11 — dev log for the price decision above. Assembled outside the
// developer block, printed inside it (the proven pattern, CLAUDE.md).
function qr_price_dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_QR_PRICE] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

function power_glow_watch()
{
	level endon( "end_game" );

	level flag::wait_till( "initial_blackscreen_passed" );

	while ( !( level flag::exists( "power_on" ) && level flag::get( "power_on" ) ) )
		wait( 0.25 );

	glow_all_machines();
	level thread glow_rekick_watch();
}

// v13.3b — THE AUTHORITATIVE MODEL LANE (user: "check the trigger UI for all
// perks. Lets make sure no regressions on this migration" — and the check
// found one). The .map struct's model is NOT what players see for long:
// stock _zm_perks SetModels level.machine_assets[specialty].off_model /
// .on_model over every machine on the power transitions (:129/:140) and even
// reads model EQUALITY as power state (:1723). So machine_assets is the real
// switch, and the struct models only cover the pre-registration window. This
// pass overrides all nine specialties' entries to the BO7 pair — stock's own
// power flip then swaps to the lit meshes with no custom hook — and
// re-stamps any machine an earlier stock write already dressed in an old
// model. The nine keys mirror gen_tower_map.js PERK_PARK exactly; a
// specialty with no machine_assets entry (roster change) skips silently.
// Trigger/hint wiring is untouched on purpose: triggers key off
// script_noteworthy, which the migration never changed.
function bo7_off_models()
{
	t = [];
	t[ "specialty_armorvest" ]          = "t10_zm_machine_juggernog";
	t[ "specialty_fastreload" ]         = "t10_zm_machine_speed_cola_lava_all_fxanim";
	t[ "specialty_quickrevive" ]        = "t10_zm_machine_quick_revive";
	t[ "specialty_staminup" ]           = "t10_zm_machine_staminup";
	t[ "specialty_widowswine" ]         = "sat_zm_machine_y_mod";
	t[ "specialty_combat_efficiency" ]  = "t10_zm_machine_death_perception";   // v13.19 (was elemental_pop)
	t[ "specialty_doubletap2" ]         = "t10_zm_machine_d_mod_cowboy_fxanim";
	// specialty_deadshot ROW DELETED (v14.16 — machine retired for Wisp Tea).
	// WISP TEA (specialty_nomotionsensor) is ABSENT here ON PURPOSE: its pair
	// breaks this table's off+"_on" derivation only in spirit, not in name —
	// but the vendored module (_zm_perk_wisp_tea::wisp_tea_precache) already
	// writes its own machine_assets off/on entry at the right time, so this
	// pass and bo7_stamp_sweep skip it (unknown keys skip silently, by
	// design) and stock dresses it correctly from spawn.
	t[ "specialty_electriccherry" ]     = "t10_zm_machine_phd_flopper";
	return t;
}

function bo7_machine_assets_pass()
{
	level endon( "end_game" );

	offs = bo7_off_models();
	foreach ( spec, off in offs )
	{
		if ( !isdefined( level.machine_assets ) || !isdefined( level.machine_assets[ spec ] ) )
			continue;
		level.machine_assets[ spec ].off_model = off;
		level.machine_assets[ spec ].on_model  = off + "_on";
	}

	// RE-DRESS THE LIVE ENTITIES — the table alone is NOT enough, and this is
	// the half that covers the state nobody thinks to test (peer review
	// 2026-08-28). Stock perk_machine_think SetModels off_model onto every
	// machine at :129 and then PARKS on waittill(str_on): on this map power is
	// one-way (bought once, never off), so :129 fires exactly ONCE per machine
	// at perk-registration time — BEFORE this pass can rewrite the table. Table
	// right, entities wrong. Without a sweep every machine wears its OLD mesh
	// from spawn until the power flip, which is the whole opening of the run
	// with the base-wall row and the pinned Quick Revive in view. The
	// power-ON look would be correct, so flipping the switch and looking is
	// exactly the test that PASSES while this is broken.
	// Swept TWICE: once now (best effort — a machine whose trigger is not yet
	// blessed is simply skipped) and once when the blackscreen lifts, which is
	// the first frame anything is visible.
	bo7_stamp_sweep( offs );
	level flag::wait_till( "initial_blackscreen_passed" );
	bo7_stamp_sweep( offs );
}

// Stamps every one of our nine machines with the model it SHOULD be wearing
// right now. Idempotent, safe to call at any time. Returns the number changed.
//
// STATE-AWARE RATHER THAN GUARDED-OFF (peer refinement 2026-08-28). The first
// draft early-returned when power was on, which made the function safe after
// power but also USELESS after it — and the future watcher this exists for
// (repair a machine whose model got clobbered at round 30) is post-power BY
// DEFINITION. That author would have had to delete the guard to make their
// watcher work, reintroducing the exact "OFF mesh stamped over a lit roster"
// bug the guard was protecting against. Branching on power instead makes that
// failure impossible BY CONSTRUCTION rather than by caller discipline.
//
// The wanted model is read from level.machine_assets (which this module owns
// for all nine specialties) and not from the local table, so the sweep can
// never disagree with the switch stock itself reads.
function bo7_stamp_sweep( offs )
{
	// POWER IS PER-MACHINE, NOT PER-LEVEL — and reading only the level flag was
	// a REAL v13.3 REGRESSION, caught by the map-wide audit (2026-08-28).
	// SOLO QUICK REVIVE IS SELF-POWERED FROM SPAWN: stock's QR machine runs on
	// the perk_machine_power_override lane (_zm_perks.gsc:92-95, "//Quick Revive
	// uses this"), and in solo it SKIPS the power wait entirely
	// (_zm_perk_quick_revive.gsc:165-168 `else if ( !solo_mode )`), SetModels its
	// ON model at :180 at +3.0s, marks its triggers powered at :202, then parks
	// forever at :215. Our blackscreen sweep lands ~3.6s LATER (+6.6s), read the
	// level flag — still false, because the switch at the base is unbought — and
	// stamped the DARK mesh back over the lit one. Nothing ever re-lights it:
	// the QR module never SetModels again, coherence_watch deliberately skips
	// specialty_quickrevive, and the solo hot-join updater is a no-op in solo.
	// Result before this fix: in EVERY solo run the one machine usable from
	// round 1 wore its unpowered mesh for the whole game while glowing, humming
	// and selling. Pre-v13.3 this was invisible because stock's QR off_model and
	// on_model are THE SAME STRING ("p7_zm_vending_revive",
	// _zm_perk_quick_revive.gsh:6-7) — the migration is what gave the two states
	// distinct meshes and turned a no-op into a visible bug.
	// So: OR the level flag with the machine's OWN trigger power state, which
	// stock stamps via zm_perks::set_power_on.
	lvl_powered = ( level flag::exists( "power_on" ) && level flag::get( "power_on" ) );

	n = 0;
	triggers = GetEntArray( "zombie_vending", "targetname" );
	foreach ( t in triggers )
	{
		if ( !isdefined( t.machine ) || !isdefined( t.script_noteworthy ) )
			continue;
		spec = t.script_noteworthy;
		if ( !isdefined( offs[ spec ] ) )
			continue;   // not one of ours — never touch another map system's machine
		if ( !isdefined( level.machine_assets ) || !isdefined( level.machine_assets[ spec ] ) )
			continue;
		powered = ( lvl_powered || IS_TRUE( t.power_on ) );
		// NO SOLO QUICK REVIVE CARVE-OUT HERE (v18.15). v18.14 added a
		// level.tod_qr_gated_dark latch so the machine would read dark while that
		// version held it unbuyable; the gate is gone, so the latch is gone with
		// it. Solo QR is powered and selling from round 1, and .power_on is true,
		// so this line lights it — which is correct: a machine you can use should
		// not look switched off. Retire a thing WHOLE, or the next reader inherits
		// a dead field that still looks load-bearing.
		want = ( powered ? level.machine_assets[ spec ].on_model : level.machine_assets[ spec ].off_model );
		if ( !isdefined( want ) )
			continue;
		if ( isdefined( t.machine.model ) && t.machine.model == want )
			continue;   // already correct — do not churn the model
		t.machine SetModel( want );
		n++;
	}
	return n;
}

function glow_all_machines()
{
	if ( isdefined( level.tod_perk_glow_done ) && level.tod_perk_glow_done )
		return;
	level.tod_perk_glow_done = true;

	level.tod_glow_ents = [];

	// Every perk machine carries the stock "zombie_vending" trigger whose
	// .machine is the renderable script_model (VERIFIED map 1:
	// perk_machine_spawn_init blesses trigger.machine).
	triggers = GetEntArray( "zombie_vending", "targetname" );
	foreach ( t in triggers )
	{
		if ( !isdefined( t.machine ) )
			continue;
		// (v14.16: the Deadshot yaw handback that lived here died with
		// Deadshot — no machine carries a pre-power yaw offset any more.)
		idx = perk_color_index( t.script_noteworthy );
		t.machine clientfield::set( "todPerkGlow", idx );
		t.machine.tod_glow_idx = idx;
		level.tod_glow_ents[ level.tod_glow_ents.size ] = t.machine;
	}

	// Pack-a-Punch: the "pack_a_punch" noteworthy ent is the USE TRIGGER (not a
	// renderable scriptmover), so glow an invisible tag_origin host at its spot.
	pap = GetEntArray( "pack_a_punch", "script_noteworthy" );
	if ( pap.size > 0 && isdefined( pap[ 0 ] ) )
	{
		host = spawn( "script_model", pap[ 0 ].origin + ( 0, 0, -50 ) );
		host setmodel( "tag_origin" );
		level.tod_pap_glow_host = host;   // keep a ref so it is not GC'd
		host clientfield::set( "todPerkGlow", 10 );
		host.tod_glow_idx = 10;
		level.tod_glow_ents[ level.tod_glow_ents.size ] = host;
	}
}

// Edge-triggered per-ent re-pulse: the first time any player closes within
// TOD_GLOW_REKICK_DIST of a glow ent (after power), blink its field 0 -> idx so
// the client replays the FX where the player can actually see it.
function glow_rekick_watch()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait 1;
		if ( !isdefined( level.tod_glow_ents ) )
			continue;

		foreach ( e in level.tod_glow_ents )
		{
			if ( !isdefined( e ) || IS_TRUE( e.tod_glow_rekicked ) )
				continue;

			foreach ( p in GetPlayers() )
			{
				if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
					continue;
				if ( Distance( p.origin, e.origin ) > TOD_GLOW_REKICK_DIST )
					continue;

				e.tod_glow_rekicked = true;
				e clientfield::set( "todPerkGlow", 0 );
				e thread reglow( e.tod_glow_idx );
				break;
			}
		}
	}
}

function reglow( idx )   // self = the machine model / glow host
{
	level endon( "end_game" );
	wait 0.25;   // > one snapshot, so the 0 actually transmits before the re-set
	if ( isdefined( self ) )
		self clientfield::set( "todPerkGlow", idx );
}

// specialty string -> colour index (the .csc maps each index to an FX).
// VERIFIED keys (map 1): Double Tap = specialty_doubletap2, Stamin-Up =
// specialty_staminup. Unknown -> 10 (teal).
function perk_color_index( specialty )
{
	if ( !isdefined( specialty ) )
		return 10;
	switch ( specialty )
	{
		case "specialty_armorvest":               return 1;   // Jugg         - red
		case "specialty_fastreload":              return 2;   // Speed Cola   - green
		case "specialty_doubletap2":              return 3;   // Double Tap   - yellow
		case "specialty_staminup":                return 4;   // Stamin-Up    - orange
		// Mule Kick RETIRED 2026-08-25 (replaced by PhD Flopper on the crown).
		// Kept as a live case, not deleted: the perk is still REGISTERED by stock, so
		// a stray machine or a debug grant would otherwise fall through to no colour.
		case "specialty_additionalprimaryweapon": return 5;   // (retired)   - amber
		case "specialty_quickrevive":             return 6;   // Quick Revive - blue
		// Deadshot RETIRED v14.16 (replaced by Wisp Tea in the same slot).
		// Its blacklight index passes straight to the successor — index 7 was
		// Deadshot's identity colour and nothing else claims it.
		case "specialty_nomotionsensor":          return 7;   // Wisp Tea     - blacklight (v14.16; was Deadshot)
		case "specialty_widowswine":              return 8;   // Widow's Wine - white
		case "specialty_electriccherry":          return 9;   // PhD Flopper  - purple
		// Electric Cherry MOVED 9 -> 5 (audit 2026-08-28, found by two teams).
		// It collided with PhD on purple, and on a 50-floor tower where all
		// nine machines scatter to random pads and reshuffle every 4 rounds,
		// the aura colour IS the long-range identity read — two machines
		// glowing the same colour costs a player the walk to find out which is
		// which. Index 5 was sitting free because Mule Kick retired (the case
		// above stays live for a stray machine, and now falls through to a
		// colour nothing else claims only if that machine ever appears).
		case "specialty_combat_efficiency":       return 5;   // Death Perception (v13.19; was Elemental Pop, was Electric Cherry) - amber suits the red/amber cabinet
		default:                                  return 10;  // generic / PaP - teal
	}
}

// Public: drive the coloured-glow FX on ANY scriptmover ent (future systems).
function set_glow( ent, color_index )
{
	if ( !isdefined( ent ) )
		return;
	ent clientfield::set( "todPerkGlow", color_index );
}
