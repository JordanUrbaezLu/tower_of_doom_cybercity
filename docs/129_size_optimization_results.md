# Download reduction implementation — September 10, 2026

Implementation of the ten opportunities in [the size audit](128_download_size_audit.md), authorized by “Lets go.” The newer Open Halls build is the starting point: **2,708,843,259 bytes** in the complete deployed `zone/` folder before this pass. The earlier review measured 2,673,610,491 bytes before that intervening build.

**Result: 2,708,843,259 → 2,117,743,099 bytes. Saved 591,100,160 bytes (591.1 MB / 21.82%).** Full clean build with all languages passed at **2026-09-10 18:53:58 Eastern**; final main FF was written at **18:53:55**, 176,182,656 bytes. No upload or native playtest has been performed. All sizes here are decimal file bytes; Steam's compressed network transfer can differ.

## Measured payload

| Complete upload folder | Before, bytes | After, bytes | Reduction, MB |
|---|---:|---:|---:|
| Main pack | 1,802,960,896 | 1,327,497,216 | 475.464 |
| Twelve language packs | 493,420,544 | 377,782,272 | 115.638 |
| Main fastfile | 176,181,632 | 176,182,656 | -0.001 |
| Language fastfiles | 6,500,416 | 6,501,184 | -0.001 |
| Sound banks | 228,746,496 | 228,746,496 | 0 |
| Preview/metadata | 1,033,275 | 1,033,275 | 0 |
| **Total, 48 files** | **2,708,843,259** | **2,117,743,099** | **591.100** |

The named image/sky changes account for **533.981 MB of indexed pack data** relative to the original audit indexes. The remaining total difference includes cleanup, alignment and small metadata changes; it is not a separately measured clean-only A/B result.

| Named change across all packs | Indexed reduction, MB |
|---|---:|
| Weapons | 184.639 |
| Sprinter normal/specular maps | 94.419 |
| Other enemies, including locale copies | 62.945 |
| Double Tap details | 53.729 |
| Perk cans | 36.718 |
| Duplicate images plus constants | 30.017 |
| Sky | 25.178 |
| Utility props | 18.884 |
| Raw material compression | 13.813 |
| Hall floor/wall pictures | 13.638 |

## Changes applied

| Audit item | Concrete implementation |
|---|---|
| 1. Clean every pack | `-CleanPak` now implies all languages, stages the main and twelve language packs outside the upload folder, and retains fastfiles/sound banks until every language passes. Exact prefix/freshness checks, pack-header/index validation, late failure rollback, and a complete payload report replace the main-pack-only success check. |
| 2. Sprinter repetition | Eight normal/specular source maps capped at 512; color remains 1024. All language packs are rebuilt to remove their old copies. |
| 3. Weapons | 68 included source maps capped at 1024. Named optics, reticles, lens and glass maps are excluded from this cap. |
| 4. Duplicates/constants | Material references redirect 29 duplicate image names across 20 strictly matching source/settings groups. Nineteen fully constant images become 16×16, with exact RGBA color/alpha verification. Unreferenced GDT definitions remain installed. |
| 5. Double Tap | 78 smaller detail/property maps capped at 512. Primary machine color/emissive artwork remains 1024. |
| 6. Perk cans | 20 included source maps capped at 1024. Models, labels, liquid, animations and sounds retained. |
| 7. Other enemies | 20 included source maps capped at 1024. Model variants, hitboxes, damage states and animation definitions retained. |
| 8. Props/hall art | Nine utility-prop maps capped at 1024 and thirteen hall floor/wall pictures capped at 512. Machine screen and hall crest artwork retained. |
| 9. Sky | Finished 8192×4096 linear half-float EXR reduced to 4096×2048 using a 2×2 float average. No procedural regeneration. RGB channel mean energy changes by less than 0.008%; alpha remains exact. |
| 10. Raw material textures | Nine camo/PaP image assets switch from uncompressed to supported compression: high color for eight, ordinary compressed for the RGB specular camo. Sixteen definitions changed because seven PaP assets have duplicate owner definitions. Color space, alpha and semantic fields retained. |

There are **236 distinct resized sources**, **11 edited installed GDT files**, and **16 corresponding repository mirrors**: **263 file targets** total. The GDT edits are 29 material-field redirects and 16 compression-field changes. The final pack check, rather than the source-file count, determines realized savings.

## Reproduction and recovery

