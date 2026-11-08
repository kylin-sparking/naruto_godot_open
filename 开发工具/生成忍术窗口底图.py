# -*- coding: utf-8 -*-
"""导出「忍术」窗口底板（符号 454 `SkillWindowF`），抹掉作者期烘在里面的按钮占位。

为什么要它
----------
窗口底图原来是把符号 454 整个扁平导出的，而符号 454 的时间轴上**烘着这些东西**：

| depth | 子件 | 位置（窗口坐标） |
|---|---|---|
| 8 / 14 / 26 / 32 | `SkillWindowTabButtonF` ×4（tabBtn1..4） | (16,45) (55,45) (93,45) (132,45)，各 39x22 |
| 20 | `SkillWindowMButtonF`（stateBtn） | (387,42)，57x22 |

作者期的 tabBtn 按 **39px 的原始宽度**排（16/55/93/132），而运行时
`SkillWindow.init()` 把它们的宽度统一设成 `UIConfig.btn_width_four`(61)、`x += width+1`
重排成 16/78/140/202/264。所以底图上那 4 个烘死的页签框会从客户端自己画的页签后面露出来
——实机看就是**页签行下面躺着 4 个没有字的小页签框**。

stateBtn 同理：烘的是 (387,42)，运行时 `x = width − 61 − 10 = 391`，
所以那个烘死的按钮会从客户端自己画的「忍术境界」旁边露出半圈边，
**看着就像字没居中**（眼睛读的是两个形状的合成）。

做法
----
那一条带的窗口底色是**水平的纯色**（y45..66 上 x175..380 全是 (54,45,39,239)），
所以按行取右侧干净列的颜色回填即可，不新造颜色。

用法
----
    python 开发工具/生成忍术窗口底图.py

产物
----
    素材/界面/原版窗口/忍术/忍术窗口底图.png   462x466（= 符号 454 的包围盒）
"""

import glob
import os
import subprocess
import sys

from collections import Counter

from PIL import Image

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版目录 = r"2.2.3"
FFDEC = os.path.join(原版目录, "ffdec_26.2.1", "ffdec-cli.exe")
SWF = os.path.join(原版目录, "www", "act_web_nya_208_isolated", "asset", "MainLib.swf")
临时目录 = os.path.join(项目根, "..", ".scratch", "技能补数据", "元件")
素材目录 = os.path.join(项目根, "素材", "界面", "原版窗口", "忍术")

符号 = 454
产物名 = "忍术窗口底图.png"

# 要抹的烘死子件（窗口坐标，(x0,y0,x1,y1)，含右含下），下面是逐条依据
要抹 = [
    ("4 个作者期页签框（tabBtn1..4，运行时按 61 宽重排在 16/78/140/202/264）", (15, 44, 172, 68)),
    ("作者期 stateBtn（运行时在 x=391，烘的是 387，会从自己的按钮旁露出半圈）", (386, 41, 445, 65)),
    # 标题文本框 #444 的 initialText 是空的（`<p align="center"></p>`），烘不出东西，不用管；
    # 但关闭按钮 #445 是实打实的一个 25x24 精灵，而客户端自己也画一个 → 两个叠着，
    # 实机看就是"右上角 X 的图案有重叠"。
    ("作者期关闭按钮 closeBtn（客户端自己也画一个，两个叠着）", (429, 4, 456, 30)),
]


def 导出(符号id: int) -> Image.Image:
    os.makedirs(临时目录, exist_ok=True)
    subprocess.run([FFDEC, "-selectid", str(符号id), "-format", "sprite:png",
                    "-export", "sprite", 临时目录, SWF], capture_output=True, text=True)
    命中 = glob.glob(os.path.join(临时目录, "DefineSprite_%d_*" % 符号id, "1.png"))
    if not 命中:
        raise SystemExit("ffdec 没有导出符号 %d" % 符号id)
    return Image.open(命中[0]).convert("RGBA")


def 主() -> int:
    图 = 导出(符号)
    print("符号 %d 导出 %dx%d" % (符号, 图.width, 图.height))
    像素 = 图.load()
    平地 = 0
    for 名, (x0, y0, x1, y1) in 要抹:
        改 = 0
        for y in range(y0, min(y1, 图.height) + 1):
            # ⚠️ 取样列必须落在**图内**：关闭按钮一直排到 x=456，右边只剩几列、
            # 再往外就是窗口边缘（透明）——上一版取 x1+6=462 越界，把那一块填成了透明，
            # 实机看就是"X 去掉了、但背景多了个黑方块"。改成往**左**取（标题栏那片是干净的）。
            参考 = 像素[max(0, x0 - 8), y]
            for x in range(x0, min(x1 + 1, 图.width)):
                if 像素[x, y] != 参考:
                    像素[x, y] = 参考
                    改 += 1
        平地 += 改
        print("  抹 %-28s (%d,%d)-(%d,%d)  %d 像素" % (名[:28], x0, y0, x1, y1, 改))
    os.makedirs(素材目录, exist_ok=True)
    产物 = os.path.join(素材目录, 产物名)
    图.save(产物)
    print("  共 %d 像素 -> %s" % (平地, 产物))

    # 「忍术境界」按钮的**美术**要单独留一份：底图里把它抹了之后，
    # 客户端那颗按钮是 `flat` 的、自己不画底，就会变成一行悬空的字。
    # 原版运行时用的就是这颗 `SkillWindowMButtonF`（57x22），
    # `stateBtn.width = UIConfig.btn_width_four`(61) 把它横向拉长。
    钮 = 导出(453)
    # ⚠️ 这颗美术里烘着**作者期占位文字 "Button"**（同 905「学习」那颗），
    # 客户端会在上面写「忍术境界」→ 两个叠着，实机看就是"下面还有白色字体重叠"。
    # 药丸是**竖向渐变**，所以逐行取众数当底色、把偏离众数的像素回填，只去字不动渐变与描边。
    # 内区留 3px 边不吃到外框。
    像素 = 钮.load()
    抹 = 0
    for y in range(3, 钮.height - 3):
        行 = [像素[x, y] for x in range(3, 钮.width - 3)]
        if not 行:
            continue
        底 = Counter(行).most_common(1)[0][0]
        for x in range(3, 钮.width - 3):
            if 像素[x, y] != 底:
                像素[x, y] = 底
                抹 += 1
    钮产物 = os.path.join(素材目录, "忍术境界按钮.png")
    钮.save(钮产物)
    print("  按钮美术 %dx%d（抹掉占位 \"Button\" %d 像素）-> %s" % (钮.width, 钮.height, 抹, 钮产物))
    return 0


if __name__ == "__main__":
    sys.exit(主())
