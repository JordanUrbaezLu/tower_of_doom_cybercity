# 117 — The staff viewmodel animations: why they exploded, and how to get them

## Migration authorized — 2026-09-08

**Instant aura follow-up:** Fire particles remained briefly on ice after a
swap. The old client code used a replicated element callback, a 0.4-second
settle timer, and StopFX. Replaced that with the stock client on_spawned /
weapon_change pattern (see `_zm_weap_riotshield.csc` and
`_zm_weap_raygun_mark3.csc`). KillFX destroys the old handle's live particles
before PlayViewmodelFX attaches the new element, with no scheduled delay.
The client event supplies the actual weapon; q0/q1 changes replace even the
same element. Nonstaff switches clear the handle. Death, disconnect and
entity shutdown clean up; respawn replaces any existing watcher. Local-player
guards retain split-screen/spectator isolation. The server's two-bit field
registration stays in sync but has no presentation callback, preventing late
snapshots from restoring stale FX. Native signatures were checked against
local Mod Tools docs and stock CSC. Requires in-game rapid fire/ice/lightning
swaps and Mystical Hands swaps to verify the engine's viewmodel attachment
at the event; compile success alone does not establish frame-perfect timing.

**Playback follow-up:** User requests firing to interrupt the retained reload
animation and reports sprint motion freezes after one cycle. Enabled native
`segmentedReload` for all three source staffs and all six q0/q1 twins. Retained
reload clips, 1.5s reload duration, clip-only ammo, zero reserve, and the existing
empty/zero-time reload-end configuration. This uses the engine's segmented
reload interruption path, without a scripted weapon swap or ammo grant. Must
verify actual fire-button interruption in BO3, including early/mid reload and
holding/releasing the trigger; the offline field check is not a runtime test.

The three imported sprint-loop assets were explicitly `looping=0`. Set them
to 1 and made the importer preserve that setting. Each source contains 31
frames at 30fps, with 6.278 units of hand movement and matching first/last
positions and rotations. The clip was not missing motion: playback stopped at
its last frame. Sprint entry/exit and weapon timings are retained. The build
validator now checks looping and retained/interruption-enabled reloads on
all six twins. Local APE definitions: `deffiles/xanim.awi` looping tooltip and
`deffiles/projectileweapon.awi` reload options/timing definitions.

Full build for glow + reload + sprint completed 2026-09-08 23:07:03.589139
Eastern. FF 172,209,344 bytes; newly generated all.sabs 174,624,640 bytes
at 23:06:38. 222 inputs match the captured build snapshot, repository and
deployed assets, and predate the FF. All 78 clips, six twins and three glow
FX (87 required assets) appear in the linker asset list. Staff scripts compiled.
Besides established waived warnings, linker reported an unrelated Enfield
shot2 WAV source-checksum warning. The source exists and parses as 48kHz stereo
PCM; the bank regenerated successfully, but that sound was not auditioned.
In-game aura timing, reload interruption and sustained sprint remain unverified.

User accepted the remaining staff tests and requested Tower migration, while
reporting wing-like fire-head geometry when shooting. Earlier claims that the
side-piece rotations were acceptable are superseded by this visual feedback.
The test converter now holds all six fire-head children in actual model bind
shape under the moving head root. Pinning only the terminal pieces still left
4.614 units of shot deformation from their parent pivots, caught offline; the
whole-head fix passes every-vertex checks across hip-fire, ADS fire and hold.
Hand/shaft motion and recoil remain animated. Ice and lightning retain their
approved motion, including the repaired lightning branch translation origins.

`tools/import_staff_animations.py` vendors 78 unique clips plus their conversion
skeletons into Tower-owned directories and `tod_staff_approved_anims.gdt`.
It replaces only 45 animation slots in each `tod_staff.gdt` source weapon,
then regenerates q0/q1 through the existing twin generator. All 207 generated
weapon names and every non-animation field are compared before/after. The
ledger remains 207+28=235. Test ammo, test weapon definitions and test scripts
are not imported; Tower already owns persistent glows. Existing handling
timings, damage, ammo, PaP and class behavior are retained.

