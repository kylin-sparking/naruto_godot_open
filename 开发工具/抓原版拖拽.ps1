param(
    # 源格中心，形如 "1602,607"
    [Parameter(Mandatory = $true)][string]$源,
    # 拖到哪儿（截"拖拽中"那一张时光标停的地方），形如 "1127,725"
    [Parameter(Mandatory = $true)][string]$目标,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$前缀 = "原版拖拽",
    # 松手点。**默认 = 源格自己** —— 原版 `ItemWindow2.onItemUp` 对"放回原格"是
    # no-op（`dragData.position == _loc3_` → 只 removeDragData），
    # 所以这样截完**不改变玩家的背包和装备**，是为对证图取证的最小副作用做法。
    [string]$松手 = "",
    # 只存这块区域（"x,y,宽,高"）。不填存整屏。
    [string]$Crop = "",
    [int]$等待毫秒 = 550
)

# 抓"原版**拖拽过程中**"的画面 —— 这是 `抓原版批量.ps1` 做不到的：
# 那个工具的每一步都以"按下去再弹起来"收尾，而拖拽代理只在**按住不放**时才存在。
#
# 为什么要这个：§0.0c 红线②要求每个改动配"客户端 vs 原版并排图"，
# 而拖拽预览是"只有拖到一半才看得见"的东西 —— 落地时只能靠读源码
# （`DragManager.as:137-155`：只复制图标、alpha = 0.5、居中在光标下），
# 没有跑着的原版图作证。这个工具就是补那张图。
#
# 与 `抓原版批量.ps1` 同样的三个坑：
#   1. 必须 SetProcessDPIAware()，否则截出来只有 2048x1152、右下是缺的
#   2. 移动前必须先发 MOUSEMOVE，否则只 SetCursorPos 不触发 Flash 的悬停/拖拽判定
#   3. 本文件必须带 UTF-8 BOM
#
# 用法：
#   PowerShell -File 开发工具/抓原版拖拽.ps1 -源 "1602,607" -目标 "1127,725" `
#       -OutDir 测试/截图/拖拽穿装备/原版 -Crop "1050,480,1200,850"

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class NyaDrag {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, IntPtr e);
  // 必须 `out`，不能 `[In, Out]` —— 值结构按值传进去拿不回结果，
  // 会得到全 0 的矩形，于是**任何坐标都判定成"不在窗口里"**（守卫直接误报）。
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out NyaRect r);
}
public struct NyaRect { public int L, T, Rt, B; }
'@

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

[NyaDrag]::SetProcessDPIAware() | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$hwnd = (Get-Process -Name NyaLauncher -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -match "游戏窗口" } |
    Select-Object -First 1).MainWindowHandle
if (-not $hwnd) { Write-Error "找不到原版游戏窗口（NyaLauncher / 游戏窗口）"; exit 1 }

function 解析([string]$点) {
    $xy = $点.Split(",")
    return @([int]$xy[0], [int]$xy[1])
}

