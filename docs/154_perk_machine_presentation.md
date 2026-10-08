# Perk machine purchase animations — 2026-09-22

User: Double Tap's cowboy appears but does not shoot; fix broken perk-machine
animations. Damage was explicitly requested. Target behavior is BO6.

## Findings and changes

- Tower already plays the original Double Tap intro/fire/outro clips, Speed
  Cola's power-on/off and idle, and Wisp Tea's activation and idle. These are
  the three animated machines in the installed nine-perk roster. The other
  installed machines have static models. No retired perks were reintroduced.
- The Double Tap port's loop emits `doubleTapFired` on level, but Tower had no
  listener or bullet asset. Its first shot had a sound note but no attack note.
  Three purchase sounds, ten randomized gunshot WAVs, and Wisp's activation
  sound were absent from Tower's sound sources and installed sound_assets.
- Four Tower-owned clips preserve the donor animation binaries and rigs.
  They now contain 16 matching machine-local attack, muzzle-flash and sound
  cues. The listener starts before the fire clip. Shot frames at 30 fps are
  1/8/15/21/24/27/34/35/42/43/49/52/59/61/67/70.
- Shots follow the animated pistol root, beginning at its muzzle. The muzzle has an identity bind rotation while the pistol root
  defines barrel direction. Using the animated root follows the authored
  aim and avoids the donor script's world-origin-relative destination. Muzzle FX use the measured pistol-root offset
  (4.330710, 0, 1.771652) for the same reason.
- The original firing port uses a 10,000-damage projectile at 2,500 units/s
  with a five-second lifetime. Tower uses immediate, occluded bullet traces
  with that damage and maximum travel, avoiding another weapon registration
  at the current ledger guard. This is an explicit BO3 adaptation, not a
  claim that the community port's damage matches retail BO6 numerically.
  The projectile trail is not reproduced by this hitscan implementation.
- Only a living enemy actor struck by the ray takes damage. Walls, players
  and friendly actors block the shot without taking damage. Buyer receives
  attribution; a synchronous damage mark bypasses held-weapon upgrade procs
  while retaining Sprinter armor. The original projectile damage category
  remains usable by stock boss damage handlers.
- Muzzle flashes use the port's three stock muzzle/smoke runners. Eye glow
  follows the sequence and is killed on each clip shutdown, then restarted
  by the next clip. Wisp activation retains its donor effect and now has its
  authored sound. The duplicate Double Tap loop audio cue was removed.
  Donor `FxOnObject@...` strings incorrectly marked as Sound were removed;
  their BO6 door/mouth smoke effects are not included in this donor pack.
