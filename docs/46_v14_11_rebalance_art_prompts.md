# 46 — v14.11 rebalance art: the prompts

> **STATUS: INSTALLED 2026-08-30 (files (69).zip).** All 14 files verified (sizes, text, trims vs the installed set) and wired; see CHANGELOG v14.11b. Original brief follows.
>
> ~~**STATUS: OPEN 2026-08-30.**~~ Fourteen files wanted: **8 NEW** (VITALITY and
> RECOVERY — 3 cards + 1 pause plate each) and **3 RE-BAKES + 3 optional**
> (RUN AND GUN's bottom line is now half the story). The v14.11 mechanics are
> LIVE and SHIPPED — until this art lands, VITALITY and RECOVERY render
> through the deliberate text fallback (a flat navy card with name + desc),
> which is playable but off-brand. Nothing is broken; this is polish debt.

The user's brief (2026-08-30): *"For all of these you need to think about new
prompts to create for new assets."* — from the ten-point v14.11 rebalance
(CHANGELOG v14.11).

## What needs art, and why

| domain | id | state | files | why |
|---|---|---|---|---|
| VITALITY | 38 | **NEW** | 3 cards + plate `r38` | new heavy domain, +10 max HP/Lv ×5, S tier, survives promotions |
| RECOVERY | 39 | **NEW** | 3 cards + plate `r39` | new heavy domain, regen starts 10%/Lv sooner ×3, A tier |
| RUN AND GUN | 23 | **RE-BAKE** | 3 cards | bottom line says `FREE SHOTS ON THE MOVE`; the card now ALSO pays +20/35/50% damage while moving — the line is incomplete, not false, so this is wanted-soon rather than urgent |

Verified by opening the PNGs (2026-08-30): **no other v14.11 change needs a
re-bake.** CLEAVE's line is `33% CHANCE PER LEVEL` (level-agnostic — the 6→3
cap changes nothing baked). SECOND WIND's line is `HEAL WHILE SPRINTING` (no
gun name — the MP7→MP5 move changes nothing baked). MOBILITY, DR, SPRINT
ARMOR, BACK ARMOR are all level/class-agnostic on the art. MOMENTUM and REGEN
are retired; their art stays zoned as dead weight by doctrine.

## The style contract (matches the live 768×1152 card set)

Every card in the shipped set follows this exact layout — match it:

- **768×1152 portrait**, flat cartoon "board-game card" style, thick black
  outlines, dark navy panel (`#0a1a33`-ish) with faint horizontal scanlines,
  tiny cyan/yellow pixel accents in the corners.
- **Top banner**: orange/amber rounded plate with rivets, domain name in
  chunky white outlined all-caps.
- **Middle illustration panel**: rounded dark-navy inset, one bold iconic
  cartoon illustration, cyan/teal as the dominant accent (gold/amber sparingly).
- **Rarity plate** under the illustration + **coin badge** on the panel's
  bottom-right corner + **three pips** at the bottom, and (ULTIMATE only) a
  gold outer glow around the whole card:
  - `_regular`: silver plate reading `REGULAR +1`, silver coin, 1 lit pip
  - `_super`: PURPLE-lit plate reading `SUPER +2`, gold coin, 2 lit pips (corrected 2026-08-30 against the installed PNGs — the LUI accent is blue but the BAKED set is purple)
  - `_ultimate`: gold plate reading `ULTIMATE +3`, gold coin, 3 lit pips, gold glow
- **Bottom text plate**: dark inset panel, ONE short all-caps line (two short
  centred rows are fine — SECOND WIND wraps), white with soft outline. Since
  the docs/40 subline removal there is NO small-print subline — keep it to the
  one statement. This line is IDENTICAL across the three rarities.
- Pause plates are **300×44** name-only strips: the domain name in the same
  chunky outlined type on a slim dark plate with a thin cyan frame — no
  numbers, no icon. Match `i_tod_pause_r33.png` et al.

## The prompts

