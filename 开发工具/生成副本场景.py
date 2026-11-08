# -*- coding: utf-8 -*-
"""从有头量具 `开发工具/截副本页.gd` 的 const 表 + `数据/副本.json` 生成
`场景/界面/窗口/副本/副本窗口.tscn`（原版 `CopyWindow` 570×283）。

**改真值改量具表再重跑本脚本，别手改 `.tscn`**（手改会被下一次生成吃掉；`.tscn` 里的 `;`
注记会被 Godot 存盘剥掉 ⇒ 逐件出处只写在 `测试/截图/副本_对照/真值对照表.md`
与 `game-client/真值/窗口/副本.md`）。

五件必须照原版的东西，都在这里显式做掉：
  1. **同级顺序 = 绘制顺序 = AS3 `init()` 的 addChild 序**（`CopyWindow.as:126`→`:259`）：
     内容底 → 列表面板 → 详情面板 → 列头底 → 四枚列头 → 三根竖分隔 → 星级标题 → 星级分隔
     → 星容器 → 详情滚动 → 勾选 → 排行钮 → 进入钮 → 密卷钮 → **列表最后**（盖在所有底之上）。
     行内同理：`CopyWindowCell.as:56-91` 是 名/等级/组队/次数 **之后**才 add 悬停框、选中框
     ⇒ 行底压在字之上（那张皮本来就是一圈，原版就这么画）。
  2. **行是数据驱动、但烘进场景**（编辑器=运行期）：9 行 = `getAllFuBenObj`+`filterData`
     之后的 9 条，四列文案在生成期就算好（`组队` 走 `COPY_CELL_*`、`次数` 走 `%1/%2次`）。
  3. **`isScale9Grid = false` 的钮用预烘到目标宽的整帧皮**（`开发工具/烘副本页皮.py`）：
     三档 = 常 / 悬停+30 / 按下−40。**不用 `texture_hover`、不用 modulate**。
  4. **CheckBox 的控制矩形 == 皮肤矩形**（量具记的就是 19 高的皮矩形，这里原样烘）：
     主题给 `CheckBox/hover_pressed` 补了空盒 ⇒ 最小高回到 19，不再需要外扩 4 的补偿
     （见 `脚本/界面/原版皮肤表.gd` 的 CheckBox 段）。
  5. **星级按 `newStars()`（`:279-314`）烘**：`ceil(stars)` 枚亮、末枚只在 `stars == ceil`
     时才用实心；其余槽 `visible = false` 常驻（运行期只翻 visible，不新建节点）。

坐标约定：树里每条的矩形一律**页面局部绝对值**（= 窗口坐标 − (0,29)），节点自己的
`offset_*` = 本件绝对值 − 父件绝对值 ⇒ ScrollContainer 的内容件自然落到 (0,0)。
"""
import io
import json
import math
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
from 场景id import ascii化		# 资源 id 一律 ASCII（见 开发工具/场景id.py 的说明）
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
量具 = os.path.join(工程, "开发工具", "截副本页.gd")
出 = os.path.join(工程, "场景", "界面", "窗口", "副本", "副本窗口.tscn")
根 = "原版副本内容"
NL = "\n"
源码 = io.open(量具, encoding="utf-8").read()
配置 = json.load(io.open(os.path.join(工程, "数据", "副本.json"), encoding="utf-8"))
文案 = json.load(io.open(os.path.join(工程, "数据", "界面", "副本_文案.json"), encoding="utf-8"))
物品 = json.load(io.open(os.path.join(工程, "数据", "物品.json"), encoding="utf-8"))
副本 = 配置["副本"]


def 块(名):
    i = 源码.find("const %s :=" % 名)
    if i < 0:
        raise SystemExit("量具里没有 " + 名)
    return 源码[i:源码.find("\n}", i)]


def 取字典(名):
    出 = {}
    for m in re.finditer(r'"([^"]+)"\s*:\s*(\[[^\]]*\]|"[^"]*"|Color\([^)]*\))', 块(名)):
        出[m.group(1)] = m.group(2)
    return 出


路径 = {k: v.strip('"') for k, v in 取字典("件路径").items()}
期望 = {k: [float(x) for x in v.strip("[]").split(",")] for k, v in 取字典("件期望").items()}
原文 = {k: v.strip('"') for k, v in 取字典("原文").items()}
色 = {k: v for k, v in 取字典("文案色").items()}
列色 = {k: v for k, v in 取字典("列色").items()}


