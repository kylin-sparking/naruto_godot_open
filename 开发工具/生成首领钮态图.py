# -*- coding: utf-8 -*-
"""给首领页翻页条的四枚箭头烘 MButton3 交互态皮（悬停 +30 / 按下 −40 / 禁用灰）。

真值：`PageComponent.createArrowBtn:70-75` 造的是 **`MButton3`**（字段声明 `:23-41`
`firstBtn/preBtn/nextBtn/lastBtn:MButton3`）⇒ 一张皮 + 运行时滤镜，不是每态一张真皮：
  * `StyleUtil.as:7-12`   `skinFilters = {up:0, over:+30, down:−40}`
  * `StyleUtil.as:43-47`  `getLightFilter` = 加性、逐通道 clamp、**不动 alpha**
  * `MButton3:329-345`    滤镜只挂皮肤那一个 DisplayObject；禁用走 `getGrayFilter()`
  * `MButton3.init:135`   `buttonMode = useHandCursor = true` ⇒ 手型

落点：常态皮是**共享**的 `原版窗口/通用控件/{首页,上一页,下一页,末页}.png`，
派生件不许倒进共享目录（skill `flash-mbutton3-state-skins` 第 5 条）⇒ 落 `专用控件/`，
主干加 `分页` 前缀（同目录已有先例 `分页按钮未选_悬停.png`）。

用法：python 开发工具/生成首领钮态图.py      # 幂等，重跑字节不变；每张都逐字节自检
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 派生钮态 as 派生  # noqa: E402

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
通用 = os.path.join(工程, "素材", "界面", "原版窗口", "通用控件")
专用 = os.path.join(工程, "素材", "界面", "专用控件")

# 主干 → (原生宽, 元件符号)。宽只用来核对没导错图（18/15/15/18，`PageComponent:78-90`）。
源表 = [("首页", 18, "MPageFirstBtnF(992)"), ("上一页", 15, "MPagePreBtnF(856)"),
        ("下一页", 15, "MPageNextBtnF(855)"), ("末页", 18, "MPageEndBtnF(991)")]
态表 = [("悬停", 30), ("按下", -40), ("灰", None)]


def 主():
    总 = 0
    for 主干, 宽, 符号 in 源表:
        源 = os.path.join(通用, "%s.png" % 主干)
        for 后缀, 偏移 in 态表:
            落 = os.path.join(专用, "分页%s_%s.png" % (主干, 后缀))
            尺 = 派生.烘焙(源, 落, 偏移)
            if 尺[0] != 宽:
                raise SystemExit("%s 宽 %d ≠ 元件 %s 的原生 %d ⇒ 拿错图了" % (源, 尺[0], 符号, 宽))
            总 += 1
            print("出 %s  %dx%d  %s" % (os.path.relpath(落, 工程), 尺[0], 尺[1],
                    "getGrayFilter" if 偏移 is None else "clamp(皮肤%+d)" % 偏移))
    print("共 %d 张（4 枚 × 3 态），逐字节等于公式已自检" % 总)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    主()
