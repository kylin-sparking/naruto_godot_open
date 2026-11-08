import json
import os
from PIL import Image, ImageDraw, ImageFont

"""A2 交付物：特效「8 倍单件放大图」+ Buff 状态图标对照表。

为什么这么出：
  · 8 倍图要证明的是 **Godot 里画出来的那一块像素** 和 **原版 swf 解出来的那张原图** 完全一致
    （没被重采样、没被裁、origin 钉位没偏），所以两边都按同一个矩形裁出来再各自放大。
    只放原图 = 自证，没意义。
  · 对照表要证明的是 **每个 Buff 行拿到的是它自己那张图标**（className 逐行来自 dat，不是拼字符串），
    所以每格都标 `子类/键 + 名称 + 类名`，人眼能逐行核对。

跑法：python 开发工具/出特效与图标对照图.py
"""

项目目录 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
数据 = os.path.join(项目目录, "数据")
输出 = os.path.join(项目目录, "测试", "输出")
背景色 = (18, 20, 26)

# 与 测试/特效/特效回放.gd 里的 特效清单/钉帧清单 保持一致（改了那边要同步这里）
钉帧清单 = [
    {"名": "portalPV", "帧": 3, "锚点": (760, 500)},
    {"名": "levelUp", "帧": 10, "锚点": (170, 470)},
    {"名": "Effect_guaJiZhong", "帧": 20, "锚点": (230, 700)},
]
放大倍数 = 8


def 读JSON(文件名):
    with open(os.path.join(数据, 文件名), encoding="utf-8-sig") as f:
        return json.load(f)


