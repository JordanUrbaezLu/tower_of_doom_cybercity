# Transaction for this map's compiled upload files. Dot-source; no side effects.
# Keep previous packs/fastfiles/banks together until EVERY language passes.
function Get-TodLanguagePrefix([string]$Language) {
    $prefix = @{
        english='en'; englisharabic='ea'; french='fr'; german='ge'; italian='it'
        japanese='ja'; polish='po'; portuguese='bp'; russian='ru'
        simplifiedchinese='sc'; spanish='es'; traditionalchinese='tc'
    }[$Language]
    if (-not $prefix) { throw "Unknown language prefix for '$Language'; add the verified linker prefix before building." }
    return $prefix
}

# Existing Japanese SKU exclusions, independently confirmed in the model GDTs.
# The previous all-language build shipped these exclusions. Never waive a new
# missing model, a non-Japanese failure, or an asset whose flag has changed.
function Test-TodExpectedLanguageExclusion([string]$ToolsRoot, [string]$Language, [string]$Line) {
    if ($Language -ne 'japanese' -or $Line -notmatch "^ERROR: xmodel '([^']+)' is missing$") { return $false }
    $name = $Matches[1]
    $source = @{
        p7_gib_chunk_meat_02='model_export\t7_props\p7_gib_chunk_set\p7_gib_chunk_set.gdt'
        c_t8_zmb_mob_zombie_body3='model_export\kingslayer_kyle\characters\t8\c_t8_zmb_mob_zombie\c_t8_zmb_mob_zombie.gdt'
    }[$name]
    if (-not $source -or -not (Test-Path -LiteralPath (Join-Path $ToolsRoot $source))) { return $false }
    $definition = [regex]::Matches([IO.File]::ReadAllText((Join-Path $ToolsRoot $source)),
        '(?s)"' + [regex]::Escape($name) + '"\s*\(\s*"xmodel\.gdf"\s*\)\s*\{(.*?)\n\s*\}')
    return ($definition.Count -eq 1 -and $definition[0].Groups[1].Value -match '"japaneseUnsafe"\s+"1"')
}

function Assert-TodChildPath([string]$Path, [string]$Parent) {
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetFullPath($Parent).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing path outside '$Parent': $full"
    }
    return $full
}

function Get-TodCompiledFiles([string]$ZoneDir, [string]$MapName) {
    $pattern = '^(?:[a-z]{2}_)?' + [regex]::Escape($MapName) + '(?:\.[a-z]+)?\.(?:xpak|ff|sabs|sabl)$'
    @(Get-ChildItem -LiteralPath $ZoneDir -Recurse -File | Where-Object { $_.Name -match $pattern })
}

function Undo-TodCleanPaks($Transaction) {
    if (-not $Transaction -or $Transaction.Committed -or $Transaction.Restored) { return }
    foreach ($file in @(Get-TodCompiledFiles $Transaction.ZoneDir $Transaction.MapName)) {
        $full = Assert-TodChildPath $file.FullName $Transaction.ZoneDir
        if (-not $Transaction.OriginalPaths.ContainsKey($full)) { Remove-Item -LiteralPath $full -Force }
    }
    foreach ($entry in $Transaction.Entries) {
        if (-not (Test-Path -LiteralPath $entry.Backup)) { continue }
        $dst = Assert-TodChildPath $entry.Path $Transaction.ZoneDir
        $bak = Assert-TodChildPath $entry.Backup $Transaction.HoldDir
        # Copies keep recovery repeatable even if a locked file interrupts rollback.
        Copy-Item -LiteralPath $bak -Destination $dst -Force
    }
    $Transaction.Restored = $true
    Write-Warning "Clean-pack build failed; previous packs, fastfiles and upload sound banks restored. Backup: $($Transaction.HoldDir)"
}

