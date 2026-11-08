param(
    # 步骤表：用 ";" 分隔多步，每步是
    #   "<名字>|<按键(空格分隔十六进制VK)>|<点击(空格分隔 x,y)>|<是否先重置 1/0>"
    #   点击写成 x,y 是左键；r 前缀（r876,1268）是右键；m 前缀（m876,1268）只把光标停上去
    #   不点 —— 取悬停提示框必须用 m，左键点下去会先选中/起拖，画面就不是纯悬停态了。
    # 例：-Steps "其他忍术||675,1308 1000,523|1;格0|1B 1B|675,1308 1000,523 833,583|1"
    # 每步开始时先（可选）补发按键再依次点击，步末截一张图。
    [string]$Steps = "",
    # 步骤表放在文件里（UTF-8）。步骤一多，从命令行传中文字符串会被代码页吃掉，
    # 走文件最稳。
    [string]$StepsFile = "",
    [Parameter(Mandatory = $true)][string]$OutDir,
    # 每步开始前是否重置（Esc Esc 关掉所有窗口再重新打开）
    [string]$ResetCodes = "1B 1B",
    [string]$ResetClick = "",
    # 只存这块区域（"x,y,宽,高"）。不填存整屏。点格子时详情区只有几百像素宽，
    # 存整屏一张 5MB、66 张就是 330MB，裁掉能省两个数量级。
    [string]$Crop = "",
    [switch]$NoReset
)

# 一次跑完多步、每步一图的批量驱动。
#
# 为什么要有它：逐步跑 抓原版游戏窗口.ps1 会让用户为每一张图让出一次电脑，
# 而这项工作天然是"一个页签点十几格"。合并成一次调用，用户只需要让出一次。
#
# 坑与 抓原版游戏窗口.ps1 完全一样（那份注释更全）：
#   1. 必须 SetProcessDPIAware()，否则截出来只有 2048x1152、右下是缺的
#   2. 点击前必须先发 MOUSEMOVE，否则点击穿到地图上让角色走路
#   3. 本文件必须带 UTF-8 BOM

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class NyaBatch {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
}
'@

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

[NyaBatch]::SetProcessDPIAware() | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$hwnd = (Get-Process -Name NyaLauncher |
    Where-Object { $_.MainWindowTitle -match "游戏窗口" } |
    Select-Object -First 1).MainWindowHandle
if (-not $hwnd) { Write-Error "找不到原版游戏窗口（NyaLauncher / 游戏窗口）"; exit 1 }

