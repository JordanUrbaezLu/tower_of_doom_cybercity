// =============================================================================
// _tod_perk_electric_cherry.gsc — DEATH PERCEPTION since v13.19 (user
// 2026-08-29: "replace elemental pop with depth perception... I swear this
// implementation should exist already... I dont want to reinvent the wheel")
// — the CW/BO6 awareness perk: holders see THE HORDE THROUGH WALLS as green
// keylines. Effect PORTED from the sibling map's SHIPPED module
// (tower_of_doom_II_hellbound _tod_perk_death_perception.gsc/.csc, the
// Wunderfizz perk the user remembered): T7's stock duplicate_render
// "player_keyline" offscreen filter (registered by stock _zm.csc:212,
// material mc/hud_keyline_zm_player, DR_CULL_NEVER = draws through walls),
// driven by a private clientfield pair —
//   "tod_dp_owner" (toplayer, int): the local ownership gate, flipped on
//   buy/loss. "tod_dp_ping" (actor, counter): a 2s pulse on every ENEMY (the
//   horde only until v19.72, see below); counter callbacks re-fire on EVERY
//   increment, so late buys, perk loss and fresh spawns all converge within
//   one pulse.
//
// v19.72 (2026-10-03, user: "Can death perception be buffed to all enemies not
// just zombies?") — EVERY ENEMY. The pulse used to skip the boss triad
// (is_boss / acc_is_boss / acc_is_mini_boss), and that triad is every elite
// this map spawns: the Panzer (the Warden King and the spire Wardens are
// Panzers), the Rogue Protector, the hellhound and the Reaver. Armored
// sprinters were already in (promoted horde, no triad). Elites now ride the
// same pulse behind gates of their own, dp_elite_hold(): seen on an EARLIER
// pulse (they are direct SpawnActors, and a counter field throws on an
// entity's spawn frame - the v17.92 rule in the loop), not mid drop-in
// (tod_dropping: Ghosted at the landing point while the proxy falls), and for
// a hound, not still hidden (ignoreme until hound_spawn_in's reveal - HOUNDS
// ONLY: the Protector's companion archetype sets ignoreme for life). The
// client half now clears an outline the moment its enemy dies: a dead
// Protector / hound / Reaver stays an Actor entity for its corpse linger and
// would otherwise glow through walls. Logs [TOD_DP] (tod_dev) and [TOD_DP_C]
// (client, developer runs).
// Client half = the NEW _tod_perk_electric_cherry.csc (lineage name kept,
// same doctrine as below). Machine = the SATPerks
// t10_zm_machine_death_perception(_on) pair (payload installed at
// <root>\_custom\_wetegg\models\sat\ like the other nine). Cost 1500 (user).
// The v13.4-v13.18 ELEMENTAL POP effect is fully retired below; its
// historical header follows.
//
// (was v13.4:) ELEMENTAL POP (user 2026-08-28:
// "Can we take out electric cherry and just add elemental pop?") — random
// elemental proc (shock/fire/frost) on bullet hits, replacing the reload-nova.
// FILENAME AND NAMESPACE KEEP THE CHERRY LINEAGE on purpose: the zone line,
// radiant names and specialty wiring all reference them, and renaming buys
// nothing a player can see. Historical header follows.
// (was:) Electric Cherry (ported from map 1's FINISHED
// _acc_perk_electric_cherry.gsc; the tower has no PhD Flopper, so this is the
// map's only cherry).
//
// A from-scratch perk registered on the unused engine specialty
// `specialty_combat_efficiency` (shipped Elemental Pop precedent, map 1 docs/16 —
// HasPerk/SetPerk/HUD all work natively on it). The STOCK cherry specialty
// (`specialty_electriccherry`) is untouched — but the stock module
// scripts\zm\_zm_perk_electric_cherry MUST still be #using'd from BOTH entry
// scripts: this module calls its public tesla-FX functions (reload burst,
// electrocution death, stun, shock-eyes), and those only render because the
// stock pipeline's clientfields are initialised. Map 1 got that init via PhD's
// pipeline hijack; the tower gets it via the plain entry-script #usings.
//
// Registration mirrors the stock 6-call chain (cleanest example
// _zm_perk_deadshot.gsc): register_perk_basic_info / precache / machine /
// threads / host_migration_params / clientfields.
//
// ⚠️ CORRECTED 2026-08-25. This paragraph used to say "We DELIBERATELY SKIP
// register_perk_clientfields … no per-perk hudItems.perks.* field is needed
// (stock HUD shows the perk natively off the specialty)". THAT WAS WRONG and it
// cost the perk its HUD icon: `zm_perks::set_perk_clientfield` (_zm_perks.gsc
// :968) is a NO-OP unless the perk registered a `clientfield_set`, and
// AetheriumPerksContainer.lua reads hudItems.perks.<clientFieldName> and never
// looks at the specialty at all. The clientfields ARE registered now — see the
// block above ec_set_clientfield for why the field is borrowed from retired
// Mule Kick rather than newly allocated (the clientuimodel pool really is tight,
// which is the one true half of the old claim). No
// .csc either — the nova FX is one-shot SERVER PlayFX via the stock cherry
// functions (that path renders; the "server PlayFX doesn't render" caveat is
// only for LOOPING machine glow, which _tod_perk_lights owns).
//
// ABILITY (lifted + adapted from stock _zm_perk_electric_cherry.gsc::
// electric_cherry_reload_attack, L353-492): RELOADING discharges an electric
// nova that electrocutes nearby zombies. The blast SCALES with how empty the
// clip was (the cherry signature) — reloading a near-empty mag = big blast,
// full mag = a spark. The stock clip-fraction stub (hardcoded 1/10, L383-4) is
// FIXED by reading GetWeaponAmmoClip + weapon.clipSize for real. Damage is
// round-scaled (one-shots trash at any round when the mag is empty). A
// cooldown stops reload-spam. NO laststand-boom.
//
// PORT DELTAS from map 1 (2026-08-20):
//   - Mega Bottles ("Power Surge" tier) STRIPPED — the tower has no Mega
//     system. Base tuning only.
//   - acc_utility::log STRIPPED — dev-block println instead (no tod logger).
//   - Live-tune dvars STRIPPED — compile-time constants only (tower doctrine:
//     no dev dvars, CLAUDE.md).
//   - Boss-stun guard reads is_boss / acc_is_boss / acc_is_mini_boss — the
//     acc_* field names are KEPT verbatim: the tower's vendored boss packs and
//     _tod_bosses.gsc set/filter on exactly those fields.
//
// REGISTER_SYSTEM autoexec runs the registration at the correct pre-load phase
// (same as stock perks); wired by the #using in zm_tower_of_doom.gsc + the
// scriptparsetree line in the .zone. No init call in main() needed.
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;   // set_player_uimodel (the HUD icon)

