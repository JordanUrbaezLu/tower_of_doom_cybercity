// WISP TEA — BO7 perk, vendored from WetEgg's SATPerksCode pack (2026-08-30,
// replaces Deadshot in the scatter roster). Machine + wisp models ride the
// SATPerksAssets install (root _custom\_wetegg\models\sat\sat_zm_machine_w_mod);
// jingle/stinger/powerloop aliases live in sound/aliases/tod_wisp_tea.csv.
// Mechanics: hitting zombies rolls 1-in-WISP_TEA_WISP_SPAWN_CHANCE to summon a
// wisp companion (a script_model, NOT an AI actor — no behaviour-tree cost)
// that chases and melee-kills zombies near the owner for WISP_TEA_WISP_DURATION
// seconds, then cools down. Up to WISP_TEA_MAX_WISPS can be out at once and
// they seek the highest-tier target in range (delta 6). Rides an unused engine specialty
// (specialty_nomotionsensor) exactly like Death Perception rides
// specialty_combat_efficiency — HasPerk/SetPerk work natively.
//
// TOWER DELTAS vs the pack file (keep this list current if the pack updates):
// 1. HINT: the pack's localized &"PERKMACHINES_WISP_TEA" ref (needed a .str
//    install) is now the EC-style LITERAL hint with the &&1 cost substitution
//    — ONE new triggerstring slot, same as every other perk here.
// 2. Machine animations are restored in _tod_perk_anims (2026-09-09), using
//    stock perk_purchased and movement-safe idle/purchase sequencing. The
//    off/on model pair remains registered here; no pack _zm_perks override.
// 3. LEAK FIXES: the pack never Deleted wisp.wispFXModel (one orphaned
//    tag_origin per summon), and the disconnect/bled_out exits from
//    wispFunctionality left the wisp entity alive forever. Both paths now
//    clean up — on an endless-rounds map those leaks compound into the
//    gentity budget (the spire's binding constraint).
// 4. "stopWispLookAt" notify/endon case mismatch fixed (the pack's endon said
//    "stopWispLookat", so every follow tick stacked another angles-writer
//    thread for the wisp's whole life).
// 5. sprintf() in take_wisp_tea_perk replaced with plain concat.
// 6. TWO WISPS AT ONCE + BOSS-SEEKING (v17.8, user 2026-09-03). The pack was
//    single-wisp by construction in three separate places and all three had
//    to move together: a per-player BOOLEAN cooldown, a per-player
//    "wispExpired" notify that the follow/attack loops endon (with two wisps
//    out, the first to expire retired BOTH), and one hardcoded idle offset.
//    Cooldown is now CHARGES (WISP_TEA_MAX_WISPS, each refunded
//    WISP_TEA_COOLDOWN_TIME after its own wisp expires), the expiry notify
//    moved onto the WISP entity, and each wisp claims a free parking slot.
//    Targeting went from "closest axis actor" to "highest tier in range,
//    nearest within tier" over the same ladder wisp_hit_damage() already
//    used -- see wispPickTarget for why the pack's zombie-count gate had to
//    stop applying to bosses.

#using scripts\zm\gametypes\_globallogic_score;
#using scripts\shared\clientfield_shared;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\callbacks_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_perk_wisp_tea.gsh;

#precache("fx", WISP_TEA_MACHINE_LIGHT_FX);
#precache("model", WISP_TEA_MACHINE_ACTIVE_MODEL);
#precache("model", WISP_TEA_MACHINE_DISABLED_MODEL);
#precache("model", WISP_TEA_WISP_MODEL);

#namespace zm_perk_wisp_tea;

REGISTER_SYSTEM("zm_perk_wisp_tea", &__init__, undefined)

function __init__()
{
	enable_wisp_tea_perk_for_level();

	callback::on_connect(&registerStats);

	zm::register_actor_damage_callback(&wispTeaDamageMonitor);
	zm::register_vehicle_damage_callback(&wispTeaDamageMonitor);
}

