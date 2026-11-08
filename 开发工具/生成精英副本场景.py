# -*- coding: utf-8 -*-
"""从 `数据/界面/精英副本_布局.json` 生成 `场景/界面/窗口/副本/精英副本窗.tscn`
（原版 `EliteCopyWindow.as` 500×426，四个页签子页）。

**改真值改 `开发工具/出精英副本布局.py` 再重跑那两个脚本，别手改 `.tscn`。**

四条原版口径：
  1. 同级顺序 = `newBackground()`（`:369-394`）→ `init()`（`:187-206`）→ `createTabBtn()`
     （`:321-342`）→ `createCell()`（`:101-149`）的 addChild 序：
     内容底 → 子面板 → 格滚动 → 副本名 → 四枚页签 →（格容器内）页签页 → 格。
     ⚠ `copyName` 在 `init` 里最后 addChild ⇒ **画在 ScrollPane 之上**，所以左侧那截绿字
     不会被格子挡住；页签更晚 ⇒ 压在内容底上沿。
  2. 格内子件序 = `BailianCell.as:81-131` + `EliteCopyWindowCell.as:32`
     ⇒ 格底 → 锁 → 选中底 → 名 → 章节 → 头像 → 次数（头像在名/章节之后）。
  3. 页签是 `MTabButtonF` 且 `isScale9Grid=false` ⇒ 宽恒 70 的**整帧预烘皮**；
     选中那枚 = `enabled=false` ⇒ `disabled` 槽给 `selectedUpSkin`（`页签_选中.png`）**原色**，
     不推灰度、不派生悬停档。
  4. 四个子页的格**全部烘进场景**（编辑器=运行期），运行期只翻 `visible`。
"""
import io
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
from 场景id import ascii化		# 资源 id 一律 ASCII（见 开发工具/场景id.py 的说明）
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
布局 = json.load(io.open(os.path.join(工程, "数据", "界面", "精英副本_布局.json"), encoding="utf-8"))
文案 = json.load(io.open(os.path.join(工程, "数据", "界面", "副本_文案.json"), encoding="utf-8"))
出 = os.path.join(工程, "场景", "界面", "窗口", "副本", "精英副本窗.tscn")
根 = "原版精英副本内容"
NL = "\n"
抬 = 29
通用 = "原版窗口/通用控件"
本页 = "原版窗口/副本"

图 = {"内容面板": 通用 + "/内容面板.png", "子面板": 通用 + "/子面板.png",
     "横向分隔线": 通用 + "/横向分隔线.png",
     "精英格底": 本页 + "/精英格底.png", "精英格锁": 本页 + "/精英格锁.png",
     "精英格选中": 本页 + "/精英格选中.png",
     "页签_未选": 本页 + "/页签_未选.png", "页签_未选悬停": 本页 + "/页签_未选_悬停.png",
     "页签_未选按下": 本页 + "/页签_未选_按下.png", "页签_选中": 本页 + "/页签_选中.png"}
头像表 = {}
for 页 in 布局["页"]:
    for 格 in 页["格"]:
        if 格["头像"] and 格["头像"] not in 头像表:
            相对 = 格["头像"].replace("res://素材/", "")
            if not os.path.isfile(os.path.join(工程, "素材", *相对.split("/"))):
                raise SystemExit("布局说 %s 有头像但文件不在：%s" % (格["bossId"], 格["头像"]))
            头像表[格["头像"]] = "p%d" % len(头像表)
扩展id = {k: "t%d" % i for i, k in enumerate(图)}
for k in 图:
    if not os.path.isfile(os.path.join(工程, "素材", "界面", *图[k].split("/"))):
        raise SystemExit("素材缺失 %s ⇒ 先跑 开发工具/烘副本页皮.py" % 图[k])
