# 92 — DARK UPGRADES: one step past maxed, earned in the Endless Spire

> **STATUS: LIVE IN THE BUILD AND BOOT-CONFIRMED, GAMEPLAY UNPLAYED (v17.10,
> 2026-09-04).** 28 domains carry a dark upgrade; all 28 effect lanes wired; 28
> dark cards and 24 red pause plates zoned and converted; `tod_dark_aura` banked;
> spire round deals restored to every 4th round; pause menu prints dark values.
> **Weapon ledger 229 of a 229 guard — BOOTS**, confirmed on this map's own asset
> mix (see tools/gen_tod_twins.js and the weapon-ledger-limit note). Zero margin:
> the next weapon,line anywhere must be paid for by retiring one.
> **NOBODY HAS SEEN A DARK CARD DEAL.** Reaching one means beating the tower,
> ascending, and winning a Warden Trial with something maxed. The numbers
> in THE NUMBERS below are the user's own and are final; the 0.40 anchor section
> is kept only as the record of how the first pass was derived. Art request (37
> cards, sent): `docs/93_dark_upgrade_cards_art_prompt.md`. Sound asset installed
> and banked: `tod_dark_aura` (see THE SOUND).

**The user's brief, 2026-09-03:** *"All abilities are able to gain 1 dark upgrade.
This is unlocked in the endless spire. They appear after a trial is completed
where you get card upgrades. If you have a maxed out ability you can get the dark
upgrade. This is a 2-3 level jump in that ability and will have its own unique
dark red style card. ... For example I know I want damage to be a 40% increase.
You can use that as a ref and carefully decide on the numbers for each."*

## THE ANCHOR — the one rule every number below obeys

DAMAGE is `TOD_UPG_DMG_PER_LVL 0.10` (`_tod_upgrades.gsc:171`) over 10 levels, so
a maxed player carries **+100%**, and the user fixed its dark step at **+40%**.
Read structurally, that is:

> **A dark upgrade adds 40% of what the fully maxed ability already contributes,
> measured in the unit the ability contributes in.**

On a 5-rung ladder that lands at 2 more rungs; on a 10-rung ladder, 4. Both sit
inside the user's "2-3 level jump", and the anchor is the tie-breaker whenever a
ladder is diminishing (where "one more rung" is ambiguous by a factor of two).

**THE FRAMING IS THE WHOLE BALLGAME ON CONVEX DOMAINS.** DMG REDUCTION, BACK
ARMOR, VITALITY, RECOVERY, SUPPRESSING FIRE and RIOT SHIELD all pay a value the
player feels *non-linearly* (percentage points of mitigation are not effective
HP; a shorter timer is not a bigger timer). Priced in raw percentage points, dark
DR is 42%. Priced in the unit it contributes — effective HP — the anchor gives
`(1/(1-0.30) - 1) x 1.4 = 0.60` exactly, i.e. **37.5%**. Five of the six convex
domains independently land on the contribution framing; DR was the one that did
not, and it is the framing that is wrong, not the five. **Use the contribution
framing everywhere.**

## SCOPE — 28 of 37 carry one (final, 2026-09-04)

`grep -c "^\tadd_domain(" scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc` = **37**.

**This section is the FIRST PASS's scoping and is superseded by THE NUMBERS
below.** It said 30 of 37, on the finding that seven domains were blocked. The
user then (a) marked SPRINT FIRE, SECOND WIND, DISTRACTION and DEADSHOT as NONE,
(b) confirmed SUPPRESSING FIRE and DRAW CUT as NONE, and (c) **revived MAG SIZE,
HANDLING and KNIFE SPEED by restricting each to a single TIER-3 gun** — see THE
THREE GUN-RESTRICTED REVIVALS for what that actually costs. Net: **27 with a dark
upgrade, 10 without.** The blocked-list reasoning below is still correct about
WHY the weapon ladders are expensive; it is the conclusion that moved.

| excluded | why |
|---|---|
| MAG SIZE, FIRE RATE, HANDLING, RECOIL, KNIFE SPEED | **Real weapon-variant ladders.** A rung is a weapon asset, not a number. Live ledger **220** against `LEDGER_GUARD 224` (`tools/gen_tod_twins.js:623`) — four free, and the rungs cost +18 / +8 / +12 / +24 / +6. GSC exposes no per-player lever for clip size, fire time, reload time, recoil or melee time. |
| PENETRATION | **Engine enum saturated.** `penetrateType` is `none/small/medium/large` (`deffiles/bulletweapon.awi:26`) and Lv2 already emits `large` on all four gun-forms. No third rung exists at any price. |
| PERK SLOTS | **No-op in the spire.** `perk_slot_limit()` floors every spire player at `TOD_PERK_ROSTER 9` (`_tod_upgrades.gsc:3315-3322`) — the whole roster. A 6th level pays nothing. |

