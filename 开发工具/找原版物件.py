# -*- coding: utf-8 -*-
"""在**跑着的原版**截图里，按"彩色区块"找出物品图标，并打出它们在**原图上的绝对坐标**。

为什么要它：驱动原版鼠标要点在格子上，而背包格只有 41px 宽。
拿标尺图用眼睛读坐标能差 20px（2026-09-22 连量两次得到两个互相矛盾的答案），
点错就点到隔壁格 —— 这一条是真栽过的（§0.0d「验证环节本身不可靠」）。
物品图标**一定是高饱和度**的（格子底色是低饱和的褐），所以按饱和度聚块比按边框色靠谱得多
（`定位原版装备格.py` 那套"找边框色"在背包上会出 759 个假框）。

用法：
    python 开发工具/找原版物件.py <截图.png> --区域 1560,600,1845,800
    # 输出每个色块的中心与包围盒，按 y 再按 x 排序（就是格子的行序/列序）

    python 开发工具/找原版物件.py <截图.png> --区域 ... --最小边 12 --最小饱和 90
"""
import argparse
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

from PIL import Image  # noqa: E402


def 饱和(r: int, g: int, b: int) -> int:
    return max(r, g, b) - min(r, g, b)


def main() -> int:
    解析 = argparse.ArgumentParser()
    解析.add_argument("图")
    解析.add_argument("--区域", required=True, help="左,上,右,下（原图坐标）")
    解析.add_argument("--最小边", type=int, default=10, help="色块最小边长（原图像素）")
    解析.add_argument("--最小饱和", type=int, default=80, help="算作'彩色'的饱和度门槛")
    参数 = 解析.parse_args()

    左, 上, 右, 下 = (int(v) for v in 参数.区域.replace("，", ",").split(","))
    with Image.open(参数.图) as 原:
        块 = 原.convert("RGB").crop((左, 上, 右, 下))
    W, H = 块.size
    像素 = 块.load()

    # 先标出所有"彩色"像素
    彩 = [[饱和(*像素[x, y]) >= 参数.最小饱和 for x in range(W)] for y in range(H)]

    # 4 连通洪水填充聚块
    访问 = [[False] * W for _ in range(H)]
    块集 = []
    for y0 in range(H):
        for x0 in range(W):
            if not 彩[y0][x0] or 访问[y0][x0]:
                continue
            栈 = [(x0, y0)]
            访问[y0][x0] = True
            xs, ys, n = [], [], 0
            while 栈:
                x, y = 栈.pop()
                xs.append(x); ys.append(y); n += 1
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and 彩[ny][nx] and not 访问[ny][nx]:
                        访问[ny][nx] = True
                        栈.append((nx, ny))
            w = max(xs) - min(xs) + 1
            h = max(ys) - min(ys) + 1
            # 图标至少这么大；碎点（描边、抗锯齿）丢掉
            if w >= 参数.最小边 and h >= 参数.最小边 and n >= 参数.最小边 ** 2 // 3:
                块集.append((左 + min(xs), 上 + min(ys), 左 + max(xs), 上 + max(ys), n))

    # 按 y 分行（行高用中位块高的一半当容差），行内按 x 排
    块集.sort(key=lambda b: ((b[1] + b[3]) // 2, (b[0] + b[2]) // 2))
    行: list[list] = []
    for b in 块集:
        cy = (b[1] + b[3]) // 2
        if 行 and abs(cy - 行[-1][0]) <= max(12, (b[3] - b[1]) // 2):
            行[-1][1].append(b)
        else:
            行.append([cy, [b]])

    print("区域 %d,%d,%d,%d  找到 %d 个色块，分 %d 行" % (左, 上, 右, 下, len(块集), len(行)))
    for i, (cy, 条) in enumerate(行, 1):
        条.sort(key=lambda b: (b[0] + b[2]) // 2)
        中心 = "  ".join("(%d,%d)" % ((b[0] + b[2]) // 2, (b[1] + b[3]) // 2) for b in 条)
        print("  第%d行 y≈%d，%d 个：%s" % (i, cy, len(条), 中心))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
