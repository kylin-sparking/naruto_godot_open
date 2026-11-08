# -*- coding: utf-8 -*-
"""从原版 `asset/effect.swf` 解析 **NPC 头顶三档任务标记** 与 **目标选中箭头** 的注册点与时间轴，
导出逐帧 PNG 并合并进 `数据/特效.json`。

为什么要有这条生产链（而不是手抄一份表）
--------------------------------------
这四枚元件都是 Flash 库里的 **MovieClip**，不是 `Etc.effects` 那种「一帧一张独立位图」：

* `NPCQuestPopup.as:15-36` 按 `NpcQuestStatus` 三档 `new TickMovie()` 再 `motion = "QuestIcon_<档>"`，
  `NPCSprite.as:256-263 / :383-386` 只钉 `x = 0`、`y = -ci.bmd.height - 5` —— 钉的是**注册点**；
* `AbstractLifeObject.as:181-184` 的 `MobMouseOverEffectSkin`（属性名叫 MouseOver，取的其实是
  `MobSelected_Effect_Skin` 那张 —— 名字坑）同理，`Character.as:1458-1471` 钉 `x = 0`、
  `y = -_crtCharHeight - 8`，开关在 `TargetHandler.as:269-273`；
* 注册点在元件库里是作者随手放的，**只能从 SWF 读**。

注册点为什么要「两个来源对出来」，不能只信一边
--------------------------------------------
一开始只按 `shapeBounds` 推（`Xmin/Ymin` = 贴图左上角相对注册点的偏移 —— 这套在
`出小地图标记表.py` 那批**单位图标记**上是对的）。但这里不成立：

* `QuestIcon_1` 形状框 55.0×51.5，ffdec 给的画布却是 **73×70**；`QuestIcon_0` 形状框 60.2×60.2、
  画布 **92×92** —— 差的是元件上挂的 `GLOWFILTER` / `BEVELFILTER`（`-swf2xml` 的产物里查得到），
  ffdec 把滤镜晕出去那圈也画进了画布 ⇒ 「画布左上 == 形状框左上」这个前提直接断掉。
* 反过来只按 PNG 的不透明区推也不行：`MobSelected_Effect_Skin` 的箭头是**同一个形状逐帧平移**
  （`PlaceObject2` 的 move-only 条目 `characterId=None`），漏了这些条目形状框会少 9px 高。

⇒ 两边都要，取**线性对应**：形状框并集 `S=(L,T,R,B)`（元件自身坐标，注册点在 (0,0)）、
  全时间轴不透明区并集 `A=(al,at,ar,ab)`（画布坐标），认定「画出来的字形」就是「几何框里的字形」，
  则注册点在画布里的位置 = `al + (0-L)*(ar-al)/(R-L)`（y 同理）。
  自检钉住 `|A|` 与 `|S|` 每轴差 ≤ 3px —— 超出说明这个对应关系不成立，宁可炸，不要蒙一个数写进表。

时间轴为什么压成「唯一帧 + 每帧停留ms」
--------------------------------------
`TickMovie.tickAnimation`（`TickMovie.as:100-119`）：`frame = pastTime / _frameTime mod totalFrames + 1`，
而 `_frameTime` 的初值是 10（`:21`，`fps` 的 setter 没人调过）⇒ **每帧 10ms、走完回第 0 帧**。
`QuestIcon_0` 时间轴 105 帧但只有 17 段不同画面（首段停 480ms、末段停 420ms）——
按 105 张导会有 88 张重复图白进包。压成「唯一帧 + 停留ms」后周期仍是 105×10=1050ms、
任一时刻抽到的画面与原版逐帧相同，且 `特效播放器.gd` 的「逐帧位图」分支本来就支持 per-frame delay。
自检：段长之和 == 时间轴帧数 × 10ms。

⚠ 另两个坑
1. **ffdec 的 `-swf2xml` 里 DefineShape 用 `shapeId`、DefineSprite 用 `spriteId`、
   PlaceObject2/3 用 `characterId`** —— 三种大小写不同的键，抄成一种会得到「查不到形状」的假阴性。
2. PNG **原样保留 ffdec 的画布**（含滤镜留白），不许自己裁 —— 裁了就等于改美术，
   而且画布尺寸与源件不再逐字节相同，事后没法拿 ffdec 重导来对账。

用法
----
    python 开发工具/出任务标记特效.py            # 写盘 + 自检
    python 开发工具/出任务标记特效.py --干跑     # 只打印，不写盘
"""
import hashlib
import io
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

