#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把「宝石合成链」两列补进 `数据/物品.json`（宝石工艺窗「宝石合成」页的数据源）。

背景（2026-10-03 宝石合成窗轮）：原版 2.2.3 客户端**永远在线**，宝石的
`stoneLevel` / `next` 存在 GameData 的 `BaoShi.<id>.info.equip.inlay` 里，
服务端 `fake_flash_server.py:54226 _merge_equipment_stone` 就是拿这两段做判定与产物：
  · `inlay.next` 为 0 → 原话「该宝石已达到最高等级。」；
  · 产物 = `next` 那颗（三合一，按 `EquipSystem.merge.level{目标级}.prob` 掷骰）；
  · 原版客户端 `StoneCompositeWindow.validateItem:191` 也在**本地**读 `nextId==0`
    弹「该宝石已经是最高等级！」，并在 `合成宝石格` **预览产物图标**
    （`ItemFactory.createSingleItem(_itemData.nextId)`）。
而我们的客户端表里这些列**一个都没有**（和 2026-10-01 的 `use_all`、
2026-10-02 的「使用效果」整列缺失是同一种病）：没有 `next`，满级闸、
产物预览、消耗/几率的档位全都没依据 —— 只能编，一编就和服务端对不上。

源：不自己解 GameData.dat —— **借用服务端自己的 catalog**
（`导出物品使用效果.py`/`导出物品use_all.py` 同族做法），
解的是 `GAME_DATA_CATALOG.raw_item_sections["BaoShi"]` 的 `inlay` 段，
口径与服务端 `_merge_equipment_stone` 读的**同一份数据**。

写入的列（只写 BaoShi 类的条目；`stone_next`=0 表示已满级、**照写**，
因为"满级"和"不是宝石"要靠这一列区分）：
  stone_level（inlay.stoneLevel，缺省按服务端同口径取 1）
  stone_next（inlay.next，缺省 0）
⚠️ 不碰别的列；幂等：非 BaoShi 条目若残留旧键会撤掉。

用法（在 naruto_godot 下）：
    运行时/python/python.exe 开发工具/导出宝石合成链.py            # 写入
    运行时/python/python.exe 开发工具/导出宝石合成链.py --dry-run  # 只看
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.join(HERE, "..", "数据", "物品.json")
# 服务端已进项目：寻径见 开发工具/服务端目录.py，来源见 服务端/README.md（§3.89）


def main() -> int:
    dry = "--dry-run" in sys.argv
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import 服务端目录
    f = 服务端目录.加载()  # 项目内那份服务端；只建 catalog，不起服务
    catalog = f.GAME_DATA_CATALOG

    with io.open(TABLE, encoding="utf-8") as fp:
        items = json.load(fp)

    写 = 0
    撤 = 0
    for key, entry in items.items():
        if not str(key).isdigit() or not isinstance(entry, dict):
            continue
        号 = int(key)
        raw = catalog.raw_item_sections.get("BaoShi", {}).get(f"{号:08d}")
        decoded = catalog._decode_section(raw) if raw is not None else {}
        inlay = decoded.get("inlay") if isinstance(decoded, dict) else None
        if not isinstance(inlay, dict):
            for col in ("stone_level", "stone_next"):
                if entry.pop(col, None) is not None:
                    撤 += 1
            continue
        # 与服务端 `_merge_equipment_stone:54066-54075` 同一取值口径：
        # stoneLevel 缺省取 1（`max(1, int(...))`），next 缺省 0（满级）。
        try:
            级 = max(1, int(inlay.get("stoneLevel") or 1))
        except (TypeError, ValueError):
            级 = 1
        try:
            下 = int(inlay.get("next") or 0)
        except (TypeError, ValueError):
            下 = 0
        entry["stone_level"] = 级
        entry["stone_next"] = 下
        写 += 1

    标 = "（--dry-run 未写入）" if dry else ""
    print(f"宝石合成链列写入{标}：写 {写} 条、撤残留 {撤} 处")
    for probe in ("13000000", "13000009", "13010000", "13100001"):
        e = items.get(probe, {})
        print(" ", probe, e.get("name", "?"), "→ level", e.get("stone_level"), "next", e.get("stone_next"))
    if not dry:
        with io.open(TABLE, "w", encoding="utf-8", newline="") as fp:
            json.dump(items, fp, ensure_ascii=False, separators=(",", ":"))
        print("已写入", os.path.normpath(TABLE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
