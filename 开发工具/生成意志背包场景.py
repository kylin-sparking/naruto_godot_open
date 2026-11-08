# -*- coding: utf-8 -*-
"""从量具表 `开发工具/截意志背包页.gd` 生成 `场景/界面/窗口/遗址/意志背包窗口.tscn`。

**改真值改量具表再重跑本文件，别手改 .tscn。**
逐件算式与出处见量具表头注释与 `game-client/真值/窗口/意志背包.md`。

页面局部 y = AS3 窗口局部 y − 29（「遗址」在 `窗口尺寸.json` 标 `整框: true`）。

用法：python 开发工具/生成意志背包场景.py
"""
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
量具 = os.path.join(工程, "开发工具", "截意志背包页.gd")
出 = os.path.join(工程, "场景", "界面", "窗口", "遗址", "意志背包窗口.tscn")
根 = "原版意志背包内容"
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
for 缺 in [k for k in 件路径 if k not in 件期望]:
    print("!! 件期望缺条目:", 缺)
    sys.exit(1)

图 = {
    "黄底": ("原版窗口/通用控件/内容面板.png", [11, 10, 10, 11]),	# §13 MYellow，**不许拟合**
    "输入框": ("原版窗口/通用控件/输入框.png", [6, 7, 5, 6]),	# 原版皮肤表.九宫格[输入框] 真值，禁拟合
    "格底": ("原版窗口/意志背包/格底.png", [0, 0, 0, 0]),			# UISwf_yizhiPack_cellSkin 64×64
    "格悬停": ("原版窗口/意志背包/格悬停.png", [0, 0, 0, 0]),		# cellOverSkin 64×64，初值隐
    # `forbidCell:63` 的 `_icon = UISwf_yizhiPack_feng`（穿戴位等级不够 ⇒ 整格画封印）
    "封印": ("原版窗口/意志背包/封印.png", [0, 0, 0, 0]),
    "穿戴盘": ("原版窗口/意志背包/穿戴盘.png", [0, 0, 0, 0]),		# equipSkin 230×230
    "意志力": ("原版窗口/意志背包/意志力图标.png", [0, 0, 0, 0]),	# yizhiIcon 29×30
    "一键合成": ("专用控件/意志_一键合成.png", [0, 0, 0, 0]),
    "前往学习": ("专用控件/意志_前往学习.png", [0, 0, 0, 0]),
    "自动升级": ("专用控件/意志_自动升级.png", [0, 0, 0, 0]),
    # `MButton3.updateState():335-339`：disabled **不是加性偏移，是换 getGrayFilter()**
    # ⇒ 烘一张灰皮走 `texture_disabled`（Godot 在 disabled 时自动用它）。
    "自动升级灰": ("专用控件/意志_自动升级_灰.png", [0, 0, 0, 0]),
}
缺 = [k for k, (p, _) in 图.items() if not os.path.exists(os.path.join(工程, "素材", "界面", p))]
if 缺:
    print("!! 素材缺失:", 缺)
    sys.exit(1)
扩展id = {k: "t%d" % i for i, k in enumerate(图)}

绿 = "Color(0, 1, 0, 1)"			# UIConfig.UI_GREEN = 0x00FF00
黄 = "Color(1, 0.941176, 0, 1)"		# UIConfig.UI_YELLOW = 0xFFF000
白 = "Color(1, 1, 1, 1)"
暗绿 = "Color(0, 0.8, 0, 1)"			# textFormat.color = 52224 = 0x00CC00
钮字 = "Color(0.988235, 0.956863, 0.611765, 1)"	# MButton3._textColors.up = #FCF49C


def 文(字, 色, 对齐=0, 号=12, 行距=None):
    出 = (("theme_override_font_sizes/font_size = %d" % 号) + NL
          + ("theme_override_colors/font_color = %s" % 色) + NL
          + ("horizontal_alignment = %d" % 对齐) + NL
          + ('text = "%s"' % 字) + NL)
    if 行距 is not None:
        # flash-text-area-geometry 口径：Godot 行距 = AS3 leading + 2
        出 += "line_spacing = %d" % 行距 + NL
    return 出


