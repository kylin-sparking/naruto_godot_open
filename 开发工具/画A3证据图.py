# -*- coding: utf-8 -*-
"""A3 证据图：本次从原版 SWF 直解补回的素材，按清单各挑一件，8 倍最近邻放大 + 标注。

为什么要 8 倍单件 —— 并排全景里 34px 的图标看不出锯齿/错位，原版口径要求逐件放大对证。
取样直接读 数据/原版直解清单.json 的「落点」，图上标的就是台账里那条，可回查。
"""
import io
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
台账 = json.load(open(os.path.join(项目, "数据", "原版直解清单.json"), encoding="utf-8"))
输出 = os.path.join(项目, "测试", "输出", "A3_直解素材8倍_四类.png")

# 每个清单挑一条：物品图标 / 地图块 / 怪物 / 角色 / 技能动画元件（帧目录里取第 10 帧）
挑 = [
    ("物品图标", lambda v: v["清单"] == "物品图标"),
    ("地图块 Tile", lambda v: v["清单"] == "地图素材" and v["分类"] == "Tile"),
    ("怪物 Mob", lambda v: v["清单"] == "怪物素材"),
    ("角色 Char", lambda v: v["清单"] == "角色动画"),
    ("技能特效（80 帧动画元件·第 10 帧）", lambda v: v.get("形态")),
]

样本 = []
for 标签, 条件 in 挑:
    项 = next(((名, v) for 名, v in 台账.items() if 条件(v)), None)
    if 项 is None:
        print("台账里没有：", 标签)
        continue
    符号名, 条 = 项
    落点 = 条["落点"].replace("res://素材/", os.path.join(项目, "素材") + os.sep).replace("/", os.sep)
    if os.path.isdir(落点):
        落点 = os.path.join(落点, "10.png")
    样本.append((标签, 符号名, 落点, 条))

字体 = None
for 候选 in (r"C:\Windows\Fonts\simhei.ttf", r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\simsun.ttc"):
    if os.path.exists(候选):
        字体 = ImageFont.truetype(候选, 18)
        break

放大 = 8
格宽 = 600
格高 = 420
标题 = 78
列 = 3
行 = -(-len(样本) // 列)
画布 = Image.new("RGB", (格宽 * 列, (格高 + 标题) * 行 + 44), (24, 22, 20))
笔 = ImageDraw.Draw(画布)
笔.text((12, 12), "A3 本次从原版 SWF 直解补回的素材 · 每格按可用的最大整数倍最近邻放大（上限 8×，棋盘底=透明区）",
        fill=(232, 214, 160), font=字体)

for i, (桶名, 符号名, 路径, 条) in enumerate(样本):
    if not os.path.exists(路径):
        print("缺文件：", 路径)
        continue
    图 = Image.open(路径).convert("RGBA")
    原始 = 图.size
    # 8× 是硬要求，但 126×58 的地砖放大 8 倍就是 1008×464 —— 塞不进格就得缩放，缩了就不是 8×。
    # 所以取"塞得进格子的最大整数倍"，并把实际倍数标在图上，不留假象。
    倍数 = max(1, min(放大, int(min((格宽 - 20) / 原始[0], (格高 - 20) / 原始[1]))))
    图 = 图.resize((原始[0] * 倍数, 原始[1] * 倍数), Image.NEAREST)
    格 = Image.new("RGB", (格宽, 格高 + 标题), (30, 28, 26))
    格笔 = ImageDraw.Draw(格)
    for y in range(0, 格高, 16):
        for x in range(0, 格宽, 16):
            格笔.rectangle([x, y, x + 15, y + 15],
                           fill=(44, 42, 38) if (x // 16 + y // 16) % 2 == 0 else (26, 24, 22))
    格.paste(图, ((格宽 - 图.width) // 2, (格高 - 图.height) // 2), 图)
    格笔.text((10, 格高 + 4), 桶名, fill=(232, 214, 160), font=字体)
    格笔.text((10, 格高 + 26), 符号名, fill=(225, 225, 225), font=字体)
    格笔.text((10, 格高 + 48), "原始 %dx%d · 本图 %d× · 源库 %s.swf" % (原始[0], 原始[1], 倍数, 条["库名"]),
              fill=(150, 200, 150), font=字体)
    x, y = (i % 列) * 格宽, 44 + (i // 列) * (格高 + 标题)
    画布.paste(格.convert("RGB"), (x, y))
    print(桶名, 符号名, 原始, "→", os.path.relpath(路径, 项目))

画布.save(输出)
print("已写出", 输出, 画布.size)
