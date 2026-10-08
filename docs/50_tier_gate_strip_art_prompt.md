# 50 — CLASS TIER GATE BADGE: art prompt (2 images)

> **2026-09-02 — TIER 3 MOVED TO FLOOR 30.** `i_tod_tier_gate_3.png` was re-baked
> to read TIER 3 AT FLOOR 30 (pack + install record: docs/72). Every "FLOOR 20"
> below is the historical record of the original bake, kept verbatim. One claim
> below is now WRONG: "the tier number is not a fourth home" — the Lua derived
> the tier as floor/10+1, which only inverts an evenly spaced ladder; it is an
> explicit `TIER_FLOOR_TO_TIER` table since docs/72, LOCKSTEP with the GSC.

> **STATUS: SHIPPED 2026-08-31.** The user picked **explore direction 3, the
> up-chevron** — steel pill, amber stacked double chevron on the left disc,
> reading as *climb* rather than *refused*. Both PNGs are installed, entered in
> `tod_ui_images.gdt`, given their `.zone` lines, and `USE_TIER_GATE_ART` is
> `true`. Verified before install: 420×90 and colortype 6 (RGBA) read from the
> PNG headers, and **legibility checked by actually downscaling to the on-screen
> 280×60 and looking at it** — the delivered type is lighter than the luck
> badge's heavy outlined face, which is a deviation from the chassis spec below,
> and it survives the 1.5× reduction cleanly. Kept as delivered.
>
> The prompts below stay verbatim as the record of what was asked for, and are
> the starting point for any re-bake (which a floor retune requires — see the
> baked-numbers warning).

**Why:** v14.35 gated the CLASS TIER promotion on the climb — tier 2 needs floor
10, tier 3 needs floor 20, on top of Pack-a-Punch. A withheld tier card is
*silent*, so the rule was undiscoverable. User ask, verbatim: *"Yeah how can we
add some clue"*, then the standing rule: *"Typically we try to only use assets
pngs to display things."*

This is that clue: a baked badge on the upgrade panel, shown **only** when the
floor is the sole thing withholding the tier card.

**Scope: TWO new images.** Nothing existing is regenerated or replaced.

| New file | Reads | Shown when |
|---|---|---|
| `i_tod_tier_gate_2.png` | TIER 2 AT FLOOR 10 | player is tier 1, gun PaP'd, high-water below floor 10 |
| `i_tod_tier_gate_3.png` | TIER 3 AT FLOOR 20 | player is tier 2, gun PaP'd, high-water below floor 20 |

Path: `source_data/tod_ui_images/_images/`

---

## Hard specs (non-negotiable)

- **Canvas 420 × 90, PNG, RGBA, fully transparent background.** This is the
  shipped luck badge's own canvas (`i_tod_badge_luck_100.png`), measured from the
  file — see the placement rule below for why that is not a coincidence.
- **Renders at 280 × 60 on screen** (`tod_upgrade.lua`, `TierGateImg`). Canvas
  aspect 4.667 = draw aspect 4.667 **exactly**. Do not hand back a different
  ratio: this map has a stretched-plate lesson (v6.6) and every plate is drawn
  on its own aspect.
- **It must survive a 1.5× downscale.** No hairlines, no type below the sizes
  given, no fine texture that will alias.
- The two files must be **pixel-identical in chassis, glyph position and scale**
  to each other. They swap by tier at runtime, and any drift makes the badge
  jump between a tier-1 and a tier-2 player's screen.

### It is the MIRROR of the luck badge, and that decides everything

The upgrade panel already has one deal-status indicator: the **luck badge**,
280×60 at `x 950..1230, y 150..210` — top-right, beside the header banner. The
banner spans `x 340..940`, so the top-left gutter `x 50..330` is empty and is the
exact mirror of that slot. **This badge goes there, same row, same size.** The
panel then reads as one system: what boosted this deal on the right, what is
being withheld from it on the left.

**It is deliberately NOT a strip under the cards.** That was the first design and
it was wrong on measurement, not taste: the cards' input hints end at y 612,
`SwitchHintImg` occupies 650..693, the countdown 697..717. Thirty-eight free
pixels — anything placed there lands on the switch hint.

**Attach `i_tod_badge_luck_100.png` to every generation step as the chassis
reference.** Do not work from description alone.

---

## The chassis it has to match

