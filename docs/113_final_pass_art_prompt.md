<!-- art-pack
name: final_pass
refs:
  i_tod_card_tier_skirmisher_2.png | CURRENT tier-2 card, skirmisher (cyan band) - re-bake with the caution strip
  i_tod_card_tier_skirmisher_3.png | CURRENT tier-3 card, skirmisher - re-bake with the caution strip
  i_tod_card_tier_assault_2.png | CURRENT tier-2 card, assault (amber band) - re-bake with the caution strip
  i_tod_card_tier_assault_3.png | CURRENT tier-3 card, assault - re-bake with the caution strip
  i_tod_card_tier_heavy_2.png | CURRENT tier-2 card, heavy (green band) - re-bake with the caution strip
  i_tod_card_tier_heavy_3.png | CURRENT tier-3 card, heavy - re-bake with the caution strip
  i_tod_card_tier_slasher_2.png | CURRENT tier-2 card, slasher (violet band) - re-bake with the caution strip
  i_tod_card_tier_slasher_3.png | CURRENT tier-3 card, slasher - re-bake with the caution strip
  i_tod_badge_luck_100.png | the luck badge at full - the NEW legend strip sits under it and must match this chassis exactly
  i_tod_badge_luck_50.png | the same badge at a mid value, for the amber palette at partial fill
preview: 234x351 280x60
-->

# 113 - FINAL PASS ART (tier-card caution + luck legend)

**STATUS: SHIPPED v18.10 (2026-09-07).** Drop `files - 2026-09-07T020147`.
All 9 installed. Two variants were chosen over the ones this brief specified,
both because the generator measured the geometry and this brief had not:

* **Cards — the strip sits inside the weapon screen's lower edge**, not in the
  gap named below. That gap is **16 px tall** on the reference cards
  (name-plate border ends y 988, pip row starts y 1004); the requested 620x76
  could not fit and the best the position allows is a 17 px cap, ~5 px on
  screen. Shipped 500x76 at y 606, 54 px cap. The `_alt_in_panel/` build (the
  requested position, pip row nudged 10 px) was rejected on legibility, which
  is this brief's own top rule.
* **Legend — the NEUTRAL steel variant**, not the amber one asked for below.
  Amber is the badge's **full-value state, not its chassis**: at 100% the
  border, clover and number are gold, at 50% they are green. A gold caption
  would read correctly at one luck value only. The optional chevron was
  dropped too — it crowded the words at 280x60.

The rule both corrections share: **specify the constraint, not the solution.**
"Legible at the real display size" survived contact with the geometry; "put it
in this gap" and "match the amber palette" did not.

## Why these two

The pre-publish audit (105 agents over the code and the 130-comment Workshop
thread) surfaced two information gaps that players hit repeatedly and that no
amount of script work can close, because in both cases the player is looking at
a picture at the moment they need the fact:

1. **The TIER card never says the new gun arrives un-Pack-a-Punched.** Two
   separate players raised it (`.vers` 2026-09-02: *"taking the kit upgrade
   wipes your PaP on your guns which is unfortunate"*; `Nello` 2026-08-29: *"a
   class upgrade can actually feel like a downgrade"*). On the spire it is
   worse than it sounds: a tier card can vaporise 75,000 points of PACK II /
   PACK III with no warning on any surface. The card is what a player reads
   while deciding, so the warning has to be baked into the card.
2. **Nothing in game says what the luck bar does.** `Apendex` 2026-09-06:
   *"What does luck do?"* - the author answered in the comment thread, which is
   the proof the game does not. Every in-game surface that names luck is
   circular: the LUCK domain row explains how to raise it and never says what
   it buys, and a player who never rolls that domain never sees even that.

## The split between art and text (deliberate)

The card is 768x1152 but **draws at 234x351** - a quarter of its linear size
(`CARD_Y0, CARD_Y1 = 226, 577` in `tod_upgrade.lua`, 2:3 aspect). At that size a
sentence is unreadable, so the ART carries ONE WORD that must survive the
downscale, and the DETAIL text carries the explanation. Same rule for the luck
legend at 280x60 (the luck badge's own on-screen box, `950->1230, 150->210`).

Text side, no art needed, done in the same change:
* the CLASS TIER pause row gains "new gun starts unpacked, gun upgrades reset"
* the existing free toast lane says it once at the moment of promotion
* the LUCK row gains what the bar actually buys

## Install notes (repo side)

Both deliverables reuse existing names or add one: the eight tier cards are
same-name replacements (no wiring), the luck legend is a new
`i_tod_luck_legend` needing a GDT block, a zone `image,` line and a Lua slug.
Full build; proof is a fresh content-hash `.iwi` beside an untouched control.

<!-- PACK:BEGIN -->

# TOWER OF DOOM - FINAL PASS ART

Two jobs. The first is eight re-bakes of cards you have already made; the second
is one new strip. Everything here is a UI image for a Call of Duty custom
zombies map with a neon-cyberpunk look.

## THE ONE RULE THAT DECIDES BOTH JOBS

**These images are displayed far smaller than they are drawn.**

| Deliverable | You author | Player actually sees |
|---|---|---|
| Tier cards | 768 x 1152 | **234 x 351** |
| Luck legend | 420 x 90 | **280 x 60** |

The `preview_onscreen_*` folders in this pack show every reference image at its
real on-screen size. **Judge your work in those folders, not at full size.** A
line of text that reads beautifully at 768 wide is mush at 234. That is why the
new text on these images is deliberately only one or two words - do not add a
sentence, however much space appears to be free.

---

## JOB 1 - EIGHT TIER CARDS, ADD A CAUTION STRIP

### Deliverables (768 x 1152 PNG, same names, replacing the originals)

| File | Class | Band colour |
|---|---|---|
| `i_tod_card_tier_skirmisher_2.png` | SKIRMISHER | cyan |
| `i_tod_card_tier_skirmisher_3.png` | SKIRMISHER | cyan |
| `i_tod_card_tier_assault_2.png` | ASSAULT | amber |
| `i_tod_card_tier_assault_3.png` | ASSAULT | amber |
| `i_tod_card_tier_heavy_2.png` | HEAVY | green |
| `i_tod_card_tier_heavy_3.png` | HEAVY | green |
| `i_tod_card_tier_slasher_2.png` | SLASHER | violet |
| `i_tod_card_tier_slasher_3.png` | SLASHER | violet |

All eight are in `reference/`. **Start from those exact files.** Every element
already on them stays where it is, at the size it is: the TIER 2 / TIER 3 header
plate, the weapon screen, the class name band, the weapon name plate, the pips,
the frame, the outer glow.

### The one change

Add a **caution strip** across the card carrying exactly this word:

```
UNPACKED
```

Nothing else. No second line, no sentence, no number, no punctuation.

* **Where:** immediately BELOW the weapon-name plate (the panel reading e.g.
  "KATANA / UDM 45") and ABOVE the row of pips. If that gap is too tight, take
  the space from the pip row's padding - never from the weapon screen.
* **Size:** the strip should be about 620 x 76 inside the card's frame, centred.
  The word should fill it confidently - roughly 54 px cap height. At the real
  234 px display width this word must still be instantly readable; check it in
  `preview_onscreen_234x351/`.
* **Colour:** a caution treatment that reads as a warning without fighting the
  class band - dark amber/red plate, bright warm-white or amber type, thin
  bright rule top and bottom. It must read as "careful" at a glance, and it must
  NOT look like a reward or a bonus.
* Keep it in the card's existing visual language: same rounded-rectangle plate
  style, same chunky outlined display type, same slight bevel and glow.

### Why the word is "UNPACKED"

Taking this card hands the player the next weapon in their class, and that
weapon arrives without its Pack-a-Punch upgrade. Players have been surprised by
this and lost a lot of progress to it. One unmistakable word is the whole job -
the game explains the rest in its menus.

### Prompt you can paste (repeat per class/tier, attaching that card)

> Attached is a game UI card, 768x1152. Reproduce it EXACTLY - same frame, same
> header plate, same weapon illustration and screen, same class band, same
> weapon name plate, same pips, same colours, same glow - and make one addition:
> a caution strip centred between the weapon name plate and the pip row,
> approximately 620x76, containing only the word "UNPACKED" in the same chunky
> outlined display typeface used elsewhere on the card, about 54px cap height.
> Style the strip as a warning: dark amber-red plate, bright amber-white
> lettering, thin bright rules above and below, matching the card's existing
> bevel and glow language. Change nothing else. Output PNG 768x1152 with the
> same transparent surround as the original.

---

## JOB 2 - ONE NEW STRIP, THE LUCK LEGEND

### Deliverable

| File | Size | Notes |
|---|---|---|
| `i_tod_luck_legend.png` | **420 x 90** | new file, transparent outside the plate |

### What it is

The player has a LUCK bar on screen that fills as they play, and a badge showing
its percentage. Nothing tells them what it is FOR. This strip sits directly
under that badge and answers it in two words.

Exact text, nothing else:

```
BETTER CARDS
```

### How it must look

* **Match `i_tod_badge_luck_100.png` exactly** - it is in `reference/`, and this
  strip is its sibling sitting immediately beneath it. Same chassis: same plate
  shape, same corner treatment, same border weight, same bevel, same amber luck
  palette, same outlined display type, same transparent surround.
* `i_tod_badge_luck_50.png` is in `reference/` too - the same badge at a
  half-full value. Attach it alongside the 100 version so you can see which
  parts of the amber palette are the fixed chassis and which change with the
  fill. Your strip uses only the fixed chassis colours.
* Same 420 x 90 canvas and the same internal margins, so the two stack into one
  visual unit rather than looking like two separate widgets.
* The luck badge is the loud one (it carries the number). This strip is the
  quiet one: slightly lower contrast, so it reads as a caption to the badge
  rather than competing with it.
* Optional and only if it stays clean at 280 x 60: a small upward chevron or
  spark glyph at the left inside edge, in the same amber, hinting "this rises".
  Skip it if it crowds the words.

### Prompt you can paste

> Attached are two versions of a game UI badge, 420x90, amber on dark, with a
> chunky outlined display typeface and a bevelled plate (one at a full value,
> one at half, so you can tell the fixed chassis from the fill). Produce a
> SIBLING strip on the same
> 420x90 canvas that will sit directly beneath it: identical plate shape, corner
> treatment, border weight, bevel, palette and transparent surround, but
> containing the words "BETTER CARDS" instead of a number, at slightly lower
> contrast so it reads as a caption to the badge above it. The words must be
> instantly readable when the whole strip is displayed at only 280x60. Output
> PNG 420x90.

---

## DELIVERY CHECKLIST

- [ ] 9 PNGs total: 8 tier cards at 768x1152, 1 luck legend at 420x90
- [ ] Exact filenames as listed - they replace or join existing game files
- [ ] Tier cards keep every original element unchanged; only the caution strip
      is new
- [ ] The word on the cards is `UNPACKED`; the words on the strip are
      `BETTER CARDS`. No other new text anywhere.
- [ ] Transparent surround preserved on every file
- [ ] **Every file checked at its real display size** (234x351 for cards,
      280x60 for the strip) and still legible there
- [ ] Zip them together and send back

## DO NOT

- Do NOT add any number to any of these images.
- Do NOT add a second line, a sentence, or an explanation - the game's menus
  carry the detail; these images carry one readable phrase each.
- Do NOT redraw, restyle, recolour or "improve" the existing card artwork. The
  eight cards must be pixel-faithful to the originals apart from the new strip.
- Do NOT change the canvas size of anything.
- Do NOT crop the transparent surround.
- Do NOT invent new class colours - each card keeps the band colour it has.

<!-- PACK:END -->
