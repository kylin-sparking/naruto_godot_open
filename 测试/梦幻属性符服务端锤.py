# -*- coding: utf-8 -*-
"""梦幻属性符服务端锤（2026-11-03）——进程内锤。

用户点名：「背包梦幻属性符，功能未实装，显示是材料或人物物品，不能直接使用」。

客户端 `_执行梦幻重置` 按原版 `MengHuanPropResetWindow.as:96` 发 **1 基**序号：
`ITEM_CHANGE 20`，字段 `[20, 装备格, 材料格, 属性序号(1 基)]`。服务端
`_forge_full_plus_attribute` 必须减一后取 `plus_attributes` 那一条，把它的数值抬到
`plus.stage<阶>.<部位类型名>` 里同英文名那条的 `valueTo`，并消耗 `plus.fullone.needItemId`
一件。序号 0 / 越界 / 没材料都不许改动、不许扣料。

锤钉的五件事（纯进程内，`FakeFlashSession.__new__` 驱动真 `handle_item_change`）：
  ① 序号 1（1 基）⇒ 抬**第 0 条**到上限 7，第 1 条不动；
  ② 序号 2 ⇒ 抬**第 1 条**到上限 8；
  ③ 抬完发 `flag 11` 整件帧（槽 = 装备格）+ 材料 `flag 1` 数量帧；扣完发清格帧；
  ④ 序号 0 / 99 ⇒ 不动、不扣料、不發帧；
  ⑤ 没材料 ⇒ 不动、不發帧、弹「不够」话；
  ⑥ 已超上限（9 ≥ 8）⇒ 保持 9，不降。

用法（被 `测试/梦幻属性符回归测试.gd` 调，也可手跑）：
    python 测试/梦幻属性符服务端锤.py
退出码：0 = 全绿；1 = 有断言不符。
"""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "服务端" / "runtime" / "tools"))

import fake_flash_server as ffs  # noqa: E402

装备号 = 1010011          # 一段紫武器，type_name EquipA，stage 1
符号 = 15024001           # plus.fullone.needItemId
装备格 = 2
材料格 = 3

失败: list[str] = []


def 查(条件: bool, 说明: str) -> None:
    if not 条件:
        失败.append(说明)


def _建会话(根: Path) -> ffs.FakeFlashSession:
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = ffs.SinglePlayerStore(根 / "save.json")
    会话.random = __import__("random").Random(20261103)
    会话.wire_mode = "text"
    会话.发出的帧 = []
    会话.系统话 = []
    会话.send_text = lambda payload: 会话.发出的帧.append(str(payload))
    会话._send_stats = lambda *a, **k: None
    会话._client_base_combat_stats = lambda: {}
    会话._send_system_chat = lambda 话, *a, **k: 会话.系统话.append(str(话))
    会话._send_equipped_kun_chong = lambda *a, **k: None
    会话.store.state.money = 10_000_000
    return 会话


def _铺(会话: ffs.FakeFlashSession, 符数: int, 词条: list[list[int]]) -> ffs.InventoryItem:
    件 = ffs.InventoryItem(
        item_id=装备号, slot=装备格, quantity=1, unique_id=装备格,
        aptitude=4, plus_attributes=[list(条) for 条 in 词条],
    )
    背包 = {装备格: 件}
    if 符数 > 0:
        背包[材料格] = ffs.InventoryItem(
            item_id=符号, slot=材料格, quantity=符数, unique_id=材料格,
        )
    会话.store.state.inventory = 背包
    会话.发出的帧.clear()
    会话.系统话.clear()
    return 件


def _重置(会话: ffs.FakeFlashSession, 序号: int) -> None:
    会话.handle_item_change(
        f"{ffs.op(ffs.ClientOpcode.ITEM_CHANGE)}:"
        f"{int(ffs.ItemChangeAction.FULL_PLUS_ATTRIBUTE)}:"
        f"{装备格}:{材料格}:{序号}"
    )


def _整件帧(会话: ffs.FakeFlashSession) -> list[list[str]]:
    前缀 = (f"{ffs.op(ffs.ServerOpcode.MODIFY_INVENTORY_ITEM)}:"
            f"{ffs.op(ffs.InventoryUpdateFlag.UPDATE_EQUIP_SLOT)}:")
    出 = []
    for 帧 in 会话.发出的帧:
        if 帧.startswith(前缀):
            段 = 帧.split(":")
            if len(段) >= 4:
                出.append(段)
    return 出


def _数量帧(会话: ffs.FakeFlashSession) -> list[list[str]]:
    前缀 = (f"{ffs.op(ffs.ServerOpcode.MODIFY_INVENTORY_ITEM)}:"
            f"{ffs.op(ffs.InventoryUpdateFlag.UPDATE)}:")
    return [帧.split(":") for 帧 in 会话.发出的帧 if 帧.startswith(前缀)]


