# -*- coding: utf-8 -*-
"""导出原版**物品提示框**（`MToolTipItem` 那一套）用的美术。

原版真值
--------
提示框的版式是**纯代码算出来的**，没有自己的符号（`MToolTipDefault.createDefaultTip`）：

    PADDING   = 8        （`MToolTip.as:20`）
    MAX_WIDTH = 280      （`MToolTipItem.as:18`）
    bgHeight  = PADDING
    标题   titleTF    w=280 h=20 @ (8, 8)              白 14px 粗体 居中
    图标框 MGrid_background(40x40) @ (170, bgHeight+10)  ← **不参与 bgHeight 累加**
    等级   content1TF w=280 @ (8, bgHeight+5)  12px 白，接着 bgHeight += 5 + height
    描述   content2TF 同上（有 desc 才建）
    分隔线 LineHPicF  w=280 @ (8, bgHeight+5)  接着 bgHeight += 5 + line.height
    宝石属性（仅宝石且非徽章石）
    价格/绑定 content4TF w=280 居中 @ (8, bgHeight+5)
    过期   content5TF w=280 h=20 居中 @ (8, bgHeight+5)
    最后：background.width = MAX_WIDTH + PADDING*2 - 3 = **293**
          background.height = bgHeight + PADDING

框的**形状**来自符号 `ToolTip_background`（symbol 699，包围盒 218x294）。
⚠️ 它 `extends ScaleSprite`，但 **SWF 里没有 scale9Grid**（查过 MainLib.xml：spriteId=699
的标签里没有这个属性），`ScaleSprite` 构造里读到的就是 null ⇒ **是普通拉伸，不是九宫格**。
所以客户端也用普通拉伸，别去做九宫格边距。

用法
----
    python 开发工具/生成物品提示框底板.py

产物
----
    素材/界面/原版窗口/通用控件/提示框底.png   218x294（客户端拉伸到 293 x (bgHeight+8)）
"""

import importlib.util
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

from PIL import Image  # noqa: E402

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版目录 = r"2.2.3"
FFDEC = os.path.join(原版目录, "ffdec_26.2.1", "ffdec-cli.exe")
SWF = os.path.join(原版目录, "www", "act_web_nya_208_isolated", "asset", "MainLib.swf")
临时目录 = os.path.join(项目根, "..", ".scratch", "物品提示框", "元件")
素材目录 = os.path.join(项目根, "素材", "界面", "原版窗口", "通用控件")

提示框底符号 = 699


def _载入时间轴工具():
    路径 = os.path.join(项目根, "开发工具", "读符号时间轴.py")
    spec = importlib.util.spec_from_file_location("读符号时间轴", 路径)
    模块 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(模块)
    return 模块


def 导出符号(符号: int) -> Image.Image:
    os.makedirs(临时目录, exist_ok=True)
    子进程 = subprocess.run(
        [FFDEC, "-selectid", str(符号), "-format", "sprite:png", "-export", "sprite",
         临时目录, SWF],
        capture_output=True, text=True,
    )
    for 名 in os.listdir(临时目录):
        if 名.startswith("DefineSprite_%d_" % 符号):
            候选 = os.path.join(临时目录, 名, "1.png")
            if os.path.exists(候选):
                return Image.open(候选).convert("RGBA")
    raise SystemExit("ffdec 没有导出符号 %d：%s" % (符号, 子进程.stdout + 子进程.stderr))


def 归一到符号原点(图: Image.Image, 符号: int, 时间轴) -> Image.Image:
    """把导出图画布对齐到 `PNG(0,0) = 符号(0,0)`（见 开发记录（本地） §3.3.0e 的偏移规律）。"""
    import math
    文本 = 时间轴.读XML(时间轴.XML_默认)
    盒 = 时间轴.字符边界(文本, 符号)
    if 盒 is None:
        raise SystemExit("算不出符号 %d 的包围盒" % 符号)
    x0, y0, x1, y1 = 盒
    旧原点 = (min(0, math.floor(x0)), math.floor(y0))
    if 旧原点 == (0, 0):
        return 图
    宽 = max(图.width + 旧原点[0], math.ceil(x1))
    高 = max(图.height + 旧原点[1], math.ceil(y1))
    新图 = Image.new("RGBA", (宽, 高), (0, 0, 0, 0))
    新图.alpha_composite(图, (旧原点[0], 旧原点[1]))
    print("  归一：导出原点在符号 (%d,%d) → %dx%d" % (旧原点[0], 旧原点[1], 宽, 高))
    return 新图


def 主() -> int:
    os.makedirs(素材目录, exist_ok=True)
    时间轴 = _载入时间轴工具()
    图 = 归一到符号原点(导出符号(提示框底符号), 提示框底符号, 时间轴)
    产物 = os.path.join(素材目录, "提示框底.png")
    图.save(产物)
    不透明 = sum(1 for y in range(图.height) for x in range(图.width) if 图.load()[x, y][3] > 0)
    print("提示框底 %dx%d，非透明 %d 像素 → %s" % (图.width, 图.height, 不透明, 产物))
    print("  素材自带 alpha=220（约 86% 不透明），客户端直接拉伸即可，不要再调透明度")
    return 0


if __name__ == "__main__":
    sys.exit(主())
