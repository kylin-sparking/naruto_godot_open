# -*- coding: utf-8 -*-
"""出「秘笈合成」（原版 `JiNengCompositeWindow`，340×381，一个页签）的对证图。
原语全在 `开发工具/对证库.py`；本页只放表与判定。逐件出处见同目录 `真值对照表.md`。

用法：
    python 开发工具/出秘笈合成对照图.py        # 退出码 0 = 全部通过
"""
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from 对证库 import (九宫格拉伸, 加亮, 叠, 并排, 比对, 条, 数组, 文件级, 窗口截图,  # noqa: E402
                   红计数类)
import numpy as np  # noqa: E402

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
截图 = os.path.join(工程, "测试", "截图")
客户目录 = os.path.join(截图, "秘笈合成")
出目录 = os.path.join(截图, "秘笈合成_对照")
元件根 = os.path.join(os.environ.get("NARUTO_ELEMENT_ROOT")
	or os.path.join(工程, "..", "原版源数据", "元件图"), "sprites")
通用 = os.path.join(工程, "素材", "界面", "原版窗口", "通用控件")
专用 = os.path.join(工程, "素材", "界面", "专用控件")
倍 = 8
抬 = 29
# 九宫格边距 [左, 右, 上, 下]。**只认《共用件度量表》§13**（= `脚本/界面/原版皮肤表.gd`），禁拟合值：
#   MYellow(10)   splitter (220,200)-(5060,4820)÷20 ⇒ 11/10/10/11（旧表里那个"下 20"是建 §13 前拟合的）
#   MPane(97)     7.5/6.75/7/7.25 → 工程整数化 8/7/7/7（全工程共用一张，改它牵动所有页）
#   ItemArrow(1016) (85,20)-(195,135)÷20 ⇒ 左4.25/上1/右4.25/下9.25（下帽就是箭头）
#   ComboBox_*Skin  见 `生成秘笈合成场景.py` 的 图 表（右帽 22 上下 = 箭头按钮）
九宫格 = {
    "MYellow_background": [11, 10, 10, 11],
    "MPane_background": [8, 7, 7, 7],
    "ItemArrow": [4.25, 4.25, 1, 9.25],
    "ComboBox_disabledSkin": [6, 21.75, 5.5, 5.25],
}
门 = 红计数类()


def 元件(符号):
    return Image.open(os.path.join(元件根, 符号, "1.png")).convert("RGBA")


def 素材(根, 名):
    return Image.open(os.path.join(根, 名)).convert("RGBA")


内容整块 = None


def 垫内容(框):
    """子面板的边是半透明的 ⇒ 参照必须先垫上同一套 MYellow 九宫格底（宝石工艺实测：不垫 50~82% 假红）。"""
    global 内容整块
    if 内容整块 is None:
        内容整块 = 九宫格拉伸(素材(通用, "内容面板.png"), 330, 290, 九宫格["MYellow_background"])
    左 = int(round(框[0])) - 5
    上 = int(round(框[1])) - 29
    return 内容整块.crop((左, 上, 左 + int(round(框[2])), 上 + int(round(框[3]))))


def 皮级(名, 客户路径, 参照, 已知=""):
    过, 话 = 文件级(素材(*客户路径), 参照)
    if not 过 and not 已知:
        门.红项(名, 话)
    门.记("%-34s 文件级 %s｜%s%s" % (名, "√" if 过 else "!!", 话,
                               "" if not 已知 else "← 已知未决：" + 已知))


def 像素级(名, 参照, 页, 框, 说明, 环=None, 率上限=1.0, 不判底=False, 不判右=False, 备注="", 不判区=None):
    客 = 窗裁.裁(框, 页)
    if 客.size != 参照.size:
        门.红项(名, "裁块 %s 与参照 %s 尺寸不同" % (客.size, 参照.size))
        return
    超, 判, 偏 = 比对(客, 参照, 环=环, 不判底=不判底, 不判右=不判右, 不判区=不判区)
    率 = 0.0 if 判 == 0 else 100.0 * 超 / 判
    过 = 率 <= 率上限
    if not 过:
        门.红项(名, "超阈值 %.2f%%（%d/%d）" % (率, 超, 判))
    门.记("%-34s 像素级 %s 偏移%s 判 %d 超 %d（%.2f%%，门 %.1f%%%s）｜%s" % (
        名, "√" if 过 else "!!", 偏, 判, 超, 率, 率上限, "，环 %d" % 环 if 环 is not None else "", 说明))
    if 备注:
        门.记("%-34s   ↳ %s" % ("", 备注))


