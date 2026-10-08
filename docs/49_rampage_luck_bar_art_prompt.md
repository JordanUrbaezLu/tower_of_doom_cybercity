# RAMPAGE LUCK BAR — art prompt (red fill / purple max)

**Why:** the RAMPAGE INDUCER (v14.20, `_tod_rampage.gsc`) needs an always-on,
glanceable indicator that hard mode is live. The breaker's spark FX only reads when
you are standing in the teleport bay; the luck bar is on screen for the whole match.
User ask, verbatim: *"We can update the luck bar to red and max is purple when
rampage is on. This will be another indicator that it is on."*

**Scope: FIFTEEN new images** — a complete parallel set to the shipped luck bar.
Nothing existing is regenerated or replaced; the normal set stays exactly as it is
and is the style reference.

| New file | Mirrors | State |
|---|---|---|
| `i_tod_luck_rmp_00.png` … `i_tod_luck_rmp_09.png` | `i_tod_luck_00..09` | 0–90% fill, **red** |
| `i_tod_luck_rmp_10.png` | `i_tod_luck_10` | 100% fill, **purple** |
| `i_tod_luck_rmp_max_01.png` … `_04.png` | `i_tod_luck_max_01..04` | overcharge zap frames, **purple** |

Path: `source_data/tod_ui_images/_images/`

---

## Hard specs (non-negotiable — these swap 1:1 with the shipped set at runtime)

- **Canvas 1024 × 128, PNG, RGBA, fully transparent background.** Identical to the
  existing set — verified from the shipped PNGs, not from a doc.
- **Renders at 304 × 38 on screen** (`tod_upgrade.lua:1317`,
  `LUCK_X, LUCK_Y, LUCK_W, LUCK_H = 24, 56, 304, 38`). Every detail must survive a
  ~3.4× downscale. No hairlines, no small text beyond the existing wordmark.
- **GEOMETRY MUST BE PIXEL-IDENTICAL to the shipped set.** Same housing shape, same
  dice badge position and size, same `LUCK` wordmark position, same ten segment
  divisions, same lightning tick marks, same circuit-traced arrow tip on the right,
  same outer bounds. The game swaps whole images between the normal and rampage sets
  the instant the breaker is thrown — **any drift in position or scale makes the HUD
  visibly jump.** Only the COLOUR changes.
- Attach the reference PNGs to every generation step (see below). Do not work from
  description alone.

---

## THE DESIGN RULE THAT DECIDES THIS SET

**The whole bar goes red, not just the fill.**

The shipped empty state (`i_tod_luck_00`) is **cyan** — cyan housing outline, cyan
`LUCK` wordmark, cyan dice badge, ten dark empty segments. It only turns gold as it
fills. If the rampage variant recoloured *only the fill*, then a player sitting at 0%
luck — which is every player immediately after every upgrade event, since the bar
hard-resets to 0 — would see a bar identical to normal mode. The indicator would fail
exactly when it is most needed.

So in the rampage set the **housing outline, the `LUCK` wordmark, the dice badge, the
segment borders and the arrow tip are all red at every fill level**, including at 0%.
The fill is what climbs; the chrome is what tells you the mode.

**The red→purple shift at the top mirrors the shipped set's own behaviour.** Normal
goes cyan → gold as it fills. Rampage goes red → purple. Same idea, different palette,
so it reads as the same instrument in a different mode rather than a different widget.

---

## Palette

| Element | Normal set (reference) | Rampage set |
|---|---|---|
| Housing / frame outline | cyan `#3fd0ee` → gold `#f5c518` | **red `#e02a2a`** at every level |
| `LUCK` wordmark | cyan → gold | **red `#e02a2a`** (purple `#a855f7` on 10 and max) |
| Dice badge | cyan → gold | **red** (purple on 10 and max) |
| Empty segments | dark navy `#141a24` | dark navy `#141a24` — **unchanged** |
| Fill, states 01–09 | molten gold | **red**, deep crimson `#8f1616` at 01 warming to hot red-orange `#ff3b1b` by 09 |
| Fill, state 10 | molten gold, hottest | **purple** — violet `#a855f7` core with a brighter magenta-white centre line |
| Overcharge arcs | cyan over gold | **white-violet arcs over the purple fill** |
| Housing body | near-black navy | near-black navy — **unchanged** |

