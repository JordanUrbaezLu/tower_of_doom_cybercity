# 119 — HEADSHOT card re-copy (domain 6: numberless value line + 5 pips, 4 images)

<!-- art-pack
name: headshot_recopy
refs:
  i_tod_card_headshot_regular.png | THE SOURCE for the REGULAR card. Reproduce it exactly; only the value plate and the pip row change. Attach to Prompt A.
  i_tod_card_headshot_super.png | THE SOURCE for the SUPER card. Same illustration, purple treatment, 2 lit pips. Attach to Prompt B.
  i_tod_card_headshot_ultimate.png | THE SOURCE for the ULTIMATE card. Same illustration, gold treatment, 3 lit pips. Attach to Prompt C.
  i_tod_card_headshot_dark.png | THE SOURCE for the DARK card, and the COPY TARGET for the other three: its value plate already reads HEADSHOTS / HIT HARDER, which is the exact wording and two-line layout all four must end up with. Only its pip row changes. Attach to Prompt D (and to A, B and C as the copy reference).
  i_tod_card_trailblazer_regular.png | PIP ROW REFERENCE ONLY — a shipped 5-level card at REGULAR: 5 pips, 1 lit. Copy the pip COUNT, SPACING and SIZE, nothing else. Attach to Prompt A.
  i_tod_card_trailblazer_super.png | PIP ROW REFERENCE ONLY — 5 pips, 2 lit, purple. Attach to Prompt B.
  i_tod_card_trailblazer_ultimate.png | PIP ROW REFERENCE ONLY — 5 pips, 3 lit, gold. Attach to Prompt C.
  i_tod_card_trailblazer_dark.png | PIP ROW REFERENCE ONLY — 5 pips, all 5 lit red. Attach to Prompt D.
preview: 234x351
-->

> **STATUS: SHIPPED v18.43, 2026-09-08.** The drop
> (`files - 2026-09-08T105253.636.zip`) delivered all four: the numbers are gone,
> every value plate reads `HEADSHOTS` / `HIT HARDER` on two lines in that card's own
> colour, and the pip row is five with 1 / 2 / 3 / 5 lit. Nothing else moved.
> Originally requested 2026-09-08 (v18.41) — behaviour had shipped and built;
> only the baked copy was stale. Four re-bakes at the **same filenames**, so
> the install is a straight file swap — no GDT block, no zone line, no
> `CARD_SLUG` entry, no `PAUSE_PLATE_MAX` move. FULL build after install; prove
> with a fresh content-hash `.iwi` for each beside an untouched control.

## Why this exists

