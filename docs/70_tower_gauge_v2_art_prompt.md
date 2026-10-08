# 70 — TOWER GAUGE v2: art prompt pack (5 images) + wiring plan

> **STATUS: ART DELIVERED AND WIRED, v16.39 (2026-09-02) — UNPLAYED.** User:
> *"Can we look into improving the design of the tower bar on the right of the
> screen? ... make it cleaner more detailed and nicer. And maybe the crown at
> the top should kind of reflect what it actually looks like on this map."*
>
> The pack went out as `~/Downloads/tod_tower_gauge_v2_art_pack.zip` (this
> brief as `INSTRUCTIONS.md`, a 1:1 layout guide, a HUD placement diagram, and
> every reference: the six shipped gauge PNGs, the 2026-08-21 masters from
> `files (16).zip`, five shipped crown renders, four HUD style plates). The art
> came back the same day as `files (98).zip`: three PIXEL-REGISTERED 180×1440
> masters from ONE procedural draw (the delivery ships its own
> `build_gauge_v2.py` — PIL at 2×, Lanczos down, the lit/down alpha and every
> cut row copied from the dark master), the 72×42 pip, and a preview sheet.
> `tools/slice_gauge.js` measured it: 0 silhouette pixels differ, 0 pixels on
> any cut row, 0 in the neck. **§B.0 records what was built where it differs
> from the plan in §B.1–B.6.**

**What is wrong with the shipped gauge** (`source_data/tod_ui_images/_images/
i_tod_gauge_*.png`, 180 × 1440 kit from 2026-08-21, docs/63 §C.11 rated it
"clean flat minimal, optional material pass only"):

- **The crown is an emoji.** A cartoon crown with a sparkle in a cream halo,
  while the map's rooftop is a 6128 × 13,888 heraldic gold crown with an ermine
  rim, 16 points, arches, monde, cross, red beacon and a bell underside
  (docs/34). The bar's top is the ONE place the goal is drawn on the HUD.
- **It knows nothing about the districts.** Since v16.11 the spiral is five
  colour districts (blue / green / orange / gold / red, `DISTRICTS` in the
  generator) and the four lounges cap their districts in their own colour. The
  bar lights every cell the same cyan and marks the lounges amber — a
  pre-facelift read.
- **The boss pip is a code-drawn red rectangle** (`GaugeBoss` has no
  `setImage`), the only unbaked element on the HUD.
- **The down tile is a hue-rotated breather tile.** Fine today, but once the
  top district lights RED a plain red cell in cells 21–25 is ambiguous — the
  v2 down tile carries a white glyph for exactly that reason.
- Flat cartoon material next to the luck bar's plate-and-keyline language.

**Design decisions taken in the brief** (so the next session does not
re-litigate them): same 180 × 1440 canvas and the same 52 × 416 on-screen slot
(zero HUD layout risk); the crown zone grows 140 → 270 px and the cell pitch
drops 48 → 42 (cells 290..1340); lit tiles become **full-width 180 × 42 band
crops, one image per cell** (25 images, so every cell can carry its own
district colour and the lit master is free to be one continuous design);
lounges are distinguished by SHAPE (wider chamfered plate), never colour; the
down tile is a universal 180 × 42 tile with a mandatory white glyph; the boss
pip becomes a 72 × 42 art asset; no numerals anywhere (the bar doubles as the
finale / trial clock); the player marker stays retired.

---

## A. THE BRIEF — verbatim copy of the pack's `INSTRUCTIONS.md`

# TOWER OF DOOM: CYBERCITY — TOWER GAUGE v2 (art brief for the asset model)

You are the art director and image generator for the HUD of **Tower of Doom:
Cybercity**, a Call of Duty: Black Ops III custom zombies map. This job re-bakes
ONE HUD widget: the **TOWER GAUGE** — the tall vertical bar on the right edge of
the screen that shows how high the party has climbed. The current art is flat
and cartoonish (a plain pill, rounded-rectangle cells, an emoji-style crown in a
cream halo). We want a cleaner, more detailed, more premium version that
**matches the rest of the HUD** (dark navy plates, thin neon keylines, glowing
segments) and that **shows the tower as it actually is in the map**: five colour
districts of floors, four lounge floors, and the real gold crown on top.

