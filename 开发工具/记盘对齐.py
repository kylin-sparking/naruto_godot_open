# -*- coding: utf-8 -*-
"""把「盘到底差几像素」这条实测结论落进 `数据/界面/打坐光环.json`（纯记录，不参与摆位）。

跑：python 开发工具/记盘对齐.py
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
import 盘配准

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
路 = os.path.join(工程, "数据", "界面", "打坐光环.json")
表 = json.load(io.open(路, encoding="utf-8"))
量, _ = 盘配准.量全部(工程, 路, 基准=0)

错位 = {str(i): list(量[i]["应加"]) for i in sorted(量) if 量[i]["应加"] is not None}
修正 = {str(i): list(量[i]["position修正"]) for i in sorted(量) if 量[i]["position修正"] is not None}
自检 = {str(i): {"峰尖度": round(量[i]["峰尖"], 2), "阳性对照": bool(量[i]["对照"])}
        for i in sorted(量) if not 量[i].get("基准")}

# ★ 每帧落两个**摆位补量**：`补x`/`补y` = position 该加多少才与第 0 帧的盘重合。
#   生成器按 `position = (−原点x + 补x, −原点y + 补y)` 烘进场景 ⇒ 编辑器所见 == 游戏所得。
#   ⚠ 补量只许由这张表来（脚本里不许再加第二种补偿），否则又回到"越修越飘"的老路。
for i, 帧 in enumerate(表["帧"]):
    帧["补x"] = 修正[str(i)][0]
    帧["补y"] = 修正[str(i)][1]

表["补x补y口径"] = (
    "`position = (−原点x + 补x, −原点y + 补y)`。补量**只**来自 `盘对齐实测.position修正`"
    "（= 叠图应加取反，符号由 `开发工具/验盘配准符号.py` 实测钉死：内容往下搬 5 像素、工具的 dy 跟着 +5"
    " ⇒ 叠图量与 position 反号）。除这两个字段之外，任何地方都不许再给这圈特效加位移。")

表["盘对齐实测"] = {
    "出处": "2026-10-13 由 `开发工具/盘配准.py` 现查（以第 0 帧那块阵为尺子：两帧都按注册点铺进同一张"
            "叠图，只认画实的像素 alpha>200 把半透明辉光切掉，±6 搜重叠区色差最小的整数位移）。"
            "**每条都带两条自检**：① 阳性对照 = 先把该帧故意压 5 像素再搜、必须报出 −5（全部通过）；"
            "② 峰尖度 = 竖直色差曲线两端最差 ÷ 谷底（>1.15 才算尖）。"
            "⇒ 结论：第 1~5 帧与第 0 帧一比一重合，**只有第 6、7 两帧的盘偏左上 2~3 像素**"
            "（叠图应加 (−2,−3) ⇒ position 该加 (+2,+3)）。根因在原版素材：原版"
            "`FrameQueueAnimation.generateCharacterItem()` 每帧 `ci.setOrigin(该帧自己的 origin)`"
            "（`FrameQueueAnimation.as:56-70` + `CharacterItem.as:53-60`）⇒ 原版播到这两帧同样跳。"
            "⇒ 2026-10-13 用户点头：把这两帧各挪 2~3 像素，让九帧的阵一比一重合。",
    "口径": "`各帧错位` = 叠图里该往哪挪（与 position **反号**，见 `补x补y口径`）；"
            "`position修正` = 该帧 position 该加多少才与第 0 帧的盘重合 = 已取反，就是 `补x`/`补y`。"
            "对账跑 `python 开发工具/读回打坐九帧位.py`（它把这张表与 `.tscn` 现值合起来判重合）。",
    "基准帧": 0,
    "各帧错位": 错位,
    "position修正": 修正,
    "自检": 自检,
}
表["环底距出处"] = str(表["环底距出处"]).replace(
    "盘挪没挪的判据见 开发工具/配盘定基准.py（拿第0帧那块盘的花纹 RGB 去每帧找它自己，九帧最佳偏移全是 (0,0)）。",
    "⚠ `配盘定基准.py` 那条『九帧最佳偏移全 (0,0)』是**假阴性**（它自己同时报了七帧『峰不尖』= 认不出位移），"
    "已作废。盘挪没挪改按 `开发工具/盘配准.py`（带阳性对照 + 峰尖度两条自检）⇒ 实测第 1~5 帧重合、"
    "第 6/7 帧偏 (−2,−3)，见本表 `盘对齐实测`。")

io.open(路, "w", encoding="utf-8").write(json.dumps(表, ensure_ascii=False, indent=1) + "\n")
print("已写入 `盘对齐实测`：", json.dumps(错位, ensure_ascii=False))
