# Cybercity reference equipment

Open [review.html](review.html) for the five editable studies, six camera views
per model, and the three original reference sheets. Scope: regular zombies
and armored sprinter.

The equipment is reconstructed on the original bodies: layered shoulder armor,
cyan reactor cells, magenta hoses, fitted harnesses, wrist/leg braces, mechanical
hand plates, cracked optics, jaw supports and a raised welding visor. Chipped
paint, oxide, directional scratches, rubber and woven mounts use separate
material responses. This is an adaptation to the existing body proportions,
not an exact 3D recovery from the reference pictures.

Authoring: `tools/cyber_reference_equipment.py`; one-time source masters are
preserved in `tmp/cyber_finish_v3/`. Current reports: `equipment_v4.json`.
`delivery_manifest.json` records the current master and render hashes.

Five native atlas sets use five 2048-square maps each. All geometry follows
existing skeleton joints. The stock elbow/knee cuts preserve shoulder/hip
gear and send forearm/shin equipment with the detached limbs. Original
body geometry, UVs, weights and animations stay intact.

Current build status and reproduction: [docs/146](../../docs/146_cyber_reference_equipment.md).
These are Blender studio views; native appearance and motion need the user's
gameplay test. Panzer, protectors, Reavers and hellhounds are outside this pass.
