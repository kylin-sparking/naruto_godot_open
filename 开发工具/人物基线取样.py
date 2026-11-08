#!/usr/bin/env python3
"""从原版基线截图里量色/裁区，供人物窗口精修对照用。

用法：python 开发工具/人物基线取样.py
"""
import os
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

基线 = "测试/基线/原版界面/原版_人物属性_空装.png"
出 = os.path.join(os.environ.get("TEMP", "."), "peek")
os.makedirs(出, exist_ok=True)

im = Image.open(基线).convert("RGB")
区 = {
    "战属": (338, 98, 515, 250),
    "加点": (338, 245, 515, 400),
    "顶部": (78, 45, 515, 105),
    "底部": (60, 370, 340, 440),
}
for 名, (l, t, r, b) in 区.items():
    im.crop((l, t, r, b)).resize(((r - l) * 3, (b - t) * 3), Image.NEAREST).save(f"{出}/ref_{名}.png")

# 逐行扫一条竖线，找出内容底色的实际 RGB（避开文字与边框）
for y in range(100, 250, 10):
    print(y, [im.getpixel((x, y)) for x in (345, 360, 400, 500)])
