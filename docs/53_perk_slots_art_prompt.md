# 53 — PERK SLOTS card art: the prompts (v14.56)

> **STATUS: RETIRED 2026-09-03 (v16.80)** — the PERK SLOTS domain and the perk cap were removed on the Workshop thread's verdict; the three cards are unzoned, the r40 pause plate stays zoned, the PNGs and GDT entries remain on disk. Previous: **STATUS: INSTALLED 2026-08-31** (user drop `files (77).zip`, FULL build 19:58:09,
> `.ff` 120,602,368 bytes). All four files verified before install — 768x1152 /
> 300x44, RGBA with corner alpha 0 against an installed control, five pips lit
> 1/2/3, identical `+1 PERK SLOT PER LEVEL` line on all three rarities. Wired:
> GDT blocks, zone lines, `CARD_SLUG[40]`, `PAUSE_PLATE_MAX` 39 -> 40.
> Conversion proven by content-hash `.iwi` (glob `<name>_*`) stamped by this
> build, with a positive and a negative control. Original brief follows.
>
> ~~**STATUS: OPEN 2026-08-31.**~~ Four files wanted: **3 cards + 1 pause plate**
> for the new PERK SLOTS domain (id 40). The mechanic ships in the same pass;
> until this art lands the domain renders through the deliberate **text
> fallback** (a flat navy card with name + desc), which is playable but
> off-brand — the same state VITALITY and RECOVERY sat in between v14.11 and
> v14.11b.

The user's brief (2026-08-31): *"you need to implement a perk max at 4 and you
can get more through the altar. 1 extra slot on basic, 2 on super, 3 on
ultimate and they persist through dying and class tier upgrades. We would need
to new assets for these so you would need to get me a prompt so my LLM asset
generator can create them."*

## What the domain is

| | |
|---|---|
| key / display | `perkslots` / **PERK SLOTS** |
| domain id | **40** (next free — 39 was RECOVERY) |
| max level | **5** |
| classes | **all four** (`class_keys` undefined) |
| rarity tier | `TOD_TIER_A` (was `TOD_TIER_S`; f8 moved it S->A on a user directive, v14.59 2026-08-31 — draw weight 20 -> 50, so it is offered ~2.5x as often and its SUPER/ULTIMATE slice factor goes 0.50 -> 0.75. **No art impact**: the band changes nothing on the card, which carries only the name, the per-level line and the pip row.) |
| effect | **+1 perk slot per level**, on top of a base cap of **4** |
| persistence | survives **death** (levels live on the player) and **class-tier promotions** (`set_scope("perkslots","class")`) |

**Why max 5, and why it is the number baked into the pip row:** this map sells
exactly **NINE** perks — measured, not recalled: nine `zm_perk_machine` parking
entities in `map_source/zm/zm_tower_of_doom.map`, one per specialty —
`armorvest` (Juggernog), `fastreload` (Speed Cola), `quickrevive`,
`staminup`, `widowswine`, `doubletap2`, `electriccherry` (**presented as PhD
Flopper**), `combat_efficiency` (**presented as Death Perception**),
`nomotionsensor` (**Wisp Tea**). Mule Kick is retired and machineless, so it is
not a tenth. **4 base + 5 levels = 9 = the whole roster**, which also means the
Endless Spire's "max every domain, then grant every perk" ascension works out
by construction instead of needing an exemption.

⚠️ Two numbers are baked into this art: the **5 pips** (= the domain max) and
the **four filled sockets** in the illustration (= the base cap). If either the
base cap or the max level ever moves, these three cards need a re-bake. That is
the standing failure mode this docs series has recorded four times — it is
written down here on purpose.

## The style contract — MEASURED off the installed set, not recalled

Opened and read 2026-08-31: `i_tod_card_sprint_armor_super.png`,
`i_tod_card_sprint_armor_ultimate.png`, `i_tod_card_vitality_regular.png`,
`i_tod_card_vitality_super.png`.

- **768×1152 portrait**, RGBA with a **TRANSPARENT background** (corner pixel
  `0,0,0,0`) — the rounded body sits on transparency and the rarity glow
  feathers into it. A prompt that says "opaque" returns a hard-edged rectangle
  with the glow clipped, beside 130 cards that feather.
- **CARD BODY**: rounded dark-navy panel, very thick black outline, four small
  screw-bolt heads in the corners, a faint scanline texture.
- **TITLE BANNER** (top): rounded orange/amber plate with a row of rivet dots
  along its top edge; the domain name in chunky white bubble letters with a
  heavy dark outline.
- **ILLUSTRATION PANEL** (middle, largest): rounded darker-navy inset with a
  soft radial highlight top-centre, scanlines, and a few tiny cyan/yellow
  pixel-square accents in its corners. One bold flat-cartoon illustration,
  thick black outlines, **teal/cyan dominant**.
