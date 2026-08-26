# 26 — CLASS TIERS art: the complete prompt set (2026-08-22)

> **STATUS: INSTALLED 2026-08-22 (v9.14)** — the user's build-out drop
> `files (31).zip` (direction 4, arabic-numeral medal) carried all 39 files
> at the exact names/sizes; proofread on the contact sheets (tier names,
> footer line, rarity numbers, pips, plates, MAC-10 / ENFIELD) — clean. Wired:
> 37 `image.gdf` blocks + zone lines, `USE_TIER_CARD_ART = true`,
> `CARD_SLUG[25..31]`, `PAUSE_PLATE_MAX = 31`. Nit: the Enfield class-card
> icon reads as a generic rifle rather than an L85 bullpup — cosmetic.

Everything the tier system still needs from the image model. 39 PNGs:
**8 tier cards · 21 unique-upgrade cards (7 × 3 rarities) · 8 pause plates ·
2 class-card re-bakes.** Filenames are exact — the Lua/GDT/zone wiring keys
off them. Sizes: cards **768×1152**, plates **300×44**. Transparent outside
the card edge (the existing set is).

Install rule (docs/25 §10): a NEW filename = PNG in
`source_data/tod_ui_images/_images/` + an `image.gdf` block in
`tod_ui_images.gdt` + an `image,` zone line + `CARD_SLUG[id]` /
`USE_TIER_CARD_ART` / `PAUSE_PLATE_MAX` in the Lua; an EXISTING filename
(the two class cards) = pure PNG overwrite.

---

## PROMPT 1 — style lock + the new TIER frame (one contact sheet, 5 directions)

Attach as references: `i_tod_card_run_and_gun_regular.png`,
`i_tod_card_run_and_gun_ultimate.png`, `i_tod_card_thors_thunder_super.png`,
`i_tod_card_class_assault.png`.