// Read-only damage monitor (returns -1 always — doctrine). attacker rolls the
// wisp chance on every damaging hit while holding the perk and holding at
// least one unspent summon (wisp_can_spawn — a charge AND a free slot).
function wispTeaDamageMonitor(inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex, surfacetype)
{
	if(!isPlayer(attacker) || !attacker HasPerk(WISP_TEA_SPECIALTY))
	{
		return -1;
	}

	chanceToSpawn = RandomIntRange(1,WISP_TEA_WISP_SPAWN_CHANCE + 1);

	// ROLL FIRST, THEN THE GATE (v17.8). && short-circuits, and this is a hot
	// path — every damaging hit in the map from every player holding the perk.
	// wisp_can_spawn() prunes an array; the roll is one compare and rejects 19
	// hits in 20, so it goes on the left.
	if(chanceToSpawn == WISP_TEA_WISP_SPAWN_CHANCE && attacker wisp_can_spawn())
	{
		attacker thread spawnWisp();
	}

	return -1;
}

function registerStats()
{
	self globallogic_score::initPersStat(WISP_TEA_SPECIALTY + "_drank", false);
}

function enable_wisp_tea_perk_for_level()
{
	zm_perks::register_perk_basic_info(WISP_TEA_SPECIALTY, "wisp_tea", WISP_TEA_PERK_COST, "Hold ^3[{+activate}]^7 for Wisp Tea [Cost: &&1]", GetWeapon(WISP_TEA_PERK_BOTTLE_WEAPON));
	zm_perks::register_perk_precache_func(WISP_TEA_SPECIALTY, &wisp_tea_precache);
	zm_perks::register_perk_clientfields(WISP_TEA_SPECIALTY, &wisp_tea_register_clientfield, &wisp_tea_set_clientfield);
	zm_perks::register_perk_machine(WISP_TEA_SPECIALTY, &wisp_tea_perk_machine_setup, &init_wisp_tea);
	zm_perks::register_perk_threads(WISP_TEA_SPECIALTY, &give_wisp_tea_perk, &take_wisp_tea_perk);
	zm_perks::register_perk_host_migration_params(WISP_TEA_SPECIALTY, WISP_TEA_RADIANT_MACHINE_NAME, WISP_TEA_MACHINE_LIGHT_FX_NAME);
}

function init_wisp_tea() {}

function wisp_tea_precache()
{
	if(IsDefined(level.wisp_tea_precache_override_func))
	{
		[[ level.wisp_tea_precache_override_func ]]();
		return;
	}

	level._effect[WISP_TEA_MACHINE_LIGHT_FX_NAME] = WISP_TEA_MACHINE_LIGHT_FX;

	level.machine_assets[WISP_TEA_SPECIALTY] = SpawnStruct();
	level.machine_assets[WISP_TEA_SPECIALTY].weapon = GetWeapon(WISP_TEA_PERK_BOTTLE_WEAPON);
	level.machine_assets[WISP_TEA_SPECIALTY].off_model = WISP_TEA_MACHINE_DISABLED_MODEL;
	level.machine_assets[WISP_TEA_SPECIALTY].on_model = WISP_TEA_MACHINE_ACTIVE_MODEL;
	level.machine_assets[WISP_TEA_SPECIALTY].powerloop = "amb_perk_wisptea_lp";
}

function wisp_tea_register_clientfield()
{
	clientfield::register("clientuimodel", WISP_TEA_CLIENTFIELD, VERSION_SHIP, 2, "int");

	clientfield::register("scriptmover", "wispTeaWispFX", VERSION_SHIP, 1, "int");
}

function wisp_tea_set_clientfield(state)
{
	self clientfield::set_player_uimodel(WISP_TEA_CLIENTFIELD, state);
}

function wisp_tea_perk_machine_setup(use_trigger, perk_machine, bump_trigger, collision)
{
	use_trigger.script_sound = WISP_TEA_JINGLE;
	use_trigger.script_label = WISP_TEA_STING;
	use_trigger.script_string = "wisp_tea_perk";
	use_trigger.target = WISP_TEA_RADIANT_MACHINE_NAME;

	perk_machine.script_string = "wisp_tea_perk";
	perk_machine.targetname = WISP_TEA_RADIANT_MACHINE_NAME;

	if(isdefined(bump_trigger))
	{
		bump_trigger.script_string = "wisp_tea_perk";
	}
}

