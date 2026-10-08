# Staff Pack-a-Punch models and first-equip flourishes

2026-09-21. User clarified that "inspect" means **first-equip flourish**.

## Assets found and implemented

- Fire/lightning: `wpn_t7_zmb_hd_staff_tip_{fire,lightning}_upg_world_LOD0`
  from the user's `Downloads/T7 Assets V2.7.rar`. These are separate, wider
  upgraded head meshes in the same local +X coordinates as the existing heads.
  Reuse their existing materials. First-person animation positions the head;
  the third-person attachment uses the shaft's `tag_tip` socket.
- Fire/lightning: original `vm_zom_staff_t7_{fire,lightning}_upg_first_raise`
  binaries in the test-map export. Converted using the approved arm placement,
  detached-head coordinate correction and elbow repair. Existing base clips,
  firing/reload poses and sound aliases remain in use.
- Ice: the BO6 export's upgraded appearance is its four tip blades opened by
  `t10_vm_ww_staff_upg_idle`, not the cosmetic `dreward` model. The original
  BO6 assembly is split at `tag_barrel_attach`; its tip has normal and opened
  models in both perspectives. Vertex positions, materials, UVs, weights and
  every triangle of the base assembly reconstruct the installed original.
- Ice: sample the four blade quaternion curves from BO6's normal/upgraded
  `first_raise` clips onto the existing first-equip timing. These are adapted
  weapon motions on the approved Origins hand motion. **No claim of porting
  BO6's arm animation**: its viewhands rest skeleton is absent from the export.
  Only the relevant arm/camera and BO6 bones enter the new conversion skeleton.

## Runtime routing

`gmod6` is a stock neutral attachment. Per-staff `attachmentunique` definitions
replace the base head and first-raise clip. Native database defaults would add
4x head/5x neck multipliers, so both definitions explicitly retain the emitted
weapon's existing location multipliers (including headshot normalization) and
zero the legacy bullet-range overrides. Ammo and handling remain inherited.
All handling/perk variants share each element's presentation table. This
feature adds zero weapon registrations. Concurrent balance work added the ice
Double Tap axis, so the current roster has eight staff variants; the presentation
checks and inventory regression cover those variants too.

`_tod_classes::staff_presentation` resolves the owned staff's PaP tier. Pack I
selects the upgraded head; II/III retain it. Paid PaP resolves after the weapon
has been taken for the machine presentation, then grants it directly rather
than passing through stock GetBuildKitWeapon. Free-PaP reconciliation compares
weapon objects including attachments. A same-root replacement takes first to
avoid deleting the newly attached weapon; different-root handling swaps keep
their previous order. Respawn/loadout and tier grants retain the returned
attached object for ammo and equip calls. New acquisition/PaP return requests
the flourish; handling changes preserve the presentation without requesting it.
Ability re-equip continues using the actual held weapon and preserves ammo.

Dev mode automatically emits `[TOD_STAFF_PAP]` on give, completed swap, PaP
return and held-weapon changes: player, root, per-staff tier, actual gmod6
presence and first-raise request. A missing attachment logs once per root and
keeps the existing weapon. These record routing, not proof of rendered motion.
Dev/god settings are not enabled by this feature.

## Regeneration and checks

`tools/build_staff_presentation.py` generates private binaries/GDT and a hash
manifest. Original source paths and hashes are recorded in
`docs/staff_presentation_manifest.json`. Generation requires the user's local
T7/BO6 exports, PyCoD and BO3 export2bin; ordinary map builds require only the
vendored outputs. `--ice-clips-only` regenerates the adapted ice clips/rig.

`tools/verify_staff_presentation.py` runs automatically through the existing
staff build gate. It checks hashes, bindings, neutral attachment fields, sound
notes, registered weapon count, skeleton limits and linked dependencies.
The original 78 approved clips and BO6 assembly remain hash-pinned separately.

Passed before build:

- `python tools/audit_staff_presentation.py`: binary mesh completeness,
  triangle/material/weight integrity, base assembly reconstruction, movement
  restricted to blade geometry, unchanged ice hand/flash positions, elbow fix.
- `node tools/test_staff_presentation.js`: actual GSC routing under a native
  mock, all elements/handling/tier combinations and ice Double Tap changes, independent PaP ownership,
  free-PaP and handling swaps, ammo preservation, downed PaP return, missing
  attachment fallback. This is not native engine playback verification.
- Existing ability re-equip, staff HUD identity, fire cadence and asset checks.

## Build result

The shared full build completed at **2026-09-21 10:17:04 Eastern**. Its final
isolated linker pass wrote the 146,217,856-byte fastfile at 10:14:36. The
preserved build receipt, geometry transcript and linker output are in
`tmp/staff_pap_20260921/final_shared_*`; `final_build_evidence.json` records the
exact fastfile hash. Earlier staff-task build logs were interrupted or failed
during concurrent work and are not the success evidence.

`deployment_verification.json` records the completed package: **27 staff
assets** (8 models, 4 clips, 6 unique attachments, 8 weapon variants and the
stock attachment), all **293** checked source hashes matching deployment,
no deployed input newer than the fastfile, and a **207,523,840-byte** sound
bank. The final link has only the ten existing waived errors and no unexpected
errors. The native database audit confirms all six unique definitions retain
the emitted 3x head/neck multipliers and inherit first-raise timing. Inventory
and ability re-equip checks also pass against the latest shared scripts.

A separate session began another full rebuild at 10:18, after this successful
build. Its sync removed the generated asset ledgers, so the preserved 10:15
deployment report is the evidence for the completed package. The exact
fastfile hash and all source hashes were checked again afterward and still
matched. Wait for any active build before playing.

Dev/god/test flags remain off. Build evidence and audits:
`tmp/staff_pap_20260921/`.

## 2026-09-23 status: it never rendered, and the fourth requirement

The user played it: base and packed staffs identical. Their console shows the
routing above working exactly as written and the ENGINE refusing the
attachment: `[TOD_STAFF_PAP] ... tier=1 packed_attachment=0 ERROR missing gmod6
presentation`. The Sep 21 build evidence proved the assets were packed and the
bindings resolved in the source database; nothing checked what the linker
connected to the weapon, and the answer was nothing.

The linker's dependency file (`usermaps/zm_tower_of_doom/zone_source/all/
assetinfo/zm_tower_of_doom.deps`) is the only artifact that says so. In the
2026-09-23 15:27 build every `weaponfull,leviathan*_zm` reads
`attachmentmappingstable.csv` and pulls its gmod7 attachment + both uniques;
every `weaponfull,tod_staff_*` reads the same table and pulls only the bare
weapon. The staffs were the map's only weapon assets without the engine's `_zm`
tail. Stock connects gmod6/gmod7 uniques to projectile weapons too (launchers,
crossbow, discgun - all `_mp`/`_zm`-named), so the GDF type is not the gate:
the linker derives its mapping-table key from the mode tail, and a name
without one never matches its own row.

**Fix (v19.41):** the 8 staff variants are emitted as `tod_staff_<el><suffix>_zm`
(gen_tod_twins.js mage block). Script, CSV, HUD and mapping-row names stay
unsuffixed; `verify_staff_animations.py` strips the tail. The linker half is
proven when the new `.deps` shows `weaponfull,tod_staff_fire_q1_zm` pulling
`gmod6`, `au_tod_staff_fire_gmod6` and `au_tod_staff_fire_none`. The runtime
half (the engine composing the packed head in hand) remains the user's test;
it is unproven for every weapon in this map, the hammer included.
Native visual acceptance remains the user's playtest: acquire each staff,
Pack I, switch away/back, Pack II/III, then change Mystical Hands; confirm heads
stay attached and the first-equip flourish ends in the expected resting pose.
Check third-person models with another player when available. Do not launch
the game to perform this checklist unless the user explicitly requests it.
