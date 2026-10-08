// =============================================================================
// _tod_spire.gsc — THE ENDLESS SPIRE (docs/44, user 2026-08-29: "once you beat
// the game you will get all perks and all power ups for your class maxed out.
// And you can continue playing" + "a teleporter in the crown room that
// activates once you beat the map ... a tower that goes up 100 floors ...
// Once players teleport they cant go back"; v17.69 2026-09-05: "make the
// endless spire tower go to floor 70 instead of 100" — SEVENTY laps, SEVEN
// trials, THE TOP one flight above the last hall, docs/105).
//
// THE FLOW. The finale's win no longer auto-departs: _tod_finale's choice
// phase offers EXTRACT (the existing ending) or ASCEND — this module owns the
// ASCEND half and everything after it. The two halves talk ONLY through level
// notifies ("tod_choice_begin" / "tod_ascend" / "tod_extract"), deliberately:
// _tod_finale does not #using this file and this file does not #using
// _tod_finale, so there is no import cycle and either module degrades to a
// no-op without the other (finale falls back to auto-depart when
// level.tod_spire_ready is unset).
//
// THE SEQUENCE on ascend:
//   1. the dais teleporter fires (the _tod_teleport recipe: charge -> flash ->
//      warp) and EVERYONE goes — living on the arrival ring, downed dragged
//      along like gather_to_centre does at the seal. One-way by construction:
//      no return pad exists.
//   2. THE TOWER DIES BEHIND YOU — the teardown deletes the old world's
//      script-spawned entity load (door slabs + triggers, teleporter triggers
//      + beams, the finale's props). This is an ENTITY BUDGET, not fiction:
//      the ~1024-slot gentity table is the spire's binding constraint
//      (docs/44 §4, map 1's G_Spawn crash) and the freed slots are what the
//      spire's own vendors spend.
//   3. THE GRANT (v16.36; v16.80 dropped the PERK SLOTS gift with the
//      domain): EVERY PERK the map sells —
//      PERMANENTLY (re-given on every revive and spawn for the rest of the
//      run), full ammo, full health. NOTHING ELSE: the party keeps exactly
//      the build it beat the tower with; a WON TRIAL deals the upgrade
//      cards (the tower's own round-event deal) and is the spire's only
//      upgrade source. (v14.0-v16.35 granted T3 PaP'd + every domain maxed.)
//   4. THE SWAP: music -> the spire loop (single band row; the Panzer
//      override rides unchanged), perk machines -> RETIRED (v17.56: parked
//      out of the world by the scatter; the perks are perma), PaP vendors + crates ->
//      the hubs, spawn pacing -> hot (read by _tod_endless_rounds).
//   5. THE CLIMB: 70 doors (100 until v17.69), sequential — so
//      exactly ONE door has live buy triggers at any moment; crates ride a
//      player-position window. Both are the lazy-entity discipline the
//      budget demands.
//   6. THE END: wipe -> the "THE CLIMB ENDS HERE" screen (they beat the game;
//      they fall as sovereigns) — or the SUMMIT EXTRACTION at the top (floor 70's roof)
//      (7500, the roof door's price): the chosen ending, "YOU CONQUERED THE
//      SPIRE".
//
// Geometry + anchors ride in from GENERATED _tod_spire_data.gsc (the
// door-data no-drift contract). The spire brushes themselves are behind the
// generator's SPIRE_ENABLED flag — this module NO-OPS (init returns) when the
// door slabs are absent, so script and geometry can ship independently.
// =============================================================================

#using scripts\codescripts\struct;        // v19.76 — the respawn groups (summit_respawn_only)
#using scripts\shared\callbacks_shared;   // on_spawned (v16.36 — the perma-perk keeper for respawns + late joiners)
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm;             // get_zombie_count_for_round (v16.9 — the ascension-round budget clamp; stock module, no cycle)
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_powerups;    // specific_powerup_drop (v16.15 — the trial win's Max Ammo)
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\shared\ai\zombie_utility;   // get_current_zombie_count / get_current_actor_count (the v15 round-stall probe)
#using scripts\shared\ai\mechz;              // v18.75 — MechzBehavior::mechzGoBerserk (the King's rampage rage; the vendored Panzer pack already imports it)
#using scripts\shared\ai\systems\blackboard; // v18.75 — SetBlackBoardAttribute (the King's rampage sprint)
#using scripts\zm\zm_tower_of_doom\_tod_zombie_speed;   // v18.96 — slow_elite (the King's phase stagger; that module imports only shared/ai + callbacks, no cycle)

#using scripts\zm\zm_tower_of_doom\_tod_spire_data;
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;
#using scripts\zm\zm_tower_of_doom\_tod_doors;         // door_price (one pricing rule map-wide)
// v14.31 — spawn_panzer for the door honour guard. SAFE: _tod_bosses does NOT
// #using this module (verified), so this is a one-way edge, not a cycle.
#using scripts\zm\zm_tower_of_doom\_tod_bosses;
#using scripts\zm\zm_tower_of_doom\_tod_teleport;      // pad assembly + fx recipe (proven)
#using scripts\zm\zm_tower_of_doom\_tod_perk_scatter;  // retire_all (v17.56) + derez/sound hosts
#using scripts\zm\zm_tower_of_doom\_tod_rocket;         // v19.68r THE ROCKETS: ride_spire, the ascend ship's flight + crash (docs/170)
#using scripts\zm\zm_tower_of_doom\_tod_perk_lights;   // set_glow (the aura clientfield)
#using scripts\zm\zm_tower_of_doom\_tod_atmosphere;    // channel_play / add_music_band
#using scripts\zm\zm_tower_of_doom\_tod_upgrades;      // run_upgrade_event (the trial deal, v16.36); the PERK SLOTS gift and its _tod_upgrade_ui sync went with the domain (v16.80)
#using scripts\zm\zm_tower_of_doom\_tod_classes;       // (no live call since v16.36 — the T3/PaP grant is gone; the import stays for a future lane that needs tier())
#using scripts\zm\zm_tower_of_doom\_tod_powerups;      // breather_pap_place (the hub vendors)
#using scripts\zm\zm_tower_of_doom\_tod_ammo_crate;    // spawn_model/spawn_trigger + use_loop (the arena/hub/shelf crates)
#using scripts\zm\zm_tower_of_doom\_tod_gameover;   // end_screen_push (v19.58, the end-screen lines in the map typeface)
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;    // banner_track (the scoreboard steps banners aside, 2026-09-27)
#using scripts\zm\zm_tower_of_doom\_tod_gauge;         // mark_top_reached (the grant vs the tier floor gate)

#insert scripts\shared\shared.gsh;
#insert scripts\zm\zm_tower_of_doom\_tod_toast.gsh;

// AFTER every #using/#insert — between them kills the compile ("No generated
// data", the map's own dialect trap).
#precache( "material", "tod_choice_banner" );
#precache( "material", "tod_spire_banner" );
#precache( "material", "tod_spire_over_banner" );
#precache( "material", "tod_spire_win_banner" );
#precache( "material", "tod_spire_emblem" );
// v16.25 — THE TRIAL BANNERS, TRIAL I..VII (docs/66 §11; I..X until v17.69,
// 8..10 retired whole: precache, zone lines, GDT, PNGs): tier n draws
// tod_trial_n at the seal (trial_banner). Seven materials, zoned with their
// images. The seven hall names + colours ride in docs/105.
#precache( "material", "tod_trial_1" );
#precache( "material", "tod_trial_2" );
#precache( "material", "tod_trial_3" );
#precache( "material", "tod_trial_4" );
#precache( "material", "tod_trial_5" );
#precache( "material", "tod_trial_6" );
#precache( "material", "tod_trial_7" );
// v16.43 — the WON plate docs/66 §8 owed (files (99).zip): same lane, shown
// at the win by trial_banner( 0, "tod_trial_won" ).
#precache( "material", "tod_trial_won" );
// v17.71 — THE WARDEN KING's plates (docs/106): the arrival banner at the
// summit seal (king_run) and THE KING IS DEAD at his fall (king_win).
#precache( "material", "tod_king_banner" );
#precache( "material", "tod_king_dead" );
// (v19.76 THE KING'S BOSS BAR is fed by _tod_gauge's heartbeat from
// level.tod_king_hp_frac - king_hp_bar below only publishes the fraction.)
// v17.70 THE WARDEN KING's second flame cone (king_flame_fx): the same castle
// flame the .csc plays on his muzzle, on a host linked TOD_KING_FLAME_FWD
// ahead of it — the visual half of "2x flame size and range". Server-side
// looping FX on a host is the proven lane (ambient-fx-server-loop-lane).
#precache( "fx", "dlc1/castle/fx_mech_wpn_flamethrower" );
#precache( "model", "p7_out_mech_spawn_pad_light_green" );   // summit extraction pad (zoned by the finale already)
#precache( "model", "tod_ammo_chest" );                      // shelf/hub crates (zoned by _tod_ammo_crate already; v19.69 Nikolai's chest)
// v16.18 — THE RITUAL BARRIER (user: "typically when you do hold outs there
// is this purple aura where you get blocked off from leaving"): Shadows of
// Evil's ritual-lockdown doorway wall, the wide variant, looping. Zone line
// in zm_tower_of_doom.zone; the fx must be BOTH precached and zoned or it
// silently no-ops (memory: ambient-fx-server-loop-lane).
#precache( "fx", "zombie/fx_ritual_barrier_defend_door_wide_zod_zmb" );
// 2026-10-01: THE HALL BECOMES THE CLOCK (tools/gen_trial_fx.py; trial_fx_start).
// LOCKSTEP: one walls effect per trial_fx_hues() entry.
#precache( "fx", "tod/spire/fx_trial_walls_gold" );
#precache( "fx", "tod/spire/fx_trial_walls_green" );
#precache( "fx", "tod/spire/fx_trial_walls_cyan" );
#precache( "fx", "tod/spire/fx_trial_walls_purple" );
#precache( "fx", "tod/spire/fx_trial_walls_orange" );
#precache( "fx", "tod/spire/fx_trial_walls_white" );
#precache( "fx", "tod/spire/fx_trial_walls_red" );
#precache( "fx", "tod/spire/fx_trial_walls_frenzy" );
#precache( "fx", "tod/spire/fx_trial_frenzy_light" );
#precache( "fx", "tod/spire/fx_trial_win" );
#precache( "fx", "tod/spire/fx_trial_win_light" );
#precache( "fx", "tod/spire/fx_king_countdown" );
#precache( "fx", "tod/spire/fx_king_countdown_light" );

// Hot pacing (docs/44 §6a, user: "aggression picks up ... rounds will fly by
// but zombies just keep coming non stop and quickly"). Read by
// _tod_endless_rounds::tod_spawn_delay while level.tod_spire_active. 0.18 =
// sustained finale pressure (the finale's own phased band is 0.4 -> 0.1);
// tune HERE, nowhere else.
#define TOD_SPIRE_SPAWN_FLOOR     0.18
// The crate window: shelves exist on floors 5+ (hubs excluded); crates
// materialize for floors within this many of any player and de-rez beyond it.
#define TOD_SPIRE_CRATE_WINDOW    3
// aura colour indices (tod_perk_lights::perk_color_index table)
#define TOD_SPIRE_GLOW_RED        1
#define TOD_SPIRE_GLOW_GREEN     2
// THE CLOCK SEAL IS RETIRED (v18.0, user 2026-09-06: "lets remove the timer on
// the doors for the endless spire. We should still restrict the trial floor door
// so they have to defeat the trial. But thats it. The timer slows down the game
// too much"). Was: every door but the first stayed unbuyable for N seconds after
// the previous one opened — v14.31 at 30 s ("you need to stay and fight for a bit
// and cant just run through each door if you have lots of money"), v16.4 at 12.
// The clock is gone; the TRIAL seal is not (trial_seal_window still holds the
// door above every hub until that hub's trial is won, which is the one gate the
// user kept). seal_window() and its "SEALED - hold this floor" literal went with
// the define — retire it whole, or the string is dead weight and the next reader
// has to work out which of two seals is live. seal_active() survives as the
// TRIAL's refusal gate; its clock branch is gone.
//
// WHAT ELSE CHANGES BY ITSELF: the honour guard used to be sized to fit inside
// the seal — four Panzers at TOD_SPIRE_GUARD_STAGGER 3.5 land at 0/3.5/7/10.5 s,
// i.e. the last one arrived just before the door opened. They still spawn on the
// floor just bought, but a party with points can now buy the next door before the
// procession lands and climb away from it. That is the point of the change, not a
// side effect: the pacing lever is the guard and the price now, not a wait.
// THE HONOUR GUARD (v14.31): Panzers per door buy = living players, capped
// here. Doubles as the STANDING cap in door_guard_panzers — a party that
// leaves guards alive gets fewer, never more.
#define TOD_SPIRE_GUARD_MAX       4
// Seconds between guard arrivals. 3.5 mirrors the director's own ~3s drain and
// gives pick_spawn_point's boss-clearance scatter room to place the next one.
#define TOD_SPIRE_GUARD_STAGGER   3.5

// =============================================================================
// THE WARDEN TRIALS (v16.15, user 2026-09-01: "add mini boss fights every
// breather zone and this also means that we should redesign the breather
// zone. The next door should be locked until you defeat the boss round hold
// out which should be 2 minutes. And it should be quite difficult. Already
// harder than the endless spire").
//
// Every hub (floor 10, 20 .. 100) is THE HUB HALL now (v16.19, user
// 2026-09-02: "the hub battle should actually be inside the tower. so every
// 10 floors the center of the tower open up for the battle"): the core
// column stops for one lap and a drum of walls encloses the tower's whole
// cross-section — the hall floor at the hub landing, the hub's own S flight
// climbing inside it, the next lap's flights running round the walls as
// galleries overhead (generator SP_RM_*, anchors in generated
// _tod_spire_data). THE HALL SEALS ITSELF the moment every living player is
// inside it (v16.18, user: "once everyone is in the holdout starts and gets
// locked off from leaving" — a 2 s tell first, and anyone stepping back out
// in that window keeps it open): door n's own slab goes Solid again while
// staying HIDDEN, and the SoE ritual barrier — the purple lockdown wall —
// plays across the doorway in front of it. For TOD_TRIAL_SECS the hall is
// the whole world: WARDENS (Panzers,
// one per player, one more for the frenzy) drop in front of the Warden gate
// and are replaced as they fall, the adds keep the elite roof full, every
// elite spawned inside carries TOD_TRIAL_HP_MULT, and the trickle runs at the
// hottest floor in the map. The next door — and, at the last hub, the summit
// extraction — stays SEALED until the clock runs out.
//
// NO CEILING IS RAISED. TOD_ELITE_ROOF_ALL still bounds what may stand; the
// Wardens merely have FIRST CLAIM on it (level.tod_trial_reserve, read by
// tod_bosses::elites_over_roof), and TOD_ACTOR_LIMIT is untouched. The
// difficulty comes from continuity and containment, not from numbers the
// actor pool cannot pay for.
//
// COPY LOCKSTEP: none left. The frenzy print is the constant "THE FRENZY"
// (v16.25 replaced the old "THIRTY SECONDS" wording, and the note demanding
// they move together outlived the string it guarded by a week — a lockstep
// note for a string that no longer exists sends the next reader hunting).
// =============================================================================
// 70, NOT 60, AND THE REASON IS THE WAV (v17.8, user 2026-09-03: first "the
// trials will now only last 60 seconds", then "make the trial 70 seconds
// instead" once the trial track's length came up). tod_music_trial is 79.5 s,
// so a 60 s trial never reached the last third of it; 70 leaves ~9 s. It is
// NOT pinned to the wav — the track LOOPS, so nothing breaks at any length,
// and this number is free to move for feel alone. Contrast the FINALE, where
// TOD_FINALE_SONG_SECS genuinely is the wav's length and moving it plays the
// ending over the song's second intro.
#define TOD_TRIAL_SECS            70    // the hold-out; was 60 earlier today, 90 before that, 120 originally
// DERIVED, NOT A LITERAL (v17.8). The frenzy has been the LAST THIRD of the
// fight since it was authored (30 of 90), and holding it at a literal while
// the trial length moved would have silently reshaped the fight — at 30 of a
// 60 s trial it is HALF, a difficulty INCREASE inside the change the user
// asked to be 25% easier. This survived two length changes in one evening;
// the third is free. ~23.3 s at 70. The three recipes that set their own
// frenzy_at already derive it from TOD_TRIAL_SECS, so the whole lane follows
// one number now.
#define TOD_TRIAL_FRENZY_SECS     ( TOD_TRIAL_SECS / 3.0 )  // the last third: one more Warden, the adds tick halves
#define TOD_TRIAL_WARDEN_CAP      4     // Wardens standing at once, ever (the honour guard's own cap)
#define TOD_TRIAL_WARDEN_REDROP   6     // seconds a fallen Warden's slot stays empty before the next drops
// THE LADDER. v16.21 set it from the first real run ("toned down about 15% ...
// increase in difficulty about 7% increments"); v17.8 re-set it from the
// second (user 2026-09-03: "the trials are starting off way too hard. They
// should start off about 25% easier. Then build up from there. I think I said
// 8% harder each level").
//
// TWO AXES, BOTH TONED, exactly as v16.21 did it — the tone-down is not an HP
// number, it is a difficulty number, and the adds' cadence is half of what
// makes a hold-out hard. HP x0.75 and the tick x1.25 (a SLOWER tick is easier;
// dividing would have doubled the nerf on one axis and left the other).
//
// WHAT THE LADDER NOW LOOKS LIKE (trial_ladder = STEP^(tier-1)):
//   trial I  x0.956   trial II x1.042   trial V  x1.349   trial VII x1.603
// against the old 1.275 / 1.364 / 1.672 / 2.344. Trial I lands just BELOW 1.0,
// so a first-trial elite is a hair weaker than a plain spire elite — that is
// what "25% easier" arithmetically is from 1.275, not an error, and the ladder
// is back over 1.0 by trial II.
#define TOD_TRIAL_HP_MULT         0.956 // trial I: every elite spawned inside (tod_bosses::boss_hp reads level.tod_trial_hp_mult); 1.275 x0.75, was 1.5 before v16.21
#define TOD_TRIAL_STEP            1.09  // per trial, compounding, on HP and on the adds cadence. 1.1225 -> 1.09 (v18.2, user 2026-09-06: "many people are complaining about how hard the trials get as you continue to go up ... lets make it a bit easier as you continue"). Trial I does not move; the TOP does - trial VII goes x1.911 -> x1.603, and with the same pass -10% on every elite an add in the last trial lands at x1.44 of a plain spire elite instead of x1.91. Was 1.1225 (v17.69, seven trials at the old ten-trial top), 1.08 (v17.8), 1.07 (v16.21)
#define TOD_TRIAL_TICK            5.75  // trial I adds top-up cadence; 4.6 x1.25 (the 25% tone-down on the cadence axis)
#define TOD_TRIAL_FRENZY_TICK     2.875 // held at exactly half TOD_TRIAL_TICK — "the adds tick halves" is the frenzy's whole definition
#define TOD_TRIAL_TICK_MIN        1.5
#define TOD_TRIAL_SPAWN_FLOOR     0.12  // LOCKSTEP with _tod_endless_rounds TOD_SPIRE_TRIAL_SPAWN_FLOOR
#define TOD_TRIAL_WIN_PTS         5000  // team-wide on the win: the next door, a perk re-buy, and change
#define TOD_TRIAL_WIN_PTS_TIER    1500  // + this per trial past the first (v16.26: trial X paid 14000 at 1000/tier; v17.69: seven trials, trial VII pays the same 14000 at 1500/tier — the ladder's risk deserves a ladder's purse)
#define TOD_TRIAL_CLOSE_SECS      2     // everyone-in -> the ring closes; stepping back out inside this window keeps it open
#define TOD_TRIAL_BARRIER_N       3     // ritual-barrier FX hosts across the 160-wide mouth (the wide fx is ~120 across)
#define TOD_TRIAL_BARRIER_SPREAD  50    // x spacing between them: -50 / 0 / +50
// ---- THE WARDEN KING (v17.70, user 2026-09-05) --------------------------------
// "the boss fight will be one panzer that has 2x flame size and range and high
// zaps will have double range. He will have a health bar and about 100M health
// at any round. He will spawn in many elites and zombies. He will be the only
// panzer during this fight ... once all player enter the top zone the door
// will lock after 10 seconds the boss will land and you can see his health
// bar. Then the game will behind the scenes make sure all players have all
// their upgrades maxed out. Then it will prompt all the users the rest of
// their dark upgrade with a 10s timer ... Once all players are maxed out the
// boss fight will begin ... Ammo will be cost 1k at the top. His health bar
// will actually be the spire bar. It will be completely lit up and as you kill
// him it drains down."
// HIS HEALTH IS PER-PLAYER AND LINEAR (v17.83, user 2026-09-05: "1/4 health on
// solo. Should scale linearly. I gave you the 4 player health so he basically
// cant die when IM playing"). v17.70 read the 100M he gave as a FLAT number
// and shipped it at every party size, so a solo player fought the four-player
// king. It was always the FOUR-player figure: 25M a head, times the party.
//
// LINEAR ON PURPOSE — this is the ONE boss that does not use
// tod_bosses::coop_hp_mult (1.0 / 1.7 / 2.3 / 2.8, which is sub-linear so a
// duo is not fighting two bosses' worth). The king is the run's final wall and
// the user set its four-player value by hand; a curve here would quietly
// contradict the number he chose. Still round-independent and NOT
// rampage-scaled — "at any round" was the original brief and stands.
//
// ⚠️ TRIED AND REVERTED, 2026-09-07 (v18.24 -> v18.25): the co-op curve was
// briefly fitted here over a 30M solo base, on "treat the factor ... the same
// as we do for panzer". It was reverted the same session, and the reason is
// worth keeping so it is not re-proposed: coop_hp_mult is SUB-LINEAR and this
// boss's rule is not, so adopting it is a solo BUFF and a squad NERF — solo
// +20%, two +2%, three -8%, four -16% (100,000,000 -> 84,000,000). The ask
// that prompted it was "the king should be a little stronger", and it made him
// weaker for every party above two. IF THE KING NEEDS RETUNING, MOVE THE
// PER-PLAYER NUMBER; the curve is the wrong instrument for a boss whose value
// was hand-set per head.
// [tod 2026-09-08] 25,000,000 -> 10,000,000. THE KING HAD NEVER BEEN FOUGHT AT
// HONEST DAMAGE. Dark upgrades went live 2026-09-04 (v17.14) carrying a unit bug
// in TOD_DARK_OVERDRIVE_ADD (25 where the additive mult chain wants a fraction =
// about 11x damage), and he landed the next day, so every run against him —
// including the tuning of this number — happened with a heavy doing 11x. Fixing
// that left him at ~6 minutes of realistic shooting PER PLAYER, against a 70 s
// Warden Trial and a 191 s finale road.
// Measured at the King state (king_max_out caps every domain, king_dark_deals
// forces the dark cards), PACK III, 40% headshots, 65% trigger uptime:
//     heavy 71,312 DPS / assault 69,548 / skirmisher 70,474  — a 3% spread, so
//     the three gun classes are already in line with each other and NONE of them
//     needed a class-side change. This wall was the only thing misaligned.
//     (Heavy figure is with the dark OVERDRIVE step at 0.40 = +65% at full ramp.)
// 10M gives ~142 s per player's share with PACK III, ~284 s without it. The
// per-player scaling and the 4-player cap are untouched, so party size does not
// move the figure.
#define TOD_KING_HP_PER_PLAYER    10000000
#define TOD_KING_HP_MAX_PLAYERS   4           // the party cap; a 5th body cannot raise the wall
#define TOD_KING_COUNTDOWN_SECS   10          // the seal -> his landing
#define TOD_KING_FLAME_FWD        140         // the second flame cone's lead ahead of the muzzle (units)
#define TOD_KING_SUMMON_SECS      18          // his summons cadence (elite debts SET, the trickle is already the trial floor)
#define TOD_KING_SUMMON_PROT      2
#define TOD_KING_SUMMON_REAVER    1
#define TOD_KING_SUMMON_HOUND     3
#define TOD_KING_SUMMON_SPRINT    2
#define TOD_KING_WIN_PTS          25000       // team-wide on the kill (the trial purse's big brother)
#define TOD_KING_CRATE_COST       1000        // the summit crate's flat price, any gun
// ---- THE KING UNDER RAMPAGE (v18.75, user 2026-09-10: "The final fight
// against the warden king on rampage should be super hard ... by at least 25%
// ... perma rampage sprint mode ... faster horde"). EVERY lever below reads
// level.tod_rampage_on through king_rampage() and nothing else; breaker off,
// the fight is byte-for-byte the v18.74 one. Rampage otherwise barely reached
// him: king_setup writes his HP flat AFTER boss_hp, so the elite x1.5 skipped
// him, and only the +3 elite roof (his summons) and the horde x1.2 landed.
#define TOD_KING_RAMPAGE_HP_MULT        1.25   // on king_hp(): 12.5M per player
#define TOD_KING_RAMPAGE_SUMMON_SECS    13     // 18 -> 13 between summons
#define TOD_KING_RAMPAGE_SUMMON_PROT_ADD  1    // +1 Protector per summons (2 -> 3)
#define TOD_KING_RAMPAGE_SUMMON_HOUND_ADD 1    // +1 hound per summons (3 -> 4)
// THE TRICKLE: the trial floor (0.12) is already the hottest on the map; the
// King under rampage runs one notch below it. LOCKSTEP PAIR with
// _tod_endless_rounds TOD_SPIRE_KING_RAMPAGE_SPAWN_FLOOR (the resolver's copy,
// consulted at each rollover; this one is written straight into zombie_vars at
// the seal, the same mid-round reason the trial floor is).
#define TOD_KING_RAMPAGE_SPAWN_FLOOR    0.10
// THE HORDE ON THE DECK: every ordinary zombie standing in the summit box is
// stamped +N rounds on the speed curve (tod_zspeed_round_add — the armored
// sprinter's own lane, read by _tod_zombie_speed at every keep-alive sweep).
// A ROUND OFFSET, not a rate multiplier, so it composes with slows and the
// depth curve exactly as the sprinter's does. Sprinters keep their own value.
#define TOD_KING_RAMPAGE_HORDE_ADD      10
// HIS SPRINT: the stock mask-break rage (MechzBehavior::mechzGoBerserk) is
// sprint locomotion for MECHZ_BERSERK_TIME 10 s — AND no flamethrower, no claw
// while it lasts (mechzShouldShootFlame / mechzShouldShootClaw return 0 on
// berserk). A permanently berserk King is a fast melee chaser that never
// burns anyone, which on an open deck with Blink and Healing Aura is EASIER.
// So the permanent part is the locomotion only, set on the blackboard the way
// the rage sets it and re-asserted every tick (the rage's own end restores
// RUN; a stumble re-evaluation can too), with flame and claw intact — and the
// REAL rage rides his summons: ten seconds of berserk each call.
// The two literals are stock blackboard.gsh's LOCOMOTION_SPEED_TYPE /
// LOCOMOTION_SPEED_SPRINT, copied rather than #inserted so this file takes
// no AI-system header; test_king_rampage.js checks them against the header.
#define TOD_KING_RAMPAGE_BB_SPEED       "_locomotion_speed"
#define TOD_KING_RAMPAGE_BB_SPRINT      "locomotion_speed_sprint"
#define TOD_KING_RAMPAGE_SPRINT_TICK    1.0
// ---- THE KING'S PHASES (v18.96, user 2026-09-13: "We can give the warden
// phases"). Before this he had ZERO state change from landing to death: every
// escalation lever above was wired to the global RAMPAGE breaker. Now his OWN
// HEALTH owns them. At two-thirds and one-third he REELS (a stun + the elite
// slow — a window you can punish), the deck shakes, the sting plays, and he
// comes back meaner: phase 2 = the permanent sprint locomotion (flame and
// claw intact) + summons 18 -> 15 s; phase 3 = the berserk on every summons +
// the 13 s cadence (king_rage_on()). Under RAMPAGE the levers are already on
// from the landing, so the phases only add the beats — never a second sprint
// thread, never a second berserk call site (test_king_rampage asserts one).
// The ladder only climbs (king_phase_watch), and a beat waits out a world
// pause (the spire's round clock still deals cards).
#define TOD_KING_PHASE_2_FRAC           0.66   // <= this fraction of maxhealth = phase 2
#define TOD_KING_PHASE_3_FRAC           0.33   // <= this = phase 3
#define TOD_KING_PHASE_2_SUMMON_SECS    15     // 18 -> 15 between summons in phase 2 (phase 3 = the rampage 13)
#define TOD_KING_STAGGER_MULT           0.45   // the reel: his animation rate for the window
#define TOD_KING_STAGGER_MS             2500
#define TOD_KING_PHASE_POLL             0.25
// (v16.20's per-tier steps — +1 Warden per 4 tiers, -0.25 s tick, +5% HP —
// were replaced by TOD_TRIAL_STEP above and the per-hub recipes in v16.21.)

