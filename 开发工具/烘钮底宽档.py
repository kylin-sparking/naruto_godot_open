#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""按宽档预烘 MButtonF 的钮底（+悬停/按下/灰 三态）—— 只吃工程里已有的 `好友/钮底.png`（= tag18 upSkin 57×22）。

为什么单独一个脚本：`导入好友素材.py` 那一版要先有 `_tmp/ffdec_jiazu/mainlib` 的 ffdec 导出目录，
而那目录是临时物、早清掉了。宽档表**仍然记在 `导入好友素材.py:39`**（唯一事实源），
这里只是把那张表里的档用工程里已有的基图重烘一遍，两边算式必须一致：
`九宫格拉伸(基, 宽, 22, (7.15, 7.3, 7.15, 7))` —— 边距来自 tag18 的 `scale9Grid`（度量表 §3.2:202），
不是拟合值。三态 = `StyleUtil.skinFilters` 的 `+30 / −40` 加性滤镜 + `getGrayFilter`。

跑法：python 开发工具/烘钮底宽档.py            （默认烘 导入好友素材.py 宽档表里全部档）
      python 开发工具/烘钮底宽档.py --只 70
自检：烘完立刻重烘一遍比字节（幂等），并打印每张的天然尺寸与不透明像素数。
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from 对证库 import 九宫格拉伸
from 导入家族素材 import 加亮, 变灰

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
落 = os.path.join(项目, "素材", "界面", "原版窗口", "好友")
基路 = os.path.join(落, "钮底.png")
边距 = (7.15, 7.3, 7.15, 7)


def 表内宽档():
    文 = io.open(os.path.join(项目, "开发工具", "导入好友素材.py"), encoding="utf-8").read()
    行 = re.search(r"^宽档 = \[([0-9,\s]+)\]", 文, re.M)
    if 行 is None:
        raise SystemExit("没在 导入好友素材.py 里找到 `宽档 = [...]`（那张表是唯一事实源，别在这儿补第二份）")
    return [int(x) for x in 行.group(1).replace(" ", "").split(",") if x]


def 烘(宽, 基):
    名 = os.path.join(落, "钮底%d.png" % 宽)
    图 = 九宫格拉伸(基, 宽, 22, 边距)
    图.save(名)
    for 态, d in [("悬停", 30), ("按下", -40)]:
        加亮(图, d).save(名[:-4] + "_%s.png" % 态)
    变灰(图).save(名[:-4] + "_灰.png")
    return 名


def 字節(p):
    return io.open(p, "rb").read()


def 主():
    if not os.path.isfile(基路):
        raise SystemExit("基图不在：" + 基路)
    基 = Image.open(基路).convert("RGBA")
    档 = 表内宽档()
    if "--只" in sys.argv:
        档 = [int(x) for x in sys.argv[sys.argv.index("--只") + 1].split(",")]
    for 宽 in 档:
        if 宽 == 基.size[0]:
            print("  跳过 钮底%d：与基图同宽，本来就不用烘" % 宽)
            continue
        名 = 烘(宽, 基)
        第次 = 字節(名)
        烘(宽, 基)
        状态 = "幂等" if 字節(名) == 第次 else "**重烘字节不同 ⇒ 有不确定输入，别看这份产物**"
        图 = Image.open(名)
        实心 = sum(1 for a in 图.getchannel("A").getdata() if a > 0)
        print("  钮底%-3d %dx%d 不透明 %d 个像素  %s" % (宽, 图.size[0], 图.size[1], 实心, 状态))
        for 态 in ["_悬停", "_按下", "_灰"]:
            p = 名[:-4] + 态 + ".png"
            q = Image.open(p)
            print("      %-6s %dx%d 不透明 %d" % (态, q.size[0], q.size[1],
                    sum(1 for a in q.getchannel("A").getdata() if a > 0)))
    print("下一步：Godot --path . --headless --import")


主()
