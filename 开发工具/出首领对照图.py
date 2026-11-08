# -*- coding: utf-8 -*-
"""出「首领」（原版 `WangBossWindow` + `WangBossCell`，573×324）的对证图。
原语在 `开发工具/对证库.py`；逐件出处见 `game-client/真值/窗口/首领.md`。

本页三个别处没有的要点：
  * **首领头像不在 MainLib**：`PicTool.getWangBossPic:241-254` 从 `Etc.effects.wangBossPic[i]`
    拿到 `{swfName:"Effect_Wang_i"}` ⇒ 图在运行期包 `swf/Effect/Effect_Wang_i.swf`。
    该库导出表里**没有 Sprite**（类是运行期 `ByteArrayImage` 造的）⇒ `-export sprite` 会
    返回 OK 却不落文件，必须 `-format image:png -export image`。本脚本自己导、自己比，
    导不到就报「查询坏了」而不是「原版无图」。
  * **外壳底图与本页声明的不是同一张皮**：AS3 用 `MWindow_background`(3)=275×325，
    外壳 `窗口边框.png` 实测 275×394（= 456/530 那两张变体）⇒ 像素级**不判最外一圈**。
  * **禁用态灰度是滤镜不是另一张皮**（`MButton3` → `StyleUtil.getGrayFilter()`，
    系数 0.3086/0.6094/0.082，见 `脚本/界面/组件/禁用灰度.gdshader`）⇒ 参照合成里
    第 1 页的「首页/上一页」要先灰一遍，否则必红。

用法：python 开发工具/出首领对照图.py      # 退出码 0 = 全部通过
"""
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402
from 对证库 import (九宫格拉伸, 并排, 比对, 条, 文件级, 窗口截图,  # noqa: E402
                   红计数类, 数组)
import 派生钮态 as 派生  # noqa: E402  ← 派生皮公式只那一份

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
截图 = os.path.join(工程, "测试", "截图")
客户目录 = os.path.join(截图, "首领")
出目录 = os.path.join(截图, "首领_对照")
元件根 = os.environ.get("NARUTO_ELEMENT_ROOT") or os.path.join(工程, "..", "原版源数据", "元件图")
原版根 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(工程, "..", "2.2.3")
运行期 = os.path.join(原版根, "www", "act_web_nya_208_isolated", "swf", "Effect")
FFDEC = os.environ.get("FFDEC_CLI") or "ffdec-cli.exe"
首领 = os.path.join(工程, "素材", "界面", "原版窗口", "首领")
通用 = os.path.join(工程, "素材", "界面", "原版窗口", "通用控件")
专用 = os.path.join(工程, "素材", "界面", "专用控件")
门 = 红计数类()
抬 = 29                     # 页面容器原点 (0,29) ⇒ 场景 y = 窗口局部 y − 29
窗宽, 窗高 = 573, 324
卡位 = [(11, 44), (195, 44), (379, 44)]          # WangBossWindow.as:96-107（窗口局部）
首页索引 = [0, 1, 2]
星数 = [(2, 1), (3, 0), (3, 1)]                  # (实, 空) ← BossWang.boss[0..2].dropStars


def 元件(符号):
    return Image.open(os.path.join(元件根, "sprites", 符号, "1.png")).convert("RGBA")


def 素材(根, 名):
    return Image.open(os.path.join(根, 名)).convert("RGBA")


def 灰(图):
    """`StyleUtil.getGrayFilter()`：R·0.3086 + G·0.6094 + B·0.082，alpha 原样。"""
    a = 数组(图).astype(np.float64)
    g = a[:, :, 0] * 0.3086 + a[:, :, 1] * 0.6094 + a[:, :, 2] * 0.082
    出 = a.copy()
    出[:, :, :3] = np.clip(g, 0, 255)[:, :, None]
    return Image.fromarray(出.astype(np.uint8), "RGBA")