from PIL import Image

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
特效表路 = os.path.join(工程, "数据", "特效.json")
素材根 = os.path.join(工程, "素材", "特效")

## **钉 2.2.3优化版**（用户令：按 2.2.3优化版 制作，不按 V2.6 分发版）。
## 元件不都在一份 SWF 里：`QuestIcon_*` / `MobSelected_Effect_Skin` 在合并库 `asset/effect.swf`，
## 而 `Effect_PathFindingTip` 是**自带一份 SWF**的（`MCFromDatDefine.as:244-250` 那条分支里
## `swfName = this._effectName` ⇒ 加载的是 `swf/Effect/Effect_PathFindingTip.swf`）。
## 原版客户端根：默认用工程旁的 `2.2.3/`，可用 NARUTO_GAME_ROOT 覆盖。
原版根 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(工程, "..", "2.2.3")
源表 = {
    "effect": {"标签": "asset/effect.swf", "候选": [
        os.path.join(原版根, "www", "act_web_nya_208_isolated", "asset", "effect.swf"),
    ]},
    "寻路提示": {"标签": "swf/Effect/Effect_PathFindingTip.swf", "候选": [
        os.path.join(原版根, "www", "act_web_nya_208_isolated", "swf", "Effect", "Effect_PathFindingTip.swf"),
    ]},
}
FFDEC候选 = [os.environ.get("FFDEC_CLI", ""), "ffdec-cli.exe"]

## 元件类名 → (特效.json 的键, 用途与出处, 源, 每帧ms, 播法出处)
元件表 = {
    "QuestIcon_0": ("QuestIcon_0", "NPC 头顶「可接」= 金色叹号。NPCQuestPopup.as:22-24 case NpcQuestStatus.QUEST_CAN_START → motion=\"QuestIcon_0\"；挂点 NPCSprite.as:256-263（x=0, y=-bmd.height-3）、:383-386（set cy 里 y=-bmd.height-5）", "effect", 10, "TickMovie.as:21 `_frameTime = 10`（fps setter 无人调用） + :100-119 `pastTime / _frameTime mod totalFrames + 1`"),
    "QuestIcon_1": ("QuestIcon_1", "NPC 头顶「进行中」= 银灰问号。NPCQuestPopup.as:26-28 case QUEST_IN_PROGRESS → motion=\"QuestIcon_1\"（时间轴 1 帧 ⇒ 静态）", "effect", 10, "TickMovie.as:21 `_frameTime = 10`（fps setter 无人调用） + :100-119 `pastTime / _frameTime mod totalFrames + 1`"),
    "QuestIcon_2": ("QuestIcon_2", "NPC 头顶「可交」= **金色问号**（不是叹号！）。NPCQuestPopup.as:30-32 case QUEST_CAN_COMPLETE → motion=\"QuestIcon_2\"", "effect", 10, "TickMovie.as:21 `_frameTime = 10`（fps setter 无人调用） + :100-119 `pastTime / _frameTime mod totalFrames + 1`"),
    "MobSelected_Effect_Skin": ("MobSelected_Effect_Skin", "点击 NPC/怪 之后的目标选中箭头（蓝色，逐帧上下浮动）。AbstractLifeObject.as:181-184 属性名 MobMouseOverEffectSkin（名字坑：取的是 Selected 那张）；显示/摘除 Character.as:1458-1471（x=0, y=-_crtCharHeight-8）；开关 TargetHandler.as:269-273", "effect", 10, "TickMovie.as:21 `_frameTime = 10`（fps setter 无人调用） + :100-119 `pastTime / _frameTime mod totalFrames + 1`"),
    "Effect_PathFindingTip": ("Effect_PathFindingTip", "**自动赶路时舞台顶部中央常驻的那条「自动寻路中．．．」**（省略号是逐帧动画，不是文本）。定义 MCFromDatDefine.as:244-250（frameCount=40、swfName 与元件同名）；挂点 KeyController.as:996-1002 与 :1058-1066（x = Config.STAGE_WIDTH/2、y = 110、挂 API.stage、mouseEnabled=false）；摘除 :446-449 与 :1222-1225（停下就 removeChild）；开关参数是 `pathFind(...,param5=showtip)` —— CharacterHandler.as:710（MovePlayerToNpc）/:881/:885 与 SmallMapWindow.as:1137（点小地图）传 true，World.as:392（鼠标点地走）不传 ⇒ **只有自动赶路才亮，手动点地不亮**", "寻路提示", 25, "MCFromDatDefine.as:88-92 `set fps` ⇒ `_frameTime = 1000/40 = 25ms` + :174-193 `tickAnimation`：`pastTime / _frameTime % _datObj.frameCount + 1`（这份 SWF 自己的帧率也正是 40）"),
}
容差px = 3.0       # |不透明区并集| 与 |形状框并集| 每轴允许差（滤镜溢出/抗锯齿），超出即判「两个来源对不上」


