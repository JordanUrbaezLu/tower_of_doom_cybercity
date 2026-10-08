# 104 — THE CYBERCITY SKY (v17.71, 2026-09-05)

> **STATUS 2026-09-16 (v19.19): SMOOTH SOLIDS — Tower II's v0.7 profile-solid
> pass ported (user: "not everything is so blocky ... more sharp").**
> `drawSolid` / `addSolid` in `tools/gen_tod_sky.js`: a cross-section as a
> function of height, marched per column and solved analytically (circle or
> rectangle) with fractional column coverage. Masts are round tapers, every
> setback is a sloped band, the ziggurat is faceted, and the city gained round
> towers (a fifth of the lattice), pyramid crowns, round mega-drums, arcology
> domes and twin spires. `drawBox` untouched. Bisect: `TOD_SKY_SKIP=round,
> crown,slope`. A non-finite `d` now throws in both `addBox` and `addSolid`
> (the first cut's NaN scrambled the painter sort for the whole city).
> v19.19b (same day): the paint row uses the EXACT height and each z-sample paints its near-edge row only — full-res crops had shown dashed floor rings and a comb fringe at every round foot. FULL BUILD VERIFIED 2026-09-16 15:52:27 Eastern, FF 149,684,992 B; fresh sky .iwi; deployed EXR = repo's; diffs clean. UNPLAYED.
>
> **STATUS 2026-09-05 (v17.87): DEPTH PASS BUILT, UNPLAYED.** The generator was
> rewritten round an atmospheric-perspective model (§4f): fills and edges fade
> toward the sky with distance, a far ring of megastructures stands over the
> near lattice, a light-pollution dome follows the skyline, two cloud decks on
> real planes, two black holes of different designs that lens the sky behind
> them, ring highways, holo panels, searchlights. Asset name, GDT, zone line and
> material unchanged; the body-clearance and seam checks print on every run.
>
> **STATUS 2026-09-05 (v17.81): LIVE AGAIN.** Back on `skybox_tod_cybercity` /
> `tod_ssi_cybercity` (user: *"Looks good. Lets implement"*) after the yellow
> cast was traced to the SUN VOLUME height (docs/107, fixed v17.80 — it was
> never the sky). v17.78–v17.80 ran the Miami pair for the A/B. The fsi
> (`zm_factory_volumetric`), the warm spawn light and the null light tint
> stay at their published values: the only change from v17.80 is the sky
> image plus its ssi clone. Back to Miami = flip `SKYBOX_MODEL`/`SSI` in the
> generator plus the zone xmodel line, always as a pair. UNPLAYED as built.

User: *"So im looking for a better background for the map like an actual
cyber city instead of miami. I thought for sure there would be one online
somewhere."* — then, on the findings: *"Yeah if we can make something sick
ourselves that would be great."*

HISTORY: **v17.71 PLAYED ("Looks awesome"); v17.72 NIGHT + taller skyline PLAYED ("Great"); v17.73 DETAIL PASS; v17.74 exposure `SKY_GAIN` 0.06 → 0.025 (the sky is a LIGHT source, §4b — 0.06 lit the world too bright); v17.78–v17.80 Miami for the yellow A/B; v17.81 back.** Themes: `--theme night` (default) / `sunset`.

## 1. What was found (six-lane research, 13 agents, 2026-09-05 01:21–01:52)

- **There is no cyber-city / synthwave skybox for BO3 anywhere.** The
  community's whole released sky catalogue is five packs (T9/Cold War by
  Nastian — the one we shipped; BO6 Zombies; PBR; BO2; Extra BO3), all rips of
  real-game skies or photographic HDRIs. Poly Haven: 993 HDRIs, none stylised.
- **On this machine there are 24 buildable skyboxes, not ~117** (a name-grep
  over `"skyboxmodel"` values counted references, not assets). Every one was
  converted to PNG and looked at: nine daytime, six near-black nights, one
  alpine sunset, two with a city — Miami (ours) and Moscow (photographic,
  grass foreground). None neon.
