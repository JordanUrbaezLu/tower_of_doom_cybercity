# 114 — THE MAGE: the staff journey and the class design

**Fire Blast card reduced to +20% per level (2026-09-09, built):**
Changed the six-level damage bonus from +25/50/75/100/125/150% to
+20/40/60/80/100/120% (2.20x at Lv6). Server card description, Lua
card/readout and armory now agree. Prior all-staff damage nerf remains;
fire charge payoff, firing rate, handling and other card bonuses are unchanged.
Damage regression, Lua 5.1 level readouts, arity, Lua lint and armory constants pass.
Build verified 2026-09-09 03:18:31 Eastern: FF 172,914,240 bytes; all 1,164
snapshot/repo/deployed inputs and complete script/UI/zone-source trees match
and predate FF. Fresh streamed bank 174,624,640 bytes; only established waived
asset warnings. Ready for native testing.

**All staff damage reduced another 20% (2026-09-09, built):** Multiplied
the shared Mage damage ladder by 0.80: T1 0.92 -> 0.736, T2 2.00 -> 1.60,
T3 3.95 -> 3.16. The three constants are used only by staff_mult, so every
staff direct/splash hit is reduced before the existing card, charge, PaP and
Archmage multipliers finish scaling. Existing ice-specific nerf stays in place.
Lightning chain shares use the reduced final hit and exit the callback before
attacker multipliers can apply twice. Normal integer damage rounding remains.
No weapon GDT, firing rate, splash radius, handling or target-count changes.
Updated the armory damage ladder/readouts; relative card bonuses are unchanged.
Tests compare before/after values across all three staffs, q0/q1, three tiers,
all card levels, four target families, charged shots and normal/Archmage/Dark
multipliers; chain rounding and Panzer display regressions pass. Arity and
armory constants pass.
Build verified 2026-09-09 03:07:27 Eastern: FF 172,914,240 bytes;
all 1,164 snapshot/repo/deployed inputs match and predate FF. Fresh
streamed bank 174,624,640 bytes; only the established waived asset
warnings. All dev/god flags OFF. Ready for native balance testing.


**Combined queued changes - full build verified (2026-09-09 03:01:34 Eastern):**
FF 172,914,240 bytes; fresh streamed sound bank 174,624,640 bytes. All 1,164
snapshot/repo/deployed inputs match and predate the FF; complete scripts, UI
and zone-source comparisons also pass. The packed asset list contains all six
staff variants, nine perk animation clips, the dedicated animtree/module and
green Healing Aura FX. All four reload sound aliases occur in the inflated FF.
Full BSP, navigation, lighting, script/asset/Lua gates pass; only the ten already
waived third-party asset warnings remain. All dev/god flags are OFF.
This build includes every queued change through the latest staff handling pass:
perk-machine animations, green Healing Aura FX, Winter's Howl reload foley,
ice damage/rate/radius nerfs, fire rate/radius nerfs, Archmage sprint fire and
Protector entrance elite immunity. Ready for native testing; no in-game visual,
audio or handling playtest has been performed by the agent.


**Further staff handling and ice cadence nerf (2026-09-09, built):**
User confirmed ice SHOT SPEED means FIRING RATE. Ice fireTime 0.80 -> 1.00s:
20% fewer shots per second (25% longer interval); projectile speed stays 2200.
All twelve staff lower/raise timing fields multiplied by another 1.5 across
lightning/fire/ice, then regenerated q0/q1. Normal drop+raise now
0.5625+0.9000=1.4625s; Mystical Hands 0.1875+0.3000=0.4875s. First raise
1.4625s normal / 0.4875s with card. Quick/empty/ADS-alt/swim timings also scaled;
unused zero alt times remain zero. Generator q-axis formatting now keeps five
decimals so the smaller one-third timings stay exact; other axes keep four.
Semantic comparison proves every timing exactly 1.5x the prior value in all
nine source/generated staff blocks, and only ice fireTime also changed.
Every other weapon/block, registration list and cost CSV stayed unchanged.
Normal cycling is native. Script immediate switches are bounded re-equips for
actual variant/PaP changes, not a Mage normal-cycle override; fire's cooldown
controller only gates shooting. Mage does not receive the Skirmisher HANDLING
card. Updated armory cadence and Mystical Hands timings.
Included in the verified 03:01:34 full build above; native playtest pending.


**Staff splash radius reductions (2026-09-09, built):**
Fire explosionRadius 192 -> 144 units (-25%); ice 160 -> 144 (-10%).
Regenerated all four fire/ice q0/q1 variants. Semantic comparison against the
pre-change GDTs proves only explosionRadius changed, with lightning and every
other weapon unchanged. Direct and inner/outer splash damage, minimum radius,
projectile spread, shot cadence and Mystical Hands handling remain as before.
The ice radius applies independently to each of its three real projectiles.
Updated the armory staff table. Registration count remains 235 and weapon cost
table 238/240, byte-identical to before. GDT changes require a FULL build.
Included in the verified 03:01:34 full build above; native playtest pending.


**Mage balance and Archmage sprint fire (2026-09-09, built):**
Ice damage reduced 20% for every target: beast matchup 4.19 -> 3.352 and
all-other-target matchup 2.95 -> 2.36. Those two paths cover every ice hit,
including all three volley missiles, splash and Panzer hits; card bonuses,
PaP and Archmage still multiply the reduced values. ICE SHATTER remains
+15% per level. Fire's shot interval increases 10%, 1430 -> 1573ms. The 0.10s
native state and fire-only lock are unchanged, preserving swaps and use prompts.
Archmage now grants native specialty_sprintfire through a shared
_tod_upgrades::apply_sprint_fire owner. Both the regular upgrade maintenance
and Archmage start/end use that helper, preventing the old card-only upkeep
from stripping the temporary grant. Quarter-second active checks exclude dead,
downed and disarmed Mages; class changes refresh immediately. An owned Sprint
Fire card retains its existing permission independently after Archmage expires.
Updated card/server copy and armory matchup/cadence values. All 64 native-perk
ownership/state cases, ice-before/after damage ratios across tiers/cards/forms,
fire recovery, staff asset integrity, arity and Lua structural checks pass.
Included in the verified 03:01:34 full build above; native playtest pending.


**Staff reload sound (2026-09-09, built):** All three approved
reload clips already had wpn_staff_reload_1..4 notes at frames 14/29/43/59, but
none of those aliases existed in the active sound tables. Added all four to
tod_ports, backed by four short Winter's Howl freezegun reload foley excerpts.
Sources: installed _t8/reload/fly_freezegun_mag_release.wav (first two beats)
and fly_freezegun_mag_in.wav (last two). Each excerpt is 0.28s with 8ms edge
fades, 48kHz stereo 16-bit PCM; exact ranges are in sound_assets/tod/mage/README.
Native animation notes own timing, including Speed Cola and unreached-cue
cancellation on interruption. No scripted sleeps, animation edits or new weapon
registrations. Validated all six q0/q1 staffs and four reload slots each against
the aliases/WAVs and active bank config. Reload mana regression passes.
Included in the verified 03:01:34 full build above; native playtest pending.


**Healing Aura green player FX (2026-09-09, built):** Reused the
installed Near Death Experience third-person effect as a map-owned green tint
(`share/raw/fx/tod/mage/fx_healing_aura_player.efx`). Donor is stock
`zombie/fx_bgb_near_death_3p`: only its 118 color-graph RGB keys changed;
particle motion, sizes, lifespan, camera fade and revive-symbol material remain.
The original source graph is blue, so this is a green adaptation, not a claim
that stock Near Death Experience was green. No image or sound imports needed.
Replaces the machine-light aura and repeated robot-revive hit bursts with one
upper-torso FX host per protected player. Healing pulses and overlapping auras
reuse that host. Host-owned cleanup checks actual aura protection and removes it
after expiry, downing, death or disconnect, including caster disconnects. Native
particles may fade for their original lifetime after the host is removed.
All recipients, including the caster, receive it; native near-camera fade keeps
the world effect out of first person, where the existing green health bar remains.
No new replicated fields; healing, resistance, charges, sound and cast animation
are unchanged. Actual-script lifecycle and healing-scaling tests pass; native
appearance/attachment is untested.
Included in the verified 03:01:34 full build above; native playtest pending.


