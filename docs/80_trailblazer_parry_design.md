# 80 — TRAILBLAZER (skirmisher) + PARRY (slasher): design for sign-off

> **STATUS: TRAILBLAZER BUILT v16.62 (2026-09-02, ground-fire variant — see the amendment at the end); PARRY still PROPOSED, awaiting sign-off.**
> **v16.79 (2026-09-03): the v16.62 fire effect never drew — `zombie/fx_dog_fire_trail_zmb` is a 5 KB STUB in the mod tools (one default element, no material; 298 such files). Swapped to `fire/fx_fire_ground_rubble_50x50`, same hosts/caps/reaper, plus three SFX aliases (`tod_trail_ignite` / `tod_trail_loop` / `tod_trail_sizzle`). UNPLAYED as of the build.**
> Ids: 46 TRAILBLAZER (built). PARRY takes the NEXT FREE id at build time — 45 went to RIOT SHIELD and 47 to DEADSHOT (peer sessions, same day), so read the domain_id switch before assigning it — the 6-bit domain-id field allows 1..63.
> Both are class-scoped (survive tier promotions), both ship on the TEXT
> fallbacks until their card art lands (art prompt docs + packs after the build).

## TRAILBLAZER — skirmisher, id 45, band A, max 5

**"Sprinting leaves a burning trail. Zombies that chase through it burn."**

