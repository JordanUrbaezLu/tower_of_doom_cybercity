# 41 — THE FINALE RUN: DESIGN OPTIONS (2026-08-27)

> User: *"some paths just go straight to the finish line. Is there any
> enhancements or design updates we can do here on the final run to make it a
> better experience. I feel like running straight the whole time is kinda ehh"*

Standing intent on record (2026-08-26): every lane a DIFFERENT KIND of fear; the
risk at the ending is being PINNED, not being slow. This document measures why
the road still reads as "running straight", then lays out the options that
survived a full feasibility pass against the source. **Nothing here is
implemented.** Every mechanism cited below was verified against the repo this
session; the handful of computed (not live-measured) inputs are flagged where
they appear.

Sibling docs: docs/23/24 (experience reviews), docs/34 (crown doctrine),
docs/39 (stair research — stair FEEL is solved as of v12.12; nothing below
touches it).

---

## 1. THE PROBLEM, MEASURED

### 1.1 The frame

- The song is the clock: 191 s (`_tod_finale.gsc:115`), road phase capped at
  90 s (`:136`), hold-out = whatever remains (`:669-671`). The road ends EARLY
  when every living player is `in_crown` (`:613-618`), and the door seals
  (`"tod_finale_sealed"` notified at `:650`).
- At the seal: players in the hall gather to a ring (`gather_to_centre`
  `:864-887`); anyone still outside is killed with lives = 0
  (`kill_stragglers` `:906-921`).
- Pressure is FLAT: spawn delay floored at 0.1 s from second zero
  (`_tod_endless_rounds.gsc:42, :266-267`), bosses topped up one type per 6 s
  tick under the combined roof of 4 (`_tod_bosses.gsc:111-112, :730-793`),
  Panzer anchored to the highest player, protectors to the lowest
  (`anchor_player` `:380-402`).
- There is no timer on screen (deliberate) and the four quarter beacons ignite
  only during the hold-out — **during the 90 s road phase the map's biggest
  object does nothing and there is no progress read at all** except the road
  itself (`_tod_finale.gsc:672-681, :739-744`).

### 1.2 The slack (computed, not live-measured)

Class run speeds from `class_speed_base` (`_tod_upgrades.gsc:1185-1198`) ×
base 190 u/s; route lengths from the cwY table and lane declarations
(`tools/gen_tower_map.js:1602-1608, :1631-1756`). Diagonal-corrected walk
estimates against the 90 s cap:

| Route (fork 1 + fork 2)          | walked ≈ | HEAVY | ASSAULT | SKIRM | SLASHER |
|----------------------------------|----------|-------|---------|-------|---------|
| Broken Stair + Plank (fastest)   | ~7,900u  | 55 s  | 46 s    | 42 s  | 38 s    |
| Broken Stair + Undercroft        | ~8,450u  | 59 s  | 49 s    | 44 s  | 40 s    |
| Ridge + Plank                    | ~8,300u  | 58 s  | 49 s    | 44 s  | 40 s    |
| Ridge + Weave (slowest)          | ~9,600u  | 67 s  | 56 s    | 51 s  | 46 s    |

Worst case in the game — a HEAVY on both long lanes, never sprinting — arrives
with **23 s to spare**. A SLASHER on the fast line arrives with **~55 s**
spare. The 90 s clock never bites anyone moving generally forward.

Worse: because hold = song_end − now (`_tod_finale.gsc:669-671`), **every
second saved on the road is a second added to the sealed-hall siege** with its
permanent Panzer (`finale_holdout_start`, `_tod_bosses.gsc:723-728`). The
mechanically optimal play is to loiter on the open road until ~85 s — the
exact opposite of what the banner and the song are selling.

### 1.3 The segments

Times at SKIRMISHER 190 u/s (HEAVY in parens). Risers = one per flat piece
(`causewayRunPoints()` `gen_tower_map.js:1864-1866`, wired at `:3316-3328`).