#namespace tod_spire;

function init()
{
	level endon( "end_game" );

	// GEOMETRY GATE: no spire slabs in the .map (generator SPIRE_ENABLED off)
	// = this whole module stands down. Script and geometry ship independently.
	probe = GetEnt( "tod_spire_door1", "targetname" );
	if ( !isdefined( probe ) )
		return;

	level flag::wait_till( "initial_blackscreen_passed" );

	// v14.36 — ALL 100 SLABS RESIDENT, one per floor (user: "I want the endless
	// spire to match that 2 set of stairs per door"). v14.23's 50 was a
	// lap-PAIR compromise; this is the tower's own cadence.
	// The v14.1 two-slab parity MOVER never re-seated in the
	// first live run (doors 3+ never existed, the party climbed free, the
	// un-set flags left every zone past c1 disabled and stock's
	// out-of-playable monitor instakilled climbers past ~floor 6). The mover
	// used two mechanisms this map never proved live (.origin assignment on a
	// brushmodel; Show() after Hide()); resident slabs need neither — this is
	// the tower's 53-door contract verbatim: Solid at load, opened ONCE on
	// buy, never moved, never re-shown. Sealing is spread 8-per-frame like
	// the teardown spreads its reconnects.
	for ( n = 1; n <= tod_spire_data::spire_door_count(); n++ )
	{
		slab = GetEnt( "tod_spire_door" + n, "targetname" );
		if ( !isdefined( slab ) )
			continue;
		slab Solid();
		slab DisconnectPaths();
		tod_bosses::dev_ai_gate( slab, "disconnect" );
		if ( ( n % 8 ) == 0 )
			wait 0.05;
	}

	// THE TRIAL SEAL (v16.19): the gate IS door n's own slab — sealed above
	// like every door at load, opened by the buy, then re-sealed Solid +
	// DisconnectPaths WHILE STAYING HIDDEN for the trial (collision is
	// independent of Hide on a brushmodel, which is exactly why doors need
	// NotSolid as well) behind the ritual barrier FX, and opened again for
	// good on the win. No gate entity, nothing to init here but the fx key.
	level._effect[ "tod_trial_barrier" ] = "zombie/fx_ritual_barrier_defend_door_wide_zod_zmb";
	level._effect[ "tod_king_flame" ] = "dlc1/castle/fx_mech_wpn_flamethrower";   // v17.70
	// 2026-10-01: THE HALL BECOMES THE CLOCK (trial_fx_start and friends).
	foreach ( hue in trial_fx_hues() )
		level._effect[ "tod_trial_walls_" + hue ] = "tod/spire/fx_trial_walls_" + hue;
	level._effect[ "tod_trial_walls_frenzy" ] = "tod/spire/fx_trial_walls_frenzy";
	level._effect[ "tod_trial_frenzy_light" ] = "tod/spire/fx_trial_frenzy_light";
	level._effect[ "tod_trial_win" ] = "tod/spire/fx_trial_win";
	level._effect[ "tod_trial_win_light" ] = "tod/spire/fx_trial_win_light";
	level._effect[ "tod_king_countdown" ] = "tod/spire/fx_king_countdown";
	level._effect[ "tod_king_countdown_light" ] = "tod/spire/fx_king_countdown_light";
	level.tod_spire_trial_won = [];
	// THE HALL GATES (v16.21): one script_brushmodel across each hall's porch
	// mouth. Hidden + NotSolid + ConnectPaths at load — crown_door_init's
	// contract — shown and sealed by trial_run, hidden and opened by trial_win.
	hubs = tod_spire_data::hub_laps();
	for ( i = 0; i < hubs.size; i++ )
	{
		g = GetEnt( tod_spire_data::trial_gate_target( hubs[ i ] ), "targetname" );
		if ( !isdefined( g ) )
			continue;
		g Hide();
		g NotSolid();
		g ConnectPaths();
		tod_bosses::dev_ai_gate( g, "connect" );
	}
	// v17.70 THE SUMMIT GATE (across the summit stair's mouth) — same contract,
	// shown by king_run; since v19.76 king_win leaves it SHUT (the summit is the
	// end of the road - the tester's call), so only this teardown hides it.
	g = GetEnt( tod_spire_data::summit_gate_target(), "targetname" );
	if ( isdefined( g ) )
	{
		g Hide();
		g NotSolid();
		g ConnectPaths();
		tod_bosses::dev_ai_gate( g, "connect" );
	}

	// The zone-chain flags. The tower's enter_lapN flags are flag::init'd by
	// stock door_init off the map triggers; the spire has no map triggers, so
	// it inits its own. tod_ascension is the chain's root (roof_zone ->
	// spire_base_zone in the entry script's zone graph).
	if ( !( level flag::exists( "tod_ascension" ) ) )
		level flag::init( "tod_ascension" );
	for ( n = 1; n <= tod_spire_data::spire_door_count(); n++ )
	{
		if ( !( level flag::exists( "enter_spire" + n ) ) )
			level flag::init( "enter_spire" + n );
	}

	// DEV HEADROOM PROBE (v14.23): the 50 resident slabs spend init-time
	// entities from the same ~1024 table the v14.0 crash exhausted, so an
	// armed build MEASURES the remaining margin instead of guessing: spawn
	// throwaway script_origins until the pool refuses (capped), then free
	// them. The crown altar's buy trigger is the canary if this ever reads
	// low. tod_dev-gated; ships silent.
	if ( IS_TRUE( level.tod_dev ) )
	{
		probes = [];
		for ( i = 0; i < 150; i++ )
		{
			e = Spawn( "script_origin", ( 0, 0, -5000 ) );
			if ( !isdefined( e ) )
				break;
			probes[ probes.size ] = e;
		}
		for ( i = 0; i < probes.size; i++ )
			probes[ i ] Delete();
		if ( probes.size >= 150 )
			tod_quiet_print( "spire dev: init entity headroom >= 150" );
		else
			tod_quiet_print( "^1spire dev: init entity headroom = " + probes.size + " (LOW — the v14.0 altar-trigger crash class)" );
	}

	level.tod_spire_ready = true;      // read by _tod_finale: choice replaces auto-depart
	level.tod_spire_active = false;
	level.tod_spire_door_max_z = 100;  // arena risers (z=0) only, until door 1

	callback::on_spawned( &on_spire_spawned );   // v16.36 — a no-op until ascension; then perma perks per life (v16.80: the perk-slot write went with the domain)
	level thread choice_watch();
}

// ---------------------------------------------------------------------------
// THE CHOICE — the ASCEND half. _tod_finale owns the EXTRACT half and the
// choice banners; this listens for the phase and stands the dais pad up.
// ---------------------------------------------------------------------------

function choice_watch()
{
	level endon( "end_game" );
	level waittill( "tod_choice_begin" );

	// v19.68r THE ROCKETS (docs/170; user 2026-10-02: "the colorful one goes to endless spire ... they view from
	// the rocket pov as it flies to the endless spire. Then it crashes into the ground and they spawn in"): the
	// colourful ship stands on this dais and carries the ASCEND prompt (_tod_rocket::rockets_arm, the same
	// string). ride_spire returns in the crash's WHITE with every rider already set down at the arrival facing
	// the wreck, and ascend_run flips the world while nothing can be seen. The teleporter below is the
	// no-rocket path (no rocket data in the generated crown file).
	if ( IS_TRUE( level.tod_rockets_ready ) )
	{
		msg = level util::waittill_any_return( "tod_ascend", "tod_extract" );
		if ( msg != "tod_ascend" )
			return;
		if ( !tod_rocket::ride_spire() )
			tod_teleport::discharge( tod_spire_data::ascension_pad_org() );   // no ship: the old way up, in a flash
		level thread ascend_run();
		return;
	}

	org = tod_spire_data::ascension_pad_org();

	// The dais teleporter — the Der Eisendrache assembly on the crown's focal
	// point (the dais the uplink left behind in v10), ignited only now.
	tod_teleport::spawn_der_teleporter( org, 0 );
	beam = tod_teleport::spawn_beam( org );
	tod_perk_scatter::derez_burst( org );
	tod_perk_scatter::play_sound_at_origin( org, "zmb_cha_ching", 4 );

	t = Spawn( "trigger_radius_use", org + ( 0, 0, 32 ), 0, 110, 96 );
	t TriggerIgnoreTeam();      // REQUIRED for a script-spawned use-trigger
	t SetCursorHint( "HINT_NOICON" );
	// Leads with the noun (PromptDefault strips the hold prefix). No cost —
	// they paid for this in blood already.
	// v14.58: the second " / " splits the warning onto its own line in the card
	// (PromptDefault.lua's "<TITLE> - <detail 1> / <detail 2>"), so "one way,
	// no return" is not a parenthetical tucked on the end of the destination.
	t SetHintString( "Hold ^3[{+activate}]^7 ^5ASCEND^7 - to THE ENDLESS SPIRE / ^1one way, no return" );

	// v18.9 — THE OTHER HALF OF THE CONTRACT. _tod_finale states it ("each
	// retires the other by notify") and only one direction was ever wired:
	// extract_use_loop carries level endon( "tod_ascend" ), but nothing here
	// listened for "tod_extract", so this trigger stayed live through depart()'s
	// 6-second send-off. A second player's hold landing in that window fired
	// tod_ascend, teleported the party to the spire and tore down the tower —
	// and then the departure timer ended the match with YOU ESCAPED THE TOWER
	// over a world they had been dropped into two seconds earlier, costing them
	// the entire post-victory mode. Co-op only.
	//
	// A SEPARATE THREAD AND NOT AN endon HERE: a thread killed by endon runs no
	// cleanup (this repo's own endon-is-not-cleanup rule), so this function
	// dying on the notify would strand the "ASCEND — one way, no return" prompt
	// on screen for the whole send-off. The retirer clears the string and
	// disables the trigger, which is what actually closes the race — a disabled
	// trigger cannot notify.
	level thread choice_extract_retire( t );

	for ( ;; )
	{
		t waittill( "trigger", player );
		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( !( zm_utility::is_player_valid( player ) ) )
			continue;
		if ( player zm_utility::in_revive_trigger() )
			continue;
		break;   // FIRST COMMITTED HOLD WINS for the whole party (approved design)
	}

	// Committed. The extract half stands down on this notify.
	level notify( "tod_ascend" );
	t SetHintString( "" );
	t TriggerEnable( false );

	// The teleport theater — the pad recipe at ascension scale.
	level thread tod_teleport::fx_burst( "tod_tp_charge", org + ( 0, 0, 40 ), 1.3 );
	tod_perk_scatter::play_sound_at_origin( org, "tod_teleport_fire", 4 );
	wait 0.8;
	tod_teleport::discharge( org );
	if ( isdefined( beam ) )
		beam Delete();
	t Delete();

	level thread ascend_run();
}

// v18.9 — retire the ASCEND trigger when the party takes the OTHER door.
// Spawned by choice_watch beside the trigger; see the block there for why this
// is a thread and not an endon on choice_watch itself.
//
// It ends on "tod_ascend" as well as "end_game" so it can never fire after the
// ascend path has already consumed and deleted the trigger — the isdefined
// guard covers the same ground, and both are cheap.
function choice_extract_retire( t )
{
	level endon( "end_game" );
	level endon( "tod_ascend" );

	level waittill( "tod_extract" );

	if ( isdefined( t ) )
	{
		t SetHintString( "" );   // clears the prompt; costs no new string
		t TriggerEnable( false );
	}
}

// ---------------------------------------------------------------------------
// THE ASCENSION
// ---------------------------------------------------------------------------