Everything in `reference/` is either live shipped art from this map or a render
of the map's own geometry. **Open the references first; this text only
describes them.** Attach the named files to every generation.

---

## 1. What the gauge is (context you need)

- The map is a **50-floor spiral tower**. The bar has **25 CELLS, one per TWO
  floors**: cell 1 (floors 1–2) at the BOTTOM, cell 25 (floors 49–50) at the
  TOP. Above cell 25 is the **CROWN** (the rooftop citadel, the goal). Below
  cell 1 is the **BASE** (the ground-floor arena where the match starts).
- In game the bar is drawn **52 × 416 px on a 1280 × 720 layout** (≈ 78 × 624
  at 1080p), pinned to the right screen edge with nothing else near it — see
  `HUD_PLACEMENT.png`. That is **29 % of the art's size at 720p and 43 % at
  1080p**, with no mip-mapping, so every shape must survive a hard downscale:
  no hairlines under 3 px, no fine texture, no type.
- **How the engine draws it** (this dictates the deliverables): it draws the
  DARK master (the unlit bar) as the backing, then stamps a LIT tile onto every
  cell at or below the player's floor. Each lit tile is **cut from the LIT
  master at that cell's exact 42-px band, full canvas width**, and pasted over
  the same band of the dark master. When the player reaches the roof the CROWN
  band is stamped on. A cell where a teammate is DOWNED is swapped for the red
  DOWN tile. A small BOSS PIP is drawn to the LEFT of the bar beside the cell
  the highest live Panzer is on (v19.46: Panzers only, never the Protector or
  Reaver; before that, the lowest of every flagged boss). There is no
  cropping, tinting, masking or
  animation in the engine: every state is one of these PNGs, so the three
  masters must line up pixel for pixel.
- During the ending the same bar becomes a **TIMER**: it empties, then fills
  bottom-to-top over the final song. So **no floor numbers may be baked into
  the cells** — the lit trail has to read as "progress" in either role.

## 2. The five districts and the four lounges (from the map)

The tower's floors are lit in five colour districts of ten floors each, and
each of the first four districts is capped by a walled **LOUNGE** floor (a rest
stop with perk machines and a teleporter) in that district's colour. On the bar:

| cells | floors | district | lamp hue |
|---|---|---|---|
| 1–5 | 1–10 | **BLUE** | `#5A8CFF` |
| 6–10 | 11–20 | **GREEN** | `#59FF99` |
| 11–15 | 21–30 | **ORANGE** | `#FF9940` |
| 16–20 | 31–40 | **GOLD** | `#FFD959` |
| 21–25 | 41–50 | **RED** | `#FF4D4D` |

**Lounge cells are 5, 10, 15 and 20** — the TOP cell of each of the first four
districts, in that district's colour. Cells 21–25 are the danger floors under
the crown. The lit trail therefore climbs blue → green → orange → gold → red →
crown, exactly as the tower does.

## 3. The crown (from the map — `reference/crown/`)

The rooftop is not a cartoon crown. It is a giant heraldic **GOLD crown**
floating beside the tower's top (`crown_v13_elevation.png` is the front view,
`crown_v13_hero.png` the three-quarter view players get from the stairs,
`crown_v13_under.png` what they see from below). Elements, top to bottom:

- a red **BEACON** star at the apex, glowing red;
- a cross pattée finial on a golden **MONDE** (orb);
- two dipped **ARCHES** rising from the rim to the monde;
- a rim of **16 alternating points** — tall crosses pattée and shorter
  fleurs-de-lis — every point tipped with a coloured stone (ruby / emerald /
  sapphire);
