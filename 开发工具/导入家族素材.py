# -*- coding: utf-8 -*-
"""把家族页缺的原版皮肤从 `_tmp/ffdec_jiazu/` 落进 `素材/界面/原版窗口/家族/`。

口径（与 `flash-swf-asset-probe` 一致）：
  · 判"缺不缺"先跟工程里已有的同尺寸件逐像素比（容差 0，另报不透明像素差），
    同源就别再造一份，避免同一张图两处漂移；
  · 尺寸一律 PIL 实测，不靠文件名；
  · 幂等：重跑覆盖，不追加。

跑法：`python 开发工具/导入家族素材.py`，然后 `Godot --path . --headless --import`。
"""
import os
import shutil

import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
from PIL import Image
import numpy as np

from 对证库 import 九宫格拉伸	# 门里用的同一套九宫格实现，别自己再写一份（手写那份把钮拉坏了）

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚠️ 原来写死作者机的 naruto_godot；改成从本文件反推，见 §合并说明
源 = os.path.join(项目, "_tmp", "ffdec_jiazu")
落 = os.path.join(项目, "素材", "界面", "原版窗口", "家族")

# (源相对路径, 落地名, 要顺带对比的工程内候选)
表 = [
    ("mainlib/DefineSprite_97_MPane_background_MPane_background/1.png", "盒底.png",
     ["素材/界面/原版窗口/通用控件/内容面板.png", "素材/界面/原版窗口/通用控件/浅色面板.png",
      "素材/界面/原版窗口/通用控件/窗口内底.png"]),
    ("mainlib/DefineSprite_593_TableSeparatorLineF_TableSeparatorLineF/1.png", "表头竖分隔线.png",
     ["素材/界面/原版窗口/通用控件/竖向分隔线.png"]),
    # LeafBorder 的两端小标（`LeafBorder.as:80-85`：左 x=padding、右 x=宽−27−padding、y=8−22=−14），
    # 盒标题文字压在盒顶之上（`label.y = −label高+1`）⇒ 缺这俩就没有"叶边"效果。
    ("mainlib/DefineSprite_892_LeftXiaoBiao_LeftXiaoBiao/1.png", "端帽左.png", []),
    ("mainlib/DefineSprite_890_RightXiaoBiao_RightXiaoBiao/1.png", "端帽右.png", []),
    ("mainlib/DefineSprite_580_FamillyPopupWindowSkin_FamillyPopupWindowSkin/1.png", "弹窗底.png",
     ["素材/界面/原版窗口/通用控件/提示框底.png", "素材/界面/原版窗口/通用控件/提示框.png"]),
    ("mainlib/DefineSprite_600_MPlusBtnF_MPlusBtnF/1.png", "加号钮.png",
     ["素材/界面/原版窗口/通用控件/增加按钮.png"]),
    ("mainlib/DefineSprite_604_MMinusBtnF_MMinusBtnF/1.png", "减号钮.png",
     ["素材/界面/原版窗口/通用控件/减少按钮.png"]),
    ("mainlib/DefineSprite_608_MMaxBtnF_MMaxBtnF/1.png", "最大钮.png", []),
    ("mainlib/DefineSprite_105_MCheckBoxF_MCheckBoxF/1.png", "复选框.png",
     ["素材/界面/原版窗口/通用控件/复选框.png"]),
    # ⚠ MButtonF(21) 的 upSkin 是 **tag18 MButton_up**（《度量表》§3.2 时间轴表：selectedUpSkin=15、upSkin=18），
    # 不是 tag21 那张复合体（导出来是整颗钮含 tf 的帧）。实测：工程 `通用控件\按钮.png` 与 tag18
    # 不透明像素 137 vs 112、均 RGB 差 13 ⇒ **不同源**，家族页不能拿它当钮底；
    # 而 `按钮按下.png` 与 tag15 selectedUp 均 RGB 全同 ⇒ 那是"选中皮"族，不是 MButtonF 的按下档。
    ("mainlib/DefineSprite_18_MButton_up_MButton_up/1.png", "钮底.png",
     ["素材/界面/原版窗口/通用控件/按钮.png"]),
    ("mainlib/DefineSprite_15_MButton_selectedUp_MButton_selectedUp/1.png", "钮底选中.png",
     ["素材/界面/原版窗口/通用控件/按钮按下.png"]),
    ("uiswf_FamillyShop/DefineSprite_3_UISwf_FamillyShop_ShopIcon/1.png", "商店角标.png", []),
    ("uiswf_FlagHelp/DefineSprite_3_UISwf_FlagHelp_Background/1.png", "旗帜帮助底.png", []),
    ("uiswf_FamillyIcon/DefineSprite_3_UISwf_FamillyIcon_GridFamilyInvite/1.png", "邀请格.png", []),
    # Boss 奖励条的收起钮 = BranchButton(660) 18×18（《家族.md》§6.5 要求实测，已 PIL 量得）；
    # 日环窗的星级图标 = StarLevelIconF(693) 14×13。
    ("mainlib/DefineSprite_660_BranchButton_BranchButton/1.png", "展开钮.png", []),
    ("mainlib/DefineSprite_693_StarLevelIconF_StarLevelIconF/1.png", "星标.png", []),
]