function ascend_run()
{
	level endon( "end_game" );

	arrival = tod_spire_data::arrival_org();

	// 1. EVERYONE GOES — living on the ring, downed dragged along (the
	// gather_to_centre precedent: a crawler who survived the siege has earned
	// the ride, and leaving one behind in a dead world is not a choice).
	// v19.68r: a ROCKET arrival faces the burning wreck in the arena's north-west corner (docs/170)
	face = 0;
	if ( IS_TRUE( level.tod_ascend_by_rocket ) )
		face = tod_spire_data::rocket_arrival_yaw();
	players = GetPlayers();
	n = 0;
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		ang = n * 90;
		off = ( cos( ang ) * 56, sin( ang ) * 56, 0 );
		p SetOrigin( arrival + off );
		p SetPlayerAngles( ( 0, face, 0 ) );   // facing +x: the first door, the climb (a rocket arrival: the wreck)
		n++;
	}
	// a rocket arrival is the crash's white, not a teleport: no discharge, no materialize beam
	if ( !IS_TRUE( level.tod_ascend_by_rocket ) )
	{
		tod_teleport::discharge( arrival );
		level thread tod_teleport::fx_burst( "tod_tp_kino", arrival + ( 0, 0, 4 ), 3.0 );
	}

	// 2. THE WORLD FLIPS. Order matters: state fields first (the spawn systems
	// read them this frame), then the teardown, then the grant/vendors (which
	// SPEND the slots the teardown freed).
	level notify( "tod_ascension" );          // kills the finale pressure loop
	level flag::set( "tod_ascension" );       // roof_zone -> spire_base_zone chain root
	level.tod_spire_active = true;            // hot pacing + the spire spawn filter
	level.tod_choice_pending = undefined;

	// EVERY ZOMBIE DIES WITH THE TOWER (live test 2026-08-29: "we need to kill
	// all zombies on map and they need to start spawning on the endless spire").
	// Anything alive right now is 9,500+ units behind the party in a world
	// they left — stranded actors holding slots the spire needs.
	wipe_all_zombies();
	level thread island_sweep();   // v17.92 — the wipe is one frame; the tower keeps spawning for a while (see island_sweep)

	// SPAWNING RESUMES AT SPIRE PACE, THIS FRAME. Three writes, all needed:
	// the choice froze zombies via stock's world_is_paused and the boss
	// directors via tod_upgrade_pause (clear both), and
	// zombie_vars["zombie_spawn_delay"] is what round_spawning actually SLEEPS
	// on mid-round — the per-round resolver alone leaves the old delay
	// marinating until the next rollover (the live-test no-spawn deadlock).
	// 0.18 = TOD_SPIRE_SPAWN_FLOOR, the lockstep pair in _tod_endless_rounds.
	level.tod_upgrade_pause = false;
	if ( level flag::exists( "world_is_paused" ) )
		level flag::clear( "world_is_paused" );
	level.zombie_vars[ "zombie_spawn_delay" ] = TOD_SPIRE_SPAWN_FLOOR;

	// v16.9 — THE BUDGET IS THE CLOCK AT DEPTH (user 2026-09-01: "each round
	// was like 15 minutes. We need to triple the speed"). _tod_endless_rounds::
	// tod_max_zombies now cuts every spire round's spawn budget by
	// TOD_SPIRE_BUDGET_DIV, but stock stamps level.zombie_total ONCE at the top
	// of round_spawning — so the round in progress at ascension would still
	// carry the tower's FULL budget (hundreds of zombies at round 40+: exactly
	// the 15-minute first spire round). Same shape as the zombie_vars write
	// above: re-resolve through the hook — tod_spire_active is already true, so
	// it answers at spire size — and clamp the unspent remainder to it.
	fresh = zm::get_zombie_count_for_round( level.round_number, GetPlayers().size );
	if ( isdefined( level.zombie_total ) && isdefined( fresh ) && level.zombie_total > fresh )
		level.zombie_total = fresh;

	// TARGETABILITY INSURANCE: re-derive ignoreme from stock's own refcount
	// (the _tod_powerups pattern — never stomp the count, the laststand trap).
	// A latched ignoreme is the classic every-enemy-ignores-you cause; the
	// dev probe below reports it if it ever recurs.
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p.ignoreme = ( isdefined( p.ignorme_count ) && p.ignorme_count > 0 );
	}
	level.tod_finale_aggro = false;
	level.tod_finale_holdout = false;
	level.tod_crown_sealed = false;           // the hall-only spawn filter dies with the tower
	level.tod_finale_spawn_floor = undefined;
	level.tod_finale_pressure_tick = undefined;
	level.tod_rp_force_orgs = undefined;
	level.tod_boss_force_org = undefined;
	// The song clock is over — stale fields would leave the tower gauge
	// drawing a dead finale bar for the whole endless run.
	level.tod_finale_song_start = undefined;
	level.tod_finale_song_end = undefined;
	// v17.10 (user 2026-09-04: "I just want to continue the 4 round cadence of
	// getting upgrades on the spire. Thats all"). THE ROUND CLOCK DEALS AGAIN UP
	// HERE. v16.36 had set tod_upgrades_suppressed, which stopped BOTH the round
	// events and the station gate; only the second half was ever wanted in the
	// spire, so this now sets the station-only flag and the scheduler runs its
	// normal every-4th-round cadence.
	//
	// The FINALE still sets tod_upgrades_suppressed and still stops everything —
	// that one is not about stations, it is that the closing song is the run's
	// clock and a world freeze does not stop a music stream.
	//
	// Stations were never PLACED on the spire anyway (station_spawn does base 0,
	// breathers 1-4, crown 5, and the teardown deletes the old world), so this is
	// belt-and-braces rather than the only guard.
	// ⚠️ AND THE FINALE'S FLAG MUST BE CLEARED HERE, EXPLICITLY. _tod_finale sets
	// tod_upgrades_suppressed at the top of the road run and never clears it —
	// it did not need to, because the game ended either way and because the old
	// line here re-set the same flag to true. Now that the spire sets a
	// DIFFERENT flag, a stale `true` would survive ascension and the round clock
	// would deal nothing for the whole endless run: no error, no log line, just
	// an upgrade cadence that silently never fires. Same family as every other
	// stale-latch trap in this file.
	level.tod_upgrades_suppressed = undefined;
	level.tod_stations_suppressed = true;
	level.custom_game_over_hud_elem = &spire_game_over;

	// MUSIC: the finale latch dies, the band table becomes ONE row, the latch
	// resets, and the spire loop takes the channel. The Panzer override rides
	// the same boss_track_start/end refcount it always did.
	level.tod_finale_music = undefined;
	level.tod_music_bands = [];
	tod_atmosphere::add_music_band( 0, "tod_music_spire" );
	level.tod_music_floor = 0;
	tod_atmosphere::channel_play( "tod_music_spire" );

	// THE SKY GOES WITH THE MUSIC (v14.37, user: "can we dynamically change the
	// skybox wants the team enters the endless spire?"). The skybox MODEL is a
	// baked worldspawn key and cannot change — so the fog swallows it instead:
	// dense blood-red with the altitude falloff pushed past the summit, which
	// means the Miami skyline is never visible from the spire at all. Full
	// reasoning + the rejected visionset lane are documented at the function.
	// Lerps over ~6s, and the teleport flash covers the first second.
	tod_atmosphere::spire_weather_turn();

	teardown_tower();

	// 3. THE GRANT — every player (v16.36: perma perks + ammo and health,
	// nothing else — see grant_all; v16.80 dropped the perk-slot write).
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p thread grant_all();
	}

	// 4. THE SPIRE'S OWN SYSTEMS.
	retire_perk_machines();   // v17.56: no vending machines in the spire — the perks are perma
	spawn_hub_vendors();
	level thread door_manager();
	level thread trial_watch_all();   // v16.21: every hub hall arms on presence alone (never on the door path)
	level thread crate_window();
	level thread summit_station();

	// 5. Say where they are. One banner, six seconds, then the climb speaks
	// for itself.
	level thread arrival_banners();

	// DEV DIAGNOSIS (live report 2026-08-29: "Zombies are spawning but do not
	// target me. No enemy targets me."). Names the mechanism instead of
	// guessing at it: per tick, the nearest zombie's distance, whether it holds
	// a target, and the player's own validity flags. tod_dev-gated; ships silent.
	if ( IS_TRUE( level.tod_dev ) )
	{
		level thread dev_target_probe();
		level thread dev_mesh_probe();
	}
}

// DEV — SPIRE MESH COVERAGE. The one measurement that separates "no navmesh
// here" from every other reason an enemy can be standing still, and it is a
// measurement rather than an inference: it asks the engine, at 600 points
// spread up the 200 spire flight ramps, whether there is mesh under them.
//
// WHY THE FLIGHTS. Seeds used to be emitted one per RISER and risers live only
// on LANDINGS, so the flights were the surface with no seed of its own — and
// cod2map is Havok REGION PRUNING, which can drop a region that is connected to
// a seeded one. The 2026-09-04 pass seeds every ramp from inside rampWedgeY /
// rampWedgeX; this probe is how that is checked rather than believed.
//
// Coordinates are the same arithmetic the generator builds the wedges from
// (SP_X 10240, CORE 256, PX 416, TREAD 32, FLIGHT_RISE 192, LAP_RISE 384), and
// the sample is 2 units above the wedge top, exactly where a seed sits.
//
// READ IT AS: 0/600 = the flights are fully meshed, look elsewhere. Anything
// above 0 = that many samples have NO navmesh under them, and `first=` names a
// coordinate to fly to. tod_dev-gated; ships silent.
function dev_mesh_probe()
{
	level endon( "end_game" );
	wait 5;

	miss  = 0;
	tot   = 0;
	first = undefined;
	for ( n = 1; n <= tod_spire_data::spire_laps(); n++ )
	{
		b   = ( n - 1 ) * 384;
		mid = b + 192;
		for ( s = 1; s <= 3; s++ )
		{
			// OFFSET FROM THE SEED POINTS ON PURPOSE. The generator drops its
			// ramp seeds at t = 0.25 / 0.50 / 0.75; sampling those exact spots
			// would ask "did the seed anchor" when the question is "is the
			// FLIGHT meshed". 0.15 / 0.40 / 0.65 walks the surface between them.
			t = s * 0.25 - 0.10;
			if ( ( n % 2 ) == 1 )
			{
				p1 = ( 10576, -288 + 512 * t, b + 192 * t + 2 );              // E flight ramp
				p2 = ( 10016 + 512 * t, 336, mid + 192 - 192 * t + 2 );       // N flight ramp
			}
			else
			{
				p1 = ( 9904, -224 + 512 * t, b + 192 - 192 * t + 2 );         // W flight ramp
				p2 = ( 9952 + 512 * t, -336, mid + 192 * t + 2 );             // S flight ramp
			}
			tot += 2;
			if ( !isdefined( GetClosestPointOnNavMesh( p1, 32, 24 ) ) )
			{
				miss++;
				if ( !isdefined( first ) )
					first = p1;
			}
			if ( !isdefined( GetClosestPointOnNavMesh( p2, 32, 24 ) ) )
			{
				miss++;
				if ( !isdefined( first ) )
					first = p2;
			}
		}
		WAIT_SERVER_FRAME;
	}

	line = "spire mesh: " + miss + "/" + tot + " flight samples OFF-MESH";
	if ( isdefined( first ) )
		line = line + "  first=(" + int( first[ 0 ] ) + " " + int( first[ 1 ] ) + " " + int( first[ 2 ] ) + ")";
	IPrintLnBold( line );
}

function dev_target_probe()
{
	level endon( "end_game" );
	for ( ;; )
	{
		wait 3;
		players = GetPlayers();
		p = undefined;
		for ( i = 0; i < players.size; i++ )
		{
			if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) && isalive( players[ i ] ) )
			{
				p = players[ i ];
				break;
			}
		}
		if ( !isdefined( p ) )
			continue;
		zs = GetAISpeciesArray( "all" );
		best = undefined;
		bd = 999999;
		n = 0;
		for ( i = 0; i < zs.size; i++ )
		{
			z = zs[ i ];
			if ( !isdefined( z ) || !isalive( z ) )
				continue;
			n++;
			d = Distance( z.origin, p.origin );
			if ( d < bd )
			{
				bd = d;
				best = z;
			}
		}
		line = "probe: ai=" + n + " ign=" + ( ( IS_TRUE( p.ignoreme ) ) ? 1 : 0 ) + " valid=" + ( ( zm_utility::is_player_valid( p, true ) ) ? 1 : 0 );
		if ( isdefined( best ) )
			line = line + " near=" + int( bd ) + " fav=" + ( ( isdefined( best.favoriteenemy ) ) ? 1 : 0 ) + " ignall=" + ( ( IS_TRUE( best.ignoreall ) ) ? 1 : 0 );
		// ---- THE ROUND-STALL COUNTERS (v15 item 2) --------------------------
		// "Rounds dont continue in endless spire." Under the endless-rounds
		// twist the next round starts when the last zombie SPAWNS, so a round
		// freeze and a SPAWN freeze are the same event and these four numbers
		// name which one it is. Read them together:
		//   tot  = level.zombie_total, the round's UNSPENT spawn budget. This is
		//          what tod_round_wait drains to 0. If it sits still, spawning
		//          is wedged and THAT is the stall.
		//   cur  = live zombies       act = live actors (the 60-actor ceiling)
		//   el   = elites_all_alive() vs the TOD_ELITE_ROOF_ALL of 12
		// DIAGNOSIS: tot frozen with act pinned near 60 and el at 12 is
		// actor-pool saturation (the honour-guard roof bypass, fixed this build).
		// tot frozen with act LOW is the opposite — spawn points or navmesh, and
		// no GscOnly cures it.
		tot = ( ( isdefined( level.zombie_total ) ) ? level.zombie_total : -1 );
		line = line + " | tot=" + tot
		            + " cur=" + zombie_utility::get_current_zombie_count()
		            + " act=" + zombie_utility::get_current_actor_count()
		            + " el=" + tod_bosses::elites_all_alive();
		tod_quiet_print( line );
	}
}

// The seal's own wipe recipe (_tod_finale::wipe_the_map — cloned, not
// imported: the notify contract keeps these modules import-free of each other).
// v17.92 — THE WIPE IS ONE FRAME AND THE TOWER DOES NOT STOP ON A FRAME.
// console_mp.log 2026-09-05: 3.5 s after ascension the dev probe read cur=7
// with the nearest zombie 10,156 units away, i.e. trash standing on the TOWER
// while every player was on the spire; by 92 s it was cur=29. Bodies that were
// still emerging when Kill() ran, plus the spawns stock's round loop landed at
// tower points in the frames before the spawn filter took hold, were left with
// no path to any player (27 PATHFIND_FAILURE_UNREACHABLE lines, ents 24..35, all
// at z~0, x~+-460 — the base arena) and no way to die. Eight of them sat there
// for the whole match holding actor slots the spire needed.
//
// Neither safety net reached them: stock's round_spawn_failsafe waits
// level.failsafe_waittime (30 s) per pass and then teleports to a spawn point
// through our own selector; _tod_stray relocates by cost/visibility and is
// boot-only verified. This is the rule underneath both: once the party has
// ascended, ANY actor off the spire island is dead weight by definition — the
// tower is a place no player can ever stand again. So sweep it: fast for the
// first seconds (the spawn tail), then slowly for the rest of the match (the
// belt). Kill(), not Delete(): trash goes through stock's death and the corpse
// lane, elites through their own death watches (attacker undefined = no
// reward, exactly like the wipe below), hounds through their new delete lane.
#define TOD_ISLAND_SWEEP_FAST_SECS   1.0
#define TOD_ISLAND_SWEEP_FAST_PASSES 15
#define TOD_ISLAND_SWEEP_SLOW_SECS   5.0
function island_sweep()
{
	level endon( "end_game" );
	pass = 0;
	for ( ;; )
	{
		if ( pass < TOD_ISLAND_SWEEP_FAST_PASSES )
			wait TOD_ISLAND_SWEEP_FAST_SECS;
		else
			wait TOD_ISLAND_SWEEP_SLOW_SECS;
		pass++;
		if ( !IS_TRUE( level.tod_spire_active ) )
			continue;
		ai = GetAISpeciesArray( "all" );
		n = 0;
		for ( i = 0; i < ai.size; i++ )
		{
			e = ai[ i ];
			if ( !isdefined( e ) || !isalive( e ) )
				continue;
			if ( IS_TRUE( e.tod_dropping ) )
				continue;   // a boss mid-entrance is Ghosted and owned by drop_in; its landing is on-island by the spawn filter
			if ( tod_spire_data::in_spire( e.origin ) )
				continue;
			e Kill();
			n++;
		}
		if ( n > 0 && IS_TRUE( level.tod_dev ) )
			tod_quiet_print( "spire dev: island sweep killed " + n + " off-spire actor(s), pass " + pass );   // v17.92a: this file has no dbg() of its own (each module carries one) — the linker caught it, lint_tod_arity did not
	}
}

function wipe_all_zombies()
{
	ai = GetAISpeciesArray( "all" );
	for ( i = 0; i < ai.size; i++ )
	{
		e = ai[ i ];
		if ( !isdefined( e ) || !isalive( e ) )
			continue;
		e Kill();
	}
}

// ---------------------------------------------------------------------------
// THE TEARDOWN — "the tower dies behind you" (docs/44 §4 rule 2). Deletes the
// old world's TRACKED script-spawned entity load. Untracked cosmetics (crate
// models, teleporter assemblies, station meshes) stay — they cost nothing we
// need back, and nobody is ever there to see them again.
// ---------------------------------------------------------------------------

function teardown_tower()
{
	// Every tower door: both buy triggers, the slab (bought slabs are Hidden
	// but still hold gentity slots), and the dead map trigger.
	if ( isdefined( level.tod_doors_by_flag ) )
	{
		keys = GetArrayKeys( level.tod_doors_by_flag );
		for ( i = 0; i < keys.size; i++ )
		{
			d = level.tod_doors_by_flag[ keys[ i ] ];
			if ( !isdefined( d ) )
				continue;
			if ( isdefined( d.tod_trigs ) )
			{
				for ( j = 0; j < d.tod_trigs.size; j++ )
				{
					if ( isdefined( d.tod_trigs[ j ] ) )
						d.tod_trigs[ j ] Delete();
				}
			}
			if ( isdefined( d.tod_slab ) )
			{
				// An unbought slab is Solid + DisconnectPaths — reconnect
				// before deleting or the navmesh stays cut at a doorway that
				// no longer exists (ConnectPaths is not refcounted, but the
				// slab's cut is its own).
				d.tod_slab ConnectPaths();
				tod_bosses::dev_ai_gate( d.tod_slab, "connect" );
				d.tod_slab Delete();
			}
			d Delete();
			if ( ( i % 8 ) == 0 )
				wait 0.05;   // spread the navmesh reconnects
		}
		level.tod_doors_by_flag = undefined;
	}

	// The teleporter network: triggers + idle beams (the assemblies are
	// untracked cosmetics and stay).
	if ( isdefined( level.tod_tp_trigs ) )
	{
		for ( i = 0; i < level.tod_tp_trigs.size; i++ )
		{
			t = level.tod_tp_trigs[ i ];
			if ( !isdefined( t ) )
				continue;
			if ( isdefined( t.tod_tp_beam ) )
				t.tod_tp_beam Delete();
			t Delete();
		}
		level.tod_tp_trigs = [];
	}

	// The finale's props and triggers.
	if ( isdefined( level.tod_finale_uplink ) )
		level.tod_finale_uplink Delete();
	if ( isdefined( level.tod_finale_uplink_clip ) )
	{
		level.tod_finale_uplink_clip ConnectPaths();
		tod_bosses::dev_ai_gate( level.tod_finale_uplink_clip, "connect" );
		level.tod_finale_uplink_clip Delete();
	}
	if ( isdefined( level.tod_finale_uplink_trig ) )
		level.tod_finale_uplink_trig Delete();
	if ( isdefined( level.tod_finale_pad_trig ) )
		level.tod_finale_pad_trig Delete();
	if ( isdefined( level.tod_finale_pad ) )
		level.tod_finale_pad Delete();
	if ( isdefined( level.tod_finale_beacon ) )
		level.tod_finale_beacon Delete();
	if ( isdefined( level.tod_finale_pylons ) )
	{
		for ( i = 0; i < level.tod_finale_pylons.size; i++ )
		{
			if ( isdefined( level.tod_finale_pylons[ i ] ) )
				level.tod_finale_pylons[ i ] Delete();
		}
		level.tod_finale_pylons = [];
	}
	if ( isdefined( level.tod_finale_sconces ) )
	{
		for ( i = 0; i < level.tod_finale_sconces.size; i++ )
		{
			if ( isdefined( level.tod_finale_sconces[ i ] ) )
				level.tod_finale_sconces[ i ] Delete();
		}
		level.tod_finale_sconces = [];
	}
	if ( isdefined( level.tod_avenue_hosts ) )
	{
		for ( i = 0; i < level.tod_avenue_hosts.size; i++ )
		{
			if ( isdefined( level.tod_avenue_hosts[ i ] ) )
				level.tod_avenue_hosts[ i ] Delete();
		}
		level.tod_avenue_hosts = [];
	}
}

// ---------------------------------------------------------------------------
// THE GRANT (v16.36, user 2026-09-02: "defeating the map and going to the
// endless spire will give you max upgrades lets remove that. You will keep
// what upgrades you have. Instead it will give you perma perks. You will get
// all the perks and then also keep them even when you die. Also that means
// you must be given the max perk bottle upgrade so that one we can gift.
// When you beat a trial you will get an upgrade. Thats how you will continue
// upgrading your class.")
//
// self = player. WHAT ASCENSION HANDS OUT NOW:
//   * (v16.36..v16.79: PERK SLOTS to its cap. Gone with the domain in v16.80 —
//     the perk limit sits above the roster, so there is nothing to raise.)
//   * EVERY PERK THE MAP SELLS, PERMANENTLY (perma_perks_give + the keeper
//     below): the live scatter roster, and ONLY that.
//   * Full ammo + full health. The luck bar is KEPT — it drives the rarity of
//     the trial deals now, so zeroing it would throw away earned odds.
//
// WHAT IT NO LONGER HANDS OUT (v14.0 → v16.35): the T3 promotion, the free
// Pack-a-Punch latch, the sidearm PaP and every domain at its cap. The party
// climbs the spire with exactly the build it beat the tower with; the ONLY
// upgrade source on the spire is a WON TRIAL (trial_upgrade_deal → the real
// round-event deal, luck and all). Round-clock events stay suppressed
// (ascend_run), so nothing hands out a card the user did not name.
//
// The class-tier FLOOR stamp survives: a tier card dealt on the spire still
// asks tier_floor_ok, and a late joiner's high-water starts at 0 — the spire
// is above floor 50 by definition, so stamp it and never let a promotion
// earned in a trial be refused for a floor the player cannot even reach.
// ---------------------------------------------------------------------------

function grant_all()
{
	level endon( "end_game" );
	self endon( "disconnect" );

	tod_gauge::mark_top_reached( self );

	// 1. EVERY PERK, and the keeper that holds them for the rest of the run.
	self perma_perks_give( true );
	self thread perma_perks_watch();

	// 2. Ammo + health. (The luck bar is deliberately untouched — see above.)
	if ( !isdefined( self ) )
		return;
	weapons = self GetWeaponsListPrimaries();
	for ( i = 0; i < weapons.size; i++ )
		self GiveMaxAmmo( weapons[ i ] );
	if ( isalive( self ) && self.health < self.maxhealth )
		self SetNormalHealth( self.maxhealth );

	self PlayLocalSound( "tod_ultimate_sting" );
}

// (grant_perk_slots() — the v16.36 PERK SLOTS gift — went with the domain in
// v16.80; the perk limit sits above the roster, nothing to raise per life.)

// PERMA PERKS — every perk the map sells to self, minus what is already held.
// The live scatter roster (GetArrayKeys of level.tod_scatter_machines), never
// a hardcoded list (the lineup has changed repeatedly). b_qr: whether QUICK
// REVIVE may be handed out on this call.
//
// WHY A FLAG FOR ONE PERK: in SOLO, Quick Revive is a LIFE — stock's
// perk_think consumes it on the self-revive (use_solo_revive → do_retain
// false) and the machine sells at most its solo cap. The revive/spawn lane
// passes false in solo, or a down would refund the very life it just spent
// and a solo spire run could never end. Ascension and a WON TRIAL pass true:
// one free life per trial, which is what the v16.21 trial grant already
// amounted to. In co-op QR is faster revives, not lives — always re-given.
//
// Stock strips every perk on a down (perk_think → UnsetPerk) and runs each
// perk's take hook then; giving them back through zm_perks::give_perk re-runs
// every give hook (Jugg's max health, the PhD / Cherry / Wisp Tea threads), so
// the lifecycle is always take → give and never a stale retained state. That
// is why this does NOT use stock's _retain_perks flag: onPlayerSpawned zeroes
// num_perks on every spawn, and a retained perk would then sit outside the
// count with its effect threads dead.
function perma_perks_give( b_qr )
{
	if ( !isdefined( self ) || !isplayer( self ) )
		return;
	specs = [];
	if ( isdefined( level.tod_scatter_machines ) )
		specs = GetArrayKeys( level.tod_scatter_machines );
	for ( i = 0; i < specs.size; i++ )
	{
		if ( !isdefined( self ) || !isalive( self ) )
			return;
		// a crawler gets nothing: stock strips on the down, and a grant into
		// last stand is lost on the revive anyway (review find, v16.26)
		if ( self laststand::player_is_in_laststand() )
			return;
		if ( self HasPerk( specs[ i ] ) )
			continue;
		if ( !IS_TRUE( b_qr ) && specs[ i ] == "specialty_quickrevive" )
			continue;
		self zm_perks::give_perk( specs[ i ], 0 );
		wait 0.15;   // stagger the grant FX/sounds
	}
}

