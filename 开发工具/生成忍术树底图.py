# -*- coding: utf-8 -*-
"""导出原版 5 个「忍术树」子面板底图，把烘死在里面的格子框换成原版运行时的样子。

为什么要重做
------------
客户端现在 5 个页签共用一张 `忍术树底图.png`（= 符号 930 `SkillPane1F` 的扁平导出）。
扁平导出有两个地方和原版运行时不一样：

1. **每一格都被烘成了"选中"态**。格子元件 `SkillCellF`（符号 130）的**第 1 帧就是橙色选中环**；
   运行时未选中的格子是 `SkillCell_background`（符号 125，40x40 棕框）。
   扁平渲染走第 1 帧，所以底图上会一直有 15 个橙圈——原版只有当前那一格才有。
   → 本工具按"橙框围出来的暗区"把格子位置**测出来**再抹掉，交给客户端自己摆格子
     （也顺带产出 `数据/界面/忍术树_箭头与元件.json` 里的逐格坐标，供客户端定位）。

2. **连接线（粗杆 + 箭头）是橙色的**。运行时 `SkillPane.onEnterFrame` 会给它加
   `Style.getDisableFilter()`（亮度矩阵 0.3086/0.6094/0.082）：**技能没学就变灰**，
   学了才恢复橙色（`arrows[_index].filters = floor > 0 ? null : getDisableFilter()`）。
   → 底图里的连接线**整条抹掉**（客户端逐条自己画，见下）。

**连接线现在由客户端逐条画**（2026-09-19 改；原来是从真机截图抠一整层，只能整层灰）
- 「箭头」表给出每条：`格`（指向的格子下标）/`元件`（`SkillArrow1..4` 的符号 id）/`x,y`/`缩放X,Y`。
  `arrows[i]` 跟着 `cells[i]` 学没学走（`SkillPane.as`），而实例名 `arrowN` 的 N 恒等于 i。
  **缩放必须一起用**：长杆是 `arrow7/8` 用 `scale(1,4.88)` 拉出来的。
- 另外导出 4 张箭头美术（`忍术树箭头_<符号id>.png`）——它们的**原色就是橙的**
  （实测主色 (200,80,0)），AS3 只是给没学的加亮度矩阵转灰，所以不需要另找橙素材。

⚠️ 客户端现在用的那张底图**元件是对的**（就是 `SkillPane1F`，与符号 930 逐像素差 4.34%，
只差抗锯齿）。文档 §3.3.0b 记的"用错元件 930、实渲更像 885"是错的：
930=SkillPane1F 正是「职业忍术」页用的那个（15 格 4 列），885=SkillPane2F 是「世界忍术」（18 格 3 列）。

用法
----
    python 开发工具/生成忍术树底图.py

产物
----
    素材/界面/原版窗口/忍术/忍术树底图_<页签>.png   230x390，只有面板背景（格子与连接线都抹掉了）
    素材/界面/原版窗口/忍术/忍术树箭头_732/927/929/884.png   4 张箭头原色美术
    数据/界面/忍术树_箭头与元件.json                每页签的元件、逐格坐标、逐条箭头（含缩放的运行时坐标）
"""

import glob
import io
import json
import os
import re
import subprocess
import sys
from collections import Counter, deque

import numpy as np
from PIL import Image

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版目录 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(项目根, "..", "2.2.3")
FFDEC = os.environ.get("FFDEC_CLI") or os.path.join(原版目录, "ffdec_26.2.1", "ffdec-cli.exe")
SWF = os.path.join(原版目录, "www", "act_web_nya_208_isolated", "asset", "MainLib.swf")
临时目录 = os.path.join(项目根, "..", ".scratch", "技能补数据", "元件")
素材目录 = os.path.join(项目根, "素材", "界面", "原版窗口", "忍术")
坐标产物 = os.path.join(项目根, "数据", "界面", "忍术树_箭头与元件.json")

