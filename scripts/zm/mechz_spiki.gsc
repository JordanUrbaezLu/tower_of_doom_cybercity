// =============================================================================
// mechz_spiki.gsc - Spiki asset-dump PANZER (mechz), vendored server half.
//
// SOURCE: raw decompile from Spiki's Asset Dump (modme #3087), recovered via
// tools/_panzer_stash/ (git 84e98c9). CLEAN-ROOM FIXES re-applied 2026-07-08 from the
// 2026-06-19 recipe (tools/_panzer_stash/README.md) - every [acc] block below:
//   1. THE ATTACK-CRASH FIX: no-op rebind of the 4 stock mechz_face StartFunctions (__init__).
//   2. Pack per-spawn init (function_3d5df242) re-registered - dead in the decompile.
//   3. Bow-damage autoexec DISARMED (duplicate of our vendored bow scripts + live div-by-undef bug).
//   4. Unregistered "sparky_beam_fx" clientfield sets commented out (gravity-spikes path, no DG-4 here).
//   5. m_claw / explosive-claw-cancel guards (claw is OFF: needs spawner targetname "mechz_tomb").
//   6. portal_3p FX guard in the teleport mocomp (fx not shipped).
//   7. Melee-vs-player damage callback registered + tunable (was defined-but-dead 150).
//   8. acc_setup_mechz() added at EOF - the SpawnActor'd-boss setup path (_acc_boss_panzer drives
//      spawns; spawn_mechz() needs a .map spawner entity we deliberately don't place - custom-aitype
//      .map spawners crashed the LED bake (Avogadro) and game load (Rogue Protector) on this map).
// The .csc twin carries fix #9: mirror-registration of the 11 stock server-side mechz clientfields.
// Ship rules (docs/research/BO3_Panzer_mechz_usermap_method.txt): STANDARD variant only (the
// Origins variant's grab is inescapable); treat armor as solid (destructible visuals are DLC1-gated).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\_burnplayer;
#using scripts\shared\aat_shared;
#using scripts\shared\ai\mechz;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\zm\_zm;
#using scripts\zm\_zm_devgui;
//#using scripts\zm\_zm_elemental_zombies;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_zonemgr;
#using scripts\zm\_zm_audio;
#using scripts\shared\laststand_shared;
#using scripts\zm\_zm_weap_riotshield;
#using scripts\shared\ai\zombie_shared;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai_shared;
// [tod] 2026-08-19: NO #using of _tod_bosses here — that module #usings this
// file back, and the KB cycle rule (map 1 docs/16) says a vendored file that
// needs a driver value must use a LEVEL FIELD, never an import. The player
// mitigation hook is the function pointer level.tod_player_mitigations_fn
// (published by tod_bosses::init; guarded call below). Was map 1's
// _acc_elites::apply_player_mitigations (Exo/Savior armor, audit 2026-07-12).



#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace mechz_spiki;


#precache( "model", "c_t7_zm_dlchd_origins_mech_claw_lod0");
#precache( "model", "p7_chemistry_kit_large_bottle");
#precache( "xanim", "ai_zombie_mech_ft_burn_player");

#using_animtree("mechz_tomb");

// [tod 2026-08-23] PANZER FIRE — HALVED (user: "his fire should do half damage
// it currently does").
//
// WHY THIS IS ONE SHARED CONSTANT: the Panzer has TWO independent fire damage
// sources and they had already drifted apart. Both call
// burnplayer::SetPlayerBurning DIRECTLY, so BOTH bypass every tod mitigation
// lane — _tod_bosses::apply_player_mitigations (the melee short-circuit, which
// carries TOD_PANZER_DMG_MULT 0.5) and _tod_bosses::boss_player_damage (the
// electroball lane AND the DR upgrade domain). That is exactly why the
// 2026-08-20 "halve ALL panzer damage" pass never touched the flame:
//   * acc_player_flame_damage  (~:1544) = the flameTrigger CONE. Was scaled by
//     acc_panzer_flame_mult 1.21 (map 1's +10% then +10% passes).
//   * function_3389e2f3        (~:743)  = the GROUND-FIRE pool, ignited by the
//     10Hz proximity sweep (~:710). Was NEVER scaled — raw stock 30/20.
// The GROUND-FIRE pool still multiplies by this one constant, so its per-tick
// damage halves exactly: 30 -> 15 (no Jugg) / 20 -> 10 (Jugg).
// The old acc_panzer_flame_mult DVAR is folded away with it — this map's
// doctrine is compile-time constants, never dvars.
#define TOD_PANZER_FIRE_MULT   0.5

// [tod 2026-09-08] THE CONE'S NUMBERS ARE PINNED, NOT DERIVED (user: "do 25 and
// 12"). They used to be int(30 * 1.21 * TOD_PANZER_FIRE_MULT) = 18 and
// int(20 * ...) = 12 — a stock base times a map-1 heritage factor times a
// halving pass, three movable parts for a number the user tunes by feel. Same
// lesson as CLASS_SEC_CAP_MULT: pin the value, never derive it from something
// that moves. 0.5s ticks over a 1.5s burn = ~3 ticks, so these are a THIRD of
// the per-ignite total against a 100 HP player: 75 without Jugg, 36 with it.
// The DoT cannot be outrun and is NOT reduced by the DR upgrade domain (it
// never enters boss_player_damage), so the total is what matters — 75 is a
// hard hit that leaves you alive; the historical 36/tick (108 total) was a
// guaranteed no-Jugg down from a single tag.
#define TOD_PANZER_FLAME_DMG        25
#define TOD_PANZER_FLAME_DMG_JUGG   12

REGISTER_SYSTEM( "zm_ai_mechz", &__init__, undefined )




function __init__()
{
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("mechzShouldShootClaw", &mechzShouldShootClaw);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeAction("zmMechzShootClawAction", &zmMechzShootClawActionStart, &zmMechzShootClawActionUpdate, &zmMechzShootClawActionEnd);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("zmMechzShootClaw", &zmMechzShootClaw);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("zmMechzUpdateClaw", &zmMechzUpdateClaw);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("zmMechzStopClaw", &zmMechzStopClaw);
	AnimationStateNetwork::RegisterNotetrackHandlerFunction("muzzleflash", &muzzleflash);
	AnimationStateNetwork::RegisterNotetrackHandlerFunction("start_ft", &start_ft);
	AnimationStateNetwork::RegisterNotetrackHandlerFunction("stop_ft", &stop_ft);

	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("castleMechzTrapService", &castleMechzTrapService);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("genesisVortexService", &genesisVortexService);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("genesisMechzOctobombService", &genesisMechzOctobombService);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("castleMechzShouldMoveToTrap", &castleMechzShouldMoveToTrap);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("castleMechzIsAtTrap", &castleMechzIsAtTrap);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("castleMechzShouldAttackTrap", &castleMechzShouldAttackTrap);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("genesisMechzShouldOctobombAttack", &genesisMechzShouldOctobombAttack);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("casteMechzTrapMoveTerminate", &casteMechzTrapMoveTerminate);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("casteMechzTrapAttackTerminate", &casteMechzTrapAttackTerminate);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("genesisMechzDestoryOctobomb", &genesisMechzDestoryOctobomb);
	AnimationStateNetwork::RegisterAnimationMocomp("mocomp_trap_attack@mechz", &mechz_attack_trap_start, undefined, &mechz_attack_trap_end);
	AnimationStateNetwork::RegisterAnimationMocomp("mocomp_teleport_traversal@mechz", &mechz_teleport_Start, undefined, undefined);



	spawner::add_archetype_spawn_function("mechz", &tomb_spawn_function);
	level.mechz_claw_cooldown_time = 7000;
	// [tod 2026-09-08] OURS IS THE ONLY FLAME DAMAGE (user: "I want our damage not the
	// stock"). Stock's mechzUpdateFlame (mechz.gsc:800) sweeps the flame cone itself every
	// behavior-tree tick and, with no callback set, ran MechzBehavior::playerFlameDamage at
	// the raw stock 30/20 per tick - in PARALLEL with this map's halved twin, on a separate
	// latch (is_burning vs acc_mechz_burn_until). SetPlayerBurning does not stack (its
	// WatchBurnDamage endons on its own restart notify), so the last caller of the frame won
	// and the flame did full or half damage more or less at random, while every comment in
	// this file said "halved". Claiming the callback makes stock call US instead, so
	// TOD_PANZER_FIRE_MULT is the one owner of the number.
	// It also retires the last writer of player.is_burning: stock's playerFlameDamage set it,
	// and _zm_utility.gsc:3776 requests the "lava_small" shellshock for a burning player on
	// explosive damage - an asset no fastfile here carries. See acc_player_flame_damage.
	level.mechz_flamethrower_player_callback = &acc_mechz_flame_player_cb;
	level.mechz_left_arm_damage_callback = &function_671deda5;
	level.mechz_explosive_damage_reaction_callback = &function_6028875a;
	level.mechz_powercap_destroyed_callback = &function_d6f31ed2;
	level flag::init("mechz_launching_claw");
	level flag::init("mechz_claw_move_complete");

	// ------------------------------------------------------------------------------------------
	// [acc] THE ATTACK-CRASH FIX (2026-06-19 recipe, re-applied 2026-07-08): stock mechz.gsc
	// (#using'd above) registers the "mechz_face" actor clientfield at VERSION_SHIP server-side
	// and SETS it on every idle/attack/pain/death - but no client script registers it in a
	// usermap, so the first set = clientfield layout desync = CTD ("the game breaks every time
	// he attacks", the historical Panzer killer with no published fix anywhere). BT_REGISTER_API
	// bindings are name-keyed LAST-WRITE-WINS and this __init__ (REGISTER_SYSTEM) runs after
	// stock's autoexec init(), so re-binding the 4 face StartFunctions to a no-op means
	// mechz_face is NEVER set. (Belt+braces: the vendored .csc also mirror-registers the stock
	// server-side mechz fields, so even a missed set can't desync the layout.)
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("mechzAttackStart", &acc_mechz_face_noop);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("mechzDeathStart", &acc_mechz_face_noop);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("mechzIdleStart", &acc_mechz_face_noop);
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI("mechzPainStart", &acc_mechz_face_noop);

	// [acc] The pack's own per-spawn init (is_mechz flag, cleanup exemption, thundergun
	// fling/knockdown overrides, zm_spawner::zombie_death_event) is DEAD in the decompile -
	// defined but registered nowhere. It's `private`, so this __init__ is the only place that
	// can bind it; without it the boss misses is_mechz + thundergun handling.
	spawner::add_archetype_spawn_function("mechz", &function_3d5df242);

	// [acc] Mechz melee vs players: the pack defines (but never registers) the melee damage
	// override (function_ed70c868, was a hardcoded 150 = instadown without Jugg). Registered
	// here; the value is live-tunable via acc_panzer_melee_damage (default 90).
	zm::register_player_damage_callback(&function_ed70c868);

	clientfield::register("actor", "mechz_fx", VERSION_DLC5, 1, "int");
	clientfield::register("scriptmover", "mechz_claw", VERSION_DLC5, 1, "int");
	clientfield::register("actor", "mechz_wpn_source", VERSION_DLC5, 1, "int");
	clientfield::register("toplayer", "mechz_grab", VERSION_DLC5, 1, "int");
	clientfield::register("actor", "death_ray_shock_fx", 15000, 1, "int");
	clientfield::register("actor", "mechz_fx_spawn", 15000, 1, "counter");

	// [acc] VISIBLE FLAMETHROWER (user 2026-07-08: "his flamethrower has no fx"): the pack's
	// "mechz_ft" field is VERSION_DLC1 = version-gated dead on a usermap, so the flame cone
	// never rendered. This is OUR OWN SHIP-version twin, mirrored from stock flame state
	// as well as animation notetracks; the .csc callback plays/stops the real castle cone FX
	// on tag_flamethrower_fx (the avogadro bolt clientfield-on-entity pattern - self-cleaning).
	// Registered IDENTICALLY in mechz_spiki.csc - keep in lockstep.
	clientfield::register("actor", "acc_panzer_ft", VERSION_SHIP, 1, "int");

/*
	clientfield::register("actor", "sparky_zombie_spark_fx", 1, 1, "int");
	clientfield::register("actor", "sparky_zombie_death_fx", 1, 1, "int");
	clientfield::register("actor", "napalm_zombie_death_fx", 1, 1, "int");
	clientfield::register("actor", "sparky_damaged_fx", 1, 1, "counter");
	clientfield::register("actor", "napalm_damaged_fx", 1, 1, "counter");
	clientfield::register("actor", "napalm_sfx", 11000, 1, "int");
*/

}



// [acc] no-op replacement for the 4 stock mechz face StartFunctions (see the crash fix in __init__).
function private acc_mechz_face_noop( entity )
{
}



function autoexec mechz_bow_damage_cuz_it_dont_work_by_default()
{
	// [acc] DISARMED (2026-07-08). The pack hooked every player connect with a projectile-impact
	// watcher for weapons whose stripped name is exactly "elemental_bow"/"elemental_bow4" - our
	// HB21 bows are "elemental_bow_demongate"-named (never match) and our vendored
	// _zm_weap_elemental_bow*.gsc already carries its own mechz-damage path (reads
	// level.mechz_health), so this was dead weight with a live bug: function_dc4f8831 divides by
	// never-set level.var_42ee1b54 (throws if it ever ran). The helper chain below
	// (function_c45ac6ae/_d2e32ed2/_b78fcfc7/_dc4f8831/_1796e73) is now unreachable dead code,
	// kept verbatim for diff-ability against the pack. NOTE: level.var_f4dc2834 (the thundergun
	// damage clamp function_b8e0ce15 relies on) used to be seeded HERE - it is now seeded in
	// _acc_boss_panzer::init() instead. Do not re-arm without re-checking both.
}



function function_c45ac6ae(var_6ab83514 = "elemental_bow", var_8f9bdf29 = "elemental_bow4", var_332bb697)
{
	if(!isdefined(var_332bb697))
	{
		var_332bb697 = undefined;
	}
	self endon("death");

	while(1)
	{
		self waittill("projectile_impact", weapon, v_position, radius, e_projectile, normal);
		//IPrintLnBold("damage");
		var_48369d98 = function_1796e73(weapon.name);
		if(var_48369d98 == var_6ab83514 || var_48369d98 == var_8f9bdf29)
		{

		self thread function_d2e32ed2(var_48369d98, v_position);

		}
	}
}




function function_d2e32ed2(var_48369d98, v_position)
{
	if(var_48369d98 === "elemental_bow_wolf_howl4")
	{
		return;
	}
	array::thread_all(GetAIArchetypeArray("mechz"), &function_b78fcfc7, self, var_48369d98, v_position);
}





