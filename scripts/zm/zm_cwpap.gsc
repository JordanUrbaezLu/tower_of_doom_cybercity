    /////////////////////////////////////////////////////
   //
  //	         ALXS - CW-BO6 PAP         v1.1.2
 //
/////////////////////////////////////////////////////
//CREDITS//
//PAP model and Anims - Madgaz, Owen C137
//PAP script - RiDD_Alexis31, JoaoSlideCancelo, Prov3ntus, Shidouri, Resxt, CF4_99, Rayjiun, devraw and mod tools servers support and more
//PAP sounds - Owen C137
//
// =============================================================================
// [tod v13.12] DE-SINGULARIZED (user 2026-08-29: "just do it that way now" —
// every Pack-a-Punch machine runs THIS script's proven flow, not a graft of
// it). The original pack drives exactly ONE machine through the literal
// `level.packAPunchModel`; this fork makes the machine a parameter:
//
//   * register_pap_machine( model, trig_org, trig_angles, b_jingle ) — public.
//     The CROWN registers itself in __init__ from the prefab's own struct,
//     byte-faithful to the original bootstrap. The FOUR BREATHER VENDORS
//     register from _tod_powerups::breather_pap_place. Five machines, one
//     code path — whatever the crown does, every machine does.
//   * Every `level.packAPunchModel` became `self` (the functions were already
//     threaded ON the model) or an explicit machine parameter (the
//     player-threaded ones). No behavior changed by the transform.
//   * ONE NETWORK (user: "they all need to act as if they work together so I
//     cant just walk up and double pack from a different machine"):
//     the purchase cooldown is LEVEL-GLOBAL (level.tod_cwpap_cooldown_end) —
//     five stations, one machine's throughput. Double-upgrading is already
//     impossible at the weapon table (an _up form has no further upgrade row),
//     so the shared cooldown is what makes the network FEEL single.
//   * THE CLASS-GUN LANE is woven in (this map's tier-card system requires
//     it): class primaries fail stock's can_upgrade_weapon by design (the
//     twin roster), so the stock branch would deny them with a blank hint.
//     A class primary now buys at 5000 through the same show, latching
//     player.tod_pap_owned — _tod_upgrades::reconcile_twin swaps the _up
//     form within 1s, exactly the proven vendor lane's economics inside the
//     pack's presentation.
//   * The jingle runs on the machines with b_jingle true only (crown +
//     vendors all pass true would mean five overlapping music stings with
//     unknown 2d/3d routing — the crown keeps it, vendors stay quiet except
//     their idle hum; flip the vendor arg in _tod_powerups if wanted).
//   * Per-machine POWER-ON work is STAGGERED 0-1s (user: "started lagging a
//     bit when I turned on power" — the KB's simultaneous-FX-burst rule).
//   * USE_HAND_KNUCKLE stays false: the anim needs weapon
//     "zombie_knuckle_crack", which T7 does not ship and no installed pack
//     declares (see the zone comment). Re-enable together with a sourced
//     knuckle weapon port.
// =============================================================================

// [tod v13.14] HEADER RESTORED TO THE ORIGINAL'S FULL SET. The v13.12 rewrite
// slimmed the #usings and dropped the original's #precache block — losing the
// THREE HINT STRINGS (an unprecached &string kills SetHintString, i.e. every
// machine's prompt) and the aats using that pulls the AAT system in. Faithful
// means the whole header, not just the functions.
#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\trigger_shared;
#using scripts\shared\animation_shared;
#using scripts\shared\aat_shared;
#using scripts\shared\audio_shared;

#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_perks;

// [tod v13.17] AAT using REMOVED (user 2026-08-29: "its allowing me to double
// pack my guns... adding some elemental part... disable"). This using was the
// ONLY thing registering the AAT system map-wide (verified: no other module
// or zone line touches aats) — without it level.aat_in_use never goes true,
// so neither these five machines NOR the roof stock PaP can offer the 2500
// elemental re-pack. The USE_AAT_REPACK define below gates the branches too,
// in case a future module re-registers AATs for its own reasons.
// #using scripts\zm\aats\_zm_aat_blast_furnace;

#using scripts\zm\zm_tower_of_doom\_tod_classes;   // [tod] is_class_primary — the tier-card lane

