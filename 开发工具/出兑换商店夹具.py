# -*- coding: utf-8 -*-
"""导出「兑换商店」(ExchangeShopWindow) 的**离线夹具**，并钉住数据源版本。

为什么要夹具：这一窗的行**全部来自服务端帧** ——
`1820 EXCHANGE_ACTION` cmd 0 → `ExchangeProcessor.handleAction_listAll` → `Client.as:8939`
→ `ExchangeShopWindow.setData(list)`；**2026-10-05 起 cmd 0 这一条已接**（只读取列表），
所以连着服务端打开就是真数据；**没连服务端时**它就是"原版没收到回帧时的那个空态"。
量具与门要验格子渲染，必须自己喂一份**与真机同构**的行 ⇒ 从 2.2.3优化版 服务端的
捕获目录 `tools/nya_208_runtime_catalogs.json` 的 `exchange` 段原样取前 N 行
（字段名就是 `_send_exchange_recipe_list` 打包前的那份 recipe 字典）。

⚠ 口径同 `出木叶村NPC表.py`：**必须显式钉 2.2.3优化版**并记 md5，取到别的版本就拒绝落地。
"""
import hashlib
import io
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
服务端根 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(工程, "..", "2.2.3")
目录路径 = os.path.join(服务端根, "tools", "nya_208_runtime_catalogs.json")
服务脚本 = os.path.join(服务端根, "tools", "fake_flash_server.py")
出 = os.path.join(工程, "数据", "界面", "兑换商店_夹具.json")
取几行 = 12


def md5(路):
    return hashlib.md5(io.open(路, "rb").read()).hexdigest()[:12]


def 自检服务端():
    """目录 JSON 不含版本字样 ⇒ 拿服务脚本里的两处硬特征证明这份就是 2.2.3优化版。"""
    文 = io.open(服务脚本, encoding="utf-8", errors="replace").read()
    特 = ["EXCHANGE_ACTION = 1820", "def _iruka_exchange_recipes", "nya_208_runtime_catalogs.json"]
    缺 = [t for t in 特 if t not in 文]
    if 缺:
        raise SystemExit("服务端脚本不像 2.2.3优化版（缺特征 %s）⇒ 别拿这份导夹具：%s" % (缺, 服务脚本))
    if "2.2.3" not in 服务端根.replace("\\", "/"):
        raise SystemExit("服务端根路径里没有 2.2.3 ⇒ 数据源没钉住：%s" % 服务端根)


def 主():
    自检服务端()
    目 = json.load(io.open(目录路径, encoding="utf-8"))
    行 = 目.get("exchange", [])
    if not isinstance(行, list) or not 行:
        raise SystemExit("exchange 段是空的 ⇒ 目录坏了：%s" % 目录路径)
    选 = []
    for r in 行[:取几行]:
        选.append({
            "sn": int(r["sn"]),
            "isTimeLimited": bool(r.get("limited", False)),
            "restTime": int(r.get("rest_time", 0)),
            "totalCountLimit": int(r.get("total_limit", 0)),
            "singleCountLimit": int(r.get("single_limit", 0)),
            "exchangeCount": int(r.get("exchange_count", 0)),
            "singleExchanged": int(r.get("single_exchanged", 0)),
            "targetItemid": int(r["target_id"]),
            "targetQuantity": int(r["target_quantity"]),
            "targetBind": bool(r["target_bind"]),
            "needItems": [{"itemid": int(a), "count": int(b)} for a, b in r.get("needs", [])],
        })
    包 = {
        "_说明": ("「兑换商店」离线夹具。字段名 = 客户端 `ExchangeItem.decode` 的字段"
                  "（`exchangeShop/ExchangeItem.as:47-74`，顺序 sn / isTimeLimited(readByte==1) / restTime /"
                  " totalCountLimit / singleCountLimit / exchangeCount / singleExchanged / targetItemid /"
                  " targetQuantity / targetBind / needJinBi / needLiJin / needYuanBao / needItems[{itemid,count}]）。"
                  "⚠ `needJinBi/needLiJin/needYuanBao` 三个字段**格子里根本没用**（全树只 decode 不读）⇒"
                  " 这里不落，别去渲染三行不存在的价格。"
                  "值 = 2.2.3优化版 服务端捕获目录 exchange 段的前 12 行原样，"
                  "**不是在线真值**：在线时服务端还会把 `exchange_counts` 本地进度加进"
                  " exchangeCount/singleExchanged（`fake_flash_server.py:26468-26474`）。"),
        "_源": {"服务端根": 服务端根, "目录": 目录路径, "目录md5": md5(目录路径),
                "服务脚本md5": md5(服务脚本), "总行数": len(行), "取了几行": len(选)},
        "行": 选,
    }
    io.open(出, "w", encoding="utf-8", newline="\n").write(json.dumps(包, ensure_ascii=False, indent=1) + "\n")
    print("夹具 %d 行（源共 %d 行）⇒ %s" % (len(选), len(行), 出))
    print("  目录md5=%s 服务脚本md5=%s" % (包["_源"]["目录md5"], 包["_源"]["服务脚本md5"]))
    for r in 选[:3]:
        print("  sn=%s 目标=%s×%s 材料=%s 限次=%s 已兑=%s" % (
            r["sn"], r["targetItemid"], r["targetQuantity"],
            [(x["itemid"], x["count"]) for x in r["needItems"]],
            r["singleCountLimit"], r["exchangeCount"]))


if __name__ == "__main__":
    主()
