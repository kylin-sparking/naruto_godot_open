#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把「使用效果」列补进 `数据/物品.json`（**离线**道具使用的数据源）。

背景（2026-10-02 消耗品/礼包实装轮）：原版 2.2.3 客户端**永远在线**，
`use_inventory_item` 的全部效果都在服务端 `ItemDefinition`
（`hp_restore`/`mp_restore`/`money_reward`/`coupon_reward`/`use_type`/`contents`，
见 `fake_flash_server.py:50323`），`handle_use_item` 发放后**回包驱动**客户端刷新
（属性 `_send_stats`、点券走字段号 30、礼包内容走 ADD/UPDATE 背包包）。
本重制版的离线模式里，这些列**一个都没有** —— 表现：
  · 点券/金币礼包（category=礼包）离线 `use_inventory_item` 直接 `return false`，点了没动静；
  · 回复药剂离线能回血，**纯粹因为 `离线示例数据` 手写种子带了个 `hp:250`**，
    真道具（服务端表里的拉面）离线用了一口血不回。
和 2026-10-01 的 `use_all` 整列缺失是**同一种病**：导出当年没带的列，功能就整体形同不存在。

源：不自己解 GameData.dat —— **借用服务端自己的 catalog**（`导出物品use_all.py` 同族做法，
import 时它已把 `2.2.3/www/.../GameData.dat` 解好），口径永远与服务端一致。

写入的列（只写非默认值，幂等：不再命中的旧键会撤掉）：
  use_type / hp_restore / mp_restore / money_reward / coupon_reward / contents([[id,数量],…])
⚠️ `use_all` 归 `导出物品use_all.py` 管，这里**不碰**（两个脚本写同一键必然漂）。
⚠️ buff 类（`shuxing`/`shuangbei`/`zhenqi`/`bianshen`）这里只导出 `use_type` 供识别，
   效果离线**不模拟**（见 `游戏会话.use_inventory_item` 的分流注释）——那是服务端结算的
   定时器与属性百分比，硬编一份就是自造。

用法（在 naruto_godot 下）：
    运行时/python/python.exe 开发工具/导出物品使用效果.py            # 写入
    运行时/python/python.exe 开发工具/导出物品使用效果.py --dry-run  # 只看
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

    计数 = {"use_type": 0, "hp": 0, "mp": 0, "money": 0, "coupon": 0, "contents": 0}
    for key, entry in items.items():
        if not str(key).isdigit() or not isinstance(entry, dict):
            continue
        try:
            defn = catalog.get_item_definition(int(key))
        except Exception:
            defn = None
        if defn is None:
            for col in ("use_type", "hp_restore", "mp_restore", "money_reward",
                        "coupon_reward", "contents"):
                entry.pop(col, None)
            continue
        # ⚠️ 不碰 `use_all`（`导出物品use_all.py` 的地盘）。
        if defn.use_type:
            entry["use_type"] = str(defn.use_type)
            计数["use_type"] += 1
        else:
            entry.pop("use_type", None)
        for col, 桶 in (("hp_restore", "hp"), ("mp_restore", "mp"),
                        ("money_reward", "money"), ("coupon_reward", "coupon")):
            值 = int(getattr(defn, col, 0) or 0)
            if 值 > 0:
                entry[col] = 值
                计数[桶] += 1
            else:
                entry.pop(col, None)
        if defn.contents:
            entry["contents"] = [[int(a), int(b)] for a, b in defn.contents]
            计数["contents"] += 1
        else:
            entry.pop("contents", None)

    标 = "（--dry-run 未写入）" if dry else ""
    print("使用效果列写入统计" + 标 + "：", 计数)
    样例 = [k for k, v in items.items()
            if isinstance(v, dict) and v.get("coupon_reward")][:4]
    print("点券礼包样例:", 样例)
    if not dry:
        with io.open(TABLE, "w", encoding="utf-8", newline="") as fp:
            json.dump(items, fp, ensure_ascii=False, separators=(",", ":"))
        print("已写入", os.path.normpath(TABLE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
