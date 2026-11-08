# -*- coding: utf-8 -*-
"""导出原版忍术详情区下半块的两块子面板（符号 905 / 900）并抹掉作者期占位内容。

- 905 `SkillStudyConditionPaneF` → 学习方法底板.png（未学时显示）
- 900 `SkillUpgradeConditionPaneF` → 升级条件底板.png（已学时显示，标题 `UI_56` = "升级条件"）

为什么需要它
------------
忍术详情区下半块在原版是 `SkillStudyConditionPaneF`（`SkillStudyConditionPane.as`）：
一个带卷云纹的框 + 需要等级 / 需要秘笈 / 来源三行 + 技能书图标框 + 学习按钮 + 拖动提示。
框里的那些行**是作者期烘在符号里的占位**（"需要等级：999"、《大力金刚指》、"Button"），
运行时全部由 AS3 重写（占位文字 `visible = false` 后换成 `BaseUtil.getLabel` 新建的 MLabel）。
直接拿来当底板就会多出一层假字。

做法与 §3.1 加点区（`生成加点属性底板.py`）同一条：只清作者期占位，不新造颜色、不动边框与卷云纹。

⚠️ 这个符号**不含框内底色**——实测框内是 `alpha=0` 全透明，棕色是详情区背景透上来的。
所以清理方式是**把占位像素的 alpha 置 0**，不是填色（填色会把框内涂死、盖住背景）。

⚠️ 原点对齐（2026-09-19 修）
---------------------------
ffdec `-export sprite` 出的 PNG **原点不是符号原点**。实测十几个符号后归纳出：

    PNG(0,0) = 符号( min(0, ⌊Xmin⌋), ⌊Ymin⌋ )

即 x 只裁负的部分、y 直接以包围盒顶边为原点。905 的包围盒是 (1,4)-(205,140)，
所以旧产物是 `PNG(150,25) = 符号(150,29)`——**客户端照"PNG 就是符号"摆就整体差 4px**，
而且下面那些标着"符号局部坐标"的擦除矩形其实也偏了 4px（905）/ (1,4)（900）。
现在统一**归一到 `PNG(0,0) = 符号(0,0)`**（900 左侧被裁掉的只有外框最外 1 列）。

⚠️ 三处只擦"看得见的东西"会踩的坑（都在这一版修掉了）
----------------------------------------------------
1. **别擦到外框**：905 的外框是「上边整条到 y=28、左边 x1..13、右边 x192..204、底边从 y≈127 渐隐」。
   占位文字从 x=14 起、第一行在 y=30——擦除矩形超出这个内区就会在外框上啃出缺口。
2. **按钮压着右边框**：905 的 `studyBtn`(#453) 摆在 (142,72)、57 宽，右端 199 **盖住了右边框**。
   整块擦掉会把边框一起擦出洞；擦完要用干净行的 x192..204 回填。
3. **拖动提示的残影**：底部的 `#896` 占位文字是**绿字 + 抗锯齿**，压在**外框底边的渐隐**上。
   旧版"只清绿色像素"把抗锯齿留下来，中灰底上一看就是一层鬼影。
   这里改成**按行重建**：取该行 x15..21（文字左边、干净）的颜色当基准，
   内区里凡是偏离基准的像素都回填成基准色——文字没了、外框的渐隐原样恢复。

要保留的：外框、两个卷云纹（905 还有右上角的**技能书图标框**、900 的「提升层数」按钮）。
要清掉的：占位文字、905 那个作者期的橙色 "Button"、底部的拖动提示。

用法
----
    python 开发工具/生成忍术详情底板.py

产物（原点都是符号原点，客户端直接摆在 AS3 给的运行时坐标上）
----
    素材/界面/原版窗口/忍术/学习方法底板.png   → 详情区 (2,246)
    素材/界面/原版窗口/忍术/升级条件底板.png   → 详情区 (4,246)
    （`SkillDetailPane` 构造函数：`--skillStudyConditionPane.x` / `++skillUpgradeConditionPane.x`）

    素材/界面/原版窗口/忍术/学习按钮_{常态,悬停,按下,禁用}.png  → 学习方法区内 (142,72)，61x22
    （`SkillStudyConditionPane.as:105` 把 57 宽的皮肤横向拉到 `UIConfig.btn_width_four`=61）

复现素材
--------
    ffdec-cli -selectid 905 -format sprite:png -export sprite <目录> MainLib.swf
"""