| # | Segment (y)              | Len   | Time        | Decisions       | Threat            | Interactions |
|---|--------------------------|-------|-------------|-----------------|-------------------|--------------|
| 0 | Terrace / uplink 355-480 | ~130  | 1 s         | buy or not      | 2 risers          | **the buy — the run's ONLY interaction** |
| 1 | Gate-run 480-1120        | 640   | 3.4 (4.5)   | none            | 1 riser           | none |
| 2 | J1 fork 1120-1280        | 160   | 1 s         | pick W/E — uninformed | 1 riser     | none |
| 3a| Ridge (W) 1280-3520      | ~2640 | 14 (18.5)   | 2 forced turns  | 4 risers, draws Panzer | none |
| 3b| Broken Stair (E)         | ~2240 | 12 (15.7)   | none — straight in plan | 3 risers  | none |
| 4 | J2 merge 3520-3680       | 160   | 0.8         | none            | 1 riser           | none |
| 5 | Narrows 3680-4320        | 640   | 3.4 (4.5)   | none            | 4 risers, on-axis ahead | none — 120 width never slows a solo player |
| 6 | J3 fork 4320-4480        | 160   | 0.8         | pick W/C/E      | 1 riser           | none |
| 7a| Undercroft (W) 4480-6720 | ~2780 | 15 (19.5)   | none            | **1 riser in 2,240u** | none |
| 7b| Plank (C)                | 2240  | 12 (15.7)   | none — dead straight | 4 risers, draws Panzer | none |
| 7c| Weave (E)                | ~3570 | 19 (25)     | 8 forced corners| 9 risers — most infested | none |
| 8 | J4 merge 6720-6880       | 160   | 0.8         | none            | 1 riser           | none |
| 9 | Approach + flare 6880-7840| 960  | 5.1 (6.7)   | none            | 2 risers          | none — arrival is crossing an invisible line |
| 10| Hall, pre-seal           | —     | 0-50 s+     | none            | hall risers only after seal | WAIT |

Between the buy and the seal the player performs: **2 route picks worth ~3 s
each, 0 interactions, 0 pickups, 0 triggers, 0 mid-run objectives.**

### 1.4 The five monotony findings, ranked

1. **The finish line is dead air.** The 1,120u J4→gate stretch is the longest
   decision-free straight since the opener, at peak anticipation — then
   arrival is an invisible line and up to tens of seconds of standing in the
   hall waiting for `all_living_in_crown()` (`:836-850`) or the timeout.
2. **The clock never bites, and speed is punished.** 23-55 s of slack for
   every class on every route, and the hold-remainder math taxes arrival.
   This is the root cause: nothing chases the player's throttle.
3. **The dominant line is the straight line.** Broken Stair + Plank — both
   straight in plan — is fastest, and the risk math never pushes back. After
   one run both forks collapse into hold-W.
4. **The forks are uninformed and unfelt.** Nothing at a landing identifies a
   lane; the payoffs (boss altitude flavor, riser density) are invisible and
   small. The undercroft — the flagship "scary" lane — is objectively the
   road's *quietest* ground (its cistern is the lane's only flat piece,
   `gen_tower_map.js:1697-1699` → 1 riser in 2,240u). The fear vocabulary and
   the threat reality point in opposite directions.
5. **The Narrows doesn't narrow anything.** The one guaranteed choke (120 ×
   320 under portal 2, `:1681-1682`) passes a solo player at full speed with
   zero input change; its risers sit ahead, exactly where the gun points.

**The complaint is not that the geometry is straight — it is that the player
is in the same STATE on every straight.** v12's lanes are real; they are
mechanically unpriced and dramatically unaccompanied.

### 1.5 Inputs that are computed, not proven

The speed/slack table above is arithmetic on `class_speed_base` and the cwY
table, not a stopwatch. And every "musical hit" timestamp in Section 2 is a
placeholder: **measure `tod_music_finale.wav` first** (`ffmpeg -af ebur128`,
recipe in `sound_assets/tod/music/README.md:44-53`) and snap beats to real
hits. The measure-first doctrine is already house law for audio.

---

## 2. THE MENU

Everything below survived feasibility verification against source. Shared
facts used throughout: both ends of the song are published
(`level.tod_finale_song_start/_end`, `_tod_finale.gsc:609-610`) so any thread
can key off song progress with no new clock; the cue kit is host-based
(`derez_burst` / `play_sound_at_origin`, `_tod_perk_scatter.gsc:778, :814`);
the `todPerkGlow` aura is a 4-bit ENTITY clientfield on any scriptmover
(`_tod_perk_lights.gsc:38, :166-171`, colours `:142-163`, blink proven
`:100-137`) — it does NOT touch the 61-bit clientuimodel ceiling; `prop()`
spawns non-solid cosmetic hosts with no navmesh obligations
(`_tod_finale.gsc:193-201`); risers are `script_struct`s collectable and
sortable by y (`gen_tower_map.js:3316-3328`) at zero bake cost (`:3233-3234`);
and `guid()` is a deterministic counter (`:704-708`), so a generator change
that only adds GSC-writer lines leaves the `.map` byte-identical and stays
`-GscOnly` (verify with a diff of the regenerated `.map`).

Every timed thread must survive an early seal — `endon("tod_finale_sealed")`,
notified at `_tod_finale.gsc:650`. Any new y-threshold region test must apply
the CM mirror like `beyond_gate` does (`_tod_crown_data.gsc:22-26`, emitted
at `gen_tower_map.js:4137-4141`).

