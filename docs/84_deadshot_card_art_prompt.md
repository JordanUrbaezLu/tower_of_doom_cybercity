# 84 — DEADSHOT card art (domain 47: perma-Deadshot, ONE image)

<!-- art-pack
name: deadshot
refs:
  i_tod_card_headshot_ultimate.png | the ASSAULT class's own ULTIMATE card: the gold rarity treatment (rails, ribbon, medal, glow, sparkles), the assault accent colour, and every plate position — copy them exactly. Attach to the prompt.
  i_tod_card_giant_slayer_ultimate.png | a second assault ULTIMATE card from the same deck, so the treatment is sampled from two examples, not one. Attach to the prompt.
  i_tod_perk_deadshot.png | the perk-bar icon this card unlocks (drawn 28 x 28 on the HUD): echo its skull-in-a-crosshair motif in the illustration so the card and the icon read as the same thing. Attach to the prompt.
preview: 213x320
-->

> **STATUS: SHIPPED v16.67, 2026-09-03 — UNPLAYED.** Drop `files - 2026-09-03T002026.239.zip`: 1 file installed (md5 87ffa6f2; value line came back as PERMA / AIM BOT, accepted), GDT block, zone line, `CARD_SLUG[47]` + the new `CARD_ONE_IMAGE` lane (one file fills all three rarity slots). The PAUSE PLATE is requested separately in docs/85 (2026-09-03 — the user did want it; "only an Ultimate asset" meant one card rarity, not no plate). (Historical, pre-drop:) **REQUESTED 2026-09-02 (v16.64).** The domain ships on the TEXT
> fallback (PaintCard's nil-slug branch) until the PNG lands: `CARD_SLUG[47]`
> unset. Pack built by
> `.\tools\make_art_pack.ps1 docs\84_deadshot_card_art_prompt.md` →
> `~/Downloads/tod_deadshot_art_pack.zip`. Install = copy the PNG into
> `source_data/tod_ui_images/_images/`, add its GDT block + `image,` zone line,
> set `CARD_SLUG[47] = "deadshot"`, FULL build, prove with a fresh
> content-hash `.iwi`. **No pause-menu plate is requested** (user: "we only
> need an Ultimate asset for this") — the pause row stays a text row
> (47 > PAUSE_PLATE_MAX), which is the VITALITY/RECOVERY precedent.

## The domain

- **Key** `deadshot`, id **47**, **ASSAULT only**, band **S** (the rarest
  draw weight), **max 1**, scope `class` (survives tier promotions).
- **Effect:** permanent DEADSHOT. The engine's head-snap aim assist
  (`UseAlternateAimParams`, gamepad only) is switched on for that player for
  the rest of the match: it survives downs and respawns, shows in the perk
  bar with the Deadshot crest, and does NOT use a perk slot (it is an
  upgrade, not a purchase). Module `_tod_deadshot.gsc|.csc`.
- **The card is ALWAYS an ULTIMATE** (`set_rarity_lock( "deadshot", 3 )` —
  make_option forces the frame after its headroom clamp): "the only way to
  pull it is an Ultimate card" (user 2026-09-02). It pays its one level and is
  never dealt again. That is why exactly ONE image exists for it — there is no
  regular or super Deadshot card to draw.

**Baked text:** title `DEADSHOT`, value line `AIM BOT` (the user's words,
verbatim), ribbon `ULTIMATE` — **no `+3`** (it is a one-time unlock, not
three levels) and **no pip row** (there is no ladder to show). Those two
departures from the deck are deliberate; everything else is the deck's
ULTIMATE treatment, copied.

<!-- PACK:BEGIN -->
# DEADSHOT — one new upgrade card (ULTIMATE rarity only)

## What this is

A Call of Duty: Black Ops 3 zombies map has a deck of upgrade cards (drawn at
**213 × 320 px on screen**, see `preview_onscreen_213x320/`). This upgrade
exists at ONE rarity only, so it needs exactly ONE image. **The attached
cards ARE the style — match them exactly.** The new card has to sit in a hand
beside them and look like it came out of the same deck.

The upgrade: **DEADSHOT** — a permanent aim-lock: the player's aim snaps to
zombie heads for the rest of the match. It is a one-time unlock, always dealt
as an ULTIMATE card.

**Deliver exactly ONE file:**

| Deliver as | Size | Title plate | Value line (exact) | Ribbon | Pips |
|---|---|---|---|---|---|
| `i_tod_card_deadshot_ultimate.png` | 768 × 1152 | **`DEADSHOT`** | **`AIM BOT`** | **`ULTIMATE`** (no `+3`) | **none** |

RGBA with a **fully transparent background** — the card body sits on
transparency, it does not fill the frame. Same margin as the attached cards.

## References (in `reference/`)

- `i_tod_card_headshot_ultimate.png` — a card of the SAME CLASS at the SAME
  rarity. Everything structural comes from it: the card body, the title plate,
  the illustration panel, the gold ULTIMATE rails/ribbon/medal/glow/sparkles,
  the value plate, and the class **accent colour** of its illustration (sample
  it from the image; do not invent one).
- `i_tod_card_giant_slayer_ultimate.png` — a second ULTIMATE card from the
  same class, so you can see the rarity treatment on two different
  illustrations. Use both; where they agree, that is the rule.
- `i_tod_perk_deadshot.png` — the small icon that appears in the player's
  perk bar when this card is taken. Its motif (a skull inside a crosshair) is
  what the card's illustration should echo, so the card and the icon read as
  the same thing.

## The card template

**Canvas:** 768 × 1152 portrait, transparent outside the card edge.

1. **Card body** — rounded-corner near-black navy card with a very thick black
   outline, faint horizontal scanlines, a small dark cross-head screw in each
   corner, a slim vertical accent rail inside the left and right edges in the
   ULTIMATE gold-and-red.
2. **Title plate** — the rounded orange-to-amber gradient plate with a black
   outline and seven small studs along its top edge, holding **`DEADSHOT`** in
   chunky white bubble letters with a heavy dark outline. One line, all caps.
3. **Illustration panel** — the rounded darker-navy inset panel with a soft
   radial sheen at the top, faint scanlines, a thin inner border in the
   ULTIMATE gold, the four tiny corner pixel squares and two or three small
   sparkle glyphs, exactly as on the attached cards.
4. **Rarity ribbon** — the glowing orange-gold gradient pill with a dark
   notched arrowhead each side, reading **`ULTIMATE`** in the same bubble
   lettering — **and nothing after it**: no `+3`. The round gold star medal
   overlapping the panel's bottom-right corner.
5. **Value plate** — the dark inset rectangle with a thin rounded inner frame
   and a rivet in each corner, holding **ONE centred line** of chunky all-caps
   outlined lettering in the deck's ULTIMATE gold/amber: **`AIM BOT`**. No
   second line, no number.
6. **NO pip row.** The attached cards have a row of round sockets under the
   value plate; this card has none. Leave that band of the card as plain card
   body (scanlines continue through it). Do not draw empty sockets.
7. **Outer glow** — the warm gold-and-pink glow outside the card edge plus the
   scattered small gold sparkle crosses and tick marks, copied from the
   attached ULTIMATE cards.

## The illustration

A chunky flat-cartoon **zombie head, three-quarter view**, filling the centre
of the panel, drawn in the deck's flat style (grey-green skin, sunken eyes,
thick black outlines) — and locked inside a **big glowing crosshair reticle**
in the class accent colour with a gold core: a ring, four bracket ticks that
are visibly snapping inward toward the forehead (short motion dashes trailing
each bracket), and a small bright dot exactly on the forehead. The reticle is
the hero of the image and should echo the skull-in-a-crosshair of the perk
icon. One short cartoon tracer line enters from the lower-left, ending at the
forehead dot with a small white-and-gold impact spark. Behind the head,
receding into the panel's navy, two or three smaller out-of-focus zombie
silhouettes, each with a faint dim reticle on it (the lock jumping target to
target).

No human face or body. No weapon in frame beyond the tracer. No blood, no
hearts, no health bars, no text inside the panel, no digits anywhere on the
card.

## Hard rules

- Flat colours, thick black outlines, simple soft shading. No photorealism, no
  3D render look, no drop shadows on text.
- Text on the card is exactly three strings: `DEADSHOT`, `ULTIMATE`, and
  `AIM BOT`. **No other text, no `+3`, no logos, no watermark.**
- **No digits anywhere on the card.**
- **No pip sockets.** Generators add a socket row by habit; check the band
  under the value plate is empty.
- Plate positions (title, panel, ribbon, medal, value plate) must sit exactly
  where the attached ULTIMATE cards have them — overlay to check.
- Corner pixel of the file must be fully transparent — decode it.

## Prompt — build `i_tod_card_deadshot_ultimate.png`

Attach `reference/i_tod_card_headshot_ultimate.png`,
`reference/i_tod_card_giant_slayer_ultimate.png` AND
`reference/i_tod_perk_deadshot.png`.

```text
Two ULTIMATE upgrade cards from a Black Ops 3 zombies map are attached, plus
a small round perk icon. The cards ARE the style: match them exactly and
produce a NEW ULTIMATE card of the same deck. Deliver at exactly 768 x 1152
pixels, PNG, RGBA, transparent outside the card, same margin as the attached
cards. Flat cartoon, thick black outlines, no photorealism.

Copy from the attached cards, unchanged: the navy rounded card body with the
thick black outline, corner screws and scanlines; the gold-and-red side
rails; the orange-to-amber title plate with seven studs; the darker-navy
illustration panel with its sheen, gold inner border, corner pixel squares
and sparkles; the glowing orange-gold ribbon with notched arrowheads and the
gold star medal overlapping the panel's bottom-right corner; the dark
riveted value plate; the warm gold-and-pink outer glow with scattered gold
sparkle crosses and tick marks.

Two deliberate differences from the attached cards: the ribbon reads only
ULTIMATE (no "+3" after it), and there is NO row of round pip sockets under
the value plate - leave that band as plain card body.

Title plate text: DEADSHOT (chunky white bubble letters, dark outline).

Illustration: a chunky flat-cartoon zombie head in three-quarter view,
grey-green skin, sunken eyes, filling the centre of the panel, locked inside
a big glowing crosshair reticle drawn in the SAME accent colour as the
attached cards' illustrations (sample it) with a gold core: a ring, four
bracket ticks snapping inward toward the forehead with short motion dashes,
and a bright dot on the forehead. The reticle should echo the
skull-in-a-crosshair of the attached perk icon. One short tracer line enters
from the lower-left and ends at the forehead dot with a small white-and-gold
spark. Behind the head, receding into the navy, two or three smaller
out-of-focus zombie silhouettes, each with a faint dim reticle on it. No
human face or body, no weapon, no blood, no text inside the panel.

Value plate: ONE centred line of chunky all-caps outlined lettering in the
attached cards' ULTIMATE gold/amber: AIM BOT. No number, no second line.

No other text, no digits anywhere, no watermark. Deliver as
i_tod_card_deadshot_ultimate.png.
```

## Delivery checklist

- [ ] `i_tod_card_deadshot_ultimate.png`, 768 × 1152, RGBA, transparent
      corner pixel.
- [ ] Title reads `DEADSHOT`; ribbon reads `ULTIMATE` with nothing after it;
      value line reads `AIM BOT`. Proofread all three.
- [ ] No pip sockets anywhere on the card.
- [ ] No digits anywhere on the card.
- [ ] Overlaid on `i_tod_card_headshot_ultimate.png`, every plate lines up.

## Do NOT

- Do not add `+3` to the ribbon, a level number, or a socket row.
- Do not add a second rarity of this card — only the ULTIMATE exists.
- Do not change the accent colour to red/gold "because it is an ultimate";
  the rails and ribbon carry the rarity, the illustration keeps the class
  colour, exactly as the attached ULTIMATE cards do.
- Do not draw a gun, a scope view, or a first-person weapon.
- Do not deliver JPEG, a filled background, or a different size.
<!-- PACK:END -->
