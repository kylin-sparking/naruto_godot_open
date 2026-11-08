# -*- coding: utf-8 -*-
"""导「副本传送 / 精英副本」两扇窗的配置 → `数据/副本.json`。

为什么单独一个文件、不复用 `数据/原版杂项.json`
------------------------------------------------
`原版杂项.json` 里**确实有** `FuBen` / `Hero` 两段，但它是**旧快照**，2026-10-03 实测与
本机在跑的 V2.6 `GameData.dat` 对不上：

| 差异 | 旧快照 | 活数据（V2.6） | 后果 |
|---|---|---|---|
| 条数 | 10 条（0~9） | **11 条**（多一条 `10 刷连斩 15 混合`） | 列表少一行；用户实机截图第 9 行露出的就是它 |
| `血之羁绊.teamType` | `"2"`（→ 组队） | **`"1"`**（→ 单人） | 组队列与实机不符 |

⇒ 本页只读这份新导出的、按 `原版数据.数据源`（= 服务端真正发的那份 GameData）现取。
`原版杂项.json` 原样不动（邻居页在读它的 `NpcLocation` / `BossWang`）。

三条口径抄原版，别"顺手改好"
----------------------------
1. **取列表 = `StringTool.getAllFuBenObj()`（`StringTool.as:436-450`）**：从 id `0` 往上数、
   **遇到第一个缺号就 break**（不是"跳过缺号"）。
2. **过滤 = `CopyWindow.filterData()`（`:424-451`）**：只删 `hasOwnProperty("show") && show == 0`
   的条 —— `show` 缺字段要**留着**（原版就是这么写的）。
3. **精英页签 = `StringTool.getEliteCopyData()`（`:585-594`）**：`for each` 全取，**不过滤 show**；
   `maps` 是 `{copyId: {mapid, boss}}` 字典，原版 `mapsArray` 再 `sortOn("copyId")` 升序。

用法：python 开发工具/导出副本配置.py
"""
import io
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据  # noqa: E402

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
落 = os.path.join(工程, "数据", "副本.json")

## **数据源钉死在 `2.2.3优化版\HYSJ`**（用户 2026-10-03：副本名字与对应奖励要与该版本一致）。
## `原版数据.数据源` 的候选表把 V2.6 排在第一 ⇒ 不干预就会静默读到 V2.6 那份，而两份
## `Etc.FuBen` 实测不一样：V2.6 多一条「刷连斩」、血之羁绊 teamType 是 1（2.2.3 是 2 组队）、
## 奖励数量整体被放大过（第1演习场 2.2.3 = 16000012/16000032/16000057 各 ×1，
## V2.6 = 16000032×100 + 15028002×100）。换版本只改下面这一行，别手改 `数据/副本.json`。
源根 = os.environ.get("NARUTO_FUBEN_ROOT",
                      r"2.2.3")


def 段():
    dat = os.path.join(源根, "www", "act_web_nya_208_isolated", "dat", "GameData.dat")
    if not os.path.isfile(dat):
        raise SystemExit("找不到 GameData.dat：" + dat)
    # 覆盖 `原版数据` 的那三个模块级路径常量：它的候选表把 V2.6 排在 2.2.3 前面，
    # 只设环境变量的话导入时机已经过了 ⇒ 必须显式改，否则"钉了源根"是假的。
    原版数据.原版根 = 源根
    原版数据.dat目录 = os.path.dirname(dat)
    原版数据.数据源 = dat
    整 = 原版数据.取顶层段("Etc")
    return {名: 原版数据.解载荷(值) for 名, 值 in 整.items()}


def 副本列表(原):
    """`getAllFuBenObj` + `filterData`：id 从 0 连号、遇缺号停，再删 show==0。

    ⚠ `FuBen` 段每条**没有 `id` 字段**（只有 `FuBen_Hide` 有）—— 原版靠"数组下标 = copyId"
    取数（`getFuBenObj(param1)` 直接用 param1 当键）。这里把下标显式写进 `id`，
    省掉运行期再靠位置反推一次。
    """
    出 = []
    for i in range(10000):
        条 = 原.get(str(i))
        if 条 is None:
            break
        出.append((i, 条))
    留 = [(i, 条) for i, 条 in 出 if not (条.get("show") is not None and int(条["show"]) == 0)]
    return 留, len(出)