### TIER A — cheap and certain (script/FX only, `-GscOnly`, near-zero risk)

---

#### A1. THE DEREZ TIDE — the road dies behind you  · kill-rating 5/5

**Experience.** The gate opens, and ~12 seconds later the terrace end of the
causeway starts to *derez* — a crackling red front crawling north up the road
at a fixed pace, portal frames and pylon pips flipping from blue to red as it
swallows them, spawns favoring the deck just behind you. It never outruns
anyone who keeps moving — even a HEAVY walking backward shooting stays ahead
of it — but it eats the 23-55 s of slack alive. Loitering for siege-optimal
timing is dead. Taking the Weave is now a bet. Going back for a downed
teammate has a price. Look over your shoulder and the road you already walked
is being unmade; look ahead and the remaining blue lights ARE the clock. The
banner finally tells the truth.

**Build (pure script + GSC-only generator emit).**
- Front = one y-coordinate advanced by a thread in `finale_run`
  (`_tod_finale.gsc` after `gate_open` `:306-334`), pure arithmetic on the
  published song clock, polled at 0.25 s. TER_Y2=480 → cwY[9]=7840
  (`gen_tower_map.js:1602-1608`) over ~85 s ≈ **87 u/s = 61% of HEAVY's
  142.5 u/s** — put that inequality in a comment as the design invariant.
  A y-plane front is fair on every lane: all v12 lanes advance monotonically
  in +y (`:1631-1756`), and the ±256/−384 z excursions stay inside
  `beyond_gate`'s z bound (CW_ZMIN 18928, emitted `gen:4140`).
- Behind = `beyond_gate(org) && org[1]*CM < front_y && !in_crown(org)`. The
  terrace respawn pad at y≈370 is structurally NEVER behind the front
  (`beyond_gate` is false below y=480). Harm is tiered: rumble + chime inside
  400u (`PlayRumbleOnEntity` pattern `_tod_bosses.gsc:1558`,
  `play_sound_at_origin` `_tod_perk_scatter.gsc:814`); overtaken by >~300u
  for >~4 s → the exact `kill_stragglers` death (`_tod_finale.gsc:906-921`) —
  reusing the seal's own death makes the tide legible as "the seal, moving".
  Skip laststand players (the `isalive`-in-laststand trap,
  `_tod_endless_rounds.gsc:165-180`). **No solids, no movers, no crush case,
  no navmesh work** — a 0.25 s poll, the map's normal cadence.
- Spawn coupling: one clause in `finale_spawn_selection` — drop risers south
  of the front (the shipped gate-filter shape,
  `_tod_endless_rounds.gsc:103-119`), and when the front is within ~600u of
  the focus player, relax the facing test (`:219-220`) for candidates between
  the front and him so a fraction of spawns land at his heels. Keep every
  fail-safe (`:117-118, :141-142, :234-242`).
- The visible front doubles as the COUNTDOWN AVENUE: ~11 `prop()` glow hosts
  at the 3 portal frames (`portal_orgs()`, `_tod_crown_data.gsc:13-20` —
  verified ZERO consumers today) and the 8 pylon pips
  (`gen_tower_map.js:1823-1831`, y 640/960/3792/4208 at x ±360; export
  `avenue_pylon_orgs()` beside the `pylon_orgs()` emit, `gen:4104-4221`
  pattern — GSC-only, `.map` byte-identical). All ignite blue (colour 6) at
  the buy; each flips red (1) + `derez_burst` as the front passes its y —
  change-only clientfield sets, never poll-spam. `depart_show`
  (`_tod_finale.gsc:1126-1143`) can strobe them green on victory for free.
  Open item: aura draw distance at 3,000u is unproven — fallback is the
  precached warning-light model the mast beacon already uses (`:273-278`).
- Co-op respawn (the one correctness item, **needs user sign-off**): a
  bleed-out lands at the terrace group (`gen_tower_map.js:3521-3541`) behind
  the front. Either an 8 s grace stamp on `"spawned_player"` (front 87 u/s vs
  HEAVY 142.5 — every class catches up sprinting), or a warp to the rearmost
  living teammate ahead of the front (`SetOrigin`+`SetPlayerAngles`, the
  proven recipe `_tod_teleport.gsc:454-484`). The warp variant amends the
  "come back at the START of the road" doctrine (`gen:3504-3507`) for the
  tide window only.

**Cost.** ~150 lines in `_tod_finale.gsc` + one selector clause + ~6 generator
lines. `-GscOnly`. Zero geometry, zero bake, zero asserts touched.