**Healing Aura per-level strength (2026-09-09, built):** Lv1 keeps
10 HP/s and 50% damage resistance. Each additional card level adds 1 HP/s and
2 percentage points of resistance: Lv1-6 = 10/11/12/13/14/15 HP/s and
50/52/54/56/58/60% resistance. Five-second totals = 50/55/60/65/70/75 HP.
Caster level is latched for the pulse thread and shared with all recipients.
Integer HP pulses alternate where needed, avoiding trickle_heal's per-pulse
round-up at odd HP/s levels. Existing max-health cap remains authoritative.
Resistance tracks a recent timestamp per aura level on each recipient; the
strongest fresh level wins. A weaker aura neither replaces stronger protection
nor extends its lifetime. Existing 700ms grace and per-cast healing pulses
remain. These fields are server-only, with no new clientfield registrations.
Updated live aura text, card/server descriptions, pause values and armory copy.
Duration, radius, charges, Lv6 revive and the new sound/first-raise gesture
remain. Tests cover Lv1-6, exact full-cast totals, caster-to-teammate strength,
overlap precedence/expiry and Lua readout parity. Native playtest pending.
Build VERIFIED 2026-09-09 01:58:18 Eastern: FF 172,362,496 bytes;
1,142 snapshot/repo/deployed inputs match and predate FF. Fresh sound bank
174,624,640 bytes; only established waived asset warnings.
Dev/god OFF. Ready for native testing.


**Staff card buffs and Panzer damage display (2026-09-09, built):**
FIRE BLAST now adds 25% damage per upgrade level (Lv1-6: +25/50/75/100/125/150%;
maximum multiplier 2.50). ICE SHATTER adds 15% per level (+15/30/45/60/75/90%;
maximum 1.90) and retains its slow duration. These add per level, not compound.
Updated server domain copy, Lua card descriptions/pause values and armory
ladders/current overview. Removed the misleading Fire copy promising a DOT;
its existing survivor flames are visual. Baked card art has no percentages.
Panzer staff numbers now defer from the level callback to the final Panzer
wrapper: stock armor/hit-location reductions finish before one HUD push.
A 4,000 incoming hit reduced to 2,000 displays 2,000; zero/immune results emit
no positive number. Existing direct+splash/crowd summing remains. Marker is
installed with the wrapper; other actors and non-staff HUD paths stay as before.
The previous Panzer calculation body is unchanged, including armor side effects
and lightning's 5.60 matchup multiplier. This corrects reporting, not a hidden
lightning buff. Tests exercise live staff arithmetic at Lv0-6, all six staff
variants, 60 final-result cases, untouched result returns and early HUD suppression.
Lua 5.1 parsing/level readouts, armory constants, arity and fire cooldown pass.
Native Panzer shots-to-kill still need user testing with the corrected numbers.
Build VERIFIED 2026-09-09 01:51:45 Eastern: FF 172,361,408 bytes;
1,142 snapshot/repo/deployed inputs match and predate FF. Fresh sound bank
174,624,640 bytes; only established waived asset warnings. Dev/god
OFF. Ready for native playtest; no gameplay test performed by the agent.


**Healing Aura cast presentation (2026-09-09, built):** Imported the
user's Healing_aura_#4-1788931088647.wav unchanged as
sound_assets/tod/mage/healing_aura.wav (48 kHz stereo, 16-bit PCM, 2.76s).
A distinct tod_mage_heal_activate alias plays locally on a successful cast.
The caster skips the separate first-heal receipt ping; teammates retain that
short stock cue. Locked, active and empty-charge refusals do not play either
the activation audio or gesture. The held staff's native InitialWeaponRaise
replays its existing first-equip animation without replacing the weapon.
The reload-attempt cancellation notify precedes the gesture so an interrupted
reload cannot pay mana. All six q0/q1 staff identities are preserved.
Native sound mix and repeat first-raise playback need an in-game check.
Build VERIFIED 2026-09-09 01:44:06 Eastern: FF 172,361,344 bytes;
1,142 snapshot/repo/deployed inputs match and predate FF. Fresh sound bank
174,624,640 bytes; only established waived asset warnings.
Successful/refused cast checks cover all six staff variants; reload mana and
arity checks pass. Native animation and audio playtest pending. Dev/god OFF.


**Fire recovery correction (2026-09-09, built):** Replaced the failed
swap-button workaround with a fire-only cooldown controller. Native fireTime
is 0.10s, while script retains the 1,430ms deadline via DisableWeaponFire.
No DisableWeapons, forced swaps, inventory replacement or use-trigger bypass.
Other held weapons clear our flag; returning to fire preserves the deadline.
Death/down/disarm clear our flag, and menu/laststand weapon locks are separate.
Mystical Hands still changes lower/raise only. Charge input cannot pre-bank
while recovery, reload, switching or menus block it. Native action/animation
behavior needs a playtest; script lifecycle and generated variants are checked.
Damage audit: native fire is 1,600 direct + 2,200 inner / 700 outer splash,
then the existing per-target upgrade/tier/matchup/charge multipliers. The HUD
SUMS damage across crowd targets. Fire FX on survivors are visual, not a DOT.
Ordinary-zombie callback returns the calculated damage; no zero-damage branch
was found there. Panzer stock armor applies AFTER the HUD push, so that readout
can overstate actual damage. No damage or enemy-health balance values changed.
Full build VERIFIED 2026-09-09 01:39:13 Eastern: FF 172,362,880 bytes;
1,141 snapshot/repo/deployed inputs match and predate FF, fresh sound bank
174,624,640 bytes. Only established waived asset warnings. All dev/god flags
OFF. Fire cooldown, reload, Blink, ice-volley, arity and staff asset checks
pass; native post-shot interactions and animation feel await user playtest.


**Reload mana (2026-09-08):** User requests a small mana reward for a full
successful staff reload. All three staffs now award 5 mana once per completed
reload, via mana_add (100 cap, no gain during Archmage). A reload_start arms
one attempt; stock reload notification plus IsReloading clearing confirms
completion past the ammo/animation tail. Fire, weapon change, sprint, melee,
new reload, class disarm, death and disconnect cancel pending rewards. Final
state guards also reject downed/menu/paused players and changed weapons.
HUD updates through the existing mana_push path. No new sound/toast spam.
`tools/test_mage_reload_mana.js` exercises actual GSC coroutine logic with
simulated native events: no early/double award, 18 cancellation cases, state
guards and cap pass. Native notification timing remains a playtest check.
Script build verified 2026-09-08 23:21:22 Eastern: FF 172,361,728 bytes,
138 script/UI/zone inputs match snapshot/repo/deployed and predate the FF.
Only established waived linker warnings. Completion/cancellation behavior
still needs confirmation in BO3.


**Ice volley correction (2026-09-08):** Ice was one native missile with
cosmetic flying icicles in the muzzle FX. `ice_volley_watch` now adds two real
missiles per ice weapon_fired event, using the exact fired variant/player via
MagicBullet (stock multirocket pattern). Symmetric +/-8-degree view-space fan;
center remains native. Side hits use full existing per-projectile damage,
splash and normal ice slow/PaP/matchup callbacks. Overlapping explosions can
increase damage to one target; this is not a damage-neutral cosmetic change.
No extra weapon registrations or ammo deductions. Custom 1p/3p muzzle FX each
remove 13 cosmetic icicle-model emitters, keeping the other flash particles;
real missiles retain the stock trail/impact. All generated ice twins use the
new muzzle FX. `tools/test_mage_ice_volley.js` passes 40 aim/variant cases plus
non-ice filtering; engine collision and side-hit damage need playtesting.
Full build verified 2026-09-08 23:16:59 Eastern: FF 172,363,328 bytes,
fresh all.sabs 174,624,640 bytes; 224 inputs match snapshot/repo/deployed and
predate FF; 89 required staff assets packed, including both new muzzle effects.
Only established waived asset warnings; prior Enfield checksum warning did
not recur. Runtime outer-bolt collision/damage still needs playtesting.


**Blink charges (2026-09-08):** Locked at level 0, one stored charge at levels
1–2, two maximum at levels 3–5. Unlocking grants the first charge; reaching
level 3 grants the new second slot. Spent charges refill sequentially at the
12/10.5/9/7.5/6-second per-level rate (50% longer, 2026-09-09). Using the second stored charge does
not restart the first recharge. Elite kills refund the active recharge timer;
failed landings spend nothing. `blink_charges_now()` owns cast readiness and
the tactical HUD count, which dims at zero. Respawn resets charges with the
existing cooldown reset; class promotion preserves stored charges. The card
text and armory ladder describe the level-3 capacity increase.
`node tools/test_mage_blink.js` executes the actual charge helpers with mocked
time and checks unlocks, levels 0–5, exhaustion, sequential refill, second-use
progress, elite refunds, and upgrading during a recharge. Built at 19:22:24
Eastern: 172,004,288-byte fastfile and 174,624,640-byte sound bank. Initial build
hit the previously recorded material/access-violation crash. Stopped our retry
when a peer build overlapped; the peer build completed with the changes.
All 138 script/zone/UI files match deployment and predate that fastfile.
Gameplay verification is pending.

