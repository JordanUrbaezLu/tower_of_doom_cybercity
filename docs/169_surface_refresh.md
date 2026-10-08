# 169 — The surface refresh + the sky's depth pass (v19.68o, 2026-10-02)

User, 2026-10-02: *"The map looks beautiful already. Are there any small visual
enhancements or updates we can make to the walls floors ceilings etc on either
tower to keep the content improving and fresh. Like a minor redesign. Also any
enhancements in the skybox in terms of depth and atmosphere would be great as
well."* — then *"be prepared to revert cleanly if I don't like some of the
changes"* and *"list out simply what changes you have made and what I should
expect."*

So every piece below is behind its OWN switch, and every switch off reproduces
the map / sky as it was, byte-for-byte (proven, see Evidence).

## What changed in game

### Both towers (map geometry — `tools/gen_tower_map.js`, the REFRESH block near `doorMatOf`)

| switch | what you see | where |
|---|---|---|
| `RF_RISERS` (ON) | the front face of every stair step is now a soft glow with a bright LIGHT LINE through its middle, in the floor's district colour — climbing, the stair ahead is a ladder of light | all 1,600 tower treads (five district colours) + 2,240 spire treads (a hotter spire red) |
| `RF_SOFFITS` (ON) | the UNDERSIDE of every stair and landing (and the strip of each step's back face left showing under the next step) wears the district's PLAIN material — black tiles + a thin grid line, the rails' own look — so looking up the spiral you see a dark gridded ceiling with lit edges instead of one wash of colour | every tower tread + landing; the spire's undersides are plain dark blue (neutral inside every coloured trial hall) |
| `RF_FLOORNUMS` (ON) | a glowing FLOOR NUMBER painted on the floor of every door landing, in the map's own HUD digits, the district colour, reading for a player facing the door | tower floors 1–50, spire floors 1–70 (222 digit decals) |
| `RF_STRINGERS` (OFF) | the outer side edge of each step / landing in the plain material | tried: no visible difference in any preview, left off |

**Nothing else moves:** zero new brushes (the risers and soffits are per-FACE
materials on the brushes that already exist), the floor numbers are
non-colliding decals 1.5 above the floor; no collision, trigger, navmesh, door,
spawn or script change — the four generated gameplay data files
(`_tod_door_data` / `_tod_crown_data` / `_tod_breather_data` / `_tod_spire_data`)
are byte-identical with the refresh on or off. Lit area 1308.0M u² before and
after (`measure_lit_area.js`); world blocks +222 (the decals).

### The sky (`tools/gen_tod_sky.js`, the DEPTH header block)

| `TOD_SKY_SKIP` key | what you see |
|---|---|
| `ceiling` | THE CLOUD CEILING: the two cloud decks used to be painted only BEHIND the city, so a tower taller than the low deck stood crisp in front of the cloud it should vanish into. Every surface above a deck is now seen through that deck at the ray's crossing — towers rise out of the mid city and disappear into the overcast; the far ring's megastructures stand in and out of drifting cloud |
| `underglow` | THE UNDERLIT OVERCAST: each downtown cluster lights the cloud base above it (a soft warm or cool neon pool, strongest over the densest district), so the overcast carries the shape of the city under it |
| `beamhits` | BEAMS MEET THE CLOUD: a searchlight whose foot is under the low deck stops in a lit patch on the cloud base where the deck is thick; a lamp standing inside the deck is dimmed by it and glows in it |
| `plumes` | SMOKE PLUMES: six thin vent plumes off mid-height roofs, leaning down-wind, lit at the foot by the roof's neon |

The world's LIGHT is held: `SKY_GAIN` is solved for `--target-score 0.324` as
before, so the sky picture changed and the light it casts on the tower did not
(gain printed in the build's sky render log, `tmp/visual_refresh_20261002/sky_full_render.log`).

## Tried and dropped

- **Core floor rings** (a thin light ring round the core at every floor line):
  invisible. The column already carries a vertigo grid line every 64 units, so a
  floor-line ring reads as one more grid line (`prev/zoom_ring_spur_up30.png`:
  375 changed pixels in a 960×540 view). Removed whole — code, image and the six
  materials. LESSON: on a vertigo face a thin bright line is camouflage; contrast
  there needs a texture change (grid ↔ fill), not a line.
- **Stringers**: see the table.

## How it works (the non-obvious parts)

- **Per-face materials** — `addBoxFaces(label, ..., tex, faces)` (after
  `addBoxTex`) emits a box whose faces may each carry their own material; with
  every refresh switch off it calls plain `addBox` and consumes no extra guid,
  which is what makes "all off" byte-identical. Face keys: `bottom`, `top`, `s`
  (y1), `e` (x2), `n` (y2), `w` (x1). `treadFaces(riser, back, outer, ...)` /
  `landingFaces(outers, ...)` hold the per-flight orientation (the riser faces
  the LOW end of its flight).
- **The geometry lint classes a brush by its TOP face now** (`lint_tod_geometry.js`
  `parseWorld`): a tread is a DECK because its walking surface is `_tinted`,
  whatever its riser wears — and every other face's material must still be
  known (an unknown material anywhere aborts, as before). The six
  `tod_rf_riser_*` materials are registered BLOCK. The self-test gained two
  cases (every non-top face of 96 treads made BLOCK: the climb still walks; an
  unknown SIDE material: aborts); both fail the pre-refresh lint.
- **The riser cannot be upside down.** The engine's wall V direction is
  unverified on this map (docs/110 left it open), so the riser image is mapped at
  exactly ONE repeat per 12-unit visible riser (`RF_RISER_V` 12 — every tread top
  on both towers is a multiple of 12, asserted) and the image is symmetric top to
  bottom: whichever way V runs, the line lands in the middle of the step.
- **Floor numbers** are chalk-mesh decals cut per digit from a 10-cell atlas
  (`tod_rf_floornum.png`) of the HUD's own digit sheet (fill only, a soft halo in
  the alpha). Each digit is cropped to its own ink (`FLOORNUM_INK`), so "1" does
  not leave a gap in "13". LOCKSTEP: `gen_tod_refresh_assets.py --check` measures
  the atlas ink and FAILS if the generator's crops would cut it. The quad faces up
  by the decal winding rule (normal = u_dir × v_dir; text RIGHT x text UP = +z).
- **The art + materials** live in their own `source_data/tod_refresh.gdt`, written
  by `tools/gen_tod_refresh_assets.py` (2 images, 12 materials): risers are clones
  of `tod_door_blue` (the matte vertigo clone), the floor numbers clones of the
  DOGCANARY decal `arrow_power_coldwar1`. No zone lines — world materials ride
  in through the BSP. **The numbers are pinned steady:** the donor's technique
  (`lit_emissive_scroll_transparent`, technique "lit") compiles
  `USE_EMISSIVE_FLICKER` and the arrow ships flicker range 0..1 (the POWER signs
  carry it); the numbers set `flickerMin` 1 so the range is [1, 1] — constant
  whatever the unshipped shader does with its lookup. The risers' technique
  (`lit_emissive_advanced`) has no flicker at all. Knobs: `RISER_SCALE` 5 / `_SPIRE` 6, `FLOORNUM_SCALE` 8 /
  `_SPIRE` 9, the district tints (the pack's own plain-hue tints).

## Reverting

**One map item:** set its `RF_*` literal to `false` in `tools/gen_tower_map.js`,
`node tools/gen_tower_map.js`, FULL build. All three off = the pre-refresh map,
byte-for-byte (`tmp/visual_refresh_20261002/gen_pair.sh` proves it: it generates
the off/on pair and asserts the gameplay data identical). For an A/B without
editing: `TOD_REFRESH=none|all|risers,soffits,...` in the environment overrides
the literals.

**One sky item:** `TOD_SKY_SKIP=<key>` on a full render (`node tools/gen_tod_sky.js`,
~5 min), then a FULL build. All four keys skipped reproduce the previous previews
pixel-for-pixel (0 of 42 differ). **The whole sky at once:** copy
`tmp/visual_refresh_20261002/baseline/i_skybox_tod_cybercity.exr` (the shipped
2026-09-16 EXR) over `source_data/tod_skybox/_images/i_skybox_tod_cybercity.exr`,
FULL build.

## Evidence

- `tmp/visual_refresh_20261002/` — `baseline/` (every source this pass touched,
  as shipped, + MD5SUMS), `prev/` (before/after renders from player eyes:
  `tools/preview_views.py`, new — renders the generated `.map` with its real
  materials, decals and lights), `sky_before/` / `sky_after/` / `sky_skip/`
  (2048 sky previews), `gen_pair.sh`, `regen_ship.log`, `sky_full_render.log`.
- Map: off `01775ac389ab` (== the repo map before this pass) / on `49d9a2f6c09e`.
- Gates on the shipped map: geometry lint OK (no regression: 0 misplaced walls,
  0 unguarded edges, every route walkable, standable surfaces unchanged
  151756 / 118943), hall-bunker lint OK, the two new self-test cases PASS,
  `gen_tod_refresh_assets.py --check` OK.

## Build

FULL BUILD OK 2026-10-02 03:44:17 Eastern, FF 149,434,560 B — own compile
(d3dbsp 03:33:04) + bake (.led 45,144,894 B, 03:35:48; sun-volume ceiling
39,468). All 12 `tod_rf_*` materials are in the linker's ledger, pulled by the
BSP, with both images; the new sky converted to a fresh content-hash `.iwi`
(22,873,846 B). Geometry / refresh-check / hall-bunker / navmesh (2 components)
gates green; source trees clean, nothing synced after the `.ff`. Log:
`tmp/visual_refresh_20261002/build_full1.log`. UNPLAYED.

## Not verified (the user's look decides)

- In-game brightness of the risers and numbers (the previews model the
  material's tint × scaleRGB, not the engine's bloom) — one knob each, above.
- The sky in game (the preview PNGs cannot show bloom; v18.97's glare lesson).
- Whether a decal's sort order ever loses to the floor at a grazing angle (the
  numbers are 1.5 proud, the POWER signs' recipe at 2).
