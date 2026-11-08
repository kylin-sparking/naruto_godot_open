# -*- coding: utf-8 -*-
"""把九帧**盘左边那排亮条**单独裁出来、8 倍放大竖排，每 2 像素一条网格 ⇒ 直接数"最后一两帧差几像素"。

为什么盯左边的亮条：它是整张图里**对比度最高、最实**的结构（画死的小竖条），
而辉光是一团糊的、气珠是一颗颗的 ⇒ 要看盘有没有挪，量亮条比量"底边/宽度/覆盖率"都硬。

裁法：以**注册点**为锚（不是以画布角），窗 = 注册点左 52~左 20、注册点上 4 ~ 下 16
⇒ 九格共用同一个锚，盘若在同一处，亮条就该压在同一批格线上。

用法：python 开发工具/数亮条.py
产物：测试/截图/打坐/亮条九格.png
"""
import io
import json
import os
import sys

from PIL import Image, ImageDraw

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
表路 = os.path.join(工程, "数据", "界面", "打坐光环.json")
出 = os.path.join(工程, "测试", "截图", "打坐", "亮条九格.png")
倍 = 8
左1, 左2 = -52, -18		# 相对注册点的列范围（盘左半边那排亮条）
上1, 下1 = -6, 16		# 相对注册点的行范围
网格 = 2			# 每 2 像素一条横线


def main():
    表 = json.load(io.open(表路, encoding="utf-8"))
    帧表 = 表["帧"]
    宽 = (左2 - 左1) * 倍
    高 = (下1 - 上1) * 倍
    图 = Image.new("RGB", (宽 + 90, (高 + 8) * len(帧表)), (14, 16, 22))
    画 = ImageDraw.Draw(图)
    for i, 帧 in enumerate(帧表):
        像 = Image.open(os.path.join(工程, 帧["文件"][len("res://"):])).convert("RGBA")
        原x, 原y = int(帧["原点x"]), int(帧["原点y"])
        裁 = 像.crop((原x + 左1, 原y + 上1, 原x + 左2, 原y + 下1)).convert("RGB")
        裁 = 裁.resize((宽, 高), Image.NEAREST)
        y0 = i * (高 + 8)
        图.paste(裁, (0, y0))
        画 = ImageDraw.Draw(图)
        for d in range(0, (下1 - 上1) // 网格 + 1):
            y = y0 + d * 网格 * 倍
            画.line([(0, y), (宽, y)], fill=(150, 150, 0) if d % 5 else (255, 255, 255), width=1)
        画.text((宽 + 6, y0 + 4), "f%d 原点(%d,%d)" % (i, 原x, 原y), fill=(255, 255, 0))
        画.text((宽 + 6, y0 + 18), "白线每 10 像素\n黄线每 %d 像素" % 网格, fill=(200, 200, 200))
    图.save(出)
    print("出图 %s" % 出)
    print("判读：九格用的是同一个锚（注册点），所以**亮条压在第几条线上**就该九格都一样；"
          "哪一格错开 N 条黄线 = 那一帧的盘差 N×%d 像素。" % 网格)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
