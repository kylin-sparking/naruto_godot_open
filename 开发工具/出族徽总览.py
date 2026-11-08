# -*- coding: utf-8 -*-
"""出**族徽总览图**：把 `素材/界面/原版窗口/家族/家徽_*.png`（200 张样式）拼成一张大图，
一格一个样式、格下标样式号，方便一次看完"所有族徽长什么样"。

为什么需要它
------------
族徽有 **200 个样式**，而界面里**同时只能看到 1 个**（家族页/创建窗预览/族旗/头顶各一处）——
逐个进游戏翻页看 200 次不现实。用户 2026-10-15 要求"直接使用素材、我来看看所有族徽的效果"
⇒ 拼图是唯一能一次性验收的办法（也是"素材本体长什么样"的留痕：图里出现橘金色就说明没导干净）。

用法
----
    <python> 开发工具/出族徽总览.py                 # → .scratch/族徽总览.png（4 倍放大、10 列）
    <python> 开发工具/出族徽总览.py 出.png 6 3      # 指定输出、列数、放大倍数

⚠️ 只读素材、不改素材；输出默认落 `.scratch/`（gitignore）。
"""

import os
import sys

from PIL import Image, ImageDraw

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
素材目录 = os.path.join(项目根, "素材", "界面", "原版窗口", "家族")

## `.scratch/` 是本工程的临时产物目录（gitignore），要留痕的结论写文档/提交信息。
出目录 = os.path.join(项目根, ".scratch")


def 列样式() -> list[int]:
    出 = []
    for 名 in os.listdir(素材目录):
        if 名.startswith("家徽_") and 名.endswith(".png"):
            尾 = 名[len("家徽_"):-len(".png")]
            if 尾.isdigit():
                出.append(int(尾))
    return sorted(出)


def 主() -> int:
    参数 = [a for a in sys.argv[1:]]
    出图 = 参数[0] if len(参数) > 0 else os.path.join(出目录, "族徽总览.png")
    列数 = int(参数[1]) if len(参数) > 1 else 10
    倍 = int(参数[2]) if len(参数) > 2 else 4

    样式表 = 列样式()
    if not 样式表:
        raise SystemExit(f"素材目录里没有 家徽_*.png：{素材目录}（先跑 开发工具/导出家族家徽.py）")

    首 = Image.open(os.path.join(素材目录, f"家徽_{样式表[0]}.png")).convert("RGBA")
    边长 = 首.size[0] * 倍
    标签高 = 16
    间隙 = 6
    行数 = (len(样式表) + 列数 - 1) // 列数
    宽 = 列数 * (边长 + 间隙) + 间隙
    高 = 行数 * (边长 + 标签高 + 间隙) + 间隙
    # 底色用中灰：既能看清白圆盘，也能看清深灰卷纹（透明处不踩到"看不见"）。
    画布 = Image.new("RGBA", (宽, 高), (96, 96, 104, 255))
    笔 = ImageDraw.Draw(画布)
    for i, 样式 in enumerate(样式表):
        列 = i % 列数
        行 = i // 列数
        x = 间隙 + 列 * (边长 + 间隙)
        y = 间隙 + 行 * (边长 + 标签高 + 间隙)
        with Image.open(os.path.join(素材目录, f"家徽_{样式}.png")).convert("RGBA") as 图:
            画布.alpha_composite(图.resize((边长, 边长), Image.NEAREST), (x, y))
        笔.text((x, y + 边长 + 2), str(样式), fill=(255, 255, 255, 255))

    os.makedirs(os.path.dirname(os.path.abspath(出图)), exist_ok=True)
    画布.save(出图)
    print(f"[族徽总览] {len(样式表)} 个样式 → {出图}（{宽}×{高}，{列数} 列，{倍} 倍放大）")
    return 0


if __name__ == "__main__":
    sys.exit(主())
