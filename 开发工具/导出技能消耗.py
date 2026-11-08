# -*- coding: utf-8 -*-
"""从 `数据/技能_原版.json` 抽技能的**释放消耗**（查克拉 / 查克拉精华），落成一张小表。

为什么要它
----------
原版 `AbstractSkill.isMpEnough():143-158` 检查**两样**：

    SkillDataTool.getSkillMp(skillId, level)      // 读技能的 `info.consume[等级]`
    SkillDataTool.getSkillConsumeZQ(skillId, level)  // 读技能的 `info.consumeZqLevel`
    不够就 `API.ui.addNotice(CNCore.FIGHT_WARNING_SHORT_OF_MP / _OF_ZQ)`

我们的 `数据/技能.json` 只有 `mp_cost`（一个数）、**完全没有查克拉精华这一项**。
于是客户端会心安理得地放一个根本付不起的技能：不提示、照样发包，
服务端回一句 `查克拉或查克拉精华不足，无法释放这个技能` 就没了 ——
用户实机看到的就是"按了技能怪一点事没有"（2026-09-27）。

产物
----
`数据/技能消耗.json`   {技能id: {"mp": {等级: 值}, "zq": 值}}
`mp` 只收原版那张逐级表里真有的键；`zq` 是 `consumeZqLevel`（原版就是个定值，不随等级变）。

用法
----
    python 开发工具/导出技能消耗.py
"""

import io
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
源 = os.path.join(项目根, "数据", "技能_原版.json")
产物 = os.path.join(项目根, "数据", "技能消耗.json")


def main() -> int:
    if not os.path.exists(源):
        print("缺少 %s —— 先跑 开发工具/导出技能数据.py" % 源)
        return 1
    with io.open(源, encoding="utf-8-sig") as f:
        原版 = json.load(f)

    表 = {}
    for 技能id, 记录 in 原版.items():
        if not isinstance(记录, dict):
            continue
        info = 记录.get("info")
        if not isinstance(info, dict):
            continue
        消耗 = info.get("consume")
        mp = {}
        if isinstance(消耗, dict):
            for 等级, 值 in 消耗.items():
                if str(等级).isdigit():
                    mp[str(int(等级))] = int(值)
        elif isinstance(消耗, (int, float)):
            mp["1"] = int(消耗)
        zq = info.get("consumeZqLevel")
        zq = int(zq) if isinstance(zq, (int, float)) else 0
        if mp or zq:
            表[str(技能id)] = {"mp": mp, "zq": zq}

    io.open(产物, "w", encoding="utf-8").write(
        json.dumps(表, ensure_ascii=False, sort_keys=True)
    )
    有精华 = [k for k, v in 表.items() if v["zq"] > 0]
    print("有消耗的技能 %d 条 -> %s" % (len(表), 产物))
    print("其中要查克拉精华的 %d 条：%s" % (len(有精华), 有精华[:8]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