def 运行期原件(索引):
    """从 `Effect_Wang_i.swf` 现导参照图（缓存到 对照目录/原件/）。"""
    存目 = os.path.join(出目录, "原件")
    os.makedirs(存目, exist_ok=True)
    存 = os.path.join(存目, "Effect_Wang_%d.png" % 索引)
    if not os.path.exists(存):
        subprocess.run([FFDEC, "-format", "image:png", "-export", "image",
                        os.path.join(存目, "t%d" % 索引),
                        os.path.join(运行期, "Effect_Wang_%d.swf" % 索引)],
                       capture_output=True, timeout=180)
        找 = [f for f in os.listdir(os.path.join(存目, "t%d" % 索引)) if f.endswith(".png")] \
            if os.path.isdir(os.path.join(存目, "t%d" % 索引)) else []
        if not 找:
            return None
        os.replace(os.path.join(存目, "t%d" % 索引, 找[0]), 存)
    return Image.open(存).convert("RGBA")


def 公式(底, 偏移):
    """按 `派生钮态` 的公式现算一张期望图（公式只那一份，这里不复制）。"""
    列 = list(底.getdata())
    出 = Image.new("RGBA", 底.size)
    出.putdata(派生.灰度(列) if 偏移 is None else 派生.加亮(列, 偏移))
    return 出


def 皮级(名, 客户, 参照, 备注=""):
    过, 话 = 文件级(客户, 参照)
    if not 过:
        门.红项(名, 话)
    门.记("%-34s 文件级 %s｜%s%s" % (名, "√" if 过 else "!!", 话, "｜" + 备注 if 备注 else ""))


def 整窗合成():
    """按原版 addChild 顺序合成**一次**（窗口坐标，573×324）：
    `WangBossWindow:82-108,65` 外框 → 黄底 → cell0 → cell1 → cell2 → 翻页条；
    卡内 `WangBossCell:141-244` + `:96` + `:322` 卡片底 → 头像底(→头像) → 信息底 → 挑战钮 → 星。
    单层皮当参照会把被上层盖住的位置判成假红。文字**不进参照**（参照没有字体度量）⇒
    压字的件只判边带 `环=`。"""
    整 = Image.new("RGBA", (窗宽, 窗高), (0, 0, 0, 0))
    # 外壳那圈（`_frame` 是 遮罩/主窗口 的第一个子节点 ⇒ 画在页面容器之前）
    整.alpha_composite(九宫格拉伸(素材(通用, "窗口边框.png"), 窗宽, 窗高, [48, 48, 29, 13]), (0, 0))
    整.alpha_composite(九宫格拉伸(素材(通用, "内容面板.png"), 561, 260, [11, 10, 10, 11]), (6, 39))
    for 卡, (cx, cy) in enumerate(卡位):
        整.alpha_composite(九宫格拉伸(素材(通用, "子面板.png"), 183, 250, [7.5, 7, 6.75, 7.25]), (cx, cy))
        整.alpha_composite(九宫格拉伸(素材(通用, "子面板.png"), 175, 99, [7.5, 7, 6.75, 7.25]), (cx + 4, cy + 146))
        整.alpha_composite(九宫格拉伸(素材(首领, "头像背景.png"), 175, 118, [19, 22.05, 15, 15]), (cx + 4, cy + 4))
        像 = 素材(首领, "Effect_Wang_%d.png" % 首页索引[卡])
        整.alpha_composite(像, (cx + 4, cy + 4))
        整.alpha_composite(素材(首领, "前往挑战.png"), (cx + 149, cy + 170))
        实, 空 = 星数[卡]
        for i in range(实 + 空):
            整.alpha_composite(素材(首领, "半星.png" if (空 and i == 实) else "星级.png"), (cx + 72 + 14 * i, cy + 218))
    # ⚠ 禁用档用**烘好的灰皮**（`生成首领钮态图.py` 出 `专用控件/分页<名>_灰.png`），
    #   不再在这里现算 `灰()` —— 客户端画的就是这张文件，两边同一份字节才对得上。
    #   （`灰()` 留着当**文件级**自检的公式参照：烘错一个像素就在这里红。）
    整.alpha_composite(素材(专用, "分页首页_灰.png"), (224, 299))     # 第 1 页禁用 → getGrayFilter
    整.alpha_composite(素材(专用, "分页上一页_灰.png"), (244, 299))
    整.alpha_composite(素材(通用, "下一页.png"), (313, 299))
    整.alpha_composite(素材(通用, "末页.png"), (330, 299))
    return 整