`docs/staff_approved_manifest.json` records dependencies and source hashes.
`tools/verify_staff_animations.py` gates every Tower build: hashes, all 78 clip
definitions/dependencies, all six twins/45 slots, and the 3x Mystical Hands
timing relationship. Sync copies the two owned asset directories without
mirroring shared installed assets. Tower builds no longer depend on test+map.
Re-importing requires that test repository; ordinary builds do not.

The test A controls are frozen in `test+map/docs/staff_tower_original_reference.json`
so future test regeneration cannot silently give A Tower's newly migrated
animations. Test sources contain the fire fix, but its installed test build
still predates this correction. Full Tower build completed; runtime appearance
of the fire fix still requires playtesting. The user's migration authorization
is satisfied and must not be requested again.

Full-build blocker found during migration: `tod_staff_origins.gdt` declared
the shared `i_generic_lookup` as `diffuseMap`. The linker explicitly requires
`revealMap` for `flickerLookupMap`; the wrong type invalidated the existing
PaP screen and `wc/mwiii_vertigo_retro_synth_pap` techniques and the linker
crashed before producing a sound bank/fastfile. Corrected the image semantic
in both Tower and test sources, preserving the image pixels. The staff build
validator also guards this type. The full rebuild included this repair.

**Build completed:** 2026-09-08 22:20:35.043322 Eastern, full BSP/navigation/LED
and linker passes. Fastfile 172,209,792 bytes; all.sabs 174,624,640 bytes. All
78 migrated animations, six staff twins and three glows verified in the fresh
asset list. 222 deployed script/zone/UI and staff asset sources match and
predate the fastfile. Shared-lookup failure cleared; only the build script's
existing waived warnings remain. Log:
`%TEMP%/tod_staff_migration_build_fixed_lookup.log`. Launch Tower's existing
PLAY_NORMAL.bat. Migration complete; final fire correction awaits in-game test.

## Historical testing notes

**Follow-up:** test+map/docs/28 fixes a different source-space convention for
fire/lightning heads (the forward offset was being applied twice) and adds the
same persistent glows as Tower. Models/attachment fields already match Tower.
Build pending game closure; no animation migration yet.

User approved ice and requested fire/lightning tests, then Tower migration if
both look good. test+map/docs/27
records the new comparisons using the same attachment/placement conversion.
Test build verified 20:49:14 Eastern; fire/lightning visual approval pending. Tower animation migration
is authorized only after that confirmation; ice approval is already satisfied.

**Current status 2026-09-08:** R5 arm repair confirmed; explicit tip tag lost the
head. R6 never built. User requested Tower's actual ice staff in test+map with
the staff animation set. Current ICE A/B comparison uses the exact Tower models
and blank attachment tags; B has 30 staff clips, retains the elbow repair, and
was initially equipped. User reports B incorrect and hold-melee failed. Follow-up
starts on unchanged A and restores press/release melee switching. Model audit
passed. User now confirms A complete and comparison switching working. B idle
has a misplaced cradle and missing-looking base; test+map/docs/25 corrects the
head's doubled bind translation in idle only. User reports closer idle but
equip/fire still displaced. Current test+map/docs/26 applies the attachment
correction to all full poses and matches A's resting placement. Test build
verified 20:31:05 Eastern; visual verification pending.
Historical investigation follows. The shipped Tower wears the
`vm_freezegun_*` animations, which render correctly and feel like a gun. This doc
is the plan for replacing them with the real Origins staff set.

User, 2026-09-07: *"can you start looking into how to get those staff animations?
We really need those … maybe you can use a test map as a test … maybe you can
implement certain different ways, and I can cycle through staff to see which
animation looks the best."*

---

## A. What actually went wrong

**Not scale, and not missing assets.** All 20 converted `vm_zom_staff_*` anims
were packed and referenced — 20 of 20, verified in the linker's own asset list.
The mesh still tore into flat shards, which is the signature of vertices being
transformed by the *wrong bones*.

**The decisive evidence is the `model` field on the xanim block.** A BO3 viewmodel
animation declares the skeleton it was authored against:

| animation set | binds to | result |
|---|---|---|
| `vm_freezegun_*` (works) | `weapons_t8\freezegun\wpn_t8_zmb_freezegun_skeleton.XMODEL_BIN` | renders |
| `vm_zom_staff_*` (ours) | `sla\tod_staff\tod_staff_skeleton.xmodel_bin` | explodes |

