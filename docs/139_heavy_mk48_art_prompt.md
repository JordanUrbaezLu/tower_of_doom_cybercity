<!-- art-pack
name: heavy_mk48
refs:
  i_tod_card_class_heavy.png | DELIVERABLE 1, current version. The class-draft card. The whole chassis stays; only the gun inside the art window and the baked weapon name change.
  i_tod_hud_gun_stoner63.png | DELIVERABLE 2, current version. The bottom-right HUD weapon cell for this gun. The filename is stale and stays as it is - only the drawing changes.
  i_tod_card_class_assault.png | The same card chassis on another class. Proof of what must NOT move: frame, tier banner, name plate, pips.
  i_tod_card_class_skirmisher.png | The same chassis again, third class. Shows the per-class accent colour is the ONLY thing that varies.
  i_tod_card_tier_heavy_2.png | The heavy's TIER 2 card, NOT a deliverable. Context only - it carries the class's next gun and keeps it.
  i_tod_hud_gun_hk21.png | HUD cell house style, and the very next gun in this class's ladder. The nearest neighbour - match this weight exactly.
  i_tod_hud_gun_minigun.png | HUD cell house style, third gun in the ladder. Shows how a very heavy weapon fills the cell.
  i_tod_hud_gun_ak47.png | HUD cell house style, a rifle - the length to stay clear of.
preview: 186x279 144x66
-->

# 139 — HEAVY: the Stoner 63 art becomes the MK 48

> **STATUS: REQUESTED 2026-09-14. Nothing installed, no build owed until the
> drop comes back.**

## Why (user, 2026-09-14)

> *"Also the skirmisher will use the msmc and the heavy will use mk48. I need
> those asset requests as well"*

## Repo-facing notes (NOT in the pack)

**THE CODE IS ALREADY THERE — ONLY THE ART IS STALE.** Same situation as the
skirmisher (docs/138), and unlike the slasher's baseball bat (docs/137):
`_tod_classes.gsc:331` registers the heavy's tier-1 gun as **`t6_mk48`**, and
`AetheriumLoadout.lua:146` / `:349` already route `t6_mk48` and the display name
`MK 48` to the `stoner63` icon cell. So a player drafting HEAVY today is handed
an MK 48 while the draft card shows a Stoner 63 and says `STONER 63`. **These
two images are the only place the old gun survives.** They can be installed the
moment they arrive — there is no weapon work to wait for.

| file | size | drawn at | registered in | wiring owed |
|---|---|---|---|---|
| `i_tod_card_class_heavy` | 768x1152 | 186x279 | `tod_class_select.lua:367` | none — same name |
| `i_tod_hud_gun_stoner63` | 288x132 | 144x66 | `AetheriumLoadout.lua:146` | none — same name |

**The `stoner63` cell is EXCLUSIVELY the MK 48** — three rows point at it
(`t6_mk48`, `MK 48`, and the PaP name `MAGNA IMPETU`) and all three are the same
gun. Nothing else shares it, so redrawing it is safe. **Keep the stale
filename.** Renaming it to `i_tod_hud_gun_mk48` would cost a GDT block, a zone
`image,` line and a Lua row for zero player-visible gain.

NOT deliverables, checked and deliberately excluded:

- `i_tod_class_heavy` (the small icon on the same card) is a generic red rifle
  with a bullet belt, not a Stoner. No change.
- `i_tod_upg_class_heavy` and `i_tod_class_medallion_heavy` carry generic class
  glyphs, not this gun. No change.
- The tier 2 and 3 cards (HK21, Death Machine) are unaffected.
- The secondary is still the starter MR6 (`TOD_SEC_HEAVY_1`), so the card's
  `MR6` line is correct and stays.

Install: copy into `source_data/tod_ui_images/_images/`, FULL build, prove with
a fresh content-hash `.iwi` beside an untouched control.

**If the drop comes back weak on likeness**, the fix is in-game screenshots —
that is what closed the same gap for the mage staffs (docs/128). Ask the user
for a first-person shot of the MK 48 held and re-issue with it attached.

