<#
.SYNOPSIS
  ART REQUEST PACKS - build the zip the user hands to their asset generator,
  or inspect the drop that comes back.

.DESCRIPTION
  ONE SOURCE OF TRUTH: the brief is a repo doc, docs/NN_<thing>_art_prompt.md.
  This script turns it into ~/Downloads/tod_<name>_art_pack.zip with the shape
  every generator hand-off has used since 2026-09-01:

      <name>/INSTRUCTIONS.md              the generator-facing brief (verbatim
                                          from the doc's PACK section)
      <name>/reference/<image>.png        the CURRENT shipped files to match
      <name>/reference/README.md          generated from the doc's refs list
      <name>/preview_onscreen_<WxH>/...   each PNG ref downscaled to its real
                                          on-screen size (optional)

  THE DOC FORMAT (see docs/73 for the worked example):

      <!-- art-pack
      name: tier_gate_legibility
      refs:
        i_tod_tier_gate_2.png | the CURRENT tier-2 badge; keep chassis, replace type
        i_tod_badge_luck_100.png | the luck badge; its TYPE treatment is the target
      preview: 280x60
      -->
      ...repo-facing STATUS / why / install notes, anything...
      <!-- PACK:BEGIN -->
      ...the generator-facing brief: deliverables, hard rules, prompts,
      checklist, do-NOT list. NO repo internals, NO absolute paths...
      <!-- PACK:END -->

  A ref with no slash resolves under source_data/tod_ui_images/_images/;
  a ref with a slash is repo-relative. `preview:` takes zero or more WxH.

  GATES: every ref must exist; the PACK section must exist; INSTRUCTIONS.md
  must contain no absolute path (a generator cannot open C:\ anything) - that
  FAILS. Repo-internal words (docs/, .gsc, .lua, .gdt, CLAUDE.md, scratchpad)
  only WARN: the generator does not need them, but they are not fatal.

.PARAMETER Doc
  The docs/NN_*_art_prompt.md brief to pack (positional).

.PARAMETER Inspect
  A returned drop to look at instead: "files (N).zip" (resolved in ~/Downloads
  when not an absolute path). Extracts it (nested zips too), prints every
  PNG's size / colour type / md5, and whether a same-named repo image exists
  and differs. It never installs anything - LOOK at the images first.

.PARAMETER NoZip
  Stage the folder and report, but do not write the zip.

.EXAMPLE
  .\tools\make_art_pack.ps1 docs\73_tier_gate_legibility_art_prompt.md
  .\tools\make_art_pack.ps1 -Inspect "files (100).zip"
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Doc,
    [string] $Inspect,
    [switch] $NoZip
)

