# Upgraded staff head at the grip instead of the tip

## Third-person glow follow-up (September 27, evening)

User reports third-person stones stopped glowing and requests only that fix.
Restore the previous pass-2 scaleRGB 16 / orange and violet tints on world
fire/lightning crystals only. `build_staff_assembly.py::world_glow_assets`
clones the two retail materials and remaps only the crystal surface on each
world head. Two PaP world xmodel definitions reuse the existing packed binary;
the first-person PaP definitions retain their original materials. No mesh,
socket, animation, first-person glow, ice or gameplay changes. Regenerate the
GDT without rewriting binaries via `--world-glow`; full assembly generation
also preserves these overrides. PaP bindings remain generator-owned.

Source checks pass: presentation/retail/assembly gates, staff state tests and
dev preview tests. `tmp/staff_3p_glow_20260927/scope_diff.json` records exactly
two base world skin overrides, two world materials, two packed world model
definitions and two packed world binding changes. Existing preview log adds
`world_crystal_glow=16_world_only`; the archived user console shows the earlier
`base_tip_socket_3` build. Materials cannot prove visible glow from console logs.

**NOT BUILT / NOT PLAYED.** BO3 is running and the user explicitly answered
"I'm still playing". Do not build until it exits. A FULL build is required
(GDT edits). Re-snapshot inputs with `check_scope.py` in that evidence folder
before building, then verify source/deployed hashes, fresh FF, complete sound
banks and both new world model/material dependencies. User tests; no launch.

September 27, 2026. The user's 15:30 fire/lightning screenshots show a round
metal piece beyond the crystal. The initial reply misidentified the complaint
as the correct side blades/spikes. The user explicitly clarified: "Dark round
metal cap beyond the crystal." This is an assembly problem, not those parts.

## Evidence

BO3 reference images inspected:
- Fire: https://steamcommunity.com/sharedfiles/filedetails/?id=950070059
- Lightning: https://guiascodzombies.com/black-ops-iii/origins-bo3/baston-electrico-mejora-bo3/
- Upgraded fire: https://images.steamusercontent.com/ugc/12105797795301879396/BB2382A459FACEB80860CA6B76FD6FC584BAE111/

These show the shaft's upper mechanism behind the crystal/head. The screenshots
instead show the crystal/head close to the hand and the shaft's round upper
mechanism protruding beyond it. The actual local complete head contains no
extra sphere. Blender reconstruction of the shipping idle pose, shaft and
upgraded head shows the correct ordering when the head uses tag_tip. Moving
the head back by the shaft's 22.071-unit socket offset reproduces the large
foreground crystal and exposed mechanism in the user's screenshot.
See tmp/staff_edges_20260927/{full_assembly,firstperson_assembly,root_fallback}.png.
This is a strong visual diagnosis of native rigid-attachment root fallback;
the engine's transform itself has not been read from a running match.

CORRECTION after the next user playtest: the base view heads have multiple
animated bones, but their roots are NOT present in the shaft model. The old
claim that a blank socket safely merges them by name was not established.
Their compiled animation rig parents those roots under tag_tip; the weapon
definition must supply that same parent. See the base follow-up below.
The upgraded head has one bone and was routed through attachmentunique with
a BLANK first-person socket. The previous whole-head repair preserved that
blank binding. Its isolated geometry/count checks could not catch placement
relative to the shaft. Do not present triangle counts as proof of appearance.

## Correction

The two upgraded complete heads now have unique unkeyed roots
tag_tod_fire_packed_head / tag_tod_lightning_packed_head. Both view and world
attachments explicitly use tag_tip. This removes the default weapon-root
fallback and avoids double-transforming an animated head root. The PaP head
is rigid and follows the shaft socket; existing hand/shaft first-raise clips
remain unchanged. Base articulated heads retain their merge-by-name binding.
No vertex, UV, normal, crystal size, blade, spike, ice asset or combat value
changes. The earlier material-depth hypothesis is not the supported cause of
the metal part; retail crystal depth remains unchanged.

## Broader retail presentation audit

