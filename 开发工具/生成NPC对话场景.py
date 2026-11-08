# -*- coding: utf-8 -*-
"""生成 `场景/界面/窗口/NPC对话/NPC对话窗.tscn`（原版 `QuestDialog.as`，两格上下叠、无标题栏）。

**改真值改本文件顶部的表再重跑，别手改 `.tscn`。**

原版结构（`QuestDialog.as`，全部行号都在这）：
    drawSkin():147-153   addChild(_npcSaidSkin) → addChild(_playerSaidSkin)   两张 ScaleSprite
    drawView():371-402   _npcLabel(10, CONTENT_GAP=8) 黄 粗 14
                         _npcTextArea(x=25, 宽 = 上格宽−50, y = 名字.y+名字高+10) 白 + 发光
                         上格高 = max(文本.y + 文本高 + 20, MIN_NPC_SAID_HEIGHT=77)   :33/:390-391
                         下格.y = 上格.y + 上格高 + 5                                  :392
    createSelection():191-363
                         首行 y = 下格.y + 20、行高 = 该枚 SelectionLalel 的高          :211-224
                         下格高 = max(末行底 − 下格.y + 20, MIN_PLAYER_SAID_HEIGHT=74) :357-362
    SelectionLalel:442-456  QuestDialog_hand(15×11) + MGlowLabel(UI_GREEN) 在 (手宽+5, −7)

两张皮的九宫格边距只认 `MainLib.xml` 的 `DefineScalingGridTag`（《共用件度量表》§13 口径）：
    上格 794 原生 506×77  ⇒ 左 8   上 30   右 41.5 下 7.75   @MainLib.xml:11757
    下格 797 原生 506×74  ⇒ 左 10.5 上 8    右 9.05 下 9     @MainLib.xml:11792

⚠ **两格高度与行距取的是用户实机截图量出来的数**（上格 81 / 下格 100 / 行距 20）：
原版那两个高是运行期按 Flash 文本度量算的（`textHeight` 不在源码里），Godot 的字距不同，
照公式硬算会差 4~7px。公式与实测的差已登记在 `真值对照表.md` 的未决问题表里。
"""
import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
出 = os.path.join(工程, "场景", "界面", "窗口", "NPC对话", "NPC对话窗.tscn")
NL = "\n"
通用 = "原版窗口/通用控件"
图 = {"对话上格": (通用 + "/对话上格.png", [8, 41.5, 30, 7.75]),
     "对话下格": (通用 + "/对话下格.png", [10.5, 9.05, 8, 9]),
     "对话手形": (通用 + "/对话手形.png", [0, 0, 0, 0])}
缺 = [k for k, (p, _) in 图.items()
     if not os.path.isfile(os.path.join(工程, "素材", "界面", *p.split("/")))]
if 缺:
    raise SystemExit("素材缺失 %s ⇒ 先跑 开发工具/烘副本页皮.py" % 缺)
扩展id = {k: "t%d" % i for i, k in enumerate(图)}

宽 = 506
上格高 = 81
下格距 = 5
下格高 = 100
行距 = 20
首行y = 20
名字 = [10, 8, 120, 21]
台词 = [25, 39, 456, 17]
菜单x = 25
下格顶 = 上格高 + 下格距		# 下格在根里的绝对 y
## ⚠ 原版 `SelectionLalel` 是 Sprite + buttonMode ⇒ **命中区 = 子节点实际画出来的范围**
## （`QuestDialog.as:442-456`：手形在 y=0、文字 `MGlowLabel` 在 **y = −7**）。
## Godot 的命中区是 Control 自己的矩形，所以那 −7 必须**并进行的矩形**，
## 不能只当子节点偏移留着 —— 留着的结果：行的矩形是 0..20、字却画在 −7..13，
## 于是「看得见的前 7 个点不到」+「上一行的矩形盖住下一行的字上半截」（点错行）。
## 正确做法：行整体上移 7（矩形 −7..13 = 正好包住可见内容），子节点相应下移 7 保持画面不动。
行顶上移 = 7
手形 = [0, 行顶上移, 15, 11]
文字 = [20, 0, 200, 20]
黄 = "Color(1, 0.941176, 0, 1)"		# UI_YELLOW 16773120 = #FFF000	`QuestDialog.as:377`
白 = "Color(1, 1, 1, 1)"			# `:384` htmlText 里硬写的 #ffffff
绿 = "Color(0, 1, 0, 1)"			# UI_GREEN 65280			`SelectionLalel:451`

