# -*- coding: utf-8 -*-
"""用**只有完全不透明的亮青像素**（alpha=255 且蓝高绿高红低）当判据，量九帧里"盘上那排亮条"
各自落在哪一行/哪一列 ⇒ 这是第一次把**半透明辉光**从判据里切掉。

为什么换这一刀（前面四把都栽在同一件事上）：盘下面那团辉光是**半透明**的，
之前所有判据都只看"够不够亮/够不够宽"，辉光全都混进来了（`环底距` 22→32、`阵底` 7→14 都是它）。
盘上那排八卦亮条是**画实了的**（alpha=255），辉光不是 ⇒ 用 alpha 这一维切，比亮度/宽度都硬。

三条对照（任一坏就不许出结论）：
  ① 第 0 帧自己配自己 ⇒ 偏移 (0,0)、分数 1.000；
  ② 造一张整幅挪 (+4,−3) 的假帧 ⇒ 必须原样配回 (4,−3)；
  ③ 把第 0 帧那些 alpha=255 的亮青像素整块抹掉 ⇒ 必须查无（找不到才算判据认得盘）。

用法：python 开发工具/量实亮条.py
产物：测试/截图/打坐/实亮条.txt
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
搜 = 10


def 实亮青(像):
    a = np.asarray(像.convert("RGBA"), dtype=np.int16)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    return (al >= 250) & (b > 190) & (g > 150) & (r < 170)


def 主(布):
    """→ (行列表, 列列表) 里取"最靠下的那一簇"= 盘的前排亮条。"""
    行 = np.flatnonzero(布.any(axis=1))
    if 行.size == 0:
        return None
    # 从最下面一簇往上收（允许 3 行断档），这簇就是盘的下沿亮条
    底 = int(行[-1])
    顶 = 底
    y = 底
    while y > 0:
        lo = max(0, y - 3)
        # ⚠ 切片**不含 y 本身**：含了的话"只有第 y 行有内容"时 顶 == y，
        #   y 不再变小 ⇒ 死循环（第一版就卡死在这儿，timeout 124）。
        有 = np.flatnonzero(布[lo:y].any(axis=1))
        if 有.size == 0:
            break
        顶 = lo + int(有[0])
        y = 顶
    片 = 布[顶:底 + 1]
    列 = np.flatnonzero(片.any(axis=0))
    return int(顶), int(底), int(列[0]), int(列[-1]), int(片.sum())


def 配(模顶, 模底, 模左, 模右, 布0, 布):
    模 = 布0[模顶:模底 + 1, 模左:模右 + 1]
    n = float(模.sum())
    高, 宽 = 布.shape
    最 = None
    for dy in range(-搜, 搜 + 1):
        for dx in range(-搜, 搜 + 1):
            顶 = 模顶 + dy
            左 = 模左 + dx
            if 顶 < 0 or 左 < 0 or 顶 + 模.shape[0] > 高 or 左 + 模.shape[1] > 宽:
                continue
            块 = 布[顶:顶 + 模.shape[0], 左:左 + 模.shape[1]]
            覆 = float(np.logical_and(模, 块).sum()) / n
            并 = float(np.logical_or(模, 块).sum())
            交 = float(np.logical_and(模, 块).sum())
            分 = 交 / 并 if 并 else 0.0
            指 = (覆, 分)
            if 最 is None or 指 > 最[2]:
                最 = (dx, dy, 指)
    return 最


def main():
    表 = json.load(io.open(表路, encoding="utf-8"))
    帧表 = 表["帧"]
    布们 = [实亮青(Image.open(os.path.join(工程, 帧["文件"][len("res://"):])).convert("RGBA"))
            for 帧 in 帧表]
    行 = []

    def 写(s):
        行.append(s)
        print(s)

    m0 = 主(布们[0])
    原0x, 原0y = int(帧表[0]["原点x"]), int(帧表[0]["原点y"])
    写("第 0 帧的实亮条簇 = 行 %d~%d、列 %d~%d（%d 个 alpha>=250 的亮青像素）；注册点 (%d,%d)"
        % (m0[0], m0[1], m0[2], m0[3], m0[4], 原0x, 原0y))
    写("  ⇒ 簇底离注册点 %d 像素、簇中心列离注册点 %+.1f"
        % (m0[1] - 原0y, (m0[2] + m0[3]) / 2.0 - 原0x))

    a, b, c = 配(m0[0], m0[1], m0[2], m0[3], 布们[0], 布们[0])
    写("")
    写("[对照①] 第 0 帧配自己 ⇒ 偏移(%d,%d) 覆盖 %.3f / IoU %.3f %s"
        % (a, b, c[0], c[1], "OK" if (a, b) == (0, 0) and c[0] > 0.999 else "★坏"))
    挪 = (4, -3)
    假 = np.zeros((布们[0].shape[0] + 30, 布们[0].shape[1] + 30), dtype=bool)
    假[15 + 挪[1]:15 + 挪[1] + 布们[0].shape[0], 15 + 挪[0]:15 + 挪[0] + 布们[0].shape[1]] = 布们[0]
    a, b, c = 配(m0[0] + 15, m0[1] + 15, m0[2] + 15, m0[3] + 15, 布们[0], 假)
    写("[对照②] 造一张整幅挪 %s 的假帧 ⇒ 配回偏移(%d,%d) 覆盖 %.3f %s"
        % (挪, a, b, c[0], "OK" if (a, b) == 挪 else "★坏：认不出位移"))
    抹 = 布们[0].copy()
    抹[m0[0]:m0[1] + 1, :] = False
    写("[对照③] 把第 0 帧那簇亮条整块抹掉 ⇒ 主() 给 %s（必须 None 或明显不同）%s"
        % (主(抹), "OK" if 主(抹) is None or abs(主(抹)[1] - m0[1]) > 2 else "★坏"))

    写("")
    写("帧  原点       簇(顶,底,左,右)      簇底−原点y  簇心−原点x   配准偏移(dx,dy)  覆盖   IoU")
    结 = []
    for i, (帧, 布) in enumerate(zip(帧表, 布们)):
        原x, 原y = int(帧["原点x"]), int(帧["原点y"])
        m = 主(布)
        if m is None:
            写("%d  查无实亮条" % i)
            continue
        a, b, c = 配(m0[0], m0[1], m0[2], m0[3], 布们[0], 布)
        写("%d  %4d,%-4d  (%d,%d,%d,%d)      %+4d       %+6.1f      (%+3d,%+3d)    %.3f  %.3f"
          % (i, 原x, 原y, m[0], m[1], m[2], m[3], m[1] - 原y, (m[2] + m[3]) / 2.0 - 原x,
             a, b, c[0], c[1]))
        结.append({"帧": i, "簇底": m[1], "簇心列": (m[2] + m[3]) / 2.0,
                   "簇底减原点y": m[1] - 原y, "偏移x": a, "偏移y": b,
                   "覆盖": round(c[0], 3), "IoU": round(c[1], 3)})
    写("")
    写("⇒ 「配准偏移」就是**这一帧的盘相对第 0 帧挪了几像素**（正=偏右下）。"
        "覆盖/IoU 高 ⇒ 这个偏移可信；两者都低 ⇒ 那几帧盘被气糊住了，不许据此补偿。")
    os.makedirs(出目, exist_ok=True)
    io.open(os.path.join(出目, "实亮条.txt"), "w", encoding="utf-8", newline="\n")\
        .write("\n".join(行) + "\n")
    json.dump(结, io.open(os.path.join(出目, "实亮条.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
