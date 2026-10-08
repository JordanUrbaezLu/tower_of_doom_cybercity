// =============================================================================
// _tod_gauge.gsc — the TOWER GAUGE feed (the HUD floor indicator).
//
// Publishes TWO events to each player's HUD, both int-only and both
// change-gated:
//   tod_floor (2 args)  the cell THEY are on, and the cell the HIGHEST live
//                       PANZER is on (0 = none; v19.46 — Panzers only, never
//                       the Protector / Reaver, which also carry .is_boss)
//   tod_down  (2 args)  a BITMASK of the cells that have a DOWNED TEAMMATE on
//                       them, split into a low and a high half (0,0 = nobody)
// The Lua (tod_upgrade.lua) draws the gauge from those — dark backing, one lit
// cell stamped per climbed floor, a red pip beside the Panzer's cell, and any
// number of cells swapped to the red DOWN tile.
//
// WHY LuiNotifyEvent AND NOT A CLIENTFIELD: the clientuimodel budget is at
// its PROVEN 61-bit ceiling (18 fields, APPEND ONLY — see _tod_upgrade_ui).
// A floor + boss-floor pair would cost ~10 more bits, and the down mask 25
// more on top. The int-only LuiNotifyEvent lane costs ZERO clientuimodel bits,
// which is exactly why the boss banner and the owned-upgrades sync already
// ride it.
//
// WHY THE DOWN MASK IS SPLIT ACROSS TWO ARGS AND SENT ON ITS OWN EVENT, and
// not appended as a third arg to tod_floor (v14.50 — both halves of this are
// a deliberate refusal to be the first caller of something unproven):
//   (a) 25 cells is 25 BITS, up to 33,554,431 as one number, and this lane's
//       values land in the LUI model system, which the client Lua reads back
//       through tonumber()/math.floor — i.e. as a Lua number, with no promise
//       anywhere that the value survived as an exact 32-bit int. A float32
//       carries integers exactly only to 16,777,216: above that the spacing is
//       2, so "cell 25 AND cell 1 are down" (16,777,217) would quietly lose
//       cell 1. Nothing in this tree or in stock pushes a value that big
//       through here, so it is unproven, and the failure mode is a marker that
//       silently does not draw — the exact bug this feature exists to fix.
//       Split 13 + 12, every value is <= 8191 and the question never arises.
//   (b) ARITY. This tree's proven shapes are 2 and 3 args; stock MP ships 4, 5
//       and 7 (_hud_message.gsc:325/443), so a 4-arg call is very likely fine
//       — but "very likely fine" is how a silent no-fire gets shipped, and a
//       second 2-arg event costs one #precache and buys certainty. It also
//       decouples the feeds: a party climbing pushes floor events all match
//       without ever touching the down lane, and vice versa.
//
// TRAP (paid for twice on this map): the event string MUST be #precache'd or
// LuiNotifyEvent silently never fires.
//
// Floors: the tower is TOD_GAUGE_LAPS (50) laps of LAP_RISE 384 starting at
// z=0, roof at 19200. The BAR has only 25 cells, so floor_of() folds two
// floors into one cell (v8 — "you need to open double the doors to see
// progress on the tower bar"):
//   z < 0            -> 0  (base arena; gauge shows no lit cells)
//   0 <= z < 19200   -> cell 1..25   (real floor 1..50)
//   z >= 19200       -> 26 (roof — the crown lights)
// (This block said "25 laps ... roof at 9600" until 2026-08-30; it was never
// updated through the v8 doubling. The DEFINES are the source of truth.)
//
// IT ALSO OWNS THE FLOOR HIGH-WATER. Since v14.35 this module's poll records
// the highest REAL floor each player has stood on (real_floor_of /
// floor_reached), because the CLASS TIER promotion is gated on it: tier 2
// needs floor 10, tier 3 needs floor 30 (20 until 2026-09-02). That is a gameplay rule reading a
// HUD module's number, which is the right way round — the gate is written
// against the floor the player can literally see on their own gauge.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\zm\zm_tower_of_doom\_tod_classes;   // [tod v17.33] pap_tier — the HUD badge feed

#insert scripts\shared\shared.gsh;

