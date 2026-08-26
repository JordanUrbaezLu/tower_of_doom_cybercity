// =============================================================================
// _tod_perk_electric_cherry.gsc — Electric Cherry (ported from map 1's FINISHED
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
#using scripts\shared\math_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_perk_electric_cherry;   // call the STOCK cherry tesla-FX functions (real electrocution; pipeline initialised by the entry-script #usings)
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_perks.gsh;

// --- identity ---------------------------------------------------------------
// specialty_combat_efficiency = an UNUSED engine specialty (no stock perk binds
// it; HasPerk/SetPerk work natively). KEEP verbatim — stock name, not a map id.
#define EC_PERK                "specialty_combat_efficiency"
#define EC_ALIAS               "tod_electric_cherry"
#define EC_COST                3000
#define EC_BOTTLE_WEAPON       "zombie_perk_bottle_cherry"   // stock cherry bottle (rides in with the stock module; no new asset)
#define EC_RADIANT_MACHINE     "vending_tod_electric_cherry" // unique radiant name (NOT the stamin-up default — avoids the machine-identity collision)
#define EC_MACHINE_LIGHT_FX    "tod_ec_machine_light"
// The REAL cherry vending model, from [West] Community Perk Collection v2.7
// (external pack, installed in the Mod Tools root — source GDT
// source_data\acc_west_electric_cherry.gdt, installed by map 1). ONE model for
// both power states (the pack's own convention; the powered look is light FX,
// which _tod_perk_lights owns). Force-packed via `xmodel,electric_cherry_model`
// in the .zone (runtime-SetModel assets need the explicit line, map 1 docs/27).
#define EC_OFF_MODEL           "electric_cherry_model"
#define EC_ON_MODEL            "electric_cherry_model"

// --- nova tuning (compile-time; magnitudes hidden in UI per vague-ui rule) ---
#define EC_RADIUS_MIN          64     // full-mag reload = small spark
#define EC_RADIUS_MAX          220    // empty-mag reload = big blast
#define EC_DMG_MIN             1      // full-mag floor
#define EC_TARGET_CAP          8      // max zombies zapped per nova
#define EC_COOLDOWN            6      // seconds between novas
#define EC_KILL_POINTS         40     // points per zombie the nova kills (mirrors stock RELOAD_ATTACK_POINTS)

// Electric burst FX — the map-1-proven, on-disk one-shot spark burst
// (electric/, "_os" = one-shot). Zoned in zm_tower_of_doom.zone.
#define EC_BURST_FX            "electric/fx_elec_sparks_burst_xlg_os"

#precache( "fx", EC_BURST_FX );

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
    zm_perks::register_perk_basic_info( EC_PERK, EC_ALIAS, EC_COST, "Hold ^3[{+activate}]^7 for Electric Cherry [Cost: &&1]", GetWeapon( EC_BOTTLE_WEAPON ) );
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
    self thread ec_reload_watcher();
}

function take_electric_cherry( b_pause, str_perk, str_result )
{
    self notify( "tod_ec_stop" );
}

// ---------------------------------------------------------------------------
// Reload-discharge nova
// ---------------------------------------------------------------------------

// self = player. Fires the nova when the player RELOADS (stock "reload_start"
// event), cooldown-gated so it can't be spammed. Blast scales with clip emptiness.
function ec_reload_watcher()
{
    self endon( "disconnect" );
    self endon( "death" );
    self endon( "tod_ec_stop" );

    self.tod_ec_cooldown = false;

    for ( ;; )
    {
        self waittill( "reload_start" );

        if ( !( self HasPerk( EC_PERK ) ) )           continue;
        if ( IS_TRUE( self.tod_ec_cooldown ) )         continue;

        self ec_nova();

        self.tod_ec_cooldown = true;
        wait EC_COOLDOWN;
        self.tod_ec_cooldown = false;
    }
}

