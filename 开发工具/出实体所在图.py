#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""烘一张「NPC / 怪 模板号 → 在哪几张图上」的索引，给**跨图自动赶路**用。

为什么要单独烘：原版点任务里的绿名走 `CharacterHandler.MovePlayerToNpc`（`:685-717`），
它拿的是静态 NpcInfo 里的 mapId ⇒ 同图就 `pathFind` 走过去、跨图先 `MovePlayerToMap`。
本工程**没有那份 NpcInfo**（`数据/NPC.json` 只有名字/称号/台词/service，没有图号），
于是"这个 NPC 到底在哪张图"没处问 ⇒ 不在本图就只会弹一扇本地假对话（用户 2026-10-10 报的
"NPC 不在当前地图点击寻路也没反应"）。

真值来源钉死成**运行期同一份**：`数据/地图索引.json`（图号→目录）+ 各图 `地图.json` 的 `life` 段。
`脚本/地图/地图资源.gd:map_data_path()` 用的就是这张索引，所以本索引与"世界上到底站了谁"
天然同源，不会出现"索引说在 A 图、进图却没人"的两张皮。

⚠ 盘上有 11 个目录**不在索引里**（`终结之谷*`、`森林外围`、`112010000`、`尾兽来袭_*`）——
运行期根本不加载它们，所以这里也**不收**，只把它们打进「孤立目录」一栏让人看见。

用法：python 开发工具/出实体所在图.py
"""
import io
import json
import os
import sys

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
索引路 = os.path.join(根, "数据", "地图索引.json")
地图根 = os.path.join(根, "数据", "地图")
出路 = os.path.join(根, "数据", "界面", "实体所在图.json")


def _列(v):
    if isinstance(v, dict):
        return list(v.values())
    if isinstance(v, list):
        return v
    return []


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    索引 = json.load(io.open(索引路, encoding="utf-8"))
    NPC = {}
    怪 = {}
    读失败 = []
    for 图 in sorted(索引):
        目 = str(索引[图])
        p = os.path.join(地图根, 目, "地图.json")
        if not os.path.isfile(p):
            读失败.append("%s→%s（目录里没 地图.json）" % (图, 目))
            continue
        j = json.load(io.open(p, encoding="utf-8"))
        for v in _列(j.get("life", [])):
            if not isinstance(v, dict):
                continue
            号 = str(v.get("id", "")).strip()
            if not 号.lstrip("0"):
                continue
            净 = str(int(号))
            表 = 怪 if str(v.get("type", "n")) == "m" else NPC
            表.setdefault(净, set()).add(图)
    if 读失败:
        print("索引指向的目录读不到，拒绝出表（漏一张 = 那张图上的 NPC 永远跨不过去）：")
        for x in 读失败:
            print("  ", x)
        raise SystemExit(1)
    盘上 = set(x for x in os.listdir(地图根)
               if os.path.isdir(os.path.join(地图根, x)))
    孤立 = sorted(盘上 - set(str(v) for v in 索引.values()))
    出 = {
        "说明": "跨图自动赶路用：NPC / 怪 模板号 -> 出现在哪些图上（图号升序）。",
        "来源": "数据/地图索引.json（图号→目录，与 脚本/地图/地图资源.gd:map_data_path 同一份）"
                " + 各图 地图.json 的 life 段（与运行期生成世界上这些实体的同一份表）。",
        "生成": "开发工具/出实体所在图.py",
        "索引张数": len(索引),
        "孤立目录_运行期不加载": 孤立,
        "npc": {k: sorted(v) for k, v in sorted(NPC.items(), key=lambda x: int(x[0]))},
        "mob": {k: sorted(v) for k, v in sorted(怪.items(), key=lambda x: int(x[0]))},
    }
    os.makedirs(os.path.dirname(出路), exist_ok=True)
    with io.open(出路, "w", encoding="utf-8") as f:
        json.dump(出, f, ensure_ascii=False, indent=1)
        f.flush(); os.fsync(f.fileno())
    print("索引 %d 张 / NPC %d 种 / 怪 %d 种 -> %s（%d 字节）" % (
        len(索引), len(出["npc"]), len(出["mob"]), os.path.relpath(出路, 根),
        os.path.getsize(出路)))
    print("孤立目录（不收，只报）:", 孤立)


if __name__ == "__main__":
    main()
