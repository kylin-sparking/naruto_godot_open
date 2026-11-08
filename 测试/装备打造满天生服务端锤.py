# -*- coding: utf-8 -*-
"""天生打造「满了还能点」服务端锤（2026-11-04）。

用户报修：「天生打造，希望跟强化一样满天生后，不再可以继续点击（当前可以继续点击，
而且会消耗金币和道具）」。客户端已经把「开始强化」在 `born >= base` 时禁用，但服务端
`_forge_born_attribute` 原先是**掷点前缀都不查** —— 绕过客户端直接发 `ITEM_CHANGE 15`
就能白扣金币和生日石。本轮在 `_forge_born_attribute` 开头补了满值闸门：

    if item.base_attr_value > 0 and item.born_attr_value >= item.base_attr_value:
        self._send_system_chat("天生属性已达上限，无需继续打造。")
        return

锤钉三件事（纯进程内，`FakeFlashSession.__new__` 驱动真 `handle_item_change`）：
  ① born == base（满）⇒ 拒：born 不动、生日石不扣、金币不扣、不发帧、弹「上限」话；
  ② born < base ⇒ 正常扣 16000033×2 与 stage4 金币 8000，掷出 born ≥ base×10%；
  ③ base = 0（没数据）⇒ 不锁：照常扣料扣钱（判据必须带 base > 0，别把无数据锁死）。

2026-11-07 补两条（用户报「怀疑成功概率不是25%、成功了也会不提升」）：
  ⑤ 成功必涨：掷出的幅度低于当前值（born=300、掷 258）也要 +1；封顶 base（born=314 ⇒ 315）；
  ⑥ 概率 25% 来自 `EquipSystem.born.<类型>.prob`（服务端把该值原样交给 `_roll_forge`），
    不是写在掷骰里的魔法数。

用法（被 `测试/装备打造面板本轮回归测试.gd` 调，也可手跑）：
    python 测试/装备打造满天生服务端锤.py
退出码：0 = 全绿；1 = 有断言不符。
"""
from __future__ import annotations

import random
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "服务端" / "runtime" / "tools"))

import fake_flash_server as ffs  # noqa: E402

装备格 = 2
材料格 = 3
武器号 = 1010041      # EquipA，stage 4，base_attr_value 315
生日石 = 16000033     # born.needItemId
生日石数 = 2          # born.EquipA.needItemCnt
四级金币 = 8000        # born.needMoney.stage4
初始金币 = 10_000_000

失败: list[str] = []


def 查(条件: bool, 说明: str) -> None:
    if not 条件:
        失败.append(说明)


def _建会话(根: Path) -> ffs.FakeFlashSession:
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = ffs.SinglePlayerStore(根 / "save.json")
    会话.random = random.Random(1)          # seed 1：第一次 _roll_forge 必中（< 25）
    会话.wire_mode = "text"
    会话.发出的帧 = []
    会话.系统话 = []
    会话.send_text = lambda payload: 会话.发出的帧.append(str(payload))
    会话._send_stats = lambda *a, **k: None
    会话._client_base_combat_stats = lambda: {}
    会话._send_system_chat = lambda 话, *a, **k: 会话.系统话.append(str(话))
    会话._send_equipped_kun_chong = lambda *a, **k: None
    会话.store.state.money = 初始金币
    return 会话


def _铺(
    会话: ffs.FakeFlashSession,
    *,
    base: int = 315,
    born: int = 0,
    石数: int = 生日石数,
) -> ffs.InventoryItem:
    件 = ffs.InventoryItem(
        item_id=武器号, slot=装备格, quantity=1, unique_id=装备格,
        base_attr_type=4, base_attr_value=base, born_attr_value=born,
    )
    背包: dict[int, ffs.InventoryItem] = {装备格: 件}
    if 石数 > 0:
        背包[材料格] = ffs.InventoryItem(
            item_id=生日石, slot=材料格, quantity=石数, unique_id=材料格,
        )
    会话.store.state.inventory = 背包
    会话.发出的帧.clear()
    会话.系统话.clear()
    return 件


def _发(会话: ffs.FakeFlashSession) -> None:
    会话.handle_item_change(
        f"{ffs.op(ffs.ClientOpcode.ITEM_CHANGE)}:{int(ffs.ItemChangeAction.WASH_BORN_ATTRIBUTE)}:{装备格}"
    )


def _整件帧(会话: ffs.FakeFlashSession) -> list[list[str]]:
    前缀 = (f"{ffs.op(ffs.ServerOpcode.MODIFY_INVENTORY_ITEM)}:"
            f"{ffs.op(ffs.InventoryUpdateFlag.UPDATE_EQUIP_SLOT)}:")
    return [帧.split(":") for 帧 in 会话.发出的帧 if 帧.startswith(前缀)]


def _清格帧(会话: ffs.FakeFlashSession) -> list[list[str]]:
    前缀 = (f"{ffs.op(ffs.ServerOpcode.MODIFY_INVENTORY_ITEM)}:"
            f"{ffs.op(ffs.InventoryUpdateFlag.CLEAR)}:")
    return [帧.split(":") for 帧 in 会话.发出的帧 if 帧.startswith(前缀)]


def _数量(会话: ffs.FakeFlashSession, 格: int) -> int:
    件 = 会话.store.state.inventory.get(格)
    return 0 if 件 is None else int(件.quantity)