function function_b78fcfc7(e_player, var_48369d98, v_position)
{
	var_2017780d = 0;
	var_c36342f3 = 0;
	var_377b9896 = 0;
	if(!IsSubStr(var_48369d98, "4"))
	{
		var_377b9896 = 1;
		var_3fa1565a = 9216;
		var_6594cbc3 = 96;
		var_f419b406 = 0.25;
	}
	else if(var_48369d98 == "elemental_bow4")
	{
		var_377b9896 = 1;
		var_3fa1565a = 20736;
		var_6594cbc3 = 144;
		var_f419b406 = 0.1;
	}
	var_7486069a = distancesquared(v_position, self.origin);
	var_7d984cf2 = distancesquared(v_position, self gettagorigin("j_neck"));
	if(var_7486069a < 1600 || var_7d984cf2 < 2304)
	{
		var_2017780d = 1;
		var_c36342f3 = 1;
	}
	else if(var_377b9896 && (var_7486069a < var_3fa1565a || var_7d984cf2 < var_3fa1565a))
	{
		var_2017780d = 1;
		var_c36342f3 = 1 - var_f419b406;
		if(var_7486069a < var_7d984cf2)
		{
		}
		else
		{
		}
		var_c36342f3 = var_7486069a * sqrt(var_7d984cf2) / var_6594cbc3;
		var_c36342f3 = 1 - var_c36342f3;
	}
	if(var_2017780d)
	{
		var_3bb42832 = level.mechz_health;
		if(isdefined(level.var_f4dc2834))
		{
			var_3bb42832 = math::clamp(var_3bb42832, 0, level.var_f4dc2834);
		}
		if(var_48369d98 == "elemental_bow")
		{
			var_26680fd5 = function_dc4f8831(0.15, 0.03);
		}
		else if(var_48369d98 == "elemental_bow4")
		{
			var_26680fd5 = function_dc4f8831(0.25, 0.12);
		}
		else if(!IsSubStr(var_48369d98, "4"))
		{
			var_26680fd5 = 0.1;
		}
		else
		{
			var_26680fd5 = 0.35;
		}
		var_40955aed = var_3bb42832 * var_26680fd5 / 0.2;
		var_40955aed = var_40955aed * var_c36342f3;
		self DoDamage(var_40955aed, self.origin, e_player, e_player, undefined, "MOD_PROJECTILE_SPLASH", 0, level.var_be94cdb);
	}
}



function function_dc4f8831(var_eaae98a2, var_c01c8d5c)
{
	if(level.mechz_health < level.var_c1f907b2)
	{
		var_26680fd5 = var_eaae98a2;
	}
	else if(level.mechz_health > level.var_42fd61f0)
	{
		var_26680fd5 = var_c01c8d5c;
	}
	else
	{
		var_d82dde4a = level.mechz_health - level.var_c1f907b2;
		var_caabb734 = var_d82dde4a / level.var_42ee1b54;
		var_26680fd5 = var_eaae98a2 - var_eaae98a2 - var_c01c8d5c * var_caabb734;
	}
	return var_26680fd5;
}



function function_1796e73(str_weapon_name)
{
	var_48369d98 = str_weapon_name;
	/*if(IsSubStr(var_48369d98, "ricochet"))
	{
		var_ae485cc2 = function_4d1b4da2(var_48369d98, "_ricochet");
		var_48369d98 = var_ae485cc2[0];
	}*/
	if(IsSubStr(var_48369d98, "2"))
	{
		var_48369d98 = strtok(var_48369d98, "2")[0];
	}
	if(IsSubStr(var_48369d98, "3"))
	{
		var_48369d98 = strtok(var_48369d98, "3")[0];
	}
	return var_48369d98;
}




function function_48cabef5()
{
	if(isdefined(self.customTraverseEndNode) && isdefined(self.customTraverseStartNode))
	{
		return self.customTraverseEndNode.script_noteworthy === "custom_traversal" && self.customTraverseStartNode.script_noteworthy === "custom_traversal";
	}
	return 0;
}

/*
	Name: function_3d5df242
	Namespace: zm_ai_mechz
	Checksum: 0xC8A7FC5D
	Offset: 0xD70
	Size: 0xE3
	Parameters: 0
	Flags: Private
*/
function private function_3d5df242()
{
	self.b_ignore_cleanup = 1;
	self.is_mechz = 1;
	self.var_7884b12d = self.health;
	self.team = level.zombie_team;
	self.zombie_lift_override = &function_817c85eb;
	self.thundergun_fling_func = &function_9bac2f00;
	self.thundergun_knockdown_func = &function_19b9b682;
	self.var_23340a5d = &function_9bac2f00;
	self.var_e1dbd63 = &function_19b9b682;
	self.var_48cabef5 = &function_48cabef5;
	level thread zm_spawner::zombie_death_event(self);
}

/*
	Name: function_ed70c868
	Namespace: zm_ai_mechz
	Checksum: 0x138FD51F
	Offset: 0xE60
	Size: 0x91
	Parameters: 10
	Flags: Private
*/
function private function_ed70c868(einflictor, eattacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, shitloc, psOffsetTime)
{
	if(isdefined(eattacker) && eattacker.archetype === "mechz" && sMeansOfDeath === "MOD_MELEE")
	{
		// [acc] was a hardcoded 150 (= instadown at base 100 HP). 99 default (user 2026-07-18 +10%
		// Panzer damage, was 90): hits VERY hard but survivable without Jugg. Live-tunable.
		// Registered in __init__ (dead in the pack).
		// Returning a value ends the stock callback chain (first != -1 wins) - correct here, the
		// mechz melee IS the final say on its own hit.
		dmg = getdvarint("acc_panzer_melee_damage", 99);
		// [acc] EXO/SAVIOR mitigation (audit 2026-07-12): because this callback SHORT-CIRCUITS
		// _acc_elites::on_player_damaged (below), Panzer melee is the ONLY boss melee that would ignore the
		// Exo Suit / Savior damage reduction. Apply the SAME shared mitigation here, in the same order
		// on_player_damaged uses (mitigate first, THEN the demigod clamp), so armor protects vs Panzer too.
		if(isdefined(level.tod_player_mitigations_fn))
		{
			// [tod] v9.45: eattacker (the Panzer) is passed through as arg 2 — BACK
			// ARMOR needs to know WHERE the hit came from, and this lane is the only
			// place that knows. Arity note: T7 resolves by name+arity, and MORE args
			// than the callee declares is a boot-time Unresolved external — so
			// _tod_bosses::apply_player_mitigations must keep its 2-param signature.
			dmg = self [[ level.tod_player_mitigations_fn ]](dmg, eattacker);   // [tod] pointer, not #using (cycle rule)
		}
		// [acc] DEMIGOD clamp (user 2026-07-08): this callback registered at REGISTER_SYSTEM time =
		// FIRST in the chain, so its return SHORT-CIRCUITS _acc_elites::on_player_damaged - the god
		// handler - entirely (this exact hit was killing godded players; memory
		// player-damage-callbacks-return-minus-one). Mirror the elites demigod contract here:
		// damage lands for real, health floors at 1 HP, no death.
		if(IS_TRUE(level.acc_god))
		{
			if(dmg >= self.health)
			{
				dmg = self.health - 1;
			}
			if(dmg < 0)
			{
				dmg = 0;
			}
		}
		return dmg;
	}
	return -1;
}

/*
	Name: function_58655f2a
	Namespace: zm_ai_mechz
	Checksum: 0x1CBB4EE6
	Offset: 0xF00
	Size: 0x31
	Parameters: 0
	Flags: None
*/
function function_58655f2a()
{
	// [acc] DECOMPILER ARTIFACT FIX x3 (this fn + the two below, 2026-07-11): `!isdefined(x) && x`
	// reads the field EXACTLY when undefined -> "cannot cast undefined to bool". THIS one is a
	// polled stun-condition, so it was the 10Hz exception spam in the 2:41 PM run log (816 throws
	// over one Panzer's lifetime). Restored stock's `!IS_TRUE(self.stun)` shape (ai/mechz.gsc) +
	// isdefined-guarded the cooldown compare (undefined < int also throws).
	if(!(isdefined(self.stun) && self.stun) && isdefined(self.stumble_stun_cooldown_time) && self.stumble_stun_cooldown_time < GetTime())
	{
		return 1;
	}
	return 0;
}

/*
	Name: function_9bac2f00
	Namespace: zm_ai_mechz
	Checksum: 0x7F52E823
	Offset: 0xF40
	Size: 0x67
	Parameters: 2
	Flags: None
*/
function function_9bac2f00(e_player, gib)
{
	self endon("death");
	self function_b8e0ce15(e_player);
	// [acc] artifact fix (see function_58655f2a)
	if(!(isdefined(self.stun) && self.stun) && isdefined(self.stumble_stun_cooldown_time) && self.stumble_stun_cooldown_time < GetTime())
	{
		self.stun = 1;
	}
}

/*
	Name: function_19b9b682
	Namespace: zm_ai_mechz
	Checksum: 0xF8494751
	Offset: 0xFB0
	Size: 0x67
	Parameters: 2
	Flags: None
*/
function function_19b9b682(e_player, gib)
{
	self endon("death");
	self function_b8e0ce15(e_player);
	// [acc] artifact fix (see function_58655f2a)
	if(!(isdefined(self.stun) && self.stun) && isdefined(self.stumble_stun_cooldown_time) && self.stumble_stun_cooldown_time < GetTime())
	{
		self.stun = 1;
	}
}

/*
	Name: function_b8e0ce15
	Namespace: zm_ai_mechz
	Checksum: 0x17BF523A
	Offset: 0x1020
	Size: 0xCB
	Parameters: 1
	Flags: None
*/
function function_b8e0ce15(e_player)
{
	var_3bb42832 = level.mechz_health;
	if(isdefined(level.var_f4dc2834))
	{
		var_3bb42832 = math::clamp(var_3bb42832, 0, level.var_f4dc2834);
	}
	n_damage = var_3bb42832 * 0.25 / 0.2;
	self DoDamage(n_damage, self GetCentroid(), e_player, e_player, undefined, "MOD_PROJECTILE_SPLASH", 0, GetWeapon("thundergun"));
}

/*
	Name: spawn_mechz
	Namespace: zm_ai_mechz
	Checksum: 0x9A47B505
	Offset: 0x10F8
	Size: 0x50F
	Parameters: 2
	Flags: None
*/
function spawn_mechz(s_location, flyin)
{
	if(!isdefined(flyin))
	{
		flyin = 0;
	}
	if(isdefined(level.mechz_spawners[0]))
	{
		if(isdefined(level.var_7f2a926d))
		{
			[[level.var_7f2a926d]]();
		}
		level.mechz_spawners[0].script_forcespawn = 1;
		ai = zombie_utility::spawn_zombie(level.mechz_spawners[0], "mechz", s_location);
		if(isdefined(ai))
		{
			ai DisableAimAssist();
			ai thread function_ef1ba7e5();
			ai thread function_949a3fdf();
			/#
				ai thread function_75a79bb5();
			#/
			ai.actor_damage_func = &MechzServerUtils::mechzDamageCallback;
			ai.damage_scoring_function = &function_b03abc02;
			ai.mechz_melee_knockdown_function = &function_55483494;
			ai.health = level.mechz_health;
			ai.faceplate_health = level.MECHZ_FACEPLATE_HEALTH;
			ai.powercap_cover_health = level.MECHZ_POWERCAP_COVER_HEALTH;
			ai.powercap_health = level.MECHZ_POWERCAP_HEALTH;
			ai.left_knee_armor_health = level.var_2cbc5b59;
			ai.right_knee_armor_health = level.var_2cbc5b59;
			ai.left_shoulder_armor_health = level.var_2cbc5b59;
			ai.right_shoulder_armor_health = level.var_2cbc5b59;
			ai.heroweapon_kill_power = 10;
			e_player = zm_utility::get_closest_player(s_location.origin);
			v_dir = e_player.origin - s_location.origin;
			v_dir = vectornormalize(v_dir);
			v_angles = VectorToAngles(v_dir);
			var_89f898ad = zm_utility::flat_angle(v_angles);
			var_6ea4ef96 = s_location;
			queryResult = PositionQuery_Source_Navigation(var_6ea4ef96.origin, 0, 32, 20, 4);
			if(queryResult.data.size)
			{
				v_ground_position = array::random(queryResult.data).origin;
			}
			if(!isdefined(v_ground_position))
			{
				trace = bullettrace(var_6ea4ef96.origin, var_6ea4ef96.origin + VectorScale((0, 0, -1), 256), 0, s_location);
				v_ground_position = trace["position"];
			}
			var_1750e965 = v_ground_position;
			if(isdefined(level.var_e1e49cc1))
			{
				ai thread [[level.var_e1e49cc1]]();
			}
			ai ForceTeleport(var_1750e965, var_89f898ad);
			if(flyin === 1)
			{
				ai thread function_d07fd448();
				ai thread scene::play("cin_zm_castle_mechz_entrance", ai);
				ai thread function_c441eaba(var_1750e965);
				ai thread function_bbdc1f34(var_1750e965);
			}
			else if(isdefined(level.var_7d2a391d))
			{
				ai thread [[level.var_7d2a391d]]();
			}
			ai.b_flyin_done = 1;
			ai thread function_bb048b27();
			ai.ignore_round_robbin_death = 1;
			/#
				ai.ignore_devgui_death = 1;
			#/
			return ai;
		}
	}
	return undefined;
}

/*
	Name: function_d07fd448
	Namespace: zm_ai_mechz
	Checksum: 0xD4416EA0
	Offset: 0x1610
	Size: 0x63
	Parameters: 0
	Flags: None
*/
function function_d07fd448()
{
	self endon("death");
	self.b_flyin_done = 0;
	self.bgbIgnoreFearInHeadlights = 1;
	self util::waittill_any("mechz_flyin_done", "scene_done");
	self.b_flyin_done = 1;
	self.bgbIgnoreFearInHeadlights = 0;
}

/*
	Name: function_c441eaba
	Namespace: zm_ai_mechz
	Checksum: 0x7E37640
	Offset: 0x1680
	Size: 0x34B
	Parameters: 1
	Flags: None
*/
function function_c441eaba(var_678a2319)
{
	self endon("death");
	var_b54110bd = 2304;
	var_f0dad551 = 9216;
	var_44615973 = 2250000;
	self waittill("hash_f93797a6");
	a_zombies = GetAIArchetypeArray("zombie");
	foreach(e_zombie in a_zombies)
	{
		dist_sq = distancesquared(e_zombie.origin, var_678a2319);
		if(dist_sq <= var_b54110bd)
		{
			e_zombie kill();
		}
	}
	a_players = GetPlayers();
	foreach(player in a_players)
	{
		dist_sq = distancesquared(player.origin, var_678a2319);
		if(dist_sq <= var_b54110bd)
		{
			player DoDamage(100, var_678a2319, self, self);
		}
		scale = var_44615973 - dist_sq / var_44615973;
		if(scale <= 0 || scale >= 1)
		{
			return;
		}
		earthquake_scale = scale * 0.15;
		earthquake(earthquake_scale, 0.1, var_678a2319, 1500);
		if(scale >= 0.66)
		{
			player PlayRumbleOnEntity("shotgun_fire");
			continue;
		}
		if(scale >= 0.33)
		{
			player PlayRumbleOnEntity("damage_heavy");
			continue;
		}
		player PlayRumbleOnEntity("reload_small");
	}
	if(isdefined(self.var_1411e129))
	{
		self.var_1411e129 delete();
	}
}