**MYSTICAL HANDS (2026-09-08; formerly Quick Hands):** Domain 56, Mage only, max 1, S band and
ultimate-only like Deadshot; no dark tier. Persists through promotion.
The q1 form of each staff divides all lowering/raising timings by three;
q0 keeps the current base timings. Per-staff PaP keys are unchanged. All
retained staffs reconcile, including holstered ones. The approved ultimate
card and pause plate r56 are installed (docs/123).
Ledger 235 (three extra variants), explicitly authorized as a boot experiment.

**Staff switching (2026-09-08):** All three source staff GDTs use halved
raise/drop timings, propagated through `gen_tod_twins.js`. Normal drop/raise
is 0.25/0.40 seconds; quick drop/raise is 0.125/0.35 seconds.

**Ability unlocks (2026-09-08):** Blink, Healing Aura and Archmage require their
first card. `ready()` rejects level 0 before checking cooldowns; it drives
Blink's HUD and cast together. Locked abilities remain visible but dimmed.
Archmage activation also checks `ready()` before spending mana. Its activation
prompt requires both the unlock and a full bar; mana still accumulates normally.

**Draft layout (2026-09-08):** Skirmisher, Assault, Mage, Heavy, Slasher.
Mage occupies the middle slot and is focused when class selection opens.
Display slots are separate from the stable class IDs used by the HUD.

**Staff PaP correction (2026-09-08, v18.50):** Every staff keeps its own
PaP level in `tod_pap_tier`, keyed by staff stem, including first pack.
Lightning must be packed for Fire; Fire must be packed for Ice. Older staffs
retain their level through promotions and new staffs start unpacked. First
PaP at a machine simulates the swap with the existing half-second take/return
sequence, full ammo and camo. Free PaP drops use the same independent state.

**Ability corrections (2026-09-08, v18.49):** HEALING AURA is locked until
`mage_heal >= 1`, with zero charges before unlock. The first unlock and later
capacity increases grant only the added slots. Blink uses the same real
cooldown for input and HUD even under god/money/dev flags; the cast immediately
sends the unavailable state (40% alpha). Stock grenade count/icon subscriptions
cannot overwrite mage tiles; leaving mage restores the stock readouts.

Insta-Kill remains one-hit against ordinary zombies and 3x damage against
boss-flagged elites, including staff hits. The Rogue Protector's fallback
previously omitted the boost and all staff-specific multipliers; it now
delegates to the main damage callback only when that callback has not already
handled the hit. Matchup penalties still apply. This closes a verified code
gap; the reported elite encounter has not been reproduced in-game.

**Loadout correction (2026-09-08, v18.48):** mage has no secondary at any
tier. The old `pistol_standard` placeholder was still a live grant, and the
dev max-out packed it into Death and Taxes. Both secondary lookups now return
empty; the shared grant helper removes existing sidearms (base or packed)
before returning without a weapon. This covers initial class selection,
respawns and tier promotions; sidearm PaP/classification already reject an
empty stem. Dev max-out is off: start with the tier-1 lightning staff and earn
fire and ice normally. Only money, god mode and open doors remain enabled.

**Status 2026-09-07: THE CLASS IS BUILT WHOLE IN TOWER OF DOOM AND SHIPPED OFF.**
All five build phases are green behind one flag (`TOD_MAGE_ENABLED 0`, section D) —
registry, draft card, four domains, staff ladder and the runtime module. **Nothing has
been played.** Separately, the Origins Staff of Fire — model AND its real first-person
animations — is extracted and building cleanly in the ShadowLight Arena test map.

This doc is the single record of where the staff came from, what works, and what the
MAGE is meant to be. Everything below marked ⚠️ is unproven.

---

## A. THE STAFF JOURNEY — how we got the asset

### A.1 What we tried first, and why it failed

| Route | Verdict |
|---|---|
| Build our own staff model (ShadowLight `sla_staff_fire`) | **Rejected by the user on look and on feel.** It exists and works — see `test+map/docs/19_magic_weapons.md` — but the user's rule is [[reuse-over-authoring]]: *"I'm really not trying to make our own staff … we're really trying to reuse as much as we can."* |
| Borrow a gun's first-person animations for a staff | **Play-tested and REJECTED.** The staff was put in the user's hands at spawn on `vm_freezegun_*` (30 stock anims, already installed). Verdict: *"Nah its liek shooting a gun."* A staff cannot wear a rifle's stance — this is what forced a real animation extraction. |
| HarryBo21's staff pack | **Closed.** All 13 of his source links are dead AND he publicly forbade reuploads (*"DO NOT REUPLOAD PUBLICALLY im having this removed"*). His assets are themselves rips of the same Treyarch staffs, so the route added a permission problem without solving anything. |
| Elemental Staffs / Elemental Staffs HD Workshop mods | Useful as reference only — they are compiled `zm_mod.ff`, not source. **Both are LIVE on the Workshop** (see the correction below). Backed up anyway. |

**A correction that cost a decision.** I reported both staff mods as *removed by Valve for
guideline violations*, and the user chose HarryBo21's pack partly because of it. It was
false: the "has been removed … violates Steam Community & Content Guidelines" string is
hidden boilerplate on **every** Workshop page, including this map's own. Steam's API is the
authority — all four items return `banned=0 visibility=0`. Full lesson:
[[workshop-removed-string-is-boilerplate]].

### A.2 What actually worked

**Extract from `zm_tomb` (Origins) directly.** The user owns Zombies Chronicles, so the
official BO3 HD remaster is on their own disk — no middleman, no dead links, no permission
question beyond the ordinary one every port in this map already carries.

Toolchain, all installed and verified 2026-09-07:

| Tool | Where | Note |
|---|---|---|
| Greyhound 1.46.3.2 | `Documents/BO3_tools/Greyhound/` | **Attaches to a RUNNING `blackops3.exe`** — it cannot open a `.ff`. Load Game, not Load File. |
| Blender 4.2 LTS | `Program Files/Blender Foundation/Blender 4.2` | **Not 5.2** — the CoD addons claim only 3.x/4.x. |
| BetterBetterBlenderCOD | `AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/` | Enabled and verified: all four xmodel/xanim import+export operators register. |

Export settings that matter (`greyhound.json`): turn ON `export_xmexport` and `export_xmbin`
so models land as `XMODEL_EXPORT` + `XMODEL_BIN` — the mod tools' own formats, no conversion.
Textures export as **PNG and PNG is fine** (9,345 existing image entries in the tools use
`.png` vs 6,070 TIFF) — map 1's "TIFF only" note in `docs/35` is stale.

### A.3 The real asset names — observed, not guessed

Searching "staff" in Greyhound on Origins returns **201 assets**. Every name guessed by
research before this point was wrong; these are read off the live game.

**Animations — `vm_zom_staff_*`, 30 fps, 201 bones** (the full viewhands rig). Element-aware
(`reload_fire` / `_ice` / `_air` / `_elec`), upgrade-aware (`upg`), and there is a revive lane
(`vm_zom_staff_t7_upg_revive_pullout` / `_revive_putaway`).

**Models — `wpn_t7_zmb_hd_staff_*`** (`hd` = the Chronicles remaster). Treyarch built these
as a **kit, not as four staffs**:

```
wpn_t7_zmb_hd_staff_view / _world          <- ONE shared shaft
  + wpn_t7_zmb_hd_staff_tip_<elem>_view    <- the element head
  + wpn_t7_zmb_hd_staff_crystal_<elem>_*   <- the glowing stone
  + wpn_t7_zmb_hd_staff_tip_<elem>_upg_world  <- the UPGRADED head
```

That kit structure is a gift for the tier ladder — see §B.2.

### A.4 What is landed right now