// [tod v17.8] Charges replace the pack's single wispTeaCooldown boolean.
// Reset-to-full on every give is the SAME behaviour the boolean had (it was
// cleared here too), which matters in the spire: perma_perks_watch re-gives
// the whole roster after every revive and respawn, so a summon spent before a
// down is refunded on the way back up.
// THE LIVE LIST IS DELIBERATELY NOT CLEARED HERE. Charges are the RATE limit
// and a re-give may reset them; the list is the CAP, and clearing it would
// let a re-give with two wisps still in the air put four out at once. Stale
// entries cost nothing -- wisp_live_count() prunes them.
function give_wisp_tea_perk()
{
	self.wispTeaCharges = WISP_TEA_MAX_WISPS;

	if(!isdefined(self.wispTeaWisps))
	{
		self.wispTeaWisps = [];
	}
}

// self = the player. TRUE if another wisp may be summoned right now: a charge
// in hand AND fewer than WISP_TEA_MAX_WISPS actually alive. Both halves are
// needed -- the charge is the RATE limit and the live count is the CAP, and a
// re-give (above) can hand back charges while wisps are still out.
function wisp_can_spawn()
{
	if(!isdefined(self.wispTeaCharges))
	{
		self.wispTeaCharges = WISP_TEA_MAX_WISPS;
	}

	if(self.wispTeaCharges < 1)
	{
		return false;
	}

	return (self wisp_live_count() < WISP_TEA_MAX_WISPS);
}

// self = the player. Counts live wisps by REBUILDING the list from the
// entities themselves, so no counter can drift out of step with the world --
// a spire teardown Delete, a host migration or a re-give mid-summon all just
// prune here. Returns the pruned size and leaves the pruned list behind.
function wisp_live_count()
{
	if(!isdefined(self.wispTeaWisps))
	{
		self.wispTeaWisps = [];
	}

	a_live = [];

	for(i = 0; i < self.wispTeaWisps.size; i++)
	{
		w = self.wispTeaWisps[i];

		if(isdefined(w) && !IS_TRUE(w.wispRemoving))
		{
			ARRAY_ADD(a_live, w);
		}
	}

	self.wispTeaWisps = a_live;

	return a_live.size;
}

function take_wisp_tea_perk(b_pause, str_perk, str_result)
{
	self notify(WISP_TEA_SPECIALTY + "_stop");
	self notify("perk_lost", str_perk);
}

function spawnWisp()
{
	// [tod v17.8] RE-TESTED HERE, not just in the damage monitor. The monitor
	// runs once per damage EVENT and a shotgun spread is many events in one
	// frame, while `thread` does not run its body until the next dispatch — so
	// the monitor's own gate can pass twice against the same charge. This is
	// the test that actually spends it.
	if(!self wisp_can_spawn())
	{
		return;
	}

	self.wispTeaCharges--;

	wisp = util::spawn_model(WISP_TEA_WISP_MODEL, self.origin, self.angles);
	wisp.wispFXModel = util::spawn_model("tag_origin", wisp.origin, wisp.angles);
	wisp.wispOwner      = self;   // wisp_target_is_free walks the owner's list
	wisp.wispSlot       = self wisp_free_slot();
	wisp.wispIdleOffset = wisp_slot_offset(wisp.wispSlot);
	wisp LinkTo(self, "tag_origin", wisp.wispIdleOffset);
	wisp.wispFXModel LinkTo(wisp, "tag_origin", (0,0,0));
	wisp.wispFXModel clientfield::set("wispTeaWispFX", 1);

	ARRAY_ADD(self.wispTeaWisps, wisp);

	// [tod] Disconnect safety: the owner's threads die WITH the owner entity,
	// so no player-side path can clean up after a disconnect. The wisp owns
	// its own owner-watch instead (delta 3 in the header).
	wisp thread wispOwnerWatch(self);

	self thread wispFunctionality(wisp);
}

// self = the player. Returns whichever parking slot no live wisp is using, so
// a pair reads as two companions instead of one silhouette. Slot 0 when both
// are free — a lone wisp always parks exactly where the pack put it.
// A SLOT INDEX, NOT THE VECTOR: comparing offsets would mean trusting `==` on
// vectors, and an int says the same thing with nothing to look up.
function wisp_free_slot()
{
	self wisp_live_count();   // prunes self.wispTeaWisps

	for(i = 0; i < self.wispTeaWisps.size; i++)
	{
		w = self.wispTeaWisps[i];

		if(isdefined(w.wispSlot) && w.wispSlot == 0)
		{
			return 1;
		}
	}

	return 0;
}

function wisp_slot_offset(n_slot)
{
	if(n_slot == 0)
	{
		return WISP_TEA_WISP_IDLE_OFF_A;
	}

	return WISP_TEA_WISP_IDLE_OFF_B;
}

