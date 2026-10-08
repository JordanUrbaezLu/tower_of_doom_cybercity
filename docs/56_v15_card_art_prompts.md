# 56 — v15 card art (2026-08-31/09-01): the re-bakes the balance pass owes

> **STATUS: COMPLETE 2026-09-01.** All 21 cards installed from user drop `files (78).zip`, plus DISTRACTION (41) whose art had never landed since v14.59 — 27 assets total, all dimension-matched to the repo (768x1152 cards, 300x44 plates, 224x196 icon). Wiring done: 9 new GDT blocks, 13 zone lines, `CARD_SLUG[41]`+`[42]`, icon 42, `PAUSE_PLATE_MAX` 40 -> 42. FULL build 01:20:39, .ff 112.55 -> 114.36 MB. **Packing proven**: exactly 27 fresh content-hash `.iwi` files matching the 27 installed, with luck/cleave/vitality as untouched controls (Aug 20/22/30). Contact sheets proofread: +10/20/30 DAMAGE, +15/30/45 BOSS DAMAGE, DMG REDUCTION 5 pips, MOVE FASTER on both speed sets, PRIMARY KILLS: AMMO BACK, FULL STEAM locomotive + SPRINT 1.5S FOR SPEED at 5 pips.
>
> (Was: **OPEN — art not yet baked.** The GSC and Lua for every change below
> is **already shipped**. Until these PNGs land the game advertises numbers it no
> longer pays, which is the failure `docs/33` has now recorded four times. The
> rule that stopped the streak was *write the re-bake doc in the same pass as the
> number change* — this doc is that.

**Every current value line below was read by OPENING THE SHIPPED PNG**, not by
trusting an older prompt doc. `docs/26` and `docs/35` are both stale about
sublines and values; do not use them as a reference.

---

## 0. The whole job at a glance

| # | domain | id | files | kind | wiring needed? |
|---|---|---|---|---|---|
| A1 | DAMAGE | 1 | 3 | value change | none |
| A2 | GIANT SLAYER | 35 | 3 | value change | none |
| A3 | DMG REDUCTION | 2 | 3 | **PIP COUNT ONLY** | none |
| A4 | SPRINT | 5 | 3 | value → **generic** | none |
| A5 | FORCED MARCH | 37 | 3 | value → **generic** | none |
| A6 | SCAVENGER | 8 | 3 | wording | none |
| B1 | **FULL STEAM** | 42 | 3 + 1 plate + 1 icon | **NEW ART** | yes — see §B |

**18 re-bakes at identical filenames + 5 new files.** Groups A1–A6 are drop-in:
overwrite in `source_data/tod_ui_images/_images/` and rebuild. Only B1 needs
GDT rows, zone lines and a `CARD_SLUG` entry.

**A `.gdt`/image change is ALWAYS a FULL build**, never `-GscOnly`.

---

## 1. The card anatomy (shared by all 21 cards)

768×1152 RGBA. Top to bottom:

1. **Title plate** — orange gradient lozenge, white outlined slab caps, domain name.
2. **Illustration panel** — dark navy inset, flat vector art, thick black outlines.
3. **Rarity banner** — `REGULAR +1` / `SUPER +2` / `ULTIMATE +3`, with a medallion
   on the panel's lower-right corner.
4. **Value panel** — the bottom box. **THIS IS THE ONLY LINE THAT CHANGES** in
   group A. One line, no subline.
5. **Pips** — a row of dots under the value panel. Lit = 1 / 2 / 3 by rarity.

**Rarity styling** (do not alter): REGULAR = silver medallion, grey banner, pale
blue-white value text, no outer glow. SUPER = gold medallion, violet banner,
violet value text, violet outer glow. ULTIMATE = gold treatment throughout.

**THERE IS NO SUBLINE ON ANY CARD.** `docs/40` removed it from the whole set.
Older prompt docs still describe one — do not reintroduce it.

### The pip count is baked into the art, varies per domain, and is easy to get wrong

**OBSERVED, by opening the shipped PNGs on 2026-09-01 — not quoted from
`docs/48`, which states the rule wrongly:**

| card opened | domain max | pips |
|---|---|---|
| `giant_slayer_regular` | 5 | **5** |
| `dmg_reduction_regular` | 10 (at bake time) | 3 |
| `damage_regular` | 10 | 3 |
| `sprint_super` | 10 | 3 |
| `march_regular` | 5 | 3 |
| `reserve_ultimate` | 6 | **3** |

So the working rule is **max ≤ 5 → pips = max; max ≥ 6 → a flat 3** (ten pips
are illegible at the 213×320 display size). `docs/48` says the boundary is 6,
which SCAVENGER (max 6, 3 pips) disproves, and FORCED MARCH is a deliberate
exception at max 5 with 3 pips ("pips clamp at 3 by design", v14 note).

**The practical consequence for this job: only DMG REDUCTION's pip count moves.
Every other card keeps the pips it already has. State the count per file in the
prompt, or the reference image silently normalises them all to three.**

---

## A. RE-BAKES — identical filenames, zero wiring

### A1 · DAMAGE (id 1, max 10, **3 pips**, unchanged)

User: *"Can we lower damage upgrade to 10% instead of 12%."*
Linear (`val(l) == l * 10`), so a pre-multiplied per-rarity increment is honest.

| file | current | **new** |
|---|---|---|
| `i_tod_card_damage_regular.png` | `+12%  DAMAGE` | **`+10%  DAMAGE`** |
| `i_tod_card_damage_super.png` | `+24%  DAMAGE` | **`+20%  DAMAGE`** |
| `i_tod_card_damage_ultimate.png` | `+36%  DAMAGE` | **`+30%  DAMAGE`** |

### A2 · GIANT SLAYER (id 35, max 5, **5 pips**, unchanged)

User: *"boss damage should be 15% instead of 8%."* At the Lv5 cap that is +75%.

| file | current | **new** |
|---|---|---|
| `i_tod_card_giant_slayer_regular.png` | `+8%  BOSS DAMAGE` | **`+15%  BOSS DAMAGE`** |
| `i_tod_card_giant_slayer_super.png` | `+16%  BOSS DAMAGE` | **`+30%  BOSS DAMAGE`** |
| `i_tod_card_giant_slayer_ultimate.png` | `+24%  BOSS DAMAGE` | **`+45%  BOSS DAMAGE`** |

No `· MAX` tag: an ULTIMATE grants +3 of 5 levels and does not always land on
the ceiling.

### A3 · DMG REDUCTION (id 2) — ⚠️ THE PIP COUNT CHANGES, THE TEXT DOES NOT

User: *"Damage Reduction needs a nerf."* The **cap** moved 10 → 5 (so −25%
instead of −50%); the **per-level value stayed −5%**, which is why the value
lines below are unchanged and correct.

**But the domain's max crossed the pip rule's boundary.** At max 10 these cards
baked **3 pips**; at max 5 they need **5**, matching GIANT SLAYER (also max 5,
also 5 pips). That is the entire job on these three cards.

> A first pass of this analysis concluded "no re-bake needed" because the value
> text was still true. That was wrong, and OPENING THE PNG is what caught it.
> **A cap change is a card change whenever it crosses 5 in either direction.**

| file | value line (UNCHANGED) | pips |
|---|---|---|
| `i_tod_card_dmg_reduction_regular.png` | `-5%  DMG TAKEN` | 3 → **5** (1 lit) |
| `i_tod_card_dmg_reduction_super.png` | `-10%  DMG TAKEN` | 3 → **5** (2 lit) |
| `i_tod_card_dmg_reduction_ultimate.png` | `-15%  DMG TAKEN` | 3 → **5** (3 lit) |

### A4/A5 · SPRINT (id 5) and FORCED MARCH (id 37) — GO GENERIC

User: *"nerf the speed boost upgrade in general. It should be 5%, 4%, 3%, then
3% each level after. Which means the assets probably need to be upgraded so they
are generic. And the pause menu can show the exact upgrade number."*

**WHY THE NUMBER HAS TO LEAVE THE CARD.** Move speed is now a diminishing
ladder — increments 5, 4, 3, 3, 3… — so a card's payout depends on *where you
already are*. A SUPER (+2 levels) is worth +9 points from Lv0 but only +6 from
Lv3. No single number on the card can be true at every level, and the
domain-retune checklist's rule is that a stage-table domain either prints the
whole ladder or says nothing. **The user chose nothing.** The exact figure is
served per-player by the pause menu instead (already implemented).

| file | current | **new** |
|---|---|---|
| `i_tod_card_sprint_regular.png` | `+5%  MOVE SPEED` | **`MOVE FASTER`** |
| `i_tod_card_sprint_super.png` | `+10%  MOVE SPEED` | **`MOVE FASTER`** |
| `i_tod_card_sprint_ultimate.png` | `+15%  MOVE SPEED` | **`MOVE FASTER`** |
| `i_tod_card_march_regular.png` | `+5%  MOVE SPEED` | **`MOVE FASTER`** |
| `i_tod_card_march_super.png` | `+10%  MOVE SPEED` | **`MOVE FASTER`** |
| `i_tod_card_march_ultimate.png` | `+15%  MOVE SPEED` | **`MOVE FASTER`** |

All six keep **3 pips**. The rarity banner still reads `+1 / +2 / +3`, so the
player still sees how many levels the card pays — only the percentage goes.

**Set the whole line in the value panel's plain style** (the SCAVENGER card is
the reference for a text-only value line: no leading number, same font, same
box, centred).

