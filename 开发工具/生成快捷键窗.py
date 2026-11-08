# -*- coding: utf-8 -*-
"""快捷键窗生成器：`KeyboardFrame`（原版快速键设置窗）整扇 1:1 →
①`场景/界面/窗口/设置/快捷键窗.tscn` ②门期望 `数据/界面/快捷键窗期望.json`（同源）。

坐标**没有一个手抄**，四份数据拼出来：
  · `数据/界面/快捷键_时间轴.json` —— 94 个命名实例（`开发工具/元件时间轴.py KeyboardFrameF`）；
  · `数据/界面/键位表.json` —— `KeyDef.as:297-815` 的格标签 / **格宽** / 可绑性 + 31 条动作槽；
  · `数据/界面/快捷键_补文案.json` —— `开发工具/出快捷键补文案.py` 从实机 SWF 常量池取的 6 条方案文案；
  · `game-client/真值/共用件度量表.md` §13 —— 九宫格边距（只认这张表，禁拟合）。

三条容易再踩的原版口径（都是上一版被打回的根因，写在生成器里当护栏）：
1. **页面 y = 时间轴 y − 拖动区高 29**（`整框: true` 的页容器原点在 (0,29)）。
   上一版 86 枚格忘了减，整排键盘低 27px 直接压在四枚操作钮上。
2. **格宽不是恒 40**：`KeyboardCell.as:99` 在 KEYBOARD_FRAME 下 `cellBg.width = KeyDef.width`
   ⇒ 空格 224 / Shift 87 / Lock 77 / Ctrl 等 60 / Enter 55 / Tab·Bksp 50，共 13 枚是宽键。
   所以格用**内层 cellBg（tag 550）九宫格**画，不能用 44×44 的整元件图硬拉
   （552 烘了设计期 countTextField 的「0」，而 `KeyboardCell.as:61` 运行期把它 visible=false）。
3. **列表格上不是动作名直接铺在格上**：`KeyboardListCell.as:44-49` 是 40×40 格里放一枚
   36×36 `KeyboardShortcurIconF`（在 (2,2)），格名走 `KeyboardShortcurIcon.as:31-44` 的
   宋体分支（2 字前置换行、3 字前置全角空格）、DefineEditText 1121 的盒 (5,5)31×31 右对齐。

尺寸口径：时间轴 background(530) 原生 275×394 拉 2.7818604×0.87564087 ⇒ **765×345**；
`KF:128` 运行期把 keyboardListSprite 的 height 设成 `(14+40<<1)+2 = 110`（原生皮 68）⇒
窗高 = 345 + 110 = **455**、窗宽 = **765**（`KF:120` 的 `background.width − 14 − 54` 也以此为右界）。

用法：python 开发工具/生成快捷键窗.py → Godot --path . --headless --import
     → Godot --path . --headless --script res://测试/快捷键窗回归测试.gd
"""
import io
import json
import os
import sys

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚠️ 原来写死作者机的 naruto_godot；改成从本文件反推，见 §合并说明
读 = lambda p: json.load(io.open(os.path.join(项目, "数据", "界面", p), encoding="utf-8"))
时轴 = 读("快捷键_时间轴.json")["件"]
键表 = 读("键位表.json")["表"]
键槽 = 读("键位表.json")["槽"]
补文 = 读("快捷键_补文案.json")["表"]

场景目录 = os.path.join(项目, "场景", "界面", "窗口", "设置")
期望文件 = os.path.join(项目, "数据", "界面", "快捷键窗期望.json")
皮目录 = "res://素材/界面/原版窗口/设置/%s.png"
控制器 = "res://脚本/界面/窗口/设置/快捷键窗.gd"

抬 = 29.0			# MWindow.as:229 拖动区高 ⇒ 页面 y = 窗口 y − 29
窗 = [765, 455]
页 = [765, 426]
格边 = [9, 9, 8, 10]		# KeyGrid_background §13:996 = 9/9.5/8.75/10（NinePatch 只吃整数 ⇒ 向下取整）
列边 = [21, 16, 21, 19]		# keyboardList_background §13:1086 = 21/16/21.05/19
格高 = 40			# cellBg 原生 40×40，运行期只改宽不改高
牌 = 36			# KeyboardShortcurIcon.as:24-32 固定 36×36

语 = {}
for 档 in ("core.json", "ui.json", "message.json"):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import 原版数据 as _语言源  # 语言表取自 AS3 字面量，与本工程同一条链
    for k, v in _语言源.读语言表(档.removesuffix(".json")).items():
        for kk, vv in json.load(f).items():
            if isinstance(vv, str):
                语.setdefault(kk, vv)
语.update(补文)


def 案文(键):
    if 键 in 语:
        return 语[键]
    raise SystemExit("语言表缺键，别自造文案：" + 键)