- **RARITY PLATE** (under the panel, with small dark arrow notches either
  side) + **coin badge** with a star overlapping the panel's bottom-right
  corner + **vertical accent rails** down the card's left and right inner
  edges + **the bottom line's text colour** — all four are tinted by rarity:

  | | plate | coin | rails | bottom text | outer glow | panel doodles |
  |---|---|---|---|---|---|---|
  | `_regular` | **silver/grey** `REGULAR +1` | **silver** | cyan | pale cyan-white | **none** | teal |
  | `_super` | **PURPLE** `SUPER +2` | **gold** | purple | **purple** | **lavender/purple** | purple + teal |
  | `_ultimate` | **orange-gold** `ULTIMATE +3` | **gold** | gold | **gold/amber** | **warm gold-pink**, plus gold sparkle crosses scattered around the card | gold, red, teal |

  (Earlier docs in this series said SUPER was *blue*. The **installed set is
  purple**, and SUPER carries an outer glow too — not ULTIMATE only.)
- **BOTTOM TEXT PLATE**: dark inset rectangle with a thin frame line and four
  rivets, holding **ONE** short all-caps line in chunky outlined lettering. No
  small-print subline (removed in docs/40). **This line is identical across the
  three rarities** — only its colour changes.
- **PIP ROW** (very bottom): **pips = the domain's MAX level**, lit count = the
  rarity's `+N`. SPRINT ARMOR (max 5) ships **5 pips**; so does this one.
  ⚠️ `i_tod_card_vitality_*` ships **3** pips for a max-5 domain — that card is
  the odd one out in the set and should not be used as the reference.
- **PAUSE PLATE**: `300×44`, name-only, dark navy rounded rectangle, thin cyan
  frame, the domain name centred in the same chunky outlined type. No icon, no
  numbers.

## The prompts

Paste one block per generation, verbatim.

### 1. `i_tod_card_perkslots_regular.png`

> You are producing a game UI asset. Create ONE image: a collectible upgrade
> card for a Call of Duty: Black Ops 3 zombies map's upgrade menu, in a flat
> cartoon "board-game card" style. Output a single PNG, portrait, exactly
> 768×1152 pixels, with a FULLY TRANSPARENT background — the rounded card body
> sits on transparency, it is not a rectangle filling the frame.
>
> Context: this game's upgrade menu deals players cartoon cards. Every card in
> the set shares one template and your image must match it exactly so it sits
> beside the others without looking foreign. The template, top to bottom:
>
> 1. CARD BODY: a rounded-corner dark navy card with a very thick black
>    outline, a faint horizontal scanline texture across the navy, a small
>    screw-bolt head in each of the four corners, and a slim vertical CYAN
>    accent rail running down the inside of the left and right edges.
> 2. TITLE BANNER (top): a rounded orange/amber plate with a row of small
>    rivet dots along its top edge, holding the card name in chunky white
>    bubble letters with a heavy dark outline: the text "PERK SLOTS" —
>    exactly this, all caps, spelled correctly, on ONE line.
> 3. ILLUSTRATION PANEL (middle, the largest area): a rounded darker-navy
>    inset panel with a soft radial highlight at the top, faint scanlines,
>    and a few tiny cyan and yellow pixel-square accents near its corners.
>    Inside it draw THIS card's illustration: a horizontal RACK of FIVE
>    bottle-shaped sockets, drawn as chunky rounded slots with thick black
>    outlines, seen straight on. The LEFT FOUR sockets are each filled with a
>    glowing teal cartoon perk-soda bottle (simple bottle silhouette, a cap, a
>    highlight streak). The FIFTH socket on the right is EMPTY and rimmed with
>    a bright glowing outline, and a fifth teal bottle is dropping DOWN into
>    it from above, with two or three small motion ticks above the bottle and
>    a couple of small teal sparkle crosses in the air. Above the rack, a
>    simple cartoon stick-figure survivor with thick black outlines stands
>    with one arm raised holding a bottle. The picture must read as "you have
>    room to carry ONE MORE PERK" — it is about CAPACITY, not about what a
>    perk does: no shields, no hearts, no health bars, no guns, no
>    medical crosses.
> 4. RARITY PLATE (directly under the illustration panel, with a small dark
>    arrow notch on each side): a SILVER/GREY banner plate with the text
>    "REGULAR +1" in the same chunky white outlined letters, and a round
>    SILVER coin badge with a star on it, overlapping the illustration
>    panel's bottom-right corner.
> 5. VALUE PLATE (bottom): a dark inset rectangle with a thin frame line and
>    a rivet in each corner, holding ONE line of chunky outlined all-caps
>    text in pale cyan-white: "+1 PERK SLOT PER LEVEL" — exactly this text,
>    on one line.
> 6. PIP ROW (very bottom): FIVE small round pips in a row; the FIRST is lit
>    white, the other FOUR are dark and empty.
>
> Style rules: flat colours, thick black outlines, soft simple shading only,
> teal/cyan as the dominant accent with the orange title banner as the only
> warm note. No photorealism, no 3D render look, no gradients beyond gentle
> panel shading, no outer glow on this rarity, no extra text anywhere beyond
> the three strings specified, no logos, no watermark, no signature.

