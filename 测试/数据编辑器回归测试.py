# -*- coding: utf-8 -*-
"""数据编辑器回归门（2026-11-05）——进程内锤。

编辑器（`开发工具/数据编辑器/服务.py`）是运营改数值的唯一入口：它只往
`服务端/runtime/www/editor_workspace/project.json` 的 `overrides` 里写**最小补丁**，
服务端 `editor_runtime_config.RuntimeConfig` 按 revision 热加载。这条链路一旦断，
运营界面上看着「保存成功」，线上却仍是旧值 —— 所以本门钉三件事：

  ① 表注册与基础值：九张表的记录/字段读得出来，物品名/描述从文案表补齐；
  ② 保存语义：最小补丁（不夹带基础值）、revision +1、备份、冲突 409、
     禁止删基础字段、NPC 派生键不回写、还原基础值、备份回滚；
  ③ 消费端真的生效：商城价/下架、NPC 倍率、物品改名、掉落池与怪物绑定、全局掉率。

⚠️ 全程在临时目录里跑：把编辑器的 WORKSPACE / PROJECT_JSON / BACKUP_DIR 和服务端的
`EDITOR_RUNTIME` 都指向 `tempfile`，结束时再按字节核对**真** project.json 没被动过。

用法（被 `测试/数据编辑器回归测试.gd` 调，也可手跑）：
    python 测试/数据编辑器回归测试.py
退出码：0 = 全绿；1 = 有断言不符。
"""
from __future__ import annotations

import copy
import importlib.util
import json
import os
import re
import shutil
import sys
import tempfile
import traceback
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
REAL_PROJECT = REPO / "服务端" / "runtime" / "www" / "editor_workspace" / "project.json"
REAL_BYTES = REAL_PROJECT.read_bytes() if REAL_PROJECT.is_file() else b""

TMP = Path(tempfile.mkdtemp(prefix="editor-gate-"))
os.environ["NARUTO_GM_STATE_PATH"] = str(TMP / "gm-state.json")

spec = importlib.util.spec_from_file_location(
    "naruto_editor_service", REPO / "开发工具" / "数据编辑器" / "服务.py"
)
svc = importlib.util.module_from_spec(spec)
sys.modules["naruto_editor_service"] = svc
spec.loader.exec_module(svc)
game = svc.game

svc.WORKSPACE = TMP
svc.PROJECT_JSON = TMP / "project.json"
svc.BACKUP_DIR = TMP / "backups"
svc.PROJECT_JSON.write_text(
    json.dumps({"revision": 1, "overrides": {}}, ensure_ascii=False, indent=1) + "\n",
    encoding="utf-8",
    newline="\n",
)
# 服务端热加载缓存也钉到同一个临时文件：消费端断言才看得到本门写入的覆盖。
game.EDITOR_PROJECT_PATH = svc.PROJECT_JSON
game.EDITOR_RUNTIME = game.RuntimeConfig(svc.PROJECT_JSON)

失败: list[str] = []
断言数 = 0


def 查(条件: bool, 说明: str) -> None:
    global 断言数
    断言数 += 1
    if not 条件:
        失败.append(说明)


def 读盘() -> dict:
    return json.loads(svc.PROJECT_JSON.read_text(encoding="utf-8"))


def 覆盖(entity: str, rid: str) -> dict:
    return 读盘()["overrides"].get(entity, {}).get(rid, {})


EXPECTED_TABLES = [
    "items", "equipment", "quests", "gift_packs", "drops_global",
    "cash_shop", "npc_shops", "drop_pools", "drop_pool_binds",
]
EXPECTED_ENTITIES = {
    "items": "items", "equipment": "equipment", "quests": "quests",
    "gift_packs": "gift_packs", "drops_global": "balance_rules",
    "cash_shop": "cash_shop", "npc_shops": "npc_shops",
    "drop_pools": "drop_pools", "drop_pool_binds": "drop_pool_binds",
}


