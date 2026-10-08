// =============================================================================
// _tod_riotshield.gsc — RIOT SHIELD, the universal five-level shield upgrade
//
// v16.63 (user 2026-09-02): "I want to add a riot shield to the map. It is for
// all classes and has 5 levels. Each level increasing the health and decreasing
// the recharge. Once it breaks it needs to be recharged and you will get it
// back automatically. ... abandoned cyber city had a riot shield so we can use
// that exact one. There is a base riot shield and then one new model. New
// model will be used at max tier."
//
// HOW IT PLAYS
//   Own one level of the RIOT SHIELD domain (id 45, every class rolls it) and a
//   shield rides in your equipment slot (d-pad DOWN swaps to it, like every stock
//   zombies shield). Held, it blocks everything in front; on your back it blocks
//   everything behind (stock rules, untouched). It has its own health bar under
//   the HUD health bar. When its health hits zero it breaks and is GONE, and a
//   per-player recharge starts; when the recharge runs out the shield is handed
//   straight back, full, no purchase, no station. THE LADDER (the user's table,
//   verbatim — TOD_SHIELD_HP_L* / TOD_SHIELD_RECHARGE_L* below):
//       Lv1  200 HP   4:00        Lv4  450 HP   2:30
//       Lv2  300 HP   3:30        Lv5  500 HP   2:00  + THE NEW MODEL
//       Lv3  370 HP   3:00
//   Lv5 also swaps the shield for the second model (the clean cyber shield —
//   Logical's mesh, the one map 1 reskinned its shield with).
//   TAKING A CARD REFILLS THE SHIELD YOU ARE CARRYING (v17.11, user 2026-09-04)
//   — to the NEW maximum, so a battered Lv2 shield comes out of the deal as a
//   full Lv3 one. The dark rung refills it too (it raises the same number).
//   A card taken while the shield is RECHARGING shortens the wait instead; it
//   can never lengthen one.
//   THE DARK RUNG (700 HP / 1:30) ALSO TAKES 2 SECONDS OFF A RUNNING RECHARGE
//   FOR EVERY ELITE YOU KILL (v17.16, user 2026-09-04) — dark holders only,
//   killer only, and only against a clock that is running. See elite_kill().
//   THE RETURN VERIFIES ITSELF (v17.16), and reconcile() sweeps a DEAD SHIELD —
//   one left in the inventory with stock's flags cleared, which used to make
//   every later reconcile think the slot was full. See shield_is_dead().
//
// THE PORT (map 1, _acc_boss_items.gsc apply_rocket_shield .. regrant_on_destroy)
//   Map 1 never wrote a shield of its own: it grants the STOCK Shadows of Evil
//   rocket shield (`zod_riotshield`, weapon def shipped in zm_levelcommon,
//   equipment registration free from stock zm_usermap's #using of
//   _zm_weap_rocketshield) and adds exactly three things, all kept here:
//     1. an EFFECTIVE-HP SCALER. The shield's real health pool is the weapon
//        def's weaponStartHitPoints, burned engine-side by DamageRiotShield
//        with NO runtime setter. So every blocked hit is scaled UP by
//        (pool / wanted HP) before it reaches the stock damage function, and
//        the pool then empties over exactly `wanted HP` of real damage. The
//        HUD bar stays a true fraction by construction. THIS IS WHAT LETS ONE
//        WEAPON ASSET CARRY FIVE HEALTH LEVELS — five per-level assets would be
//        five weapon registrations against a ledger that sits on its guard.
//        The seam is the per-player pointer self.player_shield_apply_damage
//        (the stock design's own override hook, _zm_weap_riotshield.gsc:92).
//        ⚠️ _zm_weap_rocketshield::on_player_spawned RE-STOMPS that pointer to
//        the stock function on EVERY spawn — so install_scaler() runs on every
//        reconcile, and the spawn reconcile waits for stock to settle first.
//        Shield BASHES stay stock-priced on purpose (riotshield_melee calls
//        player_damage_shield DIRECTLY, not through the pointer): a bash costs
//        the same fraction of the bar at every level; only enemy damage burns
//        the smaller pool. Map 1 shipped exactly this.
//     2. BREAK DETECTION on stock's own "destroy_riotshield" notify (the first
//        line of riotshield::player_take_riotshield, which stock threads the
//        moment the pool hits zero).
//     3. RE-GRANT: map 1's flat 60 s regrant thread is now the LEVEL LADDER
//        above, and the timer is per-player state that survives a down, a
//        bleed-out and a respawn (it is stamped on the player entity, which is
//        never deleted) — you come back from a death with whatever recharge you
//        had left, not a fresh shield and not a reset clock.
//
// WHY A RECONCILE (the DISTRACTION shape, _tod_distraction.gsc)
//   Equipment is INVENTORY and inventory does not survive a spawn. THREE paths
//   write a domain level without ever calling apply_upgrade (tier_up's reset
//   loop, tier_up's grant field, the dev grant), and a one-shot "on card pick"
//   hook is skipped by all of them. So the effect is a reconcile: read the
//   level, make the equipment slot match. Idempotent, called on every spawn, by
//   _tod_upgrades after every level write (through level.tod_shield_reconcile —
//   _tod_upgrades can never #using us, we import IT for get_level), and by a
//   slow per-player maintain so no stock strip path can leave a Lv3 player
//   shieldless for a round.
//
// THE TWO WEAPONS
//   Lv1-4  zod_riotshield     stock SoE rocket shield: def + models from
//                              zm_levelcommon, equipment-registered by stock.
//                              NOT a zone line, NOT a ledger entry — the CSV row
//                              that was always in zm_levelcommon_weapons.csv
//                              is its inclusion lane (the cymbal-monkey rule).
//   Lv5    log_riotshield_zm  Logical's standalone "Riot Shield" weapon def
//                              (bulletweapon, weaponType riotshield, 1500 HP,
//                              gunModel/worldModel logical_m_shield_full, the
//                              stock vm_riotshield_zm_* anim set, dpad icon
//                              riotshield_zm_icon). It lives in the Logical
//                              pack's own GDT under <BO3>/model_export/
//                              _logical_models/ (the gdtdb scans model_export
//                              GDTs — map 1's manifest note), which is why it
//                              needs a `weapon,` zone line here and pays ONE
//                              registration (LEDGER_GUARD 223 -> 224). Map 1
//                              used the SAME mesh a different way — six xmodel
//                              blocks SHADOWING the stock rocket-shield model
//                              names — but a shadow replaces the look for BOTH
//                              stock forms, and this map needs two looks.
//                              Registered as equipment here in init() exactly
//                              the way stock registers zod_riotshield.
//   The swap at Lv5 is take-then-buy INSIDE a latch (tod_shield_swapping) so
//   the take's stock notify cannot be mistaken for a break.
//
// WHAT IS FREE. Blocking, the back-stow, the d-pad slot, the HUD health bar
// (Aetherium's AetheriumPlayerInfo.lua already subscribes zmInventory.shield_health
// through Engine.CreateModel — that fix rode in from map 1 on 2026-08-26 and
// has waited for a shield ever since), the break sounds, the bash. Nothing here
// registers a clientfield, mints a hint string or adds a twin.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_weap_riotshield;     // player_take_riotshield / UpdateRiotShieldModel (namespace riotshield)
#using scripts\zm\_zm_weap_rocketshield;   // player_damage_rocketshield (namespace rocketshield) — keeps SoE's explosive x3

