# 93 — DARK UPGRADE CARDS: a fourth rarity above ULTIMATE (37 images)

<!-- art-pack
name: dark_upgrade_cards
refs:
  i_tod_card_damage_ultimate.png | DAMAGE - the ULTIMATE card. TEMPLATE SUBJECT A in Stage 1 - bright orange icon and a baked number, the hardest case for a red wash.
  i_tod_card_back_armor_ultimate.png | BACK ARMOR - the ULTIMATE card. TEMPLATE SUBJECT B in Stage 1 - cool blue-grey icon, no number.
  i_tod_card_dmg_reduction_ultimate.png | DMG REDUCTION - the ULTIMATE card to darken.
  i_tod_card_bounty_ultimate.png | BOUNTY - the ULTIMATE card to darken.
  i_tod_card_luck_ultimate.png | LUCK - the ULTIMATE card to darken.
  i_tod_card_sprint_ultimate.png | SPRINT - the ULTIMATE card to darken.
  i_tod_card_headshot_ultimate.png | HEADSHOT - the ULTIMATE card to darken.
  i_tod_card_mag_size_ultimate.png | MAG SIZE - the ULTIMATE card to darken.
  i_tod_card_reserve_ultimate.png | SCAVENGER - the ULTIMATE card to darken.
  i_tod_card_bullet_feed_ultimate.png | BULLET FEED - the ULTIMATE card to darken.
  i_tod_card_leech_ultimate.png | LEECH - the ULTIMATE card to darken.
  i_tod_card_cleave_ultimate.png | CLEAVE - the ULTIMATE card to darken.
  i_tod_card_fire_rate_ultimate.png | FIRE RATE - the ULTIMATE card to darken.
  i_tod_card_handling_ultimate.png | HANDLING - the ULTIMATE card to darken.
  i_tod_card_recoil_ultimate.png | RECOIL - the ULTIMATE card to darken. Its rifle is one of the darkest illustrations in the set.
  i_tod_card_knife_speed_ultimate.png | KNIFE SPEED - the ULTIMATE card to darken.
  i_tod_card_penetration_ultimate.png | PENETRATION - the ULTIMATE card to darken.
  i_tod_card_thors_thunder_ultimate.png | THOR'S THUNDER - the ULTIMATE card to darken.
  i_tod_card_sprint_fire_ultimate.png | SPRINT FIRE - the ULTIMATE card to darken.
  i_tod_card_run_and_gun_ultimate.png | RUN AND GUN - the ULTIMATE card to darken.
  i_tod_card_adrenaline_ultimate.png | ADRENALINE - the ULTIMATE card to darken.
  i_tod_card_overdrive_ultimate.png | OVERDRIVE - the ULTIMATE card to darken.
  i_tod_card_suppressing_fire_ultimate.png | SUPPRESSING FIRE - the ULTIMATE card to darken.
  i_tod_card_draw_cut_ultimate.png | DRAW CUT - the ULTIMATE card to darken.
  i_tod_card_second_wind_ultimate.png | SECOND WIND - the ULTIMATE card to darken.
  i_tod_card_giant_slayer_ultimate.png | GIANT SLAYER - the ULTIMATE card to darken. Its robot is the set's best-lit illustration - it must survive the wash, not blow out.
  i_tod_card_march_ultimate.png | FORCED MARCH - the ULTIMATE card to darken.
  i_tod_card_vitality_ultimate.png | VITALITY - the ULTIMATE card to darken.
  i_tod_card_recovery_ultimate.png | RECOVERY - the ULTIMATE card to darken.
  i_tod_card_perkslots_ultimate.png | PERK SLOTS - the ULTIMATE card to darken.
  i_tod_card_distraction_ultimate.png | DISTRACTION - the ULTIMATE card to darken.
  i_tod_card_full_steam_ultimate.png | FULL STEAM - the ULTIMATE card to darken. Its locomotive is already RED - the one card where a red wash can lose the subject.
  i_tod_card_athlete_ultimate.png | ATHLETE - the ULTIMATE card to darken.
  i_tod_card_gunslinger_ultimate.png | GUNSLINGER - the ULTIMATE card to darken.
  i_tod_card_riot_shield_ultimate.png | RIOT SHIELD - the ULTIMATE card to darken. Its shield is near-WHITE - the brightest object in the set.
  i_tod_card_trailblazer_ultimate.png | TRAILBLAZER - the ULTIMATE card to darken.
  i_tod_card_deadshot_ultimate.png | DEADSHOT - the ULTIMATE card to darken. Its ribbon reads ULTIMATE with NO "+3" - the only one in the set.