### A6 · SCAVENGER (id 8, max 6, **3 pips — UNCHANGED, do not touch**) — say PRIMARY

Not a balance change: SCAVENGER has been primary-only since 2026-08-26, and the
card is the one surface that never said so. Four of the five user-facing strings
already do. A player reading only the card thinks a sidearm kill pays.

| file | current | **new** |
|---|---|---|
| `i_tod_card_reserve_regular.png` | `AMMO BACK ON KILLS` | **`PRIMARY KILLS: AMMO BACK`** |
| `i_tod_card_reserve_super.png` | `AMMO BACK ON KILLS` | **`PRIMARY KILLS: AMMO BACK`** |
| `i_tod_card_reserve_ultimate.png` | `AMMO BACK ON KILLS` | **`PRIMARY KILLS: AMMO BACK`** |

Filenames key off the internal domain key `reserve`, **not** the display name
SCAVENGER. Do not rename them.

---

## B. NEW ART — FULL STEAM (domain 42)

User: *"We also need an LMG upgrade where when you run max speed for 1.5s you get
a speed boost."*

The HEAVY's replacement for MOBILITY, which is **retired this same build**. The
heavy trades a passive +5%/Lv for a higher base speed (0.75 → 0.80) plus this:
nothing at a standstill, the full speed ladder after 1.5 s of unbroken sprint.
Freight-train identity — slowest class from a stop, one of the fastest rolling.

