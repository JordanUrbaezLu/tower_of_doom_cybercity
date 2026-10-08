# 54 — DISTRACTION card art prompt (domain 41: Cymbal Monkey → Li'l Arnies)

> **SUPERSEDED 2026-09-02 (v16.50).** The domain was reshaped: Cymbal Monkey
> ONLY, max **3**, the level is the carry cap (1/2/3), Max Ammo +1 at every
> level. The cards this doc produced (installed 2026-09-01, files (78).zip)
> show two Li'l Arnies and TWO pips, both now wrong. The replacement brief is
> `docs/75_distraction_v2_card_art_prompt.md` (same filenames, 3 pips, monkey
> only). Everything below is the historical record of the v14.59 form.

**Status (historical):** art prompt only. The domain ships on the LUI **text fallback** first
(VITALITY / RECOVERY / PERK SLOTS precedent); `CARD_SLUG[41]` and
`PAUSE_PLATE_MAX` stay untouched until these PNGs are installed **and** zoned.
`PAUSE_PLATE_MAX` is 40 as of v14.56 (2026-08-31), so 41 is the only step left
and it depends on nothing but this drop — see the install order at the end.

- **Domain:** `distraction`, id **41**, ASSAULT only, band **S**, **max 2**,
  survives tier promotions.
- **Lv1** = Cymbal Monkey. **Lv2** = Li'l Arnies. Carry 1; every MAX AMMO grants
  **+1**; hard cap **3**.
- **Class accent colour is AMBER** — this is an assault domain. Match KILL
  RELOAD / IMPACT ROUNDS / FORCED MARCH, *not* the cyan the skirmisher cards use.
  (Rarity colour is a separate axis and drives the rails, ribbon, medal, value
  line and outer glow.)

---

## Why the illustration must show BOTH toys

Rarity pays **levels**, not power. A REGULAR card is `+1` and a SUPER is `+2`,
and there is exactly one piece of art per rarity — so:

| dealt at | REGULAR +1 lands you on | SUPER +2 lands you on |
|---|---|---|
| Lv 0 | **Monkey** | **Arnies** (the monkey is skipped) |
| Lv 1 | **Arnies** | Arnies (clamped, relabels to REGULAR) |

A REGULAR card can pay either toy depending on where the player already is, so
**neither card may show only one of them**. Both illustrations are identical and
show the monkey as the subject with the Arnies present but subordinate.

**ULTIMATE can never be dealt** on a max-2 domain (the band-honesty clamp in
`make_option` relabels any `+3` down to what it can actually pay). Bake it
anyway — `i_tod_card_penetration_ultimate`, `i_tod_card_recoil_ultimate` and
`i_tod_card_sprint_fire_ultimate` are all installed-but-unreachable for the same
reason, and the Lua's `RegisterImage` loop runs `r = 1..3` unconditionally. A
missing file there is undefined behaviour, and Lua failures in this file are
silent and take the whole HUD with them.

---

## Deliverables — 4 files, exact names, exact sizes

| file | size | notes |
|---|---|---|
| `i_tod_card_distraction_regular.png` | 768 × 1152 | 2 pips, **1 lit** |
| `i_tod_card_distraction_super.png` | 768 × 1152 | 2 pips, **2 lit** |
| `i_tod_card_distraction_ultimate.png` | 768 × 1152 | 2 pips, **2 lit** (clamped — there is no 3rd pip) |
| `i_tod_pause_r41.png` | 300 × 44 | pause-menu nameplate |

All four are RGBA with a **fully transparent background** — the card body sits
on transparency, it is not a rectangle filling the frame.

Drop them in `source_data/tod_ui_images/_images/`.

**Deliver a contact sheet of all four first** so the baked text can be
proofread, then the full-size files named exactly as above.

---

## THE PROMPT — paste this whole block

Attach as style references: `i_tod_card_impact_rounds_super.png`,
`i_tod_card_march_regular.png`, `i_tod_card_vitality_ultimate.png`,
`i_tod_pause_r38.png`.