<!-- PACK:BEGIN -->
# HEAVY CLASS ART — the gun is now an MK 48, not a Stoner 63

The HEAVY class in this game used to start with a **Stoner 63**. It now starts
with an **MK 48**. Two existing pieces of artwork still draw the Stoner and
need to be redrawn around the new gun.

Both are **drop-in replacements**: same filename, same pixel size, same style,
same layout. Only the depicted gun — and one line of baked text — changes.

## Deliverables

| # | filename | size | what changes |
|---|---|---|---|
| 1 | `i_tod_card_class_heavy.png` | **768 x 1152** | the gun in the art window + the baked name `STONER 63` -> `MK 48` |
| 2 | `i_tod_hud_gun_stoner63.png` | **288 x 132** | the gun drawn in the cell (keep this exact filename — it is stale on purpose) |

Both are PNG with a real alpha channel. Do not change either canvas size.

## What the MK 48 looks like

The MK 48 is a modern belt-fed light machine gun (the FN Mk 48, a 7.62mm
weapon in the same family as the M249 SAW / Minimi; it appears in Call of Duty:
Black Ops II). Look up reference photos — this is a real, well-documented
weapon. Its signature, and what has to survive into a small stylised drawing:

- A **belt of ammunition**, and a **boxy ammunition container clipped under the
  middle of the receiver**. This is the single most recognisable feature of the
  gun and the clearest difference from the Stoner currently drawn — if only one
  detail survives at small size, make it this one. A few visible belt links
  feeding into the left side of the receiver sell it instantly.
- A **long, heavy barrel** with a slotted heat shield / handguard and a **carry
  handle on top of the barrel**.
- A **bipod folded under the muzzle end**.
- A solid shoulder stock at the rear, and a pistol grip.
- A flat top rail with a low optic or iron sight.

It should read as a **big, serious, belt-fed machine gun** — this is the
slowest, heaviest class in the game and the gun is the whole promise. Heavier
and longer than an assault rifle (see `reference/i_tod_hud_gun_ak47.png` for
where a rifle sits) but not as absurd as the minigun in
`reference/i_tod_hud_gun_minigun.png`.

## Hard rules

1. **THE CARD CHASSIS DOES NOT MOVE.** On deliverable 1, every pixel outside
   the inner art window and the bottom weapon-name plate must stay exactly
   where it is: the outer frame, the corner screws, the orange `TIER 1` banner,
   the red `HEAVY` name bar, the dot row at the bottom, the inner panel's
   border and its faint scan lines. Compare against
   `reference/i_tod_card_class_assault.png` and
   `reference/i_tod_card_class_skirmisher.png` — all three cards must still
   look like the same object after your change.
2. **KEEP THE EXISTING TEXT EXCEPT ONE LINE.** `TIER 1`,
   `SLOW AND DEVASTATING`, `HEAVY` and `MR6` all stay, in the same place, at
   the same size, in the same font. The ONLY text that changes is `STONER 63`
   -> `MK 48`, in the bottom plate, in the same red, same font, same size, same
   style. `MK 48` is shorter than `STONER 63`, so keep it centred and do NOT
   stretch it to fill the old width.
3. **KEEP THE PALETTE.** This class is RED. The card's art window is a dark
   navy ground with red accents and light-grey gun metal. The HUD cell is flat
   near-black / pale blue-grey / slate blue only — no red there, see
   `reference/i_tod_hud_gun_hk21.png`.
4. **KEEP THE POSE AND THE FRAMING.** On the card the gun lies across the art
   window at the same diagonal, muzzle to the right, at the same size in frame,
   with the same soft yellow motion streaks behind it and the same small red
   spark near the muzzle. On the HUD cell the gun lies corner to corner and
   fills the same proportion of the cell as the current drawing.
5. **KEEP THE TREATMENT PER FILE.** These are not one style:
   - card art window: chunky black outline, flat colour, one soft highlight
     stripe along the top of the body, a thin red accent line;
   - HUD cell: flat, exactly three tones (near-black, pale blue-grey, slate
     blue), heavy black outline, no gradient, no highlight stripe.
