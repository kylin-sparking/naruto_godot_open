param(
    # 符号 id（用 读符号时间轴.py --列符号 或 --查类名 查）
    [Parameter(Mandatory = $true)][int]$符号,
    # 输出目录（会建）
    [Parameter(Mandatory = $true)][string]$出,
    # 新文件名（不含扩展名）。不填就用 ffdec 给的符号名
    [string]$名 = "",
    # 素材包。默认 MainLib；别的包见 读符号时间轴.py 的 --源
    [string]$Swf = "www/act_web_nya_208_isolated/asset/MainLib.swf"
)

# **按符号 id 导出单张素材** —— 补上 ffdec-cli 表面上看不到的那个用法。
#
# 为什么需要它：`ffdec-cli -help export` 只列了 `-export <itemtypes> <出> <入>`，
# 看起来只能**整包全导**（MainLib 几千个符号，几十分钟 + 几个 GB）。
# 但 `-selectid <id>` 是个**前置选项**，加上它就只导那一个符号 ——
# 实测导出 LockedIcon(724) 用了 **0.9 秒**（2026-09-22）。
#
# 之前因为"以为导不了单个符号"，绑定锁一直欠着（§3.18.5）；其实一直可以。
#
# 用法：
#   PowerShell -File 开发工具/导出原版符号.ps1 -符号 724 `
#       -出 "素材/界面/原版窗口/通用控件" -名 绑定锁
#
# ⚠️ 导出来的是**作者期第 1 帧**的扁平图（§0.0c 红线的适用范围）：
#   单帧静态符号（就是本工具主要的用途）作者期 == 运行时；
#   **多帧/带动画/带脚本的符号不要拿它当外观依据**，那种要驱动原版截图。

$ErrorActionPreference = "Stop"
$游戏根 = if ($env:NARUTO_GAME_ROOT) { $env:NARUTO_GAME_ROOT } else { "2.2.3" }
# ffdec 不在游戏根里也能跑：`NARUTO_FFDEC` 指到 exe 或它所在目录优先，
# 其次才找旧约定 `<游戏根>\ffdec_26.2.1\ffdec-cli.exe`（本机实装的是 ffdec）。
$ffdec = ""
if ($env:NARUTO_FFDEC) {
    $ffdec = $env:NARUTO_FFDEC
    if (Test-Path $ffdec -PathType Container) { $ffdec = Join-Path $ffdec "ffdec-cli.exe" }
}
# ⚠ `Test-Path ""` 在 PowerShell 里是**报错**（ParameterArgumentValidationError），不是返回 false
#   ⇒ 每个候选都要先判非空再试（2026-10-14 第一次跑就撞在这）。
function 有($路) { return ($路 -ne "" -and $null -ne $路) -and (Test-Path $路) }
if (-not (有 $ffdec)) { $ffdec = Join-Path $游戏根 "ffdec_26.2.1\ffdec-cli.exe" }
if (-not (有 $ffdec)) { $ffdec = "ffdec\ffdec-cli.exe" }
if (-not (有 $ffdec)) { Write-Error "找不到 ffdec-cli（试过 NARUTO_FFDEC、$游戏根\ffdec_26.2.1、ffdec）"; exit 1 }
$swf路径 = Join-Path $游戏根 $Swf
if (-not (Test-Path $swf路径)) { Write-Error "找不到素材包：$swf路径"; exit 1 }

# ffdec 会把结果放进 <临时目录>\DefineSprite_<id>_<符号名>_<类名>\1.png
$临时 = Join-Path $游戏根 ".export_scratch\symbol_$符号"
if (Test-Path $临时) { Remove-Item -Recurse -Force $临时 }
New-Item -ItemType Directory -Force -Path $临时 | Out-Null

& $ffdec -selectid $符号 -export sprite $临时 $swf路径 | Write-Output

$图 = Get-ChildItem -Path $临时 -Recurse -Filter "*.png" | Select-Object -First 1
if (-not $图) { Write-Error "ffdec 没吐出 PNG（符号 $符号 可能不是 sprite）"; exit 1 }

if ($名.Trim().Length -eq 0) {
    $名 = ($图.Directory.Name -split "_")[2]
}
New-Item -ItemType Directory -Force -Path $出 | Out-Null
$目标 = Join-Path $出 ("$名.png")
Copy-Item $图.FullName $目标 -Force
Write-Output ("OK 符号 $符号 → $目标 (" + $图.Length + " 字节)")
