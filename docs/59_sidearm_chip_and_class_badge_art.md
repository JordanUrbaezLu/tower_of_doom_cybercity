# 59 — SIDEARM CHIP + CLASS BADGE: art prompts (16 images)

> **STATUS: BOTH JOBS SHIPPED 2026-09-01. JOB A 04:41, JOB B 12:07.**
>
> **Job B** (4 class badge plates, `files (82).zip`): installed, wired and packed
> — FULL build, .ff 115.82 MB @ 12:07:54, exactly 4 fresh content-hash `.iwi`
> with `i_tod_card_luck_regular`, `i_tod_tier_gate_2` and `i_tod_badge_luck_50`
> cold. Wiring landed as specced in §6: 4 GDT blocks (braces 312 -> 316), 4 zone
> lines, `#precache` + the class push in `_tod_upgrades.gsc`, and the Lua badge,
> receiver and moved tier-gate rect. `push_tier_hint()` was renamed
> `push_panel_hints()` — it pushes two facts now. Zero clientuimodel bits spent.
> Freshness diff empty on scripts/ + zone_source/ + ui/, taken with nobody having
> synced after the .ff (see §11).
>
> **Job A** (12 sidearm-chip cards, `files (80).zip`): installed and packed — FULL build, .ff
> 115.72 MB, exactly 12 fresh content-hash `.iwi` with three untouched controls
> cold (`i_tod_card_luck_regular` Aug 20, `i_tod_card_cleave_regular` Aug 22,
> `i_tod_badge_luck_50` Aug 20). Zero wiring was needed: same filenames, so every
> GDT block and zone line already existed.
>
> **The sidearm name in the tier cards' subline is INTENTIONAL** (user,
> 2026-09-01: *"The secondary under the primary was intentional. lets just use
> those"*). §10 called it a regression before that call; it is not one. The cost
> is real and is recorded there: the tier cards no longer carry `NEW WEAPON ·
> GUN UPGRADES RESET`, so the deal screen no longer warns that a promotion wipes
> gun upgrades. The pause menu reset badges still do.
>
> **BOTH §10 ITEMS ARE NOW FIXED** — corrected card set (`files (83).zip`)
> installed and built 2026-09-01 13:22, .ff 115.94 MB, 12 fresh `.iwi`, freshness
> diff clean. The per-class outer glow is restored on all eight tier cards
> (measured: skirmisher `rgb(93,225,255)`, assault `rgb(248,203,109)`, heavy
> `rgb(248,125,118)`, slasher `rgb(202,148,255)` — within 1-3 units of the
> originals), the twelve chip silhouettes are redrawn to be tellable apart at
> their real 60px, and `tier_slasher_2` says **KATANA** again. The sidearm name
> in the tier sublines is untouched, as intended.
>
> **That settles WAKIZASHI/KATANA by moving the ART, not the strings** — all four
> player-visible sources now agree on KATANA with no code change, and the peer
> session cancelled its parked rename rather than re-creating the mismatch
> inverted. General rule worth keeping: asset identity and display name may
> differ; four places disagreeing may not, and when they diverge the BAKED ART
> decides because art is the expensive half.
>
> §6 remains the record of what job B's wiring was, and §10 the audit of the
> card drop.

Two user asks, 2026-09-01:

> *"We need another upgrade for all of these that shows a small image of the
> secondary along side the primary"*
> *"players also want an update to the upgrade menu that shows what class you
> are playing as"*

**Every coordinate and every current value in this doc was measured by decoding
the shipped PNGs**, not read out of an older prompt doc. `docs/26`, `docs/33`
and `docs/35` are all stale in places — `docs/33` in particular still certifies
the class card set as "verified current", which §4 disproves.

---

## 0. The whole job at a glance

| # | files | kind | wiring needed? |
|---|---|---|---|
| **A1** | 4 × `i_tod_card_class_*.png` | re-bake: **+ sidearm chip** | none |
| **A2** | 8 × `i_tod_card_tier_*_<2\|3>.png` | re-bake: **+ sidearm chip** | none |
| **A3** | `i_tod_card_class_slasher.png` | **also** one text line (§4) | none |
| **B** | 4 × `i_tod_upg_class_*.png` | **NEW ART** | yes — §6 |

