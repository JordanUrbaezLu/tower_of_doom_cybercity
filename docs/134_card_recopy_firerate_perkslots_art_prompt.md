# 134 — FIRE RATE + PERK SLOTS card re-copy (value plates only, 6 images)

<!-- art-pack
name: card_recopy_firerate_perkslots
refs:
  i_tod_card_fire_rate_regular.png | THE SOURCE for FIRE RATE regular. Reproduce exactly; only the value plate changes. Attach to Prompt A.
  i_tod_card_fire_rate_super.png | THE SOURCE for FIRE RATE super. Purple treatment. Attach to Prompt B.
  i_tod_card_fire_rate_ultimate.png | THE SOURCE for FIRE RATE ultimate. Gold treatment. Attach to Prompt C.
  i_tod_card_perkslots_regular.png | THE SOURCE for PERK SLOTS regular. Reproduce exactly; only the value plate changes. Attach to Prompt D.
  i_tod_card_perkslots_super.png | THE SOURCE for PERK SLOTS super. Purple treatment. Attach to Prompt E.
  i_tod_card_perkslots_ultimate.png | THE SOURCE for PERK SLOTS ultimate. Gold treatment. Attach to Prompt F.
  i_tod_card_recoil_regular.png | LAYOUT REFERENCE ONLY — a shipped card from the same deck whose value plate is ONE short centred line (LESS KICK) at the plate's full type size. Copy the single-line arrangement and type size, nothing else. Attach to every prompt.
preview: 234x351
-->

> **STATUS: DELIVERED AND INSTALLED 2026-09-11 (v18.85).** Drop
> `files - 2026-09-11T182525.218.zip`, all seven cards verified by eye before
> install, md5-checked after. **The drop was generated from the SEVEN-file version
> of this pack** (sent at 18:17, two minutes before the six-file rebuild), so
> `i_tod_card_fire_rate_dark.png` came back as well — correct, and installed,
> because re-baking it had already cost nothing at that point and a stale PNG
> beside three fresh ones is its own trap. It stays UNZONED and unreachable; see
> JOB 1 below for why FIRE RATE can never be a dark upgrade.
>
> **THE DELIVERED PERK SLOTS WORDING DIFFERS FROM THE BRIEF AND THAT IS
> ACCEPTED** (user, 2026-09-11: *"Yes thats fine"*). Asked for `+1 EXTRA PERK` on
> ONE line; delivered `+1 EXTRA` / `PERK SLOT` on TWO. Same for `+2 EXTRA PERK
> SLOTS` and `+3 EXTRA PERK SLOTS`. It still clears the user's actual complaint —
> the word LEVEL is gone — the digits and singular/plural are right on all three,
> and "PERK SLOT" matches the card's own title plate. Not re-requested.
>
> Six re-bakes at the **same filenames**, so the install is a straight file
> swap — no GDT block, no zone line, no `CARD_SLUG` entry, no `PAUSE_PLATE_MAX`
> move, no Lua change. FULL build after install; prove with a fresh
> content-hash `.iwi` for each beside an untouched control image, never a raw
> `.ff` grep. The matching code/copy edits shipped in the same pass (see
> "What already shipped" below).

## Why this exists

The user, 2026-09-11, on the two pieces of card copy players misread:

> *"The fire rate card from Mac eleven. It says truly fires faster. We don't
> need the word truly there. That's confusing. It just needs to be fire
> faster."*

> *"There's a card for perk bottles. It says, like, one perk per level. That's
> unclear because people think that it's per floor level ... maybe that needs to
> be something else, like one extra perk per rarity, or we can bake it into the
> card itself, two extra perks, three extra perks. That's something that can
> actually bake in that won't be changing over time."*

Both are **copy defects, not art defects**. Nothing about either upgrade's
behaviour is wrong or has changed.

### FIRE RATE — the word TRULY is a comparison to a domain that no longer exists

