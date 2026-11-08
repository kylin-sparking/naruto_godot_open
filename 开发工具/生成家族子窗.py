# -*- coding: utf-8 -*-
"""家族子窗生成器：一份 SPEC 同时产出 ①场景 .tscn ②门用的期望 JSON（单一真值源）。

为什么生成而不是手写：家族有 15 个子窗，手写 .tscn 与手写门期望会各自漂移
（主窗那轮就栽在"门期望抄错 x=373"）。SPEC 里每条都带 AS3 行号，场景和门都从它派生。

坐标口径：SPEC 写**窗口坐标**（AS3 原值），落场景时统一减内容区原点 (8,38)
（`UIWindow.as:36-38`：contentBg = (8,38)，尺寸 窗宽−16 / 窗高−68）。
例外：`壳=假` 的窗（FamillyPopUpWindow / 旗帜帮助 / Boss 两窗）不是 UIWindow 内容区，原点 (0,0)。

文案口径：**一律从原版语言表解析**（`真值文档/UI/texts/{core,ui,message,CN}.json`），
键查不到就直接 raise —— 宁可生成失败，也不自造文案。
`"键+："` 表示"语言值 + 字面后缀"（对应 AS3 的 `CN.PLAYER_NAME + "："`）。
自适应宽度按《共用件度量表》§6.1:345 `宽 = textWidth + 4`，12 号全角按 12px/字、半角 6px/字。

用法：python 开发工具/生成家族子窗.py        # 生成全部
     然后 Godot --path . --headless --import
"""
import io
import json
import os
import re
import sys

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚠️ 原来写死作者机的 naruto_godot；改成从本文件反推，见 §合并说明
# ⚠️ 语言表原来读作者机上的 `真值文档/UI/texts/{core,ui,message,CN}.json`（本机没有 ⇒
#    直接 FileNotFoundError，生成器跑不起来）。改成读本工程的 AS3 语言表字面量
#    （`开发工具/原版数据.py`，同一份文案），见文件尾的 `语言表` 组装。
#    ⚠️ 他那个第 4 个包 `CN.json` 在本仓库**没有对应物**（AS3 只解出 core/ui/message 三份）；
#       真有只在该包里的键，会走 `文()` 的"语言表缺键，别自造文案"直接报错退出 ——
#       是**响的**失败，不会静默生成一版错文案。
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据 as _语言源  # noqa: E402

场景目录 = os.path.join(项目, "场景", "界面", "窗口", "家族")
期望目录 = os.path.join(项目, "数据", "界面")
家族皮 = "res://素材/界面/原版窗口/家族/%s.png"
通用皮 = "res://素材/界面/原版窗口/通用控件/%s.png"
控制器 = "res://脚本/界面/窗口/家族/家族子窗.gd"

盒边 = [7.5, 6.75, 7.0, 7.25]		# MPane_background 97（《度量表》§13:1016 附近）
提示边 = [40.25, 29.25, 12.05, 20.5]	# MessageTipPane2_background 175（《度量表》§13:1020）
钮边 = [7.15, 7.15, 7.3, 7.0]		# MButton_up 18（§3.2）


def 整(v):
    """九宫边距定形：`NinePatchRect` 的 `patch_margin_*` 只收 **int**（探针实测 hint 0..16384px），
    .tscn 里写分数不报错但**向零截断** ⇒ 文件说的和运行期用的差一像素（§3.228）。
    上面三张表继续存 Flash 的分数原值（那是《度量表》§13 的真值），只在烘出去时四舍五入（.5 远离 0）。"""
    return int(v + 0.5) if v >= 0 else -int(-v + 0.5)

色表 = {
    "橙": "#FF7F00",		# UIConfig:928 UI_ORANGE
    "白": "#FFFFFF",
    "绿": "#00FF00",		# UIConfig:930 UI_GREEN
    "黄": "#FFFF00",		# UIConfig:932 UI_YELLOW
    "蓝": "#1E90FF",		# UIConfig:926 UI_BLUE
    "紫": "#BA55D9",		# UIConfig:938 UI_ZHI_SE
    "红": "#FF0000",		# UIConfig:940 UI_RED
    "肉": "#FDCE99",		# UIConfig:936 UI_ZHONG_SE（表头）
    "默认": "#FF9740",		# UIConfig:906 COMMON_TEXT_COLOR
}

语言表 = {}
for 档 in ("core", "ui", "message"):
    for k, v in _语言源.读语言表(档).items():
        if isinstance(v, str):
            语言表.setdefault(k, v)


def 色串(名):
    """`Color("#FF0000", 1, 1, 1)` 在 GDScript 里合法、在 .tscn 的变量解析里**不合法**
    （解析器只认四个数）⇒ 一律转成十进制浮点。"""
    h = 色表[名].lstrip("#")
    return "Color(%s, %s, %s, 1)" % tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def 文案(键):
    """语言表取值；`键+字面` = 值后拼字面（AS3 里 `CN.PLAYER_NAME + "："`）；
    `=字面` = 直接给字面（分页码/每页项数这类不在语言表里的占位）。查不到就 raise。"""
    if 键 is None or 键 == "":
        return ""
    if 键.startswith("="):
        return 键[1:]
    k, _, 尾 = 键.partition("+")
    if k not in 语言表:
        raise SystemExit("语言表里没有这个键，别自造文案：%s" % 键)
    return 语言表[k] + 尾


def 字宽(文, 余量=4):
    """《度量表》§6.1:345 `宽 = textWidth + 4`；12 号全角 12px、半角 6px。"""
    return sum(12 if ord(c) > 0x2E80 else 6 for c in 文) + 余量


def 去标记(文):
    文 = re.sub(r"<[^>]+>", "", 文)
    return 文.replace("\\r", " ").replace("\r", " ").replace("\n", " ").strip()


def 转BB(文):
    """AS3 htmlText → Godot bbcode（TextArea2 的正文都带 font/br 标签）。"""
    文 = 文.replace("\\'", "'")
    文 = 文.replace("<br/>", "[br]").replace("<br>", "[br]").replace("\\r", "\n").replace("\r", "\n")
    文 = re.sub(r"<font color='(#[0-9a-fA-F]+)'>", r"[color=\1]", 文)
    文 = re.sub(r'<font color="(#[0-9a-fA-F]+)">', r"[color=\1]", 文)
    文 = 文.replace("</font>", "[/color]")
    文 = 文.replace("<u>", "[u]").replace("</u>", "[/u]")
    return 文


def 列串(x, y, 宽表, 键表, 前缀, 出处):
    """表头三件套：`createSanJiaoLable`/`createListLable` 的链式 x（字画 y−2、分隔线画在列右缘 y）。"""
    出 = []
    cx = x
    for i, (宽, 键) in enumerate(zip(宽表, 键表)):
        名 = 去标记(文案(键))
        出.append(["列|%s%d" % (前缀, i), [cx, y - 2, 宽, 19], 出处, 键, {"色": "肉"}])
        if i + 1 < len(宽表):		# 末列无分隔线（`FamillyWindow.as:268-286`）
            出.append(["竖分隔|%s竖%d" % (前缀, i), [cx + 宽, y, 2, 20], 出处])
        cx += 宽
    return 出


