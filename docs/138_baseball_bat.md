# Slasher baseball bat

Requested September 14, 2026. Replaces the Slasher's tier-one combat knife with
pmr360's **BOCW Baseball Bat**, downloaded as `BOCW Baseball Bat.zip` (nested RAR).
This is a Cold War port, not a BO6 extraction.

## Contract

- Same tier-one raw damage: 1600 base / 3200 packed; existing backstab, class,
  upgrade, speed-ladder, scoring and promotion code retained.
- Twelve generated forms replace twelve knife forms. The two base registrations
  also replace the knife base registrations. Asset count stays 235 and weapon
  price keys stay 238; retired knife price rows are removed on every generation.
- Bat view/world models, 35 bat clips, conversion skeleton and materials are
  vendored. The port's third-person `sword` stance and held offsets are retained.
  Common jump/fall/walk clips remain the port's existing common dependencies.
- ~~Bat-only lunge: authored charge range 100 and lunge range 130.~~ **REMOVED
  2026-10-02** (user: "remove the lunge on the bat ... [cannot] animate out of the
  lunge if we have a swing ready"): the bat is on the roster-wide no-lunge now
  (meleeChargeRange / meleeLungeRange 0). **THE INSPECT (vm_t9_bat_inspect) is on
  the LOW-READY lane since the same day** - `_tod_bat_inspect.gsc`, reload press ->
  `SetLowReady( true )`, left on any swing (docs/167 items 5 + 6 follow-up).
  Charge timing uses the knife's balance values;
  first raise retains the bat's full presentation duration.
- User's `bathitball.wav` is copied unchanged to
  `sound_assets/tod/baseball_bat/hit.wav` (48 kHz, mono, PCM16, 0.427 seconds).
  Every bat impact alias uses it, with secondary layers removed. This includes
  nonlethal hits and surfaces; the crowd sound is retained only for animation use.
  The archive references missing sledgehammer whoosh aliases and supplies no
  swing WAVs. User supplied two Floraphonic WAVs in `compressed (2).zip`:
  `floraphonic-swing-whoosh-5-198498.wav` and
  `floraphonic-swing-whoosh-weapon-1-189819.wav`. Both are copied unchanged to
  `swing_01.wav` / `swing_02.wav` (48 kHz stereo PCM16, 0.240 / 0.264 seconds).
  Two equally weighted rows under `tod_bat_swing` provide native random selection.
  Native `2D Sound` notes at frame 4 on both empty-swing clips and the lunge
  entry play the swish even without a target. Original rumble notes remain.
  The missing shared whoosh references are cleared to avoid duplicate ownership.
- Only confirmed ordinary-zombie melee deaths launch a ragdoll, once. The
  corpse cleanup death callback uses the actual killing weapon, never the
  attacker's currently held weapon. No damage call, blast, splash or new actor.
  Elites keep their own death sequences. Existing adaptive corpse cleanup stays
  authoritative, including immediate removal under actor pressure.

## Files and verification

`tools/import_baseball_bat.py` imports the extracted pack and custom hit WAV.
`tools/gen_tod_twins.js` owns all generated balance, names, price rows and lunge.
`_tod_corpse_cleanup.gsc::bat_home_run` owns the post-death impulse.
`tools/test_baseball_bat.js` executes the actual death function with native mocks
and checks the twelve generated models/stances/damage/lunge and impact aliases.
It runs on every build. Native verification is required in addition to this test.

Diagnostics run automatically with `tod_dev`: `[TOD_BAT] INIT rev=1`, `LAUNCH`
(victim/player entity numbers, actual weapon, damage mode, impulse) and `SKIP`
(elite death ownership). No per-frame output or gameplay-dependent logging.
Working evidence: `tmp/baseball_bat/`; archived native consoles use the regular
`tools/capture_ai_logs.ps1` workflow.

Class/HUD artwork is being handled separately by the user's art request,
`docs/137_slasher_baseball_bat_art_prompt.md`. Existing blade artwork remains
until that delivery arrives; weapon names and runtime inventory are the bat.

## Status

Full build verified September 14 at 22:34:29 Eastern: FF 149,147,008 bytes;
145 script/UI/zone inputs match deployed and predate the FF. The sound-bank
retry succeeded; ten established waived asset warnings, no new bat errors.
Native launch through Steam, PID 42744. User took over controller input;
agent stopped game inputs. `tmp/baseball_bat/native_play.png` shows the textured
bat in hand and BASEBALL BAT HUD label. Native `[TOD_BAT] INIT` and repeated
`LAUNCH` records confirm actual melee kills at k0 and k1; no script exceptions
observed. User tested and approved the bat: "Also i tested. Its good."
The later swish addition was not in that approved run.
Initial matching-source archive: `tmp/elite_tracking/runs/20260914_223751_890_cc8136d6`.

That test build enabled dev/god and suppressed automatic maxed promotion. The
user questioned the enabled cheats; both flags are now false and the original
maxed harness dispatch is restored. The user closed the match; the normal-mode
script rebuild succeeded (FF 149,147,200 bytes). Cleave's echo now latches the
actual strike weapon and uses the bat hit alias, preserving other blades' echo.
The subsequent full build for the native empty-swing sound notes succeeded
(FF 149,147,072 bytes). A sound-bank relink includes the two supplied whiffs;
dev/god remain OFF. Do not re-enable them for this follow-up test.

Final randomized-whiff relink: September 14 22:49:40 Eastern, FF 149,147,328
bytes, BUILD OK. All 233 checked deployed inputs match source. Script/UI/zone
inputs predate the FF. The two WAVs retain future ZIP timestamps (Sept15 02:44),
but were imported before linking and their deployed hashes match; no post-link
audio edits. Tests cover both distinct WAVs and equal native weights.
Build log: `tmp/baseball_bat/random_whiff_build.log`; hash evidence:
`tmp/baseball_bat/random_whiff_verification.json`.

Random-whiff build loaded natively, PID 20956; desktop capture
`tmp/baseball_bat/whiff_desktop.png` shows the bat and normal HUD (150 HP,
no dev/god indicators). User controlled the Slasher playtest. Sound timing
and both samples were not independently heard by the agent. Final console
archive: `tmp/elite_tracking/runs/20260914_225936_866_40a5e782`. User authorized
closing this match for the subsequent MSMC/Mk 48 build.

## Migration review fixes (September 15)

The other agent repaired the updated fling test harness before this pass; that
work is retained. Swing sampling now accepts primary fire or melee, detects
press edges rather than rearming every held-input tick, clears the prior stamp
before targeting each new press, and resets on death/down/weapon switch.
Freshness consumes its stamp once, including on expiry, so it cannot launch
another victim from a later swipe. Dev-only SWING diagnostics record clearing.
The regression harness executes the actual input prefix and freshness function
to verify both bindings, hold protection, repeat consumption and invalid states.
Native swing classification remains a range/cone heuristic, not an animation
notify; its subjective accuracy still requires a playtest.

The FIRE RATE detail now says MSMC only. MSMC/Mk 48 HUD art remains pending
new artwork; no replacement image exists in the checkout. Another agent was
already building while these source fixes were completed; no competing build
was started. Bat/starter tests and GSC arity checks pass.

## Fling regression rollback (September 15)

User reported that fling stopped after the review changes. The deployed source
contains the review edge gate and consume-on-death logic. Those can suppress
held-fire/repeated swings and multiple deaths in one swing; the mock tests did
not establish native correctness. Backed out both restrictions, retained
primary-fire input support and invalid-state resets, and replaced the added
state tests with held-input/stamp-retention regression checks. Existing random
distance, rare home run and packed bonus are untouched. Range/cone lunge
classification still predates this rollback and remains an unverified
approximation; this is a rollback to test, not a claim that native fling is fixed.
Build/evidence: tmp/bat_fling_regression/.

## Final user direction: all lethal bat swings (September 15)

User explicitly reverted lunge-only fling: "Lets just revert back to all".
Removed the entire inferred-lunge watcher, input stamps and death gate.
Every confirmed ordinary-zombie bat melee death now flings exactly once.
Nonlethal damage, elite exclusions, random distance, packed multiplier and
rare home run are retained. INIT diagnostics are rev=3 all_swings=1.
Tests now require a plain swipe with no input/stamp to launch and assert that
no bat_lunge/ButtonPressed path remains in the corpse module. Build log:
`tmp/bat_fling_regression/all_hits_build.log`.

All-swings build passed September 15 02:21:25 Eastern, FF 149,321,664 bytes.
Deployed corpse script SHA-256 matches source and predates the FF. Launch
through tools/run_game.ps1 did not start BO3 during the observed wait; native
retest is outstanding. Previous console archived at
`tmp/elite_tracking/runs/20260915_022157_479_b8d67876`.