`TRULY fires faster` was written to contrast FIRE RATE with **ECHO ROUNDS**
(domain 11), a proc that fired a second bullet rather than raising the rate. So
"truly" meant *this one is a real rate increase, not a proc*. **ECHO ROUNDS was
removed 2026-08-23 (v9.35).** Since that build the sentence has been drawing a
distinction against nothing a player can see, and what is left reads as either
filler or a hint that some *other* card is lying. One word comes out; the rest of
the line stays.

*(This paragraph first read "retired in v14.11", taken from `tod_upgrade.lua:272`,
whose REGEN note sweeps id 11 into a batch it predates by a week. The same file
has it right at `:558`. Both Lua lines are now corrected. The date does not change
anything about the art request.)*

### PERK SLOTS — "LEVEL" is a word this map cannot spend on card rungs

`+1 PERK SLOT PER LEVEL` is precise and still wrong, because **this map has
fifty floors** and the player's floor high-water gates class-tier promotions.
"Level" already means *floor* everywhere else a player looks, so the plate reads
as "you get a perk slot every floor you climb". Every other card's `/ Lv` is safe
because its subject is obviously a gun stat; this one's subject is a thing the
tower also hands out.

**This card is the one legitimate exception to the standing generic-card-text
rule** (`[[generic-card-text-rule]]`: cards bake no number, the pause menu's
`DETAIL` row carries the live value). That rule exists because a baked number is
falsified by the next retune. Here the number is **structural, not tuned**:

- REGULAR / SUPER / ULTIMATE are *defined* as +1 / +2 / +3 levels of a domain.
- Every level of this domain is *defined* as exactly +1 perk
  (`perk_slot_limit()` = `TOD_PERK_SLOT_BASE` + `get_level(self,"perkslots")`).
- **The rarity shown can never exceed the levels actually paid.** Wherever
  `levels` can shrink against `rarity`, the band-honesty clamp demotes the card
  — `if ( o.levels >= 1 && o.levels < o.rarity ) o.rarity = o.levels;`. Checked
  **all four** sites in `_tod_upgrades.gsc`, not one: `make_option` (:5178),
  `guarantee_rarity` (:4991), the overcharge redeal (:5082) and the deferred
  re-present after a round takeover (:8648). A card reading ULTIMATE is only
  ever dealt when it really is about to grant three.
- **The one documented bypass does not apply.** `rarity_lock` (:5185) forces a
  frame *after* the clamp — but `set_rarity_lock` is called on exactly two
  domains, `deadshot` and `mage_quickhands` (:1853-1854). Not this one.

That is the whole proof, and it was re-checked adversarially: an earlier pass
found only three of the four clamp sites, which would have left the conclusion
resting on an incomplete survey even though it happened to be right.

So `+3 EXTRA PERKS` on the ultimate card is true by construction and stays true
through any future retune of this domain's *rate*, because there is no rate to
retune. The only change that would falsify it is redefining what a rarity is
worth — which would owe every card in the deck a re-bake anyway. **Do not
generalise this exception to any other card.**

## What changes per file

Nothing on any card moves except the text inside the dark value plate at the
bottom. No pip row changes (FIRE RATE stays 3 pips, PERK SLOTS stays 5).

### JOB 1 — FIRE RATE: delete one word, on three cards

| File | Value plate now | Value plate after |
|---|---|---|
| `i_tod_card_fire_rate_regular.png` | `TRULY FIRES` / `FASTER` (2 lines) | `FIRES FASTER` (**1 line**) |
| `i_tod_card_fire_rate_super.png` | `TRULY FIRES` / `FASTER` (2 lines) | `FIRES FASTER` (**1 line**) |
| `i_tod_card_fire_rate_ultimate.png` | `TRULY FIRES` / `FASTER` (2 lines) | `FIRES FASTER` (**1 line**) |

`i_tod_card_fire_rate_dark.png` is **NOT in this request.** FIRE RATE cannot be a
dark upgrade at all (user, 2026-09-11), and the block is structural rather than a
preference: `set_no_dark( "firerate" )` in `_tod_upgrades.gsc` records the reason
as *"weapon-variant ladder, +8 registrations, no per-player fire-time call
exists"* — FIRE RATE is a TWIN domain that swaps real gun data, so a dark rung
would need eight more weapon registrations against a ledger already at 223/223
with zero headroom. `DARK_NONE[15]` mirrors it in the Lua, and the card is not
zoned.

