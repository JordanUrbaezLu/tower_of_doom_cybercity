# 33 — Upgrade card audit + art prompts (2026-08-24)

> **RESOLVED 2026-08-26 (was: three cards went stale again).** The Assault
> buff (user: *"headshot damage needs to be 4% for each level and boss damage
> also 4% per level. Recoil will go to 10% per level"*) moved HEADSHOT 3%→4%/Lv,
> GIANT SLAYER 3%→4%/Lv and RECOIL −8/−16%→−10/−20%. Code, generator and Lua are
> went on the new numbers and **the nine cards were re-baked and installed the
> same day** from `files (44).zip` — so the set is coherent again. Full record,
> prompts and proofreading checklist: **`docs/35_assault_buff_art_prompts.md`**.
> HEADSHOT, RECOIL and GIANT SLAYER are back on the "Verified CURRENT" list
> below, at their new values.
>
> This is the third time this exact failure has been recorded here. The lesson at
> the bottom of this header is still the lesson: **a domain retune has to schedule
> its own re-bake in the same commit.**

> **STATUS: COMPLETE 2026-08-24.** All 15 re-bakes installed (files (40).zip,
> contact sheet proofread: suppressing fire 12/24/36, knife speed -10/-16/-20,
> leech +4/+6/+8, sprint and mobility +5/+10/+15). FORCED MARCH art installed +
> wired (files (39).zip). Group C cancelled. A 16th plate shipped in the same
> drop: `i_tod_hint_switch_kbm.png` re-baked to MOUSE1/MOUSE2/V after the v10.20
> keyboard root-cause fix retired the A/D lane. Nothing outstanding.
>
> (Original status line: AUDIT DONE, ART NOT YET BAKED.) Every live domain's card was opened
> and its baked text read against the shipping GSC numbers (not against the
> docs — docs/26's tables are stale for KILL RELOAD and were wrong here). The
> Lua-side copy fixes in the table below are **already applied**; the six PNG
> jobs are what is left.

The audit ran after the 2026-08-24 balance pass (LMG damage −10%, HK21 clip
−25%, Stormbreaker −15%, SUPPRESSING FIRE → 12/24/36, PENETRATION HK21 → Death
Machine, ADRENALINE ↔ MOMENTUM on MP5/MP7, FORCED MARCH added, CHAIN LUNGE
removed). The assault 4× headshot from that pass was **reverted** later the same
day, which is what killed group C below.

**Three of the five stale cards had nothing to do with today** — SPRINT,
MOBILITY, LEECH and KNIFE SPEED have been advertising numbers the code stopped
paying since 2026-08-21 (the 3%→5% speed buff) and v10.13 (the log-scaled knife
ladder). That is the real finding: **a domain retune has to schedule its own
re-bake, because the card is the only place a player ever reads the number.**

---

## The work list

### A. RE-BAKES — identical filenames, drop-in, ZERO wiring

| # | slug (3 files: `_regular` `_super` `_ultimate`) | baked text today | must become | why |
|---|---|---|---|---|
| 1 | `i_tod_card_suppressing_fire_*` | HITS SLOW **25% / 40% / 55%** | HITS SLOW **12% / 24% / 36%** | today's nerf |
| 2 | `i_tod_card_knife_speed_*` | **−10% / −20% / −30%** SWING TIME | **−10% / −16% / −20%** SWING TIME | v10.13 log ladder (`KNIFE_STEP`) |
| 3 | `i_tod_card_leech_*` | **+4 / +8 / +12** HP PER KILL | **+4 / +6 / +8** HP PER KILL | stage table, not linear |
| 4 | `i_tod_card_sprint_*` | **+3% / +6% / +9%** SPRINT SPEED | **+5% / +10% / +15%** SPRINT SPEED | 2026-08-21 buff (3%→5%/Lv) |
| 5 | `i_tod_card_mobility_*` | **+3% / +6% / +9%** MOVE SPEED | **+5% / +10% / +15%** MOVE SPEED | same buff |

Everything else on those five cards — icon, frame, ribbon, medal, pip count and
lit count, the light line under the value — stays **byte-for-byte the same
design**. Only the number in the bold line moves.

### B. NEW ART — FORCED MARCH (domain id 37)

`i_tod_card_march_regular.png`, `_super.png`, `_ultimate.png` (768×1152) +
`i_tod_pause_r37.png` (300×44).

Wiring once the files land (docs/25 §10):
1. PNGs into `source_data/tod_ui_images/_images/`
2. four `image.gdf` blocks in `tod_ui_images.gdt` (clone an existing card block)
3. four `image,` lines in `zone_source/zm_tower_of_doom.zone`
4. `CARD_SLUG[37] = "march"` in `tod_upgrade.lua`
5. `PAUSE_PLATE_MAX = 37` in `AetheriumStartMenu.lua`

Until then it is **not broken** — 37 is past `PAUSE_PLATE_MAX`, so the pause menu
draws a text row and the draft falls back to `DOMAIN[37]`'s text on the composite
card. Both are supported paths.

### C. CANCELLED 2026-08-24 — the assault class card

> **DO NOT BAKE THIS.** It existed to advertise the assault 4x headshot, and the
> user reverted that the same day ("Assault class had a 3x and we moved headshot
> to 4x. Lets move that back down to 3x actually"). Headshots are 3x for every
> class again, `i_tod_card_class_assault.png` is CORRECT as it stands, and the
> prompt at the bottom of this doc is dead. Left in place only so the next reader
> knows it was considered and killed, not forgotten.


---

## Verified CURRENT — no action (26 cards + the class/tier sets)

DAMAGE +24% · DMG REDUCTION −10% · BOUNTY +10% · LUCK +20% · HEADSHOT +8% (4%/Lv)
· MAG SIZE +60% · SCAVENGER (no numbers) · BULLET FEED 2.0s→0.4s · REGEN +1.0%/s
· PENETRATION (no numbers) · THOR'S THUNDER (no numbers) · CLEAVE 33%/Lv ·
FIRE RATE (no numbers) · HANDLING (no numbers) · RECOIL −20% MAX ·
SPRINT FIRE (no numbers) · RUN AND GUN +35% · ADRENALINE +6% ·
OVERDRIVE +8%/10 rounds · KILL RELOAD "EVERY 75TH KILL" · IMPACT ROUNDS 6% ·
DRAW CUT +100% · SPRINT ARMOR −10% · SECOND WIND (no numbers) ·
MOMENTUM (no numbers) · GIANT SLAYER +8% · BACK ARMOR.

Four things worth knowing about that list:

- **KILL RELOAD is current** even though docs/26 still specifies the old
  "+25/+50/+75% MAG BACK · ON EVERY KILL". It was re-baked to "EVERY 75TH KILL /
  MAG BACK TO FULL" after v9.43 and the doc never caught up. **Read the PNG, not
  the prompt doc.**
- **The gun moves need no art.** PENETRATION's card never named a gun, and
  neither do ADRENALINE's or MOMENTUM's, so HK21→Death Machine and MP5↔MP7 are
  invisible to the art.
- **The Stormbreaker −15% and the HK21 clip cut need no art.** No card, class
  card or tier card carries a weapon stat — the class cards say "STONER 63 /
  SLOW AND DEVASTATING", the tier cards say "STORMBREAKER / NEW WEAPON · GUN
  UPGRADES RESET".
- `i_tod_card_chain_lunge_*` is now **unreachable art**. The three zone lines and
  `CARD_SLUG[22]` are gone; the PNGs are still in `source_data` if the feature
  ever returns.

---

## Copy fixes ALREADY APPLIED (Lua only, no re-bake)

`tod_upgrade.lua`:

- `DOMAIN[29].desc` → "hits slow the horde 12 / 24 / 36% for 1.5s"
- `DETAIL[29].val` → `12 * l` (was `15 * l + 10`)
- `DOMAIN[37]` + `DETAIL[37]` added for FORCED MARCH
- `DOMAIN[22]` marked REMOVED; `DETAIL[22]` and `CARD_SLUG[22]` deleted
- **the "class gun only" sweep** — `DETAIL` 3, 6, 8, 25, 27, 29 and 35 all said a
  domain was class-gun-only. The 2026-08-23 widening put every weapon on one
  damage lane and un-gated `on_class_gun_kill`, so seven rows had been describing
  a restriction the code stopped enforcing. LEECH (13) keeps its gate and its
  wording; the twin domains (15/16/17/19) really are class-gun-only, because the
  variant forms only exist for that gun.

`tod_class_select.lua`:

- HEAVY blurb "bullet feed + **echo rounds**" → "bullet feed + suppression"
  (ECHO ROUNDS was removed 2026-08-23). Fallback-only text — the baked class
  cards carry the visible copy — but it was a lie in the source.
- ASSAULT blurb: briefly "4x headshots + recoil", then back to "headshots +
  recoil control" when the 4× was reverted. Net zero.

---

## Pip convention (unchanged, read before baking)

- **Short domains (max ≤ 6):** pips = the domain's MAX, lit count = the rarity's
  +N, clamped at max. FORCED MARCH is max 3 → **3 pips, 1/2/3 lit**.
  SUPPRESSING FIRE keeps its existing 3 pips.
- **Long domains (max 10):** a flat 3 pips reading "+N levels from THIS card".
  SPRINT (10) and MOBILITY (10) keep their 3 pips; LEECH (5) and KNIFE SPEED (5)
  keep whatever they have — **do not renumber pips on a re-bake**, only the text.

Sizes: cards **768×1152**, plates **300×44**, transparent outside the card edge,
all text baked in.

---

## THE PROMPT — group A, the five re-bakes

Attach as references the fifteen files being replaced:
`i_tod_card_suppressing_fire_{regular,super,ultimate}.png`,
`i_tod_card_knife_speed_{...}.png`, `i_tod_card_leech_{...}.png`,
`i_tod_card_sprint_{...}.png`, `i_tod_card_mobility_{...}.png`.

> The fifteen attached PNGs are cards from an existing Call of Duty zombies
> upgrade set. I need each one re-baked with **one number changed and nothing
> else** — same 768×1152 canvas, same navy card body, same rounded frame and
> corner screws, same amber title plate and title text, same inset "screen"
> panel and the exact same icon inside it, same ribbon and medal, same lower
> plate, same pip row with the same number of pips and the same number lit, same
> fonts, same colours, same rarity treatment (REGULAR plain navy / SUPER purple
> glow / ULTIMATE gold-orange glow), transparent outside the card edge.
>
> Only the bold value line on the lower plate changes, as follows:
>
> | card | REGULAR | SUPER | ULTIMATE |
> |---|---|---|---|
> | SUPPRESSING FIRE (`HITS SLOW __%`, light line `FOR 1.5 SECONDS`) | HITS SLOW 12% | HITS SLOW 24% | HITS SLOW 36% |
> | KNIFE SPEED (`−__% SWING TIME`, no light line) | −10% SWING TIME | −16% SWING TIME | −20% SWING TIME |
> | LEECH (`+__ HP PER KILL`, no light line) | +4 HP PER KILL | +6 HP PER KILL | +8 HP PER KILL |
> | SPRINT (`+__% SPRINT SPEED`, light line `LV 5: TIRELESS`) | +5% SPRINT SPEED | +10% SPRINT SPEED | +15% SPRINT SPEED |
> | MOBILITY (`+__% MOVE SPEED`, no light line) | +5% MOVE SPEED | +10% MOVE SPEED | +15% MOVE SPEED |
>
> Keep the value text at the same size, weight, colour and baseline as the
> original — SPRINT and MOBILITY go from a 2-character number to a 3-character
> one at ULTIMATE (+15%), so let the text sit at the same optical size and centre
> rather than growing the plate.
>
> Deliver a contact sheet of all fifteen first so the numbers can be proofread,
> then the full-size PNGs named exactly as the originals.

## THE PROMPT — group B, FORCED MARCH (new)

Attach as references: `i_tod_card_sprint_super.png` (nearest sibling — a speed
domain), `i_tod_card_mobility_regular.png`, `i_tod_card_giant_slayer_ultimate.png`,
`i_tod_pause_r32.png`.

> You are extending an existing card set for a Call of Duty zombies map. The
> attached cards ARE the style — match them exactly: 768×1152 portrait, a dark
> navy card body with a rounded outer frame and four corner screws, an AMBER
> title plate at the top with white bold rounded caps (thick dark outline), an
> inset dark-blue "screen" panel with a faint scanline gradient holding a flat,
> bold-outlined cartoon icon with small cyan/yellow sparkle accents, a ribbon
> under the screen, a round star medal overlapping the ribbon's right end, a
> lower dark plate with a thin outline holding a bold coloured value line over a
> smaller light line, and a row of pips at the bottom. Rarity frames: REGULAR =
> plain navy frame, silver ribbon "REGULAR +1", silver medal; SUPER = purple glow
> border + sparkles, purple ribbon "SUPER +2", gold medal; ULTIMATE =
> gold/orange glow border + sparkles, orange ribbon "ULTIMATE +3", gold medal.
>
> Produce ONE new upgrade card as three separate 768×1152 PNGs (one per rarity),
> transparent outside the card, all text baked in, plus one pause-menu plate.
> Deliver a contact sheet first so the baked text can be proofread, then the
> full-size files named exactly as listed.
>
> ### CARD — FORCED MARCH
>
> **Title plate:** FORCED MARCH
>
> **Icon (the screen, identical on all three):** a soldier's boot mid-stride
> seen from the side, planted forward and heavy — a heavy-soled combat boot, not
> a running shoe — with **three amber speed chevrons** stacked behind the heel
> pointing the way it is going, and two or three short horizontal motion streaks
> trailing off the left edge of the screen. One small cyan sparkle at the toe.
> The read should be **relentless forward advance under weight**, not sprinting
> lightness — this is the heavy rifleman's card, the opposite of the SPRINT
> card's leaning-forward runner. Accent colour AMBER (this is an ASSAULT-class
> domain; match the amber the KILL RELOAD and IMPACT ROUNDS cards use, not the
> cyan the skirmisher cards use).
>
> **Value line (bold, amber):** `+5% MOVE SPEED` / `+10% MOVE SPEED` /
> `+15% MOVE SPEED`
>
> **Light line (smaller, pale blue, all three):** `AK-47 ONLY · ALWAYS ON`
>
> **Pips:** three pips. REGULAR one lit, SUPER two lit, ULTIMATE all three lit.
>
> **Files:**
> - `i_tod_card_march_regular.png`
> - `i_tod_card_march_super.png`
> - `i_tod_card_march_ultimate.png`
>
> ### PAUSE PLATE
>
> `i_tod_pause_r37.png`, 300×44 — the existing plate style: a dark navy rounded
> bar with a thin outline, a small cyan notch at the left edge, white bold
> rounded caps with a dark outline, left-aligned after the notch. Text:
> **FORCED MARCH**.

## ~~THE PROMPT — group C, optional assault class card~~ (CANCELLED, see above)

Attach: `i_tod_card_class_assault.png`, `i_tod_card_class_heavy.png`.

> Re-bake the attached ASSAULT class card with one line changed and nothing
> else — same 768×1152 canvas, same navy body, same amber ASSAULT title plate,
> same rifle icon in the same screen panel, same green CLASS ribbon, same silver
> medal, same lower plate, same fonts and colours, transparent outside the card.
> The bold amber gun name **ENFIELD** stays exactly as it is. Change only the
> smaller white role line beneath it from `BALANCED RIFLEMAN` to
> `4x HEADSHOTS`. Same size, weight and baseline. Filename unchanged:
> `i_tod_card_class_assault.png`.