def 数组(名):
    return [int(float(x)) for x in re.search(r"const %s := \[([^\]]*)\]" % 名, 源码)
            .group(1).split(",")]


def 整数(名):
    m = re.search(r"const %s := (\d+)" % 名, 源码)
    if not m:
        raise SystemExit("量具里没有标量 const " + 名)
    return int(m.group(1))


行高, 行宽 = float(整数("行高")), float(整数("行宽"))
行列, 行宽列 = 数组("行列"), 数组("行宽列")
星位, 星宽, 星高 = 整数("星位"), 整数("星宽"), 整数("星高")
if len(路径) < 20 or len(期望) < 20 or len(原文) < 10:
    raise SystemExit("量具表解析不全：路径 %d / 期望 %d / 原文 %d" % (len(路径), len(期望), len(原文)))

# ── 素材表（边距只认 脚本/界面/原版皮肤表.gd + 《共用件度量表》§13，禁拟合值）──
通用 = "原版窗口/通用控件"		# ⚠ 必须正斜杠：os.path.join 在 Windows 会拼出 `\`
本页 = "原版窗口/副本"
图 = {
    "内容面板": (通用 + "/内容面板.png", [11, 10, 10, 11]),		# MYellow_background(10) §13:1019
    "子面板": (通用 + "/子面板.png", [7.5, 7.5, 6.75, 6.75]),		# MPane_background(97) §13:1008
    "列表分隔": (通用 + "/列表分隔.png", [76, 76, 6, 6]),		# ListSeparator_background(779) §13:1001
    "竖向分隔线": (通用 + "/竖向分隔线.png", [0, 0, 0, 0]),		# TableSeparatorLineF(593) 2×20 整帧
    "横向分隔线": (通用 + "/横向分隔线.png", [0, 0, 0, 0]),		# LineHPicF(133) extends Sprite ⇒ 整帧非等比
    "选中条1": (通用 + "/选中条1.png", [7, 7.9, 5.35, 5.75]),		# MSelected_background1(705) §13:1013
    "星实心": (本页 + "/星实心.png", [0, 0, 0, 0]),			# StarLevelIconF(693) 14×13
    "星空心": (本页 + "/星空心.png", [0, 0, 0, 0]),			# StarHollowF(782) 14×13
    "复选框未选": (通用 + "/复选框未选.png", None),			# MCheckBoxF(105) 左端 19×19
    "复选框选中": (通用 + "/复选框选中.png", None),
    "钮_进入": (本页 + "/钮_进入.png", [0, 0, 0, 0]),
    "钮_进入悬停": (本页 + "/钮_进入_悬停.png", [0, 0, 0, 0]),
    "钮_进入按下": (本页 + "/钮_进入_按下.png", [0, 0, 0, 0]),
    "钮_密卷": (本页 + "/钮_密卷.png", [0, 0, 0, 0]),
    "钮_密卷悬停": (本页 + "/钮_密卷_悬停.png", [0, 0, 0, 0]),
    "钮_密卷按下": (本页 + "/钮_密卷_按下.png", [0, 0, 0, 0]),
}
缺图 = [k for k, (p, _) in 图.items()
        if not os.path.isfile(os.path.join(工程, "素材", "界面", *p.split("/")))]
if 缺图:
    print("!! 素材缺失:", 缺图, "⇒ 先跑 python 开发工具/烘副本页皮.py")
    sys.exit(1)
扩展id = {k: "t%d" % i for i, k in enumerate(图)}


def 串字(字):
    r"""`.tscn` 的字符串不许裸换行（实测会让 `load()` SIGSEGV）⇒ 一律转义成 `\n`。"""
    return 字.replace('"', '""').replace("\n", "\\n")


def 标(字, 色值, 对齐=1):
    """原版 MLabel / TextField：单色、无 BBCode、`adjustContent=false` ⇒ 矩形写死。"""
    return ('text = "%s"' % 串字(字) + NL + 'horizontal_alignment = %d' % 对齐 + NL
            + 'vertical_alignment = 1' + NL
            + 'theme_override_font_sizes/font_size = 12' + NL
            + 'theme_override_colors/font_color = %s' % 色值 + NL + 'mouse_filter = 2' + NL)


