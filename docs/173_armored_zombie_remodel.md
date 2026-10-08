# Armored zombie remodel — October 7, 2026

Current request: remove the back tank; extend the mask into a helmet that covers
the head; make the red eye strip brighter and the armored zombie easy to spot.
Retained requests: 33% larger model, full sword forearms beginning at the elbows,
30% larger rear spikes, distinct arms-down walk, detailed editable Blender model.
Latest request: retain the new movement and make the whole armored kit consistent.

## Current model

Master: `art/cyber_reference_three_mcp/reference_three.blend`, open in Blender.
`tools/cyber_references/three_helmet_review.py` applies/reviews the new head without
recreating the retained torso/limb equipment. `three_helmet.py` builds a connected,
double-wall graphite executioner helmet: closed crown, complete side/back coverage,
folded jaw/brow ridge, narrow continuous optic, temple cooling cassettes, captive
screws, rear exhaust and a small riveted MK33 repair plate. The lower neck remains
exposed. There is no separate raised welding shield or forehead ornament.

`three_armor_finish.py` unifies the helmet, sword plates and body armor with shared
worn gunmetal, cold abraded steel edges, blackened fittings and aged black hoses.
They share the same oily staining, brown oxidation, forging relief and directional
scratches. The bright magenta upper-arm hose becomes dark industrial rubber;
small cyan/amber status lamps and faded hazard markings remain secondary accents.
The red optic is the main light accent. The torn suit, flesh, rusted stock spikes
and all original donor materials remain intact. Finish metadata is checked across
the head, both elbows and the torso before export/promotion.

`three_remove_backpack.py` retires all 489 tank, frame, feed, lifting arch, manifold,
mounting-foot and cantilever objects. No tank-support hardware floats on the back.
The 14 dorsal/collar spikes remain enlarged 1.30 at fixed roots; their 520 changed
vertices match the pinned native source operation. The old pressure-vessel
standoff/clearance policy is superseded by `no_pressure_pack_v1`.

Red aperture strength 14 replaces 3.5; the thinner central line uses strength 16.
The emitter is uniform and connected across the front fold, with no dark nose
divider. Atlas bake range and the sprinter material's `scaleRGB` are both 16.
Other lamps retain their authored strengths; other roster material ranges stay 6.
This increases the eye contribution without multiplying all body lamps. Actual
native fullspec `include/emissive_base.techsetdef` binds `scaleRGB` to `hdrScale`
under its Emissive category; it is the emission multiplier, not the diffuse tint.
Actual source UV/atlas samples reconstruct at least 13.292 red radiance across all four
eye spans in each of the seven authored head LODs. Native lighting/bloom remains
the user's playtest; source radiance is not a measured in-game screen brightness.

The largest connected head component (the enclosing helmet shell) remains exact
through every authored head LOD. Lower-detail versions reduce small fittings;
they cannot shrink or puncture the helmet around the retained skull. The same
gate checks shell positions, UVs and normals and the actual baked red eye samples.
Native source-binary enclosure checks cover all 21 head variants/distances.

The master has 805 editable equipment objects / 229,046 evaluated triangles.
Equipment LOD totals: 46979 / 22923 / 11567 / 6698 / 3494 / 2654 / 1806.
The existing LOD budgets and five 4096-square atlases remain. Hidden original
donors are intact. Four attachment pose checks pass (maximum error <0.000016).

## Geometry, size and walk

Both forearms, wrists and hands are complete diamond-section steel spikes from
the elbow to the tip. Upper arms, sleeves and shoulder equipment remain. Original
lower-arm flesh and the old mechanical hand are removed from the visible/native
derivatives through `cyber_arm_replacement.py` (`elbow_to_tip_spikes_v3`): exactly
1,492 faces and 1,308 vertices. All 90 bones and retained weights/UVs/normals remain.
`cyber_back_spikes.py` changes only the pinned 520 rear-spike vertices; original
donors remain hidden/intact. Blender/native display parity checks both operations.

The master stays unscaled for donor checks. Generated model GDT `scale=1.33` on
the armored body and all three heads requests the size change at conversion.
Never use live-AI SetScale (documented native crash). Native source previews apply
the same 1.33 scale; actual size/alignment and moving clearance need a playtest.

`_tod_zombie_speed.gsc::apply_speed_for_round` owns the distinctive native walk
with arms down only for `tod_is_sprinter`. Stock chooses a supported stable variant.
Ordinary zombies still sprint. Immediate promotion application, drift repair,
round offset -10, normal/rampage curves and suppressing-fire slowing remain.
Walking root motion intentionally slows the approach. Boss/freeze/riser/native
slow guards precede writes. `test_armored_walk.js` gates every build.

## Current dev playtest — October 7

