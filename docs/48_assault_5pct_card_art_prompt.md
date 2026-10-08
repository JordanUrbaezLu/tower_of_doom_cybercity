# 48 — Assault buff (2026-08-30): HEADSHOT + GIANT SLAYER 4% → 5% per level

> **STATUS: COMPLETE 2026-08-30.** All six cards installed from the user drop
> `files (71).zip` — exact filenames, all 768×1152 RGBA, md5-verified into
> `source_data/tod_ui_images/_images/`. Contact sheet proofread clean on all four
> checks: +5/+10/+15 on both sets, 3 pips headshot / 5 pips giant slayer, no
> subline anywhere, value-line colour white/violet/gold by rarity. Two spot-checked
> at full size against the outgoing art — pixel-faithful, only the value line moved.
> No wiring was needed. FULL build 15:22:22; reconversion proven by fresh
> content-addressed `.iwi` files at 15:21:44 with an untouched control that did not
> move. Nothing outstanding.

**User brief:** *"buff the headshot and boss damage upgrades for the assault
class from 4% to 5% each level."*

Code, Lua and docs are already on 5%/Lv. **The six cards below still read the
old numbers and are the only thing outstanding.** Until they are re-baked the
game advertises a value it no longer pays — the exact failure `docs/33` has now
recorded four times.

## What must be re-baked

| domain | id | max Lv | old | **new** | cards |
|---|---|---|---|---|---|
| HEADSHOT | 6 | 10 | +4% / Lv | **+5% / Lv** | 3 |
| GIANT SLAYER | 35 | 5 | +4% / Lv | **+5% / Lv** | 3 |

**Six files, all RE-BAKES at identical filenames** — so there is **no wiring
work at all**: no `image.gdf` block, no zone line, no `CARD_SLUG`, no
`PAUSE_PLATE_MAX`. Drop the PNGs into `source_data/tod_ui_images/_images/`,
overwriting, and rebuild.

```
i_tod_card_headshot_regular.png       i_tod_card_headshot_super.png       i_tod_card_headshot_ultimate.png
i_tod_card_giant_slayer_regular.png   i_tod_card_giant_slayer_super.png   i_tod_card_giant_slayer_ultimate.png
```

**The pause plates do NOT change.** `i_tod_pause_r06.png` / `i_tod_pause_r35.png`
are 300×44 name-only strips with no numbers on them. The pause-menu *numbers*
come from the Lua `DETAIL` table, which is already updated (`5 * l` on both
rows). `i_tod_up_headshot.png` is icon-only.

## Exact text, per card

**Verified by opening the shipped PNGs on 2026-08-30**, not by trusting this
directory's older prompt docs — `docs/35` still describes a `4% PER LEVEL`
subline that `docs/40` removed from the whole set. **There is no subline on
these cards today. Do not reintroduce one.**

| file | current value line | **new value line** |
|---|---|---|
| `i_tod_card_headshot_regular.png` | `+4%  HEADSHOT DMG` | **`+5%  HEADSHOT DMG`** |
| `i_tod_card_headshot_super.png` | `+8%  HEADSHOT DMG` | **`+10%  HEADSHOT DMG`** |
| `i_tod_card_headshot_ultimate.png` | `+12%  HEADSHOT DMG` | **`+15%  HEADSHOT DMG`** |
| `i_tod_card_giant_slayer_regular.png` | `+4%  BOSS DAMAGE` | **`+5%  BOSS DAMAGE`** |
| `i_tod_card_giant_slayer_super.png` | `+8%  BOSS DAMAGE` | **`+10%  BOSS DAMAGE`** |
| `i_tod_card_giant_slayer_ultimate.png` | `+12%  BOSS DAMAGE` | **`+15%  BOSS DAMAGE`** |

Both domains are **linear** (`val(l) == l * val(1)`), so a pre-multiplied
per-rarity increment stays true at every level — these cards need no ladder and
no range. No `· MAX` on either set: GIANT SLAYER's ULTIMATE grants +3 of 5
levels, which does not always land on the ceiling.

## Pip counts — different between the two sets, and both are correct

- **HEADSHOT: 3 pips.** Max is 10, and the set's convention for max-10 domains
  is a flat three pips reading "+N levels from this card" (ten pips are
  illegible at the 213×320 display size). Lit = 1 / 2 / 3 by rarity.
- **GIANT SLAYER: 5 pips.** Max is 5, and domains with max ≤ 6 carry pips = the
  domain's max. Lit = 1 / 2 / 3 by rarity.

Say this explicitly in any prompt or the reference image silently normalises
both to three.

---

## THE PROMPT (paste this to the image agent)

The prompt below names the reference PNGs by absolute path and *also* carries a
full written spec, because the user does not attach files.

