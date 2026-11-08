#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 2.2.3 服务端的 GameData 导出**装备打造配置表**（`EquipSystem` 整段）。

## 为什么需要它
原版的强化/进阶/刻印/镶嵌… 的消耗与成功率**不在客户端代码里** —— 在下载的 GameData 的
`EquipSystem` 段。反编译的 AS3 只引用它，值的本体读不到；服务端 `fake_flash_server.py`
是唯一能拿到它的地方。

## 为什么**原样导出**，不做字段改名
一开始我把 `needItemId` 之类翻成中文键名再落盘，等于**把同一份真值抄成两份**：
服务端改字段名、或者我抄漏一个字段，客户端就会**静默**错（§0.0 第一原则）。
所以这里把 `get_cultivation_config("EquipSystem")` **整个 dict 原样写出**，
客户端直接按服务端自己的字段名读 —— 中间没有可漂移的翻译层。

## 权威读法（服务端，客户端必须与它一致）
```
config = EquipSystem.strength["level<N>"]        # fake_flash_server.py:54300-54324
成功率   = config["prob"]                         # 百分数
幸运符   = 每颗 +3%，上限 config["maxHelpCnt"]     # _roll_forge: min(100, prob + 颗数*3)
消耗     = needItemId × needItemCnt + needMoney 金币   # _consume_forge_cost
成功后   = strength_level → N；strength_value = round(base_attr_value * addRatio / 100)
普通强化 10 级封顶，11 级走百炼（同段那句「请使用百炼升到 11 级」）
```

## 用法
    python 开发工具/导出装备强化表.py

输出：`数据/装备打造.json`
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

项目根 = Path(__file__).resolve().parent.parent
# 服务端已进项目（见 服务端/README.md、§3.89）：只借它自带 catalog，不起服务、不碰 2.2.3。
出 = 项目根 / "数据" / "装备打造.json"


def main() -> None:
    # scratch 写进仓库内的 .scratch（已 gitignore），别落进 2.2.3 参考目录
    os.environ.setdefault("NARUTO_MULTIPLAYER_ROOT", str(项目根 / ".scratch" / "export-scratch"))
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import 服务端目录
    服务端 = 服务端目录.加载()  # noqa: PLC0415 项目内那份 fake_flash_server

    整段 = 服务端.GAME_DATA_CATALOG.get_cultivation_config("EquipSystem")
    if not isinstance(整段, dict) or not 整段:
        raise SystemExit("取不到 EquipSystem 整段，别写空表出去")

    段名 = sorted(整段)
    print("EquipSystem 共 %d 段：%s" % (len(段名), ", ".join(段名)))

    出.parent.mkdir(parents=True, exist_ok=True)
    出.write_text(json.dumps(整段, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    print("已写出 %s（%d 字节）" % (出, 出.stat().st_size))

    # 把要紧的几段打出来给人眼核（别只信文件）
    for 段, 键 in (("strength", "level1"), ("strength", "level10"),
                   ("strength", "level11"), ("stageup", "stage2"), ("crash", None)):
        条 = 整段.get(段)
        if isinstance(条, dict):
            if 键 is None:
                print("  %s = %s" % (段, json.dumps(条, ensure_ascii=False)[:200]))
            elif 键 in 条:
                print("  %s.%s = %s" % (段, 键, json.dumps(条[键], ensure_ascii=False)))


if __name__ == "__main__":
    main()
