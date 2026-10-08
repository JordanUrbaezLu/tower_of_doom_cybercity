# 110 — THE SEVEN TRIAL HALLS: art that makes each one feel like a different place (29 files)

<!-- art-pack
name: trial_halls
refs:
  docs/109_trial_halls/sheet.png | THE SEVEN FLOOR PLANS, one per trial, drawn from the built geometry (north up, entrance bottom-left). What each room IS. Read this first; attach to every prompt.
  docs/109_trial_halls/hall_1.png | TRIAL I THE RING plan (gold): raised ring, four corner pillars with beams over them.
  docs/109_trial_halls/hall_2.png | TRIAL II THE KENNEL plan (green): three barred cages, a yard, two lamps.
  docs/109_trial_halls/hall_3.png | TRIAL III THE FIRING LINE plan (cyan): two pillar arcades, three lanes, a firing step, three target plaques on the far wall.
  docs/109_trial_halls/hall_4.png | TRIAL IV THE ALTAR plan (purple): a three-tier dais, four candle pylons, an altar screen and a wall plaque behind it.
  docs/109_trial_halls/hall_5.png | TRIAL V THE MAZE plan (orange): tall walls forming a loop round an inner room with one door, a floor thread leading in.
  docs/109_trial_halls/hall_6.png | TRIAL VI THE GAUNTLET plan (white on navy): one lane between tall walls with baffles, runway lamps, a finish step.
  docs/109_trial_halls/hall_7.png | TRIAL VII THE THRONE plan (red): a nave of pillars up a carpet to a throne with a wall banner behind it.
  i_tod_trial_1.png | THE CURRENT TRIAL I BANNER. The series chassis to keep exactly: rounded plate, red grid, gold circuit traces, numeral bar left, gold TRIAL, white name. Attach to every banner prompt.
  i_tod_trial_3.png | THE CURRENT TRIAL III BANNER: shows the cyan colourway and the numeral bar at three digits.
  i_tod_trial_7.png | THE CURRENT TRIAL VII BANNER: the red colourway at the top of the ladder.
  i_tod_trial_won.png | The TRIAL IS WON plate, shipping and unchanged. Context only.
preview: 448x112
-->

