# -*- coding: utf-8 -*-
"""好友主窗生成器：一份表同时产出 ①`场景/界面/窗口/好友/好友窗口.tscn` ②门期望
`数据/界面/好友页期望.json`（场景与期望同源，别再手抄第二份 —— 家族那轮就是栽在抄错 x）。

真值：`game-client/真值/窗口/好友.md` §0–§4。坐标一律写**窗口坐标**，落场景时减内容区原点
(8,38)（`FW2:204-212`：自绘 MYellow @ x=CONTENT_GAP=8、y=38 字面量、宽=窗−16、高=窗−73）。
页面 Control 高按 **窗−38**（底栏钮挂在窗口上、会落到内容底之外，与家族页同口径）。

用法：python 开发工具/生成好友场景.py  →  Godot --path . --headless --import
     →  Godot --path . --headless --script res://测试/好友页回归测试.gd
"""
import io
import json
import os
import sys

# ⚠️ 原来是作者机上的绝对路径 `2.2.3\naruto_godot`。
#    在本工程跑会**静默在仓库外面建一棵同名的树**（`os.makedirs` 照建不误），
#    本仓库这边一个文件都不动 —— 表现是"跑完了、门还是红的"，很难看出是写错地方了。
#    改成从本文件位置反推工程根。
项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
场景目录 = os.path.join(项目, "场景", "界面", "窗口", "好友")
期望目录 = os.path.join(项目, "数据", "界面")
通用皮 = "res://素材/界面/原版窗口/通用控件/%s.png"
好友皮 = "res://素材/界面/原版窗口/好友/%s.png"
控制器 = "res://脚本/界面/窗口/好友/好友窗口.gd"
# 子窗控制器默认复用家族那台：它只靠节点上的 metadata/skin + metadata/act 驱动，
# 与"家族"没有任何耦合（skin 存的是完整 res:// 主干，见 家族子窗.gd 文件头）。
# 好友三扇各自派生一台（extends 家族子窗），在 `装配` 里补自己的填数/发动作。
子窗控制器 = "res://脚本/界面/窗口/家族/家族子窗.gd"
三态脚本 = "res://脚本/界面/组件/原版三态钮.gd"

窗 = [295, 370]			# FW2:62 super(295,370,false)
原点 = [8, 38]			# FW2:207-208（x=CONTENT_GAP、y=38 字面量）
黄边 = [11, 10, 10, 11]		# MYellow_background（《度量表》§13）
盒边 = [7.5, 6.75, 7.0, 7.25]	# MPane_background 97
选中边 = [7, 5.35, 7.9, 5.75]	# MSelected_background1 705
菜单边 = [5.75, 4.75, 9.75, 11]	# MPopupMenu_background 590
菜单钮边 = [2.25, 2, 2.5, 2.5]	# MPopupMenuButton_up 585

语言 = {}
for 档 in ("core.json", "ui.json", "message.json"):
    # ⚠️ 语言表来源改成**本仓库自己的那条链**：原来硬编码
    #    `2.2.3\真值文档\UI\texts`（作者机上的路径，换台机器直接 FileNotFoundError）。
    #    本工程读的是 AS3 语言表字面量 `en_US$core/ui/message_properties.as`
    #    （见 `开发工具/原版数据.py`），三个包名一一对应，取到的是同一份文案。
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import 原版数据 as _语言源  # noqa: PLC0415
    for k, v in _语言源.读语言表(档.removesuffix(".json")).items():
        if isinstance(v, str):
            语言.setdefault(k, v)


def 文(键):
    if 键 not in 语言:
        raise SystemExit("语言表缺键，别自造文案：" + 键)
    return 语言[键]


# ── 页签定义：顺序即 tabBtnIndexs（FW2:40），师徒态 SHITU_OFF 时整列抽掉（FW2:173-185）
页签 = [
    ("好友", "FRIEND_TAB_LINKMAN", "体好友"),
    ("师徒", "FRIEND_TAB_SHITU", "体师徒"),
    ("仇人", "FRIEND_TAB_CHOU_REN", "体仇人"),
    ("黑名单", "FRIEND_TAB_BACKLIST", "体黑名单"),
    ("最近", "FRIEND_TAB_LAST", "体最近"),
]
# ⚠️ 右侧一律是**本工程 `游戏会话` 的真实字段名**（原包写的 shitu/blacklist 与工程对不上，
#    数据侧归我们 ⇒ 2026-10-01 合并时订正）。「黑名单」读的是 `blocked_contacts`（行字典）；
#    会话里那个 `blocked_players` 只有名字、别处按名字判重，不能改形状，所以另存了一份。
#    「师徒」本工程**没有**这条数据面（`数据/师徒.json` 只有 gains/shop/params 配置、
#    后端也没有师徒联系列表）⇒ 故意留一个不存在的键 = 空列表态，不编数据。
数据键 = {"好友": "friends", "师徒": "shitu", "仇人": "enemies",
           "黑名单": "blocked_contacts", "最近": "recent_contacts"}