/*
	Name: function_bbdc1f34
	Namespace: zm_ai_mechz
	Checksum: 0xE3ED89A7
	Offset: 0x19D8
	Size: 0x27F
	Parameters: 1
	Flags: None
*/
function function_bbdc1f34(var_678a2319)
{
	self endon("death");
	self endon("hash_f93797a6");
	self waittill("hash_3d18ed4f");
	var_f0dad551 = 9216;
	while(1)
	{
		a_players = GetPlayers();
		foreach(player in a_players)
		{
			dist_sq = distancesquared(player.origin, var_678a2319);
			if(dist_sq <= var_f0dad551)
			{
				// [acc] DECOMPILER ARTIFACT FIX (2026-07-11, found via console_mp.log): the shipped source
				// dropped the parens off !IS_TRUE(is_burning), leaving `!isdefined(x) && x` - which reads
				// the field EXACTLY when it is undefined -> "cannot cast undefined to bool" thrown at 10Hz
				// (this wait(0.1) loop) AND the ground-fire could never ignite anyone (condition was
				// unsatisfiable). Later same day: field renamed to the self-expiring acc_mechz_burn_until
				// latch (is_burning on players trips stock's missing-asset lava_small shellshock - see
				// function_3389e2f3 for the full story).
				if(!(isdefined(player.acc_mechz_burn_until) && GetTime() < player.acc_mechz_burn_until) && zombie_utility::is_player_valid(player, 0))
				{
					player function_3389e2f3(self);
				}
			}
		}
		a_zombies = array::filter( getAIArchetypeArray( "zombie" ), 0, &function_b804eb62 );
		foreach(e_zombie in a_zombies)
		{
			dist_sq = distancesquared(e_zombie.origin, var_678a2319);
			if(dist_sq <= var_f0dad551 && self.var_e05d0be2 !== 1)
			{
				self function_3efae612(e_zombie);
				e_zombie make_napalm_zombie();
			}
		}
		wait(0.1);
	}
}

function function_b804eb62(ai_zombie)
{
	return ai_zombie.is_elemental_zombie !== 1;
}


/*
	Name: function_3389e2f3
	Namespace: zm_ai_mechz
	Checksum: 0xE270D828
	Offset: 0x1C60
	Size: 0xDF
	Parameters: 1
	Flags: None
*/
function function_3389e2f3(mechz)
{
	// [acc] 2026-07-11 rework, three fixes in one (self = the player being ignited):
	// 1. ARTIFACT: the pack's `!isdefined(x) && x` guard threw AND never let the body run (players
	//    could never be ignited by the ground fire).
	// 2. FIELD RENAME is_burning -> acc_mechz_burn_until: stock _zm_utility.gsc:3776 requests the
	//    shellshock assets "lava"/"lava_small" whenever a player with is_burning takes explosive
	//    damage - those assets are NOT in any fastfile this map loads (no shellshock GDF exists to
	//    author them) -> "shellshock 'lava_small' was not precached" throw that KILLS the stock
	//    per-player damage-feedback loop (seen live 2:41 PM log). No other system on this map reads
	//    player.is_burning (burnplayer never touches it), so renaming removes the crash path wholesale.
	// 3. SELF-EXPIRING MUTEX (time-based, replaces the wait/reset pair): the old shape left the latch
	//    stuck ON if the player died mid-wait (stock cleans is_burning up in _zm.gsc:3327 - a rename
	//    loses that), and the inline wait(1.5) stalled the caller's 0.1s ground-fire sweep.
	if(!(isdefined(self.acc_mechz_burn_until) && GetTime() < self.acc_mechz_burn_until) && zombie_utility::is_player_valid(self, 1))
	{
		self.acc_mechz_burn_until = GetTime() + 1500;   // matches the 1.5s SetPlayerBurning duration
		// [tod 2026-08-23] HALVED — see TOD_PANZER_FIRE_MULT at the top of this
		// file. THIS is the ground-fire pool, and it had NEVER been scaled: it
		// sat at the raw stock 30/20 through every "Panzer hits too hard" pass,
		// because it bypasses both tod mitigation lanes. Per tick: 30 -> 15
		// (no Jugg), 20 -> 10 (Jugg).
		if(!self hasPerk("specialty_armorvest"))
		{
			self burnplayer::SetPlayerBurning(1.5, 0.5, int(30 * TOD_PANZER_FIRE_MULT), mechz, undefined);
		}
		else
		{
			self burnplayer::SetPlayerBurning(1.5, 0.5, int(20 * TOD_PANZER_FIRE_MULT), mechz, undefined);
		}
	}
}

/*
	Name: function_817c85eb
	Namespace: zm_ai_mechz
	Checksum: 0xDAA3C3AB
	Offset: 0x1D48
	Size: 0x2C7
	Parameters: 6
	Flags: None
*/
function function_817c85eb(e_player, v_attack_source, n_push_away, n_lift_height, v_lift_offset, n_lift_speed)
{
	self endon("death");
	if(isdefined(self.in_gravity_trap) && self.in_gravity_trap && e_player.gravityspikes_state === 3)
	{
		if(isdefined(self.var_1f5fe943) && self.var_1f5fe943)
		{
			return;
		}
		self.var_bcecff1d = 1;
		self.var_1f5fe943 = 1;
		self DoDamage(10, self.origin);
		self.var_ab0efcf6 = self.origin;
		self thread scene::play("cin_zm_dlc1_mechz_dth_deathray_01", self);
		// [acc] "sparky_beam_fx" is registered NOWHERE (neither side) - setting it is an instant
		// script error. Gravity-spikes(DG-4)-only path, dormant on this map; disarmed anyway.
		// self clientfield::set("sparky_beam_fx", 1);
		self clientfield::set("death_ray_shock_fx", 1);
		self playsound("zmb_talon_electrocute");
		n_start_time = GetTime();
		for(n_total_time = 0; 10 > n_total_time && e_player.gravityspikes_state === 3;  n_total_time++)
		{
			util::wait_network_frame();
		}
		self scene::stop("cin_zm_dlc1_mechz_dth_deathray_01");
		self thread function_bb84a54(self);
		// [acc] see above - "sparky_beam_fx" registered nowhere.
		// self clientfield::set("sparky_beam_fx", 0);
		self clientfield::set("death_ray_shock_fx", 0);
		self.var_bcecff1d = undefined;
		while(e_player.gravityspikes_state === 3)
		{
			util::wait_network_frame();
		}
		self.var_1f5fe943 = undefined;
		self.in_gravity_trap = undefined;
	}
	else
	{
		self DoDamage(10, self.origin);
		if(!(isdefined(self.stun) && self.stun))
		{
			self.stun = 1;
		}
	}
}

/*
	Name: function_bb84a54
	Namespace: zm_ai_mechz
	Checksum: 0x6CFD4C09
	Offset: 0x2018
	Size: 0x1A3
	Parameters: 1
	Flags: None
*/
function function_bb84a54(mechz)
{
	mechz endon("death");
	if(isdefined(mechz))
	{
		mechz scene::play("cin_zm_dlc1_mechz_dth_deathray_02", mechz);
	}
	if(isdefined(mechz) && isalive(mechz) && isdefined(mechz.var_ab0efcf6))
	{
		v_eye_pos = mechz gettagorigin("tag_eye");
		/#
			recordLine(mechz.origin, v_eye_pos, VectorScale((0, 1, 0), 255), "Dev Block strings are not supported", mechz);
		#/
		trace = bullettrace(v_eye_pos, mechz.origin, 0, mechz);
		if(trace["position"] !== mechz.origin)
		{
			point = GetClosestPointOnNavMesh(trace["position"], 64, 30);
			if(!isdefined(point))
			{
				point = mechz.var_ab0efcf6;
			}
			mechz ForceTeleport(point);
		}
	}
}

/*
	Name: function_1add8026
	Namespace: zm_ai_mechz
	Checksum: 0x42984563
	Offset: 0x21C8
	Size: 0x101
	Parameters: 1
	Flags: None
*/
function function_1add8026(mechz)
{
	flameTrigger = mechz.flameTrigger;
	a_zombies = array::filter( getAIArchetypeArray( "zombie" ), 0, &function_b804eb62 );
	foreach(zombie in a_zombies)
	{
		if(zombie istouching(flameTrigger) && zombie.var_e05d0be2 !== 1)
		{
			zombie make_napalm_zombie();
		}
	}
}


function make_napalm_zombie()
{
	if(isdefined(self))
	{
		ai_zombie = self;
		var_ac4641b = function_4aeed0a5("napalm");
		if(!isdefined(level.var_bd64e31e) || var_ac4641b < level.var_bd64e31e)
		{
			if(!isdefined(ai_zombie.is_elemental_zombie) || ai_zombie.is_elemental_zombie == 0)
			{
				ai_zombie.is_elemental_zombie = 1;
				ai_zombie.var_9a02a614 = "napalm";
				ai_zombie clientfield::set("arch_actor_fire_fx", 1);
				ai_zombie clientfield::set("napalm_sfx", 1);
				ai_zombie.health = Int(ai_zombie.health * 0.75);
				ai_zombie thread function_e94aef80();
				ai_zombie thread function_d070bfba();
				ai_zombie zombie_utility::set_zombie_run_cycle("sprint");
			}
		}
	}
}


function function_e94aef80()
{
	ai_zombie = self;
	ai_zombie waittill("death", attacker);
	if(!isdefined(ai_zombie) || ai_zombie.nuked === 1)
	{
		return;
	}
	ai_zombie clientfield::set("napalm_zombie_death_fx", 1);
	ai_zombie zombie_utility::gib_random_parts();
	GibServerUtils::Annihilate(ai_zombie);
	if(isdefined(level.var_36b5dab) && level.var_36b5dab || (isdefined(ai_zombie.var_36b5dab) && ai_zombie.var_36b5dab))
	{
		ai_zombie.custom_player_shellshock = &function_e6cd7e78;
	}
	RadiusDamage(ai_zombie.origin + VectorScale((0, 0, 1), 35), 128, 70, 30, self, "MOD_EXPLOSIVE");
}

function function_d070bfba()
{
	self endon("entityshutdown");
	self endon("death");
	while(1)
	{
		self waittill("damage");
		if(RandomInt(100) < 50)
		{
			self clientfield::increment("napalm_damaged_fx");
		}
		wait(0.05);
	}
}

/*
	Name: function_e6cd7e78
	Namespace: namespace_57695b4d
	Checksum: 0x93CF4833
	Offset: 0xEA0
	Size: 0x73
	Parameters: 5
	Flags: None
*/
function function_e6cd7e78(damage, attacker, direction_vec, point, mod)
{
	if(GetDvarString("blurpain") == "on")
	{
		self shellshock("pain_zm", 0.5);
	}
}


function function_c50e890f(type)
{
	a_zombies = GetAIArchetypeArray("zombie");
	a_filtered_zombies = Array::filter(a_zombies, 0, &function_361f6caa, type);
	return a_filtered_zombies;
}


function function_4aeed0a5(type)
{
	a_zombies = function_c50e890f(type);
	return a_zombies.size;
}


function function_361f6caa(ai_zombie, type)
{
	return ai_zombie.var_9a02a614 === type;
}



/*
	Name: function_ef1ba7e5
	Namespace: zm_ai_mechz
	Checksum: 0x6ECF0982
	Offset: 0x22D8
	Size: 0x9F
	Parameters: 0
	Flags: None
*/
function function_ef1ba7e5()
{
	self waittill("death");
	if(isplayer(self.attacker))
	{
		event = "death_mechz";
		if(!(isdefined(self.deathpoints_already_given) && self.deathpoints_already_given))
		{
			self.attacker zm_score::player_add_points(event, 1500);
		}
		if(isdefined(level.hero_power_update))
		{
			[[level.hero_power_update]](self.attacker, self);
		}
	}
}

/*
	Name: function_949a3fdf
	Namespace: zm_ai_mechz
	Checksum: 0xC9753F16
	Offset: 0x2380
	Size: 0x171
	Parameters: 0
	Flags: None
*/
function function_949a3fdf()
{
	self waittill("hash_46c1e51d");
	v_origin = self.origin;
	a_ai = GetAISpeciesArray(level.zombie_team);
	a_ai_kill_zombies = ArraySortClosest(a_ai, v_origin, 18, 0, 200);
	foreach(ai_enemy in a_ai_kill_zombies)
	{
		if(isdefined(ai_enemy))
		{
			if(ai_enemy.archetype === "mechz")
			{
				ai_enemy DoDamage(level.mechz_health * 0.25, v_origin);
			}
			else
			{
				ai_enemy DoDamage(ai_enemy.health + 100, v_origin);
			}
		}
		wait(0.05);
	}
}

/*
	Name: function_b03abc02
	Namespace: zm_ai_mechz
	Checksum: 0xD98EAD1A
	Offset: 0x2500
	Size: 0x10B
	Parameters: 12
	Flags: None
*/
function function_b03abc02(inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitloc, offsetTime, boneIndex, modelIndex)
{
	if(isdefined(attacker) && isplayer(attacker))
	{
		if(zm_spawner::player_using_hi_score_weapon(attacker))
		{
			damage_type = "damage";
		}
		else
		{
			damage_type = "damage_light";
		}
		if(!(isdefined(self.no_damage_points) && self.no_damage_points))
		{
			attacker zm_score::player_add_points(damage_type, mod, hitloc, self.isdog, self.team, weapon);
		}
	}
}

/*
	Name: function_3efae612
	Namespace: zm_ai_mechz
	Checksum: 0x6D1727E3
	Offset: 0x2618
	Size: 0x2A3
	Parameters: 1
	Flags: None
*/
function function_3efae612(zombie)
{
	zombie.knockdown = 1;
	zombie.knockdown_type = "knockdown_shoved";
	zombie_to_mechz = self.origin - zombie.origin;
	zombie_to_mechz_2d = vectornormalize((zombie_to_mechz[0], zombie_to_mechz[1], 0));
	zombie_forward = AnglesToForward(zombie.angles);
	zombie_forward_2d = vectornormalize((zombie_forward[0], zombie_forward[1], 0));
	zombie_right = AnglesToRight(zombie.angles);
	zombie_right_2d = vectornormalize((zombie_right[0], zombie_right[1], 0));
	dot = VectorDot(zombie_to_mechz_2d, zombie_forward_2d);
	if(dot >= 0.5)
	{
		zombie.knockdown_direction = "front";
		zombie.getup_direction = "getup_back";
	}
	else if(dot < 0.5 && dot > -0.5)
	{
		dot = VectorDot(zombie_to_mechz_2d, zombie_right_2d);
		if(dot > 0)
		{
			zombie.knockdown_direction = "right";
			if(math::cointoss())
			{
				zombie.getup_direction = "getup_back";
			}
			else
			{
				zombie.getup_direction = "getup_belly";
			}
		}
		else
		{
			zombie.knockdown_direction = "left";
			zombie.getup_direction = "getup_belly";
		}
	}
	else
	{
		zombie.knockdown_direction = "back";
		zombie.getup_direction = "getup_belly";
	}
}

