# -*- coding: utf-8 -*-
"""从原版 GameData.dat（AMF3）解出技能表，落成客户端用的 JSON。

为什么需要它
------------
客户端现在的 `数据/技能.json` 里 **132/150 条描述是占位的 "XXXX"**——详情区显示的
"XXXX" 就是从这来的。真描述、以及原版详情区「学习方法」要的**需要等级 / 需要秘笈**
（reqLevel / bookItem），都在服务端的 GameData.dat 里，从没被导出来过。

数据源
------
`2.2.3/www/act_web_nya_208_isolated/dat/GameData.dat`（AMF3 二进制，2.6MB）。
段名是 `Skill`（对照 `2.2.3/tools/fake_flash_server.py:5441` 的 `root.get("Skill")`）。
AMF3 读取与 .dat 定位都由 `开发工具/原版数据.py` 负责（它按 环境变量 → 候选目录 找原版，
不再写死某一台机器的路径）。

用法
----
    python 开发工具/导出技能数据.py

产物
----
    数据/技能_原版.json   {技能id: {所有原始字段…}}
"""

import io
import json
import os
import sys
from datetime import datetime
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# AMF3 读取与 .dat 定位都在 原版数据.py 里一份，别再抄一遍（抄两份迟早漂）。
from 原版数据 import 取顶层段, 解载荷, 读根  # noqa: E402

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
产物 = os.path.join(项目根, "数据", "技能_原版.json")


def 可序列化(value: Any) -> Any:
    """AMF3 里可能带 bytes / datetime，转成 JSON 能写的形态。"""
    if isinstance(value, bytes):
        return {"__bytes__": len(value)}
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, dict):
        return {str(k): 可序列化(v) for k, v in value.items()}
    if isinstance(value, list):
        return [可序列化(v) for v in value]
    return value


def main() -> int:
    root = 读根()
    if not isinstance(root, dict):
        print("GameData 根节点不是 AMF3 对象")
        return 1

    技能段 = 取顶层段("Skill")
    if not isinstance(技能段, dict):
        print("GameData 里没有 Skill 段。顶层键：%s" % sorted(root.keys()))
        return 1

    # 每个分组的载荷是 **zlib 压缩的 AMF3 字节串**（不是直接的对象），
    # 解压后再用同一个读取器解一层。分组内层键：职业组是 "skill"，
    # PetSkill 直接是 {宠物id: …}，Effect/ALL 是 "jiban"/"info"。
    摊平: dict = {}
    分组: dict = {}

    for 组名, 载荷 in 技能段.items():
        解出 = 解载荷(载荷)
        条目 = {}
        if isinstance(解出, dict):
            if isinstance(解出.get("skill"), dict):
                条目 = 解出["skill"]
            else:
                条目 = {k: v for k, v in 解出.items() if isinstance(v, dict) and not str(k).startswith("__")}
        for 技能id, 记录 in 条目.items():
            if not isinstance(记录, dict):
                continue
            项 = 可序列化(dict(记录))
            项["_组"] = str(组名)
            摊平[str(技能id)] = 项
        分组[str(组名)] = len(条目)

    os.makedirs(os.path.dirname(产物), exist_ok=True)
    io.open(产物, "w", encoding="utf-8").write(
        json.dumps(摊平, ensure_ascii=False, indent=1, sort_keys=True)
    )
    print("Skill 段分组：%s" % 分组)
    print("摊平后技能 %d 条 -> %s" % (len(摊平), 产物))
    报覆盖(摊平)
    return 0


# 玩家技能所在的分组（其余是宠物技能与特效表）
玩家组 = ("000", "100", "200", "300", "400", "900")

# GameData 里每个字段的可用条数——用来判断"还缺什么"，别只看总数
字段路径 = {
    "图标": "icon.value.className",
    "类型": "info.desc.skillType",
    "目标": "info.desc.target",
    "范围": "info.desc.range",
    "冷却": "info.cool_down.cdBase",
    "需要等级": "info.open.reqLevel",
    "需要秘笈": "info.open.reqBook",
    "数值成长": "info.type_attr",
    "攻击效果": "info.type_attack",
    "命中帧": "hit",
    "名称": "info.desc.name",
    "描述": "info.desc.desc",
}


def _有(记录: dict, 路径: str) -> bool:
    cur: Any = 记录
    for 段 in 路径.split("."):
        if not isinstance(cur, dict):
            return False
        cur = cur.get(段)
    return cur not in (None, "", {}, [])


def 报覆盖(摊平: dict) -> None:
    """按字段报可用条数。只看"总数"会误判——描述在 GameData 里本来就只有一部分。"""
    玩家 = {k: v for k, v in 摊平.items() if v.get("_组") in 玩家组}
    print("玩家技能 %d 条，各字段可用：" % len(玩家))
    for 名, 路径 in 字段路径.items():
        数 = sum(1 for v in 玩家.values() if _有(v, 路径))
        print("  %-8s %3d / %d" % (名, 数, len(玩家)))


if __name__ == "__main__":
    sys.exit(main())
