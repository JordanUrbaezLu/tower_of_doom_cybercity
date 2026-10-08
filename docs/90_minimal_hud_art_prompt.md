# 90 — MINIMAL PLAYER HUD: the bar track, frame and shield glyph (3 images)

<!-- art-pack
name: minimal_hud
refs:
  docs/90_hud_ref/minimal_now_onscreen.png | THE BRIEF IN ONE PICTURE: the shipped minimal HUD at true 1080p size over a dark AND a bright background, plus a magnification. The bright half is the problem being solved. Attach to every prompt.
  docs/90_hud_ref/current_health_frame.png | the CURRENT bar frame, SHIPPED and working. Prompt A keeps its geometry exactly and only adds a dark outer edge. Attach to Prompt A.
  docs/90_hud_ref/current_health_fill.png | the CURRENT fill strip. NOT a deliverable — shown because the new track sits behind it and must be its exact size and rhythm. Attach to Prompt B.
  docs/90_hud_ref/current_points_icon.png | the SHIPPED points glyph. Its drawing style — flat, thick strokes, hard dark outline, two flat tones — is the house style the shield glyph must match. Attach to Prompt C.
preview: 194x18 191x15 24x24
-->

> **STATUS: PACK BUILT 2026-09-03 (v17.0), awaiting the drop.** The minimal
> layout itself is SHIPPED and playable without any of this art — a near-black
> tint on the existing fill strip is standing in for the track. These three
> files are the polish that makes it hold up on bright backgrounds.

**Why (user, 2026-09-03, after playing v16.98):** *"Okay I like what we have
actually. But i do want to make it minimal and remove that whole shell part —
just the icon, no square, name, money, health, and maybe something for shield
health."*

## What shipped in v17.0 (no art needed)

The shell is gone. `i_tod_hud_player_plate` is retired from the `.zone` (file
and GDT block kept — re-zoning one line brings it back). What is left is six
free-floating readouts in a **226 × 60** canvas box at x 24..250, y 618..678 —
about a third the area the panel used. The square around the class disc went
with the plate, because the square *was* the plate.

| element | box (canvas) | @1080p |
|---|---|---|
| class medallion | 56×56 (x 24..80, y 620..676) | 84×84 |
| player name | x 90..200, y 618..630 | — |
| HP text | x 168..220, y 619..631 | — |
| shield track / fill | 130×6 / 128×4 (y 636..642) | 195×9 |
| health track / fill / frame | 130×12 (x 90..220, y 645..657) | 195×18 |
| points icon | 16×16 (x 90..106, y 662..678) | 24×24 |
| points amount | x 110..200, y 664..677 | — |

**The shield bar has a permanent reserved slot** whether or not a shield is
held. That replaced a handler that slid the name, HP text and downed icon
between two hardcoded coordinate sets — six pairs, in a second place, that had
to track the constructor by hand and did not: its "original" HP position was
640..647 against a constructor that has said 631..639 since the kit was
vendored, so dropping a shield left the HP text somewhere it had never spawned.
A layout written twice is a layout that drifts.

## The problem this art solves

**Removing the shell removed the contrast.** The plate's dark slab is what made
white text and a white bar readable. Floating, two things break:

1. **An empty bar cell showed the world through it**, so a half-empty bar had
   no visible length. Fixed already, in code, by drawing the existing fill strip
   a second time at a near-black tint (`setRGB 0.05, 0.07, 0.11`) underneath the
   real fill. That works *only* because of what that image already had to be —
   opaque edge to edge and identical in every column, for the wipe. It is a real
   fix, not a placeholder, and it is why this is a polish request and not a
   blocker.
2. **The frame's steel-white border still vanishes against anything pale.** A
   tint cannot fix that: it needs a dark edge and a soft outer shadow baked into
   the art. That is Prompt A, and it is the one that matters.

Third, smaller: the shield bar is currently an unlabelled blue line. A small
shield glyph in the right gutter (x 226..246, y 620..640) says what it is.

<!-- PACK:BEGIN -->
# MINIMAL GAME HUD — bar track, bar frame, shield glyph (3 images)

## What this is

The bottom-left player readout of a Black Ops 3 zombies HUD, in a **minimal**
style: no panel, no box, no background plate. Just a circular class badge, a
name, an HP number, a segmented health bar, a thin shield bar above it, and a
gold currency figure — floating directly on the game world.

**Open `minimal_now_onscreen.png` first.** It shows the HUD as it ships today,
at its true size on a 1920×1080 screen, over a dark background and a bright one.
The dark half looks right. **The bright half is the entire brief:** with no
panel behind it, the bar's white border washes out and the whole readout loses
its edges.

