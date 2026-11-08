#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""2026-10-28 报修②（尾兽徽章品质色）的常驻门：徽章 **aptitude 只由尾数决定**。

用户口径：一尾~二尾 白、三尾~四尾 绿、五尾~六尾 蓝、七尾~八尾 紫、九尾~十尾 橙。

为什么是**服务端**门：名字色/流光都是客户端照协议里的 `aptitude` 原值渲染的
（`数据/装备品质.json` 的下标就是 aptitude），这个值**只有服务端能定**。
夹具里 `InventoryItem.aptitude` 默认 **2**、进阶换 id 不动它、发放走奖励行默认 ⇒
一尾~十尾全绿、还都不掉色 —— 病根在夹具，验也只能在夹具验。

真值（三条，都不是本轮新发明的）：
  * 色档 = `数据/装备品质.json`：1 白 / 2 绿 / 3 蓝 / 4 紫 / 5 橙
    （常量名与色交叉的历史问题见 §3.301 勘误，这里用的是**显示色**档）。
  * id 编号 = `数据/物品.json`：`01410001` = 无尾「尾兽徽章」（底胚）、
    `01410002` = 一尾 … `01410011` = 十尾 —— **尾数 = item_id - 1_410_001，差一格**。
  * 原版 `huiZhangStageUp` 表**只有材料**（needItemId/needItemCnt，本轮实测 dump 过）
    ⇒ 品质没有现成列可抄，只能按尾数推公式（这就是用户报的分组）。

跑法（仓库根）：
    python -X utf8 开发工具/服务端徽章品质体检.py
退出码：红 > 0 ⇒ 非 0。判决只看最后一行 `汇：判 N 条 / 红 M 条`。
"""
from __future__ import annotations

import inspect
import sys
import threading
import types
from pathlib import Path

根 = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(根 / "开发工具"))

红: list[str] = []
判 = 0


def 查(条件: bool, 说明: str) -> None:
    global 判
    判 += 1
    if not 条件:
        红.append(说明)


def 主() -> None:
    import 服务端目录

    夹具 = 服务端目录.加载()
    会话类 = getattr(夹具, "FakeFlashSession")

    # ① 全表：底胚 + 一尾~十尾 各自的品质档（用户报修那句的逐档坐实）。
    期望 = {
        1410001: 1,  # 尾兽徽章（无尾底胚）⇒ 白（最低档，用户没点名、按 白1 落）
        1410002: 1, 1410003: 1,          # 一尾/二尾 白
        1410004: 2, 1410005: 2,          # 三尾/四尾 绿
        1410006: 3, 1410007: 3,          # 五尾/六尾 蓝
        1410008: 4, 1410009: 4,          # 七尾/八尾 紫
        1410010: 5, 1410011: 5,          # 九尾/十尾 橙
    }
    for 号, 该 in sorted(期望.items()):
        got = 夹具.badge_aptitude_for_item_id(号)
        查(got == 该, f"① id {号} 的品质该是 {该}（白1/绿2/蓝3/紫4/橙5），实得 {got}")

    # ② 非徽章必须返回 0（调用方拿 0 = 不改任何东西，不许误伤别的家族）。
    for 号 in (1410012, 1010011, 13200000, 1030011, 0):
        查(夹具.badge_aptitude_for_item_id(号) == 0,
           f"② 非徽章 id {号} 必须返回 0（公式不许管徽章以外的事）")

    会话 = object.__new__(会话类)

    # ③ `_apply_badge_aptitude` 行为：错值纠正、对值幂等、非徽章不动。
    十尾 = 夹具.InventoryItem(item_id=1410011, slot=0, unique_id=1)
    十尾.aptitude = 2
    会话._apply_badge_aptitude(十尾)
    查(十尾.aptitude == 5, f"③ 十尾旧值 2 该被钉成 5（橙），实得 {十尾.aptitude}")
    会话._apply_badge_aptitude(十尾)
    查(十尾.aptitude == 5, "③ 对值再跑一遍不许动（幂等）")
    武器 = 夹具.InventoryItem(item_id=1010011, slot=0, unique_id=2)
    武器.aptitude = 3
    会话._apply_badge_aptitude(武器)
    查(武器.aptitude == 3, "③ 非徽章件经过它必须原样不动")

    # ④ 登录补档端到端（用户的老档就是这么被裁正的）：stub 一份 store 走**真方法**。
    class 假存档:
        def __init__(self, 背包: dict, 仓库: dict) -> None:
            self.lock = threading.Lock()
            self.state = types.SimpleNamespace(inventory=背包, storage=仓库)
            self.保存次数 = 0

        def save(self) -> None:
            self.保存次数 += 1

    底胚 = 夹具.InventoryItem(item_id=1410001, slot=1, unique_id=3)
    底胚.aptitude = 2
    九尾 = 夹具.InventoryItem(item_id=1410010, slot=2, unique_id=4)
    九尾.aptitude = 2
    紫武 = 夹具.InventoryItem(item_id=1010011, slot=3, unique_id=5)
    紫武.aptitude = 4
    会话.store = 假存档({1: 底胚, 2: 九尾, 3: 紫武}, {})
    会话._normalize_badge_attributes()
    查(底胚.aptitude == 1, f"④ 老档里的尾兽徽章(底胚) 2 该补成 1（白），实得 {底胚.aptitude}")
    查(九尾.aptitude == 5, f"④ 老档里的九尾 2 该补成 5（橙），实得 {九尾.aptitude}")
    查(紫武.aptitude == 4, "④ 补档不许碰普通装备的品质")
    查(会话.store.保存次数 >= 1, "④ 补了就得落盘（否则下次登录又错回来）")

    # ⑤ 四个**具名函数**的体内必须有钉子（源码钉，防"改一处漏一处"同族回归）。
    for 函数名, 钉 in (
        ("_add_inventory_item", "_apply_badge_aptitude"),
        ("_stage_up_badge", "_apply_badge_aptitude"),
        ("_apply_gift_equipment_profile", "_apply_badge_aptitude"),
        ("_normalize_badge_attributes", "badge_aptitude_for_item_id"),
    ):
        源 = inspect.getsource(getattr(会话类, 函数名))
        查(钉 in 源, f"⑤ {函数名} 体内必须引用 {钉}（品质由尾数钉死，写入点一个都不能漏）")

    # ⑥ 调用点**总数**：奖励发放 与 拾取落地 两处不在上面四个函数里，用总数兜住。
    文本 = (根 / "服务端/runtime/tools/fake_flash_server.py").read_text(encoding="utf-8")
    次数 = 文本.count("self._apply_badge_aptitude(")
    查(文本.count("def _apply_badge_aptitude(") == 1,
       "⑥ 定义必须恰好一处")
    查(次数 == 5,
       f"⑥ `_apply_badge_aptitude` 调用点该是 5（建包/进阶/礼包/奖励/拾取），实得 {次数}")


if __name__ == "__main__":
    主()
    print(f"汇：判 {判} 条 / 红 {len(红)} 条")
    for 条 in 红:
        print("!! " + 条)
    sys.exit(1 if 红 else 0)
