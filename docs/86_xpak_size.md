# 86 — The 9.6 GB Workshop item: where the bytes were, and the clean pack

**Date:** 2026-09-03. **Status: DONE and measured.** 9.61 GB → **2.43 GB**
(−75%): the pack rebuilt from scratch by `-CleanPak` (now implied by
`-Publish`), perk-machine / weapon / riot-shield textures capped at source,
the Street Sweeper and the Mahem rocket unzoned, 12 retired-domain cards out
of the `.ff`, Japanese + both Chinese language packs dropped. The process is
now a build gate, not a memory: §10.

**Sections run 1-6, then 8, 9, 10, then 7** — 7 is the standing-rules
summary and stays last on purpose.

## 1. The question

The Workshop item read 9.613 GB. That number is the deployed
`usermaps\zm_tower_of_doom\zone\` folder (9168 MiB; Steam shows decimal GB),
and 9.08 GB of it was one file, `zm_tower_of_doom.xpak` — the streamed asset
pack. Repo review docs/61 #8 (2026-09-01) had guessed at "the author's asset
stack" and the 309 UI images packed `uncompressed`; both guesses were wrong,
and this doc is the record of what was actually in the file.

## 2. Method: read the pack's own index

The xpak carries a readable index (format reverse-read on this box, header
version 10; the full layout is in the header comment of
`tools/xpak_report.js`): a hash table of `{key, offset, size}` and, per
entry, a text record `name: / type: / width: / height: / levels: / format:`.
Joining the two attributes every byte to a named asset. `tools/xpak_report.js`
does this in ~2 s for any pack — run it before and after any size work
instead of guessing.

## 3. What was in the 9.08 GB pack (2026-09-03, before the clean build)

| Bucket | MB | Verdict |
|---|---:|---|
| reflection probes (221 entries, 55 probes in the map) | 3733 | 47 builds' worth, stale |
| holes: bytes no entry indexes (3758 gaps, largest 33 MB) | 1389 | replaced assets' old slots |
| probe volumes (552) + sun-shadow trees (47 under ONE name) | 419 | 47 builds' worth, stale |
| retired assets still indexed (Deadshot + Elemental Pop machines) | 124 | stale |
| weapon port textures (Skye t9/t8 vm + attachments, axe, gift gun) | ~1660 | live |
| BO7 perk machines, WetEgg/SAT pack (25 textures at 4096², 150 at 2048²) | ~880 | live, oversized |
| Riot-shield / powerup models (Logical), zombie characters, meshes, skybox | ~700 | live |

**Our own `i_tod_*` UI art is not in the pack at all** (0 entries; it rides
the 136 MB `.ff`), so its `uncompressed` GDT setting was never a lever.

**The mechanism.** The BO3 linker treats the xpak as append-only: every full
build appends a fresh sun-shadow tree, reflection-probe set and probe
volumes under the SAME names and never removes the previous build's; a
replaced asset gets a new slot and its old bytes become an un-indexed hole;
an asset dropped from the zone keeps its entry. Even a `-GscOnly` build
appended 9 MB. Map 1's pack shows the same signature (6 shadow trees, 27
probe sets). The official Workshop guide's own size advice is "delete the
.xpak from zone\ and re-link"; the MakeCents launcher ships a "Delete xpak"
button for it. Sources: the Steam guide id 770558798; MakeCents Mod Tools.

## 4. What changed

- **`tools/xpak_report.js`** — the attribution above as a tool: file size,
  holes, builds recorded, stale bake estimate, retired-name assets, groups,
  top entries; `--brief` is one line and exits 2 when more than `--warn-gb`
  (1) of the pack is dead.
- **`build_map.ps1 -CleanPak`** (section 3c) — moves the pack OUT of `zone\`
  (into `usermaps\zm_tower_of_doom\_xpak_prev\`; the upload ships the whole
  `zone\` folder, so a rename inside it would upload too), lets the linker
  write a fresh one, deletes the old pack on BUILD OK, and restores it if no
  fresh pack of plausible size (≥ 256 MB) appears. FULL build only.
  **`-Publish` implies `-CleanPak`** (`-KeepPak` opts out with a warning),
  and every publish build prints the `--brief` report after BUILD OK.
- **`tools/downscale_pack_textures.js`** — caps third-party texture sources
  (the image GDT has no size cap, so the pixels are the only lever): ffprobe
  each `baseImage`, move the original to `<modtools>\_tod_texture_originals\`
  (same volume, instant), write the resized file with ffmpeg (area filter,
  same pixel format and extension, so no GDT changes), record it in
  `manifest.json`; `--restore` moves the originals back.
  **Applied:** the nine perk machines the map sells, cap 1024 — 231 files,
  2115 MB → 179 MB on disk, 0 failures. Deadshot and Elemental Pop were left
  alone (not zoned; they leave with the clean pack).

## 5. Weapon textures — DONE (same day, on the user's explicit go-ahead)

The same tool, cap 2048, on the three packs that carry 4K on first-person
guns (27 files, 827 MB of source: the Leviathan axe's uncompressed TIFFs,
the gift gun, the Klauser fabric). The session's permission classifier
blocked the command twice earlier in the day; with the user's "You can do
that" it ran: **27 resized, 0 failed, 826.9 → 120.3 MB of source** (the axe
TIFFs re-encoded LZW at the same pixel format). The command, for the record:

```
node tools/downscale_pack_textures.js --cap 2048 --apply "_custom/wetegg/leviathanaxe/leviathanaxe.gdt" "source_data/xmas_gun.gdt" "source_data/skye_s4_klauser.gdt"
```

then a FULL build with `-CleanPak`. Expected saving ≈ 350 MB of pack.
Undo: `node tools/downscale_pack_textures.js --restore <same gdts>`.

## 6. Result (first `-CleanPak` full build, 2026-09-03 02:02, dev flags armed)

| | before | after |
|---|---:|---:|
| `zm_tower_of_doom.xpak` | 8.88 GB (9,539,649,536 B) | **2.09 GB (2,240,872,448 B)** |
| deployed `zone\` folder (= the Workshop upload) | 9.9 GB | **2.8 GB** |
| builds recorded in the pack (shadow trees) | 47 | 2 |
| holes | 1389 MB | 43 MB |
| retired-machine bytes | 124 MB | 3 MB |
| perk-machine textures, largest side | 4096 | 1024 |

`node tools/xpak_report.js --brief` on the new pack: dead ~0.05 GB, exit 0.
The `.ff` was fresh (142 MB, 02:02), the `.all.sabs` bank present at 136 MB,
the LED bake ran (BAKED), the old pack was deleted by the verdict step and
`_xpak_prev\` is empty. The build printed the usual pre-existing
`gdtdb /update exited 1` WARN (CHANGELOG has it on every build); the resized
machine sources still re-converted, which the 1024 ceiling in the report
proves. **In-game check still owed:** the perk machines at 1024 and the
reflections from a freshly linked probe set — this build carries the peers'
armed dev flags and is not the publish build.

**Second `-CleanPak` full build (11:27, after the weapon cap, the shield cap
and the Street Sweeper removal):** pack **1.65 GiB (1,768,521,728 B)**,
`zone\` **2315 MiB = 2.43 GB as Steam shows it** (six language packs, the
Japanese/Chinese ones dropped). Report: dead ~0.04 GB, 2 recorded builds; no
image above 2048 remains; shield max side 1024, axe 2048; 0 Street Sweeper
entries; 0 unexpected linker errors; `.all.sabs` 136 MB. From 9.61 GB in the
morning to 2.43 GB: **−75%**, no content removed that a player could reach.

The pack went below the 3.6 GB projection because the machine downscale
landed in the same build (~0.7 GB) and the fresh bake set is ~40 MB, not the
~285 MB the offset clustering estimated for "one build" (a build only
re-emits a probe blob whose content changed, so old clusters were fatter
than a clean link).

## 8. Second pass: "assets that aren't being used" (2026-09-03, user: "no regressions")

`tools/audit_zone_usage.js` (every zone line searched across scripts / Lua /
the .map / GDTs / sound CSVs, with computed-name prefix detection) plus five
read-only research agents, one per candidate family. Findings, with what was
done:

| Candidate | Bytes | Verdict | Action |
|---|---:|---|---|
| Street Sweeper (`weapon,t9_streetsweeper` + `_up`) | 46 MB pack + 30 alias rows | the retired MEDIC class's gun: no `register_gun`, no twins block, no script reference; only a self-referential KEEP block in `gen_tod_sounds.js` | **REMOVED** — two zone lines, the KEEP block, CSV regenerated (diff: exactly the 30 rows) |
| Gift of Death (`xmas_gun`) | 111 MB pack, 7 MB wav | **live**: it is the Death Machine powerup (`_tod_powerups.gsc install_gift_of_death` redirects `level.zombie_powerup_weapon["minigun"]`), user-tuned across v10-v16 | keep; its four 4K textures are in the pending weapon-cap command (§5) |
| "Attachment" textures (`i_attachment(s)_vm_*`, `i_attach_t9_optic_*`, …) | 253 MB | **live**: every class gun's stock / barrel / magazine is an attachment slot (`attachViewModel3-5`), PaP forms carry optics + camo tables; a mesh→material→image reachability pass put 228 MB on referenced meshes | nothing safe to trim in `gen_tod_twins.js`; blanking slots deletes PaP sights |
| Mahem (`s1_mahem`, the Protector's rocket) | 77 MB | live, but only the projectile world model is ever seen; the view model + scope textures ride along because the whole weapon is zoned | design change (swap to a lighter rocket weapon) — not done |
| Per-language packs (`fr_/ge_/…xpak`, 43.5 MB each) | 305 MB total | **fixed cost**: Kingslayer's sprinter body is `japaneseUnsafe 1` in its GDT, and the linker emits any SKU-variant asset + its references into every language pack (retail `en_zm_tomb.xpak` is the same thing); stock's DER share is unavoidable | not done; flipping the flag on the shared install-side GDT might move ~170 MB but overrides the author's SKU declaration, unproven |
| Never-drawn UI images in the `.ff` | 3 MB disk / 54 MB load RAM (36 HIGH + 17 MEDIUM) | real but small: art lanes behind flags forced false, plates for retired domains, 12 retired card sets still in `CARD_SLUG` | optional tidy-up; MEDIUM needs Lua edits first, missing images draw a white square and no lint catches it |

Side findings from the language audit, not size: the `ja_` pack is stale (Aug
26, pre-sprinter) and the Japanese zone excludes the `japaneseUnsafe` body —
what a Japanese client sees for the sprinter is UNVERIFIED; and the linker
rejects the `simplified_chinese` / `traditional_chinese` tokens the script
passes (the tools' own folders are `simplifiedchinese` / `traditionalchinese`),
so no Chinese fastfile has ever shipped — Chinese clients fail at map load.
**Decided the same day (user: "We can remove those languages"):** Japanese and
both Chinese variants are out of `build_map.ps1 -AllLanguages` (six remain),
and the stale deployed `ja_` ff + xpak were deleted from `zone\`. The `$langs`
comment records how to bring one back.

**CORRECTED 2026-09-04 (Workshop report "Could not find zone
'ea_zm_tower_of_doom'", CHANGELOG v17.42):** the "linker rejects the Chinese
tokens" reading above was the UNDERSCORED spelling. The linker's language
tokens are exactly the folder names under `<tools>/zone_source/`
(`englisharabic` → `ea_`, `polish` → `po_`, `simplifiedchinese` → `sc_`,
`traditionalchinese` → `tc_` — every one linked a fresh ff + 43.4 MB xpak
that day). The hand list of six had also never carried English/Arabic or
Polish, so those clients failed at load exactly like French did on Aug 26.
`build_map.ps1` 4b now ENUMERATES the folders (minus all/english) — ALL
twelve variants ship, Japanese included on the user's call (a placeholder
sprinter beats a launch error; the japaneseUnsafe question stays untested).
Cost: five more packs, +~218 MB on the item.

**Third pass (same day, user: "keep searching for low hanging fruit"):** with
the machines small, the pack's largest single item was the RIOT SHIELD's Lv5
model — 13 materials × 5 maps at 2048² = 232 MB for one first-person plate
(only `logical_m_shield_full`'s materials ship; the part_01/02 sets do not).
**Capped at 1024** with the same tool (81 files, 71.8 → 20.0 MB of source, 0
failures; expected ~174 MB less pack after the next clean build). Checked and
left alone: the only 4K images still packed are the Leviathan axe (176 MB)
and the gift gun (48 MB) — exactly what the pending §5 command caps; boss and
zombie bodies top out at 2048 (22 entries, 40 MB) and 1024; the second
skybox in the old pack was a stale entry and is already gone; the retired
Mule Kick's drink can is ~3.5 MB and sits in a boot-time `GetWeapon` table,
not worth the script risk; `i_maul_base` is the Bulldog (a live secondary).
Projected publish after §5 + this: pack ~1.65 GiB, item ~2.4 GB.

**Fourth pass (user: "Protector doesnt even use a rocket on this map"):**
true since 2026-08-20 ("BULLETS ONLY" in `_tod_bosses.gsc`); `mahem_shot()`
had no caller. Function deleted, `weapon,s1_mahem` + `_up` unzoned — the
77 MB leaves on the next clean build. Link-checked (v16.78).

**Sound bank — TRIMMED (user: "we can do the sound bank fix as well").**
Applied from the audit list: `user_aliases` (`test_sound`) dropped from the
.szc; the 19 `t9_sledgehammer` aliases (72 rows) out of `tod_combat_knife.csv`
(their impact def is referenced by no weapon block); `tod_elemental_pop_proc`
out of `tod_ports.csv`; `zm_ai_zod_companion.csv` forked into
`sound/aliases/` under the same name (it shadows the tools-root copy) minus
the 27 civil-protector aliases (69 rows). Kept: `wpn_t6_death_machine_tap`,
the generator's Stoner/Magnum mech/sub families, mechz. Result: `.all.sabl`
64.5 → 51.2 MB, `.all.sabs` 142.6 → 141.9 MB (−14 MB); the alias listing
confirms every trimmed name gone and every neighbour present.

**Sound bank** (before the trim: `.all.sabs` 142.6 MB + `.all.sabl` 64.5 MB, 821 FLAC entries,
every source 48k/16 as the builder requires): 14 alias sources per the .szc,
2,087 rows → 820 wavs → 394 MB raw, none missing. All seven music tracks are
used; the two orphan tracks in the tools-root music folder have no row and do
not pack. Never-referenced aliases (corpus: scripts, Lua, .efx, 4,643 GDT
blocks, alias→alias edges, AND a byte-scan of 2,022 `.xanim_bin` for
notetracks) sum to 26.5 MB raw ≈ 11 MB in-bank: the Shadows-of-Evil civil
protector set inside the shared `zm_ai_zod_companion.csv` (16 MB raw), the
`t9_sledgehammer` aliases in `tod_combat_knife.csv` (4.7 MB — but they ARE
wired through `t9_me_surfacesounddef.gdt`'s impact def, so not dead by
inspection), the mod tools' `test_sound` sample (2.4 MB), Stoner/Magnum
mech/sub/tail families the generator emits (1.5 MB). A lossless-in-effect
lever exists — 65 stereo wavs whose aliases are all 3d (the engine sums
positional sources to mono) ≈ 12 MB packed — but it means re-encoding pack
wavs. Verdict: ~5% of the bank, most of it in a shared install-side CSV;
**nothing changed** under the no-regressions rule.

## 9. Fifth pass — the `.ff` side (2026-09-03, v16.86)

Re-checked after the peer builds v16.79-v16.85. The pack side is done; the
one thing left was in the FASTFILE, which the earlier UI-image audit had
flagged as MEDIUM and v16.80 then showed how to clear safely. Four domains
retired before that pattern existed — **11 echo_rounds, 12 regen, 30
meat_grinder, 34 momentum** — still had their `CARD_SLUG` slugs and all 12
card images zoned. Cards are `uncompressed` 768x1152 = **3.4 MB of load RAM
each**. Slugs + zone lines removed (inert DOMAIN/DETAIL rows and the PNGs
stay): **`.ff` 134.34 → 131.10 MB, −40.5 MB of load-time RAM**, 0 unexpected
linker errors. `docs/87`'s 114-card re-bake excludes all four, confirmed by
two sessions independently before the edit.

Still open, deliberately: **28 GDT image blocks now have no zone line**
(3.55 MB of PNGs — retired cards, retired perk icons, the composite-lane
frame/icon set behind `USE_CARD_SET_ART`, the old gauge tiles). An unzoned
GDT block does NOT enter the `.ff` or the pack, so this is **zero shipped
cost** — repo clutter only, and pruning it while a card art pass is live
would only risk confusion. The other never-drawn set (composite lane, keyed
hint plates, `i_tod_card_base`) is still zoned and still ~1 MB / 14 MB RAM;
it needs the same slug-and-line pairing and a lint that cross-checks Lua
image names against the zone, which does not exist yet.

## 10. The process, made automatic (v16.88a)

**Be accurate about what the 9.6 GB was**, because each cause has its own fix
and only two of the three are automated:

| cause | size | fix | automated? |
|---|---:|---|---|
| build history inside the pack | ~5.3 GB | `-CleanPak`, implied by `-Publish` | **yes** |
| texture resolution on assets the map DOES use | ~1.2 GB | `downscale_pack_textures.js --cap N` | no — a judgement call |
| genuinely unused assets | ~0.13 GB | `audit_zone_usage.js`, `lint_tod_assets.js` | **the recurring case, yes** |

`tools/lint_tod_assets.js` runs on **every** build (`-GscOnly` included) —
both its failure modes are pure zone/Lua edits the linker never reports.
GATE A hard-fails on art a live path names with no `image,` line (a WHITE
SQUARE in game, silent at build): Lua literals, `CARD_SLUG` x rarities (x1
for a `CARD_ONE_IMAGE` domain), live domain ids <= `PAUSE_PLATE_MAX`, and the
8 `TCLS` tier cards. GATE B gates dead art on
`lint_tod_assets.baseline.json`, whose `why` block says which numbers are
accepted. Everything is parsed from the live sources, so renames follow.
`lint_tod_assets_selftest.js` is 9 cases: 6 that must fire, a clean control,
and 2 shapes that must NOT (a concatenation prefix, a one-image card — both
were wrong in the lint's first ten minutes).

**The rule it enforces: a slug and its zone lines are ONE unit.** Half a
retirement is either dead weight (art with no code) or a white square (code
with no art). Five domains were retired half-way before anything checked.

**Two traps this pass paid for, both recorded in CLAUDE.md:** never delete on
a name-grep alone (the gift gun looked unused — it is the Death Machine
powerup, redirected through `level.zombie_powerup_weapon`; the Mahem rocket
looked used — its function existed but nothing had called it since
2026-08-20), and a lint's own model is a claim to be tested (the tier cards
were invisible to the first version, caught by a peer session before the
baseline set; GATE A now reconciles 114-for-114 against an independently
derived list).

## 7. Standing rules that fall out of this

- **Before every publish, the pack is rebuilt from scratch** — `-Publish`
  does it. A publish with `-KeepPak` uploads history and says so.
- **Size questions are answered by `node tools/xpak_report.js`, never by
  reasoning from the asset list.** docs/61 #8 reasoned and was wrong by 5 GB.
- **Texture sources for third-party packs are a knob**, and the knob is
  reversible (`--restore`). The originals live outside the build's inputs.