The first draft of this brief asked for it anyway, as insurance against a future
session zoning a stale bake. **That argument does not survive the reason above:**
zoning it would first require eight free registrations that do not exist, so the
stale PNG can never reach a player. It stays parked in `source_data`, unzoned and
un-rebaked. If the weapon ledger ever gains headroom AND someone revives a dark
FIRE RATE, the card needs a fresh brief, not this one.

### JOB 2 — PERK SLOTS: one line, and it differs per rarity

| File | Value plate now | Value plate after |
|---|---|---|
| `i_tod_card_perkslots_regular.png` | `+1 PERK SLOT PER LEVEL` | `+1 EXTRA PERK` |
| `i_tod_card_perkslots_super.png` | `+1 PERK SLOT PER LEVEL` | `+2 EXTRA PERKS` |
| `i_tod_card_perkslots_ultimate.png` | `+1 PERK SLOT PER LEVEL` | `+3 EXTRA PERKS` |

`i_tod_card_perkslots_dark.png` is **NOT in this request and must not be
re-baked** either. It is unzoned and unreachable (`set_no_dark( "perkslots" )`,
blocked as a no-op because `perk_slot_limit()` already floors every spire player
at the whole roster), and on top of that it has no correct new wording: a dark
card is not a rarity, so it has no level count to print. If it is ever brought
back it needs its own decision, not a copy of the ultimate card's line.

**So neither domain's `_dark` card is part of this job.** Both are parked PNGs
that no deal can produce.

## What already shipped (code side, 2026-09-11, v18.85)

These landed in the same pass and are **not** waiting on art:

| Where | Was | Now |
|---|---|---|
| `_tod_upgrades.gsc` `add_domain("firerate")` | `truly fires faster (-8% fire time / Lv)` | `fires faster (-8% fire time / Lv)` |
| `tod_upgrade.lua` `DOMAIN[15].desc` | `truly fires faster per level` | `fires faster per level` |
| `_tod_upgrades.gsc` `add_domain("perkslots")` | `+1 perk slot / Lv (base 4)` | `carry +1 more perk / Lv (base 4, cap 9)` |
| `tod_upgrade.lua` `DOMAIN[40].desc` | `+1 perk slot / Lv (base 4)` | `carry one more perk each time` |
| `tod_upgrade.lua` `DETAIL[40].act` | `base 4, +1 per level` | `4 without this upgrade` |
| `docs/armory.html` both entries | — | re-worded to match |

`DETAIL[15]` (`-{V}% time between shots` / `MAC-10 only`) was already clean and
is untouched. The pause menu and scoreboard read `DETAIL`, so the live numbers
were never the problem.

## Install notes (repo side, after the drop)

`.\tools\make_art_pack.ps1 -Inspect "files (N).zip"`, **look at all six**,
overlay each against its source, then copy over
`source_data/tod_ui_images/_images/` under the same six filenames. No wiring of
any kind. FULL build. Proof is six fresh content-hash `.iwi` files beside an
untouched control image.

<!-- PACK:BEGIN -->
# Two upgrade cards need their bottom text line re-worded — 6 images

## What this is

A Call of Duty: Black Ops 3 zombies map has a deck of collectible upgrade cards,
drawn at **234 x 351 px on screen** (see `preview_onscreen_234x351/` for what the
player actually sees at real size).

Two of the upgrades in that deck have wording on their cards that players are
misreading, and the wording has to change. **This is not new art. It is a re-bake
of six cards you already have**, and on every one of them the ONLY thing that
changes is the text inside the dark panel at the bottom of the card.

The six `i_tod_card_*` files in `reference/` are the shipped originals.
Reproduce each one **exactly** — same title, same illustration, same colours,
same frame, same side rails, same corner screws, same star medal, same rarity
ribbon, same row of dots at the bottom — and change only the one text line
described below for that card.

