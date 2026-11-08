# -*- coding: utf-8 -*-
"""摊开某张图的背景层参数，并与原版的格子尺寸口径对照。

原版 `MapBackGroup.drawFullScreen/drawHorizontal/drawVertical`：
    _cellWidth  = |image.displayContent.x| * 2   （displayContent.x = -origin.x）
    _cellHeight = |image.displayContent.y| * 2   （displayContent.y = -origin.y）
而 `ByteArrayImage` 把位图的**左上角**摆在 `(-origin.x, -origin.y)`。
所以"格子尺寸"与"贴图摆放"都由 **origin** 决定，不是由导出的 PNG 尺寸决定 ——
ffdec 导出的 PNG 是内容包围盒，边长不一定等于 2*origin（见记忆里的"PNG 原点偏移"）。
客户端现在用 PNG 尺寸当格子尺寸并且居中摆放，两者不一致时背景的伸缩/位置就会不对。

用法: python 开发工具/查背景参数.py [地图id]
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

GC = r"."
NYA = r"2.2.3"
sys.path.insert(0, os.path.join(NYA, "map_extract"))

from PIL import Image  # noqa: E402

mid = sys.argv[1] if len(sys.argv) > 1 else "100000000"
scene_path = os.path.join(NYA, "map_extract", "out", "mapscene_%s.json" % mid)
if not os.path.exists(scene_path):
    raise SystemExit("先跑 map_scene.py --map %s 生成 mapscene json" % mid)
scene = json.load(open(scene_path, encoding="utf-8"))
cache = os.path.join(NYA, "map_extract", "out", "cache")

print("=== 地图 %s 背景层" % mid)
for b in scene["backs"]:
    pngs = b.get("pngs") or []
    w = h = 0
    if pngs:
        p = os.path.join(cache, "Back_%s_back_%s" % (b.get("bS"), b.get("no")), pngs[0])
        if os.path.exists(p):
            w, h = Image.open(p).size
    ox, oy = int(b.get("ox", 0)), int(b.get("oy", 0))
    print("  key=%s no=%s type=%s rx=%s ry=%s x=%s y=%s a=%s f=%s" % (
        b.get("key"), b.get("no"), b.get("type"), b.get("rx"), b.get("ry"),
        b.get("x"), b.get("y"), b.get("a"), b.get("f")))
    print("      origin=(%d,%d) → 原版格子 = (%d, %d)" % (ox, oy, abs(ox) * 2, abs(oy) * 2))
    print("      导出 PNG     = (%d, %d)   %s" % (
        w, h,
        "一致" if (w, h) == (abs(ox) * 2, abs(oy) * 2) else "**不一致**（客户端按 PNG 摆就会错位/错缩）"))
