# -*- coding: utf-8 -*-
"""「原版服务窗」通用产线 —— 把 AS3 里那些 `extends UIWindow` 的小功能窗
（忍具兑换 / 十拳剑兑换 / 洗点 / 生命料理 / 徽章打造 / 环任务 / 勾玉炼制 …）
从 SPEC 直接生成 `.tscn`，并烘出钮的三档皮。

## 为什么要通用产线
这批窗**同一套骨架**：`super(w,h,true)` ⇒ `UIWindow.as:36-39` 建 `MYellow_background` 内容底
`(CONTENT_GAP, 38)`、`:62-65` 尺寸 `w - 2*CONTENT_GAP × h - 68`；里面一枚 `MPane_background`；
件用 `setPosition()` 摆、`MButtonF` 走 `UIConfig.btn_width_*` **整帧非等比**（`isScale9Grid=false`）；
文字要么硬编码要么 `LangUtil.get(键)`。一扇一抄 = 必抄错，所以：
**SPEC 里存的是 AS3 表达式原样 + 行号，数字由常量算出来**。

## SPEC 放哪
`数据/界面/原版服务窗_SPEC.json`，键 = 页名（必须与 `数据/界面/窗口尺寸.json` 的键一致 ⇒
对话窗点行才开得出这扇）。每窗：
    类(AS3 类名) 宽 高 皮目录 场景 期望 根名 件[]
每件：名 / 类(panel|tex|sep|box|label|rich|btn) / 父(件名 或 "窗") /
      x y w h（**AS3 表达式原样**，父相对）/ 皮 / 文字 / 色 / 字号 / 对齐 / 出处
      `tex` 额外可带 `物品`(编号) + `图标`(res:// 路径) + `数量` ⇒ 在格内叠
        「数量 Label(0,20,40,20) 右对齐白」+「图标 TextureRect 居中取整」两层（SimpleItemCell 有 itemData 那一态）；
      `label` 可带 `隐藏: true`（nameField 在有 itemData 时 `visible=false`，:302）；
      `rich` 可带 `行距`（= AS3 leading + 2）；负偏移要在 SPEC 里写 `允许负偏移: true`。
坐标约定：树里每条的矩形 = 页面绝对值；只有 `父=="窗"` 的第一层抬 **−29**（`整框` 页原点）。

用法：
    python 开发工具/原版服务窗.py 列表
    python 开发工具/原版服务窗.py 烘皮 忍具兑换
    python 开发工具/原版服务窗.py 生成 忍具兑换
"""
import glob
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from 派生钮态 import 加亮  # noqa: E402

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
元件根 = os.path.join(os.environ.get("NARUTO_ELEMENT_ROOT")
	or os.path.join(os.path.dirname(工程), "原版源数据", "元件图"), "sprites")
SPEC路径 = os.path.join(工程, "数据", "界面", "原版服务窗_SPEC.json")
尺寸路径 = os.path.join(工程, "数据", "界面", "窗口尺寸.json")
皮肤根 = os.path.join(工程, "素材", "界面", "原版窗口")
皮肤目录 = os.path.join(皮肤根, "通用控件")
# ⚠ 底片必须用 **tag18 `MButton_up`**（纯皮肤）。`MButtonF` 那个符号（tag21）是**按钮容器**，
# 里面烙着 Flash 作者期的 "Button" 字样（290 色 vs tag18 的 79 色）⇒ 拿它当皮 = 钮上出现英文字母
# （2026-10-04 用户抓到）。`MButtonF.as` 的 upSkin 指向的就是 tag18。
钮基 = os.path.join(元件根, "DefineSprite_18_MButton_up_MButton_up")

# ── 常量（逐条带出处；动这里 = 动真值，必须同步 真值/窗口/木叶村NPC.md）────────
常量 = {
    "BORDER_GAP": 5.0,        # UIConfig.as:890
    "CONTENT_GAP": 8.0,       # UIConfig.as:892
    "拖动区": 29.0,            # MWindow 顶部拖动区 ⇒ 整框页 场景 y = 窗口 y − 29
    "btn_width_two": 37.0,    # UIConfig.as:964
    "btn_width_four": 61.0,   # UIConfig.as:968
    "btn_width_six": 82.0,    # UIConfig.as:972
    "btn_width_seven": 94.0,  # UIConfig.as（排行钮那一档）
    "钮高": 22.0,              # MButtonF 原生 57×22
    "格边": 40.0,              # SimpleItemCell 的 MGrid_background 原生 40×40
}
# 九宫格边距**只认** `脚本/界面/原版皮肤表.gd`（=《共用件度量表》§13 同源），禁在这里填拟合值。
# ⚠ 2026-10-05：这里原先是**手抄的四行**，注释写着"只认皮肤表"但值不是从它读的 ⇒ 皮肤表改了
#   这一份不会跟（本轮把 `分页未选` 边距按 §4.2 改成 7.25/7/7.5/4.75 时才暴露）。
#   现在真的去解析它：`const 名 := 前缀 + "档.png"` + `九宫格 = { 名: [左,右,上,下], … }`。
def 读皮肤表():
    文 = io.open(os.path.join(工程, "脚本", "界面", "原版皮肤表.gd"), encoding="utf-8").read()
    路径 = dict(re.findall(r'^const\s+(\w+)\s*:=\s*"(res://[^"]*)"', 文, re.M))
    拼 = re.findall(r'^const\s+(\w+)\s*:=\s*(\w+)\s*\+\s*"([^"]*)"', 文, re.M)
    for _ in range(4):		# 素材根 → 通用 → 商城素材 这类链式前缀，迭代几次就够
        动 = False
        for 名, 前, 尾 in 拼:
            if 名 not in 路径 and 前 in 路径:
                路径[名] = 路径[前] + 尾
                动 = True
        if not 动:
            break
    档 = {}		# const 名 → res:// 全路径
    for 名, 前, 尾 in 拼:
        if 尾.endswith(".png") and 名 in 路径:
            档[名] = 路径[名]
    基 = {k: os.path.splitext(v.split("/")[-1])[0] for k, v in 档.items()}
    皮 = {基[k]: v for k, v in 档.items()}		# png 基名 → res:// 全路径
    边 = {}		# png 基名 → [左,右,上,下]
    for 化, 值 in re.findall(r'^\t(\w+):\s*\[([^\]]*)\],', 文, re.M):
        if 化 in 基:
            # 整数值**保持 int**：`texture_margin_left = 11` 与 `= 11.0` 是同一件事，
            # 但会改 .tscn 的字节 ⇒ `原版服务窗回归测试` 的"重跑生成器比对"必红（假红）。
            项 = []
            for x in 值.split(","):
                f = float(x)
                项.append(int(f) if f == int(f) else f)
            边[基[化]] = 项
    if len(边) < 10:
        raise SystemExit("从 原版皮肤表.gd 只解出 %d 条九宫格 ⇒ 解析式过时了，**不许退回手抄**" % len(边))
    return 边, 皮