Each block below is a complete, self-contained brief — paste one block per
generation, verbatim. Each tells the image model exactly what to produce,
what it is for, the exact pixel size, the exact text, and what to avoid.

### 1. VITALITY — 3 card images (NEW)

**Prompt for `i_tod_card_vitality_regular.png`:**

> You are producing a game UI asset. Create ONE image: a collectible upgrade
> card for a Call of Duty: Black Ops 3 zombies map's upgrade menu, in a flat
> cartoon "board-game card" style. Output a single PNG, portrait, exactly
> 768×1152 pixels, card artwork filling the frame edge to edge.
>
> Context: this game's upgrade menu deals players cartoon cards. Every card
> in the set shares one template, and your image must match it exactly so it
> sits beside the others without looking foreign. The template, top to
> bottom:
>
> 1. CARD BODY: rounded-corner dark navy card with a thick black outline,
>    subtle faint horizontal scanlines across the navy, and a few tiny cyan
>    and yellow pixel-square accents near the corners.
> 2. TITLE BANNER (top): a rounded orange/amber plate with small rivet dots
>    along its top edge, holding the card name in chunky white bubble
>    letters with a dark outline: the text "VITALITY" — exactly this word,
>    all caps, spelled correctly.
> 3. ILLUSTRATION PANEL (middle, the largest area): a rounded darker-navy
>    inset panel. Inside it draw THIS card's illustration: a simple cartoon
>    stick-figure survivor with thick black outlines standing square-on and
>    chest-out, a large glowing teal heart on its chest overlaid with a
>    faint hexagonal armor-plate lattice, and below the figure a chunky
>    segmented health bar with one extra bright segment visibly snapping
>    into place, plus two or three small teal "+" sparks in the air. The
>    illustration must read as "MORE maximum health" — an armored,
>    oversized heart — NOT as healing: no medical crosses, no bandages, no
>    syringes.
> 4. RARITY PLATE (under the panel): a small silver/grey banner plate with
>    the text "REGULAR +1" in the same chunky white outlined letters, and a
>    round silver coin badge with a star, overlapping the illustration
>    panel's bottom-right corner.
> 5. VALUE PLATE (bottom): a dark inset rectangle holding ONE line of
>    chunky white outlined all-caps text: "+10 MAX HEALTH PER LEVEL" —
>    exactly this text.
> 6. PIP ROW (very bottom): three small round pips; the FIRST is lit
>    white, the other two are dark.
>
> Style rules: flat colors, thick black outlines, soft simple shading only,
> teal/cyan as the dominant accent. No photorealism, no 3D render look, no
> gradients beyond gentle panel shading, no extra text anywhere beyond the
> three strings specified, no logos, no watermark, no signature.

**Then `i_tod_card_vitality_super.png`** — the same prompt with step 4 and 6
swapped to:

> 4. RARITY PLATE: a glowing BLUE banner plate with the text "SUPER +2",
>    and a round BLUE coin badge with a star.
> 6. PIP ROW: three pips, the first TWO lit blue-white, the third dark.

**Then `i_tod_card_vitality_ultimate.png`** — same again with:

> 4. RARITY PLATE: a glowing GOLD banner plate with the text
>    "ULTIMATE +3", and a round GOLD coin badge with a star.
> 6. PIP ROW: three pips, ALL THREE lit gold.
> Plus: a warm gold glow radiating from the card's outer edge onto the
> background, and a few small gold sparkle crosses around the card.

### 2. RECOVERY — 3 card images (NEW)

**Prompt for `i_tod_card_recovery_regular.png`:**

