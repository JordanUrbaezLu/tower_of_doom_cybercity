# import_bundle.ps1 - NEW LAPTOP: clone the repo from GitHub and put every file of the transfer
# bundle where it belongs (docs/174 step B5). Run it from the bundle's own copy:
#
#   powershell -ExecutionPolicy Bypass -File E:\tod_transfer\migrate_scripts\import_bundle.ps1
#
# Before running: the apps in docs/174 step B2 are installed (Git, Python 3.14, Node 24, Blender 4.2,
# FFmpeg, 7-Zip, VS Code + Claude Code) and Steam has installed BO3 AND the BO3 Mod Tools.
# Safe to re-run: copies skip files that are already current; existing Claude / Codex / Blender
# settings are only overwritten with -Force. It ends by running check_machine.ps1.
param(
    [string]$Source = (Split-Path $PSScriptRoot -Parent),   # the bundle folder (parent of migrate_scripts)
    [string]$ReposDir = (Join-Path $env:USERPROFILE 'Repositories'),
    [string]$Branch = 'map-content',
    [string]$SteamCommon = 'C:\Program Files (x86)\Steam\steamapps\common',
    [switch]$Force,
    [switch]$SkipOverlay
)
$ErrorActionPreference = 'Stop'
function Info($m) { Write-Host "[import] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[import] WARN: $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[import] FAIL: $m" -ForegroundColor Red; exit 1 }

$H = $env:USERPROFILE
$RepoRoot = Join-Path $ReposDir 'tower_of_doom_cybercity'
$Game  = Join-Path $SteamCommon 'Call of Duty Black Ops III'
$Tools = Join-Path $SteamCommon 'Call of Duty Black Ops III 455130'
$Py = Join-Path $PSScriptRoot 'bundle_tool.py'
$RoboLog = Join-Path $env:TEMP 'tod_import_robocopy.log'

# robocopy: -NoOverwrite copies only files missing at the destination (/XC /XN /XO)
function Robo([string]$label, [string]$src, [string]$dst, [switch]$NoOverwrite) {
    if (-not (Test-Path -LiteralPath $src)) { Warn "$label - not in the bundle, skipped"; return }
    $a = @($src, $dst, '/E', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:16', '/NFL', '/NDL', '/NP', '/NJH', '/NJS', "/LOG+:$RoboLog")
    if ($NoOverwrite) { $a += @('/XC', '/XN', '/XO') }
    & robocopy @a | Out-Null
    if ($LASTEXITCODE -ge 8) { Die "robocopy failed ($LASTEXITCODE): $src -> $dst (see $RoboLog)" }
    Info "$label -> $dst"
}

# ---------------------------------------------------------------- preflight
if (-not (Test-Path (Join-Path $Source 'bundle_manifest.json'))) { Die "no bundle_manifest.json in $Source - pass -Source <bundle folder>" }
foreach ($c in 'git', 'python', 'node', 'robocopy') {
    if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Die "$c is not installed / not on PATH - see SETUP_GUIDE.md step B2, then open a NEW terminal" }
}
if (Get-Process -Name BlackOps3 -ErrorAction SilentlyContinue) { Die 'BlackOps3 is running - close it first' }
if ($H -ne 'C:\Users\jorda') { Warn "your profile is $H, not C:\Users\jorda: ~19 tools scripts hardcode C:\Users\jorda (SETUP_GUIDE.md 'Paths'). The build itself does not." }
$lpe = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction SilentlyContinue).LongPathsEnabled
if ($lpe -ne 1) { Warn 'Windows long paths are OFF. In an ADMIN PowerShell run: Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem LongPathsEnabled 1' }
git config --global core.longpaths true