import importlib.util
import math
import os
import subprocess
import sys
from collections import Counter

from PIL import Image

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版目录 = r"2.2.3"
FFDEC = os.path.join(原版目录, "ffdec_26.2.1", "ffdec-cli.exe")
SWF = os.path.join(原版目录, "www", "act_web_nya_208_isolated", "asset", "MainLib.swf")
临时目录 = os.path.join(项目根, "..", ".scratch", "技能补数据", "元件")
素材目录 = os.path.join(项目根, "素材", "界面", "原版窗口", "忍术")

# 每块子面板的「阴影带」= (外区起点, 内界)：外区那一小条是**外框的柔光边缘**（不是实色边框，
# alpha 从 51% 渐隐到 0），占位文字会压在上面，所以那一带只能清「亮像素」，内界以右才整片清透明。
# 数值逐行扫出来的：905 柔光带 x1..13、内区从 14 起；900 柔光带 x0..11、内区从 12 起。
子面板 = {
    905: dict(
        类名="SkillStudyConditionPaneF",
        文件名="学习方法底板.png",
        阴影带=(1, 14),
        占位=[
            # 前四行占位文字（需要等级 / 需要秘笈 / 族贡·八门 / 来源分两行）。
            # x 只到 148：右边 150..190 是**要保留的技能书图标框**。
            ("需要等级行", (1, 30, 149, 46)),
            ("需要秘笈行", (1, 46, 149, 64)),
            ("族贡/八门行", (1, 64, 149, 82)),
            # 来源行（#902）在运行时不隐藏、由 AS3 重写文案，作者期那句必须清掉；
            # 它**换行了**（第二行「得秘籍」落在 y104..115），要一路清到 y118。
            ("来源行（含换行第二行）", (1, 82, 191, 118)),
            # ⚠️ 按钮整块擦：符号 905 上烘的是**作者期占位**（橙底 + "Button"），
            # 运行时是灰底 MButton3 +「学习」。擦到 x191 为止——右端 192..199 压着右边框柔光，
            # 交给下面的「回填边框」处理。
            # ⚠️ 右界要写到 **192**（矩形左闭右开）：按钮本体到 191 为止，
            # 而「回填边框」是从 192 起的 —— 收在 191 会**留下整整一列按钮像素**，
            # 药丸内部又是半透明的（alpha 136），实机看就是药丸右边透出一条橙线。
            ("烘焙的 Button（占位）", (1, 70, 192, 96)),
        ],
        # 底部拖动提示：整行重建（绿字 + 抗锯齿都清掉，外框底边渐隐原样恢复）
        拖动提示=(1, 191, 118, 138),
        参考列=(15, 21),
        # 按钮盖住的右边框柔光：从干净行回填（这一段外框在竖直方向是均匀的）
        回填边框=(192, 205, 70, 98, 110),
    ),
    900: dict(
        类名="SkillUpgradeConditionPaneF",
        文件名="升级条件底板.png",
        阴影带=(0, 12),
        占位=[
            # 三行的**标签与数值都是占位**（运行时 reqLevelText/reqCoinText/reqBreathText
            # 不隐藏，由 AS3 直接改文本）。x 只到 135：右边 136..173 是**要保留的「提升层数」按钮**。
            ("需要等级行", (0, 30, 136, 45)),
            ("金币消耗行", (0, 45, 136, 63)),
            ("精华消耗行", (0, 63, 136, 81)),
        ],
        # ⚠️ 「提升层数」那颗按钮**整块挖掉**，改由客户端自己画（`提升层数按钮.png`）。
        # 烘的那颗是作者期的 38 宽，而运行时 `upgradeBtn.width = 40` 会把它横向拉到 40；
        # 更要紧的是作者期那个字的**中心比药丸中心偏右 3px**（实测 650.5 vs 647.5），
        # 实机看就是"字体不在正中间、和边框不够适配"。
        # ⚠️ 这里曾经试过「把烘死的两行字整体左移 3px」——**失败**：
        # 行内众数只能把"字"和"底色"分开，分不出药丸自己的立体明暗，
        # 结果药丸的明暗也被跟着挪了，实机看就是"左移反而多出了一点图案"。已回退。
        # 作者期那两行字的中心比药丸中心**偏右 ~3.5px**（药丸 137..174、字 146.6..171.6 ——
        # 左边留 9.6、右边只剩 2.4），实机看就是"字贴在右边框上、没在图案中间"。
        # 运行时是 `upgradeBtn.tf.text = …` 由按钮自己居中，所以把字整体左移 3px。
        # ⚠️ 矩形必须收缩到**药丸内区**（137..174 / 33..73 往里留 4px）：
        # 上一版用了含外框的矩形，结果药丸的描边与立体明暗也被当成"字"挪走了 ——
        # 实机看就是"左移反而多出了一点图案"。
        # ⚠️ 药丸**保留**，但里面烘的那两行字**擦掉**：作者期烘的是 `#000000`（黑），
        # 而运行时 `MButton3.updateTextState()` 会用 `_textColors[state]` **覆盖**成
        # `up = 16577692 = #FCF49C`（浅金）+ `getGlowFilter(6824704=#682300)` 辉光 ——
        # 和页签/忍术境界同一族颜色。所以字交给客户端按运行时口径画（`忍术详情/升级条件区/提升层数/文字`）。
        擦字区=[("「提升层数」两行作者期黑字（运行时是浅金 #FCF49C）", (141, 36, 173, 70))],
        拖动提示=(0, 190, 118, 140),
        参考列=(13, 19),
        回填边框=None,
    ),
}