**Risk.** Tuning-only; every failure mode is soft (front too slow = today's
behavior; too fast = one constant). The respawn rule is the only correctness
item. This was independently proposed by three of four design lenses and drew
the cleanest feasibility verdict of all twelve proposals.

---

#### A2. AUTHORED BOSS BEATS — the score plays the monsters  · kill-rating 4/5

**Experience.** The buy lands on the song's quiet intro — and the road is
eerily open. For the first ~20 s you run through near-silence, zombies only
trickling: the run's overture, the one moment you get to LOOK at the crown
you're running to. As the music builds, the spawn floor tightens. Then, ON the
song's first drop, the sky tears: the Panzer's full drop-in telegraph — ground
tell, falling proxy, earthquake, landing FX — puts him down astride the lip of
the Narrows just as the first runner reaches it, under portal 2's frame. The
choke finally chokes: burn him down from the 320-wide throat, or thread past
his claw at touching distance while the horde closes. Later, as the leader
crosses J4, two protectors drop onto the gate flare — the 960u decision-free
approach becomes a fight through the doorway of the thing you've been running
toward. Pressure and music are the same curve; the run *escalates* instead of
starting at 11 and staying there.

**Build.**
- Phased spawn floor: `tod_spawn_delay` (`_tod_endless_rounds.gsc:248-269`)
  reads song progress and interpolates 0.4 → 0.2 → 0.1 s across three phases.
- Beat triggers, two flavors that can mix: song-time (measure the wav first)
  or leader-y thresholds (a 0.25 s poll of max on-causeway y crossing
  J2=3520 / J4=6720). Beat orgs (Narrows north lip ~(0, 4180, TOP2); flare
  ~(0, cwY[9]−80, TOP2)) emitted by the generator into `_tod_crown_data.gsc`
  (the `crown_crate_org()` pattern) so script and road can't drift — GSC-only
  emit, `.map` byte-identical.
- The drops use the proven entrance kit verbatim: `drop_in(boss, v_ground,
  ...)` takes an explicit ground point (`_tod_bosses.gsc:440-501`), 2 s
  `tell_fx` lead (`:420-429`), `drop_clearance` degrades gracefully under
  overhead geometry (`:406-415, :454`).
- **The one piece of new plumbing** (feasibility-confirmed as the right
  seam): a consume-once `level.tod_boss_force_org` honored at the
  `pick_spawn_point` call sites (`_tod_bosses.gsc:1002-1004`) plus a direct
  kick of the spawn path — the pressure loop only writes DEBT (`:766-767`)
  and the director picks its own point on its own cadence, so without the
  force-org the beat lands ±a tick and anywhere.
- **Replace, don't add**: check `live < roof` exactly as the loop does
  (`:754-761`), zero the type's debt AND skip its next rotation turn so the
  substitution doesn't double-count. Roof stays 4; total pressure is
  identical to today, just choreographed. Altitude anchoring is bypassed for
  these two spawns only. Mid-run tick change (6 s → 4 s back half) means
  converting `TOD_FINALE_PRESSURE_TICK` from a #define to a level field.

**Cost.** ~140 lines across `_tod_bosses.gsc` / `_tod_finale.gsc` /
`_tod_endless_rounds.gsc` + generator org emit. `-GscOnly` (verify the `.map`
diff is empty).

**Risk.** Low. A Panzer parked mid-pinch can wall a low-DPS party — land him
at the pinch's *lip* (fightable from the 320-wide throat), and he replaces
scheduled pressure rather than adding to it. Quiet overture slightly reduces
road kills (negligible — upgrades are suppressed for the run anyway,
`_tod_finale.gsc:580`).

---

#### A3. THE TURN — a mid-run "all is lost" beat  · kill-rating 4/5

**Experience.** Around the song's breakdown (~t=58, measured), the run TURNS.
For ~12 seconds the spawn logic inverts: risers behind and beside you wake
instead of the ones ahead — the horde you outran is suddenly between you and
the way back, boiling out of deck you already cleared, while boss telegraphs
flare at both ends of your lane. On the plank that means the pieces behind
you surface and the only way is forward along 120 units of width; in the
weave, every blind corner you passed is now live. Then the music surges out
of the breakdown and the road answers: a wave of derez light ripples
riser-to-riser from wherever you stand all the way north to the citadel
mouth, the gold portal in the crown's throat flares, and the final approach
plays under the song's climax. Today's deadest air becomes the scored sprint
the banner always promised.

