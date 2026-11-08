# -*- coding: utf-8 -*-
"""从有头量具 `开发工具/截秘笈合成页.gd` 的 const 表生成
`场景/界面/窗口/秘籍合成/秘籍合成窗口.tscn`（原版 `JiNengCompositeWindow` 340×381，一个页签）。

**改真值改量具表再重跑本脚本，别手改 `.tscn`**（手改会被下一次生成吃掉；
而 `.tscn` 里的 `;` 注记会被 Godot 存盘剥掉 ⇒ 逐件出处只写在
`测试/截图/秘笈合成_对照/真值对照表.md` 与 `game-client/真值/窗口/秘笈合成.md`）。

三件必须照原版的东西，都在这里显式做掉：
  1. **同级顺序 = 绘制顺序 = AS3 `addChild` 顺序**：
     `:191-193` `contentBox → tabBar → upgradeBtn` ⇒ 页签条**压在内容框顶沿 2px 上**；
     内容框内 `:197/204/226/227/236` = 说明 → 放入残卷区 → **材料说明 → 材料排** → 结果区
     （`_fuDescTextField` 比 `_fuBox` 先 addChild ⇒ 材料格画在说明之上）；
     结果区内 `:253-256` = 结果 → 勾选 → **「个幸运符」→ 下拉**（单位在下拉之前）。
  2. **文字一律从量具 `原文` 现译**（含空态把占位符 `￥`/`$` 替成 0）⇒ 场景与门共读一份原文。
  3. **CheckBox 的控制矩形 == 皮肤矩形**（10-25 主题补上 `CheckBox/hover_pressed` 空盒后
     最小高 = 原版 upSkin 的 19；当年是 27 ⇒ 要外扩 4、量具再折回 4，两头都绕）；
     下拉必须是 **MenuButton + `flat=false`**
     （`OptionButton` 有 64px 最小宽地板会压住「个幸运符」；`MenuButton` 默认 flat 则整块背景不画）。
"""
import io
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
from 场景id import ascii化		# 资源 id 一律 ASCII（见 开发工具/场景id.py 的说明）
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
量具 = os.path.join(工程, "开发工具", "截秘笈合成页.gd")
出 = os.path.join(工程, "场景", "界面", "窗口", "秘籍合成", "秘籍合成窗口.tscn")
根 = "原版秘籍合成内容"
NL = "\n"
源码 = io.open(量具, encoding="utf-8").read()


def 块(名, 起=None):
    i = 源码.find(起 or ("const %s := {" % 名))
    if i < 0:
        raise SystemExit("量具里没有 " + 名)
    j = 源码.find("\n}", i)
    return 源码[i:j]


def 取字典(名, 起=None):
    正 = 块(名, 起)
    出 = {}
    for m in re.finditer(r'"([^"]+)"\s*:\s*(\[[^\]]*\]|"[^"]*")', 正):
        出[m.group(1)] = m.group(2)
    return 正, 出


def 去引(v):
    return v.strip('"')


_, 路径原 = 取字典("件路径")
路径 = {k: 去引(v) for k, v in 路径原.items()}
_, 期望原 = 取字典("件期望")
期望 = {k: [float(x) for x in v.strip("[]").split(",")] for k, v in 期望原.items()}
_, 原文原 = 取字典("原文")
原文 = {k: 去引(v) for k, v in 原文原.items()}
_, 页签原 = 取字典("页签真值")
页签真值 = {k: [x.strip().strip('"') for x in v.strip("[]").split(",")] for k, v in 页签原.items()}
下拉皮 = {k: 去引(v) for k, v in 取字典("下拉皮")[1].items()}
材料格文案 = [x.strip().strip('"') for x in re.search(
    r"const 材料格文案 := \[([^\]]*)\]", 源码).group(1).split(",")]
页签宽 = float(页签真值["页签0"][1])

# 页面件表是 const（离线门也读它）⇒ 直接截块
件表文 = 块("页面件")
页面件表 = {}
for m in re.finditer(r"(\d+)\s*:\s*\[([^\]]*)\]", 件表文):
    页面件表[int(m.group(1))] = [x.strip().strip('"') for x in m.group(2).split(",") if x.strip()]


def 译(文):
    """量具 `译文为BBCode` 的等价实现（三边同源：语言表原文 → 场景 → 门）。"""
    文 = 文.replace("<br/>", "\n").replace("<br>", "\n")
    文 = 文.replace("<font color='", "[color=").replace('<font color="', "[color=")
    文 = 文.replace("'>", "]").replace('">', "]").replace("</font>", "[/color]")
    return 文


