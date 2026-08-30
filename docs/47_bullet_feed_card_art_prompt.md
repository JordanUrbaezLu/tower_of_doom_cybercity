# BULLET FEED — card art prompt (level-agnostic re-bake)

**Why:** the 2026-08-30 2× buff (Lv1 1.0s/round → Lv10 0.2s/round) invalidated the
numbers baked into two of the three cards. Rather than re-bake the same trap, these
replacements carry **no numbers at all**, so every future retune of this domain is a
pure `-GscOnly` and never an art job again.

**Scope: TWO images.** `ULTIMATE` already reads "NEVER STOP FIRING" and is
level-agnostic — **do not regenerate it.** It is the in-set style reference for the
other two.

| File | Current panel text | Action |
|---|---|---|
| `i_tod_card_bullet_feed_regular.png` | `2.0s TO 0.4s PER ROUND` | **regenerate** |
| `i_tod_card_bullet_feed_super.png` | `2.0s TO 0.4s PER ROUND` | **regenerate** |
| `i_tod_card_bullet_feed_ultimate.png` | `NEVER STOP FIRING` | keep |

Path: `source_data/tod_ui_images/_images/`

---

## Hard specs (non-negotiable — the set has 127 cards and must stay consistent)

- **Canvas 768 × 1152, PNG, RGBA.** Background **fully transparent** outside the card
  body and outside its outer glow.
- Flat vector cartoon / mobile-game-card style. **Thick black outlines**, flat fills,
  no photorealism, no gradients except the few noted below, no drop shadows on text.
- All text in a **heavy condensed display sans, ALL CAPS**, with a black outline.
- The card must be **centred** with a small transparent margin so the outer glow is
  not clipped.

---

## Shared layout, top to bottom

1. **Card body** — rounded rectangle, near-black navy fill (`#1e2140`), heavy black
   outline, plus a soft **outer glow in the rarity colour**.
2. **Title plate** — horizontal pill, **orange→amber vertical gradient**, black
   outline, a row of small circular studs along its top edge. Text **`BULLET FEED`**
   in white heavy caps with a black outline. *Identical on both cards.*
3. **Art window** — large inset rounded panel, dark blue-navy, faint radial highlight
   at top, thin rarity-coloured inner border. Decorative pixel squares: **cyan
   top-left, white top-right, small orange bottom-left**.
4. **The icon** (see below) — centred in the art window.
5. **Star medallion** — circular coin with a five-point star, overlapping the
   **bottom-right** corner of the art window.
6. **Rarity banner** — pill with notched arrow points on both sides, bold white
   outlined caps.
7. **Bottom text panel** — inset dark plate, rounded inner border, a small screw stud
   in each of its four corners. **1–2 lines of centred text in the rarity colour.**
8. **Pip row** — three circular sockets at the very bottom; filled count = rarity tier.
9. **Corner bolts** — small cross-head screws in the four corners of the card body.
10. **Side accent bars** — thin vertical rounded bars on the left and right edges of
    the card, in the rarity colour.

---

## The icon — identical on both cards, only accent colours change

A **flat cartoon ammunition belt feeding a magazine**:

- **Four upright rounds** in brass/amber with orange tips, evenly spaced, seated in a
  dark grey belt-link rail that runs horizontally with a round pulley at each end.
- **Three small cyan triangular arrows** beneath the belt pointing **right**, showing
  travel direction.
- To the right, a **dark magazine** seen from the side, slightly tilted, with a lighter
  grey top lip.
- A **dashed cyan arc arrow** curving from above the belt down into the magazine mouth.
- Two **angular bracket accents** in the rarity colour — one upper-left, one lower-right
  of the art window.

Keep the composition, proportions and placement **identical to the existing ULTIMATE
card**; only the accent colours and the two text strings differ between rarities.

---

## Per-card variations

### 1. `i_tod_card_bullet_feed_regular.png`

