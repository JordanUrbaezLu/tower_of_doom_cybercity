# =============================================================================
# build_map.ps1 - ONE-COMMAND headless build of zm_tower_of_doom.
# Ported from abandoned_cyber_city_zombies (proven pipeline; same gotchas).
#
#   .\tools\build_map.ps1            FULL geometry build (any .map / brush /
#                                    entity / material / sky change):
#                                    sync -> cod2map64 (BSP+navmesh, cwd=bin)
#                                    -> Radiant LED -> linker -> verify .ff
#   .\tools\build_map.ps1 -GscOnly   FAST path for GSC/CSC/.zone-only changes:
#                                    sync -> linker (reuses the last BSP).
#   .\tools\build_map.ps1 -Run       build, then launch run_game.ps1 on success.
#
# Other switches: -SkipSync, -SkipLED (RED FLAG - hides a broken bake),
# -DryRun, -ModToolsRoot <path>.
#
# Exit 0 = a fresh .ff was written (THE success oracle - the linker exit code
# lies: it prints ERROR: for waived/substituted assets yet still packs a valid
# .ff). Exit 1 = a stage failed.
# =============================================================================

[CmdletBinding()]
param(
    # Publish builds: also link every non-English language fastfile (fr_/ge_/...).
    # Without these, NON-ENGLISH game clients fail AT MAP LOAD with
    # "Could not find zone '<xx>_zm_tower_of_doom'" (live Workshop report
    # 2026-08-26, French player). ~1 min per language, opt-in.
    [switch]$AllLanguages,
    [string]$ModToolsRoot = '',
    [switch]$GscOnly,
    [switch]$SkipSync,
    [switch]$SkipLED,
    [switch]$Run,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$MapName  = 'zm_tower_of_doom'
$RepoRoot = Split-Path $PSScriptRoot -Parent

# Known NON-FATAL linker 'ERROR:' substrings (missing-but-substituted assets).
# Empty for now - grow it only for user-waived, verified-cosmetic errors.
# Known NON-FATAL linker 'ERROR:' substrings — the linker substitutes a default
# and still packs a valid .ff. All six are BYTE-IDENTICAL to map 1's shipped
# errorlog (its Panzer/zod boss packs; map 1 played fine with them):
#   - the electroball 115-grenade's 4 unbundled materials (cosmetic substitution)
#   - mechz.zpkg (map 1 CHANGELOG: "cosmetic")
#   - p7_zm_zod_fuse (unbuildable + unused fuse-quest prop model)
$WaivedLinkerErrors = @(
    'mtl_p7_zm_ctl_115_grenade_glass'
    'mtl_p7_zm_ctl_blob_115_bubbles'
    'mtl_p7_zm_ctl_115_grenade_metal_brass'
    't7_zm_bgb_metal_brass_old'
    "Could not open 'zone_source/mechz.zpkg'"
    "xmodel 'p7_zm_zod_fuse' is missing"
    # v9.37 breather teleporters (_tod_teleport.gsc): the kino arrival FX
    # (dlc5/theater/fx_teleport_flashback_kino) spawns a BEAM whose material
    # exists only as a beam reference in stock t7_beams.gdt — no material GDT
    # anywhere, so the linker logs it and substitutes. The beam RENDERS in
    # game (user-verified 2026-08-23: "Seems good, the teleporters").
    'gfx_teleport_tube_em_scroll_nocull'
    # Gift of Death pack's bundled window-glass-shard debris props — their
    # native material isn't in the modtools gdtDB (stock material, substitutes
    # at runtime). Cosmetic; the .ff builds. (skinOverride black_glass blanked)
    'mtl_glass was not found'
    # STORMBREAKER (the Leviathan Axe port, 2026-08-22): its sharedweaponsounds
    # "fireaxe" chain references the STOCK surfacesounddef assets
    # knife_melee_surface / knife_melee_surface_plr, which are not in the
    # modtools gdtDB. Map 1 shipped the same axe with the identical two lines
    # (its CHANGELOG attributes them to leviathan_zm); surface-impact sound
    # defs only — the weapon links and plays. Cosmetic.
    'knife_melee_surface'
)

function Info($m) { Write-Host "[build] $m" -ForegroundColor Cyan }
function Step($m) { Write-Host ""; Write-Host "[build] === $m ===" -ForegroundColor White }
function Warn($m) { Write-Host "[build] WARN: $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host ""; Write-Host "[build] FAIL: $m" -ForegroundColor Red; exit 1 }

function Resolve-ToolsRoot([string]$override) {
    if ($override -ne '') { return $override }
    $libRoots = @(
        "C:\Program Files (x86)\Steam\steamapps\common",
        "D:\Steam\steamapps\common",
        "E:\Steam\steamapps\common",
        "C:\Steam\steamapps\common"
    )
    foreach ($lib in $libRoots) {
        if (-not (Test-Path $lib)) { continue }
        $dirs = Get-ChildItem $lib -Directory -Filter "Call of Duty Black Ops III*" -ErrorAction SilentlyContinue
        foreach ($d in $dirs) {
            if (Test-Path (Join-Path $d.FullName "bin\modlauncher.exe")) { return $d.FullName }
        }
    }
    throw "Could not auto-detect the Mod Tools root (no folder with bin\modlauncher.exe)."
}

# GAME-RUNNING GUARD (2026-08-18 crash incident, map 1 precedent): the game
# file-locks the .sabs sound bank while running — a build regenerating the
# banks against the locked/stale cache emits CORRUPT banks -> silent
# 0xC0000005 mid-DB-load at the NEXT launch (no log error, just a minidump).
# CROSS-SESSION LINKER LOCK (2026-08-21): two Claude sessions built this map
# at once; the later linker overwrote the earlier clean output with banks it
# generated while the game held the alias file -> black-screen hang. One
# linker per usermap, ever. If another linker_modtools.exe is alive, it is
# either a concurrent build or a zombie from a collided one — both are
# reasons to STOP, not race. Never remove this.
$otherLinker = Get-Process linker_modtools -ErrorAction SilentlyContinue
if ($otherLinker) {
    Die "another linker_modtools.exe is RUNNING (pid $($otherLinker.Id)) - a concurrent or zombie build. Wait for it (or kill it if it is a leftover), then build. Two linkers on one usermap corrupt the sound banks."
}

# Never build while BlackOps3 is up. (run_game.ps1 has the inverse guard.)
$gameProc = Get-Process BlackOps3 -ErrorAction SilentlyContinue
if ($gameProc) {
    Die "BlackOps3 is RUNNING (pid $($gameProc.Id)) - a build now would corrupt the sound banks (locked .sabs). Close the game, then build."
}

# GAME WATCHDOG (2026-08-24, user: "make sure to never start a build if im in
# game. Should be something as part of the process that we keep missing").
# The check above covers the START; the end-of-linker sample covers the END.
# The blind spot both nights was the MIDDLE: a session that starts AND ends
# inside the ~4-minute build window trips neither, and that overlap is the top
# suspect for the intermittent wav-converter faults. This job polls every 2s
# for the whole build and drops a flag file the instant BlackOps3 appears; the
# end guard treats that flag exactly like catching the game live. The job is a
# child of THIS PowerShell session, so it dies with the script — it can never
# outlive the build (the 2026-08-21 orphaned-watcher lesson does not apply).
$GameSeenFlag = Join-Path $env:TEMP ("tod_build_gameseen_{0}.flag" -f $PID)
if (Test-Path $GameSeenFlag) { Remove-Item $GameSeenFlag -Force }
$GameWatchJob = Start-Job -ArgumentList $GameSeenFlag -ScriptBlock {
    param($flag)
    while ($true) {
        if (Get-Process BlackOps3 -ErrorAction SilentlyContinue) {
            Set-Content -Path $flag -Value (Get-Date -Format o)
        }
        Start-Sleep -Seconds 2
    }
}

# --- resolve tools root + exe paths ----------------------------------------
try { $Tools = Resolve-ToolsRoot $ModToolsRoot } catch { Die $_.Exception.Message }
$Bin     = Join-Path $Tools 'bin'
$Cod2    = Join-Path $Bin 'cod2map64.exe'
$Radiant = Join-Path $Bin 'Radiant_modtools.exe'
$Linker  = Join-Path $Bin 'linker_modtools.exe'
$MapSrc  = Join-Path $Tools ("map_source\zm\{0}.map"        -f $MapName)
$Bsp     = Join-Path $Tools ("share\raw\maps\zm\{0}.d3dbsp" -f $MapName)
$NavHkt  = Join-Path $Tools ("share\raw\maps\zm\{0}_navmesh.hkt" -f $MapName)
$FfDir   = Join-Path $Tools ("usermaps\{0}\zone" -f $MapName)
$RepoMap = Join-Path $RepoRoot ("map_source\zm\{0}.map" -f $MapName)

Info "mod tools root = $Tools"
Info ("mode = {0}{1}" -f $(if ($GscOnly) { 'GSC-ONLY (linker only)' } else { 'FULL geometry (cod2map64 + LED + linker)' }), $(if ($DryRun) { '  [DRY RUN]' } else { '' }))
foreach ($e in @($Cod2, $Radiant, $Linker)) {
    if (-not (Test-Path $e)) { Die "missing compiler exe: $e" }
}

# --- native-exe runner: capture stdout/stderr to temp files ------------------
function Invoke-BuildExe($exe, [string[]]$argList, $label, $workDir) {
    Info ("{0}: {1} {2}" -f $label, (Split-Path $exe -Leaf), ($argList -join ' '))
    if ($DryRun) { Info "  DRY: not executed"; return [pscustomobject]@{ Code = 0; Out = ''; Err = '' } }
    $o  = New-TemporaryFile
    $er = New-TemporaryFile
    try {
        $p = Start-Process -FilePath $exe -ArgumentList $argList -WorkingDirectory $workDir `
                 -NoNewWindow -Wait -PassThru -RedirectStandardOutput $o.FullName -RedirectStandardError $er.FullName
        $out = Get-Content $o.FullName -Raw -ErrorAction SilentlyContinue
        $err = Get-Content $er.FullName -Raw -ErrorAction SilentlyContinue
    } finally {
        Remove-Item $o.FullName, $er.FullName -ErrorAction SilentlyContinue
    }
    return [pscustomobject]@{ Code = $p.ExitCode; Out = [string]$out; Err = [string]$err }
}

function Q($p) { '"' + $p + '"' }

# ===========================================================================
# 1. sync repo -> Mod Tools (linker builds the DEPLOYED copy - skipping this
#    silently builds STALE code; cost map 1 hours)
# ===========================================================================
if (-not $SkipSync) {
    Step "sync repo -> Mod Tools"
    if ($DryRun) {
        & (Join-Path $PSScriptRoot 'sync_to_modtools.ps1') -ModToolsRoot $Tools -DryRun
    } else {
        & (Join-Path $PSScriptRoot 'sync_to_modtools.ps1') -ModToolsRoot $Tools
        if ((Test-Path $RepoMap) -and (Test-Path $MapSrc)) {
            $rh = (Get-FileHash $RepoMap).Hash
            $dh = (Get-FileHash $MapSrc).Hash
            if ($rh -eq $dh) { Info "deployed .map hash matches repo (sync OK)" }
            else { Die "deployed map_source .map does NOT match repo after sync - aborting before a stale build" }
        }
    }
} else {
    Warn "-SkipSync: building whatever is already deployed"
}

# ===========================================================================
# 1b. gdtdb /update - refresh the asset DB when the repo ships GDTs. The
#     linker does NOT do this itself; a stale DB errors "unable to locate
#     asset in gdtdb for '<asset>'" (map 1's deploy_perk_shaders lesson).
# ===========================================================================
if (-not $DryRun -and (Test-Path (Join-Path $RepoRoot 'source_data'))) {
    Step "gdtdb /update (repo GDTs present)"
    $GdtDb = Join-Path $Tools 'gdtdb\gdtdb.exe'
    if (Test-Path $GdtDb) {
        $r = Invoke-BuildExe $GdtDb @('/update') 'gdtdb' (Join-Path $Tools 'gdtdb')
        if ($r.Code -ne 0) { Warn "gdtdb /update exited $($r.Code) - new GDT assets may not link" }
        else { Info "asset DB refreshed" }
    } else {
        Warn "gdtdb.exe not found at $GdtDb - skipping DB refresh"
    }
}

# ===========================================================================
# 2. cod2map64 - BSP + navmesh (FULL builds only). MUST run with cwd = bin or
#    navmesh gen aborts while still writing the .d3dbsp (silent stale navmesh).
# ===========================================================================
# ===========================================================================
# 1a. WEAPON / PACK-A-PUNCH GATE - runs on EVERY build, GscOnly included.
#
# WHY THIS IS HERE (2026-08-25, user: "Why do we continuously keep breaking the
# game? ... It specifically happens with pap where we make a change and somehow
# guns cant be papped anymore. It seems random too").
#
# It kept happening because these two lints EXISTED and the build never ran
# them. Only the geometry lint was wired in, so every PaP regression shipped
# unless a human remembered to run `node tools/lint_tod_weapons.js` by hand -
# and the failure mode is silent in the build, silent in the linker, and only
# shows up at the PaP machine in game. That is not a run-of-bad-luck, it is a
# missing gate, and this is the gate.
#
# Both are fast (~1s) and both are HARD failures. Neither is optional on
# -GscOnly: a weapons CSV or _tod_classes.gsc edit is exactly the kind of change
# that takes the fast path.
# ===========================================================================
Step "weapon / Pack-a-Punch lint"
if (-not $DryRun) {
    $wOut = & node (Join-Path $PSScriptRoot 'lint_tod_weapons.js') 2>&1 | Out-String
    Write-Host $wOut
    if ($LASTEXITCODE -ne 0) {
        Die "weapon/PaP lint FAILED - a gun would be unpackapunchable in game. Fix the generator or the CSV; do NOT build past this."
    }
}

Step "GSC arity / resolution lint"
if (-not $DryRun) {
    $aOut = & node (Join-Path $PSScriptRoot 'lint_tod_arity.js') 2>&1 | Out-String
    Write-Host $aOut
    if ($LASTEXITCODE -ne 0) {
        Die "GSC arity lint FAILED - a call does not match its function. Fix it before building."
    }
}

if (-not $GscOnly) {
    # =======================================================================
    # 1b. GEOMETRY LINT - holes and misplaced walls, BEFORE 20 minutes of
    #     cod2map + bake are spent on a .map with a hole in it. Static
    #     worldspawn only; see the header of lint_tod_geometry.js for what it
    #     cannot see. Gates on REGRESSION against tools/lint_tod_geometry.baseline.json,
    #     which currently stands at zero of everything.
    # =======================================================================
    Step "geometry lint (holes / misplaced walls)"
    if (-not $DryRun) {
        $lintOut = & node (Join-Path $PSScriptRoot 'lint_tod_geometry.js') 2>&1 | Out-String
        Write-Host $lintOut
        if ($LASTEXITCODE -ne 0) {
            Die "geometry lint FAILED - the .map has a new hole, a new invisible wall, or the road is severed. Fix the generator, not the baseline."
        }
    }

    Step "cod2map64 (BSP + navmesh + navvolume)  [cwd = bin]"
    $bspDir = Split-Path $Bsp -Parent
    if (-not (Test-Path $bspDir) -and -not $DryRun) { New-Item -ItemType Directory -Path $bspDir -Force | Out-Null }

    $cod2Args = @('-platform', 'pc', '-navmesh', '-navvolume', '-loadFrom', (Q $MapSrc), (Q $Bsp))
    $r = Invoke-BuildExe $Cod2 $cod2Args 'cod2map64' $Bin

    if (-not $DryRun) {
        if ($r.Out -match 'Unable to load navigation mesh generation settings' -or $r.Err -match 'Unable to load navigation mesh generation settings') {
            Write-Host $r.Out
            Die "cod2map64 could not load navmesh settings (cwd was not bin?) - navmesh is STALE; refusing to continue"
        }
        if ($r.Code -ne 0) { Write-Host $r.Out; Write-Host $r.Err; Die "cod2map64 exited $($r.Code)" }
        if (-not (Test-Path $Bsp)) { Die "cod2map64 produced no .d3dbsp at $Bsp" }
        Info ("BSP written: {0:N1} MB @ {1}" -f ((Get-Item $Bsp).Length / 1MB), (Get-Item $Bsp).LastWriteTime)
        if (Test-Path $NavHkt) { Info ("navmesh.hkt updated @ {0}" -f (Get-Item $NavHkt).LastWriteTime) }
        else { Warn "no _navmesh.hkt found at $NavHkt (ground zombies may not path)" }
    }

    # =======================================================================
    # 3. Radiant LED lighting recompute - THE BAKE GATE. If it hangs on the
    #    brush.cpp:1860 modal, the geometry re-hit the lightmap-atlas ceiling:
    #    REVERT/FIX before testing (use tools\_bake_test.ps1 to bisect).
    # =======================================================================
    if (-not $SkipLED) {
        Step "Radiant LED (lighting recompute)"
        $radArgs = @('-ledSilent', '+medium', '+forceclean', '+recompute', (Q $MapSrc))
        $r = Invoke-BuildExe $Radiant $radArgs 'Radiant LED' $Bin
        if (-not $DryRun -and $r.Code -ne 0) { Write-Host $r.Out; Warn "Radiant LED exited $($r.Code) - lighting may be stale; if it CRASHED (brush.cpp:1860) a geometry change regressed the bake" }
    } else {
        Warn "-SkipLED: lighting NOT recomputed (RED FLAG - never use this to hide a broken bake)"
    }
} else {
    Warn "-GscOnly: skipping cod2map64 + LED (reusing the last BSP + navmesh). Invalid if any brush/entity/material moved."
}

# ===========================================================================
# 3b. sweep orphaned build lock-temp files (*~lk) - an interrupted build
#     leaves multi-GB orphans that would ship into the Workshop upload.
# ===========================================================================
if (-not $DryRun -and (Test-Path $FfDir)) {
    Step "sweep stale build locks (*~lk)"
    $locks = @(Get-ChildItem -Path $FfDir -Recurse -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name.EndsWith('~lk') })
    if ($locks.Count -gt 0) {
        foreach ($f in $locks) {
            try {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                Info ("  removed {0} ({1:N1} MB)" -f $f.Name, ($f.Length / 1MB))
            } catch {
                Warn ("  could NOT remove {0} - a build may be running? ({1})" -f $f.Name, $_.Exception.Message)
            }
        }
    } else {
        Info "no stale *~lk files (folder clean)"
    }
}

# ===========================================================================
# 4. linker - compile GSC + pack the .ff
# ===========================================================================
Step "linker (compile GSC + pack .ff)"
$ffBefore = $null
if (Test-Path $FfDir) { $ffBefore = Get-ChildItem $FfDir -Filter "$MapName.ff" -ErrorAction SilentlyContinue | Select-Object -First 1 }

$linkArgs = @('-language', 'english', '-modsource', $MapName)

# AUTO-RETRY THE FLAKY SOUND STEP (2026-08-24). The wav converter inside the
# linker intermittently null-refs ("Object reference not set to an instance of
# an object") on one or two RANDOM skye_ports wavs and, when it does, ABORTS
# all-language bank emission while still exiting 0. Investigated and ruled out:
# the wavs are intact (normal attributes, exclusive-read succeeds, no lock) and
# Defender was idle across the failures - so it is a concurrency fault inside
# the tool, not the data and not this machine. It clears on a re-run, so the
# build now retries the LINKER ALONE (~1 min) rather than making a human re-run
# the whole thing (~4 min). sound\zone is cleared between attempts so a retry
# cannot inherit a half-written bank. Observed failure rate is roughly 1 in 2,
# so 3 attempts is ~7/8 to succeed; a persistent failure still Dies at the
# BANK-PRESENCE GUARD below.
$maxLinkTries = 3
$SndZoneEarly = Join-Path $Tools ("usermaps\{0}\sound\zone" -f $MapName)
for ($try = 1; $try -le $maxLinkTries; $try++) {
    if ($try -gt 1) {
        Warn ("sound bank missing after linker attempt {0} - clearing sound\zone, retrying linker ({1} of {2})." -f ($try - 1), $try, $maxLinkTries)
        if (Test-Path $SndZoneEarly) { Remove-Item $SndZoneEarly -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $r = Invoke-BuildExe $Linker $linkArgs 'linker' $Bin
    if ($DryRun) { break }
    $sabsNow = @(Get-ChildItem $SndZoneEarly -Recurse -Filter "*.all.sabs" -File -ErrorAction SilentlyContinue | Sort-Object Length -Descending)
    if ($sabsNow.Count -gt 0 -and $sabsNow[0].Length -ge 50MB) {
        if ($try -gt 1) { Info ("sound bank recovered on linker attempt {0}." -f $try) }
        break
    }
}

if (-not $DryRun) {
    $allOut   = "$($r.Out)`n$($r.Err)"
    $errLines = @($allOut -split "\r?\n" |
        ForEach-Object { ($_ -replace '\^\d', '').Trim() } |
        Where-Object { $_ -match 'ERROR:' -or $_ -match 'no file for filespec' -or $_ -match 'Unresolved external' })

    # SUCCESS ORACLE = a FRESH .ff was written (see header).
    $ffAfter = $null
    if (Test-Path $FfDir) {
        $ffAfter = Get-ChildItem $FfDir -Filter "$MapName.ff" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    $freshFf = $ffAfter -and ( (-not $ffBefore) -or ($ffAfter.LastWriteTime -gt $ffBefore.LastWriteTime) )

    if (-not $freshFf) {
        if ($errLines.Count -gt 0) {
            Write-Host "[build] linker errors (aborted before packing the .ff):" -ForegroundColor Red
            $errLines | Select-Object -First 25 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        } else {
            ($allOut -split "\r?\n" | Select-Object -Last 20) | ForEach-Object { Write-Host "  $_" }
        }
        Die "linker did not produce a fresh .ff (exit $($r.Code))"
    }

    $unexpected = @($errLines | Where-Object { $l = $_; -not ($WaivedLinkerErrors | Where-Object { $l -match [regex]::Escape($_) }) })
    $waived     = @($errLines | Where-Object { $l = $_;     ($WaivedLinkerErrors | Where-Object { $l -match [regex]::Escape($_) }) })

    if ($waived.Count -gt 0) {
        Info "$($waived.Count) known-waived asset warning(s) (non-fatal, default-substituted):"
        $waived | Sort-Object -Unique | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkGray }
    }
    if ($unexpected.Count -gt 0) {
        Warn "$($unexpected.Count) UNEXPECTED linker error(s) - a .ff WAS produced, but verify (asset may be missing in-game):"
        $unexpected | Select-Object -First 25 | ForEach-Object { Write-Host "    ! $_" -ForegroundColor Yellow }
    }

    # POISONED-BUILD GUARD (2026-08-21 black-screen incident). The start-of-run
    # game check is not enough: if BlackOps3 is LAUNCHED MID-BUILD the game
    # file-locks the sound banks, the linker logs "being used by another
    # process" for the alias bank, KEEPS GOING, and still emits a .ff that
    # "links OK" - with corrupt banks that hang the next load on a black
    # screen. Worse, that linker can outlive a later clean rebuild and
    # overwrite it (the tell is the UmbraDebug 0x000000b7 rename error: two
    # linkers alive). So: any bank lock, or the game appearing during the run,
    # is a HARD FAIL with the ritual spelled out. Never remove this.
    $bankLocked = ($allOut -match 'being used by another process')
    $gameNow    = Get-Process BlackOps3 -ErrorAction SilentlyContinue
    # the watchdog's verdict: did the game appear at ANY point during the build?
    $gameSeen = $false
    if ($GameWatchJob) { Stop-Job $GameWatchJob -ErrorAction SilentlyContinue; Remove-Job $GameWatchJob -Force -ErrorAction SilentlyContinue }
    if (Test-Path $GameSeenFlag) {
        $gameSeen = $true
        $seenAt = Get-Content $GameSeenFlag -ErrorAction SilentlyContinue | Select-Object -First 1
        Remove-Item $GameSeenFlag -Force -ErrorAction SilentlyContinue
    }
    if ($bankLocked -or $gameNow -or $gameSeen) {
        if ($gameNow)    { Warn "BlackOps3 (pid $($gameNow.Id)) appeared DURING the build." }
        if ($gameSeen -and -not $gameNow) { Warn ("the watchdog saw BlackOps3 running MID-BUILD (first seen {0}) - even though it is closed now." -f $seenAt) }
        if ($bankLocked) { Warn "the linker could not write the sound alias bank (file locked by the game)." }
        Warn "This .ff is POISONED even though the linker reported success. Ritual:"
        Warn "  1) close the game   2) confirm no linker_modtools.exe is still running (tasklist)"
        Warn "  3) delete usermaps\zm_tower_of_doom\sound\zone\ entirely   4) rebuild"
        Die "sound banks were regenerated while the game was up - do NOT test this build"
    }

    # BANK-PRESENCE GUARD (2026-08-24). An intermittent wav-converter null-ref
    # ("Object reference not set to an instance of an object", 2 random wavs per
    # occurrence, source files intact on disk) can ABORT the whole all-language
    # bank emission and STILL report success: the 11:14 build said "BUILD OK",
    # wrote a fresh .ff, and left sound\zone holding only .sz stubs with NO
    # .all.sabs anywhere - the black-screen-on-boot class. "BUILD OK" is
    # therefore not enough: the bank must EXIST at plausible size. Known-good
    # .all.sabs is ~105 MB; 50 MB is a generous floor that still catches a stub
    # or a partial write. It may sit in sound\zone or under CachedBanks\all -
    # the recursive search covers both. Recovery = the ritual above (delete
    # sound\zone, confirm the game is closed, one full rebuild).
    $SndZone = Join-Path $Tools ("usermaps\{0}\sound\zone" -f $MapName)
    $allSabs = @(Get-ChildItem $SndZone -Recurse -Filter "*.all.sabs" -File -ErrorAction SilentlyContinue | Sort-Object Length -Descending)
    if ($allSabs.Count -eq 0 -or $allSabs[0].Length -lt 50MB) {
        Warn "the all-language sound bank (.all.sabs) is MISSING or truncated under sound\zone."
        Warn "The intermittent wav-converter fault aborted bank emission - the map would load with NO custom audio (music, gun sounds, VO all missing)."
        Warn ("This persisted across {0} linker attempts, so it is NOT the usual transient fault - investigate before retrying." -f $maxLinkTries)
        Die "no usable .all.sabs bank - do NOT test this build"
    }
    Info ("sound bank: {0} ({1:N1} MB)" -f $allSabs[0].Name, ($allSabs[0].Length / 1MB))

    Step "BUILD OK"
    Info ("fastfile: {0}" -f $ffAfter.FullName)
    Info ("size:     {0:N2} MB" -f ($ffAfter.Length / 1MB))
    Info ("written:  {0}" -f $ffAfter.LastWriteTime)
    Write-Host ""
    Write-Host "[build] READY TO TEST -> .\tools\run_game.ps1  (or PLAY_NORMAL.bat)" -ForegroundColor Green
}

# ===========================================================================
# 4b. optional: link the NON-ENGLISH language fastfiles  (-AllLanguages)
# ===========================================================================
# WHY (Workshop report 2026-08-26: "ERROR: Could not find zone
# 'fr_zm_tower_of_doom'"): the game loads a per-language fastfile named
# <prefix>_<map>.ff, and this script only ever linked -language english — so
# every non-English client failed at map load with exactly that error. The
# language ff is tiny (~230 KB of localized strings; our .str files are
# English-only, so other languages fall back to English text — the standard
# Workshop-map arrangement). One linker pass per language, SEQUENTIAL: the
# one-linker-at-a-time rule holds inside a single build too.
# Verification is PREFIX-AGNOSTIC on purpose — we don't hardcode fr/ge/sp
# name mappings; a pass counts as good if it wrote a fresh *_<map>.ff.
if ($AllLanguages -and -not $DryRun) {
    Step "language fastfiles (-AllLanguages)"
    $langs = @('french','german','italian','spanish','portuguese','russian','japanese','simplified_chinese','traditional_chinese')
    foreach ($lang in $langs) {
        # The mid-build game-launch hazard applies to every pass, not just the
        # English one (a launched game file-locks the banks and poisons output).
        if (Get-Process BlackOps3 -ErrorAction SilentlyContinue) {
            Die ("BlackOps3 appeared before the '{0}' language pass - close the game and re-run; do NOT ship a build the game overlapped" -f $lang)
        }
        $before = @{}
        Get-ChildItem $FfDir -Filter "*_$MapName.ff" -ErrorAction SilentlyContinue | ForEach-Object { $before[$_.Name] = $_.LastWriteTime }
        $rl = Invoke-BuildExe $Linker @('-language', $lang, '-modsource', $MapName) "linker[$lang]" $Bin
        $fresh = @(Get-ChildItem $FfDir -Filter "*_$MapName.ff" -ErrorAction SilentlyContinue | Where-Object {
            (-not $before.ContainsKey($_.Name)) -or ($_.LastWriteTime -gt $before[$_.Name]) })
        if ($fresh.Count -gt 0) {
            Info ("{0}: {1}" -f $lang, (($fresh | ForEach-Object { "{0} ({1:N0} KB)" -f $_.Name, ($_.Length/1KB) }) -join ', '))
        } else {
            Warn ("{0}: NO fresh language ff (exit {1}) - clients in this language still cannot load the map (unsupported -language token?)" -f $lang, $rl.Code)
        }
    }
    # The extra passes re-enter the shared sound pipeline, and the flaky wav
    # converter (see the retry note above section 4) can strand a stub bank on
    # any of them while still exiting 0 - re-assert the bank guard so a late
    # pass cannot silently undo a build the English pass already verified.
    $allSabsL = @(Get-ChildItem $SndZone -Recurse -Filter "*.all.sabs" -File -ErrorAction SilentlyContinue | Sort-Object Length -Descending)
    if ($allSabsL.Count -eq 0 -or $allSabsL[0].Length -lt 50MB) {
        Die "the .all.sabs bank is MISSING/truncated after the language passes - do NOT ship; delete sound\zone and rebuild"
    }
    Info ("sound bank still healthy after language passes: {0} ({1:N1} MB)" -f $allSabsL[0].Name, ($allSabsL[0].Length / 1MB))
}

# ===========================================================================
# 5. optional launch
# ===========================================================================
if ($Run -and -not $DryRun) {
    Step "launching game (run_game.ps1)"
    & (Join-Path $PSScriptRoot 'run_game.ps1')
}

exit 0
