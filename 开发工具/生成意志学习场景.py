# -*- coding: utf-8 -*-
"""从 开发工具/截意志学习页.gd 的 件路径/件期望 生成 场景/界面/窗口/遗址/意志学习窗口.tscn。

口径与 `生成宠物场景.py` 相同：**真值只写在量具表里**，.tscn 是产物，别手改。
本版改进（宠物版的教训）：
  * 节点类型/贴图/文案按**相对根的完整路径**显式登记，不靠文件名猜；
  * 父节点自动补登时不覆盖已登记的真矩形；
  * 子节点 offset 一律换算成**相对父**（件期望 存的是页面局部绝对矩形）。

用法：python 开发工具/生成意志学习场景.py     # 之后 --import + 跑量具
"""
import io
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
量具 = os.path.join(工程, "开发工具", "截意志学习页.gd")
出 = os.path.join(工程, "场景", "界面", "窗口", "遗址", "意志学习窗口.tscn")
根 = "原版意志学习内容"
NL = chr(10)
源码 = open(量具, encoding="utf-8").read()


def 表(名):
    i = 源码.find("const %s := {" % 名)
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
    "黄底": ("原版窗口/通用控件/内容面板.png", [11, 10, 10, 11]),
    "背景": ("原版窗口/意志/背景.png", [0, 0, 0, 0]),
    "小标题底": ("原版窗口/意志/小标题底.png", [0, 0, 0, 0]),
    "元宝": ("原版窗口/通用控件/元宝币.png", [0, 0, 0, 0]),
    "阅历": ("原版窗口/意志/阅历图标.png", [0, 0, 0, 0]),
    "格底": ("原版窗口/意志/意志格底.png", [0, 0, 0, 0]),
    "导师条": ("原版窗口/意志/导师条底.png", [0, 0, 0, 0]),
    "悬停框": ("原版窗口/意志/导师悬停框.png", [0, 0, 0, 0]),
    "气泡1": ("原版窗口/意志/气泡1.png", [0, 0, 0, 0]),
    "气泡2": ("原版窗口/意志/气泡2.png", [0, 0, 0, 0]),
    "气泡3": ("原版窗口/意志/气泡3.png", [0, 0, 0, 0]),
    "返回": ("原版窗口/意志/钮_返回.png", [0, 0, 0, 0]),
    "卖出": ("原版窗口/意志/钮_全部卖出.png", [0, 0, 0, 0]),
    "拾取": ("原版窗口/意志/钮_全部拾取.png", [0, 0, 0, 0]),
    "学习": ("原版窗口/意志/钮_一键学习.png", [0, 0, 0, 0]),
    "背包钮": ("原版窗口/意志/打开背包钮.png", [0, 0, 0, 0]),
    # 「召唤」= `BaseUtil.getButton()` → `MButtonF extends MButton3`，共享皮 `按钮.png`(57×22)
    # 但 `TeacherCell:57-64` 关掉九宫格并把宽压成 37 ⇒ 用**离线压扁好的 37×22 常态皮**，
    # 运行期只换 `texture_normal`（三态见 `开发工具/生成意志钮态图.py`）。
    "召唤钮": ("专用控件/意志_召唤.png", [0, 0, 0, 0]),
}
for i in range(1, 6):
    图["导师%d" % i] = ("原版窗口/意志/导师%d.png" % i, [0, 0, 0, 0])
## Panel 类件走 stylebox，子资源编号见 `箱(编号, 键)`（`体 = [箱("yellow", "黄底")]`）。
面板皮 = {"黄底": "yellow"}
缺 = [k for k, (p, _) in 图.items() if not os.path.exists(os.path.join(工程, "素材", "界面", p))]
if 缺:
    print("!! 素材缺失:", 缺)
    sys.exit(1)
扩展id = {k: "t%d" % i for i, k in enumerate(图)}
黄 = "Color(1, 0.941176, 0, 1)"      # UIConfig.UI_YELLOW #FFF000
白 = "Color(1, 1, 1, 1)"


def 文(字, 色, 对齐=0, 号=12):
    return (("theme_override_font_sizes/font_size = %d" % 号) + NL
            + ("theme_override_colors/font_color = %s" % 色) + NL
            + ("horizontal_alignment = %d" % 对齐) + NL
            + ('text = "%s"' % 字) + NL)


