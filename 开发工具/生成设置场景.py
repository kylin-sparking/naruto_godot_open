# -*- coding: utf-8 -*-
"""设置页生成器：一份 SPEC 同时产出 ①`场景/界面/窗口/设置/设置窗口.tscn`
②门期望 `数据/界面/设置页期望.json`（同源，**别手改 .tscn**）。

真值：`game-client/真值/窗口/设置.md` §1–§6。坐标 = **窗口坐标 − (0, 拖动区高 29)**
（这一页是 `整框: true` 的整窗 1:1 移植：原版窗 423×424，MYellow 在窗口 (6,39)，
和 资讯查询 同一口径 —— 见 `数据/界面/窗口尺寸.json` 的「整框」机制）。

时间轴坐标不在 AS3 里（SCW 只按名字绑定），所以每件都带 `出处` 指回
`数据/界面/设置_时间轴.json`（由 `开发工具/元件时间轴.py SystemConfigWindowF --json` 生成）。

用法：python 开发工具/生成设置场景.py → Godot --path . --headless --import
     → Godot --path . --headless --script res://测试/设置页回归测试.gd
"""
import io
import json
import os
import sys

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚠️ 原来写死作者机的 naruto_godot；改成从本文件反推，见 §合并说明
场景目录 = os.path.join(项目, "场景", "界面", "窗口", "设置")
期望目录 = os.path.join(项目, "数据", "界面")

抬 = 29.0		# MWindow.as:229 拖动区高 ⇒ 页面 y = 窗口 y − 29
窗 = [423, 424]
页 = [423, int(窗[1] - 抬)]

皮目录 = "res://素材/界面/原版窗口/设置/%s.png"
通用皮 = "res://素材/界面/原版窗口/通用控件/%s.png"
控制器 = "res://脚本/界面/窗口/设置/设置窗口.gd"
复选件 = "res://场景/界面/组件/原版复选项.tscn"
复选脚本 = "res://脚本/界面/组件/原版复选项.gd"
圆脚本 = "res://脚本/界面/组件/自绘圆.gd"

黄边 = [11, 10, 10, 12]		# KeyboardFrameMYellow_background §13:1000 = 11/10/10/12.05（NinePatch 只吃整数 ⇒ 向下取整）
盒边 = [7, 6, 7, 7]		# KeyboardFrameMPane_background §13:998 = 7.5/6.75/7/7.25

语 = {}
for 档 in ("core.json", "ui.json", "message.json"):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import 原版数据 as _语言源  # 语言表取自 AS3 字面量，与本工程同一条链
    for k, v in _语言源.读语言表(档.removesuffix(".json")).items():
        if isinstance(v, str):
            语.setdefault(k, v)


def 文(键):
    if 键 not in 语:
        raise SystemExit("语言表缺键，别自造文案：" + 键)
    return 语[键]