**A1/A2/A3 are one bake of 12 files** (A3 is a second change to one of the 12,
not a 13th file). **An image change is ALWAYS a FULL build**, never `-GscOnly`.

---

## 1. Card anatomy (shared by all 12), as measured

768 × 1152 RGBA, transparent outside the card's rounded body. Top to bottom:

1. **Title plate** — amber gradient lozenge. Class cards read `SKIRMISHER` /
   `ASSAULT` / `HEAVY` / `SLASHER`; tier cards read `TIER 2` / `TIER 3`.
2. **Illustration panel** — dark navy inset with a blue gradient, flat vector
   weapon art, thick black outlines. Tier cards carry faint amber chevron
   watermarks behind the weapon; class cards do not. **Keep that difference.**
3. **Medal** — straddles the panel's **lower-right** corner. Class cards: a
   silver star disc. Tier cards: a white disc reading `TIER 2` / `TIER 3`.
4. **Ribbon** — class cards a green `CLASS` banner; tier cards a class-accent
   banner reading the class name.
5. **Name plate** — the weapon name in the class accent colour, plus a subline.
6. **Pips** — a row of dots at the bottom. Tier cards: 3 dots, 2 lit on a
   TIER 2 card, 3 lit on a TIER 3. Class cards: 3 short dashes.

Measured rects (canvas px):

| element | tier cards | class cards |
|---|---|---|
| illustration panel, inner | x 112–623, y 240–688 | x 128–607, y 240–690 |
| medal bounding box | x 528–639, y 624–704 | x 496–623, y 624–704 |

