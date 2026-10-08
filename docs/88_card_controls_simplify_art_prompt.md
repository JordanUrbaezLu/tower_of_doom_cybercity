# 88 — CONTROL PROMPTS: real button glyphs, per device (10 images)

<!-- art-pack
name: card_controls
refs:
  i_tod_hint_switch_pad.png | the old baked CONTROLLER plate. It already carries a d-pad glyph AND a green A button - the closest thing to the target for the four pad glyphs. Attach to Prompts A and C.
  i_tod_hint_lock_kbm.png | the old baked KEYBOARD plate. It already carries SPACE and F key chips - the closest thing to the target for the two blank keycaps. Attach to Prompts D and F.
  i_tod_hint_locked.png | the LOCKED IN plate: the ENERGISED look (bright cyan rim, lit interior) that a FILLED bar should arrive at. Attach to Prompts G and I.
  i_tod_hint_frame.png | the blank plate chassis: pill shape, dark navy fill, thin cyan rim, soft outer glow. The shared material for the plate and the timer track. Attach to Prompts F and H.
preview: 280x43
-->

> **STATUS: SHIPPED — art installed v16.88, recentred v16.89, pause legend
> v16.93, draft timer bar v16.95 (2026-09-03).** Nine images were delivered in
> `files - 2026-09-03T133821.928.zip`; SEVEN shipped. `i_tod_key_blank` (square
> keycap) and `i_tod_hold_fill` are installed and GDT'd but deliberately NOT
> zoned — the reasons are recorded at the registration site in `tod_upgrade.lua`
> and in the v16.88 CHANGELOG entry. The tenth requested image,
> `i_tod_pad_button_x`, was added to this brief AFTER the drop went out and has
> never been delivered; it is only needed for the world buy-prompts (doors,
> perks, crate, PaP, teleporter, extraction), which still print a key NAME.
>
> **VERIFIED AT INSTALL:** the drop's loose and nested copies were
> pixel-identical (0 differing px across all three duplicated files), both
> keycaps genuinely empty, and both fills uniform left-to-right so a part-filled
> bar cannot smear. Proof of packing = a fresh content-hash `.iwi` for all seven
> names beside an untouched control.
>
> ⚠️ **STILL OPEN, and neither is art:** (1) THE DEVICE READ — **half-settled
> v17.55:** the `[{+smoke}]` / `[{+frag}]` expansion IS a device read in the
> pad direction (`CoD.TodKeycap.PadDevice()`, one reader for all three surfaces),
> so a pad player gets pad glyphs from the first frame and the keycaps can never
> carry "LT"/"RT". Still open: a keyboard player who taps 3 or 4 latches
> `CoD.TodPad` and sees pad glyphs; the `GetControllerType()` probe shipped in
> v16.93 and still needs one run to settle that direction. (2) `+activate` is bound to NO controller button
> in either of the user's profiles, so the world buy-prompts may render a BLANK
> key on a pad — untested, and a ten-second check at any door.
>
> Pack built by
> `.\tools\make_art_pack.ps1 docs\88_card_controls_simplify_art_prompt.md` →
> `~/Downloads/tod_card_controls_art_pack.zip`.
>
> **REVISION 3.** Test result from the user, in game, on a pad: *"Yeah we have
> lt < Switch > rt … Again this needs to show a dpad. Use the <dpad icon> to
> switch. We have hold A which is good. But the KBM UI is pretty bad."*

## The finding that changes the design

**The engine draws bind tokens as TEXT NAMES, not pictures.** A controller
player reads the letters `LT` and `RT`; they do not see trigger art. The repo had
recorded for days that the engine "resolves the token into the device's bound key
**or pad glyph**", on the strength of one transcription of an `X` — a letter that
reads identically either way. Nobody had ever seen a picture. **So there is no
engine glyph to inherit, and baking our own is the only way to get one.**

## How this is typically done (the research)

Industry practice for control prompts, which our situation maps onto exactly:

1. **Ship a glyph atlas per device family** — Xbox, PlayStation, keyboard+mouse.
   Prompts are images, not text.
2. **Switch on LAST INPUT USED, never on what is plugged in.** That is why
   plugging a pad into a PC game does not change prompts until you press
   something on it. It is also exactly the bug v16.3 fixed here from the other
   side: `Engine.IsGamepadEnabled` answered true for a keyboard player with a pad
   merely connected.