## 烘的是**纲手**那一屏（`数据/NPC.json` 的 00000018 + 服务端 `NPC_SERVICE_MENUS[18]`）：
## 台词 = NPC 原文，菜单 = 挑战副本 / 挑战精英副本 / 离开（用户说两条支线不做 ⇒ 不烘）。
纲手 = {"名": "纲手",
        "台词": "我把希望，押在你身上，希望你能成为伟大的忍者。",
        "菜单": ["挑战副本", "挑战精英副本", "离开"]}


def 串字(字):
    return 字.replace('"', '""').replace("\n", "\\n")


def 九宫(边):
    """`NinePatchRect` 的 `patch_margin_*` 在 Godot 4 是 **int**（`texture_margin_*` 属于
    TextureRect / StyleBoxTexture，写在 NinePatchRect 上载入不报错也不落地 ⇒ 四角从没九宫切过）。
    上面 `图` 里存的是 Flash XML 的分数换算值 ⇒ 烘进九宫那条一律四舍五入（.5 远离 0）。"""
    return [int(f + 0.5) if f >= 0 else -int(-f + 0.5) for f in 边]


树 = [("原版NPC对话", "Control", [0, 0, float(宽), float(上格高 + 下格距 + 下格高)],
        'custom_minimum_size = Vector2(%d, %d)' % (宽, 上格高 + 下格距 + 下格高) + NL
        + 'mouse_filter = 2' + NL),
       ("上格", "NinePatchRect", [0, 0, float(宽), float(上格高)],
        'texture = ExtResource("%s")' % 扩展id["对话上格"] + NL
        + "".join('patch_margin_%s = %d' % (n, 九宫(图["对话上格"][1])[i]) + NL for i, n in
                  enumerate(("left", "right", "top", "bottom")))
        + 'mouse_filter = 2' + NL),
       ("上格/名字", "Label", [float(名字[0]), float(名字[1]), float(名字[2]), float(名字[3])],
        'text = "%s"' % 串字(纲手["名"]) + NL + 'horizontal_alignment = 0' + NL
        + 'vertical_alignment = 1' + NL + 'theme_override_font_sizes/font_size = 14' + NL
        + 'theme_override_colors/font_color = %s' % 黄 + NL + 'mouse_filter = 2' + NL),
       ("上格/台词", "RichTextLabel",
        [float(台词[0]), float(台词[1]), float(台词[2]), float(台词[3])],
        'bbcode_enabled = true' + NL + 'text = "[color=#ffffff]%s[/color]"' % 串字(纲手["台词"]) + NL
        + 'scroll_active = false' + NL + 'autowrap_mode = 3' + NL
        + 'theme_override_constants/line_separation = 5' + NL + 'mouse_filter = 2' + NL),
       ("下格", "NinePatchRect", [0, float(上格高 + 下格距), float(宽), float(下格高)],
        'texture = ExtResource("%s")' % 扩展id["对话下格"] + NL
        + "".join('patch_margin_%s = %d' % (n, 九宫(图["对话下格"][1])[i]) + NL for i, n in
                  enumerate(("left", "right", "top", "bottom")))
        + 'mouse_filter = 2' + NL),
       ("下格/菜单", "Control", [float(菜单x), float(下格顶 + 首行y), 220.0,
        float(行距 * len(纲手["菜单"]))],
        'mouse_filter = 2' + NL),
       ## **剧情面**：原版 `createPlayerTextArea():404-416` —— 328 帧第 4 段有 `text` 时，
       ## 下格不建菜单行，只画**一行绿色玩家回应**，宽 = 上格宽 − 50 = 456、x 与台词同为 25、
       ## 在下格内**垂直居中**（`:413` `y = skin.y + (skin.height − height)/2`）。
       ## 烘成常驻隐藏节点（运行期只切 `visible` 与文案）⇒ 编辑器里看得见、和运行期同一形状。
       ## `mouse_filter = 2`（IGNORE）：热区是**整个下格**（原版 skin 上挂 CLICK），
       ## 文字自己不吃鼠标，否则点字会走 `_点行` 那条而不是发 NEXT。
       ("下格/回应", "RichTextLabel",
        [float(台词[0]), float((下格高 - 台词[3]) / 2.0), float(台词[2]), float(台词[3])],
        'visible = false' + NL + 'bbcode_enabled = true' + NL
        + 'text = "[color=#00ff00]我会用心记住婆婆的话的。[/color]"' + NL
        + 'scroll_active = false' + NL + 'autowrap_mode = 3' + NL
        + 'theme_override_constants/line_separation = 5' + NL + 'mouse_filter = 2' + NL)]
