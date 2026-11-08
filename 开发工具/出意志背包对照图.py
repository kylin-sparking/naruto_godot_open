# -*- coding: utf-8 -*-
"""出「意志背包」（原版 `YiZhiPackWindow`，663×548）的对证图。

原语在 `开发工具/对证库.py`；逐件出处见量具表 `开发工具/截意志背包页.gd` 的注释。

这一页的两个别处没有的要点：
  * 主美术是**运行期包** `swf/UISwf/UISwf_yizhiPack.swf`（格底/格悬停/equipSkin/yizhiIcon/feng），
    不在 MainLib ⇒ 「一、文件级」逐张比 `元件图/UISwf_yizhiPack` 原件，专治"拿别的页面的图凑数"。
  * 三枚钮（一键合成/前往学习/自动升级意志）是 `MButtonF extends MButton3` 且
    `isScale9Grid=false` + 显式 width ⇒ **整张非等比压/拉**，不是九宫格；
    派生三态由 `开发工具/生成意志钮态图.py` 烘，逐像素另有 `出意志钮态对照图.py` 判。

用法：python 开发工具/出意志背包对照图.py      # 退出码 0 = 全部通过
"""
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from 对证库 import (九宫格拉伸, 并排, 比对, 条, 文件级, 窗口截图,  # noqa: E402
                   红计数类)

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
截图 = os.path.join(工程, "测试", "截图")
客户目录 = os.path.join(截图, "遗址")
出目录 = os.path.join(截图, "遗址_对照")
元件根 = os.environ.get("NARUTO_ELEMENT_ROOT") or os.path.join(工程, "..", "原版源数据", "元件图")
包 = os.path.join(元件根, "UISwf_yizhiPack")
背 = os.path.join(工程, "素材", "界面", "原版窗口", "意志背包")
专 = os.path.join(工程, "素材", "界面", "专用控件")
通用 = os.path.join(工程, "素材", "界面", "原版窗口", "通用控件")
抬 = 29
门 = 红计数类()


def 元件(符号):
    d = [x for x in os.listdir(包) if x.endswith("_" + 符号)]
    if not d:
        raise SystemExit("元件图里没有符号 " + 符号)
    return Image.open(os.path.join(包, d[0], "1.png")).convert("RGBA")


def 素材(根, 名):
    return Image.open(os.path.join(根, 名)).convert("RGBA")


def 皮级(名, 根, 文件, 参):
    客 = 素材(根, 文件)
    过, 文 = 文件级(客, 参 if callable(参) else 参)
    门.记("%-34s 文件级 %s｜%s" % (名, "√" if 过 else "!!", 文))
    if not 过:
        门.红项(名, 文)