User requested one armored zombie per round plus dev and god mode. Both flags
are ON in `tod_resolve_dev_flags()`. Other explicit test flags retain their
existing settings; the normal dev bundle still applies.

`_tod_sprinter.gsc::round_watch` seeds exactly one conversion ticket per round
in dev, including the current first round. It bypasses the lap-30 unlock and
party/Rampage wave scaling. The existing one-second director promotes a settled,
living regular horde zombie; no extra actor or round count is created. Killing
it does not refill that round's ticket. Upgrade pause, eligible-AI and alive-cap
guards remain. The finale still suppresses new tickets. Outside dev, the existing
unlock-anchored three-round cadence and wave scaling remain.

Automatic `[TOD_ARMORED_TEST]` records: `START` (quota/god/unlock bypass),
`ROUND_ARM` (round/quota/alive), `PROMOTED` (round/entity/body/health/debt/alive),
change-only `WAIT` (upgrade pause, alive cap, or no eligible zombie), and
`ROUND_SKIP` (finale). The actual-source test `test_armored_dev_rounds.js` covers
round 1 and later rounds, no same-round repeats, co-op/Rampage quota one,
pause/no-AI recovery, eligible actors, finale and normal cadence. Four negative
controls must fail. It runs in every build. Source checks pass; native play and
representative native log output remain the user's test.

SCRIPT BUILD OK; .ff 2026-10-07 09:37:23 Eastern, 155,157,312 bytes; USER PLAYTEST PENDING.
Deployed dev/god flags are ON; 159 authored sources, 184 models and 20 maps match deployed with no compared input newer than the fastfile. The armored master is unchanged from the completed full art build. Sound bank 207,523,840 bytes; ten known waived warnings only. New per-round gate and existing walk/compiled geometry gates passed inside the build. No game launched.
Evidence:
`tmp/armored_dev_rounds_20261007/`. The full model build below remains the art
baseline for this script-only update.

## Diagnostics and reproduction

Dev-only `[TOD_CYBER] START rev=8` and `ELITE_PROMOTE` record
`helmet=executioner_enclosed_v1 tank=removed eye_strength=14 eye_core=16`, plus
`finish=shared_worn_gunmetal_v1` and scale/swords/spikes/walk.
Existing `[TOD_ARMORED_WALK] APPLY rev=1` logs gait,
arms, variant, repaired drift, round, offset, animation rate, slow and rampage on
change. These are configuration/state records, not native visual proof. Dev/god
are ON for the current test above. After the user's playtest, archive `console_mp.log` through
`tools/capture_ai_logs.ps1` and inspect these tags.

Author/review → `export_cyber_zombie_kit.py` in background Blender on the saved
master → `verify_helmet_bake.py` → `promote_exports.py --reference three` →
`install_cyber_roster.py` → full `tools/build_map.ps1`. Always pass Blender
`--python-exit-code 17`; the default exit status can hide a failed script.
`three_mouth_guard.py` also calls the current helmet/removal pass for reproduction.

Seven master views and seven installed-source previews are in the refreshed
gallery (`art/cyber_zombie_roster/review.html`). Installed-source views use
Cycles/128 samples at 1600x1760, including the farthest authored head and a dim
studio visibility study. Images are Blender renders, not game screenshots.

## Build and evidence

FULL BUILD OK; .ff 2026-10-07 01:21:05 Eastern, 155,157,248 bytes; USER PLAYTEST PENDING.
No game launched. Source and compiled roster geometry checks pass. All 21
installed head variants/distances enclose 19,284 checked skull vertices; minimum
measured outer clearance is 0.056756 source units. The 384-triangle connected
helmet shell stays exact in every authored head LOD. All 184 binaries pass
retained-stock preservation checks. Only 22 armored binaries and five armored
maps changed; other roster asset hashes are unchanged. The sole generated GDT
change is the sprinter emission decode 6 -> 16 (size 1.33 already present).

159 authored source files, 184 models and 20 maps match their deployed copies,
with no compared input newer than the fastfile. Sound bank 207,523,840 bytes;
ten existing waived warnings only. Walk tests pass, including four negative
controls; the walk gate ran again inside the full build. Seven master renders
and seven installed-source Cycles/128-sample renders (1600x1760) have current
source/image hashes. Farthest-head and dim-studio views checked; gallery fresh.
Evidence and pre-change master/GDT/manifest backups:
`tmp/armored_helmet_20261007/`.
The previous combined walk/spike build was October 6 at 23:44:25 Eastern,
155,157,184 bytes; it predates this enclosed helmet/tank-removal pass.

Three further ideas remain suggestions: asymmetric cracked shoulder armor,
amber chest vents, exposed elbow power cables. No extra forehead feature.
