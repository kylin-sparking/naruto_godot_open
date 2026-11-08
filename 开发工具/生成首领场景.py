# -*- coding: utf-8 -*-
"""从 开发工具/截首领页.gd 的 件路径/件期望/件文案 生成 场景/界面/窗口/首领/首领窗口.tscn。

口径与 `生成意志学习场景.py` 相同：**真值只写在量具表里**，.tscn 是产物，别手改。
本版相对意志版的两处修正（都是那页踩过的坑）：
  * **Panel 不再被塞 `texture`/`expand_mode`**（那是 TextureRect 的属性）——
    意志那份的 `外框黄底` 因此根本没画出来。这里 Panel 一律走
    `theme_override_styles/panel = SubResource("sb_…")`，九宫格边距取 §13 原值。
  * 节点类型/贴图/文案按**相对根的完整路径**显式登记，父节点自动补登时不覆盖已登记的真矩形；
    子节点 offset 一律换算成**相对父**（件期望 存的是页面局部绝对矩形）。

用法：python 开发工具/生成首领场景.py     # 之后 --import + 跑量具
"""
import io
import json
import os
import re
import sys

from 场景id import ascii化		# 资源 id 一律 ASCII（见 开发工具/场景id.py 的说明）

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
量具 = os.path.join(工程, "开发工具", "截首领页.gd")
出 = os.path.join(工程, "场景", "界面", "窗口", "首领", "首领窗口.tscn")
根 = "原版首领窗口内容"
NL = chr(10)
源码 = io.open(量具, encoding="utf-8").read()


def 表(名):
    i = 源码.find("const %s := {" % 名)
    assert i > 0, "量具里找不到 const %s" % 名
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
件文案 = 解析(表("件文案"), lambda v: v.strip('"'))
首页索引 = [int(x) for x in re.search(r"const 首页索引 := \[([^\]]*)\]", 源码).group(1).split(",")]
每页条数 = int(re.search(r"const 每页条数 := (\d+)", 源码).group(1))

# ── 素材：路径 + §13 九宫格边距（左/上/右/下；无 DefineScalingGridTag 的填 0）──
首领 = "原版窗口/首领/"
通用 = "原版窗口/通用控件/"
图 = {
    "黄底": (通用 + "内容面板.png", [11, 10, 10, 11]),          # MYellow_background(10)  §13 X:124
    "子面板": (通用 + "子面板.png", [7.5, 6.75, 7, 7.25]),       # MPane_background(97)    §13 X:1318
    "头像底": (首领 + "头像背景.png", [19, 15, 22.05, 15]),      # PetPic_background(136)  §13 X:2568
    "挑战": (首领 + "前往挑战.png", [0, 0, 0, 0]),               # MWangBossKillBtnF(1126) 22×22
    "星": (首领 + "星级.png", [0, 0, 0, 0]),                     # StarLevelIconF(693) 14×13
    "空星": (首领 + "半星.png", [0, 0, 0, 0]),                   # StarHollowF(782) 14×13
    "首页": (通用 + "首页.png", [0, 0, 0, 0]),                   # MPageFirstBtnF(992) 18×13
    "上一页": (通用 + "上一页.png", [0, 0, 0, 0]),               # MPagePreBtnF(856) 15×13
    "下一页": (通用 + "下一页.png", [0, 0, 0, 0]),               # MPageNextBtnF(855) 15×13
    "末页": (通用 + "末页.png", [0, 0, 0, 0]),                   # MPageEndBtnF(991) 18×13
}
# ⚠ 四枚箭头是 **`MButton3`**（`PageComponent.as:23-41` 字段类型 + `:70-75` 构造）
#   ⇒ 一张皮 + 运行时滤镜：悬停 `getLightFilter(+30)`、按下 `−40`、禁用 `getGrayFilter()`。
#   Godot 侧的形态是**换 `texture_normal` / 指 `texture_disabled`**，不是挂 material
#   （material 会被子节点继承、且不是工程既有那条路）⇒ 派生皮由
#   `开发工具/生成首领钮态图.py` 烘进 `专用控件/分页<名>_{悬停,按下,灰}.png`
#   （常态皮是**共享**件，派生件不许倒回 `通用控件/`）。
#   悬停/按下两档运行期 `load()`，场景里只钉得住 `texture_disabled` 那一档。
for 主干 in ("首页", "上一页", "下一页", "末页"):
    图["分页%s灰" % 主干] = ("专用控件/分页%s_灰.png" % 主干, [0, 0, 0, 0])
for i in range(11):
    图["头像%d" % i] = (首领 + "Effect_Wang_%d.png" % i, [0, 0, 0, 0])
缺 = [k for k, (p, _) in 图.items() if not os.path.exists(os.path.join(工程, "素材", "界面", p))]
if 缺:
    print("!! 素材缺失:", 缺)
    sys.exit(1)