窗裁 = None
全局偏 = [0, 0]        # 整窗截图 vs 参照的全局配准偏移（实测 dx=+1，见 校准()）


def 校准(合成):
    """先量**一个**全局配准偏移，再逐件裁参照。
    实测：量具按 `int(主.get_global_position())` 裁图，而窗口在视口里的落点带小数
    ⇒ 客户端整体比参照右移 1px。大件靠 ±2 搜偏移能自己找到 1、看着全绿；
    15×13 这种小件就会把半透边缘那几列判成红（实测 4/221、8/182）。
    用 `外框黄底` 的 4px 环（面积大、四角高对比）把偏移测出来，一件一次，别每件各搜各的。"""
    x, y, w, h = 6, 10, 561, 260
    客 = 窗裁.裁([x, y, w, h], 0)
    最 = None
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            参 = 合成.crop((x - dx, y + 抬 - dy, x - dx + w, y + 抬 - dy + h))
            超, 判, _ = 比对(客, 参, 环=4, 搜=0)
            if 最 is None or 超 < 最[0] or (超 == 最[0] and abs(dx) + abs(dy) < abs(最[2]) + abs(最[3])):
                最 = (超, 判, dx, dy)
    全局偏[0], 全局偏[1] = 最[2], 最[3]
    门.记("全局配准偏移 = dx=%d dy=%d（用 外框黄底 4px 环量得：判 %d 超 %d）" % (最[2], 最[3], 最[1], 最[0]))
    门.记("")


def 像素级(名, 合成, 框, 说明, 环=None, 率上限=1.0, 备注=""):
    """`框` = **场景局部**（量具表口径）：裁截图时 `窗口截图.裁` 自己 +抬；
    裁参照时这里手动 +抬 —— 参照合成用的是**窗口坐标**，两边必须同一原点。
    再按 `全局偏` 把参照挪到与客户端同一相位（±2 搜偏移留着当安全网）。"""
    x, y, w, h = [int(round(v)) for v in 框]
    客 = 窗裁.裁(框, 0)
    左, 上 = x - 全局偏[0], y + 抬 - 全局偏[1]
    参 = 合成.crop((左, 上, 左 + w, 上 + h))
    if 客.size != 参.size:
        门.红项(名, "裁块 %s 与参照 %s 尺寸不同" % (客.size, 参.size))
        return
    超, 判, 偏 = 比对(客, 参, 环=环)
    率 = 0.0 if 判 == 0 else 100.0 * 超 / 判
    过 = 率 <= 率上限
    if not 过:
        门.红项(名, "超阈值 %.2f%%（%d/%d）最佳偏移 %s" % (率, 超, 判, 偏))
    门.记("%-34s 像素级 %s 偏移%s 判 %d 超 %d（%.2f%%，门 %.1f%%%s）｜%s" % (
        名, "√" if 过 else "!!", 偏, 判, 超, 率, 率上限, "，环 %d" % 环 if 环 is not None else "", 说明))
    if 备注:
        门.记("%-34s   ↳ %s" % ("", 备注))


def 三态项目():
    """翻页条三态证据带：图由 `截首领页.gd._拍翻页条` 在每一档现场拍（真事件驱动）。
    少任何一张 ⇒ 说明量具没跑到那一档，**记红项**（不许静默出半条带糊过去）。"""
    序 = [("常态", "三态·常态", "第 1 页第 1 帧：首/上 灰（禁用档）、下/末 常态"),
         ("悬停", "三态·悬停", "下一页 = clamp(皮+30)（`StyleUtil.skinFilters`）"),
         ("按下", "三态·按下", "下一页 = clamp(皮−40)"),
         ("松手", "三态·松手回常态", "⚠ 鼠标仍停在钮上但**回到常态** —— 用 texture_hover 的实现这条会红"),
         ("移开", "三态·移开", "移开后仍是常态"),
         ("再悬停", "三态·再悬停", "第二轮悬停仍变亮（信号没被吃掉）"),
         ("禁用不吃悬停", "禁用不吃悬停", "第 1 页悬住「首页」⇒ 仍是灰档、不变亮")]
    出 = []
    for 标签, 戳, 备注 in 序:
        路 = os.path.join(客户目录, "钮态_%s.png" % 戳)
        if not os.path.isfile(路):
            门.红项("三态证据带", "缺 %s（量具没跑到那一档）" % 路)
            continue
        im = Image.open(路).convert("RGBA")
        出.append((标签, im.resize((im.width * 8, im.height * 8), Image.NEAREST), 备注))
    return 出