# ── 主页面 16 枚复选（SCW:141-149 的「+50 位移」已算进 y；y 写**窗口坐标**，落场景时减 29）
# (件名, 语言键, x, 窗口y, 宽, 会话键, 勾选时写入)　—— 会话键沿用工程 `session.game_settings` 现有键，
# 不新造键：原版「拒绝家族邀请 / 拒绝组队邀请」在本工程是同一个开关 `allow_group_invites`（合并绑定）。
主页复选 = [
    ("遮罩其他玩家造型", "SYSTEM_CONFIG_HIDE_OTHER_CHAR_PIC", 20, 74, 182, "show_other_characters", False),
    ("遮罩其他玩家名字", "SYSTEM_CONFIG_HIDE_OTHER_CHAR_NAME", 20, 168, 182, "show_names", False),
    ("遮罩其他玩家特效", "SYSTEM_CONFIG_HIDE_OTHER_MO_FA_TEXIAO", 20, 212, 182, "show_skill_effects", False),
    ("遮罩暴击震屏", "SYSTEM_CONFIG_HIDE_ZHEN_PING", 20, 262, 182, "screen_shake", False),
    ("遮罩低生命心跳", "SYSTEM_CONFIG_HIDE_XIN_TIAO", 20, 310, 182, "low_hp_effect", False),
    ("遮罩任务追踪面板", "SYSTEM_CONFIG_HIDE_QUEST_TRACKER_WINDOW", 20, 357, 182, "show_quest_tracker", False),
    ("遮罩队员资讯窗口", "SYSTEM_CONFIG_HIDE_TROOP_HP_PANE", 20, 383, 182, "show_team_hp", False),
    ("关闭地图音乐", "SYSTEM_CONFIG_CLOSE_MAP_MUSIC", 222, 74, 182, "mute_music", True),
    ("关闭动作音效", "SYSTEM_CONFIG_CLOSE_ACTION_MUSIC", 222, 121, 182, "mute_sound", True),
    ("遮罩所有造型特效", "SYSTEM_CONFIG_CLOSE_LINGQI_TEXIAO", 222, 168, 182, "show_aura_effects", False),
    ("关闭自动提交任务", "SYSCONFIG_CLOSE_COMMIT_QUEST", 222, 195, 182, "auto_commit_quest", False),
    ("禁止他人发起私聊", "SYSTEM_CONFIG_FORBID_WHISPER", 222, 218, 182, "allow_whisper", False),
    ("禁止他人加我为好友", "SYSTEM_CONFIG_FORBID_ADD_FRIEND", 222, 264, 182, "allow_friend_requests", False),
    ("拒绝他人发起交易", "SYSTEM_CONFIG_FORBID_TRADE_INVITE", 222, 313, 182, "allow_trade_requests", False),
    ("拒绝家族邀请", "SYSTEM_CONFIG_FORBID_FAMILY_INVITE", 222, 359, 182, "allow_group_invites", False),
    ("拒绝组队邀请", "SYSTEM_CONFIG_FORBID_TROOP_INVITE", 222, 386, 182, "allow_group_invites", False),
]
# ── 黄字提示（#FFF000 = 16773120，SCW:505-643；三条「禁止」提示随 +50 位移）
主页提示 = [
    ("提示快捷显隐键一", "SYSTEM_CONFIG_SHORTCUT_KEY", 40, 94),
    ("提示快捷显隐键二", "SYSTEM_CONFIG_SHORTCUT_KEY", 40, 188),
    ("提示忍术特效", "SYSTEM_CONFIG_HIDE_OTHER_MO_FA_TEXIAO_TIP", 40, 235),
    ("提示震屏", "SYSTEM_CONFIG_HIDE_ZHEN_PING_TIP", 40, 282),
    ("提示心跳", "SYSTEM_CONFIG_HIDE_XIN_TIAO_TIP", 40, 329),
    ("提示音乐开关", "SYSTEM_CONFIG_SHORTCUT_KEY_SWITCH", 242, 94),
    ("提示音效开关", "@快捷开关键：Ctrl + Y", 242, 142),	# SCW:586 = 键值 substr(0,6)（"快捷开关键："）+ "Ctrl + Y"
    ("提示私聊", "SYSTEM_CONFIG_FORBID_WHISPER_TIP", 242, 239),
    ("提示加好友", "SYSTEM_CONFIG_FORBID_ADD_FRIEND_TIP", 242, 285),
    ("提示交易", "SYSTEM_CONFIG_FORBID_TRADE_INVITE_TIP", 242, 332),
]
# ── 特殊设置页（SCW:151-215，全部代码 new）
特页复选 = [
    ("分栏装备特性", "@装备特性/神话属性分栏显示", 20, 70, 240),
    ("分栏三栏", "@改为3栏分栏", 38, 95, 190),
    ("分栏四栏", "@改为4栏分栏", 38, 120, 190),
    ("遮罩自身忍术特效", "@隐藏自身忍术特效", 20, 147, 182),
    ("遮罩所有忍术特效", "@隐藏所有忍术特效", 20, 174, 182),
    ("遮罩宠物变身外观", "@隐藏宠物变身卡外观", 20, 201, 182),
]
特页音量 = [
    ("条背景音乐音量", "@背景音乐音量", 20, 232),
    ("条技能音效音量", "@技能/界面音效音量", 20, 275),
]
页签 = [("页签系统设置", "SYSTEM_CONFIG", 16), ("页签快速键", "SYSTEM_CONFIG_SHORTCUT_KEY_SET_BTN", 76),
	("页签特殊设置", "@特殊设置", 136)]