// self = the wisp; polls its owner out of existence. endon death covers the
// normal removal path (Delete fires "death").
function wispOwnerWatch(owner)
{
	self endon("death");

	while(isdefined(owner))
	{
		wait(0.5);
	}

	self thread removeWisp();
}

function wispFunctionality(wisp)
{
	self thread wispAttack(wisp);
	self thread wispFollowEnemy(wisp);

	response = self util::waittill_any_ex(WISP_TEA_WISP_DURATION, "disconnect","bled_out");

	// [tod] Every exit removes the wisp; the pack only cleaned up the natural
	// expiry, so a bleed-out (or disconnect) mid-summon stranded the wisp and
	// its FX model in the world forever (delta 3 in the header).
	//
	// [tod v17.8] NOTIFIED ON THE WISP, NOT THE OWNER. The pack raised this on
	// the PLAYER and every follow/attack loop endon'd it there — which is a
	// broadcast, so the first of two wisps to expire would have retired the
	// second one's loops as well and left it drifting, linked and inert, for
	// the rest of its life. One wisp, one channel.
	if(isdefined(wisp))
	{
		wisp Notify("wispExpired");
	}

	if(response != "disconnect" && response != "bled_out")
	{
		self thread wispCooldown();
	}

	// Threaded ON THE WISP so the 4s delete tail never depends on the owner's
	// thread surviving (it does not on bled_out -> spectate churn). isdefined
	// FIRST: threading on an undefined entity is a runtime error, and the
	// spire's teardown deletes world script entities out from under callers
	// (v14.20 hardening — same class as the _tod_stray/teardown lesson).
	if( isdefined( wisp ) )
	{
		wisp thread removeWisp();
	}
}

// self = the wisp. Hides immediately, lets the CSC's StopFX fade run, then
// deletes BOTH entities (the fx-model Delete is a tower leak fix — delta 3).
// Re-entry guarded: the expiry path and the owner-watch can both get here.
function removeWisp()
{
	if(IS_TRUE(self.wispRemoving))
	{
		return;
	}
	self.wispRemoving = true;

	fx_model = self.wispFXModel;
	if(isdefined(fx_model))
	{
		fx_model clientfield::set("wispTeaWispFX", 0);
	}
	self Unlink();
	self Hide();

	wait(4);

	if(isdefined(fx_model))
	{
		fx_model Delete();
	}
	if(isdefined(self))
	{
		self Delete();
	}
}

// self = the player. Refunds ONE charge WISP_TEA_COOLDOWN_TIME after the wisp
// that spent it expired, so the slots run independent clocks and the perk's
// rate is unchanged per slot — only the number of slots grew (v17.8).
// Clamped, because give_wisp_tea_perk may have refilled to full while this
// was still counting down (the spire re-gives the roster on every respawn).
function wispCooldown()
{
	level endon("game_over");
	self endon("disconnect");
	self endon("bled_out");

	wait(WISP_TEA_COOLDOWN_TIME);

	if(!isdefined(self.wispTeaCharges) || self.wispTeaCharges >= WISP_TEA_MAX_WISPS)
	{
		self.wispTeaCharges = WISP_TEA_MAX_WISPS;
		return;
	}

	self.wispTeaCharges++;
}

function wispFollowEnemy(wisp)
{
	level endon("game_over");

	self endon("disconnect");
	self endon("bled_out");

	// [tod v17.8] The wisp's own channels (see wispFunctionality). "death"
	// covers the Delete in removeWisp, which is the path the owner-watch takes
	// after a disconnect.
	wisp endon("wispExpired");
	wisp endon("death");

	for(;;)
	{
		e_target = self wispPickTarget(wisp);

		// PUBLISHED FOR THE OTHER WISP (v17.8). wispPickTarget reads every
		// live wisp's wispTargetEnt so a pair splits the room instead of
		// stacking on one body. Written every tick, including the undefined
		// case below — a stale claim would fence the other wisp off a target
		// nobody is actually going for.
		wisp.wispTargetEnt = e_target;

		if(isdefined(e_target))
		{
			wisp Unlink();
			wisp thread wispLookAt(e_target);

			distance = Distance(wisp.origin, e_target.origin);

			if(distance > 20)
			{
				time = distance / WISP_TEA_WISP_MOVE_SPEED;
				wisp MoveTo(e_target.origin, time, 0, 0);

				wisp.attackTarget = undefined;
			}
			else
			{
				wisp.attackTarget = e_target;
				wisp.origin = e_target.origin;
			}

			wisp Notify("stopWispLookAt");
		}
		else
		{
			wisp.attackTarget = undefined;
			wisp LinkTo(self, "tag_origin", wisp.wispIdleOffset);
		}

		util::wait_network_frame();
	}
}

