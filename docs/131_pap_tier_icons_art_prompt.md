<!-- art-pack
name: pap_tier_icons
refs:
  docs/131_pap_ref/onscreen_row.png | THE WHOLE BRIEF IN ONE PICTURE. All five icons at their TRUE on-screen size at 1080p, on the HUD's own near-black, in HUD order: blink, heal, then PaP 1, 2, 3. Blink and heal are instantly readable. The three PaP icons are three nearly identical dark smudges and you cannot tell which tier is which. Look at this before anything else, and judge your own work by re-making this row.
  docs/131_pap_ref/pap_vs_offhand.png | The same five at 4x with the true-size row beneath. Left of the rule: the two icons the user likes. Right of the rule: the three to replace. Study what the good two do that the bad three do not.
  i_tod_hud_off_blink.png | THE QUALITY BAR, 1 of 2. The user's words: "both blink and healing aura look great". One bold geometric symbol, filling the cell, with a big committed purple mass. Match this level of readability.
  i_tod_hud_off_heal.png | THE QUALITY BAR, 2 of 2. A flat green cross on a flat ring. Note how little detail it contains and how well that works.
  i_tod_hud_pap_1.png | DELIVERABLE 1, current version - TIER 1. To be replaced completely. This is a fist with a lightning bolt and chevrons; see the brief for why nobody can tell.
  i_tod_hud_pap_2.png | DELIVERABLE 2, current version - TIER 2. Differs from tier 1 only by one extra small chevron.
  i_tod_hud_pap_3.png | DELIVERABLE 3, current version - TIER 3. Differs by one more chevron again.
  i_tod_hud_pap_tile.png | THE PLATE the icon sits on, and it is NOT a deliverable. Your icon is drawn on top of this, inside a square box in its left portion. Note its cyan top rule - that is the PaP plate's existing accent.
  i_tod_hud_offhand_tile.png | The plate blink and heal sit on, for comparison. Same chassis as the PaP plate, without the cyan rule.
  i_tod_hud_off_monkey.png | A third icon on the same HUD row, same box, for breadth on the house style.
  i_tod_hud_off_frag.png | A fourth icon on the same row. Simple, bold, one colour mass.
  i_tod_pu2_free_pap.png | The map's own free-Pack-a-Punch power-up icon, for SUBJECT vocabulary only. Its gradient and its yellow are banned here.
preview: 39x39 36x36
-->

# 131 — THE PACK-A-PUNCH TIER ICONS: make them readable, and make the tier obvious

> **STATUS: ROUND 4 DELIVERED AND INSTALLED 2026-09-10 21:47**
> (`files - 2026-09-10T214733.441.zip`). The generator took **direction A, the
> chevron stack**, with the three specified hues exact. Every acceptance number
> cleared before install; FULL build started 21:50. UNPLAYED — no native check.
>
> Round 3's files are parked at `docs/131_pap_ref/_prev_shipped/`; these images
> are NOT git tracked, so that folder is the only copy. The delivery's own
> review sheet is kept as `docs/131_pap_ref/delivered_review_round4.png`.

### Round 4 acceptance record

Measured by `node tools/gen_pap_icon_ref.js` (its numbers are the table farther
down, recomputed against the installed files):

| | tier 1 | tier 2 | tier 3 | the gate | blink / heal |
|---|---|---|---|---|---|
| **bright saturated px** | **62.1%** | **50.0%** | **37.8%** | >= 20% | 20.2 / 38.3% |
| ink coverage | 49.9% | 49.9% | 49.9% | 44-50% | 44.2 / 47.5% |
| tones >=2% of ink | 3 | 3 | 3 | <= 5 | 5 / 5 |
| ink bounding box | 80.7% | 80.7% | 80.7% | >= 80% | 84.8 / 80.6% |

The saturation gap this brief was written about is closed and then some: 9.0%
average before, **49.9% after**, against a quality bar of 29.3%. Dominant
colours are the exact specified hex — `#3FD8E8`, `#F5C542`, `#F0524B` — each
with one darker companion (`#1F929E`, `#A77C21`, `#A32D28`) as its single
shadow step, which is why the tone count is 3 rather than the permitted 5.

Re-generated `docs/131_pap_ref/onscreen_row.png` with the delivered files in
place — the acceptance test this brief set — and the three tiers are instantly
distinguishable from each other and from blink and heal at true size.

