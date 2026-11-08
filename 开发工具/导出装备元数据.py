#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 2.2.3 服务端的 GameData 导出**装备元数据表**（客户端工具的公共件）。

## 为什么需要它
装备的 `stage`（阶数）**不在**客户端的 `数据/物品.json` 里 —— 那张表只有
name/description/price/required_level/icon 这些。`stage` 是服务端从 GameData 的
`ZhuangBei` 段解出来的（`get_equipment_definition` → `info.stage`），
原版客户端是从 **下载的 GameData** 里读的。移植版没有那条下载链，
所以在这里导成静态表，用法与 `数据/物品.json` 一样。

## 用法
    python 开发工具/导出装备元数据.py

输出：`数据/物品装备元数据.json`，键是**8 位补零**的物品 id。
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

项目根 = Path(__file__).resolve().parent.parent
出 = 项目根 / "数据" / "物品装备元数据.json"

# 服务端已进项目（见 服务端/README.md、§3.89）。环境要在 import 前指好（它会堵 NARUTO_MULTIPLAYER_ROOT），
# scratch 写进仓库内 .scratch（已 gitignore），不落进 2.2.3。
os.environ.setdefault("NARUTO_MULTIPLAYER_ROOT", str(项目根 / ".scratch" / "export-scratch"))
sys.path.insert(0, str(Path(__file__).resolve().parent))


def main() -> None:
    import 服务端目录
    服务端 = 服务端目录.加载()  # noqa: PLC0415 项目内那份 fake_flash_server

    目录 = 服务端.GAME_DATA_CATALOG
    表: dict[str, dict] = {}
    for 键 in 目录.raw_equipment:
        物品id = int(键)
        定义 = 目录.get_equipment_definition(物品id)
        if 定义 is None:
            continue
        表["%08d" % 物品id] = {
            "stage": int(定义.stage),
            "base_attr_type": int(定义.base_attr_type),
            "base_attr_value": int(定义.base_attr_value),
            "max_endure": int(定义.max_endure),
            "position": int(定义.position),
            "type_name": str(定义.type_name),
            "required_job": int(定义.required_job),
        }
    # 刻印值配置：原版 `StringTool.getCarveValueConfig`（`StringTool.as:295-299`）读的是
    # `EquipSystem.carve.value.<carve_id>`，每项有 `name` 与 `value_max`。
    # tooltip 的「秘印属性」段要用它拼 "名字 + 类型+值%（最大 max%）"。
    刻印 = (目录.get_cultivation_config("EquipSystem") or {}).get("carve", {}).get("value", {})
    # 灵器（十拳剑那一族）的**静态属性**不在 `数据/物品.json` 里（那张表只有 description/
    # price/attributes 这些摘要，`attributes` 其实是 `addAttr` 上限，不是基础属性）。
    # 原版 `LingQiData.initVars` 从 GameData 的 `LingQi.<id>.info` 读 `baseAttr`（"atk:5000;maxhp:50000"）、
    # `addAttr`（附加属性上限）与 `specialAttr`（开光后的三条特殊属性），
    # 走 `MToolTipLingQiTip` 那套版式显示。这里一次性导成静态表。
    # ⚠️ 2026-10-20 用户报「十拳剑没有属性值」= tooltip 里 基本属性 整段空 —— 真因就是客户端
    #    没有这份静态表、wire 上又只带 plus_attributes。
    灵器: dict[str, dict] = {}
    for 键 in 目录.raw_ling_qi:
        物品id = int(键)
        raw = 目录.raw_ling_qi[键]
        decoded = 目录._decode_section(raw) if raw is not None else {}
        info = decoded.get("info") if isinstance(decoded, dict) else None
        if not isinstance(info, dict):
            continue
        基础 = [[int(类型), int(值)] for 类型, 值 in 目录._parse_equipment_attributes(info.get("baseAttr"))]
        附加 = [[int(类型), int(值)] for 类型, 值 in 目录._parse_equipment_attributes(info.get("addAttr"))]
        # specialAttr 是 "名字:值;名字:值" 的字符串，名字不是属性枚举，原样保留名字给客户端配文案。
        特殊 = []
        for 段 in str(info.get("specialAttr") or "").split(";"):
            名, 分隔, 值 = 段.partition(":")
            if 分隔 and 名.strip():
                特殊.append([名.strip().upper(), int(值.strip() or 0)])
        灵器["%08d" % 物品id] = {
            "required_level": int(info.get("reqLevel", 0) or 0),
            "required_job": int(info.get("reqJob", 0) or 0),
            "base_attr": 基础,
            "add_attr": 附加,
            "special_attr": 特殊,
        }
    出.write_text(json.dumps({"物品": 表, "刻印值": 刻印, "灵器": 灵器}, ensure_ascii=False, indent=1, sort_keys=True),
                  encoding="utf-8")
    print("导出 物品 %d 条、刻印值 %d 条、灵器 %d 条 → %s" % (len(表), len(刻印), len(灵器), 出))


if __name__ == "__main__":
    main()