零边距 = ("theme_override_constants/expand_margin_left = 0.0" + NL
          + "theme_override_constants/expand_margin_right = 0.0" + NL
          + "theme_override_constants/expand_margin_top = 0.0" + NL
          + "theme_override_constants/expand_margin_bottom = 0.0" + NL)


def 钮底(宽, 高):
    return "custom_minimum_size = Vector2(%d, %d)" % (宽, 高) + NL + 零边距


def 译文为BBCode(文):
    """与量具基类 `译文为BBCode()` 同一套换算（AS3 HTML → Godot BBCode）。"""
    for 旧, 新 in (("\r\n", "\n"), ("\r", "\n"), ("<br/>", "\n"), ("<br>", "\n"),
               ("<font color='", "[color="), ('<font color="', "[color="),
               ("'>", "]"), ('">', "]"), ("</font>", "[/color]")):
        文 = 文.replace(旧, 新)
    return 文


原文路径 = os.path.join(工程, "数据", "界面", "意志_说明原文.txt")
说明原文 = open(原文路径, encoding="utf-8").read()
说明文 = 译文为BBCode(说明原文)
assert 说明文.startswith("[color=") and "[/color]" in 说明文, "BBCode 换算失败: " + 说明文[:60]


路径规格 = {
    "外框黄底": ("Panel", "黄底", None, False),
    "主背景": ("TextureRect", "背景", None, False),
    "小标题条": ("TextureRect", "小标题底", None, False),
    "货币条": ("Control", None, "mouse_filter = 2" + NL, False),
    "货币条/元宝图标": ("TextureRect", "元宝", None, False),
    "货币条/阅历图标": ("TextureRect", "阅历", None, False),
    "货币条/元宝数值": ("Label", None, 文("0", 黄), False),
    "货币条/阅历数值": ("Label", None, 文("0", 白), False),
    "意志容器": ("Control", None, "mouse_filter = 2" + NL, False),
    "导师面板": ("Control", None, "mouse_filter = 2" + NL, False),
    "导师面板/条底": ("TextureRect", "导师条", None, False),
    "导师面板/导师容器": ("Control", None, "mouse_filter = 2" + NL, False),
    "导师面板/今日次数": ("Label", None, 文("今日还可免费学习意志0次", 白), False),
    "导师面板/说明文字": ("RichTextLabel", None,
                   "bbcode_enabled = true" + NL + "scroll_active = false" + NL
                   + "fit_content = true" + NL
                   + 'text = "%s"' % 说明文.replace(NL, chr(92) + "n").replace('"', chr(92) + '"') + NL, False),
    # 四枚大钮 + 打开背包：原版都是 `ProgramButton extends MButton3` ⇒ **一张皮 + 运行时加性滤镜**，
    # 文字画在皮里（不是 MButton3 的 textFormat）。所以用 TextureButton 直接贴皮，
    # 三态由控制器换 `texture_normal`（见 `开发工具/生成意志钮态图.py` 烘的 _悬停/_按下）。
    # ⚠ 不用 Button+stylebox：那会把钮撑进主题的内容边距，尺寸就不是原生的 98/96/94/88 宽。
    "导师面板/一键学习": ("TextureButton", "学习", None, False),
    "导师面板/全部拾取": ("TextureButton", "拾取", None, False),
    "导师面板/全部卖出": ("TextureButton", "卖出", None, False),
    "导师面板/返回": ("TextureButton", "返回", None, False),
    "导师面板/打开背包": ("TextureButton", "背包钮", None, False),
}
# ⚠️ 2026-10-22 §3.185：range(10) → range(20)。原版 `YiZhiContainer` 动态排**两行**
#   （LENGTH=10，`getYiZhiPoint:68-69` y=(i/10)·82），服务端 `SPIRIT_PANEL_LIMIT = 20`。
#   旧规格只烘一排 ⇒ 面板 ≥11 件时第二层不在场景里（用户实机报「应该有第二层，
#   但是没有显示」）。第二排位置槽同样整格隐藏、由 `_填学习格` 按数据显。
for k in range(20):
    前 = "意志容器/意志格_%d" % k
    # ⚠ **空态一个格子都没有**（用户 2026-09-28 用两张原版截图指出：没学出意志时那一排是空的）。
    #   依据 `YiZhiContainer.setData:78-93`：先 `removeAllCells()`，再**按数据条数**
    #   `new YiZhiStudyCell(...)` ⇒ 0 条数据 = 0 个格，连 `cellBg` 都不画。
    #   所以 10 个"格位"只是**位置槽**（`updateDisplayList:68-69` 的 15+72·(k%10) / 71+72·(k/10)），
    #   整格初值隐藏；有数据时由 `_填意志格()` 逐格显出来。子件保持 visible=true，靠父隐藏。
    路径规格[前] = ("Control", None, "", True)
    路径规格[前 + "/格底"] = ("TextureRect", "格底", "mouse_filter = 2" + NL, False)
    # 原版 `YiZhiContainer.setData` 只在**有数据**时才给格子造 图标/名称/卖出/拾取
    # ⇒ 空态（服务端没回）只剩格底。烘成 visible=false，编辑器视图 = 运行期视图。
    路径规格[前 + "/图标"] = ("TextureRect", None, "expand_mode = 1" + NL, False)
    路径规格[前 + "/名称"] = ("Label", None, 文("", 白, 1), False)
    # ⚠ 这两个小字**必须烘 `mouse_filter = 0`**：原版它们是 `MLabel + buttonMode +
    #   useHandCursor + CLICK`（`YiZhiStudyCell.as:95-101,109-117` 发 pickUpOne/sellOne），
    #   而 Godot 的 Label 默认 `mouse_filter=IGNORE(2)` ⇒ 不写就是"看得见点不动"：
    #   `gui_input` 永远收不到，点击直接穿透到下层图标（2026-10-20 玩家实机报
    #   「学习到的意志无法拾取」，量具 `开发工具/验意志一键钮.gd` 复现：hovered=图标）。
    #   控制器 `_填学习格` 运行期也会设一遍（双保险，别因此删这里）。
    路径规格[前 + "/卖出"] = ("Label", None, "mouse_filter = 0" + NL + 文("卖出", 黄, 2), False)
    路径规格[前 + "/拾取"] = ("Label", None, "mouse_filter = 0" + NL + 文("拾取", 黄), False)
