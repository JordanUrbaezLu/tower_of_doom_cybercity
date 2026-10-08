# Reference two: regular zombies

The rear machine was rebuilt through the visible Blender MCP session on port
9877. It now follows the reference's asymmetric pipe network, with paired supply
lines, a separate flank return, copper induction chamber, amber regulator,
layered lower spinal cassettes and a solid carrier for the tall neural cell.
The original body, head, skin weights and other master equipment are preserved.

- Master: `reference_two.blend`; 1,933 equipment objects.
- Gallery: `../cyber_zombie_roster/review.html?ref=2&mode=native&view=back_detail`.
- Five 4096-square baked maps; seven equipment LODs: 46433 / 32296 / 18631 / 7654 / 5120 / 3392 / 1692.
- Four pose checks passed. Reference-one and reference-three assets unchanged.
- Full build verified 2026-09-16T14:54:25.573552; 149,684,992-byte main fastfile.
- All 431 snapshot/source/deployed inputs match; compiled geometry passed.
- Built and stopped; game not launched. User playtest remains pending.

Authoring: `tools/cyber_references/two_back_machine.py`, followed by
`fix_modifier_order.py` and `review.py`. Evidence: `tmp/reference_two_back_machine_20260916`.
Gallery pictures are Blender renders of masters and exported source assets,
not in-game screenshots. Equipment adapts the reference to the original donor.
