// =============================================================================
// _tod_doors.gsc — buyable stairwell doors.
//
// THE MAP 1 LESSON (do not re-learn): a generator-written zombie_door
// trigger_use is DEAD — the zone system re-disables it and a map brush entity
// has no usable .origin (reports 0,0,0). So: disable the map trigger, spawn a
// trigger_radius_use on BOTH sides of the doorway (the slab occludes a single
// center trigger from the approach side), and drive the buy in script: charge
// points, set the zone script_flag, hide+notsolid+connectpaths the slab.
// Script-spawned use triggers REQUIRE TriggerIgnoreTeam() or no prompt shows.
// Slab starts Solid()+DisconnectPaths() (navmesh ignores entity collision).
//
// Doorway coordinates come from the GENERATED _tod_door_data.gsc (emitted by
// tools/gen_tower_map.js from the same tables that cut the .map — no drift).
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\zm\_zm;          // get_zombie_count_for_round (door price scaling)
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\zm_tower_of_doom\_tod_door_data;
#using scripts\zm\zm_tower_of_doom\_tod_luck;   // door buys pay luck (v5)

#insert scripts\shared\shared.gsh;

#namespace tod_doors;

function init()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	wait 1;   // let stock door_init finish (it flag::init's the script_flags we set on purchase)

	doors = GetEntArray( "zombie_door", "targetname" );
	for ( i = 0; i < doors.size; i++ )
	{
		if ( isdefined( doors[ i ] ) )
			level thread door_buy_setup( doors[ i ] );
	}

	// Set LAST: the dev harness (_tod_main::dev_crown_test) waits on this before
	// calling dev_open_all_doors, so it cannot race the setup above and find
	// slabs that have not been made Solid()/DisconnectPaths() yet — it would
	// then "open" a door that promptly closes itself.
	level.tod_doors_ready = true;
}

function door_buy_setup( d )
{
	level endon( "end_game" );

	cost = 1000;
	if ( isdefined( d.zombie_cost ) )
		cost = int( d.zombie_cost );

	slab = undefined;
	if ( isdefined( d.target ) )
		slab = GetEnt( d.target, "targetname" );

	flag = "";
	if ( isdefined( d.script_flag ) )
		flag = d.script_flag;

	info = tod_door_data::get_door_info( flag );
	if ( !isdefined( info ) )
		return;   // unknown door — leave it alone rather than break it

	// v9.41: the PRICE rides in the generated data file too (the same generator
	// table writes the .map's zombie_cost) and WINS over the map entity — the
	// entity value is frozen into the BSP at cod2map time, so without this a
	// price change needed a full geometry build. Map value = fallback only.
	if ( isdefined( info.cost ) )
		cost = int( info.cost );

	if ( isdefined( slab ) )   // barrier solid + nav cut until bought
	{
		slab Solid();
		slab DisconnectPaths();
	}

	d TriggerEnable( false );   // the dead map trigger; our spawned ones drive the buy
	d.tod_bought = false;
	d.tod_trigs = [];
	// v13.9: kept on the ent + a flag-keyed registry so force_open_by_flag can
	// run the open path without the buy closure's locals.
	d.tod_slab = slab;
	d.tod_flag = flag;
	if ( flag != "" )
	{
		if ( !isdefined( level.tod_doors_by_flag ) )
			level.tod_doors_by_flag = [];
		level.tod_doors_by_flag[ flag ] = d;
	}

	spawn_buy_trigger( d, info.org + info.off, cost, slab, flag, info.dest );
	spawn_buy_trigger( d, info.org - info.off, cost, slab, flag, info.dest );
}

