# -*- coding: utf-8 -*-
"""统计所有地图用到的 foothold 顶层层号（原版 index1）与地图块层号分布。

为什么要先统计：客户端用 `层号 * ALAYER_STRIDE(2000) + 偏移` 当 z_index，
而 Godot 的 z_index 只有 ±4096 —— 8 层 × 2000 直接溢出。要定新的带大小，
先得知道实际用到哪些层、y 跨度多大。
"""
import json
import os
import sys
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8")

GC = r"."
index = json.load(open(os.path.join(GC, "数据", "地图索引.json"), encoding="utf-8-sig"))
根 = os.path.join(GC, "数据", "地图")

fh层 = Counter()
块层 = Counter()
y最小 = 10 ** 9
y最大 = -10 ** 9
用到的最大层 = -1
缺文件 = 0
for mid, folder in index.items():
    p = os.path.join(根, folder, "地图.json")
    if not os.path.exists(p):
        缺文件 += 1
        continue
    d = json.load(open(p, encoding="utf-8-sig"))
    for L, grp in d.get("foothold", {}).items():
        fh层[int(L)] += 1
        用到的最大层 = max(用到的最大层, int(L))
        for g in grp.values():
            for s in g.values():
                y最小 = min(y最小, float(s["y1"]), float(s["y2"]))
                y最大 = max(y最大, float(s["y1"]), float(s["y2"]))
    tp = os.path.join(根, folder, "地图块.json")
    if os.path.exists(tp):
        for t in json.load(open(tp, encoding="utf-8-sig")):
            块层[int(t.get("layer", 0))] += 1
            y最小 = min(y最小, float(t.get("y", 0)))
            y最大 = max(y最大, float(t.get("y", 0)))

print("地图 %d 张（缺 地图.json %d 张）" % (len(index), 缺文件))
print("foothold 顶层层号 → 段数:", dict(sorted(fh层.items())))
print("地图块 层号 → 块数:", dict(sorted(块层.items())))
print("最大层号 = %d" % 用到的最大层)
print("y 跨度 = %.0f .. %.0f（%d px）" % (y最小, y最大, y最大 - y最小))
print("若带大小 512：层 7 顶点 = %d（Godot z_index 上限 4095）" % (7 * 512 + 511))
