#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 2.2.3 服务端的 GameData 导出**礼包整段** `Gift`。

## 为什么需要它
「开心有礼」六个子页里有三页要**配置**才知道怎么画：

* `线上有礼`（原版 `PrizeOnlinePane2`）：三档的**在线小时门槛**与点券数
  —— `ImgUtil.getImg(ImgType.Gift, "monthly")` 的 `hours` / `cashbind`。
  原版就是拿 `本周分钟/60` 去比 `hours` 决定哪几档图标变亮（`PrizeOnlinePane2.as:236-250`）。
* `每日签到`（`PrizeCheckInPanel`）与 `新服有礼` 同理，都按各自的配置表画档位。

这些值**不在客户端代码里**，在 GameData 的 `Gift` 段；反编译的 AS3 只引用它。

## 为什么**原样导出整段**，不做字段改名
同 `导出活跃度奖励.py` 的规矩：字段名照 GameData 原样（`hours` / `cashbind` / …），
客户端直接按服务端自己的字段名读。改一次名就等于把同一份真值抄成两份。

## 权威读法（服务端，客户端必须与它一致）
```
段 = Gift                                       # fake_flash_server.py:5550
monthly  = 解载荷(段["monthly"])                  # 键 "0"/"1"/"2"，每项 {hours, cashbind}
                                                     # monthly_online_rewards():7433
```
⚠️ 段值本身是 **zlib 压缩的 AMF3 字节串**，必须先解一层；里面某些子表还可能再压一层，
   所以这里对每个子值都过一遍 `解载荷()`（与 `导出活跃度奖励.py` 同一个坑）。

## 用法
    python 开发工具/导出礼包配置.py

输出：`数据/礼包.json`
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

GAME_ROOT = Path(os.environ.get("NARUTO_GAME_ROOT", r"2.2.3"))
出 = Path(__file__).resolve().parent.parent / "数据" / "礼包.json"

sys.path.insert(0, str(Path(__file__).resolve().parent))

import 原版数据  # noqa: E402


def main() -> None:
    os.environ.setdefault("NARUTO_MULTIPLAYER_ROOT", str(GAME_ROOT / ".export_scratch"))

    # ⚠️ 段名就是 `Gift`（服务端 `fake_flash_server.py:5550` 用的也是这个）。
    整段 = 原版数据.取顶层段("Gift")
    if not isinstance(整段, dict) or not 整段:
        raise SystemExit("取不到 Gift 整段，别写空表出去")

    # 整段本身解一层；每个子值再解一层（子表可能是二次压缩的字节串）。
    解好的 = {名: 原版数据.解载荷(值) for 名, 值 in 整段.items()}

    monthly = 解好的.get("monthly")
    if not isinstance(monthly, dict) or not monthly:
        raise SystemExit("Gift.monthly 解完还是空 —— 别写空表出去")

    print("Gift：段 %s；monthly 档位 %d 个" % (", ".join(sorted(解好的)), len(monthly)))
    for 号 in sorted(monthly, key=lambda k: int(k) if str(k).isdigit() else 1 << 30):
        条 = monthly[号]
        if isinstance(条, dict):
            print("  档 %s = hours %s / cashbind %s"
                  % (号, 条.get("hours"), 条.get("cashbind")))

    出.parent.mkdir(parents=True, exist_ok=True)
    # ⚠️ 必须显式 `newline="\n"`：`Path.write_text()` 在 Windows 下会把 `\n` 翻译成 `\r\n`，
    #    而这个仓库的 `.gitattributes` 是 `* text=auto eol=lf` —— 生成物一进仓库就被规范化，
    #    工作区却留着 CRLF，之后每次 `git add` 都报 "CRLF will be replaced by LF"。
    #    （同 `导出活跃度奖励.py`，2026-09-25 实际踩到过。）
    with open(出, "w", encoding="utf-8", newline="\n") as 文件:
        文件.write(json.dumps(解好的, ensure_ascii=False, indent=1, sort_keys=True))
    print("已写出 %s（%d 字节）" % (出, 出.stat().st_size))


if __name__ == "__main__":
    main()
