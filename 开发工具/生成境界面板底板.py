# -*- coding: utf-8 -*-
"""导出「忍术境界」子面板（符号 936 `SkillStatesPaneF`）并抹掉作者期占位文字。

它是什么
--------
`SkillWindow.as:413` 点右上角「忍术境界」按钮时 new 出来的面板，从右滑入盖住详情区。
`SkillStatesPane.as`：标题 `UI_57`=「忍术境界」摆在 (80,9)，7 个 `SkillStatesPaneCell`
（元件 935，200x41）各显示一档境界，底部 `totalText` = 「当前忍术层数合计：N层」。

每档的文案与门槛（`CN.SKILL_STATES` + `SkillJingJie`）：

| 序 | 境名 | 门槛 | 图标 |
|---|---|---|---|
| 0 | 掌握忍术基础 | 100 | 下 |
| 1 | 新星崭露头角 | 250 | 中 |
| 2 | 精通特殊领域 | 450 | 特 |
| 3 | 实力非比寻常 | 700 | 上 |
| 4 | 忍界精锐部队 | 1000 | 暗 |
| 5 | 忍术登峰造极 | 1400 | 影 |
| 6 | 领悟忍学真谛 | 1900 | 仙 |

`setFilters(总层数)`：达到门槛的那一档去掉 `Style.getDisableFilter()`（图标恢复彩色）、
境名转金色 13087055；没达到是灰色 9671571 且图标灰掉。

为什么不能直接用符号的扁平导出
------------------------------
符号里烘了 7 行**作者期占位文字**（都是同一句「初窥武学门径 / 所有武学层数相加≥1900」，
而且用的是"武学"不是"忍术"——运行时全部由 AS3 重写成语言表里的文案）。
和 §3.1 加点区、学习方法底板同一条做法：只清占位、不动框与图标槽。

用法
----
    python 开发工具/生成境界面板底板.py

产物
----
    素材/界面/原版窗口/忍术/境界面板底板.png   （210x390，7 个图标槽 + 外框，无文字）
    素材/界面/原版窗口/忍术/境界图标_0..6.png   （下/中/特/上/暗/影/仙）
"""

from collections import Counter
import glob
import io
import json
import os
import subprocess
import sys

from PIL import Image

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版目录 = r"2.2.3"
FFDEC = os.path.join(原版目录, "ffdec_26.2.1", "ffdec-cli.exe")
SWF = os.path.join(原版目录, "www", "act_web_nya_208_isolated", "asset", "MainLib.swf")
境界SWF = os.path.join(原版目录, "www", "act_web_nya_208_isolated", "swf", "Effect",
                       "Effect_RenShuJingJie.swf")
临时目录 = os.path.join(项目根, "..", ".scratch", "技能补数据", "元件")
图标目录 = os.path.join(项目根, "..", ".scratch", "技能补数据", "境界图标")
素材目录 = os.path.join(项目根, "素材", "界面", "原版窗口", "忍术")
符号 = 936

# 各档图标对应的 SWF 字符号。
# ⚠️ 这一串是**用客户端实渲反推**出来的（先按估计的顺序接进去、截图对真机、再倒推），
# 不是靠肉眼读导出图——肉眼读那步我读反过，把 下中特上暗影仙 认成了 下上暗影仙中特。
图标顺序 = ["1", "4", "7", "10", "13", "16", "19"]  # 下 中 特 上 暗 影 仙

# 7 行：行顶 y = 37 + 48i（真机实测：图标框 34x34 在 x12，行距 48）
行距 = 48
首行顶 = 37
行数 = 7


def 导出符号() -> Image.Image:
    os.makedirs(临时目录, exist_ok=True)
    subprocess.run([FFDEC, "-selectid", str(符号), "-format", "sprite:png",
                    "-export", "sprite", 临时目录, SWF], capture_output=True, text=True)
    命中 = glob.glob(os.path.join(临时目录, "DefineSprite_%d_*" % 符号, "1.png"))
    if not 命中:
        raise SystemExit("ffdec 没有导出符号 %d" % 符号)
    return Image.open(命中[0]).convert("RGBA")


