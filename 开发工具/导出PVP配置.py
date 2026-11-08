# -*- coding: utf-8 -*-
"""导出原版 PVP 开关配置 → 数据/PVP配置.json。

为什么需要它
------------
「切了全体模式还是打不了人」这一类问题，判定的每一个数都来自原版 GameData 的
`Pvp/open` 段（**实机那份** `as3_MainLib/…/PVPHandler.as:95-111` 就是读它）：

    minPkLevel      = pkLevel              # 等级不到这个数 ⇒ 不能 PK
    minPanelLevel   = configLevel          # 等级不到这个数 ⇒ 连 PK 模式都不许切
    pkLevelScope    = player2playerLevel   # 双方等级差超过这个数 ⇒ 不能 PK（服务端侧）
    peaceMaps       = [...]                # 安全图：图里禁止 PK（**100000000 木叶村就在里面**）
    unprotectedMaps = [...]                # BOSS 图：无保护无惩罚
    protectTime / defenceTime              # 复活保护 / 自卫时长
    messages        = {...}                # 打不了时说的那几句**原文**

以前这些数在本工程里只有两处：客户端一处（其实压根没读，见 #352）与夹具服务端
一处写死的 `PVP_MIN_LEVEL = 45`。写死的那个 45 恰好与真值相同，但**它是猜的**，
而"等级差 ≤15""安全图禁止 PK""40 级才能切模式"三条整条缺失 ⇒ 只能把它们导成一张表，
客户端与服务端读同一份。

字段名**照原版**（`pkLevel` 不改成 `最低PK等级`）：改名等于把同一份真值抄两份，抄漏就静默错。

用法
----
    python 开发工具/导出PVP配置.py
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 原版数据 import 取顶层段, 解载荷  # noqa: E402

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
产物 = os.path.join(项目根, "数据", "PVP配置.json")

段 = 取顶层段("Pvp")
if "open" not in 段:
    raise SystemExit("GameData 的 Pvp 段里没有 open —— 口径变了，先核原版")
行 = 解载荷(段["open"])
if not isinstance(行, dict):
    raise SystemExit("Pvp/open 解出来不是字典（实得 %s）" % type(行).__name__)


def 整数(键: str) -> int:
    值 = 行.get(键)
    if 值 is None:
        raise SystemExit("Pvp/open 缺 %s —— 别猜，先核原版" % 键)
    return int(值)


def 图列表(键: str) -> list:
    原 = 行.get(键) or {}
    # 原版是 `{"0":100000000,"1":...}` 这种**字符串下标**的字典（`PVPHandler.as:110-127`
    # 用 `for each` 推进数组）⇒ 按数字下标排序后摊平成数组，顺序就是原版 push 的顺序。
    if isinstance(原, dict):
        键集 = sorted(原.keys(), key=lambda k: int(k))
        return [int(原[k]) for k in 键集]
    return [int(v) for v in 原]


文案 = 行.get("messages") or {}
if not isinstance(文案, dict) or "forbidPkInPeace" not in 文案:
    raise SystemExit("Pvp/open.messages 缺 forbidPkInPeace —— 那几句提示没真值可抄了")

结果 = {
    "_说明": ("原版 GameData `Pvp/open` 段（PVPHandler.as:95-111 读的就是它）。"
              "客户端与服务端**都读这一份**，别再各自写死。生成工具：开发工具/导出PVP配置.py；别手改。"),
    "_出处": "as3_MainLib/scripts/com/mxw/game/world/handlers/PVPHandler.as:95-111（读配置）"
    " / :313-381（canAttackPlayer） / :392-453（getNoAttackWarning）",
    "configLevel": 整数("configLevel"),
    "pkLevel": 整数("pkLevel"),
    "player2playerLevel": 整数("player2playerLevel"),
    "protectTime": 整数("protectTime"),
    "defenceTime": 整数("defenceTime"),
    "peaceMaps": 图列表("peaceMaps"),
    "unprotectedMaps": 图列表("unprotectedMaps"),
    "messages": {k: str(v) for k, v in sorted(文案.items())},
}

# 自检：这几条一旦不成立，说明导出的不是那份真值（或者原版换了版本）。
if 100000000 not in 结果["peaceMaps"]:
    raise SystemExit("peaceMaps 里没有 100000000（木叶村）—— 与原版 Pvp/open 不符，先核数据源")
for 键 in ("configLevel", "pkLevel", "player2playerLevel"):
    if 结果[键] <= 0:
        raise SystemExit("%s = %r 不像合法档位" % (键, 结果[键]))
if len(结果["unprotectedMaps"]) != 10:
    raise SystemExit("unprotectedMaps 条数 = %d，原版是 10 张 BOSS 图" % len(结果["unprotectedMaps"]))

文本 = json.dumps(结果, ensure_ascii=False, indent=1, sort_keys=False)
io.open(产物 + ".tmp", "w", encoding="utf-8", newline="\n").write(文本 + "\n")
os.replace(产物 + ".tmp", 产物)
重读 = json.load(io.open(产物, encoding="utf-8"))
if 重读["pkLevel"] != 结果["pkLevel"] or 重读["messages"] != 结果["messages"]:
    raise SystemExit("写完再读回来不一致 —— 编码或键序被动过")
print("Pvp/open 导出完成：%s" % 产物)
print("  pkLevel=%d configLevel=%d player2playerLevel=%d protectTime=%d defenceTime=%d" % (
    结果["pkLevel"], 结果["configLevel"], 结果["player2playerLevel"], 结果["protectTime"], 结果["defenceTime"]))
print("  peaceMaps %d 张（含 100000000 木叶村）/ unprotectedMaps %d 张 / messages %d 句" % (
    len(结果["peaceMaps"]), len(结果["unprotectedMaps"]), len(结果["messages"])))
