# 112 — THE PACK III CAMO: "NEON CITY" (v17.90 → v17.91, 2026-09-05)

> **STATUS: BUILT, UNPLAYED — an experiment with a control.** Read the table in
> §4 on a PACK III gun before believing anything about custom camos here.
> **v17.91:** the ladder is lucid emissive (126) / Revelations 3 (123) / NEON
> CITY, and Neon City sits on slot **124** (the Revelations-4 row) so that 123
> stays stock for PACK II. Every "123" below that means OUR slot now reads 124.

User: *"Can you look into making one camo for the map. It'll be sick and cyber
colorful for 3rd pap."* / *"Background looks sick so wonder if we can do that
too."*

## 1. What it is

The map's third Pack-a-Punch (the spire's PACK III, `TOD_PAP_CAMO_T3` = index
124 since v17.91; 123 in v17.90) dresses the gun in the sky's own language (docs/104): a dark gunmetal
plating base with a faint hex etch and dim windows, a cyan Tron grid, magenta
circuit traces carrying two bands of wireframe towers with lit windows, gold
nodes. The material is a 3-layer scrolling emissive, so the grid and the city
drift across the weapon at different rates. Since v17.91 PACK I is lucid
emissive (126) and PACK II Revelations 3 (123); gold is retired.

| piece | where |
|---|---|
| the art + the GDT | `tools/gen_tod_camo.js` → `source_data/tod_camo/_images/i_tod_camo_pap3_{c,ea,eb,n}.png` (1024², RGBA) + `source_data/tod_camo.gdt` (4 images + 1 material `tod_camo_pap3`) |
| the tables | `tools/gen_tod_twins.js`, lane `CAMO_PAP3_TABLE` → 20 `tod_camo_<stem>_table` + `tod_camo_<stem>_base121` blocks in `source_data/tod_weapon_twins.gdt`; every `_up` twin's `camo` field names its copy |
| the index | `_tod_classes.gsc` `TOD_PAP_CAMO_T3` **124** (v17.91); LOCKSTEP with `CAMO_PAP3_INDEX` in the twins generator |
| previews | `docs/camo_preview/pap3_{base,layer_grid,layer_circuit,composite}.png` |

## 2. The recipe is a copy, not a design

Four builds on 2026-09-04 (v17.35–v17.39) shipped our own camo material; each
linked with real bytes and drew nothing, and v17.50 closed the question with
"the custom recipe is unknown" and moved the tiers onto stock slots (memory
`pap-camo-materials-never-linked`). The field-by-field diff of that block
against the one custom camo material a released pack ships on a gun's MAIN
surface found the differences, and this pass removes every one of them:

| | v17.35–39 (never drew) | v17.90 (this) | the proven pack |
|---|---|---|---|
| template | `mtl_origins_camo_alt` — a `material2` (second-surface) material | `wpn_t9_camo_madgaz1` — a `material1` (main-surface) material, used by owens_weapons' cosplay shotgun | — |
| base `colorMap` | our coloured diffuse | our coloured diffuse | a coloured diffuse (`mg_TREE1.png`, RGB) |
| layers 00/01/02 | ONE coloured emissive, tints white | TWO greyscale patterns (00 = grid, 01 = circuit + skyline, 02 = grid), alpha = luminance | greyscale emissives, one shared |
| colour | baked into the textures | `colorTint1..3` = cyan / magenta / gold | `colorTint1..3` per layer |
| image blocks | hand-written | copies of `i_wpn_t9_camo_madgaz3_c` / `_ce2` / `madgaz2_n`, name + baseImage moved | — |
| proof of copy | none | `assertCopy()` field-diffs every emitted block against its template and THROWS on an unlisted difference | — |

The proven pack ships both RGB (`mg_TREE1.png`) and RGBA (`mg_orange_em1.png`)
textures, so v17.36's "no alpha = invisible" was at most half the story.

## 3. The tables

A weapon's `camo` names a weaponcamoTABLE of five sub-tables (baseIndex 1 /
76 / 121 / 128 / 136; docs/… v17.62). For each of the 20 packed twins whose
table resolves in this install, the generator emits a copy of the table in
which ONLY the base-121 sub-table is replaced by a copy with two rows changed:

| global index | row | v17.90 |
|---|---|---|
| 121 | `material1_1_material` | untouched stock (Revelations PaP 1) |
| 122 | `material1_2_material` | `mtl_origins_camo_alt` — **the control**: MadGaz's material, in this build for months via the Leviathan |
| 123 | `material1_3_material` | untouched stock (Revelations PaP 3 — PACK II since v17.91; v17.90 had ours here) |
| 124 | `material1_4_material` | `tod_camo_pap3` — **ours** (v17.91) |
| everything else | | byte-identical to the port (verified by diff on the AK-47) |

The two knives (`camo_t9_me_*`) have no base-121 sub-table and the
Leviathan's table is not defined anywhere in the install; those keep their
port tables and PACK III on them is whatever it was.

**Naming rule the linker enforces (found on the first build):** a weaponcamo
asset with `baseIndex` N > 1 must have `_base<N>` in its name — the copies are
therefore `tod_camo_<stem>_base121`. A copy named otherwise is dropped with
`camo name '...' does not include '_base121'`, its table then points at
nothing, and the build still says BUILD OK: read the "UNEXPECTED linker
error(s)" block, not the verdict line.

## 4. How to read the first build

One packed gun at PACK III, dev build, crouch to cycle the camo browser
(`dev_camo_browse_list` leads with 121–126):

| you see | it means | next |
|---|---|---|
| **124 draws the neon city** | the recipe is proven | tune the art; retire the control |
| 124 blank, **122 draws** | the lane works; our material/images are still wrong | diff again — something not on the allow list matters (size? RGB vs RGBA on the diffuse?) |
| 122 blank, **121 draws** | no custom material paints through the camo lane on this map | stock slots are the ceiling; stop spending on art |
| **121 blank** | the table COPY breaks the lane | name the port table again and find another seam |

## 5. The bug the patch had

`String.prototype.replace(string, string)` treats `` $` `` in the replacement
as "insert everything before the match". A GDT row's regex ends in `"\s*$`
and the closing backtick of a template literal followed it, so the first patch
of the twins lane spliced the generator's own 2,000 lines into the new
function twice. Repaired by index splice (`scratchpad/fix_twins_camo.js`);
the lane now uses replacer functions everywhere. Patch a generated file with
a SCRIPT FILE, never an inline shell string — the shell ate the first
attempt's `$`s and the second attempt's replacement patterns ate the file.