# 把光标挪到 (x,y)，并补发真实的 MOUSEMOVE —— 只 SetCursorPos 不足以唤醒 Flash。
function 挪到([int]$x, [int]$y) {
    [NyaDrag]::SetCursorPos($x - 12, $y) | Out-Null
    Start-Sleep -Milliseconds 60
    [NyaDrag]::mouse_event(0x0001, 2, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [NyaDrag]::mouse_event(0x0001, 0, 2, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [NyaDrag]::SetCursorPos($x, $y) | Out-Null
}

# **按下之后先原地抖几下**，别急着往目标冲。
# 原版起拖的判据是 `downCell.addEventListener(MSpriteEvent.MSPRITE_MOVE, onItemMove)`
# （`ItemWindow2.as:1249-1255`）—— 也就是说**必须有一条 MOUSE_MOVE 落在那个格子自己身上**
# 才会 `createDragDataProxy`。而 Flash 的 MOUSE_MOVE 只派发给**指针底下**的那个对象：
# 一按下去就往目标大步跳（第一版每步跨 52px，格子只有 41px 宽），
# 指针头一下就出了格子 → 格子永远收不到 MOVE → **代理根本不出现**（2026-09-22 实测）。
function 抖一下([int]$x, [int]$y) {
    foreach ($偏移 in @(@(-4, 0), @(4, 0), @(0, -4), @(0, 4), @(0, 0))) {
        [NyaDrag]::SetCursorPos($x + $偏移[0], $y + $偏移[1]) | Out-Null
        [NyaDrag]::mouse_event(0x0001, $偏移[0], $偏移[1], 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 90
    }
}

# 从一点平滑拖到另一点（分成若干小步发 MOUSEMOVE）。
# ⚠️ Flash 的拖拽要靠**连续的 MOVE 事件**维持，一步跳过去有可能只当成一次瞬移。
function 拖到([int]$x0, [int]$y0, [int]$x1, [int]$y1, [int]$步数 = 12) {
    for ($i = 1; $i -le $步数; $i++) {
        $x = [int]($x0 + ($x1 - $x0) * $i / $步数)
        $y = [int]($y0 + ($y1 - $y0) * $i / $步数)
        [NyaDrag]::SetCursorPos($x, $y) | Out-Null
        [NyaDrag]::mouse_event(0x0001, 1, 1, 0, [IntPtr]::Zero)
        Start-Sleep -Milliseconds 45
    }
}

# 每次存图前**再确认一次游戏还在前台**。中途被人抢走前台的话，
# 截下来的是别的窗口、后面的合成事件也全打错地方 —— 那样得到的"拖拽起不来"
# 是**假结论**（2026-09-22 就这么白跑过两轮）。宁可中止，不要留一张会骗人的图。
function 存图([string]$名字) {
    # 被抢走前台就**先再抢一次**（别的进程偶尔会蹦到前面），抢不回来才中止
    if ([NyaDrag]::GetForegroundWindow() -ne $hwnd -and -not (抢前台 $hwnd)) {
        Write-Error ("截图‘" + $名字 + "’时游戏窗口不在前台、也抢不回来，后面的都不可信，已中止。")
        exit 2
    }
    Start-Sleep -Milliseconds 120
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $全 = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($全)
    $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $全.Size)
    $目标路径 = Join-Path $OutDir ($前缀 + "_" + $名字 + ".png")
    if ($Crop.Trim().Length -gt 0) {
        $c = $Crop.Split(",")
        $矩形 = New-Object System.Drawing.Rectangle ([int]$c[0]), ([int]$c[1]), ([int]$c[2]), ([int]$c[3])
        $块 = $全.Clone($矩形, $全.PixelFormat)
        $块.Save($目标路径)
        $块.Dispose()
    } else {
        $全.Save($目标路径)
    }
    $g.Dispose(); $全.Dispose()
    Write-Output ("SAVED " + $目标路径)
}

$S = 解析 $源
$T = 解析 $目标

# **坐标必须落在游戏窗口内**，否则合成事件打给别的窗口、截出来是别人的画面。
# 2026-09-22 真栽过：上一轮量的坐标是按窗口在 (477,47)-(2385,1373) 时算的，
# 下一轮窗口已经被挪到 (222,226)-(1200,1055)，于是"拖拽中"那张截的是 PyCharm。
# §3.12.3 早就写了"原版窗口位置会漂，每轮重量" —— 这条守卫就是那次教训的落点。
function 校验在窗内([int]$x, [int]$y, [string]$是谁) {
    $r = New-Object NyaRect
    [void][NyaDrag]::GetWindowRect($hwnd, [ref]$r)
    if ($x -lt $r.L -or $x -gt $r.Rt -or $y -lt $r.T -or $y -gt $r.B) {
        Write-Error ("$是谁 ($x,$y) 不在游戏窗口 (${r.L},${r.T})-(${r.Rt},${r.B}) 里 —— 窗口挪过了，坐标要重量。已中止。")
        exit 3
    }
}
校验在窗内 $S[0] $S[1] "源格"
校验在窗内 $T[0] $T[1] "目标点"
if ($松手.Trim().Length -eq 0) { $松手 = $源 }
$R = 解析 $松手

# **一定要确认游戏真的在前台，否则合成事件全打给别的窗口**（2026-09-22 真栽过：
# 一次跑下来 PyCharm 的"随处搜索"在最前面，按键全进了 PyCharm，
# 截出来的"拖拽中"里根本没有游戏 —— 差点又得出一个错误的"拖拽起不来"结论）。
#
# `SetForegroundWindow` 从后台进程调用**会被 Windows 的前台锁定挡掉** ——
# 光加 ALT 那一招实测**不够**（PyCharm 一直占着前台，抢不动）。
# 可靠的做法是 `AttachThreadInput`：把自己线程的输入队列临时挂到**当前前台线程**上，
# 这样本进程就被当成"有输入活动"，`SetForegroundWindow` 才会被放行。
function 抢前台([IntPtr]$h) {
    for ($i = 0; $i -lt 20; $i++) {
        if ([NyaDrag]::GetForegroundWindow() -eq $h) { return $true }
        $前台 = [NyaDrag]::GetForegroundWindow()
        $前台线程 = [NyaDrag]::GetWindowThreadProcessId($前台, [IntPtr]::Zero)
        $本线程 = [NyaDrag]::GetCurrentThreadId()
        if ([NyaDrag]::IsIconic($h)) { [NyaDrag]::ShowWindow($h, 9) | Out-Null }   # SW_RESTORE
        [void][NyaDrag]::AttachThreadInput($本线程, $前台线程, $true)
        [void][NyaDrag]::BringWindowToTop($h)
        [void][NyaDrag]::SetForegroundWindow($h)
        [void][NyaDrag]::AttachThreadInput($本线程, $前台线程, $false)
        Start-Sleep -Milliseconds 250
    }
    return ([NyaDrag]::GetForegroundWindow() -eq $h)
}

if (-not (抢前台 $hwnd)) {
    Write-Error "抢不到游戏窗口前台（现在前台是别的窗口）—— 合成鼠标会打到那边去，已中止。请手动把游戏窗口点到最前面再跑。"
    exit 2
}
Start-Sleep -Milliseconds 600

存图 "0起始"

# 1. 悬停到源格（先不按），让格子进悬停态
挪到 $S[0] $S[1]
Start-Sleep -Milliseconds $等待毫秒

# 2. 按下不放
[NyaDrag]::mouse_event(0x0002, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 200
存图 "1按下"

# 2b. **在格子里抖几下**把代理叫出来（见 `抖一下` 的注释：这是起拖的必要条件）
抖一下 $S[0] $S[1]
Start-Sleep -Milliseconds 150
存图 "1b起拖"

# 3. 按住拖到目标 —— **这一张就是"拖拽中"**
拖到 $S[0] $S[1] $T[0] $T[1]
Start-Sleep -Milliseconds $等待毫秒
存图 "2拖拽中"

# 4. 拖回松手点再放 —— 默认放回源格，原版视作 no-op，不留副作用
拖到 $T[0] $T[1] $R[0] $R[1]
Start-Sleep -Milliseconds 200
[NyaDrag]::mouse_event(0x0004, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds $等待毫秒
存图 "3松手后"

Write-Output "DONE"