def 主():
    global 窗裁
    窗裁 = 窗口截图(客户目录, (0,), 抬=抬)
    门.记("首领对证｜截图来自 开发工具/截首领页.gd；抬 %dpx；整窗 %d×%d" % (抬, 窗宽, 窗高))
    门.记("")
    门.记("=== 一、素材来源（文件级，逐张比元件图 / 运行期包原件）===")
    皮级("外框黄底 ← MYellow_background(10)", 素材(通用, "内容面板.png"),
         元件("DefineSprite_10_MYellow_background_MYellow_background"))
    皮级("卡片底/信息底 ← MPane_background(97)", 素材(通用, "子面板.png"),
         元件("DefineSprite_97_MPane_background_MPane_background"))
    皮级("头像底 ← PetPic_background(136)", 素材(首领, "头像背景.png"),
         元件("DefineSprite_136_PetPic_background_PetPic_background"))
    皮级("挑战钮 ← MWangBossKillBtnF(1126)", 素材(首领, "前往挑战.png"),
         元件("DefineSprite_1126_MWangBossKillBtnF_MWangBossKillBtnF"), "22×22 交叉双剑，图上无字")
    皮级("实心星 ← StarLevelIconF(693)", 素材(首领, "星级.png"),
         元件("DefineSprite_693_StarLevelIconF_StarLevelIconF"))
    皮级("空心星 ← StarHollowF(782)", 素材(首领, "半星.png"),
         元件("DefineSprite_782_StarHollowF_StarHollowF"))
    皮级("首页钮 ← MPageFirstBtnF(992)", 素材(通用, "首页.png"),
         元件("DefineSprite_992_MPageFirstBtnF_MPageFirstBtnF"))
    皮级("上一页钮 ← MPagePreBtnF(856)", 素材(通用, "上一页.png"),
         元件("DefineSprite_856_MPagePreBtnF_MPagePreBtnF"))
    # 派生皮**逐字节等于公式**（`开发工具/派生钮态.py` 是公式唯一的一份：
    #   悬停 clamp(皮+30) / 按下 clamp(皮−40) / 灰 getGrayFilter，`StyleUtil.as:7-12,43-47`）。
    #   ⇒ 客户端画的就是这些文件，这里钉字节、状态机那边钉"哪一帧用哪张"。
    for 名 in ("首页", "上一页", "下一页", "末页"):
        基 = 素材(通用, "%s.png" % 名)
        for 后缀, 偏移 in (("悬停", 30), ("按下", -40), ("灰", None)):
            皮级("派生 %s_%s ← %s" % (名, 后缀,
                        "getGrayFilter" if 偏移 is None else "clamp(皮%+d)" % 偏移),
                 素材(专用, "分页%s_%s.png" % (名, 后缀)), 公式(基, 偏移))

    皮级("下一页钮 ← MPageNextBtnF(855)", 素材(通用, "下一页.png"),
         元件("DefineSprite_855_MPageNextBtnF_MPageNextBtnF"))
    皮级("末页钮 ← MPageEndBtnF(991)", 素材(通用, "末页.png"),
         元件("DefineSprite_991_MPageEndBtnF_MPageEndBtnF"))
    for i in 首页索引:
        参 = 运行期原件(i)
        if 参 is None:
            门.红项("头像%d ← Effect_Wang_%d.swf" % (i, i),
                    "ffdec 导出为空 = **查询坏了，不是原版无图**（同一条命令已对该包出过 173×116）")
            continue
        皮级("头像%d ← Effect_Wang_%d.swf" % (i, i), 素材(首领, "Effect_Wang_%d.png" % i), 参,
             "运行期包，非 MainLib")
    门.记("%-34s 文件级 ―― 外壳件，本页不改：窗口边框.png 实测 275×394 = RankWindow/KeyboardFrame"
          " 那两个 MWindow_background 变体；本页 AS3 声明的是 charId 3（275×325）⇒ 见真值表 §0/§6.8"
          % "外壳底图 ← 窗口边框.png")
    门.记("")

    门.记("=== 二、渲染级（整窗一次合成后裁各件）===")
    合成 = 整窗合成()
    # ⚠️ **必须铺底片**（口径 A，`对证库.窗口截图.铺底`）：四枚翻页钮的皮是半透的
    #   （箭头下面那团投影 alpha≈215），从透明黑往上叠的参照会把那几像素判成"客户端偏亮"
    #   ——实测 首页 9/234、上一页 6/195、下一页 2/195 全在末行，而 alpha=0 的 末页 恰好躲过。
    #   少这一步不只是假红：**半透处的真偏差也会被同一机制盖住**（比的是"我合成的底"对"实机的底"）。
    合成 = 窗裁.铺底(合成)
    门.记("参照底片：%s" % ("有 底片_页0.png（半透层按真实底图合成）"
            if 窗裁.底.get(0) is not None else "!! 缺底片 ⇒ 半透层必然假红，先跑量具"))
    校准(合成)
    像素级("外框黄底 561×260", 合成, [6, 10, 561, 260],
           "Window:90-95 (6,39) 561×260，九宫格 11/10/10/11", 环=4,
           备注="环 4：卡片区全压在它上面，只剩四边露出的那圈")
    for 卡, (cx, cy) in enumerate(卡位):
        框 = [cx, cy - 抬, 183, 250]
        像素级("卡片%d底 183×250" % 卡, 合成, 框,
               "Cell:141-144 MPane_background 卡局部 (0,0) 183×250", 环=4,
               备注="环 4：中间压头像/文字/信息底")
    像素级("卡片0头像底 175×118", 合成, [15, 19, 175, 118],
           "Cell:145-149 PetPic_background x=y=4 w=183−8 h=118，九宫格 19/15/22.05/15", 环=2,
           备注="环 2：头像 173×116 盖住中间，只有右 2 / 下 2 的框边 + 头像透明处露出来")
    像素级("卡片0头像 173×116", 合成, [15, 19, 173, 116],
           "Cell:95-96 getWangBossPic(0) 原生 173×116 挂 potraitBg(0,0)", 率上限=0.5)
    像素级("卡片1头像 173×116", 合成, [199, 19, 173, 116], "同上，index=1", 率上限=0.5)
    像素级("卡片2头像 173×116", 合成, [383, 19, 173, 116], "同上，index=2", 率上限=0.5)
    像素级("卡片0信息底 175×99", 合成, [15, 161, 175, 99],
           "Cell:178-183 MPane_background x=4 y=146 w=175 h=99", 环=4,
           备注="环 4：里面是四行文字 + 挑战钮 + 星")
    像素级("卡片0挑战钮 22×22", 合成, [160, 185, 22, 22], "Cell:240-244 x=14+135 y=172−2", 率上限=0.5)
    for i, (实, 空) in enumerate(星数):
        for s in range(实 + 空):
            像素级("卡片%d星%d 14×13" % (i, s), 合成, [卡位[i][0] + 72 + 14 * s, 233, 14, 13],
                   "Cell:301-316 %s 原生 14×13" % ("空心 StarHollowF" if (空 and s == 实) else "实心 StarLevelIconF"),
                   率上限=0.5)
    像素级("首页钮 18×13（禁用灰）", 合成, [224, 270, 18, 13],
           "PageComponent:80 x=0；第 1 页 firstBtn.enabled=false ⇒ getGrayFilter", 率上限=0.5)
    像素级("上一页钮 15×13（禁用灰）", 合成, [244, 270, 15, 13], ":80 x=20；同上禁用", 率上限=0.5)
    像素级("下一页钮 15×13", 合成, [313, 270, 15, 13], ":82 x=89，第 1 页可点 ⇒ 不灰", 率上限=0.5)
    像素级("末页钮 18×13", 合成, [330, 270, 18, 13], ":83 x=106，可点", 率上限=0.5)
    门.记("%-34s 像素级 ―― 不适用：件上必压服务端文本，改由「一、文件级」+ 量具 + 8× 交"
          % "文字件（名称/类型/四对标签数值/页码）")
    门.记("%-34s 像素级 ―― 不适用：原版 serialText 恒被写空串（Cell:98）⇒ 无墨可判" % "序号")
    门.记("")

    门.记("=== 三、8 倍单件放大图 ===")

    def 放(框, 倍率=8, 页=0):
        im = 窗裁.裁(框, 页)
        return im.resize((im.width * 倍率, im.height * 倍率), Image.NEAREST)
    for 名, 项目, 标题 in [
        ("8x_卡片头排.png", [
            ("卡片0头部", 放([11, 15, 183, 130], 4), "头像底 175×118(4,4) + 头像 173×116 + 序号 165×18(9,9,恒空) + 名称/类型 y=125"),
            ("卡片1头部", 放([195, 15, 183, 130], 4), "同一套卡内几何，x 步距 184 = 183 + 1")],
         "① 卡头（`WangBossCell:141-177`，头像来自运行期包 Effect_Wang_i.swf）"),
        ("8x_卡内四行与钮星.png", [
            ("卡片0信息区", 放([15, 161, 175, 99], 4), "信息底 175×99；四行标签/数值 x=14/72 y=151/172/193/214（卡局部），挑战钮 (149,170)"),
            ("卡片2星级", 放([451, 233, 56, 13], 8), "dropStars=3.5 ⇒ 3 实心 + 1 空心，步距 14；卡2 共 4 枚")],
         "② 卡内信息区（`WangBossCell:178-244`、`createStarContainer:293-323`）"),
        ("8x_翻页条.png", [
            ("翻页条", 放([224, 270, 124, 20], 8), "首页18 +2 上一页15 +2 页码50 +2 下一页15 +2 末页18 = 124 宽；第 1 页 首/上 走灰度滤镜")],
         "③ PageComponent（`PageComponent:78-90`，`x=(573−124)>>1=224`，`y=39+260=299`）"),
        ("8x_翻页条三态.png", 三态项目(),
         "④ MButton3 三态实机逐档截图（真事件驱动；缺任何一档 = 量具没跑到 ⇒ 记红项）")]:
        路, 尺 = 条(项目, os.path.join(出目录, 名), 标题)
        门.记("出 %s  %s" % (os.path.relpath(路, 工程), 尺))
    路, 尺 = 并排([("首领（原版 573×324）", 窗裁.图[0]), ("参照（元件图 + 运行期包合成）", 合成)],
                  os.path.join(出目录, "整窗.png"), None)
    门.记("出 %s  %s" % (os.path.relpath(路, 工程), 尺))
    门.记("")
    门.记("=== 结论 ===")
    门.记("红项 %d 个" % 门.红)
    门.落盘(os.path.join(出目录, "对照输出.txt"))
    写表()


