// =============================================================================
// _tod_upgrade_ui.gsc — upgrade-choice UI, server half (logic + input).
//
// v2 = real LUI (ui/uieditor/menus/hud/tod_upgrade.lua, the map 1 4-file
// contract: this #precache + OpenLUIMenu, the CSC LuiLoad, the zone rawfile
// line). This module owns STATE + INPUT; the Lua is a dumb renderer fed by
// all-INT clientuimodel clientfields (18 as of v4.4, registered here + in
// the .csc twin in EXACT lockstep — a width/order mismatch corrupts the bit
// layout; APPEND ONLY). This module is the ONE home for every clientuimodel
// registration (upgrade panel + damage numbers + mag chip + class draft).
//
// Input (v4.4): a card is ALWAYS focused — D-PAD/stick switches, HOLD JUMP
// 0.5s locks (with a hold-progress bar via todUpgHold), release cancels.
// Focus pulse is SERVER-driven (this loop toggles bright/dim ~7 Hz — client
// UITimers are the map 1 leak trap). Sounds: tick on switch, confirm on
// lock, SUPER/ULTIMATE stings on reveal (aliases in sound/aliases/tod_ui.csv).
//
// tod_upgrades calls `player present_choice( opts, timeout )` -> returns 1|2.
// =============================================================================

#using scripts\shared\callbacks_shared;   // on_connect -> the per-life overlay rebuild
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\zm_tower_of_doom\_tod_toast.gsh;

#precache( "lui_menu", "tod_upgrade" );
// v16.3 — the device latch's client notify (see pad_latch). Same precache trap
// as tod_upg_sync in _tod_upgrades.gsc: an unprecached eventstring never fires
// and nothing reports it.
#precache( "eventstring", "tod_input_pad" );

// Hold-to-lock duration. -35% (user 2026-08-21): 0.5 -> 0.325s.
#define TOD_UPG_HOLD_SECS   0.325
#define TOD_UPG_BLINK_SECS  0.15
// v14.9 OVERCHARGE: at this raw bar value set_luck_pct sends the sentinel 11
// instead of 10 — the base zap frame; _tod_luck's overcharge_driver then
// cycles 11..14 live. LOCKSTEP PAIR with TOD_LUCK_OVERMAX in _tod_luck.gsc
// (defines are per-file; the modules cannot share one).
#define TOD_UPG_LUCK_OVERMAX_PCT 150
// Damage-number accumulation window — one server frame. See push_dmg_num.
#define TOD_DMGNUM_WINDOW   0.05
// v19.47 — ONE NUMBER PER ZOMBIE over the int-only scriptNotify lane (tod_dmg).
// BURST = events per player per frame (the King max-out's TOD_SYNC_BURST
// precedent); the rest carry into the next frame, never summed across zombies.
// PENDING = queue ceiling per player; past it a NEW zombie's hit is dropped
// (its number, not its damage). CAP = the Lua's seven-glyph pool.
#define TOD_DMGNUM_BURST    8
#define TOD_DMGNUM_PENDING  24
#define TOD_DMGNUM_CAP      9999999
// Queue-key offset for BURN numbers (v19.50): keeps a burn tick and a gun hit
// on the same zombie in separate numbers. Above any entity number (the gentity
// table is ~1024) by a wide margin; only push_dmg_num reads it.
#define TOD_DMGNUM_BURN_KEY 100000
// Scoreboard-over-banner lane (see scoreboard_watch). LOCKSTEP: the menu name
// and key are literals in AetheriumScoreboard.lua's SendMenuResponse.
#define TOD_SB_MENU        "StartMenu_Main"
#define TOD_SB_KEY         "tod_sb"
#define TOD_BANNER_HIDE_X  4000
#precache( "eventstring", "tod_dmg" );
#precache( "eventstring", "tod_toast" );
#precache( "eventstring", "tod_game_time" );   // v19.59b pause-menu GAME TIME in the typeface (see game_time_push)      // v19.58 HUD toasts in the map typeface (see toast())
#precache( "eventstring", "tod_choosing" );   // v19.58 the co-op CHOOSING line (see choosing_push())
#precache( "eventstring", "tod_upg_pips" );   // docs/172 the cards' live level pips (see pips_push())

// ---------------------------------------------------------------------------
// THE CARD REVEAL (v14.52, user 2026-08-31: "like when you pull a super cool
// camo in csgo or apex legends crates ... if a slot is ultimate it can be empty
// for 0.5s and then grow into its ultimate card and then make an epic noise").
//
// THE HOLD IS THE FEATURE. A slot sits EMPTY for longer the rarer its card is,
// so the wait itself is the tell — the player knows something good is coming
// before they can see what it is, which is the entire loot-box grammar. The
// riser SFX is layered on top of that same wait.
//
// ⚠️ LOCKSTEP with REVEAL_HOLD_MS in ui/uieditor/menus/hud/tod_upgrade.lua.
// The client ramps the socket's rim from neutral to the rarity colour over the
// SAME duration, so the ramp lands exactly as the card does. Nothing BREAKS if
// they drift (a short ramp holds its end colour, a long one is cut off by the
// card) — it just stops feeling deliberate. Change both.
// ⚠️ EVERY TIMING HERE WAS HALVED (v14.53, user 2026-08-31: "the game is fast
// paced ... can we cut all the delays in half"). The SHAPE is unchanged — the
// rarity ladder and every ratio between these numbers survived the cut intact,
// which is the point: halving all six keeps the choreography and only changes
// its tempo. If they are ever retuned again, move them together or the ladder
// stops reading.
#define TOD_REVEAL_OPEN         0.175  // empty sockets on screen before slot A's hold
#define TOD_REVEAL_HOLD_REG     0.05   // regular: barely a beat, deliberately dull
#define TOD_REVEAL_HOLD_SUPER   0.20
#define TOD_REVEAL_HOLD_ULT     0.30
#define TOD_REVEAL_GAP          0.14   // slot A lands -> slot B's hold begins
#define TOD_REVEAL_TAIL         0.15   // last card lands -> input opens
// HOW FAR AHEAD OF ITS CARD EACH STING FIRES (v14.53).
//
// ⚠️ THESE ARE PER-ASSET, NOT PER-RARITY — the single most important thing to
// know before touching them. The lead exists to cancel a wav's own ONSET DELAY
// so its punch lands ON the card, so the correct value is a property of the
// FILE, not of how rare the card is.
//
// THE RULE JUST PAID FOR ITSELF (v14.57, user: "the super sfx is better. Lets
// use that for both super and ultimate and the only difference is that ultimate
// hears the aura"). Both stings are now the SAME WAV, so both leads are the
// same 0.20 — measured, not assumed: tod_super_sting.wav opens on silence
// (-54 dB at t=0) and swells to its body by ~0.20s (-3.7 dB). ULTIMATE'S LEAD
// WAS 0.10 AND HAD TO MOVE WITH THE ASSET; left alone it would have fired the
// sting 0.10s early while its actual punch landed 0.10s LATE — a sound both
// early and late at once, and the sort of thing that gets blamed on "feel".
//
// **REGENERATE EITHER WAV AND RE-MEASURE ITS ONSET, THEN RESET ITS LEAD.** A
// sting rebuilt with a hard transient (still on the table) needs this back near
// 0, or it fires a fifth of a second early and reads as broken.
//
// Both scale with sc, so the station keeps the same proportions.
// EACH LEAD NOW EQUALS THE SUPER'S WHOLE HOLD (0.20), so on a SUPER the sting
// starts on the same frame the socket begins charging and the riser plays under
// it throughout. Legal — see reveal_slot: the snapshot guarantee rides the full
// hold, not the split — and the reason the riser is ducked to 86. The ULTIMATE's
// longer 0.30 hold still gets 0.10s of riser alone before its sting.
#define TOD_REVEAL_LEAD_ULT     0.20
#define TOD_REVEAL_LEAD_SUPER   0.20

// ---------------------------------------------------------------------------
// THE ULTIMATE AURA (v14.55, user 2026-08-31: "when you have an ultimate card
// displayed you will hear the aura sound that the heavenly altar makes. But
// this time its 2d and only your player hears it. Which makes sense since its
// your cards" + "make the aura sound like its coming from left or right
// depending on which side the ultimate is on ... if both cards are ultimate it
// sounds louder like an epic decision must be made").
//
// SAME LANE AS THE OVERCHARGE ZAP — `self PlayLocalSound()` on a repeating
// driver, which the user correctly pointed out was already proven
// (_tod_luck::overcharge_driver, v14.9b). PlayLocalSound is 2d and reaches ONE
// player; PlayLoopSound on an entity would broadcast to the whole lobby, so
// the retrigger is not a workaround, it IS the per-player mechanism here.
//
// PANNING IS BAKED INTO THE WAVS, not derived at runtime. The three units are
// pre-panned stereo cuts of tod_altar_aura.wav and the aliases are 2d, so the
// image is pinned to the SCREEN. A 3d emitter would have re-derived direction
// from world position and swung the aura around as the player turned their
// view — wrong for "the card on the left", and the panel does not lock the
// camera.
//
// UNIT 2.0s with 0.2s fades at both ends; retriggered every 1.8s so each pass
// crossfades over the seam. THAT 0.2s OVERLAP IS THE WHOLE TRICK — change one
// of these two and change the other. The tail after a pick is bounded by the
// unit length, and the 0.7s confirm flash covers most of it.
#define TOD_AURA_UNIT_SECS      1.8
// Hard ceiling on the driver, belt-and-braces beside its endons: it can never
// outlive the panel even if a future abort path forgets to notify. Sized off
// the choice window with room for the reveal.
#define TOD_AURA_MAX_PASSES     14
// DARK UPGRADES (v17.10) — the same driver, a different unit. `tod_dark_aura` is
// a 7.80s wav with a 0.35s tail fade, so it retriggers at 7.6s and the new head
// lands ON that fade as a re-swell instead of a gap. User 2026-09-04: "B but
// repeats until selection".
//
// DO NOT REUSE TOD_AURA_UNIT_SECS FOR THIS. That 1.8s against a 2.0s wav is the
// heavenly pad's own deliberate 0.2s crossfade and is shared; a dark unit is a
// different number for a different asset, and collapsing them would silently
// re-cut the ultimate aura.
#define TOD_DARK_AURA_UNIT_SECS 7.6
// The panel times out at 15s, so three passes is already more than the window
// can spend. Cheap belt against a forgotten abort path, same as the pad's.
#define TOD_DARK_AURA_MAX_PASSES 3
// LOCKSTEP with TOD_UPG_DARK_L in _tod_upgrades.gsc and with tod_upgrade.lua's
// DARK_L. The 4-bit level field carries this sentinel to mark a dealt card as
// DARK — domain levels top out at 10, so 15 is unreachable as a real value and
// the feature costs ZERO clientfield bits against a pool at 60 of its 61
// proven-booted ones. Same idiom as the TIER card packing class+tier here.
#define TOD_UPG_DARK_L          15
// A CO-OP STATION IS NOT A PAUSED WORLD. Round events run under
// level.tod_upgrade_pause, where the reveal is free; the personal upgrade
// station in CO-OP (the deliberate risk — see _tod_upgrades solo_present_run)
// leaves zombies live, so every tenth of a second of un-pickable card is real
// danger. Same show, run at this fraction of the clock.
// A SOLO STATION PICK NO LONGER TAKES THIS CUT (v16.84): it sets
// level.tod_upgrade_pause itself, so the test below already answers "paused"
// and the reveal plays at full speed. Nothing here changed — the flag became
// true in one more situation, and that is the situation this scale existed to
// avoid.
#define TOD_REVEAL_LIVE_SCALE   0.5

#namespace tod_upgrade_ui;

REGISTER_SYSTEM( "tod_upgrade_ui", &__init__, undefined )