#using scripts\shared\array_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// (v13.19: the EP-effect usings — stock cherry tesla FX, _zm_spawner damage
// callback, _zm_score, _tod_zombie_speed frost lane, zombie_utility, math —
// all retired with the effect. The entry scripts keep their own stock-cherry
// #usings; harmless and other systems reference that pipeline.)
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_utility;
#using scripts\shared\callbacks_shared;          // v17.99 — on_connect( &dp_register_stats )
#using scripts\zm\gametypes\_globallogic_score;  // v17.99 — initPersStat (the same pair _zm_perk_wisp_tea.gsc carries)

#insert scripts\zm\_zm_perks.gsh;

// --- identity ---------------------------------------------------------------
// specialty_combat_efficiency = an UNUSED engine specialty (no stock perk binds
// it; HasPerk/SetPerk work natively). KEEP verbatim — stock name, not a map id.
#define EC_PERK                "specialty_combat_efficiency"
#define EC_ALIAS               "tod_electric_cherry"
#define EC_COST                2000   // 3000 -> 2000 (2026-08-27) -> 1500 (2026-08-29) -> 2000 (user 2026-08-30; a 200 went in first from a mistyped ask and was corrected within the hour). LOCKSTEP: the DEATH PERCEPTION cost row in AetheriumPerks.lua.
#define EC_BOTTLE_WEAPON       "zombie_perk_bottle_cherry"   // stock cherry bottle (rides in with the stock module; no new asset)
#define EC_RADIANT_MACHINE     "vending_tod_electric_cherry" // unique radiant name (NOT the stamin-up default — avoids the machine-identity collision)
#define EC_MACHINE_LIGHT_FX    "tod_ec_machine_light"
// v13.3 — ELEMENTAL POP (BO7/BO6 machine migration; user pick — no modern
// Cherry mesh exists and the electric-soda cabinet is the theme match).
// Replaces the [West] pack's electric_cherry_model, which had ONE mesh for
// both states; the t10 pair has a real lit _on twin, so stock's own
// off->on SetModel at power (machine_assets lane, _zm_perks.gsc:129/:140)
// now shows a visible delta. These defines must agree with
// _tod_perk_lights::bo7_off_models — that pass overrides machine_assets for
// the whole roster AFTER every precache wrote its entry, so the two only
// disagree for a harmless init window. Force-packed via the .zone's
// `xmodel,t10_zm_machine_death_perception(_on)` lines (runtime-SetModel assets
// need the explicit line, map 1 docs/27; the old
// `xmodel,electric_cherry_model` line stays for the retired mesh's history).
#define EC_OFF_MODEL           "t10_zm_machine_death_perception"      // v13.19 (was elemental_pop)
#define EC_ON_MODEL            "t10_zm_machine_death_perception_on"

