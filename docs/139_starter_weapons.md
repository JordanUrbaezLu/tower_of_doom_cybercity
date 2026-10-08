# MSMC / Mk 48 starting weapons

Requested September 14, 2026. Skirmisher tier one replaces MAC-10 with Skye's
BO2 MSMC; Heavy tier one replaces Stoner 63 with Skye's BO2 Mk 48. Both source
GDTs and their model/animation dependencies were already installed in Mod Tools.

## Balance contract

User: "Keep the dps the same. So take the GDT but adjust the damage so dps was
same as before." The new ports retain native fire intervals and reloads,
models, animation names, sound names and stance. Existing global handling,
reserve, location multipliers and upgrade rules still apply.

| Gun | Base damage / interval | Packed damage / interval | Magazine base / packed |
|---|---|---|---|
| MSMC | 210 / 0.080 s | 264 / 0.064 s | 32 / 40 |
| Mk 48 | 275 / 0.096 s | 344 / 0.0768 s | 60 / 75 |

Damage = round(previous damage * new fire interval / previous fire interval),
separately for base and packed forms and minimum damage. The `dpsReference`
record in gen_tod_twins.js captures the previous emitted values. It also holds
the old normalization/secondary-cap reference so the swap does not retune
other weapons. The follow-up restores the old magazine and reserve counts too: MSMC uses
32/40 rounds and 11 reserve magazines; Mk 48 uses 60/75 and 6 reserve magazines.
`reserveMags` is a final emitted count after global/class reserve adjustments,
then copied to PaP, so the previous balance is exact. Later tiers are unchanged.

All 158 other bulletweapon blocks compared byte-identical to the pre-swap
snapshot (see tmp/starter_swap/before_twins.gdt; actual overlap count can be
recomputed there). All 38 replacement variants preserve previous DPS within
0.28%, including fire-rate upgrade rounding. Do not replace this damage-only
adjustment with a fireTime override: the user explicitly wants the new rates.

## Presentation and PaP

MSMC carries f0..f3 / h0..h3, base and packed (32 forms). Mk 48 carries p0..p2,
base and packed (6 forms). Registrations stay 235, weapon cost keys 238.
All 41 nonempty animation/sound/model/display-name fields match the source
port in each of the four level-zero forms (164 checks total).

22 sound aliases are appended to tod_ports.csv using the proven BO2 MP7 row
layout: all eight MSMC and fourteen Mk 48 referenced gun-specific aliases,
including normal/packed player/NPC shots and every reload/bolt/belt/foley beat.
Their 18 unique WAVs are vendored from the installed ports without modification.

Class registration, upgrade applicability and base-to-packed CSV names are
updated together. The existing class-primary PaP route accepts tier zero,
reconciles to the matching _up variant, then rejects a repeat at normal tower
machines. No extra PaP tier or alternate-weapon chain was introduced.

HUD name lookups include MSMC / Miniature Sinister Mischievous Catalyst and
Mk 48 / Magna Impetu. Class picker fallback text and armory data name the new
guns. ~~Existing custom MAC-10/Stoner pictures remain placeholders; those baked
class-card/HUD illustrations require a separate art delivery, like the bat.~~

**THAT ART LANDED 2026-09-15 00:21 AND NOTHING IS OWED (checked 2026-09-21).**
Both class cards and both HUD gun icons were re-baked in the same drop: the
cards read MSMC / MK 48 and draw the new guns, and
`i_tod_hud_gun_mac10.png` / `i_tod_hud_gun_stoner63.png` now depict the MSMC and
the Mk 48. **ONLY THE CATEGORY SLUG IS STALE** — `TOD_GUN_CAT` in
`AetheriumLoadout.lua` still maps `t6_msmc` -> `"mac10"` and `t6_mk48` ->
`"stoner63"`, and the icon FILENAMES still carry the retired guns' names. That is
a naming leftover with zero player-visible effect, and renaming it is not free:
the icon name is CONSTRUCTED at runtime (`"i_tod_hud_gun_" .. cat`), so a slug
change means renaming the PNG, its GDT block and its zone line together, and an
unzoned one draws a WHITE SQUARE. Leave it unless the set is re-cut anyway.
**Do not re-commission these four images on the strength of the struck-through
sentence above** — read the file mtimes, not the note.

## Diagnostics and verification

`test_starter_weapons.js` runs in build_map.ps1 and checks all forms, native
rates, magazines, damage and sound sources. Existing weapon lint checks PaP
mappings and script-requested variants. Dev-only `[TOD_STARTER] REGISTER`
records each tier-one class/stem/PaP suffix. Keep dev/god OFF per user request.

Evidence: tmp/starter_swap/generate.log, dps_verification.json,
presentation_verification.json, build.log. Weapon/PaP lint, armory constant
and domain checks passed. Full build and native verification status follows.

Full build passed at 23:04:09 Eastern, FF 149,323,584 bytes; ten existing
waived warnings and no new weapon errors. All 195 checked deployed inputs
match source; script/UI/zone/sound alias inputs predate the FF. Dev/god false.
Normal native verification launched through tools/run_game.ps1 and Steam.

Native run PID 31856 loaded successfully. User selected Skirmisher and took
over controller input; agent left the match running. `tmp/starter_swap/
class_picker.png` shows MSMC HUD, 30/390 ammunition and normal 150 HP;
`msmc_native.png` shows the textured MSMC aiming/firing and actual critical
kills in round 2 (23/377 ammo). No native script runtime exceptions observed.
Stock display-name/_zm lookup warnings match the previous run pattern
(previous MAC-10/Stoner warnings become MSMC/Mk 48 warnings); actual generated
MSMC variants load and function. Mk 48 and purchasing PaP have not yet been
observed in-game. Neither gun sound was independently listened to by the agent.
Native logs preserved by capture_ai_logs.ps1 (23:07 run archives).

Ammo follow-up: all 38 generated forms match the retired weapons exactly for
clipSize, maxAmmo and startAmmo. Every other weapon block remains unchanged.
Tests and PaP lint passed. Full rebuild pending closure of the active user match.

Mk 48 reload follow-up: user requested faster reloads because the port is
slower than the Stoner. `tune.reload = 6.6 / 8.0` scales its reload timings
proportionally: normal and empty reloads are 6.6 seconds base / 4.95 packed
(previously 8 / 6). Ammo-add beats scale with the same factor; Mk 48 animation
and sound references remain intact. All six Mk 48 variants pass reload timing
checks. This and the ammo restoration await a full build after the active
match closes; the currently running build still has the old port timings.

Ammo/reload full build passed September 14 at 23:26:11 Eastern, FF
149,323,584 bytes. All 176 checked deployed inputs match source; relevant
script/UI/zone/GDT/alias inputs predate the FF. Dev/god remain false. Build
log: tmp/starter_swap/ammo_reload_build.log. Native verification launching.

Final native attempt: tools/run_game.ps1 was tried twice (23:26 and 23:28).
No BlackOps3 process started during either 90-second wait. The second Steam
argument dialog was observed, but guarded input rejected a click when Chrome
had focus; the dialog subsequently disappeared. Steam gameprocess_log showed
no new BO3 process. Stopped retries without restarting Steam or touching other
apps. Therefore this latest ammo/reload build is built/static-verified but
NOT natively verified; BO3 is not running. Prior MSMC native evidence above
applies only to the previous ammo/reload settings.