// THE KEEPER. self = player; one per player for the run (latched — the field
// rides the player object across respawns). A revive brings back the perks
// stock just stripped. The bleed-out → respawn path is on_spire_spawned (the
// spawn callback every other per-life setup in this map uses), not here.
function perma_perks_watch()
{
	level endon( "end_game" );
	self endon( "disconnect" );

	if ( IS_TRUE( self.tod_spire_perma_watch ) )
		return;
	self.tod_spire_perma_watch = true;

	for ( ;; )
	{
		self waittill( "player_revived" );
		wait 0.5;   // let stock's revive settle (health, weapons) before the perk burst
		self perma_perks_give( !( zm_perks::use_solo_revive() ) );
	}
}

// callback::on_spawned — registered at init, a no-op until ascension. Covers
// the bleed-out → next-round respawn (the perks went with the old life) and
// the late joiner / reconnect: they get the perks and the keeper like everyone
// who ascended. (v16.36..v16.79 it also wrote PERK SLOTS to its cap — gone
// with the domain in v16.80.)
function on_spire_spawned()
{
	if ( !IS_TRUE( level.tod_spire_active ) )
		return;
	self endon( "disconnect" );
	wait 1.0;   // after player_upgrade_setup and stock's own spawn work
	if ( !isdefined( self ) || !isalive( self ) )
		return;
	tod_gauge::mark_top_reached( self );
	self perma_perks_give( !( zm_perks::use_solo_revive() ) );
	self thread perma_perks_watch();
	// THE KING'S MAX-OUT CATCH-UP (bug review 2026-09-22, F07): king_max_out
	// runs once, for the players alive at the landing. A teammate who bled out
	// on the way up respawned into the hardest fight of the run with their
	// pre-summit cards. Same silent fill-in they would have had; the dark
	// deals are not re-run (the every-4th-round deal still reaches them).
	if ( IS_TRUE( level.tod_king_active ) && IS_TRUE( level.tod_king_maxed_done ) && !IS_TRUE( self.tod_king_maxed ) )
	{
		self.tod_king_maxed = true;
		king_log( "MAXOUT catch-up player=" + self GetEntityNumber() );
		tod_upgrades::king_max_player( self );
	}
}

// Dev log for the summit fight. Assembled outside the developer block, printed
// inside it (the proven pattern).
function king_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_KING] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

// ---------------------------------------------------------------------------
// THE PERK MACHINES STAY BEHIND (v17.56, user 2026-09-04: "carefully remove
// all perks from the spire because during the endless spire you have all
// perks perma"). v14.0-v17.51 migrated the scatter's pad pool onto the spire
// (arena + 2 per hub) and kept the reshuffle running; since v16.36 every perk
// is perma-granted on ascension, so those machines were props that could take
// 4000 points for a perk already held. The scatter parks the set out of the
// world and stops its watchers; the ROSTER (the trigger keys) survives, and
// that is all perma_perks_give ever read. The spire has no perk pads, no
// perk anchors in its data and no machine geometry — the hub vendors are PaP
// + crate only.
// ---------------------------------------------------------------------------

function retire_perk_machines()
{
	tod_perk_scatter::retire_all();
}

// PaP at every hub — the ALXS vendor lane, registered late (the pack's
// register path is init-time-agnostic; its power watch finds power_on already
// set and lights up within a second).
function spawn_hub_vendors()
{
	hubs = tod_spire_data::hub_laps();
	for ( i = 0; i < hubs.size; i++ )
	{
		z = tod_spire_data::hub_z( hubs[ i ] );
		// v17.33 — TRUE = this machine sells PACK II (25,000) and PACK III
		// (50,000), the +50%-per-tier damage re-packs that hand back the SAME
		// weapon. The spire's hub vendors are the ONLY machines in the map that
		// do; the tower's five sell the ordinary 5,000 pack and nothing else.
		// User 2026-09-04: "Only avaibale in the endless spire PaP".
		// v18.78: PER HUB — each hall puts its PaP and crate on its own wall
		// (generator SP_RM_LAYOUTS[i].furn; the anchors are switch-by-hub now).
		tod_powerups::breather_pap_place( tod_spire_data::hub_pap_org( hubs[ i ], z ), tod_spire_data::hub_pap_trig( hubs[ i ], z ), tod_spire_data::hub_pap_yaw( hubs[ i ] ), true );
		// The hub crate — its collision clip is generator-cut into the .map
		// (label "spire hub lapN ammo crate body"), so this is model+trigger
		// only, exactly like the breather crates.
		spawn_crate( tod_spire_data::hub_crate_org( hubs[ i ], z ), tod_spire_data::hub_crate_yaw( hubs[ i ] ) );
	}
	// The arena crate — same contract since v17.38 (label "spire arena ammo
	// crate body"; it carried script clips from 2026-08-29 to then).
	spawn_crate( tod_spire_data::arena_crate_org(), tod_spire_data::arena_crate_yaw() );
}

// One crate: model + use trigger (riding _tod_ammo_crate's own use_loop, so
// pricing/refusals stay one implementation). Collision is the generator-cut
// box every crate in the map has (v17.38) — nothing script-side. Returns a
// struct so the window manager can de-rez shelf crates.
function spawn_crate( org, yaw )
{
	c = SpawnStruct();
	// EVERY PART OF THE CRATE COMES FROM _tod_ammo_crate NOW (v14.58, user
	// 2026-08-31: "All ammo crates should work the same"). This function used
	// to hand-roll the model (scale 2.5 retyped), the trigger (72/80 retyped)
	// and — the one that actually bit — its own COPY of the hint literal, kept
	// in step by a "keep in LOCKSTEP" comment and nothing else. Two copies of a
	// string that names two prices is a drift trap, AND it spent two permanent
	// triggerstring slots for one prompt (cap 250 a match, never freed).
	// use_loop was already shared; now the whole crate is.
	m = tod_ammo_crate::spawn_model( org, yaw );
	if ( !isdefined( m ) )
		return undefined;   // entity pool full — a missing crate is buyable elsewhere

	t = tod_ammo_crate::spawn_trigger( org, yaw );   // in FRONT of the crate — see _tod_ammo_crate's trigger block

	c.m = m;
	c.t = t;
	return c;
}

function delete_crate( c )
{
	if ( !isdefined( c ) )
		return;
	if ( isdefined( c.m ) )
		c.m Delete();   // its box is a resident .map brush (v17.38) — nothing to ConnectPaths
	if ( isdefined( c.t ) )
		c.t Delete();
}

// ---------------------------------------------------------------------------
// THE DOORS — one per lap (70 since v17.69), sequential, ONE live at a time. The climb is strictly
// ordered (door n stands behind door n-1), so only the next door ever needs
// buy triggers: ~4 live gentities instead of 200 resident. The slab contract,
// the guards and the live pricing are _tod_doors' own, cloned because that
// module's per-door state machine assumes map triggers this lap has none of.
// ---------------------------------------------------------------------------

// v14.23 — RESIDENT SLABS, NO MOVERS (see init's block comment: the v14.1
// parity mover never re-seated live). Buying door n opens ITS OWN slab via
// the tower's proven contract; the BYPASS WATCHDOG below is the containment
// layer: if any player ever stands past an unbought door again (any future
// failure of any kind), the door opens FREE and the zone flags advance — a
// lost sale instead of disabled zones + the out-of-playable instakill.
function door_manager()
{
	level endon( "end_game" );

	level thread door_bypass_watchdog();

	for ( n = 1; n <= tod_spire_data::spire_door_count(); n++ )
	{
		// DEV ALL-OPEN (v17.56): dev_open_all_doors has opened every slab and
		// set every flag itself; a manager selling doors on top of that would
		// only spawn triggers into open doorways.
		if ( IS_TRUE( level.tod_spire_dev_all_open ) )
			return;

		info = tod_spire_data::get_spire_door_info( n );
		if ( !isdefined( info ) )
			return;

		// Published for the watchdog: the z of the door currently for sale.
		// v19.76: and its NUMBER, so the watchdog can name the hub whose trial
		// seals it (trial_hub_of_door) instead of only knowing a height.
		level.tod_spire_next_door_z = tod_spire_data::spire_door_z( n );
		level.tod_spire_next_door_n = n;

		t1 = spire_door_trigger( info.org + info.off, info );
		t2 = spire_door_trigger( info.org - info.off, info );

		// THE ONLY SEAL LEFT IS THE TRIAL (v18.0 — see TOD_SPIRE_DOOR_SEAL_SECS's
		// retirement note at the top of this file). The door above a hub
		// (11, 21 .. 61) opens only when that hub's trial is won; every other
		// door is buyable the moment its triggers exist. The summit plays the
		// trial door's role for the last hub (summit_station).
		//
		// Door 1 is skipped as it always was — trial_hub_of_door( 1 ) is 0 and
		// there is no hub below the arena, so the guard is really "n > 1", kept
		// explicit rather than leaning on the lookup returning 0.
		if ( n > 1 )
		{
			hub = tod_spire_data::trial_hub_of_door( n );
			if ( hub > 0 )
				level thread trial_seal_window( t1, t2, hub );
		}

		// Whichever trigger lands the buy notifies; both then retire. The
		// watchdog fires the SAME notify (with the bypass marker set).
		level util::waittill_any( "tod_spire_door_bought", "tod_spire_dev_all_open" );
		if ( IS_TRUE( level.tod_spire_dev_all_open ) )
		{
			// dev_open_all_doors took over mid-sale: retire the live pair and
			// stand down (the dev function has already opened this door).
			if ( isdefined( t1 ) )
				t1 Delete();
			if ( isdefined( t2 ) )
				t2 Delete();
			return;
		}
		if ( IS_TRUE( level.tod_spire_door_bypassed ) && IS_TRUE( level.tod_dev ) )
			tod_quiet_print( "^1spire dev: door " + n + " BYPASSED — opened free (mover-class failure?)" );
		level.tod_spire_door_bypassed = undefined;
		if ( isdefined( t1 ) )
			t1 Delete();
		if ( isdefined( t2 ) )
			t2 Delete();

		if ( level flag::exists( info.flag ) )
			level flag::set( info.flag );   // zone chain + respawn groups

		open_door_slab( n );

		// THE HONOUR GUARD (v14.31, user: "maybe after every door buy a panzer
		// will spawn. 1-4 depending on players in game"). Spawned on the floor
		// just opened, so the reward for buying through is the thing you have
		// to fight in the room you just paid for.
		// v16.19: NOT at a hub door — the Wardens are that floor's guard, and an
		// honour guard on the hall floor would only be wiped the moment the
		// party stepped through the door behind it.
		if ( !( tod_spire_data::is_hub( n ) ) )
			level thread door_guard_panzers( n );

		// (v16.15-v16.20 armed the hub's trial watcher HERE, on the buy. The
		// v16.21 watcher covers every hub from ascension on presence alone —
		// a hall reached by any other path, the dev warp included, arms too.)

		// The riser gate: v14.36 door n opens exactly ONE floor, so spawns may
		// rise to that floor's end landing (door z + LAP_RISE 384, +16 slack)
		// — and past the last door, the summit itself. (Was +784 while a door
		// covered two floors; leaving it there would wake risers a full floor
		// above the highest bought door, which is the stranded-actor trap the
		// gate exists to prevent.)
		if ( n >= tod_spire_data::spire_door_count() )
			level.tod_spire_door_max_z = tod_spire_data::spire_summit_z() + 600;
		else
			level.tod_spire_door_max_z = tod_spire_data::spire_door_z( n ) + 400;
	}
	level.tod_spire_next_door_z = undefined;   // climb complete; watchdog idles
	level.tod_spire_next_door_n = undefined;
}

// (seal_window() was deleted in v18.0 with the clock seal — see the
// TOD_SPIRE_DOOR_SEAL_SECS retirement note at the top of this file. Its
// "^1SEALED^7 - hold this floor" literal went with it, so the mode's whole
// triggerstring cost is now TWO constants: the price in spire_door_hint and the
// trial literal in trial_sealed_hint. Neither interpolates, so re-stamping them
// across all 70 doors mints no further slots. See the 250-cap rule.)

// TRUE while this door refuses the buy. ONE reason left: the hub below has an
// unwon trial (trial_seal_window owns the flag, and its hint already says so —
// spire_door_buy's refusal is the audible echo).
function seal_active()
{
	return IS_TRUE( level.tod_spire_trial_seal );
}

// THE TRIAL SEAL WINDOW (v16.15) — door n+1's triggers read the trial literal
// until hub n's trial is won, then flip to the price. Polled, not waittill'd:
// the trial can only ever be won AFTER these triggers exist (door_manager
// spawns them the moment door n is bought), but a poll costs nothing and
// cannot miss.
//
// TRIGGERSTRING COST: ONE constant literal, shared by every trial door and
// the summit (trial_sealed_hint). Leads with SEALED — a TOD_NOUN — so it
// routes to the default card exactly like the 12 s seal's literal.
function trial_seal_window( t1, t2, hub )
{
	level endon( "end_game" );

	level.tod_spire_trial_seal = true;
	if ( isdefined( t1 ) )
		t1 SetHintString( trial_sealed_hint() );
	if ( isdefined( t2 ) )
		t2 SetHintString( trial_sealed_hint() );

	while ( !IS_TRUE( level.tod_spire_trial_won[ hub ] ) )
		wait 0.5;

	level.tod_spire_trial_seal = undefined;
	if ( isdefined( t1 ) )
		t1 SetHintString( spire_door_hint() );
	if ( isdefined( t2 ) )
		t2 SetHintString( spire_door_hint() );
}

// THE SUMMIT PAD'S OWN SEALED LINE. Leads with SEALED (a TOD_NOUN) like the
// door literal, so routing is identical - but it names the summit, which lets
// the prompt card give it the EXTRACTION icon instead of a door.
function summit_sealed_hint()
{
	return ( "^1SEALED^7 - win the summit trial to extract" );
}

function trial_sealed_hint()
{
	return ( "^1SEALED^7 - win the trial in the arena below" );
}

// THE HONOUR GUARD — one Panzer per living player, capped at 4, dropped onto
// the floor door n just opened, staggered so they arrive as a procession
// rather than a pile (pick_spawn_point scatters clear of living bosses, and
// the stagger gives it room to work on a 160-wide spiral).
//
// SPAWNED DIRECTLY, NOT VIA THE DIRECTOR: finale_beat_panzer carries a hard
// 4-elite ceiling meant for the ending, and the director's own gate reads
// panzer_max_alive() (1, or 2 on rampage) — either would silently deliver one
// Panzer instead of four. Going straight to spawn_panzer means THIS function
// owns the bookkeeping the director normally does, which is why the standing
// count is checked here against TOD_SPIRE_GUARD_MAX.
function door_guard_panzers( n )
{
	level endon( "end_game" );

	want = GetPlayers().size;
	if ( want > TOD_SPIRE_GUARD_MAX )
		want = TOD_SPIRE_GUARD_MAX;
	if ( want < 1 )
		return;

	org = tod_spire_data::guard_spawn_org( n );

	for ( i = 0; i < want; i++ )
	{
		// Standing-count guard: doors are >= the seal apart, but a party that
		// leaves Panzers alive and buys onward must not compound them into an
		// actor-budget failure (TOD_ACTOR_LIMIT 60 is the real ceiling, and a
		// Panzer is expensive). Skip rather than queue — a missed guard is a
		// gift, a stalled actor pool is a broken run.
		if ( isdefined( level.tod_panzer_alive ) && level.tod_panzer_alive >= TOD_SPIRE_GUARD_MAX )
			return;
		// ⚠️ AND THE COMBINED ELITE ROOF (v15, item 2 candidate #2). The line
		// above counts PANZERS ONLY, so this lane could add guards on top of a
		// spire already holding its full TOD_ELITE_ROOF_ALL of protectors,
		// reavers and hounds — the one elite spawner in the map that bypassed
		// the shared ceiling. Under the endless-rounds twist that is not a
		// difficulty bug but a ROUND-PROGRESSION bug: the next round starts when
		// the last zombie SPAWNS, so an actor pool wedged by elites stops trash
		// spawning, and the round counter simply stops. That is the reported
		// "rounds dont continue in endless spire" symptom.
		// Same skip-rather-than-queue doctrine as above.
		if ( tod_bosses::elites_over_roof() )
			return;

		level.tod_boss_force_org = org;      // consume-once, read by spawn_panzer
		boss = tod_bosses::spawn_panzer();
		if ( isdefined( boss ) )
			boss.tod_spire_guard = true;     // elite payout, not the boss jackpot (panzer_life)
		else
			level.tod_boss_force_org = undefined;   // spawn_panzer's early returns sit
			                                        // ABOVE its consume site, so a refusal
			                                        // would arm THIS door's anchor for the
			                                        // next Panzer anywhere in the run

		wait TOD_SPIRE_GUARD_STAGGER;
	}
}

// The tower door contract, verbatim (_tod_doors' slab open): hide once,
// never move, never re-show.
function open_door_slab( n )
{
	slab = GetEnt( "tod_spire_door" + n, "targetname" );
	if ( !isdefined( slab ) )
		return;
	slab Hide();
	slab NotSolid();
	slab ConnectPaths();
	tod_bosses::dev_ai_gate( slab, "connect" );
}

// DEV ONLY (v17.56, user 2026-09-04: "In dev mode we need to open all spire
// doors as well"). Called from _tod_main's dev harness after the ascension.
// Ship builds never reach it. Mirrors what a real buy does for every one of
// the 100 doors — the flag (zone chain + respawn groups), the slab (Hide /
// NotSolid / ConnectPaths, the nav cut), and the riser gate — and stands the
// sequential door_manager down through level.tod_spire_dev_all_open, so no
// buy trigger is ever spawned into an open doorway and the bypass watchdog
// idles (next_door_z undefined). The trials are untouched: the hall gate
// still closes on presence, and the door above a hub is simply open, exactly
// like every other door. No honour guard, no seals — the dev session is for
// reaching places, not fighting through them. Spread 8-per-frame like init.
function dev_open_all_doors()
{
	level.tod_spire_dev_all_open = true;
	level notify( "tod_spire_dev_all_open" );   // a manager mid-sale retires its pair and returns
	level.tod_spire_next_door_z = undefined;
	level.tod_spire_next_door_n = undefined;

	for ( n = 1; n <= tod_spire_data::spire_door_count(); n++ )
	{
		if ( level flag::exists( "enter_spire" + n ) )
			level flag::set( "enter_spire" + n );
		open_door_slab( n );
		if ( ( n % 8 ) == 0 )
			wait 0.05;
	}

	level.tod_spire_door_max_z = tod_spire_data::spire_summit_z() + 600;
	IPrintLnBold( "DEV: all " + tod_spire_data::spire_door_count() + " spire doors open" );
}

// A player standing 250+ up the flight a sealed door guards is PAST it —
// impossible unless the door failed. Open it free rather than let the zone
// chain strand (the un-set flags are what turned the v14.1 mover failure
// into instakills). Dies with the game.
//
// v19.76 — A TRIAL DOOR IS NEVER OPENED THIS WAY (lead tester Nikolai, Oct 2026:
// "just landed ran all the way up tower two not stopping for any trial, then you
// can fight the throne trial without completing prior trials and then can run up
// to the summit and finish the game"). The free-open above was written for a
// FAILED door; it never asked WHY the door was shut, so a door that was shut
// because its hall's trial is unbeaten opened for anyone who got past it some
// other way (a wall-run onto the hall's gallery, a jump off a hall platform) -
// and the next trial door the same way, all the way to the King. A trial-sealed
// door cannot have FAILED: nothing could open it yet. So a player found above
// one is sent back into that hub's hall instead (trial_bypass_return), and the
// door stays shut until the trial is won, exactly as trial_seal_window intends.
// 0.5 s cadence (was 1 s), so the trip back is prompt.
function door_bypass_watchdog()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait 0.5;
		if ( !isdefined( level.tod_spire_next_door_z ) )
			continue;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
				continue;
			if ( !( tod_spire_data::in_spire( p.origin ) ) )
				continue;
			if ( p.origin[ 2 ] > ( level.tod_spire_next_door_z + 250 ) )
			{
				hub = trial_hub_for_sale();
				if ( seal_active() && hub > 0 )
				{
					p trial_bypass_return( hub );
					continue;   // the others are judged on their own feet
				}
				level.tod_spire_door_bypassed = true;
				level notify( "tod_spire_door_bought" );
				break;
			}
		}
	}
}

// The hub whose UNWON trial seals the door currently for sale, or 0.
function trial_hub_for_sale()
{
	if ( !isdefined( level.tod_spire_next_door_n ) )
		return 0;
	return tod_spire_data::trial_hub_of_door( level.tod_spire_next_door_n );
}

// self = a living player found above a trial-sealed door. Back into the hub's
// hall, on the floor round the trial mark (the spot the win's Max Ammo lands,
// clear of every hall feature by the generator's asserts), one slot per client
// so a party sent back together does not land inside itself. The navmesh snap
// keeps the slot on the hall floor whatever the layout puts near the mark.
// A downed player is left where they are: last stand owns them, and the bleed
// out respawns them on a valid floor.
function trial_bypass_return( hub )
{
	if ( self laststand::player_is_in_laststand() )
		return;
	z = tod_spire_data::hub_z( hub );
	mark = tod_spire_data::trial_mark_org( hub, z );
	slot = self GetEntityNumber() % 4;
	dest = mark + ( 48 * Cos( 90 * slot ), 48 * Sin( 90 * slot ), 0 );
	snap = GetClosestPointOnNavMesh( dest, 64, 15 );
	if ( !isdefined( snap ) )
		snap = mark;
	from = self.origin;
	self SetVelocity( ( 0, 0, 0 ) );
	self SetOrigin( snap + ( 0, 0, 4 ) );
	self PlayLocalSound( "zmb_no_purchase" );
	tod_perk_scatter::play_sound_at_origin( snap, "tod_teleport_fire", 4 );
	level thread tod_teleport::fx_burst( "tod_tp_charge", snap + ( 0, 0, 40 ), 1.0 );
	self tod_upgrade_ui::toast( TOD_TOAST_TRIAL_SEALED, hub );
	// Rare (a bypass attempt), so it prints in every developer run, not only
	// tod_dev ones: this line IS the evidence for the fix in the user's test.
	line = "[TOD_SPIRE] TRIAL_BYPASS_BLOCKED ms=" + GetTime() + " player=" + self GetEntityNumber()
		+ " door=" + level.tod_spire_next_door_n + " hub=" + hub + " from=" + from + " to=" + snap;
	/#
	PrintLn( line );
	#/
}

