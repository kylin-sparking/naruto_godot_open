# -*- coding: utf-8 -*-
"""MButton3 / MTabButton 一族的「派生态皮」烘焙 —— 公式只这一份，别的脚本都从这里引。

真值（skill `flash-mbutton3-state-skins` 已取证）：
  `StyleUtil.as:7-12`   `skinFilters = {up: 0, over: +30, down: −40}`
  `StyleUtil.as:43-47`  `getLightFilter(d)` = 单位矩阵 + 第 5 列 R/G/B 各加 d
                        ⇒ **加性、逐通道 clamp 到 0..255、不动 alpha、只挂在皮肤那一个 DisplayObject 上**
  `MButton3.as:329-345` 文字是**换色**（`overTextColor/downTextColor`），不是跟着变亮

一处有意偏离矩阵字面：`a == 0` 的全透像素 rgb 不动。Flash 走预乘 alpha，全透本来就不参与发光；
按字面执行会把 `(0,0,0,0)` 变成 `(30,30,30,0)`，线性过滤时渗出一圈亮边。

适用族：**只有一张 upSkin、靠运行时滤镜出 over/down 的那些**（`MButton3` / `MTabButton` /
`MButtonF` / `KeyboardFrameMButtonF`）。有独立 `downSkin` 的 `MButton` 族**不许**用这里烘。
"""
import os
import sys

from PIL import Image


def 加亮(数, 偏移):
    """对 `Image.getdata()` 出来的像素序列做 `clamp(rgb + 偏移)`，alpha 原样。"""
    return [p if p[3] == 0 else tuple(min(255, max(0, c + 偏移)) for c in p[:3]) + (p[3],) for p in 数]


def 灰度(数):
    """`StyleUtil.getGrayFilter()`（`StyleUtil.as` 的 ColorMatrixFilter）：
    R/G/B 各 = `0.3086R + 0.6094G + 0.082B`，**alpha 行 `0,0,0,1,0` ⇒ alpha 原样**。
    与 `加亮` 同一条"全透像素 rgb 不动"的偏离（理由见文件头）。
    ⚠️ 系数不许换成 Rec.601 的 0.299/0.587/0.114 —— 那是另一套数，像素门会红。"""
    出 = []
    for p in 数:
        if p[3] == 0:
            出.append(p)
            continue
        灰 = min(255, max(0, int(round(p[0] * 0.3086 + p[1] * 0.6094 + p[2] * 0.082))))
        出.append((灰, 灰, 灰, p[3]))
    return 出


def 烘焙(源, 落, 偏移):
    """`源` 常态皮 → `落` 派生皮，并**逐字节自检**（回读比对公式），不等就抛。返回尺寸。
    `偏移 is None` ⇒ 走 `灰度()`（禁用态）；否则走 `加亮(偏移)`（悬停/按下）。"""
    底 = Image.open(源).convert("RGBA")
    原 = list(底.getdata())
    期 = 灰度(原) if 偏移 is None else 加亮(原, 偏移)
    图 = Image.new("RGBA", 底.size)
    图.putdata(期)		# putdata 是就地改、返回 None ⇒ 不能链式 save
    图.save(落)
    检 = list(Image.open(落).convert("RGBA").getdata())
    差 = sum(1 for a, b in zip(检, 期) if a != b)
    if 差:
        raise SystemExit("派生图 %s 有 %d 像素不等于 %s" % (
                落, 差, "getGrayFilter" if 偏移 is None else "clamp(皮肤%+d)" % 偏移))
    return 底.size


def 派生(源, 态表=(("悬停", 30), ("按下", -40)), 出目录=None):
    """给一张常态皮烘出它的交互态 ⇒ `<主干>_<态名>.png`。返回 [(落路径, 尺寸, 偏移)]。
    `出目录` 是给"常态皮在共享目录、派生皮不许倒进共享目录"用的
    （skill `flash-mbutton3-state-skins` 第 5 条：`原版窗口/通用控件/` 里不放派生件）。
    偏移写 `None` ⇒ 烘**禁用态灰皮**（`getGrayFilter`，Godot 侧对应 `texture_disabled`）。"""
    if not os.path.isfile(源):
        raise SystemExit("常态皮不存在：%s" % 源)
    主干 = 源[:-len(".png")]
    if 出目录:
        os.makedirs(出目录, exist_ok=True)
        主干 = os.path.join(出目录, 主干.rsplit("/", 1)[-1])
    出 = []
    for 后缀, 偏移 in 态表:
        落 = "%s_%s.png" % (主干, 后缀)
        出.append((落, 烘焙(源, 落, 偏移), 偏移))
    return 出


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    print(__doc__)
