# -*- coding: utf-8 -*-
"""量"客户端渲染帧 vs 2.2.3 参照帧"在地形层（瓦片/物件）上的整体偏移。

为什么要量偏移而不是只比差异：并排图只能看出"不一样"，看不出"差多少、差在哪"。
参照帧用 --前景 生成（背景层关掉，底色 70,80,100），所以只统计参照帧里
**非底色** 的像素 —— 那就是地形真正画到的地方。

用法:
  python 开发工具/量前景偏移.py <参照帧.png> <客户端帧.png> [搜索半径]
输出: 最佳 (dx,dy)、该处的平均差、以及 (0,0) 处的平均差；还要给"逐带"结果。
"""
import sys

import numpy as np
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")

BG = np.array([70, 80, 100], dtype=np.int16)


def load(p):
    return np.asarray(Image.open(p).convert("RGB")).astype(np.int16)


def main():
    ref_p, cli_p = sys.argv[1], sys.argv[2]
    radius = int(sys.argv[3]) if len(sys.argv) > 3 else 12
    ref, cli = load(ref_p), load(cli_p)
    if ref.shape != cli.shape:
        print("尺寸不同：参照 %s 客户端 %s" % (ref.shape, cli.shape))
        return
    h, w, _ = ref.shape
    mask = (np.abs(ref - BG).sum(axis=2) > 12)
    print("参照非底色像素 %d / %d (%.1f%%)" % (mask.sum(), h * w, 100.0 * mask.sum() / (h * w)))

    inner = np.zeros_like(mask)
    inner[radius:h - radius, radius:w - radius] = True
    target = mask & inner

    def cost(dx, dy):
        # 把参照按 (dx,dy) 平移后与客户端比，统计 target 区域上的平均绝对差
        r = ref[radius:h - radius, radius:w - radius]
        c = cli[radius + dy:h - radius + dy, radius + dx:w - radius + dx]
        t = target[radius:h - radius, radius:w - radius]
        if t.sum() == 0:
            return 1e9
        return float(np.abs(r - c).sum(axis=2)[t].mean())

    best = (1e9, 0, 0)
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            v = cost(dx, dy)
            if v < best[0]:
                best = (v, dx, dy)
    print("最佳偏移: 参照平移 (dx=%d, dy=%d) 后最像客户端，平均差=%.2f" % (best[1], best[2], best[0]))
    print("零偏移处平均差=%.2f" % cost(0, 0))
    print("→ 说明客户端地形相对参照 %s" % (
        "完全对位" if (best[1], best[2]) == (0, 0)
        else "整体偏移了 x=%+d y=%+d 像素（正=客户端画得更靠右/靠下）" % (-best[1], -best[2])))

    # 逐带：把画面横切 4 带，各自找最佳 dx（垂直偏移多半是固定的，先分开看）
    print("\n逐带（横切 4 带，每带独立找最佳 dx,dy）:")
    step = h // 4
    for i in range(4):
        y0, y1 = max(i * step, radius), min((i + 1) * step, h - radius)
        t0 = mask[y0:y1, radius:w - radius]
        if t0.sum() < 500:
            print("  带%d y=%d..%d 地形像素太少(%d)，跳过" % (i, y0, y1, t0.sum()))
            continue
        bb = (1e9, 0, 0)
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                r = ref[y0:y1, radius:w - radius]
                c = cli[y0 + dy:y1 + dy, radius + dx:w - radius + dx]
                v = float(np.abs(r - c).sum(axis=2)[t0].mean())
                if v < bb[0]:
                    bb = (v, dx, dy)
        print("  带%d y=%d..%d 地形像素=%d 最佳(dx=%d,dy=%d) 差=%.2f" % (
            i, y0, y1, t0.sum(), bb[1], bb[2], bb[0]))


if __name__ == "__main__":
    main()