def roundf(v):
    """**照 Godot 的 roundf**（四舍五入、.5 远离零），不是 Python 的 round（银行家舍入）。"""
    return math.floor(abs(v) + 0.5) if v >= 0 else -math.floor(abs(v) + 0.5)


def 找文件(候选, 说明):
    for p in 候选:
        if p and os.path.exists(p):
            return p
    raise SystemExit("缺 %s：候选逐个试过都不在盘上 → %s" % (说明, " / ".join([str(c) for c in 候选])))


def 跑(命令, 说明):
    with open(os.devnull, "wb") as 哑:
        回 = subprocess.run(命令, stdout=哑, stderr=subprocess.STDOUT)
    if 回.returncode != 0:
        raise SystemExit("%s 失败（退出码 %s）：%s" % (说明, 回.returncode, " ".join(命令)))


def 转xml(swf, 临时):
    标 = os.path.join(临时, "out.xml")
    具 = 找文件(FFDEC候选, "ffdec")
    跑([具, "-swf2xml", swf, 标] if 具.endswith(".exe") else ["java", "-jar", 具, "-swf2xml", swf, 标],
       "ffdec -swf2xml")
    if not os.path.exists(标):
        raise SystemExit("ffdec -swf2xml 没出 %s" % 标)
    return 标


def 导图(swf, 临时):
    目 = os.path.join(临时, "png")
    os.makedirs(目, exist_ok=True)
    具 = 找文件(FFDEC候选, "ffdec")
    跑([具, "-export", "sprite", 目, swf] if 具.endswith(".exe") else
       ["java", "-jar", 具, "-export", "sprite", 目, swf], "ffdec -export sprite")
    return 目


def 矩阵(项):
    """ffdec 的 MATRIX：translateX/Y 是 twips 的**有符号**整数；hasScale 时 scaleX/Y 已是解好的浮点。"""
    if 项 is None:
        return (1.0, 1.0, 0.0, 0.0)
    if 项.get("hasRotate") == "true":
        raise SystemExit("这份 SWF 里有带旋转的 MATRIX —— 解析器只算 缩放+平移，别把框算错蒙混过去")
    sx = float(项.get("scaleX", 1)) if 项.get("hasScale") == "true" else 1.0
    sy = float(项.get("scaleY", 1)) if 项.get("hasScale") == "true" else 1.0
    return (sx, sy, int(项.get("translateX", 0)) / 20.0, int(项.get("translateY", 0)) / 20.0)


