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
#using scripts\shared\laststand_shared;   // [tod v17.51] giveWeaponRepacked never raises into last stand

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
// so none of these five machines can offer the 2500 elemental re-pack (the
// "roof stock PaP" this line used to name does not exist: the hall's ALXS
// prefab is the ONLY PaP prefab in the .map — corrected 2026-09-02). The
// USE_AAT_REPACK define below gates the branches too,
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
// [tod v17.51] PACK II/III keep the gun for a moment — see giveWeaponRepacked.
// v17.53 (user: "4 seconds is way too long. Can we shorten as much as possible
// while it still works"): 1.0 s. The floor is set by what has to be SEEN, not
// by the machine: the take lowers the gun and the engine raises the other
// weapon (~0.5 s); the return then lowers that and raises the gun. Under ~1 s
// the two overlap, the second switch can be eaten mid-raise (camo_regive's
// re-assert catches it, but it reads as a stutter), and the take stops
// registering as a take at all. The machine's own 4 s show runs on
// UPGRADE_FXANIM_TIME regardless.
#define TOD_PAP_TIER_HOLD_SECS     0.5   // v17.53b (user: "What about 500ms?") — the re-assert in camo_regive covers an eaten switch; 1.0 is the fallback if it stutters
// [tod v16.27] THE TRIGGER ORIGIN FLOATS OFF THE FLOOR. This map has paid twice
// for a solid brush sitting on a script trigger's origin — the extraction
// obelisk and the hall crate's clip column both killed their buy outright
// (_tod_finale::spawn_props records both) — and v16.7 gave every breather
// lounge a 1u glowing floor inlay whose EAST SPOKE runs exactly under the
// pap_trig anchor (the generator ends the spoke 44u from the machine; the
// trigger is 56u out). The stub used to sit AT floor level, the stock prefab
// convention, which is fine on a bare floor (the crown, verified) and dead
// under a decal. The unitrigger's own range test is Distance2DSquared (stock
// _zm_unitrigger.gsc:431), so height costs no reach; 8 clears any 1u decal.
// The upgrade stations lift for the same reason (_tod_upgrades,
// TOD_STATION_TRIG_LIFT) — that one is the crown altar's actual bug.
#define TOD_PAP_TRIG_LIFT          8