边距 = {"内容面板": [11, 10, 10, 11], "子面板": [7.5, 7.5, 6.75, 6.75],
        "横向分隔线": [0, 0, 0, 0], "精英格底": [0, 0, 0, 0], "精英格锁": [0, 0, 0, 0],
        "精英格选中": [0, 0, 0, 0], "页签_未选": [0, 0, 0, 0], "页签_未选悬停": [0, 0, 0, 0],
        "页签_未选按下": [0, 0, 0, 0], "页签_选中": [0, 0, 0, 0]}
名色 = "Color(0.988235, 0.717647, 0.6, 1)"		# #FDB799  `BailianCell.as:105`
白 = "Color(1, 1, 1, 1)"
页签字色 = "Color(0.988235, 0.956863, 0.611765, 1)"	# #fcf49c `MTabButton.as:12`


def 串字(字):
    return 字.replace('"', '""').replace("\n", "\\n")


def 译(文):
    文 = 文.replace("<br/>", "\n").replace("<br>", "\n")
    文 = 文.replace("<font color='", "[color=").replace('<font color="', "[color=")
    文 = 文.replace("'>", "]").replace('">', "]").replace("</font>", "[/color]")
    return 文


def 标(字, 色值):
    return ('text = "%s"' % 串字(字) + NL + 'horizontal_alignment = 1' + NL
            + 'vertical_alignment = 1' + NL + 'theme_override_font_sizes/font_size = 12' + NL
            + 'theme_override_colors/font_color = %s' % 色值 + NL + 'mouse_filter = 2' + NL)


def 图块(键, 隐藏=False, 纹理=None):
    id = 头像表[纹理] if 纹理 else 扩展id[键]
    return ('texture = ExtResource("%s")' % id + NL + 'expand_mode = 1' + NL
            + 'stretch_mode = 0' + NL + 'mouse_filter = 2' + NL
            + ('visible = false' + NL if 隐藏 else ""))


树 = [(根, "Control", [0, 0, 500, 397], "custom_minimum_size = Vector2(500, 397)" + NL),
     ("内容底", "Panel", [5, 39 - 抬, 488, 381],
      'theme_override_styles/panel = SubResource("sb_内容面板")' + NL),
     ("子面板", "Panel", [11, 36, 478, 336],
      'theme_override_styles/panel = SubResource("sb_子面板")' + NL),
     ("格滚动", "ScrollContainer", [11, 36, 478, 336],
      'horizontal_scroll_mode = 3' + NL + 'vertical_scroll_mode = 1' + NL),
     ("格滚动/格容器", "Control", [11, 36, 478, 336],
      "custom_minimum_size = Vector2(478, 336)" + NL + "mouse_filter = 2" + NL)]
首 = 布局["页"][0]
树.append(("副本名", "RichTextLabel", [11, float(首["名y"] - 抬), 84, float(首["名高"])],
            'bbcode_enabled = true' + NL + 'text = "%s"' % 串字(译(首["名文本"])) + NL
            + 'scroll_active = false' + NL + 'autowrap_mode = 3' + NL
            + 'horizontal_alignment = 1' + NL
            + 'theme_override_constants/line_separation = 5' + NL + 'mouse_filter = 2' + NL))
树.append(("分页", "Control", [17, 16, 280, 22], "mouse_filter = 2" + NL))
样式 = "".join('theme_override_styles/%s = SubResource("sb_tab_%s")' % (n, n) + NL
               for n in ("normal", "hover", "pressed", "disabled"))
for n, 页 in enumerate(布局["页"]):
    树.append(("分页/页签%d" % n, "Button", [17 + n * 70, 16, 70, 22],
               样式 + 'text = "%s"' % 串字(页["页签"]) + NL + 'toggle_mode = true' + NL
               + ('button_pressed = true' + NL + 'disabled = true' + NL if n == 0 else "")
               + 'horizontal_alignment = 1' + NL
               + "".join('theme_override_colors/%s = %s' % (k, 页签字色) + NL for k in
                         ("font_color", "font_hover_color", "font_pressed_color",
                          "font_hover_pressed_color", "font_disabled_color"))
               + 'mouse_default_cursor_shape = 2' + NL))