def 解析(标, 名单=None):
    """→ {类名: {"精灵", "帧数", "形状框"[左,上,右,下]px}}。

    形状框 = **逐帧走时间轴**取并集（元件自身坐标，注册点在 (0,0)）。
    PlaceObject2/3 的 `placeFlagMove=true` 条目**没有 characterId**、只带新矩阵 ——
    必须按 depth 沿用它之前放上的那个角色，否则「同一形状逐帧平移」这类元件会少算
    （实测 `MobSelected_Effect_Skin` 少 9px 高）。
    """
    根 = ET.parse(标).getroot()
    名表 = {}
    for it in 根.iter("item"):
        if (it.get("type") or "") == "SymbolClassTag":
            名表 = dict(zip([x.text for x in it.find("tags")], [x.text for x in it.find("names")]))
            break
    if not 名表:
        raise SystemExit("这份 SWF 里没有 SymbolClass 表 —— 解析器与导出件不配套，别接着写表")
    形框 = {}
    精灵项 = {}
    for it in 根.iter("item"):
        类 = it.get("type") or ""
        if 类.startswith("DefineShape"):
            框 = it.find("shapeBounds")
            if 框 is not None:
                形框[it.get("shapeId")] = [int(框.get(k)) / 20.0 for k in ("Xmin", "Ymin", "Xmax", "Ymax")]
        elif 类 == "DefineSpriteTag":
            精灵项[it.get("spriteId")] = it
    算过 = {}

    def 框of(号):
        if 号 in 算过:
            return 算过[号]
        算过[号] = None                       # 先占位，防自引用死循环
        if 号 in 形框:
            算过[号] = list(形框[号])
            return 算过[号]
        项 = 精灵项.get(号)
        if 项 is None:
            return None
        算过[号] = 走时间轴(项)
        return 算过[号]

    def 走时间轴(项):
        子 = 项.find("subTags")
        if 子 is None:
            return None
        现场 = {}                            # depth -> [characterId, sx, sy, tx, ty]
        合 = None

        def 摊(内, sx, sy, tx, ty):
            return [内[0] * sx + tx, 内[1] * sy + ty, 内[2] * sx + tx, 内[3] * sy + ty]

        def 收():
            for 放 in 现场.values():
                内 = 框of(放[0])
                if 内 is not None:
                    yield 摊(内, 放[1], 放[2], 放[3], 放[4])

        def 并(p):
            nonlocal 合
            合 = p if 合 is None else [min(合[0], p[0]), min(合[1], p[1]),
                                       max(合[2], p[2]), max(合[3], p[3])]

        for s in 子.findall("item"):
            类 = s.get("type") or ""
            if 类 in ("PlaceObject2Tag", "PlaceObject3Tag"):
                旧 = 现场.get(s.get("depth"), [None, 1.0, 1.0, 0.0, 0.0])
                号 = s.get("characterId") or 旧[0]
                if 号 is None:
                    continue
                m = 矩阵(s.find("matrix")) if s.find("matrix") is not None else tuple(旧[1:])
                现场[s.get("depth")] = [号, m[0], m[1], m[2], m[3]]
            elif 类 in ("RemoveObjectTag", "RemoveObject2Tag"):
                现场.pop(s.get("depth"), None)
            elif 类 == "ShowFrameTag":
                for p in 收():
                    并(p)
        for p in 收():                       # 末帧之后没有 ShowFrame，补一次
            并(p)
        return 合

    要 = set(元件表) if 名单 is None else set(名单)
    出 = {}
    for 号, 名 in 名表.items():
        if 名 not in 要:
            continue
        合 = 框of(号)
        if 合 is None:
            raise SystemExit("%s（精灵 %s）里没解析出形状框 —— 注册点就是查无，别写 0,0 蒙" % (名, 号))
        项 = 精灵项.get(号)
        出[名] = {"精灵": int(号), "帧数": int(项.get("frameCount", 1)) if 项 is not None else 1,
                 "形状框": [round(v, 3) for v in 合]}
    缺 = [名 for 名 in 要 if 名 not in 出]
    if 缺:
        raise SystemExit("导出表里没有这些元件：%s ⇒ 元件不在这份 SWF 里，别接着写" % "、".join(缺))
    return 出