**Class colour: HEAVY.** Match the other heavy cards (`vitality`, `recovery`,
`back_armor`, `bullet_feed`, `suppressing_fire`) so the class reads at a glance.

### Files

```
i_tod_card_full_steam_regular.png     768x1152   (1 lit pip of 5)
i_tod_card_full_steam_super.png       768x1152   (2 lit pips of 5)
i_tod_card_full_steam_ultimate.png    768x1152   (3 lit pips of 5)
i_tod_pause_r42.png                   300x44     name-only strip, no numbers
i_tod_up_full_steam.png               icon only  (match i_tod_up_mobility's size)
```

- Title plate: **FULL STEAM**
- Value line, all three: **`SPRINT 1.5S FOR SPEED`**
  (generic for the same reason as A4/A5 — it rides the same diminishing ladder)
- **5 pips** (max 5), lit 1 / 2 / 3 by rarity
- Illustration: a locomotive/pressure-gauge/steam motif reading as *building
  momentum* — deliberately NOT the boot used by FORCED MARCH or the speed-lines
  runner used by SPRINT, since all three are speed cards and must be
  distinguishable at 213×320.

### Wiring checklist (do NOT skip — art without these renders as text)

1. `source_data/tod_ui_images.gdt` — an `image.gdf` block per PNG.
2. `zone_source/zm_tower_of_doom.zone` — `image,i_tod_card_full_steam_regular`
   (+ super, ultimate, `i_tod_pause_r42`, `i_tod_up_full_steam`).
