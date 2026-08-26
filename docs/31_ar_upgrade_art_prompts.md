# 31 — AR upgrade pass (v9.45) card art: the prompts (2026-08-23)

> **HISTORICAL. THREE OF THESE FIVE WERE RE-BAKED AGAIN ON 2026-08-26** (the
> Assault buff): HEADSHOT is now +4/+8/+12%, GIANT SLAYER +4/+8/+12%, RECOIL
> −10/−20/−20%. The prompts below describe the SUPERSEDED v9.45 values and are
> kept only as the record of that pass. Current prompts: docs/35.

> **STATUS: INSTALLED 2026-08-23 (v9.45)** — the user's drop `files (38).zip`
> carried all 17 files at the exact names and sizes (15 cards 768x1152, 2 plates
> 300x44). Both contact sheets proofread clean: GIANT SLAYER +3/+6/+9% with five
> pips lit 1/2/3, BACK ARMOR -10/-20/-30% with three pips and MAX on the
> ULTIMATE, HEADSHOT +3/+6/+9% with the new light line, RECOIL -8/-16/-16% on
> **two** pips with MAX on SUPER and ULTIMATE, IMPACT ROUNDS 3/6/9%. Wired: 8
> `image.gdf` blocks + 8 zone lines (re-bakes reuse their existing ones),
> `CARD_SLUG[35] = "giant_slayer"`, `CARD_SLUG[36] = "back_armor"`,
> `PAUSE_PLATE_MAX = 36`.

Five cards in total, in two groups:

| group | slug | files | wiring needed |
|---|---|---|---|
| **NEW** | `giant_slayer` | 3 cards + `i_tod_pause_r35.png` | GDT + zone + `CARD_SLUG[35]` + `PAUSE_PLATE_MAX` |
| **NEW** | `back_armor` | 3 cards + `i_tod_pause_r36.png` | GDT + zone + `CARD_SLUG[36]` + `PAUSE_PLATE_MAX` |
| **RE-BAKE** | `headshot` | 3 cards | **none** — same filenames, drop-in |
| **RE-BAKE** | `recoil` | 3 cards | **none** — same filenames, drop-in |
| **RE-BAKE** | `impact_rounds` | 3 cards | **none** — same filenames, drop-in |

Sizes: cards **768×1152**, plates **300×44**. Transparent outside the card
edge. All text baked in — the game reads nothing from the art, but players do.

Install rule (docs/25 §10): NEW filenames = PNG in
`source_data/tod_ui_images/_images/` + an `image.gdf` block each in
`tod_ui_images.gdt` (clone an existing card block) + an `image,` zone line
each + `CARD_SLUG[35] = "giant_slayer"` / `CARD_SLUG[36] = "back_armor"` and
`PAUSE_PLATE_MAX = 36` in the Lua. **RE-BAKES need none of that** — identical
filenames, so they replace the PNG and rebuild.

---

## Pip convention (read this before baking any of the five)

The set carries two conventions and both are correct:

- **Short domains (max ≤ 6):** pips = the domain's MAX, lit count = the
  rarity's +N, clamped at max. `i_tod_card_sprint_armor_*` (5 pips, 1/2/3 lit)
  and `i_tod_card_penetration_*` (2 pips, 1/2/2 lit — the ULTIMATE shows both
  lit and says **MAX** in the value line) are the references.
- **Long domains (max 10):** the original 54-card set uses a flat **3 pips**
  reading as "+N levels from THIS card". Ten pips would be illegible at the
  213×320 display size. `i_tod_card_damage_*` is the reference. **Keep 3 pips
  on the HEADSHOT and IMPACT ROUNDS re-bakes** — only their text changes.

---

## THE PROMPT — group 1: two NEW cards

Attach as references: `i_tod_card_sprint_armor_super.png`,
`i_tod_card_impact_rounds_ultimate.png`, `i_tod_card_recoil_regular.png`,
`i_tod_pause_r32.png`.

