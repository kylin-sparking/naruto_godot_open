#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把宝石提示框要的两段词条补进 `数据/物品.json`。

背景（2026-10-31 用户报修，同一段 AS3 的两支）：
  ① 勾玉详情框只印描述，**不写它加哪个忍术** —— 原版 `MToolTipDefault.createDefaultTip:145`
     对勾玉会多一段：
         `<font color="#8ea8d8">勾玉属性</font><br/><font color="#00ff00">技能名  +N层</font>`
  ② 普通宝石（130 前缀）的「宝石属性」一段同样没搬（同文件 `:147-149` 的 else 分支）：
         抬头 `宝石属性` + `StoneData.getAttributeDesc:89` 的 `属性名　+数值`（白字）。

两支都来自 GameData 的 `BaoShi.<id>.info.equip.inlay` 段：
  勾玉（131）→ `skill` / `level`；普通宝石（130）→ `type` / `value`。
`stoneLevel`/`next` 已由 `导出宝石合成链.py` 搬过，这里不碰。

写入的列（互斥，一支有条目就撤另一支的残留键，幂等）：
  gouyu_skill（忍术号，七位/四位两种）/ gouyu_level（加成层数 —— **不是** stoneLevel，
      两者从 6 级起就分叉了：6 级勾玉 stoneLevel=6、level=7）
  stone_attr_type（`StoneData.ATTR_TYPES` 的键：atk/def/atkspeed/bsk/avd/maxhp）
  stone_attr_value（加成数值）

源：服务端 catalog（`服务端目录.加载()` → `GAME_DATA_CATALOG.raw_item_sections["BaoShi"]`），
口径与服务端 `_equipped_skill_gem_bonus` 读的同一份数据。

用法（在 naruto_godot 下）：
    运行时/python/python.exe 开发工具/导出勾玉技能.py            # 写入
    运行时/python/python.exe 开发工具/导出勾玉技能.py --dry-run  # 只看
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.join(HERE, "..", "数据", "物品.json")
SKILLS = os.path.join(HERE, "..", "数据", "技能文案.json")
勾玉列 = ("gouyu_skill", "gouyu_level")
宝石列 = ("stone_attr_type", "stone_attr_value")


def 技能名(skills: dict, sid: int) -> str:
    for 键 in (str(sid).zfill(7), str(sid)):
        if 键 in skills:
            return str(skills[键].get("name", "?"))
    return "?"


def main() -> int:
    dry = "--dry-run" in sys.argv
    sys.path.insert(0, HERE)
    import 服务端目录
    f = 服务端目录.加载()
    catalog = f.GAME_DATA_CATALOG
    分段 = catalog.raw_item_sections.get("BaoShi", {})

    with io.open(TABLE, encoding="utf-8") as fp:
        items = json.load(fp)
    with io.open(SKILLS, encoding="utf-8") as fp:
        skills = json.load(fp)

    写勾玉 = 0
    写宝石 = 0
    撤 = 0
    for key, entry in items.items():
        if not str(key).isdigit() or not isinstance(entry, dict):
            continue
        raw = 分段.get(str(key).zfill(8))
        decoded = catalog._decode_section(raw) if raw is not None else {}
        inlay = decoded.get("inlay") if isinstance(decoded, dict) else None
        sid = 0
        typ = ""
        if isinstance(inlay, dict):
            try:
                sid = int(inlay.get("skill") or 0)
            except (TypeError, ValueError):
                sid = 0
            typ = str(inlay.get("type") or "")
        if sid:
            try:
                层 = max(0, int(inlay.get("level") or 0))
            except (TypeError, ValueError):
                层 = 0
            entry["gouyu_skill"] = sid
            entry["gouyu_level"] = 层
            写勾玉 += 1
            for col in 宝石列:
                if entry.pop(col, None) is not None:
                    撤 += 1
        elif typ:
            try:
                值 = int(inlay.get("value") or 0)
            except (TypeError, ValueError):
                值 = 0
            entry["stone_attr_type"] = typ
            entry["stone_attr_value"] = 值
            写宝石 += 1
            for col in 勾玉列:
                if entry.pop(col, None) is not None:
                    撤 += 1
        else:
            for col in 勾玉列 + 宝石列:
                if entry.pop(col, None) is not None:
                    撤 += 1

    标 = "（--dry-run 未写入）" if dry else ""
    print(f"宝石词条列写入{标}：勾玉 {写勾玉} 条、普通宝石 {写宝石} 条、撤残留 {撤} 处")
    for probe in ("13100000", "13100805"):
        e = items.get(probe, {})
        sid = e.get("gouyu_skill")
        print(" ", probe, e.get("name", "?"), "→ skill", sid,
              技能名(skills, sid) if sid else "-", "level", e.get("gouyu_level"))
    for probe in ("13000000", "13010000", "13020009", "13050009"):
        e = items.get(probe, {})
        print(" ", probe, e.get("name", "?"), "→", e.get("stone_attr_type"),
              e.get("stone_attr_value"))
    if not dry:
        with io.open(TABLE, "w", encoding="utf-8", newline="") as fp:
            json.dump(items, fp, ensure_ascii=False, separators=(",", ":"))
        print("已写入", os.path.normpath(TABLE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