Both are `type "relative"`. The difference is that Treyarch's is a **real
shipped weapon skeleton** and ours is a **synthesized union rig** — assembled by
appending a bone set to an arms model because no single exported model carried
both the viewhands and the staff tags.

**And `tod_staff_skeleton` is not obviously broken**, which is why this needs an
experiment rather than a guess. Its hierarchy opens exactly as a BO3 viewmodel
rig should:

```
BONE 0 -1 "tag_view"      BONE 3 1 "tag_torso"
BONE 1  0 "tag_ads"       BONE 5 3 "j_shoulder_le"
BONE 2  0 "tag_cambone"   BONE 7 3 "tag_weapon_left"
```

So the top of the tree is right. The fault is further in — the most likely
candidates, in order:

1. **Bone ORDER.** SEAnim bone order is not rig order. If any stage of the
   conversion matched by index rather than by name, every transform lands one
   bone off and the mesh explodes exactly like this.
2. **The 37 dropped `j_sleeve*` bones.** Option B (2026-09-07) deliberately
   dropped Origins' coat-sleeve jiggle chain. Dropping a bone is safe only if
   nothing downstream is index-addressed — see (1).
3. **animType.** The set carries four different semantics (64 absolute, 4
   additive, 29 relative, 48 delta). Treating an additive or delta clip as an
   absolute pose compiles clean and animates wrong.

---

## B. The thing that changes the plan

**Real Origins-family viewhands are ALREADY on disk**, in the mod tools, with no
Greyhound session needed:

```
model_export/wawmodels/c_t7_zm_dlchd_nikolai_waw_viewhands_LOD0.XMODEL_BIN
model_export/wawmodels/c_t7_zm_dlchd_richtofen_waw_viewhands_LOD0.XMODEL_BIN
model_export/wawmodels/c_t7_dlchd_dempsey_waw_viewhands_LOD0.XMODEL_BIN
model_export/t7_characters/viewmodels/c_t7_mp_warrior_viewhands.XMODEL_BIN
```

`dlchd` is **DLC HD — the Zombies Chronicles remaster**, the same asset family
the `wpn_t7_zmb_hd_staff_*` models and the `vm_zom_staff_*` animations came from.
So the correct bind rig is very likely already here, and the earlier synthesis
may simply have been unnecessary.

Real weapon skeletons ship too (e.g. `wpn_t7_knife_combat_skeleton.xmodel_bin`),
which give a second reference for what a correct one looks like.

---

## C. The experiment — build several, let the user pick

This is the user's own suggestion and it is the right shape, because the failure
is cheap to see and expensive to reason about. **In `Repositories/test+map`**, not
in the tower.

Build **one staff weapon per candidate bind rig**, all sharing one model and one
`.seanim` source set, and give the player a way to cycle between them. Each is a
weapon def clone — the same 1284-field clone already proven — differing only in
which xanim set it names.

| # | bind rig | what it tests |
|---|---|---|
| A | `c_t7_zm_dlchd_richtofen_waw_viewhands` | the Origins crew rig, HD family |
| B | `c_t7_zm_dlchd_nikolai_waw_viewhands` | ditto, second crew member |
| C | `c_t7_mp_warrior_viewhands` | the generic T7 viewhands |
| D | `tod_staff_skeleton` **with sleeves kept** | isolates cause (2) |
| E | `tod_staff_skeleton` as-is | the control — known-bad, proves the harness shows a difference |

**E is not optional.** A harness where every variant looks wrong teaches nothing
unless one of them is *known* to be wrong.

Cycling: `_sla_weapons::dev_give_staff` already exists and is dev-gated. Extend
it to take an index and give staff N, bound to a key — the user cycles in-game
and reports which reads correctly.

---

## D. The cheaper check to run FIRST

Before building five variants, run the **oracle** that already exists: 17 staff
animations ship as Treyarch `.XANIM_BIN` in the mod tools
(`ai_zm_dlc5_zombie_*staff*`). Convert those from their own source with the same
converter and diff bone-by-bone against the shipped files. Near-zero drift proves
the converter; large drift on specific bones names the broken stage.

