# Preserve the raw console and a searchable diagnostic extract before a relaunch.
# Safe to run during play too: source is opened with ReadWrite/Delete sharing.
param(
    [string]$GameRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III',
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..\tmp\elite_tracking\runs')
)
$ErrorActionPreference = 'Stop'
$source = Join-Path $GameRoot 'console_mp.log'
if (-not (Test-Path -LiteralPath $source)) {
    Write-Host '[ai_logs] No console log exists yet.'
    return
}
$run = Join-Path $OutputRoot ((Get-Date).ToString('yyyyMMdd_HHmmss_fff') + '_' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$copy = Join-Path $run 'console_mp.log'
$inputStream = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
try {
    $outputStream = [IO.File]::Create($copy)
    try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
} finally { $inputStream.Dispose() }
# Keep every original line; the extract is only an aid, never the sole evidence.
Select-String -LiteralPath $copy -Pattern '\[TOD_[A-Z0-9_]+\]|\d+(?:START schema|WORLD round|PLAYER id|ACTOR id|ELITE id|APPEAR id|GONE id|NAV id|MOTION id|STATE id|PROBE id|ROUTE id|TICK gap|EVENT GATE)|PATHFIND_FAILURE|SCRIPT ERROR|UNRECOVERABLE|Error:|\[TOD.*(?:probe|NAV)' |
    ForEach-Object { '{0}: {1}' -f $_.LineNumber, $_.Line } |
    Set-Content -LiteralPath (Join-Path $run 'diagnostics.txt') -Encoding UTF8
$repo = Split-Path $PSScriptRoot -Parent
$manifest = [ordered]@{
    captured_at = (Get-Date).ToString('o')
    original_log = $source
    log_bytes = (Get-Item -LiteralPath $copy).Length
    log_sha256 = (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash
    note = 'Hashes describe files at capture time; use TOD_AI START build tag to identify the logged recorder. A live capture can end mid-line.'
    files = @()
}
foreach ($relative in @('scripts\zm\zm_tower_of_doom\_tod_bosses.gsc', 'scripts\zm\zm_tower_of_doom\_tod_spire.gsc', 'scripts\zm\zm_tower_of_doom.gsc', 'map_source\zm\zm_tower_of_doom.map')) {
    $path = Join-Path $repo $relative
    if (Test-Path -LiteralPath $path) {
        $manifest.files += @{ path = $path; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash; modified = (Get-Item -LiteralPath $path).LastWriteTime.ToString('o') }
    }
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $run 'capture.json') -Encoding UTF8
Write-Host "[ai_logs] Saved $run"
