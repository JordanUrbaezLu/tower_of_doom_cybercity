# 100 — CLASS MEDALLIONS: the badge beside your name, redone as 3D medals (4 files)

<!-- art-pack
name: class_medallions
refs:
  docs/100_hud_ref/current_medallions_onscreen.png | THE BRIEF IN ONE PICTURE: the four medallions exactly as the player sees them (84 px beside the name, 52 px on teammate rows), then at their 256 px source size, with the measurements. Attach to every prompt.
  i_tod_class_medallion_skirmisher.png | CURRENT skirmisher medallion (cyan). Being REPLACED. Shows the colour and the symbol idea, not the style.
  i_tod_class_medallion_assault.png | CURRENT assault medallion (gold). Being REPLACED.
  i_tod_class_medallion_heavy.png | CURRENT heavy medallion (red). Being REPLACED.
  i_tod_class_medallion_slasher.png | CURRENT slasher medallion (violet). Being REPLACED.
  docs/100_hud_ref/world_cover.png | the map's own cover art: the neon tower, the purple night city. The medals must belong to this world. Attach to every prompt.
preview: 84x84 52x52
-->

> **STATUS: SHIPPED v17.44 (2026-09-04).** The drop
> (`files - 2026-09-04T183151.480.zip`) came back exactly as asked: four 1024²
> RGBA discs, 15 px margin, transparent corners, zero ink outside the circle,
> one matching set. Shipped at 512² (premultiplied Lanczos via ffmpeg — recipe
> in `source_data/tod_ui_images/_masters/README_medallions.txt`, masters kept
> beside it). Both draw boxes re-verified SQUARE (56×56 local, 35×35 rows).
> UNPLAYED as of the build.

## Why (user, 2026-09-04)

*"our icons for each class on player HUD kinda suck and are either not
detailed in creation or way too low resolution. I'm looking for sick 3D icons
that display exactly the class ... I'm wondering if 4K would help too ... They
just look low quality and low detail. It should be a symbol of pride to wear
that icon next to your name."*

## The measurement — resolution is NOT the problem

Per the standing rule (memory `low-detail-is-rarely-low-resolution`), measured
before anything was asked for:

| | value | source |
|---|---|---|
| draw box, local panel | 56 × 56 canvas → **84 × 84 px at 1080p** (126 @1440p, 168 @4K) | `AetheriumPlayerInfo.lua` x24..80 y620..676; the panel is NOT under `TodScaleHud` |
| draw box, teammate rows | 35 × 35 → **52 px** | `AetheriumPartyPlayers.lua` |
| source | 256 × 256 RGBA, **uncompressed** (`compressionMethod "uncompressed"`, proven RGBA8 in docs/89) | `tod_ui_images.gdt` |
| src-used-% | **33 % at 1080p**, 49 % at 1440p, 66 % at 4K | |
| aspect | square in a square box since v16.21 / v16.97 — no stretch | |
| feature density | a thin ring + a flat 2-tone glyph with 2–4 px strokes at source, i.e. **<1 px strokes on screen** | the PNGs |

So a 4K source would throw away 95 % of its pixels at 1080p. The medallion
looks low-detail because it IS low-detail: flat fill, one outline, thin ring,
soft glow, no lighting — the docs/89 house style, which was chosen for glyphs
that had to survive a 6× downscale, and which reads as "cheap" on the one
element the user wants to feel like a medal.

**The fix is the RENDER, not the resolution.** A lit, bevelled, metallic 3D
medal with big shapes and strong light/dark contrast reads as a solid object
at 84 px, where a flat glyph reads as a sticker.

## Resolution decision

- **Ask for 1024 × 1024 masters.** Generators produce that natively, and a 3D
  render with fine highlights downsamples cleanly from 12× (1080p) with a good
  filter — the extra pixels are used by the resample, not thrown away.
- **Ship at 512 × 512.** That is 6× the 1080p draw, 3× the 4K draw, and
  uncompressed it costs 1 MB of load RAM per medal (4 MB the set) against
  256 KB today. 1024 shipped would be 4 MB EACH for pixels no screen shows;
  docs/86's size rule says no. Downscale on install with a Lanczos filter
  (`tools/downscale_pack_textures.js --cap 512` on the four, or any proper
  resampler — NOT a nearest-neighbour or a browser drag).
- **Say "do not upscale" in the brief** or it comes back 4K anyway.

## Design decisions