def 纯(文):
    """量具 `纯文本` 的等价实现：`Label` / `Button.text` 没有 BBCode，只留正文。"""
    文 = 译(文)
    for 串 in ["[color=#ffffff]", "[color=#00ff00]", "[color=#ff9100]", "[color=#ff9900]",
               "[color=#0081ff]", "[color=#ff0000]", "[/color]"]:
        文 = 文.replace(串, "")
    return 文


def 串字(字):
    r"""`.tscn` 的字符串**不许有裸换行**（实测会让 `load()` 直接 SIGSEGV）⇒ 一律转义成 `\n`。
    反斜杠本身不动：BBCode 原文里没有反斜杠。"""
    return 字.replace('"', '""').replace("\n", "\\n")


通用 = "原版窗口/通用控件"		# ⚠ 必须用正斜杠：`.tscn` 的路径分隔符就是 `/`，
								# 用 os.path.join 在 Windows 上会拼出 `\` ⇒ 素材全部找不到
# 边距约定 [左, 右, 上, 下]，只认 `脚本/界面/原版皮肤表.gd` + 《共用件度量表》§13（禁拟合值）。
图 = {
    "内容面板": (通用 + "/内容面板.png", [11, 10, 10, 11]),		# MYellow_background(10)
    "子面板": (通用 + "/子面板.png", [8, 7, 7, 7]),			# MPane_background(97)
    "物品格": (通用 + "/物品格.png", [9, 6, 9, 6]),			# MGrid_background(172)
    "分隔线": (通用 + "/横向分隔线.png", [0, 0, 0, 0]),		# LineHPicF：extends Sprite ⇒ 整帧非等比
    "方向箭头": (通用 + "/方向箭头.png", [4.25, 4.25, 1, 9.25]),	# ItemArrow(1016) §13:875
    "页签未选": (通用 + "/分页按钮未选.png", [7, 8, 7, 7]),		# MTabButton_up(121)
    "页签未选悬停": (通用 + "/分页按钮未选_悬停.png", [7, 8, 7, 7]),	# 加亮(未选, +30) 预烘
    "页签选中": (通用 + "/分页按钮选中.png", [9, 8, 9, 4]),		# MTabButton_disabled(118) = selectedUpSkin
    "下拉框": (通用 + "/下拉框.png", [5.5, 22.75, 5, 5.5]),		# ComboBox_upSkin(614)
    "下拉框悬停": (通用 + "/下拉框悬停.png", [6, 22, 5, 5.5]),		# overSkin(620)
    "下拉框按下": (通用 + "/下拉框按下.png", [6, 22.75, 5.25, 5.5]),	# downSkin(623)
    "下拉框禁用": (通用 + "/下拉框禁用.png", [6, 21.75, 5.5, 5.25]),	# disabledSkin(617)
}
缺图 = [k for k, (p, _) in 图.items()
        if not os.path.isfile(os.path.join(工程, "素材", "界面", *p.split("/")))]
if 缺图:
    print("!! 素材缺失:", 缺图)
    sys.exit(1)
扩展id = {k: "t%d" % i for i, k in enumerate(图)}

橙 = "Color(1, 0.6, 0, 1)"				# UI_ORANGE 16748800（`ItemCaiLiaoBox.as:131`）
白 = "Color(1, 1, 1, 1)"					# `:237/:260` textColor / MGlowLabel.color = 16777215
页签字色 = "Color(0.988235, 0.956863, 0.611765, 1)"		# #fcf49c，`MTabButton.as:12` 四态同色


def 文(字, 行距=6, 对齐=0):
    """RichTextLabel：bbcode + 不换行溢出 + 不出滚动条（原版是 dynamic TextField）。"""
    出 = ('bbcode_enabled = true' + NL + 'text = "%s"' % 串字(字) + NL
          + 'scroll_active = false' + NL + 'autowrap_mode = 3' + NL
          + 'theme_override_constants/line_separation = %d' % 行距)
    if 对齐:
        出 += NL + ('horizontal_alignment = %d' % 对齐)
    return 出 + NL


def 标(字, 色, 对齐=1):
    """Label（原版 MLabel / MGlowLabel：单色、无 BBCode、高恒 20）。"""
    return ('text = "%s"' % 串字(字) + NL + 'horizontal_alignment = %d' % 对齐 + NL
            + 'vertical_alignment = 1' + NL
            + 'theme_override_font_sizes/font_size = 12' + NL
            + 'theme_override_colors/font_color = %s' % 色 + NL + 'mouse_filter = 2' + NL)


