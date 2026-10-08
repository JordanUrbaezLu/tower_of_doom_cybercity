# 25 — CLASS TIERS: the design (v10 plan, 2026-08-22)

**Status: IMPLEMENTED (2026-08-22, CHANGELOG v9.12 + v9.13).** Phases 0–3
are built: the tier card, all 8 tier guns (incl. the Wakizashi = the katana,
stem `t9_me_wakizashi`) and the 7 uniques — final build 75.96 MB @ 1:42:33
PM, ledger 159/200. OUTSTANDING: the art (§10 prompts; all cards render on
the text fallback), in-game tuning after the user's play test, and the
Leviathan's stock fire-axe audio verification. The roster below is the
USER-LOCKED one; §9 is authoritative over anything an older session
remembers.

**User decisions (2026-08-22), all applied:** (1) the T1 guns change —
MAC-10 and Enfield open every run, class-card art re-bake is REQUIRED;
(2)+(3) Enfield + HK21 ports installed (Skye BO1); (4) katana port link
still needed; (5) Thor's Thunder is Stormbreaker-only, Lv1 granted on
arrival; (6) keep BOTH Death Machines (class gun + the powerup); (7) a tier
step never shrinks the magazine (generator rule, §6); (8) MAC-10 and
Enfield are the first real-gun builds. Body domains RESET; BOUNTY resets;
the tier card is right-slot / never auto-locked; station deals include it;
LUCK does not move the 10%.

## 0. The pitch (user, 2026-08-22)

> For each class, once you have PaP'd your gun you have a 10% chance to pull a
> card that upgrades your class to tier 2 — a new, stronger gun, about as
> strong as the PaP'd version of your current gun, but you lose the gun's
> personal upgrades (damage, bullet feed, …). Class upgrades persist: damage
> resistance, luck, maybe only those two. Three tiers per class; the last tier
> is the most popular guns in that class. Some guns have their own unique
> upgrades — e.g. Thor's Thunder leaves the Combat Axe, and one of the axe's
> upgrades is the Leviathan Axe, which carries Thor's Thunder.

What this adds to the run: a second progression axis that RESETS the first.
Today a player's power curve is one monotonic climb (23 domains, luck-rolled).
Tiers add a deliberate gamble — trade a fully-upgraded gun for a stronger
base that has to be re-levelled — and give the late game a reason to keep
dealing cards after a class has seen every domain.

## 1. Hard constraints (measured — the design lives inside them)

| # | Constraint | Number | Source |
|---|---|---|---|
| 1 | Weapon-registration boot ceiling | **230 good / 368 = silent 0xC0000005 at boot** | map 1 docs/21 §A; CHANGELOG v9.1 |
| 2 | Registrations spent TODAY | **97** = 13 (main zone) + 82 (`tod_twins.zpkg`) + 2 (xmas gun) | `grep -c '^weapon,'` 2026-08-22 |
| 3 | Headroom | 133 — the design CAPS new spend at ~90 (generator asserts ledger ≤ 200) | this doc §7 |
| 4 | clientuimodel pool | **61 custom bits = proven ceiling** (83 aborted to lobby) | `_tod_upgrade_ui.gsc` BUDGET note |
| 5 | Domain-id field width | `todUpgAD`/`todUpgBD` are **5 bits → max id 31**; 23 used | `_tod_upgrade_ui.gsc:45,48` |
| 6 | Gun-data upgrades | max 3 levels per axis, ONE axis per gun in the new tiers (8 assets); melee swing ladders 5 levels (12) | user rule 2026-08-19 + budget |
| 7 | Roster parity | every gun: `locHead/Helmet/Neck 3.0`, `moveSpeedScale 1`, recoil ×1.15, ADS time ×1.20, PaP = base +25% | memory `roster-parity-rule`, `gen_tod_twins.js` |
| 8 | altWeapon boot trap | every vendored GDT screened for a live `altWeapon` before it is zoned | `_tod_classes.gsc:15` |
| 9 | One gun per build | boot-test after EVERY gun added — never batch | map 1 hard rule |
| 10 | Stock vending/PaP paths | class guns are PaP'd by NAME (`_up` in `weapon.name`) or the free-PaP latch `player.tod_pap_owned`. **v9.14 (review 2026-08-22): the roof machine never worked on the twins because the zone had NO `stringtable,gamedata/weapons/zm/zm_levelcommon_weapons.csv` line** — TableLookup hit the stock table in zm_levelcommon.ff, `level.zombie_weapons` had no class-gun row and `is_weapon_included()` was false. Fixed with the zone line (map 1 precedent). | zone + `_tod_powerups.gsc:108-116` |

Constraint 5 is the one that forces an engine-facing change: a TIER card plus
~12 unique-gun domains do not fit in 31 ids. §8 pays for the widening with
the dead `todMagBonus` field (7 bits registered, never set since 2026-08-20).

## 2. The model

Three nouns, kept separate on purpose:

- **CLASS** (4, unchanged): `skirmisher / assault / heavy / slasher`. Owns move
  speed (`class_speed_base`), the draft, and the class-gated domain pool
  (`class_keys`). A player's class never changes.
- **TIER** (per player, 1..3): `player.tod_tier`, starts at 1. Promoted ONLY by
  taking a TIER card. Never demoted.
- **GUN** (a registry entry): what the player actually holds. Each class has a
  3-entry ladder `c.tiers[1..3]`, and a gun may have **transform** siblings
  (the Stormbreaker is a transform of the Combat Axe — same tier, same
  upgrades, different asset).

### 2.1 Registry change (`_tod_classes.gsc`)

`register_class` keeps its signature for the draft; the gun fields move out
into a gun struct so every module resolves "the class gun" PER PLAYER:

```
register_class( key, display, station_org )                // class identity only
register_gun( class_key, tier, stem, up_suffix, axes, label, alt_weapon, uniques )
   stem        "t9_krig6"            asset stem; variants are stem[+up_suffix]+suffix
   up_suffix   "_up" | "_upgraded"   the port's PaP suffix (per gun, already per class today)
   axes        array of { domain:"firerate", letter:"f", max:3 }  -> variant suffix
               (undefined = no ladder; the gun still has ONE generated base form "_b")
   label       "KRIG 6"              baked into art, never printed (no floaty text)
   alt_weapon  "bowie_knife" | undefined
   uniques     array of domain keys only this gun can roll (see §5)

tod_classes::gun( player )          -> the gun struct for player.tod_class + player.tod_tier
tod_classes::gun_stem( player )     -> gun(player).stem (or the transform's stem if transformed)
tod_classes::is_class_primary( player, weapon )   -> matches CURRENT gun (+ transform + alt) ONLY
tod_classes::next_gun( player )     -> c.tiers[ tier+1 ] or undefined
```

Every `c.primary` / `c.up_suffix` / `c.alt_primary` read in the tree becomes a
`gun(player)` read. The full list (grep 2026-08-22, 9 sites):
`_tod_classes.gsc` give_class_loadout + is_class_primary;
`_tod_upgrades.gsc` class_primary_in_inventory, reconcile_twin (×2),
twin_suffix; `_tod_runandgun.gsc:78`, `_tod_bosses.gsc:1476` and
`_tod_upgrades.gsc:1292/1570` go through `is_class_primary` and need no edit.