for i, 项 in enumerate(纲手["菜单"]):
    名 = "下格/菜单/行%d" % (i + 1)
    顶 = 下格顶 + 首行y - 行顶上移 + i * 行距
    树.append((名, "Control", [float(菜单x), float(顶), 220.0, float(行距)],
                'mouse_filter = 0' + NL + 'mouse_default_cursor_shape = 2' + NL))
    树.append(("%s/手形" % 名, "TextureRect",
               [float(菜单x + 手形[0]), float(顶 + 手形[1]),
                float(手形[2]), float(手形[3])],
               'texture = ExtResource("%s")' % 扩展id["对话手形"] + NL
               + 'expand_mode = 1' + NL + 'stretch_mode = 0' + NL + 'mouse_filter = 2' + NL))
    树.append(("%s/文字" % 名, "Label",
               [float(菜单x + 文字[0]), float(顶 + 文字[1]),
                float(文字[2]), float(文字[3])],
               'text = "%s"' % 串字(项) + NL + 'horizontal_alignment = 0' + NL
               + 'vertical_alignment = 1' + NL + 'theme_override_font_sizes/font_size = 12' + NL
               + 'theme_override_colors/font_color = %s' % 绿 + NL + 'mouse_filter = 2' + NL))

全路 = {"原版NPC对话": ""}
for 件名, _t, _矩, _a in 树:
    if 件名 == "原版NPC对话":
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
    名 = 件名 if 件名 == "原版NPC对话" else 件名.rsplit("/", 1)[-1]
    if 件名 == "原版NPC对话":
        父注, 基 = "", [0, 0, 0, 0]
    else:
        父 = 件名.rsplit("/", 1)[0] if "/" in 件名 else None
        父路 = 全路[父] if 父 else ""
        父注 = ' parent="."' if 父路 == "" else ' parent="%s"' % 父路
        assert 父注 != ' parent="%s"' % 名, "自指 parent：" + 件名
        基 = 矩形[父] if 父 else [0, 0, 0, 0]
    行们.append(模板行 % (名, 类型, 父注, 附, 矩[0] - 基[0], 矩[1] - 基[1],
                        矩[0] - 基[0] + 矩[2], 矩[1] - 基[1] + 矩[3]))

注释 = [
    '; 由 `开发工具/生成NPC对话场景.py` 生成 ⇒ **别手改本文件**（下一次生成会吃掉）。',
    '; 原版 `com/mxw/uifl/controls/QuestDialog.as`：两张 ScaleSprite 上下叠、**没有标题栏/关闭钮**，',
    '; `PopUpMananger.centerWindow` 居中摆在舞台上（`:401`）。烘的是纲手（NPC 00000018）那一屏。',
    '; 两格高度/行距取实机截图量出的 81 / 5 / 100 / 20；公式与差值见 `真值对照表.md` 未决问题表。',
    '; 逐件出处 `game-client/真值/窗口/纲手对话.md`。']
头 = ["[gd_scene load_steps=%d format=3]" % (1 + len(图)), NL.join(注释)]
for k, (p, _) in 图.items():
    头.append('[ext_resource type="Texture2D" path="res://素材/界面/%s" id="%s"]' % (p, 扩展id[k]))
头.append("")
正文 = NL.join(头) + NL + NL.join(行们) + NL
assert 正文.count('[node name=') == len(树)
assert 'parent=""' not in 正文
os.makedirs(os.path.dirname(出), exist_ok=True)
io.open(出, "w", encoding="utf-8", newline=NL).write(正文)
print("生成 %s：%d 个节点（上格 %d / 下格 %d / 菜单 %d 行）" % (
    os.path.relpath(出, 工程), len(树), 上格高, 下格高, len(纲手["菜单"])))
