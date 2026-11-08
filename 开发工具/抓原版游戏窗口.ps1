param(
    [string]$Codes = "",
    [string]$Clicks = "",
    [string]$Out = ".scratch\ref.png"
)

# 驱动原版游戏窗口：先发按键（十六进制 VK 码，空格分隔），再按屏幕坐标点击，最后全屏截图。
#   人物(567,1348) 背包(612,1348) 忍术(655,1348) 宠物(695,1348) 任务(737,1348)
#   组队/好友/家族/商城/设置 在右侧，量法同上。
#
# 两个坑，都踩过：
#   1. 必须先 SetProcessDPIAware()，否则 Windows 按缩放比虚拟化分辨率
#      （本机 2560x1440 会被报成 2048x1152），截出来的图右边和下边都是缺的。
#   2. 点击前必须先发一次 MOUSEMOVE —— SetCursorPos 只挪系统光标，不产生
#      WM_MOUSEMOVE，游戏的悬停/点击判定不会被唤醒，点了没反应（只会穿到地图上让角色走路）。
#      先 SetCursorPos 到目标附近、发两次带位移的 MOUSEMOVE、再挪到目标按下抬起，才有效。
#
# 文件必须带 UTF-8 BOM：PowerShell 5.1 无 BOM 时按 ANSI 读，中文参数名会解析失败。

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class NyaDrive {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, IntPtr e);
}
'@

[NyaDrive]::SetProcessDPIAware() | Out-Null
$h = (Get-Process -Name NyaLauncher | Where-Object { $_.MainWindowTitle -match "游戏窗口" } | Select-Object -First 1).MainWindowHandle
[NyaDrive]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 700

foreach ($code in $Codes.Split(" ")) {
    if ($code.Trim().Length -eq 0) { continue }
    $vk = [Convert]::ToByte($code.Trim(), 16)
    [NyaDrive]::keybd_event($vk, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 70
    [NyaDrive]::keybd_event($vk, 0, 2, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 450
}

foreach ($pair in $Clicks.Split(" ")) {
    if ($pair.Trim().Length -eq 0) { continue }
    $xy = $pair.Trim().Split(",")
    $x = [int]$xy[0]; $y = [int]$xy[1]
    [NyaDrive]::SetCursorPos($x - 12, $y) | Out-Null
    Start-Sleep -Milliseconds 260
    [NyaDrive]::mouse_event(0x0001, 2, 0, 0, [IntPtr]::Zero)   # MOUSEMOVE，唤醒游戏悬停判定
    Start-Sleep -Milliseconds 70
    [NyaDrive]::mouse_event(0x0001, 0, 2, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 70
    [NyaDrive]::SetCursorPos($x, $y) | Out-Null
    Start-Sleep -Milliseconds 260
    [NyaDrive]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)   # left down
    Start-Sleep -Milliseconds 130
    [NyaDrive]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)   # left up
    Start-Sleep -Milliseconds 800
}
Start-Sleep -Milliseconds 1100

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
$bmp.Save($Out)
Write-Output ("SAVED " + $Out)
