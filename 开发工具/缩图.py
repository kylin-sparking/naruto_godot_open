# -*- coding: utf-8 -*-
"""把一张大图整体缩小，用于"先整块缩略定方向，再局部放大看细节"（§0.0c 第 3 条）。

`抓原版批量.ps1` 截出来是 2560x1440，整张读进来既费上下文又看不清重点，
先用这个看一眼"窗口在哪、什么状态"，再用 `裁图放大.py` 局部放大。

用法：
    python 开发工具/缩图.py --入 a.png --出 a_small.png --宽 1100
    python 开发工具/缩图.py --入 a.png --出 a_half.png --倍 0.5

⚠️ 写出来的图必须能读回来（对齐 `拼对比图.py` 的规矩）：PNG 结构自洽才落盘，
不通过就抛异常并把坏图改名 `.bad` —— 坏图进了会话历史会让那个会话永久 400。
"""
import argparse
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

from PIL import Image  # noqa: E402


def 验证(路径: str) -> None:
    with Image.open(路径) as 图:
        图.load()


def main() -> int:
    解析 = argparse.ArgumentParser()
    解析.add_argument("--入", required=True)
    解析.add_argument("--出", required=True)
    解析.add_argument("--宽", type=int, default=0, help="目标宽度；给了就按它等比缩")
    解析.add_argument("--倍", type=float, default=0.0, help="或者直接给倍率（<1 才是缩小）")
    参数 = 解析.parse_args()

    with Image.open(参数.入) as 图:
        图 = 图.convert("RGB")
        原宽, 原高 = 图.size
        if 参数.宽 > 0:
            比 = 参数.宽 / 原宽
        elif 参数.倍 > 0:
            比 = 参数.倍
        else:
            raise SystemExit("--宽 或 --倍 至少给一个")
        新宽, 新高 = max(1, round(原宽 * 比)), max(1, round(原高 * 比))
        缩 = 图.resize((新宽, 新高), Image.LANCZOS)

    目录 = os.path.dirname(os.path.abspath(参数.出))
    if 目录:
        os.makedirs(目录, exist_ok=True)
    缩.save(参数.出)
    try:
        验证(参数.出)
    except Exception as 异常:  # noqa: BLE001
        坏 = 参数.出 + ".bad"
        os.replace(参数.出, 坏)
        raise SystemExit("写出来的图读不回来（已改名 .bad）：%s" % 异常) from 异常
    print("缩图 %dx%d → %dx%d   %s" % (原宽, 原高, 新宽, 新高, 参数.出))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
