param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [int]$秒数 = 12,
    [int]$间隔毫秒 = 400,
    [string]$前缀 = "连拍",
    # 只存这块区域（"x,y,宽,高"）。不填存整屏。
    # 连续动作的中间态往往只在一小块里（拖拽代理跟着光标），裁掉能省两个数量级。
    [string]$Crop = ""
)

# **连拍**：按固定间隔连拍一串，用来抓"手一动就没了"的中间态。
#
# 为什么要有它：`抓原版拖拽.ps1` 用**合成鼠标**驱动拖拽，实测**起不来**
# （2026-09-22：按下、移动、悬停更新都正常 —— 点一下能弹物品菜单、
#   移过去能出提示框，但拖拽代理始终不出现；怀疑 Flash 对合成 MOVE 的判定，未定论）。
# 既然合成驱动不了，就改成"**人来拖、机器连拍**"：这个工具负责连拍，
# 用户在这几秒里手动拖一次，事后从这串图里挑出代理可见的那一张。
#
# 用法：
#   PowerShell -File 开发工具/抓原版连拍.ps1 -OutDir 测试/截图/拖拽穿装备/原版 -秒数 12
#   然后在这 12 秒内：在原版里把背包里那件武器拖到人物面板的武器格上方**按住别松**。
#
# 坑与 `抓原版批量.ps1` 一样：必须 SetProcessDPIAware()，否则截出来只有 2048x1152、右下是缺的。

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class NyaBurst {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

[NyaBurst]::SetProcessDPIAware() | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$总张数 = [int]($秒数 * 1000 / $间隔毫秒)
Write-Output ("开始连拍：$总张数 张，每 $间隔毫秒 毫秒一张，共约 $秒数 秒 —— 现在开始拖！")

$屏 = [System.Windows.Forms.SystemInformation]::VirtualScreen
for ($i = 1; $i -le $总张数; $i++) {
    $全 = New-Object System.Drawing.Bitmap $屏.Width, $屏.Height
    $g = [System.Drawing.Graphics]::FromImage($全)
    $g.CopyFromScreen($屏.Left, $屏.Top, 0, 0, $全.Size)
    $名 = "{0}_{1:d3}.png" -f $前缀, $i
    $路径 = Join-Path $OutDir $名
    if ($Crop.Trim().Length -gt 0) {
        $c = $Crop.Split(",")
        $矩形 = New-Object System.Drawing.Rectangle ([int]$c[0]), ([int]$c[1]), ([int]$c[2]), ([int]$c[3])
        $块 = $全.Clone($矩形, $全.PixelFormat)
        $块.Save($路径)
        $块.Dispose()
    } else {
        $全.Save($路径)
    }
    $g.Dispose(); $全.Dispose()
    Start-Sleep -Milliseconds $间隔毫秒
}

Write-Output ("DONE 共 $总张数 张 → " + $OutDir)
