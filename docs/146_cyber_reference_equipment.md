# Cyber reference equipment reconstruction

The newer Blender MCP reference-one Crown/shared-body and head conversion is
now built; see [docs/148](148_reference_one_game_model.md). Other roster designs
retain the revision-four assets described below.

Status: BUILT in the v19.17 publish build, 2026-09-16 10:36:04 Eastern
(FF 150,269,376 bytes, -CleanPak + all twelve languages). All five cyber
gates and the compiled-ledger coverage check pass. The native playtest is
still the user's: glow under map lighting, extreme poses, randomized
head/body combinations, severed limbs and horde frame rate are UNVERIFIED.
See docs/144 for the japaneseUnsafe flag decision the publish forced.

User references: `C:/Users/jorda/Downloads/CyberZombie1.png`,
`CyberZombie2.png`, `CyberZombie3.png`. They are visual references, not runnable
instructions. Original donor bodies, clothing and skeletons stay intact.

## Design mapping

- Crown and Signal: first sheet, asymmetric layered shoulder plates, cracked
  cyan optic, chest monitor, spinal cell, left arm/leg brace, thigh reserve.
- Trooper and armored sprinter: second sheet, paired chest cells, spinal
  vent housing, shoulder armor, both forearm and shin braces, jaw supports.
- Relay: third sheet, twin back reservoirs, raised welding visor, industrial
  hazard case, left arm and shin equipment.

The pictures are not source meshes. This is an editable reconstruction adapted
to the original zombie proportions, not a claim of pixel-identical recovery.
Original stock clothing/armor can occupy space that is bare in the references.

## Reproduction

`tools/cyber_reference_equipment.py -- <roster-id|mvp>` under Blender 4.2.
One-time revision-3 masters are kept in `tmp/cyber_finish_v3/` and every rerun
starts there. Each current master has `cyber_finish_revision=4` and its report
is `equipment_v4.json`. Geometry/weights signatures must match the donor.

Limb bands sample each actual donor; rays cannot pass through a torn hole to
the opposite wall. Missing angular spans are bridged between measured rims.
Shoulder shells curve around the upper arm. Original armor/spikes stay on the
sprinter, so its shoulder mounts start lower. New rigid equipment uses the
original head, spine, shoulder, elbow, hip and knee bones.

Materials separate chipped ivory paint, exposed dark steel, oxide, woven
webbing, aged rubber, magenta hose jackets, cyan cells and amber pilot lights.
Broad corrosion, directional abrasion and fine pitting are distinct scales.
The five native material channels bake from shader nodes to 2048-square maps.
Twenty-five maps replace the existing atlas names; no stock texture changes.

The final fit pass shortens harness tails above the original pouches, lowers the
welding shield onto the head, joins chest-cell supplies across the shoulder,
and tilts each rigid limb chassis along its measured sleeve-to-wrist taper.
This removes the bulky lower standoff produced by a bone-parallel brace on a
thin arm. Rubber pads keep their own dark bevel material. The first
and third designs also add wrist/finger plates, each using its original joint.
Every report records the authoring script hash and `fit_pass=3`.

## Anatomical export

`tools/cyber_equipment_layout.py` describes equipment regions. The original
damage variants sever at elbows and knees: shoulders and thigh cases stay on
the remaining body; forearm/shin gear goes with the detached native limb.
Installers preserve original object tables, skeletons, geometry and weights.
Leg-loss models now need binaries too, because they retain fitted hip gear.
Matching right-arm/left-leg/right-leg gibs are added where the design needs them.

Read-only source inspection confirms the body-2 two-leg-loss donor retains
z15.83..41.59 geometry; the hips are still present. The upper-body arm-loss
models retain the shoulders. `test_cyber_equipment_layout.py` protects these
anatomical distinctions separately from binary source preservation checks.

Head randomness remains shared across the original four character slots;
native combinations can mix the reference head kits with different bodies.
The sprinter retains the head/helmet of the zombie promoted into it. The
gallery is five representative full-body assemblies, not an enumeration of
every native randomized head/body combination.

Gameplay, health, AI, collision and animation definitions are unchanged.
Source checks and native triangle coverage must pass before the final build
is called ready. Blender attachment pose checks are not a native playtest.

## Detail and remaining playtest checks

The baked equipment atlases total 25 maps at 2048 x 2048. Added equipment
geometry is substantially denser than revision 3. Counts below exclude the
stock zombie meshes and cover each complete exported kit:

| Kit | Nearest detail | Distance LOD 3 | Farthest authored detail |
| --- | ---: | ---: | ---: |
| Crown | 34,966 | 4,845 | 1,288 |
| Trooper | 54,842 | 7,611 | 1,660 |
| Signal | 36,878 | 5,111 | 1,340 |
| Relay | 35,034 | 4,866 | 1,004 |
| Sprinter | 50,744 | 7,043 | 1,574 |

The sprinter body and detached limbs inherit native automatic distance
reduction; regular body/head assets use the seven authored levels. Source
validation covers all 233 authored binaries, including every original vertex,
face, bone, normal, UV and weight. The exported Crown model was also rendered
with its actual baked atlas to check conversion appearance.

The user handles the native playtest: check glow under map lighting, extreme
arm/head poses, randomized head/body combinations, severed limbs, and horde
frame rate. A successful conversion/build does not establish clip-free motion
or measured runtime performance. No game launch is authorized for this pass.
