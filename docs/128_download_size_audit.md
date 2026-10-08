# Download size review — September 10, 2026

Original review, before implementation. The user subsequently authorized the work with “Lets go”; implementation and measured results are tracked in [129_size_optimization_results.md](129_size_optimization_results.md). The findings and estimates below preserve the original audit baseline.

The earlier reduction is largely holding. The current deployed upload payload is **2.674 GB**, versus **2.656 GB** in the locally installed Workshop item. A useful next planning target is **about 0.4–0.6 GB**, if the proposed texture reductions pass visual checks. This is an estimate for a future pass, not a measured reduction or a promise of unchanged appearance.

All GB/MB figures in this report are decimal. The existing `xpak_report.js` labels binary GiB/MiB as GB/MB; its numbers have been converted here. Payload bytes are the files shipped, not a measurement of Steam's compressed network transfer.

## Measured baseline

The deployed main pack and fastfile were last written **2026-09-10 16:25:22 Eastern**.

| Shipped files | Bytes | MB |
|---|---:|---:|
| Main `.xpak` | 1,767,833,600 | 1,767.8 |
| Twelve language `.xpak` files | 493,420,544 | 493.4 |
| Main `.ff` | 176,076,224 | 176.1 |
| Sound banks, including language stubs | 228,746,496 | 228.7 |
| Language `.ff` files | 6,500,352 | 6.5 |
| Preview files and metadata | 1,033,275 | 1.0 |
| **Total deployed `zone/`, recursively** | **2,673,610,491** | **2,673.6** |

The main pack's indexed image chunks alone occupy **1,457.8 MB**. Its meshes occupy about **161 MB**. There are no image chunks above 2048 px in this pack; the previous 4K cap work has not broadly reverted. Skybox data uses a separate pack type.

I read all thirteen pack indexes, mapped every one of the main pack's **6,932 image entries** to installed GDT definitions, inspected **1,032 GDT files**, and decoded **1,899 source images** for identical pixels and solid-color images. The source-image pass excludes unsupported formats and had one decode failure. I also reviewed the zone audit, current class/perk inclusion paths, build/publish code, and UI asset gate. This is a current packed-asset review, not a disk-usage ranking of the repository.

## Ten changes, ranked by return for the work

Savings are candidate budgets from current packed bytes. For resolution changes, the ceiling is the sum of existing mip chunks above the proposed cap; it is not the source PNG/TIFF size. Keeping selected detailed textures reduces the saving. A fresh pack is required to realize any of these changes.

| Rank | Change | Candidate saving | Work / risk |
|---|---|---:|---|
| 1 | Clean **every language pack** as well as the main pack, and measure the complete publish payload | **About 30 MB of main bake history is identifiable; the reporter flags about 80 MB total, not all proven reclaimable** | Small / low |
| 2 | Reduce textures repeated with the armored sprinter across language packs | **94 MB** for normal/specular maps; **183 MB** including color | Small–medium / visual check |
| 3 | Selectively cap remaining 2048 px weapon maps at 1024 | **Up to 185 MB** | Medium / first-person visual check |
| 4 | Share identical image assets and shrink completely solid textures | **About 31 MB** candidate budget | Medium / low, with conversion checks |
| 5 | Reduce Double Tap's smaller animated details to 512 | **Up to 63 MB** | Small–medium / visual and animation check |
| 6 | Cap the perk-can texture set at 1024 | **Up to 37 MB** | Small / drink-animation visual check |
| 7 | Cap remaining 2048 px enemy maps at 1024 | **About 38 MB** in the main pack | Small–medium / close-range visual check |
| 8 | Reduce oversized utility-prop and hall-decoration textures | **Up to 40 MB** combined | Small–medium / readability check |
| 9 | Test a half-resolution copy of the finished cybercity sky | **About 25 MB** | Small / conspicuous visual risk |
| 10 | Compress the few remaining raw world/camo textures | **About 8–13 MB** | Small / material check |

### 1. Complete the clean-publish path

`tools/build_map.ps1:848` moves only `zm_tower_of_doom.xpak` out before linking. The language passes at `:1035` rebuild fastfiles but retain their existing `.xpak` files. Several language packs still have September 2 timestamps despite September 9 language fastfiles. The report at `:1008` is advisory, checks only the main pack, and runs before the additional language passes.