// --- DEATH PERCEPTION tuning (v13.19) ---------------------------------------
#define DP_PULSE_SECS          2      // outline refresh cadence (hellbound-proven)
#define DP_REV                 "all_enemies_1"   // v19.72 - the [TOD_DP] LOOP_START marker

#namespace tod_perk_electric_cherry;

// REGISTER_SYSTEM autoexec — runs __init__ at the system-init load phase
// (before perk_machine_spawn_init iterates the zm_perk_machine structs).
REGISTER_SYSTEM( "tod_perk_electric_cherry", &__init__, undefined )

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

function __init__()
{
    // The 6-call chain (minus clientfields — skipped on purpose, see header).
    // Hint recipe (map 1 buyable-UI audit 2026-07-10): [{+activate}] = the use
    // key, &&1 = the COST substitution stock SetHintString(hint,cost) fills.
    zm_perks::register_perk_basic_info( EC_PERK, EC_ALIAS, EC_COST, "Hold ^3[{+activate}]^7 for Death Perception [Cost: &&1]", GetWeapon( EC_BOTTLE_WEAPON ) );
    // DEATH PERCEPTION's private outline pair — the NEW .csc registers the
    // EXACT same two fields with the drawing callbacks (lockstep pairs in
    // both VMs; zm_cwpap's 8-field pair is this map's shipped precedent).
    clientfield::register( "toplayer", "tod_dp_owner", VERSION_SHIP, 1, "int" );
    clientfield::register( "actor",    "tod_dp_ping",  VERSION_SHIP, 1, "counter" );
    zm_perks::register_perk_precache_func( EC_PERK, &ec_precache );
    zm_perks::register_perk_machine( EC_PERK, &ec_machine_setup );
    zm_perks::register_perk_threads( EC_PERK, &give_electric_cherry, &take_electric_cherry );
    // THE HUD ICON (user 2026-08-25: "electric cherry icon doesnt show up in HUD
    // when you get it"). See the long note above ec_set_clientfield for why this
    // borrows a dead stock field instead of registering a new one.
    zm_perks::register_perk_clientfields( EC_PERK, &ec_register_clientfield, &ec_set_clientfield );
    // host_migration_params sets .radiant_machine_name + .machine_light_effect,
    // which (with .alias) is what makes stock auto-thread perk_machine_think
    // for this machine (_zm_perks.gsc:98-100).
    zm_perks::register_perk_host_migration_params( EC_PERK, EC_RADIANT_MACHINE, EC_MACHINE_LIGHT_FX );
    // v17.99 — THE BUY THREW IN STOCK'S STAT LANE. give_perk (_zm_perks.gsc:762)
    // runs zm_stats::increment_client_stat( perk + "_drank" ) -> incPersStat ->
    // `self.pers[ stat ] += 1`, and stock initPersStat's only its own perks'
    // _drank slots (armorvest/quickrevive/fastreload/staminup/doubletap2/
    // widowswine/deadshot/electriccherry). combat_efficiency is not among them,
    // so every Death Perception buy threw `pair 'undefined' and '1'` and
    // give_perk never reached its tail: perk_history, perks_active, the
    // "perk_acquired" notify and perk_think( perk ). PhD rides electriccherry
    // (initialised); Wisp Tea's module registers its own on connect — this is
    // that exact recipe (_zm_perk_wisp_tea.gsc::registerStats). initPersStat is
    // idempotent, so ordering against stock's player_stats_init is irrelevant.
    callback::on_connect( &dp_register_stats );
}

