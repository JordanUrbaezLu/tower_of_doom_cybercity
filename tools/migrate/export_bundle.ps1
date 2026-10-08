# export_bundle.ps1 - OLD LAPTOP: pack everything GitHub does not carry into ONE folder (docs/174).
#
#   powershell -ExecutionPolicy Bypass -File tools\migrate\export_bundle.ps1 -Dest E:\tod_transfer -DryRun
#   powershell -ExecutionPolicy Bypass -File tools\migrate\export_bundle.ps1 -Dest E:\tod_transfer
#
# -Dest can be an external drive, a network share or a cloud-synced folder. Re-running RESUMES:
# robocopy and the overlay copy both skip files that are already there and current.
#
# GitHub carries the repo itself (code, docs, art, model_export ...). This bundle carries the rest:
#   tools_overlay\    the ~86 GB of BO3 Mod Tools files that are NOT stock (packs, originals, the
#                     30 modified stock files, this map's current build + its Workshop publish files)
#   repo_extras\      every file in this repo git does not track (tmp\, local_sync_cache\, .blend1 ...)
#   documents\        Documents\BO3_tools (Greyhound, Saluki, Cordycep, RSX, BO6_Pilot) + BO3_asset_backups
#   downloads\        the project's raw sources in Downloads (BO6 exports, Nikolai's zips, source audio,
#                     reference images, every art pack) - or ALL of Downloads with -IncludeAllDownloads
#   repos\            test+map (no remote) and the Blender MCP addon that lives in Tower II's tmp\
#   claude\ codex\ blender\ game\ registry\ python\   settings, memory, addons, keybinds, Radiant prefs
#   migrate_scripts\  this folder, so the new laptop can run import_bundle.ps1 before anything is cloned
#
# Credentials (Claude, Codex, git) are NOT copied - log in fresh on the new laptop.
param(
    [Parameter(Mandatory = $true)][string]$Dest,
    [switch]$DryRun,
    [switch]$AllowUnpushed,         # skip the "all work committed and pushed" gate (testing only)
    [switch]$IncludeAllDownloads,   # every file in Downloads (~230 GB, mostly pack archives) instead of the project subset
    [switch]$IncludeClaudeHistory,  # this project's Claude session transcripts (~1.5 GB), not just its memory
    [switch]$AllUsermaps,           # the other maps' build output too (Tower II etc., ~31 GB)
    [string]$ToolsRoot = ''
)
$ErrorActionPreference = 'Stop'

# string join: Join-Path throws when -Dest's drive is not mounted yet (dry runs before the drive is in)
function PJ([string]$a, [string]$b) { return [System.IO.Path]::Combine($a, $b) }
function Info($m) { Write-Host "[export] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[export] WARN: $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[export] FAIL: $m" -ForegroundColor Red; exit 1 }

$Repo     = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ReposDir = Split-Path $Repo -Parent
$H        = $env:USERPROFILE
$Py       = Join-Path $PSScriptRoot 'bundle_tool.py'
$Common   = 'C:\Program Files (x86)\Steam\steamapps\common'
if ($ToolsRoot -eq '') { $ToolsRoot = Join-Path $Common 'Call of Duty Black Ops III 455130' }
$Game     = Join-Path (Split-Path $ToolsRoot -Parent) 'Call of Duty Black Ops III'
$ClaudeKey = $Repo -replace '[^A-Za-z0-9]', '-'
$ClaudeProj = Join-Path $H ".claude\projects\$ClaudeKey"

# ---------------------------------------------------------------- preflight
foreach ($p in 'BlackOps3', 'linker_modtools', 'cod2map64', 'radiant_modtools', 'converter', 'modlauncher') {
    if (Get-Process -Name $p -ErrorAction SilentlyContinue) {
        if ($DryRun) { Warn "$p is running - close it before the real export" } else { Die "$p is running. Close BO3 / the mod tools / any build first, so nothing changes mid-copy." }
    }
}
foreach ($c in 'git', 'python', 'robocopy') { if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Die "$c not found on PATH" } }
if (-not (Test-Path (Join-Path $ToolsRoot 'bin\modlauncher.exe'))) { Die "Mod Tools root not found: $ToolsRoot (pass -ToolsRoot)" }

