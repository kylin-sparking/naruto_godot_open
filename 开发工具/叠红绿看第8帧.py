# -*- coding: utf-8 -*-
"""第 0 帧涂红、第 N 帧涂绿，按**注册点对齐**叠在一张图上 ⇒ 盘重合处变黄、错开处露红绿边。
再顺手搜 ±6 像素内"让重叠区色差最小"的那个偏移，直接给出第 N 帧的盘偏了几像素。

为什么用这个办法（前面四把自动地标全被"盘底下的半透明辉光"带偏了）：
红绿叠图**不挑地标** —— 盘的亮条是画实的，重合就是重合、错开就露边，肉眼和色差一起说话。

用法：python 开发工具/叠红绿看第8帧.py [帧号...]     默认 7 8
产物：测试/截图/打坐/红绿叠帧_第N帧.png
"""
import io
import json
import os
import sys

import numpy as np
from PIL import Image

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
表路 = os.path.join(工程, "数据", "界面", "打坐光环.json")
出目 = os.path.join(工程, "测试", "截图", "打坐")
倍 = 6
带 = (-30, 30, -40, 30)		# 相对注册点：列 −30~+30、行 −40~+30（盘整个在这个带里）


def 取(i):
    表 = json.load(io.open(表路, encoding="utf-8"))
    帧 = 表["帧"][i]
    像 = Image.open(os.path.join(工程, 帧["文件"][len("res://"):])).convert("RGBA")
    return 帧, np.asarray(像, dtype=np.float64)


def 贴到(色, 原x, 原y, 顶, 左):
    """把整张位图按"注册点落在叠图 (锚x,锚y) + (左,顶)"铺进叠图，返回 RGBA 数组。
    ⚠ `带` 的四元是 **(列起, 列止, 行起, 行止)** ⇒ 高 = 行止−行起、宽 = 列止−列起。
      上一版在这里把下标用反了（算出宽 = −10），所以这工具其实从没跑出过图。"""
    高, 宽 = 带[3] - 带[2], 带[1] - 带[0]
    布 = np.zeros((高, 宽, 4), dtype=np.float64)
    for y in range(高):
        画y = 顶 + 原y + 带[2] + y		# 该帧画布上的行
        if 画y < 0 or 画y >= 色.shape[0]:
            continue
        for x in range(宽):
            画x = 左 + 原x + 带[0] + x
            if 画x < 0 or 画x >= 色.shape[1]:
                continue
            布[y, x] = 色[画y, 画x]
    return 布


def 搜(色n, 原nx, 原ny, 底0, 实0, 预顶=0, 预左=0):
    """在 ±6 里搜"让重叠区色差最小"的整数偏移。`预顶/预左` 是**故意先加上的位移**，
    用来做阳性对照 —— 不证这一条，"最佳偏移 (0,0)" 完全可能只是量法认不出位移（假阴性）。"""
    最 = None
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            底n = 贴到(色n, 原nx, 原ny, 预顶 + dy, 预左 + dx)
            实n = 底n[..., 3] > 200
            同 = np.logical_and(实0, 实n)
            if 同.sum() < 50:
                continue
            差 = np.abs(底n[..., :3] - 底0[..., :3]).max(axis=2)
            分 = float(差[同].mean())
            指 = (-分, int(同.sum()))
            if 最 is None or 指 > 最[2]:
                最 = (dx, dy, 指, 分, int(同.sum()), 底n)
    return 最


