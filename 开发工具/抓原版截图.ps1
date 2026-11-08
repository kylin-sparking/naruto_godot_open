param(
    [string]$Out = ".scratch\yuanban.png",
    [switch]$NoFocus
)

# 把运行中的原版（NyaLauncher 的游戏窗口）调到前台并全屏截图。
# 必须带 UTF-8 BOM：PowerShell 5.1 无 BOM 时按 ANSI 读，中文会乱、参数名会解析失败。
# 必须先 SetProcessDPIAware：否则 Windows 按缩放比虚拟化分辨率（本机 2560x1440 会被报成
# 2048x1152），截出来的图右边和下边都是缺的。

Add-Type @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
public class NyaShot {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
'@

[NyaShot]::SetProcessDPIAware() | Out-Null
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$proc = Get-Process -Name NyaLauncher -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -match "游戏窗口" } | Select-Object -First 1
if ($null -eq $proc) { Write-Output "NOT_FOUND"; exit 1 }
$h = $proc.MainWindowHandle

if (-not $NoFocus) {
    [NyaShot]::ShowWindow($h, 9) | Out-Null
    [NyaShot]::BringWindowToTop($h) | Out-Null
    [NyaShot]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 700
}

$r = New-Object NyaShot+RECT
[NyaShot]::GetWindowRect($h, [ref]$r) | Out-Null
Write-Output ("WINDOW {0} {1} {2} {3} hwnd={4} pid={5}" -f $r.L, $r.T, ($r.R - $r.L), ($r.B - $r.T), $h, $proc.Id)

$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
Write-Output ("SCREEN {0}x{1} at {2},{3}" -f $b.Width, $b.Height, $b.Left, $b.Top)
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
$bmp.Save($Out)
Write-Output ("SAVED " + $Out)