for k in range(5):
    前 = "导师面板/导师容器/导师_%d" % k
    路径规格[前] = ("Control", None, "", False)
    # 原版可点的是 `_header` 本体（`TeacherCell:46-49` buttonMode + CLICK），
    # 不是另加一枚热区钮；`lightTeacher()` 再按点亮/灰决定 mouseEnabled。
    路径规格[前 + "/头像"] = ("TextureRect", "导师%d" % (k + 1),
                       "mouse_filter = 0" + NL, False)
    # 原版 `TeacherCell:53,71` 把 `_overSkin` / `_paoPao` 的 `mouseEnabled/mouseChildren` 全设 false。
    # Godot 侧 TextureRect 默认是 `PASS`（=1），仍会当 hover 目标 ⇒ 黄框一显就盖住头像、
    # 把 hover 抢走，头像收到 mouse_exited 又把框收掉，来回踢 = 用户报的"一闪一闪"。
    # 烘成 IGNORE（=2）才和原版一致。
    路径规格[前 + "/悬停框"] = ("TextureRect", "悬停框", "mouse_filter = 2" + NL, True)
    路径规格[前 + "/气泡"] = ("TextureRect", "气泡动图", "mouse_filter = 2" + NL, k != 0)
    # 「召唤」钮：`TeacherCell:57-64` 的算式是 x=(56−37)/2=**9.5**、y=57−22/2=**46**
    # ⇒ 钮**骑在头像下沿**（46..68 而头像只有 0..57），正是用户截图里那个样子。
    # 文字是 MButton3 自己的 tf（不是画在皮里）⇒ 单独一个 Label，三态换色 #fcf49c/#ffffc3/#acadb2。
    路径规格[前 + "/召唤"] = ("TextureButton", "召唤钮", None, True)
    # ⚠ 初值**不能**烘 visible=false：控制器 `setZhaoHunButtonVisible` 只切父钮，
    #    子 Label 自己隐着就永远不出字（用户报"召唤的字哪去了"）。父钮隐 ⇒ 子件自然不画。
    路径规格[前 + "/召唤/召唤文字"] = ("Label", None,
                             文("召唤", "Color(0.988235, 0.956863, 0.611765, 1)", 1) + NL
                             + "vertical_alignment = 1" + NL   # MButton3 的 tf 在钮里**垂直居中**
                             + "mouse_filter = 2" + NL, False)
