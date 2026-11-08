param(
    [string]$Godot = "godot",
    [switch]$含像素基线
)

# 窗口层那两道**有头**的门。
#
# 为什么不并进 `验证全部.ps1`：那边整套是无头跑的，而这里两件都要真视口 ——
#   无头模式下根视口只有 64x64，既截不了图，窗口钳制/居中也会失真。
#
# ⚠️ 改了 `场景/地图/地图场景.tscn` 的**结构**（不是脚本）之后，168 张烘焙图必须重烤：
#   Godot --headless --path . --script res://开发工具/烘焙当前地图.gd -- --all
#   运行时加载的是 `场景/生成/地图_<id>_烘焙.tscn`，不是源场景。

$ErrorActionPreference = "Stop"
$clientRoot = Split-Path -Parent $PSScriptRoot

# ① 真实鼠标走查（点底栏开关、拖标题栏、点被盖住的窗）
& $Godot --path $clientRoot --script "res://开发工具/窗口走查.gd" -- "--出目录=测试/截图/窗口走查"
if ($LASTEXITCODE -ne 0) { throw "Walkthrough failed: 窗口走查.gd" }
Write-Host "窗口走查 通过"

# ② 像素基线比对。**默认不跑**：它是**诊断工具**不是断言工具 ——
#    基线里是原版玩家的背包内容（一堆礼盒、标题 背包(21/30)），和我们背包里的东西不同，
#    内容差异天然占大头。它只有在"人想看看某页和原版差在哪"时才该跑。
#    退出码只对三种方法论失败（配准不可信 / 基线装不下整窗 / 尺度不是 1.00）为 1。
if ($含像素基线) {
    $页们 = @(
        @("背包", "测试/基线/原版界面/原版_背包.png"),
        @("人物", "测试/基线/原版界面/原版_人物面板.png"),
        @("忍术", "测试/基线/原版界面/原版_忍术.png")
    )
    foreach ($项 in $页们) {
        & $Godot --path $clientRoot --script "res://开发工具/窗口像素基线.gd" -- `
            "--页=$($项[0])" "--基线=$($项[1])" "--出目录=测试/差异/窗口基线"
        if ($LASTEXITCODE -ne 0) { throw "Pixel baseline methodology failed: $($项[0])" }
        Write-Host "像素基线 $($项[0]) 出报告（看 测试/差异/窗口基线/）"
    }
}

Write-Host "Headed window suite passed."
