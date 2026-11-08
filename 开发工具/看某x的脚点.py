# -*- coding: utf-8 -*-
"""列出某张图、某个世界 x 上，所有「水平/斜坡」脚点线段各自的 y（按链条串起来看）。

用法: python 开发工具/看某x的脚点.py <地图id> <x> [y范围下限 y范围上限]
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

GC = r"."
INDEX = os.path.join(GC, "数据", "地图索引.json")
ROOT = os.path.join(GC, "数据", "地图")

mid = sys.argv[1] if len(sys.argv) > 1 else "100000000"
x = float(sys.argv[2]) if len(sys.argv) > 2 else 2100.0
lo = float(sys.argv[3]) if len(sys.argv) > 3 else -1e9
hi = float(sys.argv[4]) if len(sys.argv) > 4 else 1e9

with open(INDEX, encoding="utf-8-sig") as f:
    index = json.load(f)
folder = index.get(mid, mid)
with open(os.path.join(ROOT, folder, "地图.json"), encoding="utf-8-sig") as f:
    d = json.load(f)

rows = []
for i1 in d["foothold"].values():
    for i2 in i1.values():
        for fid, s in i2.items():
            rows.append((str(fid), s))

print("地图 %s(%s) 共 %d 段；x=%.1f 上命中的水平/斜坡段：" % (mid, folder, len(rows), x))
for fid, s in rows:
    x1, y1, x2, y2 = float(s["x1"]), float(s["y1"]), float(s["x2"]), float(s["y2"])
    if x1 == x2:
        continue
    if x < min(x1, x2) - 0.01 or x > max(x1, x2) + 0.01:
        continue
    t = (x - x1) / (x2 - x1)
    y = y1 + t * (y2 - y1)
    if y < lo or y > hi:
        continue
    print("  id=%-4s 段=(%g,%g)-(%g,%g)  该处 y=%.2f   prev=%s next=%s" % (
        fid, x1, y1, x2, y2, y, s.get("prev"), s.get("next")))

print("\n该 x 上的竖直段（原版用来当墙/边缘）：")
for fid, s in rows:
    x1, y1, x2, y2 = float(s["x1"]), float(s["y1"]), float(s["x2"]), float(s["y2"])
    if x1 != x2:
        continue
    if abs(x1 - x) > 60:
        continue
    print("  id=%-4s x=%g y=%g..%g  prev=%s next=%s" % (fid, x1, y1, y2, s.get("prev"), s.get("next")))
