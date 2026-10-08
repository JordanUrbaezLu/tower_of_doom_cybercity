# 37 — SCAVENGER card re-bake (2026-08-27): say what the upgrade actually does

> **STATUS: COMPLETE 2026-08-27.** Installed from the user drop and shipped in
> v12.10. The ULTIMATE was additionally brought into line with its siblings the
> same day (it read NEVER RUN DRY where the other two read AMMO BACK ON KILLS) —
> the whole deck now states what an upgrade DOES on every rarity.

The user's brief: *"Lets do a new prompt if its easier for players to understand
what upgrade they are actually choosing."*

## Why these three cards needed it

SCAVENGER was the only card in the deck whose text did not tell you what you were
buying. The outgoing art read:

| rarity | value plate before |
|---|---|
| regular | `AMMO BACK` / `ON KILLS` |
| super | `AMMO BACK` / `ON KILLS` |
| ultimate | `NEVER` / `RUN DRY` |

Two problems, the second new as of 2026-08-27:

1. **No rate, no progression.** "Ammo back on kills" is true of the upgrade at
   every level from 1 to 6, so it told a player nothing about whether to take it.
2. **It did not mention that the refund is CLASS PRIMARY ONLY.** A sidearm kill
   pays nothing and does not even advance the counter. That is a real restriction
   a player must know BEFORE choosing, and it appeared nowhere but the pause menu.

## The layout fix, which was also the clarity fix

Every other card uses the value plate as **one big value line + one smaller
wide-spaced subline** (`+4%  HEADSHOT DMG` over `4% PER LEVEL`). SCAVENGER was
the odd one out, spending both lines on one phrase and getting no subline at all.
Converting it to the standard treatment bought a whole line of information with
no layout invention.

**Why the subline carries no number.** Every other domain is linear, so a card
can state a constant increment that stays true wherever you are on the ladder.
SCAVENGER is not — 1 per 5, 1 per 4, 1 per 3, 1 per 2, 1 per kill, then 3 per 2
at the assault-only Lv6 — so ANY single number printed on the card is wrong for
most players who see it. `FASTER EACH LEVEL` is the honest version; the exact
current rate is one keypress away in the pause menu, read live from
`scav_kills_needed()`.

Filenames key off the INTERNAL domain key `reserve`, not the display name
SCAVENGER — long-standing, since `domain_id` 8, `CARD_SLUG[8]` and every existing
image name key off it.

---

## THE PROMPT

Attach as references: **`i_tod_card_reserve_regular.png`**,
**`i_tod_card_reserve_super.png`**, **`i_tod_card_reserve_ultimate.png`** (the
three being revised), and **`i_tod_card_headshot_regular.png`** (the target
value-plate layout: one big line over one small subline).