**Stem-prefix trap:** `is_class_primary` matches by `IsSubStr( weapon.name,
stem )`. Two stems where one is a prefix of the other (`t9_mp5` /
`t9_mp5k`) would cross-match. The registry asserts at init that no stem is a
prefix of another stem in the same class ladder.

### 2.2 Variant naming is generic now

Today `twin_suffix()` is a per-class switch. It becomes per-gun, derived from
`axes`, so a new gun never touches GSC:

```
suffix = ""
foreach axis in gun.axes:  suffix += axis.letter + get_level( self, axis.domain )
if ( suffix == "" )  return "_b"            // base-tuned form, no ladder
return "_" + suffix                         // "_f1h2", "_r0m3", "_p1", "_k4" — today's names unchanged
```

The generator emits the SAME naming (`<stem>[<up_suffix>]<suffix>`) and the
CSV rows (`variant,variant_up`) so the roof PaP machine and the free-PaP
latch both keep working on every tier gun. (The CSV only reaches the game
through a `stringtable,` zone line — added in v9.14; without it the roof
machine silently refused every class gun.)

### 2.3 Domain scope — the new field

`add_domain(...)` gains two trailing fields:

```
d.scope     "class" | "gun"     class = survives a tier-up; gun = reset to 0 on tier-up
d.gun_keys  undefined | array of stems   undefined = any gun of the gated classes;
                                         defined  = only while gun_stem(player) is in the list
```

`domain_available( player, d )` gains the `gun_keys` check. This one field
implements three things at once: the existing twin ladders stay bound to the
guns that have them (FIRE RATE is the MP5's; the T2 SMG never rolls a dead
card), unique-gun upgrades (§5), and the Thor's Thunder relocation.

## 3. Which upgrades are CLASS and which are GUN (the preservation table)

Rule from the user: *"almost no perks will [persist] but damage resistance,
luck, maybe only those two."* Recommendation below = that rule applied
strictly. The BODY rows are the only judgment call — they are trained on the
player, not the gun, but keeping them would shrink the gamble; I recommend
they reset (it also means SPRINT Lv5 tireless is genuinely lost, which is
what makes the T2 card a real decision for a skirmisher).

> ⚠️ **The Scope column below is v9-era and has been INVERTED since v15 (2026-08-31).** Persistence is the DEFAULT now — `add_domain` sets `scope = "class"` and only the explicit `set_scope( key, "gun" )` list in `register_domains` resets on a promotion, so DAMAGE, BOUNTY, SPRINT, SPRINT FIRE, HEADSHOT, GIANT SLAYER, SCAVENGER, BULLET FEED, LEECH, CLEAVE and RUN AND GUN all SURVIVE it, and SCAVENGER's assault-only carve-out is gone. `domain_survives_tier()` is the one authority; read the `set_scope` calls, never this table.

| id | Domain | Gate today | Scope | Bound to | Note |
|---|---|---|---|---|---|
| 2 | DMG REDUCTION | shared | **CLASS — kept** | — | user |
| 4 | LUCK | shared | **CLASS — kept** | — | user; compounds into the re-level |
| 32 | SPRINT ARMOR | skirm+slasher | **CLASS — kept** | — | damage resistance, the family the user's rule keeps (v9.28) |
| 36 | BACK ARMOR | assault+heavy | **CLASS — kept** | — | damage resistance, same rule as DR / SPRINT ARMOR (v9.45) |
| 1 | DAMAGE | shared | GUN — reset | any | user's example |
| 3 | BOUNTY | shared | GUN — reset | any | economy, not gun-specific — flagged; strict rule says reset |
| 5 | SPRINT | skirm+slasher | BODY → reset | any | judgment call (see above) |
| 9 | MOBILITY | heavy | BODY → reset | any | judgment call |
| 12 | REGEN | heavy | BODY → reset | any | judgment call |
| 21 | SPRINT FIRE | skirm | BODY → reset | any | player specialty; the body loop's UnsetPerk branch already handles a 0 |
| 6 | HEADSHOT | assault | GUN — reset | any | |
| 35 | GIANT SLAYER | assault | GUN — reset | any | v9.45; pays only vs the is_boss / acc_is_boss / acc_is_mini_boss triad |
| 8 | SCAVENGER | skirm/assault/heavy | GUN — reset | any gun with a reserve | |
| 10 | BULLET FEED | heavy | GUN — reset | any | user's example |
| 11 | ECHO ROUNDS | heavy | GUN — reset | any | |
| 13 | LEECH | slasher | GUN — reset | any melee | |
| 14 | CLEAVE | slasher | GUN — reset | any melee | |
| 22 | CHAIN LUNGE | slasher | GUN — reset | any melee (reads the held blade) | re-rollable on every tier |
| 23 | RUN AND GUN | skirm | GUN — reset | any | v16.36: REQUIRES SPRINT FIRE (id 21) owned before it can roll — `set_requires( "runandgun", "sprintfire" )` |
| 7 | MAG SIZE | assault (twin m) | GUN — reset | `t9_krig6` ONLY | ladder exists only on the Krig |
| 15 | FIRE RATE | skirm (twin f) | GUN — reset | `t9_mp5` ONLY | |
| 16 | HANDLING | skirm (twin h) | GUN — reset | `t9_mp5` ONLY | |
| 17 | RECOIL | assault (twin r) | GUN — reset | `t9_krig6` ONLY | |
| 18 | KNIFE SPEED | slasher (twin k) | GUN — reset | `t9_me_knife_american` + any melee given a k-ladder | |
| 19 | PENETRATION | heavy (twin p) | GUN — reset | `t9_stoner63` ONLY | |
| 20 | THOR'S THUNDER | slasher | GUN — reset | **Stormbreaker ONLY** (`leviathan`, the T3 slasher gun) | user: leaves the knife pool; Lv1 granted the moment the Stormbreaker arrives (`register_gun` `grant`) |

Reset mechanics (`tier_up`, §4.3) are generic: every domain with
`scope == "gun"` goes to 0; the pause-menu list already hides level-0 rows
(`AetheriumStartMenu.lua:460` filters `o.lvl > 0`), so a `tod_upg_sync`
push of `(id, 0, max)` per reset domain is all the UI needs.

Live effects that must be UN-applied explicitly on reset (the 1s body loop
only ever SETS most of them):

- tireless: `UnsetPerk("specialty_staminup")` + `SetSprintDuration(4)`;
- `apply_move_speed()` immediately (sprint/mobility);
- `tod_lunge_until = 0` (close any open lunge window), `tod_thor_next_ms`,
  `tod_feed_t`, `tod_bounty_bank`, `tod_scav_kills` → 0;
- SPRINT FIRE: the body loop's `else if HasPerk → UnsetPerk` branch already
  strips it within 1s — no action.

## 4. The TIER card

### 4.1 Eligibility — `tier_card_eligible( player )`

All of:

1. `player.tod_tier < TOD_TIER_MAX (3)`;
2. the class gun is PaP'd: `class_primary_in_inventory()` name contains
   `gun.up_suffix`, OR `IS_TRUE( player.tod_pap_owned )` (the free-PaP latch,
   which reconcile turns into the `_up` form within 1s);
3. `next_gun( player )` is defined AND `GetWeapon( next_stem + "_b" or its
   level-0 suffix )` resolves — never deal a card that cannot pay out (an
   unlinked asset would strand the swap; `reconcile_twin` has the same
   guard);