def _载入时间轴工具():
    路径 = os.path.join(项目根, "开发工具", "读符号时间轴.py")
    spec = importlib.util.spec_from_file_location("读符号时间轴", 路径)
    模块 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(模块)
    return 模块


def 导出符号(符号: int) -> Image.Image:
    os.makedirs(临时目录, exist_ok=True)
    子进程 = subprocess.run(
        [FFDEC, "-selectid", str(符号), "-format", "sprite:png", "-export", "sprite",
         临时目录, SWF],
        capture_output=True, text=True,
    )
    路径 = None
    for 名 in os.listdir(临时目录):
        if 名.startswith("DefineSprite_%d_" % 符号):
            候选 = os.path.join(临时目录, 名, "1.png")
            if os.path.exists(候选):
                路径 = 候选
    if 路径 is None:
        raise SystemExit("ffdec 没有导出符号 %d：%s" % (符号, 子进程.stdout + 子进程.stderr))
    return Image.open(路径).convert("RGBA")


def 归一到符号原点(图: Image.Image, 符号: int, 时间轴) -> Image.Image:
    """把导出图画布对齐到 `PNG(0,0) = 符号(0,0)`。"""
    文本 = 时间轴.读XML(时间轴.XML_默认)
    盒 = 时间轴.字符边界(文本, 符号)
    if 盒 is None:
        raise SystemExit("算不出符号 %d 的包围盒" % 符号)
    x0, y0, x1, y1 = 盒
    旧原点 = (min(0, math.floor(x0)), math.floor(y0))
    宽 = max(图.width + 旧原点[0], math.ceil(x1))
    高 = max(图.height + 旧原点[1], math.ceil(y1))
    新图 = Image.new("RGBA", (宽, 高), (0, 0, 0, 0))
    # 旧图(u,v) = 符号(u+ox, v+oy)；新图(X,Y) = 符号(X,Y) ⇒ 旧图(u,v) 摆到新图 (u+ox, v+oy)。
    新图.alpha_composite(图, (旧原点[0], 旧原点[1]))
    print("  导出 %dx%d，原点在符号 (%d,%d)，包围盒 (%g,%g)-(%g,%g) → 归一为 %dx%d"
          % (图.width, 图.height, 旧原点[0], 旧原点[1], x0, y0, x1, y1, 宽, 高))
    return 新图


