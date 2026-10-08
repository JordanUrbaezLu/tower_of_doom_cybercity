<!-- art-pack
name: mage_wizard_hat
refs:
  i_tod_class_slasher.png | THE GLYPH CHASSIS - flat, thick dark outline, ONE accent colour, on transparency. Match this treatment exactly.
  i_tod_class_heavy.png | A second glyph, for breadth - only the accent colour and the object change.
  i_tod_class_mage.png | THE CURRENT mage glyph, being REPLACED. A staff; it becomes the hat.
  i_tod_class_medallion_slasher.png | THE MEDALLION CHASSIS - accent ring, dark navy field, the object rendered PALE against it. Match ring, depth and framing exactly.
  i_tod_class_medallion_heavy.png | A second medallion, for breadth.
  i_tod_class_medallion_mage.png | THE CURRENT mage medallion, being REPLACED.
  i_tod_upg_class_slasher.png | THE CLASS BANNER chassis - note the small ROUND ICON BADGE at the left end, which carries the same object again.
  i_tod_upg_class_mage.png | THE CURRENT mage banner, being REPLACED. Its baked text is already right; only the badge art changes.
preview: 64x56 56x56 280x60
-->

# 122 — the MAGE's icon becomes a wizard hat

**Status: SHIPPED v18.48, 2026-09-08.** The drop
(`files - 2026-09-08T144532.485.zip`) delivered all three at the requested sizes
on the first pass — one hat, three renderings, mint throughout, the banner's
baked text untouched. Nothing was sent back for revision. The medallion wiring
warned about below was closed in v18.47, the build before the art landed.

User: *"I also want to update the icon for this class to be a wizard hat. A
detailed wizard hat… can you gather all the scenarios where we have the icon and
zip them up with new instructions… let's really stay consistent with how the
other classes do icons and everything and class banners."*

## The sweep — every surface the class icon draws on

Read out of the code, not the earlier doc:

| File | Where it draws | Drawn at | Found via |
|---|---|---|---|
| `i_tod_class_mage.png` | the GLYPH on the class draft card | 64 × 56 | `tod_class_select.lua` `art.icons[5]` |
| `i_tod_class_medallion_mage.png` | the HUD portrait disc, and the party list | 56 × 56 | `AetheriumCharacters.lua` → `AetheriumPlayerInfo` + `AetheriumPartyPlayers` |
| `i_tod_upg_class_mage.png` | the CLASS BANNER on the upgrade panel — the small round badge at its left end | 280 × 60 | `tod_upgrade.lua` `art.classPlate[5]` |

Three surfaces, three files. The class DRAFT CARD and the two TIER CARDS are a
separate request (`docs/121`) and show the staffs, not the hat — that split is
deliberate and is the reason a hat works here at all: the mage carries THREE
weapons, so no single weapon can be its mark the way the katana is the slasher's.

## THE MEDALLION WAS NOT WIRED — CLOSED IN v18.47, KEPT AS A RECORD

⚠️ **This section is HISTORY, not a live warning.** It described the state on
2026-09-08 before v18.47; read it that way. A warning left in the present tense
after its fix is the single most reliable way this project misleads a later
reader.

`i_tod_class_medallion_mage.png` existed, was zoned, and **never drew**. Two
independent gaps, both in code:

1. **`_tod_classes::class_body_index()` has no `"mage"` case.** It returns
   `undefined`, so `apply_class_body()` no-ops and a mage keeps whatever body
   stock happened to assign.
2. **`AetheriumCharacters.lua` maps only four character ids** (`char5`..`char8`)
   — the four Shadows of Evil bodies, one per original class. There is no fifth
   row, because the mage has no body of its own to key one to.

So today a mage displays **whichever of the other four classes' medallions**
belongs to the body they were handed. Not a blank — a wrong one.

**HOW IT WAS ACTUALLY CLOSED (v18.47):** the mage got Richtofen (body 2 —
derived from core_common.csv order, which all four shipping bodies confirm), and
rather than spend a playtest on the char id, the mage claimed the WHOLE unused
low range: char0..char4 all map to its medallion. Safe because the four shipping
classes are pinned to bodies 5..8 reporting char5..char8, all four observed, so
none can reach those rows. The original plan below needed an observation: That id **cannot be derived** —
the table's own history records three separate observations that each killed a
natural ordering (boxer 5 → char8, magician 8 → char7, detective 6 → char6). It
is a playtest question, not a reasoning one. Worth doing in the same build as
this art lands, so the hat has somewhere to appear.

## Install notes (repo-facing, not in the pack)