**Display scale is the constraint on every decision below.** The art is
768 wide and is drawn at **234 px** on the deal panel and **210 px** on the
class draft — 0.305× and 0.273×. A 34 px cap height in the art lands at ~15 real
px on a 1080p screen. That is why the chip in §3 carries **no weapon name**:
there is no rect inside it where a name would survive the downscale, and the
set already has one legibility complaint on record (user 2026-08-27, "Some have
text that is so hard to read" — the comment above `CARD_Y0` in `tod_upgrade.lua`).

---

## 2. The twelve sidearms

Source of truth: the `TOD_SEC_*` defines in
`scripts/zm/zm_tower_of_doom/_tod_classes.gsc:99-110`. **Read them there, not
here, if this doc is more than a build old.**

| class | tier | sidearm | what it looks like |
|---|---|---|---|
| SKIRMISHER | 1 | AW Bulldog | stubby futuristic pump shotgun — boxy angular receiver, short fat barrel, chunky fore-grip, no stock |
| SKIRMISHER | 2 | SG12 | compact full-auto shotgun — straight box magazine below, top rail, short vented barrel |
| SKIRMISHER | 3 | SPAS-12 | heavy combat shotgun — perforated heat shield over the barrel, folding skeleton hook stock |
| ASSAULT | 1 | CW Magnum | large revolver — long barrel, fat exposed cylinder, curved grip, hammer spur |
| ASSAULT | 2 | MOG 12 | classic pump shotgun — long tube magazine under the barrel, wood-look pump handle and stock |
| ASSAULT | 3 | Executioner | revolver-shotgun — short stubby barrel, oversized cylinder full of fat shells |
| HEAVY | 1 | MR6 pistol | plain modern service pistol — boxy slide, straight grip |
| HEAVY | 2 | RPG | rocket launcher — long straight tube, conical warhead at the front, pistol grip, flared rear blast cone |
| HEAVY | 3 | Nail Gun | industrial nail gun — chunky body, angled nail magazine, short blunt nose |
| SLASHER | 1 | AMP63 | blocky machine pistol — squared-off slide, extended straight magazine |
| SLASHER | 2 | UDM 45 | sleek futuristic machine pistol — smooth curved slide, long magazine |
| SLASHER | 3 | RK7 Garrison | angular full-auto pistol — polymer frame, extended magazine, small red-dot on top |

The class cards are tier 1, so they take their class's **tier-1** row. The
`_2` / `_3` tier cards take the matching tier row.

---

## 3. The sidearm chip

**A rounded square straddling the illustration panel's LOWER-LEFT corner —
the exact mirror of the medal that already straddles the lower-right.** Square,
not a disc, so it can never be misread as a rarity or tier medal.

| part | rect (canvas px) | content |
|---|---|---|
| chip body | **x 96–296, y 554–704** (200 × 150, corner radius 20) | navy fill one shade darker than the panel, 5 px black outline, 3 px class-accent inner rim |
| header strip | x 96–296, y 554–592 | the word **`2ND`**, 34 px caps, centred, white on a dim slate band |
| silhouette cell | x 108–284, y 598–694 | the sidearm, fitted, **muzzle pointing right** |

The chip's bottom edge (704) is deliberately level with the medal's (704), so
the two corner elements read as a pair.

**The primary illustration must be nudged or scaled so nothing collides with the
chip.** On most of the twelve the lower-left is already clear; the slasher tier
cards (blade running corner to corner) and the heavy class card (ammo belt
hanging down at x 176–224, y 480–640) are the two that need the most give. The
primary stays the hero: it should still read at least 2.5× the chip.

Everything else on the card is **untouched** — title plate, medal, ribbon, name
plate, subline, pips, chevron watermarks, palette, fonts.

---

## 4. ⚠️ THE SLASHER CLASS CARD ALSO CARRIES A LIE — fix it in this bake

`i_tod_card_class_slasher.png` reads **`COMBAT KNIFE / FASTEST ON THE TOWER`**.

That went false on 2026-08-30 (v14.29), when the user swapped the skirmisher and
slasher base speeds. `class_speed_base()` in `_tod_upgrades.gsc:2033` is now
**heavy 0.80 · assault 0.9 · slasher 1.0 · skirmisher 1.1** — the SMG class is
the fastest thing in the map and the knife is not.

| file | current subline | **new** |
|---|---|---|
| `i_tod_card_class_slasher.png` | `FASTEST ON THE TOWER` | **`CLEAVE AND LIFE LEECH`** |

**The replacement states no value and no superlative, deliberately.** A
superlative is exactly as fragile as a number — this one survived two days
because the class speeds moved twice in that window, and nothing re-checks baked
art. `CLEAVE AND LIFE LEECH` names two domains that exist and are slasher-scoped
(`_tod_upgrades.gsc:1090` and `:1100`, both re-read 2026-09-01), which is the
same grammar the skirmisher card already uses when it says `RUN AND GUN`. The
only thing that can stale it is retiring one of those two domains — a much rarer
event than a tuning pass.

The other three class cards' sublines are correct and must not change:
`RUN AND GUN` (skirmisher — also the name of its exclusive domain),
`BALANCED RIFLEMAN` (assault), `SLOW AND DEVASTATING` (heavy).

The Lua fallback copy in `tod_class_select.lua:46` was updated when the speeds
swapped, but `USE_CLASS_CARD_ART = true` blanks that whole text stack — the
baked line is what players actually read, which is why the fallback being
right fixed nothing.

---

## 5. The class badge (job B)

**Where:** the upgrade panel's top-left gutter, `x 50–330, y 150–210` — the
exact mirror of the LUCK badge at `x 950–1230`. Drawn 280 × 60 from a 420 × 90
source, same as the luck badge and the tier gate strip.

**Why there:** the panel already carries a badge on the right and nothing on the
left, and the class is a standing fact about the player, not a per-card one.

| file | reads |
|---|---|
| `i_tod_upg_class_skirmisher.png` | CLASS SKIRMISHER |
| `i_tod_upg_class_assault.png` | CLASS ASSAULT |
| `i_tod_upg_class_heavy.png` | CLASS HEAVY |
| `i_tod_upg_class_slasher.png` | CLASS SLASHER |

Class accents (from `tod_class_select.lua:32-47`, the one source):

| class | accent | hex |
|---|---|---|
| SKIRMISHER | cyan | `#33D9FF` |
| ASSAULT | amber | `#FFBF40` |
| HEAVY | red | `#FF594D` |
| SLASHER | purple | `#BF73FF` |

---

## 6. Wiring checklist for job B (art without these renders as nothing)

**Zero clientuimodel bits.** The pool is at **60 of its PROVEN 61** — a new
field is not affordable. The class rides the int-only `LuiNotifyEvent` lane,
exactly as `tod_upg_tier_need` does (`_tod_upgrades.gsc:3873`).

1. **Art** — 4 PNGs into `source_data/tod_ui_images/_images/`, 420 × 90 RGBA.
2. **GDT** — 4 blocks in `source_data/tod_ui_images.gdt`; copy the
   `i_tod_tier_gate_2` block verbatim, change the name and `baseImage` only.
3. **Zone** — 4 `image,i_tod_upg_class_*` lines in
   `zone_source/zm_tower_of_doom.zone`, beside the existing `image,i_tod_tier_gate_2`.
4. **GSC** — `_tod_upgrades.gsc`:
   - `#precache( "eventstring", "tod_upg_class" );` beside the `tod_upg_tier_need`
     precache at `:652`.
   - one line inside `push_tier_hint()` (`:3873`):
     `self LuiNotifyEvent( &"tod_upg_class", 1, tod_classes::class_id( self.tod_class ) );`
     `class_id()` returns **0** for a classless player, which the Lua reads as
     "hide the plate", so the pre-draft case needs no special handling.
   - **Rename that function `push_panel_hints()`** — it will no longer push only
     the tier line, and there are exactly **two** call sites (`:3078` the round
     event, `:6066` the personal station). Both presenters owe both pushes; a
     third presenter must call it too.
5. **Lua** — `tod_upgrade.lua`:
   - `local USE_CLASS_BADGE_ART = true` + `art.classPlate[1..4] = RegisterImage(...)`.
   - a `ClassBadge` UIImage at `50, 330, 150, 210`, alpha 0 by default.
   - receiver branch beside the `tod_upg_tier_need` one (`:2426`):
     `elseif ... == "tod_upg_class" then CoD.TodClass = d[1] or 0`.
   - on paint: `CoD.TodClass` in 1..4 → set image, alpha 1; else alpha 0.
   - ⚠️ **MOVE THE TIER GATE STRIP'S NO-CARD SLOT.** It currently falls back to
     `50, 330, 150, 210` (`:1573`) — the same rect. Move that fallback to
     `50, 330, 216, 276`, one row down, so the two stack instead of colliding.
     Its other position (under a locked card B, `654, 934, 336, 396`) is fine.
6. **Build** — FULL. New images, GDT and zone lines.

`CoD.TodClass` is a plain global on the client, so the pause menu
(`AetheriumStartMenu.lua`) and the scoreboard can read it later for free, the
same way they already read `CoD.TodOwned`.

---

## 7. THE PROMPT — job A (paste to the image agent, 12 files)

> You are revising a set of weapon cards for a Call of Duty: Black Ops III
> custom zombies map. **This is an ADDITIVE revision.** Reproduce each card
> exactly as it already is and change ONLY what this brief names. Do not
> redraw, restyle, recolour, re-crop or "improve" the frame, the title plate,
> the ribbon, the medal, the name plate, the subline or the pips.
>
> **Open these files first — they are both the target style and the target
> artwork.** Output at the exact same filenames, overwriting:
> `source_data/tod_ui_images/_images/i_tod_card_class_skirmisher.png`
> `…/i_tod_card_class_assault.png`
> `…/i_tod_card_class_heavy.png`
> `…/i_tod_card_class_slasher.png`
> `…/i_tod_card_tier_skirmisher_2.png`
> `…/i_tod_card_tier_skirmisher_3.png`
> `…/i_tod_card_tier_assault_2.png`
> `…/i_tod_card_tier_assault_3.png`
> `…/i_tod_card_tier_heavy_2.png`
> `…/i_tod_card_tier_heavy_3.png`
> `…/i_tod_card_tier_slasher_2.png`
> `…/i_tod_card_tier_slasher_3.png`
>
> **Format:** 768 × 1152 RGBA PNG, transparent outside the card's rounded body.
>
> **Card anatomy (all of this stays):** amber title plate at the top · dark navy
> illustration panel with flat vector weapon art and thick black outlines · a
> medal straddling the panel's lower-right corner (a silver star on the four
> class cards, a white `TIER 2`/`TIER 3` disc on the eight tier cards) · a
> ribbon · a name plate with the weapon name in the class accent colour and a
> smaller white subline · a row of pips at the bottom. The eight tier cards have
> faint amber chevron watermarks inside the illustration panel; the four class
> cards do not. **Keep that difference.**
>
> **THE ADDITION — a SIDEARM CHIP on every one of the twelve.** It straddles the
> illustration panel's **lower-LEFT** corner as the exact mirror of the medal
> that straddles the lower-right, and it is a rounded SQUARE so it can never be
> mistaken for a medal:
>
> - **Chip body:** x 96–296, y 554–704 in the 768 × 1152 canvas (200 × 150,
>   corner radius 20). Navy fill one shade darker than the illustration panel,
>   5 px black outline, 3 px inner rim in that card's class accent colour.
> - **Header strip:** x 96–296, y 554–592 — the word `2ND` in white caps, 34 px
>   cap height, centred, on a dim slate band.
> - **Silhouette cell:** x 108–284, y 598–694 — the sidearm, fitted to the cell,
>   **muzzle pointing right**, drawn in the same flat vector style as the main
>   weapon: thick black outline, dark body, one highlight detail in the class
>   accent colour. Simplified — it is one sixth the size of the main weapon and
>   must read as a silhouette, not as a detailed illustration.
> - **No text inside the chip other than `2ND`.** Do not add the sidearm's name;
>   the card is drawn at 234 px wide in game and a name would be illegible.
> - **Move or scale the main weapon illustration as needed so it does not
>   collide with the chip**, but keep it the hero of the panel — at least 2.5×
>   the chip. The slasher tier cards (blade corner to corner) and the heavy
>   class card (ammo belt hanging into the lower left) need the most give.
>
> **Which sidearm goes on which card** — one per file, no substitutions:
>
> | file | sidearm | draw it as | accent |
> |---|---|---|---|
> | `card_class_skirmisher` | AW Bulldog | stubby futuristic pump shotgun: boxy angular receiver, short fat barrel, chunky fore-grip, no stock | cyan |
> | `card_tier_skirmisher_2` | SG12 | compact full-auto shotgun: straight box magazine below, top rail, short vented barrel | cyan |
> | `card_tier_skirmisher_3` | SPAS-12 | heavy combat shotgun: perforated heat shield over the barrel, folding skeleton hook stock | cyan |
> | `card_class_assault` | Magnum | large revolver: long barrel, fat exposed cylinder, curved grip, hammer spur | amber |
> | `card_tier_assault_2` | MOG 12 | classic pump shotgun: long tube magazine under the barrel, wood-look pump handle and stock | amber |
> | `card_tier_assault_3` | Executioner | revolver-shotgun: short stubby barrel, oversized cylinder full of fat shells | amber |
> | `card_class_heavy` | MR6 pistol | plain modern service pistol: boxy slide, straight grip | red |
> | `card_tier_heavy_2` | RPG | rocket launcher: long straight tube, conical warhead at the front, pistol grip, flared rear blast cone | red |
> | `card_tier_heavy_3` | Nail Gun | industrial nail gun: chunky body, angled nail magazine, short blunt nose | red |
> | `card_class_slasher` | AMP63 | blocky machine pistol: squared-off slide, extended straight magazine | purple |
> | `card_tier_slasher_2` | UDM 45 | sleek futuristic machine pistol: smooth curved slide, long magazine | purple |
> | `card_tier_slasher_3` | RK7 Garrison | angular full-auto pistol: polymer frame, extended magazine, small red-dot on top | purple |
>
> Class accent colours: cyan `#33D9FF`, amber `#FFBF40`, red `#FF594D`,
> purple `#BF73FF`. Each card already uses its class's accent — match it.
>
> **ONE TEXT CHANGE, ON ONE FILE ONLY.** On `i_tod_card_class_slasher.png`,
> the white subline under `COMBAT KNIFE` currently reads `FASTEST ON THE TOWER`.
> Change it to **`CLEAVE AND LIFE LEECH`**, same font, size, weight, colour and
> baseline. The weapon name `COMBAT KNIFE` above it does not change. **The other
> eleven cards keep every word they have** — the tier cards' `NEW WEAPON ·
> GUN UPGRADES RESET` and the class cards' `RUN AND GUN`, `BALANCED RIFLEMAN`
> and `SLOW AND DEVASTATING` are all correct.
>
> **Do not** change any weapon name, any pip count or which pips are lit, the
> medal, the ribbon colour, the title plate, or the transparent margin.

---

## 8. THE PROMPT — job B (paste to the image agent, 4 new files)

> You are making four new badge plates for the upgrade menu of a Call of Duty:
> Black Ops III custom zombies map. They must sit in a set with two plates that
> already exist and read as siblings of them.
>
> **Open these two first — they are the chassis:**
> `source_data/tod_ui_images/_images/i_tod_badge_luck_50.png`
> `source_data/tod_ui_images/_images/i_tod_tier_gate_2.png`
>
> **Format:** 420 × 90 RGBA PNG, transparent outside the plate. Drawn in game at
> 280 × 60, so every element must survive a 1.5× reduction — check it before
> delivering.
>
> **Chassis (copy it):** a horizontal capsule with a dark navy fill and a rounded
> outline, a circular emblem disc overlapping the LEFT end and breaking the
> capsule's outline, and text filling the rest. A soft outer glow in the plate's
> own colour. The luck badge's text is heavy white slab caps with a dark
> outline; match that weight — it is the plate this one sits opposite, and the
> two are seen together every time the panel opens.
>
> **Text:** the word `CLASS` in white, then the class name in that class's accent
> colour, on one line, left-aligned after the disc — `CLASS SKIRMISHER`. Fill
> the available width; this reads at 40 real px on a 1080p screen, so it should
> be confident, not timid.
>
> **Four files, one per class.** Capsule outline, glow, emblem and class name all
> take the class accent colour:
>
> | file | text | accent | emblem on the left disc |
> |---|---|---|---|
> | `i_tod_upg_class_skirmisher.png` | CLASS SKIRMISHER | cyan `#33D9FF` | a running figure carrying a submachine gun |
> | `i_tod_upg_class_assault.png` | CLASS ASSAULT | amber `#FFBF40` | a chevron above an assault rifle |
> | `i_tod_upg_class_heavy.png` | CLASS HEAVY | red `#FF594D` | a light machine gun with a muzzle-blast arc |
> | `i_tod_upg_class_slasher.png` | CLASS SLASHER | purple `#BF73FF` | a dagger crossed by a slash arc |
>
> The four emblems already exist as flat single-colour icons in this map — open
> `i_tod_class_skirmisher.png`, `i_tod_class_assault.png`, `i_tod_class_heavy.png`
> and `i_tod_class_slasher.png` in the same folder and use those shapes, redrawn
> to sit cleanly inside a circular disc.
>
> All four plates must be pixel-identical apart from colour, emblem and class
> name — same capsule, same disc size and position, same baseline, same text
> size. They are seen one at a time but must never look like four different
> designs.

