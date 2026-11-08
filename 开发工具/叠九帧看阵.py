# -*- coding: utf-8 -*-
"""把九帧**照原版公式**（`CharacterItem.setOrigin():53-60` 的 `bmp = −原点`）叠到一张图上，
用眼睛看那块八卦阵重不重合 —— 前三把尺子（按宽度找环 / FFT 配阵 / 长横条找带）
互相打脸，说明"该拿什么当阵"这件事我并没有真的看清楚。先看，再定基准。

出三张图（都放在 测试/截图/打坐/叠图/）：
  1) `逐帧_原版摆位.png`  九宫格，每格一张帧按原版摆位画在同一个坐标系里，
     并画两条**第 0 帧的盘底行 / 盘中心列**当参考线 ⇒ 一眼看出每帧的盘偏了几像素。
  2) `叠加_原版摆位.png`  九帧半透叠在一起（同一坐标系）⇒ 盘的轮廓糊成几圈就是没重合。
  3) `叠加_钉盘后.png`    按「长横条最下带」的盘底+盘心钉到第 0 帧之后再叠 ⇒ 对照用。
"""
import io
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
表路 = os.path.join(工程, "数据", "界面", "打坐光环.json")
出目 = os.path.join(工程, "测试", "截图", "打坐", "叠图")
画布 = 240		# 每格 480×480，节点原点放在格心
放大 = 2


def 摆到(底, 像, 位):
    """把 RGBA 像按 (位 = 画布原点要落在底图上的位置) 叠上去（SRC_OVER，含 alpha）。"""
    底.alpha_composite(像, (int(round(位[0])), int(round(位[1]))))


def main():
    表 = json.load(io.open(表路, encoding="utf-8"))
    帧表 = 表["帧"]
    量 = json.load(io.open(os.path.join(工程, "测试", "截图", "打坐", "阵横条.json"),
                           encoding="utf-8"))
    os.makedirs(出目, exist_ok=True)
    像们 = []
    for 帧 in 帧表:
        路 = os.path.join(工程, 帧["文件"][len("res://"):])
        像 = Image.open(路).convert("RGBA")
        if 放大 != 1:
            像 = 像.resize((像.size[0] * 放大, 像.size[1] * 放大), Image.NEAREST)
        像们.append(像)

    # 第 0 帧的盘底行 / 盘心列（**未放大**的像素坐标，来自 阵横条.json）
    盘0 = 量[0]
    底0 = 盘0["阵底"]
    心0 = int(round((盘0["阵左"] + 盘0["阵右"]) / 2.0))

    # ── 1) 九宫格：每格同一坐标系 + 第 0 帧的两条参考线
    格 = 画布 * 放大
    图 = Image.new("RGBA", (格 * 3 + 20, 格 * 3 + 20), (12, 14, 20, 255))
    for i, (帧, 像) in enumerate(zip(帧表, 像们)):
        gx, gy = i % 3, i // 3
        块 = Image.new("RGBA", (格, 格), (12, 14, 20, 255))
        # 原版公式：画布原点落在"节点原点"上 ⇒ 位 = 格心 − 原点
        摆到(块, 像, (格 / 2 - int(帧["原点x"]) * 放大, 格 / 2 - int(帧["原点y"]) * 放大))
        画 = ImageDraw.Draw(块)
        参y = 格 / 2 + (底0 - int(帧["原点y"])) * 放大
        参x = 格 / 2 + (心0 - int(帧["原点x"])) * 放大
        画.line([(0, 格 / 2), (格, 格 / 2)], fill=(90, 90, 90, 255), width=1)	# 节点原点(脚底)
        画.line([(格 / 2, 0), (格 / 2, 格)], fill=(90, 90, 90, 255), width=1)
        画.line([(0, 参y), (格, 参y)], fill=(255, 40, 40, 255), width=1)		# 第0帧盘底
        画.line([(参x, 0), (参x, 格)], fill=(40, 255, 40, 255), width=1)		# 第0帧盘心
        画.text((6, 6), "frame %d  origin(%d,%d)" % (i, int(帧["原点x"]), int(帧["原点y"])),
                fill=(255, 255, 0, 255))
        图.paste(块, (gx * (格 + 5) + 5, gy * (格 + 5) + 5))
    图.save(os.path.join(出目, "逐帧_原版摆位.png"))

    # ── 2) 叠加（原版摆位）
    叠 = Image.new("RGBA", (格, 格), (12, 14, 20, 255))
    for 帧, 像 in zip(帧表, 像们):
        摆到(叠, 像, (格 / 2 - int(帧["原点x"]) * 放大, 格 / 2 - int(帧["原点y"]) * 放大))
    画 = ImageDraw.Draw(叠)
    画.line([(0, 格 / 2 + (底0 - int(帧表[0]["原点y"])) * 放大), (格, 格 / 2 + (底0 - int(帧表[0]["原点y"])) * 放大)],
             fill=(255, 40, 40, 255), width=1)
    叠.save(os.path.join(出目, "叠加_原版摆位.png"))

    # ── 3) 叠加（按盘底+盘心钉到第 0 帧之后）
    # 记法：第 0 帧照原版摆 = (基x, 基y)；第 i 帧要让**自己的盘底/盘心**落在
    # 第 0 帧盘底/盘心所在的那个屏幕上位置 ⇒ 位 = 基 + (心0−心i, 底0−底i)。
    基x = 格 / 2 - int(帧表[0]["原点x"]) * 放大
    基y = 格 / 2 - int(帧表[0]["原点y"]) * 放大
    叠2 = Image.new("RGBA", (格, 格), (12, 14, 20, 255))
    for 像, 盘 in zip(像们, 量):
        if "阵底" not in 盘:
            continue
        心 = int(round((盘["阵左"] + 盘["阵右"]) / 2.0))
        摆到(叠2, 像, (基x + (心0 - 心) * 放大, 基y + (底0 - 盘["阵底"]) * 放大))
    画 = ImageDraw.Draw(叠2)
    画.line([(0, 格 / 2 + (底0 - int(帧表[0]["原点y"])) * 放大), (格, 格 / 2 + (底0 - int(帧表[0]["原点y"])) * 放大)],
             fill=(255, 40, 40, 255), width=1)
    叠2.save(os.path.join(出目, "叠加_钉盘后.png"))
    print("出图：%s" % 出目)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