#using scripts\zm\zm_tower_of_doom\_tod_upgrades;   // get_level

#insert scripts\shared\shared.gsh;

#precache( "string", "ZOMBIE_EQUIP_RIOTSHIELD_PICKUP_HINT_STRING" );
#precache( "string", "ZOMBIE_EQUIP_RIOTSHIELD_HOWTO" );

#define TOD_SHIELD_DOMAIN   "riotshield"
#define TOD_SHIELD_W_BASE   "zod_riotshield"      // Lv1..4 — the stock SoE rocket shield
#define TOD_SHIELD_W_MAX    "log_riotshield_zm"   // Lv5    — Logical's cyber shield (the "new model")
#define TOD_SHIELD_MAX_LVL  5                     // the level that swaps the model in (= the domain max)

// THE LADDER — the user's table, verbatim (2026-09-02). LOCKSTEP: the
// SHIELD_HP / SHIELD_RECHARGE tables in tod_upgrade.lua (the pause menu prints
// these), the add_domain desc and the armory row are mirrors of THESE.
#define TOD_SHIELD_HP_L1        200
#define TOD_SHIELD_HP_L2        300
#define TOD_SHIELD_HP_L3        370
#define TOD_SHIELD_HP_L4        450
#define TOD_SHIELD_HP_L5        500
#define TOD_SHIELD_RECHARGE_L1  240   // 4:00, seconds
#define TOD_SHIELD_RECHARGE_L2  210   // 3:30
#define TOD_SHIELD_RECHARGE_L3  180   // 3:00
#define TOD_SHIELD_RECHARGE_L4  150   // 2:30
#define TOD_SHIELD_RECHARGE_L5  120   // 2:00
// DARK UPGRADE (v17.10, docs/92): the rung past Lv5. Absolute values, authored
// the same way the ladder above is. Defined HERE and nowhere else -- the design
// doc records them, no other .gsc repeats them.
#define TOD_DARK_SHIELD_HP            700
#define TOD_DARK_SHIELD_RECHARGE_SECS  75   // 1:15 (was 1:30, user 2026-09-05)
// Dev builds (level.tod_dev, the ONE compile-time flag) recharge in this many
// seconds instead, so a test session can watch break -> return more than once
// a round. Ship state never reads it.
#define TOD_SHIELD_DEV_RECHARGE 15

