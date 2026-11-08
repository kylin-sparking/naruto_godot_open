# -*- coding: utf-8 -*-
"""原版标准钮 `MButtonF`（元件 21）的交互态皮 —— 工程里所有走主题 `Button` 族的换皮件。

现查（2026-10-20 晚，用户报「右页的按钮点击没有反馈 没有点击效果」）：
  * `MButtonF.as`（脚本根 `MButtonF.as:6`）= `public dynamic class MButtonF extends MButton3`
    **只有构造函数，没有任何覆盖** ⇒ 与关钮/加减钮/复选框同一族：
    **一组只有一张 upSkin，悬停/按下是运行时加性滤镜**，不是每态一张独立 skin。
  * 时间轴：`upSkin = tag18 MButton_up`（工程 `通用控件/按钮.png` 就是这份美术），
    `selectedUpSkin = tag15`（工程 `按钮按下.png`）—— **它是"选中皮"，不是"按下皮"**，
    原来却把它接在主题的 `pressed` 槽上。
  * `StyleUtil.as:7-12` up 0 / over **+30** / down **−40**；`:43-47` 逐通道 clamp、alpha 行不动。
  * `MButton3.as:69-74` 文字四色 up `#fcf49c` / over `#ffffc3` / down `#acadb2` / disabled `#939393`
    （= 主题里已有的 按钮色/悬停/按下三常量，实测 16577692/16777155/11316658 换算一致）。

工程现状（`开发工具/查钮态与字号.gd` 无头实测，改之前）：
  Button/normal        = 按钮.png
  Button/hover         = 按钮.png × modulate #fff4d8   ← **乘性**，几乎不亮
  Button/hover_pressed = StyleBoxFlat 纯色 (1.0,0.365,0.365) ← 主题**没有这一槽**，
                          漏到 Godot 自带主题那张红块上 ⇒ 鼠标压着按下时画的是系统红
  Button/pressed       = 按钮按下.png（= 选中皮，占错了位）
  ⚠ 鼠标压着按钮时引擎走的是 DRAW_HOVER_PRESSED(=4)，**永远轮不到 `pressed`** ⇒
    原来"按下"看到的是那张红块，而 `按钮按下.png` 其实一次都没画过。

公式只有一份：`开发工具/派生钮态.py`（和底栏十钮、页签、关钮、复选框同一份）。

用法：`python 开发工具/生成标准钮态图.py` → `Godot --path . --headless --import`
     → 跑 `测试/界面主题回归测试.gd`（里面有 `Button` 四槽的皮名判据）。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 派生钮态 import 派生

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
基 = os.path.join(工程, "素材", "界面", "原版窗口", "通用控件")

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    源 = os.path.join(基, "按钮.png")
    总 = 0
    for 落, 尺, 偏移 in 派生(源):
        总 += 1
        print("   %-24s <- 按钮.png（%dx%d，clamp(rgb%+d)）" % (
                os.path.basename(落), 尺[0], 尺[1], 偏移))
    print("标准钮交互态皮：%d 张（逐字节等于公式，自检过）" % 总)