# 相对路径 → (件名, 皮键)：四枚大钮各用自己的 UISwf_Text_* 原件，互不共用
动画气泡 = True
钮皮 = {"导师面板/一键学习": ("一键学习", "学习"), "导师面板/全部拾取": ("全部拾取", "拾取"),
       "导师面板/全部卖出": ("全部卖出", "卖出"), "导师面板/返回": ("返回", "返回")}

节点 = {根: {"父": "", "矩": [0, 0, 772, 535]}}
顺序 = [根]


def 加(相对, 矩=None):
    路 = 相对 if 相对 == 根 else 根 + "/" + 相对
    if 路 in 节点:
        if 矩 and not any(节点[路]["矩"]):
            节点[路]["矩"] = 矩
        return
    父 = 路.rsplit("/", 1)[0] if "/" in 路 else ""
    if 父 and 父 != 根 and 父 not in 节点:
        加(父[len(根) + 1:])
    节点[路] = {"父": 父, "矩": 矩 or [0, 0, 0, 0]}
    顺序.append(路)


for 名, 路 in 件路径.items():
    加(路, 件期望.get(名))   # 件路径 的值是页面局部相对路径
# ⚠️ 2026-10-22 §3.185（用户实机报「应该有第二层，但是没有显示」）：原版
#   `YiZhiContainer:64-69` 按数据**动态排两行**（LENGTH=10，`y=(i/10)·(62+20)`），
#   服务端 `SPIRIT_PANEL_LIMIT = 20` ⇒ 20 格才是全容量。旧循环 range(10) 只烘一排，
#   面板 ≥11 件时多出的件在客户端**无处显示、不可拾取/卖出**。两行坐标照真值算式：
#   x=(i%10)·72，格 y=71+(i/10)·82；子件 y 同层平移。
for k in range(20):
    _行, _列 = divmod(k, 10)
    _格x = 15 + 72 * _列
    _格y = 71 + 82 * _行
    加("意志容器/意志格_%d" % k, [_格x, _格y, 62, 62])
    加("意志容器/意志格_%d/格底" % k, [_格x, _格y, 62, 62])
    加("意志容器/意志格_%d/图标" % k, [_格x + 3, _格y + 3, 56, 56])
    加("意志容器/意志格_%d/名称" % k, [_格x, _格y + 24, 62, 19])
    加("意志容器/意志格_%d/卖出" % k, [_格x + 2, _格y + 38, 58, 19])
    # 「拾取」宽 **24 = 2×12px 汉字墨迹**：原版 `_pickBtn` 不设 width
    # （`YiZhiStudyCell.as:94-96` 只有 x=5，MLabel 的 adjustContent 按墨迹自适应）⇒
    # 可点区只盖左一小条，右对齐的「卖出」墨迹（≈36..60）才点得到。
    # 曾取 52 ⇒ 「拾取」矩形 5..57 盖住卖出文字区，点「卖出」命中上层的「拾取」
    # （2026-10-20 实测：点卖出中心 hovered=拾取）——原版绝不会这样。
    加("意志容器/意志格_%d/拾取" % k, [_格x + 5, _格y + 38, 24, 19])
for k in range(5):
    加("导师面板/导师容器/导师_%d" % k, [55 + 76 * k, 441, 56, 57])
    加("导师面板/导师容器/导师_%d/头像" % k, [55 + 76 * k, 441, 56, 57])
    加("导师面板/导师容器/导师_%d/悬停框" % k, [55 + 76 * k, 441, 57, 57])
    加("导师面板/导师容器/导师_%d/气泡" % k, [89 + 76 * k, 419, 46, 48])
    # 基准**必须取自量具表**（`导师0召唤`），别再写死一遍数字 ——
    # 上一轮把 0 位改成 x=9.5/y=46 时，1..4 位仍吃这行的旧常量，结果只有第 0 格对。
    _召 = 件期望["导师0召唤"]
    加("导师面板/导师容器/导师_%d/召唤" % k, [_召[0] + 76 * k, _召[1], _召[2], _召[3]])
    加("导师面板/导师容器/导师_%d/召唤/召唤文字" % k, [_召[0] + 76 * k, _召[1], _召[2], _召[3]])