All three keep their existing filenames, so the install is a straight file swap:
no GDT block, no zone line, no Lua change. FULL build; proof is a fresh
content-hash `.iwi` for each beside an untouched control.

<!-- PACK:BEGIN -->

# TOWER OF DOOM — the MAGE's class icon: a wizard hat

**3 PNG files.** A fifth class in a neon cyber-city zombies map is changing its
icon, and that icon appears in three different places at three different sizes.
All three replace files that already ship, at the same filenames, and all three
sit beside four other classes' versions in the same frame.

**Consistency with the reference images is the whole job.** A piece that is
beautiful but off-style is a failure.

---

## 1. Deliverables

| # | File | Size | Draws on screen at | What it is |
|---|---|---|---|---|
| 1 | `i_tod_class_mage.png` | 224 × 196 | **64 × 56** | the flat glyph on the class card |
| 2 | `i_tod_class_medallion_mage.png` | 512 × 512 | **56 × 56** | the round portrait badge on the HUD |
| 3 | `i_tod_upg_class_mage.png` | 420 × 90 | **280 × 60** | the class banner, with the icon in a small circle at its left end |

Exact filenames, exact pixel sizes, PNG with alpha. No other files.

---

## 2. The subject — one hat, three renderings

**A detailed wizard hat.** Classic and unmistakable: a tall pointed cone with a
**bent, slightly drooping tip**, a **wide circular brim** that curves, and a
**band around the base of the cone** with a buckle or clasp.

Detail is welcome at full size — a fold in the felt, a worn edge, a few small
stars or arcane marks on the cone, a highlight along the brim. But **the
silhouette carries it**: pointed cone + bent tip + wide brim is what a player
reads at 56 pixels. Nothing may depend on detail that vanishes there.

**The same hat in all three files.** Same proportions, same tilt, same bend in
the tip. What changes is only the rendering, per the sections below.

**Colour: mint green `#59FFCC`**, the mage's accent, already used across all
three current files. Keep it.

⚠️ **Draw the hat only — no face, no figure, no head inside it.** The other four
classes' icons are objects, and a character would break the set.

---

## 3. File 1 — `i_tod_class_mage.png` (224 × 196, drawn at 64 × 56)

Match `reference/i_tod_class_slasher.png` and `reference/i_tod_class_heavy.png`
**exactly** in treatment:

- **Flat.** One accent colour for the object, one darker tone for its shadowed
  side, one lighter tone for a highlight. No gradients, no glow, no texture.
- **A very heavy dark outline** around the whole object — thicker than looks
  right at full size. It is what keeps the glyph alive at 64 px.
- Transparent background, object centred with a little padding, filling the
  landscape frame on a slight diagonal the way the references do.
- No ring, no plate, no background shape — just the object.

Subject: the wizard hat, three-quarter view, tipped so the bent point reaches
toward one upper corner and the brim sweeps to the opposite lower one. That
diagonal is what fills a landscape frame with a tall object.

---

## 4. File 2 — `i_tod_class_medallion_mage.png` (512 × 512, drawn at 56 × 56)

Match `reference/i_tod_class_medallion_slasher.png` **exactly**: a thick
accent-coloured **ring** with a lighter inner bevel, a **dark navy circular
field** inside it, and the object rendered **pale and light against that dark
field** with accent-coloured shading — not flat like the glyph, but shaded with
real depth and a highlight.

- **Square canvas, circular badge**, edge to edge with the same margin as the
  reference. The box that draws it is square and the art is stretched to fill,
  so anything off-square distorts.
- The ring's hard outer edge is what survives the downscale to 56 px — keep it
  exactly as thick as the reference's.
- The hat sits centred and large, on the same diagonal as the glyph.

**This is the hardest legibility test in the set.** Up to four of these are on
screen at once at 56 pixels. Solve the hat's silhouette at that size first and
scale the idea up; check `preview_onscreen_56x56/` before you finish it.

---

## 5. File 3 — `i_tod_upg_class_mage.png` (420 × 90, drawn at 280 × 60)

Match `reference/i_tod_upg_class_slasher.png` **exactly** — same rounded dark
plate, same accent keyline, same round icon badge at the left end, same type
size and placement.

**The baked text is already correct on the current version and does not change:**
the word `CLASS` in white followed by `MAGE` in mint. Reproduce
`reference/i_tod_upg_class_mage.png` and change **only the artwork inside the
small round badge at the left**, from the staff to the wizard hat.

That badge is tiny — roughly 40 px across on screen. Use the **glyph** treatment
from file 1 there (flat, heavy outline, mint), not the medallion's shading, and
simplify further if you must: at that size the cone, the bend and the brim are
the entire drawing.

