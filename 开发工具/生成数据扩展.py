# -*- coding: utf-8 -*-
"""把 2.2.3 有、客户端快照没有的那几条数据补进 `数据_扩展/`。

为什么要单独一个"扩展层"而不是重导整表
--------------------------------------
客户端的 `数据/技能.json`、`数据/物品.json` 是 `开发工具/导出游戏数据.mjs` 从
**另一份 GameData 快照**（`NarutoWorld_Server_202607222145-master/data/GameData.dat.json`）
烘出来的，那份快照比 2.2.3 旧：**2098 个物品 vs 2.2.3 的 1395**（算法不同、口径不同）。
拿 2.2.3 重导整表会把客户端多出来的那 700 条冲掉，所以只补差额。

`脚本/单例/游戏数据.gd` 的 `reload()` 会把 `res://数据_扩展/<表名>.json` 深合并到基表之上，
本工具就写这个目录。字段口径**照抄 `导出游戏数据.mjs`**，保证补进来的记录和原有的长得一样。

现在缺什么（实测，2026-09-18）
------------------------------
- 技能：2.2.3 玩家组有 156 条，客户端 150 条，差 6 条
  （`0008029` 与 5 个「特别技能」`0009029`-`0009033`）。
  其中 `0008029` **不在任何页签里**（`getSkillIdsForJob` 从不返回它），它是 9029 的
  图标/特效来源行，且没有名字，所以**不补**（补了会多出一个无名技能）。
- 物品：技能书 `JiNengShu` 差 6 本、技能残卷 `JiNengCanJuan` 差 2 张
  ——「学习方法」那行的《需要秘笈》点开就是查这张表。

用法
----
    python 开发工具/生成数据扩展.py [--只报]
"""

import argparse
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from 原版数据 import 取字符串段, 取顶层段, 解载荷, 读根  # noqa: E402

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
数据目录 = os.path.join(项目根, "数据")
扩展目录 = os.path.join(项目根, "数据_扩展")

玩家组 = ("000", "100", "200", "300", "400", "900")
# 照抄 导出游戏数据.mjs 的物品分类表
物品分类 = {
    "ZhuangBei": "装备", "XiaoHao": "消耗品", "JiNengShu": "技能书", "JiNengCanJuan": "技能残卷",
    "FuZhuWuPin": "辅助物品", "BuffWuPin": "增益物品", "BaoShi": "宝石", "LingQi": "灵器",
    "CaiLiao": "材料", "RenWuWuPin": "任务物品", "TeShuWuPin": "特殊物品", "LiBao": "礼包",
    "HunJie": "魂戒", "ShenQi": "神器", "Pet": "宠物", "Spirit": "意志",
}


def 读客户端表(名: str) -> dict:
    路径 = os.path.join(数据目录, 名)
    if not os.path.exists(路径):
        return {}
    return json.load(io.open(路径, encoding="utf-8"))


def 读扩展表(名: str) -> dict:
    路径 = os.path.join(扩展目录, 名)
    if not os.path.exists(路径):
        return {}
    return json.load(io.open(路径, encoding="utf-8"))


def 取文本(分类: str, 编号: str) -> dict:
    表 = 取字符串段(分类)
    键 = str(编号)
    for 候选 in (键, 键.zfill(8), 键.lstrip("0")):
        if 候选 in 表:
            条 = 解载荷(表[候选])
            return 条 if isinstance(条, dict) else {}
    return {}


def 编号排序(编号: str):
    return int(编号) if str(编号).isdigit() else 0


# ------------------------------------------------------------------ 技能