## 「学习」按钮的皮肤 —— 符号 `#452 SkillWindowMButton_up`（57x22）。
##
## 为什么不是 `#453`：运行时那颗按钮**不是** 453 本体画的。
## `MButton3.init()` 把时间轴上的子件全部 `removeChild` 掉、只留文本框 `tf`，
## 皮肤用的是时间轴上那个**实例名叫 `upSkin`** 的对象（453 的第 3 层就是它）。
## 453 的扁平导出之所以是「橙底 + 英文 Button」，是因为作者期的 tf 里烘着占位文案。
## 运行时 `SkillStudyConditionPane.as:103` 把 `studyBtn.text` 设成 `CN.SKILL_STUDY_BTN` =「学习」，
## 尺寸则由 `:105` 的 `studyBtn.width = UIConfig.btn_width_four`(=61) 把 57 宽的皮肤横向拉到 61。
##
## 四个状态的颜色不是"调暗/调亮"近似，而是 `MButton3.updateState()` 给 upSkin 套的
## `StyleUtil` ColorMatrixFilter（`MButton3.as:392`），矩阵原文见 `StyleUtil.as`：
##   up       → `getLightFilter(skinFilters.up = 0)`   → RGB 偏移 0 = **单位矩阵（原样）**
##   over     → `getLightFilter(skinFilters.over = 30)`  → RGB 各 +30
##   down     → `getLightFilter(skinFilters.down = -40)` → RGB 各 -40
##   disabled → `getGrayFilter()`                       → 亮度灰度 (0.3086, 0.6094, 0.082)
## 四条矩阵的 alpha 行都是 `[0,0,0,1,0]`，所以 alpha 一律不动。
##
## ⚠️ 药丸内部是**半透明**的（实测 alpha=136/255），底色是详情区透上来的；
## 所以四张图只能**原样保留 alpha**，不能填底。
按钮皮肤符号 = 452
按钮态名 = [("常态", 0), ("悬停", 30), ("按下", -40), ("禁用", None)]


def 皮肤四态(图: Image.Image) -> list:
    """按上表的颜色矩阵出四张皮肤。`None` 表示走 getGrayFilter 的亮度灰度。"""
    import numpy as np
    数组 = np.asarray(图).astype(np.float64)
    rgb, 甲 = 数组[:, :, :3], 数组[:, :, 3:4].astype(np.uint8)
    出 = []
    for 名, 增量 in 按钮态名:
        if 增量 is None:
            亮度 = 0.3086 * rgb[:, :, 0] + 0.6094 * rgb[:, :, 1] + 0.082 * rgb[:, :, 2]
            新 = np.repeat(np.clip(np.rint(亮度), 0, 255)[:, :, None], 3, axis=2)
        else:
            新 = np.clip(np.rint(rgb + 增量), 0, 255)
        出.append((名, Image.fromarray(
            np.concatenate([新.astype(np.uint8), 甲], axis=2), "RGBA")))
    return 出


def _偏离(a, b, 容差=10) -> bool:
    return any(abs(a[i] - b[i]) > 容差 for i in range(4))


def _亮(p, 阈值=80) -> bool:
    """占位文字的像素判定：外框的柔光是暗色（三通道都 ≤ 25），文字随便哪个通道都远超它。"""
    return max(p[0], p[1], p[2]) > 阈值


