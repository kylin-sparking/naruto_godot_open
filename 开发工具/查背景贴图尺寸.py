# -*- coding: utf-8 -*-
"""对比客户端**实际加载到**的背景贴图尺寸 与 原版由 origin 推出来的格子尺寸。

原版格子尺寸由 `origin` 决定（`MapBackGroup`：cell = |origin| * 2），与导出/导入的
PNG 边长无关。客户端却拿 PNG 边长当格子尺寸，还用 `draw_texture_rect` 把贴图拉到
那个尺寸 —— 一旦客户端加载的是放大版素材（素材_2x / 素材_4x），或 ffdec 导出的
PNG 与 2*origin 不等，背景就会整体缩放错。

用法: python 开发工具/查背景贴图尺寸.py [地图id]
"""
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

GC = r"."
NYA = r"2.2.3"
sys.path.insert(0, os.path.join(NYA, "map_extract"))

from PIL import Image  # noqa: E402

mid = sys.argv[1] if len(sys.argv) > 1 else "101010000"
map_dir = json.load(open(os.path.join(GC, "数据", "地图索引.json"), encoding="utf-8-sig")).get(mid, mid)
data = json.load(open(os.path.join(GC, "数据", "地图", map_dir, "地图.json"), encoding="utf-8-sig"))
scene = json.load(open(os.path.join(NYA, "map_extract", "out", "mapscene_%s.json" % mid), encoding="utf-8"))
bydesc = {(b.get("key"), b.get("no")): b for b in scene["backs"]}
asset_index = json.load(open(os.path.join(GC, "数据", "地图素材索引.json"), encoding="utf-8-sig"))

print("=== 地图 %s 的背景层：原版格子 vs 客户端实际贴图" % mid)
for key in sorted(data.get("back", {}), key=lambda k: int(k)):
    ld = data["back"][key]
    no = int(ld.get("no", -1))
    desc = bydesc.get((key, no)) or bydesc.get((str(key), no)) or {}
    ox, oy = int(desc.get("ox", 0)), int(desc.get("oy", 0))
    cell = (abs(ox) * 2, abs(oy) * 2)
    # 客户端会怎么找这张图：find_asset(map_id, "背景", "Back_<bS>_back_<no>.png")
    bS = ld.get("bS", "")
    found = []
    for ext in ["png", "jpg"]:
        name = "Back_%s_back_%d" % (bS, no)
        hit = asset_index.get("背景/%s" % name, "")
        if hit:
            found.append(("索引", hit))
        local = os.path.join(GC, "素材", "地图", map_dir, "背景", "%s.%s" % (name, ext))
        if os.path.exists(local):
            found.append(("本地", local))
        # 也可能是 2x/4x 目录
        for d in ("素材_2x", "素材_4x"):
            p = os.path.join(GC, d, "地图", map_dir, "背景", "%s.%s" % (name, ext))
            if os.path.exists(p):
                found.append((d, p))
    print("  key=%s no=%s type=%s rx=%s ry=%s x=%s y=%s  原版格子=%s" % (
        key, no, ld.get("type"), ld.get("rx"), ld.get("ry"), ld.get("x"), ld.get("y"), cell))
    if not found:
        print("     **客户端找不到这张图**")
    for 来源, p in found:
        真实路径 = p.replace("res://", GC + os.sep).replace("/", os.sep)
        尺寸 = Image.open(真实路径).size
        一致 = "一致" if 尺寸 == cell else "**不一致，背景会被拉伸到 %s**" % (cell,)
        print("     [%s] %s  %s  %s" % (来源, 尺寸, os.path.basename(p), 一致))
