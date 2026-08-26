# Tower of Doom: Cybercity — session brief

Custom BO3 zombies map `zm_tower_of_doom` — a **classic tower map with a twist**,
set in the same cyber-city universe as the user's first map
(`c:\Users\jorda\Repositories\abandoned_cyber_city_zombies`). **That repo is the
knowledge base for this one** — read `docs/BO3_MAPMAKING_KB.md` (copied here into
`docs/`, canonical copy lives in both repos) FIRST, and consult the old repo's
`CLAUDE.md`, `docs/14_stock_api_verification.md` (stock-API traps ledger) and
`docs/16_community_techniques.md` before touching stock interfaces. Do NOT
re-learn lessons that map already paid for.

## What this map is (user, 2026-08-17)

- **SPIRAL TOWER, 50 FLOORS — v8** (user 2026-08-20: "4 stairs per floor is
  way too much"): a solid core with an open-air staircase spiralling around
  its OUTSIDE — base arena at the bottom, 50 floors of **2 flights each**
  (`LAP_RISE 384`, top z=19200), rooftop arena (PaP + Mule Kick) on the core's
  top. PARITY spiral: odd floors climb the E+N sides (NE mid landing, NW end
  landing), even floors the W+S (mirrored); doors/zones/lights/probes all
  parity-mirrored in the generator. 52 zones; buyable doors one per lap + roof
  + power (v10.4: 750 +60/lap cap 3000, roof 7500, power 750 — the price
  rides in the GENERATED `_tod_door_data.gsc`, so a price change is a
  -GscOnly build). **NO wallbuys** (user: "I never asked for those").
  **PERKS = the 8-machine random scatter** (`_tod_perk_scatter.gsc`): all 8
  base machines (Jugg/Speed/QR/Stamin-Up/Widow's/Cherry/DoubleTap/Deadshot)
  park at the base N wall in the .map, scatter to random pads at load and
  reshuffle every 4 rounds (v10.3; was the round after each Panzer), never
  onto the same floor; pads = **the 8 breather pads ONLY**
  (2 per balcony × floors 10/20/30/40) **plus ONE base pad where QUICK REVIVE
  is pinned** (v6.9 solo carve-out: the first-breather pin costs 15,750 pts of doors to
  reach (lap 10 under the v9.43 prices), leaving solo with no self-revive for ~10k pts. Granting the perk early
  is NOT an alternative — the stock vending trigger refuses a buy while the
  player holds the perk, `_zm_perks.gsc:545`). 9 pads / 8 machines = one
  breather pad empty each run.
  Breathers (floors 10/20/30/40) are LARGER (544×576 since v9.37), parity-mirrored, and
  emit **ZERO risers** (v6.9) so they are real rest stops — the horde must
  climb to you.
  **Tron Grid look**: edge-lit `_tinted_edge` floors cycling 5 colors, navy
  base + glowing inlay ring, PaP-material roof floor; Miami night skybox
  (`skybox_t9_mp_miami` + `acc_ssi_miami_night`, Nastian pack — credit before
  publish), scripted city-smog fog (`_tod_atmosphere.gsc` — dense at street
  level, clear by mid-tower). Music (`_tod_atmosphere` owns the channel):
  **BANDS BY FLOOR** (v9.46) — the track changes as the party climbs past the
  breathers: 1-9 "Password Infinity" (Evgeny Bardyuzha), 10-22 "Cyberpunk
  Futuristic City" (lnplusmusic), 23-36 "Cyber Relay" (Psychronic), 37-50
  "Cyber Eclipse" (bykenneth) — the three climb tracks are spread EVENLY over
  floors 10-50, so only the floor-10 change lines up with a breather. The PANZER's
  track ("Data Spike" — Psychronic) always overrides, and resumes into whatever
  band the party has climbed into; the FINALE track ("You See Big Girl" —
  Hiroyuki Sawano / Gemie) outranks everything and IS the run's clock. One
  `add_music_band()` row per band in `register_music_bands()` — the bands are 10/23/37
  (was 20/30/40, then 10/30/40, evened out 2026-08-25). Rows must stay in
  ASCENDING floor order — band_alias() walks the array backwards. Credit all SIX
  before publish (full list: CREDITS.md). TELEPORTERS (v9.37/v10.3-4): four
  breather pads (0.8s charge, 30s cd) down to a base arrival pad + four base
  UP pads gated on each breather's own lap door — five porters at spawn; band table, wav rules
  and the loudness-matching recipe in sound_assets/tod/music/README.md.
  Bosses: Panzer every 5th round (music + luck-to-last-hit), Rogue Protector
  WAVE every 3rd round, wave size = int(players×round/3+0.5) CAPPED at the
  concurrency roof 8, debt SET not summed (v10.4; quiet
  per-unit rewards). **Power switch at the BOTTOM.** The generator prints the live
  world-brush / entity / lap counts on every run — read them there rather than
  trusting a number copied into this brief. LED bake is the ceiling; generator
  `PARA_EVERY` is the bake-budget knob.
- **4 CLASSES × 3 TIERS** (`_tod_classes.gsc` `register_gun`; docs/25 —
  CLASS TIERS, 2026-08-22): SKIRMISHER **MAC-10 → MP5 → MP7** (speed 1.0),
  ASSAULT **Enfield → Krig 6 → AK-47** (0.9), HEAVY **Stoner 63 → HK21 →
  Death Machine** (0.75), SLASHER **Combat Knife → Wakizashi → STORMBREAKER
  (Leviathan port)** (1.1). Once the class gun is PaP'd, 20% (v9.42; was 10%) of card deals
  (dev 100%) carry a TIER card (right slot, never auto-locked): new gun at
  its level-0 form, every GUN-scoped domain reset, DMG REDUCTION + LUCK
  kept. Guns are GENERATED by `tools/gen_tod_twins.js` (ladder table, TIER_DPS
  normalization, never-shrink clips, altWeapon blanked on every form —
  audit it per build) under a 200-registration guard (map 1's ~230 ceiling).
  Every gun: LOC_NORM 3.0, move 1.0, recoil ×1.15, ADS ×1.20, PaP = +25%.
  **HEADSHOTS ARE 3× FOR EVERY CLASS** — LOC_NORM is the whole story and script
  supplies no per-class ratio. An ASSAULT-only 4× shipped for exactly one build
  (v10.14) and the user reverted it after playing it (v10.16); the recipe for
  bringing it back is in the comment where `class_hs_scale()` used to live in
  `_tod_upgrades.gsc`. Differentiation comes ONLY from the HEADSHOT domain.
  Per-class weapon knobs live in the generator: `CLASS_DAMAGE_MULT`
  (skirmisher 1.15, heavy 0.90) and `CLASS_RESERVE_MULT` apply to the **T1 gun
  only** — the higher tiers are normalized FROM the tuned T1, so a class knob
  propagates by construction and scaling them too double-applies it.
  Only the PISTOL (MR6) keeps a script damage multiplier (×9.6 base,
  ×5.76 PaP — the PaP form took a 40% nerf 2026-08-23).
  Move speed is keyed on the CLASS (`class_speed_base()`), not the gun, so it
  survives any roster swap. Sound aliases for all class guns are GENERATED by
  `tools/gen_tod_sounds.js` — it reads each GDT for the alias names it
  actually references (guessing from wav names is wrong in both directions)
  and skips fire families a gun lacks (the Stoner has no trig_pull). Game-start CLASS DRAFT (`_tod_class_select.gsc`
  LUI, 30s, random on timeout) + hold-USE stations at the base (moved WEST of
  the door trigger — overlap bug); switching swaps the primary, per-player
  upgrade levels persist.
- **THE TWIST — endless rounds:** there is NO pause between rounds. The moment
  the last zombie of a round SPAWNS, the next round starts — it should feel like
  the round never ended. Implemented in
  `scripts/zm/zm_tower_of_doom/_tod_endless_rounds.gsc` via the stock overridable
  pointers `level.round_wait_func` (wait for zombie_total==0, i.e. all SPAWNED,
  not all dead) + `level.zombie_round_change_custom` (no fanfare stall) +
  `level.func_get_delay_between_rounds` (returns 0).
- **Zombie speed curve** (`_tod_zombie_speed.gsc`): SPRINT animation from
  round 1 at reduced rate (floor 0.8 after live test — 0.5 read as broken),
  linear to full sprint at round 15 (7 -> 10 -> 12 -> 15 across three user
  retunes; 15 is the end of this lever, see the block comment on
  TOD_ZSPEED_FULL_ROUND), then +0.28%/round unbounded (0.35 -> 0.28 nerf,
  2026-08-26). 1.5s keep-alive sweep re-asserts
  gait+rate (one-shot overrides decay — map 1 lesson). Spawn trickle 0.8×
  stock, floor 0.3s.
- **Perk power-on glow** (`_tod_perk_lights.gsc|.csc`, ported from map 1):
  server sets the `todPerkGlow` clientfield when "power_on" flags; client
  PlayFXOnTag's the colored aura (server-side PlayFX does NOT render). FX =
  map 1's self-authored recolors, sources in repo `share/raw/fx/acc/light/`.
- **UPGRADE TOWER** (`_tod_upgrades.gsc`): events at rounds 1 (post-draft),
  4, 8, 12… (dev: every round) — the world pauses, each player picks 1 of 2
  rolled options (33 live domains + the TIER card × rarity REGULAR/SUPER/ULTIMATE = +1/+2/+3
  Lv; ids run to 37 with 11/22/30 retired — `domain_id()` and the Lua tables are
  KEY-KEYED, so a removed domain's id STAYS mapped and only its `add_domain`
  call goes).
  **CARD ART CARRIES THE NUMBERS BAKED IN, so a domain retune is not finished
  until the card is re-baked** — the card is the only place a player ever reads
  the value. Audit + prompts: `docs/33_upgrade_art_audit.md`. When auditing,
  OPEN THE PNG; the art-prompt docs go stale (docs/26 still specifies a KILL
  RELOAD card that was re-baked out from under it).
  Odds ride the **LUCK BAR** (`_tod_luck.gsc`, 0–100% per player: kills
  normalized 40×players÷round_total, headshots ×1.5, revive +15, door +8,
  down −25, boss LAST HIT takes all; FULL RESET to 0 after each event; LUCK
  domain = +10% gain rate/Lv). **NO-TWIN RULE: upgrades are NEVER weapon
  variants** (engine ~230-twin boot-AV ceiling, map 1 docs/21 §A) —
  damage/firerate(echo-proc)/magsize(virtual pool) are all script-side.
  UI = real LUI (`tod_upgrade.lua` + `_tod_upgrade_ui.gsc|.csc`, 18
  clientuimodel fields = **61 bits, the PROVEN ceiling — APPEND ONLY**);
  luck bar = LuckSegs segments in the frame art (todUpgLuck, live via
  `tod_upgrade_ui::set_luck_pct`); owned-upgrades list shows ONLY in the
  pause menu (int-only `LuiNotifyEvent(&"tod_upg_sync")` → `CoD.TodOwned` →
  AetheriumStartMenu.lua panel — `SetClientDvar` does NOT exist in T7).
  **PERSONAL UPGRADE STATION** (base, core south face, Chaos PaP mesh):
  solo upgrade buy at 2000 +250/purchase PER PLAYER, 5 uses per station;
  world does NOT pause
  (the risk), 15s timer; a scheduled round OVERRIDES a manual pick and the
  same cards re-present after (re-clamped — stale cards never lower levels).
- **HUD: Aetherium kit** (vendored, `zone_source/aetherium_hud.zpkg`) + our
  LUI menus. No Mega Bottles, no Data Shards — old map's systems, NOT ported.
- **THE CROWN + THE ENDING (v9, user 2026-08-21).** Above the spiral:
  CROWN STAIR (gold) → TERRACE → CAUSEWAY ("the pathway") → CROWN HALL, a
  1536-sq open-top citadel floating beside the tower, + a MAST on the core top.
  **v11 (2026-08-25) — THE CITADEL IS A LITERAL CROWN.** The user's verdict on
  the old one was "it just looks like a castle with spikes"; measured, it was a
  4°-wide blue box plus six spires under the 0.5°/384-unit legibility floor,
  standing on a `dark_blue_tinted` underside that rendered as a black square
  against the fog. It is now THE CIRCLET (`gen_tower_map.js` §5f): a
  **6128 wide x 13,888 tall gold crown** (v11.1, user: "I want the scale to be
  even more... players should be in awe") — ONE KNOB, `CR_SCALE` (1.4), scales
  the whole thing uniformly; the SOUTH FACE is PINNED at y=6912 because the
  mouth has to stay inside the causeway F approach, so the crown grows NORTH
  around the hall and `CR_CY` is derived. Flared 9° band, white
  ermine rim, 16 alternating points (8 crosses pattée / 8 fleurs-de-lis, every
  head WIDER than its shaft), a FRONT CROSS with a great ruby, two dipped
  arches → monde → cross finial → red beacon, 16 jewels, pendilia, and —
  v12 (user 2026-08-26: "they look up and see this MASSIVE building") — THE
  VORTEX BELL underside: 10 tiers on an ogee whose ring-widths accelerate
  toward the centre, corona teeth serrating the gold tiers, jewel collars on
  two brass tiers, ermine tail-spots under the south rim, pearl beading on the
  arches, and THE GIRANDOLE — a stepped ruby drop-pendant (with the crown's
  third red light) hanging below the bell, completing the red vertical axis
  (beacon above, great ruby front, girandole below). The causeway runs
  **through a 640×424 mouth cut in the rim**. THE HALL DOES NOT MOVE — floor,
  walls, gate, dais, sconces, exfil pad and every `_tod_crown_data.gsc` anchor
  are byte-identical; only `pylon_orgs()` moved. Full record + the 15-point
  "castle vs crown" checklist: `docs/34_crown_redesign.md`. Iterate with
  `tools/preview_crown.js` (6 renders, ~1s, no bake) — **if the `_under` view is
  dark, nothing else you did counts.** The 4 hall pillars are BACK as pure
  architecture (v12 — the v11 deletion was aimed at the coil MODELS; user:
  "I think the last agent thought I wanted the entire pillars removed"): gold
  base, ruby shaft, gold cap at the original ±448 spots, scenery + cover only.
  The finale's quarter-progress read STAYS on the crown's corner points
  (`pylon_orgs()` untouched). The hall also has its own AMMO CRATE (v12, east
  wall, mirror of the upgrade station) — coords ride in generated
  `_tod_crown_data.gsc::crown_crate_org()`, clip emitted by the generator.
  **Generated as lap LAPS+1 in the spiral's own parity math** — every
  crown coordinate is authored in the odd frame and mirrored by `CM`
  (`cbox/cpt/cyaw/cvolume/cspec`); the old odd-only "final landing" special
  case silently vanished when LAPS went even and left the roof unreachable.
  Never special-case the top by parity again. **THE LAST MILE (v10)** — the
  CAUSEWAY IS the finale arena; `SKY_IN` and `HS` are derived from `CW_LEN`,
  never literals. **v12 (user 2026-08-26: "the paths ... are pretty simple and
  straight forward. Lets be more creative ... scary and anxious") — 7360 long,
  160 wide, SAME span budget as v10.12 (so every crown/road assert held), but
  every lane is now a DIFFERENT KIND of fear**: gate-run (flanked by the first
  AVENUE PYLONS — jewelled gold obelisks floating in the void, the road's
  scale-rhythm markers) → fork (west THE RIDGE climbs +256 and ZIGZAGS along
  the crest — the awe lane, best crown view on the road; east THE BROKEN STAIR
  steps down through blind pockets into a 640-long hollow at −256, then one
  16-tread blind climb) → merge → **THE NARROWS** (the old spine, PINCHED to
  120 wide for its middle 320 under portal 2 — the road's one guaranteed
  single-file choke) → **three-way** fork (west THE UNDERCROFT plunges −384
  to an ambush cistern then 960 units of blind ascent; centre THE PLANK, 120
  wide, raised to +256, the riser-densest straight line; east THE WEAVE, flat
  but serpentining through 4 jogs — 9 pieces, 9 risers, the most infested
  ground) → merge → approach → a FLARE into the citadel gate. Boss
  altitude-sorting (panzer→highest player, protectors→lowest) makes the plank
  draw the Panzer and the undercroft draw the swarm — emergent, by design.
  Shortest walk ~8220 units (the generator prints the live number) against the
  90 s road phase — comfortable even for HEAVY (speed 0.75), so the risk at
  the ending is being PINNED, not being slow.
  The citadel mouth FLARES to `CW_FLARE` because the gate opening is 256 and
  the road is 160: the difference was unguarded hall floor over a 19,000-unit
  drop. The mouth PORTAL must be as wide as the flare or the rail pass plants
  bollards on the citadel floor — `roadEmit` throws on that now.
  **THE ROAD IS DECLARED, NOT DRAWN.** `roadFlat`/`roadStair`/`roadPortal`
  declare flat grid-aligned deck cells; `roadEmit()` rasterises them on a
  20-unit grid and DERIVES every rail. `ROAD_G === PARA === 20` is load-bearing:
  it makes a rail occupy exactly the one unoccupied column outside the edge it
  guards, so a rail can never land on deck. roadEmit also throws on overlapping
  cells, on any adjacency over `ROAD_STEP_MAX` (18), and if the citadel mouth is
  not reachable from the terrace mouth. Hand-cut rails (the v10.11 `face()`
  walking mouth x-centres) do NOT survive a road that turns — that is what this
  replaced.
  First and last runs are **on-axis at TOP2** — load-bearing, they meet the
  terrace mouth and the hall's gate opening. Every branch returns to TOP2 before
  a merge, so junctions are always flat. A `tod_causeway_gate` script_brushmodel
  **seals the mouth until EXTRACTION is bought** (same
  `Solid+DisconnectPaths` → `Hide+NotSolid+ConnectPaths` contract as every
  door); while it is shut `_tod_endless_rounds::finale_spawn_selection` drops
  every riser past it, or zombies strand on an unreachable bridge holding actor
  slots. Risers/lights/portals come from `causewayRunPoints()` etc. — placed
  **by shape, never by fraction of length**, since most of the road is no longer
  at x=0 or at TOP2. A CROWN RESPAWN GROUP sits on the terrace (gated on
  `roof_zone`, like the breather groups are gated on their lap zones) — without
  it a co-op death during the 191 s finale sent that player to the base arena,
  which is removal from the run, not a setback. It is on the TERRACE and not in
  the citadel deliberately: you come back at the START of the road.
  **THE BAKE IS A PASS/FAIL GATE, NOT A BUDGET METER** (corrected 2026-08-25):
  on near-identical input this map has baked at 38.2, 126.2, 35.1, 31.9, 31.3 and
  31.8 s. The 126.2 was taken ONCE, was used to justify a design limit, and NEVER
  REPRODUCED — an A/B with byte-identical geometry (only materials differing)
  ruled that suspect out too. Bake time here is dominated by HOST STATE, not map
  content. Never conclude anything from a single bake; run
  `node tools/measure_lit_area.js` for the budget question (deterministic,
  instant, groups area by map region) and read _bake_test only as BAKED/CRASHED,
  and the same map varies by 20 s run to run. Bake and read the number; never
  predict it, and never use it to justify not adding geometry.
  Finale = `_tod_finale.gsc`: buyable EXTRACTION
  **12k** (v10.11, was 25k — the price stopped being the gate once the gate
  became a literal wall) at the **terrace** (start of the road) → the closing
  song takes the channel and IS the clock → ~8220 walked units of
  ambushed road (v12; the generator prints the live number) → survive to the last chord → "YOU ESCAPED THE TOWER" via
  `custom_game_over_hud_elem`. `TOD_FINALE_SONG_SECS` + `DEPART_SECS` must
  equal the wav's length (191 + 6 = 197.4) or the LOOPING stream restarts under
  the ending. Ambush = spawn-delay floor + `_tod_bosses::finale_pressure_start`
  cycling all three boss types under a combined roof of 4 — **no stock AI limit
  is ever raised** (bosses are direct SpawnActor and bypass stock's gate).
  Anchors ride in from GENERATED `_tod_crown_data.gsc`. **Boss-fight slot:**
  `level.tod_finale_boss_fn` owns the hold-out if defined. Rails everywhere
  carry invisible clip caps (`RAIL_CAP_H`) — rail tops are not launch pads.

## Conventions

- Map name `zm_tower_of_doom`; script prefix **`tod`** (`_tod_*.gsc` modules,
  `tod_*::` namespaces, `level.tod_*` state) — mirrors the old map's `acc`.
- Entry scripts `scripts/zm/zm_tower_of_doom.gsc|.csc`; modules under
  `scripts/zm/zm_tower_of_doom/`; every module needs a `scriptparsetree` line in
  `zone_source/zm_tower_of_doom.zone`.
- **The `.map` is GENERATED** by `tools/gen_tower_map.js` from the layout tables
  at the top of that file. The generator ALSO emits
  `scripts/zm/zm_tower_of_doom/_tod_door_data.gsc` (door buy-trigger coords) so
  the .map and GSC can never drift. Regenerate BOTH with
  `node tools/gen_tower_map.js` after any layout change; hand-edits to the .map
  will be clobbered by a regen, so put changes in the generator.
- **DEV TEST HARNESS: REMOVED** (2026-08-25, verified 2026-08-26).
  `_tod_main::dev_crown_test` and the dev finale clock are GONE — the user had
  the throwaway harness reverted before publish (`_tod_main.gsc:63` records
  it). `level.tod_dev` still exists and still gates the money loop, early
  Panzer/boss intervals, 100% tier-card odds and unlimited station uses — but
  nothing warps to the terrace and the finale clock is the same 191 s in every
  build. If the ending needs testing again, write a fresh harness (recipe in
  the _tod_main comment: stock power entry
  `zm_power::turn_power_on_and_open_doors` + `zm_perks::perk_unpause_all_perks`
  — poking "power_on" by hand leaves perk machines paused — open every zone
  flag + the causeway gate, warp on spawn AND respawn), and remove it again
  before publish.
- Dev/test = ONE compile-time flag, `level.tod_dev` in
  `zm_tower_of_doom.gsc::tod_resolve_dev_flags()` (hardcode `= true;` +
  rebuild to arm a test session; ship state `= false;`). NEVER add dev dvars or
  tell the user to set console dvars — same doctrine as the old map (its
  CLAUDE.md "Dev/test mode" section).

## Build / run (same pipeline as the old map)

- `.\tools\build_map.ps1` — full headless build (sync → cod2map64 [cwd=bin] →
  Radiant LED bake → linker → verify fresh `.ff`). `-GscOnly` for
  GSC/.zone-only changes. **Build it yourself; the user's job is to TEST.**
  Build success = a FRESH `.ff`, NOT the linker exit code.
- **LED bake is a gate** after any geometry change — `tools/_bake_test.ps1`
  prints BAKED/CRASHED (the brush.cpp:1860 lightmap-atlas ceiling; see KB §1).
  **READ IT AS BAKED/CRASHED AND NOTHING ELSE.** Its TIMING is not a budget
  meter: on near-identical input this map has come back 38.2, 126.2, 35.1, 31.9,
  31.3 and 31.8 s — a 4x spread, and the 126.2 was a one-off that never
  reproduced (an A/B with byte-identical geometry ruled out the material
  distribution as the cause). Timing here is dominated by HOST STATE. A single
  bake reading justifies NOTHING; if a number is going to decide something, bake
  twice and A/B it. For the actual budget question run
  `node tools/measure_lit_area.js` — deterministic, instant, and it groups lit
  area by region so you can see what changed (the crown is 84% of the map's).
- **Two ADVISORY crown tools** (not gates, but run them after any crown edit):
  `node tools/measure_lit_area.js` groups lit surface area by region — the
  crown is 84% of the map, so that is the number that should drive geometry
  decisions up there. `node tools/audit_hidden_faces.js` samples every face and
  reports what nothing can see; it found panel stiles, jewel bosses, a keystone,
  an arch segment and the mouth jambs all sealed inside other brushes. Two cases
  are always wrong: buried on ALL SIX faces (pure cost), and a visible face
  COPLANAR with a neighbour in another material (a z-fight). Everything else is
  advisory — a tenon keyed into a wall is supposed to be buried.
- **NOTHING MAY STAND ON THE CAUSEWAY.** The J4 landing is 960 wide (x +-480,
  y 6720-6880 at TOP2) and the crown face is 32 north of it, so anything pushed
  proud lands on walkable deck. NO LINT CATCHES THIS — the misplaced-wall check
  only fires on `clip` with no visible solid, a VISIBLE solid silently drops the
  node, and the flood still walks the middle of a 960-wide landing. gen_tower_map
  section 5f.9 asserts it against the emitted brushes; keep that assert.
- **`tools/lint_tod_geometry.js` is the other geometry gate** — HOLES and
  MISPLACED WALLS, run automatically by `build_map.ps1` before cod2map. Proves,
  whole-map in ~1 s: no invisible blocker where a player stands, no unguarded
  edge, and base→terrace + terrace→citadel still walkable. Gates on REGRESSION
  against `tools/lint_tod_geometry.baseline.json` (currently zero of
  everything). `tools/lint_tod_geometry_selftest.js` breaks the map six ways and
  requires the lint to catch each — run it whenever the lint is edited.
  **If it goes red on a map somebody has WALKED, suspect the lint** (that
  happened twice the day it was written and both times the check was wrong, not
  the map). Never edit the baseline to make it green. It cannot see
  script-spawned collision, prefabs, or the navmesh.
- **IS THE `.ff` ACTUALLY BUILT FROM THIS TREE?** Three different freshness
  checks have now been trusted and been WRONG, so use this one and only this one:
  ```
  diff -rq scripts     <modtools>/usermaps/zm_tower_of_doom/scripts
  diff -rq zone_source <modtools>/usermaps/zm_tower_of_doom/zone_source
  ```
  (ignore the generated `all/`, `english/`, `loc/` output dirs). Empty = the
  linker consumed exactly this source. **An mtime gate cannot answer this**:
  `build_map.ps1` SYNCS AT THE START, so a file edited mid-build is older than
  the `.ff` and newer than the sync — a peer edit 25 s before the `.ff` was
  written was not in it, and `find -newer` called the tree clean.
  And "synced" is not "packed": **a `.gdt` edit is ALWAYS a full build**, because
  `-GscOnly` copies the GDT but runs no `gdtdb /update` and rebuilds no weapon
  assets — so a `-GscOnly` after a GDT change is worse than nothing, it makes the
  tree look current. (Contrast door PRICES, which really are `-GscOnly`.)
- Launch: `PLAY_NORMAL.bat` or `.\tools\run_game.ps1` (steam://run/311210 +
  `+set_gametype zclassic` — the ONE load-bearing arg; never raw exe, never
  Steam Launch Options).
- Mod tools root: `...\Call of Duty Black Ops III 455130` (detected via
  `bin\modlauncher.exe`). Linker builds the DEPLOYED usermaps copy — sync
  before every build (build_map.ps1 does it).

## Hard-won facts inherited from map 1 (the short list — full set in the KB)

- Map-authored `zombie_door` trigger_use entities are DEAD for generated maps —
  `_tod_doors.gsc` disables them and spawns `trigger_radius_use` on BOTH sides
  of each doorway (script-spawned use-triggers need `TriggerIgnoreTeam()`).
  Buy = charge points, set the zone script_flag, hide+notsolid+connectpaths the
  slab. Slab starts `solid(); disconnectpaths();`.
- GSC dialect: `function` keyword, `#using` before `#namespace`, `#precache`
  only AFTER every `#using`/`#insert` (between them = "No generated data"
  compile kill, live 2026-08-20), ternary fully
  paren-wrapped, no `.field` on parenthesized expr, `class` reserved,
  `"power_on"`/`"initial_blackscreen_passed"` are FLAGS (`flag::wait_till`),
  never write `player.score` (use `zm_score::`), read-only damage callbacks
  MUST `return -1`.
- Navmesh ignores ALL entity collision → any script-spawned solid needs
  `DisconnectPaths()` (and `ConnectPaths()` when cleared).
- Playable space below z=-1000 triggers the stock below-world zombie failsafe —
  this tower goes UP, so not an issue here.