$ErrorActionPreference = "Stop"
$Root      = Split-Path -Parent $PSScriptRoot
$ImagesDir = Join-Path $Root "source_data\tod_ui_images\_images"
$Downloads = Join-Path $env:USERPROFILE "Downloads"
$Stamp     = Get-Date -Format "yyyyMMdd_HHmmss"
$Work      = Join-Path $env:TEMP ("tod_art_packs\" + $Stamp)

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
function Read-PngHeader([string] $Path) {
    $b = [System.IO.File]::ReadAllBytes($Path)
    if ($b.Length -lt 26 -or $b[0] -ne 0x89 -or $b[1] -ne 0x50 -or $b[2] -ne 0x4E -or $b[3] -ne 0x47) {
        return $null
    }
    $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
    $h = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
    $ct = [int]$b[25]
    $ctName = "unknown"
    if ($ct -eq 6) { $ctName = "RGBA" }
    elseif ($ct -eq 2) { $ctName = "RGB (no alpha)" }
    elseif ($ct -eq 3) { $ctName = "palette" }
    elseif ($ct -eq 0) { $ctName = "gray" }
    elseif ($ct -eq 4) { $ctName = "gray+alpha" }
    return [pscustomobject]@{ Width = $w; Height = $h; Depth = [int]$b[24]; ColorType = $ct; ColorName = $ctName }
}

function Get-Md5([string] $Path) {
    return (Get-FileHash -Path $Path -Algorithm MD5).Hash.ToLower()
}

function New-Preview([string] $Src, [string] $Dst, [int] $W, [int] $H) {
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($Src)
    try {
        $bmp = New-Object System.Drawing.Bitmap -ArgumentList $W, $H
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingMode   = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $g.DrawImage($img, 0, 0, $W, $H)
        $g.Dispose()
        $bmp.Save($Dst, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
    } finally {
        $img.Dispose()
    }
}

function Write-Utf8NoBom([string] $Path, [string] $Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

# ---------------------------------------------------------------------------
# INSPECT a returned drop
# ---------------------------------------------------------------------------
if ($Inspect) {
    $zip = $Inspect
    if (-not [System.IO.Path]::IsPathRooted($zip)) { $zip = Join-Path $Downloads $zip }
    if (-not (Test-Path $zip)) { throw "drop not found: $zip" }

    $dst = Join-Path $Work "inspect"
    New-Item -ItemType Directory -Force $dst | Out-Null
    Expand-Archive -Path $zip -DestinationPath $dst -Force
    # nested zips (generators often ship the set twice: loose + zipped)
    foreach ($nz in (Get-ChildItem $dst -Recurse -Filter *.zip)) {
        Expand-Archive -Path $nz.FullName -DestinationPath (Join-Path $nz.DirectoryName ($nz.BaseName + "_unzipped")) -Force
    }

    Write-Host ""
    Write-Host "[art-pack] INSPECT $zip"
    Write-Host "[art-pack] extracted to $dst  (LOOK at every image there before installing anything)"
    Write-Host ""
    $rows = @()
    foreach ($f in (Get-ChildItem $dst -Recurse -File | Sort-Object FullName)) {
        $rel = $f.FullName.Substring($dst.Length + 1)
        if ($f.Extension -ieq ".png") {
            $hdr = Read-PngHeader $f.FullName
            $md5 = Get-Md5 $f.FullName
            $repo = Join-Path $ImagesDir $f.Name
            $status = "NEW NAME (needs a GDT block + zone image line + Lua slug)"
            if (Test-Path $repo) {
                if ((Get-Md5 $repo) -eq $md5) { $status = "IDENTICAL to repo copy (nothing to install)" }
                else { $status = "REPLACES repo copy (same name: no wiring, FULL build)" }
            }
            $dims = "not a PNG"
            if ($hdr) { $dims = "{0}x{1} {2}" -f $hdr.Width, $hdr.Height, $hdr.ColorName }
            $rows += [pscustomobject]@{ File = $rel; Bytes = $f.Length; Dims = $dims; Md5 = $md5.Substring(0, 8); Status = $status }
        }
        elseif ($f.Extension -ine ".zip") {
            $rows += [pscustomobject]@{ File = $rel; Bytes = $f.Length; Dims = ""; Md5 = ""; Status = "(non-image)" }
        }
    }
    $rows | Format-Table -AutoSize -Wrap | Out-String -Width 220 | Write-Host
    Write-Host "[art-pack] next: Read each PNG, proofread the baked text, overlay against the shipped file,"
    Write-Host "           copy into source_data/tod_ui_images/_images/, FULL build, prove with a fresh content-hash .iwi."
    return
}

# ---------------------------------------------------------------------------
# BUILD a pack from a doc
# ---------------------------------------------------------------------------
if (-not $Doc) { throw "usage: make_art_pack.ps1 <docs/NN_thing_art_prompt.md>   |   -Inspect 'files (N).zip'" }
$DocPath = $Doc
if (-not [System.IO.Path]::IsPathRooted($DocPath)) { $DocPath = Join-Path $Root $DocPath }
if (-not (Test-Path $DocPath)) { throw "doc not found: $DocPath" }
$text = Get-Content -Raw -Encoding UTF8 $DocPath

# --- the art-pack header block ---------------------------------------------
$m = [regex]::Match($text, '(?s)<!--\s*art-pack\s*\r?\n(.*?)-->')
if (-not $m.Success) { throw "no '<!-- art-pack ... -->' block in $Doc (see the header of this script for the format)" }
$name = $null
$previews = @()
$refs = @()
$mode = ""
foreach ($line in ($m.Groups[1].Value -split "`r?`n")) {
    $t = $line.Trim()
    if ($t -eq "") { continue }
    if ($t -match '^name:\s*(.+)$') { $name = $Matches[1].Trim(); $mode = ""; continue }
    if ($t -match '^preview:\s*(.*)$') {
        $previews = @($Matches[1].Trim() -split '\s+' | Where-Object { $_ -match '^\d+x\d+$' })
        $mode = ""; continue
    }
    if ($t -match '^refs:\s*$') { $mode = "refs"; continue }
    if ($mode -eq "refs") {
        $parts = $t -split '\|', 2
        $desc = ""
        if ($parts.Count -gt 1) { $desc = $parts[1].Trim() }
        $refs += [pscustomobject]@{ Spec = $parts[0].Trim(); Desc = $desc }
        continue
    }
    throw "art-pack block: unrecognised line '$t'"
}
if (-not $name) { throw "art-pack block has no 'name:'" }
if ($name -notmatch '^[a-z0-9_]+$') { throw "art-pack name '$name' must be lower_snake_case (it becomes tod_<name>_art_pack.zip)" }
if ($refs.Count -eq 0) { throw "art-pack block lists no refs: - a generator with nothing to match drifts" }

# --- the PACK section = INSTRUCTIONS.md --------------------------------------
$pm = [regex]::Match($text, '(?s)<!--\s*PACK:BEGIN\s*-->\r?\n(.*?)\r?\n\s*<!--\s*PACK:END\s*-->')
if (-not $pm.Success) { throw "no '<!-- PACK:BEGIN -->' ... '<!-- PACK:END -->' section in $Doc" }
$instructions = $pm.Groups[1].Value.TrimEnd() + "`n"

$fail = @()
$warn = @()
if ($instructions -match '[A-Za-z]:\\' -or $instructions -match '/[a-z]/Users/') {
    $fail += "INSTRUCTIONS.md contains an absolute path - the generator cannot open it; refer to files by their name inside the zip"
}
foreach ($pat in @('docs/', '\.gsc', '\.lua', '\.gdt', '\.zone', 'CLAUDE\.md', 'scratchpad', 'zone_source', 'source_data')) {
    if ($instructions -match $pat) { $warn += "INSTRUCTIONS.md mentions '$pat' - repo internals the generator does not need" }
}
foreach ($ref in $refs) {
    $leaf = Split-Path $ref.Spec -Leaf
    if ($instructions -notmatch [regex]::Escape($leaf)) {
        $warn += "reference '$leaf' is never named in INSTRUCTIONS.md - say which prompt attaches it"
    }
}

# --- resolve refs ---------------------------------------------------------------
$resolved = @()
foreach ($ref in $refs) {
    $p = $ref.Spec
    if ($p -match '[\\/]') { $p = Join-Path $Root $p } else { $p = Join-Path $ImagesDir $p }
    if (-not (Test-Path $p)) { $fail += "ref not found: $($ref.Spec)  (looked at $p)"; continue }
    $resolved += [pscustomobject]@{ Path = (Resolve-Path $p).Path; Leaf = (Split-Path $p -Leaf); Desc = $ref.Desc }
}
if ($fail.Count -gt 0) {
    foreach ($f in $fail) { Write-Host "[art-pack] FAIL: $f" -ForegroundColor Red }
    throw "art-pack: $($fail.Count) gate failure(s)"
}
foreach ($w in $warn) { Write-Host "[art-pack] WARN: $w" -ForegroundColor Yellow }

# --- stage --------------------------------------------------------------------
$PackDir = Join-Path $Work $name
$RefDir  = Join-Path $PackDir "reference"
New-Item -ItemType Directory -Force $RefDir | Out-Null
Write-Utf8NoBom (Join-Path $PackDir "INSTRUCTIONS.md") $instructions

Write-Host ""
Write-Host "[art-pack] $name  <-  $Doc"
Write-Host "[art-pack] reference/"
$readme = "# reference/`n`n"
$readme += "The CURRENT shipped files, unmodified. Attach the ones each prompt in INSTRUCTIONS.md names.`n`n"
foreach ($r in $resolved) {
    Copy-Item $r.Path (Join-Path $RefDir $r.Leaf) -Force
    $hdr = $null
    if ($r.Leaf -match '\.png$') { $hdr = Read-PngHeader $r.Path }
    $dims = ""
    if ($hdr) {
        $dims = "{0}x{1} {2}" -f $hdr.Width, $hdr.Height, $hdr.ColorName
        if ($hdr.ColorType -ne 6) { Write-Host "[art-pack] WARN: $($r.Leaf) is $($hdr.ColorName), not RGBA" -ForegroundColor Yellow }
    }
    Write-Host ("    {0,-36} {1,-16} {2}" -f $r.Leaf, $dims, $r.Desc)
    $line = "- ``$($r.Leaf)``"
    if ($dims) { $line += " ($dims)" }
    if ($r.Desc) { $line += " - $($r.Desc)" }
    $readme += $line + "`n"
}

# --- previews (each PNG ref at its real on-screen size) ------------------------
foreach ($pv in $previews) {
    $wh = $pv -split 'x'
    $W = [int]$wh[0]; $H = [int]$wh[1]
    $PvDir = Join-Path $PackDir ("preview_onscreen_" + $pv)
    New-Item -ItemType Directory -Force $PvDir | Out-Null
    $made = 0
    foreach ($r in $resolved) {
        if ($r.Leaf -notmatch '\.png$') { continue }
        $hdr = Read-PngHeader $r.Path
        if (-not $hdr) { continue }
        $srcAspect = $hdr.Width / [double]$hdr.Height
        $dstAspect = $W / [double]$H
        if ([Math]::Abs($srcAspect - $dstAspect) / $dstAspect -gt 0.02) {
            Write-Host "[art-pack] WARN: preview ${pv} is not $($r.Leaf)'s aspect ($($hdr.Width)x$($hdr.Height)) - skipped (a stretched preview teaches the wrong thing)" -ForegroundColor Yellow
            continue
        }
        $out = Join-Path $PvDir ($r.Leaf -replace '\.png$', "_$pv.png")
        New-Preview $r.Path $out $W $H
        $made++
    }
    Write-Host "[art-pack] preview_onscreen_$pv/  $made file(s)"
    if ($made -gt 0) {
        $readme += "`n``../preview_onscreen_$pv/`` holds these downscaled to their real on-screen size ($pv) - what the player actually sees.`n"
    }
}
Write-Utf8NoBom (Join-Path $RefDir "README.md") $readme

# --- zip ------------------------------------------------------------------------
$ZipPath = Join-Path $Downloads ("tod_" + $name + "_art_pack.zip")
if ($NoZip) {
    Write-Host "[art-pack] -NoZip: staged at $PackDir"
    return
}
Compress-Archive -Path $PackDir -DestinationPath $ZipPath -CompressionLevel Optimal -Force
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
Write-Host ""
Write-Host "[art-pack] PACK -> $ZipPath  ($((Get-Item $ZipPath).Length) bytes)"
foreach ($e in ($z.Entries | Sort-Object FullName)) {
    Write-Host ("    {0,8}  {1}" -f $e.Length, $e.FullName)
}
$z.Dispose()
Write-Host ""
Write-Host "[art-pack] hand the zip to the generator; INSTRUCTIONS.md at the top of it is the whole task."
Write-Host "[art-pack] the drop comes back as ~/Downloads/files (N).zip -> .\tools\make_art_pack.ps1 -Inspect 'files (N).zip'"
