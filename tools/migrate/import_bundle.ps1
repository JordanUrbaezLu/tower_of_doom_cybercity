# import_bundle.ps1 - NEW LAPTOP: clone the repo from GitHub and put every file of the transfer
# bundle where it belongs (docs/174 step B5). Run it from the bundle's own copy:
#
#   powershell -ExecutionPolicy Bypass -File E:\tod_transfer\migrate_scripts\import_bundle.ps1
#
# Before running: the apps in docs/174 step B2 are installed (Git, Python 3.14, Node 24, Blender 4.2,
# FFmpeg, 7-Zip, VS Code + Claude Code) and Steam has installed BO3 AND the BO3 Mod Tools. Best run
# BEFORE BO3 or Blender is opened for the first time (their first launch writes config that the
# import then keeps).
#
# Safe to re-run: nothing newer on this machine is ever replaced (robocopy /XO, the overlay import
# skips files changed here); existing Claude / Codex / Blender settings are only replaced with -Force.
# It ends by running check_machine.ps1.
param(
    [string]$Source = (Split-Path $PSScriptRoot -Parent),   # the bundle folder (parent of migrate_scripts)
    [string]$ReposDir = (Join-Path $env:USERPROFILE 'Repositories'),
    [string]$Branch = 'map-content',
    [string]$SteamCommon = 'C:\Program Files (x86)\Steam\steamapps\common',
    [switch]$Force,
    [switch]$SkipOverlay
)
$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1: `2>$null` on a native command under Stop turns stderr into a terminating
# error (reg.exe prints its success line on stderr). Run such calls through this.
function NoErr([scriptblock]$sb) { $ErrorActionPreference = 'Continue'; & $sb 2>$null }
function Info($m) { Write-Host "[import] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[import] WARN: $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[import] FAIL: $m" -ForegroundColor Red; exit 1 }

$H = $env:USERPROFILE
$RepoRoot = Join-Path $ReposDir 'tower_of_doom_cybercity'
$Game  = Join-Path $SteamCommon 'Call of Duty Black Ops III'
$Tools = Join-Path $SteamCommon 'Call of Duty Black Ops III 455130'
$Py = Join-Path $PSScriptRoot 'bundle_tool.py'
$RoboLog = Join-Path $env:TEMP 'tod_import_robocopy.log'

