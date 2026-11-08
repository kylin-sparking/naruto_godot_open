# -*- coding: utf-8 -*-
"""烘「纲手三窗」（NPC 对话 / 副本传送 / 精英副本）要用的皮。

三件事都在这里一次做掉，每件都带**文件级自检**（回读比对，不等就抛）：

1. **整帧导入**：`QuestDialog_npcSaidSkin(794)` / `_playerSaidSkin(797)` / `_hand(800)` /
   `TableSeparatorLineF(593)` / `StarLevelIconF(693)` / `StarHollowF(782)` —— 逐字节等于元件图。
2. **运行期外部 SWF 皮**：`UISwf_BailianCopy.swf` 的三张（chid 9=cellBackground、
   3=selectedBg、6=Lack，84×81 与 `BailianCell.as:86` 的 `showLoading(this,84,81)` 对上）。
   ⚠ 这三张**不在 MainLib**，`元件图/sprites` 与《共用件度量表》§13 都查不到 ⇒ 只能按
   skill `flash-swf-asset-probe` 的口径从 SWF 直接解，符号归属以 ffdec 打的
   `DefineSprite (chid, cls)` 行为准（E 盘那批 `UISwf_BailianCopy.swf_1/4/7.png` 的下标是
   **帧号**、不是 chid，别拿它当符号 id）。
3. **整帧非等比拉伸 + MButton3 派生态**：原版这三扇窗里的钮全是
   `isScale9Grid = false`（`CopyWindow.as:229/237/245`、`EliteCopyWindow.as:330`）
   ⇒ `Sprite.width=` 是**整帧非等比缩放**，九宫格边距不生效。所以按 `UIConfig.btn_width_*`
   预烘到目标宽，再按 `StyleUtil.as:7-12` 烘 `+30 / −40`（公式取自 `开发工具/派生钮态.py`，
   不在这儿重写第二份）。

用法：python 开发工具/烘副本页皮.py
"""
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from 派生钮态 import 加亮  # noqa: E402

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
元件根 = os.path.join(os.environ.get("NARUTO_ELEMENT_ROOT")
	or os.path.join(os.path.dirname(工程), "原版源数据", "元件图"), "sprites")
通用 = os.path.join(工程, "素材", "界面", "原版窗口", "通用控件")
副本 = os.path.join(工程, "素材", "界面", "原版窗口", "副本")
UISWF = os.path.join(工程, "_tmp", "纲手", "uiswf")	# ffdec -export sprite 的落点，见真值 md §2.3


def 元件(类名前缀):
    import glob
    d = sorted(glob.glob(os.path.join(元件根, 类名前缀 + "*")))
    if not d:
        raise SystemExit("元件图里没有 " + 类名前缀)
    return Image.open(os.path.join(d[0], "1.png")).convert("RGBA")


def 落(图, 路径):
    os.makedirs(os.path.dirname(路径), exist_ok=True)
    图.save(路径)


def 逐字节(名, 客户路径, 参照):
    客 = Image.open(客户路径).convert("RGBA")
    if 客.size != 参照.size:
        raise SystemExit("%s 尺寸 %s ≠ 参照 %s" % (名, 客.size, 参照.size))
    差 = sum(1 for a, b in zip(list(客.getdata()), list(参照.getdata())) if a != b)
    print("  %-28s %s 逐字节 %d/%d 不同" % (os.path.basename(客户路径), "√" if 差 == 0 else "!!",
                                          差, 参照.size[0] * 参照.size[1]))
    if 差:
        raise SystemExit(名 + " 与元件不是同一张")


def 拉伸(源, 宽, 高):
    """Flash 普通 Sprite 的 `width=` 语义：整帧非等比、NEAREST（不抗锯齿）。"""
    return 源.resize((宽, 高), Image.NEAREST)


def 三态(名, 底, 目录):
    """`底` 是常态皮（已按目标宽拉过）⇒ 落 常态 / _悬停(+30) / _按下(−40)。"""
    常 = os.path.join(目录, 名 + ".png")
    落(底, 常)
    for 后缀, 偏移 in (("_悬停", 30), ("_按下", -40)):
        路 = os.path.join(目录, 名 + 后缀 + ".png")
        派 = Image.new("RGBA", 底.size, (0, 0, 0, 0))
        派.putdata(加亮(list(底.getdata()), 偏移))
        落(派, 路)
        回 = Image.open(路).convert("RGBA")
        if list(回.getdata()) != list(派.getdata()):
            raise SystemExit("派生态回读不等：" + 路)
    print("  %-28s %d×%d 三态齐（+30 / −40 逐字节等于公式）" % (名 + ".png", 底.size[0], 底.size[1]))


def 主():
    print("=== 一、整帧导入（逐字节等于元件图）===")
    for 名, 前缀, 目录 in [
            ("对话上格", "DefineSprite_794_QuestDialog_npcSaidSkin", 通用),
            ("对话下格", "DefineSprite_797_QuestDialog_playerSaidSkin", 通用),
            ("对话手形", "DefineSprite_800_QuestDialog_hand", 通用),
            ("竖向分隔线", "DefineSprite_593_TableSeparatorLineF", 通用),
            ("星实心", "DefineSprite_693_StarLevelIconF", 副本),
            ("星空心", "DefineSprite_782_StarHollowF", 副本)]:
        路 = os.path.join(目录, 名 + ".png")
        落(元件(前缀), 路)
        逐字节(名, 路, 元件(前缀))

    print("=== 二、UISwf_BailianCopy 三张（运行期外部 SWF）===")
    for 名, chid in [("精英格底", 9), ("精英格选中", 3), ("精英格锁", 6)]:
        d = [x for x in os.listdir(UISWF) if x.startswith("DefineSprite_%d_" % chid)]
        if not d:
            raise SystemExit("uiswf 导出里没有 chid=%d" % chid)
        参照 = Image.open(os.path.join(UISWF, d[0], "1.png")).convert("RGBA")
        if 参照.size != (84, 81):
            raise SystemExit("chid=%d 尺寸 %s ≠ BailianCell.as:86 的 84×81" % (chid, 参照.size))
        路 = os.path.join(副本, 名 + ".png")
        落(参照, 路)
        逐字节("%s（%s）" % (名, d[0].split("_", 2)[2]), 路, 参照)

    print("=== 三、isScale9Grid=false ⇒ 整帧拉到 btn_width_* 再烘三态 ===")
    钮底 = 元件("DefineSprite_21_MButtonF")		# MButtonF 原生 57×22
    # CopyWindow.as:236-247：进入 = btn_width_two(37)、副本密卷进入 = btn_width_six(82)
    # （排行榜那枚 btn_width_seven(94) 原版 `visible=false` ⇒ 不烘，量具按「不存在」判）
    for 名, 宽 in [("钮_进入", 37), ("钮_密卷", 82)]:
        三态(名, 拉伸(钮底, 宽, 22), 副本)
    # EliteCopyWindow.as:329-331：MTabButtonF、isScale9Grid=false、宽 = btn_width_five(70)
    未选 = 元件("DefineSprite_121_MTabButton_up")		# 39×22
    选中 = 元件("DefineSprite_118_MTabButton_disabled")	# = selectedUpSkin（名字坑）
    三态("页签_未选", 拉伸(未选, 70, 22), 副本)
    落(拉伸(选中, 70, 22), os.path.join(副本, "页签_选中.png"))
    print("  %-28s 70×22（选中档=selectedUpSkin 原色，MTabButton 不推灰度、不派生）" % "页签_选中.png")


if __name__ == "__main__":
    主()