3. **Offer a manual override in settings** (Auto / Xbox / PlayStation /
   Keyboard). Common, and the honest fallback wherever detection is unreliable.
4. **Pad prompts are ALWAYS pictures.** The button set is small and fixed, so
   every one gets art. Printing `LT` as text is the thing no shipped game does.
5. **Keyboard prompts are a keycap FRAME plus the bind name as TEXT.** Binds are
   arbitrary, so per-key art does not scale; only a few special cases (space bar,
   shift, mouse buttons) get dedicated shapes. **So the frame-plus-token approach
   for KBM is the standard one** — it looks bad here only because the "frame" is
   a flat navy pill and the text is unstyled. The fix is to make it an actual
   keycap, plus a wide variant so `SPACE` and `MOUSE3` are not cramped.

**Conclusion: pad gets baked pictures, keyboard gets baked keycaps with live text
inside.** That is both what the user asked for and what the industry does.

## The device-detection problem, and a real lead

Showing pad art to a pad player needs a device read. The standing memory says
there is none. **That memory is wrong on one point, and the correction matters:**
`GetControllerType()` is in the mod tools API docs — `CLIENT/SERVER: Server`,
per-player, *"returns the controller type of the player"*. The memory's claim
came from "no gamepad builtin appears anywhere in `share/raw`", which is a
statement about stock USAGE, not about the API existing; and our own doctrine
says the API doc is the authority.

**Do not treat this as solved.** Verified: it is the only device-type API in the
docs, and **stock never calls it anywhere in `share/raw`**, so it is completely
unexercised and its return values are unknown. It may report the pad MODEL rather
than keyboard-vs-pad, and may return nothing useful with no pad attached. It is a
**one-line probe** under `tod_dev`: call it per player, print the value, read it
with and without a pad connected. That probe can ride the same build that
installs this art.

**The art does not depend on the answer.** These glyphs are needed under every
detection scheme, a manual toggle included. So the request ships now and
detection is settled separately.

## The world prompts need the same fix — and may already be broken on a pad

The card panel is not the most-seen control prompt in the map. **Every door,
perk machine, Pack-a-Punch, ammo crate, teleporter, power switch and the
extraction buy** goes through the eight cursor-hint cards, whose footer is
`local HOLD_KEY = "Hold ^3[{+activate}]^7 "`. On a controller that renders as
TEXT for the same reason `LT` did — so the whole map currently says "Hold X To
Open" in letters where it should show a button.

**And `+activate` may not resolve on a pad at all.** Read out of the user's own
`players/bindings_0.cfg` and `bindings_1.cfg`: `+activate` is bound to the
keyboard's `F` and **to no controller button in either profile**. Pad "use" is
`+usereload` on `BUTTON_X`. What `[{+activate}]` renders as when the token has
no pad binding is UNKNOWN — CoD may alias activate to use and print `X`, or it
may print nothing, leaving "Hold  To Open" with a hole in it. If it is the
latter, v16.29 introduced it (that build replaced a hardcoded `"F"` with this
token) and it has been live for every controller player since.

**Ten-second test: walk up to a door with the pad active and look at the
footer.** Either it says X, or the key is missing. That decides whether this is
a cosmetic upgrade or a live bug fix.

Either way the art is the same, which is why `i_tod_pad_button_x.png` joins this
request: with it, every buy prompt in the map can show a real button instead of
a letter, and if the token turns out to render blank the glyph is also the fix.

## What is on screen after this

| Element | Today | After |
|---|---|---|
| switch hint | one text line, `LT < SWITCH > RT` | a glyph beside each card: d-pad left/right on a pad, a keycap on a keyboard |
| lock hint | art frame + LUI text | baked plate reading `HOLD` … glyph … `TO LOCK` |
| hold bar | **raw colour quads, no art** | baked groove + baked fill, inside that plate |
| countdown | **pure LUI text, no art** | a baked draining bar, no digits |

**The chevrons from revision 2 are dropped.** The d-pad glyph carries its own
direction arrow, so a chevron beside it would be a second arrow saying the same
thing; on keyboard, position at the card's edge carries it. Fewer elements is the
brief.