HEADSHOT (domain 6, ASSAULT) changed on 2026-09-08 (user: *"We will change
headshot upgrade to 12% per tier and only 5 tiers"*): **+5%/Lv over 10 levels
became +12%/Lv over 5.** `TOD_UPG_HS_PER_LVL` is 0.12 and the `add_domain` max
is 5.

That breaks the card art in **two** independent ways, and it is easy to see only
the first:

1. **The printed number is wrong.** The three light cards bake `+5% / +10% /
   +15%  HEADSHOT DMG` as pixels. The game now pays 12 / 24 / 36. The card is
   the only place a player ever reads this value, so it is the one lie no code
   change can fix.
2. **The pip count is wrong.** Per the pip rule (`[[domain-retune-checklist]]`,
   confirmed by opening the PNGs): **max ≤ 6 → pips = the domain's MAX**, and a
   flat 3 pips is the *max-10* convention. HEADSHOT was max 10 and carries 3
   pips on all four cards. At max 5 it must carry **5**. This half applies to
   the DARK card too, whose wording is already correct.

**The fix is the house rule, not a new number.** Per the standing generic-card-
text rule, the value line bakes **no figure at all** — the pause menu's `DETAIL`
row carries the live, level-aware value — so the next retune of this domain owes
no art. The wording already exists: **the DARK card has said `HEADSHOTS / HIT
HARDER` since it was baked.** The three light cards are being brought onto the
dark card's copy, not onto anything invented here.

## What changes per file

| File | Value plate | Pip row |
|---|---|---|
| `i_tod_card_headshot_regular.png` | `+5%  HEADSHOT DMG` → `HEADSHOTS / HIT HARDER` | 3 pips (1 lit) → **5 pips (1 lit)** |
| `i_tod_card_headshot_super.png` | `+10%  HEADSHOT DMG` → `HEADSHOTS / HIT HARDER` | 3 pips (2 lit) → **5 pips (2 lit)** |
| `i_tod_card_headshot_ultimate.png` | `+15%  HEADSHOT DMG` → `HEADSHOTS / HIT HARDER` | 3 pips (3 lit) → **5 pips (3 lit)** |
| `i_tod_card_headshot_dark.png` | already correct — **unchanged** | 3 pips (3 lit) → **5 pips (5 lit)** |

## Install notes (repo side, after the drop)

Same four filenames over `source_data/tod_ui_images/_images/`. No wiring of any
kind. FULL build. Proof is four fresh content-hash `.iwi` files beside an
untouched control image — never a raw `.ff` grep.

<!-- PACK:BEGIN -->
# HEADSHOT — remove the numbers, and go from 3 pips to 5, on four existing cards

## What this is

A Call of Duty: Black Ops 3 zombies map has a deck of collectible upgrade cards,
drawn at **234 x 351 px on screen** (see `preview_onscreen_234x351/` for what the
player actually sees at real size). One upgrade in that deck — HEADSHOT — was
re-tuned, and its cards are now wrong in two ways.

**This is not a new card. It is a re-bake of four cards you already have.** The
four `i_tod_card_headshot_*` images in `reference/` are the shipped originals.
Reproduce each one **exactly** — same title, same skull-and-crosshair
illustration, same colours, same frame, same rails, same screws, same star
medal, same rarity ribbon — and change only the two things below.

## Change 1 — the value plate loses its number

The dark panel at the bottom of each card currently holds **one** line with a
number in it. It must become **two** centred lines with no number:

```
HEADSHOTS
HIT HARDER
```

**You already have this exact wording and layout in the pack.**
`reference/i_tod_card_headshot_dark.png` — the red/black card — has read
`HEADSHOTS / HIT HARDER` since it was made. Match its two-line arrangement,
line break, relative type size and centring precisely. **The dark card's own
value plate does not change at all.**

Keep each card's own **colour**: the two new lines take the colour the words
`HEADSHOT DMG` use on that same card today — pale blue-white on regular, purple
on super, gold on ultimate. Do not carry the dark card's cream colour onto the
other three.

## Change 2 — the pip row goes from 3 pips to 5

The small row of dots at the very bottom of every card is a level meter. This
upgrade now has five levels instead of ten, so every card needs **five** dots
where it currently has three.

**How many are lit is per-rarity and is the one thing that differs between the
four cards:**

| Card | Pips | Lit |
|---|---|---|
| regular | 5 | 1 lit, 4 dark |
| super | 5 | 2 lit, 3 dark |
| ultimate | 5 | 3 lit, 2 dark |
| dark | 5 | **all 5 lit**, red |

The `reference/i_tod_card_trailblazer_*.png` files are shipped cards from the
same deck that already have five pips — one per rarity, so you can see all four
lit-counts. **Use them for the pip row ONLY**: its dot count, size, spacing and
lit/unlit treatment. Take nothing else from them — not their title, not their
illustration, not their wording.

The row stays horizontally centred in the same place, and the dots keep the same
size and style as the ones already on the HEADSHOT card. Five dots at the
existing size and spacing will simply be a slightly wider row than three; that is
correct — do not shrink the dots to keep the old row width.

## Deliver exactly FOUR files

| Deliver as | Size | Source to match | Value plate | Pip row |
|---|---|---|---|---|
| `i_tod_card_headshot_regular.png` | 768 x 1152 | `reference/i_tod_card_headshot_regular.png` | `HEADSHOTS` / `HIT HARDER` | 5 pips, 1 lit |
| `i_tod_card_headshot_super.png` | 768 x 1152 | `reference/i_tod_card_headshot_super.png` | `HEADSHOTS` / `HIT HARDER` | 5 pips, 2 lit |
| `i_tod_card_headshot_ultimate.png` | 768 x 1152 | `reference/i_tod_card_headshot_ultimate.png` | `HEADSHOTS` / `HIT HARDER` | 5 pips, 3 lit |
| `i_tod_card_headshot_dark.png` | 768 x 1152 | `reference/i_tod_card_headshot_dark.png` | unchanged | 5 pips, all 5 lit |

Same filenames as the sources — these replace the shipped files in place. RGBA,
**fully transparent background** (the card body sits on transparency and does not
fill the canvas), same canvas size and same margins as each source.

## Hard rules

- **No number anywhere on any of the four cards.** Not on the value plate, not
  in the panel, not in the illustration. This is the entire point of the job:
  the number is shown live elsewhere in the game, and baking one here is what
  made these cards go stale.
- **Nothing else may change.** Title plate and the word HEADSHOT, the skull with
  the crosshair over its eye, the background panel and its scanlines, the
  floating tick marks, the sparkles, the rarity ribbon (`REGULAR +1` / `SUPER
  +2` / `ULTIMATE +3` / `DARK UPGRADE`), the star medal, the side rails, the
  corner screws, the outer glow, canvas size and margins — all identical to the
  source card.
- **The colour treatment is per-rarity and must not move:** regular navy/blue,
  super purple, ultimate gold, dark red-on-black.
- **The rarity ribbon text does not change** and keeps its `+1` / `+2` / `+3`.
  Those are card-value markers, not the upgrade's value — leave them exactly as
  they are.
- **Spell it exactly:** `HEADSHOTS` / `HIT HARDER`, all caps, two lines, no full
  stop, no hyphen.
- Do not add a third line. Do not re-flow the two lines into one.
- Do not restyle, redraw or "improve" the illustration.

## Paste-ready prompts

**Prompt A — regular.** *Attach `reference/i_tod_card_headshot_regular.png`,
`reference/i_tod_card_headshot_dark.png` and
`reference/i_tod_card_trailblazer_regular.png`.*

> Reproduce the first attached game upgrade card (the blue HEADSHOT card)
> exactly, at 768 x 1152 with a fully transparent background, changing only two
> things.
> (1) In the dark value plate near the bottom, replace the single line
> `+5%  HEADSHOT DMG` with two centred lines reading `HEADSHOTS` on the first
> and `HIT HARDER` on the second. The second attached image (the red DARK card)
> already shows this exact wording and two-line layout — match its arrangement,
> line break and relative type size. Keep the pale blue-white colour that
> `HEADSHOT DMG` currently uses on the blue card; do not use the red card's
> cream colour. No number may appear anywhere on the finished card.
> (2) The small row of dots at the very bottom currently has 3 dots with 1 lit.
> Make it **5 dots with 1 lit and 4 dark**, keeping the same dot size, style and
> spacing and staying centred. The third attached image shows a shipped card
> from the same deck with the correct 5-dot row — copy only the dot row from it.
> Everything else must be identical to the first image: the HEADSHOT title
> plate, the skull with the crosshair, the background panel, the tick marks and
> sparkles, the `REGULAR +1` ribbon, the star medal, the rails, the screws, the
> margins and the transparent background.

**Prompt B — super.** *Attach `reference/i_tod_card_headshot_super.png`,
`reference/i_tod_card_headshot_dark.png` and
`reference/i_tod_card_trailblazer_super.png`.*

> Same task on the purple SUPER card. Reproduce the first attached image exactly
> at 768 x 1152, transparent background, with two changes.
> (1) Replace the value-plate line `+10%  HEADSHOT DMG` with two centred lines
> `HEADSHOTS` / `HIT HARDER`, matching the two-line layout shown on the second
> attached image (the red DARK card) but keeping the PURPLE colour the words
> `HEADSHOT DMG` currently use on this card. No number anywhere on the card.
> (2) Change the bottom dot row from 3 dots with 2 lit to **5 dots with 2 lit
> and 3 dark**, same dot size, style and spacing, centred — the third attached
> image shows the correct 5-dot row at this rarity.
> Keep the `SUPER +2` ribbon exactly as it is, and keep everything else
> identical to the first image.

**Prompt C — ultimate.** *Attach `reference/i_tod_card_headshot_ultimate.png`,
`reference/i_tod_card_headshot_dark.png` and
`reference/i_tod_card_trailblazer_ultimate.png`.*

> Same task on the gold ULTIMATE card. Reproduce the first attached image
> exactly at 768 x 1152, transparent background, with two changes.
> (1) Replace the value-plate line `+15%  HEADSHOT DMG` with two centred lines
> `HEADSHOTS` / `HIT HARDER`, matching the two-line layout shown on the second
> attached image (the red DARK card) but keeping the GOLD colour the words
> `HEADSHOT DMG` currently use on this card. No number anywhere on the card.
> (2) Change the bottom dot row from 3 dots with 3 lit to **5 dots with 3 lit
> and 2 dark**, same dot size, style and spacing, centred — the third attached
> image shows the correct 5-dot row at this rarity.
> Keep the `ULTIMATE +3` ribbon exactly as it is, keep the gold outer glow, and
> keep everything else identical to the first image.

**Prompt D — dark.** *Attach `reference/i_tod_card_headshot_dark.png` and
`reference/i_tod_card_trailblazer_dark.png`.*

> Reproduce the attached red-and-black DARK upgrade card exactly at 768 x 1152
> with a fully transparent background, changing **one** thing only: the small
> row of dots at the very bottom currently has 3 red lit dots. Make it **5 red
> dots, all 5 lit**, keeping the same dot size, style and spacing and staying
> centred. The second attached image shows a shipped card from the same deck
> with the correct all-lit 5-dot row — copy only the dot row from it.
> **The value plate is already correct and must not change**: it reads
> `HEADSHOTS` / `HIT HARDER` and stays exactly as it is, in the same cream
> colour. Everything else — the red HEADSHOT title plate, the skull with the
> crosshair, the purple/magenta panel, the `DARK UPGRADE` ribbon, the red star
> medal, the rails, the screws, the red outer glow, the margins — must be
> identical to the attached image.

## Delivery checklist

- [ ] Four PNG files, named exactly as in the table above.
- [ ] Each 768 x 1152, RGBA, fully transparent background.
- [ ] No digit and no `%` sign anywhere on any of the four cards.
- [ ] Every card's dot row has exactly **5** dots.
- [ ] Lit counts: regular 1, super 2, ultimate 3, dark 5.
- [ ] All four value plates read `HEADSHOTS` / `HIT HARDER` on two lines.
- [ ] Per-card colour kept: blue / purple / gold / red-on-black.
- [ ] Rarity ribbons untouched (`REGULAR +1`, `SUPER +2`, `ULTIMATE +3`,
      `DARK UPGRADE`).
- [ ] Laid beside its source, each card differs ONLY in the value plate and the
      dot row.

## Do NOT

- Do not bake any number, percentage or level count onto the cards.
- Do not change the illustration, the title, the ribbon or the frame.
- Do not copy TRAILBLAZER's artwork, title or wording — those files are in the
  pack purely to show the correct 5-dot row.
- Do not change the dark card's value plate text.
- Do not resize the canvas, add a background fill, or crop the margins.
- Do not shrink the dots to make five of them occupy the old three-dot width.
- Do not rename the files.
<!-- PACK:END -->