---

## JOB 1 — the FIRE RATE cards: delete one word (3 images)

These three cards currently have **two** centred lines in the bottom panel:

```
TRULY FIRES
FASTER
```

They must become **one** centred line:

```
FIRES FASTER
```

That is the whole change. The word `TRULY` is removed and the remaining two
words sit together on a single line, centred in the panel both across and down.

**Set it at the panel's full type size — the same size the words `TRULY FIRES`
use today, not smaller.** `reference/i_tod_card_recoil_regular.png` is a shipped
card from the same deck whose bottom panel already holds one short centred line
(`LESS KICK`) at that size — use it to see how a single line should sit in the
panel. Take **nothing else** from that card: not its title, not its artwork, not
its wording, not its dot row.

**Keep each card's own colour.** The new line takes exactly the colour the words
`TRULY FIRES` use on that same card today:

| Card | Line colour |
|---|---|
| regular | pale blue-white |
| super | purple |
| ultimate | gold |

## JOB 2 — the PERK SLOTS cards: a different line on each of the three (3 images)

These three cards currently all carry the **same** single line in the bottom
panel:

```
+1 PERK SLOT PER LEVEL
```

Players read "level" as the floor of the tower they are climbing, which is not
what it means. Each card now gets **its own** line, and unlike almost every other
card in this deck **the three are deliberately different from each other**:

| Card | Line after |
|---|---|
| regular | `+1 EXTRA PERK` |
| super | `+2 EXTRA PERKS` |
| ultimate | `+3 EXTRA PERKS` |

Note `PERK` is singular on the regular card and `PERKS` is plural on the other
two. Spell them exactly as written, all caps, with the `+` and the digit, no full
stop.

Each stays **one centred line** in the same panel, in the same colour that card's
current line uses (pale blue-white on regular, purple on super, gold on
ultimate). The new lines are much shorter than the one they replace, so **set
them larger** — at the panel's full type size, the size shown by
`reference/i_tod_card_recoil_regular.png`'s `LESS KICK` line. They must not wrap
to a second line.

---

## Deliver exactly SIX files

| Deliver as | Size | Source to match | New bottom line |
|---|---|---|---|
| `i_tod_card_fire_rate_regular.png` | 768 x 1152 | `reference/i_tod_card_fire_rate_regular.png` | `FIRES FASTER` |
| `i_tod_card_fire_rate_super.png` | 768 x 1152 | `reference/i_tod_card_fire_rate_super.png` | `FIRES FASTER` |
| `i_tod_card_fire_rate_ultimate.png` | 768 x 1152 | `reference/i_tod_card_fire_rate_ultimate.png` | `FIRES FASTER` |
| `i_tod_card_perkslots_regular.png` | 768 x 1152 | `reference/i_tod_card_perkslots_regular.png` | `+1 EXTRA PERK` |
| `i_tod_card_perkslots_super.png` | 768 x 1152 | `reference/i_tod_card_perkslots_super.png` | `+2 EXTRA PERKS` |
| `i_tod_card_perkslots_ultimate.png` | 768 x 1152 | `reference/i_tod_card_perkslots_ultimate.png` | `+3 EXTRA PERKS` |

Same filenames as the sources — these replace the shipped files in place. RGBA,
**fully transparent background** (the card body sits on transparency and does not
fill the canvas), same canvas size and same margins as each source.

## Hard rules

- **Only the bottom text line changes. Nothing else on any card may move.**
  Title plate and its word, the illustration, the background panel and its
  scanlines, the floating tick marks, the sparkles, the rarity ribbon, the star
  medal, the side rails, the corner screws, the outer glow, the canvas size and
  the margins — identical to the source card.
- **Do not touch the row of dots at the bottom of any card.** FIRE RATE keeps its
  3 dots, PERK SLOTS keeps its 5, and the number lit on each card stays exactly
  as it is. This job does not change any dot row.
- **Do not touch the rarity ribbon.** `REGULAR +1`, `SUPER +2` and `ULTIMATE +3`
  all stay exactly as they are. The `+1` / `+2` / `+3` on the ribbon is a
  separate marker and is correct already.