# 每个页签体的件：全部是**页签体局部坐标**（体本身在窗口 (13,65)，FG:25-27 底 269×265）
表头键 = {"体好友": "FRIEND_GIFD_TITLE_4", "体仇人": "FRIEND_GIFD_TITLE_1",
	  "体黑名单": "FRIEND_GIFD_TITLE_2", "体最近": "FRIEND_GIFD_TITLE_2",
	  "体师徒": "FRIEND_GIFD_TITLE_3"}
底高 = {"体师徒": 240}		# FG:44-48 师徒态列表体高 240，其余 265


def 体件(名):
    """一个页签体的件表：[件名, 类型, 局部矩形, 贴图, 附加属性…]。列表体见 §1，底栏件见 §3。"""
    高 = 底高.get(名, 265)
    件 = [
        ["列表底", "九宫", [0, 0, 269, 高], 通用皮 % "内容面板", 黄边, "FG:49-51 MYellow 269×265（师徒 240）"],
        ["表头横线", "图", [0, 20, 269, 2], 通用皮 % "横向分隔线", [], "FG:53-55 y=22−高、宽=底宽"],
        ["表头分隔1", "图", [116, 0, 2, 20], 好友皮 % "表头竖分隔", [], "FG:56-58 x=116 字面量、y 不设=0"],
        ["表头分隔2", "图", [192, 0, 2, 20], 好友皮 % "表头竖分隔", [], "FG:59-60 x=192"],
        ["表头分隔3", "图", [245, 0, 2, 20], 好友皮 % "表头竖分隔", [], "FG:61 x=245"],
        # InputWithBg 的三段是**构造时固定**的（1/115/192，宽 112/76/54，与盒宽无关），
        # setText 按英文逗号切三段 —— 所以表头不显示逗号（`InputWithBg.as:26-52`）
        ["表头1", "字", [1, 0, 112, 22], None, ["居中", "文:%s" % 文(表头键[名]).split(",")[0]], "IB:26-31 + FG:74-91"],
        ["表头2", "字", [115, 0, 76, 22], None, ["居中", "文:%s" % 文(表头键[名]).split(",")[1]], "IB:32-37"],
        ["表头3", "字", [192, 0, 54, 22], None, ["居中", "文:%s" % 文(表头键[名]).split(",")[2]], "IB:38-43"],
        ["列表", "容器", [0, 24, 265, 高 - 30], None, ["裁剪"], "FG:92-96 x=表头x、y=1+22+1、宽=269−4、高=底−30、rowHeight23"],
        # 行容器**嵌在列表里**（原版 fl List 的 scrollContent）：这样裁剪由列表负责，
        # 控制器按 `体/列表/行容器` 取；平铺成兄弟会让那条路径 404（上一版就踩了）
        ["列表/行容器", "容器", [0, 0, 265, 0], None, [], "运行期按数据建行（行模板见期望表 _模板行）"],
    ]
    if 名 == "体好友":		# TL:53-61 献花钮没吃到 isScale9Grid（AS3 把 _btnAdd 又设了一遍）⇒ 皮宽 57
        件 += [["献花钮", "钮", [30, 276, 57, 22], "钮底", "ZENGHUA_XIANHUA", "TL:56-61 x=30、y=276 字面量"],
              ["添加好友钮", "钮9", [185, 276, 54, 22], "钮底", "FRIEND_ADD", "TL:53-55,59 isScale9Grid=true ⇒ 宽=48+6=54、x=269−54−30"]]
    elif 名 == "体黑名单":	# Tst:32-36 「增加」没设 isScale9Grid ⇒ 57
        件 += [["增加钮", "钮", [182, 276, 57, 22], "钮底", "FRIEND_SWEETEN", "Tst:32-36 x=269−57−30、y=276"]]
    elif 名 == "体仇人":		# CR:31-41 两行橙字居中，压在列表体下面
        件 += [["仇人说明", "富文", [0, 269, 269, 32], None, "CHOURENTAB_SAY", "CR:34-35 setSize(269,32)、y=265+4"]]
    elif 名 == "体师徒":		# SL:73-125,149-152（师徒态：底 240 ⇒ 说明 y=244）
        件 += [["师徒说明", "字", [2, 244, 269, 18], None, ["文:", "色:#FF7F00"], "SL:73-77 w=269、h=18、@ (2, 底+4)"],
               ["师徒右钮", "钮37", [228, 244, 37, 22], "钮底", "AWARD_BTN", "SL:87-100 isScale9Grid=false、w=37、x=269−37−4"],
               ["师徒主钮", "钮61", [49, 273, 61, 22], "钮底", "WOYAO_BAISHI", "SL:102-116,149 x=(269−61·2)/3=49、y=244+22+7"],
               ["退出师门钮", "钮61", [159, 273, 61, 22], "钮底", "SHITU_WINDOW_TUICHUSHIMEN", "SL:117-125,151 仅徒弟态建、x=49+61+49"]]
    return 件