def 整窗合成():
    """按原版 addChild 顺序合成一次（`onSkinReady:121-195` + `initView:431-468`）。
    单层皮当参照会把被上层盖住的位置判成假红。"""
    整 = Image.new("RGBA", (663, 548), (0, 0, 0, 0))
    # `_frame` 是第一个子节点 ⇒ 窗口外框**最先**合成（中段不是全透的，最后压会蒙纱整窗）
    整.alpha_composite(九宫格拉伸(素材(通用, "窗口边框.png"), 663, 548, [48, 29, 48, 13]), (0, 0))
    整.alpha_composite(九宫格拉伸(素材(通用, "内容面板.png"), 647, 480, [11, 10, 10, 11]), (8, 38))
    整.alpha_composite(素材(背, "穿戴盘.png"), (391, 112))
    for k in range(30):
        整.alpha_composite(素材(背, "格底.png"), (16 + 69 * (k % 5), 80 + 69 * (k // 5)))
    for dx, dy in [(-29, 81), (-4, 1), (80, -30), (165, 1), (195, 81), (165, 161),
                   (80, 196), (-4, 161)]:
        整.alpha_composite(素材(背, "格底.png"), (391 + dx, 112 + dy))
    # ⚠️ 穿戴格 2..8 还要**再压一层封印**：`updateEquipLimit:209-227` 对超出 `equipLimit`
    #   的格走 `forbidCell:57-64` ⇒ 摘掉悬停框 + `addChildAt(feng, 1)`（格底之上、名称之下）。
    #   初值 `equipLimit = 1`（`YiZhiManager.as:56`）⇒ 只有第一格开着。
    for i, (dx, dy) in enumerate([(-29, 81), (-4, 1), (80, -30), (165, 1), (195, 81),
                                  (165, 161), (80, 196), (-4, 161)]):
        if i:
            整.alpha_composite(素材(背, "封印.png"), (391 + dx, 112 + dy))
    整.alpha_composite(素材(背, "格底.png"), (413, 388))
    整.alpha_composite(素材(背, "意志力图标.png"), (507, 47))
    整.alpha_composite(素材(专, "意志_一键合成.png"), (80, 521))
    整.alpha_composite(素材(专, "意志_前往学习.png"), (440, 521))
    # ⚠️ 「自动升级意志」原版建完就 `enabled=false`（`YiZhiPackWindow:481`）⇒
    #   `MButton3.set enabled:460-477` 走 STATE_DISABLED，画的是 **getGrayFilter 派生灰皮**，
    #   不是亮皮。场景侧先前把灰皮写成 `theme_override_textures/disabled`
    #   （TextureButton 没这条属性 ⇒ .tscn 静默丢掉 ⇒ 一直是亮的），现改 `texture_disabled`。
    整.alpha_composite(素材(专, "意志_自动升级_灰.png"), (485, 420))
    return 整


def 像素级(名, 合成, 框, 说明, 环=None, 率上限=2.0, 备注=""):
    x, y, w, h = [int(round(v)) for v in 框]
    客 = 窗裁.裁(框, 0)
    # `框` 是**页面局部**（量具表口径），`窗裁.裁` 内部已 +抬；参照也必须 +抬
    参 = 合成.crop((x, y + 抬, x + w, y + h + 抬))
    if 客.size != 参.size:
        门.红项(名, "裁块 %s 与参照 %s 尺寸不同" % (客.size, 参.size))
        return
    超, 判, 偏 = 比对(客, 参, 环=环)
    率 = 0.0 if 判 == 0 else 100.0 * 超 / 判
    过 = 率 <= 率上限
    if not 过:
        门.红项(名, "超阈值 %.2f%%（%d/%d）" % (率, 超, 判))
    门.记("%-30s 像素级 %s 偏移%s 判 %d 超 %d（%.2f%%，门 %.1f%%%s）｜%s" % (
        名, "√" if 过 else "!!", 偏, 判, 超, 率, 率上限, "，环 %d" % 环 if 环 is not None else "", 说明))
    if 备注:
        门.记("%-30s   ↳ %s" % ("", 备注))


def 主():
    global 窗裁
    窗裁 = 窗口截图(客户目录, (0,), 抬=抬)
    门.记("意志背包对证｜截图来自 开发工具/截意志背包页.gd；抬 %dpx" % 抬)
    门.记("")
    门.记("=== 一、素材来源（文件级，逐张比 UISwf_yizhiPack 原件）===")
    皮级("格底 ← UISwf_yizhiPack_cellSkin", 背, "格底.png", 元件("UISwf_yizhiPack_cellSkin"))
    皮级("格悬停 ← cellOverSkin", 背, "格悬停.png", 元件("UISwf_yizhiPack_cellOverSkin"))
    皮级("穿戴盘 ← equipSkin", 背, "穿戴盘.png", 元件("UISwf_yizhiPack_equipSkin"))
    皮级("意志力图标 ← yizhiIcon", 背, "意志力图标.png", 元件("UISwf_yizhiPack_yizhiIcon"))
    # `forbidCell:63-64` 的 `_icon = UISwf_yizhiPack_feng`（原生 64×64，且**不设 x/y** ⇒
    # 坐在格原点，与 `drawYiZhi:203` 的 `x=y=4`、锁的 `x=-10,y=-16` 都不同）
    皮级("封印 ← UISwf_yizhiPack_feng", 背, "封印.png", 元件("UISwf_yizhiPack_feng"))
    皮级("外框黄底 ← MYellow_background", 通用, "内容面板.png",
         Image.open(os.path.join(元件根, "sprites",
                                 "DefineSprite_10_MYellow_background_MYellow_background",
                                 "1.png")).convert("RGBA"))
    门.记("")

    门.记("=== 二、渲染级（整窗一次合成后裁各件）===")
    # ⚠️ 合成完必须**铺到真实底片上**再裁：原版皮肤全是半透的（MYellow 底板 alpha≈230、
    #   穿戴盘描边更低），从透明黑往上叠的参照会比客户端整体偏暗 ——
    #   实测盘缘中位差 +13、四个件超阈 11~18%，全是这条口径造成的假红。
    #   底片由 `量具基类._步拍底片/_步存底片` 把窗口藏起来拍同一矩形。
    合成 = 窗裁.铺底(整窗合成())
    门.记("参照底片：%s" % ("有 底片_页0.png（半透层按真实底图合成）"
            if 窗裁.底.get(0) is not None else "缺底片，仍按透明黑（旧口径）"))
    像素级("外框黄底 647×480", 合成, [8, 9, 647, 480],
           "UIWindow:36-38,64-65 (8,38) 663−16 × 548−68，九宫格 11/10/10/11", 环=4, 率上限=1.0,
           备注="环 4：中间被 30 格与穿戴盘盖住，只判四边露出的 MYellow 边带")
    像素级("格底(背包格0) 64×64", 合成, [16, 51, 64, 64],
           "YiZhiCell:113-114 cellSkin 原生 64×64，容器 @(16,80) 首格 (0,0)",
           备注="空态只画格底（图标/字要服务端有货才造）")
    像素级("穿戴盘 230×230", 合成, [391, 83, 230, 230],
           "PW:157-160 equipSkin @(391,112) 原生 230×230", 环=6, 率上限=1.0,
           备注="环 6：盘上压着 8 枚穿戴格，判没被压住的边带")
    像素级("穿戴格1(开启) 64×64", 合成, [362, 164, 64, 64],
           "PW:451 硬编码偏移表首格 (-29,81) + equipLimit=1 ⇒ 这格开着、只有格底")
    像素级("穿戴格2(封印) 64×64", 合成, [387, 84, 64, 64],
           "PW:451 次格 (-4,1) + forbidCell:63-64 addChildAt(feng,1) ⇒ 格底之上压封印",
           备注="这一条是「封印层有没有画」的哨兵：层序写反（盖到悬停框上面）或忘了画都会红")
    像素级("升级格 64×64", 合成, [413, 359, 64, 64], "PW:465-468 x=663−250、y=488−100")
    # 钮字是 MButton3 自己的 tf（Godot 与 Flash 的字体栅格化不可能逐字节相同）⇒
    # 按 skill 的口径**只量外圈 2px**（实测全域判会报 42% 的假"美术差"）。
    像素级("一键合成 143×22", 合成, [80, 492, 143, 22],
           "PW:186-191 x=80 y=548−22−5、width=143、isScale9Grid=false ⇒ 整张拉伸", 环=2)
    像素级("前往学习 82×22", 合成, [440, 492, 82, 22],
           "PW:193-197 x=663−143−80=440、width=btn_width_six=82", 环=2)
    像素级("自动升级钮 110×22(灰)", 合成, [485, 391, 110, 22],
           "PW:476-480 x=_lockCheckBox.x、width=110；:481 `enabled=false` ⇒ 画灰皮不画亮皮", 环=2,
           备注="这一条就是「禁用钮画成亮皮」那个静默 bug 的哨兵：属性名写错"
                "（`theme_override_textures/disabled` 被 .tscn 丢掉）时它会红")
    门.记("%-30s 像素级 ―― 不适用：件上必压文字/服务端数据，改由「一、文件级」+ 量具 + 8× 交"
          % "拖动提示 / 三枚钮的字 / 意志力框")
    门.记("%-30s 像素级 ―― 不适用：`PW:150-153,158` 的 _charSkin 里坐 `drawCharImage:387-405`"
          " 的点阵动画（按 stats.face 现选、站姿），参照只能取一帧" % "人物立绘")
    门.记("")

    门.记("=== 三、8 倍单件放大图 ===")

    def 放(框, 倍率=8):
        im = 窗裁.裁(框, 0)
        return im.resize((im.width * 倍率, im.height * 倍率), Image.NEAREST)
    项目 = [
        ("背包格排首两行", 放([16, 51, 340, 133], 3), "5 列一行、格 64 + gap 5 ⇒ 步距 69（`initView:431-450`）"),
        ("穿戴盘与八格", 放([333, 53, 317, 290], 2), "`initView:451` 硬编码偏移，盘 230×230 @(391,112)"),
        ("右下三件", 放([405, 351, 258, 168], 3), "升级格 64×64 + 锁定意志 + 自动升级意志(禁用) + 两行提示"),
        ("底部两钮", 放([80, 492, 442, 22], 4), "一键合成 143×22 / 前往学习 82×22（都是整张拉伸的 MButtonF）"),
    ]
    路, 尺 = 条(项目, os.path.join(出目录, "8x_格排与钮.png"),
               "① 意志背包（原版 663×548）逐件 8×")
    门.记("出 %s  %s" % (os.path.relpath(路, 工程), 尺))
    路, 尺 = 并排([("意志背包（原版 663×548）", 窗裁.图[0])], os.path.join(出目录, "整窗.png"), None)
    门.记("出 %s  %s" % (os.path.relpath(路, 工程), 尺))
    门.记("")
    门.记("=== 结论 ===")
    门.记("红项 %d 个" % 门.红)
    if not os.path.isdir(出目录):
        os.makedirs(出目录)
    门.落盘(os.path.join(出目录, "对照输出.txt"))


if __name__ == "__main__":
    主()
    sys.exit(门.退出码())
