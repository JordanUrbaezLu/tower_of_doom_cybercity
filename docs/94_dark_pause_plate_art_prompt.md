# 94 — DARK PAUSE PLATES: a red variant of 24 pause-menu name plates

<!-- art-pack
name: dark_pause_plates
refs:
  i_tod_pause_r01.png | DAMAGE - the plate to recolour. TEMPLATE SUBJECT in Prompt 1.
  i_tod_pause_r02.png | DMG REDUCTION - the plate to recolour.
  i_tod_pause_r03.png | BOUNTY - the plate to recolour.
  i_tod_pause_r04.png | LUCK - the plate to recolour.
  i_tod_pause_r05.png | SPRINT - the plate to recolour.
  i_tod_pause_r06.png | HEADSHOT - the plate to recolour.
  i_tod_pause_r08.png | SCAVENGER - the plate to recolour. The LONGEST word in the set - check it still fits after any type change.
  i_tod_pause_r10.png | BULLET FEED - the plate to recolour.
  i_tod_pause_r13.png | LEECH - the plate to recolour. The SHORTEST word in the set.
  i_tod_pause_r14.png | CLEAVE - the plate to recolour.
  i_tod_pause_r20.png | THOR'S THUNDER - the plate to recolour. The only one with an apostrophe.
  i_tod_pause_r23.png | RUN AND GUN - the plate to recolour.
  i_tod_pause_r25.png | ADRENALINE - the plate to recolour.
  i_tod_pause_r26.png | OVERDRIVE - the plate to recolour.
  i_tod_pause_r35.png | GIANT SLAYER - the plate to recolour.
  i_tod_pause_r36.png | BACK ARMOR - the plate to recolour.
  i_tod_pause_r37.png | FORCED MARCH - the plate to recolour.
  i_tod_pause_r38.png | VITALITY - the plate to recolour.
  i_tod_pause_r39.png | RECOVERY - the plate to recolour.
  i_tod_pause_r42.png | FULL STEAM - the plate to recolour.
  i_tod_pause_r43.png | ATHLETE - the plate to recolour.
  i_tod_pause_r44.png | GUNSLINGER - the plate to recolour.
  i_tod_pause_r45.png | RIOT SHIELD - the plate to recolour.
  i_tod_pause_r46.png | TRAILBLAZER - the plate to recolour.
preview: 210x31
-->

> **STATUS: PACK READY, NOT SENT. 2026-09-04.**

**Why (user, 2026-09-04):** *"Pause menu yes. We may need new assets for this and
we for sure need updated descriptions for the new levels. Maybe a red upgrade
plate when you have dark upgrade. That would require a zip."*

## Scope — 24, and only 24

These are the name plates in the pause menu's YOUR UPGRADES panel. There are 47
of them, but only **24 abilities can hold a dark upgrade** (the mirror of
`set_no_dark()` in `_tod_upgrades.gsc`), and a plate for an ability that can
never go dark is dead load RAM. The excluded ids are 7, 15, 16, 17, 18, 19, 21,
29, 31, 33, 40, 41, 47 — plus every id with no live domain.

**This is CHEAP, unlike the cards.** A plate is 300x44, so 24 of them cost about
**1.3 MiB** of load RAM against the dark cards' ~81 MiB. That is why it is worth
real art rather than the runtime tint.

## It already works without this

`AetheriumStartMenu.lua` tints the existing plate red (`setRGB( 1.0, 0.34, 0.36 )`)
when a row is dark, so the feature is COMPLETE and readable today. That tint is a
real fallback, not a placeholder: `setRGB` is multiplicative, so it pushes the
plate red and darkens it, which is the right direction — it simply cannot add a
glow, change the type colour independently, or brighten anything.

**Install:** drop the 24 into `source_data/tod_ui_images/_images/`, add a GDT
block and an `image,` line each, then flip `USE_DARK_PLATE_ART` in
`AetheriumStartMenu.lua`. All three in the same commit — `RegisterImage` on an
unzoned name is undefined behavior. FULL build; proof = 24 fresh content-hash
`.iwi` beside an untouched control.

<!-- PACK:BEGIN -->
# DARK PAUSE PLATES — a red variant of 24 name plates

## What this is

These are name plates from the pause menu of a Black Ops 3 zombies map. Each one
is a small horizontal bar carrying one ability's name, and they stack in a list
so the player can see everything they own.

**We are adding a fourth, highest tier called DARK UPGRADE**, and a plate needs a
RED variant that is shown when the player holds the dark version of that ability.
Same plate, same word, same everything — the colour is the whole change.

Every file is **300 x 44 px** and is drawn at **210 x 31 px** on a 1080p screen —
see `preview_onscreen_210x31/`. That is small. Judge every decision at that size:
these are read in a list at a glance, not studied.

## The job in one line

**Take each plate, keep its shape and its word exactly, and re-theme it from its
current colour to dark red.**

## What must not change

1. **The word.** Same text, same font, same size, same position, same letter
   spacing. Do not re-typeset, re-wrap, abbreviate or re-kern anything.
2. **The shape.** Same 300 x 44 canvas, same bar silhouette, same corners, same
   transparent margin. These are drawn over a live menu, so the alpha channel
   must match the source exactly.
3. **Pixel registration.** Overlay your result on the source at 100% — nothing
   should move by a pixel.