That was measured once at median 0.0053 units / 0.412° over 146,200 samples — but
that run validated the **converter maths**, not the **skeleton binding**, which is
where the failure actually is. The oracle needs re-running with the bind rig as
the variable.

---

## E. What is NOT the problem

Ruled out with evidence, so nobody re-investigates them:

- **Missing anims** — 20 referenced, 20 packed.
- **Missing models** — both staff viewmodels packed and rendering.
- **The weapon def** — diffed field-for-field against the working test-map def;
  only damage fields differed (`locHead`, `locNeck`, `meleeChargeRange`,
  `startAmmo`), none view-related.
- **Scale** — a scale error produces a large intact staff, not shards.


---

## F. The harness, as built (2026-09-07)

User: *"Build it out on test+map. You can add a station that cycles through."*

**In `Repositories/test+map` — ShadowLight Arena. Nothing in the tower changed.**

`source_data/sla_staff_animtest.gdt` — 5 weapon defs + 30 xanim blocks, generated
by cloning the def that RENDERS (`sla_staff.gdt.pre_staff_anims`, 1284 fields) and
overriding only `displayName` and the six judged animation fields.

**Press MELEE in game to cycle.** `_sla_weapons::animtest_station`, dev-gated,
takes the previous variant back before giving the next (five staffs at once would
trip the stock too-many-weapons monitor, which CONFISCATES a primary rather than
refusing it) and prints the rig name on every step.

| variant | bind rig |
|---|---|
| A | `c_t7_zm_dlchd_richtofen_waw_viewhands_LOD0` |
| B | `c_t7_zm_dlchd_nikolai_waw_viewhands_LOD0` |
| C | `c_t7_dlchd_dempsey_waw_viewhands_LOD0` |
| D | `c_t7_mp_warrior_viewhands` |
| E | `tod_staff_skeleton` — **the known-bad control** |

**E IS NOT OPTIONAL.** If E does not visibly explode, the harness is not
exercising the variable and nothing A–D show can be trusted.

**Only six animations are swapped** — idle, fire, raise, first-raise, sprint-in,
sprint-loop. Every other slot keeps its working freezegun animation, so a bad rig
breaks only what is being judged and you can always cycle away from it.

### What the build already told us

All 30 xanims converted with **zero errors** and all five weapons packed. So every
candidate skeleton RESOLVED — the failure, if it persists, is in how the bones
match, not in whether the rig exists. That rules out "the path was wrong" before
a single frame is looked at.

### The escaping trap this hit

A GDT path is **double-backslash** separated — verified in raw bytes in both the
stock freezegun GDT and our own converted set. The first generated pass emitted a
single backslash on `model` (correct on `filename`, wrong one line below), which
would have failed to resolve silently. Paths are now written with forward slashes
in the generator and converted once at emit time.


---

## G. ROUND 2 PLAYED — and it was the useful kind of failure

User: *"yes A looks good and the rest look horrible. They always block my face
like im looking inside of something."*

A good, **B C D E all bad**. That is a clean, decisive result even though every
hypothesis in it was wrong:

- **The bind rig is not the cause.** B (richtofen) and C (synth) both failed, and
  D (synth) and E (richtofen) both failed. Swapping the rig changed nothing.
- **`looping` is not the cause.** B and C carried `looping "0"` and still failed.
- **The harness itself was sound.** A (the known-good reference) looked right and
  E (the known-bad control) looked wrong, exactly as predicted. The rig WAS being
  varied; it just isn't what matters.

Four variants failing *identically* is the tell: the real cause was a **constant
across all four**, so no amount of varying rig or looping could ever have found
it. That is the lesson to keep — when every arm of an experiment fails the same
way, stop varying and start looking for what they share.

## H. Round-3 hypothesis — `useBones` must be 0 on a viewmodel animation

`xanim.gdf` names the field **"Use Bones (Not viewmodel)"** and its own tooltip
reads: *"??? Not needed for viewmodels, but is needed for practically everything
else."*

Across the **entire** mod tools install, only four GDTs define `vm_*` animations:

| GDT | `useBones 0` | `useBones 1` |
|---|---|---|
| `wpn_t7_zmb_bow.gdt` — Treyarch, Der Eisendrache bow | **40** | 0 |
| `wpn_t8_zmb_freezegun.gdt` — Treyarch | **28** | 0 |
| `tod_staff_anims.gdt` — ours | 0 | **64** |
| `sla_staff_animtest.gdt` — the harness (clones ours) | 0 | **24** |