def 商品格(ox, oy, n):
    """ItemPane 内部链式（`famillyshop/ItemPane.as:85-127`）。运行期有货才建，故只进期望表当模板。"""
    return [
        ["盒|商品%d底" % n, [ox, oy, 177, 101], "ItemPane:85-90 MPane_background 176.8×101.4"],
        ["标题|商品%d名" % n, [ox + 8, oy + 3, 161, 19], "ItemPane:91-99 居中橙粗、x=8、宽=177−16、y=3"],
        ["线|商品%d线" % n, [ox + 5, oy + 23, 167, 2], "ItemPane:100-104 x=5、宽=177−10、y=23"],
        ["标签|商品%d价" % n, [ox + 68, oy + 36, 75, 20], "ItemPane:105-112 75×20 adjustContent=false", "FAMILLYSHOP_PRICE", {"色": "白"}],
        ["格|商品%d物" % n, [ox + 18, oy + 40, 40, 40], "ItemPane:113-116 ItemWindowCell"],
        ["角标|商品%d角" % n, [ox + 143, oy + 37, 18, 18], "ItemPane:117-121"],
        ["钮|商品%d买" % n, [ox + 68, oy + 60, 57, 22], "ItemPane:122-126 未设 width ⇒ 皮宽 57", "SHOP_BUY"],
    ]


def 守卫行():
    """FamillyPetWindow 的 7 行（`FP:130-145` 线 y=表头底+23×i；
    `FPW:118-133` item 贴在线上方 1px，内部 checkBox x=30/w140、状态字 x=170/w45）。"""
    出 = []
    周 = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
    for i in range(1, 8):
        线y = 71 + 23 * i
        出.append(["线|周%d" % i, [10, 线y, 240, 2], "FP:130-145 y=表头底+23×%d" % i])
        出.append(["复选|周%d" % i, [40, 线y - 20, 140, 19],
                   "FPW:118-124 item(线x、y=线−高−1) 内 checkBox x=30、w140；"
                   "原文案=周几+时刻+开启，时刻是协议字段 ⇒ 空态只落周几", "COMMON_" + 周[i - 1]])
        出.append(["标签|周%d状态" % i, [180, 线y - 20, 45, 19],
                   "FPW:125-133 状态字 x=checkBox右、同y、w45（已选择/已结束/进行中随数据）",
                   None, {"色": "绿"}])
    return 出


