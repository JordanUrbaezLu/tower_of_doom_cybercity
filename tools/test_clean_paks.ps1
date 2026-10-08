$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'clean_paks.ps1')
$work = Join-Path ([IO.Path]::GetTempPath()) ('tod_cleanpak_test_' + [guid]::NewGuid().ToString('N'))
$zone = Join-Path $work 'zone'
New-Item -ItemType Directory -Path $zone | Out-Null
function Check($condition, $message) { if (-not $condition) { throw $message } }
function Write-Pack([string]$file, [long]$size=256) {
    $head = New-Object byte[] 120
    [Text.Encoding]::ASCII.GetBytes('KAPI').CopyTo($head,0)
    [BitConverter]::GetBytes([uint64]$size).CopyTo($head,16)
    [BitConverter]::GetBytes([uint64]120).CopyTo($head,56)
    [BitConverter]::GetBytes([uint64]120).CopyTo($head,104)
    $stream=[IO.File]::Create($file)
    try { $stream.Write($head,0,120); $stream.SetLength($size) } finally { $stream.Dispose() }
}
try {
    foreach ($name in @('zm_test.xpak','en_zm_test.xpak','fr_zm_test.xpak')) { Write-Pack (Join-Path $zone $name) }
    foreach ($name in @('zm_test.ff','en_zm_test.ff','fr_zm_test.ff','zm_test.all.sabs')) {
        [IO.File]::WriteAllBytes((Join-Path $zone $name), (New-Object byte[] 256))
    }
    [IO.File]::WriteAllText((Join-Path $zone 'other_map.xpak'),'unrelated')
    $original=@{}
    foreach ($file in @(Get-TodCompiledFiles $zone 'zm_test')) { $original[$file.Name]=(Get-FileHash -LiteralPath $file.FullName).Hash }
    $tx=Start-TodCleanPaks $zone 'zm_test' @('french')
    Check (-not (Test-Path (Join-Path $zone 'fr_zm_test.xpak'))) 'language pack was not staged'
    Check (Test-Path (Join-Path $zone 'other_map.xpak')) 'unrelated file was touched'
    # A late language failure: English has new outputs, one language is missing,
    # an existing bank was overwritten and the linker added a new bank.
    Write-Pack (Join-Path $zone 'zm_test.xpak') (256MB+128)
    Write-Pack (Join-Path $zone 'en_zm_test.xpak')
    Set-Content -LiteralPath (Join-Path $zone 'zm_test.ff') -Value 'partial'
    Set-Content -LiteralPath (Join-Path $zone 'zm_test.all.sabs') -Value 'partial bank'
    Set-Content -LiteralPath (Join-Path $zone 'zm_test.fr.sabs') -Value 'new bank'
    $failed=$false
    try { Complete-TodCleanPaks $tx } catch { $failed=$true }
    Check $failed 'missing language should reject commit'
    Undo-TodCleanPaks $tx
    foreach ($name in $original.Keys) { Check ((Get-FileHash -LiteralPath (Join-Path $zone $name)).Hash -eq $original[$name]) "rollback mismatch: $name" }
    Check (-not (Test-Path (Join-Path $zone 'zm_test.fr.sabs'))) 'new partial bank survived rollback'
    Write-Host 'PASS: late-language failure restores all original packs, fastfiles and banks'

    $tx=Start-TodCleanPaks $zone 'zm_test' @('french')
    foreach ($name in $tx.Expected) {
        $size=if ($name -eq 'zm_test.xpak') { 256MB+128 } else { 256 }
        Write-Pack (Join-Path $zone $name) $size
        [IO.File]::WriteAllBytes((Join-Path $zone ($name -replace '\.xpak$','.ff')), (New-Object byte[] 256))
        (Get-Item -LiteralPath (Join-Path $zone $name)).LastWriteTime=$tx.Started.AddSeconds(1)
        (Get-Item -LiteralPath (Join-Path $zone ($name -replace '\.xpak$','.ff'))).LastWriteTime=$tx.Started.AddSeconds(1)
    }
    Complete-TodCleanPaks $tx
    Check $tx.Committed 'valid complete set did not commit'
    Check (@($tx.Entries | Where-Object { Test-Path -LiteralPath $_.Backup }).Count -eq 0) 'committed backups not cleaned'
    Write-Host 'PASS: complete fresh set commits and releases old payloads'
    $file=Join-Path $zone 'fr_zm_test.xpak'
    $stream=[IO.File]::OpenWrite($file)
    try { $stream.Position=104; $bytes=[BitConverter]::GetBytes([uint64]999999); $stream.Write($bytes,0,8) } finally { $stream.Dispose() }
    $failed=$false; try { Assert-TodPack $file ([datetime]::MinValue) } catch { $failed=$true }
    Check $failed 'out-of-file index accepted'
    $failed=$false; try { Assert-TodChildPath (Join-Path $work 'escape.xpak') $zone } catch { $failed=$true }
    Check $failed 'outside path accepted'
    Check ((Get-TodLanguagePrefix 'englisharabic') -eq 'ea') 'Arabic prefix mismatch'
    Write-Host 'PASS: corrupt index and path escape rejected; language prefix checked'
    $modelFile=Join-Path $work 'model_export\t7_props\p7_gib_chunk_set\p7_gib_chunk_set.gdt'
    New-Item -ItemType Directory -Path (Split-Path $modelFile -Parent) -Force | Out-Null
    $modelText="`"p7_gib_chunk_meat_02`" ( `"xmodel.gdf`" ) {`n `"japaneseUnsafe`" `"1`"`n}"
    [IO.File]::WriteAllText($modelFile,$modelText)
    $errorLine="ERROR: xmodel 'p7_gib_chunk_meat_02' is missing"
    Check (Test-TodExpectedLanguageExclusion $work 'japanese' $errorLine) 'known Japanese exclusion rejected'
    Check (-not (Test-TodExpectedLanguageExclusion $work 'english' $errorLine)) 'English missing model waived'
    Check (-not (Test-TodExpectedLanguageExclusion $work 'japanese' "ERROR: xmodel 'unrelated' is missing")) 'new missing model waived'
    [IO.File]::WriteAllText($modelFile,($modelText -replace '"1"','"0"'))
    Check (-not (Test-TodExpectedLanguageExclusion $work 'japanese' $errorLine)) 'changed unsafe flag still waived'
    Write-Host 'PASS: Japanese exclusions require the exact language, asset and current GDT flag'
} finally {
    # Explicitly verify the recursive target before removing this test's tree.
    $checked=Assert-TodChildPath $work ([IO.Path]::GetTempPath())
    if ((Split-Path $checked -Leaf) -notlike 'tod_cleanpak_test_*') { throw 'Unexpected test cleanup target' }
    Remove-Item -LiteralPath $checked -Recurse -Force
}