# ── 行模板（`FriendItemRenderer`，运行期建行；几何进期望表当板，门单独核）
模板行 = [
    ["选中条", [2, 1, 246, 23], "FI:167-177 MSelected_background1 @(2,1) 高23、background.width=246（整条拉伸）"],
    ["头像", [15, 13, 20, 20], "FI:82-89 PortraitHead 20×20 @ (15,13)，仅 face>0"],
    ["名列", [25, 2, 90, 20], "FI:142-146 左对齐白 #FFFFFF"],
    ["列二", [115, 2, 75, 20], "FI:147-150 居中；好友态装的是 level（FI:98）"],
    ["列三", [190, 2, 55, 20], "FI:152-156 居中；好友态=友好度、带 YOUHAODU_TIP"],
]
菜单模板 = {
    "底边距": 菜单边, "项边距": 菜单钮边, "MARGIN": 3, "项高": 19, "分隔高": 2,
    "版式": "MPM:38-95 钮 x=3、y=累计+3；bgWidth=max(钮宽)+6；项宽=bgWidth−6；空文本项=一条 LineHPicF；底高=累计+6(+5)",
}


def 节(名, 类, 父, 属性):
    """一个节点块：首行 `[node … parent=父]`，后面是属性行。
    父用**场景路径**（"." 或 "页签条"）；要在块内再嵌子节点，自己在属性里写第二个 [node]。"""
    return "\n".join(['[node name="%s" type="%s" parent="%s"]' % (名, 类, 父)] + 属性)


资源 = []
节点 = []
期望 = {}
序 = [0]


def 加(路径):
    序[0] += 1
    资源.append('[ext_resource type="Texture2D" path="%s" id="t%d"]' % (路径, 序[0]))
    return "t%d" % 序[0]


def 矩形行(局, 忽略鼠标=True):
    出 = ["layout_mode = 0", "offset_left = %.1f" % 局[0], "offset_top = %.1f" % 局[1],
          "offset_right = %.1f" % (局[0] + 局[2]), "offset_bottom = %.1f" % (局[1] + 局[3])]
    if 忽略鼠标:
        出.append("mouse_filter = 2")
    return 出


def 整(v):
    """九宫边距定形：`NinePatchRect` 的 `patch_margin_*` 只收 **int**（探针实测 hint 0..16384px），
    .tscn 里写分数不报错但**向零截断** ⇒ 文件说的和运行期用的差一像素（§3.228）。
    这边按「四舍五入、.5 远离 0」烘成整数 —— 离 Flash 那个分数最近、且文件 = 运行期。"""
    return int(v + 0.5) if v >= 0 else -int(-v + 0.5)