/*
	Name: function_55483494
	Namespace: zm_ai_mechz
	Checksum: 0x8DDC6FC8
	Offset: 0x28C8
	Size: 0x109
	Parameters: 0
	Flags: None
*/
function function_55483494()
{
	a_zombies = GetAIArchetypeArray("zombie");
	foreach(zombie in a_zombies)
	{
		dist_sq = distancesquared(self.origin, zombie.origin);
		if(zombie function_10d36217(self) && dist_sq <= 12544)
		{
			self function_3efae612(zombie);
		}
	}
}

/*
	Name: function_10d36217
	Namespace: zm_ai_mechz
	Checksum: 0x97014B61
	Offset: 0x29E0
	Size: 0x183
	Parameters: 1
	Flags: None
*/
function function_10d36217(mechz)
{
	origin = self.origin;
	facing_vec = AnglesToForward(mechz.angles);
	enemy_vec = origin - mechz.origin;
	enemy_yaw_vec = (enemy_vec[0], enemy_vec[1], 0);
	facing_yaw_vec = (facing_vec[0], facing_vec[1], 0);
	enemy_yaw_vec = vectornormalize(enemy_yaw_vec);
	facing_yaw_vec = vectornormalize(facing_yaw_vec);
	enemy_dot = VectorDot(facing_yaw_vec, enemy_yaw_vec);
	if(enemy_dot < 0.7)
	{
		return 0;
	}
	enemy_angles = VectorToAngles(enemy_vec);
	if(Abs(AngleClamp180(enemy_angles[0])) > 45)
	{
		return 0;
	}
	return 1;
}

/*
	Name: function_bb048b27
	Namespace: zm_ai_mechz
	Checksum: 0x433026DB
	Offset: 0x2B70
	Size: 0x57
	Parameters: 0
	Flags: None
*/
function function_bb048b27()
{
	self endon("death");
	while(1)
	{
		wait(randomintrange(9, 14));
		self playsound("zmb_ai_mechz_vox_ambient");
	}
}

/*
	Name: function_75a79bb5
	Namespace: zm_ai_mechz
	Checksum: 0xEEE038CF
	Offset: 0x2BD0
	Size: 0x97
	Parameters: 0
	Flags: None
*/
function function_75a79bb5()
{
	self endon("death");
	/#
		while(1)
		{
			if(isdefined(level.var_70068a8) && level.var_70068a8)
			{
				if(self.health > 0)
				{
					print3d(self.origin + VectorScale((0, 0, 1), 72), self.health, (0, 0.8, 0.6), 3);
				}
			}
			wait(0.05);
		}
	#/
}

/*
	Name: function_fbad70fd
	Namespace: zm_ai_mechz
	Checksum: 0xF8F6CEC
	Offset: 0x2C70
	Size: 0x43
	Parameters: 0
	Flags: Private
*/
function private function_fbad70fd()
{
	/#
		level flagsys::wait_till("Dev Block strings are not supported");
		//zm_devgui::function_4acecab5(&function_94a24a91);
	#/
}

/*
	Name: function_94a24a91
	Namespace: zm_ai_mechz
	Checksum: 0xA825197A
	Offset: 0x2CC0
	Size: 0x40D
	Parameters: 1
	Flags: Private
*/
function private function_94a24a91(cmd)
{
	/#
		players = GetPlayers();
		var_6aad1b23 = getentarray("Dev Block strings are not supported", "Dev Block strings are not supported");
		mechz = ArrayGetClosest(GetPlayers()[0].origin, var_6aad1b23);
		switch(cmd)
		{
			case "Dev Block strings are not supported":
			{
				queryResult = PositionQuery_Source_Navigation(players[0].origin, 128, 256, 128, 20);
				spot = spawnstruct();
				spot.origin = players[0].origin;
				if(isdefined(queryResult) && queryResult.data.size > 0)
				{
					spot.origin = queryResult.data[0].origin;
				}
				mechz = spawn_mechz(spot);
				break;
			}
			case "Dev Block strings are not supported":
			{
				if(!isdefined(level.zm_loc_types["Dev Block strings are not supported"]) || level.zm_loc_types["Dev Block strings are not supported"].size == 0)
				{
					iprintln("Dev Block strings are not supported");
				}
				spot = ArrayGetClosest(GetPlayers()[0].origin, level.zm_loc_types["Dev Block strings are not supported"]);
				if(isdefined(spot))
				{
					mechz = spawn_mechz(spot, 1);
				}
				else
				{
					iprintln("Dev Block strings are not supported");
				}
				break;
			}
			case "Dev Block strings are not supported":
			{
				if(isdefined(mechz))
				{
					mechz kill();
				}
				break;
			}
			case "Dev Block strings are not supported":
			{
				if(isdefined(mechz))
				{
					if(isdefined(mechz.shoot_grenade))
					{
						mechz.shoot_grenade = !mechz.shoot_grenade;
					}
					else
					{
						mechz.shoot_grenade = 1;
					}
				}
				break;
			}
			case "Dev Block strings are not supported":
			{
				if(isdefined(mechz))
				{
					if(isdefined(mechz.shoot_flame))
					{
						mechz.shoot_flame = !mechz.shoot_flame;
					}
					else
					{
						mechz.shoot_flame = 1;
					}
				}
				break;
			}
			case "Dev Block strings are not supported":
			{
				if(isdefined(mechz))
				{
					mechz.berserk = 1;
				}
				break;
			}
			case "Dev Block strings are not supported":
			{
				if(!(isdefined(level.var_70068a8) && level.var_70068a8))
				{
					level.var_70068a8 = 1;
				}
				else
				{
					level.var_70068a8 = 0;
				}
				break;
			}
			case "Dev Block strings are not supported":
			{
				if(!(isdefined(level.b_mechz_true_ignore) && level.b_mechz_true_ignore))
				{
					level.b_mechz_true_ignore = 1;
				}
				else
				{
					level.b_mechz_true_ignore = 0;
				}
				break;
			}
		}
	#/
}




function private mechzShouldShootClaw(entity)
{
	if(!isdefined(entity.favoriteenemy))
	{
		return 0;
	}
	if(!(isdefined(entity.has_powercap) && entity.has_powercap))
	{
		return 0;
	}
	if(isdefined(entity.last_claw_time) && GetTime() - self.last_claw_time < level.mechz_claw_cooldown_time)
	{
		return 0;
	}
	if(isdefined(entity.Berserk) && entity.Berserk)
	{
		return 0;
	}
	if(!entity MechzServerUtils::mechzCheckInArc())
	{
		return 0;
	}
	dist_sq = DistanceSquared(entity.origin, entity.favoriteenemy.origin);
	if(dist_sq < 40000 || dist_sq > 1000000)
	{
		return 0;
	}
	if(!entity.favoriteenemy player_can_be_grabbed())
	{
		return 0;
	}
	curr_zone = zm_zonemgr::get_zone_from_position(self.origin + VectorScale((0, 0, 1), 36));
	if(isdefined(curr_zone) && "ug_bottom_zone" == curr_zone)
	{
		return 0;
	}
	clip_mask = 1 | 8;
	claw_origin = entity.origin + VectorScale((0, 0, 1), 65);
	trace = PhysicsTrace(claw_origin, entity.favoriteenemy.origin + VectorScale((0, 0, 1), 30), (-15, -15, -20), (15, 15, 40), entity, clip_mask);
	b_cansee = trace["fraction"] == 1 || (isdefined(trace["entity"]) && trace["entity"] == entity.favoriteenemy);
	if(!b_cansee)
	{
		return 0;
	}
}



function private player_can_be_grabbed()
{
	if(self GetStance() == "prone")
	{
		return 0;
	}
	// [tod 2026-09-24] Honour .ignoreme (Zombie Blood): the claw must not fire
	// at a player the Panzer is supposed to be ignoring.
	if(!zm_utility::is_player_valid(self, 1))
	{
		return 0;
	}
	return 1;
}

function private zmMechzShootClawActionStart(entity, asmStateName)
{
	AnimationStateNetworkUtility::RequestState(entity, asmStateName);
	zmMechzShootClaw(entity);
	return 5;
}


function private zmMechzShootClawActionUpdate(entity, asmStateName)
{
	if(!(isdefined(entity.var_7bee990f) && entity.var_7bee990f))
	{
		return 4;
	}
	return 5;
}


function private zmMechzShootClawActionEnd(entity, asmStateName)
{
	return 4;
}


function private zmMechzShootClaw(entity)
{
	self thread function_31c4b972();
	level flag::set("mechz_launching_claw");
}


function private zmMechzUpdateClaw(entity)
{
}


function private zmMechzStopClaw(entity)
{
}


function private muzzleflash(entity)
{
	self.var_7bee990f = 1;
	self.last_claw_time = GetTime();
	entity function_672f9804();
	entity function_90832db7();
	self.last_claw_time = GetTime();
}

/*
	Name: function_48c03479
	Namespace: namespace_19d9d56d
	Checksum: 0x4E70C510
	Offset: 0x10C0
	Size: 0x63
	Parameters: 1
	Flags: Private
*/
function private start_ft(entity)
{
	entity notify("hash_8225d137");
	entity clientfield::set("mechz_ft", 1);
	acc_ft_visual_state(entity, true);
	entity.isShootingFlame = 1;
	entity thread function_fa513ca0();
}

/*
	Name: function_fa513ca0
	Namespace: namespace_19d9d56d
	Checksum: 0xC2AC5BEF
	Offset: 0x1130
	Size: 0x117
	Parameters: 0
	Flags: Private
*/
function private function_fa513ca0()
{
	self endon("death");
	self endon("hash_8225d137");
	self thread acc_ft_fx_off_on_death();
	while(1)
	{
		// [tod 2026-09-08] THE FLAME OUTLIVED THE ANIMATION (user: "he will shoot his fire
		// and then end the animation to run at you but you are still being burned").
		// This loop is started by the start_ft anim notetrack and, until today, could ONLY be
		// stopped by the stop_ft notetrack ("hash_8225d137"). But the flame is a BEHAVIOR TREE
		// action, and stock leaves it WITHOUT the animation ever reaching stop_ft:
		// mechzShootFlameActionUpdate calls mechzStopFlame and returns SUCCESS the moment he
		// goes berserk or decides to MELEE (mechz.gsc:735-752), and mechzShootFlameActionEnd
		// calls it on any other interruption. NONE of those notify us. So "he cuts the flame
		// short to charge you" left this loop running for the rest of his life - and
		// flameTrigger is LinkTo'd to tag_flamethrower_fx, so it is a burn cone that FOLLOWS
		// him while he sprints at you.
		// mechzStopFlame's own state is the authority, so read it instead of trusting a
		// notetrack that may never play:
		//   isShootingFlame       - cleared by every stock stop path.
		//   stopShootingFlameTime - stock's MECHZ_FT_RUN_DURATION (2.5s) deadline. It is
		//                           UNDEFINED outside the BT action, so the claw grab-burn
		//                           (a scripted anim that DOES run its stop_ft) is untouched.
		if(!(isdefined(self.isShootingFlame) && self.isShootingFlame)
			|| (isdefined(self.stopShootingFlameTime) && GetTime() > self.stopShootingFlameTime))
		{
			acc_ft_fx_off(self);
			return;
		}

		// [acc] flameTrigger only exists once mechzSpawnSetup has run (archetype spawn funcs) -
		// unguarded istouching(undefined) THROWS and kills the flame damage loop.
		if(!isdefined(self.flameTrigger))
		{
			wait(0.25);
			continue;
		}
		players = GetPlayers();
		foreach(player in players)
		{
			// [acc] 2026-07-11: renamed to the self-expiring acc_mechz_burn_until latch (see
			// function_3389e2f3 - player.is_burning trips stock's missing lava_small shellshock).
			if(!(isdefined(player.acc_mechz_burn_until) && GetTime() < player.acc_mechz_burn_until))
			{
				if(player istouching(self.flameTrigger))
				{
					// [acc] was MechzBehavior::playerFlameDamage(self) - replaced with our
					// scaled twin (user 2026-07-11: flamethrower +20%). See acc_player_flame_damage.
					player thread acc_player_flame_damage(self);
				}
			}
		}
		wait(0.05);
	}
}

// [acc] scaled twin of stock MechzBehavior::playerFlameDamage (mechz.gsc:835) - the flame damage
// constants are stock #defines (MECHZ_FT_PLAYER_DAMAGE 30 / _JUGG 20, 0.5s ticks over a 1.5s burn
// = ~3 ticks) inside a stock function we can't edit, so the flame loop above calls this instead.
// Jugg branch, burnplayer::SetPlayerBurning (already #using'd).
//
// [tod 2026-09-08] THIS IS NOW THE ONLY FLAME-CONE DAMAGE ON THE MAP. Until today
// stock's own mechzUpdateFlame swept the same cone every behavior-tree tick and ran
// stock playerFlameDamage at the raw 30/20, in parallel with this, on a separate
// latch — and SetPlayerBurning does not stack, so the last caller of the frame won
// and the cone did full or half damage more or less at random. __init__ now claims
// level.mechz_flamethrower_player_callback, so this function owns the number.
// Per tick: TOD_PANZER_FLAME_DMG / _JUGG (25 / 12 today) — read the defines, never
// this line. Historical note kept because it is the reason the pinning happened:
// the original "+20%" (1.2) was tuned while the burn path was secretly dead (a
// decompiler artifact), so it was never actually felt until the path was fixed,
// and the two later +10% passes then walked the cone up to 36/tick = 108 total =
// a guaranteed no-Jugg down from a single tag.
// MUTEX 2026-07-11: acc_mechz_burn_until (self-expiring time latch) REPLACED the is_burning
// wait/reset latch - is_burning on a player triggers stock _zm_utility's "lava_small" shellshock
// on explosive hits, an asset NOT in our fastfiles = a throw that kills the stock damage-feedback
// loop (full story at function_3389e2f3). The old "shared with stock flame sources" mutex argument
// is moot: this map has no other player-burn source.
function acc_player_flame_damage(mechz)   // self = the player
{
	self endon("death");
	self endon("disconnect");

	if(!(isdefined(self.acc_mechz_burn_until) && GetTime() < self.acc_mechz_burn_until) && zombie_utility::is_player_valid(self, 1))
	{
		self.acc_mechz_burn_until = GetTime() + 1500;   // matches the 1.5s SetPlayerBurning duration
		// [tod 2026-09-08] the two pinned cone constants at the top of this file.
		if(!self hasPerk("specialty_armorvest"))
		{
			self burnplayer::SetPlayerBurning(1.5, 0.5, TOD_PANZER_FLAME_DMG, mechz, undefined);
		}
		else
		{
			self burnplayer::SetPlayerBurning(1.5, 0.5, TOD_PANZER_FLAME_DMG_JUGG, mechz, undefined);
		}
	}
}