def 富(字):
    return ('bbcode_enabled = true' + NL + 'text = "%s"' % 串字(字) + NL
            + 'scroll_active = false' + NL + 'autowrap_mode = 3' + NL
            + 'theme_override_constants/line_separation = 5' + NL)


def 图块(键, 隐藏=False):
    return ('texture = ExtResource("%s")' % 扩展id[键] + NL + 'expand_mode = 1' + NL
            + 'stretch_mode = 0' + NL + 'mouse_filter = 2' + NL
            + ('visible = false' + NL if 隐藏 else ""))


def 钮(字, 键):
    样 = "".join('theme_override_styles/%s = SubResource("sb_%s_%s")' % (n, 键, n) + NL
                 for n in ("normal", "hover", "pressed"))
    白 = 色["进入钮"]
    return (样 + 'text = "%s"' % 串字(字) + NL + 'horizontal_alignment = 1' + NL
            + "".join('theme_override_colors/%s = %s' % (k, 白) + NL for k in
                      ("font_color", "font_hover_color", "font_pressed_color"))
            + 'mouse_default_cursor_shape = 2' + NL)


# ── 运行期文案在生成期先算一遍（编辑器=运行期）────────────────────────────
def 组队(类型):
    return {"1": 文案["COPY_CELL_SINGLE"], "2": 文案["COPY_CELL_TEAM"],
            "3": 文案["COPY_CELL_TROOP"]}.get(类型, "")


def 上限(条):
    """`CopyWindowCell.as:111-118`：`enter.through > 0` 用它，否则用 `totalCount`
    （=`setData` 第二参 = 服务端 819 帧的 maximum；离线量具按实机截图取 1）。"""
    穿 = int(条["enter"]["through"])
    return 穿 if 穿 > 0 else 1


def 奖励文本(条):
    """`setRightTextFieldData:520-543`：无奖励先取 `FAMILLY_MANAGER_WU`，有则逐条
    `【物品名×数量】`、非末条补换行，整段套绿。"""
    if not 条["prize"]:
        return "[color=#00ff00]" + 文案["FAMILLY_MANAGER_WU"] + "[/color]"
    部 = []
    for p in 条["prize"]:
        名 = 物品.get(str(p["itemid"]), {}).get("name")
        if 名 is None:
            raise SystemExit("物品表里没有 %s ⇒ 不许自造奖励名" % p["itemid"])
        部.append("【%s×%s】" % (名, p["quantity"]))
    return "[color=#00ff00]" + "\n".join(部) + "[/color]"


def 格式串(文):
    r"""`BaseUtil.formatStr`（`BaseUtil.as:378-392`）逐条照抄：删字面 `\r` 与真 `\r`，
    再把**字面 `\n`（两个字符）**和真换行都换成换行。
    ⚠ 数据里的 desc 存的是字面反斜杠 n ⇒ 不套这一步实机会把 `\n` 当正文画出来
    （2026-10-03 截图抓到）。"""
    文 = 文.replace("\\r", "").replace("\r", "")
    return 文.replace("\\n", "\n")


def 说明文本(条):
    """`:545` `BaseUtil.formatStr(desc)` 套 `#ff9100`。"""
    return "[color=#ff9100]" + 格式串(条["desc"]) + "[/color]"


行高字 = 17		# Flash 12px 单行 textHeight（这两块是 autoSize TextField ⇒ 高 = 行数 × 17）


def 行数(文, 宽):
    """`wordWrap=true` + `autoSize=LEFT` ⇒ 高 = 行数 × 17。每行字数按 CJK 满宽估
    （12px 宋体一个汉字正好 12px）⇒ `floor(宽/12)`。**只用来烘初值**；运行期由控制器按
    同一条 `说明.y = 奖励.y + 奖励.高 + 1`（`:544`）重排，门核的是那条算式。"""
    每行 = max(1, int(宽 / 12.0))
    return sum(max(1, math.ceil(len(段) / float(每行))) for 段 in 文.split("\n"))


首 = 副本[0]
奖纯 = "\n".join("【%s×%s】" % (物品[str(p["itemid"])]["name"], p["quantity"])
                 for p in 首["prize"]) or 文案["FAMILLY_MANAGER_WU"]