`test+map/source_data/tod_staff_origins.gdt` — 24 images + 4 materials + 4 xmodels,
generated by a script that **clones a proven port's blocks** rather than hand-authoring
fields. Staged meshes/textures live in `test+map/model_export/sla/tod_staff/`.
ShadowLight's existing `sla_staff_fire_zm` now points at them
(`gunModel` → `tod_staff_view`, `worldModel` → `tod_staff_world`,
`attachViewModel1` → `tod_staff_tip_fire_view`; original saved as `sla_staff.gdt.pre_origins`).
**Builds clean.**

**Three traps paid for, in the order they bit:**
1. `xmodel "filename"` is relative to `model_export/`, but `image "baseImage"` is relative to
   the **tools root** and needs a `model_export\` prefix. The mesh converts fine while every
   texture fails with a bare *"is missing"*.
2. **A techset is looked up by the whole material PERMUTATION, not by `materialType`.**
   Cloning an emissive material and overwriting `materialType` to `lit_weapon` produced
   *"no techset for surface 0"*. Clone a material that is **already** `lit_weapon`, from a
   port that demonstrably renders (used `skye_iw7_udm.gdt`).
3. Image `semantic` / `coreSemantic` / `compressionMethod` differ per map kind. Guessing them
   fails conversion silently-ish. Clone the settings from an image of the **same suffix**.

### A.5 THE ANIMATIONS — CONVERTED AND BUILDING (2026-09-07)

**64 of 68 Origins staff viewmodel animations are converted, packed, and building clean into
ShadowLight.** The staff no longer wears the freeze gun's stance.

**Discard Greyhound's "DirectXAnim" output.** Those extensionless files are the *compiled game*
xanim — quantised, no hierarchy — not a source format. `export2bin` is a TEXT parser and
rejects them outright. **The `.seanim` files are the source.**

The pipeline that works, end to end:

```
.seanim  ->  [converter: FK to world space]  ->  .XANIM_EXPORT  ->  export2bin  ->  .XANIM_BIN
```

**Proven, not assumed.** 17 of the animations already ship as Treyarch `.XANIM_BIN` in the mod
tools, so they are a numerical oracle. Converting those and diffing against Treyarch's own
files over **146,200 bone-frame samples**: median position error **0.0053 units**, median
rotation **0.412°**. Bones that do not move reproduce exactly (median rotation 0.000°), which
places the residual in the source data's own compression, not in the converter.

**Five traps, each of which cost a build:**

1. **SEAnim positions are in CENTIMETRES.** Scale by 1/2.54. Nothing in the header says so;
   reading the spec gave 44–80 unit median error.
2. **Position and rotation use different semantics.** Rotation is always the absolute
   parent-local quaternion; position depends on animType — type 0 absolute, types 2/3 relative
   to the bind pose. Type 1 (ADDITIVE) is a layered pose and is **not convertible standalone**;
   4 animations (`fall`, `jump`, `jump_land`, `walk_f`) were correctly SKIPPED rather than
   emitted wrong. Those four fields stay on the freeze gun, which is a safe blend.
3. **PyCoD's `WriteFile_Bin` is unusable for both xanim and xmodel.** It produces a token
   stream that *neither the linker nor PyCoD itself* can read back
   (`Unknown Block Hash 0x16`). Its READ side and its maths are fine — it is the binary writer
   that is broken. Always go out through `.XANIM_EXPORT` / `.XMODEL_EXPORT` and `export2bin`.
4. **`export2bin` silently PASSES THE FILE THROUGH when invoked with absolute paths.** The
   output then begins `//` (`0x2F2F`) — the source file copied verbatim, not converted, and
   it reports success. **It must be run with the working directory set to the input folder and
   a bare filename or pattern:**
   `cd <input dir>; export2bin /nt=8 /o=<out dir> "*.XANIM_EXPORT"`
   Verify every output begins with the ASCII magic `*LZ4*` — that check is the whole defence.
5. **`'end' is not an allowed user specified notetrack.`** Greyhound carries Treyarch's own
   note names straight out of the game, and the linker reserves `end`. It killed 14 of 64.
   Drop engine-reserved notetracks during conversion.

**The bind skeleton had to be synthesised.** A GDT xanim entry's `model` field is never empty
(0 of 8,202 live entries) and no single model on the machine carries both the viewhands bones
and the Origins staff tags. `tod_staff_skeleton` is a shipped Skye port's arm model (real
geometry, 110 bones) with the remaining 107 bones of the union rig APPENDED — appending is
what makes it safe, because vertex weights index bones by position. 217 bones, and every
animation's bones are present.

**Dropped bones: 37, and all inert.** 36 are `j_sleeve*` (the user chose to drop Origins' coat
sleeves — the map ships its own player models). The 37th, `tag_weapon_le`, appears in two
3-bone ADS animations and carries **zero keys** — a placeholder with no animation data.

Still open: the 4 additive animations, and animType 2 (the 29 `pt_` player-torso anims) which
is handled as relative but is **unvalidated** and was not delivered.
- The **crystal** is excluded: `mtl_..._crystal_fire` is a camo-shader material (only
  `$camo_base_*` + `i_generic_lookup` + a shared `crystals_n/_o`, no plain `_c`). Needs a
  different materialType and a camo table.
- The `_upg` tips exist only as `_world`. The upgraded viewmodel may be handled another way.

---

## B. THE CLASS — design decisions from the user, 2026-09-07

### B.1 The shape

A fifth class alongside Skirmisher / Assault / Heavy / Slasher. Three weapon tiers like
every other class, plus **an upgrade tree that is the actual identity**.

> *"Starts as a basic staff and slowly gets stronger. So the model will start super basic.
> Then maybe one with more detail and then a final one with even more detail. But their
> upgrades will be getting the elements and using those."*

### B.2 The three staff tiers

The ladder is the **model getting richer**, using Treyarch's own kit (§A.3) — shaft alone,
shaft + tip, shaft + upgraded tip — so no modelling is required. Costs **6 weapon
registrations** (3 tiers × base + Pack-a-Punch, `axes: []`).

Pack-a-Punch forms are required, not optional: the tier gate needs the class gun packed.

### B.3 The elements — AIR, then FIRE, then ICE

**Lightning is deliberately out**: the Slasher's Stormbreaker already owns electricity.

- The staff has a **BASE ATTACK** from the moment you draft it.
- The three elements are **earned through upgrade cards** — you do not start with them.
- **Six upgrade levels each.**
- **Elements do bonus damage to specific ELITES.** The base attack is deliberately weak
  against elites; a maxed element should be *"maybe one of the highest damage in the game."*
  That is the incentive to spread upgrades across all three rather than tunnelling one.

**THE UNLOCK ORDER IS THE TIER LADDER.** Each staff tier opens the next element, so the
progression the user asked for — a plain staff that slowly becomes a caster — is carried by
the same gate that already exists for every other class:

| Tier | Element it unlocks | Role | Beats |
|---|---|---|---|
| 1 | **AIR** | Horde clear. Big effect, **long recharge**. | trash — the horde, not elites |
| 2 | **FIRE** | Single-target elite killer | **Panzers** and the **robots** (Rogue Protectors) |
| 3 | **ICE** | Pack control / anti-fast | **hellhounds**, **armored zombies**, dogs |

Tier 1 therefore carries **few upgrades** by design — it is the plain staff plus one
horde-clear button. The class blooms as it climbs.

**Why this is a good fit:** it maps one-to-one onto the threats this map actually fields.
Every elite family in the tower has an answer, and no element is dead weight —
[[zombie-count-is-trash-only]] is a reminder that trash and elites are counted and handled
separately here, which is exactly the seam this design runs along.

FX are already on disk and cost nothing: the Origins `fx_staff_air_*` / `fx_staff_fire_*` /
`fx_staff_ice_*` sets (151 files, all four elements, including the upgraded `_ug` variants).
For AIR the user is happy to use either the Origins wind effects or a **Thundergun-style
blast**, which is a stock BO3 asset this repo can already reach.

⚠️ **The Apothicon Fury (Reaver) is not assigned an element** — it is one of the map's four
elite families and currently no element counters it. Decide before build: give it to ICE,
give it to FIRE, or leave it deliberately uncountered.

⚠️ One phrase in the user's spec was unclear on the ice element — *"it'll be really strong in
social"* — most likely **solo**, but confirm rather than assume.

Because they are upgrade domains and not weapons, the elements cost **zero** weapon
registrations — this map's standing law is that upgrades are never weapon variants.

Also wanted: a plain **damage upgrade** for the staff itself.

### B.4 COMBAT STANCE — how one weapon carries many moves

The user's answer to *"how can you give something so many different moves?"*:

> *"the button to aim in will put you in probably, like, a combat stance where we'll use those
> four buttons on the right, like a x, b y, those ones, and each one will do a different move,
> and then you can still hit the trigger to shoot your basic shot. And then if you want … you
> can aim in again to kind of … takeout combat mode."*

- **ADS toggles COMBAT STANCE.** The staff therefore has **no conventional aim-down-sights** —
  the ADS button is spent on the mode.
- In stance, the **four face buttons** each cast a different move.
- The **trigger still fires the basic shot** in either mode.
- **Audio cue on entering and leaving** the stance, so the state is never ambiguous.
  The user intends to generate these with ElevenLabs.

⚠️ Input feasibility is unproven but the map has form here: it already polls action buttons
directly for its card menu, and [[bo3-menu-input-apis]] records which APIs survive which
states. Read that before designing the poll.

### B.5 THE REVIVE STAFF

Origins' fifth staff is a revive tool, and the user wants it:

> *"it does have that ability to revive someone right away … that'll definitely be an upgrade
> as well."*

**We already hold the assets for this.** `mtl_wpn_t7_zmb_hd_staff_revive` is in the shipped
GDT, `wpn_t7_zmb_hd_staff_revive_view` / `_world` and `..._parts_revive` are in the export,
and the animation set has a dedicated revive lane. Worth designing as its own upgrade domain.
⚠️ Instant revive interacts with the map's down-path contracts — see
[[down-path-stock-contracts]] before touching it.

### B.6 THE AIR LAUNCH — blast the ground, ride it up

> *"one move that you can unlock that kinda shoots an air blast to the ground, and it kind …
> can make you jump up to certain levels of the tower, um, but it can only be used at the base
> of the tower, um, which also means that mage can't take fall damage."*

**This is doable, and there is stock precedent — but only one implementation works.**

The trap first, because this project has already paid for it once:
**velocity writes on a GROUNDED player are overwritten by the movement code every frame.**
That is precisely why CHAIN LUNGE was designed, built and retired
([[pending-chain-lunge]], `_tod_lunge.gsc:45-46`). A single `SetVelocity` on someone standing
on the floor does nothing at all.

**Stock's own answer is `_zm_jump_pad.gsc:491-495`: re-assert `SetVelocity` every server
frame for the whole flight.** That is a shipped Treyarch launcher doing exactly the thing
this ability needs, so the lane is proven — it just cannot be a one-shot impulse.

Engine facts that size it ([[per-player-movement-levers]] is the full record):

- **Apex goes as velocity SQUARED** — `h = v²/2g`. "Twice as high" is ×1.41 velocity, not ×2.
  At the map's `LAP_RISE 384`, ten floors is 3,840 units and wants roughly 2,500 u/s.
- **`SetPlayerGravity` is per-player** and only raises an apex if set AFTER launch — it is the
  hang-time lever, not the height lever. Good for making the ride readable.
- **`SetJumpHeight` is GLOBAL** and must never be used for a class ability; it silently buffs
  the whole lobby the moment a second player joins.
- There is **no sub-50 ms script lane** (`SERVER_FRAME .05`), so the flight is re-asserted at
  20 Hz. Fine for a launch; it is why the ascent should be tuned, not improvised.

**Fall damage.** Making the MAGE immune is straightforward through the damage callback, but
read [[damage-passthrough-marks]] first: a `return -1` pass-through skips VICTIM-side
modifiers too, so the immunity has to be written where it does not eat the rest of the
player's damage handling.

⚠️ **Two design questions this raises, both the user's call:**
1. **Where do you land?** The stair is a spiral on the OUTSIDE of the core, so a vertical
   launch from the base goes up open air. Either the ability targets a landing, or the player
   rides up and falls back down having achieved nothing. This is a geometry problem, not a
   scripting one, and it decides whether the move is fun.
2. **Does it skip the door economy?** The whole map is paid for door by door. Landing on a
   floor above a door you have not bought is a progression bypass. "Base of the tower only"
   limits it, but does not by itself prevent landing past a closed door.

### B.7 Class uniques — three proposals

Every class has 2-3 domains only it can be dealt (skirmisher ADRENALINE / SECOND WIND,
assault SCAVENGER / DEADSHOT, heavy VITALITY / RECOVERY, slasher CLEAVE / DRAWCUT /
GUNSLINGER / THUNDER). The MAGE needs the same. All the shared domains — DR, LUCK, SPRINT,
HEADSHOT, BOUNTY, GIANT SLAYER — apply to it for free; nothing extra is needed for those.

Proposed, each chosen because its lever is already proven in this repo:

| # | Domain | What it does | Lever |
|---|---|---|---|
| 1 | **ATTUNEMENT** | Cuts elemental cooldowns / refunds a charge on an elite kill | Pure script. This is the mage's FIRE RATE — the whole kit is gated on recharge, so without it the class has no throughput knob at all. Air's "long recharge" makes it the most-wanted card in the deck. |
| 2 | **LEVITATION** | Lower personal gravity: floatier, higher, softer landings | **`SetPlayerGravity` is per-player and verified** ([[per-player-movement-levers]]). One lever answers three of the user's wishes at once — the levitation idea, the air launch's ride, and fall-damage survivability. |
| 3 | **CONDUIT** | The BASIC attack inherits a slice of your strongest element | Pure script, on the damage callback the elements already use. Solves a real problem the design creates: the base attack is deliberately weak against elites, which risks feeling bad for a whole run. Conduit means element investment never stops paying. |

Reasoning on #2 worth keeping: gravity is the *right* lever and jump height is the wrong one.
`SetJumpHeight` is GLOBAL and would buff the entire lobby off one player's card — the exact
silent co-op bug this project has been bitten by before.

**Class move speed** is unset. The spread today is heavy 0.75 / assault 0.9 / slasher 1.0 /
skirmisher 1.1. A robed caster reads slow, and starting low gives LEVITATION somewhere to go —
**0.85 is the suggested starting knob**, set in `class_speed_base()`, never on the weapon.

### B.8 Open, user still thinking

- **Levitation.** *"I think maybe I wanna allow the mage to levitate or something. I'm not
  sure if we can even do that."* Unproven. [[per-player-movement-levers]] is the record of
  what this engine does and does not allow per player — start there, and note that
  `SetJumpHeight` is GLOBAL, which has bitten this project before.
- More moves and upgrades to come.

---

## C. What has to be true before any of this ships

1. **The animations must convert** (§A.5). Without them the class does not exist —
   the gun stance was already rejected in play.
2. **The weapon ledger must be paid.** Tower of Doom is at **229/229** and the generator
   throws before writing anything. Two costed options are on the table and the decision is
   parked at the user's request; the recommendation is retiring the four dark weapon rungs
   (frees 10, costs only Warden-Trial reward cards) over dropping the Enfield/Krig `r` axis
   (frees 32, but silently removes the RECOIL upgrade from Assault tiers 1 and 2).
3. **Everything above is being tested in ShadowLight Arena**, not in Tower of Doom, because
   its builds are fast and it cannot break the published map. GDTs are shared across every
   map on the machine, so the asset work transfers with no rework.

---

## D. THE GATE, AND HOW TO TURN THE CLASS ON

**Status 2026-09-07: the class is BUILT WHOLE and SHIPPED OFF.** Every phase below
built green; nothing has been played. The flag is `0`.

### D.1 The two literals — one per language, and two is the FLOOR

User, 2026-09-07: *"make sure that all the changes you're making are behind a
singular flag that is false right now ... We're also working on fixing bugs for
the production version to publish while you're making changes, and we don't want
those to intersect at all."*

| literal | file | today | governs |
|---|---|---|---|
| `TOD_MAGE_ENABLED` | `scripts/zm/zm_tower_of_doom/_tod_mage.gsh` | `0` | **all GSC** |
| `MAGE_ENABLED` | `ui/uieditor/menus/hud/tod_class_select.lua` | `false` | **all Lua** |

**`TOD_CLS_COUNT` is DERIVED** — `( 4 + TOD_MAGE_ENABLED )` — so it is not a
literal and cannot drift. Nested `#define` expansion has stock precedent
(`#define FILTER_INDEX_VISION_PULSE FILTER_INDEX_GADGET`) and was confirmed by a
real build on 2026-09-07: `_tod_class_select.gsc` compiled and packed with zero
errors in the linker errorlog.

