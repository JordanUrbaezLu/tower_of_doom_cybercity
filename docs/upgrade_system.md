# The Class & Upgrade System — definitive reference (v4.2 BALLISTIC SLASHER, 2026-08-19)

> **SUPERSEDED — HISTORICAL RECORD ONLY (2026-08-30).** This is the v4-era
> design (M60/Ballistic Knife roster, ECHO ROUNDS live, CLEAVE 5, +3%/Lv
> mobility — all long gone). The LIVING references are `register_domains()` in
> `_tod_upgrades.gsc` (the truth), CHANGELOG.md (the deltas — v14.11 is the
> latest rebalance), and the Tower of Doom Armory artifact (the readable map).
> Do not update this file; it is kept as the record of the original design.

Endless rounds; upgrade events at round 1 (dealt by the class draft) then
every 4th round (dev mode: every round from 2): the world freezes, each
player picks 1 of 2 cards (D-pad/stick to switch, hold JUMP to lock, 15s).

**THE LUCK BAR (v5, `_tod_luck.gsc`)**: per-player 0..100%, bottom-left
hudelem bar. Card odds scale linearly with the bar: 0% = REGULAR 80 /
SUPER 15 / ULTIMATE 5 → 100% = 20/50/30; the bar FULLY RESETS to 0 after
each event. Gains (LAST HIT takes all): zombie kills normalized to the
round's spawn budget (fair-share clear ≈ +40% at any round/lobby size —
per-kill = 40×players÷round_total via zm::get_zombie_count_for_round),
headshot kills ×1.5, Protector last hit +4, Panzer last hit +20, revive
+15, door buy +8; going down −25. The LUCK domain = +10% gain rate per
level. Boss POINTS stay team-wide (+250/unit quiet, +1000 Panzer).

## Classes (v4 roster — select stations, tower base, south core face)

Base MOVE SPEED per class (script-side in class_speed_base — never the
shared install-side GDTs): HEAVY 0.75 · ASSAULT 0.9 · SKIRMISHER 1.0 ·
SLASHER 1.1. SPRINT/MOBILITY multiply on top. (2026-08-23: HEAVY cut
0.8 -> 0.75 and ASSAULT 0.9 -> 0.85, then ASSAULT put back to 0.9 the
same day — only the LMG kept its cut.) GUN BALANCE (same day): per-gun raw-damage multipliers in
gun_balance_mult() — pistol ×4, m60 ×0.85, ak74u ×1.1, krig ×1.05.

| Class | Weapon | Signatures (active) | Signatures (twin phase, PENDING) |
|---|---|---|---|
| SKIRMISHER | AK-74u (SMG) | SPRINT, FIRE RATE 3, HANDLING 3 (twins LIVE) | — |
| ASSAULT | Krig 6 (AR) | HEADSHOT, MAG SIZE, RESERVE, RECOIL 3 (twin LIVE) | — |
| HEAVY | M60 (LMG) | MOBILITY, BULLET FEED, ECHO ROUNDS, REGEN | — |
| SLASHER | **Ballistic Knife** (primary, PaP `_upgraded`) + Bowie alt melee | SPRINT, LEECH, CLEAVE, **KNIFE SPEED 3 (twins LIVE)** | — |

PENETRATION (heavy) was investigated and honestly declined: the M60's base GDT
already ships `penetrateType "large"` — the engine's maximum — so there is no
ladder to climb. RANGE (damageRangeScale) is the costed alternative if the
heavy ever needs a 4th gun-data domain.

## Domains (ids 1..18 — lockstep across register_domains /
## _tod_upgrade_ui::domain_id / tod_upgrade.lua DOMAIN)

SHARED (1-4): DAMAGE 10 (+12%/Lv) · DMG REDUCTION 10 (−4%/Lv damage taken —
applied in the player-damage chain + the panzer-melee mitigation hook;
replaced HEALTH 2026-08-20) · BOUNTY 10 (+3%/Lv money per class-weapon kill,
banked exact; melee kills count at the 130 nominal) · LUCK 5 (+1 permanent
luck/Lv).

5 SPRINT 10 (skirmisher+slasher): +5%/Lv move speed; **Lv 5 grants tireless
sprint (skirmisher only)**. v9.15: the sprint meter is predicted on the CLIENT
from its `player_sprintTime` dvar (stock sets it per client once at connect,
`zm/gametypes/_globallogic_player.gsc:125`), so the lever is
`SetClientPlayerSprintTime(999)` PLUS the server-side `SetSprintDuration(999)`
(the server call alone — every earlier attempt — never changed the meter). The
staminup specialty is set alongside; latched, cleared on class switch /
tier-up (`tireless_apply/clear`).