function spire_door_trigger( pos, info )
{
	t = Spawn( "trigger_radius_use", pos, 0, 96, 100 );
	if ( !isdefined( t ) )
		return undefined;
	t TriggerIgnoreTeam();
	t SetCursorHint( "HINT_NOICON" );
	// CONSTANT DESTINATION — the 250-triggerstring cap (2026-08-30). This used to
	// interpolate info.dest ("the Spire - Floor 1".."Floor 100"), minting ONE
	// PERMANENT BG-cache 'triggerstring' slot per floor climbed. The engine caps
	// that cache at 250 UNIQUE strings for the WHOLE MATCH and never frees a slot
	// — not on trigger Delete(), not between rounds — and the overflow blames
	// whoever registers NEXT, not the accumulator (map 1's Thundergun trap).
	// The tower already sits near ~242 by the time the finale is won, so the
	// spire did not need 100 floors to hard-error; it needed about EIGHT. This
	// mode was broken on arrival and nobody had reached it to report it.
	// The price stays: spire doors are a flat constant (generated door_cost, 4500
	// since v16.30), so it costs ONE string per party size.
	// "Open Door to <dest>" shape kept EXACTLY — PromptDoors.lua parses the
	// destination out of it for the card title; "the Spire" is what it reads now.
	// If the floor number is ever wanted on screen, put it in an IPrintLnBold on
	// buy — chat prints provably do NOT feed this cache.
	t SetHintString( spire_door_hint() );
	t thread spire_door_buy( info );
	return t;
}

// ONE literal, one slot (v14.31). Factored out because seal_window re-stamps
// it after the seal expires and a second copy of the string would be a second
// permanent triggerstring slot the moment the two texts ever drifted apart.
function spire_door_hint()
{
	// v16.30: the base price comes from the GENERATED data (door_cost), the same
	// constant spire_door_buy charges through info.cost — this literal carried
	// its own 3000 beside it for two versions, one price with two sources.
	return ( "Hold ^3[{+activate}]^7 Open Door to the Endless Spire ^2[Cost: " + tod_doors::door_price( tod_spire_data::door_cost() ) + "]" );
}