// Stock re-runs its spawn handlers on every "spawned_player" dispatch, and a
// co-op bleed-out respawn dispatches it TWICE; give_class_loadout waits 0.5 for
// the same reason. Same 0.6 as DISTRACTION: land on a settled loadout, and —
// specific to us — land AFTER rocketshield::on_player_spawned has re-stomped
// player_shield_apply_damage, so the scaler installed here is the one that
// stays. A hit inside that 0.6 s is charged at the stock rate; acceptable.
#define TOD_SHIELD_SPAWN_WAIT   0.6
#define TOD_SHIELD_MAINTAIN_SECS 2     // the slow per-player maintain (idempotent reconcile)
#define TOD_SHIELD_BREAK_SND    "tod_shield_break"    // map 1's shield_break.wav, 3d at the owner (stock's own break sounds fire too)
#define TOD_SHIELD_BACK_SND     "tod_lounge_arrive"   // an existing 2d chime — the "it's back" tell, local to the owner

// EVERY ELITE YOU KILL TAKES THIS MANY SECONDS OFF A RUNNING RECHARGE (v17.16,
// user 2026-09-04: "every elite you kills takes off 2 seconds from the recharge
// time" ... "this only applies to the dark shield max upgrade"). So it is part
// of the DARK rung, not of the ladder: a THIRD term on the dark upgrade beside
// the 700 HP and the 1:30, and a Lv5 holder without the dark bit gets nothing
// from it. KILLER ONLY, the same rule as the elite money it rides in beside,
// and it only ever shortens a recharge that is ACTUALLY RUNNING — there is
// nothing to bank against a shield you are still carrying.
#define TOD_SHIELD_ELITE_CUT_SECS 2

// How long after OUR OWN give we take the inventory on trust. Stock's
// self.hasRiotShield is set inside UpdateRiotShieldModel, which opens with
// WAIT_SERVER_FRAME, so it lags every give — without this grace the dead-shield
// sweep below would reap a shield we handed out one frame ago.
#define TOD_SHIELD_GIVE_GRACE_MS 1500

// The recharge return VERIFIES itself (v17.16). Give, wait a beat, look again;
// a give that did not land is retried rather than trusted.
#define TOD_SHIELD_RETURN_TRIES  4
#define TOD_SHIELD_RETURN_WAIT   0.5

#namespace tod_riotshield;

function init()
{
	// THE CALL-IN POINTER (the DISTRACTION idiom). _tod_upgrades re-runs our
	// reconcile after it writes a level (card pick, tier promotion, dev grant)
	// — it can never #using this module (we import it for get_level; the KB
	// cycle rule). Every caller guards on isdefined, so this module staying
	// unregistered degrades to "the shield only reconciles on spawn / the
	// maintain", never to a crash.
	level.tod_shield_reconcile = &reconcile;

	// THE ELITE-KILL POINTER (v17.16), same guarded-pointer idiom and the same
	// reason: _tod_bosses is the ONE choke point every elite death runs through
	// (grant_elite_reward — Panzer, Rogue Protector, Reaver, Hellhound,
	// Sprinter and the spire's Wardens all land there), and it must not #using
	// this module. Undefined = the module is not in the build, and an elite kill
	// simply pays money and nothing else.
	level.tod_shield_elite_kill = &elite_kill;

	// THE Lv5 WEAPON. zod_riotshield is registered as equipment by stock
	// (_zm_weap_rocketshield::__init__, reached through zm_usermap). Logical's
	// weapon is not stock, so it gets the same three calls here, with stock's
	// own strings and VO key — that is what makes zm_equipment::buy/give/take
	// treat it as a shield in the equipment slot rather than a foreign weapon.
	// GetWeapon on a name that is not in the .ff returns weaponNone and the
	// register would key on it; guard so a missing zone line reads as "Lv5
	// keeps the base model" and not as a boot error.
	w_max = GetWeapon( TOD_SHIELD_W_MAX );
	if ( isdefined( w_max ) && w_max != level.weaponNone )
	{
		zm_equipment::register( TOD_SHIELD_W_MAX, &"ZOMBIE_EQUIP_RIOTSHIELD_PICKUP_HINT_STRING", &"ZOMBIE_EQUIP_RIOTSHIELD_HOWTO", undefined, "riotshield" );
		zm_equipment::register_for_level( TOD_SHIELD_W_MAX );
		zm_equipment::include( TOD_SHIELD_W_MAX );
	}
	else
	{
		/# PrintLn( "^1[tod] riotshield: " + TOD_SHIELD_W_MAX + " is not in the .ff — Lv5 keeps the base shield model" ); #/
	}

	callback::on_spawned( &on_player_spawned );
}