> You are extending an existing card set for a Call of Duty: Black Ops 3 zombies
> map. **The attached cards ARE the style — match them exactly.** Do not
> reinterpret the template; a new card has to sit in a hand beside these and look
> like it came out of the same deck.
>
> ### The template, top to bottom (identical on all three rarities)
>
> **Canvas:** 768 × 1152 portrait, transparent outside the card edge, small
> transparent margin all round.
>
> 1. **Card body** — a rounded-corner dark navy card (near-black navy, ~`#1e2140`)
>    with a **very thick black outline**, a faint horizontal scanline texture
>    across the navy, and a small dark cross-head screw-bolt in each of the four
>    corners. A slim vertical accent rail runs down the inside of the left edge
>    and the right edge (colour is rarity-driven, below).
> 2. **Title plate** — a rounded **orange-to-amber vertical-gradient** plate with
>    a black outline and a row of **seven small circular studs** along its top
>    edge, holding the card name in chunky white bubble letters with a heavy dark
>    outline: **`DISTRACTION`** — exactly that, all caps, one line, correctly
>    spelled, identical on all three cards.
> 3. **Illustration panel** — a rounded darker blue-navy inset panel with a soft
>    radial sheen across the top, faint scanlines, a thin inner border line, and
>    four tiny decorative pixel squares near its corners (cyan top-left, white
>    top-right, small amber bottom-left, small amber mid-right). The illustration
>    goes inside it — see below. Add two or three small four-point sparkle glyphs
>    and one or two short angular bracket doodles, one upper-left and one
>    lower-right inside the panel.
> 4. **Rarity ribbon** — directly under the illustration panel, a gradient pill
>    with a dark notched arrowhead on each side, holding the rarity text in the
>    same chunky white outlined bubble letters. A round coin medal with a
>    five-point star overlaps the illustration panel's **bottom-right** corner.
> 5. **Value plate** — a dark inset rectangle with a thin rounded inner frame line
>    and a small rivet in each of its four corners, holding **ONE centred line**
>    of chunky all-caps outlined lettering:
>    **`THEY CHASE THE NOISE`** — exactly that text, identical wording on all
>    three cards, only the colour differs. **No second line beneath it.**
> 6. **Pip row** — at the very bottom, **TWO** small round pip sockets side by
>    side. Exactly two. Not three.
>
> ### The illustration (identical on all three cards)
>
> A chunky flat-cartoon **wind-up cymbal monkey toy**, seen three-quarters on,
> filling most of the panel as the clear subject: round head, wide manic grin,
> small red fez, a brass **cymbal in each hand caught mid-clash** with a bright
> white-and-amber impact starburst between them, and two or three curved
> sound-wave arcs radiating outward in **amber**. A wind-up key on its back.
>
> At the monkey's feet, smaller and clearly subordinate, **two little octopus
> creatures** scuttling outward — round domed bodies, big simple cartoon eyes,
> four short tentacles each, drawn in a **sickly green** so they read as a
> different creature from the brass-and-amber monkey. They are sidekicks in the
> composition, not co-stars: roughly a quarter of the monkey's height.
>
> At the left and right edges of the panel, **two small zombie head silhouettes**
> turned *toward* the monkey — flat dark navy, outline-only, no detail, so they
> stay background. The whole read must be **"a noisy thing you throw that pulls
> the horde onto it"**.
>
> No guns. No hearts, crosses or health bars. No blood. No human characters.
>
> ### Rarity treatment — the ONLY differences between the three files
>
> | | REGULAR | SUPER | ULTIMATE |
> |---|---|---|---|
> | side accent rails | **cyan** | **purple/violet** | **gold** |
> | panel inner border + sparkle/bracket doodles | cyan | purple (+ one or two teal) | gold and red (+ one or two teal) |
> | rarity ribbon | **silver/grey** gradient, text `REGULAR +1` | glowing **purple** gradient, text `SUPER +2` | glowing **orange-gold** gradient, text `ULTIMATE +3` |
> | coin medal | silver | gold | gold |
> | value-line lettering | pale grey-blue | purple/lavender | gold/amber |
> | outer glow on the transparent background | **none** | soft lavender-purple glow round the card edge | warm gold-and-pink glow round the card edge, **plus** scattered small gold four-point sparkle crosses and short gold tick marks outside the border |
> | pips | 2 pips, **first lit white**, second dark | 2 pips, **both lit purple-white** | 2 pips, **both lit gold** |
>
> The **illustration itself does not change** between rarities — same monkey,
> same two octopus creatures, same zombie silhouettes, same amber accents.
>
> ### Hard rules
>
> - Flat colours, thick black outlines, simple soft shading. No photorealism, no
>   3D render look, no drop shadows on text.
> - **No digits anywhere** except the `+1` / `+2` / `+3` that are part of the
>   rarity ribbon text.
> - No text anywhere beyond the three specified strings (`DISTRACTION`, the
>   rarity ribbon, `THEY CHASE THE NOISE`).
> - No logos, no watermark, no signature.
>
> ### Also produce the pause-menu plate — `i_tod_pause_r41.png`
>
> A slim horizontal nameplate, exactly **300 × 44** pixels, transparent outside
> the plate. A fully rounded-end **dark navy pill** with a thick dark outline and
> a subtle lighter-navy bevel sheen along its top inside edge. At the **left**
> end, inset just inside the outline, a short bright **cyan vertical bar** (a
> notch). To the right of that notch, **left-aligned** (not centred), the word
> **`DISTRACTION`** in chunky white bubble letters with a dark outline, sized to
> fill most of the plate's height. Flat cartoon style. No icon, no numbers, no
> other text.

