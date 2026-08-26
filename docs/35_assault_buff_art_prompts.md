# 35 — Assault buff (2026-08-26) card art: the prompts

> **STATUS: COMPLETE 2026-08-26.** All nine cards installed from the user drop
> `files (44).zip` — exact filenames, all 768x1152, md5-verified into
> `source_data/tod_ui_images/_images/`. The contact sheet (`rebake9_check.png`)
> proofread clean against the six-point checklist at the bottom of this file:
> HEADSHOT +4/+8/+12 with "4% PER LEVEL", GIANT SLAYER +4/+8/+12 on five pips
> with both subline clauses, RECOIL −10/−20/−20 on two pips with the wide minus
> and `· MAX` on SUPER and ULTIMATE only. Spot-checked three at full size
> against the outgoing art: pixel-faithful, only the two value-plate lines moved.
> No wiring was needed — every one of the nine already had its zone line and its
> GDT block. Nothing outstanding.

The user's brief: *"the Assault class need a minor buff. The headshot damage
needs to be 4% for each level and boss damage also 4% per level. Recoil will go
to 10% per level. … We will need new prompts to get the updated assets for the
upgrade menu."*

## What changed, and therefore what must be re-baked

| domain | id | max | old | **new** | cards |
|---|---|---|---|---|---|
| HEADSHOT | 6 | 10 | +3% / Lv | **+4% / Lv** | 3 |
| GIANT SLAYER | 35 | 5 | +3% / Lv | **+4% / Lv** | 3 |
| RECOIL | 17 | 2 | −8 / −16% | **−10 / −20%** | 3 |

**Nine files, all RE-BAKES at identical filenames** — so there is **no wiring
work at all**: no `image.gdf` block, no zone line, no `CARD_SLUG`, no
`PAUSE_PLATE_MAX`. Drop the PNGs in `source_data/tod_ui_images/_images/`,
overwriting, and rebuild.

```
i_tod_card_headshot_regular.png       i_tod_card_headshot_super.png       i_tod_card_headshot_ultimate.png
i_tod_card_giant_slayer_regular.png   i_tod_card_giant_slayer_super.png   i_tod_card_giant_slayer_ultimate.png
i_tod_card_recoil_regular.png         i_tod_card_recoil_super.png         i_tod_card_recoil_ultimate.png
```

**The pause plates do NOT change.** `i_tod_pause_r06/r17/r35.png` are 300×44
name-only strips ("HEADSHOT", "RECOIL", "GIANT SLAYER") with no numbers on them
— verified by opening them. The pause-menu *numbers* come from the Lua DETAIL
table, which is already updated. Likewise `i_tod_up_headshot.png` /
`i_tod_up_recoil.png` are icon-only.

## Exact text, per card (this is the whole job)

Everything else on these nine cards must come back **pixel-identical**. Only the
two text lines in the bottom plate change.

| file | big value line | small subline |
|---|---|---|
| `headshot_regular` | `+4%  HEADSHOT DMG` | `4% PER LEVEL` |
| `headshot_super` | `+8%  HEADSHOT DMG` | `4% PER LEVEL` |
| `headshot_ultimate` | `+12%  HEADSHOT DMG` | `4% PER LEVEL` |
| `giant_slayer_regular` | `+4%  BOSS DAMAGE` | `BOSSES AND ELITES ONLY · 4% PER LEVEL` |
| `giant_slayer_super` | `+8%  BOSS DAMAGE` | `BOSSES AND ELITES ONLY · 4% PER LEVEL` |
| `giant_slayer_ultimate` | `+12%  BOSS DAMAGE` | `BOSSES AND ELITES ONLY · 4% PER LEVEL` |
| `recoil_regular` | `−10%  RECOIL` | `KICK REDUCED` |
| `recoil_super` | `−20%  RECOIL` | `KICK REDUCED · MAX` |
| `recoil_ultimate` | `−20%  RECOIL` | `KICK REDUCED · MAX` |

RECOIL caps at **2** levels, so SUPER (+2) and ULTIMATE (+3) both land on −20%
and both keep the `· MAX` suffix — that is correct, not a copy-paste error, and
it matches how the −8/−16/−16 set already shipped.

---

## THE PROMPT

Attach as references: `i_tod_card_headshot_ultimate.png`,
`i_tod_card_recoil_regular.png`, `i_tod_card_giant_slayer_regular.png`,
`i_tod_card_headshot_super.png`. These four cover all three rarity frames and
all three illustrations.

