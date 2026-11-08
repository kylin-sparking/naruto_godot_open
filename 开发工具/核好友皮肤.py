# -*- coding: utf-8 -*-
"""好友页皮肤核对：工程既有件 vs 元件图导出（tag 来自《共用件度量表》§13）。

口径照 `导入家族素材.py`：先比尺寸，再比全等像素数与不透明区 RGB 最大差；
**不同源就用元件图那份**（上一轮 `通用控件/按钮.png` 冒充 MButtonF 皮的教训）。
跑法：python 开发工具/核好友皮肤.py
"""
import os
import sys

import numpy as np
from PIL import Image

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚠️ 原来写死作者机的 naruto_godot；改成从本文件反推，见 §合并说明
导 = os.path.join(项目, "_tmp", "ffdec_jiazu", "mainlib")
sys.stdout.reconfigure(encoding="utf-8")

表 = [  # (导出目录名, 工程内候选相对路径, 用途)
    ("DefineSprite_590_MPopupMenu_background_MPopupMenu_background",
     "素材/界面/原版窗口/通用控件/菜单底.png", "行菜单底"),
    ("DefineSprite_585_MPopupMenuButton_up_MPopupMenuButton_up",
     "素材/界面/原版窗口/通用控件/菜单按钮.png", "菜单项 up"),
    ("DefineSprite_705_MSelected_background1_MSelected_background1",
     "素材/界面/原版窗口/通用控件/选中条1.png", "行选中条"),
    ("DefineSprite_767_MWindowSmall_background_MWindowSmall_background",
     "素材/界面/原版窗口/通用控件/小窗口边框.png", "选人窗底"),
    ("DefineSprite_566_FriendFaceBtn_FriendFaceBtn", None, "私聊窗表情钮"),
    ("DefineSprite_247_FriendBtn_FriendBtn", None, "底栏好友钮（对照用）"),
]


def 组(路):
    a = np.asarray(Image.open(路).convert("RGBA")).astype(int)
    return a


def 比(甲, 乙):
    a, b = 组(甲), 组(乙)
    if a.shape != b.shape:
        return "尺寸不同 %s vs %s" % (a.shape[:2], b.shape[:2])
    同 = int((a == b).all(axis=2).sum())
    遮 = (a[:, :, 3] == 255) & (b[:, :, 3] == 255)
    差 = int(np.abs(a[:, :, :3] - b[:, :, :3]).max(initial=0)) if 遮.any() else None
    return "全等 %d/%d、不透明 RGB 最大差 %s" % (同, a.shape[0] * a.shape[1], 差)


for 符, 候, 用 in 表:
    源 = os.path.join(导, 符, "1.png")
    if not os.path.isfile(源):
        print("!! 导出缺：%s" % 符)
        continue
    尺 = Image.open(源).size
    行 = ["%-58s %dx%d　%s" % (符.replace("DefineSprite_", "tag"), 尺[0], 尺[1], 用)]
    if 候:
        p = os.path.join(项目, 候.replace("/", os.sep))
        行.append("工程件 " + ("无" if not os.path.isfile(p) else 比(源, p)))
    print("  |  ".join(行))
