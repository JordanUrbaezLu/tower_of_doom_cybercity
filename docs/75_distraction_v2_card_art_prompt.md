# 75 — DISTRACTION v2 card re-bake (3 images): monkey only, three pips, generic value line

<!-- art-pack
name: distraction_v2
refs:
  i_tod_card_distraction_regular.png | the CURRENT REGULAR card: keep its whole chassis, title plate and monkey; REMOVE the two green octopus creatures, change the value line, make it THREE pips. Attach to Prompt A.
  i_tod_card_distraction_super.png | the CURRENT SUPER card: the purple rarity treatment to keep. Attach to Prompt B.
  i_tod_card_distraction_ultimate.png | the CURRENT ULTIMATE card: the gold rarity treatment to keep. Attach to Prompt C.
  i_tod_card_cleave_regular.png | a max-3 card from the same deck: THREE pip sockets, first lit. This is the pip row to copy exactly. Attach to every prompt.
preview: 213x320
-->

> **STATUS: SHIPPED v16.54, 2026-09-02 19:08 — UNPLAYED.** Drop `files - 2026-09-02T190025.581.zip`; per-pixel diff vs shipped: 18.4–19.0k px, bbox x 171–598 y 591–1049 (creatures, plate, pips only); 3 fresh content-hash `.iwi`. Pack was built
> by `.\tools\make_art_pack.ps1 docs\75_distraction_v2_card_art_prompt.md` →
> `~/Downloads/tod_distraction_v2_art_pack.zip`. Install = same three filenames
> over the shipped ones (no GDT / zone / Lua wiring), FULL build, proof = fresh
> content-hash `.iwi` for all three beside an untouched control.

**Why (user, 2026-09-02):** *"change the distraction upgrade so now it only is
cymbal monkeys and also what it does is increases the max number of cymbal
monkeys you can hold. tier 1 is 1, tier 2 is 2, etc. And this goes up to 3."*
The v16.50 code does exactly that (`_tod_distraction.gsc`, domain max 2 → 3).
The shipped cards (docs/54, installed 2026-09-01) show **two Li'l Arnies** at
the monkey's feet and **TWO pips** — both now false. The card is the only place
a player reads the value at deal time, so the retune is not finished until
these are re-baked.

**What changes on the card, and why each is safe to bake:**

- **Pips 2 → 3.** Rule from the domain-retune checklist: max ≤ 6 → pips = the
  domain's max. Lit count = the rarity's +1/+2/+3.
- **Value line becomes GENERIC — no number.** User 2026-09-02: *"convert to
  generic text so this can be prevented in future where possible."* The card
  says what the upgrade DOES; the pause menu (`DETAIL[41]`, live text) says how
  much. A later change to the carry ladder then owes NO re-bake. House
  precedent: `FREE SHOTS + BONUS DAMAGE ON THE MOVE`, `DECOY PULLS THE HORDE`.
- **Illustration loses the octopuses.** Nothing in the map hands out Li'l
  Arnies any more; a creature on the card that the domain never grants is a
  lie. The monkey, the zombie silhouettes and the amber accents stay.
- **Pause plate `i_tod_pause_r41` stays** — it is name-only.

<!-- PACK:BEGIN -->
# DISTRACTION cards — re-bake (3 images)

## What this is

Three upgrade cards from a Call of Duty: Black Ops 3 zombies map, one per
rarity. They are drawn at **213 × 320 px on screen** (look at
`preview_onscreen_213x320/` — that is what the player sees). The cards already
exist and their look is right; the upgrade they describe changed, so THREE
things on them are now wrong and must change. Everything else stays.

The upgrade: it hands the player a wind-up **cymbal monkey** decoy grenade, and
each level lets them **carry one more** (1, then 2, then 3). The card's rarity
says how many levels it pays: REGULAR +1, SUPER +2, ULTIMATE +3.

**Deliver exactly THREE files, same names as the attached originals:**

| Deliver as | Rarity | Value line (exact) | Pips |
|---|---|---|---|
| `i_tod_card_distraction_regular.png` | REGULAR +1 | **CARRY MORE MONKEYS** | 3 sockets, **1 lit** |
| `i_tod_card_distraction_super.png` | SUPER +2 | **CARRY MORE MONKEYS** | 3 sockets, **2 lit** |
| `i_tod_card_distraction_ultimate.png` | ULTIMATE +3 | **CARRY MORE MONKEYS** | 3 sockets, **3 lit** |

## References (in `reference/`)