# ── 导师格子件发射顺序归位：气泡必须压在头像上（2026-10-21 用户实机报）────────
# 兄弟节点**后声明 = 绘制/命中都在上层**。原版 `TeacherCell.as` 的 addChild 顺序：
# 头像(:48) → 悬停框(:54) → 召唤钮(:63) → 气泡(:72)，气泡在**最后** = 画在人物前面
# （用户原话：「图层这里黄色的应该在人物前面，第一个是对的，把所有的核对一样，
#   都要和第一个一样」）。
# ⚠️ 为什么会乱：量具表 `截意志学习页.gd` 的 件路径 登记了「导师1气泡」（那条门要断言
#   它**初值隐藏**）⇒ 上面第一个循环提前登记它，而 `加()` 的去重不会纠正位置 ⇒ 场景里
#   导师_1 的气泡排在自己头像**之前**，画在人物后面（还被 2/3/4 号头像盖住一截）。
#   只挪这一个节点治标不治本——这里按 canonical 顺序把 5 个格的子件整块重排：
#   每格「头像→悬停框→召唤→召唤文字→气泡」连成整块、气泡固定在每格末尾，
#   从此子件顺序与"谁先在量具表里登记"无关。
导师子件序 = {"头像": 0, "悬停框": 1, "召唤": 2, "召唤/召唤文字": 3, "气泡": 4}
导师前缀 = 根 + "/导师面板/导师容器/导师_"


def 导师子件键(路):
    if not 路.startswith(导师前缀):
        return None
    格, _, 子 = 路[len(导师前缀):].partition("/")
    if not 格.isdigit() or 子 not in 导师子件序:
        return None
    return (int(格), 导师子件序[子])


导师位 = [i for i, 路 in enumerate(顺序) if 导师子件键(路) is not None]
if 导师位:
    首, 末 = 导师位[0], 导师位[-1]
    位集 = set(导师位)
    块 = sorted([路 for i, 路 in enumerate(顺序) if i in 位集], key=导师子件键)
    顺序 = 顺序[:首] + 块 \
        + [路 for i, 路 in enumerate(顺序) if 首 < i < 末 and i not in 位集] \
        + 顺序[末 + 1:]
    print("导师子件已按 canonical 顺序归位：%d 个（每格 头像→悬停框→召唤→召唤文字→气泡）" % len(块))

注释 = [
    '; ── 意志学习（原版 `com/mxw/uifl/controls/yiZhi/YiZhiStudyWindow.as`，772×564，整窗 1:1 移植）──',
    '; 本文件由 `开发工具/生成意志学习场景.py` 从量具表 `截意志学习页.gd` 的 件路径/件期望 生成。',
    '; **改真值改量具表再重跑生成器，别手改本文件。** 逐件算式与出处见 `game-client/真值/窗口/意志学习.md`；',
    '; 场景 y = AS3 窗口局部 y − 29（`窗口尺寸.json` 的「意志学习」标 `整框: true` ⇒ 容器原点 (0,29)）。',
    '; 主美术来自运行期包 `swf/UISwf/UISwf_yizhi.swf`；四枚大钮皮来自 `UISwf_Text.swf`（前缀见 BaseUtil.getLocalPath）。']
头 = ["[gd_scene load_steps=%d format=3]" % (1 + len(图) + 2), NL.join(注释)]
for k, (p, _) in 图.items():
    头.append('[ext_resource type="Texture2D" path="res://素材/界面/%s" id="%s"]' % (p, 扩展id[k]))
头.append('')


def 箱(编号, 键):
    p, 边 = 图[键]
    return (('[sub_resource type="StyleBoxTexture" id="sb_%s"]' + NL
             + 'texture = ExtResource("%s")' + NL
             + 'texture_margin_left = %s' + NL + 'texture_margin_top = %s' + NL
             + 'texture_margin_right = %s' + NL + 'texture_margin_bottom = %s' + NL
             + 'content_margin_left = 0.0' + NL + 'content_margin_right = 0.0' + NL
             + 'content_margin_top = 0.0' + NL + 'content_margin_bottom = 0.0' + NL + NL)
            % ((编号, 扩展id[键]) + tuple(边)))


