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
//   buy/loss. "tod_dp_ping" (actor, counter): a 2s pulse on every trash
//   zombie; counter callbacks re-fire on EVERY increment, so late buys, perk
//   loss and fresh spawns all converge within one pulse.
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

#insert scripts\zm\_zm_perks.gsh;

// --- identity ---------------------------------------------------------------
// specialty_combat_efficiency = an UNUSED engine specialty (no stock perk binds
// it; HasPerk/SetPerk work natively). KEEP verbatim — stock name, not a map id.
#define EC_PERK                "specialty_combat_efficiency"
#define EC_ALIAS               "tod_electric_cherry"
#define EC_COST                1500   // 3000 -> 2000 (2026-08-27) -> 1500 (Death Perception, user 2026-08-29)
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
#define DP_PULSE_SECS          2      // horde-outline refresh cadence (hellbound-proven)

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
    if ( !IS_TRUE( level.tod_dp_loop ) )
    {
        level.tod_dp_loop = true;
        level thread dp_pulse_loop();
    }
}

function take_electric_cherry( b_pause, str_perk, str_result )
{
    self clientfield::set_to_player( "tod_dp_owner", 0 );
}

// ---------------------------------------------------------------------------
// DEATH PERCEPTION — the horde-outline pulse (v13.19, hellbound port)
// ---------------------------------------------------------------------------

// One level-wide pulse: every trash zombie's counter ticks every
// DP_PULSE_SECS. The CSC callback fires per client per tick and
// applies/clears the keyline against the LOCAL ownership gate — an
// ex-holder's outlines clear on the next pulse, a fresh spawn appears within
// one. Boss triad excluded (bosses own their own presentation; also keeps
// the pulse cheap) — the same acc_* guard trio the EP effect shipped with
// (this map's vendored bosses set exactly these fields).
function dp_pulse_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        wait DP_PULSE_SECS;

        team = "axis";
        if ( isdefined( level.zombie_team ) )
            team = level.zombie_team;
        zombies = GetAITeamArray( team );
        pinged = 0;
        for ( i = 0; i < zombies.size; i++ )
        {
            z = zombies[ i ];
            if ( !isdefined( z ) || !IsAlive( z ) )
                continue;
            if ( IS_TRUE( z.is_boss ) || IS_TRUE( z.acc_is_boss ) || IS_TRUE( z.acc_is_mini_boss ) )
                continue;
            z clientfield::increment( "tod_dp_ping" );
            pinged++;
        }
    }
}