def 主() -> int:
    图 = 导出符号()
    print("符号 %d 导出 %dx%d" % (符号, 图.width, 图.height))
    像素 = 图.load()

    # 占位文字矩形（符号局部）。行内文字的 x 从 55 起就够——图标槽在 x 8..48。
    占位 = [("标题「忍术境界」", (75, 12, 145, 32))]
    for i in range(行数):
        y = 首行顶 + 行距 * i
        占位.append(("行%d 境名" % i, (55, y + 1, 210, y + 17)))
        占位.append(("行%d 说明" % i, (45, y + 18, 210, y + 34)))
    占位.append(("底部合计", (45, 368, 210, 390)))

    # ⚠️ 不能擦成透明：这一条带的**行背景是不透明的**（实测 `(57,38,32,129)`）。
    # 擦透明等于在上面挖个洞，面板滑到详情区上时那些洞会透出底下的详情区，
    # 实机看就是一行行"白/灰的条"压在境名和说明上（用户就是照这个报的）。
    # 正解是**用底色回填**：底色按列取，竖向上从该行**上下两侧**取样（那两段是纯背景、
    # 文字只占行内），再把这个矩形整片刷成该列底色 —— 清掉文字，同时保住行背景与右侧那道暗边。
    底色 = {}
    for 名, (x0, y0, x1, y1) in 占位:
        for x in range(x0, min(x1, 图.width)):
            样 = [像素[x, y] for y in range(max(0, y0 - 6), max(0, y0 - 2))]
            样 += [像素[x, y] for y in range(min(y1 + 1, 图.height - 1), min(y1 + 5, 图.height))]
            if 样:
                底色[x] = Counter(样).most_common(1)[0][0]
    清 = 0
    for 名, (x0, y0, x1, y1) in 占位:
        本区 = 0
        for y in range(y0, min(y1, 图.height)):
            for x in range(x0, min(x1, 图.width)):
                参考 = 底色.get(x)
                if 参考 is None or 像素[x, y] == 参考:
                    continue
                像素[x, y] = 参考
                本区 += 1
        清 += 本区
        print("  回填 %-18s (%d,%d)-(%d,%d)  %d 像素" % (名, x0, y0, x1, y1, 本区))
    print("清掉作者期占位（按列底色回填）%d 像素" % 清)

    os.makedirs(素材目录, exist_ok=True)
    产物 = os.path.join(素材目录, "境界面板底板.png")
    图.save(产物)
    print("-> %s" % 产物)

    # 7 档的文案与门槛：境名/门槛来自语言表 SKILL_STATES_TITLE_0..6 + SkillJingJie，
    # 说明与底部合计是带 %1 的模板。落成 JSON 给客户端读，别在 gd 里硬编码中文。
    sys.path.insert(0, 项目根 + "\开发工具")
    from 原版数据 import 语言
    门槛 = [100, 250, 450, 700, 1000, 1400, 1900]   # SkillJingJie.JINGJIE_1..7
    档 = [{"境名": 语言("SKILL_STATES_TITLE_%d" % i), "门槛": 门槛[i]} for i in range(7)]
    坐标产物 = os.path.join(项目根, "数据", "界面", "忍术境界.json")
    os.makedirs(os.path.dirname(坐标产物), exist_ok=True)
    io.open(坐标产物, "w", encoding="utf-8").write(json.dumps({
        "_说明": ("忍术境界的 7 档文案与门槛。境名来自语言表 SKILL_STATES_TITLE_0..6，"
                  "门槛来自 com/mxw/data/skill/SkillJingJie.as 的 JINGJIE_1..7，"
                  "说明模板 SKILL_STATES_REQ_FLOOR、底部 SKILL_TOTAL_SKILL_TIP。"
                  "解锁条件：总忍术层数 >= 50 才显示右上角按钮（SkillWindow.as:258）。"
                  "客户端 `技能面板` 里的计算见 忍术窗口.gd 的 _总忍术层数。"),
        "档": 档,
        "说明模板": 语言("SKILL_STATES_REQ_FLOOR"),
        "合计模板": 语言("SKILL_TOTAL_SKILL_TIP"),
        "按钮文案": 语言("SKILL_STATE"),
        "解锁门槛": 50,
    }, ensure_ascii=False, indent=1))
    print("-> %s（%s）" % (坐标产物, " / ".join(d["境名"] for d in 档)))

    # 7 个图标：从 Effect_RenShuJingJie.swf 导出，按真机上读到的顺序命名
    os.makedirs(图标目录, exist_ok=True)
    subprocess.run([FFDEC, "-export", "image", 图标目录, 境界SWF],
                   capture_output=True, text=True)
    for i, 号 in enumerate(图标顺序):
        源 = os.path.join(图标目录, 号 + ".png")
        if not os.path.exists(源):
            print("  ⚠ 缺图标 %s.png" % 号)
            continue
        Image.open(源).convert("RGBA").save(
            os.path.join(素材目录, "境界图标_%d.png" % i))
        print("  境界图标_%d.png <- %s.png" % (i, 号))
    return 0


if __name__ == "__main__":
    sys.exit(主())