**Build.** The inversion is genuinely ONE conditional: flip the facing
dot-test sign (`_tod_endless_rounds.gsc:219-220`) under a
`level.tod_finale_turn` flag for the window, keeping the 280u floor (`:52`)
and both fallbacks (`:234-242`). Telegraphs via `tell_fx`
(`_tod_bosses.gsc:420-429`) at the nearest behind-riser per player; the
light-wave is a thread walking the collected riser structs sorted by y,
firing `derez_burst` + a soft chime at ~40 ms/step. No visionset, no fog —
deliberately (the visionset traps are on the memory record); every cue is
entity-FX/sound. No new text, no banner — fully diegetic.

**Cost.** ~100 lines, `-GscOnly`, zero geometry.

**Risk.** The window must be SHORT (10-15 s) and, if the tide (A1) ships,
must sit clear of the front's position so behind-spawns don't land on dying
deck — order the timestamp table. Without A1, verify the window doesn't make
loitering *more* attractive (standing still farms the wave); the 12 s cap and
boss telegraphs are the counterweight. Feel needs one live test.

---

#### A4. THE ARRIVAL — gold throat, count-in, slam  · kill-rating 3/5 vs "straight", but it kills monotony #1 outright

**Experience.** Portal 3 was built for this — it stands inside the crown's
throat and is gold precisely because "the colour change IS the arrival"
(`gen_tower_map.js:1769-1778`); today you run through it and nothing happens.
Proposed: the first survivor across it triggers THE ACCEPTANCE — a ground
ripple, then derez bursts walk the courtyard from mouth to dais in five 0.3 s
steps, and the wall sconces ignite in sequence toward the pad: the room
lights itself for you, front to back. The four hall pillars burn red, one per
living player, and snap green with a chime as each teammate makes it in — the
hall is counting your people. The instant the last pillar turns (or the 90 s
deadline lands), the door doesn't just close: earthquake, derez, SLAM — and
two seconds later the hold-out Panzer crashes through the open crown top onto
a dais telegraph as the song enters its final movement. The seal becomes a
scored downbeat and the siege opens at its peak instead of fading in.

**Build.** Pure GSC in `_tod_finale.gsc`. Portal 3 = `portal_orgs()[2]`;
sconce orgs/yaws already exported (`_tod_crown_data.gsc:80-97`) — the one
structural edit is storing the sconce prop handles that `spawn_props()`
currently discards (`_tod_finale.gsc:283-284`). Pillar count-in = 4 spawned
`tag_origin` glow hosts at the pillar caps (±448, `:142-145`), flipped on the
existing 0.25 s `all_living_in_crown` cadence (`:836-850`). The slam: reorder
NOTHING — gather → close → stragglers stays byte-identical (`:864-921`, and
never add a second path to `depart()`, the double-fire trap at
`:1040-1046`) — just decorate the close, and open `finale_holdout_start`
with a forced `drop_in` at hall centre (needs A2's force-org seam — the stock
path only floors a debt, `_tod_bosses.gsc:723-728`). Land the Panzer offset
from the 160 gather ring (`:146`); `drop_clearance` handles the crown arches
overhead (`:454`). Do NOT touch the quarter beacons — the generator's emitted
comment reserves them as the hold-out progress read (`gen:4188-4197`).

**Cost.** ~150 lines, `-GscOnly`, zero geometry, zero new bits.

**Risk.** Near-zero (the lowest of the menu alongside A1). Gate everything on
`level.tod_finale_state` so it can't double-fire with the 90 s seal path.

---

*Tier A riders (not numbered options — carry them on any package):*
**THE CROWN'S HEARTBEAT** — one glow host at the girandole (coordinate exists
verbatim, `gen_tower_map.js:3935`; emit `girandole_org()` beside
`mast_tip_org()` `gen:4177`, CM-mirrored) pulsing red on an 8 s beat that
halves at each portal crossing and STOPS when the door slams — the crown's
heart stops because you're inside it now. ~50 lines, `-GscOnly`, blink
mechanics proven (`_tod_perk_lights.gsc:100-137`).
**WEATHER TURN** — the extraction buy turns the sky: `SetVolFog` re-stepped
over ~15 s (`_tod_atmosphere.gsc:296-302` proves mid-game re-assert), smog
warmed toward ember and raised to crown altitude so the void under the road
fills with a dim red sea. ~30 lines, `-GscOnly`; the one hazard is density —
the crown must read *through* the haze (docs/34 legibility doctrine outranks
the weather). Neither rider changes what the player's feet do; both make the
straights point at something alive.

### TIER B — one good build (generator geometry inside roadEmit's existing range)

---

#### B1. THE LOTTERY SEAL — one lane per fork is dead each run  · kill-rating 4/5

**Experience.** The road you paid for is never the same road twice. As the
gate derezzes open, two slabs slam visible down the deck — one lane at each
fork, rolled fresh per run, walled off and red-lit in the same visual grammar
as the causeway gate you just bought. Some runs the Plank is gone and the
memorized speedline dies with it; some runs the Broken Stair is gone and the
Ridge's exposed crest is mandatory. You read the sealed mouth from the
landing and route live.

