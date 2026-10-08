<!-- art-pack
name: slasher_baseball_bat
refs:
  i_tod_card_class_slasher.png | DELIVERABLE 1, current version. The class-draft card. The whole chassis stays; only the picture inside the art window and the baked weapon name change.
  i_tod_hud_gun_blade.png | DELIVERABLE 2, current version. The bottom-right HUD weapon cell for this weapon. The filename is stale and stays as it is - only the drawing changes.
  i_tod_card_class_assault.png | The same card chassis on another class. Proof of what must NOT move: frame, tier banner, name plate, pips.
  i_tod_card_class_mage.png | The same chassis again, with a two-line weapon name in the bottom plate. Use this setting if BASEBALL BAT needs two lines.
  i_tod_card_tier_slasher_2.png | The slasher's TIER 2 card, NOT a deliverable. Context only - it carries the class's next weapon and keeps it.
  i_tod_hud_gun_katana.png | HUD cell house style, and the very next weapon in this class's ladder. The nearest neighbour - match this weight exactly.
  i_tod_hud_gun_axe.png | HUD cell house style, third weapon in the ladder - shows how much detail survives at this size.
preview: 186x279 144x66
-->

# 137 — SLASHER: the combat knife becomes a BASEBALL BAT

> **STATUS: REQUESTED 2026-09-14. Nothing installed, no build owed until the
> drop comes back.**
>
> **SCOPE TRIMMED 2026-09-14** on the user's *"I only need gun hud icons and
> new class card assets. Thats all. I dont need new class icons or anything.
> 2 for each"* — the first cut of this pack also asked for the small class
> icon, the CLASS SLASHER plate and the scoreboard medallion. All three are
> dropped; the HUD cell was promoted from optional to required.

## Why (user, 2026-09-14)

> *"We are looking to replace the combat knife with the baseball bat as
> slashers starting weapon. Can you create an asset zip request so we can
> update the class selection image for slasher?"*

## Repo-facing notes (NOT in the pack)

**THE CODE IS ALREADY THERE — ONLY THE ART IS STALE.** Same situation as the
skirmisher (docs/138) and the heavy (docs/139): `_tod_classes.gsc:339` registers
the slasher's tier-1 weapon as **`t9_me_baseballbat`**, the weapon has its own
`source_data/tod_baseball_bat.gdt`, `tools/gen_tod_twins.js:1424` emits its
twins, and `AetheriumLoadout.lua:175` / `:329` / `:330` already route
`t9_me_baseballbat`, the display name `BASEBALL BAT` and the PaP name
`GRAND SLAMMER` to the `blade` icon cell. So a player drafting SLASHER today
swings a bat while the draft card shows a combat knife and says `COMBAT KNIFE`.
**These two images are the only place the old weapon survives, and they can be
installed the moment they arrive.**

⚠️ **AN EARLIER REVISION OF THIS DOC SAID THE OPPOSITE** — "the weapon itself
is not ported yet", from a grep of `_tod_classes.gsc` that read
`t9_me_knife_american` and a `source_data/t9_weapons/melee/` listing with no
bat in it. The bat's GDT is at `source_data/tod_baseball_bat.gdt`, one level
up from where that listing looked. Corrected 2026-09-14 on the user's *"The bat
is in the game as slasher tier 1"*. The lesson is the repo's own: a stale
prose claim outlives the thing it describes — read the `register_gun` call, not
a summary of it.

| file | size | drawn at | registered in | wiring owed |
|---|---|---|---|---|
| `i_tod_card_class_slasher` | 768x1152 | 186x279 | `tod_class_select.lua:368` | none — same name |
| `i_tod_hud_gun_blade` | 288x132 | 144x66 | `AetheriumLoadout.lua:175` | see below |