- Power/model changes, machine replacement, movement, retirement and world
  upgrade pauses cancel the purchase/shot listener. Disconnected or dead
  buyers cannot cause damage. A 15-second watchdog recovers a missing native
  animation-completion notify (longest finite clip is Speed's 10.7 seconds).

## Files and provenance

WetEgg / SAT, already credited in CREDITS.md. Local sources:
`Downloads/SATPerksCode.7z`, `Downloads/SATPerksAssets (1).7z`, installed
`_custom/_wetegg/models/sat/`. Recovery evidence and extracted donor code are
under `tmp/perk_machine_fix_20260922/`.

`tools/import_perk_machine_presentation.py` vendors only the four needed
clips/rigs, three FX and fourteen WAVs. Its manifest records source/output
hashes. Ordinary builds validate frozen outputs; they do not re-extract or
edit the shared installed vendor GDTs. `tod_perk_machines.csv` is explicitly
included by the map's sound zone. No weapon or clientfield registrations added.

## Verification and user playtest

`tools/test_perk_anims.js` executes the actual GSC state and shot functions
with mocked native calls. It checks direction/ownership, blocked/friendly
hits, dead/disconnected buyers, power/movement/pause/replacement and stopping.
`tools/verify_perk_machine_presentation.py` checks source hashes, finite
clips, all 16 paired cues, note limits, sound/FX references, WAVs and sound
zone inclusion. Both now gate every build. Arity and sound-context lints pass.

Native playback is unverified. The user tests; no agent game launch or input.
In dev mode, `[TOD_PERK_ANIM] INIT rev=2` identifies the build. Expected
Double Tap evidence: BUY, three ANIM_START/ANIM_DONE pairs, 16 SHOT records,
VOLLEY shots=16 expected=16, then BUY_DONE and idle. SHOT reports muzzle,
origin, direction, hit and trace fraction. SHOT_SKIP / BUY_SKIP / CANCEL /
ANIM_TIMEOUT explain interruptions. Wisp should log activation then idle;
Speed should finish power-on and remain animated across machine relocation.

For the user test: buy Double Tap with zombies in front of it; listen for
opening, gunshots and closing, watch both muzzle flashes and zombie damage.
Buy Wisp Tea and check its activation sound/effect. Let a machine relocation
occur and check that it resumes correctly. Archive console with
`tools/capture_ai_logs.ps1` before interpreting the results.

Full build passed 2026-09-22 11:09:30 Eastern. Fastfile: 147,066,944 bytes.
All 373 snapshotted source/deployed inputs match; none were synced after the
fastfile. All four new clips and three FX appear in compiled assetinfo. All
fourteen audio rows and their converted .snd files appear in the generated
alias/asset lists. Loaded audio bank (.sabl): 59,140,608 bytes; streaming bank
(.sabs): 207,523,840 bytes. Ten previously waived asset warnings only.
Evidence: tmp/perk_machine_fix_20260922/build.log, build_inputs.json and
deployment_verification.json. Full build and deployment checks passed;
native visuals, sounds and damage remain for the user's playtest.

## 2026-09-23: Widow's Wine powered panel was the engine's grey stand-in

User screenshot: the powered Widow's Wine machine's whole front panel flat grey,
no "WIDOW'S WINE" sign, no spider crest, no red glow. Cause, read from the
linker's own ledger (`zone_source/all/assetinfo/zm_tower_of_doom.deps`):
`material,mc/sat_zm_machine_y_mod_01_on` -> `techset,mc/missing_techsetdef_geometry`
with image `code_missing_techsetdef`. The pack authored that material on
`lit_emissive_scroll_3layer_advanced_fullspec`, a techsetdef the SAT **code**
archive ships (`share/raw/techsetdefs_stable/geometry_advanced/`) and this
install never had. The linker does not fail on it and writes nothing to the
errorlog; the unpowered model uses a stock type, so the machine only breaks
once powered. Only this material was affected: the ledger's other stand-in users
are the two long-waived stock assets (115 grenade, xmas gun).

The def is the stock `lit_emissive_scroll_3layer_advanced` plus the full-spec
additions (`lit_base_mid` include, a specColorMap slot, the `BASE_SPEC` define)
and names only stock shader sources. Fix: the repo carries it under both
`share/raw/techsetdefs_stable*/geometry_advanced/`, `sync_to_modtools.ps1` copies
them (never mirrors), `verify_perk_machine_presentation.py` pins the hash and
checks both installed copies before the link, and `build_map.ps1` fails any link
whose ledger names `missing_techsetdef` (baseline zero, no waivers). No pack
file, GDT, model or texture was changed; the three-layer look (base emissive +
red-tinted "WIDOW'S WINE" text layer, no scrolling) renders as authored.

Also answered that day: every one of the nine sold machines already wears a
pack model (BO6 `t10_` rips for Juggernog / Speed Cola / Quick Revive /
Stamin-Up / PhD / Death Perception / Double Tap, SAT customs for Widow's Wine
and Wisp Tea); the pack holds no newer set, and every machine animation it
ships for this roster (Speed Cola, Double Tap, Wisp Tea) is wired. The
unwired clips belong to machines the map does not sell (Vulture Aid, Melee
Macchiato, the unidentified `z_mod`).

## 2026-09-23 - The volley never fired (v19.45)

User: the cowboy comes out and looks like he is shooting, but no bullets, no
gunshots, no kills. The user's console (dev build) had the whole cause in two
lines: `ANIM_START clip=tod_doubletap_fire` and `ANIM_DONE` at the SAME
millisecond, then `VOLLEY shots=0 expected=16 hits=0`, while the intro (38
frames, 1.2 s) and outro (151 frames, 5.1 s) ran to length.

**Cause.** The fire clip is the only one carrying script notes: sixteen
"Self Notify" custom notes. A script note in an AnimScripted clip arrives on
the clip's own done-notify with the note as its argument (stock reads clips
with `DoNoteTracks` / `waittillmatch( done, "end" )` for exactly this reason),
so `play()`'s bare `waittill( done )` returned on the frame-1 note, the
sequence started the outro in the same frame (the fire clip was replaced
before a frame of it rendered; the user saw intro + outro), and the shot
listener died on its `endon( "tod_doubletap_loop_done" )` before a
`tod_doubletap_shot` notify could reach it. Because the 73-frame clip never
played, its gunshot sound notes and muzzle-flash notes never fired either. The
2026-09-22 "16 matching machine-local attack cues" claim was a build-artifact
claim; the notes were compiled, never received.