function Start-TodCleanPaks([string]$ZoneDir, [string]$MapName, [string[]]$Languages) {
    $zone = (Resolve-Path -LiteralPath $ZoneDir).Path
    $holdRoot = Join-Path (Split-Path $zone -Parent) '_xpak_prev'
    $hold = Assert-TodChildPath (Join-Path $holdRoot ((Get-Date -Format 'yyyyMMdd_HHmmss_fff') + "_$PID")) $holdRoot
    if ($hold.StartsWith($zone.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Backup must be outside the upload folder.' }
    $expected = @("$MapName.xpak", "en_$MapName.xpak")
    foreach ($language in $Languages) { $expected += "$(Get-TodLanguagePrefix $language)_$MapName.xpak" }
    $expected = @($expected | Sort-Object -Unique)
    $tx = [pscustomobject]@{
        ZoneDir=$zone; MapName=$MapName; HoldDir=$hold; Started=Get-Date
        Expected=$expected; Entries=[Collections.Generic.List[object]]::new()
        OriginalPaths=@{}; Committed=$false; Restored=$false
    }
    $files = @(Get-TodCompiledFiles $zone $MapName)
    foreach ($file in $files) { $tx.OriginalPaths[$file.FullName] = $true }
    New-Item -ItemType Directory -Path $hold -Force | Out-Null
    try {
        foreach ($file in $files) {
            $src = Assert-TodChildPath $file.FullName $zone
            $relative = $src.Substring($zone.Length).TrimStart('\','/')
            $bak = Assert-TodChildPath (Join-Path $hold $relative) $hold
            New-Item -ItemType Directory -Path (Split-Path $bak -Parent) -Force | Out-Null
            if ($file.Extension -eq '.xpak' -and $expected -contains $file.Name) {
                Move-Item -LiteralPath $src -Destination $bak
            } else {
                Copy-Item -LiteralPath $src -Destination $bak
            }
            $tx.Entries.Add([pscustomobject]@{ Path=$src; Backup=$bak; Length=$file.Length })
        }
        $tx | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $hold 'transaction.json') -Encoding UTF8
        return $tx
    } catch {
        Undo-TodCleanPaks $tx
        throw
    }
}

function Assert-TodPack([string]$Path, [datetime]$Since, [long]$MinimumBytes=128) {
    $file = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($file.Length -lt $MinimumBytes -or $file.LastWriteTime -le $Since) { throw "Missing, truncated or stale pack: $Path" }
    $stream = [IO.File]::OpenRead($Path)
    try {
        $header = New-Object byte[] 120
        if ($stream.Read($header,0,120) -ne 120 -or [Text.Encoding]::ASCII.GetString($header,0,4) -ne 'KAPI') { throw "Invalid pack header: $Path" }
        foreach ($pair in @(@(56,64), @(104,112))) {
            $offset = [BitConverter]::ToUInt64($header,$pair[0])
            $length = [BitConverter]::ToUInt64($header,$pair[1])
            if ($offset -gt $file.Length -or $length -gt ($file.Length - $offset)) { throw "Truncated pack index: $Path" }
        }
    } finally { $stream.Dispose() }
}

function Complete-TodCleanPaks($Transaction) {
    foreach ($name in $Transaction.Expected) {
        $minimum = if ($name -eq "$($Transaction.MapName).xpak") { 256MB } else { 128 }
        Assert-TodPack (Join-Path $Transaction.ZoneDir $name) $Transaction.Started $minimum
        $ff = Get-Item -LiteralPath (Join-Path $Transaction.ZoneDir ($name -replace '\.xpak$', '.ff')) -ErrorAction Stop
        if ($ff.LastWriteTime -le $Transaction.Started -or $ff.Length -lt 128) { throw "Missing or stale fastfile: $($ff.FullName)" }
    }
    # Commit only after the caller's final language/bank checks. Cleanup cannot
    # convert a valid build into a failed rollback with half the backups removed.
    $Transaction.Committed = $true
    foreach ($entry in $Transaction.Entries) {
        $bak = Assert-TodChildPath $entry.Backup $Transaction.HoldDir
        Remove-Item -LiteralPath $bak -Force -ErrorAction Continue
    }
    $Transaction | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Transaction.HoldDir 'transaction.json') -Encoding UTF8
}