**Treyarch: 68 of 68 viewmodel anims are 0. Ours: 88 of 88 are 1.** No exception
on either side. And the split is not "Treyarch always writes 0" — in that same
freezegun GDT the five `ai_zm_dlc5_zombie_freeze_death_*` **world** anims are all
`useBones 1`. The field tracks viewmodel-vs-world exactly as the tooltip says.

**Beware the whole-folder count.** Scanning all 227 GDTs first gives "vm_*: 68
zero vs 88 one", which looks like no pattern at all — until you notice all 88 of
the ones are *our own two files*. Aggregate the wrong population and a perfect
signal reads as noise; break it down per file.

Symptom match: `useBones` on a viewmodel anim drives the full skeleton instead of
the viewmodel set, so bones the view rig has no place for get transformed anyway
— the mesh ends up wrapped around the camera. The user's *"like im looking inside
of something"* is literally that: you are inside the geometry.

Note also that the linker's earlier `delta` complaint — five root bones
(`tag_camera`, `j_shoulder_le`, `j_shoulder_ri`, `tag_weapon_left`,
`tag_weapon_right`) — is a **symptom of the same thing**, not an independent
problem. Those are exactly the bones a viewmodel set should not be driving.

### The fix

All 64 blocks in `tod_staff_anims.gdt` set to `useBones "0"`, applied per-block
so only `vm_*` names are touched, in all three copies (both repos and the shared
tools root — GDTs are last-sync-wins across maps).

**No generator to fix.** `tools/make_anim.py` hardcodes `useBones "1"`, but it
writes `sla_anims.gdt` and clones an AI robot walk — 1 is *correct* there. The
staff blocks came from a one-off script that no longer exists, so the GDT is the
source of truth and was edited directly.

### Round 3 harness — MELEE cycles, in ShadowLight

| | variant | expected |
|---|---|---|
| A | freezegun reference | right |
| B | **`useBones 0` + synth rig** | **the fix** |
| C | `useBones 0` + richtofen rig | should also be right |
| D | `useBones 0` + `looping 0` | tests whether looping matters *too* |
| E | `useBones 1` — exactly what shipped | **wrong** (the control) |

If B is right, the rig was never the problem and the synthesized
`tod_staff_skeleton` is fine — which retires section A's hypotheses (1) bone
order and (2) the dropped `j_sleeve*` chain along with it.

**The tower is untouched by all of this.** `zm_tower_of_doom` still names
`vm_freezegun_*` in `tod_staff.gdt` and does not zone `tod_staff_anims.gdt` at
all, so nothing here can reach the production build.

## I. Round 3 failed; round 4 tests actual pose assembly (2026-09-08)

User confirms B/C/D/E all looked bad and authorizes continued testing in
`Repositories/test+map`. Section H's setting is appropriate but its root-cause
claim was not established; the original symptom explanation is a hypothesis.

Binary inspection finds concrete assembly errors: the union skeleton retains
the donor character's view origin at z=64.32, while the camera-space staff clip
omits torso/cambone parents; the staff root is at zero while its hand anchor is
at (21.291,-6.759,-5.565); `tag_flash` belongs to the donor pistol slide;
`tag_tip` and the fire tip inherit from a world-prop origin. The actual staff
view meshes supply different parents. No fresh export needed for the test:
68 first-person staff SEAnim sources and all 64 existing converted clips are
present, with all model/animation paths resolving in Mod Tools.

New reproducible test: `test+map/tools/staff_anim_round4.py`; full details and
interpretation in that repo's `docs/21_staff_animation_round4.md`. Five existing
weapon registrations reused: A freeze gun, B missing-parent tracks, C assembled
view rig and weapon poses, D same hand motion with rigid staff parts, E old
conversion. Eight actions plus empty/quick aliases. Labels start **R4**; melee
cycles. New conversions get isolated names; original clips remain untouched.
The generated C/D poses pass finite-position, unit-axis and attachment-anchor
checks. Full build and user visual test are tracked in docs/21. Tower weapons
remain on the freeze-gun set until a staff candidate is visually confirmed.
