# -*- coding: utf-8 -*-
"""组队页（原版 TroopWindow2 + MyTroopPane + NearTroopsPane + NearCharsPane）生成器。

一份表同时产出
  ① 场景  `场景/界面/窗口/组队/队伍窗.tscn`
  ② 几何门期望  `数据/界面/队伍页期望.json`
（**场景与期望同源**：抄第二份必然对错，家族那轮就栽在 x 抄错。）

真值 = `真值/窗口/组队.md` §①②③④⑥⑦，每条坐标后面注 AS3 行号。
坐标系 = **窗口局部坐标 − (0, 29)**（`数据/界面/窗口尺寸.json` 的「组队」必须 `整框: true`，
宿把内容区摆在 (0,29)）。`_contentBg.y = 38` 是窗口局部 ⇒ 页里写 9。

九宫格边距**现场解析** `MainLib.xml` 的 `DefineScalingGridTag`（按属性名取 splitter，
再按本体 `shapeBounds` 算四边距），不在工具里抄第二份边距表；解析完自检「无负数、不超本体尺寸」。

用法：
    python 开发工具/生成队伍场景.py            # 写盘
    python 开发工具/生成队伍场景.py --扫       # 干跑，只打印统计与自检结果
跑完必须 `Godot --path . --headless --import`，再跑 测试/队伍页回归测试.gd。
⚠ 生成器只在**开新页/推翻重做**时跑；之后手改场景就别再跑它（会把手拖的覆盖掉）。
"""
import io
import json
import math
import os
import re
import sys

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
场景目录 = os.path.join(工程, "场景", "界面", "窗口", "组队")
期望目录 = os.path.join(工程, "数据", "界面")
XML = r"2.2.3/logs/swfprobe/MainLib.xml"
通用皮 = "res://素材/界面/原版窗口/通用控件/%s.png"

拖动区 = 29			# MWindow 标题拖动区：页局部 y = 窗口局部 y − 29

# ── 元件 → 素材主干（天然尺寸写注释里，全部现查 MainLib/ffdec）──────────
元件 = {
    "内容背景": (通用皮 % "内容面板", "MYellow_background(10) 天然 263x252"),
    "底板": (通用皮 % "子面板", "MPane_background(97) 天然 253x212"),
    "选中底": (通用皮 % "选中条1", "MSelected_background1(705) 天然 189x19"),
    "头像盒": (通用皮 % "物品格", "MGrid_background(172) 天然 40x40"),
    "横分隔": (通用皮 % "横向分隔线", "LineHPicF(133) 天然 252x2，**普通 Sprite ⇒ 整帧非等比**"),
    "斑马条": (通用皮 % "列表分隔", "ListSeparator_background(779) 天然 304x24"),
    "竖分隔": (通用皮 % "竖向分隔线", "TableSeparatorLineF(593) 天然 2x20"),
    "分页首": (通用皮 % "首页", "MPageFirstBtnF(992) 18x13"),
    "分页上": (通用皮 % "上一页", "MPagePreBtnF(856) 15x13"),
    "分页下": (通用皮 % "下一页", "MPageNextBtnF(855) 15x13"),
    "分页末": (通用皮 % "末页", "MPageEndBtnF(991) 18x13"),
    "折叠钮": (通用皮 % "减少按钮", "BranchButton(660) 18x18（upSkin/selectedUpSkin 两张真皮）"),
    "血条底": (通用皮 % "血条底", "MBar 的 barBg"),
    "血条填充": (通用皮 % "血条填充", "MBar 的 bar"),
    "蓝条底": (通用皮 % "经验条槽", "MBar 蓝档槽"),
    "蓝条填充": (通用皮 % "经验条填充", "MBar 蓝档填充"),
    "标题底": (通用皮 % "窗口内底", "TroopHPPaneTitleSkinF(803) 天然 164x22"),
}
搜索钮 = (通用皮 % "小标右", "TroopWindowSearchBtn(1154) 天然 22x22（upSkin #1153）")

# ── 文案：只认原版语言表，缺键直接炸，不许自造 ────────────────────────
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据  # noqa: E402

语言 = {}
for 包 in ("core", "ui", "message"):
    for k, v in 原版数据.读语言表(包).items():
        if isinstance(v, str):
            语言.setdefault(k, v)


def 文(键):
    if 键 not in 语言:
        raise SystemExit("语言表缺键，别自造文案：" + 键)
    return 语言[键]