奖高 = 行数(奖纯, 170) * 行高字
说高 = 行数(格式串(首["desc"]), 200) * 行高字
内高 = max(142.0, 17 + 奖高 + 1 + 说高)

# ── 树：件名(含路径) / 类型 / 页面局部绝对矩形 / 附加属性；顺序 = addChild 序 ──
星儿 = []
枚 = int(math.ceil(首["stars"]))
for i in range(星位):
    实 = i < 枚 - 1 or (i == 枚 - 1 and 首["stars"] == 枚)
    星儿.append(("星容器/星%d" % (i + 1), "TextureRect",
                 [359.0 + i * 星宽, 38.0, float(星宽), float(星高)],
                 图块("星实心" if 实 else "星空心", 隐藏=(i >= 枚))))
树 = [(根, "Control", [0, 0, 570, 254], "custom_minimum_size = Vector2(570, 254)" + NL),
     ("内容底", "Panel", 期望["内容底"], 'theme_override_styles/panel = SubResource("sb_内容面板")' + NL),
     ("列表面板", "Panel", 期望["列表面板"], 'theme_override_styles/panel = SubResource("sb_子面板")' + NL),
     ("详情面板", "Panel", 期望["详情面板"], 'theme_override_styles/panel = SubResource("sb_子面板")' + NL),
     ("列头底", "Panel", 期望["列头底"], 'theme_override_styles/panel = SubResource("sb_列表分隔")' + NL),
     ("列头_名称", "Label", 期望["列头_名称"], 标(原文["列头_名称"], 色["列头_名称"])),
     ("列头_等级", "Label", 期望["列头_等级"], 标(原文["列头_等级"], 色["列头_等级"])),
     ("列头_组队", "Label", 期望["列头_组队"], 标(原文["列头_组队"], 色["列头_组队"])),
     ("列头_次数", "Label", 期望["列头_次数"], 标(原文["列头_次数"], 色["列头_次数"])),
     ("列分隔1", "TextureRect", 期望["列分隔1"], 图块("竖向分隔线")),
     ("列分隔2", "TextureRect", 期望["列分隔2"], 图块("竖向分隔线")),
     ("列分隔3", "TextureRect", 期望["列分隔3"], 图块("竖向分隔线")),
     ("星级标题", "Label", 期望["星级标题"], 标(原文["星级标题"], 色["星级标题"], 0)),
     ("星级分隔", "TextureRect", 期望["星级分隔"], 图块("横向分隔线")),
     ("星容器", "Control", 期望["星容器"], "mouse_filter = 2" + NL)] + 星儿 + [
     ("详情滚动", "ScrollContainer", 期望["详情滚动"],
      'horizontal_scroll_mode = 3' + NL + 'vertical_scroll_mode = 1' + NL),
     ("详情滚动/详情内容", "Control", [328, 67, 224, 内高],
      "custom_minimum_size = Vector2(224, %d)" % int(内高) + NL + "mouse_filter = 2" + NL),
     ("详情滚动/详情内容/奖励标题", "Label", 期望["奖励标题"],
      标(原文["奖励标题"], 色["奖励标题"], 0)),
     ("详情滚动/详情内容/奖励", "RichTextLabel", [348, 84, 170, float(奖高)], 富(奖励文本(首))),
     ("详情滚动/详情内容/说明", "RichTextLabel", [331, float(84 + 奖高 + 1), 200, float(说高)],
      富(说明文本(首))),
     ("勾选", "CheckBox", 期望["勾选"],
      'text = "%s"' % 串字(原文["勾选"]) + NL
      + 'theme_override_colors/font_color = ' + 色["勾选"] + NL
      + 'theme_override_font_sizes/font_size = 12' + NL
      + 'theme_override_icons/unchecked = ExtResource("%s")' % 扩展id["复选框未选"] + NL
      + 'theme_override_icons/checked = ExtResource("%s")' % 扩展id["复选框选中"] + NL
      + 'icon_alignment = 0' + NL + 'alignment = 0' + NL + 'button_icon_size = 19' + NL),
     ("排行钮", "Button", 期望["排行钮"], 钮(原文["排行钮"], "钮_进入") + "visible = false" + NL),
     ("进入钮", "Button", 期望["进入钮"], 钮(原文["进入钮"], "钮_进入")),
     ("密卷钮", "Button", 期望["密卷钮"], 钮(原文["密卷钮"], "钮_密卷")),
     # ↓ 本工程既有的 819 副本流程三枚钮（原版 `CopyWindow` 没有）：静止全隐藏，
     #   位置取底栏 (190..305, 213) 那段空档，皮沿用 37 宽档（不新造宽度）。
     ("确认钮", "Button", 期望["确认钮"], 钮("确认", "钮_进入") + "visible = false" + NL),
     ("取消钮", "Button", 期望["取消钮"], 钮("取消", "钮_进入") + "visible = false" + NL),
     ("领取钮", "Button", 期望["领取钮"], 钮("领取", "钮_进入") + "visible = false" + NL),
     ("列表", "ScrollContainer", 期望["列表"],
      'horizontal_scroll_mode = 3' + NL + 'vertical_scroll_mode = 1' + NL),
     ("列表/行容器", "Control", [14, 36, 行宽, 行高 * len(副本)],
      "custom_minimum_size = Vector2(%d, %d)" % (int(行宽), int(行高 * len(副本))) + NL)]