function __init__()
{
	// MUST match _tod_upgrade_ui.csc EXACTLY (scope/name/version/bits/type,
	// same order). Our clientuimodel pool is otherwise empty.
	// CLASS TIERS widening (2026-08-22, docs/25 §8 Phase 0): the domain-id
	// fields grow 5 -> 6 bits (ids 1..63; the tier card is 24 and the per-gun
	// uniques 25..31 did not fit in 31). Paid for by todMagBonus 7 -> 1 — the
	// virtual mag pool was deleted 2026-08-20 and the field has read 0 ever
	// since. Net 61 -> 57 custom bits. ORDER UNCHANGED.
	clientfield::register( "clientuimodel", "todUpgShow",  VERSION_SHIP, 2, "int" );
	clientfield::register( "clientuimodel", "todUpgAD",    VERSION_SHIP, 6, "int" );   // 6 bits: domain ids 1..63 (was 5, 2026-08-22)
	clientfield::register( "clientuimodel", "todUpgAR",    VERSION_SHIP, 2, "int" );
	clientfield::register( "clientuimodel", "todUpgAL",    VERSION_SHIP, 4, "int" );
	clientfield::register( "clientuimodel", "todUpgBD",    VERSION_SHIP, 6, "int" );   // 6 bits: domain ids 1..63 (was 5, 2026-08-22)
	clientfield::register( "clientuimodel", "todUpgBR",    VERSION_SHIP, 2, "int" );
	clientfield::register( "clientuimodel", "todUpgBL",    VERSION_SHIP, 4, "int" );
	clientfield::register( "clientuimodel", "todUpgLuck",  VERSION_SHIP, 4, "int" );
	clientfield::register( "clientuimodel", "todUpgFocus", VERSION_SHIP, 3, "int" );
	clientfield::register( "clientuimodel", "todUpgTime",  VERSION_SHIP, 4, "int" );   // seconds left, 15..0
	clientfield::register( "clientuimodel", "todMagBonus", VERSION_SHIP, 1, "int" );   // DEAD field (mag pool deleted 2026-08-20); 7 -> 1 bit 2026-08-22, always 0
	// Crosshair damage number: min(dmg,2047)*8 + reduced*4 + headshot*2 +
	// parity (parity flips per push so identical numbers re-pop). WIDENED
	// 13 -> 14 BITS (v13.9, user: sprinter hits "should be red ... to show you
	// are doing reduced damage") — the reduced bit rides the same field.
	// BUDGET: 58 -> 59 of the 61 PROVEN-BOOTED bits. Two left. Matching 14 in
	// the .csc register — the pair MUST move together (clientfield lockstep).
	clientfield::register( "clientuimodel", "todDmgNum",  VERSION_SHIP, 15, "int" );   // 14 -> 15 on 2026-09-09: the SCALE bit (hundreds / thousands). The pool is now 61 of 61.
	// Hold-to-lock progress 0..15 (the fill bar — SHARED by the upgrade panel
	// and the class draft; the two are never on screen together).
	clientfield::register( "clientuimodel", "todUpgHold", VERSION_SHIP, 4, "int" );
	// Class draft (_tod_class_select.gsc drives; tod_class_select.lua
	// renders): ONLY Show is class-specific — focus/time/hold RIDE the
	// todUpgFocus/todUpgTime/todUpgHold fields above (time is HALVED
	// server-side: 30s -> 15, the Lua displays x2). Show: 0 off / 1 choosing
	// / 2 locked-flash (the picked class = todUpgFocus at that moment).
	//
	// BUDGET (hard lesson 2026-08-19): the clientuimodel pool is SHARED with
	// stock zmhud.* + the Aetherium kit. 83 custom bits OVERFLOWED the pool
	// (Com_ERROR "clientuimodel is out of space" evicting zmhud.swordState =
	// map load aborts to the lobby). 61 custom bits was the last
	// PROVEN-BOOTED budget; this layout = 57 (the 2026-08-22 widening above
	// trimmed 4). Adding ANY field needs an equal trim.
	clientfield::register( "clientuimodel", "todClsShow",  VERSION_SHIP, 2, "int" );
	// THE FINALE ROAD BANNER (v10.26) — 1 bit, on/off. The blink is done
	// client-side in tod_upgrade.lua, so the wire only ever carries the state
	// change: two writes per game, not one per flash.
	// BUDGET: this takes the layout from 57 to 58 of the 61 PROVEN-BOOTED bits.
	// Three left. The next field still has to pay for itself by trimming one.
	clientfield::register( "clientuimodel", "todFinaleWarn", VERSION_SHIP, 1, "int" );
	// RAMPAGE INDUCER (v14.20): 1 = hard mode is ON, and the Lua draws the RED
	// luck bar set instead of the amber one (tod_upgrade.lua LuckBar). APPENDED,
	// never inserted — the register ORDER is the wire format, so a field added
	// anywhere but the end re-numbers every field after it.
	//
	// WHY A NEW FIELD AND NOT A todUpgLuck WIDENING: todUpgLuck is 4 bits and
	// every value is spoken for — 0..10 are the eleven baked fill states and
	// 11..14 are v14.9's overcharge zap frames, leaving exactly ONE spare. The
	// red set needs fifteen more states, so it cannot ride that field, and
	// widening 4 -> 5 would not be an append.
	//
	// BUDGET (counted from the tree 2026-08-30, both VMs): the fifteen fields
	// above total 59 bits — 2+6+2+4+6+2+4+4+3+4+1+14+4+2+1. This one takes it
	// to 16 fields / 60 bits against the PROVEN ceiling of 18 / 61. One bit
	// left after this; the next feature needs the LuiNotifyEvent lane instead.
	//
	// NOT REUSING todMagBonus: it is a dead 1-bit field that has read 0 since
	// the mag pool was deleted, so it is tempting — but the name would then lie
	// about its contents, which is how the next reader gets misled.
	clientfield::register( "clientuimodel", "todRampage",  VERSION_SHIP, 1, "int" );
	// v17.93 FULL STEAM's wind goes PLAYER-ONLY (user 2026-09-05: "Other players
	// shouldnt be able to hear it"). It was a server PlayLoopSound on the player
	// entity with a 2D alias — every client rendered it at full volume. A
	// toplayer bit (its own pool, not the 61-bit clientuimodel budget) tells the
	// owner's client VM to run the loop locally; the .csc twin owns the handle.
	// LOCKSTEP with _tod_upgrade_ui.csc; the alias itself is TOD_LMGS_SFX in
	// _tod_upgrades.gsc and the literal in the .csc callback.
	clientfield::register( "toplayer", "todSteamWind", VERSION_SHIP, 1, "int" );

	// Guarantees every panel is down when the run ends — see clear_ui_on_end.
	level thread clear_ui_on_end();
	level thread game_time_push();

	// The per-life overlay rebuild — see player_lui_life for the why.
	callback::on_connect( &on_player_connect );
}

// SHOTGUNS READ ONE PELLET (user 2026-08-25: "when i use a shot gun the damage
// indicators dont add up ... Im shooting the executioner and it shows 150 to the
// head but its killing the zombie on round 10").
//
// THE CAUSE IS THE CHANNEL, NOT THE MATH. todDmgNum is ONE clientuimodel field,
// and a networked field carries only its LAST value per server snapshot. A
// pellet shotgun raises one damage event PER PELLET, all inside the same server
// frame, so the eight writes below collapsed into one and the player saw a
// single pellet. The Executioner is 50/pellet x 8; a headshot is x3 = 150 per
// pellet — exactly the number reported — while the zombie actually ate 1,200.
// Nothing was wrong with the damage; only with what got drawn.
//
// MAP 1 HIT THIS AND SOLVED IT DIFFERENTLY: _acc_dev.gsc queues every event in a
// ring buffer and drains ONE per ~0.025s, so a shotgun reads as a fast flurry of
// eight separate numbers. That works, and it is why that map needed a parity bit
// and a self-terminating push loop. WE SUM INSTEAD, because the user asked for
// "a single damage number" and because summing is strictly cheaper: one network
// write per shot instead of eight, no drain loop to stall, and no queue to
// overflow on a Death Machine.
//
// THE WINDOW IS ONE SERVER FRAME. Pellets from one trigger pull all land in the
// same frame, so 0.05s captures a shot completely while staying at or below the
// fastest fireTime in the roster (Death Machine 0.05, PaP MP7 0.0512) — and on
// those two, merging two consecutive bullets into one number is a readability
// win rather than a loss. The window is FIXED, not extended per hit, so
// sustained fire can never accumulate without ever flushing.
//
// It also merges one shot across MULTIPLE zombies (a penetrating round, a pellet
// spread over a crowd). That is deliberate: the number answers "what did that
// shot do", which is the question being asked.
// PUBLIC — accumulate a crosshair damage number. self = the attacking player.
// The actual push happens in dmg_num_flush one frame later.
// Only our Panzer wrapper owns a later authoritative staff-damage result.
// The marker is installed with that wrapper, so other actors retain the
// ordinary HUD path. No import of the Mage module (which imports upgrades).
function defer_staff_damage_number( victim, weapon )
{
	return ( isdefined( victim ) && IS_TRUE( victim.tod_staff_damage_number_final )
	    && isdefined( weapon ) && isdefined( weapon.name )
	    && IsSubStr( weapon.name, "tod_staff_" ) );
}

// v19.47 — ONE NUMBER PER ZOMBIE (user 2026-09-23: "if you use the fire blast
// on the fire staff, and you hit multiple zombies, all of that adds up and it
// can say like 1 million ... it's confusing to a player how sometimes one shot
// can do 1 million or it can do 200k ... I don't think I ever want to see the
// damage numbers combine for multiple zombies").
//
// THE CHANNEL CHANGED, NOT THE MATH. The summing above existed because the
// old carrier, the todDmgNum clientuimodel field, holds ONE value per server
// frame. The numbers ride the int-only scriptNotify lane now — the same
// LuiNotifyEvent lane the owned-upgrades sync fires up to eight of per frame
// (TOD_SYNC_BURST, _tod_upgrades) — where EVERY call is delivered, so a splash
// over five zombies is five events in one frame and five numbers on screen at
// once. What still merges: the pellets / ticks of one shot on ONE zombie in
// one frame (a shotgun reads one number per zombie, as the 2026-08-25 report
// asked). What never merges: two zombies. The queue is keyed by the victim's
// entity number; hits with no victim (the unknown bucket, key 0) merge with
// each other only. A frame's overflow past TOD_DMGNUM_BURST carries into the
// next frame; a zombie past TOD_DMGNUM_PENDING loses its NUMBER (not its
// damage). The todDmgNum clientfield stays registered (the 61-bit layout is
// proven and untouched) but nothing writes or reads it now.
//
// Dev log `[TOD_DMGNUM]` (change-only, tod_dev): FLUSH of any multi-zombie
// frame (n, sent, carried), DROP at the queue ceiling.
function dmgnum_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_DMGNUM] ms=" + GetTime() + " " + msg;
	/# PrintLn( line ); #/
}

// PUBLIC — queue a crosshair damage number. self = the attacking player;
// victim = the actor that took it (undefined = the unknown bucket). The push
// happens in dmg_num_flush one frame later, one event per zombie.
// burn (optional, v19.50, user 2026-09-23: "Any burn damage on enemies will
// be orange on the damage display HUD. Multiple classes can do burn damage"):
// TRUE for a fire-over-time tick — TRAILBLAZER's trail and FIRE BLAST's elite
// burn today. Carried as flag bit 3 and drawn ORANGE by the Lua. A burn tick
// is queued under its OWN key (TOD_DMGNUM_BURN_KEY + victim), so a bullet and
// a burn landing on one zombie in the same frame stay two numbers: one amber,
// one orange. Merging them would have painted the gun hit orange too.
function push_dmg_num( dmg, headshot, reduced, victim, burn )
{
	if ( !isdefined( dmg ) || dmg <= 0 )
		return;
	key = 0;
	if ( isdefined( victim ) )
		key = victim GetEntityNumber() + 1;
	if ( IS_TRUE( burn ) )
		key += TOD_DMGNUM_BURN_KEY;
	if ( !isdefined( self.tod_dmg_q ) )
		self.tod_dmg_q = [];
	e = self.tod_dmg_q[ key ];
	if ( !isdefined( e ) )
	{
		if ( self.tod_dmg_q.size >= TOD_DMGNUM_PENDING )
		{
			dmgnum_log( "DROP player=" + self GetEntityNumber() + " pending=" + self.tod_dmg_q.size + " dmg=" + dmg );
			return;
		}
		e = SpawnStruct();
		e.dmg = 0;
		e.head = false;
		e.red = false;
		e.burn = IS_TRUE( burn );
		self.tod_dmg_q[ key ] = e;
	}
	e.dmg += dmg;
	if ( IS_TRUE( headshot ) )
		e.head = true;   // any pellet in the head colours the number
	if ( IS_TRUE( reduced ) )
		e.red = true;    // any armored (sprinter) hit REDDENS it — red WINS
		                 // over headshot in the Lua, because "you are doing
		                 // reduced damage" is the fact the colour carries
	if ( !IS_TRUE( self.tod_dmg_acc_on ) )
	{
		self.tod_dmg_acc_on = true;
		self thread dmg_num_flush();
	}
}