for n, 页 in enumerate(布局["页"]):
    路 = "格滚动/格容器/页%d" % n
    树.append((路, "Control", [11, 36, 478, float(页["内容高"])],
               "custom_minimum_size = Vector2(478, %d)" % int(页["内容高"]) + NL
               + 'mouse_filter = 2' + NL + ('' if n == 0 else 'visible = false' + NL)))
    for j, 线 in enumerate(页["线"]):
        树.append(("%s/线%d" % (路, j), "TextureRect",
                   [11 + 线[0], 36 + 线[1], 线[2], 线[3]], 图块("横向分隔线")))
    for 格 in 页["格"]:
        名 = "%s/格%d" % (路, int(格["序号"]))
        树.append((名, "Control", [11 + 格["x"], 36 + 格["y"], 84, 124],
                   "custom_minimum_size = Vector2(84, 124)" + NL + 'mouse_filter = 0' + NL))
        树.append(("%s/格底" % 名, "TextureRect", [11 + 格["x"], 36 + 格["y"], 84, 81],
                   图块("精英格底")))
        树.append(("%s/锁" % 名, "TextureRect", [11 + 格["x"], 36 + 格["y"], 84, 81],
                   图块("精英格锁", 隐藏=True)))
        树.append(("%s/选中底" % 名, "TextureRect", [11 + 格["x"], 36 + 格["y"], 84, 81],
                   图块("精英格选中", 隐藏=True)))
        树.append(("%s/名" % 名, "Label", [11 + 格["x"], 36 + 格["y"] + 84, 84, 18],
                   标(格["名"], 名色)))
        树.append(("%s/章节" % 名, "Label", [11 + 格["x"] + 21, 36 + 格["y"] + 64, 43, 18],
                   标(格["章"], 白)))
        # 头像：**每张按自己原生尺寸、原生位置**画（`PortraitHead.as:80-89` 用 `_origin` 对齐、
        # `:94` 的 `_w/_h=-1` ⇒ 不缩放）。实测 21 张有 11 种尺寸（41×54…62×62），
        # 塞进固定 62×62 会把小的放大变形（用户 2026-10-03 报的图1 vs 图2）。
        头尺, 头位 = 格["头像尺寸"], 格["头像位"]
        树.append(("%s/头像" % 名, "TextureRect",
                   [11 + 格["x"] + float(头位[0]), 36 + 格["y"] + float(头位[1]),
                    float(头尺[0]), float(头尺[1])],
                   图块(None, 纹理=格["头像"]) if 格["头像"]
                   else 'expand_mode = 1' + NL + 'mouse_filter = 2' + NL))
        树.append(("%s/次数" % 名, "Label", [11 + 格["x"], 36 + 格["y"] + 100, 84, 20],
                   标(格["次数"], 白)))

# ── 资源块 ────────────────────────────────────────────────────────────────
def 箱(编号, 键):
    边 = 边距[键]
    return (('[sub_resource type="StyleBoxTexture" id="sb_%s"]' % 编号 + NL
             + 'texture = ExtResource("%s")' % 扩展id[键] + NL
             + 'texture_margin_left = %s' % 边[0] + NL + 'texture_margin_right = %s' % 边[1] + NL
             + 'texture_margin_top = %s' % 边[2] + NL + 'texture_margin_bottom = %s' % 边[3] + NL + NL))


体 = [箱("内容面板", "内容面板"), 箱("子面板", "子面板")]
for 槽, 键 in (("normal", "页签_未选"), ("hover", "页签_未选悬停"),
                ("pressed", "页签_选中"), ("disabled", "页签_选中")):
    体.append(箱("tab_%s" % 槽, 键))

全路 = {根: ""}
for 件名, _t, _矩, _a in 树:
    if 件名 == 根:
        continue
    末 = 件名.rsplit("/", 1)[-1]
    父 = 件名.rsplit("/", 1)[0] if "/" in 件名 else None
    全路[件名] = 末 if 父 is None else "%s/%s" % (全路[父], 末)
