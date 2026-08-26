# docs/24 — Full map review: Tower of Doom: Cybercity (2026-08-21)

> ⚠️ **BANNER PROPOSALS IN THIS DOC ARE DEAD (2026-08-22).** Several items below
> prescribe work on "the boss-banner lane" (B8 PANZER DOWN, B9 CLOSING banner,
> ER-10 round-type banners, ECO-13 POWER RESTORED, the A15 HUD-collision fix,
> and the banner rows in the asset table). **That lane no longer exists** — the
> user cut it: *"remove all the announcement banners for the enemies spawning
> in. Its unnecessary."* Deleted in v9.21: `tod_boss_banner` and its eventstring,
> `banner()` / `banner_notify_all()` / `boss_banner_show()` /
> `boss_banner_show_seq()`, the whole LUI block in `tod_upgrade.lua`, and the
> `i_tod_banner_panzer` / `i_tod_banner_protectors` zone lines.
> **Do not re-add an enemy spawn banner.** A non-enemy banner (e.g. POWER
> RESTORED) would mean rebuilding the lane from scratch — confirm with the user
> before doing that, and prefer a sound or an FX. A15 is moot: there is no boss
> banner left to collide with the compass.

Eight subsystem reviewers, 123 findings, six bug-class items adversarially CONFIRMED. This document is the improvement plan. Source state reviewed: generator v9 (`LAPS = 50`, crown lap 51, 3178 brushes, LED bake 44.8 s), scripts at CHANGELOG v8.3, `level.tod_dev = true` / `level.tod_god = true` still armed in `scripts/zm/zm_tower_of_doom.gsc:254-255`.

Numbers used throughout (from `tools/gen_tower_map.js:210-212` and `_tod_finale.gsc:62`): `doorCost(lap) = min(1125 + 375*(lap-1), 6000)`, cap reached at lap 14. Laps 1-13 = 43,875; laps 14-50 = 37 × 6,000 = 222,000; lap doors 265,875; + crown 7,500 + power 750 = 274,125; + uplink 25,000 = **299,125 to finish**. Cumulative to floor 10 = 28,125 (+750 power); floor 20 = 85,875; floor 30 = 145,875; floor 40 = 205,875. CLAUDE.md's "25 floors" and "~15k to floor 5" are stale — the tower is 50 floors and the first breather costs 28,875.

---

## 1. How the map plays today

**Minute 0.** Black screen, then CHOOSE YOUR CLASS: four cards, a 30-second clock that says RANDOM IN N. Nothing says what the map is — not that the rounds never stop, not that there are 50 floors, not that there is an ending. Two upgrade cards appear (the round-1 event), you lock one, and the world unfreezes into a navy arena with a 512-square core in the middle and a staircase wrapping around its outside. You have a pistol, a stock-stat class gun, 500 points.

**Minutes 1-4.** Zombies sprint from round 1 (anim rate 0.8). Because the round ends when the last zombie *spawns*, rounds 1-4 (6/8/13/18 zombies at 1.6→1.37 s trickle) are over in ~66 s of wall time regardless of how you play; round 5 — and the first Panzer, 24,000 HP — arrives at about 1:40, while you have maybe 4k points. The first Protector wave cannot exist yet (it unlocks with the floor-10 door). By minute 4 you are at round 10, zombies are at full sprint and 1,045 HP, and you have been given a second upgrade event. The power switch is 1,340 units down a 120-wide dead-end corridor with no risers in it — which also makes it the safest spot in the map. Throwing it changes nothing you can see; the perks it enables are 10-40 floors up.

**Floors 1-13.** This is the part that works. Each door costs more than the last (1,125 → 5,625), the treads change colour every lap, the first Panzer climbs up after you, and at floor 10 you hit the first breather: a 384×400 balcony with two perk machines (one of the eight, randomly), an upgrade terminal, and zero risers. If Jugg landed here (25 % chance) the run opens up. If it is on floor 30 or 40 (50 % chance), you will be at 100 HP against full-sprint zombies until round ~23-33 solo. Buying the floor-10 door also silently unlocks Rogue Protectors — the first wave shows up three rounds later, from the base, and takes minutes to climb.

**Floors 14-50.** Every door is 6,000. Every lap is two 16-step flights and two 160-square landings, identical to the last one except for a colour that recurs every 8 floors. Risers sit dead-centre on the landings — the only spots with a two-way sightline, and 20 units from the next door's buy trigger — so zombies rise at your feet whenever you stop. The Panzer every 5 rounds and the Protector wave every 3 rounds spawn at z=0; a floor-25 player is ~37,000 units of stairs away, so "PANZER INBOUND" is followed by four minutes of boss music and nothing on screen, and the next Panzer is owed before the first arrives. Protectors pay 0 per hit and 250 per kill for 13k-43k HP, so nobody shoots them; they accumulate into a permanent 8-robot traffic jam that eats a third of the 24-AI budget. The perks reshuffle while the Panzer is still alive. The only box is at the base. There is no way down. The rational play is to sit in a breather — one 160-unit mouth, no risers, perks, terminal — until 60k points, then burst ten floors. Solo income crosses floor 20 around round 17-18, floor 30 around round 23, the crown around round 30-40 (2+ hours); a 4-stack finishes around round 20-25 with floors 25-50 costing under 10 % of a round each.

**The crown.** A gold stair off lap 50, a terrace (with a riser 112 units from where you arrive), a 640-unit causeway over nothing, and a 1536-square citadel with PaP, Mule Kick (useless with 4 perk slots already full), a terminal, an uplink dais, four pylons and an extraction pad. You pay 25,000 — about one round of income by then — stand in the roomiest, safest space in the map for 90 s while four small auras turn yellow to the purchase sound, walk 500 units, hold USE on a pad jammed against the north wall next to a pilaster, wait 6 s with full control, and read "YOU ESCAPED THE TOWER" over your own feet while the boss track keeps looping under the stock game-over music. No camera, no sting, no summary, no arrival moment.

**What is solid.** The endless-rounds override verifiably cannot wedge; the doors, zones, perk scatter, twin-variant plumbing, draft input, LUI lanes and the crown geometry are all correct and the map-1 traps are honoured. The map has a deep progression layer and a sound shell. What it lacks is *rhythm* — in the climb, the economy, the enemies and the sound — and it has never once been played with mortal money.

---

## 2. Top 12 changes, ranked by player impact per effort

### 1. Ship-gate the build: flip dev/god off, silence dev prints, one mortal playthrough — **S**
- **Why.** Every session so far has run on the 100k money loop and demigod (`_tod_main.gsc:40-62`, `_tod_bosses.gsc:1409-1416`). Nobody has felt a 299k ladder at 60-130 points a kill. Every balance number below is a hypothesis until this happens.
- **How.** `scripts/zm/zm_tower_of_doom.gsc:254-255` → both `false`; `.\tools\build_map.ps1 -GscOnly`; verify a fresh `.ff` (the deployed one is the armed build). Add a guard to `build_map.ps1` before the sync step: `Select-String 'level\.tod_(dev|god)\s*=\s*true'` on the repo copy → loud `Warn` repeated in the READY TO TEST summary (optionally `-Ship` switch turns it into `Die`). Stub `_tod_perk_scatter.gsc::debug_dump/dev_print` (:490, :501) the way `_tod_bosses::dbg` was. Then: one solo + one duo run at ship values, and one finale pass with `tod_dev=true, tod_god=false` so the left-behind / downed branches execute (CR-18).
- **Assets.** None.

