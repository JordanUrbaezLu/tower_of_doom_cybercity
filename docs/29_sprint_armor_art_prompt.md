# 29 — SPRINT ARMOR card art: the prompt (2026-08-23)

> **STATUS: INSTALLED 2026-08-23 (v9.30)** — the user's drop `files (32).zip`
> carried all four files at the exact names/sizes; proofread on the contact
> sheet (titles, ribbons, -5/-10/-15% DAMAGE TAKEN, light line, five pips
> with 1/2/3 lit, plate r32) — clean. Wired: 4 `image.gdf` blocks + zone
> lines, `CARD_SLUG[32] = "sprint_armor"`, `PAUSE_PLATE_MAX = 32`.

Four PNGs: **3 cards (regular / super / ultimate) + 1 pause plate.** Filenames
are exact — the Lua/GDT/zone wiring keys off them. Sizes: cards **768×1152**,
plate **300×44**. Transparent outside the card edge (the existing set is).

Install rule (docs/25 §10): NEW filenames = PNG in
`source_data/tod_ui_images/_images/` + an `image.gdf` block each in
`tod_ui_images.gdt` (clone an existing card block) + an `image,` zone line
each + `CARD_SLUG[32] = "sprint_armor"` and `PAUSE_PLATE_MAX = 32` in the
Lua. Proofread the baked text on the contact sheet BEFORE building.

---

## THE PROMPT (single build-out — the style is already locked by the set)

Attach as references: `i_tod_card_sprint_regular.png`,
`i_tod_card_dmg_reduction_super.png`, `i_tod_card_draw_cut_ultimate.png`,
`i_tod_pause_r31.png`.

> You are extending an existing card set for a Call of Duty zombies map.
> The attached cards ARE the style — match them exactly: 768×1152 portrait,
> a dark navy card body with a rounded outer frame and four corner screws,
> an AMBER title plate at the top with white bold rounded caps (thick dark
> outline), an inset dark-blue "screen" panel with a faint scanline gradient
> holding a flat, bold-outlined cartoon icon with small cyan/yellow sparkle
> accents, a ribbon under the screen, a round star medal overlapping the
> ribbon's right end, a lower dark plate with a thin outline holding two
> lines of text (a bold coloured line over a light smaller line), and a row
> of pips at the bottom. Rarity frames: REGULAR = plain navy frame, silver
> ribbon "REGULAR +1", silver medal; SUPER = purple glow border + sparkles,
> purple ribbon "SUPER +2"; ULTIMATE = gold glow border + sparkles, orange
> ribbon "ULTIMATE +3", gold medal.
>
> Produce ONE new upgrade card, **SPRINT ARMOR**, as three separate 768×1152
> PNGs (one per rarity), transparent outside the card, all text baked in,
> plus one pause-menu plate. Deliver a contact sheet first so the baked text
> can be proofread, then the full-size files named exactly as listed.
>
> **Icon (the screen, identical on all three):** a running figure in
> silhouette, leaning into a full sprint with motion lines trailing behind,
> and a bold angular SHIELD plate glowing over its chest/shoulder — the
> shield reads as armor that only exists while moving. Accent colour
> **cyan `#33D9FF`** (the shield glow and the motion lines) with a single
> **violet `#BF73FF`** sparkle, because this card is shared by the
> SKIRMISHER (cyan) and the SLASHER (violet). Flat cartoon, thick outlines,
> the set's sparkle accents. No text inside the screen.
>
> **This domain has FIVE levels, so the pips are FIVE**, lit count = the
> rarity's +N (1, 2, 3 of 5). Title plate on all three: **"SPRINT ARMOR"**.
> The lower plate's bold cyan line carries the value reached with +1 / +2 /
> +3 levels; the light line is identical on all three.
>
> | file | ribbon / frame | bold line | light line | pips |
> |---|---|---|---|---|
> | `i_tod_card_sprint_armor_regular.png` | REGULAR +1, silver, plain frame | **-5% DAMAGE TAKEN** | WHILE SPRINTING · 5% PER LEVEL | ●○○○○ |
> | `i_tod_card_sprint_armor_super.png` | SUPER +2, purple, purple glow | **-10% DAMAGE TAKEN** | WHILE SPRINTING · 5% PER LEVEL | ●●○○○ |
> | `i_tod_card_sprint_armor_ultimate.png` | ULTIMATE +3, orange, gold glow | **-15% DAMAGE TAKEN** | WHILE SPRINTING · 5% PER LEVEL | ●●●○○ |
>
> **Pause-menu plate:** `i_tod_pause_r32.png`, 300×44 — the existing plate
> exactly (attach `i_tod_pause_r31.png`): a dark navy rounded bar with a
> thin outline, a small cyan notch at the left edge, white bold rounded caps
> with a dark outline, left-aligned after the notch, reading **"SPRINT
> ARMOR"**.
>
> Keep every text string exactly as written (the game reads nothing from the
> art — but players do). Everything must stay readable when the card is
> shown at 213×320.

---

## Proofreading checklist (before install)

- Title "SPRINT ARMOR" on all three; bold line -5% / -10% / -15% DAMAGE
  TAKEN matching the rarity; light line identical on the trio.
- FIVE pips, lit 1 / 2 / 3.
- Ribbon text REGULAR +1 / SUPER +2 / ULTIMATE +3 with the matching frame.
- Plate r32 reads "SPRINT ARMOR", same bar construction as r31.

## Wiring after the drop (what the session will do)

`tod_ui_images.gdt`: 4 `image.gdf` blocks; `.zone`: 4 `image,` lines;
`tod_upgrade.lua`: `CARD_SLUG[32] = "sprint_armor"`;
`AetheriumStartMenu.lua`: `PAUSE_PLATE_MAX = 32`. Then one `-GscOnly` build.