体 = [箱("yellow", "黄底")]
# 气泡 = 原版 `UISwf_yizhi_PaoPao` 的 29 帧里 3 个不同画面（帧 1 / 10 / 20，实测差 33、41 像素）
# ⇒ 三点依次点亮的省略号动画。原版 24fps、每态约 9 帧 ⇒ 每态持续 0.375s（`frameRate="24.0"`）。
# ⚠️ Godot 4.7 的 AnimatedTexture **没有 `fps`、也没有 `loop`**（帧号按 frames 取模 = 天然循环），
#    每帧时长靠 `frame_N/duration`（单位**秒**，默认 1.0 ⇒ 写错就等于不动）。
体.append("[sub_resource type=" + chr(34) + "AnimatedTexture" + chr(34) + " id=" + chr(34) + "anim_paopao" + chr(34) + "]" + chr(10)
         + "frames = 3" + chr(10)
         + "frame_0/texture = ExtResource(" + chr(34) + 扩展id["气泡1"] + chr(34) + ")" + chr(10)
         + "frame_0/duration = 0.375" + chr(10)
         + "frame_1/texture = ExtResource(" + chr(34) + 扩展id["气泡2"] + chr(34) + ")" + chr(10)
         + "frame_1/duration = 0.375" + chr(10)
         + "frame_2/texture = ExtResource(" + chr(34) + 扩展id["气泡3"] + chr(34) + ")" + chr(10)
         + "frame_2/duration = 0.375" + chr(10) + chr(10))
## 四枚大钮已改 TextureButton（皮 = texture_normal，三态由控制器换图），不再发 StyleBoxTexture。
## `钮皮` 只留作「件名 → 皮键」的对照表，供注释与排查用。

模板 = ('[node name="%s" type="%s"%s]' + NL + '%s%s' + NL
        + 'layout_mode = 0' + NL + 'offset_left = %s' + NL + 'offset_top = %s' + NL
        + 'offset_right = %s' + NL + 'offset_bottom = %s' + NL)
行 = []
for 路 in 顺序:
    信息 = 节点[路]
    if 路 != 根 and not 路.startswith(根 + "/"):
        print("!! 键没带根前缀:", repr(路)); sys.exit(1)
    名 = 路.rsplit("/", 1)[-1]
    父 = 信息["父"]
    x, y, w, h = 信息["矩"]
    基 = [0.0, 0.0]
    if 父:
        父矩 = 节点.get(父, {}).get("矩")
        if 父矩:
            基 = [父矩[0], 父矩[1]]
    if 路 == 根:
        类型, 附加, 隐 = "Control", "custom_minimum_size = Vector2(772, 535)" + NL, False
    else:
        相 = 路[len(根) + 1:]
        if not 相:                      # 被当作中间父节点补登的根占位，跳过（真根在上一分支处理）
            continue
        型 = 路径规格.get(相)
        if 型 is None:
            print("!! 路径规格缺:", 相)
            sys.exit(1)
        类型, 键, 附, 隐 = 型
        附 = 附 or ""
        if 键:
            资 = 'SubResource("anim_paopao")' if 键 == "气泡动图" else 'ExtResource("%s")' % 扩展id[键]
            if 类型 == "Panel":
                # Panel 没有 `texture` 属性 —— 写上去 Godot 直接丢掉，于是运行期落到全局主题的
                # 默认 Panel 皮（`原版主题.tres` 里 texture_margin 8/7/7/7），九宫格边距全错。
                # 必须走 `theme_override_styles/panel`，边距才认 §13 的 MYellow 11/10/10/11。
                附 = ('theme_override_styles/panel = SubResource("sb_%s")' % 面板皮[键] + NL + 附)
            elif 类型 == "TextureButton":
                # TextureButton 的皮属性是 `texture_normal`，也没有 `expand_mode`（那是 TextureRect 的）。
                附 = ('texture_normal = %s' % 资 + NL + 附)
            else:
                附 = ('texture = %s' % 资 + NL + "expand_mode = 1" + NL + 附)
        附加 = 附
    头注 = '' if 路 == 根 else ' parent="%s"' % (父[len(根) + 1:] if 父.startswith(根 + "/") else ".")
    行.append(模板 % (名, 类型, 头注, ("visible = false" + NL if 隐 else ""), 附加,
                      x - 基[0], y - 基[1], x - 基[0] + w, y - 基[1] + h))

open(出, "w", encoding="utf-8", newline=NL).write(NL.join(头) + "".join(体) + NL.join(行))
print("生成 %s：%d 个节点" % (os.path.relpath(出, 工程), len(顺序)))