**One measurement to discount rather than chase.** A "thinnest horizontal ink
run" check reports **1 px** on all three, against the brief's rule that nothing
be thinner than 8 px. That reading is an artifact, not a violation: the metric
counts horizontal runs, and any diagonal edge produces 1-px runs at its tip no
matter how thick the bar is. Round 3 scored 2 px for the same reason and heal
scores 26 px only because it contains no diagonal at all. The chevron bars are
thick and well separated; verified visually at 4x. Do not "fix" this number.

## Why (user, 2026-09-10)

> *"Our pap icon looks like ass in game. But both blink and healing aura look
> great. Can we zip up an asset request with those as quality example and get
> better pap icons? Creative and obvious to the player what tier pap they are."*

The user sent a HUD screenshot with the PaP badge reading tier 1 beside the
blink and heal tiles. Their read is correct and this doc exists to make the
reason measurable rather than aesthetic.

## This is round FOUR, and the first three failed the same way

`docs/125` commissioned these icons and went three rounds in two days:

| round | subject delivered | tier carried by |
|---|---|---|
| v17.60 (docs/102) | a pale pointed capsule | 1/2/3 bolts inside it |
| round 2 (2026-09-09 13:13) | a blunt side-on pistol | 1/2/3 upward chevrons |
| round 3 (2026-09-09 19:19, SHIPPING NOW) | a clenched fist + lightning bolt | none/one/two chevrons above it |

docs/125 already diagnosed round 1 as reading like *"a bullet, a rocket or a
gravestone"*. Round 4 must therefore change the MECHANISM, not the subject
again — three different pictures have now failed in the same cell, so the fault
is not which object was chosen.

**One observation that should decide the whole approach.** Reviewing the
shipped art at **4x magnification**, deliberately studying it, the author of
this brief identified the tier-1 icon as *"a gun"* and wrote that down. It is
a fist. If the silhouette cannot survive a reviewer looking straight at it at
four times size, it has no chance at all at 39 pixels in peripheral vision
during a fight.

## What is NOT wrong, measured — so nobody "fixes" the wrong thing

Read straight off `AetheriumLoadout.lua`:

| | box (canvas units) | at 1080p |
|---|---|---|
| offhand icon (blink, heal) | 24 x 24 (line 1346) | **36 x 36 px** |
| **PaP glyph** | **26 x 26** (line 1443) | **39 x 39 px** |

**The PaP icon already gets a BIGGER box than the two icons the user likes, and
still loses.** It is not a resolution problem and not a box problem. Do not ask
for a larger box and do not deliver a larger canvas; 128x128 stays.

Nor is it a matter of filling the cell. Measured by
`tools/gen_pap_icon_ref.js`, which reuses the ink/saturation/tone definitions
from `tools/gen_staffhud_ref.js` so the figures compare across briefs:

| | blink | heal | **GOOD mean** | pap 1 | pap 2 | pap 3 | **BAD mean** |
|---|---|---|---|---|---|---|---|
| ink coverage | 44.2% | 47.5% | **45.9%** | 39.3% | 42.4% | 48.1% | **43.3%** |
| **bright saturated px** | 20.2% | 38.3% | **29.3%** | 7.2% | 9.2% | 10.7% | **9.0%** |
| tones >=2% of ink | 5 | 5 | **5.0** | 4 | 4 | 4 | **4.0** |
| ink bounding box | 84.8% | 80.6% | **82.7%** | 72.5% | 72.5% | 82.7% | **75.9%** |

Ink coverage is effectively equal (43.3% against 45.9%). The one large,
consistent gap is **saturated colour: 9.0% against 29.3%, a factor of 3.3.**

A correction worth recording so it is not re-derived: the obvious hypothesis
was that the good icons are ONE shape and the bad ones are two competing
objects, measurable as the largest connected ink blob. Measured, **all five
score 100% and a single blob** — the PaP fist and its chevron badge touch, so
they connect. The hypothesis was right about the composition and wrong about
the metric; the colour figure is the one that holds up.

## So what is actually wrong — three things

1. **Almost no colour.** 9% saturated ink against the quality bar's 29%. Blink
   commits a third of its ink to purple and heal commits more than a third to
   green; each is identifiable by hue alone, before the eye resolves any shape.
   The PaP icons are a dark navy mass with a small cyan patch.
2. **Two objects at half scale each, and one of them is finely detailed.** A
   chevron badge upper-left and a fist lower-right, the fist carrying knuckle
   lines and a thumb. At 39 px that detail is mud. Blink and heal are each a
   single flat geometric form with no internal detail to lose.
