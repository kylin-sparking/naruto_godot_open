#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 2.2.3 服务端的 GameData 导出**活跃度（火影活跃度）整段** `HuoYueDu`。

## 为什么需要它
「福利 → 活动奖励 → 在线有礼」页要显示**奖励档位**：第几档要多少活跃分、给什么。
这些值不在客户端代码里，在 GameData 的 `HuoYueDu` 段；反编译的 AS3 只引用它。
服务端 `fake_flash_server.py` 是唯一能拿到它的地方。

⚠️ 客户端在此之前是**硬编码猜的**：`活动窗口.gd` 里写死 `[20, 50, 80, 100]`，
奖励文案是 `(index+1)*100 金币 / (index+1)*50 经验` —— 全是自造的。本表取代它。

## 为什么**原样导出**，不做字段改名
同 `导出装备强化表.py` 的规矩：字段名照 GameData 原样（`reqScore` / `cnt1` / `exp` …），
客户端直接按服务端自己的字段名读。改一次名就等于把同一份真值抄成两份，
服务端改字段名或这里抄漏一个字段，客户端会**静默**错（§0.0 第一原则）。

## 权威读法（服务端，客户端必须与它一致）
```
段 = HuoYueDu                                   # fake_flash_server.py:5445-5450
档位表 = 段["info"]["0".."7"]                    # huoyuedu_rewards():6721-6758，最多 8 档
每档字段（原样）：
    reqScore    该档所需活跃分（总活跃分 0-150，每完成一个每日任务 +10，封顶 150）
    exp         经验系数 —— 实发经验 = exp * 人物等级³ / 100   (:32332)
    dianjuan    点券数
    itemId1/cnt1, itemId2/cnt2   两件物品与数量（0 或负表示没有）
15 个每日任务的槽位定义在 段["taskInfo"]（huoyuedu_tasks():6689-6714），
槽位顺序 = 服务端 `2326:0` 帧里那 15 个次数的顺序。
```

## 用法
    python 开发工具/导出活跃度奖励.py

输出：`数据/活跃度奖励.json`
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

GAME_ROOT = Path(os.environ.get("NARUTO_GAME_ROOT", r"2.2.3"))
出 = Path(__file__).resolve().parent.parent / "数据" / "活跃度奖励.json"

sys.path.insert(0, str(Path(__file__).resolve().parent))

import 原版数据  # noqa: E402


def main() -> None:
    os.environ.setdefault("NARUTO_MULTIPLAYER_ROOT", str(GAME_ROOT / ".export_scratch"))

    # ⚠️ 段名是 `Huoyuedu`（**小写 d**）—— 服务端 `fake_flash_server.py:5445` 用的也是这个。
    #    写成 `HuoYueDu` 会拿到 None，然后"导出一张空表"。
    整段 = 原版数据.取顶层段("Huoyuedu")
    if not isinstance(整段, dict) or not 整段:
        raise SystemExit("取不到 Huoyuedu 整段，别写空表出去")

    # ⚠️ 整段不是"已经是字典"：`info` / `taskInfo` 的值是 **zlib 压缩的 AMF3 字节串**，
    #    必须逐个 `解载荷()` 再解一层（直接读会得到"0 档"的假象，见 原版数据.py 的说明）。
    #    落盘前也必须全解成 JSON 能序列化的东西 —— bytes 是写不进 JSON 的。
    解好的 = {名: 原版数据.解载荷(值) for 名, 值 in 整段.items()}

    info = 解好的.get("info")
    if not isinstance(info, dict) or not info:
        raise SystemExit("Huoyuedu.info 解完还是空 —— 别写空表出去")

    档位 = sorted(info, key=lambda k: int(k) if str(k).isdigit() else 1 << 30)
    print("Huoyuedu：档位 %d 个（%s），另有段 %s"
          % (len(档位), ", ".join(档位), ", ".join(sorted(解好的))))

    出.parent.mkdir(parents=True, exist_ok=True)
    # ⚠️ 必须显式 `newline="\n"`：`Path.write_text()` 在 Windows 下会把 `\n` 翻译成 `\r\n`，
    #    而这个仓库的 `.gitattributes` 是 `* text=auto eol=lf` —— 生成物一进仓库就被规范化，
    #    工作区却留着 CRLF，之后每次 `git add` 都报 "CRLF will be replaced by LF"，
    #    并且产生无意义的空白 diff。2026-09-25 实际踩到过。
    with open(出, "w", encoding="utf-8", newline="\n") as 文件:
        文件.write(json.dumps(解好的, ensure_ascii=False, indent=1, sort_keys=True))
    print("已写出 %s（%d 字节）" % (出, 出.stat().st_size))

    # 把要紧的几档打出来给人眼核（别只信文件）
    for 键 in 档位[:8]:
        条 = info[键]
        if isinstance(条, dict):
            要 = {k: 条.get(k) for k in ("reqScore", "exp", "dianjuan",
                                         "itemId1", "cnt1", "itemId2", "cnt2")
                  if k in 条}
            print("  档 %s = %s" % (键, json.dumps(要, ensure_ascii=False)))

    任务 = 整段.get("taskInfo")
    if isinstance(任务, dict):
        print("  taskInfo 槽位 %d 个" % len(任务))


if __name__ == "__main__":
    main()
