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
#   .\tools\build_map.ps1 -CleanPak  FULL build that also rewrites zone\*.xpak
#                                    from scratch (the linker only ever appends
#                                    to it; -Publish implies this, -KeepPak
#                                    opts out; node tools/xpak_report.js proves it).
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
    # PUBLISH GATE (repo review 2026-09-01): refuses an armed level.tod_dev /
    # level.tod_god, refuses -GscOnly, implies -AllLanguages, and refuses
    # backup files parked in the deployed zone\. See section 0b below.
    [switch]$Publish,
    # PATCH-NOTES GATE (user 2026-09-02: "when I ask for a full build for
    # publish prep we need to generate patch notes as well"): -Publish refuses
    # to build until tools/patch_notes.js check passes (a staged ledger row
    # whose cutoff is the top CHANGELOG entry, and docs/68 + the BBCode file
    # lead with that version's section). Emergency bypass only:
    [switch]$SkipNotesGate,
    # CLEAN PACK (2026-09-03, docs/86): the linker only APPENDS to
    # zone\<map>.xpak - every full build leaves the previous build's
    # reflection probes / probe volumes / sun-shadow tree behind and every
    # replaced asset leaves a hole, so the pack the Workshop ships grew to
    # 9.5 GB with ~5.3 GB of build history in it (47 shadow trees under one
    # name). -CleanPak moves ALL map/language packs OUT of zone\ before the
    # link, implies -AllLanguages, and retains previous fastfiles/sound banks
    # until every language passes. Failure restores the complete old set.
    # FULL build only. -Publish implies it;
    # -KeepPak opts a publish out. Prove it: node tools/xpak_report.js
    [switch]$CleanPak,
    [switch]$KeepPak,
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
    # THE THREE reflex_* ERRORS: CLOSED 2026-08-28 — FIXED, NEVER WAIVED,
    # and the answer to the recorded in-game exit condition was NOT BENIGN.
    # The user's play report ("the UDM has a weird sight. Like a sight that
    # you cant even see through") was the exit condition firing negative:
    # reflex_reddot_lens_ads is literally the ADS lens material, and missing
    # meant an OPAQUE optic on the PaP'd SLASHER tier-2 sidearm. Resolution
    # (parallel cybercity session, same day): the port was incomplete —
    # skinOverride SOURCES need not exist, TARGETS and un-remapped slots
    # must, and the porter had remapped exactly one mesh's slots. Every
    # reflex_* slot on all four UDM meshes now remaps to materials the UDM's
    # own GDT declares (lens -> weapon_udm45_glass etc.); edit lives in the
    # TOOLS-ROOT-ONLY source_data\skye_iw7_udm.gdt (backup .tod-reflex-orig;
    # root-only GDTs SURVIVE builds — our sync copies, never mirrors).
    # Verified: the 20:22 build logged ZERO reflex errors.
    # DO NOT ADD THE THREE NAMES TO THE WAIVE LIST — if a reflex_* error
    # ever reappears here it means the root GDT fix was lost (a pack
    # reinstall, a new machine), and the UNEXPECTED lane below flagging it
    # is exactly the alarm we want. Portable lesson for any ported gun
    # throwing "material not found in gdtDB": check the skinOverride
    # source/target asymmetry before waiving or dropping the gun.
    # (History: briefly waived 2026-08-28 on root-cause evidence alone;
    # reverted the same hour — the bar was seeing it render, and holding
    # that bar is what caught a real defect. A cross-map "fires with zero
    # UDM assets" scare was RETRACTED: it paired remembered console output
    # with a later run's assetlist. Pair build symptoms only with artifacts
    # from the SAME run. The HK21 was a red herring — only its unused
    # reflex variant is packed.)
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
function Die($m)  {
    if ($script:TodPakTransaction) { Undo-TodCleanPaks $script:TodPakTransaction }
    Write-Host ""; Write-Host "[build] FAIL: $m" -ForegroundColor Red; exit 1
}
. (Join-Path $PSScriptRoot 'clean_paks.ps1')
$script:TodPakTransaction = $null
trap {
    if ($script:TodPakTransaction) { Undo-TodCleanPaks $script:TodPakTransaction }
    throw
}

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