// self = the attacking player. Threaded, because push_dmg_num is called from
// inside damage callbacks and a callback must never wait. Sends up to
// TOD_DMGNUM_BURST numbers per frame and keeps going while anything is queued.
function dmg_num_flush()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	wait TOD_DMGNUM_WINDOW;
	for ( ;; )
	{
		q = self.tod_dmg_q;
		self.tod_dmg_q = [];
		keys = GetArrayKeys( q );
		sent = 0;
		carried = 0;
		for ( i = 0; i < keys.size; i++ )
		{
			e = q[ keys[ i ] ];
			if ( sent >= TOD_DMGNUM_BURST )
			{
				// Next frame's business — and if that zombie was hit again
				// meanwhile, the two stay one number for one zombie.
				late = self.tod_dmg_q[ keys[ i ] ];
				if ( isdefined( late ) )
				{
					late.dmg += e.dmg;
					if ( IS_TRUE( e.head ) ) late.head = true;
					if ( IS_TRUE( e.red ) ) late.red = true;
					if ( IS_TRUE( e.burn ) ) late.burn = true;   // same key = same lane, so this only ever restates it
				}
				else
					self.tod_dmg_q[ keys[ i ] ] = e;
				carried++;
				continue;
			}
			self send_dmg_num( e );
			sent++;
		}
		if ( keys.size > 1 || carried > 0 )
			dmgnum_log( "FLUSH player=" + self GetEntityNumber() + " zombies=" + keys.size + " sent=" + sent + " carried=" + carried );
		if ( self.tod_dmg_q.size == 0 )
			break;
		wait TOD_DMGNUM_WINDOW;
	}
	self.tod_dmg_acc_on = false;
}

// One number, one event. LOCKSTEP with the tod_dmg subscription in
// tod_upgrade.lua: arg 1 = the exact amount (capped at the seven-glyph pool),
// arg 2 = flags, bit 1 headshot, bit 2 reduced, bit 3 burn (v19.50; the Lua
// paints burn ORANGE and burn wins over red and headshot). History of the retired
// clientfield encoding (tens -> hundreds -> hundreds/thousands with a scale
// bit, caps 2,047 -> 20,470 -> 204,700 -> 2,047,000): CHANGELOG v17.64 and
// 2026-09-09. None of that rounding applies any more; the number is exact.
function send_dmg_num( e )
{
	dmg = int( e.dmg );
	if ( dmg > TOD_DMGNUM_CAP )
		dmg = TOD_DMGNUM_CAP;
	if ( dmg < 1 )
		dmg = 1;
	flags = 0;
	if ( IS_TRUE( e.head ) )
		flags += 1;
	if ( IS_TRUE( e.red ) )
		flags += 2;
	if ( IS_TRUE( e.burn ) )
	{
		flags += 4;
		// Dev evidence the orange lane fired, throttled to one line per player
		// per 5 s — a trail across a train would otherwise print every tick.
		if ( !isdefined( self.tod_dmg_burn_log_ms ) || GetTime() - self.tod_dmg_burn_log_ms >= 5000 )
		{
			self.tod_dmg_burn_log_ms = GetTime();
			dmgnum_log( "BURN player=" + self GetEntityNumber() + " dmg=" + dmg + " flags=" + flags );
		}
	}
	self LuiNotifyEvent( &"tod_dmg", 2, dmg, flags );
}

// PUBLIC — the finale road banner. self = player. on/off only; the blinking is
// the Lua's job (CoD.TodFinaleWarn in tod_upgrade.lua), so a 90-second warning
// costs exactly two network writes.
// EVERY PANEL CLEARS ON end_game (audit 2026-08-25). todUpgShow is only zeroed
// on the NORMAL exit of a card pick, and the HEAVENLY GIFT ALTAR deliberately
// does NOT pause the world — so a wipe, or the finale ending, while a card was
// up left the panel frozen over the game-over screen. Same class of bug as the
// finale banner leak, and the same shape of fix: one thread with NO endon, so
// it is guaranteed to run on every exit path including ones added later.
// THE PAUSE MENU'S GAME TIME, IN THE MAP'S TYPEFACE (v19.59b, user 2026-09-27:
// "Make sure you dont miss anything"). The kit drew it with UIText
// setupServerTime - an engine clock whose text Lua can never read, so it was the
// last engine-font line in the pause menu. Once a second every player is sent
// the whole seconds since stock's own level.n_gameplay_start_time (the same
// origin the stock clientfield game_start_time hands that clock, _zm.gsc:630).
// The HUD caches it (CoD.TodGameSecs) so the menu has a value the instant it
// opens; a solo pause freezes the server, and with it the clock - as before.
// One int per player per second on the proven scriptNotify lane.
function game_time_push()
{
	level endon( "end_game" );
	while ( !isdefined( level.n_gameplay_start_time ) )
		wait 0.5;
	for ( ;; )
	{
		secs = Int( ( GetTime() - level.n_gameplay_start_time ) / 1000 );
		if ( secs < 0 )
			secs = 0;
		foreach ( p in GetPlayers() )
		{
			if ( !( p IsTestClient() ) )
				p LuiNotifyEvent( &"tod_game_time", 1, secs );
		}
		wait 1;
	}
}

function clear_ui_on_end()
{
	level waittill( "end_game" );
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p set_field( "todUpgShow", 0 );
		p set_field( "todClsShow", 0 );
		p set_field( "todUpgHold", 0 );
		p set_finale_warn( false );
	}
}

function set_finale_warn( on )
{
	v = 0;
	if ( IS_TRUE( on ) )
		v = 1;
	self clientfield::set_player_uimodel( "todFinaleWarn", v );
}

// PUBLIC — RAMPAGE INDUCER (v14.20). self = player. Flips that player's luck
// bar between the amber set and the red/purple one. _tod_rampage.gsc is the
// only caller and the only writer of level.tod_rampage_on.
//
// PUSHED ON EVERY SPAWN, not just on toggle: the engine closes a player's LUI
// menus on death -> spectate and the HUD is rebuilt per life, so a
// toggle-only push would leave a revived player looking at an amber bar in a
// rampaged match. Same per-life re-assert discipline the rest of this file
// uses (aetherium-and-upgrade-input memory).
function set_rampage( on )
{
	v = 0;
	if ( IS_TRUE( on ) )
		v = 1;
	self clientfield::set_player_uimodel( "todRampage", v );
}

// DEAD SINCE 2026-08-20 (the virtual mag pool was deleted) — kept only so the
// Lua's MagChip subscription has a model. The field is 1 bit now (2026-08-22);
// never push anything but 0 through it.
function set_mag_bonus( n )   // self = player
{
	if ( n > 1 )
		n = 1;
	self clientfield::set_player_uimodel( "todMagBonus", n );
}

// self = player. Open the always-on overlay once (additive — cannot break the
// stock HUD; the widget stays invisible until todUpgShow goes nonzero).
function ensure_menu()
{
	if ( !isdefined( self.tod_upg_menu ) )
		self.tod_upg_menu = self OpenLUIMenu( "tod_upgrade" );
}

// ---------------------------------------------------------------------------
// PER-LIFE OVERLAY REBUILD (live report 2026-08-26: "when you get finished and
// you spectate your team and respawn half of the UI go away ... you can't
// choose the upgrade ... can't see the luck ... can't see where are you in
// the map").
//
// THE ENGINE CLOSES A PLAYER'S OpenLUIMenu MENUS ON THE DEATH -> SPECTATE
// TRANSITION, and ensure_menu()'s handle guard reads self.tod_upg_menu — a
// SERVER-side field that transition never clears — so after a respawn the
// guard was permanently satisfied and the menu never reopened. The player
// lost the entire tod_upgrade overlay for the rest of the match: upgrade
// cards, luck bar, tower gauge, damage numbers, finale banner — exactly the
// list in the report. (The upgrade EVENTS still ran server-side; the player
// was choosing blind.)
//
// This is map 1's fix ported (_acc_lui::player_lui_init; its user report
// 2026-06-24 was the same bug: "drops + perks don't show after a player dies
// and respawns"): reopen once per LIFE, then re-arm every change-gated feed
// so it re-pushes CURRENT state into the just-opened menu. Map 1 proved both
// halves: a value that hasn't changed since its last push never repaints a
// fresh menu on its own, and a same-value set_player_uimodel re-set DOES
// repaint once the GSC-side change tracker is cleared. "spawned_player"
// fires on the initial spawn AND every co-op respawn (stock _zm.gsc notify),
// so one loop covers both.
//
// The Aetherium kit needs none of this: it replaces T7Hud_zm_factory, the
// stock HUD menu, whose lifecycle the engine itself re-runs per spawn. The
// class-draft menu (tod_class_select) is round-1-once in a paused world and
// is never needed again, so it is deliberately not rebuilt here.
// ---------------------------------------------------------------------------
// PUBLIC - a HUD toast in the map's typeface. self = the player who sees it.
// id is a TOD_TOAST_* (_tod_toast.gsh); a / b fill the row's {A} / {B}.
// Replaces IPrintLnBold for the map's own notices: that draws in the engine font.
function toast( id, a, b )
{
	if ( !isdefined( a ) )
		a = 0;
	if ( !isdefined( b ) )
		b = 0;
	self LuiNotifyEvent( &"tod_toast", 3, id, a, b );
}

// PUBLIC - the same toast to every player.
function toast_all( id, a, b )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isdefined( players[ i ] ) && IsPlayer( players[ i ] ) )
			players[ i ] toast( id, a, b );
	}
}

// PUBLIC - who is still choosing an upgrade card, as a bitmask of entity
// numbers (bit n = client n). 0 hides the line. The Lua looks the names up in
// its own PlayerList models, so no name string ever crosses the wire.
function choosing_push( mask )   // self = viewer
{
	self LuiNotifyEvent( &"tod_choosing", 1, mask );
}

function on_player_connect()
{
	self thread player_lui_life();
	self thread scoreboard_watch();
}

// ---------------------------------------------------------------------------
// THE SCOREBOARD WINS OVER A CENTRE BANNER (2026-09-27, tester Nikolai: the
// EXTRACT OR ASCEND plate sat on top of the scoreboard's upgrades panel; the
// user: "only one can be up at a time ... hide the other while another is
// triggered by player"). The board is the one the PLAYER asked for, so while it
// is open this player's centre banners step aside, and come back when it
// closes. The map HUD already hides under the board (tod_upgrade.lua); these
// banners are SERVER hudelems, which cannot read the client's scoreboard bit,
// so AetheriumScoreboard.lua sends "tod_sb|1" / "tod_sb|0" on the stock
// StartMenu_Main response lane (precached by stock _zm.gsc; the third-person
// toggle rides the same menu name). Unknown responses are ignored by stock.
//
// HIDDEN BY X, NOT ALPHA: every banner owns its own alpha (fade in, timed fade
// out) and a second alpha writer would fight it; nothing moves a banner's x.
// If the response never arrives the banner simply stays up - today's behaviour.
// Dev log `[TOD_SB]` (tod_dev): OPEN / CLOSE with the banners moved, TRACK.
// ---------------------------------------------------------------------------
function sb_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_SB] ms=" + GetTime() + " " + msg;
	/# PrintLn( line ); #/
}

// PUBLIC - register a centre banner hudelem. self = the player who sees it.
function banner_track( e )
{
	if ( !isdefined( e ) )
		return;
	kept = [];
	if ( isdefined( self.tod_banners ) )
	{
		for ( i = 0; i < self.tod_banners.size; i++ )
		{
			if ( isdefined( self.tod_banners[ i ] ) )
				kept[ kept.size ] = self.tod_banners[ i ];
		}
	}
	e.tod_banner_x = e.x;
	kept[ kept.size ] = e;
	self.tod_banners = kept;
	if ( IS_TRUE( self.tod_sb_open ) )
		e.x = TOD_BANNER_HIDE_X;
	sb_log( "TRACK ent=" + self GetEntityNumber() + " live=" + kept.size + " board_open=" + IS_TRUE( self.tod_sb_open ) );
}

// self = player. Returns how many live banners were moved.
function banners_apply()
{
	n = 0;
	if ( !isdefined( self.tod_banners ) )
		return n;
	for ( i = 0; i < self.tod_banners.size; i++ )
	{
		b = self.tod_banners[ i ];
		if ( !isdefined( b ) )
			continue;
		if ( IS_TRUE( self.tod_sb_open ) )
			b.x = TOD_BANNER_HIDE_X;
		else if ( isdefined( b.tod_banner_x ) )
			b.x = b.tod_banner_x;
		n++;
	}
	return n;
}

// self = player. One plain waittill loop for the whole connection.
function scoreboard_watch()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "menuresponse", menu, response );
		if ( !isdefined( menu ) || !isdefined( response ) || menu != TOD_SB_MENU )
			continue;
		parts = StrTok( response, "|" );
		// v19.60 DEV: the pause menu reports what the keyboard key-name lookup
		// returned (AetheriumStartMenu TodKeyDiag). Log only; nothing acts on it.
		if ( parts.size >= 2 && parts[ 0 ] == "tod_keydiag" )
		{
			if ( IS_TRUE( level.tod_dev ) )
			{
				line = "[TOD_KEYS] ms=" + GetTime() + " ent=" + self GetEntityNumber() + " " + response;
				/# PrintLn( line ); #/
			}
			continue;
		}
		if ( parts.size < 2 || parts[ 0 ] != TOD_SB_KEY )
			continue;
		open = ( parts[ 1 ] == "1" );
		if ( open == IS_TRUE( self.tod_sb_open ) )
			continue;
		self.tod_sb_open = open;
		n = self banners_apply();
		sb_log( ( ( open ) ? "OPEN" : "CLOSE" ) + " ent=" + self GetEntityNumber() + " banners_moved=" + n );
	}
}