// ---------------------------------------------------------------------------
// DOOR PRICE SCALING (user 2026-08-23: "Door cost should scale with amount of
// zombies spawning", answering the co-op audit finding that a quad team splits
// a 186,975-point door ladder four ways while earning roughly four times the
// points — so bigger teams climbed far higher per round than solo).
//
// THE MULTIPLIER IS THE ZOMBIE RATIO, exactly as asked: how many zombies a
// round spawns at the current player count divided by how many it would spawn
// solo. Stock adds zombie_ai_per_player (6) per extra player, so this lands
// near 1.0 / 1.5 / 2.0 / 2.5 and MOVES WITH stock's own curve rather than a
// table we would have to keep in sync.
//
// EVALUATED AT A FIXED REFERENCE ROUND, not the live one. The ratio drifts with
// the round number, and a price that climbed every round would fight the
// generator's +100/lap ladder and make late doors unbuyable — the ask was to
// scale with PARTY SIZE (which is what changes the zombie count), not to make
// doors inflate over time.
//
// Solo is untouched by construction (ratio 1.0), which matters: the door ladder
// was tuned solo and the user has been testing it solo.
// REF ROUND IS THE TUNING KNOB, and it matters more than it looks — stock's
// curve steepens with the round, so the same formula gives very different
// multipliers depending where you sample it (quad: x1.56 at r5, x2.36 at r10,
// x4.00 at r20, x4.86 at r30).
//
// Round 10 gives  solo x1.00 / duo x1.27 / trio x1.82 / quad x2.36
//   -> the 186,975-point ladder becomes ~441k for a quad, about 110k a head
//      against solo's 187k. So a big team still has it easier per player on
//      PROGRESSION (which is right — they are fighting a tougher horde), but
//      nothing like the 4x free ride the audit found.
// Sampling at r20 would make quad per-capita exactly equal to solo. That is
// "fairer" on paper and probably too harsh in play, since co-op ALSO now eats
// scaled zombie health and a higher AI cap. Move this if the beta says so.
#define TOD_DOOR_SCALE_REF_ROUND  10

function door_cost_mult()
{
	players = GetPlayers();
	n = players.size;
	if ( n < 2 )
		return 1.0;                     // solo: exactly the authored price

	solo = zm::get_zombie_count_for_round( TOD_DOOR_SCALE_REF_ROUND, 1 );
	many = zm::get_zombie_count_for_round( TOD_DOOR_SCALE_REF_ROUND, n );
	if ( !isdefined( solo ) || solo < 1 || !isdefined( many ) || many < 1 )
		return 1.0;                     // stock said something odd — never invent a price

	m = many / ( solo * 1.0 );
	if ( m < 1.0 )
		m = 1.0;                        // a door may never get CHEAPER in co-op
	return m;
}

// The price a door asks RIGHT NOW. Kept as a function rather than a number
// baked at spawn because players connect and drop mid-game, so the CHARGE has
// to be re-read at the moment of purchase (buy_trigger_wait, below).
//
// THE HINT READS THIS ONCE, AT SPAWN. Hint and charge can therefore disagree
// after a party-size change; that is deliberate and the reasoning is in the
// block above buy_trigger_wait. Do NOT add a per-door hint re-stamp to close
// the gap — one used to live here and it is what overflowed the engine's
// 250-entry triggerstring cache in co-op.
function door_price( base_cost )
{
	c = int( base_cost * door_cost_mult() );
	if ( c < 1 )
		c = 1;
	return c;
}

function spawn_buy_trigger( d, pos, cost, slab, flag, dest )
{
	t = spawn( "trigger_radius_use", pos, 0, 96, 100 );
	t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger
	t SetCursorHint( "HINT_NOICON" );
	// "Open Door to <dest>" EXACTLY — PromptDoors.lua parses the destination out
	// of this hint and puts it in the card TITLE.
	//
	// THAT WAS ONLY TRUE FROM 2026-08-25. This comment previously claimed the
	// card showed "Unlocks: <dest>" and it never did — PromptDoors.lua drew a
	// hardcoded "Locked Area" for all 53 doors, so the Floor 1 door and the
	// Power Room door were byte-identical prompts and the destination the
	// generator carefully authors per door was thrown away. The parse now
	// exists; keep this format EXACT or it silently falls back to the title.
	t SetHintString( "Hold ^3[{+activate}]^7 Open Door to " + dest + " ^2[Cost: " + door_price( cost ) + "]" );

	d.tod_trigs[ d.tod_trigs.size ] = t;

	t thread buy_trigger_wait( d, cost, slab, flag );
}

