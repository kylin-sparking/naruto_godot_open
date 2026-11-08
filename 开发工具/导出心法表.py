# -*- coding: utf-8 -*-
"""生产链：从原版 GameData 导 `数据/界面/心法表.json` —— 心法窗（XinfaWindow）的列表数据源。

为什么要有这张表（2026-10-13）：原版心法窗里那几枚格子**不是**"全部心法技能"，
而是**本角色已学的心法**（`DataCenter.getFirstTypePassivizeSkills():2058-2072` 遍历的是
`skillInfoList`，再按 `SkillDataTool.isSkillXinfa(id)` 过滤）。而"哪条算心法""叫什么名字"
两件事分别躺在 GameData 的两个段里，客户端原来的 `数据/技能.json` **一个都没带**：

· **是不是心法** = `Skill` 段每条的 `info.desc.xinfa == 1`（原版判据
  `SkillDataTool.isSkillXinfa():252-257`）⇒ 全表 21 条。
· **名字与描述** = `String` 段的 `Skill` 子段（原版 `StringTool.getSkillString():114-119`），
  键是 `ImgUtil.getSkillNumName(id)`（`ImgUtil.as:220-232`：**小于 10000 就左补零到 7 位**，
  否则原样字符串）。⇒ ⚠ **不在 `Skill` 段的 `info.desc.name` 里** —— 那里 21 条有 15 条是空串，
  照着它做窗里就会缺一大半空白名。
· **图标** = `Skill` 段 `icon.value.className`，路径查 `数据/技能素材索引.json`（21 枚实测全在）。

数据源钉死：`原版数据.py`（按 环境变量 NARUTO_GAME_ROOT → 候选目录 找 GameData.dat），
不写死某台机器的路径。跑之前先确认它解到的是 **2.2.3优化版** 那一份（用户令）。

用法：python 开发工具/导出心法表.py
产物：数据/界面/心法表.json
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 原版数据 import 取顶层段, 解载荷  # noqa: E402

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
产物 = os.path.join(工程, "数据", "界面", "心法表.json")
索引路 = os.path.join(工程, "数据", "技能素材索引.json")
原版表路 = os.path.join(工程, "数据", "技能_原版.json")


def 心法键(号: str) -> str:
    """原版 `ImgUtil.getSkillNumName()`：数值 < 10000 ⇒ 左补零到 7 位；否则原样。"""
    n = int(号)
    return ("%07d" % n) if n < 10000 else str(n)


def main() -> int:
    if not os.path.exists(原版表路):
        print("!! 先跑 python 开发工具/导出技能数据.py 生成 数据/技能_原版.json")
        return 1
    技能 = json.load(io.open(原版表路, encoding="utf-8"))
    索引 = json.load(io.open(索引路, encoding="utf-8")) if os.path.exists(索引路) else {}
    名段 = 解载荷(取顶层段("String")["Skill"])
    if not isinstance(名段, dict):
        print("!! GameData 的 String.Skill 段解不开 ⇒ 名字取不到，不许写表")
        return 1

    条目 = {}
    缺名 = []
    缺图 = []
    for 号, 录 in sorted(技能.items()):
        if not isinstance(录, dict):
            continue
        信 = 录.get("info") or {}
        述 = 信.get("desc") or {}
        if 述.get("xinfa") != 1:
            continue
        开 = 信.get("open") or {}
        图类 = str(((录.get("icon") or {}).get("value") or {}).get("className", ""))
        路 = 索引.get(图类, "")
        名 = 名段.get(心法键(号)) or 名段.get(str(号))
        if not isinstance(名, dict):
            缺名.append(号)
            名 = {}
        if not 路:
            缺图.append(号)
        条目[号] = {
            "名称": str(名.get("name", "")),
            "描述": str(名.get("desc", "")).replace("\r\n", "\n"),
            "获得途径": str(名.get("gain", "")),
            "图标": 路,
            "图标类名": 图类,
            "组": str(录.get("_组", "")),
            "属性": str((信.get("type_attr") or {}).get("type", "")),
            "需要等级": int(开.get("reqLevel", 0) or 0),
            "需要秘笈": str(开.get("reqBook", "") or ""),
        }

    表 = {
        "说明": "心法窗（XinfaWindow）的**候选表**：全 21 条心法技能。窗里实际列出的不是这 21 条，"
                "而是**本角色已学的那些**（原版 `getFirstTypePassivizeSkills()` 遍历 skillInfoList 再按 "
                "xinfa==1 过滤）⇒ 控制器拿 `后端连接.authoritative_skills` 的键与这张表求交集。",
        "出处": "是否心法 = GameData `Skill` 段 `info.desc.xinfa == 1`（原版判据 "
                "`SkillDataTool.isSkillXinfa():252-257`）；名称/描述 = GameData `String` 段的 `Skill` 子段"
                "（原版 `StringTool.getSkillString():114-119`，键 = `ImgUtil.getSkillNumName(id)`，"
                "`ImgUtil.as:220-232` 小于 10000 左补零到 7 位）。⚠ **不要用 `Skill` 段自己的 "
                "`info.desc.name`** —— 21 条里 15 条是空串，照着做窗里会一片空白。"
                "图标路径查 `数据/技能素材索引.json`（21 枚实测全在）。",
        "条目": 条目,
    }
    os.makedirs(os.path.dirname(产物), exist_ok=True)
    io.open(产物, "w", encoding="utf-8").write(json.dumps(表, ensure_ascii=False, indent=1) + "\n")
    print("写了 %d 条心法 → %s" % (len(条目), 产物))
    for 号, 项 in 条目.items():
        print("  %-8s %-12s 图标%s  需等级%-3d 属性%s" % (
            号, 项["名称"], "有" if 项["图标"] else "缺", 项["需要等级"], 项["属性"] or "-"))
    if 缺名:
        print("!! 名称查不到的：%s ⇒ 这些条在窗里会是空白，别放行" % 缺名)
        return 1
    if 缺图:
        print("!! 图标路径查不到的：%s" % 缺图)
        return 1
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