function player_lui_life()
{
	self endon( "disconnect" );
	level flag::wait_till( "initial_blackscreen_passed" );

	b_first = true;
	for ( ;; )
	{
		// Respawns need a beat for the fresh client HUD to settle before the
		// reopen lands (map 1's 0.5s). Match start opens near-instantly so
		// the overlay is up the moment the fade lifts.
		if ( b_first )
			wait 0.05;
		else
			wait 0.5;
		b_first = false;

		if ( isdefined( self.tod_upg_menu ) )
			self CloseLUIMenu( self.tod_upg_menu );
		self.tod_upg_menu = undefined;
		self ensure_menu();
		wait 0.1;   // let the menu instantiate client-side before data lands

		// v16.3 — re-tell the fresh HUD Lua which device this player has proved
		// (pad_latch). CoD.TodPad is a client-VM global and normally survives
		// the rebuild; the resend is one int and closes the case where the
		// first d-pad press beat the first menu.
		if ( IS_TRUE( self.tod_input_pad ) )
			self LuiNotifyEvent( &"tod_input_pad", 1, 1 );

		// Re-arm the change-gated feeds so each re-pushes into the new menu:
		// the tower gauge + boss pip + max-HP lanes (_tod_gauge's 0.35s loop
		// re-sends the moment its per-player trackers read undefined) ...
		self.tod_gauge_f = undefined;
		self.tod_gauge_bf = undefined;
		self.tod_gauge_mh = undefined;
		// ... including the v14.50 DOWNED-TEAMMATE cells, which need this more
		// than any other feed on the list: a player who just bled out and
		// respawned is precisely the one whose teammates are likely to be down
		// RIGHT NOW, and that mask only pushes when it CHANGES. Without these
		// two the fresh HUD would show no red until somebody else went down or
		// got picked up — a marker missing at the exact moment it matters.
		self.tod_gauge_dlo = undefined;
		self.tod_gauge_dhi = undefined;
		// ... the spire's upper down cells (tod_down2) and THE MODE itself
		// (docs/71): a fresh menu boots as the tower instrument, so on the
		// spire it must be told to swap BEFORE the re-pushed floor lands —
		// _tod_gauge sends the mode first within a tick.
		self.tod_gauge_d2lo = undefined;
		self.tod_gauge_d2hi = undefined;
		self.tod_gauge_mode = undefined;
		// ... and the ROUND READOUT (v17.25). THIS ONE IS NOT FOR THIS MENU.
		// tod_round is drawn by AetheriumRoundCounter, which lives in the KIT
		// HUD — the menu the header above says needs none of this, because the
		// engine re-runs its lifecycle per spawn. That is exactly the problem:
		// the engine rebuilds the widget, and a change-gated feed then says
		// nothing to it until the round flips, which can be minutes. A fresh
		// counter reading ROUND 1 in round 40 is the failure. The re-arm rides
		// here because "spawned_player" is already what this loop waits on, and
		// _tod_gauge re-sends within one 0.35s tick of the tracker going
		// undefined.
		self.tod_round_shown = undefined;
		// ... and the PACK-A-PUNCH TIER BADGE (v17.33), for the same reason and
		// with the same owner. It lives in AetheriumLoadout — the KIT HUD,
		// rebuilt by the engine on every spawn — and its feed only pushes on
		// change, so without this a respawning player's badge would read
		// UNPACKED until they next switched weapons or bought a tier. A player
		// who just bled out holding a 50,000-point PACK III gun is precisely
		// who notices.
		self.tod_pap_tier_shown = undefined;
		// ... and the WARDEN KING'S BOSS BAR (v19.76), same owner, same reason:
		// tod_upgrade.lua is rebuilt per life and its on/off is change-gated.
		self.tod_king_bar_shown = undefined;
		// ... and the luck bar, whose pushes only ride luck CHANGES —
		// re-assert the current value directly. The upgrade cards need
		// nothing (every event re-sets its fields from scratch, todUpgShow
		// 0->1 included) and the finale banner's blink re-pushes all players
		// every cycle, so both self-heal.
		pct = 0;
		if ( isdefined( self.tod_luck_bar ) )
			pct = self.tod_luck_bar;
		self set_luck_pct( pct );

		self waittill( "spawned_player" );   // next death -> respawn: rebuild
	}
}

// domain key -> the Lua DOMAIN table id (MUST mirror tod_upgrade.lua AND the
// register_domains order in _tod_upgrades.gsc). v4 matrix 2026-08-19.
function domain_id( key )
{
	switch ( key )
	{
		case "damage":     return 1;
		case "dr":         return 2;    // DMG REDUCTION — v16: DIMINISHING ladder 6/11/15/18/20% cumulative (was flat 5%/Lv to 25%) and S -> A band. The two boss lanes CALL tod_upgrades::dr_mult() now; they used to carry hand-copied literals
		case "bounty":     return 3;
		case "luck":       return 4;
		case "sprint":     return 5;    // SPRINT — v16: A -> S band (user: "sprint needs to be moved to S tier"), so weight 50 -> 20 and the SUPER/ULTIMATE slice x0.75 -> x0.50. Ladder unchanged (speed_pct_for_level)
		case "headshot":   return 6;
		case "magsize":    return 7;    // MAG SIZE — 2026-09-02: A -> S band (user: "We need to move mag size upgrade to s tier"), so weight 50 -> 20 and the SUPER/ULTIMATE slice x0.75 -> x0.50. Ladder untouched (MAG_STEP), so the card art stands
		case "reserve":    return 8;
		case "mobility":   return 9;
		case "bulletfeed": return 10;
		case "echo":       return 11;
		case "regen":      return 12;
		case "leech":      return 13;
		case "cleave":     return 14;
		case "firerate":   return 15;
		case "handling":   return 16;
		case "recoil":     return 17;
		case "knifespeed": return 18;
		case "penetration": return 19;
		case "thunder":     return 20;
		case "sprintfire":  return 21;
		case "lunge":       return 22;   // CHAIN LUNGE (2026-08-22)
		case "runandgun":   return 23;   // RUN AND GUN (2026-08-22) — skirmisher ammo saver
		// CLASS TIERS (docs/25, 2026-08-22). The field is 6 bits now (1..63).
		case "tier":        return 24;   // the TIER card — AL/BL carry (class-1)*2 + (tier-2)
		case "adrenaline":  return 25;   // MP5  (skirmisher T2) — kills grant a speed burst
		case "overdrive":   return 26;   // Death Machine (heavy T3, moved off the MP7 2026-08-23)
		case "killreload":  return 27;   // KILL RELOAD — REMOVED 2026-09-01 (user: "No one likes it"); id stays mapped, same form as 28 below
		case "impact":      return 28;   // ASSAULT, any gun (un-bound from the AK-47 2026-08-23)
		case "suppress":    return 29;   // HK21 (heavy T2)      — hits slow the horde
		case "grinder":     return 30;   // Death Machine (heavy T3) — keep firing, hit harder
		case "drawcut":     return 31;   // Wakizashi (slasher T2) — swings out of a sprint hit harder
		case "sprintarmor": return 32;   // SPRINT ARMOR (2026-08-23) — skirmisher-only since v14.11 (slasher dropped), -5%/Lv damage while sprinting
		case "secondwind":  return 33;   // SECOND WIND (2026-08-23) — skirmisher, MP5-bound since v14.11 (was MP7), sprint to heal 1%/Lv per second
		case "momentum":    return 34;   // MOMENTUM — REMOVED v14.11 (2026-08-30); stays mapped, see the note below
		case "bossdmg":     return 35;   // GIANT SLAYER (2026-08-23, v9.45) — assault, +15%/Lv vs the boss/elite triad (3->4->5->8->15 in nine days; 15 since v15, 2026-08-31)
		case "backarmor":   return 36;   // BACK ARMOR (2026-08-23, v9.45) — heavy-only since v14.11 (assault dropped); v16 max 3 -> 5 on the shared ladder5(), -10/18/24/28/32% from a rear arc
		case "march":       return 37;   // FORCED MARCH (2026-08-24) — assault, AK-47-bound, +5% move speed/Lv (card art + pause plate r37 landed 2026-08-24)
		case "vitality":    return 38;   // VITALITY (v14.11) — heavy, scope class; v16 put it on ladder5() as FLAT HP: +10/18/24/28/32 (TOD_UPG_VITALITY_HP_PER_LVL is DEAD). Card art + pause plate r38 landed 2026-08-30
		case "recovery":    return 39;   // RECOVERY (v14.11) — heavy; v16 max 3 -> 5 on ladder5(), regen starts 10/18/24/28/32% sooner. Card art + pause plate r39 landed 2026-08-30
		case "perkslots":   return 40;   // PERK SLOTS — REMOVED 2026-09-03 (v16.80, user: "remove the perk limit"); id stays mapped, same form as 27 above
		case "distraction": return 41;   // DISTRACTION (v14.59; reshaped v16.49) - assault Cymbal Monkey; the level IS the carry cap (1/2/3), Max Ammo +1. Weapon lane in _tod_distraction.gsc; scope class, max 3. Art + pause plate r41 landed 2026-09-01; cards re-baked for 3 pips (docs/75)
		case "gunslinger":  return 44;   // GUNSLINGER (v16.51) — slasher; class secondary vs bosses/elites x(1 + 0.30/Lv) on top of the 2.25x class baseline, in slasher_sidearm_boss_mult. Scope class, max 5, band B. Art + pause plate r44 PENDING (docs/79): text fallbacks until then
		case "trailblazer": return 46;   // TRAILBLAZER (v16.62) — skirmisher; burning ground trail while sprinting: longer, wider, hotter per Lv (docs/80). Scope class, max 5, band A. Art PENDING (docs/83): text fallbacks
		case "athlete":     return 43;   // ATHLETE (v16) — slasher; +10% slide speed, +25% jump height and (v16.23-28) strafe-axis air steering at 120 + 60/Lv deg/s, momentum free in the front hemisphere, 35% at a reversal. Mechanic in _tod_athlete.gsc (per-player SetVelocity, never the GLOBAL SetJumpHeight). Art + pause plate r43 landed 2026-09-01
		case "riotshield":  return 45;   // RIOT SHIELD (v16.63, 2026-09-02) — UNIVERSAL; a shield that recharges after it breaks, 200..500 HP and 4:00..2:00 per level. Weapon lane in _tod_riotshield.gsc; scope class, max 5, band A. Art + pause plate r45 PENDING (docs/82): text fallbacks until then
		case "deadshot":    return 47;   // DEADSHOT — RETIRED v19.25 (2026-09-21, user: "not liked or helpful"). Shipped v16.64 as the assault's ULTIMATE-locked perma aim assist; it was GAMEPAD-ONLY (UseAlternateAimParams) so it did nothing on M+KB, and the rarity lock made it displace the rarest assault draw. add_domain, the rarity lock, _tod_deadshot.gsc|.csc, the card and the perk crest all went together. THE ID STAYS MAPPED (retired-id rule) and i_tod_pause_r47 STAYS ZONED: PAUSE_PLATE_MAX is a contiguous ceiling at 56, so unzoning r47 would cost rows 48..56 their plates
		case "lmgsprint":   return 42;   // FULL STEAM (v15) — heavy; sprint 0.8s unbroken for the speed ladder (TOD_LMGS_ARM_MS, 1500 -> 1000 -> 800 in v16). Replaced MOBILITY (id 9, retired same commit). Card art + pause plate r42 landed 2026-09-01; the three cards were re-baked the same day to the NUMBERLESS "KEEP SPRINTING FOR SPEED", so an arm-time retune no longer owes an art pass (docs/56 amendment, closed)
		// ---- THE MAGE (docs/114) -- the fifth class, BUILT AND NOT ENABLED
		// (see _tod_mage.gsh). 48 is the first free id: 1..47 are all mapped
		// above, ten of them by RETIRED domains that keep their ids on purpose.
		// The domain-id clientfields todUpgAD / todUpgBD are 6 bits = 1..63, so
		// 51 fits with twelve to spare and NO clientfield change is owed -- the
		// clientuimodel pool is at its proven ceiling and could not have paid.
		// 52 and 53 are RESERVED for LEVITATION and CONDUIT (docs/114 B.7).
		case "mage_air":    return 48;   // AIR (tier 1+) -- horde clear, long recharge. Max 6, band B. No CARD_SLUG and no pause plate (48 > PAUSE_PLATE_MAX 47): LUI text fallbacks
		case "mage_fire":   return 49;   // FIRE (tier 2+, set_tier_min) -- x2 vs panzer + protector. Max 6, band A. Text fallbacks
		case "mage_ice":    return 50;   // ICE (tier 3, set_tier_min) -- x2 vs hellhound + armored sprinter. Max 6, band A. Text fallbacks
		case "mage_heal":   return 52;   // HEALING AURA (tier 1+) — heals the caster and every teammate in the aura; Lv6 raises one downed teammate. Max 6, band A. No CARD_SLUG and no pause plate (52 > PAUSE_PLATE_MAX 47): LUI text fallbacks
		case "mage_attune": return 51;
		case "mage_bolt":   return 53;
		case "mage_arch":   return 54;
		case "mage_quickhands": return 56;
		case "thunder_smash": return 58;
		case "mage_rate":   return 57;   // RAPID FLAME (v19.25) -- the fire staff's cadence: -10% of the shot cooldown per level, 5 levels, DOUBLE the shots at Lv5. Effect lane is _tod_mage_elements::fire_recovery_ms (the DisableWeaponFire controller fire already owned). Max 5, band A, tier-min 2, no dark. 57 > PAUSE_PLATE_MAX so the pause row is TEXT, and there is no CARD_SLUG until the art lands (docs/150). Ids 58..63 are what the 6-bit todUpgAD/BD fields have left
		case "mage_blink":  return 55;   // BLINK (v18.41) -- the mage's short teleport on the tactical button. Max 5, band A. Text fallbacks; 55 > PAUSE_PLATE_MAX 52 so the pause row is TEXT
		// NOTE 51 "mage_attune" above is RETIRED (v18.41) and stays mapped: the
		// retired-id rule -- a removed domain keeps its id, only add_domain goes.   // ARCHMAGE (v18.40) -- the mana bar's payoff: bigger, longer demigod. Max 6, band S. 54 > PAUSE_PLATE_MAX 52, so the pause row is TEXT   // CHAIN LIGHTNING (v18.30) -- the lightning staff's line: +1 arc per level at half the hit. Max 6, band B. Text fallbacks (no art yet, docs/118); 53 > PAUSE_PLATE_MAX 52 so the pause row is TEXT   // ATTUNEMENT -- the class's only throughput knob: shorter cooldowns, refund on an elite kill. Max 5 on the shared ladder5(). Text fallbacks
		// NOTE "echo" (11), "regen" (12), "lunge" (22), "grinder" (30) and
		// "momentum" (34) are still mapped above even though all five domains
		// were removed (echo + grinder 2026-08-23, CHAIN LUNGE 2026-08-24,
		// regen + momentum v14.11 2026-08-30). This switch is a KEY->id map,
		// not an ordered list, so a stale case is inert and removing one would
		// only risk disturbing ids that the Lua and the pause plates depend on.
	}
	return 0;
}

