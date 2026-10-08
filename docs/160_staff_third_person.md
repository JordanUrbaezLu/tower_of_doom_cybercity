# Staff third-person repair and dev Mage preview

> **SUPERSEDED IN PART 2026-09-27: see [docs/161](161_staff_third_person_origins.md).** The staffs now use
> Treyarch's Origins staff player clips (`playerAnimType armminigun`, mount `tag_weapon_right`), which
> already ship in zm_common. The bow pose below is the documented one-edit fallback.

2026-09-23. User reports all three Mage staffs look correct in first person,
but other players see an incorrect hold. User also requested a dev-only extra
Mage to inspect the co-op view. Native visual acceptance is still pending.

## Repair

`tools/staff_presentation_bindings.py` is the source of presentation overrides;
refresh with that tool, then `node tools/gen_tod_twins.js`. All three source
weapons and all eight generated `_zm` variants now use `playerAnimType=bow`.
The existing `tag_weapon_left` mount is retained. This is the stock upright
bow pose as a conservative fallback, **not** an import of Origins torso clips.
The 29 `pt_` clips recorded as undelivered in docs/114 remain undelivered.
Firing/reloading/movement and the aesthetic fit of this stock pose need a
native co-op look; a compiling GDT is not proof of a good pose.

Evidence from the installed primary assets:

- `wpn_t7_zmb_bow.gdt`: stock elemental bows use `rocketlauncher`, `bow`,
  `tag_weapon_left`. The donor `sla_staff.gdt` retained the same mount but
  replaced the pose with `default`. That incompatible pairing was inherited
  by every Tower staff. The earlier suspicion that a left mount alone was
  wrong was too strong: the mount must be assessed together with the pose.
- Decoded world models: both stock bow and staff have identity `tag_weapon`
  roots and their long axis along local Z. The bow spans Z -25.96..30.68;
  the Origins shaft spans -24.29..47.65. The ice world body was deliberately
  built into the same upright frame.
- Fire/lightning base world heads had **blank** `attachWorldModelTag1` and
  zero offsets. Their separate head models extend along local X; the shaft's
  `tag_tip` at Z 47.860935 supplies the needed position and quarter-turn.
  Those base heads now attach to `tag_tip`, matching their PaP replacements.
  Ice keeps its correct `tag_barrel_attach` in both forms.
- `deffiles/projectileweapon.awi` lists `bow` as a supported player animation
  type. `gamedata/playeranim/playeranimtypes.txt` includes it and has no staff
  entry. No global player animation table or weapon class was changed.

The per-weapon field diff is limited to `playerAnimType` and (fire/lightning
only) `attachWorldModelTag1`. First-person clips/models, view tags, weapon
stats, timing, projectile behavior, PaP state and names are unchanged. Keep
the Origins **view** tag empty: the accepted view clips position the head
themselves (docs/117). Do not copy the world-tag fix into the view field.

## Dev preview

