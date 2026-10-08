# Crown structure enhancement — September 15, 2026

User requested exterior and interior structural improvements, readable from the
base, underneath, on the approach, head-on and inside. Geometry is the priority.

## Implemented

- True convex brush geometry replaces the four-step corner approximations.
- The outer band's courses have sloping sides and matching octagonal joins.
- A five-section sloping bell replaces the ten stacked underside tiers. Eight
  substantial gold ribs follow its corners; three brass reveals articulate it.
- Both upper arches use 24 adjoining sloped sections per half, rather than
  eight stair-step boxes. The orb and pearls use faceted round profiles.
- Crown point heads flare through angled shoulders. Jewels, front cross,
  pendant, ribs, entrance posts, cornices and interior trim have cut bevels.
- The hall's straight colonnade beams become curved arcades, with beveled
  pillars and capitals. Upper wall panels and exposed jambs add detail.
- The hall floor, sanctuary steps, dais, vendors, spawn and finale anchors
  retain their existing placements. Crown data matches the before snapshot.
- Palette/material assets are unchanged. These are structure previews with
  approximate colors, not claims of photographic metal or native lighting.

## Geometry tooling

`tools/convex_brush.js` reconstructs bounded hulls from actual emitted map
planes. It owns plane intersections, polygon face areas and vertical spans.

`preview_crown.js` now draws those polygons with a PNG depth buffer and clips
polygons at the near plane (the old renderer dropped a floor crossing behind
the camera). SVG remains a painter-sorted approximate export. No invented
strong shading: the existing crown materials are self-lit.

`lint_tod_geometry.js` reads convex crown architecture and samples its actual
vertical extent at each 20-unit column center. It does not fill a slope's
bounding box. Crown walking surfaces remain the original axial slabs; these
decorative hulls are blockers rather than newly introduced floors. Existing
stair-ramp sampling and limitations remain. This is a static sampler, not a
proof of sub-grid clearance, prefabs, script collision or zombie navigation.

`measure_lit_area.js` measures convex face polygons. `audit_hidden_faces.js`
samples actual faces and tests containment using halfspaces. Its hidden-area
result is advisory. This pass found four wholly buried wall trim pieces and
removed them.

`test_crown_convex.js` verifies closure of emitted crown hulls and checks area
and collision sampling against an analytic wedge. It gates full builds. The
existing geometry fault-injection tests and mirrored-layout test also pass;
the latter now copies the geometry helper into its isolated generator folder.

## Evidence / status

- Before inputs and previews: `tmp/crown_structure_review/before/`, `current_*`.
- Work previews: `tmp/crown_structure_review/final_*.png` (regenerate after edits).
- Original crown categorized lit area: 949M units squared; first shaped pass
  approximately 849M. This measures authored surface area for lighting, **not
  runtime frame rate** and not predicted bake time.
- First full compile: both towers pass native navmesh connectivity gate.
- First full-build log: `tmp/crown_structure_review/build.log`.
- First build completed successfully, FF 149,676,608 bytes. This includes the
  four buried trim pieces; it is superseded by the final cleanup build.
- Scope comparison: all 10,975 non-crown brushes are unchanged (GUIDs ignored),
  and crown gameplay anchor data is byte-identical. Planarity/convexity asserts
  also run in the generator; a write-intercepted run reproduces all five output
  files byte-for-byte without modifying them.
- Fault injection now additionally inserts a sloped invisible blocker on the
  actual causeway and proves the updated collision lint detects it.
- **Final full build PASSED 2026-09-15 11:48:05 Eastern**, FF 149,611,840 bytes.
  Log: `tmp/crown_structure_review/build_final.log`. Fresh BSP/navmesh and LED
  bake; both towers connected; existing ten waived third-party warnings only.
  Full build ran the new hull gate. Final source/deploy comparison: 145 script,
  UI and zone-source inputs identical; no deployed input newer than FF. Map
  matches the final full compile. `deploy_verification.json` records this.
- Final geometry: 773 crown hulls tested, 669 shaped solids; all closed.
  Hidden-face audit reports no crown brush at or above 99% hidden. Fault
  injection suite including convex blocker and mirrored layout: Node exit 0
  (`selftest_verified.log`).
- **Native boot observed:** launched with `tools/run_game.ps1`, inspected and
  accepted Steam's custom-arguments dialog. BO3 PID 17064 loaded the map and
  rendered the base arena/HUD, MR6, 150 HP, 500 points, round 1. Screenshot:
  `tmp/crown_structure_review/native_maximized.png`. Initial black captures
  cleared after maximizing the window, as in prior sessions.
- The next screenshot/input helper failed its foreground guard (Steam held
  focus). No further game inputs were sent. **Close-up crown walkthrough and
  in-game visual approval remain unverified. Game left running.** No camera
  commands were issued and no class/playthrough was operated.
- Native logs preserved at
  `tmp/elite_tracking/runs/20260915_115129_677_469e48b2`.
- Initial geometry build had all dev/god flags off. **User then explicitly
  took over testing and requested dev, god and open doors.** Enabled
  `tod_dev`, `tod_god`, `tod_dev_doors`; optional maxed-loadout, upgrade,
  altar and Mage-test flags remain false. Existing dev mode supplies money
  and diagnostics, and the existing door harness opens the tower doors.
  No new gameplay harness was added. Closed agent-started PID 17064 after
  archiving at `20260915_115233_493_804a0c9c`; script-only test build follows
  the verified full geometry build (`build_dev.log`). User owns gameplay
  verification from here; agent handles build and Steam launch only.

## Continuing work

Edit `tools/gen_tower_map.js`, never the generated map. `crownLoft` joins
matching convex profiles; `crownBevel` cuts inward within an existing envelope.
Keep profiles planar and convex, and keep all new pieces within the crown/sky
and causeway assertions. Run generation, hull tests, static lint, area and
hidden-face checks, then a full geometry/lighting build. Compare the actual
game before claiming the visual pass is approved.