def 补技能() -> dict:
    已有 = 读客户端表("技能.json")
    Skill段 = 读根().get("Skill") or {}
    玩家 = {}
    for 组名, 载荷 in Skill段.items():
        if 组名 not in 玩家组:
            continue
        解出 = 解载荷(载荷)
        条目 = 解出.get("skill") if isinstance(解出, dict) else None
        if isinstance(条目, dict):
            玩家.update(条目)
    # 页签会显示的集合（没在这张表里的技能，补了也没人显示）
    分页路径 = os.path.join(数据目录, "界面", "技能分页.json")
    页签id = set()
    if os.path.exists(分页路径):
        分页 = json.load(io.open(分页路径, encoding="utf-8"))
        for 清单 in (分页.get("页签", {}) or {}).values():
            for 列 in (清单.get("列", []) if isinstance(清单, dict) else []):
                if isinstance(列, list):
                    页签id.update(x for x in 列 if isinstance(x, str) and not x.startswith("$"))
        for 清单 in (分页.get("职业普攻", {}) or {}).values():
            页签id.update(清单)

    补 = {}
    for 编号, 原型 in 玩家.items():
        键 = str(编号)
        if 键 in 已有 or 键 in 读扩展表("技能.json"):
            continue
        信息 = 原型.get("info") or {}
        描述 = 信息.get("desc") or {}
        攻击 = (信息.get("type_attack") or {}).get("effect") or {}
        消耗 = 信息.get("consume") or {}
        冷却 = 信息.get("cool_down") or {}
        图标 = (原型.get("icon") or {}).get("value") or {}
        名字 = str(取文本("Skill", 键).get("name") or 描述.get("name") or "")
        # 只补**页签里会出现的**技能。0008029 这类行是 9029 的图标/特效来源，
        # `getSkillIdsForJob` 从不返回它（名字还叫"面积"，是作者期残留），补进去只会在
        # 技能表里多出一个原版界面上永远看不到的条目。
        if 键 not in 页签id:
            print("  跳过 %s（%s）：不在任何页签里，原版界面不显示它" % (键, 名字 or "无名字"))
            continue
        if not 名字:
            print("  跳过 %s：页签里有它但取不到名字" % 键)
            continue
        补[键] = {
            "id": 键,
            "job_group": str(原型.get("_组") or 键[:3]),
            "name": 名字,
            "description": str(描述.get("skillDesc") or 描述.get("desc") or ""),
            "range": int(描述.get("range") or 0),
            "target": int(描述.get("target") or 0),
            "skill_type": int(描述.get("skillType") or 0),
            "damage": 攻击.get("valueBase") or 攻击.get("damageBase") or 0,
            "damage_growth": 攻击.get("valueLevel") or 攻击.get("damageLevel") or 0,
            "mp_cost": 消耗.get("mpBase") or 消耗.get("mp") or 消耗.get("1") or 0,
            "cooldown": 冷却.get("cdBase") or 冷却.get("cd") or 1.12,
            "icon_class": str(图标.get("className") or ""),
            "icon_swf": str(图标.get("swfName") or ""),
        }
    return 补


# ------------------------------------------------------------------ 物品

def 补物品() -> dict:
    已有 = 读客户端表("物品.json")
    扩展已有 = 读扩展表("物品.json")
    补 = {}
    for 分类 in ("JiNengShu", "JiNengCanJuan"):
        段 = 取顶层段(分类) or {}
        for 编号 in 段:
            键 = str(编号)
            if not 键.isdigit():
                continue
            if 键 in 已有 or 键 in 扩展已有:
                continue
            信息 = (解载荷(段[编号]) or {}).get("info") or {}
            图标 = (信息.get("icon") or {}).get("value") or {}
            文本 = 取文本(分类, 键)
            补[键] = {
                "id": 键,
                "name": str(文本.get("name") or 信息.get("name") or 键),
                "description": str(文本.get("desc") or 文本.get("info") or ""),
                "category": 物品分类[分类],
                "source_category": 分类,
                "price": int(信息.get("price") or 0),
                "required_level": int(信息.get("reqLevel") or 0),
                "stack_max": int(信息.get("slotMax") or 1),
                "icon_class": str(图标.get("className") or ""),
                "icon_swf": str(图标.get("swfName") or ""),
            }
    return 补


def 写扩展(名: str, 补: dict) -> None:
    路径 = os.path.join(扩展目录, 名)
    合并 = 读扩展表(名)
    合并.update(补)
    排序后 = {k: 合并[k] for k in sorted(合并, key=编号排序)}
    os.makedirs(扩展目录, exist_ok=True)
    io.open(路径, "w", encoding="utf-8").write(
        json.dumps(排序后, ensure_ascii=False, indent=1)
    )
    print("  -> %s（原有 %d 条，本次新增 %d 条，共 %d 条）"
          % (路径, len(合并) - len(补), len(补), len(合并)))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--只报", action="store_true")
    args = ap.parse_args()

    print("补技能：")
    技能 = 补技能()
    for 键, v in sorted(技能.items(), key=lambda kv: 编号排序(kv[0])):
        print("  %s %s（%s 组，icon=%s）" % (键, v["name"], v["job_group"], v["icon_class"]))
    if not args.只报:
        写扩展("技能.json", 技能)

    print("补物品（技能书 / 技能残卷）：")
    物品 = 补物品()
    for 键, v in sorted(物品.items(), key=lambda kv: 编号排序(kv[0])):
        print("  %s %s（%s，需要等级 %d）" % (键, v["name"], v["category"], v["required_level"]))
    if not args.只报:
        写扩展("物品.json", 物品)
    return 0


if __name__ == "__main__":
    sys.exit(main())