# ─────────────────────────── SPEC ───────────────────────────
# 件 = [种名, [x,y,宽,高], 出处(AS3 行号), 文案键(可省), 额外 dict(可省)]
# 宽=None ⇒ 按文案自适应（《度量表》§6.1:345）；额外可给 色/字号/皮/padding/对齐
SPEC = {
    # ―― 第一批（已收口的四个，金币窗的 ±/+/最大 链式这次按 AS3 重算：
    #    `_moneyInput` 是按 `_width`(=窗宽 276) 居中 ⇒ x=(276−125)/2=75，不是先前抄的 98）――
    "家族升级窗": {
        "窗": [178, 270], "as3": "FamillyUpgradeWindow.as:33,83-112",
        "件": [
            ["叶盒|升级消耗", [13, 57, 152, 178], "FUp:83-87 LeafBorder(20)", "UI_53", {"padding": 20}],
            ["文本|升级说明", [13, 57, 152, 178], "FUp:88-93 TextArea2 同盒尺寸、padding8",
             "FAMILLY_UPGRADE_WINDOW_DESC_TANPLATE"],
            ["线", [18, 149, 136, 2], "FUp:95-99 y=textArea.y+92、宽136"],
            ["钮|确定", [40, 243, 61, 22], "FUp:100-106 x=40、y=270−22−5（w37 见下）", "COMMON_OK"],
            ["钮|取消", [101, 243, 61, 22], "FUp:108-112 x=178−37−40", "COMMON_CANCEL"],
        ],
        "钮宽档": {"确定": 37, "取消": 37},
    },
    "家族令牌窗": {
        "窗": [277, 204], "as3": "ZhuGongLingWindow.as:41,135-163,218-234",
        "件": [
            ["文本|说明", [8, 38, 261, 64], "ZGL:135-141 说明 TextArea2", "ZUGONGLING_WINDOW_SAY", {"色": "橙"}],
            ["盒", [13, 103, 251, 66], "ZGL:142-147 高=136−65−5"],
            ["格|0", [16, 116, 40, 40], "ZGL:218-234 6 格 40×40、步距 宽+1、盒内垂直居中"],
            ["格|1", [57, 116, 40, 40], ""],
            ["格|2", [98, 116, 40, 40], ""],
            ["格|3", [139, 116, 40, 40], ""],
            ["格|4", [180, 116, 40, 40], ""],
            ["格|5", [221, 116, 40, 40], ""],
            ["钮|确定", [60, 177, 61, 22], "ZGL:149-163 x=60、y=204−22−5", "COMMON_OK"],
            ["钮|取消", [180, 177, 61, 22], "x=277−37−60", "COMMON_CANCEL"],
        ],
        "钮宽档": {"确定": 37, "取消": 37},
    },
    "家族金币窗": {
        "窗": [276, 214], "as3": "ZhuGongMoneyWindow.as:45,117-196",
        "件": [
            ["盒", [13, 43, 250, 101], "ZGM:117-122 宽=260−10、高=146−5−40"],
            ["标签|余额名", [18, 43, 237, 19], "ZGM:123-129 w237 adjustContent=false", "PACK_MONEY", {"色": "橙"}],
            ["输入|余额", [75, 67, 125, 21], "ZGM:130-140 x=(276−125)/2=75（用 _width 不是 contentBg）、y=标签+24"],
            ["图|金币", [77, 69, 17, 17], "ZGM:130-140 MIconGoldCoinF 611 = 17×17，输入框 +2/+2"],
            ["线", [18, 91, 240, 2], "ZGM:141-145 x=标签x、y=输入底+3、宽=250−10"],
            ["标签|捐献名", [18, 91, 237, 19], "ZGM:146-158 白标签 w237、y=线", "ZUGONGMONEY_WINDOW_GONGXIAN_DUOSHAO"],
            ["输入|捐献", [75, 115, 125, 21], "ZGM:146-158 x=余额输入x、y=标签+24"],
            ["钮|减", [55, 116, 18, 18], "ZGM:160-166 MMinusBtnF 604 18×18 = 输入x−18−2、y=输入+1", None, {"皮": "减号钮"}],
            ["钮|加", [202, 115, 18, 18], "ZGM:167-172 MPlusBtnF 600 = 输入右+2", None, {"皮": "加号钮"}],
            ["钮|最大", [222, 115, 27, 18], "ZGM:173-178 MMaxBtnF 608 27×18 = 加右+2", None, {"皮": "最大钮"}],
            ["文本|说明", [13, 146, 250, 34], "ZGM:179-185 x=盒x、y=盒底+2、高34", "ZUGONGMONEY_WINDOW_SAY", {"色": "橙"}],
            ["钮|确定", [60, 187, 61, 22], "ZGM:186-191 x=60、y=214−22−5", "COMMON_OK"],
            ["钮|取消", [179, 187, 61, 22], "ZGM:192-196 x=276−37−60", "COMMON_CANCEL"],
        ],
        "钮宽档": {"确定": 37, "取消": 37},
    },
    "家族确认弹": {
        "窗": [216, 134], "壳": False, "as3": "FamillyPopUpWindow.as:113-149,176-195",
        "件": [
            ["底", [0, 0, 216, 134], "FamillyPopupWindowSkin 580 = 家族/弹窗底.png 216×134"],
            ["标题|提示", [0, 2, 216, 18], "FPW:115-120 y=2 居中 w=底宽"],
            ["文本|正文", [5, 25, 204, 70], "FPW:121-126 宽=底宽−12、初高70、padding8（正文由调用方喂）"],
            ["复选|记住", [9, 98, 200, 19], "FPW:127-131 x=9、宽随文案"],
            ["钮|确定", [35, 117, 61, 22], "FPW:132-143 x=35、y=背景高−钮高−12", "COMMON_OK"],
            ["钮|取消", [150, 117, 61, 22], "x=右−35−宽", "COMMON_CANCEL"],
        ],
        "钮宽档": {"确定": 37, "取消": 37},
    },

    # ―― 第二批 ――
    "家族成员窗": {
        "窗": [650, 370], "as3": "FamillyMembersWindow.as:147-269",
        "件": [
            # UIWindow 的 `_contentBg`（MYellow_background = 通用控件/内容面板.png，alpha 213）：
            # x=CONTENT_GAP(8)、y=38、w=窗−16、h=窗−68（UIWindow.as:36-38/62-65）。
            # ⚠️ 原先没这层 ⇒ 窗皮(0.843)+盒底(0.506)叠完底下主窗还有 ~8% 透出来，
            #    成员窗大部分面积是空的，主窗的家族信息/成员表整个看穿（2026-10-15 用户截图
            #    报"界面不对"的一半就是它）。原版每扇 UIWindow 都有这层，这里先给成员窗补上。
            ["提示底|内容底", [8, 38, 634, 302], "UIWindow.as:36-38/62-65 contentBg（原版每窗都有）"],
            ["盒", [13, 43, 624, 267], "FM:152-157 宽=634−10、高=302−5−30"],
        ] + 列串(18, 48, [70, 55, 65, 70, 70, 70, 70, 70, 70],
                ["FAMILLY_MEMBERS_NAME", "CHARACTOR_LEVEL", "FAMILLY_MEMBERS_ZHIWU",
                 "FAMILLY_MEMBERS_SKILL_CENGSHU", "BA_MEN_JINDU", "CHENG_JIU_JINDU",
                 "FAMILLY_MEMBERS_ZHANCHANG_SHENGWANG", "FAMILLY_MEMBERS_BENZHOU_BOSS",
                 "FAMILLY_GONGXIAN_WINDOW_GONGXIAN"], "成员", "FM:158-186 链式，createSanJiaoLable") + [
            ["线", [18, 68, 614, 2], "FM:187-190 LineHPicF 宽=624−10、y=表头y+20"],
            ["列表", [18, 72, 614, 235], "FM:191-199 高=267+43−72−3、rowHeight23"],
            ["标签|每页", [28, 313, 28, 19], "FM:203-208 x=线x+10、y=list底+6", "FAMILLY_GONGXIAN_WINDOW_PAGE_COMPONENT"],
            ["下拉|页", [58, 313, 60, 21], "FM:209-214 MComboBox w60、x=每页右+2", "=10项"],
            ["标签|显示", [138, 313, 28, 19], "FM:215-220 x=页下拉右+20", "FAMILLY_LIST_WINDOW_SHOW"],
            ["下拉|成员", [168, 313, 60, 21], "FM:221-227 w60、x=显示右+2", "FAMILLY_MEMBERS_ALL"],
            ["复选|自动同意", [303, 313, 345, 19], "FM:228-236 x=成员下拉右+75、w345", "FAMILLY_MEMBERS_BANGZHU_SHEZHI"],
            ["分页|分页", [263, 347, 124, 18], "FM:237-241 x=(650−124)/2、y=370−18−5", "=1/1"],
            ["钮|添加成员", [121, 343, 61, 22], "FM:251-256 x=开除x−61−5、y=370−22−5", "FAMILLY_MEMBERS_ADD_CHENGYUAN"],
            ["钮|开除出族", [187, 343, 61, 22], "FM:243-250 x=分页x−61−15", "FAMILLY_MEMBERS_KAICHU_CHUZU"],
            ["钮|解散家族", [402, 343, 61, 22], "FM:257-262 x=分页右+15", "FAMILLY_MEMBERS_JIESAN_JIAZU"],
            ["钮|退出家族", [468, 343, 61, 22], "FM:263-269 链+5", "FAMILLY_MEMBERS_TUICHU_JIAZU"],
        ],
    },
    "家族创建窗": {
        "窗": [461, 394], "as3": "FamillyCreateWindow.as:128-249",
        "件": [
            ["标签|家族名", [18, 46, 86, 20], "FC:136-142 FormItem2 title 86、高=20（FormItem2:75）", "FAMILLY_CREATE_INPUT_FAMILLY_NAME", {"色": "橙"}],
            ["输入|家族名", [108, 46, 266, 21], "FC:136-147 content x=86+gap4 ⇒ 窗108；maxChars6", None, {"长": 6}],
            ["钮|检测重名", [379, 46, 61, 22], "FC:148-154 x=表单x+表单宽(86+266+4)+5", "FAMILLY_CREATE_NAME_VALIDATE_BTN"],
            ["标签|公告名", [18, 63, None, 19], "FC:155-159 y=表单底−3、自适应宽", "FAMILLY_CREATE_INPUT_FAMILLY_NOTICE", {"色": "橙"}],
            ["输入文本|公告", [18, 86, 425, 107], "FC:160-172 宽=445−20、y=标签+23、padding4、leading2、maxChars200", None, {"长": 200}],
            ["叶盒|家徽说明", [13, 213, 171, 141], "FC:173-177 LeafBorder(20) y=desc底+20", "UI_69", {"padding": 20}],
            ["叶盒|图形选择", [185, 213, 131, 141], "FC:178-181 LeafBorder(13) x=上一盒右+1", "UI_61", {"padding": 13}],
            ["叶盒|创建条件", [317, 213, 131, 141], "FC:182-187 LeafBorder(13)", "UI_14", {"padding": 13}],
            ["标签|家徽名", [28, 223, None, 19], "FC:188-193 x=盒x+15、y=盒y+10、adjustContent=false w150", "FAMILLY_CREATE_INPUT_FAMILLY_EMBLEM", {"色": "橙"}],
            ["输入|家徽名", [28, 247, 125, 21], "FC:194-200 MTextInput2 原生 125×21、y=标签+24", None, {"长": 6}],
            ["线|家徽", [23, 272, 161, 2], "FC:201-205 x=盒x+5、宽=171−10、y=输入底+4"],
            ["文本|家徽说明", [28, 276, 137, 73], "FC:206-212 宽=171−28−6、y=线底+4、高73", "FAMILLY_CREATE_EMBLEM_SHUOYMING"],
            ["格|家徽图", [230, 253, 40, 40], "FC:213-216 选择盒内水平居中、y=盒y+40"],
            ["线|旗页", [190, 305, 121, 2], "FC:217-221 x=选择盒x+5、宽=131−10、y=格底+12"],
            ["分页短|旗选择", [208, 317, 84, 18], "FC:222-228 盒内居中、y=线底+12、firstAndLastBtnVisible=false"],
            ["标签|创建条件", [317, 223, 127, 20], "FC:229-235 宽=131−4、y=同第一标签、绿字居中", "FAMILLY_CREATE_TIAOJIAN", {"色": "绿", "对齐": 1}],
            ["格|族书", [362, 253, 40, 40], "FC:236-241 ItemCaiLiaoBox 40 宽居中、y=盒y+40"],
            ["钮|创建", [416, 367, 37, 22], "FC:243-249 x=461−37−8、y=394−22−5", "FAMILLY_CREATE"],
        ],
    },
    "家族贡献窗": {
        "窗": [610, 408], "as3": "FamillyGongXianWindow.as:120-261",
        "件": [
            ["叶盒|族贡库存", [13, 57, 584, 68], "FGX:125-131 LeafBorder(30) 宽=594−10、高68、y=38+5+14", "UI_68", {"padding": 30}],
            ["叶盒|族贡记录", [13, 145, 584, 228], "FGX:132-140 y=上盒底+20、高=340−5−145", "UI_67", {"padding": 30}],
            ["格|0", [53, 71, 40, 40], "FGX:141-146 x=盒x+40、盒内垂直居中"],
            ["格|1", [113, 71, 40, 40], "FGX:147-150 前格右+20"],
            ["格|2", [158, 71, 40, 40], "FGX:151-154 右+5"],
            ["格|3", [203, 71, 40, 40], "FGX:155-158 右+5"],
            ["格|4", [248, 71, 40, 40], "FGX:159-160 右+5"],
            ["标签|存量名", [328, 62, None, 19], "FGX:161 x=末格右+40、y=上盒y+5、自适应宽", "FAMILLY_GONGXIAN_WINDOW_GONGXIAN_CUNLIANG", {"色": "橙"}],
            ["输入|存量", [417, 65, 125, 21], "FGX:173-178 x=标签右+1、y=标签+3、只读", None, {"长": 12}],
            ["图|金币", [419, 67, 17, 17], "FGX:179-182 MIconGoldCoinF = 标签右+3、标签y+5"],
            ["钮|贡献金币", [328, 91, 61, 22], "FGX:166-169 x=标签x、y=标签底+10", "FAMILLY_GONGXIAN_WINDOW_GONGXIAN_MONEY"],
            ["钮|贡献书籍", [404, 91, 61, 22], "FGX:170-172 x=上一钮右+15", "FAMILLY_GONGXIAN_WINDOW_GONGXIAN_BOOK"],
        ] + 列串(21, 153, [70, 45, 66, 66, 66, 58, 66, 66, 58],
                ["FAMILLY_GONGXIAN_WINDOW_NAME", "FAMILLY_GONGXIAN_WINDOW_LEVEL", "FAMILLY_GONGXIAN_WINDOW_ZHIWU",
                 "FAMILLY_JIAZUSHUJI", "FAMILLY_GONGXIAN_WINDOW_MONEY", "FAMILLY_ZONGGONGXIAN",
                 "FAMILLY_ZHOUGONGSHUJI", "FAMILLY_ZHOUGONGJINBI", "FAMILLY_ZHOUGONGXIAN"], "贡献", "FGX:183-211 x=下盒x+8、y=下盒y+8") + [
            ["线|上", [18, 173, 574, 2], "FGX:212-216 x=下盒x+5、宽=584−10、y=表头y+20"],
            ["列表", [21, 177, 568, 160], "FGX:217-223 宽=584−16、高 160 字面量、rowHeight23"],
            ["线|下", [18, 339, 574, 2], "FGX:224-229 y=list底+2"],
            ["分页|分页", [243, 350, 124, 18], "FGX:230-235 x=(610−124)/2、y=下盒底−18−5", "=1/1"],
            ["标签|每页", [502, 347, 28, 19], "FGX:236-239 x=下盒右−95、y=分页y−3", "FAMILLY_GONGXIAN_WINDOW_PAGE_COMPONENT"],
            ["下拉|页", [530, 347, 60, 21], "FGX:240-244 x=每页右、同y", "=10项"],
            ["输入|剩贡", [120, 382, 100, 21], "FGX:245-249 w100、y=408−21−5", None, {"长": 12}],
            ["标签|剩贡名", [10, 382, 110, 19], "FGX:250-252 x=10、w110、同输入y", "FAMILLY_GONGXIAN_WINDOW_CURRENT_SHENGYUZHI"],
            ["标签|学技提示", [325, 382, 280, 19], "FGX:253-255 x=610−285、w280 右对齐", "FAMILLY_GONGXIAN_WINDOW_XUEXI_JIAZU_SKILL", {"色": "橙", "对齐": 2}],
            ["角标|商店", [121, 384, 18, 18], "FGX:256-261 叠输入框 +1/+2"],
        ],
    },
    "家族旗帜窗": {
        "窗": [620, 370], "as3": "FamillyFlagWindow.as:228-375",
        "件": [
            ["叶盒|本族族旗信息", [13, 58, 150, 277], "FF:230-236 LeafBorder(12) 高=302−20−5", "UI_6", {"padding": 12}],
            ["标签|家族名", [21, 63, 130, 19], "FF:237-242 x=盒x+8、y=盒y+5、w130", "FAMILLY_FLAG_WINDOW_NAME"],
            ["输入|家族名", [21, 83, 125, 21], "FF:243-246 y=标签+20"],
            ["标签|家族级", [21, 104, 130, 19], "FF:247-252 y=输入底", "FAMILLY_FLAG_WINDOW_LEVEL"],
            ["输入|家族级", [21, 124, 125, 21], "FF:253-257 y=标签+20"],
            ["盒|旗帜预览", [21, 167, 120, 120], "FF:258-263 MPane_background 120×120、y=输入底+2"],
            ["标签|已安插", [21, 289, 130, 19], "FF:264-269 y=预览盒底+2", "FAMILLY_FLAG_WINDOW_COUNT"],
            ["输入|旗数", [21, 309, 125, 21], "FF:270-274 y=标签+20", "FAMILLY_FLAG_COUNT_INPUT"],
            ["标签|旗数上限", [21, 330, 130, 19], "FF:275-280 y=输入底（⚠ 溢出盒底 335，AS3 原样）", "FAMILLY_FLAG_MAX_COUNT"],
            ["叶盒|势力对比图", [164, 58, 443, 60], "FF:281-288 LeafBorder(30) 宽=8+604−164−5、高60", "UI_54", {"padding": 30}],
            ["标签|旗数图文本", [171, 68, 56, 19], "FF:289-292 getLabel2(…,56) x=盒x+7、y=盒y+10", "UI_73"],
            ["线|势力", [167, 86, 437, 2], "FF:293-297 x=盒x+3、宽=盒宽−6、y=文本底+? （+18）"],
            ["竖分隔|势力", [224, 92, 2, 20], "FF:298-302 x=文本x+50+3、y=线底+4"],
            ["标题|势力", [228, 62, 370, 19], "FF:303-308 x=分隔+4、y=文本y−6、w370 居中"],
            ["标题|计数", [167, 89, 50, 19], "FF:309-314 x=盒x+3、y=线+3、w50 居中"],
            ["槽|进度", [228, 92, 372, 20], "FF:315-318 MTextInput_background 372×20 x=分隔+4、y=线+6"],
            ["区|进度条", [232, 96, 364, 12], "FF:319-321 Shape 绘三段渐变（运行期），槽内 +4/+4"],
            ["叶盒|族旗安插列表", [164, 138, 443, 197], "FF:322-329 y=上盒底+20、高=340−138−5=197（真值文档写 205，按 AS3 复算）", "UI_72", {"padding": 30}],
            ["列表", [169, 165, 431, 165], "FF:331-339 x=盒x+5、y=盒y+27、宽=盒−10−2、高=盒−32=165"],
        ] + 列串(169, 145, [80, 50, 80, 40, 80, 90],
                ["LABEL_STRINGS_1", "LABEL_STRINGS_2", "LABEL_STRINGS_3", "LABEL_STRINGS_4",
                 "LABEL_STRINGS_5", "LABEL_STRINGS_6"], "旗", "FF:340-356 ⚠ 源码写 CN.LABEL_STRINGS（全局 6 项）") + [
            ["线|旗表", [169, 163, 431, 2], "FF:357-361 y=表头y+18、宽=list宽"],
            ["钮|说明资讯", [223, 343, 57, 22], "FF:362-375 三钮居中 x=(620−57−57−60)/2、y=370−22−5", "FAMILLY_FLAG_WINDOW_HELP"],
            ["钮|安插本族旗帜", [310, 343, 57, 22], "FF:362-375 x=帮助右+30（未设 width ⇒ 57）", "FAMILLY_FLAG_WINDOW_INSERT_FLAG"],
            ["钮|修复族旗血量", [397, 343, 57, 22], "FF:362-375 x=插旗右+30、初始 visible=false", "FAMILLY_FLAG_WINDOW_MODIFY_FLAG"],
        ],
    },

    # ―― 第三批 ――
    "家族守卫窗": {
        "窗": [260, 320], "as3": "FamillyPetWindow.as:124-151,235-263",
        "件": [
            ["标签|可选时间", [98, 50, None, 19], "FP:238-244 宽=textWidth+4、x=(260−宽)/2、y=50 字面量", "FAMILLY_PET_WINDOW_LABLE", {"色": "橙"}],
            ["线|表头", [10, 71, 240, 2], "FP:124-129 x=10、y=标题底+2、宽=260−20"],
        ] + 守卫行() + [
            ["文本|提示", [-8, 235, 280, 80], "FP:248-256 故意超窗（x=−8 ⇒ 页坐标 −16）、280×80 居中橙字", "FAMILLY_PET_WINDOW_TIP", {"色": "橙"}],
            ["钮|确定", [99, 293, 61, 22], "FP:257-263 x=(260−61)/2、y=320−22−5", "COMMON_OK"],
        ],
    },
    "家族搜索窗": {
        "窗": [290, 300], "as3": "SearchPlayerWindow.as:85-162",
        "件": [
            ["标签|玩家名", [48, 43, 54, 20], "SPW:89-97 FormItem2 gap=0、title 54、高 20", "PLAYER_NAME+："],
            ["输入|玩家名", [102, 43, 114, 21], "SPW:89-97 content x=48+54+gap0"],
            ["钮|搜索", [218, 43, 37, 22], "SPW:98-100 x=表单右+2、w37", "TROOP_SEARCH_BTN"],
            ["线|上", [13, 68, 264, 2], "SPW:101-105 x=contentBg+5、宽=274−10、y=表单底+5"],
            ["标签|查找结果", [13, 68, None, 19], "SPW:106-110 压在线起点、自适应宽", "SEARCH_RESULTS"],
            ["盒|列表皮肤", [13, 89, 264, 143], "SPW:111-116 CommonListSkin(23,true) rowNum=5 ⇒ 高=20表头+5×23−2"],
            ["列表", [16, 114, 258, 115], "SPW:132-140 x=皮肤x+3、宽=皮肤−6、高 115 字面量"],
        ] + 列串(16, 92, [135, 53, 70],
                ["GAME_PLAYER_NAME", "CHARACTOR_LEVEL", "SEARCHPLAYER_WINDOW_MENPAI"], "查询", "SPW:117-127 x=皮肤x+3、y=皮肤y+3") + [
            ["线|下", [16, 112, 258, 2], "SPW:128-131 宽=皮肤−6、y=表头y+20"],
            ["标签|模糊提示", [13, 235, None, 19], "SPW:141-145 x=线上x、y=list底+6", "SEARCH_MOHU", {"色": "橙"}],
            ["分页短|分页", [196, 238, 84, 18], "SPW:146-151 x=窗右−分页宽(84)−10、y=提示+3、首末隐藏"],
            ["钮|查看资料", [40, 273, 61, 22], "SPW:152-156 x=40、y=300−22−5", "TROOP_SHOW_CHAR_INFO_BTN"],
            ["钮|邀请加入", [114, 273, 61, 22], "SPW:157-159 x=(290−61)/2", "SEARCHPLAYER_WINDOW_YAOQING_JIARU"],
            ["钮|取消", [213, 273, 37, 22], "SPW:160-162 x=290−37−40、w37", "COMMON_CANCEL"],
        ],
    },
    "家族商城窗": {
        "窗": [575, 435], "as3": "FamillyShopWindow.as:121-166",
        "件": [
            ["盒|商城底", [13, 43, 549, 352], "FS:123-130 ⚠ :124 contentBg.height+=20；宽=559−10、高 352 字面量"],
            ["区|商品区", [18, 48, 541, 314], "FS:59-88 setItems 3 列×3 行，格 176.8×101.4、间距 5、起点=盒x+5/盒y+5 ⇒ 有货才建（见期望表 模板）"],
            ["线", [18, 367, 539, 2], "FS:131-135 x=盒x+5、宽=549−10、y=367 字面量"],
            ["分页|分页", [225, 370, 124, 18], "FS:136-140 x=(575−124)/2、y=370 字面量、PageComponent(0,9)", "=1/9"],
            ["标签|贡值名", [280, 400, None, 19], "FS:141-146 setSize(30,20) 但 adjustContent 默认 true ⇒ 被 updateLayout 覆成 文字宽+4", "FAMILLYSHOP_LEFTGONGXIAN"],
            ["输入|贡值", [380, 400, 80, 21], "FS:147-152 w80、x=标签x+标签宽、只读", None, {"长": 12}],
            ["角标|商店", [381, 402, 18, 18], "FS:153-157 叠输入框 +1/+2"],
            ["标签|如何获得", [465, 400, None, 19], "FS:158-164 x=输入右+5、绿字（⚠ 右缘 577 溢出 575，AS3 原样）", "FAMILLYSHOP_ADDGONGXIAN", {"色": "绿"}],
        ],
        "模板": 商品格(18, 48, 1),
    },
    "家族日环窗": {
        "窗": [355, 407], "as3": "famillyquest/FamillyQuestWindow.as:160-235",
        "件": [
            ["标签|任务说明", [14, 42, None, 19], "FQ:166-170 x=contentBg+6、自适应", "FAMILLY_QUEST_LABEL", {"色": "橙"}],
            ["文本|说明一", [32, 62, 297, 90], "FQ:171-177 宽=339−32−10、y=标签+20、高90", "FAMILLY_DESC_1"],
            ["线", [14, 152, 311, 2], "FQ:178-182 x=标签x、y=说明底、宽=339−2x"],
            ["文本|说明二", [14, 156, 340, 40], "FQ:183-188 paddingV=0、340×40 蓝字（正文随数据）", None, {"色": "蓝"}],
            ["盒|任务盒", [14, 188, 330, 153], "FQ:189-194 x=标签x、y=说明二底−8、330×153"],
            ["标签|任务星级", [22, 196, None, 19], "FQ:195-197 盒x+8/+8", "RIHUAN_LEVEL", {"色": "绿"}],
            ["星|0", [86, 198, 14, 13], "FQ:198-201 x=星级标签右、y=标签+2、StarLevelIconF 693 = 14×13"],
            ["标签|星级说明", [222, 196, None, 19], "FQ:202-205 x=标签x+200", "RIHUAN_LEVEL_DESC", {"色": "绿"}],
            ["标签|倒计时", [22, 319, None, 19], "FQ:206-209 x=盒x+8、y=盒底−22", "RIHUAN_COUNT_DOWN_TEXT+00:00:00", {"色": "橙"}],
            ["复选|自动刷新", [14, 350, None, 19], "FQ:210-215 x=盒x、y=盒底+9、宽=文字宽+21", "RIHUAN_CHENK_LEBEL_1", {"色": "黄"}],
            ["复选|自动停止", [117, 350, None, 19], "FQ:216-221 x=上一复选右+4", "RIHUAN_CHENK_LEBEL_2", {"色": "黄"}],
            ["钮|立即完成", [279, 216, 57, 22], "FQ:222-226 x=盒右−57−8、y=星级说明y+20", "BUTTON_LI_JI_WAN_CHENG"],
            ["钮|刷新任务", [80, 380, 57, 22], "FQ:227-231 x=80、y=407−22−5", "BUTTON_SHUA_XIN_REN_WU"],
            ["钮|开始任务", [218, 380, 57, 22], "FQ:232-235 x=355−57−80", "START_QUSET"],
        ],
    },
    "家族旗帜帮助窗": {
        "窗": [642, 426], "壳": False, "as3": "FamillyFlagHelpWindow.as:36-63,65-83",
        "件": [
            ["整图|旗帜帮助底", [0, 0, 642, 426], "FFH:65-83 外载 UISwf_FlagHelp_Background 实测 642×426；MWindow 自绘底、不是 UIWindow 内容区"],
            ["复选|跳过", [12, 402, 200, 19], "FFH:47-54 x=12、y=426−19−5", "FAMILLY_FLAGHELP_WINDOW_CHECKBOX"],
            ["钮|进入旗帜", [267, 402, 108, 22], "FFH:55-60 width=108 字面量、x=(642−108)/2、同复选 y", "FAMILLY_FLAGHELP_WINDOW_ENTER"],
        ],
    },
    "家族Boss奖励条": {
        "窗": [263, 222], "壳": False, "as3": "FamillyBossPrizeTip.as:43-95,116-128",
        "件": [
            ["提示底", [0, 0, 263, 222], "FBPT:48-51 MessageTipPane2_background 175 原生 263×252，建后 height−=30"],
            ["标题|奖励说明", [0, 5, 263, 19], "FBPT:52-61 MWindow 标题 y=5 整幅居中、16 号粗红", "FAMILLYBOSS_TIP_1", {"色": "红", "字号": 16}],
            ["钮|收起", [240, 8, 18, 18], "FBPT:62-67 BranchButton 660 实测 18×18、x=底宽−18−5、y=8；收起态 x=5（:116-128）", None, {"皮": "展开钮"}],
            ["文本|奖励", [10, 29, 253, 225], "FBPT:73-80 setSize(263−10, 222−标题y+8)=253×225、x=2×5、y=标题y+3×8（⚠ 高按 AS3 字面，超出底框；数据齐后 :198 背景高=文本高+8）", "FAMILLYBOSS_TIP_PRIZE"],
            ["标签|倒计时", [15, 210, 200, 20], "FBPT:81-88 200×20 黄字，x=文本x+5、y=210 字面量", "FAMILLYBOSS_TIP_3+00:00:00", {"色": "黄"}],
        ],
        "钮皮": {"收起": "展开钮"},
    },
    "家族Boss完成窗": {
        "窗": [268, 116], "壳": False, "as3": "FamillyPetFinishWindow.as:29-84",
        "件": [
            ["提示底", [0, 0, 268, 116], "FPPW:31-34 MessageTipPane2_background 设成 268×116（九宫格，不整拉）"],
            ["钮|关闭", [238, 5, 25, 24], "FPPW:35-37 MWindowCloseBtnF 25×24、x=268−25−5、y=5", None, {"皮": "通用/关闭按钮", "静态": 1}],
            ["文本|正文", [0, 13, 268, 65], "FPPW:38-51 白字 leading3 发光、y=13 整幅居中；高=116−13−22−16（drawLayout :81 之前）", "FAMILLY_PET_WINDOW_WINTIP+%1/%2/%3"],
            ["钮|领取", [101, 86, 66, 22], "FPPW:52-57 isScale9Grid=true ⇒ 宽=文字宽+6=66、x=(268−66)/2、y=86 字面量", "PRIZE_GET_BTN"],
        ],
        "钮皮": {"关闭": "通用/关闭按钮"},
    },
}