3. `ui/uieditor/menus/hud/tod_upgrade.lua` — `CARD_SLUG[42] = "full_steam"`,
   **only after the PNGs are installed and zoned.** `RegisterImage` of a missing
   image is undefined behaviour.
4. `ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua` — `PAUSE_PLATE_MAX`
   **40 → 42**. ⚠️ It is a `<=` test over a contiguous range, so bumping it to 42
   also claims **41**. `i_tod_pause_r41.png` (DISTRACTION) must exist and be
   zoned first, or bump to 41 and 42 together in one drop.
5. FULL build. Then prove the images actually packed: a **fresh
   content-hash `.iwi` plus an untouched control**. A `.ff` raw grep is invalid
   (compressed) and a stale `.iwi` passes every other gate.

---

## C. Retired this build — no art needed

**MOBILITY (id 9)** is gone with the domain. Already done in code:
`CARD_SLUG[9]` and the three `i_tod_card_mobility_*` zone lines are removed (an
unreachable slug is dead weight in the `.ff`, where an inert Lua row costs
nothing — the IMPACT ROUNDS precedent). **The PNGs stay in `source_data`.** Id 9
stays mapped in `domain_id()` and the Lua tables, which are key-keyed.

---

## THE PROMPT (paste this to the image agent)

> You are revising a set of upgrade cards for a Call of Duty: Black Ops III
> custom zombies map. **Groups A1–A6 are a TEXT-ONLY revision.** Reproduce each
> card exactly as it already is and change ONLY what this brief names. Do not
> redraw, restyle, recolour, re-crop or "improve" the illustration, the frame,
> the title plate, the rarity banner or the medallion.
>
> **Open these files first — they are both the target style and the target
> artwork:**
> `source_data/tod_ui_images/_images/i_tod_card_damage_regular.png`
> `source_data/tod_ui_images/_images/i_tod_card_giant_slayer_regular.png`
> `source_data/tod_ui_images/_images/i_tod_card_sprint_super.png`
> `source_data/tod_ui_images/_images/i_tod_card_reserve_regular.png`
>
> **Format:** 768×1152 RGBA PNG, transparent outside the card's rounded frame.
> Output at the exact same filenames, overwriting.
>
> **Card anatomy, top to bottom:** orange title plate with the domain name in
> white outlined slab caps · dark navy illustration panel with flat vector art
> and thick black outlines · rarity banner reading `REGULAR +1`, `SUPER +2` or
> `ULTIMATE +3` with a medallion at the panel's lower-right · a bottom VALUE
> PANEL holding ONE line of text · a row of PIPS beneath it.
>
> **There is no subline anywhere in this set. Do not add one.**
>
> **Rarity styling — keep exactly as-is per file:** REGULAR = silver medallion,
> grey banner, pale blue-white value text, no outer glow. SUPER = gold medallion,
> violet banner, violet value text, violet outer glow. ULTIMATE = gold throughout.
>
> **PIP COUNTS ARE NOT ALL THE SAME AND ARE EASY TO GET WRONG.** Do not
> normalise them, and do not infer them from the level cap. Per file:
> DAMAGE 3 · SPRINT 3 · FORCED MARCH 3 · SCAVENGER 3 · GIANT SLAYER 5 ·
> **DMG REDUCTION 5 (the ONLY pip change in this job — it is currently 3)** ·
> FULL STEAM 5. Lit pips = 1 for REGULAR, 2 for SUPER, 3 for ULTIMATE.
>
> **THE CHANGES:**
>
> *DAMAGE* — value line `+12% DAMAGE` → `+10% DAMAGE`; `+24%` → `+20%`;
> `+36%` → `+30%`.
>
> *GIANT SLAYER* — `+8% BOSS DAMAGE` → `+15% BOSS DAMAGE`; `+16%` → `+30%`;
> `+24%` → `+45%`.
>
> *DMG REDUCTION* — **the value lines do not change** (`-5% / -10% / -15% DMG
> TAKEN`). Change ONLY the pip row from 3 pips to 5 pips, keeping 1/2/3 lit by
> rarity and the same dot size, spacing style and centring as the GIANT SLAYER
> cards (which already carry 5).
>
> *SPRINT and FORCED MARCH* — replace the numeric value line with the plain
> words **`MOVE FASTER`**, centred, no number and no percent sign. Set it in the
> same font, size treatment and colour the numeric line used, matching the
> all-text value line on the SCAVENGER card.
>
> *SCAVENGER* — `AMMO BACK ON KILLS` → `PRIMARY KILLS: AMMO BACK`. If that does
> not fit the panel at a readable size, use `PRIMARY KILLS ONLY` — but try the
> full line first; the point is telling the player sidearm kills pay nothing.
>
> **NEW CARDS — FULL STEAM (3 cards, built fresh in this exact style):**
> Title plate `FULL STEAM`. Value line on all three: `SPRINT 1.5S FOR SPEED`.
> 5 pips, 1/2/3 lit. Use the HEAVY class's colour treatment — match
> `i_tod_card_vitality_regular.png` and `i_tod_card_back_armor_regular.png`.
> Illustration: a locomotive, pressure gauge or building-steam motif that reads
> as GATHERING MOMENTUM. It must NOT resemble the boot on FORCED MARCH or the
> speed-line runner on SPRINT — all three are speed cards and a player has to
> tell them apart at 213×320 on screen.
> Also produce `i_tod_pause_r42.png`, a 300×44 name-only strip reading
> `FULL STEAM` — match `i_tod_pause_r40.png` exactly for style; it carries no
> numbers.
>
> **Proofread before returning:** every value line matches the table above · pip
> counts are per-file and not normalised · no subline was added · rarity colours
> unchanged · filenames identical to the originals for groups A1–A6.