// [tod 2026-09-08] stock's flame-cone sweep, redirected here (see __init__). Stock calls
// this from mechzShootFlameActionUpdate every behavior-tree tick while the flame is up, and
// passes the Panzer as a PARAMETER - there is no useful `self` in a BT action, so read only
// `entity`. Same cone, same latch and same damage function as the notetrack loop above, so
// the two are idempotent: whichever reaches a player first sets acc_mechz_burn_until and the
// other finds it held. This lane's lifetime is stock's own action, so it cannot outlive the
// animation; the notetrack loop stays because the claw grab-burn is a scripted anim that
// runs outside the behavior-tree flame action entirely.
function acc_mechz_flame_player_cb(entity)
{
	if(!isdefined(entity) || !isdefined(entity.flameTrigger))
	{
		return;
	}
	// Stock mechzDelayFlame can start the burn without start_ft. Mirror before
	// applying damage; the per-actor watcher handles every stock stop path.
	acc_ft_visual_state(entity, IS_TRUE(entity.isShootingFlame));
	players = GetPlayers();
	foreach(player in players)
	{
		if(!(isdefined(player.acc_mechz_burn_until) && GetTime() < player.acc_mechz_burn_until))
		{
			if(player istouching(entity.flameTrigger))
			{
				player thread acc_player_flame_damage(entity);
			}
		}
	}
}

// [tod 2026-09-08] ONE writer for the flame-cone clientfields, so every stop path - the
// stop_ft notetrack, the behavior-tree stop the notetrack never told us about, and death -
// puts the visible cone out the same way. "mechz_ft" is the DLC1 field (version-gated dead
// on a usermap); "acc_panzer_ft" is our SHIP twin that actually renders (see __init__).
function acc_ft_fx_off(entity)
{
	if(!isdefined(entity))
	{
		return;
	}
	entity clientfield::set("mechz_ft", 0);
	acc_ft_visual_state(entity, false);
}

// One change-gated owner for the SHIP visual field. Stock owns mechz_ft and
// isShootingFlame; animation notetracks are not the only writers of that state.
function acc_ft_visual_state(entity, on)
{
	if(isdefined(entity.tod_ft_visual_on) && entity.tod_ft_visual_on == on)
		return;
	entity.tod_ft_visual_on = on;
	entity clientfield::set("acc_panzer_ft", int(on));
	if(IS_TRUE(level.tod_dev))
	{
		line = "[TOD_PANZER_FX] ms=" + GetTime() + " ent=" + entity GetEntityNumber() + " on=" + on;
		/#
		PrintLn(line);
		#/
	}
}

function acc_ft_visual_watch()
{
	// No death endon: explicitly turn off the field on the corpse, too.
	while(isdefined(self) && isalive(self))
	{
		acc_ft_visual_state(self, IS_TRUE(self.isShootingFlame));
		wait 0.05;
	}
	if(isdefined(self))
		acc_ft_visual_state(self, false);
}

// [tod 2026-09-08] endon() is not cleanup: the damage loop's endon("death") drops it
// mid-flame with the cone still lit, leaving a corpse holding a lit flamethrower. Own the
// teardown. Killed by the same notify every other stop path raises, so there is only ever
// one of these per flame.
function private acc_ft_fx_off_on_death()
{
	self endon("hash_8225d137");
	self waittill("death");
	acc_ft_fx_off(self);
}

function private stop_ft(entity)
{
	entity notify("hash_8225d137");
	acc_ft_fx_off(entity);                         // [acc] stop our flame-fx twin
	entity.isShootingFlame = 0;
	entity.nextFlameTime = GetTime() + 7500;
	entity.stopShootingFlameTime = undefined;
}

/*
	Name: function_1aacf7d4
	Namespace: namespace_19d9d56d
	Checksum: 0xD1A9ED74
	Offset: 0x12D0
	Size: 0x2EB
	Parameters: 0
	Flags: Private
*/
function private tomb_spawn_function()
{
wait 0.2;

if(self.targetname != "mechz_tomb")
	return;

	if(isdefined(self.m_claw))
	{
		self.m_claw delete();
		self.m_claw = undefined;
	}
	self.fx_field = 0;
	org = self GetTagOrigin("tag_claw");
	ang = self GetTagAngles("tag_claw");
	self.m_claw = spawn("script_model", org);
	self.m_claw SetModel("c_t7_zm_dlchd_origins_mech_claw_lod0");
	self.m_claw.angles = ang;
	self.m_claw LinkTo(self, "tag_claw");
	self.m_claw useanimtree(-1);
	if(isdefined(self.m_claw_damage_trigger))
	{
		self.m_claw_damage_trigger Unlink();
		self.m_claw_damage_trigger delete();
		self.m_claw_damage_trigger = undefined;
	}
	trigger_spawnflags = 0;
	trigger_radius = 3;
	trigger_height = 15;
	self.m_claw_damage_trigger = spawn("script_model", org);
	self.m_claw_damage_trigger SetModel("p7_chemistry_kit_large_bottle");
	ang = combineangles(VectorScale((-1, 0, 0), 90), ang);
	self.m_claw_damage_trigger.angles = ang;
	self.m_claw_damage_trigger Hide();
	self.m_claw_damage_trigger SetCanDamage(1);
	self.m_claw_damage_trigger.health = 10000;
	self.m_claw_damage_trigger EnableLinkTo();
	self.m_claw_damage_trigger LinkTo(self, "tag_claw");
	self thread function_5dfc412a();
	self HidePart("tag_claw");
}

/*
	Name: function_5dfc412a
	Namespace: namespace_19d9d56d
	Checksum: 0x34E549BA
	Offset: 0x15C8
	Size: 0x165
	Parameters: 0
	Flags: Private
*/
function private function_5dfc412a()
{
	self endon("death");
	self.m_claw_damage_trigger endon("death");
	while(1)
	{
		self.m_claw_damage_trigger waittill("damage", amount, inflictor, direction, point, type, tagName, modelName, partName, weaponName, iDFlags);
		self.m_claw_damage_trigger.health = 10000;
		if(self.m_claw islinkedto(self))
		{
			continue;
		}
		if(zm_utility::is_player_valid(inflictor))
		{
			self DoDamage(1, inflictor.origin, inflictor, inflictor, "left_hand", type);
			self.m_claw SetCanDamage(0);
			self notify("claw_damaged");
		}
	}
}

/*
	Name: function_31c4b972
	Namespace: namespace_19d9d56d
	Checksum: 0x4AB73000
	Offset: 0x1738
	Size: 0x4B
	Parameters: 0
	Flags: Private
*/
function private function_31c4b972()
{
	self endon("claw_complete");
	self util::waittill_either("death", "kill_claw");
	self function_90832db7();
}

/*
	Name: function_90832db7
	Namespace: namespace_19d9d56d
	Checksum: 0x3488FB5D
	Offset: 0x1790
	Size: 0x3C3
	Parameters: 0
	Flags: Private
*/
function private function_90832db7()
{
		self.fx_field = self.fx_field & 256;
	self.fx_field = self.fx_field & 64;
	//self clientfield::set("mechz_fx", self.fx_field);
	self function_9bfd96c8();
	if(isdefined(self.m_claw))
	{
		self.m_claw ClearAnim(%root, 0.2);
		if(isdefined(self.m_claw.fx_ent))
		{
			self.m_claw.fx_ent delete();
			self.m_claw.fx_ent = undefined;
		}
		if(!(isdefined(self.has_powercap) && self.has_powercap))
		{
			self function_4208b4ec();
			level flag::clear("mechz_launching_claw");
		}
		else if(!self.m_claw islinkedto(self))
		{
			v_claw_origin = self GetTagOrigin("tag_claw");
			v_claw_angles = self GetTagAngles("tag_claw");
			n_dist = Distance(self.m_claw.origin, v_claw_origin);
			n_time = n_dist / 1000;
			self.m_claw moveto(v_claw_origin, max(0.05, n_time));
			self.m_claw PlayLoopSound("zmb_ai_mechz_claw_loop_in", 0.1);
			self.m_claw waittill("movedone");
			v_claw_origin = self GetTagOrigin("tag_claw");
			v_claw_angles = self GetTagAngles("tag_claw");
			self.m_claw playsound("zmb_ai_mechz_claw_back");
			self.m_claw StopLoopSound(1);
			self.m_claw.origin = v_claw_origin;
			self.m_claw.angles = v_claw_angles;
			self.m_claw ClearAnim(%root, 0.2);
			self.m_claw LinkTo(self, "tag_claw", (0, 0, 0));
		}
		self.m_claw SetAnim(%ai_zombie_mech_grapple_arm_closed_idle, 1, 0.2, 1);
	}
	self notify("claw_complete");
	self.var_7bee990f = 0;
}

/*
	Name: function_4208b4ec
	Namespace: namespace_19d9d56d
	Checksum: 0xC95B0CC8
	Offset: 0x1B60
	Size: 0x135
	Parameters: 0
	Flags: Private
*/
function private function_4208b4ec()
{
	if(isdefined(self.m_claw))
	{
		self.m_claw SetAnim(%ai_zombie_mech_grapple_arm_open_idle, 1, 0.2, 1);
		if(isdefined(self.m_claw.fx_ent))
		{
			self.m_claw.fx_ent delete();
		}
		self.m_claw Unlink();
		self.m_claw PhysicsLaunch(self.m_claw.origin, (0, 0, -1));
		self.m_claw thread function_36db86b();
		self.m_claw = undefined;
	}
	if(isdefined(self.m_claw_damage_trigger))
	{
		self.m_claw_damage_trigger Unlink();
		self.m_claw_damage_trigger delete();
		self.m_claw_damage_trigger = undefined;
	}
}

/*
	Name: function_36db86b
	Namespace: namespace_19d9d56d
	Checksum: 0x170A4A0C
	Offset: 0x1CA0
	Size: 0x1B
	Parameters: 0
	Flags: Private
*/
function private function_36db86b()
{
	wait(30);
	self delete();
}

/*
	Name: function_9bfd96c8
	Namespace: namespace_19d9d56d
	Checksum: 0x3726CB94
	Offset: 0x1CC8
	Size: 0x1DB
	Parameters: 1
	Flags: Private
*/
function private function_9bfd96c8(bopenclaw)
{
	self.explosive_dmg_taken_on_grab_start = undefined;
	if(isdefined(self.e_grabbed))
	{
		if(isPlayer(self.e_grabbed))
		{
			self.e_grabbed clientfield::set_to_player("mechz_grab", 0);
			self.e_grabbed AllowCrouch(1);
			self.e_grabbed AllowProne(1);
		}
		if(!isdefined(self.e_grabbed._fall_down_anchor))
		{
			trace_start = self.e_grabbed.origin + VectorScale((0, 0, 1), 70);
			trace_end = self.e_grabbed.origin + VectorScale((0, 0, -1), 500);
			drop_trace = playerphysicstrace(trace_start, trace_end) + VectorScale((0, 0, 1), 24);
			self.e_grabbed Unlink();
			self.e_grabbed SetOrigin(drop_trace);
		}
		self.e_grabbed = undefined;
		if(isdefined(bopenclaw) && bopenclaw)
		{
			self.m_claw SetAnim(%ai_zombie_mech_grapple_arm_open_idle, 1, 0.2, 1);
		}
	}
}

/*
	Name: function_7c33f4fb
	Namespace: namespace_19d9d56d
	Checksum: 0x821DF5F5
	Offset: 0x1EB0
	Size: 0x2B
	Parameters: 0
	Flags: Private
*/
function private function_7c33f4fb()
{
	if(!isdefined(self.explosive_dmg_taken))
	{
		self.explosive_dmg_taken = 0;
	}
	self.explosive_dmg_taken_on_grab_start = self.explosive_dmg_taken;
}

/*
	Name: function_d6f31ed2
	Namespace: namespace_19d9d56d
	Checksum: 0x941D14BB
	Offset: 0x1EE8
	Size: 0x3B
	Parameters: 0
	Flags: Private
*/
function private function_d6f31ed2()
{
	self MechzServerUtils::hide_part("tag_claw");
	// [acc] m_claw only exists when the actor targetname is "mechz_tomb" (tomb_spawn_function
	// gate) - ours is "acc_panzer" (claw feature OFF), so the unguarded Hide() would throw the
	// first time a powercap is destroyed.
	if(isdefined(self.m_claw))
	{
		self.m_claw Hide();
	}
}

/*
	Name: function_5f5eaf3a
	Namespace: namespace_19d9d56d
	Checksum: 0xA7799255
	Offset: 0x1F30
	Size: 0xAB
	Parameters: 1
	Flags: Private
*/
function private function_5f5eaf3a(ai_mechz)
{
	self endon("disconnect");
	self zm_audio::create_and_play_dialog("general", "mech_grab");
	while(isdefined(self) && (isdefined(self.isSpeaking) && self.isSpeaking))
	{
		wait(0.1);
	}
	wait(1);
	if(isalive(ai_mechz) && isdefined(ai_mechz.e_grabbed))
	{
		ai_mechz thread play_shoot_arm_hint_vo();
	}
}

/*
	Name: play_shoot_arm_hint_vo
	Namespace: namespace_19d9d56d
	Checksum: 0xBA759057
	Offset: 0x1FE8
	Size: 0x187
	Parameters: 0
	Flags: Private
*/
function private play_shoot_arm_hint_vo()
{
	self endon("death");
	while(1)
	{
		if(!isdefined(self.e_grabbed))
		{
			return;
		}
		a_players = GetPlayers();
		foreach(player in a_players)
		{
			if(player == self.e_grabbed)
			{
				continue;
			}
			if(DistanceSquared(self.origin, player.origin) < 1000000)
			{
				if(player util::is_player_looking_at(self.origin + VectorScale((0, 0, 1), 60), 0.75))
				{
					if(!(isdefined(player.dontspeak) && player.dontspeak))
					{
						player zm_audio::create_and_play_dialog("general", "shoot_mech_arm");
						return;
					}
				}
			}
		}
		wait(0.1);
	}
}

/*
	Name: function_671deda5
	Namespace: namespace_19d9d56d
	Checksum: 0x75701F2F
	Offset: 0x2178
	Size: 0x2B
	Parameters: 0
	Flags: Private
*/
function private function_671deda5()
{
	if(isdefined(self.e_grabbed))
	{
		self thread function_9bfd96c8(1);
	}
}

/*
	Name: function_6028875a
	Namespace: namespace_19d9d56d
	Checksum: 0x34B66BA7
	Offset: 0x21B0
	Size: 0x5B
	Parameters: 0
	Flags: Private
*/
function private function_6028875a()
{
	if(isdefined(self.explosive_dmg_taken_on_grab_start))
	{
		// [acc] mechz_explosive_dmg_to_cancel_claw was DLC-map init (set nowhere in the pack or
		// stock mechz.gsc) - guard the compare or any explosive hit during a grab throws.
		if(!isdefined(self.mechz_explosive_dmg_to_cancel_claw))
		{
			self.mechz_explosive_dmg_to_cancel_claw = 500;
		}
		if(isdefined(self.e_grabbed) && self.explosive_dmg_taken - self.explosive_dmg_taken_on_grab_start > self.mechz_explosive_dmg_to_cancel_claw)
		{
			self.show_pain_from_explosive_dmg = 1;
			self thread function_9bfd96c8();
		}
	}
}

