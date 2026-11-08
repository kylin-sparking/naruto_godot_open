#!/usr/bin/env python3
"""量 ffdec 导出的原版分区图，找出横条/螺旋/按钮的精确像素位置，供 Godot 场景对齐。

用法：python 开发工具/分区量尺.py <图.png>
"""
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

路径 = sys.argv[1]
im = Image.open(路径).convert("RGBA")
宽, 高 = im.size
print(f"{路径}  {宽}x{高}")

起 = int(sys.argv[2]) if len(sys.argv) > 2 else 宽 // 2
print("-- 逐行（x=%d）--" % 起)
上一行 = None
for y in range(高):
    r, g, b, a = im.getpixel((起, y))
    态 = "透" if a < 40 else f"{r},{g},{b}"
    if 态 != 上一行:
        print(f"  y={y:<4} {态}")
        上一行 = 态

列 = int(sys.argv[3]) if len(sys.argv) > 3 else 12
print("-- 逐列（y=%d）--" % 列)
上一列 = None
for x in range(宽):
    r, g, b, a = im.getpixel((x, 列))
    态 = "透" if a < 40 else f"{r},{g},{b}"
    if 态 != 上一列:
        print(f"  x={x:<4} {态}")
        上一列 = 态