def 展开(件):
    """叶盒 = LeafBorder 的四件宏（盒 + 两端帽 + 居中盒标题）。期望表里落成的键与手写时一致。"""
    出 = []
    for 项 in 件:
        种名, 矩形, 出处 = 项[0], 项[1], 项[2]
        额外 = 项[4] if len(项) > 4 else {}
        键 = 项[3] if len(项) > 3 else None
        if 种名.startswith("叶盒"):
            _, _, 名 = 种名.partition("|")
            x, y, w, h = 矩形
            p = 额外.get("padding", 30)
            # `LeafBorder.as:66-72,80-85`：端帽 27×22 落在 x=盒x+padding、y=8−22=−14；标题 y=−label高+1
            出.append([("盒|%s" % 名) if 名 else "盒", [x, y, w, h], 出处])
            # 端帽必须带盒名：一扇窗里三个 LeafBorder 会产出三对同名兄弟（`端帽左`），
            # 期望字典互相覆盖、`get_node` 又只拿第一个 ⇒ 门会拿 A 盒的节点去比 C 盒的期望
            # （家族创建窗实测 dx=−297 就是这么来的）。
            出.append(["端帽左|%s" % 名, [x + p, y - 14, 27, 22], 出处])
            出.append(["端帽右|%s" % 名, [x + w - 27 - p, y - 14, 27, 22], 出处])
            出.append(["标题|%s" % 名, [x, y - 19, w, 18], 出处 + "；盒标题居中、y=盒y−19", 键])
            continue
        出.append(项)
    return 出