// v8 (user 2026-08-21): the tower DOUBLED to 50 floors but the gauge art still
// has 25 cells, so ONE CELL = TWO FLOORS — "you need to open double the doors
// to see progress on the tower bar". floor_of() reports the CELL, not the
// floor: cell = ceil(floor / 2).
#define TOD_GAUGE_LAP_RISE   384
#define TOD_GAUGE_LAPS       50    // real floors
#define TOD_GAUGE_CELLS      25    // cells on the bar art
#define TOD_GAUGE_ROOF_ID    26    // = CELLS + 1 (tower; the spire's top id is SPIRE_CELLS + 1)
// THE ENDLESS SPIRE (docs/71, 2026-09-02): after ascension the bar becomes a
// SECOND instrument — the spire's floors on half-size cells, still two floors
// per cell, a hub plate every 5th. Before this the module mapped spire z onto
// the tower grid, so the bar sat FULL WITH THE CROWN LIT from spire floor 51
// up. gauge_mode() is the one switch; every clamp below reads cells_for_mode().
// v17.69 (docs/105): the spire is 70 laps -> 35 cells (was 100 / 50). LOCKSTEP
// with SP_CELLS/SP_PITCH in tod_upgrade.lua and the --spire profile in
// tools/slice_gauge.js; the down mask splits 13/13/9 over tod_down + tod_down2.
#define TOD_GAUGE_SPIRE_LAPS  70
#define TOD_GAUGE_SPIRE_CELLS 35
#define TOD_GAUGE_TICK       0.35   // push cadence; only sends on CHANGE
// real_floor_of ONLY. A player standing on a landing has their feet AT the
// landing's z, and that z is the exact boundary between two floors — one
// ground-trace hair under it reads as the floor below, which would make
// "reached floor 10" flicker for someone standing on floor 10. 8 units is a
// little over half a stair riser: it cannot promote anyone who has not
// actually arrived, and it cannot demote anyone who has.
#define TOD_GAUGE_FLOOR_EPS  8
// The DOWN mask's split point: cells 1..13 ride the low arg (bits 0..12) and
// cells 14..25 the high one (bits 0..11), so neither number can exceed 8191.
// LOCKSTEP with GA_SPLIT in tod_upgrade.lua — the Lua reassembles by the same
// boundary, and there is no way for the two to disagree loudly.
#define TOD_GAUGE_MASK_SPLIT 13

#precache( "eventstring", "tod_floor" );
// v19.46 — THE PANZER PIPS (user 2026-09-23: "if there's two panzers and
// they're on separate floors, maybe we can show two indicators ... it's really
// there for the players to know where the panzers are"). Two ints, each packing
// two cells as hi*64 + lo (every cell <= 52 < 64, every value <= 3391): up to
// FOUR distinct cells, highest first, 0 = no Panzer. Same 2-arg shape as
// tod_down; tod_floor's second arg stays the highest cell for the log and for
// anything else that ever reads it, but the Lua draws the pips from THIS lane.
#precache( "eventstring", "tod_pips" );
#define TOD_GAUGE_PIPS_MAX 4
// v14.50 — the downed-teammate cells. Its own event, deliberately (see the
// header). SAME PRECACHE TRAP as tod_floor: without this line LuiNotifyEvent
// silently never fires and the red cells simply never appear, with no error.
#precache( "eventstring", "tod_down" );
// docs/71 — the spire's 50 cells outgrow two 13-bit args, so cells 27..52
// ride a SECOND 2-arg event (the proven shape) rather than a 4-arg call this
// tree has never fired. Same precache trap.
#precache( "eventstring", "tod_down2" );
// docs/71 — which instrument the HUD draws: 0 tower, 1 spire, 2 spire + the
// summit won (the beacon goes green). One int, change-gated, re-armed per
// life at _tod_upgrade_ui's reopen site like the rest of this module's lanes.
#precache( "eventstring", "tod_gauge_mode" );
// [tod 2026-08-21] real MAX HP for the Aetherium HP text (the kit's health
// field is a 0..1 fraction and its Lua multiplied by a hardcoded 100, so
// the map's 150-HP players read "100 HP"). Same zero-bit int lane, sent
// only when a player's maxhealth changes (spawn, jugg, upgrades).
#precache( "eventstring", "tod_maxhp" );
// [tod v17.25] THE ROUND READOUT. The top-right "ROUND n" is ours now — the
// stock ZmRndContainer was deleted out of AetheriumRoundCounter.lua and the
// number is set in the map's own baked typeface (user 2026-09-04: "Lets remove
// stock and track ourselves"). One int, change-gated, and it rides here rather
// than in a module of its own because this loop is already the map's per-player
// HUD-push heartbeat and already owns the per-life re-arm contract.
//
// WHY NOT A CLIENTFIELD: the clientuimodel pool is at 60 of its PROVEN 61 bits
// (_tod_upgrade_ui.gsc) and a round number wants ten. This lane costs none.
// SAME PRECACHE TRAP as every event above: no line, no fire, no error.
#precache( "eventstring", "tod_round" );
// [tod v17.33] THE PACK-A-PUNCH TIER BADGE on the gun HUD — 0 unpacked, 1
// packed, 2..3 the spire's re-packs. Reports the tier of the weapon CURRENTLY
// IN HAND, so it changes on a weapon switch as well as on a purchase.
//
// WHY IT RIDES HERE and not a clientfield: the clientuimodel pool is at 60 of
// its PROVEN 61 bits (_tod_upgrade_ui.gsc's own count), and a 0..3 value wants
// two. The only dead field, todMagBonus, is one bit — so a clientfield would
// have to take bits out of a shipped feature to buy a badge. This lane costs
// none, and this loop is already the map's per-player HUD-push heartbeat with
// the per-life re-arm contract the badge needs.
//
// SAME PRECACHE TRAP as every event above: no line here, no fire, no error.
#precache( "eventstring", "tod_pap_tier" );
// 2026-10-01 (docs/167 item 12) — THE FLOOR LABEL under the scoreboard's and
// the pause menu's "MAP / ROUND" line (lead tester: "Remove the redundant 'round
// based zombies' text right below the round counter, replacing it with the map
// name or floor"). One int, floor_label_code below; change-gated with a 5 s
// re-send. SAME PRECACHE TRAP as every event above.
#precache( "eventstring", "tod_floor_label" );
// v19.76 — THE WARDEN KING'S BOSS BAR across the top of the screen
// (tod_upgrade.lua; lead tester Nikolai, Oct 2026: "a dedicated Boss HP bar
// across the top of the screen" + "the Luck Bar ... and the Floor Progression
// Counter should both be hidden"). ( state, permille ): 1 = on at that health,
// 0 = off. king_bar_permille below. SAME PRECACHE TRAP as every event above.
#precache( "eventstring", "tod_king_bar" );