function Send-Codes([string]$codes) {
    foreach ($code in $codes.Split(" ")) {
        if ($code.Trim().Length -eq 0) { continue }
        $vk = [Convert]::ToByte($code.Trim(), 16)
        [NyaBatch]::keybd_event($vk, 0, 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 70
        [NyaBatch]::keybd_event($vk, 0, 2, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 450
    }
}

function Send-Click([int]$x, [int]$y, [string]$btn = "L") {
    # $btn = "L" 左键（0x0002/0x0004）、"R" 右键（0x0008/0x0010）、"M" 只悬停不点。
    [NyaBatch]::SetCursorPos($x - 12, $y) | Out-Null
    Start-Sleep -Milliseconds 260
    [NyaBatch]::mouse_event(0x0001, 2, 0, 0, [IntPtr]::Zero)   # MOUSEMOVE，唤醒游戏悬停判定
    Start-Sleep -Milliseconds 70
    [NyaBatch]::mouse_event(0x0001, 0, 2, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 70
    [NyaBatch]::SetCursorPos($x, $y) | Out-Null
    Start-Sleep -Milliseconds 320
    if ($btn -eq "M") {
        # 只把光标停在上面。⚠️ SetCursorPos 之后还要再补真实的 MOUSEMOVE：
        # 上一版只 SetCursorPos 就等，实测**不弹悬停提示**（Flash 的 MOUSE_OVER 没被叫醒）。
        [NyaBatch]::mouse_event(0x0001, 3, 0, 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 120
        [NyaBatch]::mouse_event(0x0001, -3, 0, 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 1500
        return
    }
    if ($btn -eq "R") {
        [NyaBatch]::mouse_event(0x0008, 0, 0, 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 130
        [NyaBatch]::mouse_event(0x0010, 0, 0, 0, [IntPtr]::Zero)
    } else {
        [NyaBatch]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 130
        [NyaBatch]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
    }
    Start-Sleep -Milliseconds 700
}

# **抢前台** —— 2026-09-23 补。这一条是从 `抓原版拖拽.ps1` 搬过来的：
# 原来这里只有一句 `SetForegroundWindow`，而**从后台进程调它会被 Windows 的前台锁定挡掉**，
# 于是"点了精炼页签"的那一次：截出来的是 PyCharm、点击也全打给了 PyCharm
# （§3.16.9 记的同一个坑，第二次栽 —— 那次修的是拖拽工具，这个批量工具漏改了）。
# 可靠的做法是 `AttachThreadInput`：把自己线程的输入队列临时挂到当前前台线程上，
# 本进程就被当成"有输入活动"，`SetForegroundWindow` 才会被放行。
function 抢前台([IntPtr]$h) {
    for ($i = 0; $i -lt 20; $i++) {
        if ([NyaBatch]::GetForegroundWindow() -eq $h) { return $true }
        $前台 = [NyaBatch]::GetForegroundWindow()
        $前台线程 = [NyaBatch]::GetWindowThreadProcessId($前台, [IntPtr]::Zero)
        $本线程 = [NyaBatch]::GetCurrentThreadId()
        if ([NyaBatch]::IsIconic($h)) { [NyaBatch]::ShowWindow($h, 9) | Out-Null }   # SW_RESTORE
        [void][NyaBatch]::AttachThreadInput($本线程, $前台线程, $true)
        [void][NyaBatch]::BringWindowToTop($h)
        [void][NyaBatch]::SetForegroundWindow($h)
        [void][NyaBatch]::AttachThreadInput($本线程, $前台线程, $false)
        Start-Sleep -Milliseconds 250
    }
    return ([NyaBatch]::GetForegroundWindow() -eq $h)
}

$script:游戏窗口 = $hwnd

function Save-Shot([string]$name) {
    # ⚠️ **每次截图前复验前台**，不在就中止 —— 只在这一批开始时抢一次是不够的，
    # 别的窗口会抢回去；那样拍出来的图里根本没有游戏，而事后看图的人会当成"原版就这样"。
    if ([NyaBatch]::GetForegroundWindow() -ne $script:游戏窗口) {
        Write-Error "截图前发现游戏不在前台（前台是别的窗口）—— 拍下去就是错的，已中止。请手动把游戏窗口点到最前面再跑。"
        exit 4
    }
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $full = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($full)
    $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $full.Size)
    $target = Join-Path $OutDir ($name + ".png")
    if ($Crop.Trim().Length -gt 0) {
        $c = $Crop.Split(",")
        $rect = New-Object System.Drawing.Rectangle ([int]$c[0]), ([int]$c[1]), ([int]$c[2]), ([int]$c[3])
        $piece = $full.Clone($rect, $full.PixelFormat)
        $piece.Save($target)
        $piece.Dispose()
    } else {
        $full.Save($target)
    }
    $g.Dispose(); $full.Dispose()
    Write-Output ("SAVED " + $target)
}

if ($StepsFile.Trim().Length -gt 0) {
    $Steps = [System.IO.File]::ReadAllText($StepsFile, [System.Text.Encoding]::UTF8)
}
if ($Steps.Trim().Length -eq 0) { Write-Error "没有步骤（-Steps 或 -StepsFile）"; exit 1 }

if (-not (抢前台 $hwnd)) {
    Write-Error "抢不到游戏窗口前台（现在前台是别的窗口）—— 合成鼠标会打到那边去，已中止。请手动把游戏窗口点到最前面再跑。"
    exit 2
}
Start-Sleep -Milliseconds 700

# 先截一张起点图，便于事后核对窗口有没有被挪过（底栏坐标随窗口位置变）
Save-Shot "_起始"

foreach ($step in $Steps.Split(";")) {
    if ($step.Trim().Length -eq 0) { continue }
    $parts = $step.Split("|")
    $name = $parts[0].Trim()
    $doReset = -not $NoReset
    if ($parts.Count -gt 3 -and $parts[3].Trim() -eq "0") { $doReset = $false }
    if ($doReset) {
        Send-Codes $ResetCodes
        if ($ResetClick.Trim().Length -gt 0) {
            foreach ($pair in $ResetClick.Split(" ")) {
                $tok = $pair.Trim()
                $btn = "L"
                if ($tok.StartsWith("r")) { $btn = "R"; $tok = $tok.Substring(1) }
                elseif ($tok.StartsWith("m")) { $btn = "M"; $tok = $tok.Substring(1) }
                $xy = $tok.Split(",")
                Send-Click ([int]$xy[0]) ([int]$xy[1]) $btn
            }
        }
    }
    if ($parts.Count -gt 1 -and $parts[1].Trim().Length -gt 0) { Send-Codes $parts[1] }
    if ($parts.Count -gt 2 -and $parts[2].Trim().Length -gt 0) {
        foreach ($pair in $parts[2].Split(" ")) {
            $tok = $pair.Trim()
            if ($tok.Length -eq 0) { continue }
            $btn = "L"
            if ($tok.StartsWith("r")) { $btn = "R"; $tok = $tok.Substring(1) }
            elseif ($tok.StartsWith("m")) { $btn = "M"; $tok = $tok.Substring(1) }
            $xy = $tok.Split(",")
            Send-Click ([int]$xy[0]) ([int]$xy[1]) $btn
        }
    }
    Start-Sleep -Milliseconds 900
    Save-Shot $name
}

Write-Output "DONE"
