# 135 — THE PROMPT CARDS: reskin every interactive prompt into our theme (11 images)

<!-- art-pack
name: prompt_card_reskin
refs:
  i_tod_hold_plate.png | OUR house plate, and the closest existing thing to what is being made: navy pill, steel bevel, chunky white outlined caps. THE CHASSIS SHOULD LOOK LIKE THIS FAMILY.
  i_tod_hint_frame.png | the same plate EMPTY, so the chassis treatment is visible without lettering over it
  i_tod_card_headshot_regular.png | an upgrade card: the fullest statement of our look — navy panels, steel bevel, rivet corners, gold title band, inset description panel. Borrow the language, not the layout.
  i_tod_hud_points_icon.png | the PRICE icon that ALREADY draws on the prompt card and is not changing. The new chassis must sit behind this without clashing.
  i_tod_banner_panzer.png | our banner treatment: how a wide plate carries a title in this map
  i_tod_hud_player_plate.png | our HUD plate: the quieter, in-play end of the same family
preview: 346x114 66x66
-->

> **STATUS: SHIPPED v19.1/v19.2 (2026-09-14).** The chassis and all six icons are
> installed, zoned (zm_tower_of_doom.zone:554-560) and in the build. The four
> "spacer" deliverables were NOT outstanding — they were superseded: the kit's
> five chassis rects are nested and the outer one contains the other four, so the
> inner ones point at stock `blacktransparent` rather than shipping empty PNGs.
> Round 2 (rampage / crown / PaP / perk) is docs/136 and is still undelivered.
> `.\tools\make_art_pack.ps1 docs\135_prompt_card_reskin_art_prompt.md`.
> User: *"we have this UI for ammo crates, for buying doors, for using the heavenly
> altar, for starting the extraction … we need to come up with a better design using
> our typography … rather than how currently it's the Aetherium hub theme … currently
> that's, like, our biggest issue on that inconsistency."*
>
> **WHY THIS IS ART AND NOT A LUA REWRITE.** Every one of the nine
> `ui/uieditor/widgets/HUD/ZM_CursorHint/Prompts/*.lua` cards is composed purely of
> `LUI.UIImage` + `RegisterImage()`. There is not one drawn rectangle or nine-slice in
> any of them. Five shared chassis images are used at identical rects by all SIX live
> cards (Default, Doors, Perks, PAP, PowerSwitch, PowerRequired), so replacing those
> five re-skins every prompt in the map at once.
>
> **THE ONE-CANVAS TRICK THIS BRIEF RELIES ON.** The five chassis rects are nested:
> `bgBorder` (544..775 × 444..520) CONTAINS `bgIcon`, `bgHeader`, `bgFrame` and
> `bgMain`, and it is drawn LAST of the background layers. So the whole card can be
> drawn on the border layer alone and the other four shipped as fully transparent
> spacers — one design surface for the artist, and zero Lua layout edits for us.
> The per-object icon still draws ON TOP of it, and so does all the text.
>
> **INSTALL (after the drop):** `-Inspect` the zip, look at every image, then copy into
> `source_data/tod_ui_images/_images/`. All eleven are NEW names → each needs a GDT
> block, a zone `image,` line, and the Lua slug repointed in the six live cards.
> ⚠️ **NEVER overwrite the kit's `i_mtl_image_*` slugs in place**: `i_mtl_image_7d9423641070f37e`
> is also used by the scoreboard (`AetheriumQuestsCustom.lua`), and those names are zoned
> through `aetherium_hud.zpkg`, which the asset lint cannot see — a typo there is a white
> square with no build-time warning. New names, repointed Lua, always.
> ⚠️ Do not decorate the strip at y 488..502: `TodTeleportFeedback` injects the teleporter
> countdown bar there.

<!-- PACK:BEGIN -->

# PROMPT CARD RESKIN — 11 images

This is the small card that appears in the middle-right of the screen whenever the
player looks at something they can interact with: a door they can buy, an ammo crate,
an upgrade altar, a teleporter, the power switch, the extraction beacon. It currently
wears a different game's UI theme and clashes with everything else on screen. You are
replacing it with one that belongs to this map.

