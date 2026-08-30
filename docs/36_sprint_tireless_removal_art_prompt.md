# 36 — SPRINT card re-bake (2026-08-26): the TIRELESS line comes off

> **STATUS: COMPLETE 2026-08-26.** All three cards installed from the user drop
> `files (47).zip` — exact filenames, all 768×1152, md5-verified into
> `source_data/tod_ui_images/_images/`. The contact sheet (`sprint_check.png`)
> proofread clean against the checklist at the bottom of this file, and the
> regular + ultimate were opened at full size against the outgoing art:
> pixel-faithful, only the value plate moved. Outgoing art backed up to the
> session scratchpad before overwriting.
>
> Built and verified in the 23:03:58 full build. Proof the art actually reached
> the `.ff` (which cannot itself be grepped — it is a compressed container): the
> content-hashed image converter emitted a NEW `.iwi` for all three names at
> 23:03, alongside the older hashes from 08-20 and 08-24 —
> e.g. `i_tod_card_sprint_regular_W6FPG576DSAQ6ZZQYLBXODYQYJ.iwi`. A cache HIT
> would have left the timestamps untouched. Nothing outstanding.

The user's brief: *"for sprint we are saying skirmisher gets unlimited. That
does work and we tried to implement multiple times. Lets just remove that
benefit so skirmisher doesnt get that extra benefit. I know we will need new
assets for this one."*

## What changed

TIRELESS — the Lv5 unlimited-sprint rider on the SPRINT domain — was removed
outright. SPRINT is now **+5% move speed per level and nothing else**, identical
for both classes that can roll it (skirmisher and slasher). The value line on
all three cards is therefore **still correct**; what is wrong is the second line.

All three SPRINT cards carry a subline reading:

```
LV 5 TIRELESS · SKIRMISHER
```

That line now advertises a benefit the game does not grant. It must come off.

## THE JOB IS THREE FILES, AND IT IS A DELETION

| file | value line (UNCHANGED) | subline |
|---|---|---|
| `i_tod_card_sprint_regular.png` | `+5%  MOVE SPEED` | **delete** |
| `i_tod_card_sprint_super.png` | `+10%  MOVE SPEED` | **delete** |
| `i_tod_card_sprint_ultimate.png` | `+15%  MOVE SPEED` | **delete** |

Re-bakes at **identical filenames**, so there is **zero wiring work**: no
`image.gdf` block, no zone line, no `CARD_SLUG`, no `PAUSE_PLATE_MAX`. Drop the
PNGs into `source_data/tod_ui_images/_images/`, overwriting, and rebuild.

**Nothing else in the SPRINT set needs re-baking**, verified by opening each
file rather than trusting this doc's ancestors:

- `i_tod_pause_r05.png` — a 300×44 name-only strip reading just `SPRINT`. No
  numbers, no rider text. The pause menu's *numbers* come from the Lua DETAIL
  table, which is already updated.
- `i_tod_up_sprint.png` — icon only: a cyan boot with three speed lines. No text.

## THE TARGET ALREADY EXISTS IN THE DECK

**`i_tod_card_mobility_*` is the exact answer to "what should the plate look
like with no subline".** MOBILITY is the heavy's +5%/Lv move-speed domain — the
same effect, the same value line text, and it has never had a rider. Its value
plate holds **one centred line and nothing else**, vertically centred in the
plate rather than sitting high in it.

So this job is not a design decision. It is: make SPRINT's value plate match
MOBILITY's value plate. Attach the MOBILITY card and the answer is on it.

---

## THE PROMPT

Attach as references, in this order: **`i_tod_card_sprint_regular.png`**,
**`i_tod_card_sprint_super.png`**, **`i_tod_card_sprint_ultimate.png`** (the
three cards being revised — all three rarity frames), and
**`i_tod_card_mobility_regular.png`** (the target value-plate layout).