// self = player. One set of watchers per player for the whole game.
function on_player_spawned()
{
	// RESPAWN LATCH in the function, not at the registration site (the shipped
	// idiom — _tod_distraction, _tod_runandgun, _tod_luck): callback::callback
	// THREADS every registered func on every dispatch, and the double dispatch
	// would otherwise stack immortal watchers per life. Do NOT use
	// callback::remove_on_spawned — it deregisters for EVERY player.
	if ( IS_TRUE( self.tod_shield_watch_on ) )
	{
		self thread respawn_reconcile();
		return;
	}
	self.tod_shield_watch_on = true;
	self thread break_watch();
	self thread maintain_loop();
	self thread respawn_reconcile();
	// A recharge that was running when this player died keeps running (the
	// deadline is entity state); the loop that hands the shield back is
	// re-armed here in case the old one was cut by a disconnect/reconnect.
	if ( isdefined( self.tod_shield_recharge_until ) )
		self thread recharge_loop();
}

// One-shot per spawn dispatch: let stock settle, then reconcile.
function respawn_reconcile()   // self = player
{
	self endon( "disconnect" );
	level endon( "end_game" );

	wait TOD_SHIELD_SPAWN_WAIT;

	if ( !isdefined( self ) || !IsAlive( self ) )
		return;

	self reconcile();
}

// The slow maintain. A reconcile every couple of seconds is one weapon-list
// walk; it exists so that any stock path that takes the shield WITHOUT the
// destroy notify (none known today — the watcher above owns the known one)
// still cannot leave a levelled player without one for longer than this.
function maintain_loop()   // self = player
{
	self endon( "disconnect" );
	level endon( "end_game" );

	for ( ;; )
	{
		wait TOD_SHIELD_MAINTAIN_SECS;
		if ( !isdefined( self ) || !IsAlive( self ) )
			continue;
		if ( self laststand::player_is_in_laststand() )
			continue;
		self reconcile();
	}
}