### Placement at install (1280×720 virtual canvas)

| Element | Rect | Notes |
|---|---|---|
| left glyph | x 317–369, y 376–428 | just outside card A (starts x 369); 52 sq for a pad glyph or square keycap, 72×36 for the wide keycap |
| right glyph | x 911–963, y 376–428 | just outside card B (ends x 911) |
| hold plate | 222×34 under the focused card | replaces plate + separate bar |
| glyph in plate | ~72×36 gap, centred | A button on a pad, keycap on a keyboard |
| timer bar | x 500–780, y 660–675 | replaces the `AUTO IN 15s` text |
| bottom switch plate | **deleted** | |

Class draft (four cards, x 88–298 … 982–1192): same parts at x 36–88 / 1192–1244.

<!-- PACK:BEGIN -->
# CONTROL PROMPTS — 10 images

## What this is

A Black Ops 3 zombies HUD panel. The game pauses and offers the player **two
upgrade cards side by side**. They press one button to highlight the left card,
another for the right, then **hold** a third to lock their choice in. A timer
runs; if it expires the game picks for them.

Right now those controls are plain text and flat coloured rectangles. A
controller player literally reads the letters "LT" and "RT" instead of seeing
buttons. The same is true of every buy prompt in the level - doors, vending
machines, crates - which show a letter where a button should be. **This request replaces the whole thing with real artwork**: proper
controller button glyphs, proper keyboard keycaps, and proper bars.

**Deliver exactly TEN files, in three groups.**

### Group 1 — controller button glyphs (4)

| Deliver as | Canvas | What it is |
|---|---|---|
| `i_tod_pad_dpad_left.png` | **256 × 256** | a gamepad D-PAD with its LEFT direction lit |
| `i_tod_pad_dpad_right.png` | **256 × 256** | the same D-PAD with its RIGHT direction lit |
| `i_tod_pad_button_a.png` | **256 × 256** | the green Xbox-style **A** face button |
| `i_tod_pad_button_x.png` | **256 × 256** | the blue Xbox-style **X** face button |

### Group 2 — keyboard keycaps (2)

| Deliver as | Canvas | What it is |
|---|---|---|
| `i_tod_key_blank.png` | **192 × 192** | an EMPTY square keycap, for short names like `E` or `G` |
| `i_tod_key_blank_wide.png` | **384 × 192** | an EMPTY wide keycap, for long names like `SPACE` or `MOUSE3` |

### Group 3 — the plate and the bars (4)

| Deliver as | Canvas | What it is |
|---|---|---|
| `i_tod_hold_plate.png` | **460 × 70** | a plate reading `HOLD` … gap … `TO LOCK`, with an empty progress groove |
| `i_tod_hold_fill.png` | **460 × 70** | the glowing bar that fills that groove |
| `i_tod_timer_track.png` | **460 × 24** | a slim empty timer track |
| `i_tod_timer_fill.png` | **460 × 24** | the glowing bar that drains along it |

## THE RULE THAT OVERRIDES EVERYTHING

**The only lettering anywhere in these ten files is:**

- the single letter **`A`** on `i_tod_pad_button_a.png` and the single letter
  **`X`** on `i_tod_pad_button_x.png` — each is that button's own name, moulded
  into the controller, and neither ever changes;
- the words **`HOLD`** and **`TO LOCK`** on `i_tod_hold_plate.png`.

**Everything else is textless.** In particular the two keycaps must be
**completely EMPTY** — no `E`, no `G`, no `SPACE`, no letter at all. The game
prints the player's live key name into them at runtime, and any letter baked
there is wrong for anyone who has rebound that key.

## References (in `reference/`)

- `i_tod_hint_switch_pad.png` — the old controller plate. **It already carries a
  small d-pad glyph and a green A button.** Those are the shapes to build from,
  redrawn much larger and cleaner. For Group 1.
- `i_tod_hint_lock_kbm.png` — the old keyboard plate. **It already carries SPACE
  and F key chips.** That is the keycap look, with the letters removed. For
  Group 2.
- `i_tod_hint_frame.png` — the blank plate chassis: pill shape, near-black navy
  fill, thin bright cyan-white rim, soft outer glow, subtle inner vignette.