- **Keep the four class colours EXACTLY.** They are the class identity on the
  cards, the class-select screen, the tier cards and the teammate rows:
  skirmisher cyan `#33D9FF`, assault gold `#FFBF40`, heavy red `#FF594D`,
  slasher violet `#BF73FF` (from `tod_class_select.lua`'s `accent` table).
  The metal of the medal carries the colour; the symbol is lighter metal.
- **Keep the SYMBOL IDEAS** (they already tell the classes apart): skirmisher =
  a running figure with an SMG, assault = a rifle with a rank chevron, heavy =
  an LMG with an ammo belt, slasher = a katana. Rendered as 3D objects now.
- **The disc IS the box.** The draw box is exactly the medal's outer edge, so
  the medal must fill the canvas edge-to-edge (≤ 3 % transparent margin) and
  the corners must be fully transparent. A glow outside the disc gets clipped
  by the box and reads as a square halo — so NO outer glow; put the light ON
  the metal instead.
- **Authored for 84 px.** The symbol fills ≥ 60 % of the disc; nothing that
  matters is thinner than 24 px on the 1024 master (2 px on screen). Bevel,
  rim light and specular are the detail — they survive; engraving does not.

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` — LOOK at all four at
   84 and 52 (the inspect preview folder); check the corners are transparent
   and the disc fills the canvas.
2. Downscale each to 512 × 512 (Lanczos), save over
   `source_data/tod_ui_images/_images/i_tod_class_medallion_<class>.png`. Same
   names, so no GDT / zone / Lua change; the GDT block already says
   `uncompressed` + `noPicMip`.
3. FULL build; proof = 4 fresh content-hash `.iwi` in
   `share/assetconvert/image/v29/` beside an untouched control, and the
   assetlist row count unchanged.
4. Flip this STATUS to SHIPPED with the version. The file has exactly TWO
   consumers — the local panel and the party rows (verified 2026-09-04: they
   are the only callers of `GetClassPortrait`; the brief image's "and the
   scoreboard" row was an unchecked claim and is wrong) — both square. LOOK at
   both in game: a 3D medal that reads at 84 might muddy at 52.

<!-- PACK:BEGIN -->
# CLASS MEDALLIONS — four 3D medals, one per class (4 files)

## Start here

**Open `current_medallions_onscreen.png` first.** It shows the four class
badges exactly as the player sees them today — 84 pixels wide beside their
name, 52 pixels on the teammate rows — and then at full size. They are flat
stickers. The player is meant to feel PRIDE wearing this badge next to their
name for a whole match, and today it reads as a coloured circle with a smudge
in it.

**What you are making: four MEDALS.** Solid, heavy, lit metal objects — the
kind of class emblem a player screenshots. Rendered in 3D (or painted to read
exactly like a 3D render): bevelled rims, a real light source, specular
highlights on the metal, deep shadow in the recesses, a hard clean silhouette.
The opposite of the flat glyphs attached.

## Deliver exactly FOUR files

| file | size | class | colour of the metal |
|---|---|---|---|
| `i_tod_class_medallion_skirmisher.png` | **1024 × 1024**, PNG, RGBA | SKIRMISHER | cyan `#33D9FF` |
| `i_tod_class_medallion_assault.png` | **1024 × 1024**, PNG, RGBA | ASSAULT | gold `#FFBF40` |
| `i_tod_class_medallion_heavy.png` | **1024 × 1024**, PNG, RGBA | HEAVY | red `#FF594D` |
| `i_tod_class_medallion_slasher.png` | **1024 × 1024**, PNG, RGBA | SLASHER | violet `#BF73FF` |

**Exactly 1024 × 1024. Do not deliver larger.** We resize them ourselves for
the game; a 4K file gains nothing and costs us a round trip. The four must be
one matching set: same lighting direction, same rim design, same camera, same
metal treatment — only the colour and the symbol change.

## The shape rules (these are mechanical, not taste)

- **A perfect circle that fills the canvas.** The medal's outer edge touches
  the canvas edge (at most a 3 % margin). The four corners outside the circle
  are **fully transparent**. The game draws the file into a square box that IS
  the medal's edge, so any glow, shadow or halo OUTSIDE the circle gets cut off
  square and looks broken. **No outer glow. No drop shadow. Nothing outside
  the disc.** Put all the light ON the metal.
- **Made to be seen at 84 pixels.** Before delivering, shrink each one to
  84 × 84 and to 52 × 52 and look at them on a dark navy background. If the
  class symbol is not obvious at 52, it is too small or too thin. The symbol
  should fill at least 60 % of the disc. Nothing that matters may be thinner
  than 24 pixels on the 1024 canvas.
- **Big shapes, strong contrast.** The detail that survives shrinking is
  bevel, rim light and specular — light against dark. Fine engraving, thin
  lines, texture and small text do NOT survive and must not be used.
- **No text, no numbers, no letters** anywhere on the medal.

## The four medals

The **rim**: a thick bevelled metal ring in the class colour, with a bright
specular highlight along the upper-left and a dark shadow along the lower-right,
like a real coin edge. Inside it, a dark recessed field (deep navy, near-black
`#0B1020`, with a subtle radial falloff) so the symbol stands proud of it.

The **symbol**: a solid 3D object in a lighter, brighter version of the class
metal, raised off the field, lit by the same light as the rim, casting a soft
shadow INTO the field (inside the disc only).

| class | the symbol, rendered as a solid object |
|---|---|
| **SKIRMISHER** (cyan) | a running figure, full sprint, mid-stride, holding a compact SMG one-handed out in front; two or three thick motion bars behind. The figure fills the disc top to bottom. |
| **ASSAULT** (gold) | an assault rifle, side profile, slightly angled, magazine down; a single bold rank CHEVRON above it. The rifle spans the full width of the field. |
| **HEAVY** (red) | a light machine gun, side profile, heavy and wide, with a chunky ammo belt curving down and out of it. The widest, heaviest symbol of the four. |
| **SLASHER** (violet) | a katana, blade drawn, angled corner to corner across the disc, with a clean specular flash along the edge. The longest, sharpest symbol of the four. |

The set must belong to the attached cover art's world: neon, night, clean
hard-surface metal — not fantasy, not cartoon, not chrome-on-white.

## The prompt (one pass, all four)

Attach `current_medallions_onscreen.png`, the four current medallion files, and
`world_cover.png`.

```text
Attached: the four class badges currently in a Call of Duty zombies map's HUD,
shown at the tiny size the player sees them (84 and 52 pixels) and at full
size, plus the map's cover art.

Make FOUR new class medals to replace them - one matching set, a real 3D-rendered
look: a heavy bevelled metal medal with a real light source, specular highlights
on the metal, deep shadow in the recesses, a hard clean silhouette. These are a
badge of pride shown beside the player's name for the whole match. They must
look like solid objects, not flat stickers.

Each: canvas exactly 1024 x 1024 pixels, PNG, RGBA, transparent background. A
PERFECT CIRCLE that fills the canvas edge to edge (no more than 3 percent
margin). The four corners outside the circle are fully transparent. NOTHING
outside the circle - no outer glow, no drop shadow, no halo - the game clips
to the disc and anything outside it breaks. All light goes ON the metal.

Shared design, all four:
- a thick bevelled metal RIM in the class colour, bright specular along the
  upper-left edge, dark shadow along the lower-right, like a coin edge
- inside the rim a dark recessed field, deep navy near-black #0B1020 with a
  subtle radial falloff
- the class SYMBOL as a solid raised 3D object in a lighter, brighter version of
  the class metal, lit by the same light, casting a soft shadow into the field
- same camera, same light direction, same rim design across all four; only the
  colour and the symbol change

The four:
1 SKIRMISHER - metal colour cyan #33D9FF. Symbol: a running figure in full
  sprint, mid-stride, holding a compact SMG one-handed out in front, two or
  three thick motion bars behind. Fills the disc top to bottom.
2 ASSAULT - metal colour gold #FFBF40. Symbol: an assault rifle in side
  profile, slightly angled, magazine down, spanning the full width of the
  field, with one bold rank chevron above it.
3 HEAVY - metal colour red #FF594D. Symbol: a light machine gun in side
  profile, heavy and wide, with a chunky ammo belt curving down out of it. The
  widest, heaviest symbol of the set.
4 SLASHER - metal colour violet #BF73FF. Symbol: a katana, blade drawn, angled
  corner to corner across the disc, with a clean specular flash along the edge.
  The longest, sharpest symbol of the set.

Made to be seen SMALL: the symbol fills at least 60 percent of the disc;
nothing that matters is thinner than 24 pixels on the 1024 canvas; big shapes
and strong light-against-dark contrast; no fine engraving, no thin lines, no
texture, no text, no numbers, no letters. Before delivering, shrink each to
84 x 84 and 52 x 52 on a dark navy background and check the class is obvious.

The world is the attached cover art: neon, night, clean hard-surface metal.
Not fantasy, not cartoon, not chrome-on-white.

Deliver exactly four files at exactly 1024 x 1024 - do not upscale, do not
deliver 2K or 4K:
i_tod_class_medallion_skirmisher.png, i_tod_class_medallion_assault.png,
i_tod_class_medallion_heavy.png, i_tod_class_medallion_slasher.png
```

## Delivery checklist

- [ ] four files, exact names, each **exactly 1024 × 1024**, RGBA
- [ ] a full circle filling the canvas; corners fully transparent; nothing outside the disc
- [ ] one matching set: same light, same rim, same camera
- [ ] the class colours are the four hex values, on the rim metal
- [ ] each symbol obvious at 52 × 52 on dark navy
- [ ] no text, no glow outside the disc, no drop shadow

## Do NOT

- do not deliver larger than 1024 × 1024, and do not upscale
- do not put a glow, shadow or halo outside the circle
- do not change the four class colours
- do not use fine engraving, thin lines, texture or text
- do not make the four differently lit or differently framed
<!-- PACK:END -->