def 建():
    内 = [窗[0] - 16, 窗[1] - 38]
    # ① 内容底（自绘 MYellow，FW2:204-212）
    局 = [0, 0, 279, 297]
    期望["内容底"] = [局, "FW2:204-212 x=8、y=38、宽=窗−16、高=窗−73"]
    节点.append(节("内容底", "NinePatchRect", ".", 矩形行(局) + [
        "texture = ExtResource(\"%s\")" % 加(通用皮 % "内容面板"),
        "patch_margin_left = %d" % 整(黄边[0]), "patch_margin_top = %d" % 整(黄边[1]),
        "patch_margin_right = %d" % 整(黄边[2]), "patch_margin_bottom = %d" % 整(黄边[3])]))
    # ② 页签条（FW2:268-271 @ 窗口 18,45；TabBar 横排 gap=1，皮 39×22）
    条 = [18 - 原点[0], 45 - 原点[1], 5 * 39 + 4, 22]
    期望["页签条"] = [条, "FW2:269-271 窗口(18,45)；TabBar.as:90-93 gap=1"]
    节点.append(节("页签条", "Control", ".", 矩形行(条, False)))
    for i, (名, 键, 体) in enumerate(页签):
        局 = [i * 40, 0, 39, 22]
        期望["页签|%s" % 名] = [局, "FW2:266 第 %d 枚；MTabButtonF 皮宽 39、gap1" % i]
        节点.append(节("页签" + 名, "TextureButton", "页签条", 矩形行(局, False) + [
            "focus_mode = 0", "ignore_texture_size = true",
            # 未选枚 = 页签未选.png（+ 预烘 悬停/按下）；选中枚 = `texture_disabled` 显示**选中皮真皮**
            # —— `MTabButton.set enabled(v)` 里 `selected=!enabled`，且子类 DISABLED 档不推灰度
            # （《度量表》§4.1 + project memory「页签选中皮非灰度」）。
            "texture_normal = ExtResource(\"%s\")" % 加(好友皮 % "页签未选"),
            "texture_disabled = ExtResource(\"%s\")" % 加(好友皮 % "页签选中"),
            "metadata/skin = \"%s\"" % (好友皮 % "页签未选")[:-4],
            "metadata/act = \"%s\"" % 名,
            "", "[node name=\"Label\" type=\"Label\" parent=\"页签条/页签%s\"]" % 名,
            "layout_mode = 1", "anchors_preset = 15", "anchor_right = 1.0", "anchor_bottom = 1.0",
            "grow_horizontal = 2", "grow_vertical = 2", "mouse_filter = 2",
            # MTabButton 把四态字色设成同一个 #FCF49C（`MTabButton.as:12`）⇒ 换态不换字色
            "text = \"%s\"" % 文(键), "horizontal_alignment = 1", "vertical_alignment = 1",
            "theme_override_colors/font_color = %s" % 色("#FCF49C")]))
    # ③ 五个页签体（FW2:215-228 挂窗口 (13,65)）
    体原 = [13 - 原点[0], 65 - 原点[1], 269, 300]
    for i, (名, 键, 体) in enumerate(页签):
        期望["体|%s" % 体] = [体原, "FW2:220-221 x=13、y=65 字面量（Tab 自身原点）"]
        节点.append(节(体, "Control", ".", 矩形行(体原, False) + ["visible = %s" % ("true" if i == 0 else "false")]))
        for 件 in 体件(体):
            种 = 件[1]
            局 = 件[2]
            父 = 件[0] if 件[0].find("/") < 0 else 件[0].rsplit("/", 1)[0]
            件名 = 件[0].rsplit("/", 1)[-1]
            期望["%s|%s" % (体, 件[0])] = [局, 件[-1] if 种 not in ("钮", "钮37", "钮61", "钮9", "富文") else 件[5]]
            路 = "%s/%s" % (体, 件[0])
            if 种 == "九宫":
                节点.append(节(件名, "NinePatchRect", 体 + ("/" + 父 if 父 != 件名 else ""), 矩形行(局) + [
                    "texture = ExtResource(\"%s\")" % 加(件[3])] +
                    ["patch_margin_%s = %d" % (s, 整(v)) for s, v in zip(
                        ["left", "top", "right", "bottom"], 件[4])]))
            elif 种 == "图":
                节点.append(节(件名, "TextureRect", 体 + ("/" + 父 if 父 != 件名 else ""), 矩形行(局) + [
                    "texture = ExtResource(\"%s\")" % 加(件[3]), "expand_mode = 1", "stretch_mode = 0"]))
            elif 种 == "容器":
                行 = 矩形行(局, False)
                if "裁剪" in 件[4]:
                    行.append("clip_contents = true")
                节点.append(节(件名, "Control", 体 + ("/" + 父 if 父 != 件名 else ""), 行))
            elif 种 == "字":
                行 = 矩形行(局) + ["text = \"%s\"" % 件[4][1].replace("文:", "")]
                if "居中" in 件[4]:
                    行 += ["horizontal_alignment = 1", "vertical_alignment = 1"]
                for 附 in 件[4]:
                    if 附.startswith("色:"):
                        行.append("theme_override_colors/font_color = %s" % 色(附[2:]))
                节点.append(节(件名, "Label", 体 + ("/" + 父 if 父 != 件名 else ""), 行))
            elif 种 == "富文":
                节点.append(节(件名, "RichTextLabel", 体 + ("/" + 父 if 父 != 件名 else ""), 矩形行(局) + [
                    "theme_override_constants/line_separation = 2",
                    "theme_override_font_sizes/normal_font_size = 12",
                    "theme_override_colors/default_color = %s" % 色("#FF9740"),
                    "bbcode_enabled = true", "text = \"%s\"" % 转BB(文(件[4])), "scroll_active = false"]))
            else:	# 钮 / 钮37 / 钮61 / 钮9 = 预烘宽档
                宽 = 局[2]
                皮 = 件[3]
                名皮 = {"钮": "钮底%d" % 宽 if 宽 in (37, 61) else "钮底", "钮37": "钮底37",
                       "钮61": "钮底61", "钮9": "钮底54"}[种]
                节点.append(节(件名, "TextureButton", 体 + ("/" + 父 if 父 != 件名 else ""), 矩形行(局, False) + [
                    "focus_mode = 0", "ignore_texture_size = true",
                    "texture_normal = ExtResource(\"%s\")" % 加(好友皮 % 名皮),
                    "metadata/skin = \"%s\"" % (好友皮 % 名皮)[:-4],
                    "metadata/act = \"%s\"" % 件[0],
                    "", "[node name=\"Label\" type=\"Label\" parent=\"%s\"]" % 路,
                    "layout_mode = 1", "anchors_preset = 15", "anchor_right = 1.0", "anchor_bottom = 1.0",
                    "grow_horizontal = 2", "grow_vertical = 2", "mouse_filter = 2",
                    "text = \"%s\"" % 文(件[4]), "horizontal_alignment = 1", "vertical_alignment = 1"]))
    头 = ["[gd_scene load_steps=%d format=3]" % (len(资源) + 2),
          '[ext_resource type="Script" path="%s" id="1_script"]' % 控制器]
    头 += 资源		# ⚠ 别漏：漏了就只有 load_steps 里数过、正文里没有 ⇒ tscn 解析在第一个
    # ExtResource("t1") 上就炸（家族那台的 头 是这么拼的，抄过来时少抄这一行）
    根 = ["[node name=\"原版好友窗口内容\" type=\"Control\"]",
          "custom_minimum_size = Vector2(%d, %d)" % (内[0], 内[1]),
          "script = ExtResource(\"1_script\")"]
    文句 = "\n\n".join(头 + ["", "\n".join(根)] + 节点) + "\n"
    os.makedirs(场景目录, exist_ok=True)
    os.makedirs(期望目录, exist_ok=True)
    with io.open(os.path.join(场景目录, "好友窗口.tscn"), "w", encoding="utf-8", newline="\n") as f:
        f.write(文句)
    期望["_窗"] = 窗
    期望["_内容"] = 内
    期望["_页签"] = [[名, 文(键), 体, 数据键[名]] for 名, 键, 体 in 页签]	# 第 4 项 = 会话字段名，门用它验数据通路
    期望["_模板行"] = 模板行
    期望["_菜单"] = 菜单模板
    with io.open(os.path.join(期望目录, "好友页期望.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(期望, f, ensure_ascii=False, indent=1)
    print("好友窗口.tscn：%d 节点、期望 %d 条；内容 %dx%d" % (len(节点), len(期望) - 4, 内[0], 内[1]))


def 色(hex文):
    h = hex文.lstrip("#")
    return "Color(%s, %s, %s, 1)" % tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def 转BB(文):
    文 = 文.replace("\\'", "'").replace("<br/>", "[br]").replace("<br>", "[br]")
    return 文.replace("</font>", "[/color]")


# ───────────────────────── 子窗（自成一窗：底 + 标题 + 关钮 + 件，全部**窗口坐标**）─────────────────────────
# 这三扇原版都不是"内容页 + 家族式窗壳"的结构：私聊/选人各自带底皮与自己的标题落点，
# 所以场景根就是整窗，宿主（`家族子窗壳`，其控件是元数据驱动的、与家族不耦合）只负责摆位置。
# 标题/关钮公式：`MWindow.as:162-221` —— 非小底 标题 y=5、关钮 y=6；**小底 标题 y=3、关钮 y=4**。
窗边 = [48, 29.25, 48.05, 18]		# MWindow_background(3) 275×325（《度量表》§13:152）
小窗边 = [49.5, 25.75, 52.05, 18]	# MWindowSmall_background(767) 243×171（§13:1017）
输入边 = [6.25, 5, 6.75, 6]		# MTextInput_background(437) 125×21（§13:1016）
选中边 = [7, 5.35, 7.9, 5.75]		# MSelected_background1(705) 189×19（§13:1013）

子窗 = {
    "好友私聊窗": {
        "窗": [262, 330], "底": ["通用", "窗口边框", 窗边], "小底": False,
        "标题键": "FRIENDCHAT_WINDOW_TITLE",		# 「与%1对话中」⇒ %1 由宿主填玩家名（FCW:132）
        "控制器": "res://脚本/界面/窗口/好友/好友私聊窗.gd",
        "as3": "FriendChatWindow.as:124-148,273-282",
        "件": [
            ["内盒", "九宫", [5, 33, 252, 265], ["通用", "子面板", 盒边], "FCW:134-138 MPane_background"],
            ["上区", "九宫", [13, 40, 237, 147], ["通用", "内容面板", 黄边], "FCW:139-147 _upBg MYellow 237×147"],
            ["下区", "九宫", [13, 212, 237, 80], ["通用", "内容面板", 黄边], "FCW:146-148 _downBg 237×80 @13,212"],
            ["消息视口", "容器", [19, 45, 228, 140], ["裁剪"], "FCW:70-76 ScrollPane 228×140、横向条 off"],
            # 消息容器**嵌在视口里**（局部原点 = 视口原点）：行往上长时靠视口裁剪 + 容器位移滚。
            # 宽 = 行宽 216（`FC:12`），不是视口宽 228 —— 控制器 `_重铺()` 也按 216 收口。
            ["消息视口/消息容器", "容器", [19, 45, 216, 0], [], "FCW:238-239,312 行按 y=堆叠高累加（行宽 216，FC:12）"],
            ["输入", "输入文本", [18, 218, 228, 73], ["长:100"], "FCW:78-87 TextField INPUT 228×73、白字、maxChars=ChatUtil.INPUT_MAX_CHARS(100)"],
            ["表情钮", "钮皮", [230, 192, 18, 18], ["好友", "表情钮"], "FCW:280-282 FriendFaceBtn(566) x=206−18+42 字面量链"],
            ["发送钮", "钮", [193, 301, 54, 22], ["好友", "钮底54", "FRIENDCHAT_SEND"], "FCW:273-277 isScale9Grid=true ⇒ 宽=文字48+6=54"],
        ],
    },
    "好友打探窗": {
        "窗": [294, 215], "底": ["通用", "窗口边框", 窗边], "小底": False,
        "标题键": "DATAN_WINDOW_TITLE", "标题填": True,
        "控制器": "res://脚本/界面/窗口/好友/好友打探窗.gd",
        "as3": "MPromptWindow.as:96-102,411-465",
        # 窗高 = 红字y + 55（MPW:465）；红字y = 棕底底；棕底y = 说明y(46) + **说明.textField.height** + 4（MPW:428）
        # ⇒ 说明正文 `DATAN_PROMPT_3`（"…需要消耗一个“%1”"）在 262 宽 / 12 号下实测**两行**
        #    ⇒ textField.height = 15·2 = 30、盒高 = 30+4 = 34、棕底 y = 80。换行数随运行期代入的材料名变，
        #    重摆由控制器负责（同装备打造 `_摆分隔线` 口径），这里烘的是"两行"这一确定态。
        "件": [
            ["橙说明", "富文", [8, 46, 262, 34], ["DATAN_PROMPT_3", "#FF7F00"], "MPW:417-423 宽=内容宽−16、@ (内容x, 内容y+8)、居中橙字；两行 ⇒ 盒 34"],
            ["棕底", "九宫", [14, 80, 266, 80], ["通用", "子面板", 盒边], "MPW:424-430 宽=内容宽−12、高 80、y=说明 textField 底+4"],
            ["材料格", "图", [21, 87, 40, 40], ["通用", "物品格"], "MPW:432-434 MGrid_background(172) 40×40 = 棕底 +7/+7"],
            ["头像", "区", [41, 107, 40, 40], [], "MPW:435-440 PortraitHead 40×40 挂在**格内 (20,20)**（AS3 字面就溢出 40 格，未证本意）；头像是运行期位图（SwfLibManager），本工程没有该数据 ⇒ 只留命中区不编图"],
            ["信息串", "富文", [66, 84, 233, 57], ["", "#FF9740"], "MPW:441-450 宽=内容宽−45、leading4、@ (格右+5, 格y−3)；3 行 = 15·3+2·4+4=57（正文随数据 DATA_INFOSTR_1..3）"],
            ["红字", "富文", [21, 160, 262, 19], ["", "#FF0000"], "MPW:452-456 UI_RED、宽=内容宽−16、@ (格x, 棕底底)；正文 DATAN_PROMPT_1/2 随数据"],
            ["材料盒", "区", [205, 67, 60, 64], [], "MPW:459-461 ItemCaiLiaoBox setSize(60,64)、x=棕底右−60−15、y=棕底y−13"],
            ["打探钮", "钮", [40, 188, 30, 22], ["好友", "钮底30", "DATAN_BUTTON_NAME"], "MPW:239-241,256,267 isScale9Grid=true ⇒ 宽=24+6=30、x=40、y=215−22−5"],
            ["取消钮", "钮", [224, 188, 30, 22], ["好友", "钮底30", "COMMON_CANCEL"], "MPW:244-246,268 宽=30、x=294−30−40"],
        ],
    },
    "好友选人窗": {
        "窗": [292, 279], "底": ["通用", "小窗口边框", 小窗边], "小底": True,
        "标题键": "SELCET_PLAYER_WINDOW_TITLE",		# 原键就拼错 SELCET（SPW:123）
        "控制器": "res://脚本/界面/窗口/好友/好友选人窗.gd",
        "as3": "SelectPlayerWindow.as:123-164,212-228,369-423",
        "件": [
            ["内容底", "九宫", [6, 30, 280, 215], ["通用", "内容面板", 黄边], "SPW:377-381 bg2 = 底宽−12"],
            ["列表底", "九宫", [10, 83, 270, 142], ["通用", "子面板", 盒边], "SPW:383-387 bg3 = bg2 宽−10"],
            ["输入框底", "九宫", [88, 36, 102, 21], ["通用", "输入框", 输入边], "SPW:389-393 437 号；**高未设** ⇒ 吃皮 21"],
            ["横线一", "图", [14, 60, 252, 2], ["通用", "横向分隔线"], "SPW:394-399"],
            ["横线二", "图", [14, 104, 252, 2], ["通用", "横向分隔线"], "SPW:412-417"],
            ["竖分隔一", "图", [148, 84, 2, 20], ["好友", "表头竖分隔"], "SPW:400-405 x=148 字面量"],
            ["竖分隔二", "图", [204, 84, 2, 20], ["好友", "表头竖分隔"], "SPW:406-411 x=204"],
            ["选中条", "九宫", [12, 108, 265, 19], ["通用", "选中条1", 选中边], "SPW:418-423 curSelectCell，初值 visible=false（:145）"],
            ["名标签", "字", [11, 36, 78, 18], ["右", "PLAYER_NAME"], "SPW:124-126"],
            ["名输入", "输入", [91, 37, 99, 18], ["长:20"], "SPW:127-133 INPUT 白字"],
            ["结果标签", "字", [11, 64, 263, 18], ["左", "SEARCH_RESULTS"], "SPW:146-147"],
            ["表头一", "字", [13, 85, 132, 18], ["居中", "GAME_PLAYER_NAME"], "SPW:148-150"],
            ["表头二", "字", [150, 85, 51, 18], ["居中", "CHARACTOR_LEVEL"], "SPW:151-153"],
            ["表头三", "字", [206, 85, 51, 18], ["居中", "CHARACTOR_JOB"], "SPW:154-156"],
            ["行容器", "容器", [12, 108, 265, 117], ["裁剪"], "SPW:162-164,47 cellContainer；pageSize=5、行 y=(21+2)i"],
            ["模糊提示", "字", [11, 223, 182, 18], ["左", "SEARCH_MOHU", "#FF9100"], "SPW:157-159 色 16748800"],
            ["页码", "字", [211, 224, 34, 18], ["居中"], "SPW:135-142 currentPage，autoSize=CENTER 不吃鼠标"],
            ["上一页钮", "钮皮", [194, 223, 15, 13], ["通用", "上一页", "三态"], "SPW:222-224 MPagePreBtnF(856)"],
            ["下一页钮", "钮皮", [244, 223, 15, 13], ["通用", "下一页", "三态"], "SPW:226-228 MPageNextBtnF(855)"],
            ["搜索钮", "钮", [207, 36, 37, 22], ["好友", "钮底37", "TROOP_SEARCH_BTN"], "SPW:212-213 w=btn_width_two"],
            ["查看资料钮", "钮", [26, 251, 61, 22], ["好友", "钮底61", "TROOP_SHOW_CHAR_INFO_BTN", "禁"], "SPW:214-216 w=61、**初值 disabled**"],
            ["多功能钮", "钮", [116, 251, 61, 22], ["好友", "钮底61", "MULTIFUNCTIONAL", "禁"], "SPW:217-219 w=61、**初值 disabled**"],
            ["取消钮", "钮", [201, 251, 61, 22], ["好友", "钮底61", "COMMON_CANCEL"], "SPW:220-221 w=61"],
        ],
    },
}


def 建子窗(名, 定):
    """自成一窗的场景：底 + 标题 + 关钮 + 件（全窗口坐标，不减原点）。"""
    序[0] = 0
    资源.clear()
    节点.clear()
    期望 = {}
    宽, 高 = 定["窗"]
    题Y = 3.0 if 定["小底"] else 5.0		# `MWin.as:166-173` 小底标题 y=3、非小底 y=5
    目 = 定["底"]
    局 = [0, 0, 宽, 高]
    节点.append(节("窗底", "NinePatchRect", ".", 矩形行(局) + [
        "texture = ExtResource(\"%s\")" % 加((通用皮 if 目[0] == "通用" else 好友皮) % 目[1])] +
        ["patch_margin_%s = %d" % (s, 整(v)) for s, v in zip(["left", "top", "right", "bottom"], 目[2])]))
    期望["窗底"] = [局, "%s 底 = %s(%s 号皮) 按窗尺寸九宫拉伸" % (定["as3"], 目[1], 目[0])]

    期望["标题"] = [[0, 题Y, 宽, 18], "%s 标题 y=%s 整幅居中；文案 %s（含 %%1 时由宿主替换玩家名）" % (定["as3"], 题Y, 定["标题键"])]
    节点.append(节("标题", "Label", ".", 矩形行([0, 题Y, 宽, 18]) + [
        "text = \"%s\"" % (文(定["标题键"]) if 定.get("标题填") else ""),
        "horizontal_alignment = 1", "vertical_alignment = 1",
        "theme_override_colors/font_color = %s" % 色("#FCF49C")]))
    关X = round(宽 - 25 - 6)
    关Y = 题Y + 1
    期望["关钮"] = [[关X, 关Y, 25, 24], "MWin.as:208-212 closeBtn.x = round(底宽−钮宽−6)、y = 标题y+1"]
    节点.append(节("关钮", "TextureButton", ".", 矩形行([关X, 关Y, 25, 24], False) + [
        "focus_mode = 0", "ignore_texture_size = true",
        "texture_normal = ExtResource(\"%s\")" % 加(通用皮 % "关闭按钮"),
        "metadata/act = \"关闭\"",
        "script = ExtResource(\"9_三态\")", "mouse_default_cursor_shape = 2"]))
    局表 = {}
    for 件 in 定["件"]:
        种, 局, 附 = 件[1], 件[2], 件[3]
        出处 = 件[4]
        件名 = 件[0].rsplit("/", 1)[-1]
        父 = 件[0].rsplit("/", 1)[0] if "/" in 件[0] else "."
        局父 = 局表[父][:2] if 父 != "." else [0, 0]
        局相对 = [局[0] - 局父[0], 局[1] - 局父[1], 局[2], 局[3]]
        局表[件[0]] = 局
        期望[件名] = [局, 出处]		# 期望一律**窗口坐标**（嵌套节点的 position 是局部的，门自己换算）
        if 种 == "九宫":
            节点.append(节(件名, "NinePatchRect", 父, 矩形行(局相对) + [
                "texture = ExtResource(\"%s\")" % 加((通用皮 if 附[0] == "通用" else 好友皮) % 附[1])] +
                ["patch_margin_%s = %d" % (s, 整(v)) for s, v in zip(["left", "top", "right", "bottom"], 附[2])]))
        elif 种 == "图":
            节点.append(节(件名, "TextureRect", 父, 矩形行(局相对) + [
                "texture = ExtResource(\"%s\")" % 加((通用皮 if 附[0] == "通用" else 好友皮) % 附[1]),
                "expand_mode = 1", "stretch_mode = 0"]))
        elif 种 == "区":
            节点.append(节(件名, "Control", 父, 矩形行(局相对)))
        elif 种 == "富文":
            节点.append(节(件名, "RichTextLabel", 父, 矩形行(局相对) + [
                "theme_override_constants/line_separation = 2",
                "theme_override_font_sizes/normal_font_size = 12",
                "theme_override_colors/default_color = %s" % 色(附[1]),
                "bbcode_enabled = true",
                "text = \"%s\"" % (转BB(文(附[0])) if 附[0] else " "),
                "scroll_active = false"]))
        elif 种 == "容器":
            行 = 矩形行(局相对, False)
            if "裁剪" in 附:
                行.append("clip_contents = true")
            节点.append(节(件名, "Control", 父, 行))
        elif 种 == "字":
            行 = 矩形行(局相对) + ["horizontal_alignment = %d" % {"左": 0, "右": 2, "居中": 1}[附[0]],
                              "vertical_alignment = 1"]
            if len(附) > 1:
                行.append("text = \"%s\"" % 文(附[1]))
            if len(附) > 2:
                行.append("theme_override_colors/font_color = %s" % 色(附[2]))
            节点.append(节(件名, "Label", 父, 行))
        elif 种 == "输入":
            节点.append(节(件名, "LineEdit", 父, 矩形行(局相对, False) + [
                "theme_override_styles/normal = SubResource(\"StyleBoxEmpty1\")",
                "theme_override_styles/focus = SubResource(\"StyleBoxEmpty1\")",
                "theme_override_font_sizes/font_size = 12",
                "theme_override_colors/font_color = %s" % 色("#FFFFFF"),
                "max_length = %s" % 附[0].split(":")[1]]))
        elif 种 == "输入文本":
            节点.append(节(件名, "TextEdit", 父, 矩形行(局相对, False) + [
                "theme_override_styles/normal = SubResource(\"StyleBoxEmpty1\")",
                "theme_override_styles/focus = SubResource(\"StyleBoxEmpty1\")",
                "theme_override_font_sizes/font_size = 12",
                "theme_override_colors/font_color = %s" % 色("#FFFFFF"),
                "max_length = %s" % 附[0].split(":")[1]]))
        elif 种 == "钮皮":
            皮 = (通用皮 if 附[0] == "通用" else 好友皮) % 附[1]
            行 = 矩形行(局相对, False) + [
                "focus_mode = 0", "ignore_texture_size = true",
                "texture_normal = ExtResource(\"%s\")" % 加(皮),
                "metadata/skin = \"%s\"" % 皮[:-4], "metadata/act = \"%s\"" % 件名]
            if "三态" in 附:
                行 += ["script = ExtResource(\"9_三态\")", "mouse_default_cursor_shape = 2"]
            节点.append(节(件名, "TextureButton", 父, 行))
        else:	# 钮：预烘宽档 + 子 Label
            皮 = (通用皮 if 附[0] == "通用" else 好友皮) % 附[1]
            节点.append(节(件名, "TextureButton", 父, 矩形行(局相对, False) + [
                "focus_mode = 0", "ignore_texture_size = true",
                "texture_normal = ExtResource(\"%s\")" % 加(皮),
                "metadata/skin = \"%s\"" % 皮[:-4], "metadata/act = \"%s\"" % 件名,
                # 原版初值 disabled 的钮（选人窗"查看资料/多功能"）⇒ 烘进场景，编辑器 = 运行期
                "disabled = true" if len(附) > 3 and 附[3] == "禁" else "disabled = false",
                "", "[node name=\"Label\" type=\"Label\" parent=\"%s\"]" % 件[0],
                "layout_mode = 1", "anchors_preset = 15", "anchor_right = 1.0", "anchor_bottom = 1.0",
                "grow_horizontal = 2", "grow_vertical = 2", "mouse_filter = 2",
                "text = \"%s\"" % 文(附[2]), "horizontal_alignment = 1", "vertical_alignment = 1"]))
    有输入 = any(件[1] in ("输入", "输入文本") for 件 in 定["件"])
    # 关钮永远挂三态皮 ⇒ ext_resource 多一份、load_steps 也 +1（load_steps = ext + sub + 1）
    头 = ["[gd_scene load_steps=%d format=3]" % (len(资源) + (4 if 有输入 else 3)),
          '[ext_resource type="Script" path="%s" id="1_script"]' % 定.get("控制器", 子窗控制器)]
    头 += 资源		# ⚠ ext_resource 必须在 sub_resource **之前**（写反了整窗 instantiate 静默 null）
    头 += ['[ext_resource type="Script" path="%s" id="9_三态"]' % 三态脚本]
    if 有输入:
        头 += ["", '[sub_resource type="StyleBoxEmpty" id="StyleBoxEmpty1"]']
    根 = ["[node name=\"%s\" type=\"Control\"]" % 名,
          "custom_minimum_size = Vector2(%d, %d)" % (宽, 高),
          "script = ExtResource(\"1_script\")", "窗名 = \"%s\"" % 名]
    out = os.path.join(场景目录, 名 + ".tscn")
    # `newline="\n"`：在库 `.tscn`/`.json` 全是 LF，Windows 缺省会写成 CRLF ⇒ 重生一次凭空脏一片（§3.228）。
    with io.open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n\n".join(头 + ["", "\n".join(根)] + 节点) + "\n")
    with io.open(os.path.join(期望目录, "好友子窗_%s.json" % 名), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"窗": [宽, 高], "小底": 定["小底"], "标题键": 定["标题键"], "件": 期望}, f,
                  ensure_ascii=False, indent=1)
    print("   %-12s %dx%d　%d 件" % (名, 宽, 高, len(期望)))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    建()
    for 名 in 子窗:
        建子窗(名, 子窗[名])
