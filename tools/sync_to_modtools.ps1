# =============================================================================
# sync_to_modtools.ps1 - Mirror the repo's authoring trees into the BO3
# Mod Tools install. Ported from abandoned_cyber_city_zombies (proven).
#
#   .\tools\sync_to_modtools.ps1            forward sync (repo -> Mod Tools)
#   .\tools\sync_to_modtools.ps1 -DryRun    print only
#   .\tools\sync_to_modtools.ps1 -Reverse   pull Mod Tools edits back (after
#                                           editing the map in Radiant)
#
# Layout facts:
#   repo\scripts\*      -> usermaps\zm_tower_of_doom\scripts\*      (MIRROR)
#   repo\zone_source\*  -> usermaps\zm_tower_of_doom\zone_source\*  (MIRROR)
#   repo\sound\*        -> usermaps\zm_tower_of_doom\sound\*        (MIRROR)
#   repo\ui\*           -> usermaps\zm_tower_of_doom\ui\*           (MIRROR)
#   repo\zone\*         -> usermaps\zm_tower_of_doom\zone\*         (COPY, no
#       delete: Launcher writes workshop.json + publish artifacts here)
#   repo\map_source\zm\zm_tower_of_doom.map -> <tools>\map_source\zm\  (single
#       file COPY - Radiant map sources live in the TOOLS root map_source, not
#       usermaps; never mirror that folder, it holds _prefabs + other maps)
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = "",
    [switch]$DryRun,
    [switch]$Reverse
)

$ErrorActionPreference = "Stop"

$MapName = "zm_tower_of_doom"

function Write-Info($msg) {
    Write-Host "[sync] $msg"
}