def 清一块(图, 配置) -> int:
    宽, 高 = 图.size
    像素 = 图.load()
    外区, 内界 = 配置["阴影带"]
    清 = 0

    def 擦(y, x0, x1):
        """内区一律清成透明；左侧那条柔光带只清「亮像素」，免得把外框啃掉。"""
        n = 0
        for x in range(x0, min(x1, 宽)):
            p = 像素[x, y]
            if p[3] > 0 and (x >= 内界 or _亮(p)):
                像素[x, y] = (0, 0, 0, 0)
                n += 1
        return n

    for 名, (_, y0, x1_, y1) in 配置["占位"]:
        本区 = 0
        for y in range(y0, min(y1, 高)):
            本区 += 擦(y, 外区, x1_)
        清 += 本区
        print("  擦 %-22s y=%d..%d x=%d..%d  %d 像素" % (名, y0, y1 - 1, 外区, x1_ - 1, 本区))

    # 拖动提示：按行重建。基准色取该行「参考列」（文字左边、外框之内）的众数，
    # 内区里偏离基准的像素一律回填基准色 —— 文字与抗锯齿消失，外框的渐隐保持原样。
    x0, x1, y0, y1 = 配置["拖动提示"]
    rx0, rx1 = 配置["参考列"]
    本区 = 0
    for y in range(y0, min(y1, 高)):
        本区 += 擦(y, 外区, 内界)
        基准 = Counter(像素[x, y] for x in range(rx0, rx1)).most_common(1)[0][0]
        for x in range(内界, min(x1, 宽)):
            if _偏离(像素[x, y], 基准) and 像素[x, y][3] > 0:
                像素[x, y] = 基准
                本区 += 1
    清 += 本区
    print("  擦 %-22s y=%d..%d x=%d..%d  %d 像素（按行重建，含抗锯齿）"
          % ("拖动提示（占位）", y0, y1 - 1, 外区, x1 - 1, 本区))

    # 「把烘死的字擦掉、只留底」的区域（底色按行取众数回填，保住药丸的竖向渐变）。
    for 名, (x0, y0, x1, y1) in 配置.get("擦字区", []):
        本区 = 0
        for y in range(y0, min(y1, 高)):
            行 = [tuple(像素[x, y]) for x in range(x0, min(x1, 宽))]
            if not 行:
                continue
            底 = Counter(行).most_common(1)[0][0]
            for i, 像 in enumerate(行):
                if max(abs(像[k] - 底[k]) for k in range(3)) > 45:
                    像素[x0 + i, y] = 底
                    本区 += 1
        清 += 本区
        print("  擦字 %-24s (%d,%d)-(%d,%d)  %d 像素" % (名[:24], x0, y0, x1, y1, 本区))

    # 「把烘死的字整体平移」的区域。
    # 为什么不是"让客户端重画"：作者期那两行字的中心比药丸中心偏右 3px（实测字 636..665
    # 贴在药丸右边 665 上），而运行时是 `upgradeBtn.tf.text = ...` 由按钮自己居中。
    # 试过让客户端用 Godot 字体重画 —— **Godot 的中文字面比 Flash 大**，12px、11px 两档都撑破药丸，
    # 所以退回"留住原美术、只把字挪正"。
    for 名, (x0, y0, x1, y1), dx in 配置.get("移字区", []):
        新片 = {}
        本区 = 0
        for y in range(y0, min(y1, 高)):
            行 = [tuple(像素[x, y]) for x in range(x0, min(x1, 宽))]
            if not 行:
                continue
            底 = Counter(行).most_common(1)[0][0]
            干净 = [底 if 像 != 底 else 像 for 像 in 行]
            画 = list(干净)
            for i, 像 in enumerate(行):
                if 像 != 底:
                    目标 = i + dx
                    if 0 <= 目标 < len(画):
                        画[目标] = 像
                        本区 += 1
            for i, 像 in enumerate(画):
                新片[(x0 + i, y)] = 像
        for (x, y), 像 in 新片.items():
            像素[x, y] = 像
        清 += 本区
        print("  移字 %-24s (%d,%d)-(%d,%d) dx=%d  %d 像素" % (名[:24], x0, y0, x1, y1, dx, 本区))

    # 「整块挖掉、用底色回填」的区域。
    # ⚠️ 前两类占位在**框内**，那里底色 alpha=0（棕是详情区透上来的），清成透明是对的；
    # 但 900 的「提升层数」按钮那一带**是不透明的**（药丸 + 面板底），
    # 擦透明会挖个洞、透出详情区 —— 所以按列取"行外"的底色回填，保住药丸那一圈的底。
    for 名, (x0, y0, x1, y1) in 配置.get("回填区", []):
        参考 = {}
        for x in range(x0, min(x1, 宽)):
            样 = [像素[x, y] for y in range(max(0, y0 - 6), max(0, y0 - 2))]
            样 += [像素[x, y] for y in range(min(y1 + 1, 高 - 1), min(y1 + 5, 高))]
            if 样:
                参考[x] = Counter(样).most_common(1)[0][0]
        本区 = 0
        for y in range(y0, min(y1, 高)):
            for x in range(x0, min(x1, 宽)):
                if x not in 参考:
                    参考[x] = 像素[x, y0 - 3] if y0 >= 3 else 像素[x, y]
                底 = 参考[x]
                if 像素[x, y] != 底:
                    像素[x, y] = 底
                    本区 += 1
        清 += 本区
        print("  回填 %-20s (%d,%d)-(%d,%d)  %d 像素（按列取行外底色）" % (名, x0, y0, x1, y1, 本区))

    # 按钮压住的那段外框：整列从干净行回填（外框在这一段垂直方向是均匀的）
    if 配置.get("回填边框"):
        bx0, bx1, by0, by1, 参考行 = 配置["回填边框"]
        本区 = 0
        for y in range(by0, min(by1, 高)):
            for x in range(bx0, min(bx1, 宽)):
                if 像素[x, y] != 像素[x, 参考行]:
                    像素[x, y] = 像素[x, 参考行]
                    本区 += 1
        清 += 本区
        print("  补 %-20s (%d,%d)-(%d,%d)  从 y=%d 回填  %d 像素"
              % ("被按钮盖住的右边框", bx0, by0, bx1, by1, 参考行, 本区))
    return 清