边距表, 皮路表 = 读皮肤表()


def 皮肤路(名):
    # ⚠ 只有 `res://` 开头的（皮肤表登记的共用皮）才要砍前缀；页本地皮的默认值本身就是
    #   **绝对路径**，一起切片会把 `<盘>:\...` 六个字符削掉 ⇒ 拼出不存在的路径（2026-10-05 自己踩）。
    路 = 皮路表.get(名)
    if 路 is None:
        return os.path.join(皮肤目录, 名 + ".png")
    return os.path.join(工程, 路[len("res://"):]) if 路.startswith("res://") else 路


def 边距(名):
    if 名 not in 边距表:
        raise SystemExit("边距表里没有皮 %r —— 只认 原版皮肤表.gd / 共用件度量表 §13" % 名)
    return 边距表[名]


def 九宫边(名):
    """`panel` / `cell` 烘出来是 `NinePatchRect` ⇒ 认的是 **int** 的 `patch_margin_*`
    （`texture_margin_*` 属于 TextureRect / StyleBoxTexture，写到 NinePatchRect 上
    载入不报错也不落地：底图整片拉伸、四角从没九宫切过 —— 2026-10-20 §3.228 抓到）。
    皮肤表给的是 Flash XML 的分数换算值 ⇒ 这里四舍五入（.5 远离 0），与那 336 行迁移同一口径。"""
    return [int(f + 0.5) if f >= 0 else -int(-f + 0.5) for f in 边距(名)]


def 算(式, 域):
    """只允许 数字 / 已登记的常量与件属性 / `+ - * / ( )`。表达式来自仓库里的 SPEC。"""
    if isinstance(式, (int, float)):
        return float(式)
    s = str(式)
    for 键 in sorted(域, key=len, reverse=True):
        s = s.replace(键, repr(域[键]))
    s = re.sub(r"[^0-9eE+\-*/(). ]", "", s)
    try:
        return float(eval(s, {"__builtins__": {}}, {}))
    except Exception as e:
        raise SystemExit("表达式算不出来：%r → %r（%s）" % (式, s, e))


def 域of(已算, 窗):
    域 = dict(常量)
    域["窗宽"] = float(窗["宽"])
    域["窗高"] = float(窗["高"])
    域["_width"] = float(窗["宽"])
    域["_height"] = float(窗["高"])
    for 名, r in 已算.items():
        域[名 + ".x"] = r["局x"]
        域[名 + ".y"] = r["局y"]
        域[名 + ".w"] = r["w"]
        域[名 + ".h"] = r["h"]
    return 域


def 读SPEC(页):
    # `utf-8-sig`：`数据/界面/窗口尺寸.json` 是 688 个数据文本里**唯一**带 UTF-8 BOM 的
    # （Godot 读得动、`json.load` 读不动 ⇒ 重生 17 页会整批死在尺寸条()）。别去剥数据的皮，改读法。
    全 = json.load(io.open(SPEC路径, encoding="utf-8-sig"))
    if 页 not in 全:
        raise SystemExit("SPEC 里没有 %r，现有：%s" % (页, "、".join(sorted(全))))
    return 全[页]


def 尺寸条(页):
    尺 = json.load(io.open(尺寸路径, encoding="utf-8-sig"))
    if 页 not in 尺:
        raise SystemExit("窗口尺寸.json 里没有「%s」⇒ 先加一条（as3/宽/高/标题/整框），落地页才打得开" % 页)
    return 尺[页]


# ── 一、烘钮：MButtonF = 一张 upSkin + 运行时加性滤镜 ⇒ 只能预烘三档 ────────────
def 烘一枚(目, 名, 宽, 高):
    """MButtonF 族的一张皮 → `<名>.png` + `_悬停`(+30) + `_按下`(−40)，逐字节回读自检。

    `isScale9Grid=false` ⇒ **整帧非等比拉伸**（先拉到目标宽高再烘，顺序不能反）。
    运行期才建的钮（例：兑换商店格子里那颗 80×22「兑换」）也走这里 ⇒ 单独给一个命令，
    别让页面上的第 N 颗钮去复用别档宽的皮。
    """
    底片 = sorted(glob.glob(钮基 + "/*.png"))
    if not 底片:
        raise SystemExit("查不到 MButtonF 底片：%s*" % 钮基)
    源 = Image.open(底片[0]).convert("RGBA")
    # 布防：作者期带文字的容器符号（tag21 `MButtonF` = 290 色，图里写着 "Button"）一旦被换回来，
    # 颜色数会暴涨 ⇒ 这条把"钮上冒出英文字母"变成打包期就红，而不是等用户看图。
    色数 = len(源.getcolors(maxcolors=99999) or [])
    if 色数 > 120:
        raise SystemExit("钮底片颜色数 %d > 120 ⇒ 八成拿成了带作者期文字的容器符号（%s）；"
                         "纯皮肤应是 MButton_up(tag18)，实测 79 色" % (色数, 底片[0]))
    os.makedirs(目, exist_ok=True)
    底 = 源.resize((宽, 高), Image.NEAREST)
    for 后缀, 偏移 in (("", 0), ("_悬停", 30), ("_按下", -40)):
        像 = 底.copy()
        if 偏移:
            像.putdata(加亮(list(底.getdata()), 偏移))
        路 = os.path.join(目, "%s%s.png" % (名, 后缀))
        像.save(路)
        if 偏移:
            回 = Image.open(路).convert("RGBA")
            if list(回.getdata()) != list(像.getdata()):
                raise SystemExit("派生态回读不等：" + 路)
    print("  %-24s %d×%d 三态齐（+30 / −40 逐字节等于公式）" % (名 + ".png", 宽, 高))


