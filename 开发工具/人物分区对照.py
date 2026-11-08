#!/usr/bin/env python3
"""把「我方渲染」和「原版基线」按配准偏移对齐，分区出 2 倍上下并排图。

用法：python 开发工具/人物分区对照.py <基线.png> <我方.png> <出目录> [偏移x,偏移y]
偏移 = 我方(0,0) 落在基线上的坐标，由 窗口像素基线.gd 的配准结果给出。
"""
import sys
from pathlib import Path

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

基线路径, 我方路径, 出目录 = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
偏移 = (3, 19)
if len(sys.argv) > 4:
    偏移 = tuple(int(v) for v in sys.argv[4].split(","))

基线 = Image.open(基线路径).convert("RGB")
我方 = Image.open(我方路径).convert("RGB")
宽, 高 = 我方.size
基线裁 = 基线.crop((偏移[0], 偏移[1], 偏移[0] + 宽, 偏移[1] + 高))

分区 = {
    "页签栏": (0, 22, 宽, 52),
    "左侧页按钮": (0, 40, 80, 210),
    "顶部信息": (70, 40, 宽, 100),
    "装备左列": (70, 90, 180, 340),
    "装备中列": (130, 120, 250, 340),
    "装备右列": (215, 90, 330, 340),
    "勾玉行": (120, 270, 300, 340),
    "战斗属性": (325, 85, 宽, 245),
    "加点属性": (325, 240, 宽, 400),
    "底部生命": (60, 375, 340, 440),
}

出目录.mkdir(parents=True, exist_ok=True)
for 名, 框 in 分区.items():
    上 = 我方.crop(框)
    下 = 基线裁.crop(框)
    w, h = 上.size
    画 = Image.new("RGB", (w, h * 2 + 6), (255, 0, 255))
    画.paste(上, (0, 0))
    画.paste(下, (0, h + 6))
    画 = 画.resize((w * 2, 画.size[1] * 2), Image.NEAREST)
    路径 = 出目录 / f"{名}.png"
    画.save(路径)
    print(f"{名}: 上=我方 下=原版  区域{框} → {路径}")