**Build.** 5 thin `script_brushmodel` slabs across each lane's SOUTH mouth
just past the J1/J3 landings — the causeway-gate emission pattern verbatim
(`gen_tower_map.js:3693-3699`), orgs into `_tod_crown_data.gsc`. Init all
five open (Hide/NotSolid/ConnectPaths, `_tod_finale.gsc:345-370`); at
`gate_open` roll one per fork and seal it (Show/Solid/DisconnectPaths,
`:372-382`) + derez + red glow via tag_origin hosts (glow on a brushmodel
itself is unproven). **The crush case is structurally absent** — sealing
fires while the whole party is still behind the still-solid causeway gate.
South-mouth-only sealing keeps every lane path-connected via the merge (all
six branch mouths verified at ZB), so nothing strands; a spawn filter drops
risers in the sealed band (the shipped shape,
`_tod_endless_rounds.gsc:103-119`). Walkability is guaranteed by
construction (one lane per fork always open); the compile-time flood and the
5f.9 assert only see world brushes (`gen:3097-3107, :1530-1535`) — runtime
entities are invisible to both, same as the existing gate.

**Cost.** Full build (new .map entities) + bake gate (entities ≈ nil lit
area; read BAKED/CRASHED only) + geometry lint (no brush change → no
regression). ~100 lines GSC.

**Risk.** Low — every half of the contract (seal, open, filter, announce) is
a shipped pattern; feasibility rated it the strongest correctness story of
the geometry proposals. It kills finding #3 dead: "Broken Stair + Plank every
time" cannot survive a lottery.

---

#### B2. POCKETS THAT WAKE UP — the scary ground gets real teeth  · kill-rating 4/5

**Experience.** The broken stair's hollow and the undercroft's cistern are
sold as the road's scary ground and are actually its quietest. Now the first
boot into a pocket trips it: every riser in the pocket derez-flares at once
with a rising chime — a ~1.2 s beat where the floor visibly ARMS around you —
then six seconds of spawns dump into the pocket from all sides, facing be
damned. The blind sprinter takes the ambush at knife range; the player who
pauses at the lip, watches the pocket light up, and fights in on their own
terms gets rewarded. Reading the road beats hold-W.

**Build.** Riser density is a DECLARED knob — one riser per flat piece, and
the plank was already split into four pieces for exactly this reason
(`gen_tower_map.js:1712-1718`). Split the cistern flat into 3 pieces along x
(each ≥120 short-dimension, `CW_MIN_LANE` guard `:1407-1408`; 440×320 splits
3×~146) and each hollow flat into 2 (320/160 fits). Same cells, same z —
deck geometry unchanged, but new brushes/risers = `.map` regen = full build.
Generator emits pocket bboxes + riser orgs into `_tod_crown_data.gsc` (the
`in_hall` emit pattern, `gen:4165-4172`). Script: a once-per-pocket entry
watcher → arming tell → 6 s burst window; `finale_spawn_selection` gets a
pre-clause filtering candidates to the box and ignoring the facing test,
with a reduced ~160u floor — the arming tell IS the reaction window the
`TOD_FINALE_MIN_AHEAD_SQ` doctrine comment demands
(`_tod_endless_rounds.gsc:43-52`). Copy the never-return-empty fail-safes.

**Cost.** Generator lane splits + org emit (full build once), ~60 lines of
script. `CW_DEEP` untouched — no new depth.

**Risk.** For 6 s the burst redirects the party's spawn stream at one pocket;
players elsewhere get a lull — acceptable at 6 s. This is the one option that
specifically punishes blind straight-line sprinting while rewarding
road-reading, and it fixes the undercroft's fear/threat inversion (finding #4).

---

#### B3. VOID PIERS — risk-reward spurs off the road  · kill-rating 4/5, **ship only alongside A1**

**Experience.** Off the J2 merge, a 120-wide pier runs ~400 units into open
void, dead-ending at a floating plinth where a prize shimmers under a teal
beacon visible from the landing. A second pier dips off the undercroft
cistern — the deep lane finally gets a reason to exist. Walking out is 5-8
seconds of round trip on a dead end whose own risers wake behind you; with
the tide eating the road at your back, grabbing it is a genuine gamble — and
the prize pays off in the sealed hall, not on the road.