def 钮(字, 色=页签字色):
    """MButtonF 那类文字钮：字 + 字色（皮走全局主题，见真值 md §8.4 那条已知未决）。"""
    return ('text = "%s"' % 串字(字) + NL + 'horizontal_alignment = 1' + NL
            + 'theme_override_colors/font_color = %s' % 色 + NL)


# ── 件种表：件名 → (类型, 图键或 None, 附加属性) ────────────────────────────
# 矩形一律取 期望[件名]（页面局部绝对值），派生件在下面 派生 里按父格现算。
样式页签 = "".join('theme_override_styles/%s = SubResource("sb_tab_%s")' % (n, n) + NL
                   for n in ("normal", "hover", "pressed", "hover_pressed"))
样式下拉 = "".join('theme_override_styles/%s = SubResource("sb_combo_%s")' % (n, n) + NL
                   for n in ("normal", "hover", "pressed", "disabled"))
规格 = {
    "内容框": ("Panel", "内容面板", ""),
    "开始合成": ("Button", None, 钮(纯(原文["开始合成"]))),
    "说明": ("RichTextLabel", None, 文(译(原文["说明"]), 6)),
    "说明分隔线": ("TextureRect", "分隔线", "mouse_filter = 2" + NL),
    "放入残卷区": ("Panel", "子面板", ""),
    "放入残卷": ("Button", None, 钮(纯(原文["放入残卷"]))),
    "主残卷格": ("TextureRect", "物品格", "mouse_filter = 2" + NL),
    "方向箭头": ("Panel", "方向箭头", ""),
    "秘籍格": ("TextureRect", "物品格", "mouse_filter = 2" + NL),
    "材料说明": ("RichTextLabel", None, 文(译(原文["材料说明"]), 6)),
    "结果区": ("Panel", "子面板", ""),
    "结果": ("RichTextLabel", None, 文(译(原文["结果"].replace("￥", "0").replace("$", "0")), 6)),
    "使用幸运符": ("CheckBox", None, 'text = "%s"' % 串字(纯(原文["使用幸运符"])) + NL
                 + 'theme_override_colors/font_color = ' + 白 + NL + 'button_icon_size = 19' + NL),
    "单位": ("Label", None, 标(纯(原文["单位"]), 白, 0)),
    # ⚠ `MenuButton` 默认 flat=true ⇒ `Button::draw` 整块背景不画（接了皮也看不见），必须显式 false。
    "幸运符数量": ("MenuButton", None, 样式下拉
                 + 'theme_override_colors/font_color = ' + 白 + NL
                 + 'theme_override_colors/font_disabled_color = ' + 白 + NL
                 + 'flat = false' + NL + 'text = "1"' + NL + 'disabled = true' + NL
                 + 'alignment = 0' + NL),
}
for i in range(1, 5):
    规格["材料格%d" % i] = ("Control", None, "mouse_filter = 2" + NL)

# 页签：1 枚（`EQUIP_UPGRADE_TAB_NAMES` 长度 1）
规格["分页"] = ("Control", None, "mouse_filter = 2" + NL)
规格["页签0"] = ("Button", None, 样式页签
                + "".join("theme_override_colors/%s = %s" % (k, 页签字色) + NL for k in
                          ("font_color", "font_hover_color", "font_pressed_color",
                           "font_hover_pressed_color", "font_disabled_color"))
                + 'toggle_mode = true' + NL + 'button_pressed = true' + NL
                + 'text = "%s"' % 串字(页签真值["页签0"][0]) + NL)

# ── 树：件名 → (父件名, 矩形)；顺序 = 绘制顺序（AS3 addChild 序）─────────────
树 = [(根, None, [0, 0, 340, 352]),
      ("内容框", None, 期望["内容框"]),
      ("说明", "内容框", 期望["说明"]),
      ("说明分隔线", "内容框", 期望["说明分隔线"]),
      ("放入残卷区", "内容框", 期望["放入残卷区"]),
      ("放入残卷", "放入残卷区", 期望["放入残卷"]),
      ("主残卷格", "放入残卷区", 期望["主残卷格"]),
      ("方向箭头", "放入残卷区", 期望["方向箭头"]),
      ("秘籍格", "放入残卷区", 期望["秘籍格"]),
      ("材料说明", "内容框", 期望["材料说明"])]
