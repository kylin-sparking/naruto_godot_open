#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 `info.useAll` 补进 `数据/物品.json`（菜单「全部使用」的数据源）。

背景（2026-10-01 背包/道具轮）：原版服务端每件物品的 `definition.use_all`
读的就是 GameData 的 `info.useAll`（`2.2.3/tools/fake_flash_server.py:8429`），
`handle_use_item` 在报文 flags[3]=="true" **且** `definition.use_all` 时整摞吃
（`:50207-50219`）。客户端的 `数据/物品.json` 当年由
`开发工具/导出游戏数据.mjs` 生成，那份**没带这个字段** ——
于是 `物品菜单.取菜单项` 的 `use_all==1` 过滤（照抄原版 `filtrateItemMenu` :520）
永远把「全部使用」抹掉，这条功能整体形同不存在。

源：不自己解 GameData.dat（AMF）—— **借用服务端自己的 catalog**
（import 时它就把 `2.2.3/www/.../GameData.dat` 解好了），
口径永远和服务端一致（"报文语义以服务端读写器为准"的同族做法）。

用法（在 naruto_godot 下）：
    运行时/python/python.exe 开发工具/导出物品use_all.py            # 写入
    运行时/python/python.exe 开发工具/导出物品use_all.py --dry-run  # 只看
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

    hits = 0
    for key, entry in items.items():
        if not str(key).isdigit() or not isinstance(entry, dict):
            continue
        try:
            defn = catalog.get_item_definition(int(key))
        except Exception:
            defn = None
        flag = int(getattr(defn, "use_all", 0) or 0) if defn is not None else 0
        if flag == 1:
            entry["use_all"] = 1
            hits += 1
        else:
            entry.pop("use_all", None)   # 幂等重跑：撤掉不再命中的旧键

    print(f"use_all=1 共 {hits} 件" + ("（--dry-run 未写入）" if dry else ""))
    sample = [k for k, v in items.items() if isinstance(v, dict) and v.get("use_all") == 1][:6]
    print("样例:", sample)
    if not dry:
        with io.open(TABLE, "w", encoding="utf-8", newline="") as fp:
            json.dump(items, fp, ensure_ascii=False, separators=(",", ":"))
        print("已写入", os.path.normpath(TABLE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