// ---------------------------------------------------------------------------
// THE ONE OWNER. Idempotent — read the level, make the equipment slot match.
// Safe from anywhere, any number of times, at any level including 0.
// ---------------------------------------------------------------------------
function reconcile()   // self = player
{
	if ( !isdefined( self ) || !IsAlive( self ) )
		return;

	lvl = tod_upgrades::get_level( self, TOD_SHIELD_DOMAIN );
	if ( lvl <= 0 )
		return;   // never owned it — leave the equipment slot exactly as we found it

	// The scaler goes in on EVERY reconcile — rocketshield's spawn handler
	// re-points it to the stock function every life (see the header).
	self install_scaler();

	// "DID THE SHIELD JUST GET BETTER?" — tracked as the HP NUMBER, not as the
	// level. Since v17.10 the level is not the whole story: the DARK rung raises
	// HP and cuts the recharge without moving the level, and it lands through
	// this same reconcile. One number covers both, and it can never read a
	// downgrade as an improvement.
	hp_now = shield_hp( lvl, self );
	hp_seen = 0;
	if ( isdefined( self.tod_shield_hp_seen ) )
		hp_seen = self.tod_shield_hp_seen;
	self.tod_shield_hp_seen = hp_now;
	improved = ( hp_seen > 0 && hp_now > hp_seen );

	// RECHARGING: nothing is handed out here — recharge_loop owns the return.
	// A card gained mid-recharge SHORTENS it: the deadline is re-derived from
	// the break time at the CURRENT rate and taken only when it lands earlier,
	// so a card can never lengthen a wait and a Lv1 -> Lv5 jump can hand the
	// shield back at once. (Compared against the live deadline rather than
	// against a remembered level, so the dark rung shortens it too.)
	if ( isdefined( self.tod_shield_recharge_until ) )
	{
		// v18.99c — A CARD ENDS THE RECHARGE, IT DOES NOT JUST SHORTEN IT (user:
		// "I had no riot shield, and I got a riot shield upgrade card, and it
		// didn't refill my riot shield when it should. That is the requirement.
		// I thought we fixed this before. Sometimes it seems to work, but this
		// time it didn't"). THE EARLIER FIX WAS A DIFFERENT CASE: v17.10's
		// swap_shield refill covers a card taken while you are HOLDING a shield.
		// A card taken while the shield was BROKEN fell in here, where the only
		// effect was re-deriving the deadline at the new rate — so it appeared
		// to work exactly when that new deadline had already passed (a big
		// level jump, or a break most of the way through the wait) and did
		// nothing at all when it had not. That is the whole intermittency.
		//
		// `improved` is what keeps the recharge meaningful: it is true only when
		// the HP NUMBER went up since the last reconcile, which no routine
		// caller can do. The 2 s maintain loop, every respawn and every reload
		// of this lane still fall through to the shortening below, so a broken
		// shield still has to wait — unless the player earned a card.
		if ( improved )
		{
			self.tod_shield_recharge_until = undefined;
			self.tod_shield_broke_at = undefined;
			// Stop the counter BEFORE the give: recharge_loop endon's this and
			// owns the ordinary return, and two owners handing out one shield is
			// the inventory-overflow trap. The give below is the return now.
			self notify( "tod_shield_recharge_loop" );
		}
		else
		{
			if ( isdefined( self.tod_shield_broke_at ) )
			{
				until = self.tod_shield_broke_at + recharge_ms( lvl, self );
				if ( until < self.tod_shield_recharge_until )
					self.tod_shield_recharge_until = until;
			}
			return;
		}
	}

	want = weapon_for_level( lvl );
	if ( !isdefined( want ) || want == level.weaponNone )
		return;   // asset missing: bail rather than take the slot and give nothing

	// THE DEAD-SHIELD SWEEP (v17.16) — see shield_is_dead(). A weapon sitting in
	// the inventory that stock no longer counts as a shield blocks nothing and
	// shows an empty bar, but it made every reconcile below think the slot was
	// already filled, so neither the recharge nor the 2 s maintain could ever
	// hand a real one back. Reap it and fall through to the give.
	held = self held_shield();
	if ( isdefined( held ) && ( self shield_is_dead() ) )
	{
		self clear_shield( held );
		held = self held_shield();
	}

	if ( isdefined( held ) )
	{
		if ( held != want )
			self swap_shield( held, want );   // the Lv5 model promotion — the re-give refills by construction
		else if ( improved )
			self swap_shield( held, held );   // THE CARD REFILL (see swap_shield)
		// else: already the right shield at the same strength. Its remaining
		// fraction stands.
		return;
	}

	self give_shield( want );
}

// self = player. The whole grant. zm_equipment::buy takes any OTHER equipment
// first, gives, sets the d-pad slot and (isriotshield) runs stock's
// player_shield_reset_health, which repaints the HUD bar to full and refreshes
// the back-stow model — the same call map 1 made, string form and all.
function give_shield( w )
{
	self.tod_shield_given_ms = GetTime();   // opens the grace window (see shield_is_dead)
	self zm_equipment::buy( w );
	self install_scaler();
	self.tod_shield_given_ms = GetTime();   // buy yields a frame inside UpdateRiotShieldModel; stamp the LANDING
	self notify( "tod_shield_given", w );
}

// self = player. TAKE THE SHIELD AND HAND IT STRAIGHT BACK. Two callers, one
// mechanism:
//   * the Lv5 model promotion (old_w != new_w — the base shield becomes the
//     cyber shield in place), and
//   * THE CARD REFILL (old_w == new_w), user 2026-09-04: "when you receive a
//     Riot Shield card upgrade and you already have one it should refill the
//     health on your existing one with the health it just got improved to".
// The re-give IS the refill, and it is the only one available: the engine pool
// has no setter (DamageRiotShield only burns it — the header's point 1), and
// stock's player_shield_reset_health repaints the HUD bar to 1.0 WITHOUT
// touching that pool, so calling it alone would draw a full bar over a shield
// that is one hit from breaking. zm_equipment::take clears current_equipment,
// which is what lets the following buy's give() past its "already has it"
// early-out; buy then re-runs player_shield_reset_health for the bar.
// The latch makes break_watch ignore the stock notify that a take can raise,
// so neither a promotion nor a refill is ever read as a break and neither
// starts a recharge.
function swap_shield( old_w, new_w )
{
	self.tod_shield_swapping = true;
	self.tod_shield_given_ms = GetTime();
	// zm_equipment::take switches back to the primary itself when the shield is
	// the current weapon, clears the slot and TakeWeapons it — no destroy path.
	self zm_equipment::take( old_w );
	self zm_equipment::buy( new_w );
	self install_scaler();
	self.tod_shield_given_ms = GetTime();
	self.tod_shield_swapping = undefined;
	self notify( "tod_shield_given", new_w );
}