**Fix (script only).** `play()` waits for the note "end" and logs any other
note it receives (`NOTE`); the watchdog endons `tod_perk_anim_clip_over`. The
sixteen traces are now SCHEDULED from the clip's start on its authored frames
(`volley_frames()`, pinned to the importer's SHOTS and the GDT notes by
`verify_perk_machine_presentation.py` and `test_perk_anims.js`), one per frame
at 30 fps, left pistol first then alternating. A shot is levelled at muzzle
height on the pistol root's heading (the xanim_bin shows the barrels pitching
-6..+9 degrees; the donor fired flat). A trace that starts inside a solid
(the stock `zm_collision_perks1` clip, or the gun's own bullet mesh) retries
32 units down the barrel ignoring the clip. `doubletap_note_probe` only
records whether a Self Notify ever reaches script by name.

**Log lines for the next playtest** (`[TOD_PERK_ANIM]`, dev build):
`INIT rev=3 lane=scheduled`, `VOLLEY_START`, sixteen `SHOT n= muzzle= stage=
origin= direction= hit= fraction= victim= hp=before->after`, any `NOTE` /
`SELF_NOTE`, then `VOLLEY shots=16 hits=N`. `ANIM_DONE clip=tod_doubletap_fire`
must now come about 2.4 s after its `ANIM_START`. `hit=1` with the victim's hp
unchanged would point at the damage callback, not the shot lane.

**Facing.** Perk machines front on model +X (scatter, v13.3c) and the pistol
roots point along model +X within 7 degrees at every shot frame, so the
machine's facing and the cowboy's aim agree. The "model faces local -Y"
comment that lived in the shot function was wrong and is gone.

## 2026-09-23 - The cowboy aims (v19.48)

User, after playing v19.45: "I did hear the shots now so that's better", but
no zombie died. The dev log had the whole volley: `VOLLEY_START ... shots=16`,
sixteen `SHOT` lines from 50 ms to 2.35 s after the clip started, `ANIM_DONE
clip=tod_doubletap_fire` 2,450 ms after its `ANIM_START`, then `VOLLEY shots=16
expected=16 hits=0`. Every shot: `hit=0 victim=-1`, direction (0, 1, 0) from a
muzzle at (-360, -942, 15230); fractions 0.77 (shots 1-5: the far wall, 9,600
units out), 0.07 (6-10: something 950 units out) and 1.0 (11-16: out through
the open window band, nothing within 12,500 units). The mechanism was right
and the design was wrong: sixteen traces in ONE fixed level line, and a zombie
is never standing in that line.

**Fix (script only).** `volley_target()` picks the zombie for each shot: live,
within range, within 200 units of the muzzle's height (this deck, not the
flight below), inside the barrel's front fan (70 degrees either side of its
heading), nearest first. A world-only sight line runs from 32 units down the
line (clear of the machine's footprint, ignoring the stock perk clip) to 40
units above the zombie's feet; if it is blocked (fraction under 0.95) the
next-nearest is tried, three candidates per shot. World-only on purpose: a
player standing at the machine never shields the zombie behind them. The
damage call is unchanged (10,000 raw, MOD_PROJECTILE, buyer credited, machine
as inflictor, the `tod_perk_machine_hit` mark keeps held-weapon procs out,
sprinter armor still applies). With nobody in front the shot is the v19.45
level trace, the only lane that can hit a player or a wall. Constants
`TOD_DOUBLE_TAP_AIM_COS / _AIM_Z / _AIM_DZ / _AIM_TRIES / _LOS_FRAC` in
`_tod_perk_anims.gsc`; `test_perk_anims.js` runs the real function bodies
through nearest-pick, dead/behind skips, cover skip, fan / deck / range
limits, the clip ignore and a sixteen-hit volley.

**Proven by the same log:** a "Self Notify" custom note delivers BOTH a note on
the clip's done-notify AND `self notify( <note name>, <param> )` on the
script_model: sixteen `SELF_NOTE muzzle=j_pistol_le/ri_muzzle` lines, one per
`NOTE`, alternating from the left. The scheduled lane stays the owner (it is
gate-tested and fired within 50 ms of every note).

**Log lines for the next playtest** (`[TOD_PERK_ANIM]`, dev build): `INIT
rev=4 lane=aimed`; per shot `SHOT n= muzzle= stage=aimed|level|retry
candidates= dist= struck=actor|player|world hit= fraction= victim=
hp=before->after`; `SHOT_COVER candidate= dist= fraction=` whenever a nearer
zombie was behind cover; `VOLLEY shots=16 hits=N`. With zombies on the deck in
front of the machine expect `stage=aimed hit=1` and `hp` dropping by 10,000 a
shot; a kill leaves that zombie out of the next pick and the next shot names
another victim. `stage=level` on every shot with zombies present means they
were outside the fan, off the deck, or behind cover (read the `SHOT_COVER`
lines).

### Second playtest, same night: the enemy check threw (v19.48b)

User: "I still didn't see him shoot any zombies and there was a bunch in front
of the machine." The log (19:32): `INIT rev=4 lane=aimed`, sixteen `SHOT ...
stage=aimed candidates=1 dist=69..112 struck=actor_spawner_zm_tod_cyber_horde
fraction=1 victim=33|52|45 hit=0`. The aim worked end to end: a zombie 70 to
110 units in front was picked every shot, the sight line reached its chest,
and the victim was named. Then `hit=0`, and between each `SELF_NOTE` and its
`SHOT` line the engine printed two exceptions with `_tod_perk_anims.gsc` on
the stack: `parameter 2 does not exist` and `Object must be an array`.

**Cause.** `enemy_actor()` confirmed a victim by walking `GetAIArray( "axis" )`.
The engine throws on that call (stock calls `GetAIArray()` with no arguments;
its one-argument use is in an MP gadget script that never runs here) and hands
back undefined, so the `foreach` threw the second exception and the function
returned false for a live, sighted zombie. BO3 reports these as script
EXCEPTIONS and continues the thread, which is why the `SHOT` line still
printed and why no earlier playtest had shown it: v19.32's volley never fired,
and v19.45's level traces never reached a zombie, so the check had never run
against a real one. The retired `_tod_thunder_smash.gsc` carries the same call.

**Fix.** `enemy_actor()` walks `GetAITeamArray( level.zombie_team )`, the call
`volley_target()` picks from (proven in the same log). `test_perk_anims.js`
now fails on any `GetAIArray(` in the module and asserts the enemy check reads
the team list; its zombies live on one list for the pick and the check.

**Also in that log, not bugs:** the outro was cut at 2.3 s by `CANCEL
phase=tod_doubletap_outro` because round 5 began and the perk shuffle moved
every machine (`REST` for both machines 0.95 s later) - the documented
stop-before-move contract. Two `assert fail` exceptions in
`archetype_apothicon_fury.gsc` / `animation_state_machine_mocomp.gsc` belong to
the Reaver's stock animation code under developer mode; untouched here.
