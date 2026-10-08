# Heavenly Gift Altar — cyber design study

The reference is `design_reference.png`, supplied by the user on September 16,
2026. The editable design is `heavenly_altar_cyber.blend`; the unchanged native
altar is preserved in `heavenly_altar_original.blend` and as a hidden reference
mesh inside the design file.

## Live inspection

The isolated Blender MCP session uses **127.0.0.1:9878**. Other sessions use
9876 (Tower II sword) and 9877 (zombie roster); never direct altar work to them.
The saved file opens in **Rendered** viewport shading with scene lighting,
materials, shadows, reflections and compositor glow. Middle mouse orbits;
Numpad 0 leaves/returns to the review camera. The model is intentionally a
separate art master. The native export now lives in `engine_kit/` and
`model_export/tod_heavenly_altar/`; the shared station model is switched to
`tod_heavenly_altar` for all six locations. See the build status below.

## Construction

- Original diamond silhouette, with full-depth graphite structure, layered
  ivory armor, champagne-gold bevels, segmented shields and mechanical locks.
- Rebuilt celestial crest: 48 index segments, four raised glyph medallions,
  concentric optical rings, central triangle/circle, bolts and recessed sectors.
- Faceted crystal clusters in machined cradles; modeled light conductors,
  separate curved feather membranes, halo ribbons, hanging sigils and packets.
- Surface materials have roughness variation, fine grain, clearcoat and
  modeled panel seams/scratches. These procedural materials are editable and
  are baked into the native texture maps for deployment.
- The heavenly figures and stairs are a **recessed image surface sampled from
  the supplied reference**, matching the original altar's image-inset approach.
  They are not sculpted characters or a traversable three-dimensional interior.
- The reference shows the front. Rear service covers, cooling vents and
  conduit routing are a compatible extrapolation, not image-confirmed geometry.

## Validation and deployment status

### Restored satin material ? current

The user rejected the all-matte result at 21:54: it flattened the exterior.
The full pre-matte GDT is restored, with exactly ONE adjustment from that
version: `glossRangeMax` 8 -> 6. Replacing that value back to 8 reproduces the
SHA-256 of the 19:54 GDT exactly; evidence is in
`tmp/heavenly_altar_satin_restore/change_scope.json`. Specular image/enable,
amount .2, tint .25 and reflection-probe amount .15 are restored. All original
model and texture files are byte-identical. The interior remains user-confirmed.
Full build passed at 22:04:01 Eastern: 146,515,200-byte FF. All 165 inputs,
original portal definitions, seven altar LODs and existing cyber model checks
passed; converted material settings match. Built and stopped; the adjusted
gloss still needs the user's game test.

### Matte frame follow-up ? rejected, superseded

The user confirmed that the original interior works, but the softer frame was
still too glossy. The native frame now uses `$black_specular`, zero specular
amount/tint, zero gloss range and zero reflection-probe amount. Its old
specular image is no longer a shipped dependency. Geometry, diffuse/normal
textures, cyber emission and the restored interior are unchanged.
`verify_native.py` requires these matte settings while preserving the original
panel at every LOD. Evidence: `tmp/heavenly_altar_matte/`. Full build passed at 21:15:16 Eastern,
146,514,176-byte FF. All 165 inputs, original portal definitions, seven altar
LODs and existing cyber model checks passed. Converted material settings were
checked directly. The current front preview is matte; older side/LOD preview
shading predates this final material-only change. User test of the final
finish remains pending; the game was not launched.

### Original interior restored; frame softened

The user's second screenshot confirmed that the 19:24 material-slot fix did
**not** resolve the gray center. That earlier unlit-path diagnosis was not a
confirmed game cause. Its preview is retained only as historical evidence.

The native installer now extracts the original altar's 32 background faces,
unchanged positions, UVs, winding, normals, vertex colors and root weights.
All seven LODs reuse `chaos_pap_background` directly, with its original three
animated texture layers. Neither the shared material nor its images are edited.
`original_portal.py` SHA-checks the donor; `verify_native.py` compares every
portal corner against it. The custom portal material and baked image are no
longer dependencies of the shipped model. The editable Blender art master
retains its reference-derived study interior; the native derivative deliberately
uses the original in-game interior requested by the user.

Frame gloss range is 0..8 (previously 1..17), specular amount .2, specular tint
.25 and reflection-probe amount .15. Cyan/purple emission remains unchanged.
`game_preview/native_front.png` shows the restored native mesh with a static
first-layer approximation and softer shading; it is not a game screenshot.
Final build: September 16 at 19:54:01 Eastern, 146,544,640-byte FF.
All 165 source/deployed inputs and used portal definitions pass verification;
all seven LODs and 249 existing cyber models pass compiled checks. The full
build completed before a peer sync removed its reports; final peer packaging
passed and independent altar checks were repeated. Current evidence and exact
provenance: `tmp/heavenly_altar_original_inset/`.
User confirmation in game remains pending.

`validation.json` records the master hash, evaluated geometry count, source
preservation, bounds and missing-file check. Review images are actual Blender
renders; each has an adjacent JSON carrying the exact master hash.

**Original interior and satin frame built for all six altars; user retest pending.** The original source remains preserved. Seven native detail
levels contain 83,220 / 51,342 / 35,454 / 26,637 / 21,776 / 18,109 / 15,447
triangles, versus the previous model's 161,216 triangles at its single authored
level. The main surface has five 4096-square baked maps, the portal reuses the original
three animated image layers, and wing membranes use small RGBA textures with
two-sided geometry. All six instances share these assets.

`game_preview/` shows actual exported source geometry and baked textures in
Blender, including backface culling. Those images are not BO3 screenshots.
Blender's glow and ray-traced lighting do not establish the exact game result.
`verify_native.py` checks all-six placement wiring, source integrity, original
collision/sound wiring, and (after building) triangle coverage at every LOD.
The full build runs these checks automatically. Initial integration package (historical): **146,512,640 bytes, September 16 at 18:50:18 Eastern**.
All 164 source/deployed inputs match the full-build snapshot, no later sync or
missing altar assets, and every triangle survives conversion at all seven LODs.
The existing 249 cyber zombie binaries also pass source and compiled checks.
Our full geometry/lighting/native build completed; a concurrent peer sync
removed its reports during postchecks. The peer's subsequent packaging passed
BUILD OK using those unchanged inputs, and all checks were repeated independently.
Evidence: `tmp/heavenly_altar_integration/deployment_verification.json` and
`build_provenance.json`. The game was not launched; dev/god/open doors stay off.

## Reproduction

Run `tools/heavenly_altar/import_original.py` through the isolated MCP session,
then `01_structure.py`, `02_crest.py`, `03_crystals_wings.py`,
`04_portal_finish.py`, `05_reference_refinement.py`, `06_live_rendered.py`,
`07_optical_polish.py`, `09_side_surfaces.py`, and `08_validate.py` in that order. These are stage
scripts, not idempotent patch operations; rerun from stage 01 for a clean
reconstruction. Render the saved master with `render_review.py -- front`,
`-- detail`, or `-- side` using background Blender. Render tooling must never
save over the live master.

This is a reconstruction guided by one image, not an exact image-to-mesh
recovery. Native integration is complete; the user will judge the game appearance.
