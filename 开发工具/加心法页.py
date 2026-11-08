# -*- coding: utf-8 -*-
"""一次性给产线加「心法」这一页：窗口尺寸条目 + SPEC 页 + 页目录皮。

跑完就可以 `python 开发工具/原版服务窗.py 生成 心法`。本脚本跑一次即可（不是常驻工具）。
"""
import io
import json
import os
import shutil
import sys

sys.stdout.reconfigure(encoding="utf-8")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
尺路 = os.path.join(工程, "数据", "界面", "窗口尺寸.json")
Spec路 = os.path.join(工程, "数据", "界面", "原版服务窗_SPEC.json")
皮目 = os.path.join(工程, "素材", "界面", "原版窗口", "心法")

# ── 1. 窗口尺寸条目 ───────────────────────────────────────────────────────
尺 = json.load(io.open(尺路, encoding="utf-8"))
尺["心法"] = {
    "宽": 275, "高": 295,
    "整框": True,
    "出处": "XinfaWindow.as:253-255 `background.width=275; height=295`（`super()` 无参 ⇒ 尺寸由这张"
            "背景给）。⚠ `整框` 必须 true：直接子件最小 y = 39（黄底板 `:261-263`）落在 36~40 那一档 ⇒ "
            "标 false 会整页偏 29 像素而几何门照样全绿（工程老坑）。",
}
io.open(尺路, "w", encoding="utf-8", newline="\n").write(json.dumps(尺, ensure_ascii=False, indent=1) + "\n")
print("窗口尺寸.json：加了「心法」275×295 整框 true")

# ── 2. 页目录皮：确定/取消两枚钮都是 `MButtonF`（同一符号）⇒ 三档皮复用徽章打造那套 ──
源 = os.path.join(工程, "素材", "界面", "原版窗口", "徽章打造")
os.makedirs(皮目, exist_ok=True)
拷 = []
for 名 in ("确定钮.png", "确定钮_悬停.png", "确定钮_按下.png"):
    a = os.path.join(源, 名)
    if os.path.isfile(a):
        shutil.copyfile(a, os.path.join(皮目, 名))
        拷.append(名)
print("皮目录 %s：%s" % (os.path.relpath(皮目, 工程), 拷 or "徽章打造那三档不在，得另找来源"))

# ── 3. SPEC 页 ───────────────────────────────────────────────────────────
说 = "打坐时技能栏上方那颗「心法」球点开的那扇（`XinfaWindow` 275×295，`com/mxw/uifl/controls/`，"
"不在 window/ 下）。列表列的**不是**全部 21 条心法，而是**本角色已学的**"
"（`getFirstTypePassivizeSkills()` 遍历 skillInfoList 再按 xinfa==1 过滤）⇒ 控制器拿 "
"`后端连接.authoritative_skills` 与 `数据/界面/心法表.json` 求交集。逐件行号见 真值/窗口/心法.md §①。"
"⚠ 两件没做进场景：① `MArrowBtnF` 的三态皮未烘（产线 元件根 指向已不存在的 game-client ⇒ 要烘得先用 "
"ffdec 现导），这里只摆静态图；② 列表格是运行期按已学心法建的（`initCellCount():223-…`），"
"场景里只给滚动区空壳。"

