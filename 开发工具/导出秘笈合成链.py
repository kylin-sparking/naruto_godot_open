#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把「秘笈合成」的数据补进客户端（2026-10-03 接 `CAN_JUAN_ACTION 1352` 的门数据源）。

两件事：
1. 给 `数据/物品.json` 补两列（只给 `JiNengCanJuan` 段的条目）：
     canjuan_book —— 产物秘笈的 item id（`JiNengCanJuan.<id>.spec.merge.bookid`）
     canjuan_need —— 合成要几条残卷（`…merge.needCnt`）
   这与服务端 `fake_flash_server.skill_fragment_recipe` 读的是**同一份 catalog**
   （`GAME_DATA_CATALOG.raw_item_sections["JiNengCanJuan"]`，66 条），口径不得分叉。
2. 落 `数据/界面/秘笈合成配置.json`：
     need_zq / prob / help_item ← `Etc.CanJuanHeCheng`（`skill_fragment_composition_config`）
     ratio = 3                   ← 原版 `UIConfig.as:976 xingYunJingRatio`（每枚幸运符 +3 几率）
   ⚠️ **夹具掷骰基率硬编码 30**（`handle_can_juan_action: base_probability = 30`），
   而表里 prob=25 —— 客户端展示按表（原版 `JiNengCompositeWindow:390` 读的也是表），
   差异记入移植文档（在线门只钉"结果 0/1 + 消耗"，不钉几率值）。

用法（在 naruto_godot 下）：
    运行时/python/python.exe 开发工具/导出秘笈合成链.py            # 写入
    运行时/python/python.exe 开发工具/导出秘笈合成链.py --dry-run  # 只看
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.join(HERE, "..", "数据", "物品.json")
CONFIG = os.path.join(HERE, "..", "数据", "界面", "秘笈合成配置.json")


def main() -> int:
    dry = "--dry-run" in sys.argv
    sys.path.insert(0, HERE)
    import 服务端目录
    f = 服务端目录.加载()          # 项目内那份服务端；只建 catalog，不起服务
    catalog = f.GAME_DATA_CATALOG

    with io.open(TABLE, encoding="utf-8") as fp:
        items = json.load(fp)

    merged = 0
    for key, row in items.items():
        raw = catalog.raw_item_sections.get("JiNengCanJuan", {}).get(f"{int(key):08d}")
        book = need = 0
        if raw is not None:
            spec = (catalog._decode_section(raw) or {}).get("spec") or {}
            merge = spec.get("merge") if isinstance(spec, dict) else {}
            if isinstance(merge, dict):
                book = int(merge.get("bookid") or 0)
                need = int(merge.get("needCnt") or 0)
        if book > 0 and need > 0:
            row["canjuan_book"] = book
            row["canjuan_need"] = need
            merged += 1
        else:
            row.pop("canjuan_book", None)
            row.pop("canjuan_need", None)

    zq_cost, prob, help_item = catalog.skill_fragment_composition_config()
    conf = {
        "_说明": "秘笈合成（JiNengCompositeWindow）档位。need_zq/prob/help_item 逐字来自 "
                 "Etc.CanJuanHeCheng（`skill_fragment_composition_config`）；ratio=3 来自 "
                 "UIConfig.as:976 xingYunJingRatio。⚠️ 夹具 handle_can_juan_action 掷骰基率硬编码 30，"
                 "与表 prob=%d 不同源——展示按表、结果按夹具，见移植文档 §3.90.6。" % prob,
        "need_zq": zq_cost,
        "prob": prob,
        "help_item": help_item,
        "ratio": 3,
        "max_helper": 9,
    }
    print("JiNengCanJuan 配方 %d 条 / 物品表命中 %d 条" % (
        len(catalog.raw_item_sections.get("JiNengCanJuan", {})), merged))
    print("配置:", json.dumps(conf, ensure_ascii=False))
    if dry:
        print("--dry-run：不写入")
        return 0
    with io.open(TABLE, "w", encoding="utf-8") as fp:
        json.dump(items, fp, ensure_ascii=False, separators=(",", ":"))
    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    with io.open(CONFIG, "w", encoding="utf-8") as fp:
        json.dump(conf, fp, ensure_ascii=False, indent=1)
    print("已写入 物品.json（两列）与 数据/界面/秘笈合成配置.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
