# -*- coding: utf-8 -*-
"""沿某一列扫"强水平边缘"的行号，用来把两张图的地形表面**精确对齐**（肉眼读图必错）。

用法:
  python 开发工具/探竖列边缘.py <图.png> <列号> [阈值]
对两张图各跑一次，比行号：同一块地形表面在两张图里的行号差 = 真正的竖直偏移。
"""
import sys

import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

p = sys.argv[1]
col = int(sys.argv[2])
thr = int(sys.argv[3]) if len(sys.argv) > 3 else 60

im = np.asarray(Image.open(p).convert("RGB")).astype(np.int16)
c = im[:, col, :]
d = np.abs(np.diff(c, axis=0)).sum(axis=1)
rows = np.where(d > thr)[0]
print("%s 列=%d  强边缘行数=%d" % (p.split("\\")[-1], col, len(rows)))
prev = -9
for r in rows:
    if r - prev < 3:
        prev = r
        continue
    prev = r
    print("  行%3d → %3d   上=%s 下=%s   Δ=%d" % (
        r, r + 1, tuple(c[r]), tuple(c[r + 1]), d[r]))
