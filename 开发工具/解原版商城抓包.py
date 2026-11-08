# -*- coding: utf-8 -*-
"""把 `nya_208_cash_catalog.json`（原版 2.0.8 商城目录抓包）解出来看。

结构与 `com/mxw/data/cashshop/CashItemInfo.as:52-70` 的 decode 一致，
打包格式见 `start_nya_208_isolated.py:62` 的 `NYA208_CASH_ROW_STRUCT = struct.Struct("<iii bb ii b ii bbb ii b")`。
"""
import base64
import json
import struct
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

行 = struct.Struct("<iii bb ii b ii bbb ii b")
源 = Path(__file__).with_name("nya_208_cash_catalog.json")
抓包 = json.loads(源.read_text(encoding="utf-8"))

print("分类数：%d（键 %s）" % (len(抓包), sorted(抓包, key=int)))
总 = 0
for 类 in sorted(抓包, key=int):
    体 = base64.b64decode(抓包[类])
    总数, 条数 = struct.unpack_from("<ii", 体)
    print("\n=== 分类 %s：total=%d count=%d  （字节 %d，应为 8+%d*%d=%d）"
          % (类, 总数, 条数, len(体), 条数, 行.size, 8 + 条数 * 行.size))
    总 += 条数
    for i in range(条数):
        起 = 8 + i * 行.size
        v = 行.unpack(体[起:起 + 行.size])
        sn, 原价, 现价, 打折, 限时, 始, 止, 限购, 总限, 已售, 新, 热, 礼金, 物品id, 过期, 礼包 = v
        print("  sn=%-6d 物品=%-9d 原价=%-8d 现价=%-8d%s%s%s%s%s%s%s 过期=%d 礼包=%d"
              % (sn, 物品id, 原价, 现价,
                 " 打折" if 打折 else "", " 限时" if 限时 else "",
                 " 限购%d" % 总限 if 限购 else "", " 已售%d" % 已售 if 已售 else "",
                 " 新品" if 新 else "", " 热卖" if 热 else "", " 礼金" if 礼金 else "",
                 过期, 礼包))
print("\n合计 %d 行" % 总)