Push-Location $Repo
$dirty = @(git status --porcelain --untracked-files=no)
$ahead = (git rev-list --count '@{u}..HEAD' 2>$null)
$branch = (git rev-parse --abbrev-ref HEAD)
Pop-Location
if ($dirty.Count -gt 0 -or "$ahead" -ne '0') {
    $msg = "the repo has $($dirty.Count) uncommitted tracked change(s) and $ahead unpushed commit(s) on $branch. GitHub + this bundle must together equal this folder: commit and push first (docs/174 step A2)."
    if ($DryRun -or $AllowUnpushed) { Warn $msg } else { Die $msg }
}

if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $Dest | Out-Null }
$LogDir = PJ $Dest 'logs'
if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }
$RoboLog = PJ $LogDir 'robocopy.log'
$Items = New-Object System.Collections.ArrayList

function Add-Item($label, $bytes, $files, $dst) {
    [void]$Items.Add([pscustomobject]@{ item = $label; bytes = [int64]$bytes; files = $files; dest = $dst })
    Info ("{0,-44} {1,9:N2} GB" -f $label, ($bytes / 1e9))
}

# robocopy wrapper: returns the byte total from the job summary (/BYTES); /L in dry runs.
function Robo([string]$label, [string]$src, [string]$dst, [string[]]$opts) {
    if (-not (Test-Path -LiteralPath $src)) { Warn "$label - source missing, skipped: $src"; return }
    $a = @($src, $dst) + $opts + @('/COPY:DAT', '/DCOPY:T', '/R:1', '/W:1', '/NFL', '/NDL', '/NP', '/BYTES', '/NJH')
    if ($DryRun) { $a += '/L' } else { $a += @('/MT:16', '/TEE', "/LOG+:$RoboLog") }
    $out = & robocopy @a
    if ($LASTEXITCODE -ge 8) { Die "robocopy failed ($LASTEXITCODE): $src -> $dst (see $RoboLog)" }
    # summary columns: Total Copied Skipped ... - "Copied" (what this run moves; /L: would move).
    # Total also counts files a filter such as /MAX excluded, so it is not the bundle size.
    $bytes = 0
    foreach ($l in $out) { if ($l -match '^\s*Bytes\s*:\s*(\d+)\s+(\d+)') { $bytes = [int64]$matches[2] } }
    Add-Item $label $bytes '' $dst
}

function Copy-OneFile([string]$label, [string]$src, [string]$dst) {
    if (-not (Test-Path -LiteralPath $src)) { Warn "$label - missing, skipped: $src"; return }
    $len = (Get-Item -LiteralPath $src).Length
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }
    Add-Item $label $len 1 $dst
}

function Parse-Bytes($lines) {
    $b = 0; $f = 0
    foreach ($l in $lines) { if ("$l" -match 'BYTES=(\d+) FILES=(\d+)') { $b = [int64]$matches[1]; $f = [int]$matches[2] } }
    return @($b, $f)
}

Info "repo:       $Repo ($branch)"
Info "tools root: $ToolsRoot"
Info "bundle:     $Dest $(if ($DryRun) { '(DRY RUN - nothing is copied)' })"

# ---------------------------------------------------------------- 1. Mod Tools overlay (the big one)
$ovArgs = @($Py, 'overlay-export', '--dest', (PJ $Dest 'tools_overlay'), '--tools', $ToolsRoot)
if ($DryRun) { $ovArgs += '--dry-run' }
if ($AllUsermaps) { $ovArgs += '--all-usermaps' }
$ov = & python @ovArgs
$ovCode = $LASTEXITCODE
$ov | Where-Object { "$_" -notmatch '^\s+\d+\.\d+ GB' -and "$_" -notmatch '^BYTES=' } | ForEach-Object { Write-Host "    $_" }
if ($ovCode -ne 0) { Die 'tools overlay export failed' }
$r = Parse-Bytes $ov; Add-Item 'tools_overlay (Mod Tools non-stock files)' $r[0] $r[1] 'tools_overlay'

