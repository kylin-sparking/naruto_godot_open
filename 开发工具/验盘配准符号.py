# -*- coding: utf-8 -*-
"""**符号定死实验**：`盘配准.py` 报的那个 (dx,dy) 到底等于"position 该加多少"，还是它的相反数？

为什么必须做（2026-10-13）：用户已点头"把第 6、7 帧各挪 2~3 像素"。而 `铺()` 里那个
`顶/左` 是"**从画布第几行开始取**"—— 它增大，内容在屏幕上反而**往上**走 ⇒ 与 position 的
方向差一层反号。靠推容易推错一次，而挪错方向比不挪更糟（盘会往反方向跳 4~6 像素）。

做法：把第 6 帧的内容在画布里整体**往下**搬 5 像素（= 等价于把这一帧的 position_y 加 5），
再让工具去量它和第 0 帧 ⇒
  · 若报 dy = **−5** ⇒ `应加` 就是 position 该加的量（"往下搬了 5，要往上 5 才回去"）；
  · 若报 dy = **+5** ⇒ `应加` 与 position 增量**反号**，目标 position = 现值 − 应加。
两条互斥，跑一次就知道，不许靠读代码下结论。

跑：python 开发工具/验盘配准符号.py
退出码：0 = 判出方向了（两种都算"判出来了"，会打印该往哪走）；1 = 实验本身没做出位移。
"""
import io
import json
import os
import sys
import tempfile

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
import 盘配准

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
表路 = os.path.join(工程, "数据", "界面", "打坐光环.json")
搬 = 5		# 往下搬 5 像素（正数 = 屏幕上更低 = position_y 更大）


def main():
    表 = json.load(io.open(表路, encoding="utf-8"))
    帧6 = 表["帧"][6]
    源 = os.path.join(工程, str(帧6["文件"])[len("res://"):])
    像 = Image.open(源).convert("RGBA")
    a = np.asarray(像, dtype=np.uint8)
    假 = np.zeros_like(a)
    假[搬:, ...] = a[:a.shape[0] - 搬, ...]		# 内容整体往下搬 5 行
    临时 = tempfile.mkdtemp(prefix="盘符号_")
    假路 = os.path.join(临时, "假6.png")
    Image.fromarray(假).save(假路)

    # 自检：假帧真的被搬动了（否则这个实验什么都测不出来 = 连续两轮的假对照）
    动 = int((假[..., 3] > 200).sum() - (a[..., 3] > 200).sum())
    差行 = np.where(假[..., 3] > 200)[0]
    原行 = np.where(a[..., 3] > 200)[0]
    首行差 = int(差行.min() - 原行.min())
    print("自检：假帧最上一个「画实」像素行 相对原帧 = %+d 行（期望 %+d）⇒ %s" % (
        首行差, 搬, "搬到了，实验有效" if 首行差 == 搬 else "**没搬到 ⇒ 实验无效，别下结论**"))
    if 首行差 != 搬:
        raise SystemExit(1)

    原0x, 原0y, 色0 = 盘配准.读帧(工程, 表["帧"][0])
    底0 = 盘配准.铺(色0, 原0x, 原0y)
    实0 = 底0[..., 3] > 盘配准.实亮阈
    原x, 原y, 色 = 盘配准.读帧(工程, 帧6)
    假色 = np.asarray(Image.open(假路).convert("RGBA"), dtype=np.float64)

    def 量(像色, 标签):
        果 = 盘配准.搜(像色, 原x, 原y, 底0, 实0)
        print("%s ⇒ 工具报 应加 = %s（重叠 %d 个像素、色差 %.1f）" % (
            标签, 果["应加"], 果["重叠"], 果["色差"]))
        return 果

    真果 = 量(色, "原第 6 帧（没搬）")
    假果 = 量(假色, "把第 6 帧内容往下搬 %+d 像素之后" % 搬)
    报 = 假果["应加"][1] - 真果["应加"][1]
    print("")
    print("往下搬 %+d 像素 ⇒ 工具的 dy 变了 %+d" % (搬, 报))
    if 报 == -搬:
        print("⇒ **`应加` 就是 position 该加的量**（搬下去 5，它要 −5 才回来）")
        print("⇒ 目标 position = 现值 + 应加 ⇒ 第 6 帧 = (%g, %g)" % (
            -原x + 真果["应加"][0], -原y + 真果["应加"][1]))
    elif 报 == 搬:
        print("⇒ **`应加` 与 position 增量反号** ⇒ 目标 position = 现值 − 应加 ⇒ 第 6 帧 = (%g, %g)" % (
            -原x - 真果["应加"][0], -原y - 真果["应加"][1]))
    else:
        print("⇒ 两种都不是（变了 %+d）⇒ 量法对这个位移不敏感，**不许据此改摆位**" % 报)
        raise SystemExit(1)
    import shutil
    shutil.rmtree(临时, ignore_errors=True)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
