# 89 — PLAYER HUD (bottom-left panel): legibility re-bake (4 images)

<!-- art-pack
name: player_hud
refs:
  docs/89_hud_ref/current_panel_onscreen.png | THE BRIEF IN ONE PICTURE: the whole panel at its true 1080p size, then magnified. Attach to every prompt.
  docs/89_hud_ref/current_player_plate.png | the CURRENT panel backing (blue electric wisp). Its family is kept; the portrait bay and the readout area are what change. Attach to Prompt D.
  docs/89_hud_ref/current_health_frame.png | the CURRENT health frame: ~48 segments, which is what smears. Attach to Prompt B.
  docs/89_hud_ref/current_health_fill.png | the CURRENT health fill strip that sits inside the frame. Attach to Prompt C.
  docs/89_hud_ref/current_points_icon.png | the CURRENT points glyph: a beveled 3D render that cannot survive its downscale. Attach to Prompt A.
  docs/89_hud_ref/class_medallion_heavy.png | the class disc that sits in the portrait bay. NOT a deliverable - it shows the bay's contents, ring weight and palette. Attach to Prompt D.
preview: 516x172 190x11 192x10 24x24 77x77
-->

> **STATUS: SHIPPED v16.98, 2026-09-03 — UNPLAYED.** Pack out 17:07, drop back
> 17:22, installed and FULL-built by 17:39. All four delivered at the requested
> sizes and passed every pixel check (see the CHANGELOG). The zip held two
> PIXEL-IDENTICAL copies of the set differing only in PNG encoding; the loose
> one omitted the fill, so the nested set shipped. The plate came back a
> REDESIGN rather than the refinement asked for — kept, because it reads far
> better; the co-op mismatch with the unchanged teammate rows is the open item.
> Two of the four defects
> had already been fixed in code that morning (v16.97): the portrait box is
> square, the points-icon box is square.

**Why (user, 2026-09-03):** *"Our atherium player HUD on bottom left is pretty
bad in terms of detail. Looks low detail the icons and kinda squished. ... get
maybe 4k images for those icons and get more detail or something. They just
look bad and squished. Maybe its the HUD fault IDK."*

## The diagnosis — measured, and it is NOT resolution

The instinct in that last sentence is right. **Nothing in this panel is starved
of source pixels.** Every element already carries 2–10× the pixels it is ever
shown at, even on a 1440p screen. 4K source art would change nothing.

Draw rects read out of `AetheriumPlayerInfo.lua`; source sizes from the PNG
headers; physical pixels are the 1280×720 LUI canvas × 1.5 for 1080p:

| element | source | drawn (canvas) | 1080p px | src used | aspect error |
|---|---|---|---|---|---|
| plate | 960×320 | 344×115 | 516×173 | 54% | ok |
| **portrait** | 256×256 | **51×59** | 77×89 | 30% | **−13.6%** |
| **points icon** | 256×256 | **16×15** | 24×23 | 9% | **+6.7%** |
| health fill | 768×40 | 127×7 | 191×11 | 25% | −5.5% |
| **health frame** | 1728×100 | **129×9** | 194×14 | 11% | **−17.1%** |
| shield fill | 448×40 | 131×7 | 197×11 | 44% | +67% (flat art, invisible) |
| downed icon | 128×128 | 30×30 | 45×45 | 35% | ok |

Four real causes, in the order they hurt:

1. **SQUISH #1 — the portrait was literally an ellipse.** A 256×256 square
   medallion was being drawn into a 51 wide × 59 tall box, and LUI stretches an
   image to fill its box: a circle pulled 13.6% vertically, bottom-left, where
   the eye goes. **This is the same bug v16.21 fixed for the TEAMMATE rows on
   2026-09-02** (`AetheriumPartyPlayers.lua`, "Any image put here must be
   SQUARE") — the local player's own panel was missed in that pass. Fixed
   v16.97: the box is 51×51, re-centred at y 629..680. No art needed.

2. **SQUISH #2 — the health frame is a 48-segment ladder shown 194 px wide.**
   That is under 4 physical pixels per segment including its gap, so it
   resolves to a grey smear (look at the top row of
   `current_panel_onscreen.png`). It is *also* squeezed 17% narrower than its
   source aspect, which packs the segments tighter still. **More source
   resolution makes this worse, not better** — the defect is the segment COUNT
   against the on-screen width. Needs art: fewer, fatter segments.

3. **LOW DETAIL — every kit image is DXT5 block-compressed.** Proven from the
   converted `.iwi` headers, not inferred: the essence glyph decompresses to
   65,632 bytes for a 256×256 image (DXT5 + 96-byte header) and the plate to
   307,296 for 960×320 (same arithmetic), while our own
   `i_tod_class_medallion_assault` decompresses to 262,240 = 256×256 RGBA8.
   The GDT agrees — `bo7_aetherium_hud.gdt` sets `compressionMethod
   "compressed"` on all of them; all **505** entries in `tod_ui_images.gdt` are
   `uncompressed`. DXT5 quantises 4×4 blocks, which is worst exactly on what
   this kit is made of: smooth blue gradients, thin strokes, soft alpha.

4. **LOW DETAIL — beveled 3D renders read at 24 px.** The essence glyph is a
   lit, beveled, gradient-shaded 3D "Z". At 24×24 physical pixels every one of
   those cues collapses. Needs art: a flat, high-contrast silhouette authored
   *for* that size.

**Why the fix is to bring these assets in-house.** Cause 3 could be fixed by
flipping `compressionMethod` in `bo7_aetherium_hud.gdt` — but that file lives
in the mod-tools root under `model_export/_OwensAssets/`, is **not** in this
repo, is **shared with map 1** (the `.acc-purple-orig` backups beside it are
map 1's edits), and nothing here would regenerate the change. Re-authoring the
four assets as `i_tod_hud_*` in `tod_ui_images.gdt` fixes causes 2, 3 and 4 at
once, version-controlled, with no reach into a shared file.

### Not in scope, deliberately

- **The teammate rows** (`AetheriumPartyPlayers.lua`, co-op only) keep the kit's
  own `i_mtl_ui_hud_party_member_theme_aetherium` plate. That is why Prompt D
  asks for a *refinement inside the existing electric-blue wisp family* rather
  than a redesign: the two must still read as one HUD. If the new plate lands
  well, the party plate (1024×320, drawn 276×87) is the follow-on.
- **The +15% HUD scale.** `AetheriumHud.lua`'s v15 `TodScaleHud` pass scaled
  Loadout, Powerups, RoundCounter and CursorHint and skipped this widget, so it
  does read small next to its neighbours. Scaling it is one line, but at 1.15
  about its own bottom-left corner the panel grows to y≈578 and its overlap
  with party row 1 (bottom edge y=611) goes from 16 px to 33 px. Worth doing
  only together with a matching scale on the party stack — a separate change,
  after this art is judged in game.
- **The shield fill's +67% stretch** (`i_mtl_ui_hud_party_health_bar_fill` in
  the shield slot). Real, but the asset is a flat 685-byte strip that is then
  wipe-clipped and colour-tinted, so the stretch is not visible. Left alone
  rather than "fixed" for tidiness. The riot shield went live in v16.63, so
  this lane now actually draws — worth a look in game.

## Geometry the art must hit

All boxes on the 1280×720 LUI canvas. **The Lua boxes move to these values when
the art is installed** — see Install below.

| slot | box (canvas) | @1080p | @1440p | deliver at | exact aspect |
|---|---|---|---|---|---|
| plate | 345×115 (x 16..361, y 595..710) | 518×173 | 690×230 | **1536×512** | 3.0 |
| health frame | 129×12 (x 93..222, y 648..660) | 194×18 | 258×24 | **1032×96** | 10.75 |
| health fill | 127×10 (x 94..221, y 649..659) | 191×15 | 254×20 | **1016×80** | 12.7 |
| points icon | 16×16 (x 89..105, y 661..677) | 24×24 | 32×32 | **256×256** | 1.0 |

Plate is 345 wide, not 344, so the aspect is exactly 3.0 and 1536×512 lands
unstretched. The health frame grows from 9 to 12 canvas px — the only free
band is 648..660, between the shield bar (ends 648) and the points icon
(starts 661).

**Positions inside the 1536×512 plate art** (scale = 1536/345 = 4.4522):

| what sits there | plate-art px |
|---|---|
| portrait bay interior (square, holds the class disc) | x 89..316, y 151..378 |
| HP text `150 HP`, right-aligned-ish | x 770..944, y 160..196 |
| player name | x 365..815, y 183..231 |
| shield bar (only when a riot shield is held) | x 338..922, y 205..236 |
| health frame | x 343..917, y 236..289 |
| points icon | x 325..396, y 294..365 |
| points number | x 396..721, y 312..361 |

## Runtime tints the art MUST survive

Written down because getting one wrong ships a bug that only appears on a down.

- **Health fill is tinted by code**: `setRGB(1,1,1)` alive, **`setRGB(1,0.2,0.2)`
  when downed**. It must therefore be authored **white / near-white** — any
  colour baked in multiplies with the red and goes muddy.
- Health fill is also revealed by a **left-to-right wipe** (`uie_wipe_normal`),
  cut at an arbitrary x every frame. So it must have **no horizontal detail** —
  no segments, no ticks, no highlights that a cut could bisect. Vertical
  gradient only.
- The health **frame** is never tinted (`setRGB(1,1,1)`), so it may carry
  colour — but it sits over a fill that turns red, so keep it neutral steel /
  white with at most a cool edge, or the down state stops reading.
- The plate and the points icon are never tinted. Free colour.
- Points **text** is `#FBF879` gold and sits immediately right of the icon.

<!-- PACK:BEGIN -->
# PLAYER HUD PANEL — legibility re-bake (4 images)

## What this is

The bottom-left player panel of a Black Ops 3 zombies HUD: a portrait disc, a
player name, an HP readout, a segmented health bar, and a points counter, all
sitting on a soft electric-blue backing plate.

**Open `reference/current_panel_onscreen.png` first.** The top row is the whole
panel at its true size on a 1920×1080 screen — 516 × 173 pixels, life size.
Everything under it is the same pixels magnified. That top row is the brief:
the health bar is a grey smear and the points glyph is unreadable.

**This is not a resolution problem, and please do not solve it with more
resolution.** Every one of these files is already 2–10× larger than the box it
is drawn into. The problems are (a) too many tiny features per element, and
(b) shaded, beveled, gradient-heavy rendering that cannot survive a large
downscale. The fix is **fewer, fatter, higher-contrast shapes** — art authored
*for* a small readout.

Deliver at the sizes in the table below and no larger. A 4K version of any of
these would be thrown away by the game.

## Deliver exactly FOUR files

| Deliver as | Size | Drawn on screen at | What it is |
|---|---|---|---|
| `i_tod_hud_points_icon.png` | **256 × 256** | 24 × 24 px | the points/essence glyph |
| `i_tod_hud_health_frame.png` | **1032 × 96** | 194 × 18 px | the health bar's segmented frame |
| `i_tod_hud_health_fill.png` | **1016 × 80** | 191 × 15 px | the bar that fills inside it |
| `i_tod_hud_player_plate.png` | **1536 × 512** | 518 × 173 px | the panel backing |

All four: PNG, RGBA, fully transparent background, flat vector-clean game-UI
art. No photographic texture, no film grain, no noise, no drop-shadow blur so
soft it disappears at 1/5 scale.

## References (in `reference/`)

- `current_panel_onscreen.png` — the panel at true 1080p size, then magnified.
  **The single most important file here.** Attach it to every prompt.
- `current_points_icon.png` — the current glyph. Its *shape* (a stylised "Z"
  crossed by two vertical bars) and its gold are kept; its beveled 3D
  rendering is what goes.
- `current_health_frame.png` — the current frame. It has about 48 segments; on
  screen each one is under 4 pixels wide including its gap. This is the file
  being replaced with far fewer, far chunkier segments.
- `current_health_fill.png` — the plain strip that fills inside the frame.
- `current_player_plate.png` — the current backing: a soft electric-blue
  lightning wisp with a faint square portrait frame at the left and a long
  fading tail to the right. **Its visual family is kept** (see Prompt D).
- `class_medallion_heavy.png` — **not a deliverable.** This is the circular
  class badge that sits in the plate's portrait bay at runtime; it is shown so
  the bay can be sized and lit for it, and so the ring weight and palette
  match. One of four; the ring colour changes per class (red, gold, cyan,
  green), so the bay must not assume any one colour.
- `preview_onscreen_*/` — each reference downscaled to its real on-screen size.
  `24x24` is the points icon; `190x11` the health frame; `192x10` the fill;
  `516x172` the plate; `77x77` the portrait disc. **Judge every deliverable by
  downscaling it to the same size and looking at that**, not at the full-size
  canvas.

## Hard rules (all four files)

- Exact canvas sizes from the table. RGBA, transparent background.
- Everything must survive a **5×–6× downscale**. Practical floor: no feature
  narrower than **6 px** on its delivered canvas, and no more than a handful of
  distinct features per element.
- High contrast against a **dark** background — this HUD sits over night city
  and dark stairwells. Light shapes with dark separation, not mid-tones.
- Keep the existing colour language: **electric cyan-blue** for the plate and
  frame furniture, **gold `#FBF879`** for points.
- No text, no lettering, no numbers baked into any file. The name, HP and score
  are live text drawn by the game on top.

## Prompt A — `i_tod_hud_points_icon.png` (256 × 256)

Attach `reference/current_points_icon.png` and `reference/current_panel_onscreen.png`.

```text
Attached is a game HUD currency icon (a gold "Z" glyph crossed by two vertical
bars) and a screenshot of the HUD it lives in. Redraw the icon so it stays
readable when it is shrunk to 24 x 24 pixels on screen.

Canvas exactly 256 x 256 pixels, PNG, RGBA, fully transparent background.

KEEP the symbol: the same stylised capital Z with two vertical bars crossing
it, the same gold colour family, the same overall proportions, filling roughly
the same share of the square.

CHANGE the rendering, completely:
- Flat vector-style icon art. No 3D bevel, no extruded side faces, no cast
  shadow, no glossy highlight, no photographic shading.
- Thick, confident strokes. Every stroke of the Z and both vertical bars at
  least 26 pixels wide on this 256 canvas. Where they cross, keep a clean
  visible gap of at least 8 pixels so the shapes stay separate when small.
- Two flat tones at most for the gold: a bright face and one darker tone used
  only as a hard-edged bottom-right offset, no gradient ramp.
- A crisp dark outline about 6 pixels wide around the whole silhouette, in a
  very dark warm brown-black, so the glyph separates from any background.
- Simplify anything that will not read: if a detail is under 10 pixels on this
  canvas, delete it rather than shrink it.

Test before delivering: shrink your result to 24 x 24 pixels and look at it. It
must still read unmistakably as the Z-with-two-bars symbol, with the bars still
visible as separate strokes. If it turns into a gold blob, make the strokes
fewer and thicker and try again.

Deliver as i_tod_hud_points_icon.png.
```

## Prompt B — `i_tod_hud_health_frame.png` (1032 × 96)

Attach `reference/current_health_frame.png` and `reference/current_panel_onscreen.png`.

```text
Attached is a game HUD health-bar frame and a screenshot of the HUD it lives
in. It is a long horizontal bar divided into about 48 thin segments. On screen
it is only 194 x 18 pixels, so those segments are under 4 pixels each and they
blur into a grey smear. Redraw it with far fewer, far chunkier segments.

Canvas exactly 1032 x 96 pixels, PNG, RGBA, fully transparent background. Flat
vector-clean game-UI art, crisp edges, no texture, no noise.

The design:
- A horizontal bar frame spanning the full canvas width: a clean outer border
  about 8 pixels thick in bright steel-white, with a thin cool cyan-blue edge
  light on the outside of it.
- Inside the border, exactly 14 EQUAL SEGMENT DIVIDERS creating 15 cells across
  the bar. Each divider is a solid vertical bar about 12 pixels wide, in the
  same steel-white as the border, running the full inner height.
- The cells between dividers are fully transparent - a separate coloured fill
  image is drawn UNDERNEATH this frame and must show through them.
- Slightly heavier weight at the two ends: the leftmost and rightmost few
  pixels can read as end caps, so the bar has a start and a finish.
- The whole thing is neutral steel-white with a cool cyan edge only. Do not
  make it green, red, orange or gold: the bar underneath changes colour at
  runtime and this frame must sit over both a white and a red fill.

Everything is drawn hard-edged. No soft glow, no gradient across the length, no
inner shadow, no bevel.

Test before delivering: shrink your result to 194 x 18 pixels and look at it.
All 14 dividers must still be individually countable and the border must still
read as a clean rectangle. If the dividers merge, use fewer of them.

Deliver as i_tod_hud_health_frame.png.
```

## Prompt C — `i_tod_hud_health_fill.png` (1016 × 80)

Attach `reference/current_health_fill.png` and the FINISHED
`i_tod_hud_health_frame.png` from Prompt B.

```text
Attached is a plain health-bar fill strip and the finished frame it sits inside
(from the previous step). Produce the replacement fill strip.

Canvas exactly 1016 x 80 pixels, PNG, RGBA. The strip fills the ENTIRE canvas
edge to edge - no transparent margin, no rounded corners, no border of its own.
The frame drawn on top provides all the edges.

CRITICAL - the image must be completely UNIFORM along its width. The game
reveals this strip left to right as health drains, cutting it at any horizontal
position, and it also multiplies the whole strip by a colour that changes at
runtime. So:
- NO segments, ticks, notches, chevrons, arrows or repeating pattern.
- NO highlight, gloss spot, vignette or lighting that varies left to right.
- NO colour change along the width.
- Every vertical column of pixels must be identical to every other column.

What it may have, and should:
- A vertical gradient only, top to bottom: bright near-white at the top, easing
  to a slightly cooler light grey at the bottom, with a single crisp brighter
  band across the upper third to read as a sheen.
- Keep it WHITE / very light neutral grey overall. The game tints this image -
  white when healthy, red when the player is downed - so any baked-in colour
  will multiply into a muddy result. Highest saturation anywhere: nearly zero.
- Fully opaque, alpha 255 across the whole canvas.

Deliver as i_tod_hud_health_fill.png.
```

## Prompt D — `i_tod_hud_player_plate.png` (1536 × 512)

Attach `reference/current_player_plate.png`,
`reference/class_medallion_heavy.png` and
`reference/current_panel_onscreen.png`.

```text
Attached: the backing plate of a bottom-left player HUD panel (a soft electric-
blue lightning wisp), the circular class badge that sits inside its portrait
bay at runtime, and a screenshot of the assembled panel.

Refine this plate. This is NOT a redesign - other panels on the same HUD still
use the original artwork and must still look like the same family. Keep the
electric-blue lightning-wisp identity, the dark translucent body, and the long
fading tail that trails off to the right.

Canvas exactly 1536 x 512 pixels, PNG, RGBA, fully transparent background.
Flat, clean, high-contrast game-UI art in a neon-cyber style. It is displayed
at 518 x 173 pixels, a 3x reduction, so nothing may depend on fine detail.

Fix these four things:

1. THE PORTRAIT BAY. The current square frame at the left is too small and too
   faint for the badge that goes in it, which overhangs it on both sides. Draw
   a clean SQUARE bay whose interior is exactly 227 x 227 pixels with its
   top-left corner at (89, 151) on this canvas. Give it a definite edge: a
   bright cyan keyline about 7 pixels thick with a darker inset behind it, so a
   circular badge dropped inside sits in a frame instead of floating. Leave the
   interior of that square dark and nearly empty - the badge covers it. The
   badge's ring colour changes per class (red, gold, cyan or green), so the bay
   must be colour-neutral cyan-blue and must not fight any of them.

2. READABILITY BEHIND THE READOUTS. Live white and gold text and a health bar
   are drawn on top, in this region: x 325 to 950, y 150 to 370. Right now the
   bright lightning core runs straight through it. Keep that whole region calm
   and DARK - a soft dark translucent slab or a gentle darkening of the wisp -
   so white text and a white bar read cleanly on it. No bright filaments, no
   high-contrast detail, nothing busy inside that box.

3. STRUCTURE. Give the plate a sense of being a designed panel rather than a
   smear: a thin bright cyan rule running along the bottom edge under the
   readout region, and a subtle angled cut at the plate's lower-right where the
   body hands off into the tail. Both hard-edged and simple.

4. THE TAIL. Keep the lightning tail streaming right and fading to nothing, but
   thin it and calm it - it currently competes with the panel. It should read
   as one or two confident arcs, not a spray of filaments. It must fade fully
   to transparent before the right edge of the canvas.

Palette: dark navy-black body, electric cyan and mid-blue for the light, white
only at the very hottest points. No purple, no green, no gold anywhere on the
plate.

Test before delivering: shrink your result to 518 x 173 pixels. The portrait
bay must still read as a crisp square, and the region where the text goes must
be visibly darker and calmer than the rest.

Deliver as i_tod_hud_player_plate.png.
```

## Delivery checklist

- [ ] Four files, named exactly `i_tod_hud_points_icon.png`,
      `i_tod_hud_health_frame.png`, `i_tod_hud_health_fill.png`,
      `i_tod_hud_player_plate.png`
- [ ] Exact canvases: 256×256, 1032×96, 1016×80, 1536×512 — RGBA, transparent
      background (except the fill, which is fully opaque edge to edge)
- [ ] Each one downscaled to its on-screen size (24×24, 194×18, 191×15,
      518×173) and **looked at** — that is the only test that matters
- [ ] The health frame's 14 dividers are still individually countable at 194×18
- [ ] The fill has zero horizontal variation — every column identical — and is
      white/neutral, not coloured
- [ ] The plate's portrait bay interior is 227×227 at (89, 151), and the
      readout region x 325–950, y 150–370 is dark and calm

## Do NOT

- Do not deliver 4K, 2K or "upscaled" versions of anything. The sizes in the
  table are already several times what the game displays; larger files are
  discarded and the extra detail is lost either way.
- Do not bake any text, numbers, name or HP value into any file.
- Do not put segments, ticks or any left-right pattern in the health FILL —
  it is cut at arbitrary positions and tinted at runtime.
- Do not colour the health fill or the health frame green/red/gold.
- Do not redesign the plate into a different shape language — the teammate
  panels still use the original and must still match.
- Do not add a compass, minimap, ammo counter, perk icons or any element that
  is not in the reference.
<!-- PACK:END -->

## Install — DONE 2026-09-03 (v16.98). The recipe below is what was run.

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` — headers, md5, nested
   zips expanded. Then **LOOK at all four**, and downscale each to its
   on-screen size (24×24 / 194×18 / 191×15 / 518×173) before believing any of
   them. Check the fill really is column-uniform (a per-column diff, not an
   eyeball) and really is unsaturated, or the downed state goes muddy.
2. Copy into `source_data/tod_ui_images/_images/`. These are **NEW names**, so
   all three wiring lanes are needed:
   - a GDT block per image in `source_data/tod_ui_images.gdt` — copy an existing
     `i_tod_*` block verbatim (`compressionMethod "uncompressed"`, `colorSRGB 1`,
     `coreSemantic sRGB3chAlpha`, `noPicMip 1`); that is the whole point of
     bringing them in-house.
   - an `image,` line each in `zone_source/zm_tower_of_doom.zone` — without it
     the linker is silent and the game draws a WHITE SQUARE
     (`tools/lint_tod_assets.js` GATE A catches this).
   - the `RegisterImage` names in `AetheriumPlayerInfo.lua`.
3. **Move the four boxes** in `AetheriumPlayerInfo.lua` to the geometry table
   above at the same time — the new art is authored for those aspects, and
   installing it against the old boxes re-introduces the stretch (the health
   frame in particular goes from −17% to −38%, worse than today):
   - plate `16..361 × 595..710`
   - health frame `93..222 × 648..660`
   - health fill `94..221 × 649..659`
   - points icon `89..105 × 661..677` (already done, v16.97)
4. **FULL build** (a GDT edit is always a full build). Proof = a fresh
   content-hash `.iwi` for each of the four beside an untouched control, per
   the verify-assets-in-artifacts rule.
5. Then judge it in game and decide the two follow-ons parked above: the
   party-member plate, and the +15% `TodScaleHud` on this widget plus the party
   stack.

## Open follow-ons (2026-09-03, after the install)

Ranked by how visible they are, most first.

1. **The party-member plate.** The delivered plate is a framed tech panel, not
   the refinement this doc asked for. It is a large improvement and solo play
   is unaffected, but in co-op the three teammate rows above it still use the
   kit's `i_mtl_ui_hud_party_member_theme_aetherium` wisp. Same palette and the
   same medallion discs, so it does not clash — but the local panel now reads
   "designed" and the rows read "leftover". One more pack: 1024×320 source,
   drawn 276×87 (aspect 3.17), matching the new panel's keyline, corner ticks
   and dark readout slab, with a square 35×35 portrait bay.
2. **The prompt cards stretch the points glyph +25%.** Six `Prompt*.lua` cards
   draw the (square) icon into a 15 wide × 12 tall box — a worse aspect error
   than the 13.6% portrait ellipse this whole pass started from. Only the image
   was swapped there, not the box, because that card layout is tuned (docs/88)
   and the change was outside what was asked. Squaring it needs a look at what
   sits above and below y 503..515 on each card.
3. **`lint_tod_assets.js` cannot see `.zpkg` files.** It reads only
   `zone_source/zm_tower_of_doom.zone` and models only `i_tod_*` names, so GATE
   A did NOT cover this pass's retirement of three `i_mtl_*` images — that was
   verified by hand instead. Every Aetherium kit image is in the same blind
   spot. Parsing the `.zpkg` list and modelling `i_mtl_*` literals would close
   it; the selftest would need two new shapes.
4. **The +15% `TodScaleHud`**, still skipped for this widget and the party
   stack. Unchanged from the v16.97 note above: it needs both scaled together,
   or the local panel's overlap with party row 1 goes 16 px → 33 px.