for i, 条 in enumerate(副本):
    名 = "列表/行容器/行%d" % (i + 1)
    树.append((名, "Control", [14.0, 36.0 + i * 行高, 行宽, 行高],
               "custom_minimum_size = Vector2(%d, %d)" % (int(行宽), int(行高)) + NL
               + 'mouse_filter = 0' + NL))
    树.append(("%s/悬停底" % 名, "TextureRect", [14.0, 36.0 + i * 行高, 行宽, 行高],
               图块("选中条1", 隐藏=True)))
    for c, (列名, 字) in enumerate([("名", 条["name"]), ("等级", str(条["reqLevel"])),
                                    ("组队", 组队(条["teamType"])),
                                    ("次数", 文案["COPY_CELL_COUNT"].replace("%1", "0")
                                     .replace("%2", str(上限(条))))]):
        树.append(("%s/%s" % (名, 列名), "Label",
                   [14.0 + 行列[c], 36.0 + i * 行高, float(行宽列[c]), 18.0],
                   标(字, 列色[列名])))
    # `:81-91` 悬停框、选中框都在四列之后 addChild ⇒ 画在字之上；第 1 行 = selectedIndex 0
    树.append(("%s/选中底" % 名, "TextureRect", [14.0, 36.0 + i * 行高, 行宽, 行高],
               图块("选中条1", 隐藏=(i != 0))))

# ── 资源块 ────────────────────────────────────────────────────────────────
def 箱(编号, 键):
    p, 边 = 图[键]
    return (('[sub_resource type="StyleBoxTexture" id="sb_%s"]' % 编号 + NL
             + 'texture = ExtResource("%s")' % 扩展id[键] + NL
             + 'texture_margin_left = %s' % 边[0] + NL + 'texture_margin_right = %s' % 边[1] + NL
             + 'texture_margin_top = %s' % 边[2] + NL + 'texture_margin_bottom = %s' % 边[3] + NL + NL))


体 = [箱(k, k) for k in ("内容面板", "子面板", "列表分隔")]
for 键 in ("钮_进入", "钮_密卷"):
    for 槽, 后 in (("normal", ""), ("hover", "悬停"), ("pressed", "按下")):
        体.append(箱("%s_%s" % (键, 槽), 键 + 后))

矩形 = {件名: 矩 for 件名, _t, 矩, _a in 树}
全路 = {根: ""}
for 件名, _t, _矩, _a in 树:
    if 件名 == 根:
        continue
    名 = 件名.rsplit("/", 1)[-1]
    父 = 件名.rsplit("/", 1)[0] if "/" in 件名 else None
    全路[件名] = 名 if 父 is None else "%s/%s" % (全路[父], 名)
# 与量具 `件路径` 对拍：门按 `件路径` 取件，场景里必须有**逐字相同**的路径，否则门会
# 报"缺节点"而人看不出是别名写错。量具的键是给人看的短名，所以比的是**值**。
有 = set(全路.values())
for 件名, 路 in 路径.items():
    if 路 not in 有:
        print("!! 量具登记的 件路径[%s]=%s 在场景里不存在（现有 %d 条路径）" % (件名, 路, len(有)))
        sys.exit(1)

