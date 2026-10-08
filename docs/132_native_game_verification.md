# Starting and checking a match from an agent

The user explicitly requested this workflow be recorded on September 10, 2026.
Agents should build and launch native verification themselves when needed to
complete authorized work. Do not stop at telling the user how to start the map.
The user still judges subjective visuals and gameplay feel.

## Build and launch

1. Check for BlackOps3 and active linker/cod2map/Radiant processes. Do not build
   while the game runs or start another build alongside one already in progress.
   If the user is playing, prepare the changes and tests first; honor their
   instruction about when to close the match. Do not kill their match to build.
2. Run `tools/build_map.ps1` (full for geometry/GDT/images, `-GscOnly` for scripts
   with verified unchanged compiled geometry). Complete CLAUDE.md's source,
   deployed-tree and fastfile freshness checks. BUILD OK alone is not proof
   that a later sync did not replace the deployed source.
3. Run `tools/run_game.ps1`, or `PLAY_NORMAL.bat`. These archive the previous
   console log before launch. They use Steam's registered launch URI, not the
   raw BlackOps3.exe. Keep Steam's own Launch Options empty.
4. Steam may show **Launch Game with custom arguments**. Bring Steam forward,
   take and inspect a screenshot, then click its **Continue** button. This is
   the application's launch dialog; it is not a reason to stop and ask the user
   again when launching the test is already authorized.
5. Wait for the actual native map/HUD and recorder startup. BO3 may take roughly
   60-90 seconds on this machine. Process existence or the launcher's memory
   threshold message does not prove successful map load.

The working arguments are:

```text
+set fs_game zm_tower_of_doom +set_gametype zclassic +set developer 1 +set logfile 2 +set scr_mod_enable_devblock 1 +devmap zm_tower_of_doom
```

`+set_gametype zclassic` is essential; `+set g_gametype zclassic` does not replace
it. `+devmap` enters the map directly instead of navigating the map selection
menus. It does not select a class. Inspect the class picker, select the required
class, and hold its displayed lock key (Space in the verified keyboard layout).
Do not wait for an assumed class-selection timeout. `tod_dev`, god mode, maxed upgrades and the spire harness are source
settings; check the current source and never assume the launch command enables
all of them. Do not leave new test harnesses armed without recording it.

## Window tools (persistent copies of the helpers used this session)

Use separate PowerShell invocations to avoid repeated Add-Type declarations.
Both tools restrict the target process to BlackOps3 or steamwebhelper.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/focus_game_window.ps1 -Process steamwebhelper
if ($LASTEXITCODE -ne 0) { throw 'Steam focus failed; stop input' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/game_window.ps1 -Action shot -Process steamwebhelper -Output tmp/steam_launch.png
if ($LASTEXITCODE -ne 0) { throw 'Steam capture failed; stop input' }
```

**Inspect that image before clicking.** Coordinates are physical pixels relative
to the captured window. On the verified 1263x750 dialog, Continue was at
`-X 765 -Y 537`; measure again if its size or layout differs.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/game_window.ps1 -Action click -Process steamwebhelper -X 765 -Y 537
if ($LASTEXITCODE -ne 0) { throw 'Steam launch confirmation failed' }
```

For the game, use `-Process BlackOps3` (the default). `-Action shot` captures
the window; `-Action key -Key Enter` or `F`, `One`, `Two`, `Three`, arrows,
Escape, Space supplies a short key press. For the observed **HOLD SPACE TO LOCK**
class prompt, use `-Action key -Key Space -HoldMs 1600`; the helper releases the
key in finally. Wheel and bounded clicks are also
available. Choose input from what the current screenshot shows. Do not navigate
blindly or take over input while the user is actively playing.

The capture/input helper opts into DPI awareness. Without that, Windows returned
a 1010x600 logical rectangle for the actual 1263x750 Steam window and clicks
missed the button. The focus helper briefly attaches the window input threads,
restores/raises the target, detaches in finally, and fails if it did not focus.
The input helper checks the foreground process and rejects clicks outside the
window. **Always check LASTEXITCODE after each helper; do not continue input
after a failed focus or screenshot.** Do not use unguarded WScript.SendKeys:
it can type into an editor if the game closes. BO3 console commands require
a leading `/`; plain text was interpreted as player chat during this session.
Prefer launch arguments and source-driven tests to console typing.

## Verify and preserve the result

Read `<actual game>/console_mp.log` (the install without the `455130` suffix).
For the AI recorder require `[TOD_AI] ... START` with the expected build tag,
then actual ELITE/STATE output for the families being checked. Inspect native
script exceptions, not only startup asset warnings. Confirm the relevant
behavior in screenshots/logs rather than declaring success from compilation.

`PrintLn` must be inside `/# ... #/`. This engine's native loader rejects an
unwrapped call even when the linker accepts it. The devblock flag above is also
required for output. Build the entire log string outside the devblock: literals
assembled inside it were blank in the observed native run. See diagnostics doc
131 for the raw evidence and field limitations.

Archive at useful points and before closing/relaunching:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/capture_ai_logs.ps1
```

It preserves the raw console, numbered extract and metadata under unique
`tmp/elite_tracking/runs/` folders, including while the game writes the log.
A live snapshot can end mid-line. Its source hashes describe capture time,
not necessarily the loaded historical build.

Close only an agent-owned verification match when appropriate, or a user match
the user has authorized closing. Prefer CloseMainWindow; if the owned process
remains after its window closes, identify that exact PID before stopping it.
Avoid repeated force-kill/relaunch loops, which can jam Steam's launch handler.
State in the handoff whether the game is running and whether the change was
built, natively verified, or still needs a gameplay retest.
