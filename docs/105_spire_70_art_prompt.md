# 105 — THE ENDLESS SPIRE GOES TO FLOOR 70: seven halls with personality, a 35-cell gauge, the top as the boss floor (design + art pack)

<!-- art-pack
name: spire_70
refs:
  docs/105_spire_ref/spire_dark_current.png | THE CURRENT SPIRE GAUGE, UNLIT master (180x1440, 50 cells at pitch 21). The chassis, palette and summit to KEEP. Re-grid it to 35 cells at pitch 30. Attach to every gauge prompt.
  docs/105_spire_ref/spire_lit_current.png | THE CURRENT SPIRE GAUGE, FULLY LIT master, reassembled from the shipped tiles. Red lamps, gold hub plates, lit summit and base ring. The lit treatment to keep at the new pitch. Attach to every gauge prompt.
  docs/105_spire_ref/spire_down_current.png | THE CURRENT SPIRE GAUGE, DOWN master, reassembled: every cell white with a red cross. The down treatment to keep at the new pitch. Attach to the down prompt.
  i_tod_spire_summit_won.png | The summit band with the beacon GREEN (the won state). Only the beacon changes between lit and won. Attach to the won prompt.
  i_tod_gauge_dark.png | The TOWER gauge (the sister instrument, 25 cells at pitch 42) for scale and family resemblance. Context only.
  i_tod_trial_1.png | THE CURRENT TRIAL I BANNER: the plate, the numeral bar, the gold TRIAL, the white name, the faint glyph. The series chassis to keep. Attach to every banner prompt.
  docs/105_spire_ref/i_tod_trial_10_retired.png | THE OLD TRIAL X BANNER (retired from the game in v17.69, kept here as a reference): shows how the numeral grows and the plate reddens by the last trial. Attach to every banner prompt.
  i_tod_trial_won.png | THE TRIAL IS WON plate, shipping and unchanged. Shows the gold-shifted rim glow treatment. Context only.
preview: 52x416 600x150
-->

