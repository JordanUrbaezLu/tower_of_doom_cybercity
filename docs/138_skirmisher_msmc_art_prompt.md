<!-- art-pack
name: skirmisher_msmc
refs:
  i_tod_card_class_skirmisher.png | DELIVERABLE 1, current version. The class-draft card. The whole chassis stays; only the gun inside the art window and the baked weapon name change.
  i_tod_hud_gun_mac10.png | DELIVERABLE 2, current version. The bottom-right HUD weapon cell for this gun. The filename is stale and stays as it is - only the drawing changes.
  i_tod_card_class_assault.png | The same card chassis on another class. Proof of what must NOT move: frame, tier banner, name plate, pips.
  i_tod_card_class_heavy.png | The same chassis again, third class. Shows the per-class accent colour is the ONLY thing that varies.
  i_tod_card_tier_skirmisher_2.png | The skirmisher's TIER 2 card, NOT a deliverable. Context only - it carries the class's next gun and keeps it.
  i_tod_hud_gun_mp5.png | HUD cell house style, and the very next gun in this class's ladder. Match this weight exactly.
  i_tod_hud_gun_mp7.png | HUD cell house style, third gun in the ladder.
  i_tod_hud_gun_ak47.png | HUD cell house style, a longer weapon - shows how a full-size gun fills the cell.
preview: 186x279 144x66
-->

# 138 — SKIRMISHER: the MAC-10 art becomes the MSMC

> **STATUS: REQUESTED 2026-09-14. Nothing installed, no build owed until the
> drop comes back.**

## Why (user, 2026-09-14)

> *"Also the skirmisher will use the msmc and the heavy will use mk48. I need
> those asset requests as well"*

## Repo-facing notes (NOT in the pack)

**THE CODE IS ALREADY THERE — ONLY THE ART IS STALE.** Unlike the slasher's
baseball bat (docs/137), this swap has already happened:
`_tod_classes.gsc:325` registers the skirmisher's tier-1 gun as **`t6_msmc`**,
and `AetheriumLoadout.lua:138` / `:359` already route `t6_msmc` and the display
name `MSMC` to the `mac10` icon cell. So a player drafting SKIRMISHER today is
handed an MSMC while the draft card shows a MAC-10 and says `MAC-10`. **These
two images are the only place the old gun survives.** They can be installed the
moment they arrive — there is no weapon work to wait for.

| file | size | drawn at | registered in | wiring owed |
|---|---|---|---|---|
| `i_tod_card_class_skirmisher` | 768x1152 | 186x279 | `tod_class_select.lua:365` | none — same name |
| `i_tod_hud_gun_mac10` | 288x132 | 144x66 | `AetheriumLoadout.lua:138` | none — same name |

**The `mac10` cell is EXCLUSIVELY the MSMC** — three rows point at it
(`t6_msmc`, `MSMC`, and the PaP name `MINIATURE SINISTER MISCHIEVOUS CATALYST`)
and all three are the same gun. Nothing else shares it, so redrawing it is
safe. **Keep the stale filename.** Renaming it to `i_tod_hud_gun_msmc` would
cost a GDT block, a zone `image,` line and a Lua row for zero player-visible
gain.

NOT deliverables, checked and deliberately excluded:

- `i_tod_class_skirmisher` (the small icon on the same card) is a running
  figure with a generic pistol, not a MAC-10. No change.
- `i_tod_upg_class_skirmisher` and `i_tod_class_medallion_skirmisher` carry
  generic class glyphs, not this gun. No change.
- The tier 2 and 3 cards (MP5, MP7) are unaffected.
- The secondary is still the AW Bulldog (`TOD_SEC_SKIRMISHER_1`), so the card's
  `BULLDOG` line is correct and stays.

Install: copy into `source_data/tod_ui_images/_images/`, FULL build, prove with
a fresh content-hash `.iwi` beside an untouched control.

**If the drop comes back weak on likeness**, the fix is in-game screenshots —
that is what closed the same gap for the mage staffs (docs/128). Ask the user
for a first-person shot of the MSMC held and re-issue with it attached.

<!-- PACK:BEGIN -->
# SKIRMISHER CLASS ART — the gun is now an MSMC, not a MAC-10

The SKIRMISHER class in this game used to start with a **MAC-10**. It now
starts with an **MSMC**. Two existing pieces of artwork still draw the MAC-10
and need to be redrawn around the new gun.

Both are **drop-in replacements**: same filename, same pixel size, same style,
same layout. Only the depicted gun — and one line of baked text — changes.

## Deliverables

| # | filename | size | what changes |
|---|---|---|---|
| 1 | `i_tod_card_class_skirmisher.png` | **768 x 1152** | the gun in the art window + the baked name `MAC-10` -> `MSMC` |
| 2 | `i_tod_hud_gun_mac10.png` | **288 x 132** | the gun drawn in the cell (keep this exact filename — it is stale on purpose) |

Both are PNG with a real alpha channel. Do not change either canvas size.

## What the MSMC looks like

The MSMC is a compact modern submachine gun (it appears in Call of Duty:
Black Ops II, and is based on the Chang Feng SMG). Look up reference photos —
this is a real, well-documented weapon. Its signature, and what has to survive
into a small stylised drawing:

- A **long, straight, boxy body** — much more rectangular and slab-sided than
  the MAC-10, with a flat top rail running most of its length.
- A **long, straight magazine** in front of the trigger group, sitting well
  forward of the pistol grip. The MAC-10's magazine is the grip; the MSMC's is
  not, and **that is the single clearest difference between the two.**
- A short barrel poking just past the handguard, often with a small muzzle
  device.
- A collapsible stock or a plain stub at the rear.
- A pistol grip below and behind the magazine.

