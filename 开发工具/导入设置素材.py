# -*- coding: utf-8 -*-
"""设置页 / 快捷键窗皮肤导入器：从 ffdec 的元件图导出缓存里挑出本页要用的皮，
落到 `素材/界面/原版窗口/设置/`，并**逐张与工程既有通用件做同源核验**（不同源就单独出，不复用）。

为什么单独一个目录：这一页的皮是 `KeyboardFrame*` 前缀的**窗口自带副本**，
和 `通用控件/` 那几张**同名不同图** —— 实测 `KeyboardFrameMYellow_background` 原生 **263×349**，
而 `通用控件/内容面板.png` 是 263×252（§13 边距也不同：11/10/10/12.05 vs 11/10/10/11）。

跑法：python 开发工具/导入设置素材.py
     → Godot --path . --headless --import
"""
import io
import json
import os
import shutil
import sys

from PIL import Image

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚠️ 原来写死作者机的 naruto_godot；改成从本文件反推，见 §合并说明
缓存 = os.path.join(项目, "_tmp", "ffdec_jiazu", "mainlib")
出 = os.path.join(项目, "素材", "界面", "原版窗口", "设置")

# tag → (落到设置目录的文件名, 出处说明, 可与工程哪张既有件对照)
需 = {
    532: ("内容底.png", "KeyboardFrameMYellow_background 263×349（SCW 时间轴 (6,39) 拉 1.5628×1.0860 ⇒ 411×379）", None),
    540: ("页签未选.png", "SystemConfigWindowMTabButton_up 39×22（§13:1073 边距 7.25/7.5/7/4.75）", None),
    538: ("页签选中.png", "SystemConfigWindowMTabButtonF 的 selectedUpSkin（tag 541 时间轴第 0 层，未导出无名）", None),
    103: ("复选框未选.png", "KeyboardFrameMCheckBoxF 的 upSkin（tag 542 第 1 层）19×19", "通用控件/复选框未选.png"),
    100: ("复选框选中.png", "KeyboardFrameMCheckBoxF 的 selectedUpSkin（tag 542 第 0 层）19×19", "通用控件/复选框选中.png"),
    534: ("子面板.png", "KeyboardFrameMPane_background 253×212（§13:998 边距 7.5/6.75/7/7.25）", "通用控件/子面板.png"),
    530: ("窗口边框.png", "KeyboardFrameMWindow_background 275×394（§13:999 边距 48/29.25/48.05/13）", "通用控件/窗口边框.png"),
    535: ("关闭钮.png", "KeyboardFrameMWindowCloseBtnF 25×24", "通用控件/关闭按钮.png"),
    # 快捷键窗
    # ⚠ 552（KeyboardCellF 整元件图 44×44）**故意不导**，建格要的是**内层 cellBg = tag 550**：
    #   · `KeyboardCell.as:99` 在 KEYBOARD_FRAME 下 `cellBg.width = KeyDef.width` ⇒ 宽键要拉伸，
    #     用 552 整图拉会把烘在里面的设计期 countTextField「0」一起抹糊；
    #   · `KeyboardCell.as:61` 构造里 `countTextField.visible = false` ⇒ 运行期根本没有那个「0」。
    #   550 是干净底片 40×40，§13:996 边距 9/9.5/8.75/10 ⇒ 九宫格拉伸。
    550: ("键位格底.png", "KeyGrid_background 40×40（KeyboardCellF 的 cellBg，§13:996 边距 9/9.5/8.75/10）", None),
    844: ("键位列表格.png", "KeyboardListCellF 40×40（KF:131-143 17 列 × 2 行、格距 42）", None),
    # 列表格上叠的是 KeyboardShortcurIconF（36×36）——但 `-export sprite` 出的 1122 烘进了
    # 设计期 tf 的「一二三四」占位字。真皮是它的底片位图 1119（shape 1120 只有这一个填充）：
    #   ffdec-cli -export image <目录> MainLib.swf  →  <目录>/1119.png
    # 对照过：1122 与 1119 的 1284 个双不透明像素里只差 149 个，且差异全在字形区。
    1119: ("图标底板.png", "KeyboardShortcurIconF 的底片位图 1119（36×36；1122 元件图烘了设计期占位字，不能用）", None),
    546: ("键位列表底.png", "keyboardList_background 765×68（§13:1086 边距 21/16/21.05/19）", None),
    556: ("钮底.png", "KeyboardFrameMButton_up 57×22（§13:997 边距 7.15/7.15/7.3/7）", "通用控件/按钮.png"),
    554: ("钮底选中.png", "KeyboardFrameMButton_selectedUp 57×22", None),
}


def 找缓存(号):
    前 = "DefineSprite_%d_" % 号
    完 = os.path.join(缓存, 前.rstrip("_"))
    if os.path.isdir(完):
        return 完
    for 名 in os.listdir(缓存):
        if 名.startswith(前):
            return os.path.join(缓存, 名)
    位 = os.path.join(缓存, "DefineBitmap_%d" % 号)		# 纯位图皮（ffdec `-export image` 的产物）
    if os.path.isdir(位):
        return 位
    raise SystemExit("缓存里没有 tag %d（先按 flash-swf-asset-probe 的口径重导 MainLib 元件图）" % 号)


def 同源(a, b):
    甲 = Image.open(a).convert("RGBA")
    乙 = Image.open(b).convert("RGBA")
    if 甲.size != 乙.size:
        return "尺寸不同 %s vs %s" % (甲.size, 乙.size)
    相 = 0
    差 = 0
    for p in zip(甲.getdata(), 乙.getdata()):
        if p[0] == p[1]:
            相 += 1
        else:
            差 = max(差, max(abs(x - y) for x, y in zip(p[0][:3], p[1][:3])))
    return "全等 %d/%d，不透明区 RGB 最大差 %d" % (相, 甲.size[0] * 甲.size[1], 差)


def 主():
    os.makedirs(出, exist_ok=True)
    表 = {}
    for 号, (名, 注, 对照) in 需.items():
        d = 找缓存(号)
        源 = os.path.join(d, "1.png")
        if not os.path.isfile(源):
            源 = sorted(f for f in os.listdir(d) if f.endswith(".png"))[0]
            源 = os.path.join(d, 源)
        落 = os.path.join(出, 名)
        shutil.copy2(源, 落)
        尺 = Image.open(落).size
        行 = {"tag": 号, "原生": [尺[0], 尺[1]], "出处": 注}
        话 = ""
        if 对照:
            全 = os.path.join(项目, "素材", "界面", "原版窗口", 对照)
            if os.path.isfile(全):
                话 = "　对照 %s：%s" % (对照, 同源(落, 全))
                行["与通用件对照"] = 同源(落, 全)
        print("   %-16s tag=%-5d %dx%d%s" % (名, 号, 尺[0], 尺[1], 话))
        表[名] = 行
    with io.open(os.path.join(出, "皮肤对照.json"), "w", encoding="utf-8") as f:
        json.dump(表, f, ensure_ascii=False, indent=1)
    print("→ %s（%d 张）+ 皮肤对照.json" % (出, len(需)))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    主()
