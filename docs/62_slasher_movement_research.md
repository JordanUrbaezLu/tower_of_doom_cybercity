# 59 — Slasher movement: slide → jump momentum (v16.1 research record)

**Status 2026-09-02: v16.1/v16.2 WERE PLAYED (in the v16.21 armed harness) and
the verdict was "speed boosts when you jump out of a slide" — see §9 for the
cause (the script carry itself) and the v16.23 rebuild (momentum preserved at
every edge, never added, plus AIR STEERING). v16.23 WAS PLAYED ("its for sure
comical. But we know its possible"); v16.24 (§9.7: the MOMENTUM CONE, the rate
ladder walked back to 180..420 deg/s, and the answer to "poll every 10ms") was
superseded before it was played by v16.28 (§9.8: the fresh-eyes review — strafe-
only steering, the front hemisphere free, press-gated edges, the edge rule
demoted to clamp insurance). v16.28 WAS PLAYED: "when jumping out of my slide
im launching" — and §9.9 (v16.31) is the finding that `jump_max_velocity` is
the engine's slide-jump LAUNCH speed, plus the JUST-IN-TIME rule that makes it
per-player. v16.31 WAS PLAYED ("still kinda launching. I think it got better
tho ... there should be a max steer limit") — §9.10 (v16.33): the steer budget,
the eased rate, and the cap pre-armed against a poisoned session rest value.
v16.34 adds an EXPERIMENTAL WALL-RUN for athletes (§9.11: the engine's own,
gated per player with AllowWallRun); v16.38 adds its per-level LADDER (seven
wallRun_* dvars, pristine × mult(level), exposure-free) and settles the pause
text. v16.38 is BUILT, NOT YET PLAYED.** The engine dvar defaults this doc says to
read have still not been read by anyone. Fill in §7 after the first dev test;
§9.5, §9.8 and §9.9 list the trace fields.

## 1. The ask

User, after playing v16 in the armed dev build:

> "the velocity of a character is clunky when running and sliding and jump. With
> this ability you get a slide speed boost but typically players will slide and
> jump. That slide speed boost never transfers momentum properly to the jump so
> you slow down a ton. Basically the ask here is to make the player experience
> as smooth as possible with the Slasher class."

and of map 1 (Abandoned Cyber City), whose `_acc_movement.gsc` v16 was a port of:

> "Now I wouldn't call it smooth. Still very clunky. But that may be a good
> point of reference. Don't only use that cause it's not that good. We should
> think from a new lens and perspective to make ours perfect."

## 2. The engine's own account of a slide-jump

BO3 ships a `slide_*` / `jump_*` dvar family. Names and descriptions below are
Treyarch's own, recovered from the string table in `<tools>\bin\cod2map64.exe`
(the description sits immediately before each name; extraction script in the
session scratchpad, 82 names matched). **Default values are NOT in that table**
and are not in any file on this box — the retail exe hashes dvar names. They
are printed by `tod_athlete::dev_print_movement_dvars()` in every dev build.

| dvar | Treyarch's description | why it matters here |
|---|---|---|
| `jump_max_velocity` | The max velocity of the players jump if they enter it from a slide | **THE ROOT CLAMP.** Registered in retail (T7Overcharged hash list `0x7EAE1BD8`). |
| `jump_slowdownEnable` | Slow player movement after jumping | the landing stumble; stock ZM disables it only in `scr_oldschool` (`zm/gametypes/_globallogic.gsc:191`) |
| `jump_height` | The maximum height of a player's jump | global; `SetJumpHeight()` writes it for ALL players |
| `slide_speedBase` / `slide_speed` / `slide_speedReduced` | The slide start speed if no player energy / … / … | ZM disables player energy (`_zm.gsc:220`) → the slide starts at an ENGINE CONSTANT, not at sprint speed |
| `slide_maxTimeBase` / `slide_maxTime` / `slide_maxTimeReduced` | The max time in ms the player is allowed to slide for (base / — / reduced) | the slide's timer gate |
| `slide_min_continue_velocity` | Required speed a player must sliding to continue sliding | the slide's speed gate — a faster start = a longer slide |
| `slide_friction_amount` / `_uphillFriction_amount` / `_downhillFriction_amount` | The amount of friction to apply while sliding (…uphill / …downhill) | this map is 100 flights of 20.6° ramps |
| `slide_outSpeedScale` | Scale down your movement speed by this when exiting a slide | the crawl out of a slide |
| `slide_outShouldScaleSpeed` | Scale down your movement speed during the slide out | ditto, the switch |
| `slide_outAllowSprint` | Allow sprinting during the slide out | whether you can go straight back to sprint |
| `slide_friction_duration_ms` | The amount of time over which friction will be added back in | the engine's OWN release ramp after a slide |
| `slide_to_sprint_friction_time_scale` | Scales the duration of the friction exit time when heading back to a sprint from a slide | |
| `slide_subsequentSlideTime` / `slide_subsequentSlideScale` | The time (ms) in which a player starts another slide, their speed will be reduced / Percent the slide speed should be scaled down by per subsequent slide | the chained-slide penalty |
| `slide_delayTime` | The time the player must wait before starting another slide | |
| `slide_min_sprint_time_ms` | Minimum time a player must be sprinting to slide | the delay before you can slide after landing and re-sprinting |
| `slide_min_required_velocity` | Required speed a player must be moving to trigger a slide | |
| `slide_enable_tweak_left_right` / `slide_deadzoneTweek` | Allow the player to adjust their velocity to the left/right while sliding / threshold | steering (map 1 set it to 1) |
| `slide_angle1` / `slide_angle2` | sin of the slope angle: up to angle1 the player must initiate; in {angle1, angle2} the slide auto-triggers | sin(20.556°) = 0.351 — docs/39 §3.5's auto-slide hypothesis, still unmeasured |
| `slide_hold_change_stance_time_air_ms` / `slide_min_required_airVelocity` / `slide_required_airAngle` | hold slide in air to trigger a slide when landing / required air speed / required angle | land-into-slide exists in the engine |
| `player_sprintSpeedScale` / `player_sprintMinTime` / `sprint_rampIn` | sprint scale / min sprint time to start sprinting / time for the sprint scale to fully ramp in | the run half of the loop |
| `friction` | (no description) | the classic ground friction that bleeds a fast landing |

## 3. Script API facts (mod tools `docs_modtools/bo3_scriptapifunctions.htm`)

Per-player: `SetVelocity`, `GetVelocity`, `IsOnGround`, `IsSliding` ("Returns true
if the player is sliding"), **`IsOnSlide`** ("Return true if the player is in the
player movement slide" — a SECOND builtin, zero stock consumers, relation to
`IsSliding` unknown; the trace reports it at slide end), `IsSprinting`,
`IsMantling`, `SetMoveSpeedScale`, `AllowSlide/AllowJump/AllowSprint` (booleans),
`SetStance`, `JumpButtonPressed`, `GetNormalizedMovement` (EXISTS — map 1's docs
claimed it did not), `SetSprintDuration`, **`SetPlayerGravity` /
`ClearPlayerGravity` / `GetPlayerGravity`** (per-player gravity override — the
movement-levers memory said no per-player jump lever existed; corrected).
Global only: `SetJumpHeight` ("all players"), `SetGravity`.

Stock idioms: `_zm_jump_pad.gsc:491-495` makes a velocity write stick on the
ground by re-asserting `SetVelocity` every server frame for the flight. Stock
sets movement dvars from server GSC with no cheat gate (`_zm.gsc:218-224`).

## 4. Why v16 (and map 1) stayed clunky — structural, not tuning

1. **The engine clamps the launch on the client, at frame rate, before script
   runs.** A 20 Hz server script can only correct one server frame later. That
   correction is a prediction error for the client — the dip-then-jerk.
2. **The braked-player floor bailed on the strong case.** `restore_speed()`
   refused to act when the current speed was under half the recorded slide
   speed — precisely what a hard clamp on a boosted slide produces. From
   about Lv3 the carry never fired. "Never transfers momentum" was literal.
3. **"+10% slide speed" rode `SetMoveSpeedScale`,** which scales input-driven
   movement. The engine's slide starts at a constant (`slide_speedBase`) and
   is not input-driven, so that lane could not honestly be slide speed. What
   the user felt as the slide boost was the v16 kick (+50 u/s/Lv), which
   over-paid the spec at high levels and was a second lane for one number.
4. Map 1 additionally held/decayed the scale after the slide (rejected as
   "ice") and never read the dvar defaults it was scaling.

## 5. The v16.1 design (`_tod_athlete.gsc`, header has the full rationale)

| lane | scope | what | why only it can |
|---|---|---|---|
| 1 | ENGINE, global | `jump_max_velocity` → 1000, probe-first absolute SetDvar | removes the clamp at the source; zero latency; client-predicted |
| 2 | script, per player | slide start: horizontal velocity × (1 + 0.10·Lv), one-shot, wall 800 | exact spec on the engine's own start speed; composes with SPRINT/Stamin-Up by construction |
| 3 | script, per player | carry: no floor on a DIRECT slide-jump (≤150 ms since last sliding tick), 3 airborne re-asserts; floor kept on the stand-up path | belt to lane 1's braces; correct if lane 1 is unregistered or unreplicated |
| — | script, per player | jump z × sqrt(1 + 0.25·Lv), gated to the engine's launch band vz 10..400 | unchanged; velocity beats gravity for snappiness (T ~ v vs T ~ 1/g) |
| 1b | ENGINE, global | `jump_slowdownEnable 0` behind `TOD_MOVE_LAND_STUMBLE_OFF` | v16.1 shipped it OFF; v16.2 turned it ON on the user's steer ("forward velocity after sliding and jumping") — the landing stumble is a forward-speed loss on every jump landing; Treyarch's own ZM old-school write |

**Lane 1 is global.** A non-athlete's slide-jump keeps its speed too. What is
ATHLETE-only is the magnitude (faster slide, higher jump, the carry). That is
the stated trade: smoothness at the root over exclusivity of preservation.

**Co-op replication** of engine movement dvars is inferred from stock's own
`doublejump_enabled` / `wallrun_enabled` writes (they must reach clients for ZM
to work) — not proven. Test in co-op; the tell is non-host rubber-banding on
every slide-jump. Note lane 3 has the same replication shape (a server velocity
write is always a prediction correction for a remote client), so lane 1 is
never worse than what v16 already did.

## 6. What the dev build prints (tod_dev was DISARMED in v16.5 — re-arm to read these)

- Map start, after the sprint-dvar lines: `dvar <name> = <value> (was X)` for
  the 14 dvars in §2 that matter most. The first map load of a Steam session
  shows the engine defaults; `<UNREGISTERED>` on `jump_max_velocity` means
  lane 1 was skipped.
- Per slide: `ATH slide eng=E set=S next=N end=Z Tms onslide@end=B`.
  `N ≈ S` → the lane-2 write sticks. `N ≈ E` → the engine re-derives slide
  speed each frame and lane 2 must become a per-tick additive delta (never a
  per-tick multiply — that compounds). `B` answers the `IsOnSlide` question.
- Per slide-jump: `ATH jump direct|standup|none carry=C launch=B>A vz=V
  minair=M air=Nt land=L +300ms=P`. `B` is what the engine launched at (the
  clamp if lane 1 is off), `A` after the restore, `M` the worst airborne speed,
  `P` vs `L` the landing-stumble number.

## 7. Fill in after the first test

| question | answer |
|---|---|
| `jump_max_velocity` default ("was") | |
| `slide_speedBase`, `slide_maxTimeBase`, `slide_min_continue_velocity` | |
| `slide_outSpeedScale` / `slide_outAllowSprint` / `slide_subsequentSlideScale` | |
| `jump_slowdownEnable` default | |
| lane-2 write sticks? (`next` vs `set`) | |
| direct slide-jump: `launch B>A` — did the engine still clamp with lane 1 on? | |
| landing: `land L` vs `+300ms P` — is there a stumble worth `TOD_MOVE_LAND_STUMBLE_OFF`? | |
| `onslide@end` — does `IsOnSlide()` cover the slide-out? | |
| Lv5 `set` capped by the 800 wall? | |
| co-op: non-host rubber-banding on slide-jumps? | |

## 8. Not done, deliberately

- No `slide_out*` / `slide_subsequent*` / `sprint_rampIn` writes: global, and
  their defaults are unknown until §7 is filled in.
- No `SetPlayerGravity` use: it is the floaty-jump lever, not the higher-jump lever.
- No `IsOnSlide` in logic, only in the trace, until its meaning is measured.
- The sprint-slide auto-trigger on the stair ramps (docs/39 §3.5) is still an
  open hypothesis; `ATH slide` lines appearing while merely sprinting down a
  flight would confirm it.

## 9. v16.23 (2026-09-02) — the boost was script, and AIR STEERING

**Status: BUILT `-GscOnly` 2026-09-02, NOT YET PLAYED.** The user played
v16.21 (the armed spire harness, ATHLETE Lv5 by `dev_grant_maxed`):

> "athlete is not so smooth. It kind of speed boosts when you jump out of a
> slide which is exactly the issue I was worried about. It also needs more
> aerial handling meaning you can keep velocity but change directions in the
> air very very easily. And that handling increases with each level."

> "The air handling should be comical for now. Like you are air steering and
> flying thats how crazy. We should be able to tweak after but I want us to get
> comical just so i can see the actual differences. Smoothness should not be
> comical. Unless you can make it comically smooth."

### 9.1 Where the boost came from (no dev numbers needed)

Read `_tod_athlete.gsc` v16.1 as a list of what each write can DO, not what it
was FOR: lane 1 lifts the engine clamp; lane 3 then (a) scales a grounded
player back UP to the slide's last speed when the jump button is down inside a
500 ms window after the slide, and (b) on the jump edge restores to that speed
raise-only, plus three raise-only airborne re-asserts. With the clamp gone,
lane 3 has nothing left to restore — every remaining action it can take is a
speed INCREASE, and it fires one server frame after the launch. A player who
let the slide end, lost speed on the stand-up frames (`slide_outSpeedScale`)
and jumped was re-accelerated to full slide speed *at* the jump. That is the
reported symptom, verbatim. The v16 changelog even asked "do slide-jumps
compound?" of the kick and cleared the carry because it "only puts back what
THIS slide had" — true, and beside the point: putting back speed the player
had already SHED is a boost from where they are.

**Rule for the KB: a correction lane must be able to CUT as well as RAISE, or
it is a boost lane with a nicer name.** The whole carry (grace window, top-up,
floor, re-asserts, `restore_speed`) is gone.

### 9.2 The v16.23 lanes

| lane | scope | what | why |
|---|---|---|---|
| 1 | ENGINE, global | unchanged: `jump_max_velocity` 1000, `jump_slowdownEnable` 0 | the only zero-latency fix for the clamp |
| 2 | script, per player | slide start: velocity = BASE × (1 + 0.10·Lv), raise-only, one-shot. BASE = the engine's own start speed on a CLEAN entry (previous tick ≤ `TOD_ATH_CLEAN_ENTRY` 440), remembered as the reference; on a fast entry BASE = the reference | bounded at REF × (1+0.10·Lv) whether the engine assigns `slide_speedBase` or carries the entry speed into the slide; v16.1 multiplied whatever the engine started at |
| 3 | script, per player | jump edge: launch must be within ±`TOD_ATH_EDGE_TOL` (0.15) of the last grounded tick's speed; outside the band that speed is written back (below = clamp, above = boost); inside, NOTHING is written | the launch stays the engine's own client-predicted one; the band absorbs ≤50 ms of ground friction |
| 4 | script, per player | AIR STEERING: every airborne tick, rotate the velocity heading toward the movement stick by ≤ `TOD_ATH_AIR_TURN_PER_LV` × Lv × 0.05 s (360/720/1080/1440/1800 deg/s = 18..90° per frame), magnitude untouched | "keep velocity, change direction", comical by request; the ladder is the knob |
| — | script, per player | jump z × sqrt(1 + 0.25·Lv), unchanged | |

One `SetVelocity` per tick at most: the lanes edit the same output vector.

### 9.3 Why the steering is a server rotation (the client-predicted lane is dead)

The engine's own air accelerate is driven by the move-speed scale
(`SetMoveSpeedScale` → the playerstate speed the client predicts with), so an
airborne ×5..×10 scale would give smooth, client-side steering. It also drives
GROUND acceleration, and it is still in force on the landing frames until the
server sees the landing (≤50 ms, i.e. up to three client frames). Ground
accelerate at ×10 wishspeed for three frames is a ~1000 u/s lurch toward the
stick on every landing. There is no way to time the restore from a 20 Hz
script. Dead lane — do not re-research. `doubleJump_accel` / `doubleJump_speed`
("Player's doubleJump horizontal allowable acceleration/speed") exist in the
table but belong to the disabled `doublejump_enabled` system.

The rotation is a 20 Hz correction. The client's prediction-error smoothing
hides it at low rates; at the comical top (90°/frame) it will show as a kink
per server frame. The user chose comical first; `TOD_ATH_AIR_TURN_PER_LV` is
the one number to walk back.

### 9.4 Input facts

`GetNormalizedMovement()` is the LEFT stick / WASD, normalized: the API lists it
beside `GetNormalizedCameraMovement()` (example var `v_stick`), and the
2026-08-21 card-focus experiment flipped focus per tick with the player's
velocity pinned to ~0 by menu_freeze — a velocity-derived read would have been
zero. `[0]` is forward, `[1]` is right on the class-draft evidence; that sign
has never been verified on its own (the menus now ride action buttons), so
`TOD_ATH_AIR_RIGHT_SIGN` exists and the jump trace prints `stick=F,R` with the
largest turn step.

### 9.5 What to read in the next dev test (tod_dev is ARMED in v16.21+)

- `ATH slide eng=E set=S next=N end=Z Tms clean=C ref=R` — `E` constant across
  slides means the engine assigns `slide_speedBase`; `E` ≈ the landing speed
  after a hop means it carries entry speed (and lane 2's reference rule is
  what keeps the chain bounded). `N ≈ S` proves the write sticks.
- `ATH jump slide|run pre=P launch=B>A vz=V minair=M air=Nt turn=T/Smax
  stick=F,R land=L +300ms=Q` — `B == A` means the momentum rule wrote nothing
  (the engine launch was already right); `B < A` by more than 15% means lane 1
  is not clamp-free on this host; `T` is the heading change the steering
  delivered, `Smax` the largest single step (should read ≤ 90 at Lv5), `F,R`
  the stick at that step (×10). If pushing LEFT turns you RIGHT, flip
  `TOD_ATH_AIR_RIGHT_SIGN`.
- `minair` below `A` by more than a few units with the stick centred means
  something else cuts airborne speed — nothing in this file does any more.

### 9.6 Still open

- §7 is still empty: no dev-build numbers have been read by anyone.
- Height: the ≤50 ms-late vz step is the one remaining script discontinuity in
  the loop. `SetPlayerGravity` after launch is the smooth alternative (floaty by
  the full height factor) if the user asks for hang time — "flying".
- Co-op: every airborne steering tick is a prediction correction for a remote
  client; the tell is non-host slashers rubber-banding in the air.

### 9.7 v16.24 (2026-09-02) — THE MOMENTUM CONE, the rate walked back, and "poll every 10 ms"

User, after playing v16.23: *"its for sure comical. But we know its possible.
Now its about smoothing it out and making it make sense. I would say they
should be able to keep max momentum up to 120 degrees in front of them. And we
need to poll every 10ms for smoothness. Yeah issue right now is that i can
slide and then go backwards max speed. Obviously that doesnt make sense. So we
can tweak it while keeping it fun and slight exaggeration on physics."*

**What v16.23 proved in play:** the stick read is live input, the left/right
sign is right (no complaint), the rotation lane works, and 90° per server
frame is a visible zigzag.

**"Poll every 10 ms" is not available, and this is the record of why:**
`shared.gsh:264 #define SERVER_FRAME .05` — every script `wait` rounds up to the
server frame; the T7 API doc has no `waitframe`-style builtin; Treyarch's dvar
table (the same string-table extraction as §2) has no server tick-rate dvar.
The client DOES carry `cg_errorDecay` ("Decay for predicted error"), the
smoothing that hides server corrections, but it is a client dvar and T7 has no
`SetClientDvar`. So smoothness is STEP SIZE PER FRAME, and the ladder was walked
back from the comical 360/Lv to `TOD_ATH_AIR_TURN_BASE 120 +
TOD_ATH_AIR_TURN_PER_LV 60` per level = 180/240/300/360/420 deg/s = 9..21° per
frame, scaled by the stick magnitude (analog: a gentle push is a gentle curve).

**THE CONE (`air_retain`):** every air episode is ANCHORED on the heading and
speed it began with — the first airborne tick, i.e. a jump after the edge rule
has run, or a ledge drop. Deviation of the CURRENT heading from the anchor
decides the cap on the launch speed:

| deviation | 0..60° | 90° | 120° | 150° | 180° |
|---|---|---|---|---|---|
| speed kept | 100% | 84% | 68% | 51% | 35% |

- the cap ONLY FALLS inside an episode: speed shed in a turn is not refunded by
  turning back (energy lost stays lost);
- never under `TOD_ATH_AIR_CAP_FLOOR` 200 u/s (walking pace), so the engine's
  own air control can still steer a standing jump somewhere;
- the engine's own small airborne additions are trimmed to the cap as well —
  "keep velocity" means exactly that;
- a speed jump past cap × `TOD_ATH_AIR_REANCHOR` 1.25 in one tick is an
  external impulse (boss fling, knockback): the episode re-anchors on it, it is
  never fought;
- the anchor is reset by any grounded tick.

The cone is measured against the LAUNCH heading, not the view: a slide-jump
then a 180° look-and-push is a 180° momentum reversal (35% kept), while a 45°
bank while looking anywhere is inside the cone (100%). The view-relative
reading would have kept the exact nonsense case the user reported.

**Trace additions:** the jump line now ends `dev=D keep=K%` — the widest
deviation from the launch heading and the momentum the cone left.

**Not done:** the ≤50 ms-late vz step on the jump edge is still the one
script discontinuity in the loop (see §9.6). `TOD_ATH_AIR_REVERSE_KEEP` 0.35 and
the 60-deg half-cone are the two "make sense" numbers to retune from feel.

### 9.8 v16.28 (2026-09-02) — the fresh-eyes review and the six fixes

User: *"Okay so we have all the optimizations possible on this system? Shall we
think more about what we did and if it makes sense? Maybe fresh eyes."* Then,
on the decisions: *"Do what ever players would find intuitive and a bit beyond
that to make it fun."*

An independent reviewer (a subagent with no context on the session's
reasoning) read `_tod_athlete.gsc` v16.24 cold and returned eleven findings.
Verified against the code and the generator; six became changes, one was
rejected on evidence, the rest are measurements.

| # | finding | verdict | v16.28 |
|---|---|---|---|
| 1 | the ±15% edge rule still refunds lost speed: `pre` is ≤50 ms old, landing friction bleeds ~20%/50 ms, so a late-in-tick hop is boosted one frame after launch | **bug, confirmed by the header's own numbers** | restore only on a SLIDE-jump whose launch is >40% under the slide speed (`TOD_ATH_EDGE_CLAMP`); the "boost cut" branch is gone (no live impulse source exists) |
| 2 | a bunny hop with ground contact between two server frames is invisible: no height, stale cone anchor | bug | air→air with vz rising by `TOD_ATH_HOP_DVZ` is an edge ("hop") |
| 3 | a ramp-crest hop while sprinting up a 20.6° flight may read as a jump (vz ≈ +141 in the launch band) and get the height pop | unmeasured; CoD's ground snap probably prevents it | a jump edge now needs a jump press inside `TOD_ATH_JUMP_LATCH_MS`; a press-less edge is traced **"nojump"** — that line IS the measurement |
| 4 | ±60° taxes the spiral's 90° landing turn 16% per landing | feel, agreed | cone = the front hemisphere (`TOD_ATH_AIR_CONE_DEG` 180) |
| 5 | holding W and looking around IS steering, and the cap never refunds — a glance at a zombie past 60° docks speed for the flight | feel, the important one | FORWARD/BACK NEVER STEER (`TOD_ATH_AIR_STEER_FWD` 0): the strafe axis steers, relative to the view; the ratchet is gone |
| 6 | holding S swings the line through sideways at 84% before it points back — off the side of a flight | feel, agreed | falls out of 5: S no longer steers, the engine's own weak air control brakes as it always did |
| 7 | a write on essentially every airborne tick (0.05° threshold); co-op rubber-band tell | nit / co-op | 3° deadband (`TOD_ATH_AIR_DEADBAND`) |
| 8 | a mantle ending airborne re-arms the edge from `was_ground = true` | narrow bug | the guard leaves `was_ground` false; the press gate covers it too |
| 9 | the clean-entry / `slide_ref` machinery rests on one unmeasured fact (does the engine carry entry speed into a slide?) | simplification | kept; ONE `ATH slide eng=` reading across a sprint slide and a landing slide deletes it if `eng` is constant |
| 10 | the re-anchor rule guards an impulse no live code produces (`rp_knockback` has zero callers; the lunge is retired) | simplification | kept, three lines, so a future knockback is not silently trimmed |
| 11 | "the height ladder crosses the 56-unit spiral parapet at Lv2" | **rejected** | every lap rail on the tower (gen_tower_map 1905-1919) and the spire (5229-5486) carries a `RAIL_CAP_H` 112 clip cap: barrier 168 vs a Lv5 apex of 88 |

**Why "aiming must not move you" outranks "fly where you look":** the full
stick in the view frame is the standard FPS air-control model, and it is what
v16.23/24 shipped. In a horde game the dominant mid-air input is *hold forward,
turn around, shoot the thing chasing you*. Under the full-stick model that
input is a request to fly back into the horde, delivered at 21°/frame. The
strafe axis is unambiguous: push left, curve left of where you look. The old
model is one flag away (`TOD_ATH_AIR_STEER_FWD 1`) if the user misses it.

**Why the hemisphere and no ratchet:** the reversal case the user reported
(180°) still bleeds to 35%; a U-turn taken as successive strafes passes 90°
free, 120° at 78%, 150° at 57%. Trimmed speed was never refunded anyway (the
lanes only ever copy or cut a magnitude), so the ratchet only ever punished a
glance; dropping it makes the cap a pure function of where you are pointing.

**What the next dev session should read** (all lines print bold on screen):
`ATH jump nojump ...` while sprinting UP a flight = the crest hop is real and
the press gate is earning its keep; `ATH slide eng=` across a sprint slide vs a
land-into-slide; `next=` vs `set=`; any `ATH slide` while sprinting DOWN a
flight without crouching (the auto-slide hypothesis, docs/39 §3.5); `launch=B>A`
with B<A on a slide-jump = the clamp insurance fired, i.e. lane 1 is not
clamp-free on that host.

**Still not done:** the ≤50 ms-late vz step on the jump edge (gravity-after-
launch is the smooth-but-floaty alternative); the client-predicted air-control
experiment (airborne move-speed scale + a trace-predicted early restore before
the landing frames) is an analysis, not a measurement — one dev jump decides it.

### 9.9 v16.31 (2026-09-02) — the launch was the ENGINE; the just-in-time rule

User, after playing v16.28: *"When jumping out of my slide im launching. We
need a creative way to keep the speed of the player throught the slide jump
with calculations or something."* Then: *"Still feels like i slide then jump
and my jump is launching me in the direction. Like its a stutter step and
randomly gain speed idk how to describe."* And, to be clear: *"this really
only needs to apply to players with athlete. I have no complains about how it
works without athlete ... All these changes are for the athlete upgrade."*

**The diagnosis, from the complaint pattern alone:**

| build | `jump_max_velocity` | script at the edge | the user's words |
|---|---|---|---|
| v16 | engine default | restore (bailed) | "you slow down a ton" |
| v16.21 | 1000 | top-up + raise-only restore | "kind of speed boosts" |
| v16.23/24 | 1000 | exact-set, cut one frame late | (no launch complaint) |
| v16.28 | 1000 | cut removed | "launching … stutter step … randomly gain speed" |

The dvar is not a clamp on the slider's own speed. It is the speed the engine
**launches** a slide-jump at, capped by the dvar (an assignment or a cap on the
engine's own boost — the new `jmv=` vs `launch=` trace fields tell which). At
the default the launch was below the athlete's boosted slide; at 1000 it was a
rocket; a script that cuts it one frame later is the stutter. Treyarch's table
has no separate boost dvar (checked: every `jump_*` / `slide_*` name mentioning
jump, boost, launch, velocity or speed — §2 and this section are the full list).
"Randomly" = a jump straight out of the slide launches, a jump after the
stand-up frames does not (the engine treats that as a normal jump).

**THE JUST-IN-TIME RULE** (`jit_update`, the arbiter; `jit_publish` from the
watcher): a global movement dvar becomes per-player if it is written from the
one player who is in the state that consumes it, on every frame of that state,
and rested otherwise. A slide-jump can only happen while sliding, so every
sliding tick of an athlete publishes:

- `jump_max_velocity` = that player's current horizontal speed (post-lane-2, so
  the first tick's multiply is already in it, and decaying with the slide);
- `jump_height` = the engine's base height × (1 + 0.25·Lv) — the HEIGHT
  directly, no sqrt, the engine derives the velocity;

and the first non-sliding tick publishes zeros. The stumble
(`jump_slowdownEnable`) is off while any athlete is airborne. The arbiter takes
the MAX over everyone currently in the state and writes only on change. When
nobody is in the state, every dvar rests at the engine's **pristine** default.

Consequences:

- a jump straight out of a slide has **zero script writes**: the engine
  launches at the slide speed and the level's height, client-predicted, at
  frame rate. The vz multiply survives only for run / stand-up / hop jumps;
- the other three classes get **stock** slide-jumps and the stock landing
  stumble again — v16.1/v16.2 had changed both for the whole map and nobody
  but the slasher was ever tested;
- co-op exposure = a non-athlete slide-jumping inside an athlete's slide
  (~0.5 s windows) or landing inside an athlete's flight (~1 s windows) gets
  the athlete's numbers. Accepted and documented; the script cannot see them;
- the edge insurance (slide-jumps only: cut above +15%, restore below −40%)
  is kept to be MEASURED — `launch=B>A` with B == A is the success signature.

**Pristine capture:** dvars persist across map loads within a Steam session,
so the value read at init may be our own previous write. The first init of a
session stores the live value in `tod_ath_orig_jmv` / `_jh` / `_js`; later
inits read those. A session that already ran v16.1..v16.28 captures 1000 for
the launch cap — the dev print prints `pristine=` and a bold POISONED warning;
restart the game once and it captures the real default.

**Trace:** the jump line now carries `jmv=J jh=H` (the values in force at the
launch). On a `slide` line: `B == P == J` is the lane working; `B == J != P`
means the dvar is an assignment and `pre` was a tick stale; `B >> J` means the
dvar is not in force on this host (the insurance then cuts — the stutter).

### 9.10 v16.33 (2026-09-02) — the steer budget, the eased rate, and the pre-armed cap

User, after playing v16.31: *"Still not super smooth you should be able to
change direction as much. here should be a max steer limit. Also still kinda
launching. I think it got better tho."*

**The steer budget.** The heading may leave the line the air episode began on
by at most `TOD_ATH_AIR_STEER_MAX_BASE` 20 + `TOD_ATH_AIR_STEER_MAX_PER_LV` 8
per level = 28/36/44/52/60°, in either direction, per jump (a bunny hop is a
new episode with a fresh budget). The rate is halved to `TOD_ATH_AIR_TURN_BASE`
90 + `TOD_ATH_AIR_TURN_PER_LV` 30 per level = 120..240 deg/s = 6..12° per
server frame, and EASED: a frame never closes more than `TOD_ATH_AIR_EASE`
0.6 of the remaining gap, so the last degrees arrive in shrinking steps
instead of a snap. The momentum cone (§9.7/§9.8) never bites under a 60°
budget and stays as the safety net.

**The residual launch, diagnosed.** The just-in-time cap (§9.9) is written on
the first SLIDING tick the server sees — up to 50 ms after the slide began on
the client. A slide-hop pressed inside that window launches against the cap
that was in force BEFORE the slide: the rest value. And the rest value was the
"pristine" capture from the first v16.31 init of this game session, which was
1000 — v16.28's own write, still live because dvars persist across map loads
within a game session. So an early slide-hop still launched at up to 1000,
"randomly" (only when the press beat the first server tick), "better" (every
other slide-jump now capped at its slide speed).

Three changes:

1. **Poison refusal.** A captured `jump_max_velocity` ≥ 999 is refused, the
   stored capture is cleared (so a game restart captures the real default),
   and the rest falls back to the engine's own `slide_speedBase` (read from
   the dvar), then `TOD_MOVE_SLIDE_JUMP_FALLBACK` 400.
2. **A session marker.** `tod_ath_jit_written` is set on every init; a later
   map load in the same game session never captures again (the live values
   may be ours). Only a fresh game session captures.
3. **PRE-ARM.** While an athlete is grounded and not sliding, the cap is held
   at the engine's own slide START speed — the player's measured `slide_ref`
   from their last clean slide, else `slide_speedBase`. An early hop then
   launches at exactly the speed it had (the lane-2 multiply had not landed
   either, so "keep the speed" means the base slide speed there). The height
   is NOT pre-armed: `jump_height` would then boost every jump of every
   player while an athlete stands anywhere — the whole-map change the user
   ruled out; the early hop gets the one-frame vz multiply instead.

**Dev print additions:** `jit session FRESH|continued slide_base=`, `pristine=`
now shows -2 for "unknown", and a bold REFUSED line when the 1000 was found.
The user's current game session will show REFUSED until the game is restarted
once; that is expected, and the athlete's slide-jumps are correct either way
(the JIT and pre-arm values do not depend on the rest).

### 9.11 v16.34 (2026-09-02) — WALL-RUN for athletes (experimental)

User: *"Any chance of adding wall running for athlete?"*

**What the engine offers.** Wall-running is BO3's own advanced-movement
feature and lives in the engine, not in script. Stock zombies turns it off with
one line — `SetDvar( "wallrun_enabled", 0 )` at `_zm.gsc:221`, in the same block
that disables double-jump, juke, sprint-leap and player energy. The script API
carries a **per-player** gate, `<player> AllowWallRun( <on off> )` ("Sets
whether the player can wall run"), a server-side `IsWallRunning()`, and a
client-side `IsPlayerWallRunning()`. Treyarch's dvar table has a 60-entry
`wallRun_*` family (this section's extraction): initiation rules
(`wallRun_minJumpHeight` + `_Enable`, `wallRun_peakTest` "Only init wall run if
peak of jump is reached", `wallRun_minTriggerSpeed`, `wallRun_minZVel`,
`wallRun_minVelocityAlignment`), the run (`wallRun_maxTimeMs`,
`wallRun_speedScale`, `wallRun_frictionScale`, `wallRun_minMaintainSpeed`), the
exit (`wallRun_jumpHeight` "jump height to achieve when jumping off a wall",
`wallRun_jumpVelocity` "2D Velocity to push off wall"), combat
(`wallRun_combatEnable`), camera roll/yaw and the viewmodel anim switch.

**The lane (`TOD_ATH_WALLRUN`):**
- `wallrun_enabled` → 1 for the match (probe-first; the master switch);
- every player is DENIED at spawn (`AllowWallRun( false )` in
  `on_player_spawned`, before the watcher's first tick) and the watcher allows
  it only while the ATHLETE level is above 0 (`wallrun_allow`, cached,
  re-applied on every spawn in case stock resets the flag) — so the gate is
  native and per-player, no just-in-time trick and no co-op exposure;
- while `IsWallRunning()` the engine owns movement: the watcher publishes
  "airborne" (the stumble lane), parks lanes 3 and 4, and the tick after the
  run ends starts a fresh air episode with NO edge — the wall-jump is the
  engine's own launch, never multiplied or insured;
- trace: `ATH wallrun Tms in=S out=E` per run; the dev print lists the
  `wallRun_*` family.

**Unknown until played:**
1. Do the MP-tuned initiation rules let a zombies jump attach? MP wall-runs are
   usually entered from a boost-jump; `wallRun_minJumpHeight` / `peakTest` /
   `minTriggerSpeed` may refuse a 39-unit jump. The athlete's 2.25× jump and
   600 u/s slide-jump help. If it refuses, the next lever is a just-in-time
   `wallRun_minJumpHeightEnable 0` / lower `wallRun_minTriggerSpeed` while an
   athlete is airborne (the §9.9 rule).
2. Does the zombies player animation set carry wall-run states? First person
   is camera roll + a viewmodel anim (custom guns will simply lack it); third
   person matters only in co-op.
3. With `playerEnergy_enabled 0`, is the run bounded by `wallRun_maxTimeMs`
   alone? (Probably; the dev print shows the value.)

**Geometry:** every parapet carries a 112 clip cap and every door an
anti-vault clip, so a wall-run cannot leave a flight or pass a shut door. The
core column's flat face along every flight is the natural surface.

**THE LADDER (v16.38 — user: "how can wall running be enhanced at every
level?"):** the §9.9 rule, with a twist that makes it free of co-op exposure:
only athletes can ever be in the wall-run state (`AllowWallRun`), so every
`wallRun_*` dvar can be published while an athlete is AIRBORNE (initiation
happens in the air, and the run itself is airborne) as pristine × mult(the
highest airborne athlete level), rested at pristine otherwise, and no other
player ever feels a scaled value. Seven dvars, three constants:

| dvar | per level | Lv5 |
|---|---|---|
| `wallRun_maxTimeMs` | × (1 + 0.25·Lv) `TOD_ATH_WR_TIME_PER_LV` | 2.25× longer |
| `wallRun_speedScale` | × (1 + 0.05·Lv) `TOD_ATH_WR_SPEED_PER_LV` | +25% along the wall |
| `wallRun_jumpHeight` | **NOT scaled** (v16.53 — see below) | stock |
| `wallRun_jumpVelocity` | × (1 + 0.10·Lv) (the slide ladder) | +50% push-off |
| `wallRun_minTriggerSpeed` / `_minJumpHeight` / `_minMaintainSpeed` | × (1 − 0.08·Lv) `TOD_ATH_WR_EASE_PER_LV`, floor 0.2 | 60%: easier to start and keep |

Pristine values are captured on first sight (`first_ever` — no earlier build
wrote them, so the live value is the engine's own even in a continued game
session) and the dev print lists each with its Lv5 value. The lowered
thresholds are also the best odds of a zombies jump attaching at all.

**Off-the-map risk (v16.53, user: "do we get at risk for slasher players to
jump off the map or get into weird spots? Or do we have invisible walls up at
the barriers and railings").** The geometry: every drop-facing edge on both
towers is a 56 rail + an invisible 112 clip cap (`RAIL_CAP_H`) = 168 above the
deck — lap rails and landings, the spire crate shelves, the teleporter spurs,
the summit apron/plaza/rim/stair, the crown stair, the hub-hall galleries and
the finale road rails (the `rail()` helper emits a cap with every rail); the
lounges are walled with clipped window bands, shut doors carry a 600 anti-vault
clip, the hub drums are 632. Sized against a 39 stock jump; the athlete's 88 is
still well under. The wall-run's two unknowns are the engine's climb along a
wall (`wallRun_maxHeight`) and the jump OFF the wall (`wallRun_jumpHeight`),
whose stock values nobody has read. v16.36's ladder multiplied the wall-jump
height by up to 2.25 — a stock value over ~75 would then clear a parapet — so
v16.50 REMOVED that multiplier (the push-off speed still scales) and added
`wallRun_maxHeight` to the dev print. Weird spots: door lintels (reachable only
once the door's slab clip is gone) and the core's cornices are the plausible
perches; a stock jump reaches neither. If the print ever shows a wall-jump
within reach of 168, the fix is `RAIL_CAP_H` 112 → 256 in the generator (a
full build; invisible to players), never a shorter ladder.

**Pause text settled (v16.38):** val "+N% slide, +M% jump, steer D deg";
act "always on; wall-run: longer, faster, easier per Lv" (the "always on"
convention every passive uses). The CARD (user: "im asking for description
text on the card") carries the title ATHLETE, one generic line, "Unmatched mobility." (the four-beat line was withdrawn as too much text) — numberless by design, a deliberate
exception to docs/40 (which stripped sublines because they carried numbers);
the plate carries ATHLETE only. The brief with the exact copy is in docs/57 and
in `~/Downloads/athlete_assets_v2.zip`.