## 文案从 `数据/界面/意志_文案.json` 读（与量具同源），不在这里再抄一遍。
import json
try:
    with open(os.path.join(工程, "数据", "界面", "意志_文案.json"), encoding="utf-8") as f:
        文案 = json.load(f)
except Exception as e:
    print("!! 读不到 意志_文案.json（先跑 开发工具/出意志文案数据.py）:", e)
    sys.exit(1)


def 键(名):
    v = 文案.get(名)
    if v is None:
        print("!! 意志_文案.json 缺键:", 名)
        sys.exit(1)
    return v


# ── 路径规格：相对根的完整路径 → (类型, 皮键, 附加属性, 初值隐) ────────────────────
路径规格 = {
    "外框黄底": ("Panel", "黄底", None, False),
    "拖动提示": ("Label", None, 文(键("YIZHI_DRAG_PROMPT_LABEL"), 绿), False),
    "意志值框": ("LineEdit", "输入框", 'text = "0"' + NL + "alignment = 1" + NL, False),
    "意志力图标": ("TextureRect", "意志力", "mouse_filter = 2" + NL, False),
    "背包容器": ("Control", None, "mouse_filter = 2" + NL, False),
    "穿戴盘": ("TextureRect", "穿戴盘", "mouse_filter = 2" + NL, False),
    "穿戴容器": ("Control", None, "mouse_filter = 2" + NL, False),
    "升级格": ("Control", None, "", False),
    # 原版 MCheckBoxF 高 = upSkin.height = 19；Godot 侧控件矩形 == 皮肤矩形（10-25 在主题里
    # 给 `CheckBox/hover_pressed` 补了空盒，最小高回到 19；那之前是 27，控件顶边要抬 4 补偿）。
    # `h_separation = 2` = 原版 `tf.x = upSkin.x + upSkin.width + 2`。
    "锁定勾选": ("CheckBox", None, 'text = "锁定意志"' + NL
             + "theme_override_constants/h_separation = 2" + NL, False),
    "自动升级钮": ("TextureButton", "自动升级",
               "disabled = true" + NL
               # ⚠️ 必须是 `texture_disabled`：TextureButton **没有** `theme_override_textures/*`
               #   这条属性（实测 `get_property_list()` 只有 `disabled`/`texture_disabled`），
               #   写成 override 会被 .tscn 解析器**静默丢掉** ⇒ 禁用钮照画亮皮（2026-09-28 就是这么
               #   让「自动升级意志」一直是亮的）。
               + 'texture_disabled = ExtResource("%s")' % 扩展id["自动升级灰"] + NL, False),
    # disabled 的字色 = `MButton3._textColors.disabled` = 9671571 = **#939393**（:69-74），
    # 这颗钮原版造出来就是禁用的 ⇒ 直接烘禁用色（悬停/按下都不会走到它）。
    "自动升级钮/字": ("Label", None, 文("自动升级意志", "Color(0.576471, 0.576471, 0.576471, 1)", 1)
                + "vertical_alignment = 1" + NL + "mouse_filter = 2" + NL, False),
    # 原版 `:483-495` 220×40 = **正好两行**（2×15 + leading 4 + 上下 4 余量），两行由文本里
    # 那个 `\r` 决定（`adjustContent=false`、没开 wordWrap）⇒ 不许自动换行，否则第一行
    # 在 Godot 里被折成三行、掉出 40 高的框。
    "自动升级提示": ("Label", None, 文(
        "提示:任意背包/穿戴意志都可直接拖入此槽\\n勾选锁定后点击升级即可", 暗绿, 0, 12, 6)
        + "autowrap_mode = 0" + NL, False),
    "意志介绍": ("Label", None, 文("[" + 键("YIZHI_INTRODUCE_LABEL") + "]", 黄, 2)
              + "underline = 1" + NL + "mouse_filter = 0" + NL, False),
    "一键合成": ("TextureButton", "一键合成", None, False),
    "一键合成/字": ("Label", None, 文(键("YIZHI_YI_JIAN_HECHENG_BUTTON_NAME"), 钮字, 1)
                + "vertical_alignment = 1" + NL + "mouse_filter = 2" + NL, False),
    "前往学习": ("TextureButton", "前往学习", None, False),
    "前往学习/字": ("Label", None, 文(键("YIZHI_STUDY_BUTTON_NAME"), 钮字, 1)
                + "vertical_alignment = 1" + NL + "mouse_filter = 2" + NL, False),
}