*(Hex values are direction, not law — match the shipped set's saturation and glow
weight rather than hitting exact numbers.)*

---

## PROMPT 1 — the asset LLM

Two-step doctrine (memory: `images-over-lui`; same flow docs/45 used for the
overcharge frames). **Attach `i_tod_luck_00.png`, `i_tod_luck_05.png`,
`i_tod_luck_10.png` and `i_tod_luck_max_01.png` to BOTH steps** — the LLM needs the
empty, mid, full and zap states to hold the geometry.

### Step 1 — explore

> I'm attaching four states of a luck meter from my neon cyber-city zombies game —
> empty, half, full, and an "overcharged" zap frame. Each is a 1024×128 transparent
> PNG: an angular dark navy housing, a dice icon in a rounded square on the left, the
> word LUCK across the top, ten fill segments with small lightning tick marks, and a
> circuit-traced arrow tip on the right. Empty reads cyan; it warms to molten gold as
> it fills.
>
> I need a RED "hard mode" version of this exact meter. When the player switches my
> game into hard mode, the whole bar turns red so they can tell at a glance — and
> critically it must look red even when the bar is EMPTY, because it resets to empty
> constantly. So the housing outline, the LUCK wordmark, the dice badge and the arrow
> tip all go red, not just the fill.
>
> Give me 3 distinct style options of ONE half-full red bar so I can pick a direction:
>
> A) **Danger red** — clean signal red across the chrome, fill a molten crimson→orange
>    gradient like heated iron. Reads as an alarm state. Closest sibling to the gold set.
> B) **Blood neon** — deeper oxblood chrome with a hot magenta-red neon rim light, fill
>    a saturated arterial red with a bright core line. Cyberpunk, more menacing.
> C) **Warning strobe** — red chrome with faint amber-red bloom around the housing, fill
>    banded in two reds so the segments read harder at small size. Industrial hazard feel.
>
> Hard rules for every option: keep the geometry EXACTLY as attached — same canvas
> (1024×128), same shapes, same positions, same scale, fully transparent background.
> The empty-segment interiors stay near-black navy. Only the colours change. It renders
> at 304×38 on screen, so keep everything readable when shrunk to a third size.

### Step 2 — build-out (after picking a style)

> Style [X] wins. Now produce the full set of ELEVEN fill states plus FOUR overcharge
> frames, in that exact style.
>
> **Fill states — `i_tod_luck_rmp_00` through `i_tod_luck_rmp_10`:**
> Match the attached normal set's fill amounts exactly, state for state — 00 is empty,
> 05 is half, 10 is completely full — so the two sets can be swapped mid-game without
> the level appearing to change. States 00–09 are RED, warming from a deep crimson at
> 01 to a hot red-orange by 09 (00 has no fill at all, just red chrome and dark
> segments).
>
> **State 10 is PURPLE, not red.** At maximum the bar shifts to a violet/purple fill
> with a brighter magenta-white core, and the wordmark and dice badge shift purple to
> match. This is the payoff state and must be unmistakable next to 09.
>
> **Overcharge frames — `i_tod_luck_rmp_max_01` through `i_tod_luck_rmp_max_04`:**
> Four variants of the PURPLE full bar with electric arcs crawling over it, matching
> the attached `i_tod_luck_max_01` in energy and arc weight but with **white-violet
> arcs over purple fill** instead of cyan over gold. The game flips between these four
> at random ~7 times a second to fake live electricity, so all four must share an
> identical base image and identical overall energy, with every arc, spark and hotspot
> at DIFFERENT positions in each frame (frame 1 left third and arrow tip, frame 2
> mid-bar and top edge, frame 3 bottom edge and dice badge, frame 4 spread wide with
> the longest single arc). No frame may look calmer than another — cycling should read
> as electricity dancing, not blinking.
>
> Deliver: fifteen 1024×128 transparent PNGs, geometry pixel-aligned across all
> fifteen and against the attached originals — any drift makes the HUD jitter.