// self = player. IS THE THING IN THE SLOT ACTUALLY A SHIELD? (v17.16)
//
// TWO SOURCES, AND THE DISAGREEMENT IS THE BUG. held_shield() reads the
// inventory — the truth about what GiveWeapon handed out. Stock's
// `self.hasRiotShield` is the truth about whether the ENGINE still treats it as
// a shield: `player_take_riotshield` clears it on every break, before it calls
// `zm_equipment::take`. If that take does not land — it early-outs on a weapon
// the player "does not have", and it is aimed at `self.weaponRiotshield`, a
// field stock recomputes on a delayed `WAIT_SERVER_FRAME` — the weapon STAYS in
// the inventory with the flags cleared. That is a shield that blocks nothing,
// draws an empty bar, and (before this) made reconcile() see a full slot
// forever, so neither the recharge nor the maintain could hand a live one back.
// The symptom is exactly "it broke and I never got it back".
//
// Not a proven diagnosis of the user's report — it is the one state consistent
// with it that this module could not previously escape from. Cheap, idempotent,
// and it costs nothing when the two sources agree.
function shield_is_dead()
{
	if ( IS_TRUE( self.tod_shield_swapping ) )
		return false;   // mid take-then-buy; the flags are supposed to be down
	// Trust our own give for a moment: hasRiotShield is set inside
	// UpdateRiotShieldModel, which opens with WAIT_SERVER_FRAME.
	if ( isdefined( self.tod_shield_given_ms ) && GetTime() - self.tod_shield_given_ms < TOD_SHIELD_GIVE_GRACE_MS )
		return false;
	return !IS_TRUE( self.hasRiotShield );
}

// self = player. Get a shield OUT of the inventory, whatever state it is in.
// zm_equipment::take is the front door and clears the equipment slot with it;
// the raw TakeWeapon behind it exists for the case take() itself early-outs
// (that is the failure this whole lane is here to survive), and the slot is
// then cleared by hand so the next zm_equipment::buy cannot early-out on
// "already has it".
function clear_shield( w )
{
	self.tod_shield_swapping = true;   // a take must never read as a break
	self zm_equipment::take( w );
	if ( isdefined( self held_shield() ) )
	{
		self TakeWeapon( w );
		self zm_equipment::set_player_equipment( level.weaponNone );
	}
	self.tod_shield_swapping = undefined;
}

// The shield weapon this player holds right now, or undefined. Read off the
// inventory directly: stock's self.hasRiotShield is refreshed a server frame
// after a weapon change and can lag a give by a tick.
function held_shield()   // self = player
{
	weapons = self GetWeaponsList( true );
	foreach ( w in weapons )
	{
		if ( isdefined( w ) && IS_TRUE( w.isriotshield ) )
			return w;
	}
	return undefined;
}

// ---------------------------------------------------------------------------
// HEALTH — the effective-HP scaler (map 1's acc_shield_damage, level-keyed)
// ---------------------------------------------------------------------------
function install_scaler()   // self = player
{
	self.player_shield_apply_damage = &shield_damage;
}

// self = player. Stock calls this with the BLOCKED part of every hit
// (_zm_weap_riotshield::player_damage_override_callback). Scale it so the
// engine's fixed pool behaves like shield_hp( level ), then hand it to the
// stock rocket-shield function, which keeps SoE's explosive x3 and then runs
// riotshield::player_damage_shield: DamageRiotShield, rumble, the HUD fraction,
// and the break (player_take_riotshield) when the pool hits zero.
function shield_damage( iDamage, bHeld, fromCode = false, smod = "MOD_UNKNOWN" )
{
	lvl = tod_upgrades::get_level( self, TOD_SHIELD_DOMAIN );
	hp = shield_hp( lvl, self );
	full = pool_size();
	scaled = iDamage;
	if ( hp > 0 && full > 0 && iDamage > 0 )
	{
		scaled = int( iDamage * full / hp );
		if ( scaled < 1 )
			scaled = 1;
	}
	self rocketshield::player_damage_rocketshield( scaled, bHeld, fromCode, smod );
}

// The engine pool behind the shield this player holds (weaponStartHitPoints of
// the held form — 1850 on the stock shield, 1500 on Logical's), or of the form
// the level wants when nothing is held yet.
function pool_size()   // self = player
{
	w = self held_shield();
	if ( !isdefined( w ) )
		w = weapon_for_level( tod_upgrades::get_level( self, TOD_SHIELD_DOMAIN ) );
	if ( isdefined( w ) && w != level.weaponNone && isdefined( w.weaponstarthitpoints ) )
		return w.weaponstarthitpoints;
	if ( isdefined( level.weaponRiotshield ) && isdefined( level.weaponRiotshield.weaponstarthitpoints ) )
		return level.weaponRiotshield.weaponstarthitpoints;
	return 0;
}

