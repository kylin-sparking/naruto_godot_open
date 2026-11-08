# -*- coding: utf-8 -*-
"""导出「升级条件」那三个数要用的 `SkillReqTable` → 数据/技能升级需求表.json。

为什么在客户端而不是服务端
--------------------------
忍术详情区下半块（已学技能时显示的「升级条件」）要三个数：

    DataCenter.as:548  upgradeReqLevel = SkillReqTable.getSkillReqLevel(技能等级 + 1)
    DataCenter.as:549  upgradeReqCoin  = SkillReqTable.getSkillReqCoins (技能等级 + 1, 技能id)
    DataCenter.as:551  upgradeReqTotalBreath = SkillDataTool.getSkillReqZQ(技能id, 技能等级 + 1)

它们全在**客户端 SWF 的静态表** `com/mxw/common/data/skills/SkillReqTable.as` 里，
服务端不下发。表是 `table[等级] = [需要人物等级, 需要金币, 需要精华]`：

    table[2] = [2, 4, 62]     → 升到 2 级需要人物 2 级、4 金币、62 精华
    table[3] = [3, 9, 75]     → 升到 3 级需要人物 3 级（正是"技能等级不能超过人物等级"）

家族技能（`id/100 == 31` 或 `32`，即八门奥义那批）走另一张 `tableFamily`。

界面上「精华消耗」显示的**不是**总量，而是还差多少：
`SkillUpgradeConditionPane.as:93` `_loc2_ = upgradeReqTotalBreath - upgradeCurrentBreath`，
其中 `upgradeCurrentBreath = 技能的 masterLevel`（熟练度，客户端没有就按 0）。

用法
----
    python 开发工具/导出升级需求表.py

产物
----
    数据/技能升级需求表.json   {maxLevel, table: [[等级,金币,精华]...], tableFamily: [...]}
"""

import io
import json
import os
import re
import sys

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from 原版数据 import AS文件  # noqa: E402

源文件 = AS文件("com", "mxw", "data", "SkillReqTable.as")
产物 = os.path.join(项目根, "数据", "技能升级需求表.json")


def 取数组(源: str, 名: str) -> list:
    """抠出 `private static const/var <名>:Array = [[...],[...]];` 里的数组字面量。"""
    起 = 源.index(名)
    起 = 源.index("[", 起)
    # 一直读到与之配平的 `]`
    层 = 0
    for i in range(起, len(源)):
        if 源[i] == "[":
            层 += 1
        elif 源[i] == "]":
            层 -= 1
            if 层 == 0:
                return json.loads(源[起 : i + 1])
    raise ValueError("数组 %s 没有配平的右括号" % 名)


def 主() -> int:
    if not os.path.exists(源文件):
        print("找不到原版 SkillReqTable：%s" % 源文件)
        return 1
    源 = io.open(源文件, encoding="utf-8").read()

    上限 = int(re.search(r"public static var maxLevel:int\s*=\s*(\d+);", 源).group(1))
    table = 取数组(源, "private static const table:Array")
    tableFamily = 取数组(源, "private static var tableFamily:Array")

    输出 = {
        "_说明": (
            "忍术【升级条件】那三个数的来源。原版在客户端 SWF 的静态表里（SkillReqTable.as），"
            "服务端不下发。table[等级] = [需要人物等级, 需要金币, 需要精华]；"
            "家族技能（id/100 为 31 或 32）走 tableFamily。"
            "升级到 N 级就查 table[N]——所以技能等级不超过人物等级。"
            "界面上的「精华消耗」显示的是 总需 - 当前熟练度（masterLevel），客户端没有熟练度就按 0。"
        ),
        "maxLevel": 上限,
        "table": table,
        "tableFamily": tableFamily,
    }
    os.makedirs(os.path.dirname(产物), exist_ok=True)
    io.open(产物, "w", encoding="utf-8").write(
        json.dumps(输出, ensure_ascii=False, separators=(",", ":"))
    )
    print("maxLevel=%d  table %d 条  tableFamily %d 条 -> %s"
          % (上限, len(table), len(tableFamily), 产物))
    for 级 in (2, 3, 4):
        print("  升到 %d 级：人物 %d 级 / 金币 %d / 精华 %d"
              % (级, table[级][0], table[级][1], table[级][2]))
    return 0


if __name__ == "__main__":
    sys.exit(主())