> **STATUS: INSTALLED + WIRED v17.88 (drop `files - 2026-09-05T163829.118.zip`, 16:38, all 29 files clean) — NOT YET LOOKED AT IN GAME.** Banners over the same names (the generator rebuilt the chassis with a RED grid — accepted, noted). World textures: 21 materials in `source_data/tod_materials.gdt` at scaleRGB 4.0, crest plaque on every hall's N wall (`panel … 'crest'`), seal on the mark, tile on the liner (generator `HALL_ART`). Three things need a look: does the lane link (waived-warning count), crest orientation, glow level. See CHANGELOG v17.88.
>
> **(Original) STATUS: COMMISSIONED 2026-09-05 (after v17.86).** User: *"Do we think we
> should improve the assets to give it a better feel too? ... We want the best
> experience for players ... I really want to emphasize the freshness these
> trials need from one another. I'm afraid of players getting bored cause it's
> too stale."* Pack built by `.\tools\make_art_pack.ps1 docs\110_trial_halls_art_prompt.md`
> → `~/Downloads/tod_trial_halls_art_pack.zip`.
>
> **What this buys.** v17.86 (docs/109) rebuilt the seven halls as different
> ROOMS, but every surface in them is still the same two textures (the vertigo
> pack: black tiles + a grid line, or a filled glow) in seven tints. Three of
> the halls already carry blank glowing PLAQUES on their far wall (the Firing
> Line's targets, the Altar's reredos, the Throne's banner) and every hall has
> a blank LINER band round its walls and a bare red seam for its trial mark.
> This pack fills those three surfaces with art that is DIFFERENT IN KIND per
> hall — a cage, a target, a labyrinth, a throne — and re-glyphs the seven
> banners to match, so the moment a player steps in (and the moment the seal
> banner drops) they know they are somewhere new.
>
> **Wiring (repo side, after the drop) — TWO LANES, one of them NEW:**
> 1. **Banners (JOB 4) — the proven lane.** Same names over
>    `source_data/tod_ui_images/_images/`, no zone / GDT / Lua change, FULL
>    build, proof = a fresh content-hash `.iwi` beside an untouched control.
> 2. **World textures (JOBS 1–3) — a NEW lane, unproven on this map.**
>    Custom WORLD materials: one `material.gdf` block per texture in
>    `source_data/tod_materials.gdt` cloned from a vertigo `_tinted` block (the
>    pack's materials are all `lit_emissive_*`, so a black background is dark
>    and everything else glows — that is the whole reason the rules below
>    demand pure black) + an `image.gdf` block each, PNGs under
>    `source_data/tod_materials/_images/`. Generator: `panel` takes a `mat`
>    (the crest), the trial mark takes `kit.floorMat`, the liner takes
>    `kit.linerMat`; the four halls with no plaque yet (Ring, Kennel, Maze,
>    Gauntlet) get a 256×128 crest panel on their N wall. The geometry lint's
>    MATERIALS table must learn every new name (BLOCK for crests and tiles; the
>    floor emblem is a 1u inlay like the plain-material sigils already
>    shipped). FULL build. Proof = the linker's known-waived warning list
>    UNCHANGED in count (a material it cannot find lands there) + the look in
>    game. **Memory `pap-camo-materials-never-linked` says our custom camo
>    materials never rendered — so wire ONE crest first, build, look, and only
>    then the other twenty.** If the lane will not link, the crests can still
>    ship as UI images on a script-spawned plate; decide after the one-material
>    test, not before.

<!-- PACK:BEGIN -->
# TOWER OF DOOM: CYBERCITY — THE SEVEN TRIAL HALLS (4 jobs, 29 files)

You are the art director and image generator for **Tower of Doom: Cybercity**,
a Call of Duty: Black Ops III custom zombies map. You already delivered the
**TRIAL I..VII banners** (in `reference/`). The map's endless mode climbs a
red tower with a boss arena — a **TRIAL HALL** — every ten floors. Each hall
has just been rebuilt as a different ROOM (the floor plans are in
`reference/`), and this pack is the art that makes each of the seven feel
like a different PLACE, not the same room in a different colour.

**THE ONE RULE ABOVE ALL OTHERS: the seven must differ IN KIND, not in tint.**
A player who has just fought in the Kennel and walks into the Firing Line
must see at a glance that this is somewhere else. If your seven crests could
be described as "the same plaque with a different colour and word", start
over. Different silhouette, different composition, different emblem, different
mood — the colour is the LEAST of the differences.

**Open `reference/` first; this text only describes the files there.** Attach
`sheet.png` (all seven plans on one page) to EVERY generation, and the
hall's own plan — `hall_1.png` (Ring), `hall_2.png` (Kennel), `hall_3.png`
(Firing Line), `hall_4.png` (Altar), `hall_5.png` (Maze), `hall_6.png`
(Gauntlet), `hall_7.png` (Throne) — to that hall's crest, floor and tile
prompts. The banner prompts attach that hall's current banner:
`i_tod_trial_1.png` (gold, the numeral bar at one digit), `i_tod_trial_3.png`
(cyan, three digits) and `i_tod_trial_7.png` (red, the top of the ladder) are
in `reference/` as the three colourways to match; `i_tod_trial_won.png` is the
WON plate, context only — it does not change.

---

## THE SEVEN HALLS (the story each piece of art must tell)

| # | name | colour (hex) | the room | the story | the EMBLEM |
|---|---|---|---|---|---|
| I | THE RING | gold `#FFD84D` | a raised fighting ring, four corner posts, beams over them | THE PROVING GROUND — fight in the open, keep moving | a square ring of light with four corner posts, a single figure inside |
| II | THE KENNEL | green `#66FF80` | three barred cages round a yard | THE POUND — the cages are dead ends for you, doorways for the hounds | a cage of vertical bars with two glowing eyes behind them |
| III | THE FIRING LINE | cyan `#59D9FF` | two arcades, three long lanes, a firing step, targets on the far wall | THE RANGE — you are the targets | a shooting-range target: concentric rings, bullet holes, a lane below it |
| IV | THE ALTAR | purple `#B366FF` | a stepped dais, four candle pylons, an altar screen | THE SACRIFICE — the dais is the only high ground | a three-step altar with four candle flames, a blade or a drop above it |
| V | THE MAZE | orange `#FF8C33` | tall walls, one loop, one door, a thread on the floor | THE LABYRINTH — corners are the enemy | a square labyrinth glyph with a single thread running to its centre |
| VI | THE GAUNTLET | white `#F2F2FF` on navy | one lane between tall walls, baffles, runway lamps, a finish step | THE RUN — three of them come down at the finish; run it | a lane in one-point perspective, chevrons / speed lines, a finish bar |
| VII | THE THRONE | red `#FF4D4D` | a nave of pillars up a carpet to a throne | THE COURT — everything, all at once; the first one lands on the throne | a high-backed throne, a crown floating above it, a carpet below |

Look: the map's world is a **Tron / synthwave neon grid** — black surfaces
with glowing lines. Every texture here is drawn as GLOWING LINES AND SHAPES
ON PURE BLACK, because in the game anything that is not black will glow. The
banners in `reference/` are the family's typographic voice (heavy condensed
capitals, gold TRIAL, gold circuit traces); the plans show each room's real
proportions.

---

## JOB 1 — SEVEN HALL CRESTS (wall plaques)