## 一格（`YiZhiCell:110-131`）：格底 + 悬停(隐) + 名称 + 等级。
## ⚠ 与意志学习页的 `YiZhiStudyCell` **不同**：这里的名称/等级是 `createChildren` 无条件造的，
##    只是 text="" ⇒ 结构上存在、画不出东西。图标(`_icon`)才是 `drawYiZhi` 里有数据才建。
for 前缀, 个数, 起 in (("背包容器/格_", 30, 0), ("穿戴容器/格_", 8, 1)):
    for k in range(起, 起 + 个数):
        路 = 前缀 + "%d" % k
        路径规格[路] = ("Control", None, "", False)
        路径规格[路 + "/格底"] = ("TextureRect", "格底", "mouse_filter = 2" + NL, False)
        路径规格[路 + "/格悬停"] = ("TextureRect", "格悬停", "mouse_filter = 2" + NL, True)
        路径规格[路 + "/名称"] = ("Label", None, 文("", 白, 1), False)
        路径规格[路 + "/等级"] = ("Label", None, 文("", 白, 1), False)
        # 封印只属于**穿戴格**（`updateEquipLimit:209-227` 走 forbidCell 那一支）：
        # 初值 `equipLimit=1`（`YiZhiManager.as:56`）⇒ 格_1 开着、格_2..8 画封印。
        # 烘成"编辑器里看见的 = 开页时画出来的"，控制器再按同一条数据重推一遍。
        if 前缀 == "穿戴容器/格_":
            # 第 4 位是「**隐不隐**」：格_1 开着 ⇒ 封印隐；格_2..8 封着 ⇒ 封印显
            路径规格[路 + "/封印"] = ("TextureRect", "封印", "mouse_filter = 2" + NL, k == 1)
路径规格["升级格/格底"] = ("TextureRect", "格底", "mouse_filter = 2" + NL, False)
路径规格["升级格/格悬停"] = ("TextureRect", "格悬停", "mouse_filter = 2" + NL, True)
路径规格["升级格/名称"] = ("Label", None, 文("", 白, 1), False)
路径规格["升级格/等级"] = ("Label", None, 文("", 白, 1), False)

# ── 矩形表：量具里点了名的用 件期望；没点名的格/子件按原版公式算 ──────────────────
矩 = {根: [0.0, 0.0, 663.0, 519.0]}			# 548 − 29（页面容器原点 (0,29)）
for 名, 值 in 件期望.items():
    矩[件路径[名]] = 值
