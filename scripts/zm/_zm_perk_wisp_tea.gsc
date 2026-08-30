// WISP TEA — BO7 perk, vendored from WetEgg's SATPerksCode pack (2026-08-30,
// replaces Deadshot in the scatter roster). Machine + wisp models ride the
// SATPerksAssets install (root _custom\_wetegg\models\sat\sat_zm_machine_w_mod);
// jingle/stinger/powerloop aliases live in sound/aliases/tod_wisp_tea.csv.
// Mechanics: hitting zombies rolls 1-in-WISP_TEA_WISP_SPAWN_CHANCE to summon a
// wisp companion (a script_model, NOT an AI actor — no behaviour-tree cost)
// that chases and melee-kills zombies near the owner for WISP_TEA_WISP_DURATION
// seconds, then cools down. Rides an unused engine specialty
// (specialty_nomotionsensor) exactly like Death Perception rides
// specialty_combat_efficiency — HasPerk/SetPerk work natively.
//
// TOWER DELTAS vs the pack file (keep this list current if the pack updates):
// 1. HINT: the pack's localized &"PERKMACHINES_WISP_TEA" ref (needed a .str
//    install) is now the EC-style LITERAL hint with the &&1 cost substitution
//    — ONE new triggerstring slot, same as every other perk here.
// 2. MACHINE ANIMS STRIPPED (#using_animtree/AnimScripted/activateAnimation/
//    xanim precaches): every machine on this map poses as a static struct —
//    the d_mod/speed-cola fxanim meshes already do — and the .atr + xanim
//    install lane buys nothing but scatter-vs-anim interplay. The off/on
//    model pair in machine_assets (set in precache below) is the whole
//    visual contract; _tod_perk_lights leaves this specialty alone because
//    the pair does not follow the t10 off+"_on" naming.
// 3. LEAK FIXES: the pack never Deleted wisp.wispFXModel (one orphaned
//    tag_origin per summon), and the disconnect/bled_out exits from
//    wispFunctionality left the wisp entity alive forever. Both paths now
//    clean up — on an endless-rounds map those leaks compound into the
//    gentity budget (the spire's binding constraint).
// 4. "stopWispLookAt" notify/endon case mismatch fixed (the pack's endon said
//    "stopWispLookat", so every follow tick stacked another angles-writer
//    thread for the wisp's whole life).
// 5. sprintf() in take_wisp_tea_perk replaced with plain concat.

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
// wisp chance on every damaging hit while holding the perk and off cooldown.
function wispTeaDamageMonitor(inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex, surfacetype)
{
	if(!isPlayer(attacker) || !attacker HasPerk(WISP_TEA_SPECIALTY))
	{
		return -1;
	}

	chanceToSpawn = RandomIntRange(1,WISP_TEA_WISP_SPAWN_CHANCE + 1);

	if(!attacker.wispTeaCooldown && chanceToSpawn == WISP_TEA_WISP_SPAWN_CHANCE)
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

function give_wisp_tea_perk()
{
	self.wispTeaCooldown = false;
}

function take_wisp_tea_perk(b_pause, str_perk, str_result)
{
	self notify(WISP_TEA_SPECIALTY + "_stop");
	self notify("perk_lost", str_perk);
}

function spawnWisp()
{
	wisp = util::spawn_model(WISP_TEA_WISP_MODEL, self.origin, self.angles);
	wisp.wispFXModel = util::spawn_model("tag_origin", wisp.origin, wisp.angles);
	wisp LinkTo(self, "tag_origin", (120,-100,0));
	wisp.wispFXModel LinkTo(wisp, "tag_origin", (0,0,0));
	wisp.wispFXModel clientfield::set("wispTeaWispFX", 1);

	// [tod] Disconnect safety: the owner's threads die WITH the owner entity,
	// so no player-side path can clean up after a disconnect. The wisp owns
	// its own owner-watch instead (delta 3 in the header).
	wisp thread wispOwnerWatch(self);

	self thread wispFunctionality(wisp);
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
	self.wispTeaCooldown = true;

	response = self util::waittill_any_ex(WISP_TEA_WISP_DURATION, "disconnect","bled_out");

	// [tod] Every exit removes the wisp; the pack only cleaned up the natural
	// expiry, so a bleed-out (or disconnect) mid-summon stranded the wisp and
	// its FX model in the world forever (delta 3 in the header).
	self Notify("wispExpired");

	if(response != "disconnect" && response != "bled_out")
	{
		self thread wispCooldown();
	}

	// Threaded ON THE WISP so the 4s delete tail never depends on the owner's
	// thread surviving (it does not on bled_out -> spectate churn).
	wisp thread removeWisp();
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

function wispCooldown()
{
	level endon("game_over");
	self endon("disconnect");
	self endon("bled_out");

	wait(WISP_TEA_COOLDOWN_TIME);

	self.wispTeaCooldown = false;
}

function wispFollowEnemy(wisp)
{
	level endon("game_over");

	self endon("disconnect");
	self endon("bled_out");

	self endon("wispExpired");

	for(;;)
	{
		a_targets = GetActorTeamArray("axis");

		if(a_targets.size != 0 && zombie_utility::get_current_zombie_count() > 1)
		{
			e_target = ArrayGetClosest(wisp.origin, a_targets);

			playerDistance = Distance(self.origin, e_target.origin);

			if(playerDistance < WISP_TEA_WISP_MAX_DISTANCE_TO_PLAYER)
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
				wisp LinkTo(self, "tag_origin", (120,-100,0));
			}
		}
		else
		{
			wisp.attackTarget = undefined;
			wisp LinkTo(self, "tag_origin", (120,-100,0));
		}

		util::wait_network_frame();
	}
}

function wispAttack(wisp)
{
	self endon("wispExpired");

	for(;;)
	{
		if(isdefined(wisp.attackTarget))
		{
			if(IsAlive(wisp.attackTarget))
			{
				if(wisp.attackTarget.archetype == "zombie")
				{
					wisp.attackTarget DoDamage(wisp.attackTarget.maxHealth / WISP_TEA_DAMAGE_SEGMENTS, wisp.origin, self, self, "none", "MOD_MELEE", 0, GetWeapon("none"));
				}
				else
				{
					wisp.attackTarget DoDamage(WISP_TEA_NON_ZOMBIE_DAMAGE, wisp.origin, self, self, "none", "MOD_MELEE", 0, GetWeapon("none"));
				}
			}
		}

		wait(0.75);
	}
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
