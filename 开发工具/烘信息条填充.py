# -*- coding: utf-8 -*-
"""把目标信息条那两张填充图压到**控件天然宽 107**（Flash 那边是 `bar.width = 107`）。

为什么要单独烘一张：Godot 的 `TextureProgressBar` **不按控件尺寸缩放贴图** ——
它按贴图的天然宽度算填充像素、也不裁到控件矩形。所以 129 宽的图摆在 107 的框里
会往右溢出 22 像素（用户 10-15 实机图：血条/查克拉条戳出面板外）。
真值 `真值/窗口/目标信息条.md` §③ 原先写的"引擎横向压到 107"是**错的**，这次一并订正。
"""
import os
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
目录 = os.path.join(工程, "素材", "界面", "原版窗口", "目标信息")
宽 = 107			# `DetailsWindow.as:114-125` 的 `bar.width`（= maskMc 可见宽）

for 名 in ["血条填充", "蓝条填充"]:
    路 = os.path.join(目录, 名 + ".png")
    图 = Image.open(路).convert("RGBA")
    if 图.size[0] == 宽:
        print("跳过（已经是 %d 宽）：%s" % (宽, 名))
        continue
    旧 = 图.size
    # Flash 缩小走的是带 alpha 的双线性；这里同样用 BILINEAR，别用 NEAREST（会丢渐变里的过渡列）
    新 = 图.resize((宽, 图.size[1]), Image.BILINEAR)
    新.save(路)
    print("压 %s：%s → %s（逐列双线性）" % (名, 旧, 新.size))