- **The reference screenshots were AI restyles of THIS map** — the user's
  friend confirmed it the same night ("I'm prompting ai for some ideas and
  forcing it to not change the tower and the UI"). No asset existed behind
  them.
- **Every BO3 sky is one image on one mesh.** All 16 Nastian skies and the
  stock ones share `t6_props\vista\skybox\t6_skybox.xmodel_bin` (13,495 B, a
  2011 Treyarch export) and differ only by a `skinOverride` onto a
  `materialType "sky_latlong_hdr"` material whose `colorMap` is an
  8192×4096 **equirectangular** EXR (2:1 lat-long; `_ft` in the porter's
  names is vestigial, there are no cube faces). Content sits from the zenith
  to ~4° below the horizon; the lower hemisphere is black in every stock sky.
- **The "HDR" skies contain no HDR**: max pixel exactly 1.0, values on a
  1/65535 grid. Miami's horizon luminance peaks ~0.014, upper-hemisphere
  mean 2.8e-3 — the engine's exposure lifts it several stops.
- **Size is a non-issue**: the shipped Miami sky is 33,570,944 B (32.0 MB)
  streamed in the xpak, exactly 8192×4096×1 B, no mips. Any sky at that size
  is byte-neutral; the EXR source size (5.6 MB PIZ vs 256 MB raw for the
  other 15) is irrelevant to the build.
- **The tower has NO fog** (`apply_fog`'s tower branch calls `fog_off()`), so
  the sky is 31–38 % of a level-looking screen for the whole climb and
  52–74 % of the upward view. CLAUDE.md's "dense at street level" fog line
  was stale.
- **The seam tolerance is effectively zero**: Miami's column 0 and column
  8191 agree to 0.06/65535 while columns 400 px apart differ by 222. With
  `clampU/clampV 1` nothing hides a mismatch. That is why the sky is
  PROCEDURAL, not commissioned art: an image generator cannot promise a
  seam; a function of azimuth is periodic by construction.
- **The Nastian pack's own `t9_*` SSIs must NOT be adopted**: they run ev 15 /
  evmin 7 / evmax 14 against `acc_ssi_miami_night`'s ev 6 / evmin 3 / evmax
  3.5 / stops −2.2 (a clone of stock `default_night`). A ~9-EV jump would
  crush the neon look. The new SSI is that block with ONLY `skyboxmodel`
  changed, so the sun rig and the LED bake are untouched.
- A `material,` zone line for a `sky_latlong_hdr` material **breaks the
  build** (map 1, zone :793: the standalone techset compile fails). The
  material rides in transitively through the xmodel; the zone carries ONE
  `xmodel,` line and no ssi line (no .zone on the machine declares an ssi).

## 2. What was built

| piece | where |
|---|---|
| the renderer | `tools/gen_tod_sky.js` — synthwave gradient, haze streaks, star field, chrome scanline SUN, three laser bars, a far ridge, ~1955 wireframe blocks on a street lattice ray-cast per column with real perspective and depth fade, red beacons, a Tron ground grid below the horizon, a bloom pass; seam-checked on every run |
| the asset | `source_data/tod_skybox/_images/i_skybox_tod_cybercity.exr` — 8192×4096 half RGBA, zip16, 20.8 MB (the render writes a 16-bit PNG and ffmpeg converts it; the round trip was proven linear, no gamma) |
| the four GDT blocks | `source_data/tod_skybox.gdt` — `i_skybox_tod_cybercity` (image, HDR semantic, clamp, no mips) → `mtl_skybox_tod_cybercity` (sky_latlong_hdr) → `skybox_tod_cybercity` (stock t6 dome, skinOverride) → `tod_ssi_cybercity` (miami_night clone, skyboxmodel repointed). Written by `--gdt`, cloned from the installed Nastian blocks — never edit `acc_nastian_t9_skyboxes.gdt`, it is shared with map 1 and Tower II |
| the wiring | `SKYBOX_MODEL` / `SSI` in `tools/gen_tower_map.js` (three emission sites: worldspawn `skyboxmodel` + `ssi`, volume_sun `ssi` + `ssi1`); `xmodel,skybox_tod_cybercity` in the zone |
| v17.73 detail | setback tiers, antenna spires + beacons, glyph billboards, window density, ground glow + base reflections, traffic light-trails, three landmarks (ziggurat / gate / floating platform); night sky: nebula, milky way, coloured glinting stars round-on-sphere, cratered haloed moon, aurora |
| previews | `docs/sky_preview/` — the 2048-wide equirect and five 90° rectilinear views (sun, two city sides, up, down) |

## 3. Design notes

- **v17.72 (first in-game feedback):** the eye was 900 above the city plane and
  the skyline sat at the horizon behind the parapets ("I have to jump"); eye
  220 + taller/nearer towers put the tops +10..+25° above level. The "yellow
  hue everywhere" was the sunset bloom (40° gaussian) — gone in both themes;
  NIGHT (moon, indigo, cyan/blue) is the default the user leaned to.

- The city sits on a plane 900 units below the eye and the grid continues
  below the horizon, so from the stairs the sky floor reads as a city far
  below rather than the stock black void. Straight down is still black.
- Hues: cyan 40 %, magenta 26 %, violet 12 %, then orange / gold / red /
  green accents — the tower's own five district colours in the skyline.
- The sun's direction is kept low-rise so the disc stays visible; five
  downtown clusters give the horizon a rhythm as the spiral turns.
- **A lat-long sky has zero parallax** — the city looks the same from floor 1
  and floor 50. The look the restyles reached for also had blocks at
  different depths; that half is docs/64 item 8 (a geometry city ring inside
  the sky seal), the natural NEXT step, deliberately not this one.

## 3b. Line weight — LW

The 2048 previews are BOLDER than a 1-px line at 8192 downsampled 4×, and the
user approved the previews. `LW = 1.0 + 0.9 × PX` (≈1.9 px at 8192) scales
every neon line, edge, ground-grid line and star radius so the shipped sky
matches the preview the decision was made on. Change it, not the per-line
constants.

## 4. THE SKY LIGHTS THE WORLD — skyStops (v17.74, the yellow-world postmortem)

`docs_modtools/SunSky_Light_SetUp.pdf`: *"A sky light is a spherical light
projected into the scene using the sky texture for value and color ...
skyStops is used to adjust the brightness of the sky light"*; the worldspawn
`ssi` *"is what will bake into the reflection probes"*. So the picture IS the
ambient light, and two material keys govern it:

| key | value | meaning |
|---|---|---|
| `skyScaleRGB` | 1097.5 in all 16 pack skies | display multiplier — never touch |
| `skyStops` | Miami 10.0; pack 2–7 | sky-LIGHT gain; the pack keeps image mean × 2^skyStops ≈ 1.3 |

The v17.73 file (mean 3.9e-3) scored ~4.0 on that rule — 3× the pack's
ambient — and every wall, gun and zombie went olive-yellow (dark albedos
under strong light), while the same brightness blew the sky white. v17.74
dropped the FILE (gain 0.025, lower hemisphere ×0.45) to a score of 0.76.
If the world ever needs more or less sky light WITHOUT changing the picture,
edit `skyStops` in `source_data/tod_skybox.gdt` (one stop = 2×; GDT edit =
FULL build, the bake reads it).

## 4c. THE YELLOW WAS NEVER THE SKY — it was sun-lit fog (v17.75)

After v17.74 (sky light below Miami's, blue on average) and a clean pack the
olive walls and the yellow strip on the core were still there. The worldspawn
diff against the last commit held the answer: `fsi` had been switched from
`default` to `zm_factory_volumetric` on 08-30 so the spire fog would render,
and that asset carries `litfog 1`, `sunintensityscale 2` and an orange haze
colour — sun-lit volumetric fog. `fog_off()` uses the 8-arg `SetVolFog`,
which cannot touch the sun-fog lane. `tod_fsi_cybercity` (in the sky GDT)
is that asset with the sun-lit lane off and `fogopacity 1` kept.
LESSON: when a tint survives every sky change, diff the WORLDSPAWN — every
lighting/fog asset the BSP bakes in is a key there.

## 4e. v17.82 — CONTRAST, LESS GLOW, FEWER STARS, PLANETS + BLACK HOLES

User (first in-game look at v17.81): *"things glow a bit too much. I cant see
that deep contrast detail that gives it personality ... less stars in the sky
with some planets and blackholes here and there."* Knobs moved: the whole
night palette ~30% darker, building fill half as hazy, `GLOW` 0.14 (was
0.30), `starThresh` 0.87 (was 0.60), aurora 1.15, moon bloom 0.07/0.22.
New §1b `BODIES`: three matte planets (ringed giant, rust, ice crescent) and
two black holes (photon ring, tilted Doppler disc, lensed arch, gravity
well), all placed by azimuth relative to the moon at el ≥ 38° so the skyline
never hides them. Previews `night_view_{hole,giant,rust,ice}.png`.
**Placement rule learned the first time round: check every body against the
equirect preview — the giant's first spot was behind the red gate landmark.**

## 4d. THE OLIVE WAS THE SPAWN LIGHT — and it was there before the sky (v17.76)

Ground truth came from the map's own Workshop screenshots (Miami era): the base
was ALREADY gold-olive. The floor's colourMap is `$white_diffuse`; the one
warm light in the base, `tod light base spawn` (`1 0.9 0.78`), painted the
spawn pool, the core face, hands, guns and zombies. Miami's warm sky-light
tinted the whole map the same way and hid it; the blue sky exposed it (far
floor cyan, spawn pool yellow). Now cool white `0.72 0.84 1`.

**THE LESSON THAT COST FIVE BUILDS: before hunting a cause, establish what
the thing looked like BEFORE.** The Workshop item page carries real
screenshots of every published build — `curl` it and look, first.

## 4b. The knob — SKY_GAIN

The file stores `linear = display^2.2 × SKY_GAIN`, `SKY_GAIN = 0.025` (was 0.06 v17.71–73). That
puts the whole-sky mean at 3.9e-3 (Miami 2.8e-3), the upper-half mean at
5.7e-3, and the brightest neon at 0.12 (Miami's point lights hit 1.0). Nobody
has measured the engine's lift, so the FIRST in-game look decides:

- blown out / white horizon → `node tools/gen_tod_sky.js --gain 0.03`
- muddy / too dark → `--gain 0.12`

then a FULL build (the worldspawn keys bake into the .d3dbsp). Nothing else
should need touching for brightness.

## 4e. THE LEVER MAP — where the map's colour comes from (v17.77, the red-light test)

User 2026-09-05: *"if i asked for a red tint of light on the entire map how
would you do it ... I want to see if we even know the levels for this."*
Everything that can colour the screen, in the order the frame is made:

| stage | what it is | the ONE knob | build |
|---|---|---|---|
| sky light | the sky image is the ambient light (§4); it also IS the visible sky | `tools/gen_tod_sky.js --tint r,g,b` (linear, mean held; §4b for gain) | FULL |
| sun | `tod_ssi_cybercity` (enablesun 1, ev 6, stops -2.2, pitch 130 / yaw 140) | `colorSRGB` in source_data/tod_skybox.gdt | FULL |
| point lights | ~310 `light` entities, all emitted by `light()` in the generator | `LIGHT_TINT` (whole lane) or the palettes `DISTRICTS` / `BREATHER_THEME` / `BASE_LIGHT` (per region) | FULL |
| reflections | probes bake FROM the three above | none of their own | FULL |
| fog | `tod_fsi_cybercity` colours + script `SetVolFog` | the tower runs `fog_off()` — fog cannot tint the tower; the spire's is red already | script = `-GscOnly`, fsi = FULL |
| LUT | worldspawn `lutmaterial luts_t7_default` | a custom LUT material + image | FULL |
| vision | `vision/<name>.vision` post-grade: `vkTC` tint, `vkRGB0..4` curve, `vkTT` temperature | a SEPARATE vision file + `VisionSetNaked` (map 1's `_acc_atmosphere::apply_vision`); the MAP-NAME file stays neutral (force-restored per client on every revive) | `-GscOnly` |

"Red tint of LIGHT" = the first three (v17.77 turned all three red: sky
`--tint 1,0.2,0.2`, sun `1 0.253 0.253`, `LIGHT_TINT [1,0.2,0.2]`). "Red
SCREEN" = the vision, four minutes, no bake. A tint that survives a sky
change and a light change is one of the last three rows — diff the worldspawn.
Revert of the test: `LIGHT_TINT = null`, `colorSRGB "0.791298368368055 1 1 1"`,
`node tools/gen_tod_sky.js` with no `--tint`; FULL build.

## 5. Credits

Self-authored image on Treyarch's stock dome; the SSI is a clone of Nastian's
`acc_ssi_miami_night` and the dome mesh's provenance (stock tools vs pack
install) could not be separated by timestamp, so the Nastian credit line
stays, reworded (CREDITS.md).

## 4f. v17.87 — THE DEPTH PASS: atmospheric perspective, the far ring, lensing holes, cloud decks

User (on v17.82 in game, 2026-09-05): *"more cyber themed detail and more
detail in the sky. I can tell blackholes look like they are just cropped in
rather than be part of the sky ... like stickers we just copied and placed in
the sky. The biggest difference in these [references] is they have depth.
Doesn't seem like everything is at the same layer ... part of the city is
farther away and closer. Ours looks more cartoony and backgroundy rather than
giving that atmospheric feeling."*

Diagnosis from the v17.82 previews: every building was drawn at the same
contrast whether 1,000 or 15,000 units away (one `FOG_D` 12000 for everything
left a tower at 15k with 30% of its neon), the ground grid ran at 35% to the
horizon, and the bodies were matte hard-edged discs on a plain gradient with
nothing in front of or around them. A lat-long sky has no parallax, so depth
has to be PAINTED — the generator was rewritten around that.

### The depth model (`drawBox`, and every curve item)
| curve | what it drives |
|---|---|
| `fog = exp(-d / HAZE_D)` (7500) | surface CONTRAST: fill → 0.58× the sky behind it, neon edges → pale haze tint keeping 16%, the face grid × `gridK` (gone beyond ~8k) |
| `lightFog = exp(-d / LIGHT_D)` (15000) | point LIGHTS: window brightness, sparse lit-window points on hazed towers (`dotP`), beacons, trails |
| `skyBaseAt(az, el)` | the sky a box stands in = gradient + the glow dome; the fill converges on it |
| `GLOW_AZ` (720 bins) | light-pollution strength per bearing, accumulated from the geometry (face area × lit × lightFog / d), blurred, 0.35..1.75 |

The dome (`glowDome`) falls off with `exp(-el / 8.5°)`, alternates warm/cool
round the horizon and carries smog noise; it also colours the far ground plane.

### Composition
- **THE FAR RING** — 170 megastructures at 12.5k..26k (mega-towers 2–3 tiers +
  masts, arcologies, twins with two sky-bridges, megablocks), heights to 40°
  of elevation so they stand OVER the near lattice (which stops at 12k) as
  pale, light-speckled giants. Two far downtowns cluster them.
- **LANES** (`LANES`) cap every building, tier and mast under two bearings
  (moon 10°, the giant 8.5°) so a body rises BEHIND the skyline. The tier and
  antenna stacks had to be bound too — the first run put a tier at 19° in
  the giant's lane. The generator prints each body's clearance against the
  skyline profile; only the giant is meant to be partly covered.
- **BODIES**: the giant LOW (el 12.5°, r 5.2°) behind the far skyline with a
  moonlet above; atmosphere limb + scatter halo on every planet; two black
  holes of DIFFERENT designs — `gargantua` ('edge': thin near-edge-on disc,
  lensed arch, warm gas halo) and `maelstrom` ('face': inclined 3-arm spiral
  vortex, blue-white photon ring, POLAR JETS, violet halo). Both LENS the
  background: the pixel at θ reads the sky at θ − θE²/θ (`lens` = Einstein
  radius in disc units), so stars smear into arcs and the ring inside θE is
  the mirrored inner image.
- **CLOUDS** on real planes at 2600 and 9000 above the eye (`fbm2` in world
  coordinates — seamless by construction and foreshortened toward the horizon
  for free); the low deck lit from below by `glowAt(az)` and silvered near the
  moon, the cirrus thin and stretched; both in front of the bodies.
- **CITY DETAIL**: two RING HIGHWAYS (dark deck between thin neon rails,
  cross-ties, traffic dashes, pylons; the eye outside each so each is an arc,
  one passing behind the gate), 9 HOLO PANELS, 7 SEARCHLIGHT fans, 30 AIR
  LANES (≤ ~2.6° long, bright heads), four antenna kinds.
- A DEPTH BUFFER `Z`: boxes write range where covered, every curve item
  (rings, streaks, holos, beacons, beams) tests it per pixel.

### Exposure — measured at FULL size, or not at all
`STATS` prints the sky-light score (mean linear × 2^skyStops) on every run.
**The score is resolution-dependent** (line weight does not scale with W, so a
2048 preview reads ~1.7× higher): v17.82 = 0.834 at 2048 but **0.478 at
8192**, share 22/27/51. The depth pass at gain 0.025 came out BRIGHTER than
v17.82 (the dome + far ring add more than the hazing removes), so `SKY_GAIN`
is 0.024 to hold 0.478. Share moves ~5 points green → red (27/23/50 at 2048)
from the magenta half of the dome; `--tint 1,1.15,1` restores it if the world
reads warmer in game.

### The seam check was measuring the wrong thing
The old check compared the wrap pair to ONE arbitrary column pair and read a
ring rail crossing a row boundary at the seam as a 2× "break". It now compares
the wrap against its own neighbour pairs and the whole-image adjacent mean and
THROWS on an outlier (>2.5×); the wrap sits at 0.2–0.3× of its neighbours. One
real period break was found on the way: scaling the x argument of the periodic
noise maps (`noise(NOISE_C, lx * 1.3, ly)`) changes their period — scale y,
never x. Bisect aids: `TOD_SKY_SKIP=rings,beams,holo,air,far`,
`TOD_SKY_SEAMDBG=1`, `TOD_SKY_PIXDBG=x,y`.

Previews: `night_view_{giant,hole,maelstrom,ring_a,ring_b,far}.png` joined the set.

## 4g. v18.87 (2026-09-13) — THE QUALITY PASS + THE ATMOSPHERE PASS, learned from Tower II's hellscape sky

User: *"our sky box generator for our tower of doom 2 map found an improvement to
make to enhance the background image. Can we learn from what they did and apply
the enhancement to our cybercity background and on top of that make it even more
atmospheric ... more depth and more cyber type theme art. A deeper dark more
detailed sky."*

Tower II's `gen_hb_sky.js` (its docs/63, STATUS v0.5–v0.7) is this generator's
pipeline with a different picture, and its quality passes changed nothing that
is drawn — they changed how the drawing becomes pixels. Every one of those is
now in `gen_tod_sky.js`; the picture additions are ours.

### What was ported (same picture, cleaner pixels)
| stage | v17.87 | v18.87 | why it shows |
|---|---|---|---|
| paint | 8192×4096, per-primitive coverage AA | **16384×8192** (`--ss 2`, default) | true 4-sample anti-aliasing on every neon edge, rail, trail, glyph and star instead of the painter's one-axis coverage estimates; near-vertical tower edges stop stair-stepping |
| noise tables | bilinear read of the 1/8-res tables | **Catmull-Rom**, x wraps, y clamps | the sky base, nebula and smog lose the faint linear facets bilinear left at table-cell scale |
| resolve | — | **Lanczos-2**, separable, wrap-aware in x, row-streamed | a real reconstruction filter; sharper than a box average, no ringing round point lights (Lanczos-3 rings) |
| sharpen | none | **three clamped unsharp passes AFTER the resolve** (3×3 @0.38, 3×3 @0.45, 5×5 @0.25, each clamped 0.6..1.5× the source) | tuned by Tower II against a simulated in-game view (1080p at cg_fov 65 = 80.7° Hor+, 0.96 texel/px, bilinear like the GPU); the same view is written here as `night_ingame_*.png` — judge sharpness on 1:1 crops of THOSE, never on the 2048 equirect (4× minified) |
| file | float → 12-bit LUT → 16-bit PNG → ffmpeg → half EXR | **half floats written directly** (own ZIP16 writer, channels A B G R, no ffmpeg in the shipped path; needs Node 24 for `Float16Array`) | the LUT quantised the dark sky to a few hundred linear steps and banded the gradients into the BC6H compressor; half keeps ~11 bits at every level |
| exposure | `SKY_GAIN` hand-held at 0.024 to keep the v17.82 score | **solved**: `--target-score 0.478` (default) → the gain that lands the sky-light score there, printed on the STATS line; `--gain` pins it; a solve outside 0.012..0.048 THROWS | a picture change can no longer move the world's lighting by accident (§4) |
| perf | bare top-level blocks | every stage an IIFE | a top-level function past V8's optimised-bytecode limit runs every hot loop 2–30× slow (Tower II measured it) |

**Two scales, kept apart.** `PXO = OW/8192` is the SHIPPED pixel: every feature
COUNT and detail GATE keys on it, so `--ss` changes only how cleanly the picture
is resolved. `PX = W/8192` is the RENDER pixel: radii and lengths. `LW` is the
approved final line weight × `SS`. Anything of the form `k·PX + c` had to
become `(k·PXO + c)·SS`, and every pixel constant in the star, holo-scanline,
beacon and mountain-edge code is now `× SS`. The near-city size gate
(`atan(w/d)·W/TAU < 2`) keyed on W and therefore changed the random stream
between a 2048 preview and the 8192 ship — the preview drew a different city.
It keys on `OW` now, so **the 2048 preview draws the same buildings as the ship.**

### What was added (the picture)
**ATMOSPHERE — `veil(az, t, z)`**, the lit air between the eye and every surface,
applied in `drawBox` (per row), the ground grid, the reflections, the ring
highways, the street trails and the mountains, and against the sky by `skyStrata`:
- **GROUND MIST** — a bank on the city plane, density 1 at the plane → 0 at
  `MIST_TOP` 300, patchy in world XY (`fbm2`, seamless). The eye (220) is inside
  it. The ray's path below `MIST_TOP` is integrated (`MIST_D` 900 — it took four
  halvings from 5200 before the bank read as fog on a preview at all: a physically
  thin bank is invisible at these ranges). Tower feet and the far grid dissolve
  into a violet-pink fog lit by the glow dome's warm/cool per bearing (`airCol`);
  the reflections drown with the feet.
- **HAZE STRATA** — two thin layers hanging BETWEEN the towers (`STRATA`: z 560
  and 1180, half-thickness 110/90). A ray to a surface beyond a layer crosses it
  once and runs `2hh·t/|z−EYE|` inside it, so the layer seen edge-on is a band
  and seen steeply a wisp; density from world-XY fbm so the bands break up. The
  strongest depth cue in the picture: towers read sliced by drifting smog.
- **MOON SHAFTS** — crepuscular rays round the moon (a 720-bin periodic ray
  pattern, thresholded so there are real dark gaps), scattered in the air under
  the low deck where the deck has a gap toward the moon (the deck's own fbm is
  sampled 45% of the way from the pixel to the disc). Painted before the clouds.
- **THE STORM** — a cell in the low deck at `STORM_AZ` (2.55 rad round from the
  moon), el 16°, σ 0.10 rad, cloud guaranteed there but ragged by the deck's
  noise, lit from inside (`stormCol`, veined by `NOISE_C`), plus ONE branching
  bolt (`drawBolt`, a hashed random walk, two branches, core + violet glow) from
  the cloud base at 14.2° down to 6.4° at range 9000, depth-tested. A third
  composition LANE (`storm`, half 0.30, maxEl 7°) keeps the skyline low under it.

**CYBER ART**
- **AIRSHIPS** (`drawAirship`, `SHIP_DEFS`) — two dirigibles in disc space, depth
  tested at their range: dark hulls converging on the sky, a neon rim, three
  ribs, tail fins, a lit gondola, a holo billboard on the flank with scanlines,
  red/green running lights and a strobe. One close overhead (2100 out, ~24° long)
  crossing the cyan ring highway, one high and far (5200 out).
- **THE ORBITAL TETHER** (`TETHER`) — an anchor megastructure in the far ring at
  19,000 (three tiers + two arms), a cable from its top toward the zenith with
  climber lights every 2.4°, a STATION at 47° (hub, lit ring, two arms). Drawn
  in the sky pass so the glow dome, clouds and strata pass in front; it fades
  out above 66° because every column converges at the pole.
- **MEGA-BILLBOARDS** — 40% of far-ring mega-towers carry a holo glyph wall
  (`sign.rows` 5, `sign.holo`); signs are LIGHTS now, so they carry on
  `lerp(fog, lfog, 0.7)` instead of `fog` (at 15k the old rule left them at 12%).
- **DEEPER DARK** — zenith / high / mid levels another ~15% down (the gain solve
  holds the world light, so the lights gain contrast); fine nebula grain from a
  new `NOISE_D` table (six octaves to 768), modulated by the nebula so the plain
  dark stays plain.

Previews joined the set: `night_view_{tether,station,storm,ship_a,ship_b,mist}.png`
and the in-game views `night_ingame_{moon,city,tether,giant,ship}.png`.
`TOD_SKY_SKIP` gained `mist,strata,shafts,storm,ships,tether`;
`TOD_SKY_PREVIEW_DIR` redirects the previews (the tuning passes ran into scratch
so the approved set was not overwritten by 2048 renders).

### Tuning trail (2048 previews, ~19 s each)
1. First render: every atmosphere layer invisible. Mist τ at 600 units was 0.07;
   strata alpha peaked at 0.06; the shaft pattern's mean-0.5 noise raised to 2.4
   gave no dark gaps; the storm cell at el 7.6° sat behind the near skyline; the
   ships were 8° long and occluded by the cluster at SUN_AZ+2.2.
2. Mist ×2.4 / `MIST_D` 3200, strata `k` 0.8/0.6 and run/900, shafts thresholded,
   storm lane + el 9.6°, ships 1100/1400 long — mist and strata still not readable.
3. `MIST_D` 1400, strata hh 110/90 `k` 1.0/0.8 run/500, shafts 0.26 and e-fold
   0.28, storm to el 16° σ 0.10 with the bolt at 9000, ships moved to 2100/5200
   out — strata now a heavy lavender wash over the whole mid city.
4. Strata `k` 0.7/0.5 and a more saturated colour; mist `MIST_D` 900 and the
   colour ×1.2 — a ground-column probe (`MIST` debug print) confirmed alpha 0.20 at
   −11° and 0.36 at −6° on the plane. This is what rendered at full size.

### The 16k question — ANSWERED, NO (2026-09-13, same night)
User: *"So higher resolution won't help? Cause I don't mind that size tradeoff."* Tower II
had left it open (its docs/63 v0.6 addendum: "unproven ... the only way to prove it is a
build"). Proven here: the generator was taught widths above 8192 (`OW_BASE` / `HI`: the
approved 8192 picture at exactly 2x the pixels — same city, same line weight in approved
pixels, sharpen radii scaled, `--ss` defaulting to 1 so the paint stays 16384 wide), a
16384x8192 half EXR (139.4 MB) rendered in 363 s, and the FULL build FAILED in the linker:

```
! ERROR: (image source_data\tod_skybox\_images\i_skybox_tod_cybercity.exr) unsupported size.
! ERROR: image 'i_skybox_tod_cybercity' is missing
```

No `.iwi` was produced and the `.ff` went out without a sky until an 8192 re-render and
rebuild. The only 16384-wide image in the whole converted cache is a 16384x64 caustic strip,
so the cap is per-image, not per-axis — an 8192x4096 sky is the ceiling of this pipeline.
`--width 16384` now THROWS in the generator unless `--i-know-16k-fails` is passed for a
future converter re-test. What that means for sharpness: at 1080p the shipped sky is already
0.96 texel per screen pixel (1:1), so the quality pass above IS the sharpness ceiling; 1440p
and 4K players see it magnified 1.3x / 1.9x and only a bigger texture could change that, and
this engine will not take one. Size is irrelevant to the decision — the user waived it.

## 4h. v18.88 (2026-09-13) — THE RAIL PASS: trains, stations, the crosstown line

User, on the v18.87 previews: *"I saw some train railroads and things. Did you deeply
enhance those?"* They were the v17.87 ring highways — a dark deck between two neon rails,
cross-ties, traffic dashes, pylons — and v18.87 had only sharpened and hazed them. Now:

- **TRAINS** — two per line, strings of 6–8 cars (190 long, 22 gap, 105 tall) riding the top
  rail: a dark body converging on the sky, six window slots per car lit warm-white by a hash,
  a roof rim in the line's hue, a white headlight on the lead car, red tail lights on the
  last, and a glow trail on the rail behind the tail (a maglev's charged track, 1.6 car
  lengths). Dashes never draw under a train.
- **STATIONS** — two per line: a platform band (44 up) with a lit edge, a canopy line 200 up
  with a warm lit strip under it, a nine-column glyph board in the line's second hue, two
  lamp posts. Dashes never draw through a station.
- **THE CROSSTOWN** — a third line: a 30,000-radius arc (reads straight) passing 2,600 south of
  the eye at z 950, gold, pylons every 720 units (`pylonStep`), a 0.60 rad span (`p0..p1`)
  chunked in 40 pieces. It runs BETWEEN the near towers, so the depth test slices it.
- **STRUCTURE** — every pylon carries a 128-square head under the deck and a light. The first
  head was a 300-square plate and read as a lamp shade on the preview; halved.
- **FAR RIM** — every deck alpha, rail intensity and light carries `farK = 0.30 + 0.70·e^(−t/12000)`
  so the far half of each ring sinks into the smog.

**Placement lesson.** Trains and stations were first scattered round each circle by ring
angle, and the debug count showed them drawing — 686 phi steps — yet every aimed preview was
empty: they had landed on the hazed FAR rim behind the towers (ranges 5–13k, veil 0.26–0.39).
They now sit on the NEAR rim (`nearPhi = atan2(−cy, −cx)`, the ring angle facing the eye;
the crosstown's is its span centre) at fixed offsets. The aimed previews
`night_view_train_*.png` / `night_view_station_*.png` are generated from the actual
positions (`globalThis.RAIL_VIEWS`) so the next pass can check them without hunting.

## 4i. v18.95 (2026-09-13) — THE RAIL FIT PASS: the lines take the city's grammar

User, on the v18.88 previews: *"Rail way still needs more work. If you take a look doesn't look
like it fits in well."* Read against the towers it stood among, the v18.88 line was in a
different visual language: every building is dark glass with a neon grid and lit edges, and
the deck was a flat pale slab with faint cross-ties, the pylons plain pale poles, the trains
cream strips with warm windows. Now, in `drawRingChunk` and the pylon registration:

- **THE DECK** is a face in the towers' grammar — dark glass (`fc` pulled toward the roof
  black), a neon grid at `CELL` spacing along the arc that dissolves with range on the same
  `gridK`/`lineK` the towers use, the two lit rails as its edges. It writes depth, so trains,
  dots and the dashes test against it.
- **THE GIRDER** (`RAIL_GIRDER` 110 deep, `RAIL_BRACE_U` 360) — a see-through dark truss under
  every deck: a post every 360 units, a zigzag brace between posts (only once the girder is
  a few pixels tall, so it never smears the far rim), a lit bottom chord. The pylons end at
  the chord, gridded like the towers (`plain` dropped), heads and lights under it.
- **TRAINS** are dark glass bodies with cool windows in the line's hue, a neon edge at each
  car end, the roof rim, and a lit underframe on the rail — a maglev, not a cream sausage.
- **STATIONS** get a dark platform with its lit edge and a real canopy slab under the canopy
  line.

Judge on `night_ingame_city.png` (the cyan ring overhead) and `night_view_crosstown.png` (the
gold line as a truss bridge with a train on it).

## 4j. v18.96 (2026-09-13) — a tiny bit darker, more contrast

User: *"Can we make the night sky a tiny bit darker? Enhance the contrast."* Two knobs, both in
`tools/gen_tod_sky.js`: every night sky level (`zen`/`high`/`mid`/`low`/`horSun`/`horAway`/
`haze`, nebulae) another ~18% down, and the light target `--target-score` default 0.478 → 0.45
(−6%, the "tiny bit"). Because the gain is solved for the target, darkening the base alone
would have lifted everything back; the solve landed at gain 0.01661 (was 0.01701, −2.4%), so
the net is: sky base ≈ 0.80× before, neon ≈ 0.98× — darker ground, lights held, contrast up.
The world's ambient light is 6% lower by design; the STATS line prints the score.

## 4k. v18.97 (2026-09-13) — THE PEAK KNEE: the white glare was in the image

User: *"I notice the buildings have these white glares. Is that part of the map or can we change
that just by editing the image? It causes a blur and you can't see the buildings properly."*
It was the image. A lit edge was written at display 1.15 (linear 1.36) over a sky base near
display 0.1 (linear ~0.006) — a 200x peak — and the engine's HDR bloom turns every lit edge,
window, sign, headlight and beacon into a white halo. **The previews never showed it because
they are display-referred PNGs**; the judge is the game.

- **The knee** (stage 4a, `--knee 0.45 --knee-max 0.62`): every display value above 0.45 is
  soft-clipped toward 0.62, per channel so hue is kept. Peaks now sit ~40x over the base
  instead of ~200x. 4.73% of the 8192 image was above the knee.
- **The authored halo** `GLOW` 0.14 → 0.05 (the emit-buffer bloom around lights, the "blur").
- **The gain is PINNED at the v18.96 value 0.01661** and `--target-score` default is now 0.324.
  The peaks carried 28% of the sky-light mean, so solving for 0.45 would have brightened the
  base by a third to make up for them — the opposite of the user's "darker". The world's
  ambient from the sky is therefore ~28% lower than v18.96 (~32% below the v17.82 0.478).
  That is a deliberate lighting change, not drift; restore with `--target-score 0.45` if the
  tower reads too dark in game — that brightens the sky base back to about the v18.95 level.