// ---------------------------------------------------------------------------
// BREAK -> RECHARGE -> RETURN
// ---------------------------------------------------------------------------
// "destroy_riotshield" is the first line of stock's player_take_riotshield,
// which player_damage_shield threads the moment the pool hits zero. Stock then
// switches you off the shield, plays its two break sounds and takes it.
function break_watch()   // self = player
{
	self endon( "disconnect" );
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( "destroy_riotshield" );

		if ( IS_TRUE( self.tod_shield_swapping ) )
			continue;   // a Lv5 promotion, not a break
		lvl = tod_upgrades::get_level( self, TOD_SHIELD_DOMAIN );
		if ( lvl <= 0 )
			continue;   // not ours (nothing else hands out a shield today, but never assume)
		if ( isdefined( self.tod_shield_recharge_until ) )
			continue;   // already counting — a double notify must not restart the clock

		if ( isdefined( self.origin ) )
			PlaySoundAtPosition( TOD_SHIELD_BREAK_SND, self.origin );
		self.tod_shield_broke_at = GetTime();
		self.tod_shield_recharge_until = self.tod_shield_broke_at + recharge_ms( lvl, self );
		// NO ON-SCREEN TEXT ON THE BREAK (user 2026-09-04: "riot shield shows
		// diaplyed text on screen when its broken. IT already makes a sound so I
		// wnat to remove the on screen text"). TOD_SHIELD_BREAK_SND above is the
		// tell, and it fires two lines up — the print was a second announcement of
		// the same event, in the middle of the fight that just broke the shield.
		// The RECHARGED print at the end of recharge_loop() is deliberately left
		// alone: it was not what was reported, and unlike the break it announces a
		// state the player cannot otherwise see coming.
		self thread recharge_loop();
	}
}

// self = player. Counts down the deadline — through a down, a death and a
// respawn (the deadline is entity state and this loop ends only on disconnect)
// — then hands the shield back the first moment the player is alive and on
// their feet. Single instance per player.
function recharge_loop()
{
	self notify( "tod_shield_recharge_loop" );
	self endon( "tod_shield_recharge_loop" );
	self endon( "disconnect" );
	level endon( "end_game" );

	while ( isdefined( self.tod_shield_recharge_until ) && GetTime() < self.tod_shield_recharge_until )
		wait 0.5;

	self.tod_shield_recharge_until = undefined;
	self.tod_shield_broke_at = undefined;

	while ( !isdefined( self ) || !IsAlive( self ) || ( self laststand::player_is_in_laststand() ) )
		wait 0.5;

	lvl = tod_upgrades::get_level( self, TOD_SHIELD_DOMAIN );
	if ( lvl <= 0 )
		return;   // lost the domain while recharging (a promotion cannot do that — scope class — but the guard is free)

	// THE RETURN VERIFIES ITSELF (v17.16). This is the one call in the module
	// the player is WAITING on — up to four minutes of it — so it does not
	// simply fire a reconcile and trust it. Reconcile, look, and try again:
	// every give path downstream (zm_equipment::buy -> give) has early-outs that
	// return silently, and a silent no-op here is a shield that never comes
	// back. The maintain loop would eventually cover it, but only for the
	// failures the sweep can see; this covers the rest.
	for ( i = 0; i < TOD_SHIELD_RETURN_TRIES; i++ )
	{
		self reconcile();
		wait TOD_SHIELD_RETURN_WAIT;
		if ( !isdefined( self ) || !IsAlive( self ) )
			return;
		if ( isdefined( self held_shield() ) && !( self shield_is_dead() ) )
			break;
		/# PrintLn( "^3[tod] riotshield: recharge return did not land (try " + ( i + 1 ) + ") — retrying" ); #/
	}

	// NO ON-SCREEN TEXT HERE EITHER (user 2026-09-04, same call as the break).
	// The sound is the whole tell now — both aliases verified registered in
	// sound/aliases/tod_ui.csv with wavs on disk (tod_shield_break 3d vol 92,
	// tod_lounge_arrive 2d vol 90), so neither removal leaves a silent event.
	//
	// ⚠️ BUT TOD_SHIELD_BACK_SND IS A SHARED ALIAS, NOT A SHIELD SOUND. It is
	// "tod_lounge_arrive", the breather-lounge first-arrival chime, also played
	// by _tod_atmosphere (every lounge) and _tod_spire:1692. That was harmless
	// while a line of text said which event had just happened; with the text
	// gone the chime is the ONLY signal, and the same arpeggio now means both
	// "your shield is back" and "you reached a lounge". Worth its own wav.
	self PlayLocalSound( TOD_SHIELD_BACK_SND );
}