件 = [
 {"名": "内容底", "类": "panel", "父": "窗", "皮": "内容面板", "x": 6, "y": 39, "w": 263, "h": 221,
  "出处": "XinfaWindow.as:261-266 `new MYellow_background()`、x=6、y=39、w=background.width-12、h=221。"
          "⚠ 不是 UIWindow 那张 (CONTENT_GAP,38)/(w-2gap,h-68) —— 本窗 `super()` 无参、自己 new 的"},
 {"名": "子面板", "类": "panel", "父": "窗", "皮": "子面板", "x": 11, "y": 90, "w": 253, "h": 164,
  "出处": ":268-272 `new MPane_background()`、x=11、y=90、w=background2.width-10、h=164"},
 {"名": "说明盒", "类": "box", "父": "窗", "x": 20, "y": 49, "w": 242, "h": 40,
  "出处": ":158-162 `sayBox` Box setPosition(20,49) setSize(242,40)"},
 {"名": "说明文", "类": "rich", "父": "说明盒", "x": 0, "y": 0, "w": 242, "h": 40,
  "文字": "[font_color=#00ff00]打坐时你不但获得经验与查克拉精华收益，\n还可以选择修炼一种心法，增加熟练度[/font_color]",
  "出处": ":163-170 `sayTf.htmlText = CN.XINFA_SAY`（原串用 <br/> 断行 ⇒ 转 BBCode 换行）、"
          "width=242、wordWrap/multiline、高 = textHeight+6、glow 滤镜（Godot 侧不做滤镜，见未决）"},
 {"名": "选中心法盒", "类": "box", "父": "窗", "x": 20, "y": 109, "w": 68, "h": 36,
  "出处": ":145-149 `selectXinfaBox` Box (20,109) 68×36"},
 {"名": "选中心法文", "类": "rich", "父": "选中心法盒", "x": 0, "y": 0, "w": 68, "h": 36,
  "文字": "[font_color=#ffffff]请在本处选\n择一种心法[/font_color]",
  "出处": ":150-157 `selectXinfaTf.htmlText = CN.SELECT_TYPE_XINFA`（原串中间就带 <br/> ⇒ 断在「选/择」之间，"
          "照抄不许改成自然换行）"},
 {"名": "温馨提示盒", "类": "box", "父": "窗", "x": 20, "y": 159, "w": 242, "h": 96,
  "出处": ":171-175 `wenxintishiBox` Box (20,159) 242×96"},
 {"名": "温馨提示文", "类": "rich", "父": "温馨提示盒", "x": 0, "y": 0, "w": 242, "h": 96,
  "文字": "[font_color=#ff9100]温馨提示：[/font_color]\n[font_color=#ffffff]当[font_color=#1e90ff][u]忍术或心法熟练度[/u][/font_color]提高后，那麽在提升忍\n术和心法的层数时所需要的查克拉精华就会\n数量减少；当你的查克拉数量很足时，也可\n以选直接强行提升忍术和心法的层数[/font_color]",
  "出处": ":176-184 `wenxintishiTf.htmlText = CN.WENXIN_TISHI` —— 四行断句照语言键原串逐字，不许重排"},
 {"名": "主格", "类": "cell", "父": "窗", "皮": "技能格底板", "x": 92, "y": 106, "w": 40, "h": 40,
  "出处": ":186-190 `selectSkillIocn = new SkillCellF()` (92,106)；格 40×40 与技能栏同源"
          "（`素材/界面/技能面板/技能格底板.png` 实测 40×40）。⚠ `:190` `floorText.text = \"\"` ⇒ 主格**不显示层数角标**"},
 {"名": "心法名", "类": "label", "父": "窗", "x": 154, "y": 105, "w": 108, "h": 18,
  "色": "#FFFFE0", "文字": "", "出处": ":141-142 `BaseUtil.getLabel(\"\",16773120,true)` + "
  "setLabel(…,154,105,108,18)；16773120 = #FFFFE0、第三参 true = **bold**。"
  "⚠ Godot 的 Label 没有 bold 属性（写进去会被静默丢弃）⇒ 粗体只能走 FontVariation，"
  "而它会强制描边、毁掉点阵清晰度 ⇒ 本表先按常规字重出，bold 这条挂在未决"},
 {"名": "心法层数", "类": "label", "父": "窗", "x": 154, "y": 127, "w": 108, "h": 18,
  "色": "#FFD000", "文字": "", "出处": ":143-144 `getLabel(\"\",16748800,true)` + setLabel(…,154,127,108,18)；"
  "16748800 = #FFD000、bold。运行期文字 = `CN.CURRENT_CENGSHU + floor` = 「当前层数:」+ 层数（`:92`）"},
 {"名": "选择心法钮", "类": "tex", "父": "窗", "皮": "下拉箭头2", "x": 133, "y": 125, "w": 0, "h": 0,
  "出处": ":124-128 `selectSkillBtn = new MArrowBtnF()`、**`selected = true`**、(133,125)。"
          "⚠ 三态皮未烘（产线 元件根 失效）⇒ 这里只摆静态图，w/h 取皮自身尺寸；"
          "点它 = 把列表滚动区 addChild/removeChild 切一下（`:69-83`），不是普通按钮"},
 {"名": "心法列表", "类": "滚动区", "父": "窗", "x": 92, "y": 146, "w": 57, "h": 90,
  "内容宽": 40, "内容高": 162,
  "出处": ":191-200 `skillScrollPane` x=selectSkillIocn.x=92、y=146、w=57、h=_height=90（`:32`）、"
          "V=ON/H=OFF。⚠ 常态**没挂上窗**（`:73-80` 点箭头才 addChild）⇒ 运行期由控制器决定显隐；"
          "内容高按 4 枚格估（40·i+2，`:223-…`），实际枚数 = 已学心法数，`setData():313` 还会把 "
          "`h` 压成 90>>1（只有一枚时）"},
 {"名": "确定钮", "类": "btn", "父": "窗", "皮": "确定钮", "x": 45, "y": 267, "w": "btn_width_four",
  "文字": "确定", "出处": ":129-134 `okBtn = new MButtonF()`、x=45、y=267、width=UIConfig.btn_width_four=61、"
  "text=CN.COMMON_OK。与取消钮是**同一个符号**⇒ 三档皮复用（MButton3 族一张皮 + 运行时 ±30/−40 滤镜）"},
 {"名": "取消钮", "类": "btn", "父": "窗", "皮": "确定钮", "x": 180, "y": 267, "w": "btn_width_four",
  "文字": "取消", "出处": ":135-140 `cancelBtn` x=180、y=267、w=61、text=CN.COMMON_CANCEL。"
  "点它**只关窗、不发任何包**（`onClickOkBtn` 里只有 okBtn 那支发切换，`:97-115`）"},
]

页 = {
 "类": "com/mxw/uifl/controls/XinfaWindow",
 "as3文件": "原版源码/反编译脚本/MainLib/scripts/com/mxw/uifl/controls/XinfaWindow.as",
 "宽": 275, "高": 295,
 "标题": "修炼心法",
 "标题出处": ":123 `title = CN.XINFA_WINDOW_TITLE` = 「修炼心法」",
 "皮目录": "心法",
 "场景": "场景/界面/窗口/心法/心法窗.tscn",
 "期望": "数据/界面/心法_期望.json",
 "根名": "原版心法窗内容",
 "说明": 说,
 "件": 件,
}
S = json.load(io.open(Spec路, encoding="utf-8"))
S["心法"] = 页
io.open(Spec路, "w", encoding="utf-8", newline="\n").write(json.dumps(S, ensure_ascii=False, indent=1) + "\n")
print("原版服务窗_SPEC.json：加了「心法」页，%d 件" % len(件))