def 主() -> int:
    os.makedirs(素材目录, exist_ok=True)
    时间轴 = _载入时间轴工具()
    for 符号, 配置 in sorted(子面板.items()):
        图 = 导出符号(符号)
        不透明 = sum(1 for y in range(图.height) for x in range(图.width) if 图.load()[x, y][3] > 0)
        print("符号 %d %s 导出 %dx%d，非透明 %d 像素"
              % (符号, 配置["类名"], 图.width, 图.height, 不透明))
        图 = 归一到符号原点(图, 符号, 时间轴)
        清 = 清一块(图, 配置)
        产物 = os.path.join(素材目录, 配置["文件名"])
        图.save(产物)
        print("  共动 %d 像素 -> %s (%dx%d)" % (清, 产物, 图.width, 图.height))
    # 「提升层数」按钮的美术（#729 SkillWindowUpgradeBtnF，38x40）——
    # 底板里那颗挖掉之后由客户端自己画：与 AS3 一致地拉到 40 宽，字交给 Godot 居中。
    钮 = 导出符号(729)
    钮产物 = os.path.join(素材目录, "提升层数按钮.png")
    钮.save(钮产物)
    print("  按钮美术 %dx%d -> %s" % (钮.width, 钮.height, 钮产物))

    # 「学习」按钮的皮肤：四态各一张（矩阵见 按钮皮肤符号 上面的注释）。
    # 原图要先归一到符号原点（452 的包围盒是 (0,0)-(57,22)，本例不裁，但别依赖这一点）。
    皮肤 = 归一到符号原点(导出符号(按钮皮肤符号), 按钮皮肤符号, 时间轴)
    for 名, 图 in 皮肤四态(皮肤):
        产物 = os.path.join(素材目录, "学习按钮_%s.png" % 名)
        图.save(产物)
        print("  学习按钮 %-4s %dx%d -> %s" % (名, 图.width, 图.height, 产物))
    print()
    print("摆放：学习方法底板 @ 详情区 (2,246)、升级条件底板 @ (4,246)")
    return 0


if __name__ == "__main__":
    sys.exit(主())
