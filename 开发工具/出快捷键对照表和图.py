# -*- coding: utf-8 -*-
"""快捷键设置窗「真值对照表 + 并排证据」出件器。

跑法：python 开发工具/出快捷键对照表和图.py
产物（`测试/截图/快捷键窗_对照/`）：
  · `真值对照表.md`  —— 94 个时间轴命名件逐条：时间轴窗口坐标 → 页坐标（−29）→ .tscn 落点 → 差；
  · `对照输出.txt`   —— 同表的机器可读版（每行一条 OK/NG），给门禁日志用；
  · `两皮对照.png`   —— 左 = 原版整窗元件图（ffdec flatten），右 = 本工程整页渲染，同宽并排。

口径说明（写进表头，别当"像素门"看）：
  · 本表比的是**几何**：件的位置/尺寸 vs 时间轴 + KeyDef。运行期文字（键名/牌字/钮字）
    在元件图里是空的（`KeyboardCellF` 的 countTextField 运行期 visible=false），所以不逐像素比。
  · 原版整窗元件图把 background(530) **非等比自由拉伸**（ffdec flatten 不做九宫格），
    而本工程走宿主窗框的九宫格（§13:999 边距 48/29.25/48.05/13）⇒ 边框那圈本来就该不一样，
    比对只看键盘区与列表条的件位。
  · 列表条：元件图是原生 68 高，本工程按 `KF:128` 的 `height=(14+40<<1)+2=110` 出 ⇒ 右图下半截更高。
"""
import io
import json
import os
import re
import sys

from PIL import Image, ImageDraw

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚠️ 原来写死作者机的 naruto_godot；改成从本文件反推，见 §合并说明
出 = os.path.join(项目, "测试", "截图", "快捷键窗_对照")
抬 = 29.0

时轴 = json.load(io.open(os.path.join(项目, "数据", "界面", "快捷键_时间轴.json"), encoding="utf-8"))["件"]
键表 = json.load(io.open(os.path.join(项目, "数据", "界面", "键位表.json"), encoding="utf-8"))["表"]
场景文 = io.open(os.path.join(项目, "场景", "界面", "窗口", "设置", "快捷键窗.tscn"), encoding="utf-8").read()

# .tscn 里逐节点回读 offset_*（不依赖 Godot，纯文本），这样"实测"这一列不是抄期望表
件 = {}
for 块 in 场景文.split("[node ")[1:]:
    m = re.match(r'name="([^"]+)" type="([^"]+)" parent="([^"]*)"', 块)
    if not m:
        continue
    d = dict(re.findall(r"^(offset_left|offset_top|offset_right|offset_bottom) = ([-\d.]+)$", 块, re.M))
    if len(d) != 4:
        continue
    路 = (m[3] + "/" if m[3] != "." else "") + m[1]		# ⚠ m[0] 是整条匹配，节点名在 m[1]
    件[路] = [float(d["offset_left"]), float(d["offset_top"]),
              float(d["offset_right"]) - float(d["offset_left"]),
              float(d["offset_bottom"]) - float(d["offset_top"])]

行 = []
红 = 0


def 核(名, 路, 局, 注):
    global 红
    实 = 件.get(路)
    if 实 is None:
        红 += 1
        行.append((名, 局, "缺件", "—", 注, False))
        return
    d = max(max(abs(a - b) for a, b in zip(局, 实)), 0.0)
    if d > 1.0:
        红 += 1
    行.append((名, 局, "(%.0f,%.0f,%.0f,%.0f)" % tuple(实), "%.2f" % d, 注, d <= 1.0))


for 名, (号, 符号, x, y, sx, sy) in 时轴.items():
    if 符号 == "KeyboardCellF":
        键 = 名[:-4]
        宽 = float(键表.get(键, {}).get("width", 40))
        核(名, "格" + 名, [x, y - 抬, 宽, 40.0],
           "cellBg(550) 九宫 9/9/8/10；KeyDef %s width=%g canSet=%s" % (键, 宽, 键表.get(键, {}).get("canSet")))
    elif 符号 == "KeyboardFrameMButtonF":
        # KF:109-120 的右对齐链，本表独立复算（不吃生成器的期望表，免得两边同错自证自绿）
        链 = {"resetBtn": 765 - 14 - 54, "cancelEditBtn": 765 - 14 - 54 - 54 - 5}
        链["cancelBtn"] = 链["cancelEditBtn"] - 32 - 54
        链["okBtn"] = 链["cancelBtn"] - 32 - 5
        宽 = {"okBtn": 32, "cancelBtn": 32, "cancelEditBtn": 54, "resetBtn": 54}
        对应 = {"okBtn": "钮确定", "cancelBtn": "钮取消",
               "cancelEditBtn": "钮全部重置", "resetBtn": "钮全部消除"}[名]
        核(名, 对应, [链[名], y - 抬, 宽[名], 22.0],
           "KF:109-120 宽 %d、isScale9Grid=false ⇒ 57×22 整张拉" % 宽[名])
    elif 名 == "keyboardListSprite":
        核("keyboardListSprite→九宫列表底", "九宫列表底", [0, 345 - 抬, 765, 110],
           "546 原生 765×68；KF:128 height=(14+40<<1)+2=110；§13:1086 边距 21/16/21.05/19")
    elif 名 == "background":
        print("   background(530) %.1f×%.1f → 765×345 = 宿主窗框，页内不铺（§13:999 边距 48/29.25/48.05/13）"
              % (275 * sx, 394 * sy))
    else:
        print("   %s (%s) @ (%.0f,%.0f) = 宿主件（标题/关闭钮），页内不重复" % (名, 符号, x, y))