// self = trigger. The tower door loop's guards, verbatim — every one of them
// was paid for (revive presses, upgrade freezes, menu freezes).
function spire_door_buy( info )
{
	level endon( "end_game" );
	level endon( "tod_spire_door_bought" );
	for ( ;; )
	{
		self waittill( "trigger", player );
		if ( !isdefined( player ) || !IsPlayer( player ) )
			continue;
		if ( player zm_utility::in_revive_trigger() )
			continue;
		if ( !( zm_utility::is_player_valid( player ) ) )
			continue;
		if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( player.tod_menu_frozen ) )
			continue;
		// THE SEAL (v14.31): refuse with the deny sound, never silently — a
		// mute refusal reads as a dead trigger (the 2026-08-26 "teleporter
		// wasn't activated" lesson, and the same reason the altar's pause
		// branch speaks). The hint already says SEALED, so this is the echo.
		if ( seal_active() )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		price = tod_doors::door_price( info.cost );
		if ( !( player zm_score::can_player_purchase( price ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		player zm_score::minus_to_player_score( price );
		player PlaySound( "zmb_cha_ching" );
		level notify( "tod_spire_door_bought" );
		return;
	}
}

// ---------------------------------------------------------------------------
// THE CRATE WINDOW — "an ammo crate at every floor", at ~5 floors of live
// entities. Shelf crates materialize for floors near any player and de-rez
// beyond the window. Their collision is a RESIDENT .map box since v17.38 (the
// generator's shelfCrateBox, label "... shelf ammo crate body", whitelisted by
// the lint's MODEL_CLIP_COLUMNS): an empty shelf with a box on it is only ever
// seen by a player who is >3 floors away from it, because standing on the
// shelf puts you inside the window. The old "script clips so the shelf is
// clean when empty" reasoning bought a collider that matched neither the mesh
// nor its yaw, on a 128-deep ledge where every unit counts.
// ---------------------------------------------------------------------------

function crate_window()
{
	level endon( "end_game" );

	crates = [];   // floor -> crate struct
	for ( ;; )
	{
		wait 2;

		// Which floors should hold a live crate right now?
		want = [];
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
				continue;
			if ( !( tod_spire_data::in_spire( p.origin ) ) )
				continue;
			f = 1 + int( p.origin[ 2 ] / 384 );
			for ( d = f - TOD_SPIRE_CRATE_WINDOW; d <= f + TOD_SPIRE_CRATE_WINDOW; d++ )
			{
				if ( isdefined( tod_spire_data::shelf_crate_org( d ) ) )
					want[ d ] = true;
			}
		}

		// De-rez crates that fell out of the window.
		keys = GetArrayKeys( crates );
		for ( i = 0; i < keys.size; i++ )
		{
			f = keys[ i ];
			if ( IS_TRUE( want[ f ] ) )
				continue;
			delete_crate( crates[ f ] );
			crates[ f ] = undefined;
		}

		// Materialize the window's missing crates.
		wkeys = GetArrayKeys( want );
		for ( i = 0; i < wkeys.size; i++ )
		{
			f = wkeys[ i ];
			if ( isdefined( crates[ f ] ) )
				continue;
			org = tod_spire_data::shelf_crate_org( f );
			if ( !isdefined( org ) )
				continue;
			crates[ f ] = spawn_crate( org, tod_spire_data::shelf_crate_yaw( f ) );
		}
	}
}

// ---------------------------------------------------------------------------
// THE SUMMIT — the top's chosen ending (approved): extraction at the roof
// door's price. Survive the climb, buy the ride, win the mode.
// v17.69: THE TOP is the future BOSS FLOOR (user 2026-09-05: "after the 7th
// trial the next level leads to the top of the tower where we will have a
// boss fight. For now we can just have an extraction up there"). The pad and
// its gate are unchanged; the boss fight is the follow-up and will replace
// (or precede) the buy loop below — level.tod_finale_boss_fn is the crown's
// slot for the same idea.
// ---------------------------------------------------------------------------

function summit_station()
{
	level endon( "end_game" );

	org = tod_spire_data::summit_exfil_org();
	pad = Spawn( "script_model", org );
	if ( isdefined( pad ) )
	{
		pad SetModel( "p7_out_mech_spawn_pad_light_green" );
		tod_perk_lights::set_glow( pad, TOD_SPIRE_GLOW_GREEN );
	}
	beacon = Spawn( "script_model", tod_spire_data::beacon_org() );
	if ( isdefined( beacon ) )
	{
		beacon SetModel( "tag_origin" );
		tod_perk_lights::set_glow( beacon, TOD_SPIRE_GLOW_RED );
	}

	// v17.70 THE SUMMIT CRATE — the one crate contract (spawn_crate), a flat
	// TOD_KING_CRATE_COST for any gun (use_loop reads the trigger's override).
	c = spawn_crate( tod_spire_data::summit_crate_org(), tod_spire_data::summit_crate_yaw() );
	if ( isdefined( c ) && isdefined( c.t ) )
	{
		c.t.tod_crate_cost = TOD_KING_CRATE_COST;
		c.t SetHintString( king_crate_hint() );
	}

	t = Spawn( "trigger_radius_use", org + ( 0, 0, 24 ), 0, 110, 96 );
	t TriggerIgnoreTeam();
	t SetCursorHint( "HINT_NOICON" );
	price = tod_doors::door_price( tod_spire_data::summit_cost() );
	// v16.15 — THE LAST TRIAL GUARDS THE SUMMIT. The last hub's hall is the
	// flight below this pad; until its trial is won the pad reads the trial
	// literal (one string, shared with the trial doors) and the buy loop is not
	// entered. A spire without a hub on its top floor skips this entirely.
	top = tod_spire_data::spire_laps();
	if ( tod_spire_data::is_hub( top ) )
	{
		// v19.3: ITS OWN LITERAL, NOT THE DOOR ONE. This pad used to share
		// trial_sealed_hint() with all 70 spire doors, and the prompt card
		// resolves that string's "sealed" to the DOOR icon - so a player
		// standing on the extraction beacon was shown a door. Costs one
		// triggerstring slot (94 -> 95 of 190 budgeted) and names the object.
		t SetHintString( summit_sealed_hint() );
		while ( !IS_TRUE( level.tod_spire_trial_won[ top ] ) )
			wait 0.5;
	}
	// v17.70 THE WARDEN KING holds the summit between the last trial and the
	// extraction: the pad reads SEALED (one constant string) until he falls.
	t SetHintString( king_sealed_hint() );
	king_fight();
	summit_hint_stamp( t, price );

	for ( ;; )
	{
		t waittill( "trigger", player );
		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( !( zm_utility::is_player_valid( player ) ) )
			continue;
		if ( player zm_utility::in_revive_trigger() )
			continue;
		// NOT DURING A FREEZE (v17.61) — the same refusal every spire door makes
		// (spire_door_buy). The summit's own trial ends in a frozen reward now,
		// held from the last chord through the card deal, and this trigger sits
		// inside that hall: a player with no card coming could otherwise end the
		// run while a teammate is still mid-pick on a board that cannot move.
		// Refused with the deny sound, never silently (the "wasn't activated"
		// lesson); the hint already reads as a live buy, so this is the echo.
		if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( player.tod_menu_frozen ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		price = tod_doors::door_price( tod_spire_data::summit_cost() );
		if ( !( player zm_score::can_player_purchase( price ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		player zm_score::minus_to_player_score( price );
		player PlaySound( "zmb_cha_ching" );
		break;
	}

	t SetHintString( "^2EXTRACTING...^7" );
	level thread summit_win( org, beacon );
}

// The summit's own extraction prompt. Deliberately a DIFFERENT literal from
// the tower's (_tod_finale.gsc "opens the road to the crown") — two distinct
// strings, as before, because the two prompts end two different runs. ONE
// site (v16.15 factored it out of summit_station so the post-trial re-stamp
// could not grow a second copy of the string).
function summit_hint_stamp( t, price )
{
	t SetHintString( "Hold ^3[{+activate}]^7 ^2CALL EXTRACTION^7 - conquer the spire ^2[Cost: " + price + "]" );
}

function summit_win( org, beacon )
{
	// NO endon(end_game): this thread IS what ends the game (depart's rule).
	level.tod_spire_won = true;

	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p EnableInvulnerability();
		p.ignoreme = true;
	}

	// Six seconds of send-off: the beacon strobes green over the world it
	// conquered, strike bursts walk the pad — depart_show's grammar.
	for ( k = 0; k < 15; k++ )
	{
		on = ( ( k % 2 ) == 0 );
		if ( isdefined( beacon ) )
			tod_perk_lights::set_glow( beacon, ( ( on ) ? TOD_SPIRE_GLOW_GREEN : 0 ) );
		if ( ( k % 3 ) == 0 )
			tod_perk_scatter::derez_burst( org );
		wait 0.4;
	}

	level notify( "end_game" );
}

// ---------------------------------------------------------------------------
// THE WARDEN KING (v17.70) — THE TOP IS THE BOSS FLOOR. The defines' block
// comment is the user's design. The shape is the trial's, reused on purpose:
//   presence  -> trial_all_in( summit_box ): everyone alive on the arena deck
//                (the stair well is excluded so nobody in the gate's volume
//                counts as in), a 2 s tell, a re-check.
//   the seal  -> wipe, state, the SUMMIT GATE (hall-gate contract) + the
//                ritual barrier along the stair's mouth, his own track
//                (tod_music_king), the countdown.
//   the bar   -> level.tod_king_hp_frac, read by _tod_gauge::finale_cell: the
//                spire bar is FULL (summit lit) as he lands and drains with
//                his health — zero LUI bits, zero art.
//   the max   -> a frozen world: tod_upgrades::king_max_out (every domain to
//                cap) then king_dark_deals (dark-only 10 s deals until nobody
//                has one left; everyone frozen throughout).
//   the fight -> the king (tod_king: 2x flame box + a second cone, 2x flame
//                and zap range through _tod_bosses' BT twins, 100M) and his
//                summons (elite debts SET on a cadence; risers + elites are
//                kept inside the box by the trial's own containment fields:
//                tod_trial_active + tod_trial_box). He is the only Panzer:
//                _tod_bosses' director and round_watch read tod_king_active.
//   the win   -> the purse, a Max Ammo on the mark, the extraction unseals
//                (summit_station's re-stamp). The gate STAYS SHUT since v19.76
//                (the summit is the end of the road; king_win keeps the box).
// _tod_finale ↔ _tod_spire keep their notify-only contract; the king lives
// here because the summit does.
// ---------------------------------------------------------------------------

function king_sealed_hint()
{
	return ( "^1SEALED^7 - the Warden King holds the summit" );
}

function king_crate_hint()
{
	return ( "Hold ^3[{+activate}]^7 ^5AMMO CRATE^7 - the summit's tithe ^2[Cost: 1000]" );
}

function king_fight()
{
	level endon( "end_game" );

	box = tod_spire_data::summit_box();
	gate_org = tod_spire_data::summit_gate_org();
	for ( ;; )
	{
		wait 0.5;
		if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( level.tod_trial_active ) )
			continue;
		if ( !trial_all_in( box ) )
			continue;
		level thread tod_teleport::fx_burst( "tod_tp_charge", gate_org + ( 0, 0, 40 ), TOD_TRIAL_CLOSE_SECS );
		tod_perk_scatter::play_sound_at_origin( gate_org, "tod_teleport_fire", 4 );
		wait TOD_TRIAL_CLOSE_SECS;
		if ( trial_all_in( box ) )
			break;
	}
	king_run( box );
}

// ONLY THE SUMMIT'S RESPAWN GROUP STAYS OPEN ONCE IT SEALS (v19.76 review).
// The gate stays shut after the King now, so a teammate who respawns must come
// back ON the deck. Stock respawns a player at the unlocked group nearest a
// living teammate (_zm.gsc check_for_valid_spawn_near_team), and hub 70's
// group sits in the hall UNDER the deck - nearer than the summit's own group to
// a teammate on the deck's west half (the King's drop, the mark, the crate).
// Before v19.76 that stranded them only until the win opened the gate; now it
// would be for good, and the zombies (all held on the deck by the kept box)
// could never reach them. Stock skips a locked group, and its only unlocker,
// enable_zone, returns early for a zone already enabled - which every spire
// zone is by the seal, since the summit chains off the last door. If even the
// summit group were refused, stock respawns the player where they died, which
// is on the deck too.
function summit_respawn_only()
{
	spz = tod_spire_data::spire_zone_names();
	summit = spz[ spz.size - 1 ];
	locked = 0;
	kept = 0;
	foreach ( s in struct::get_array( "player_respawn_point", "targetname" ) )
	{
		if ( isdefined( s.script_noteworthy ) && s.script_noteworthy == summit )
		{
			kept++;
			continue;
		}
		s.locked = true;
		locked++;
	}
	king_log( "RESPAWN_LOCK summit=" + summit + " kept=" + kept + " locked=" + locked );
}

function king_run( box )
{
	level endon( "end_game" );

	gate = GetEnt( tod_spire_data::summit_gate_target(), "targetname" );
	gate_org = tod_spire_data::summit_gate_org();
	mark = tod_spire_data::summit_mark_org();

	// 1. THE SEAL — the trial's recipe: board cleared, state first (the spawn
	// systems read these this frame), then the gate and the wall.
	wipe_all_zombies();
	level.tod_king_active = true;
	level.tod_trial_active = true;      // the hottest trickle (_tod_endless_rounds)
	level.tod_trial_box = box;          // every riser + every elite inside the arena
	level.tod_trial_reserve = 0;
	level.tod_panzer_debt = 0;
	// ...AND THE FOUR FAMILY DEBTS (v17.94). Trial VII's adds SET them and
	// nothing zeroed them at its win, so the ten-second countdown below drained
	// them into fresh elites on the summit deck — the Furys the user met during
	// the dark deals came from HERE, not from his summons (king_summons starts
	// after the deals). The board is cleared; the debts are part of the board.
	level.tod_protector_debt = 0;
	level.tod_reaver_debt = 0;
	level.tod_hound_debt = 0;
	level.tod_sprinter_debt = 0;
	level.zombie_vars[ "zombie_spawn_delay" ] = king_spawn_floor();   // v18.75: one notch hotter under rampage
	hosts = king_barrier_up( gate_org );
	if ( isdefined( gate ) )
	{
		gate Show();
		gate Solid();
		gate DisconnectPaths();
		tod_bosses::dev_ai_gate( gate, "disconnect" );
	}
	summit_respawn_only();
	Earthquake( 0.5, 1.2, gate_org, 1400 );
	tod_perk_scatter::play_sound_at_origin( gate_org, "tod_teleport_fire", 4 );
	tod_atmosphere::channel_play( "tod_music_king" );
	level thread trial_banner( 0, "tod_king_banner" );   // v17.71: the baked plate (docs/106)
	// 2026-10-01: his landing spot burns - a red ring that tightens on a
	// quickening heartbeat for exactly the countdown below.
	level thread king_countdown_fx( TOD_KING_COUNTDOWN_SECS );

	// 2. THE COUNTDOWN
	level.tod_king_landing = true;   // event_scheduler deals nothing until the dark deals are done
	wait TOD_KING_COUNTDOWN_SECS;

	// 3. THE LANDING — spawn_panzer's own drop-in, forced onto the king's org.
	// It can refuse (no anchor player, a pause); a few tries, then the
	// fail-safe: no king means no lock, the extraction opens.
	//
	// WAIT OUT A CARD PAUSE FIRST (bug review 2026-09-22, F03): spawn_panzer
	// returns undefined for as long as level.tod_upgrade_pause holds, and a
	// scheduled every-4th-round deal could open during the countdown and hold
	// the pause for up to 20 s — four 1 s tries all failed and the fail-safe
	// skipped the whole fight. The pause is now waited out before each try
	// (bounded: no deal outlives choice_timeout()+5), and tod_king_landing
	// keeps the scheduler from opening one here at all.
	boss = undefined;
	for ( attempt = 0; attempt < 4 && !isdefined( boss ); attempt++ )
	{
		waited = 0;
		while ( IS_TRUE( level.tod_upgrade_pause ) && waited < 40 )
		{
			wait 0.25;
			waited += 0.25;
		}
		if ( waited > 0 )
			king_log( "LANDING waited " + waited + " s for a card pause to clear" );
		level.tod_boss_force_org = tod_spire_data::summit_king_org();
		boss = tod_bosses::spawn_panzer();
		if ( !isdefined( boss ) )
		{
			level.tod_boss_force_org = undefined;
			king_log( "LANDING attempt=" + attempt + " refused pause=" + IS_TRUE( level.tod_upgrade_pause ) );
			wait 1;
		}
	}
	if ( !isdefined( boss ) )
	{
		king_log( "LANDING FAILED after 4 tries -> king_win(false), no fight" );
		level.tod_king_landing = undefined;
		king_win( gate, hosts, mark, false );
		return;
	}
	king_log( "LANDING ok" );
	king_setup( boss );
	level.tod_king_hp_frac = 1.0;
	level thread king_hp_bar( boss );

	// 4. THE MAX-OUT — the world (the king included) frozen from here to the
	// last dark card; the freeze is ours to release after the deals. Since
	// v17.94 the pause also makes every upright player invulnerable and parks
	// any Fury's behaviour tree (boss_pause_watch) — the first real run had
	// Furys bamfing onto frozen players through the deals.
	tod_upgrades::set_world_pause( true );
	wait 1.0;
	tod_upgrades::king_max_out();
	wait 0.5;
	tod_upgrades::king_dark_deals();
	// A teammate who was dead at the landing respawns during the fight with
	// the pre-summit build; on_spire_spawned reads this and maxes them too
	// (bug review 2026-09-22, F07).
	level.tod_king_maxed_done = true;
	level.tod_king_landing = undefined;
	if ( IS_TRUE( level.tod_upgrade_pause ) && !isdefined( level.tod_station_pause_owner ) )
		tod_upgrades::set_world_pause( false );

	// 5. THE FIGHT
	trial_sting();
	level thread king_summons( boss );
	level thread king_phase_watch( boss );   // v18.96: his phases (after the max-out freeze is released — no beat inside it)
	if ( king_rampage() )
		level thread king_horde_sprint( box );   // v18.75
	while ( isdefined( boss ) && isalive( boss ) )
		wait 0.25;
	king_win( gate, hosts, mark, true );
}

// v18.75 — THE ONE GATE for every King-under-rampage lever. Field-read like
// every other consumer; _tod_rampage is the only writer, no import either way.
function king_rampage()
{
	return IS_TRUE( level.tod_rampage_on );
}

function king_spawn_floor()
{
	if ( king_rampage() )
		return TOD_KING_RAMPAGE_SPAWN_FLOOR;
	return TOD_TRIAL_SPAWN_FLOOR;
}

function king_summon_secs()
{
	if ( king_rampage() )
		return TOD_KING_RAMPAGE_SUMMON_SECS;
	// v18.96 — his phases (health-owned); never slower than rampage's figure.
	if ( isdefined( level.tod_king_phase ) && level.tod_king_phase >= 3 )
		return TOD_KING_RAMPAGE_SUMMON_SECS;
	if ( isdefined( level.tod_king_phase ) && level.tod_king_phase >= 2 )
		return TOD_KING_PHASE_2_SUMMON_SECS;
	return TOD_KING_SUMMON_SECS;
}

function king_summon_prot()
{
	if ( king_rampage() )
		return TOD_KING_SUMMON_PROT + TOD_KING_RAMPAGE_SUMMON_PROT_ADD;
	return TOD_KING_SUMMON_PROT;
}

function king_summon_hound()
{
	if ( king_rampage() )
		return TOD_KING_SUMMON_HOUND + TOD_KING_RAMPAGE_SUMMON_HOUND_ADD;
	return TOD_KING_SUMMON_HOUND;
}

// v18.75 — HIS SPRINT (rampage only; see the defines). Locomotion only: flame
// and claw keep firing. Skips the world pause so the max-out freeze is not
// argued with; ends with him or with the fight.
function king_sprint( boss )
{
	level endon( "end_game" );
	level endon( "tod_king_end" );
	boss endon( "death" );

	level.tod_king_sprint_on = true;   // v18.96: one sprint thread ever (the phase-2 lever checks this)
	while ( isdefined( boss ) && isalive( boss ) )
	{
		if ( !IS_TRUE( level.tod_upgrade_pause ) )
			Blackboard::SetBlackBoardAttribute( boss, TOD_KING_RAMPAGE_BB_SPEED, TOD_KING_RAMPAGE_BB_SPRINT );
		wait TOD_KING_RAMPAGE_SPRINT_TICK;
	}
}

// v18.75 — THE HORDE ON THE DECK (rampage only). Stamps the sprinter's round
// offset on every ordinary zombie inside the summit box that does not already
// carry one; the speed module's keep-alive sweep applies it within 1.5 s.
// Bosses and elites are skipped by the same triad the speed path uses, and a
// zombie that already has an offset (an armored sprinter) keeps its own.
function king_horde_sprint( box )
{
	level endon( "end_game" );
	level endon( "tod_king_end" );

	while ( IS_TRUE( level.tod_king_active ) )
	{
		foreach ( ai in GetAITeamArray( level.zombie_team ) )
		{
			if ( !isdefined( ai ) || !IsAlive( ai ) )
				continue;
			if ( IS_TRUE( ai.is_boss ) || IS_TRUE( ai.acc_is_boss ) || IS_TRUE( ai.acc_is_mini_boss ) || IS_TRUE( ai.tod_boss_custom_speed ) )
				continue;
			if ( isdefined( ai.tod_zspeed_round_add ) )
				continue;
			if ( !tod_spire_data::in_box( ai.origin, box ) )
				continue;
			ai.tod_zspeed_round_add = TOD_KING_RAMPAGE_HORDE_ADD;
		}
		wait 1.0;
	}
}

// THE WALL, sized to the party. Read ONCE, at king_setup — the same standing
// every other boss in this map has (boss_hp resolves its coop multiplier at
// spawn too), so a player joining or leaving mid-fight never moves a health bar
// that is already draining on screen. Counts CONNECTED players, not living
// ones: a teammate bleeding out is still in the fight and still coming back.
function king_hp()
{
	n = GetPlayers().size;
	if ( n < 1 )
		n = 1;
	if ( n > TOD_KING_HP_MAX_PLAYERS )
		n = TOD_KING_HP_MAX_PLAYERS;
	hp = n * TOD_KING_HP_PER_PLAYER;
	if ( king_rampage() )
		hp = int( hp * TOD_KING_RAMPAGE_HP_MULT );   // v18.75 — rampage's elite x1.5 never reached him (flat write below boss_hp)
	return hp;
}

// What the Panzer archetype needs changed for the king (the BT range twins
// read boss.tod_king in _tod_bosses; the electroball ring too).
function king_setup( boss )
{
	boss.tod_king = true;
	boss.tod_spire_guard = true;   // panzer_life pays the elite rate, not the jackpot — the purse is king_win's
	hp = king_hp();
	boss.maxhealth = hp;
	boss.health = hp;
	level.mechz_health = hp;   // the pack's part-health formulas read it live (spawn_panzer's own rule)
	// THE FLAME, 2x: stock's trigger_box( 200, 50, 25 ) on the muzzle tag,
	// replaced by one twice the size on the same tag — the burn loop reads
	// self.flameTrigger every tick, so the swap is the whole change.
	if ( isdefined( boss.flameTrigger ) )
		boss.flameTrigger Delete();
	ft = Spawn( "trigger_box", boss.origin, 0, 400, 100, 50 );
	if ( isdefined( ft ) )
	{
		ft EnableLinkTo();
		ft.origin = boss GetTagOrigin( "tag_flamethrower_fx" );
		ft.angles = boss GetTagAngles( "tag_flamethrower_fx" );
		ft LinkTo( boss, "tag_flamethrower_fx" );
		boss.flameTrigger = ft;
	}
	level thread king_flame_fx( boss );
	if ( king_rampage() )
		level thread king_sprint( boss );   // v18.75
}

// The second flame cone: while he flames (isShootingFlame, set by the port's
// start_ft / stop_ft), a tag_origin host linked TOD_KING_FLAME_FWD ahead of
// the muzzle plays the same castle cone; deleted when the flame stops.
function king_flame_fx( boss )
{
	level endon( "end_game" );

	host = undefined;
	while ( isdefined( boss ) && isalive( boss ) )
	{
		on = IS_TRUE( boss.isShootingFlame );
		if ( on && !isdefined( host ) )
		{
			host = Spawn( "script_model", boss GetTagOrigin( "tag_flamethrower_fx" ) );
			if ( isdefined( host ) )
			{
				host SetModel( "tag_origin" );
				host.angles = boss GetTagAngles( "tag_flamethrower_fx" );
				host LinkTo( boss, "tag_flamethrower_fx", ( TOD_KING_FLAME_FWD, 0, 0 ), ( 0, 0, 0 ) );
				// Replicate the host before emitting its one-shot event, as for
				// teleport hosts. Recheck the attack after yielding.
				wait 0.1;
				if ( isdefined( boss ) && isalive( boss ) && IS_TRUE( boss.isShootingFlame ) && isdefined( host ) )
					PlayFxOnTag( level._effect[ "tod_king_flame" ], host, "tag_origin" );
				else if ( isdefined( host ) )
				{
					host Delete();
					host = undefined;
				}
			}
		}
		else if ( !on && isdefined( host ) )
		{
			host Delete();
			host = undefined;
		}
		wait 0.05;
	}
	if ( isdefined( host ) )
		host Delete();
}

// THE BAR: his health as a fraction, read by _tod_gauge::finale_cell.
function king_hp_bar( boss )
{
	level endon( "end_game" );
	// v18.9 — AND THE WIN, which this thread was racing. Both watch the same boss
	// on different periods with no ordering: this polls at 0.2 s and ends by
	// writing 0, king_run polls the same predicate at 0.25 s and calls king_win,
	// which clears the field to undefined. Waits quantize to the 50 ms frame, so
	// 0.2/0.25 are 4 and 5 frames and king_run won outright in 6 cases of 20 with
	// 4 more same-frame ties — roughly a third to a half of King kills left
	// tod_king_hp_frac sitting at 0. _tod_gauge shadows on isdefined, not on a
	// value, so the spire bar stayed EMPTY for the rest of the run and took the
	// boss pip and all four teammate-down cells with it.
	//
	// king_win notifies this six lines before it clears the field, so the endon
	// removes the race entirely. Nothing here needs cleanup, so an endon is the
	// right tool (contrast the ASCEND retirer below, which does).
	level endon( "tod_king_end" );

	// v19.76 — THE BOSS BAR at the top of the screen reads this same fraction:
	// _tod_gauge's heartbeat turns it on while level.tod_king_hp_frac is defined
	// (his landing to king_win) and feeds it the value. It lives there, not here,
	// so it inherits that loop's per-life and per-game re-arm: a bar switched on
	// here and never switched off (a game over mid-fight, the HUD menu surviving
	// map_restart) would hide the next game's floor gauge and luck bar for good.
	while ( isdefined( boss ) && isalive( boss ) )
	{
		if ( isdefined( boss.maxhealth ) && boss.maxhealth > 0 )
			level.tod_king_hp_frac = ( boss.health * 1.0 ) / boss.maxhealth;
		wait 0.2;
	}
	level.tod_king_hp_frac = 0;
}

// HIS SUMMONS: every TOD_KING_SUMMON_SECS a tell at his feet and every family's
// debt SET to the recipe's figure — the directors deliver inside the box under
// their own roofs and the combined elite roof (never raised).
function king_summons( boss )
{
	level endon( "end_game" );
	level endon( "tod_king_end" );

	for ( ;; )
	{
		wait king_summon_secs();   // v18.75: 13 s under rampage, 18 otherwise
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;
		if ( !isdefined( boss ) || !isalive( boss ) )
			return;
		tod_perk_scatter::derez_burst( boss.origin );
		tod_perk_scatter::play_sound_at_origin( boss.origin, "tod_teleport_fire", 4 );
		// v18.75 — THE RAGE (rampage only): the stock mask-break berserk, ten
		// seconds of sprint-and-melee, on every call. Stock's own routine owns
		// the timer, the intro and the return to normal (mechz.gsc:869-908).
		if ( king_rage_on() )   // v18.96: rampage OR phase 3
			boss MechzBehavior::mechzGoBerserk();
		if ( tod_bosses::elites_over_roof() )
			continue;
		if ( level.tod_protector_debt < king_summon_prot() )
			level.tod_protector_debt = king_summon_prot();
		if ( !isdefined( level.tod_reaver_debt ) )
			level.tod_reaver_debt = 0;
		if ( level.tod_reaver_debt < TOD_KING_SUMMON_REAVER )
			level.tod_reaver_debt = TOD_KING_SUMMON_REAVER;
		if ( !isdefined( level.tod_hound_debt ) )
			level.tod_hound_debt = 0;
		if ( level.tod_hound_debt < king_summon_hound() )
			level.tod_hound_debt = king_summon_hound();
		if ( !isdefined( level.tod_sprinter_debt ) )
			level.tod_sprinter_debt = 0;
		if ( level.tod_sprinter_debt < TOD_KING_SUMMON_SPRINT )
			level.tod_sprinter_debt = TOD_KING_SUMMON_SPRINT;
	}
}

function king_barrier_up( gate_org )
{
	hosts = [];
	axis = tod_spire_data::summit_gate_axis();
	spread = tod_spire_data::summit_gate_len() / TOD_TRIAL_BARRIER_N;
	for ( i = 0; i < TOD_TRIAL_BARRIER_N; i++ )
	{
		off = axis * ( ( i - ( ( TOD_TRIAL_BARRIER_N - 1 ) / 2.0 ) ) * spread );
		h = Spawn( "script_model", gate_org + off );
		if ( !isdefined( h ) )
			continue;
		h SetModel( "tag_origin" );
		h.angles = ( 0, tod_spire_data::summit_gate_yaw(), 0 );
		hosts[ hosts.size ] = h;
	}
	level thread barrier_fx_late( hosts, "king" );   // 2026-10-01: never in the hosts' own frame
	return hosts;
}

// Every flag the fight set, cleared here and only here; the gate STAYS SHUT
// (v19.76) and the extraction unseals; the purse + the Max Ammo when he was actually slain (slain = false is
// the no-king fail-safe: the lock simply lifts).
function king_win( gate, hosts, mark, slain )
{
	level notify( "tod_king_end" );
	// v18.9 — the debt too. Without this, a boss round that passed during the
	// fight dropped an ordinary Panzer onto the summit deck the moment the King
	// died, under his own victory banner.
	level.tod_panzer_debt = 0;
	level.tod_king_active = undefined;
	level.tod_trial_active = undefined;
	// v19.76 — THE SUMMIT STAYS SEALED AFTER HIM (lead tester Nikolai, Oct 2026:
	// "when you complete the boss fight it also opens up the door to go back down
	// the tower ... maybe just make it so the wall doesn't disappear at the end,
	// forcing the player to end the game or continue to survive at the top"). The
	// gate stays solid and the purple ritual wall goes out (the seal is no longer a
	// fight, just the end of the road). The CONTAINMENT BOX STAYS TOO: with the
	// stair shut, a riser or an elite placed anywhere below the summit would be
	// stranded behind the gate holding a slot for the rest of the run - the exact
	// trap tod_trial_box exists to prevent (its readers: the riser filter, the
	// elite spawn-point filter and the stray culler). tod_trial_active still clears,
	// so the trickle and the boss director go back to their normal cadence.
	level.tod_trial_box = tod_spire_data::summit_box();
	level.tod_trial_reserve = undefined;
	level.tod_boss_force_org = undefined;
	level.tod_king_hp_frac = undefined;   // the bar goes back to being an altimeter (and v19.76: the boss bar goes, the gauge + luck bar come back)
	level.zombie_vars[ "zombie_spawn_delay" ] = TOD_SPIRE_SPAWN_FLOOR;
	trial_barrier_down( hosts );
	tod_atmosphere::channel_play( tod_atmosphere::band_alias() );
	if ( !slain )
		return;
	tod_bosses::grant_boss_reward( "KING", TOD_KING_WIN_PTS, false );
	level thread trial_ammo_drop( mark );
	trial_sting();
	level thread trial_banner( 0, "tod_king_dead" );   // v17.71: the baked plate (docs/106)
	tod_perk_scatter::derez_burst( mark );
}

// ---------------------------------------------------------------------------
// THE WARDEN TRIALS (v16.15 -> v16.21) — the defines' block comment is the
// design. v16.21 (user 2026-09-02, after the FIRST REAL RUN — "I was able to
// easily walk in and out ... the entrance is tiny ... toned down about 15%
// ... each level should have its own unique structure ... maybe even in
// bosses too ... 7% increments ... max perks on completion"):
//
//   ONE WATCHER FOR EVERY HUB (trial_watch_all), armed at ascension. v16.15
//   armed a per-hub watcher from door_manager's buy of door n — the dev warp
//   that reached hub 10 fired the buy notifies too, so the trial DID run, but
//   any path that does not is a hall that never seals. Presence is the only
//   condition now: everyone alive inside the HALL (trial_box is the hall
//   alone since v16.21 — the W flight's slot and the S lane are OUT).
//
//   THE SEAL IS THE HALL GATE (generator: tod_spire_hall_gate<hub>, across
//   the porch's mouth) on the crown door's Show + Solid + DisconnectPaths —
//   the one Show-after-Hide this map has proven live. v16.19 sealed door n
//   one flight BELOW the hall: the floor was locked, the room was not, and
//   the party walked out of the hall onto its own stairs.
//
//   SEVEN RECIPES (trial_recipe; ten until v17.69) matched to the generator's
//   seven layouts: each hall has its own boss mix — which elite family
//   carries the adds, how many Wardens stand, when the frenzy comes — on top
//   of the ladder: TOD_TRIAL_HP_MULT x TOD_TRIAL_STEP^(tier-1), compounding,
//   applied to elite HP and to the adds' cadence (read the defines).
//
//   THE WIN GRANTS EVERY PERK the map sells (the live scatter roster, exactly
//   as the ascension grant does) on top of the jackpot and the Max Ammo.
//
// LIFECYCLE per hub n: ascension -> trial_watch_all polls every hub not yet
// won -> everyone in hub n's hall -> a 2 s tell at the gate and the mark,
// re-check -> trial_run(n): wipe, the HALL GATE shows + seals with the
// ritual barrier along it, clock, hot trickle, the TRIAL TRACK, the Warden loop +
// the adds loop -> TOD_TRIAL_SECS later trial_win(n): the gate hides and
// opens for good, every flag clears, the jackpot + a Max Ammo on the mark +
// every perk, door n+1 (or the summit) unseals. Every flag the trial sets is
// cleared in trial_win and nowhere else; a party wipe ends the game and
// nothing needs unwinding.
//
// WHAT THE REST OF THE MAP READS while a trial runs (all level fields):
//   tod_trial_active   _tod_endless_rounds::tod_spawn_delay — the 0.12 floor
//   tod_trial_box      _tod_endless_rounds riser filter + tod_bosses::
//                      pick_spawn_point — nothing rises or lands outside the
//                      hall (the sealed-crown in_hall rule, one flight up)
//   tod_trial_hp_mult  tod_bosses::boss_hp — the single HP choke point
//   tod_trial_reserve  tod_bosses::elites_over_roof — the Wardens' first claim
//   tod_finale_song_start/end   _tod_gauge::finale_cell — the tower gauge IS
//                      the clock (25 cells filling toward the open gate; the
//                      finale's own lane, zero new LUI bits)
// ---------------------------------------------------------------------------

function trial_watch_all()
{
	level endon( "end_game" );

	hubs = tod_spire_data::hub_laps();
	for ( ;; )
	{
		wait 0.25;
		if ( IS_TRUE( level.tod_trial_active ) )
			continue;
		for ( i = 0; i < hubs.size; i++ )
		{
			hub = hubs[ i ];
			if ( IS_TRUE( level.tod_spire_trial_won[ hub ] ) )
				continue;
			z = tod_spire_data::hub_z( hub );
			box = tod_spire_data::trial_box( z );
			trial_arrival_chimes( hub, box );
			if ( !trial_all_in( box ) )
				continue;
			// THE CLOSING: a short tell at the gate AND at the mark (the party
			// faces into the hall), then a re-check — a player who steps back
			// out in that window keeps the hall open. A downed teammate outside
			// holds it open until they are revived and walk in.
			gate_org = tod_spire_data::trial_gate_org( z );
			mark = tod_spire_data::trial_mark_org( hub, z );
			level thread tod_teleport::fx_burst( "tod_tp_charge", gate_org + ( 0, 0, 40 ), TOD_TRIAL_CLOSE_SECS );
			tod_perk_scatter::play_sound_at_origin( gate_org, "tod_teleport_fire", 4 );
			tod_perk_scatter::play_sound_at_origin( mark, "tod_teleport_fire", 4 );
			wait TOD_TRIAL_CLOSE_SECS;
			if ( !trial_all_in( box ) )
				break;
			trial_run( hub );   // blocks this watcher for the trial: one at a time, by design
			break;
		}
	}
}

// Every player who is alive AND playing on the spire is inside the box, and
// there is at least one. Spectators are skipped (their .origin rides the
// camera — the gauge's own lesson); last stand counts as alive, so a crawler
// outside the hall is a reason not to close it, never a reason to leave them
// behind.
function trial_all_in( box )
{
	n = 0;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( isdefined( p.sessionstate ) && p.sessionstate != "playing" )
			continue;
		if ( !( tod_spire_data::in_spire( p.origin ) ) )
			continue;
		if ( !( tod_spire_data::in_box( p.origin, box ) ) )
			return false;
		n++;
	}
	return ( n > 0 );
}

// The lounges' first-arrival chime (tod_lounge_arrive, _tod_atmosphere), for
// the hall: once per player per hub, the first tick they stand inside it.
function trial_arrival_chimes( hub, box )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( isdefined( p.tod_hall_chimed ) && p.tod_hall_chimed == hub )
			continue;
		if ( !( tod_spire_data::in_box( p.origin, box ) ) )
			continue;
		p.tod_hall_chimed = hub;
		p PlayLocalSound( "tod_lounge_arrive" );
	}
}

// tier = hub / 10 (1..7 since v17.69) — the ladder's input.
function trial_tier( hub )
{
	t = int( hub / tod_spire_data::hub_every() );
	if ( t < 1 )
		t = 1;
	return t;
}

// TOD_TRIAL_STEP ^ ( tier - 1 ), by loop (GSC has no reliable Pow builtin —
// the boss module's own note).
function trial_ladder( tier )
{
	m = 1.0;
	for ( i = 1; i < tier; i++ )
		m = m * TOD_TRIAL_STEP;
	return m;
}

// THE SEVEN RECIPES (v17.69; ten in v16.21) — one per hub, matched to the
// generator's seven layouts by index (SP_RM_LAYOUTS; the names are the
// layouts' names, the colours are the halls' hues, docs/105). Fields:
//   name           the constant print at the seal ("TRIAL IV - THE DAIS")
//   wardens_extra  Wardens on top of one-per-player (the cap still binds)
//   prot/reaver/hound/sprint   the debt each adds tick tops up to (0 = that
//                  family sits this trial out); directors drain them under
//                  their own MAX_ALIVE roofs and the combined elite roof
//   frenzy_at      seconds before the end the frenzy starts (+1 Warden, the
//                  fast tick); TOD_TRIAL_SECS = the whole trial is a frenzy
// The ladder (TOD_TRIAL_STEP per trial) rides on top of every recipe.
function trial_recipe( hub )
{
	r = SpawnStruct();
	r.tier = trial_tier( hub );
	r.wardens_extra = 0;
	r.prot = 2;
	r.reaver = 1;
	r.hound = 2;
	r.sprint = 0;
	r.frenzy_at = TOD_TRIAL_FRENZY_SECS;
	switch ( r.tier )
	{
		case 1:   // THE RING (gold) — the Warden and its protectors; nothing else. The lesson.
			r.name = "TRIAL I - THE RING";
			r.reaver = 0; r.hound = 0;
			break;
		case 2:   // THE KENNEL (green) — the cross makes four pens; hounds hunt through them
			r.name = "TRIAL II - THE KENNEL";
			r.prot = 1; r.reaver = 0; r.hound = 4;
			break;
		case 3:   // THE FIRING LINE (cyan) — protectors fire down the colonnade's lanes, a Reaver at the back
			r.name = "TRIAL III - THE FIRING LINE";
			r.prot = 3; r.reaver = 1; r.hound = 0;
			break;
		case 4:   // THE ALTAR (purple) — two Wardens; reavers take the high ground with you
			r.name = "TRIAL IV - THE ALTAR";
			r.wardens_extra = 1; r.prot = 1; r.reaver = 2; r.hound = 1;
			break;
		case 5:   // THE MAZE (orange) — armored sprinters round every corner, two Wardens; the frenzy comes at the halfway mark
			r.name = "TRIAL V - THE MAZE";
			r.wardens_extra = 1; r.prot = 1; r.reaver = 0; r.hound = 2; r.sprint = 3;
			r.frenzy_at = int( TOD_TRIAL_SECS / 2 );
			break;
		case 6:   // THE GAUNTLET (white) — three Wardens down the lane, protectors on the flanks; frenzy at the halfway mark
			r.name = "TRIAL VI - THE GAUNTLET";
			r.wardens_extra = 2; r.prot = 3; r.reaver = 1; r.hound = 0; r.sprint = 2;
			r.frenzy_at = int( TOD_TRIAL_SECS / 2 );
			break;
		default:  // tier 7, THE THRONE (red) — the cap of Wardens, every family, the whole trial a frenzy. The top is one flight up.
			r.name = "TRIAL VII - THE THRONE";
			r.wardens_extra = 3; r.prot = 3; r.reaver = 2; r.hound = 3; r.sprint = 3;
			r.frenzy_at = TOD_TRIAL_SECS;
			break;
	}
	return r;
}