preview: 351x527
-->

> **STATUS: DELIVERED AND PARKED, 2026-09-04. Design record:
> `docs/92_dark_upgrades_design.md`.**
>
> Drop came back the same hour as `files - 2026-09-04T003924.491.zip` (37 cards in
> treatment **B**, plus the generator's own review sheets and its `dark_recipe.py`).
> The generator skipped Stage 1 and delivered Stage 2 directly.
>
> **Checked before install:** all 37 names present, none extra, every file
> 768x1152 RGBA; every effect line proofread character-for-character against the
> deliverables table — **all 37 correct, no card carries a number, no "+3"
> survives**, and DEADSHOT's bare `ULTIMATE` ribbon converted correctly. The three
> stress cards all held: the RIOT SHIELD's white did not go pink, FULL STEAM's red
> locomotive still separates, GIANT SLAYER's robot did not blow out. RECOIL and
> HANDLING actually read BETTER than their ULTIMATEs, because the panel got
> lighter under them. Pips are max-count, all lit red. Registration matches.
>
> **THE PANEL COLOUR IS ACCEPTED — user 2026-09-04: *"Color is fine"*.** It came
> back **magenta / violet** rather than dark red: the frame, glow, title plate and
> ribbon are red, but the panel behind each illustration is LIGHTER than the
> ULTIMATE's navy rather than darker. That is a deliberate keep, not an oversight,
> and it is the reason every illustration stayed legible — the docs/87 lesson
> holding. **THE ART IS FINAL. No re-tone is owed and none should be commissioned.**
>
> **INSTALLED TO `source_data` ONLY. NOT ZONED, DELIBERATELY.** Nothing can deal a
> dark card yet, and 37 zoned-but-unreachable cards is **+125 MiB of load RAM** for
> art nothing draws. The zone lines, GDT blocks and Lua slug lane land in the same
> commit as the dark-card code — see the install checklist below.

**Why (user, 2026-09-03):** *"...will have its own unique dark red style card.
Ill need a zip for all tier 3 class upgrades to create the assets. In the zip you
can probably give me the ultimate version of each card and my llm asset generator
can use that as a reference. We want to let them know to use that as a ref and add
a dark red theme to the content and card template. They can give me 3 template
versions to pick from to start with. Then they can do a small dark themed red
enhancement on the content and the copy where it says ultimate will say DARK
UPGRADE. Upgrade description will stay the same."*

**Then, 2026-09-04:** *"Prepare the zip as if all upgrade will get the dark
upgrade. Then we can decide after but lets get the zip so i can get the assets"*
and *"Make sure its generic."*

## Scope — all 37, art first, mechanic later

The first cut of this pack asked for **30**, because seven domains cannot carry a
dark upgrade at the current weapon budget (`docs/92` §Scope: five weapon-variant
ladders against a ledger at 220/224, one saturated engine enum, one spire no-op).
**The user's call is to bake all 37 anyway and decide the mechanic afterwards** —
so the art can never be the thing blocking a decision.

The seven that are currently blocked on mechanics are MAG SIZE, FIRE RATE,
HANDLING, RECOIL, KNIFE SPEED, PENETRATION and PERK SLOTS. **Their art is
identical work to the other 30 and carries no risk**, because of the generic-copy
rule below: a numberless card cannot be falsified by a value that has not been
decided.

⚠️ **Do not zone a card whose domain cannot deal it.** An unreachable card is
3.4 MB of load RAM (`lint_tod_assets.js` exists for exactly this). Hold the seven
in `source_data` until their domain is unblocked, or accept ~24 MB knowingly.

## EVERY VALUE LINE IS GENERIC — no numbers on any dark card

The standing rule (`generic-card-text-rule`, and `docs/40`) is that a card says
*what* an upgrade is and the pause menu says *how much*. 28 of the 37 ULTIMATE
cards already obey it. **Nine still bake a figure, and all nine become generic on
their dark twin:**

| card | ULTIMATE bakes | dark card says |
|---|---|---|
| DAMAGE | `+30%  DAMAGE` | `HIT HARDER` |
| BOUNTY | `+15%  MONEY PER KILL` | `MORE MONEY PER KILL` |
| LUCK | `+30%  LUCK GAIN` | `LUCK BUILDS FASTER` |
| HEADSHOT | `+15%  HEADSHOT DMG` | `HEADSHOTS HIT HARDER` |
| MAG SIZE | `+60%  MAGAZINE` | `BIGGER MAGAZINE` |
| CLEAVE | `33% CHANCE PER LEVEL` | `CHANCE TO HIT EXTRA ZOMBIES` |
| SUPPRESSING FIRE | `HITS SLOW 36%` | `HITS SLOW THE HORDE` |
| DRAW CUT | `+150% DAMAGE` | `SPRINT SWINGS HIT HARDER` |
| PERK SLOTS | `+1 PERK SLOT PER LEVEL` | `MORE PERK SLOTS` |

This kills three problems at once and is why it is the right call, not just the
instructed one:

1. **LUCK stops reading as a downgrade.** Its dark step is +20 points against an
   ULTIMATE card's +30, so a numbered dark card would have printed a *smaller*
   figure than the rarity below it.
2. **The seven blocked domains need no decided number to be drawn.**
3. **A dark card can never go stale.** Every one of these nine numbers has moved
   at least once; GIANT SLAYER moved four times in nine days. The pause row
   (`DETAIL[id].val`) carries the live value and costs nothing to change.

The other 28 keep their existing line verbatim, because they are already generic.
**DISTRACTION** is the one to watch: it keeps `CARRY MORE MONKEYS` while its dark
step changes the resupply axis instead — not false, but no longer the whole story.

## Install, when the drop lands

1. `.\tools\make_art_pack.ps1 -Inspect "files (N).zip"` — LOOK at every image,
   proofread every baked string, overlay against the shipped ULTIMATE.
2. Copy into `source_data/tod_ui_images/_images/`. New names, so each needs a GDT
   block and an `image,` line in `zone_source/zm_tower_of_doom.zone`, plus the Lua
   slug lane — **for the domains that can actually deal one** (see the warning
   above).
3. ⚠️ `tools/lint_tod_assets.js` hard-codes `['regular','super','ultimate']` at
   `:208`/`:243`. **Teach it the fourth rarity in the same commit**, or every dark
   card is unguarded by GATE A and a missing zone line draws a WHITE SQUARE with
   the lint green.
4. FULL build. Proof = fresh content-hash `.iwi` beside an untouched control.

⚠️ **Read `docs/92` §THE ART before committing to Stage 2's full set.** 37
uncompressed 768x1152 cards is **+125 MiB of load RAM** on a set already costing
395 MiB. The one-shared-overlay route costs 3.4 MiB and its Lua lane is already
built and force-disabled by one line. Stage 1 of this pack (the three templates)
is the right first step under EITHER route, which is why it ships as-is.

<!-- PACK:BEGIN -->
# DARK UPGRADE CARDS — a fourth rarity above ULTIMATE (37 images)

## What this is

These are upgrade cards from a Black Ops 3 zombies map. The player is dealt two
cards and picks one; each card is one ability at one rarity. There are three
rarities today — REGULAR, SUPER and ULTIMATE — and they share one chassis, one
palette and one display face.

**We are adding a fourth rarity above ULTIMATE, called DARK UPGRADE.** It is a
late-game reward: it can only be offered on an ability you have already maxed out,
and only deep in the game's endless mode. It should feel like the ULTIMATE card's
corrupted big brother — same card, same illustration, same words, but the gold has
gone to blood.

**Everything you need is in `reference/`: the 37 current ULTIMATE cards.** Each
dark card is built from its own ULTIMATE. They are drawn at **351 x 527 px on a
1080p screen** — see `preview_onscreen_351x527/`, which is what the player really
sees. Judge every decision at that size, not at full resolution.

## The job in one line

**Take each ULTIMATE card, keep the illustration, change the rarity ribbon from
"ULTIMATE +3" to "DARK UPGRADE", and re-theme the chassis and the artwork from
gold/amber to dark red.**

## Two stages — do STAGE 1 first and stop

### STAGE 1 — three template designs (6 files)

Design **three different dark-red treatments** of the chassis, and show each one on
**the same two cards**, so they can be compared like with like:

| Deliver as | Built from | Why this card |
|---|---|---|
| `dark_template_a_damage.png` | `i_tod_card_damage_ultimate.png` | bright saturated orange rocket — the hardest case for a red wash |
| `dark_template_a_back_armor.png` | `i_tod_card_back_armor_ultimate.png` | cool blue-grey icon — proves the treatment works on a cold card |
| `dark_template_b_damage.png` | same as A | variant B |
| `dark_template_b_back_armor.png` | same as A | variant B |
| `dark_template_c_damage.png` | same as A | variant C |
| `dark_template_c_back_armor.png` | same as A | variant C |

On these six, the DAMAGE card's value line reads **`HIT HARDER`** and the BACK
ARMOR card's reads **`LESS DAMAGE FROM BEHIND`** (see the deliverables table).

**Then stop and send those six.** One of the three gets picked, and only then does
Stage 2 run. Do not deliver 37 cards in three flavours.

Make the three genuinely different in *approach*, not just in saturation — for
example one that keeps the chassis structure and only re-hues it, one that darkens
the whole card and lets the red glow do the work, one that adds a corrupted or
cracked material to the frame. Each must still be recognisable as the same card
family, and **whichever is chosen has to work unmodified on all 37** — it is one
generic treatment applied to a set, not a per-card art direction.

### STAGE 2 — the other 35, in the chosen treatment (do not start yet)

Once a template is chosen, apply it to all 37 cards and deliver them under the
exact filenames in the table at the bottom.

## The chassis, top to bottom, and what changes

Every card is a 768 x 1152 portrait PNG with transparency outside a rounded card
body. From top to bottom:

| band | today (ULTIMATE) | dark version |
|---|---|---|
| outer glow | soft peach/gold halo outside the card | **deep red halo** |
| frame | black rounded frame, gold inner line, gold rivets at the four corners, small gold star sparkles around the border | **dark crimson inner line, blackened metal, red sparkles** |
| title plate | amber-to-gold gradient plate, ability name in white heavy display type with a black outline | **dark red plate**, the name stays white with a black outline — it must stay the most readable thing on the card |
| art panel | rounded dark-navy "screen" holding the illustration, faint horizontal scanlines | **darker, red-shifted panel** |
| illustration | the ability's icon | keep the drawing EXACTLY — re-grade it only (see below) |
| medallion | small gold coin with a star, overlapping the panel's bottom-right | **dark red / blackened metal coin** |
| rarity ribbon | orange-gold banner on a dark red backing plate, reading **`ULTIMATE +3`** in white outlined caps, with a small notched tail either side | **reads `DARK UPGRADE`** — no "+3" — on a blood-red / near-black banner |
| effect plate | dark navy plate with an inset border, effect text in bright yellow display caps | **red-shifted plate**; the text goes from yellow to a **hot red-orange or bone white** — whichever your template keeps most legible |
| pip row | a row of sockets, one per level of that ability, with 3 lit gold | **every pip lit, in red** — a dark upgrade is the step past the last one |

### The illustration — "a small dark red enhancement", not a repaint

Keep the drawing identical: same shapes, same pose, same line work, same position.
Re-grade it toward the new palette — pull the golds and ambers toward crimson,
deepen the shadows, let the panel glow red instead of blue — but **do not redraw
it, do not add flames, cracks, skulls or smoke, and do not let it get darker than
it is now.** These illustrations were already brightened once because they were
hard to see against the panel; a dark theme must not undo that.

Four cards are the stress tests, and all four are in `reference/`:

- `i_tod_card_riot_shield_ultimate.png` — the shield is near-white, the brightest
  object in the whole set. It must not turn pink.
- `i_tod_card_full_steam_ultimate.png` — the locomotive is *already red*. On a red
  card it can vanish. It needs to stay separated from its background.
- `i_tod_card_giant_slayer_ultimate.png` — the mid-grey robot is the most legible
  illustration in the set. It must come through unharmed, not blown out.
- `i_tod_card_recoil_ultimate.png` — one of the darkest illustrations. It must not
  sink into a darker panel.

### One card is different

`i_tod_card_deadshot_ultimate.png`'s ribbon reads **`ULTIMATE`** with **no `+3`** —
it is the only one. Its dark ribbon reads `DARK UPGRADE`, same as the rest.

## Hard rules

1. **768 x 1152 px, PNG-32 with the alpha channel preserved.** The transparent
   area outside the card body must stay transparent and must match the source
   exactly — these are drawn over a live game screen.
2. **Pixel registration.** Every band must land on the same pixels as the ULTIMATE
   it was built from. Overlay your result on the reference at 100% and check the
   title plate, ribbon and effect plate do not move.
3. **NO NUMBERS ON ANY DARK CARD.** Nine of the ULTIMATE cards bake a figure
   (`+30%  DAMAGE`, `HITS SLOW 36%`, `+60%  MAGAZINE`, and six more). **Every one
   of those is replaced by the generic wording in the deliverables table** — the
   game shows the real value elsewhere, and a number on the card goes stale. If a
   card in `reference/` shows a percentage and the table does not, the table wins.
4. **The words are otherwise fixed.** Use the exact title and effect text in the
   table, character for character. Do not rewrite, re-punctuate, re-wrap or
   "improve" any line, and do not add a subtitle, a level number or a description.
5. **The ribbon says `DARK UPGRADE`.** Two words, all caps, no "+3", no "+4". It is
   four characters longer than "ULTIMATE +3" — if it does not fit, tighten the
   tracking or shrink the type; do not shorten the words and do not widen the
   ribbon past the plate behind it.
6. **One treatment for all 37.** This is a set and it must still match itself. Set
   the recipe once in Stage 1 and apply it — no per-card judgement, no auto-tone,
   no auto-contrast.
7. **Legibility beats mood.** If a choice makes the card darker but the title,
   ribbon or effect text harder to read at 351 x 527, it is the wrong choice. The
   one failure mode this job has is a beautiful card nobody can read in the 15
   seconds it is on screen.

## References (in `reference/`)

All 37 current ULTIMATE cards, unmodified — these are the INPUTS, one per dark
card. `reference/README.md` names each one.
`preview_onscreen_351x527/` holds every one of them at real on-screen size.

Worth opening before you start: `i_tod_card_damage_ultimate.png` and
`i_tod_card_back_armor_ultimate.png` (your two Stage 1 subjects), plus the four
stress tests named above.

## Deliverables — STAGE 2, 37 files, exact names

`/` in the effect text means a line break. **Bold** rows are the nine whose
wording changes from the reference — everything else is copied verbatim.

| Deliver as | Built from | Title plate | Effect text (exact) |
|---|---|---|---|
| **`i_tod_card_damage_dark.png`** | `i_tod_card_damage_ultimate.png` | DAMAGE | **`HIT HARDER`** |
| `i_tod_card_dmg_reduction_dark.png` | `i_tod_card_dmg_reduction_ultimate.png` | DMG REDUCTION | `TAKE LESS DAMAGE` |
| **`i_tod_card_bounty_dark.png`** | `i_tod_card_bounty_ultimate.png` | BOUNTY | **`MORE MONEY PER KILL`** |
| **`i_tod_card_luck_dark.png`** | `i_tod_card_luck_ultimate.png` | LUCK | **`LUCK BUILDS FASTER`** |
| `i_tod_card_sprint_dark.png` | `i_tod_card_sprint_ultimate.png` | SPRINT | `MOVE FASTER` |
| **`i_tod_card_headshot_dark.png`** | `i_tod_card_headshot_ultimate.png` | HEADSHOT | **`HEADSHOTS HIT HARDER`** |
| **`i_tod_card_mag_size_dark.png`** | `i_tod_card_mag_size_ultimate.png` | MAG SIZE | **`BIGGER MAGAZINE`** |
| `i_tod_card_reserve_dark.png` | `i_tod_card_reserve_ultimate.png` | SCAVENGER | `PRIMARY KILLS: AMMO BACK` |
| `i_tod_card_bullet_feed_dark.png` | `i_tod_card_bullet_feed_ultimate.png` | BULLET FEED | `RESERVE FEEDS YOUR MAG / EVEN WHEN STOWED` |
| `i_tod_card_leech_dark.png` | `i_tod_card_leech_ultimate.png` | LEECH | `BLADE KILLS HEAL YOU` |
| **`i_tod_card_cleave_dark.png`** | `i_tod_card_cleave_ultimate.png` | CLEAVE | **`CHANCE TO HIT EXTRA ZOMBIES`** |
| `i_tod_card_fire_rate_dark.png` | `i_tod_card_fire_rate_ultimate.png` | FIRE RATE | `TRULY FIRES / FASTER` |
| `i_tod_card_handling_dark.png` | `i_tod_card_handling_ultimate.png` | HANDLING | `FASTER RELOAD & ADS` |
| `i_tod_card_recoil_dark.png` | `i_tod_card_recoil_ultimate.png` | RECOIL | `LESS KICK` |
| `i_tod_card_knife_speed_dark.png` | `i_tod_card_knife_speed_ultimate.png` | KNIFE SPEED | `FASTER BLADE SWING` |
| `i_tod_card_penetration_dark.png` | `i_tod_card_penetration_ultimate.png` | PENETRATION | `PIERCE HEAVIER COVER` |
| `i_tod_card_thors_thunder_dark.png` | `i_tod_card_thors_thunder_ultimate.png` | THOR'S THUNDER | `MELEE CALLS LIGHTNING` |
| `i_tod_card_sprint_fire_dark.png` | `i_tod_card_sprint_fire_ultimate.png` | SPRINT FIRE | `FIRE WHILE SPRINTING` |
| `i_tod_card_run_and_gun_dark.png` | `i_tod_card_run_and_gun_ultimate.png` | RUN AND GUN | `FREE SHOTS + BONUS DAMAGE / ON THE MOVE` |
| `i_tod_card_adrenaline_dark.png` | `i_tod_card_adrenaline_ultimate.png` | ADRENALINE | `MULTI-KILLS / GRANT SPEED` |
| `i_tod_card_overdrive_dark.png` | `i_tod_card_overdrive_ultimate.png` | OVERDRIVE | `SUSTAINED FIRE HITS HARDER` |
| **`i_tod_card_suppressing_fire_dark.png`** | `i_tod_card_suppressing_fire_ultimate.png` | SUPPRESSING FIRE | **`HITS SLOW THE HORDE`** |
| **`i_tod_card_draw_cut_dark.png`** | `i_tod_card_draw_cut_ultimate.png` | DRAW CUT | **`SPRINT SWINGS HIT HARDER`** |
| `i_tod_card_second_wind_dark.png` | `i_tod_card_second_wind_ultimate.png` | SECOND WIND | `HEAL WHILE SPRINTING` |
| `i_tod_card_giant_slayer_dark.png` | `i_tod_card_giant_slayer_ultimate.png` | GIANT SLAYER | `HIT BOSSES HARDER` |
| `i_tod_card_back_armor_dark.png` | `i_tod_card_back_armor_ultimate.png` | BACK ARMOR | `LESS DAMAGE FROM BEHIND` |
| `i_tod_card_march_dark.png` | `i_tod_card_march_ultimate.png` | FORCED MARCH | `MOVE FASTER` |
| `i_tod_card_vitality_dark.png` | `i_tod_card_vitality_ultimate.png` | VITALITY | `MORE MAX HEALTH` |
| `i_tod_card_recovery_dark.png` | `i_tod_card_recovery_ultimate.png` | RECOVERY | `REGEN STARTS SOONER` |
| **`i_tod_card_perkslots_dark.png`** | `i_tod_card_perkslots_ultimate.png` | PERK SLOTS | **`MORE PERK SLOTS`** |
| `i_tod_card_distraction_dark.png` | `i_tod_card_distraction_ultimate.png` | DISTRACTION | `CARRY MORE MONKEYS` |
| `i_tod_card_full_steam_dark.png` | `i_tod_card_full_steam_ultimate.png` | FULL STEAM | `KEEP SPRINTING FOR SPEED` |
| `i_tod_card_athlete_dark.png` | `i_tod_card_athlete_ultimate.png` | ATHLETE | `JUMP HIGHER / SLIDE FASTER` |
| `i_tod_card_gunslinger_dark.png` | `i_tod_card_gunslinger_ultimate.png` | GUNSLINGER | `SIDEARM SHREDS BOSSES` |
| `i_tod_card_riot_shield_dark.png` | `i_tod_card_riot_shield_ultimate.png` | RIOT SHIELD | `MORE HEALTH, / FASTER RECHARGE` |
| `i_tod_card_trailblazer_dark.png` | `i_tod_card_trailblazer_ultimate.png` | TRAILBLAZER | `FIRE FOLLOWS / YOUR SPRINT` |
| `i_tod_card_deadshot_dark.png` | `i_tod_card_deadshot_ultimate.png` | DEADSHOT | `PERMA / AIM BOT` |

Where the replacement line is longer than the one it replaces, keep it on ONE line
inside the plate and shrink the type to fit — do not wrap it to two lines unless
the table shows a `/`, and do not spill outside the plate.

## Delivery checklist

- [ ] **Stage 1 only, six files**, named `dark_template_{a,b,c}_{damage,back_armor}.png`
- [ ] every file 768 x 1152, PNG-32, alpha preserved and matching the source
- [ ] the ribbon reads `DARK UPGRADE` on every card — no "+3", no "+4"
- [ ] **no percentages or digits anywhere on any card**
- [ ] title and effect text proofread character for character against the table
- [ ] overlaid on the reference at 100%: no band has moved
- [ ] each one downscaled to 351 x 527 and still readable — title, ribbon, effect
- [ ] the four stress-test cards checked at that size (Stage 2)
- [ ] one recipe across the whole set, no per-file tuning (Stage 2)

## Do NOT

- Do **not** deliver all 37 in Stage 1. Three treatments, two cards each, six files.
- Do **not** copy a number off a reference card. Nine of them carry one and all
  nine are replaced by generic wording in the table.
- Do **not** change the canvas size, the card's silhouette, or the transparent margin.
- Do **not** redraw, replace or re-pose any illustration, and do not add new motifs
  (flames, cracks, skulls, chains, smoke).
- Do **not** add, remove or reword any other text, including "+3", level numbers or
  a description line.
- Do **not** run Auto Levels, Auto Contrast or Auto Tone — each picks a different
  stretch per image and the set stops matching.
- Do **not** make the card so dark that the effect text or the pips disappear at
  351 x 527. Read it small before you send it.
<!-- PACK:END -->
