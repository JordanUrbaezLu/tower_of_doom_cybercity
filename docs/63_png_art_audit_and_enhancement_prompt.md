# 63 — PNG art audit + the enhancement prompt (2026-09-01)

> **STATUS 2026-09-02 01:48: BATCHES 01, 03, 04 AND THE CLASS HALF OF 06 INSTALLED + BUILT.**
> Class badges x4 (`files (94).zip` version — same pill/text as the approved `files (93)`
> sample, medallion glyph matched to the new class icon set) + the 4 draft icons built at
> 01:48:01 (12 fresh .iwi incl. 4 `i_tod_class_medallion_*` discs wired by another session).
> Luck badges x10 and tier gates x2 (rest of batch 06) never arrived; batches 02, 05, 07-11
> not delivered. The user closed the art pass here (2026-09-02: "U are done tho").
>
> Earlier: **STATUS 2026-09-02 01:15: BATCHES 01, 03 AND 04 INSTALLED + BUILT.** Batch 03 (36
> cards, `files (91).zip`) rode the 00:56 FULL build; batch 04 (`files (92).zip`) 60 of
> 66 built at 01:15:13 — MAG SIZE held back (art-pass copies bake +30/60/90 against the
> v16.14 +20/40/60; re-send those three with the new lines if the steel-mag art is
> wanted) and KILL RELOAD skipped (retired). Every card: template diff 0.00%, pip row
> pixel-identical to a reference of the right count, lines read off the PNG. Still out:
> batches 02 (class/tier), 05 (pause plates), 06 (badges), 07 (luck bar), 08 (power-ups),
> 09 (perks), 10 (banners), 11 (workshop).
>
> Earlier: **BATCH 01 (HERO, 7 files) INSTALLED + BUILT v16.16 2026-09-01 23:38:40** — user drop
> `files (88).zip`, proofread by opening every PNG (text unchanged, RGBA, edge alpha 0
> with an 8 px clear ring), FULL build, exactly 7 fresh content-hash `.iwi` with
> `i_tod_card_dmg_reduction_regular` cold as the control. **BATCH 03 SAMPLE (LUCK x3,
> `files (90).zip`) APPROVED + INSTALLED in source_data 2026-09-01 23:5x** — 5 pips lit 1/2/3,
> value lines unchanged, template diff 0.00% outside the screen/value/pip zones
> (`scratchpad/cardtemplate.js`); rides the next FULL build. The remaining 30 batch-03
> cards + batches 02, 04-11 still out. MAG SIZE re-bake (docs/65) came back in
> `files (89).zip` and session 82 installed + built it as v16.17.
> Known nit on the installed choice banner: the two glows are still ring-textured
> (asked for a smooth bloom) — watch for shimmer in game. NEW since the audit:
> MAG SIZE cards owe a re-bake (+30/60/90 baked vs +20/40/60 paid since v16.14,
> prompt in docs/65); KILL RELOAD is retired (see §B).
>
> (Original status: AUDIT DONE, PROMPT WRITTEN, NO ART DELIVERED YET.) Every live UI PNG
> (281 in `source_data/tod_ui_images/_images/` + the two storefront images) was
> OPENED and graded — art, legibility at its real on-screen size, consistency
> with the set, technical cleanliness, and correctness against the shipping
> code. Method: one reviewer per family, then a skeptic per family who re-opened
> every flagged file and hunted for misses. 27 of 36 review agents completed;
> seven skeptic passes and the cohesion read hit a usage limit, so the families
> marked "review only" below carry one pair of eyes, not two. The gauge / hint /
> class-icon family was reviewed by hand instead.

## Totals (281 files)

| verdict | files | meaning |
|---|---|---|
| KEEP | 8 | already the standard — DMG REDUCTION cards, PhD crest, Double Points icon, pip_empty, three pause chrome pieces |
| TOUCH_UP | 19 | a nudge: text/pips/an edge |
| ENHANCE | 186 | same construction, redraw the ART to a higher standard |
| REGENERATE | 17 | wrong facts or wrong drawing — redo |
| RETIRE | 36 | provably never drawn — dead weight in the `.ff`, do NOT spend art |
| (hand review) | 15 | gauge 6 / hint plates 5 / class icons 4 — see §C |

**The set's construction is excellent and rigid** (every card family is a
byte-identical template; the luck bar's 30 states have zero alpha-mask
differences; the pause plates are one bitmap under 43 names). **The weakness is
uniformly the ART INSIDE the construction**: flat single-tone glyphs, no light
source, no material, subjects at 40–50% panel fill, and a rarity sparkle stamp
at fixed coordinates that lands on the drawing in roughly a third of the set.

---

## A. FACTS BEFORE ART — 33 cards are lying or stale (fix these in the same bake)

All confirmed by opening the PNG **and** the `add_domain` line. The set already
renders 5 pips for max-5 domains (GIANT SLAYER, PERK SLOTS, ATHLETE, FULL STEAM,
ADRENALINE), so the PIP RULE (max ≤ 6 → pips = max) is what the set does, and
these are defects against it:

| domain (id) | files | today | must become |
|---|---|---|---|
| LUCK (4) | `i_tod_card_luck_*` | 3 pips | **5 pips**, lit 1/2/3; keep `+10/20/30% LUCK GAIN` (linear) |
| SCAVENGER (8) | `i_tod_card_reserve_*` | 3 pips; stray pale wedge at the top-left bullet | **5 pips**; remove the wedge |
| LEECH (13) | `i_tod_card_leech_*` | 3 pips | **5 pips** (docs/33:177 said "keep 3" — that line is overruled by the set's own practice; rewrite it) |
| KNIFE SPEED (18) | `i_tod_card_knife_speed_*` | 3 pips | **5 pips** |
| SPRINT FIRE (21) | `i_tod_card_sprint_fire_*` | 5 pips, lit 1/2/3; two-line value text; muzzle flash merged into the panel frame | **1 pip, lit on all three**; one line `FIRE WHILE SPRINTING`; flash inside the panel |
| OVERDRIVE (26) | `i_tod_card_overdrive_*` | 3 pips; three DIFFERENT drawings across the rarities | **5 pips**; ONE drawing |
| SECOND WIND (33) | `i_tod_card_second_wind_*` | 3 pips | **5 pips** |
| BACK ARMOR (36) | `i_tod_card_back_armor_*` | 3 pips; `-10/-20/-30% DAMAGE TAKEN` (game pays 10/18/24) | **5 pips**; numberless `LESS DAMAGE FROM BEHIND` on all three |
| FORCED MARCH (37) | `i_tod_card_march_*` | 3 pips | **5 pips** (the GSC comment at `_tod_upgrades.gsc:1271` "pips clamp at 3 by design" and docs/33:174 are both stale — fix them with the bake) |
| VITALITY (38) | `i_tod_card_vitality_*` | 3 pips; `+10 MAX HEALTH PER LEVEL` (flat ladder 10/18/24/28/32) | **5 pips**; numberless `MORE MAX HEALTH` |
| RECOVERY (39) | `i_tod_card_recovery_*` | 3 pips | **5 pips** |
| CLEAVE (14) | `i_tod_card_cleave_ultimate` | `STORM OF BLADES` (a hype line, off-family) | same line as its siblings: `33% CHANCE PER LEVEL` |

Confirmed CORRECT and current (the brief's own claims were stale): DMG REDUCTION
already reads `TAKE LESS DAMAGE` with 5 pips; FULL STEAM already reads
`KEEP SPRINTING FOR SPEED`; SPRINT reads `MOVE FASTER`; ADRENALINE, GIANT SLAYER,
DISTRACTION, PERK SLOTS, ATHLETE all correct. docs/56's amendment still says
FULL STEAM prints 1.5S — the doc is stale, not the art.

**Decision the user owns:** the pip fix assumes the PIP RULE wins over the two
"keep 3" doc lines. If the user prefers 3 pips on those domains, strike the pip
rows above and the prompt's pip counts, and instead rewrite the rule.

## B. DEAD WEIGHT — 36+ files packed but never drawn (no art; un-zone instead)

| family | files | why unreachable | cost |
|---|---|---|---|
| composite-card lane | `i_tod_card_base`, `i_tod_frame_regular/super/ultimate`, `i_tod_icon_damage/firerate/magsize`, all 16 `i_tod_up_*`, `i_tod_title_plate` | `USE_CARD_SET_ART = true` forces the frame/base/icon flags off (`tod_upgrade.lua:514-518`); the composite paint at L1453+ is unreachable; the title plate is registered but composites to 4 visible pixels | 24 zone lines, ~600 KB |
| retired pause plates | `i_tod_pause_r09/r11/r12/r22/r28/r30/r32/r34` | ids the server can never send | 8 zone lines |
| retired card sets | `echo_rounds`, `regen`, `momentum`, `meat_grinder` ×3 | domains commented out; the Lua's own "unreachable slug = dead weight" rule | 13 zone lines |
| KILL RELOAD (retired v16.14, 2026-09-01 23:07, session 82) | `i_tod_card_kill_reload_*` ×3, `i_tod_pause_r27` | domain retired after this audit ran; its card slug + 3 zone lines were dropped in v16.14, the plate line remains | 1 zone line + 3 PNGs |
| class draft icons | `i_tod_class_skirmisher/assault/heavy/slasher` | `tod_class_select.lua:55` forces `USE_CLASS_ICON_ART = false` under card art | 4 zone lines |
| luck v2 frame | `i_tod_luck_frame` | not zoned, not registered; only a stale GDT entry | GDT row |
| powerups that never spawn | `i_tod_pu2_fire_sale` (needs a mystery box), `i_tod_pu2_carpenter` (needs barricades), `i_tod_pu2_free_pap` (row keyed to the perk-bottle clientfield, no timed state) | stock drop gates refuse in this map | keep the rows, spend no art |

Un-zoning is a FULL build (same build the art needs). Side finding for code:
`_tod_powerups.gsc:81` lists carpenter among always-drop powerups; it is not.

## C. THE ENHANCEMENT SET, ranked by visibility × gap

1. **HERO PIECES (P1).** `i_tod_win_banner` is a bare text plate with no scene
   while every spire banner has one; `i_tod_win_emblem` and `i_tod_spire_emblem`
   are ~12 px line-art that becomes a 1.5 px wireframe at their 128 px draw;
   `i_tod_choice_banner` presents EXTRACT and ASCEND as unequal halves (green
   peak alpha 122 vs red 243, ring-textured ovals that will moiré). Touch-ups:
   spire arrival/over banners (stray ticks at the chevron tips, a crown glyph
   crowding SOVEREIGN), spire win (ring-textured sun, sparkles over CONQUERED).
2. **CLASS + TIER CARDS (P1/P2, 12 files).** First art every player sees, 30 s,
   every match. Every weapon is flat two-tone grey with one class stripe; the
   MP7 is a near-duplicate of the MAC-10 card; STORMBREAKER is drawn as a
   symmetric double-bit axe (the real one is single blade + hammer poll); the
   Enfield lacks its SUSAT and curved mag; the Stoner reads as "an LMG with a
   scope". All four class cards carry a stray dark tick after the third pip.
   The 8 tier cards carry residue ticks in the glow bands and a five-ring banded
   glow. (Note: no sidearm CHIP is drawn on any tier card — the sidearm is the
   subline only. If a chip was intended, it never landed.)
3. **UPGRADE CARD SCREENS (P2, 96 files — KILL RELOAD dropped out in v16.14).** The 33 fact fixes above plus a
   family-wide art pass. Standard-bearers to match: DMG REDUCTION shield,
   PENETRATION, THOR'S THUNDER, DISTRACTION monkey, FORCED MARCH boot, RECOVERY
   stopwatch. Weakest: LUCK (four green circles), SPRINT (ambiguous shoe, low in
   panel), SUPPRESSING FIRE (a 150 px blob that will be a smudge; the rounds
   miss the figure), OVERDRIVE (box glued to a circle), HANDLING (an off-class
   handgun on an SMG class), MAG SIZE / FIRE RATE / FULL STEAM (navy on navy),
   BOUNTY (credit cards), PERK SLOTS / ATHLETE (white stick mannequins).
   Set-wide template faults: the rarity sparkle stamp sits at fixed coordinates
   and crosses the art on ~40 cards; value-plate typography drifts (two faces,
   two sizes); DAMAGE exhaust, DISTRACTION fez, FULL STEAM smoke touch/clip the
   panel edge.
4. **PAUSE PLATES (P2, 35 live + header + legend).** One template, but baked
   with RGB sub-pixel antialiasing flattened into the PNG (blue left edges,
   orange right edges on every glyph), zero canvas margin (the outer stroke is
   half-clipped on all four sides), and 300×44 is upscaled on every monitor
   (315×47 at 1080p, 630×92 at 4K). One 600×88 master fixes all 35.
5. **BADGES (P2, 16).** Luck ×10 and class ×4 are one chassis with a glow cut
   flat at the canvas on all four sides and posterised into three alpha steps;
   the class medallion glyphs are 2 px line icons; the tier-gate pair is a
   different family (thin un-outlined type, smaller pill, no glow) and now
   stacks directly under the class badge. One 840×180 master for all three kinds.
6. **LUCK BAR (P1 for the 8 overcharge frames).** Geometry is perfect. The
   OVERCHARGE arcs are 1–2 px hairlines that dissolve at 304×38 and run off the
   bottom canvas edge at full alpha on 7 of 8 frames. Optional: one material
   pass under all 30 states with byte-identical alpha.
7. **POWER-UP ICONS (P1/P2, 8 live).** 128×128 is upscaled above 1080p; four
   icons clip the canvas edge; fill ranges 69–95% so they draw at different
   sizes; gift_of_death / max_ammo / timewarp / nuke are flat single fills while
   double_points is fully rendered. Re-bake the 8 live at 256 in one recipe.
8. **PERK ICONS (P1/P2).** Crest family is locked. Wisp Tea is a different
   dialect (outlined cartoon, 2,964 colours, haze bleeding outside the shield);
   Widow's Wine is dark red on black and vanishes at 42 px; Revive's two figures
   fuse; Speed's gradient streaks smear; Double Tap's border is darker than its
   field (the only inverted frame). Code-side A/B worth running: every
   `i_tod_perk_*` GDT row has `noMipMaps 1`, so the 6:1 minification is bilinear
   from a 2×2 footprint — flip one to 0, full build, compare.
9. **BANNERS (P2).** `i_tod_banner_finale` is off-family (hollow red techno caps
   with a cyan halo on a strip that fills 4% of its canvas) and fronts the 191 s
   ending — regenerate in the header construction. The two headers are one good
   template whose "glow" is a flat 15% band with a hard edge — 2× re-bake with a
   real soft glow. Rampage plate is fine (note `HALF ITS LUCK` is a baked fact).
10. **WORKSHOP KEY ART (P1, storefront).** Cards and title are on-brief; the
    tower is a straight leaning slab (no core, no spiral wrap), the top is the
    RETIRED pre-v11 "castle with spikes" instead of the gold crown, no horde, a
    22 px Panzer blob. Redraw the two hero elements, re-derive the 600×340 card,
    re-animate `workshopimage.gif` (which is what `workshop.json` points at).
11. **GAUGE / HINT PLATES (hand review, P3).** Clean flat minimal, geometry
    locked; the crown cap is good. Optional material pass only. Hint plates
    match the badge pill and read correctly (KBM = MOUSE1/MOUSE2/V). No action
    unless the badge master lands, in which case re-set them on it for parity.

---

## D. THE PROMPT (paste to the image agent; send one batch at a time)

> You are the art director and image generator for the UI of **TOWER OF DOOM:
> CYBERCITY**, a Call of Duty: Black Ops III custom zombies map. An audit opened
> every PNG in the set and produced the job list below. Your job is to reproduce
> the set's style EXACTLY and re-bake the listed files to a higher standard of
> art and detail — identical filenames, identical canvas sizes unless a batch
> says otherwise, identical layouts — so every file drops in with zero wiring.
>
> **OPEN THESE FIRST. They are the style; this text is only the description.**
> Folder: `c:\Users\jorda\Repositories\tower_of_doom_cybercity\source_data\tod_ui_images\_images\`
> - `i_tod_card_dmg_reduction_regular.png` — the standard every card screen must reach
> - `i_tod_card_penetration_ultimate.png`, `i_tod_card_thors_thunder_super.png`, `i_tod_card_distraction_regular.png` — object-based, shaded, narrative screens
> - `i_tod_card_giant_slayer_regular.png` — the 5-pip layout
> - `i_tod_card_tier_heavy_3.png`, `i_tod_card_class_slasher.png` — tier/class construction
> - `i_tod_banner_upgrade.png` — the header plate lockup (screws, outlined rounded caps)
> - `i_tod_spire_banner.png` — the hero-banner construction (plate + perspective scene + bloom)
> - `i_tod_luck_10.png`, `i_tod_luck_max_02.png` — the luck bar and an overcharge frame
> - `i_tod_badge_luck_60.png`, `i_tod_tier_gate_2.png` — the badge chassis and the odd one out
> - `i_tod_pause_r35.png`, `i_tod_pause_hdr.png` — pause plate and header
> - `i_tod_pu2_double_points.png` — the power-up icon polish benchmark
> - `i_tod_perk_phd.png` — the perk crest reference
>
> **STYLE LOCK (applies to every batch).** Flat vector cartoon, mobile-game-card
> finish: thick near-black outlines, saturated flat fills, **three-value
> shading** (base, one shadow, one highlight) keyed to a light source at the
> TOP-LEFT, a thin rim light in the accent colour along the top edge of every
> object, a real material read (steel, brass, wood, glass, cloth), a few
> hand-placed four-point sparkles and small cyan/yellow squares as accents, and
> a faint scanline gradient on every "screen" panel. Palette: navy body
> `#0E1530`–`#1B2452`, amber `#FFBF40`, cyan `#33D9FF`, gold `#F8CB6D`, violet
> `#BF73FF`, red `#FF594D`, green `#3ED27E`. Type: heavy rounded ALL-CAPS with a
> thick dark outline (the set's face — copy it from the reference). No
> photorealism, no soft-brush painting, no drop shadows on text, no gradient
> "glow ovals" built from concentric rings (they moiré at draw size). "Detail"
> means: a stronger silhouette, a secondary element that shows the CONDITION
> of the effect, one more value of shading, and a material — not more clutter.
>
> **HARD RULES (non-negotiable).**
> 1. PNG, RGBA, fully transparent outside the artwork and its glow. Every glow
>    must reach alpha 0 at least 8 px INSIDE the canvas — nothing may touch the
>    canvas edge. Everything inside a card's screen panel must sit at least 24 px
>    inside the panel's edge — nothing may touch or cross the panel frame.
> 2. Cards: 768×1152. The frame, title plate, screen, ribbon, medal, value plate
>    and pip row are LOCKED — reproduce them pixel-for-pixel from the reference;
>    only the screen ART and the elements a batch names may change. The three
>    rarities of a domain are ONE drawing with only the rarity treatment
>    changed: REGULAR plain navy frame + silver ribbon "REGULAR +1" + silver
>    medal + pale blue-white value text; SUPER purple glow + purple ribbon
>    "SUPER +2" + gold medal + violet text; ULTIMATE gold glow + orange ribbon
>    "ULTIMATE +3" + gold medal + gold text.
> 3. Pips: the count is given per domain below; lit = 1 / 2 / 3 by rarity,
>    clamped at the count. Match the pip size and spacing of the reference.
> 4. Value text: exactly the line given per domain, ONE line, in the set's face,
>    the same size and weight for every domain (no mixing of faces or sizes).
>    NO numbers except where the given line contains one. NO superlatives. No
>    second line.
> 5. Rarity sparkle accents (the purple / yellow / red strokes on SUPER and
>    ULTIMATE) must be placed BY HAND in empty margin space so they never touch
>    the drawing. Do not use a fixed-position stamp.
> 6. Screen art fills ~65–70% of the panel, centred, with the light from the
>    panel's top-left bloom. Where a weapon is shown it is the class's REAL gun
>    with its identifying cues, never a generic silhouette.
> 7. Deliver a CONTACT SHEET of ONE sample per batch first, wait for approval,
>    then every file of the batch as a separate PNG at the exact filename.
>    Proofread every baked word, pip count and lit count against this document
>    before returning.
>
> ---
>
> **BATCH 1 — HERO PIECES (6 files).**
> - `i_tod_win_banner.png` 2048×512 — keep the dark chevron plate, the gold
>   "YOU ESCAPED THE TOWER" and its cyan-edged outline. Build the family scene
>   behind it in the TOWER'S cyan/gold: the spiral tower or the crown citadel
>   receding to a bright vanishing-point bloom above the plate, cyan node-dotted
>   rails below it (the spire banners' red rails, in cyan), gold sparkles, and a
>   soft gold/cyan outer glow that is actually visible (alpha 60–120). No subline.
> - `i_tod_win_emblem.png` 1024×1024 — redraw as a FILLED badge built for a
>   128 px draw: a solid navy/cyan tower silhouette with an edge-lit cyan glow
>   and two or three lit floor bands, a GOLD CROWN SEATED on its top (flared band,
>   alternating points, a ruby at the front), strokes 24–32 px, no vertex dots,
>   on a dark disc with a cyan ring and a radial glow.
> - `i_tod_spire_emblem.png` 1024×1024 — the exact mirror in red/gold: a filled
>   dark-red spire with edge-lit red glow and lit rungs, the gold hub ring as a
>   solid banded ring with glowing nodes, a gold summit beacon on top, same stroke
>   weight and disc as the win emblem.
> - `i_tod_choice_banner.png` 2048×512 — keep the split neon type (green
>   EXTRACT / red ASCEND). Rebuild the halves as EQUALS: two restrained soft
>   glows of equal strength (no ring texture), an exfil-pad / uplink-console
>   scene on the left in cyan-green to balance the spire road on the right,
>   "OR" in neutral white on its own small divider plate, remove the pill-dash
>   and the ring caps, fewer and heavier grid lines.
> - `i_tod_spire_win_banner.png` 2048×512 — keep the gold title with red outline
>   and the red rails with gold nodes. Redraw the sun as a soft radial gold bloom
>   with a bright core (no rings, no hard edge); replace the three black dots with
>   a gold summit beacon; move every sparkle clear of the letters; subline in
>   gold. Text stays: `YOU CONQUERED THE SPIRE` / `100 FLOORS - NOTHING LEFT TO CLIMB`.
> - `i_tod_spire_over_banner.png` 2048×512 — touch-up only: move the small crown
>   glyph off the word SOVEREIGN (centre it above the title), remove the stray
>   ticks at the chevron tips, set the subline one weight heavier. And on
>   `i_tod_spire_banner.png`: remove the tip ticks, fewer/heavier bottom rails
>   with larger node rings, one gold accent at the vanishing point.
>
> **BATCH 2 — CLASS + TIER CARDS (12 files, 768×1152).**
> Keep every plate and the layout. Remove the stray dark tick after the third
> pip on the four class cards, the small white/lavender ticks in the glow bands
> of the eight tier cards, and replace the five-ring banded class glow with a
> smooth falloff. Replace the dim yellow "X" behind each gun with a crisp radial
> glow in the class colour plus a subtle chevron motif. Set each class tagline on
> its own small dark plate at the top of the screen. Redraw every weapon as a
> HERO render: three-value shading, class-colour rim light, real mechanical
> detail, unmistakable silhouette — distinguishable from its siblings at 234 px
> by shape alone. Text is unchanged on all twelve (read it off the file).
> - `i_tod_card_class_skirmisher.png` — MAC-10: ejection port, charging handle,
>   mag base plate, wire-stock rivets, threaded muzzle. Cyan.
> - `i_tod_card_class_assault.png` — ENFIELD (L85 bullpup): SUSAT optic block
>   on top, curved 30-round mag behind the grip, short stock plate, forend vents. Amber.
> - `i_tod_card_class_heavy.png` — STONER 63: side-hung box magazine, folding
>   bipod, top carry handle, perforated barrel jacket, long barrel; the receiver
>   tube must read as round steel. Red.
> - `i_tod_card_class_slasher.png` — COMBAT KNIFE: bevelled two-facet blade
>   with a violet rim light, wrapped grip with pommel; the dashed arc becomes a
>   solid violet slash-trail with a bright leading edge. Violet.
> - `i_tod_card_tier_skirmisher_2.png` — MP5: ejection port, cocking tube,
>   tri-lug muzzle, curved mag, fixed stock.
> - `i_tod_card_tier_skirmisher_3.png` — MP7: MUST NOT look like the MAC-10.
>   Stubby body, fat top rail with folding sights, folding vertical foregrip,
>   extending stock, grip-mounted mag, short barrel with brake.
> - `i_tod_card_tier_assault_2.png` — KRIG 6: angular polymer stock with cheek
>   riser, long top rail, M-LOK handguard, flared magwell, flash hider.
> - `i_tod_card_tier_assault_3.png` — AK-47: keep the silhouette; add a second
>   wood tone with grain, a third metal value, dust-cover ribs, slanted brake.
> - `i_tod_card_tier_heavy_2.png` — HK21: drum rear sight, belt-feed box under
>   the receiver with a belt exiting it, perforated handguard, folded bipod.
> - `i_tod_card_tier_heavy_3.png` — DEATH MACHINE: keep the silhouette; barrel
>   cluster shaded as a cylinder, ammo chute, top handle, hot-white muzzle cores.
> - `i_tod_card_tier_slasher_2.png` — KATANA: bevel line and wavy hamon, violet
>   rim light on the spine, two-tone tsuba, solid slash-trail.
> - `i_tod_card_tier_slasher_3.png` — STORMBREAKER: the head is ONE broad axe
>   blade with a flat hammer poll on the other side (NOT a symmetric double-bit),
>   a branch-like wooden haft with a wrapped grip, violet lightning veins
>   crackling across the steel with bright cores; angle it diagonally.
>
> **BATCH 3 — UPGRADE CARDS, FACT FIXES (33 files, 768×1152).** These must be
> right before anything else. Each row: pips, value line (identical on all three
> rarities unless stated), and the art direction for the screen.
> - `i_tod_card_luck_regular/super/ultimate` — **5 pips**. `+10% LUCK GAIN` /
>   `+20% LUCK GAIN` / `+30% LUCK GAIN`. Art: a real four-leaf clover with
>   heart-shaped leaves, a vein highlight per leaf, a curved stem, one gold coin
>   spinning beside it; not four circles.
> - `i_tod_card_reserve_regular/super/ultimate` (SCAVENGER) — **5 pips**.
>   `PRIMARY KILLS: AMMO BACK`. Art: a brass round arcing up out of a downed
>   zombie silhouette into a steel magazine, casings bevelled; remove the stray
>   pale wedge.
> - `i_tod_card_leech_regular/super/ultimate` — **5 pips**. `BLADE KILLS HEAL
>   YOU`. Art: a blade with a bright edge, a red droplet lifting off it and
>   turning into a green cross/plus as it rises — the heal must be visible.
> - `i_tod_card_knife_speed_regular/super/ultimate` — **5 pips**. `FASTER BLADE
>   SWING`. Art: the slasher's Combat Knife (clip point, bevel, wrapped grip)
>   with three stepped solid afterimages that never drop below 40% opacity.
> - `i_tod_card_sprint_fire_regular/super/ultimate` — **1 pip, lit on all
>   three**. ONE line: `FIRE WHILE SPRINTING`. Art: a running cyber-operator
>   firing a MAC-10 from the hip, muzzle flash fully INSIDE the panel with margin.
> - `i_tod_card_overdrive_regular/super/ultimate` — **5 pips**. `SUSTAINED FIRE
>   HITS HARDER`. ONE drawing across all three (today they differ): a 3/4-view
>   minigun with a heat ramp on the barrels (grey → orange → white-hot toward the
>   muzzle), ejected casings in one consistent cluster.
> - `i_tod_card_second_wind_regular/super/ultimate` — **5 pips**. `HEAL WHILE
>   SPRINTING`. Art: the shared cyber-operator figure (see BATCH 4 note)
>   sprinting with a green cross/plus pulsing at the chest and an ECG trace behind.
> - `i_tod_card_back_armor_regular/super/ultimate` — **5 pips**. `LESS DAMAGE
>   FROM BEHIND` (no number). Art: the operator from behind, a glowing armour
>   plate across the shoulders deflecting a claw swipe, red rim light.
> - `i_tod_card_march_regular/super/ultimate` (FORCED MARCH) — **5 pips**.
>   `MOVE FASTER`. Art unchanged (the boot is a standard-bearer) — pips only.
> - `i_tod_card_vitality_regular/super/ultimate` — **5 pips**. `MORE MAX HEALTH`
>   (no number). Art: the shared operator figure, chest-forward, with a large
>   red heart/cross emblem and a health bar filling to the brim; same shaded
>   navy figure style as SECOND WIND and BACK ARMOR so the three read as one set.
> - `i_tod_card_recovery_regular/super/ultimate` — **5 pips**. `REGEN STARTS
>   SOONER`. Art unchanged (stopwatch + ECG is a standard-bearer) — pips only;
>   set the value text in the same face/size as the rest of the set.
> - `i_tod_card_cleave_ultimate` — value line becomes `33% CHANCE PER LEVEL`
>   (same as regular/super). Art unchanged apart from moving the red accent off
>   the blade tip.
>
> **BATCH 4 — UPGRADE CARDS, ART PASS (63 files, 768×1152).** Pips and value
> lines stay EXACTLY as they are on the file (read them). Redraw the screen to
> the style lock. Figures: use ONE shared "cyber-operator" — navy body, cyan
> visor, armour plates, class-colour accent — everywhere a person appears, so
> cards never look like different sets side by side.
> - DAMAGE (3 pips) — rocket with swept fins, nozzle ring, gloss strip; a
>   three-layer starburst with shockwave ring and spark shards; exhaust ends
>   well inside the panel (today it is clipped).
> - BOUNTY (3) — a banded cash bundle and bevelled gold coins bursting up from
>   a zombie kill marker; not credit cards.
> - SPRINT (3) — a proper running boot/leg with solid speed lines, centred.
> - HEADSHOT (3) — keep the skull-and-crosshair; add shading and a hot impact.
> - MAG SIZE (3) — a steel magazine in a light metal (not navy on navy),
>   rounds visible, an extended second mag beside it.
> - BULLET FEED (3) — a belt of brass rounds feeding into an LMG's mag, larger
>   and fewer rounds, accents clear of the belt.
> - FIRE RATE (3) — the skirmisher's MAC-10 with a hot muzzle and a fan of
>   solid tracer streaks; light metal on navy.
> - HANDLING (3) — an MP5 (SMG class — NOT a handgun) mid-reload with a fresh
>   mag and a speed arc.
> - RECOIL (2) — a rifle with a bold compensator and a shrinking recoil arc;
>   one face and size for the value text.
> - PENETRATION (2), THOR'S THUNDER (5), DISTRACTION (2) — standard-bearers:
>   lightest touch only (fez 24 px clear of the panel top; accents off the art).
> - RUN AND GUN (3) — the operator sprinting and firing the MAC-10, casings flying.
> - ADRENALINE (5) — keep; add rim light and a bright core to the burst.
> - SUPPRESSING FIRE (3) — redraw at twice the figure scale: a zombie silhouette
>   HIT by a fan of rounds and slowed (drag lines behind it, not speed ghosts).
> - DRAW CUT (3) — a blade leaving its scabbard at speed, bright leading edge.
> - GIANT SLAYER (5) — a fired round (no casing) striking a shaded, armoured
>   giant; keep the composition.
> - PERK SLOTS (5) — the operator holding one glowing perk bottle; exactly five
>   bottles in the scene, coloured, bevelled glass.
> - FULL STEAM (5) — a brass-and-red locomotive (not navy) with smoke fully
>   inside the panel and a glowing pressure gauge.
> - ATHLETE (5) — the operator mid-slide with a cyan slide streak and a hurdle.
> - SCAVENGER, LEECH, KNIFE SPEED, etc. are in BATCH 3. DMG REDUCTION: do not touch.
>
> **BATCH 5 — PAUSE PLATES (34 plates + header + legend).** Re-bake ONE master
> at **600×88** (exact 2× of 300×44, identical geometry doubled: pill, cyan tick
> at 2× its position, text left edge at 2×33, same face at 2× cap height) and
> stamp every name. Type rendered with GREYSCALE antialiasing — no sub-pixel
> colour fringing (today every glyph has a blue left edge and an orange right
> edge). Keep 2 px of transparent margin so the outer stroke is whole. Give the
> pill the header's vocabulary, restrained: a 1 px cyan hairline inside the
> outline, a faint scanline gradient on the lower half, a soft LED glow on the
> tick. Names (exact): r01 DAMAGE, r02 DMG REDUCTION, r03 BOUNTY, r04 LUCK,
> r05 SPRINT, r06 HEADSHOT, r07 MAG SIZE, r08 SCAVENGER, r10 BULLET FEED,
> r13 LEECH, r14 CLEAVE, r15 FIRE RATE, r16 HANDLING, r17 RECOIL, r18 KNIFE
> SPEED, r19 PENETRATION, r20 THOR'S THUNDER, r21 SPRINT FIRE, r23 RUN AND GUN,
> r24 CLASS TIER, r25 ADRENALINE, r26 OVERDRIVE, r29
> SUPPRESSING FIRE, r31 DRAW CUT, r33 SECOND WIND, r35 GIANT SLAYER, r36 BACK
> ARMOR, r37 FORCED MARCH, r38 VITALITY, r39 RECOVERY, r40 PERK SLOTS, r41
> DISTRACTION, r42 FULL STEAM, r43 ATHLETE (filenames `i_tod_pause_rNN.png`).
> Also `i_tod_pause_hdr.png` at **2000×140** with a smooth (non-banded) glow,
> and `i_tod_pause_legend_reset.png` at **1520×112** with the text set larger
> and brighter across the plate's full width.
>
> **BATCH 6 — BADGES (16 files at 840×180, exact 2× of 420×90).** One master
> chassis shared by all three kinds: the navy pill centred with an EVEN width,
> the left medallion disc, the set's bold outlined face, and a smooth glow that
> reaches alpha 0 at least 8 px inside the canvas (today it is cut flat on all
> four sides and stepped into three bands). Redraw every medallion emblem as a
> bold FILLED, outlined, bevelled icon (today they are 2 px line drawings).
> - `i_tod_badge_luck_10..100.png` — `LUCK NN% BOOSTED`, hue walking cyan →
>   mint → green → lime → gold as today; on 100 render the sparkle pair BRIGHT
>   and remove the stray dark tooth at top-centre.
> - `i_tod_upg_class_skirmisher/assault/heavy/slasher.png` — `CLASS <NAME>` in
>   the class colour with a bold filled class emblem in the medallion.
> - `i_tod_tier_gate_2.png` / `_3.png` — `TIER 2 AT FLOOR 10` / `TIER 3 AT
>   FLOOR 20`, keeping the chosen steel pill + amber double-chevron medallion,
>   dim glow and sparkles, but on the FULL chassis footprint with the set's
>   outlined bold type (today it is thin and un-outlined and the pill is smaller).
>
> **BATCH 7 — LUCK BAR OVERCHARGE (8 files, 1024×128).**
> `i_tod_luck_max_01..04.png` and `i_tod_luck_rmp_max_01..04.png`. The housing,
> fill, wordmark and dice badge must stay BYTE-IDENTICAL to `i_tod_luck_10.png`
> / `i_tod_luck_rmp_10.png` respectively — only the arc/aura layer changes.
> Re-author the arcs as a real hero animation: 4–6 px white-hot cores with a wide
> soft coloured glow (cyan-white over the gold bar; magenta-white with a dark halo
> over the rampage lavender), a soft bloom aura around the whole housing, and a
> hotter/whiter fill than plain state 10; four genuinely different frames. Every
> arc must fade out above y = 124 — today 7 of 8 frames run arcs off the bottom
> edge at full alpha.
>
> **BATCH 8 — POWER-UP ICONS (8 files at 256×256).** `i_tod_pu2_insta`,
> `_double_points`, `_gift_of_death`, `_max_ammo`, `_nuke`, `_timewarp`,
> `_infinite_ammo`, `_zombie_blood`. One recipe for all eight, at the polish of
> the current double_points: silhouette centred in a uniform ~80% safe box with
> an 8 px minimum margin on every side (today four icons touch the edge and fill
> ranges 69–95%), top-left highlight, bottom-right shade, thin inner rim light,
> identical outline weight, a thin 2–3 px dark halo for contrast over gameplay,
> no purple bloom. ~~Insta keeps its baked `x3`~~ (REVERSED 2026-09-02, docs/74: Insta-Kill is a one-hit now, the `x3` goes), double_points its `x2`. Gift of
> Death: a large menacing skull on the box (today it vanishes). Max Ammo: an
> olive/steel crate (not navy) with fewer, bolder rounds. Time Warp: glass
> highlight, sand stream, thick arc arrows. Nuke: layered cloud lobes with a hot
> core. Infinite Ammo: recentred, bullet fully inside. Zombie Blood: enlarge the
> eye with a white sclera.
>
> **BATCH 9 — PERK ICONS (8 files, 256×256, the crest/pentagon family is
> LOCKED).** Flat single-colour silhouettes on a flat field with an 8 px lighter
> border, hard 2–3 px shield edge, zero alpha outside the pentagon, no gradients,
> no stroke under 8 px. `i_tod_perk_wisptea` — REDRAW in this dialect (today it
> is an outlined cartoon with haze bleeding outside the shield): flat white cup,
> three bold flat steam wisps. `_widows` — spider to `#C62A2F` with 8 px legs,
> 8 px border, rounded top corners. `_revive` — one bold glyph with body-colour
> gaps so the figures never fuse; arc flat or gone. `_speed` — three bold
> tapered flat strokes instead of eight gradient streaks; a hand with a thumb.
> `_doubletap` — drop the watermark, pale-gold border lighter than the field,
> a gap where the pistols cross. `_deathperception` — flat halo ring, six blunt
> bolts. `_jugg` — bullet as a solid cream silhouette. `_staminup` — two swirl
> loops, 8 px limbs. `_phd` — do not touch (the reference).
>
> **BATCH 10 — BANNERS.** `i_tod_banner_finale.png` (1024×128 → deliver
> **2048×256**): REGENERATE in the header construction — navy rounded plate
> with four screws, `EXTRACTION` in white rounded outlined caps, a red alarm
> glow, a small gold crown emblem, filling the full 8:1 canvas (today it is
> hollow red techno caps with a cyan halo on a strip that fills 4% of the
> canvas). Text unchanged (read it off the file). `i_tod_banner_choose_class.png`
> and `i_tod_banner_upgrade.png` (900×140 → **1800×280**): the same plates,
> re-baked at 2× with a TRUE soft outer glow (today a flat 15% band with a hard
> edge), a bevel on the plate rim, and the choose-class subline pulled clear of
> the bottom screws.
>
> **BATCH 11 — WORKSHOP KEY ART.** Master at 2048×2048 downscaled to
> `zone\workshopimage.png` **512×512**, then re-derived at 30:17 to
> `zone\previewimage.png` **600×340** (exact). Keep the composition, the card
> fan, the title block and the palette exactly. Redraw two hero elements:
> (1) THE TOWER as a genuine spiral: a solid dark core with the open-air
> staircase visibly wrapping around it, flights passing in front of and behind
> the core, a landing every two flights, floor edges cycling cyan / magenta /
> amber / green / violet WITH bloom, four enclosed glowing lounge boxes at
> floors 10/20/30/40, zombies pouring up the lower spiral, a Panzer on a landing
> at a readable size. (2) THE TOP as the GOLD CROWN: a flared gold band with a
> white ermine rim, sixteen alternating points, a front cross with a great ruby,
> two arches to a monde and a red beacon, the causeway running into its mouth —
> reuse the existing ring as the crown's halo. Not a castle, not spikes. On the
> 600×340: anchor the tower base lower-left, fill the bottom band with two or
> three skyline layers and signage, keep the crown 8% inside the edges.
>
> **PROOFREAD CHECKLIST before returning any batch:** exact filenames · exact
> canvas size · alpha 0 on every canvas edge · nothing crossing a panel frame ·
> pip count and lit count per this document · value line verbatim · no numbers
> or superlatives beyond the given lines · rarity treatment per file · every
> weapon identifiable by silhouette · sparkle accents clear of the art.

---

## E. Install (after art lands)

1. Overwrite in `source_data/tod_ui_images/_images/` (and `zone\` for the two
   storefront files — those need no build, just a sync + republish; re-animate
   `workshopimage.gif` from the new square or repoint `workshop.json`).
2. 2× re-bakes need NO GDT change — `image.gdf` blocks carry no dimensions
   (verified on `i_tod_pause_r35`); the Lua draws by rect and the aspects are
   held. The 256 power-up icons likewise.
3. In the same commit: un-zone the dead weight in §B (24 + 8 + 13 + 4 zone
   lines), delete the `i_tod_luck_frame` GDT row, fix the stale pip comments
   (`_tod_upgrades.gsc:1271`, docs/33:174/177/178), and rewrite docs/56's
   FULL STEAM amendment.
4. **FULL build.** Prove the pack with a fresh content-hash `.iwi` per file plus
   an untouched control (`i_tod_card_dmg_reduction_regular` is the natural
   control — it is the one card set that does not change).
5. Accept the pause plates BY MEASUREMENT: zero warm opaque pixels in the text
   band, alpha 0 on row 0 / column 0 of every plate.
6. A/B the perk-icon `noMipMaps` flag on one icon in a separate build; apply to
   all nine only if the HUD row is visibly sharper.

## F. Memory footprint (decide knowingly)

Every `i_tod_*` image is `uncompressed / noMipMaps / noPicMip`. A 600×88 plate
is ~211 KB in memory vs 53 KB today (+5.7 MB over 36 plates); 840×180 badges
+~5 MB; the 2× banners +~3 MB. Un-zoning §B returns ~1 MB. Acceptable, but it
is a real number.