# ---------------------------------------------------------------- 1. Steam layout (the 47 scripts that name "...455130")
if (Test-Path (Join-Path $Tools 'bin\modlauncher.exe')) {
    Info "Mod Tools found (separate folder): $Tools"
    $gu = Join-Path $Game 'usermaps'; $tu = Join-Path $Tools 'usermaps'
    New-Item -ItemType Directory -Force -Path $tu | Out-Null
    if (-not (Test-Path $Game)) {
        Warn "BO3 itself is not installed at $Game - install it, then re-run (the game reads maps through $gu)"
    } elseif (Test-Path $gu) {
        $it = Get-Item $gu -Force
        if ($it.LinkType -eq 'Junction') { Info "game usermaps junction already present -> $($it.Target)" }
        elseif (@(Get-ChildItem $gu -Force).Count -eq 0) {
            Remove-Item $gu -Force
            New-Item -ItemType Junction -Path $gu -Target $tu | Out-Null
            Info "junction: $gu -> $tu"
        } else { Warn "$gu is a real folder with files in it. Move them into $tu, delete it, re-run." }
    } else {
        New-Item -ItemType Junction -Path $gu -Target $tu | Out-Null
        Info "junction: $gu -> $tu"
    }
} elseif (Test-Path (Join-Path $Game 'bin\modlauncher.exe')) {
    # Steam put the tools INSIDE the game folder: give the hardcoded "...455130" path a junction
    New-Item -ItemType Junction -Path $Tools -Target $Game | Out-Null
    Info "Mod Tools live inside the game folder; junction: $Tools -> $Game"
} else {
    Die "BO3 Mod Tools not found under $SteamCommon. Steam > Library > Tools > 'Call of Duty: Black Ops III - Mod Tools', then re-run."
}

# ---------------------------------------------------------------- 2. repos from GitHub
New-Item -ItemType Directory -Force -Path $ReposDir | Out-Null
git lfs install | Out-Null
function Clone([string]$url, [string]$dir, [string]$branch) {
    if (Test-Path (Join-Path $dir '.git')) { Info "already cloned: $dir"; return }
    $a = @('clone')
    if ($branch) { $a += @('--branch', $branch) }
    & git @($a + @($url, $dir))
    if ($LASTEXITCODE -ne 0) { Die "git clone failed: $url (log in to GitHub when Git Credential Manager asks; the repo is private)" }
}
Clone 'https://github.com/JordanUrbaezLu/tower_of_doom_cybercity.git' $RepoRoot $Branch
Clone 'https://github.com/JordanUrbaezLu/abandoned_cyber_city_zombies.git' (Join-Path $ReposDir 'abandoned_cyber_city_zombies') ''
Clone 'https://github.com/Owen-C137/Aetherium-Hud-Bo7-Remake-.git' (Join-Path $ReposDir 'Aetherium-Hud-Bo7-Remake') ''
git -C $RepoRoot lfs pull
Robo 'repo extras (tmp, local_sync_cache, untracked)' (Join-Path $Source 'repo_extras') $RepoRoot
Robo 'repos\test+map' (Join-Path $Source 'repos\test+map') (Join-Path $ReposDir 'test+map') -NoOverwrite
Robo 'Blender MCP addon (Tower II tmp)' (Join-Path $Source 'repos\tower_of_doom_II_hellbound') (Join-Path $ReposDir 'tower_of_doom_II_hellbound') -NoOverwrite

# ---------------------------------------------------------------- 3. Mod Tools overlay (~86 GB, sha1-checked)
if (-not $SkipOverlay) {
    & python $Py overlay-import --src (Join-Path $Source 'tools_overlay') --tools $Tools
    if ($LASTEXITCODE -ne 0) { Die 'tools overlay import failed (see above)' }
}
$mig = Join-Path $RepoRoot 'tmp\migration'
New-Item -ItemType Directory -Force -Path $mig | Out-Null
Copy-Item (Join-Path $Source 'tools_overlay\overlay_manifest.json') $mig -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $Source 'bundle_manifest.json') $mig -Force
Copy-Item (Join-Path $Source 'machine_facts.txt') $mig -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $Source 'python') $mig -Recurse -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------------- 4. Documents / Downloads (literal paths: the tools hardcode them)
Robo 'Documents\BO3_tools' (Join-Path $Source 'documents\BO3_tools') (Join-Path $H 'Documents\BO3_tools')
Robo 'Documents\BO3_asset_backups' (Join-Path $Source 'documents\BO3_asset_backups') (Join-Path $H 'Documents\BO3_asset_backups')
Robo 'Downloads (project raw sources)' (Join-Path $Source 'downloads') (Join-Path $H 'Downloads') -NoOverwrite