def 主():
    global 窗裁
    窗裁 = 窗口截图(客户目录, (0,), 抬=抬)
    门.记("秘笈合成对证｜截图来自 开发工具/截秘笈合成页.gd；倍率 %d×；抬 %dpx" % (倍, 抬))
    门.记("")
    门.记("=== 一、素材来源（文件级）===")
    皮级("内容面板 ← MYellow_background", (通用, "内容面板.png"),
         元件("DefineSprite_10_MYellow_background_MYellow_background"))
    皮级("子面板 ← MPane_background", (通用, "子面板.png"),
         元件("DefineSprite_97_MPane_background_MPane_background"))
    皮级("物品格 ← MGrid_background", (通用, "物品格.png"),
         元件("DefineSprite_172_MGrid_background_MGrid_background"),
         已知="工程这张的 alpha 被洗白过（`物品格.png.bak_alpha`），亲热天堂那轮已挂起")
    皮级("横向分隔线 ← LineHPicF", (通用, "横向分隔线.png"),
         元件("DefineSprite_133_LineHPicF_LineHPicF"))
    皮级("按钮 ← MButton_up", (通用, "按钮.png"), 元件("DefineSprite_18_MButton_up_MButton_up"),
         已知="与 DefineSprite_18 不同源（alpha 差 118 像素），亲热天堂那轮挂起的共享素材问题")
    皮级("分页按钮未选 ← MTabButton_up", (通用, "分页按钮未选.png"),
         元件("DefineSprite_121_MTabButton_up_MTabButton_up"))
    皮级("分页按钮选中 ← MTabButton_disabled", (通用, "分页按钮选中.png"),
         元件("DefineSprite_118_MTabButton_disabled_MTabButton_disabled"))
    皮级("方向箭头 ← ItemArrow", (通用, "方向箭头.png"),
         元件("DefineSprite_1016_ItemArrow_ItemArrow"))
    for 名, 符 in [("下拉框", "DefineSprite_614_ComboBox_upSkin_ComboBox_upSkin"),
                   ("下拉框悬停", "DefineSprite_620_ComboBox_overSkin_ComboBox_overSkin"),
                   ("下拉框按下", "DefineSprite_623_ComboBox_downSkin_ComboBox_downSkin"),
                   ("下拉框禁用", "DefineSprite_617_ComboBox_disabledSkin_ComboBox_disabledSkin")]:
        皮级("%s ← %s" % (名, 符.split("_", 2)[2]), (通用, "%s.png" % 名), 元件(符))
    # 复选框：原版只导出合成件 `MCheckBoxF`(105，73×19)，方框就是它左端那 19×19
    盒 = 元件("DefineSprite_105_MCheckBoxF_MCheckBoxF").crop((0, 0, 19, 19))
    皮级("复选框未选 ← MCheckBoxF 左端 19×19", (通用, "复选框未选.png"), 盒)
    过选, 话 = 文件级(素材(通用, "复选框选中.png"), 盒)
    门.记("%-34s 文件级 ―― %s｜与未选同一位置比：%s" % (
        "复选框选中（selectedUpSkin）", "不判红（见说明）", 话))
    门.记("%-34s   ↳ 阳性对照：同一条 `swf_probe` 命令能查到 MCheckBoxF(chid=105)，"
          "而 MCheckBox_up/selected/selectedUp 三个名字在导出表里真没有 ⇒ 选中态那张是嵌套元件，"
          "名字查不到；沿用工程既有件，勾 = 与未选差 48 像素" % "")
    未选 = 素材(通用, "分页按钮未选.png")
    同 = list(素材(专用, "分页按钮未选_悬停.png").getdata()) == list(加亮(未选, 30).getdata())
    if not 同:
        门.红项("页签悬停 +30", "与 getLightFilter 公式不一致")
    门.记("%-34s 公式级 %s（+30 = skinFilters.over）" % ("分页按钮未选_悬停", "√ 逐字节等于" if 同 else "!! 不等"))
    门.记("")

    门.记("=== 二、渲染级（只判没压东西的边带）===")
    子皮 = 素材(通用, "子面板.png")
    框残卷区 = [13, 99, 83, 214]
    框结果区 = [100, 241, 229, 70]
    像素级("内容框 330×290", 九宫格拉伸(素材(通用, "内容面板.png"), 330, 290, 九宫格["MYellow_background"]),
           0, [5, 29, 330, 290], "JiNengCompositeWindow.as:188-189 (340−5×2)×(381−91) @(5,58)", 环=6,
           不判右=True, 不判区=[(5, 0, 59, 2)],
           备注="环 6：内容盒里最近的件在 8px（CONTENT_GAP），而下沿的 ItemDropBox 占到 y=284 ⇒ 环 7 会压到它的边框。右带不判：说明文本盒 = 340−16 = 324 从 "
                "x=8 起，原版就让它超出 330 宽的面板 2px ⇒ 文字压在右边框上，比的不是皮",
           )
    门.记("%-34s   ↳ 不判区 (5,0,59,2)【件内坐标】：`:191-192` 先 addChild(_contentBox) 再 addChild(_tabBar) "
          "⇒ 页签条 window y 38..60 压在内容盒 window y 58 起点的**上沿 2px** 上（唯一那枚页签宽 54，"
          "内容盒局部 x 5..59），那两行本来就该是页签皮。原版叠压、不是移植错；与宝石工艺同一条。"
          "旧场景把 分页 排在 内容框 之前 ⇒ 这条红当时被层序错误掩盖。" % "")
    像素级("放入残卷区 83×214", 叠(垫内容(框残卷区),
           九宫格拉伸(子皮, 83, 214, 九宫格["MPane_background"])),
           0, 框残卷区, "ItemDropBox(true) @(8,70)", 环=6,
           备注="环 6：区内 dropBtn 在 (11,10)、格在 x=21.5")
    像素级("结果区 229×70", 叠(垫内容(框结果区),
           九宫格拉伸(子皮, 229, 70, 九宫格["MPane_background"])),
           0, 框结果区, "_resultBox @(95,212) 宽=340−8−83−20=229", 环=3,
           备注="环 3：区内 _resultTextField 在 (2,2)+padding4 ⇒ 文字离边 6px")
    像素级("方向箭头 14×87", 九宫格拉伸(素材(通用, "方向箭头.png"), 14, 87, 九宫格["ItemArrow"]),
           0, [47.5, 176, 14, 87], "ItemDropBox:36-38 h=214−127=87", 率上限=4.0,
           备注="落点 x=(83−14)/2=34.5 带半像素 ⇒ 门放宽到 4%")
    # 下拉：本轮才把四态皮**接到件上**（PNG 早就导好了但没接 ⇒ 实机是 Godot 默认主题黑框），
    # 初始态是 disabled（`_comboBox.enabled=false` `:248`）⇒ 参照取 `下拉框禁用.png`(617)。
    # 环 2：文字框 = fl `inputField` @(3,3) 宽 W−24 ⇒ 第 0/1 列只有皮；箭头在右帽里不被压。
    框下拉 = [202, 285, 45, 22]
    像素级("下拉框(禁用态) 45×22", 叠(垫内容(框下拉),
           九宫格拉伸(素材(通用, "下拉框禁用.png"), 45, 22, 九宫格["ComboBox_disabledSkin"])),
           0, 框下拉, "MComboBox width=45 @(102,44) + ComboBox_disabledSkin(617) 九宫格", 环=2,
           备注="这条判的是「皮到底接没接到件上」：`MenuButton` 默认 flat=true 会整块不画背景，"
                "接错就整条红（宝石工艺页实测 90.35%）")
    门.记("%-34s 像素级 ―― 不适用：件上必压文字，改由「一、文件级」+ 量具 + 8× 交" % "页签 / 复选框")
    门.记("")

    门.记("=== 三、8 倍单件放大图 ===")

    def 放(框, 倍率=倍, 页=0):
        im = 窗裁.裁(框, 页)
        return im.resize((im.width * 倍率, im.height * 倍率), Image.NEAREST)
    for 名, 项目, 标题 in [
        ("8x_页签与说明.png", [
            ("页签+说明+线", 放([5, 29, 330, 70], 6), "1 个页签（宽=文字宽+6）；说明 3 行 #ff9100，线在文本盒下 2px"),
            ("材料说明", 放([100, 161, 180, 38]), "2 行白；「幸运符：」= 原文占位符 5 换成 helpItem 名")],
         "① 页签条与文字块（分隔线位置 = textHeight+4 规则）"),
        ("8x_放入残卷区.png", [
            ("放入残卷区", 放(框残卷区), "钮 61×22 / 主残卷格 40 / 箭头 14×87 / 秘籍格 40")],
         "② ItemDropBox(true)：与宝石工艺同一个类，只是 y=70"),
        ("8x_材料格排.png", [
            ("四格", 放([100, 99, 230, 88]), "HBox gap=2 ⇒ x=100/158/216/274；第 4 格多一颗 37×22 购买钮"),
            ("第4格", 放([274, 99, 56, 88]), "标签=幸运符（item 16000015）+ 购买")],
         "③ ItemCaiLiaoBox ×4（_fu2/_fu3 原版永远是空格子，别填假数据）"),
        ("8x_结果区.png", [
            ("结果区", 放(框结果区), "文本 (6,6)207×38 + 勾选 98×19 + 下拉 45×22 + 个幸运符"),
            ("下拉行", 放([104, 285, 147, 27]), "下拉初始 disabled ⇒ 用 disabledSkin；42/45 宽都小于 OptionButton 的 64 地板")],
         "④ 结果区：TextArea2 + MCheckBoxF + MComboBox + MGlowLabel")]:
        路, 尺 = 条(项目, os.path.join(出目录, 名), 标题)
        门.记("出 %s  %s" % (os.path.relpath(路, 工程), 尺))
    路, 尺 = 并排([("秘笈合成（原版 340×381）", 窗裁.图[0])], os.path.join(出目录, "整窗.png"), None)
    门.记("出 %s  %s" % (os.path.relpath(路, 工程), 尺))
    门.记("")
    门.记("=== 结论 ===")
    门.记("红项 %d 个" % 门.红)
    门.落盘(os.path.join(出目录, "对照输出.txt"))


if __name__ == "__main__":
    主()
    sys.exit(门.退出码())