- **The colour treatment is per-card and must not move:** regular navy/blue,
  super purple, ultimate gold.
- **There is no dark/red card in this job.** Both of these upgrades have a
  red-and-black `_dark` card in the game's files; neither is part of this
  request and neither may be delivered.
- **Every new line is ONE line.** Nothing wraps, nothing splits across two lines.
- **No FIRE RATE card may carry a number.** `FIRES FASTER` and nothing else.
- **The three PERK SLOTS lines must differ from each other** — `+1` on regular,
  `+2` on super, `+3` on ultimate. This is the one place in this job where the
  three rarities do not say the same thing, and getting all three the same is the
  single most likely way to get this wrong.
- Do not restyle, redraw or "improve" any illustration.
- Do not rename the files.

## Paste-ready prompts

**Prompt A — FIRE RATE regular.** *Attach `reference/i_tod_card_fire_rate_regular.png`
and `reference/i_tod_card_recoil_regular.png`.*

> Reproduce the first attached game upgrade card (the blue FIRE RATE card)
> exactly, at 768 x 1152 with a fully transparent background, changing only one
> thing. In the dark panel at the bottom, the two centred lines currently reading
> `TRULY FIRES` and `FASTER` must become a single centred line reading
> `FIRES FASTER`. Delete the word `TRULY`; keep the other two words together on
> one line, centred both across and down in that panel, in the same pale
> blue-white colour they use now, at the same type size the words `TRULY FIRES`
> use today. The second attached image is a different card from the same deck
> whose bottom panel already holds one short centred line — use it only to see
> how a single line sits in that panel, and take nothing else from it.
> Everything else must be identical to the first image: the FIRE RATE title
> plate, the submachine gun with the muzzle flash, the background panel, the tick
> marks and sparkles, the `REGULAR +1` ribbon, the star medal, the rails, the
> screws, the row of 3 dots at the bottom with 1 lit, the margins and the
> transparent background.

**Prompt B — FIRE RATE super.** *Attach `reference/i_tod_card_fire_rate_super.png`
and `reference/i_tod_card_recoil_regular.png`.*

> Same task on the purple SUPER card. Reproduce the first attached image exactly
> at 768 x 1152, transparent background, with one change: replace the two lines
> `TRULY FIRES` / `FASTER` in the bottom panel with a single centred line reading
> `FIRES FASTER`, keeping the PURPLE colour those words use on this card and the
> same type size. The second attached image shows how one short centred line sits
> in that panel — take only the layout from it. Keep the `SUPER +2` ribbon and
> the row of 3 dots with 2 lit exactly as they are, and keep everything else
> identical to the first image.

**Prompt C — FIRE RATE ultimate.** *Attach `reference/i_tod_card_fire_rate_ultimate.png`
and `reference/i_tod_card_recoil_regular.png`.*

> Same task on the gold ULTIMATE card. Reproduce the first attached image exactly
> at 768 x 1152, transparent background, with one change: replace the two lines
> `TRULY FIRES` / `FASTER` in the bottom panel with a single centred line reading
> `FIRES FASTER`, keeping the GOLD colour those words use on this card and the
> same type size. The second attached image shows how one short centred line sits
> in that panel — take only the layout from it. Keep the `ULTIMATE +3` ribbon,
> the gold outer glow and the row of 3 dots with 3 lit exactly as they are, and
> keep everything else identical to the first image.

**Prompt D — PERK SLOTS regular.** *Attach `reference/i_tod_card_perkslots_regular.png`
and `reference/i_tod_card_recoil_regular.png`.*