for i in range(1, 5):
    名 = "材料格%d" % i
    格 = 期望[名]
    树.append((名, "内容框", 格))
    树.append(("%s/标签" % 名, 名, [格[0], 格[1], 56, 20]))		# MLabel 高恒 20、adjustContent=false
    树.append(("%s/物品格" % 名, 名, [格[0] + 8, 格[1] + 20, 40, 40]))	# (56−40)/2=8
树.append(("材料格4/购买", "材料格4", 期望["购买"]))			# 只有 _fu4 = ItemCaiLiaoBox(true)
树 += [("结果区", "内容框", 期望["结果区"]),
       ("结果", "结果区", 期望["结果"]),
       ("使用幸运符", "结果区", 期望["使用幸运符"]),
       ("单位", "结果区", 期望["单位"]),
       ("幸运符数量", "结果区", 期望["幸运符数量"]),
       ("分页", None, [10, 9, 页签宽, 22]),
       ("页签0", "分页", [10, 9, 页签宽, 22]),
       ("开始合成", None, 期望["开始合成"])]


def 型(件名):
    if 件名.endswith("/标签"):
        i = int(re.search(r"材料格(\d)/标签", 件名).group(1))
        return ("Label", None, 标(材料格文案[i - 1], 橙))
    if 件名.endswith("/物品格"):
        return ("TextureRect", "物品格", "mouse_filter = 2" + NL)
    if 件名.endswith("/购买"):
        return ("Button", None, 钮(纯(原文["购买"])))
    return 规格[件名]


# ── 资源块 ────────────────────────────────────────────────────────────────
def 箱(编号, 键, 内容边距=None):
    p, 边 = 图[键]
    内 = 内容边距 or (0.0, 0.0, 0.0, 0.0)
    return (('[sub_resource type="StyleBoxTexture" id="sb_%s"]' % 编号 + NL
             + 'texture = ExtResource("%s")' % 扩展id[键] + NL
             + 'texture_margin_left = %s' % 边[0] + NL + 'texture_margin_right = %s' % 边[1] + NL
             + 'texture_margin_top = %s' % 边[2] + NL + 'texture_margin_bottom = %s' % 边[3] + NL
             + 'content_margin_left = %s' % 内[0] + NL + 'content_margin_right = %s' % 内[1] + NL
             + 'content_margin_top = %s' % 内[2] + NL + 'content_margin_bottom = %s' % 内[3] + NL + NL))


皮四 = {"normal": "页签未选", "hover": "页签未选悬停",
        "pressed": "页签选中", "hover_pressed": "页签选中"}
体 = [箱("tab_%s" % n, 皮四[n]) for n in ("normal", "hover", "pressed", "hover_pressed")]
体 += [箱(k, k) for k in ("内容面板", "子面板", "方向箭头")]
# fl `ComboBox.drawLayout:651-655`：inputField @(textPadding=3, 3)、宽 = W − buttonWidth(24) − 3
# ⇒ 文字框 content_margin 左3 / 右24 / 上3 / 下0
下拉内 = (3, 24, 3, 0)
体 += [箱("combo_%s" % n, "下拉框" + {"normal": "", "hover": "悬停",
      "pressed": "按下", "disabled": "禁用"}[n], 下拉内)
        for n in ("normal", "hover", "pressed", "disabled")]

注释 = [
    '; 由 `开发工具/生成秘笈合成场景.py` 从量具表 `截秘笈合成页.gd` 的 件路径/件期望/原文/页签真值/下拉皮 生成。',
    '; **改真值改量具表再重跑生成器，别手改本文件**（手改会被下一次生成吃掉）。',
    '; 原版 `com/mxw/uifl/controls/equip/JiNengCompositeWindow.as` 340×381（`super(340,381)` 在 `:79`）。',
    '; 场景 y = AS3 窗口局部 y − 29（「技能书」在 `窗口尺寸.json` 标 `整框: true` ⇒ 容器原点 (0,29)）。',
    '; 同级顺序 = AS3 addChild 序（内容框 → 页签条 → 提交钮；内容框内 说明 → 残卷区 → 材料说明 → 材料排 → 结果区）。',
    '; 逐件出处见 `测试/截图/秘笈合成_对照/真值对照表.md` 与 `game-client/真值/窗口/秘笈合成.md`。']
头 = ["[gd_scene load_steps=0 format=3]", NL.join(注释)]
for k, (p, _) in 图.items():
    头.append('[ext_resource type="Texture2D" path="res://素材/界面/%s" id="%s"]' % (p, 扩展id[k]))
头.append("")

