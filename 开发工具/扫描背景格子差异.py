# -*- coding: utf-8 -*-
"""全地图扫描：客户端用"PNG 边长"当背景格子，原版用 `|origin|*2`。差多少？

原版依据（`MapBackGroup.drawFullScreen/drawHorizontal/drawVertical`）：
    _cellWidth  = |image.displayContent.x| * 2   （ByteArrayImage.origin → displayContent.x = -origin.x）
    _cellHeight = |image.displayContent.y| * 2
且位图左上角摆在 `(-origin.x, -origin.y)`；客户端是"把贴图缩放着画进 cell_size 的格子、
并以格子中心为原点"，PNG 边长与 2*origin 不等时两者都会偏。

用法: python 开发工具/扫描背景格子差异.py [阈值像素]
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

GC = r"."
NYA = r"2.2.3"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # 服务端目录在本目录

import 服务端目录  # noqa: E402
fs = 服务端目录.加载()  # 项目内那份 fake_flash_server
from PIL import Image  # noqa: E402

阈值 = int(sys.argv[1]) if len(sys.argv) > 1 else 2
_CAT = fs.GAME_DATA_CATALOG


def _dec(b):
    while isinstance(b, (bytes, bytearray)):
        b = _CAT._decode_section(b)
    return b


ROOT = fs.Amf3Reader(
    open(os.path.join(NYA, "www", "act_web_nya_208_isolated", "dat", "GameData.dat"), "rb").read()
).read_value()
BACK = _CAT.raw_maps and ROOT.get("Back") or {}
INDEX = json.load(open(os.path.join(GC, "数据", "地图索引.json"), encoding="utf-8-sig"))
ASSET = json.load(open(os.path.join(GC, "数据", "地图素材索引.json"), encoding="utf-8-sig"))

差集 = []
缺图 = 0
总 = 0
for mid, folder in INDEX.items():
    p = os.path.join(GC, "数据", "地图", folder, "地图.json")
    if not os.path.exists(p):
        continue
    d = json.load(open(p, encoding="utf-8-sig"))
    for key in sorted(d.get("back", {}), key=lambda k: int(k)):
        ld = d["back"][key]
        bS, no = str(ld.get("bS", "")), int(ld.get("no", -1))
        总 += 1
        node = _dec(BACK.get(bS))
        node = _dec(node.get("back")) if isinstance(node, dict) else None
        node = _dec(node.get(str(no))) if isinstance(node, dict) else None
        o = (node or {}).get("origin") or {}
        ox, oy = int(o.get("x", 0)), int(o.get("y", 0))
        真格子 = (abs(ox) * 2, abs(oy) * 2)
        路径 = ASSET.get("背景/Back_%s_back_%d" % (bS, no), "")
        if not 路径:
            local = os.path.join(GC, "素材", "地图", folder, "背景", "Back_%s_back_%d.png" % (bS, no))
            路径 = local if os.path.exists(local) else ""
        if not 路径:
            缺图 += 1
            continue
        真实 = 路径.replace("res://", GC + os.sep).replace("/", os.sep)
        if not os.path.exists(真实):
            缺图 += 1
            continue
        w, h = Image.open(真实).size
        dx, dy = abs(w - 真格子[0]), abs(h - 真格子[1])
        if dx > 阈值 or dy > 阈值:
            差集.append((mid, folder, key, bS, no, (w, h), 真格子, dx, dy, ld.get("type")))

print("扫描 %d 个背景层；找不到贴图 %d 个" % (总, 缺图))
print("格子尺寸差 > %dpx 的层：%d 个  ← 客户端的伸缩/位置会明显错" % (阈值, len(差集)))
for r in sorted(差集, key=lambda r: -max(r[7], r[8]))[:25]:
    print("  %s 层%s no=%s type=%s  PNG=%s  原版格子=%s  差=(%d,%d)" % (
        r[1], r[2], r[4], r[9], r[5], r[6], r[7], r[8]))