/*
	Name: function_8b0a73b5
	Namespace: namespace_19d9d56d
	Checksum: 0x169F6E1E
	Offset: 0x2218
	Size: 0x93
	Parameters: 1
	Flags: Private
*/
function private function_8b0a73b5(mechz)
{
	self endon("death");
	self endon("disconnect");
	mechz endon("death");
	mechz endon("claw_complete");
	mechz endon("kill_claw");
	while(1)
	{
		if(isdefined(self) && self laststand::player_is_in_laststand())
		{
			mechz thread function_9bfd96c8();
			return;
		}
		wait(0.05);
	}
}

/*
	Name: function_bed84b4
	Namespace: namespace_19d9d56d
	Checksum: 0xE32C1EFF
	Offset: 0x22B8
	Size: 0x91
	Parameters: 1
	Flags: Private
*/
function private function_bed84b4(mechz)
{
	self endon("death");
	self endon("disconnect");
	mechz endon("death");
	mechz endon("claw_complete");
	mechz endon("kill_claw");
	while(1)
	{
		self waittill("hash_10c37787");
		if(isdefined(self) && self.bgb === "zm_bgb_anywhere_but_here")
		{
			mechz thread function_9bfd96c8();
			return;
		}
	}
}

/*
	Name: function_38d105a4
	Namespace: namespace_19d9d56d
	Checksum: 0xF69E84FF
	Offset: 0x2358
	Size: 0x79
	Parameters: 1
	Flags: Private
*/
function private function_38d105a4(mechz)
{
	self endon("death");
	self endon("disconnect");
	mechz endon("death");
	mechz endon("claw_complete");
	mechz endon("kill_claw");
	while(1)
	{
		self waittill("hash_e2be4752");
		mechz thread function_9bfd96c8();
		return;
	}
}

/*
	Name: function_672f9804
	Namespace: namespace_19d9d56d
	Checksum: 0xF302A04C
	Offset: 0x23E0
	Size: 0xE4B
	Parameters: 0
	Flags: Private
*/
function private function_672f9804()
{
	self endon("death");
	self endon("kill_claw");
	if(!isdefined(self.favoriteenemy))
	{
		return;
	}
	v_claw_origin = self GetTagOrigin("tag_claw");
	v_claw_angles = VectorToAngles(self.origin - self.favoriteenemy.origin);
	self.fx_field = self.fx_field | 256;
	//self clientfield::set("mechz_fx", self.fx_field);
	self.m_claw SetAnim(%ai_zombie_mech_grapple_arm_open_idle, 1, 0, 1);
	self.m_claw Unlink();
	self.m_claw.fx_ent = spawn("script_model", self.m_claw GetTagOrigin("tag_claw"));
	self.m_claw.fx_ent.angles = self.m_claw GetTagAngles("tag_claw");
	self.m_claw.fx_ent SetModel("tag_origin");
	self.m_claw.fx_ent LinkTo(self.m_claw, "tag_claw");
	self.m_claw.fx_ent clientfield::set("mechz_claw", 1);
	self clientfield::set("mechz_wpn_source", 1);
	v_enemy_origin = self.favoriteenemy.origin + VectorScale((0, 0, 1), 36);
	n_dist = Distance(v_claw_origin, v_enemy_origin);
	n_time = n_dist / 1200;
	self playsound("zmb_ai_mechz_claw_fire");
	self.m_claw moveto(v_enemy_origin, n_time);
	self.m_claw thread function_2998f2a1();
	self.m_claw PlayLoopSound("zmb_ai_mechz_claw_loop_out", 0.1);
	self.e_grabbed = undefined;
	do
	{
		a_players = GetPlayers();
		foreach(player in a_players)
		{
			if(!zm_utility::is_player_valid(player, 1, 1) || !player player_can_be_grabbed())
			{
				continue;
			}
			n_dist_sq = DistanceSquared(player.origin + VectorScale((0, 0, 1), 36), self.m_claw.origin);
			if(n_dist_sq < 2304)
			{
				clip_mask = 1 | 8;
				var_7d76644b = self.origin + VectorScale((0, 0, 1), 65);
				trace = PhysicsTrace(var_7d76644b, player.origin + VectorScale((0, 0, 1), 30), (-15, -15, -20), (15, 15, 40), self, clip_mask);
				b_cansee = trace["fraction"] == 1 || (isdefined(trace["entity"]) && trace["entity"] == player);
				if(!b_cansee)
				{
					continue;
				}
				if(isdefined(player.hasRiotShield) && player.hasRiotShield && (isdefined(player.hasRiotShieldEquipped) && player.hasRiotShieldEquipped))
				{
					shield_dmg = level.zombie_vars["riotshield_hit_points"];
					player riotshield::player_damage_shield(shield_dmg - 1, 1);
					wait(1);
					player riotshield::player_damage_shield(1, 1);
				}
				else
				{
					self.e_grabbed = player;
					self.e_grabbed clientfield::set_to_player("mechz_grab", 1);
					self.e_grabbed PlayerLinkToDelta(self.m_claw, "tag_attach_player");
					self.e_grabbed SetPlayerAngles(VectorToAngles(self.origin - self.e_grabbed.origin));
					self.e_grabbed playsound("zmb_ai_mechz_claw_grab");
					self.e_grabbed SetStance("stand");
					self.e_grabbed AllowCrouch(0);
					self.e_grabbed AllowProne(0);
					self.e_grabbed thread function_5f5eaf3a(self);
					self.e_grabbed thread function_bed84b4(self);
					self.e_grabbed thread function_38d105a4(self);
					if(!level flag::get("mechz_claw_move_complete"))
					{
						self.m_claw moveto(self.m_claw.origin, 0.05);
					}
				}
				break;
			}
		}
		wait(0.05);
	}
	while(!level flag::get("mechz_claw_move_complete") && (!isdefined(self.e_grabbed)));

	if(!isdefined(self.e_grabbed))
	{
		a_ai_zombies = zombie_utility::get_round_enemy_array();
		foreach(ai_zombie in a_ai_zombies)
		{
			if(!isalive(ai_zombie) || (isdefined(ai_zombie.is_giant_robot) && ai_zombie.is_giant_robot) || (isdefined(ai_zombie.is_mechz) && ai_zombie.is_mechz))
			{
				continue;
			}
			n_dist_sq = DistanceSquared(ai_zombie.origin + VectorScale((0, 0, 1), 36), self.m_claw.origin);
			if(n_dist_sq < 2304)
			{
				self.e_grabbed = ai_zombie;
				self.e_grabbed LinkTo(self.m_claw, "tag_attach_player", (0, 0, 0));
				self.e_grabbed.mechz_grabbed_by = self;
				break;
			}
		}
	}
	self.m_claw ClearAnim(%root, 0.2);
	self.m_claw SetAnim(%ai_zombie_mech_grapple_arm_closed_idle, 1, 0.2, 1);
	wait(0.5);
	if(isdefined(self.e_grabbed))
	{
		n_time = n_dist / 200;
	}
	else
	{
		n_time = n_dist / 1000;
	}
	self function_7c33f4fb();
	v_claw_origin = self GetTagOrigin("tag_claw");
	v_claw_angles = self GetTagAngles("tag_claw");
	self.m_claw moveto(v_claw_origin, max(0.05, n_time));
	self.m_claw PlayLoopSound("zmb_ai_mechz_claw_loop_in", 0.1);
	self.m_claw waittill("movedone");
	v_claw_origin = self GetTagOrigin("tag_claw");
	v_claw_angles = self GetTagAngles("tag_claw");
	self.m_claw playsound("zmb_ai_mechz_claw_back");
	self.m_claw StopLoopSound(1);
	if(zm_audio::sndIsNetworkSafe())
	{
		self playsound("zmb_ai_mechz_vox_angry");
	}
	self.m_claw.origin = v_claw_origin;
	self.m_claw.angles = v_claw_angles;
	self.m_claw ClearAnim(%root, 0.2);
	self.m_claw LinkTo(self, "tag_claw", (0, 0, 0));
	self.m_claw SetAnim(%ai_zombie_mech_grapple_arm_closed_idle, 1, 0.2, 1);
	self.m_claw.fx_ent delete();
	self.m_claw.fx_ent = undefined;
	self.fx_field = self.fx_field & 256;
	//self clientfield::set("mechz_fx", self.fx_field);
	self clientfield::set("mechz_wpn_source", 0);
	level flag::clear("mechz_launching_claw");

	if(isdefined(self.e_grabbed))
	{
		if(isPlayer(self.e_grabbed) && zm_utility::is_player_valid(self.e_grabbed))
		{
			self.e_grabbed thread function_8b0a73b5(self);
		}
		else if(isai(self.e_grabbed))
		{
			self.e_grabbed thread function_860f0461(self);
		}
		self thread function_eb9df173(self.e_grabbed);
		self AnimScripted("flamethrower_anim", self.origin, self.angles, "ai_zombie_mech_ft_burn_player", "normal", "ai_zombie_mech_ft_burn_player", 1,0.1);
		self zombie_shared::DoNoteTracks("flamethrower_anim");
	}
	level flag::clear("mechz_claw_move_complete");
}
/*
	Name: function_eb9df173
	Namespace: namespace_19d9d56d
	Checksum: 0x96078390
	Offset: 0x3238
	Size: 0x1A9
	Parameters: 1
	Flags: Private
*/
function private function_eb9df173(player)
{
	player endon("death");
	player endon("disconnect");
	self endon("death");
	self endon("claw_complete");
	self endon("kill_claw");
	self thread function_7792d05e(player);
	player thread function_d0e280a0(self);
	self.m_claw SetCanDamage(1);
	while(isdefined(self.e_grabbed))
	{
		self.m_claw waittill("damage", amount, inflictor, direction, point, type, tagName, modelName, partName, weaponName, iDFlags);
		if(zm_utility::is_player_valid(inflictor))
		{
			self DoDamage(1, inflictor.origin, inflictor, inflictor, "left_hand", type);
			self.m_claw SetCanDamage(0);
			self notify("claw_damaged");
			break;
		}
	}
}

/*
	Name: function_7792d05e
	Namespace: namespace_19d9d56d
	Checksum: 0xD27C5750
	Offset: 0x33F0
	Size: 0x8B
	Parameters: 1
	Flags: Private
*/
function private function_7792d05e(player)
{
	self endon("claw_damaged");
	player endon("death");
	player endon("disconnect");
	self util::waittill_any("death", "claw_complete", "kill_claw");
	if(isdefined(self) && isdefined(self.m_claw))
	{
		self.m_claw SetCanDamage(0);
	}
}

/*
	Name: function_d0e280a0
	Namespace: namespace_19d9d56d
	Checksum: 0xBB4AC903
	Offset: 0x3488
	Size: 0xA3
	Parameters: 1
	Flags: Private
*/
function private function_d0e280a0(mechz)
{
	mechz endon("claw_damaged");
	mechz endon("death");
	mechz endon("claw_complete");
	mechz endon("kill_claw");
	self util::waittill_any("death", "disconnect");
	if(isdefined(mechz) && isdefined(mechz.m_claw))
	{
		mechz.m_claw SetCanDamage(0);
	}
}

/*
	Name: function_2998f2a1
	Namespace: namespace_19d9d56d
	Checksum: 0x7FDF7C4B
	Offset: 0x3538
	Size: 0x33
	Parameters: 0
	Flags: Private
*/
function private function_2998f2a1()
{
	self waittill("movedone");
	wait(0.05);
	level flag::set("mechz_claw_move_complete");
}

/*
	Name: function_860f0461
	Namespace: namespace_19d9d56d
	Checksum: 0xB7441423
	Offset: 0x3578
	Size: 0x93
	Parameters: 1
	Flags: Private
*/
function private function_860f0461(mechz)
{
	mechz waittillmatch("flamethrower_anim");
	if(isalive(self))
	{
		self DoDamage(self.health, self.origin, self);
		self zombie_utility::gib_random_parts();
		GibServerUtils::Annihilate(self);
	}
}






function private function_76e7495b()
{
	wait(0.5);
	var_85129cef = getentarray("zombie_trap", "targetname");
	foreach(e_trap in var_85129cef)
	{
		if(e_trap.script_noteworthy == "electric")
		{
			level.electric_trap = e_trap;
		}
	}
}




/*
	Name: function_604404
	Namespace: namespace_8f77dbcb
	Checksum: 0x72B858C2
	Offset: 0xC88
	Size: 0x9D
	Parameters: 1
	Flags: Private
*/
function private function_604404(entity)
{
	if(isdefined(self.react))
	{
		foreach(react in self.react)
		{
			if(react == entity)
			{
				return 1;
			}
		}
	}
	return 0;
}

/*
	Name: function_e92d3bb1
	Namespace: namespace_8f77dbcb
	Checksum: 0x200C993B
	Offset: 0xD30
	Size: 0x39
	Parameters: 1
	Flags: Private
*/
function private function_e92d3bb1(entity)
{
	if(!isdefined(self.react))
	{
		self.react = [];
	}
	self.react[self.react.size] = entity;
}

/*
	Name: function_8746ceea
	Namespace: namespace_8f77dbcb
	Checksum: 0x6C7E79B4
	Offset: 0xD78
	Size: 0x1C1
	Parameters: 1
	Flags: Private
*/
function private genesisVortexService(entity)
{
	if(!entity function_58655f2a())
	{
		return 0;
	}
	if(isdefined(level.vortex_manager) && isdefined(level.vortex_manager.a_active_vorticies))
	{
		foreach(vortex in level.vortex_manager.a_active_vorticies)
		{
			if(!vortex function_604404(entity))
			{
				dist_sq = distancesquared(vortex.origin, self.origin);
				if(dist_sq < 9216)
				{
					entity.stun = 1;
					entity.vortex = vortex;
					//if(isdefined(vortex.weapon) && idgun::function_9b7ac6a9(vortex.weapon))
					//{
					//	blackboard::SetBlackBoardAttribute(entity, "_zombie_damageweapon_type", "packed");
					//}
					vortex function_e92d3bb1(entity);
					return 1;
				}
			}
		}
	}
	return 0;
}

/*
	Name: function_2ffb7337
	Namespace: namespace_8f77dbcb
	Checksum: 0xCF00231A
	Offset: 0xF48
	Size: 0x159
	Parameters: 1
	Flags: Private
*/
function private genesisMechzOctobombService(entity)
{
	if(isdefined(entity.destroy_octobomb))
	{
		entity SetGoal(entity.destroy_octobomb.origin);
		return 1;
	}
	if(isdefined(level.octobombs))
	{
		foreach(octobomb in level.octobombs)
		{
			if(isdefined(octobomb))
			{
				dist_sq = distancesquared(octobomb.origin, self.origin);
				if(dist_sq < 360000)
				{
					entity.destroy_octobomb = octobomb;
					entity SetGoal(octobomb.origin);
					return 1;
				}
			}
		}
	}
	return 0;
}