**Build.** Each pier = 2-3 `roadFlat` cells off a junction landing — **dead
ends are legal** (the flood throws only on unreachable columns,
`gen:1530-1535`; a connected spur floods). roadEmit derives rails, clip caps,
riser, zone membership and the sky envelope automatically (`:1846-1857,
:1864-1866`) — the pier is self-infesting with zero extra work. Feasibility
computed the J2-east pier clears the (±360, 3792) avenue-pylon assert
(`gen:1819-1822`) with ~28u of margin — legal but pinned; the assert is the
guard. The cistern pier stays AT −384 (`CW_DEEP` is a hard ceiling,
`gen:1324-1327`). Reward, two proven forms: a hold-USE station (the ammo-crate
template, `_tod_ammo_crate.gsc:126-145`, generator clip contract `:28-48`,
hall precedent `:116-123`), or a placed powerup —
`zm_powerups::specific_powerup_drop(name, org, ..., b_stay_forever)` exists
in stock (`<modtools>/share/raw/scripts/zm/_zm_powerups.gsc:688`;
`b_stay_forever` skips the timeout entirely, `:698-701`; shipped precedent
`_zm_ai_dogs.gsc:292`; the name must be in `level.zombie_include_powerups`,
include path per `_tod_powerups.gsc:103-124`). Luck is NOT a viable prize —
upgrades are suppressed for the run and the game ends after
(`_tod_finale.gsc:580`).

**Cost.** ~8-12 road cells + derived rails (trivial next to the crown's
84-85% of lit area — confirm with `node tools/measure_lit_area.js`), full
build + bake gate + lint. ~60 lines GSC.

**Risk.** Without A1 this is free candy that ADDS slack usage — ship with the
tide or not at all. Also the road's first player-initiated interaction after
the buy, which Section 1.3 shows is currently a count of zero.

### TIER C — ambitious (new systems, needs prototyping)

---

#### C1. HOT LANES — live threat state you read, that flips  · kill-rating 4/5

**Experience.** At each fork mouth floats a lane sigil. One burns RED — that
lane is HOT: its risers favored, most of the ambush living there, and bait
glittering at its midpoint (a placed max-ammo or insta-kill, the B3 powerup
plumbing). The others glow cold teal. The fork becomes an informed read:
fast-but-hot with a prize, or long-but-quiet. At the road's quarter marks a
chime-and-derez fires and the heat REROLLS — the cold lane you committed to
can catch fire under your feet, and the party argues in real time: push
through or eat the slow merge. Rolled fresh every run, revisable mid-run —
the fork never collapses into a memorized answer.

**Build.** Sigils = non-solid script_models at the 5 lane mouths (orgs
generator-emitted), glow RED/teal, reroll at 25/50/75% of road phase off the
song clock. Heat = a pre-filter stage in `finale_spawn_selection`: when the
focus player is inside a lane's band, triple-weight hot-lane risers / drop
50% of cold candidates, BEFORE the ahead-test, keeping every fallback.
Feasibility corrections that make this Tier C: (1) J3 is a THREE-way —
"x-sign = lane" cannot distinguish the plank (|x|≤60); it needs x-band
tests. (2) A hot undercroft is toothless until its cistern is split (B2's
riser work) — so C1 realistically rides on a full build. (3) The weight
tuning must be prototyped so it never starves the nearest-ahead guarantee.
No HUD cost — the sigil glow IS the information channel.

**Cost.** ~150 lines + generator org emits; full build if the cistern split
ships with it (it should).

**Risk.** Moderate — the only option here whose core loop (weights a player
reads through spawn behavior) needs live iteration to feel fair. Alone, a
sprinting party can still ignore it; with A1 they cannot.

---

**Best killed idea, one line so it is not re-invented:** THE COLLAPSE
(discrete seal walls slamming shut behind the party on musical hits) — the
same fantasy as A1, but it needs THREE new gate entities, brand-new crush
logic (the "poll the brush bounds clear" pattern a designer cited at
`_tod_finale.gsc:625-637` **does not exist** — the shipped contract is
gather-then-close), and it turns the terrace respawn group into a death trap
behind seal 1; the tide delivers the identical pressure script-only, with no
crush case at all.

---

## 3. WHAT I WOULD DO (awaiting the author's pick)

**Recommended package: A1 + A2 + A4, with B1 as the single-build add-on if a
full build is welcome — plus both Tier A riders.**

Why these four compose:

1. **They share one spine.** A1, A2 and A4 all key off the published song
   clock and can share a single `#define`d beat/front table in
   `_tod_finale.gsc` (front position, phase boundaries, drop beats, all
   reading `level.tod_finale_song_start`). One table, one tuning surface —
   and A1's front and any light wavefront are the SAME variable, so the road
   never shows two disagreeing clocks.