def 组(路):
    im = Image.open(路).convert("RGBA")
    a = np.asarray(im).astype(int)
    return im.size, a


def 比(甲, 乙):
    """返回 (是否同尺寸, 全等像素数, 不透明像素 RGB 最大差)。"""
    sa, aa = 组(甲)
    sb, ab = 组(乙)
    if sa != sb:
        return False, 0, None
    同 = int((aa == ab).all(axis=2).sum())
    遮 = (aa[:, :, 3] == 255) & (ab[:, :, 3] == 255)
    差 = int(np.abs(aa[:, :, :3] - ab[:, :, :3]).max(initial=0)) if 遮.any() else 0
    return True, 同, 差


def 加亮(图, d):
    """`StyleUtil.getLightFilter(±d)`：逐通道加性、clamp、**不动 alpha**；
    全透像素 (0,0,0,0) 保持全透（线性过滤时不渗亮边，同聊天栏口径）。"""
    a = np.asarray(图.convert("RGBA")).astype(int)
    out = a.copy()
    透 = a[:, :, 3] > 0
    for c in range(3):
        层 = np.clip(a[:, :, c] + d, 0, 255)
        out[:, :, c] = np.where(透, 层, a[:, :, c])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def 变灰(图):
    """`BaseUtil.getGrayFilter()` 的字面系数（0.3086/0.6094/0.082，三通道同值）。"""
    a = np.asarray(图.convert("RGBA")).astype(int)
    灰 = np.round(a[:, :, 0] * 0.3086 + a[:, :, 1] * 0.6094 + a[:, :, 2] * 0.082)
    out = a.copy()
    透 = a[:, :, 3] > 0
    for c in range(3):
        out[:, :, c] = np.where(透, np.clip(灰, 0, 255), a[:, :, c])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


