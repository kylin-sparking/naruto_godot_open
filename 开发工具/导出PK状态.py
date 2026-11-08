# -*- coding: utf-8 -*-
"""导出罪状（叛忍等级）Buff 的阈值/文案/图标技能号 → 数据/PK状态.json。

为什么需要它
------------
原版 HUD 的罪状格**不是服务端推的一条 buff**：`PVPHandler.checkAddCrimeBuff:740-800`
拿角色当前罪恶值和 Buff/PK 表的 `crimeC/B/A/S.begin` 比，再按命中的那一行
`buffName` / `buffDesc` / `iconSkillId` 造一格（图标是 `PicTool.getSkillPic(iconSkillId)`，
**不是** Buff 行自己的 icon —— 那四行在原版里本来就没有 icon 字段）。

我们导出的 `状态图标.json` 只有 name/desc/贴图，没有 `begin` 与 `iconSkillId`，
所以客户端没法判级。这个脚本把三样缺的补成一张小表：

    {'C': {begin, end, name, desc, icon_skill_id}, ...}

真值出处
--------
* 阈值/文案/图标号：GameData `Buff` 段 `PK` 子表的 `crimeC/B/A/S`
  （`PVPHandler.as:745-776` 的取值顺序与判定全部照抄）。
* 图标解析：`iconSkillId` → 数据/技能.json 的 `icon_class` → 数据/技能素材索引.json。
  客户端最后仍走 `GAME_DATA.skill(id).icon`，这里只存 id，不存路径（避免两份真值）。

用法
----
    python 开发工具/导出PK状态.py
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 原版数据 import 取顶层段, 解载荷  # noqa: E402

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
产物 = os.path.join(项目根, "数据", "PK状态.json")

PK = 解载荷(取顶层段("Buff")["PK"])
技能 = json.load(io.open(os.path.join(项目根, "数据", "技能.json"), encoding="utf-8"))
素材 = json.load(io.open(os.path.join(项目根, "数据", "技能素材索引.json"), encoding="utf-8"))


def 图标路径(技能号: int) -> str:
    行 = 技能.get(str(技能号), {})
    类名 = str(行.get("icon_class", ""))
    return str(素材.get(类名, "")) if 类名 else ""


结果 = {}
for 级 in ("C", "B", "A", "S"):
    行 = PK.get("crime" + 级)
    if not isinstance(行, dict):
        raise SystemExit("Buff/PK 缺 crime%s —— 口径变了，先核原版" % 级)
    号 = int(行.get("iconSkillId") or 0)
    路径 = 图标路径(号)
    if 号 <= 0 or not 路径:
        raise SystemExit("crime%s 的 iconSkillId=%s 查不到技能图标（%s）" % (级, 号, 路径))
    结果[级] = {
        "begin": int(行.get("begin") or 0),
        "end": int(行.get("end") or 0),
        "name": str(行.get("buffName") or ""),
        "desc": str(行.get("buffDesc") or "").replace("\r", ""),
        "icon_skill_id": 号,
    }

输出 = {
    "_说明": (
        "罪状（叛忍等级）Buff 的阈值/文案/图标技能号。原版 PVPHandler.checkAddCrimeBuff:740-800 "
        "按 Buff/PK 的 crimeC/B/A/S.begin 判级，图标取 PicTool.getSkillPic(iconSkillId)。"
        "生成工具：开发工具/导出PK状态.py；别手改。"
    ),
    "罪状": 结果,
}
io.open(产物, "w", encoding="utf-8").write(json.dumps(输出, ensure_ascii=False, indent=1, sort_keys=True))
print("数据/PK状态.json：%s" % ", ".join(
    "%s>=%d(%s)" % (级, 结果[级]["begin"], 结果[级]["name"]) for 级 in ("C", "B", "A", "S")))