---

## 6. The set test

Put the three finished files side by side at the sizes in section 1. A player
must recognise the same hat in all three. If the medallion's hat and the glyph's
hat read as different objects, the silhouettes have drifted — fix the
silhouette, not the shading.

---

## 7. Hard rules

1. **Exact filenames and exact pixel sizes.** PNG with alpha throughout.
2. **The same hat, same proportions, same tilt, in all three files.**
3. **Mint `#59FFCC`** on all three.
4. **The hat only.** No face, no head, no figure, no staff.
5. **Match each file's own reference treatment** — the glyph is flat, the
   medallion is shaded inside a ring, the banner badge is flat and tiny.
6. **Do not change the banner's baked text or its plate**; only the badge art.
7. **Check `preview_onscreen_*/`.** 56 px is the real test.
8. No watermark, no signature, no border of your own.

---

## 8. Paste-ready prompts

**A — the glyph.** *Attach `i_tod_class_slasher.png`, `i_tod_class_heavy.png`,
`i_tod_class_mage.png`.*
> Match the treatment of the first two attached class glyphs exactly — a single
> object on a transparent background, drawn flat in one accent colour with one
> darker shadow tone and one lighter highlight, no gradients or glow, and a very
> heavy dark outline around the whole shape. The third attachment is the file you
> are replacing; keep its mint green #59FFCC. Subject: a detailed wizard hat —
> a tall pointed cone with a bent drooping tip, a wide curved brim, and a banded
> base with a clasp — in three-quarter view, tilted on a diagonal so the point
> reaches an upper corner and the brim sweeps to the opposite lower one, filling
> the landscape frame. Draw the hat only: no face, no head, no figure. It must
> read clearly at 64 x 56 pixels. 224x196 PNG.

**B — the medallion.** *Attach `i_tod_class_medallion_slasher.png`,
`i_tod_class_medallion_heavy.png`, `i_tod_class_medallion_mage.png`.*
> Match the first two attached medallions exactly — a thick accent-coloured outer
> ring with a lighter inner bevel, a dark navy circular field inside it, and the
> subject rendered pale and light against that field with accent-coloured shading
> and a highlight, so it has real depth rather than the flat treatment of the
> class glyphs. Same ring thickness, same margins, perfectly square canvas and
> perfectly circular badge. Keep the mint green #59FFCC of the third attachment,
> which is the file you are replacing. Subject: the same detailed wizard hat as
> the glyph — tall pointed cone with a bent drooping tip, wide curved brim,
> banded base with a clasp — centred, large, on the same diagonal. No face, no
> head, no figure. It must be readable at 56 x 56 pixels, so solve the silhouette
> at that size first. 512x512 PNG.

**C — the class banner.** *Attach `i_tod_upg_class_mage.png`,
`i_tod_upg_class_slasher.png`, and your finished glyph from prompt A.*
> Reproduce the first attached banner exactly at 420x90 with a transparent
> background — same rounded dark plate, same mint keyline, same round icon badge
> at the left end, same baked text (`CLASS` in white followed by `MAGE` in mint),
> same type size and placement — and change ONE thing: the artwork inside the
> small round badge at the left becomes the wizard hat from the third attachment
> instead of the staff. Use the flat glyph treatment there (one accent colour,
> heavy dark outline), simplified as needed: the badge is about 40 pixels across
> on screen, so the cone, the bend and the brim are the whole drawing. The second
> attachment shows the same banner for another class, to confirm which parts of
> the plate are fixed. 420x90 PNG.

---

## 9. Delivery checklist

- [ ] Three PNGs, exact names, exact sizes, RGBA with real transparency
- [ ] The same wizard hat, same proportions and tilt, in all three
- [ ] Glyph is FLAT with a heavy outline; medallion is SHADED inside its ring
- [ ] The medallion canvas is square and the badge is circular
- [ ] The banner's plate, keyline and baked text are untouched — badge art only
- [ ] Mint `#59FFCC` throughout
- [ ] No face, head, figure or staff anywhere
- [ ] All three checked in `preview_onscreen_*/`, especially 56 × 56

## 10. Do NOT

- Do not draw a wizard, a face, or a head — the hat is the icon.
- Do not keep the staff in any of the three.
- Do not give the glyph or the badge a ring, a plate or a background.
- Do not give the medallion the glyph's flat treatment, or vice versa.
- Do not change the banner's text, plate shape or keyline.
- Do not add fine detail that disappears at 56 pixels.
- Do not rename the files.
<!-- PACK:END -->
