# -*- coding: utf-8 -*-
"""把「八门穴位点序」从**服务端真值**导进 `数据/经脉.json`（幂等，改完重跑即可）。

这张表 = **配置键序**（`pts` 的 "0".."N"），下标即发给服务端的 `point_id`。

⚠️ 2026-10-17 更正（用户实机）：`pointId` **就是配置键号**，不是别的什么序 ——
  原版 `JingMaiSource.getMaiPointSource` 里是 `for each(_loc7_ in pts) { _loc8_.pointId = _loc6_++; }`，
  而 AS3 对象的**数值键是按升序枚举**的 ⇒ 第 0 枚就是 `pts["0"]`（开门＝**头维**）。
  **旧版**这张表读的是服务端 `MAI_POINT_ORDER_BY_COUNT` —— 那是当年按 **Ruffle 的动态属性哈希序**
  实测出来的（开门第 0 位是"攒竹"），**与用户实机不符** ⇒ 那张表已在服务端**停用**
  （`_mai_client_ordered_points` 走它的兜底 `sorted(points)` ＝按键升序），本脚本同步改成**数值键序**。

做法：按 `数据/经脉.json` 各门 `pts` 的**数值键**算出每门的点序（穴名数组），
写回 `_客户端点序`（键 = 门名，值 = 穴名数组，下标即 point_id）。

⚠️ 键名带 `_` 前缀 = 派生/说明用，和 `数据/经脉.json` 里其它 `_说明` 一个待遇。
⚠️ 服务端那张表若变了，本脚本要重跑（表本身是"原版对象序"的实测结果，我们不改它）。
用法：python 开发工具/导出八门点序.py
"""
import io
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
服务端 = os.path.join(工程, "服务端", "runtime", "tools", "fake_flash_server.py")
经脉 = os.path.join(工程, "数据", "经脉.json")

# ⚠️ 不再读服务端那张表（已停用，见文件头）—— 点序 = `pts` 的数值键序。
数据 = json.load(io.open(经脉, encoding="utf-8"))
点序 = {}
for 列表键 in ["0", "1", "2", "3", "4"]:
    for 门键, 门 in (数据.get(列表键, {}).get("mai", {}) or {}).items():
        点 = 门.get("pts", {})
        次序 = sorted(int(k) for k in 点)   # 配置键序 = 原版 `for each` 的枚举序（数值键升序）
        点序[门.get("name", "门%s" % 门键)] = [点[str(k)].get("name", str(k)) for k in 次序]

数据["_客户端点序"] = 点序
数据["_客户端点序_出处"] = (
    "配置键序（`pts` 的 0..N）＝原版 `for each` 对数值键的升序枚举；"
    "由 开发工具/导出八门点序.py 生成 —— 下标 = 发给服务端的 point_id"
)
io.open(经脉, "w", encoding="utf-8", newline="\n").write(
    json.dumps(数据, ensure_ascii=False, indent=1, sort_keys=False))
print("已写 %s：%d 门点序（%s）" % (
    os.path.basename(经脉), len(点序),
    ", ".join("%s=%d" % (k, len(v)) for k, v in list(点序.items())[:8])))