- `i_tod_card_distraction_regular.png`, `_super.png`, `_ultimate.png` — the
  CURRENT three cards. Their chassis, title plate, monkey illustration, rarity
  ribbons, medals, rails, glows and colours are all correct and must be kept.
  What is wrong on them: the two small green octopus creatures at the monkey's
  feet, the value line text (`DECOY PULLS THE HORDE`), and the pip row (two
  sockets).
- `i_tod_card_cleave_regular.png` — a card from the same deck whose upgrade has
  three levels. **Its pip row is the target**: three round sockets, evenly
  spaced, centred at the bottom of the card, first one lit white. Copy that
  row's size, spacing and position exactly.
- `preview_onscreen_213x320/` — all four at their real on-screen size.

## The three changes

1. **Remove the two green octopus creatures** at the bottom of the
   illustration panel. Fill the space with the panel's own dark navy and
   scanline texture. The monkey, its cymbals, the amber impact starburst, the
   amber sound-wave arcs, the two dark zombie-head silhouettes at the panel
   edges, the sparkle glyphs and the corner pixel squares all stay exactly as
   they are. The monkey may be scaled up slightly (up to ~10%) to own the
   panel now that it is alone, but it must not touch the panel border.
2. **Replace the value line.** Same plate, same position, same chunky all-caps
   outlined lettering, same per-rarity colour as the attached card (pale
   grey-blue on REGULAR, purple/lavender on SUPER, gold/amber on ULTIMATE).
   ONE centred line, no second line. Text, exactly, IDENTICAL on all three
   cards (only the lettering colour differs): `CARRY MORE MONKEYS`
3. **Pip row becomes THREE sockets.** Match `i_tod_card_cleave_regular.png`:
   three round sockets, evenly spaced, centred. Lit count: REGULAR 1 lit
   (white) + 2 dark; SUPER 2 lit (purple-white) + 1 dark; ULTIMATE all 3 lit
   (gold). The lit/dark colours are the ones the attached cards already use.

## Hard rules

- Canvas exactly **768 × 1152 px**, PNG, RGBA, fully transparent outside the
  card edge, identical margin to the attached files. Decode the corner pixel:
  it must be (0,0,0,0).
- **Everything not listed under "The three changes" is pixel-for-pixel the
  attached card**: the navy body, black outline, corner screws, the amber
  title plate reading `DISTRACTION` with its seven studs, the side rails, the
  rarity ribbon text (`REGULAR +1` / `SUPER +2` / `ULTIMATE +3`), the medal,
  the outer glow, the ULTIMATE's scattered gold sparkles.
- Flat colours, thick black outlines, simple soft shading — the deck's style.
  No photorealism, no 3D render look, no drop shadows on text.
- **No digits anywhere** except the `+1` / `+2` / `+3` in the rarity ribbon.
  The value line carries NO number on purpose.
- No text anywhere beyond the three strings (`DISTRACTION`, the ribbon, the
  value line). No logos, no watermark, no signature.
- The three files must stay registered with each other: same monkey position,
  same plate positions, same pip row position. Only the rarity treatment, the
  value line and the lit pips differ.

## Prompt A — `i_tod_card_distraction_regular.png`

Attach `reference/i_tod_card_distraction_regular.png` AND
`reference/i_tod_card_cleave_regular.png`.

```text
Two upgrade cards from a Black Ops 3 zombies map are attached. Edit the FIRST
one (DISTRACTION, the cymbal monkey) and deliver it at exactly 768 x 1152
pixels, PNG, RGBA, transparent outside the card, same margin as the original.
Flat cartoon style, thick black outlines, no photorealism.

Make exactly three changes and nothing else:

1. Remove the two small green octopus creatures at the monkey's feet. Fill the
   space with the panel's own dark navy and scanline texture. Keep the monkey,
   its cymbals, the amber starburst, the amber sound arcs, the two dark zombie
   head silhouettes at the panel edges, the sparkles and the tiny corner
   squares exactly as they are. You may enlarge the monkey by up to 10% so it
   owns the panel, but it must not touch the panel border.

2. Replace the text in the dark value plate near the bottom. It currently reads
   DECOY PULLS THE HORDE. It must read exactly: CARRY MORE MONKEYS
   Same chunky all-caps outlined lettering, same pale grey-blue colour, same
   size, one centred line, nothing beneath it. No digits in it.

3. The pip row at the very bottom currently has TWO round sockets. Make it
   THREE, matching the SECOND attached card (CLEAVE) exactly: three round
   sockets, evenly spaced, centred, same size and vertical position as on
   CLEAVE. The FIRST socket is lit white, the other two are dark.

Everything else — the navy card body, the black outline, the corner screws,
the amber title plate reading DISTRACTION with its seven studs, the cyan side
rails, the silver REGULAR +1 ribbon, the silver star medal — stays pixel-for-
pixel as in the original. No other text, no digits other than the +1 in the
ribbon. Deliver as i_tod_card_distraction_regular.png.
```

