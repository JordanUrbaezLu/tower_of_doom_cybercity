# 40 — Strip the card sublines (2026-08-27)

> **STATUS: PROMPT READY, ART NOT YET BAKED.**

The user's brief: *"some assets have this sub disclaimer text that I kind of
what to remove. This is what the pause menu is for. Maybe for class upgrade im
fine with but things like blood kill where it goes through each HP through level
I really dont want. Its just extra clutter when they can check in pause menu."*

## The decision

**The card says WHAT an upgrade is. The pause menu says the numbers.** The
rarity ribbon already says how much you are getting (+1/+2/+3 levels), and
`CoD.TodDomainDesc` gives the exact value AT YOUR OWN LEVEL, live, in the pause
menu. A ladder printed on the card duplicates that badly — LEECH's
`+4 · 6 · 8 · 9 · 10 HP BY LEVEL` is five numbers, four of which are wrong for
the player reading them.

So: **every upgrade card loses its subline. The value line stays.**

## This does NOT undo the level-agnostic work (docs 37, and v12.10 §11)

Worth stating plainly, because it looks like a reversal and is not. That pass
existed because a per-rarity NUMBER on a stage-table domain is wrong for anyone
above level 0. It fixed that by printing the whole ladder. **Deleting the number
entirely solves the same problem more cleanly** — a card with no figure cannot
be wrong at any level. The rule survives; only the remedy changed.

The deck is already inconsistent about this, which is the other reason to act:
DAMAGE, SPRINT and MOBILITY carry a bare value line and look clean, while
SUPPRESSING FIRE carries `FOR 1.5 SECONDS` and LEECH carries a five-step ladder.
Same deck, three different conventions.

## What changes

| | |
|---|---|
| **Strip the subline** | every `i_tod_card_<domain>_{regular,super,ultimate}.png` |
| **Keep the big value line** | untouched, re-centred in the plate |
| **KEEP the subline** | the 8 `i_tod_card_tier_*` cards — see below |
| **Skip entirely** | `echo_rounds`, `chain_lunge`, `meat_grinder` — retired domains, unreachable, not worth a bake |
| **Already clean, leave alone** | any card that has no subline today (DAMAGE, SPRINT, MOBILITY, and others) |

### Why the TIER cards keep theirs

`NEW WEAPON · ⚠ GUN UPGRADES RESET` is not a value, it is a **warning about an
irreversible cost** — taking that card zeroes every gun-scoped upgrade the player
holds, which is 29 of the 33 domains. It was deliberately made loud on
2026-08-27 for exactly that reason, and a player has 15 seconds to decide. It
stays.

### The one judgement call

`i_tod_card_reserve_*` (SCAVENGER) carries `CLASS PRIMARY ONLY · FASTER EACH
LEVEL`. The first half is a RESTRICTION, not a value: a sidearm kill pays
nothing and does not even advance the counter. By the rule above it goes, and the
pause menu does state it (`class primary kills only, 1 per shot`). If the user
would rather keep restrictions on the card the way the tier warning is kept, the
variant is: SCAVENGER keeps `CLASS PRIMARY ONLY` alone, dropping only
`· FASTER EACH LEVEL`. Decide before baking; do not ship both conventions.

## The live domains (33) whose cards are in scope

adrenaline, back_armor, bounty, bullet_feed, cleave, damage, dmg_reduction,
draw_cut, fire_rate, giant_slayer, handling, headshot, impact_rounds,
kill_reload, knife_speed, leech, luck, mag_size, march, mobility, momentum,
overdrive, penetration, recoil, regen, reserve, run_and_gun, second_wind,
sprint, sprint_armor, sprint_fire, suppressing_fire, thors_thunder

---

## THE PROMPT

Attach the full card set, plus `i_tod_card_damage_regular.png` as the target
(it already has the bare single-line plate this pass is standardising on).