Everything below is about making these elements survive on ANY background
without giving them a panel back.

## Deliver exactly THREE files

| Deliver as | Size | Drawn on screen at | What it is |
|---|---|---|---|
| `i_tod_hud_health_frame.png` | **1032 × 96** | 195 × 18 px | the bar's segmented frame — REPLACES the attached one |
| `i_tod_hud_bar_track.png` | **1016 × 80** | 191 × 15 px | the dark trough the bar drains against, drawn behind the fill |
| `i_tod_hud_shield_icon.png` | **256 × 256** | 20 × 20 px | a small shield glyph labelling the shield bar |

All three: PNG, RGBA, flat vector-clean game-UI art. No photographic texture,
no noise, no 3D bevel. They are shown at roughly **1/5 scale**, so nothing may
depend on fine detail — no feature narrower than about 6 px on the delivered
canvas.

## References (in `reference/`)

- `minimal_now_onscreen.png` — the shipped HUD at true size on dark and on
  bright, plus a magnification. **The most important file here.**
- `current_health_frame.png` — the CURRENT frame. It is good and it ships; its
  15-cell geometry is correct and must be preserved exactly. Only its edge
  treatment changes.
- `current_health_fill.png` — the CURRENT fill strip that slides across inside
  the frame. Not a deliverable. The new track must be its exact size and line
  up with it perfectly.
- `current_points_icon.png` — the SHIPPED gold currency glyph. **Its drawing
  style is the house style**: flat, thick strokes, two flat tones, a hard dark
  outline round the whole silhouette, no gradients. The shield glyph must look
  like it came from the same set.
- `preview_onscreen_*/` — each reference at its real on-screen size. Judge every
  deliverable by shrinking it to the same size and looking at that.

## Prompt A — `i_tod_hud_health_frame.png` (1032 × 96)

Attach `reference/current_health_frame.png` and `reference/minimal_now_onscreen.png`.

```text
Attached is a game HUD health-bar frame that currently ships, and a screenshot
of the minimal HUD it lives in shown over both a dark and a bright background.

The frame's geometry is correct and must be preserved EXACTLY. The problem is
only that it is drawn in pale steel-white with no dark edge, so on the bright
background in the screenshot it washes out and disappears.

Canvas exactly 1032 x 96 pixels, PNG, RGBA. Flat vector-clean game-UI art,
crisp edges, no texture, no noise, no bevel.

KEEP, pixel for pixel where you can:
- the outer rectangular border, same thickness and same position
- exactly 14 vertical dividers making 15 equal cells across the bar
- the cells themselves FULLY TRANSPARENT - a separate coloured bar is drawn
  underneath and must show through them completely and cleanly
- the slightly heavier end caps at the far left and far right
- the bright steel-white colour of the border and dividers, with its cool cyan
  edge light

ADD, and this is the whole job:
- a hard near-black outline, about 5 pixels thick, tracing the OUTSIDE of the
  outer border all the way around. Solid, hard-edged, not a blur.
- outside that, a soft dark drop shadow about 10 pixels deep, fading to fully
  transparent, so the bar separates from a light background.
- the same near-black outline, about 3 pixels, down BOTH long edges of every
  one of the 14 dividers, so the dividers read as distinct bars and not as
  gaps when the background behind the cells is pale.
- the outline and shadow must sit entirely within the 1032 x 96 canvas: do not
  make the bar itself smaller to fit them. Shrink the transparent margin, not
  the bar.

The cells must stay COMPLETELY transparent in their middles. Do not tint them,
do not add a dark wash inside them, do not fill them - a different image
provides that.

Test before delivering: shrink your result to 195 x 18 pixels and place it on a
white background, then on a black one. All 14 dividers must be individually
countable on BOTH, and the outer rectangle must read as a crisp closed shape on
both. If it disappears on white, thicken the outline.

Deliver as i_tod_hud_health_frame.png.
```

## Prompt B — `i_tod_hud_bar_track.png` (1016 × 80)

Attach `reference/current_health_fill.png` and the FINISHED
`i_tod_hud_health_frame.png` from Prompt A.