# ---------------------------------------------------------------- 5. Claude / Codex / Blender / game / registry
$key = $RepoRoot -replace '[^A-Za-z0-9]', '-'
$mem = Join-Path $H ".claude\projects\$key\memory"
if ((Test-Path (Join-Path $mem 'MEMORY.md')) -and -not $Force) { Warn "Claude memory already at $mem - kept (use -Force to replace)" }
else { Robo 'Claude project memory' (Join-Path $Source 'claude\memory') $mem }
Robo 'Claude session history' (Join-Path $Source 'claude\project') (Join-Path $H ".claude\projects\$key") -NoOverwrite
foreach ($f in @(@('claude\settings.json', '.claude\settings.json'), @('codex\config.toml', '.codex\config.toml'), @('codex\AGENTS.md', '.codex\AGENTS.md'))) {
    $s = Join-Path $Source $f[0]; $d = Join-Path $H $f[1]
    if (-not (Test-Path $s)) { continue }
    if ((Test-Path $d) -and -not $Force) { Warn "$d exists - kept (use -Force to replace)"; continue }
    New-Item -ItemType Directory -Force -Path (Split-Path $d -Parent) | Out-Null
    Copy-Item $s $d -Force; Info "$($f[0]) -> $d"
}
$bl = Join-Path $env:APPDATA 'Blender Foundation\Blender\4.2'
if ($Force) { Robo 'Blender 4.2 addons + prefs' (Join-Path $Source 'blender\4.2') $bl } else { Robo 'Blender 4.2 addons + prefs' (Join-Path $Source 'blender\4.2') $bl -NoOverwrite }
if (Test-Path $Game) {
    Robo 'BO3 players config (keybinds)' (Join-Path $Source 'game\players') (Join-Path $Game 'players') -NoOverwrite
    Robo 'BO3 mods folder' (Join-Path $Source 'game\mods') (Join-Path $Game 'mods') -NoOverwrite
}
$reg = Join-Path $Source 'registry\treyarch.reg'
if (Test-Path $reg) {
    & reg import $reg 2>$null
    if ($LASTEXITCODE -eq 0) { Info 'Radiant / ModLauncher prefs imported (incl. Controller_Enabled=false - a gamepad press stalls bakes otherwise)' } else { Warn 'reg import failed' }
}

# ---------------------------------------------------------------- 6. Python packages + the Blender MCP venv
& python -m pip install --disable-pip-version-check -r (Join-Path $PSScriptRoot 'requirements.txt')
if ($LASTEXITCODE -ne 0) { Warn 'pip install of tools requirements failed - the build gates need lupa/numpy/pillow/scipy/soundfile' }
$t2tmp = Join-Path $ReposDir 'tower_of_doom_II_hellbound\tmp'
$venv = Join-Path $t2tmp 'gold_sword_env'
$vendor = Join-Path $t2tmp 'blender_mcp_vendor'
if ((Test-Path $vendor) -and -not (Test-Path (Join-Path $venv 'Scripts\python.exe'))) {
    & python -m venv $venv
    & (Join-Path $venv 'Scripts\python.exe') -m pip install --disable-pip-version-check -r (Join-Path $PSScriptRoot 'requirements-blender-mcp.txt')
    & (Join-Path $venv 'Scripts\python.exe') -m pip install --disable-pip-version-check --no-deps $vendor
    if ($LASTEXITCODE -eq 0) { Info "Blender MCP client venv ready: $venv" } else { Warn 'Blender MCP venv install failed (art sessions only; the build does not need it)' }
}

# ---------------------------------------------------------------- 7. check everything
Info 'running check_machine.ps1 ...'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'tools\migrate\check_machine.ps1') -RepoRoot $RepoRoot -SteamCommon $SteamCommon
exit $LASTEXITCODE
