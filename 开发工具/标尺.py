# -*- coding: utf-8 -*-
"""给截图裁块并叠上**坐标标尺**，用来"在原版屏幕上读出一个点的绝对坐标"。

为什么要有它：原版窗口的位置会漂（§3.12.3），要驱动的坐标每次都得重新量。
肉眼在缩放图上估点能差 20px（2026-09-22 连量两次得到两个互相矛盾的答案），
而背包格只有 41px 宽 —— 估错就点到隔壁格。叠上标尺后是**读数**，不是估计。

标尺刻度写的是**原图绝对坐标**（不是裁块局部），省得再加一次偏移。

用法：
    python 开发工具/标尺.py --入 a.png --框 1570,590,1825,775 --出 a_尺.png --倍 3 --格 20
    # --格 是刻度间隔（原图像素），--倍 是放大倍数；标尺每 --格 画一条，
    # 每 5 条加粗并写数字。
"""
import argparse
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

from PIL import Image, ImageDraw  # noqa: E402


def main() -> int:
    解析 = argparse.ArgumentParser()
    解析.add_argument("--入", required=True)
    解析.add_argument("--出", required=True)
    解析.add_argument("--框", required=True, help="左,上,右,下（原图坐标）")
    解析.add_argument("--倍", type=int, default=3)
    解析.add_argument("--格", type=int, default=20, help="刻度间隔（原图像素）")
    参数 = 解析.parse_args()

    左, 上, 右, 下 = (int(v) for v in 参数.框.replace("，", ",").split(","))
    with Image.open(参数.入) as 原:
        块 = 原.convert("RGB").crop((左, 上, 右, 下))
    倍 = 参数.倍
    块 = 块.resize((块.width * 倍, 块.height * 倍), Image.NEAREST)
    画 = ImageDraw.Draw(块)

    # 竖线：x 每 --格 一条，标签写原图坐标
    x = (左 // 参数.格) * 参数.格
    while x <= 右:
        if x >= 左:
            粗 = (x % (参数.格 * 5) == 0)
            cx = (x - 左) * 倍
            画.line([(cx, 0), (cx, 块.height)], fill=(255, 0, 255) if 粗 else (255, 120, 255), width=2 if 粗 else 1)
            if 粗:
                画.text((cx + 3, 2), str(x), fill=(255, 255, 0))
        x += 参数.格

    y = (上 // 参数.格) * 参数.格
    while y <= 下:
        if y >= 上:
            粗 = (y % (参数.格 * 5) == 0)
            cy = (y - 上) * 倍
            画.line([(0, cy), (块.width, cy)], fill=(0, 255, 255) if 粗 else (140, 255, 255), width=2 if 粗 else 1)
            if 粗:
                画.text((3, cy + 2), str(y), fill=(255, 255, 0))
        y += 参数.格

    目录 = os.path.dirname(os.path.abspath(参数.出))
    if 目录:
        os.makedirs(目录, exist_ok=True)
    块.save(参数.出)
    print("标尺 %s  刻度每 %d px，放大 %d 倍" % (参数.出, 参数.格, 倍))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