---

## 9. The lockstep this creates

**The twelve cards now carry a SECOND weapon identity.** Before this change,
`docs/33` could truthfully say *"no card, class card or tier card carries a
weapon stat"* — a sidearm swap was invisible to the art. It no longer is.

If any `TOD_SEC_*` define in `_tod_classes.gsc:99-110` changes, **that card must
be re-baked in the same commit**, exactly as a primary swap already forces one.

**THE CONSTRAINT RUNS BOTH WAYS, and the shipped art made it stricter than this
section originally said.** As specced, the chip carried a picture and no name, so
a swap inside one weapon family (one pump shotgun for another) would have been
survivable and only a cross-family swap (shotgun → launcher) would have read as a
lie. **The delivered tier cards NAME the sidearm in the subline** — `SG12`,
`SPAS-12`, `MOG 12`, `EXECUTIONER`, `RPG`, `NAIL GUN`, `UDM 45`, `RK7` — which
the user confirmed was intentional. So:

- **code → art:** changing a `TOD_SEC_*` row makes that card's printed name
  wrong. There is no survivable swap any more; every swap is a re-bake.
- **art → code:** the twelve names baked into the cards are now a spec the code
  has to satisfy. Re-baking a card with a different name silently makes the
  weapon table the thing that is wrong.

