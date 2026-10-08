# check_machine.ps1 - is this machine ready to build and play Tower of Doom: Cybercity? (docs/174)
#
#   powershell -ExecutionPolicy Bypass -File tools\migrate\check_machine.ps1            # quick (sizes)
#   powershell -ExecutionPolicy Bypass -File tools\migrate\check_machine.ps1 -FullHash  # re-hash the 86 GB overlay
#
# Read-only. Prints PASS / WARN / FAIL per item and exits 1 on any FAIL. A FAIL blocks building or
# playing; a WARN only matters for art / extraction work. Runs on the old laptop too (as a control).
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$SteamCommon = 'C:\Program Files (x86)\Steam\steamapps\common',
    [string]$OverlayManifest = '',
    [switch]$FullHash
)
$ErrorActionPreference = 'Continue'
$script:fails = 0; $script:warns = 0
function Pass($m) { Write-Host "  PASS  $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  WARN  $m" -ForegroundColor Yellow; $script:warns++ }
function Fail($m) { Write-Host "  FAIL  $m" -ForegroundColor Red; $script:fails++ }
function Check([bool]$ok, [string]$pass, [string]$bad, [switch]$WarnOnly) {
    if ($ok) { Pass $pass } elseif ($WarnOnly) { Warn $bad } else { Fail $bad }
}
function Cmd($n) { (Get-Command $n -ErrorAction SilentlyContinue) }

$H = $env:USERPROFILE
$ReposDir = Split-Path $RepoRoot -Parent
$Game  = Join-Path $SteamCommon 'Call of Duty Black Ops III'
$Tools = Join-Path $SteamCommon 'Call of Duty Black Ops III 455130'

Write-Host "== Windows"
Check ($H -eq 'C:\Users\jorda') "profile is C:\Users\jorda" "profile is $H - ~19 tools scripts hardcode C:\Users\jorda (docs/174 'Paths'); the build itself is fine" -WarnOnly
$lpe = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction SilentlyContinue).LongPathsEnabled
Check ($lpe -eq 1) 'long paths enabled' 'long paths OFF - admin PowerShell: Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem LongPathsEnabled 1'
$free = (Get-PSDrive C).Free / 1e9
Check ($free -ge 60) ("C: free {0:N0} GB" -f $free) ("C: free only {0:N0} GB - the first full build regenerates ~24 GB of converter cache" -f $free) -WarnOnly

Write-Host "== Toolchain"
Check ([bool](Cmd git)) "git: $(git --version 2>$null)" 'git missing (winget install Git.Git)'
$lfs = (git lfs version 2>$null); Check ([bool]$lfs) "git-lfs: $lfs" 'git-lfs missing (comes with Git for Windows) - Blender masters / FBX sources would be pointer files'
Check ("$(git config --global core.longpaths)" -eq 'true') 'git core.longpaths=true' 'git config --global core.longpaths true' -WarnOnly
$nv = (node --version 2>$null)
Check ($nv -match '^v(\d+)' -and [int]$matches[1] -ge 24) "node $nv" "node $nv - need Node 24+ (the sky tool writes Float16 EXR; every build gate is node)"
$pyv = (python --version 2>&1)
Check ("$pyv" -match '^Python 3\.(1[1-9])') "$pyv" "python missing or too old ($pyv) - install Python 3.14 'Add to PATH'"
Check ("$pyv" -match '^Python 3\.14') 'python is 3.14 (same as the old laptop)' "$pyv is not 3.14 - fine for the build, but the MCP venv was 3.14" -WarnOnly
& python -c "import numpy, PIL, scipy, soundfile; from lupa.lua51 import LuaRuntime" 2>$null
Check ($LASTEXITCODE -eq 0) 'python packages: numpy pillow scipy soundfile lupa' 'python packages missing - python -m pip install -r tools\migrate\requirements.txt'
Check ([bool](Cmd ffmpeg)) "ffmpeg: $((Cmd ffmpeg).Source)" 'ffmpeg not on PATH (winget install Gyan.FFmpeg; set TOD_FFMPEG for the two sound tools if needed)' -WarnOnly
Check (Test-Path 'C:\Program Files\7-Zip\7z.exe') '7-Zip installed' '7-Zip missing (winget install 7zip.7zip) - pack archives' -WarnOnly
$blender = 'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe'
Check (Test-Path $blender) 'Blender 4.2 LTS at the scripted path' "Blender 4.2 LTS not at $blender - every art/model script calls this exact path" -WarnOnly
$addons = Join-Path $env:APPDATA 'Blender Foundation\Blender\4.2\scripts\addons'
Check ((Test-Path (Join-Path $addons 'BetterBetterBlenderCOD')) -and (Test-Path (Join-Path $addons 'io_scene_cast'))) 'Blender addons BetterBetterBlenderCOD + io_scene_cast' 'Blender CoD/Cast addons missing from %APPDATA%\Blender Foundation\Blender\4.2\scripts\addons' -WarnOnly