| Level | Trail lingers | Burn (of the round's zombie health, per second) |
|---|---|---|
| 1 | 2.0 s | 12% |
| 2 | 2.5 s | 16% |
| 3 | 3.0 s | 20% |
| 4 | 3.5 s | 24% |
| 5 | 4.0 s | 28% |

- **When it runs:** sprinting, on the ground, alive, not in last stand, not
  menu-frozen, not during the upgrade pause.
- **The visual:** the hellhound's own fire trail (`zombie/fx_dog_fire_trail_zmb`
  — the attached looping effect stock plays on a dog's spine) hosted on a
  tag_origin script_model linked to the player while sprinting, deleted the
  moment the sprint ends. Not packed in this map today → one `fx,` zone line
  + `#precache` + `level._effect["tod_trail_fire"]` → **FULL build.**
- **The damage:** every 0.35 s of sprint (and only after 48 u of travel since
  the last one — standing still and spinning makes no trail) a NODE is
  recorded at the player's feet: `{ org, expire }`, radius 64 u, max 12 live
  per player (oldest expire early). Every 0.5 s each live node burns every
  non-boss zombie inside its radius for half the per-second figure, credited
  to the runner (`DoDamage( dmg, z.origin, player )` — kills pay points,
  BOUNTY, luck, the elite reward). **A zombie is burned by at most ONE node per
  tick**, so an overlapping trail is a line, not a pile.
- **Damage contract:** a fraction of the ROUND's trash health
  (`level.zombie_health`, the PhD-nova rule), so it never one-shots early and
  never falls off late. Passes through `upgrade_damage_cb` on a `tod_trail_hit`
  mark: NO attacker multipliers (the figure is already the design number),
  victim-side SPRINTER ARMOR **does** apply (the cleave rule — documented
  decision, not an omission), bosses (Panzer / Wardens) immune, elites burn for
  the same absolute damage as trash (so they burn slowly, by design).
- **Cost:** zero entities per node (structs), one FX host per sprinting
  skirmisher (≤ 4). Per tick ≤ 12 nodes × ≤ 45 zombies distance checks/player.
- **Pause menu (DETAIL[45]):** eff `burns {V}% of a zombie's health per second`,
  act `while sprinting; the trail lingers N s` (level-aware).
- **First tuning knob:** the FX's visible persistence vs the 2–4 s damage
  window — align `TOD_TRAIL_LIFE` to what the fire actually shows on screen.

## PARRY — slasher, id = next free (48 as of 2026-09-02 23:30), band B, max 5

**"A zombie that hits you mid-swing is parried: the hit does nothing and your
blade answers with a riposte."**

| Level | Window (grace after the swing ends) | Riposte (of the round's zombie health) | Extra |
|---|---|---|---|
| 1 | swing only (+0 ms) | 50% | |
| 2 | +60 ms | 75% | |
| 3 | +120 ms | 100% (kills trash) | |
| 4 | +180 ms | 125% | |
| 5 | +240 ms | 150% | **+20 HP** on every parry |

- **The hook:** `_tod_bosses::boss_player_damage` is the map's ONE player-damage
  callback (stock dispatch: first non-(-1) return wins, and this map already
  returns **0** there for out-of-sight boss hits — "no damage" is an
  established contract). Before DMG REDUCTION runs it asks
  `tod_upgrades::parry_try( attacker, mod )`; true → `return 0`.
- **Qualifies:** attacker is an AI on the zombie team, `MOD_MELEE`, not a boss
  (`is_boss` / `acc_is_boss` / Panzer / Warden — their claws stay real),
  elites (protector / reaver / hound / sprinter) CAN be parried; the victim is
  a slasher with PARRY ≥ 1, alive, not in last stand; the Wisp Tea companion
  is not an attacker for this purpose.
- **The window:** a per-player 50 ms poll of the engine's `IsMeleeing()`
  stamps swing START and END; the hit is parried if you are meleeing now, or
  within the level's grace after the last swing ended. (`"weapon_melee"` is a
  stock player notify that may also fire for blades — wired as a second stamp
  lane, harmless if silent.)
- **The limiter:** ONE parry per 0.6 s per player, so a swarm still lands
  hits; with KNIFE SPEED the swing itself is faster than the limiter, which is
  the point — PARRY is not immunity.
- **The riposte:** `attacker DoDamage( frac × level.zombie_health, org, self )`
  through a `tod_parry_hit` pass-through mark (same contract as the trail:
  design number, no attacker multipliers, bosses excluded upstream). Credited
  kill → points / BOUNTY / luck / elite reward as any blade kill.
- **Feedback:** the sprint-armor ricochet ping (`tod_sprint_ricochet`, packed)
  + the blue spark burst on the parried zombie
  (`electric/fx_elec_sparks_burst_xsm_omni_blue_os` — already in the zone as
  a client fx; needs a server `#precache( "fx" )` line). No new sounds in v1;
  a blade "clang" can come with the art pack.
- **Pause menu (DETAIL[46]):** eff `riposte for {V}% of a zombie's health`,
  act `a zombie that hits you mid-swing is parried; one per 0.6s; Lv5 heals 20`.

## Wiring (the validated new-domain recipe, per domain)

1. `_tod_upgrades.gsc`: `#define TOD_TRAIL_*` / `TOD_PARRY_*`, `add_domain`
   (class scope is the default), per-player loops threaded from the
   `tod_body_systems_on` latch in `player_upgrade_setup` (trail loop; swing
   stamp loop), `parry_try()` public, the two pass-through marks at the top of
   `upgrade_damage_cb`, `#precache` + `level._effect` for the trail fire and
   the spark.
2. `_tod_bosses.gsc::boss_player_damage`: the `parry_try` call before DR.
3. `_tod_upgrade_ui.gsc::domain_id`: `case "trailblazer": return 45;`
   `case "parry": return 46;`
4. `tod_upgrade.lua`: `DOMAIN[45]`, `DOMAIN[46]` (name/desc/max),
   `DETAIL[45]`, `DETAIL[46]` (level-aware eff/act/val). `CARD_SLUG` untouched
   (text fallback) until the art lands; `PAUSE_PLATE_MAX` stays 44.
   `TIER_RESETS` (AetheriumStartMenu.lua) untouched — class scope.
5. `zone_source/zm_tower_of_doom.zone`: `fx,zombie/fx_dog_fire_trail_zmb`.
6. CHANGELOG entry; `docs/83_trailblazer_card_art_prompt.md` +    the PARRY prompt at the next free docs number + the two art packs
   (`tools/make_art_pack.ps1`) — generic value lines, no baked numbers.
7. `lint_tod_arity`, `lint_tod_lua`, hint lint (no hints touched) → **FULL
   build** (the fx zone line) → the deployed diff + `-newermt` check.

## Risks, named

- The trail FX's persistence may not match the damage window (tune `TOD_TRAIL_LIFE`).
- `IsMeleeing()` timing on the three blades is unmeasured; the grace ladder is the retune knob.
- PARRY vs a swarm: the 0.6 s limiter is the safety; if it still feels like immunity, raise the limiter first.
- Entity budget: ≤ 4 FX hosts, transient — well under the ~1024 gentity roof.

## Test plan (unplayed until then)

- Skirmisher, Lv1 then Lv5: sprint a lap with a train behind you; fire follows
  you; the train's health visibly drops; stop sprinting → the fire stops.
- Slasher: swing as a zombie strikes; hear the ping, see the spark, the zombie
  dies (Lv3+); a Panzer claw still hits you; two zombies striking together —
  only one is parried per 0.6 s.

## Amendment — TRAILBLAZER as built (v16.62, 2026-09-02)

User at sign-off: *"Can the fire fx go on the ground? And the higher tier the
larger and more effective it is?"* Both taken:

- **Ground fire, not an attached trail.** Each damage node also spawns fire
  PATCHES: tag_origin script_models on the floor with the hellhound trail fire
  looping on them, deleted by ONE level-wide reaper on their own expiry (a
  disconnect mid-sprint leaks nothing). Patches are capped map-wide at 60
  (`TOD_TRAIL_MAX_HOSTS`); when the cap is hit the damage node still lands.
- **Larger per level:** radius 56 → 88 u (`trail_radius`), and the trail is
  WIDER — 1 patch across at Lv1-2, 2 at Lv3-4, 3 at Lv5, laid perpendicular to
  the direction of travel (`trail_hosts`). Lifetime 2.0 → 4.0 s, burn 12 → 28%/s
  as planned.
- Id **46** (45 went to RIOT SHIELD, a peer session's domain landed the same
  hour); art prompt **docs/83** (82 went to RIOT SHIELD as well).
