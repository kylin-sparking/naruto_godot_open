# -*- coding: utf-8 -*-
"""加减钮 `MPlusBtnF` / `MMinusBtnF` 的交互态皮 —— 数量框左右那两颗 18×18 的小圆钮。

现查（2026-10-19 夜）：
  * `MPlusBtnF.as` / `MMinusBtnF.as` 都是
    `public dynamic class … extends MButton3`（symbol **600** / **604**），类体里除了
    `[Embed]` 一行别的什么都没有 ⇒ 和挂机页那 27 枚勾、每一扇窗那颗 X **同一族**：
    一组只有一张皮，悬停/按下靠运行时加性滤镜，不是 `MButton` 那种每态一张独立 skin。
  * `StyleUtil.as:7-12` up 0 / over **+30** / down **−40**；`:43-47` 逐通道 clamp、alpha 行不动。
  * `MButton3.as:333-344` 的禁用档推 `getGrayFilter()` —— 但这四扇窗（买卖数量 / 商城购买 /
    存取金额 / 拆分）**没有任何一处把加或减置 disabled**（只禁 确定/购买），
    所以这里**不烘 `_灰`**；状态机 (`脚本/界面/组件/原版三态钮.gd`) 查不到派生皮会回落常态，
    真哪天要禁用，先补一张 `_灰.png` 再说。

工程现状（本轮要打掉的就是这个）：
  `买卖数量窗` / `商城购买窗` 的加减 = `Button` + `icon = 增加按钮.png`，四档同一张；
  `存取金额窗口` / `拆分窗口` 的加减 = `Button` + `theme_override_styles/{normal,hover,pressed,
  focus}` **四个槽指同一个 StyleBoxTexture** ⇒ 主题自己也没有任何档差。

公式只有一份：`开发工具/派生钮态.py`（和底栏十钮、页签、首领钮、复选框、关钮同一份）。

用法：`python 开发工具/生成加减钮态图.py` → `Godot --path . --headless --import` → 跑 `测试/换皮件三态回归测试.gd`
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 派生钮态 import 派生

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
基 = os.path.join(工程, "素材", "界面", "原版窗口", "通用控件")

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    总 = 0
    for 名 in ["增加按钮", "减少按钮"]:
        源 = os.path.join(基, 名 + ".png")
        for 落, 尺, 偏移 in 派生(源):
            总 += 1
            print("   %-24s <- %s（%dx%d，clamp(rgb%+d)）" % (
                    os.path.basename(落), 名, 尺[0], 尺[1], 偏移))
    print("加减钮交互态皮：%d 张（逐字节等于公式，自检过）" % 总)