Write-Host "== Steam / BO3"
Check (Test-Path (Join-Path $Game 'BlackOps3.exe')) "BO3 at $Game" "BO3 not found at $Game"
Check (Test-Path (Join-Path $Tools 'bin\modlauncher.exe')) "Mod Tools at $Tools" "Mod Tools not at $Tools - 47 tools scripts name this exact folder (import_bundle.ps1 makes a junction if Steam put them elsewhere)"
$gu = Get-Item (Join-Path $Game 'usermaps') -Force -ErrorAction SilentlyContinue
$merged = (Test-Path (Join-Path $Game 'bin\modlauncher.exe'))
Check ($merged -or ($gu -and $gu.LinkType -eq 'Junction')) 'game\usermaps reaches the tools usermaps' 'game\usermaps is not a junction to the tools usermaps - the game will not see your builds (import_bundle.ps1 creates it)'
$ws = Join-Path $Tools 'usermaps\zm_tower_of_doom\zone\workshop.json'
Check (Test-Path $ws) 'Workshop publish file (zone\workshop.json) present' 'workshop.json missing - publishing would create a NEW Workshop item instead of updating yours'
Check (-not (Test-Path (Join-Path $SteamCommon '..\workshop\content\311210\3788921059'))) 'not subscribed to your own Workshop item' 'subscribed to your own Workshop item - unsubscribe, the subscribed copy shadows your local build' -WarnOnly
$cte = (Get-ItemProperty 'HKCU:\Software\Treyarch\Radiant\Prefs' -ErrorAction SilentlyContinue).Controller_Enabled
Check ("$cte" -eq 'false') 'Radiant Controller_Enabled=false' 'Radiant Controller_Enabled is not false - a gamepad press opens Preferences and stalls the LED bake (reg import registry\treyarch.reg)' -WarnOnly

Write-Host "== Repos"
Check (Test-Path (Join-Path $RepoRoot '.git')) "repo at $RepoRoot" "repo not found at $RepoRoot"
if (Test-Path (Join-Path $RepoRoot '.git')) {
    $br = git -C $RepoRoot rev-parse --abbrev-ref HEAD
    Check ($br -eq 'map-content') "branch $br" "on branch $br (work happens on map-content)" -WarnOnly
    $ptr = Get-ChildItem (Join-Path $RepoRoot 'art') -Recurse -Include *.blend, *.fbx -ErrorAction SilentlyContinue | Where-Object { $_.Length -lt 1024 }
    Check (@($ptr).Count -eq 0) 'LFS files are real (no pointer stubs)' "$(@($ptr).Count) .blend/.fbx files are LFS pointers - run: git -C `"$RepoRoot`" lfs pull"
    foreach ($d in 'tmp', 'local_sync_cache', 'art', 'model_export') {
        Check (Test-Path (Join-Path $RepoRoot $d)) "repo\$d present" "repo\$d missing (tmp + local_sync_cache come from the bundle's repo_extras)" -WarnOnly
    }
}
Check (Test-Path (Join-Path $ReposDir 'abandoned_cyber_city_zombies\sound\aliases\acc_skye_box_weapons.csv')) 'map 1 repo (knowledge base; gen_tod_sounds reads it)' 'map 1 repo missing - git clone https://github.com/JordanUrbaezLu/abandoned_cyber_city_zombies' -WarnOnly
Check (Test-Path (Join-Path $ReposDir 'test+map\tmp\blender-cod\io_scene_cod')) 'test+map\tmp\blender-cod (BO6 extraction scripts)' 'test+map\tmp\blender-cod missing (bundle repos\test+map)' -WarnOnly
$venvPy = Join-Path $ReposDir 'tower_of_doom_II_hellbound\tmp\gold_sword_env\Scripts\python.exe'
$mcpOk = $false
if (Test-Path $venvPy) { & $venvPy -c "import mcp, blender_mcp" 2>$null; $mcpOk = ($LASTEXITCODE -eq 0) }
Check $mcpOk 'Blender MCP client venv (gold_sword_env) imports mcp + blender_mcp' 'Blender MCP venv missing/broken (art sessions only)' -WarnOnly

Write-Host "== Personal data"
$key = $RepoRoot -replace '[^A-Za-z0-9]', '-'
Check (Test-Path (Join-Path $H ".claude\projects\$key\memory\MEMORY.md")) 'Claude project memory in place' "Claude memory missing at ~\.claude\projects\$key\memory" -WarnOnly
Check (Test-Path (Join-Path $H 'Documents\BO3_tools\Greyhound')) 'Documents\BO3_tools (Greyhound, Saluki, RSX ...)' 'Documents\BO3_tools missing (extraction tools + their exports)' -WarnOnly
Check (Test-Path (Join-Path $H 'Downloads\BO6_Pilot_Export')) 'Downloads\BO6_Pilot_Export (BO6 raw exports)' 'Downloads\BO6_Pilot_Export missing (only needed to re-run the BO6 ports)' -WarnOnly

Write-Host "== Mod Tools overlay"
if ($OverlayManifest -eq '') { $OverlayManifest = Join-Path $RepoRoot 'tmp\migration\overlay_manifest.json' }
if (Test-Path $OverlayManifest) {
    $a = @((Join-Path $PSScriptRoot 'bundle_tool.py'), 'overlay-verify', '--manifest', $OverlayManifest, '--tools', $Tools)
    if (-not $FullHash) { $a += '--quick' }
    & python @a | Where-Object { "$_" -notmatch '^\s+verify:' } | ForEach-Object { Write-Host "        $_" }
    Check ($LASTEXITCODE -eq 0) "every transferred tools file present$(if ($FullHash) { ' and sha1-identical' } else { ' (sizes; -FullHash re-hashes)' })" 'tools overlay incomplete - re-run import_bundle.ps1'
} else {
    Warn "no overlay manifest at $OverlayManifest (normal on the OLD laptop; on the new one import_bundle.ps1 puts it there)"
}

Write-Host ""
if ($script:fails -gt 0) { Write-Host "NOT READY: $($script:fails) FAIL, $($script:warns) WARN" -ForegroundColor Red; exit 1 }
Write-Host "READY TO BUILD: 0 FAIL, $($script:warns) WARN. Next: .\tools\build_map.ps1 (full build; the first one re-converts assets and takes longer)" -ForegroundColor Green
exit 0