**Why Lua needs its own literal at all:** the draft card geometry (`CLASS_N`,
`CARD_W`, `CARD_PITCH`) is computed at FILE-PARSE time, and the zone loads
`tod_class_select.lua` at line 375 against `TodKeycap.lua` at 380 — so no shared
Lua module has loaded yet. A `CoD.*` flag would read nil. That is the whole
reason this is two and not one.

**TWO FLAGS WERE DELETED, NOT ASSERTED (2026-09-07).** `MAGE_ART` in
`tod_upgrade.lua` and `TOD_MAGE_ART` in `AetheriumLoadout.lua` each gated art
registration that cannot be switched on until the images are baked and zoned —
so they bought nothing today and cost two more literals. `build_map.ps1` now
**Dies if any third Lua `MAGE_*` local reappears**, which is how five became two
in the first place. What to add back when the art lands is written at both
deletion sites and in docs/116.

Lua cannot read a GSC define and a GSC define does not cross files, so these
cannot be derived from one another. **`tools/build_map.ps1` hard-Dies on any
disagreement** and refuses `-Publish` while the flag is `1`. Every mismatch is
otherwise silent: GSC on / Lua off draws four cards over a five-class draft and
the mage is unpickable with no error anywhere.

The tools do NOT carry their own copy — `gen_tod_twins.js` and
`lint_tod_weapons.js` both PARSE the `.gsh`. Never add a mirrored JS constant.

### D.2 Why it is inert, measured

- **No ledger spend.** The three staff rungs are `enabled: MAGE_ON`. The
  generator still prints `201 generated + 28 fixed = 229 (guard 229)`, emits no
  GDT block / zone line / CSV row, and a second run is byte-identical. Verified
  by `grep -c tod_staff` returning 0 across all three generated artifacts.
- **No deal pollution.** All four domains carry `class_keys array( "mage" )`, and
  `domain_available` compares those against `player.tod_class`. No player can
  hold `"mage"` while `register_class` is gated, so the test fails before
  anything else is read — and that one predicate is the gate under `eligible_pool`,
  `dark_pool`, `player_has_domains_left`, `dev_grant_maxed` and `king_max_player`.
- **No draft entry.** `TOD_CLS_COUNT` is 4, and `random_class_key()` — the one
  lane that reads the REGISTRY rather than the draft's id table — now honours a
  new `draftable` flag, so a drop-in joiner can never be handed the class either.
- **No lint failure.** `lint_tod_weapons` reads the gate and skips the mage's
  `register_gun` rows (its scan is raw text and does not strip comments, so it
  would otherwise demand assets that were deliberately not emitted). Ids 48–51
  are above `PAUSE_PLATE_MAX 47` so no plate is owed; no `CARD_SLUG` exists so no
  card is owed; `set_no_dark` on all four closes the dark-card lane.
- **The one measurable delta:** four zero entries in every player's `tod_levels`
  from `player_upgrade_setup`'s zero-fill. Nothing reads them.

### D.3 Reserved ids

`48` AIR · `49` FIRE · `50` ICE · `51` ATTUNEMENT.
**`52` and `53` are RESERVED for LEVITATION and CONDUIT** (§B.7). The domain-id
clientfields are 6 bits (1..63), so there is room and no clientfield change is
owed — which matters, because the clientuimodel pool is at its proven ceiling.

### D.4 The enable runbook

Do these in order. **Do not flip the flag first** — it will not build.

1. **Pay the weapon ledger.** The map is at 229/229 and the generator throws
   above it, before every write. The Mage costs 6. Recommended payment: retire
   the four dark weapon rungs (`axisMaxUp` on the MP7, the AK-47 and the
   Leviathan) for 10, which costs only Warden-Trial reward cards. The alternative
   — dropping the Enfield/Krig `r` axis for 32 — silently deals dead RECOIL cards
   to Assault tiers 1–2 unless `set_guns( "recoil", ... )` is re-added, and it
   reverses a 2026-08-23 user decision.
2. **Land the staff assets.** `source_data/tod_staff.gdt` with `tod_staff_t1/t2/t3`
   and their `_up` forms, all with **zero explosion values** — the CW Nail Gun
   precedent. Damage parked in splash is damage the tier ladder never moves and
   Pack-a-Punch never improves.
3. **Uncomment the three `fx,` lines** in the zone. FULL BUILD — fx are link-time.
4. **Land the card art** (`docs/115`, pack already sent) and add the `CARD_SLUG`
   entries and `image,` lines in the SAME build. `lint_tod_assets` GATE A hard
   fails on a live path naming an unzoned image.
5. **Flip BOTH literals together** (`TOD_MAGE_ENABLED` 1 and `MAGE_ENABLED`
   true — `TOD_CLS_COUNT` follows on its own), re-add the art registrations
   named at the two deletion sites, run `node tools/gen_tod_twins.js`, then
   FULL BUILD.
6. **Play it.** Nothing in §B or §C has been tested.

### D.5 What is still owed

- The **T3 upgraded tip has no viewmodel** — the export holds `_upg` tips only as
  `_world`. T3 currently wears T2's tip and is visually identical to it.
- The **combat stance is unproven**: `AdsButtonPressed` / `JumpButtonPressed` /
  `UseButtonPressed` / `MeleeButtonPressed` are all proven in this tree, but the
  stance loop itself, the `AllowAds(false)` keeper against stock's
  `enable_player_move_states`, and the USE-tap-vs-hold split have never run.
- The **stance audio cue is a placeholder** (`zmb_perks_packa_ready`). An
  ElevenLabs pair is owed.
- **Every number in `_tod_mage_elements.gsc` is unplayed**, and its Lua mirrors
  in `DETAIL[48..51]` are the only place a player reads any of them.
- **`docs/armory.html` owes four `DOMAINS` rows** (`mage_air` 48 B 6, `mage_fire` 49 A 6,
  `mage_ice` 50 A 6, `mage_attune` 51 A 5; all `cls:["mage"]`, `scope:"class"`,
  `guns:null`) plus its hand-maintained counters. `verify_armory_domains.js` prints the
  four MISSING lines on every build and is ADVISORY, not a gate — it is a reminder, and
  it will keep reminding until the page is updated and the artifact re-published.

---

## E. HEALING AURA (domain 52) — added 2026-09-07

User, same day as the class itself: *"we also need a new move called healing aura.
And this one is to support you and the team, um, whoever's near you."*

### E.1 What it is

The mage's **fourth combat-stance cast**, and the only one that is not an element.
Six levels, band A, mage-only, `set_no_dark` (parked, exactly like the other four).

| | |
|---|---|
| Key / id | `mage_heal` / **52** |
| Levels | 6 |
| Tier gate | **none** — see E.2 |
| Cast button | lethal (`FragButtonPressed`) — see E.3 and F.1 |
| Shape | 10 pulses x 0.5 s = a 5.0 s aura, **linked to the caster** |
| Radius | 256 / 288 / 320 / 352 / 384 / 416 |
| Heal | 6.5 / 7.15 / 7.8 / 8.45 / 9.1 / 9.75 flat HP per second — 32.5 / 35.75 / 39 / 42.25 / 45.5 / 48.75 HP over the five seconds |
| Charges | 1 / 1 / 2 / 2 / 3 / 3, one back every 22 s (`TOD_MAGE_CHG_RECHARGE_S`, cap `TOD_MAGE_CHG_MAX` 3) |
| Level 6 | **also raises one downed teammate per cast** |

Heal is a flat HP/s drawn from the *caster's* own latched card level, not a share of each
target's max health — 6.5 HP/s at Lv1 rising to 9.75 at Lv6, identical for everyone
standing in it. The old fraction quietly made the aura worth more to a VITALITY heavy
than to the mage who cast it, which is why v18.38 retired it.

It reuses `tod_upgrades::trickle_heal()` rather than writing health itself — that
function already owns the clamp to maxhealth and the never-lower guard.

### E.2 Why it is NOT behind a staff tier

FIRE and ICE are (`set_tier_min` 2 and 3). HEALING AURA deliberately is not.

The mage moves at **0.85** and its DAMAGE REDUCTION is **capped at 3** where every
other class reaches 5. Both were the user's calls, and together they make this the
most fragile class in the map. The counterweight to that has to be draftable from the
**first** card, not from the second staff — otherwise the class's weakest stretch is
also the stretch where it has no answer.

### E.3 The button, and why it is not a face button

The user asked for the four right-hand face buttons: *"we'll use those four buttons on
the right, like a x, b y"*. Three of the four are already spent (melee → AIR, jump/A →
FIRE, use/X → ICE). The fourth would be **B (crouch)** or **Y (weapon switch)**.