- a **FRONT CROSS** in the centre with a great **RUBY**;
- a flared gold **BAND** set with jewels;
- a white **ERMINE** fur rim (the widest line of the whole silhouette) with
  dark tail-spots;
- below the rim, a stepped **BELL** underside of gold and brass tiers hung with
  blue pendilia, ending in a ruby drop pendant.

Colours measured from the map: bright gold `#FFE45C`, gold panel `#C9A52E`,
brass `#B0621A`, ermine `#EEF2F8`, ruby `#C0302A`, sapphire `#2D4FB8`,
emerald `#2E9E5B`.

At 52 px wide on screen the crown can carry about five reads. Draw them in this
priority: **ermine rim → flared gold band → the points → arches + monde + cross
→ the red beacon on top.** The jewel dots are optional accents. The red
vertical axis (beacon above, ruby in front, pendant below) is the crown's
signature — keep at least the beacon and the front ruby. A short bell/pendant
under the rim is welcome if it fits the band.

## 4. The style contract (read from `reference/hud_style/`)

- **Plate:** near-black navy (`#0C1022`-ish) with a faint inner vignette,
  slightly lighter toward the top (see `i_tod_badge_luck_60.png`).
- **Keylines:** a thin neon cyan-white (`#9FF6FF`) rim with a soft outer glow
  that stays inside the canvas, and a darker keyline just inside it.
- **Lamps / segments:** the luck bar's treatment (`i_tod_luck_10.png`) — a
  filled glowing segment with a bright core, a hairline top highlight, a soft
  bloom. Cyberpunk / Tron-grid, clean vector, no grunge, no photo textures.
- **Frame details** are allowed and wanted: rail lines, tick marks at the
  district boundaries, small screws or vents like `i_tod_banner_upgrade.png` —
  as long as they survive the downscale.
- **No text anywhere.** No numerals, no letters, no logos.
- Transparent background; nothing baked behind the bar.

## 5. THE GRID — non-negotiable; every number is a pixel on the 180 × 1440 canvas

Canvas **180 wide × 1440 tall**, PNG-32 (RGBA), fully transparent outside the
bar. `LAYOUT_GUIDE_gauge_v2.png` is a colour-coded diagram of this table (a
diagram, not a style reference):

| zone | y (top .. bottom) | notes |
|---|---|---|
| **CROWN** | 0 .. 270 | full 180 width available; the crown sits on the bar's top cap |
| **NECK** | 270 .. 290 | the bar's top cap / shoulder |
| **CELL 25** | 290 .. 332 | top cell — floors 49–50, RED |
| … | pitch **42** | cell *f* spans **y = 290 + (25 − f) × 42** to +42 |
| **CELL 1** | 1298 .. 1340 | bottom cell — floors 1–2, BLUE |
| **BASE** | 1340 .. 1440 | the base-arena cap |

- Lamp column **x 30 .. 150** (normal cell plates live inside it). Lounge
  plates (cells 5/10/15/20) are **wider chamfered plates, up to x 22 .. 158**,
  that break the rail line. The frame and rails may use x 18 .. 162; glows may
  reach x 0 .. 180.
- **Each cell's plate + glow stays INSIDE its own 42-px band**, with ≥ 4 px of
  plate-dark margin above and below the lamp (lamp body ≈ 30–32 px tall). The
  engine cuts the tiles on the band lines **y = 290 + 42·k (k = 0 .. 25)**, so
  any glow crossing a line is clipped and shows as a hard edge at the top of
  the lit trail.
- The guide's colours: gold band = crown zone, grey = neck, five tinted bands
  = the districts (lounge cells drawn wider), cyan = base, white hairlines =
  the cut lines, magenta = the canvas edge.
- **The three masters must be PIXEL-REGISTERED**: identical silhouette, frame,
  cell plates, crown outline and base; only the state (unlit / lit / down)
  changes. Overlay them — nothing may shift by a pixel.

## 6. Deliverables (exact filenames)