#namespace tod_gauge;

function init()
{
	level thread gauge_loop();
}

function gauge_loop()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );

	for ( ;; )
	{
		wait TOD_GAUGE_TICK;

		pips = boss_cells();
		pip_a = pack_pips( pips, 0 );
		pip_b = pack_pips( pips, 2 );
		boss_f = 0;
		if ( pips.size > 0 )
			boss_f = pips[ 0 ];
		mode = gauge_mode();
		// Change-gated: which cells wear a Panzer pip, how many Panzers were
		// live and how many flagged elites were passed over for them.
		if ( !isdefined( level.tod_gauge_pip_logged ) || level.tod_gauge_pip_logged != ( pip_a * 4096 + pip_b ) )
		{
			level.tod_gauge_pip_logged = pip_a * 4096 + pip_b;
			cells_txt = "";
			for ( i = 0; i < pips.size; i++ )
				cells_txt += ( ( i > 0 ) ? "," : "" ) + pips[ i ];
			dev_log( "PIP cells=" + cells_txt + " highest=" + boss_f + " panzers=" + level.tod_gauge_pip_panzers + " elites_ignored=" + level.tod_gauge_pip_elites + " mode=" + mode );
		}

		foreach ( p in GetPlayers() )
		{
			if ( !isdefined( p ) || !isplayer( p ) )
				continue;

			// THE MODE LANE (docs/71) — sent FIRST, so the HUD has swapped
			// instruments before this tick's floor lands. A mode change makes
			// every cached cell number mean something else (cell 12 of 25 vs
			// cell 12 of 50), so the floor and down caches are dropped with it
			// and re-push on this same tick below.
			if ( !isdefined( p.tod_gauge_mode ) || p.tod_gauge_mode != mode )
			{
				p.tod_gauge_mode = mode;
				p LuiNotifyEvent( &"tod_gauge_mode", 1, mode );
				p.tod_gauge_f = undefined;
				p.tod_gauge_bf = undefined;
				p.tod_gauge_pa = undefined;
				p.tod_gauge_pb = undefined;
				p.tod_gauge_dlo = undefined;
				p.tod_gauge_dhi = undefined;
				p.tod_gauge_d2lo = undefined;
				p.tod_gauge_d2hi = undefined;
			}

			// THE CLASS TIER FLOOR GATE's input (v14.35, user 2026-08-30: "you
			// must also reach floor 10 to get 2nd tier class upgrade and floor
			// 20 for 3rd"; T3 moved to floor 30 on 2026-09-02). A per-player HIGH-WATER of the REAL floor, read by
			// _tod_upgrades::tier_floor_ok. Tracked HERE because this is the
			// map's only per-player altitude poll — and ABOVE the change-only
			// `continue` further down, which is about the HUD send and must
			// never decide whether progress was recorded.
			//
			// ALIVE + PLAYING ONLY. A dead player spectates a teammate and
			// their .origin rides that camera, so sampling a spectator would
			// hand a body sitting in the base arena the climber's floor —
			// exactly the free ride the gate exists to close. LAST STAND still
			// samples (sessionstate stays "playing" and isalive is TRUE there —
			// map 1's down-path lesson), which is correct: a downed player
			// really is standing on that floor.
			if ( IsAlive( p ) && ( !isdefined( p.sessionstate ) || p.sessionstate == "playing" ) )
			{
				rf = real_floor_of( p.origin[ 2 ] );
				if ( !isdefined( p.tod_floor_best ) || rf > p.tod_floor_best )
					p.tod_floor_best = rf;

				// THE FLOOR LABEL (2026-10-01, docs/167 item 12) - where this
				// player stands, for the scoreboard / pause header. Same alive +
				// playing rule as the high-water above (a spectator's origin rides
				// someone else's camera; they keep their last label). Change-gated,
				// plus a re-send every 5 s so a HUD built after the first push
				// still learns it (the per-controller cache lives in AetheriumHud).
				flc = floor_label_code( p.origin[ 2 ] );
				if ( !isdefined( p.tod_gauge_flc ) || p.tod_gauge_flc != flc
				  || !isdefined( p.tod_gauge_flc_ms ) || GetTime() >= p.tod_gauge_flc_ms )
				{
					p.tod_gauge_flc = flc;
					p.tod_gauge_flc_ms = GetTime() + 5000;
					p LuiNotifyEvent( &"tod_floor_label", 1, flc );
				}
			}

			// MAX HP feed (change-only; a fresh HUD reads the default until the
			// first push, which lands on this tick's change from undefined)
			if ( isdefined( p.maxhealth ) && p.maxhealth > 0 )
			{
				mh = int( p.maxhealth );
				if ( !isdefined( p.tod_gauge_mh ) || p.tod_gauge_mh != mh )
				{
					p.tod_gauge_mh = mh;
					p LuiNotifyEvent( &"tod_maxhp", 1, mh );
				}
			}

			// THE ROUND READOUT (v17.25). level.round_number is the number the
			// SERVER acts on — the boss cadence, the spawn budget and the
			// zombie-speed ramp all read it — so the HUD shows that and not a
			// stock counter reached through three replaced round functions.
			// Change-gated like every other lane here; re-armed per life by
			// _tod_upgrade_ui::player_lui_life clearing tod_round_shown,
			// because the kit HUD is rebuilt by the engine on every spawn and a
			// change-only feed says nothing to a fresh menu.
			//
			// ABOVE the finale block on purpose: the finale takes over the
			// GAUGE, not the round counter. Rounds keep running on the road,
			// and they keep running on the spire.
			if ( isdefined( level.round_number ) && level.round_number >= 1 )
			{
				rn = int( level.round_number );
				if ( !isdefined( p.tod_round_shown ) || p.tod_round_shown != rn )
				{
					p.tod_round_shown = rn;
					p LuiNotifyEvent( &"tod_round", 1, rn );
				}
			}

			// THE KING'S BOSS BAR (v19.76). HERE and not in _tod_spire so it
			// gets this loop's re-arm for free: a fresh HUD (player_lui_life
			// clears tod_king_bar_shown) and a fresh GAME (a new player entity)
			// both get an explicit state on their first tick. That matters for
			// OFF as much as ON - the HUD menu survives map_restart, and a bar
			// left on by the last game would keep the next game's floor gauge
			// and luck bar hidden with nothing to bring them back. Change-gated,
			// plus a 1 s re-send while the fight is on. Lua's show/hide is itself
			// change-gated, so an OFF push to a HUD that never saw the fight
			// touches nothing.
			kb = king_bar_permille();
			if ( !isdefined( p.tod_king_bar_shown ) || p.tod_king_bar_shown != kb
			  || ( kb >= 0 && ( !isdefined( p.tod_king_bar_ms ) || GetTime() >= p.tod_king_bar_ms ) ) )
			{
				p.tod_king_bar_shown = kb;
				p.tod_king_bar_ms = GetTime() + 1000;
				if ( kb < 0 )
					p LuiNotifyEvent( &"tod_king_bar", 2, 0, 0 );
				else
					p LuiNotifyEvent( &"tod_king_bar", 2, 1, kb );
			}

			// THE PACK-A-PUNCH TIER BADGE (v17.33). Change-gated like every
			// lane here, and re-armed per life by _tod_upgrade_ui's
			// player_lui_life clearing tod_pap_tier_shown.
			//
			// READS THE WEAPON IN HAND, not a stored per-player number: the
			// tier is per-GUN (you can buy PACK III for your primary and leave
			// the sidearm at PACK I), so the badge has to follow the switch.
			// That makes this the one lane here whose value can change without
			// any game state changing at all, which is exactly why it is polled
			// on the heartbeat rather than pushed from the purchase site.
			//
			// ABOVE the finale block, like the round readout: the finale takes
			// over the GAUGE, not the gun HUD, and the badge stays true on the
			// road and on the spire.
			//
			// v2026-09-24: THE SWITCH ITSELF PUSHES TOO (pap_switch_watch). The
			// packed staff NAME rides this event, and on the heartbeat alone it
			// landed up to TOD_GAUGE_TICK after the engine's weapon-name model
			// (lead tester: "it would show old name then change to new name
			// within half second"). The tick stays as the per-life re-arm and the
			// backstop; the send is one function so the two can never disagree.
			if ( !IS_TRUE( p.tod_pap_switch_watch ) )
			{
				p.tod_pap_switch_watch = true;
				p thread pap_switch_watch();
			}
			pap_tier_push( p, undefined );

			// THE FINALE OWNS THE BAR once the clock is running: it stops being
			// an altimeter and becomes the run's timer. The boss pip AND the
			// down cells are forced off with it — everyone is sealed on one
			// road by then, so neither "which floor is the boss on" nor "which
			// floor is your teammate down on" means anything, and both would
			// only muddy a bar that now has exactly one job. (The down cells
			// have a second reason: every cell is also a chunk of the song, so
			// a red one there would read as a timer event, not a person.)
			fc = finale_cell();
			pa = pip_a;
			pb = pip_b;
			if ( fc >= 0 )
			{
				f = fc;
				boss_f = 0;
				pa = 0;
				pb = 0;
				dm = [];
				dm[ 0 ] = 0;
				dm[ 1 ] = 0;
				dm[ 2 ] = 0;
				dm[ 3 ] = 0;
			}
			else
			{
				f = floor_of( p.origin[ 2 ] );
				dm = down_mask_for( p );
			}

			// THE DOWN LANE, change-gated on its own and sent ABOVE the floor
			// lane's `continue` — a teammate going down, crawling to another
			// cell, or being revived must push whether or not this player's own
			// floor moved, and standing still is the normal case for the person
			// who most needs to see it.
			if ( !isdefined( p.tod_gauge_dlo ) || p.tod_gauge_dlo != dm[ 0 ]
			  || !isdefined( p.tod_gauge_dhi ) || p.tod_gauge_dhi != dm[ 1 ] )
			{
				p.tod_gauge_dlo = dm[ 0 ];
				p.tod_gauge_dhi = dm[ 1 ];
				p LuiNotifyEvent( &"tod_down", 2, dm[ 0 ], dm[ 1 ] );
			}
			// cells 27..52 (spire only in practice — on the tower both halves
			// are always 0 and this fires exactly once per life)
			if ( !isdefined( p.tod_gauge_d2lo ) || p.tod_gauge_d2lo != dm[ 2 ]
			  || !isdefined( p.tod_gauge_d2hi ) || p.tod_gauge_d2hi != dm[ 3 ] )
			{
				p.tod_gauge_d2lo = dm[ 2 ];
				p.tod_gauge_d2hi = dm[ 3 ];
				p LuiNotifyEvent( &"tod_down2", 2, dm[ 2 ], dm[ 3 ] );
			}

			// THE PANZER PIPS (v19.46), change-gated on their own like the down
			// lane: a Panzer climbing a cell, dying, or a second one landing on
			// another floor must push whether or not this player's floor moved.
			if ( !isdefined( p.tod_gauge_pa ) || p.tod_gauge_pa != pa
			  || !isdefined( p.tod_gauge_pb ) || p.tod_gauge_pb != pb )
			{
				p.tod_gauge_pa = pa;
				p.tod_gauge_pb = pb;
				p LuiNotifyEvent( &"tod_pips", 2, pa, pb );
			}

			// Send only on change — this loop runs forever, and a per-tick
			// event for every player would be pure config-string churn.
			if ( isdefined( p.tod_gauge_f ) && p.tod_gauge_f == f
			  && isdefined( p.tod_gauge_bf ) && p.tod_gauge_bf == boss_f )
				continue;

			p.tod_gauge_f = f;
			p.tod_gauge_bf = boss_f;
			p LuiNotifyEvent( &"tod_floor", 2, f, boss_f );
		}
	}
}

