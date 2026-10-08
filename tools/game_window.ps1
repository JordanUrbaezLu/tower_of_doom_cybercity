# Native window capture/input; see docs/132_native_game_verification.md.
param([ValidateSet('shot','key','wheel','click')][string]$Action='shot',[string]$Key='Enter',[string]$Output='tmp/game_window.png',[int]$Delta=-120,[ValidateSet('BlackOps3','steamwebhelper')][string]$Process='BlackOps3',[int]$X=0,[int]$Y=0,[ValidateRange(50,5000)][int]$HoldMs=120)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class TodGameWindow {
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint x,uint y,int data,UIntPtr extra);
}
'@
[TodGameWindow]::SetProcessDPIAware() | Out-Null
$game=Get-Process $Process -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$handle=$game.MainWindowHandle
if ($handle -eq 0) { throw 'No game window yet' }
[TodGameWindow]::SetForegroundWindow($handle) | Out-Null
Start-Sleep -Milliseconds 250
if ([TodGameWindow]::GetForegroundWindow() -ne $handle) {
 $front=[TodGameWindow]::GetForegroundWindow()
 [uint32]$frontPid=0
 [TodGameWindow]::GetWindowThreadProcessId($front,[ref]$frontPid) | Out-Null
 $frontProcess=Get-Process -Id $frontPid
 if ($frontProcess.ProcessName -ne $Process) { throw "Expected $Process; foreground is $($frontProcess.ProcessName); no input sent" }
 $handle=$front
}
if ($Action -eq 'key') {
 $code=@{Enter=13;Console=192;Escape=27;F=70;One=49;Two=50;Three=51;Space=32;Left=37;Right=39;Up=38;Down=40}[$Key]
 if (-not $code) { throw 'Unknown test key' }
 [TodGameWindow]::keybd_event($code,0,0,[UIntPtr]::Zero)
 try { Start-Sleep -Milliseconds $HoldMs }
 finally { [TodGameWindow]::keybd_event($code,0,2,[UIntPtr]::Zero) }
} elseif ($Action -eq 'click') {
 $rect=New-Object TodGameWindow+RECT
 [TodGameWindow]::GetWindowRect($handle,[ref]$rect) | Out-Null
 if ($X -le 0 -or $Y -le 0 -or $X -ge ($rect.Right-$rect.Left) -or $Y -ge ($rect.Bottom-$rect.Top)) { throw 'Click outside window' }
 [TodGameWindow]::SetCursorPos($rect.Left+$X,$rect.Top+$Y) | Out-Null
 [TodGameWindow]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
 Start-Sleep -Milliseconds 100
 [TodGameWindow]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
} elseif ($Action -eq 'wheel') {
 [TodGameWindow]::mouse_event(0x0800,0,0,$Delta,[UIntPtr]::Zero)
} else {
 $rect=New-Object TodGameWindow+RECT
 [TodGameWindow]::GetWindowRect($handle,[ref]$rect) | Out-Null
 $bitmap=New-Object Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top)
 $graphics=[Drawing.Graphics]::FromImage($bitmap)
 try {
  $graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$bitmap.Size)
  $bitmap.Save([IO.Path]::GetFullPath($Output),[Drawing.Imaging.ImageFormat]::Png)
 } finally { $graphics.Dispose();$bitmap.Dispose() }
 Write-Host "Saved $Output"
}
