# =============================================================================
# run_game.ps1 - launch the already-built map straight into the game.
#
# Launch THROUGH Steam (steam://run/311210) - a raw BlackOps3.exe launch trips
# the DRM. THE GAMETYPE FIX: pass `+set_gametype zclassic` (engine command,
# sticks), NOT `+set g_gametype zclassic` (resets to tdm -> black screen).
# Keep BO3's Steam LAUNCH OPTIONS EMPTY (Steam appends them = doubled args).
#
# Usage:  .\tools\run_game.ps1     (build first: .\tools\build_map.ps1)
# Dev/god are NOT launch flags - they are hardcoded in the build
# (zm_tower_of_doom.gsc::tod_resolve_dev_flags + rebuild).
# =============================================================================

# BUILD-IN-PROGRESS GUARD: launching while the linker writes the .ff loads a
# half-written fastfile (= "UI Error" box / corrupt load). Refuse.
$buildProcs = Get-Process linker_modtools, cod2map64, radiant_modtools -ErrorAction SilentlyContinue
if ($buildProcs) {
    Write-Host ""
    Write-Host "[run_game] BUILD IN PROGRESS - NOT launching:" -ForegroundColor Red
    $buildProcs | ForEach-Object { Write-Host ("    {0} (pid {1})" -f $_.ProcessName, $_.Id) -ForegroundColor Red }
    Write-Host "[run_game] Wait for the build to finish, then run this again." -ForegroundColor Yellow
    exit 1
}

$gameArgs = "+set fs_game zm_tower_of_doom +set_gametype zclassic +devmap zm_tower_of_doom +set developer 1 +set logfile 2"

Write-Host "launching BO3 through Steam (DRM-safe): steam://run/311210"
Write-Host "args: $gameArgs"
Start-Process "steam://run/311210//$gameArgs"

# Wait for the game to come up (asset load takes ~30-60s).
for ($i = 0; $i -lt 18; $i++) {
    Start-Sleep -Seconds 5
    $p = Get-Process BlackOps3 -ErrorAction SilentlyContinue
    if ($p) {
        $gb = [math]::Round($p.WorkingSet64 / 1GB, 1)
        Write-Host ("  +{0,3}s  PID {1}  {2} GB  responding={3}" -f (($i + 1) * 5), $p.Id, $gb, $p.Responding)
        if ($gb -ge 4) { Write-Host "loaded - you should be in zm_tower_of_doom."; break }
    } else {
        Write-Host ("  +{0,3}s  not up yet" -f (($i + 1) * 5))
    }
}