6. **TRANSPARENT BACKGROUND** on the HUD cell, and no new backing plate, glow,
   outer drop shadow or border anywhere.
7. **NO NEW TEXT ANYWHERE.** No calibre, no model number, no labels, no
   watermark, no signature.

## Size to judge at

These are drawn small. Check both files zoomed OUT, not zoomed in:

| file | actual on-screen size |
|---|---|
| `i_tod_card_class_heavy.png` | **186 x 279** |
| `i_tod_hud_gun_stoner63.png` | **144 x 66** |

The `preview_onscreen_*` folders in this pack show the reference images scaled
that way. If the gun is unreadable there, it is unreadable in the game.

At 144x66 the belt and the ammo box are the details worth spending pixels on.
The carry handle and the bipod can be simplified to two or three strokes; the
optic can go entirely.

## Prompts

**Deliverable 1 — the class card.** Attach
`reference/i_tod_card_class_heavy.png`,
`reference/i_tod_card_class_assault.png` and
`reference/i_tod_card_class_skirmisher.png`.

> Redraw this game UI card. Keep the entire card frame, the orange TIER 1
> banner, the red HEAVY bar, the bottom panel and the dot row exactly as they
> are, pixel for pixel. Inside the dark art window, replace the Stoner 63 with
> an MK 48 belt-fed light machine gun — long heavy barrel with a slotted
> handguard and a carry handle on top, a folded bipod under the muzzle, a boxy
> ammunition container clipped under the middle of the receiver with a short
> belt of rounds feeding in, a solid stock at the rear — at the same size, at
> the same diagonal angle, muzzle to the right, in the same chunky
> black-outlined flat cartoon style, with the same soft yellow motion streaks
> behind it and the same small red spark at the muzzle. Keep the words SLOW AND
> DEVASTATING at the top of that window untouched. In the bottom plate, change
> the red text STONER 63 to MK 48 in the identical font, colour and size,
> centred; leave MR6 below it untouched. Output 768x1152 PNG.

**Deliverable 2 — the HUD cell.** Attach
`reference/i_tod_hud_gun_stoner63.png`, `reference/i_tod_hud_gun_hk21.png`,
`reference/i_tod_hud_gun_minigun.png` and `reference/i_tod_hud_gun_ak47.png`.

> Draw an MK 48 belt-fed light machine gun in this icon set's exact style: laid
> diagonally across the cell, filling the same proportion of the frame as the
> gun it replaces, heavy dark outline, flat fill with only three tones
> (near-black, pale blue-grey, slate blue), no gradient, no background. Give it
> the MK 48's silhouette — long slotted barrel with a carry handle, a folded
> bipod, and above all a boxy ammunition container under the receiver with a
> few belt links feeding into it — so it reads as a belt-fed machine gun at a
> glance. Output 288x132 PNG, transparent background.

## Delivery checklist

- [ ] Exact filenames (including the stale `i_tod_hud_gun_stoner63.png`), exact
      pixel sizes, PNG with alpha.
- [ ] The card's frame, banner, name bar and dot row are untouched.
- [ ] `MK 48` is spelled correctly, with the space, and set in the original
      font/colour/size.
- [ ] `TIER 1`, `SLOW AND DEVASTATING`, `HEAVY`, `MR6` all still present and
      unchanged.
- [ ] The ammunition belt and box are readable at the on-screen sizes listed
      above.
- [ ] Nothing added: no new text, glow, border, or background.

## Do NOT

- Do not rename either file.
- Do not restyle the card, change the palette, or "modernise" the frame.
- Do not resize, recrop or re-letterbox either canvas.
- Do not touch the heavy's TIER 2 or TIER 3 cards.
  `reference/i_tod_card_tier_heavy_2.png` is attached for context only — it
  shows the same chassis carrying the class's NEXT gun, which keeps its own
  weapon and is not part of this job.
- Do not change any text other than `STONER 63`.
- Do not draw a minigun, a rotary barrel, or a rifle.
- Do not deliver JPG, WebP, or a flattened PNG with a solid background.
- Do not deliver a photograph or a photorealistic render.
<!-- PACK:END -->