function set_field( name, v )   // self = player
{
	self clientfield::set_player_uimodel( name, v );
}

// PUBLIC — live luck-bar push, 0..100 -> tens (self = player). The top-left
// luck bar is all-LUI now (tod_upgrade.lua swaps baked i_tod_luck_NN images
// on todUpgLuck);
// _tod_luck calls this on every bar change. present_choice re-sets the same
// field at event time for the card readout — same scale, no conflict.
function set_luck_pct( pct )
{
	v = int( pct / 10 );
	if ( v > 10 )
		v = 10;
	if ( v < 0 )
		v = 0;
	// v14.9 OVERCHARGE: the secret band (101..149) still clamps to the full
	// bar above — the band is invisible by design. Only the ceiling itself
	// encodes as the sentinel (11 = base zap frame; the driver animates 11..14
	// on top of this, and a refresh mid-animation snapping to 11 is harmless —
	// the next 0.15s tick re-randomizes).
	if ( pct >= TOD_UPG_LUCK_OVERMAX_PCT )
		v = 11;
	// The HUD menu hosts the luck bar — but never OpenLUIMenu pre-blackscreen
	// (the field set itself is safe anytime; the menu reads it on subscribe).
	if ( level flag::get( "initial_blackscreen_passed" ) )
		self ensure_menu();
	self set_field( "todUpgLuck", v );
}

// PUBLIC — one overcharge animation frame (self = player; f = 11..14, the
// todUpgLuck spare values). Called only by _tod_luck::overcharge_driver at
// ~7 Hz while the bar sits at the overcharge ceiling. Same blackscreen gate
// as set_luck_pct — the driver can outlive a menu (death -> per-life rebuild)
// and the field set itself is safe anytime.
function set_luck_over_frame( f )
{
	if ( f < 11 )
		f = 11;
	if ( f > 14 )
		f = 14;
	if ( level flag::get( "initial_blackscreen_passed" ) )
		self ensure_menu();
	self set_field( "todUpgLuck", f );
}

// self = player. THE REVEAL TIMELINE. Runs INSIDE present_choice's thread (not
// threaded) so the caller's endons — "disconnect", "end_game",
// "tod_solo_down_abort" — kill it exactly like they kill the rest of the flow.
// A player who goes down or disconnects mid-reveal leaves no orphan thread and
// no half-dealt panel: the abort paths already clear todUpgShow.
//
// Slot fields are written in two waves and the ORDER MATTERS. RARITY lands at
// the START of a slot's hold and DOMAIN at the END of it, separated by a real
// wait, so the two can never arrive in the same snapshot. That is what makes
// the client's "domain went 0 -> N" edge safe to read the rarity on: without
// the gap, model callbacks fire in clientfield REGISTRATION order (AD before
// AR) and the card would land wearing the previous deal's rarity for a frame.
function reveal_deal( opts )
{
	sc = 1.0;
	if ( !IS_TRUE( level.tod_upgrade_pause ) )
		sc = TOD_REVEAL_LIVE_SCALE;

	// WHICH SIDE(S) HOLD AN ULTIMATE — decided from reveal_rarity, not raw
	// rarity, so a floor-gated tier card (which carries rarity 3 but cannot be
	// taken) does not summon an aura for a card the player is not allowed.
	ult_a = ( reveal_rarity( opts[ 0 ] ) >= 3 );
	ult_b = ( isdefined( opts[ 1 ] ) && reveal_rarity( opts[ 1 ] ) >= 3 );

	// DARK UPGRADES (v17.10): a dark card OUTRANKS the heavenly pad — it is the
	// rarer thing on screen and the two must never sound at once. Decided here,
	// once, from the whole hand rather than per slot, because the dark pad is
	// centred: it is one 7.8s piece about the deal, not a side-panned halo about
	// a socket.
	dark_deal = ( IS_TRUE( opts[ 0 ].dark ) || ( isdefined( opts[ 1 ] ) && IS_TRUE( opts[ 1 ].dark ) ) );
	if ( dark_deal )
	{
		ult_a = false;
		ult_b = false;
	}

	self PlayLocalSound( "tod_deal_open" );
	wait( TOD_REVEAL_OPEN * sc );

	self reveal_slot( "A", opts[ 0 ], sc );
	// A lone ultimate starts its aura the moment its own card lands. A DOUBLE
	// ultimate deliberately waits for the second — one bigger, centred aura for
	// the pair rather than two overlapping halves, and it arrives as the choice
	// itself becomes the thing worth agonising over.
	if ( dark_deal )
		self thread dark_aura();
	else if ( ult_a && !ult_b )
		self thread ultimate_aura( "tod_upg_aura_l" );

	if ( isdefined( opts[ 1 ] ) )
	{
		wait( TOD_REVEAL_GAP * sc );
		self reveal_slot( "B", opts[ 1 ], sc );

		if ( ult_a && ult_b )
			self thread ultimate_aura( "tod_upg_aura_both" );
		else if ( ult_b )
			self thread ultimate_aura( "tod_upg_aura_r" );
	}
	// NO SEPARATE DOUBLE-ULTIMATE FANFARE. The overcharge deal (150% luck,
	// docs/45) already announces itself with TWO ultimate stings ~0.9s apart,
	// which no other deal in the game can produce — a third sound on top would
	// be a whole authored asset earning nothing the pair does not already say.
	// If it is ever wanted back it is one alias and one line, right here.

	wait( TOD_REVEAL_TAIL * sc );
}

// self = player. THE ULTIMATE AURA DRIVER — the heavenly altar's own pad,
// pre-panned to the side its card is on, retriggered per-player until the panel
// is done with it. See the TOD_AURA_* block for why this is a retrigger and not
// a loop, and why the panning lives in the wav.
//
// FOUR WAYS OUT, and it needs all of them: the panel is torn down on more paths
// than it is closed on. "tod_upg_aura_stop" is the normal one (present_choice
// notifies it after the pick); the other three are the aborts that kill
// present_choice's own thread mid-flight — a disconnect, a solo player going
// down at the station, and a round event seizing the panel from a station buy.
// If present_choice dies, its cleanup never runs, so the driver cannot rely on
// being told. The pass ceiling is the last resort: even with every endon
// missed, it stops on its own.
function ultimate_aura( alias )
{
	self endon( "disconnect" );
	self endon( "tod_upg_aura_stop" );
	self endon( "tod_solo_down_abort" );
	level endon( "tod_global_upg_takeover" );
	level endon( "end_game" );

	for ( i = 0; i < TOD_AURA_MAX_PASSES; i++ )
	{
		self PlayLocalSound( alias );
		wait TOD_AURA_UNIT_SECS;
	}
}

// self = player. THE DARK PAD (v17.10) — the same retrigger contract as
// ultimate_aura and DELIBERATELY a separate function rather than an argument on
// it, because the unit length is a property of the WAV and the two assets are
// different lengths. It needs the identical four ways out: the panel is torn
// down on more paths than it is closed on, and if present_choice dies its
// cleanup never runs, so this thread cannot rely on being told.
//
// Centred, not panned: unlike the heavenly pad there is no _l/_r pair, because a
// dark upgrade is a singular event about the deal rather than a halo on one
// socket. If pans are ever wanted, they are one alias each and a slot argument.
function dark_aura()
{
	self endon( "disconnect" );
	self endon( "tod_upg_aura_stop" );
	self endon( "tod_solo_down_abort" );
	level endon( "tod_global_upg_takeover" );
	level endon( "end_game" );

	for ( i = 0; i < TOD_DARK_AURA_MAX_PASSES; i++ )
	{
		self PlayLocalSound( "tod_dark_aura" );
		wait TOD_DARK_AURA_UNIT_SECS;
	}
}

// The rarity this option is REVEALED at, which is not always the rarity it was
// rolled at. A floor-gated CLASS TIER card carries rarity 3 (see
// _tod_upgrades::make_tier_option) but cannot be taken — giving it the full
// ultimate build-up and then refusing the pick is a tease, not a reward, so a
// locked slot always reveals as a plain regular: quick, quiet, no riser.
function reveal_rarity( o )
{
	if ( IS_TRUE( o.locked ) )
		return 1;
	return o.rarity;
}

// self = player. One slot's beat: hold empty (longer the rarer), then land.
function reveal_slot( slot, o, sc )
{
	rar = reveal_rarity( o );

	hold = TOD_REVEAL_HOLD_REG;
	if ( rar == 2 )
		hold = TOD_REVEAL_HOLD_SUPER;
	else if ( rar >= 3 )
		hold = TOD_REVEAL_HOLD_ULT;

	// WAVE 1 — the socket learns what is coming and starts its colour ramp.
	self set_field( "todUpg" + slot + "R", rar );
	// DARK UPGRADES (v17.10): the LEVEL field carries the sentinel instead of the
	// player's current level, and that is what tells the Lua to draw the dark
	// card art. Safe because levels top out at 10, and free because it spends no
	// clientfield bits — the pool has one left. Losing `o.cur` here costs
	// nothing: a dark card is dealt on a MAXED domain, so its pip row is full by
	// definition and the card art already has every pip lit.
	if ( IS_TRUE( o.dark ) )
		self set_field( "todUpg" + slot + "L", TOD_UPG_DARK_L );
	else
		self set_field( "todUpg" + slot + "L", o.cur );
	// ONE RISER FOR BOTH RARITIES, not two. The HOLD is what separates them and
	// it already does the work: authored at 0.6s it completes exactly as an
	// ULTIMATE lands, and a SUPER's shorter 0.4s hold CUTS IT OFF mid-sweep. So
	// the ultimate is the only build the player ever hears resolve, which is
	// the whole tell — bought with one asset instead of two.
	if ( rar >= 2 )
		self PlayLocalSound( "tod_reveal_charge" );

	// THE STING JUMPS THE CARD by its own lead (see TOD_REVEAL_LEAD_* above —
	// the value is a property of the WAV, not of the rarity). The hold splits
	// around it: hold-lead, sting, lead, card.
	//
	// THE SPLIT CANNOT THREATEN THE SNAPSHOT GUARANTEE, and it is worth being
	// exact about why: what the client's "domain went 0 -> N" edge depends on
	// is that the RARITY and DOMAIN pushes land in different snapshots, and the
	// distance between those two is the WHOLE hold (hold * sc) no matter where
	// the sting falls inside it. Splitting the wait moves a SOUND, not a push.
	// This stays true even at lead == hold (super's current case), where the
	// first wait vanishes entirely and the sting fires on the rarity frame.
	// The tightest case is a REGULAR at the station — 0.05 * 0.5, which GSC
	// rounds up to one server frame, still two distinct snapshots.
	sting = "tod_card_land";
	lead  = 0;
	if ( rar >= 3 )
	{
		sting = "tod_ultimate_sting";
		lead  = TOD_REVEAL_LEAD_ULT;
	}
	else if ( rar == 2 )
	{
		sting = "tod_super_sting";
		lead  = TOD_REVEAL_LEAD_SUPER;
	}

	// Guarded rather than `wait( (hold-lead) * sc )` because a lead is allowed
	// to equal — or exceed — its hold, and a negative wait is not a thing.
	if ( hold > lead )
		wait( ( hold - lead ) * sc );

	self PlayLocalSound( sting );

	if ( lead > 0 )
		wait( lead * sc );

	// WAVE 2 — the card itself.
	self set_field( "todUpg" + slot + "D", domain_id( o.domain ) );
}