**BO3 GSC publishes no poll for either.** The complete set of `*ButtonPressed()`
readers used anywhere in this map is melee, jump, use, ads, attack, reload, frag,
secondary-offhand and actionslot three/four. Of what is left:

- `AttackButtonPressed` is **spent by design** — the trigger still fires the basic
  shot in stance, which the user asked for explicitly.
- `ReloadButtonPressed` **shares the physical X button with USE on a pad**, so it
  would double-fire against ICE.
- `ActionSlotThree/Four` are the d-pad, which this map has already established is not
  a device proof and is bound to keyboard 3/4 in `players/bindings_0.cfg`.

That leaves the **offhand pair**, which is also the one pair CLAUDE.md already records
as correct on every device in every place the card panel opens. `stance_enter` now
calls `DisableOffhandWeapons()` and `stance_exit` restores it, so the tactical grenade
does not come out alongside the cast. Both halves are stock and appear in
`doors_shared` / `killstreaks_shared`.

**If a face button is ever wanted here, the blocker is the engine, not the design.**

### E.4 Level 6 is the revive staff

The user, the same day: *"it does have that ability to revive someone right away.
That'll definitely be an upgrade as well."*

Folding it into HEALING AURA's capstone rather than minting a 53rd domain costs no id,
no card art, no clientfield and no pause plate, and prices it honestly at six picks on
one card with the cooldown as the rate limit. It calls
`zm_laststand::auto_revive( self )` — the stock function, six stock call sites.

A downed player is skipped by the healing branch on purpose: their health is not the
bleedout clock and stock zeroes their damage anyway (memory
`downed-players-take-zero-damage`), so healing them would do literally nothing.

### E.5 The FX

`zombie/fx_perk_quick_revive_zmb` — the Quick Revive machine's own aura. It is the
game's established "you are being healed" picture, it is a real 60,919-byte source
rather than one of the 298 five-kilobyte placeholders, and being a LOOPING effect is
exactly right on a `tag_origin` host that gets deleted after five seconds. That is the
`_tod_spire::king_flame_fx` lane; a bare server one-shot `PlayFX` would not draw at all.

Its `fx,` zone line is commented out with the other three until the class is enabled.

### E.6 The flags: five for one afternoon, now two (see D.1)

`MAGE_ART` in `tod_upgrade.lua` (default **false**) guards the mage's **tier cards**,
whose name is built at runtime (`"i_tod_card_tier_" .. TCLS[c] .. "_" .. t`). A
constructed name is invisible to `lint_tod_assets.js`, so nothing else stands between
an unzoned mage tier card and a white square.

It is deliberately **not** in lockstep with `TOD_MAGE_ENABLED`: it asks *"is the art
baked and zoned"*, which is a different question — a live class with no art falls back
to text and is merely plain. `build_map.ps1` asserts the one combination that is always
wrong, one-directionally: **art on with the class off** (3.4 MB of load RAM per card
for a class nobody can draft).

`AetheriumLoadout.lua` carries the same idea as `TOD_MAGE_ART` for the three staff HUD
icons, for the same reason.

**GATE A IS FLAG-BLIND, and this cost a build.** The class badge plate
`i_tod_upg_class_mage` was first written as a literal inside `if MAGE_ART then` — the
lint failed it anyway, because GATE A strips comments and ignores flags and only asks
whether a literal `i_tod_*` string has a zone line. A literal image name cannot be in
the file at all until its zone line is. The tier cards escape only because their name
is constructed, which is the *other* half of the same trap.

### E.7 What HEALING AURA still owes

- **It has never run.** Same standing as everything else in §B/§C.
- **Its four cards are requested, not shipped** — `docs/116_mage_class_art_prompt.md`,
  sent 2026-09-07 as `tod_mage_class_art_pack.zip`.
- **`docs/armory.html` owes a fifth row**: `mage_heal` 52, band A, max 6,
  `cls:["mage"]`, `scope:"class"`, `guns:null`.

## C. THE REVAMP (v18.30, 2026-09-07 night) — THREE STAFFS, NO STANCE

Everything above §C describes the stance-and-spells mage that shipped v18.20–v18.29
and was retired the same night. The user's spec, verbatim:

> *"I actually wanna completely revamp the mage ... It'll be the ice staff, fire
> staff, lightning staff ... three staffs for the mage, and you can switch through
> to fire them, which means we can get rid of the combat stance ... lightning will
> be good against zombies and hordes. Fire will be good against robots and the
> armor, and then the ice will be good against the hounds, the dogs, and the
> furies. And overall, the mage will be pretty weak against the Panzers."*
> Tiers: *"Lightning tier 1 / Lightning and Fire tier 2 / Lightning fire and ice
> tier 3"*; *"Healing can work for all staffs but it will be the aim down button"*;
> tiers are *"Stronger only"*; *"Drop wind entirely"*; spawn at tier 1 and earn
> the rest; fire cards from tier 2, ice cards from tier 3, lightning cards persist.

| | LIGHTNING (tier 1) | FIRE (tier 2) | ICE (tier 3) |
|---|---|---|---|
| stem | `tod_staff_lightning` | `tod_staff_fire` | `tod_staff_ice` |
| good against | the horde (x0.5 on any elite) | Rogue Protector, armored sprinter (x2, pierces armor) | hellhound, Fury (x2) |
| on hit | CHAIN LIGHTNING arcs (domain 53) | burn tell; ELITES burn 0.5%·Lv max HP / 2 s (v19.26) | ELITES ONLY (v19.26): slow 0.45x − 0.03/Lv, 1.0 s + 0.4 s/Lv |
| card | 53 CHAIN LIGHTNING (+1 arc/Lv, half hit) | 49 FIRE BLAST (+25%/Lv) | 50 ICE SHATTER (+15%/Lv) |

Every staff x0.4 on the Panzer. Tier multiplies every staff 1 / 1.5625 / 2.4414 in
script (`TOD_MAGE_TIER2/3_MULT`, lockstep with the generator's TIER_DPS; the fire and
ice rungs are emitted `flat: true`). HEALING AURA (52) is the AIM button on every
staff; ATTUNEMENT (51) is its recharge. AIR BURST (48) retired whole.

**Mechanics that had to change for an additive class** (`level.tod_classes["mage"]
.additive`): `give_class_loadout` gives every staff up to the tier; `tier_up` GIVES
the next staff instead of `swap_primary`; `has_gun` / `is_class_primary` /
`class_primary_in_inventory` accept any held staff (`class_stems`); the map now sets
`level.get_player_weapon_limit` (mage 4). The interface between the mage module and
the one damage chain is three guarded level pointers (`tod_mage_staff_mult`,
`tod_mage_staff_hit`, `tod_mage_pierce_armor`) — no `#using` in either direction.

**Engine limit, settled 2026-09-07:** there is no script-callable viewmodel
animation in this engine (stock scripts, the mod tools tree, map 1 and the binary
were searched). The only lane that plays the staff's fire animation is a real
trigger pull — which is exactly why the spells became the staffs' own shots.

**Open:** CHAIN LIGHTNING card art (docs/118); the freeze-gun hold pose (docs/117);
a lightning tip mesh; a crystalline ice shot sound. **UNPLAYED.**

### C.1 THE FULL STAFF KIT WAS ALWAYS EXTRACTED (v18.33, 2026-09-08)

§A.4 above says "24 images + 4 materials + 4 xmodels" landed — that is what was
carried into `source_data/`, **not what was extracted**. The user's Greyhound
export (`~/Documents/BO3_tools/Greyhound/exported_files/black_ops_3/xmodels/`)
holds the whole kit and always did: `tip_fire`, `tip_lightning`, `tip_water`,
`tip_air` (view + world + `_upg_world`), every `crystal_<elem>_view/_world`,
`parts_stem`, `parts_revive`, the `reload_<elem>` props and the `<elem>_prop_animate`
world props. **Look in the export folder before concluding an asset does not exist.**

Two naming facts, read off the files rather than guessed:
- Treyarch's element is **`lightning`**, never `elec`.
- **There is no ice staff in Origins.** The fourth element is **WATER**. This
  map's ICE staff wears `tip_water`.

**Models need NO Blender pass** (§A.2 already says this): Greyhound writes
`XMODEL_BIN`, which is the mod tools' own format. Only ANIMATIONS take the
`.seanim` -> Blender -> `export2bin` route in §A.5. Do not quote the animation
pipeline as a blocker for meshes.