function private castleMechzTrapService(entity)
{
	if(isdefined(entity.var_d77404f7) && entity.var_d77404f7 || (isdefined(entity.var_72308ff2) && entity.var_72308ff2))
	{
		return 1;
	}

	traps_are_gay = GetEntArray("zombie_trap", "targetname");
	if(traps_are_gay.size < 1)
		return 0;

	traps = ArraySortClosest(traps_are_gay, entity.origin);

	foreach(trap in traps)
		if(isdefined(trap._trap_in_use) && trap._trap_in_use && !(isdefined(trap._trap_cooling_down) && trap._trap_cooling_down))
			if(entity function_d8f5da34("elec_trap_switch", trap))
				return 1;

	return 0;
}



function private function_d8f5da34(var_2dba2212, trig)
{
box = ArrayGetClosest(self.origin, trig._trap_use_trigs);

spot = GetClosestPointOnNavMesh(box.origin);




if(self CanPath(self.origin, spot))
	{
	self.trap_to_kill = trig;
	self.var_d77404f7 = 1;
	self.ignoreall = 1;
	self SetGoal(spot);
	self thread function_957c9419();
	return 1;
	}


return 0;

	traps = struct::get_array(var_2dba2212, "script_noteworthy");
	self.var_fdce40e2 = undefined;
	n_closest_dist_sq = 57600;
	foreach(var_fdce40e2 in traps)
	{
		n_dist_sq = distancesquared(var_fdce40e2.origin, self.origin);
		if(n_dist_sq < n_closest_dist_sq)
		{
			n_closest_dist_sq = n_dist_sq;
			self.var_fdce40e2 = var_fdce40e2;
		}
	}
	if(isdefined(self.var_fdce40e2))
	{
		self.var_d77404f7 = 1;
		self.ignoreall = 1;
		self SetGoal(self.var_fdce40e2.origin);
		self thread function_957c9419();
		return 1;
	}
	return 0;
}

/*
	Name: function_957c9419
	Namespace: namespace_8f77dbcb
	Checksum: 0x56378946
	Offset: 0x1240
	Size: 0x93
	Parameters: 0
	Flags: None
*/
function function_957c9419()
{
	self endon("death");
	wait(60);
	if(isdefined(self.var_d77404f7) && self.var_d77404f7 || (isdefined(self.var_72308ff2) && self.var_72308ff2) || (isdefined(self.ignoreall) && self.ignoreall))
	{
		self.var_d77404f7 = 0;
		self.var_72308ff2 = 0;
		self.ignoreall = 0;
		self.trap_to_kill = undefined;
		MechzBehavior::mechzTargetService(self);
	}
}

/*
	Name: function_beb13c4b
	Namespace: namespace_8f77dbcb
	Checksum: 0x62EB8DCB
	Offset: 0x12E0
	Size: 0x39
	Parameters: 1
	Flags: None
*/
function castleMechzShouldMoveToTrap(entity)
{
	if(isdefined(entity.var_d77404f7) && entity.var_d77404f7)
	{
		return 1;
	}
	return 0;
}

/*
	Name: function_fc277828
	Namespace: namespace_8f77dbcb
	Checksum: 0x4CF7A31
	Offset: 0x1328
	Size: 0x2D
	Parameters: 1
	Flags: None
*/
function castleMechzIsAtTrap(entity)
{
	if(entity IsAtGoal())
	{
		return 1;
	}
	return 0;
}

/*
	Name: function_d1cb5cbc
	Namespace: namespace_8f77dbcb
	Checksum: 0xF00A1DB5
	Offset: 0x1360
	Size: 0x39
	Parameters: 1
	Flags: None
*/
function castleMechzShouldAttackTrap(entity)
{
	if(isdefined(entity.var_72308ff2) && entity.var_72308ff2)
	{
		return 1;
	}
	return 0;
}

/*
	Name: function_4e06a982
	Namespace: namespace_8f77dbcb
	Checksum: 0x8D6FDF20
	Offset: 0x13A8
	Size: 0xBD
	Parameters: 1
	Flags: Private
*/
function private genesisMechzShouldOctobombAttack(entity)
{
	if(!isdefined(entity.destroy_octobomb))
	{
		return 0;
	}
	if(distancesquared(entity.origin, entity.destroy_octobomb.origin) > 16384)
	{
		return 0;
	}
	yaw = Abs(zombie_utility::GetYawToSpot(entity.destroy_octobomb.origin));
	if(yaw > 45)
	{
		return 0;
	}
	return 1;
}

/*
	Name: function_4210ca29
	Namespace: namespace_8f77dbcb
	Checksum: 0x2FDF1357
	Offset: 0x1470
	Size: 0x2F
	Parameters: 1
	Flags: None
*/
function casteMechzTrapMoveTerminate(entity)
{
	entity.var_d77404f7 = 0;
	entity.var_72308ff2 = 1;
}

/*
	Name: function_910e57ee
	Namespace: namespace_8f77dbcb
	Checksum: 0xB370CE16
	Offset: 0x14A8
	Size: 0xB3
	Parameters: 1
	Flags: None
*/
function casteMechzTrapAttackTerminate(entity)
{
	entity.var_72308ff2 = 0;
	entity.ignoreall = 0;
	entity.trap_to_kill notify("trap_deactivate");
	entity.trap_to_kill = undefined;
	MechzBehavior::mechzTargetService(entity);
}

/*
	Name: function_78198ba2
	Namespace: namespace_8f77dbcb
	Checksum: 0x17184BF0
	Offset: 0x1568
	Size: 0x63
	Parameters: 1
	Flags: None
*/
function genesisMechzDestoryOctobomb(entity)
{
	if(isdefined(entity.destroy_octobomb))
	{
		entity.destroy_octobomb detonate();
		entity.destroy_octobomb = undefined;
	}
	MechzBehavior::mechzStopFlame(entity);
}

/*
	Name: function_45f397ee
	Namespace: namespace_8f77dbcb
	Checksum: 0x8AF26E9A
	Offset: 0x15D8
	Size: 0x83
	Parameters: 5
	Flags: None
*/
function mechz_attack_trap_start(entity, mocompanim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration)
{
	entity OrientMode("face angle", entity.var_fdce40e2.angles[1]);
	entity animMode("normal");
}

/*
	Name: function_9da58a6f
	Namespace: namespace_8f77dbcb
	Checksum: 0xC8867E8E
	Offset: 0x1668
	Size: 0x4B
	Parameters: 5
	Flags: None
*/
function mechz_attack_trap_end(entity, mocompanim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration)
{
	entity OrientMode("face default");
}

/*
	Name: mechz_health_increases
	Namespace: namespace_8f77dbcb
	Checksum: 0x6D4ACC3F
	Offset: 0x16C0
	Size: 0x2EB
	Parameters: 0
	Flags: None
*/
function mechz_health_increases()
{
	if(!isdefined(level.mechz_last_spawn_round) || level.round_number > level.mechz_last_spawn_round)
	{
		a_players = GetPlayers();
		n_player_modifier = 1;
		switch(a_players.size)
		{
			case 0:
			case 1:
			{
				n_player_modifier = 1;
				break;
			}
			case 2:
			{
				n_player_modifier = 1.33;
				break;
			}
			case 3:
			{
				n_player_modifier = 1.66;
				break;
			}
			case 4:
			{
				n_player_modifier = 2;
				break;
			}
		}
		var_485a2c2c = level.zombie_health / level.zombie_vars["zombie_health_start"];
		level.mechz_health = int(n_player_modifier * level.mechz_base_health + level.mechz_health_increase * var_485a2c2c);
		level.MECHZ_FACEPLATE_HEALTH = int(n_player_modifier * level.var_fa14536d + level.var_1a5bb9d8 * var_485a2c2c);
		level.MECHZ_POWERCAP_COVER_HEALTH = int(n_player_modifier * level.MECHZ_POWERCAP_COVER_HEALTH + level.var_a1943286 * var_485a2c2c);
		level.MECHZ_POWERCAP_HEALTH = int(n_player_modifier * level.MECHZ_POWERCAP_HEALTH + level.var_9684c99e * var_485a2c2c);
		level.var_2cbc5b59 = int(n_player_modifier * level.var_3f1bf221 + level.var_158234c * var_485a2c2c);
		level.mechz_health = function_26beb37e(level.mechz_health, 17500, n_player_modifier);
		level.MECHZ_FACEPLATE_HEALTH = function_26beb37e(level.MECHZ_FACEPLATE_HEALTH, 16000, n_player_modifier);
		level.MECHZ_POWERCAP_COVER_HEALTH = function_26beb37e(level.MECHZ_POWERCAP_COVER_HEALTH, 7500, n_player_modifier);
		level.MECHZ_POWERCAP_HEALTH = function_26beb37e(level.MECHZ_POWERCAP_HEALTH, 5000, n_player_modifier);
		level.var_2cbc5b59 = function_26beb37e(level.var_2cbc5b59, 3500, n_player_modifier);
		level.mechz_last_spawn_round = level.round_number;
	}
}

/*
	Name: function_26beb37e
	Namespace: namespace_8f77dbcb
	Checksum: 0xD8F5E84C
	Offset: 0x19B8
	Size: 0x53
	Parameters: 3
	Flags: None
*/
function function_26beb37e(n_value, var_9cc1b75, n_player_modifier)
{
	if(n_value >= var_9cc1b75 * n_player_modifier)
	{
		n_value = int(var_9cc1b75 * n_player_modifier);
	}
	return n_value;
}

/*
	Name: function_d8d01032
	Namespace: namespace_8f77dbcb
	Checksum: 0x3FA40FB3
	Offset: 0x1A18
	Size: 0xF9
	Parameters: 0
	Flags: None
*/
function function_d8d01032()
{
	self.idgun_damage_cb = &function_5f2149bb;
	self.var_c732138b = &function_1df1ec14;
	self.traversalSpeedBoost = &function_40ef38f8;
	self thread function_a2a11991();
	self thread function_b2a1b297();
	//self thread function_2a26e636();
	self thread zm::update_zone_name();
	self waittill("death");
	//self thread function_2a2bfc25();
	if(isdefined(self.var_9b31a70d) && self.var_9b31a70d)
	{
		level.var_638dde56--;
	}
	level notify("hash_8f65ad3d");
}

/*
	Name: function_3fdbda1e
	Namespace: namespace_8f77dbcb
	Checksum: 0x395BF9F3
	Offset: 0x1B20
	Size: 0x63
	Parameters: 0
	Flags: None
*/
function function_3fdbda1e()
{
	self function_1faf1646();
	util::wait_network_frame();
	self clientfield::increment("mechz_fx_spawn");
	wait(1);
	self function_ee090a93();
}

/*
	Name: function_b7e11612
	Namespace: namespace_8f77dbcb
	Checksum: 0x2363B45C
	Offset: 0x1B90
	Size: 0x2B
	Parameters: 0
	Flags: None
*/
function function_b7e11612()
{
	self waittill("death");
	//self namespace_c149ef1::function_f7879c72(self.attacker);
}

/*
	Name: function_b2a1b297
	Namespace: namespace_8f77dbcb
	Checksum: 0xF4DCA2D
	Offset: 0x1BC8
	Size: 0x43
	Parameters: 0
	Flags: None
*/
function function_b2a1b297()
{
	self waittill("actor_corpse", mechz);
	wait(60);
	if(isdefined(mechz))
	{
		mechz delete();
	}
}

/*
	Name: function_2a26e636
	Namespace: namespace_8f77dbcb
	Checksum: 0x89EA333C
	Offset: 0x1C18
	Size: 0x243
	Parameters: 0
	Flags: None
*/
function function_2a26e636()
{
	self endon("death");
	while(1)
	{
		if(!isdefined(self.zone_name))
		{
			wait(0.1);
			continue;
		}
		var_225b5e15 = 1;
		var_e01c8f74 = 1;
		players = GetPlayers();
		foreach(player in players)
		{
			if(isdefined(player.var_5aef0317) && player.var_5aef0317 || (isdefined(player.var_a393601c) && player.var_a393601c))
			{
				var_225b5e15 = 0;
				var_e01c8f74 = 0;
				break;
				continue;
			}
			if(isdefined(player.am_i_valid) && player.am_i_valid)
			{
				if(!isdefined(player.zone_name))
				{
					var_225b5e15 = 0;
					var_e01c8f74 = 0;
					break;
				}
				if(isdefined(player.zone_name))
				{
					if(player.zone_name == "apothicon_interior_zone")
					{
						var_e01c8f74 = 0;
						continue;
					}
					var_225b5e15 = 0;
				}
			}
		}
		var_9626d5b6 = 0;
		if(self.zone_name == "apothicon_interior_zone")
		{
			var_9626d5b6 = 1;
		}
		if(var_225b5e15 && !var_9626d5b6 || (var_e01c8f74 && var_9626d5b6))
		{
			break;
		}
		wait(0.5);
	}
	self thread function_17da3db2();
}

/*
	Name: function_17da3db2
	Namespace: namespace_8f77dbcb
	Checksum: 0x7B4EFA08
	Offset: 0x1E68
	Size: 0x53
	Parameters: 0
	Flags: None
*/
function function_17da3db2()
{
	wait(0.05);
	if(isdefined(self))
	{
		self delete();
	}
	wait(1.1);
	//level thread namespace_6929903c::spawn_boss("mechz");
}

/*
	Name: function_a2a11991
	Namespace: namespace_8f77dbcb
	Checksum: 0xDFD65FD3
	Offset: 0x1EC8
	Size: 0x3B
	Parameters: 0
	Flags: None
*/
function function_a2a11991()
{
	self endon("death");
	while(!isdefined(self.zombie_lift_override))
	{
		wait(0.05);
	}
	self.zombie_lift_override = &function_2d571578;
}

/*
	Name: function_2a2bfc25
	Namespace: namespace_8f77dbcb
	Checksum: 0x7668C947
	Offset: 0x1F10
	Size: 0xC3
	Parameters: 0
	Flags: None
*/
function function_2a2bfc25()
{
	self waittill("hash_46c1e51d");
	// [acc] artifact fix (2026-07-11, see function_58655f2a): the dropped parens made this drop check
	// UNSATISFIABLE (and a throw when no_powerups is undefined) - these specials never dropped their
	// powerup since integration. Restored `!IS_TRUE(self.no_powerups)`.
	if(level flag::get("zombie_drop_powerups") && !(isdefined(self.no_powerups) && self.no_powerups))
	{
		var_d54b1ec = array("double_points", "insta_kill", "full_ammo", "nuke");
		str_type = array::random(var_d54b1ec);
		// [acc] 2026-07-11: level thread, was a plain call on the mech. The eMoX delayed-drop
		// override makes specific_powerup_drop block ~1.6s; a mech-owned thread dying mid-delay
		// (corpse delete) would strand a model-less powerup. origin is captured at call time.
		level thread zm_powerups::specific_powerup_drop(str_type, self.origin);
	}
}