The main pack has three `shadowTree` entries, including a tiny dummy, and two versions of the large volume-0 reflection/probe/shadow set. The extra real set is approximately 33 MB. `xpak_report.js` flags 44.5 MB of unindexed gaps plus roughly 35.7 MB of estimated stale bake data. **Do not promise to recover every gap:** a previously clean pack already had roughly 43 MiB of gaps, and the report's “last bake cluster” model cannot prove all earlier volume data is unused. It also flags 3.5 MB of Deadshot-can assets by name, which is not a reachability proof.

Recommendation: extend the existing reversible staging/restore procedure to every map-owned language `.xpak`, rebuild every supported language, then measure the entire final payload. Record a size budget after all passes and verify freshness for each language before accepting the publish. This is also necessary for recommendation 2: otherwise its obsolete language texture chunks can remain in the download.

The official [Treyarch Workshop guide](https://steamcommunity.com/sharedfiles/filedetails/?id=770558798) explicitly recommends removing the map's `.xpak` files and rebuilding with all languages selected. Keep all twelve language fastfiles: this project has already reproduced load failures when language support was omitted.

### 2. Exploit the language-pack texture multiplier

The armored sprinter is explicitly zoned at `zone_source/zm_tower_of_doom.zone:298` as `c_t8_zmb_mob_zombie_body3`. Its definition is in:

`<modtools>/model_export/kingslayer_kyle/characters/t8/c_t8_zmb_mob_zombie/c_t8_zmb_mob_zombie.gdt:4754`

It has `japaneseUnsafe=1`. Its body textures are present in the main pack and eleven non-Japanese language packs. For `i_c_t8_zmb_mob_zombie_body3*`, there are **15 chunks above 512 px totaling 15,213,696 bytes per pack**. Across twelve copies:

- Normal maps: **88,134,144 bytes**.
- Specular map: **6,296,064 bytes**.
- Color maps: **88,134,144 bytes**.
- All three: **182,564,352 bytes**.

Start with 512 px normal/specular maps while retaining the 1024 color maps. The first target is **94.4 MB**, without changing the enemy model or class behavior. Test a 512 color version separately if it remains readable in close combat. Resize only these identified image sources; the installed GDT contains additional character content.

There is a larger experimental packaging question: each non-Japanese language pack repeats about **35.9 MB of keys already present in the main pack**. That is evidence of duplication, not proof those files can be removed. Moving the character dependencies to common packaging could offer more, but requires proving the engine's localization/SKU behavior. **Do not delete language packs or simply clear `japaneseUnsafe`.** I have not included speculative common-pack savings in the target.

### 3. Cap selected remaining weapon maps at 1024

The following installed GDT families still contribute approximately **184.6 MB of chunks above 1024**:

| Family | Removable higher mip chunks, MB |
|---|---:|
| Leviathan / Stormbreaker | 46.2 |
| Gift of Death / Xmas gun | 39.9 |
| Bulldog | 16.8 |
| MAC-10 | 16.8 |
| UDM | 16.8 |
| AK-47 | 14.7 |
| Shared CW weapon attachments | 7.3 |
| RK7 and Nail Gun | 12.6 |
| Krig, SG12, Stoner and MOG12 | 13.6 |

Use `tools/downscale_pack_textures.js` with per-image filters on the actual included images. Begin with specular/roughness/normal maps and small attachments; preserve detailed color maps and important sight masks until compared in ADS. A whole-file dry run includes installed assets that this map does not ship, so use the packed-image inventory to limit the work.

Main sources: `_custom/wetegg/leviathanaxe/leviathanaxe.gdt`, `source_data/xmas_gun.gdt`, and the listed `source_data/skye_*.gdt` weapon packs. These are installed Mod Tools paths, often shared with other maps. Keep original files and a reproducible per-image manifest.

The Gift gun is live through `_tod_powerups.gsc:1115`, which redirects the Death Machine powerup. Weapon attachment models are also live through weapon-definition slots, including upgraded sights. Neither is safe to remove on a script-name search.

### 4. Remove duplicate image definitions and solid-texture waste

The pixel pass found **20 groups with identical decoded RGBA pixels and identical explicit image settings**, excluding only source filename/type. Keeping one image asset per group and redirecting all material references targets **22,295,344 bytes**. Representative duplicates:

- Panzer faceplate, arm-cannon and neck-shell images in `source_data/mechz_spiki.gdt`.
- Weapon/attachment copies of `i_weapon_vm_lm_t9accurate_misc_*` and `i_attachment_vm_lm_t9accurate_misc_*`.
- Repeated MOG12 and Bulldog material images.

A broader pass found 25.3 MiB, but some entries had different `coreSemantic` settings; those were excluded from the 22.3 MB budget above. Packed blob hashes also differ, so the evidence here is **identical source pixels/settings, not byte-identical packed blobs**. Compare the converted result before merging a group.

Separately, **19 fully constant RGBA textures consume 8,268,768 bytes**. Examples include the 1024 px Infinite Ammo black color/flat normal maps, a uniform holographic-sight glass tint, shield specular maps and white debris masks. Preserve their exact colors, alpha and semantic settings in tiny textures, such as 16×16. These constant images do not overlap the duplicate groups.

Merely pointing two separately named image assets at the same source file is insufficient: make material references share the same image asset, then prove the duplicate entry disappears from a clean pack. Keep distinct material behavior, especially Panzer damage states and transparent sights.

### 5. Give Double Tap a separate texture budget

The machine/animated-cowboy pack owns **86.7 MB of images**, much more than the other individual perk-machine families. Of that, **63.1 MB is in chunks above 512 px**.

Source: `_custom/_wetegg/models/sat/t10_zm_machine_d_mod/t10_zm_machine_d_mod.gdt`. The live models are explicitly zoned at `zone_source/zm_tower_of_doom.zone:1481` and `:1482`; the generator places the machine at `tools/gen_tower_map.js:1639`.

Retain 1024 for readable labels/front artwork; test 512 for cowboy clothing, secondary pieces and surface-property maps. Preserve the existing powered and purchase animations. The animated model is live, so removing the cowboy's materials wholesale would be a visible change.

### 6. Apply the earlier machine cap to the newer perk cans

The installed can pack has **55.3 MB of indexed image data**, including **36.7 MB above 1024 px**:

`_custom/_wetegg/weapons/sat/eqp/perk_cans/sat_zmb_perk_cans.gdt`

This is separate from the machines that were already capped. The can normal/specular/gloss/occlusion maps and label textures still have 2048 px chunks. Cap the included images at 1024, keeping the labels and liquids intact.

The live can table is `scripts/zm/zm_tower_of_doom.gsc:643`; names are assembled at runtime. A zero-reference grep for the `_zm` asset names is not evidence they are unused. Test all nine drink animations and their sounds, including Wisp Tea and Widow's Wine.

### 7. Cap the remaining high-resolution enemy maps

Excluding the sprinter family in recommendation 2, approximately **37.8 MB of primary-pack chunks above 1024** come from:

- `model_export/t7_characters_zombie.gdt`: **27.3 MB**.
- `source_data/mechz_spiki.gdt`: **8.4 MB**.
- `source_data/c_zom_zod_robot_protector.gdt`: **2.1 MB**.

Use 1024 only on the included 2048 sources, starting with body/surface maps. Preserve models, hitboxes, animations, dismemberment variants and glow states. Test the Panzer, Warden King and Protector at melee distance. These are texture savings, not a reduction in enemy variety. This budget counts the main pack only; some stock character data also has language copies.

### 8. Reduce oversized prop and hall-decoration maps

There are two separate small passes here:

- Utility props: **23.1 MB above 1024**, covering the power switch, ammo crate, teleporter/stock prop maps and the two PaP families. Key installed sources include `source_data/fanatic/ww2/ww2_power_switch.gdt`, `source_data/acc_west_ammo_crate.gdt`, `model_export/t7_props_zombie.gdt`, `source_data/chaos_pack_a_punch.gdt`, and `source_data/acc_alxs_pap.gdt` plus its duplicate installed definition.
- Seven-hall decorative artwork in `source_data/tod_materials.gdt`: **23.1 MB total**, with **17.3 MB above 512**. This covers 20 included floor/wall/crest image assets. The generator wires this artwork at `tools/gen_tower_map.js:1009`.

Test 1024 on utility props and 512 on hall art. Preserve machine screens and identifying text where required. These are detailed pictures, not solid color swatches. This work does not require changing geometry, collision or the hall layouts, although material-source edits still require the project's full build.

### 9. Test a smaller finished sky image

`tools/gen_tod_sky.js:84` defaults to an **8192×4096** source. The live `i_skybox_tod_cybercity#1de67382` skybox payload is **33,554,560 bytes**. A half-width/half-height version would target roughly **8.4 MB**, a **25.2 MB** reduction if the converter retains the same representation.

Downsample the finished HDR image while preserving its energy/exposure, then verify the resulting pack size. Do not assume regenerating the procedural sky at `--width 4096` is identical: its pixel-scale and line-width logic changes with width. The sky is highly visible, so this ranks below the smaller, less visible textures. Inspect horizon signs, thin grid lines and tower lighting in game.

Do not change `SUN_VOLUME_TOP_MIN`, probe placement, exposure, fog or the sun volume as part of this test. The previous yellow-lighting regression came from the sun volume and is documented in `docs/107` and `CLAUDE.md`.

### 10. Compress the raw camo and PaP-detail images

The pack still stores `i_skye_up_camo_c` and `i_skye_up_camo_s` as **R8G8B8A8_SRGB**, totaling **11.2 MB**. They are explicitly `compressionMethod=uncompressed` in `source_data/skye_up_camo.gdt`. At the same dimensions, BC7-style storage would target about **2.8 MB**, saving **8.4 MB** before packing overhead.

Another roughly **6.3 MB** of raw color textures comes from PaP rust, dirt and scratch details declared in `source_data/acc_alxs_pap.gdt` and the installed CW PaP model GDT. Including those brings the candidate saving toward **13 MB**. Both owner definitions must be reconciled where the same asset is declared twice.

Use a supported compressed high-color image setting, preserve color-space and alpha behavior, and compare the material in game. Inspect the UDM/Bulldog camo and PaP machines. This recommendation is specifically about raw textures measured in the `.xpak`; it is not a blanket instruction to compress the HUD.

## Candidates that did not earn a top-ten slot

- **Repository cleanup:** deleting unused PNG masters, export files, tools, backups outside the upload folder, or unzoned GDT definitions does not reduce the Workshop payload. Trace the shipped asset first.
- **More card retirement:** `node tools/lint_tod_assets.js` passes with **zero dead card slugs and zero dead card images**. It still accepts ten dead pause plates and some fallback art, but those are small. The automated zone audit's 42 unreferenced weapon/model/FX candidates include live computed-name and GDT-driven assets; they are not 42 confirmed deletions.
- **Bulk UI compression:** the packed asset list identifies 631 `i_tod_*` images with approximately **781.5 MB of source RGBA pixels**, including 176 cards at 768×1152. That is primarily a resident-memory opportunity. The corresponding PNG sources total only **54.9 MB**, and the entire compressed main fastfile is **176.1 MB**. Do not present raw RGBA reductions as download savings; measure an A/B fastfile before accepting any claim. Baked text readability is also a real constraint.
- **Removing weapon variants:** the class system uses generated variants for actual handling/recoil/other states. They share meshes/textures. Asset-registration count is not a multiplier for download size. The packed asset list and the gameplay registration guard also count different things.
- **Dropping music or changing sample rate:** sound banks total 228.7 MB, and previous dead-alias trimming has already landed. Further alias pruning needs GDT, FX, animation-notetrack and secondary-alias reachability, not only GSC searches. The existing converter requires the project's established audio format; changing source encoding is not an automatic reduction in the packed bank.
- **Removing LODs, probes or crown geometry:** no large safe download win was established. Removing LODs can hurt performance; geometry/probe/sun changes carry previously reproduced lighting and navigation risks. Texture and duplicate-asset work offers a better first pass.

## How to turn this review into measured savings

1. Snapshot the current sources and complete upload payload. Keep source originals outside build inputs; scope changes to this map's included image list.
2. Implement the all-pack clean/restore path. Rebuild all supported languages and record this clean baseline before judging new savings.
3. Apply one family at a time. Begin with duplicate/constant images and the sprinter normal/specular maps; then compare selected weapon, can and Double Tap texture caps.
4. Use the normal full build, including geometry, navigation, lighting, asset/script/UI gates. Confirm source freshness against that build. Check all language outputs after the last linker pass.
5. Compare total shipped bytes and the named packed-image chunks. Replaced images must actually lose the old entries in fresh packs. Use the usual native checks for first-person/ADS, all perk drinks, animated machines, enemy damage states, sky and representative languages before calling the result regression-free.

Read-only working evidence is retained under `tmp/size_audit_*`: pack CSVs, installed asset-owner inventory, pixel duplicate/constant reports, and the audit scripts. Existing project commands used were `xpak_report.js`, `audit_zone_usage.js` and `lint_tod_assets.js`. Subsequent implementation is recorded in the linked results document.