# ── 九宫格边距：现场解析 MainLib ────────────────────────────────────
_全文 = None


def 全文():
    global _全文
    if _全文 is None:
        with io.open(XML, encoding="utf-8", errors="replace") as f:
            _全文 = f.read()
    return _全文


def png尺(路径):
    """直接读 PNG 的 IHDR（宽/高），不依赖 PIL。"""
    with open(路径, "rb") as f:
        头 = f.read(24)
    if len(头) < 24 or 头[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    宽 = int.from_bytes(头[16:20], "big")
    高 = int.from_bytes(头[20:24], "big")
    return (float(宽), float(高))


def _头(编号):
    文本 = 全文()
    return re.search(r'<item type="Define(\w+)Tag"[^>]*?(?:spriteId|shapeId|buttonId)="(%d)"' % 编号, 文本)


def 本体盒(编号, 深=0):
    """characterId → (宽, 高) 像素。
    ⚠ DefineSpriteTag **没有自己的 shapeBounds**：直接往后找会抓到**下一条 tag** 的盒
      （实测把 MYellow_background 解成 100x100、边距算出负数）。
      ⇒ 是 Sprite 就递归并它的子件盒；是 Shape 才读自己那一行 shapeBounds。"""
    m = _头(编号)
    if not m:
        return None
    类 = m.group(1)
    文本 = 全文()
    起 = m.end()
    止 = 文本.find('<item type="Define', 起)
    段 = 文本[起:止 if 止 != -1 else 起 + 6000]
    if 类 != "Sprite":
        行 = re.search(r"<shapeBounds\b[^>]*/?>", 段)
        if not 行:
            return None
        取 = lambda 名: float(re.search(r'\b%s="([-\d.]+)"' % 名, 行.group(0)).group(1)) / 20.0
        return (取("Xmax") - 取("Xmin"), 取("Ymax") - 取("Ymin"), 取("Xmin"), 取("Ymin"))
    if 深 > 3:
        return None
    并 = None
    for 块 in re.finditer(r'<item type="PlaceObject2\w*"[^>]*>', 段):
        cid = re.search(r'characterId="(-?\d+)"', 块.group(0))
        if not cid:
            continue
        子 = 本体盒(int(cid.group(1)), 深 + 1)
        if 子 is None:
            continue
        矩 = re.search(r'<matrix[^>]*translateX="([-\d.]+)"[^>]*translateY="([-\d.]+)"', 段[块.end():块.end() + 700])
        dx = float(矩.group(1)) / 20.0 if 矩 else 0.0
        dy = float(矩.group(2)) / 20.0 if 矩 else 0.0
        盒 = (子[2] + dx, 子[3] + dy, 子[0], 子[1])
        if 并 is None:
            并 = [盒[0], 盒[1], 盒[0] + 盒[2], 盒[1] + 盒[3]]
        else:
            并 = [min(并[0], 盒[0]), min(并[1], 盒[1]), max(并[2], 盒[0] + 盒[2]), max(并[3], 盒[1] + 盒[3])]
    if 并 is None:
        return None
    return (并[2] - 并[0], 并[3] - 并[1], 并[0], 并[1])


def 边距(编号, 素材=None):
    """[左, 上, 右, 下]（像素）。查无 DefineScalingGridTag ⇒ 全 0（整拉，与原版一致）。
    给了素材就顺手校一件事：**MainLib 解出的天然尺寸必须等于那张 PNG 的实际像素**，
    不相等说明本体盒抓错了层。"""
    文本 = 全文()
    m = re.search(r'<item type="DefineScalingGridTag"[^>]*characterId="%d"[^>]*>' % 编号, 文本)
    尺 = 本体盒(编号)
    if 尺 is None:
        raise SystemExit("元件 %d 解不出本体尺寸" % 编号)
    宽, 高 = 尺[0], 尺[1]
    if 素材:
        盘 = png尺(os.path.join(工程, 素材.replace("res://", "").replace("/", os.sep)))
        if 盘 and (abs(盘[0] - 宽) > 0.51 or abs(盘[1] - 高) > 0.51):
            raise SystemExit("元件 %d：MainLib 解出 %s，盘上的图是 %s ⇒ 本体盒抓错层" % (编号, (宽, 高), 盘))
    if not m:
        return [0.0, 0.0, 0.0, 0.0]
    行 = re.search(r"<splitter\b[^>]*/?>", 文本[m.end():m.end() + 900])
    if not 行:
        raise SystemExit("元件 %d 有 ScalingGrid 头却没有 splitter" % 编号)
    取 = lambda 名: float(re.search(r'\b%s="([-\d.]+)"' % 名, 行.group(0)).group(1)) / 20.0
    出 = [取("Xmin") - 尺[2], 取("Ymin") - 尺[3], 尺[2] + 宽 - 取("Xmax"), 尺[3] + 高 - 取("Ymax")]
    for i, 值 in enumerate(出):
        if 值 < -0.001:
            raise SystemExit("元件 %d 边距算出负数 %r" % (编号, 出))
        if 值 > (宽 if i in (0, 2) else 高):
            raise SystemExit("元件 %d 边距超过本体尺寸 %r" % (编号, 出))
    return [round(值, 2) for 值 in 出]


# 阳性对照：MYellow_background(10) 已知 = [11, 10, 10, 11]（皮肤表与 §13 都这么记）
元件号 = {"内容背景": 10, "底板": 97, "选中底": 705, "头像盒": 172}
对照 = 边距(10, 元件["内容背景"][0])
if [round(值) for 值 in 对照] != [11, 10, 10, 11]:
    raise SystemExit("九宫格解析的阳性对照没过：MYellow_background 解成 %r，期望 [11,10,10,11]" % 对照)

九宫 = {名: 边距(号, 元件[名][0]) for 名, 号 in 元件号.items()}

# ── 窗口/页几何（真值 §①）─────────────────────────────────────────
窗宽, 窗高 = 515, 432			# TroopWindow2.as:47 super(515,432,false)
内容底 = [8, 38 - 拖动区]		# :111-114  x=CONTENT_GAP(8)、y=38 字面量
内容尺 = [窗宽 - 16, 窗高 - 38 - 8]	# drawWindowLayout:144-152
页签位 = [8 + 3 + 5, 38 - 拖动区 + 5]	# :118-119  x=8+3+BORDER_GAP(5)=16、y=38+5=43
页签宽, 页签高 = 61, 22			# buttonSize=[btn_width_four]=61；MTabButtonF 天然 39x22
内容区位 = [8 + 5, 43 - 拖动区 + 20]	# :124-125  x=13、y=63
页宽, 页高 = 489, 356			# dolayout:397-403 ⇒ 宽=489+26、高=356+63+13
钮宽, 钮高 = 61, 22			# MButtonF 天然 57x22，宽被设成 btn_width_four=61

# ── 色（UIConfig 十进制字面量）────────────────────────────────────
色橙 = "#ff9100"			# UI_ORANGE 16748800
色白 = "#ffffff"			# UI_WHITE 16777215
色绿 = "#00ff00"			# UI_GREEN 65280
色蓝 = "#1e90ff"			# UI_BLUE 2003199

成员格位 = [(3, 24), (245, 24), (3, 89), (245, 89), (3, 154), (245, 154)]	# MyTroopPane:183-188
成员格尺 = (241, 64)							# MyTroopPaneCell:82-83


def 表头列(起点, 列):
    """`createListLable`（:235-253 / :257-275）：label 在 (x, y−2) 高 20，线在 (x+宽, y)。
    列 = [(键, 宽, 画不画线)]，返回 (标签们, 竖线们, 下一列)。"""
    标签, 线 = [], []
    x, y = 起点
    for 键, 宽, 画线 in 列:
        标签.append((文(键), x, y - 2, 宽, 20, 色白, "center"))
        if 画线:
            线.append((x + 宽, y, 2, 20))
        x += 宽 + 2
    return 标签, 线


# ══════════════════════ 页内容：逐件（名, 类型, x, y, 宽, 高, 附加） ══════════════════════
件 = []		# (父, 名, 类型, x, y, 宽, 高, props)
期望 = {"窗口": {"宽": 窗宽, "高": 窗高, "as3": "TroopWindow2",
		 "标题": 文("TROOP_TITLE"), "自算": "宽=页宽+26=%d；高=页高+63+13=%d" % (页宽 + 26, 页高 + 63 + 13)},
	"件": [], "元件边距": 九宫, "元件天然尺寸": {}}


短 = {}		# 名 → 最后登记的全路径（写表时父节点允许用短名，如 成员格3 / 左皮）
所有路径 = {}		# 名 → 全部同名的全路径，用于最后那道「被当父用的名字必须唯一」的自检
当过父 = set()


def 记(父, 名, 类型, x, y, 宽, 高, **附加):
    原始 = 父
    if 父 != "." and 父 in 短:
        父 = 短[父]
        当过父.add(原始)
    全 = 名 if 父 == "." else "%s/%s" % (父, 名)
    短[名] = 全
    所有路径.setdefault(名, []).append(全)
    件.append((父, 名, 类型, x, y, 宽, 高, 附加))
    期望["件"].append({"路径": 全, "类型": 类型, "x": x, "y": y, "宽": 宽, "高": 高,
		       "隐藏": bool(附加.get("隐")), "文本": 附加.get("文本"),
		       "页序": 附加.get("页序"), "格序": 附加.get("格序"), "行序": 附加.get("行序")})


def 标签(父, 名, 文本, x, y, 宽, 高=18, 色=色白, 对齐="left", **附加):
    附加.update({"文本": 文本, "色": 色, "对齐": 对齐})
    记(父, 名, "Label", x, y, 宽, 高, **附加)


def 钮(父, 名, 文本, x, y, 宽=钮宽, 高=钮高, **附加):
    附加.update({"文本": 文本})
    记(父, 名, "Button", x, y, 宽, 高, **附加)


def 皮(父, 名, 主干, x, y, 宽, 高, 格子=True, **附加):
    附加["皮"] = 主干
    记(父, 名, "NinePatchRect" if 格子 else "TextureRect", x, y, 宽, 高, **附加)


# ───────────────────────── 外壳 ─────────────────────────
皮(".", "内容背景", "内容背景", 内容底[0], 内容底[1], 内容尺[0], 内容尺[1])
记(".", "分页", "Control", 页签位[0], 页签位[1], 页签宽 * 5, 页签高)
页签键 = ["TROOP_TAB_BTN_MY_TROOP", "TROOP_TAB_BTN_NEAR_TROOPS", "TROOP_TAB_BTN_NEARCHARS",
	  "TROOP_WINDOW_WODE_PEIOU", "TROOP_TAB_BTN_MARRY_LIST"]
for i, 键 in enumerate(页签键):
    记("分页", 文(键), "Button", i * 页签宽, 0, 页签宽, 页签高, 文本=文(键), 页序=i)
记(".", "内容区", "Control", 内容区位[0], 内容区位[1], 页宽, 页高)

# ───────────────────── 第一页：我的队伍 ─────────────────────
# MyTroopPane.as:171-224
记("内容区", "我的队伍", "Control", 0, 0, 页宽, 页高)
一 = "内容区/我的队伍"
皮(一, "底板", "底板", 0, 0, 489, 326)					# :173-176
标签(一, "提示", 文("TROOP_TIP_MORE_MEMBER_MORE_EXP"), 5, 3, 479, 18, 色蓝)	# :177-182

for i, (x, y) in enumerate(成员格位, 1):
    格 = "%s/成员格%d" % (一, i)
    记(一, "成员格%d" % i, "Button", x, y, *成员格尺, 透明钮=True, 格序=i - 1)
    皮("成员格%d" % i, "底", "底板", 0, 0, 241, 64)			# Cell:81-84
    皮("成员格%d" % i, "悬停底", "选中底", 0, 0, 241, 64, 隐=True)		# :85-88
    皮("成员格%d" % i, "选中底", "选中底", 0, 0, 241, 64, 隐=True)		# :89-92
    皮("成员格%d" % i, "头像盒", "头像盒", 5, 5, 54, 54)			# :93-96
    记("%s/成员格%d/头像盒" % (一, i), "头像", "TextureRect", 2, 2, 49, 49)		# :155-161 (54-49)>>1
    标签("成员格%d" % i, "名字", "", 60, 6, 140, 16, 色橙)			# :97-102
    标签("成员格%d" % i, "等级", "", 60, 22, 175, 16, 色白)			# :103-108
    标签("成员格%d" % i, "地图", "", 60, 38, 175, 16, 色白)			# :109-114
    标签("成员格%d" % i, "队长", "", 60, 6, 175, 16, 色绿, "right")		# :115-121（与名字同位）

for i, 键 in enumerate(["TROOP_OPTION1", "TROOP_OPTION2", "TROOP_OPTION3"], 1):
    记(一, "勾选%d" % i, "CheckBox", 8, 221 + (i - 1) * 24, 470, 19, 文本=文(键))	# :189-204
标签(一, "宣言标签", 文("TROOP_MANIFESTO"), 8, 298, 65, 16, 色橙)			# :205-210
记(一, "宣言输入", "LineEdit", 68, 297, 353, 22, 最长=9)					# :211-216
钮(一, "修改宣言钮", 文("TROOP_SAVE_MANIFESTO_BTN"), 422, 297)				# :217
钮(一, "自我退队", 文("TROOP_QUIT_BUTTON"), 34, 333)						# :219
钮(一, "添加成员", 文("TROOP_ADD_BTN"), 121, 333)						# :220
钮(一, "自建队伍", 文("TROOP_CREATE_BUTTON"), 208, 333)						# :218
钮(一, "任命队长", 文("TROOP_CHANGE_LEADER_BTN"), 208, 333, 隐=True)					# :221（与自建同位）
钮(一, "请离队伍", 文("TROOP_KICK_BTN"), 295, 333)						# :222
钮(一, "查看资料", 文("TROOP_SHOW_CHAR_INFO_BTN"), 382, 333)						# :223

# ───────────────────── 第二页：附近队伍 ─────────────────────
# NearTroopsPane.as:140-185
记("内容区", "附近队伍", "Control", 0, 0, 页宽, 页高, 隐=True)
二 = "内容区/附近队伍"
皮(二, "底板", "底板", 0, 0, 489, 326)						# :142-145
for 名, x, 宽, 行数 in (("左皮", 3, 297, 11), ("右皮", 301, 185, 6)):
    记(二, 名, "Control", x, 26, 宽, 269)					# :146-153
    皮(名, "底", "底板", 0, 0, 宽, 269)
    皮(名, "顶线", "横分隔", 3, 25, 宽 - 6, 2, 格子=False)				# CommonListSkin2:22-26
    for k in range(行数 // 2):
        皮(名, "斑马%d" % (k + 1), "斑马条", 3, 47 + k * 44, 宽 - 6, 24)		# :27-33
标签(二, "左表题", 文("UI_60"), 94, 8, 102, 16)					# :97-100
标签(二, "右表题", 文("UI_39"), 370, 8, 56, 16)					# :101-104
左列, 左线 = 表头列((6, 32), [(("TROOP_MANIFESTO"), 130, True),
			       (("TROOP_NEAR_LEADER_LABEL"), 80, True),
			       (("CHARACTOR_LEVEL"), 40, True),
			       (("TROOP_NEAR_MEMBER_COUNT_LABEL"), 40, False)])
右列, 右线 = 表头列((301, 32), [(("TROOP_NEAR_MEMBER_NAME"), 80, True),
				 (("CHARACTOR_LEVEL"), 40, True),
				 (("CHARACTOR_JOB"), 65, False)])
for i, (t, x, y, 宽, 高, 色, 对齐) in enumerate(左列 + 右列, 1):
    标签(二, "表头%d" % i, t, x, y, 宽, 高, 色, 对齐)
for i, (x, y, 宽, 高) in enumerate(左线 + 右线, 1):
    皮(二, "表头线%d" % i, "竖分隔", x, y, 宽, 高, 格子=False)
队列 = [("宣言", 5, 122), ("队长", 130, 80), ("等级", 210, 40), ("人数", 250, 40)]
员列 = [("名称", 5, 80), ("等级", 85, 40), ("职业", 125, 65)]
for i in range(11):							# troopList :111-121
    记(二, "队伍行%d" % (i + 1), "Button", 5, 53 + i * 22, 293, 22, 透明钮=True, 行序=i)
    for 名, x, 宽 in 队列:
        标签("队伍行%d" % (i + 1), 名, "", x, 0, 宽, 20, 色白, "left" if 名 in ("宣言", "队长") else "center")
    皮("队伍行%d" % (i + 1), "选中底", "选中底", 0, 0, 293, 22, 隐=True)
for i in range(6):							# memberList :122-131
    记(二, "成员行%d" % (i + 1), "Control", 303, 53 + i * 22, 181, 22)
    for 名, x, 宽 in 员列:
        标签("成员行%d" % (i + 1), 名, "", x, 0, 宽, 20, 色白)
分页条宽 = 124							# 首页18 + 上一页15 + 下一页15 + 末页18 + 输入框
记(二, "分页条", "Control", 3 + ((297 - 分页条宽) >> 1), 26 + 269 + 3, 分页条宽, 18)	# :222-233
for i, (名, 键, 宽) in enumerate([("首", "分页首", 18), ("上", "分页上", 15),
				  ("下", "分页下", 15), ("末", "分页末", 18)]):
    x = [0, 18, 61, 76][i]
    皮("分页条", "钮" + 名, 键, x, 0, 宽, 13, 格子=False)
    记("分页条", "位" + 名, "Control", x, 0, 宽, 13)
钮(二, "刷新列表钮", 文("TROOP_NEAR_REFRESH_BTN"), 110, 333)				# :175-179
钮(二, "申请入队钮", 文("TROOP_NEAR_APPLY_BTN"), 352, 333)					# :180-184

# ───────────────────── 第三页：附近玩家 ─────────────────────
# NearCharsPane.as:74-129
记("内容区", "附近玩家", "Control", 0, 0, 页宽, 页高, 隐=True)
三 = "内容区/附近玩家"
皮(三, "底板", "底板", 0, 0, 489, 326)
记(三, "皮", "Control", 3, 30, 483, 269)							# :80-83
皮("皮", "底", "底板", 0, 0, 483, 269)
皮("皮", "顶线", "横分隔", 3, 25, 477, 2, 格子=False)
for k in range(5):
    皮("皮", "斑马%d" % (k + 1), "斑马条", 3, 47 + k * 44, 477, 24)
标签(三, "搜索标签", 文("TROOP_SEARCH_LABEL"), 6, 6, 254, 16, 色白, "right")			# :84-89
记(三, "关键词", "LineEdit", 260, 6, 148, 22, 最长=20)						# :90-94
记(三, "搜索钮", "Button", 408, 6, 22, 22, 图标="搜索钮")					# :95-98 TroopWindowSearchBtn（Sprite + buttonMode）
玩列, 玩线 = 表头列((10, 35), [(("CHARACTOR_NAME"), 110, True), (("CHARACTOR_LEVEL"), 40, True),
			       (("CHARACTOR_JOB"), 100, True), (("CHARACTOR_FAMILY"), 110, True),
			       (("CHARACTOR_TITLE_NAME"), 110, False)])
for i, (t, x, y, 宽, 高, 色, 对齐) in enumerate(玩列, 1):
    标签(三, "表头%d" % i, t, x, y, 宽, 高, 色, 对齐)
for i, (x, y, 宽, 高) in enumerate(玩线, 1):
    皮(三, "表头线%d" % i, "竖分隔", x, y, 宽, 高, 格子=False)
玩内 = [("名字", 0, 115), ("等级", 115, 40), ("职业", 155, 100), ("家族", 255, 110), ("称号", 365, 110)]
for i in range(11):							# charsList :188-198
    记(三, "玩家行%d" % (i + 1), "Button", 5, 57 + i * 22, 479, 21, 透明钮=True, 行序=i)
    for 名, x, 宽 in 玩内:
        标签("玩家行%d" % (i + 1), 名, "", x, 0, 宽, 20, 色白)
    皮("玩家行%d" % (i + 1), "选中底", "选中底", 0, 0, 479, 21, 隐=True)
钮(三, "刷新列表钮", 文("TROOP_NEAR_REFRESH_BTN"), 8, 333)					# :114-118
钮(三, "查看资料钮", 文("TROOP_SHOW_CHAR_INFO_BTN"), 321, 333)					# :119-123
钮(三, "邀请组队钮", 文("TROOP_INVITE_BUTTON"), 408, 333)					# :124-128

# ───────────────── 第四、五页：我的羁绊 / 酒宴列表 ─────────────────
# TroopWindow2:174-178 / :350-358 —— 内容属 羁绊 族（#263），这里只留原版那两个空壳页根。
记("内容区", "我的羁绊", "Control", 0, 0, 页宽, 页高, 隐=True)
记("内容区", "酒宴列表", "Control", 0, 0, 页宽, 页高, 隐=True)

期望["元件天然尺寸"] = {名: (round(本体盒(号)[0], 2), round(本体盒(号)[1], 2)) for 名, 号 in 元件号.items()}
期望["页签"] = [文(键) for 键 in 页签键]
期望["成员格位"] = 成员格位
期望["钮位"] = {"自我退队": (34, 333), "添加成员": (121, 333), "自建队伍": (208, 333),
		 "任命队长": (208, 333), "请离队伍": (295, 333), "查看资料": (382, 333),
		 "修改宣言钮": (422, 297)}
期望["勾选"] = [(8, 221), (8, 245), (8, 269)]
期望["文案"] = {"标题": 文("TROOP_TITLE"), "提示": 文("TROOP_TIP_MORE_MEMBER_MORE_EXP"),
		 "宣言": 文("TROOP_MANIFESTO"), "等级前缀": 文("CHARACTOR_LEVEL"),
		 "队长": 文("TROOP_NEAR_LEADER_LABEL"), "自建": 文("TROOP_CREATE_BUTTON"),
		 "退队": 文("TROOP_QUIT_BUTTON"), "添加": 文("TROOP_ADD_BTN"),
		 "任命": 文("TROOP_CHANGE_LEADER_BTN"), "请离": 文("TROOP_KICK_BTN"),
		 "查看资料": 文("TROOP_SHOW_CHAR_INFO_BTN"), "修改宣言": 文("TROOP_SAVE_MANIFESTO_BTN"),
		 "刷新": 文("TROOP_NEAR_REFRESH_BTN"), "申请入队": 文("TROOP_NEAR_APPLY_BTN"),
		 "邀请组队": 文("TROOP_INVITE_BUTTON")}

# ══════════════════════ 写 .tscn ══════════════════════
对齐号 = {"left": 0, "center": 1, "right": 2}


def 主干路径(名):
    """件上写的是**元件类名**（内容背景/底板/…），这里解成 res:// 素材路径。
    查不到就炸：素材名打错 = 页面白一块，宁可现在红。"""
    if 名 == "搜索钮":
        return 搜索钮[0]
    if 名 not in 元件:
        raise SystemExit("元件名没登记进 元件 表：" + 名)
    return 元件[名][0]


def 收集纹理():
    序, 表 = [], {}
    for _, _, _, _, _, _, _, 附加 in 件:
        主干 = 附加.get("皮") or 附加.get("图标")
        if 主干:
            路径 = 主干路径(主干)
            if 路径 not in 表:
                序.append(路径)
                表[路径] = "t%d" % len(序)
    return 序, 表


def 出场景(序, 表):
    行 = ["[gd_scene load_steps=%d format=3]" % (len(序) + 1), ""]
    for 路径 in 序:
        盘 = os.path.join(工程, 路径.replace("res://", "").replace("/", os.sep))
        if not os.path.exists(盘):
            raise SystemExit("素材不在盘上：" + 路径)
        行.append('[ext_resource type="Texture2D" path="%s" id="%s"]' % (路径, 表[路径]))
    行.append("")
    行.append('[node name="原版组队窗口内容" type="Control"]')
    行.append("custom_minimum_size = Vector2(%d, %d)" % (窗宽, 窗高 - 拖动区))
    行.append("offset_right = %d" % 窗宽)
    行.append("offset_bottom = %d" % (窗高 - 拖动区))
    行.append("mouse_filter = 2")
    行.append("; 整框：页局部 y = 窗口局部 y − 29（宿把内容区摆在 (0,29)）。逐件出处 = 真值/窗口/组队.md §①")
    父尺 = {}
    for 父, 名, 类型, x, y, 宽, 高, 附加 in 件:
        路径 = 名 if 父 == "." else "%s/%s" % (父, 名)
        行.append('[node name="%s" type="%s" parent="%s"]' % (名, 类型, "." if 父 == "." else 父))
        if 类型 in ("Label", "RichTextLabel"):
            行.append("layout_mode = 0")
            行.append("offset_left = %g" % x); 行.append("offset_top = %g" % y)
            行.append("offset_right = %g" % (x + 宽)); 行.append("offset_bottom = %g" % (y + 高))
            行.append('text = "%s"' % 附加.get("文本", ""))
            if 附加.get("色"):
                行.append('theme_override_colors/font_color = Color%s' % 十六到四(附加["色"]))
            if 附加.get("对齐"):
                行.append("horizontal_alignment = %d" % 对齐号[附加["对齐"]])
        else:
            行.append("layout_mode = 0")
            行.append("offset_left = %g" % x); 行.append("offset_top = %g" % y)
            行.append("offset_right = %g" % (x + 宽)); 行.append("offset_bottom = %g" % (y + 高))
            if 类型 == "NinePatchRect":
                主干 = 附加["皮"]
                行.append('texture = ExtResource("%s")' % 表[主干路径(主干)])
                边 = 九宫.get(主干, [0, 0, 0, 0])
                # ⚠ `NinePatchRect.patch_margin_*` 是 **int** 属性：现场解析出来的边距是 twip÷20，
                # 常常带小数（实测 7.5 / 5.75 / 7.9…）。写进 .tscn 时 Godot 不报错但**向下截断**
                # ⇒ 端帽比真值窄 1px（`场景资源回归测试` 因此报 156 项"边距不是整数"）。
                # 一律四舍五入（不是 floor、不是抄第二份表）—— 解析仍是唯一事实源。
                取整 = [int(math.floor(float(v) + 0.5)) for v in 边]
                行.append("patch_margin_left = %d" % 取整[0]); 行.append("patch_margin_top = %d" % 取整[1])
                行.append("patch_margin_right = %d" % 取整[2]); 行.append("patch_margin_bottom = %d" % 取整[3])
                行.append("mouse_filter = 2")
            elif 类型 == "TextureRect":
                主干 = 附加.get("皮")
                if 主干:
                    行.append('texture = ExtResource("%s")' % 表[主干路径(主干)])
                    行.append("stretch_mode = 0" if 主干 in ("横分隔", "竖分隔") else "stretch_mode = 1")
                else:
                    行.append("expand_mode = 1")	# 运行期由控制器贴（头像 / 血蓝填充）
                行.append("mouse_filter = 2")
            elif 类型 == "Button":
                if 附加.get("透明钮"):
                    行.append("theme_type_variation = &\"OrigBlankButton\"")
                if 附加.get("图标"):
                    行.append("theme_type_variation = &\"OrigBlankButton\"")
                    行.append('icon = ExtResource("%s")' % 表[主干路径(附加["图标"])])
                elif 附加.get("页序") is not None:
                    行.append("theme_type_variation = &\"OrigTab\"")
                    行.append("toggle_mode = true")
                行.append("focus_mode = 0")
                行.append('text = "%s"' % 附加.get("文本", ""))
                if 附加.get("文本") is None:
                    行.append('text = ""')
            elif 类型 == "CheckBox":
                行.append('text = "%s"' % 附加.get("文本", ""))
                行.append("theme_override_colors/font_color = Color(1, 1, 1, 1)")
                行.append("theme_override_font_sizes/font_size = 12")
                行.append("mouse_default_cursor_shape = 2")
            elif 类型 == "LineEdit":
                行.append("max_length = %d" % 附加.get("最长", 0))
            if 附加.get("隐"):
                行.append("visible = false")
        父尺[路径] = (宽, 高)
    return "\n".join(行) + "\n"


def 十六到四(色):
    色 = 色.lstrip("#")
    return "(%s, %s, %s, 1.0)" % tuple("%.6f" % (int(色[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    干 = "--扫" in sys.argv
    序, 表 = 收集纹理()
    文本 = 出场景(序, 表)
    print("件 %d 个（期望同数）、纹理 %d 张、场景字符 %d" % (len(件), len(序), len(文本)))
    assert len(期望["件"]) == len(件)
    撞 = {名: 径 for 名, 径 in 所有路径.items() if 名 in 当过父 and len(径) > 1}
    if 撞:
        raise SystemExit("被当父用的节点名不唯一（会挂错父 ⇒ 件掉到 (0,0)）：%s" % 撞)
    print("九宫格边距（现场解析 MainLib）：%s" % 九宫)
    for 键 in ("内容背景", "分页", "内容区", "我的队伍", "附近队伍", "附近玩家", "我的羁绊", "酒宴列表"):
        if not any(p == 键 or p.endswith("/" + 键) for p in [e["路径"] for e in 期望["件"]]):
            raise SystemExit("外壳缺件：" + 键)
    if 干:
        print("（--扫：没写盘）")
        return
    os.makedirs(场景目录, exist_ok=True)
    os.makedirs(期望目录, exist_ok=True)
    场景路 = os.path.join(场景目录, "队伍窗.tscn")
    期望路 = os.path.join(期望目录, "队伍页期望.json")
    for 路, 内容 in ((场景路, 文本), (期望路, json.dumps(期望, ensure_ascii=False, indent=1))):
        临 = 路 + ".tmp"
        with io.open(临, "w", encoding="utf-8", newline="\n") as f:
            f.write(内容)
        with io.open(临, encoding="utf-8") as f:
            if len(f.read()) != len(内容):
                raise SystemExit("临时文件回读长度不符，不覆盖：" + 路)
        os.replace(临, 路)
    print("已写 %s" % 场景路)
    print("已写 %s" % 期望路)
    print("行数 场景=%d 期望=%d" % (文本.count("\n"), 期望["件"].__len__()))


if __name__ == "__main__":
    main()