def main():
    选 = [int(a) for a in sys.argv[1:]] or [7, 8]
    帧0, 色0 = 取(0)
    原0x, 原0y = int(帧0["原点x"]), int(帧0["原点y"])
    底0 = 贴到(色0, 原0x, 原0y, 0, 0)
    实0 = 底0[..., 3] > 200			# 只数"画实的"像素（辉光是半透明的，切掉）
    print("第 0 帧叠图里画实的像素 = %d 个（带 %s，高 %d 宽 %d）" % (
        int(实0.sum()), 带, 底0.shape[0], 底0.shape[1]))
    对照红 = 0
    for n in 选:
        帧n, 色n = 取(n)
        原nx, 原ny = int(帧n["原点x"]), int(帧n["原点y"])
        最 = 搜(色n, 原nx, 原ny, 底0, 实0)
        对 = 搜(色n, 原nx, 原ny, 底0, 实0, 预顶=5, 预左=0)
        if 最 is None:
            print("第 %d 帧：找不到重叠足够的偏移 ⇒ 这一帧盘不在带里？" % n)
            continue
        认得出 = 对 is not None and 对[1] == -5
        if not 认得出:
            对照红 += 1
        # ⚠ 符号口径（`贴到` 的 顶/左 就是"往画布下/右挪"= position 变大）：
        #   最佳 (dx,dy) = **这一帧的 position 该加上多少**才与第 0 帧的盘重合。
        #   上一版把它打成"盘比第 0 帧左 +2"，读起来方向正好反 ⇒ 差点又把人带沟里。
        print("第 %d 帧：与第 0 帧的盘重合 ⇒ 该帧 position 应加 (%+d,%+d)（往%s%s挪 %d/%d 像素）；"
              "现状 = 盘偏%s%s；重叠实亮像素 %d 个、平均色差 %.1f（红=第0帧 绿=第%d帧 黄=重合）"
              % (n, 最[0], 最[1],
                 "左" if 最[0] < 0 else "右", "上" if 最[1] < 0 else "下", abs(最[0]), abs(最[1]),
                 "右下" if (最[0] < 0 and 最[1] < 0) else ("左下" if (最[0] > 0 and 最[1] < 0)
                     else ("右上" if (最[0] < 0 and 最[1] > 0) else "左上")),
                 最[4], 最[3], n))
        print("   阳性对照（先把这帧往下压 5 像素再搜）：最佳偏移 (%s,%s) ⇒ 认得出 5 像素位移：%s"
              % (对[0] if 对 else "无", 对[1] if 对 else "无", "是" if 认得出 else "**否 —— 这一帧的量法无效**"))
        图 = Image.new("RGB", (底0.shape[1] * 倍, 底0.shape[0] * 倍), (8, 9, 12))
        像 = np.zeros((*底0.shape[:2], 3), dtype=np.uint8)
        像[..., 0] = np.clip(底0[..., 2] * (底0[..., 3] > 200), 0, 255).astype(np.uint8)
        像[..., 1] = np.clip(最[5][..., 2] * (最[5][..., 3] > 200), 0, 255).astype(np.uint8)
        像[..., 2] = np.minimum(像[..., 0], 像[..., 1])	# 蓝=两边都实且都亮 ⇒ 更醒目
        Image.fromarray(像).resize((底0.shape[1] * 倍, 底0.shape[0] * 倍), Image.NEAREST).save(
            os.path.join(出目, "红绿叠帧_第%d帧.png" % n))
        print("   出图 红绿叠帧_第%d帧.png" % n)
        # ★ 峰尖检查：只报"最佳偏移"不够 —— 若色差曲线在 ±6 里几乎是平的，
        #   那 (0,0) 就只是"没测出差别"，不是"重合"。（上一轮 配盘定基准.py 就是这么骗过我的）
        曲 = []
        for dy in range(-6, 7):
            底n = 贴到(色n, 原nx, 原ny, dy, 最[0])
            同 = np.logical_and(实0, 底n[..., 3] > 200)
            差 = np.abs(底n[..., :3] - 底0[..., :3]).max(axis=2)
            曲.append(float(差[同].mean()) if 同.sum() >= 50 else -1.0)
        好 = [c for c in 曲 if c >= 0]
        print("   竖直色差曲线(dx=%+d，行 −6..+6)：%s" % (最[0], " ".join("%.0f" % c for c in 曲)))
        if len(好) >= 3:
            谷 = min(好)
            边 = max(好[0], 好[-1])
            尖 = (边 / 谷) if 谷 > 0 else 999.0
            print("   ⇒ 峰尖度 = 两端最差 %.0f ÷ 谷底 %.0f = %.2f ⇒ %s（口径：这个比值**越大越尖**，"
                  "<1.15 才算平、平则偏移不可信）" % (
                      边, 谷, 尖, "峰是尖的 ⇒ 这个偏移可信" if 尖 >= 1.15 else "**峰是平的 ⇒ 这一帧的偏移不可信**"))
    if 对照红:
        print("!! 有 %d 帧的阳性对照不过 ⇒ 这些帧的『最佳偏移』不可信" % 对照红)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