function trial_run( hub )
{
	level endon( "end_game" );

	z = tod_spire_data::hub_z( hub );
	mark = tod_spire_data::trial_mark_org( hub, z );
	gate = GetEnt( tod_spire_data::trial_gate_target( hub ), "targetname" );
	gate_org = tod_spire_data::trial_gate_org( z );
	recipe = trial_recipe( hub );

	// 1. THE BOARD IS CLEARED — the seal's own recipe. Everything alive is
	// either on the spiral outside (stranded the moment the gate seals,
	// holding slots the hall needs) or an honour guard the party chose not
	// to finish; the trial spawns its own.
	wipe_all_zombies();

	// 2. STATE FIRST — the spawn systems read these this frame — then the
	// seal: nothing may be spawned outside the hall after this line.
	level.tod_trial_active = true;
	level.tod_trial_hub = hub;
	level.tod_trial_tier = recipe.tier;
	level.tod_trial_recipe = recipe;
	level.tod_trial_box = tod_spire_data::trial_box( z );
	level.tod_trial_hp_mult = TOD_TRIAL_HP_MULT * trial_ladder( recipe.tier );
	level.tod_trial_frenzy = false;
	// The mid-round direct write (the ascension lesson: the resolver is only
	// consulted at a rollover, and the round in progress would keep the old
	// delay marinating).
	level.zombie_vars[ "zombie_spawn_delay" ] = TOD_TRIAL_SPAWN_FLOOR;
	// v18.9 — AND DROP ANY OWED PANZER, exactly as king_run already does at its
	// own seal. The director's gate (added the same version) stops a NEW debt
	// being spent into the hall, but a debt banked while a spire honour-guard
	// Panzer was standing would otherwise pop the instant the trial ends. Zeroed,
	// not clamped: an unspent boss round is forgiven, the same rule the Panzer
	// debt cap already encodes.
	level.tod_panzer_debt = 0;

	// 3. THE SEAL — the hall gate SHOWS and goes Solid + DisconnectPaths
	// (crown_door_close verbatim) and the purple wall goes up along it (the
	// SoE ritual barrier on tag_origin hosts, deleted on the win): the FX is
	// what you see, the slab is what stops you, DisconnectPaths is what stops
	// the horde (the navmesh ignores entity collision). The quake sells it.
	hosts = trial_barrier_up( gate_org );
	if ( isdefined( gate ) )
	{
		gate Show();
		gate Solid();
		gate DisconnectPaths();
		tod_bosses::dev_ai_gate( gate, "disconnect" );
	}
	Earthquake( 0.5, 1.2, gate_org, 1400 );
	tod_perk_scatter::play_sound_at_origin( gate_org, "tod_teleport_fire", 4 );
	tod_perk_scatter::derez_burst( mark );
	// 3b. THE HALL WAKES (2026-10-01): sparks rush up all four walls and keep
	// rising in the hall's own colour - red from the start in the all-frenzy hall.
	trial_fx_start( hub, z, ( recipe.frenzy_at >= TOD_TRIAL_SECS ) );

	// 4. THE CLOCK — the tower gauge's finale lane: 25 cells that FILL toward
	// the open gate. finale_cell reads these two fields and nothing else.
	level.tod_finale_song_start = GetTime();
	level.tod_finale_song_end = level.tod_finale_song_start + ( TOD_TRIAL_SECS * 1000 );

	// 5. MUSIC + THE NAME: THE TRIAL'S OWN TRACK takes the channel (v17.8,
	// user: "in the trials I believe we play boss music but I want to change
	// it") — "Chaos Unleashed", tod_music_trial, level-matched to the boss
	// track it replaces (-12.2 LUFS) and on the same BUS_MUSIC row shape at
	// the same alias volume, so "it'll still fall under boss volume" holds
	// both in the mixer and to the ear. Set DIRECTLY, not via the Panzer
	// refcount — boss_music_blocked() is true on the spire, so a Warden's
	// death can never yank the channel mid-trial. trial_win puts the spire
	// band back with channel_play( band_alias() ).
	tod_atmosphere::channel_play( "tod_music_trial" );
	trial_sting();
	level thread trial_banner( recipe.tier );   // v16.25: the baked TRIAL I..VII plate (was the name printed)
	tod_upgrade_ui::toast_all( TOD_TOAST_HOLD_THE_HALL );   // v19.58: map typeface

	level thread trial_wardens( hub );
	level thread trial_adds( hub );

	if ( recipe.frenzy_at >= TOD_TRIAL_SECS )
	{
		level.tod_trial_frenzy = true;   // the whole trial is a frenzy (THE SUMMIT HALL)
		wait TOD_TRIAL_SECS;
	}
	else
	{
		wait ( TOD_TRIAL_SECS - recipe.frenzy_at );
		level.tod_trial_frenzy = true;
		// The frenzy you SEE (2026-10-01): the walls surge red and the hall's
		// heart starts beating - the tell the deleted "THE FRENZY" text never was.
		trial_fx_frenzy( hub, z );
		// v17.46 (user 2026-09-04: "I dont want that display"): the "THE FRENZY"
		// IPrintLnBold that used to fire here is GONE. The frenzy itself is
		// unchanged — the flag above still adds the extra Warden and halves the
		// adds tick — the player just feels it instead of reading it.
		wait recipe.frenzy_at;
	}

	trial_win( hub, gate, hosts );
}

// THE BARRIER: TOD_TRIAL_BARRIER_N tag_origin hosts spread along the gate's
// axis at hall-floor level, each playing the looping ritual-barrier fx on its
// tag (the _tod_teleport fx_burst recipe, held instead of timed — a looping fx
// on a host is the only stoppable kind). The gate runs along y and faces +x
// into the hall (generated trial_gate_axis / trial_gate_yaw); if the wall
// renders edge-on in game, the yaw is the one number to flip.
function trial_barrier_up( gate_org )
{
	hosts = [];
	axis = tod_spire_data::trial_gate_axis();
	spread = tod_spire_data::trial_gate_len() / TOD_TRIAL_BARRIER_N;
	for ( i = 0; i < TOD_TRIAL_BARRIER_N; i++ )
	{
		off = axis * ( ( i - ( ( TOD_TRIAL_BARRIER_N - 1 ) / 2.0 ) ) * spread );
		h = Spawn( "script_model", gate_org + off );
		if ( !isdefined( h ) )
			continue;   // entity pool — the slab still seals; the wall is just less visible
		h SetModel( "tag_origin" );
		h.angles = ( 0, tod_spire_data::trial_gate_yaw(), 0 );
		hosts[ hosts.size ] = h;
	}
	// 2026-10-01: NOT IN THIS FRAME. The wall was played on hosts made in the same
	// frame, and an effect that reaches the client before its host is dropped - the
	// Healing Aura's area was invisible for exactly this until it waited (memory
	// flat-ground-fx-rules). So the purple wall has most likely never been drawn.
	level thread barrier_fx_late( hosts, "trial" );
	return hosts;
}

// The barrier's effect, two server frames after its hosts exist. A host deleted
// in between (a two-frame trial is not possible, but a game end is) is skipped.
function barrier_fx_late( hosts, which )
{
	WAIT_SERVER_FRAME;
	WAIT_SERVER_FRAME;
	n = 0;
	foreach ( h in hosts )
	{
		if ( !isdefined( h ) )
			continue;
		PlayFxOnTag( level._effect[ "tod_trial_barrier" ], h, "tag_origin" );
		n++;
	}
	trial_fx_log( "BARRIER_FX " + which + " hosts=" + n + "/" + hosts.size );
}

function trial_barrier_down( hosts )
{
	if ( !isdefined( hosts ) )
		return;
	for ( i = 0; i < hosts.size; i++ )
	{
		if ( isdefined( hosts[ i ] ) )
			hosts[ i ] Delete();
	}
}

// =============================================================================
// THE HALL BECOMES THE CLOCK (2026-10-01; user: "Lets build 1 first. Highest
// quality" - section 1 of the effects plan). Before this a trial's only effect
// was the purple gate wall (which was never drawn, barrier_fx_late) and the clock
// lived only on the HUD gauge. Now:
//   the seal    - sparks rush up all four drum walls, then keep rising in the
//                 hall's own light colour (motes, sparks, a low haze, slow runes);
//   the frenzy  - the walls surge red, rise faster and thicker with embers, and a
//                 red light at the hall's heart beats lub-dub (Trial VII, all
//                 frenzy, starts like this);
//   the win     - the walls stop (the last sparks rise and fade on their own: they
//                 run in world space) and gold rains onto the Max Ammo mark;
//   the King    - a red ring tightens on his landing spot on a quickening
//                 heartbeat for exactly the countdown (king_countdown_fx).
// The effects are tools/gen_trial_fx.py (its --check gates this file). Every host
// faces UP (flat elements lie on the floor) and every effect waits two server
// frames after its host exists (fx_play_on_new_host). [TOD_TRIAL_FX] logs it all.
// =============================================================================

// LOCKSTEP with gen_tower_map.js SP_RM_LAYOUTS (hall order = hub order; the
// generator's --check compares them): the colour each hall's lights are.
function trial_fx_hues()
{
	return array( "gold", "green", "cyan", "purple", "orange", "white", "red" );
}

function trial_fx_hue( hub )
{
	hues = trial_fx_hues();
	i = tod_spire_data::trial_layout_index( hub );
	if ( i < 0 || i >= hues.size )
		i = hues.size - 1;
	return hues[ i ];
}

// A new tag_origin host FACING UP: an effect lays its flat sprites across its
// forward axis (memory flat-ground-fx-rules), so up = flat on the floor.
function fx_host_up( org )
{
	h = Spawn( "script_model", org );
	if ( !isdefined( h ) )
		return undefined;
	h SetModel( "tag_origin" );
	h.angles = ( -90, 0, 0 );
	return h;
}

// THE RULE (2026-10-01): an effect played on a host made in the same server frame
// reaches the client before the host and is dropped - two frames, then play.
function fx_play_on_new_host( host, key, key2 )
{
	WAIT_SERVER_FRAME;
	WAIT_SERVER_FRAME;
	if ( !isdefined( host ) )
		return;
	PlayFXOnTag( level._effect[ key ], host, "tag_origin" );
	if ( isdefined( key2 ) )
		PlayFXOnTag( level._effect[ key2 ], host, "tag_origin" );
	trial_fx_log( "FX_PLAYED " + key + ( ( isdefined( key2 ) ) ? ( " + " + key2 ) : "" ) + " at=" + host.origin );
}

function fx_host_delete_after( secs )   // self = an fx host
{
	wait secs;
	if ( isdefined( self ) )
		self Delete();
}

// WHERE THE SPARKS STAND (v19.68l, after the user's first trial: "I dont see any
// changes visually"). v19.68i played ONE effect from the hall's centre whose
// sparks were born 436 out - on the drum's inner face, inside its 8-thick liner
// (428): every one of them was inside the wall. Now EIGHT segments stand on the
// hall's own floor, 24 in front of the liner: three tile the N wall, three the E
// wall, one stands over the NW region (the W flight climbs in below y 64), one
// runs the middle of the S strip. ( x, y, yaw ) from the hall's centre; each
// segment's sparks run +-135 along its host's LEFT axis (pitch -90 keeps X up;
// yaw 0 = world Y, yaw 90 = world X), symmetric about the host, so no axis sign
// matters. LOCKSTEP: tools/gen_trial_fx.py WALL_SEGMENTS - its --check also
// re-derives every number from gen_tower_map.js.
function trial_wall_segments()
{
	return array( ( -269, 404, 90 ), ( 0, 404, 90 ), ( 269, 404, 90 ), ( 404, -269, 0 ), ( 404, 0, 0 ), ( 404, 269, 0 ), ( -404, 254, 0 ), ( 0, -232, 90 ) );
}

// The walls of the hall at hub <hub>, its floor at z: the hall's colour, or the
// frenzy (plus the heartbeat light on its own host at the hall's centre).
function trial_fx_start( hub, z, frenzy )
{
	trial_fx_stop( "restart" );
	c = ( tod_spire_data::spire_x(), tod_spire_data::spire_y(), z );
	key = "tod_trial_walls_" + trial_fx_hue( hub );
	if ( frenzy )
		key = "tod_trial_walls_frenzy";
	hosts = [];
	foreach ( s in trial_wall_segments() )
	{
		h = fx_host_up( c + ( s[ 0 ], s[ 1 ], 0 ) );
		if ( !isdefined( h ) )
			continue;   // entity pool: one wall goes dark, the trial runs
		h.angles = ( -90, s[ 2 ], 0 );
		level thread fx_play_on_new_host( h, key );
		hosts[ hosts.size ] = h;
	}
	if ( frenzy )
	{
		h = fx_host_up( c );
		if ( isdefined( h ) )
		{
			level thread fx_play_on_new_host( h, "tod_trial_frenzy_light" );
			hosts[ hosts.size ] = h;
		}
	}
	level.tod_trial_fx_hosts = hosts;
	trial_fx_log( "WALLS_ON hub=" + hub + " tier=" + trial_tier( hub ) + " look="
		+ ( ( frenzy ) ? "frenzy" : trial_fx_hue( hub ) ) + " hosts=" + hosts.size + " centre=" + c );
}

// The frenzy takes over: the red walls start, and the calm ones go a moment
// later, so there is never a frame with neither.
function trial_fx_frenzy( hub, z )
{
	old = level.tod_trial_fx_hosts;
	level.tod_trial_fx_hosts = undefined;
	trial_fx_start( hub, z, true );
	if ( isdefined( old ) )
	{
		foreach ( h in old )
		{
			if ( isdefined( h ) )
				h thread fx_host_delete_after( 0.5 );
		}
	}
}

function trial_fx_stop( why )
{
	if ( isdefined( level.tod_trial_fx_hosts ) )
	{
		n = 0;
		foreach ( h in level.tod_trial_fx_hosts )
		{
			if ( isdefined( h ) )
			{
				h Delete();
				n++;
			}
		}
		trial_fx_log( "WALLS_OFF why=" + why + " hosts=" + n );
	}
	level.tod_trial_fx_hosts = undefined;
}

// Gold on the mark: a one-shot shower with its own flash light.
function trial_fx_win( mark )
{
	h = fx_host_up( mark );
	if ( !isdefined( h ) )
	{
		trial_fx_log( "WIN_FAIL no_entity" );
		return;
	}
	level thread fx_play_on_new_host( h, "tod_trial_win", "tod_trial_win_light" );
	h thread fx_host_delete_after( 3.0 );
	trial_fx_log( "WIN_SHOWER mark=" + mark );
}

// THE KING'S COUNTDOWN: his ring on the deck under the spot he lands on, for the
// countdown's length (the effect is cut to it: tools/gen_trial_fx.py KING_SECS).
function king_countdown_fx( secs )
{
	level endon( "end_game" );

	org = tod_bosses::ground_snap( tod_spire_data::summit_king_org() );
	h = fx_host_up( org );
	if ( !isdefined( h ) )
	{
		trial_fx_log( "KING_COUNTDOWN_FAIL no_entity" );
		return;
	}
	level thread fx_play_on_new_host( h, "tod_king_countdown", "tod_king_countdown_light" );
	trial_fx_log( "KING_COUNTDOWN secs=" + secs + " org=" + org );
	wait secs + 0.1;
	if ( isdefined( h ) )
		h Delete();
}

function trial_fx_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_TRIAL_FX] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

// THE WARDENS: level.tod_panzer_alive is held at want (one per player, plus
// the recipe's extra, plus one in the frenzy, capped), a fallen one replaced
// TOD_TRIAL_WARDEN_REDROP later. SPAWNED DIRECTLY like the honour guard (the
// director would deliver ONE), which is why the roof bookkeeping lives here:
// a Warden drops only under the hard roof, and tod_trial_reserve tells every
// director to leave the Wardens their slots. Wardens pay the elite rate
// (tod_spire_guard), not the boss jackpot.
function trial_wardens( hub )
{
	level endon( "end_game" );
	level endon( "tod_trial_end" );

	z = tod_spire_data::hub_z( hub );
	org = tod_spire_data::trial_warden_org( hub, z );
	last_alive = 0;
	fell_at = 0;
	for ( ;; )
	{
		wait 0.5;
		want = trial_warden_want();
		alive = ( ( isdefined( level.tod_panzer_alive ) ) ? level.tod_panzer_alive : 0 );
		if ( alive < last_alive )
			fell_at = GetTime();          // one fell — the slot stays empty for a beat
		last_alive = alive;
		reserve = want - alive;
		if ( reserve < 0 )
			reserve = 0;
		level.tod_trial_reserve = reserve;
		if ( alive >= want )
			continue;
		if ( ( GetTime() - fell_at ) < ( TOD_TRIAL_WARDEN_REDROP * 1000 ) )
			continue;
		if ( tod_bosses::elites_all_alive() >= tod_bosses::elite_roof_all() )
			continue;                     // the hard roof — never raised, ever
		// THE DROP GOES ON ITS OWN THREAD (2026-09-04). spawn_panzer BLOCKS for
		// the whole of _tod_bosses::drop_in — the tell lead plus TOD_DROP_SECS —
		// and THIS loop carries `level endon( "tod_trial_end" )`, which trial_win
		// fires the instant the clock runs out. A notify landing inside that
		// window killed the stack mid-drop, and drop_in's teardown is all after
		// its waits: the script_model PROXY wearing the boss's model and
		// attachments survives forever, standing where it was, with a
		// "fly_civil_protector_loop" playing and a sky-trail linked to it, while
		// the REAL boss stays Ghost()ed, SetCanDamage(false), ignoreall, anim
		// rate 0.05 and holding a level.tod_panzer_alive slot that suppresses
		// every later Warden. A permanent motionless enemy that cannot target
		// anyone is the reported bug wearing its most literal costume, and this
		// is the only caller of spawn_panzer that put the blocking call under a
		// notify it does not control (door_guard_panzers uses end_game only).
		level thread trial_warden_drop( org );
		wait 2.5;                         // let the drop settle so `alive` is honest
		// panzer_life bumped the count on its first line, before spawn_panzer
		// returned — re-read so the fall detector above does not misread the
		// arrival as a death on the next tick.
		last_alive = ( ( isdefined( level.tod_panzer_alive ) ) ? level.tod_panzer_alive : 0 );
		wait TOD_SPIRE_GUARD_STAGGER;
	}
}

// The Warden drop, deliberately OUTSIDE trial_wardens' endon: a drop already in
// flight when the clock expires must be allowed to land and tear itself down.
// A Warden that arrives a beat after the win is the designed degrade — trial_win
// already leaves standing Wardens hunting — whereas an abandoned drop is
// permanent litter.
//
// It also closes the force-org leak on this lane. spawn_panzer's two early
// returns (the upgrade pause, and no anchor player) sit ABOVE the site that
// consumes level.tod_boss_force_org, so a refusal used to leave this hub's
// anchor armed for whatever Panzer spawned next, anywhere in the run.
function trial_warden_drop( org )
{
	level endon( "end_game" );

	level.tod_boss_force_org = org;   // consume-once, read by spawn_panzer
	boss = tod_bosses::spawn_panzer();
	if ( !isdefined( boss ) )
	{
		level.tod_boss_force_org = undefined;
		return;
	}
	boss.tod_spire_guard  = true;     // elite payout lane (panzer_life)
	boss.tod_trial_warden = true;
}

function trial_warden_want()
{
	want = 0;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
			want++;
	}
	if ( want < 1 )
		want = 1;
	if ( isdefined( level.tod_trial_recipe ) )
		want += level.tod_trial_recipe.wardens_extra;
	if ( IS_TRUE( level.tod_trial_frenzy ) )
		want++;
	if ( want > TOD_TRIAL_WARDEN_CAP )
		want = TOD_TRIAL_WARDEN_CAP;
	return want;
}

// The adds tick for this trial: the base divided by the ladder (TOD_TRIAL_STEP
// per trial = 9% faster each as of v18.2), floored at TOD_TRIAL_TICK_MIN. The
// rate is NOT written here - read the define, this comment has been stale for
// two retunes already.
function trial_tick( base )
{
	t = base;
	if ( isdefined( level.tod_trial_tier ) )
		t = t / trial_ladder( level.tod_trial_tier );
	if ( t < TOD_TRIAL_TICK_MIN )
		t = TOD_TRIAL_TICK_MIN;
	return t;
}

// THE ADDS: every tick, top each family's debt up to the recipe's figure (a
// family at 0 sits the trial out) — the same debts the directors drain under
// their own MAX_ALIVE roofs and the combined elite roof. Debts are SET to a
// ceiling, never summed — the map's debt rule. The directors deliver at the
// party's own position and pick_spawn_point keeps them inside the hall; the
// sprinter director promotes horde zombies already in the hall.
function trial_adds( hub )
{
	level endon( "end_game" );
	level endon( "tod_trial_end" );

	r = level.tod_trial_recipe;
	for ( ;; )
	{
		tick = trial_tick( TOD_TRIAL_TICK );
		if ( IS_TRUE( level.tod_trial_frenzy ) )
			tick = trial_tick( TOD_TRIAL_FRENZY_TICK );
		wait tick;
		if ( tod_bosses::elites_over_roof() )
			continue;
		if ( r.prot > 0 && level.tod_protector_debt < r.prot )
			level.tod_protector_debt = r.prot;
		if ( r.reaver > 0 )
		{
			if ( !isdefined( level.tod_reaver_debt ) )
				level.tod_reaver_debt = 0;
			if ( level.tod_reaver_debt < r.reaver )
				level.tod_reaver_debt = r.reaver;
		}
		if ( r.hound > 0 )
		{
			if ( !isdefined( level.tod_hound_debt ) )
				level.tod_hound_debt = 0;
			if ( level.tod_hound_debt < r.hound )
				level.tod_hound_debt = r.hound;
		}
		if ( r.sprint > 0 )
		{
			if ( !isdefined( level.tod_sprinter_debt ) )
				level.tod_sprinter_debt = 0;
			if ( level.tod_sprinter_debt < r.sprint )
				level.tod_sprinter_debt = r.sprint;
		}
	}
}