def 主流程() -> None:
    # ── ① 表注册 ────────────────────────────────────────────────────────────
    查(list(svc.TABLES) == EXPECTED_TABLES, "九张表的 id 与顺序应保持注册表原样")
    查({t: svc.TABLES[t]["entity"] for t in svc.TABLES} == EXPECTED_ENTITIES, "每张表应映射到约定的 override 实体")
    查({t for t in svc.TABLES if svc.TABLES[t]["creatable"]} == {"drop_pools", "drop_pool_binds"},
       "只有掉落池与怪物绑定允许新建记录")

    首记录 = {
        "items": "1010011", "equipment": "1010011", "quests": "1003",
        "gift_packs": "11000001", "drops_global": "monster_drops",
        "cash_shop": "100", "npc_shops": "3",
    }
    for tid, rid in 首记录.items():
        payload = svc._record_payload(tid, rid)
        查(bool(payload["fields"]) and payload["projectRevision"] == 1 and isinstance(payload["merged"], dict)
           and (tid in {"drops_global"} or bool(payload["merged"])),
           f"{tid}:{rid} 应返回字段表、基础值与 revision 1")
    查(svc._record_payload("drops_global", "999")["id"] == "monster_drops", "全局掉落表应折回固定 id monster_drops")

    item = svc._item_base(1010011)
    查(item.get("name") == "竹制忍杖", "物品 1010011 的名称应从文案表补进基础值（竹制忍杖）")
    查(item.get("description") == "可镶嵌【红色宝石】", "物品 1010011 的描述应从文案表补进基础值")
    查(svc._gift_base(11000001).get("name") == "5级成长礼包", "礼包 11000001 的名称应从文案表补进基础值")
    初始 = svc._list_records("items", "", 0, 5)
    查(初始["overridden"] == [] and all(row["overridden"] is False for row in 初始["records"]),
       "未写覆盖时列表不应标 overridden")

    # 另一个编辑器进程刚写了覆盖：本进程的索引缓存还是旧的（缓存无 mtime），
    # 列表仍需按合并视图显示覆盖后的名字。
    原文 = svc.PROJECT_JSON.read_bytes()
    外部 = 读盘()
    外部["revision"] += 1
    外部["overrides"]["items"] = {"1010011": {"name": "外部改名"}}
    svc.PROJECT_JSON.write_text(json.dumps(外部, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    查(svc._list_records("items", "1010011", 0, 5)["records"][0]["name"] == "外部改名",
       "索引缓存过期时列表仍应显示覆盖后的名字")
    svc.PROJECT_JSON.write_bytes(原文)
    svc._INDEX_CACHE.pop("items", None)

    # ── ② 保存语义：最小补丁 / 备份 / 冲突 ──────────────────────────────────
    base = svc._base_record(svc.TABLES["items"], "1010011")
    draft = copy.deepcopy(base)
    draft["name"] = "竹制忍杖·测"
    旧修订 = 读盘()["revision"]
    r = svc._save_record("items", "1010011", draft, {})
    查(r["patch"] == {"name": "竹制忍杖·测"}, "只改名称时补丁必须只有 name（不能夹带 info 等基础值）")
    查(r["revision"] == 旧修订 + 1 and r["hasOverride"] is True, "保存应把 revision +1 并标记有覆盖")
    查(bool(re.match(r"^project-r1-\d{8}-\d{6}\.json$", r["backup"])), "保存前应生成 project-r<旧revision>-<时间>.json 备份")
    查(读盘()["overrides"] == {"items": {"1010011": {"name": "竹制忍杖·测"}}}, "磁盘上的 overrides 应与补丁一致")

    rows = svc._list_records("items", "1010011", 0, 5)
    查(rows["overridden"] == ["1010011"] and rows["records"][0]["overridden"] is True
       and rows["records"][0]["name"] == "竹制忍杖·测", "列表应标出覆盖并显示合并后的名称")
    查(game.GAME_DATA_CATALOG.get_item_definition(1010011).name == "竹制忍杖·测",
       "服务端 get_item_definition 应读到改名覆盖（线上生效）")

    旧修订 = 读盘()["revision"]
    r = svc._save_record("items", "1010011", copy.deepcopy(base), {"name": "竹制忍杖·测"})
    查(r["patch"] == {} and r["hasOverride"] is False and r["revision"] == 旧修订 + 1, "存回基础值应清掉覆盖且不写空补丁")
    查("items" not in 读盘()["overrides"], "清掉最后一条覆盖后应删除空实体")

    冲突 = False
    try:
        svc._save_record("items", "1010011", copy.deepcopy(base), {"name": "别人刚改的"})
    except svc._Conflict:
        冲突 = True
    except Exception:
        冲突 = False
    查(冲突, "expectedOverride 与当前覆盖不一致时应报冲突（HTTP 409），不能覆盖别人的修改")

    删字段拒 = False
    try:
        bad = copy.deepcopy(base)
        bad.pop("name")
        svc._save_record("items", "1010011", bad, {})
    except ValueError as error:
        删字段拒 = "不支持删除基础字段" in str(error)
    查(删字段拒, "删除基础字段应被拒绝并给出明确原因")

    # 商城：字段白名单 / 整数 / 下架 / 改价 / 编码序
    cash = svc._record_payload("cash_shop", "100")
    draft = copy.deepcopy(cash["merged"])
    draft["now_price"] = 1111
    draft["hidden"] = True
    r = svc._save_record("cash_shop", "100", draft, {})
    查(r["patch"] == {"now_price": 1111, "hidden": True}, "商城只应补丁改动的两个字段")
    查(game.FakeFlashSession._cash_row_by_sn(100) is None, "hidden=true 应让该 sn 从商城目录消失")
    查(all(int(row["sn"]) != 100 for row in game.FakeFlashSession._cash_rows(None)), "sn=100 不应出现在任何分类里")

    draft["hidden"] = False
    r = svc._save_record("cash_shop", "100", draft, {"now_price": 1111, "hidden": True})
    查(r["patch"] == {"now_price": 1111, "hidden": False}, "重新上架应把 hidden 写回 false 并保留改价")
    行 = game.FakeFlashSession._cash_row_by_sn(100)
    查(行 is not None and 行["now_price"] == 1111, "消费端 _cash_row_by_sn 应看到改后的现价")
    查(game.FakeFlashSession._encode_cash_row(行).split("&")[2] == "1111", "16 字段编码序第 3 位必须是 now_price")

    未知字段拒 = False
    try:
        bad = copy.deepcopy(cash["merged"])
        bad["what"] = 1
        svc._save_record("cash_shop", "100", bad, {"now_price": 1111, "hidden": False})
    except ValueError as error:
        未知字段拒 = "不支持字段" in str(error)
    查(未知字段拒, "商城补丁出现白名单外字段时应拒绝")
    svc._reset_record("cash_shop", "100", svc._record_payload("cash_shop", "100")["override"])
    查(game.FakeFlashSession._cash_row_by_sn(100)["now_price"] == 3456, "还原后商城现价应回到抓包基础值 3456")

    # NPC 商店：派生键不回写、倍率生效、关店/开店
    npc = svc._record_payload("npc_shops", "3")
    merged = copy.deepcopy(npc["merged"])
    merged["buyPriceMultiplier"] = 1.5
    # 前端把 prices / 基础倍率当展示派生键剔掉再提交；服务端必须自己按基础值还原，
    # 否则这里会判成「删除基础字段」而保存失败。
    for 派生键 in ("prices", "buy_multiplier", "sell_multiplier"):
        merged.pop(派生键, None)
    try:
        r = svc._save_record("npc_shops", "3", merged, npc["override"])
        保存错误 = ""
    except ValueError as error:
        r = {"patch": None}
        保存错误 = str(error)
    查(not 保存错误 and r["patch"] == {"buyPriceMultiplier": 1.5},
       "NPC 店保存倍率时服务端应按基础值还原派生键，补丁只能有倍率" + ("（实际报错：" + 保存错误 + "）" if 保存错误 else ""))
    查(覆盖("npc_shops", "3") == {"buyPriceMultiplier": 1.5}, "磁盘覆盖不应出现 prices / buy_multiplier")
    查(svc._record_payload("npc_shops", "3")["merged"]["buy_multiplier"] == 1.5, "重读合并视图应把倍率映射到 buy_multiplier")
    查(game.editor_shop_override("npc_shops", 3) == {"buyPriceMultiplier": 1.5}, "服务端 editor_shop_override 应读到 NPC 倍率")

    npc = svc._record_payload("npc_shops", "3")
    merged = copy.deepcopy(npc["merged"])
    merged["enabled"] = False
    svc._save_record("npc_shops", "3", merged, npc["override"])
    查(覆盖("npc_shops", "3") == {"buyPriceMultiplier": 1.5, "enabled": False}, "关店应以 enabled=false 落盘")

    npc = svc._record_payload("npc_shops", "3")
    merged = copy.deepcopy(npc["merged"])
    merged["enabled"] = True
    svc._save_record("npc_shops", "3", merged, npc["override"])
    查("enabled" not in 覆盖("npc_shops", "3"), "重新开店应删除 enabled，而不是存 enabled=true")
    # 故意留着这条覆盖去回滚：回滚必须整份替换 overrides，而不是把当前覆盖并进去。
    查(覆盖("npc_shops", "3") == {"buyPriceMultiplier": 1.5}, "回滚前 NPC 倍率覆盖应仍在盘上")

    # 全局掉落：数字字段 + 消费端合并
    drops = svc._record_payload("drops_global", "monster_drops")
    merged = copy.deepcopy(drops["merged"])
    merged["doubleDropRateMultiplier"] = 3
    r = svc._save_record("drops_global", "monster_drops", merged, {})
    查(r["patch"] == {"doubleDropRateMultiplier": 3}, "全局掉落只应补丁改动的倍率")
    查(game.EDITOR_RUNTIME.entity("balance_rules", "monster_drops", game.BALANCE_DEFAULTS["monster_drops"])
       ["doubleDropRateMultiplier"] == 3, "服务端 balance_rules 合并视图应读到双倍掉率 3")
    svc._reset_record("drops_global", "monster_drops", svc._record_payload("drops_global", "monster_drops")["override"])

    # 掉落池 / 怪物绑定：可新建，消费端 entities() 可见
    pool = {"name": "门测试池", "description": "回归用", "items": [{"itemId": 1010011, "prob10000": 5000}]}
    svc._save_record("drop_pools", "999001", copy.deepcopy(pool), {})
    查(覆盖("drop_pools", "999001") == pool, "新建掉落池应整条写入 overrides")
    查(game.EDITOR_RUNTIME.entities("drop_pools").get("999001") == pool, "服务端 entities(drop_pools) 应展开新池")
    查("999001" in [row["id"] for row in svc._list_records("drop_pools", "", 0, 10)["records"]], "掉落池列表应包含新建的池")

    bind = {"name": "门测试绑定", "pools": ["999001"]}
    svc._save_record("drop_pool_binds", "2", copy.deepcopy(bind), {})
    查(game.EDITOR_RUNTIME.entities("drop_pool_binds").get("2") == bind, "服务端 entities(drop_pool_binds) 应读到怪物绑定")
    查("2" in [row["id"] for row in svc._list_records("drop_pool_binds", "", 0, 10)["records"]], "怪物绑定列表应包含新记录")
    svc._reset_record("drop_pool_binds", "2", svc._record_payload("drop_pool_binds", "2")["override"])
    svc._reset_record("drop_pools", "999001", svc._record_payload("drop_pools", "999001")["override"])

    # ── 备份与还原 ──────────────────────────────────────────────────────────
    备份 = svc._backup_rows()
    查(bool(备份) and all(re.match(r"^project-r\d+-\d{8}-\d{6}(?:-pre-restore)?\.json$", row["name"]) for row in 备份),
       "每次写入都应留下可回滚的 project-r<revision>-<时间>.json 备份")
    含物品的备份 = [row for row in 备份 if row["revision"] == 2]
    查(len(含物品的备份) == 1, "revision 2 的备份应恰好一份（当时 items 改名覆盖还在）")
    if 含物品的备份:
        还原前修订 = 读盘()["revision"]
        还原 = svc._restore_backup(含物品的备份[0]["name"])
        查(还原["revision"] == 还原前修订 + 1, "回滚后 revision 必须比当前大，才能触发服务端热加载")
        查(读盘()["overrides"].get("items", {}).get("1010011") == {"name": "竹制忍杖·测"}, "回滚应恢复备份里的物品改名")
        查("npc_shops" not in 读盘()["overrides"], "回滚到 revision 2 时不应保留之后的 NPC 覆盖")
        查(game.GAME_DATA_CATALOG.get_item_definition(1010011).name == "竹制忍杖·测", "回滚后服务端应立刻看到备份里的名字")

    # ── 冲突与 restore 之外，确认真工程文件没被动过 ─────────────────────────
    查(svc.PROJECT_JSON != REAL_PROJECT, "门必须把编辑器路径改到临时目录")
    真 = REAL_PROJECT.read_bytes() if REAL_PROJECT.is_file() else b""
    查(真 == REAL_BYTES, "真 project.json 必须逐字节不变（门绝不在线改运营数据）")


def main() -> int:
    global 失败
    try:
        主流程()
    except Exception:
        失败.append("锤执行异常：\n" + traceback.format_exc())
    finally:
        shutil.rmtree(TMP, ignore_errors=True)
    for line in 失败:
        print("[红] " + line)
    print("断言数：%d，失败：%d" % (断言数, len(失败)))
    if 失败:
        print("数据编辑器回归测试：失败（%d 条）" % len(失败))
        return 1
    print("数据编辑器回归测试：通过（%d 条断言）" % 断言数)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
