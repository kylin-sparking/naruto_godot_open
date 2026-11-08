# -*- coding: utf-8 -*-
"""从 `数据/技能_原版.json` 抽出「这个技能是主动还是被动」，落成一张小表。

为什么要它
----------
我们的代码一直用 `damage > 0` 当"主动"的判据（技能面板的可绑定/可释放都看它）。
**这个判据是错的**：面积类技能的 `damage` 是**负数**（那是倍率不是伤害），
`3001003 面积 = -40`、`1001003 面积 = -40` —— 于是它们被当成被动，
拖不进快捷键栏、按了也没反应（用户 2026-09-27 报的"有一个 3 技能被识别为被动技能"）。

真值在原版技能记录的 `info` 里，两个键互斥：

    info.type_attack  —— 有它 = **主动**（`SkillDataTool.getSkillEffectType()` 读的就是它）
    info.type_attr    —— 有它 = **被动 / 属性类**

样本实测 100% 干净：`3001001/3001003/0002000/0009030/0002001` 都是 `type_attack`；
`0001000 体能强化 / 0001004 替身术` 都是 `type_attr`。

产物
----
`数据/技能主动.json`   {技能id: true/false}
两个标记都没有的技能**不收**（调用方对"表里没有"默认按主动处理 —— 与原版拖拽不设门槛一致）。

用法
----
    python 开发工具/导出技能主动.py
"""

import io
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
源 = os.path.join(项目根, "数据", "技能_原版.json")
产物 = os.path.join(项目根, "数据", "技能主动.json")


def main() -> int:
    if not os.path.exists(源):
        print("缺少 %s —— 先跑 开发工具/导出技能数据.py" % 源)
        return 1
    with io.open(源, encoding="utf-8-sig") as f:
        原版 = json.load(f)

    表 = {}
    两种都没有 = []
    for 技能id, 记录 in 原版.items():
        if not isinstance(记录, dict):
            continue
        info = 记录.get("info")
        if not isinstance(info, dict):
            continue
        主动 = "type_attack" in info
        被动 = "type_attr" in info
        if 主动 or 被动:
            # 两个都有时以 type_attack 为准（原版按这个取效果类型），但记一笔便于排查。
            表[str(技能id)] = 主动
        else:
            两种都没有.append(str(技能id))

    io.open(产物, "w", encoding="utf-8").write(
        json.dumps(表, ensure_ascii=False, sort_keys=True)
    )
    主动数 = sum(1 for v in 表.values() if v)
    print("技能 %d 条：主动 %d / 被动 %d -> %s" % (len(表), 主动数, len(表) - 主动数, 产物))
    if 两种都没有:
        print("⚠️ 两个标记都没有的 %d 条（调用方会按主动处理）：%s" % (len(两种都没有), 两种都没有[:8]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