| # | file | size | what it is |
|---|---|---|---|
| 1 | `gauge_dark.png` | 180 × 1440 | UNLIT master |
| 2 | `gauge_lit.png` | 180 × 1440 | FULLY LIT master |
| 3 | `gauge_down.png` | 180 × 1440 | DOWN master (every cell in the down state) |
| 4 | `gauge_boss.png` | 72 × 42 | the boss pip |
| 5 | `gauge_kit_preview.png` | any (e.g. 1400 × 1600) | review sheet |

1. **`gauge_dark.png` — UNLIT master.** Every cell an empty plate in the dark
   navy with a faint (≈ 15 %) tint of its district hue on the plate, so the five
   districts read before they light. The four LOUNGE plates (cells 5/10/15/20)
   are the wider chamfered plates. The CROWN in the 0..270 band is a **dim,
   unlit gold silhouette** (no glow, beacon dark) — the goal is visible from
   the first second, it just is not lit yet. The BASE cap is the ground floor:
   a navy plaza plate with a thin dim cyan inlay ring. Small frame ticks at the
   district boundaries (between cells 5|6, 10|11, 15|16, 20|21) are welcome.
2. **`gauge_lit.png` — FULLY LIT master.** Identical layout; every cell lit in
   its district hue (table in §2) with the glowing-segment treatment; the
   lounge cells lit in the SAME hue as their district on their wider plate
   (shape distinguishes a lounge, never colour); the crown **fully lit** —
   bright gold, red beacon and front ruby glowing, stone accents on the points,
   white fur rim; the base ring lit cyan. The neck and the frame may be
   identical to the dark master.
3. **`gauge_down.png` — DOWN master.** Identical layout; **EVERY cell (all 25,
   lounge cells included) shows the same DOWN tile**: the plate filled alarm
   red `#FF3A30` with a bold **WHITE glyph — a medic cross or a downed figure
   — and a thin white keyline**, a soft red glow inside the band. It must be
   unmistakable next to a LIT RED-district cell (cells 21–25 light red), so the
   white glyph is mandatory, and on the lounge cells it must cover the whole
   wider plate. Crown and base as in the dark master.
4. **`gauge_boss.png` — BOSS PIP, 72 × 42, transparent.** A small red
   (`#FF3A30`) rounded tab pointing RIGHT, its tip at the right edge of the
   canvas, a small white skull (or a glowing Panzer eye) in the tab, dark
   outline, soft red glow. It is drawn just left of the bar beside the boss's
   cell and reads at 21 × 12 px on screen — bold and simple.
5. **`gauge_kit_preview.png` — review sheet.** The bar in six states side by
   side on a neutral dark grey: empty; climbed to floor 10 (cells 1–5 lit);
   floor 30 (cells 1–15 lit); full with the crown lit; cells 8 and 17 DOWN
   with everything up to cell 20 lit; the boss pip beside cell 12 with cells
   1–12 lit. Also show one bar at 40 % scale so we both see what the player
   sees.

**Optional extras:** a 2× set (360 × 2880 and 144 × 84, every grid number × 2,
same filenames with `@2x`) — we downsample it ourselves; and `gauge_lit_alt.png`
— one alternative lit treatment (e.g. lamps drawn as edge-lit stair treads or
tower windows) if you have a second idea.

## 7. Prompts (paste verbatim; attach the named references)

**Prompt A — `gauge_dark.png`** (attach `reference/current_kit/i_tod_gauge_dark.png`,
`LAYOUT_GUIDE_gauge_v2.png`, `reference/hud_style/i_tod_luck_10.png`,
`reference/hud_style/i_tod_badge_luck_60.png`, `reference/crown/crown_v13_elevation.png`):

