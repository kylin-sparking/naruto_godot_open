# -*- coding: utf-8 -*-
"""把若干张同尺寸 PNG 横排成一张对照图（每张上面写标签），用于"改前 / 改后"留痕。

用法: python 开发工具/拼前后对比.py --出 <out.png> --图 "标签1=<a.png>" "标签2=<b.png>" ...
"""
import argparse
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

from PIL import Image, ImageDraw  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--出", dest="out", required=True)
    ap.add_argument("--图", dest="items", nargs="+", required=True)
    ap.add_argument("--间隔", dest="gap", type=int, default=12)
    ap.add_argument("--表头", dest="head", type=int, default=26)
    args = ap.parse_args()

    parts = []
    for item in args.items:
        标签, _, 路径 = item.rpartition("=")
        parts.append((标签, Image.open(路径).convert("RGB")))

    宽 = sum(p[1].width for p in parts) + args.gap * (len(parts) - 1)
    高 = max(p[1].height for p in parts) + args.head
    canvas = Image.new("RGB", (宽, 高), (18, 18, 18))
    d = ImageDraw.Draw(canvas)
    x = 0
    for 标签, im in parts:
        canvas.paste(im, (x, args.head))
        d.text((x + 4, 8), 标签, fill=(255, 220, 120))
        d.line([(x - args.gap // 2, 0), (x - args.gap // 2, 高)], fill=(60, 60, 60))
        x += im.width + args.gap
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    canvas.save(args.out)
    print("对照图 -> %s  %dx%d" % (args.out, 宽, 高))


if __name__ == "__main__":
    main()