/*
	Name: function_f517cdd6
	Namespace: namespace_8f77dbcb
	Checksum: 0x127817F3
	Offset: 0x1FE0
	Size: 0x63
	Parameters: 12
	Flags: None
*/
function function_f517cdd6(inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitloc, offsetTime, boneIndex, modelIndex)
{
}

/*
	Name: function_5683b5d5
	Namespace: namespace_8f77dbcb
	Checksum: 0x55D305A2
	Offset: 0x2050
	Size: 0xDB
	Parameters: 5
	Flags: None
*/
function mechz_teleport_Start(entity, mocompanim, mocompAnimBlendOutTime, mocompAnimFlag, mocompDuration)
{
	entity.is_teleporting = 1;
	entity OrientMode("face angle", entity.angles[1]);
	entity animMode("normal");


	thread function_eb1242c8(entity);
}


function function_eb1242c8(entity)
{
	//IPrintLnBold("teleporting");
	entity endon("death");
	

	entity.teleportStart = entity.origin;
	entity.teleportPos = entity.traverseEndNode.origin;

	entity.b_teleporting = 1;
	entity PathMode("dont move");
	// [acc] portal_3p is defined nowhere (DLC fx, not shipped) - unguarded PlayFX throws if any
	// mechz traversal ever maps to the teleport mocomp.
	if(isdefined(level._effect["portal_3p"]))
	{
		PlayFX(level._effect["portal_3p"], entity.origin);
	}
	PlaySoundAtPosition("zmb_teleporter_teleport_out", entity.origin);
	entity NotSolid();
	entity Hide();
	util::wait_network_frame();
	/*image_room = struct::get("teleport_room_zombies", "targetname");
	if(IsActor(entity))
	{
		entity ForceTeleport(image_room.origin, image_room.angles);
	}
	else
	{
		entity.origin = image_room.origin;
		entity.angles = image_room.angles;
	}*/
	wait(5);



	entity ForceTeleport(entity.teleportPos, entity.angles);
	playsoundatposition("zmb_teleporter_teleport_in", entity.teleportPos);
	if(isdefined(level._effect["portal_3p"]))   // [acc] see guard above
	{
		PlayFX(level._effect["portal_3p"], entity.traverseEndNode.origin);
	}
	entity Solid();
	entity Show();
	wait(1);
	entity PathMode("move allowed");
	entity.b_teleporting = 0;
	entity.is_teleporting = 0;

}


/*
	Name: function_2d571578
	Namespace: namespace_8f77dbcb
	Checksum: 0xF5B7B7A4
	Offset: 0x2138
	Size: 0x2C7
	Parameters: 6
	Flags: None
*/
function function_2d571578(e_player, v_attack_source, n_push_away, n_lift_height, v_lift_offset, n_lift_speed)
{
	self endon("death");
	if(isdefined(self.in_gravity_trap) && self.in_gravity_trap && e_player.gravityspikes_state === 3)
	{
		if(isdefined(self.var_1f5fe943) && self.var_1f5fe943)
		{
			return;
		}
		self.var_bcecff1d = 1;
		self.var_1f5fe943 = 1;
		self DoDamage(10, self.origin);
		self.var_ab0efcf6 = self.origin;
		self thread scene::play("cin_zm_dlc1_mechz_dth_deathray_01", self);
		// [acc] "sparky_beam_fx" is registered NOWHERE (neither side) - setting it is an instant
		// script error. Gravity-spikes(DG-4)-only path, dormant on this map; disarmed anyway.
		// self clientfield::set("sparky_beam_fx", 1);
		self clientfield::set("death_ray_shock_fx", 1);
		self playsound("zmb_talon_electrocute");
		n_start_time = GetTime();
		for(n_total_time = 0; 10 > n_total_time && e_player.gravityspikes_state === 3;  n_total_time++)
		{
			util::wait_network_frame();
		}
		self scene::stop("cin_zm_dlc1_mechz_dth_deathray_01");
		self thread function_a0b6d6b9(self);
		// [acc] see above - "sparky_beam_fx" registered nowhere.
		// self clientfield::set("sparky_beam_fx", 0);
		self clientfield::set("death_ray_shock_fx", 0);
		self.var_bcecff1d = undefined;
		while(e_player.gravityspikes_state === 3)
		{
			util::wait_network_frame();
		}
		self.var_1f5fe943 = undefined;
		self.in_gravity_trap = undefined;
	}
	else
	{
		self DoDamage(10, self.origin);
		if(!(isdefined(self.stun) && self.stun))
		{
			self.stun = 1;
		}
	}
}

/*
	Name: function_a0b6d6b9
	Namespace: namespace_8f77dbcb
	Checksum: 0xCDD8F98B
	Offset: 0x2408
	Size: 0x1A3
	Parameters: 1
	Flags: None
*/
function function_a0b6d6b9(mechz)
{
	mechz endon("death");
	if(isdefined(mechz))
	{
		mechz scene::play("cin_zm_dlc1_mechz_dth_deathray_02", mechz);
	}
	if(isdefined(mechz) && isalive(mechz) && isdefined(mechz.var_ab0efcf6))
	{
		v_eye_pos = mechz gettagorigin("tag_eye");
		/#
			recordLine(mechz.origin, v_eye_pos, VectorScale((0, 1, 0), 255), "Dev Block strings are not supported", mechz);
		#/
		trace = bullettrace(v_eye_pos, mechz.origin, 0, mechz);
		if(trace["position"] !== mechz.origin)
		{
			point = GetClosestPointOnNavMesh(trace["position"], 64, 30);
			if(!isdefined(point))
			{
				point = mechz.var_ab0efcf6;
			}
			mechz ForceTeleport(point);
		}
	}
}

/*
	Name: function_5f2149bb
	Namespace: namespace_8f77dbcb
	Checksum: 0xBE06B1AA
	Offset: 0x25B8
	Size: 0xA3
	Parameters: 2
	Flags: None
*/
function function_5f2149bb(inflictor, attacker)
{
	var_3bb42832 = level.mechz_health;
	n_damage = var_3bb42832 * 0.25 / 0.2;
	self DoDamage(n_damage, self GetCentroid(), inflictor, attacker, undefined, "MOD_PROJECTILE_SPLASH", 0, GetWeapon("none"));
}

/*
	Name: function_1df1ec14
	Namespace: namespace_8f77dbcb
	Checksum: 0xF9FD1480
	Offset: 0x2668
	Size: 0x33
	Parameters: 0
	Flags: Private
*/
function private function_1df1ec14()
{
	if(self function_58655f2a())
	{
		self.stun = 1;
		return 1;
	}
	return 0;
}

/*
	Name: function_40ef38f8
	Namespace: namespace_8f77dbcb
	Checksum: 0x868B0E29
	Offset: 0x26A8
	Size: 0xAD
	Parameters: 0
	Flags: Private
*/
function private function_40ef38f8()
{
	traversal = self.traversal;
	speedBoost = 0;
	if(traversal.absLengthToEnd > 200)
	{
		speedBoost = 48;
	}
	else if(traversal.absLengthToEnd > 120)
	{
		speedBoost = 24;
	}
	else if(traversal.absLengthToEnd > 80 || traversal.absHeightToEnd > 80)
	{
		speedBoost = 12;
	}
	return speedBoost;
}

/*
	Name: mechz_damage_override
	Namespace: namespace_8f77dbcb
	Checksum: 0xDCC4E48E
	Offset: 0x2760
	Size: 0x45
	Parameters: 2
	Flags: None
*/
function mechz_damage_override(attacker, damage)
{
	if(isdefined(attacker.var_bbd3efb8))
	{
		damage = damage * attacker.var_bbd3efb8;
	}
	return damage;
}

/*
	Name: function_1faf1646
	Namespace: namespace_8f77dbcb
	Checksum: 0xEBF31B1C
	Offset: 0x27B0
	Size: 0x6B
	Parameters: 0
	Flags: Private
*/
function private function_1faf1646()
{
	self.canDamage = 0;
	self.isFrozen = 1;
	self ghost();
	self notsolid();
	self PathMode("dont move");
}

/*
	Name: function_ee090a93
	Namespace: namespace_8f77dbcb
	Checksum: 0x6950A9C0
	Offset: 0x2828
	Size: 0x6F
	Parameters: 0
	Flags: Private
*/
function private function_ee090a93()
{
	self.isFrozen = 0;
	self show();
	self solid();
	wait(0.5);
	self PathMode("move allowed");
	self.canDamage = 1;
}

/*
	Name: function_78e44cda
	Namespace: namespace_8f77dbcb
	Checksum: 0xB373F219
	Offset: 0x28A0
	Size: 0xB7
	Parameters: 0
	Flags: None
*/
function function_78e44cda()
{
	/#
		wait(0.05);
		level waittill("start_zombie_round_logic");
		wait(0.05);
		SetDvar("Dev Block strings are not supported", 0);
		AddDebugCommand("Dev Block strings are not supported");
		while(1)
		{
			if(GetDvarInt("Dev Block strings are not supported"))
			{
				SetDvar("Dev Block strings are not supported", 0);
				level thread function_eac1444a();
			}
			wait(0.5);
		}
	#/
}

/*
	Name: function_eac1444a
	Namespace: namespace_8f77dbcb
	Checksum: 0x5DA0BFA5
	Offset: 0x2960
	Size: 0x281
	Parameters: 0
	Flags: None
*/
function function_eac1444a()
{
	/#
		var_10b176f0 = GetAIArchetypeArray("Dev Block strings are not supported");
		foreach(ai_mechz in var_10b176f0)
		{
			var_efe3c52f = level.activePlayers[0] gettagorigin("Dev Block strings are not supported") + VectorScale((0, 0, 1), 20);
			var_7ddc55f4 = level.activePlayers[0] gettagorigin("Dev Block strings are not supported") + (5, 0, 20);
			var_a3ded05d = level.activePlayers[0] gettagorigin("Dev Block strings are not supported") + (-5, 0, 20);
			var_31d76122 = level.activePlayers[0] gettagorigin("Dev Block strings are not supported") + VectorScale((0, 0, 1), 15);
			MagicBullet(level.var_e106fba5, var_efe3c52f, ai_mechz GetCentroid(), level.activePlayers[0]);
			MagicBullet(level.var_791ba87b, var_7ddc55f4, ai_mechz GetCentroid(), level.activePlayers[0]);
			MagicBullet(level.var_5d4538da, var_a3ded05d, ai_mechz GetCentroid(), level.activePlayers[0]);
			MagicBullet(level.var_30611368, var_31d76122, ai_mechz GetCentroid(), level.activePlayers[0]);
		}
	#/
}

/*
	Name: function_22cf3e9f
	Namespace: namespace_8f77dbcb
	Checksum: 0xDAD1DE02
	Offset: 0x2BF0
	Size: 0x5B
	Parameters: 3
	Flags: None
*/
function function_22cf3e9f(str_weapon_name, v_source, ai_mechz)
{
	/#
		MagicBullet(level.var_791ba87b, v_source, ai_mechz GetCentroid(), level.activePlayers[0]);
	#/
}




// =============================================================================
// [acc] acc_setup_mechz - per-actor setup for a SpawnActor'd mechz (added 2026-07-08).
//
// spawn_mechz() above is the pack's spawner-entity path: it needs level.mechz_spawners[0], a
// .map actor spawner we deliberately do NOT place (custom-aitype .map spawners crashed the LED
// bake (Avogadro, map_source note ~L4331) and game load (Rogue Protector) on this codebase).
// _acc_boss_panzer instead SpawnActor()s the archetype at runtime - the proven Rogue
// Protector/Avogadro recipe - and calls this to apply spawn_mechz's per-ai block. Stock
// mechzSpawnSetup + ArchetypeMechzBlackboardInit + our re-registered function_3d5df242 all run
// automatically via the "mechz" archetype spawn functions (living proof archetype spawn funcs
// fire on SpawnActor: the Rogue Protector locomotes with no manual blackboard call).
//
// DELIBERATELY SKIPPED from spawn_mechz: function_ef1ba7e5 (pack 1500-pt kill bonus - our
// unified boss reward is the "every boss identical" economy contract), function_949a3fdf
// (death AoE - parks forever on the lost "hash_46c1e51d" notify, never fires in a usermap),
// the flyin path (castle entrance scene assets absent; flyin also drives the napalm-zombie
// code whose clientfields are unregistered), and the ForceTeleport ground snap (the caller
// picks a navmesh-clamped spawn point itself).
//
// Call mechz_spiki::mechz_health_increases() BEFORE this (and seed its level.* base fields
// once - _acc_boss_panzer::init() does) so the part-health level fields below are defined.
// =============================================================================
function acc_setup_mechz()
{
	if(!IS_TRUE(self.tod_ft_visual_watch_started))
	{
		self.tod_ft_visual_watch_started = true;
		self thread acc_ft_visual_watch();
	}
	self DisableAimAssist();
	self.actor_damage_func = &MechzServerUtils::mechzDamageCallback;
	self.damage_scoring_function = &function_b03abc02;
	self.mechz_melee_knockdown_function = &function_55483494;
	self.health = level.mechz_health;
	self.faceplate_health = level.MECHZ_FACEPLATE_HEALTH;
	self.powercap_cover_health = level.MECHZ_POWERCAP_COVER_HEALTH;
	self.powercap_health = level.MECHZ_POWERCAP_HEALTH;
	self.left_knee_armor_health = level.var_2cbc5b59;
	self.right_knee_armor_health = level.var_2cbc5b59;
	self.left_shoulder_armor_health = level.var_2cbc5b59;
	self.right_shoulder_armor_health = level.var_2cbc5b59;
	self.heroweapon_kill_power = 10;
	// [acc] THE STATUE BUG (playtest round 3, 2026-07-08 - THE root cause of "spawns but won't
	// move", found via the haspath/atgoal HB probes): Spiki's aitype GDT ships
	// defaultGoalRadius 2048 - any goal within 2048u counts as ALREADY ARRIVED, so on a
	// ~2000u-wide plaza every SetGoal at the player is instantly "at goal" and the BT idles
	// (atgoal=1 forever while he stares at you; he only ever walked when a goal landed beyond
	// 2048u). Fixed at the source (source_data/mechz_spiki.gdt, all 3 aitype blocks -> 64,
	// Avogadro ships 32) - this line is the script-side BELT so a GDT regression can never
	// re-statue him. Suspected to be the REAL story behind Spiki's own "spawns but won't move"
	// note (the assetlist-comment fix was likely coincidental).
	self.goalRadius = 64;
	self.b_flyin_done = 1;
	self.ignore_round_robbin_death = 1;
	self thread function_bb048b27();
	/#
		self.ignore_devgui_death = 1;
	#/
}