// self = player. The electric discharge: damage + electrocute zombies near the
// player, scaled by how empty the reloaded clip was. Kills route through
// DoDamage -> the zombie death callback -> the points economy (MOD_GRENADE_SPLASH).
function ec_nova()
{
    self endon( "disconnect" );

    // Clip emptiness fraction (FIX for the stock 1/10 stub): 0.0 = empty (max blast), 1.0 = full (min blast).
    w_cur   = self GetCurrentWeapon();
    clip_max = ( isdefined( w_cur ) && isdefined( w_cur.clipSize ) && w_cur.clipSize > 0 ? w_cur.clipSize : 1 );
    clip_cur = self GetWeaponAmmoClip( w_cur );
    frac = clip_cur / clip_max;
    if ( frac > 1.0 ) frac = 1.0;
    if ( frac < 0.0 ) frac = 0.0;

    radius = math::linear_map( frac, 1.0, 0.0, EC_RADIUS_MIN, EC_RADIUS_MAX );

    // Damage: round-scaled so an empty-mag nova one-shots trash at any round (full-mag = floor).
    dmg_max = ( isdefined( level.zombie_health ) && level.zombie_health > EC_DMG_MIN ? level.zombie_health : 1045 );
    dmg = int( math::linear_map( frac, 1.0, 0.0, EC_DMG_MIN, dmg_max ) );

    // GENUINE base-game Electric Cherry discharge: electric_cherry_reload_fx =
    // the REAL on-player reload burst FX from the stock cherry pipeline (the
    // entry-script #usings initialised it, so the clientfields/FX are live and
    // this renders). Sound: the tower's STANDALONE sound zone mutes stock
    // aliases like zmb_cherry_explode (map 1 lesson), so play the map's own
    // audible zap wav — acc_phantom_zap is ALREADY SHIPPED by the tower in
    // sound/aliases/tod_bosses.csv (same wav as map 1; alias name kept verbatim).
    self thread zm_perk_electric_cherry::electric_cherry_reload_fx( frac );
    self PlaySound( "acc_phantom_zap" );

    v_origin = self.origin;
    r_sq = radius * radius;
    a_zombies = GetAITeamArray( level.zombie_team );
    hit = 0;

    for ( i = 0; i < a_zombies.size; i++ )
    {
        z = a_zombies[ i ];
        if ( !IsAlive( z ) )                                       continue;
        if ( DistanceSquared( z.origin, v_origin ) > r_sq )       continue;
        if ( hit >= EC_TARGET_CAP )                                break;
        hit++;

        b_lethal = ( isdefined( z.health ) && z.health <= dmg );

        // REAL stock Electric Cherry tesla FX. Lethal hits get the full
        // electrocution death; survivors get the genuine shock-eyes + a ~4s
        // freeze — exactly like buying stock Electric Cherry.
        if ( b_lethal )
        {
            z thread zm_perk_electric_cherry::electric_cherry_death_fx();   // real tesla electrocution death
        }
        else
        {
            // BOSS STUN GUARD (map 1 crash-hunt 2026-06-27): never freeze a
            // boss — electric_cherry_stun sets ignoreall ~4s and a boss is
            // always non-lethal here, so an unguarded stun soft-locks boss
            // rounds. BOSS THREAD-HANG GUARD (map 1 2026-07-06): stock
            // electric_cherry_shock_fx blocks on waittill("stun_fx_end"),
            // which only the (skipped) stun fires — so run BOTH only for
            // non-bosses. Tower boss filter idiom = _tod_bosses.gsc:329
            // (is_boss = Panzer pack, acc_is_boss / acc_is_mini_boss =
            // vendored-pack field names, kept verbatim on this map).
            if ( !IS_TRUE( z.is_boss ) && !IS_TRUE( z.acc_is_boss ) && !IS_TRUE( z.acc_is_mini_boss ) )
            {
                z thread zm_perk_electric_cherry::electric_cherry_stun();    // real ~4s freeze (ignoreall)
                z thread zm_perk_electric_cherry::electric_cherry_shock_fx();    // real shock-eyes FX
            }
        }

        z DoDamage( dmg, v_origin, self, self, 0, "MOD_GRENADE_SPLASH" );

        if ( b_lethal )
            self zm_score::add_to_player_score( EC_KILL_POINTS );
    }

    /# println( "[tod] electric cherry nova: frac " + frac + " radius " + int( radius ) + " dmg " + dmg + " hit " + hit ); #/
}