Landed in v18.33: lightning and water tips wired to their staffs on both
`attachViewModel1` and `attachWorldModel1`, 16 GDT blocks cloned from fire's.
Still unwired and available if wanted: the four `crystal_<elem>` meshes and every
`_upg_world` head (a visible Pack-a-Punch, if the staffs ever get a packed form).


## F. THE CLASS IS FINISHED (v18.42, 2026-09-08)

User: *"Now we have the entire class done and finalized."* This section is the
settled contract — read it before changing anything above, because most of §B is
the design as it was BEFORE the revamp and several of its decisions were undone
the same night.

### F.1 The four buttons

| Button | What it does | Refusal |
|---|---|---|
| FIRE | the held staff's shot | — |
| WEAPON SWAP | change staff | you only hold what your tier has earned |
| **LETHAL** (`+frag`) | HEALING AURA | out of charges, or one already running |
| **TACTICAL** (`+smoke`) | BLINK | on cooldown, or no floor at the far end |
| **AIM** (`+speed_throw`) | ARCHMAGE | mana below 100 |

Both offhand buttons are free because `DisableOffhandWeapons()` is asserted on
arm and re-asserted at 5 Hz — the mage carries no grenades at all. ADS is taken
the same way, through `_allow_ads` AND `AllowAds( false )`, because
`enable_player_move_states` hands ADS back on every Pack-a-Punch and perk buy.

**The bind tokens in those HUD rows DO expand.** `[{+frag}]` in a
`NewClientHudElem` `SetText` is not the LUI lane and was worth checking rather
than assuming: stock `mp/killstreaks/_remotemortar.gsc:414` does exactly this
(`self.missile_hud SetText("[{+attack}]" + "Fire Missile")`).

### F.2 The domains — SEVEN as of 2026-09-08

⚠️ **COUNT THEM FROM `add_domain`, never from this table.** It has been wrong
twice: it said six for a day after MYSTICAL HANDS landed, and it gave BLINK band
A after it moved to B. `node tools/verify_armory_domains.js` prints the live
figure in a second.

| id | key | name | max | band | Gate |
|---|---|---|---|---|---|
| 49 | `mage_fire` | FIRE BLAST | 6 | A | tier 2 |
| 50 | `mage_ice` | ICE SHATTER | 6 | A | tier 3 |
| 52 | `mage_heal` | HEALING AURA | 6 | A | — |
| 53 | `mage_bolt` | CHAIN LIGHTNING | 6 | B | — |
| 54 | `mage_arch` | ARCHMAGE | 6 | S | — |
| 55 | `mage_blink` | BLINK | 5 | **B** | — |
| 56 | `mage_quickhands` | MYSTICAL HANDS | 1 | S | — |

**MYSTICAL HANDS IS NOT LIKE THE OTHER SIX.** It is not script at all — it is a
generated WEAPON AXIS (`axes1( "mage_quickhands", "q" )` on all three staffs in
`register_gun`), always dealt at ULTIMATE (`set_rarity_lock 3`), one level. So
it costs **three registrations**, and the ledger guard was raised 232 → 235 to
fit them. See §F.6.

Retired, ids still mapped per the retired-id rule: **48 AIR BURST** (v18.30, the
element became a staff and then was dropped entirely) and **51 ATTUNEMENT**
(v18.41, it only sold a faster version of what HEALING AURA already gives).

Only **MYSTICAL HANDS** is `set_no_dark()` — and **RAPID FLAME** (id 57, v19.25), which is not in this table. Every other mage domain carries a dark rung whose effect lane really reads `has_dark()`: CHAIN LIGHTNING +1 arc, FIRE BLAST / ICE SHATTER +50 points on the card multiplier (`TOD_MAGE_FIRE_DARK_ADD` / `_ICE_DARK_ADD` 0.50), HEALING AURA a seventh rung (`TOD_MAGE_HEAL_DARK_LV` 7), ARCHMAGE +0.50 / +4 s / +15% speed, BLINK a third charge.

### F.2b THE MATCHUP TABLE (v18.44) — the class's whole damage identity

|            | horde | robot / armored | hound / Fury | Panzer |
|---|---|---|---|---|
| lightning  | ×1.25 | ×0.45 | ×0.45 | ×0.40 |
| fire       | ×0.83 | **×1.75** | ×0.2625 | ×0.83 |
| ice        | ×0.80 | ×0.80 | **×2.85** | ×0.80 |

Read it out of `victim_family()` and the four `TOD_MAGE_*_FAMILY` defines, never
from this table — it has been rewritten once already.

Three things about it are load-bearing:

1. **The off-family penalty is the point.** Until v18.44 the off-matchup case was
   NEUTRAL, so there was no reason to swap back and one staff could carry a whole
   match.
2. **The Panzer arm is EXCLUSIVE.** Lightning OWNS him at ×4.76
   (`TOD_MAGE_LIGHTNING_VS_PANZER`); fire and ice take their own off-family value
   (×0.83 / ×0.80) instead of stacking a second penalty on top — ice's own staff
   nerfs still land after the arm. The universal ×0.40 was RETIRED in v18.56: it
   put every staff on ×0.16 against a Warden King at 10M HP per player, which is
   not "weak", it is "excluded", and v18.52 answered that by giving the Panzer to
   lightning rather than leaving the class with no right answer.
3. **Lightning's own family pays less than the other two.** Its reward is RATE —
   ~7 shots per fire-staff shot, plus CHAIN LIGHTNING. A ×2.00 there doubles the
   class's damage across most of the map and buys no extra decision.

One classifier owns all of it, so a new enemy type is one line rather than a
branch in every staff.

### F.3 The mana economy

0.8 mana a second, plus a per-kill share normalised by the round's zombie count (a fair-share round clear pays 32 at Lv0), cap 100. `ARCHMAGE` adds +0.25/s per level and +25%/level to the kill budget, so a maxed mage refills in about 44 s of standing still instead of 125. Mana does **not**
build while the form is running — the bar is the cost, and letting it refill
mid-transformation would let one bar buy two.

Spending it: ×2.0 damage for 15 s at level 0, ×3.2 for 27 s at level 6. **The
multiplier is latched at transformation time**, so a card taken mid-form cannot
change a fight already in progress.

⚠️ **THE MULTIPLY-NOT-ASSIGN TRAP (fixed v18.42).** `staff_mult` computed the
demigod multiplier and then ASSIGNED the tier multiplier over the top, so
ARCHMAGE did nothing above tier 1 for its whole shipped life. It hid because
tier 1 is the one tier that takes neither branch — and because `tod_dev_maxed`
spawns the tester at tier 3, which is where it was dead. Any future multiplier
added to that function must `*=`.

### F.4 The mana bar

It replaces the clip and reserve cells in the ammo bay for this class only
(`AetheriumLoadout.lua`), because a mage has no ammunition. Mint while filling,
gold and draining while ARCHMAGE runs — the form's own timer.

**It rides `LuiNotifyEvent`, not a clientfield.** The clientuimodel pool is at
its proven 61-bit ceiling with one bit spare and is append-only; 0..100 needs
seven, and overflowing that pool aborts the load to the lobby. Two ints: value,
and a state (0 filling / 1 archmage / 2 not a mage). Change-gated at 4 Hz, with
the gate dropped every 5 s because the ammo bay's widget lifecycle re-runs on a
death and would otherwise leave the bar blank against a server that believes it
already sent that value.

**The art is not in the code.** GATE A of `lint_tod_assets.js` is
comment-stripped and flag-blind and caught the first attempt correctly: naming an
unzoned image behind a `false` flag still fails the build, because
`RegisterImage` on an unzoned name draws a WHITE SQUARE rather than failing. The
bar is built from the flat slab until the drop can be zoned in the same build.

### F.5 What is still owed

- **Art: DONE v18.43** — all 26 files of `docs/120` installed and zoned. Still
  owed, and deliberately: the CLASS CARD and the two TIER cards, which the user is
  designing. The glyph, medallion and upgrade-panel plate are held with them —
  they work today, and they should follow whatever identity colour the class card
  lands on rather than being drawn twice.
- **Sound:** `docs/118` is written and unsent. BLINK and ARCHMAGE both play
  `tod_mage_stance_on` as a placeholder cue.
- **The hold pose** is still `vm_freezegun_*` (docs/117).
- **Everything since v18.37 is UNPLAYED** beyond the loads the user did during
  the build-out. Nothing in the mana / ARCHMAGE / BLINK chain has had a real run.