2. **Each kills a different ranked finding.** A1 kills #2 (the clock never
   bites, loitering is optimal — the root cause) and gives the straights a
   pursuer; A2 kills #5 (the Narrows finally chokes) and half of #1 (the
   approach gets its fight); A4 kills the rest of #1 (arrival and the seal
   become the climax instead of dead air); B1 kills #3 (the memorized
   speedline dies). Finding #4 is partially addressed by A2's altitude
   drama and fully by B2/C1 if the author wants a second wave later.
3. **The resulting 191 seconds have a shape**: quiet overture under the
   ignited blue avenue (0-20 s) → the tide starts eating the road → pressure
   climbs with the music → Panzer drop at the Narrows on the first hit →
   climax sprint up the approach with the front at your heels → gold-throat
   acceptance, pillar count-in, SLAM, drop-in siege at peak → last chord.
   The straights stay straight — but the player is never in the same state
   on any two of them, which is what the complaint is actually about.
4. **Build economics**: A1+A2+A4 and both riders are one `-GscOnly` change
   set, independently revertible by constant. B1 is the only full build, and
   its bake exposure is ~nil (entities). Nothing touches the song, the boss
   roof, movers, HUD bits, `pylon_orgs()`, or any generator assert.

Before implementation, in order: (1) measure the wav (`ffmpeg -af ebur128`,
`sound_assets/tod/music/README.md:44-53`) and commit the beat table to real
musical hits; (2) get user sign-off on the two flagged rules — the tide's
co-op respawn handling (grace stamp vs forward warp, which amends the
"respawn at the start of the road" doctrine for the tide window) and the
tide's overtake-death itself (a new way to die; its rumble/chime telegraph is
mandatory, not polish); (3) one live HEAVY run on the slow lanes to validate
the computed slack table before locking TIDE_SPEED.

If the author wants a smaller first bite: **A1 alone** already converts every
straight from "hold W in silence" to "outrun the unmaking of the road", is
one `-GscOnly` build, and is revertible by a single constant. If the author
instead wants the road itself to change: **B1 + B2** is one full build that
makes every run's map different and every "scary" lane actually scary,
without touching the clock at all.

---

## 4. EXPLICITLY NOT PROPOSED

- **On-screen countdown / timer** — violates the standing no-timer decision
  (the banner deliberately carries none, `_tod_finale.gsc:739-744`) and the
  one-announcement rule.
- **Mid-road upgrade/card beat** — any world-freeze desyncs the un-pausable
  song; upgrades are suppressed for exactly this reason (`_tod_finale.gsc:580`).
- **Moving/collapsing deck the player rides** — `SetMovingPlatformEnabled`/
  `_elevator` are MP-namespace and unproven in ZM; HIGH RISK per constraints.
- **Forced-hold segments** (defend N seconds to open a mid-road gate) —
  worst-case legitimate slack is ~23 s; a mandatory hold stacks with the tide
  into unwinnable-by-class, and each sealing brush is a stranded-actor bug
  surface.
- **Narrows cycling shutter** — runs the map's most delicate contract
  (crush-avoidance) every 6 s instead of once, and can pincer a HEAVY
  no-fault under the tide.
- **Cross-lane gantries mid-branch** — a ±256↔−256 stair web (32+ treads per
  connector) for a switch point the merges already provide every ≤2,240u.
- **Mid-road forward teleporter** — warping deletes the very experience being
  enriched, and zombies don't follow (navmesh-invisible).
- **Raising the boss roof for a climax wave** — forbidden without sign-off
  (`_tod_bosses.gsc:111`); every surviving option re-phases within 4.
- **"The lane you didn't pick goes quiet"** — spawns NOT happening is
  imperceptible; zero felt change per line of code.
- **Song-synced baked road lighting** — baked lights cannot switch; every
  light beat above uses entity glows and host-based FX.
- **Colonnade/occlusion fins along a fork lane** — per-fin lit area on a map
  whose crown is already 84-85% of `measure_lit_area.js`, plus a bake gate,
  for an effect the ridge's zigzag already produces.
- **Animated portal frames / moving thresholds** — brush movers over walkable
  deck, one mistake from the 5f.9 doctrine; light-state changes deliver the
  same read at zero risk.
- **Localized per-lane fog pockets** — `SetVolFog` is global; no per-volume
  fog primitive exists in this codebase.

---

*Feasibility provenance: all twelve source proposals were verified against
the tree this session; the options above incorporate every correction
(force-org plumbing for placed boss drops, the nonexistent poll-bounds crush
pattern, J3 three-way x-bands, CW_MIN_LANE split limits, CM mirroring on new
y-tests, full-build reclassification of the cistern split). Computed inputs
still needing live confirmation: the class speed/slack table (§1.2) and every
song timestamp (measure first).*