def _清格帧(会话: ffs.FakeFlashSession) -> list[list[str]]:
    前缀 = (f"{ffs.op(ffs.ServerOpcode.MODIFY_INVENTORY_ITEM)}:"
            f"{ffs.op(ffs.InventoryUpdateFlag.CLEAR)}:")
    return [帧.split(":") for 帧 in 会话.发出的帧 if 帧.startswith(前缀)]


def _符数(会话: ffs.FakeFlashSession) -> int:
    件 = 会话.store.state.inventory.get(材料格)
    return 0 if 件 is None else int(件.quantity)


def _跑(根: Path) -> None:
    # ── ① 序号 1（1 基）⇒ 第 0 条 3→7，第 1 条不动 ──
    会话 = _建会话(根)
    件 = _铺(会话, 2, [[4, 3], [6, 5]])
    _重置(会话, 1)
    查(件.plus_attributes[0] == [4, 7],
       f"① 序号 1（1 基）该把第 0 条 atk 3 抬到 7，实测 {件.plus_attributes[0]}")
    查(件.plus_attributes[1] == [6, 5],
       f"① 第 1 条 bsk 不该被动，实测 {件.plus_attributes[1]}")
    查(_符数(会话) == 1, f"① 该扣 1 张符（2→1），实测 {_符数(会话)}")
    整件 = _整件帧(会话)
    查(len(整件) == 1, f"① 该发一条 flag 11 整件帧，实测 {len(整件)} 条")
    if 整件:
        查(int(整件[0][2]) == 装备格, f"① 整件帧槽该是装备格 {装备格}，实测 {整件[0][2]}")
    数量 = _数量帧(会话)
    查(len(数量) == 1, f"① 该发一条材料 flag 1 数量帧，实测 {len(数量)} 条")
    if 数量:
        查(int(数量[0][4]) == 材料格 and int(数量[0][5]) == 1,
           f"① 材料帧该是槽 {材料格} 剩 1，实测 `{':'.join(数量[0])}`")

    # ── ② 序号 2 ⇒ 第 1 条 5→8；扣到 0 该发清格帧 ──
    会话 = _建会话(根)
    件 = _铺(会话, 1, [[4, 3], [6, 5]])
    _重置(会话, 2)
    查(件.plus_attributes[1] == [6, 8],
       f"② 序号 2（1 基）该把第 1 条 bsk 5 抬到 8，实测 {件.plus_attributes[1]}")
    查(件.plus_attributes[0] == [4, 3],
       f"② 第 0 条 atk 不该被动，实测 {件.plus_attributes[0]}")
    查(材料格 not in 会话.store.state.inventory, "② 符扣到 0 该从存档消失")
    查(len(_清格帧(会话)) == 1, f"② 符扣完该发一条清格帧，实测 {len(_清格帧(会话))} 条")

    # ── ③ 序号 0 / 99 ⇒ 不动、不扣、不發帧 ──
    for 序号 in (0, 99):
        会话 = _建会话(根)
        件 = _铺(会话, 2, [[4, 3], [6, 5]])
        _重置(会话, 序号)
        查(件.plus_attributes == [[4, 3], [6, 5]],
           f"③ 序号 {序号} 越界，属性不该动，实测 {件.plus_attributes}")
        查(_符数(会话) == 2, f"③ 序号 {序号} 越界，不该扣符，实测 {_符数(会话)}")
        查(not 会话.发出的帧, f"③ 序号 {序号} 越界，不该發任何帧，实测 {会话.发出的帧}")

    # ── ④ 没材料 ⇒ 不动、不發帧、弹话 ──
    会话 = _建会话(根)
    件 = _铺(会话, 0, [[4, 3], [6, 5]])
    _重置(会话, 1)
    查(件.plus_attributes == [[4, 3], [6, 5]],
       f"④ 没符时属性不该动，实测 {件.plus_attributes}")
    查(not 会话.发出的帧, f"④ 没符时不该發帧，实测 {会话.发出的帧}")
    查(any("不够" in 话 or "购买" in 话 for 话 in 会话.系统话),
       f"④ 没符该弹「不够 / 购买」话，实测 {会话.系统话}")

    # ── ⑤ 已超上限（9 ≥ 8）⇒ 保持 9，不降 ──
    会话 = _建会话(根)
    件 = _铺(会话, 1, [[4, 3], [6, 9]])
    _重置(会话, 2)
    查(件.plus_attributes[1] == [6, 9],
       f"⑤ 已超上限该保持 9，实测 {件.plus_attributes[1]}")
    查(_符数(会话) == 0, f"⑤ 有效请求仍该扣符，实测 {_符数(会话)}")


def main() -> int:
    with tempfile.TemporaryDirectory() as 临时:
        _跑(Path(临时))
    if 失败:
        for 行 in 失败:
            print("!!! " + 行)
        print(f"梦幻属性符服务端锤：红 {len(失败)} 条")
        return 1
    print("梦幻属性符服务端锤：通过（1 基序号/抬到上限/不降/扣料/越界与缺料不动）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