# 第 4 枚**不是原版件**：原版 SystemConfigWindow 只有三页（§2）。
# 「客户端」页承载本工程自加的开关（全屏/自动拾取/后端主机端口…），旧版就在「更多设置」页里，
# 节点名一律照旧（`功能窗口._render_more_settings` 按名字取件），删了就是丢功能。
客页签 = ("页签客户端", "@客户端", 196)


def 去标记(串):
    串 = 串.replace("<br/>", "\n").replace("<br>", "\n")
    while True:
        a = 串.find("<")
        if a < 0:
            return 串
        b = 串.find(">", a)
        if b < 0:
            return 串
        串 = 串[:a] + 串[b + 1:]


def 文案(键):
    return 去标记(文(键)) if not 键.startswith("@") else 键[1:]


def 色串(十六):
    r, g, b = ((十六 >> 16) & 255) / 255.0, ((十六 >> 8) & 255) / 255.0, (十六 & 255) / 255.0
    return "Color(%s, %s, %s, 1)" % (round(r, 6), round(g, 6), round(b, 6))


资源 = []		# (res:// 路径, id)


def 皮(路径):
    for i, (p, _) in enumerate(资源):
        if p == 路径:
            return "r%d" % (i + 1)
    资源.append((路径, None))
    return "r%d" % len(资源)


节 = []


def 加(名, 类, 父, 属性, 局=None):
    行 = ['[node name="%s" type="%s" parent="%s"]' % (名, 类, 父)]
    行.append("layout_mode = 0")
    if 局:
        行 += ["offset_left = %s" % 局[0], "offset_top = %s" % 局[1],
               "offset_right = %s" % (局[0] + 局[2]), "offset_bottom = %s" % (局[1] + 局[3])]
    行 += 属性
    节.append("\n".join(行))


def 九宫(名, 皮路, 边, 局, 父="."):
    加(名, "NinePatchRect", 父,
      ["texture = ExtResource(\"%s\")" % 皮(皮路)]
      + ["patch_margin_%s = %s" % (k, v) for k, v in zip(("left", "top", "right", "bottom"), 边)], 局)


def 复选(名, 键, 局, 父, 宽, 路径=""):
    """一行复选 = 直接落四件（指示框/标记/文本/点击区域），**不复用** `原版复选项.tscn`：
    那个组件是脚本生成的、子件没有 owner，实例覆盖会被 Godot 判成
    `Parent path "./文本" ... has vanished`（改动静默失效）。
    直接落件还能逐字对上时间轴：盒 19×19 @ (0,0)、`tf` @ **(22,4)**（tag 542 第 2 层）。

    ⚠ 但**交互态必须挂组件那份脚本**（`原版复选项.gd`）：这一族原版是 `MCheckBoxF`→`MButton3`，
    悬停 +30 / 按下 −40 是运行时加性滤镜（`StyleUtil.as:7-12`），Godot 只能预烘派生皮换 `texture`。
    以前这四件是"版式对、状态机没接"⇒ 22 行勾点了什么反馈都没有（用户 10-19「很死板」）。
    行根 = Control，正好是组件脚本的宿主；子件名与组件完全同名（指示框/标记/文本/点击区域），
    脚本 `_ready()` 按名字找件、抄主干，不需要 owner，也不动几何 ⇒ 几何门不受影响。"""
    加(名, "Control", 父, ["mouse_filter = 2", "script = ExtResource(\"%s\")" % 皮(复选脚本)], 局)
    全 = ((父 + "/" if 父 != "." else "") + 名)		# ⚠ .tscn 的 parent= 是**从场景根算**的路径
    # 两张皮走 `通用控件/`，不走 `设置/` 那两张同名件（10-19 现查：两处**逐像素全等**、都 19×19）。
    # 理由是状态机的取皮口径 = 「与常态皮**同目录**同名加后缀」（`原版复选项.gd::_取图`），
    # 而 `_悬停/_按下/_灰` 只烘在共享目录旁边（`开发工具/生成复选框态图.py`）⇒
    # 指向页私有那份，查不到派生皮就只能回落常态，等于这一页 22 行勾又回到"点了没反应"。
    加("指示框", "TextureRect", 全,
      ["texture = ExtResource(\"%s\")" % 皮(通用皮 % "复选框未选"),
       "expand_mode = 1", "mouse_filter = 2"], [0, 0, 19, 19])
    加("标记", "TextureRect", 全,
      ["visible = false", "texture = ExtResource(\"%s\")" % 皮(通用皮 % "复选框选中"),
       "expand_mode = 1", "mouse_filter = 2"], [0, 0, 19, 19])
    加("文本", "Label", 全,
      ["text = \"%s\"" % 文案(键), "theme_override_colors/font_color = %s" % 色串(0xFFFFFF),
       "theme_override_font_sizes/font_size = 12", "mouse_filter = 2", "clip_text = true"],
      [22, 4, 宽 - 22, 15])
    加("点击区域", "Button", 全,
      ["flat = true", "focus_mode = 0", "mouse_default_cursor_shape = 2",
       "theme_override_colors/font_color = %s" % 色串(0x000000)], [0, 0, 宽, 19])
    前 = (路径 or 父) + "/" + 名
    记(前, [局[0], 局[1], 宽, 19], "SCW:466-471,752-757 行 19 高、宽 182")
    for 子, 子局, 注 in [("指示框", [0, 0, 19, 19], "时间轴 542 的 upSkin(103) 19×19"),
                 ("标记", [0, 0, 19, 19], "时间轴 542 的 selectedUpSkin(100) 19×19，初值隐藏"),
                 ("文本", [22, 4, 宽 - 22, 15], "时间轴 542 的 tf @ (22,4)"),
                 ("点击区域", [0, 0, 宽, 19], "整行可点（原版 MCheckBox 自身收 CLICK）")]:
        记(前 + "/" + 子, 子局, 注)


