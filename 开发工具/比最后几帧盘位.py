# -*- coding: utf-8 -*-
"""把**游戏渲染连拍**里第 0/6/7/8 帧的盘区裁出来、4 倍放大并排，画 5 像素网格 ⇒
肉眼判"最后一两帧的盘差几像素"。

为什么要单独看这几帧：用户 2026-10-13 报"现在只剩最后那一两帧会动，幅度不大"。
量法在起气那几帧被辉光骗过两次（`环底距`、`阵底`），所以这次**不看素材、看渲染出来的那一屏**，
而且把网格画上，差几像素直接数得出来。

用法：python 开发工具/比最后几帧盘位.py [连拍目录]
产物：测试/截图/打坐/盘位最后几帧.png
"""
import os
import sys

from PIL import Image, ImageDraw

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
目 = sys.argv[1] if len(sys.argv) > 1 else os.path.join(工程, "测试/截图/打坐/九帧连拍")
出 = os.path.join(工程, "测试/截图/打坐", "盘位最后几帧.png")
选 = [0, 1, 6, 7, 8]		# 第 0 帧是基准，1 是"该完全重合"的对照，6/7/8 是用户说会动的那几帧
倍 = 5
半宽, 上, 下 = 70, -20, 45	# 以注册点为中心：横向 ±70、纵向 −20~+45（盘就在这个带里）


def main():
    格宽, 格高 = 半宽 * 2 * 倍, (下 - 上) * 倍
    图 = Image.new("RGB", ((格宽 + 12) * len(选), 格高 + 40), (14, 16, 22))
    画 = ImageDraw.Draw(图)
    for k, i in enumerate(选):
        路 = os.path.join(目, "r_%d.png" % i)
        if not os.path.isfile(路):
            print("缺图", 路)
            continue
        像 = Image.open(路).convert("RGB")
        中x, 中y = 像.size[0] // 2, 像.size[1] // 2	# 连拍每格中心 = 角色注册点
        裁 = 像.crop((中x - 半宽, 中y + 上, 中x + 半宽, 中y + 下))
        裁 = 裁.resize((格宽, 格高), Image.NEAREST)
        x0 = k * (格宽 + 12)
        图.paste(裁, (x0, 40))
        画 = ImageDraw.Draw(图)
        # 白线 = 注册点那一行；黄网格每 5 像素一条（放大后每 25 像素一条）
        画.line([(x0, 40 + (-上) * 倍), (x0 + 格宽, 40 + (-上) * 倍)], fill=(255, 255, 255), width=2)
        for d in range(1, (下 - 上) // 5):
            y = 40 + (-上) * 倍 + d * 5 * 倍
            if y < 40 + 格高:
                画.line([(x0, y), (x0 + 格宽, y)], fill=(120, 120, 0), width=1)
        画.text((x0 + 4, 6), "f%d（白线=注册点，黄线每 5 像素）" % i, fill=(255, 255, 0))
    图.save(出)
    print("出图 %s" % 出)
    print("判读：拿第 0 帧那格当尺，数后面几格里盘的那排亮条**压在白线下方第几条黄线**；"
          "对不上就是差 N×5 像素以内，直接读得出来。")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