// THE PACK-A-PUNCH TIER + HELD-STAFF EVENT, one sender for both callers (the
// heartbeat above and pap_switch_watch below). Change-gated on the pair, so a
// switch push followed by the next tick sends once. `w` = the weapon a
// weapon_change notify named, or undefined to read the hand.
function pap_tier_push( p, w )
{
	pt = 0;
	staff_id = 0;
	if ( IsAlive( p ) )
	{
		cw = w;
		if ( !isdefined( cw ) )
			cw = p GetCurrentWeapon();
		if ( isdefined( cw ) && cw != level.weaponNone )
		{
			pt = tod_classes::pap_tier( p, cw );
			staff_id = tod_classes::pap_staff_id( cw );
		}
	}
	// A staff switch must update the name even when both have the same tier.
	if ( !isdefined( p.tod_pap_tier_shown ) || p.tod_pap_tier_shown != pt || !isdefined( p.tod_pap_staff_shown ) || p.tod_pap_staff_shown != staff_id )
	{
		p.tod_pap_tier_shown = pt;
		p.tod_pap_staff_shown = staff_id;
		p LuiNotifyEvent( &"tod_pap_tier", 2, pt, staff_id );
	}
}

// self = player. One per player for the match (the heartbeat's latch starts
// it); survives respawns because it waits on the player, never on a life.
function pap_switch_watch()
{
	self endon( "disconnect" );
	level endon( "end_game" );
	for ( ;; )
	{
		self waittill( "weapon_change", w );
		pap_tier_push( self, w );
	}
}