- Reviewed input list: [size_optimization_manifest.json](size_optimization_manifest.json). It records source hashes, caps, strict duplicate settings and exact GDT field changes.
- Tool: `python tools/optimize_tod_assets.py --prepare`, then `--apply`. Preparation validates inputs/duplicates and creates all converted files without changing build inputs. Application preflights the entire set before copying. Existing repository mirrors are updated alongside installed sources.
- Verify: `python tools/optimize_tod_assets.py --verify`. The build runs this after sync whenever the pass is applied, catching an old source being copied back over an optimized asset.
- Restore: `python tools/optimize_tod_assets.py --restore`, followed by a full clean build. Restore refuses to overwrite later edits. Individual file originals and target mappings are retained in the same state file for narrower manual recovery.
- Original sources and staging: `<modtools>/_tod_size_originals/20260910/state.json`. Originals occupy 678,109,745 bytes, outside build and upload inputs. GDT recovery files use `.before`, so the asset database cannot discover them as duplicate definitions.
- Final build: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/build_map.ps1 -CleanPak -AllLanguages`.
- Payload report: `<modtools>/usermaps/zm_tower_of_doom/last_payload.json`, outside `zone/`.

Third-party asset sources are installed at the shared Mod Tools root and can affect another local map that uses those same sources when it is rebuilt. The manifest and retained originals cover those edits; no other map's compiled files were changed.

## Validation and limits

The clean-pack transaction tests reproduce a late language failure, overwritten/partial fastfiles and banks, a missing language, an invalid index and an escaped path. They verify full hash restoration and successful commit cleanup. GDT fixture checks verify exact field scoping, BOM/CRLF preservation, idempotence and rejection of stale/missing fields.

All 236 converted sources retain their pixel format. All nineteen constant images retain their exact color/alpha. Strict duplicate groups are rechecked against current source pixels and explicit GDT settings before staging. Sky preparation initially rejected an ffmpeg half-to-float path that quantized faint values; decoding at the native half format and averaging in float fixes that issue, with numeric validation before application.

The initial clean-only trial stopped at Japanese model exclusions and restored its previous compiled set. The two exclusions already exist in the shipped language behavior: `p7_gib_chunk_meat_02` and `c_t8_zmb_mob_zombie_body3`, both currently marked `japaneseUnsafe=1`. The stricter language gate accepts only those exact Japanese errors after checking their current GDT flags. Other missing models, other languages or changed flags still fail. No isolated clean-only savings number is claimed from that aborted trial.

The first optimized link rejected `compressed high color` for `i_skye_up_camo_s` (`sRGB3ch` / `specularMap`); all prior compiled outputs were restored. That asset now uses `compressed`, the existing supported BC1_SRGB combination used by the staff and weapon specular maps. Its semantic fields were not changed to force another format. Unexpected English linker errors now stop immediately, matching the stricter language passes.

The final build passed full geometry, navigation, lighting, script/UI/asset gates and all twelve language passes. All thirteen packs have fresh matching fastfiles and valid indexes. All **1,527** captured inputs match their pre-build hashes and deployed targets; complete script/UI/zone trees match and source/deployed mtimes predate the final FF. All **263** optimized file targets and their recovery copies pass hash verification.

All **29** duplicate image names are absent from every pack. Every remaining streamed target meets its resolution cap. Another **21** reduced images (the nineteen constants and two small Double Tap maps) still appear in the linked asset list but no longer have streamed pack entries. These account for the other removed image names: **no unexplained image-name removals, no removed non-image names**. Mesh bytes across all packs remain exactly **221,601,216**. The nine compression targets pack as eight BC7_SRGB assets and one BC1_SRGB asset; none remain raw. The sky's indexed data is **8,392,832 bytes**.

Evidence is retained in `tmp/size_optimized_payload.json`, `tmp/size_optimized_packed_verification.json`, `tmp/size_optimized_freshness.json` and `tmp/size_optimized_build_retry.log`. The original pre-execution folder inventory is `tmp/size_before_execution.json`.

Texture resolution and compression changes still need native visual testing, especially first-person/ADS weapons, perk drinking and Double Tap animation, close-range enemies, hall art, sky lines and the camo/PaP materials. The existing Japanese model exclusion is not fixed by this size pass. Dev/god/open-door settings remain as the user left them.

## Sky retired from this pass (2026-09-13, v18.87 / v18.87)

Item 9 above (the 2:1 float average of the finished sky to 4096×2048) is
superseded: the sky is authored again at its native 8192×4096 by
`tools/gen_tod_sky.js` (docs/104 §4g — the whole point of that pass is the
sharpness a 0.96-texel-per-pixel texture gives at 1080p, which the half-size
copy cannot). `python tools/optimize_tod_assets.py --retire sky` dropped the
two sky rows (installed + repo mirror) from the pass ledger and logged it in
`state.json`'s `revisions`; the recovery copies stay on disk; `--verify` now
reports 260 outputs and the build gate no longer compares the sky. Cost: the
sky's streamed slot returns to ~32 MB from 8.4 MB, about 25 MB of download on a
~2.1 GB item. The other 260 targets are untouched.