// THE PRICE WATCHER IS GONE (2026-08-30, the 250-triggerstring crash).
//
// THE RULE: SetHintString mints ONE PERMANENT entry in the engine's
// 'triggerstring' BG-cache per DISTINCT string. That cache caps at 250 for the
// WHOLE MATCH and a slot is never freed — not on Delete(), not between rounds.
// Overflow fatals with BG_Cache_GetIndexInternal and BLAMES WHOEVER REGISTERS
// NEXT, so the site named in a crash report is never the accumulator.
//
// WHAT WAS HERE: door_price_watch(), a 2s poll per trigger that re-stamped a
// door's hint whenever door_cost_mult() moved (a join, a drop, a migration),
// gated on a player being within 512u. It was written to BOUND the cost of
// re-stamping and it did — but it could not bound it to zero. `shown` only
// advanced when the re-stamp actually FIRED, so after one party-size change
// every door the party had not yet walked up to still held its load-time price
// and minted a SECOND string on approach. Shipped players hit the cap in
// 4-player games: one party-size change cost ~46 slots, two crossed 250 in the
// upper spiral. The ceiling for this lane alone was 53 x 4 = 212.
//
// WHY DELETING IT IS THE WHOLE FIX, AND WHY THE PRICE STAYS ON SCREEN:
// init() threads door_buy_setup for all 53 doors in one waitless loop, and
// door_buy_setup runs straight through to spawn_buy_trigger — so every hint is
// minted in a SINGLE FRAME off ONE GetPlayers() snapshot. The 53 destinations
// are distinct, so the door-hint set is a fixed 53 whether or not the price is
// in the string. With no watcher that set cannot grow, and stripping the price
// out of the hint would therefore save exactly ZERO slots while making every
// door in the map a blind purchase. It costs nothing to show it, so it is shown.
//
// THE RESIDUAL, ACCEPTED DELIBERATELY: without the watcher a hint can go stale
// if the party size changes mid-match — the sign shows the load-time price
// while buy_trigger_wait charges the live one. A shrinking party is charged
// LESS than shown, a growing party MORE. That is the trade for a hard slot
// bound. If it ever needs closing, close it with IPrintLnBold (chat prints do
// NOT feed this cache) or a clientfield -> LUI lookup. NEVER with another
// SetHintString, and NEVER with a per-door re-stamp — that is this exact bug.

