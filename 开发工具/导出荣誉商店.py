#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 2.2.3 原版 GameData 导出**荣誉商城**（木叶大战积分兑换）的商品表 `MuyeBattle.shop`。

## 为什么需要它
商城那第九个页签「荣誉类」（语言表 `CASHSHOP_RONGYU`）点开的是 `RongYuPanel`，
它的**全部数据源**就是这一张表 —— 原版一处 HTTP 请求都不发：

```
RongYuPanel.setData():91-107
    var o = ImgUtil.getImg(ImgType.MuyeBattle, "shop");   // ← GameData 的 MuyeBattle.shop
    for each (item in o) items.push(item);                // 逐条推进数组，顺序 = GameData 的键序
    setTimeout(delayLoadData, 50, ...)                    // 每 50ms 建一行
```

每条只有两个字段（**原样**）：`itemId` 换什么、`famePoint` 要多少荣誉积分。
商品名与那两行说明**不在这张表里**，是 `StringTool.getItemStringObject(itemId)`
现查 GameData 的 `String` 段（⇒ 端口用 `游戏数据.item_name` / `item_detail`，见 §「为什么不做成一张宽表」）。

## 服务端也读同一段（口径必须一致）
`fake_flash_server.py:6181-6195 muye_battle_shop()`：同样是 `MuyeBattle.shop`，逐条取
`itemId`/`famePoint`，但它**多两道筛选**（`item_id > 0 and fame_point > 0 and 有物品定义`）。
兑换判定在服务端（`:30002-30022 _redeem_muye_battle_reward`：单价×数量、够不够积分、背包满不满），
客户端只把 `itemId` 报上去 ⇒ **本表不做那两道筛选**，照原版把 11 条全导出来。
（本机 11 条实测**全都过**服务端那两道筛，所以两边现在看到的是同一批；不改不代表可以改。）

## 为什么落成一个**有序列表**而不是字典
`RongYuPanel` 的 `for each` 走的是 GameData 里 `"0".."10"` 那个**插入序**，行序 = 键的数值序。
JSON 字典写出去会被 `sort_keys` 按字符串排（`"10"` 跑到 `"2"` 前面）⇒ 页面上的行序和原版不一样。
所以这里显式按 `int(键)` 排好、落成数组，客户端直接按下标建行，不给它第二次排序的机会。

## 为什么不做成一张"宽表"（把名字/说明抄进来）
名字与 `detaildesc` 已经各有一份权威导出（`数据/物品.json`、`数据/物品详情文案.json`），
抄进本表就是同一真值两份 —— 物品改名时这里会**静默**不一致（§0.0 第一原则）。
本表只留 GameData 那段**独有**的两个字段。

## 用法
    python 开发工具/导出荣誉商店.py

输出：`数据/荣誉商店.json`
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

出 = Path(__file__).resolve().parent.parent / "数据" / "荣誉商店.json"

sys.path.insert(0, str(Path(__file__).resolve().parent))

import 原版数据  # noqa: E402


def main() -> None:
    os.environ.setdefault("NARUTO_MULTIPLAYER_ROOT",
                          str(Path(os.environ.get("NARUTO_GAME_ROOT", r"2.2.3"))
                              / ".export_scratch"))

    整段 = 原版数据.取顶层段("MuyeBattle")
    if not isinstance(整段, dict) or not 整段:
        raise SystemExit("取不到 MuyeBattle 整段，别写空表出去")

    # 与 导出活跃度奖励.py 同一条坑：段里的每个值是 **zlib 压缩的 AMF3 字节串**，
    # 不解这一层会得到"shop 是 147 个字节"的假象。
    解好的 = {名: 原版数据.解载荷(值) for 名, 值 in 整段.items()}
    商店 = 解好的.get("shop")
    if not isinstance(商店, dict) or not 商店:
        raise SystemExit("MuyeBattle.shop 解完还是空 —— 别写空表出去")

    键序 = sorted(商店, key=lambda k: int(k) if str(k).isdigit() else 1 << 30)
    条目 = []
    for 键 in 键序:
        条 = 商店[键]
        if not isinstance(条, dict):
            raise SystemExit("shop[%s] 不是对象：%r" % (键, 条))
        # 字段名**原样**（itemId / famePoint），客户端按这两个键读，别在这里改名。
        条目.append({"itemId": int(条["itemId"]), "famePoint": int(条["famePoint"])})

    表 = {
        "_说明": ("2026-10-20 新增（§3.227 荣誉类页签）。真值出处：GameData `MuyeBattle.shop`，"
                  "客户端读法 `RongYuPanel.setData():91-107`（`ImgUtil.getImg(ImgType.MuyeBattle,\"shop\")`，"
                  "**不发任何请求**）；服务端同段读法 `fake_flash_server.py:6181 muye_battle_shop()`，"
                  "兑换判定 `:30002 _redeem_muye_battle_reward`。"
                  "`itemId`/`famePoint` 是 GameData **原样字段名** ⇒ 不改名（理由见 开发工具/导出荣誉商店.py）。"
                  "行序 = GameData 键序 `0..10`，已按数值排好；商品名与 `detaildesc` 不在本表，"
                  "运行期查 `游戏数据.item_name` / `item_detail`（`StringTool.getItemStringObject` 同义）。"),
        "条目": 条目,
    }

    出.parent.mkdir(parents=True, exist_ok=True)
    # 同 导出活跃度奖励.py：必须 `newline="\n"`，否则 Windows 写 CRLF、`.gitattributes` 又规范化成 LF，
    # 每次 `git add` 都报 CRLF 并产生空白 diff。
    # ⚠ 也**不能** `sort_keys=True` —— 那会把 `_说明`/`条目` 之外的东西按字典序排，
    #   而本表的**行序**是语义的一部分（文件头那条）。
    with open(出, "w", encoding="utf-8", newline="\n") as 文件:
        文件.write(json.dumps(表, ensure_ascii=False, indent=1))
    print("已写出 %s（%d 字节，%d 条）" % (出, 出.stat().st_size, len(条目)))
    for 条 in 条目:
        print("  itemId=%d famePoint=%d" % (条["itemId"], 条["famePoint"]))


if __name__ == "__main__":
    main()