// THE GAUGE BECOMES THE SONG CLOCK DURING EXTRACTION (user 2026-08-25: "once
// the extraction starts we can reset the tower bar on the right and that will be
// the song timer so players know when the map ends").
//
// WHY THIS BAR AND NOT A NEW ONE: it is already the right shape (25 cells that
// fill), it is already on screen, and it rides LuiNotifyEvent — which costs ZERO
// clientuimodel bits, and the pool is at 58 of its proven 61. A dedicated timer
// widget would have cost bits the map does not have.
//
// IT ALSO RESETS ITSELF FOR FREE. You buy Extraction standing at the crown, so
// the bar is full and the crown light is on; the first finale tick reports cell
// 0 and the whole thing empties. That drop IS the "reset" — no extra signal.
//
// FILLS rather than drains, keeping the bar's one meaning: full = you are done.
// Climbing it filled toward the crown; now it fills toward the last chord.
//
// -> 0..CELLS while the finale clock runs, or -1 when it is not running (in
// which case the caller falls back to altitude).
// v19.76 THE BOSS BAR's input: -1 when there is no King fight (the bar hides),
// else his health as 0..1000 (an int: the event lane carries ints only). The
// fight window is level.tod_king_hp_frac being defined - set at his landing,
// cleared by king_win - the same predicate finale_cell reads below.
function king_bar_permille()
{
	if ( !isdefined( level.tod_king_hp_frac ) )
		return -1;
	pm = int( level.tod_king_hp_frac * 1000 + 0.5 );
	if ( pm < 0 )
		pm = 0;
	if ( pm > 1000 )
		pm = 1000;
	return pm;
}

