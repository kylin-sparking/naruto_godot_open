# -*- coding: utf-8 -*-
"""翻页条那四枚箭头（首页 / 上一页 / 下一页 / 末页）的交互态皮。

现查（2026-10-19 深夜）：
  * `MPageFirstBtnF.as` / `MPagePreBtnF.as` / `MPageNextBtnF.as` / `MPageEndBtnF.as`
    **四个类都只有一行 `extends MButton3` + 一个 `[Embed]`** ⇒ 和窗口那颗 X、
    挂机页那 27 枚勾、数量框那两颗加减**同一族**：一组一张皮，悬停/按下是运行时
    `StyleUtil.getLightFilter`（`StyleUtil.as:7-12` over **+30** / down **−40**），
    禁用推 `getGrayFilter()`（`MButton3.as:333-344`）。不是 `MButton` 那种每态一张独立 skin。
  * 普查（10-19 深夜，本地一次性普查（同一轮））：全工程 **22 枚**箭头用到这四张皮，
    散在 8 张场景。其中 `首领窗口` 那 4 枚已有 `首领窗口.gd:217-235` 的一份状态机、
    五张 `家族*窗` 的 10 枚走 `家族子窗.gd:60-90` 那份（按 `metadata/skin` 换皮）⇒
    **本轮真正接的是剩下 8 枚**（`商城窗口` 4 + `好友选人窗` 2 + `双修选人窗` 2）。
    灰皮照旧烘齐四张：已接入的那几枚禁用档也走 `getGrayFilter`，取皮口径是"同目录加后缀"。
  * `首领窗口.tscn` 那四枚已经有 `texture_disabled = 专用控件/分页*_灰.png`（上一轮烘的灰皮，
    主干当时叫「分页首页」，现在工程里只剩派生件、没有同名常态件）。
    ⇒ 这一轮把灰皮**按现在的主干名**（`通用控件/首页_灰.png`）重烘一份放它旁边，
    状态机（`脚本/界面/组件/原版三态钮.gd`）的取皮口径是「同目录同名加后缀」，
    查不到 `_灰` 就回落常态、会把已经灰着的箭头刷回彩色 ⇒ 禁用档必须有料。
    旧的 `分页*_灰.png` **不删**（首领页那四枚的 `texture_disabled` 还指着它们，
    删了会让 TextureButton 自己拿常态图去画禁用档）。

公式只有一份：`开发工具/派生钮态.py`（和底栏十钮、页签、首领钮、复选框、关钮、加减同一份）。

用法：`python 开发工具/生成翻页钮态图.py` → `Godot --path . --headless --import`
     → `测试/换皮件三态回归测试.gd`（表里已经收这 22 枚）
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
    for 名 in ["首页", "上一页", "下一页", "末页"]:
        源 = os.path.join(基, 名 + ".png")
        for 落, 尺, 偏移 in 派生(源, 态表=态表):
            总 += 1
            print("   %-22s <- %s（%dx%d，%s）" % (
                    os.path.basename(落), 名, 尺[0], 尺[1],
                    "getGrayFilter" if 偏移 is None else "clamp(rgb%+d)" % 偏移))
    print("翻页箭头交互态皮：%d 张（逐字节等于公式，自检过）" % 总)
