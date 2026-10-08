# Elite tracking pauses: diagnostic run, September 10, 2026

Status: captured same-frame world pauses followed by elite stalls; the missing
restore is fixed and covered by an actual-function regression test. Build tag
20260910f passed at 22:44:11 Eastern; native missed-edge restoration is verified.

The user reports Panzer, hound and Protector pauses in the Endless Spire while
other enemies sometimes keep targeting. They requested readable logs before
changing behavior.

## Confirmed failure mechanism: a pause shorter than the elite watcher tick

Final pre-fix capture:
`tmp/elite_tracking/runs/20260910_224229_229_a18a10ca/console_mp.log`.
The earlier snapshot `20260910_223618_543_0f107bfe` contains the same decisive
interval. Exact WORLD fields record both pause edges at **69550 ms**, and
hound 54's STATE records that exact pause-rate write. This hound was moving
hundreds of units before that frame, then remained near (10066,284,0) for
25 seconds despite a valid target and fresh path. No active slow was recorded.
Earlier same-frame pauses occurred at 40550, 44050 and 47550; later ones at
103050, 121550 and 126050. The native completion getter continued to report
`asm_status_running`; generic entity animation rate remained 1. Those getters
therefore did not expose the missed 0.05 playback-rate restoration.

The code path is concrete:

1. `event_scheduler` calls `run_upgrade_event` every dev round from round 2;
   normal mode calls it every fourth round.
2. A maxed player can still be admitted by `dark_allowed() && dark_pool.size > 0`.
   But `roll_options`, with no ordinary domains left, only produces a dark hand
   when `tod_dark_guarantee` is set. With no tier card either, it returns undefined.
3. `set_world_pause(true)` has already written 0.05 onto every live AI.
   `player_choice_flow` immediately decrements the pending count and returns;
   `run_upgrade_event` then calls `set_world_pause(false)` without waiting.
4. That release cleared ignore/frozen flags, but left elite animation restoration
   to `boss_pause_watch`, which polls every 250 ms and only restored if it had
   observed pause=true. Same-frame on/off never satisfies that condition.
5. The regular zombie speed sweep skips these custom-speed elites. An unrelated
   rate writer or a relocation might later mask the defect, causing intermittent
   apparent recovery. Dev mode's extra rounds and maxed loadout expose it often;
   it is not a dev-only restore defect.

The fix latches `tod_elite_pause_pending` on each freeze-rate write to an actor
with a known elite base rate. Its existing watcher restores when that latch is
set even if it missed the pause itself, then clears it. A still-active world
pause keeps precedence; spawn entrances keep ownership; unexpired elite slow
multipliers are retained. This adds no continuously enforced rate and changes
no targets, path goals, spawn positions or geometry. Sprinters retain their
ordinary zombie speed-sweep lane.

`tools/test_elite_pause_restore.js` executes the actual pause writer and watcher
as coroutines. The old condition demonstrably leaves 0.05 indefinitely; the new
condition restores the configured base. It covers same-frame, long and repeated
pauses, Fury park/unpark, entrance ownership, live/expired slows and diagnostic
release timestamps. It runs as a required build check. Final runtime logs add
`PAUSE_RESTORE ... missed_edge=1`, plus pending/resume fields, to verify the
specific repaired path rather than relying on a subjective impression.

Native run e exercised all five families, 412 STATE rows by the first snapshot,
and zero script exceptions. A trial hook on the shared RequestState helper saw
zero requests across those families and was removed; the native ASM completion
getter remains. Do not claim that the recorder reveals the engine's active
animation name. A separate Protector radius=2048 observation and the earlier
first-hall path errors are not proven causes of the captured pause-write stalls;
this fix does not claim to cure every possible stationary actor.

## September 10 follow-up: the user still saw freezes

The user's completed run is archived at
`tmp/elite_tracking/runs/20260910_220944_115_becdbeb5/console_mp.log`.
It contained 20 INVALID_START path errors for entity 40 and one INVALID_END for
entity 33. Entity 40 descended from z=3449.9 to z=2984.9 at approximately 20
units/second near (10063.6,-272). Its family and health were not recorded, so
this is not proof of a living elite falling through a particular brush.
The two `_tod_mage_elements` exceptions were a separate definite defect:
comparing undefined `staff_element(weapon)` to `"lightning"` throws in native
GSC. Both comparisons now guard undefined; the bolt/reload test models that
native boundary instead of silently accepting JavaScript's comparison rules.

