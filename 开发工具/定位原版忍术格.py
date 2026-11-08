# -*- coding: utf-8 -*-
"""从原版忍术窗口截图里找出技能树每格的屏幕坐标。

为什么要自动找而不是手量
------------------------
窗口位置一变手量的坐标就全废（跟底栏按钮是同一个坑），而且 5 个页签加起来有 60+ 格。

怎么找
------
**不是**按亮度找图标——图标和灰色箭头一样亮，一膨胀就连成一片（试过，5 个页签里
「奥义禁术」被连成两根 250px 高的柱子）。改成找**格子边框的颜色**：
未选中格子是 `#7E4D2F`(126,77,47) 的圆角方框，每格是一个独立连通的环，
环的外接矩形正好就是格子，中心即点击点。实测每格净尺寸 38×34，非常整齐。

用法
----
    python 开发工具/定位原版忍术格.py <截图.png> [--窗口 x0,y0,x1,y1] [--树右界 N]

输出按**列分组**（同一列的 x 相同），每列内按 y 排序——技能树是按列串起来的。
最后一行是可直接喂给 抓原版批量.ps1 的点击串（按列从左到右，列内从上到下）。
"""

import argparse
import sys
from collections import deque

import numpy as np
from PIL import Image

# 未选中格子的边框色（在 2560x1440 的整屏截图上取样得到）
边框色 = (126, 77, 47)
# 整屏，够大即可——靠"树右界"和"格子尺寸"两道过滤把详情区排除掉
默认窗口 = (780, 440, 1260, 930)
# 树区右边界：再往右是详情区，详情区里也有方块（技能大图标、学习按钮）
默认树右界 = 1020


def 取掩码(图, 色=边框色, 容差: int = 28):
    a = np.asarray(图, dtype=np.int16)
    return np.abs(a - np.array(色, dtype=np.int16)).max(axis=2) <= 容差


def 膨胀(掩码, 半径: int):
    if 半径 <= 0:
        return 掩码
    k = 半径 * 2 + 1
    pad = np.pad(掩码, 半径, mode="constant", constant_values=False)
    return np.lib.stride_tricks.sliding_window_view(pad, (k, k)).any(axis=(2, 3))


def 连通域(掩码):
    高, 宽 = 掩码.shape
    已访 = np.zeros_like(掩码, dtype=bool)
    结果 = []
    for sy, sx in zip(*[v.tolist() for v in np.nonzero(掩码)]):
        if 已访[sy, sx]:
            continue
        队列 = deque([(sy, sx)])
        已访[sy, sx] = True
        x0 = x1 = sx
        y0 = y1 = sy
        while 队列:
            y, x = 队列.popleft()
            x0 = min(x0, x)
            x1 = max(x1, x)
            y0 = min(y0, y)
            y1 = max(y1, y)
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < 高 and 0 <= nx < 宽 and 掩码[ny, nx] and not 已访[ny, nx]:
                    已访[ny, nx] = True
                    队列.append((ny, nx))
        结果.append((x0, y0, x1, y1))
    return 结果


def 找格(path: str, 窗口, 树右界: int, 最短: int = 28, 最长: int = 46):
    x0, y0, x1, y1 = 窗口
    图 = Image.open(path).convert("RGB").crop((x0, y0, x1, y1))
    掩码 = 膨胀(取掩码(图), 1)
    格 = []
    for bx0, by0, bx1, by1 in 连通域(掩码):
        宽 = bx1 - bx0 - 1  # 去掉膨胀出来的各 1px
        高 = by1 - by0 - 1
        if not (最短 <= 宽 <= 最长 and 最短 <= 高 <= 最长):
            continue
        中心x = x0 + (bx0 + bx1) // 2
        中心y = y0 + (by0 + by1) // 2
        if 中心x > 树右界:
            continue
        格.append((中心x, 中心y, 宽, 高))
    return 格


def 分列(格, 同列容差: int = 6):
    列: list = []
    for x, y, 宽, 高 in sorted(格):
        放到 = None
        for 本列 in 列:
            if abs(本列[0][0] - x) <= 同列容差:
                放到 = 本列
                break
        if 放到 is None:
            列.append([(x, y, 宽, 高)])
        else:
            放到.append((x, y, 宽, 高))
    for 本列 in 列:
        本列.sort(key=lambda t: t[1])
    return 列


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("截图")
    ap.add_argument("--窗口", default=",".join(str(v) for v in 默认窗口))
    ap.add_argument("--树右界", type=int, default=默认树右界)
    args = ap.parse_args()

    窗口 = tuple(int(v) for v in args.窗口.split(","))
    格 = 找格(args.截图, 窗口, args.树右界)
    if not 格:
        print("没找到格子——检查 --窗口 是否对得上截图")
        return 1
    列 = 分列(格)
    print("%s：找到 %d 格，分 %d 列" % (args.截图.split("\\")[-1], len(格), len(列)))
    for i, 本列 in enumerate(列):
        print("  列%d x=%d：%s" % (i, 本列[0][0],
                                 "  ".join("y=%d(%dx%d)" % (y, 宽, 高) for _, y, 宽, 高 in 本列)))
    print("点击串：" + " ".join("%d,%d" % (x, y)
                               for 本列 in 列 for x, y, _, _ in 本列))
    return 0


if __name__ == "__main__":
    sys.exit(main())
