# Floor 10 — Sky Lounge prototype

The requested structural and atmospheric redesign is limited to the tenth-floor
breather. The new silhouette opens toward a stepped observation deck, with an
arrival portal, shallow canopies over the upgrade/perk stations, and two tall
fins framing the outer lookout. The middle stays open to the sky and tower.

The main room keeps its 544 × 576 footprint. A 288 × 352 shoulder and 96 × 224
lookout add 122,880 square units, or 39.2% more room floor. Dark blue walking
surfaces, narrow blue perimeter lights, neutral structural supports and warm
service lights replace the former window-wall box. Small floor seams mark the
gathering space and the route toward the view. Floor-10 chest-height haze is
replaced with low overlook fog and high motes.

PaP, upgrades, ammo, perks, teleporter, respawn points and existing risers keep
their anchors. This prototype changes structure and atmosphere; it does not
introduce sanctuary mechanics. The new wing belongs to zone 10. Generated
room detection covers it for both the arrival chime and existing spawn relief.
Floors 20, 30 and 40 retain their previous structure and lighting.

## Sources and previews

- `tools/breather10.js`: the floor-10 structure and overlook dimensions.
- `tools/gen_tower_map.js`: floor-10 dispatch, zone coverage and lighting;
  emits `_tod_breather_data.gsc` alongside the map.
- `_tod_atmosphere.gsc`: floor-10 ambient FX placement and shared room lookup.
- `_tod_endless_rounds.gsc`: uses that same lookup for existing breather relief.
- [Plan](breather10_preview_plan.png): generated geometry, approximate colors.
- [Inspection](breather10_preview_inspection.png): geometry only, without the
  game's lighting, machines, particles or surrounding tower.

Generate with `node tools/gen_tower_map.js`, then run a **full build**.
Preview camera support in `tools/preview_crown.js` accepts `--eye x,y,z` and
`--target x,y,z`. These previews are not in-game screenshots.

## Verification

Static geometry: no misplaced walls, unguarded edges or detached walks.
Compared world brush geometry/materials against the pre-edit map, ignoring
regenerated GUIDs: all 156 changed/added/removed labels belong to floor 10's
breather. Arity/resolution passes. Shared room detection passes 4,216 points
across all four floors. The compiled navigation mesh covers 90 interior
overlook samples in the same connected component as the tower.

Full build verified 2026-09-10 at 02:06:06 Eastern: FF 173,330,752 bytes.
All 1,154 snapshot/repo/deployed build input hashes match, as do complete
script/UI trees. Six pre-existing dark pause images retain future 03:05:56
archive timestamps but match the pre-build snapshot; all other 1,148 inputs
predate the fastfile. Native appearance and walk-through remain pending.

In game, check the stair entrance, all use prompts, both sides of PaP, the
lookout's stepped corners, the teleporter round trip, and zombie pursuit onto
the outermost deck. Judge brightness and atmosphere with the normal HUD on.
