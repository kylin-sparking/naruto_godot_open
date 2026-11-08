# -*- coding: utf-8 -*-
"""**最终定案用的那张图**：把第 0/2/4/8 帧按原版公式摆好、注册点画成白十字、
下面每 10 像素画一条黄线，4 倍放大并排 ⇒ 用眼睛判"盘到底在不在同一行"。

为什么最后要靠眼睛（前面四把尺子全栽了）：这九张位图里**盘、辉光、弧、气珠全糊在一起**，
任何"找边/找宽/找亮度/配花纹"的自动地标都会在起气那几帧被辉光骗走：
  · `环底距`（最后一个不透明像素行）22→32 ⇒ 那是辉光往下淌；
  · `阵底`（最长连续亮段 78~108 的那一档）7→14 ⇒ 还是辉光，盘没动；
  · FFT 覆盖率 1.000 ⇒ 气糊满造成的假满分；RGB 花纹配准 ⇒ 自己报了"峰不尖"，等于没测到。
⇒ 而原版 GameData 的 `Etc.effects.healNew` 每帧**只有 `origin` 与 `delay` 两个字段**
（2026-10-13 现查 `原版源数据/GameData.dat.json`），没有任何每帧偏移或缩放
⇒ 原版的摆位就是 `bmp = −origin`，盘在原版本来就不动。**我们照这条摆就对了，加任何补偿都会把它顶走。**

用法：python 开发工具/放大看盘位.py        产物：测试/截图/打坐/盘位放大对照.png
"""
import io
import json
import os
import sys

from PIL import Image, ImageDraw

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
表路 = os.path.join(工程, "数据", "界面", "打坐光环.json")
出 = os.path.join(工程, "测试", "截图", "打坐", "盘位放大对照.png")
选 = [0, 2, 4, 8]		# 第 0 帧（基准）、第 2 帧（补偿争议最小）、第 4 帧（沉得最多的那帧）、第 8 帧（收尾）
倍 = 4
宽, 高 = 120, 70
锚x, 锚y = 60, 45		# 注册点钉在每格这个位置


def main():
    表 = json.load(io.open(表路, encoding="utf-8"))
    帧表 = 表["帧"]
    图 = Image.new("RGB", ((宽 * 倍 + 10) * len(选), 高 * 倍 + 34), (14, 16, 22))
    画 = ImageDraw.Draw(图)
    for k, i in enumerate(选):
        帧 = 帧表[i]
        像 = Image.open(os.path.join(工程, 帧["文件"][len("res://"):])).convert("RGBA")
        原x, 原y = int(帧["原点x"]), int(帧["原点y"])
        块 = Image.new("RGBA", (宽, 高), (14, 16, 22, 255))
        块.alpha_composite(像, (锚x - 原x, 锚y - 原y))		# 注册点落到 (锚x,锚y)
        块 = 块.resize((宽 * 倍, 高 * 倍), Image.NEAREST)
        x0 = k * (宽 * 倍 + 10)
        图.paste(块, (x0, 34))
        画 = ImageDraw.Draw(图)
        画.line([(x0, 34 + 锚y * 倍), (x0 + 宽 * 倍, 34 + 锚y * 倍)], fill=(255, 255, 255), width=2)
        画.line([(x0 + 锚x * 倍, 34), (x0 + 锚x * 倍, 34 + 高 * 倍)], fill=(255, 255, 255), width=2)
        for d in range(1, 8):
            y = 34 + 锚y * 倍 + d * 10 * 倍
            if y < 34 + 高 * 倍:
                画.line([(x0, y), (x0 + 宽 * 倍, y)], fill=(255, 255, 0), width=1)
        画.text((x0 + 4, 6), "f%d  原点(%d,%d)  画布 %dx%d" % (i, 原x, 原y, 像.size[0], 像.size[1]),
                fill=(255, 255, 0))
        画.text((x0 + 4, 18), "白十字=注册点  黄线间隔 10 像素", fill=(200, 200, 200))
    图.save(出)
    print("出图 %s" % 出)
    print("判读：四格里那块八边形盘相对白十字的位置应当**一样高** ⇒ 盘是死的，"
          "照原版公式摆就不会飘；谁再往上/下补一个数，谁就把它顶走。")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