function dp_register_stats()
{
    self globallogic_score::initPersStat( EC_PERK + "_drank", false );
}

// ---------------------------------------------------------------------------
// THE HUD ICON, AND WHY IT BORROWS MULE KICK'S DEAD CLIENTFIELD
//
// The bug: buying Electric Cherry lit no icon. The header of this file used to
// claim the "stock HUD shows the perk natively off the specialty" and skipped
// register_perk_clientfields to save clientuimodel bits. That claim is wrong.
// `zm_perks::set_perk_clientfield` (_zm_perks.gsc:968) is a NO-OP unless the
// perk registered a `clientfield_set` — so nothing ever drove the row, and
// AetheriumPerksContainer.lua keys its whole display off
// `hudItems.perks.<clientFieldName>`, which nothing was writing.
//
// WHY NOT JUST REGISTER A NEW FIELD. `clientuimodel` fields must be registered
// in BOTH VMs, in the same order, or the bit layout desyncs — and this map has a
// documented boot ceiling on that pool (CLAUDE.md: 61 bits, PROVEN, APPEND
// ONLY). We sit at 15 fields / 58 bits. A new 2-bit field would fit at 60, but
// it would spend the last of the proven headroom and add a matched-registration
// ordering risk, for a cosmetic icon.
//
// WHAT WE USE INSTEAD. `hudItems.perks.additional_primary_weapon` is MULE KICK's
// field. It is registered by `_zm_perk_additionalprimaryweapon`, which this map
// #uses, in BOTH VMs (.gsc:79 and .csc:47) — so it is already allocated, already
// matched, and costs nothing new. And it is DEAD: Mule Kick was retired from
// this map on 2026-08-25 when PhD Flopper replaced it, so no machine sells it
// and nothing else ever writes that field.
//
// The Lua row's `clientFieldName` must match this exactly — the container reads
// the field NAME and never looks at `specialty`.
#define EC_HUD_CLIENTFIELD  "hudItems.perks.additional_primary_weapon"

// Deliberately EMPTY. The perk framework CALLS clientfield_register for every
// registered perk (_zm_perks.gsc:1638-1640), and the field above is already
// registered by the stock Mule Kick module — registering it twice is a
// duplicate-clientfield error, which is a boot failure, not a warning.
function ec_register_clientfield()
{
}

function ec_set_clientfield( state )
{
    self clientfield::set_player_uimodel( EC_HUD_CLIENTFIELD, state );
}

// Perk precache callback — register the machine light FX + the machine model assets.
function ec_precache()
{
    // Machine light: a stock cola light FX (must be a defined level._effect key
    // for the perk_machine_think auto-run gate; the actual machine GLOW is
    // driven client-side by _tod_perk_lights, but the gate needs this defined).
    level._effect[ EC_MACHINE_LIGHT_FX ] = "_t6/misc/fx_zombie_cola_revive_on";

    level.machine_assets[ EC_PERK ] = SpawnStruct();
    level.machine_assets[ EC_PERK ].weapon    = GetWeapon( EC_BOTTLE_WEAPON );
    // perk_machine_think SetModels this at runtime over the .map struct's model
    // — hence the .zone force-pack line (see EC_OFF_MODEL comment).
    level.machine_assets[ EC_PERK ].off_model = EC_OFF_MODEL;
    level.machine_assets[ EC_PERK ].on_model  = EC_ON_MODEL;
}