扩展id = {k: "t%d" % i for i, k in enumerate(图)}

橙 = "Color(1, 0.568627, 0, 1)"      # UIConfig.UI_ORANGE #FF9100（UIConfig.as:928）
白 = "Color(1, 1, 1, 1)"             # UI_WHITE #FFFFFF（:924）
绿 = "Color(0, 1, 0, 1)"             # UI_GREEN #00FF00（:930）
桃 = "Color(0.988235, 0.764706, 0.6, 1)"   # 16565145 = #FCC399（WangBossCell 四个标签的字面色）


def 文(字, 色, 对齐=0, 号=12, 粗=False, 可点=False):
    """MLabel 烘焙：件矩形照 AS3 声明烘；AS3 的 `textField.y=2`（MLabel.as:206-207）
    用 `vertical_alignment = 1` 逼近（12px 宋体行高≈16 ⇒ 居中顶偏移≈2）。"""
    串 = ("theme_override_font_sizes/font_size = %d" % 号 + NL
          + "theme_override_colors/font_color = %s" % 色 + NL
          + "vertical_alignment = 1" + NL
          + "horizontal_alignment = %d" % 对齐 + NL)
    if 粗:
        串 += "theme_override_font_flags/font = 4" + NL      # Font.FLAG_BOLD（PageComponent:141 bold=true）
    if 可点:
        串 += "mouse_filter = 0" + NL                        # 原版 mapText 挂了 CLICK（WangBossCell:215）
    return 串 + 'text = "%s"' % 字 + NL


# ── 数据侧（与量具 `卡值()` 同一套公式，两边互为对照）──
王 = json.load(io.open(os.path.join(工程, "数据", "原版杂项.json"), encoding="utf-8"))["BossWang"]["boss"]
怪 = json.load(io.open(os.path.join(工程, "数据", "怪物.json"), encoding="utf-8"))
图名 = json.load(io.open(os.path.join(工程, "数据", "地图名.json"), encoding="utf-8"))
文案 = {k: v["值"] for k, v in json.load(io.open(
    os.path.join(工程, "数据", "界面", "首领_文案.json"), encoding="utf-8"))["文案"].items()}


星位 = 7   # 每卡烘满 7 枚星位（原版最多 6 实 + 1 空），用不到的 visible=false


def 星段(索引):
    """`dropStars.split(".")`（WangBossCell:299-316）：点号前 = 实心枚数，有小数段再补 1 枚空心。
    本工程 JSON 把它导成了数字、且 Godot 的 JSON 一律解成 float（`str(3)` = "3.0"），
    所以按等价的数值口径：实心 = floor(值)，小数 > 0 再补一枚空心 —— 11 条真实数据两种口径逐条相同。"""
    值 = float(王[str(索引)]["dropStars"])
    实 = int(值)
    return 实, (1 if 值 - 实 > 1e-9 else 0)


def 卡文本(卡, 件名):
    行 = 王[str(首页索引[卡])]
    if 件名 == "名称":                      # :99 StringTool.getMobString(mobid)
        return 怪[str(行["mobid"])]["name"]
    if 件名 == "类型":                      # :100 param1.levelDesc
        return 行["levelDesc"]
    if 件名 == "等级数值":                  # :101 CN.replaceString(WANG_BOSS_CELL_JI, info.level)
        return 文案["WANG_BOSS_CELL_JI"].replace("%1", str(怪[str(行["mobid"])]["level"]))
    if 件名 == "地图数值":                  # :102 StringTool.getMapString(mapid)
        return 图名[str(行["mapid"])]
    if 件名 == "时间数值":                  # :105 alive=true ⇒ WANG_BOSS_NOT_DIED（真值表 §6.1）
        return 文案["WANG_BOSS_NOT_DIED"]
    raise KeyError(件名)


