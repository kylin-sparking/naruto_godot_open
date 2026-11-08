# -*- coding: utf-8 -*-
"""把九帧**按注册点对齐**裁成同样大小、竖着叠成一列，画两条水平基准线 ⇒
盘对没对上，肉眼直接看出来（不再靠某把尺子的数字说话）。

为什么还要这张图：`配盘定基准.py` 的 RGB 花纹配准给的是"偏移全 0"，但它自己同时打了
**七帧"不尖"**（最佳格与周边 8 邻的色差只差几）⇒ 那个数其实**分辨不出位置**，
我不该拿它当"盘没动"的证据。用户实机说"还有一点点飘" ⇒ 得换一张能看的图。

用法：python 开发工具/裁盘对齐看.py
产物：测试/截图/打坐/盘对齐列.png（每格 200×84，注册点固定在格内同一处）
"""
import io
import json
import os
import sys

from PIL import Image, ImageDraw

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
表路 = os.path.join(工程, "数据", "界面", "打坐光环.json")
出 = os.path.join(工程, "测试", "截图", "打坐", "盘对齐列.png")
宽, 高 = 200, 84
原点x格, 原点y格 = 100, 30		# 注册点固定在每格这个位置
放大 = 2


def main():
    表 = json.load(io.open(表路, encoding="utf-8"))
    帧表 = 表["帧"]
    第0 = 帧表[0]
    基准心 = int(第0["阵心"]) - int(第0["原点x"])
    基准底 = int(第0["阵底"]) - int(第0["原点y"])
    格宽, 格高 = 宽 * 放大, 高 * 放大
    图 = Image.new("RGB", ((格宽 + 10) * 2, (格高 + 6) * len(帧表)), (16, 18, 26))
    画 = ImageDraw.Draw(图)
    for i, 帧 in enumerate(帧表):
        像 = Image.open(os.path.join(工程, 帧["文件"][len("res://"):])).convert("RGBA")
        原x, 原y = int(帧["原点x"]), int(帧["原点y"])
        挪x = (int(帧["阵心"]) - 原x) - 基准心
        挪y = (int(帧["阵底"]) - 原y) - 基准底
        # 裁一块"以注册点为锚"的窗：画布上的 (原x,原y) 必须落在裁图 (原点x格,原点y格)。
        # ⚠ 第一版写成 `原点x格 − 左`（左 = 原x − 原点x格）⇒ 等于多挪了一整个原点，
        #   盘被推到格子右边缘外面、参考线也全错位（图看着"对不上"其实是裁图错了）。
        for 栏 in range(2):
            dx = 0 if 栏 == 0 else 挪x
            dy = 0 if 栏 == 0 else 挪y
            块 = Image.new("RGBA", (宽, 高), (16, 18, 26, 255))
            块.alpha_composite(像, (原点x格 - 原x - dx, 原点y格 - 原y - dy))
            块 = 块.resize((格宽, 格高), Image.NEAREST)
            x0 = 栏 * (格宽 + 10)
            y0 = i * (格高 + 6)
            图.paste(块, (x0, y0))
            画 = ImageDraw.Draw(图)
            画.line([(x0, y0 + 原点y格 * 放大), (x0 + 格宽, y0 + 原点y格 * 放大)], fill=(255, 255, 255), width=1)
            画.line([(x0, y0 + (原点y格 + 基准底) * 放大), (x0 + 格宽, y0 + (原点y格 + 基准底) * 放大)],
                    fill=(0, 255, 255), width=1)
            画.text((x0 + 4, y0 + 2), "f%d 原点(%d,%d) 阵底%s 阵心%s 补(%d,%d)"
                     % (i, 原x, 原y, 帧.get("阵底"), 帧.get("阵心"), dx, dy), fill=(255, 255, 0))
    画.text((6, 2), "左列=只照原版公式   右列=按八卦阵钉过   白线=注册点 青线=第0帧盘下沿",
            fill=(255, 255, 255))
    图.save(出)
    print("出图 %s" % 出)
    print("判读：白线=注册点那一行、青线=第 0 帧那块盘的下沿那一行。")
    print("  左列若有几格的盘沉到青线下面 ⇒ 素材自己会飘；右列九格的盘都该压在青线上 ⇒ 钉对了。")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
