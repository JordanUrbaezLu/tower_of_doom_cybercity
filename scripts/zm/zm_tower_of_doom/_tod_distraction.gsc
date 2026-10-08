// =============================================================================
// _tod_distraction.gsc — DISTRACTION, the ASSAULT's thrown-decoy upgrade
//
// v16.49 (user 2026-09-02): "change the distraction upgrade so now it only is
// cymbal monkeys and also what it does is increases the max number of cymbal
// monkeys you can hold. tier 1 is 1, tier 2 is 2, etc. And this goes up to 3.
// And we need to make sure a max ammo gives only 1 no matter what tier."
//
// HOW IT PLAYS
//   ONE WEAPON, THE CYMBAL MONKEY, and the LEVEL IS THE CARRY CAP: Lv1 holds 1,
//   Lv2 holds 2, Lv3 holds 3 (domain max 3). The first level hands you one
//   monkey; every level after that opens one more slot AND fills it (a card
//   that says "carry one more" and hands you nothing would read as a dud).
//   MAX AMMO adds exactly ONE, at every level, capped at the level — never a
//   refill, which takes an explicit opt-out from stock's powerup; see
//   on_max_ammo(). The v14.59-v16.48 form (Lv1 monkey, Lv2 Li'l Arnies, flat
//   cap 3) is GONE: the octobomb is no longer registered, granted or opted out
//   here, and nothing else in the map hands it out.
//
// WHY A MODULE, AND WHY LEVEL-DRIVEN RATHER THAN A CARD HOOK
//   A grenade is INVENTORY, and inventory does not survive a spawn. Stock's
//   init_player_offhand_weapons nulls the tactical slot pointer on EVERY
//   "spawned_player"; usermaps never set level.zombie_tactical_grenade_player_init,
//   so the slot is weaponNone every life. _tod_classes::give_class_loadout
//   re-gives only the primary, the alt melee and the sidearm — it never looks at
//   a domain.
//   Worse, THREE paths write a domain level without ever calling apply_upgrade:
//   tier_up's reset loop, tier_up's grant field, and _tod_spire::grant_all. A
//   one-shot "on card pick" hook is skipped by all three, and an ascended spire
//   player would end up with a maxed domain and no grenade.
//   So the effect is a RECONCILE — read the level, make the inventory match.
//   It is idempotent and every one of those paths lands by construction.
//
// THREE ENGINE TRAPS, ALL PAID FOR ON MAP 1 (docs/09, _acc_boss_items.gsc)
//   1. Raw GiveWeapon does NOT ARM the grenade. The thrown behaviour is threaded
//      by the registered zombie-weapon callback, and zm_weapons::weapon_give is
//      the only stock path that dispatches it. We dispatch it by hand. Without
//      this the projectile lands and just sits there — no error, no tell.
//   2. get_player_tactical_grenade() returns level.weaponNone, NEVER undefined.
//      An isdefined() guard alone is a no-op that TakeWeapon(weaponNone)s.
//      Test `!= level.weaponNone` as well, always.
//   3. Re-assert set_player_tactical_grenade EVERY time. HasWeapon can be TRUE
//      while the slot pointer is dead — a state where the player holds the
//      grenade and the throw does nothing. Never skip the re-assert on an
//      `if ( HasWeapon ) return;` fast path.
//   (The fourth trap — register_tactical_grenade_for_level for the octobomb —
//   retired with the octobomb. Stock zm_usermap.gsc:173 already registers the
//   cymbal_monkey, so this module registers nothing.)
//
// COSTS NOTHING TO INCLUDE. The monkey is already included via
// gamedata/weapons/zm/zm_levelcommon_weapons.csv (row `cymbal_monkey`), and
// stock zm_usermap already #using's _zm_weap_cymbal_monkey on BOTH VMs — so
// this feature adds ZERO clientfields, ZERO zone weapon lines and ZERO weapon
// registrations against the ~230 twin ceiling.
//   *** DO NOT add a `weapon,cymbal_monkey_zm` .zone line. *** No GDT on this
//   box defines the asset, so the link hard-fails with "Unable to load weapon".
//   The CSV row IS the inclusion lane. Do not "tidy" that row or _zm-suffix it
//   either (memory: weapons-csv-zm-suffix-mismatch).
//
// Domain id 41 in _tod_upgrade_ui::domain_id + tod_upgrade.lua DOMAIN/DETAIL
// (ids are APPEND-ONLY; 40 is PERK SLOTS). This module imports _tod_upgrades for
// get_level — _tod_upgrades never imports us (the KB cycle rule). Same for
// _tod_powerups, which reaches us through level.tod_distract_max_ammo.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_powerups;   // set_weapon_ignore_max_ammo (the +1 ladder)
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_tower_of_doom\_tod_upgrades;   // get_level