def 皮名(种, 名, 定, 宽, 额外=None):
    """件种 → res:// 贴图路径。皮的覆盖口有两个，等价：件上写 `{"皮": "减号钮"}`，
    或窗上写 `"钮皮": {"关闭": "通用/关闭按钮"}`。`通用/` 前缀 = 通用控件目录。"""
    额外 = 额外 or {}
    覆 = 额外.get("皮") or 定.get("钮皮", {}).get(名)
    if 种 in ("钮", "下拉"):
        if 覆:
            return (通用皮 if 覆.startswith("通用/") else 家族皮) % 覆.replace("通用/", "")
        if 种 == "下拉":
            return 家族皮 % "下拉%d" % 宽
        return 家族皮 % ("钮底" if 宽 == 57 else "钮底%d" % 宽)
    表 = {
        "盒": 家族皮 % "盒底", "提示底": 通用皮 % "内容面板", "底": 家族皮 % "弹窗底",
        "端帽左": 家族皮 % "端帽左", "端帽右": 家族皮 % "端帽右",
        "线": 通用皮 % "横向分隔线", "竖分隔": 家族皮 % "表头竖分隔线",
        "格": 通用皮 % "物品格", "星": 家族皮 % "星标", "角标": 家族皮 % "商店角标",
        "三角": 通用皮 % "下拉箭头", "条": 通用皮 % "滚动槽", "槽": 通用皮 % "输入框",
    }
    if 种 == "图":
        return 通用皮 % "金币" if 名 == "金币" else 家族皮 % "邀请格"
    if 种 == "整图":
        return 家族皮 % 名
    return 表.get(种, "")