> You are producing a game UI asset. Create ONE image: a collectible upgrade
> card for a Call of Duty: Black Ops 3 zombies map's upgrade menu, in a flat
> cartoon "board-game card" style. Output a single PNG, portrait, exactly
> 768×1152 pixels, card artwork filling the frame edge to edge.
>
> Context: this card sits in a shared template set (described below) and
> its job is to sell the upgrade "your health regeneration STARTS SOONER
> after taking damage" — a time saving, not a bigger heal. Template, top to
> bottom:
>
> 1. CARD BODY: rounded-corner dark navy card, thick black outline, faint
>    horizontal scanlines, tiny cyan and yellow pixel-square accents near
>    the corners.
> 2. TITLE BANNER (top): rounded orange/amber plate with rivet dots,
>    holding chunky white outlined bubble letters: "RECOVERY" — exactly
>    this word, all caps.
> 3. ILLUSTRATION PANEL (middle, largest area): rounded darker-navy inset
>    panel. Inside it: a glowing teal EKG/heartbeat line running left to
>    right that dips low and flat, then kinks SHARPLY upward into a strong
>    rising pulse — and behind the line, a large simple cartoon stopwatch
>    whose face has one wedge glowing teal, with the watch hand jumped
>    FORWARD past that wedge, with two small motion ticks at the hand. The
>    two elements together must read "the wait before recovery got
>    shorter". No human figure, no crosses, no pills.
> 4. RARITY PLATE: a small silver/grey banner plate reading "REGULAR +1"
>    in chunky white outlined letters, and a round silver coin badge with a
>    star overlapping the panel's bottom-right corner.
> 5. VALUE PLATE (bottom): dark inset rectangle, ONE line of chunky white
>    outlined all-caps text: "REGEN STARTS SOONER" — exactly this text.
> 6. PIP ROW: three small round pips, the first lit white, two dark.
>
> Style rules: flat colors, thick black outlines, soft simple shading only,
> teal/cyan dominant. No photorealism, no 3D look, no extra text beyond the
> three strings specified, no watermark.

**SUPER and ULTIMATE variants:** identical swaps to VITALITY's (blue
"SUPER +2" / 2 pips; gold "ULTIMATE +3" / 3 pips + gold outer glow).
Files: `i_tod_card_recovery_super.png`, `i_tod_card_recovery_ultimate.png`.

### 3. RUN AND GUN — 3 card re-bakes (text change only)

Attach the current card image to the generation as the reference, one
rarity at a time (`i_tod_card_run_and_gun_regular/super/ultimate.png` from
`source_data/tod_ui_images/_images/`).

**Prompt (all three, run once per attached rarity):**

> You are editing an existing game UI asset. I have attached a cartoon
> upgrade card image, 768×1152. Reproduce this exact card — same
> illustration (the dashing submachine gun with the muzzle star and blue
> speed streaks), same title banner reading "RUN AND GUN", same rarity
> plate, same coin badge, same pips, same colors, same outlines — with ONE
> change only: the bottom dark text plate currently reads "FREE SHOTS ON
> THE MOVE"; replace that with TWO centred rows of the same chunky white
> outlined all-caps lettering: first row "FREE SHOTS + BONUS DAMAGE",
> second row "ON THE MOVE". Keep the lettering the same size as the
> original line — two full-size rows, never one shrunken row. Change
> nothing else anywhere on the card. Output a single PNG, exactly 768×1152.

(Why: in v14.11 the upgrade also grants +20/35/50% damage while moving, so
the old one-line caption is now half the story.)

### 4. The two pause plates (NEW)

**Prompt for `i_tod_pause_r38.png`:**

> You are producing a tiny game UI asset. Create ONE image: a slim
> horizontal nameplate for a pause-menu list in a Call of Duty: Black Ops 3
> zombies map. Output a single PNG, exactly 300×44 pixels. It is a dark
> navy rounded rectangle with a thin cyan frame line just inside its edge,
> containing only the word "VITALITY" centred, in chunky white bubble
> letters with a dark outline, sized to fill most of the plate's height.
> Flat cartoon style, no icon, no numbers, no other text, no watermark.

**And `i_tod_pause_r39.png`** — the same with the word "RECOVERY".


## Measured facts about the shipped card set (do not infer these)

