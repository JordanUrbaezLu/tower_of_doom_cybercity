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
}

# GDT assets (repo source_data\...) land at the TOOLS ROOT source_data\ — the
# usermap tree is NOT scanned for GDTs. COPY (never mirror) — the tools
# source_data holds stock + every other pack's GDTs. NOTE: after a GDT
# changes, gdtdb /update must run before the linker or it errors "unable to
# locate asset in gdtdb" (build_map.ps1 runs it when repo GDTs are newer).
if (-not $Reverse) {
    Copy-Tree (Join-Path $RepoRoot "source_data") (Join-Path $ModTools "source_data") "source_data (GDTs)" $false
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