3. **The tier signal is a counting task.** Telling tier 2 from tier 3 requires
   resolving whether there are two or three small chevrons, roughly 8 px of the
   cell. On the true-size row all three tiers are indistinguishable. Counting
   is the wrong mechanism at this size.

## The tier does NOT need to be a number — the game already prints one

`AetheriumLoadout.lua` draws the level as a game-typeface DIGIT immediately
right of the glyph (`pap_row.set( tostring( t ), 12, PAP_X + 43, 592 )`). That
is the `1` visible in the user's screenshot. **The literal number is already on
screen and is not your job.** Do not bake a numeral, a roman numeral, or a
count of pips into the artwork; it would duplicate what the plate prints.

Your job is the thing the digit cannot do: make the tier readable
**pre-attentively** — recognisable from the corner of the eye without reading.
That means hue and silhouette mass, the two channels that survive at 39 px.

## The tier ladder: use the map's own colours

The map already has a five-step severity ladder used for its fifty floors, the
`DISTRICTS` table in `tools/gen_tower_map.js`: **cyan → green → orange → gold →
red**, climbing. Players spend a whole run learning it. Take a three-step slice
so the badge escalates the way the tower does, and so tier 1 agrees with the
cyan rule already on the PaP plate:

| tier | hue | hex | reads as |
|---|---|---|---|
| 1 | cyan | `#3FD8E8` | powered, baseline — matches the plate's own rule |
| 2 | gold | `#F5C542` | upgraded |
| 3 | red | `#F0524B` | maxed, hot, do-not-miss |

Cyan → gold → red also survives the common colour-vision deficiencies as a
lightness and warmth progression, which is why the silhouette must escalate
**as well** — see the next section. Do not use green for any tier: green is
the healing aura's identity on this same HUD row.

## What to draw

**ONE bold emblem per tier, flat, geometric, no representational detail** — the
same species of thing as a cross or an arrow, not a picture of a fist or a gun.
Blink and heal are the proof that an abstract symbol beats a depiction here.

The emblem should say "upgraded weapon power" without needing to depict a
weapon. Strong directions, in order of confidence:

- **A CHEVRON STACK AS THE WHOLE ICON.** Not chevrons beside an object — the
  chevron *is* the icon, drawn enormous, filling the cell. Tier 1 one fat
  chevron, tier 2 two, tier 3 three, each stack sized so the whole group always
  fills the same cell (so it is a shape change, not a counting task) and each in
  its tier hue. This is the most legible option and the safest.
- **A RISING BAR / POWER METER EMBLEM.** Three chunky ascending blocks; tier 1
  lights one, tier 2 two, tier 3 all three, with unlit blocks still drawn as
  dark sockets so the silhouette is identical and only the colour mass grows.
- **ONE FIST OR BOLT, ABSTRACTED HARD** — if you keep the Pack-a-Punch
  vocabulary, reduce it to a single unmistakable block form with no knuckles,
  no thumb, no internal lines, and let the tier hue plus a growing energy
  element carry the escalation. Riskier: three rounds have already failed here.

Whichever you choose, **the three must differ on BOTH axes at once**: hue AND
silhouette mass. Either alone has already been tried and failed.

## Hard numbers to hit

Judge against `docs/131_pap_ref/onscreen_row.png`, not against the 4x view.

- **Bright saturated pixels: at least 20% of inked pixels, target ~30%.** The
  quality bar is blink 20.2% and heal 38.3%. The current icons are 9%. This is
  the single most important number in this brief.
- **Ink coverage 44-50%** of the 128x128 cell, and an ink bounding box of at
  least 80%. The emblem fills the cell edge to edge.
- **No more than 5 tones carrying >=2% of the ink.** Flat fills with one
  highlight and one shadow step, exactly like blink and heal.
- **One emblem.** No second object, no separate badge, no corner element.
- **The house outline**: a heavy near-black keyline (`#0A1020`) around the whole
  emblem, the same weight blink and heal carry, so it holds on the plate.
- Stroke and gap minimum: nothing thinner than **8 px at 128x128**, because 8
  px becomes 2.4 px on screen. Anything finer will disappear.

## Deliverables

| filename | size | what |
|---|---|---|
| `i_tod_hud_pap_1.png` | 128x128 RGBA | TIER 1 emblem, cyan `#3FD8E8` |
| `i_tod_hud_pap_2.png` | 128x128 RGBA | TIER 2 emblem, gold `#F5C542` |
| `i_tod_hud_pap_3.png` | 128x128 RGBA | TIER 3 emblem, red `#F0524B` |

