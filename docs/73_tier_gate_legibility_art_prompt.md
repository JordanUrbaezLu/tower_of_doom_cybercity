# 73 — TIER GATE BADGES: legibility re-bake (2 images)

<!-- art-pack
name: tier_gate_legibility
refs:
  i_tod_tier_gate_2.png | the CURRENT tier-2 badge (TIER 2 AT FLOOR 10): keep its chassis and emblem, replace its type. Attach to Prompt A.
  i_tod_tier_gate_3.png | the CURRENT tier-3 badge (TIER 3 AT FLOOR 30): same chassis, shown so the pair's registration is visible. Prompt B rebuilds it from the FINISHED new tier-2 badge, not from this file.
  i_tod_badge_luck_100.png | the luck badge: its TYPE TREATMENT (chunky white, thick black outline, drop shadow, one amber token) is the target. Its gold colour and clover are not. Attach to Prompt A.
preview: 280x60
-->

> **STATUS: SHIPPED v16.46, 2026-09-02 — UNPLAYED.** Pack built by
> `.\tools\make_art_pack.ps1 docs\73_tier_gate_legibility_art_prompt.md` →
> `~/Downloads/tod_tier_gate_legibility_art_pack.zip`; the drop came back the
> same hour as `files - 2026-09-02T171910.602.zip` (loose PNGs + a nested zip
> carrying the generator's own `build_tier_gates.py` and the Anton face — the
> two copies are pixel-identical). Verified via `-Inspect` + a per-pixel diff:
> 420×90 RGBA, TIER 2 AT FLOOR 10 / TIER 3 AT FLOOR 30 in heavy outlined type,
> the pair registered (emblem region 0/9,000 pixels differ; the 1,977 that do
> are the changed glyphs), and the 280×60 downscale reads at a glance, `AT`
> included. The generator re-rendered the chassis (654 of 9,000 emblem pixels
> differ from the old file at tolerance 8) — accepted: the pair is internally
> consistent, which is the runtime contract. Installed under the same names,
> FULL build 17:27:14, proof = NEW `i_tod_tier_gate_2_UIYF2CEJ…` and
> `i_tod_tier_gate_3_FKJ3Y47M…` `.iwi` @ 17:26:56 beside the untouched luck
> badge control. This doc was the FIRST in the art-pack format; the tool's
> header documents it.

**Why (user, 2026-09-02, after playing v16.43/44):** *"They dont look very
clear and hard to read. I want to have the llm enhance the legibility and
letter and number visibility."* Then, on the hand-off itself: *"Lets finalize
this process of zipping up reference images and instructions ... I can just
send the zip to my asset generator and they can easily know the task and
goal."* — which is what `tools/make_art_pack.ps1` now is.

