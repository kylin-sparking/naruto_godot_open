# -*- coding: utf-8 -*-
"""窗口关钮 `MWindowCloseBtnF`（元件 7，25×24）的交互态皮 —— 每一扇原版窗右上角那颗 X。

现查（2026-10-19 晚）：
  * `MWindowCloseBtnF.as` = `public dynamic class MWindowCloseBtnF extends MButton3`（symbol7）
    ⇒ **和挂机页那 27 枚勾同一族**：一组只有一张皮，悬停/按下靠运行时加性滤镜，
    不是 `MButton` 那种每态一张独立 skin。
  * `StyleUtil.as:7-12` up 0 / over **+30** / down **−40**；`:43-47` 逐通道 clamp、alpha 行不动。
  * `MButton3.init()` `:135` ⇒ 手型光标。
  * 工程现状：`场景/界面/功能窗口.tscn` 里那颗 X 是 `Button` + `icon = 关闭按钮.png` +
    五档样式全 `StyleBoxEmpty` ⇒ **四个状态画的是同一张图**，一点反馈都没有
    （用户 10-19 那句「你做的没有点击效果，很死板」在这一颗上完全成立）。
    主题里也没有 `Button/icon_*_modulate` 覆盖 ⇒ 连"错的反馈"都没有。

公式只有一份：`开发工具/派生钮态.py`（和底栏十钮、页签、首领钮、复选框同一份）。

用法：`python 开发工具/生成关钮态图.py` → `Godot --path . --headless --import` → 跑关钮量具
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 派生钮态 import 派生

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
基 = os.path.join(工程, "素材", "界面", "原版窗口", "通用控件")

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    源 = os.path.join(基, "关闭按钮.png")
    总 = 0
    for 落, 尺, 偏移 in 派生(源):
        总 += 1
        print("   %-24s <- 关闭按钮（%dx%d，clamp(rgb%+d)）" % (
                os.path.basename(落), 尺[0], 尺[1], 偏移))
    print("关钮交互态皮：%d 张（逐字节等于公式，自检过）" % 总)