# ── 相对路径 → (类型, 贴图键, 附加属性, 初值不可见)；顺序即原版 addChild 顺序 ──
路径规格 = {"外框黄底": ("Panel", "黄底", None, False)}
for 卡 in range(3):
    前 = "卡片_%d" % 卡
    路径规格[前] = ("Control", None, "mouse_filter = 2" + NL, False)
    路径规格[前 + "/卡片底"] = ("Panel", "子面板", None, False)          # Cell:141
    # 头像底 = 简介 tooltip 的宿主（`Cell:133` 挂的是 potraitBg）⇒ **必须吃鼠标**。
    # Panel 默认 PASS 也能进 hover，但"能不能悬到"不该留给默认值 ⇒ 显式 STOP。
    路径规格[前 + "/头像底"] = ("Panel", "头像底", "mouse_filter = 0" + NL, False)  # Cell:145
    路径规格[前 + "/头像底/头像"] = ("TextureRect", "头像%d" % 首页索引[卡], None, False)  # Cell:96
    路径规格[前 + "/序号"] = ("Label", None, 文("", 白, 2), False)       # Cell:152 恒空
    路径规格[前 + "/名称"] = ("Label", None, 文(卡文本(卡, "名称"), 橙), False)
    路径规格[前 + "/类型"] = ("Label", None, 文(卡文本(卡, "类型"), 橙), False)
    路径规格[前 + "/信息底"] = ("Panel", "子面板", None, False)          # Cell:178
    路径规格[前 + "/等级标签"] = ("Label", None, 文(文案["WANG_BOSS_CELL_LEVEL"], 桃), False)
    路径规格[前 + "/等级数值"] = ("Label", None, 文(卡文本(卡, "等级数值"), 白), False)
    路径规格[前 + "/地图标签"] = ("Label", None, 文(文案["WANG_BOSS_REFURBISH_MAP"], 桃), False)
    # 原版 :207-208 new 了个 underline 的 TextFormat 却**从没 setTextFormat 上去** ⇒ 实际不划线
    路径规格[前 + "/地图数值"] = ("Label", None, 文(卡文本(卡, "地图数值"), 绿, 可点=True), False)
    路径规格[前 + "/时间标签"] = ("Label", None, 文(文案["WANG_BOSS_REFURBISH_TIMER"], 桃), False)
    路径规格[前 + "/时间数值"] = ("Label", None, 文(卡文本(卡, "时间数值"), 白), False)
    路径规格[前 + "/爆率标签"] = ("Label", None, 文(文案["WANG_BOSS_INSTRUCTION"], 桃), False)
    路径规格[前 + "/挑战钮"] = ("TextureButton", "挑战", None, False)     # Cell:240
    路径规格[前 + "/星级"] = ("Control", None, "mouse_filter = 2" + NL, False)  # Cell:298-322
    实, 空 = 星段(首页索引[卡])
    for i in range(星位):
        键 = "空星" if i == 实 and 空 else "星"
        路径规格["%s/星级/星_%d" % (前, i)] = ("TextureRect", 键, None, i >= 实 + 空)
路径规格["分页"] = ("Control", None, "mouse_filter = 2" + NL, False)      # Window:61-65
# 烘的是**第 1 页** ⇒ `PageComponent.setBtnEnabled:102-120`：首/上 disabled、下/末 可点。
禁用钮 = {"首页", "上一页"}
可点钮 = {"下一页", "末页"}
for 名, 键 in [("首页", "首页"), ("上一页", "上一页"), ("下一页", "下一页"), ("末页", "末页")]:
    路径规格["分页/" + 名] = ("TextureButton", 键, None, False)