4. not already holding a Gift of Death / Death Machine powerup gun (the swap
   would fight the powerup's restore);
5. **THE FLOOR GATE** (added v14.35, 2026-08-30 — user: *"You must also reach
   floor 10 to get 2nd tier class upgrade and floor 20 for 3rd tier. I dont want
   players able to be tier 2 or 3 before even opening the first door to the
   tower."*) — `tier_floor_ok( player )`: the player's own climb high-water is at
   or above `tier_floor_req( tier + 1 )`, **floor 10 for T2 and floor 30 for T3** (T3 was floor 20 until 2026-09-02 — docs/72)
   (`TOD_TIER2_FLOOR` / `TOD_TIER3_FLOOR`).

**Why the gate was needed when (2) looks like it already covers it.** It did —
by accident. The first Pack-a-Punch reachable while climbing IS the floor-10
breather vendor (the crown machine sits above all 50 laps), so the normal route
already implied floor 10. Two things leaked through:

* the **free-PaP powerup** sets `tod_pap_owned` wherever it drops, so one lucky
  base-arena drop made a tier-1 player eligible with no doors bought;
* **tier 3 needed no extra climb at all** — you could PaP the T2 gun at the same
  floor-10 machine and promote again on the spot.

**The high-water** (`_tod_gauge::floor_reached`, fed by the 0.35 s gauge poll
into `player.tod_floor_best`): per-player, alive-and-playing only, and
**monotonically rising**. Consequences worth knowing before touching it:

* the gate asks *have you been there*, not *are you there now* — the promotion
  can be taken at a base station or on a teleporter pad once earned;
* nothing re-checks the floor after a card is dealt, and nothing needs to: a
  card legal when dealt stays legal;
* **spectators are excluded on purpose.** A dead player's `.origin` rides the
  spectate camera, so sampling them would hand a body in the base arena the
  climber's floor — the exact free ride being closed. Last stand still samples
  (`sessionstate` stays `"playing"`, `isalive` TRUE): a downed player really is
  on that floor;
* `real_floor_of()` carries an 8-unit epsilon because a player standing on a
  landing sits at the exact z boundary between two floors, and clamps at floor
  50 so the crown, causeway and Endless Spire report the top rather than
  running off the end.

`tier_up()` re-asks `tier_card_eligible()` before promoting, so the gate covers
the round event, the station's deferred cards and the redeals from one edit. The
spire's `grant_all` calls `tod_gauge::mark_top_reached()` first — ascending
players are far above floor 50 anyway, but a grant must not lose a race with the
poll. It is **not** waived by `level.tod_dev`.

### 4.2 Roll — inside `roll_options()`

After the two domain cards are drawn (weighted, without replacement):

```
if ( tier_card_eligible( player ) && RandomInt( 100 ) < tier_card_pct() )
    opts[ 1 ] = make_tier_option( player )      // the RIGHT card, always
```

- `tier_card_pct()` = `TOD_TIER_CARD_PCT` **20** (was 10 until v9.42); dev flag → **100** (every
  deal shows it, so the swap flow is testable in one session).
- **v16.56 (2026-09-02) — THE FULL-BAR PROMOTION.** The roll is now
  `tier_card_roll()`: a player whose luck bar is at or above
  `TOD_UPG_GUAR_TIER_BAR` (100, the full visible bar — same number as the
  ULTIMATE floor) AND who passes the FULL `tier_card_eligible()` (PaP'd, next
  gun linked, **floor gate cleared** — the user's explicit condition) is dealt
  the TIER card 100% of the time. Below the bar, or floor-blocked, the 20%
  draw stands (a floor-blocked draw is still shown LOCKED, v14.39). Both deal
  paths (roll_options and the maxed-player pre-roll) ask the same function.
- **Right slot on purpose.** The LEFT card is focused by default and a
  timeout locks the focused card; a timeout must never swap a gun the player
  did not choose.
- **A timed-out tier card is never taken** — `wait_for_choice` already sets
  `tod_upg_timed_out`; `apply_upgrade` skips a `"tier"` option when it is set.
  So even a lone tier card (player otherwise maxed) is opt-in.
- `player_has_upgrades_left()` returns true when `tier_card_eligible()` —
  a fully-maxed player still participates in events (and can still buy at
  a station) for the tier chance alone; in that case the tier card is the
  only card (slot A) and the timeout rule above still protects it.
- LUCK does NOT move the 10% (user said 10%; keeps the bar's meaning = rarity).
  Optional knob, OFF: `TOD_TIER_PITY_PCT` +N per event missed while eligible.
- Personal station: same `roll_options`, same 10% — a station buy can deal a
  tier card. The station's "both cards dead → refund" path treats a tier
  option as alive while eligible.

### 4.3 Apply — `tier_up( player )` (the swap, in this order)

1. `player notify( "tod_tier_up" )`; clear the transient gun-bound state
   listed in §3.
2. Reset every `scope == "gun"` domain to 0; push `tod_upg_sync (id, 0, max)`
   for each; `apply_move_speed()`; tireless/staminup strip.
3. `player.tod_tier++`; `player.tod_pap_owned = undefined` (**mandatory** —
   the latch would otherwise pull the new gun straight to its `_up` form on
   the next reconcile tick, skipping the "PaP it again" step the whole
   design rests on); `player.tod_transform = undefined`.
4. Weapon swap = map 1's proven order, factored out of `reconcile_twin` into
   `swap_primary( old, want, fresh_ammo )`: GIVE `want` → if `old` was held,
   `SwitchToWeaponImmediate` verify-loop (≤1s, frame-paced) → ammo:
   `GiveStartAmmo( want )` (a tier-up is a gift: full mags) → `TakeWeapon(
   old )` LAST → `ensure_equipped`. Alt weapon: take the old gun's
   `alt_weapon`, give the new one's, if they differ.
5. `refresh_upgrade_list()`; the pause menu's CLASS TIER row (domain 24,
   level = tier, max 3) updates through the same lane.
6. Feedback: `PlayLocalSound( "tod_tier_sting" )` (new alias; `tod_ultimate_sting`
   until it exists) + the standard card confirm-flash. NO floaty text.
   ~~Optional: a baked "TIER 2 UNLOCKED" banner on the boss-banner lane
   (`tod_boss_banner` id 3/4 — zero clientfield cost).~~
   **DEAD 2026-08-22:** the entire spawn-banner lane (`tod_boss_banner`, its
   eventstring, the LUI block and the banner images) was deleted at the user's
   request — "remove all the announcement banners for the enemies spawning in.
   Its unnecessary." Do not build against it. Feedback here stays sound + the
   confirm-flash, which is what shipped anyway.

The 1s `reconcile_twin` then owns the gun as before: the new gun's level-0
suffix (`_b` / `_f0h0` …), its `_up` form once PaP'd again, and the tier-3
card becomes eligible the moment the T2 gun is PaP'd.

### 4.4 Co-op, drop-in, death

- Tier and levels live on the player entity like `tod_levels` — they survive
  respawns; `give_class_loadout` gives `gun(player)` (the CURRENT tier gun),
  not the T1 gun.
- A hot-joiner is tier 1, random class, as today.
- A player downed mid-deal: the existing solo/event grace paths apply; a
  tier option under the "default card on down" rule is the LEFT card, never
  the tier card.

## 5. Unique-gun upgrades and transforms

### 5.1 Unique domains

A unique upgrade is an ordinary domain with `gun_keys` set — it lives in the
same `register_domains` table (ids APPEND-ONLY, 24+), gets card art + a
pause plate like any other, and is reset by tier-up like any gun domain.
Two kinds:

- **script-side** (preferred, 0 assets): procs, auras, economy, on-kill
  effects — the same levers the 23 existing domains use (actor-damage
  callback, death callback, `weapon_fired`, body loop);
- **one twin axis** (3 levels, 8 assets): the gun's signature gun-data
  ladder — fire rate, recoil, mag, penetration, swing speed, or RANGE
  (`damageRangeScale`, the costed-but-unbuilt heavy option from
  docs/upgrade_system.md).

Budget rule: **each T2/T3 gun carries ≤ 1 twin axis and ≤ 2 unique domains.**
Every unique domain costs 3 cards + 1 plate of art (§10).

### 5.2 Transform upgrades — NOT NEEDED (kept as a mechanism on paper)

**Superseded 2026-08-22:** the user moved the Stormbreaker to the slasher's
TIER 3 gun (Combat Knife → katana → Stormbreaker), so there is no Combat
Axe and no transform card. Thor's Thunder rides `gun_keys = [ leviathan ]`
and the Stormbreaker's `register_gun` `grant = "thunder"` sets it to Lv1 on
arrival. The mechanism below is left for a future "reforge" upgrade only.

A transform is a `max 1` unique domain with `d.transform_to = <gun stem>`.
Applying it swaps the player's weapon to the transform sibling **at the same
tier with every level preserved** (it is an upgrade OF the gun, not a
tier-up): `player.tod_transform = stem` and `swap_primary( old, want,
fresh_ammo=false )` (ammo copied — melee has none anyway). `gun_stem(player)`
returns the transform stem while set; tier-up clears it.

`gun_keys` on the axe's other unique domains list BOTH stems (axe +
Stormbreaker) so nothing the player already levelled goes dark after the
transform. THOR'S THUNDER (20) gets `gun_keys = [ stormbreaker ]` and the
transform apply grants it Lv1 immediately (`tod_levels["thunder"] = max(1,
cur)`), so the card visibly does something the swing after you take it; the
remaining 4 levels are then rolled like any domain (only while holding the
Stormbreaker). Thor's `thor_*` block is untouched by this — it already reads
`get_level("thunder")` per hit.

**Naming.** In Norse myth Thor's weapon is Mjölnir (a hammer, not an axe).
The Leviathan Axe is Kratos's (God of War). Thor's AXE is **Stormbreaker**
(MCU, forged on Nidavellir) — the name most players will recognize; the
deep-cut alternative is **Jarnbjorn** ("iron bear", Thor's axe in the Marvel
comics before Mjölnir). Recommendation: card title **STORMBREAKER**, subtitle
"the Leviathan reforged"; keep "Leviathan" in the internal key
(`leviathan`) so the art filenames never depend on the display name (the
SCAVENGER rename lesson).

## 6. Balance — "about as strong as the PaP'd version of your gun"

PaP is a uniform **+25%** (damage, clip; fire-time ÷1.25; times/kick ×0.75).
So the tier ladder is defined relative to the class's T1 **tuned base**:

| Tier | Base DPS | PaP DPS | vs T1 base DPS |
|---|---|---|---|
| 1 | ×1.00 | ×1.5625 | — (PaP = +25% damage × +25% rate) |
| 2 | **×1.5625** (= T1 PaP) | ×2.44 | +56% / +144% |
| 3 | **×2.4414** (= T2 PaP) | ×3.81 | +144% / +281% |

`TIER_DPS = [1, 1.5625, 2.4414]` (`PAP_DPS = 1.25 × 1.25`) — one knob in
`gen_tod_twins.js`. **v9.14 (user 2026-08-22): the step is DAMAGE ONLY** —
"the next tier gun should have the same DPS as the PaP version of the tier
under … only touch the damage numbers of each gun, no other stats". The
first cut (v9.13) used `[1, 1.25, 1.5625]`, which ignored PaP's rate half
and made every promotion a DPS downgrade until the new gun was PaP'd again.
As built: T2 base vs T1 PaP DPS = 4057/4051, 3130/3125, 5518/5517; T3 base
vs T2 PaP = 6328/6339, 4888/4888, 8620/8627 (rounding only).

**How it is applied (bullet guns):** the generator computes the class's T1
tuned DPS (`damage × 60 / fireTime`) and sets each tier gun's `damage` so
its DPS at ITS OWN fire time equals `T1_DPS × TIER_DPS[tier]`. The port's
fire rate, clip, reload and handling are kept (that is the gun's identity —
an LMG still feels like an LMG); damage is the normalizer. Then the roster
parity pass (LOC_NORM, move 1.0, recoil ×1.15, ADS ×1.20) and the PaP rule
(+25%) run exactly as for the T1 guns. `damage`/`damageMin` stay INT (the
float-damage = 0 trap). Hit-location multipliers are never a tier lever.

With the script-side DAMAGE domain (+10%/Lv, ×2.0 at Lv10) on top, a T3 PaP
with DAMAGE maxed lands at ~×4.3 of today's T1 base — which is the point:
the ceiling of the run moves up by ~2×, but only for players who re-earn it.

**Magazines never shrink on a promotion** (user 2026-08-22 #7 — "fix
this"): the generator enforces `clip(tier N) >= round( clip(tier N−1 tuned
base) × 1.10 )` and the Krig's 25-round nerf is retired now that it is a
T2 gun (stock 30). So MAC-10 32 → MP5 35 → MP7 40; Enfield 30 → Krig 33 →
AK-47 36; Stoner 60 → HK21 125 → Death Machine (belt). Reserve (in
magazines) is copied from the port.

**Melee** has no DPS; the slasher's doctrine is "one-shot deep into the
round curve" (the knife is exempt from the uniform PaP rule: 1700 base /
20000 PaP). The melee ladder doubles per step so each tier buys ~7 more
one-shot rounds (BO3 zombie HP ×1.1/round from 10): T1 bat 1600/3200 →
T2 wakizashi **3200/6400** → T3 Stormbreaker **5440/10880**.
`MELEE_TIER_DMG` table, same file. Swing speed / lunge are the melee "feel"
levers per tier (CHAIN LUNGE's `TOD_LUNGE_DMG` must read the held blade's
`meleeDamage` instead of the knife's 20000 constant — Phase 2 slasher item).

Move speed is untouched by tiers (class-keyed by design — it survived the
last roster swap for exactly this reason).

## 7. Assets per new gun (the runbook, from map 1 docs/21 + this map)

Per gun, in order — ONE gun per build:

1. **Source**: the port's GDT in the tools root `source_data/` (or vendored
   into repo `source_data/t9_weapons/…` like the combat knife). Screen for a
   live `altWeapon` (boot trap). Note its PaP suffix and whether its asset
   names carry `_zm` (engine strips it at runtime — the knife does).
2. **Generator** (`gen_tod_twins.js` GUNS table): `{ stem, tier, class,
   axes, base tune = parity pass + TIER_DPS normalizer }` → emits variant
   blocks into `tod_weapon_twins.gdt`, `weapon,` lines into
   `tod_twins.zpkg`, `variant,variant_up` rows into
   `zm_levelcommon_weapons.csv` (marker-free, by-name idempotent regex —
   extend `variantRe`). The generator prints the ledger and **throws above
   200**.
3. **Zone**: the base + `_up` source assets get explicit `weapon,` lines in
   `zm_tower_of_doom.zone` (the twins come through the include).
4. **Sounds**: add the gun to `gen_tod_sounds.js` GUNS/GDT_OF (it reads the
   GDT for the alias names it actually references; declare missing fire
   families in `skipFire`); non-Skye ports get their own alias CSV +
   `.szc` source entry (the knife pattern: `tod_combat_knife.csv`).
5. **Registry**: one `register_gun(...)` line. No other GSC.
6. **Strings**: the port's `displayName` (e.g. "Closing Argument" on the
   knife) is what the stock HUD shows — nothing in our UI prints weapon
   names; art carries them.
7. **Build → boot → in-game**: `lint_tod_arity`, then `build_map.ps1
   -GscOnly` IS enough for GDT/zone/CSV changes (gdtdb `/update` runs in
   both modes; only cod2map/LED are skipped — a full build is for
   geometry). Check ERRORLOG for `is missing`, then a dev session
   (`level.tod_dev` → tier card 100%): draft the class, grab a free-PaP,
   take the card, verify swap/ammo/reset/pause list, PaP again, take T3.
   gdtdb gotcha: an edited GDT is skipped unless its mtime changed.
   VERIFIED (review 2026-08-22): `GetWeapon( "<unknown name>" )` returns
   `level.weaponNone`, it does not error — stock `mp/_challenges.gsc:92-99`
   branches on exactly that — so `base_weapon()` / `tier_card_eligible()`
   can gate on "is this variant linked" safely (check BOTH `isdefined` and
   `!= level.weaponNone`).

Registration budget of the full roster (§9) is tallied there; the design
target is ≤ 75 new registrations (97 → ≤ 172).

## 8. UI + clientfields

**The 6-bit widening (Phase 0, its own build).** In BOTH
`_tod_upgrade_ui.gsc` and `.csc`, same order, same names:

| field | today | after | Δ |
|---|---|---|---|
| `todUpgAD` | 5 | **6** | +1 |
| `todUpgBD` | 5 | **6** | +1 |
| `todMagBonus` | 7 (dead since 2026-08-20; Lua reads it, value always 0) | **1** | −6 |
| total custom | 61 | **57** | −4 |

Order is preserved (the "append only" rule is about order; both VMs register
identically so the layout stays in lockstep). This is the one engine-facing
risk in the plan and it ships alone: build, boot, watch `console_mp.log` for
"clientuimodel is out of space", open a card deal. Domain ids 24..63 open up.

**The tier card on the existing fields.** Domain **24 = CLASS TIER**. The
card needs to know class + target tier to pick its art; `todUpgAL/BL` (4
bits, "current level") is free on a tier card, so it carries
`(class_id − 1) × 2 + (target_tier − 2)` → 0..7. `tod_upgrade.lua`:
`DOMAIN[24]`, and `PaintCard` special-cases 24 to
`art.tier[ class ][ tier ]` (8 images, §10) instead of `art.cards[dom][rar]`.
Rarity field for a tier card = 3 (ULTIMATE sting plays on reveal).

**Pause menu.** `PAUSE_PLATE_MAX` 23 → 24 once `i_tod_pause_r24` ("CLASS
TIER") lands; the row's pips = tier (1..3), driven by the normal sync lane.
Unique domains 25+ follow the established one-plate-per-id rule.

**Class draft.** Unchanged mechanically. The four `i_tod_card_class_*` cards
can be re-baked (same filenames = PNG overwrite, zero wiring) to show each
class's 3-gun ladder — §10 has the prompt.

## 9. The roster — 3 tiers per class, unique upgrades (USER-LOCKED 2026-08-22)

> Mac10 → MP5 → MP7 · Enfield → Krig → AK · Stoner → HK → Death Machine ·
> Combat Knife → some katana or sword → Stormbreaker  — the user, verbatim.

The T1 guns CHANGE: the MAC-10 and the Enfield open every run, and the
MP5/Krig (with their existing f×h and r×m twin matrices, already paid for)
become the tier-2 guns. Because §6 normalizes damage to the tier, a pick is
about FEEL (fire rate, mag, reload, recoil, sound, model) — not the port's
raw numbers.

Reuse rule: a tier gun reuses an EXISTING twin domain (its card art, its id)
whenever the same ladder fits — only truly new mechanics get a new domain.
Every new unique is script-side (0 assets).

| Class | T1 | T2 | T3 |
|---|---|---|---|
| SKIRMISHER | **MSMC** `t6_msmc` (BO2) | MP5 `t9_mp5` | **MP7** `t6_mp7` (BO2 — "MP117 Redactor") |
| ASSAULT | **Enfield** `t5_enfield` (BO1) | Krig 6 `t9_krig6` | **AK-47** `t9_ak47` (CW) |
| HEAVY | **Mk 48** `t6_mk48` (BO2) | **HK21** `t5_hk21` (BO1 — 125-rd belt) | **Death Machine** `t6_death_machine` (BO2 — "Meat Grinder") |
| SLASHER | **Baseball bat** `t9_me_baseballbat` (BOCW) | **Wakizashi** `t9_me_wakizashi` (BOCW — the katana) | **STORMBREAKER** `leviathan` (the installed Leviathan Axe port, renamed) |

### 9.1 SKIRMISHER — speed

| Tier | Gun | Domains it rolls (besides shared + class) | Unique |
|---|---|---|---|
| 1 | MAC-10 | FIRE RATE **f-axis** × HANDLING **h-axis** (the 32-asset matrix; v9.44 — FIRE RATE is the MAC-10's ALONE, HANDLING is every SMG), SPRINT FIRE, RUN AND GUN, SPRINT, SCAVENGER | — |
| 2 | MP5 | HANDLING **h-axis** (8 assets; v9.44 retired its f-ladder), SPRINT FIRE, RUN AND GUN, SPRINT, SCAVENGER | **ADRENALINE** (id 25, A, max 3): a class-gun kill grants +4/+6/+8% move speed for 4s, stacking ×3 — script: a `tod_adren` bonus read by `apply_move_speed`, decayed by the body loop |
| 3 | MP7 | HANDLING **h-axis** (8 assets; v9.44 — MAG SIZE left the skirmisher class, assault-only now), SPRINT FIRE, RUN AND GUN, SPRINT, SCAVENGER | **SECOND WIND** (id 33, S, max 5): sprint to heal 1%/Lv of max HP per second (OVERDRIVE moved to the Death Machine 2026-08-23); MOMENTUM (id 34, A, max 5) is skirmisher class-wide |

### 9.2 ASSAULT — precision

| Tier | Gun | Domains | Unique |
|---|---|---|---|
| 1 | Enfield | HEADSHOT, RECOIL **r-axis** (8 assets; `gun_keys` += `t5_enfield`), SCAVENGER (cap 6) | — |
| 2 | Krig 6 | HEADSHOT, RECOIL × MAG SIZE (24 assets since v9.45: r 3 forms × m 4 forms × 2; clip nerf retired → 33 base), SCAVENGER (cap 6) | **KILL RELOAD** (id 27, **B** since v9.45, max 3; all three assault guns since v9.38): every 100th/75th/50th kill tops the magazine back to FULL out of the reserve — script: death callback → `SetWeaponAmmoClip` + `SetWeaponAmmoStock` (v9.43 rework; the 25/50/75%-per-kill form deleted reloading, see the block comment in `unique_on_kill`) |
| 3 | AK-47 | HEADSHOT, RECOIL × MAG SIZE (the AK traded its p-axis for r+m, 2026-08-23), SCAVENGER (cap 6) | **IMPACT ROUNDS** (id 28, S, **max 10** since v9.45): 3% per level (30% at cap) of hits burst for 40% of the hit's damage in 64u — script: direct `DoDamage` on up to 6 marked victims from the damage callback, victim excluded, bosses exempt |

### 9.3 HEAVY — sustained fire

| Tier | Gun | Domains | Unique |
|---|---|---|---|
| 1 | Stoner 63 | MOBILITY, BULLET FEED, ECHO ROUNDS, REGEN, PENETRATION p, SCAVENGER | — |
| 2 | HK21 | MOBILITY, BULLET FEED, ECHO ROUNDS, REGEN, PENETRATION **p reused** (6 assets; `gun_keys` += `t5_hk21`), SCAVENGER | **SUPPRESSING FIRE** (id 29, A, max 3): hits slow the zombie 25/40/55% for 1.5s — script: the vendored `cheese_man/zombie_slow_util.gsc` (API confirmed at implementation; bosses exempt) |
| 3 | Death Machine | MOBILITY, ECHO ROUNDS, REGEN, SCAVENGER — no twin axis (spin-up is the gun); BULLET FEED stays rollable but is near-moot on a belt (user: keep both Death Machines) | **MEAT GRINDER** (id 30, S, max 3): sustained fire ramps damage +2/+3/+4% per 5 rounds, cap +50/+75/+100%, decays one step per 0.5s off the trigger — script, same counter idiom as OVERDRIVE |

### 9.4 SLASHER — up close

| Tier | Gun | Domains | Unique |
|---|---|---|---|
| 1 | Combat Knife | LEECH, CLEAVE, KNIFE SPEED k, CHAIN LUNGE, SPRINT — **THOR'S THUNDER REMOVED from this pool** (user; live since v9.12) | — |
| 2 | Katana | LEECH, CLEAVE, KNIFE SPEED **k reused** (12 assets; `gun_keys` += the katana stem), CHAIN LUNGE, SPRINT | **DRAW CUT** (id 31, S, max 3): a swing within 0.4s of sprinting deals +50/+100/+150% — script: `IsSprinting` timestamp → multiplier on MOD_MELEE in `upgrade_damage_cb` |
| 3 | STORMBREAKER | LEECH, CLEAVE, KNIFE SPEED **k** (12 assets; `gun_keys` += `leviathan`), CHAIN LUNGE, SPRINT, **THOR'S THUNDER** (20, its exclusive; `grant` = Lv1 on arrival, then rolls to Lv5) | (Thor's Thunder IS its unique — no new id) |

Melee damage per tier follows `MELEE_TIER_DMG` (§6): katana 3200/6400,
Stormbreaker 5440/10880 (the port ships 5000/20000 — overridden).

### 9.5 Ports: what exists, what must be sourced

| Pick | On the box? | Notes |
|---|---|---|
| MAC-10 | yes — `skye_t9_mac-10.gdt` (the user's re-download was byte-identical) | t9 pipeline, `gen_tod_sounds.js` |
| MP7 | yes — `skye_t6_mp7.gdt` (byte-identical re-download) | BO2 pack: fire set differs from t9 (`wpn_t6_mp7_shot` single wav, no trig_pull) — `gen_tod_sounds.js` needs a t6 recipe (or copy map 1's rows if it boxed the MP7) |
| Enfield | **installed 2026-08-22** from `Skye_BO1_Enfield.zip` — `skye_t5_enfield.gdt`: `t5_enfield` (30-rd, 160 dmg, 750 rpm, locHead 5.0 → LOC_NORM) / `t5_enfield_up_zm` ("E2N-F13LD", 40-rd) | the `_up_zm` form's `altWeapon "t5_enfield_shotty_zm"` (a Masterkey) is BLANKED in the generator: boot trap + parity. Mixed naming: base has no `_zm`, PaP does — the knife precedent in the generator's form table |
| HK21 | **installed 2026-08-22** from `Skye_BO1_HK21.zip` — `skye_t5_hk21.gdt`: `t5_hk21` (125-rd, 310 dmg, 536 rpm, moveSpeedScale 0.9 → 1.0, locTorsoUpper 2.0 → 1) / `t5_hk21_up` | `altWeapon` empty ✓; the README row is `t5_hk21,t5_hk21_up,,2750,lmg,…` |
| AK-47 | yes — `skye_t9_ak-47.gdt` (also holds `t9_rpk`) | t9 pipeline |
| Death Machine | yes — `skye_t6_death_machine.gdt` | screen spin-up fields + `altWeapon`; BO2 sound set. **v16.6 (2026-09-01): `spinMinigunOnADS` 0 -> 1 via `tune.str`** — holding AIM pre-spins the barrels (spinUpTime 0.25, spinDownTime 0.5) so the trigger fires instantly; engine field, feel unverified until played |
| Stormbreaker | yes — `<tools>\_custom\wetegg\leviathanaxe\leviathanaxe.gdt` (`leviathan_zm` / `leviathan_up_zm`, `_zm` runtime-strip like the knife; meleeDamage 5000/20000) | **It links only because `bin\converter_gdt_dirs_0.txt` line 1 is `_custom`** — a Mod Tools verify resets that file and the axe silently drops from every build (map 1's `apply_bin_patches.ps1` lesson); do NOT also vendor it (a second definition = gdtdb duplicate). **The live GDT is map-1-patched** (`continuousFire 1` paired with map 1's `_acc_leviathan_swing.gsc` — without that script holding attack makes the engine reject the re-fire; `moveSpeedScale 1.07`, `meleeChargeRange 0`); the pristine pack copy `leviathanaxe.gdt.acc-balance0709-orig` (fireTime 0.6, meleeTime 0.65, continuousFire 0, move 1.0, chargeRange 100) is the generator's source. SOUND: no alias CSV anywhere — the GDT references stock MP fire-axe aliases (`wpn_melee_fireaxe_*`) that may not be in the ZM banks; verify in-game, else author rows. Stock `is_melee_weapon()` is false for it (same as the combat knife — harmless). Credit WetEgg / M5_Prodigy / J.G. / DeLeon / Santa Monica Studio before publish |
| AK-47 (note) | — | **map 1 patched `skye_t9_ak-47.gdt` in place** (recoil ×1.75, maxAmmo 10/11, moveSpeedScale 0.93, hipSpread ×1.25); the generator reads the pristine `.acc-orig` backup so the roster recoil bump (×1.15) is not stacked on a hidden ×1.75. Map 1 ran it at balance ×0.27 — our TIER_DPS normalization replaces that |
| Death Machine (note) | — | loop-fire minigun: the GDT's audio is `startFireSound`/`loopFireSound`/`loopFireEndSound` (wavs `fire_start_plr`, `fire_loop_plr/npc`, `fire_stop_plr/npc`, no `_npc` start wav) — `gen_tod_sounds.js`'s t9 shot recipe does not apply; its alias rows are hand-authored in Phase 2f. `moveSpeedScale 0.65` → parity 1.0; `blocksProne 1` |
| MP7 / HK21 / Enfield sounds | — | the BO1/BO2 packs ship their alias rows in the zip README (`#BO2 H&K MP7`, `#BO1 H&K HK21A1`, `#BO1 RSAF L85A1 Enfield` blocks) — copied verbatim into `sound/aliases/tod_ports.csv` (+ a `.szc` source entry), not generated |
| **Katana** | **NO** — nothing sword-shaped on the box except the ZoD glaives (hero-slot) | Skye's CW melee ports include the **Wakizashi** (a katana) — same t9 pipeline as the combat knife, `bulletweapon.gdf` melee with `meleeTime`/`meleeChargeTime` (required for the k-ladder). Source: Skye's BO:CW ports thread on UGX (link in the chat log); the `_custom`/`t9_weapons\melee` layout of the knife pack is the install shape |

### 9.6 Registration ledger for this roster

| Gun | Forms | Count |
|---|---|---|
| MAC-10 (T1) | f0..f3 × (base, up) | 8 |
| MP7 (T3) | m0..m3 × 2 | 8 |
| Enfield (T1) | r0..r3 × 2 | 8 |
| AK-47 (T3) | p0..p2 × 2 | 6 |
| HK21 (T2) | p0..p2 × 2 | 6 |
| Death Machine (T3) | `_b` × 2 | 2 |
| Katana (T2) | k0..k5 × 2 | 12 |
| Stormbreaker (T3) | k0..k5 × 2 | 12 |
| **Total new** | | **62** |

Ledger 97 → **159** — under the 200 guard, ~70 under the proven 230. The
MP5/Krig/Stoner/knife matrices are unchanged (they just move tier). The raw
base/`_up` source assets of NEW guns are NOT zoned (the level-0 variant is
what `give_class_loadout` hands out); the four old T1 raw forms stay zoned
for now. Domain ids (live in `domain_id` since v9.12): **24 CLASS TIER, 25
ADRENALINE, 26 OVERDRIVE, 27 KILL RELOAD, 28 IMPACT ROUNDS, 29 SUPPRESSING
FIRE, 30 MEAT GRINDER, 31 DRAW CUT**.

## 10. Image prompts

All art follows the shipped card set: **768×1152 portrait, all text baked
in, readable at ~213×320 on screen**, the same frame/plate/medal/ribbon/pip
language per rarity as the CLEAVE or RUN AND GUN cards (attach one
regular/super/ultimate trio as the style reference in every prompt). Plates
are **300×44**. Files land as PNG in `source_data/tod_ui_images/_images/`;
every NEW filename = one `image.gdf` block + one zone `image,` line (+
`CARD_SLUG`/`PAUSE_PLATE_MAX` in Lua); an EXISTING filename is a pure
overwrite.

### 10.1 Exploration prompt (step 1 — ONE asset, five directions)

> Using the attached three cards as the fixed style reference (same canvas
> 768×1152, same cartoon rendering, same frame/plate/medal/ribbon/pip
> construction), design ONE new card type: a **CLASS TIER card**. It is not a
> rarity — it sits apart from REGULAR (silver), SUPER (blue) and ULTIMATE
> (amber) as a fourth, rarer frame: **PLATINUM / white-gold**, with a thin
> glow in the class's accent colour (this sample: ASSAULT = amber-gold
> `#FFBF40`). Subject: the **AK-47** rendered in the set's style, three-quarter
> view, muzzle up-right, on a dark navy tech ground with a faint upward arrow
> motif (a promotion). Baked text, top to bottom: eyebrow "TIER 2", title
> "AK-47", sub "ASSAULT · NEW WEAPON", footer in two short lines "GUN UPGRADES
> RESET" / "DMG REDUCTION + LUCK KEPT". Give me **5 distinct directions** of
> this one card on a contact sheet (frame construction, how the platinum reads
> against the navy, how the promotion arrow is integrated, type treatment),
> each readable at 213×320. No rarity medal — replace it with a roman "II"
> badge where the medal normally sits.

