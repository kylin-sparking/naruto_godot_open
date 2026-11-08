# -*- coding: utf-8 -*-
"""从量具表 `开发工具/截意志介绍页.gd` 生成 `场景/界面/窗口/遗址/意志介绍窗口.tscn`。

**改真值改量具表再重跑本文件，别手改 .tscn。**

只烘外壳 + 滚动条：原版列表是 `fl.controls.List`，行由 `dataProvider` 现造
（`YiZhiIntroduceWindow.drawList:56-71`）⇒ 行归控制器 `_填意志介绍行()` 管。

用法：python 开发工具/生成意志介绍场景.py
"""
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
量具 = os.path.join(工程, "开发工具", "截意志介绍页.gd")
出 = os.path.join(工程, "场景", "界面", "窗口", "遗址", "意志介绍窗口.tscn")
根 = "原版意志介绍内容"
NL = chr(10)
源码 = open(量具, encoding="utf-8").read()


def 表(名):
    i = 源码.find("const %s := {" % 名)
    assert i > 0, "量具表里没有 const %s" % 名
    j = 源码.find(NL + "}", i)
    return 源码[i + len("const %s := {" % 名) + 1:j]


def 解析(正文, 值解析):
    out = {}
    for 行 in 正文.split(NL):
        行 = re.sub(r"#.*$", "", 行)
        for m in re.finditer(r'"([^"]+)"\s*:\s*(\[[^\]]*\]|"[^"]*")', 行):
            out[m.group(1)] = 值解析(m.group(2))
    return out


件路径 = 解析(表("件路径"), lambda v: v.strip('"'))
件期望 = 解析(表("件期望"), lambda v: [float(x) for x in v.strip("[]").split(",")])

图 = {
    "黄底": ("原版窗口/通用控件/内容面板.png", [11, 10, 10, 11]),	# §13 MYellow，**不许拟合**
    "滚上": ("原版窗口/通用控件/滚动向上.png", [0, 0, 0, 0]),
    "滚槽": ("原版窗口/通用控件/滚动槽.png", [0, 0, 0, 0]),
    "滚块": ("原版窗口/通用控件/滚动滑块.png", [0, 0, 0, 0]),
    "滚下": ("原版窗口/通用控件/滚动向下.png", [0, 0, 0, 0]),
}
缺 = [k for k, (p, _) in 图.items() if not os.path.exists(os.path.join(工程, "素材", "界面", p))]
if 缺:
    print("!! 素材缺失:", 缺)
    sys.exit(1)
扩展id = {k: "t%d" % i for i, k in enumerate(图)}

路径规格 = {	# 键 = **相对根的完整路径**（与量具表 `件路径` 的值一致）
    "外框黄底": ("Panel", "黄底", None, False),
    # ⚠️ 列表区/竖条那几件**必须 STOP(0)**：原版 `fl.controls.List` 自带 ScrollBar，
    #   滚轮、点箭头、拖滑块都要收到事件。先前全烘成 IGNORE(2) ⇒ 38 行裁死也动不了
    #   （2026-09-28 用户报"意志介绍不能滑动"就是这个）。内容列保持 IGNORE：
    #   它是被移动的那一层，本身不吃鼠标（行也是 IGNORE，原版行不可点）。
    "列表区": ("Control", None, "mouse_filter = 0" + NL + "clip_contents = true" + NL, False),
    # `fl.controls.List` 有 scrollRect ⇒ 视口外的行**被裁掉**（38 行 ×26 = 988 > 372）。
    # Godot 侧对应 `clip_contents`；不裁的话 `窗口布局体检` 会白挨一条
    # `越界 意志介绍 … 下+599`（988−372−17），而那几行实机本来就画在视口外。
    # ⚠️ 裁剪框必须挂在**不动的那一层**（列表区），不能挂在被滚动的内容列上：
    #   挂在内容列上时，`内容列.position.y = −偏移` 会把裁剪矩形一起搬出窗口 ⇒
    #   数字全对（量具实测过）但**画面整块消失**（2026-09-28 截图抓到的）。
    "列表区/内容列": ("Control", None, "mouse_filter = 2" + NL, False),
    "列表区/竖条": ("Control", None, "mouse_filter = 0" + NL, False),
    "列表区/竖条/上箭头": ("TextureRect", "滚上", "mouse_filter = 0" + NL, False),
    "列表区/竖条/轨道": ("TextureRect", "滚槽", "mouse_filter = 2" + NL, False),
    "列表区/竖条/滑块": ("TextureRect", "滚块", "mouse_filter = 0" + NL, False),
    "列表区/竖条/下箭头": ("TextureRect", "滚下", "mouse_filter = 0" + NL, False),
}