---

## Wiring notes (for whoever installs the art)

- **The data channel is NOT `todUpgLuck`.** That clientfield is a **4-bit int**
  (`_tod_upgrade_ui.gsc:64`, `.csc:33`) and every value is already spoken for: 0–10
  are the fill states, 11–14 are the overcharge zap frames (v14.9), leaving exactly
  **one** spare value. A red set needs 15 more states and cannot fit.
- **Append a new 1-bit `todRampage` clientuimodel field.** Counted from the tree
  2026-08-30: the map registers **15 fields / 59 bits** (todUpgShow 2, todUpgAD 6,
  todUpgAR 2, todUpgAL 4, todUpgBD 6, todUpgBR 2, todUpgBL 4, todUpgLuck 4,
  todUpgFocus 3, todUpgTime 4, todMagBonus 1, todDmgNum 14, todUpgHold 4,
  todClsShow 2, todFinaleWarn 1). Against the proven ceiling of **18 fields / 61
  bits**, a 1-bit append lands at 16 / 60 and fits with a bit to spare — and it is an
  APPEND, which is what the ceiling rule actually requires. **Do not widen
  `todUpgLuck` 4→5** — that is not an append.
- Register it in **both VMs** (`_tod_upgrade_ui.gsc:64` and `.csc:33`) — a pack whose
  CSC drifts from its GSC is a shipped bug class on this map
  (`ported-pack-both-vms`).
- A clientfield is preferred over the `LuiNotifyEvent` lane here specifically because
  the state must survive the **per-life menu rebuild** (the engine closes player LUI
  menus on death → spectate). Clientfields re-deliver on new-ent; a notify would need
  a manual re-push.
- `todMagBonus` is a **dead 1-bit field, always 0** since the mag pool was deleted —
  tempting to reuse, but the name would then lie about its contents. Append instead.
- Lua side: build a second image table beside `luckStates` / `luckOverStates`
  (`tod_upgrade.lua:1318-1335`) and pick the table from the cached rampage flag inside
  the existing `subscribeToModel` callback at `:1347`. Keep the shipped
  `USE_…_ART = true` guard pattern so a missing-art build falls back to the normal set
  instead of drawing nothing.
- **This is a FULL build**, not `-GscOnly`: 15 new image assets, 15 new
  `image,` zone lines, and GDT entries. A `.gdt` edit is always a full build.
- **"BUILD OK" does not prove the images landed.** `gdtdb /update` exits 1 on this
  machine (duplicate install-side pack GDT, 2026-08-30) and `build_map.ps1` downgrades
  it to a Warn. Verify by filename-grepping the fresh `.ff` for `i_tod_luck_rmp` with
  `i_tod_luck_10` as the control, per the `verify-assets-in-artifacts` memory.

---

## Open interpretation, and what each option costs

The ask was *"luck bar to red and max is purple"*. Since v14.9 the bar has **two**
different "max" notions, so this needs one decision:

| Reading | Purple on | New PNGs |
|---|---|---|
| **A — this doc's spec** | state 10 **and** the 4 overcharge frames | **15** |
| B — overcharge only | the 4 overcharge frames; state 10 stays red | 15 (state 10 red instead of purple) |
| C — full bar only | state 10; skip rampage overcharge frames entirely | **11** |

Every new PNG also needs an `image.gdf` block cloned from a sibling and an `image,`
zone line, so the count is the real cost driver. Option C is the cheapest complete
answer and still delivers "red bar, purple at max" — the overcharge band is a secret
150% state most players never see.

**The zero-asset alternative, offered rather than recommended:** `setRGB` on a LUI
image multiplies the texture, and the tint lane is proven on this HUD
(`tod_upgrade.lua:1445`, from the retired v2 luck segments). So the shipped amber bar
could be tinted toward red with **no new art at all**. But it multiplies against baked
amber (`PAL.luck = 1.0, 0.88, 0.25`), so the gold hot-tell at 08–09 and the molten MAX
state would go muddy or disappear — it destroys the exact art that makes the bar
readable. Cheap, and worse. Flagged because it is the user's call, not mine.