# ---------------------------------------------------------------- 2. repo files git does not track
# python asks git directly (git ls-files --others --directory -z): PowerShell would re-encode the names
$clArgs = @($Py, 'copylist', '--src', $Repo, '--dest', (PJ $Dest 'repo_extras'), '--git-untracked')
if ($DryRun) { $clArgs += '--dry-run' } else { $clArgs += @('--save-list', (PJ $Dest 'repo_extras.lst')) }
$cl = & python @clArgs
if ($LASTEXITCODE -ne 0) { Die 'repo extras copy failed' }
$r = Parse-Bytes $cl; Add-Item 'repo_extras (tmp, local_sync_cache, untracked)' $r[0] $r[1] 'repo_extras'

# ---------------------------------------------------------------- 3. Documents tool folders
Robo 'documents\BO3_tools (Greyhound, Saluki, RSX ...)' (Join-Path $H 'Documents\BO3_tools') (PJ $Dest 'documents\BO3_tools') @('/E')
Robo 'documents\BO3_asset_backups' (Join-Path $H 'Documents\BO3_asset_backups') (PJ $Dest 'documents\BO3_asset_backups') @('/E')

# ---------------------------------------------------------------- 4. Downloads
$DL = Join-Path $H 'Downloads'
$DLd = PJ $Dest 'downloads'
if ($IncludeAllDownloads) {
    Robo 'downloads (EVERYTHING)' $DL $DLd @('/E')
} else {
    # every loose file under 50 MB (art pack drops, reference images, source audio, small zips)
    Robo 'downloads: loose files under 50 MB' $DL $DLd @('/MAX:52428800')
    Robo "downloads: Nikolai's 3D Models zips" $DL $DLd @('3D Models-*.zip')
    foreach ($d in 'BO6_Pilot_Export', 'tod_sounds', 'sky_refs', 'Image Assets', 'Steam Workshop Images') {
        Robo "downloads\$d" (Join-Path $DL $d) (PJ $DLd $d) @('/E')
    }
}

# ---------------------------------------------------------------- 5. sibling repos the tools read
Robo 'repos\test+map (no remote; holds tmp\blender-cod)' (Join-Path $ReposDir 'test+map') (PJ $Dest 'repos\test+map') @('/E')
Robo 'repos\...II_hellbound\tmp\blender_mcp_vendor' (Join-Path $ReposDir 'tower_of_doom_II_hellbound\tmp\blender_mcp_vendor') (PJ $Dest 'repos\tower_of_doom_II_hellbound\tmp\blender_mcp_vendor') @('/E')

# ---------------------------------------------------------------- 6. Claude / Codex / Blender / game / registry
Robo 'claude\memory (this project)' (Join-Path $ClaudeProj 'memory') (PJ $Dest 'claude\memory') @('/E')
if ($IncludeClaudeHistory) { Robo 'claude\project (session transcripts)' $ClaudeProj (PJ $Dest 'claude\project') @('/E', '/XD', 'memory') }
Copy-OneFile 'claude\settings.json' (Join-Path $H '.claude\settings.json') (PJ $Dest 'claude\settings.json')
Copy-OneFile 'codex\config.toml' (Join-Path $H '.codex\config.toml') (PJ $Dest 'codex\config.toml')
Copy-OneFile 'codex\AGENTS.md' (Join-Path $H '.codex\AGENTS.md') (PJ $Dest 'codex\AGENTS.md')
Robo 'blender\4.2 (addons + prefs)' (Join-Path $env:APPDATA 'Blender Foundation\Blender\4.2') (PJ $Dest 'blender\4.2') @('/E')
Robo 'game\players (keybinds + config)' (Join-Path $Game 'players') (PJ $Dest 'game\players') @('/E')
Robo 'game\mods' (Join-Path $Game 'mods') (PJ $Dest 'game\mods') @('/E')
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path (PJ $Dest 'registry') | Out-Null
    & reg export 'HKCU\Software\Treyarch' (PJ $Dest 'registry\treyarch.reg') /y | Out-Null
    if ($LASTEXITCODE -ne 0) { Warn 'reg export HKCU\Software\Treyarch failed' }
}
Add-Item 'registry\treyarch.reg (Radiant + ModLauncher prefs)' 0 1 'registry'