注释 = [
    '; 由 `开发工具/生成副本场景.py` 从量具 `截副本页.gd` 的 件路径/件期望/原文/文案色/列色 + `数据/副本.json` 生成。',
    '; **改真值改量具表或重跑生成器，别手改本文件**（手改会被下一次生成吃掉）。',
    '; 原版 `com/mxw/uifl/controls/copy/CopyWindow.as`，`super(570,283)` 在 `:69`；',
    '; 标题 = `COPY_WINDOW_TITLE`「副本传送」（`:138`），**不是**「挑战副本」（那是 NPC 菜单项）。',
    '; 场景 y = AS3 窗口局部 y − 29（「副本」在 `窗口尺寸.json` 标 `整框: true` ⇒ 容器原点 (0,29)）。',
    '; 同级顺序 = AS3 addChild 序（列表在最后 ⇒ 盖住底）；行内 四列 → 悬停框 → 选中框。',
    '; 逐件出处见 `测试/截图/副本_对照/真值对照表.md` 与 `game-client/真值/窗口/副本.md`。']
头 = ["[gd_scene load_steps=0 format=3]", NL.join(注释)]
for k, (p, _) in 图.items():
    头.append('[ext_resource type="Texture2D" path="res://素材/界面/%s" id="%s"]' % (p, 扩展id[k]))
头.append("")

模板行 = ('[node name="%s" type="%s"%s]' + NL + '%s'
           + 'layout_mode = 0' + NL + 'offset_left = %s' + NL + 'offset_top = %s' + NL
           + 'offset_right = %s' + NL + 'offset_bottom = %s' + NL)
行们 = []
for 件名, 类型, 矩, 附 in 树:
    名 = 件名.rsplit("/", 1)[-1] if 件名 != 根 else 根
    if 件名 == 根:
        父注, 基 = "", [0, 0, 0, 0]
    else:
        父 = 件名.rsplit("/", 1)[0] if "/" in 件名 else None
        父路 = 全路[父] if 父 else ""
        # ⚠ 直接子节点必须写 `parent="."`：`parent=""` 会让 Godot 解析期递归、栈溢出 SIGSEGV
        父注 = ' parent="."' if 父路 == "" else ' parent="%s"' % 父路
        基 = 矩形[父] if 父 else [0, 0, 0, 0]
    行们.append(模板行 % (名, 类型, 父注, 附,
                        矩[0] - 基[0], 矩[1] - 基[1], 矩[0] - 基[0] + 矩[2], 矩[1] - 基[1] + 矩[3]))

头[0] = "[gd_scene load_steps=%d format=3]" % (1 + len(图) + len(体))
正文 = NL.join(头) + "".join(体) + NL + NL.join(行们) + NL
assert 正文.count('[node name=') == len(树), "节点数 %d ≠ 树 %d" % (正文.count('[node name='), len(树))
assert 正文.count('parent=""') == 0, "出现 parent=\"\"（会让 load 递归爆栈）"
# 资源 id 一律 ASCII：Godot 的 scene unique ID 只许 `[A-Za-z0-9_]` 且不以数字开头，
# 中文 id（`[sub_resource id="sb_内容面板"]`）每加载一次吐一行 ERROR（全量 77 门 720 行）。
正文 = ascii化(正文)

if os.path.exists(出):
    io.open(出 + ".bak", "w", encoding="utf-8", newline=NL).write(io.open(出, encoding="utf-8").read())
    旧 = io.open(出, encoding="utf-8").read().count('[node name=')
    备 = "副本窗口.tscn.bak"
else:
    旧, 备 = 0, "无"
os.makedirs(os.path.dirname(出), exist_ok=True)
io.open(出, "w", encoding="utf-8", newline=NL).write(正文)
print("生成 %s：%d 个节点、%d 张图、%d 个样式盒（旧文件 %d 个节点，备份 %s）"
      % (os.path.relpath(出, 工程), len(树), len(图), len(体), 旧, 备))
print("  行 %d 条、星 %d 槽亮 %d 枚、详情内容高 %d（奖励 %d 行 / 说明 %d 行）"
      % (len(副本), 星位, 枚, int(内高), 奖高 // 行高字, 说高 // 行高字))
