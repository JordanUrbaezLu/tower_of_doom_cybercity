# Resume the authorized Ice Staff extraction through one ordinary UAC prompt.
# Loads only the four observed installed staff packages, then starts the guarded
# Saluki controller. No game launch, executable dumping or networking changes.
param([switch]$Elevated,[string]$SessionDir='')
$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot)
$sibling=Join-Path (Split-Path $repo) 'tower_of_doom_II_hellbound'
$pilot='C:\Users\jorda\Documents\BO3_tools\BO6_Pilot'
$task='tod_bo6_ice_staff'
$leasePath=Join-Path $pilot 'saluki_active_task.json'
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if ($Elevated) {
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator token missing' }
    if (-not $SessionDir -or -not (Test-Path -LiteralPath $SessionDir -PathType Container)) { throw 'Session directory missing' }
    try {
        $lease=Get-Content -LiteralPath $leasePath -Raw | ConvertFrom-Json
        if ($lease.task -ne $task -or $lease.session -ne $SessionDir) { throw 'Extractor ownership changed' }
        $names=@('mp_av_wpn_t10_vm_ww_zmb_staffs_tr','mp_av_att_t10_vm_ww_zmb_staffs_water_tip_tr','mp_aw_wpn_t10_vm_ww_zmb_staffs_tr','mp_aw_att_t10_vm_ww_zmb_staffs_water_tip_tr')
        foreach ($name in $names) {
            $result=Join-Path $SessionDir ('load_'+$name+'.json')
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sibling 'tools/bo6_extraction/load_bo6_file.ps1') -Name $name -Elevated -ResultPath $result
            if ($LASTEXITCODE -ne 0) { throw ('Package load failed: '+$name) }
            $receipt=Get-Content -LiteralPath $result -Raw | ConvertFrom-Json
            if (-not $receipt.ok) { throw ('No successful load receipt: '+$name) }
        }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'saluki_ui_session.ps1') -SessionDir $SessionDir -DurationMinutes 90
        exit $LASTEXITCODE
    } catch {
        $_ | Out-String | Set-Content -LiteralPath (Join-Path $SessionDir 'worker_error.txt') -Encoding UTF8
        exit 1
    }
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $sibling 'tools/start_bo6_extraction.ps1') -Check
if ($LASTEXITCODE -ne 0) { throw 'BO6 preflight failed' }
if (@(Get-Process BlackOps3,'cod24-cod',cod,'sp24-cod','cod25-cod' -ErrorAction SilentlyContinue).Count) { throw 'An actual game is running' }
if (Test-Path -LiteralPath $leasePath) {
    $lease=Get-Content -LiteralPath $leasePath -Raw | ConvertFrom-Json
    if ([DateTimeOffset]::Parse($lease.expires) -gt [DateTimeOffset]::Now) { throw ('Extractor already reserved by '+$lease.task+'; reuse its controller') }
}
$SessionDir=Join-Path $pilot ('saluki_'+$task+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path $SessionDir -ErrorAction Stop | Out-Null
$scratch=Join-Path $repo 'tmp/bo6_ice_staff'
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$SessionDir | Set-Content -LiteralPath (Join-Path $scratch 'session.txt') -Encoding UTF8
@{task=$task;session=$SessionDir;reason='User resumed all uncharged staff presentation and test preparation on 2026-09-13';expires=[DateTimeOffset]::Now.AddMinutes(95).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $leasePath -Encoding UTF8
try {
    $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Elevated -SessionDir "'+$SessionDir+'"'
    $worker=Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -PassThru
    $deadline=[DateTime]::UtcNow.AddSeconds(120)
    while (-not (Test-Path -LiteralPath (Join-Path $SessionDir 'ready.json'))) {
        if ($worker.HasExited) { throw ('Extraction worker exited; inspect '+$SessionDir) }
        if ([DateTime]::UtcNow -gt $deadline) { throw ('Readiness timed out; inspect '+$SessionDir+' before any retry') }
        Start-Sleep -Milliseconds 300
    }
    Get-Content -LiteralPath (Join-Path $SessionDir 'ready.json') -Raw
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $SessionDir 'startup_error.txt') -Encoding UTF8
    # Do not release an ownership lease for a worker that may still be running.
    if (-not $worker -or $worker.HasExited) {
        $lease=Get-Content -LiteralPath $leasePath -Raw | ConvertFrom-Json
        if ($lease.task -eq $task -and $lease.session -eq $SessionDir) {
            $lease.expires=[DateTimeOffset]::Now.ToString('o')
            $lease | ConvertTo-Json | Set-Content -LiteralPath $leasePath -Encoding UTF8
        }
    }
    throw
}