# ---------------------------------------------------------------- 7. versions + package lists + the scripts themselves
if (-not $DryRun) {
    $pyd = PJ $Dest 'python'; New-Item -ItemType Directory -Force -Path $pyd | Out-Null
    & python -m pip freeze 2>$null | Set-Content -Encoding utf8 (Join-Path $pyd 'global-freeze.txt')
    $gold = Join-Path $ReposDir 'tower_of_doom_II_hellbound\tmp\gold_sword_env\Scripts\python.exe'
    if (Test-Path $gold) { & $gold -m pip freeze 2>$null | Set-Content -Encoding utf8 (Join-Path $pyd 'gold_sword_env-freeze.txt') }
    $facts = @(
        "exported   : $(Get-Date -Format s)",
        "computer   : $env:COMPUTERNAME  user: $env:USERNAME  profile: $H",
        "repo       : $Repo  branch: $branch  head: $(git -C $Repo rev-parse --short HEAD)",
        "tools root : $ToolsRoot",
        "game       : $Game",
        "git        : $(git --version)",
        "git-lfs    : $(git lfs version)",
        "node       : $(node --version)",
        "python     : $(python --version)",
        "ffmpeg     : $((Get-Command ffmpeg -ErrorAction SilentlyContinue).Source)",
        "blender    : $(& 'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe' --version 2>$null | Select-Object -First 1)"
    )
    $facts | Set-Content -Encoding utf8 (PJ $Dest 'machine_facts.txt')
    Robo 'migrate_scripts (run import_bundle.ps1 from here)' $PSScriptRoot (PJ $Dest 'migrate_scripts') @('/E', '/XD', '__pycache__')
    Copy-Item (Join-Path $Repo 'docs\174_new_laptop_setup.md') (PJ $Dest 'SETUP_GUIDE.md') -Force
}

# ---------------------------------------------------------------- summary
$total = ($Items | Measure-Object -Property bytes -Sum).Sum
Info ('-' * 60)
if (-not $DryRun) {
    # a resumed run copies only what was missing, so measure the bundle itself for the real size
    $du = & python $Py du $Dest --json | ConvertFrom-Json
    $total = [int64]$du[0].bytes
    Info ("bundle on disk: {0:N0} files" -f $du[0].files)
}
Info ("TOTAL {0,48:N2} GB" -f ($total / 1e9))
if ($DryRun) {
    Info 'DRY RUN only. Nothing was copied. Run again without -DryRun to build the bundle.'
    $drv = Split-Path -Qualifier $Dest -ErrorAction SilentlyContinue
    if ($drv) { $disk = Get-PSDrive -Name $drv.TrimEnd(':') -ErrorAction SilentlyContinue; if ($disk) { Info ("free on {0}: {1:N1} GB" -f $drv, ($disk.Free / 1e9)) } }
    exit 0
}
$manifest = [pscustomobject]@{
    created = (Get-Date -Format s); source_computer = $env:COMPUTERNAME; repo_branch = $branch
    repo_head = (git -C $Repo rev-parse HEAD); github = 'https://github.com/JordanUrbaezLu/tower_of_doom_cybercity'
    tools_root = $ToolsRoot; total_bytes = $total; items = $Items
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (PJ $Dest 'bundle_manifest.json')
@"
TOWER OF DOOM CYBERCITY - TRANSFER BUNDLE ($(Get-Date -Format s), from $env:COMPUTERNAME)

On the NEW laptop, after installing the apps in SETUP_GUIDE.md (step B2) and Steam's BO3 + Mod Tools:

  powershell -ExecutionPolicy Bypass -File "<this folder>\migrate_scripts\import_bundle.ps1"

It clones the repo from GitHub, puts every file in this bundle where it belongs and finishes with
check_machine.ps1. Full instructions: SETUP_GUIDE.md (= docs/174 in the repo).
"@ | Set-Content -Encoding utf8 (PJ $Dest 'README.txt')
Info "BUNDLE OK -> $Dest"