The user reiterated that the entire fire/lightning presentation must match
BO3. Comparison against the original t7_weapons.gdt exposed pistol donor
occlusion/gloss/camo maps on the shaft and heads, and glossRangeMax 17 instead
of 13. tools/restore_staff_retail.py restores every original material field
for the five metal surfaces and two crystals. The exact source fields and
source GDT hash live in docs/staff_retail_materials.json. All 28 referenced
textures were copied from Greyhound and pinned in staff_retail_manifest.json;
every duplicate source copy had the same hash. Original diffuse/normal/specular
maps remain the same images; their paths are now repository-owned too.

The pass-2 crystal brightness/tint boost is retired: scaleRGB 16 -> retail 8,
original fire/violet tints. Persistent fire/lightning emitter sizes are restored
from 125% to the original BO3 sizes. Ice effect recipes are unchanged from their
previous accepted settings. These changes supersede earlier requests for
boosted fire/lightning presentation in favor of the user's current retail goal.
Original hand-placement adaptations and map lighting remain; identical assets
do not establish pixel-identical native rendering. First-person upgraded heads
still use the original rigid upgraded world geometry (as before), not a newly
ported articulated upgraded viewmodel animation set. Do not claim that this
pass establishes exact retail animation parity.

Source gates require the explicit socket in both perspectives and the unkeyed
single-bone root. Existing dev preview INIT records staff_assembly=tip_socket_2.
The user's archived previous console confirms Mage T3 / 14 eligible caps /
missing=0, so class maxing is already proven for that played Mage session.

Full build OK September 27, 2026, 15:49:47 Eastern: FF 147,494,976 bytes.
All 1,408 recorded inputs match source and deployment, nothing synced after
the FF. Native DB verifies all seven restored material blocks and explicit
tag_tip sockets in both views. All six complete heads retain full geometry;
109/109 referenced weapon models linked; zero missing shaders; only the ten
established waived messages. Sound banks are complete (68,465,920 and
207,523,840 bytes). Evidence: tmp/staff_edges_20260927/build_final.log and
deployment_receipt.json. The initial pre-sync attempt caught a validator
checking the deployment before new repo-owned textures were synced; it now
accepts repository source textures and the successful full build deployed them.

User tests; no game launch. Native retest should check base and
upgraded fire/lightning, idle/equip/fire/reload, crystal position relative to
the shaft, and third-person preview. Do not certify native appearance from
the offline reconstruction alone.

## Base follow-up: attachment hierarchy (September 27, after user retest)

The user reports the base/PaP discrepancy remained. Archived console in
tmp/staff_base_20260927/logs/ confirms tip_socket_2 and preview cycles through
base/packed fire/lightning. It proves the earlier build was played, not the
position of the visible geometry. The earlier review covered the packed
attachment correction and did not validate the base runtime hierarchy.

Both base first-person attachViewModelTag1 fields were blank. In the actual
tod_vm_staff_elements_skeleton, tag_tip_fire / tag_tip_lightning are children
of tag_tip. They do not exist in the shaft itself. The original BO3 GDT also
attaches the articulated head at tag_tip (original slot4). Set that explicit
socket in the source weapons and all four fire/lightning handling variants.
Keep the animated head roots and children; do not rigidify the base heads.
Base world and packed view/world already specify tag_tip.

Earlier Blender renders applied global exported frame poses directly. That
assumes the correct hierarchy and therefore concealed a wrong runtime parent.
The new parent audit reconstructs head transforms from relative animation
tracks and the actual weapon socket: 24 clips / 821 frames for fire and 24
clips / 815 frames for lightning agree with the intended global poses to
under 1e-4 units. A blank parent demonstrably loses the shaft-to-tip offset.
This is an offline hierarchy check, not an observation of engine transforms.

verify_staff_presentation.py now compares the actual native model/animation
hierarchies against the declared socket, in addition to checking each emitted
weapon binding. Existing animation, material, head geometry, third-person,
and gameplay-routing gates pass. No geometry, animation, material, gameplay,
ice, or PaP binding changes in this follow-up. Dev INIT revision is
base_tip_socket_3. Full build initially refused safely because another map's
compile was active; the queued full build subsequently passed at 17:09:34 Eastern. FF 147,496,128 bytes; 1,408 source/deployed hashes match with nothing synced after the FF. Native DB confirms all six base weapon records and both packed sockets; six full-detail heads, 109 weapon models, zero missing shaders, complete 68,465,920 / 207,523,840-byte banks. No game launch; native visual retest remains with the user. Evidence tmp/staff_base_20260927/.