- `i_tod_hint_locked.png` — the **energised** treatment: bright cyan rim, lit
  interior. That is where a FULL bar should arrive.
- `preview_onscreen_280x43/` — those plates at real on-screen size. That is how
  small this art is, and why every outline must be heavy.

## Shared hard rules

- PNG, **RGBA**, exact canvas sizes above, **fully transparent** background
  everywhere that is not the artwork.
- One family: near-black navy plates, bright cyan-white rim light, pure-white
  lettering and glyphs with thick near-black outlines, soft glow that fades to
  nothing inside the canvas edge.
- Flat, vector-clean game-UI art. Crisp edges. No photographic texture, no noise,
  no grain, no heavy bevel, no chrome.
- Everything is drawn small — the glyphs at roughly **52 × 52** on screen, the
  plate at **222 × 34**, the timer at **280 × 15**. Assume a 2× to 5× downscale:
  no hairlines, nothing finer than about 8 px on a 460-wide canvas.
- Each glyph sits directly over the game world, not on a panel, so it needs its
  own dark outline and drop shadow to read against a dark sky and a bright neon
  wall alike.

## Prompt A — `i_tod_pad_dpad_left.png`

Attach `reference/i_tod_hint_switch_pad.png`.

```text
Create a game controller D-PAD icon for a video game HUD. Canvas exactly 256 by
256 pixels, PNG, RGBA, fully transparent background.

Draw a clean plus-shaped directional pad, seen straight on, filling about the
middle 75 percent of the canvas, optically centred, with clear transparent
margin all round. The attached game plate carries a small version of exactly
this glyph - build a much larger, cleaner version of it.

The pad body is a rounded plus/cross shape in a cool dark grey with a soft
top-to-bottom gradient, a thick near-black outline about 6 pixels wide, and a
soft dark drop shadow below and to the right.

The LEFT arm of the cross is HIGHLIGHTED: fill it bright cyan-white, glowing,
clearly lit compared with the other three arms, and put a small white
directional arrowhead pointing LEFT inside it. The other three arms stay dark
grey and unlit, with no arrows in them.

Flat vector-clean game UI art. Crisp edges. No photographic texture, no noise,
no chrome, no heavy 3D bevel, no thumbstick, no other buttons, no controller
body around it - just the d-pad itself on transparency.

It is shown at about 52 by 52 pixels on screen, so keep every stroke thick and
make the highlight unmistakable at small size.

No text or numbers anywhere.

Deliver as i_tod_pad_dpad_left.png.
```

## Prompt B — `i_tod_pad_dpad_right.png`

Attach the FINISHED `i_tod_pad_dpad_left.png` from Prompt A.

```text
Here is a finished D-PAD icon for a game HUD (attached), with its LEFT arm lit
and containing a left-pointing arrow. Produce the right-hand version.

Canvas exactly 256 by 256 pixels, PNG, RGBA, fully transparent background,
identical to the attached file.

Change EXACTLY ONE THING: the RIGHT arm is the lit one, with a right-pointing
arrowhead in it, and the LEFT arm goes back to dark grey and unlit.

Everything else must be pixel-identical to the attached image: the same cross
shape, size, position, outline, gradient, glow colour, shadow and margins. The
two icons appear on screen at the same moment on opposite sides of a pair of
cards, so any drift will be obvious.

No text or numbers anywhere.

Deliver as i_tod_pad_dpad_right.png.
```

## Prompt C — `i_tod_pad_button_a.png`

Attach `reference/i_tod_hint_switch_pad.png`.

```text
Create an Xbox-style A button icon for a video game HUD. Canvas exactly 256 by
256 pixels, PNG, RGBA, fully transparent background.

Draw a single round face button, seen straight on, filling about the middle 75
percent of the canvas, optically centred. The attached game plate carries a
small green A button - build a much larger, cleaner version of exactly that.

A circular button with a vivid green face and a soft top-to-bottom gradient, a
thick near-black outline about 6 pixels wide, a thin lighter green inner rim,
and a soft dark drop shadow below and to the right. Centred on it, the capital
letter A in pure white, chunky and slightly condensed, with its own thin dark
outline so it stays crisp when shrunk.

The letter A is the ONLY text allowed in this image - it is moulded into the
button and never changes.

Flat vector-clean game UI art. Crisp edges. No photographic texture, no noise,
no chrome, no glossy highlight blob, no controller body around it - just the
button on transparency.

It is shown at about 52 by 52 pixels on screen, so keep the outline heavy and
the A large within the circle.

Deliver as i_tod_pad_button_a.png.
```