> You are extending an existing card set for a Call of Duty zombies map. The
> attached cards ARE the style — match them exactly: 768×1152 portrait, a dark
> navy card body with a rounded outer frame and four corner screws, an AMBER
> title plate at the top with white bold rounded caps (thick dark outline), an
> inset dark-blue "screen" panel with a faint scanline gradient holding a flat,
> bold-outlined cartoon icon with small cyan/yellow sparkle accents, a ribbon
> under the screen, a round star medal overlapping the ribbon's right end, a
> lower dark plate with a thin outline holding one or two lines of text (a bold
> coloured line over a light smaller line), and a row of pips at the bottom.
> Rarity frames: REGULAR = plain navy frame, silver ribbon "REGULAR +1", silver
> medal; SUPER = purple glow border + sparkles, purple ribbon "SUPER +2", gold
> medal; ULTIMATE = gold/orange glow border + sparkles, orange ribbon
> "ULTIMATE +3", gold medal.
>
> Produce TWO new upgrade cards, each as three separate 768×1152 PNGs (one per
> rarity), transparent outside the card, all text baked in, plus one
> pause-menu plate each. Deliver a contact sheet first so the baked text can be
> proofread, then the full-size files named exactly as listed.
>
> ### CARD 1 — GIANT SLAYER
>
> **Icon (the screen, identical on all three):** a huge armoured mechanical
> boss silhouette seen from the front, hunched and heavy, filling most of the
> screen — and a single bright bullet or spearhead striking a **cracked orange
> impact star** dead centre on its chest plate, with the crack lines spreading
> outward. The boss reads as far bigger than the thing killing it. Accent
> colour **orange `#FF8A2B`** for the impact star and the cracks, the boss body
> in cold steel blue-grey, one cyan `#33D9FF` sparkle. Flat cartoon, thick
> outlines. No text inside the screen.
>
> **FIVE pips**, lit count = the rarity's +N (1, 2, 3 of 5). Title plate on all
> three: **"GIANT SLAYER"**.
>
> | file | ribbon / frame | bold line | light line | pips |
> |---|---|---|---|---|
> | `i_tod_card_giant_slayer_regular.png` | REGULAR +1, silver, plain frame | **+3% BOSS DAMAGE** | BOSSES AND ELITES ONLY · 3% PER LEVEL | ●○○○○ |
> | `i_tod_card_giant_slayer_super.png` | SUPER +2, purple, purple glow | **+6% BOSS DAMAGE** | BOSSES AND ELITES ONLY · 3% PER LEVEL | ●●○○○ |
> | `i_tod_card_giant_slayer_ultimate.png` | ULTIMATE +3, orange, gold glow | **+9% BOSS DAMAGE** | BOSSES AND ELITES ONLY · 3% PER LEVEL | ●●●○○ |
>
> **Pause plate:** `i_tod_pause_r35.png`, 300×44 — the existing plate exactly
> (attach `i_tod_pause_r32.png`): a dark navy rounded bar with a thin outline,
> a small cyan notch at the left edge, white bold rounded caps with a dark
> outline, left-aligned after the notch, reading **"GIANT SLAYER"**.
>
> ### CARD 2 — BACK ARMOR
>
> **Icon (the screen, identical on all three):** a figure in silhouette seen
> from **BEHIND**, shoulders squared and facing away from the viewer, with a
> bold angular **armour plate glowing across its back**; two or three small
> claw or bite marks glance off the plate from behind and deflect away as short
> spark chevrons. It must read as "the hit came from behind you and the plate
> ate it" — the figure is not turning round. Accent colour **amber `#FFB300`**
> for the plate glow and the deflected sparks, one cyan `#33D9FF` sparkle. Flat
> cartoon, thick outlines. No text inside the screen.
>
> **THREE pips**, lit count = the rarity's +N (1, 2, 3 of 3 — the ULTIMATE
> fills all three). Title plate on all three: **"BACK ARMOR"**.
>
> | file | ribbon / frame | bold line | light line | pips |
> |---|---|---|---|---|
> | `i_tod_card_back_armor_regular.png` | REGULAR +1, silver, plain frame | **-10% DAMAGE TAKEN** | FROM BEHIND YOU · 10% PER LEVEL | ●○○ |
> | `i_tod_card_back_armor_super.png` | SUPER +2, purple, purple glow | **-20% DAMAGE TAKEN** | FROM BEHIND YOU · 10% PER LEVEL | ●●○ |
> | `i_tod_card_back_armor_ultimate.png` | ULTIMATE +3, orange, gold glow | **-30% DAMAGE TAKEN** | FROM BEHIND YOU · MAX | ●●● |
>
> **Pause plate:** `i_tod_pause_r36.png`, 300×44 — same construction as r35,
> reading **"BACK ARMOR"**.
>
> Keep every text string exactly as written. Everything must stay readable when
> the card is shown at 213×320.

