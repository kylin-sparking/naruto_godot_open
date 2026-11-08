# -*- coding: utf-8 -*-
"""把好友页缺的原版皮肤落进 `素材/界面/原版窗口/好友/`。

口径（与 `导入家族素材.py` 同一套，别另起炉灶）：
  · 判"要不要新导"先跟工程里已有的同尺寸件逐像素比（容差 0，另报不透明区 RGB 最大差），
    同源就不再造一份，避免同一张图两处漂移；
  · 尺寸一律 PIL 实测，不靠文件名；
  · MButton3 族的派生态一律 **预烘**（`StyleUtil.skinFilters` 悬停 +30 / 按下 −40 + `getGrayFilter`），
    因为 `TextureButton` 没有九宫格、也没有滤镜档，运行期换皮是唯一口径；
  · 幂等：重跑覆盖。
跑法：python 开发工具/导入好友素材.py，然后 `Godot --path . --headless --import`。
"""
import os
import shutil
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 导入家族素材 import 比, 加亮, 变灰	# 同一份实现，别抄第二份
项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚠️ 原来写死作者机的 naruto_godot；改成从本文件反推，见 §合并说明
源 = os.path.join(项目, "_tmp", "ffdec_jiazu", "mainlib")
落 = os.path.join(项目, "素材", "界面", "原版窗口", "好友")

# (导出目录, 落地名, 工程内候选, 要不要派生三态)
表 = [
    # 私聊窗右下角的表情钮：`FriendFaceBtn.as:6` extends MButton3 ⇒ 有 ±30/−40 档，要派生态
    ("DefineSprite_566_FriendFaceBtn_FriendFaceBtn", "表情钮.png", [], True),
    # 表头竖分隔 = TableSeparatorLineF(593) 2×20：与家族页同一张皮，但**包内自带一份**，
    # 免得好友包离开家族包就缺件（同源比对在下面打印，不是第二张图）
    ("DefineSprite_593_TableSeparatorLineF_TableSeparatorLineF", "表头竖分隔.png",
     ["素材/界面/原版窗口/家族/表头竖分隔线.png"], False),
    # MButtonF 的 upSkin = tag18（57×22，边距 7.15/7.15/7.3/7）；`TextureButton` 没有九宫格 ⇒
    # 页签体里那几颗钮按各自档**预烘**：37（`btn_width_two`）、61（`btn_width_four`）、
    # 54（`isScale9Grid=true` 的「添加好友」= 文字 48 + 6，《度量表》§3.2:202）
    ("DefineSprite_18_MButton_up_MButton_up", "钮底.png",
     ["素材/界面/原版窗口/家族/钮底.png"], True),
]
宽档 = [30, 37, 54, 61]	# 30 = 打探窗两枚（`isScale9Grid=true` ⇒ 文字 24+6）

已核 = {  # §7 的逐像素结论，落在这里当注释用（不在 表 里 = 沿用工程件，不重复导）
    "菜单底.png": "tag590 全等 3237/3237",
    "菜单按钮.png": "tag585 全等 893/893",
    "选中条1.png": "tag705 全等 3591/3591",
    "小窗口边框.png": "tag767 同形同 alpha、RGB 最大差 64（两版 SWF 色差）⇒ 按实机优先沿用工程件",
}


def 主():
    os.makedirs(落, exist_ok=True)
    for 相, 出名, 候选, 派生 in 表:
        s = os.path.join(源, 相, "1.png")
        if not os.path.isfile(s):
            raise SystemExit("源不存在：" + 相)
        尺 = Image.open(s).size
        行 = ["%-14s %dx%d" % (出名, 尺[0], 尺[1])]
        for 候 in 候选:
            p = os.path.join(项目, 候.replace("/", os.sep))
            行.append("%s：%s" % (os.path.basename(候),
                    "尺寸不同" if not os.path.isfile(p) else 比(s, p)))
        目 = os.path.join(落, 出名)
        shutil.copy2(s, 目)
        if 派生:
            图 = Image.open(目)
            for 态, d in [("悬停", 30), ("按下", -40)]:
                加亮(图, d).save(目[:-4] + "_%s.png" % 态)
            变灰(图).save(目[:-4] + "_灰.png")
            行.append("已派生 悬停/按下/灰")
        print("  |  ".join(行))
    # 预烘宽档（`TextureButton` 无九宫格 ⇒ 整拉会把圆角拉糊，家族那轮实测钮件 18% 超差）
    from 对证库 import 九宫格拉伸
    基 = Image.open(os.path.join(落, "钮底.png")).convert("RGBA")
    for 宽 in 宽档:
        图 = 九宫格拉伸(基, 宽, 22, (7.15, 7.3, 7.15, 7))
        名 = os.path.join(落, "钮底%d.png" % 宽)
        图.save(名)
        for 态, d in [("悬停", 30), ("按下", -40)]:
            加亮(图, d).save(名[:-4] + "_%s.png" % 态)
        变灰(图).save(名[:-4] + "_灰.png")
        print("  钮底%d(+悬停/按下/灰)" % 宽)
    # 页签三态：`MTabButton` 继承 MButton3 ⇒ 未选枚照样有 悬停 +30 / 按下 −40（《度量表》§4.1），
    # 选中枚显示 `selectedUpSkin`（= 工程既有 `分页按钮选中.png`）且**不推灰度**。
    # TextureButton 没有滤镜档 ⇒ 未选枚的 悬停/按下 必须预烘，否则运行期只能"点了没反应"。
    from PIL import Image as _I
    未选 = _I.open(os.path.join(项目, "素材", "界面", "原版窗口", "通用控件", "分页按钮未选.png")).convert("RGBA")
    for 态, d in [("悬停", 30), ("按下", -40)]:
        加亮(未选, d).save(os.path.join(落, "页签未选_%s.png" % 态))
    未选.save(os.path.join(落, "页签未选.png"))
    _I.open(os.path.join(项目, "素材", "界面", "原版窗口", "通用控件",
           "分页按钮选中.png")).convert("RGBA").save(os.path.join(落, "页签选中.png"))
    print("  页签未选(+悬停/按下)、页签选中")
    for k, v in 已核.items():
        print("  沿用通用控件/%s —— %s" % (k, v))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    主()