### 2. Co-op respawns land near the team, not at z=0 — **S**
- **Why.** One `player_respawn_point` group (`gen_tower_map.js:786-806`) with `script_noteworthy 'start_room'` — a zone name that does not exist — so stock leaves it `.locked` forever and every respawn falls back to the initial spawn struct at the base. A teammate who dies on floor 35 comes back alone, 35 laps down, and drags base risers and boss anchors with them.
- **How.** No `.map` regen needed: set `level.check_valid_spawn_override = &tod_respawn_near_team` in `_tod_endless_rounds::init()` (consumed at stock `_zm.gsc:3290-3293`). It picks a living non-laststand teammate via `zm_utility::is_player_valid(p, undefined, true)`, returns a `SpawnStruct()` at a navmesh point near them (reuse `_tod_bosses::pick_spawn_point`'s scatter, reject `positionWouldTelefrag`), or `undefined` to fall back. If the generator route is preferred instead, each new respawn group MUST carry `script_noteworthy` = its zone name (`lap10_zone` … `roof_zone`) or it stays locked. Pair with ER-05: set `level.zombie_vars["spectators_respawn"] = false` and respawn on a lull or after 90 s dead, because round boundaries are now ~45 s apart and death is otherwise a one-minute timeout with a free 1,500.
- **Assets.** None.

### 3. Jugg/Speed guaranteed low, perk slots grow with the climb, Mule Kick joins the scatter — **S**
- **Why.** Jugg is uniform over 8 pads: 25 % of runs put it behind 205,875 of doors; half put it at floor 30+. Meanwhile the 4-slot cap makes floors 30/40 and the crown's Mule Kick dead content.
- **How.** `_tod_perk_scatter.gsc::apply_scatter` (:282-308): split specs into tier-1 `{Jugg, Speed, Stamin-Up}` and tier-2; shuffle each; fill pads 1-2 (floor 10) from tier-1 first, the rest from the concatenation. Add a derangement retry so no machine lands on its current pad (PK-11: `for tries<25 … if !any_fixed_point break`). Move Mule Kick into the pool (9 machines / 9 pads, no empty pad; `gen_tower_map.js:975` machine parks at the base N wall like the others). `_tod_doors::breather_unlock` (:159-165): `level.perk_purchase_limit++` per breather door → 5/6/7/8 (stock reads it live, `_zm_utility.gsc:5874-5889`). Deadshot 3,500 → 1,500 and give it the luck-perk hook (headshot luck ×2 while held, one line in `_tod_luck`).
- **Assets.** None.

### 4. Bosses spawn a fixed number of laps below the lowest player; Protectors drop from above — **M**
- **Why.** `base_spawn_origin()` (`_tod_bosses.gsc:228-236`, used at :578 and :952) makes a floor-25 Panzer a 3.7-minute rumour and a floor-50 one a 7-minute soundtrack. The anti-strand watchdog never shortcuts a climb. This is the single biggest reason the boss layer does not feel like a boss layer. Bosses-at-the-bottom was a user decision (2026-08-20); this is a deliberate challenge to it on player-experience grounds — the climb stays ("he climbs to you"), it is just bounded.
- **How.** Have the generator emit `level.tod_lap_landing[lap]` (mid-landing centre per lap) into `_tod_door_data.gsc` next to the door coords. `spawn_panzer(anchor)` / `spawn_protector(anchor)` take an optional anchor; the director computes the lowest living player's floor F (same math as `_tod_gauge::floor_of`) and anchors the Panzer at lap `max(1, F-3)` (~30 s climb) — `pick_spawn_point`'s zone gate (:506-522) still vets it. Protectors: anchor = landing of `min(highest_floor + 2, highest bought lap)`, play `zod_robot_flyin_fx` on a script_model descending 1,200 z over 1.5 s, then the existing slam/quake — they come DOWN the stair you were about to climb while zombies rise ahead: a pincer. Gate `landing_rumble` (:1078) on distance < 1,500. Finale: while `level.tod_finale_state == "charging"` the director anchors at `tod_crown_data::gate_org()`.
- **Assets.** None.

### 5. Risers off the landings; pick spawn points that come from below — **S**
- **Why.** Both risers per lap are the exact centres of the mid and end landings (`gen_tower_map.js:720-722`); the end one is 20 u from the next door's radius-96 buy trigger. The two places the design asks you to stand still are where zombies erupt.
- **How.** Script first (no bake): `level.zm_custom_spawn_location_selection = &tod_pick_riser` in `_tod_endless_rounds::init()` (stock hook, `_zm_spawner.gsc:2950`) — filter spots to `DistanceSquared ≥ 512²` from every living player AND `origin[2] ≤ lowest player z + 64`; fall back to the farthest, then `array::random`. Generator second: move risers to the lower third of each flight — odd lap mid riser → `(336, -144, b+48)`, end riser → `(-64, 336, mid+96)`, mirrored for even laps — and the terrace pair to the far west end `cpt(-440, 440)` / `cpt(-440, 300)`. Tighten lap zone volumes to `z2 = lapBase + LAP_RISE + 72` (L10) so occupancy is exact. Later, if the bake allows (+8 brushes/lap): spawn niches cut into the core face at mid-flight, lit in the district colour.
- **Assets.** None.

### 6. Earned lulls and a kill-aware round clock — **S**
- **Why.** Rounds 1-5 are spawn-rate-bound (round 5 at ~97 s, round 10 under 4 min) so every round-keyed system runs 3-5× faster than stock in the opening; and nothing — not a Panzer kill, not a 6,000-point breather door — ever changes the pressure for the next 30 s.
- **How.** `_tod_endless_rounds.gsc::tod_round_wait` (:93): exit on `zombie_total <= 0 && zombie_utility::get_current_zombie_count() <= TOD_CARRY_CAP` (8 solo / 12 co-op) — the next wave still begins with zombies alive, the counter just cannot outrun the player. Add `lull(seconds)`: `flag::clear("spawn_zombies"); wait; flag::set` (the stock Nuke lever, `_zm.gsc:3753`) with a `level.tod_lull_until` stamp so calls extend rather than stack; 20 s on Panzer death (`panzer_life`, after :860), 20 s on every breather door, 10 s on Gift of Death pickup. Fix round-1 co-op trickle (:55 hardcodes solo 1.6 — set it after `initial_blackscreen_passed` via `tod_spawn_delay(1)`), remove the `sndMusicSystem_PlayState("round_end")` call at :98 (the BO3 round-over jingle plays over our loop every minute, contradicting the twist). Add the floor-band term from ER-06 so the climb, not the clock, is the ramp: `rate += bands * 0.04`, round step 0.003 → 0.002, trickle `d *= (1 - 0.08*bands)`. Per-zombie rate jitter `RandomFloatRange(0.92, 1.08)` and a 1.15 cap (ER-07) so the horde arrives as a stream, not a wall.
- **Assets.** Optional 10-20 s low pad for the lull window.

### 7. A door economy with rhythm: district saw-tooth + party-size scaling — **M**
- **Why.** 81 % of the climb is 37 identical 6,000 tolls. Solo pays 100 % of a shared cost on ~1/3 of a squad's income. The economy is a flat tax that is brutal solo and trivial in a squad.
- **How.** `gen_tower_map.js:210`: `cost = 1500 + 500 * ((lap - 1) % 10)` — every district starts cheap and ends with the breather door as the 6,000 gate; total 187,500 (−30 %). In `_tod_doors::door_buy_setup` scale by party size at init (`GetPlayers().size` is valid after blackscreen): ×0.75 / 1.0 / 1.25 / 1.5 for 1/2/3/4 players; refresh hints once. Target: solo crown ~round 24, quad ~round 22 — validate in the mortal run from #1. Add the `FLOOR_KIND` table keyed on `lap % 10` so the generator's flight loop varies the middle: `%10==7` dark floor (skip both `light()` calls, emissive treads only), `%10==5` outrigger pocket (L9: 160×160 off the mid landing's outer side, 3 rails + caps + zone brush, ~8 brushes each, normal risers so it is not a camp), `%10==3` split flight. Optional later: toll meter (any player pays 500 increments into `d.tod_paid`) and an Express Ascent bundle at breather terminals (ECO-09).
- **Assets.** None.

### 8. A second verb: lift pads down, plus a box and a PaP mid-tower — **M/L**
- **Why.** The tower is strictly one-way. The scatter reshuffle — the map's signature perk mechanic — is invisible after floor 15 because going back is 20 laps of open stairs; QR is unreachable for a downed teammate; the only box is at the base so Fire Sale can never drop (`_zm_powerup_fire_sale.gsc:244`, `chest_moves` stays 0) and PaP is at 273k points. docs/23 B2 called this the highest fun-per-hour item and it is still open.
- **How.** New `_tod_lifts.gsc`: generator emits a 128-sq × 8 u pad in `MAT.exfilPad` on every breather at `(-600, -450, mid)` (NW corner, 150 u from the station trigger) and one at the base `(-300, 470, 0)`; script spawns a `trigger_radius_use` (+`TriggerIgnoreTeam`, radius 72) on each. Breather pad = free ride DOWN to the base (or any lower unlocked breather); base pad = ride UP to the highest opened breather for 1,000 (checks `flag::get("enter_lapN")`). `SetOrigin` + the existing derez/strike FX, 10 s cooldown, requires power. Generator also emits `buyable_magic_box` prefabs on the floor-20 and floor-40 breathers and in the crown hall (stock teddy cycle then moves the box UP the tower; Fire Sale goes live), and a second `vending_weapon_upgrade_spawnable.map` on the floor-20 breather inboard strip (~`(-300, -460, 7488)` yaw 0 backing the north seal). Make the FIRST Panzer kill drop `tod_pap` guaranteed next to the Max Ammo (`_tod_bosses.gsc:872`).
- **Assets.** Optional lift-pad decal (a `_tinted_edge` brush works without one).

### 9. Make bosses worth shooting: protector economy, debt cap, unlock-round wave, Panzer HP — **S**
- **Why.** Protectors: 0/hit, 250/kill, 7000 × 1.07^(r-3) HP, debt never forgiven, 8 alive max → furniture that throttles the round clock. Panzer: 24k × 1.075^(r-5) = 71k at round 20 (~5.8 min of body fire) → nobody fights him after round 10 unless the Gift of Death drops. The first protector wave lands 3 rounds after the unlock (CONFIRMED). "Halve ALL Panzer damage" misses the flame beam and the 100-dmg slam.
- **How.** `_tod_bosses.gsc`: per-hit `attacker zm_score::add_to_player_score(10)` in `rp_damage_feed` (:1448+); `TOD_RP_PTS` 250 → `300 + 20*round`; `TOD_PROTECTOR_HP_EXP` 1.07 → 1.045, base 7000 → 5500; `round_watch` (:334) `debt = min(debt + rp, 2*rp)`; `TOD_RP_MAX_ALIVE` 8 → 6 and `level.zombie_ai_limit = 24 - bosses_alive()` (floor 12) so the 31-actor corpse wipe never triggers (ER-08). Panzer: base 16000, exp 1.05, `TOD_PANZER_HEAD_SCALE` 0.9 → 1.2 (the spiral hands you a vertical shot at his faceplate). `unlock_watch()` thread: on `tod_enemy_unlocked "protector"` add `protector_due(round)` debt + banner, with a `tod_protector_served_round` latch shared with `round_watch` so the <1 s post-round-change window cannot double-wave. `boss_player_damage` (:1381): replace the GRENADE-only gate with "attacker is Panzer and MOD is not MELEE" → ×0.5. Exclude bosses from the DR domain or cap DR at 6 (U10). Drop the Max Ammo at `killer.origin`, PANZER DOWN banner (id 3), pulse the luck frame for the last hitter (B8). Move `mechz_health_increases()` after a successful `SpawnActor` (B14); strict mode for `pick_spawn_point` so no fallback ever places a boss on the player's origin (B7).
- **Assets.** One banner image "PANZER DOWN" (540×84, existing family); optional "WAVE CLEARED".

### 10. The music plan: altitude bands, gated boss track, owned ending — **M (assets)**
- **Why.** One 145.6 s loop heard 25-50 times; hard stop/start swaps; the boss track starts the instant he spawns 40 floors away; stock's `game_over` state stacks on our never-stopped loop at the end; the finale is scored by the Panzer track.
- **How.** `_tod_atmosphere.gsc`: `band_of(cell)` 1-5 from the highest living player's cell (`_tod_gauge::gauge_loop` exposes `level.tod_top_cell`); on band change `PlayLocalSound tod_band_rise` then `channel_play("tod_music_band"+n)`; add FadeIn/FadeOut 1500 to every music row in `sound/aliases/tod_ui.csv`. Boss: `tod_boss_horn` one-shot on spawn; `boss_track_start()` only when the boss's cell is within 4 cells of the nearest player (driven from the gauge tick). Finale: `finale_track_start` → `tod_music_finale`. End: `level thread end_game_watch()` → `channel_stop()`; `level.sndPlayStateOverride` blocks `"game_over"` (stock hook `_zm_audio.gsc:1098`); play `tod_end_escaped` / `tod_end_fallen` per player (LOADED, < 12 s). Proximity pulse per boss (`tod_boss_pulse_far/mid/near`, every 8/4/2 s by cell distance).
- **Assets.** See §5 — 5 band loops, 1 finale loop, `tod_band_rise`, `tod_boss_horn`, 2 end stings, 3 boss pulses.

### 11. An ending that escalates, is seen, and sounds like one — **M**
- **Why.** The 90 s hold-out is the easiest 90 s in the map; no camera; every beat is `zmb_cha_ching`; departure is 6 s of normal play; the pad is a dead-end pocket 16 u from a pilaster with risers 480 u to each side.
- **How.** `_tod_finale.gsc::finale_run` (:263): `level.tod_finale_hot` → `tod_spawn_delay` returns `max(d*0.5, 0.15)`; pylon 1 `protector_debt += 2*players`, pylon 2 `panzer_debt += 1`, pylon 3 `+= 3*players`, final quarter +25 % zombie rate; flip 3 of 12 sconces to yellow per quarter so the walls are the progress bar. Anchors per #4. Seal the gate at charge start (CR-12: a `tod_crown_gate` script_brushmodel slab using the door machinery; the uplink becomes a real 2.5 s hold, CR-09, so teammates have time). Generator: move the pad to the dais (`EXFIL_Y = HYC`, DAIS 112 → 160), drop or flush the N pilaster, add 4 hall risers, emit one `info_intermission` at `cpt(0, HN + 1100, TOP2 + 640)` angles `25 ${cyaw(270)} 0` — stock then cuts to a shot of the citadel with the tower falling away. Departure: white `lui::screen_fade_out(1.5)` at t=4.5, `FreezeControls` at t=5.5, rumble at 0 and 5. Exfil window instead of all-or-nothing (CR-04): first valid press starts a 20 s boarding countdown; non-boarders see LEFT BEHIND. Stock sound swaps now (ignite → `zmb_perks_power_on`, online → `zmb_lightning_l`), custom wavs later. `prop()`/`station_place`: `DisconnectPaths()` on the uplink and terminals (CR-08). Both use-loops honour `level.tod_upgrade_pause` and `depart()` waits it out (CR-03). Crown door hint warns when power is off (CR-16).
- **Assets.** `tod_uplink_buy`, `tod_pylon_ignite_1..4`, `tod_uplink_online`, `tod_extract_depart`, `tod_victory_sting` (see §5).

### 12. Tell the player where they are and what they just did — **S each**
- **Why.** No floor is distinguishable without the HUD; breathers share their lap's colour and have no arrival moment; doors open as a silent blink; the door card says "Buy to unlock new areas" on all 52 doors; nothing in the first minute states the premise.
- **How.** Generator: `lapPal(lap) = BAND[floor(lap/10)]` (cyan/green/orange/red-pink/purple — bake-neutral, material tokens only), yellow EXCLUSIVE to breather floors + crown, next-district colour on the lap before a breather as a "one more floor" tell; breather light gold `1 0.85 0.35` radius 600, floor `MAT.crownRing`, parapets `MAT.crownFascia`. Script: per-breather `trigger_radius` (260) → once per player `tod_breather_arrive` + derez on both pads + luck +3. Doors: `slab NotSolid(); ConnectPaths(); MoveZ(130, 1.5)` (the authored `script_vector`/`script_transition_time` nobody reads), `derez_burst(info.org)` + `play_sound_at_origin(info.org, "zmb_heavy_door_open")` — `info.org`, never `slab.origin`. `PromptDoors.lua:160`: `string.match(hint, "[Oo]pen [Dd]oor to%s*(.-)%s*%[")` → "Unlocks <dest>"; door strings → "Floor 10 - BREATHER (perks + terminal)", "the Crown - THE UPLINK". Fog: `TOD_FOG_HALFWAY_HEIGHT` 1200 → 4000, `HALFWAY_DIST` 2600 → 2000 so the smog thins across the whole climb and the base reads hazy. Briefing plate in `tod_class_select.lua` (y 645-715 is free) and open the gauge menu during the draft. Power: cyan surge FX down the hall + "POWER RESTORED" banner.
- **Assets.** `i_tod_briefing.png` 900×140; "POWER RESTORED" banner; `tod_breather_arrive.wav`.

---

## 3. Confirmed bugs

### Adversarially CONFIRMED

| Sev | File:line | What breaks | Fix |
|---|---|---|---|
| 5 | `tools/gen_tower_map.js:786-806` (L1) | Single respawn group with `script_noteworthy 'start_room'` (no such zone) → `_zm_zonemgr` never unlocks it → `check_for_valid_spawn_near_team` returns undefined → every co-op respawn falls back to the initial spawn struct at z=0. | `level.check_valid_spawn_override = &tod_respawn_near_team` (spawn struct near a living teammate); or new groups with `script_noteworthy` = zone name. Top-12 #2. |
| 4 | `scripts/zm/zm_tower_of_doom.gsc:254-255` (ECO-01) | `tod_dev`/`tod_god` armed: 100k money loop, no downs, upgrades every round, Panzer from round 3, 20 s finale. Deployed `.ff` is the armed build. Economy at current prices has never been played mortal. | Flip both false, `-GscOnly` rebuild, build-script ARMED warning, mortal solo+duo run. Top-12 #1. |
| 4 | `ui/uieditor/menus/hud/tod_upgrade.lua:177-185` + `AetheriumStartMenu.lua:458,484` (U1) | THOR'S THUNDER (domain 20) has no `CARD_SLUG`, so `PaintCard` makes no `setImage` call and the slot shows the PREVIOUS event's card image with a thunder rarity strip; the intended composite fallback is unreachable (early return at :485); pause list stops at id 19 so thunder levels are invisible. | Add `[20] = "thunder"`, bake `i_tod_card_thunder_{regular,super,ultimate}` + `i_tod_pause_r20`, zone them, loop to 20 / `PAUSE_PLATE_MAX = 20` (derive from `#DOMAIN`). Safety net: when `art.cards[dom]` is nil set CardImg to a neutral registered plate and fall through to the composite path (alpha-0 does not stick — `SetCardAlpha` re-raises it). Fix the "at most 8 domains" comment (slasher and heavy are 9). |
| 4 | `scripts/zm/zm_tower_of_doom/_tod_powerups.gsc:293` (PK-03) | `zm_perks::give_random_perk()` iterates every `level._custom_perks` key, including the stock `specialty_electriccherry` registered by the `#using` at `zm_tower_of_doom.gsc:47` — a perk with NO machine on the map. ~1-in-10 bottles grant it: stock reload attack fires alongside ours, stock downed-explosion, and it is the only thing that lights the Aetherium cherry icon (our `specialty_combat_efficiency` cherry never does). | Map-owned picker: candidates = `script_noteworthy` of every `GetEntArray("zombie_vending","targetname")` (machines that physically exist; do NOT use `level.tod_scatter_machines`, which is empty until capture), filter `!HasPerk && !has_perk_paused`, `give_perk(pick)`, else Max Ammo. Cap bypass is stock-consistent; decide it as design (recommend respecting `can_player_purchase_perk()` once slots scale, #3). |
| 3 | `scripts/zm/zm_tower_of_doom/_tod_perk_scatter.gsc:147-169` (PK-02) | Reshuffle keys on `round_number` flipping to 6/11/16; under endless rounds round 6 begins ~31 s after round 5's Panzer spawns at the base with 24k HP — machines warp mid-fight (85 u `unstick_players` nudge included). Nothing in the scatter path reads `tod_panzer_alive`. | After the clamp at `_tod_bosses.gsc:860-862`: `if (level.tod_panzer_alive == 0) level notify("tod_panzer_down")`; `round_watcher` waits on it, `wait 3`, respects the upgrade-pause guard. Or minimal: keep the round trigger and insert `while (level.tod_panzer_alive > 0) wait 0.5;`. Update the header comment + CLAUDE.md. |
| 3 | `scripts/zm/zm_tower_of_doom/_tod_bosses.gsc:317-347` (B3) | `breather_unlock` only stamps + notifies; nobody listens; `round_watch` evaluates `protector_due` on the next round change where `(r-start)%3 == 1` → first wave at unlock+3, not on the unlock round (user spec, documented three times). | `unlock_watch()` adding `protector_due(round)` debt + banner on the notify, with a `tod_protector_served_round` latch shared with `round_watch` (the <1 s window after a round tick would otherwise double-wave). |

### Unverified bug-class findings (reviewer confidence only — verify in code before fixing)

| Sev | Conf | File:line | What breaks | Fix |
|---|---|---|---|---|
| 4 | 0.90 | `_tod_upgrades.gsc:1226` (U2) | `thor_shock`'s `DoDamage` re-enters `upgrade_damage_cb` with the knife as weapon → ×(1+0.12·dmg_lvl)×dmult; thunder Lv5 + DAMAGE Lv10 = 165 % max-HP AoE insta-kill every 450 ms. | Mark victims `z.tod_thor_hit = true` and `return -1` in the callback (the cleave idiom); exclude from dmult. |
| 3 | 0.85 | `_tod_upgrades.gsc:1244` (U3) | `cleave_splash` calls `DoDamage(dmg, org, attacker)` with no MOD/weapon → 60-pt body kills, no LEECH/BOUNTY. | `DoDamage(dmg, z.origin, attacker, attacker, "none", "MOD_MELEE", 0, weapon)`. |
| 3 | 0.80 | ~~`_tod_doors.gsc:96-100`~~ **FIXED 2026-08-26** (ECO-05) | Door buy did not reject laststand / `in_revive_trigger` / drinking; radius-96 triggers on a 160-sq landing → a revive press ALSO bought the door (reviving polls the raw USE button, `_zm_laststand.gsc:1129`, so it is both, not either/or), and a crawler could buy it himself (his own revive trigger is `SetInvisibleToPlayer(self)`, so the door trigger was his only use-ent). | DONE: `in_revive_trigger` + `is_player_valid` guards in `buy_trigger_wait`, and the same revive guard on the four other charging loops (breather PaP, ammo crate, uplink, station) plus the teleporter pads. **`UseTriggerRequireLookAt()` deliberately NOT added** — stock has it commented out on every blocker path and these are two origin-offset radius volumes, not aimed at the slab; that is a separate, riskier change needing a live test. |
| 3 | 0.75 | `_tod_upgrades.gsc:693` (U8) | Upgrade event fires with a player in laststand; bleed-out keeps running during the 15 s freeze while revivers are pinned. | Defer the event up to 20 s while anyone is down; exclude downed players and re-present on revive. |
| 3 | 0.75 | `_tod_bosses.gsc:1381-1388` (B6) | 0.5× Panzer multiplier applied only on MELEE (via mitigations) and `*GRENADE*` lanes; the flame beam and the 100-dmg no-MOD slam land full. | Gate on "attacker is Panzer && MOD not MELEE". |
| 3 | 0.90 | `_tod_bosses.gsc:297, :601` (B7) | Watchdog teleport and Panzer spawn retry fall back to the target player's origin. | `strict` flag on `pick_spawn_point` → undefined; retry next tick. |
| 3 | 0.95 | `_tod_upgrades.gsc:838-849` (A4) | Co-op events draw a server hudelem "CHOOSING: name, name" at y=96 — floaty text. | LuiNotifyEvent `tod_upg_wait` + baked WAITING FOR SQUAD plate. |
| 3 | 0.85 | `_tod_atmosphere.gsc:55` (A2/CR-07) | No `channel_stop()` on `end_game`; stock `game_over` state plays over our loop (boss track latched by the finale). | `end_game_watch` + `sndPlayStateOverride`; own end stings. |
| 3 | 0.80 | `_tod_finale.gsc:129` (CR-02) | Beacon/uplink glows set while viewers are 19k u away and never re-pulsed (finale ents are not in `level.tod_glow_ents`). | Push them into the rekick array; make mast tier 5 an emissive material for the seen-from-below goal. |
| 3 | 0.60 | `_tod_finale.gsc:363` (CR-03) | Pad/uplink use loops ignore `tod_upgrade_pause`; `depart()` can `end_game` under an open card UI. | `continue` on pause in both loops; countdown only while unpaused; scheduler skips events once departing. |
| 2 | 0.85 | stock `_zm.gsc:3740` (ER-08) | 8 RP + Panzer push `get_current_actor_count()` to the 31 limit → corpses wiped every 0.1 s, zombie stream thins, round clock stalls. | `zombie_ai_limit = 24 - bosses_alive()`, RP max 6. |
| 2 | 0.85 | `_tod_endless_rounds.gsc:55, :98` (ER-11) | Round-1 delay hardcoded solo; stock `round_end` music state fires every round. | Set after blackscreen via `tod_spawn_delay(1)`; remove the PlayState. |
| 2 | 0.90 | `_tod_perk_scatter.gsc:282` (PK-11) | ~61 % of reshuffles leave ≥1 machine on its own pad (with arrival FX there). | Derangement retry. |
| 2 | 0.90 | `_tod_perk_scatter.gsc:490, :501` (A5) | Dev IPrintLn scatter dumps on screen while armed. | Stub like `_tod_bosses::dbg`. |
| 2 | 0.85 | `_tod_upgrades.gsc:337` (PK-14) | Bare `SetPerk("specialty_staminup")` at SPRINT Lv5 → machine denies with a sigh, no icon. | `zm_perks::give_perk` once. |
| 2 | 0.60 | `_tod_powerups.gsc:195` (PK-15) | Zombie Blood writes `ignoreme` directly (stomps the stock refcount); Panzer target picker ignores it. | `increment/decrement_ignoreme`; skip blooded players in boss target pickers. |
| 2 | 0.60 | `_tod_bosses.gsc:584` (B14) | `mechz_health_increases()` before `SpawnActor`; failed attempts at the AI cap ratchet part HP every 3 s. | Move after a successful spawn or per-round latch. |
| 2 | 0.60 | `_tod_finale.gsc:101` (CR-08) | Uplink/terminals spawned without `DisconnectPaths()` → zombies phase through what blocks players. | `m DisconnectPaths()` after `SetModel`. |
| 2 | 0.50 | `_tod_upgrades.gsc:508` (U15) | Two `reconcile_twin` calls inside the 1 s retry window can leave a stale twin. | Per-player busy latch; take any non-want variant in the loop. |
| 2 | 0.50 | `_tod_finale.gsc:384` (CR-15) | `refuse_flash` thread per USE frame, first to wake clears the flag; no debounce. | `notify/endon("tod_refuse")` + `wait 0.5`. |
| 1 | 0.80 | `_tod_upgrades.gsc:1570` (U14) | Station buyer regains jump during an event takeover. | Only `AllowJump(true)` when `!tod_menu_frozen`. |
| 1 | 0.70 | `_tod_bosses.gsc:1132` (B16) | RP `SetGoal(target.origin)` unprojected every 0.5 s. | Reuse the Panzer's navmesh projection ladder. |
| 1 | 0.70 | `_tod_doors.gsc:57` (ECO-14) | Unknown-door early return leaves the slab non-solid for AI. | Solid/DisconnectPaths before the info check. |
| 1 | 0.70 | `tod_upgrade.lua:115`, `tod_class_select.lua:63` (A16) | `IsGamepadEnabled(0)` for all split-screen players. | Pass `InstanceRef`. |
| 1 | 0.95 | `gen_tower_map.js:48, 190-196, 300-302`; `_tod_atmosphere.gsc:44`; `_tod_gauge.gsc:18-21`; `sound_assets/tod/music/README.md:13` (L14, A17) | Comments cite 25 laps / 2400-brush budget / 6 machines / vol 50-75 / placeholder wavs — all stale. | Refresh to v9 values. |

---

## 4. Per-subsystem findings (condensed)

### 4.1 Layout & route
- **Monotony of floors 14-50** (L3/ECO-02): 37 identical half-revolutions. Fix via the generator `FLOOR_KIND` table and saw-tooth cost (Top-12 #7).
- **Breather camp** (L6): one 160 u mouth, zero risers, perks + terminal inside; rational play is to never leave. Keep zero risers as *arrival grace* and expire it: generator emits 2 late risers per balcony (`lapN_zone_late_spawners`, behind the perk line, not targeted by the volume); `_tod_breathers.gsc` appends them to `level.zones["lapN_zone"].a_loc_types["zombie_location"]` 3 rounds after the buy. Cheaper lever: `is_spawning_allowed = false` for 3 rounds then normal risers.
- **Ordinal colour** (L5/A7): district palette per 10 floors (Top-12 #12). Optional number plates: 96×96 brushes on the core face per mid landing with digit materials.
- **Lift pads** (L4/ECO-08): Top-12 #8.
- **Power hall** (L8/ECO-06): 1,340 u riser-free dead end, the safest camp in the map, switch buys nothing visible. Make it its own `power_zone` (volume + 1 riser behind the switch) adjacent to `base_zone` on `enter_power` (flag already exists) so zombies come from both ends only once the door is bought; power-gated electric trap across the mouth at x≈600 (`_zm_trap_electric` is already `#using`'d and no trap exists); window slot in the S wall at x[1000,1100] z[48,112]; optional 20 s spawn surge on power_on.
- **Zone overlap** (L10): `z2 = lapBase + LAP_RISE + 200` spans the next lap's first flight → 4 laps of risers active on a lower flight. Set `+72` and emit only the sides a lap uses.
- **Base pinch points** (L11): 104 u east strip and 144 u SE pass. `ARENA` 540 → 600, power-room N wall to y=-440. Bake-neutral.
- **Blind corners** (L12): core corner windows at landing height (128 w × 96 h notch, +150 brushes; breather/pocket laps only if the bake balks); `TOD_BOSS_FIRE_ZDELTA` 300 → 400.
- **Crown arrival** (L13/L7): terrace risers to the west end; `roof_zone` spawning off for 10 s after `enter_roof`; pad to the dais; N pilaster flush; `is_spawning_allowed = false` for roof_zone at ONLINE so extraction is fought against what is present.
- **Outrigger pockets** (L9): laps 15/25/35/45, ~32 brushes total.

### 4.2 Doors, economy, power
- **Cost curve + party scaling** (ECO-02/12): Top-12 #7. Uplink: 15,000 + 2,500 × rounds-since-crown-door so lingering costs money; pay the hold-out back as a drop train (Max Ammo at 25 %/75 %, Insta-Kill at 50 %).
- **Door card destination** (ECO-03): `PromptDoors.lua:146-167` never parses the `Open Door to <dest>` the GSC authors. One `string.match`.
- **Door feedback** (ECO-11/A9): slide + sound + derez; fire the stock `open_door` score event.
- **Door buy guards** (ECO-05): see bugs table.
- **Team toll / Express Ascent** (ECO-09) and **WAGER terminal** (ECO-10: stake 5k/10k/20k, 60 s forced 0.3 s trickle, stay in the balcony, win 2× + Max Ammo + 20 luck): the only non-door sinks past floor 14 are perks and the quadratic station. Sprint 3 candidates.
- **Power feedback** (ECO-13): Top-12 #12.
- **Enemy unlock slots 20/30/40** (ECO-07): see 4.6.

### 4.3 Rounds & pacing
- **Carry-over cap / minimum round duration** (ER-01), **lulls** (ER-03), **floor-band difficulty** (ER-06), **rate jitter + 1.15 cap** (ER-07), **round-1 co-op delay + round_end state** (ER-11): Top-12 #6.
- **Co-op respawn cadence** (ER-05): `spectators_respawn` runs every ~45 s boundary → death is a timeout. Own it (Top-12 #2).
- **Grenade refill every round** (ER-09): `award_grenades_for_survivors` cannot be disabled without `headshots_only`; restore the pre-boundary lethal count on `start_of_round` unless `round % 4 == 0`.
- **Round types** (ER-10): 1-in-6 from round 7, never on a boss round: BLACKOUT (fog to street density), OVERCLOCK (`super_sprint` gait at 0.85, count halved), HEAVIES (count ×0.5, HP ×3, eye tint, double points), FLOOD (trickle 0.15 then a 15 s lull). Banners ride the boss-banner lane. Sprint 3.
- **Floor as the headline number** (ER-12): push the real floor (1-50) over `tod_floor` and render baked numerals beside the gauge; "FLOOR xx" above "ROUND xx" on the end screen.
- **Actor ceiling** (ER-08): bugs table.

### 4.4 Classes, upgrades, luck, draft, station
- **Thunder** (U1/U2/U3): bugs table; U3's MOD_MELEE fix applies to `thor_shock` too.
- **Heavy dominance, skirmisher runs dry** (U4): ECHO ×DAMAGE = 4.4× + REGEN/DR; skirmisher has 16 class levels, 6 of them twins. Cap ECHO at 5 levels (or 6 %/Lv); new skirmisher signature MOMENTUM (kill stacks: +4 % dmg / +3 % speed per stack, decay 3 s — hooks `on_class_gun_kill`, `upgrade_damage_cb`, `apply_move_speed` all exist); ASSAULT EXECUTION (headshot kills refill 20 %/Lv clip via `SetWeaponAmmoClip`).
- **Agency** (U5/U6): no reroll, uniform 1-of-2, LUCK is a dead pick (~+3 levels per run for 5 picks; bar resets to 0 at :748 and :1594). Reroll = hold D-pad UP for 30 luck (max 2/event); LUCK reset becomes a FLOOR `10 × luck_lvl`; no-repeat rule on the rejected domain. Third card is bit-neutral: `todMagBonus` (7 dead bits) → `todUpgCD`(5)+`todUpgCR`(2) in the same slot — APPEND-ONLY discipline respected because the slot and order do not move. Deal 3 at luck ≥ 70 or always at the station.
- **Protector luck flood** (U7): +4 per unit × round/3 units re-saturates the bar. Budget per wave: `12 / wave_size` per unit; Panzer keeps +20.
- **DR × Panzer halving** (U10): 0.25× at Lv10. Exclude bosses from DR or cap at 6.
- **Slasher ranged answer** (U11): make the pistol a class primary for slasher (`is_class_primary` match, ×12), plus the floor-20 PaP (#8).
- **Draft timeout** (U12): a focused card that the clock ignores is a lie. Random only if input was never touched; else lock the focus.
- **Late joiners** (U9): random permanent class, no panel. Run `player_select` without the pause and deal the missed round-1 card via the station flow at cost 0.
- **Station ceiling** (U16): `2000 + 1000n` never decays; cap at 10,000 and step back one notch per scheduled event.
- **Show the build** (U13): owned-level pips under each card from `CoD.TodOwned` (zero new bits); run-summary card on death (docs/23 C4/D5).
- **Class ultimates** (U17): ULTIMATE-only 1-level class cards (JUGGERNAUT BELT / SLIPSTREAM / MARKSMAN / REAPER) give the luck bar a payoff. Sprint 3, needs 4 cards.
- U8, U14, U15: bugs table.

### 4.5 Perks, scatter, powerups, wonder weapon
- **Jugg lottery, perk cap, Mule Kick, Deadshot** (PK-01/04/10, ECO-04): Top-12 #3.
- **Reshuffle mid-fight** (PK-02), **phantom stock cherry** (PK-03), **fixed points** (PK-11), **Stamin-Up sigh** (PK-14), **Zombie Blood ignoreme** (PK-15): bugs table.
- **PaP only at the crown** (PK-05) and **one box / dead Fire Sale + Carpenter** (PK-06): Top-12 #8.
- **Max Ammo scarcity** (PK-09): 1-in-10 with no wallbuys. Duplicate `"full_ammo"` in `level.zombie_powerup_array` after `zm_usermap::main()`; guaranteed Max Ammo on each breather door; last protector of a wave drops one.
- **PERK PAGER** (PK-07): the always-empty 9th pad becomes "Hold to PAGE a perk machine [3000]" — `move_machine()` already does the whole show. Superseded if Mule Kick fills the 9th pad (#3); keep as the agency option if the user prefers pure randomness.
- **Cherry does nothing for the slasher** (PK-08): proc on `tod_melee_kill` at frac 0.35 with the same 6 s cooldown.
- **LOCKDOWN powerup** (PK-12): replace the dead Carpenter with "seal the risers on laps N-1..N+1 for 45 s" via `spawn_locations[i].is_enabled`; blue aura on sealed risers via the existing glow clientfield. The first powerup whose value depends on where you grab it.
- **Scatter legibility** (PK-13/A13): perk glyphs beside the gauge's breather cells over the LuiNotifyEvent lane (`tod_pads`, 8 ints + opened bitmask), dimmed until that breather is bought.
- **Player-favouring reshuffle** (PK-16): the breather nearest above the highest player always receives a perk nobody owns.

### 4.6 Bosses & enemy variety
- **Spawn geography** (B1/B2/ER-04/A6): Top-12 #4.
- **Protector economy, debt, Panzer HP, damage lanes, rewards** (B3-B8, B14-B16): Top-12 #9 + bugs table.
- **CLOSING banner** (B9): per-boss `arrived` flag when `floor_of(boss) ≥ floor_of(lowest player) − 2`; optional once #4 shrinks the gap to ~30 s.
- **Panzer worth fighting** (B10): kill grants every living player a free station-style pick (`tod_upgrades::offer_free_pick`, cost 0, 15 s, no pause); breather-arena lock (favoriteenemy to players in the balcony, suppress retarget 20 s).
- **Enemy unlocks 20/30/40** (B11/B12/B13, ECO-07), all slots empty today:
  - **Floor 20 — Hellhound packs**: `_zm_ai_dogs` is compiled into zm_usermap; `special_dog_spawn(n, spawners, point)` spawns without a dog round (dog ROUNDS would break endless rounds — keep `dog_rounds_allowed = 0`). Generator emits one `zombie_dog_spawner`; `2 × players` dogs per round after unlock, teleported to a vetted point one lap below the lowest player. Zero new assets.
  - **Floor 30 — Glitch Stalker**: port map 1's `_acc_boss_glitch.gsc` (promoted riser zombie, blink via `GetClosestPointOnNavMesh` + `ForceTeleport`, post-blink 2× damage window, `ignore_enemy_count`). 1 per round (2 quad), HP 3× round zombie, +500. Zero assets, no bake, no base climb.
  - **Floor 40 — Brutus the JAMMER** (NSZ pack from map 1) or map 1's Phantom as the zero-asset fallback: locks the nearest perk machine / terminal to the highest player while he lives (`TriggerEnable(false)` + derez FX), one per 4 rounds, 1500 + the jammed machine's next buy free. Alternative from ECO-07: armored SENTINEL zombies (head-only damage, 3× HP, eye glow) and TWIN PANZERS at 40.
  - Each unlock fires a banner so the player learns what the door bought.

### 4.7 Presentation, audio, HUD
- **Music** (A3/A2/CR-07/ER-11): Top-12 #10.
- **Floaty text regressions** (A4 co-op CHOOSING hudelem, A5 dev prints): bugs table.
- **Boss on the gauge** (A6): `tod_floor` event extended with `boss_kind` + `near`; per-kind pip images; proximity pulses.
- **District colour, breather arrival, door feedback, door strings, fog, briefing** (A7-A12, A14): Top-12 #12.
- **HUD collisions** (A15): boss banner (y 56-140) sits on the compass frame; gauge foot overlaps the loadout frame by 54 px; banner-on-banner on boss rounds. Move BossBannerImg to y 136-220, upgrade banner to 232-325 (cards +20), or GA_H 416 → 352. Check the PNG alpha first.
- **Finale audio** (A11/CR-14): Top-12 #11.
- **Stale docs** (A17): bugs table.
- A16 split-screen controller detection: bugs table.

### 4.8 The crown & ending
- **Escalation, camera, seal, pad move, departure, exfil window, sounds, hold-to-buy, power warning, DisconnectPaths, pause holes, refusal debounce** (CR-01..05, CR-08..12, CR-14..17): Top-12 #11 + bugs table.
- **THE WARDEN** (CR-06) — the `level.tod_finale_boss_fn` slot: a Panzer at `gate_org()` with `boss_hp × 2.5` and `tod_warden_shield = 4`; `tod_mechz_damage_wrap` returns 0 while shielded; each pylon coil gets a 4 s hold "OVERLOAD THE PYLON" that ignites it, drops a shield layer and spawns `1 + broken` protectors at the gate; at shield 0 he takes full damage; 5,000 + luck on death. The pylons-as-progress-bar read survives and the hold-out becomes choreography (one overloads, three cover). L effort; Sprint 3. The user said "boss fight we wouldn't implement" for v9 — this is the design for when that changes.
- **End screen** (CR-13): LEFT BEHIND in red for downed players; TIME + KILLS line now; the docs/23 D5 image card via the int lane later.
- **Price** (CR-11): keep 25k; make the cost TIME: charge stalls if anyone leaves `roof_zone` > 5 s ("UPLINK UNSTABLE - hold the Crown").

---

## 5. Asset shopping list for the user

All wavs 48 kHz / 16-bit PCM; loops stereo and clean-wrapping (STREAMED/LOOPING/BUS_MUSIC/snp_never_duck like the existing rows); one-shots LOADED, 2D stereo for UI/music stings, mono for 3D world sounds; per `sound_assets/tod/music/README.md`. All images PNG in the existing baked-art families. Credit every external source before publish.

### Music (enables Top-12 #10, #11)
| File | Type | Length | Mood |
|---|---|---|---|
| `tod_music_band1.wav` | loop | 150-210 s | street-level synthwave, 90-100 BPM, smog/neon, low |
| `tod_music_band2.wav` | loop | 150-210 s | same key family, arpeggio added, 100-110 BPM |
| `tod_music_band3.wav` | loop | 150-210 s | brighter pads, drums forward, 110 BPM |
| `tod_music_band4.wav` | loop | 150-210 s | thin-air / high-altitude, wide reverb, tension pulse, 115 BPM |
| `tod_music_band5.wav` | loop | 150-210 s | edge-of-space choir-synth, 120 BPM, heroic (floors 41-50 + Crown) |
| `tod_music_finale.wav` | loop | 120-180 s | countdown drive for the 90 s hold-out + extraction |
| `tod_band_rise.wav` | one-shot 2D | 2.5 s | whoosh/riser that masks the band swap |
| `tod_boss_horn.wav` | one-shot 2D | 3-4 s | distant mechanical horn — "a Panzer has spawned" |
| `tod_end_escaped.wav` | one-shot 2D | 8-12 s | triumphant synth resolve |
| `tod_end_fallen.wav` | one-shot 2D | 8-12 s | dark fading drone |
| (existing) `tod_boss_music.wav` | loop | 206 s | keep, now gated on proximity |
| optional lull pad | one-shot/loop | 10-20 s | low pad for the earned-lull window (#6) |

### World / UI sounds
| File | Type | Length | Enables |
|---|---|---|---|
| `tod_boss_pulse_far.wav` / `_mid` / `_near` | one-shot 2D | ≤1.5 s each | metallic stomp or klaxon, rising intensity — A6 proximity pulse |
| `tod_breather_arrive.wav` | one-shot 2D | 3-5 s | warm major-chord "safe room" chime — A8 |
| `tod_uplink_buy.wav` | one-shot 3D mono | 4 s | terminal boot — CR-14 |
| `tod_pylon_ignite_1..4.wav` | one-shot 3D mono | 1.5 s each | same electrical hit pitched up a fourth per pylon — CR-14 |
| `tod_uplink_online.wav` | one-shot 3D mono | 3 s | power surge + chord — CR-14 |
| `tod_extract_depart.wav` | one-shot 3D mono | 6 s | engine spool + lift-off — CR-14/17 |
| `tod_victory_sting.wav` | one-shot 2D | ~8 s | can be the same file as `tod_end_escaped` |
| `tod_door_derez.wav` (optional) | one-shot 3D mono | 1.5 s | glitchy digital dissolve — A9 |

### Images — required by bugs / Top-12
| Asset | Size | Enables |
|---|---|---|
| `i_tod_card_thunder_regular/super/ultimate` | 768×1152 portrait each, existing 54-card style | U1 (CONFIRMED bug) |
| `i_tod_pause_r20` "THOR'S THUNDER" | 300×44 | U1 |
| Banner "PANZER DOWN" (+ optional "WAVE CLEARED") | 540×84, PANZER/PROTECTORS family | B8 |
| Banner "POWER RESTORED" | 540×84 | ECO-13 |
| `i_tod_hint_waiting` "WAITING FOR SQUAD" | 460×70 | A4 (floaty-text removal) |
| `i_tod_briefing` — 3 icon rows: THE ROUNDS NEVER STOP / CLIMB 50 FLOORS - REST EVERY 10 / REACH THE CROWN - UPLINK - EXTRACT (+ "class is permanent" line if the class banner lacks it) | 900×140 | A14 |
| `i_tod_gauge_pip_panzer`, `i_tod_gauge_pip_protector` | 16×16 | A6 |
| Map card `zone/previewimage.png` | 600×340 | docs/23 D1 — still the 3,825-byte placeholder |
| Workshop thumbnail `zone/workshopimage.png` | 512×512 square (currently byte-identical to the 600×340 card) | docs/23 D2 |
| Class card regen for SKIRMISHER (MP5) and HEAVY (Stoner 63) | existing class-card size | CHANGELOG v8 note — cards still show the retired AK-74u / M60 |

### Images — for Sprint 2/3 designs
| Asset | Size | Enables |
|---|---|---|
| Banners "PANZER — CLOSING", "PROTECTORS — CLOSING" | 540×84 | B9 |
| Banners HELLHOUNDS / GLITCH STALKER (or SENTINELS) / JAMMER (or TWIN PANZER) | 540×84 | enemy unlocks 20/30/40 |
| Banners BLACKOUT / OVERCLOCK / HEAVIES / FLOOD | 540×84 | ER-10 round types |
| Floor numeral strip matching the gauge art | per gauge style | ER-12 |
| 8-glyph perk icon strip (~24 px each) or approval to reuse stock specialty shaders | — | PK-13 / A13 |
| MOMENTUM + EXECUTION cards (3 rarities each) + 2 pause plates | 768×1152 / 300×44 | U4 |
| 4 ULTIMATE-only class cards + 4 pause plates | 768×1152 / 300×44 | U17 |
| Input-hint plate "D-PAD UP: REROLL −30 % LUCK" (controller + KBM) | 280×43 | U5 |
| LUCK card text regen (3) if the floor-reset wording changes | 768×1152 | U6 |
| Run-summary frame | ~900×600 (or 1920×1080 with empty centre) | U13 / CR-13 / docs/23 D5 |
| Optional: 10 neon numeral materials 0-9 | 256×256 | L5 floor plates |
| Optional: `i_tod_gauge_rung` in 5 band colours or one neutral white rung | — | A7 |
| Optional: WAGER timer frame | — | ECO-10 |
| Optional: LOCKDOWN tray icon (blue padlock over a stair glyph) | 64×64 | PK-12 |
| Optional: loading movie `zone/video/zm_tower_of_doom_load.mkv` | — | docs/23 D7 |

### Models / packs
| Asset | Enables |
|---|---|
| NSZ Brutus pack (`scripts/_NSZ/nsz_brutus.gsc` + GDT/xmodel/xanim), installed into the Mod Tools root as on map 1 | B13 floor-40 JAMMER (fallback: map 1's Phantom needs nothing) |
| Optional lift-pad decal/model | L4/ECO-08 (a `_tinted_edge` brush works) |
| Nothing else — Hellhounds, Glitch Stalker, second box, second PaP, intermission camera are all stock or already vendored |

---

## 6. Suggested order of work

### Sprint 1 — ship gate + confirmed bugs + the cheap rhythm wins (all S, ~no assets except thunder art)
1. ECO-01 / A5 / CR-18: flags off, build guard, dev prints stubbed, mortal solo + duo run, finale pass with god off. Record the real round-per-floor numbers.
2. L1 + ER-05: `check_valid_spawn_override` respawn near team; own the respawn cadence.
3. U1 + U2 + U3: thunder card art/plate/loop bound + re-entry latch + MOD_MELEE on cleave/thunder.
4. PK-03 + PK-02 + PK-11 + PK-14 + PK-15: map-owned bottle picker, death-driven reshuffle, derangement, real Stamin-Up perk, ignoreme refcount.
5. B3 + B6 + B7 + B14 + B4 numbers + B5 numbers + ER-08 cap: unlock-round wave, all-lane halving, strict spawn points, protector per-hit points / HP / debt cap / 6 alive, Panzer 16k × 1.05 / head 1.2.
6. PK-01 + PK-04 + ECO-04 + PK-10: tiered scatter, perk slots per breather, Mule Kick in the pool, Deadshot 1,500.
7. ER-01 + ER-03 + ER-11 + ER-07: carry-over cap, lulls on Panzer death / breather doors, co-op round-1 delay, no `round_end` state, rate jitter + cap.
8. ER-02 + L10: `zm_custom_spawn_location_selection` from below; zone volume `+72`.
9. A4 + A2/CR-07 + CR-03 + CR-08 + CR-15 + ECO-05 + ECO-14 + U8 + U14 + U12: floaty-text removal, `end_game` channel stop, finale pause holes, DisconnectPaths, refusal debounce, door buy guards, deferred events while downed, jump refcount, draft timeout honours focus.
10. ECO-03 + A10 + ECO-11/A9: door card destination, milestone door strings, slide + sound + derez on buy.
11. Stale comments (L14, A17) and CLAUDE.md's 25-floor / 15k numbers.

### Sprint 2 — the climb gets a shape (generator + M items; first asset drop)
1. L3/ECO-02/ECO-12: saw-tooth cost + party-size scaling + `FLOOR_KIND` (dark floor, pocket, split flight); re-bake; re-run the mortal numbers.
2. B1 + B2 + A6 + B8 + B9 + B15: altitude-anchored Panzer, sky-drop protectors, gauge boss kinds + proximity pulses, PANZER DOWN, CLOSING banners, gated rumble.
3. L2 generator riser move + L13 terrace risers + L7 pad-to-dais + pilaster + hall risers + CR-05 intermission point + L11 arena 600.
4. A7/L5 district palette + A8 breather arrival + A12 fog retune + ECO-13 power surge + A14 briefing + ER-06 floor-band difficulty.
5. A3 music bands + boss gate + finale track (asset-dependent; wire the aliases with the existing wavs as placeholders so the code lands first).
6. CR-01 escalation + CR-12 gate seal + CR-09 hold + CR-04 exfil window + CR-17 departure + CR-11 zone stall + CR-14/A11 stock sound swaps + CR-13 end-screen line + CR-16 crown door power warning.
7. L4/ECO-08 lift pads + PK-06 boxes on 20/40/crown + PK-05 PaP on floor 20 + first-Panzer PaP drop + PK-09 ammo weighting.
8. B11 Hellhounds at floor 20 (zero assets) and B12 Glitch Stalker at floor 30 (module port).
9. U7 luck wave budget + U10 DR vs bosses + U6 LUCK floor + U16 station cap + U11 slasher pistol + PK-08 slasher cherry + U9 late joiners.
10. D1/D2 map card + workshop thumbnail + class card regen (user art).

### Sprint 3 — agency, variety, the boss ending
1. U5 reroll + third card (bit-neutral rename) + no-repeat; U4 ECHO cap + MOMENTUM + EXECUTION; U13 card pips + run-summary card; U17 class ultimates.
2. ER-10 round types; PK-12 LOCKDOWN; PK-13/A13 perk glyphs on the gauge; PK-16 player-favouring reshuffle (or PK-07 Pager if the user wants pure randomness).
3. L6 expiring breather grace; L8/ECO-06 power zone + trap + window; L12 corner windows (bake-gated); L9 pockets if not done in Sprint 2.
4. ECO-09 toll meter / Express Ascent; ECO-10 WAGER; B10 Panzer free pick + breather arena.
5. B13 floor-40 JAMMER (Brutus pack or Phantom).
6. CR-06 THE WARDEN in the `tod_finale_boss_fn` slot.
7. ER-12 floor numerals; A15 HUD rectangles; A16 split-screen; docs/23 D7 loading movie.

---

## 7. Previous review (docs/23) status

| Item | Status | Evidence |
|---|---|---|
| A1 Solo has no safety net for ~9,900 pts | **Delivered** (v6.9) | QR pinned to the base N-wall pad; `_tod_perk_scatter.gsc:99` |
| A2 Powerups have no vertical handling | **Still open** | No snap/clamp anywhere in `_tod_powerups.gsc` / `_tod_bosses.gsc` drop sites; no changelog entry. Not re-raised by this review's reviewers, but still true — add to Sprint 2 alongside PK-09 (drop the Panzer Max Ammo at the killer, B8, covers the worst case) |
| A3 The breathers are not breathers | **Delivered** (v6.9) | Breather laps emit zero risers (`gen_tower_map.js:720`). This review now flags the opposite problem (L6 camp) |
| B1 Station on every breather | **Delivered** (v8, refined v8.2) | `_tod_upgrades.gsc:1369-1371`, west wall facing east |
| B2 A descent in the core | **Still open** | No lift/teleport/descent entry since; re-raised as L4 / ECO-08 (Top-12 #8) |
| C1/D3 Floor readout / tower gauge | **Delivered** (v6.x gauge art, v8 cells) | `_tod_gauge.gsc`; 1 cell = 2 floors, focus marker removed (user). Numeric floor still absent (ER-12) |
| C2/D4 Boss climb visibility / proximity plate | **Partial** | Red gauge pip shipped; no proximity plate or arrival cue (B9, A6). Root cause (base spawn) now addressed by B1/B2 instead |
| C3 Altitude music layers | **Still open** | One loop + boss track; plan in A3 (Top-12 #10), wav list in §5 |
| C4/D5 Run summary on death | **Still open** | Custom end screen exists for the escape only (`_tod_finale.gsc:471`); no summary (U13, CR-13) |
| D1 Map card placeholder | **Still open** | `zone/previewimage.png` is 3,825 bytes |
| D2 Workshop thumbnail wrong shape + duplicate | **Still open** | `zone/workshopimage.png` is still 3,825 bytes, byte-identical, 600×340 |
| D6 Stale cards / cherry icon / pause panel set | **Mostly delivered** | Pause panel baked art (v6.9), cherry icon (v6.9), DR/BOUNTY/KNIFE SPEED regen prompt delivered (v6.8). Open: class cards still show AK-74u / M60 (v8 note); cherry icon cannot light because `specialty_combat_efficiency` has no uimodel (known limit, PK-03 note) |
| D7 Loading movie | **Still open** | Low priority, unchanged |