def 帧序列(目, 名, 形状框):
    """→ (段表, 时间轴帧数, 不透明区并集, 注册点, (画布宽, 画布高))。PNG 原样保留 ffdec 画布，不裁。"""
    夹 = os.path.join(目, 名)
    if not os.path.isdir(夹):
        候 = [d for d in os.listdir(目) if d.endswith("_" + 名)]
        if not 候:
            raise SystemExit("ffdec 没导出 %s 的帧目录（%s 下只有 %s）"
                             % (名, 目, "、".join(sorted(os.listdir(目))[:6])))
        夹 = os.path.join(目, 候[0])
    件 = sorted([f for f in os.listdir(夹) if re.fullmatch(r"\d+\.png", f)],
                key=lambda f: int(f.split(".")[0]))
    if not 件:
        raise SystemExit("%s 目录里没有 <帧号>.png" % 夹)
    A = None
    尺 = set()
    字表 = {}
    for f in 件:
        路 = os.path.join(夹, f)
        字 = open(路, "rb").read()
        字表[f] = 字
        图 = Image.open(路).convert("RGBA")
        尺.add(图.size)
        框 = 图.split()[3].getbbox()
        if 框:
            A = 框 if A is None else (min(A[0], 框[0]), min(A[1], 框[1]),
                                      max(A[2], 框[2]), max(A[3], 框[3]))
    if len(尺) != 1:
        raise SystemExit("%s：ffdec 给的画布尺寸不统一 %s ⇒ 逐帧贴图不能共用一个注册点" % (名, sorted(尺)))
    if A is None:
        raise SystemExit("%s：所有帧的不透明区都为空，没有可对齐的字形" % 名)
    宽, 高 = 尺.pop()
    左, 上, 右, 下 = 形状框
    al, at, ar, ab = A
    for 轴, a, s in (("宽", ar - al, 右 - 左), ("高", ab - at, 下 - 上)):
        if abs(a - s) > 容差px:
            print("  %-24s %s：不透明区 %.1fpx 与形状框 %.1fpx 差 %.1f（滤镜晕出/形状框留白）⇒ 这一轴走「字形边」推"
                  % (名, 轴, a, s, abs(a - s)))
    ## 注册点（元件自身坐标 (0,0)）在画布里的位置。
    ## 口径：**画出来的字形 = 几何框里的字形**，于是
    ##   · y：字形底边 ab 对应几何底边 下 ⇒ 注册点在 ab 之下 (0 − 下) px；
    ##   · x：字形中心 (al+ar)/2 对应几何中心 (左+右)/2 ⇒ 注册点在字形中心左偏 (左+右)/2 px。
    ## 这条在 `MobSelected_Effect_Skin` 上是**精确**的（两轴 extents 与形状框逐位相同，见 主() 的自检①），
    ## 其余三枚因为挂了 GLOW/BEVEL 滤镜、画布被晕出去一圈，只能按同一口径外推。
    原x = (al + ar) / 2.0 - (左 + 右) / 2.0
    原y = float(ab) + (0.0 - 下)
    原点 = [int(roundf(原x)), int(roundf(原y))]
    ## 守卫判的是**形状框落进画布没有**，不是「注册点在画布内」——
    ## `Effect_PathFindingTip` 的注册点在这枚元件的**地面线**上（形状框 y 到 −2 为止，
    ## 字形整体在锚点之上），于是注册点 y=45 天然落在 43 高的画布之外 2px。
    ## 判「注册点在画布内」会把这种元件直接拒掉，而真正该拒的是「注册点算错 ⇒ 字形跑出画布」。
    内 = [原点[0] + 左, 原点[1] + 上, 原点[0] + 右, 原点[1] + 下]
    if 内[0] < -容差px or 内[1] < -容差px or 内[2] > 宽 + 容差px or 内[3] > 高 + 容差px:
        raise SystemExit("%s：注册点 %s 把形状框 %s 推到画布 %dx%d 之外（换算后 %s）"
                         % (名, 原点, 形状框, 宽, 高, [round(v, 2) for v in 内]))
    段 = []
    前 = None
    for f in 件:
        值 = hashlib.md5(字表[f]).hexdigest()
        if 值 != 前:
            段.append({"源": os.path.join(夹, f), "字": 字表[f], "帧数": 1})
            前 = 值
        else:
            段[-1]["帧数"] += 1
    严丝 = all(abs(x - y) <= 容差px for x, y in ((ar - al, 右 - 左), (ab - at, 下 - 上)))
    return 段, len(件), [int(v) for v in A], 原点, (宽, 高), 严丝