// ---------------------------------------------------------------------------
// ELITE KILLS SHORTEN THE RECHARGE (v17.16)
// ---------------------------------------------------------------------------
// PUBLIC, called through level.tod_shield_elite_kill from
// _tod_bosses::grant_elite_reward — the one function every elite death already
// runs through, and the one that already decides the kill belongs to exactly
// one player. So the rule matches the money's: THE KILLER, and nobody else.
//
// DARK ONLY (the user's second message, same day). This is a term of the dark
// upgrade, so it reads the SAME has_dark() bit shield_hp and recharge_secs do
// — one source, and a Lv5 holder who has not taken the dark card is refused
// here exactly as they are refused the 700 HP. Because a dark card is only ever
// dealt on a maxed domain, and dark cards only deal in the spire, in practice
// this pays on the Warden Trials and the spire climb — where the recharge it is
// shortening is already the shortest one in the game (1:30) and elites are the
// thing you are fighting.
//
// It shortens a recharge that is RUNNING and does nothing otherwise — there is
// no bank, because there is nothing to spend it on while you are carrying the
// shield. Cutting past the deadline is fine and is the point: the recharge loop
// polls twice a second, sees the deadline behind it, and hands the shield
// straight back. Four elites inside one trial take 8 s off 90.
function elite_kill( player )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return;
	if ( !isdefined( player.tod_shield_recharge_until ) )
		return;   // not recharging — nothing to shorten
	if ( tod_upgrades::get_level( player, TOD_SHIELD_DOMAIN ) <= 0 )
		return;
	if ( !tod_upgrades::has_dark( player, TOD_SHIELD_DOMAIN ) )
		return;   // a term of the DARK rung, not of the ladder

	player.tod_shield_recharge_until = player.tod_shield_recharge_until - ( TOD_SHIELD_ELITE_CUT_SECS * 1000 );
}

// ---------------------------------------------------------------------------
// the ladder
// ---------------------------------------------------------------------------
function shield_hp( lvl, player )
{
	// DARK UPGRADE (v17.10): 500 -> 700 HP. An ABSOLUTE value, not a step -- the
	// ladder is authored as literals and the dark rung is authored the same way.
	if ( isdefined( player ) && tod_upgrades::has_dark( player, TOD_SHIELD_DOMAIN ) )
		return TOD_DARK_SHIELD_HP;
	if ( lvl >= 5 ) return TOD_SHIELD_HP_L5;
	if ( lvl == 4 ) return TOD_SHIELD_HP_L4;
	if ( lvl == 3 ) return TOD_SHIELD_HP_L3;
	if ( lvl == 2 ) return TOD_SHIELD_HP_L2;
	return TOD_SHIELD_HP_L1;
}

function recharge_secs( lvl, player )
{
	if ( IS_TRUE( level.tod_dev ) )
		return TOD_SHIELD_DEV_RECHARGE;
	// DARK UPGRADE (v17.10): 2:00 -> 1:15 back from a break (1:30 until 2026-09-05).
	if ( isdefined( player ) && tod_upgrades::has_dark( player, TOD_SHIELD_DOMAIN ) )
		return TOD_DARK_SHIELD_RECHARGE_SECS;
	if ( lvl >= 5 ) return TOD_SHIELD_RECHARGE_L5;
	if ( lvl == 4 ) return TOD_SHIELD_RECHARGE_L4;
	if ( lvl == 3 ) return TOD_SHIELD_RECHARGE_L3;
	if ( lvl == 2 ) return TOD_SHIELD_RECHARGE_L2;
	return TOD_SHIELD_RECHARGE_L1;
}

function recharge_ms( lvl, player )
{
	return int( recharge_secs( lvl, player ) * 1000 );
}

// The weapon a level wears. Lv5 = the cyber shield IF it made the .ff (init
// logs when it did not); every lower level, and the fallback, is the stock one.
function weapon_for_level( lvl )
{
	if ( lvl >= TOD_SHIELD_MAX_LVL )
	{
		w = GetWeapon( TOD_SHIELD_W_MAX );
		if ( isdefined( w ) && w != level.weaponNone )
			return w;
	}
	return GetWeapon( TOD_SHIELD_W_BASE );
}

// PUBLIC — seconds left on this player's recharge, 0 when not recharging.
// (For any HUD/readout that wants it; nothing consumes it yet.)
function recharge_left( player )
{
	if ( !isdefined( player.tod_shield_recharge_until ) )
		return 0;
	left = ( player.tod_shield_recharge_until - GetTime() ) / 1000;
	if ( left < 0 )
		left = 0;
	return left;
}
