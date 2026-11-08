# -*- coding: utf-8 -*-
"""看某张图的 foothold 各层归属、地图块按层的条数、物件 z 分布。

原版把角色放进 `ALayerManager.getALayer(currFoothold.index1)`，也就是**脚点所在的那一层**；
客户端的做法是 `z_index = 100 + y`。两者只有在"瓦片层的 z 都在角色之下"时才等价，
所以要把各层的量级摊出来看。

用法: python 开发工具/看层归属.py [地图id]
"""
import json
import os
import sys
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8")

GC = r"."
mid = sys.argv[1] if len(sys.argv) > 1 else "100000000"
index = json.load(open(os.path.join(GC, "数据", "地图索引.json"), encoding="utf-8-sig"))
folder = index.get(mid, mid)
base = os.path.join(GC, "数据", "地图", folder)

d = json.load(open(os.path.join(base, "地图.json"), encoding="utf-8-sig"))
print("=== 地图 %s (%s)" % (mid, folder))
for L, grp in d["foothold"].items():
    ids = sorted((str(k) for g in grp.values() for k in g), key=int)
    print("  foothold 顶层键(原版 index1=层号) %s：%d 段  id=%s" % (L, len(ids), ids[:14]))

tp = os.path.join(base, "地图块.json")
if os.path.exists(tp):
    tb = json.load(open(tp, encoding="utf-8-sig"))
    print("  地图块按层:", Counter(t["layer"] for t in tb))
op = os.path.join(base, "物件.json")
if os.path.exists(op):
    ob = json.load(open(op, encoding="utf-8-sig"))
    zs = [int(o.get("z", 0)) for o in ob]
    print("  物件 %d 条，z 最小/最大 = %d/%d" % (len(ob), min(zs), max(zs)))
    print("  z 分布:", Counter(zs).most_common(8))
print("  ALAYER_STRIDE=2000、TILE_Z_OFFSET=1 → 各层瓦片 z = 层号*2000+1")