**The diagnosis, measured, not guessed.** docs/50 already recorded at install
that "the delivered type is lighter than the luck badge's heavy outlined face,
which is a deviation from the chassis spec" and kept it. Rendering all three
badges at the on-screen 280×60 (System.Drawing, high-quality bicubic — the
files are in the pack) shows the gap: the luck badge is chunky white type with
a ~3 px black outline and a drop shadow; the tier badges are a thin, light,
condensed face with NO outline at ~34 px cap height, and at 1.5× down the
strokes fall to ~1 px and `AT` nearly vanishes. The chassis, emblem and colour
logic (steel pill, amber chevron — docs/50's chosen direction) are fine and
stay.

**Scope: the PAIR.** They swap at runtime and must stay pixel-registered, so a
type change to one is a type change to both. Same names, same 420×90 RGBA.

<!-- PACK:BEGIN -->
# TIER GATE BADGES — legibility re-bake (2 images)

## What this is

Two Black Ops 3 zombies HUD badges that swap at runtime. They are drawn at
**280 × 60 px on screen** and the lettering is hard to read there: the type is a
thin, light, condensed face with **no outline**, so it washes out against the
dark pill. Look at `preview_onscreen_280x60/` — that is what the player sees.

The fix is the TYPE, not the badge. Keep the chassis, keep the emblem, keep the
words. Make the letters and numbers big, heavy and outlined, the way the
attached luck badge does it.

**Deliver exactly TWO files:**

| Deliver as | Must read |
|---|---|
| `i_tod_tier_gate_2.png` | **TIER 2 AT FLOOR 10** |
| `i_tod_tier_gate_3.png` | **TIER 3 AT FLOOR 30** |

## References (in `reference/`)

- `i_tod_tier_gate_2.png`, `i_tod_tier_gate_3.png` — the CURRENT badges. The
  chassis to keep: steel-blue pill, amber stacked double chevron on the pale
  left disc, sparkles, navy interior. Their type is what is being replaced.
- `i_tod_badge_luck_100.png` — the luck badge, same 420 × 90 canvas, same
  on-screen size. **Its TYPE TREATMENT is the target**: chunky, heavy-weight,
  slightly condensed all-caps display face, pure white, with a thick near-black
  outline and a soft dark drop shadow, one token in the accent colour. Copy the
  treatment, NOT its gold colour and NOT its clover.
- `preview_onscreen_280x60/` — all three at their real on-screen size. Compare
  the luck badge preview with the tier badge previews: that gap is the brief.

## Hard rules

- Canvas exactly **420 × 90 px**, PNG, RGBA, fully transparent background,
  identical to the attached files. Drawn at 280 × 60 (a 1.5× downscale), so
  every stroke must survive that: no hairlines, no thin faces.
- **Keep** the pill shape and size, the steel-blue stroke and glow, the sparkle
  glyphs, the navy interior, and the amber double-chevron emblem in the same
  position at the same scale. Nothing outside the text changes.
- **Type:** a chunky, heavy, slightly condensed all-caps display face (the
  luck badge's weight or heavier). Cap height **40–44 px** on the 420 canvas
  (about 27–29 px on screen; the current type is ~34). Every glyph gets a
  **thick near-black outline, about 3 px at 420**, plus a soft dark drop shadow
  below-right. Letterspacing slightly open so glyphs do not fuse when
  downscaled. The line stays optically centred in the space right of the
  emblem and may run to within ~12 px of the inner keyline on the right.
- **Colours:** words pure white `#FFFFFF`; the floor number (`10` / `30`) in
  the chevron's amber `#FFC84D`, same weight and outline as the words. `AT` at
  the same weight, about 75% of the cap height, in a light grey `#C8D0DC` — it
  must still be readable at 280 × 60, not a whisper.
- The interior directly behind the text stays flat dark navy; do not brighten
  it, do not add a glow behind the letters.
- **The pair must be pixel-identical except the glyphs** `2`↔`3` and `10`↔`30`.
  Same face, size, outline, baseline, letterspacing, composition width. They
  swap on screen at runtime; any drift makes the badge visibly jump.

## Prompt A — build `i_tod_tier_gate_2.png`

Attach `reference/i_tod_tier_gate_2.png` AND `reference/i_tod_badge_luck_100.png`.

```text
Two Black Ops 3 zombies HUD badges are attached. The first (i_tod_tier_gate_2.png,
a steel-blue pill with an amber double chevron) has lettering that is too thin
and light to read at its on-screen size. The second (i_tod_badge_luck_100.png,
gold) has the lettering treatment I want: chunky, heavy, slightly condensed
all-caps display type, pure white, with a thick near-black outline and a soft
dark drop shadow.

Redraw the FIRST badge with the SECOND badge's type treatment. Canvas exactly
420 x 90 pixels, PNG, fully transparent background (RGBA), identical to the
attached files. Flat vector-clean game-UI art, crisp edges, no photographic
texture, no noise. It is displayed at 280 x 60, so every stroke must survive a
1.5x downscale.

KEEP from the first badge, unchanged: the pill shape and size, the steel-blue
outer stroke and glow, the small sparkle glyphs, the dark navy interior, and the
amber stacked double chevron on the pale disc at the left, in the same position
at the same scale. Do not make anything gold. Do not add a clover or any icon.

CHANGE only the lettering. The text reads exactly: TIER 2 AT FLOOR 10
- chunky, heavy, slightly condensed all-caps display face, as heavy as the gold
  badge's type or heavier
- cap height about 40 to 44 pixels on this 420-pixel canvas
- every letter and number has a thick near-black outline, about 3 pixels, and a
  soft dark drop shadow below-right
- TIER, FLOOR: pure white
- 10: bright amber #FFC84D, the same amber as the chevron, same weight and outline
- AT: the same weight, about three quarters of the cap height, light grey #C8D0DC
  - still clearly readable, not faded away
- letterspacing slightly open so the glyphs do not merge when downscaled
- the whole line optically centred in the space to the right of the emblem, and
  it may run to within about 12 pixels of the inner keyline on the right

The area directly behind the text stays flat dark navy: no glow behind the
letters, no brightening. Deliver as i_tod_tier_gate_2.png.
```

## Prompt B — build `i_tod_tier_gate_3.png` from the finished tier-2 badge

Attach the FINISHED `i_tod_tier_gate_2.png` from Prompt A (not the old one).

```text
Here is a finished Black Ops 3 zombies HUD badge (attached, reading "TIER 2 AT
FLOOR 10"). Produce its sibling.

Canvas exactly 420 x 90 pixels, PNG, fully transparent background (RGBA),
identical to the attached file.

Change EXACTLY TWO THINGS and nothing else:
- "TIER 2" becomes "TIER 3"
- "FLOOR 10" becomes "FLOOR 30"

Everything else must be pixel-identical to the attached image: the same pill,
stroke, glow, sparkles, the same amber chevron emblem in the same position at
the same scale, the same typeface, weight, outline, drop shadow, cap height,
letterspacing, baseline and overall composition width. "30" keeps the same
amber that "10" is in. The two badges swap places on screen at runtime, so any
drift in position or scale will make the badge visibly jump.

Deliver as i_tod_tier_gate_3.png.
```

## Delivery checklist

- [ ] Two files, named exactly `i_tod_tier_gate_2.png` and `i_tod_tier_gate_3.png`
- [ ] 420 × 90, RGBA, transparent background
- [ ] Reads `TIER 2 AT FLOOR 10` / `TIER 3 AT FLOOR 30` — proofread the digits
- [ ] Heavy outlined type, cap height 40–44 px; downscale to 280 × 60 and
      confirm every word, including AT, reads at a glance
- [ ] Overlay the two files: nothing outside the changed glyphs moves

## Do NOT

- Do not change the pill colour to gold, or copy the clover.
- Do not move, resize or restyle the chevron emblem.
- Do not add a lock icon, a subtitle, a level number or any extra text.
- Do not hand back a different canvas size or aspect ratio.
- Do not deliver only one of the pair — they ship together or not at all.
<!-- PACK:END -->

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` — headers, md5 vs the
   repo copies, nested zips expanded. Then LOOK at both; proofread the two
   strings; overlay the pair (everything outside the changed glyphs identical);
   downscale to 280×60 and read it at a glance — `AT` included.
2. Copy over both files in `source_data/tod_ui_images/_images/` (same names,
   no GDT/zone/Lua edits).
3. FULL build. Proof: NEW content-hash `.iwi` for `i_tod_tier_gate_2` AND
   `_3` with fresh mtimes, beside an untouched control (`i_tod_badge_luck_100`
   keeps its old files).
4. Flip this STATUS to SHIPPED with the build version; CHANGELOG entry; note in
   docs/50 that the "lighter type, kept as delivered" call was reversed here.
