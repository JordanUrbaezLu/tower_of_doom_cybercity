# 174 — Moving development to a new laptop

**2026-10-08.** The user is moving Tower of Doom: Cybercity development to a new laptop
("help transfer all the data needed ... we can't miss anything ... as seamless as possible ...
probably best to go through GitHub as much as possible"). This doc is the plan, the toolchain
list, and the record of what was measured on the old laptop. **Claude on the new laptop: read this
first. After the import, `tools\migrate\check_machine.ps1` says whether the machine is ready.**

## The idea

**GitHub carries the repo. One bundle carries everything git can't. One script checks it all.**

| What | How it moves | Size (measured 2026-10-08) |
|---|---|---|
| This repo: scripts, tools, docs, map source, GDTs, `art/`, `model_export/`, sounds — **every file byte-for-byte** | **GitHub** (`map-content`; `.blend` / `.fbx` via Git LFS) | ~3.9 GB pushed 2026-10-08 |
| Map 1 repo (knowledge base), Aetherium HUD upstream | **GitHub** (already pushed, clean) — the import clones them | — |
| BO3 Mod Tools additions: every pack (skye_ports, vk_mtl, BO6 rips, SATPerks, T7 assets …), the size-pass originals, 30 modified stock files, this map's current build + its Workshop publish files | **Bundle** `tools_overlay\` (sha1 per file) | 86.0 GB / 61,652 files |
| Repo files git does not track: `tmp\` (evidence + restore originals), `local_sync_cache\`, `.blend1` backups, root scratch files | **Bundle** `repo_extras\` | ~11.6 GB |
| `Documents\BO3_tools` (Greyhound + its 24 GB of exports, Saluki, Cordycep, RSX, BO6_Pilot) + `BO3_asset_backups` | **Bundle** `documents\` | 29.7 GB |
| Downloads the tools read: `BO6_Pilot_Export`, Nikolai's `3D Models-*.zip`, every loose file < 50 MB (art pack drops, source audio, reference images) | **Bundle** `downloads\` | ~18.5 GB |
| `test+map` (no remote; **its `tmp\blender-cod` is PyCoD, which build gates load**); from Tower II hellbound `tmp\blender_mcp_vendor` + `tools\bo6_extraction` | **Bundle** `repos\` | 0.7 GB |
| Claude memory + settings, Codex config/rules/skills/memories, Blender 4.2 addons (**BetterBetterBlenderCOD = PyCoD for 6 build gates**) + prefs, BO3 keybinds, Radiant registry prefs, git identity, pip freezes | **Bundle** (small) | < 50 MB |
| BO3, Mod Tools, Git, Python, Node, Blender, FFmpeg, 7-Zip, VS Code | **Reinstall** (list below) | — |

**Bundle total ≈ 146 GB.** This laptop has only ~40 GB free, so the bundle goes **straight** to its
destination: an external drive of **256 GB or more**, or a shared folder on the new laptop over the
home network (`-Dest \\NEWLAPTOP\tod_transfer`). The export resumes if interrupted. (2026-10-08: the
USB cable between the two laptops showed up as nothing on this side — no drive, no network link.)

### How "nothing missed" is proven
- **Tools root:** `bundle_tool.py` reads Steam's own depot manifest for the Mod Tools
  (`Steam\depotcache\455131_7421982922197022459.manifest`: 186,026 stock files with sha1s) and
  exports every file that is NOT byte-for-byte stock (every same-size stock file is hashed). A fresh
  Steam install has exactly those stock files (the Mod Tools have not changed since 2020), so
  stock + overlay = this laptop's tools root. Each overlay file carries a sha1; the import refuses a
  mismatch; `check_machine.ps1 -FullHash` re-hashes all 86 GB. Unreadable paths FAIL the export.
- **Repo:** the export refuses to run until every tracked change is committed and pushed, then copies
  every path `git ls-files --others` reports. GitHub + `repo_extras` = this folder.
- **Line endings (fixed 2026-10-08, commit 8be5af0):** ~389 working files were CRLF on disk while
  `.gitattributes` (`* text=auto eol=lf`) made every clone LF — and many build gates pin the exact
  bytes (`gen_tod_amp63.js --check` failed on a simulated clone). `.gitattributes` is now `* -text`:
  git stores and checks out every file byte-for-byte, regardless of Git for Windows' `autocrlf`.
  `check_machine.ps1` runs that gate as a canary.
- **The 30 modified stock files** (would be silently reverted by a fresh install): `bin\libtiff64r.dll`,
  `bin\converter_gdt_dirs_0.txt` (adds `_custom` to the GDT scan), `archetypes\archetypes.gdt`,
  `texture_assets\gfx.gdt`, `xanim_export\t7_ai_zombie.gdt`, `model_export\wpn_t7_zmb_weapons.gdt`,
  `share\raw\...\animation_state_machine_utility.gsc`,
  `share\raw\fx\electric\fx_elec_sparks_burst_xsm_omni_blue_os.efx`,
  `share\raw\gamedata\weapons\common\attachmentmappingsTable.csv`, `zone_source\all\assetlist\zm_patch.csv`
  and 20 stock zombie/prop textures the Sep 10 size pass shrank. All ride the overlay.
- **Reviewed:** a script reviewer and a coverage auditor (2026-10-08) found 2 blockers + 9 bugs in the
  first draft and 2 build-breaking gaps (line endings; the `TA_*` environment). All fixed; the copy
  logic is tested end-to-end (exclusions, >260-char paths, Unicode names, resume, junctions not
  followed, full-hash verify, a corrupted bundle file refused, a newer local file never rolled back).
  The new laptop's Claude then caught one more (2026-10-08): Steam stamps a fresh install with the
  INSTALL time, so the 30 untouched stock files looked newer than the bundle's modified copies and
  the "never roll back newer work" rule kept the stock ones. Now a newer local file is kept only if it
  is NOT byte-for-byte stock (hashed against the depot manifest), and verify FAILs on a stock copy left
  where a modified one belongs (tested with a real stock file).

## A. Old laptop (this one)

1. **Visibility:** the GitHub repo stays **public** — the user's call (2026-10-08), made after being
   told it publishes Nikolai's source models, the BO6/BO3-derived assets and licensed music.
2. **Commit + push everything** — done 2026-10-08 on `map-content`, in batches (code+docs, sources,
   models, art via LFS, the line-ending fix, the migration scripts). Each push stays far under GitHub's
   2 GB cap; `*.blend` / `*.fbx` ride Git LFS (`reference_two.blend` is 128 MB, over the 100 MB file
   limit; free LFS = 10 GiB storage + 10 GiB download/month, ~1 GB used); `*.blend1` and `__pycache__`
   are ignored (they ride the bundle). Anything edited later: commit + push again before exporting.
3. **Close BO3, Radiant, the mod launcher and any build.**
4. **Build the bundle** (dry run first; it prints every item's size and warns about anything missing):
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\migrate\export_bundle.ps1 -Dest E:\tod_transfer -DryRun
   powershell -ExecutionPolicy Bypass -File tools\migrate\export_bundle.ps1 -Dest E:\tod_transfer
   ```
   It ends `BUNDLE OK`, or FAILs listing any required item it could not find. Options:
   `-IncludeAllDownloads` (all 230 GB of Downloads — the original pack archives, a backup; not needed,
   the installed form rides the overlay), `-IncludeAgentHistory` (Claude transcripts ~1.5 GB + Codex
   sessions ~3.8 GB), `-AllUsermaps` (the other maps' build output, ~31 GB).
5. **Keep this laptop untouched** until the new one has passed B6, built and played.

## B. New laptop

1. **Windows account:** sign in with the **same Microsoft account** (jordana.urbaez@…) so the profile
   folder is again `C:\Users\jorda`. ~19 tools scripts hardcode it, and so do **two build-gate
   dependencies**: PyCoD is loaded from `C:\Users\jorda\Repositories\test+map\tmp\blender-cod` and from
   `%APPDATA%\Blender Foundation\Blender\4.2\scripts\addons\BetterBetterBlenderCOD`.
   Then, in an **admin** PowerShell, enable long paths (tool trees exceed 260 characters):
   `Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem LongPathsEnabled 1`
2. **Install the toolchain** (versions = the old laptop's):

   | App | Old laptop | Get it | Notes |
   |---|---|---|---|
   | Steam | — | store.steampowered.com | the default library `C:\Program Files (x86)\Steam` |
   | Call of Duty: Black Ops III | app 311210 | Steam | install FIRST |
   | Black Ops III Mod Tools | app 455130 | Steam → Library → Tools | install SECOND (see B3) |
   | Git for Windows | 2.55.0 (Git LFS 3.7.1, Credential Manager) | `winget install Git.Git` | LFS is included |
   | Python | **3.14.7**, per-user, on PATH | `winget install Python.Python.3.14` | the import installs `tools\migrate\requirements.txt` (lupa, numpy, pillow, scipy, soundfile — build gates need all five) |
   | Node.js | **24.18.0** | nodejs.org (24.x LTS) | most build gates are node; built-ins only, no npm packages |
   | Blender | **4.2.23 LTS** at `C:\Program Files\Blender Foundation\Blender 4.2` | blender.org/download/lts/4-2 | the art scripts call that exact path; 5.2 is not used by this repo |
   | FFmpeg | 8.1.2 full_build (winget) | `winget install Gyan.FFmpeg --version 8.1.2` | three sound tools default to that exact winget folder; on another version the import sets `TOD_FFMPEG` (two honour it; `install_ice_staff_bo3.py` does not) |
   | 7-Zip | — | `winget install 7zip.7zip` | pack archives |
   | VS Code + Claude Code | extension `anthropic.claude-code` | code.visualstudio.com | also `openai.chatgpt` (Codex) if used |
   | GitHub CLI (optional) | not installed on the old laptop | `winget install GitHub.cli` | |

   Not installed, they come in the bundle: Greyhound, Saluki, Cordycep, RSX (portable, in
   `Documents\BO3_tools`). Only for extracting NEW assets: Black Ops II (Greyhound), BO6 (Saluki),
   Apex (RSX 2.3.0 — the devel build crashes on the Sep 16 materials).
3. **Steam layout (load-bearing).** On the old laptop Steam put the Mod Tools in their own folder
   `...\common\Call of Duty Black Ops III 455130`, and the game sees your builds through a junction
   `...\Call of Duty Black Ops III\usermaps → ...\Call of Duty Black Ops III 455130\usermaps`. **47
   tools scripts name the `... 455130` folder.** Install BO3 then the Mod Tools in the default library
   and Steam should repeat that layout; `import_bundle.ps1` creates the usermaps junction, and if Steam
   instead puts the tools inside the game folder it makes `... 455130` a junction to it. Steam's Mod
   Tools installer also writes `TA_GAME_PATH` / `TA_TOOLS_PATH` / `TA_LOCAL_ASSET_CACHE` (user
   environment) — cod2map64 and Radiant refuse to run without them; the import sets any that are
   missing. **Do not subscribe to your own Workshop item (3788921059)** — the subscribed copy shadows
   the local build (the old laptop has one; `check_machine.ps1` warns).
4. **Before the import, don't open BO3 or Blender** (their first launch writes config the import then
   keeps — it warns if so). Plug in the drive (no need to copy the bundle to the laptop first).
5. **Import:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File E:\tod_transfer\migrate_scripts\import_bundle.ps1
   ```
   It: checks the tools are installed → fixes the Steam layout / junctions / `TA_*` environment →
   sets the git identity → clones this repo (`map-content`, then a checked `git lfs pull`; Git
   Credential Manager asks you to log in to GitHub), map 1 and the Aetherium HUD → restores the
   untracked repo files (never over a file the clone has) → imports the 86 GB overlay with sha1 checks
   (never over a file newer on this machine) → Documents, Downloads, `test+map`, Tower II's MCP addon +
   BO6 loaders, a rebuilt `gold_sword_env` venv → Claude memory (into
   `~\.claude\projects\C--Users-jorda-Repositories-tower-of-doom-cybercity\memory`), Claude/Codex
   settings, Blender addons + prefs, BO3 keybinds, Radiant prefs (`Controller_Enabled=false`: a gamepad
   press otherwise opens Preferences and stalls the LED bake), `TOD_FFMPEG` if needed → pip packages →
   runs B6. Safe to re-run; existing settings are kept unless `-Force`.
6. **Check:** in a **new** terminal (the environment variables apply to new ones):
   `powershell -ExecutionPolicy Bypass -File tools\migrate\check_machine.ps1 -FullHash`
   → must end `READY TO BUILD: 0 FAIL`. WARNs only matter for art / extraction work. Run it again
   whenever the setup is in doubt — it is read-only, and it never asks to re-import over newer work.
7. **First full build** (Claude runs it, as always): `.\tools\build_map.ps1`. It re-converts the
   assets the map uses (`share\assetconvert` was not transferred — it regenerates), so it takes
   longer than usual. Success = a fresh `.ff` (CLAUDE.md "Build / run"). Until it runs, the bundle's
   copy of the current build already sits in `usermaps\zm_tower_of_doom\zone` and is playable.
8. **Play-test** (the user, `PLAY_NORMAL.bat`). Then log in to Claude Code / Codex, open the repo
   folder in VS Code, and confirm Claude sees the memory (`MEMORY.md` index loads at session start).

## Paths that must stay the same

| Path | Why |
|---|---|
| `C:\Users\jorda\…` | ~19 tools scripts + the two PyCoD build-gate paths; Claude's memory folder name comes from the repo path |
| `C:\Users\jorda\Repositories\tower_of_doom_cybercity` | memory key; siblings `..\abandoned_cyber_city_zombies`, `..\test+map\tmp\blender-cod` (build gates), `..\tower_of_doom_II_hellbound\{tmp,tools\bo6_extraction}` |
| `%APPDATA%\Blender Foundation\Blender\4.2\scripts\addons\BetterBetterBlenderCOD` | six build gates import PyCoD from it |
| `C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130` | 47 tools scripts (build_map/sync auto-detect, the rest do not) + `TA_*` env |
| `C:\Program Files\Blender Foundation\Blender 4.2\blender.exe` | every Blender-driven art script |
| `C:\Users\jorda\Documents\BO3_tools\{Greyhound,Saluki,BO6_Pilot}` | BO6 extraction + `build_staff_crystal.py` (Greyhound exports) |
| `C:\Users\jorda\Downloads\{BO6_Pilot_Export,3D Models-*.zip,…}` | re-running the BO6 ports, the fan props, the luck-orb / bat audio imports (no build gate reads Downloads) |
| `...\WinGet\Packages\Gyan.FFmpeg_...\ffmpeg-8.1.2-full_build` | the rampage-sting / inducer / ice-staff sound tools (or `TOD_FFMPEG`) |

## Not transferred, on purpose

- `share\assetconvert` (24 GB, 942k files — the converter's cache; regenerates) and `gdtdb`.
- The other maps' build output under `usermaps\` (31 GB; their own builds recreate it — `-AllUsermaps`
  keeps it; junctions such as `usermaps\zm_tod2_cybercity` are never followed) and
  `usermaps\zm_tower_of_doom\_xpak_prev` (7.5 GB of dead backups, awaiting deletion).
- The Downloads pack archives (~212 GB — T7 Assets, VK parts, SATPerks, Skye packs …): the overlay
  carries their installed, post-edit form. `-IncludeAllDownloads` if you want them as a backup.
- Credentials (`.claude\.credentials.json`, `.codex\auth.json`, git): log in again.
- BO3 crash dumps, `C:\BO3Tools\TOD2Cybercity` (Tower II's own tools copy).
- **Tower II** is out of scope, and note: `tower_of_doom_II_hellbound`'s GitHub repo holds ONE file —
  its 36 GB live only on the old laptop, as does most of `tower_of_doom_II_cybercity` (78 GB). The
  Hellbound / TOD2 raw Apex exports in Downloads (~18 GB) are their only copy. Moving Tower II is its
  own job. If you clone `tower_of_doom_II_hellbound` later, its folder already exists (the import put
  `tmp\` and `tools\bo6_extraction` there): `git init; git remote add origin <url>; git fetch;
  git checkout -f main` inside it.

## Files

- `tools/migrate/export_bundle.ps1` — old laptop; builds the bundle (`-DryRun` sizes it).
- `tools/migrate/import_bundle.ps1` — new laptop; clone + restore + check.
- `tools/migrate/check_machine.ps1` — read-only readiness check (0 FAIL on the old laptop).
- `tools/migrate/bundle_tool.py` + `steam_manifest.py` — the stock-vs-added classifier, sha1 copy,
  import, verify, untracked-file copy (stdlib only).
- `tools/migrate/requirements.txt`, `requirements-blender-mcp.txt` — Python packages.

## Status (2026-10-09)

**Export done: `BUNDLE OK` 2026-10-09 00:03:47** over Wi-Fi into `\\10.0.0.149\tod_transfer`
(= `C:\tod_transfer` on the new laptop JORDANURBAEZLU): **155,361 files / 147.25 GB**, matching the
new laptop's own count; 0 warnings, 0 missing required items; scripts from `b0f941b`. The overlay is
61,720 files: 30 resized + **71 same-size-but-different** stock files (only the full hash finds those)
plus every pack. Next: the new laptop runs B5–B8 (import, check, first build, play).

What the Wi-Fi export taught (each fixed in `tools/migrate`, all on `map-content`):
- **Never a per-file network round trip.** One-at-a-time copy ran 2–4 MB/s on a link robocopy fills
  at 24 MB/s; the fixes are parallel copies (Python 32, robocopy `/MT:64`), no `.part`/rename/set-time
  on export, and folder LISTINGS instead of per-file stats for resume checks, copylist and `du`.
- **Keep the progress record on the exporting machine** (`%LOCALAPPDATA%\tod_migrate`, keyed by the
  bundle's `bundle_id.txt`); written over SMB it fell ~27k files behind the copiers and a drop lost
  the backlog. At the end the COMPLETE record goes to both places — copying the local file over the
  share's once erased share-only entries.
- **A laptop that is unplugged and closed goes into Modern Standby with Wi-Fi off** (Kernel-Power 172
  "Adaptive Connected Standby"); `SetThreadExecutionState` cannot stop that. Keep it plugged in and open.
- PS 5.1: `New-Item` on a share root throws; a killed robocopy exits `-1` (treat as failure).