// Machine setup callback (dispatched by perk_machine_spawn_init,
// _zm_perks.gsc:1599). MUST set UNIQUE radiant names or stock's hardcoded
// stamin-up default captures our machine (the machine-identity collision —
// map 1 lesson). Sig = ( use_trigger, perk_machine, bump_trigger, collision ).
function ec_machine_setup( use_trigger, perk_machine, bump_trigger, collision )
{
    use_trigger.script_string = "tod_electric_cherry_perk";
    use_trigger.target        = EC_RADIANT_MACHINE;
    perk_machine.script_string = "tod_electric_cherry_vending";
    perk_machine.targetname    = EC_RADIANT_MACHINE;
    if ( isdefined( bump_trigger ) )
        bump_trigger.script_string = "tod_electric_cherry_vending";
}

// ---------------------------------------------------------------------------
// Give / take (self = player)
// ---------------------------------------------------------------------------

function give_electric_cherry()
{
    // (Function names keep the ec_ lineage — the perk framework and radiant
    // names reference them; the PLAYER-facing name is Death Perception.)
    self clientfield::set_to_player( "tod_dp_owner", 1 );
    started = false;
    if ( !IS_TRUE( level.tod_dp_loop ) )
    {
        level.tod_dp_loop = true;
        level thread dp_pulse_loop();
        started = true;
    }
    if ( IS_TRUE( level.tod_dev ) )
        dp_log( "GIVE player=" + dp_str( self.name ) + " loop_started=" + started );
}

function take_electric_cherry( b_pause, str_perk, str_result )
{
    self clientfield::set_to_player( "tod_dp_owner", 0 );
    if ( IS_TRUE( level.tod_dev ) )
        dp_log( "TAKE player=" + dp_str( self.name ) + " pause=" + dp_str( b_pause ) + " result=" + dp_str( str_result ) );
}

// ---------------------------------------------------------------------------
// DEATH PERCEPTION — the outline pulse (v13.19, hellbound port; every enemy
// since v19.72)
// ---------------------------------------------------------------------------

// One level-wide pulse: every enemy's counter ticks every DP_PULSE_SECS. The
// CSC callback fires per client per tick and applies/clears the keyline
// against the LOCAL ownership gate — an ex-holder's outlines clear on the
// next pulse, a fresh spawn appears within one, and (v19.72, client half) an
// outline clears when its enemy dies.
//
// TWO LANES, ONE PING. The horde lane is unchanged since v17.92. The ELITE
// lane (v19.72) is everything carrying the boss triad or a tod_boss_kind —
// the exact set this loop used to skip — and dp_elite_hold() says when one is
// ready. Nothing here reads or writes gameplay state: the only writes are the
// counter and three dp_* bookkeeping fields on the actor.
function dp_pulse_loop()
{
    level endon( "end_game" );

    dp_log( "LOOP_START rev=" + DP_REV + " pulse_s=" + DP_PULSE_SECS );
    last_sig = "";
    for ( ;; )
    {
        wait DP_PULSE_SECS;

        team = "axis";
        if ( isdefined( level.zombie_team ) )
            team = level.zombie_team;
        ais = GetAITeamArray( team );
        horde = 0;
        elites = 0;
        held_new = 0;
        held_drop = 0;
        held_hidden = 0;
        for ( i = 0; i < ais.size; i++ )
        {
            z = ais[ i ];
            if ( !isdefined( z ) || !IsAlive( z ) )
                continue;

            // THE ELITE LANE (v19.72): Panzer (+ the Warden King, + the spire
            // Wardens), Rogue Protector, hellhound, Reaver.
            if ( dp_is_elite( z ) )
            {
                hold = dp_elite_hold( z );
                if ( hold != "" )
                {
                    if ( hold == "new" )
                        held_new++;
                    else if ( hold == "dropping" )
                        held_drop++;
                    else
                        held_hidden++;
                    continue;
                }
                z clientfield::increment( "tod_dp_ping" );
                elites++;
                if ( !IS_TRUE( z.tod_dp_lit ) )
                {
                    z.tod_dp_lit = true;
                    if ( IS_TRUE( level.tod_dev ) )
                        dp_log( "ELITE_ON kind=" + dp_kind( z ) + " ent=" + z GetEntityNumber() + " waited_ms=" + ( GetTime() - z.tod_dp_seen_ms ) );
                }
                continue;
            }

            // THE HORDE LANE (incl. armored sprinters — promoted horde, no triad).
            // v17.92 — a "counter" clientfield cannot be incremented on the frame an
            // entity is spawned (the engine throws, by name: 15 times in one match).
            // A zombie that has not finished emerging is at best a frame old and
            // is not worth pinging anyway.
            if ( !IS_TRUE( z.completed_emerging_into_playable_area ) )
                continue;
            z clientfield::increment( "tod_dp_ping" );
            horde++;
        }

        // Change-gated on the elite picture (the horde count moves every pulse).
        if ( IS_TRUE( level.tod_dev ) )
        {
            sig = "" + elites + "/" + held_new + "/" + held_drop + "/" + held_hidden;
            if ( sig != last_sig )
            {
                last_sig = sig;
                dp_log( "PULSE elites=" + elites + " held_new=" + held_new + " held_dropping=" + held_drop + " held_hidden=" + held_hidden + " horde=" + horde );
            }
        }
    }
}