function finale_cell()
{
	// v17.70 THE WARDEN KING'S HEALTH BAR (user 2026-09-05: "His health bar
	// will actually be the spire bar. It will be completely lit up and as you
	// kill him it drains down"). _tod_spire::king_hp_bar publishes his health
	// as a fraction; the bar shows ceil( frac x cells ) — every cell AND the
	// summit at full, the last cell for his last sliver — and the finale lane
	// below is shadowed while it is defined. Cleared by king_win.
	// v19.76: the gauge is HIDDEN for the fight now (the tester's top-of-screen
	// boss bar replaces it, king_bar_permille above) but is still fed here, so
	// it is right the moment it comes back and the rollback is one Lua line.
	if ( isdefined( level.tod_king_hp_frac ) )
	{
		cells = cells_for_mode();
		if ( level.tod_king_hp_frac >= 0.999 )
			return ( cells + 1 );
		c = int( level.tod_king_hp_frac * cells + 0.999 );
		if ( c > cells )
			c = cells;
		if ( c < 0 )
			c = 0;
		return c;
	}
	if ( !isdefined( level.tod_finale_song_start ) || !isdefined( level.tod_finale_song_end ) )
		return -1;

	span = level.tod_finale_song_end - level.tod_finale_song_start;
	if ( span <= 0 )
		return -1;

	done = GetTime() - level.tod_finale_song_start;
	if ( done < 0 )
		done = 0;

	cells = cells_for_mode();
	c = int( done * cells / span );
	if ( c > cells )
		c = cells;
	return c;
}

// ---------------------------------------------------------------------------
// THE MODE (docs/71). 0 = the tower (25 cells, the crown on top); 1 = THE
// ENDLESS SPIRE after ascension (50 cells, the summit on top); 2 = the spire
// with the summit extraction bought (same grid, the beacon tile goes green).
// Level-wide, not per player: the whole party ascends together and one way
// (_tod_spire sets tod_spire_active on arrival and tod_spire_won at the
// summit; this module only READS them — no second latch).
// ---------------------------------------------------------------------------
function gauge_mode()
{
	if ( IS_TRUE( level.tod_spire_won ) )
		return 2;
	if ( IS_TRUE( level.tod_spire_active ) )
		return 1;
	return 0;
}

function cells_for_mode()
{
	return ( ( gauge_mode() > 0 ) ? TOD_GAUGE_SPIRE_CELLS : TOD_GAUGE_CELLS );
}

function laps_for_mode()
{
	return ( ( gauge_mode() > 0 ) ? TOD_GAUGE_SPIRE_LAPS : TOD_GAUGE_LAPS );
}

// -> the CELL index on the bar (1..cells), 0 = base arena, cells + 1 = the
// roof (tower) or the summit (spire). Both towers stack LAP_RISE floors from
// z = 0 on their own axis, so the arithmetic is shared and only the counts
// differ. The spire's arrival arena stands AT z = 0 (the tower's is below
// it), so in spire mode the first FLOOR_EPS units read as the base — the
// lowest tread of flight 1 is already above that.
function floor_of( z )
{
	laps = laps_for_mode();
	cells = cells_for_mode();
	if ( z >= laps * TOD_GAUGE_LAP_RISE )
		return cells + 1;
	if ( z < ( ( gauge_mode() > 0 ) ? TOD_GAUGE_FLOOR_EPS : 0 ) )
		return 0;
	f = 1 + int( z / TOD_GAUGE_LAP_RISE );      // real floor 1..laps
	if ( f > laps )
		f = laps;
	if ( f < 1 )
		f = 1;
	c = int( ( f + 1 ) / 2 );                   // 2 floors per cell (ceil), both towers
	if ( c > cells )
		c = cells;
	if ( c < 1 )
		c = 1;
	return c;
}