#insert scripts\shared\aat_zm.gsh;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache("xmodel", "p9_fxanim_zm_gp_pap_xmodel_off");
#precache("xmodel", "p9_fxanim_zm_gp_pap_xmodel");
#precache( "xanim", "xanim_c5969f9b9bb4e89_idle");
#precache( "xanim", "xanim_a79285d6b6f48f4_in_use");
#precache("string", "ZOMBIE_PERK_PACKAPUNCH");
#precache("string", "ZOMBIE_PERK_PACKAPUNCH_AAT");
#precache("string", "ZOMBIE_NEED_POWER");

#define SND_UNSUP_PAPPING          true
#define AAT_FX_COLORS              2
#define USE_HAND_KNUCKLE           false    // [tod v13.9] see the header — needs a knuckle weapon port
#define USE_AAT_REPACK             false    // [tod v13.17] the 2500 elemental re-pack lane — OFF (user order, see the aats using tombstone)
#define TRIGGER_COOLDOWN_TIME      4
#define UPGRADE_FXANIM_TIME        4

#using_animtree("cwpapanimtree");

#namespace zm_cwpap;

REGISTER_SYSTEM_EX( "zm_cwpap", &__init__, undefined, undefined )

function __init__()
{
    clientfield::register( "scriptmover", "t9_pap_FX_idle", VERSION_SHIP, 1, "int" );
    clientfield::register( "scriptmover", "t9_pap_FX_inuse", VERSION_SHIP, 2, "int" );
    clientfield::register( "scriptmover", "t9_pap_FX_inuse_aat", VERSION_SHIP, 3, "int" );
    clientfield::register( "scriptmover", "t9_pap_FX_aat_bf", VERSION_SHIP, 3, "int" );
    clientfield::register( "scriptmover", "t9_pap_FX_aat_dw", VERSION_SHIP, 3, "int" );
    clientfield::register( "scriptmover", "t9_pap_FX_aat_fw", VERSION_SHIP, 3, "int" );
    clientfield::register( "scriptmover", "t9_pap_FX_aat_tw", VERSION_SHIP, 3, "int" );
    clientfield::register( "scriptmover", "t9_pap_FX_aat_t", VERSION_SHIP, 3, "int" );
    level.snd_unsup_pap = SND_UNSUP_PAPPING;
    level.use_papknuckles = USE_HAND_KNUCKLE;
    level.tod_cwpap_cooldown_end = 0;   // [tod] ONE cooldown for the whole network

    // THE CROWN — the pack's original machine, registered through the same
    // public lane the vendors use. [tod v13.15] MOVED TO THE LATE LANE: the
    // v13.12 direct call here ran at REGISTER_SYSTEM_EX time and guarded with
    // isdefined — if the prefab's entities are not findable that early, the
    // guard SKIPS SILENTLY and the crown simply never exists (the original
    // pack had no guard, so it never taught us whether system-time GetEnt on
    // prefab ents is safe). The retry lane below is the crown_pap_clips
    // (_tod_powerups v13.9) proven pattern, and it names its failure on
    // screen in dev instead of swallowing it.
    level thread crown_register_late();
}

function crown_register_late()
{
    level endon( "end_game" );
    while ( !( level flag::exists( "initial_blackscreen_passed" ) ) )
        wait 0.05;
    level flag::wait_till( "initial_blackscreen_passed" );
    for ( i = 0; i < 40; i++ )
    {
        crown_struct = struct::get("pap_trigger_struct", "targetname");
        crown_model  = GetEnt("pack_a_punch_model", "targetname");
        if ( isdefined( crown_model ) && isdefined( crown_struct ) )
        {
            register_pap_machine( crown_model, crown_struct.origin, crown_struct.angles, true );
            return;
        }
        wait 0.25;
    }
    if ( IS_TRUE( level.tod_dev ) )
        IPrintLnBold( "[PAP] CROWN NOT FOUND — prefab ents missing after 10s" );
}

// [tod v13.12] PUBLIC — one call makes any script_model a full Pack-a-Punch
// station on this script's flow. Late registration is fine (the vendors
// register at gameplay init, after clients connect).
function register_pap_machine( model, trig_org, trig_angles, b_jingle )
{
    if ( !isdefined( model ) )
        return;
    if ( !isdefined( b_jingle ) )
        b_jingle = false;
    model.tod_cwpap_jingle = b_jingle;
    model thread setup_unitrigger( trig_org, trig_angles );
    model thread papIdleSound();
    model thread machine_power_watch();
}