The crest hangs on the far wall of its hall, **256 wide × 128 tall in the
world**, seen first from the doorway about 600 units away — at that distance
it is roughly **150 pixels wide on screen**. So: ONE big emblem, the hall's
name in heavy type, nothing fine.

| # | file | size | content |
|---|---|---|---|
| 1 | `tod_hall_crest_1.png` | 1024 × 512 | THE RING crest: the ring emblem, gold, name below |
| 2 | `tod_hall_crest_2.png` | 1024 × 512 | THE KENNEL crest: the cage emblem, green |
| 3 | `tod_hall_crest_3.png` | 1024 × 512 | THE FIRING LINE crest: the target emblem, cyan |
| 4 | `tod_hall_crest_4.png` | 1024 × 512 | THE ALTAR crest: the altar emblem, purple |
| 5 | `tod_hall_crest_5.png` | 1024 × 512 | THE MAZE crest: the labyrinth emblem, orange |
| 6 | `tod_hall_crest_6.png` | 1024 × 512 | THE GAUNTLET crest: the lane emblem, white |
| 7 | `tod_hall_crest_7.png` | 1024 × 512 | THE THRONE crest: the throne emblem, red |

Hard rules (every crest):
- **PNG-24, NO alpha channel, background PURE BLACK `#000000`** edge to edge.
  Grey, noise, vignette or a "dark" background will glow in game.
- The emblem fills at least the middle **60 % of the height**; the name is a
  single line of heavy condensed capitals at least **1/5 of the height**,
  in the hall colour or white with the hall colour as its glow.
- Line weights thick enough to survive a 7× downscale: no line thinner than
  **6 px** at 1024 wide.
- A thin frame in the hall colour round the whole plate is welcome; it must
  stay ≥ 24 px inside the edge (the edge is black).
- **Seven different compositions.** One is centred, one is asymmetric, one is
  a silhouette, one is line-art, one is a single object, one is a scene, one
  is a symbol. Do not reuse a layout twice.

