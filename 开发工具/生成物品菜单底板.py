# -*- coding: utf-8 -*-
"""导出原版**物品右键菜单**（`MPopupMenu`，实际是**左键单击**弹的）用的美术。

原版真值
--------
`com/mxw/uifl/base/controls/MPopupMenu.as`：

    MARGIN = 3，totalMargin = 6
    按钮   x = 3，y = 累计 + 3，累计 += 按钮高(19)
    bgWidth = max(按钮自然宽) + 6                 （:59，没给 menuWidth 时）
    按钮统一 宽 = bgWidth - 6                      （:76）
    底    高 = 累计 + 6，底宽 = bgWidth              （:85-86）
    ⚠️ 底是 `MPopupMenu_background` 时**再 +4 宽、+5 高**（:89-90）

按钮宽来自 `MButton` 的测量（`MButton.as:167-170`）：
    `宽 = 文本宽 + (paddingLeft-3) + (paddingRight-5) + 1`，两个 padding 默认都是 7
    ⇒ **宽 = 文本宽 + 7**

符号
----
    590  `MPopupMenu_background`  39x83   → 菜单底（按上面算出的宽高拉伸）
    585  `MPopupMenuButton_up`    47x19   → 按钮常态
    582  （时间轴里叫 downSkin/overSkin，摆的时候 scaleX 0.248672）189x19 → 47x19，悬停/按下

真机复核（2026-09-20）
    原版点开一次菜单实测宽 **72**：按上面算式「发到聊天框」5 字 ≈ 55 + 17 = 72 ✓

用法
----
    python 开发工具/生成物品菜单底板.py

产物
----
    素材/界面/原版窗口/通用控件/菜单底.png        39x83
    素材/界面/原版窗口/通用控件/菜单按钮.png      47x19
    素材/界面/原版窗口/通用控件/菜单按钮亮.png    47x19
"""

import importlib.util
import math
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

from PIL import Image  # noqa: E402

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版目录 = r"2.2.3"
FFDEC = os.path.join(原版目录, "ffdec_26.2.1", "ffdec-cli.exe")
SWF = os.path.join(原版目录, "www", "act_web_nya_208_isolated", "asset", "MainLib.swf")
临时目录 = os.path.join(项目根, "..", ".scratch", "物品菜单", "元件")
素材目录 = os.path.join(项目根, "素材", "界面", "原版窗口", "通用控件")

产物表 = [
    (590, "菜单底.png", 1.0),
    (585, "菜单按钮.png", 1.0),
    (582, "菜单按钮亮.png", 0.248672),   # 时间轴里 downSkin/overSkin 的摆法就是横向压到 0.248672
]


def 导出符号(符号: int) -> Image.Image:
    os.makedirs(临时目录, exist_ok=True)
    子进程 = subprocess.run(
        [FFDEC, "-selectid", str(符号), "-format", "sprite:png", "-export", "sprite",
         临时目录, SWF],
        capture_output=True, text=True,
    )
    # ⚠️ 目录名**不一定带类名后缀**：有类的符号是 `DefineSprite_585_MPopupMenuButton_up_…`，
    # 没类的（如 582）就叫 `DefineSprite_582` —— 只按 `DefineSprite_<id>_` 前缀找会漏。
    前缀 = "DefineSprite_%d" % 符号
    for 名 in os.listdir(临时目录):
        if 名 == 前缀 or 名.startswith(前缀 + "_"):
            候选 = os.path.join(临时目录, 名, "1.png")
            if os.path.exists(候选):
                return Image.open(候选).convert("RGBA")
    raise SystemExit("ffdec 没有导出符号 %d：%s" % (符号, 子进程.stdout + 子进程.stderr))


def 归一到符号原点(图, 符号: int, 时间轴) -> Image.Image:
    """`PNG(0,0) = 符号(0,0)`（见 开发记录（本地） §3.3.0e）。"""
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
    for 符号, 文件名, 横向缩放 in 产物表:
        图 = 归一到符号原点(导出符号(符号), 符号, 时间轴)
        if 横向缩放 != 1.0:
            新宽 = max(1, int(round(图.width * 横向缩放)))
            图 = 图.resize((新宽, 图.height), Image.LANCZOS)
        产物 = os.path.join(素材目录, 文件名)
        图.save(产物)
        print("符号 %d → %s (%dx%d)" % (符号, 产物, 图.width, 图.height))
    return 0


def _载入时间轴工具():
    路径 = os.path.join(项目根, "开发工具", "读符号时间轴.py")
    spec = importlib.util.spec_from_file_location("读符号时间轴", 路径)
    模块 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(模块)
    return 模块


if __name__ == "__main__":
    sys.exit(主())