⚠️ **`i_tod_hud_gun_blade` IS SHARED BY EIGHT THINGS, AND THAT IS NOW A REAL
DECISION, NOT A FUTURE ONE.** `AetheriumLoadout.lua` maps `t9_me_baseballbat`,
`bowie_knife`, `knife_widows_wine`, `bowie_knife_widows_wine`,
`sickle_knife_widows_wine`, `zombie_fists`, `zombie_fists_bowie` and the
display name `KNIFE` all onto the `blade` cell. The bowie is the slasher's own
alt melee (`register_gun`'s 6th argument, all three tiers), Widow's Wine
re-skins the base knife, and `zombie_fists` is what a downed or disarmed player
holds. **The moment this cell draws a bat, all seven of those draw a bat too.**

Unlike `mac10` and `stoner63` — which are exclusively the MSMC and the MK 48 —
this cell cannot just be redrawn and left. The fix is a second cell: a new
image name plus a GDT block, a zone `image,` line and a `TOD_GUN_CAT` row
pointing `t9_me_baseballbat` / `BASEBALL BAT` / `GRAND SLAMMER` at it, leaving
the knives and fists on `blade`. That is script/zone work, not art, and it
should land in the same build that installs this drop.

**Keep the stale filename in the art drop regardless** — the generator has no
business knowing about the split, and the delivered PNG can be renamed here for
free.

NOT deliverables (dropped on the user's 2026-09-14 trim): the small class icon
`i_tod_class_slasher`, the `i_tod_upg_class_slasher` plate and the
`i_tod_class_medallion_slasher` scoreboard medal. All three draw a generic
purple blade rather than a combat knife specifically, so they read acceptably
with a bat in hand. The slasher's tier 2 and 3 cards (wakizashi, Stormbreaker)
are unaffected. The secondary is still the CW AMP63 (`TOD_SEC_SLASHER_1`), so
the card's `AMP63` line is correct and stays.

Install: copy into `source_data/tod_ui_images/_images/`, FULL build, prove with
a fresh content-hash `.iwi` beside an untouched control.

<!-- PACK:BEGIN -->
# SLASHER CLASS ART — replace the combat knife with a BASEBALL BAT

The SLASHER class in this game starts with a combat knife. It is being changed
to a **baseball bat**. Two existing pieces of artwork draw that knife and need
to be redrawn around the new weapon.

Both are **drop-in replacements**: same filename, same pixel size, same style,
same layout. Only the depicted weapon — and one line of baked text — changes.

## Deliverables

| # | filename | size | what changes |
|---|---|---|---|
| 1 | `i_tod_card_class_slasher.png` | **768 x 1152** | the weapon in the art window + the baked name `COMBAT KNIFE` -> `BASEBALL BAT` |
| 2 | `i_tod_hud_gun_blade.png` | **288 x 132** | the weapon drawn in the cell (keep this exact filename — it is stale on purpose) |

Both are PNG with a real alpha channel. Do not change either canvas size.

## What the baseball bat should look like

A plain wooden baseball bat. Not a spiked bat, not a nail bat, not a
barbed-wire bat, not a metal bat — this is a clean bat, and it is the weakest
weapon in its class's ladder, so it should read as ordinary rather than
monstrous.

- Tapered barrel, a narrower handle, a knob at the butt end.
- Wood grain is welcome on the card; on the small HUD cell drop it entirely.
- **Read it at a glance.** The silhouette is the whole job: a thick end, a thin
  end, a knob. Anyone squinting at the icon must see "bat", not "club", "pipe"
  or "sword".
- Keep it the same physical size in frame as the knife it replaces — do not let
  a longer object shrink itself to fit. It may overrun the art window's
  diagonal the way the knife's blade does.

## Hard rules

1. **THE CARD CHASSIS DOES NOT MOVE.** On deliverable 1, every pixel outside
   the inner art window and the bottom weapon-name plate must stay exactly
   where it is: the outer frame, the corner screws, the orange `TIER 1` banner,
   the purple `SLASHER` name bar, the dot row at the bottom, the inner panel's
   border and its faint scan lines. Compare against
   `reference/i_tod_card_class_assault.png` — those two cards must still look
   like the same object after your change.
2. **KEEP THE EXISTING TEXT EXCEPT ONE LINE.** `TIER 1`, `DODGE AND CLEAVE`,
   `SLASHER` and `AMP63` all stay, in the same place, at the same size, in the
   same font. The ONLY text that changes is `COMBAT KNIFE` -> `BASEBALL BAT`,
   in the bottom plate, in the same purple, same font, same style. If
   `BASEBALL BAT` does not fit on one line at the existing size, set it on two
   lines the way `reference/i_tod_card_class_mage.png` does — do not shrink it
   into illegibility.
3. **KEEP THE PALETTE.** This class is PURPLE, but only on the card: dark navy
   ground, purple accents, light-grey highlights. The HUD cell is flat
   near-black / pale blue-grey / slate blue only — no purple there, see
   `reference/i_tod_hud_gun_katana.png`.
4. **KEEP THE SWING ARC ON THE CARD.** The card art draws a dashed purple
   motion arc behind the weapon. Keep it, adjusted to the bat's new shape — it
   is what says "melee class". The HUD cell has no arc and gains none.
5. **KEEP THE TREATMENT PER FILE.** These are not one style:
   - card art window: chunky black outline, flat colour, soft highlight, a soft
     shadow beneath the weapon;
   - HUD cell: flat, exactly three tones (near-black, pale blue-grey, slate
     blue), heavy black outline, object laid diagonally corner to corner, no
     gradient, no shadow.
6. **TRANSPARENT BACKGROUND** on the HUD cell, and no new backing plate, glow,
   outer drop shadow or border anywhere.
7. **NO NEW TEXT ANYWHERE.** No numbers, no labels, no watermark, no signature.

## Size to judge at

These are drawn small. Check both files zoomed OUT, not zoomed in:

| file | actual on-screen size |
|---|---|
| `i_tod_card_class_slasher.png` | **186 x 279** |
| `i_tod_hud_gun_blade.png` | **144 x 66** |

The `preview_onscreen_*` folders in this pack show the reference images scaled
that way. If the bat is unreadable there, it is unreadable in the game.

## Prompts

**Deliverable 1 — the class card.** Attach
`reference/i_tod_card_class_slasher.png` and
`reference/i_tod_card_class_assault.png`.

> Redraw this game UI card. Keep the entire card frame, the orange TIER 1
> banner, the purple SLASHER bar, the bottom panel and the dot row exactly as
> they are, pixel for pixel. Inside the dark art window, replace the combat
> knife with a plain wooden baseball bat of the same size and in the same
> pose — laid diagonally, barrel to the upper right, knob to the lower left —
> in the same chunky black-outlined flat cartoon style, with the same purple
> dashed swing arc behind it and the same soft shadow beneath it. Keep the
> words DODGE AND CLEAVE at the top of that window untouched. In the bottom
> plate, change the purple text COMBAT KNIFE to BASEBALL BAT in the identical
> font, colour and size; leave AMP63 below it untouched. Output 768x1152 PNG.

**Deliverable 2 — the HUD cell.** Attach `reference/i_tod_hud_gun_blade.png`,
`reference/i_tod_hud_gun_katana.png` and `reference/i_tod_hud_gun_axe.png`.

> Draw a plain wooden baseball bat in this icon set's exact style: laid
> diagonally across the cell from lower left to upper right, filling the same
> proportion of the frame as the knife it replaces, heavy dark outline, flat
> fill with only three tones (near-black, pale blue-grey, slate blue), no
> purple, no gradient, no background. Tapered barrel at the top right, narrow
> handle and a knob at the bottom left. No wood grain — it is too small. Output
> 288x132 PNG, transparent background.

## Delivery checklist

- [ ] Exact filenames (including the stale `i_tod_hud_gun_blade.png`), exact
      pixel sizes, PNG with alpha.
- [ ] The card's frame, banner, name bar and dot row are untouched.
- [ ] `BASEBALL BAT` is spelled correctly and set in the original font/colour.
- [ ] `TIER 1`, `DODGE AND CLEAVE`, `SLASHER`, `AMP63` all still present and
      unchanged.
- [ ] The bat reads as a bat at the on-screen sizes listed above.
- [ ] No spikes, nails, wire, or blades anywhere.
- [ ] Nothing added: no new text, glow, border, or background.

## Do NOT

- Do not rename either file.
- Do not restyle the card, change the palette, or "modernise" the frame.
- Do not resize, recrop or re-letterbox either canvas.
- Do not touch the slasher's TIER 2 or TIER 3 cards.
  `reference/i_tod_card_tier_slasher_2.png` is attached for context only — it
  shows the same chassis carrying the class's NEXT weapon, which keeps its own
  sword and is not part of this job.
- Do not change any text other than `COMBAT KNIFE`.
- Do not deliver JPG, WebP, or a flattened PNG with a solid background.
- Do not deliver a photograph or a photorealistic render.
<!-- PACK:END -->