// Per-machine power watch — the original monitorPower, per machine, with the
// [tod] anti-burst stagger (five machines flipping in the same frame was the
// user's power-on lag; the KB documents the pattern).
function machine_power_watch()
{
    // [tod v13.13 — THE "MAP WONT START" BOOT FIX, 2026-08-29 ~3:25am]
    // Two bugs in one line pair, found from the user's terminal-error screen
    // ("cannot cast undefined to bool, flag_shared.gsc:0"):
    //  1. The CROWN registers from __init__ (system-registration time), so
    //     this thread ran BEFORE stock creates ANY flag — flag::wait_till on
    //     an unregistered flag is the exact cast error on the screen. The
    //     vendors register at gameplay init and never tripped it, which is
    //     why the de-sing booted in no earlier test: the crown was the only
    //     __init__-lane machine and this build was its first boot.
    //  2. "all_players_spawned" DOES NOT EXIST in this map at all — stock's
    //     only mention is a commented-out line (_zm.gsc:6849). Even guarded,
    //     the wait would never return and NO machine would ever power on.
    // Fix: the exists-loop + blackscreen wait (the _tod_ammo_crate precedent,
    // required for any pre-gameplay-init thread), then "power_on", which is
    // registered by stock zm_power long before the blackscreen passes.
    while ( !( level flag::exists( "initial_blackscreen_passed" ) ) )
        wait 0.1;
    level flag::wait_till( "initial_blackscreen_passed" );
    level flag::wait_till("power_on");
    wait RandomFloatRange( 0.05, 1.0 );
    if ( !isdefined( self ) )
        return;
    self thread powerOnAnimation();
    self thread monitorPackAPunch();
}