Transparent background — the plate shows through. Same three names as today, so
there is no wiring to do on our side.

## Install (when the drop returns)

`.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'`, look at every image, then
rebuild `docs/131_pap_ref/onscreen_row.png` with the delivered files in place
and judge THAT. Re-run `node tools/gen_pap_icon_ref.js` and confirm the
saturated-pixel row clears 20%. Then copy into
`source_data/tod_ui_images/_images/` and FULL build; proof is a fresh
content-hash `.iwi` beside an untouched control.

**Park the outgoing files first.** These images are NOT git tracked, so
whatever is in `_images/` is the only copy. Round 3's originals are already
parked at `docs/125_pap_ref/`; put round 3's at
`docs/131_pap_ref/_prev_shipped/` before overwriting.

<!-- PACK:BEGIN -->

# PACK-A-PUNCH TIER ICONS — three HUD emblems, round 4

## The deliverables

| filename | size | format | what |
|---|---|---|---|
| `i_tod_hud_pap_1.png` | 128 x 128 | PNG RGBA, transparent background | TIER 1 emblem, cyan |
| `i_tod_hud_pap_2.png` | 128 x 128 | PNG RGBA, transparent background | TIER 2 emblem, gold |
| `i_tod_hud_pap_3.png` | 128 x 128 | PNG RGBA, transparent background | TIER 3 emblem, red |

Exact filenames, exact size. They replace three existing files.

## What these are

A small status badge in the bottom-right of a zombies HUD that tells the player
how many times their weapon has been upgraded: tier 1, 2 or 3. It sits on a
dark plate, on the same row as two ability icons.

**They are drawn at 39 x 39 physical pixels on a 1080p screen.** Your 128 x 128
artwork is scaled down to roughly a third of its size. Everything in this brief
follows from that.

## The problem, in one sentence

The three icons shipping today are unreadable at that size and all three tiers
look identical, while the two ability icons beside them — attached as
`i_tod_hud_off_blink.png` and `i_tod_hud_off_heal.png` — read instantly.

**Open `reference/onscreen_row.png` first.** It shows all five icons at their
true on-screen size, in HUD order: blink, heal, then the three PaP tiers. The
first two are legible. The last three are three near-identical smudges.

## Why the good two work and the bad three do not — measured, not opinion

This is round 4. Three previous rounds delivered a capsule, then a pistol, then
a fist-and-lightning-bolt, and all three failed the same way. So please read
this section rather than starting from a new subject.

**It is not a size problem.** The PaP icon is given a 39 x 39 px box. Blink and
heal get a SMALLER box, 36 x 36 px, and win anyway. Do not deliver a bigger
canvas.

**It is not a matter of filling the cell.** Ink coverage is 43.3% average on
the bad three against 45.9% on the good two — effectively the same.

**It is a COLOUR problem, and it is large.** Share of inked pixels that are a
bright saturated colour:

| | blink | heal | pap 1 | pap 2 | pap 3 |
|---|---|---|---|---|---|
| bright saturated pixels | 20.2% | 38.3% | 7.2% | 9.2% | 10.7% |

Blink commits a third of its ink to purple; heal commits more than a third to
green. Each is identifiable by colour alone, before you resolve any shape. The
PaP icons are a dark navy mass with a small pale-blue patch — about 9%.

**And it is a COMPOSITION problem.** Each PaP icon crams in two objects at half
scale: a small chevron badge in the upper left and a fist in the lower right,
the fist carrying knuckle lines and a thumb. At 39 px that detail turns to mud.
For calibration: reviewing the current art at FOUR TIMES its size, studying it
deliberately, our own reviewer identified that fist as "a gun". Blink and heal
are each one flat geometric form with nothing small in them to lose.

**And the tier signal is a counting task.** Today, telling tier 2 from tier 3
means resolving whether there are two or three small chevrons in about 8 px of
the cell. That is why all three look the same on screen.

## You do not need to draw the number

The game already prints the level as a digit right next to your icon — that is
the `1` you can see beside the badge in the HUD. **Do not bake a numeral, a
roman numeral, or a row of counting pips into the artwork.** It would duplicate
what the game already draws.

Your job is what the digit cannot do: make the tier readable from the corner of
the eye, without reading. At this size only two channels survive — **colour**
and **overall silhouette mass**.