# robocopy that never replaces a newer local file (/XO). -NoOverwrite: only files missing at the
# destination (/XC /XN /XO) - for configs the user may already have.
function Robo([string]$label, [string]$src, [string]$dst, [switch]$NoOverwrite) {
    if (-not (Test-Path -LiteralPath $src)) { Warn "$label - not in the bundle, skipped"; return }
    $a = @($src, $dst, '/E', '/XO', '/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/MT:16', '/NFL', '/NDL', '/NP', '/NJH', '/NJS', "/LOG+:$RoboLog")
    if ($NoOverwrite) { $a += @('/XC', '/XN') }
    & robocopy @a | Out-Null
    if ($LASTEXITCODE -ge 8 -or $LASTEXITCODE -lt 0) { Die "robocopy failed ($LASTEXITCODE): $src -> $dst (see $RoboLog)" }
    Info "$label -> $dst"
}
function Same-Path([string]$a, [string]$b) {
    try { return ((Resolve-Path -LiteralPath $a).ProviderPath.TrimEnd('\') -eq (Resolve-Path -LiteralPath $b).ProviderPath.TrimEnd('\')) } catch { return $false }
}

# ---------------------------------------------------------------- preflight
if (-not (Test-Path (Join-Path $Source 'bundle_manifest.json'))) { Die "no bundle_manifest.json in $Source - pass -Source <bundle folder>" }
foreach ($c in 'git', 'python', 'node', 'robocopy') {
    if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Die "$c is not installed / not on PATH - see SETUP_GUIDE.md step B2, then open a NEW terminal" }
}
if (Get-Process -Name BlackOps3 -ErrorAction SilentlyContinue) { Die 'BlackOps3 is running - close it first' }
if ($H -ne 'C:\Users\jorda') { Warn "your profile is $H, not C:\Users\jorda: tools scripts AND two build gates (PyCoD paths) hardcode C:\Users\jorda - see SETUP_GUIDE.md 'Paths'" }
$lpe = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction SilentlyContinue).LongPathsEnabled
if ($lpe -ne 1) { Warn 'Windows long paths are OFF. In an ADMIN PowerShell run: Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem LongPathsEnabled 1' }
git config --global core.longpaths true
$gidFile = Join-Path $Source 'git_identity.txt'
if ((Test-Path $gidFile) -and -not (git config --global user.name)) {
    foreach ($l in Get-Content $gidFile) {
        if ($l -match '^name=(.+)$') { git config --global user.name $matches[1] }
        if ($l -match '^email=(.+)$') { git config --global user.email $matches[1] }
    }
    Info "git identity set: $(git config --global user.name) <$(git config --global user.email)>"
}

# ---------------------------------------------------------------- 1. Steam layout (47 scripts name "...455130")
$toolsItem = Get-Item -LiteralPath $Tools -Force -ErrorAction SilentlyContinue
if ($toolsItem -and $toolsItem.LinkType -eq 'Junction') {
    Info "Mod Tools path is already a junction -> $($toolsItem.Target) (tools live inside the game folder; no usermaps junction needed)"
} elseif (Test-Path (Join-Path $Tools 'bin\modlauncher.exe')) {
    Info "Mod Tools found (own folder): $Tools"
    $gu = Join-Path $Game 'usermaps'; $tu = Join-Path $Tools 'usermaps'
    New-Item -ItemType Directory -Force -Path $tu | Out-Null
    if (-not (Test-Path $Game)) {
        Warn "BO3 itself is not installed at $Game - install it, then re-run (the game reads maps through $gu)"
    } elseif (Test-Path $gu) {
        $it = Get-Item -LiteralPath $gu -Force
        if (Same-Path $gu $tu) { Info "game usermaps already reaches $tu" }
        elseif ($it.LinkType -eq 'Junction') { Warn "$gu is a junction to $($it.Target), not to $tu - fix it by hand" }
        elseif (@(Get-ChildItem -LiteralPath $gu -Force).Count -eq 0) {
            Remove-Item -LiteralPath $gu -Force
            New-Item -ItemType Junction -Path $gu -Target $tu | Out-Null
            Info "junction: $gu -> $tu"
        } else { Warn "$gu is a real folder with files in it (left alone). Move its contents into $tu, remove the empty folder, re-run." }
    } else {
        New-Item -ItemType Junction -Path $gu -Target $tu | Out-Null
        Info "junction: $gu -> $tu"
    }
} elseif (Test-Path (Join-Path $Game 'bin\modlauncher.exe')) {
    if (Test-Path -LiteralPath $Tools) { Die "$Tools exists but holds no Mod Tools - remove it, then re-run" }
    New-Item -ItemType Junction -Path $Tools -Target $Game | Out-Null
    Info "Mod Tools live inside the game folder; junction: $Tools -> $Game"
} else {
    Die "BO3 Mod Tools not found under $SteamCommon. Steam > Library > Tools > 'Call of Duty: Black Ops III - Mod Tools', then re-run."
}
# The Mod Tools' own environment (Steam's installscript writes it; cod2map64 / Radiant refuse to run without it)
$envKey = 'HKCU:\Environment'
$want = @{ TA_GAME_PATH = "$Tools\"; TA_TOOLS_PATH = "$Tools\"; TA_LOCAL_ASSET_CACHE = "$Tools\share\assetconvert\" }
foreach ($k in $want.Keys) {
    $cur = (Get-ItemProperty $envKey -ErrorAction SilentlyContinue).$k
    if (-not $cur -or -not (Test-Path -LiteralPath $cur)) {
        [Environment]::SetEnvironmentVariable($k, $want[$k], 'User')
        Info "user env $k = $($want[$k])"
    }
}

# ---------------------------------------------------------------- 2. repos from GitHub
New-Item -ItemType Directory -Force -Path $ReposDir | Out-Null
NoErr { git lfs install } | Out-Null
function Clone([string]$url, [string]$dir, [string]$branch, [switch]$Lfs) {
    if (Test-Path (Join-Path $dir '.git')) {
        # a clone that died mid-checkout leaves .git + a partial tree: refuse to build on it
        $missing = @(git -C $dir ls-files --deleted).Count
        if ($missing -gt 0) { Die "$dir is an incomplete clone ($missing tracked files missing). Delete the folder and re-run." }
        Info "already cloned: $dir"; return
    }
    $a = @('clone')
    if ($branch) { $a += @('--branch', $branch) }
    if ($Lfs) { $env:GIT_LFS_SKIP_SMUDGE = '1' }   # big files come down in one checked step below
    & git @($a + @($url, $dir))
    $code = $LASTEXITCODE
    Remove-Item Env:\GIT_LFS_SKIP_SMUDGE -ErrorAction SilentlyContinue
    if ($code -ne 0) { Die "git clone failed: $url (delete $dir if it exists, then re-run)" }
    if ($Lfs) {
        & git -C $dir lfs pull
        if ($LASTEXITCODE -ne 0) { Die "git lfs pull failed in $dir (GitHub LFS quota or login) - fix, then: git -C `"$dir`" lfs pull" }
    }
}
Clone 'https://github.com/JordanUrbaezLu/tower_of_doom_cybercity.git' $RepoRoot $Branch -Lfs
Clone 'https://github.com/JordanUrbaezLu/abandoned_cyber_city_zombies.git' (Join-Path $ReposDir 'abandoned_cyber_city_zombies') ''
Clone 'https://github.com/Owen-C137/Aetherium-Hud-Bo7-Remake-.git' (Join-Path $ReposDir 'Aetherium-Hud-Bo7-Remake') ''
# untracked repo files: only the paths the export listed, never over a file the clone already has
$lst = Join-Path $Source 'repo_extras.lst'
if (Test-Path $lst) {
    & python $Py copylist --src (Join-Path $Source 'repo_extras') --dest $RepoRoot --list $lst --no-overwrite
    if ($LASTEXITCODE -ne 0) { Die 'repo extras copy failed (see above)' }
} else { Warn 'repo_extras.lst missing from the bundle - tmp\ and local_sync_cache\ were not restored' }
Robo 'repos\test+map (PyCoD for build gates)' (Join-Path $Source 'repos\test+map') (Join-Path $ReposDir 'test+map') -NoOverwrite
Robo 'Tower II hellbound: MCP addon + BO6 loaders' (Join-Path $Source 'repos\tower_of_doom_II_hellbound') (Join-Path $ReposDir 'tower_of_doom_II_hellbound') -NoOverwrite

# ---------------------------------------------------------------- 3. Mod Tools overlay (~86 GB, sha1-checked)
if (-not $SkipOverlay) {
    $oa = @($Py, 'overlay-import', '--src', (Join-Path $Source 'tools_overlay'), '--tools', $Tools)
    if ($Force) { $oa += '--force' }
    & python @oa
    if ($LASTEXITCODE -ne 0) { Die 'tools overlay import failed (see above)' }
}
$mig = Join-Path $RepoRoot 'tmp\migration'
New-Item -ItemType Directory -Force -Path $mig | Out-Null
foreach ($f in 'tools_overlay\overlay_manifest.json', 'bundle_manifest.json', 'machine_facts.txt') {
    $p = Join-Path $Source $f
    if (Test-Path $p) { Copy-Item $p $mig -Force }
}
if (Test-Path (Join-Path $Source 'python')) { Copy-Item (Join-Path $Source 'python') $mig -Recurse -Force }

# ---------------------------------------------------------------- 4. Documents / Downloads (literal paths: the tools hardcode them)
Robo 'Documents\BO3_tools' (Join-Path $Source 'documents\BO3_tools') (Join-Path $H 'Documents\BO3_tools')
Robo 'Documents\BO3_asset_backups' (Join-Path $Source 'documents\BO3_asset_backups') (Join-Path $H 'Documents\BO3_asset_backups')
Robo 'Downloads (project raw sources)' (Join-Path $Source 'downloads') (Join-Path $H 'Downloads') -NoOverwrite

# ---------------------------------------------------------------- 5. Claude / Codex / Blender / game / registry
$key = $RepoRoot -replace '[^A-Za-z0-9]', '-'
$mem = Join-Path $H ".claude\projects\$key\memory"
$oldIdx = Join-Path $Source 'claude\memory\MEMORY.md'; $newIdx = Join-Path $mem 'MEMORY.md'
if ((Test-Path $newIdx) -and (Test-Path $oldIdx) -and -not $Force -and
    ((Get-FileHash $newIdx).Hash -ne (Get-FileHash $oldIdx).Hash)) {
    Warn "this laptop already has a different Claude MEMORY.md (Claude was opened in the repo before the import). The old laptop's index is $oldIdx - merge its lines in, or re-run with -Force to take the old one."
}
if ($Force) { Robo 'Claude project memory' (Join-Path $Source 'claude\memory') $mem }
else { Robo 'Claude project memory (missing files only)' (Join-Path $Source 'claude\memory') $mem -NoOverwrite }
Robo 'Claude session history' (Join-Path $Source 'claude\project') (Join-Path $H ".claude\projects\$key") -NoOverwrite
$sj = Join-Path $Source 'claude\settings.json'; $dj = Join-Path $H '.claude\settings.json'
if (Test-Path $sj) {
    if ((Test-Path $dj) -and -not $Force) { Warn "$dj exists - kept (use -Force to take the old laptop's)" }
    else { New-Item -ItemType Directory -Force -Path (Split-Path $dj) | Out-Null; Copy-Item $sj $dj -Force; Info "claude settings.json -> $dj" }
}
if ($Force) { Robo 'Codex config, rules, skills, memories' (Join-Path $Source 'codex') (Join-Path $H '.codex') }
else { Robo 'Codex config, rules, skills, memories (missing files only)' (Join-Path $Source 'codex') (Join-Path $H '.codex') -NoOverwrite }
$bl = Join-Path $env:APPDATA 'Blender Foundation\Blender\4.2'
if ((Test-Path (Join-Path $bl 'config\userpref.blend')) -and -not $Force) {
    Robo 'Blender 4.2 addons (prefs kept)' (Join-Path $Source 'blender\4.2') $bl -NoOverwrite
    Warn 'Blender 4.2 was opened before the import: its own userpref.blend was kept. Enable the "BetterBetterBlenderCOD" and "Cast" addons in Edit > Preferences > Add-ons (or re-run with -Force)'
} else { Robo 'Blender 4.2 addons + prefs' (Join-Path $Source 'blender\4.2') $bl }
if (Test-Path $Game) {
    if ((Test-Path (Join-Path $Game 'players\config.cfg')) -and -not $Force) {
        Warn "BO3 was launched before the import: its new players\ config was kept. Your old keybinds are in $Source\game\players (copy the .cfg files over, or re-run with -Force)"
        Robo 'BO3 players config (missing files only)' (Join-Path $Source 'game\players') (Join-Path $Game 'players') -NoOverwrite
    } else { Robo 'BO3 players config (keybinds)' (Join-Path $Source 'game\players') (Join-Path $Game 'players') }
    Robo 'BO3 mods folder' (Join-Path $Source 'game\mods') (Join-Path $Game 'mods') -NoOverwrite
}
$reg = Join-Path $Source 'registry\treyarch.reg'
if (Test-Path $reg) {
    NoErr { & reg import $reg } | Out-Null
    if ($LASTEXITCODE -eq 0) { Info 'Radiant / ModLauncher prefs imported (Controller_Enabled=false: a gamepad press otherwise stalls the LED bake)' }
    else { Warn "reg import failed ($LASTEXITCODE) - run: reg import `"$reg`"" }
}
# two sound tools default to the old laptop's winget FFmpeg folder; point them at whatever is installed
$oldFf = Join-Path $H 'AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.2-full_build\bin\ffmpeg.exe'
$ff = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not (Test-Path $oldFf) -and $ff -and -not [Environment]::GetEnvironmentVariable('TOD_FFMPEG', 'User')) {
    [Environment]::SetEnvironmentVariable('TOD_FFMPEG', $ff.Source, 'User')
    Info "user env TOD_FFMPEG = $($ff.Source)"
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
Info 'running check_machine.ps1 ... (environment variables set above apply to NEW terminals: open one before building)'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'tools\migrate\check_machine.ps1') -RepoRoot $RepoRoot -SteamCommon $SteamCommon
exit $LASTEXITCODE