⚠️ **Never raise `LEDGER_GUARD` to buy one back.** Its own comment forbids it and
the failure is a boot AV. The one ledger-*negative* route that exists is trimming
the T1 combat knife to k0..k3 and giving the Leviathan k0..k6 (net **222**) — real,
but it costs the T1 slasher two rungs of a domain that wipes on promotion anyway.

⚠️ **A dark card must never be stored as a level past the cap.** Six sites assume
`o.levels == o.rarity` (`:4181`, `:4211`, `:4027`, `:4115`, `:4875`, `:7194`), and
past that `ladder5`'s `>= 5` clamp, `leech_hp_for_level`'s `default: return 10`,
`overdrive_total_pct`'s `if ( lvl > 5 ) lvl = 5`, `speed_pct_for_level`'s
deceleration, `twin_suffix`'s unclamped concatenation and the pause pip row all
fail **silently and in the player's disfavour**. Store `player.tod_dark[key]`.

## THE NUMBERS — SET BY THE USER, 2026-09-04

⚠️ **These are the user's own figures and they SUPERSEDE the 0.40 anchor above.**
The anchor is kept as the record of how the first pass was derived and as the
sanity ruler; where the user's number differs, the user's number ships. Most are
notably larger — DAMAGE went +40 -> +50, BOUNTY +20 -> +50, LUCK +20 -> +50.

Every value is an **additive percentage-point step on top of the maxed value**,
confirmed by the user writing three of them with the resulting total in brackets:
RECOVERY "+13% (45%)", OVERDRIVE "+25% (50%)", GUNSLINGER "+100% (250%)".
(OVERDRIVE's dark step was later raised 25 -> 40 on 2026-09-08, so its total is
now +65%, not the +50% recorded here. The row in the table below is the live one.)