## The tier colours — please use these exact three

The game's fifty floors are colour-coded on a climbing ladder the player learns
over a whole run: cyan, green, orange, gold, red. Take a three-step slice of it
so the badge escalates the same way:

| tier | hue | hex |
|---|---|---|
| 1 | cyan | `#3FD8E8` |
| 2 | gold | `#F5C542` |
| 3 | red | `#F0524B` |

Tier 1's cyan also matches a cyan rule already printed on the plate the icon
sits on (attached as `i_tod_hud_pap_tile.png`).

**Do not use green for any tier** — green is the healing icon's identity on this
same HUD row, and a green PaP badge would be mistaken for it.

## What to draw

**ONE bold emblem per tier. Flat, geometric, no representational detail.** The
same kind of thing as a cross or an arrow — not a picture of a fist, a gun or a
machine. The two icons you are matching are proof that an abstract symbol beats
a depiction at this size.

It should communicate "upgraded weapon power" without depicting a weapon. Three
directions, most-recommended first:

**A — THE CHEVRON STACK (recommended).** The chevron IS the icon, not a detail
beside something else. Draw it enormous, filling the cell. Tier 1 is one fat
chevron, tier 2 is two, tier 3 is three — but size each stack so the GROUP
always fills the same cell, so the difference reads as a change of shape and
density rather than as something to count. Each in its tier hue.

**B — THE POWER METER.** Three chunky ascending blocks or bars. Tier 1 lights
one, tier 2 two, tier 3 all three; unlit blocks are still drawn as dark sockets
so the silhouette is identical across the three and only the colour mass grows.

**C — AN ABSTRACTED FIST OR BOLT.** If you want to keep the Pack-a-Punch
vocabulary, reduce it to a single unmistakable block form — no knuckles, no
thumb, no internal lines — and let the tier hue plus a growing energy element
carry the escalation. This is the riskiest option; three rounds have already
failed in this direction.

Whichever you pick, **the three tiers must differ on BOTH axes at once: colour
AND silhouette mass.** Either one alone has already been tried and has failed.

## Hard rules

- **Bright saturated colour: at least 20% of your inked pixels, aim for 30%.**
  The bar is blink at 20.2% and heal at 38.3%. Today's icons are 9%. This is the
  single most important number here.
- **Ink coverage 44-50%** of the 128 x 128 cell, with the artwork's bounding box
  covering at least 80% of it. Fill the cell edge to edge.
- **At most 5 flat tones** carrying 2% or more of the ink: a base, one
  highlight, one shadow, the outline. No gradients, no glows, no soft shadows,
  no bevels, no texture.
- **ONE emblem.** No second object, no corner badge, no separate element.
- **Heavy near-black outline** `#0A1020` around the whole emblem, matching the
  weight on blink and heal, so it holds against the plate.
- **Nothing thinner than 8 px** anywhere — strokes, gaps, or internal shapes.
  8 px at 128 becomes 2.4 px on screen; anything finer vanishes.
- Transparent background. The plate shows through behind your emblem.
- No text, no numerals, no letters of any kind.

## Paste-ready prompts

### Prompt 1 — the three tier emblems

