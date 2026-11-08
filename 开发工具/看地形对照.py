# -*- coding: utf-8 -*-
"""把「原版美术+原版脚点红线」和「客户端渲染帧」裁到同一块世界区域，并排输出。

用处：`2.2.3/map_extract/map_scene.py --map X` 出的 out/map_X.png 是**原版美术上叠原版
foothold 红线**（线宽 3）。把它和客户端同机位帧并排、再放大单个元件，才看得出
"角色站的位置对不对"以及"红线（碰撞线）和画出来的地面是不是一条"。

用法:
  python 开发工具/看地形对照.py --map 100000000 --cx 2450 --cy 1100 \
      --客户端 "测试/截图/_本轮地形/客户端_100000000_cx2450.png" \
      --出 .scratch/并排.png [--放大 x,y,w,h]
"""
import argparse
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

import json  # noqa: E402

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

NYA = r"2.2.3"
W, H = 960, 560
VER_OFFSET = 128  # render_frame.py: ry = cy - H/2 - 128
MARGIN = 60       # map_scene.py render_preview 的 M


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", type=int, default=100000000)
    ap.add_argument("--cx", type=int, required=True)
    ap.add_argument("--cy", type=int, required=True)
    ap.add_argument("--客户端", dest="cli", required=True)
    ap.add_argument("--出", dest="out", required=True)
    ap.add_argument("--放大", dest="zoom", default="", help="世界坐标 x,y,w,h，额外出一张 8 倍放大")
    args = ap.parse_args()

    # 客户端帧的世界可见矩形（与 render_frame.py 同语义）
    rx = max(28, min(args.cx - W // 2, 4885 - W))
    ry = args.cy - H // 2 - VER_OFFSET

    full = Image.open(os.path.join(NYA, "map_extract", "out", "map_%d.png" % args.map)).convert("RGB")
    ox, oy = MARGIN - 28, MARGIN - (-70)   # 木叶村 VRLeft=28 VRTop=-70
    box = (rx + ox, ry + oy, rx + ox + W, ry + oy + H)
    orig = full.crop(box)
    cli = Image.open(args.cli).convert("RGB")

    # 关键证据图：把**原版脚点红线**直接画到**客户端渲染帧**上。
    # 这样一眼能看出"碰撞线"是不是落在客户端画出来的地面上。
    over = cli.copy()
    dov = ImageDraw.Draw(over)
    fh = json.load(open(os.path.join(
        r".", "数据", "地图", "木叶村", "地图.json"), encoding="utf-8-sig"))
    for i1 in fh.get("foothold", {}).values():
        for i2 in i1.values():
            for s in i2.values():
                x1, y1, x2, y2 = (float(s[k]) for k in ("x1", "y1", "x2", "y2"))
                if max(x1, x2) < rx or min(x1, x2) > rx + W:
                    continue
                if max(y1, y2) < ry or min(y1, y2) > ry + H:
                    continue
                dov.line([(x1 - rx, y1 - ry), (x2 - rx, y2 - ry)], fill=(255, 30, 30), width=1)

    canvas = Image.new("RGB", (W * 2 + 12, H + 26), (20, 20, 20))
    canvas.paste(orig, (0, 26))
    canvas.paste(over, (W + 12, 26))
    d = ImageDraw.Draw(canvas)
    d.text((4, 8), "原版美术 + 原版脚点红线(x%+d,y%+d)" % (ox, oy), fill=(255, 220, 120))
    d.text((W + 16, 8), "客户端渲染帧 + 原版脚点红线  cx=%d cy=%d" % (args.cx, args.cy), fill=(120, 220, 255))
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    canvas.save(args.out)
    print("并排图 -> %s  客户端可见世界矩形左上=(%d,%d)" % (args.out, rx, ry))

    if args.zoom:
        zx, zy, zw, zh = [int(v) for v in args.zoom.split(",")]
        scale = 8
        o = orig.crop((zx - rx, zy - ry, zx - rx + zw, zy - ry + zh))
        c = cli.crop((zx - rx, zy - ry, zx - rx + zw, zy - ry + zh))
        zo = o.resize((zw * scale, zh * scale), Image.NEAREST)
        zc = c.resize((zw * scale, zh * scale), Image.NEAREST)
        zc2 = Image.new("RGB", (zw * scale * 2 + 12, zh * scale + 26), (20, 20, 20))
        zc2.paste(zo, (0, 26))
        zc2.paste(zc, (zw * scale + 12, 26))
        d2 = ImageDraw.Draw(zc2)
        d2.text((4, 8), "原版世界(%d,%d)-(%d,%d) x8" % (zx, zy, zx + zw, zy + zh), fill=(255, 220, 120))
        d2.text((zw * scale + 16, 8), "客户端同区域 x8", fill=(120, 220, 255))
        zp = args.out.replace(".png", "_x8.png")
        zc2.save(zp)
        print("放大样本 x8 -> %s" % zp)


if __name__ == "__main__":
    main()