**28 domains carry a dark upgrade. 9 do not.** The nine: SPRINT FIRE, SECOND
WIND, DISTRACTION, DEADSHOT, SUPPRESSING FIRE and DRAW CUT (all the user's call)
plus FIRE RATE, PENETRATION and PERK SLOTS (blocked). MAG SIZE, HANDLING, KNIFE
SPEED and RECOIL were UNPARKED once the r-axis saving funded their twins.

### Shared — every class

| # | Domain | At max today | **DARK** |
|---|---|---|---|
| 1 | DAMAGE | +100% damage | **+150%** |
| 2 | DMG REDUCTION | 15 / 20 / 24 / 30% by class cap | **25 / 30 / 34 / 40%** (flat +10, every class) |
| 3 | BOUNTY | +50% money per kill | **+100%** |
| 4 | LUCK | x1.50 luck gain | **NONE since 2026-09-05** (was x2.00, v17.10..v17.65) |
| 45 | RIOT SHIELD | 500 HP, back in 2:00 | **700 HP, back in 1:15** (1:30 until 2026-09-05) |
| 8 | SCAVENGER | a round per 1.8 kills (assault 1.6) | **-40% of what you are at** → per 1.08 kills (assault 0.96) |

### Skirmisher

| # | Domain | At max today | **DARK** |
|---|---|---|---|
| 5 | SPRINT (also slasher) | +33% move scale | **+48%** |
| 23 | RUN AND GUN | 52% free shots + 52% damage | **100% / 100%** (77 until 2026-09-05) |
| 25 | ADRENALINE | +15% burst for 3s | **+25%** |
| 46 | TRAILBLAZER | 6%/s burn, 17% slow, 90u wide | **10%/s, 25% slow, 100u, AND IT BURNS BOSSES** (boss burn added 2026-09-05) |
| 16 | HANDLING | -35% reload / swap / ADS | **-55%** — **MP7 ONLY** |

### Assault

| # | Domain | At max today | **DARK** |
|---|---|---|---|
| 6 | HEADSHOT | +50% headshot damage | **+75%** |
| 35 | GIANT SLAYER | +60% vs bosses and elites | **+80%** (85 until 2026-09-05) |
| 37 | FORCED MARCH | +18% move scale | **+35%** (38 until 2026-09-05) |
| 7 | MAG SIZE | +60% magazine | **+90%** — **AK-47 ONLY** |

### Heavy

| # | Domain | At max today | **DARK** |
|---|---|---|---|
| 38 | VITALITY | +32 max HP | **+50 max HP** (57 until 2026-09-05) |
| 39 | RECOVERY | regen starts 32% sooner | **45% sooner** |
| 36 | BACK ARMOR | -32% from behind | **-45%** |
| 26 | OVERDRIVE | +25% at full ramp | **+65%** (+50% until 2026-09-08) |
| 42 | FULL STEAM | +21.6% burst | **+41.6%** |
| 10 | BULLET FEED | 5.0 rounds/s into the mag | **7.0 rounds/s** |

### Slasher

| # | Domain | At max today | **DARK** |
|---|---|---|---|
| 43 | ATHLETE | level 5 on all lanes | **computes as level 7** |
| 13 | LEECH | 10 HP per blade kill | **a FLAT 25 HP** (18 until 2026-09-05). AND LEECH NO LONGER STACKS at any level: one heal per swing, cleave-splash victims pay nothing (`tod_no_leech`) |
| 14 | CLEAVE | 100% chance of +1 target | **a guaranteed 2nd extra target** |
| 20 | THOR'S THUNDER | radius 192, frac 0.64, cap 6, cd 1500ms | **+50% on every term** |
| 44 | GUNSLINGER | +150% sidearm vs bosses | **+180%** (a +30 step) |
| 18 | KNIFE SPEED | -26% swing time | **-46%** — **STORMBREAKER ONLY** |

### The 2026-09-05 pass (user, verbatim list)

*"Vitality goes from 57 -> 50. Mega Trail Blaze impacts bosses. Giant Slayer goes
from 85% -> 80%. Leach goes to 25HP but doesnt stack. This is a change to leech
overall. Riot SHield from 1:30 -> 1:15. Forced March goes from 38% -> 35%. Run
and gun goes from 77% -> 100%. Remove dark luck."* All eight landed in v17.66;
the rows above carry the new values with the old ones in brackets. LUCK moved to
the no-dark list (`set_no_dark( "luck" )`, `DARK_NONE[4]`, its dark card and red
plate UNZONED, art kept in `source_data`). "Doesn't stack" was read as ONE heal
per swing regardless of how many zombies the swing killed, applied to every leech
level, since the user called it a change to leech overall.

### Two values revised on the balance pass (user 2026-09-04)

Both were the outliers flagged after the stacks were recomputed, and both were
cut by the user rather than defended:

| domain | was | **now** | why it moved |
|---|---|---|---|
| SCAVENGER | one fewer kill, flat (1.8 -> 0.8) | **-40% of the current requirement** (1.8 -> 1.08, assault 1.6 -> 0.96) | the flat -1 was the biggest relative jump in the whole set — **2.25x** the ammo rate, 2.67x for the assault, which is near-infinite primary ammo. A proportional cut is 1.67x and scales with the class's own cap. User: *"limit scavenger to 40% reduction of what you are at"* |
| GUNSLINGER | +100 (to 250%) | **+30 (to 180%)** | dark DAMAGE + dark GUNSLINGER put the slasher sidearm at 11.25x vs today's 7.875x = **+43%**, on a lane emergency-reshaped in v16.99 and moved again in v17.4. At +30 it is 9.675x = **+22.9%**, in line with the assault's +32% Panzer head. User: *"Sidearm can be 30% instead"* |

### The ten with NO dark upgrade

| Domain | Why |
|---|---|
| SPRINT FIRE (21) | user: NONE |
| SECOND WIND (33) | user: NONE |
| DISTRACTION (41) | user: NONE |
| DEADSHOT (47) | user: NONE |
| SUPPRESSING FIRE (29) | user: NONE (confirmed 2026-09-04) |
| DRAW CUT (31) | user: NONE (confirmed 2026-09-04). Also Wakizashi-bound, so a T3 slasher can never hold it |
| FIRE RATE (15) | stays blocked — weapon-variant ladder, +8 registrations |
| RECOIL (17) | stays blocked — weapon-variant ladder, +24, the priciest rung in the map |
| PENETRATION (19) | stays blocked — `penetrateType` enum already at `large` |
| PERK SLOTS (40) | stays blocked — no-op, the spire floors everyone at the 9-perk roster |

**Art is still baked for all 37**, so any of these ten can be turned on later
without another generator trip. Do not ZONE a card whose domain cannot deal it.

## THE THREE GUN-RESTRICTED REVIVALS — COSTED, 2026-09-04

The user revived MAG SIZE, HANDLING and KNIFE SPEED from the blocked list by
restricting each to ONE gun. That is the right instinct and it nearly works.

**Live ledger 220** (`node tools/gen_tod_twins.js` prints it: 191 generated + 29
fixed), **`LEDGER_GUARD` 224** (`tools/gen_tod_twins.js:623`), and map 1's
only-ever-proven-to-boot table is **229** (368 = boot-AV). Cost of each, from the
cartesian product in `variantsOf()` — combos x {base, _up}:

| domain | gun | axis change | combos | registrations | ledger |
|---|---|---|---|---|---|
| HANDLING | `t6_mp7` | `h` 3 -> 4 | 4 -> 5 | **+2** | 222 ✓ |
| KNIFE SPEED | `leviathan` | `k` 5 -> 6 | 6 -> 7 | **+2** | 222 ✓ |
| both | | | | **+4** | **224 — exactly the guard** ✓ |
| MAG SIZE | `t9_ak47` | `m` 3 -> 4 | 12 -> 15 | **+6** | 226 ✗ |
| all three | | | | **+10** | **230** ✗ |

MAG SIZE costs 3x the others because the AK sits on a TWO-axis product
(`r` x `m`, `tools/gen_tod_twins.js:959`), so a new `m` rung multiplies across
all three recoil levels and both PaP forms.

**TWO PREREQUISITES, both real:**

1. **`variantsOf()` HAS NO PER-GUN AXIS LEVEL** (`tools/gen_tod_twins.js:1548`) —
   it reads `AXIS[letter].levels` globally, so bumping `m` to 4 today adds a rung
   to the Enfield and the Krig 6 as well (+18, not +6). **"Only the AK" is not
   expressible until the generator learns a per-gun override.** That is a small
   change to one function, but it must land BEFORE any of these three.
2. **The guard would have to move for MAG SIZE.** Its own comment forbids raising
   it. 226 is under map 1's proven 229 so it is defensible; 230 (all three) is one
   past the only count ever observed to boot — unproven, not proven-fatal.

**What the user got right and an earlier pass got wrong:** all three named guns
are **TIER 3** (`t6_mp7` skirmisher, `t9_ak47` assault, `leviathan` slasher), so
no tier promotion can wipe them. The "these reset on promotion" objection raised
against the original blocked list does not apply to this shape.

**Recommendation:** ship HANDLING + KNIFE SPEED (exactly 224, no guard change),
and hold MAG SIZE until an axis is retired somewhere to pay for it.

## THE STACKS, IN REAL NUMBERS

**Heavy, all four mitigation domains dark.** Juggernog is guaranteed in the spire
(perma perks), so `max_hp_floor` = 150 base + ladder5(vitality) + 100.

| | maxed today | all dark |
|---|---|---|
| max HP | 282 | **295** |
| front multiplier | 0.70 | **0.625** |
| rear (with BACK ARMOR) | 0.476 | **0.375** |
| front effective HP | 403 | **472 (+17%)** |
| rear effective HP | 592 | **787 (+33%)** |

**But effective HP is not what moves. RECOVERY is.** Above the 20% cutoff the
delivery is `SetNormalHealth( 1 )` — a snap to full (`_tod_upgrades.gsc:2884`) —
so the real metric is how often the whole bar resets: 1632 ms -> **1320 ms**.
Pool x reset together = **~45% more sustained mitigated throughput**, not the 17%
the eHP figure suggests. That is the single strongest reason DR is 37.5 and not 42.

⚠️ **Do NOT take the tidy "ladder5 dark rung = 45 serves VITALITY, RECOVERY and
BACK ARMOR".** All three want 45 arithmetically, and it is one edit — but BACK
ARMOR at 45% multiplies with DR and pushes rear eHP to ~865 (+46%), while the
other two do not. Put the dark value at each domain's own `ladder5` read site
(`:1936`, `:2465`, `:2876`) and leave `ladder5()` and its Lua mirror alone.

**Assault vs a Panzer head**, dark DAMAGE + HEADSHOT + GIANT SLAYER:
`3.0 (locHead) x 3.10 x 0.9 = 8.37x` today -> **10.64x**, **+27.1%**. Against the
Warden ladder (`0.956 x 1.08^(tier-1)` — 0.956x at trial I, 1.911x at trial X) a
flat +27% is outrun by trial III. The counter-scaling holds.

**Slasher, dark SPRINT x dark ATHLETE:** the slide multiply reads the engine's
actual entry speed, so the two darks partially cannibalise each other through the
`TOD_ATH_SPEED_MAX 800` wall — which is exactly what that wall is for.
**Do not raise it to recover the lost slide;** its own comment calls it "a safety
wall on the slide multiply, not a tuning knob."

**The worst number in the set is not the assault** — it is the slasher sidearm at
+28.6% (item 4 above).

## KNOWN PACING DEFECT — eligibility cost is wildly uneven

DAMAGE takes ten levels to max. SPRINT FIRE and DEADSHOT take **one card of any
rarity**. A skirmisher maxes DMG REDUCTION (class cap 3) with **one ULTIMATE**, and
at luck bar >= 150 `guarantee_both_ultimate` makes both non-tier cards ULTIMATE —
so "maxed" can be reached on the first deal. **The first dark card a player is
offered will reliably be the cheapest domain they own, not the one they invested
in.** Cheapest fix, costing nothing: at most **one dark offer per trial win**, and
require at least one trial win between taking a domain's last level and its dark
offer.

## WIRING NOTES (for whoever implements this)

- **Hook:** `_tod_spire.gsc:2018 trial_upgrade_deal( hub )` — three lines, calls
  the shared `run_upgrade_event()`. `hub` is accepted and never read, and
  `trial_tier(hub)` is available if dark odds should scale with trial depth. It is
  the *only* card source in the spire (`level.tod_upgrades_suppressed` at `:484`
  kills the round clock; stations exist at base/breathers/crown only).
- **Three filters must learn about dark or the feature never fires for its own
  audience:** `player_has_domains_left` (`:3639`, read by the participant filter at
  `:3452`), `eligible_pool` (`:4340`), `player_has_upgrades_left` (`:3645`). A
  fully-maxed player is dropped from the event *before* the roll today.
- **`o.levels = o.rarity` by construction** (`:4180`) — rarity IS the level count.
  A dark card must break that identity and take the `set_rarity_lock` route
  (`:1651`, DEADSHOT's precedent, applied AFTER the band-honesty clamp).
- **The rarity wire has no room for a 4th band.** `todUpgAR`/`todUpgBR` are **2
  bits** each (`_tod_upgrade_ui.gsc:160`/`:165`) and the clientuimodel pool is at
  **60 of 61 proven-booted bits** — a rarity of 4 silently truncates to 0.
  Cheapest route: rename and reuse the dead 1-bit `todMagBonus` (`:170`) as a
  per-slot "this card is DARK" flag, plus the one spare bit.
- **Both luck guarantees need a dark exemption**, exactly like the tier card's:
  `guarantee_rarity`'s `if ( o.rarity >= want ) return;` (`:3917`) would silently
  cancel the ULTIMATE floor on the other slot.
- **Every pause row must learn the dark value** — the card is frozen art, so
  `DETAIL[id].val` is the only surface a player ever reads a number on. Watch the
  table-index rows that return **nil** past their length and are swallowed by
  `CoD.TodDomainDesc`'s pcall, and the `math.min(l,5)` clamps.
- **Filter PERK SLOTS out of the spire deal at every rarity while you are here** —
  three dead cards currently sit in the exact deal a player fought a 90-second
  trial for.

## IMPLEMENTATION STATUS — v17.10, 2026-09-04. CORE IN, GATED OFF.

**`#define TOD_DARK_ENABLED 0` in `_tod_upgrades.gsc` is the master switch and it
is OFF.** The deal path is complete and compiles (BUILD OK, fresh `.ff`), but only
four effect lanes read the bit, so turning it on today would deal cards that pay
nothing for every other domain — silently. Flip it to 1 when the last lane lands.

### Done

| | |
|---|---|
| Storage | `player.tod_dark[ key ]`, a per-player BIT. Never a level — see the three rules above. |
| Exceptions | `set_no_dark()` x13: the ten with no dark step, **plus MAG SIZE / HANDLING / KNIFE SPEED parked** until the generator learns per-gun axis levels. |
| Pool | `dark_pool()` — available AND maxed (through `domain_max`, never `d.max`) AND not already dark. `has_dark()` / `dark()` are the reads. |
| Deal | `make_dark_option()` (deliberately NOT via `make_option` — every clamp there is keyed on headroom and a dark card has none) and `deal_dark()`, carrying the guarantee. |
| Guarantee | `level.tod_dark_guarantee`, set and cleared *around* the call in `trial_upgrade_deal`. One slot forced; an EMPTY right slot is always filled with a second dark card when one exists (v17.46), and `TOD_DARK_BOTH_PCT` is 100 (was 35) so a regular card is displaced too — "eligible for two means dealt two" (user 2026-09-04). |
| The three filters | participant filter gained a third arm; `player_has_upgrades_left` gained the dark test; the `pool.size == 0` early return now builds a dark hand instead of refusing. |
| Apply | `apply_upgrade`'s dark branch sits ABOVE every levels test, and pokes the two inventory reconcile pointers by hand (a bit is not a level write). |
| Luck guarantees | both skip dark cards — one would have read rarity 3 as "the floor is met" and cancelled the other slot's ULTIMATE; the other would have overwritten the zero-levels contract. |
| Wire | **ZERO clientfield bits.** The 4-bit level field carries `TOD_UPG_DARK_L` 15. The pool stays at 60 of its 61 proven-booted bits. |
| Sound | `dark_aura()` — its own driver with a 7.6 s unit, the same four aborts, and it outranks the heavenly pad for the whole deal. |
| Lua | `DARK_L`, the `DARK UPGRADE` tag, and a gated `USE_DARK_CARD_ART` art path (OFF — the cards are not zoned). |
| Effect lanes | **ALL 24 WIRED.** Verified by `grep has_dark(` rather than a hand-kept list. |

### Still to do

1. **THE ONE BLOCKER: the card art.** `TOD_DARK_ENABLED` cannot be flipped until
   the dark cards are zoned, and NOT for a cosmetic reason — with
   `USE_CARD_SET_ART` on and no dark art, a dark card draws its ULTIMATE image,
   which has **"ULTIMATE +3" baked into the pixels**. The card would state a
   rarity and a level count that are both false about what it just paid. Zone the
   24 dealable cards (~81 MiB) or take the shared-overlay route (~3.4 MiB); either
   way, flip `USE_DARK_CARD_ART` and `TOD_DARK_ENABLED` together.
2. **The cadence** (below) — none of the three sources runs yet.
3. **Card art**: zone the 24 dealable dark cards, teach
   `tools/lint_tod_assets.js` the fourth rarity, flip `USE_DARK_CARD_ART`. Or
   take the shared-overlay route instead — see THE ART.
4. **The pause menu** has no dark readout.
5. The generator's per-gun axis override, to unpark the three gun domains.

### Two lanes worth recording, because both were traps

* **THOR'S THUNDER's cooldown floor had to move with it.** Lv5 already sits
  exactly on `TOD_THOR_CD_MIN_MS` 1500 (4500 - 4x750), so scaling the cooldown by
  1.5 and re-clamping against the same floor returns 1500 — the rate third of
  "+50% all around" would have been eaten by a clamp that looks correct.
  `TOD_DARK_THOR_CD_MIN_MS` 1000 is the dark floor. Also note `r2` is now computed
  AFTER the dark scale; leaving it where it was would have silently kept the base
  radius while every other term grew.
* **CLEAVE cost nothing to build.** `cleave_splash` already takes a `count`, its
  loop already handles 2, and its echo already fires once per swing rather than
  once per victim — all left in place by the author "in case the cap ever goes
  back up". This is that case.

## THE SPIRE UPGRADE CADENCE (user 2026-09-04) — THREE SOURCES, NONE OF WHICH RUN TODAY

User: *"At the endless spire you still get upgrades every 4 rounds. Not sure if
that got removed or not. Addition to that you get an upgrade every level of the
tower. If you have an upgrade maxed then you must get the dark upgrade as an
option after you defeat a trial and get upgrade rewards. If you have multiple it
is possible to get both cards as dark upgrades but the only guarantee is that one
must be a dark upgrade."*

**IT WAS REMOVED, DELIBERATELY.** `level.tod_upgrades_suppressed = true`
(`_tod_spire.gsc:484`, v16.36) is read at `_tod_upgrades.gsc:3399` (the round
clock) and `:6844` (the station gate). Stations are not placed above the crown
anyway. **A won trial is the spire's only upgrade source today.** So all three of
the below are new work:

**SCOPE CORRECTED BY THE USER, 2026-09-04:** *"I just want to continue the 4
round cadence of getting upgrades on the spire. Thats all. And you get one on
every trial too but thats in the game already."* **THE PER-FLOOR DEAL IS NOT
WANTED** — the first reading of the brief added it, and that was wrong. Two
sources, not three.

1. **Every 4 rounds — DONE (v17.10).** One flag, `tod_upgrades_suppressed`, gated
   BOTH the round clock and the personal station, so it was split: the FINALE
   keeps `tod_upgrades_suppressed` (its closing song is the run clock and a world
   freeze does not stop a music stream) while the SPIRE now sets
   `tod_stations_suppressed`. The scheduler runs its normal every-4th-round
   cadence up there, and stations stay dead (none are placed on the spire anyway).
   ⚠️ **The finale's flag is now cleared explicitly at ascension.** It is set on
   the road run and never cleared — it never needed to be, because the old spire
   line re-set the same flag to true. With the spire on a different flag, a stale
   `true` would have survived ascension and the round clock would have dealt
   nothing for the whole endless run: no error, no log line, just a cadence that
   silently never fires.
2. ~~One per spire floor~~ — **NOT WANTED. Do not add it.**
3. **Trial win** — the existing `trial_upgrade_deal` plus the dark guarantee,
   already shipped.

**THE DARK GUARANTEE, exactly as specified:** on the trial-win deal, if the player
has **at least one maxed domain**, at least ONE of the two cards must be a dark
upgrade. With several maxed domains BOTH cards may be dark; only one is
guaranteed. This is the same shape as `guarantee_rarity` (`:3875`) — promote one
slot after the roll — and it must be sequenced with the two existing luck
guarantees, which both test `o.rarity >= want` and would otherwise early-return or
demote a dark card.

⚠️ **THE CADENCE IS A BIGGER BALANCE LEVER THAN ANY SINGLE NUMBER, and it
re-prices the whole dark feature.** Today the spire deals ~10 cards a run (one
trial deal per hub). Adding a deal per floor plus one every 4 rounds takes that to
**~100+**. Consequences that follow by construction, not by opinion:

* **Dark stops being a capstone and becomes the normal state.** Domains max early,
  so the "one card must be dark" guarantee fires on nearly every trial from the
  first few hubs — which is the opposite of the rare-reward framing the values
  were priced against.
* **Small-cap domains max almost immediately** — SPRINT FIRE (1), RECOIL (2),
  PENETRATION (2), DMG REDUCTION at the skirmisher cap (3). One ULTIMATE is +3
  levels, so a single card can max a domain and make it dark-eligible on the spot.
* **One mitigating factor, free:** the luck bar RESETS to 0 after every deal, so
  more deals means more time spent near zero, which lowers average rarity. The
  card flood is partly self-damping.

## THE SOUND — `tod_dark_aura`, installed and banked, NOTHING PLAYS IT YET

User 2026-09-04: *"When you get a choice of this upgrade we will play a wav ...
Currently for ultimate we play a heavenly choir sounds. This one will override
that and play a dark angelic revelation sounds ... trim the beginning and also it
will pulse a bit"*, then chose *"B but repeats until selection"*.

**WHAT IT OVERRIDES IS THE AURA, NOT THE STING.** `tod_ultimate_sting` and
`tod_super_sting` deliberately resolve to the SAME wav — v14.57 repointed the
alias on the user's own call (*"the only difference is that ultimate hears the
aura"*), and `tod_ultimate_sting.wav` is parked in `sound_assets` unreferenced on
purpose. **Rarity reads entirely through `tod_upg_aura_*`.** So the dark cue is a
fourth aura, not a fourth sting; the riser (`tod_reveal_charge`) and the land
sting are unchanged.

**The asset (installed 2026-09-04):** `sound_assets/tod/sfx/tod_dark_aura.wav` —
7.80 s, 48000 Hz stereo s16, peak **-4.4 dBFS**, mean -14.4 dB. Recipe, from the
source `Dark_angelic_revelat_#1-1788496121727.wav` (10.00 s):

```
atrim=start=2.20,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.02,
afade=t=out:st=7.45:d=0.35,tremolo=f=1.25:d=0.45,volume=-4.4dB
```

* **The 2.20 s head trim is measured, not taste.** The source opens with a
  decaying tail — -30 dB RMS at t=0 falling to -56 dB by 2.0 s — and the real
  transient is at 2.25 s. (`silencedetect` at -45 dB reports NO leading silence,
  which is why the trim point had to come from a windowed RMS profile instead.)
* **The throb is baked in** at 1.25 Hz, depth 0.45 — that is the user's "pulse".
* **Peak matched to `tod_upg_aura_both`** (also -4.4 dBFS) so the alias volume
  **92** carries over unchanged and the dark cue sits exactly where the heavenly
  pad sat in the mix. Loudness knob is that column, per `audio-tooling`.
* Alias row added to `sound/aliases/tod_ui.csv` beside the aura family:
  `UIN_MOD`, `2d`, `NONLOOPING`, vol 92/92 — a clone of `tod_upg_aura_both`.

**THE DRIVER CONTRACT — reuse `ultimate_aura()`, do not write a second one.**
`_tod_upgrade_ui.gsc:676` already is "retrigger this alias until the panel is
done", with **four** ways out (`tod_upg_aura_stop`, `disconnect`,
`tod_solo_down_abort`, `tod_global_upg_takeover`) plus a pass ceiling — and it
needs all four, because the panel is torn down on more paths than it is closed
on. A dark card calls the same function with `"tod_dark_aura"`; only the unit
changes:

| | heavenly | dark |
|---|---|---|
| wav length | 2.00 s | 7.80 s |
| retrigger unit | `TOD_AURA_UNIT_SECS` 1.8 | **7.6 s** — overlaps the 0.35 s out-fade as a re-swell, not a gap |
| passes | `TOD_AURA_MAX_PASSES` 14 | 3 is ample (the panel times out at 15 s) |

So the unit and the pass ceiling must become per-call arguments, or a second pair
of defines. **Do not just raise `TOD_AURA_UNIT_SECS`** — the heavenly aura's 1.8 s
against a 2.0 s wav is a deliberate 0.2 s overlap and shares the constant.

**ONE ASSET, CENTRED — no `_l`/`_r` pans yet.** The heavenly aura is pre-panned to
its card's side; the dark cue is not, deliberately: a dark upgrade is a singular
rare event and reads better as enveloping than as positional, and the feature has
no code yet to say whether two dark cards can ever be dealt at once. If pans are
wanted later they are one ffmpeg command each.

⚠️ **Nothing calls this alias today.** It is banked (~1.5 MB) and ready; it costs
a `-GscOnly` build to hear once the dark card lane exists (sound banks are rebuilt
by the linker, so no full build is needed for alias/wav changes).

## THE ART

**37 cards** (user 2026-09-04: *"Prepare the zip as if all upgrade will get the
dark upgrade. Then we can decide after"*), `i_tod_card_<slug>_dark.png`. The seven
blocked domains get art too, so the mechanic decision is never gated on art. Brief
and pack: `docs/93_dark_upgrade_cards_art_prompt.md`.

**EVERY DARK CARD'S VALUE LINE IS GENERIC** (user, same day: *"Make sure its
generic"*) — the standing `generic-card-text-rule`. Nine ULTIMATE cards bake a
figure and all nine lose it on their dark twin. That is what makes "bake all 37"
safe: **a numberless card cannot be falsified by a value nobody has decided yet**,
LUCK stops printing a smaller number than the rarity below it, and no dark card
owes a re-bake when a domain is retuned. Only the pause row moves.

⚠️ **Do not zone a dark card whose domain cannot deal it.** Art in `source_data`
costs nothing; a zoned unreachable card is 3.4 MB of load RAM each, ~24 MB for the
seven.

⚠️ **THE RAM BILL IS THE REAL DECISION.** Every `i_tod_card_*` is `uncompressed`
768x1152 RGBA (`source_data/tod_ui_images.gdt:157`, 568/568 blocks identical) =
**3.375 MiB of load RAM each**, resident from menu creation. The 117 live cards
already cost **395 MiB — 77% of all UI-art load RAM and ~24% of the `.ff`.**

| route | new images | load RAM | `.ff` |
|---|---|---|---|
| 37 full dark cards at 768x1152 | 37 | **+125 MiB** | +10 MiB |
| the 30 dealable ones only | 30 | +101 MiB | +8 MiB |
| 37 dark cards at 512x768 | 37 | +55 MiB | +5 MiB |
| **one shared dark overlay frame** | 1 | **+3.4 MiB** | +0.3 MiB |

The overlay lane **already exists and is complete**: `art.frames[]` is registered
(`tod_upgrade.lua:917-923`), `FrameArt` is created AFTER `CardImg` so it composites
on top (`:1568-1574`), it is repainted every paint (`:2043`) and it rides in
`card.group` so the reveal flip already carries it. It is force-disabled by ONE
line (`:681`), and `i_tod_frame_*` is still zoned — **8 MiB of frame art is being
paid for right now and drawn zero times.** The three existing frames are 1024x512
landscape against a portrait card, so the overlay would need a new portrait bake.
`setRGB` is also already used to tint a whole card for the locked state (`:2431`),
which is a free dark-red wash on the existing artwork.

⚠️ **`tools/lint_tod_assets.js` hard-codes `['regular','super','ultimate']`
(`:208`/`:243`)** — 30 dark cards would be entirely unguarded by GATE A, and a
missing `image,` line draws a **WHITE SQUARE** with the lint green. Teach the lint
the fourth rarity in the same commit that zones the first dark card.

## Chain Lightning enabled (2026-09-09)

Normal additional targets: 1/2/2/3/3/4 at levels 1..6. Dark: 6.
The direct hit is separate; each arc keeps half damage and skips the Panzer.
Uses the existing maxed-domain Spire Dark pool and ownership bit. Dedicated
Dark art is absent: DARK_TEXT_ONLY[53] suppresses image registration and the
card renderer selects the existing composite DARK text layout. It must never
fall through to an Ultimate picture with a baked +3 claim. Asset lint checks
both routing guards before honoring this exception. Pause uses the tinted
base plate through DARK_PLATE_NONE[53]. No new clientfield or weapon asset.