> Attach `reference/onscreen_row.png`, `reference/pap_vs_offhand.png`,
> `reference/i_tod_hud_off_blink.png`, `reference/i_tod_hud_off_heal.png`,
> `reference/i_tod_hud_pap_1.png`, `reference/i_tod_hud_pap_2.png`,
> `reference/i_tod_hud_pap_3.png`, `reference/i_tod_hud_pap_tile.png`.
>
> For extra context on the house style, also attach
> `reference/i_tod_hud_off_monkey.png` and `reference/i_tod_hud_off_frag.png`
> (two more icons from the same HUD row, same box — more examples of the
> treatment to match), `reference/i_tod_hud_offhand_tile.png` (the plate blink
> and heal sit on, so you can see the PaP plate is the same chassis), and
> `reference/i_tod_pu2_free_pap.png` (the game's own Pack-a-Punch power-up icon
> — useful only as subject vocabulary; its gradient and its yellow are both
> banned in this brief).
>
> I need three HUD status icons for a zombies game, 128x128 PNG RGBA with
> transparent backgrounds, named `i_tod_hud_pap_1.png`, `i_tod_hud_pap_2.png`
> and `i_tod_hud_pap_3.png`. They show how many times a weapon has been
> upgraded: tier 1, tier 2, tier 3.
>
> They are displayed at only 39x39 pixels on screen. Look at
> `onscreen_row.png`: it shows, at true on-screen size, two icons that work
> (a purple arrow, a green cross — `i_tod_hud_off_blink.png` and
> `i_tod_hud_off_heal.png`) followed by the three I want to replace, which are
> unreadable and identical to each other.
>
> Match the quality of the purple arrow and the green cross: ONE bold flat
> geometric emblem per icon, filling the cell, a heavy near-black `#0A1020`
> outline, at most five flat tones, no gradients or glows, and a big committed
> mass of saturated colour — at least 20% of the inked pixels, ideally 30%. The
> icons I am replacing are only 9% saturated and that is their main failure.
>
> Draw the chevron stack direction: the chevron IS the whole icon, drawn
> enormous. Tier 1 one fat chevron, tier 2 two, tier 3 three, with each stack
> sized so the group always fills the same cell — the difference should read as
> shape and density, not as something to count. Tier 1 cyan `#3FD8E8`, tier 2
> gold `#F5C542`, tier 3 red `#F0524B`. No green anywhere — green means healing
> on this HUD.
>
> No text, no numbers, no roman numerals: the game prints the level as a digit
> beside the icon already. One emblem only, no second object or corner badge.
> Nothing thinner than 8 pixels anywhere.
>
> Before sending, shrink all three to 39x39 and put them in a row beside the
> purple arrow and green cross. If the three tiers are not instantly
> distinguishable from each other at that size, they are not done.

### Prompt 2 — if you want to offer alternatives

> Same rules and same three files as Prompt 1, but give me the POWER METER
> direction instead: three chunky ascending blocks per icon, tier 1 lighting
> one, tier 2 two, tier 3 all three, with the unlit blocks still drawn as dark
> sockets so all three icons share one silhouette and only the lit colour mass
> grows. Same tier hues, same hard rules, same 39x39 self-check.

### Prompt 3 — self-check before sending

> Check each of the three icons against this list and fix anything that fails:
>
> 1. Shrink to 39x39. Can you tell the three tiers apart instantly, without
>    counting anything?
> 2. At 39x39, is each one still recognisable as a deliberate symbol rather
>    than a smudge?
> 3. Is at least 20% of each icon's inked pixels a bright saturated colour?
> 4. Is there exactly ONE emblem in each, with no second object or corner
>    badge?
> 5. Five or fewer flat tones? No gradient, glow, bevel or soft shadow
>    anywhere?
> 6. Is every stroke, gap and internal shape at least 8 pixels?
> 7. Heavy near-black outline around the whole emblem?
> 8. Exactly 128x128, RGBA, transparent background, correct filename?
> 9. No text, numerals or roman numerals anywhere?
> 10. Tier 1 cyan, tier 2 gold, tier 3 red, and no green in any of them?

## Delivery

- Exactly three PNG files, the three filenames above, 128x128 RGBA.
- A contact sheet is welcome: the three at 4x, plus the three shrunk to 39x39
  in a row beside the purple arrow and green cross. That row is how they will
  be judged.
- Please do not rename, resize, or add extra variants under other names.

## Checklist before you send

1. Three files, named exactly `i_tod_hud_pap_1.png`, `i_tod_hud_pap_2.png`,
   `i_tod_hud_pap_3.png`.
2. All 128x128, RGBA, transparent background.
3. Tiers instantly distinguishable at 39x39.
4. At least 20% saturated colour in each.
5. One emblem each, no second object.
6. Five or fewer flat tones, no gradients or glows.
7. Nothing thinner than 8 px.
8. Heavy near-black outline on all three.
9. Tier 1 cyan, tier 2 gold, tier 3 red; no green.
10. No text or numerals.

## Do NOT

- Do NOT bake in a number, roman numeral, or a row of counting pips — the game
  draws the level digit itself, right beside your icon.
- Do NOT deliver a larger canvas or ask for a bigger box. The icon already gets
  more room than the two icons it is losing to.
- Do NOT put two objects in the cell. That is the current failure.
- Do NOT use gradients, glows, bevels, drop shadows or texture.
- Do NOT use green in any tier.
- Do NOT draw a detailed fist, gun or machine. Detail dissolves at 39 px.
- Do NOT distinguish the tiers by colour alone, or by silhouette alone. Both.
- Do NOT rename the files or change their dimensions.

<!-- PACK:END -->