> You are re-baking nine cards from an existing upgrade-card set for a Call of
> Duty: Black Ops III custom zombies map. **The attached images ARE the target
> style and the target artwork — this is a text-only revision.** Reproduce each
> card exactly as it is, changing ONLY the two lines of text in the bottom
> value plate. Do not redraw, restyle, recolour, re-crop or "improve" the
> illustrations, the frame, the title plate, the ribbon, the medal or the pips.
>
> **Canvas:** 768 × 1152 px portrait PNG, transparent everywhere outside the
> card's rounded outer edge. The card fills the canvas with a small transparent
> margin all round (larger on the glowing rarities, to hold the glow).
>
> **Card anatomy, top to bottom** (identical on all nine):
>
> 1. **Outer body** — a dark navy rounded-rectangle slab with a thick near-black
>    rounded border, and a second thin inner border line inside it. Four
>    cross-head screw heads, one at each corner, sitting just inside the border.
> 2. **Title plate** — a wide amber-to-orange vertical-gradient rounded bar
>    across the top, inset from the card edges, with a row of seven small round
>    rivets along its top edge (alternating pale yellow and grey). The domain
>    name sits centred on it in a **heavy rounded sans-serif, all caps, white,
>    with a thick dark navy outline and a subtle drop shadow** — a chunky
>    cartoon-game letterform, tightly spaced, optically filling the plate width.
> 3. **Screen panel** — a large inset rounded-square panel below the title,
>    dark blue with a subtle vertical gradient (lighter at the top), very faint
>    horizontal scanlines, and a soft elliptical highlight sheen across the top
>    third. A thick dark rounded border. Four tiny pixel squares sit in the
>    panel's corners as accents: **cyan** top-left, **white** top-right,
>    **amber** bottom-left.
> 4. **Illustration** — a flat, boldly black-outlined cartoon icon centred in
>    the screen panel, drawn in the chunky vector style of a mobile-game power-up
>    icon: flat fills, no gradients inside the shapes, no texture, no realism.
>    (Per-card subjects below.)
> 5. **Ribbon** — a horizontal rounded banner overlapping the bottom edge of the
>    screen panel, with a small dark arrowhead notch protruding at each end. It
>    carries the rarity text in the same heavy white outlined caps as the title.
> 6. **Star medal** — a circular medallion with a raised rim and a five-pointed
>    star embossed in its centre, overlapping the ribbon's **right** end and the
>    screen panel's bottom-right corner.
> 7. **Value plate** — a dark rounded panel below the ribbon with a thin
>    coloured inner outline and four small round bolts (one per corner of the
>    outer plate). Inside it, two centred lines: a **large bold value line**
>    where the percentage is coloured and the label following it is in the same
>    weight, and beneath it a **smaller, wider-letter-spaced subline** in a pale
>    desaturated blue-grey.
> 8. **Pip row** — small circles centred along the very bottom of the card,
>    inside the outer border. Unlit pips are near-black with a dark rim; lit
>    pips are filled in the rarity colour with a matching rim.
>
> **The three rarity frames:**
>
> - **REGULAR (+1)** — no outer glow. Plain dark navy frame. Ribbon is a
>   **silver / light-grey** gradient reading `REGULAR +1`. The star medal is
>   **silver**. Two slim **cyan** vertical light bars run down the outer left and
>   right edges of the card body. The value plate's inner outline is a muted
>   teal. The big percentage is **pale silver-white**; the label beside it is the
>   same pale silver-white. Lit pips are **white**. No sparkles in the screen.
> - **SUPER (+2)** — a soft **violet/lavender outer glow** haloing the whole
>   card, and the frame border picks up a purple line. Ribbon is **purple**
>   reading `SUPER +2`. The star medal is **gold**. The two side light bars are
>   **purple**. The value plate's inner outline is purple. The big percentage and
>   its label are **bright purple/orchid**. Lit pips are **purple**. Add **two
>   small purple "kick" chevrons** floating in the screen panel as motion
>   accents — one upper-left, one lower-right — drawn as simple thick bent lines
>   (like a stylised ricochet mark), not as arrows.
> - **ULTIMATE (+3)** — a warm **gold/peach outer glow**, a **gold** frame
>   border, and small **four-pointed sparkle stars** scattered around the border
>   margin (both black and gold ones, evenly distributed). Ribbon is
>   **orange** reading `ULTIMATE +3`. The star medal is **gold**. The side light
>   bars are **gold**. The value plate's inner outline is gold. The big
>   percentage and its label are **golden yellow**. Lit pips are **gold**. In the
>   screen panel add **three or four bent "kick" chevrons** — two yellow, one
>   red — plus a couple of extra tiny amber pixel squares.
>
> **The three illustrations — reproduce these exactly as in the references:**
>
> - **HEADSHOT** — a white/pale-grey cartoon skull facing forward and slightly
>   turned, with a thick black outline and a soft grey shade down its left side.
>   Its left eye socket (viewer's left) is a plain black oval; over its right eye
>   socket sits a **magenta-pink crosshair**: a ring with four tick marks at 12,
>   3, 6 and 9 o'clock and a small magenta dot at the centre, drawn *over* a
>   black pupil-dot. A small black angular triangle forms the nose. Below the
>   cranium sits a separate blocky jaw of **four square white teeth** with black
>   dividers. A short black tick-mark crack sits at the upper left of the
>   cranium.
> - **RECOIL** — a **cyan circular crosshair** centred in the panel: a bold
>   cyan ring with four cyan tick marks at 12, 3, 6 and 9 o'clock and a
>   **magenta dot** at its exact centre. Four grey right-angle corner brackets
>   frame it in a square. Above the ring, three stacked **orange chevrons**
>   pointing upward, the topmost largest and most saturated and the lower two
>   progressively smaller and more transparent, reading as upward muzzle climb.
>   Below the ring, a single grey chevron pointing downward.
> - **GIANT SLAYER** — a large, hunched, front-facing **armoured mech boss** in
>   dark slate-blue greys with black outlines, filling most of the panel: a small
>   head with a horizontal **orange visor slot**, big angular shoulder pauldrons
>   canted outward, two blocky arms with rounded fists at the bottom, and a broad
>   chest plate. Dead centre on the chest is a **bright orange cracked impact
>   star** — a spiky radial burst with a white-hot core — being struck by a
>   **white bullet** entering from the right, with two short grey motion dashes
>   trailing behind it. Two thin antennae angle up from the shoulders.
>
> **Typography rules:** every piece of text on the card is the same heavy
> rounded sans-serif, all caps. Title and ribbon text are white with a thick
> dark outline. The value line is coloured per rarity, has no outline, and its
> percentage and label are set at the same size with a wide gap between them.
> The subline is noticeably smaller, letter-spaced wide, and pale blue-grey.
> Use a middle dot `·` with spaces either side where a subline has two clauses.
>
> **Deliverables:** first a single **contact sheet** showing all nine cards at
> small size so the baked text can be proofread, then the nine full-size
> 768 × 1152 PNGs named exactly:
>
> ```
> i_tod_card_headshot_regular.png        +4%  HEADSHOT DMG   /  4% PER LEVEL                          / 3 pips, 1 lit
> i_tod_card_headshot_super.png          +8%  HEADSHOT DMG   /  4% PER LEVEL                          / 3 pips, 2 lit
> i_tod_card_headshot_ultimate.png       +12% HEADSHOT DMG   /  4% PER LEVEL                          / 3 pips, 3 lit
> i_tod_card_giant_slayer_regular.png    +4%  BOSS DAMAGE    /  BOSSES AND ELITES ONLY · 4% PER LEVEL / 5 pips, 1 lit
> i_tod_card_giant_slayer_super.png      +8%  BOSS DAMAGE    /  BOSSES AND ELITES ONLY · 4% PER LEVEL / 5 pips, 2 lit
> i_tod_card_giant_slayer_ultimate.png   +12% BOSS DAMAGE    /  BOSSES AND ELITES ONLY · 4% PER LEVEL / 5 pips, 3 lit
> i_tod_card_recoil_regular.png          −10% RECOIL         /  KICK REDUCED                          / 2 pips, 1 lit
> i_tod_card_recoil_super.png            −20% RECOIL         /  KICK REDUCED · MAX                    / 2 pips, 2 lit
> i_tod_card_recoil_ultimate.png         −20% RECOIL         /  KICK REDUCED · MAX                    / 2 pips, 2 lit
> ```
>
> Note the pip counts differ per domain and are **not** all three: HEADSHOT uses
> a flat 3 (its real cap is 10, which would be illegible at display size),
> GIANT SLAYER uses 5 (its real cap), RECOIL uses 2 (its real cap, which is why
> SUPER and ULTIMATE both show both pips lit and both read MAX).
>
> **The negative RECOIL values use a WIDE MINUS (U+2212, −), not an ASCII
> hyphen.** The three shipping RECOIL cards are baked with the wide glyph, and a
> narrower dash reads as a different font sitting next to the other cards. If in
> doubt, match the dash in `i_tod_card_recoil_regular.png` exactly: roughly as
> wide as a digit, same stroke weight, vertically centred on the digits.

---

## Proofreading checklist (do this on the contact sheet before installing)

1. HEADSHOT reads **+4 / +8 / +12**, never 3/6/9. Subline says **4% PER LEVEL**
   on all three.
2. GIANT SLAYER reads **+4 / +8 / +12**. Subline keeps **both** clauses and the
   middle dot, with **4% PER LEVEL**.
3. RECOIL reads **−10 / −20 / −20** set with a WIDE MINUS (U+2212), and `· MAX` appears on SUPER **and**
   ULTIMATE but **not** on REGULAR.
4. Pip counts are 3 / 5 / 2 by domain, lit 1-2-3 (clamped to 2 for RECOIL).
5. Ribbon text and medal colour match the rarity (silver medal only on REGULAR).
6. Filenames are byte-exact — a typo here silently keeps the old card in the
   build, because the zone line points at the name.

## Install

Overwrite the nine PNGs in `source_data/tod_ui_images/_images/` and run a
**full** `.\tools\build_map.ps1` (an image change is an asset change, not a
GSC change). No `.gdt`, `.zone` or Lua edits are needed for a re-bake.
