# 60 — DMG REDUCTION card re-bake (v16, 2026-09-01)

> **STATUS: PROMPT WRITTEN, ART NOT YET DELIVERED.** Three text-only re-bakes at
> identical filenames. No wiring — `CARD_SLUG[2] = "dmg_reduction"` and the three
> zone lines have existed since the first card batch.

---

## Why this re-bake is owed

The user changed DMG REDUCTION from a flat **−5% per level** to a diminishing
ladder — **+6, +5, +4, +3, +2** per level, i.e. cumulative **−6 / 11 / 15 / 18 /
20%** at Lv1..Lv5.

The three cards currently print:

| file | value line |
|---|---|
| `i_tod_card_dmg_reduction_regular.png` | `−5% DMG TAKEN` |
| `i_tod_card_dmg_reduction_super.png` | `−10% DMG TAKEN` |
| `i_tod_card_dmg_reduction_ultimate.png` | `−15% DMG TAKEN` |

**Those numbers are not merely out of date — the card can no longer carry a
number at all.** That is the important part, and it is a different failure from
every previous re-bake.

A rarity band grants **+1 / +2 / +3 LEVELS**, so a pre-multiplied figure on a
card is a constant **increment**. That is only true when the domain is
**linear**. DR used to be: an ULTIMATE was +3 × 5% = +15pp no matter where you
started, so `−15% DMG TAKEN` was honest at every level.

On the new stage table the increment depends on where you are standing:

| you are at | an ULTIMATE (+3) takes you to | actual gain |
|---|---|---|
| Lv0 | Lv3 = 15% | **+15pp** |
| Lv1 (6%) | Lv4 = 18% | **+12pp** |
| Lv2 (11%) | Lv5 = 20% | **+9pp** |

So any single printed figure is wrong at every level except zero. This is the
LEECH trap from `docs/48` exactly — LEECH REGULAR said "+4 HP PER KILL" and paid
+2 if you took it at Lv2 — and it is why the test is
`val(l) != l * val(1)`, not "did the number change".

**The fix is the house one:** drop the figure, let the pips and the rarity banner
carry the rarity, and let the pause menu carry the number. The pause menu is
level-aware (`DETAIL[2].val` → `drPct(l)`), server-fed and always current, so the
player can still read their exact reduction — just not off the card.

This also satisfies the user's standing rule (2026-09-01): *"lets make the
prompts give generic assets so if we ever need to tweak numbers we dont need new
assets."* DR's numbers have now moved **twice in two days** (cap 10 → 5, then flat
→ ladder). It has earned a numberless card.

---

## THE PROMPT

> You are re-baking three cards from an existing upgrade-card set for a Call of
> Duty: Black Ops III custom zombies map. **This is a TEXT-ONLY revision.**
> Reproduce each card exactly as it is and change ONLY the single line of text in
> the bottom value panel. Do not touch the shield/cross illustration, the frame,
> the title plate, the rarity banner, the medallion, or the pips.
>
> | file | current value line | new value line |
> |---|---|---|
> | `i_tod_card_dmg_reduction_regular.png` | `−5% DMG TAKEN` | `TAKE LESS DAMAGE` |
> | `i_tod_card_dmg_reduction_super.png` | `−10% DMG TAKEN` | `TAKE LESS DAMAGE` |
> | `i_tod_card_dmg_reduction_ultimate.png` | `−15% DMG TAKEN` | `TAKE LESS DAMAGE` |
>
> All three get the **same** line. That is deliberate — the rarity is already
> carried by the banner (`REGULAR +1` / `SUPER +2` / `ULTIMATE +3`), the glow, and
> the number of lit pips, so the value panel does not need to repeat it. The new
> line carries **no number** on purpose: this upgrade now pays a different amount
> depending on the level you take it at, so no single figure is true, and the
> exact percentage is shown in the pause menu, which is always current.
>
> **Keep 5 pips**, lit 1 / 2 / 3 by rarity. Same font, size and colour treatment
> as the line being replaced (pale blue-white on regular, violet on super, gold on
> ultimate).
>
> **Deliver as:** PNG, 768×1152 RGBA, transparent outside the rounded frame, same
> filenames, overwriting.

---

## Install

Overwrite in `source_data/tod_ui_images/_images/`, **FULL build**, then prove the
re-convert with a **fresh content-hash `.iwi` plus an untouched control** — take
the whole `i_tod_card_*.iwi` inventory as a set before and after and diff it, so
the proof is "exactly these three appeared and nothing else moved" rather than
three filenames you went looking for. No wiring: these are already installed and
zoned.

**Pips do NOT change.** `max` is still 5, and the pip rule is *pips = max when
max ≤ 6*, so 5 pips stays correct. The v15 nerf (cap 10 → 5) is what moved them to
5, and that re-bake already landed.

## The pause plate does NOT change either

`i_tod_pause_r2` is name-only — pause plates carry the domain NAME, never a
value, so no plate re-bake is ever owed by a retune.
