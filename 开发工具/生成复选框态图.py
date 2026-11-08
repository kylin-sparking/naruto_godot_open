# -*- coding: utf-8 -*-
"""挂机页那 25 枚勾（`复选框未选.png` / `复选框选中.png`）的交互态皮。

为什么要它（用户 2026-10-19 实机打回「你做的挂机页没有点击交互性，原版点什么都没反应是很死板」）：
`MCheckBoxF` → `MCheckBox` → **`MButton3`**（`MCheckBox.as:6`），也就是「一组只有一张皮、
悬停/按下靠运行时加性滤镜」那一族，不是 `MButton` 那种「每态一张独立 skin」：

| 档 | 真值 | 出处 |
|---|---|---|
| up | 滤镜 0 | `StyleUtil.as:7-12` `skinFilters = {up:0, over:30, down:-40}` |
| over | R/G/B 各 +30（加性、逐通道 clamp、alpha 行 `0,0,0,1,0` 不动 alpha） | `StyleUtil.as:43-47` `getLightFilter` |
| down | 各 −40 | 同上 |
| disabled | **灰度矩阵**（0.3086/0.6094/0.082），不是减亮度 | `MButton3.as:333` + `StyleUtil.as:24-28` |
| 挂在谁身上 | 只挂在 `_selected ? selectedUpSkin : upSkin` **那一个** DisplayObject | `MButton3.as:341-345` |

⇒ 需要 未选/选中 × 悬停/按下/灰 = **6 张**派生皮（选中那一枚不是「不加亮的 selectedUpSkin」：
`MButton3.as:136-142` 只在 `selectedUpSkin == null` 时回落成 upSkin，而 `MCheckBoxF` 的库里
两张皮都有 ⇒ 选中态照样吃 ±30/−40）。

**文字不换色**（这一条是这条链上最容易自己加戏的地方）：`GuaJiSettingWindow.as:719-731`
`createCheckBox` 用的是 `MButton3.as:444-451` 那个 `textColor` 设器 —— 它把
up/over/down/disabled **四档写成同一个数**（本窗 param4 缺省 2003199 = #1E90FF）
⇒ 原版悬停、按下时**只有方框变亮变暗，文字一个像素都不动**。别照 `MButton3` 的
`_textColors` 默认四档去换色。

公式只有一份：`开发工具/派生钮态.py`（和底栏十钮、页签、首领钮同一份）。

用法：`python 开发工具/生成复选框态图.py` → `Godot --path . --headless --import` → 跑挂机窗门
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 派生钮态 import 派生

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
基 = os.path.join(工程, "素材", "界面", "原版窗口", "通用控件")
态表 = (("悬停", 30), ("按下", -40), ("灰", None))

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    总 = 0
    for 名 in ["复选框未选", "复选框选中"]:
        源 = os.path.join(基, 名 + ".png")
        for 落, 尺, 偏移 in 派生(源, 态表=态表):
            总 += 1
            print("   %-24s <- %s（%dx%d，%s）" % (
                    os.path.basename(落), 名, 尺[0], 尺[1],
                    "getGrayFilter" if 偏移 is None else "clamp(rgb%+d)" % 偏移))
    print("复选框交互态皮：%d 张（每张都逐字节等于公式，自检过）" % 总)