**Prompt (crest, one per hall — substitute the row from the table; attach
`sheet.png` and that hall's `hall_N.png`):**

> A glowing neon emblem plaque for a video-game arena wall, 1024 by 512
> pixels, PNG with NO transparency, the background solid pure black. Synthwave
> / Tron style: everything is drawn as luminous {COLOUR} light on black —
> {EMBLEM DESCRIPTION} — filling the middle of the plate, with the words
> "{NAME}" in heavy condensed capitals beneath it, and a thin {COLOUR} keyline
> frame just inside the edge. Bold shapes, thick lines, no fine detail; it
> must read from across a room. No gradients into grey, no smoke, no
> vignette — pure black wherever there is no light.

---

## JOB 2 — SEVEN FLOOR EMBLEMS (the trial mark)

A 96 × 96 seal set into the floor at the spot where the hall's reward drops.
Seen from standing height, walked over, so: one circular emblem, heavy lines.

| # | file | size | content |
|---|---|---|---|
| 8–14 | `tod_hall_floor_1.png` … `tod_hall_floor_7.png` | 1024 × 1024 | the hall's emblem in a **roundel** (a circle with a rim), the hall colour on pure black, NO text |

Hard rules: PNG-24, no alpha, pure black background; the roundel's outer rim
≥ 32 px inside the edge; no line thinner than 8 px; the emblem is the SAME
motif as the hall's crest (so crest and floor agree) but composed for a
circle. Seven distinct roundels — a ring, a cage, a target, an altar, a
labyrinth, a lane, a throne.

**Prompt (floor, one per hall; attach `sheet.png` and `hall_N.png`):**

> A circular neon floor seal for a video-game arena, 1024 by 1024 pixels,
> PNG with NO transparency, solid pure black background. A luminous {COLOUR}
> roundel — a bold rim ring with {EMBLEM DESCRIPTION} drawn inside it as thick
> glowing lines — centred, filling most of the square, no text. Synthwave /
> Tron look, pure black outside the light.

---

## JOB 3 — SEVEN WALL TILES (the liner band)

A band of texture runs round each hall's walls at head height. Today it is a
plain grid in the hall colour. Give each hall its OWN seamless pattern so the
walls themselves say which hall you are in.

| # | file | size | pattern |
|---|---|---|---|
| 15 | `tod_hall_wall_1.png` | 1024 × 1024 | THE RING: rope-and-post rhythm — thick vertical posts every quarter with a triple horizontal line between them, gold |
| 16 | `tod_hall_wall_2.png` | 1024 × 1024 | THE KENNEL: cage bars — dense vertical bars with a rail top and bottom, green |
| 17 | `tod_hall_wall_3.png` | 1024 × 1024 | THE FIRING LINE: range stripes — horizontal warning stripes and small target rings, cyan |
| 18 | `tod_hall_wall_4.png` | 1024 × 1024 | THE ALTAR: candle flames on stems in a row, a pointed-arch rhythm above them, purple |
| 19 | `tod_hall_wall_5.png` | 1024 × 1024 | THE MAZE: a meander / key-pattern band, orange |
| 20 | `tod_hall_wall_6.png` | 1024 × 1024 | THE GAUNTLET: chevrons pointing one way, runway dashes, white |
| 21 | `tod_hall_wall_7.png` | 1024 × 1024 | THE THRONE: heraldic — repeated crowns and fleurs on a diamond lattice, red |

Hard rules: PNG-24, no alpha, pure black background; **SEAMLESS in BOTH
directions** (the left edge continues into the right, the top into the
bottom — test by tiling 2 × 2); pattern elements ≥ 12 px thick; the pattern
repeats about 4 times across the 1024 width so it reads as texture, not as a
picture. Seven DIFFERENT motifs — no recolours.

**Prompt (tile, one per hall; attach `sheet.png` and `hall_N.png`):**

> A seamless tileable neon pattern, 1024 by 1024 pixels, PNG with NO
> transparency, solid pure black background, luminous {COLOUR} line-art: {TILE
> PATTERN}, repeating about four times across the width, edges matching so the
> image tiles perfectly left-to-right and top-to-bottom. Thick glowing lines,
> synthwave / Tron look, nothing but black between the lines.

---

## JOB 4 — SEVEN BANNERS, RE-GLYPHED (same series)

The TRIAL I..VII banners drop on screen when a hall seals. They already carry
the right names and colours (see `reference/`). Keep them EXACTLY — the
rounded plate, the red grid, the gold circuit traces, the numeral bar on the
left, the gold TRIAL, the white name — and change ONE thing: the faint
background glyph becomes **the hall's EMBLEM from JOB 1**, drawn larger and
clearer (about 30 % opacity over the grid, behind the name, right of the
numeral bar), so banner, crest and floor all carry the same mark.

| # | file | size | change |
|---|---|---|---|
| 22–28 | `i_tod_trial_1.png` … `i_tod_trial_7.png` | 2048 × 512 | PNG-32 (transparent outside the plate, as now); the hall's emblem as the background glyph; nothing else moves |

The banner is shown at **448 × 112 on screen** — `preview_onscreen_448x112/`
holds the current ones at that size. The emblem must still be recognisable
there; the name must stay exactly as legible as it is now (it sits ON TOP of
the glyph — keep the glyph at low opacity).

**Prompt (banner, one per hall — attach that hall's current banner, e.g.
`i_tod_trial_3.png` for THE FIRING LINE; `i_tod_trial_won.png` shows the
family's glow treatment for reference only):**

> The identical banner plate as the attached image — same 2048 by 512 size,
> same transparent background outside the plate, same rounded plate, red
> grid, gold circuit traces, the same numeral bar on the left, the same gold
> "TRIAL" and the same white "{NAME}" in the same position — but the faint
> background glyph behind the name is replaced by {EMBLEM DESCRIPTION} in
> {COLOUR}, larger and clearer, at about 30 % opacity so the name stays fully
> legible over it. Change nothing else.

---

## JOB 5 — REVIEW SHEET (1 file)

| # | file | content |
|---|---|---|
| 29 | `trial_halls_kit_preview.png` | one sheet, seven rows: crest / floor roundel / wall tile (shown 2 × 2 tiled) / banner at 448 × 112, one row per hall, in ladder order |

---

## DELIVERY CHECKLIST

- [ ] 29 files, exact names above, exact sizes; JOBS 1–3 PNG-24 with NO alpha, JOB 4 PNG-32 with alpha.
- [ ] Every JOB 1–3 background is `#000000` — check a corner pixel.
- [ ] The seven crests differ in COMPOSITION, not only in colour and word (say which is which in one line each).
- [ ] The seven wall tiles tile seamlessly 2 × 2 with no visible seam.
- [ ] The floor roundel and the crest of each hall carry the same motif.
- [ ] The banners' plate, numeral bar, TRIAL and name are pixel-identical to the current files; only the glyph changed.
- [ ] Names proofread: THE RING, THE KENNEL, THE FIRING LINE, THE ALTAR, THE MAZE, THE GAUNTLET, THE THRONE.

## DO NOT

- Do not deliver seven recolours of one design — that is the failure this pack exists to prevent.
- Do not put text on the floor roundels or the wall tiles.
- Do not use grey, gradients into grey, smoke, fog or vignettes on the world textures — only black and light.
- Do not thin the lines; everything here is seen from far away or under a running player.
- Do not change the banners' type, plate or numeral bar.
- Do not add alpha to the world textures or remove it from the banners.
<!-- PACK:END -->