### 2. `i_tod_card_perkslots_super.png`

Same prompt as above, with these substitutions:

> 1. CARD BODY: …the vertical accent rails down the left and right inner
>    edges are PURPLE instead of cyan.
> 3. …and a few of the small sparkle/doodle accents in the panel are PURPLE
>    alongside the teal ones.
> 4. RARITY PLATE: a glowing PURPLE banner plate with the text "SUPER +2" in
>    chunky white outlined letters, and a round GOLD coin badge with a star.
> 5. VALUE PLATE: the same line "+1 PERK SLOT PER LEVEL", lettered in
>    PURPLE instead of pale cyan-white.
> 6. PIP ROW: FIVE pips, the first TWO lit purple-white, the other three dark.
> PLUS: a soft lavender/purple glow radiating from the card's outer edge onto
> the transparent background.

### 3. `i_tod_card_perkslots_ultimate.png`

Same prompt again, with these substitutions:

> 1. CARD BODY: …the vertical accent rails down the left and right inner
>    edges are GOLD instead of cyan.
> 3. …and a few of the small sparkle/doodle accents in the panel are GOLD and
>    RED alongside the teal ones.
> 4. RARITY PLATE: a glowing ORANGE-GOLD banner plate with the text
>    "ULTIMATE +3" in chunky white outlined letters, and a round GOLD coin
>    badge with a star.
> 5. VALUE PLATE: the same line "+1 PERK SLOT PER LEVEL", lettered in
>    GOLD/AMBER instead of pale cyan-white.
> 6. PIP ROW: FIVE pips, the first THREE lit gold, the other two dark.
> PLUS: a warm gold-and-pink glow radiating from the card's outer edge onto
> the transparent background, and a scattering of small gold four-point
> sparkle crosses around the card's border.

### 4. `i_tod_pause_r40.png`

> You are producing a tiny game UI asset. Create ONE image: a slim horizontal
> nameplate for a pause-menu list in a Call of Duty: Black Ops 3 zombies map.
> Output a single PNG, exactly 300×44 pixels, with a transparent background
> outside the plate. The plate is a dark navy rounded rectangle with a thin
> cyan frame line just inside its edge, containing only the words "PERK SLOTS"
> centred, in chunky white bubble letters with a dark outline, sized to fill
> most of the plate's height. Flat cartoon style, no icon, no numbers, no
> other text, no watermark.

## Proofread checklist (against the drop, before install)

- [ ] All three cards exactly **768×1152**; plate exactly **300×44**
- [ ] Backgrounds **transparent** (check the corner pixel, do not eyeball it)
- [ ] Title reads `PERK SLOTS` on all three, one line, spelled correctly
- [ ] Bottom line reads `+1 PERK SLOT PER LEVEL` on all three — **identical
      wording**, only the colour differs
- [ ] **FIVE pips** on every card; lit 1 / 2 / 3 for regular / super / ultimate
- [ ] Rarity plates read `REGULAR +1` / `SUPER +2` / `ULTIMATE +3`
- [ ] Coins: silver / gold / gold. Rails: cyan / purple / gold
- [ ] Outer glow: none / lavender / gold — regular must have NO glow
- [ ] The illustration shows **four filled sockets + one filling**, and does
      not read as health, armour or ammo

## Install + wiring checklist (when the drop lands)

The VITALITY/RECOVERY (ids 38/39) precedent, exactly. **This half is a FULL
build** — a `.gdt` edit always is.

1. PNGs → `source_data/tod_ui_images/_images/` (4 files, names above).
2. `source_data/tod_ui_images.gdt`: clone the `i_tod_card_vitality_regular`
   image.gdf block for each of the 4 new images, changing only the asset name
   and the `baseImage` path.
3. `zone_source/zm_tower_of_doom.zone`: add `image,i_tod_card_perkslots_regular`
   (…`_super`, `_ultimate`) and `image,i_tod_pause_r40`.
4. `ui/uieditor/menus/hud/tod_upgrade.lua`: in `CARD_SLUG` add
   `[40] = "perkslots"`. **NEVER before the images are zoned** — `RegisterImage`
   of a missing image is undefined behaviour.
5. `ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua`: `PAUSE_PLATE_MAX`
   39 → 40.
6. `node tools/lint_tod_lua.js`, then a FULL `.\tools\build_map.ps1`.
7. In game: dev-deal until PERK SLOTS appears; check all three rarities, the
   pause row, and that the row does **not** carry the reset badge
   (`set_scope("perkslots","class")` makes it promotion-safe).
