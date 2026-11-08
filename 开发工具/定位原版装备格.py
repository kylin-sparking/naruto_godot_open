# -*- coding: utf-8 -*-
"""在**运行中的原版**截图上定位人物面板的装备格（真值，不是推导值）。

背景：`EquipPaneF`(符号 94) 的时间轴只给了 cell0..cell13，而
神器剑/镜、徽章、灵器、忍具、羁绊这几格是 **AS3 代码 new 出来的**
（`createShenQiCell` / `createLingQiCell` / `createRenJuCell` / `createHunjieCell`），
坐标由运行时公式算，源码里没有明文。用户 2026-09-21 口径：**以跑着的原版为准**。

用法：
    python 开发工具/定位原版装备格.py <截图.png> --区域 900,430,1250,760
    python 开发工具/定位原版装备格.py <截图.png> --区域 ... --原点 922,436

判据：格子的**边框是一条等宽的实心色带**（`CharWindowMGrid_background`）。
      先统计区域内出现次数最多、亮度中等的颜色当边框色，再找
      「上边一整条 + 下边一整条（相距 边长-1）都是该色」的矩形。
      **不用固定亮度阈值**（§3.10.11 第 3 条）。
"""

import argparse
import collections
import struct
import sys
import zlib
from pathlib import Path


def 解码PNG(路径):
    raw = Path(路径).read_bytes()
    w, h = struct.unpack(">II", raw[16:24])
    bd, ct = raw[24], raw[25]
    if bd != 8 or ct not in (2, 6):
        sys.exit(f"只支持 8bit RGB/RGBA，这张是 bitdepth={bd} colortype={ct}")
    idat = b""
    i = 8
    while i < len(raw):
        ln = struct.unpack(">I", raw[i : i + 4])[0]
        typ = raw[i + 4 : i + 8]
        if typ == b"IDAT":
            idat += raw[i + 8 : i + 8 + ln]
        i += 12 + ln
    data = zlib.decompress(idat)
    bpp = 3 if ct == 2 else 4
    stride = w * bpp
    行 = []
    prev = bytearray(stride)
    pos = 0
    for _ in range(h):
        f = data[pos]
        pos += 1
        line = bytearray(data[pos : pos + stride])
        pos += stride
        if f == 1:
            for x in range(bpp, stride):
                line[x] = (line[x] + line[x - bpp]) & 255
        elif f == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        行.append(bytes(line))
        prev = line
    return w, h, bpp, 行


def 取像素(行, bpp, x, y):
    off = x * bpp
    r = 行[y]
    return r[off], r[off + 1], r[off + 2]


def 找边框色(w, h, bpp, 行, 区域):
    """区域内出现最多、且亮度中等（不是黑也不是白）的颜色。"""
    计数 = collections.Counter()
    x0, y0, x1, y1 = 区域
    for y in range(y0, y1):
        for x in range(x0, x1):
            px = 取像素(行, bpp, x, y)
            if 6 <= sum(px) / 3 <= 250:
                计数[px] += 1
    return 计数


def 找格子(w, h, bpp, 行, 区域, 边框色, 容差, 边长):
    是边框 = lambda px: all(abs(px[i] - 边框色[i]) <= 容差 for i in range(3))
    x0, y0, x1, y1 = 区域
    结果 = []
    for y in range(max(0, y0), min(h - 边长, y1)):
        # 预先算这一行的"是边框"布尔数组，快得多
        上掩码 = None
        for x in range(max(0, x0), min(w - 边长, x1)):
            上 = all(是边框(取像素(行, bpp, x + i, y)) for i in range(边长))
            if not 上:
                continue
            下 = all(是边框(取像素(行, bpp, x + i, y + 边长 - 1)) for i in range(边长))
            if not 下:
                continue
            左 = all(是边框(取像素(行, bpp, x, y + i)) for i in range(边长))
            if not 左:
                continue
            右 = all(是边框(取像素(行, bpp, x + 边长 - 1, y + i)) for i in range(边长))
            if not 右:
                continue
            结果.append((x, y))
    去重 = []
    for x, y in 结果:
        if all(abs(x - a) > 2 or abs(y - b) > 2 for a, b in 去重):
            去重.append((x, y))
    return sorted(去重, key=lambda p: (p[1], p[0]))


def 主():
    ap = argparse.ArgumentParser()
    ap.add_argument("图片")
    ap.add_argument("--区域", required=True, help="x0,y0,x1,y1")
    ap.add_argument("--容差", type=int, default=6)
    ap.add_argument("--边长", type=int, default=40)
    ap.add_argument("--边框色", default=None, help="r,g,b；不给则自动统计")
    ap.add_argument("--原点", default=None, help="窗口原点绝对坐标 x,y")
    ap.add_argument("--前N", type=int, default=6, help="打印候选色前 N 个")
    参 = ap.parse_args()

    w, h, bpp, 行 = 解码PNG(参.图片)
    区域 = tuple(int(v) for v in 参.区域.split(","))
    去重候选 = []
    if 参.边框色:
        去重候选 = [tuple(int(v) for v in 参.边框色.split(","))]
    else:
        计数 = 找边框色(w, h, bpp, 行, 区域)
        print("# 区域内高频非纯黑/白颜色（候选边框色）：")
        for 色, n in 计数.most_common(参.前N):
            print("   %-18s n=%d" % (str(色), n))
        去重候选 = [色 for 色, _ in 计数.most_common(参.前N)]

    原点 = tuple(int(v) for v in 参.原点.split(",")) if 参.原点 else None
    for 色 in 去重候选:
        框 = 找格子(w, h, bpp, 行, 区域, 色, 参.容差, 参.边长)
        if len(框) < 4:
            continue
        print(f"\n# 边框色 {色} → {len(框)} 个 {参.边长}x{参.边长} 框")
        for x, y in 框:
            尾巴 = "  局部=(%d,%d)" % (x - 原点[0], y - 原点[1]) if 原点 else ""
            print(f"  绝对=({x},{y}){尾巴}")
        xs = sorted({x for x, _ in 框})
        ys = sorted({y for _, y in 框})
        if len(xs) > 1:
            print("  列 x =", xs, " 节距 =", [xs[i + 1] - xs[i] for i in range(len(xs) - 1)])
        if len(ys) > 1:
            print("  行 y =", ys, " 节距 =", [ys[i + 1] - ys[i] for i in range(len(ys) - 1)])
        break


if __name__ == "__main__":
    主()