The current art shows a MAC-10: a stubby blocky box with the magazine going
down through the grip and a wire loop stock. The new drawing should read as a
**longer, sleeker, more modern SMG**, and should be noticeably different in
silhouette from the old one — if someone could mistake the new drawing for the
old one, it has not done its job.

Keep it compact. It is still a submachine gun, not a rifle — see
`reference/i_tod_hud_gun_ak47.png` for how much longer a full-size rifle reads
in this set, and do not go that far.

## Hard rules

1. **THE CARD CHASSIS DOES NOT MOVE.** On deliverable 1, every pixel outside
   the inner art window and the bottom weapon-name plate must stay exactly
   where it is: the outer frame, the corner screws, the orange `TIER 1` banner,
   the cyan `SKIRMISHER` name bar, the dot row at the bottom, the inner panel's
   border and its faint scan lines. Compare against
   `reference/i_tod_card_class_assault.png` and
   `reference/i_tod_card_class_heavy.png` — all three cards must still look
   like the same object after your change.
2. **KEEP THE EXISTING TEXT EXCEPT ONE LINE.** `TIER 1`, `RUN AND GUN`,
   `SKIRMISHER` and `BULLDOG` all stay, in the same place, at the same size, in
   the same font. The ONLY text that changes is `MAC-10` -> `MSMC`, in the
   bottom plate, in the same cyan, same font, same size, same style. `MSMC` is
   shorter than `MAC-10`, so keep it centred and do NOT stretch it to fill the
   old width.
3. **KEEP THE PALETTE.** This class is CYAN. The card's art window is a dark
   navy ground with cyan accents and light-grey gun metal. The HUD cell is flat
   near-black / pale blue-grey / slate blue only — no cyan there, see
   `reference/i_tod_hud_gun_mp5.png`.
4. **KEEP THE POSE AND THE FRAMING.** On the card the gun lies across the art
   window at the same diagonal, at the same size in frame, with the same soft
   yellow motion streaks behind it and the same small cyan speed ticks near the
   muzzle. On the HUD cell the gun lies corner to corner and fills the same
   proportion of the cell as the current drawing.
5. **KEEP THE TREATMENT PER FILE.** These are not one style:
   - card art window: chunky black outline, flat colour, one soft highlight
     stripe along the top of the body, a thin cyan accent line;
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
| `i_tod_card_class_skirmisher.png` | **186 x 279** |
| `i_tod_hud_gun_mac10.png` | **144 x 66** |

The `preview_onscreen_*` folders in this pack show the reference images scaled
that way. If the gun is unreadable there, it is unreadable in the game.

## Prompts

**Deliverable 1 — the class card.** Attach
`reference/i_tod_card_class_skirmisher.png`,
`reference/i_tod_card_class_assault.png` and
`reference/i_tod_card_class_heavy.png`.

> Redraw this game UI card. Keep the entire card frame, the orange TIER 1
> banner, the cyan SKIRMISHER bar, the bottom panel and the dot row exactly as
> they are, pixel for pixel. Inside the dark art window, replace the MAC-10
> with an MSMC submachine gun — a longer, straighter, boxier modern SMG with a
> flat top rail and a long straight magazine set forward of the pistol grip —
> at the same size, at the same diagonal angle, muzzle to the right, in the
> same chunky black-outlined flat cartoon style, with the same soft yellow
> motion streaks behind it and the same small cyan speed ticks at the muzzle.
> Keep the words RUN AND GUN at the top of that window untouched. In the bottom
> plate, change the cyan text MAC-10 to MSMC in the identical font, colour and
> size, centred; leave BULLDOG below it untouched. Output 768x1152 PNG.

**Deliverable 2 — the HUD cell.** Attach `reference/i_tod_hud_gun_mac10.png`,
`reference/i_tod_hud_gun_mp5.png`, `reference/i_tod_hud_gun_mp7.png` and
`reference/i_tod_hud_gun_ak47.png`.

> Draw an MSMC submachine gun in this icon set's exact style: laid diagonally
> across the cell, filling the same proportion of the frame as the gun it
> replaces, heavy dark outline, flat fill with only three tones (near-black,
> pale blue-grey, slate blue), no gradient, no background. Give it the MSMC's
> silhouette — a straight boxy receiver with a flat top rail, a long straight
> magazine forward of the pistol grip, a short barrel and a stubby stock — so
> it reads as a different, more modern gun than the stubby MAC-10 currently
> drawn. Output 288x132 PNG, transparent background.

## Delivery checklist

- [ ] Exact filenames (including the stale `i_tod_hud_gun_mac10.png`), exact
      pixel sizes, PNG with alpha.
- [ ] The card's frame, banner, name bar and dot row are untouched.
- [ ] `MSMC` is spelled correctly and set in the original font/colour/size.
- [ ] `TIER 1`, `RUN AND GUN`, `SKIRMISHER`, `BULLDOG` all still present and
      unchanged.
- [ ] The new gun's silhouette is clearly NOT the old MAC-10 at the on-screen
      sizes listed above.
- [ ] Nothing added: no new text, glow, border, or background.

## Do NOT

- Do not rename either file.
- Do not restyle the card, change the palette, or "modernise" the frame.
- Do not resize, recrop or re-letterbox either canvas.
- Do not touch the skirmisher's TIER 2 or TIER 3 cards.
  `reference/i_tod_card_tier_skirmisher_2.png` is attached for context only —
  it shows the same chassis carrying the class's NEXT gun, which keeps its own
  weapon and is not part of this job.
- Do not change any text other than `MAC-10`.
- Do not deliver JPG, WebP, or a flattened PNG with a solid background.
- Do not deliver a photograph or a photorealistic render.
<!-- PACK:END -->