# 页内自造件（运行期建的）也要有行：列表格 34 + 方案钮 6
x0 = (765 - 17 * 42 - 2) // 2
y0 = (110 - 2 * 40 - 2) // 2
for i in range(34):
    核("列格%d（KF:131-143 运行期）" % i, "列格%d" % i,
       [x0 + i % 17 * 42, 345 - 抬 + y0 + (i // 17) * 42, 40, 40], "KeyboardListCellF(844) 40×40")
for i in range(1, 6):
    核("keyScheme%d（KF:766-785 运行期）" % i, "钮方案%d" % i,
       [14 + (i - 1) * 75, 317 - 抬, 72, 22], "宽 72、isScale9Grid=false；i=1 带 selectedUpSkin(554)")
核("saveSchemeBtn（KF:786-793 运行期）", "钮保存方案", [392, 317 - 抬, 72, 22], "14+5·75+3=392、宽 72")


def 主():
    os.makedirs(出, exist_ok=True)
    with io.open(os.path.join(出, "真值对照表.md"), "w", encoding="utf-8") as f:
        f.write("# 快捷键设置窗（KeyboardFrame）逐件真值对照表\n\n")
        f.write("比对口径：本表比**几何**（件位/尺寸 vs 时间轴 + KeyDef），不逐像素 —— 原版元件图里"
                "运行期文字是空的（`KeyboardCell.as:61` 把 countTextField 设成 visible=false）。\n"
                "元件图把 background(530) 非等比自由拉伸（ffdec flatten 不做九宫格），本工程走宿主窗框"
                "九宫格（§13:999）⇒ 边框那圈本就该不同，比对只看键盘区与列表条的件位。\n"
                "列表条：元件图原生 68 高，本工程按 `KF:128` 出 110 高。\n\n")
        f.write("出处：`game-client/真值/窗口/设置.md` §8 · `数据/界面/快捷键_时间轴.json`（tag 558 的 94 个命名实例）\n")
        f.write("· `KeyDef.as:297-815`（格标签/格宽/可绑）· `KeyboardCell.as:61,99` · `KeyboardListCell.as:44-49`\n")
        f.write("· `KeyboardShortcurIcon.as:24-44` · `共用件度量表.md` §13:996/997/999/1086\n\n")
        f.write("窗 765×455 = background(530) 765×345 + 列表条 110；页 = 窗 − 拖动区高 29 ⇒ 765×426。\n\n")
        f.write("| 时间轴件 / 运行期件 | 页坐标期望 (x,y,w,h) | .tscn 实测 | 最大差 px | 皮与出处 | 判 |\n")
        f.write("|---|---|---|---|---|---|\n")
        for 名, 局, 实, d, 注, ok in 行:
            f.write("| `%s` | (%g,%g,%g,%g) | %s | %s | %s | %s |\n" % (
                名, 局[0], 局[1], 局[2], 局[3], 实, d, 注, "OK" if ok else "**NG**"))
        f.write("\n**合计 %d 件，NG %d 件。**\n" % (len(行), 红))
    with io.open(os.path.join(出, "对照输出.txt"), "w", encoding="utf-8") as f:
        for 名, 局, 实, d, 注, ok in 行:
            f.write("%s %s 期望(%g,%g,%g,%g) 实测%s 差%s\n" % (
                "OK" if ok else "NG", 名, 局[0], 局[1], 局[2], 局[3], 实, d))
        f.write("合计 %d 件，NG %d\n" % (len(行), 红))
    # 并排图：左 = 原版整窗元件图（缩到 765 宽），右 = 本工程整页渲染（裁页框）
    参 = Image.open(os.path.join(
        项目, "_tmp", "ffdec_jiazu", "mainlib",
        "DefineSprite_558_KeyboardFrameF_KeyboardFrameF", "1.png")).convert("RGB")
    参 = 参.crop((2, 2, 767, 415)).resize((765, 413), Image.LANCZOS)
    我 = Image.open(os.path.join(项目, "测试", "截图", "设置_对照", "快捷键_开窗.png")).convert("RGB")
    我 = 我.crop((120, 40, 120 + 765, 40 + 426))
    布 = Image.new("RGB", (765 * 2 + 30, 456), (24, 24, 24))
    布.paste(参, (0, 26))
    布.paste(我, (765 + 30, 26))
    d = ImageDraw.Draw(布)
    d.text((4, 8), "LEFT = original KeyboardFrameF flatten (765x413, no runtime text, list strip native 68)",
           fill=(230, 230, 230))
    d.text((765 + 34, 8), "RIGHT = Godot port (765x426 page, list strip 110 per KF:128)", fill=(230, 230, 230))
    布.save(os.path.join(出, "两皮对照.png"))
    print("对照表 %d 件、NG %d；并排图 → %s" % (len(行), 红, os.path.join(出, "两皮对照.png")))
    if 红:
        raise SystemExit(1)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    主()