> You are re-baking six cards from an existing upgrade-card set for a Call of
> Duty: Black Ops III custom zombies map. **This is a TEXT-ONLY revision.**
> Reproduce each card exactly as it already is and change ONLY the single line
> of text in the bottom value panel. Do not redraw, restyle, recolour, re-crop
> or "improve" the illustration, the frame, the title plate, the rarity banner,
> the medallion or the pips.
>
> **Open these files first — they are the target style AND the target artwork:**
>
> ```
> c:\Users\jorda\Repositories\tower_of_doom_cybercity\source_data\tod_ui_images\_images\i_tod_card_headshot_regular.png
> c:\Users\jorda\Repositories\tower_of_doom_cybercity\source_data\tod_ui_images\_images\i_tod_card_headshot_super.png
> c:\Users\jorda\Repositories\tower_of_doom_cybercity\source_data\tod_ui_images\_images\i_tod_card_headshot_ultimate.png
> c:\Users\jorda\Repositories\tower_of_doom_cybercity\source_data\tod_ui_images\_images\i_tod_card_giant_slayer_regular.png
> c:\Users\jorda\Repositories\tower_of_doom_cybercity\source_data\tod_ui_images\_images\i_tod_card_giant_slayer_super.png
> c:\Users\jorda\Repositories\tower_of_doom_cybercity\source_data\tod_ui_images\_images\i_tod_card_giant_slayer_ultimate.png
> ```
>
> Output the same six filenames, overwriting.
>
> ### The only change
>
> | file | change the value line FROM | TO |
> |---|---|---|
> | `i_tod_card_headshot_regular.png` | `+4%  HEADSHOT DMG` | `+5%  HEADSHOT DMG` |
> | `i_tod_card_headshot_super.png` | `+8%  HEADSHOT DMG` | `+10%  HEADSHOT DMG` |
> | `i_tod_card_headshot_ultimate.png` | `+12%  HEADSHOT DMG` | `+15%  HEADSHOT DMG` |
> | `i_tod_card_giant_slayer_regular.png` | `+4%  BOSS DAMAGE` | `+5%  BOSS DAMAGE` |
> | `i_tod_card_giant_slayer_super.png` | `+8%  BOSS DAMAGE` | `+10%  BOSS DAMAGE` |
> | `i_tod_card_giant_slayer_ultimate.png` | `+12%  BOSS DAMAGE` | `+15%  BOSS DAMAGE` |
>
> The panel holds **ONE line only**. There is no second/subline row on these
> cards — do not add one. The percentage and the label are separated by a wide
> gap (about two spaces), the percentage sits left of centre, and the pair is
> centred in the panel as a unit. `+10%` and `+15%` are one character wider than
> the values they replace: keep the same font size and let the line stay
> centred; do not shrink the text and do not let it touch the panel border.
>
> ### Written spec (fallback, and the consistency contract)
>
> - **Canvas 768 × 1152, PNG, RGBA.** Fully transparent outside the card body
>   and outside its outer glow. Card centred with a small transparent margin so
>   the glow is not clipped.
> - Flat vector cartoon / mobile-game-card style. **Thick black outlines**, flat
>   fills, no photorealism, no drop shadows on text. Heavy condensed display
>   sans, **ALL CAPS**, black outline on all text.
> - **Layout, top to bottom:** card body (rounded rect, near-black navy `#1e2140`,
>   heavy black outline, soft outer glow in the rarity colour) → title plate
>   (orange→amber vertical gradient pill, black outline, row of circular studs
>   along its top edge, name in white outlined caps) → art window (large inset
>   rounded panel, dark blue-navy, faint radial highlight top, thin
>   rarity-coloured inner border, decorative pixel squares: cyan top-left, white
>   top-right, small orange bottom-left) → the illustration, centred → star
>   medallion (circular coin with a five-point star) overlapping the art
>   window's **bottom-right** corner → rarity banner (pill with notched arrow
>   points both sides, bold white outlined caps) → bottom value panel (inset
>   dark plate, rounded inner border, a small screw stud in each of its four
>   corners) → pip row → cross-head corner bolts in the four corners of the card
>   body, and thin vertical rounded accent bars on the left and right edges in
>   the rarity colour.
> - **RARITY DRIVES THREE THINGS AND ONLY THREE:** the outer glow / accent bars /
>   art-window border colour, the rarity banner, and **the colour of the value
>   line**. The illustration keeps its own colours in every rarity.
>
>   | rarity | banner text | glow + accents | **value-line colour** | medallion |
>   |---|---|---|---|---|
>   | REGULAR | `REGULAR +1` | white / pale grey | **white** | silver |
>   | SUPER | `SUPER +2` | violet | **violet** | gold |
>   | ULTIMATE | `ULTIMATE +3` | gold / amber | **gold** | gold |
>
> - **Pips — the two sets differ, and both are correct:**
>   - `headshot` cards: **3 pips**, lit 1 / 2 / 3 for REGULAR / SUPER / ULTIMATE.
>   - `giant_slayer` cards: **5 pips**, lit 1 / 2 / 3 for REGULAR / SUPER /
>     ULTIMATE (so REGULAR shows 1 lit + 4 dark).
>   - Lit pips glow in the rarity colour; unlit pips are dark navy sockets.
> - **Titles:** `HEADSHOT` and `GIANT SLAYER`, unchanged.
> - **Illustrations, unchanged:** headshot = a white cartoon skull with a
>   magenta crosshair over its right eye socket, on dark navy, with small yellow
>   and red angular accent marks around it. Giant slayer = a large grey-blue
>   cartoon mech/robot seen head-on with an orange impact starburst and a bullet
>   striking its chest plate.
>
> Deliver **`i_tod_card_headshot_ultimate.png` first, on its own**, so the style
> match can be checked before the other five are generated.

---

## Install + proofread checklist

1. **One card first** (`headshot_ultimate`), compared at full size against the
   outgoing PNG — only the value line may have moved.
2. Overwrite in `source_data/tod_ui_images/_images/`. **Nothing else to wire.**
3. Proofread the contact sheet on four points:
   - HEADSHOT reads **+5 / +10 / +15**, never 4/8/12, on **3** pips.
   - GIANT SLAYER reads **+5 / +10 / +15** on **5** pips.
   - **No subline on any of the six.**
   - Value-line colour is white / violet / gold by rarity, not by domain.
4. All six are 768 × 1152 RGBA with a transparent margin.
5. A card re-bake is a **FULL build** (`.gdt`-fed image assets), not `-GscOnly`.
