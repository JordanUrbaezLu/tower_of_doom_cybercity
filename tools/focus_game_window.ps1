# Native foreground helper; see docs/132_native_game_verification.md.
param([ValidateSet('BlackOps3','steamwebhelper')][string]$Process='BlackOps3')
$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TodGameFocus {
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a,uint b,bool join);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h,int cmd);
}
'@
$target = Get-Process $Process | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $target) { throw 'No target window' }
[uint32]$targetPid = 0
[uint32]$frontPid = 0
$targetThread = [TodGameFocus]::GetWindowThreadProcessId($target.MainWindowHandle,[ref]$targetPid)
$frontThread = [TodGameFocus]::GetWindowThreadProcessId([TodGameFocus]::GetForegroundWindow(),[ref]$frontPid)
$callerThread = [TodGameFocus]::GetCurrentThreadId()
try {
 [TodGameFocus]::AttachThreadInput($callerThread,$frontThread,$true) | Out-Null
 [TodGameFocus]::AttachThreadInput($callerThread,$targetThread,$true) | Out-Null
 [TodGameFocus]::ShowWindowAsync($target.MainWindowHandle,9) | Out-Null
 [TodGameFocus]::BringWindowToTop($target.MainWindowHandle) | Out-Null
 [TodGameFocus]::SetForegroundWindow($target.MainWindowHandle) | Out-Null
} finally {
 [TodGameFocus]::AttachThreadInput($callerThread,$targetThread,$false) | Out-Null
 [TodGameFocus]::AttachThreadInput($callerThread,$frontThread,$false) | Out-Null
}

Start-Sleep -Milliseconds 200
if ([TodGameFocus]::GetForegroundWindow() -ne $target.MainWindowHandle) {
 throw 'Target window did not gain focus; do not send input.'
}
Write-Host "Focused $Process (PID $($target.Id))"