#insert scripts\shared\shared.gsh;

#define TOD_DISTRACT_DOMAIN     "distraction"
#define TOD_DISTRACT_W          "cymbal_monkey"   // the ONLY weapon this domain hands out

// CARRY RULES (v16.49). THE LEVEL IS THE CAP: carry = min( level, TOD_DISTRACT_MAX_CARRY ).
// Granted at TOD_DISTRACT_GRANT on the first level; each further level adds one
// slot and one monkey (see reconcile); MAX AMMO adds TOD_DISTRACT_MAXAMMO_ADD,
// clamped to the level's cap. TOD_DISTRACT_MAX_CARRY is a SAFETY ceiling that
// must equal the domain's max in _tod_upgrades::add_domain (3) — it is also the
// weapon's own baked ceiling, measured 2026-09-01: stock GiveMaxAmmo tops the
// monkey to exactly 3, so a level above 3 could never be paid anyway.
// LOCKSTEP: add_domain( "distraction", ..., 3, ... ) / DOMAIN[41].max / the
// three-pip card art.
#define TOD_DISTRACT_GRANT       1
#define TOD_DISTRACT_MAX_CARRY   3
#define TOD_DISTRACT_MAXAMMO_ADD 1

// Stock re-runs init_player_offhand_weapons on EVERY spawn dispatch, and a co-op
// bleed-out respawn dispatches "spawned_player" TWICE (_zm.gsc spectator_respawn,
// then _globallogic_spawn.gsc spawnPlayer, which the custom path returns into).
// give_class_loadout waits 0.5 for the same reason; we wait fractionally longer
// so the reconcile always lands on top of a settled loadout rather than racing it.
#define TOD_DISTRACT_SPAWN_WAIT  0.6

#namespace tod_distraction;

function init()
{
	// THE MAX-AMMO OPT-OUT — half of the +1 ladder, and the half with no tell.
	// Stock full_ammo_powerup walks GetWeaponsList( true ), which INCLUDES the
	// offhands, and GiveMaxAmmo's each one to its baked cap. Without this the
	// player is already topped to full before our on_max_ammo() ever runs, so an
	// incremental rule is INVISIBLE rather than broken — the exact shape of bug
	// that reads as "the code does nothing". That is what shipped in v14.20 and
	// what the user saw as "max ammo is giving 3".
	//
	// The stock skip is keyed on the weapon NAME string
	// (_zm_powerup_full_ammo.gsc: level.zombie_weapons_no_max_ammo[ w.name ]),
	// NOT on the weapon struct — pass the same bare name the CSV row uses.
	zm_powerups::set_weapon_ignore_max_ammo( TOD_DISTRACT_W );

	// THE CALL-IN POINTER. _tod_upgrades must be able to re-run our reconcile
	// after it writes a level (card pick, tier promotion, spire grant) — but it
	// can NEVER #using this module, because we import IT for get_level and the
	// KB cycle rule forbids the loop. A level function pointer is the shipped
	// idiom for exactly this (level.tod_finale_boss_fn,
	// level.closest_player_override).
	//
	// Every caller MUST guard on isdefined, so this module staying unregistered
	// (or being removed entirely) degrades to "the grenade only reconciles on
	// spawn" rather than to a crash.
	level.tod_distract_reconcile = &reconcile;

	// SAME REASON, SECOND POINTER: _tod_powerups owns the "zmb_max_ammo" watcher
	// and cannot #using this module either (_tod_upgrades #usings _tod_powerups,
	// and we #using _tod_upgrades — powerups -> us would close the loop).
	level.tod_distract_max_ammo = &on_max_ammo;

	callback::on_spawned( &on_player_spawned );
}

// self = player. One watcher per player for the whole game.
function on_player_spawned()
{
	// RESPAWN LATCH, in the FUNCTION and not at the registration site, so it
	// covers any future caller. callback::callback THREADS every registered func
	// on every dispatch, and the double dispatch above would otherwise stack a
	// second immortal watcher per life. Same shipped idiom as _tod_runandgun,
	// _tod_uniques, _tod_luck and _tod_powerups::max_ammo_clip_watch. The field
	// survives death because the ZM player entity is never deleted. Do NOT use
	// callback::remove_on_spawned — it deregisters for EVERY player.
	if ( IS_TRUE( self.tod_distract_watch_on ) )
	{
		// Already watching, but THIS dispatch is still a fresh life whose
		// tactical slot stock has just nulled — reconcile it and return.
		self thread respawn_reconcile();
		return;
	}
	self.tod_distract_watch_on = true;
	self thread respawn_reconcile();
}

// One-shot per spawn dispatch: wait for the stock loadout to settle, then make
// the inventory match the level. Waits once and returns, so it needs no latch of
// its own (same shape as give_class_loadout).
function respawn_reconcile()   // self = player
{
	self endon( "disconnect" );
	level endon( "end_game" );

	wait TOD_DISTRACT_SPAWN_WAIT;

	if ( !isdefined( self ) || !IsAlive( self ) )
		return;

	self reconcile();
}