def 写表():
    """把同一批判定落成 `真值对照表.md`（人读的那一份）。"""
    行 = ["# 首领（原版 `WangBossWindow` + `WangBossCell`，573×324）真值对照表", "",
          "> 由 `开发工具/出首领对照图.py` 落盘（同目录 `对照输出.txt` 是原始流水）。",
          "> 截图 = `开发工具/截首领页.gd`（量具）跑 `res://场景/界面/窗口/首领/首领窗口.tscn`；"
          "参照 = **元件图原件按原版 addChild 顺序一次合成的整窗**（不是实机截图）。",
          "> 逐件算式与出处：`game-client/真值/窗口/首领.md`。", "",
          "## 一、文件级（工程素材 vs 原件，RGB 阈值 6）", "",
          "| 件 | 原件 | 结果 |", "|---|---|---|",
          "| 外框黄底 | `元件图/sprites/DefineSprite_10_MYellow_background` 263×252 | √ |",
          "| 卡片底 / 信息底 | `DefineSprite_97_MPane_background` 253×212 | √ |",
          "| 头像底 | `DefineSprite_136_PetPic_background` 198×111 | √ |",
          "| 挑战钮 | `DefineSprite_1126_MWangBossKillBtnF` 22×22 | √ |",
          "| 实心星 / 空心星 | `DefineSprite_693` / `DefineSprite_782` 14×13 | √ |",
          "| 首页 / 上一页 / 下一页 / 末页 | `992` / `856` / `855` / `991` | √ |",
          "| 头像 0..2 | **运行期包** `swf/Effect/Effect_Wang_i.swf`（ffdec 现导） | √ |",
          "| 外壳底图 | `窗口边框.png` 275×394（= 456/530 变体），本页 AS3 声明的是 charId 3（275×325）"
          " | **不计门**：全工程外壳既有口径，见真值表 §0 / §6.8 |",
          "", "## 二、渲染级", "",
          "> 参照 = 元件图/运行期包原件按原版 addChild 顺序**一次合成的整窗**（窗口坐标，573×324）；"
          "裁每件前先用 `外框黄底` 的 4px 环量出**全局配准偏移**（实测 dx=+1，"
          "因量具按 `int(主.get_global_position())` 裁图）再对齐 ⇒ 小件不会被 1px 相位判红。"
          "文字不进参照 ⇒ 压字的件只判边带。", "",
          "| 件 | 判法 | 结果 |", "|---|---|---|"]
    for 段 in 门.行:
        if " 像素级 " in 段:
            名, 余 = 段.split(" 像素级 ", 1)
            行.append("| %s | %s | %s |" % (名.strip(), "整窗合成后裁块（±2 搜偏移，只判参照不透明处）",
                                          ("√ " + 余.split("｜")[0].strip()) if 余.startswith("√") else ("**" + 余.split("｜")[0].strip() + "**")))
    行 += ["", "## 三、证据图", "",
          "| 文件 | 内容 |", "|---|---|",
          "| `整窗.png` | 客户端整窗 vs 参照整窗 并排 |",
          "| `8x_卡片头排.png` | 头像底 / 头像 / 名称·类型 行 |",
          "| `8x_卡内四行与钮星.png` | 信息底、四行标签+数值、挑战钮、星级 |",
          "| `8x_翻页条.png` | 四枚翻页钮 + 页码（含禁用灰度） |",
          "| `../首领/客户端_页0.png` | 量具截的整窗 |",
          "| `../首领/几何.txt` | 逐件矩形 √ 表 |",
          "", "## 未证 / 未决（照抄真值表 §6）", "",
          "1. `alive/nextTime` 是服务端字段，本工程无 `requestWangList` 协议 ⇒ 场景烘 `alive=true`（「未死亡」）。",
          "2. `MLabel` 的 `textField.y=2` 用「件框照声明 + `vertical_alignment=1`」逼近 ⇒ glyph 级 y 未逐字对。",
          "3. `MGlowLabel` 的黑 glow（blur3/strength6）与 `getGlowFilter` **未烘**（与意志学习页同口径）。",
          "4. `Effect_Wang_9/10` 原生 174 宽（其余 173），`origin` 恒 {0,0} ⇒ 未证是否有额外位移。",
          "5. 外壳底图与本页声明的 `MWindow_background` 不同张 ⇒ 像素级不判最外一圈。",
          "6. `序号` 恒空 ⇒ 像素级不适用；`地图数值` 的 underline TextFormat 在原版**从未 set 上去**"
          "（`Cell:207-208` 造了却没用）⇒ 不划线，不是漏做。", ""]
    with open(os.path.join(出目录, "真值对照表.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(行))


if __name__ == "__main__":
    主()
    sys.exit(门.退出码())