---

## THE PROMPT — group 2: three RE-BAKES (numbers changed, art unchanged)

Attach as references the NINE existing files being replaced:
`i_tod_card_headshot_{regular,super,ultimate}.png`,
`i_tod_card_recoil_{regular,super,ultimate}.png`,
`i_tod_card_impact_rounds_{regular,super,ultimate}.png`.

> These nine cards already exist and are correct in every way EXCEPT the
> numbers baked into their lower text plate (and, for RECOIL, the pip count).
> Reproduce each card **identically** — same 768×1152 canvas, same frame, same
> title plate and title text, same screen icon, same ribbon, same medal, same
> colours, same layout — and change ONLY what the table below says. Do not
> redesign the icons. Deliver a contact sheet first for proofreading, then the
> nine full-size PNGs at their EXISTING filenames.
>
> ### HEADSHOT — value nerfed 4% → 3% per level (still 10 levels, KEEP 3 pips)
>
> | file | bold line was | bold line becomes | light line |
> |---|---|---|---|
> | `i_tod_card_headshot_regular.png` | +10% HEADSHOT DMG | **+3% HEADSHOT DMG** | 3% PER LEVEL |
> | `i_tod_card_headshot_super.png` | +20% HEADSHOT DMG | **+6% HEADSHOT DMG** | 3% PER LEVEL |
> | `i_tod_card_headshot_ultimate.png` | +30% HEADSHOT DMG | **+9% HEADSHOT DMG** | 3% PER LEVEL |
>
> (The current cards have no light line — add the small light "3% PER LEVEL"
> line under the bold one, in the style of the SPRINT ARMOR card, so the new
> smaller numbers do not read as the card's ceiling.)
>
> ### RECOIL — now TWO levels only, −8% and −16% (pips 3 → **2**)
>
> The pip row drops from three pips to **two**, following the PENETRATION card
> exactly: the ULTIMATE fills both pips and its value line says MAX.
>
> | file | bold line | light line | pips |
> |---|---|---|---|
> | `i_tod_card_recoil_regular.png` | **−8% RECOIL** | KICK REDUCED | ●○ |
> | `i_tod_card_recoil_super.png` | **−16% RECOIL** | KICK REDUCED · MAX | ●● |
> | `i_tod_card_recoil_ultimate.png` | **−16% RECOIL** | KICK REDUCED · MAX | ●● |
>
> ### IMPACT ROUNDS — now TEN levels at 3% each (KEEP 3 pips)
>
> | file | bold line was | bold line becomes | light line |
> |---|---|---|---|
> | `i_tod_card_impact_rounds_regular.png` | 10% HITS BURST | **3% HITS BURST** | 40% SPLASH · 3% PER LEVEL |
> | `i_tod_card_impact_rounds_super.png` | 20% HITS BURST | **6% HITS BURST** | 40% SPLASH · 3% PER LEVEL |
> | `i_tod_card_impact_rounds_ultimate.png` | 30% HITS BURST | **9% HITS BURST** | 40% SPLASH · 3% PER LEVEL |
>
> Keep every other pixel and every other string as it is.

---

## Proofreading checklist (before install)

- **GIANT SLAYER**: title on all three; +3 / +6 / +9% BOSS DAMAGE matching the
  rarity; light line identical on the trio; FIVE pips lit 1/2/3; plate r35.
- **BACK ARMOR**: -10 / -20 / -30% DAMAGE TAKEN; THREE pips lit 1/2/3; the
  ULTIMATE light line says MAX; plate r36.
- **HEADSHOT**: +3 / +6 / +9%, three pips, new light line present.
- **RECOIL**: −8 / −16 / −16%, **two** pips, SUPER and ULTIMATE both say MAX.
- **IMPACT ROUNDS**: 3 / 6 / 9%, three pips.
- Ribbon text REGULAR +1 / SUPER +2 / ULTIMATE +3 with the matching frame on
  every card in both groups.

## Wiring after the drop (what the session will do)

Re-bakes: replace the nine PNGs, nothing else.
New cards: `tod_ui_images.gdt` 8 `image.gdf` blocks; `.zone` 8 `image,` lines;
`tod_upgrade.lua` `CARD_SLUG[35] = "giant_slayer"`, `CARD_SLUG[36] =
"back_armor"`; `AetheriumStartMenu.lua` `PAUSE_PLATE_MAX = 36`. Then one
`-GscOnly` build.
