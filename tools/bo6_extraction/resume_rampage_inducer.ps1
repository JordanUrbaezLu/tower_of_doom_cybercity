# Start the guarded Saluki controller for the BO6 rampage inducer model export
# through one ordinary UAC prompt. Cordycep already holds the common Zombies
# files + zm_t10_garnet; nothing is loaded, dumped or changed on the network.
param([switch]$Elevated,[string]$SessionDir='')
$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot)
$sibling=Join-Path (Split-Path $repo) 'tower_of_doom_II_hellbound'
$pilot='C:\Users\jorda\Documents\BO3_tools\BO6_Pilot'
$task='tod_bo6_rampage_inducer'
$leasePath=Join-Path $pilot 'saluki_active_task.json'
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if ($Elevated) {
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator token missing' }
    if (-not $SessionDir -or -not (Test-Path -LiteralPath $SessionDir -PathType Container)) { throw 'Session directory missing' }
    try {
        $lease=Get-Content -LiteralPath $leasePath -Raw | ConvertFrom-Json
        if ($lease.task -ne $task -or $lease.session -ne $SessionDir) { throw 'Extractor ownership changed' }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'saluki_ui_session.ps1') -SessionDir $SessionDir -DurationMinutes 60
        exit $LASTEXITCODE
    } catch {
        $_ | Out-String | Set-Content -LiteralPath (Join-Path $SessionDir 'worker_error.txt') -Encoding UTF8
        exit 1
    }
}
if (@(Get-Process BlackOps3,'cod24-cod',cod,'sp24-cod','cod25-cod' -ErrorAction SilentlyContinue).Count) { throw 'An actual game is running' }
if (-not (Get-Process Saluki -ErrorAction SilentlyContinue)) { throw 'Saluki is not running; use the Extract BO6 shortcut first' }
if (Test-Path -LiteralPath $leasePath) {
    $lease=Get-Content -LiteralPath $leasePath -Raw | ConvertFrom-Json
    if ([DateTimeOffset]::Parse($lease.expires) -gt [DateTimeOffset]::Now -and $lease.task -ne $task) { throw ('Extractor already reserved by '+$lease.task+'; reuse its controller') }
}
$SessionDir=Join-Path $pilot ('saluki_'+$task+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path $SessionDir -ErrorAction Stop | Out-Null
$scratch=Join-Path $repo 'tmp/bo6_rampage_inducer'
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$SessionDir | Set-Content -LiteralPath (Join-Path $scratch 'session.txt') -Encoding UTF8
@{task=$task;session=$SessionDir;reason='User asked for the BO6 rampage inducer model on 2026-09-13';expires=[DateTimeOffset]::Now.AddMinutes(65).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $leasePath -Encoding UTF8
try {
    $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Elevated -SessionDir "'+$SessionDir+'"'
    $worker=Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -PassThru
    $deadline=[DateTime]::UtcNow.AddSeconds(150)
    while (-not (Test-Path -LiteralPath (Join-Path $SessionDir 'ready.json'))) {
        if ($worker.HasExited) { throw ('Extraction worker exited; inspect '+$SessionDir) }
        if ([DateTime]::UtcNow -gt $deadline) { throw ('Readiness timed out; inspect '+$SessionDir+' before any retry') }
        Start-Sleep -Milliseconds 300
    }
    Get-Content -LiteralPath (Join-Path $SessionDir 'ready.json') -Raw
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $SessionDir 'startup_error.txt') -Encoding UTF8
    if (-not $worker -or $worker.HasExited) {
        $lease=Get-Content -LiteralPath $leasePath -Raw | ConvertFrom-Json
        if ($lease.task -eq $task -and $lease.session -eq $SessionDir) {
            $lease.expires=[DateTimeOffset]::Now.ToString('o')
            $lease | ConvertTo-Json | Set-Content -LiteralPath $leasePath -Encoding UTF8
        }
    }
    throw
}