> You are revising three cards from an existing upgrade-card set for a Call of
> Duty: Black Ops III custom zombies map. **The attached SCAVENGER images ARE the
> target style and the target artwork — this is a text revision, not a redesign.**
> Reproduce each card exactly as it is and change only the contents of the bottom
> value plate.
>
> **The change, precisely:**
>
> Each SCAVENGER card's value plate currently holds ONE phrase set as two big
> centred lines — `AMMO BACK` / `ON KILLS`, or `NEVER` / `RUN DRY` on the
> ultimate — and no subline.
>
> Replace that with the deck's standard two-part treatment: **one large bold
> value line, and beneath it one smaller, wider-letter-spaced subline** in a pale
> desaturated blue-grey. The fourth attached image
> (`i_tod_card_headshot_regular.png`) shows exactly this treatment — match its
> relative sizes, spacing and vertical placement within the plate. Do not copy
> anything else from it: its title, illustration, colour and pip row belong to a
> different upgrade.
>
> The new plate contents, per card:
>
> - `i_tod_card_reserve_regular.png` — big: `AMMO BACK ON KILLS` · small:
>   `CLASS PRIMARY ONLY · FASTER EACH LEVEL`
> - `i_tod_card_reserve_super.png` — big: `AMMO BACK ON KILLS` · small:
>   `CLASS PRIMARY ONLY · FASTER EACH LEVEL`
> - `i_tod_card_reserve_ultimate.png` — big: `NEVER RUN DRY` · small:
>   `CLASS PRIMARY ONLY · FASTER EACH LEVEL`
>
> The big line must fit on ONE line — condense the letterforms slightly if needed
> rather than wrapping to two, and rather than shrinking it below the size the
> reference cards use for their big value line.
>
> **Everything else on all three cards must come back pixel-identical.** Do not
> redraw, restyle, recolour, re-crop or "improve" any of it. Specifically
> unchanged: the outer body and its border, the four corner screws, the amber
> title plate with its seven rivets, the word `SCAVENGER` and its letterforms, the
> screen panel with its scanlines, sheen and corner pixel squares, the
> illustration, the ribbon and its arrowhead notches, the rarity text, the star
> medal, the value plate's own shape/outline/bolts, the pip row, the side light
> bars, and every glow, sparkle and chevron belonging to the rarity frame.
>
> **The illustration — reproduce exactly as in the references:** a chunky flat
> vector cartoon of an open brown ammo crate seen from the front, thick black
> outline, with its lid tilted open to the upper left, a small yellow star on its
> near rim, a dashed seam line and a small amber latch on its face. Four
> orange-and-yellow rifle rounds arc up and out of it, the tallest standing
> upright at centre. A thick cyan arc sweeps up and over the crate from lower left
> to right, reading as ammunition returning. Flat fills, no gradients inside the
> shapes, no texture, no realism.
>
> **Canvas:** 768 × 1152 px portrait PNG, transparent everywhere outside the
> card's rounded outer edge, with a small transparent margin all round — larger on
> SUPER and ULTIMATE to hold their glow.
>
> **The three rarity frames, unchanged from the references:**
>
> - **REGULAR (+1)** — no outer glow, plain dark navy frame, **silver/light-grey**
>   ribbon reading `REGULAR +1`, **silver** star medal, two slim **cyan** vertical
>   light bars down the outer edges, muted teal value-plate inner outline, big line
>   in **pale silver-white**, **1 of 3** pips lit in white, no sparkles.
> - **SUPER (+2)** — soft **violet/lavender outer glow**, purple line in the frame
>   border, **purple** ribbon reading `SUPER +2`, **gold** star medal, **purple**
>   side light bars, purple value-plate inner outline, big line in **bright
>   purple/orchid**, **2 of 3** pips lit in purple, and the two small purple bent
>   "kick" chevrons floating in the screen panel (upper-left and lower-right).
> - **ULTIMATE (+3)** — warm **gold/peach outer glow**, **gold** frame border,
>   small four-pointed sparkle stars scattered around the border margin (both black
>   and gold), **orange** ribbon reading `ULTIMATE +3`, **gold** star medal,
>   **gold** side light bars, gold value-plate inner outline, big line in **golden
>   yellow**, **3 of 3** pips lit in gold, and the bent kick chevrons in the screen
>   panel — one red at mid-left, one yellow upper-left, one yellow lower-right —
>   plus the extra tiny amber pixel squares.
>
> **Typography:** every piece of text is the same heavy rounded sans-serif, all
> caps. The big value line is coloured per rarity and has no outline. The subline
> is noticeably smaller, letter-spaced wide, and pale blue-grey on all three cards
> regardless of rarity. Use a middle dot `·` with a space either side between the
> subline's two clauses, exactly as the reference card does.
>
> **Deliverables:** first a single **contact sheet** showing all three cards at
> small size so the plates can be proofread side by side, then the three full-size
> 768 × 1152 PNGs named exactly:
>
> ```
> i_tod_card_reserve_regular.png    AMMO BACK ON KILLS / CLASS PRIMARY ONLY · FASTER EACH LEVEL / 3 pips, 1 lit
> i_tod_card_reserve_super.png      AMMO BACK ON KILLS / CLASS PRIMARY ONLY · FASTER EACH LEVEL / 3 pips, 2 lit
> i_tod_card_reserve_ultimate.png   NEVER RUN DRY      / CLASS PRIMARY ONLY · FASTER EACH LEVEL / 3 pips, 3 lit
> ```
>
> SCAVENGER's real level cap is 5 (6 for one class), but the card shows a flat
> **3** pips — that is correct and matches the outgoing art and the rest of the
> deck. Do not change the pip count.

---

## Proofreading checklist (run against the contact sheet before installing)

1. **All three cards now have a SUBLINE** where the outgoing art had only a
   two-line big phrase. This is the whole point of the job.
2. Every subline reads `CLASS PRIMARY ONLY · FASTER EACH LEVEL` — identical on all
   three, pale blue-grey on all three (it does NOT take the rarity colour).
3. Big lines: `AMMO BACK ON KILLS`, `AMMO BACK ON KILLS`, `NEVER RUN DRY` — and
   each sits on ONE line, not wrapped.
4. No card states a kills-per-round NUMBER. If one appears, it is wrong for most
   levels — reject it.
5. Filenames use `reserve`, not `scavenger`.
6. Pips: 3 total on every card; 1 / 2 / 3 lit; lit colour white / purple / gold.
7. The title plate still reads `SCAVENGER` and the ammo-crate illustration is
   unchanged in all three.
8. All three are 768 × 1152 with transparent surrounds.

## After installing

New image source files mean a **full build** (`.\tools\build_map.ps1`), not
`-GscOnly`. Drop the three PNGs into `source_data/tod_ui_images/_images/`
overwriting. No wiring needed — same filenames, so the GDT blocks and zone lines
already exist.

Proof the art reached the `.ff`: check for a NEW content-hash `.iwi` per name in
`<modtools>\share\assetconvert\image\v29\` at build time. A new hash proves
conversion; note that the ABSENCE of one proves nothing (it cannot distinguish
"not zoned" from "content already cached").