---

## Why no numbers are baked in

The carry rules (`1 on grant · +1 per MAX AMMO · cap 3`) and the stage ladder
(`Lv1 Cymbal Monkey → Lv2 Li'l Arnies`) are **deliberately not on the card**.

Card art is the only place a player reads a value at deal time, and a baked
number is falsified by any retune — that is docs/47's whole rationale, and
docs/26 is already stale against a card that was re-baked out from under it. The
numbers live in the pause menu's `DETAIL[41]` row, which is text and costs
nothing to change:

```lua
[41] = { eff = "{V}", act = "carry 1, +1 per MAX AMMO, cap 3",
         val = function( l ) if l >= 2 then return "Li'l Arnies" end
                             return "Cymbal Monkey" end },
```

`THEY CHASE THE NOISE` is level-agnostic and true of both toys, so no re-bake is
ever owed for a balance change. House voice precedent: `PIERCE HEAVIER COVER`
(PENETRATION), `AMMO BACK ON KILLS` (SCAVENGER), `MAG REFILLS ON KILLS`
(KILL RELOAD), `NEVER STOP FIRING` (BULLET FEED).

---

## Proofread checklist — run this on the drop before installing

- [ ] all three cards exactly **768 × 1152**; the plate exactly **300 × 44**
- [ ] corner pixel is `(0,0,0,0)` on all four — **decode it, do not eyeball it**
- [ ] title reads `DISTRACTION`, spelled right, one line, identical on all three
- [ ] value line reads `THEY CHASE THE NOISE`, identical wording on all three,
      colour differs only
- [ ] **no subline** under the value line on any card (docs/40 removed it set-wide)
- [ ] **exactly 2 pips** on every card — 1 lit on REGULAR, 2 lit on SUPER and
      ULTIMATE. Generators normalise to 3; this is the single most likely defect
- [ ] the two Li'l Arnies are visibly present but clearly smaller than the monkey
- [ ] no digits anywhere except `+1` / `+2` / `+3` in the ribbons
- [ ] icon accent is **amber** (assault), not cyan

## Install order — do NOT reorder

1. PNGs into `source_data/tod_ui_images/_images/`
2. four blocks into `source_data/tod_ui_images.gdt` (clone the
   `i_tod_card_vitality_regular` block; change only the asset name and
   `baseImage` path — the pause plate block clones `i_tod_pause_r39`)
3. four `image,` lines into `zone_source/zm_tower_of_doom.zone`, after the
   `image,i_tod_pause_r39` block
4. **only now** `CARD_SLUG[41] = "distraction"` in `tod_upgrade.lua`
5. `PAUSE_PLATE_MAX` **40 → 41** in `AetheriumStartMenu.lua:638` — **only once
   `i_tod_pause_r41` has all three legs** (PNG + GDT block + zone line, i.e.
   steps 1–3 above). It is a shared scalar, not a per-domain flag: it must never
   be raised past the highest plate that actually exists, because every id at or
   below it gets a `RegisterImage`. Ids above it render as plain text rows, which
   is the correct fallback, not a bug.

   *Amended 2026-08-31 after v14.56.* This step previously said to leave the
   constant alone, because raising it for 41 would also have lit up
   `i_tod_pause_r40` before PERK SLOTS had installed it. That is now spent —
   r40 landed with all three legs in v14.56 (`.ff` 19:58:09) and the constant is
   already 40. Verified in-tree rather than taken on report. So 41 is the only
   step left, and it has no dependency on anyone else's work.
6. `node tools/lint_tod_lua.js`, then a **FULL** `.\tools\build_map.ps1` — a
   `.gdt` edit is always a full build
7. prove conversion by content: a fresh content-hash `.iwi` stamped by this
   build, beside an untouched control file that did not move

Steps 4–5 before step 3 is a `RegisterImage` on a missing image, and the failure
mode of this Lua file is silent: the menu fails to load and the upgrade panel,
damage numbers, tower gauge, luck bar, finale banner and rampage seal all vanish
at once.