总页 = -(-len(王) // 每页条数)
路径规格["分页/页码"] = ("Label", None, 文("1/%d" % 总页, 白, 1, 粗=True), False)

节点 = {根: {"父": "", "矩": [0, 0, 573, 295]}}
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
    加(路, 件期望.get(名))
    if 名 in 件文案 and 件文案[名] not in 文案:
        print("!! 文案表缺键:", 件文案[名]); sys.exit(1)
for 相 in 路径规格:
    if 相 not in [路[len(根) + 1:] for 路 in 节点]:
        print("!! 路径规格里的件没在 件路径 登记:", 相); sys.exit(1)

注释 = [
    '; ── 首领（原版 `com/mxw/uifl/controls/wangBoss/WangBossWindow.as` + `WangBossCell.as`，573×324，整窗 1:1 移植）──',
    '; 本文件由 `开发工具/生成首领场景.py` 从量具表 `截首领页.gd` 的 件路径/件期望/件文案 生成。',
    '; **改真值改量具表再重跑生成器，别手改本文件。** 逐件算式与出处见 `game-client/真值/窗口/首领.md`；',
    '; 场景 y = AS3 窗口局部 y − 29（`窗口尺寸.json` 的「首领」标 `整框: true` ⇒ 容器原点 (0,29)）。',
    '; 外框那圈（MWindow_background）/标题/关闭钮由外壳 `遮罩/主窗口/窗口边框` 画，本页不重复画。',
    '; 11 张首领头像来自运行期包 `swf/Effect/Effect_Wang_<i>.swf`（`PicTool.getWangBossPic`），非 MainLib。',
    '; 三张卡 = 静态表 BossWang.boss 的前三条；alive/nextTime 是服务端字段 ⇒ 烘 alive=true（「未死亡」）。']
def 箱(编号, 键):
    p, 边 = 图[键]
    return (('[sub_resource type="StyleBoxTexture" id="sb_%s"]' + NL
             + 'texture = ExtResource("%s")' + NL
             + 'texture_margin_left = %s' + NL + 'texture_margin_top = %s' + NL
             + 'texture_margin_right = %s' + NL + 'texture_margin_bottom = %s' + NL
             + 'content_margin_left = 0.0' + NL + 'content_margin_right = 0.0' + NL
             + 'content_margin_top = 0.0' + NL + 'content_margin_bottom = 0.0' + NL + NL)
            % ((编号, 扩展id[键]) + tuple(边)))


体 = [箱(键, 键) for 键 in ("黄底", "子面板", "头像底")]
# ⚠ 禁用档**不挂 material**：原版 `MButton3` 禁用是把 `getGrayFilter()` 加在皮肤那一个
#   DisplayObject 上，Godot 侧的等价形态是 `texture_disabled` = 烘好的灰皮
#   （`开发工具/生成首领钮态图.py` 出 `专用控件/分页<名>_灰.png`）。
#   material 会被子节点继承、也不是工程既有的那条路（skill `flash-mbutton3-state-skins`
#   第 2 步两条「不许用」）⇒ 悬停/按下/禁用三档一律**换皮**。
头 = ["[gd_scene load_steps=%d format=3]" % (len(图) + len(体) + 1), NL.join(注释)]
for k, (p, _) in 图.items():
    头.append('[ext_resource type="Texture2D" path="res://素材/界面/%s" id="%s"]' % (p, 扩展id[k]))
头.append('')

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
        类型, 附加, 隐 = "Control", "custom_minimum_size = Vector2(573, 295)" + NL, False
    else:
        相 = 路[len(根) + 1:]
        if not 相:
            continue
        型 = 路径规格.get(相)
        if 型 is None:
            print("!! 路径规格缺:", 相)
            sys.exit(1)
        类型, 键, 附, 隐 = 型
        附 = 附 or ""
        if 键:
            p, 边 = 图[键]
            if 类型 == "Panel":
                assert max(边) > 0, "Panel 必须有九宫格边距: " + 相
                附 = ('theme_override_styles/panel = SubResource("sb_%s")' % 键 + NL + 附)
            elif 类型 == "TextureButton":
                附 = ('texture_normal = ExtResource("%s")' % 扩展id[键] + NL
                     + "ignore_texture_size = false" + NL + "stretch_mode = 0" + NL
                     # `MButton3.init:135` `buttonMode = useHandCursor = true` ⇒ 手型光标。
                     # ⚠ Godot 4 的枚举值：ARROW=0、IBEAM=1、**POINTING_HAND=2**
                     #   （先前写 1 = I 形文本光标，看着"有反馈"其实是错的）
                     + "mouse_default_cursor_shape = 2" + NL + 附)
                # 四枚**都要**烘 `texture_disabled`：哪一枚禁用是运行期按页定的
                #   （第 1 页禁 首/上、末页禁 下/末、中间页全可点）⇒ 灰档得随时拿得出来。
                #   ⚠ 卡片上的「挑战钮」也是 TextureButton，别一起套进来（它没有灰档）。
                if 名 in 禁用钮 or 名 in 可点钮:
                    附 = ('texture_disabled = ExtResource("%s")'
                         % 扩展id["分页%s灰" % 名] + NL + 附)
                if 名 in 禁用钮:
                    附 = "disabled = true" + NL + 附
            else:
                附 = ('texture = ExtResource("%s")' % 扩展id[键] + NL
                     + "expand_mode = 1" + NL + "stretch_mode = 0" + NL + 附)
        附加 = 附
    头注 = '' if 路 == 根 else ' parent="%s"' % (父[len(根) + 1:] if 父.startswith(根 + "/") else ".")
    行.append(模板 % (名, 类型, 头注, ("visible = false" + NL if 隐 else ""), 附加,
                      x - 基[0], y - 基[1], x - 基[0] + w, y - 基[1] + h))

旧 = 出 if os.path.exists(出) else None
if 旧:
    备份 = 出 + ".bak"
    io.open(备份, "w", encoding="utf-8", newline=NL).write(io.open(旧, encoding="utf-8").read())
    旧数 = io.open(旧, encoding="utf-8").read().count('node name=')
文 = NL.join(头) + "".join(体) + NL.join(行)
assert 文.count('node name=') == len(顺序), "节点数与顺序表不符"
# 资源 id 一律 ASCII（Godot 的 scene unique ID 只许 `[A-Za-z0-9_]` 且不以数字开头；
# 中文 id 每加载一次吐一行 ERROR）。见 开发工具/场景id.py。
文 = ascii化(文)
os.makedirs(os.path.dirname(出), exist_ok=True)
io.open(出, "w", encoding="utf-8", newline=NL).write(文)
print("生成 %s：%d 个节点（旧文件 %d 个 node name=，备份 %s）" % (
    os.path.relpath(出, 工程), len(顺序), 旧数 if 旧 else 0, (出 + ".bak") if 旧 else "无"))