**The map's look, in one line:** dark navy panels with polished steel bevels and rivet
corners, cyan and gold accents, and heavy all-caps display lettering with a dark
outline and a soft drop shadow. Attach every file in `reference/` — those are the real
shipped assets this has to sit beside.

## Deliverables

### A. The card chassis — 5 files

| Filename | Size | What it is |
|---|---|---|
| `i_tod_prompt_chassis.png` | **924 x 304** | **THE WHOLE CARD.** Draw the complete design here. |
| `i_tod_prompt_spacer_main.png` | **624 x 232** | fully transparent |
| `i_tod_prompt_spacer_header.png` | **632 x 60** | fully transparent |
| `i_tod_prompt_spacer_frame.png` | **628 x 272** | fully transparent |
| `i_tod_prompt_spacer_icon.png` | **276 x 292** | fully transparent |

The four spacers exist because the game still draws those layers; they must be present
and completely empty (alpha 0 everywhere) so only your chassis shows. Ship them as
real PNGs at exactly those sizes.

**The chassis is `924 x 304` and displays at `346 x 114`.** Judge it at that size —
it is a small card and detail below about 3 px will disappear. The preview folder
renders it for you.

### The chassis layout — where the game puts things ON TOP of your art

Coordinates below are in your 924 x 304 canvas. **These regions are fixed by the game.
Your art must leave them readable; do not put busy detail or bright colour under them.**

| Region | x | y | What lands there |
|---|---|---|---|
| **Icon well** | 8 → 284 | 4 → 296 | a 176 x 176 object icon (see part B), centred at about (180, 150) |
| **Title band** | 284 → 916 | 8 → 68 | the object name in caps, e.g. `AMMO CRATE`, `HEAVENLY GIFT ALTAR` |
| **Detail line 1** | 304 → 892 | 92 → 120 | e.g. `Regular $2500` |
| **Detail line 2** | 304 → 892 | 136 → 164 | e.g. `Pack a Punch $5000` |
| **Footer** | 304 → 720 | 252 → 284 | `Hold [button] To Buy` |
| **Price** | 732 → 916 | 236 → 288 | a coin icon then a number, right-aligned |

So: a tall icon well on the left, a title bar across the top of the remaining width,
two lines of detail under it, and a footer row with a price at the right end.

### What the chassis should be

- A **navy plate with a polished steel bevel**, in the family of `i_tod_hold_plate.png`
  and the upgrade card in `reference/`. Rivets or corner hardware are welcome if they
  stay out of the text regions.
- **The icon well should read as a recessed slot** — a darker inset panel with its own
  bevel, clearly a place where an object portrait sits.
- **The title band should be a distinct band**, the way the upgrade card's gold name
  plate is distinct from its body. Cyan or steel is right for the default; do not use
  gold, which this map reserves for the crown and for rarity.
- Keep the interior **dark and low-contrast** so white and cyan text sits cleanly on it.
- A subtle outer glow or rim light is in keeping; a heavy one is not. This element is
  on screen constantly during play and must not compete with the crosshair.
- **Transparent outside the plate.** No opaque background square.

### B. The object icons — 6 files, `256 x 256` each

One per kind of thing the player interacts with. These drop into the icon well, so
they read at about **66 x 66 on screen** — draw bold, simple silhouettes, not scenes.

| Filename | The object |
|---|---|
| `i_tod_prompt_icon_door.png` | a buyable door — a heavy sealed bulkhead or shutter |
| `i_tod_prompt_icon_crate.png` | an ammo crate — a military supply box, lid ajar, rounds visible |
| `i_tod_prompt_icon_altar.png` | an upgrade altar — a pedestal or shrine offering a glowing card |
| `i_tod_prompt_icon_teleporter.png` | a teleporter pad — a ring pad with a beam rising from it |
| `i_tod_prompt_icon_power.png` | a power switch — a big industrial breaker lever |
| `i_tod_prompt_icon_extract.png` | extraction — a beacon or uplink dish firing a signal upward |