def 烘皮(页):
    窗 = 读SPEC(页)
    目 = os.path.join(皮肤根, 窗["皮目录"])
    派过 = set()
    for 件 in 窗["件"]:
        if 件["类"] != "btn":
            continue
        尺 = (int(round(算(件.get("w", 常量["btn_width_four"]), 域of({}, 窗)))),
             int(round(算(件.get("h", 常量["钮高"]), 域of({}, 窗)))))
        if 件.get("皮"):
            # 给了 `皮` 分两种族，**只有第二种要烘**：
            #  (a) 每态一张真皮（`MButton` / 跨服那族 `ChannelButtonF` = cid 652/655/658）
            #      ⇒ 三张都从库里现导，**绝不许烘**（烘一次就把真皮覆盖成假的，还看不出来）。
            #  (b) `MButton3` 血统的**纯图钮**（`MPlusBtnF`/`MMinusBtnF`/`MArrowBtnF` 这种只有
            #      upSkin、悬停/按下是运行时 ColorMatrix ±30/−40）⇒ up 是真皮、另两档**必须派生**，
            #      否则生成器按 `<皮>_悬停/_按下` 找皮就直接报"皮不存在"（2026-10-06 洗点那四颗撞到）。
            #      用 `派生: true` 显式声明，不靠猜。
            if not 件.get("派生"):
                continue
            if 件["皮"] in 派过:
                continue        # 同一张皮被多枚钮共用（洗点四行的「全收钮」）⇒ 只烘一次
            派过.add(件["皮"])
            烘一枚(目, 件["皮"], *尺)
            continue
        烘一枚(目, 件["名"], *尺)


# ── 二、生成 .tscn ────────────────────────────────────────────────────────────
def 节点名(名):
    # ⚠ 节点名里**不许出现 `/`** —— 它是 Godot 的路径分隔符，
    # SPEC 用 `格/名` 这种层级名只是为了人读，落到 .tscn 必须转成 `格_名`，
    # 否则 `parent="格/名"` 解析不到、件会被挂到根节点 (0,0) 上（2026-10-04 用户抓到）。
    return str(名).replace("/", "_")


def _色(十六):
    十六 = str(十六).lstrip("#")
    return ", ".join("%.6f" % (int(十六[k:k + 2], 16) / 255.0) for k in (0, 2, 4))


def _串(文):
    """→ `.tscn` 里一行放得下的字符串字面量。
    原版文案里带真换行（`String.RenJu[…].desc` 里有 `\\n`），原样写进场景会把一行劈成两行、
    整个节点块解坏 ⇒ 转成 `\\n` 两字符，Godot 读回来仍是换行。"""
    return (str(文).replace('"', "'").replace("\r\n", "\n")
            .replace("\n", "\\n").replace("\t", "\\t"))


_尺缓存 = {}


def 图尺寸(res路):
    """物品图标的原生尺寸 —— AS3 的居中偏移要用真实宽高，不能假定 34。"""
    盘 = os.path.join(工程, res路[len("res://"):]) if res路.startswith("res://") else res路
    if 盘 not in _尺缓存:
        with Image.open(盘) as 像:
            _尺缓存[盘] = 像.size
    return _尺缓存[盘]