- **TRANSPARENT background, not opaque.** Every card and both pause plates are
  RGBA with corner pixel `0,0,0,0` — machine-measured 2026-08-30 across 8 files
  (decoded row 0 / pixel 0, which is filter-invariant, so the read is exact and
  needs no full PNG decode). The rounded body and outline sit ON transparency,
  and the ULTIMATE glow feathers into it. An earlier revision of this doc said
  "opaque" — that was INFERRED from seeing a body and outline, and it was wrong;
  a peer session measured and corrected it. A prompt that says opaque returns a
  hard-edged rectangle with the glow clipped, sitting beside 127 cards that
  feather. **Measure the corner pixel. Never infer it from the art.**

- **The deal screen prints NO number on the card.** The "Lv X > Y" overlay was
  REMOVED 2026-08-20 (`tod_upgrade.lua` :723) — the baked rarity gem "+N" carries
  the gain, and `PaintCard` blanks Tag/Name/Desc whenever the card set is on.
  The file header at :343 still advertises a live "Lv X > Y" line: that comment
  is STALE, and reading it instead of the implementation is exactly how this doc
  got the claim wrong the first time.

- **Where a live number CAN appear**: the pause menu only, via
  `CoD.TodDomainDesc` -> `DETAIL[id].val(lvl)`, which prints the value at the
  level the player actually holds.

- **Consequence for level-agnostic art** (the BULLET FEED question): it is safe
  and it is the house pattern — CLEAVE, SECOND WIND and RUN AND GUN all carry no
  number — but be deliberate that the player then sees the number ONLY in the
  pause menu, never at deal time. That is the trade for never re-baking again.

## Install + wiring checklist (when the drop lands)

The march (id 37) precedent, exactly. **This half is a FULL build** — image
GDT blocks are weapon-adjacent assets and `-GscOnly` runs no gdtdb update.

1. PNGs → `source_data/tod_ui_images/_images/` (14 files, names above;
   run-and-gun overwrites in place — those 3 need NO wiring at all).
2. `source_data/tod_ui_images.gdt`: clone the `i_tod_card_march_regular`
   image.gdf block (line ~6929) for each of the 8 NEW images, changing only
   the asset name + baseImage path.
3. `zone_source/zm_tower_of_doom.zone`: after the march lines (~588-591) add
   `image,i_tod_card_vitality_regular` (…super/ultimate), the recovery three,
   `image,i_tod_pause_r38`, `image,i_tod_pause_r39`.
4. `ui/uieditor/menus/hud/tod_upgrade.lua`: in CARD_SLUG add
   `[38] = "vitality"` and `[39] = "recovery"` (the comment at DOMAIN[38]
   marks the spot). NEVER before the images are zoned — RegisterImage of a
   missing image is undefined behavior.
5. `ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua`: `PAUSE_PLATE_MAX`
   37 → 39 (the comment on that line says so).
6. FULL build (`.\tools\build_map.ps1` — GDT change), then in game: draft
   HEAVY, dev-deal until VITALITY and RECOVERY appear, check both cards, both
   pause rows, and that VITALITY's row does NOT carry the reset badge
   (TIER_SAFE[38] is already set).

## Proofread checklist (against the drop, before install)

- [ ] All cards 768×1152; plates 300×44 (march drop shipped correct sizes)
- [ ] VITALITY line reads `+10 MAX HEALTH PER LEVEL` — **the number is the
      per-level rate**, matching the GSC define (10/Lv, 5 levels, +50 at cap)
- [ ] RECOVERY line is `REGEN STARTS SOONER` (no number — the per-level 10%
      lives in the pause DETAIL row, which is already wired)
- [ ] RUN AND GUN illustration pixel-identical to the outgoing card
- [ ] Rarity plates say `REGULAR +1` / `SUPER +2` / `ULTIMATE +3` and pip
      counts match 1/2/3
- [ ] ULTIMATE cards carry the gold outer glow; REGULAR/SUPER do not
