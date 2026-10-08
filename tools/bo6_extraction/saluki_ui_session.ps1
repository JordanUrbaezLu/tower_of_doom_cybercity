param([Parameter(Mandatory=$true)][string]$SessionDir,
      [ValidateRange(1,120)][int]$DurationMinutes=25)
$ErrorActionPreference = 'Stop'
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Saluki automation requires elevation; restart through the normal UAC prompt.'
}
Add-Type -AssemblyName System.Windows.Forms,System.Drawing,UIAutomationClient,UIAutomationTypes
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class SalukiNative {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
 [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X,Y; public POINT(int x,int y){X=x;Y=y;} }
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a,uint b,bool join);
 [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int n);
 [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h,int x,int y,int w,int ht,bool r);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
 [DllImport("user32.dll")] public static extern bool SetPhysicalCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern bool GetPhysicalCursorPos(out POINT point);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
}
'@
[SalukiNative]::SetProcessDPIAware() | Out-Null
[SalukiNative]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null
$exe = 'C:\Users\jorda\Documents\BO3_tools\Saluki\Saluki.exe'
New-Item -ItemType Directory -Path $SessionDir -Force | Out-Null
if (-not (Get-Process Saluki -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) | Out-Null
}
function Get-Saluki {
    $found = @(Get-Process Saluki -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe -and $_.MainWindowHandle -ne 0 })
    if ($found.Count -ne 1) { throw 'Expected exactly one visible Saluki window' }
    return $found[0]
}
function Get-Owner($handle) {
    [uint32]$ownerId = 0
    [SalukiNative]::GetWindowThreadProcessId($handle,[ref]$ownerId) | Out-Null
    return $ownerId
}
function Get-Rect($handle) {
    $rect = New-Object SalukiNative+RECT
    [SalukiNative]::GetWindowRect($handle,[ref]$rect) | Out-Null
    return $rect
}
function Set-SalukiPointer($point) {
    if (-not [SalukiNative]::SetPhysicalCursorPos($point.X,$point.Y)) { throw 'Could not position the physical pointer; no click sent' }
    $actual = New-Object SalukiNative+POINT
    if (-not [SalukiNative]::GetPhysicalCursorPos([ref]$actual) -or $actual.X -ne $point.X -or $actual.Y -ne $point.Y) {
        throw 'Physical pointer did not reach the verified Saluki target; no click sent'
    }
}
function Focus-Saluki($app) {
    $handle = [SalukiNative]::GetForegroundWindow()
    if ((Get-Owner $handle) -eq $app.Id) { return $handle }
    [SalukiNative]::ShowWindow($app.MainWindowHandle,9) | Out-Null
    [SalukiNative]::SetForegroundWindow($app.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 250
    $handle = [SalukiNative]::GetForegroundWindow()
    if ((Get-Owner $handle) -ne $app.Id) {
        # Same foreground method as tools/focus_game_window.ps1. No input is
        # sent until ownership is rechecked below; always detach the threads.
        [uint32]$frontOwner = 0
        [uint32]$targetOwner = 0
        $frontThread = [SalukiNative]::GetWindowThreadProcessId($handle,[ref]$frontOwner)
        $targetThread = [SalukiNative]::GetWindowThreadProcessId($app.MainWindowHandle,[ref]$targetOwner)
        $callerThread = [SalukiNative]::GetCurrentThreadId()
        $joinedFront = $false
        $joinedTarget = $false
        try {
            if ($callerThread -ne $frontThread -and $frontThread -ne 0) {
                $joinedFront = [SalukiNative]::AttachThreadInput($callerThread,$frontThread,$true)
            }
            if ($callerThread -ne $targetThread -and $targetThread -ne $frontThread) {
                $joinedTarget = [SalukiNative]::AttachThreadInput($callerThread,$targetThread,$true)
            }
            [SalukiNative]::BringWindowToTop($app.MainWindowHandle) | Out-Null
            [SalukiNative]::SetForegroundWindow($app.MainWindowHandle) | Out-Null
        } finally {
            if ($joinedTarget) { [SalukiNative]::AttachThreadInput($callerThread,$targetThread,$false) | Out-Null }
            if ($joinedFront) { [SalukiNative]::AttachThreadInput($callerThread,$frontThread,$false) | Out-Null }
        }
        Start-Sleep -Milliseconds 200
        $handle = [SalukiNative]::GetForegroundWindow()
    }
    if ((Get-Owner $handle) -ne $app.Id) {
        $rect = Get-Rect $app.MainWindowHandle
        $point = New-Object SalukiNative+POINT ($rect.Left+100),($rect.Top+12)
        if ((Get-Owner ([SalukiNative]::WindowFromPoint($point))) -ne $app.Id) { throw 'Saluki title bar is obscured; no input sent' }
        Set-SalukiPointer $point
        [SalukiNative]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
        [SalukiNative]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
        Start-Sleep -Milliseconds 200
        $handle = [SalukiNative]::GetForegroundWindow()
    }
    if ((Get-Owner $handle) -ne $app.Id) { throw 'Saluki did not gain focus; no input sent' }
    return $handle
}
function Read-Ui($handle) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($handle)
    $elements = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition)
    $rows = @()
    for ($i=0;$i -lt [Math]::Min($elements.Count,350);$i++) {
        $current = $elements[$i].Current
        if ($current.IsOffscreen) { continue }
        $rows += [pscustomobject]@{name=$current.Name;type=$current.ControlType.ProgrammaticName;id=$current.AutomationId;rect=$current.BoundingRectangle.ToString()}
    }
    return $rows
}
Start-Sleep -Seconds 3
$app = Get-Saluki
[SalukiNative]::MoveWindow($app.MainWindowHandle,100,80,1200,800,$true) | Out-Null
@{pid=$PID;saluki_pid=$app.Id;started=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $SessionDir 'ready.json') -Encoding UTF8
$deadline = [DateTime]::UtcNow.AddMinutes($DurationMinutes)
while ([DateTime]::UtcNow -lt $deadline) {
    foreach ($request in @(Get-ChildItem -LiteralPath $SessionDir -Filter 'request_*.json' | Sort-Object Name)) {
        $resultPath = Join-Path $SessionDir ($request.BaseName.Replace('request_','result_')+'.json')
        if (Test-Path -LiteralPath $resultPath) { continue }
        try {
            $command = Get-Content -LiteralPath $request.FullName -Raw | ConvertFrom-Json
            if ($command.action -eq 'stop') { '{"ok":true,"stopped":true}' | Set-Content -LiteralPath $resultPath; exit 0 }
            [SalukiNative]::SetThreadDpiAwarenessContext([IntPtr](-4)) | Out-Null
            $app = Get-Saluki
            $handle = Focus-Saluki $app
            $rect = Get-Rect $handle
            switch ($command.action) {
                'capture' {}
                'click' {
                    $x = $rect.Left+[int]$command.x; $y = $rect.Top+[int]$command.y
                    if ($x -lt $rect.Left -or $x -ge $rect.Right -or $y -lt $rect.Top -or $y -ge $rect.Bottom) { throw 'Click lies outside the observed Saluki window' }
                    $point = New-Object SalukiNative+POINT $x,$y
                    if ((Get-Owner ([SalukiNative]::WindowFromPoint($point))) -ne $app.Id) { throw 'Click target is not a Saluki window' }
                    Set-SalukiPointer $point
                    Start-Sleep -Milliseconds 100
                    [SalukiNative]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
                    Start-Sleep -Milliseconds 100
                    [SalukiNative]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
                }
                'text' {
                    if ($command.text -notmatch '^[a-zA-Z0-9_ .:/\\-]{1,220}$') { throw 'Unsupported text characters' }
                    # Saluki 0.2.39 sometimes lost the tail of long SendKeys
                    # input. Twelve-character chunks with UI consumption time
                    # were verified to select the complete exact hash.
                    $value=[string]$command.text
                    for ($offset=0; $offset -lt $value.Length; $offset+=12) {
                        $handle=Focus-Saluki (Get-Saluki)
                        [System.Windows.Forms.SendKeys]::SendWait($value.Substring($offset,[Math]::Min(12,$value.Length-$offset)))
                        Start-Sleep -Milliseconds 500
                    }
                }
                'keys' {
                    # Saluki's documented Ctrl+F focuses and selects the search text.
                    if ($command.keys -notin @('{ENTER}','{ESC}','{TAB}','{DOWN}','{UP}','^a','^f','{BACKSPACE}')) { throw 'Unsupported key sequence' }
                    [System.Windows.Forms.SendKeys]::SendWait([string]$command.keys)
                }
                default { throw 'Unsupported Saluki action' }
            }
            Start-Sleep -Milliseconds 500
            $handle = Focus-Saluki (Get-Saluki)
            $rect = Get-Rect $handle
            $bitmap = New-Object Drawing.Bitmap ($rect.Right-$rect.Left),($rect.Bottom-$rect.Top)
            $graphics = [Drawing.Graphics]::FromImage($bitmap)
            $graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$bitmap.Size)
            $shot = Join-Path $SessionDir ($request.BaseName+'.png')
            $bitmap.Save($shot,[Drawing.Imaging.ImageFormat]::Png)
            $graphics.Dispose(); $bitmap.Dispose()
            @{ok=$true;action=$command.action;window=[long]$handle;screenshot=$shot;ui=@(Read-Ui $handle)} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding UTF8
        } catch {
            @{ok=$false;error=$_.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $resultPath -Encoding UTF8
        }
    }
    Start-Sleep -Milliseconds 200
}
