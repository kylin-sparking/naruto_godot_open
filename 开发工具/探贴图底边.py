# -*- coding: utf-8 -*-
"""量一张角色/物件贴图里**图像内容**的真实范围（alpha 非透明的最小/最大行、列）。

为什么要量：`origin` 说的是"贴图哪一行落在角色坐标上"，但贴图本身可能带透明留白。
留白在 origin 之下 = 角色被画高（浮空）；在 origin 之上 = 角色被画低（陷进去）。

用法: python 开发工具/探贴图底边.py <png> [origin_x origin_y] [--逐行]
"""
import sys

import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

p = sys.argv[1]
数字 = [a for a in sys.argv[2:] if not a.startswith("--")]
逐行 = "--逐行" in sys.argv
im = Image.open(p)
a = np.asarray(im.convert("RGBA"))
h, w, _ = a.shape
alpha = a[:, :, 3]
rows = np.where((alpha > 200).any(axis=1))[0]
cols = np.where((alpha > 200).any(axis=0))[0]
print("%s 尺寸=%dx%d（alpha>200 视为内容）" % (p.split("\\")[-1], w, h))
if len(rows) == 0:
    print("  整张全透明")
else:
    print("  内容行 = %d .. %d（高 %d）；上留白 %d 行 / 下留白 %d 行" % (
        rows[0], rows[-1], rows[-1] - rows[0] + 1, rows[0], h - 1 - rows[-1]))
    print("  内容列 = %d .. %d" % (cols[0], cols[-1]))
if len(数字) >= 2:
    ox, oy = int(数字[0]), int(数字[1])
    print("  origin=(%d,%d)：相对 origin，内容底部在 %+d 行（负=内容在 origin 上方）" % (
        ox, oy, rows[-1] - oy))
if 逐行:
    print("  末尾 24 行每行 alpha 最大值：")
    for r in range(max(0, h - 24), h):
        print("    行%3d alpha_max=%3d  非零列数=%d" % (
            r, alpha[r].max(), int((alpha[r] > 8).sum())))