// self = the OWNER (the range gate is measured from the player, exactly as the
// pack wrote it — the wisp is a companion on a leash, not a scout).
//
// BOSS PRIORITY (v17.8, user: "have them prioritize bosses"). The pack took
// ArrayGetClosest over every axis actor and then asked whether THAT ONE
// happened to be near the player — so a Panzer eight feet away lost to any
// shambler a foot nearer, and worse, a nearest-target that was out of the
// player's range parked the wisp even when something else was well inside it.
// This walks the whole array instead and keeps the best by (rank, distance).
// The RANK is wisp_seek_rank( wisp_target_tier( e ) ): ELITES first, then the
// PANZER, then trash (v17.8) — deliberately NOT the health order, and
// deliberately not the same number wisp_hit_damage() prices with.
//
// THE ZOMBIE-COUNT GATE NOW BINDS TRASH ONLY, and that is the load-bearing
// half of "prioritize bosses". Every boss and elite on this map sets
// ignore_enemy_count (_tod_bosses.gsc:1704 and :2202, _tod_hellhounds.gsc:361,
// _tod_reaver.gsc:267) and get_current_zombie_count() skips exactly those — so
// the count it returns is the TRASH population and nothing else. The pack's
// `> 1` was a "never take the round's last zombie" rule; applied to the whole
// array it also parked the wisp for the back half of every thinned-out boss
// fight, which is precisely when a boss-seeking wisp is supposed to be
// working. So it gates trash targets and leaves bosses alone.
function wispPickTarget(wisp)
{
	a_targets = GetActorTeamArray("axis");

	if(a_targets.size == 0)
	{
		return undefined;
	}

	b_trash_ok = (zombie_utility::get_current_zombie_count() > 1);

	e_best      = undefined;
	n_best_rank = -1;
	n_best_free = -1;
	n_best_dist = 0;

	for(i = 0; i < a_targets.size; i++)
	{
		e = a_targets[i];

		if(!isdefined(e) || !IsAlive(e))
		{
			continue;
		}

		if(Distance(self.origin, e.origin) >= WISP_TEA_WISP_MAX_DISTANCE_TO_PLAYER)
		{
			continue;
		}

		// IDENTITY for the trash gate, RANK for the ordering — they are
		// different questions and since v17.8 different answers.
		n_id = wisp_target_tier(e);

		if(n_id == 0 && !b_trash_ok)
		{
			continue;
		}

		n_rank = wisp_seek_rank(n_id);

		// CLAIMED BY THE OTHER WISP? A tiebreaker BELOW rank, never above it:
		// an elite still outranks an unclaimed shambler, so "elites first"
		// survives intact. It only decides between equals — which is the
		// common case, since most of what is in range is trash.
		n_free = ( ( wisp wisp_target_is_free( e ) ) ? 1 : 0 );

		// Distance is measured from the WISP (which target is cheapest for it
		// to reach) while the range gate above is measured from the PLAYER —
		// the pack's split, kept. THIS is what turns the two parking spots
		// into two hunting grounds: the wisps sit on opposite sides of the
		// player, so "nearest to me" already means "the one on my side", and
		// the claim rule above breaks the ties where it does not.
		n_dist = DistanceSquared(wisp.origin, e.origin);

		if(n_rank > n_best_rank
		|| (n_rank == n_best_rank && n_free > n_best_free)
		|| (n_rank == n_best_rank && n_free == n_best_free && n_dist < n_best_dist))
		{
			e_best      = e;
			n_best_rank = n_rank;
			n_best_free = n_free;
			n_best_dist = n_dist;
		}
	}

	return e_best;
}