## What changes

**The plate goes red.** Deep, slightly desaturated crimson rather than a bright
primary red — this sits behind body text in a dark menu and a hot red vibrates
against it. Whatever accent, edge light or gradient the source plate has should
follow the same shift rather than being deleted.

**The word must stay at least as readable as it is now.** That is the one hard
constraint and the one failure mode this job has: a red plate with the name
sunk into it is worse than no plate. If the current type is light on a darker
bar, keep it light. Do not tint the TEXT red.

## References (in `reference/`)

All 24 current plates, unmodified — these are the INPUTS, one per output.
`reference/README.md` names each one, and `preview_onscreen_210x31/` shows every
one at its real on-screen size.

Worth opening first, because they bracket the set:

- `i_tod_pause_r08.png` — SCAVENGER, the longest word. If anything about the
  type changes, this is where it overflows.
- `i_tod_pause_r13.png` — LEECH, the shortest. Lots of empty bar; the treatment
  has to still look intentional with little text on it.
- `i_tod_pause_r20.png` — THOR'S THUNDER, the only apostrophe in the set.

## Deliverables — 24 files, exact names

Each output is its source filename with `_dark` appended.

| Deliver as | Built from | Word on the plate |
|---|---|---|
| `i_tod_pause_r01_dark.png` | `i_tod_pause_r01.png` | DAMAGE |
| `i_tod_pause_r02_dark.png` | `i_tod_pause_r02.png` | DMG REDUCTION |
| `i_tod_pause_r03_dark.png` | `i_tod_pause_r03.png` | BOUNTY |
| `i_tod_pause_r04_dark.png` | `i_tod_pause_r04.png` | LUCK |
| `i_tod_pause_r05_dark.png` | `i_tod_pause_r05.png` | SPRINT |
| `i_tod_pause_r06_dark.png` | `i_tod_pause_r06.png` | HEADSHOT |
| `i_tod_pause_r08_dark.png` | `i_tod_pause_r08.png` | SCAVENGER |
| `i_tod_pause_r10_dark.png` | `i_tod_pause_r10.png` | BULLET FEED |
| `i_tod_pause_r13_dark.png` | `i_tod_pause_r13.png` | LEECH |
| `i_tod_pause_r14_dark.png` | `i_tod_pause_r14.png` | CLEAVE |
| `i_tod_pause_r20_dark.png` | `i_tod_pause_r20.png` | THOR'S THUNDER |
| `i_tod_pause_r23_dark.png` | `i_tod_pause_r23.png` | RUN AND GUN |
| `i_tod_pause_r25_dark.png` | `i_tod_pause_r25.png` | ADRENALINE |
| `i_tod_pause_r26_dark.png` | `i_tod_pause_r26.png` | OVERDRIVE |
| `i_tod_pause_r35_dark.png` | `i_tod_pause_r35.png` | GIANT SLAYER |
| `i_tod_pause_r36_dark.png` | `i_tod_pause_r36.png` | BACK ARMOR |
| `i_tod_pause_r37_dark.png` | `i_tod_pause_r37.png` | FORCED MARCH |
| `i_tod_pause_r38_dark.png` | `i_tod_pause_r38.png` | VITALITY |
| `i_tod_pause_r39_dark.png` | `i_tod_pause_r39.png` | RECOVERY |
| `i_tod_pause_r42_dark.png` | `i_tod_pause_r42.png` | FULL STEAM |
| `i_tod_pause_r43_dark.png` | `i_tod_pause_r43.png` | ATHLETE |
| `i_tod_pause_r44_dark.png` | `i_tod_pause_r44.png` | GUNSLINGER |
| `i_tod_pause_r45_dark.png` | `i_tod_pause_r45.png` | RIOT SHIELD |
| `i_tod_pause_r46_dark.png` | `i_tod_pause_r46.png` | TRAILBLAZER |

The "Word on the plate" column is there so you can PROOFREAD what is already
baked into each source, not so you can re-set it. If a source plate disagrees
with this column, say so rather than changing it.

## Hard rules

1. **300 x 44 px, PNG-32, alpha preserved and matching the source exactly.**
2. **One recipe across all 24.** This is a set and it must still match itself.
   Set the treatment once and apply it — no per-file judgement, no auto-tone,
   no auto-contrast, no auto-levels.
3. **The word stays as legible as it is now, minimum.** Check at 210 x 31.
4. **No new elements.** No icons, no glow blobs, no borders that were not there,
   no "DARK" label. The list already shows dark differently by colour alone.

## Delivery checklist

- [ ] 24 files, exact names from the table
- [ ] every file 300 x 44, PNG-32, alpha matching the source
- [ ] overlaid on the source at 100%: nothing moved
- [ ] every word proofread against the table, unchanged
- [ ] each one downscaled to 210 x 31 and still readable
- [ ] the three bracket plates (SCAVENGER, LEECH, THOR'S THUNDER) checked at that size
- [ ] one recipe across the whole set

## Do NOT

- Do **not** change the canvas size, the bar shape, or the transparent margin.
- Do **not** re-typeset, re-position, abbreviate or re-kern any word.
- Do **not** tint the TEXT red — it is the plate that goes red, not the name.
- Do **not** use a hot primary red; it vibrates against a dark menu at this size.
- Do **not** add any new graphic element.
<!-- PACK:END -->
