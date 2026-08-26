# Zombie Blood removal snapshot (v12.5, 2026-08-26)

> **STATUS: REVERTED in v12.6 (same day).** The user tested the removal, the
> tint verdict was inconclusive ("maybe it's just my eyes"), and these five
> files were wholesale-restored (safe because zero intervening edits landed
> between the snapshot and the restore). Zombie Blood is LIVE again, in the
> debugged v12.3 state these files preserve. This directory is now purely
> historical.

The user's tint-isolation experiment: Zombie Blood was COMPLETELY removed from
the game — no code mentions or references — so a test run can prove whether the
permanent orange tint has anything to do with it. (The actual root cause was
diagnosed and fixed separately in v12.4: the missing map-name vision file. The
expectation is therefore that the tint is gone WITH OR WITHOUT zombie blood,
and the planned re-add is what closes the case.)

## What this directory is

Byte-exact copies of every file the removal touched, taken IMMEDIATELY BEFORE
the removal edits (i.e. these files still contain zombie blood, in its final,
fully-debugged v12.3 state: tray timer + refcount-safe clear + scoped laststand
guard + keep-alive loop):

- `_tod_powerups.gsc`   — define TOD_BLOOD_SECS, the __init__ registration
  block, and the four functions (grab_zombie_blood / zombie_blood_window /
  zombie_blood_laststand_guard / zombie_blood_clear)
- `_tod_powerups.csc`   — the include+add pair with the "tod_zombie_blood"
  clientfield arg (MUST return together with the gsc add's trailing three
  args, or the toplayer clientfield registration mismatches at load)
- `AetheriumPowerupsContainer.lua` — the tray row
- `zm_tower_of_doom.zone` — `xmodel,zombie_blood`, `material,zombie_blood`,
  `image,i_tod_pu2_zombie_blood` (+ their comments)
- `_tod_endless_rounds.gsc` — only a comment reword (the focus-picker
  rationale named Zombie Blood)

Deliberately NOT touched by the removal (so nothing here to restore):
`source_data/nsz_zombie_blood.gdt`, `source_data/tod_ui_images.gdt` (the
i_tod_pu2_zombie_blood entry), `sound/aliases/tod_ui.csv` (zombie_blood_vox)
and the NSZ wavs — data files whose assets simply stop being referenced/packed.
Leaving them is what makes this revert a pure code restore with a -GscOnly
build and no sound-bank or GDT risk.

## How to revert (bring Zombie Blood back)

1. Diff each backup file against its live counterpart and restore ONLY the
   blood-related hunks (other code will have moved on — do NOT wholesale-copy
   these files over the live ones unless the revert happens immediately after
   v12.5 with no intervening edits).
2. `node tools/lint_tod_arity.js`
3. `.\tools\build_map.ps1 -GscOnly` (all five files are linker-side)
4. Verify with the diff gate (`diff -rq scripts <modtools>/usermaps/...`).

This directory is under docs/, which the sync script does not ship.