// ---------------------------------------------------------------------------
// THE DOWNED-TEAMMATE CELLS (v14.50, user 2026-08-31: "players dont know where
// their tm8s are when they go down ... makes a section light red if a player is
// down at that location").
//
// A BITMASK, NOT A CELL NUMBER, and that is the whole design decision (user,
// same day: "there is always a possibility that multiple players are down at
// different areas so we need to be prepared to have multiple squares red ...
// I dont want the system to break cause it doesnt expect 2,3 players down at
// once"). Bit (cell-1) is set for every cell holding at least one downed
// teammate, so the Lua walks 25 bits and never needs to know how many people
// are down — one, two or three reds cost the same code path, and there is no
// "the" down cell anywhere in this feature to be wrong about.
//
// `|` AND NEVER `+`. Two players down on the SAME cell is the case a sum gets
// wrong (bit 4 + bit 4 = bit 5 — a red cell one floor above where anybody
// actually is). OR is idempotent, so the same cell set twice is the same mask,
// which makes the collision case correct by construction rather than by a
// guard somebody has to remember.
//
// PER VIEWER, EXCLUDING THEIR OWN BODY: a downed player knows where they are,
// so red on this gauge means exactly one thing — "a teammate is there and
// needs you". Solo therefore never sees a red cell at all, which is right.
//
// -> a FOUR-ELEMENT array of 13-bit chunks: [k] holds cells 13k+1 .. 13k+13.
// The split is a transport concern, not a design one (see the header): it
// keeps every number under 8191 so no float rounding can eat a bit. [0],[1]
// ride tod_down and [2],[3] ride tod_down2 (docs/71 — the spire's 50 cells
// need all four; the tower only ever fills the first two). Callers hand them
// straight to the events and never interpret them. LOCKSTEP with GA_SPLIT in
// the Lua, which unpacks by the same chunk/bit arithmetic.
// ---------------------------------------------------------------------------
function down_mask_for( viewer )
{
	m = [];
	m[ 0 ] = 0;
	m[ 1 ] = 0;
	m[ 2 ] = 0;
	m[ 3 ] = 0;

	foreach ( q in GetPlayers() )
	{
		if ( !isdefined( q ) || !isplayer( q ) || q == viewer )
			continue;

		// LAST STAND ONLY, and IsAlive is what separates it from a corpse:
		// isalive stays TRUE through last stand (map 1's down-path lesson) and
		// goes FALSE once the player has bled out. That is exactly the line
		// this marker wants — a bled-out player cannot be revived, so sending
		// the party 30 floors to their body would be a lie. And
		// player_is_in_laststand() reads the revive trigger's existence, so it
		// clears itself the frame a revive completes; nothing here has to
		// watch for the revive.
		if ( !IsAlive( q ) || !( q laststand::player_is_in_laststand() ) )
			continue;

		c = down_cell_of( q.origin[ 2 ] );
		chunk = int( ( c - 1 ) / TOD_GAUGE_MASK_SPLIT );
		bit = ( c - 1 ) - ( chunk * TOD_GAUGE_MASK_SPLIT );
		m[ chunk ] = m[ chunk ] | ( 1 << bit );
	}
	return m;
}

// -> a cell the gauge can actually DRAW (1..CELLS) for any world z.
//
// The same clamp the boss pip already pays for, for the same reason, and the
// direct answer to the user's "or at least pick the closest section ... catch
// the edge cases where they may be in between section or something": every z
// between the base deck and the roof already lands in a cell by construction
// (floor_of has no gaps), so the only real edge cases are the two ENDS. A down
// in the base arena reads z < 0 -> 0, and a down on the roof, the causeway or
// the crown reads ROOF_ID 26; neither is a drawable cell, and a mask bit for
// either would render nowhere at all — "nobody is down" at the exact moment
// somebody is. Pinning them to the bottom and top cells puts the mark on the
// nearest section to where that player physically is.
function down_cell_of( z )
{
	c = floor_of( z );
	cells = cells_for_mode();
	if ( c < 1 )
		c = 1;
	if ( c > cells )
		c = cells;
	return c;
}

// -> the REAL floor (1..LAPS), 0 = below the base arena deck.
//
// floor_of()'s ungrouped sibling, and deliberately NOT built on top of it: the
// gauge folds two floors into one art cell and pins everything at or above the
// roof to ROOF_ID, both of which are answers about the BAR, not about the
// tower. This one is the answer about the tower, so a gate can be written
// against the floor numbers the player actually reads on their HUD
// ("floor 10", not "cell 5"). It clamps at LAPS, so the crown, the causeway
// and the Endless Spire all report the top floor rather than running off the
// end — every one of them is above every gate by construction.
function real_floor_of( z )
{
	if ( z < 0 )
		return 0;
	f = 1 + int( ( z + TOD_GAUGE_FLOOR_EPS ) / TOD_GAUGE_LAP_RISE );
	if ( f > TOD_GAUGE_LAPS )
		f = TOD_GAUGE_LAPS;
	return f;
}

// -> the FLOOR LABEL code (2026-10-01, docs/167 item 12). LOCKSTEP with
// CoD.TodFloorLabelText in AetheriumHud.lua:
//   1..laps      tower floor n ("FLOOR n"; the base arena is floor 1, like the gauge)
//   100          above the tower's last lap: the terrace, causeway and crown ("THE CROWN")
//   1000 + n     Endless Spire floor n ("SPIRE FLOOR n")
//   1100         above the spire's last lap ("THE SUMMIT")
// real_floor_of's arithmetic, but against THIS mode's lap count: real_floor_of
// clamps at the tower's 50, which is right for the class gate and wrong for a
// label read on a 70-floor spire.
function floor_label_code( z )
{
	laps = laps_for_mode();
	spire = ( gauge_mode() > 0 );
	if ( z >= laps * TOD_GAUGE_LAP_RISE )
		return ( ( spire ) ? 1100 : 100 );
	f = 1;
	if ( z > 0 )
		f = 1 + int( ( z + TOD_GAUGE_FLOOR_EPS ) / TOD_GAUGE_LAP_RISE );
	if ( f > laps )
		f = laps;
	if ( spire )
		return 1000 + f;
	return f;
}