# THE OTHER TWO BUILD STAGES (2026-09-01). The linker check above is necessary
# and was NOT sufficient: it only covers the PACK stage. A full build spends most
# of its wall time in cod2map64 (BSP) and Radiant_modtools (LED bake), and during
# those stages NO linker_modtools exists — so this script would happily start,
# and the very first thing it does is SYNC THE SOURCE TREE. That means a second
# build launched during someone else's bake rewrites the inputs underneath it and
# then links against a half-written BSP.
#
# That failure is WORSE than the two-linker one this guard was built for, because
# it is not obviously broken: it produces a .ff that is internally inconsistent,
# and the sanctioned freshness diff CANNOT catch it — that diff compares SOURCE
# trees and knows nothing about the compiled BSP.
#
# Live near-miss 2026-09-01: a -GscOnly was about to start while Radiant_modtools
# (pid 35416) was 66 seconds into a peer session's LED bake, with ~3.6 cores
# pegged. Nothing in this script would have stopped it; it was caught by a human
# -- well, by an agent -- looking at the process list by hand.
$otherBake = Get-Process Radiant_modtools,cod2map64 -ErrorAction SilentlyContinue
if ($otherBake) {
    $names = ($otherBake | ForEach-Object { "$($_.Name) (pid $($_.Id))" }) -join ', '
    Die "a build STAGE is already running: $names - that is someone else's cod2map/LED bake. This script SYNCS THE SOURCE TREE as its first step, so starting now would rewrite that build's inputs mid-flight and link against a half-written BSP. Wait for it to finish, then build."
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

# ===========================================================================
# 0b. PUBLISH GATE (-Publish; repo review 2026-09-01). CLAUDE.md: "A PUBLISH IS
#     NEVER A RELABEL OF AN ARMED ARTIFACT: flags false, then a fresh FULL
#     build, then publish." The two flags have cycled armed/disarmed at least
#     five times by their own comment history, and three sessions share this
#     repo, so the rule is now a gate rather than a memory:
#       * level.tod_dev / level.tod_god armed -> WARN on every build,
#         FAIL with -Publish (the assignment lines are the truth, not comments)
#       * -Publish refuses -GscOnly (a publish is a fresh FULL build)
#       * -Publish implies -AllLanguages (non-English clients need their ff;
#         the deploy tree carried five-day-old language ffs on 2026-09-01)
#       * -Publish refuses *.orig / *.bak* files parked in the deployed zone\
#         (they upload with the item)
# ===========================================================================
# devw* NOT dev (2026-09-07): level.tod_dev_money was added as a SEPARATE
# flag so "unlimited money" stops implying upgrades-every-round and a Panzer
# from round 3 -- and the old pattern did not match it, because `tod_dev` is
# followed by `_money`, not by `=`. A dev flag this gate cannot see is a dev
# flag that ships. Any future tod_dev<anything> is caught now.
$EntryGsc   = Join-Path $RepoRoot 'scripts\zm\zm_tower_of_doom.gsc'
$armedFlags = @()
if (Test-Path $EntryGsc) {
    $armedFlags = @(Select-String -Path $EntryGsc -Pattern '^\s*level\.tod_(dev\w*|god)\s*=\s*true\s*;' |
                    ForEach-Object { $_.Line.Trim() })
}
if ($armedFlags.Count -gt 0) {
    if ($Publish) {
        Die ("PUBLISH GATE: dev/test flags are ARMED in {0}: {1}  -> set both to false, rebuild FULL, then publish" -f $EntryGsc, ($armedFlags -join ' | '))
    }
    Warn ("dev/test flags ARMED ({0}) - fine for a test build; NEVER publish this .ff" -f ($armedFlags -join ' | '))
}

# THE LUA MOCK FLAG (v17.3). TOD_MOCK_PARTY in AetheriumHud.lua replaces the
# three party rows with fakes so the co-op HUD can be seen solo. Lua has no
# level.tod_dev, so it CANNOT be dev-gated in the file itself - and while armed
# it MASKS REAL TEAMMATES in co-op. Map 1 carried the identical flag with a
# comment saying to manage it by hand; this is that comment turned into a gate.
$HudLua = Join-Path $RepoRoot 'ui\uieditor\menus\hud\AetheriumHud.lua'
if (Test-Path $HudLua) {
    $armedMock = @(Select-String -Path $HudLua -Pattern '^\s*local\s+TOD_MOCK_PARTY\s*=\s*true\b' |
                   ForEach-Object { $_.Line.Trim() })
    if ($armedMock.Count -gt 0) {
        if ($Publish) {
            Die ("PUBLISH GATE: TOD_MOCK_PARTY is ARMED in {0}: {1}  -> set it to false, rebuild FULL, then publish (armed, it hides real teammates)" -f $HudLua, ($armedMock -join ' | '))
        }
        Warn ("TOD_MOCK_PARTY ARMED - fake party rows are ON and REAL teammates are hidden; fine solo, NEVER publish this .ff")
    }
}

# THE LUA HUD PROBE (v17.21). TOD_HUD_DEBUG in AetheriumLoadout.lua appends the
# resolved weapon CATEGORY to the weapon-name band ("MAC-10 SMG" / "MAC-10 NIL")
# so a single play session can say which link of the gun-icon chain is broken.
# Same reasoning as TOD_MOCK_PARTY above: Lua cannot read level.tod_dev, so the
# file cannot gate itself, and armed it puts debug text on a player's HUD.
$LoadoutLua = Join-Path $RepoRoot 'ui\uieditor\widgets\HUD\AetheriumWidgets\AetheriumLoadout.lua'
if (Test-Path $LoadoutLua) {
    $armedProbe = @(Select-String -Path $LoadoutLua -Pattern '^\s*local\s+TOD_HUD_DEBUG\s*=\s*true\b' |
                    ForEach-Object { $_.Line.Trim() })
    if ($armedProbe.Count -gt 0) {
        if ($Publish) {
            Die ("PUBLISH GATE: TOD_HUD_DEBUG is ARMED in {0}: {1}  -> set it to false, rebuild, then publish (armed, it prints the weapon category on the HUD)" -f $LoadoutLua, ($armedProbe -join ' | '))
        }
        Warn ("TOD_HUD_DEBUG ARMED - the weapon name band reads '<NAME> <CATEGORY>'; fine for a test build, NEVER publish this .ff")
    }
}

# THE MAGE GATE (2026-09-07, docs/114). The fifth class SHIPS as of 2026-09-09;
# what survives here is the CONSISTENCY half, which outlives the launch.
#
# USER REQUIREMENT, 2026-09-07: *"make sure that all the changes you're making
# are behind a singular flag that is false right now ... we don't want those to
# intersect at all."* That requirement is met and spent — the flag is 1 now, and
# the publish-refusal that enforced the "not yet" half is gone (see the bottom
# of this block). The flag stays because the two-language drift it prevents is
# permanent, not because the class is still provisional.
#
# IT IS ONE FLAG PER LANGUAGE, AND TWO IS THE FLOOR - not a compromise anyone
# chose. TOD_MAGE_ENABLED in scripts\zm\zm_tower_of_doom\_tod_mage.gsh is the
# flag for ALL GSC (TOD_CLS_COUNT is DERIVED from it, not a second literal).
# MAGE_ENABLED in ui\uieditor\menus\hud\tod_class_select.lua exists ONLY
# because Lua cannot read a GSC define and the draft card geometry is computed
# at file-parse time, before any shared Lua module has loaded (zone order:
# tod_class_select.lua 375, TodKeycap.lua 380). This assertion is what stops
# the two drifting, and every disagreement is otherwise SILENT: GSC on / Lua
# off draws four cards over a five-class draft and the mage is unpickable with
# no error anywhere; GSC off / Lua on draws a fifth card the server refuses.
#
# Two earlier flags (MAGE_ART in tod_upgrade.lua, TOD_MAGE_ART in
# AetheriumLoadout.lua) were DELETED the same day rather than asserted here.
# Each gated art registration that cannot be switched on until the images are
# baked and zoned, so both bought nothing and cost two more literals.
#
# EVERY DISAGREEMENT IS SILENT. GSC on / Lua off draws four cards over a
# five-class draft and the mage is unpickable with no error anywhere. GSC off /
# Lua on draws a fifth card the server will never accept. Flag on with COUNT 4
# is the same unpickable failure from the other side. Hard Die: there is no
# state in which the three should differ.
$MageGsh = Join-Path $RepoRoot 'scripts\zm\zm_tower_of_doom\_tod_mage.gsh'
$MageLua = Join-Path $RepoRoot 'ui\uieditor\menus\hud\tod_class_select.lua'
if ((Test-Path $MageGsh) -and (Test-Path $MageLua)) {
    $gscOn = @(Select-String -Path $MageGsh -Pattern '^\s*#define\s+TOD_MAGE_ENABLED\s+1\b').Count -gt 0
    $luaOn = @(Select-String -Path $MageLua -Pattern '^\s*local\s+MAGE_ENABLED\s*=\s*true\b').Count -gt 0
    if ($gscOn -ne $luaOn) {
        Die ("MAGE GATE MISMATCH: TOD_MAGE_ENABLED={0} in {1} but MAGE_ENABLED={2} in {3} -> set both the same, then rebuild" -f $gscOn, $MageGsh, $luaOn, $MageLua)
    }
    # TOD_CLS_COUNT is DERIVED now - assert it STAYED derived. A future edit
    # that helpfully "unrolls" it back to a literal 4 silently reintroduces
    # the exact drift this gate was built to catch.
    if (-not (Select-String -Path $MageGsh -Pattern '#define\s+TOD_CLS_COUNT\s+\(\s*4\s*\+\s*TOD_MAGE_ENABLED\s*\)' -Quiet)) {
        Die ("MAGE GATE: TOD_CLS_COUNT in {0} is no longer derived from TOD_MAGE_ENABLED -> restore `#define TOD_CLS_COUNT ( 4 + TOD_MAGE_ENABLED )` so the GSC side keeps exactly one flag" -f $MageGsh)
    }
    # NO THIRD LITERAL MAY APPEAR. The two deleted art flags are the precedent:
    # a new MAGE_* Lua local is how this creeps back to five.
    $strayFlag = @(Get-ChildItem (Join-Path $RepoRoot 'ui') -Recurse -Filter *.lua -ErrorAction SilentlyContinue |
                   Where-Object { $_.FullName -notmatch 'tod_class_select\.lua$' } |
                   Select-String -Pattern '^\s*local\s+(MAGE_\w+|TOD_MAGE\w*|MAGE)\s*=' )
    if ($strayFlag.Count -gt 0) {
        $where = ($strayFlag | ForEach-Object { "{0}:{1}" -f (Split-Path $_.Path -Leaf), $_.LineNumber }) -join ', '
        Die ("MAGE GATE: a second Lua mage flag appeared ({0}). The mage is ONE flag per language - TOD_MAGE_ENABLED for GSC, MAGE_ENABLED in tod_class_select.lua for Lua. Gate the new code on one of those, or delete it (docs/114 section D)" -f $where)
    }
    # THE PUBLISH BLOCK IS RETIRED (2026-09-09). It Died on -Publish while the
    # flag was 1 and told the operator to switch the class off, which was right
    # for every day the mage was unfinished and became the one thing standing
    # between this repo and shipping it. The three assertions ABOVE are what
    # actually earn their keep and they stay: GSC and Lua agreeing, TOD_CLS_COUNT
    # staying derived, and no second Lua flag appearing.
    #
    # No Warn either. A warning that fires on every build from here on is a
    # warning nobody reads, and the next real one gets skimmed past with it.
}

if ($Publish) {
    if ($GscOnly) { Die "PUBLISH GATE: -Publish needs a FULL build (drop -GscOnly)" }
    if (-not $AllLanguages) { $AllLanguages = $true; Info "-Publish: language fastfiles enabled (-AllLanguages)" }
    if ($KeepPak) { Warn "-KeepPak: this publish will upload the pack WITH its build history (node tools/xpak_report.js shows how much)" }
    elseif (-not $CleanPak) { $CleanPak = $true; Info "-Publish: clean pack enabled (-CleanPak; -KeepPak to opt out)" }
    $stray = @(Get-ChildItem $FfDir -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match 'tod-preart-orig$|\.orig$|\.bak(-|$)' })
    if ($stray.Count -gt 0) {
        Die ("PUBLISH GATE: backup files in the deployed zone\ would upload with the item: {0}" -f (($stray | ForEach-Object { $_.Name }) -join ', '))
    }
    Info "PUBLISH GATE: flags disarmed, full build, language ffs on, zone\ clean"
    # PATCH-NOTES GATE — see the -SkipNotesGate comment in param(). The flow:
    #   node tools/patch_notes.js window   (what changed since the last upload)
    #   write the section in docs/68_patch_notes.md + docs/68_patch_notes_steam_bbcode.txt
    #   node tools/patch_notes.js stage --version vX.Y
    #   .\tools\build_map.ps1 -Publish     (this gate; 'built' stamps the .ff time below)
    #   upload, then: node tools/patch_notes.js uploaded
    if ($SkipNotesGate) {
        Warn "PATCH-NOTES GATE SKIPPED (-SkipNotesGate) - this upload will go out without notes again"
    } else {
        $pn = Join-Path $PSScriptRoot 'patch_notes.js'
        & node $pn check
        if ($LASTEXITCODE -ne 0) { Die "PATCH-NOTES GATE: no patch notes staged for this publish (see the message above; -SkipNotesGate to bypass in an emergency)" }
    }
}

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
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot 'verify_weapon_costs.js')
    if ($LASTEXITCODE -ne 0) { Die 'Weapon-cost table budget failed; client startup would be at risk.' }
    # 2026-10-04: the slasher T1 AMP63 is a MAP-OWNED copy (source_data/tod_amp63.gdt,
    # reload x1.3) of the install-side skye_t9_amp63.gdt Tower II shares. The source is
    # sha-pinned; the repo copy must equal a fresh generation.
    & node (Join-Path $PSScriptRoot 'gen_tod_amp63.js') --check
    if ($LASTEXITCODE -ne 0) { Die 'Map-owned AMP63 (source_data/tod_amp63.gdt) is stale or its shared source changed - see tools/gen_tod_amp63.js.' }
}
if (-not $DryRun -and (Test-Path (Join-Path $RepoRoot 'docs\staff_approved_manifest.json'))) {
    & python (Join-Path $PSScriptRoot 'verify_staff_animations.py')
    if ($LASTEXITCODE -ne 0) { Die 'Staff animation assets/slots/timing validation failed.' }
    # docs/161: third-person staff pose = Treyarch's armminigun clips from zm_common.
    & python (Join-Path $PSScriptRoot 'verify_staff_3p.py')
    if ($LASTEXITCODE -ne 0) { Die 'Staff third-person pose/mount validation failed.' }
    # docs/167 item 4: the third-person staff models keep ONE full-detail LOD
    # (generated LODs decimated the thin shaft away at range - "floating pieces").
    & python (Join-Path $PSScriptRoot 'staff_world_lods.py') --check
    if ($LASTEXITCODE -ne 0) { Die 'Third-person staff models regained generated LODs.' }
    & node (Join-Path $PSScriptRoot 'test_dev_mage.js')
    if ($LASTEXITCODE -ne 0) { Die 'Dev Mage preview lifecycle validation failed.' }
    & node (Join-Path $PSScriptRoot 'test_dev_maxed.js')
    if ($LASTEXITCODE -ne 0) { Die 'Dev selected-class max-upgrade validation failed.' }
}
# docs/172 (2026-10-04): THE LEVEL PIPS. Every upgrade card's live level row sits
# where the card art's baked dot row was; tools/card_pips painted that row out of
# every zoned regular / super / ultimate / tier card. A new card drop arrives WITH
# baked dots (two rows in game) and --check fails on it by name. It also pins the
# ten sprites to the generator, their GDT blocks + generated zone block, and the
# Lua's PIP_* geometry to the tool's. Every build, -GscOnly included.
if (-not $DryRun) {
    Step "card level pips (sprites, no baked dots under the live row, lockstep)"
    & python (Join-Path $PSScriptRoot 'card_pips\build_card_pips.py') --check
    if ($LASTEXITCODE -ne 0) { Die 'Card level pips check failed - a card still carries baked dots, a sprite drifted, or the Lua PIP_* geometry moved. Run python tools/card_pips/build_card_pips.py --install (docs/172).' }
    # v19.76: the Warden King's boss bar art (the PNGs are the tool's own output, and
    # tod_upgrade.lua's KB_* layout matches the art) and the thinned rising-dirt FX
    # (the three copies match their recipes and their pinned stock donors).
    Step "boss bar art + thinned riser FX (v19.76)"
    & python (Join-Path $PSScriptRoot 'boss_bar\build_boss_bar.py') --check
    if ($LASTEXITCODE -ne 0) { Die 'Boss bar check failed - re-run python tools/boss_bar/build_boss_bar.py, or the Lua KB_* layout moved.' }
    & python (Join-Path $PSScriptRoot 'gen_tod_riser_fx.py') --check
    if ($LASTEXITCODE -ne 0) { Die 'Riser FX check failed - re-run python tools/gen_tod_riser_fx.py.' }
}
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