> **STATUS: SHIPPED v17.70 (drop `files - 2026-09-05T014400.611.zip`, 2026-09-05 01:44, installed the same hour) — UNPLAYED.** All seven banners (the nested set; the two loose re-encodes were pixel-identical) copied over the same names; the four gauge masters cut by `slice_gauge.js --spire --band-tol 140 --write` — the delivery draws every plate edge-to-edge in its band (no plate-dark margin), so every cut row is a plate outline that is bright lit / dim dark (110-124 px of 180): the trail's top is a lit plate under a dark one, not a seam. Inspected on `docs/105_spire_ref/delivered_review_gauge.png` before the override was used; the banners' sheet is `delivered_review_trials.png` beside it.
>
> **(Original) STATUS: COMMISSIONED 2026-09-05 (v17.69).** User: *"Can we make the
> endless spire tower go to floor 70 instead of 100? ... update on the right
> side tower progression HUD ... compact 1-10 difficulties into 7 ... bigger
> jumps ... now its only 7 boss fights we can give the rooms more personality
> ... after the 7th trial the next level leads to the top of the tower where we
> will have a boss fight. For now we can just have an extraction up there."*
> Pack built by `.\tools\make_art_pack.ps1 docs\105_spire_70_art_prompt.md` →
> `~/Downloads/tod_spire_70_art_pack.zip`.
>
> **The code side shipped in the same build (v17.69) and does not wait for the
> art**: the spire is 70 laps, seven hub halls, the ladder is seven steps, the
> gauge is 35 cells. Until the drop lands the HUD stamps the OLD 21-px tiles
> into 30-px cells over the OLD 50-plate dark master (lit bars land between
> plates — ugly, not broken), and trials II / III / V / VII show the OLD names
> on their banners (THE CROSS / THE COLONNADE / THE BAFFLES / THE CHECKER).
>
> **Install when the drop comes back:**
> 1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` — LOOK at every file,
>    proofread the seven names and numerals, overlay the four masters.
> 2. Gauge: put the four masters in one folder and run
>    `node tools/slice_gauge.js <folder> --spire` (dry run, every check green)
>    then `--write`. It overwrites `i_tod_spire_dark/summit/summit_won/base`
>    and cuts `c01..c35` / `d01..d35`. No zone or GDT change (v17.69 already
>    trimmed the set to 35).
> 3. Banners: copy `i_tod_trial_1..7.png` over the same names. No wiring.
> 4. FULL build; proof = fresh content-hash `.iwi` beside an untouched control.
> 5. Flip this STATUS to SHIPPED.

## A. THE DESIGN (repo-facing; what v17.69 built)

### A.1 Seventy floors, seven halls, the top is the boss floor

| what | was (v14.0 – v17.68) | now (v17.69) |
|---|---|---|
| spire laps | 100 (`SP_LAPS`) | **70** |
| summit deck z | 38 592 | **27 072** (`SP_TOP2`, derived) |
| hub halls / trials | 10 (floors 10..100) | **7 (floors 10..70)** |
| doors | 100 sequential | **70** |
| spawn zones | 20 chunks of 5 | **14** chunks of 5 |
| trial ladder | ×1.08 per trial, trial X = ×2.00 of trial I | **×1.1225 per trial, trial VII = ×2.00 of trial I** (same top, bigger jumps) |
| trial purse | 5000 + 1000 per tier, X paid 14 000 | 5000 + **1500** per tier, **VII pays 14 000** |
| gauge | 50 cells, pitch 21, hub plate every 5th | **35 cells, pitch 30**, hub plate every 5th (cells 5..35) |
| banners | TRIAL I..X | **TRIAL I..VII**, one colour per hall |

**The top.** Hub 70's hall is the last trial. Its S flight climbs inside the
drum to the SE landing and the gold SUMMIT STAIR rises from there to the
summit deck — one flight, the same shape hub 100 had. That deck is where the
BOSS FIGHT will live; for now the EXTRACTION pad (7500) stands there,
sealed until trial VII is won, exactly as before. The boss arena is a
follow-up: the deck is a 512-square plaza + a 960×224 apron, which is a
holdout, not an arena, and enlarging it is its own geometry pass.

**Why 70 and not 71.** `SP_LAPS` must be EVEN (the summit flight and the
hub furniture are authored for the frame parity produces, and the generator
refuses odd on purpose). A 71st regular floor between trial VII and the top
would mean mirroring the whole summit block into the odd frame. The summit
stair IS the "next level" — it starts at the last trial's hall and ends at
the top. If a full extra floor is wanted, that is the parity-mirror job.

### A.2 The seven halls — one personality each

> **SUPERSEDED for the FLOOR PLANS by docs/109 (v17.84):** the names, colours
> and fights below stand; the rooms were rebuilt per trial (own floor, walls,
> liner, lamps, set-piece). Read docs/109 §B for what each hall IS now.

Every hall keeps the drum, the porch entrance, the hall gate, the galleries,
the seven risers and the vendors. What changes per hall, all from ONE row in
`SP_RM_LAYOUTS` (generator) + ONE case in `trial_recipe` (`_tod_spire.gsc`):

- **the floor plan** (the feature vocabulary: pillar / post / wall / dais / big),
- **the colour** — the four corner lights and the central pool take the hall's
  hue (`hue` on the row; the drum band and floor stay GOLD so the tower still
  reads "gold ring every 10th" from outside), and a 1u-proud floor SIGIL
  inlay in that colour draws the hall's emblem around the trial mark,
- **the fight** — which elite family carries the adds, how many Wardens, when
  the frenzy comes,
- **the banner** — same plate, the numeral and rim glow in the hall's colour,
  the hall's glyph.

| # | floor | name | colour | floor plan | the fight |
|---|---|---|---|---|---|
| I | 10 | **THE RING** | gold | four pillars at the corners of a square | one Warden and its Rogue Protectors. Nothing else. The lesson. Frenzy in the last third. |
| II | 20 | **THE KENNEL** | green | the cross: four low walls make four pens | hellhound packs (4 on the leash) + one protector. Frenzy in the last third. |
| III | 30 | **THE FIRING LINE** | cyan | the colonnade: two rows of three pillars, three lanes | three protectors firing down the lanes, a Reaver at the back. Frenzy in the last third. |
| IV | 40 | **THE ALTAR** | purple | a three-tier dais with four pillars around it | TWO Wardens; Reavers take the high ground with you (2), a protector and a hound. Frenzy in the last third. |
| V | 50 | **THE MAZE** | orange | the baffles plus two posts: no straight line longer than a room | armored sprinters round every corner (3), hounds (2), a protector; TWO Wardens. **Frenzy at the halfway mark.** |
| VI | 60 | **THE GAUNTLET** | white | two long walls make one lane, a pillar on each flank | THREE Wardens down the lane, three protectors on the flanks, sprinters (2), a Reaver. **Frenzy at the halfway mark.** |
| VII | 70 | **THE THRONE** | red | the great plinth (160 sq, 240 tall) with two pillars flanking it | FOUR Wardens (the cap), every family (3/2/3/3), **the whole trial a frenzy.** The top is one flight up. |

The ladder rides on top: trial n's elites carry `TOD_TRIAL_HP_MULT ×
TOD_TRIAL_STEP^(n-1)` (0.956 × 1.1225^(n-1): I ×0.96, II ×1.07, III ×1.20,
IV ×1.35, V ×1.52, VI ×1.70, VII ×1.91 — the old trial X's number) and the
adds' cadence tightens by the same factor from 5.75 s.

### A.3 The gauge grid (LOCKSTEP trio)

`tools/slice_gauge.js` spire profile · `tod_upgrade.lua` `SP_CELLS/SP_PITCH` ·
`_tod_gauge.gsc` `TOD_GAUGE_SPIRE_LAPS/CELLS`. 35 cells × 30 px = 1050 =
1340 − 290, so the summit band (0..290), neck (270..290) and base (1340..1440)
are untouched — the tower's masters and the spire's share every cut except
the cell rows. Two floors per cell still. Hub floors 10..70 → cells 5..35.
The down mask keeps its 13/13/9 split over `tod_down` + `tod_down2`.

<!-- PACK:BEGIN -->
# TOWER OF DOOM: CYBERCITY — THE ENDLESS SPIRE AT 70 FLOORS (2 jobs, 12 files)

You are the art director and image generator for the HUD of **Tower of Doom:
Cybercity**, a Call of Duty: Black Ops III custom zombies map. You delivered
the **ENDLESS SPIRE GAUGE** (the tall bar on the right screen edge) and the
**TRIAL I..X banners**. The Spire has been **shortened from 100 floors to
70**, its ten trials **compacted to seven**, and each of the seven trial
halls now has its own **personality and colour**. Two jobs come out of that:

- **JOB 1 — re-grid the Spire gauge to 35 cells** (4 masters + 1 review sheet).
- **JOB 2 — seven new trial banners** (7 files), same series, new names, one
  colour per hall.

**Open `reference/` first; this text only describes the files there.** Attach
the named files to every generation. If you still have the procedural
pipeline you built the gauge with (`build_spire_gauge.py`), **change its grid
constants and re-run it** — that guarantees pixel registration for free.

---

## JOB 1 — THE SPIRE GAUGE, 35 CELLS

### What stays exactly the same
Canvas **180 × 1440**, PNG-32, transparent outside the bar. The plate, the red
keyline and glow, the gold circuit tracery, the SUMMIT band (**y 0..270**, the
gold deck + three-tier mast + red beacon), the NECK (**270..290**) and the BASE
cap (**1340..1440**, the crimson plaza plate with the red ring) are
**pixel-identical to the current masters** in `reference/`. Only the cell
column changes.

### The new grid — 35 cells at pitch 30

The Spire is 70 floors, two floors per cell, so the column between the neck
and the base (y 290..1340, 1050 px) holds **35 cells of exactly 30 px**:

| zone | y (top .. bottom) | notes |
|---|---|---|
| SUMMIT | 0 .. 270 | unchanged |
| NECK | 270 .. 290 | unchanged, identical in every master |
| **CELL 35** | 290 .. 320 | top cell — floors 69–70, a HUB cell |
| … | pitch **30** | cell *f* spans **y = 290 + (35 − f) × 30** to +30 |
| **CELL 1** | 1310 .. 1340 | bottom cell — floors 1–2 |
| BASE | 1340 .. 1440 | unchanged |

- **HUB plates on cells 5, 10, 15, 20, 25, 30, 35** (= floors 10..70): the
  wider chamfered plate, gold-tinted, with the rail tick marks — the same
  construction as now, seven of them instead of ten.
- Each cell's plate + glow stays **inside its own 30-px band** with ≥ 4 px of
  plate-dark margin above and below the lamp (lamp body ≈ 20–22 px tall). The
  engine cuts on **y = 290 + 30·k, k = 0..35**; anything crossing a line
  clips to a hard edge.
- On screen a cell is **8.7 px at 720p, 13 px at 1080p** — a taller lamp than
  before, so the bar reads a little brighter and the hub plates a little
  bolder. Still no glyphs in regular cells.
- **The four masters must be PIXEL-REGISTERED** (identical alpha silhouette);
  overlay them, nothing may shift.

### Deliverables (exact filenames)

| # | file | size | what it is |
|---|---|---|---|
| 1 | `spire_dark.png` | 180 × 1440 | UNLIT master, 35 empty plates (7 hub plates), summit dim, base dim |
| 2 | `spire_lit.png` | 180 × 1440 | FULLY LIT master: 28 red lamps, 7 gold hub lamps, summit lit, beacon RED, base ring lit |
| 3 | `spire_down.png` | 180 × 1440 | DOWN master: all 35 cells white with the red cross, summit + base as dark |
| 4 | `spire_won.png` | 180 × 1440 | the LIT master with only the beacon + halo GREEN (#4DFF88) |
| 5 | `spire_kit_preview.png` | any | review sheet (below) |

**Prompt A — `spire_dark.png`** (attach `spire_dark_current.png`,
`i_tod_gauge_dark.png`):

> The identical HUD gauge as the attached Spire gauge — exactly 180 by 1440
> pixels, PNG with a transparent background, the same rounded crimson plate,
> the same blood-red keyline and glow, the same gold circuit tracery, the
> same unlit gold summit platform with its three-tier mast and dark beacon
> in the top 270 pixels, the same crimson base plaza plate with its dim red
> ring in the bottom 100 pixels — but the cell column between y 290 and
> y 1340 is REBUILT with THIRTY-FIVE empty rounded cell plates at exactly
> 30 pixel pitch instead of fifty at 21, each faintly tinted red, and every
> fifth plate counted from the bottom (the 5th, 10th, 15th, 20th, 25th, 30th
> and 35th) is the wider chamfered hexagonal hub plate faintly tinted gold
> with small tick marks on the rails. Thirty-five plates at 30 pixel pitch —
> count them. Everything outside the cell column is pixel-identical to the
> attached.

**Prompt B — `spire_lit.png`** (attach Prompt A's result,
`spire_lit_current.png`):

> The identical gauge as the attached, exactly 180 by 1440 pixels, same
> silhouette, frame and layout pixel-for-pixel, now FULLY LIT exactly as the
> attached current lit master is lit: every one of the thirty-five cell
> plates filled with a glowing neon bar — blood red #FF4D4D on the regular
> plates, gold #FFD959 on the seven wider hub plates — each with a bright
> core, a hairline top highlight and a soft bloom that stays inside its own
> 30 pixel band; the summit lit, gold platform and mast glowing, the beacon
> burning red with a soft red halo; the base ring glowing red. Nothing else
> changes.

**Prompt C — `spire_down.png`** (attach Prompt A's result,
`spire_down_current.png`):

> The identical gauge as the attached, exactly 180 by 1440 pixels, same
> silhouette, frame and layout pixel-for-pixel, with every one of the
> thirty-five cell plates in the DOWNED state exactly as the attached current
> down master shows it: the plate filled solid white #F4F6FA with a bold red
> #FF3A30 cross centred in it and a thin red keyline, a soft white glow that
> stays inside the band; the seven wider hub plates use the same white
> treatment over their whole wider shape; summit and base unlit exactly as
> in the dark master. No text.

**Prompt D — `spire_won.png`** (attach Prompt B's result,
`i_tod_spire_summit_won.png`):

> The identical gauge as the attached, exactly 180 by 1440 pixels, pixel for
> pixel the same, with one change: the beacon on the summit mast and its
> halo are green #4DFF88 instead of red, exactly as in the attached won
> summit band. Nothing else changes.

**Prompt E — `spire_kit_preview.png`** (attach A, B, C, D):

> A review sheet on a neutral dark grey background showing the attached Spire
> gauge assembled in six labelled states side by side: EMPTY; FLOOR 20 (the
> bottom ten cells lit); FLOOR 50 (bottom twenty-five lit); FULL (all
> thirty-five lit, summit lit); TWO DOWN (cells up to thirty lit, cells nine
> and twenty-two replaced by the white down tile); WON (all lit, the green
> beacon). Then one Spire FULL scaled to 43 percent — the 1080p size.
> Composite the actual files; do not redraw them.

---

## JOB 2 — SEVEN TRIAL BANNERS

Same series as the current TRIAL I..X banners in `reference/` (open
`i_tod_trial_1.png` and `i_tod_trial_10_retired.png`; `i_tod_trial_won.png` is the WON
plate that follows every banner — context for the gold rim treatment, it
ships as is and is NOT to be redrawn): **2048 × 512**, transparent
outside the plate, the black-to-crimson Tron-grid plate with gold circuit
tracery, a huge glowing roman numeral in the left third, **TRIAL** small in
gold above the hall's name in white condensed all-caps neon, and a faint
line-art glyph of the hall behind the text. Shown at 600 × 150 on a 1280 × 720
layout (900 × 225 at 1080p).

**What is new:** seven halls, seven names, and **each banner carries its
hall's colour** — the numeral's neon and the plate's rim glow take the
colour; TRIAL stays gold, the name stays white, the plate stays crimson. The
glyph is drawn in the hall's colour at low opacity. Trial I is gold and
trial VII is red, so the series starts where the tower's gold hubs are and
ends on the Spire's own red.

| file | numeral | name | colour (numeral + rim + glyph) | glyph |
|---|---|---|---|---|
| `i_tod_trial_1.png` | I | THE RING | gold `#FFD959` | four small squares at the corners of a square |
| `i_tod_trial_2.png` | II | THE KENNEL | green `#4DFF88` | a plus sign dividing a square into four pens |
| `i_tod_trial_3.png` | III | THE FIRING LINE | cyan `#4DE8FF` | two vertical rows of three dots with three arrows running between them |
| `i_tod_trial_4.png` | IV | THE ALTAR | purple `#B36BFF` | three concentric squares with a dot at each outer corner |
| `i_tod_trial_5.png` | V | THE MAZE | orange `#FF9A3D` | four short staggered horizontal bars with two dots between them |
| `i_tod_trial_6.png` | VI | THE GAUNTLET | white `#F4F6FA` | two long parallel vertical lines with a dot outside each |
| `i_tod_trial_7.png` | VII | THE THRONE | red `#FF4D4D` | one large solid square, centred, a small square either side |