# 各元件的 `arrows` 数组（AS3 源码里的字面量）：下标=格序号，1 表示那一格后面接着一条连接线。
# SkillPane1.as:74 / SkillPane2.as:82 / SkillPane3.as:62 / SkillPane4.as:57 / SkillPane5.as:47
箭头表 = {
    "SkillPane1F": [0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1],
    "SkillPane2F": [0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    "SkillPane3F": [0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1],
    "SkillPane4F": [0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0],
    "SkillPane5": [0, 0, 1, 0, 1, 0, 0, 0],
}

# 页签 → (元件名, 符号id, 是否要拉伸到 230x390)。
# 特别技能那页**没有自己的元件**：SkillPane5.as 是 `new SkillWindowMPane_background()`
# 再设 width=230/height=390（符号 881 原尺寸 253x212，被拉伸）。
页签 = [
    ("职业忍术", "SkillPane1F", 930, False),
    ("世界忍术", "SkillPane2F", 885, False),
    ("其他忍术", "SkillPane4F", 886, False),
    ("奥义禁术", "SkillPane3F", 931, False),
    ("特别技能", "SkillWindowMPane_background", 881, True),
]

# 各元件里 `arrowN` 的**时间轴坐标**（twips÷20），从 `ffdec -swf2xml MainLib.swf` 里
# 按 `name="arrowN"` 后紧跟的 `<matrix translateX translateY>` 抠出来的：
#     python -c "…" → _箭头时间轴.json（生成命令见提交信息）
# 为什么要它：符号**扁平导出**里那根箭头和运行时**不在同一个位置**（实测差 6px），
# 而运行时位置就是时间轴上的这个矩阵。
箭头时间轴文件 = os.path.join(项目根, "..", ".scratch", "技能补数据", "_箭头时间轴.json")
元件符号 = {"SkillPane1F": "930", "SkillPane2F": "885", "SkillPane3F": "931", "SkillPane4F": "886"}


def 取箭头表(元件名: str) -> list:
    """该元件 `arrows` 数组（下标=格序号，1 表示那一格后面有连接线）。"""
    return 箭头表.get(元件名) or 箭头表.get("SkillPane5", [])


def 取箭头坐标(元件名: str) -> list:
    """按 `arrows` 数组的顺序，返回该元件每条箭头的 [x, y]（元件局部）。

    `arrows` 数组的下标 = 格序号，所以第 i 个非空项就是"格子 i 后面那条箭头"，
    时间轴里的 `arrowN` 恰好按 N 递增排在格序上（arrow1/2/3…对应第 1/2/3 条）。
    """
    if 元件名 == "SkillWindowMPane_background":
        # 特别技能页的箭头**不在时间轴上**：SkillPane5.as 的 `createArrow(cell)` 是代码 new 的：
        #   `x = cell.x + (cell.width − arrow.width)/2`、`y = cell.y + cell.height + 2`
        # 而代码里挂的是 `arrow2 = createArrow(cell1)`、`arrow4 = createArrow(cell3)`
        # ——锚点是 **cells[1] / cells[3]**（不是 cells[2]/cells[4]），
        # 所以箭头落在 cellHeight+2 = 48 的下方，即 y = 43 + 48 = 91。
        格 = 取格子坐标(元件名)
        return [[格[i][0] + (46 - 15) / 2.0, 格[i][1] + 46 + 2] for i in (1, 3)]
    if 元件名 == "SkillPane4F":
        # `setCellXY()` 会把 arrow1/3/5/7 重摆到对应格子的正下方：
        #   `x = cell.x + (cell.width − arrow.width)/2`、`y = cell.y + cell.height − 7`
        # （cell 46x46、arrow 15x17）。所以箭头位置要按**运行时格子位置**算——
        # 符号里烘的那几根（(32,62) 那一排）是作者期的，不在运行画面上。
        格 = 取格子坐标(元件名)
        return [[格[i - 1][0] + (46 - 15) / 2.0, 格[i - 1][1] + 46 - 7]
                for i, v in enumerate(取箭头表(元件名)) if v == 1]
    表 = json.load(io.open(箭头时间轴文件, encoding="utf-8")) if os.path.exists(箭头时间轴文件) else {}
    原始 = 表.get(元件符号.get(元件名, ""), {})
    return [原始[k] for k in sorted(原始, key=lambda n: int(n[5:]))]


# 原版真机截图（连接线只能从这儿取，见 抠连接线 的说明）
_截图根 = os.path.join(项目根, "..", ".scratch", "技能补数据")
真机截图 = {
    "职业忍术": os.path.join(_截图根, "原版_忍术_0.png"),
    "世界忍术": os.path.join(_截图根, "原版_世界忍术.png"),
    "其他忍术": os.path.join(_截图根, "批次1", "其他忍术.png"),
    "奥义禁术": os.path.join(_截图根, "批次1", "奥义禁术.png"),
    "特别技能": os.path.join(_截图根, "原版_特别技能.png"),
}

# Style.creatDisableFilter() 的亮度矩阵
亮度 = (0.3086, 0.6094, 0.082)

# 连接线逐条画要用的**箭头美术**：4 个 `SkillArrow` 符号的原始色（橙 (200,80,0)）。
# AS3 只给"没学的"那条加 `getDisableFilter()`（就是上面的亮度矩阵）转灰，
# 学了的 `filters = null`，用的就是这张原色图 —— 直接导出即可，不用去把灰的调回橙。
箭头美术 = {732: "SkillArrow1", 929: "SkillArrow2", 927: "SkillArrow3", 884: "SkillArrow4"}


def 导出(符号: int) -> Image.Image:
    os.makedirs(临时目录, exist_ok=True)
    subprocess.run([FFDEC, "-selectid", str(符号), "-format", "sprite:png",
                    "-export", "sprite", 临时目录, SWF], capture_output=True, text=True)
    命中 = glob.glob(os.path.join(临时目录, "DefineSprite_%d_*" % 符号, "1.png"))
    if not 命中:
        raise SystemExit("ffdec 没有导出符号 %d" % 符号)
    return Image.open(命中[0]).convert("RGBA")


def 取格子坐标(元件名: str) -> list:
    """逐格坐标（元件局部）。SkillPane4F/5 用 AS3 源码里的值；1F/2F/3F 用 naruto 提取表。

    ⚠️ naruto 的 `skill_cells.json` 里 **SkillPane4F 那 8 条是错的**（坐标整体偏 -20 且只有 8 条），
    真实值在 `SkillPane4.as setCellXY()`：12 格，x=19/70/121/172，y=43/113/210。
    """
    if 元件名 == "SkillPane4F":
        # ⚠️ 顺序 = AS3 `cells[]` 的**声明序**，不是视觉的行优先。
        # SkillPane4.as：cell0..cell7 是符号里的，`setCellXY()` 把 cell0/cell1 摆到 x=19
        # 那列的上下两格、cell2/cell3 摆到 x=70…（"每列一对"，`cells` 数组也按这个顺序）；
        # cell8..cell11 是 `newCell()` 另建的底行（y=210）。
        # 数据是 `cells[i].setCellValue(param1[i])`，按下标对格，所以这里必须照抄。
        x = [19, 70, 121, 172]
        面 = []
        for i in range(4):
            面.append((x[i], 43))
            面.append((x[i], 113))
        return 面 + [(x[i], 210) for i in range(4)]
    if 元件名 == "SkillWindowMPane_background":
        # SkillPane5.as createCell()：CELL_START_X=19 / CELL_START_Y=43 / CELL_GAP=5，
        # 列 = [0,1,1,2,2,3,3,0]，行 = [0,0,1,0,1,0,1,1]
        列 = [0, 1, 1, 2, 2, 3, 3, 0]
        行 = [0, 0, 1, 0, 1, 0, 1, 1]
        return [(19 + c * 51, 43 + r * 70) for c, r in zip(列, 行)]
    表 = json.load(open(os.path.join(项目根, "..", "naruto-client", "assets",
                                     "skill_cells.json"), encoding="utf-8"))
    return [(int(round(格["x"])), int(round(格["y"]))) for 格 in 表[元件名]]


_时间轴缓存 = None


def _取时间轴():
    global _时间轴缓存
    if _时间轴缓存 is None:
        import importlib.util
        路径 = os.path.join(项目根, "开发工具", "读符号时间轴.py")
        spec = importlib.util.spec_from_file_location("读符号时间轴", 路径)
        模块 = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(模块)
        _时间轴缓存 = (模块, 模块.读XML(模块.XML_默认))
    return _时间轴缓存


def _时间轴实例(元件名: str) -> dict:
    """该元件时间轴上的 `arrowN` 实例：名字 → (子符号id, x, y, 缩放X, 缩放Y)。"""
    if 元件名 not in 元件符号:
        return {}
    模块, 文本 = _取时间轴()
    块 = 模块.取符号块(文本, int(元件符号[元件名]))
    if not 块:
        return {}
    出 = {}
    for 帧 in 模块.解析时间轴(块):
        for 放 in 帧["放置"]:
            名 = str(放.get("名称") or "")
            if 名.startswith("arrow"):
                出[名] = (放["元件"], 放["x"], 放["y"], 放["缩放X"], 放["缩放Y"])
    return 出


def 取箭头实例(元件名: str) -> list:
    """每条连接线的**运行时**信息：{格, 元件, x, y, 缩放X, 缩放Y}。

    「格」= 它指向的格子下标（AS3 `arrows[i].filters = cells[i].floor > 0 ? …`，
    而实例名 `arrowN` 的 N 恒等于 i —— 四个元件都核过）。
    **坐标与缩放必须一起带**：长杆是 `arrow7/8` 用 `scale(1, 4.88)` 拉出来的，
    只画精灵盒不乘缩放就只剩一堆小箭头（上一轮"长杆全没了"就是漏了这个）。
    """
    目标 = [i for i, v in enumerate(取箭头表(元件名)) if v == 1]
    时间轴 = _时间轴实例(元件名)
    格 = 取格子坐标(元件名)
    出 = []
    for 序号 in 目标:
        if 元件名 == "SkillWindowMPane_background":
            # 特别技能页的箭头不在时间轴上：`SkillPane5.createArrow` 是代码 new 的，
            # 锚点是 cells[1]/cells[3]（`arrow2 = createArrow(cell1)`、`arrow4 = createArrow(cell3)`）。
            出.append({"格": 序号, "元件": 732,
                       "x": 格[序号 - 1][0] + (46 - 15) / 2.0,
                       "y": 格[序号 - 1][1] + 46 + 2,
                       "缩放X": 1.0, "缩放Y": 1.0})
            continue
        项 = 时间轴.get("arrow%d" % 序号)
        if 项 is None:
            continue
        元件, x, y, 缩放X, 缩放Y = 项
        if 元件名 == "SkillPane4F":
            # `setCellXY()` 会把 arrow1/3/5/7 重摆到对应格子正下方：
            #   `x = cell.x + (cell.width − arrow.width)/2`、`y = cell.y + cell.height − 7`
            x = 格[序号 - 1][0] + (46 - 15) / 2.0
            y = 格[序号 - 1][1] + 46 - 7
        出.append({"格": 序号, "元件": 元件, "x": x, "y": y, "缩放X": 缩放X, "缩放Y": 缩放Y})
    return 出


def 箭头矩形(符号: int, 要拉伸: bool, 尺寸) -> list:
    """元件时间轴上每个 `arrowN` 实例的像素矩形（含 1px 余量）。

    箭头是 `SkillArrow1/2/3/4` 这些符号按矩阵摆放（有的还带缩放，长杆就是这么拉出来的），
    所以矩形 = 实例坐标 + 子符号包围盒 × 缩放。特别技能页的箭头不在时间轴上（代码 new 的），
    返回空表。拉伸页（881）也不含箭头。
    """
    if 要拉伸 or 符号 not in (930, 885, 886, 931):
        return []
    模块, 文本 = _取时间轴()
    元件名 = {v: k for k, v in 元件符号.items()}.get(str(符号))
    if 元件名 is None:
        return []
    矩形 = []
    for 项 in 取箭头实例(元件名):
        盒 = 模块.字符边界(文本, 项["元件"])
        if not 盒:
            continue
        # ⚠️ 这里要用**时间轴上**的位置（底图上烘的是作者期体位），
        # 所以对 SkillPane4F 要拿回原始 x/y，不能用 setCellXY 之后的。
        原 = _时间轴实例(元件名).get("arrow%d" % 项["格"])
        if 原 is None:
            continue
        x, y = 原[1], 原[2]
        矩形.append((
            int(x + 盒[0] * 项["缩放X"]) - 1,
            int(y + 盒[1] * 项["缩放Y"]) - 1,
            int(x + 盒[2] * 项["缩放X"]) + 2,
            int(y + 盒[3] * 项["缩放Y"]) + 2,
        ))
    return 矩形


def 橙色掩码(图: Image.Image) -> np.ndarray:
    a = np.asarray(图.convert("RGB"), dtype=np.int16)
    return (a[:, :, 0] > 120) & (a[:, :, 0] > a[:, :, 2] + 40)


def 测烘死的格子(橙: np.ndarray) -> list:
    """测出元件里烘着的格子框：格子内部是一块**被橙框围住的暗区**。

    做法：把"非橙"像素当可通行区域，从画布四边灌水；灌不到的那部分就是被围住的格子内部。
    比按 AS3 坐标去抹稳——元件里烘的格子未必摆在 `setCellXY()` 的位置上
    （试过按 AS3 坐标抹，`SkillPane4F` 抹完还剩 64x47 的橙块）。
    """
    高, 宽 = 橙.shape
    可走 = ~橙
    可达 = np.zeros_like(可走)
    队 = deque()
    for x in range(宽):
        for y in (0, 高 - 1):
            if 可走[y, x] and not 可达[y, x]:
                可达[y, x] = True
                队.append((y, x))
    for y in range(高):
        for x in (0, 宽 - 1):
            if 可走[y, x] and not 可达[y, x]:
                可达[y, x] = True
                队.append((y, x))
    while 队:
        y, x = 队.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < 高 and 0 <= nx < 宽 and 可走[ny, nx] and not 可达[ny, nx]:
                可达[ny, nx] = True
                队.append((ny, nx))
    封闭 = 可走 & ~可达
    # 连通域：每个封闭块 = 一个格子内部
    已访 = np.zeros_like(封闭)
    格 = []
    for sy, sx in zip(*[v.tolist() for v in np.nonzero(封闭)]):
        if 已访[sy, sx]:
            continue
        队 = deque([(sy, sx)])
        已访[sy, sx] = True
        x0 = x1 = sx
        y0 = y1 = sy
        面积 = 0
        while 队:
            y, x = 队.popleft()
            面积 += 1
            x0, x1 = min(x0, x), max(x1, x)
            y0, y1 = min(y0, y), max(y1, y)
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < 高 and 0 <= nx < 宽 and 封闭[ny, nx] and not 已访[ny, nx]:
                    已访[ny, nx] = True
                    队.append((ny, nx))
        if 面积 < 200:          # 太小的不算格子（抗锯齿孔隙等）
            continue
        框 = 3                   # 橙框宽约 3px，向外扩出去把框也圈进来
        格.append((max(0, x0 - 框), max(0, y0 - 框),
                   min(宽, x1 + 1 + 框), min(高, y1 + 1 + 框)))
    return sorted(格, key=lambda t: (t[1], t[0]))


def _定位工具():
    import importlib.util
    路径 = os.path.join(项目根, "开发工具", "定位原版忍术格.py")
    spec = importlib.util.spec_from_file_location("定位原版忍术格", 路径)
    模块 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(模块)
    return 模块


_定位偏移缓存 = None


def _定位器相对格原点的偏移(格: list) -> tuple:
    """把 `定位原版忍术格.py` 在**已知原点**的合成图上跑一遍，量出它的「格心」偏格原点多少。

    为什么要标定：那个定位器给的是「框心」，而框心相对元件原点是个固定但不好手算的值
    （它自己会膨胀掩码、容差也和这里不同）。用它自己在合成图上的读数当基准，
    偏差就抵消掉了——剩下的就是真正的树原点。
    """
    global _定位偏移缓存
    if _定位偏移缓存 is not None:
        return _定位偏移缓存
    定位 = _定位工具()
    底 = Image.open(os.path.join(素材目录, "忍术格底.png")).convert("RGBA")
    画布 = Image.new("RGB", (2560, 1440), (57, 38, 32))
    假原点 = (900, 500)
    for (lx, ly) in 格:
        画布.paste(底, (假原点[0] + lx, 假原点[1] + ly), 底)
    临时 = os.path.join(临时目录, "_合成_定位标定.png")
    os.makedirs(临时目录, exist_ok=True)
    画布.save(临时)
    找到 = 定位.找格(临时, (850, 450, 1300, 950), 1100)
    偏移 = []
    for 项 in 找到:
        cx, cy = 项[0], 项[1]
        # 找最近的 AS3 格
        最 = min(格, key=lambda g: (假原点[0] + g[0] - cx) ** 2 + (假原点[1] + g[1] - cy) ** 2)
        偏移.append((cx - (假原点[0] + 最[0]), cy - (假原点[1] + 最[1])))
    if not 偏移:
        raise SystemExit("定位器标定失败：合成图上没找到格子")
    偏移.sort()
    _定位偏移缓存 = 偏移[len(偏移) // 2]
    print("     定位器标定：合成图上找到 %d 格，格心相对格原点 = %s"
          % (len(偏移), _定位偏移缓存))
    return _定位偏移缓存


def 测树原点(截图: str, 格: list) -> tuple:
    """在整屏截图里把「技能树元件原点」量出来（不再硬编码）。

    上一版把原点写成常数 (800,527)，结果整层偏了 4~6px，表现为
    「箭头看着有点下坠」「横杆左端戳进格子右下角」这种说不清的小症状。
    现在改成实测：用 `定位原版忍术格.py` 找出各格格心，减掉标定出来的格心偏移，
    再减掉 AS3 的逐格坐标，取中位数。
    """
    定位 = _定位工具()
    偏移X, 偏移Y = _定位器相对格原点的偏移(格)
    找到 = 定位.找格(截图, 定位.默认窗口, 定位.默认树右界)
    if len(找到) != len(格):
        raise SystemExit("在 %s 里找到 %d 格，但该页签有 %d 格——数不上就不敢定原点"
                         % (截图, len(找到), len(格)))
    # 用**质心差**求平移：两套点是同一个刚体（都只平移），质心差就是树原点，
    # 不用先知道原点、也就不会出现「就近匹配」那种先有鸡还是先有蛋的歪解。
    检测质心 = (sum(t[0] for t in 找到) / len(找到), sum(t[1] for t in 找到) / len(找到))
    格质心 = (sum(g[0] for g in 格) / len(格) + 偏移X, sum(g[1] for g in 格) / len(格) + 偏移Y)
    原点X = 检测质心[0] - 格质心[0]
    原点Y = 检测质心[1] - 格质心[1]
    return (len(找到), int(round(原点X)), int(round(原点Y)), len(找到))


def 抠连接线(截图: str, 格: list) -> Image.Image:
    """从**原版真机截图**里抠出连接线层。

    为什么不在符号上做：符号里烘的箭头是 `SkillArrow1` 那种 17px 的小箭头，
    而原版运行时画的是 33px 的大箭头（`SkillPane` 的 `arrow1..N` 精灵，位置在时间轴上、
    不在 AS3 代码里）——实测同一根横杆，符号在 y149..154、真机在 y155..160。
    所以连接线的**形状和位置都以真机为准**，直接从截图里抠。

    抠法：连接线是灰的（RGB 三通道接近），格子的框是棕的、选中环是橙的，都不满足；
    只有**未学技能的图标**也是灰的，按已知格坐标把图标和等级数字那两块挖掉即可。
    """
    一致, 原X, 原Y, 找到数 = 测树原点(截图, 格)
    print("     连接线抠图：测到树原点 = (%d,%d)（找到 %d 格，其中 %d 个与中位数一致）"
          % (原X, 原Y, 找到数, 一致))
    图 = Image.open(截图).convert("RGB").crop((原X, 原Y, 原X + 230, 原Y + 390))
    a = np.asarray(图, dtype=np.int16)
    mx = a.max(axis=2); mn = a.min(axis=2)
    灰 = (mx > 95) & ((mx - mn) < 26)
    # ⚠️ 这里必须把**整格**挖掉，不只是图标与等级数字那两块。
    # 格子框虽然主体是棕的，但它的抗锯齿边/高光边是**灰的**，会被上面的"灰"判据选中，
    # 抠出来就是一堆贴在格子四角的碎块（"⌐"形拐角和短竖线）——叠在格子上就是
    # 一直没看明白的"忍术框边上的白边"。格子是画在连接线**之上**的，
    # 所以格子矩形里本来就不可能有连接线像素，整块挖掉不会误伤。
    # 矩形取"选中环"的范围 (-3,-3)-(43,43)（46x46，见 忍术格.tscn 的真值）。
    for g in 格:
        x, y = int(g[0]), int(g[1])
        灰[max(0, y - 3):y + 43, max(0, x - 3):x + 43] = False
    out = np.zeros((390, 230, 4), dtype=np.uint8)
    出 = np.asarray(图, dtype=np.uint8)
    out[:, :, :3] = 出
    out[:, :, 3] = np.where(灰, 255, 0).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def 主() -> int:
    坐标表 = {}
    for 名, 元件, 符号, 要拉伸 in 页签:
        图 = 导出(符号)
        if 要拉伸:
            图 = 图.resize((230, 390), Image.LANCZOS)
        宽, 高 = 图.size
        像素 = 图.load()

        # 面板底色：全图里**非橙**像素的众数。别去角落取样——角落可能压着阴影或描边，
        # 取到错的值会把抹掉的格子填成一块更深/更浅的补丁（世界忍术那页就这样翻过车）。
        _橙全 = 橙色掩码(图)
        底色 = Counter(
            (r, g, b, a)
            for y in range(高) for x in range(宽)
            for (r, g, b, a) in (像素[x, y],)
            if not _橙全[y, x] and a > 0
        ).most_common(1)[0][0]

        烘格 = 测烘死的格子(橙色掩码(图)) if not 要拉伸 else []
        清 = 0
        for (x0, y0, x1, y1) in 烘格:
            for y in range(y0, y1):
                for x in range(x0, x1):
                    if 像素[x, y] != 底色:
                        像素[x, y] = 底色
                        清 += 1

        # 连接线（剩下的橙）**抹掉**，不留在底图里：连接线由客户端单独一层画
        # （`忍术树连接线_<页签>.png`，从真机截图抠的）。留着会变成两层重影——
        # 符号烘的位置和真机画的位置差 6px（见 抠连接线 的说明）。
        橙 = 橙色掩码(图)
        改 = 0
        for y in range(高):
            for x in range(宽):
                if 橙[y, x]:
                    像素[x, y] = 底色
                    改 += 1

        # 连接线的**抗锯齿边**：上面的橙色阈值（R>120 且 R>B+40）漏掉了一圈半透明的边，
        # 底图上就留着一圈"钩子"和双线轮廓，客户端把真机抠的连接线层叠上去就是重影。
        # 这里再按**时间轴上 arrowN 的实例矩形**（含 1px 余量）精确擦一遍——
        # 箭头是按实例名摆在背景之上的，矩形之内除了箭头没有别的东西。
        擦箭头 = 0
        for (ax0, ay0, ax1, ay1) in 箭头矩形(符号, 要拉伸, (宽, 高)):
            for y in range(max(0, ay0), min(高, ay1)):
                for x in range(max(0, ax0), min(宽, ax1)):
                    if 像素[x, y] != 底色:
                        像素[x, y] = 底色
                        擦箭头 += 1

        os.makedirs(素材目录, exist_ok=True)
        出图 = os.path.join(素材目录, "忍术树底图_%s.png" % 名)
        图.save(出图)

        # 连接线包围盒：去色之后按亮度比底色亮一截的像素找
        a = np.asarray(图.convert("RGB"), dtype=np.int16)
        亮 = a.max(axis=2) > max(70, int(底色[0]) + 22)
        坐标表[名] = {
            "元件": 元件,
            "符号": 符号,
            "拉伸": 要拉伸,
            "格": [{"x": cx, "y": cy} for cx, cy in 取格子坐标(元件)],
            "元件里烘的格子框": [{"x0": x0, "y0": y0, "x1": x1, "y1": y1} for (x0, y0, x1, y1) in 烘格],
            # 每条连接线：指向哪一格 + 元件符号 + 运行时坐标 + 缩放。
            # 客户端按它**逐条**画（运行时就是逐条精灵，好按"已学变橙"切滤镜）。
            "箭头": 取箭头实例(元件),
        }
        print("%-6s 元件 %-26s 底 %-18s 抹掉烘格 %2d 个 / %5d 像素，抹连接线 %5d + 抗锯齿边 %5d 像素"
              % (名, 元件, str(底色), len(烘格), 清, 改, 擦箭头))
        print("       -> %s" % 出图)

    # 箭头美术（4 张，与页签无关，循环外做一次）
    画 = Image.open(os.path.join(素材目录, "忍术树底图_职业忍术.png")).convert("RGBA")
    for 符号id, 类名 in 箭头美术.items():
        箭 = 导出(符号id)
        箭产物 = os.path.join(素材目录, "忍术树箭头_%d.png" % 符号id)
        箭.save(箭产物)
        print("箭头 %-12s #%-4d %dx%d -> %s" % (类名, 符号id, 箭.width, 箭.height, 箭产物))

    说明 = ("忍术树各页签用的元件与坐标。"
            "「格」= AS3 `cells[]` 的**声明序**（下标与 数据/界面/技能分页.json 的「技能序」一一对应），"
            "坐标是元件局部坐标（面板 230x390 的原点）；客户端按它摆格子。"
            "「元件里烘的格子框」是从符号里量出来的烘死格子位置（已抹掉），留作核对。"
            "「箭头」= **运行时**的箭头精灵坐标（SkillPane4.setCellXY 会重摆 arrow1/3/5/7；"
            "SkillPane5.createArrow 是代码 new 的），「格」是它指向的下一个格子。"
            "连接线由客户端单独一层画（忍术树连接线_<页签>.png，从真机截图抠的），底图里已经清空。"
            "生成工具：开发工具/生成忍术树底图.py")
    os.makedirs(os.path.dirname(坐标产物), exist_ok=True)
    open(坐标产物, "w", encoding="utf-8").write(
        json.dumps({"_说明": 说明, "页签": 坐标表}, ensure_ascii=False, indent=1))
    print("-> %s" % 坐标产物)
    return 0


def _块(掩码: np.ndarray) -> list:
    """连通域包围盒（只回面积够大的）。"""
    高, 宽 = 掩码.shape
    已访 = np.zeros_like(掩码)
    出 = []
    for sy, sx in zip(*[v.tolist() for v in np.nonzero(掩码)]):
        if 已访[sy, sx]:
            continue
        队 = deque([(sy, sx)])
        已访[sy, sx] = True
        x0 = x1 = sx
        y0 = y1 = sy
        面积 = 0
        while 队:
            y, x = 队.popleft()
            面积 += 1
            x0, x1 = min(x0, x), max(x1, x)
            y0, y1 = min(y0, y), max(y1, y)
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < 高 and 0 <= nx < 宽 and 掩码[ny, nx] and not 已访[ny, nx]:
                    已访[ny, nx] = True
                    队.append((ny, nx))
        if 面积 >= 40:
            出.append((x0, y0, x1 + 1, y1 + 1))
    return sorted(出, key=lambda t: (t[1], t[0]))


if __name__ == "__main__":
    sys.exit(主())