function Resolve-ModToolsRoot {
    if ($ModToolsRoot -ne "") { return $ModToolsRoot }

    # The tools may live in the game folder OR a separate "...455130" folder
    # (Steam appends the AppID on name collision - this machine's layout).
    # Require bin\modlauncher.exe as proof, never the folder name.
    $libRoots = @(
        "C:\Program Files (x86)\Steam\steamapps\common",
        "D:\Steam\steamapps\common",
        "E:\Steam\steamapps\common",
        "C:\Steam\steamapps\common"
    )
    foreach ($lib in $libRoots) {
        if (-not (Test-Path $lib)) { continue }
        $dirs = Get-ChildItem $lib -Directory -Filter "Call of Duty Black Ops III*" -ErrorAction SilentlyContinue
        foreach ($d in $dirs) {
            if (Test-Path (Join-Path $d.FullName "bin\modlauncher.exe")) { return $d.FullName }
        }
    }

    throw "Could not auto-detect the Mod Tools root (no folder with bin\modlauncher.exe). Pass -ModToolsRoot explicitly."
}

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        if ($DryRun) {
            Write-Info "DRY: would mkdir $path"
        } else {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

# Mirror = destination becomes an exact copy (robocopy /MIR; deletes extras).
# Copy   = overwrite-copy only; destination-only files survive.
function Copy-Tree($src, $dst, $label, $mirror) {
    if (-not (Test-Path $src)) {
        Write-Info "skip ($label): $src does not exist"
        return
    }

    Ensure-Dir (Split-Path $dst -Parent)

    if ($DryRun) {
        Write-Info "DRY: ${label}: $src -> $dst (mirror=$mirror)"
        return
    }

    Write-Info "${label}: $src -> $dst (mirror=$mirror)"

    $args = @("`"$src`"", "`"$dst`"")
    if ($mirror) { $args += "/MIR" } else { $args += "/E" }
    $args += @("/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/R:2", "/W:1")

    $rc = Start-Process robocopy -NoNewWindow -Wait -PassThru -ArgumentList $args

    # robocopy: 0 = no change, 1 = copied, 2 = extras, 3 = both; >= 8 = failure.
    if ($rc.ExitCode -ge 8) {
        throw "robocopy failed ($label) with exit code $($rc.ExitCode)"
    }
}

function Copy-One($src, $dst, $label) {
    if (-not (Test-Path $src)) {
        Write-Info "skip ($label): $src does not exist"
        return
    }

    Ensure-Dir (Split-Path $dst -Parent)

    if ($DryRun) {
        Write-Info "DRY: ${label}: $src -> $dst"
        return
    }

    Write-Info "${label}: $src -> $dst"
    Copy-Item -Path $src -Destination $dst -Force
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ModTools = Resolve-ModToolsRoot
$MapRoot  = Join-Path $ModTools "usermaps\$MapName"

Write-Info "repo     = $RepoRoot"
Write-Info "modtools = $ModTools"
Write-Info "target   = $MapRoot"
Write-Info "mode     = $(if ($Reverse) {'REVERSE (modtools -> repo)'} else {'FORWARD (repo -> modtools)'})"
if ($DryRun) { Write-Info "DRY RUN - no files will be written" }

# Split-install fix: linker writes the .ff into the TOOLS usermaps, the game
# loads usermaps from the GAME folder -> junction them. Also steam_appid.txt
# for DRM. Idempotent (both already exist from map 1 on this box).
if (-not $Reverse -and -not $DryRun) {
    $gameRoot = $ModTools -replace ' 455130$', ''
    if ($gameRoot -ne $ModTools -and (Test-Path (Join-Path $gameRoot "BlackOps3.exe"))) {
        $gameUsermaps = Join-Path $gameRoot "usermaps"
        if (-not (Test-Path $gameUsermaps)) {
            try {
                New-Item -ItemType Junction -Path $gameUsermaps -Target (Join-Path $ModTools "usermaps") -ErrorAction Stop | Out-Null
                Write-Info "created junction: $gameUsermaps -> $ModTools\usermaps"
            } catch { Write-Info "WARN: could not junction game usermaps ($($_.Exception.Message)); the game may not see builds" }
        }
        $appidFile = Join-Path $gameRoot "steam_appid.txt"
        if (-not (Test-Path $appidFile)) {
            try { [System.IO.File]::WriteAllText($appidFile, "311210"); Write-Info "created steam_appid.txt (311210)" }
            catch { Write-Info "WARN: could not write steam_appid.txt ($($_.Exception.Message))" }
        }
    }
}

if (-not $Reverse) {
    Ensure-Dir $MapRoot
}

$mappings = @(
    @{ Label = "scripts";      RepoRel = "scripts";      ModRel = "scripts";      Mirror = $true  },
    @{ Label = "zone_source";  RepoRel = "zone_source";  ModRel = "zone_source";  Mirror = $true  },
    @{ Label = "sound";        RepoRel = "sound";        ModRel = "sound";        Mirror = $true  },
    @{ Label = "ui";           RepoRel = "ui";           ModRel = "ui";           Mirror = $true  },
    # Aetherium HUD kit: custom TTF fonts (zone `ttf,` lines) + kill-feed strings
    @{ Label = "fonts";            RepoRel = "fonts";            ModRel = "fonts";            Mirror = $true  },
    @{ Label = "localizedstrings"; RepoRel = "localizedstrings"; ModRel = "localizedstrings"; Mirror = $true  },
    # Keep installed third-party animation trees alongside this map's tree.
    @{ Label = "animtrees";    RepoRel = "animtrees";    ModRel = "animtrees";    Mirror = $false },
    # Map-name vision (rawfile,vision/zm_tower_of_doom.vision). The engine sets
    # every client's base vision BY MAP NAME (visionset_mgr_shared.csc
    # finalize_initialization -> GetDvarString("mapname")); with no such file in
    # the .ff the renderer showed its warm-orange fallback — the 2026-08-26
    # "permanent orange tint" report. COPY, not mirror (map 1's rule).
    @{ Label = "vision";       RepoRel = "vision";       ModRel = "vision";       Mirror = $false },
    # Custom level weapon table (stock rows + the class guns). COPY, not mirror.
    @{ Label = "gamedata";     RepoRel = "gamedata";     ModRel = "gamedata";     Mirror = $false },
    @{ Label = "zone";         RepoRel = "zone";         ModRel = "zone";         Mirror = $false }
)

foreach ($m in $mappings) {
    $repoPath = Join-Path $RepoRoot $m.RepoRel
    $modPath  = Join-Path $MapRoot  $m.ModRel

    if ($Reverse) {
        # Never mirror on reverse - the repo has files the tools side lacks.
        Copy-Tree $modPath $repoPath $m.Label $false
    } else {
        Copy-Tree $repoPath $modPath $m.Label $m.Mirror
    }
}

# Radiant map source: single file into the TOOLS root map_source\zm\.
$repoMap = Join-Path $RepoRoot "map_source\zm\$MapName.map"
$modMap  = Join-Path $ModTools "map_source\zm\$MapName.map"

if ($Reverse) {
    Copy-One $modMap $repoMap "map_source"
} else {
    Copy-One $repoMap $modMap "map_source"
}

# Custom prefabs (if this map ever authors its own under map_source\_prefabs\tod).
$repoPrefabs = Join-Path $RepoRoot "map_source\_prefabs\tod"
$modPrefabs  = Join-Path $ModTools "map_source\_prefabs\tod"

if ($Reverse) {
    Copy-Tree $modPrefabs $repoPrefabs "map_source\_prefabs\tod" $false
} else {
    Copy-Tree $repoPrefabs $modPrefabs "map_source\_prefabs\tod" $false
}

# Custom FX sources (repo share\raw\fx\...) land in the TOOLS share tree the
# linker reads. COPY (never mirror) — the tools share tree holds stock + other
# packs. Currently: the acc/light perk-glow recolours ported from map 1.
if (-not $Reverse) {
    Copy-Tree (Join-Path $RepoRoot "share\raw\fx") (Join-Path $ModTools "share\raw\fx") "share\raw\fx" $false
    # CUSTOM SHADER DEFINITIONS (2026-09-23): the SAT Widow's Wine machine's powered
    # panel material is authored on lit_emissive_scroll_3layer_advanced_fullspec, a
    # techsetdef the pack's CODE archive ships and this install never had. Without
    # it the linker builds that material against missing_techsetdef_geometry and the
    # whole front panel (sign, spider crest, red text glow) renders as the engine's
    # grey stand-in once the machine is powered. The def is a stock
    # lit_emissive_scroll_3layer_advanced + the fullspec additions and names only
    # stock shader sources. COPY (never mirror): these trees hold every stock def.
    # verify_perk_machine_presentation.py pins the file and checks both copies;
    # build_map.ps1 fails the link if any material still lands on a missing techset.
    Copy-Tree (Join-Path $RepoRoot "share\raw\techsetdefs_stable") (Join-Path $ModTools "share\raw\techsetdefs_stable") "custom techsetdefs" $false
    Copy-Tree (Join-Path $RepoRoot "share\raw\techsetdefs_stable_toolsgfx") (Join-Path $ModTools "share\raw\techsetdefs_stable_toolsgfx") "custom techsetdefs (toolsgfx)" $false
}

# weaponfull reads this install-side table at link time. Merely zoning an AU
# never enables it. Merge only our 21 presentation rows, preserving other maps.
if (-not $Reverse) {
    if ($DryRun) {
        Write-Info "DRY: merge staff / Thunder Smash linker attachment mappings"
    } else {
        & python (Join-Path $PSScriptRoot "verify_weapon_attachments.py") --install $ModTools
        if ($LASTEXITCODE -ne 0) { throw "Weapon attachment mapping setup failed" }
    }
}

# GDT assets (repo source_data\...) land at the TOOLS ROOT source_data\ — the
# usermap tree is NOT scanned for GDTs. COPY (never mirror) — the tools
# source_data holds stock + every other pack's GDTs. NOTE: after a GDT
# changes, gdtdb /update must run before the linker or it errors "unable to
# locate asset in gdtdb" (build_map.ps1 runs it when repo GDTs are newer).
if (-not $Reverse) {
    Copy-Tree (Join-Path $RepoRoot "source_data") (Join-Path $ModTools "source_data") "source_data (GDTs)" $false
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_cyber_zombie") (Join-Path $ModTools "model_export\tod_cyber_zombie") "cyber zombie models and textures" $false
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_heavenly_altar") (Join-Path $ModTools "model_export\tod_heavenly_altar") "Heavenly Altar models and baked textures" $false
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_baseball_bat") (Join-Path $ModTools "model_export\tod_baseball_bat") "baseball bat models" $false
    Copy-Tree (Join-Path $RepoRoot "xanim_export\tod_baseball_bat") (Join-Path $ModTools "xanim_export\tod_baseball_bat") "baseball bat animations" $false
    # Approved staff animations carry their conversion skeletons with them.
    # Copy only our folders; never mirror the shared installed asset trees.
    Copy-Tree (Join-Path $RepoRoot "xanim_export\tod_staff_approved") (Join-Path $ModTools "xanim_export\tod_staff_approved") "approved staff animations" $false
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_staff_anim") (Join-Path $ModTools "model_export\tod_staff_anim") "staff animation skeletons" $false
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_staff_pap") (Join-Path $ModTools "model_export\tod_staff_pap") "staff PaP models and skeleton" $false
    Copy-Tree (Join-Path $RepoRoot "xanim_export\tod_staff_pap") (Join-Path $ModTools "xanim_export\tod_staff_pap") "staff first-equip flourishes" $false
    # docs/164: Treyarch's fire/lightning staff crystals (world), written by
    # tools/build_staff_crystal.py. Repo-owned, unlike the v18.33 shaft/heads,
    # which still live ONLY in the tools root under model_export\sla\tod_staff.
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_staff_crystal") (Join-Path $ModTools "model_export\tod_staff_crystal") "staff crystals" $false
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_staff_assembly") (Join-Path $ModTools "model_export\tod_staff_assembly") "complete fire and lightning heads" $false
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_staff_retail") (Join-Path $ModTools "model_export\tod_staff_retail") "original BO3 staff material textures" $false
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_thunder_smash") (Join-Path $ModTools "model_export\tod_thunder_smash") "Thunder Smash conversion rig" $false
    Copy-Tree (Join-Path $RepoRoot "xanim_export\tod_thunder_smash") (Join-Path $ModTools "xanim_export\tod_thunder_smash") "Thunder Smash bat lunge" $false
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_perk_machines") (Join-Path $ModTools "model_export\tod_perk_machines") "perk machine animation rigs" $false
    Copy-Tree (Join-Path $RepoRoot "xanim_export\tod_perk_machines") (Join-Path $ModTools "xanim_export\tod_perk_machines") "perk machine purchase animations" $false
    # v18.89: the BO6 ice staff assembly (both models + their _images), written by
    # tools/bo6_extraction/install_ice_staff_bo3.py and pinned by its manifest.
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_bo6_ice") (Join-Path $ModTools "model_export\tod_bo6_ice") "BO6 ice staff models" $false
    # v18.99h: the BO6 RAMPAGE INDUCER (the real one - an Aetherium essence
    # container plus its four crystal shards), written by
    # tools/bo6_extraction/install_inducer_bo3.py.
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_bo6_inducer") (Join-Path $ModTools "model_export\tod_bo6_inducer") "BO6 rampage inducer model (unzoned rollback since 2026-10-02)" $false
    # 2026-10-02: the CYBER Rampage Inducer - one animated model + its baked maps,
    # and its two looping clips, written by tools/inducer_cyber/install_native.py.
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_inducer_cyber") (Join-Path $ModTools "model_export\tod_inducer_cyber") "cyber rampage inducer model" $false
    Copy-Tree (Join-Path $RepoRoot "xanim_export\tod_inducer_cyber") (Join-Path $ModTools "xanim_export\tod_inducer_cyber") "cyber rampage inducer loops" $false
    # v19.64: the fan's Cyber Teddy, the song-hunt bear (model + colour + glow),
    # written by tools/cyber_teddy/build_cyber_teddy.py.
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_cyber_teddy") (Join-Path $ModTools "model_export\tod_cyber_teddy") "fan Cyber Teddy model" $false
    # v19.69: Nikolai's three props - the spawn sign, the crown uplink terminal and
    # the ammo chest (models + maps), written by tools/fan_props/build_fan_props.py.
    Copy-Tree (Join-Path $RepoRoot "model_export\tod_fan_props") (Join-Path $ModTools "model_export\tod_fan_props") "fan props (sign, uplink terminal, ammo chest)" $false
}

# Sound alias CSVs also have to land in share\raw\sound\aliases\ (the linker's
# sound-bank build reads THAT path, not the usermap copy - map 1 lesson). COPY
# (never mirror) so stock sources survive.
if (-not $Reverse) {
    $aliasSrc = Join-Path $RepoRoot "sound\aliases"
    $aliasDst = Join-Path $ModTools "share\raw\sound\aliases"
    if (Test-Path $aliasSrc) {
        Ensure-Dir $aliasDst
        Get-ChildItem $aliasSrc -Filter *.csv | ForEach-Object {
            Copy-One $_.FullName (Join-Path $aliasDst $_.Name) "sound-alias->share\raw"
        }
    }
}

# Wav sources (repo sound_assets\...) land at the TOOLS ROOT sound_assets\ -
# alias FileSpec paths resolve against that tree at sound-bank build. COPY
# (never mirror) - the tools tree holds map 1's + the packs' wavs too.
# *.wav ONLY: a non-wav file in that tree (a README) crashed the bank builder
# with "Object reference not set" (2026-08-19).
if (-not $Reverse) {
    $wavSrc = Join-Path $RepoRoot "sound_assets"
    $wavDstRoot = Join-Path $ModTools "sound_assets"
    if (Test-Path $wavSrc) {
        Get-ChildItem $wavSrc -Recurse -Filter *.wav | ForEach-Object {
            $rel = $_.FullName.Substring($wavSrc.Length + 1)
            $dst = Join-Path $wavDstRoot $rel
            Ensure-Dir (Split-Path $dst -Parent)
            Copy-One $_.FullName $dst "sound_assets (wav)"
        }
    }
}

Write-Info "done"
