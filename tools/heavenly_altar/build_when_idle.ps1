# This task's authorized full build waits for the user's match and other builds.
# It never terminates a game process and never launches the game afterward.
param([string]$EvidenceDirectory = 'tmp/heavenly_altar_integration')
$ErrorActionPreference = 'Stop'
$altarRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location -LiteralPath $altarRoot
$env:ALTAR_VERIFY_OUT = [IO.Path]::GetFullPath((Join-Path $altarRoot $EvidenceDirectory))
New-Item -ItemType Directory -Force -Path $env:ALTAR_VERIFY_OUT | Out-Null
$lastState = ''
while ($true) {
    $game = @(Get-Process BlackOps3 -ErrorAction SilentlyContinue)
    $peer = @(Get-CimInstance Win32_Process | Where-Object {
        $_.ProcessId -ne $PID -and (
            $_.Name -in @('linker_modtools.exe','cod2map64.exe','Radiant_modtools.exe') -or
            ($_.Name -in @('powershell.exe','pwsh.exe') -and $_.CommandLine -match '-File\s+[^\r\n]*tools[\\/]build_map\.ps1')
        )
    })
    $state = if ($game.Count) { 'Waiting for BO3 to close; active match is untouched.' } elseif ($peer.Count) { 'Waiting for the other Mod Tools build to finish.' } else { 'Ready to build.' }
    if ($state -ne $lastState) { Write-Output $state; $lastState = $state }
    if (-not $game.Count -and -not $peer.Count) { break }
    Start-Sleep -Seconds 5
}
& python tools/heavenly_altar/verify_deployment.py --snapshot
if ($LASTEXITCODE -ne 0) { throw 'Altar source snapshot failed' }
& powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_map.ps1 *> (Join-Path $env:ALTAR_VERIFY_OUT 'build.log')
if ($LASTEXITCODE -ne 0) { throw "Full build failed; inspect $env:ALTAR_VERIFY_OUT/build.log" }
& python tools/heavenly_altar/verify_deployment.py
if ($LASTEXITCODE -ne 0) { throw 'Exact-source deployment verification failed' }
Write-Output 'ALTAR_BUILD_AND_DEPLOYMENT_VERIFIED'