### 10.2 Build-out prompt (step 2 — every file, exact names)

> Lock direction **N** from the contact sheet and produce the full set at
> 768×1152 PNG, transparent outside the frame, text baked, readable at
> 213×320. Same construction for all eight; only class accent, badge numeral,
> gun and text change.
>
> **Tier cards** (`i_tod_card_tier_<class>_<n>.png`):
> - `i_tod_card_tier_skirmisher_2` — MP5 — accent cyan `#33D9FF` — "TIER 2 / MP5 / SKIRMISHER · NEW WEAPON"
> - `i_tod_card_tier_skirmisher_3` — MP7 (BO2, compact, 40-round translucent mag) — cyan — "TIER 3 / MP7 / SKIRMISHER · NEW WEAPON"
> - `i_tod_card_tier_assault_2` — Krig 6 — amber `#FFBF40` — "TIER 2 / KRIG 6 / ASSAULT · NEW WEAPON"
> - `i_tod_card_tier_assault_3` — AK-47 — amber — "TIER 3 / AK-47 / ASSAULT · NEW WEAPON"
> - `i_tod_card_tier_heavy_2` — HK21 with its box belt — red `#FF594D` — "TIER 2 / HK21 / HEAVY · NEW WEAPON"
> - `i_tod_card_tier_heavy_3` — Death Machine minigun, barrels spinning — red — "TIER 3 / DEATH MACHINE / HEAVY · NEW WEAPON"
> - `i_tod_card_tier_slasher_2` — a katana, blade up — violet `#BF73FF` — "TIER 2 / KATANA / SLASHER · NEW WEAPON"
> - `i_tod_card_tier_slasher_3` — STORMBREAKER: a Norse two-bladed great-axe wreathed in white-blue lightning — violet — "TIER 3 / STORMBREAKER / SLASHER · NEW WEAPON", sub-line "CALLS THOR'S THUNDER"
> Every tier card's footer: "GUN UPGRADES RESET" / "DMG REDUCTION + LUCK KEPT". Badge: "II" on tier-2 cards, "III" on tier-3.
>
> **Unique-upgrade cards** — three rarities each, EXACTLY like the existing
> domain cards (`i_tod_card_<slug>_regular|super|ultimate.png`), rarity
> medal "+1 / +2 / +3" as in the set:
> - `adrenaline` — title "ADRENALINE", desc "KILLS GRANT A BURST OF SPEED", icon: a syringe-shaped speed chevron over a running silhouette, cyan (the MP5's)
> - `overdrive` — "OVERDRIVE", "SUSTAINED FIRE HITS HARDER", icon: an SMG magazine with rising heat lines and a red-lining gauge, cyan (the MP7's)
> - `kill_reload` — "KILL RELOAD", "KILLS REFILL YOUR MAGAZINE", icon: a magazine with a returning arrow and a skull, amber (the Krig's)
> - `impact_rounds` — "IMPACT ROUNDS", "HITS CAN BURST NEARBY ZOMBIES", icon: a bullet with a small shock ring, amber (the AK-47's)
> - `suppressing_fire` — "SUPPRESSING FIRE", "HITS SLOW THE HORDE", icon: a belt of rounds over a stumbling zombie, red (the HK21's)
> - `meat_grinder` — "MEAT GRINDER", "KEEP FIRING, HIT HARDER", icon: spinning minigun barrels with a rising gauge, red (the Death Machine's)
> - `draw_cut` — "DRAW CUT", "STRIKE OUT OF A SPRINT FOR MORE", icon: a katana mid-draw with a motion arc and speed lines, violet (the katana's)
>
> **Pause-menu plates** (`i_tod_pause_rNN.png`, 300×44, the existing plate
> style): r24 "CLASS TIER", r25 "ADRENALINE", r26 "OVERDRIVE", r27 "KILL
> RELOAD", r28 "IMPACT ROUNDS", r29 "SUPPRESSING FIRE", r30 "MEAT GRINDER",
> r31 "DRAW CUT".
>
> **REQUIRED — class draft re-bake** (same filenames = pure overwrite; the
> starting guns changed): `i_tod_card_class_skirmisher|assault|heavy|slasher`
> in today's style but showing the NEW tier-1 gun (MAC-10 / Enfield /
> Stoner 63 / Combat Knife) plus a small three-step ladder strip at the
> bottom: "MAC-10 › MP5 › MP7", "ENFIELD › KRIG 6 › AK-47", "STONER 63 › HK21
> › DEATH MACHINE", "KNIFE › KATANA › STORMBREAKER".
>
> **Optional — banners** (900×140, the PANZER banner style):
> `i_tod_banner_tier2` "TIER 2 UNLOCKED", `i_tod_banner_tier3` "TIER 3
> UNLOCKED".
>
> Deliver a contact sheet first so the baked text can be proofread before the
> full-size export.

Art arrives in the order it is needed: tier cards + r24 first (Phase 1 can
test on the ULTIMATE frame as a placeholder), uniques with Phase 3, the
optional pieces last.

## 11. Implementation phases (each = one build, one boot test)

| Phase | Change | Files | Test |
|---|---|---|---|
| 0 ✅ | Clientfield widening 5→6 / 7→1; `DOMAIN[24..31]` rows; pause loop 1..31 | `_tod_upgrade_ui.gsc/.csc`, `tod_upgrade.lua`, `AetheriumStartMenu.lua` | built 11:46 AM (73.89 MB); boots; console_mp.log clean; a normal deal renders |
| 1 (coded) | Registry refactor (`register_gun`, `gun(player)`, generic `twin_suffix`), `scope`/`gun_keys` on every domain (Thor → `leviathan`), `tier_card_eligible/roll/tier_up`, `swap_primary` + latch, dev 100% — with **T2 = T3 = the T1 gun** (a "null ladder": proves reset + swap + latch-clear + pause list with ZERO new assets) | `_tod_classes.gsc`, `_tod_upgrades.gsc` | take the card: gun re-given at base form, levels reset, DR/LUCK kept, PaP again → T3 card |
| 2a MAC-10 (T1) | the FIRST real gun — it opens every skirmisher run; `register_gun` T1 stem → `t9_mac10`, f-axis; `gun_keys` firerate += `t9_mac10`; draft label | generator, zone, CSV, sounds, `tod_class_select.lua` | boot + draft gives the MAC-10 + tier-up lands on the MP5 |
| 2b Enfield (T1) | same for assault (`t5_enfield`, r-axis, altWeapon blanked, LOC_NORM) | same | boot + draft gives the Enfield + tier-up lands on the Krig |
| 2c HK21 (T2) | `t5_hk21`, p-axis | same | tier-up from the Stoner |
| 2d MP7 (T3), 2e AK-47 (T3), 2f Death Machine (T3) | one per build | same | tier-up chain to T3 |
| 2g Stormbreaker (T3) | vendor the Leviathan GDT, k-axis, `grant = "thunder"`, melee 40000/80000; CHAIN LUNGE damage from the held blade | same + `_tod_lunge.gsc` | tier-up → Thor's Thunder Lv1 on arrival |
| 2h Katana (T2) | **after the user sources the port** | same | — |
| 3 | Unique domains 25..31 (script-side) | `_tod_upgrades.gsc` (+ small modules per mechanic) | each unique rolls only on its gun |
| 4 | Art drops (8 tier cards, 7 unique sets, r24..r31, the REQUIRED draft re-bake), `tod_tier_sting` alias, `docs/upgrade_system.md` refresh | images GDT/zone/Lua | visual QA vs the existing set |

Lint before every build: `node tools/lint_tod_arity.js`. One builder at a
time across sessions (tasklist for `linker_modtools.exe` / `BlackOps3.exe`).

## 12. Decisions — RESOLVED 2026-08-22 (user) unless marked OPEN

1. Body domains (SPRINT, MOBILITY, REGEN, SPRINT FIRE): **reset** ("OK").
2. BOUNTY: **reset** (strict rule).
3. Tier card never auto-locks on timeout, always the RIGHT slot: **yes**.
4. Station deals can include the tier card: **yes**.
5. LUCK does not raise the 10%: **yes** (no pity rate).
6. Melee ladder 1700/20000 → 20000/40000 → 40000/80000: **as proposed**
   (katana / Stormbreaker).
7. Title: **STORMBREAKER** (the user's own pick for T3).
8. Roster: **locked** (§9). Enfield + HK21 ports installed; MAC-10 + MP7
   were already on the box.
9. Thor's Thunder leaves the T1 knife: **yes** — Stormbreaker-only, Lv1 on
   arrival ("5. Ok").
10. Combat Axe: **gone** — T2 is a katana, T3 the Stormbreaker.
11. Apothicon Sword: **not used**.
12. Two Death Machines (class gun + the powerup): **keep both** ("that's
    fine").
13. Tier-2 clips smaller than tier-1: **fixed** by the never-shrink rule +
    the Krig clip nerf retired (§6).
14. **OPEN — the katana port.** The user needs the exact download; nothing
    sword-shaped is installed. Candidate: Skye's BO:CW Wakizashi (t9
    pipeline, `bulletweapon.gdf` melee — the k-ladder needs `meleeTime` /
    `meleeChargeTime`). Until it lands, T2 slasher stays the knife in the
    registry (the null-ladder entry), so the slasher's T3 card is reachable
    only after the katana build.

## 13. Knobs (one place each)

| Knob | Default | Where |
|---|---|---|
| `TOD_TIER_MAX` | 3 | `_tod_upgrades.gsc` |
| `TOD_TIER_CARD_PCT` | 20 (dev_upgrades 100; a full luck bar deals it outright) | `_tod_upgrades.gsc` |
| `TOD_TIER_PITY_PCT` | 0 (off) | `_tod_upgrades.gsc` |
| `TIER_DPS` | [1, 1.5625, 2.4414] (damage only) | `gen_tod_twins.js` |
| `MELEE_TIER_DMG` | {1:[1600,3200], 2:[3200,6400], 3:[5440,10880]} (lockstep with `register_melee_dmg()`) | `gen_tod_twins.js` |
| ledger guard | throw > 200 registrations | `gen_tod_twins.js` |
| domain `scope` / `gun_keys` | per `add_domain` row | `register_domains` |