// THE ONE OWNER. Idempotent — read the domain level, make the tactical slot
// match it. Safe to call from anywhere, any number of times, at any level
// including 0. Called on every spawn, and by _tod_upgrades after a card pick,
// a tier promotion and the spire grant.
//
// WHAT "MATCH" MEANS NOW THAT THE LEVEL IS THE CAP:
//   - not held (fresh life, first grant)      -> give TOD_DISTRACT_GRANT (1)
//   - held, level unchanged since last look   -> re-assert the pointer, keep count
//   - held, level ROSE by d since last look   -> count + d, clamped to the cap
// The "since last look" is self.tod_distract_lvl_seen, stamped here and only
// here. It is per-player state on an entity that is never deleted, so it
// survives death — which is what we want: a bleed-out respawn re-grants ONE
// monkey (the old life's ammo is gone with the old life), it does not re-pay
// every level the player already cashed. A revive keeps the count because
// stock stashes and restores the tactical clip across last stand.
function reconcile()   // self = player
{
	if ( !isdefined( self ) || !IsAlive( self ) )
		return;

	lvl = tod_upgrades::get_level( self, TOD_DISTRACT_DOMAIN );
	if ( lvl <= 0 )
		return;   // never owned it — leave the slot exactly as we found it

	w = GetWeapon( TOD_DISTRACT_W );
	if ( !isdefined( w ) || w == level.weaponNone )
		return;   // asset missing: bail rather than take the slot and give nothing

	seen = 0;
	if ( isdefined( self.tod_distract_lvl_seen ) )
		seen = self.tod_distract_lvl_seen;
	self.tod_distract_lvl_seen = lvl;

	cur = self zm_utility::get_player_tactical_grenade();
	holding = ( isdefined( cur ) && cur == w && self HasWeapon( w ) );

	if ( holding )
	{
		// Already holding the monkey. Re-assert the pointer (TRAP 3) and pay
		// out any levels gained since the last reconcile: every new slot comes
		// filled. clamp_carry keeps a stale seen (or a raised cap) honest.
		self zm_utility::set_player_tactical_grenade( w );
		held = self ammo_count( w );
		if ( lvl > seen )
			self set_ammo_count( w, clamp_carry( held + ( lvl - seen ), lvl ) );
		return;
	}

	// Not holding it. FIRST GRANT (never seen a level before): every slot the
	// card opened comes filled, so a SUPER at Lv0 hands you 2, not 1. FRESH
	// LIFE (seen a level before, weapon gone with the old life): the base grant,
	// plus one per level gained while it was gone. If some OTHER tactical is in
	// the slot (nothing in this map puts one there today), its count is carried
	// across so an upgrade never reads as a downgrade.
	if ( seen <= 0 )
		count = lvl;
	else
		count = TOD_DISTRACT_GRANT + ( ( lvl > seen ) ? ( lvl - seen ) : 0 );
	if ( isdefined( cur ) && cur != level.weaponNone && self HasWeapon( cur ) )
	{
		held = self ammo_count( cur );
		if ( held > count )
			count = held;
	}

	self give( w, clamp_carry( count, lvl ) );
}

// self = player. The COMPLETE grant. Mirrors map 1's give_monkey_bomb.
function give( w, count )
{
	// TRAP 2 — get_player_tactical_grenade returns weaponNone, never undefined.
	// Both halves of this test are load-bearing.
	cur = self zm_utility::get_player_tactical_grenade();
	if ( isdefined( cur ) && cur != level.weaponNone )
		self TakeWeapon( cur );

	// The engine does not auto-replace one tactical with another — Treyarch's own
	// note in _zm_weap_cymbal_monkey.gsc reads "was not correctly replacing the
	// regular monkeys until they were manually taken", and both stock give
	// functions take before they give. The TakeWeapon above is that.
	self GiveWeapon( w );
	self zm_utility::set_player_tactical_grenade( w );   // TRAP 3
	self set_ammo_count( w, count );

	// TRAP 1 — ARM IT. Raw GiveWeapon bypasses zm_weapons::weapon_give, the only
	// stock path that dispatches the registered zombie-weapon callback (the
	// per-player grenade_fire watcher). Without this the thrown grenade is inert.
	// The watcher self-guards with its own notify/endon, so re-dispatching on
	// every respawn is safe.
	if ( isdefined( level.zombie_weapons_callbacks ) && isdefined( level.zombie_weapons_callbacks[ w ] ) )
		self thread [[ level.zombie_weapons_callbacks[ w ] ]]();
}

