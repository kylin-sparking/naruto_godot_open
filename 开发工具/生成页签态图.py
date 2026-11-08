# -*- coding: utf-8 -*-
"""设置页四枚页签（`MTabButton`）的交互态皮：`页签未选.png` → `_悬停.png` / `_按下.png`。

为什么需要这一步（2026-09-30 用户问「快捷键 tab 按钮为什么没有按下的状态」）：
`MTabButton.as:16-32 updateState()` **换的不是图，是滤镜** ——
皮永远只有 `_selected ? selectedUpSkin : upSkin` 这两张，over/down 靠
`StyleUtil.getLightFilter(skinFilters[_state])` 在**同一张皮**上加/减亮度
（`StyleUtil.as:7-12` up 0 / over +30 / down −40）。
Godot 的 `TextureButton` 没有"运行时给贴图加色矩阵"这条挂法（只有 `texture_hover/pressed` 换图），
⇒ 要么上 shader、要么**把派生态预先烘成图**。工程既有口径是烘图（底栏十钮 =
`开发工具/生成底栏钮态图.py`），这里沿用同一份公式 `开发工具/派生钮态.py`。

早先 `生成设置场景.py` 把 `texture_hover/texture_pressed` 直接挂成和 `texture_normal`
同一张「页签未选」⇒ 悬停、按下**零变化**，就是用户看到的"没有按下态"。

选中那一枚不用派生：原版 `MTabButton.as:34-38` `set enabled(v){ selected = !v }` ⇒ 选中枚
`enabled=false`，`updateState()` 走 `_state == STATE_DISABLED` 分支、滤镜取 `skinFilters[STATE_UP]` = 0
⇒ **选中枚既不吃鼠标也不加亮**，只显示未加亮的 `selectedUpSkin`（tag 538）。移植侧同义：
`disabled = true` + `texture_disabled = 页签选中.png`（不加派生）。

用法：python 开发工具/生成页签态图.py
     → Godot --path . --headless --import → python 开发工具/生成设置场景.py → 跑设置页门
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 派生钮态 import 派生

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚠️ 原来写死作者机的 naruto_godot；改成从本文件反推，见 §合并说明
未选 = os.path.join(项目, "素材", "界面", "原版窗口", "设置", "页签未选.png")

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    for 落, 尺, 偏移 in 派生(未选):
        print("   %s ← 页签未选（%dx%d，clamp(rgb%+d)，逐字节自检过）"
              % (os.path.basename(落), 尺[0], 尺[1], 偏移))
    print("页签态皮：%d 张（选中枚不派生 —— 原版 DISABLED 档滤镜是 0）" % 2)