def 生成(窗名, 定):
    窗 = 定["窗"]
    壳 = 定.get("壳", True)
    ox, oy = (8, 38) if 壳 else (0, 0)
    # 页面 Control 的尺寸：宽 = 窗−16（=contentBg 宽），**高 = 窗−38**（不是窗−68）。
    # 因为 AS3 里底栏钮/分页是 `addChild` 到窗口本身、y 直接按 `_height − 钮高 − 5` 算，
    # 会落到 contentBg 下沿之外（成员窗钮页 y=305 > 302）；主窗同口径（601×352 已验收）。
    宽, 高 = (窗[0] - 16, 窗[1] - 38) if 壳 else 窗
    钮档 = 定.get("钮宽档", {})
    资源, 节点, 期望 = [], [], {}
    序 = [0]
    子资源 = ["", '[sub_resource type="StyleBoxEmpty" id="StyleBoxEmpty1"]'] if any(
        str(项[0]).split("|")[0] in ("输入", "输入文本") for 项 in 定["件"]) else []

    def 加(路径):
        序[0] += 1
        资源.append('[ext_resource type="Texture2D" path="%s" id="t%d"]' % (路径, 序[0]))
        return "t%d" % 序[0]

    def 串(文):
        return '"%s"' % 文.replace("\\", "").replace('"', '\\"').replace("\n", "\\n")

    for 项 in 展开(定["件"]):
        种名, 矩形, 出处 = 项[0], 项[1], 项[2]
        键 = 项[3] if len(项) > 3 else None
        额外 = 项[4] if len(项) > 4 else {}
        种, _, 名 = 种名.partition("|")
        名 = 名 or 种
        # 节点名带件种前缀：同一条 SPEC 里"盒|升级消耗"与"标题|升级消耗"、"线|周1"与"复选|周1"
        # 会撞名（Godot 自动改名 @…@2，门按名字取节点就取错件）。动作名另存 metadata/act，保持语义。
        节点名 = (种 + 名) if 种名.find("|") >= 0 else 种
        文 = 文案(键) if 键 is not None else None
        w = 矩形[2]
        if w is None:
            w = 字宽(去标记(文 or "")) + (17 if 种 == "复选" else 0)
        局 = [矩形[0] - ox, 矩形[1] - oy, w, 矩形[3]]
        键名 = ("%s|%s" % (种, 名)) if 种名.find("|") >= 0 else 种
        期望[键名] = [局, 出处 or 定["as3"], 文, 节点名]
        if 种 == "下拉":
            档 = 60 if w <= 60 else 90
        elif 种 == "钮":
            档 = 钮档.get(名, 额外.get("档", 57 if 额外.get("皮") is None else w))
        类型 = {"盒": "NinePatchRect", "提示底": "NinePatchRect", "底": "TextureRect",
                 "整图": "TextureRect", "端帽左": "TextureRect", "端帽右": "TextureRect",
                 "线": "TextureRect", "竖分隔": "TextureRect", "格": "TextureRect",
                 "星": "TextureRect", "角标": "TextureRect", "图": "TextureRect", "条": "TextureRect",
                 "槽": "NinePatchRect", "区": "Control", "文本": "RichTextLabel", "列表": "Control",
                 "输入文本": "TextEdit", "输入": "LineEdit", "标签": "Label", "标题": "Label", "列": "Label",
                 "钮": "TextureButton", "复选": "Control", "下拉": "TextureButton",
                 "分页": "Control", "分页短": "Control"}[种]
        节 = ['[node name="%s" type="%s" parent="."]' % (节点名, 类型)]
        if 种 in ("输入", "输入文本"):
            # `FormItem2.contentField` / `TextArea2.setSkin(MTextInput_background)` ⇒ 输入位都有一张
            # 437 号九宫格底（边距 6.25/5/6.75/6，《度量表》§13:1016）。控件本体走空样式，
            # 底单独垫一层在同矩形上（先加者在下）。
            节点.append("\n".join(['[node name="%s底" type="NinePatchRect" parent="."]' % 节点名,
                                   "layout_mode = 0", "offset_left = %.1f" % 局[0], "offset_top = %.1f" % 局[1],
                                   "offset_right = %.1f" % (局[0] + 局[2]), "offset_bottom = %.1f" % (局[1] + 局[3]),
                                   "mouse_filter = 2", "texture = ExtResource(\"%s\")" % 加(通用皮 % "输入框"),
                                   "patch_margin_left = %d" % 整(6.25), "patch_margin_top = %d" % 整(5),
                                   "patch_margin_right = %d" % 整(6.75),
                                   "patch_margin_bottom = %d" % 整(6)]))
        节 += ["layout_mode = 0", "offset_left = %.1f" % 局[0], "offset_top = %.1f" % 局[1],
               "offset_right = %.1f" % (局[0] + 局[2]), "offset_bottom = %.1f" % (局[1] + 局[3])]
        if 种 not in ("钮", "输入", "输入文本", "下拉", "复选", "分页", "分页短"):
            节.append("mouse_filter = 2")
        if 种 == "列表":
            节.append("clip_contents = true")
        if 种 in ("盒", "提示底", "底", "整图", "端帽左", "端帽右", "线", "竖分隔", "格", "星",
                  "角标", "图", "条", "槽", "钮", "下拉"):
            路径 = 皮名(种, 名, 定, 局[2] if 种 == "下拉" else 档 if 种 == "钮" else 0, 额外)
            id名 = 加(路径)
            节.append(("texture_normal" if 种 in ("钮", "下拉") else "texture") + " = ExtResource(\"%s\")" % id名)
            if 种 in ("盒", "提示底", "槽"):
                边 = 盒边 if 种 == "盒" else (提示边 if 种 == "提示底" else [6.25, 5, 6.75, 6])
                节 += ["patch_margin_left = %d" % 整(边[0]), "patch_margin_top = %d" % 整(边[1]),
                       "patch_margin_right = %d" % 整(边[2]), "patch_margin_bottom = %d" % 整(边[3])]
            else:
                节 += ["expand_mode = 1", "stretch_mode = 0"]
            if 种 in ("钮", "下拉"):
                节 += ["focus_mode = 0", "ignore_texture_size = true"]
                # metadata/skin = 皮主干（完整 res:// 去掉 .png），控制器按它拼 _悬停/_按下/_灰
                # （`MButton3.as:329-346`）。关钮/分页小件是两帧符号、不是 MButton3 滤镜族 ⇒ 用 额外={"静态":1} 不写。
                if not 额外.get("静态"):
                    节.append("metadata/skin = \"%s\"" % 路径[:-4])
                # metadata/act = 语义动作名（节点名带件种前缀会撞车，动作不能跟着变）
                节.append("metadata/act = \"%s\"" % 名)
        if 种 in ("文本", "输入文本"):
            正文 = 转BB(文 or "") if 文 else " "
            if 种 == "文本":
                节 += ["theme_override_constants/line_separation = 2",
                       "theme_override_font_sizes/normal_font_size = 12",
                       "theme_override_colors/default_color = %s" % 色串(额外.get("色", "默认")),
                       "bbcode_enabled = true", "text = %s" % 串(正文), "scroll_active = false"]
            else:
                节 += ["theme_override_font_sizes/font_size = 12",
                       "theme_override_colors/font_color = %s" % 色串(额外.get("色", "默认")),
                       "theme_override_styles/normal = SubResource(\"StyleBoxEmpty1\")",
                       "theme_override_styles/focus = SubResource(\"StyleBoxEmpty1\")",
                       "text = %s" % 串(正文)]
        if 种 == "输入":
            节 += ["placeholder_text = \"\"",
                   "theme_override_styles/normal = SubResource(\"StyleBoxEmpty1\")",
                   "theme_override_styles/focus = SubResource(\"StyleBoxEmpty1\")",
                   "theme_override_font_sizes/font_size = 12",
                   "theme_override_colors/font_color = %s" % 色串(额外.get("色", "绿")),
                   "text = %s" % 串(去标记(文) if 文 else ""),
                   "max_length = %d" % 额外.get("长", 12)]
        if 种 in ("标题", "列"):
            节.append("horizontal_alignment = 1")
        if 种 in ("标签", "标题", "列"):
            节.append("text = %s" % 串(去标记(文) if 文 is not None else ""))
            if 额外.get("色"):
                节.append("theme_override_colors/font_color = %s" % 色串(额外["色"]))
            if 额外.get("字号"):
                节.append("theme_override_font_sizes/font_size = %d" % 额外["字号"])
            if 额外.get("对齐") is not None:
                节.append("horizontal_alignment = %d" % 额外["对齐"])
            节.append("vertical_alignment = 1")
            节.append("clip_text = true")
        if 种 == "复选":
            节 += ["metadata/act = \"%s\"" % 名,
                   "", "[node name=\"框\" type=\"TextureRect\" parent=\"%s\"]" % 节点名,
                   "layout_mode = 0", "offset_right = 19.0", "offset_bottom = 19.0",
                   "mouse_filter = 2", "texture = ExtResource(\"%s\")" % 加(通用皮 % "复选框未选"),
                   "expand_mode = 1", "stretch_mode = 0",
                   "", "[node name=\"字\" type=\"Label\" parent=\"%s\"]" % 节点名,
                   "layout_mode = 0", "offset_left = 24.0", "offset_right = %.1f" % 局[2],
                   "offset_bottom = 19.0", "mouse_filter = 2",
                   "text = %s" % 串(去标记(文) if 文 is not None else ""),
                   "theme_override_colors/font_color = %s" % 色串(额外.get("色", "白"))]
        if 种 == "钮":
            节 += ["", "[node name=\"Label\" type=\"Label\" parent=\"%s\"]" % 节点名,
                   "layout_mode = 1", "anchors_preset = 15", "anchor_right = 1.0", "anchor_bottom = 1.0",
                   "grow_horizontal = 2", "grow_vertical = 2", "mouse_filter = 2",
                   "text = %s" % 串(去标记(文) if 文 is not None else ""),
                   "horizontal_alignment = 1", "vertical_alignment = 1"]
        if 种 == "下拉":
            节 += ["", "[node name=\"文字\" type=\"Label\" parent=\"%s\"]" % 节点名,
                   "layout_mode = 0", "offset_left = 6.0", "offset_right = %.1f" % (局[2] - 15),
                   "offset_bottom = 21.0", "mouse_filter = 2", "vertical_alignment = 1",
                   "text = %s" % 串(去标记(文) if 文 is not None else ""),
                   "theme_override_colors/font_color = Color(1, 1, 1, 1)",
                   "", "[node name=\"箭头\" type=\"TextureRect\" parent=\"%s\"]" % 节点名,
                   "layout_mode = 0", "offset_left = %.1f" % (局[2] - 15), "offset_top = 6.0",
                   "offset_right = %.1f" % (局[2] - 2), "offset_bottom = 14.0", "mouse_filter = 2",
                   "texture = ExtResource(\"%s\")" % 加(通用皮 % "下拉箭头"), "expand_mode = 1", "stretch_mode = 0"]
        if 种 in ("分页", "分页短"):
            # PageComponent 四颗 = MPageFirstBtnF992/Pre856/Next855/End991（18/15/15/18 ×13），
            # 链式 +2 ⇒ 首末隐藏时只剩 84 宽。原版这四颗各有一张皮、无 MButton3 滤镜族证据 ⇒ 不写 skin 元数据。
            件子 = ([("首页", 0, 18, "分页首"), ("上一页", 20, 15, "上一页"), ("页码", 37, 50, None),
                     ("下一页", 89, 15, "下一页"), ("末页", 106, 18, "分页末")] if 种 == "分页" else
                    [("上一页", 0, 15, "上一页"), ("页码", 17, 50, None), ("下一页", 69, 15, "下一页")])
            for 子名, sx, sw, 皮 in 件子:
                if 皮 is None:
                    节 += ["", "[node name=\"%s\" type=\"Label\" parent=\"%s\"]" % (子名, 节点名),
                          "layout_mode = 0", "offset_left = %d.0" % sx, "offset_top = -2.0",
                          "offset_right = %d.0" % (sx + sw), "offset_bottom = 16.0", "mouse_filter = 2",
                          "horizontal_alignment = 1", "vertical_alignment = 1",
                          "text = %s" % 串(去标记(文) if 文 is not None else "1/1")]
                else:
                    节 += ["", "[node name=\"%s\" type=\"TextureButton\" parent=\"%s\"]" % (子名, 节点名),
                          "layout_mode = 0", "offset_left = %d.0" % sx, "offset_right = %d.0" % (sx + sw),
                          "offset_bottom = 13.0", "focus_mode = 0",
                          "texture_normal = ExtResource(\"%s\")" % 加(通用皮 % 皮),
                          "ignore_texture_size = true"]
        节点.append("\n".join(节))
    if 定.get("模板"):
        # 运行期有货才建的商品格：几何不落成节点，但把每件矩形留在期望表里，门可单独核对板。
        期望["_模板"] = [[x[0], [x[1][0] - ox, x[1][1] - oy, x[1][2], x[1][3]], x[2],
                        去标记(文案(x[3])) if len(x) > 3 and x[3] else ""] for x in 定["模板"]]
    头 = ["[gd_scene load_steps=%d format=3]" % (len(资源) + 2 + len(子资源)),
          '[ext_resource type="Script" path="%s" id="1_script"]' % 控制器]
    头 += 资源
    根 = ["[node name=\"%s\" type=\"Control\"]" % 窗名,
          "custom_minimum_size = Vector2(%d, %d)" % (宽, 高),
          "script = ExtResource(\"1_script\")",
          "窗名 = \"%s\"" % 窗名]
    文 = "\n\n".join(头 + 子资源 + ["", "\n".join(根)] + 节点) + "\n"
    # `newline="\n"`：在库 `.tscn`/`.json` 全是 LF，Windows 缺省会写成 CRLF ⇒ 重生一次凭空脏一片（§3.228）。
    with io.open(os.path.join(场景目录, 窗名 + ".tscn"), "w", encoding="utf-8", newline="\n") as f:
        f.write(文)
    with io.open(os.path.join(期望目录, "家族子窗_%s.json" % 窗名), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"窗": 窗, "壳": 壳, "内容": [宽, 高], "件": 期望}, f, ensure_ascii=False, indent=1)
    print("%-14s 内容 %dx%d　%d 件" % (窗名, 宽, 高, len(期望)))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(场景目录, exist_ok=True)
    os.makedirs(期望目录, exist_ok=True)
    for k, v in SPEC.items():
        生成(k, v)