// ---------------------------------------------------------------------------
// THE LEVEL PIPS (docs/172, user 2026-10-04: "players arent really aware of
// what basic, super, and ultimate even mean ... shows all the levels of that
// upgrade, fills in the level you are and then shows what the upgrade will
// take you"). tod_upgrade.lua draws one pip per level on every dealt card: the
// levels the player owns, the levels THIS card adds (pulsing, in the rarity's
// colour), the rest empty.
//
// The card already carries the CURRENT level (todUpgAL/BL). What it lacks is
// the player's real CAP (domain_max: per class - DMG REDUCTION is 3 / 5 / 9 / 10)
// and how many levels the card truly PAYS (o.levels: the headroom clamp, and the
// rarity lock that deals MYSTICAL HANDS as an ULTIMATE paying 1). Both ride ONE
// int per slot on the int-only event lane - zero clientfield bits (the pool is
// at 61 of 61) - sent before the panel opens, so it is in hand ~0.2 s before the
// first card lands. LOCKSTEP with tod_upgrade.lua's tod_upg_pips decode:
//   code = domain_id * 256 + max * 16 + levels      (0 = no card in that slot)
// The domain id rides along so a late or stale value can never paint another
// card's pips. A dark card sends levels 0 and the Lua skips it (its art keeps
// its own baked row); a TIER card sends tier_max / 1.
// Dev log `[TOD_CARD_PIPS] DEAL a= b=` (tod_dev).
function pips_code( o )
{
	if ( !isdefined( o ) || !isdefined( o.domain ) )
		return 0;
	mx = 0;
	if ( isdefined( o.max ) )
		mx = int( o.max );
	lv = 0;
	if ( isdefined( o.levels ) )
		lv = int( o.levels );
	if ( mx < 0 ) mx = 0;
	if ( mx > 15 ) mx = 15;
	if ( lv < 0 ) lv = 0;
	if ( lv > 15 ) lv = 15;
	return domain_id( o.domain ) * 256 + mx * 16 + lv;
}

function pips_push( opts )   // self = player
{
	a = pips_code( opts[ 0 ] );
	b = pips_code( opts[ 1 ] );
	self LuiNotifyEvent( &"tod_upg_pips", 2, a, b );
	if ( IS_TRUE( level.tod_dev ) )
	{
		pn = self GetEntityNumber();
		line = "[TOD_CARD_PIPS] ms=" + GetTime() + " DEAL player=" + pn
			+ " a=" + pips_desc( opts[ 0 ] ) + " b=" + pips_desc( opts[ 1 ] );
		/# PrintLn( line ); #/
	}
}

// key / cur -> cur+levels of max, rarity (dev log only). Every field is
// guarded: a string + undefined throws, and a log line must never break a deal.
function pips_desc( o )
{
	if ( !isdefined( o ) || !isdefined( o.domain ) )
		return "none";
	cur = "?";
	if ( isdefined( o.cur ) )
		cur = "" + o.cur;
	lv = "?";
	if ( isdefined( o.levels ) )
		lv = "" + o.levels;
	mx = "?";
	if ( isdefined( o.max ) )
		mx = "" + o.max;
	rar = "?";
	if ( isdefined( o.rarity ) )
		rar = "" + o.rarity;
	s = o.domain + "/lv" + cur + "+" + lv + "of" + mx + "/r" + rar + "/code" + pips_code( o );
	if ( IS_TRUE( o.dark ) )
		s = s + "/dark";
	if ( IS_TRUE( o.locked ) )
		s = s + "/locked";
	return s;
}

// self = player. opts = array of 1-2 option structs (see _tod_upgrades).
// Returns 1 or 2.
function present_choice( opts, timeout )
{
	self endon( "disconnect" );

	self ensure_menu();

	// docs/172: each card's real cap + levels paid, ahead of the cards (see pips_push).
	self pips_push( opts );

	// ---- THE DEAL (v14.52) -------------------------------------------------
	// Cards no longer appear finished. The panel opens on two EMPTY SOCKETS and
	// each slot lands on its own beat — see reveal_deal below for the whole
	// timeline and the field contract it rides.
	//
	// LEVEL is pushed up front (it is invisible until the card lands and the
	// Lua needs it in hand when the domain edge fires). RARITY is pushed as 1
	// up front — "a card is coming here", NOT its true rarity — and re-pushed
	// with the truth at that slot's hold. DOMAIN stays 0 until the card lands;
	// the 0 -> N edge IS the client's "deal this card now" trigger.
	self set_field( "todUpgAD", 0 );
	self set_field( "todUpgAR", 1 );
	self set_field( "todUpgAL", opts[ 0 ].cur );

	self set_field( "todUpgBD", 0 );
	if ( isdefined( opts[ 1 ] ) )
	{
		// BR >= 1 with BD == 0 is what tells the Lua a SECOND socket exists.
		// A single-card deal leaves BR at 0 and draws one socket, which is why
		// this pair must be written on BOTH branches — a stale BR from the last
		// deal would otherwise hang an empty socket on a one-card event.
		self set_field( "todUpgBR", 1 );
		self set_field( "todUpgBL", opts[ 1 ].cur );
	}
	else
	{
		self set_field( "todUpgBR", 0 );
	}

	// Card readout = the LUCK BAR in tens (0..10 -> "LUCK n0%" in the Lua).
	luck = 0;
	if ( isdefined( self.tod_luck_bar ) )
		luck = int( self.tod_luck_bar / 10 );
	if ( luck > 10 )
		luck = 10;
	self set_field( "todUpgLuck", luck );

	// FOCUS 0 WHILE SHOW IS 1 IS THE REVEAL STATE, and it is unreachable any
	// other way: every other path that sets show=1 sets focus 1..4 in the same
	// breath, and wait_for_choice never writes 0. The Lua keys its whole reveal
	// mode off that pair, so this ordering is a CONTRACT, not an accident.
	self set_field( "todUpgFocus", 0 );
	self set_field( "todUpgTime", int( timeout ) );
	self set_field( "todUpgHold", 0 );
	self.tod_upg_hold_shown = 0;
	self set_field( "todUpgShow", 1 );

	self reveal_deal( opts );

	self set_field( "todUpgFocus", 1 );   // left card focused by default

	// The freeze is the CALLER's job now (tod_upgrades::menu_freeze — the
	// soft-freeze: FreezeControls kills ALL input reads, live-test 2026-08-19).

	// THE LOCKED SLOT (v14.39). A CLASS TIER card dealt below its floor gate is
	// shown but cannot be taken — see _tod_upgrades::make_tier_option. Only the
	// RIGHT slot can ever be locked, which is what makes this safe: focus starts
	// on the left card and a timeout locks whatever is focused, so a fully
	// unselectable panel is impossible by construction. (roll_options refuses to
	// deal a lone locked card for the same reason.)
	// v16.79 — the domain test is belt and braces: only make_tier_option and
	// solo_refresh_option ever write .locked, both on the tier struct, and both
	// redeal paths skip the tier card, so nothing else can carry the flag. A
	// lock on anything but the promotion would be a bug; this makes it a
	// non-event instead of a card the player cannot reach.
	locked = 0;
	if ( isdefined( opts[ 1 ] ) && IS_TRUE( opts[ 1 ].locked ) && opts[ 1 ].domain == "tier" )
		locked = 2;

	self.tod_upg_timed_out = false;
	choice = self wait_for_choice( opts, timeout, locked );

	// THE AURA STOPS THE INSTANT THE CHOICE IS MADE, not when the panel hides.
	// It is a retrigger, so what this actually stops is the NEXT pass — the
	// current one plays out, bounded by TOD_AURA_UNIT_SECS, and the 0.7s confirm
	// flash below covers most of that tail. Notifying unconditionally (rather
	// than only when an ultimate was dealt) costs nothing and cannot leave a
	// driver running because a rarity check drifted.
	self notify( "tod_upg_aura_stop" );

	// confirm flash (Lua: chosen card teal, other recedes), then hide
	self set_field( "todUpgFocus", 0 );
	self set_field( "todUpgTime", 0 );
	self set_field( "todUpgShow", ( ( choice == 1 ) ? 2 : 3 ) );
	wait 0.7;
	self set_field( "todUpgShow", 0 );

	return choice;
}

// self = player. MENU-style input (user 2026-08-18): a card is ALWAYS focused
// (left by default, blinking); switch focus with D-PAD LEFT/RIGHT (actionslot
// 3/4), the MOVE STICK / strafe keys, or AIM/FIRE as fallbacks; HOLD JUMP (A /
// space) for 0.5s to lock the focused card in (blink speeds up while held).
// Timeout locks whatever is focused. Controls are frozen — none of these
// inputs leak into gameplay.
// `locked` (v14.39) = a slot index that must never receive focus (0 = none;
// only ever 2, see present_choice). Enforced at the ONE place every input lane
// converges — the `want` -> `sel` commit below — rather than in each of the
// seven lanes that can produce a `want`, so a lane added later cannot bypass it.
// v16.3 — THE DEVICE LATCH NOW ALSO TELLS THE CLIENT (repo review 2026-09-01).
// Both LUI menus used to GUESS the device with Engine.IsGamepadEnabled( 0 ) and
// fell back to CONTROLLER wording, so keyboard players read "HOLD A" — four
// Workshop reports, the last one after the 08-24 keyboard fix. The only
// device-proving input the server has is the d-pad press that arms
// tod_input_pad (see the latch note in wait_for_choice), so the menus now
// default to the KEYBOARD plates (PC-only mod) and flip to the pad plates when
// this fires — over the same zero-bit int-notify lane as tod_upg_sync, so no
// clientfield bit is spent. Sent ONCE per player (the latch is one-way); the
// per-life reopen in player_lui_life resends it. _tod_class_select inlines the
// same three lines (it does not import this module).
function pad_latch()   // self = player
{
	if ( IS_TRUE( self.tod_input_pad ) )
		return;
	self.tod_input_pad = true;
	self LuiNotifyEvent( &"tod_input_pad", 1, 1 );
}