From the reference PNG (look at it, don't trust this list alone):

- **Stadium/pill plate** — fully rounded ends, not a rounded rectangle.
- Near-black **navy interior**, very slightly lighter toward the top.
- A **thick neon outer stroke** with a soft outer glow, and a thin darker
  keyline just inside it.
- A **circular emblem on the LEFT**, breaking out past the pill's left end,
  sitting in a pale disc with its own ring.
- **Chunky white all-caps display type**, heavy dark outline, slightly
  condensed, optically centred in the remaining space.
- **One token in the accent colour** rather than white (the reference does this
  with `100%`).
- Small **four-point sparkle glyphs** just outside the pill, top-left and
  bottom-right.

Keep all of that. Change the colour, the emblem and the words.

---

## THE ONE DESIGN DECISION: it must NOT be gold

The luck badge is **already gold**, and this badge sits on the same row 620px
away. A gold badge in the mirror slot reads as a second luck badge — the player
glances, pattern-matches "gold pill, top of panel", and skips it. That defeats
the whole point, because the player this exists for is the one who has already
stopped reading the screen and is wondering why the tier card never comes.

**So: a dimmed STEEL-BLUE pill with an AMBER padlock and an amber number.**

- **pill stroke, keyline and sparkles: desaturated steel blue-grey**, around
  `#7C8AA0`, with a cool dim glow. Deliberately *duller* than anything else on
  the panel — "inactive / not yet yours" is the read.
- **the emblem is a PADLOCK, closed**, in bright amber `#FFC84D` on the pale
  disc. It is the one bright thing on the badge and it carries the meaning.
- **`10` (or `20`) is amber**, matching the padlock — mirroring how the luck
  badge accents `100%`. Everything else in the type is white.
- **interior stays the same near-black navy** as the reference. Do not warm or
  lighten it, or it stops matching the panel.

The contrast is the message: bright gold badge on the right = *you earned
something*. Dim steel badge with a gold lock on the left = *something is being
held back, and here is the key*.

---

## Layout and copy (exact strings)

One line, mirroring the reference's rhythm exactly.

```
   ( LOCK )  TIER 2  AT  FLOOR 10
   amber      white  white  white + amber "10"
```

- `i_tod_tier_gate_2.png` → **`TIER 2 AT FLOOR 10`**, the `10` amber.
- `i_tod_tier_gate_3.png` → **`TIER 3 AT FLOOR 20`**, the `20` amber.

Same character count in both, so the two files are trivially identical in
layout — only the `2→3` and `10→20` glyphs change. Nothing else moves.

Type size: cap height ~34px on the 420px canvas (≈23px on screen). `AT` may be
set smaller and dimmer than the rest — it is the only filler word.

---

## ⚠ THE NUMBERS ARE BAKED IN

`10` and `20` are in the art, so **a gate retune is not finished until these two
PNGs are re-baked.** Same rule the upgrade cards already live under (docs/33).
The floors have three homes and all three move together:

1. `TOD_TIER2_FLOOR` / `TOD_TIER3_FLOOR` in `_tod_upgrades.gsc` — the gate
   itself, the only one that changes behaviour;
2. `DETAIL[24].act` in `tod_upgrade.lua` — the pause-menu line;
3. **these two images.**

The *tier* number is not a fourth home — the Lua derives it from the floor
(`floor / 10 + 1`, the exact inverse of `tier_floor_req`), so the art only ever
has to agree about the floors.

---

## Step 1 — EXPLORE (one image, five directions)

Generate `i_tod_tier_gate_2.png` only, five ways, so the direction can be picked
before the pair is committed.

**ATTACH `i_tod_badge_luck_100.png` TO EVERY ONE OF THESE.** Each prompt is
self-contained — copy one whole block, do not chain them.

### Direction 1 — STRAIGHT MIRROR (the baseline)

```text
Using the attached image as the exact chassis reference, create a Black Ops 3
zombies HUD badge.

Canvas exactly 420 x 90 pixels, PNG, fully transparent background (RGBA). Flat
vector-clean game-UI art: crisp edges, no photographic texture, no noise, no
grain. It must stay legible when scaled down to 280 x 60.

Copy the reference's construction exactly:
- a stadium/pill plate with fully rounded ends
- near-black navy interior, very slightly lighter toward the top
- a thick neon outer stroke with a soft outer glow, and a thin darker keyline
  just inside it
- a circular emblem on the LEFT, breaking out past the pill's left end, sitting
  in a pale disc with its own ring
- chunky white all-caps display type, heavy dark outline, slightly condensed,
  optically centred in the space to the right of the emblem
- small four-point sparkle glyphs just outside the pill, top-left and
  bottom-right

Change only these three things:
1. The stroke, keyline, glow and sparkles go from gold to a DESATURATED STEEL
   BLUE-GREY, about #7C8AA0, with a cool dim glow. It must read as dimmer and
   cooler than the reference - "locked, not yet yours".
2. The emblem is a CLOSED PADLOCK in bright amber #FFC84D on the pale disc. It
   is the single brightest thing on the badge.
3. The type reads: TIER 2 AT FLOOR 10 - all caps, white, except "10" which is
   the same bright amber as the padlock, and "AT" which is set smaller and
   dimmer than the rest. Cap height about 34px on the 420px canvas.

Keep the interior the same near-black navy as the reference. Do not warm it.
```

### Direction 2 — ALTIMETER EMBLEM (ties it to the tower gauge)

```text
Using the attached image as the exact chassis reference, create a Black Ops 3
zombies HUD badge.

Canvas exactly 420 x 90 pixels, PNG, fully transparent background (RGBA). Flat
vector-clean game-UI art: crisp edges, no photographic texture, no noise, no
grain. It must stay legible when scaled down to 280 x 60.

Copy the reference's construction exactly:
- a stadium/pill plate with fully rounded ends
- near-black navy interior, very slightly lighter toward the top
- a thick neon outer stroke with a soft outer glow, and a thin darker keyline
  just inside it
- a circular emblem on the LEFT, breaking out past the pill's left end, sitting
  in a pale disc with its own ring
- chunky white all-caps display type, heavy dark outline, slightly condensed,
  optically centred in the space to the right of the emblem
- small four-point sparkle glyphs just outside the pill, top-left and
  bottom-right

Change only these three things:
1. The stroke, keyline, glow and sparkles go from gold to a DESATURATED STEEL
   BLUE-GREY, about #7C8AA0, with a cool dim glow. It must read as dimmer and
   cooler than the reference - "locked, not yet yours".
2. The emblem is an ALTIMETER glyph in bright amber #FFC84D: a narrow vertical
   tower silhouette with five short horizontal floor ticks up its side, the
   topmost tick brighter than the rest. Simple, iconic, no perspective.
3. The type reads: TIER 2 AT FLOOR 10 - all caps, white, except "10" which is
   the same bright amber as the emblem, and "AT" which is set smaller and
   dimmer than the rest. Cap height about 34px on the 420px canvas.

Keep the interior the same near-black navy as the reference. Do not warm it.
```

### Direction 3 — UP-CHEVRON (an instruction, not a refusal)

```text
Using the attached image as the exact chassis reference, create a Black Ops 3
zombies HUD badge.

Canvas exactly 420 x 90 pixels, PNG, fully transparent background (RGBA). Flat
vector-clean game-UI art: crisp edges, no photographic texture, no noise, no
grain. It must stay legible when scaled down to 280 x 60.

Copy the reference's construction exactly:
- a stadium/pill plate with fully rounded ends
- near-black navy interior, very slightly lighter toward the top
- a thick neon outer stroke with a soft outer glow, and a thin darker keyline
  just inside it
- a circular emblem on the LEFT, breaking out past the pill's left end, sitting
  in a pale disc with its own ring
- chunky white all-caps display type, heavy dark outline, slightly condensed,
  optically centred in the space to the right of the emblem
- small four-point sparkle glyphs just outside the pill, top-left and
  bottom-right

Change only these three things:
1. The stroke, keyline, glow and sparkles go from gold to a DESATURATED STEEL
   BLUE-GREY, about #7C8AA0, with a cool dim glow. It must read as dimmer and
   cooler than the reference - "locked, not yet yours".
2. The emblem is a STACKED DOUBLE CHEVRON pointing UP in bright amber #FFC84D -
   two thick angled chevrons, one above the other, the upper one brighter. It
   should read as "climb".
3. The type reads: TIER 2 AT FLOOR 10 - all caps, white, except "10" which is
   the same bright amber as the chevrons, and "AT" which is set smaller and
   dimmer than the rest. Cap height about 34px on the 420px canvas.

Keep the interior the same near-black navy as the reference. Do not warm it.
```

### Direction 4 — CRIMSON LOCK (louder; test whether it reads as "blocked")

```text
Using the attached image as the exact chassis reference, create a Black Ops 3
zombies HUD badge.

Canvas exactly 420 x 90 pixels, PNG, fully transparent background (RGBA). Flat
vector-clean game-UI art: crisp edges, no photographic texture, no noise, no
grain. It must stay legible when scaled down to 280 x 60.

Copy the reference's construction exactly:
- a stadium/pill plate with fully rounded ends
- near-black navy interior, very slightly lighter toward the top
- a thick neon outer stroke with a soft outer glow, and a thin darker keyline
  just inside it
- a circular emblem on the LEFT, breaking out past the pill's left end, sitting
  in a pale disc with its own ring
- chunky white all-caps display type, heavy dark outline, slightly condensed,
  optically centred in the space to the right of the emblem
- small four-point sparkle glyphs just outside the pill, top-left and
  bottom-right

Change only these three things:
1. The stroke, keyline, glow and sparkles go from gold to a DESATURATED STEEL
   BLUE-GREY, about #7C8AA0, with a cool dim glow. It must read as dimmer and
   cooler than the reference - "locked, not yet yours".
2. The emblem is a CLOSED PADLOCK in bright CRIMSON #E0463C on the pale disc,
   with a faint red glow. It is the single brightest thing on the badge.
3. The type reads: TIER 2 AT FLOOR 10 - all caps, white, except "10" which is
   the same crimson as the padlock, and "AT" which is set smaller and dimmer
   than the rest. Cap height about 34px on the 420px canvas.

Keep the interior the same near-black navy as the reference. Do not warm it.
```

### Direction 5 — HALF-LIT PILL (the decorative one; included to be rejected)

```text
Using the attached image as the exact chassis reference, create a Black Ops 3
zombies HUD badge.

Canvas exactly 420 x 90 pixels, PNG, fully transparent background (RGBA). Flat
vector-clean game-UI art: crisp edges, no photographic texture, no noise, no
grain. It must stay legible when scaled down to 280 x 60.

Copy the reference's construction exactly:
- a stadium/pill plate with fully rounded ends
- near-black navy interior, very slightly lighter toward the top
- a thick neon outer stroke with a soft outer glow, and a thin darker keyline
  just inside it
- a circular emblem on the LEFT, breaking out past the pill's left end, sitting
  in a pale disc with its own ring
- chunky white all-caps display type, heavy dark outline, slightly condensed,
  optically centred in the space to the right of the emblem
- small four-point sparkle glyphs just outside the pill, top-left and
  bottom-right

Change only these three things:
1. The outer stroke is a LEFT-TO-RIGHT GRADIENT: desaturated steel blue-grey
   #7C8AA0 at the left end, warming to bright amber #FFC84D at the right end, as
   if the badge is partly unlocked. The glow follows the same gradient. Sparkles
   stay steel.
2. The emblem is a CLOSED PADLOCK in bright amber #FFC84D on the pale disc.
3. The type reads: TIER 2 AT FLOOR 10 - all caps, white, except "10" which is
   the same bright amber as the padlock, and "AT" which is set smaller and
   dimmer than the rest. Cap height about 34px on the 420px canvas.

Keep the interior the same near-black navy as the reference. Do not warm it.
```

## Step 2 — BUILD OUT (after a direction is chosen)

Once one direction is picked, regenerate it cleanly as the final
`i_tod_tier_gate_2.png`, then make its sibling with this prompt — **attach the
finished tier-2 badge, not the luck badge**:

```text
Here is a finished Black Ops 3 zombies HUD badge. Produce the matching sibling
image.

Canvas exactly 420 x 90 pixels, PNG, fully transparent background (RGBA) -
identical to the attached file.

Change EXACTLY TWO THINGS and nothing else:
- "TIER 2" becomes "TIER 3"
- "FLOOR 10" becomes "FLOOR 20"

Everything else must be pixel-identical to the attached image: the same pill
shape and size, the same stroke colour and weight, the same glow, the same
emblem in the same position at the same scale, the same sparkle glyphs, the same
typeface, the same cap height, the same letterspacing, the same baseline, and
the same overall composition width. The two badges swap places on screen at
runtime, so any drift in position or scale will make the badge visibly jump.
Keep "20" in the same accent colour that "10" is in.
```

---

## Install (all of it, in order)

1. Drop both PNGs in `source_data/tod_ui_images/_images/`.
2. Add two entries to `source_data/tod_ui_images.gdt`, copying an existing
   `i_tod_badge_luck_*` block verbatim and changing only the asset name and
   `baseImage` path (it is already the right uncompressed sRGB+alpha shape).
3. Add two lines to `zone_source/zm_tower_of_doom.zone` beside the other badges:
   ```
   image,i_tod_tier_gate_2
   image,i_tod_tier_gate_3
   ```
4. Flip `USE_TIER_GATE_ART = false` → `true` in `tod_upgrade.lua`.
5. **FULL build, not `-GscOnly`** — a `.gdt` edit is always a full build.
6. Verify with a **fresh content-hash `.iwi` plus an untouched control** (a `.ff`
   raw grep is invalid — the file is compressed).

Until step 4 the LUI text fallback ships and the clue works; it is just
text-on-panel instead of a badge. Nothing is broken while the art is in flight.

---

## What does NOT need art

The **pause-menu CLASS TIER row** is the other half of this clue (it now shows
from tier 1, reading `tier 2: Pack-a-Punch + floor 10`). It needs **no new
asset**: its name plate `i_tod_pause_r24` already exists and is already zoned,
and every one of that panel's ~30 rows draws its two detail lines as LUI text by
design. Baking those would mean baking thirty-odd level-aware lines that change
whenever a domain is retuned — the opposite of what the images-over-LUI rule is
for. Art carries the *chrome* there; the text is the data.