def 整形副本(编号, 条):
    奖 = []
    # ⚠ `prize` 的键**不一定从 "0" 起**（实测 V2.6 的 第1演习场 只有 "1"/"2"）⇒ 按整数升序取
    for k in sorted(条.get("prize", {}), key=lambda x: int(x)):
        奖.append({"itemid": int(条["prize"][k]["itemid"]),
                   "quantity": int(条["prize"][k]["quantity"])})
    进 = 条.get("enter", {})
    return {
        "id": 编号,
        "name": 条["name"],
        "reqLevel": int(条["reqLevel"]),
        "teamType": str(条["teamType"]),
        "stars": float(条.get("stars", 0)),
        "desc": 条.get("desc", ""),
        "prize": 奖,
        "enter": {"free": int(进.get("free", 0) or 0),
                  "freeVip": int(进.get("freeVip", 0) or 0),
                  "needItemId": int(进.get("needItemId", 0) or 0),
                  "through": int(进.get("through", 0) or 0)},
        "show": int(条["show"]) if 条.get("show") is not None else None,
    }


def 整形精英(编号, 条):
    图 = []
    for 编 in sorted(条.get("maps", {}), key=lambda x: int(x)):
        图.append({"copyId": int(编),
                   "mapid": int(条["maps"][编]["mapid"]),
                   "bossId": int(条["maps"][编]["boss"])})
    return {"tabId": 编号, "tabName": 条["tabName"], "name": 条["name"],
            "reqLevel": int(条["reqLevel"]), "maps": 图}


def 主():
    E = 段()
    全, 连号 = 副本列表(E["FuBen"])
    体 = {
        "_说明": "由 `开发工具/导出副本配置.py` 从 `原版数据.数据源` 现取，别手改。"
                 "取列表/过滤/排序三条口径的出处见脚本头。",
        "_源": 原版数据.数据源,
        "_连号条数": 连号,
        "副本": [整形副本(编号, 条) for 编号, 条 in 全],
        "精英": [整形精英(i, 条) for i, 条 in enumerate(E["Hero"].values())],
    }
    io.open(落, "w", encoding="utf-8", newline="\n").write(
        json.dumps(体, ensure_ascii=False, indent=1))
    print("出 %s：%d 条副本（连号 %d 条、滤掉 show=0 的 %d 条）、%d 个精英页签"
          % (os.path.relpath(落, 工程), len(全), 连号, 连号 - len(全), len(体["精英"])))
    for 条 in 体["副本"]:
        print("  副本 %-8s lv%-3s %-3s 星%-4s 密卷%s 奖%d" % (
            条["name"], 条["reqLevel"], 条["teamType"], 条["stars"],
            条["enter"]["needItemId"], len(条["prize"])))
    for 条 in 体["精英"]:
        print("  精英 %-10s %-12s lv%-3s %d 章" % (条["tabName"], 条["name"], 条["reqLevel"],
                                                len(条["maps"])))
    # 自检钉的是 **2.2.3 这一版**的形状：10 条连号、滤掉两条 show=0 之后 8 行；
    # 血之羁绊 teamType = "2"（组队）、迷路森林 = "1"（单人）—— V2.6 那份血之羁绊是 "1"，
    # 串了就说明数据源漂回 V2.6 了。奖励三条 ×1 同理。
    名序 = [条["name"] for 条 in 体["副本"]]
    if 名序 != ["第1演习场", "命运之抉择", "秽土转生", "挑战第七班", "挑战尾兽",
                    "血之羁绊", "迷路森林", "修炼场"]:
        raise SystemExit("副本列表与 2.2.3 版不符（数据源或过滤口径变了）：%s" % 名序)
    if 体["副本"][5]["teamType"] != "2" or 体["副本"][6]["teamType"] != "1":
        raise SystemExit("血之羁绊/迷路森林 的 teamType 不是 2.2.3 那版（2 组队 / 1 单人）")
    首奖 = 体["副本"][0]["prize"]
    if [(p["itemid"], p["quantity"]) for p in 首奖] != [(16000012, 1), (16000032, 1),
                                                        (16000057, 1)]:
        raise SystemExit("第1演习场 的通关奖励不是 2.2.3 那版三条 ×1：%s" % 首奖)
    print("自检 √ 8 行名称 / teamType / 第1演习场奖励三条 都与 2.2.3 版一致（源 = %s）" % 源根)


if __name__ == "__main__":
    主()