> You are revising three cards from an existing upgrade-card set for a Call of
> Duty: Black Ops III custom zombies map. **The attached SPRINT images ARE the
> target style and the target artwork — this is a text-deletion revision, not a
> redesign.** Reproduce each card exactly as it is and make one single change:
> **remove the small second line of text from the bottom value plate.**
>
> **The change, precisely:**
>
> Each SPRINT card's value plate currently holds two centred lines:
>
> - a large bold value line — `+5%  MOVE SPEED`, `+10%  MOVE SPEED`,
>   `+15%  MOVE SPEED`
> - beneath it a smaller, wide-letter-spaced pale blue-grey subline reading
>   `LV 5 TIRELESS · SKIRMISHER`
>
> **Delete that subline entirely** and **re-centre the remaining value line
> vertically within the value plate**, so it sits in the optical middle of the
> panel instead of riding high where it sat when there were two lines. The value
> line's own text, size, weight, colour and horizontal centring do **not**
> change — only its vertical position, and only because it is now alone.
>
> **The fourth attached image (`i_tod_card_mobility_regular.png`) is the exact
> target for this plate.** It is a different card from the same deck whose value
> plate already holds a single centred `+5%  MOVE SPEED` line with no subline.
> Match its value-plate treatment — the same vertical centring, the same line
> size relative to the plate, the same amount of breathing room above and below.
> Do not copy anything else from it: its title, illustration and pip row belong
> to a different upgrade.
>
> **Everything else on all three SPRINT cards must come back pixel-identical.**
> Do not redraw, restyle, recolour, re-crop or "improve" any of it. Specifically
> unchanged: the outer body and its border, the four corner screws, the amber
> title plate and its seven rivets, the word `SPRINT` and its letterforms, the
> screen panel with its scanlines, sheen and corner pixel squares, the
> illustration, the ribbon and its arrowhead notches, the rarity text, the star
> medal, the value plate's own shape/outline/bolts, the pip row, the side light
> bars, and every glow, sparkle and chevron belonging to the rarity frame.
>
> **The illustration — reproduce exactly as in the references:** a chunky flat
> vector cartoon of a **running shoe / boot in profile facing right**, in
> saturated orange with a thick black outline and a yellow rounded heel cap,
> sitting on a cyan ground bar with a small grey dot on it. Three cyan
> speed-streak bars trail off to the **left** of the boot, and three white
> arrowhead chevrons point left between them, reading as motion. Flat fills, no
> gradients inside the shapes, no texture, no realism.
>
> **Canvas:** 768 × 1152 px portrait PNG, transparent everywhere outside the
> card's rounded outer edge, with a small transparent margin all round — larger
> on SUPER and ULTIMATE to hold their glow.
>
> **The three rarity frames, unchanged from the references:**
>
> - **REGULAR (+1)** — no outer glow, plain dark navy frame, **silver/light-grey**
>   ribbon reading `REGULAR +1`, **silver** star medal, two slim **cyan** vertical
>   light bars down the outer edges, muted teal value-plate inner outline, value
>   line in **pale silver-white**, **1 of 3** pips lit in white, no sparkles.
> - **SUPER (+2)** — soft **violet/lavender outer glow**, purple line in the
>   frame border, **purple** ribbon reading `SUPER +2`, **gold** star medal,
>   **purple** side light bars, purple value-plate inner outline, value line in
>   **bright purple/orchid**, **2 of 3** pips lit in purple, and the two small
>   purple bent "kick" chevrons floating in the screen panel (upper-left and
>   lower-right).
> - **ULTIMATE (+3)** — warm **gold/peach outer glow**, **gold** frame border,
>   small four-pointed sparkle stars scattered around the border margin (both
>   black and gold), **orange** ribbon reading `ULTIMATE +3`, **gold** star
>   medal, **gold** side light bars, gold value-plate inner outline, value line
>   in **golden yellow**, **3 of 3** pips lit in gold, and the bent kick chevrons
>   in the screen panel — one red at mid-left, one yellow upper-left, one yellow
>   lower-right — plus the extra tiny amber pixel squares.
>
> **Typography:** the value line is the same heavy rounded sans-serif, all caps,
> coloured per rarity, no outline, with the percentage and the label `MOVE SPEED`
> at the same size and a wide gap between them — exactly as in the references.
>
> **Deliverables:** first a single **contact sheet** showing all three cards at
> small size so the plates can be proofread side by side, then the three
> full-size 768 × 1152 PNGs named exactly:
>
> ```
> i_tod_card_sprint_regular.png     +5%   MOVE SPEED   / no subline / 3 pips, 1 lit
> i_tod_card_sprint_super.png       +10%  MOVE SPEED   / no subline / 3 pips, 2 lit
> i_tod_card_sprint_ultimate.png    +15%  MOVE SPEED   / no subline / 3 pips, 3 lit
> ```
>
> SPRINT's real level cap is 10, but the card shows a flat **3** pips — that is
> correct and matches the outgoing art and the rest of the deck's deep domains
> (10 pips would be illegible at display size). Do not change the pip count.

---

## Proofreading checklist (run against the contact sheet before installing)

1. **No card shows the words `TIRELESS` or `SKIRMISHER` anywhere.** This is the
   whole point of the job.
2. Value lines read `+5%`, `+10%`, `+15%` — unchanged, and in that order across
   regular / super / ultimate.
3. The label still reads `MOVE SPEED`, not `SPRINT SPEED`. (The outgoing art says
   MOVE SPEED; an earlier generation of this card said SPRINT SPEED and was
   re-baked away from it on 2026-08-24 — do not let it drift back.)
4. Each value line is vertically **centred** in its plate, not sitting high with
   empty space beneath where the subline used to be. Compare directly against
   `i_tod_card_mobility_regular.png`.
5. Pips: 3 total on every card; 1 / 2 / 3 lit; lit colour white / purple / gold.
6. The title plate still reads `SPRINT` and the boot illustration is unchanged in
   all three.
7. All three files are 768 × 1152 with transparent surrounds, at the exact
   filenames above.

## After installing

`-GscOnly` is **not** sufficient — new image source files mean a **full build**
(the image assets have to be reconverted). Drop the three PNGs into
`source_data/tod_ui_images/_images/`, then `.\tools\build_map.ps1`.