> You are extending an existing card set for a Call of Duty zombies map.
> The attached four cards ARE the style — match them exactly: 768×1152
> portrait, a dark navy card body with a rounded outer frame and four corner
> screws, an AMBER title plate at the top with white bold rounded caps
> (thick dark outline), an inset dark-blue "screen" panel with a faint
> scanline gradient holding a flat, bold-outlined cartoon icon with small
> cyan/yellow sparkle accents, a ribbon under the screen, a round star medal
> overlapping the ribbon's right end, a lower dark plate with a thin outline
> holding two lines of text (a bold coloured line over a light smaller line),
> and a row of pips at the bottom. Rarity frames: REGULAR = plain navy
> frame, silver ribbon "REGULAR +1", silver medal; SUPER = purple glow
> border + sparkles, purple ribbon "SUPER +2"; ULTIMATE = gold glow border +
> sparkles, orange ribbon "ULTIMATE +3", gold medal.
>
> Design ONE new card type on a contact sheet, 5 distinct directions: the
> **CLASS TIER card** — the card a player takes to promote their class to a
> stronger weapon. It is a fourth, rarer frame: **PLATINUM / white-gold**
> (brighter and cooler than ULTIMATE's gold), with the glow tinted by the
> class colour. This sample: ASSAULT, accent amber `#FFBF40`. Construction:
> title plate text **"TIER 2"**; screen = an **AK-47** drawn in the set's
> flat cartoon style, three-quarter view, muzzle up-right, with a faint
> upward-chevron "promotion" motif behind it; ribbon in the class colour
> reading **"ASSAULT"** (like the green "CLASS" ribbon on the class card);
> medal = a roman numeral **"II"** on a platinum coin instead of the star;
> lower plate: bold amber line **"AK-47"**, light line **"NEW WEAPON · GUN
> UPGRADES RESET"**; pips: three, the first two lit. Show how the platinum
> frame reads next to the ULTIMATE gold and how the chevron motif sits in
> the screen. Everything must stay readable when the card is shown at
> 213×320.

---

## PROMPT 2 — build-out (pick direction N, then every file)

> Lock direction **N** from the contact sheet. Produce every file below as a
> separate 768×1152 PNG, transparent outside the card, all text baked in,
> the set's exact construction (navy body, corner screws, amber title plate,
> inset screen, ribbon + medal, lower two-line plate, pips). Deliver a
> contact sheet first so the baked text can be proofread, then the full-size
> files named exactly as listed.
>
> **A. TIER CARDS (8)** — platinum frame, glow tinted by the class accent,
> roman-numeral medal, class-colour ribbon, pips = tier lit of three.
> Footer light line on all eight: "NEW WEAPON · GUN UPGRADES RESET".
>
> | file | title plate | screen art | ribbon (accent) | bold line | medal / pips |
> |---|---|---|---|---|---|
> | `i_tod_card_tier_skirmisher_2.png` | TIER 2 | MP5 submachine gun | SKIRMISHER (cyan `#33D9FF`) | MP5 | II / ●●○ |
> | `i_tod_card_tier_skirmisher_3.png` | TIER 3 | MP7, compact, translucent 40-round mag | SKIRMISHER (cyan) | MP7 | III / ●●● |
> | `i_tod_card_tier_assault_2.png` | TIER 2 | Krig 6 rifle | ASSAULT (amber `#FFBF40`) | KRIG 6 | II / ●●○ |
> | `i_tod_card_tier_assault_3.png` | TIER 3 | AK-47 | ASSAULT (amber) | AK-47 | III / ●●● |
> | `i_tod_card_tier_heavy_2.png` | TIER 2 | HK21 machine gun with its box belt | HEAVY (red `#FF594D`) | HK21 | II / ●●○ |
> | `i_tod_card_tier_heavy_3.png` | TIER 3 | Death Machine minigun, barrels blurred with spin | HEAVY (red) | DEATH MACHINE | III / ●●● |
> | `i_tod_card_tier_slasher_2.png` | TIER 2 | a katana, blade up, small motion arc | SLASHER (violet `#BF73FF`) | KATANA | II / ●●○ |
> | `i_tod_card_tier_slasher_3.png` | TIER 3 | STORMBREAKER: a Norse two-bladed great-axe wreathed in white-blue lightning, small purple storm cloud behind | SLASHER (violet) | STORMBREAKER | III / ●●● |
>
> **B. UNIQUE-UPGRADE CARDS (7 × 3 = 21)** — exactly the existing domain-card
> construction, one file per rarity: `_regular` (silver ribbon "REGULAR +1",
> plain frame), `_super` (purple ribbon "SUPER +2", purple glow), `_ultimate`
> (orange ribbon "ULTIMATE +3", gold glow). Every one of these domains has
> THREE levels, so the pips are three and the lit count = the rarity's +N.
> The lower plate's bold line carries the number for that rarity (the value
> reached with +1 / +2 / +3 levels), the light line is the same on all
> three. Icon accent colour = the class colour.
>
> | slug (`i_tod_card_<slug>_<rarity>.png`) | title plate | icon (screen) | accent | bold line regular / super / ultimate | light line |
> |---|---|---|---|---|---|
> | `adrenaline` | ADRENALINE | a syringe-shaped speed chevron over a running silhouette, motion lines | cyan | +4% SPEED PER KILL / +6% SPEED PER KILL / +8% SPEED PER KILL | STACKS ×3 · 4S BURST |
> | `overdrive` | OVERDRIVE | an SMG magazine glowing hot with rising heat lines and a red-lining gauge | cyan | +5% PER 10 ROUNDS / +8% PER 10 ROUNDS / +12% PER 10 ROUNDS | SUSTAINED FIRE, 5 STACKS |
> | `kill_reload` | KILL RELOAD | a rifle magazine with a returning arrow and a small skull | amber | +25% MAG BACK / +50% MAG BACK / +75% MAG BACK | ON EVERY KILL |
> | `impact_rounds` | IMPACT ROUNDS | a bullet with a small shock ring and three flying shards | amber | 10% HITS BURST / 20% HITS BURST / 30% HITS BURST | 40% SPLASH NEARBY |
> | `suppressing_fire` | SUPPRESSING FIRE | an ammo belt over a stumbling zombie silhouette, slow-motion trails | red | HITS SLOW 25% / HITS SLOW 40% / HITS SLOW 55% | FOR 1.5 SECONDS |
> | `meat_grinder` | MEAT GRINDER | spinning minigun barrels with a rising heat gauge | red | +2% PER 5 ROUNDS / +3% PER 5 ROUNDS / +4% PER 5 ROUNDS | UP TO +50% · +75% · +100% (use the matching one per rarity: UP TO +50% / UP TO +75% / UP TO +100%) |
> | `draw_cut` | DRAW CUT | a katana mid-draw with a crescent slash arc and speed lines | violet | +50% DAMAGE / +100% DAMAGE / +150% DAMAGE | SWING OUT OF A SPRINT |
>
> **C. PAUSE-MENU PLATES (8)** — `i_tod_pause_rNN.png`, 300×44, the
> existing plate: a dark navy rounded bar with a thin outline, a small cyan
> notch at the left edge, white bold rounded caps with a dark outline,
> left-aligned after the notch (attach `i_tod_pause_r23.png` as the
> reference).
>
> r24 "CLASS TIER" · r25 "ADRENALINE" · r26 "OVERDRIVE" · r27 "KILL RELOAD"
> · r28 "IMPACT ROUNDS" · r29 "SUPPRESSING FIRE" · r30 "MEAT GRINDER" ·
> r31 "DRAW CUT"
>
> **D. CLASS-CARD RE-BAKES (2, same filenames = overwrite)** — the starting
> guns changed. Exactly the attached `i_tod_card_class_assault.png`
> construction (green "CLASS" ribbon, silver star medal, amber gun name, light
> role line, three dash pips):
>
> - `i_tod_card_class_skirmisher.png` — title "SKIRMISHER", screen: a
>   **MAC-10** (boxy machine pistol, wire stock) in the set's style with cyan
>   motion lines, bold line **"MAC-10"**, light line **"RUN AND GUN"**.
> - `i_tod_card_class_assault.png` — title "ASSAULT", screen: an **ENFIELD**
>   (L85-style bullpup rifle, carry-handle sight), bold line **"ENFIELD"**,
>   light line **"BALANCED RIFLEMAN"**.
>
> Keep every text string exactly as written (the game reads nothing from the
> art — but players do). Readable at 213×320.

---

## Proofreading checklist (before install)

- Tier cards: title TIER 2/3, ribbon = class name, bold = gun name, footer
  "NEW WEAPON · GUN UPGRADES RESET", numeral medal, pips 2-of-3 / 3-of-3.
- Unique cards: bold-line numbers per rarity match the table; light line
  identical across the trio; three pips with +N lit.
- Plates: all caps, names exactly as the table (r24–r31).
- Class cards: MAC-10 / ENFIELD spelled as shown.

## Wiring after the drop (what the session will do)

`tod_ui_images.gdt` blocks + zone `image,` lines for the 37 NEW files;
`tod_upgrade.lua`: `USE_TIER_CARD_ART = true`, `CARD_SLUG[25..31] =
adrenaline / overdrive / kill_reload / impact_rounds / suppressing_fire /
meat_grinder / draw_cut`; `AetheriumStartMenu.lua`: `PAUSE_PLATE_MAX = 31`.
The two class cards are overwrites only.