## Prompt C2 — `i_tod_pad_button_x.png`

Attach the FINISHED `i_tod_pad_button_a.png` from Prompt C.

```text
Here is a finished green Xbox-style A button icon for a game HUD (attached).
Produce its sibling, the X button.

Canvas exactly 256 by 256 pixels, PNG, RGBA, fully transparent background,
identical to the attached file.

Change EXACTLY TWO THINGS:
- the button face colour goes from green to a vivid blue (the standard Xbox X
  button blue), keeping the same style of soft top-to-bottom gradient and the
  same lighter inner rim, now in blue
- the letter changes from A to X

Everything else must be identical to the attached image: the same circle size and
position, the same near-black outline weight, the same drop shadow, the same
margins, and the same white lettering treatment - chunky, slightly condensed,
same cap height and optical centring, with its own thin dark outline.

The letter X is the only text. No other text or numbers anywhere. No controller
body, no other buttons.

The two buttons appear in the same places at different times, so any drift in
size or position will be obvious.

Deliver as i_tod_pad_button_x.png.
```

## Prompt D — `i_tod_key_blank.png`

Attach `reference/i_tod_hint_lock_kbm.png`.

```text
Create an EMPTY keyboard keycap for a video game HUD. Canvas exactly 192 by 192
pixels, PNG, RGBA, fully transparent background.

The attached game plate carries small key chips with letters printed in them.
Draw that chip, much larger and cleaner, with NOTHING printed in it.

A squarish keycap with generously rounded corners, filling about the middle 80
percent of the canvas, optically centred. Light cool-grey face with a soft
top-to-bottom gradient so it reads as a real key catching light from above, a
crisp near-black outline about 5 pixels wide, a slightly darker lower lip so it
looks subtly three-dimensional, and a soft dark drop shadow below.

The face must be CLEAN, FLAT AND EMPTY: the game prints a letter on top of it at
runtime, so nothing may compete with that. No letter, no number, no word, no
symbol, no arrow, no dot, no icon, no logo, no highlight streak across the
middle.

Flat vector-clean game UI art - no photographic texture, no noise, no heavy
bevel, no chrome.

It is shown at about 52 by 52 pixels on screen, so keep the outline heavy.

Deliver as i_tod_key_blank.png.
```

## Prompt E — `i_tod_key_blank_wide.png`

Attach the FINISHED `i_tod_key_blank.png` from Prompt D.

```text
Here is a finished empty keycap for a game HUD (attached). Produce the WIDE
version of the same key.

Canvas exactly 384 by 192 pixels, PNG, RGBA, fully transparent background.

The same keycap stretched to a wide rectangle: same grey face and gradient, same
near-black outline weight, same corner rounding RADIUS (do not scale the radius
up with the width - it must read as the same key family), same lower lip, same
drop shadow. It fills about the middle 85 percent of the canvas width and 80
percent of its height, optically centred.

It exists because the game may print a long name on it such as SPACE or MOUSE3,
so the interior must be an even, uninterrupted field from left to right.

Still COMPLETELY EMPTY: no letter, no word, no symbol, no icon, nothing printed
on the face.

Deliver as i_tod_key_blank_wide.png.
```

## Prompt F — `i_tod_hold_plate.png`

Attach `reference/i_tod_hint_lock_kbm.png` and `reference/i_tod_hint_frame.png`.