```text
Attached is a plain white health-bar fill strip and the finished frame that sits
on top of it. Produce the TRACK: the dark trough that sits BEHIND the fill, so
that the emptied part of the bar is visibly dark instead of showing the game
world through it.

Canvas exactly 1016 x 80 pixels, PNG, RGBA. The track fills the ENTIRE canvas
edge to edge, fully opaque, alpha 255 everywhere. No transparent margin, no
rounded corners, no border of its own - the frame on top provides all edges.

What it looks like:
- a very dark near-black trough with a slight cool blue cast, around RGB
  12 to 18 out of 255 - dark enough that white and red read strongly on top of
  it, not pure black
- a subtle vertical gradient only: very slightly lighter at the top, darker at
  the bottom, as if lit from above
- a single faint darker line along the very top edge, about 4 pixels, reading
  as an inner shadow under the frame's top border

CRITICAL - it must be completely UNIFORM along its width. Every vertical column
of pixels identical to every other column:
- NO segments, ticks, notches or repeating pattern of any kind
- NO highlight, gloss spot or vignette that varies left to right
- NO colour change along the width
The frame drawn on top supplies all 15 cell divisions; if this image also had
them they would not line up and would read as a double image.

Deliver as i_tod_hud_bar_track.png.
```

## Prompt C — `i_tod_hud_shield_icon.png` (256 × 256)

Attach `reference/current_points_icon.png` and `reference/minimal_now_onscreen.png`.

```text
Attached is a gold currency glyph from a game HUD, and a screenshot of the HUD
it belongs to. Draw a SHIELD icon in exactly the same style, to sit next to a
thin blue shield-health bar in that HUD.

Canvas exactly 256 x 256 pixels, PNG, RGBA, fully transparent background.

The symbol: a simple heater shield - flat top edge, straight sides, tapering to
a rounded point at the bottom. Nothing on its face except one single wide
vertical band down the centre in the darker tone. No crest, no emblem, no
cross, no lion, no rivets, no text.

The style, copied from the attached gold glyph:
- completely flat vector art. No 3D bevel, no extrusion, no cast shadow, no
  gloss highlight, no gradient ramp of any kind.
- exactly two flat tones for the body: a bright face and one darker tone, the
  darker used only as a hard-edged offset toward the bottom-right.
- a crisp dark outline about 6 pixels wide around the entire silhouette, in a
  very dark cool blue-black.
- thick and chunky: the shield should fill roughly 75 percent of the square,
  and no part of its outline or inner band should be narrower than 20 pixels.

The colours are BLUE, not gold: a bright cyan-blue face around #5AC8FF with a
deeper blue #1E6FA8 as the darker tone. It must read as the same family as the
attached gold glyph - same weight, same outline, same flatness - just blue.

Test before delivering: shrink your result to 20 x 20 pixels. It must still
read unmistakably as a shield. If it turns into a blue blob, simplify it
further and thicken the outline.

Deliver as i_tod_hud_shield_icon.png.
```

## Delivery checklist

- [ ] Three files, named exactly `i_tod_hud_health_frame.png`,
      `i_tod_hud_bar_track.png`, `i_tod_hud_shield_icon.png`
- [ ] Exact canvases: 1032×96, 1016×80, 256×256 — all RGBA
- [ ] The frame's 14 dividers are unchanged in position and still countable at
      195×18 **on a white background as well as a black one**
- [ ] The frame's cells are still fully transparent in their middles
- [ ] The track is fully opaque, every column identical, no segments
- [ ] The shield glyph still reads as a shield at 20×20

## Do NOT

- Do not change the frame's cell count, cell positions or overall geometry —
  only its edge treatment.
- Do not fill or tint the frame's cell interiors.
- Do not put segments, ticks or any left-right pattern in the track.
- Do not give the track its own border or rounded corners.
- Do not add a background panel, plate or box behind anything. The whole point
  of this HUD is that there isn't one.
- Do not deliver larger "4K" versions. The sizes above are already several
  times what the game displays.
<!-- PACK:END -->

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'`, then LOOK at all three
   and shrink each to its on-screen size. **Composite the frame over the track
   over a half-width fill and check it on white AND black** — that pairing is
   the deliverable, not the three files separately.
2. `i_tod_hud_health_frame.png` replaces the shipped file under the same name:
   no GDT, zone or Lua edit. The other two are NEW names and need all three
   lanes (GDT block cloned from an existing `i_tod_*` entry so they are
   `uncompressed`; an `image,` line; the `RegisterImage` name).
3. In `AetheriumPlayerInfo.lua`: point `health_track` and `shield_track` at
   `i_tod_hud_bar_track` and **drop their `setRGB` tint** — the new art is
   already dark, so leaving the 0.05 tint on would crush it to black. Point
   `shield_icon` at `i_tod_hud_shield_icon` (box x 226..246, y 620..640).
4. FULL build (GDT edits always are). Proof = fresh content-hash `.iwi` for the
   new names beside an untouched control.