**Icon rules**
- One object, centred, filling most of the square with a little margin.
- **Flat, bold shapes with a dark outline** — the same construction as the skull on the
  upgrade card in `reference/`. Not photographic, not painted.
- Cyan as the accent for most; the extraction beacon may use gold; the power switch may
  use a warm amber for its lever.
- **Transparent background.** The icon well behind them is part of the chassis.
- They must read as a set: same outline weight, same light direction, same palette.

## Hard rules

1. **Exact pixel sizes.** Every file at the size in the table, no other.
2. **PNG, RGBA, transparent where specified.**
3. **No text baked into any image.** All wording is drawn by the game at runtime, in
   many languages. A baked word is a bug.
4. **No numbers baked in** — prices change.
5. **Leave the text regions clean.** Anything busy under the title or detail rows makes
   the prompt unreadable, which is the whole problem being fixed.
6. **Do not draw a button glyph or a key name anywhere.** The game inserts the player's
   own live binding, which differs per device and per player.

## Prompts you can paste

**The chassis** — attach `reference/i_tod_hold_plate.png`, `reference/i_tod_hint_frame.png`,
`reference/i_tod_card_headshot_regular.png`, `reference/i_tod_hud_points_icon.png`,
`reference/i_tod_banner_panzer.png` (how a WIDE plate in this map carries a title band —
the closest thing to the title bar you are drawing) and
`reference/i_tod_hud_player_plate.png` (the quieter in-play end of the family: this card
sits on screen during combat, so it should be closer to this than to the loud banner):

> A game UI interaction prompt plate, 924 x 304 pixels, PNG with transparency.
> Dark navy blue panel with a polished steel bevelled border and small rivets at the
> corners, matching the attached reference plates. On the left, a recessed square slot
> about 276 x 292 with its own inner bevel, clearly a holder for an object icon. Across
> the top of the remaining width, a distinct horizontal band in steel and cyan for a
> title. Below it the panel interior is dark, flat and uncluttered, with room for two
> lines of text and a footer row. Subtle cyan rim light around the outer edge. No text,
> no numbers, no letters anywhere. Transparent outside the plate. Clean vector-style
> game UI art, crisp edges, readable when scaled down to 346 pixels wide.

**The icons** — attach `reference/i_tod_card_headshot_regular.png` for construction, and
the chassis you just made so the palette matches:

> A set of six game UI object icons, each 256 x 256 pixels, PNG with transparent
> background, drawn as one consistent family. Flat bold vector shapes with a dark
> outline and a soft inner shadow, cyan accent lighting, dark navy shading, matching
> the attached reference art's construction. The six objects: (1) a heavy sealed
> bulkhead door, (2) a military ammunition crate with the lid ajar and rounds visible,
> (3) a stone pedestal shrine offering a single glowing card, (4) a circular teleporter
> pad with a beam of light rising from it, (5) a large industrial electrical breaker
> lever, (6) a signal beacon dish emitting a beam upward. Each centred, filling most of
> the square with a small margin, bold enough to read at 66 pixels. No text, no numbers.

## Delivery checklist

- [ ] 11 PNGs, exact filenames, exact sizes
- [ ] the 4 spacers are completely transparent
- [ ] no text, no numbers, no button glyphs in any image
- [ ] the chassis leaves the title / detail / footer / price regions clean
- [ ] the 6 icons read as one set and are legible at 66 px
- [ ] transparent backgrounds throughout
- [ ] a flattened preview of the chassis with an icon in the well, so the composition
      can be judged as one picture

## Do NOT

- Do not bake any word, letter, number or key name into any image.
- Do not deliver a different size "because it looked better" — the sizes are fixed by
  the game's layout.
- Do not draw the icons in a different style from each other.
- Do not use gold as the chassis accent; it is reserved elsewhere in this map.
- Do not add a drop shadow outside the plate that assumes a light background.

<!-- PACK:END -->
