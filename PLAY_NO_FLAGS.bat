@echo off
REM ===========================================================================
REM  PLAY_NO_FLAGS.bat - launch BO3 with ZERO command-line arguments (user
REM  2026-08-18: rule out the launch flags entirely; everything the map needs
REM  is hardcoded). The game boots to the FRONTEND MENU; load the map from:
REM     ZOMBIES -> map select -> ZM TOWER OF DOOM (custom maps section)
REM  The in-game loader sets fs_game/gametype itself - no flags needed.
REM
REM  This is also the crash bisect: if the game crashes at BOOT with zero
REM  flags, the failure is engine/install-level (our map is not even mounted
REM  yet). If the menu loads but picking the map crashes, the map content is
REM  implicated.
REM ===========================================================================

tasklist /FI "IMAGENAME eq linker_modtools.exe" 2>NUL | find /I "linker_modtools.exe" >NUL && goto build_running
tasklist /FI "IMAGENAME eq cod2map64.exe"      2>NUL | find /I "cod2map64.exe"      >NUL && goto build_running
tasklist /FI "IMAGENAME eq radiant_modtools.exe" 2>NUL | find /I "radiant_modtools.exe" >NUL && goto build_running

start "" "steam://rungameid/311210"
goto :eof

:build_running
echo.
echo  [PLAY_NO_FLAGS] A MAP BUILD IS RUNNING - not launching. Wait, then retry.
echo.
pause
exit /b 1