def _跑(根: Path) -> None:
    # ── ① born == base（满）⇒ 拒、不扣、不发帧 ──
    会话 = _建会话(根)
    件 = _铺(会话, base=315, born=315, 石数=2)
    _发(会话)
    查(件.born_attr_value == 315, f"① 满天生不该再掷，实测 born={件.born_attr_value}")
    查(_数量(会话, 材料格) == 2, f"① 满天生被拒不该扣生日石，实测剩 {_数量(会话, 材料格)}")
    查(会话.store.state.money == 初始金币,
       f"① 满天生被拒不该扣金币，实测 {会话.store.state.money}")
    查(not 会话.发出的帧, f"① 满天生被拒不该发帧，实测 {会话.发出的帧}")
    查(any("上限" in 话 for 话 in 会话.系统话), f"① 该弹「上限」话，实测 {会话.系统话}")

    # ── ② born < base ⇒ 正常扣料扣钱并掷点 ──
    会话 = _建会话(根)
    件 = _铺(会话, base=315, born=0, 石数=2)
    _发(会话)
    查(件.born_attr_value >= 32, f"② 未满该掷出 born ≥ 31（315×10%），实测 {件.born_attr_value}")
    查(_数量(会话, 材料格) == 0, f"② 该扣光 2 块生日石，实测剩 {_数量(会话, 材料格)}")
    查(会话.store.state.money == 初始金币 - 四级金币,
       f"② 该扣 stage4 金币 {四级金币}，实测 {会话.store.state.money}")
    查(len(_整件帧(会话)) == 1, f"② 成功该发一条整件帧，实测 {len(_整件帧(会话))} 条")
    查(len(_清格帧(会话)) == 1, f"② 材料扣光该发一条清格帧，实测 {len(_清格帧(会话))} 条")

    # ── ③ base = 0（没数据）⇒ 不锁，照常扣 ──
    会话 = _建会话(根)
    件 = _铺(会话, base=0, born=0, 石数=2)
    _发(会话)
    查(_数量(会话, 材料格) == 0, f"③ base=0 不该被满值闸门挡住，实测剩 {_数量(会话, 材料格)}")
    查(会话.store.state.money == 初始金币 - 四级金币,
       f"③ base=0 也该扣金币，实测 {会话.store.state.money}")
    查(not any("上限" in 话 for 话 in 会话.系统话), f"③ base=0 不该弹「上限」话，实测 {会话.系统话}")


    # ── ⑤ 成功必涨、封顶 base ──
    # seed 1：_roll_forge 先取 randrange(100)=17（<25 成功），随后 randint(10,100)=82
    # ⇒ 掷出幅度 round(315×82%)=258，低于当前 300：成功也必须 +1，不许原地。
    会话 = _建会话(根)
    件 = _铺(会话, base=315, born=300, 石数=2)
    _发(会话)
    查(件.born_attr_value > 300, f"⑤ 成功必涨：born=300 该 >300，实测 {件.born_attr_value}")
    查(件.born_attr_value <= 315, f"⑤ 涨幅不许超 base=315，实测 {件.born_attr_value}")
    会话 = _建会话(根)
    件 = _铺(会话, base=315, born=314, 石数=2)
    _发(会话)
    查(件.born_attr_value == 315, f"⑤ 封顶：born=314 成功该停在 315，实测 {件.born_attr_value}")

    # ── ⑥ 成功率 25% 取自配置，且原样交给掷骰 ──
    语境 = ffs.GAME_DATA_CATALOG.get_equipment_system_config("born")
    for 类型 in ("EquipA", "EquipB", "EquipC", "EquipD", "EquipE", "EquipF",
                 "EquipG", "EquipH", "EquipI", "EquipJ", "EquipK", "EquipL",
                 "PetA", "PetB", "PetC", "PetD"):
        查(int(语境.get(类型, {}).get("prob", 0)) == 25,
           f"⑥ born.{类型}.prob 应为 25，实测 {语境.get(类型, {}).get('prob')}")
    会话 = _建会话(根)
    _铺(会话, base=315, born=0, 石数=2)
    掷骰入参: list[int] = []
    会话._roll_forge = lambda p, *a: (掷骰入参.append(int(p)), True)[1]
    _发(会话)
    查(掷骰入参 == [25], f"⑥ 掷骰该收到配置里的 25，实测 {掷骰入参}")


def _失败也应答(根: Path) -> None:
    for 动作 in (ffs.ItemChangeAction.STRENGTH, ffs.ItemChangeAction.WASH_BORN_ATTRIBUTE):
        会话 = _建会话(根)
        件 = _铺(会话, born=100, 石数=4)
        会话._roll_forge = lambda *_: False
        if 动作 == ffs.ItemChangeAction.STRENGTH:
            件.strength_level = 9
            会话.store.state.inventory[材料格].item_id = 16000016
            会话.store.state.inventory[材料格].quantity = 181
            期望金币 = 初始金币
            期望材料 = 1
        else:
            期望金币 = 初始金币 - 四级金币
            期望材料 = 2
        会话.handle_item_change(f"{ffs.op(ffs.ClientOpcode.ITEM_CHANGE)}:{int(动作)}:{装备格}")
        查(len(_整件帧(会话)) == 1, f"④ {动作.name}概率失败也须回一份装备快照供自动打造续跑")
        查(_数量(会话, 材料格) == 期望材料, f"④ {动作.name}失败只扣本次材料")
        查(会话.store.state.money == 期望金币, f"④ {动作.name}失败只扣本次金币")
        查(件.born_attr_value == 100, f"④ {动作.name}失败不改天生值")
        if 动作 == ffs.ItemChangeAction.STRENGTH:
            查(件.strength_level == 9, "④ 强化失败不改星级")


def main() -> int:
    with tempfile.TemporaryDirectory() as 临时:
        _跑(Path(临时))
        _失败也应答(Path(临时))
    if 失败:
        for 行 in 失败:
            print("!!! " + 行)
        print(f"装备打造满天生服务端锤：红 {len(失败)} 条")
        return 1
    print("装备打造满天生服务端锤：通过（满值拒且不扣不发帧、未满正常扣、base=0 不锁）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