期望 = {}


def 记(名, 局, 注):
    期望[名] = [[round(局[0], 2), round(局[1], 2), round(局[2], 2), round(局[3], 2)], 注]


def _客户端层():
    加("更多设置", "Control", ".", ["mouse_filter = 2", "visible = false"], [0, 0, 页[0], 页[1]])
    记("更多设置", [0, 0, 页[0], 页[1]], "非原版层：工程自加的客户端开关容器（旧版第 3 页原样搬来，节点名不变）")
    局表 = [
        ("音乐面板", "Panel", [17, 43, 181, 132]), ("音效面板", "Panel", [213, 43, 181, 132]),
    ]
    for 名, 类, 局 in 局表:
        加(名, 类, "更多设置", [], 局)
        记("更多设置/" + 名, 局, "旧版件，_render_more_settings 按名取")
        for 子, 子类, 子局, 文 in [("标题", "Label", [13, 10, 150, 20],
                    ("音乐设置" if 名 == "音乐面板" else "音效设置")),
                # 勾高一律 19 = 皮肤高：主题已给 `CheckBox/hover_pressed` 补空盒，
                # 最小高不再是「皮高 + 4×2 = 27」那档（`脚本/界面/原版皮肤表.gd` CheckBox 段）。
                ("静音", "CheckBox", [10, 34, 155, 19], ("关闭地图音乐" if 名 == "音乐面板" else "关闭动作音效")),
                ("音量文字", "Label", [13, 62, 150, 20], ("音乐音量" if 名 == "音乐面板" else "音效音量")),
                ("音量", "HSlider", [13, 88, 150, 20], "")]:
            属 = ["text = \"%s\"" % 文] if 文 and 子类 == "Label" else []
            if 子类 == "CheckBox" and 文:
                属 = ["text = \"%s\"" % 文]
            加(子, 子类, "更多设置/" + 名, 属, 子局)
    # ⚠ 两枚勾高 19（= 皮高）：以前写 27，是因为缺 `CheckBox/hover_pressed` 槽 ⇒
    # 引擎兜底空盒带 4 像素四边边距，把最小高顶到 27、19 的皮居中后往下挪 4（烘 27 才勉强贴住）。
    # 主题补了空盒后最小高回 19，烘高必须跟着回 19，否则控制矩形又比皮高一大截、
    # 与下面「连接标题」那一行叠出 8 像素的可点带。
    静 = [("全屏显示", "CheckBox", [20, 184, 170, 19], "全屏显示"),
        ("自动拾取", "CheckBox", [216, 184, 170, 19], "自动拾取"),
        ("连接标题", "Label", [20, 212, 368, 18], "原服务端连接"),
        ("主机", "LineEdit", [20, 232, 130, 23], ""), ("端口", "SpinBox", [156, 232, 90, 23], ""),
        ("同步", "Button", [312, 232, 76, 23], "立即同步"),
        ("账号", "LineEdit", [20, 260, 178, 23], ""), ("密码", "LineEdit", [210, 260, 178, 23], ""),
        ("网页地址", "LineEdit", [20, 288, 368, 23], ""),
        ("连接状态", "Label", [20, 318, 368, 20], "")]
    for 名, 类, 局, 文 in 静:
        属 = ["text = \"%s\"" % 文] if 文 else []
        加(名, 类, "更多设置", 属, 局)
        记("更多设置/" + 名, 局, "旧版件，_render_more_settings / 后端接线按名取")