// =============================================================================
// [tod v17.33] PACK-A-PUNCH TIERS — the 25,000 / 50,000 re-packs, SPIRE ONLY.
//
// User 2026-09-04: "itll be 25k for pap tier II and 50k for tier III. You can
// do it to any gun. Only available in the endless spire PaP ... I still want
// the animation of it taking the gun away and giving it back. Itll just give
// back the same gun. +50% damage at each level."
//
// The machine sells a tier only when its own tod_cwpap_tiers flag is set, and
// _tod_powerups::breather_pap_place only sets it for the machines the spire
// places (its own 4th argument, defaulted false). The tower's five machines —
// four breather lounges and the crown — are byte-identical in behaviour to
// what shipped, which is the point: the tiers are the SPIRE's reward, and the
// spire is the map's hard mode.
//
// THE SHOW IS THE STOCK ONE, UNCHANGED, AND THAT IS THE WHOLE POINT (user
// 2026-09-04: "I want it the same as other pap with differnt text since price
// is different and it spap II ... Other than that it should be same
// animation"). Same FX, same AnimScripted lever, same sting, same cha-ching,
// same topped-up gun in your hands at the end. ONLY THE PROMPT DIFFERS —
// tod_set_tier_hint. See pap_refill for why the weapon itself is not touched.
// =============================================================================
#define TOD_PAP_TIER2_COST         25000
#define TOD_PAP_TIER3_COST         50000

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
// [tod v17.33] b_tiers — does this machine sell PACK II / PACK III? Spire hubs
// only; see the TOD_PAP_TIER2_COST block. Defaulted false so every existing
// caller keeps the shipped behaviour without being edited.
function register_pap_machine( model, trig_org, trig_angles, b_jingle, b_tiers )
{
    if ( !isdefined( model ) )
        return;
    if ( !isdefined( b_jingle ) )
        b_jingle = false;
    if ( !isdefined( b_tiers ) )
        b_tiers = false;
    model.tod_cwpap_jingle = b_jingle;
    model.tod_cwpap_tiers = b_tiers;
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

// [tod 2026-09-22, bug review F12] What the machine will NOT pack even though
// the weapons CSV pairs it with an `_upgraded` form. Stock's own
// _zm_pack_a_punch::can_pack_weapon refuses `weapon.isriotshield` outright;
// this port had no such test, so a held RIOT SHIELD (the universal card's
// zod_riotshield) showed "Pack-a-Punch 5000", took the points, and
// _tod_riotshield's reconcile swapped the upgraded shield straight back.
function tod_pap_refuses(weapon)
{
    return ( isdefined( weapon ) && IS_TRUE( weapon.isriotshield ) );
}

function monitorPackAPunch()
{
    if ( IS_TRUE( self.tod_cwpap_jingle ) )
        self thread pap_jingle_logic();

    for(;;)
    {
        self waittill( "trigger_activated", player );

        if( GetTime() > level.tod_cwpap_cooldown_end && !IS_TRUE( player.tod_tier_busy ) && !IS_TRUE( player.tod_swap_busy ) ) // network-global throughput and player inventory lock
        {
            weapon = player GetCurrentWeapon();

            // [tod] CLASS-GUN LANE — class primaries fail stock can_upgrade
            // by roster design; they buy here at the same price through the
            // same show, latching the flag the tier-card system reads.
            // reconcile_twin (_tod_upgrades) swaps the _up form within 1s.
            // [tod v13.14] is_class_primary is (player, weapon) — the v13.12
            // one-arg call returned false silently and killed the whole lane.
            if ( tod_classes::is_class_primary( player, weapon ) && tod_classes::pap_tier( player, weapon ) == 0 )
            {
                if ( player zm_score::can_player_purchase( 5000 ) && zm_utility::is_player_valid( player ) )
                {
                    player zm_score::minus_to_player_score( 5000 );
                    self PlaySoundToPlayer("zmb_cha_ching", player);
                    tod_classes::pap_first_grant( player, weapon );
                    // [tod v19.76] THE PAID MACHINE KEEPS ITS SHOW. swap_primary turns
                    // the first-raise flourish off for upgrade swaps (cards, tier-ups,
                    // the free PaP DROP - the tester's "can't cancel it" report); this
                    // stamp tells it the swap reconcile_twin is about to make is THIS
                    // 5,000 purchase, which keeps the packed gun's first raise as it
                    // always had. Read once, within 3 s (reconcile swaps within 1 s).
                    player.tod_pap_flourish_ms = GetTime();
                    if ( tod_classes::pap_independent( player, weapon ) )
                        player thread giveWeaponRepacked( weapon );
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
            else if ( zm_weapons::is_weapon_upgraded( weapon ) || tod_weapon_is_packed( player, weapon ) )   // [tod v16.27] the CSV-blind packed forms deny here too, not via can_upgrade
            {
                // [tod v17.33] THE TIER LANE — spire machines only, and only
                // while there is a tier left to sell. Ordered FIRST inside the
                // packed branch so it wins over the AAT arm and the deny; on
                // the tower's five machines tod_cwpap_tiers is false and this
                // whole arm is skipped, leaving the shipped behaviour exact.
                //
                // CHARGE ORDER IS THE CLASS-GUN LANE'S, NOT hasEnoughMoney's:
                // affordability is tested BEFORE anything is taken, and the
                // tier is recorded BEFORE the show, so a player who somehow
                // disconnects mid-animation keeps what they paid for rather
                // than paying for a state that was never written.
                if ( IS_TRUE( self.tod_cwpap_tiers ) && tod_pap_next_tier( player, weapon ) > 0 )
                {
                    next = tod_pap_next_tier( player, weapon );
                    cost = tod_pap_tier_cost( next );
                    if ( player zm_score::can_player_purchase( cost ) && zm_utility::is_player_valid( player ) )
                    {
                        player zm_score::minus_to_player_score( cost );
                        self PlaySoundToPlayer( "zmb_cha_ching", player );
                        tod_classes::pap_tier_set( player, weapon, next );
                        player thread giveWeaponRepacked( weapon );   // [tod v17.39] the 5,000 buy's own take -> give, so the tier's camo rides in; refills too
                        // was: player pap_refill( weapon );  — v17.33 left the gun in hand, which is why no tier ever changed its look
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
                else if (USE_AAT_REPACK && zm_weapons::weapon_supports_aat(weapon) && ( isdefined( level.aat_in_use ) && level.aat_in_use ) )
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
                if (zm_weapons::can_upgrade_weapon(weapon) && !tod_pap_refuses(weapon))
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
            if (zm_weapons::can_upgrade_weapon(weapon) && !tod_pap_refuses(weapon))
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
    // [tod v17.39] THE CAMO IS STAMPED HERE, AT THE SOURCE. weapon_give hands
    // the packed form over with stock's camo index (42 — a row this map's
    // four-slot tables do not have; every stock camo material is a name-only
    // stub here anyway, see tools/gen_tod_camo.js). Options are per-give and
    // the only give that changes them on an owned asset is take -> give, so
    // the gun is re-dressed immediately, ammo preserved, and raised. The
    // watcher in _tod_classes is a backstop only from this build on.
    self tod_classes::camo_regive( upgrade_weapon, true );
    self switchToWeapon(upgrade_Weapon);
}

// [tod v17.39] THE TIER BUY (PACK II / III, spire machines). Same shape as the
// 5,000 buy above — take at the lever, hand back after the show — with ONE
// difference: the asset does not change. v17.33 left the gun in the player's
// hands for exactly that reason (its comment survives at pap_refill), and that
// is why a tier never changed its look: nothing re-gave the weapon, so nothing
// could carry the new tier's options. Taking it at the machine, where the
// player has just pressed USE, is the state the 5,000 buy has used for months;
// weapon_give on a weapon NOT held runs stock's full path (melee slot, fallback
// take, purchase notify), exactly as the first pack did.
//
// [tod v17.51] THE MACHINE KEEPS THE GUN FOR ITS SHOW (user 2026-09-04: "Can we
// make it so the weapon gets taken on 2 and 3"). A same-asset take -> give in
// one frame plays nothing, so PACK II/III looked inert even once the camo
// changed. Now the take lands at the lever and the give lands when the
// machine's in-use anim ends (TOD_PAP_TIER_HOLD_SECS = UPGRADE_FXANIM_TIME, the
// same clock stopUpgradeAnimationAfterTime runs on), so the gun comes back —
// re-dressed in the new tier's camo — with a real raise. During the window the
// player holds their other weapon, exactly as at every stock Pack-a-Punch.
// tod_tier_busy holds the class-gun watchdog off (it re-gives a missing class
// gun after 3 s — one second SHORTER than the show) and reconcile with it;
// cleared on EVERY exit. A player who goes down mid-show still gets the gun
// back (never raised into last stand — the engine owns the weapon there).
function giveWeaponRepacked( weapon )
{
    self endon( "disconnect" );
    level endon( "end_game" );
    if ( !isdefined( weapon ) || weapon == level.weaponNone || !( self HasWeapon( weapon ) ) )
        return;
    self.tod_tier_busy = true;
    self takeWeapon( weapon );
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
    else
    {
        wait TOD_PAP_TIER_HOLD_SECS;
    }
    weapon = tod_classes::staff_presentation( self, weapon );
    if ( tod_classes::pap_staff_id( weapon ) > 0 )
    {
        // Stock weapon_give runs GetBuildKitWeapon, which can replace our
        // presentation attachment. Give the resolved staff directly.
        weapon = self tod_classes::give_camo_weapon( weapon );
        self GiveStartAmmo( weapon );
        self notify( "weapon_give", weapon );
    }
    else
        self zm_weapons::weapon_give( weapon, true, false, true, true );   // full ammo — the refill stays (pap_refill's rule)
    if ( self laststand::player_is_in_laststand() )
    {
        self tod_classes::camo_regive( weapon, false, true );   // flourish remains pending in the holster
        self.tod_tier_busy = undefined;
        return;
    }
    self tod_classes::camo_regive( weapon, true, true );
    self switchToWeapon( weapon );
    self.tod_tier_busy = undefined;
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
        if ( tod_classes::is_class_primary( player, weapon ) && tod_classes::pap_tier( player, weapon ) == 0 )
        {
            self SetHintString( &"ZOMBIE_PERK_PACKAPUNCH", 5000 );
        }
        else if ( zm_weapons::is_weapon_upgraded( weapon ) || tod_weapon_is_packed( player, weapon ) )
        {
            // [tod v17.33] THE TIER PROMPT. Same gate and same question the
            // purchase asks (tod_pap_next_tier), so the sign and the till can
            // never disagree. self is the TRIGGER here, not the machine — the
            // machine is the stub's related_parent, set in setup_unitrigger.
            m_tier = self.stub.related_parent;
            if ( isdefined( m_tier ) && IS_TRUE( m_tier.tod_cwpap_tiers ) && tod_pap_next_tier( player, weapon ) > 0 )
            {
                self tod_set_tier_hint( tod_pap_next_tier( player, weapon ) );
            }
            else if (USE_AAT_REPACK && zm_weapons::weapon_supports_aat(weapon))
            {
                self SetHintString( &"ZOMBIE_PERK_PACKAPUNCH_AAT", 2500 );
            }
            else
            {
                // [tod v16.27] was SetHintString( "" ) — "packed is packed". A
                // blank hint is the double-pack confusion; see tod_set_packed_hint.
                // [tod v17.33] On a spire machine reaching here means PACK III
                // is already owned, which is a different sentence — and the
                // shipped one ("upgrade at the Heavenly Gift Altar") is wrong there
                // anyway: the spire has no altars at all (_tod_upgrades
                // station_spawn places base 0, breathers 1-4 and crown 5, and
                // that is the whole list).
                self tod_set_packed_hint( player, weapon,
                    ( isdefined( m_tier ) && IS_TRUE( m_tier.tod_cwpap_tiers ) ) );
            }
        }
        else
        {
            if (zm_weapons::can_upgrade_weapon(weapon) && !tod_pap_refuses(weapon))
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

// =============================================================================
// [tod v16.27] THE PACKED STATES — real copy instead of a blank hint.
//
// WHAT WAS WRONG (user 2026-09-02: "Many people get confused cause it still
// says [the buy prompt] when you try to double pap"). Every packed weapon in
// hand set SetHintString( "" ), and the Aetherium router IGNORED a blank hint
// (ZMCursorHintNew.lua only re-evaluated its state on non-empty text — fixed
// alongside this), so the card that was up last — "Pack-a-Punch / Upgrade
// your weapon / 5000 / Hold F To Upgrade", i.e. the prompt you had just bought
// through — simply stayed on screen. Hold F again: deny sound, no explanation.
// That is the double-pack confusion, and it is worst right after a purchase,
// when the packed gun is the one in your hands.
//
// NOW: a packed weapon in hand draws the DEFAULT card as a STATUS line (no
// button token, so PromptDefault hides the footer — nothing to press):
//     ALREADY PACKED
//     upgrade at the Heavenly Gift Altar
//     sidearm can still be packed        (only while that is true)
// The sidearm (or the class gun, when the packed thing in hand is the sidearm)
// still buys through the stock lane exactly as before — this changes only what
// the machine SAYS when it has nothing to sell you.
//
// THREE distinct strings, all constant. tools/lint_tod_hints.js counts this
// file since v16.27 (it was the lint's declared blind spot; this is the first
// authored copy in it). "already packed" is in TOD_NOUNS, so the router claims
// the line by name before isPAPHint can see "upgrade"/"pack" in it, and the
// detail deliberately never says "weapon" (upgrade+weapon = the PaP card,
// which never reads the text). A hyphen or slash may appear ONLY as the " - "
// and " / " separators — PromptDefault splits on the first of each. Detail
// lines are kept to ~30 characters: the card's detail box is 146px wide.
//
// PACKED-NESS IS A NAME TEST, NOT is_weapon_upgraded ALONE. Stock's
// is_weapon_upgraded reads level.zombie_weapons_upgraded, which the CSV rows
// for the Enfield / knife / Leviathan (and three sidearms) never populate —
// the weapons-CSV `_zm` suffix mismatch — so a packed Enfield in hand fell
// through to can_upgrade_weapon (false for every twin) and blanked too. The
// class primary answers by tod_pap_owned (the tier system's own latch, set the
// moment the buy lands and before reconcile_twin swaps the form) or by the
// `_up` substring; a class sidearm by the same `_up` test
// _tod_classes::pap_secondary uses. Nothing else in this map packs.
// =============================================================================
// =============================================================================
// [tod v17.33] THE TIER HELPERS. Three small functions, one job each, because
// the prompt and the purchase must never be able to disagree about what is on
// sale — both ask tod_pap_next_tier(), and the price comes from the tier it
// returns rather than from a second test of the same state.
// =============================================================================

// self = the player's own unitrigger. THE TIER BUY PROMPT.
//
// TWO CONSTANT STRINGS, one per tier, each handed to SetHintString DIRECTLY —
// the shape tools/lint_tod_hints.js can count, and the reason the price is
// concatenated from a #define rather than read from a runtime value. A hint
// that interpolates a many-valued number mints one PERMANENT engine slot per
// distinct value against a 250-per-match cap; a #define is resolved at compile
// time, so each of these is exactly one slot. Keep it that way.
//
// THE WORDING IS A UI CHOICE, NOT A STYLE CHOICE. ZMCursorHintNew.lua's
// isPAPHint routes any hint containing BOTH "pack" and "punch" to the static
// Pack-a-Punch card, which draws its own fixed title and price and NEVER reads
// the text — so this copy says PACK II, never PACK-A-PUNCH II. Belt and
// braces, "pack ii" and "pack iii" are also in that file's TOD_NOUNS list,
// which is claimed at step 3, two steps before isPAPHint runs. If you reword
// these, keep the noun and keep "punch" out.
//
// The detail line names the damage in the same terms the card art and the HUD
// badge do: tier II is +50%, tier III is +100% over the packed gun.
// [v19.38] SPELLED OUT, NOT SYMBOLS: the prompt typeface has no "+" or "%"
// glyph and drops both silently, so "+50% damage" drew as "50 DAMAGE".
// Say "percent" in words; never put a symbol the name set lacks in this copy.
function tod_set_tier_hint( next )
{
    if ( next == 2 )
    {
        self SetHintString( "Hold ^3[{+activate}]^7 ^5PACK II^7 - amplify this weapon / 50 percent more damage ^2[Cost: " + TOD_PAP_TIER2_COST + "]" );
        return;
    }
    self SetHintString( "Hold ^3[{+activate}]^7 ^5PACK III^7 - amplify this weapon / 100 percent more damage ^2[Cost: " + TOD_PAP_TIER3_COST + "]" );
}

// The tier this buy would move the weapon TO, or 0 if there is nothing to sell:
// the gun is not packed at all (the ordinary 5,000 lane owns that), or it is
// already at TOD_PAP_TIER_MAX.
function tod_pap_next_tier( player, weapon )
{
    if ( !isdefined( player ) || !isdefined( weapon ) )
        return 0;
    t = tod_classes::pap_tier( player, weapon );
    // pap_tier_max(), never a literal — a GSC #define does not cross files, so
    // the ceiling has to be ASKED FOR rather than copied. This tested a bare 3
    // for one build.
    if ( t < 1 || t >= tod_classes::pap_tier_max() )
        return 0;
    return t + 1;
}

function tod_pap_tier_cost( tier )
{
    if ( tier == 2 )
        return TOD_PAP_TIER2_COST;
    return TOD_PAP_TIER3_COST;
}

// [tod v17.39] SUPERSEDED — the tier lane now calls giveWeaponRepacked (above),
// because the weapon DOES change after all: its camo. Weapon options are a
// per-give value, so a gun left in the player's hands could never show the
// tier it had just been sold. The take -> give is the stock lane's same-frame
// one (no empty-handed window — the knuckle wait is off, USE_HAND_KNUCKLE),
// followed by camo_regive's bounded re-assert against the eaten-switch strand
// described below. The refill still rides in weapon_give. This function and
// the reasoning under it are kept as the record of why it was ever different.
//
// self = the player. THE PURCHASE'S EFFECT ON THE WEAPON — which is a refill
// and nothing else.
//
// v17.33a (user 2026-09-04: "I want it the same as other pap with differnt text
// since price is different and it spap II ... Other than that it should be same
// animation"). The first version took the weapon, waited 2.2 s and handed it
// back, reading "the animation of it taking the gun away and giving it back"
// literally. That was an empty-handed window NO Pack-a-Punch in this map has,
// in a spire hub where a trial can seal the player in.
//
// WHAT "THE SAME AS OTHER PAP" ACTUALLY IS, measured rather than assumed:
//   * the CLASS-GUN lane (5,000) never touches the weapon at all — it sets the
//     latch, plays the show, and reconcile_twin swaps the form within a second.
//   * the STOCK lane (giveWeaponUpgraded) takes and gives in the SAME FRAME,
//     which is invisible. The machine's lever anim IS the visible event.
// Neither leaves the player weaponless for one frame, so neither does this.
//
// AND HERE THE WEAPON DOES NOT CHANGE, so there is nothing to swap and a
// take/give would buy nothing while opening the map's worst-known weapon bug:
// SwitchToWeaponImmediate is silently EATEN in several player states (mid-sprint,
// mid-raise, mid-reload, ADS transition), after which TakeWeapon strands the
// player on the pistol — the entire reason swap_primary exists
// (_tod_upgrades.gsc). reconcile_twin could not repair it either, because the
// form it wants is the form already owned. So the weapon is left alone.
//
// THE REFILL STAYS. Every other Pack-a-Punch in the game hands back a topped-up
// gun, and at 25,000 and 50,000 this must not be worse than the 5,000 buy.
// GiveStartAmmo on an unchanged asset is already this tree's idiom for exactly
// this case (_tod_upgrades.gsc:5120, "same asset ... still a refill").
function pap_refill( weapon )
{
    if ( !isdefined( self ) || !isdefined( weapon ) || weapon == level.weaponNone )
        return;
    self GiveStartAmmo( weapon );
}

function tod_weapon_is_packed( player, weapon )
{
    if ( !isdefined( weapon ) || weapon == level.weaponNone || !isdefined( weapon.name ) )
        return false;
    if ( tod_classes::is_class_primary( player, weapon ) )
        return tod_classes::pap_tier( player, weapon ) > 0;
    if ( zm_weapons::is_weapon_upgraded( weapon ) )
        return true;
    return ( tod_classes::is_class_secondary( player, weapon ) && IsSubStr( weapon.name, "_up" ) );
}

// Is there an UN-packed class sidearm in the inventory that the stock lane
// would sell an upgrade for? Drives the "sidearm can still be packed" line.
function tod_sidearm_packable( player )
{
    weapons = player GetWeaponsListPrimaries();
    foreach ( w in weapons )
    {
        if ( !isdefined( w ) || !isdefined( w.name ) )
            continue;
        if ( !tod_classes::is_class_secondary( player, w ) )
            continue;
        if ( IsSubStr( w.name, "_up" ) || zm_utility::is_offhand_weapon( w ) )
            continue;
        return zm_weapons::can_upgrade_weapon( w );
    }
    return false;
}

// Is the class primary still un-packed? The mirror line, shown when the packed
// thing in hand is the sidearm.
function tod_primary_packable( player )
{
    weapons = player GetWeaponsListPrimaries();
    foreach ( w in weapons )
    {
        if ( !isdefined( w ) || !isdefined( w.name ) )
            continue;
        if ( tod_classes::is_class_primary( player, w ) && tod_classes::pap_tier( player, w ) == 0 )
            return true;
    }
    return false;
}

// self = the player's own unitrigger. Each literal is handed to SetHintString
// DIRECTLY rather than returned through a helper that takes arguments, because
// that is the shape tools/lint_tod_hints.js can count — keep it that way.
function tod_set_packed_hint( player, weapon, b_tiers )
{
    // [tod v17.33] A spire machine with nothing left to sell: PACK III is
    // owned. One more constant string, and it deliberately does NOT point at
    // an altar — there are none on the spire.
    if ( IS_TRUE( b_tiers ) )
    {
        self SetHintString( "^5PACK III^7 - this weapon is fully amplified" );
        return;
    }
    if ( tod_classes::is_class_primary( player, weapon ) )
    {
        if ( tod_sidearm_packable( player ) )
            self SetHintString( "^1ALREADY PACKED^7 - upgrade at the Heavenly Gift Altar / sidearm can still be packed" );
        else
            self SetHintString( "^1ALREADY PACKED^7 - upgrade at the Heavenly Gift Altar" );
        return;
    }
    if ( tod_primary_packable( player ) )
        self SetHintString( "^1ALREADY PACKED^7 - upgrade at the Heavenly Gift Altar / class gun can still be packed" );
    else
        self SetHintString( "^1ALREADY PACKED^7 - upgrade at the Heavenly Gift Altar" );
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
    unitrigger_pap.origin = trig_org + ( 0, 0, TOD_PAP_TRIG_LIFT );   // [tod v16.27] off the floor decals — see the define
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
