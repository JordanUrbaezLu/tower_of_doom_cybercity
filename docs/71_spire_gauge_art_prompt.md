# 71 — THE ENDLESS SPIRE GAUGE: art prompt pack (3 masters + 3 optional) + wiring plan

> **STATUS: ART DELIVERED AND WIRED, v16.44 (2026-09-02) — UNPLAYED.**
> User: *"I need a new zip cause we need new assets for endless spire. Thats a
> completely different tower so needs consistent UI pngs."* Sister of docs/70
> (the tower gauge v2, wired v16.39). Pack:
> `~/Downloads/tod_spire_gauge_art_pack.zip`; the drop came back as
> `files (99).zip` — three registered masters, `spire_won.png`, the preview,
> AND the trial-won banner (§4 #6), all from the generator's own procedural
> pipeline (`build_spire_gauge.py`, shipped in the nested zip). Slicer checks:
> 0 silhouette px differ across all four masters, 0 px on every cut row, neck
> identical, every hub plate distinct. **§B.0 records what was built.**
>
> **THE BUG THIS ALSO FIXES:** `_tod_gauge::floor_of` maps world z straight to
> the 25-cell tower grid. The Spire climbs from z ≈ 0 to 38,400 on its own
> axis, so after ascension the bar fills through Spire floors 1–50 and then
> sits FULL WITH THE CROWN LIT for floors 51–100 — the half of the hard mode
> where the party most needs an altimeter shows nothing. The art is 50 cells
> because the mode switch below is what makes the art mean anything.

**Design decisions taken in the brief** (do not re-litigate): same 180 × 1440
canvas and 52 × 416 slot; **50 cells at pitch 21 from y 290** (two floors per
cell, the rate the user accepted for the tower — the half-height cells are the
"twice the tower" read); **hub plates on every 5th cell** (5..50 = floors
10..100, the lounge rhythm); summit band 0..290; base 1340..1440; palette =
crimson plate, RED keyline (the trial banners' identity), red lamps, GOLD hubs
and summit; **DOWN tile is WHITE with a red cross** (the inverse of the
tower's, because the Spire's lit cells are red); no numerals; the tower's boss
pip is reused. The 25-cell alternatives were rejected on arithmetic: 4 floors
per cell puts the hubs on cells 3/5/8/10/13… (uneven), 20 cells × 5 floors
makes every other cell a hub.

---

## A. THE BRIEF — verbatim copy of the pack's `INSTRUCTIONS.md`

# TOWER OF DOOM: CYBERCITY — THE ENDLESS SPIRE GAUGE (art brief for the asset model)

You are the art director and image generator for the HUD of **Tower of Doom:
Cybercity**, a Call of Duty: Black Ops III custom zombies map. You already
delivered the **TOWER GAUGE v2** (the tall bar on the right edge of the screen;
your masters are in `reference/tower_gauge_v2/`, including your own
`build_gauge_v2.py`). This job is its **SISTER SET for THE ENDLESS SPIRE** —
the map's post-victory hard mode, a completely different tower the party
teleports to after winning the first one. The moment they arrive, the HUD
swaps the gauge to this set, so it must read as **the same instrument
re-skinned for a different tower**: same plate, same construction, same
on-screen slot — the Spire's colours, the Spire's floors, the Spire's summit.

**Open the references first; this text only describes them.** Attach the
named files to every generation. If you can, **extend `build_gauge_v2.py`**
with a Spire profile (new grid constants, new palette, same frame code) —
that guarantees pixel registration and chassis consistency for free.

---

## 1. The Spire (context you need)

- A **100-floor spiral stair** around a square core, standing on its own to
  the east of the first tower. **Monochrome red**: red-glowing landings and
  edge lines, red parapets, a red core; only the stair treads are dark blue.
  On this map red means danger, and the Spire is the danger tower.
- **Every 10th floor is a HUB HALL** (floors 10, 20 … 100): the core opens
  into a drum-shaped hall with a **gold band** on its outer face, gold floor
  and gold parapets — a **gold ring on the red tower**. The hubs are where the
  WARDEN TRIALS happen (a 90-second hold-out that seals the hall); the
  trial banners in `reference/spire_ui/` are the established Spire UI look.
- **The summit** (floor 100's roof): a square **gold deck** with a gold rim
  rail and a gold apron, and in the middle a **three-tier tapering gold
  mast** (512 tall) with a **red head and a red beacon light** on top. When
  the party wins, the beacon **strobes green**.
- **The base**: the arrival arena — a red-walled square plaza where the party
  materialises on an arrival ring.
- Same on-screen slot as the tower gauge: **52 × 416 px on a 1280 × 720
  layout** (≈ 78 × 624 at 1080p), right screen edge, nothing near it. So the
  art is drawn at **29 % of its size at 720p, 43 % at 1080p**, no mip-mapping:
  no hairlines under 3 px, no fine texture, no type.
- **How the engine draws it** (same as the tower gauge): the DARK master is
  the backing; a LIT tile — a **full-width band cut from the LIT master at
  the cell's exact pixel rows** — is stamped on every cell at or below the
  player; the SUMMIT band is stamped on the roof; the BASE band lights with
  the first cell; a DOWN tile replaces a cell holding a downed teammate; the
  same red skull BOSS PIP from the tower set is drawn left of the bar (no
  new pip needed). No cropping, tinting or animation in the engine: every
  state is one of these PNGs, so the masters must line up pixel for pixel.
- During a trial the bar becomes the **hold-out clock** (it empties, then
  fills bottom-to-top over the 90 s). So **no floor numbers in the cells** —
  the lit trail must read as "progress" in either role.

## 2. THE GRID — 50 cells, because the Spire is twice the tower

The tower gauge has 25 cells at two floors each. The Spire keeps **two floors
per cell** (the progress rate players already know) and therefore has **50
cells, each half the height** — the bar itself says "this tower is twice as
tall". The **hub floors (10, 20 … 100) land on every 5th cell (5, 10 … 50)**,
exactly the rhythm the tower's lounges have, so a hub cell is a **wider plate**
the same way a lounge cell is.

Canvas **180 wide × 1440 tall**, PNG-32 (RGBA), transparent outside the bar.
`LAYOUT_GUIDE_spire.png` is the colour-coded diagram of this table:

| zone | y (top .. bottom) | notes |
|---|---|---|
| **SUMMIT** | 0 .. 270 | full 180 width; the summit sits on the bar's top cap |
| **NECK** | 270 .. 290 | the bar's top cap / shoulder — identical in every master |
| **CELL 50** | 290 .. 311 | top cell — floors 99–100, a HUB cell |
| … | pitch **21** | cell *f* spans **y = 290 + (50 − f) × 21** to +21 |
| **CELL 1** | 1319 .. 1340 | bottom cell — floors 1–2 |
| **BASE** | 1340 .. 1440 | the arrival arena cap |

- Lamp column **x 30 .. 150**; **hub plates (cells 5, 10, 15 … 50) are wider
  chamfered plates, up to x 22 .. 158**, that break the rail line. Frame and
  rails x 18 .. 162; glows may reach x 0 .. 180.
- **Each cell's plate + glow stays INSIDE its own 21-px band** with ≥ 3 px of
  plate-dark margin above and below the lamp (lamp body ≈ 14–15 px tall).
  The engine cuts on **y = 290 + 21·k (k = 0 .. 50)**; a glow crossing a line
  is clipped and shows as a hard edge on the trail's top cell.
- A cell is **6 px tall on screen at 720p, 9 px at 1080p**. So: **no glyphs
  inside regular cells** — a lamp is a bold bar of light, nothing more. The
  hub plate's read is its width and its gold. The only glyph in the set is
  on the DOWN tile (§4.3).
- **The three masters must be PIXEL-REGISTERED**: identical silhouette,
  frame, cell plates, summit outline and base; only the state changes.
  Overlay them — nothing may shift.

## 3. The palette (the Spire's, on the HUD's chassis)

- **Plate:** the tower gauge's plate construction (rounded slab, vignette
  lighter toward the top, thin keyline + darker inner keyline, soft outer
  glow) — but the plate fill is **black-to-crimson** (`#12060A` → `#2A0A10`)
  and the keyline + glow are the Spire's **red** (`#FF4D4D`), not cyan. This
  is what the trial banners do (`reference/spire_ui/i_tod_trial_1.png`): dark
  crimson Tron-grid plate, red rim glow, gold accents.
- **Lit cells:** **red** `#FF4D4D` — the same red as the tower's top district,
  so the trail continues the colour the player last saw on the tower.
- **Hub cells (5, 10 … 50):** **gold** `#FFD959`, on the wider plate, with a
  brighter core — the gold ring on the red tower.
- **Summit:** gold `#FFE45C` / `#C9A52E`, the mast head and beacon red.
- **Base:** crimson plate, the arrival ring in red.
- **DOWN tile:** **white plate** `#F4F6FA` with a **red cross** `#FF3A30` and a
  thin red keyline — the INVERSE of the tower's red-with-white-cross, and for
  the same reason it had a white glyph there: the Spire's lit cells are red,
  so a red down tile would vanish among them. A white bar in a red stack is
  unmissable at 6 px; the cross is the bonus at higher resolutions.
- Faint **gold circuit tracery** on the frame (as on the trial banners) is
  welcome if it survives the downscale. No text, no numerals, no logos.

## 4. Deliverables (exact filenames)

| # | file | size | what it is |
|---|---|---|---|
| 1 | `spire_dark.png` | 180 × 1440 | UNLIT master |
| 2 | `spire_lit.png` | 180 × 1440 | FULLY LIT master |
| 3 | `spire_down.png` | 180 × 1440 | DOWN master (every cell in the down state) |
| 4 | `spire_kit_preview.png` | any (e.g. 1600 × 1600) | review sheet |
| 5 | *(optional)* `spire_won.png` | 180 × 1440 | the LIT master with the beacon GREEN — the win state |
| 6 | *(optional)* `i_tod_trial_won.png` | 2048 × 512 | the trial-won banner (§5, prompt F) |

1. **`spire_dark.png` — UNLIT master.** Fifty empty cell plates on the
   crimson plate, each carrying a faint (≈ 15 %) red tint; the ten HUB plates
   (cells 5, 10 … 50) wider and chamfered, with a faint gold tint instead of
   red; small tick marks on the rails at every hub. The **SUMMIT** in the
   0..270 band as a **dim, unlit silhouette**: the square gold deck with its
   rim rail, the three-tier tapering mast, a dark beacon head. The **BASE**
   cap as the arrival plaza: a crimson plate with a thin dim red ring.
2. **`spire_lit.png` — FULLY LIT master.** Identical layout; every regular
   cell a glowing **red** bar (bright core, hairline top highlight, soft
   bloom inside its band); every HUB cell a glowing **gold** bar on its wider
   plate; the summit **lit** — gold deck and mast glowing, the **beacon
   burning red** with a soft red halo; the base ring lit red. Neck and frame
   identical to the dark master.
3. **`spire_down.png` — DOWN master.** Identical layout; **EVERY cell (all
   50, hubs included) in the down state**: the plate filled **white** with a
   bold **red cross** centred in it and a thin red keyline, a soft white
   glow inside the band; on the hub cells the white covers the whole wider
   plate. Summit and base as in the dark master.
4. **`spire_kit_preview.png` — review sheet.** The bar in six states on a
   neutral dark grey: empty; floor 20 (cells 1–10 lit); floor 60 (1–30);
   full with the summit lit; cells 12 and 33 DOWN with everything up to cell
   40 lit; the tower set's boss pip beside cell 25 with 1–25 lit. Add the
   tower gauge v2 FULL state beside them at the same scale, so we see the two
   sets as siblings — and one Spire FULL at 40 %.
5. **Optional `spire_won.png`:** `spire_lit.png` with only the beacon and its
   halo turned **green** (`#4DFF88`). We crop its summit band for the win.
6. **Optional `i_tod_trial_won.png`:** see §5, prompt F.

## 5. Prompts (paste verbatim; attach the named references)

**Prompt A — `spire_dark.png`** (attach `reference/tower_gauge_v2/gauge_dark.png`,
`LAYOUT_GUIDE_spire.png`, `reference/spire_ui/i_tod_trial_1.png`,
`reference/spire_ui/i_tod_spire_banner.png`):

> A tall vertical HUD gauge for a cyberpunk zombies game, exactly 180 by
> 1440 pixels, PNG with a fully transparent background — the sister of the
> attached tower gauge, built on the identical plate: same rounded slab
> silhouette, same margins, same keyline construction and outer glow, but
> the plate fill is black-to-crimson and the keyline and glow are blood red
> (#FF4D4D) instead of cyan, with faint gold circuit tracery on the frame
> like the attached trial banner. Clean Tron-grid vector style, no text, no
> numbers, no logos. From the top: a dim, unlit summit filling the top 270
> pixels — a square gold platform with a thin rim rail, a three-tier
> tapering gold mast rising from its centre with a dark beacon head on top —
> rendered as a muted silhouette; then a short cap; then FIFTY empty
> rounded cell plates stacked at exactly 21 pixel pitch inside a 120 pixel
> wide column, each faintly tinted red; every fifth plate counted from the
> bottom (the 5th, 10th, 15th … 50th) is a wider chamfered hexagonal plate
> that breaks the rail line, faintly tinted gold; small tick marks on the
> rails at those plates; at the bottom a base cap shaped like a small
> crimson plaza plate with a thin dim red ring. Match the layout guide
> exactly. Fifty plates at 21 pixel pitch — count them.

**Prompt B — `spire_lit.png`** (attach Prompt A's result,
`reference/tower_gauge_v2/gauge_lit.png`):

> The identical gauge as the attached, exactly 180 by 1440 pixels, same
> silhouette, frame and layout pixel-for-pixel, now FULLY LIT: every one of
> the fifty cell plates filled with a glowing neon bar — blood red #FF4D4D
> on the regular plates, gold #FFD959 on the ten wider plates — each with a
> bright core, a hairline top highlight and a soft bloom that stays inside
> its own 21 pixel band; the summit at the top now lit — gold platform and
> mast glowing, the beacon on the mast burning red with a soft red halo; the
> base ring glowing red. Nothing else changes.

**Prompt C — `spire_down.png`** (attach Prompt A's result,
`reference/tower_gauge_v2/gauge_down.png`):

> The identical gauge as the attached, exactly 180 by 1440 pixels, same
> silhouette, frame and layout pixel-for-pixel, with every one of the fifty
> cell plates in a DOWNED state: the plate filled solid white #F4F6FA with a
> bold red #FF3A30 cross centred in it and a thin red keyline, a soft white
> glow that stays inside the band; the ten wider plates use the same white
> treatment covering their whole wider shape; summit and base unlit exactly
> as in the attached. No text.

**Prompt D — `spire_won.png`** (optional; attach Prompt B's result):

> The identical gauge as the attached, exactly 180 by 1440 pixels, pixel for
> pixel the same, with one change: the beacon on the summit mast and its
> halo are green #4DFF88 instead of red. Nothing else changes.

**Prompt E — `spire_kit_preview.png`** (attach A, B, C, the tower set's
`gauge_boss.png` and `gauge_lit.png`):

> A review sheet on a neutral dark grey background showing the attached Spire
> gauge assembled in six labelled states side by side: EMPTY; FLOOR 20 (the
> bottom ten cells lit, from the lit master); FLOOR 60 (bottom thirty lit);
> FULL (all lit, summit lit); TWO DOWN (cells up to forty lit, cells twelve
> and thirty-three replaced by the white down tile); BOSS (bottom
> twenty-five lit, the attached red skull pip just left of cell
> twenty-five). Then the attached TOWER gauge fully lit at the same scale
> for comparison, and one Spire FULL scaled to 40 percent. Composite the
> actual files; do not redraw them.

**Prompt F — `i_tod_trial_won.png`** (optional; attach
`reference/spire_ui/i_tod_trial_1.png` and `i_tod_trial_10.png`):

> A wide HUD event banner, exactly 2048 by 512 pixels, PNG with a
> transparent background outside the plate, in the identical style as the
> attached trial banners: the same dark crimson Tron-grid plate with a red
> rim glow and gold circuit tracery, the same margins. Instead of a numeral
> bar and a name, the plate reads a small gold word TRIAL above a large
> white glowing title THE TRIAL IS WON, with a subtle gold radial burst
> behind the letters and the plate's rim glow shifted to gold. No other
> text, no characters.

## 6. Delivery checklist

- Exact filenames, lower-case. **180 × 1440** for every master; 2048 × 512
  for the banner. Do not pad, crop or add a border.
- PNG-32 with an 8-bit alpha channel; transparent outside the bar; no
  backdrop baked in.
- **Fifty cells.** Count them. Cell 1's band is y 1319..1340, cell 50's is
  290..311.
- **The masters overlay pixel-for-pixel** (same alpha silhouette); nothing
  crosses a band line at **y = 290 + 21·k**.
- Open the lit master at **40 %**: the hub cells read gold among red, the
  summit reads as a platform with a mast, the down tile reads white.
- One zip. Reusing `build_gauge_v2.py` with a Spire profile is the easiest
  way to hit every line above.

## 7. What NOT to do

- No numerals, letters, words or logos on the bar. No glyphs in regular cells.
- No 25-cell layout — this set is 50 cells; the tower set stays 25.
- No red DOWN tile — the lit cells are red; the down tile is white.
- No cyan keyline — the Spire's identity is red on crimson with gold.
- Do not draw a crown on the summit; the Spire's top is a gold deck and mast.
- No glow or shadow across a band line or the canvas edge.


---

## B. WIRING PLAN — when the zip comes back (repo side, not for the generator)

A FULL build (new GDT entries). Read docs/70 §B.0 first — every lesson there
(per-cell tiles, the crown crop including the neck, the base tile, the pip
placement, what a "bleed" check can and cannot measure) carries over.

### B.0 AS BUILT (v16.44) — where the wiring departed from the plan below

- **Slicer:** a `PROFILES` table in the one tool, as planned; the spire
  profile also cuts `i_tod_spire_summit_won` from `spire_won.png` when
  present, and the tool now proves the won master differs from the lit one
  ONLY inside the summit band. Both profiles re-checked green on both drops.
- **Down mask:** FOUR 13-bit chunks (`[k]` = cells 13k+1..13k+13) on two
  2-arg events, `tod_down` + `tod_down2`, exactly as planned; the Lua unpacks
  by `chunk = floor((i-1)/13)`, `bit = (i-1) mod 13` — the tower's old
  13/12 split is the same arithmetic, so v16.39's lane is unchanged.
- **Mode:** LEVEL-wide from `level.tod_spire_active` / `level.tod_spire_won`
  (no new latch); value 2 = summit won, which the Lua uses only to swap the
  summit tile. The mode lane is sent FIRST in the tick and drops the floor +
  down caches, so a swap and its first paint land within one 0.35 s tick.
- **Arena z:** the spire's arrival arena stands AT z = 0 (the tower's is
  below the deck), so `floor_of` reads the first `TOD_GAUGE_FLOOR_EPS` (8)
  units as the base in spire mode — otherwise the arrival ring lit cell 1.
- **Trial-won plate:** wired in this build (not in the plan): `trial_banner`
  took a `mat_override`, called at the win with `"tod_trial_won"`.
- **The tier-gate 20 → 30 change** landed in `_tod_gauge.gsc`'s header from
  session 48 (v16.43) while this was being wired; both edits coexist.

### B.1 Slicer: `tools/slice_gauge.js --spire`

Add a PROFILE to the existing tool rather than a second tool: `{ prefix:
"i_tod_spire_", cells: 50, pitch: 21, cell0: 290, topCrop: 290, files:
spire_dark/lit/down(.png), optional spire_won }`. Outputs:
`i_tod_spire_dark`, `i_tod_spire_c01..c50`, `i_tod_spire_d01..d50`,
`i_tod_spire_summit` (lit 0..290), `i_tod_spire_base` (lit 1340..1440), and
`i_tod_spire_summit_won` (from `spire_won.png` 0..290) when delivered. Same
checks: sizes, registration, every cut row `290 + 21k` (k = 0..50) identical
across masters, the neck identical. **103–104 images**; the tower set added
54 for +240 KB of `.ff`, so expect ~+0.5 MB.

### B.2 GDT + zone

Clone the `i_tod_gauge_dark` block per name (a node one-liner, as v16.39
did); one `image,` line each in the gauge block of the `.zone`, under their
own comment. The tower set stays zoned — both sets are live in one match.

### B.3 `_tod_gauge.gsc` — a MODE, not a second module

- **Mode source:** the ascension latch `_tod_spire` already sets on
  `tod_ascend` (read the file for its name — do not add a second flag). The
  whole party ascends together and one way, so mode is LEVEL-wide, not
  per-player; `tod_spire_data::in_spire( org )` exists if a per-player
  position test is ever wanted.
- **`cells_for_mode()`** → 25 or 50; **`floor_of()`** in spire mode: real
  floor = `1 + int( ( z - spire_base_z ) / 384 )` clamped 1..100, cell =
  ceil( floor / 2 ) → 1..50, summit (z ≥ 38400) → 51. `boss_floor()` and
  `down_cell_of()` clamp to `cells_for_mode()`; `finale_cell()` (the trial
  clock rides this lane) scales to it too, so a trial fills 50 cells.
- **New `tod_gauge_mode` eventstring** (1 arg: 0 tower, 1 spire), `#precache`d
  (the silent-no-fire trap), sent on change and **re-armed per life** at the
  `_tod_upgrade_ui.gsc` reopen site next to `tod_gauge_f` — the fresh menu
  must learn the mode BEFORE the next `tod_floor` push lands.
- **The down mask outgrows two 13-bit args**: 50 cells is 50 bits. Keep the
  proven 2-arg shape and add a second event `tod_down2` for cells 27..50
  (13 + 12 again), or accept a 4-arg call (stock ships 4/5/7-arg
  LuiNotifyEvents but this tree has never fired one). Two events is the
  no-new-claims route; `TOD_GAUGE_MASK_SPLIT` stays LOCKSTEP with the Lua.

### B.4 `tod_upgrade.lua` — a second element set, driven by `gaMode`

- Pre-build the Spire set beside the tower set: `GaugeCellsSp[1..50]`,
  `GaugeDownSp[1..50]` (rects `ax(0)..ax(180)` × `ay(top)..ay(top+21)`,
  images `i_tod_spire_c%02d` / `d%02d`), `GaugeSummit` (`ay(0)..ay(290)`),
  `GaugeBaseSp`. All alpha 0 until mode 1. ~104 more elements on a menu that
  already holds ~55 for this widget — cheap, and the same pre-built pattern.
- `GaugeDark:setImage` swaps to `i_tod_spire_dark` on mode 1 (the tower's
  cells/crown/base go alpha 0 in the same handler). `gaApplyCells` walks
  `cells_for_mode()` and the mode's arrays. The top-of-bar rule becomes
  `f > cells` → summit/crown.
- **Boss pip**: still `i_tod_gauge_boss`, 42 art px tall; on a 21-px cell
  centre it: `top = cellTop_sp( bf ) - 10.5`.
- Optional win state: on `tod_extract`/summit win, `GaugeSummit:setImage(
  i_tod_spire_summit_won )` — only if `spire_won.png` was delivered.

### B.5 Verify (the harness in `tools/spire_wip/HARNESS.md` is the fast path)

Ascend → the bar swaps to crimson/red with the summit dim and the base ring
lit; climb → red cells, a gold cell at every hub (floors 10/20…); a trial →
the bar empties and fills over 90 s in 50 cells; a co-op down → a WHITE cell;
a Warden → the skull pip; the summit → the summit lights (green if the won
tile shipped). Prove packing with the content-hash `.iwi` rule + a control
(memory `verify-assets-in-artifacts`), never a raw `.ff` grep.

### B.6 Docs owed after it lands

This file's STATUS flips; docs/44 gets a HUD row; docs/70 §B.0 gains a
cross-reference; CHANGELOG names the image count and the two new
eventstrings; the memory `pending-tower-gauge-v2` gets the Spire sibling.