**Prompt F — one per banner** (attach `i_tod_trial_1.png` and
`i_tod_trial_10_retired.png`; fill the braces from the table):

> Cyberpunk zombies-map event banner, exactly 2048 by 512 pixels, PNG with a
> transparent background outside the plate, in the identical style as the
> attached trial banners: the same black-to-crimson Tron-grid plate with
> thin gold circuit tracery, the same margins and typeface. Left third: a
> huge glowing roman numeral "{NUMERAL}" in {COLOUR} neon with a gold inner
> stroke. Right two-thirds: "TRIAL" small in gold above the hall's name
> "{NAME}" in white neon, condensed all-caps. The plate's rim glow is
> {COLOUR} instead of red. Behind the text a faint line-art glyph of the
> hall in {COLOUR} at low opacity: {GLYPH}. No characters, no other text.

## Delivery checklist

- Exact filenames, lower-case. **180 × 1440** for the four masters; **2048 ×
  512** for the seven banners. Do not pad, crop or add a border.
- PNG-32 with an 8-bit alpha channel; transparent outside the art.
- **Thirty-five cells.** Count them. Cell 1's band is y 1310..1340, cell 35's
  is 290..320. Hub plates on 5/10/15/20/25/30/35.
- The four masters overlay pixel-for-pixel; nothing crosses a band line at
  **y = 290 + 30·k**; the summit band, neck and base are byte-identical to the
  current masters.
- Proofread the seven names and numerals against the table. VII is the last.
- Open the lit master at **43 %**: the hub cells read gold among red, the
  summit reads as a platform with a mast, the down tile reads white.
- One zip. Twelve files.

## What NOT to do

- No numerals, letters or logos on the gauge. No glyphs in regular cells.
- Not 50 cells, not 25 — this set is **35**. The tower set is untouched.
- Do not redraw the summit, neck or base; do not move the column.
- No cyan keyline on the gauge — the Spire's identity is red on crimson with
  gold. (Cyan is trial III's banner colour only.)
- No eighth banner, no "TRIAL VIII..X", no won plate — the won plate ships as
  is.
- No glow or shadow across a band line or the canvas edge.
<!-- PACK:END -->