Nothing mechanically checks either direction. `tools/verify_armory_constants.js`
and `tools/verify_armory_domains.js` cover the armory page only, and no tool in
this repo can read a PNG.

### INSTALL STEP — the comment goes in the CODE, not only here

The person who retunes a sidearm is reading the `TOD_SEC_*` table, not this doc.
So **when the twelve cards install, and not before**, add a line above
`_tod_classes.gsc:99`:

```
// ⚠️ THESE TWELVE ARE DRAWN ON THE CLASS/TIER CARDS (the "2ND" chip, docs/59).
// Changing a row here forces a re-bake of that class's cards — a swap inside
// one weapon family survives, a swap across families (shotgun -> launcher)
// makes the art lie. Nothing checks this; no tool here can read a PNG.
```

**Not before**, deliberately: until the chips ship, that comment describes art
that does not exist, and a comment that is wrong about today is the exact failure
this whole doc exists to prevent.

---

## 10. DROP 1 AUDIT — `files (80).zip`, 2026-09-01 04:18

**12 of 16 files.** The 4 class badge plates (`i_tod_upg_class_*`) were not in
the drop, so job B is still unstarted. All 12 cards are 768×1152, bit depth 8,
colour type 6 (RGBA) — verified from the PNG headers.

**Correct, and worth keeping:**