- Accent colour: **cyan / light blue**. Side bars cyan. Bracket accents **purple-blue**.
- Star medallion: **silver/grey** coin, grey star.
- Rarity banner: **silver-grey gradient**, text `REGULAR +1`.
- Outer glow: **soft white-blue**, subtle.
- Pips: **first filled white**, other two empty.
- **Bottom panel text (2 lines, light blue):**
  ```
  RESERVE FEEDS
  THE MAG
  ```

### 2. `i_tod_card_bullet_feed_super.png`

- Accent colour: **purple/violet**. Side bars purple. Bracket accents purple.
- Star medallion: **gold** coin, gold star.
- Rarity banner: **purple gradient**, text `SUPER +2`.
- Outer glow: **purple**, brighter than regular.
- Pips: **first two filled purple**, third empty.
- **Bottom panel text (2 lines, purple):**
  ```
  THE BELT
  NEVER RESTS
  ```

---

## Negative constraints — the whole point of this re-bake

- **NO NUMBERS ANYWHERE.** No seconds, no percentages, no "per round", no digits at all
  except the `+1` / `+2` that are part of the rarity banner.
- No mention of rate, timing, or level counts that a future retune could falsify.
- No new iconography — do not add clocks, timers, gauges or speed lines. The belt-and-
  magazine icon already carries the idea.
- No text outside the title plate, rarity banner and bottom panel.
- No opaque background, no white card border, no watermark.

---

## Where the live numbers come from once they leave the art

The card is the **whole visual** — `PaintCard` sets `CardImg` and then blanks the
composite `Tag`/`Name`/`Desc` text, so LUI draws nothing over the art. Taking numbers
off the card therefore has to be paid for somewhere, and it is:

- **The pause menu** renders the value **level-aware** — `CoD.TodDomainDesc` →
  `DETAIL[10].val(lvl)`, with `{V}` substituted and formatted to `dec` places
  (`tod_upgrade.lua:193` documents the substitution, `:235` is the row). A player who
  wants the exact seconds at their current level reads it there, always correct.
- **The deal screen** keeps a live `Lv X > Y` line outside the card image
  (`tod_upgrade.lua:341-344` — "LUI keeps only layout, the focus/hold/timer overlays
  and the live Lv X > Y line"). ⚠️ That line reads as **level numbers**, not the effect
  value; I could not confirm from the code that it prints the seconds. Assume the deal
  screen shows the level transition and the pause menu shows the value.

## The rule this encodes

**Card art must be true at any tuning.** In-set precedents that already do this:
`HANDLING` → "FASTER RELOAD & ADS"; `BULLET FEED` ULTIMATE → "NEVER STOP FIRING";
`CLEAVE`, `SECOND WIND`, `RUN AND GUN` (per the v14.11 batch, `docs/46`).
Cards that bake a value (`+12% damage per level`, `2.0s TO 0.4s`) become stale the
moment the domain is retuned, and per `CLAUDE.md` the retune is not finished until the
card is re-baked — which is a full build plus an art round-trip for what should be a
one-number change.

**The live numbers are not lost.** The pause menu renders them level-aware from script
(`CoD.TodDomainDesc` → `tod_upgrade.lua:235`), so a player who wants the exact figure
reads it there, always correct, never needing art.

---

## After the art lands

1. Drop both PNGs into `source_data/tod_ui_images/_images/` (same filenames — the zone
   lines and GDT image blocks already exist; no new entries needed).
2. **A `.gdt` change is ALWAYS a full build** — `-GscOnly` copies the GDT but runs no
   `gdtdb /update` and rebuilds no image assets, so a `-GscOnly` after an art drop is
   worse than nothing: it makes the tree look current while shipping the old art.
3. **Verify by content, not by name.** Both filenames already exist, so a manifest
   name-grep passes whether or not the new bytes converted. Check
   `share/assetconvert/image/v29` for a **new content-hash-keyed `.iwi` stamped this
   build** sitting beside the old one. `gdtdb /update` currently exits 1 on this machine
   (a duplicate pack GDT in two scan roots), so `BUILD OK` alone proves nothing here.