function wait_for_choice( opts, timeout, locked )
{
	self endon( "disconnect" );

	if ( !isdefined( locked ) )
		locked = 0;

	two = isdefined( opts[ 1 ] );
	sel = 1;         // focused card: 1 left, 2 right
	held = 0;
	phase = 0;       // blink phase 0/1
	blink_t = 0;
	last_focus = 0;
	last_secs = int( timeout );
	last_strafe = 0; // KBM strafe edge latch (v10.3)
	last_fwd = 0;    // KBM W/S edge latch (v10.18 — full-WASD, user 2026-08-24)
	// v10.19 (user retest: "Controller works fine but keyboard still does
	// nothing"): the whole KBM lane so far rides GetNormalizedMovement + the
	// jump read, and NEITHER has ever been live-verified on a keyboard — map
	// 1's freeze lesson and every menu test since were controller runs. So the
	// menu now ALSO listens on reads the engine core exercises constantly and
	// that a keyboard definitely owns: MOUSE1 = left card, MOUSE2 = right card
	// (weapons are DisableWeapons'd for every choice — player_choice_flow wraps
	// present_choice in menu_freeze — so the press cannot fire the gun), and
	// HOLD USE [F] locks alongside JUMP. On controller these add RT/LT/X as
	// bonus inputs, which is harmless.
	// SEEDED latches: attack/ads are sampled ONCE before the loop so a button
	// already held when the panel opens (RT mid-fight) cannot flip focus on the
	// first tick. USE gets the jump treatment (arm-on-release) because the
	// STATION is opened by hold-F — without arming, the buy hold would
	// insta-lock the left card.
	// v10.20 — THE ACTUAL KEYBOARD LANE, and why it is these four buttons.
	// RESEARCH RESULT (workflow 2026-08-24, five parallel source audits):
	//   * ActionSlotThree/Four ARE THE CONTROLLER D-PAD, provably — stock maps
	//     them at util_shared.gsc:2404 ( _button_funcs[ BUTTON_RIGHT ] =
	//     &ActionSlotFourButtonPressed ). BO3 PC binds NO keyboard key to an
	//     action slot in zombies, so on a keyboard they are permanently false.
	//     That is the whole "controller works, keyboard does nothing" report:
	//     the working input was always the D-PAD.
	//   * GetNormalizedMovement is documented as "the player's MOVEMENT
	//     normalized" — not the movement INPUT — and every card flow wraps this
	//     in menu_freeze(), which pins SetMoveSpeedScale to 0.001. A
	//     movement-derived read under a 0.001 pin is ~0 FOR BOTH DEVICES. It is
	//     kept below as a free bonus lane, but nothing depends on it, and
	//     Treyarch never calls it anywhere in share/raw.
	// SO THE LANE IS ACTION BUTTONS, which BOTH devices bind by default. The
	// precedent is the author's OWN SHIPPED CODE: map 1's leaderboard consent
	// card (_acc_leaderboard.gsc:588-596) is an in-game hold-to-choose picker
	// driven by MeleeButtonPressed + AdsButtonPressed, played on keyboard.
	// FOUR buttons, not two, deliberately: menu_freeze calls DisableWeapons(),
	// and if that ever suppresses the attack/ads reads, MELEE and RELOAD are an
	// independent path to the same result. Redundancy is the point.
	last_atk = ( ( self AttackButtonPressed() ) ? 1 : 0 );
	last_ads = ( ( self AdsButtonPressed() ) ? 1 : 0 );
	last_mel = ( ( self MeleeButtonPressed() ) ? 1 : 0 );
	last_rld = ( ( self ReloadButtonPressed() ) ? 1 : 0 );
	// v16.57 THE OFFHAND PAIR (see the lane in the loop): seeded like the rest.
	last_sec = ( ( self SecondaryOffhandButtonPressed() ) ? 1 : 0 );
	last_frag = ( ( self FragButtonPressed() ) ? 1 : 0 );
	// 2026-10-01 (docs/167 item 14, "the mouse wheel not scrolling through
	// upgrades"): the WEAPON-SWITCH button joins the flip lanes, seeded like the
	// rest. See the lane in the loop for what it is and is not.
	last_wsw = ( ( self WeaponSwitchButtonPressed() ) ? 1 : 0 );
	wheel_wsw = last_wsw;                                     // dev wheel probe only
	wheel_isw = ( ( self IsSwitchingWeapons() ) ? 1 : 0 );   // dev wheel probe only
	wheel_wpn = self GetCurrentWeapon();                      // dev wheel probe only
	use_armed = 0;
	probe_t = 0;     // dev input probe cadence
	// (The v10.19 LUI keyboard bridge was REMOVED in v10.20 — see the input
	// research note at the latch block above. It never had a precedent: every
	// OpenLUIMenu menu in stock, in map 1 and in this map is display-only, and
	// a HUD-layer menu is not on the focused menu stack, so its button
	// callbacks were never dispatched to. Replaced by the action-button lane.)
	last_d3 = 0;     // d-pad edge latches (v10.4; PER SLOT since v16.81): level
	last_d4 = 0;     // reads re-asserted a held direction every tick and snapped
	                 // focus back against a fresh strafe flip (audit find)
	// JUMP RELEASE GATE (co-op audit 2026-08-23): the loop samples
	// JumpButtonPressed() with no press-edge, so a player ALREADY holding jump
	// when the panel opens accumulates `held` from frame one and auto-locks the
	// left card ~0.3s later, before they have read either option. That is not a
	// corner case: menu_freeze uses AllowJump(false), which suppresses the hop
	// but NOT the button read, and the round-1 event drops its cards while
	// players who locked their class early are free-running the base. The
	// personal station is worse — the world is not paused there, so a dodge-hop
	// mid-fight pays for a card. Holds only count once we have seen the button
	// RELEASED at least once, so a press must start after the panel is up.
	jump_armed = 0;
	waited = 0;
	// v16.79 — A CRAWLER DEALT CARDS KEEPS THE PANEL (user 2026-09-03: "sometimes
	// I get two options for upgrades but i cant select one of them"). v15
	// (2026-08-31) let last-stand players into round events, but the mid-card
	// release below had no notion of "already down when the panel opened": for
	// a crawler it fired on the FIRST tick — cards landed, focus on the left
	// card, 50 ms later the loop fell out to the timeout exit — card A taken,
	// card B never reachable, panel gone inside a second. The release exists
	// to undo menu_freeze's DisableWeapons for a player who went down DURING
	// the pick, and menu_freeze never freezes a player who is already down, so
	// for a crawler there is nothing to release. Latch the entry state; break
	// only on the alive -> down transition.
	down_at_open = ( self laststand::player_is_in_laststand() );

	while ( waited < timeout )
	{
		// countdown readout (whole seconds, only on change)
		secs = int( timeout - waited + 0.999 );
		if ( secs != last_secs )
		{
			self set_field( "todUpgTime", secs );
			last_secs = secs;
		}

		// WENT DOWN MID-CARD -> RELEASE THEM NOW (live-report audit 2026-08-26).
		//
		// THE CALLER'S menu_freeze STILL HOLDS DisableWeapons(), AND STOCK NEVER
		// UNDOES IT. This is the whole reason this guard exists, and it is worth
		// stating precisely because it is counter-intuitive: stock's last-stand
		// path does NOT use DisableWeapons at all — it uses DisableWeaponCycling
		// (_zm_laststand.gsc:290) and restores with EnableWeaponCycling +
		// EnableOffhandWeapons (:369-403). Nothing on the down, bleedout or
		// revive path ever calls EnableWeapons(). So a player who goes down
		// while the cards are up is handed the last-stand pistol by
		// _zm.gsc:2826-2892 (GiveWeapon + SwitchToWeapon), holds it on screen,
		// AND CANNOT FIRE IT — for up to TOD_UPG_CHOICE_TIMEOUT + the 0.7s
		// confirm flash. Stock itself uses DisableWeapons this way as a firing
		// lock (_zm.gsc:4855, playerzombie_downed_state).
		//
		// menu_freeze's own laststand check (_tod_upgrades.gsc:1087) is a
		// ONE-SHOT ENTRY test — it refuses to freeze someone already down, and
		// never looks again. This is the other half of that rule.
		//
		// REACHABLE despite the world being paused: the pause freezes AI, but
		// the Panzer's FLAMETHROWER BURN is stock _burnplayer.gsc's own per-player
		// damage loop and knows nothing about level.tod_upgrade_pause, so it keeps
		// ticking (_tod_bosses.gsc records the same exemption for the through-wall
		// shield). Panzers land every 5th round, events every 4th, and the
		// endless-rounds twist starts the next round while the last one's Panzer
		// is still alive — so the overlap is routine, not freak. A Protector
		// rocket already in flight and an in-flight melee notetrack do it too.
		//
		// `break`, NOT `return`: it falls into the existing timeout exit below
		// (tod_upg_timed_out = true; return sel), so no new exit path is created
		// and the caller still unfreezes on return. THE UPGRADE IS NOT
		// FORFEITED — apply_upgrade only refuses a timed-out TIER card, and
		// player_choice_flow already falls back to the other card; a domain card
		// pays out normally. Refusing a tier promotion mid-crawl is exactly the
		// rule the station path already enforces.
		// (v16.79: TRANSITION only — a player down at open keeps the panel; see
		// down_at_open above.)
		if ( !down_at_open && ( self laststand::player_is_in_laststand() ) )
			break;
		// A crawler who BLEEDS OUT mid-pick has no panel any more (the engine
		// closes a player's LUI menus on death -> spectate) — release the event
		// rather than hold the world for a card nobody can answer. IsAlive is
		// TRUE in last stand (stock contract), so this is the dead test alone.
		if ( !isalive( self ) )
			break;

		// --- focus switching: D-PAD ONLY ------------------------------------
		// User 2026-08-21: "change the controls of the upgrade menu to only
		// use the dpad". ActionSlotThree/Four ARE the d-pad left/right reads.
		// The old ADS/FIRE and movement-stick fallbacks are gone — with the
		// personal station no longer freezing the player, strafing to dodge
		// was silently flipping the card, and aiming/firing to fight was
		// selecting one.
		//
		// ...and then v10.19/v10.20 put every one of those lanes BACK, because
		// a keyboard has no d-pad. v14.20 (user 2026-08-30: "can we make the
		// upgrade menu d pad only on controller. Its akward to move around and
		// still set an upgrade") reconciles the two directives instead of
		// picking one: the extra lanes now live behind a PER-PLAYER DEVICE
		// LATCH, so the pad gets the 2026-08-21 rule and the keyboard keeps the
		// 2026-08-24 one.
		//
		// HOW THE LATCH KNOWS. There is NO server-side device read in T7 — no
		// gamepad builtin exists anywhere in share/raw, and CSC/LUI cannot
		// answer the server (clientfields are one-way). What the map DOES have
		// is an input that only one device can produce: ActionSlotThree/Four
		// are the controller d-pad and BO3 PC binds no keyboard key to an
		// action slot in zombies (the v10.20 research). So the FIRST d-pad
		// press this player ever makes proves the device, and tod_input_pad
		// latches for the rest of the match (a plain player field — it rides
		// the player entity, so it survives respawns like tod_levels does, and
		// _tod_class_select sets the same field, which is what usually gets it
		// latched during the 30s draft, before the round-1 event opens).
		// ONE-WAY, deliberately: the d-pad is never gated on anything, so a
		// player who somehow bound a key to an action slot still navigates with
		// it, and a player who never touches the d-pad simply keeps every lane
		// they had before this change. Nothing regresses for the keyboard.
		//
		// ⚠️ v16.81 (2026-09-03) — THE PREMISE ABOVE IS FALSE. The player's own
		// <game>/players/bindings_0.cfg reads:
		//     bind 1 "+actionslot 1"   bind 2 "+actionslot 2"
		//     bind 3 "+actionslot 4"   bind 4 "+actionslot 3"
		// so keyboard 3 / 4 ARE action-slot presses (4 and 3, swapped). A KBM
		// player who taps 3 or 4 during the draft or a deal used to be latched
		// as a pad for the rest of the match and lose every keyboard lane —
		// "frozen" with two cards up. tod_input_pad therefore means "an
		// action-slot press was seen", not "this is a controller", and its
		// blast radius is now the STATION only: at a ROUND EVENT (the world
		// paused, movement pinned, weapons disabled) every lane is live for
		// everyone — there is no fight to be awkward with, which was the whole
		// point of the 2026-08-30 d-pad-only rule. The station keeps that rule.
		want = sel;
		// v16.81 (user 2026-09-03: "my dpad was frozen. And another player
		// reported this too") — PER-SLOT edges, read INDEPENDENTLY. The old
		// `else if` let a slot-3 read that stays true hide slot 4 for the whole
		// panel: no edge, no right card. Stock binds slot 3 to the held weapon's
		// altMode (_zm.gsc:1836), so its read is the one most exposed to weapon
		// state. Each slot now latches on its own; either still seeds the
		// action-slot latch below.
		d3 = ( ( self ActionSlotThreeButtonPressed() ) ? 1 : 0 );
		d4 = ( ( self ActionSlotFourButtonPressed() ) ? 1 : 0 );
		if ( d3 || d4 )
			self pad_latch();   // an action-slot press was seen — see the latch note above (not a device PROOF; v16.81)
		if ( d3 && !last_d3 )
			want = 1;   // edge-latched (v10.4) — a fresh press only
		if ( d4 && !last_d4 )
			want = 2;
		last_d3 = d3;
		last_d4 = d4;
		// v16.57 THE OFFHAND PAIR — TACTICAL = LEFT card, LETHAL = RIGHT card, on
		// BOTH devices, always live (user 2026-09-02: "Left bumper goes right and
		// right goes left"). The fire/aim pair can NEVER be given a side that is
		// right on both devices: every pad layout puts FIRE on the right hand and
		// AIM on the left (default RT/LT, the user's own bumper layout RB/LB),
		// while a mouse puts fire on the LEFT button — and the server cannot tell
		// the devices apart (bo3-menu-input-apis fact 4). The grenade pair has no
		// such problem: every BO3 layout keeps TACTICAL on the left-hand button and
		// LETHAL on the right-hand one (default LB/RB; bumper-swapped LT/RT), so
		// "tactical = left, lethal = right" is physically correct on every pad by
		// construction, and on a keyboard it is a stable key pair the plate names
		// through its bind tokens. NOT gated on the pad latch: nobody holds a
		// grenade button while fighting, and menu_freeze holds
		// DisableOffhandWeapons() so a press here can never throw one. Fire/aim
		// no longer move focus at all (they were the reversed lane).
		sec = ( ( self SecondaryOffhandButtonPressed() ) ? 1 : 0 );
		frg = ( ( self FragButtonPressed() ) ? 1 : 0 );
		if ( sec && !last_sec )
			want = 1;
		else if ( frg && !last_frag )
			want = 2;
		last_sec = sec;
		last_frag = frg;
		// EVERY LANE BELOW IS KEYBOARD-ONLY (v14.20). On a controller these are
		// the strafe stick, RT, LT, R3 and X — i.e. exactly the buttons a player
		// is holding while fighting at the personal upgrade station, which is
		// the awkwardness the user reported. The reads are SKIPPED, not merely
		// ignored, so the per-source latches below stay untouched and cannot
		// fire a stale edge if the flag were ever cleared.
		// Seeded OUTSIDE the gate because the dev input probe at the bottom of
		// the loop prints all four every second — skipping the reads must not
		// hand it uninitialised variables (dev-only, but a dev build is exactly
		// where this would be discovered the hard way).
		atk = 0;
		ads = 0;
		mel = 0;
		rld = 0;
		// v16.81: the latch gates these lanes at the STATION only (world live,
		// the player is fighting — the awkward case). At a ROUND EVENT the
		// world is paused and the player cannot move or shoot, so every lane
		// stays live for every device: a pad whose d-pad read has died still
		// has R3 / X, and a KBM player falsely latched by keyboard 3/4 still
		// has WASD / R / V. See the latch note above.
		// v16.84 narrows "the STATION" to a CO-OP station without touching this
		// line: a solo pick now sets level.tod_upgrade_pause itself, so it takes
		// the paused branch and every lane opens. That is the rule above being
		// obeyed, not bypassed — the d-pad-only gate was earned by the player
		// being mid-fight, and a frozen solo buyer is not.
		if ( !IS_TRUE( self.tod_input_pad ) || IS_TRUE( level.tod_upgrade_pause ) )
		{
		// KBM (playtest 2026-08-23: "Make sure KBM can pick the cards and
		// upgrades"): ActionSlot 3/4 are the D-PAD reads — a keyboard player
		// had NO way to move focus. A/D (the strafe axis; left stick on pad)
		// now switches too, EDGE-LATCHED like the class draft: only a FRESH
		// push flips, so holding a strafe to dodge flips once, not per-tick.
		// That per-tick flipping is what got the stick read removed on
		// 2026-08-21 — the latch is the difference, and KBM access outranks
		// the residual single flip (user directive).
		strafe = 0;
		mv = self GetNormalizedMovement();
		if ( isdefined( mv ) )
		{
			if ( mv[ 1 ] < -0.4 )
				strafe = -1;
			else if ( mv[ 1 ] > 0.4 )
				strafe = 1;
		}
		if ( strafe != 0 && strafe != last_strafe )
			want = ( ( strafe < 0 ) ? 1 : 2 );
		last_strafe = strafe;
		// FULL WASD (user 2026-08-24, from beta comments: "the upgrade menu
		// needs to be fully keyboard accessable. WASD, up left down right").
		// W/S = the forward axis (mv[0]); with exactly TWO cards side by side
		// there is no "up card", so a fresh W or S press flips focus to the
		// OTHER card — every direction key now moves focus, none is dead.
		// Same PER-SOURCE edge latch as the strafe (the draft's cross-fire
		// lesson): sign is irrelevant to a flip, so W-vs-S never inverts.
		// ARROW KEYS ride this same read, but only for players whose arrows
		// are BOUND to movement — GSC has no raw-key read, so unbound arrows
		// are invisible to script. WASD is the guaranteed lane.
		fwd = 0;
		if ( isdefined( mv ) )
		{
			if ( mv[ 0 ] < -0.4 )
				fwd = -1;
			else if ( mv[ 0 ] > 0.4 )
				fwd = 1;
		}
		if ( fwd != 0 && fwd != last_fwd )
			want = ( ( sel == 1 ) ? 2 : 1 );
		last_fwd = fwd;
		// ACTION BUTTONS (v10.20) — the keyboard lane. All edge-latched and
		// pre-seeded (see the latch block above), so a button already held when
		// the panel opens cannot flip focus on tick one.
		//   (fire / aim: READ for the dev probe only since v16.57 — no longer a
		//   lane; the offhand pair above is the directional one on every device)
		//   MELEE (V / R3)   -> flip to the other card
		//   RELOAD (R / X)   -> flip to the other card
		atk = ( ( self AttackButtonPressed() ) ? 1 : 0 );
		ads = ( ( self AdsButtonPressed() ) ? 1 : 0 );
		mel = ( ( self MeleeButtonPressed() ) ? 1 : 0 );
		rld = ( ( self ReloadButtonPressed() ) ? 1 : 0 );
		if ( ( mel && !last_mel ) || ( rld && !last_rld ) )
			want = ( ( sel == 1 ) ? 2 : 1 );
		last_mel = mel;
		last_rld = rld;
		// 2026-10-01 (docs/167 item 14): THE WEAPON-SWITCH BUTTON flips too
		// (+weapnext_inventory - Y on a pad, X on the default keyboard), edge-
		// latched and seeded like melee / reload. ⚠️ THE MOUSE WHEEL IS NOT PROVEN
		// TO REACH IT: the wheel's default binds are weapnext / weapprev, one-shot
		// commands that pick a weapon rather than hold a button, and this panel is
		// HUD-layer, so it receives no LUI input at all (bo3-menu-input-apis). The
		// dev wheel probe below logs every candidate lane per tick, so one KBM test
		// settles which one - if any - a wheel notch reaches.
		wsw = ( ( self WeaponSwitchButtonPressed() ) ? 1 : 0 );
		if ( wsw && !last_wsw )
			want = ( ( sel == 1 ) ? 2 : 1 );
		last_wsw = wsw;
		}   // end keyboard-only lanes (v14.20 device latch)
		// DEV WHEEL PROBE (2026-10-01, docs/167 item 14). A wheel notch is a one-
		// frame event, so the once-a-second input probe below cannot see it. This
		// logs the moment any candidate lane changes - the weapon-switch button,
		// the engine's switching state, the held weapon - with the card focus
		// beside it. Console only, change-gated, dev only; it decides nothing.
		if ( IS_TRUE( level.tod_dev ) )
		{
			p_wsw = ( ( self WeaponSwitchButtonPressed() ) ? 1 : 0 );
			p_isw = ( ( self IsSwitchingWeapons() ) ? 1 : 0 );
			p_wpn = self GetCurrentWeapon();
			if ( p_wsw != wheel_wsw || p_isw != wheel_isw || p_wpn != wheel_wpn )
			{
				wname = "none";
				if ( isdefined( p_wpn ) && isdefined( p_wpn.name ) )
					wname = p_wpn.name;
				line = "[TOD_CARD_WHEEL] ms=" + GetTime() + " player=" + self GetEntityNumber()
					+ " wsw=" + p_wsw + " switching=" + p_isw + " weapon=" + wname + " sel=" + sel;
				/#
				PrintLn( line );
				#/
			}
			wheel_wsw = p_wsw;
			wheel_isw = p_isw;
			wheel_wpn = p_wpn;
		}
		if ( !two )
		{
			if ( IS_TRUE( level.tod_dev ) && want == 2 )
				self tod_quiet_print_to( "^3card 2 refused: single-card deal" );
			want = 1;
		}
		// THE LOCKED SLOT REFUSES FOCUS (v14.39). Every input lane above funnels
		// into `want`; this is the single commit point, so one test covers the
		// d-pad, the movement stick, all four action buttons and the KBM lanes.
		//
		// AUDIBLE, because a control that silently does nothing reads as a
		// broken trigger — the same rule the pause-gated devices already follow.
		// It can only fire on an input EDGE (want only differs from sel when a
		// lane produced a change this tick), so holding a direction against the
		// locked card cannot machine-gun the deny sound.
		//
		// PlaySound, NOT PlayLocalSound, and that is deliberate. Every
		// PlayLocalSound in this map pairs with a CUSTOM tod_* alias; the only
		// proven pairing for this STOCK alias is `PlaySound( "zmb_no_purchase" )`
		// — four live call sites in _tod_ammo_crate. PlayLocalSound with it
		// would be the first caller of an untested combination, and its failure
		// mode is SILENCE, which is precisely the thing this sound exists to
		// prevent. (Caught by grepping for a precedent and finding only my own
		// new line — a self-citation is not a precedent.)
		if ( locked > 0 && want == locked )
		{
			want = sel;
			self PlaySound( "zmb_no_purchase" );
			// DEV: name the refused slot's domain — a refusal that names nothing
			// is the 2026-09-03 report ("a sprint card I couldn't switch to").
			if ( IS_TRUE( level.tod_dev ) )
				self tod_quiet_print_to( "^3card " + locked + " refused: locked " + opts[ locked - 1 ].domain );
		}
		if ( want != sel )
		{
			sel = want;
			held = 0;   // switching resets any lock progress
			phase = 0;
			blink_t = 0;
			self PlayLocalSound( "tod_ui_tick" );   // focus moved
		}

		// --- hold JUMP or USE to lock (v10.19: USE [F] joins for KBM) -------
		// Each button arms on its own first RELEASE (jump: pre-open hops; use:
		// the station is BOUGHT with hold-F, so the same finger is still down
		// when this panel opens). An armed hold on EITHER accumulates.
		b_jump = self JumpButtonPressed();
		b_use = self UseButtonPressed();
		if ( !b_jump )
			jump_armed = 1;
		if ( !b_use )
			use_armed = 1;
		if ( ( b_jump && jump_armed ) || ( b_use && use_armed ) )
		{
			held += 0.05;
			if ( held >= TOD_UPG_HOLD_SECS )
			{
				self set_field( "todUpgHold", 15 );
				self PlayLocalSound( "tod_ui_lock" );
				return sel;
			}
		}
		else
		{
			held = 0;
		}

		// DEV INPUT PROBE (v10.19): one line per second of exactly what the
		// server reads from this player — the tool that ends the "keyboard
		// does nothing" guessing. Read it off a KEYBOARD run: whichever
		// column stays 0 while the key is held is the dead read.
		if ( IS_TRUE( level.tod_dev ) )
		{
			probe_t += 0.05;
			if ( probe_t >= 1.0 )
			{
				probe_t = 0;
				mvp = self GetNormalizedMovement();
				fwd_p = 0;
				str_p = 0;
				if ( isdefined( mvp ) )
				{
					fwd_p = int( mvp[ 0 ] * 10 );
					str_p = int( mvp[ 1 ] * 10 );
				}
				// v16.81: every lane's raw read PLUS the loop's own state, so a
				// "frozen d-pad" repro says which it is in one line: d3/d4 stuck
				// at 0 while held = the engine is not delivering the slot; d4=1
				// with sel stuck = the lane; sel moving while the HUD does not =
				// the Lua. Read it off a dev run with the panel up.
				self tod_quiet_print_to( "^3inp mv=" + fwd_p + "," + str_p
					+ " j=" + ( ( b_jump ) ? 1 : 0 ) + " u=" + ( ( b_use ) ? 1 : 0 )
					+ " m1=" + atk + " m2=" + ads + " mel=" + mel + " rld=" + rld
					+ " d3=" + d3 + " d4=" + d4 + " tac=" + sec + " let=" + frg
					+ " | sel=" + sel + " two=" + ( ( two ) ? 1 : 0 ) + " lock=" + locked
					+ " pad=" + ( ( IS_TRUE( self.tod_input_pad ) ) ? 1 : 0 )
					+ " ev=" + ( ( IS_TRUE( level.tod_upgrade_pause ) ) ? 1 : 0 ) );
			}
		}

		// hold-progress fill (0..15) — the bar under the focused card
		hv = int( held / TOD_UPG_HOLD_SECS * 15 );
		if ( hv > 15 )
			hv = 15;
		if ( !isdefined( self.tod_upg_hold_shown ) || self.tod_upg_hold_shown != hv )
		{
			self set_field( "todUpgHold", hv );
			self.tod_upg_hold_shown = hv;
		}

		// --- focus blink (faster while locking) ----------------------------
		blink_t += 0.05;
		interval = ( ( held > 0 ) ? ( TOD_UPG_BLINK_SECS * 0.5 ) : TOD_UPG_BLINK_SECS );
		if ( blink_t >= interval )
		{
			blink_t = 0;
			phase = 1 - phase;
		}

		focus = ( ( sel == 1 ) ? ( ( phase == 0 ) ? 1 : 2 ) : ( ( phase == 0 ) ? 3 : 4 ) );
		if ( focus != last_focus )
		{
			self set_field( "todUpgFocus", focus );
			last_focus = focus;
		}

		wait 0.05;
		waited += 0.05;
	}

	self.tod_upg_timed_out = true;
	return sel;   // timeout — lock whatever is focused
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