# Re-copying an old source must not silently undo the reviewed size pass.
$sizeState = Join-Path $Tools '_tod_size_originals\20260910\state.json'
if (-not $DryRun -and (Test-Path $sizeState)) {
    $sizeApplied = (Get-Content -LiteralPath $sizeState -Raw | ConvertFrom-Json).applied
    if ($sizeApplied) {
        Step 'optimized asset source verification'
        & python (Join-Path $PSScriptRoot 'optimize_tod_assets.py') --root $Tools --verify
        if ($LASTEXITCODE -ne 0) { Die 'Optimized asset sources changed or were overwritten by sync. Review the size manifest before rebuilding.' }
    }
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

Step "baseball bat balance / death presentation test"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_baseball_bat.js")
    if ($LASTEXITCODE -ne 0) { Die "Baseball bat validation failed." }
}

Step "perk machine purchase / shot / asset validation"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_perk_anims.js")
    if ($LASTEXITCODE -ne 0) { Die "Perk machine state/shot validation failed." }
    & python (Join-Path $PSScriptRoot "verify_perk_machine_presentation.py")
    if ($LASTEXITCODE -ne 0) { Die "Perk machine animation/FX/audio validation failed." }
}

Step "tower gauge boss pips (one per floor holding a Panzer, never an elite)"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_gauge_boss_pip.js")
    if ($LASTEXITCODE -ne 0) { Die "Tower gauge boss pip validation failed." }
}

Step "crosshair damage numbers (one per zombie, tod_dmg lane)"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_dmg_numbers.js")
    if ($LASTEXITCODE -ne 0) { Die "Damage number lane validation failed." }
}

# 2026-10-04: kill money = what the popup says. A cleave kill pays 75% of the
# slasher's base (melee) kill and the popup shows it, BOUNTY and Double Points
# included; the Mage's 80 rides the same death hook and popup.
Step "kill money vs kill popup (cleave 75%, Mage 80)"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_cleave_kill_pay.js")
    if ($LASTEXITCODE -ne 0) { Die "Cleave kill money / popup validation failed." }
    & node (Join-Path $PSScriptRoot "test_mage_kill_points.js")
    if ($LASTEXITCODE -ne 0) { Die "Mage kill money / popup validation failed." }
}

# v19.76 (2026-10-06): the lead tester's Oct 4-6 list, server half - the trial skip
# (executed, with the v19.75 watchdog as its negative control), the summit gate kept
# shut + its rails, no flourish on upgrade swaps, power-ups paused for the cards
# (executed), the closing song's pause, the thinned riser FX, the King bar feed.
Step "tester fixes 2026-10-06 (trial skip, summit, flourish, power-up pause, finale, smoke, King bar)"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_tester_fixes_1006.js")
    if ($LASTEXITCODE -ne 0) { Die "Tester fixes 1006 validation failed (tools/test_tester_fixes_1006.js)." }
}

Step "lead-tester fixes 2026-09-24 (RK5, Zombie Blood aggro, co-op QR prompt, crate trigger, end stats, staff name, bear melee)"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_tester_fixes_0924.js")
    if ($LASTEXITCODE -ne 0) { Die "Lead-tester fix validation failed." }
    & node (Join-Path $PSScriptRoot "test_staff_name_feed.js")
    if ($LASTEXITCODE -ne 0) { Die "Staff name feed validation failed." }
}

# ZOMBIE BLOOD'S SCREEN FILTER (v19.65, 2026-09-30). The visual was deleted in
# August because it activated a visionset_mgr name nothing registered - that
# killed the window thread and left players ignored + invulnerable for the
# match. Pins the registration lockstep (lower-case name, both first-frame
# __init__s), the threaded start/stop, and the fade against the window clock.
Step "Zombie Blood screen filter (registered overlay, threaded start/stop, fade ends with the window)"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_zombie_blood_filter.js")
    if ($LASTEXITCODE -ne 0) { Die "Zombie Blood filter validation failed." }
}

# TEAMMATES' SHIELD BARS (2026-09-30). A shield's health reaches only its owner's
# HUD (a clientuimodel), so _zm_aetherium_hud broadcasts every slot to every party
# row on one packed int. Pins the server/Lua base lockstep + round trip, the post-
# func start, the no-icon rule and the rows' cleanup; 6 negative controls.
Step "teammates' shield bars (packed broadcast lockstep, row slot, no icon)"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_party_shield.js")
    if ($LASTEXITCODE -ne 0) { Die "Teammate shield bar validation failed." }
}

# THE CO-OP RESTART LANE (v19.63, 2026-09-30). The restart bug shipped THREE
# times because nothing checked HOW the menu restarted: a client console command
# (Engine.Exec map_restart) restarts the host alone. This gate forbids that lane
# in ui/ outright and pins the server contract (menu name + response key in
# lockstep between Lua and GSC, game["state"] before map_restart( true ), host
# check, ExitLevel( false ), the tod_party publisher and its Lua reader).
Step "co-op restart lane (no client-side map_restart; server contract in lockstep)"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_coop_restart_lane.js")
    if ($LASTEXITCODE -ne 0) { Die "Co-op restart lane validation failed - a client-side restart/disconnect lane is back, or the Lua/GSC contract drifted." }
}

# THE ROCKETS (docs/170, 2026-10-02). The post-crown EXTRACT / ASCEND rides: flies all four flights with the
# shipping GSC over the GENERATED keys against the generated .map (hull + camera clearance, camera step, the sky
# seal), checks the beats fit their rides and the letterbox watchdog outlasts them (LOCKSTEP with
# TodRocketCine.lua), and the wiring (zone lines, real .efx sources, alias rows + wavs, the generated data, the
# clips in the .map, the callers, the reused hint strings); 7 negative controls. A GSC / zone / alias edit rides
# a -GscOnly build, so this runs on every build.
Step "the rockets (flights clear the map, beats fit, wiring)"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "rocket\test_rocket_ride.js")
    if ($LASTEXITCODE -ne 0) { Die "Rocket ride validation failed - a flight clips the map or snaps the camera, a beat no longer fits its ride, or the wiring broke (tools/rocket/test_rocket_ride.js)." }
}

Step "luck orb delivery / source / FX validation"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_luck_orbs.js")
    if ($LASTEXITCODE -ne 0) { Die "Luck orb delivery validation failed." }
    & python (Join-Path $PSScriptRoot "gen_luck_orb_fx.py") --check --tools $Tools
    if ($LASTEXITCODE -ne 0) { Die "Luck orb FX validation failed." }
    # docs/167 item 1 (second pass): the Healing Aura's flat ground AREA, one per radius
    # (stock Domination ring + bokeh disc + the luck soul's mote), regenerated byte-for-byte.
    & python (Join-Path $PSScriptRoot "gen_heal_area_fx.py") --check --tools $Tools
    if ($LASTEXITCODE -ne 0) { Die "Healing Aura area FX validation failed." }
    # 2026-10-01: ARCHMAGE on the world - ten client effects + the tod_arch_form field,
    # which must match in BOTH VMs or the map does not load (memory clientfield-registration-window).
    & python (Join-Path $PSScriptRoot "gen_archmage_fx.py") --check --tools $Tools
    if ($LASTEXITCODE -ne 0) { Die "Archmage FX validation failed." }
    # 2026-10-01: the trial halls - walls in each hall's colour, the frenzy, the win shower,
    # the King's countdown - in lockstep with gen_tower_map.js hues and the _tod_spire hooks.
    & python (Join-Path $PSScriptRoot "gen_trial_fx.py") --check --tools $Tools
    if ($LASTEXITCODE -ne 0) { Die "Trial FX validation failed." }
    # 2026-10-01: Rampage on the column's strips + the switch bursts - geometry held to
    # gen_tower_map.js, the todRampage HUD value, the CSC loaded, the switch waits.
    & python (Join-Path $PSScriptRoot "gen_rampage_fx.py") --check --tools $Tools
    if ($LASTEXITCODE -ne 0) { Die "Rampage FX validation failed." }
    & python (Join-Path $PSScriptRoot "import_luck_orb_audio.py") --check
    if ($LASTEXITCODE -ne 0) { Die "Luck orb audio validation failed." }
    # 2026-10-02: the Rampage switch's ON / OFF stings - the shipped WAVs are the tool's own output, both alias rows
    # point at their own WAV (pass 1 shipped tod_rampage_on on the HOOP sting), the switch plays both, and the stock
    # purchase cha-ching stays off the flip (user: "Remove the cha ching").
    & python (Join-Path $PSScriptRoot "rampage_sfx/build_rampage_sfx.py") --check
    if ($LASTEXITCODE -ne 0) { Die "Rampage ON/OFF sting validation failed - re-run: python tools/rampage_sfx/build_rampage_sfx.py" }
}