def 牌文(名):
    """`KeyboardShortcurIcon.as:31-44` 宋体分支：2 字前置一个换行、3 字前置一个全角空格。"""
    if len(名) == 2:
        return "\n" + 名
    if len(名) == 3:
        return "　" + 名
    return 名


def 转(文):
    return 文.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


资源 = []


def 皮(路径):
    for i, p in enumerate(资源):
        if p == 路径:
            return "r%d" % (i + 1)
    资源.append(路径)
    return "r%d" % len(资源)


节 = []
期望 = {}


def 加(名, 类, 父, 属性, 局):
    行 = ['[node name="%s" type="%s" parent="%s"]' % (名, 类, 父), "layout_mode = 0",
          "offset_left = %s" % 局[0], "offset_top = %s" % 局[1],
          "offset_right = %s" % (局[0] + 局[2]), "offset_bottom = %s" % (局[1] + 局[3])]
    行 += 属性
    节.append("\n".join(行))


def 记(路, 局, 注):
    期望[路] = [[round(局[0], 2), round(局[1], 2), round(局[2], 2), round(局[3], 2)], 注]


def 九宫(名, 皮路, 边, 局, 父=".", 注="", 属=None):
    加(名, "NinePatchRect", 父,
       ["texture = ExtResource(\"%s\")" % 皮(皮路)]
       + ["patch_margin_%s = %s" % (k, v) for k, v in zip(("left", "top", "right", "bottom"), 边)]
       + (属 or []), 局)
    记((父 + "/" if 父 != "." else "") + 名, 局, 注)


def 钮(名, 局, 标签, 注, 选中=False):
    """MButton3 的静态外观：`isScale9Grid = false`（KF:112 / :777）⇒ 57×22 整张非等比拉伸，
    不是九宫格；`texture_normal` 用选中皮 = MButton3 的 `selectedUpSkin`（selected 态停在上图）。"""
    加(名, "TextureButton", ".",
       ["texture_normal = ExtResource(\"%s\")" % 皮(皮目录 % ("钮底选中" if 选中 else "钮底")),
        "ignore_texture_size = true", "stretch_mode = 0", "focus_mode = 0",
        "mouse_default_cursor_shape = 2",
        "metadata/skin = \"%s\"" % (皮目录 % ("钮底选中" if 选中 else "钮底"))[:-4],
        "metadata/act = \"快捷键:%s\"" % 名[1:]], 局)
    记(名, 局, 注)
    加("字" + 名[1:], "Label", 名,
       ["text = \"%s\"" % 转(标签), "horizontal_alignment = 1", "vertical_alignment = 1",
        "theme_override_font_sizes/font_size = 12", "mouse_filter = 2"], [0, 0, 局[2], 22])
    记(名 + "/字" + 名[1:], [0, 0, 局[2], 22], "钮上文字（MButton3 的 tf，MenuPane 同族口径）")


def 图标底(父, 局, 文本, 注, 可见=True):
    """36×36 `KeyboardShortcurIconF`：底片 = 位图 1119（不能用 1122 元件图，它烘了设计期占位字）；
    文字盒 = DefineEditText 1121 在件内 (7,7)、bounds (−2,−2)-(29,29) ⇒ 件内 (5,5) 31×31，右对齐、12px 粗体白。

    键格上的牌**每枚可绑格都烘出来**（未绑的先 hidden）：运行期拖放要显隐/改字，
    现场 new 就得在运行期 load 皮 ⇒ 编辑器里看不到、门也量不到。"""
    加("牌", "TextureRect", 父,
       (["visible = false"] if not 可见 else [])
       + ["texture = ExtResource(\"%s\")" % 皮(皮目录 % "图标底板"),
          "expand_mode = 1", "mouse_filter = 2"], 局)
    记(父 + "/牌", 局, 注 + ("；未绑 ⇒ hidden" if not 可见 else ""))
    加("牌字", "Label", 父 + "/牌",
       ["text = \"%s\"" % 转(文本), "horizontal_alignment = 2",
        "autowrap_mode = 3", "theme_override_font_sizes/font_size = 12",
        "theme_override_colors/font_color = Color(1, 1, 1, 1)",
        "font_flags = 2", "mouse_filter = 2"], [5, 5, 31, 31])
    记(父 + "/牌/牌字", [5, 5, 31, 31],
        "KSI:31-44 宋体分支 + 1121 bounds (−2,−2)-(29,29) ⇒ 盒 (5,5)31×31 右对齐")


