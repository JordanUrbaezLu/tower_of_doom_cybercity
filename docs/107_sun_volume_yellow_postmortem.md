# 107 — The yellow tower: the sun volume shrank with the spire (v17.80, 2026-09-05)

## What the player saw

From the first build after 2026-09-05 02:47 (v17.71) every surface in the
tower — walls, floors, the gun, the hands, the zombies — carried a warm
yellow-olive cast. The published v17.58 build (Workshop, 09-04 21:04) did not.
The user's same-spot screenshots (beside the ammo crate against the base's E
wall, round 1, 500 points, before power) show black wall panels and a
neutrally lit gun in the published build, and bright yellow-olive everything
in every dev build, with a warm gradient on the core face 170 units from the
crate — exactly where the base spawn light stands.

## What it was

`tools/gen_tower_map.js` derives `SKY_TOP` as
`max(MAST_TOP, CROWN_TOP, SP_TOP2 + SP_BEACON_H + 64) + 300`. That one number
sizes two things: the sky enclosure brushes and the `volume_sun` brush — the
map-wide sun / light-grid volume (`grid_density 32`).

| build | spire laps | spire term | SKY_TOP | volume_sun top | look |
|---|---|---|---|---|---|
| published v17.58 | 100 | 39,168 | 39,468 | 39,500 | correct |
| v17.69 → v17.78 | 70 | 27,648 (CROWN_TOP 28,896 governs) | 29,196 | 29,228 | yellow |
| v17.79 (floor 39,168) | 70 | pinned | 39,468 | 39,500 | correct |
| v17.80 bisect (floor 0, fresh `.led`) | 70 | 27,648 | 29,196 | 29,228 | yellow |

With the short volume the engine lit everything with a warm light that
honoured the base lights' POSITIONS (the gradient at the spawn light) but not
their colour (cool white, not yellow) or their lighting state (`lightingstate1
0`: authored OFF before power). That is what default light parameters look
like. The mechanism inside Radiant / the engine is not known; the light-grid
partition of the volume is the likely lane. The rule is empirical and cheap.

The bake's own export file is the fingerprint: every yellow bake wrote
`zm_tower_of_doom.led` at 44,592,07x bytes; the good bake wrote 45,041,494;
the bisect (short volume, `.led` deleted first) wrote 44,592,078 again.

## The fix

`SUN_VOLUME_TOP_MIN = 39168` in the generator, an extra `max()` term under
`SKY_TOP`. The sky seal and the sun volume can never drop below the published
height again; if the geometry ever grows past it, `max()` wins. Ship build =
a standard full build. Nothing else in the map changed.

## What it was not — and the evidence, so nobody re-runs these

| suspect | what was done | result |
|---|---|---|
| the cybercity sky, its exposure | v17.72–v17.74 retunes; v17.78 back to Miami | yellow |
| the fsi (sun-lit fog) | v17.75 `tod_fsi_cybercity`; v17.78 back to `zm_factory_volumetric` | yellow |
| the spawn light | v17.76 cool white; v17.78 back to warm | yellow |
| the sky image / sun colour / all 310 lights | v17.77 red-gelled all three, bake clean, new sky `.iwi` proven | "still yellow" |
| dev flags | peer's flags-off `-GscOnly` (13:17) | yellow, same spot |
| vision / LUT / script grades | neutral + deployed / stock / no live grade call in any script | — |
| shared tools-root GDT drift | only tod_weapon_twins / tod_ui_images / tod_ui.csv changed in the window | — |
| the ssi not resolving | the `.led` embeds acc_ssi_miami_night's pitch 130 / yaw 140 (peer's probe) | resolves |
| the asset DB | `gdtdb /verbose /update`: only the Chaos-PaP duplicate pair errors, everything else processed | — |
| Radiant's ToolsGfx cache | 14,079 entries, none written in the three crash windows, none zero-byte | — |
| memory starvation | pagefile system-managed 29.7 GB, peak use 572 MB; Radiant's 11.2 GB commit fit; a bake with apps closed changed nothing | — |
| the xpak bake fingerprint | published SST 6.7 / probes 29.3 MB vs ours 6.2 / 24.5 — explained by the 100→70 spire alone | withdrawn |
| lighting states | all lights `lightingstate1 0`; `zm_usermap::main` boots state 1; nothing flips it; same as published | — |
| a stale `.led` carried forward | the bisect deleted it and the yellow came back | not it |
| the tools / the host | the control map (`Repositories/test+map`, the Mod Tools ZM template + one neutral vision file) baked clean | not it |

## The control map

`C:\Users\jorda\Repositories\test+map` (own git repo, 11 files): the Mod Tools'
"ZM Mod Level" template minus the perk / PaP / box / power prefabs, a neutral
map-name vision file, `build.ps1` (sync → cod2map64 → Radiant LED, awaited →
linker), `PLAY_TEST_MAP.bat`. It proved the host in one look and stays as the
place to reproduce any future "is it us or the tools" question. Step 2 (one
green omni light, `lightingstate1 0`) is committed and unbuilt.

Two toolchain facts it surfaced on the way: Radiant is a GUI exe, so a
PowerShell call operator returns before the bake finishes and the linker then
prints "Failed to load Lighting Export Data … Falling back to preview
lighting" — `Start-Process -Wait` it; and `gdtdb.exe /flags` must be run from
PowerShell (Git Bash rewrites `/update` into a path).

## Lessons

- **When every direct lever fails, diff the DERIVED numbers.** The cause was
  not a value anyone typed; it was a `max()` whose winner changed when an
  unrelated feature shrank. The generator now prints "ceiling" on every run —
  read it.
- **A control map is one build and settles "us or the tools" in one look.**
  Build it first next time, not sixth.
- **The published build is on disk** (`steamapps\workshop\content\311210\
  3788921059`). Its pack and fastfile are the reference for any "it used to
  look right" question; `node tools/xpak_report.js <xpak>` reads it.
- **Same-spot, same-state screenshots or nothing.** The first useful
  comparison of the day was the one taken beside the crate at round 1.