def 主():
    os.makedirs(场景目录, exist_ok=True)
    # ── 底与两栏（SCW 时间轴：MYellow (6,39) 411×379、MPane (11,64)/(212,64) 200×349）
    九宫("九宫内容底", 皮目录 % "内容底", 黄边, [6, 39 - 抬, 411, 379])
    记("九宫内容底", [6, 39 - 抬, 411, 379], "时间轴 532 原生 263×349 拉 1.5628×1.0860；§13:1000 边距 11/10/10/12.05")
    九宫("九宫左栏", 皮目录 % "子面板", 盒边, [11, 64 - 抬, 200, 349])
    记("九宫左栏", [11, 64 - 抬, 200, 349], "时间轴 534 原生 253×212 拉 0.7905×1.6462；§13:998")
    九宫("九宫右栏", 皮目录 % "子面板", 盒边, [212, 64 - 抬, 200, 349])
    记("九宫右栏", [212, 64 - 抬, 200, 349], "同上，时间轴 x=212")
    # ── 三枚页签（541 皮 39×22，代码设宽 59、isScale9Grid=false ⇒ 整张非等比拉）
    # 交互态：`MTabButton.as:16-32` 的 over/down **不换图、只换滤镜**
    # （`StyleUtil.as:7-12` up 0 / over +30 / down −40 加在**同一张皮**上）⇒ 预烘派生皮
    # （`开发工具/生成页签态图.py`，公式与底栏十钮同源 `开发工具/派生钮态.py`）。
    # ⚠ **不挂 `texture_hover` / `texture_pressed`**：`MButton3.as:103-108 mouseUpHandler`
    #   松手回 **STATE_UP 而不是 OVER**（鼠标停在上面也不再亮，要移出去再进来）。
    #   Godot 的 texture_hover 在松手后只要还在悬停就一直亮 ⇒ 形状不对，所以三态一律由
    #   `设置窗口.gd:_绑页签三态()` 换 `texture_normal` 本身来做（与底栏十钮同一口径）。
    # 选中枚不派生：原版 `set enabled(v){selected=!v}` ⇒ 选中枚 DISABLED、滤镜取 STATE_UP=0，
    # 既不吃鼠标也不加亮，只显示未加亮的 selectedUpSkin(538)。
    for 序, (名, 键, x) in enumerate(页签):
        加(名, "TextureButton", ".",
          ["texture_normal = ExtResource(\"%s\")" % 皮(皮目录 % "页签未选"),
           "texture_disabled = ExtResource(\"%s\")" % 皮(皮目录 % "页签选中"),
           "mouse_default_cursor_shape = 2",	# MButton3.init():135 buttonMode + useHandCursor
           "ignore_texture_size = true", "stretch_mode = 0",
           # ⚠ disabled 烘**运行期真值**：`_摆层()` 是 `disabled = (i == 页)`，开局页=0
           #   ⇒ 只有第 1 枚 disabled。四枚全烘 true 的话，编辑器里四枚都显示选中皮，与实机不符。
           "disabled = %s" % ("true" if 序 == 0 else "false"),
           "metadata/skin = \"%s\"" % (皮目录 % "页签未选")[:-4],
           "metadata/act = \"设置:%s\"" % 名,
           "theme_override_font_sizes/font_size = 12"],
          [x, 44 - 抬, 59, 22])
        记(名, [x, 44 - 抬, 59, 22], "SCW:486-492,153-159 宽设 59、皮原生 39、isScale9Grid=false")
    加("字页签系统设置", "Label", "页签系统设置",
      ["text = \"%s\"" % 文案("SYSTEM_CONFIG"), "horizontal_alignment = 1", "vertical_alignment = 1",
       "theme_override_colors/font_color = %s" % 色串(0xFFFFFF),
       "theme_override_font_sizes/font_size = 12", "mouse_filter = 2"], [0, 0, 59, 22])
    for 名, 键, x in 页签[1:]:
        加("字" + 名[2:], "Label", 名,
          ["text = \"%s\"" % 文案(键), "horizontal_alignment = 1", "vertical_alignment = 1",
           "theme_override_colors/font_color = %s" % 色串(0xFFFFFF),
           "theme_override_font_sizes/font_size = 12", "mouse_filter = 2"], [0, 0, 59, 22])
    for 名, 键, x in [客页签]:
        加(名, "TextureButton", ".",
          ["texture_normal = ExtResource(\"%s\")" % 皮(皮目录 % "页签未选"),
           "texture_disabled = ExtResource(\"%s\")" % 皮(皮目录 % "页签选中"),
           "mouse_default_cursor_shape = 2",
           "ignore_texture_size = true", "stretch_mode = 0", "disabled = false",	# 开局页=0，第 4 枚未选中
           "metadata/skin = \"%s\"" % (皮目录 % "页签未选")[:-4],
           "metadata/act = \"设置:%s\"" % 名,
           "theme_override_font_sizes/font_size = 12"],
          [x, 44 - 抬, 59, 22])
        记(名, [x, 44 - 抬, 59, 22], "非原版：本工程「客户端设置」页签（占第 4 格，宽同 59）")
        加("字" + 名[2:], "Label", 名,
          ["text = \"%s\"" % 文案(键), "horizontal_alignment = 1", "vertical_alignment = 1",
           "theme_override_colors/font_color = %s" % 色串(0xFFFFFF),
           "theme_override_font_sizes/font_size = 12", "mouse_filter = 2"], [0, 0, 59, 22])
    _客户端层()
    # ── 主页（16 复选 + 10 黄字 + 1 绿字盒）
    加("层主页", "Control", ".", ["mouse_filter = 2"], [0, 0, 页[0], 页[1]])
    记("层主页", [0, 0, 页[0], 页[1]], "SCW:246-259 showMainPage 整层显隐")
    for 名, 键, x, y, 宽, _会, _写 in 主页复选:
        复选("复选" + 名, 键, [x, y - 抬, 宽, 19], "层主页", 宽, "层主页")
    for 名, 键, x, y in 主页提示:
        高 = 18
        加(名, "Label", "层主页",
          ["text = \"%s\"" % 文案(键), "theme_override_colors/font_color = %s" % 色串(0xFFF000),
           "theme_override_font_sizes/font_size = 12", "mouse_filter = 2", "autowrap_mode = 0"],
          [x, y - 抬, 170, 高])
        记("层主页/" + 名, [x, y - 抬, 170, 高], "SCW:505-643 BaseUtil.getLabel(#FFF000) 宽 170、adjustContent=false")
    # 绿字盒：Box 163×44 @ (27,114)，内 TextField #00FF00 两行 leading 6 ⇒ 盒高 15·2+6+4 = 40
    加("盒绿字造型说明", "Control", "层主页", ["mouse_filter = 2"], [27, 114 - 抬, 163, 44])
    记("层主页/盒绿字造型说明", [27, 114 - 抬, 163, 44], "SCW:519-525 new Box() setSize(163,44) @ (27,114)")
    加("文绿字造型说明", "RichTextLabel", "层主页/盒绿字造型说明",
      ["theme_override_colors/default_color = %s" % 色串(0x00FF00),
       "theme_override_font_sizes/normal_font_size = 12",
       "theme_override_constants/line_separation = 8",		# leading 6 + 2（user memory「行距」）
       "bbcode_enabled = false", "scroll_active = false", "mouse_filter = 2",
       "text = \"%s\"" % 文案("SYSTEM_CONFIG_HIDE_OTHER_CHAR_PIC_TIP").replace("\n", " ")],
      [0, 0, 163, 40])
    记("层主页/盒绿字造型说明/文绿字造型说明", [0, 0, 163, 40], "SCW:526-536 textColor=65280、multiline、height=textHeight+6")
    # ── 特殊设置页
    加("层特页", "Control", ".", ["mouse_filter = 2", "visible = false"], [0, 0, 页[0], 页[1]])
    记("层特页", [0, 0, 页[0], 页[1]], "SCW:264-281 showSpecialPage 整层显隐")
    for 名, 键, x, y, 宽 in 特页复选:
        复选("复选" + 名, 键, [x, y - 抬, 宽, 19], "层特页", 宽, "层特页")
    for 名, 键, x, y in 特页音量:
        加(名, "Control", "层特页", ["mouse_filter = 2"], [x, y - 抬, 180, 32])
        记("层特页/" + 名, [x, y - 抬, 180, 32], "SCW:286-308 createVolumeSlider（bgm y=pet+31、sfx=bgm+43）")
        加("文标签", "Label", "层特页/" + 名,
          ["text = \"%s 100%%\"" % 文案(键), "theme_override_colors/font_color = %s" % 色串(0xFFFFFF),
           "theme_override_font_sizes/font_size = 12", "mouse_filter = 2"], [0, 0, 180, 20])
        记("层特页/" + 名 + "/文标签", [0, 0, 180, 20], "SCW:290-296 TextField 180×20 白字")
        加("轨条", "ColorRect", "层特页/" + 名,
          ["color = %s" % 色串(0x333333), "mouse_filter = 2"], [0, 22, 170, 6])
        记("层特页/" + 名 + "/轨条", [0, 22, 170, 6], "SCW:298-300 drawRect(0,22,170,6) 填充 3355443=#333333")
        加("钮滑块", "Control", "层特页/" + 名,
          ["script = ExtResource(\"%s\")" % 皮(圆脚本), "半径 = 7.0",
           "颜色 = %s" % 色串(0xFFCC00), "mouse_filter = 2"],
          [-7, 18, 14, 14])
        记("层特页/" + 名 + "/钮滑块", [-7, 18, 14, 14], "SCW:301-304 drawCircle(0,25,7) 填充 16763904=#FFCC00")
    # ── 落盘
    头 = ["[gd_scene load_steps=%d format=3]" % (len(资源) + 2),
          '[ext_resource type="Script" path="%s" id="1_script"]' % 控制器]
    for i, (p, _) in enumerate(资源):
        类 = "PackedScene" if p.endswith(".tscn") else ("GDScript" if p.endswith(".gd") else "Texture2D")
        头.append('[ext_resource type="%s" path="%s" id="r%d"]' % (类, p, i + 1))
    根 = ['[node name="原版系统设置内容" type="Control"]',
          "custom_minimum_size = Vector2(%d, %d)" % tuple(页),
          "script = ExtResource(\"1_script\")",
          "窗名 = \"设置\""]
    with io.open(os.path.join(场景目录, "设置窗口.tscn"), "w", encoding="utf-8") as f:
        f.write("\n\n".join(头 + ["", "\n".join(根)] + 节) + "\n")
    with io.open(os.path.join(期望目录, "设置页期望.json"), "w", encoding="utf-8") as f:
        json.dump({"窗": 窗, "页": 页, "抬": 抬, "件": 期望,
                  "页签": [[名, 文案(键), x] for 名, 键, x in 页签] + [[客页签[0], "客户端", 客页签[2]]],
                  "复选": [[("复选" + n), 文案(k), x, y - 抬, w, 会, 真] for n, k, x, y, w, 会, 真 in 主页复选],
                  "特页复选": [[("复选" + n), 文案(k), x, y - 抬, w] for n, k, x, y, w in 特页复选],
                  "音量": [[n, 文案(k), x, y - 抬] for n, k, x, y in 特页音量]},
                 f, ensure_ascii=False, indent=1)
    print("设置窗口.tscn：%d 节点、期望 %d 条；页 %dx%d（窗 %dx%d − 抬 %s）"
          % (len(节) + 1, len(期望), 页[0], 页[1], 窗[0], 窗[1], 抬))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    主()