// e = a candidate. WHAT IT IS: 2 = PANZER-class, 1 = elite (protector / reaver
// / hound / armored sprinter), 0 = trash. ORDER MATTERS — the Panzer also
// carries is_boss, so it has to be claimed before the elite test.
//
// THIS IS AN IDENTITY, NOT A PRIORITY, and since v17.8 the two genuinely
// disagree — see wisp_seek_rank() below. wisp_hit_damage() prices off THIS
// (a Panzer must always take the Panzer's share of its health per hit), and
// wispPickTarget seeks off the RANK. An earlier draft of this comment said
// "ONE ladder, read twice", which was true for about an hour and would have
// been an actively dangerous thing to still believe: renumbering this function
// to reorder the seek would have handed the Panzer the ELITE damage tier and
// made wisps kill him five times faster.
function wisp_target_tier(e)
{
	if(IS_TRUE(e.acc_is_panzer) || (isdefined(e.tod_boss_kind) && e.tod_boss_kind == "panzer"))
	{
		return 2;
	}

	if(IS_TRUE(e.is_boss) || IS_TRUE(e.acc_is_boss) || IS_TRUE(e.acc_is_mini_boss) || IS_TRUE(e.tod_is_sprinter))
	{
		return 1;
	}

	return 0;
}

// self = THE WISP asking. TRUE if no OTHER live wisp of the same owner is
// already going for e (v17.8, user: "this could allow their area to be
// different and they can target different enemies most of the time").
//
// MY OWN CURRENT TARGET ALWAYS COUNTS AS FREE. Without that the pair
// oscillates: both re-pick every network frame, and on the frame after they
// split, each would see the other's claim, both would bail, and they would
// swap targets forever without landing a hit. Stickiness on your own quarry is
// what makes the split settle.
//
// A PREFERENCE, NOT A LOCK. It sits below rank and it is only a tiebreak, so
// when there is exactly one thing worth killing BOTH wisps still go for it —
// which is right; two wisps on the last elite in the room is the correct
// answer, and "most of the time" was the ask.
function wisp_target_is_free(e)
{
	owner = self.wispOwner;

	if(!isdefined(owner) || !isdefined(owner.wispTeaWisps))
	{
		return true;
	}

	for(i = 0; i < owner.wispTeaWisps.size; i++)
	{
		w = owner.wispTeaWisps[i];

		if(!isdefined(w) || w == self)
		{
			continue;
		}

		if(isdefined(w.wispTargetEnt) && w.wispTargetEnt == e)
		{
			return false;
		}
	}

	return true;
}

// n_id = a wisp_target_tier() identity -> what the wisp goes for FIRST.
// Higher wins. User 2026-09-03: "They should target Elites, Panzers, then
// zombies. In that order."
//
// ELITES OVER THE PANZER IS THE WHOLE POINT and it is not an oversight that it
// inverts the health order. A wisp kills an elite in WISP_TEA_ELITE_SEGMENTS
// hits and a Panzer in WISP_TEA_BOSS_SEGMENTS — a Panzer is a slog it can
// barely dent, while the protector/reaver/hound/sprinter that would actually
// have reached the player dies in seconds. Sending the wisps at the thing they
// can finish is worth more than sending them at the biggest health bar.
//
// A PURE FUNCTION OF THE IDENTITY, taking the int rather than the entity: the
// caller has already paid for the field reads, and nothing here can drift out
// of step with what wisp_hit_damage() will charge the same victim.
function wisp_seek_rank(n_id)
{
	if(n_id == 1)   // ELITE — first
	{
		return 2;
	}

	if(n_id == 2)   // PANZER — second
	{
		return 1;
	}

	return 0;       // trash — last
}

function wispAttack(wisp)
{
	// [tod v17.8] wisp-scoped, not owner-scoped — see wispFunctionality.
	wisp endon("wispExpired");
	wisp endon("death");
	self endon("disconnect");
	level endon("end_game");

	for(;;)
	{
		if(isdefined(wisp.attackTarget))
		{
			if(IsAlive(wisp.attackTarget))
			{
				// MARK THE VICTIM FOR ONE HIT (v14.24). This DoDamage names the
				// OWNER as attacker with "MOD_MELEE", so without the mark the
				// tower's upgrade chain cannot tell a wisp tick from the player
				// swinging a knife — and fired THOR'S THUNDER, CLEAVE, the melee
				// uniques and crosshair damage numbers off it (the user's
				// "lightning randomly triggers" report). _tod_upgrades'
				// upgrade_damage_cb consumes this and passes the hit through
				// raw; the long note lives there. Cleared straight after too, so
				// a victim who somehow never reaches the callback cannot carry a
				// stale mark into the player's next real swing.
				wisp.attackTarget.tod_wisp_hit = true;
				wisp.attackTarget DoDamage( wisp_hit_damage( wisp.attackTarget ), wisp.origin, self, self, "none", "MOD_MELEE", 0, GetWeapon("none") );
				if( isdefined( wisp.attackTarget ) )
				{
					wisp.attackTarget.tod_wisp_hit = undefined;
				}
			}
		}

		wait(0.75);
	}
}