模板行 = ('[node name="%s" type="%s"%s]' + NL + '%s'
           + 'layout_mode = 0' + NL + 'offset_left = %s' + NL + 'offset_top = %s' + NL
           + 'offset_right = %s' + NL + 'offset_bottom = %s' + NL)
矩形 = {件: 矩 for 件, _, 矩 in 树}
# ⚠ `.tscn` 的 `parent=` 是**从场景根算**的路径，不是相对父节点 ⇒ 必须先把每个件的全路径
#   推出来（孙件写短名会被判 `Parent path './×' has vanished`、**整批静默丢掉**，2026-09-30 设置页踩过）。
全路 = {根: ""}
for 件名, 父, _ in 树:
    if 件名 == 根:
        continue
    名 = 件名.rsplit("/", 1)[-1]
    全路[件名] = 名 if 父 is None else "%s/%s" % (全路[父], 名)
# 量具里"第 1 格/第 4 格的子件"用的是别名键，比对时映射过来
别名 = {"材料格标签": "材料格1/标签", "材料格物品格": "材料格1/物品格", "购买": "材料格4/购买"}
# 校验：生成出来的路径必须与量具 `件路径` 逐字一致（不一致 = 门与场景对不上）
for 件名, 路 in 路径.items():
    我 = 全路.get(别名.get(件名, 件名))
    if 我 != 路:
        print("!! 路径不一致 %s：场景 %s ≠ 量具 %s" % (件名, 我, 路))
        sys.exit(1)
行 = []
for 件名, 父, 矩 in 树:
    名 = 件名.rsplit("/", 1)[-1] if 件名 != 根 else 根
    if 件名 == 根:
        类型, 附 = "Control", "custom_minimum_size = Vector2(340, 352)" + NL
        父注 = ""
    else:
        类型, 键, 附 = 型(件名)
        附 = 附 or ""
        if 类型 == "Panel":
            附 = 'theme_override_styles/panel = SubResource("sb_%s")' % 键 + NL + 附
        elif 类型 == "TextureRect":
            附 = ('texture = ExtResource("%s")' % 扩展id[键] + NL
                 + "expand_mode = 1" + NL + "stretch_mode = 0" + NL + 附)
        elif 类型 == "CheckBox":
            # 10-25 起**不再外扩**：主题给 `CheckBox/hover_pressed` 补了空盒，最小高 = 皮肤高 19
            # ⇒ 控制矩形 == 真值表里的皮肤矩形，直接照抄。（当年是 27，要 y−4 / 高+8 才对得上）
            pass
        # ⚠ 直接子节点必须写 `parent="."`：写成 `parent=""` 会让 Godot 解析期递归、栈溢出 SIGSEGV
        父路 = 全路[父] if 父 else ""
        父注 = ' parent="."' if 父路 == "" else ' parent="%s"' % 父路
    基 = 矩形.get(父, [0, 0, 0, 0]) if 父 else [0, 0, 0, 0]
    行.append(模板行 % (名, 类型, 父注, 附,
                        矩[0] - 基[0], 矩[1] - 基[1], 矩[0] - 基[0] + 矩[2], 矩[1] - 基[1] + 矩[3]))

头[0] = "[gd_scene load_steps=%d format=3]" % (1 + len(图) + len(体))
正文 = NL.join(头) + "".join(体) + NL + NL.join(行) + NL
assert 正文.count('[node name=') == len(树), "节点数 %d ≠ 树 %d" % (正文.count('[node name='), len(树))
for 件名 in 页面件表[0]:
    if 件名 not in 路径:
        print("!! 页面件表里的 %s 不在 件路径" % 件名)
        sys.exit(1)

# 资源 id 一律 ASCII（Godot 的 scene unique ID 只许 `[A-Za-z0-9_]` 且不以数字开头；
# 中文 id 每加载一次吐一行 ERROR）。见 开发工具/场景id.py。
正文 = ascii化(正文)
if os.path.exists(出):
    io.open(出 + ".bak", "w", encoding="utf-8", newline=NL).write(io.open(出, encoding="utf-8").read())
    旧 = io.open(出, encoding="utf-8").read().count('[node name=')
    备 = os.path.basename(出) + ".bak"
else:
    旧, 备 = 0, "无"
io.open(出, "w", encoding="utf-8", newline=NL).write(正文)
print("生成 %s：%d 个节点、%d 张图、%d 个样式盒（旧文件 %d 个节点，备份 %s）"
      % (os.path.relpath(出, 工程), len(树), len(图), len(体), 旧, 备))