`_tod_dev_mage.gsc` creates one real `AddTestClient()` after the real class
draft and initial upgrade pause. Stock Zombies calls that API in
`share/raw/scripts/zm/_zm.gsc::zbot_spawn`; stock shared bots demonstrate
`BotTakeManualControl`, `BotSetMoveMagnitude`, `BotReleaseButtons` and
`BotDropClient`. A public mirror of that primary source is
[Treyarch's Zombies script](https://github.com/zeroy99/bo3_modtools/blob/master/scripts/zm/_zm.gsc).

`level.tod_dev` automatically starts one dummy; there is no separate level
toggle and no console command is needed. Normal builds never create the
client, and the existing publish gate rejects armed dev mode.
The dummy arrives on nearby clear navmesh,
faces the host, uses the real Mage class body, stands still, ignores enemies,
and has invulnerability. It automatically cycles every 12 seconds:

| Slot | Staff |
| --- | --- |
| 1 | Lightning, base |
| 2 | Fire, base |
| 3 | Ice, base |
| 4 | Lightning, packed |
| 5 | Fire, packed |
| 6 | Ice, packed |

Optional developer console controls after it appears (not required to use it):

- `tod_mage_dummy_slot 1` through `6`: hold a particular form for inspection.
- `tod_mage_dummy_slot 0`: resume automatic cycling.
- `tod_mage_dummy 0`: disconnect the dummy. Restart the match to create it again.

It is a real player slot, so the session reports two players and stock
player-count rules apply while it is present. This is a local appearance
test, not a network latency/desync test or a combat bot. It does not fire or
walk. `_tod_upgrades::run_upgrade_event` excludes only this marked dev dummy
from card choices; it cannot hold a deal open waiting for input. Its own
weapon changes pause during upgrade events. No human loadout is rewritten.

Creation refuses a full four-player lobby and uncleared placement. Spawn
readiness is bounded to 30 seconds and requires completed player initialization
plus 1.5 continuous seconds in the playing state. An initialized spectator
returns through stock `zm::spectator_respawn_player`, only for the marked test
client, up to three attempts spaced at least three seconds apart. Placement
is recalculated near the host after this wait. Failure drops the allocated test client,
and disabling the dvar, disconnecting the host or losing the dummy cleans it
up. One owned reference prevents duplicates. Match end destroys the session.

## Diagnostics and validation

`[TOD_MAGE_DUMMY]`: INIT rev=2 automatic=1, ADD, WAIT (state/alive/initialized/
levels/respawn), RESPAWN (attempt), READY, SHOW (resolved weapon/form), FAIL,
STOP and REMOVE. READY requires a settled playing state.
`[TOD_STAFF_PAP]`: existing actual root/tier/attachment proof now also carries
`world_rev=1 cfg_pose=bow cfg_hand=left cfg_socket=...`. The `cfg_` labels are
the intended configuration, **not** a readback of the rendered player pose.
Logs use the existing dev PrintLn pattern and are quiet outside dev mode.

- Existing staff gate: all 78 accepted clips, eight variants, combat/timing,
  ice port and PaP assets pass unchanged.
- `check_world_assembly` validates compatible pose/mount, base vs packed world
  socket agreement, and accepted view tags on all forms. Nine negative
  controls reject the original pose/socket faults and a wrong-hand regression.
- `test_dev_mage.js` executes the actual GSC controller with native mocks:
  disabled flags, full lobby, allocation failure, spawn timeout, all six
  forms, inventory replacement, pinned selection, card pause, disable and
  host-disconnect cleanup. Runs in the build's staff validation stage.
- Source backup, build snapshot, stage logs and deployment proof live in
  `tmp/staff_third_person_20260923/`. No game launch is authorized or performed.

FULL BUILD OK 2026-09-23 19:58:39 Eastern, FF 147,408,192 bytes. All 385
snapshot inputs match current/deployed sources; scripts/UI/zone trees are
identical and no inputs were synced after the FF. All eight staff variants,
PaP assets and the new dummy script are in the linked ledger. Sound banks
68,465,920 / 207,523,840 bytes. Ten established waived asset errors only;
zero materials on missing techsetdefs. At that build, native visuals and
test-client startup were **UNPLAYED**; the first user test is recorded below.
Dev/god/maxed/quiet flags remained armed. No agent launch.

## First user test: automatic spawn immediately removed (v19.49b)

The archived native log in
`tmp/staff_dummy_spawn_20260923/20260923_201219_997_b7afa0a2/console_mp.log`
proves automatic creation worked: ADD player=1 at 36250 ms, playing with
150 HP at 36500, all three class staffs granted at 36750, **spectator** with
150 HP at 37000, then READY and REMOVE at the same 37500 ms. No SHOW ran.
The old controller accepted the first transient playing state, waited one
second without rechecking, announced READY for a spectator, and immediately
disconnected it at the display loop's readiness guard. No console input was
missing; the bot never stayed visible long enough to inspect.

The new readiness helper handles that late-join transition through the
stock spectator-return API. `_zm.gsc::spectators_respawn` uses the same
per-player helper normally between rounds; `_zm_gametype::onSpawnPlayer`
routes initialized players through the stock respawn callback. We neither
write sessionstate nor override the global late-join rules. The helper may
install the standard stock `level.custom_spawnPlayer` callback when unset,
exactly as a normal between-round respawn does; an existing callback survives.
The additional level toggle was removed so dev mode alone enables the test.

The source-executing test reproduces the exact playing-to-spectator timing:
old code emits READY then disconnects with zero staffs displayed; new code
performs one stock return and stays to display the staff. It also covers
failed-return retry limits, setup cancellation, automatic startup without an
extra flag, and no READY announcement for an unsettled client. Arity passes.
The game was running at capture; source work proceeded without rebuilding.
Build started only after the BlackOps3 process exited. Native retest pending.

The first follow-up build was rejected: the linker could not create five
asset-report/localization output files, and the output subdirectories were
absent afterward. The snapshot also changed during this attempt (a peer's
`_tod_upgrade_ui.gsc` burn-number update). Its complete logs and snapshot are
preserved in `tmp/staff_dummy_spawn_20260923/failed_build_1/`; a fresh script
build takes a new snapshot including that update. No failed-build success claim.

Retry **-GscOnly BUILD OK** 2026-09-23 20:24:02 Eastern, FF 147,409,600 bytes.
All 385 snapshotted inputs stayed unchanged and match deployed files, the
scripts/UI/zone trees match, and no inputs were synced after the FF. Dummy
script and all staff assets linked. Loaded/streaming banks are 68,465,920 /
207,523,840 bytes. Ten established waived asset errors only, zero materials
on missing shaders, all 111 weapon models linked, native geometry gates pass.
Evidence: `build.log`, `stage_linker.log`, `verify_build.log` and
`deployment_verification.json` under `tmp/staff_dummy_spawn_20260923/`.
The automatic-spawn correction remains unplayed until the user's next test.