// e = the victim. WHAT THE PACK GOT WRONG ON THIS MAP (v14.20, both found by
// audit before the perk was ever played against a boss — user: "make sure
// they dont kill bosses or elites crazy fast"):
//
//  1. PERCENTAGE DAMAGE IGNORED ELITE HEALTH. The pack's only zombie branch
//     is maxhealth/3 keyed on `archetype == "zombie"` — and this map's
//     ARMORED SPRINTER *is* a promoted horde zombie (archetype "zombie",
//     _tod_sprinter.gsc:209) carrying TOD_SPRINT_HP_MULT = **20x** health.
//     So the wisp killed a 20x elite in the same 3 hits as trash: its entire
//     elite budget cancelled by a divide.
//  2. FLAT 1000/HIT DELETED BOSSES. Everything non-"zombie" took a flat
//     WISP_TEA_NON_ZOMBIE_DAMAGE per 0.75s = 1,333 dps. A round-5 Panzer is
//     15,000 HP (TOD_PANZER_HP_BASE), so ONE wisp soloed it in 11 seconds of
//     its 30-second life, with the player free to do nothing. Rogue
//     Protectors (4,000) died in 3 seconds each, so a wisp could clear a
//     whole wave. Neither scaled with round while boss HP compounds 8%/round.
//
// The fix is one tier lookup and the tiers live in the .gsh as hits-to-kill,
// so retuning is a number, not a rewrite. ORDER MATTERS: the Panzer also
// carries is_boss, so it must be tested before the elite tier.
//
// maxhealth is spelled LOWERCASE deliberately — every writer on this map
// (boss.maxhealth, sprinter self.maxhealth) uses that case, and matching it
// keeps this readable next to them.
function wisp_hit_damage( e )
{
	if( !isdefined( e.maxhealth ) || e.maxhealth < 1 )
	{
		return WISP_TEA_NON_ZOMBIE_DAMAGE;
	}

	// THE WARDEN KING (v18.8) — his own tier, tested BEFORE the lookup rather
	// than inside the boss branch, so it cannot be re-ordered out by a future
	// change to wisp_target_tier. He carries is_boss like every Panzer, so
	// without this he lands on the 80-hit tier and dies in 80 ticks whatever his
	// health. Reading a tod_ field from this vendored module is established
	// practice here — wisp_target_tier already reads tod_is_sprinter for exactly
	// the same reason: the pack cannot know this map's enemies.
	if( IS_TRUE( e.tod_king ) )
	{
		return int( e.maxhealth / WISP_TEA_KING_SEGMENTS ) + 1;
	}

	// The IDENTITY, never the seek rank (v17.8). What a wisp hunts first and
	// what it charges when it arrives are two decisions; wisp_seek_rank() owns
	// the first and this owns the second.
	n_tier = wisp_target_tier( e );

	if( n_tier == 2 )
	{
		return int( e.maxhealth / WISP_TEA_BOSS_SEGMENTS ) + 1;
	}

	if( n_tier == 1 )
	{
		return int( e.maxhealth / WISP_TEA_ELITE_SEGMENTS ) + 1;
	}

	if( isdefined( e.archetype ) && e.archetype == "zombie" )
	{
		return int( e.maxhealth / WISP_TEA_DAMAGE_SEGMENTS ) + 1;
	}

	return WISP_TEA_NON_ZOMBIE_DAMAGE;
}

// self = the wisp. Yaw-tracks the chase target between MoveTo re-issues; the
// follow loop notifies "stopWispLookAt" every tick (case fixed — delta 4).
function wispLookAt(e_target)
{
	self endon("death");
	self endon("stopWispLookAt");

	for(;;)
	{
		if(isdefined(self))
		{
			point = VectortoAngles(e_target.origin - self.origin);
			self.angles = (self.angles[0], point[1], self.angles[2]);
		}

		util::wait_network_frame();
	}
}