- The chip landed on all 12 at the specified lower-left corner, with the `2ND`
  header strip. Region diff against the shipped cards is ~24 in the chip rect on
  every file.
- The right sidearm is on the right card, all twelve.
- `i_tod_card_class_slasher.png` subline is now `CLEAVE AND LIFE LEECH`.
- The four class cards are otherwise **byte-identical** in the title plate,
  medal and name plate regions (diff 0.0) — nothing drifted.
- Pip counts and lit-pip counts unchanged.

**Three regressions, all 8 TIER cards. Measured, not eyeballed:**

| # | what happened | evidence |
|---|---|---|
| 1 | The subline `NEW WEAPON · GUN UPGRADES RESET` was **replaced by the sidearm name** (`SG12`, `SPAS-12`, `MOG 12`, `EXECUTIONER`, `RPG`, `NAIL GUN`, `UDM 45`, `RK7`) | name-plate region diff 21–36 on all 8; 0.0 on the three unchanged class cards |
| 2 | The class-keyed outer glow was **flattened to one red** `rgb(255,55,46)` on all 8 | glow band sampled at x 6–26, y 400–800: was skirmisher `rgb(94,228,255)`, assault `rgb(248,205,112)`, heavy `rgb(248,128,121)`, slasher `rgb(203,150,255)` |
| 3 | `i_tod_card_tier_slasher_2` renamed the primary `KATANA` → `WAKIZASHI` | read off the card |