> Reproduce the first attached game upgrade card (the blue PERK SLOTS card)
> exactly, at 768 x 1152 with a fully transparent background, changing only one
> thing. In the dark panel at the bottom, replace the line
> `+1 PERK SLOT PER LEVEL` with a single centred line reading `+1 EXTRA PERK`.
> Keep the same pale blue-white colour, keep it on one line, centred both across
> and down. The new text is much shorter than the old line, so set it LARGER — at
> the panel's full type size, which the second attached image shows with its
> short `LESS KICK` line. Use that second image only for the type size and
> layout of a single line; take nothing else from it. Everything else must be
> identical to the first image: the PERK SLOTS title plate, the robot character
> holding a purple bottle with four coloured bottles on a shelf, the background
> panel, the sparkles, the `REGULAR +1` ribbon, the star medal, the rails, the
> screws, the row of 5 dots at the bottom with 1 lit, the margins and the
> transparent background.

**Prompt E — PERK SLOTS super.** *Attach `reference/i_tod_card_perkslots_super.png`
and `reference/i_tod_card_recoil_regular.png`.*

> Same task on the purple SUPER card, but **the text is different from the
> regular card**. Reproduce the first attached image exactly at 768 x 1152,
> transparent background, with one change: replace the line
> `+1 PERK SLOT PER LEVEL` in the bottom panel with a single centred line reading
> `+2 EXTRA PERKS` — note the `2` and the plural `PERKS`. Keep the PURPLE colour
> that line uses on this card, keep it on one line, and set it at the panel's
> full type size (the second attached image shows that size with its short
> `LESS KICK` line; take only the type size and layout from it). Keep the
> `SUPER +2` ribbon and the row of 5 dots with 2 lit exactly as they are, and
> keep everything else identical to the first image.

**Prompt F — PERK SLOTS ultimate.** *Attach `reference/i_tod_card_perkslots_ultimate.png`
and `reference/i_tod_card_recoil_regular.png`.*

> Same task on the gold ULTIMATE card, but **the text is different again**.
> Reproduce the first attached image exactly at 768 x 1152, transparent
> background, with one change: replace the line `+1 PERK SLOT PER LEVEL` in the
> bottom panel with a single centred line reading `+3 EXTRA PERKS` — note the `3`
> and the plural `PERKS`. Keep the GOLD colour that line uses on this card, keep
> it on one line, and set it at the panel's full type size (the second attached
> image shows that size with its short `LESS KICK` line; take only the type size
> and layout from it). Keep the `ULTIMATE +3` ribbon, the gold outer glow and the
> row of 5 dots with 3 lit exactly as they are, and keep everything else
> identical to the first image.

## Delivery checklist

- [ ] Six PNG files, named exactly as in the table above.
- [ ] Each 768 x 1152, RGBA, fully transparent background.
- [ ] All three FIRE RATE cards read `FIRES FASTER` on **one** line.
- [ ] The word `TRULY` appears nowhere on any card.
- [ ] No digit appears on any FIRE RATE card's bottom panel.
- [ ] The three PERK SLOTS cards read `+1 EXTRA PERK`, `+2 EXTRA PERKS` and
      `+3 EXTRA PERKS` — **three different lines**, singular on the first.
- [ ] No card's bottom line wraps to a second line.
- [ ] Every dot row is untouched: FIRE RATE 3 dots (1 / 2 / 3 lit),
      PERK SLOTS 5 dots (1 / 2 / 3 lit).
- [ ] Every rarity ribbon untouched (`REGULAR +1`, `SUPER +2`, `ULTIMATE +3`).
- [ ] Per-card colour kept: blue / purple / gold.
- [ ] No red-and-black dark card delivered for either upgrade.
- [ ] Laid beside its source, each card differs ONLY in the bottom text line.

## Do NOT

- Do not change any illustration, title, ribbon, frame, medal, rail or screw.
- Do not change any dot row, or how many dots are lit.
- Do not bake a number onto a FIRE RATE card.
- Do not give the three PERK SLOTS cards the same line — that is the point of
  the job.
- Do not copy RECOIL's artwork, title, wording or dot row; that file is in the
  pack purely to show how one short centred line sits in the bottom panel.
- Do not deliver a dark card for either upgrade — no `fire_rate_dark`, no
  `perkslots_dark`. Neither is part of this request.
- Do not resize the canvas, add a background fill, or crop the margins.
- Do not rename the files.
<!-- PACK:END -->