def 生成(页):
    """SPEC → `.tscn` + 期望表 json。块序固定：ext → sub → 根 → 件。"""
    窗 = 读SPEC(页)
    规 = 尺寸条(页)
    if int(规["宽"]) != int(窗["宽"]) or int(规["高"]) != int(窗["高"]):
        raise SystemExit("SPEC 尺寸(%sx%s) 与 窗口尺寸.json(%sx%s) 不一致"
                         % (窗["宽"], 窗["高"], 规["宽"], 规["高"]))
    抬 = float(常量["拖动区"]) if 规.get("整框") else 0.0
    目 = os.path.join(皮肤根, 窗["皮目录"])

    域 = {}
    for 件 in 窗["件"]:
        名, 父 = 件["名"], 件.get("父", "窗")
        局 = {"x": 算(件.get("x", 0), 域of(域, 窗)), "y": 算(件.get("y", 0), 域of(域, 窗)),
              "w": 算(件.get("w", 0), 域of(域, 窗)), "h": 算(件.get("h", 0), 域of(域, 窗))}
        绝 = dict(局)
        if 父 == "窗":
            绝["y"] -= 抬
        else:
            if 父 not in 域:
                raise SystemExit("件 %s 的父 %s 还没算（AS3 里父必须先 addChild）" % (名, 父))
            绝["x"] = 域[父]["x"] + 局["x"]
            绝["y"] = 域[父]["y"] + 局["y"]
            if 局["x"] < -0.01 or 局["y"] < -0.01:
                if not 件.get("允许负偏移"):
                    raise SystemExit("件 %s 在父 %s 里是负偏移（表达式或父搞错了；"
                                     "确属原版几何的要在 SPEC 里写 允许负偏移: true 并在出处给行号）"
                                     % (名, 父))
        绝["局x"], 绝["局y"], 绝["父"] = 局["x"], 局["y"], 父
        # ⚠ `.tscn` 的 `parent=` 是**从场景根算的完整路径**（`"."` = 根）。
        #    只写件名 ⇒ 嵌套件（格里的名字）解析不到父节点、被静默挂到根 (0,0) 上
        #    （2026-10-04 用户抓到「界面完全不对」的第一半根因）。
        绝["路径"] = 节点名(名) if 父 == "窗" else 域[父]["路径"] + "/" + 节点名(名)
        域[名] = 绝

    外, sub, 节 = [], [], []
    n = [0]
    b = [0]
    灰识 = [None]
    皮识 = {}		# 路径 → ext_resource id（**同一张图只登记一次**，见下面 加皮）

    def 加灰材():
        # `ItemCaiLiaoBox.applyGrayFilter()` ⇒ `itemCell.filters = Style.getDisableFilter()`
        # （Style.as:63-65 的 ColorMatrix = 亮度 0.3086/0.6094/0.082，与 禁用灰度.gdshader 同系数）。
        # 挂在**格**这一层 ⇒ Godot 的 CanvasItem 材质被子节点继承 ⇒ 图标与数量一起灰，
        # 与 Flash「滤镜挂在 itemCell 这个 DisplayObject 上、整棵子树受影响」一致。
        # ⚠ id 必须是**纯 ASCII**：`[sub_resource id="mat_禁用灰度"]` 会让加载器报
        #   `The scene unique ID must contain only letters, numbers, and underscores` 并**静默丢掉材质**
        #   （2026-10-04 灰度不生效的根因；同一理由把 stylebox 的 id 也换成 `sb<序号>_槽`）。
        if 灰识[0] is None:
            外.append('[ext_resource type="Shader" path="res://脚本/界面/组件/禁用灰度.gdshader" id="sh1"]')
            sub.append("\n".join([
                '[sub_resource type="ShaderMaterial" id="mat1"]',
                'render_priority = 0',
                'transparency = 0',
                'shader = ExtResource("sh1")']))
            灰识[0] = "mat1"
        return 灰识[0]

    def 加皮(路):
        # `res://` 开头的（物品图标这类库件）直接按工程相对路径查盘，不拼皮目录
        相 = 路[len("res://"):] if 路.startswith("res://") else 路[len(工程) + 1:]
        盘 = os.path.join(工程, 相)
        if not os.path.isfile(盘):
            raise SystemExit("皮不在盘上：%s（btn/cell 要先跑 烘皮）" % 盘)
        键 = 相.replace(os.sep, "/")
        # ⚠ **按路径去重**：跨服那 32 枚频道格全是同一个符号（charId 659）的三态皮 ⇒
        #   不去重就是 96 条 ext_resource 指 3 个文件（Godot 不报错，但改图要改 96 处、
        #   场景白胖一截）。行为门的「皮只登记 3 条」那条判据钉的就是这里。
        if 键 in 皮识:
            return 皮识[键]
        n[0] += 1
        识 = "t%d" % n[0]
        皮识[键] = 识
        外.append('[ext_resource type="Texture2D" path="res://%s" id="%s"]'
                  % (键, 识))
        return 识

    def 格内层(件, r, 灰):
        """`SimpleItemCell` 压在格底之上的那两层（`tex` 与 `cell` **共用**）。

        ⚠ 2026-10-06 之前这段只写在 `tex` 分支里 ⇒ `cell` 件上 SPEC 明明写了 `数量`，
        生成器一声不响地丢掉（生命料理那三枚「空格角标」全没了而门还是绿的）。
        `cell` 与 `tex` 在 AS3 里是同一个 `SimpleItemCell`，只是 Godot 侧一个用
        NinePatchRect（九宫格皮）一个用 TextureRect ⇒ 内层必须两边都出。
        """
        if 件.get("数量"):
            # `件["数量"]` 两种写法：**字符串** = `SimpleItemCell.countLabel`（格内 (0,20)
            # 40×20 右对齐，`SimpleItemCell.as:136-144`）；**字典** = 页专用格的角标，
            # 例如 `KapianItemCell.as:28-44` 的 tf 在 (1,24) 37×16、autoSize RIGHT ⇒ 左对齐。
            数 = 件["数量"] if isinstance(件["数量"], dict) else {"文字": 件["数量"]}
            偏x = 数.get("x", 0)
            偏y = 数.get("y", 20)
            框数 = "\n".join(["layout_mode = 0",
                            "offset_left = %s" % 偏x, "offset_top = %s" % 偏y,
                            "offset_right = %s" % (偏x + 数.get("w", r["w"])),
                            "offset_bottom = %s" % (偏y + 数.get("h", 20))])
            数块 = ['[node name="%s_数量" type="Label" parent="%s"]'
                    % (节点名(件["名"]), r["路径"])]
            if 灰:
                数块.append('material = SubResource("%s")' % 灰)
            数块 += ['text = "%s"' % _串(数.get("文字", "")),
                "theme_override_colors/font_color = Color(1, 1, 1, 1)",
                "theme_override_font_sizes/font_size = 12",
                "horizontal_alignment = %d" % {"left": 0, "center": 1, "right": 2}
                .get(数.get("对齐", "right"), 0),
                "mouse_filter = 2", 框数]
            节.append("\n".join(数块))
        if 件.get("图标"):
            宽, 高 = 图尺寸(件["图标"])
            偏x = int(round((r["w"] - 宽) / 2.0))
            偏y = int(round((r["h"] - 高) / 2.0))
            识图 = 加皮(件["图标"])
            框图 = "\n".join(["layout_mode = 0",
                            "offset_left = %d" % 偏x, "offset_top = %d" % 偏y,
                            "offset_right = %d" % (偏x + 宽), "offset_bottom = %d" % (偏y + 高)])
            图块 = ['[node name="%s_图标" type="TextureRect" parent="%s"]'
                    % (节点名(件["名"]), r["路径"])]
            if 灰:
                图块.append('material = SubResource("%s")' % 灰)
            图块 += ['texture = ExtResource("%s")' % 识图,
                    "expand_mode = 1", "mouse_filter = 2", 框图]
            节.append("\n".join(图块))

    for 件 in 窗["件"]:
        类, 名 = 件["类"], 件["名"]
        字 = str(件.get("文字", ""))
        if "<" in 字 or "</" in 字:
            # AS3 的 `TextArea2.htmlText` 用的是 `<font color="#00ff00">`，而 Godot 的
            # RichTextLabel 只认 BBCode ⇒ 原样塞进去会把标签当正文画出来（2026-10-04 被用户抓到）。
            # SPEC 里必须**先换成 `[color=#00ff00]…[/color]`**，AS3 原句留在 `出处` 里。
            raise SystemExit("件 %s 的文字里还有 HTML 标签（要写成 BBCode）：%s" % (名, 字[:60]))
        r = 域[名]
        落父 = "." if r["父"] == "窗" else r["路径"].rsplit("/", 1)[0]
        # ⚠ `.tscn` 的 `parent=` 是**从场景根算的完整路径**（不是"上一个节点的儿子"）——
        #    写相对名会静默挂到根上、整块子树看不见（本工程踩过两次；这次是 `条` 的 底/裁剪/填充
        #    与 `滚动区` 的 内容，症状都是"instantiate 出来子节点 = 0"）。
        件路 = r["路径"]
        # 顶层件写的是**页面**坐标（−29 已抬），嵌套件写的是**父相对**（就是 AS3 的局域值）
        px, py = (r["x"], r["y"]) if r["父"] == "窗" else (r["局x"], r["局y"])
        框 = "\n".join(["layout_mode = 0",
                       "offset_left = %s" % px, "offset_top = %s" % py,
                       "offset_right = %s" % (px + r["w"]), "offset_bottom = %s" % (py + r["h"])])
        if 类 in ("box", "panel", "tex", "sep", "cell"):
            if 类 == "box":
                # `ItemCaiLiaoBox` 这类容器自己**没有皮、也没有默认尺寸**：`BUI.as:12` 的 `_width`
                # 不初始化（=0），只有 AS3 里显式 `.width = 40` 才变。所以里面的
                # `SimpleItemCell`（物品格 40×40）按 `(_width − 40)/2` 摆 ⇒ **不给宽的容器，格在 −20**。
                # 曾经我把容器当 56×88 居中 ⇒ 主格右移 28px（2026-10-04 用户打回「跟原版不一致」）。
                块 = ['[node name="%s" type="Control" parent="%s"]' % (节点名(名), 落父),
                      "mouse_filter = 2"]
                # `裁剪: true` = AS3 那层 `Sprite.scrollRect = new Rectangle(0,0,w,h)`
                # （变身卡互换的两块立绘窗就是这种"有框没皮、内容超出就裁"的容器）。
                if 件.get("裁剪"):
                    块.append("clip_contents = true")
                if 件.get("隐藏"):
                    块.append("visible = false")
                块.append(框)
                节.append("\n".join(块))
                continue
            皮 = 件["皮"]
            if str(皮).startswith("res://"):
                # 复用**别的页/共用目录**里已有的图（卡片套册那四枚 `属性箭头左/右.png` 在
                # `素材/界面/专用控件/`，与洗点窗共用）⇒ 绝不能再拷一份进本页皮目录，
                # 否则同一张图两份，改一处漏一处。
                识 = 加皮(皮)
            else:
                识 = 加皮(皮肤路(皮) if 皮 in 边距表 else os.path.join(目, 皮 + ".png"))
            边9 = 九宫边(皮) if 皮 in 边距表 else [0, 0, 0, 0]
            if 类 in ("panel", "cell"):
                块 = ['[node name="%s" type="NinePatchRect" parent="%s"]' % (节点名(名), 落父)]
                # `灰化` 对格（NinePatchRect）同样成立：`ItemCaiLiaoBox.as:40-43` 是把
                # `Style.getDisableFilter()` 挂在 **itemCell 本身** ⇒ Godot 的 CanvasItem 材质
                # 被子节点继承，运行期塞进来的图标与数量跟着一起灰（材料4 那一枚）。
                灰 = 加灰材() if 件.get("灰化") else None
                if 灰:
                    块.append('material = SubResource("%s")' % 灰)
                块 += ['texture = ExtResource("%s")' % 识,
                        "patch_margin_left = %d" % 边9[0], "patch_margin_right = %d" % 边9[1],
                        "patch_margin_top = %d" % 边9[2], "patch_margin_bottom = %d" % 边9[3]]
                # `隐藏: true` 对格/面板同样成立 —— 护送那五枚 `IconSelected` 选中框就是
                # 「运行期才显形」的件（`HuSongItemCell.as:93` `visible = (richDegree == id)`）：
                # 不烘成 false，编辑器里五枚框全亮着，与原版开窗那一帧不一致（编辑器 = 运行期）。
                if 件.get("隐藏"):
                    块.append("visible = false")
                块.append(框)
                节.append("\n".join(块))
                # `cell` = AS3 的 `SimpleItemCell`（`panel` 只是底板）⇒ 格里的数量角标/图标
                # 两层要照 `tex` 一样出。**2026-10-06 抓到的漏**：这段以前只写在 tex 分支里，
                # `cell` 件上 SPEC 明明写了 `数量: " "`（`hideIcon` 那格），生成器一声不响地
                # 丢掉，而几何门只看 12 件的矩形 ⇒ 一直是绿的。
                if 类 == "cell":
                    格内层(件, r, 灰)
            else:
                格块 = ['[node name="%s" type="TextureRect" parent="%s"]' % (节点名(名), 落父)]
                灰 = 加灰材() if 件.get("灰化") else None
                if 灰:
                    格块.append('material = SubResource("%s")' % 灰)
                # `可悬停` = 原版这颗格 `buttonMode = true`（`KapianItemCell.setCellValue` 里
                # `this.buttonMode = true` + ENTER_FRAME 弹 `MToolTipItem`）⇒ 必须 STOP 才吃得到鼠标。
                格块 += ['texture = ExtResource("%s")' % 识,
                        "mouse_filter = %d" % (0 if 件.get("可悬停") else 2)]
                # ⚠ `sep`（= 原版 `LineHPicF`，`extends Sprite` 整帧**非等比**拉伸）必须显式
                #   `expand_mode = 1` + `stretch_mode = 0`：TextureRect 默认 `expand_mode = 0`
                #   会**按纹理原生尺寸自己撑**（横向分隔线原生 252 宽），声明的 244/311/320/331 被吃掉
                #   ⇒ 那条线比原版短一截（2026-10-05 用户实机图打回「分隔线不对」的第二层）。
                #   格（`tex`，物品格 40×40 原生 = 声明）不动它，免得连累别的页。
                if 类 == "sep":
                    格块 += ["expand_mode = 1", "stretch_mode = 0"]
                格块.append(框)
                节.append("\n".join(格块))
                # `SimpleItemCell` 的图标/数量两层与 `cell` 共用一份实现（见 格内层）。
                格内层(件, r, 灰)
        elif 类 == "btn":
            b[0] += 1
            号 = "sb%d" % b[0]
            # ⚠ 皮的基名**默认 = 件名**（一页里每颗钮各一张皮，`烘钮` 按件名烘三档）；
            #   但有些件是「同一个符号复用 N 次」—— 跨服那 33 枚频道格全是 `ChannelButtonF`
            #   (charId 659) 的三张态皮（up=652 / over=655 / down=658，实测互不相同、
            #   且 disabledSkin 与 upSkin 是**同一个 652**）⇒ 这类件在 SPEC 里显式给 `皮`，
            #   皮由 `flash-swf-asset-probe` 从元件图**原样拷**，`烘钮` 一律跳过（见 烘钮 那条守卫）。
            皮名 = str(件.get("皮", 名))
            态后 = ["", "_悬停", "_按下"]
            # `MButtonF extends MButton3`（`MButtonF.as` 整只 15 行、一个成员都不加）⇒
            # 禁用态是**运行时 getGrayFilter 染 upSkin**，不是另一张皮 ⇒ 派生态一律预烘
            # （口径同 `flash-mbutton3-state-skins`：三档换皮、不挂 material）。
            # ⚠ 但 `MButton` 族（`SelectedChannelCell extends MButton`）是**每态一张皮**：
            #   它的禁用态在符号表里就有 `disabledSkin`，这张皮**不许烘**（烘 = 造美术）。
            #   `禁用同常态: true` 就是"库里 disabledSkin 与 upSkin 是同一个 characterId"的写法。
            if os.path.isfile(os.path.join(目, 皮名 + "_禁用.png")):
                态后.append("_禁用")
            识 = [加皮(os.path.join(目, 皮名 + 后 + ".png")) for 后 in 态后]
            有禁用 = "_禁用" in 态后
            for 槽, 识名 in zip(["n", "h", "p", "d"], 识):
                sub.append("\n".join([
                    '[sub_resource type="StyleBoxTexture" id="%s_%s"]' % (号, 槽),
                    'texture = ExtResource("%s")' % 识名]))
            色 = _色(件.get("色", "#fcf49c"))
            块 = ['[node name="%s" type="Button" parent="%s"]' % (节点名(名), 落父),
                  'theme_override_styles/normal = SubResource("%s_n")' % 号,
                  'theme_override_styles/hover = SubResource("%s_h")' % 号,
                  'theme_override_styles/pressed = SubResource("%s_p")' % 号,
                  'text = "%s"' % _串(件.get("文字", "")),
                  "horizontal_alignment = 1",
                  "theme_override_colors/font_color = Color(%s, 1)" % 色,
                  "theme_override_colors/font_hover_color = Color(%s, 1)" % 色,
                  "theme_override_colors/font_pressed_color = Color(%s, 1)" % 色,
                  "mouse_default_cursor_shape = 2"]
            if 有禁用:
                # `MButton3.as:69-74` `_textColors[STATE_DISABLED]` = #939393
                块.append('theme_override_styles/disabled = SubResource("%s_d")' % 号)
                块.append("theme_override_colors/font_disabled_color = Color(0.576, 0.576, 0.576, 1)")
            elif 件.get("禁用同常态"):
                # 符号表里 `disabledSkin` 与 `upSkin` 是**同一个 characterId**（跨服频道格：
                # 两者都是 cid 652）⇒ 禁用槽指回常态那张皮，**不另存一份文件**（存两份必漂）。
                # 字色另给：`SelectedChannelCell.as:33` `disabledTextColor = 7434344` = #717068。
                块.append('theme_override_styles/disabled = SubResource("%s_n")' % 号)
                块.append("theme_override_colors/font_disabled_color = Color(%s, 1)"
                           % _色(件.get("禁用字色", "#717068")))
            if 件.get("可切换"):
                # MButton 的 `selected` ⇒ `backs["selectedUpSkin"]`。频道格的 selectedUpSkin
                # 与 downSkin 是同一个 cid 658 ⇒ Godot 侧等价物就是 toggle 按钮的 pressed 槽。
                块.append("toggle_mode = true")
            if 件.get("禁用态"):
                块.append("disabled = true")		# 开屏态（编辑器 = 运行期第一帧）
            块.append(框)
            节.append("\n".join(块))
        elif 类 == "页签":
            # AS3 `TabButtonBar(MTabButtonF)`：`MTabButtonF`(charId 123) 是 `MTabButton` 的空子类，
            # 页签机制三条都来自 `MTabButton.as`（度量表 §4.1/§4.2）：
            #   ① `set enabled(v)` 里 `selected = !v` ⇒ **选中那枚走 disabled 槽**，显示
            #      `selectedUpSkin` = tag118 `MTabButton_disabled`（名字坑：它就是选中样式，不是禁用样式）；
            #   ② 子类重写的 `updateState()` 对 DISABLED 推的是 `skinFilters[STATE_UP]` = **+0**
            #      ⇒ 选中态**不灰**、原色显示；
            #   ③ `:12` 把 up/over/down/disabled 四档字色赋成**同一个** #FCF49C ⇒ 换态不换字色。
            # 皮四张都在 `通用控件/`（未选 / 未选_悬停(+30) / 未选_按下(−40) / 选中），
            # 边距只认皮肤表（§4.2 的 7.25/7/7.5/4.75 与 8.75/9/8.25/3.5）——
            # ⚠ 页签宽 = 字宽 + 6（`MButton3.measure` 的 isScale9Grid 分支）⇒ 原生 39 必然被拉伸，
            #   边距取错就是端帽变形（2026-10-05 用户打回「面板样子太差劲」后补的口径）。
            b[0] += 1
            号 = "sb%d" % b[0]
            槽皮 = [("n", "分页按钮未选"), ("h", "分页按钮未选_悬停"),
                    ("p", "分页按钮未选_按下"), ("d", "分页按钮选中")]
            for 槽, 皮名 in 槽皮:
                识名 = 加皮(皮肤路(皮名))
                边 = 边距(皮名)
                # ⚠ `content_margin` 必须显式写 0：StyleBoxTexture 不写时取 **texture_margin**
                #   ⇒ Button 的最小尺寸变成「字宽 48 + 左右边距 14.25 = 62.25」，把真值 54 顶宽
                #   （实测三枚页签 62.25×25.25，整条页签溢出、间距全乱）。原版 `MButton3.measure`
                #   是 `tf.width + 6` ⇒ 文字居中在**整张皮**上，边距只属于九宫格绘制、不属于内容区。
                sub.append("\n".join([
                    '[sub_resource type="StyleBoxTexture" id="%s_%s"]' % (号, 槽),
                    'texture = ExtResource("%s")' % 识名,
                    "texture_margin_left = %s" % 边[0], "texture_margin_right = %s" % 边[1],
                    "texture_margin_top = %s" % 边[2], "texture_margin_bottom = %s" % 边[3],
                    "content_margin_left = 0.0", "content_margin_right = 0.0",
                    "content_margin_top = 0.0", "content_margin_bottom = 0.0"]))
            色 = _色(件.get("色", "#fcf49c"))
            块 = ['[node name="%s" type="Button" parent="%s"]' % (节点名(名), 落父),
                 'theme_override_styles/normal = SubResource("%s_n")' % 号,
                 'theme_override_styles/hover = SubResource("%s_h")' % 号,
                 'theme_override_styles/pressed = SubResource("%s_p")' % 号,
                 'theme_override_styles/disabled = SubResource("%s_d")' % 号,
                 "focus_mode = 0",
                 "toggle_mode = true",
                 'text = "%s"' % _串(字),
                 "horizontal_alignment = 1",
                 # `MTabButton extends MButton3`：`MButton3.init()` `:135` 一句
                 # `buttonMode = useHandCursor = true` ⇒ 页签也是**手型**（不是只有提交钮）。
                 "mouse_default_cursor_shape = 2"]
            for 槽 in ["font_color", "font_hover_color", "font_pressed_color",
                       "font_hover_pressed_color", "font_disabled_color"]:
                块.append('theme_override_colors/%s = Color(%s, 1)' % (槽, 色))
            if 件.get("选中"):
                # 烘进场景的就是运行期第一帧的样子（编辑器 = 运行期）：选中枚 `disabled = true`
                # ⇒ 吃不到悬停/按下，正是原版"选中那枚悬停不变亮"的行为。
                块.append("button_pressed = true")
                块.append("disabled = true")
            块.append(框)
            节.append("\n".join(块))
        elif 类 == "label":
            块 = ['[node name="%s" type="Label" parent="%s"]' % (节点名(名), 落父),
                  'text = "%s"' % _串(件.get("文字", "")),
                  "theme_override_colors/font_color = Color(%s, 1)" % _色(件.get("色", "#ffffff")),
                  "theme_override_font_sizes/font_size = %d" % int(件.get("字号", 12)),
                  "horizontal_alignment = %d" % {"left": 0, "center": 1, "right": 2}
                  .get(件.get("对齐", "left"), 0)]
            if 件.get("隐藏"):
                块.append("visible = false")   # 运行期就不可见（不是"我把它盖住了"）
            if 件.get("不挡鼠标"):
                块.append("mouse_filter = 2")
            块.append(框)
            节.append("\n".join(块))
        elif 类 == "rich":
            # TextArea2 = `Box` 里塞一个 dynamic TextField：`wordWrap=true`、`multiline=true`、
            # `mouseWheelEnabled=false`、字号 12、leading 4（`TextArea2.as:73-87`）
            # ⇒ Godot 侧必须 autowrap + line_separation = leading + 2（见 Skill flash-text-area-geometry-port）。
            块 = ['[node name="%s" type="RichTextLabel" parent="%s"]' % (节点名(名), 落父),
                  'text = "%s"' % _串(件.get("文字", "")),
                  "scroll_active = false", "bbcode_enabled = true", "autowrap_mode = 3",
                  "theme_override_font_sizes/normal_font_size = %d" % int(件.get("字号", 12)),
                  "theme_override_constants/line_separation = %d" % int(件.get("行距", 6))]
            # `TextFormat.align = "center"`（`TextArea2.algin` 那个拼错的 setter）⇒ 文字在盒内居中。
            # 2026-10-05 用户实机图打回：勾玉炼制那两块「本次操作消耗金币…」原版居中、我按左上画。
            if 件.get("对齐"):
                块.append("horizontal_alignment = %d"
                           % {"left": 0, "center": 1, "right": 2}[件["对齐"]])
            if 件.get("色"):
                块.append("theme_override_colors/default_color = Color(%s, 1)" % _色(件["色"]))
            if 件.get("隐藏"):		# 同 `label`：原版运行期才显形的件
                块.append("visible = false")
            块.append(框)
            节.append("\n".join(块))
        elif 类 == "线":
            # **代码画的**分隔线：`graphics.beginFill(UI_ORANGE, 0.5) drawRect(0,0,390,1)`
            # （`UIMain2.as:591-597 / 667-673` 变身卡互换那两条）。它不是 `LineHPicF`(symbol133)
            # 那张图 ⇒ 别拿 `sep` 件类去凑，色与 alpha 都照 AS3 的字面值出 `ColorRect`。
            透 = float(件.get("透明", 1))
            块 = ['[node name="%s" type="ColorRect" parent="%s"]' % (节点名(名), 落父),
                  "mouse_filter = 2",
                  "color = Color(%s, %s)" % (_色(件.get("色", "#ff9100")), 透)]
            if 件.get("隐藏"):
                块.append("visible = false")
            块.append(框)
            节.append("\n".join(块))
        elif 类 == "滚动区":
            # 原版的 `ScrollPane`（`fl.containers.ScrollPane`，V=ON/H=OFF 由页面自己设）。
            # ⚠ Godot 侧 `ScrollContainer` 的**最小宽含滚动条宽** ⇒ 内容宽不能直接写区宽，
            #    否则容器被自己那条滚动条撑宽、条整条画到框外（2026-10-04 用户打回那条根因）。
            #    场景里先按 SPEC 的 `区宽/内容宽/内容高` 摆，运行期一律再由
            #    `原版皮肤表.配原版滚动区()` 把内容宽压成「区宽 − 实测条宽」。
            #    ⚠ 滚动条**本体那张皮走全局 原版主题.tres**（`.tscn` 里没有字面量 ⇒ 闭包/自审都看不见，
            #    口径同 纲手三页/宠物页），宽度实测 19 ≠ 原版 15 的差仍挂在待办 #100。
            节.append("\n".join([
                '[node name="%s" type="ScrollContainer" parent="%s"]' % (节点名(名), 落父),
                "horizontal_scroll_mode = 0",	# H=OFF
                "vertical_scroll_mode = 1",		# V=ON
                框]))
            内宽 = 件.get("内容宽", r["w"])
            内高 = 件.get("内容高", r["h"])
            # ⚠ 这里必须过 `域of(域, 窗)`，不能直接拿第一趟的 `域`：那一本里键是**裸件名 → 矩形字典**，
            #   `算` 的按键长替换会把 `列表面板` 换成整个 dict 的 repr，剩下的 `.w` 被字符过滤削掉
            #   ⇒ 报「表达式算不出来」而几何看起来没错（2026-10-04 兑换商店踩到）。
            局域 = 域of(域, 窗)
            节.append("\n".join([
                '[node name="%s" type="Control" parent="%s"]' % (节点名(名) + "_内容", 件路),
                "mouse_filter = 2",
                "layout_mode = 0",
                "offset_right = %s" % 算(内宽, 局域), "offset_bottom = %s" % 算(内高, 局域),
                "custom_minimum_size = Vector2(%s, %s)" % (算(内宽, 局域), 算(内高, 局域))]))
        elif 类 == "条":
            # `MBarExpF`（`MBar.as`）：`barBg` 整宽、`bar`(填充) 比底窄一个固定内缩、
            # `maskMc` 裁右边、`label` 可选。口径照**已过像素门的宠物页那六根**
            # （`场景/界面/窗口/宠物/宠物窗口.tscn` 的 `经验条`：底 168×11、裁剪 (3,3)-(165,8)、
            #   填充 (-3,-3)-(165,8) ⇒ 内缩 3）。`setBarStartXToZero()` ⇒ 填充从 0 起，不居中。
            缩 = float(件.get("内缩", 3))
            识底 = 加皮(皮肤路(件.get("底皮", "经验条槽")))
            识填 = 加皮(皮肤路(件.get("填充皮", "经验条填充")))
            节.append("\n".join([
                '[node name="%s" type="Control" parent="%s"]' % (节点名(名), 落父),
                "mouse_filter = 2", 框]))
            节.append("\n".join([
                '[node name="底" type="TextureRect" parent="%s"]' % 件路,
                'texture = ExtResource("%s")' % 识底,
                "expand_mode = 1", "layout_mode = 0",
                "offset_right = %s" % r["w"], "offset_bottom = %s" % r["h"]]))
            节.append("\n".join([
                '[node name="裁剪" type="Control" parent="%s"]' % 件路,
                "clip_contents = true", "mouse_filter = 2", "layout_mode = 0",
                "offset_left = %s" % 缩, "offset_top = %s" % 缩,
                "offset_right = %s" % (r["w"] - 缩), "offset_bottom = %s" % (r["h"] - 缩)]))
            节.append("\n".join([
                '[node name="填充" type="TextureRect" parent="%s/裁剪"]' % 件路,
                'texture = ExtResource("%s")' % 识填,
                "expand_mode = 1", "layout_mode = 0",
                "offset_left = %s" % (-缩), "offset_top = %s" % (-缩),
                "offset_right = %s" % (r["w"] - 缩), "offset_bottom = %s" % (r["h"] - 缩)]))
            块 = ['[node name="值" type="Label" parent="%s"]' % 件路,
                  'text = "%s"' % _串(件.get("条文字", "")),
                  "theme_override_font_sizes/font_size = %d" % int(件.get("字号", 12)),
                  "theme_override_colors/font_color = Color(1, 1, 1, 1)",
                  "horizontal_alignment = 1",	# `MBar.tf` 居中压在条上（原版 "0/52" 就印在条里）
                  "mouse_filter = 2",
                  "layout_mode = 0", "offset_right = %s" % r["w"], "offset_bottom = 18"]
            if 件.get("无文字"):
                块.append("visible = false")	 # `bar.label.text = ""` + `_isShowBar = false`
            节.append("\n".join(块))
        else:
            raise SystemExit("未知件类 %r（%s）" % (类, 名))

    头 = "[gd_scene load_steps=%d format=3]" % (1 + len(外) + len(sub))
    根块 = "\n".join([
        '[node name="%s" type="Control"]' % 窗["根名"],
        "layout_mode = 3", "anchors_preset = 0",
        "offset_right = %s" % 窗["宽"], "offset_bottom = %s" % (float(窗["高"]) - 抬)])
    文 = "\n\n".join([头] + 外 + sub + [根块] + 节) + "\n"
    出 = os.path.join(工程, 窗["场景"])
    os.makedirs(os.path.dirname(出), exist_ok=True)
    io.open(出, "w", encoding="utf-8", newline="\n").write(文)
    # 期望表**也必须** `newline="\n"`：在库那批 `.json` 是 LF，而 Windows 上缺省写盘会把 `\n`
    # 翻成 `\r\n` ⇒ 重生一次就凭空脏 17 个文件（内容有差为零、`git status` 全红，§3.228）。
    json.dump({名: [round(r["x"], 2), round(r["y"], 2), round(r["w"], 2), round(r["h"], 2)]
               for 名, r in 域.items()},
              io.open(os.path.join(工程, 窗["期望"]), "w", encoding="utf-8", newline="\n"),
              ensure_ascii=False, indent=1, sort_keys=True)
    print("生成 %s：%d 件、%d 张皮、%d 个 stylebox ⇒ 期望表 %s"
          % (出, len(窗["件"]), len(外), len(sub), 窗["期望"]))
    return 域


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    命 = sys.argv[1] if len(sys.argv) > 1 else "列表"
    if 命 == "列表":
        print("、".join(sorted(json.load(io.open(SPEC路径, encoding="utf-8-sig")))))
    elif 命 == "烘皮":
        烘皮(sys.argv[2])
    elif 命 == "烘钮":
        # 运行期才建的钮（不在 SPEC 里）也要有真皮：`烘钮 <皮目录名> <件名> <宽> <高>`
        烘一枚(os.path.join(皮肤根, sys.argv[2]), sys.argv[3], int(sys.argv[4]), int(sys.argv[5]))
    elif 命 == "生成":
        生成(sys.argv[2])
    else:
        raise SystemExit("用法：原版服务窗.py [列表|烘皮 <页>|烘钮 <皮目录> <名> <宽> <高>|生成 <页>]")