32 SPRINT ARMOR 5 (skirmisher+slasher, v9.28): -5%/Lv damage taken WHILE
SPRINTING (`IsSprinting`), multiplied in right after DMG REDUCTION in both of
`_tod_bosses`' player-damage lanes (`tod_upgrades::sprint_armor_mult`); scope
"class" (damage resistance persists through a tier-up, like DR).

ASSAULT: 6 HEADSHOT 10 (+4%/Lv headshot dmg, additive with DAMAGE; was +10%/Lv
when this doc was written, then 4% -> 3% -> 4% again on 2026-08-26) ·
7 MAG SIZE 10 (+20% clip/Lv bottomless pool, MAG +N chip) · 8 SCAVENGER 5
(+6 assault; kill counter, ONE round per 7/6/5/4/3/2 kills by level, never
more than one round per shot — a same-frame multi-kill only counts; was 2/kill
-> 1 -> 0.25 banked -> this ladder, user 2026-08-22 "4 bullets on one shot").

HEAVY: 9 MOBILITY 10 (+3%/Lv move speed — the "handling" feel; true reload
speed needs twins) · 10 BULLET FEED 10 (reserve→mag trickle, 1 round per
(6−0.5×Lv)s while holding the gun; sets tod_mag_selfset so the mag watcher
doesn't misread it) · 11 ECHO ROUNDS 10 (+10%/Lv double-strike) ·
12 REGEN 10 (+0.5% max HP/s per Lv).

SLASHER: 13 LEECH 5 (kills heal +4 HP/Lv) · 14 CLEAVE 5 (each melee swing
carries full damage into +1 zombie/Lv within 120u; recursion guarded by the
tod_cleave_hit mark consumed at the top of the damage callback) ·
18 KNIFE SPEED 3 (twin: meleeTime+meleeChargeTime ×0.88/0.78/0.68 — map 1's
Berzerker recipe on the ballistic knife).

TWIN DOMAINS (3-level gun-data rule): 15 FIRE RATE 3 (skirmisher) ·
16 HANDLING 3 (skirmisher — reload+swap+**ADS** keys, ×0.85/0.75/0.65) ·
17 RECOIL 3 (assault) · 18 KNIFE SPEED 3 (slasher).

## Twin / registration ledger

Registrations: **50** = 8 gun forms + **42 twin variants LIVE** (2026-08-19):
ak74u fire(f1-3 x0.92/0.84/0.76 fireTime) x handling(h1-3 x0.85/0.75/0.65
reload+swap+ADS) = 15 combos x2 forms; krig recoil(r1-3 x0.90/0.80/0.70
kick — HALVED 2026-08-21 from x0.75/0.55/0.35; the krig's base kick is
x1.15 roster bump x1.25 krig-only = x1.4375 stock) x2; ballistic knife(k1-3 x0.88/0.78/0.68 meleeTime+meleeChargeTime) x2
forms (base + `_upgraded` — the ballistic's PaP suffix, NOT `_up`; asset
names carry `_zm`, stripped at runtime). Generated by tools/gen_tod_twins.js
(map 1's proven field sets; damage/ammo are INT-typed — decimals =
zero-damage gun; ballistic GDT is latin1 + projectileweapon.gdf). Naming
contract <base>[_up|_upgraded]_f{F}h{H} / _r{R} / _k{K}; zone via
zone_source/tod_twins.zpkg (include,tod_twins); CSV maps every variant to
its PaP twin so PaP works. Thrown twin blades stay retrievable —
_tod_ballistic.gsc registers every k-variant with
zm_weapons::add_retrievable_knife_init_name (map 1's lesson). Swap =
reconcile_twin() in _tod_upgrades (1s self-heal loop + instant on upgrade;
per-class up_suffix; preserves clip/reserve/PaP-form/held). Budget ~230
(docs/21 §A); headroom ~180. NEVER a third axis on one gun.
Known-benign errorlog: 16× `mtl_wpn_t7_knife_combat` no-techset warnings —
map 1 shipped with the identical 16 lines and the knife rendered fine.

## Wiring map

Registry/effects: `_tod_upgrades.gsc` (register_domains APPEND ONLY;
class_keys array = gating). Classes: `_tod_classes.gsc`. UI:
`_tod_upgrade_ui.gsc|.csc` (domain ids 4-bit) + `tod_upgrade.lua`.
Add a domain: add_domain + effect hook + domain_id case + Lua row.
Add a class: register_class + docs/21 gun runbook.