> You are revising an existing upgrade-card set for a Call of Duty: Black Ops III
> custom zombies map. **The attached images ARE the target style and the target
> artwork — this is a text-removal revision, not a redesign.** Reproduce each card
> exactly as it is and make one change only.
>
> **THE CHANGE: delete the small subline from the bottom value plate.**
>
> Each card's value plate holds a large bold value line and, beneath it, a
> smaller wide-letter-spaced subline in pale blue-grey — things like
> `4% PER LEVEL`, `FOR 1.5 SECONDS`, `KICK REDUCED`, or a ladder such as
> `+4 · 6 · 8 · 9 · 10 HP BY LEVEL`. **Remove that second line entirely** and
> **re-centre the remaining value line vertically in the plate**, so it sits in
> the optical middle instead of riding high where it sat when there were two
> lines.
>
> The value line's own text, size, weight, colour and horizontal centring do NOT
> change — only its vertical position, and only because it is now alone.
> `i_tod_card_damage_regular.png` is attached as the exact target for the
> resulting plate: one centred line, nothing beneath it. Match its treatment.
>
> **DO NOT TOUCH THESE:**
> - the eight `i_tod_card_tier_*` cards — their `NEW WEAPON · GUN UPGRADES RESET`
>   subline is a deliberate warning and must stay exactly as it is
> - any card that already has only one line in its plate — leave it byte-identical
> - `i_tod_card_echo_rounds_*`, `i_tod_card_chain_lunge_*`,
>   `i_tod_card_meat_grinder_*` — retired upgrades, not in the game
>
> **Everything else must come back pixel-identical.** Do not redraw, restyle,
> recolour, re-crop or "improve" any of it. Specifically unchanged on every card:
> the outer body and its border, the four corner screws, the amber title plate
> with its seven rivets, the domain name and its letterforms, the screen panel
> with its scanlines, sheen and corner pixel squares, **the illustration**, the
> ribbon and its arrowhead notches, the rarity text, the star medal, the value
> plate's own shape/outline/bolts, the pip row and its lit count, the side light
> bars, and every glow, sparkle and chevron belonging to the rarity frame.
>
> **Canvas:** 768 × 1152 px portrait PNG each, transparent everywhere outside the
> card's rounded outer edge, preserving each card's existing outer-glow margin
> (larger on SUPER and ULTIMATE).
>
> **Deliverables:** first a contact sheet of every card you changed, at small
> size, so the plates can be proofread in one pass — then the full-size PNGs at
> their exact existing filenames.

---

## Proofreading checklist

1. **No upgrade card has a second line in its value plate.** The only cards with
   two lines are the eight `i_tod_card_tier_*`.
2. Every remaining value line is vertically CENTRED, not sitting high with empty
   space beneath it. Compare against `i_tod_card_damage_regular.png`.
3. Value line text, colour and size unchanged from the outgoing art on every card.
4. Pip counts unchanged — they are NOT uniform: PENETRATION and RECOIL carry 2,
   SPRINT FIRE carries 1, everything else 3.
5. Tier cards untouched, warning intact and still amber/bold with its glyph.
6. Retired domains not included in the drop.
7. All files 768 × 1152 with transparent surrounds, exact existing filenames.

## After installing

New image sources mean a **FULL build** (`.\tools\build_map.ps1`), not
`-GscOnly` — the asset passes have to reconvert them. This is NOT a `.gdt`
change: the `image.gdf` blocks already exist and point at these paths, so a PNG
swap edits no GDT and needs no wiring.

Proof the art reached the `.ff`: a NEW content-hash `.iwi` per name appears in
`<modtools>\share\assetconvert\image\v29\`. A new hash proves conversion; the
ABSENCE of one proves nothing (it cannot distinguish "not zoned" from "content
already cached").

**The pause menu carries the detail now, so it must stay correct** — the DETAIL
table in `tod_upgrade.lua` is the only place a player can read an exact value
once this ships. A domain retune that skips it now costs the player the number
entirely, not just a stale one.