注释 = [
    '; ── 意志介绍（原版 `com/mxw/uifl/controls/yiZhi/YiZhiIntroduceWindow.as`，455×430）──',
    '; 由 `开发工具/生成意志介绍场景.py` 从量具表 `截意志介绍页.gd` 的 件路径/件期望 生成。',
    '; **改真值改量具表再重跑生成器，别手改本文件。**',
    '; 场景 y = AS3 窗口局部 y − 29（`窗口尺寸.json` 的「意志介绍」标 `整框: true`）。',
    '; 列表行不在本场景里：原版是 `fl.controls.List` 按 dataProvider 现造 ⇒ 控制器填。']
头 = ["[gd_scene load_steps=%d format=3]" % (1 + len(图) + 1), NL.join(注释)]
for k, (p, _) in 图.items():
    头.append('[ext_resource type="Texture2D" path="res://素材/界面/%s" id="%s"]' % (p, 扩展id[k]))
头.append('')

箱 = (('[sub_resource type="StyleBoxTexture" id="sb_yellow"]' + NL
       + 'texture = ExtResource("%s")' + NL
       + 'texture_margin_left = 11' + NL + 'texture_margin_top = 10' + NL
       + 'texture_margin_right = 10' + NL + 'texture_margin_bottom = 11' + NL
       + 'content_margin_left = 0.0' + NL + 'content_margin_right = 0.0' + NL
       + 'content_margin_top = 0.0' + NL + 'content_margin_bottom = 0.0' + NL + NL)
      % 扩展id["黄底"])
模板 = ('[node name="%s" type="%s"%s]' + NL + '%s%s' + NL
        + 'layout_mode = 0' + NL + 'offset_left = %s' + NL + 'offset_top = %s' + NL
        + 'offset_right = %s' + NL + 'offset_bottom = %s' + NL)

矩 = {根: [0.0, 0.0, 455.0, 401.0]}			# 430 − 29
for 名, 值 in 件期望.items():
    矩[件路径[名]] = 值
# ⚠️ 同级顺序 = 绘制顺序，必须照原版 addChild：`YiZhiIntroduceWindow.as:32` 先 `addChild(_contentBg)`
#   （MYellow 底板，alpha=213 半透）、`:38` 才 `addChild(_list)` ⇒ **列表在黄底之上**。
#   按字典序发节点会把「列表区」排到「外框黄底」前面 ⇒ 38 行字被半透底板盖住（偏暗一档）。
出图序 = ["外框黄底", "列表区"]
顺序 = [根] + sorted(件路径.values(),
        key=lambda x: (出图序.index(x.split("/")[0]) if x.split("/")[0] in 出图序 else len(出图序),
                       x.count("/"), x))
行 = []
for 路 in 顺序:
    名 = 路.rsplit("/", 1)[-1]
    # 单层路径（"列表区"）的父是**根**，不是它自己；rsplit 不加判断会把自己当父
    父 = 路.rsplit("/", 1)[0] if "/" in 路 else ""
    x, y, w, h = 矩[路]
    基 = [0, 0, 0, 0] if 父 == "" else 矩[父]
    if 路 == 根:
        类型, 附加, 隐 = "Control", "custom_minimum_size = Vector2(455, 401)" + NL, False
    else:
        类型, 键名, 附, 隐 = 路径规格[路]
        附 = 附 or ""
        if 键名:
            if 类型 == "Panel":
                附 = 'theme_override_styles/panel = SubResource("sb_yellow")' + NL + 附
            else:
                附 = ('texture = ExtResource("%s")' % 扩展id[键名] + NL
                     + "expand_mode = 1" + NL + 附)
        附加 = 附
    父注 = '' if 路 == 根 else ' parent="%s"' % ("." if 父 == "" else 父)
    行.append(模板 % (名, 类型, 父注, ("visible = false" + NL if 隐 else ""), 附加,
                      x - 基[0], y - 基[1], x - 基[0] + w, y - 基[1] + h))

open(出, "w", encoding="utf-8", newline=NL).write(NL.join(头) + 箱 + NL + NL.join(行) + NL)
print("生成 %s：%d 个节点" % (os.path.relpath(出, 工程), len(顺序)))