// PUBLIC — the highest REAL floor this player has stood on this match.
// 0 until the first poll. It only ever RISES, so a player who climbs to a
// breather and then rides a teleporter back to the base keeps what they
// earned; the gate asks "have you been there", not "are you there now".
// Lives on the player entity, which survives death and respawn the same way
// tod_tier and tod_levels do.
function floor_reached( player )
{
	if ( !isdefined( player ) || !isdefined( player.tod_floor_best ) )
		return 0;
	return player.tod_floor_best;
}

// PUBLIC — stamp the high-water at the top of the tower.
//
// For paths that put a player above every gate by construction and must not
// wait on the 0.35s poll to notice: the Endless Spire's grant_all runs its
// tier_up ladder in the same frame the party is teleported out of the citadel,
// and a grant is not a thing that may fail on a sampling race.
function mark_top_reached( player )
{
	if ( !isdefined( player ) )
		return;
	player.tod_floor_best = TOD_GAUGE_LAPS;
}

function dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_GAUGE] ms=" + GetTime() + " " + msg;
	/# PrintLn( line ); #/
}

// A Panzer is `tod_boss_kind == "panzer"` (stamped by the map's spawn lane,
// _tod_bosses:2276 — every Panzer, trial Warden and the King come through it)
// or `is_mechz` (the pack's own archetype flag, mechz_spiki:416, set by the
// spawn funcs the lane self-heals). Either alone identifies him.
function is_panzer( b )
{
	if ( isdefined( b.tod_boss_kind ) && b.tod_boss_kind == "panzer" )
		return true;
	return IS_TRUE( b.is_mechz );
}

// THE PANZER PIPS (v19.46, user 2026-09-23: "that icon should only be used
// for panzers, it should not be used for elites" and, the same hour, "if
// there's two panzers and they're on the same floor, maybe it's one indicator
// on that floor. But if there's two panzers and they're on separate floors,
// maybe we can show two indicators"). Returns the DISTINCT cells that hold a
// live Panzer, highest first, at most TOD_GAUGE_PIPS_MAX of them (the highest
// kept); an empty array = no Panzer alive. Two Panzers in one cell = one pip.
//
// Until v19.46 the gauge showed ONE pip at the LOWEST of every entity carrying
// `.is_boss` / `.acc_is_boss` / `.acc_is_mini_boss` — which the Rogue
// Protector (_tod_bosses:2859) and the Reaver (_tod_reaver:272) carry as well
// as the Panzer (_tod_bosses:2238), so a Protector wave below the party wore
// the pip and the real Panzer's floor was hidden behind whichever elite was
// lowest. The two counts are stashed for the change-gated PIP log in gauge_loop.
function boss_cells()
{
	team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
	ai = GetAITeamArray( team );

	found = [];   // found[ cell ] = true
	panzers = 0;
	elites = 0;
	cells = cells_for_mode();
	foreach ( b in ai )
	{
		if ( !isdefined( b ) || !IsAlive( b ) )
			continue;
		if ( !is_panzer( b ) )
		{
			if ( IS_TRUE( b.is_boss ) || IS_TRUE( b.acc_is_boss ) || IS_TRUE( b.acc_is_mini_boss ) )
				elites++;
			continue;
		}
		panzers++;
		f = floor_of( b.origin[ 2 ] );
		// CLAMP BOTH ENDS (audit 2026-08-25). floor_of() returns 26 (ROOF_ID) for
		// anything at or above the roof, and the Lua only draws the pip for
		// 1..CELLS(25) — so a Panzer on the rooftop arena made the pip VANISH,
		// reading as "no boss" at the exact moment there certainly is one.
		// Pinning it to the top cell puts it where the crown is, which is true.
		if ( f <= 0 )
			f = 1;
		if ( f > cells )
			f = cells;
		found[ f ] = true;
	}
	level.tod_gauge_pip_panzers = panzers;
	level.tod_gauge_pip_elites = elites;

	// Highest first: walk the cells from the top, stop at the pip budget.
	result = [];
	for ( c = cells; c >= 1; c-- )
	{
		if ( !isdefined( found[ c ] ) )
			continue;
		if ( result.size >= TOD_GAUGE_PIPS_MAX )
			break;
		result[ result.size ] = c;
	}
	return result;
}

// The highest live Panzer's cell, 0 = none (tod_floor's second arg / the log).
function boss_floor()
{
	pips = boss_cells();
	if ( pips.size == 0 )
		return 0;
	return pips[ 0 ];
}

// Two cells per int: hi*64 + lo. LOCKSTEP with the tod_pips decode in
// tod_upgrade.lua (floor( v / 64 ), v % 64).
function pack_pips( pips, first )
{
	hi = 0;
	lo = 0;
	if ( isdefined( pips[ first ] ) )
		hi = pips[ first ];
	if ( isdefined( pips[ first + 1 ] ) )
		lo = pips[ first + 1 ];
	return hi * 64 + lo;
}