Step "Thunder Smash state / animation validation"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_thunder_smash.js")
    if ($LASTEXITCODE -ne 0) { Die "Thunder Smash state/inventory validation failed." }
    & python (Join-Path $PSScriptRoot "verify_thunder_smash.py")
    if ($LASTEXITCODE -ne 0) { Die "Thunder Smash animation/asset validation failed." }
}

Step "GSC arity / resolution lint"
if (-not $DryRun) {
    & python (Join-Path $PSScriptRoot "verify_cyber_reference_sources.py")
    if ($LASTEXITCODE -ne 0) { Die "Cyber equipment masters and baked textures do not match." }
    & python (Join-Path $PSScriptRoot "test_cyber_equipment_layout.py")
    if ($LASTEXITCODE -ne 0) { Die "Cyber equipment limb separation failed." }
    & python (Join-Path $PSScriptRoot "verify_cyber_zombie.py")
    if ($LASTEXITCODE -ne 0) { Die "Cyber zombie model structure failed." }
    & python (Join-Path $PSScriptRoot "verify_cyber_roster.py")
    if ($LASTEXITCODE -ne 0) { Die "Cyber roster source verification failed." }
    & node (Join-Path $PSScriptRoot "test_armored_walk.js")
    if ($LASTEXITCODE -ne 0) { Die "Armored walk policy validation failed." }
    & node (Join-Path $PSScriptRoot "test_armored_dev_rounds.js")
    if ($LASTEXITCODE -ne 0) { Die "Armored dev round preview validation failed." }
    & python (Join-Path $PSScriptRoot "heavenly_altar/verify_native.py")
    if ($LASTEXITCODE -ne 0) { Die "Heavenly Altar model or shared placement validation failed." }
    # 2026-10-02: the CYBER Rampage Inducer (tools/inducer_cyber) replaced the BO6
    # canister; its gate pins the shipped files, the bones/clips (seamless, starting
    # on the bind pose) and the animtree/zone/script/generated-trigger lockstep.
    # (tools/inducer/verify.py checked the retired BO6 port and no longer runs.)
    & python (Join-Path $PSScriptRoot "inducer_cyber/verify.py")
    if ($LASTEXITCODE -ne 0) { Die 'Cyber Rampage Inducer model/animation/lockstep validation failed.' }
    # 2026-10-02 (v19.69): the power terminal's power-on animation (tools/fan_props/build_power_anim.py) - the boot
    # frames, the dial and their GDT re-derived byte-for-byte, the binaries' face counts, and the dial's #defines in
    # _tod_power_terminal.gsc == art/fan_props/power_anim.json (a drift spins the disc off the button).
    & python (Join-Path $PSScriptRoot "fan_props/build_power_anim.py") --check
    if ($LASTEXITCODE -ne 0) { Die 'Power terminal animation assets or the dial lockstep drifted - run: python tools/fan_props/build_power_anim.py' }
    # 2026-10-02 (v19.69): the spawn sign rebuilt as a clean relief + its OFF / DIM power twins
    # (tools/fan_props/build_sign_relief.py) - every shipped file == art/fan_props/sign_relief.json, the GDT re-derived
    # byte-for-byte, the footprint inside the generator's placed size, and the script/zone naming all three models.
    & python (Join-Path $PSScriptRoot "fan_props/build_sign_relief.py") --check
    if ($LASTEXITCODE -ne 0) { Die 'Spawn sign relief assets or their script/zone wiring drifted - run: python tools/fan_props/build_sign_relief.py --skip-render' }
    & node (Join-Path $PSScriptRoot "test_cyber_zombie_spawns.js")
    if ($LASTEXITCODE -ne 0) { Die "Cyber zombie spawn selection failed." }
}
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot "test_starter_weapons.js")
    if ($LASTEXITCODE -ne 0) { Die "Starter weapon validation failed." }
}

Step "skirmisher / heavy primaries carry no optic (and can still ADS)"
if (-not $DryRun) {
    # Three edits per gun - optic model, optic ADS anims, and the PaP form's
    # sight tags. The third was missing for two passes and the symptom was a PaP
    # gun aiming down HIDDEN iron sights, which no hip-pose screenshot shows.
    & node (Join-Path $PSScriptRoot "test_no_optics.js")
    if ($LASTEXITCODE -ne 0) { Die "A skirmisher/heavy primary has an optic back, or a PaP form's ADS pose has no sight to aim down." }
}
if (-not $DryRun) {
    $aOut = & node (Join-Path $PSScriptRoot 'lint_tod_arity.js') 2>&1 | Out-String
    Write-Host $aOut
    if ($LASTEXITCODE -ne 0) {
        Die "GSC arity lint FAILED - a call does not match its function. Fix it before building."
    }
}

# A FLAG READ BEFORE IT EXISTS (2026-09-30). Stock runs every system __init__
# BEFORE main creates its flags, so a flag read on an __init__'s synchronous path
# is a terminal "cannot cast undefined to bool ... flag_shared.gsc" on EVERY load.
# Paid twice in _tod_powerups (2026-08-25 pap_power_hint, 2026-09-30 the dev
# Zombie Blood shelf); the arity lint passes it because the call is well-formed.
# Reads scripts only, so it runs on -GscOnly too. Self-tests on 16 shapes first.
Step "flags read before they exist on a system __init__ path"
if (-not $DryRun) {
    $fOut = & node (Join-Path $PSScriptRoot 'lint_tod_init_flags.js') 2>&1 | Out-String
    Write-Host $fOut
    if ($LASTEXITCODE -ne 0) {
        Die "Init-flag lint FAILED - a flag is read before it can exist on a system __init__ path. That crashes every load."
    }
}

# ===========================================================================
# DAMAGE-CALLBACK GUARD (v18.59, 2026-09-09). Runs on EVERY build including
# -GscOnly: it reads one GSC file and nothing else.
#
# upgrade_damage_cb returns -1 to mean "I changed nothing", and stock then
# applies the RAW damage. So every multiplier applied above that guard must
# also be TESTED by it. Three separate multipliers have now been added above
# the guard and left out of the test -- sprinter armour, the slasher sidearm
# lane (both v16.3) and the mage staff multiplier + script-paid PACK II/III
# (v18.59). Each one silently did nothing for exactly the players carrying no
# other upgrade, while the crosshair still showed the multiplied number.
#
# The test runs the SHIPPING condition text, not a copy, and carries a negative
# control that strips the terms back out and requires the mage case to regress.
# ===========================================================================
Step "damage-callback guard test"
if (-not $DryRun) {
    $dgOut = & node (Join-Path $PSScriptRoot 'test_upgrade_damage_guard.js') 2>&1 | Out-String
    Write-Host $dgOut
    if ($LASTEXITCODE -ne 0) {
        Die "damage-callback guard test FAILED - a multiplier applied in upgrade_damage_cb is not tested by its -1 fast path, so it is being discarded for players with no other upgrade. Fix the guard; do NOT build past this."
    }
}

# ===========================================================================
# MAGE TIMING (2026-09-09). Two rules that are invisible in play until they
# are wrong, so they get a gate rather than a playtest:
#   * tod_mage_cd holds ABSOLUTE GetTime() stamps, and GetTime runs through a
#     world pause -- so BLINK and the HEALING AURA lock recharged for free
#     during card events, won trials and the Warden King's max-out.
#   * staff_hit is threaded once per DAMAGED ACTOR and a staff bolt is splash,
#     so CHAIN LIGHTNING arced once per splash victim instead of once per shot.
# Both run the shipping function text and carry negative controls.
# ===========================================================================
Step "elite pause restore test"
if (-not $DryRun) {
    $epOut = & node (Join-Path $PSScriptRoot 'test_elite_pause_restore.js') 2>&1 | Out-String
    Write-Host $epOut
    if ($LASTEXITCODE -ne 0) {
        Die "elite pause restore FAILED - a short world pause can leave elites frozen. Fix the restore before building."
    }
}

# ===========================================================================
# DEATH PERCEPTION TARGETS (v19.72, 2026-10-03). Every build, -GscOnly
# included (GSC + CSC + Lua only). The perk outlines EVERY enemy: the horde,
# and since v19.72 the Panzer / Warden King / Rogue Protector / hellhound /
# Reaver, which the pulse skipped until then. Runs the SHIPPING server pulse and
# client outline over a simulated match: no elite outlined on its spawn frame
# (a counter clientfield throws there) or while drop_in holds it Ghosted, the
# Protector not hidden by its lifelong ignoreme, a dead enemy's outline
# cleared, split-screen any-owner. Seven negative controls; the card copy and
# the two VMs' registrations are pinned too.
# ===========================================================================
Step "Death Perception targets test"
if (-not $DryRun) {
    $dpOut = & node (Join-Path $PSScriptRoot 'test_death_perception.js') 2>&1 | Out-String
    Write-Host $dpOut
    if ($LASTEXITCODE -ne 0) {
        Die "Death Perception test FAILED - an enemy family lost its outline, an elite can be pinged on its spawn frame or mid drop-in, or a dead enemy keeps its outline. Fix it before building."
    }
}