# ⚠ TextureButton 没有九宫格：给它 57×22 的皮 + 61×22 的矩形 = **整拉**，四角圆弧会糊
# ⇒ 必须按 §3.2 边距（左7.15/上7.15/右7.3/下7）预烘成 61 与 37 两档，再各出三态。
# 下拉同理：`MComboBox` 的 upSkin = ComboBox_upSkin(614) 116×21，§13 边距 左5.5/上5/右22.75/下5.5
宽档 = [("钮底", 61), ("钮底", 37), ("钮底", 108)]
# ⚠ 2026-10-16 补：66 这一档原来**漏了**（`家族Boss完成窗.tscn:83` 的 `metadata/skin` 指着它、
#   `:13` 也直接引 `钮底66.png`），而场景是随家族支一起进来的 ⇒ 那张皮一直缺、门红着。
#   宽档本来就是"同一张 57×22 的皮九宫格拉伸到目标宽 + 派生三态"，66 照同一条规则烘即可。
宽档.append(("钮底", 66))
# 原生成品是 MButton3 族：`isScale9Grid=false` ⇒ 默认宽=皮宽 57（《度量表》§3.2:264），
# 只有代码里显式 `width=` 的才要预烘档位（旗帜帮助进入钮写字面量 108）。
下拉档 = [(60, "下拉框", (5.5, 22.75, 5, 5.5)), (90, "下拉框", (5.5, 22.75, 5, 5.5))]
# 已经"一张皮就是原生尺寸"的小钮（±/最大/收起）：TextureButton 无九宫格，
# 但它们在原版里也不拉伸（MMinusBtnF 等本身 18×18），只需派生三态。
态皮 = ["减号钮", "加号钮", "最大钮", "展开钮", "下拉60", "下拉90"]


def 烘():
    for 宽, 皮, 边 in 下拉档:
        九宫格拉伸(Image.open(os.path.join(项目, "素材", "界面", "原版窗口", "通用控件",
            皮 + ".png")).convert("RGBA"), 宽, 21, 边).save(os.path.join(落, "下拉%d.png" % 宽))
        print("  下拉%d.png" % 宽)
    for 基, 宽 in 宽档:
        底 = Image.open(os.path.join(落, 基 + ".png"))
        图 = 九宫格拉伸(底, 宽, 22, (7.15, 7.3, 7.15, 7))
        出名 = os.path.join(落, "%s%d.png" % (基, 宽))
        图.save(出名)
        for 态, d in [("悬停", 30), ("按下", -40)]:
            加亮(图, d).save(os.path.join(落, "%s%d_%s.png" % (基, 宽, 态)))
        变灰(图).save(os.path.join(落, "%s%d_灰.png" % (基, 宽)))
        print("  %s%d(+悬停/按下/灰)" % (基, 宽))
    for 基 in 态皮:
        p = os.path.join(落, 基 + ".png")
        图 = Image.open(p)
        for 态, d in [("悬停", 30), ("按下", -40)]:
            出名 = p[:-4] + "_%s.png" % 态
            加亮(图, d).save(出名)
            print("  %s_%s.png" % (基, 态))
        变灰(图).save(p[:-4] + "_灰.png")
        print("  %s_灰.png" % 基)
    # 原生 57×22 那档也要三态（旗帜窗/日环窗的底钮都没设 width ⇒ 全是 57）
    底 = Image.open(os.path.join(落, "钮底.png"))
    for 态, d in [("悬停", 30), ("按下", -40)]:
        加亮(底, d).save(os.path.join(落, "钮底_%s.png" % 态))
    变灰(底).save(os.path.join(落, "钮底_灰.png"))
    print("  钮底(+悬停/按下/灰) 57×22")


def 主():
    os.makedirs(落, exist_ok=True)
    for 相, 出名, 候选 in 表:
        s = os.path.join(源, 相.replace("/", os.sep))
        if not os.path.isfile(s):
            raise SystemExit("源不存在：" + 相)
        尺 = Image.open(s).size
        行 = ["%-16s %dx%d" % (出名, 尺[0], 尺[1])]
        for 候 in 候选:
            p = os.path.join(项目, 候.replace("/", os.sep))
            if not os.path.isfile(p):
                行.append("%s 无" % os.path.basename(候))
                continue
            同尺, 同数, 最大差 = 比(s, p)
            if not 同尺:
                行.append("%s 尺寸不同(%s)" % (os.path.basename(候), Image.open(p).size))
            else:
                总 = 尺[0] * 尺[1]
                行.append("%s 全等%d/%d 不透明RGB最大差%s" % (
                    os.path.basename(候), 同数, 总, 最大差))
        shutil.copy2(s, os.path.join(落, 出名))
        print("  ".join(行))
    print("落 %d 张 → %s" % (len(表), 落))
    烘()


if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    主()
