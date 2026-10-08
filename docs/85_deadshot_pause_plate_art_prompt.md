# 85 — DEADSHOT pause-menu nameplate (domain 47: `i_tod_pause_r47`, ONE image)

<!-- art-pack
name: deadshot_plate
refs:
  i_tod_pause_r46.png | the CURRENT pause-menu nameplate style (reads TRAILBLAZER, the newest plate): copy the pill, notch, bevel and lettering exactly with the new word. Attach to the prompt.
  i_tod_pause_r44.png | a second plate from the same row (reads GUNSLINGER) so the lettering size and margin can be checked against two examples. Attach to the prompt.
preview: 300x44
-->

> **STATUS: SHIPPED v16.75, 2026-09-03 — UNPLAYED.** Drop `files - 2026-09-03T020559.719.zip` (two byte-different copies of one 300x44 plate; root md5 3825a748 installed): GDT block cloned from r46, zone line, PAUSE_PLATE_MAX + TOD_UPG_PLATE_MAX 46 -> 47. (Historical, pre-drop:) **REQUESTED 2026-09-03 (v16.73).** The DEADSHOT card itself shipped
> in v16.67 (docs/84); this is the pause-menu plate that docs/84 did NOT
> request — the user's "we only need an Ultimate asset" was read as card-only,
> and on 2026-09-03 they asked *"where is the pause menu asset? Did you forget
> to ask for that?"*. Until it lands the pause row for id 47 is the text
> fallback (47 > `PAUSE_PLATE_MAX` 46). Pack built by
> `.\tools\make_art_pack.ps1 docs\85_deadshot_pause_plate_art_prompt.md` →
> `~/Downloads/tod_deadshot_plate_art_pack.zip`. Install = copy the PNG into
> `source_data/tod_ui_images/_images/`, add its GDT block (clone r46's) + the
> `image,` zone line, raise `PAUSE_PLATE_MAX` (AetheriumStartMenu.lua) and
> `TOD_UPG_PLATE_MAX` (AetheriumScoreboard.lua) 46 → 47 — a CONTIGUOUS ceiling,
> and r45/r46 are both zoned so 47 is claimable — FULL build, prove with a
> fresh content-hash `.iwi`.

<!-- PACK:BEGIN -->
# DEADSHOT — one pause-menu nameplate

## What this is

A Call of Duty: Black Ops 3 zombies map lists a player's owned upgrades in its
pause menu as a column of slim nameplates (**300 × 44 px on screen**, see
`preview_onscreen_300x44/`). The DEADSHOT upgrade already has its card; it
needs its nameplate. **The attached plates ARE the style — match them
exactly.** The new plate has to sit in the column between them and look like
it was cut from the same strip.

**Deliver exactly ONE file:**

| Deliver as | Size | Text (exact) |
|---|---|---|
| `i_tod_pause_r47.png` | 300 × 44 | **`DEADSHOT`** |

RGBA with a **fully transparent background** outside the plate.

## References (in `reference/`)

- `i_tod_pause_r46.png` — the current plate style (reads TRAILBLAZER). Copy
  it exactly; only the word changes.
- `i_tod_pause_r44.png` — a second plate from the same column (reads
  GUNSLINGER), so the lettering size and the right-hand margin can be checked
  against two examples. Where they agree, that is the rule.

## Hard rules

- Exactly 300 × 44, PNG, RGBA, transparent outside the pill. Corner pixel
  fully transparent — decode it.
- Text is the single word `DEADSHOT` in the attached plates' lettering. No
  icon, no digits, no second word, no watermark.
- Same pill, same outline, same bevel sheen, same cyan notch, same left
  margin after the notch, same right-hand margin as the attached plates.

## Prompt — build `i_tod_pause_r47.png`

Attach `reference/i_tod_pause_r46.png` AND `reference/i_tod_pause_r44.png`.

```text
Two slim game-menu nameplates are attached (they read TRAILBLAZER and
GUNSLINGER). Produce their sibling reading DEADSHOT. Exactly 300 x 44 pixels,
PNG, RGBA, transparent outside the plate. Copy the plate exactly: the fully
rounded-end dark navy pill with its thick dark outline and the subtle lighter
bevel sheen along the top inside edge, the short bright cyan vertical notch
inset at the left end, and the same chunky white bubble lettering with a dark
outline, left-aligned after the notch, sized to fill most of the plate's
height. The only change is the word: DEADSHOT. It is about the length of
GUNSLINGER, so keep that plate's letter size and end the word with the same
right-hand margin. No icon, no numbers, no other text. Deliver as
i_tod_pause_r47.png.
```

## Delivery checklist

- [ ] `i_tod_pause_r47.png`, 300 × 44, RGBA, transparent corner pixel.
- [ ] Reads `DEADSHOT`, spelled right, one word.
- [ ] Overlaid on `i_tod_pause_r46.png`, the pill, notch and lettering baseline
      line up exactly.

## Do NOT

- Do not add an icon, a level number, or a second line.
- Do not change the pill colour or the notch colour.
- Do not deliver JPEG, a filled background, or a different size.
<!-- PACK:END -->