Step "rampage lever + seal test"
if (-not $DryRun) {
    $rlOut = & node (Join-Path $PSScriptRoot 'test_rampage_levers.js') 2>&1 | Out-String
    Write-Host $rlOut
    if ($LASTEXITCODE -ne 0) {
        Die "rampage lever test FAILED - a lever lost its off-state identity, or the retired round-9 seal came back (v19.0: RAMPAGE toggles all match). Fix it before building."
    }
    $krOut = & node (Join-Path $PSScriptRoot 'test_king_rampage.js') 2>&1 | Out-String
    Write-Host $krOut
    if ($LASTEXITCODE -ne 0) {
        Die "Warden King rampage/phase test FAILED - the phase ladder, a lever gate, the one-sprint-thread latch or the single berserk call site moved. Fix it before building."
    }
}

Step "riot shield card refill test"
if (-not $DryRun) {
    & node (Join-Path $PSScriptRoot 'test_panzer_flame_fx.js')
    if ($LASTEXITCODE -ne 0) { Die "Panzer flame visual-state test FAILED." }
}
if (-not $DryRun) {
    $rsOut = & node (Join-Path $PSScriptRoot 'test_riotshield_card_refill.js') 2>&1 | Out-String
    Write-Host $rsOut
    if ($LASTEXITCODE -ne 0) {
        Die "riot shield card test FAILED - a RIOT SHIELD card must END a recharge and hand the shield back (v18.99c), and a routine reconcile must NOT. Fix it before building."
    }
}

Step "mage pause / chain timing test"
if (-not $DryRun) {
    $mtOut = & node (Join-Path $PSScriptRoot 'test_mage_pause_and_chain.js') 2>&1 | Out-String
    Write-Host $mtOut
    if ($LASTEXITCODE -ne 0) {
        Die "mage timing test FAILED - a cooldown is running through the world pause, or CHAIN LIGHTNING is arcing per splash victim instead of per shot. Fix it; do NOT build past this."
    }
}

# =========================================================================
# LUA STRUCTURE LINT (2026-08-31). Runs on EVERY build, -GscOnly included:
# Lua rides in ui/ as zoned rawfiles, so it ships on the fast path too.
#
# WHY IT IS A GATE AND NOT AN ADVISORY: nothing else in this pipeline reads
# Lua before the linker packs it. tod_upgrade.lua alone draws the upgrade
# panel, the damage numbers, the tower gauge, the luck bar, the finale
# banner and the rampage seal - one dropped `end` takes all six off the
# screen at once, in game, with a completely green build behind it.
# It is a block/bracket balancer, not a parser - see the file header for
# exactly what it does and does not prove.
# =========================================================================
# =========================================================================
# ARMORY DRIFT CHECK (2026-09-01) — a WARNING, never a gate.
#
# docs/armory.html is the rebalance workbench the user actually designs from,
# and it is STATIC: every number is transcribed by hand, never read at view
# time. So it silently rots on every balance edit, and a wrong number there
# is a wrong INPUT TO A DESIGN DECISION rather than a cosmetic docs bug.
#
# WHY THIS IS WIRED IN AT ALL: both verifiers already existed and neither was
# ever run automatically. On 2026-09-01 the page drifted TWICE IN ONE SESSION
# from the same author — four domains retuned without the page moving, then a
# fifth reworked after the page had just been fixed. Relying on remembering
# is what failed; this is the durable version.
#
# WARNING, NOT A GATE, deliberately: a stale DOC must never block shipping a
# correct .ff. It prints and moves on. Die() here would be the tail wagging
# the dog.
#
#   verify_armory_constants.js — the tune: strings vs the #defines, PLUS (added
#                                2026-09-09) every TOD_* identifier the page
#                                names anywhere, including in prose, and every
#                                domain ladder's length. Four DELETED defines
#                                had accumulated in note: prose while this
#                                reported green, because unresolved names were
#                                printed as "check by hand" and still exited 0.
#   verify_armory_domains.js   — max / band / scope / class / guns / bonusMax
#                                per row, plus the hand-maintained header and
#                                tile counts, vs the shipping GSC
#   verify_armory_render.js    — the page actually DRAWS: syntax, boot under a
#                                fake DOM, every builder runs, and all twelve
#                                panels come out non-empty. The page has 12 tabs
#                                but only 8 builder functions, so "every builder
#                                ran" was never the same claim.
# None can check PROSE. A sentence can become false with no number moving;
# that still needs a human pass.
# =========================================================================
Step "Armory drift check (advisory)"
if (-not $DryRun) {
    $armC = & node (Join-Path $PSScriptRoot 'verify_armory_constants.js') 2>&1 | Out-String
    $armCode = $LASTEXITCODE
    $armD = & node (Join-Path $PSScriptRoot 'verify_armory_domains.js') 2>&1 | Out-String
    $armDCode = $LASTEXITCODE
    $armR = & node (Join-Path $PSScriptRoot 'verify_armory_render.js') 2>&1 | Out-String
    $armRCode = $LASTEXITCODE
    if ($armCode -ne 0 -or $armDCode -ne 0 -or $armRCode -ne 0) {
        Write-Host $armC
        Write-Host $armD
        Write-Host $armR
        Write-Host "[build] WARN: docs/armory.html has drifted from the code (advisory - build continues)."
        Write-Host "[build]       The user balances off that page; refresh + republish it before it misleads a design call."
    } else {
        Write-Host "  armory: constants + domain fields match the shipping GSC, and all 12 tabs render"
    }
}

Step "Lua structure lint (ui/**/*.lua)"
if (-not $DryRun) {
    $luaOut = & node (Join-Path $PSScriptRoot 'lint_tod_lua.js') 2>&1 | Out-String
    Write-Host $luaOut
    if ($LASTEXITCODE -ne 0) {
        Die "Lua structure lint FAILED - an unbalanced block, bracket or string in ui/. The menu would fail to load in game."
    }
}

# UI TEXT + LIFETIME TESTS (v19.59b, 2026-09-27). Run the real menu Lua under
# Lua 5.1 (lupa): every upgrade line at every level through the map's typeface
# (no dropped letters, nothing shrunk below 80%), the typeface widget itself,
# and pause / HUD / prompt element lifetimes. These were run by hand until the
# user found a pause-menu line left in the engine font. Lua-only changes ride
# -GscOnly builds, so this runs on every build.
Step "UI text + lifetime tests (lupa)"
if (-not $DryRun) {
    # test_tester_fixes_1001.lua (docs/167): the revive burst, the Mage's web
    # tile, the floor label and the party-row geometry, executed.
    # test_card_pips.lua (docs/172): whole deals through the real card panel - the
    # live level row's states, light-up, breathing, pick, lock, dark skip.
    # test_tester_fixes_1006.lua (v19.76): the King bar, the dual-wield clip (both
    # hands), the scoreboard ROUND header; test_mage_hud.lua: the Mage key badges
    # (now above their tiles) and the ability tile states.
    foreach ($t in @('test_pause_text_all.lua', 'test_typography.lua', 'test_ui_lifetimes.lua', 'test_tester_fixes_1001.lua', 'test_restart_menu.lua', 'test_rocket_cine.lua', 'test_card_pips.lua', 'test_tester_fixes_1006.lua', 'test_mage_hud.lua')) {
        $code = "from lupa.lua51 import LuaRuntime; LuaRuntime().execute(open(r'tools/$t', encoding='utf-8').read())"
        Push-Location $RepoRoot
        $uiOut = & python -c $code 2>&1 | Out-String
        $uiExit = $LASTEXITCODE
        Pop-Location
        Write-Host ($uiOut.Trim())
        if ($uiExit -ne 0) {
            Die "UI test $t FAILED - see the lines above."
        }
    }
}

# SOUND-CONTEXT LINT (2026-09-09). Every build, -GscOnly included - alias csvs
# are bank inputs on every build. A row with a ContextType/ContextValue is
# SILENT in this map (nothing here ever sets a sound context); the staff
# reload/first-raise foley shipped four builds that way. tools/lint_tod_sound_context.js
Step "sound-context lint (no context-gated alias rows)"
if (-not $DryRun) {
    $sndCtxOut = & node (Join-Path $PSScriptRoot 'lint_tod_sound_context.js') 2>&1 | Out-String
    Write-Host $sndCtxOut
    if ($LASTEXITCODE -ne 0) {
        Die "sound-context lint FAILED - an alias row is gated on a sound context this map never sets and would be silent. See the rows above."
    }
}