矩形 = {件名: 矩 for 件名, _t, 矩, _a in 树}
模板行 = ('[node name="%s" type="%s"%s]' + NL + '%s'
           + 'layout_mode = 0' + NL + 'offset_left = %s' + NL + 'offset_top = %s' + NL
           + 'offset_right = %s' + NL + 'offset_bottom = %s' + NL)
行们 = []
for 件名, 类型, 矩, 附 in 树:
    名 = 件名 if 件名 == 根 else 件名.rsplit("/", 1)[-1]
    if 件名 == 根:
        父注, 基 = "", [0, 0, 0, 0]
    else:
        # ⚠ 无斜杠的件名是**根的直接子节点**：`"副本名".rsplit("/",1)[0]` 返回它自己
        #   ⇒ 写成 `parent="副本名"` 自指，Godot 建出来是空壳（实测整页取不到件）。
        父 = 件名.rsplit("/", 1)[0] if "/" in 件名 else None
        父路 = 全路[父] if 父 else ""
        父注 = ' parent="."' if 父路 == "" else ' parent="%s"' % 父路
        # 自指 parent（`parent=` 等于本件名）Godot 不报错、建出来是空壳 ⇒ 当场拦
        assert 父注 != ' parent="%s"' % 名, "自指 parent：" + 件名
        基 = 矩形[父] if 父 else [0, 0, 0, 0]
    行们.append(模板行 % (名, 类型, 父注, 附, 矩[0] - 基[0], 矩[1] - 基[1],
                        矩[0] - 基[0] + 矩[2], 矩[1] - 基[1] + 矩[3]))

注释 = [
    '; 由 `开发工具/生成精英副本场景.py` 从 `数据/界面/精英副本_布局.json` 生成（布局由',
    '; `开发工具/出精英副本布局.py` 按 `EliteCopyWindow.as:101-149` 现算）⇒ **别手改本文件**。',
    '; 原版 `super(500,426)` 在 `:57`；标题 = `ELITECOPY_WINDOW_TITLE`「精英副本」`:383`。',
    '; 场景 y = AS3 窗口局部 y − 29（`整框: true` ⇒ 容器原点 (0,29)）。',
    '; 四个页签子页的格全烘进来（编辑器=运行期），运行期只翻 visible。',
    '; 逐件出处见 `测试/截图/精英副本_对照/真值对照表.md` 与 `game-client/真值/窗口/精英副本.md`。']
头 = ["[gd_scene load_steps=0 format=3]", NL.join(注释)]
for k, p in 图.items():
    头.append('[ext_resource type="Texture2D" path="res://素材/界面/%s" id="%s"]' % (p, 扩展id[k]))
for 路, id in 头像表.items():
    头.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (路, id))
头.append("")
头[0] = "[gd_scene load_steps=%d format=3]" % (1 + len(图) + len(头像表) + len(体))
正文 = NL.join(头) + "".join(体) + NL + NL.join(行们) + NL
assert 正文.count('[node name=') == len(树)
assert 'parent=""' not in 正文
# 资源 id 一律 ASCII（Godot 的 scene unique ID 只许 `[A-Za-z0-9_]` 且不以数字开头；
# 中文 id 每加载一次吐一行 ERROR）。见 开发工具/场景id.py。
正文 = ascii化(正文)

if os.path.exists(出):
    io.open(出 + ".bak", "w", encoding="utf-8", newline=NL).write(io.open(出, encoding="utf-8").read())
os.makedirs(os.path.dirname(出), exist_ok=True)
io.open(出, "w", encoding="utf-8", newline=NL).write(正文)
print("生成 %s：%d 个节点、%d 张共用图 + %d 张头像、%d 个样式盒" % (
    os.path.relpath(出, 工程), len(树), len(图), len(头像表), len(体)))
for 页 in 布局["页"]:
    print("  页%d %-8s 格 %d 枚 线 %d 根" % (页["页号"], 页["页签"], len(页["格"]), len(页["线"])))