function trial_win( hub, gate, hosts )
{
	level endon( "end_game" );

	z = tod_spire_data::hub_z( hub );
	mark = tod_spire_data::trial_mark_org( hub, z );
	gate_org = tod_spire_data::trial_gate_org( z );

	level notify( "tod_trial_end" );   // the Warden + adds loops
	// EVERY FLAG THE TRIAL SET, cleared here and only here.
	level.tod_trial_active = undefined;
	level.tod_trial_hub = undefined;
	level.tod_trial_tier = undefined;
	level.tod_trial_recipe = undefined;
	level.tod_trial_box = undefined;
	level.tod_trial_hp_mult = undefined;
	level.tod_trial_reserve = undefined;
	level.tod_trial_frenzy = undefined;
	level.tod_finale_song_start = undefined;   // the gauge goes back to being an altimeter
	level.tod_finale_song_end = undefined;
	level.tod_boss_force_org = undefined;      // an unconsumed Warden org must not land the next scheduled Panzer in an empty hall
	// Pacing back to the spire's own floor; the per-round resolver re-derives
	// it (rampage included) at the next rollover, seconds away under the twist.
	level.zombie_vars[ "zombie_spawn_delay" ] = TOD_SPIRE_SPAWN_FLOOR;

	// THE WORLD FREEZES ON THE LAST CHORD (v17.61, user 2026-09-04: "make sure
	// to freeze the game during the trials reward"). The card deal below
	// (trial_upgrade_deal -> run_upgrade_event) has always frozen the world —
	// but only when IT began, three seconds after this line, and those three
	// seconds were a LIVE hall: the Wardens still standing hunted, every add on
	// the floor kept swinging, the four family debts trial_adds had SET kept
	// draining into fresh elites, and stock's trickle kept rising through the
	// floor — all of it on top of the WON plate, the jackpot and the Max Ammo.
	// So the reward opened with a hit in the back. The same freeze the deal
	// uses (set_world_pause: stock's world_is_paused halts round_spawning at
	// _zm.gsc:3747, every axis AI — Wardens included, via boss_pause_watch's
	// per-tick re-assert — goes ignoreall at anim rate 0.05, every director and attack loop
	// gates on the flag, and upgrade_damage_cb returns 0 so nothing is free)
	// now starts HERE, before a single reward lands, and is held straight
	// through the deal: run_upgrade_event re-sets it (idempotent) and releases
	// it with the last pick; trial_upgrade_deal releases it itself if the deal
	// had nobody to deal to. Players are NOT frozen by this line — the cards
	// freeze each participant as they always did — so the three seconds are
	// theirs to walk to the Max Ammo on a board that cannot touch them, exactly
	// the standing a non-participant has during any round event.
	tod_upgrades::set_world_pause( true );

	// THE WALL COMES DOWN, for good: the barrier hosts die and the gate hides
	// and opens (the door contract's open half).
	trial_barrier_down( hosts );
	// THE HALL EXHALES (2026-10-01): the walls stop - the last sparks rise and
	// fade - and gold rains onto the mark where the Max Ammo lands.
	trial_fx_stop( "win" );
	level thread trial_fx_win( mark );
	if ( isdefined( gate ) )
	{
		gate Hide();
		gate NotSolid();
		gate ConnectPaths();
		tod_bosses::dev_ai_gate( gate, "connect" );
	}
	level.tod_spire_trial_won[ hub ] = true;
	level notify( "tod_spire_trial_won" );
	// THE WON PLATE (v16.43) — the baked "THE TRIAL IS WON" banner on the
	// same lane as the TRIAL I..VII plate that opened the fight.
	level thread trial_banner( 0, "tod_trial_won" );

	// THE PRIZE: the jackpot to everyone, a Max Ammo on the mark, AN UPGRADE
	// CARD DEAL to every living player (v16.36, trial_upgrade_deal — the
	// spire's ONLY upgrade source now that ascension grants none), the perk
	// top-up (trial_grant_perks — a no-op for anyone the perma lane keeps
	// whole; in SOLO it is the one lane that refunds the Quick Revive life the
	// last down spent), a de-rez flourish at the mark and the gate. Wardens
	// still standing resume the hunt when the freeze lifts — they pay the elite
	// rate whenever they finally fall.
	tod_bosses::grant_boss_reward( "TRIAL", TOD_TRIAL_WIN_PTS + TOD_TRIAL_WIN_PTS_TIER * ( trial_tier( hub ) - 1 ), false );
	level thread trial_ammo_drop( mark );   // v17.61: its clock starts when the freeze lifts, not now
	level thread trial_grant_perks();
	level thread trial_upgrade_deal( hub );
	tod_atmosphere::channel_play( tod_atmosphere::band_alias() );
	trial_sting();
	tod_upgrade_ui::toast_all( TOD_TOAST_TRIAL_WON );   // v19.58: map typeface
	tod_perk_scatter::derez_burst( mark );
	tod_perk_scatter::derez_burst( gate_org );
}

// Every perk the map sells, to every living player who lacks it — through the
// perma lane (perma_perks_give, QR allowed). Since v16.36 the perma keeper
// re-gives on every revive and spawn, so for a co-op party this is a no-op;
// in SOLO it is the ONE lane that hands Quick Revive back after a self-revive
// consumed it — one free life per trial won, which is what the v16.21 grant
// already amounted to. No cap check is needed: the perk limit sits above the
// roster (v16.80; before that PERK SLOTS was at max by the grant).
function trial_grant_perks()
{
	level endon( "end_game" );

	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p perma_perks_give( true );
	}
}

// THE MAX AMMO ON THE MARK, ON A CLOCK THAT RESPECTS THE FREEZE (v17.61).
// Stock's powerup_timeout is real time — 15 s, then ~11 s of blinking — and
// knows nothing about the world pause, so a drop made at the win would have
// spent most of its life under the frozen reward (3 s of WON plate + up to
// 20 s of cards), leaving a solo player who read both cards to the end about
// 8 s to reach it. The drop goes out with stock's own b_stay_forever, which
// simply never starts that thread; the moment the freeze lifts the very same
// stock timeout is started on it, so it then lives exactly as long as any
// Max Ammo does — no custom clock, no level-wide override (the map sets
// neither _powerup_timeout_override nor _powerup_timeout_custom_time, and
// this does not start). Grabbed during the freeze = the entity is gone by the
// time the wait ends, and the isdefined skips the start. The freeze must
// already be on when this runs — trial_win sets it a few lines earlier.
function trial_ammo_drop( mark )
{
	level endon( "end_game" );

	pu = zm_powerups::specific_powerup_drop( "full_ammo", mark, undefined, undefined, undefined, undefined, true );
	if ( !isdefined( pu ) )
		return;
	while ( IS_TRUE( level.tod_upgrade_pause ) )
		wait 0.25;
	if ( isdefined( pu ) )
		pu thread zm_powerups::powerup_timeout();
}

// THE TRIAL'S UPGRADE (v16.36): one card deal to every living player — the
// REAL round-event deal (run_upgrade_event: its participant filter, the world
// pause, the luck floor, the tier card at its odds), so the spire's
// progression is the tower's own system and never a second one. This is the
// spire's ONLY upgrade source: the round clock stays suppressed from
// ascension. Delayed past the sting and the barrier drop so the win reads
// before the cards; a player with nothing left (every domain maxed,
// top tier, no tier roll) simply is not a participant, exactly as on the
// tower, and nobody sees a panel for an empty deal.
//
// THE FREEZE IS ALREADY ON when this thread starts (v17.61: trial_win sets
// set_world_pause( true ) on the last chord, before any reward lands — see
// the note there), so the three seconds below are a frozen board, not a live
// one. run_upgrade_event re-sets the same pause (idempotent) and releases it
// after the last pick; the release at the bottom of this function is for the
// one path where it returns without ever touching the pause — no participant
// — since nothing else would ever clear a freeze trial_win opened.
function trial_upgrade_deal( hub )
{
	level endon( "end_game" );
	wait 3.0;
	// DARK UPGRADES (v17.10, user 2026-09-04: "If you have an upgrade maxed then
	// you must get the dark upgrade as an option after you defeat a trial and get
	// upgrade rewards"). THE TRIAL DEAL IS THE ONLY DEAL THAT OWES A DARK CARD —
	// the latch is what tells roll_options this one is special, exactly the shape
	// `tod_tier_deal_pre` already uses for the tier card.
	//
	// SET AND CLEARED AROUND THE CALL, never left standing: run_upgrade_event is
	// the SHARED deal used by the round clock and the per-floor deal too, and a
	// latch that outlived this call would owe a dark card on every one of them.
	// Cleared unconditionally after — run_upgrade_event blocks until the panel is
	// done, and `level endon("end_game")` is the only way out of this thread.
	// NEVER OVER A LIVE DEAL (bug review 2026-09-22, F02): a scheduled
	// every-4th-round deal that opened in the trial's last seconds could still
	// be running here, and run_upgrade_event is not re-entrant — the second
	// call reset the shared counter and unpaused the world under a teammate
	// still frozen on cards. run_upgrade_event now queues behind a live deal
	// itself; the scheduler also skips trials (event_scheduler).
	level.tod_dark_guarantee = true;
	tod_upgrades::run_upgrade_event();
	level.tod_dark_guarantee = undefined;
	// THE RELEASE for the empty-deal path (v17.61). run_upgrade_event returns
	// before its own set_world_pause( true ) when nobody has a card coming, so
	// the freeze trial_win opened is still standing here with no owner left to
	// clear it — and a permanent freeze is the one failure worse than the live
	// gap this replaced. Only OUR pause is released: a pause the deal opened
	// was already closed by its last line (the flag reads false), and a
	// station's freeze (none exist on the spire, but the guard is the same one
	// run_upgrade_event's takeover reasons from) is somebody else's to end.
	if ( IS_TRUE( level.tod_upgrade_pause ) && !isdefined( level.tod_station_pause_owner ) )
		tod_upgrades::set_world_pause( false );
}

// THE TRIAL BANNER (v16.25): the hall's own plate — TRIAL I..VII, the numeral,
// the name, the hall's glyph — to every player for five seconds at the seal.
// arrival_banners' exact geometry (600x150 at y-130: the choice plate's
// off-screen lesson). A server hudelem drawing a baked MATERIAL: zero LUI
// bits. tier n -> tod_trial_n; the seven are precached above and zoned with
// their images (ten until v17.69; the clamp reads the hub count).
// mat_override (v16.43): a plate that is not one of the tiers — the WON
// plate passes "tod_trial_won" and tier is ignored.
function trial_banner( tier, mat_override )
{
	level endon( "end_game" );

	if ( !isdefined( tier ) || tier < 1 )
		tier = 1;
	max_tier = tod_spire_data::hub_laps().size;
	if ( tier > max_tier )
		tier = max_tier;
	mat = "tod_trial_" + tier;
	if ( isdefined( mat_override ) )
		mat = mat_override;

	elems = [];
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		e = NewClientHudElem( p );
		if ( !isdefined( e ) )
			continue;
		e.alignX = "center";
		e.alignY = "middle";
		e.horzAlign = "center";
		e.vertAlign = "middle";
		e.y -= 130;
		e.foreground = true;
		e.color = ( 1, 1, 1 );
		e.hidewheninmenu = true;
		e.alpha = 0;
		// v17.82 (user 2026-09-05: "the trial banners are too big. We need like
		// 25% smaller"). 600x150 -> 448x112: 25.3% off each axis and EXACTLY
		// 4:1, which is the source art's own ratio (2048x512), so nothing
		// squishes. The WON plate rides this same line by design — it is the
		// same series and has to match.
		e SetShader( mat, 448, 112 );
		e FadeOverTime( 0.6 );
		e.alpha = 1;
		elems[ elems.size ] = e;
		p tod_upgrade_ui::banner_track( e );
	}

	wait 5;
	for ( i = 0; i < elems.size; i++ )
	{
		if ( isdefined( elems[ i ] ) )
		{
			elems[ i ] FadeOverTime( 1 );
			elems[ i ].alpha = 0;
		}
	}
	wait 1.1;
	for ( i = 0; i < elems.size; i++ )
	{
		if ( isdefined( elems[ i ] ) )
			elems[ i ] Destroy();
	}
}

// The ultimate-card sting, to everyone — the map's own "something big just
// happened" sound (the grant plays it too).
function trial_sting()
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
			players[ i ] PlayLocalSound( "tod_ultimate_sting" );
	}
}

// ---------------------------------------------------------------------------
// SCREENS. spire_game_over serves BOTH endings the spire owns — the summit
// win and the climb's death — switched on tod_spire_won. Geometry mirrors
// _tod_finale::escaped_game_over exactly (the proven layout).
// ---------------------------------------------------------------------------

function spire_game_over( player, game_over, survived )
{
	banner = "tod_spire_over_banner";
	if ( IS_TRUE( level.tod_spire_won ) )
		banner = "tod_spire_win_banner";

	game_over.alignX = "center";
	game_over.alignY = "middle";
	game_over.horzAlign = "center";
	game_over.vertAlign = "middle";
	game_over.y -= 130;
	game_over.foreground = true;
	game_over.alpha = 0;
	game_over.color = ( 1, 1, 1 );   // WHITE — the art carries its own colours
	game_over.hidewheninmenu = true;
	game_over SetShader( banner, 900, 225 );
	game_over FadeOverTime( 1 );
	game_over.alpha = 1;

	emblem = NewClientHudElem( player );
	if ( isdefined( emblem ) )
	{
		emblem.alignX = "center";
		emblem.alignY = "middle";
		emblem.horzAlign = "center";
		emblem.vertAlign = "middle";
		emblem.y = game_over.y - 150;
		emblem.foreground = true;
		emblem.color = ( 1, 1, 1 );
		emblem.hidewheninmenu = true;
		emblem.alpha = 0;
		emblem SetShader( "tod_spire_emblem", 128, 128 );
		emblem FadeOverTime( 1.4 );
		emblem.alpha = 1;
	}

	survived.alignX = "center";
	survived.alignY = "middle";
	survived.horzAlign = "center";
	survived.vertAlign = "middle";
	survived.y += 10;   // below the banner, clear of the forced board's 4-player header (2026-09-27, matches the escaped screen)
	survived.foreground = true;
	survived.fontScale = 2;
	survived.alpha = 0;
	survived.color = ( 1.0, 1.0, 1.0 );
	survived.hidewheninmenu = true;

	// v19.58: the survived line in the map's typeface (see tod_gameover).
	player tod_gameover::end_screen_push( survived, 2, 0 );

	if ( player isSplitScreen() )
	{
		game_over SetShader( banner, 600, 150 );
		game_over.y += 40;
		survived.fontScale = 1.5;
		survived.y += 40;
	}
}

// The arrival announcement: one banner per player, six seconds, gone. A
// server hudelem (baked art, zero LUI bits — the 61-bit ceiling untouched).
function arrival_banners()
{
	level endon( "end_game" );

	elems = [];
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		e = NewClientHudElem( p );
		if ( !isdefined( e ) )
			continue;
		e.alignX = "center";
		e.alignY = "middle";
		e.horzAlign = "center";
		e.vertAlign = "middle";
		// 600x150 at y-130 (live report 2026-08-29 on the choice banner's
		// identical geometry: "too big and off the screen on the top") — the
		// old 720x180 at y-170 put the top edge at -260 against the 480-unit
		// virtual screen's -240; this tops out at -205 with margin.
		e.y -= 130;
		e.foreground = true;
		e.color = ( 1, 1, 1 );
		e.hidewheninmenu = true;
		e.alpha = 0;
		e SetShader( "tod_spire_banner", 600, 150 );
		e FadeOverTime( 1 );
		e.alpha = 1;
		elems[ elems.size ] = e;
		p tod_upgrade_ui::banner_track( e );
	}

	wait 5;
	for ( i = 0; i < elems.size; i++ )
	{
		if ( isdefined( elems[ i ] ) )
		{
			elems[ i ] FadeOverTime( 1 );
			elems[ i ].alpha = 0;
		}
	}
	wait 1.1;
	for ( i = 0; i < elems.size; i++ )
	{
		if ( isdefined( elems[ i ] ) )
			elems[ i ] Destroy();
	}
}

// ---------------------------------------------------------------------------
// v17.97 — DEV PRINTS ARE MUTABLE. level.tod_dev_quiet (set beside tod_dev in
// zm_tower_of_doom::tod_resolve_dev_flags) silences every bottom-left IPrintLn
// in this file — screenshot sessions want dev + god with a clean HUD. Each
// print site's own tod_dev gate is unchanged; this is one extra gate under it.
// IPrintLnBold (real game toasts) is not routed here.
function tod_quiet_print( msg )
{
	if ( IS_TRUE( level.tod_dev_quiet ) )
		return;
	IPrintLn( msg );
}

function tod_quiet_print_to( msg )   // self = the player to print to
{
	if ( IS_TRUE( level.tod_dev_quiet ) )
		return;
	self IPrintLn( msg );
}

// =============================================================================
// v18.96 — THE KING'S PHASES. See the TOD_KING_PHASE_* defines for the design.
// Dev log tag [TOD_KING]: every crossing, whether a pause held the beat,
// whether the stun and the slow took, and the lever state after.
// =============================================================================

// THE ONE GATE for his rage (the berserk on every summons): rampage, or phase 3.
function king_rage_on()
{
	if ( king_rampage() )
		return true;
	return ( isdefined( level.tod_king_phase ) && level.tod_king_phase >= 3 );
}

// -> the phase a health fraction belongs to. Pure; test_king_rampage.js runs it.
function king_phase_for( frac )
{
	if ( frac <= TOD_KING_PHASE_3_FRAC )
		return 3;
	if ( frac <= TOD_KING_PHASE_2_FRAC )
		return 2;
	return 1;
}

// Polls his health (stamped once in king_setup, never re-stamped, so the
// fraction is monotonic) and climbs the ladder. Reads boss.health directly —
// king_hp_bar's published fraction is slammed to 0 at his death.
function king_phase_watch( boss )
{
	level endon( "end_game" );
	level endon( "tod_king_end" );
	boss endon( "death" );

	level.tod_king_phase = 1;
	king_dev_log( "phase watch up: hp " + boss.health + "/" + boss.maxhealth + " rampage=" + king_rampage() );
	while ( isdefined( boss ) && isalive( boss ) )
	{
		wait TOD_KING_PHASE_POLL;
		if ( !isdefined( boss ) || !isdefined( boss.maxhealth ) || boss.maxhealth <= 0 )
			continue;
		frac = ( boss.health * 1.0 ) / boss.maxhealth;
		want = king_phase_for( frac );
		if ( want <= level.tod_king_phase )
			continue;   // the ladder only climbs
		level.tod_king_phase = want;
		king_phase_enter( boss, want, frac );
	}
}

// The beat + the stagger + the levers for `phase`.
function king_phase_enter( boss, phase, frac )
{
	// A card deal can be open (the spire's round clock still deals): hold the
	// beat until the world moves — a stagger nobody can see or use is a
	// wasted beat, and slow_elite declines under the pause anyway.
	held = 0;
	while ( IS_TRUE( level.tod_upgrade_pause ) )
	{
		wait 0.25;
		held++;
	}
	if ( !isdefined( boss ) || !isalive( boss ) )
		return;
	king_dev_log( "PHASE " + phase + " at hp frac " + frac + " (held " + ( held * 0.25 ) + "s for a pause)" );

	// THE BEAT — every element the seal and the summons already use.
	tod_perk_scatter::derez_burst( boss.origin );
	tod_perk_scatter::play_sound_at_origin( boss.origin, "tod_teleport_fire", 4 );
	trial_sting();
	Earthquake( 0.5, 1.2, boss.origin, 1400 );

	// THE STAGGER — the counterplay window. The stock stun state (the vendored
	// pack's own `self.stun = 1` lane: half a second of stumble animation) for
	// the picture, and the elite slow for the guaranteed seconds — armed for
	// him by boss_pause_watch's base-rate stamp at spawn_panzer.
	stunned = false;
	if ( !IS_TRUE( boss.stun ) && !IS_TRUE( boss.stumble ) && !IS_TRUE( boss.berserk ) )
	{
		boss.stun = 1;
		stunned = true;
	}
	boss tod_zombie_speed::slow_elite( TOD_KING_STAGGER_MULT, TOD_KING_STAGGER_MS );
	king_dev_log( "stagger: stun=" + stunned + " slow_took=" + isdefined( boss.tod_eslow_until ) + " x" + TOD_KING_STAGGER_MULT + " " + TOD_KING_STAGGER_MS + "ms" );

	// THE LEVERS — the rampage lanes, owned by his health now. Phase 2: the
	// permanent sprint locomotion (ONE thread ever — king_setup already runs
	// it under rampage, and two writers on one blackboard attribute fight).
	// Phase 3: king_rage_on() turns true, and the summons loop reads it (the
	// berserk on every call + the 13 s cadence through king_summon_secs()).
	if ( phase >= 2 && !IS_TRUE( level.tod_king_sprint_on ) )
		level thread king_sprint( boss );
	king_dev_log( "levers: sprint_on=" + IS_TRUE( level.tod_king_sprint_on ) + " rage_on=" + king_rage_on() + " summon_secs=" + king_summon_secs() );
}

function king_dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_KING] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