function monitorPackAPunch()
{
    if ( IS_TRUE( self.tod_cwpap_jingle ) )
        self thread pap_jingle_logic();

    for(;;)
    {
        self waittill( "trigger_activated", player );

        if( GetTime() > level.tod_cwpap_cooldown_end ) // [tod] network-global — five stations, one throughput
        {
            weapon = player GetCurrentWeapon();

            // [tod] CLASS-GUN LANE — class primaries fail stock can_upgrade
            // by roster design; they buy here at the same price through the
            // same show, latching the flag the tier-card system reads.
            // reconcile_twin (_tod_upgrades) swaps the _up form within 1s.
            // [tod v13.14] is_class_primary is (player, weapon) — the v13.12
            // one-arg call returned false silently and killed the whole lane.
            if ( tod_classes::is_class_primary( player, weapon ) && !IS_TRUE( player.tod_pap_owned ) )
            {
                if ( player zm_score::can_player_purchase( 5000 ) && zm_utility::is_player_valid( player ) )
                {
                    player zm_score::minus_to_player_score( 5000 );
                    self PlaySoundToPlayer("zmb_cha_ching", player);
                    player.tod_pap_owned = true;
                    self thread papFXIdle(0);
                    self thread papFXInUse(1);
                    self UseAnimTree(#animtree);
                    self AnimScripted( "optionalNotify", self.origin , self.angles, %xanim_a79285d6b6f48f4_in_use);
                    self thread stopUpgradeAnimationAfterTime(UPGRADE_FXANIM_TIME);
                    self thread papInUseSound();
                    self thread papLeverSound();
                    self StopSound( "cw_mus_perks_packa_sting" );
                    wait 0.05;
                    self PlaySound( "cw_mus_perks_packa_sting" );
                    player zm_audio::create_and_play_dialog( "weapon_pickup", "upgrade" );
                }
                else
                {
                    self PlaySoundToPlayer("zmb_perks_packa_deny", player);
                    player zm_audio::create_and_play_dialog( "general", "outofmoney");
                }
            }
            else if (zm_weapons::is_weapon_upgraded(weapon))
            {
                if (USE_AAT_REPACK && zm_weapons::weapon_supports_aat(weapon) && ( isdefined( level.aat_in_use ) && level.aat_in_use ) )
                {
                    if(player hasEnoughMoney(2500, self) && zm_utility::is_player_valid( player ) )
                    {
                        player thread giveWeaponAAT( self );
                        self thread papFXIdle(0);
                        self UseAnimTree(#animtree);
                        self AnimScripted( "optionalNotify", self.origin , self.angles, %xanim_a79285d6b6f48f4_in_use);
                        self thread stopUpgradeAnimationAfterTime(UPGRADE_FXANIM_TIME);
                        self thread papInUseAATSound();
                        self thread papLeverSound();
                        self StopSound( "cw_mus_perks_packa_sting" );
                        self StopSound( "cw_mus_perks_packa_jingle" );
                        wait 0.05;
                        self PlaySound( "cw_mus_perks_packa_sting" );
                        player zm_audio::create_and_play_dialog( "weapon_pickup", "upgrade" );
                    }
                }
                else
                {
                    if(level.snd_unsup_pap)
                    {
                        self PlaySoundToPlayer("zmb_perks_packa_deny", player);
                    }
                    player zm_audio::create_and_play_dialog( "general", "oh_shit" );
                }
            }
            else
            {
                if (zm_weapons::can_upgrade_weapon(weapon))
                {
                    if(player hasEnoughMoney(5000, self) && zm_utility::is_player_valid( player ) )
                    {
                        player thread giveWeaponUpgraded();
                        self thread papFXIdle(0);
                        self thread papFXInUse(1);
                        self UseAnimTree(#animtree);
                        self AnimScripted( "optionalNotify", self.origin , self.angles, %xanim_a79285d6b6f48f4_in_use);
                        self thread stopUpgradeAnimationAfterTime(UPGRADE_FXANIM_TIME);
                        self thread papInUseSound();
                        self thread papLeverSound();
                        self StopSound( "cw_mus_perks_packa_sting" );
                        self StopSound( "cw_mus_perks_packa_jingle" );
                        wait 0.05;
                        self PlaySound( "cw_mus_perks_packa_sting" );
                        if(level.use_papknuckles)
                        {
                            wait 2.2;
                            player zm_audio::create_and_play_dialog( "weapon_pickup", "upgrade" );
                        }
                        else
                        {
                            player zm_audio::create_and_play_dialog( "weapon_pickup", "upgrade" );
                        }
                    }
                }
                else
                {
                    if(level.snd_unsup_pap)
                    {
                        self PlaySoundToPlayer("zmb_perks_packa_deny", player);
                    }
                    player zm_audio::create_and_play_dialog( "general", "oh_shit" );
                }
            }

            level.tod_cwpap_cooldown_end = GetTime() + ( TRIGGER_COOLDOWN_TIME * 1000 );
        }
    }
}

function papFXIdle(reproduce)
{
    self clientfield::set( "t9_pap_FX_idle", reproduce );
}

function papFXInUse(reproduce)
{
    self clientfield::set( "t9_pap_FX_inuse", reproduce );
}

function papFXInUseAAT(reproduce)
{
    self clientfield::set( "t9_pap_FX_inuse_aat", reproduce );
}

function powerOnAnimation()
{
    self SetModel("p9_fxanim_zm_gp_pap_xmodel");
    self thread playIdleAnimation();
}

// Animación de espera del Pack-a-Punch
function playIdleAnimation()
{
    self UseAnimTree(#animtree);
    self AnimScripted( "", self.origin , self.angles, %xanim_c5969f9b9bb4e89_idle);
    self thread papFXIdle(1);
}

// Detener animación de mejora después de un tiempo
function stopUpgradeAnimationAfterTime(duration)
{
    wait(duration);
    self thread papFXInUse(0);
    self thread papFXInUseAAT(0);
    self thread playIdleAnimation();
}

// Verificar si el jugador tiene suficiente dinero (y COBRAR — the original
// charges inside the check; [tod] the machine rides in as a param now)
function hasEnoughMoney(amount, machine)
{
    weapon = self GetCurrentWeapon();
    player = self;
    if(player zm_score::can_player_purchase(amount))
    {
        if (zm_weapons::is_weapon_upgraded(weapon))
        {
            if (zm_weapons::weapon_supports_aat(weapon) && ( isdefined( level.aat_in_use ) && level.aat_in_use ) )
            {
                if (amount >= 2500)
                {
                    player zm_score::minus_to_player_score(amount);
                    machine PlaySoundToPlayer("zmb_cha_ching", self);
                }
            }
        }
        else
        {
            if (zm_weapons::can_upgrade_weapon(weapon))
            {
                if (amount >= 5000)
                {
                    player zm_score::minus_to_player_score(amount);
                    machine PlaySoundToPlayer("zmb_cha_ching", self);
                }
            }
        }
        return true;
    }
    else
    {
        machine PlaySoundToPlayer("zmb_perks_packa_deny", self);
        player zm_audio::create_and_play_dialog( "general", "outofmoney");
        return false;
    }
}

function giveWeaponUpgraded()
{
    weapon = self GetCurrentWeapon();
    self takeWeapon(weapon);
    upgrade_weapon = zm_weapons::get_upgrade_weapon(weapon, false);
    if(level.use_papknuckles)
    {
        self DisableWeaponCycling();
        hands = GetWeapon("zombie_knuckle_crack");
        self GiveWeapon(hands);
        self SwitchToWeapon(hands);
        wait(2.2);
        self takeWeapon(hands);
        self EnableWeaponCycling();
    }
    self zm_weapons::weapon_give(upgrade_weapon, true, false, true, true);
    self switchToWeapon(upgrade_Weapon);
}

function giveWeaponAAT( machine ) //self = who is upgrading
{
    weapon = self GetCurrentWeapon();
    self thread aat::acquire( weapon );
    if(AAT_FX_COLORS == 1)
    {
        machine thread papFXInUseAAT(1);
    }
    if(AAT_FX_COLORS == 2)
    {
        self thread watchAAT(weapon, machine);
    }
}

function PapPromptAndVisibility(player)
{
    weapon = player GetCurrentWeapon();

    if (level flag::get("power_on"))
    {
        // [tod] class primaries: stock can_upgrade rejects the twin roster by
        // design, which used to blank this hint — the class lane prices here.
        if ( tod_classes::is_class_primary( player, weapon ) && !IS_TRUE( player.tod_pap_owned ) )
        {
            self SetHintString( &"ZOMBIE_PERK_PACKAPUNCH", 5000 );
        }
        else if ( zm_weapons::is_weapon_upgraded( weapon ))
        {
            if (USE_AAT_REPACK && zm_weapons::weapon_supports_aat(weapon))
            {
                self SetHintString( &"ZOMBIE_PERK_PACKAPUNCH_AAT", 2500 );
            }
            else
            {
                self SetHintString("");   // packed is packed — no re-pack lane on this map
            }
        }
        else
        {
            if (zm_weapons::can_upgrade_weapon(weapon))
            {
                self SetHintString( &"ZOMBIE_PERK_PACKAPUNCH", 5000 );
            }
            else
            {
                self SetHintString("");
            }
        }
    }
    else
    {
        self SetHintString( &"ZOMBIE_NEED_POWER");
    }

    return true;
}

function papInUseSound()
{
    self PlaySound("alxs_cwpap_inuse");
}

function papInUseAATSound()
{
    self PlaySound("alxs_cwpap_inuse_aat");
}

function papIdleSound()
{
    level waittill("power_on");
    if ( !isdefined( self ) )
        return;
    self PlaySound("alxs_cwpap_appear");
    wait 1;
    if ( isdefined( self ) )
        self PlayLoopSound("alxs_cwpap_idle_lp");
}

function papLeverSound()
{
    self PlaySound("alxs_cwpap_lever_down");
    wait 1.82;
    if ( isdefined( self ) )
        self PlaySound("alxs_cwpap_lever_up");
}

function watchAAT(weapon, machine)
{
    keys = getarraykeys(level.aat);
    if(self.aat[weapon] == "zm_aat_blast_furnace")
    {
        machine thread papFXInUseAAT(2);
    }
    if(self.aat[weapon] == "zm_aat_dead_wire")
    {
        machine thread papFXInUseAAT(3);
    }
    if(self.aat[weapon] == "zm_aat_fire_works")
    {
        machine thread papFXInUseAAT(4);
    }
    if(self.aat[weapon] == "zm_aat_thunder_wall")
    {
        machine thread papFXInUseAAT(5);
    }
    if(self.aat[weapon] == "zm_aat_turned")
    {
        machine thread papFXInUseAAT(6);
    }
}

function pap_jingle_logic()
{
    wait RandomIntRange( 10, 60 );
    for( ;; )
    {
        self StopSound( "cw_mus_perks_packa_sting" );
        wait 0.05;
        self PlaySound( "cw_mus_perks_packa_jingle" );
        wait ( SoundGetPlaybackTime( "cw_mus_perks_packa_jingle" ) * .001 ) + RandomIntRange( 30, 120 );
    }
}

function setup_unitrigger( trig_org, trig_angles )
{
    unitrigger_pap = SpawnStruct();
    unitrigger_pap.origin = trig_org;
    unitrigger_pap.angles = trig_angles;
    unitrigger_pap.script_unitrigger_type = "unitrigger_box_use";
    unitrigger_pap.cursor_hint = "HINT_NOICON";
    unitrigger_pap.script_width = 40;
    unitrigger_pap.script_height = 50;
    unitrigger_pap.script_length = 40;
    unitrigger_pap.related_parent = self;
    unitrigger_pap.inactive_reassess_time = 1;
    zm_unitrigger::unitrigger_force_per_player_triggers(unitrigger_pap, true);
    unitrigger_pap.prompt_and_visibility_func = &PapPromptAndVisibility;
    zm_unitrigger::register_static_unitrigger( unitrigger_pap, &zm_unitrigger::unitrigger_logic );
}