# =========================================================================
# CURSOR-HINT LINT (2026-08-31). Every build, -GscOnly included - a reworded
# hint IS a GSC-only change, and it is the change that skips every other gate.
#
# TWO THINGS, BOTH OF WHICH HAVE SHIPPED BROKEN:
#   * ROUTING. The Aetherium prompt kit picks which card to draw by
#     PATTERN-MATCHING THE HINT TEXT, so wording decides what the player
#     sees. Every priced non-door interactable in the map drew the WALL BUY
#     card - hardcoded description "Wall Weapon" - for months (found by the
#     user, 2026-08-31). The lint reads the router's own TOD_NOUNS table out
#     of the Lua, so GSC copy and the router cannot drift apart silently.
#   * THE TRIGGERSTRING 250 CAP. SetHintString mints one PERMANENT engine
#     slot per DISTINCT string, never freed, and overflow fatals blaming
#     whoever registers NEXT. This counts DISTINCT STRINGS - the only count
#     that proves anything (v14.3's "fix" proved its loop had run instead).
#
# tools/lint_tod_hints_selftest.js breaks the map seven ways and requires a
# catch on each plus a clean control - run it whenever this lint is edited.
# =========================================================================
Step "cursor-hint lint (prompt routing + the 250 triggerstring cap)"
if (-not $DryRun) {
    $hintOut = & node (Join-Path $PSScriptRoot 'lint_tod_hints.js') 2>&1 | Out-String
    Write-Host $hintOut
    if ($LASTEXITCODE -ne 0) {
        Die "cursor-hint lint FAILED - a prompt would draw the wrong card, or the distinct-string budget is blown. Neither shows up at build time in game; fix it here."
    }
}