// ---------------------------------------------------------------------------
// MAX AMMO GIVES +1, NEVER A REFILL, AT EVERY LEVEL (user 2026-09-01 / 2026-09-02)
// ---------------------------------------------------------------------------
// "a max ammo will give only 1 but the max that can be held is 3" and now "make
// sure a max ammo gives only 1 no matter what tier". The decoy is a scarce
// resource you ration, not a magazine you top up; the level only decides how
// many you can ration.
//
// TWO HALVES, AND ONLY THE PAIR WORKS:
//   (a) init() calls set_weapon_ignore_max_ammo on the weapon name, so stock's
//       full_ammo_powerup skips it entirely. Without (a) this function still
//       runs and still "succeeds" — it just adds +1 to a count stock has already
//       maxed, so the clamp eats it and nothing changes. AN INCREMENT ON TOP OF
//       A REFILL IS INVISIBLE, not broken; do not read a working on_max_ammo()
//       as proof the ladder is live.
//   (b) this function, called from _tod_powerups::max_ammo_clip_watch through
//       level.tod_distract_max_ammo after its 0.05s "let stock finish" wait.
//
// WHY IT RIDES THE EXISTING WATCHER rather than adding a second "zmb_max_ammo"
// waittill: one notify with two independent listeners is two race-prone orderings
// against the same 0.05s settle. The clip watcher already owns that wait, already
// has the respawn latch, and already runs at exactly the right moment.
//
// LEVEL-GATED, NOT INVENTORY-GATED. A player who does not own the domain gets
// nothing — we never hand out a grenade from a powerup, only top up one the
// upgrade already granted. HasWeapon is checked too: mid-life the slot can be
// live while the weapon is gone (see reconcile), and SetWeaponAmmoClip on a
// weapon the player does not hold is a silent no-op that would read as success.
function on_max_ammo()   // self = player
{
	if ( !isdefined( self ) || !IsAlive( self ) )
		return;

	lvl = tod_upgrades::get_level( self, TOD_DISTRACT_DOMAIN );
	if ( lvl <= 0 )
		return;

	w = self zm_utility::get_player_tactical_grenade();
	if ( !is_ours( w ) || !self HasWeapon( w ) )
		return;   // not ours (or not held) — never touch another system's tactical

	held = self ammo_count( w );
	want = clamp_carry( held + TOD_DISTRACT_MAXAMMO_ADD, lvl );

	// Raise-only. clamp_carry has a FLOOR of 1, so on an already-capped player
	// want == held and this is a no-op; the guard is here so that a level CUT
	// (or a future cap cut) can never turn a Max Ammo grab into a confiscation.
	if ( want > held )
		self set_ammo_count( w, want );
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

function is_ours( w )
{
	if ( !isdefined( w ) || w == level.weaponNone )
		return false;
	return ( w == GetWeapon( TOD_DISTRACT_W ) );
}

// The carry cap at a level: the level itself, under the safety ceiling.
function carry_cap( lvl )
{
	if ( lvl < 1 )                        return 1;
	if ( lvl > TOD_DISTRACT_MAX_CARRY )   return TOD_DISTRACT_MAX_CARRY;
	return lvl;
}

function clamp_carry( n, lvl )
{
	cap = carry_cap( lvl );
	if ( n < 1 )     return 1;
	if ( n > cap )   return cap;
	return n;
}

// ONE SITE EACH for the ammo read/write, deliberately — and they are the CLIP,
// not the stock (changed 2026-09-01 with the +1 ladder).
//
// EVERY STOCK TACTICAL-GRENADE COUNT IS A CLIP. Three independent sites, all in
// the shipped tree:
//   zm_usermap.gsc:185   SetWeaponAmmoClip( get_player_tactical_grenade(), 0 )
//   _zm.gsc:3201/3219    the last-stand stash SAVES and RESTORES the tactical
//                        count with GetWeaponAmmoClip / SetWeaponAmmoClip
//   _zm.gsc:1824/4576+   the same for the lethal grenade
// There is no stock site anywhere that touches an offhand's STOCK. The weapon-
// stat GDT still is not on this box, so this is read off stock's own usage
// rather than off the asset — but three writers and zero counter-examples is a
// different class of evidence than the SetWeaponAmmoStock guess it replaced
// (map 1's lane, which "worked" only because map 1 handed the grenade out full).
//
// THIS IS THE FIRST THING TO SUSPECT if the ladder reads as dead in game: the
// tell is Max Ammo doing NOTHING at all (a wrong store makes the read return 0
// forever and the write land nowhere), as opposed to Max Ammo still refilling to
// full, which would instead mean the set_weapon_ignore_max_ammo in init() did
// not take.
function ammo_count( w )        // self = player
{
	return self GetWeaponAmmoClip( w );
}

function set_ammo_count( w, n ) // self = player
{
	self SetWeaponAmmoClip( w, n );
}
