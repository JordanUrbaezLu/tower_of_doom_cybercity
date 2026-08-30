# spire_wip — THE ENDLESS SPIRE, staged implementation (docs/44)

**NOTHING in this directory is read by any build.** It is the durable parking
lot for the endless-mode implementation while the v13.x publish freeze holds.
Design + research: `docs/44_endless_spire_research.md`. Session: 2026-08-29.

## What is finished and PROVEN (all in a scratch-copy harness, repo untouched)

`gen_tower_map.SPIRE.js` — the full generator with SECTION 6 (THE ENDLESS
SPIRE) added behind `const SPIRE_ENABLED = false`:
- **Byte-identical proof HOLDS**: with the flag false the emitted `.map` is
  SHA256-identical to the pre-spire generator's output, and no
  `_tod_spire_data.gsc` is written. Re-run the proof after ANY edit.
- **Flag true emits**: 7,024 brushes / 572 entities — arrival arena (ruby
  inlay ring, own crate + clip, 4 walls), one-brush core to z=38,400, 100 laps
  of the tower's own stair grammar in monochrome red, gold vendor-hub
  balconies every 10th floor (BR_FURN anchors, crate body clips), railed
  crate SHELVES on floors 5+ (the 190u riser-clearance bump-outs), 100 door
  slabs + anti-bypass clips (NO map triggers — lazy script triggers by
  design), 21 spawn zones + risers + dogs, respawn groups (arena + 10 hubs +
  summit, `script_noteworthy` = owning zone), gold summit (plaza deck over
  the capital, rim rail, apron, beacon mast, exfil mark), ~117 lights, 22
  probes, and the `_tod_spire_data.gsc` emitter (sample: `_tod_spire_data.SAMPLE.gsc`).
- **Geometry lint: PERFECT** — 0 misplaced walls, 0 unguarded edges, 0
  detached spire nodes, `spire arena -> summit walkable: YES`, zero
  regression on every tower/crown/causeway proof.
- Placement x=+10240 fits INSIDE the existing sky seal (asserted); only
  SKY_TOP grows (39,468) and VOL_R (both gated on the flag).
- **Lit area at flag true: 1,328M u² (+18% over 1,125M)** — bake gate decides
  at wiring; mitigation ladder: spire PARA_EVERY 2->4, fewer edge-lit
  landings, darker trims.

`lint_tod_geometry.SPIRE.js` — the lint taught the spire island: own flood
seeded at `spire ground slab`, own `spire arena -> summit` proof, own
detachment bucket gated on increase; spire-from-tower detachment explicitly
NOT gated (teleport-only BY DESIGN). Null fields + byte-identical verdicts on
a map with no spire brushes. **Selftest 10/10 PASS** including CM=-1 parity.

`lint_tod_geometry_selftest.SPIRE.js` — one widened regex (floor-surface
count can be 6 digits once the spire exists; still accepts today's 5).

`tod_music_spire.wav` — the user's Suno track ("Neon Static"), mastered:
48k/16-bit stereo, fade tail cut at 247.2s (15ms anti-click), −8.0 LUFS
integrated (the set's band is −7.8..−9.1). Loop seam = groove into an 8s
intro-build; judge by ear in game. Goes to `sound_assets/tod/music/` at
wiring + alias row `tod_music_spire` in `sound/aliases/tod_ui.csv` (clone the
`tod_ambient_music` row). DO NOT drop into sound_assets during the freeze.

`art/` — the five accepted banners/emblem (audited: text, sizes, transparency
all correct). Install per the images-over-LUI pipeline: PNGs →
`source_data/tod_ui_images/_images/` + image.gdf blocks + 2d_blend material
wrappers (mirror `tod_win_banner`'s pair) + zone lines. **A .gdt change =
FULL build.**

## Port procedure (AFTER the freeze lifts)

1. Diff `gen_tower_map.SPIRE.js` against `tools/gen_tower_map.js` — the delta
   is: the SPIRE constants block (before the sky seal), the SKY_TOP + VOL_R
   max() terms, and SECTION 6 (before the Output stage). Apply; flag stays
   FALSE. Regen → the repo .map must be BYTE-IDENTICAL (prove it).
2. Replace `tools/lint_tod_geometry.js` + selftest with the .SPIRE versions
   (rename), run `node tools/lint_tod_geometry_selftest.js` → 10/10.
3. Flip `SPIRE_ENABLED = true`, regen, lint, **full build**, `_bake_test`
   (BAKED/CRASHED only), `measure_lit_area` A/B.
4. Wire the GSC (`_tod_spire.gsc` — NOT WRITTEN YET; contracts in docs/44):
   choice state in `_tod_finale` (replace auto-`depart()`), atmosphere latch
   release + single-band swap, grant (perks/domains/T3), teardown ("the tower
   dies behind you"), lazy door-trigger + crate window, scatter pad-pool
   swap, spire spawn filter (riser gating above highest bought door +
   `tod_spire_active` hot pacing), zonemgr adjacency for the 22 zones,
   summit extraction, screens. Zone line in `.zone` LAST.