## Prompt B — `i_tod_card_distraction_super.png`

Attach the FINISHED regular card from Prompt A AND
`reference/i_tod_card_distraction_super.png`.

```text
Two cards are attached: the FINISHED regular DISTRACTION card (three pips, no
octopus creatures, value line CARRY MORE MONKEYS) and the OLD super card (purple
rarity treatment). Build the new SUPER card: take the finished regular card's
illustration, value plate and three-socket pip row, and apply the old super
card's rarity treatment to it — purple/violet side rails, purple panel border
and doodles, the glowing purple SUPER +2 ribbon, the gold star medal, the
soft lavender glow outside the card edge.

Then:
- the value line stays exactly CARRY MORE MONKEYS — recoloured in the old
  super card's purple/lavender lettering colour, same size and style, one
  centred line, no number added
- the pip row: THREE sockets, the first TWO lit purple-white, the third dark

Canvas exactly 768 x 1152, PNG, RGBA, transparent outside the card. The monkey,
plates and pip row must sit in exactly the same positions as on the finished
regular card. No other changes, no other text. Deliver as
i_tod_card_distraction_super.png.
```

## Prompt C — `i_tod_card_distraction_ultimate.png`

Attach the FINISHED regular card from Prompt A AND
`reference/i_tod_card_distraction_ultimate.png`.

```text
Two cards are attached: the FINISHED regular DISTRACTION card (three pips, no
octopus creatures, value line CARRY MORE MONKEYS) and the OLD ultimate card (gold
rarity treatment). Build the new ULTIMATE card: take the finished regular
card's illustration, value plate and three-socket pip row, and apply the old
ultimate card's rarity treatment to it — gold side rails, gold and red panel
border and doodles, the glowing orange-gold ULTIMATE +3 ribbon, the gold star
medal, the warm gold-and-pink glow outside the card edge with its scattered
small gold sparkle crosses and tick marks.

Then:
- the value line stays exactly CARRY MORE MONKEYS — recoloured in the old
  ultimate card's gold/amber lettering colour, same size and style, one
  centred line, no number added
- the pip row: THREE sockets, ALL THREE lit gold

Canvas exactly 768 x 1152, PNG, RGBA, transparent outside the card. The monkey,
plates and pip row must sit in exactly the same positions as on the finished
regular card. No other changes, no other text. Deliver as
i_tod_card_distraction_ultimate.png.
```

## Delivery checklist

- [ ] Three files, named exactly as the table above
- [ ] 768 × 1152, RGBA, corner pixel fully transparent — decode it, do not eyeball it
- [ ] Title reads `DISTRACTION` on all three, unchanged from the originals
- [ ] Value line reads `CARRY MORE MONKEYS` on all three — identical text,
      only the colour differs; no digits in it
- [ ] No second line under the value line
- [ ] **Exactly THREE pip sockets** on every card, lit 1 / 2 / 3 — this is the
      single most likely defect; count them
- [ ] **No octopus creatures** on any card
- [ ] Overlay the three files: the monkey, plates and pip row do not move
      between rarities
- [ ] Downscale to 213 × 320 and confirm the value line reads at a glance

## Do NOT

- Do not redraw the monkey, the title plate, the ribbons, the medal or the
  chassis — this is an edit, not a new card.
- Do not keep, shrink or recolour the octopus creatures. They are gone.
- Do not add a number (no "+1", no "3") to the value line, a level indicator,
  a subtitle or any text beyond the three strings.
- Do not deliver two pips, four pips, or pips in a different position from the
  CLEAVE reference.
- Do not hand back a different canvas size, a cropped card or an opaque
  background.
- Do not deliver one or two of the set — the three ship together or not at all.
<!-- PACK:END -->

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` — headers, md5 vs the
   repo copies, nested zips expanded. Then LOOK at all three; count the pips
   (3); confirm no octopuses; proofread CARRY MORE MONKEYS on all three; overlay the
   three against each other (monkey + plates + pips registered) and against
   the shipped files (chassis unchanged).
2. Copy over the three files in `source_data/tod_ui_images/_images/` (same
   names; no GDT / zone / Lua edits — `CARD_SLUG[41]` and the `image,` lines are
   already in place from docs/54).
3. FULL build. Proof: NEW content-hash `.iwi` for all three
   `i_tod_card_distraction_*` with fresh mtimes, beside an untouched control
   (`i_tod_pause_r41` keeps its old file).
4. Flip this STATUS to SHIPPED with the build version; CHANGELOG entry.
