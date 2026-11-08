# -*- coding: utf-8 -*-
"""从 `数据/技能_原版.json` 抽「技能出手时角色播哪个动作」，落成一张小表。

为什么需要它
------------
原版放技能时角色会播一个**出手动作**，出处是 `AbstractAttackSkill.setStances():592-599`：

    var _loc1_:Array = SkillDataTool.getSkillAction(skillId);   // 读技能记录的 `action` 字段
    if(Boolean(_loc1_) && _loc1_.length > 0) { this.stances = _loc1_; }

而基类 `AbstractSkill.as:16` 的默认值是 `[Action.alert]` —— 也就是**技能没写 `action` 就播 `alert`**。
我们这边原来放技能时角色**一点动作都没有**（技能特效照放），用户看得出来。

产物
----
`数据/技能动作.json`   {技能id: [动作名, …]}   例：{"1001001": ["stab1"], "0002000": ["stab3"]}
只收有 `action` 的条目；查不到的技能由调用方退回基类默认值 `alert`（**不要在这里补默认值**，
否则"表里没有"和"原版就是这么写"就分不出来了）。

用法
----
    python 开发工具/导出技能动作.py
"""

import io
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
源 = os.path.join(项目根, "数据", "技能_原版.json")
产物 = os.path.join(项目根, "数据", "技能动作.json")

# 原版 `Action.as:6` 的 ActionName 表（下标即动作 id）。只认这些名字，
# 表里出现别的名字要**报出来**，别静默透传（透传会在 Godot 侧静默播不动）。
动作名 = {
    "stand", "jump", "walk", "ladder", "rope", "alert",
    "sit0", "sit1", "hit", "dead", "attack", "stab1", "stab2", "stab3",
}


def 取动作(记录: dict):
    """`action` 在原数据里是 {下标: 名字}，也可能是单个字符串。"""
    值 = 记录.get("action")
    if isinstance(值, dict):
        键 = sorted(值, key=lambda k: int(k) if str(k).isdigit() else 0)
        return [str(值[k]) for k in 键]
    if isinstance(值, str):
        return [值]
    return []


def main() -> int:
    if not os.path.exists(源):
        print("缺少 %s —— 先跑 开发工具/导出技能数据.py" % 源)
        return 1
    with io.open(源, encoding="utf-8-sig") as f:
        原版 = json.load(f)

    表 = {}
    不认识 = []
    for 技能id, 记录 in 原版.items():
        if not isinstance(记录, dict):
            continue
        动作 = 取动作(记录)
        if not 动作:
            continue
        for 名 in 动作:
            if 名 not in 动作名:
                不认识.append((技能id, 名))
        表[str(技能id)] = 动作

    io.open(产物, "w", encoding="utf-8").write(
        json.dumps(表, ensure_ascii=False, indent=1, sort_keys=True)
    )
    print("有出手动作的技能 %d 条 -> %s" % (len(表), 产物))
    用到 = sorted({名 for 动作 in 表.values() for 名 in 动作})
    print("用到的动作：%s" % 用到)
    if 不认识:
        print("⚠️ 有不在 Action.ActionName 里的名字：%s" % 不认识[:10])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