// The ELITE set is the one this loop skipped until v19.72: the boss triad every
// elite spawner stamps on its spawn frame (_tod_bosses Panzer + Protector,
// _tod_hellhounds, _tod_reaver), or a tod_boss_kind (_tod_stray's own elite
// test reads the same pair).
function dp_is_elite( z )
{
    return ( IS_TRUE( z.is_boss ) || IS_TRUE( z.acc_is_boss ) || IS_TRUE( z.acc_is_mini_boss ) || isdefined( z.tod_boss_kind ) );
}

// "" = outline it this pulse; otherwise WHY it waits. Three holds, in order:
//
//   "new"      — the first pulse that SEES an elite only stamps it. Elites are
//                direct SpawnActors placed at any moment, so this pulse may be
//                the elite's spawn frame, and a counter clientfield throws
//                there (v17.92). The horde lane's completed_emerging test does
//                NOT cover this: the Reaver sets that flag on its spawn frame.
//                Costs at most one pulse (2 s) after the reveal.
//   "dropping" — drop_in (Panzer, Protector, the King, the Wardens) holds the
//                real actor Ghosted at the landing point while a proxy falls.
//                An outline there would show him standing on his mark before
//                he has landed. A stuck-relocation drop sets the same flag.
//   "hidden"   — a hellhound is Hidden + ignoreme until hound_spawn_in's
//                reveal. HOUNDS ONLY: archetype_zod_companion sets ignoreme on
//                the Rogue Protector for life, so a general ignoreme test would
//                hide every Protector forever.
function dp_elite_hold( z )
{
    if ( !isdefined( z.tod_dp_seen_ms ) )
    {
        z.tod_dp_seen_ms = GetTime();
        return "new";
    }
    if ( IS_TRUE( z.tod_dropping ) )
        return "dropping";
    if ( isdefined( z.tod_boss_kind ) && z.tod_boss_kind == "hellhound" && IS_TRUE( z.ignoreme ) )
        return "hidden";
    return "";
}

function dp_kind( z )
{
    if ( IS_TRUE( z.tod_king ) )
        return "king";
    if ( isdefined( z.tod_boss_kind ) )
        return z.tod_boss_kind;
    return "elite";
}

function dp_str( v )
{
    if ( !isdefined( v ) )
        return "undef";
    return "" + v;
}

// Dev-only, state changes only (GIVE / TAKE / LOOP_START / ELITE_ON once per
// elite / PULSE when the elite picture changes). The line is assembled outside
// the developer block, PrintLn stays inside it (CLAUDE.md dev-log rule).
function dp_log( msg )
{
    if ( !IS_TRUE( level.tod_dev ) )
        return;
    line = "[TOD_DP] ms=" + GetTime() + " " + msg;
    /#
    PrintLn( line );
    #/
}
