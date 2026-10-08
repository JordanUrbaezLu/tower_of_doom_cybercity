# 174 — Moving development to a new laptop

**2026-10-08.** The user is moving Tower of Doom: Cybercity development to a new laptop
("help transfer all the data needed ... we can't miss anything ... as seamless as possible ...
probably best to go through GitHub as much as possible"). This doc is the plan, the toolchain
list, and the record of what was measured on the old laptop. **Claude on the new laptop: read this
first, then run `tools\migrate\check_machine.ps1`.**

## The idea

**GitHub carries the repo. One bundle carries everything git can't. One script checks it all.**

| What | How it moves | Size (measured 2026-10-08) |
|---|---|---|
| This repo: scripts, tools, docs, map source, GDTs, `art/`, `model_export/`, sounds | **GitHub** (private repo; `.blend` / `.fbx` via Git LFS) | ~3.8 GB of unpushed work + what is already there |
| Map 1 repo (knowledge base), Aetherium HUD upstream | **GitHub** (already pushed, clean) — the import script clones them | — |
| BO3 Mod Tools additions: every pack (skye_ports, vk_mtl, BO6 rips, SATPerks, T7 assets …), the size-pass originals, 30 modified stock files, this map's current build + its Workshop publish files | **Bundle** `tools_overlay\` (sha1 per file) | 86.0 GB / 61,652 files |
| Repo files git does not track: `tmp\` (evidence + restore originals), `local_sync_cache\`, `.blend1` backups | **Bundle** `repo_extras\` | ~11.6 GB |
| `Documents\BO3_tools` (Greyhound + its 24 GB of exports, Saluki, Cordycep, RSX, BO6_Pilot) + `BO3_asset_backups` | **Bundle** `documents\` | 29.7 GB |
| Downloads the tools read: `BO6_Pilot_Export`, Nikolai's `3D Models-*.zip`, every loose file < 50 MB (art pack drops, source audio, reference images) | **Bundle** `downloads\` | ~18.5 GB |
| `test+map` (no remote; holds `tmp\blender-cod`), the Blender MCP addon in Tower II's `tmp\` | **Bundle** `repos\` | 0.7 GB |
| Claude memory + settings, Codex config, Blender 4.2 addons/prefs, BO3 keybinds, Radiant registry prefs, pip freezes | **Bundle** (small) | < 10 MB |
| BO3, Mod Tools, Git, Python, Node, Blender, FFmpeg, 7-Zip, VS Code | **Reinstall** (list below) | — |

**Bundle total ≈ 146 GB** → use an external drive of **256 GB or more** (a network share or a
cloud-synced folder works too; the export script takes any folder and resumes if interrupted).

### How "nothing missed" is proven
- **Tools root:** `bundle_tool.py` reads Steam's own depot manifest for the Mod Tools
  (`Steam\depotcache\455131_7421982922197022459.manifest`: 187,611 stock entries with sha1s) and
  exports every file that is NOT byte-for-byte stock. A fresh Steam install has exactly those stock
  files (the Mod Tools have not changed since 2020), so stock + overlay = this laptop's tools root.
  Every overlay file carries a sha1; the import refuses a mismatch; `check_machine.ps1 -FullHash`
  re-hashes all 86 GB on the new laptop.
- **Repo:** the export refuses to run until every tracked change is committed and pushed, then copies
  every path `git ls-files --others` reports. GitHub + `repo_extras` = this folder.
- **The 30 modified stock files** (found by the manifest compare, would be silently reverted by a
  fresh install): `bin\libtiff64r.dll`, `bin\converter_gdt_dirs_0.txt` (adds `_custom` to the GDT
  scan), `archetypes\archetypes.gdt`, `texture_assets\gfx.gdt`, `xanim_export\t7_ai_zombie.gdt`,
  `model_export\wpn_t7_zmb_weapons.gdt`, `share\raw\...\animation_state_machine_utility.gsc`,
  `share\raw\fx\electric\fx_elec_sparks_burst_xsm_omni_blue_os.efx`,
  `share\raw\gamedata\weapons\common\attachmentmappingsTable.csv`, `zone_source\all\assetlist\zm_patch.csv`
  and 20 stock zombie/prop textures the Sep 10 size pass shrank. All ride the overlay.

## A. Old laptop (this one)

1. **Make the GitHub repo private** (user — only the owner can): github.com/JordanUrbaezLu/tower_of_doom_cybercity
   → Settings → General → Danger Zone → *Change visibility* → Private. It is **public** today, and the
   push in A2 would publish Nikolai's source models, the BO6/BO3-derived assets and licensed music.
2. **Commit + push everything** (Claude does this). The work since Aug 30 is uncommitted (254 changed,
   ~3,600 new files). Pushed in batches so no push nears GitHub's 2 GB cap; `*.blend` and `*.fbx`
   go through Git LFS (`.gitattributes`; `reference_two.blend` is 128 MB, over GitHub's 100 MB file
   limit); `*.blend1` auto-backups and `__pycache__` are ignored (they ride the bundle). Branch:
   `map-content`.
3. **Close BO3, Radiant, the mod launcher and any build.**
4. **Build the bundle** onto the drive (dry run first; it prints every item's size):
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\migrate\export_bundle.ps1 -Dest E:\tod_transfer -DryRun
   powershell -ExecutionPolicy Bypass -File tools\migrate\export_bundle.ps1 -Dest E:\tod_transfer
   ```
   Options: `-IncludeAllDownloads` (all 230 GB of Downloads — the original pack archives, a backup;
   not needed, the installed form rides the overlay), `-IncludeClaudeHistory` (session transcripts,
   ~1.5 GB), `-AllUsermaps` (the other maps' build output, ~31 GB).
5. **Keep this laptop untouched** until the new one has passed B6, built and played.

## B. New laptop

1. **Windows account:** sign in with the **same Microsoft account** (jordana.urbaez@…) so the profile
   folder is again `C:\Users\jorda` — ~19 tools scripts hardcode it (BO6 extraction, Saluki paths,
   cyber teddy, altar portal, luck-orb audio import, `gen_tod_sounds.js`). The build itself does not.
   Then, in an **admin** PowerShell, enable long paths (tool trees exceed 260 characters):
   `Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem LongPathsEnabled 1`
2. **Install the toolchain** (versions = the old laptop's):

   | App | Old laptop | Get it | Notes |
   |---|---|---|---|
   | Steam | — | store.steampowered.com | the default library `C:\Program Files (x86)\Steam` |
   | Call of Duty: Black Ops III | app 311210 | Steam | install FIRST |
   | Black Ops III Mod Tools | app 455130 | Steam → Library → Tools | install SECOND (see B3) |
   | Git for Windows | 2.55.0 (Git LFS 3.7.1, Credential Manager) | `winget install Git.Git` | LFS is included |
   | Python | **3.14.7**, per-user, on PATH | `winget install Python.Python.3.14` | then the import installs `tools\migrate\requirements.txt` (lupa, numpy, pillow, scipy, soundfile) |
   | Node.js | **24.18.0** | nodejs.org (24.x LTS) | every build gate is node; built-ins only, no npm packages |
   | Blender | **4.2.23 LTS** at `C:\Program Files\Blender Foundation\Blender 4.2` | blender.org/download/lts/4-2 | the art scripts call that exact path; 5.2 is not used by this repo |
   | FFmpeg | 8.1.2 full_build | `winget install Gyan.FFmpeg` | two sound tools take `TOD_FFMPEG` if PATH does not find it |
   | 7-Zip | — | `winget install 7zip.7zip` | pack archives |
   | VS Code + Claude Code | extension `anthropic.claude-code` | code.visualstudio.com | also `openai.chatgpt` (Codex) if used |
   | GitHub CLI (optional) | not installed on the old laptop | `winget install GitHub.cli` | |

   Not installed, they come in the bundle: Greyhound, Saluki, Cordycep, RSX (portable, in
   `Documents\BO3_tools`). Only for extracting NEW assets: Black Ops II (Greyhound), BO6 (Saluki),
   Apex (RSX 2.3.0 — the devel build crashes on the Sep 16 materials).
3. **Steam layout (load-bearing).** On the old laptop Steam put the Mod Tools in their own folder
   `...\common\Call of Duty Black Ops III 455130`, and the game sees your builds through a junction
   `...\Call of Duty Black Ops III\usermaps → ...\Call of Duty Black Ops III 455130\usermaps`. **47
   tools scripts name the `... 455130` folder.** Install BO3 then the Mod Tools in the default
   library and Steam should repeat that layout; `import_bundle.ps1` creates the usermaps junction,
   and if Steam instead puts the tools inside the game folder it makes `... 455130` a junction to it.
   **Do not subscribe to your own Workshop item (3788921059)** — the subscribed copy shadows the local
   build (the old laptop currently has one; `check_machine.ps1` warns).
4. **Plug in the drive** (no need to copy the bundle first).
5. **Import:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File E:\tod_transfer\migrate_scripts\import_bundle.ps1
   ```
   It: checks the tools are installed → fixes the Steam layout/junctions → clones this repo
   (`map-content`, LFS pulled; Git Credential Manager asks you to log in to GitHub), map 1 and the
   Aetherium HUD → restores `tmp\` / `local_sync_cache\` → imports the 86 GB overlay with sha1 checks
   → Documents, Downloads, `test+map`, the Blender MCP addon + rebuilt `gold_sword_env` venv →
   Claude memory (into `~\.claude\projects\C--Users-jorda-Repositories-tower-of-doom-cybercity\memory`),
   Claude/Codex settings, Blender addons, BO3 keybinds, Radiant prefs (`Controller_Enabled=false`:
   a gamepad press otherwise opens Preferences and stalls the LED bake) → pip packages → runs B6.
   Safe to re-run; existing settings are kept unless `-Force`.
6. **Check:** `powershell -ExecutionPolicy Bypass -File tools\migrate\check_machine.ps1 -FullHash`
   → must end `READY TO BUILD: 0 FAIL`. WARNs only matter for art/extraction work.
7. **First full build** (Claude runs it, as always): `.\tools\build_map.ps1`. It re-converts the
   assets the map uses (`share\assetconvert` was not transferred — it regenerates), so it takes
   longer than usual. Success = a fresh `.ff` (CLAUDE.md "Build / run"). Until it runs, the bundle's
   copy of the current build already sits in `usermaps\zm_tower_of_doom\zone` and is playable.
8. **Play-test** (the user, `PLAY_NORMAL.bat`). Then log in to Claude Code / Codex, open the repo
   folder in VS Code, and confirm Claude sees the memory (`MEMORY.md` index loads at session start).

## Paths that must stay the same

| Path | Why |
|---|---|
| `C:\Users\jorda\…` | ~19 tools scripts; Claude's memory folder name is derived from the repo path |
| `C:\Users\jorda\Repositories\tower_of_doom_cybercity` | memory key; sibling paths `..\abandoned_cyber_city_zombies`, `..\test+map`, `..\tower_of_doom_II_hellbound\tmp\…` |
| `C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130` | 47 tools scripts (build_map/sync auto-detect, the rest do not) |
| `C:\Program Files\Blender Foundation\Blender 4.2\blender.exe` | every Blender-driven art script |
| `C:\Users\jorda\Documents\BO3_tools\{Greyhound,Saluki,BO6_Pilot}` | BO6 extraction + `build_staff_crystal.py` |
| `C:\Users\jorda\Downloads\{BO6_Pilot_Export,3D Models-*.zip,…}` | re-running the BO6 ports, the fan props, the luck-orb / bat audio imports (no build gate reads Downloads) |

## Not transferred, on purpose

- `share\assetconvert` (24 GB, 942k files — the converter's cache; regenerates) and `gdtdb`.
- The other maps' build output under `usermaps\` (31 GB; their own builds recreate it — `-AllUsermaps`
  keeps it) and `usermaps\zm_tower_of_doom\_xpak_prev` (7.5 GB of dead backups, awaiting deletion).
- The Downloads pack archives (~212 GB — T7 Assets, VK parts, SATPerks, Skye packs …): the overlay
  carries their installed, post-edit form. `-IncludeAllDownloads` if you want them as a backup.
- Credentials (`.claude\.credentials.json`, `.codex\auth.json`, git): log in again.
- BO3 crash dumps, `C:\BO3Tools\TOD2Cybercity` (Tower II's own tools copy).
- **Tower II** (`tower_of_doom_II_cybercity` 78 GB, `tower_of_doom_II_hellbound` 36 GB locally, both on
  GitHub — and both **public**): out of scope; clone them later. The Hellbound / TOD2 raw Apex exports in
  Downloads (~18 GB) are their only copy — bring them with `-IncludeAllDownloads` or by hand if Tower II
  moves too. If you clone `tower_of_doom_II_hellbound` later, its folder already exists (the import put
  `tmp\` there): `git init; git remote add origin <url>; git fetch; git checkout -f main` inside it.

## Files

- `tools/migrate/export_bundle.ps1` — old laptop; builds the bundle (`-DryRun` sizes it).
- `tools/migrate/import_bundle.ps1` — new laptop; clone + restore + check.
- `tools/migrate/check_machine.ps1` — read-only readiness check (passes 0 FAIL on the old laptop).
- `tools/migrate/bundle_tool.py` + `steam_manifest.py` — the stock-vs-added classifier, sha1 copy,
  import, verify (stdlib only). Tested end-to-end 2026-10-08 on a fake tools root: exclusions,
  >260-char paths, Unicode names, resume, full-hash verify, a corrupted bundle file refused.
- `tools/migrate/requirements.txt`, `requirements-blender-mcp.txt` — Python packages.

## Status (2026-10-08)

Plan + scripts written and tested on the old laptop (`check_machine.ps1`: 0 FAIL; export dry run
measured every item). **Waiting on:** the repo made private (A1) → commit + push (A2) → the real
export onto a drive (A4). The new laptop has not been set up yet.