function buy_trigger_wait( d, cost, slab, flag )
{
	level endon( "end_game" );
	for ( ;; )
	{
		self waittill( "trigger", player );

		if ( !isdefined( player ) || !IsPlayer( player ) )
			continue;

		// A REVIVE PRESS IS NOT A PURCHASE — stock door parity
		// (_zm_blockers.gsc:307, and every other stock buy path: _zm_perks.gsc
		// :407, _zm_magicbox.gsc:570, _zm_traps.gsc:318, _zm_unitrigger.gsc:908,
		// whose comment is literally "revive triggers override trap triggers").
		//
		// THIS DOOR LOOP HAD NO PLAYER-STATE GATE AT ALL — no laststand, no
		// is_player_valid, no revive check (audit 2026-08-26; logged once before
		// as ECO-05 in docs/24_full_map_review.md). Two things follow, and BOTH
		// are live in co-op:
		//
		//   1. REVIVING ALSO BOUGHT THE DOOR. Reviving is NOT arbitrated by the
		//      engine's use-prompt selection — stock polls the raw button every
		//      server frame (_zm_laststand.gsc:1129 is_reviving() =
		//      UseButtonPressed() && can_revive()). So holding USE over a downed
		//      teammate satisfied both: the revive proceeded AND this trigger
		//      charged the price. Doorways are the most common down-spot in a
		//      stairwell map, and the two volumes (door 96 radius, revive 75)
		//      overlap constantly.
		//   2. THE CRAWLER HIMSELF COULD BUY IT, with no arbitration needed at
		//      all: a downed player's own revive trigger is
		//      SetInvisibleToPlayer( self ) (_zm_laststand.gsc:853), so THIS was
		//      his only use-ent, and last stand never disables use input.
		//
		// The cost is not just points: the purchase below sets the zone flag and
		// calls breather_unlock(), which can introduce a NEW ENEMY TYPE for the
		// rest of the run. That is irreversible, off a button press the player
		// meant as a revive.
		//
		// SILENT on purpose (no deny sound), for the same reason the laststand
		// branches of the crate and station loops are silent: the player is
		// HOLDING use, so a sound here would machine-gun in their ear for the
		// whole crawl.
		//
		// SCOPE — this is a 75-unit-radius / 75-tall bubble centred on the downed
		// player (_zm.gsc:1332 sets the dvar unconditionally; this map overrides
		// nothing), NOT the whole 160-wide landing: a body at the landing edge
		// leaves the door buyable. Flights are 192 apart, so a body one flight
		// down cannot reach either trigger. ACCEPTED COST: a body dropped square
		// in a doorway can pin the party until the bleedout — stock accepts
		// exactly this on every stock door; do not "fix" it with a radius
		// override.
		//
		// ARITY TRAP: in_revive_trigger() is arity 0 and a METHOD on the player;
		// is_player_valid() is arity 3 (all optional) and NOT a method — pass the
		// player as arg 1 and NOTHING else (param 2 is checkIgnoreMeFlag, not
		// ignore_laststand). Always qualify zm_utility:: — shared/ai/zombie_utility
		// ships an identically-shaped is_player_valid in another namespace.
		if ( player zm_utility::in_revive_trigger() )
			continue;
		if ( !( zm_utility::is_player_valid( player ) ) )
			continue;   // downed / spectating (_zm_blockers.gsc:318)

		// THE UPGRADE-PAUSE GUARD — the doors were the ONE map-owned trigger
		// family missing it (map-wide trigger audit 2026-08-28, found twice
		// independently). HOLD-USE IS THE CARD-LOCK BUTTON: during an upgrade
		// event the world is frozen and the player holds USE to lock their
		// pick, so a player frozen within reach of an unbought door bought it
		// too — silently, with no prompt read, at the live price (up to 3000,
		// 7500 for the roof, ~2.4x that in a quad). The zone opened at a moment
		// the player never chose, and the points were gone.
		// SILENT on purpose: the class draft and the upgrade pause both hold
		// USE for seconds at a time, so a deny sound here would machine-gun —
		// the same reasoning as the revive-trigger case just above. The player
		// is not being refused a purchase they attempted; they are being
		// prevented from making one they never attempted.
		if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( player.tod_menu_frozen ) )
			continue;

		if ( IS_TRUE( d.tod_bought ) )
			return;
		// LIVE price, re-read on every attempt — `cost` is the AUTHORED base.
		price = door_price( cost );
		if ( !( player zm_score::can_player_purchase( price ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		player zm_score::minus_to_player_score( price );
		player PlaySound( "zmb_cha_ching" );
		d.tod_bought = true;
		tod_luck::door_buy( player );   // LUCK +8 to the buyer (v5 luck bar)

		if ( flag != "" && level flag::exists( flag ) )
		{
			level flag::set( flag );   // activates the zone adjacency
			breather_unlock( flag );   // may introduce a new enemy type
		}

		if ( isdefined( slab ) )
		{
			slab Hide();
			slab NotSolid();
			slab ConnectPaths();
		}

		// retire BOTH triggers (clear the prompt on the now-open door)
		for ( i = 0; i < d.tod_trigs.size; i++ )
		{
			if ( isdefined( d.tod_trigs[ i ] ) )
			{
				d.tod_trigs[ i ] SetHintString( "" );
				d.tod_trigs[ i ] TriggerEnable( false );
			}
		}
		return;
	}
}

// ---------------------------------------------------------------------------
// v13.9 — PUBLIC: open a door by its script_flag WITHOUT a purchase.
//
// Born from a live report (user 2026-08-29): "when i took the teleporter I
// ended up in teleporter room with door closed which is what I expected but
// then I went to 1 health and hear the teddy bear like I was out of bounds".
// That IS the out-of-bounds punisher: a zone only activates when its door's
// flag sets, so a player teleported into the sealed bay stood in an INACTIVE
// zone and stock's playable-area monitor drained them to 1 with the giggle.
// Exempting arrivals from the monitor instead would have minted an
// invulnerable camp room (inactive zone = no spawns, sealed slab = no path),
// so the fix follows the user's own teleporter rule to its conclusion:
// ARRIVING BY TELEPORTER OPENS THE BAY FROM THE INSIDE, free — flag set (zone
// live, monitor satisfied, risers wake), slab open (zombies path in — no
// stranded actors), prompts retired. Mirrors the buy path exactly, minus the
// charge and the luck. Idempotent; returns true if the door is open after.
function force_open_by_flag( flag )
{
	if ( !isdefined( level.tod_doors_by_flag ) || !isdefined( level.tod_doors_by_flag[ flag ] ) )
		return false;
	d = level.tod_doors_by_flag[ flag ];
	if ( IS_TRUE( d.tod_bought ) )
		return true;
	d.tod_bought = true;

	if ( isdefined( d.tod_flag ) && d.tod_flag != "" && level flag::exists( d.tod_flag ) )
	{
		level flag::set( d.tod_flag );
		breather_unlock( d.tod_flag );   // harmless for enter_tpbay (no enemy row)
	}
	if ( isdefined( d.tod_slab ) )
	{
		d.tod_slab Hide();
		d.tod_slab NotSolid();
		d.tod_slab ConnectPaths();
	}
	for ( i = 0; i < d.tod_trigs.size; i++ )
	{
		if ( isdefined( d.tod_trigs[ i ] ) )
		{
			d.tod_trigs[ i ] SetHintString( "" );
			d.tod_trigs[ i ] TriggerEnable( false );
		}
	}
	return true;
}

// ---------------------------------------------------------------------------
// ENEMY UNLOCKS — the tower gets harder the higher you climb
// ---------------------------------------------------------------------------
// User 2026-08-21: "Every time you open a door to a breather (the gold section
// on the tower bar) we introduce a new type of enemy. First will be the
// protector — they won't spawn until that door is opened. They start coming on
// the round it's opened, then every 3 rounds in waves."
//
// The gate is the ROUND STAMP, not just a bool: _tod_bosses::protector_due
// anchors its every-3-rounds cadence to the round the door was bought, so the
// wave lands on that round and then every third one after — never on the old
// global round-3 grid.
//
// Breather laps are 10/20/30/40 (gen_tower_map.js BREATHER_LAPS). Slots 2-4
// are reserved for future enemy types; only the protector is wired today, so
// opening those doors currently unlocks nothing (no dead references).
function breather_unlock( flag )
{
	if ( !isdefined( level.tod_enemy_unlock_round ) )
		level.tod_enemy_unlock_round = [];

	kind = undefined;
	switch ( flag )
	{
		case "enter_lap10": kind = "protector"; break;
		// THE REAVER (docs/28, 2026-08-22): an Apothicon Fury run as a tower
		// elite. Cadence anchors here — _tod_reaver::reaver_due reads this
		// stamp and owes a spawn on THIS round and every 4th after.
		case "enter_lap20": kind = "reaver"; break;
		// THE ARMORED SPRINTER (v13.7, user 2026-08-29 ladder): smoke-trailing
		// chain-armor converts promoted out of the horde — _tod_sprinter reads
		// this stamp, every 3rd round after. Took the lap-30 slot from the
		// hounds when the user re-dealt the ladder ("add an enemy rather than
		// replace").
		case "enter_lap30": kind = "sprinter"; break;
		// HELLHOUNDS: the stock zm_factory dog archetype run as a tower elite.
		// Cadence anchors HERE — _tod_hellhounds::hound_due reads this stamp and
		// owes a PACK on THIS round and every 3rd after. This is NOT a dog
		// round: level.dog_rounds_allowed stays 0 and enable_dog_rounds is never
		// called anywhere in the map. MOVED lap30 -> lap40 in the same re-deal —
		// the fourth slot, reserved-empty since the ladder was built, is now
		// filled and the ladder is complete: 10 protector / 20 reaver /
		// 30 sprinter / 40 hellhound.
		case "enter_lap40": kind = "hellhound"; break;
	}
	if ( !isdefined( kind ) )
		return;
	if ( isdefined( level.tod_enemy_unlock_round[ kind ] ) )
		return;   // already unlocked — never re-stamp (would shift the cadence)

	r = 1;
	if ( isdefined( level.round_number ) )
		r = level.round_number;
	level.tod_enemy_unlock_round[ kind ] = r;
	level notify( "tod_enemy_unlocked", kind );
}

// ===========================================================================
// DEV ONLY — open every door as if it had been bought.
// Called from _tod_main::dev_crown_test (gated on level.tod_dev). Ship builds
// never reach it.
//
// WHY THIS EXISTS RATHER THAN JUST SETTING THE FLAGS. The dev harness first
// tried `level flag::set( "enter_lapN" )` for all 53 and called that "the same
// as buying every door". It is not. A real purchase (see the buy loop above)
// does FOUR things, and the flag is only the first:
//     level flag::set( flag )      - activates the zone adjacency
//     breather_unlock( flag )      - arms Protector (lap10) / Reaver (lap20) /
//                                    the hellhound unlock. WITHOUT IT THOSE
//                                    ENEMY TYPES STAY DORMANT ALL SESSION.
//     slab Hide/NotSolid/ConnectPaths - the barrier and its NAV CUT. Flags
//                                    alone leave 53 solid slabs standing and
//                                    the navmesh severed, so the horde cannot
//                                    path the tower even though the zones are
//                                    "open".
//     the two buy triggers retire  - or every opened doorway still prompts.
// Doing only the first is why a dev session looked open but played sealed.
// ===========================================================================
function dev_open_all_doors()
{
    doors = GetEntArray( "zombie_door", "targetname" );
    for ( i = 0; i < doors.size; i++ )
    {
        d = doors[ i ];
        if ( !isdefined( d ) )
            continue;

        if ( isdefined( d.script_flag ) && d.script_flag != "" && level flag::exists( d.script_flag ) )
        {
            level flag::set( d.script_flag );
            breather_unlock( d.script_flag );
        }

        if ( isdefined( d.target ) )
        {
            slab = GetEnt( d.target, "targetname" );
            if ( isdefined( slab ) )
            {
                slab Hide();
                slab NotSolid();
                slab ConnectPaths();
            }
        }

        d.tod_bought = true;
        if ( isdefined( d.tod_trigs ) )
        {
            for ( t = 0; t < d.tod_trigs.size; t++ )
            {
                if ( isdefined( d.tod_trigs[ t ] ) )
                {
                    d.tod_trigs[ t ] SetHintString( "" );
                    d.tod_trigs[ t ] TriggerEnable( false );
                }
            }
        }
    }
}
