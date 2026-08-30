# 44 — ENDLESS MODE research: THE ENDLESS SPIRE

**Status 2026-08-29 EOD: SHIPPED IN v14.0.** Fully implemented and wired
(generator SECTION 6 enabled, `_tod_spire.gsc` + finale choice surgery +
pacing/filters + zones + art + music), built (BUILD OK, LED bake PASSED with
the spire in — BSP 8.1→19.6MB — every lint green incl. the spire island
proofs, .sabl byte-equal, .sabs +tod_music_spire), BOOTED by the user
("good"), and published as the hotfix republish (the 4:13:08 PM artifact,
which also carries v13.25's namespace boot fix). REMAINING: the post-win
live-verify ladder (§ WIRING.md §10) has NOT had a real run — the spire's
runtime flow (choice→ascend→grant→climb→hubs→endings) ships boot-verified
but not play-verified; the dev-harness recipe for a fast verify run is in
`tools/spire_wip/HARNESS.md`. Name locked: THE ENDLESS SPIRE.**

## The ask (user, 2026-08-29, verbatim fragments)

- "The fans would like an endless mode … once you beat the game you will get
  all perks and all power ups for your class maxed out. And you can continue
  playing."
- "have a teleporter in the crown room that activates once you beat the map.
  Then players have an option to enter the endless mode. This brings them to a
  tower that goes up 100 floors. Doors will cost what ever the max door cost
  at the original tower. Once players teleport they cant go back. We would
  need to make a tower for this on the map somewhere."
- "at this tower we can add all the perks and a pap machine and ammo crate at
  every floor."
- "this is gonna be a lot of additions but not super complex to create" — the
  user's own scale read, and it matches: every mechanism below already exists
  in the map; the work is one new generator section + one new GSC module +
  surgery on the finale's ending.

**Interpretation note — "all power ups for your class maxed out":** read as
the UPGRADE DOMAINS (the card system) at their per-class caps, plus the class
gun at Tier 3 Pack-a-Punched. NOT the drop powerups (insta-kill etc. —
permanent drops would trivialize the mode). Flagged to the user; cheap to
re-read if wrong.

## The flow

1. **The win fires as today** (`_tod_finale::finale_run` survives the
   hold-out, state → `"ready"`, pad flips green) — but `depart()` is **no
   longer called automatically**. The hall goes quiet (wipe + spawn
   suppression, see §6) and the run enters a CHOICE state.
2. **Two glowing stations in the sealed hall:**
   - **EXTRACT** — the existing exfil pad, re-armed with a hold-USE trigger.
     Fires `depart()` → the current 6s flourish → "YOU ESCAPED THE TOWER".
     (Safe to re-add a use path now: the deleted `exfil_use_loop` was removed
     because it RACED the song-timer's automatic depart — see the tombstone at
     `_tod_finale.gsc:1544`. With no automatic depart there is exactly one
     path into `end_game` again.)
   - **ASCEND** — a NEW teleporter pad in the hall (Der Eisendrache assembly,
     the `_tod_teleport` recipe verbatim), dead all game, ignited at the win.
     Hold-USE → the whole party warps to the SPIRE. **One-way** — no return
     pad, and the crown behind them is torn down (§5).
3. **First committed hold wins for the whole party** (recommended; unanimity
   is a griefable stall in co-op — one AFK player blocks the reward). Everyone
   goes together, gathered exactly like `gather_to_centre()` does at the seal.
4. **The grant, on arrival** (§4): all 9 perks, every eligible upgrade domain
   at that player's cap, class gun at Tier 3 PaP'd.
5. **The climb**: 100 floors, doors at the original tower's price cap,
   ammo/perk/PaP access per §5. Rounds, zombie speed curve, bosses, hounds —
   all simply KEEP RUNNING (the endless-rounds engine never stopped).
   Upgrade events stay suppressed (`level.tod_upgrades_suppressed = true` —
   already the finale's own flag): every card is maxed, there is nothing to
   roll.
6. **The run ends when the party wipes** (custom death screen, §8) — or,
   recommended, at an optional SUMMIT EXTRACTION on floor 100 that ends the
   game as a win, so the mode still has a chosen ending for the party that
   conquers it.

## §1 Why the ending can host a choice (verified against current code)

- `finale_run` (`_tod_finale.gsc:606`) is linear: siege survives → state
  `"ready"` → `level thread depart()` → 6s → `end_game`. The choice replaces
  that last thread with a state; both stations call their action; `depart()`
  itself is untouched.
- The song is OVER at that point — the music channel is stopped/latched
  (`tod_finale_music` latch, `_tod_atmosphere.gsc:244`). The ascension path
  needs a **latch release** (new ~5-line public fn in `_tod_atmosphere`):
  clear `tod_finale_music`, reset the band latch (`level.tod_music_floor`),
  `channel_play(band_alias())`. §7 covers what plays after.
- During the choice window: `wipe_the_map()` has already run at the seal;
  keep the hall spawn filter starved (a `tod_choice_pending` check in
  `finale_spawn_selection`, same shape as its three existing filters at
  `_tod_endless_rounds.gsc:123-211`) so the decision is made in quiet. The
  round loop self-stalls at the actor cap; nothing needs pausing.
- `warn_clear_on_end` / gauge / hint loops all key off `tod_finale_state` —
  a new `"choice"` state slots into their switches (audit each `switch` on
  that field; the exfil hint loop at `:1562` and uplink hint loop at `:504`
  are the two live ones).

## §2 The reward grant (all mechanisms exist)

- **Perks**: `level.perk_purchase_limit = 9` already
  (`zm_tower_of_doom.gsc:207` — 8 scatter machines + roof Mule Kick). Grant =
  iterate the LIVE machine roster (the scatter's list, not a hardcoded array —
  the perk lineup changed twice this week: Death Perception in, Elemental Pop
  out) + Mule Kick, `zm_perks::give_perk(perk, 0)` each. The
  vending-trigger-refuses-while-held trap (`_zm_perks.gsc:545`) is about
  BUYING, not granting — irrelevant here.
- **Domains**: per-player `self.tod_levels[key]` array
  (`_tod_upgrades.gsc:929-941`), caps via `domain_max(player, d)` (`:885` —
  honours the per-class bonus level, e.g. assault RESERVE 6), eligibility via
  `domain_available(player, d)` (`:894`). Grant = for every eligible domain,
  set the level to the cap **through the same apply path the card picker
  uses** (`apply_upgrade`, `:2599`) or a re-clamped bulk setter + the
  side-effect appliers (`apply_move_speed` etc.). The tier-card path already
  proves a bulk reset/re-apply is possible (GUN-scoped domains reset on tier
  swap). Implementation detail to nail then: which domains apply lazily (read
  at damage time — free) vs eagerly (move speed, HP) — enumerate at build
  time, not guessed.
- **Tier**: `self.tod_tier = 3` + give the T3 gun in its PaP'd form via the
  classes module (the path `tier_card_code` uses, `_tod_upgrades.gsc:2434`,
  minus the level-0/reset semantics — this grant is the OPPOSITE of a tier
  card: levels are being maxed, not reset).
- **Refill**: full ammo + restore health. Luck bar → irrelevant (no more
  events); zero it for the HUD's sake.

## §3 The Spire (generator work)

- **Shape**: the spiral emitter already parameterizes everything the Spire
  needs (`LAPS`, `LAP_RISE=384`, parity mirroring, `PARA_EVERY` bake knob).
  A second invocation with its own origin offset + 100 laps + a SIMPLIFIED
  floor kit: no breather lounges, no furniture, no teleporter spurs — stairs,
  landings, doors, risers, zone volumes, respawn points, vendor pads. New
  §section in `gen_tower_map.js`; every coordinate through one `SPIRE_OFF`
  vector so placement is one knob.
- **Placement — USER DIRECTIVE 2026-08-29**: "You should be able to see this
  tower from the original tower but we can make it kinda far away in the
  distance. But players should be able to see and wonder what that tower is."
  East of the tower in the void, far: `SPIRE_OFF` ≈ (+10000, 0) as the
  starting knob — a silhouette with a glowing accent, not a neighbour. The
  city-smog fog hides its base at street level and the upper half emerges as
  the party climbs — the mystery builds with altitude, free. Teleport-only
  reach reinforces the one-way rule. Skybox: `SKY_IN`/`SKY_TOP` are already
  derived maxes (`gen_tower_map.js:483-485`) — extend the max terms to
  enclose it. Sky brushes are unlit (excluded from lit-area already).
- **Height**: 100 × 384 = 38,400u; base at z≈0, top ≈ 38.7k with the summit —
  inside BSP world bounds with margin (crown top is ~33.5k today; cod2map
  hard-fails on a genuine bounds violation, so the compile is the verifier).
  Base above z=-1000 → stock below-world failsafe never fires.
- **Aesthetic**: same Tron grid grammar, ONE twist so it reads as "beyond the
  crown" — recommend a single accent (crimson/void-red edge-lit inlays vs the
  tower's cycling 5) + sparser lighting. Cheap in lit area, distinct at a
  glance.

## §4 THE BUDGETS (the real feasibility question — measured, not guessed)

- **Lit area (bake ceiling)** — measured 2026-08-29 via
  `measure_lit_area.js`: whole map 1125M u², **the 50-lap spiral is only
  59.1M (5.3%)**; the crown is 945M (84%). A simplified 100-lap spire ≈
  +100-120M ≈ **+10%** — a small add against the ceiling the crown already
  set. Gate remains `_bake_test` read as BAKED/CRASHED only (never the
  timing); mitigation ladder if CRASHED: spire `PARA_EVERY` 2→4, fewer
  edge-lit inlays, unlit trims.
- **Brushes**: spiral = 2841 brushes / 50 laps (~57/lap). Simplified spire ≈
  +4-5k world brushes (map today: ~5.1k incl. unlit). No known hard wall;
  the bake gate + lint (~1s, whole-map) decide. Lint baselines must stay at
  zero-regression — the spire's stairs/edges get the same rails/derived
  guards, so no new baseline entries.
- **Runtime entities — THE binding constraint**: map 1 shipped
  `Com_ERROR: G_Spawn: no free entities` (~1024-entry game-entity table) when
  530 deco props were runtime spawns; fix was baking them as `misc_model`
  statics (map 1 `docs/02_layout.md:269`). This map's `prop()` already
  handles pool-full (`_tod_finale.gsc:228`). Three rules follow:
  1. **Everything static about the Spire is COMPILED** (worldspawn brushes,
     `misc_model` statics, `script_struct` risers, `info_volume` zones —
     none of these occupy runtime slots).
  2. **THE TOWER DIES BEHIND YOU** — the one-way rule is an entity budget,
     not just fiction. At ascension, delete the old world's script-spawned
     load: door triggers + unbought slabs, all five teleporter assemblies
     (~7 models each + hosts), ammo crates, upgrade/class stations, breather
     vendors, finale props/beacons/sconces/avenue hosts. Estimated
     **150-300 slots freed**. (Perk machines are NOT deleted — they MOVE,
     next rule.)
  3. **Vendor triggers/props spawn LAZILY in a climb window** (current lap
     ±2), despawned below — the ammo-crate-per-floor ask costs ~15 live
     entities this way instead of ~300 resident.
- **Zones**: 52 today; spire chunked at 1 zone per 5 floors + base + summit ≈
  +22 (→ ~74). No documented zonemgr cap found in the KB — VERIFY against
  stock zonemgr source during implementation before trusting it. Respawn
  points per chunk zone, `script_noteworthy = zone name` (the shipped-inert
  trap, memory `respawn-points-need-zone-noteworthy`).
- **Doors**: slabs as generated `.map` `script_brushmodel`s (the proven
  contract) = ~100 resident brushmodel entities, offset by the teardown; buy
  triggers spawn lazily in the climb window (2/doorway only near the party).
  If the resident count still hurts: door every 2nd floor is the fallback
  knob. Price: flat **3000** (the original lap-door cap; the 7500 roof price
  is the summit's option). Prices ride generated `_tod_spire_data.gsc` — same
  no-drift contract as `_tod_door_data.gsc`.

## §5 Vendors on the Spire

- **Ammo crate every floor** (the ask): lazy-spawned `_tod_ammo_crate`
  instances in the climb window. Coords generated.
- **Perk re-buys** (players hold all 9, but a down loses them): the 8 scatter
  machines **teleport with the party** — vendor pads every 10th spire floor
  (2 per hub, 20 pads) join the scatter's pad pool at ascension and the base/
  breather pads leave it; the every-4-rounds reshuffle then works unchanged.
  Zero new machine entities, and the map's signature mechanic climbs with
  you. Mule Kick stays behind on the roof (or: one pad at the spire base
  pinned for it — open design nit).
- **PaP every hub**: the 5 ALXS `zm_cwpap` vendors are registered at init
  with fixed anchors — **whether they can move or late-register is the one
  genuinely open technical risk** in this design. Investigate the pack's
  register path first; fallback is a self-owned vendor lane (the map already
  drives vendor stock lanes in `_tod_powerups`). Do NOT touch the stock PaP
  singleton (memory: `second-pap-fatals-load`).

## §6a THE SPIRE RUNS HOT (user directive 2026-08-29)

"The aggression picks up in the endless spire so rounds will fly by but
zombies just keep coming non stop and quickly." Mechanism: a permanent
`tod_spire_active` branch in `tod_spawn_delay` — same shape as the
`tod_finale_aggro` branch — pinning the trickle at a hot floor (start 0.18s,
tunable; the finale's own band is 0.4→0.1 phased, so 0.18 is "sustained
finale pressure" rather than "berserk"). No breather calm-down on the spire
(no lounges exist there; the check is footprint-gated and never fires).
Compounding is free and intended: endless rounds turn over when the budget
SPAWNS, so a hot trickle makes round numbers fly, which drives the
+0.28%/round speed curve faster — the spire gets harder on two axes from one
knob. The actor cap is untouched (the one thing the finale's pressure system
was built never to raise).

**Positioning note (2026-08-29 evening):** the user tuned the BASE game
easier off live Workshop feedback with the explicit rationale "I dont mind
making it easier now that we have an endless mode" — THE SPIRE IS THE MAP'S
HARD MODE by design now. Tune its pacing against that role: the 0.18 floor's
contrast with the (gentler) base curve is the point, not an accident.

## §6 What keeps running (nothing new to build)

Endless rounds (the twist IS the mode), zombie speed curve (+0.28%/round
unbounded — the real difficulty clock), Panzer every 5th / protector wave
every 3rd (wave size already caps at the concurrency roof), hellhounds,
armored sprinters (elite gating keyed on lap — map spire z→lap through the
same arithmetic). The finale's own aggro flags (`tod_finale_aggro`, spawn
floor, force-orgs) must be CLEARED at ascension — audit every
`level.tod_finale_*` / `tod_crown_sealed` / `tod_gate_open` consumer the way
the seal's teardown block does (`_tod_finale.gsc:715-720`).

## §7 Music — DECIDED 2026-08-29: a dedicated Suno track

The user is generating a NEW track with Suno 5.5 ("cyber retro half boss
music. That works on a loop") — the reuse-the-bands option is dead. Wiring:
alias `tod_music_spire` (clone the `tod_ambient_music` row, new Name +
FileSpec), wav at `sound_assets/tod/music/tod_music_spire.wav` under the
enforced 48k/16-bit contract, loudness-matched to the set (−8…−9 LUFS,
recipe in that README). At ascension: release the finale latch, then
**replace `level.tod_music_bands` with a single row (floor 0 →
`tod_music_spire`) and reset the band latch** — the band watcher and the
Panzer boss-override then work unchanged on the spire with no new code
paths. Every alias loops raw, so the deliverable gets loop-point surgery
(bar-boundary trim, ffmpeg atrim) before it ships.

## §8 Death, the summit, and the screens

- **Wipe on the spire** = stock end_game with a CUSTOM banner via the same
  `custom_game_over_hud_elem` seam the win screen uses
  (`_tod_finale.gsc:1663`) — they beat the game, so the death screen should
  say so (they fell as sovereigns, not as victims). Floors-climbed line as a
  second hudelem text row (stock prints rounds survived already).
- **Summit (floor 100)**: recommend a small arena + SUMMIT EXTRACTION
  (price: the roof's 7500) that ends the game as a WIN with its own banner —
  the mode keeps a chosen ending; without it the only exit is death.
- **Game-over restart menu** (memory `gameover-restart-menu`) works unchanged.
- All new screens/banners are **server hudelems with baked art** — zero new
  LUI bits (the 61-bit clientuimodel ceiling is untouched; APPEND ONLY rule
  not even exercised).

## §9 New assets (image prompts sent in chat per the images-over-LUI rule)

| asset | material | shown | canvas |
|---|---|---|---|
| `tod_choice_banner` | server hudelem | win → choice state, until a hold commits | 2048×512 → 900×225 |
| `tod_spire_banner` | server hudelem | ~6s on arrival at the spire | 2048×512 |
| `tod_spire_over_banner` | game-over elem | wipe on the spire | 2048×512 |
| `tod_spire_win_banner` | game-over elem | summit extraction (if approved) | 2048×512 |
| `tod_spire_emblem` (optional) | game-over elem | above spire banners, mirrors `tod_win_emblem` | 1024×1024 → 128 |

Pipeline per asset: PNG → `_images/` + `image.gdf` block + 2d_blend material
wrapper (mirror `tod_win_banner`'s pair in `tod_ui_images.gdt`) + zone lines.
**Every one of these is a `.gdt` change = FULL build.**

## §10 Open questions — ALL ANSWERED (user 2026-08-29: "I like all the
proposals you sent")

1. Door cadence: **every floor @3000** (fallback to every-2nd stays available
   if the live entity count bites).
2. Choice contract: **first committed hold-USE takes the whole party.**
3. Summit extraction at floor 100 as a WIN @7500: **approved.**
4. Name: **THE ENDLESS SPIRE** — locked; drives all baked art text.
5. Music: **dedicated Suno 5.5 track** (see §7 — decision superseded the
   reuse recommendation).
6. "Power ups maxed" = upgrade domains + T3 PaP gun: **confirmed.**

Step-1 art exploration prompt + step-2 batch prompt + the Suno prompt were
delivered in chat 2026-08-29; step-2 runs after the user picks a direction
from step 1.

## Build-order sketch (for when implementation is approved — NOT now)

1. Generator: spire section + `_tod_spire_data.gsc` emitter + skybox extents
   + lint coverage → full build → **bake gate** + `measure_lit_area` A/B.
2. `_tod_spire.gsc`: ascension teleporter, choice state, grant, teardown,
   window manager (lazy vendors/triggers), scatter pad-pool swap, summit.
3. Finale surgery: choice state replaces auto-depart; atmosphere latch
   release.
4. Art batch (§9) after direction sign-off; wire screens.
5. Live-verify ladder: choice both ways → grant audit (every domain actually
   applied) → climb window churn (entity count printed per lap in dev) →
   wipe screen → summit.