```text
Create a wide plate for a video game HUD. Canvas exactly 460 by 70 pixels, PNG,
RGBA, fully transparent background.

One attached image is a blank plate; the other is the same plate reading
"HOLD [SPACE] / [F] TO LOCK". Build a version between the two.

Use the blank plate's chassis exactly: same wide rounded pill at the same size,
near-black navy fill, thin bright cyan-white rim light, soft outer glow, subtle
inner vignette.

Print exactly two pieces of text on it, in the lettering style of the second
attached plate - chunky pure-white slightly condensed display capitals, thick
near-black outline, soft dark drop shadow:
- HOLD, in the left portion
- TO LOCK, in the right portion

Between them leave a CLEAN EMPTY GAP about 90 pixels wide and 46 pixels tall,
vertically centred. Nothing may be drawn in that gap - the game places a button
icon there at runtime. Do not draw the icon, do not outline the gap, do not
shade it differently, and do not print a key name in it.

Also run a shallow progress groove through the plate: inset about 12 pixels from
the rim on every side, a slightly recessed channel with rounded ends, very
subtly darker than the plate around it, with a faint one-pixel inner shadow
along its top edge so it reads as carved into the plate. The lettering sits ON
TOP of this groove and must stay fully readable. The groove itself is empty - no
fill, no segments, no tick marks, no arrows.

HOLD and TO LOCK are the only text: no key name anywhere, no other lettering.

Deliver as i_tod_hold_plate.png.
```

## Prompt G — `i_tod_hold_fill.png`

Attach the FINISHED `i_tod_hold_plate.png` from Prompt F, and
`reference/i_tod_hint_locked.png`.

```text
Here is a finished game HUD plate with an empty progress groove (attached), and
a second image showing the bright energised version of that plate family.
Produce the FILL that sweeps along the groove as the player holds a button.

Canvas exactly 460 by 70 pixels, PNG, RGBA, the same canvas as the attached
plate.

Draw ONLY the filled channel: the groove of the attached plate, in exactly the
same position and at the same height, now glowing bright cyan-white and lit from
within, with a soft bloom just outside the channel, in the spirit of the
attached energised plate.

Everything outside that channel must be FULLY TRANSPARENT: no pill, no rim, no
plate, no lettering, no outer glow around the plate shape. This image is layered
over the plate, so only the glowing channel exists in it. Do NOT copy the words
HOLD or TO LOCK into this file.

CRITICAL - the game stretches this image horizontally from zero width to full
width, so it must be COMPLETELY UNIFORM ALONG ITS LENGTH: an identical
cross-section at every horizontal position. No end caps, no rounded ends, no
bright leading edge, no left-to-right gradient, no segments, no tick marks, no
highlights sitting at a particular point along the bar. It MAY vary from top to
bottom - a soft vertical gradient inside the channel is good. Any left-to-right
variation will visibly smear when the bar is part filled.

Squared-off left and right ends, running the full length of the groove.

No text of any kind.

Deliver as i_tod_hold_fill.png.
```

## Prompt H — `i_tod_timer_track.png`

Attach `reference/i_tod_hint_frame.png`.

```text
Create a slim empty timer bar for a video game HUD. Canvas exactly 460 by 24
pixels, PNG, RGBA, fully transparent background.

The same material as the attached plate, in a much thinner strip: a long
rounded-end channel filling the canvas with about 4 pixels of transparent
margin, near-black navy fill, a thin bright cyan-white rim light, a soft outer
glow, and a faint inner shadow along the top edge so it reads as a recessed
track waiting to be filled.

Keep it quiet and empty: no fill, no segments, no tick marks, no numbers, no
icons, no arrows, no notches. A plain empty track.

Flat vector-clean game UI art, crisp edges, no texture or noise. It is shown at
about 280 by 15 pixels, so the rim must stay visible at roughly half size - no
hairlines.

No text of any kind.

Deliver as i_tod_timer_track.png.
```

## Prompt I — `i_tod_timer_fill.png`

Attach the FINISHED `i_tod_timer_track.png` from Prompt H, and
`reference/i_tod_hint_locked.png`.

```text
Here is a finished empty timer track for a game HUD (attached), and a second
image showing the bright energised look of the same family. Produce the FILL
that drains along the track as time runs out.

Canvas exactly 460 by 24 pixels, PNG, RGBA, the same canvas as the attached
track.

Draw ONLY the filled channel: the interior of the attached track, in the same
position and at the same height, glowing bright cyan-white and lit from within,
with a soft bloom just outside it. Everything outside that channel must be FULLY
TRANSPARENT - no rim, no track, no outer glow around the track shape. This is
layered over the track.

CRITICAL - the game stretches this image horizontally as the timer drains, so it
must be COMPLETELY UNIFORM ALONG ITS LENGTH: an identical cross-section at every
horizontal position. No end caps, no rounded ends, no bright leading edge, no
left-to-right gradient, no segments, no tick marks. It MAY vary from top to
bottom. Squared-off left and right ends.

No text of any kind.

Deliver as i_tod_timer_fill.png.
```