**Regression 1 is the serious one.** That subline is the only place the deal
screen warns a player that taking the tier card wipes their gun upgrades — the
user asked for that warning explicitly on 2026-08-27. Losing it to make room for
a sidearm name trades a safety line for a decoration.

**On regression 3 — the shipped card was RIGHT and the "correction" is wrong.**
`KATANA` is this map's deliberate display name for the `t9_me_wakizashi` asset:
`tod_upgrade.lua` `TIER_LADDER[4][2]`, `tod_class_select.lua`'s
`KNIFE > KATANA > STORMBREAKER`, and `CREDITS.md` ("pmr360 — BOCW Wakizashi
(KATANA)") all agree. Asset name ≠ display name. Re-bake it back rather than
changing three strings to match the art.

**Quality note, all 12 — the silhouettes are too generic.** The chip carries no
name, so the silhouette *is* the information, and at the chip's on-screen size
the four pistols and three shotguns all render as the same small bar. The RPG
(tube + cone), Executioner (cylinder + dots) and Nail Gun (angled body) are the
three that read. Second pass should lean on one distinctive feature per weapon
rather than drawing an accurate small gun.

---

## 11. An empty freshness diff does not always mean what you think

Learned live, 2026-09-01, with three sessions in one repo (found by
`tower-of-doom-cybercity-ad`; recorded here because job B is where it bit).

`build_map.ps1` **syncs at the START of a build**. So the deployed tree reflects
whoever synced most recently — not necessarily whoever built most recently.

> **An empty `diff -rq scripts zone_source ui` only speaks to YOUR build if
> nobody has synced since your `.ff` was written.**

A peer starting a build after yours overwrites the deployed tree with THEIR
state, and your diff silently becomes a statement about their build-in-progress.
It still returns empty. It is still useless to you.

The cheap fix, run alongside the diff:

```
find <deployed>/scripts <deployed>/ui <deployed>/zone_source -type f \
     -newermt "<your .ff's timestamp>" | grep -v -E "/all/|/english/|/loc/"
```

Empty means nobody has synced since your build, so the diff is about your `.ff`.
Non-empty means re-verify after the other build lands, or your check is
answering someone else's question.

Job B's verification was taken this way: diff empty, post-build sync check empty.