def 中文字体(像素):
    for 路径 in (r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\simsun.ttc"):
        if os.path.exists(路径):
            return ImageFont.truetype(路径, 像素)
    return ImageFont.load_default()


def 特效八倍图():
    特效表 = 读JSON("特效.json")["特效"]
    for 项 in 钉帧清单:
        帧 = 特效表[项["名"]]["帧"][项["帧"]]
        原点x, 原点y = 帧["原点"]
        x = 项["锚点"][0] - 原点x
        y = 项["锚点"][1] - 原点y
        矩形 = (int(x), int(y), int(x + 帧["宽"]), int(y + 帧["高"]))
        屏幕 = Image.open(os.path.join(输出, "特效钉帧_%s_%d.png" % (项["名"], 项["帧"]))).convert("RGB")
        游戏内 = 屏幕.crop(矩形)
        原图 = Image.open(os.path.join(项目目录, 帧["贴图"].replace("res://", ""))).convert("RGBA")
        # 原图叠到同色底上再放大，避免透明区在两张图里看起来不一样
        底 = Image.new("RGB", 原图.size, 背景色)
        底.paste(原图, (0, 0), 原图)
        并排 = Image.new("RGB", (游戏内.width * 放大倍数 * 2 + 24, max(游戏内.height, 帧["高"]) * 放大倍数 + 34), (255, 255, 255))
        并排.paste(游戏内.resize((游戏内.width * 放大倍数, 游戏内.height * 放大倍数), Image.NEAREST), (8, 26))
        并排.paste(底.resize((帧["宽"] * 放大倍数, 帧["高"] * 放大倍数), Image.NEAREST), (8 + 游戏内.width * 放大倍数 + 24, 26))
        笔 = ImageDraw.Draw(并排)
        字 = 中文字体(20)
        笔.text((8, 2), "Godot 实机（%d 帧 @ 锚点 %s）" % (项["帧"], 项["锚点"]), font=字, fill=(0, 0, 0))
        笔.text((8 + 游戏内.width * 放大倍数 + 24, 2), "原版 swf 解出的原图（%dx%d）" % (帧["宽"], 帧["高"]), font=字, fill=(0, 0, 0))
        目标 = os.path.join(输出, "特效8倍_%s_帧%d.png" % (项["名"], 项["帧"]))
        并排.save(目标)
        尺寸对 = 游戏内.size == (帧["宽"], 帧["高"])
        # 只在原图 alpha=255 的像素上比：那里正常混合下 Godot 必须画出**一模一样**的颜色。
        # 半透明/空帧处不比（背景是地图，底图是纯色，比了必然不同，没有判定意义）。
        最大偏差, 覆盖数 = (-1, 0)
        if 尺寸对:
            盖 = 原图.getdata()
            最大偏差 = max((max(abs(a - b) for a, b in zip(pa, pb))
                           for pa, pb, s in zip(游戏内.getdata(), 底.getdata(), 盖) if s[3] == 255), default=0)
            覆盖数 = sum(1 for s in 盖 if s[3] == 255)
        print("特效8倍 -> 测试/输出/%s  裁区 %s  尺寸与源图一致=%s  不透明像素最大偏差 %d（应为 0，覆盖 %d px）"
              % (os.path.basename(目标), 矩形, 尺寸对, 最大偏差, 覆盖数))


def 图标对照表():
    图标表 = 读JSON("状态图标.json")
    行 = []
    for 键, 项 in 图标表["表"].items():
        行.append({"键": 键, "名称": 项.get("名称", ""), "类名": 项.get("类名", ""),
                   "贴图": 项.get("贴图", ""), "尺寸": "%dx%d" % (项.get("宽", 0), 项.get("高", 0)) if 项.get("贴图") else "—"})
    for 编号, 项 in 图标表["物品Buff"].items():
        行.append({"键": "BuffWuPin/" + 编号, "名称": "物品 Buff " + 编号, "类名": 项.get("类名", ""),
                   "贴图": 项.get("贴图", ""), "尺寸": "%dx%d" % (项.get("宽", 0), 项.get("高", 0))})
    行.sort(key=lambda r: r["键"])

    格宽, 格高, 列数 = 152, 62, 6
    行数 = (len(行) + 列数 - 1) // 列数
    画布 = Image.new("RGB", (格宽 * 列数 + 8, 格高 * 行数 + 34), (255, 255, 255))
    笔 = ImageDraw.Draw(画布)
    笔.text((8, 6), "Buff 状态图标对照表（%d 行；空格子 = 原版这行本来就没有 icon）" % len(行), font=中文字体(20), fill=(0, 0, 0))
    缺格 = 0
    for i, 项 in enumerate(行):
        格 = (8 + (i % 列数) * 格宽, 30 + (i // 列数) * 格高)
        笔.text((格[0], 格[1]), 项["键"], font=中文字体(11), fill=(60, 60, 60))
        笔.text((格[0], 格[1] + 13), (项["名称"][:6] + " " + 项["尺寸"]), font=中文字体(11), fill=(120, 40, 40))
        if 项["贴图"]:
            图 = Image.open(os.path.join(项目目录, 项["贴图"].replace("res://", ""))).convert("RGBA")
            格内 = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
            格内.paste(图, ((40 - 图.width) // 2, (40 - 图.height) // 2), 图)
            画布.paste(格内, (格[0] + 96, 格[1] + 6), 格内)
            全透 = all(a < 8 for _, _, _, a in 图.getdata())
            if 全透:
                缺格 += 1
                笔.rectangle((格[0] + 96, 格[1] + 6, 格[0] + 136, 格[1] + 46), outline=(255, 0, 0), width=2)
        else:
            笔.rectangle((格[0] + 96, 格[1] + 6, 格[0] + 136, 格[1] + 46), outline=(190, 190, 190), width=1)
    目标 = os.path.join(输出, "Buff图标对照表.png")
    画布.save(目标)
    with open(os.path.join(输出, "Buff图标对照表.md"), "w", encoding="utf-8") as f:
        f.write("| 键 | 原版名称 | 类名（dat 里读出来的） | 尺寸 | 贴图 |\n|---|---|---|---|---|\n")
        for 项 in 行:
            f.write("| %s | %s | %s | %s | %s |\n" % (项["键"], 项["名称"], 项["类名"], 项["尺寸"], 项["贴图"] or "原版无 icon"))
    print("图标对照 -> 测试/输出/Buff图标对照表.png（%d 行，%d 格全透明）+ .md" % (len(行), 缺格))


特效八倍图()
图标对照表()