## Delivery checklist

- [ ] Ten files, named exactly as listed in the three tables above
- [ ] Canvases exact: 256×256 ×4, 192×192, 384×192, 460×70 ×2, 460×24 ×2
- [ ] All RGBA; open each on a checkerboard and confirm genuine transparency
- [ ] The A and X buttons differ ONLY in face colour and letter; overlay them
- [ ] **Both keycaps are EMPTY** — no letter, number, symbol or icon on either
- [ ] **The only lettering in the whole set is the `A` and `X` on the two face
      buttons and `HOLD` / `TO LOCK` on the plate** — check the other seven again
- [ ] The two d-pad icons differ ONLY in which arm is lit and which way its arrow
      points; overlay them to confirm nothing else moved
- [ ] `i_tod_hold_plate.png` has a clean empty gap between the two words
- [ ] Lay each fill over its track/plate: the glow lands exactly inside the
      channel, nothing pokes outside
- [ ] Squash each fill to 20% width and stretch it to 100%: identical, with no
      smeared end cap and no drifting highlight
- [ ] Shrink to on-screen size (glyphs 52×52, wide keycap 72×36, plate 222×34,
      timer 280×15) and confirm everything still reads — especially which d-pad
      arm is lit

## Do NOT

- Do not print any letter on either keycap. This is the single most important
  instruction here.
- Do not add lettering beyond the `A` and `X` on the two face buttons and
  `HOLD` / `TO LOCK` on the plate.
- Do not draw a controller body, thumbsticks or extra buttons around the d-pad or
  the face buttons — each glyph stands alone on transparency.
- Do not light more than one d-pad arm, and do not put arrows in the unlit arms.
- Do not give either fill rounded ends, an end cap, or a left-to-right gradient.
- Do not include the plate, rim, track or lettering inside a fill image.
- Do not change the colour family: cyan-on-navy, grey keycaps, green A button,
  blue X button.
- Do not deliver different canvas sizes, or a partial set.
<!-- PACK:END -->

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'`. Then LOOK at all ten on
   a checkerboard: transparency, both keycaps genuinely empty, the plate's gap
   empty, no stray lettering; overlay the d-pad pair; overlay each fill on its
   track; squash each fill to 20% and confirm no smear.
2. Copy into `source_data/tod_ui_images/_images/`. **All ten are NEW names**, so
   each needs a GDT block cloned from `i_tod_hint_frame` and an `image,` line in
   `zone_source/zm_tower_of_doom.zone`.
3. **Probe `GetControllerType()` in the same build** — one `tod_dev` print per
   player, read with and without a pad connected. It is documented server-side
   and per-player but stock never calls it, so its return values are unknown.
   That result decides how the glyph set is chosen:
   - **usable** → branch on it, push the device down the existing
     `tod_input_pad` clientfield lane into `CoD.TodPad`, and the plates follow
     the real device;
   - **not usable** → add a pause-menu override (Auto / Controller / Keyboard),
     the standard PC fallback, with the current latch as the Auto guess.
4. Lua, `tod_upgrade.lua` + `tod_class_select.lua`, behind one
   `USE_CARD_GLYPH_ART` flag: a glyph `UIImage` per side (the d-pad pair on a
   pad; keycap + `[{+smoke}]` / `[{+frag}]` token text on a keyboard);
   `CardHint` uses `i_tod_hold_plate` with the A button or a keycap +
   `[{+gostand}]` in its gap, and `HoldFill` retargeted into the groove; the
   countdown becomes the timer pair. Keep the current plates under the flag-off
   branch as the fallback. **The LOCKED plate (`i_tod_hint_locked`) is
   unchanged** — it names no key.
5. `node tools/lint_tod_lua.js`, then a **FULL build**. Proof: fresh
   content-hash `.iwi` for all ten names beside an untouched control.
6. Flip this STATUS to SHIPPED; CHANGELOG entry; player patch-note bullet.