# =========================================================================
# 1a-3. UI ART LINT - nothing missing, nothing dead. Runs on EVERY build
#     including -GscOnly, because both failure modes are pure zone/Lua edits.
#       * MISSING: the Lua names an image with no `image,` line. The linker
#         says nothing (Lua is an opaque rawfile) and the game draws a WHITE
#         SQUARE. Hard fail, no baseline.
#       * DEAD: the zone line outlives the thing that drew it. Cards are
#         `uncompressed` 768x1152, so one dead card is 3.4 MB of LOAD RAM -
#         four retired domains were quietly shipping 12 of them until v16.86
#         (40.5 MB). Gated on REGRESSION against
#         tools/lint_tod_assets.baseline.json, whose "why" block says which
#         of the current numbers are accepted and why.
#     THE RULE: a card slug and its zone lines are ONE unit - retire both or
#     neither. tools/lint_tod_assets_selftest.js breaks the map eight ways
#     (including two shapes that must NOT fire) - run it whenever the lint is
#     edited. It cannot see materials or GSC-only image references; see its
#     header for what a pass does and does not prove.
# =========================================================================
Step "UI art lint (missing art / dead art)"
if (-not $DryRun) {
    $artOut = & node (Join-Path $PSScriptRoot 'lint_tod_assets.js') 2>&1 | Out-String
    Write-Host $artOut
    if ($LASTEXITCODE -ne 0) {
        Die "UI art lint FAILED - either the Lua names an image the zone does not carry (white square in game, silent at build), or dead art regressed against the baseline. Fix the art; never raise the baseline to hide it."
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
        $convexOut = & node (Join-Path $PSScriptRoot 'test_crown_convex.js') 2>&1 | Out-String
        Write-Host $convexOut
        if ($LASTEXITCODE -ne 0) { Die "crown convex geometry FAILED - emitted solids must be closed and collision sampling must agree with their planes." }
        $lintOut = & node (Join-Path $PSScriptRoot 'lint_tod_geometry.js') 2>&1 | Out-String
        Write-Host $lintOut
        if ($LASTEXITCODE -ne 0) {
            Die "geometry lint FAILED - the .map has a new hole, a new invisible wall, or the road is severed. Fix the generator, not the baseline."
        }
        # 2026-10-02 (v19.68o, docs/169): the surface refresh's art + materials are GENERATED
        # (tools/gen_tod_refresh_assets.py), and the floor-number digit crops in the map
        # generator are LOCKSTEP with the atlas ink - a crop that cuts a digit would print a
        # clipped numeral on every landing with no other warning.
        & python (Join-Path $PSScriptRoot 'gen_tod_refresh_assets.py') --check
        if ($LASTEXITCODE -ne 0) { Die "surface refresh assets are stale, or the floor-number crops in gen_tower_map.js no longer hold the digit ink - run: python tools/gen_tod_refresh_assets.py" }
    }

    # =======================================================================
    # 1c. HALL BUNKER LINT (v18.78, user: "Everyone just bunker up in the little
    #     cubby") - no three-walled quiet spot in any spire trial hall: every
    #     pocket (open arc under 80 degrees at 160u) must have a riser INSIDE it.
    #     Reads the EMITTED .map like the geometry lint. The number is zero; no
    #     baseline. `node tools/lint_tod_hall_bunkers.js --png DIR` draws the
    #     arc heatmaps that designed the halls.
    # =======================================================================
    Step "hall bunker lint (spire trial halls)"
    if (-not $DryRun) {
        $bunkOut = & node (Join-Path $PSScriptRoot 'lint_tod_hall_bunkers.js') 2>&1 | Out-String
        Write-Host $bunkOut
        if ($LASTEXITCODE -ne 0) {
            Die "hall bunker lint FAILED - a trial hall has a three-walled pocket with no riser inside it (the BUNKER rows above). Fix SP_RM_LAYOUTS in the generator: move the piece, or put a riser in the pocket."
        }
    }

    # =======================================================================
    # 1d. PERCH LINT (v19.71, Workshop tester 2026-10-03: as the wall-running
    #     Slasher "first attempt am on top of the [ammo] box and cant be hit").
    #     No surface a player can stand on that the horde cannot walk onto or
    #     swing at, within athlete reach. The SAME model (tools/perch_core.js)
    #     runs inside gen_tower_map.js and closes every perch before the .map is
    #     written, so this re-proves the emitted file from scratch. Zero, except
    #     families written into lint_tod_perches.baseline.json with a reason.
    #     The self-test proves the gate still catches a flat prop top.
    # =======================================================================
    Step "perch lint (no unreachable standing spots)"
    if (-not $DryRun) {
        $perchSelf = & node (Join-Path $PSScriptRoot 'lint_tod_perches_selftest.js') 2>&1 | Out-String
        Write-Host $perchSelf
        if ($LASTEXITCODE -ne 0) { Die "perch lint SELF-TEST failed - the gate no longer catches a perch it must catch; fix tools/perch_core.js before trusting its pass." }
        $perchOut = & node (Join-Path $PSScriptRoot 'lint_tod_perches.js') 2>&1 | Out-String
        Write-Host $perchOut
        if ($LASTEXITCODE -ne 0) {
            Die "perch lint FAILED - a prop top or ledge players can stand on out of every zombie's reach. Close it in gen_tower_map.js (PERCH CAPS / PERCH SEAL), never by editing the baseline."
        }
    }

    Step "cod2map64 (BSP + navmesh + navvolume)  [cwd = bin]"
    $bspDir = Split-Path $Bsp -Parent
    if (-not (Test-Path $bspDir) -and -not $DryRun) { New-Item -ItemType Directory -Path $bspDir -Force | Out-Null }

    $cod2Args = @('-platform', 'pc', '-navmesh', '-navvolume', '-loadFrom', (Q $MapSrc), (Q $Bsp))
    $r = Invoke-BuildExe $Cod2 $cod2Args 'cod2map64' $Bin

    if (-not $DryRun) {
        # KEEP THE cod2map TRANSCRIPT (2026-09-03). Invoke-BuildExe captures
        # stdout/stderr to two temp files, reads them into $r.Out/$r.Err and
        # DELETES both in its finally block -- so on a SUCCESSFUL build the
        # entire cod2map output was thrown away and nothing reached disk. That
        # is why the tower's navmesh failure (zero seeds above the base arena,
        # everything past ~floor 17 compiled with no mesh) left no trace to
        # read afterwards: the diagnosis had to be rebuilt from the .map and
        # the Havok config instead of from the log that had already said it.
        # A build that only prints on FAILURE cannot explain a build that
        # SUCCEEDS and ships broken. *.log is gitignored.
        $c2log = Join-Path $PSScriptRoot 'cod2map_last.log'
        try {
            @($r.Out, $r.Err) | Set-Content $c2log -Encoding utf8 -ErrorAction Stop
            Info "cod2map transcript -> $c2log"
        } catch { Warn "could not write $c2log ($($_.Exception.Message))" }

        # NAVMESH DIAGNOSTICS. Havok AI keeps a navmesh region if it passes
        # EITHER of two independent tests -- area >= threshold, OR within
        # pruning.minDistanceToSeedPoints (14) of a seed point -- and when
        # every region fails BOTH it silently keeps only the largest and
        # discards the rest. Its own string says so verbatim: "All regions are
        # below the area threshold and too far from a seed point. Keeping the
        # largest region." That is how 50 floors of tower shipped with mesh on
        # the bottom ~17 and none above, on a build that reported success.
        #
        # 'Could not drop node' is the one to read after any seed change: it is
        # cod2map failing to anchor a seed onto walkable mesh AND NAMING THE
        # COORDINATE, so it validates each of the 149 tower seeds by position.
        # It turns "the mesh got bigger, probably good" into "here is the exact
        # seed that is not anchored". Full builds only -- -GscOnly never runs
        # cod2map, so an empty log there means nothing ran, not nothing wrong.
        $navWarn = @($r.Out, $r.Err) -split "`r?`n" | Where-Object { $_ -match 'Keeping the largest region|below the area threshold|too far from a seed|Could not drop node|too many edges or faces|ran out of memory|No regions found|Empty nav mesh|Removed degenerate navmesh face|NavVolume generation is skipped' }
        if ($navWarn) { Warn ("cod2map NAVMESH:`n  " + ($navWarn -join "`n  ")) }

        if ($r.Out -match 'Unable to load navigation mesh generation settings' -or $r.Err -match 'Unable to load navigation mesh generation settings') {
            Write-Host $r.Out
            Die "cod2map64 could not load navmesh settings (cwd was not bin?) - navmesh is STALE; refusing to continue"
        }
        if ($r.Code -ne 0) { Write-Host $r.Out; Write-Host $r.Err; Die "cod2map64 exited $($r.Code)" }
        if (-not (Test-Path $Bsp)) { Die "cod2map64 produced no .d3dbsp at $Bsp" }
        Info ("BSP written: {0:N1} MB @ {1}" -f ((Get-Item $Bsp).Length / 1MB), (Get-Item $Bsp).LastWriteTime)
        if (Test-Path $NavHkt) { Info ("navmesh.hkt updated @ {0}" -f (Get-Item $NavHkt).LastWriteTime) }
        else { Warn "no _navmesh.hkt found at $NavHkt (ground zombies may not path)" }

        # NAVMESH CONNECTIVITY GATE (2026-09-04). lint_tod_navmesh.js decodes the
        # .hkt cod2map just wrote (faces, edges, vertices) and requires every
        # tower floor and every spire floor to sit in ONE connected component.
        # The day it was written the shipped mesh was 18 islands, cut inside the
        # E flight of laps 17/19/33/39/43 on BOTH towers - "random spots where
        # zombies won't attack you", floor 42-44 being the live report. The .hkt
        # BYTE SIZE, the seed count and cod2map's transcript all read clean on
        # that mesh; only reading the faces showed it. A seam is a shipped bug
        # that no play-test below it can see, so this is a hard stop.
        Step "navmesh connectivity gate (lint_tod_navmesh.js)"
        if (Test-Path $NavHkt) {
            $navLint = & node (Join-Path $PSScriptRoot 'lint_tod_navmesh.js') $NavHkt 2>&1 | Out-String
            Write-Host $navLint
            if ($LASTEXITCODE -ne 0) {
                Die "navmesh gate FAILED - the mesh cod2map wrote is not one connected walk per tower (see the SEAM / ISLAND rows above). Zombies cannot cross a seam and a player standing on one cannot be targeted. Fix the geometry (tools/gen_tower_map.js RAMP_LIFT block explains the known cause); never ship past this."
            }
        }
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
# 3c. -CleanPak: retire the incrementally-grown xpak so the linker writes a
#     fresh one (2026-09-03, docs/86). The linker only APPENDS to the pack:
#     every full build leaves the previous build's reflection probes / probe
#     volumes / sun-shadow tree behind, every replaced asset leaves a hole,
#     and the Workshop upload ships all of it (measured 9.5 GB, ~5.3 GB of
#     it history; 47 shadow trees under one name). The pack is MOVED OUT of
#     zone\ (the upload ships the whole folder, so a rename inside it would
#     upload too), restored if the link fails to write a fresh one, and
#     deleted on BUILD OK. Same volume, so the move is instant.
# ===========================================================================
# A clean pack must include all languages: their image payloads also append.
if ($CleanPak -and $GscOnly) { Die "-CleanPak needs a FULL build (drop -GscOnly)" }
if ($CleanPak -and -not $AllLanguages) {
    $AllLanguages = $true
    Info "-CleanPak: rebuilding all language packs as well as the main pack"
}
$languagesToBuild = @()
if ($AllLanguages) {
    $languagesToBuild = @(Get-ChildItem (Join-Path $Tools 'zone_source') -Directory |
        Where-Object { $_.Name.ToLower() -notin @('all','english') } |
        Sort-Object Name | ForEach-Object { $_.Name })
    if ($languagesToBuild.Count -lt 6) { Die "Incomplete installed language set" }
    foreach ($language in $languagesToBuild) { $null = Get-TodLanguagePrefix $language }
}
if ($CleanPak -and -not $DryRun) {
    Step "clean all packs (rollback retained through the last language)"
    $script:TodPakTransaction = Start-TodCleanPaks $FfDir $MapName $languagesToBuild
    Info "previous compiled files protected outside zone: $($script:TodPakTransaction.HoldDir)"
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
        Warn "$($unexpected.Count) UNEXPECTED linker error(s):"
        $unexpected | Select-Object -First 25 | ForEach-Object { Write-Host "    ! $_" -ForegroundColor Yellow }
        Die 'Unexpected English linker errors; a fresh fastfile alone is not a complete build.'
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

    Info ("English link verified: {0} ({1:N1} MB); checking remaining languages before BUILD OK" -f $ffAfter.Name, ($ffAfter.Length / 1MB))
}

if (-not $DryRun) {
    Step "cyber zombie compiled geometry coverage"
    $cyberLedger = Join-Path $Tools ("usermaps\{0}\zone_source\all\assetinfo\{0}_xmodel.csv" -f $MapName)
    if (-not (Test-Path $cyberLedger)) {
        $cyberLedger = Join-Path $Tools ("usermaps\{0}\zone_source\english\assetinfo\{0}_xmodel.csv" -f $MapName)
    }
    & python (Join-Path $PSScriptRoot 'verify_cyber_zombie.py') --compiled-ledger $cyberLedger
    if ($LASTEXITCODE -ne 0) { Die "Cyber zombie compiled geometry is missing or incomplete." }
    & python (Join-Path $PSScriptRoot 'verify_cyber_roster.py') --compiled-ledger $cyberLedger
    if ($LASTEXITCODE -ne 0) { Die "Cyber roster compiled geometry is missing or incomplete." }
    & python (Join-Path $PSScriptRoot 'heavenly_altar/verify_native.py') --compiled-ledger $cyberLedger
    if ($LASTEXITCODE -ne 0) { Die "Heavenly Altar compiled geometry is missing or incomplete." }
    & python (Join-Path $PSScriptRoot 'inducer_cyber/verify.py') --compiled-ledger $cyberLedger
    if ($LASTEXITCODE -ne 0) { Die "Cyber Rampage Inducer did not link whole (model, clips, animtree or maps missing)." }
    & python (Join-Path $PSScriptRoot 'build_staff_assembly.py') --compiled-ledger $cyberLedger
    if ($LASTEXITCODE -ne 0) { Die "Complete fire/lightning staff heads are missing or incomplete." }
    & python (Join-Path $PSScriptRoot 'staff_world_lods.py') --compiled-ledger $cyberLedger
    if ($LASTEXITCODE -ne 0) { Die "A third-person staff model compiled with reduced LODs (docs/167 item 4)." }

    # NO MATERIAL MAY LINK AGAINST A MISSING SHADER (2026-09-23). The linker does
    # not fail on a material whose materialType has no techsetdef: it builds it on
    # missing_techsetdef_geometry, logs nothing in the errorlog, and the surface
    # renders as the engine's grey stand-in. That is how the Widow's Wine machine's
    # powered panel shipped blank for three weeks. The assetinfo ledger is the only
    # record; read it after every link. Baseline is ZERO - never add a waiver here,
    # install the techsetdef (repo share\raw\techsetdefs_stable*, synced) instead.
    Step "materials built against a missing shader"
    $assetLedger = Join-Path $Tools ("usermaps\{0}\zone_source\all\assetinfo\{0}.csv" -f $MapName)
    if (-not (Test-Path $assetLedger)) {
        $assetLedger = Join-Path $Tools ("usermaps\{0}\zone_source\english\assetinfo\{0}.csv" -f $MapName)
    }
    if (-not (Test-Path $assetLedger)) { Die "asset ledger not found after the link: $assetLedger" }
    $missingTechset = @(Select-String -Path $assetLedger -Pattern 'missing_techsetdef' -SimpleMatch)
    if ($missingTechset.Count -gt 0) {
        foreach ($m in $missingTechset) { Info ("  " + $m.Line) }
        Die ("{0} ledger row(s) name a material built against a MISSING techsetdef (grey stand-in in game). Install the material type's techsetdef under share\raw\techsetdefs_stable and _toolsgfx; see verify_perk_machine_presentation.py." -f $missingTechset.Count)
    }
    Info "no material linked against a missing techsetdef"

    # EVERY MODEL A GENERATED WEAPON FORM NAMES MUST BE IN THE LEDGER (2026-09-23,
    # the sight audit). test_no_optics.js proves the GDT's sight picture is
    # self-consistent by NAME; this proves the names resolve to models the linker
    # actually built. A view model, world model or attachment slot pointing at an
    # unbuilt model draws nothing in game (an invisible sight, a bare rail) and the
    # linker does not fail on it. Reads the same ledger as the gate above.
    Step "weapon models linked (view, world, every attachment slot)"
    & node (Join-Path $PSScriptRoot 'verify_weapon_models_linked.js') $assetLedger
    if ($LASTEXITCODE -ne 0) { Die "a generated weapon form names a model the linker did not build (it would be invisible in game) - see the MISSING rows above." }
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
# Verification requires the exact expected language prefix and fresh fastfile.
# Clean builds additionally validate every corresponding pack before commit.
if ($AllLanguages -and -not $DryRun) {
    Step "language fastfiles (-AllLanguages)"
    # LANGUAGE SET IS DERIVED, NOT LISTED (2026-09-04, Workshop report
    # "Could not find zone 'ea_zm_tower_of_doom'"): the hand list here missed
    # 'englisharabic' (prefix ea_, the English/Arabic SKU) and 'polish' (po_),
    # so every client in those languages failed at map load - the SAME bug as
    # the 2026-08-26 French report, one language over. The engine has NO
    # fallback to en_: the per-language ff is resolved before any map script
    # runs, so the only failsafe is to ship one ff per language the linker
    # knows. The linker's language tokens are exactly the folder names under
    # <tools>\zone_source\ (all, english, englisharabic, french, german,
    # italian, japanese, polish, portuguese, russian, simplifiedchinese,
    # spanish, traditionalchinese) - proven 2026-09-04: every one of them
    # ⚠️ THE JAPANESE NOTE BELOW IS HISTORY FOR THE SPRINTER (2026-09-16). The
    # cyber roster replaced every regular appearance and its own derived models
    # ship japaneseUnsafe 0 (install_cyber_roster.py::block, user's call), so a
    # Japanese client now gets the same horde as everyone else. The two stock
    # exclusions in Test-TodExpectedLanguageExclusion are unrelated and stand.
    # linked a fresh <xx>_ ff (the 2026-09-03 "Chinese tokens rejected" was
    # the UNDERSCORED spelling 'simplified_chinese'; the folder spelling works).
    # Excluded: only 'all' and 'english' (the main pass). EVERY other folder
    # ships - user 2026-09-04: "Can we make it so that all possible languages
    # are supported? All prefixes are supported?" Japanese included: its zone
    # drops the japaneseUnsafe sprinter body (docs/86 §8), so a Japanese client
    # plays in English text and may see a placeholder sprinter model - untested,
    # but a guaranteed "Could not find zone 'ja_...'" at launch is strictly
    # worse. A NEW folder requires its verified prefix in clean_paks.ps1;
    # unknown prefixes and failed language passes stop the build.
    $langs = $languagesToBuild
    Info ("languages: {0}" -f ($langs -join ' '))
    # The bank the English pass verified; every language pass re-enters the shared
    # sound pipeline, so the guard after the loop compares against THIS size too.
    $bankAfterEnglish = @(Get-ChildItem $SndZone -Recurse -Filter "*.all.sabs" -File -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1)
    # LANGUAGE PASSES RETRY THE WAV-CONVERTER FAULT TOO (2026-09-30). The English
    # pass has retried it since 2026-08-24 (see the note above section 4), but each
    # of the eleven language passes got ONE try, so a single flake anywhere killed
    # the publish: v19.66's first two attempts died at french (t9_ak47 start +
    # t9_magnum shot2) and englisharabic (t9_magnum shot2), "Object reference not
    # set to an instance of an object", the wavs untouched, no second linker alive.
    # Retry the LANGUAGE LINKER ALONE, and only when EVERY unexpected error is that
    # signature (a .wav path line, the null-ref, or "Missing source checksum"); any
    # other error still fails on the first pass. Nothing is deleted between tries:
    # sound\zone holds the English bank this build already verified.
    # 6, not 3: the run that shipped v19.66 needed 8 retries across 6 of the 11
    # languages, and spanish + traditionalchinese each passed only on their THIRD
    # try - at that fault rate (~40% a pass) three tries fails a publish about
    # half the time. A real error still fails on the first pass (signature filter).
    $maxLangTries = 6
    $wavFlake = '\.wav\s*$|Object reference not set to an instance of an object|Missing source checksum'
    foreach ($lang in $langs) {
        $prefix = Get-TodLanguagePrefix $lang
        $languageFf = Join-Path $FfDir "${prefix}_$MapName.ff"
        for ($langTry = 1; $langTry -le $maxLangTries; $langTry++) {
            # The mid-build game-launch hazard applies to every pass, not just the
            # English one (a launched game file-locks the banks and poisons output).
            if (Get-Process BlackOps3 -ErrorAction SilentlyContinue) {
                Die ("BlackOps3 appeared before the '{0}' language pass - close the game and re-run; do NOT ship a build the game overlapped" -f $lang)
            }
            $languageStarted = Get-Date
            $rl = Invoke-BuildExe $Linker @('-language', $lang, '-modsource', $MapName) "linker[$lang]" $Bin
            $languageOut = "$($rl.Out)`n$($rl.Err)"
            $languageErrors = @($languageOut -split "\r?\n" |
                ForEach-Object { ($_ -replace '\^\d', '').Trim() } |
                Where-Object { $_ -match 'ERROR:|no file for filespec|Unresolved external' } |
                Where-Object { -not (Test-TodExpectedLanguageExclusion $Tools $lang $_) } |
                Where-Object { $line = $_; -not ($WaivedLinkerErrors | Where-Object { $line -match [regex]::Escape($_) }) })
            $onlyWavFlake = ($languageErrors.Count -gt 0) -and (@($languageErrors | Where-Object { $_ -notmatch $wavFlake }).Count -eq 0)
            if ($onlyWavFlake -and $langTry -lt $maxLangTries) {
                Warn ("{0}: wav-converter fault on attempt {1} ({2}) - retrying this language ({3} of {4})." -f $lang, $langTry, ($languageErrors -join ' | '), ($langTry + 1), $maxLangTries)
                continue
            }
            if ($langTry -gt 1 -and $languageErrors.Count -eq 0) { Info ("{0}: linked clean on attempt {1}." -f $lang, $langTry) }
            break
        }
        if ($languageErrors.Count -gt 0) { Die ("{0}: unexpected linker errors: {1}" -f $lang, ($languageErrors -join ' | ')) }
        if ($languageOut -match 'being used by another process' -or (Get-Process BlackOps3 -ErrorAction SilentlyContinue) -or (Test-Path $GameSeenFlag)) {
            Die "$lang overlapped the game or a locked sound bank"
        }
        $fresh = Get-Item -LiteralPath $languageFf -ErrorAction SilentlyContinue
        if (-not $fresh -or $fresh.LastWriteTime -le $languageStarted -or $fresh.Length -lt 128) {
            Die ("{0}: no fresh {1} (exit {2})" -f $lang, (Split-Path $languageFf -Leaf), $rl.Code)
        }
        Info ("{0}: {1} ({2:N0} KB)" -f $lang, $fresh.Name, ($fresh.Length / 1KB))
    }
    # The extra passes re-enter the shared sound pipeline, and the flaky wav
    # converter (see the retry note above section 4) can strand a stub bank on
    # any of them while still exiting 0 - re-assert the bank guard so a late
    # pass cannot silently undo a build the English pass already verified.
    $allSabsL = @(Get-ChildItem $SndZone -Recurse -Filter "*.all.sabs" -File -ErrorAction SilentlyContinue | Sort-Object Length -Descending)
    if ($allSabsL.Count -eq 0 -or $allSabsL[0].Length -lt 50MB) {
        Die "the .all.sabs bank is MISSING/truncated after the language passes - do NOT ship; delete sound\zone and rebuild"
    }
    # A SHRUNKEN bank passes the 50 MB floor (2026-09-16: a flaked pass left 122 MB
    # where every good build made 197.9 MB). The English pass's bank is the yardstick.
    if ($bankAfterEnglish.Count -gt 0 -and $allSabsL[0].Length -lt ($bankAfterEnglish[0].Length - 1MB)) {
        Die ("the .all.sabs bank SHRANK during the language passes ({0:N1} MB -> {1:N1} MB) - a partial bank; do NOT ship; delete sound\zone and rebuild" -f ($bankAfterEnglish[0].Length / 1MB), ($allSabsL[0].Length / 1MB))
    }
    Info ("sound bank still healthy after language passes: {0} ({1:N1} MB)" -f $allSabsL[0].Name, ($allSabsL[0].Length / 1MB))
}

if (-not $DryRun) {
    if ((Get-Process BlackOps3 -ErrorAction SilentlyContinue) -or (Test-Path $GameSeenFlag)) { Die "The game appeared during the build" }
    if ($GameWatchJob) { Stop-Job $GameWatchJob -ErrorAction SilentlyContinue; Remove-Job $GameWatchJob -Force -ErrorAction SilentlyContinue }
    $payload = @(Get-ChildItem -LiteralPath $FfDir -Recurse -File)
    $payloadBytes = ($payload | Measure-Object -Property Length -Sum).Sum
    $payloadReport = [pscustomobject]@{
        when=(Get-Date -Format o); clean=[bool]$CleanPak; allLanguages=[bool]$AllLanguages
        bytes=$payloadBytes
        files=@($payload | ForEach-Object { [pscustomobject]@{ path=$_.FullName.Substring($FfDir.Length+1); bytes=$_.Length; written=$_.LastWriteTime.ToString('o') } })
    }
    $payloadReport | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Tools "usermaps\$MapName\last_payload.json") -Encoding UTF8
    if ($Publish -or $CleanPak) {
        $briefOut = & node (Join-Path $PSScriptRoot 'xpak_report.js') --brief (Join-Path $FfDir "$MapName.xpak") 2>&1
        if ($LASTEXITCODE -notin @(0,2)) { Die "Pack report failed: $briefOut" }
        Info "pack attribution (advisory, binary units): $briefOut"
    }
    if ($script:TodPakTransaction) { Complete-TodCleanPaks $script:TodPakTransaction }
    Step "BUILD OK"
    Info ("fastfile: {0} ({1:N0} bytes)" -f $ffAfter.FullName, $ffAfter.Length)
    Info ("complete upload payload: {0:N0} bytes = {1:N3} GB (decimal), {2} files" -f $payloadBytes, ($payloadBytes / 1e9), $payload.Count)
    Write-Host "[build] READY TO TEST -> .\tools\run_game.ps1 (or PLAY_NORMAL.bat)" -ForegroundColor Green
}

# ===========================================================================
# 4c. publish ledger: stamp the pending row with THIS .ff's write time so the
#     upload can be matched to the build to the second (patch-notes system).
# ===========================================================================
if ($Publish -and -not $DryRun -and -not $SkipNotesGate) {
    $pn = Join-Path $PSScriptRoot 'patch_notes.js'
    & node $pn built --ff (Join-Path $FfDir "$MapName.ff")
    if ($LASTEXITCODE -ne 0) { Warn "patch_notes.js built did not stamp the ledger - run it by hand: node tools/patch_notes.js built" }
    Write-Host "[build] AFTER UPLOADING: node tools/patch_notes.js uploaded   (records the Steam time; paste the BBCode block as the change note)" -ForegroundColor Green
}

# ===========================================================================
# 5. optional launch
# ===========================================================================
if ($Run -and -not $DryRun) {
    Step "launching game (run_game.ps1)"
    & (Join-Path $PSScriptRoot 'run_game.ps1')
}

exit 0
