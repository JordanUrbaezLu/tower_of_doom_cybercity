@echo off
REM ===========================================================================
REM  PLAY_NORMAL.bat - THE play script. Double-click to launch Tower of Doom
REM  THROUGH Steam (DRM-safe). Build FIRST (.\tools\build_map.ps1, or -GscOnly
REM  for script-only changes). Steam must be running + logged in. Loading takes
REM  ~40-60 seconds.
REM
REM  DEV / GOD MODE DO NOT LIVE HERE: they are HARDCODED in the build
REM  (scripts\zm\zm_tower_of_doom.gsc::tod_resolve_dev_flags - flip to
REM  "= true;" + rebuild for a test session, restore "= false;" to ship).
REM
REM  THE GAMETYPE FIX: pass "+set_gametype zclassic" (engine command, sticks),
REM  NOT "+set g_gametype zclassic" (resets to tdm -> black screen). Keep BO3's
REM  Steam LAUNCH OPTIONS EMPTY (Steam doubles them).
REM ===========================================================================

REM BUILD-IN-PROGRESS GUARD: launching while the linker writes the .ff loads a
REM half-written fastfile (= "UI Error" box / corrupt load).
tasklist /FI "IMAGENAME eq linker_modtools.exe" 2>NUL | find /I "linker_modtools.exe" >NUL && goto build_running
tasklist /FI "IMAGENAME eq cod2map64.exe"      2>NUL | find /I "cod2map64.exe"      >NUL && goto build_running
tasklist /FI "IMAGENAME eq radiant_modtools.exe" 2>NUL | find /I "radiant_modtools.exe" >NUL && goto build_running

REM logfile 2 = UNBUFFERED console_mp.log (logfile 1 buffers ~4KB, so a hang or
REM a Task-Manager kill loses the last lines - the 2026-08-21 black-screen triage
REM had the log cut mid-word with the real error still sitting in the buffer).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\capture_ai_logs.ps1"
if errorlevel 1 exit /b 1
start "" "steam://run/311210//+set fs_game zm_tower_of_doom +set_gametype zclassic +set developer 1 +set logfile 2 +set scr_mod_enable_devblock 1 +devmap zm_tower_of_doom"
goto :eof

:build_running
echo.
echo  [PLAY_NORMAL] A MAP BUILD IS RUNNING - not launching.
echo  Launching now would load a HALF-WRITTEN fastfile ("UI Error" box / corrupt load).
echo  Wait for the build to finish, then double-click this again.
echo.
pause
exit /b 1