---

## AMENDMENT 2026-09-01 — FULL STEAM's cards went stale, and it was avoidable

**The three `i_tod_card_full_steam_*.png` now read `SPRINT 1.5S FOR SPEED`, and
the arm time is 1.0s.** They need one more text-only re-bake.

**This was my mistake, and it is worth recording because the user had already
given the rule that prevents it.** In the same session they said *"lets make the
prompts give generic assets so if we ever need to tweak numbers we dont need new
assets"* — and I then wrote a prompt that baked **1.5S** into the value panel.
Every other card in that pass went generic (`MOVE FASTER`, empty panels, no
percentages) precisely so a retune would never touch the art. FULL STEAM was the
one card that carried a number, and it is the one card that had to be re-cut the
very next time a number moved.

**The rule, stated plainly for the next prompt author:** a card may name a
*mechanic* but never a *quantity*. "Sprint to build speed" survives any retune;
"SPRINT 1.5S FOR SPEED" survives only until someone changes 1.5.

### THE FIX — three text-only re-bakes

> You are re-baking three cards from an existing upgrade-card set for a Call of
> Duty: Black Ops III custom zombies map. **This is a TEXT-ONLY revision.**
> Reproduce each card exactly as it is and change ONLY the single line of text in
> the bottom value panel. Do not touch the locomotive illustration, the frame,
> the title plate, the rarity banner, the medallion or the pips.
>
> | file | current value line | new value line |
> |---|---|---|
> | `i_tod_card_full_steam_regular.png` | `SPRINT 1.5S FOR SPEED` | `KEEP SPRINTING FOR SPEED` |
> | `i_tod_card_full_steam_super.png` | `SPRINT 1.5S FOR SPEED` | `KEEP SPRINTING FOR SPEED` |
> | `i_tod_card_full_steam_ultimate.png` | `SPRINT 1.5S FOR SPEED` | `KEEP SPRINTING FOR SPEED` |
>
> The new line carries **no number** on purpose — the arm time has already
> changed once and the exact figure is shown in the pause menu, which is
> server-fed and always current.
>
> **Keep 5 pips**, lit 1 / 2 / 3 by rarity. Same font, size and colour treatment
> as the line being replaced (pale blue-white on regular, violet on super, gold
> on ultimate).
>
> **Deliver as:** PNG, 768×1152 RGBA, transparent outside the
> rounded frame, same filenames, overwriting.

**Install:** overwrite in `source_data/tod_ui_images/_images/`, FULL build, then
prove the re-convert with a fresh content-hash `.iwi` plus an untouched control.
No wiring — these are already installed and zoned.