def 主():
    干跑 = "--干跑" in sys.argv
    新条 = {}
    精确件 = []
    for 源, 元件们 in _按源分组().items():
        信息 = 源表[源]
        swf = 找文件(信息["候选"], "%s（%s）" % (源, 信息["标签"]))
        摘要 = hashlib.md5(open(swf, "rb").read()).hexdigest()
        临时 = tempfile.mkdtemp(prefix="任务标记特效_")
        try:
            表 = 解析(转xml(swf, 临时), [名 for 名, _v in 元件们])
            目 = 导图(swf, 临时)
            for 名, (键, 用途, _源, 每帧ms, 间隔出处) in 元件们:
                项 = 表[名]
                段, 时间轴帧, A, 原点, (宽, 高), 严丝 = 帧序列(目, 名, 项["形状框"])
                if 严丝:
                    精确件.append(名)
                帧们 = []
                for i, s in enumerate(段):
                    帧们.append({"序号": i, "类名": 名,
                                "贴图": "res://素材/特效/%s/%s_%d.png" % (名, 名, i),
                                "宽": 宽, "高": 高, "停留ms": s["帧数"] * 每帧ms, "原点": 原点})
                    if not 干跑:
                        落 = os.path.join(工程, "素材", "特效", 名, "%s_%d.png" % (名, i))
                        os.makedirs(os.path.dirname(落), exist_ok=True)
                        shutil.copyfile(s["源"], 落)
                if sum(f["停留ms"] for f in 帧们) != 时间轴帧 * 每帧ms:
                    raise SystemExit("%s：段长之和 %dms != 时间轴 %d 帧 × %dms"
                                     % (名, sum(f["停留ms"] for f in 帧们), 时间轴帧, 每帧ms))
                新条[键] = {"形态": "逐帧位图",
                           "播法": {"帧间隔": 间隔出处 + " ⇒ 每帧 " + str(每帧ms) + "ms、走完回第 0 帧。这里已把 "
                                          + str(时间轴帧) + " 帧时间轴压成 " + str(len(帧们))
                                          + " 段唯一帧，停留ms 记段长",
                                   "循环": True},
                           "帧": 帧们,
                           "时间轴帧": 时间轴帧,
                           "每帧ms": 每帧ms,
                           "形状框": 项["形状框"],
                           "不透明区": A,
                           "画布": [宽, 高],
                           "注册点": 原点,
                           "注册点依据": "精确（不透明区与形状框两轴逐位相同）" if 严丝
                                        else "按字形边/字形心外推（画布被 GLOW/BEVEL 滤镜撑大，见 出处）",
                           "元件": 名,
                           "精灵": 项["精灵"],
                           "用途": 用途,
                           "出处": "%s DefineSprite#%d：注册点由 shapeBounds 并集与全帧不透明区并集线性对应算出%s"
                                   "；钉 2.2.3优化版，md5 %s"
                                   % (信息["标签"], 项["精灵"],
                                      "" if 严丝 else "（元件挂了 GLOW/BEVEL 滤镜，画布被撑大，只信一边必错）",
                                      摘要)}
        finally:
            shutil.rmtree(临时, ignore_errors=True)

    ## 自检①：这套「字形边 ↔ 几何边」的口径必须至少在一枚元件上是**精确**的（两轴 extents 逐位相同）。
    ## 没有这一枚阳性对照，其余各枚的注册点就全是猜的 —— 宁可炸，不要写进表。
    if not 精确件:
        raise SystemExit("这批元件里没有一枚的不透明区与形状框两轴都对得上 ⇒ 注册点口径未经验证，别写表")
    print("口径阳性对照：%s 的不透明区与形状框两轴逐位相同" % "、".join(精确件))

    for 键, 条 in 新条.items():
        print("%-24s 时间轴%4d帧 → %2d 段唯一帧  画布%dx%d  不透明区%s  注册点%s  周期%dms" % (
            键, 条["时间轴帧"], len(条["帧"]), 条["画布"][0], 条["画布"][1],
            条["不透明区"], 条["注册点"], sum(f["停留ms"] for f in 条["帧"])))
    if 干跑:
        print("--干跑：没写盘")
        return

    原文 = json.load(io.open(特效表路, encoding="utf-8"))
    合 = dict(原文.get("特效", {}))
    合.update(新条)
    原文["特效"] = dict(sorted(合.items()))
    原文["数量"] = len(原文["特效"])
    io.open(特效表路, "w", encoding="utf-8").write(
        json.dumps(原文, ensure_ascii=False, indent=1) + "\n")
    重 = json.load(io.open(特效表路, encoding="utf-8"))["特效"]
    钉 = lambda d: json.dumps({k: (d[k]["注册点"], d[k]["时间轴帧"], len(d[k]["帧"])) for k in 新条},
                              sort_keys=True)
    if 钉(新条) != 钉(重):
        raise SystemExit("自检失败：重读盘上的注册点/帧数与刚算的不一致")
    for 键, 条 in 新条.items():
        for f in 条["帧"]:
            路 = os.path.join(工程, f["贴图"][len("res://"):].replace("/", os.sep))
            if not os.path.exists(路):
                raise SystemExit("自检失败：表里这条贴图不在盘上 %s" % f["贴图"])
    print("写 %s：新增/更新 %d 条（表内现共 %d 条）；重读注册点逐条相同"
          % (os.path.relpath(特效表路, 工程), len(新条), 原文["数量"]))



def _按源分组():
    出 = {}
    for 名, v in 元件表.items():
        出.setdefault(v[2], []).append((名, v))
    for 源, 们 in 出.items():
        if 源 not in 源表:
            raise SystemExit("元件表里 %s 指了个不存在的源 %r" % ("、".join(k for k, v in 们 if v[2] == 源), 源))
    return 出

if __name__ == "__main__":
    主()
