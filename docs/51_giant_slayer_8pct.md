# 51 — GIANT SLAYER 5% → 8% per level (2026-08-31, v14.51)

> **STATUS: COMPLETE 2026-08-31.** Code, Lua, armory and all three cards landed
> in the same change. Art arrived as `files (75).zip`, md5-verified into
> `source_data/tod_ui_images/_images/` at the same filenames, contact sheet
> proofread clean on all four checks. `verify_armory_constants.js` 23/23,
> `lint_tod_arity.js` clean. **Outstanding: the FULL build.**

**User brief:** *"Can we buff the giant slayer percentages to 8% per level?"*

| domain | id | max Lv | old | **new** | maxed |
|---|---|---|---|---|---|
| GIANT SLAYER | 35 | 5 | +5% / Lv | **+8% / Lv** | +25% → **+40%** |

## Why this was a cheap retune

GIANT SLAYER is the one boss-damage domain that **is not hand-copied**. Both
lanes route through `tod_upgrades::boss_damage_bonus()`, which owns the constant
*and* the triad test — the function-instead-of-constant decision recorded at
`_tod_upgrades.gsc:1378-1386` exists precisely so this retune touches one number.
Contrast DAMAGE (0.12) and HEADSHOT (0.05), which `_tod_bosses::rp_damage_feed`
carries as literal copies and which have gone stale once already.

**So there is exactly ONE authoritative number in GSC**, not two:

```
_tod_upgrades.gsc:195   #define TOD_UPG_BOSSDMG_PER_LVL 0.08
```

## Every site changed

| # | file:line | what |
|---|---|---|
| 1 | `_tod_upgrades.gsc:195` | **`TOD_UPG_BOSSDMG_PER_LVL 0.05 → 0.08`** — the only live number |
| 2 | `_tod_upgrades.gsc:696` | `add_domain` description string `+5%` → `+8%` (this is what the deal HUD reads) |
| 3 | `_tod_upgrades.gsc:180-181, 691-692, 3772` | prose comments quoting the rate / the `+25%` maxed figure |
| 4 | `_tod_upgrade_ui.gsc:415` | id-map comment |
| 5 | `tod_upgrade.lua:144` | `DOMAIN[35].desc` — pause-menu name row |
| 6 | `tod_upgrade.lua:307` | `DETAIL[35].val = function(l) return 8 * l end` — pause-menu number |
| 7 | `docs/armory.html:426-428` | `eff`, `lad:lin(8,5)`, `tune:"…0.08"` |
| 8 | `docs/armory.html:1022, 1031-1033, 1080` | peak-DPS condition rows `0.25 → 0.40` and the `+25% → +40%` prose |
| 9 | 3 × card PNG | see below |

**`_tod_bosses.gsc:2724` was NOT edited** — it is a comment only, and it
correctly says the value arrives via `boss_damage_bonus()` rather than naming a
literal. Its parenthetical "5%/Lv since 2026-08-30" is now stale by one revision;
left alone because a peer session held that file's build lane at the time.
Harmless (no number is consumed from it), but worth sweeping on the next touch.

## The cards — RE-BAKES at identical filenames, zero wiring

No `image.gdf` block, no zone line, no `CARD_SLUG`, no `PAUSE_PLATE_MAX`. The
value line on these cards is **pre-multiplied per rarity** (rate × levels
granted), not the per-level rate:

| file | old | **new** |
|---|---|---|
| `i_tod_card_giant_slayer_regular.png` | `+5%  BOSS DAMAGE` | **`+8%  BOSS DAMAGE`** |
| `i_tod_card_giant_slayer_super.png` | `+10%  BOSS DAMAGE` | **`+16%  BOSS DAMAGE`** |
| `i_tod_card_giant_slayer_ultimate.png` | `+15%  BOSS DAMAGE` | **`+24%  BOSS DAMAGE`** |

All three 768×1152 RGBA, byte-identical to the drop by md5. **5 pips** (domain
max is 5, and max ≤ 6 domains carry pips = max), lit 1/2/3 by rarity — unchanged,
because the max did not move. **No subline** (docs/40 removed it from the whole
set; do not reintroduce one). The domain is linear, so a pre-multiplied
per-rarity increment stays true at every level — no ladder, no range, no `· MAX`
(ULTIMATE grants +3 of 5, which does not always land on the ceiling).

## Build

**FULL build required** — image assets. `-GscOnly` skips cod2map64 and the LED
bake, and per-asset conversion coverage under it is unproven. Prove the
reconversion the usual way: fresh content-addressed `.iwi` files plus an
untouched control that did not move (memory `verify-assets-in-artifacts`).

## Balance note (recorded, not acted on)

This widens the lane the assault is already strongest in. Measured against the
Panzer at r30 with DAMAGE 10, the assault was already out-damaging the slasher
roughly 4:1 (`TOD_MELEE_BOSS_MULT 0.33` compounds with the mechz body re-scale
`TOD_PANZER_BODY_SCALE / 0.1` = ×0.35, so melee lands at ×0.1155 on a Panzer).
The buff moves a maxed assault's boss-headshot multiplier from ×2.95 to ×3.10 —
about **+5% boss DPS**, which is modest and safe. It does **not** address the
assault's actual deficit, which is horde clear and base T1 DPS (`CLASS_DAMAGE_MULT`
assault 1.10 on an Enfield whose raw 2,000 DPS starts 43% below the Stoner's).

**Also worth knowing:** the ARMORED SPRINTER carries **no boss/elite flag**, so
GIANT SLAYER pays nothing against it even though the card says "bosses and
elites". Hellhounds *do* carry the flag and *do* take it.