> A tall vertical HUD gauge for a cyberpunk zombies game, exactly 180 by 1440
> pixels, PNG with a fully transparent background. A slim dark navy plate
> (#0C1022) with a thin glowing cyan-white keyline and a soft outer glow,
> clean Tron-grid vector style, no text, no numbers, no logos. From the top: a
> dim, unlit heraldic gold crown filling the top 270 pixels — white ermine fur
> rim as its widest line, a flared gold band, alternating tall cross and
> fleur-de-lis points tipped with tiny stones, two arches meeting at an orb
> with a cross, a small dark beacon star at the very top — rendered as a muted
> unlit silhouette that still clearly reads as a crown; then a short cap; then
> twenty-five empty rounded cell plates stacked at exactly 42 pixel pitch
> inside a 120 pixel wide column, each plate tinted faintly by its group —
> bottom five blue, next five green, next five orange, next five gold, top
> five red; the fifth, tenth, fifteenth and twentieth plates counted from the
> bottom are wider chamfered hexagonal plates that break the rail line; small
> tick marks on the rails between the colour groups; at the bottom a base cap
> shaped like a small navy plaza plate with a thin dim cyan ring. Match the
> layout, proportions and margins of the attached current gauge and the layout
> guide exactly; take the plate material, keyline and glow language from the
> attached luck bar and badge.

**Prompt B — `gauge_lit.png`** (attach Prompt A's result,
`reference/original_masters_2026-08-21/gauge_lit.png`, `reference/crown/crown_v13_hero.png`):

> The identical gauge as the attached, exactly 180 by 1440 pixels, same
> silhouette, frame and layout pixel-for-pixel, now FULLY LIT: every one of the
> twenty-five cell plates filled with a glowing neon segment in its group
> colour — bottom five #5A8CFF blue, then #59FF99 green, then #FF9940 orange,
> then #FFD959 gold, top five #FF4D4D red — each segment with a bright core, a
> hairline top highlight and a soft bloom that stays inside its own 42 pixel
> band; the four wider plates lit in the same colour as their group; the crown
> at the top now bright gold with a glowing red beacon star at the apex, a
> glowing ruby in the front cross, small blue and green stone accents on the
> points and a white fur rim; the base ring glowing cyan. Nothing else changes.

**Prompt C — `gauge_down.png`** (attach Prompt A's result,
`reference/current_kit/i_tod_gauge_down.png`):

> The identical gauge as the attached, exactly 180 by 1440 pixels, same
> silhouette, frame and layout pixel-for-pixel, with every one of the
> twenty-five cell plates in a DOWNED state: the plate filled solid alarm red
> #FF3A30 with a thin white keyline and a bold white medic-cross glyph centred
> in it, a soft red glow that stays inside the band; the four wider plates use
> the same red treatment covering their whole wider shape; crown and base
> unlit exactly as in the attached. No text.

**Prompt D — `gauge_boss.png`** (attach Prompt C's result for the red):

> A tiny HUD marker, exactly 72 by 42 pixels, PNG with a transparent
> background: a red #FF3A30 rounded tab with a dark outline and a soft red
> glow, pointing right with its tip touching the right edge of the canvas, a
> small white skull glyph inside the tab. Bold, clean vector, readable at one
> third size. No text.

**Prompt E — `gauge_kit_preview.png`** (attach A, B, C, D):

> A review sheet on a neutral dark grey background showing the attached gauge
> assembled in six states side by side, each labelled underneath: EMPTY (dark
> master only); FLOOR 10 (the bottom five cells lit, taken from the lit
> master); FLOOR 30 (bottom fifteen lit); FULL (all lit, crown lit); TWO DOWN
> (cells up to twenty lit, cells eight and seventeen replaced by the red down
> tile); BOSS (bottom twelve lit, the boss pip just left of cell twelve). Add
> a seventh copy of FULL scaled to 40 percent. Composite the actual files; do
> not redraw them.

## 8. Delivery checklist

- Exact filenames above, lower-case, `.png`. **180 × 1440** for the three
  masters, **72 × 42** for the pip. Do not pad, crop or add a border.
- PNG-32 with an 8-bit alpha channel. Transparent outside the bar. No
  checkerboard, black or gradient baked in.
- **The three masters overlay pixel-for-pixel** — same alpha silhouette.
- Nothing crosses a band line at **y = 290 + 42·k**.
- Open the lit master at **40 %**: every district still reads as its colour,
  the lounges as wider plates, the crown as a crown (not a blob), the down
  tile as "alarm", not as "a red cell".
- Pack everything in one zip.

## 9. What NOT to do

- No numerals, letters, words or logos anywhere on the bar.
- No player marker / focus ring (that feature was retired).
- No glow or shadow that crosses a cell band line or the canvas edge.
- Do not turn the crown back into a generic emoji crown in a halo — it is
  THIS crown (`reference/crown/`).
- Do not light every cell the same colour — the five districts are the point.
- Do not make the DOWN tile a plain red cell — the top district is red.
- Do not change the canvas or the grid; the engine cuts on those lines.


---

## B. WIRING PLAN — what to do when the zip comes back (repo side, not for the generator)

Everything below is a FULL build (new GDT entries), one session, ~1 h. Do it
in this order and verify with the content-hash `.iwi` rule
(memory `verify-assets-in-artifacts`), never a raw `.ff` grep.

### B.0 AS BUILT (v16.39) — where the wiring departed from the plan below

- **Down tiles are PER CELL (`i_tod_gauge_d01..d25`), not one shared tile.**
  The plan assumed one universal down band; the slicer's uniformity check
  measured cell 13's down band against cell 25's and found ~1,900 px
  differing — the plate carries a top-to-bottom vignette under every cell, so
  a band cut at one height and stamped at another would print a faint
  rectangle of the wrong shade. The lounge cells' wider plate is the same
  problem in a stronger form. A per-cell crop composites exactly by
  construction and needs no per-cell logic in the Lua (the cell number IS the
  image name, `cellImg( "d", f )`). 25 tiny images is the whole cost.
- **The crown crop is 0..290, not 0..270** — it includes the neck, which the
  generator copies from the dark master, so the stamp cannot seam against the
  bar's shoulder whatever the crown's halo does.
- **A base tile exists (`i_tod_gauge_base`, 180×100, the lit master's base
  band).** The delivery lit the base ring in the lit master; the plan would
  have thrown that away. The Lua stamps it once `gaClimbed >= 1`, so the trail
  starts at the ground floor and the finale clock empties it with the cells.
- **The boss pip is exactly one band tall (42 art px)** and sits with its tip
  at art x 18 (the plate's left edge), i.e. on the plate's outer glow, not at
  `GA_X − 2` as the plan sketched.
- **The "crown bleed below 290" check in the plan cannot exist**: the rows
  under the crown crop are cell 25's lit lamp in the lit master, so lit-vs-dark
  there measures the lamp, not the crown. The cut row 290 itself is proven
  identical; that is the whole guarantee.
- File count: 54 written (52 new names + `_dark` and `_crown` replaced under
  their existing GDT blocks). v1's `_rung` / `_breather` / `_marker` / `_down`
  are un-zoned, blocks and PNGs left in place for a rollback.

### B.1 Receive + check (before touching the repo)

- Read every PNG header: masters 180 × 1440 colortype 6; pip 72 × 42.
- **Registration:** alpha mask of `gauge_dark` == `gauge_lit` == `gauge_down`
  (count differing alpha pixels; tolerate a few hundred, refuse thousands).
- **Band-line check:** for k = 0..25 sample the row y = 290 + 42k of the LIT
  master; it must match the DARK master's row (a glow crossing the line is a
  mismatch there).
- Downscale the lit master to 52 × 416 and LOOK at it — the crown must read.

### B.2 `tools/slice_gauge.js` (new — the zone comment names it, but it never
existed in this repo; the v1 tiles were cut wherever `files (16).zip` was made)

Node, zlib only (no PNG library in the tree — copy the PNG reader/writer
pattern from `tools/preview_crown.js`). Inputs from a delivery folder; outputs
into `source_data/tod_ui_images/_images/`:

| output | from | crop |
|---|---|---|
| `i_tod_gauge_dark.png` | dark master | whole (180 × 1440) |
| `i_tod_gauge_c01.png` .. `i_tod_gauge_c25.png` | lit master | x 0..180, y = 290 + (25 − f) × 42, 42 tall |
| `i_tod_gauge_crown.png` | lit master | x 0..180, y 0..270 (180 × 270) |
| `i_tod_gauge_down.png` | down master | cell 13's band (180 × 42) — every cell is the same tile by contract; assert cells 1, 5 and 25 crop byte-equal-ish to it |
| `i_tod_gauge_boss.png` | pip | whole (72 × 42) |

The tool asserts sizes, registration and the band-line rule, so the checks in
B.1 are mechanical on every re-bake.

### B.3 GDT + zone

- `source_data/tod_ui_images.gdt`: 27 new blocks (`i_tod_gauge_c01..c25`,
  `i_tod_gauge_boss`; `i_tod_gauge_crown` and `_down` keep their blocks, the
  PNGs change under them). Copy the `i_tod_gauge_dark` block verbatim per
  image — `sRGB3chAlpha`, uncompressed, `noMipMaps 1`, `noPicMip 1`.
- `zone_source/zm_tower_of_doom.zone` gauge block: add the 26 `image,` lines;
  drop `i_tod_gauge_rung`, `i_tod_gauge_breather`, `i_tod_gauge_marker`
  (un-zoned = unpacked; leave their GDT blocks + PNGs for a rollback). Rewrite
  the block comment — it still says "tools slice_gauge" about a tool that did
  not exist.

### B.4 `ui/uieditor/menus/hud/tod_upgrade.lua` — the TOWER GAUGE block

Only the art grid changes; `GA_X/GA_Y/GA_W/GA_H` (1216, 150, 52, 416) stay.

```lua
local function cellTop( f ) return 290 + ( GA_CELLS - f ) * 42 end   -- was 160 + ... * 48
-- crown band: ay( 0 ) .. ay( 270 )                                  -- was 140
-- cells: c:setLeftRight( true, false, ax( 0 ), ax( 180 ) )          -- was ax(30)..ax(150)
--        c:setTopBottom( true, false, ay( top ), ay( top + 42 ) )   -- was +36
--        c:setImage( RegisterImage( string.format( "i_tod_gauge_c%02d", f ) ) )
-- isBreather() goes away — the per-cell image carries the lounge look.
-- down tiles: same rect as the cells, image i_tod_gauge_down (180x42 now).
-- boss pip: GaugeBoss:setImage( RegisterImage( "i_tod_gauge_boss" ) )
--   rect: x GA_X - 72*GA_S - 2 .. GA_X - 2  (≈ 21 px wide), y = cell centre ± 21*GA_S
--   drop the setRGB (it tints an image too).
```

`GA_S = 416 / 1440` is unchanged, so on screen: cell pitch 12.1 px (was 13.9),
crown 78 px tall (was 40), pip 21 × 12 px. `tools/lint_tod_lua.js` runs on the
build; there is no runtime error channel for a wrong image name (a missing
image draws nothing), so verify each state in game: base (nothing lit), a
climb (district colours change at cells 5|6, 10|11, 15|16, 20|21), a lounge
cell, the roof (crown lights), a co-op down (red glyph tile), a Panzer round
(pip), and the finale clock (bar empties then fills).

### B.5 Downscale insurance

The engine minifies 180 → 52 px with no mips. If the delivered detail shimmers
in game, the fix is on the ASSET side: box-filter the masters to 90 × 720 (or
ask for the `@2x` set and filter that down), keep the GDT as is, re-slice. Do
not switch `noMipMaps` off as a first move — unproven for LUI images here.

### B.6 Docs owed after it lands

docs/33 (art audit) gains the gauge row; docs/63 §C.11 is superseded; this
file's STATUS line flips to SHIPPED with the build version; CHANGELOG entry
names the 27 new images and the three retired zone lines.
