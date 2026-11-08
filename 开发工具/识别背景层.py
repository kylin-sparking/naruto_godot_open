# -*- coding: utf-8 -*-
"""给每张图的每个背景层定类别，产出权威表 `数据/背景层标记.json`。

背景层的角色不能靠 `no`、`rx` 或顺序猜（都猜错过）。角色直接写在**贴图里**：

    纯色底块  贴图只有 1 种颜色（原版就是那张 256x256 的 #3366CC），垫在最底下兜底
    天空      贴图**完全不透明**且颜色丰富 —— 它是一整块铺满的画（云彩天空）
    后景      贴图有大量透明区 —— 它是"一个元素"（远山、火影岩、村子），靠透明处透出下层

木叶村实测：back_0 纯色底块(1 色) / back_2 天空(1024x1200 全不透明) /
back_3 远山(51% 透明) / back_1 火影岩+村子(27% 透明)。

**显示次序 = 地图数据里的键序（键0 在最底）** —— 这就是原版 `MapRender.drawBack()`
`for each(_loc2_ in this.data.backs) addBack(_loc2_)` 的加入顺序，后加的在上。

用法:
  python 开发工具/识别背景层.py            # 产出 json + 打印摘要
  python 开发工具/识别背景层.py --表        # 额外落一份人看的 markdown 表
"""
import argparse
import json
import os
import sys
from collections import Counter

sys.stdout.reconfigure(encoding="utf-8")

import numpy as np
from PIL import Image

GC = r"."
ASSET = json.load(open(os.path.join(GC, "数据", "地图素材索引.json"), encoding="utf-8-sig"))
INDEX = json.load(open(os.path.join(GC, "数据", "地图索引.json"), encoding="utf-8-sig"))
OUT = os.path.join(GC, "数据", "背景层标记.json")
OUT表 = os.path.join(GC, "数据", "背景层标记.md")

纯色阈值 = 4          # 唯一颜色数 <= 这个值 → 纯色底块
不透明阈值 = 0.995     # 完全不透明像素占比 >= 这个值 → 整块画（天空）
采样边长 = 96         # 判颜色数前先缩小，全尺寸太慢


def 找图(folder, bS, no):
    p = ASSET.get("背景/Back_%s_back_%d" % (bS, no), "")
    if p:
        p = p.replace("res://", GC + os.sep).replace("/", os.sep)
        if os.path.exists(p):
            return p
    p = os.path.join(GC, "素材", "地图", folder, "背景", "Back_%s_back_%d.png" % (bS, no))
    return p if os.path.exists(p) else ""


_缓存 = {}


def 判类别(路径):
    """按贴图内容判类别。同一张图（bS+no）在多张地图里复用，结果缓存。"""
    if 路径 in _缓存:
        return _缓存[路径]
    try:
        im = Image.open(路径).convert("RGBA")
    except OSError:
        _缓存[路径] = ("缺图", 0, 0, (0, 0))
        return _缓存[路径]
    w, h = im.size
    a = np.asarray(im)
    al = a[:, :, 3]
    全不透明 = float((al == 255).mean())
    小 = np.asarray(im.resize((采样边长, 采样边长), Image.BILINEAR))
    色数 = len(np.unique(小[:, :, :3].reshape(-1, 3), axis=0))
    if 色数 <= 纯色阈值:
        类 = "纯色底块"
    elif 全不透明 >= 不透明阈值:
        类 = "天空"
    else:
        类 = "后景"
    主色 = tuple(int(x) for x in np.asarray(im.convert("RGB")).reshape(-1, 3).mean(axis=0))
    _缓存[路径] = (类, 色数, round(全不透明, 4), (w, h), 主色)
    return _缓存[路径]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--表", action="store_true")
    args = ap.parse_args()

    表 = {}
    统计 = Counter()
    for mid, folder in sorted(INDEX.items()):
        p = os.path.join(GC, "数据", "地图", folder, "地图.json")
        if not os.path.exists(p):
            continue
        d = json.load(open(p, encoding="utf-8-sig"))
        back = d.get("back", {})
        if not back:
            continue
        本图 = []
        for 序号, k in enumerate(sorted(back, key=lambda x: int(x))):
            v = back[k]
            bS, no = str(v.get("bS", "")), int(v.get("no", -1))
            路径 = 找图(folder, bS, no)
            类, 色数, 不透明, 尺寸, 主色 = 判类别(路径) if 路径 else ("缺图", 0, 0.0, (0, 0), (0, 0, 0))
            本图.append({
                "键": int(k),
                "次序": 序号,              # 0 = 最底（原版 addBack 顺序）
                "no": no,
                "类别": 类,
                "bS": bS,
                "type": int(v.get("type", 0)),
                "rx": int(v.get("rx", 0)),
                "ry": int(v.get("ry", 0)),
                "x": int(v.get("x", 0)),
                "y": int(v.get("y", 0)),
                "a": int(v.get("a", 255)),
                "flip": int(v.get("f", 0)),
                "贴图": os.path.basename(路径) if 路径 else "",
                "尺寸": list(尺寸),
                "色数": 色数,
                "不透明占比": 不透明,
                "主色": list(主色),
            })
            统计[类] += 1
        表[mid] = {"目录": folder, "层": 本图}

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(表, f, ensure_ascii=False, indent=1, sort_keys=True)
    层数 = sum(len(v["层"]) for v in 表.values())
    print("标记 -> %s（%d 张图 / %d 层）" % (OUT, len(表), 层数))
    print("类别统计:", dict(统计))
    print("贴图去重后实际判过 %d 张图" % len(_缓存))

    seq = Counter()
    for mid, v in 表.items():
        seq[tuple(x["类别"] for x in v["层"])] += 1
    print("")
    print("按次序（底→顶，次序0 在最底）的类别序列：")
    for s, n in seq.most_common(12):
        print("   %-3d 张  %s" % (n, " → ".join(s)))

    print("\n木叶村：")
    for x in 表.get("100000000", {}).get("层", []):
        print("   次序%d 键%s no=%-2d type=%s rx=%-4s %-6s %s %s 不透明=%.2f" % (
            x["次序"], x["键"], x["no"], x["type"], x["rx"], x["类别"], x["尺寸"], x["贴图"], x["不透明占比"]))

    if args.表:
        with open(OUT表, "w", encoding="utf-8") as f:
            f.write("# 背景层标记（自动生成，勿手改；重跑 开发工具/识别背景层.py）\n\n")
            f.write("次序 = 地图数据里的键序，**0 在最底**（原版 `MapRender.drawBack()` 的加入顺序，后加的在上）。\n\n")
            f.write("| 地图 | 目录 | 次序 | no | 类别 | type | rx | ry | 尺寸 | 不透明 | 贴图 |\n")
            f.write("|---|---|---|---|---|---|---|---|---|---|---|\n")
            for mid, v in sorted(表.items()):
                for x in v["层"]:
                    f.write("| %s | %s | %d | %d | %s | %d | %d | %d | %s | %.2f | %s |\n" % (
                        mid, v["目录"], x["次序"], x["no"], x["类别"], x["type"], x["rx"], x["ry"],
                        "%dx%d" % tuple(x["尺寸"]), x["不透明占比"], x["贴图"]))
        print("\n表 -> %s" % OUT表)


if __name__ == "__main__":
    main()