**That run had no detailed recorder output.** The launcher omitted
`scr_mod_enable_devblock 1`; developer/logfile alone did not execute the block.
Both launchers now supply the required flag. This requirement is documented by
the [Donut Monitor author](https://github.com/dylanhebert/donut-monitor) and was
then verified locally. The original unwrapped PrintLn startup failure and this
missing launch flag were mistakes in this diagnostic work.

The subsequent instrumented run is archived at
`tmp/elite_tracking/runs/20260910_221904_350_ae4b7edc/console_mp.log`.
It contains 558 ELITE samples across all five families, 364 route samples,
1,752 ordinary-actor samples, and two stock Fury animation assertions.
No `_tod_bosses` diagnostic exception or Mage undefined/lightning exception
appears in that run. The assertions have no native line information; their
exact assertion site is unresolved.

### Concrete stationary hound

Entity 30, first observed at VM time 103150, stayed within eight units of its
spawn sample through 153700: 50,550 ms, including its initial arrival tell.
At 137700 (raw log lines 6490 and 6523-6528):

| Check | Observed |
| --- | --- |
| Hound | HP 5369, (10205.4,-478,1.1), zero velocity, grounded, unlinked |
| Target | Player 0 valid and targetable; NoTarget/ignore/Blood absent |
| Navigation | HasPath=1; path goal near player; last path just 50 ms old; length 255.9 |
| Route | Actual and projected CanPath=1; CanSee=1; chest ray unobstructed |
| Suppression | ignoreall=0, ignoreme=0, pacifist=0; no drop/freeze/park/slow/web/cocoon |
| Engagement | Last incoming hit 8.3 seconds earlier; no outgoing damage stamp |
| Animation | Generic entity rate=1; generic animname/script_animname undefined |

At 154700, raw line 7286 explicitly records `boss stalled ? relocating ... id=30`.
The later position jump therefore **is watchdog relocation, not demonstrated
recovery of normal locomotion**. Shooting it repeatedly resets the watchdog's
quiet timer, which helps explain why that system allows such a long stall.
At later times Zombie Blood legitimately makes the player untargetable; that
does not explain this earlier sample.

There are also long stationary samples for hounds, Protectors and sprinters.
Stationary duration alone cannot distinguish normal attacks from a defect.
This capture establishes a valid-target/valid-path stall; it does not prove
physical hull clearance, internal animation progress, or which agent introduced
its cause. CanPath tests navigation, not actor collision. The generic entity
animation rate is not treated as a definitive ASM playback-rate reading.

### Earlier hypotheses, superseded where noted

Before exact pause timestamps were added, the 500 ms WORLD samples appeared to
show no relevant pause. That was a sampling blind spot: a same-frame pulse was
invisible. The analysis that maxed empty deals always return before pausing was
also incomplete: it missed the dark-pool admission versus dark-guarantee check
above. The final capture and regression test establish the missing restore.

Stock dog targeting was actively updating its path and had seen its target;
refreshing favoriteenemy alone would not fix this rate problem. The generic
animation fields were empty, and GetEntityAnimRate must not be treated as a
reliable measurement of the ASM rate this pause writes.

## Evidence from the current run

Saved the existing game console to `tmp/elite_tracking/console_before.log`.
The game started at 21:12:54 Eastern. Its log contains:

- Repeated native `PATHFIND_FAILURE_UNREACHABLE` errors near the first trial's
  southwest entrance, e.g. entity 60 at `(10054.2,-272.3,3648.4)` at game time
  401379 ms. The same entity later descends below hall level and reports
  `PATHFIND_FAILURE_INVALID_START`. Entity 53 follows a similar pattern.
  **The existing log does not identify their enemy family.** These errors prove
  a path problem occurred, not that every reported elite pause has that cause.
- The player reads `ign=1 valid=0` from sampled game times 448836 through
  460847, then `ign=0 valid=1` at 463848. This is consistent with the existing
  15-second Zombie Blood window. The old probe does not log the blood flag,
  so that attribution remains an inference. It does not explain path failures
  recorded while the player was targetable.
- The compiled navigation check passes: 1070 faces, two connected components,
  one per tower. The game's existing flight probe reports 0/420 misses. These
  checks do not establish reachability through the runtime trial seal or prove
  that an actor has remained on the mesh.

Recent relevant changes are the September 10 hall shell/spawn work (docs/128),
the added southeast upper-landing exclusion, and the room/platform rebuild
(docs/130). No culprit is confirmed. The texture size pass and HUD fixes did
not edit AI behavior. Dev mode uses the normal elite cadence; the test harness
opens doors and warps between hubs, and normal upgrade pauses still apply.

## Recorder (schema 2, build tag 20260910f)

`_tod_bosses.gsc::dev_ai_watch` starts under the existing `level.tod_dev`
flag. It samples changes every 500 ms and logs full context every two seconds.
`GetAISpeciesArray("all", "all")` explicitly includes dogs and robots: the
ModTools API documents human as the default when species is omitted.
Ordinary actors are logged too, to identify native error IDs and provide moving
comparison cases. The recorder itself writes only `tod_ai_diag_*` bookkeeping. The separate
restore fix uses `tod_elite_pause_pending` and restores the intended animation
rate; goals, targets, collision and spawn positions are unchanged.

Lines start with `[TOD_AI] ms=<game time>`:

| Record | Contents |
| --- | --- |
| START | Schema, build tag, scan/detail interval and species coverage. Require this before trusting that the recorder ran. |
| WORLD | Round, dev/god/open-door flags, spire/trial/hub, trial door seal, frenzy, upgrade pause, stock world pause, teleport stamp, rampage and exact last pause-on/off timestamps. Logs changes between heartbeats. |
| PLAYER | Entity ID, position, normal validity, validity honoring ignoreme, native NoTarget, ignore flag/count, AI ignore counter, Zombie Blood flag/time, session state, HP, last valid navigation position and nearby mesh. Logs targetability changes between heartbeats. |
| APPEAR | First observation: ID, time, family, position, species, archetype and team. |
| ACTOR / ELITE | ID and first-seen time, family, position, sampled stationary duration, HP, HasPath, favorite/enemy IDs, ignore/pacifist/find-flesh suppression, freeze/drop/park/spawn flags, slow/web/cocoon. Elites also report native entity animation rate and script state. Changes emit between heartbeats. |
| NAV | Elite navigation projection, trial containment, actual goal/radius, native path mode, path start/end, current path length, path-wait and last-path fields. |
| MOTION | Velocity, on-ground status, linked parent, movement type, previous script state/reason, animation name/scale and gun-wall blocking. |
| STATE | Native ASM completion status, exact last pause-rate-write/resume times and pending restore; intended base animation rate, king/guard, drop/slow expiry ages, damage received/dealt ages; Panzer flame/octobomb and ignored-player list, Fury travel/pain/furious fields, hound last target position/seen state, target/goal override presence. |
| PROBE / ROUTE | Brackets the read-only queries; native errors inside this interval may come from the diagnostic rather than the normal goal driver. Each elite to every living player, even players currently ignored: distance/height delta, CanPath at actual positions and mesh projections, CanSee and static chest-height ray fraction/hit position. Once per heartbeat. |
| GONE | ID, first-seen time, last position and removal observation: dead, removed, or slot reused. |
| EVENT | Existing spawn/recovery diagnostics; stuck relocation and abandoned-drop recovery include ID. Spire gate ConnectPaths/DisconnectPaths calls log action, entity, targetname and position. |
| TICK | Observed sample gap/cost and live/total actor counts, elite count, configured AI/actor limits. Detects missing heartbeats or broad stalls. |

`-` means undefined; undefined entity IDs are -1. `born_ms` is **first observed**
time, not the exact spawn callback, and disambiguates reused slots. `still_ms`
measures time without eight units of accumulated displacement from a sample
anchor. Firing and scripted entrances can legitimately be stationary. A negative
`eslow_age` means time remains before expiry. Nearby mesh is a projection; the
separate CanPath results test route existence. CanSee and a static ray answer
visibility questions, not reachability. The entity animation-rate getter is not
assumed to expose every internal ASM transition.

No diagnostic sets goals, invokes target override callbacks, or requests an
approximate path: the latter API explicitly clears an actor's current path.
Read-only route queries add work, so inspect TICK gaps as well as the actors.
The logger is dev-only. Sub-500 ms transitions and actors that spawn and vanish
between scans can be missed. `GONE removed` does not assert the deletion cause.
The native pathfinder's own error lines remain essential evidence.

Output uses server `PrintLn` inside the required `/# ... #/` developer block.
The first native check rejected the earlier unwrapped call at line 520 even
though the linker accepted it. That startup error was introduced by this
diagnostic work; the wrapper is corrected. Both launchers now set developer 1,
logfile 2 and scr_mod_enable_devblock 1. Build c emitted body records with a
missing prefix because constants assembled inside the devblock were blank.
Build f assembles the whole string outside that block; the capture helper also
recognizes the earlier prefixless format. No HUD prints or duplicate stream.

## Capture and interpretation

`tools/run_game.ps1` and `PLAY_NORMAL.bat` now run `tools/capture_ai_logs.ps1` before launch. It
archives the existing raw log without overwriting earlier captures under
`tmp/elite_tracking/runs/<timestamp>_<id>/`, plus a numbered diagnostic extract
and a capture manifest. The raw log is authoritative. The helper can also be
run while playing; it uses a shared read handle and a live capture can end
mid-line. Launching directly through Steam bypasses this preservation hook.

Source log:
`C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\console_mp.log`

Match the same entity ID **and first-seen lifetime** across ELITE, NAV, STATE,
ROUTE, EVENT and native PATHFIND_FAILURE records. Compare to PLAYER and WORLD
at the same game time and to ordinary actors still moving nearby. In particular:

- Invalid/NoTarget/ignore/Blood explains eligibility; compare each co-op player.
- Raw route failure with a successful projected route suggests endpoint trouble;
  both failing suggests disconnection or an unsuitable projection.
- Below-floor coordinates, no nearby mesh, downward velocity and INVALID_START
  identify actors leaving the walkable region; first-seen position and gate
  events help locate when that happened.
- A valid target and route with persistent ignoreall/low rate/drop/park flags
  suggests a state-restoration problem. Flame, travel and damage ages separate
  expected attack behavior from unexplained inactivity.
- A GONE/APPEAR pair distinguishes replacement from recovery; a relocation or
  drop-janitor EVENT identifies the existing watchdog acting.

No single field proves the cause. Keep the raw error and surrounding timeline.

## Validation

- Actual-function elite pause regression test passes and is a build gate. The
  Mage bolt/reload comparison test passes, with an explicit native undefined
  comparison boundary and negative control.
- All earlier diagnostic getters, including ASMGetStatus, ran across all five
  families. Prefix and devblock output verified in native build e, with no
  script exceptions through the recorded interval.
- Archive helper preserves raw bytes, uses unique folders, recognizes both
  record formats and retains native errors. Source hashes describe capture
  time, not necessarily the historical fastfile which produced a log.
- Geometry reused from the external session's completed 21:53 full build.
  No geometry edit here. The failed startup is preserved separately in
  runs/20260910_215642_733_ccebd012.
- Build f passed all required gates at 22:44:11 Eastern; FF 176,322,176 bytes.
  All 1,533 snapshot/source/deployed input checks and complete-tree/freshness
  checks passed before launch. A subsequent HoldMs addition affects only the
  non-packed window helper; all deployed inputs were rechecked unchanged.
- Native proof is archived at runs/20260910_224853_099_384014b1. START matches
  tag f. Pause on/off=118050; hound 41 and Protector 42 log PAUSE_RESTORE
  missed_edge=1 at 118100 (50 ms later). Hound position advances after release;
  Protector advances from (9896.3,-208.7,0.1) to (9889.6,-63.3,1.1).
  A further same-frame pause at 143050 yields seven restores at 143100-143200.
  Nine restores total in that snapshot; all five families sampled; zero native
  script exceptions. This validates the specific missed-restore correction,
  not every possible cause of a stationary actor.
- Game left running for the user's retest. Persistent focus/capture/click and
  held-Space confirmation tools were used successfully; docs/132 records them.