def 主():
    os.makedirs(场景目录, exist_ok=True)
    # ── 底：时间轴只有两枚背景件 —— background(530) 是**窗框**（宿主画），页里只补列表条(546)
    九宫("九宫列表底", 皮目录 % "键位列表底", 列边, [0, 345 - 抬, 765, 110], ".",
         "keyboardList_background(546) 原生 765×68；KF:128 运行期 height=(14+40<<1)+2=110")
    # ── 86 枚键位格（格宽 = KeyDef.width；cellBg = tag 550 九宫格）
    格数 = 0
    默认绑定 = {s["defaultKeyId"]: s for s in 键槽}
    for 名, (号, 符号, x, y, sx, sy) in 时轴.items():
        if 符号 != "KeyboardCellF" or not 名.endswith("Cell"):
            continue
        键 = 名[:-4]
        数 = 键表.get(键, {})
        宽 = int(数.get("width", 格高))
        可绑 = bool(数.get("canSet", True))
        局 = [x, y - 抬, 宽, 格高]
        九宫("格" + 名, 皮目录 % "键位格底", 格边, 局, ".",
             "时间轴 %s (%.0f,%.0f)；KC:99 cellBg.width=KeyDef %s width=%s" % (名, x, y, 键, 宽),
             ["mouse_filter = 0" if 可绑 else "mouse_filter = 2",	# KF:100-105 只有 canSet 才挂监听
              "metadata/key = \"%s\"" % 键,
              "metadata/canset = %s" % ("true" if 可绑 else "false")])
        # 默认绑定：KF:84-96 用 CharacterConfig 的键位表灌格；首次进游戏 = KeyDef 的 defaultKeyId。
        # 可绑格一律烘出牌（未绑 hidden），运行期只切显隐 + 改字，不在运行期 load 皮。
        # ⚠ 牌必须**先**落、键名小字**后**落：原版 `KC:87 cellBg.addChild(icon)` 把牌塞进 cellBg，
        #   而 keyTextField 是 `KC:51 addChild` 加在格上、晚一层 ⇒ 键名永远压在牌上面。
        #   反过来写会让 36×36 的牌把 (2,3) 处的键名整个盖掉。
        if 可绑:
            槽 = 默认绑定.get(数.get("keyId"))
            图标底("格" + 名, [(宽 - 牌) >> 1, (格高 - 牌) >> 1, 牌, 牌],
                   牌文(槽["文"]) if 槽 is not None else "",
                   "KC:79-93 addIcon 于 cellBg 内居中"
                   + ("；默认绑 %s（%s）" % (槽["文"], 槽["defaultKeyId"]) if 槽 is not None else "；默认无绑定"),
                   可见=槽 is not None)
        加("字" + 名, "Label", "格" + 名,
           ["text = \"%s\"" % 转(str(数.get("name", ""))),
            "theme_override_font_sizes/font_size = 11", "font_flags = 2",
            "theme_override_colors/font_color = Color(1, 0.6235294117647059, 0.2588235294117647, 1)"
            if 可绑 else "theme_override_colors/font_color = Color(0.8235294117647058, 0.8235294117647058, 0.8235294117647058, 1)",
            "mouse_filter = 2"], [2, 3, 宽 - 2, 15])
        记("格" + 名 + "/字" + 名, [2, 3, 宽 - 2, 15],
            "KC:49-53 getLabel()+x=2,y=1 与 ML:206-207 textField.y=2 ⇒ 字盒 (2,3)；"
            "KC:116 色 canSet?0xFF9F42:0xD2D2D2")
        格数 += 1
    # ── 34 枚列表格（KF:129-143：17 列 × 2 行、格距 42，整组在 110 高的条内居中）
    x0 = (765 - 17 * 42 - 2) >> 1
    y0 = (110 - 2 * 40 - 2) >> 1
    槽位 = {s["position"]: s for s in 键槽}
    for i in range(34):
        全 = "列格%d" % i
        局 = [x0 + i % 17 * 42, 345 - 抬 + y0 + (i // 17) * 42, 40, 40]
        加(全, "Control", ".", ["mouse_filter = 0", "metadata/slot = %d" % i], 局)
        记(全, 局, "KF:131-143 x=%d+(i%%17)·42、y=345+%d+⌊i/17⌋·42" % (x0, y0))
        加("底", "TextureRect", 全,
           ["texture = ExtResource(\"%s\")" % 皮(皮目录 % "键位列表格"),
            "expand_mode = 1", "mouse_filter = 2"], [0, 0, 40, 40])
        记(全 + "/底", [0, 0, 40, 40], "KeyboardListCellF(844) 40×40")
        槽 = 槽位.get(i)
        if 槽 is not None:
            图标底(全, [(40 - 牌) >> 1, (40 - 牌) >> 1, 牌, 牌], 牌文(槽["文"]),
                   "KLC:44-49 非忍术槽铺 KeyboardShortcurIconF、(40−36)/2 居中；文=槽 %s" % 槽["文"])
    # ── 四枚操作钮（KF:109-120：ok/cancel 宽 32、cancelEdit/reset 宽 54，右界 = background.width−14）
    # 节点名照 AS3 实例名 + 语言表文案，不叫「放弃修改 / 恢复默认」——那两头文案读反过：
    #   cancelEditBtn = BTNS[3] =「全部重置」→ 回到 KeyDef 基本设定（KF:304-307）
    #   resetBtn      = BTNS[4] =「全部消除」→ 清掉所有绑定（KF:300-303 / :629-638）
    reset = 765 - 14 - 54
    位 = {"钮全部消除": reset, "钮全部重置": reset - 54 - 5,
         "钮取消": reset - 54 - 5 - 32 - 54, "钮确定": 0}
    位["钮确定"] = 位["钮取消"] - 32 - 5
    for 名, 键, 宽 in [("钮确定", "KEYBOARD_OPERATE_BTNS_1", 32), ("钮取消", "KEYBOARD_OPERATE_BTNS_2", 32),
                ("钮全部重置", "KEYBOARD_OPERATE_BTNS_3", 54), ("钮全部消除", "KEYBOARD_OPERATE_BTNS_4", 54)]:
        钮(名, [位[名], 317 - 抬, 宽, 22], 案文(键),
           "KF:109-120 右对齐链（reset.x = 765−14−54）；文案键 %s =「%s」" % (键, 案文(键)))
    # ── 五枚方案钮 + 保存方案（KF:766-793：x = 14+(i−1)·(72+3)、宽 72、y = okBtn.y）
    # 首次进游戏没有任何已存方案 ⇒ `refreshSchemeButtons`(KF:795-812) 给每枚加 EMPTY_SUFFIX「(空)」，
    # 且 selectedScheme 恒为 1 ⇒ 方案1 停在其 selectedUpSkin（tag 554）。
    for i in range(1, 6):
        钮("钮方案%d" % i, [14 + (i - 1) * 75, 317 - 抬, 72, 22],
           案文("KEYBOARD_SCHEME_PREFIX") + str(i) + 案文("KEYBOARD_SCHEME_EMPTY_SUFFIX"),
           "KF:766-785 x=14+(i−1)·75、宽 72、name=keyScheme%d；KF:806 selected=%d==selectedScheme(1)" % (i, i),
           选中=(i == 1))
    钮("钮保存方案", [14 + 5 * 75 + 3, 317 - 抬, 72, 22], 案文("KEYBOARD_SCHEME_SAVE"),
       "KF:786-793 x=14+5·75+3=392、宽 72；文案键 KEYBOARD_SCHEME_SAVE")
    # ── 落盘
    头 = ["[gd_scene load_steps=%d format=3]" % (len(资源) + 2),
          '[ext_resource type="Script" path="%s" id="1_script"]' % 控制器]
    for i, p in enumerate(资源):
        头.append('[ext_resource type="Texture2D" path="%s" id="r%d"]' % (p, i + 1))
    根 = ['[node name="原版快速键内容" type="Control"]',
          "custom_minimum_size = Vector2(%d, %d)" % tuple(页),
          "script = ExtResource(\"1_script\")", "窗名 = \"快捷键\""]
    with io.open(os.path.join(场景目录, "快捷键窗.tscn"), "w", encoding="utf-8") as f:
        f.write("\n\n".join(头 + ["", "\n".join(根)] + 节) + "\n")
    with io.open(期望文件, "w", encoding="utf-8") as f:
        json.dump({"窗": 窗, "页": 页, "抬": 抬,
                   "_窗注": "background(530) 765×345 + KF:128 把列表条设成 110 高 ⇒ 455；"
                            "530 是窗框，由宿主画，页里不重复铺底",
                   "件": 期望, "格数": 格数, "列表数": 34,
                   "宽键": {k[:-4]: int(v["width"]) for k, v in 键表.items()
                            if v.get("width", 40) != 40},
                   "钮": [[k, 位[k], 317 - 抬, 宽] for k, 宽 in
                         [("钮全部消除", 54), ("钮全部重置", 54), ("钮取消", 32), ("钮确定", 32)]],
                   "方案": [[("钮方案%d" % i), 14 + (i - 1) * 75, 317 - 抬] for i in range(1, 6)]
                   + [["钮保存方案", 392, 317 - 抬]],
                   "文案": {"方案前缀": 案文("KEYBOARD_SCHEME_PREFIX"),
                          "空后缀": 案文("KEYBOARD_SCHEME_EMPTY_SUFFIX"),
                          "保存": 案文("KEYBOARD_SCHEME_SAVE")}},
                  f, ensure_ascii=False, indent=1)
    print("快捷键窗.tscn：%d 节点（键位格 %d、列表格 34、操作钮 4、方案钮 6）；期望 %d 条；页 %dx%d"
          % (len(节) + 1, 格数, len(期望), 页[0], 页[1]))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    主()