容 = 矩["背包容器"]
for k in range(30):
    路 = "背包容器/格_%d" % k
    矩.setdefault(路, [容[0] + 69 * (k % 5), 容[1] + 69 * (k // 5), 64, 64])
穿 = 矩["穿戴容器"]
for k, (dx, dy) in enumerate([[-29, 81], [-4, 1], [80, -30], [165, 1],
                             [195, 81], [165, 161], [80, 196], [-4, 161]], 1):
    矩.setdefault("穿戴容器/格_%d" % k, [穿[0] + dx, 穿[1] + dy, 64, 64])
# 只取"格"本身（深度 1），别把已经建好的子件（深度 2）再当格套一层
格表 = [k for k in 矩 if k.count("/") == 1 and (k.startswith("背包容器/格_") or k.startswith("穿戴容器/格_"))]
for 格 in 格表 + ["升级格"]:
    底 = 矩[格]
    矩[格 + "/格底"] = [底[0], 底[1], 64, 64]
    # 封印**只有穿戴格有**（`forbidCell` 走 `updateEquipLimit` 那一支；
    # 背包格走 `lockCell` 用的是另一张 `UISwf_BailianCopy_Lack`，本工程没这张皮 ⇒ 不做）
    if 格.startswith("穿戴容器/"):
        矩[格 + "/封印"] = [底[0], 底[1], 64, 64]
    矩[格 + "/格悬停"] = [底[0], 底[1], 64, 64]
    矩[格 + "/名称"] = [底[0], 底[1] + 32, 64, 19]
    矩[格 + "/等级"] = [底[0], 底[1] + 46, 64, 19]
矩["升级格/格底"] = [413, 359, 64, 64]
矩["意志值框"] = 件期望["意志值框"]
钮字表 = {"一键合成": 143, "前往学习": 82, "自动升级钮": 110}
for 路, 宽 in 钮字表.items():
    基 = 矩[路]
    矩[路 + "/字"] = [基[0], 基[1], 宽, 22]
矩["锁定勾选"] = 件期望["锁定勾选"]

# ── 顺序：父在子前，**同级按原版 addChild 顺序** ──────────────────────────────────
# ⚠️ 不能按字典序发节点：Godot 的绘制顺序 = 兄弟节点先后，字典序会把「升级格」排到
#    「外框黄底」**之前** ⇒ 半透的 MYellow 底板（alpha=213）盖在它和 8 枚穿戴格上面，
#    实测盘缘/格圈整体偏亮、像素门 4 个红项（2026-09-28）。
#    原版顺序：`YiZhiPackWindow.onSkinReady:121-195`（_contentBg 由基类 UIWindow 先加）
#    + `initView:431-495`。
出图序 = ["外框黄底",					# UIWindow 的 `_contentBg`（MYellow 8,38 647×480）
          "拖动提示",					# :127-133 _dragLabel
          "意志值框",					# :134-138 _yiZhiField
          "意志力图标",					# :139-142 UISwf_yizhiPack_yizhiIcon
          "背包容器",					# :143-146 _yiZhiContainer（30 格）
          "穿戴盘",						# :154-157 equipSkin
          "穿戴容器",					# :159 _equipPanel（8 格，**在盘之上**）
          "意志介绍",					# :160-178 _introduceLabel
          "一键合成",					# :179-186 _heChengBtn
          "前往学习",					# :187-193 _studyBtn
          "升级格",						# :468 initView _upgradeCell
          "锁定勾选",					# :474 _lockCheckBox
          "自动升级钮",					# :482 _autoUpgradeBtn
          "自动升级提示"]					# :495 _autoUpgradeTip
# 格内子件的先后（底 → 悬停 → 图标 → 文字）：原版 `YiZhiCell.createChildren` 同序
# 原版 `createChildren` 先加 底/悬停/名/级，`forbidCell:64` 再 `addChildAt(_icon, 1)`
# ⇒ 封印坐在**格底之上、悬停框之下**（不是最后盖一层）
子序 = ["格底", "图标", "封印", "格悬停", "名称", "等级", "字", "召唤文字"]


def 序键(p: str):
    段 = p.split("/")
    首 = 段[0]
    组 = 出图序.index(首) if 首 in 出图序 else len(出图序)
    # ⚠ 取**叶子名**：`子序` 管的是格内子件（`穿戴容器/格_2/封印` 这一层）。
    #   先前写的是 `段[1]` ⇒ 深度 2 的件全部拿到中间那段（"格_2"）、查不到 ⇒ 一起落到
    #   兜底档、只按路径字符串排 ⇒ 汉字码点序（名540D < 封5C01 < 格683C < 等7B49）
    #   ⇒ **封印被排到格底之下**，半透的格底把 封 字蒙成看不清的暗印（像素门实测 10.47% 超阈）。
    子 = 段[-1]
    子i = 子序.index(子) if 子 in 子序 else len(子序)
    return (组, p.count("/"), 子i, p)


全部 = set(矩.keys()) | set(件路径.values())
顺序 = [根] + sorted([p for p in 全部 if p != 根], key=序键)
for p in 顺序:
    上 = p.rsplit("/", 1)[0]
    while 上 and 上 not in 顺序:
        print("!! 缺父节点路径:", 上, "（子:", p, "）")
        sys.exit(1)

头注 = [
    '; 由 `开发工具/生成意志背包场景.py` 从量具表 `截意志背包页.gd` 的 件路径/件期望 生成。',
    '; **改真值改量具表再重跑生成器，别手改本文件。**',
    '; 原版 `com/mxw/uifl/controls/yiZhi/YiZhiPackWindow.as`，663×548，整窗 1:1 移植。',
    '; 场景 y = AS3 窗口局部 y − 29（`窗口尺寸.json` 的「遗址」标 `整框: true`）。',
    '; 美术来自运行期包 `swf/UISwf/UISwf_yizhiPack.swf`（格底/格悬停/equipSkin/yizhiIcon/feng）。']
头 = ["[gd_scene load_steps=%d format=3]" % (1 + len(图) + 2), NL.join(头注)]
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
# 2026-10-03 融合轮补：原生成器把 **Texture2D 直接写进 `theme_override_styles/normal`**
# （`Required object "rp_style" is null` 每条 LineEdit 开页报一次）—— 样式槽要的是 StyleBox。
# 边距用 原版皮肤表.九宫格[输入框] = [左6 右7 上5 下6]（2026-10-01 核过），不是拟合值。
箱 += (('[sub_resource type="StyleBoxTexture" id="sb_input"]' + NL
        + 'texture = ExtResource("%s")' + NL
        + 'texture_margin_left = 6' + NL + 'texture_margin_top = 5' + NL
        + 'texture_margin_right = 7' + NL + 'texture_margin_bottom = 6' + NL
        + 'content_margin_left = 0.0' + NL + 'content_margin_right = 0.0' + NL
        + 'content_margin_top = 0.0' + NL + 'content_margin_bottom = 0.0' + NL + NL)
       % 扩展id["输入框"])
模板 = ('[node name="%s" type="%s"%s]' + NL + '%s%s' + NL
        + 'layout_mode = 0' + NL + 'offset_left = %s' + NL + 'offset_top = %s' + NL
        + 'offset_right = %s' + NL + 'offset_bottom = %s' + NL)

行 = []
for 路 in 顺序:
    名 = 路.rsplit("/", 1)[-1]
    父 = 路.rsplit("/", 1)[0] if "/" in 路 else ""
    x, y, w, h = 矩[路]
    基 = [0, 0, 0, 0] if 父 == "" else 矩.get(父, [0, 0, 0, 0])
    if 路 == 根:
        类型, 附加, 隐 = "Control", "custom_minimum_size = Vector2(663, 519)" + NL, False
    else:
        相 = 路
        型 = 路径规格.get(相)
        if 型 is None:
            print("!! 路径规格缺:", 相)
            sys.exit(1)
        类型, 键名, 附, 隐 = 型
        附 = 附 or ""
        if 键名:
            资 = 'ExtResource("%s")' % 扩展id[键名]
            if 类型 == "Panel":
                # Panel 没有 `texture` 属性：写上去会被丢掉、落到全局主题默认皮
                附 = 'theme_override_styles/panel = SubResource("sb_yellow")' + NL + 附
            elif 类型 == "TextureButton":
                附 = 'texture_normal = %s' % 资 + NL + 附
            elif 类型 == "LineEdit":
                附 = ('theme_override_styles/normal = SubResource("sb_input")'
                     + NL + 附)
            else:
                附 = 'texture = %s' % 资 + NL + "expand_mode = 1" + NL + 附
        附加 = 附
    # 表里的路径本来就是**相对根**的 ⇒ 根的直接子节点写 parent="."，其余原样写父路径
    父注 = '' if 路 == 根 else ' parent="%s"' % ("." if 父 == "" else 父)
    行.append(模板 % (名, 类型, 父注, ("visible = false" + NL if 隐 else ""), 附加,
                      x - 基[0], y - 基[1], x - 基[0] + w, y - 基[1] + h))

正文 = NL.join(头) + 箱 + NL + NL.join(行) + NL
open(出, "w", encoding="utf-8", newline=NL).write(正文)
print("生成 %s：%d 个节点" % (os.path.relpath(出, 工程), len(顺序)))
