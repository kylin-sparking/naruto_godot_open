# -*- coding: utf-8 -*-
"""橙装打造 / 精炼服务端锤（2026-11-04）——进程内锤。

用户报修：「传说装备打造石，功能未实装」；同一轮还报了「天生/精炼满级后还能继续点」，
说明服务端不能只靠客户端拦。橙装这两条原本一条校验都没有：

  · `_forge_change_to_orange` 只查 `aptitude != 4`，**没查 10 星、没查 60 级**；
  · `_forge_change_tale_attribute` **什么都不查**，紫装直接能重掷一条传说属性。

客户端 `YellowEquipLianZhiWindow.strengthHandler:146-198` 的三道闸门
（非紫 / 未满 10 星 / 低于 60 级）与精炼页那道（非橙）必须在服务端各有一份，
否则绕过客户端直接发 `ITEM_CHANGE 23/24` 就能白嫖。被拒时**不许扣料、不许发帧**。

锤钉的八件事（纯进程内，`FakeFlashSession.__new__` 驱动真 `handle_item_change`）：
  ① 紫 10 星 60 级 + 80 块 ⇒ 变橙、掷出传说属性、80 块扣光（清格帧）、发整件帧；
  ② 已经是橙 ⇒ 拒、不扣、不发帧；
  ③ 紫 9 星 ⇒ 拒、不扣、不发帧；
  ④ 紫 10 星但 1 级（01010011）⇒ 拒、不扣、不发帧；
  ⑤ 紫 0 星 ⇒ 拒、不扣、不发帧；
  ⑥ 精炼紫装 ⇒ 拒、不扣精炼石、不发帧；
  ⑦ 精炼橙装 ⇒ 成功、精炼石 2→1、发整件帧；
  ⑧ 没打造石 ⇒ 拒、不动属性、不发帧、弹「购买」话。

用法（被 `测试/橙装打造回归测试.gd` 调，也可手跑）：
    python 测试/橙装打造服务端锤.py
退出码：0 = 全绿；1 = 有断言不符。
"""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "服务端" / "runtime" / "tools"))

import fake_flash_server as ffs  # noqa: E402

装备格 = 2
材料格 = 3
紫装备号 = 1010041      # EquipA，required_level 60
低等级装备号 = 1010011  # EquipA，required_level 1
打造石 = 15029001       # changeToOrange.needItemId，EquipA 需要 80
精炼石 = 15028001       # changeTaleAttribute.needItemId，需要 1

失败: list[str] = []


def 查(条件: bool, 说明: str) -> None:
    if not 条件:
        失败.append(说明)


def _建会话(根: Path) -> ffs.FakeFlashSession:
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = ffs.SinglePlayerStore(根 / "save.json")
    会话.random = __import__("random").Random(20261104)
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


def _铺(
    会话: ffs.FakeFlashSession,
    *,
    装备号: int = 紫装备号,
    aptitude: int = 4,
    stars: int = 10,
    打造石数: int = 80,
    精炼石数: int = 0,
    传说: tuple[int, int] = (-1, 0),
) -> tuple[ffs.InventoryItem, ffs.InventoryItem | None]:
    件 = ffs.InventoryItem(
        item_id=装备号, slot=装备格, quantity=1, unique_id=装备格,
        aptitude=aptitude, strength_level=stars,
        tale_attr_type=传说[0], tale_attr_value=传说[1],
    )
    背包: dict[int, ffs.InventoryItem] = {装备格: 件}
    石 = None
    if 打造石数 > 0:
        背包[材料格] = ffs.InventoryItem(
            item_id=打造石, slot=材料格, quantity=打造石数, unique_id=材料格,
        )
    if 精炼石数 > 0:
        背包[材料格 + 1] = ffs.InventoryItem(
            item_id=精炼石, slot=材料格 + 1, quantity=精炼石数, unique_id=材料格 + 1,
        )
    会话.store.state.inventory = 背包
    会话.发出的帧.clear()
    会话.系统话.clear()
    return 件, 石


def _发(会话: ffs.FakeFlashSession, 动作: ffs.ItemChangeAction) -> None:
    会话.handle_item_change(
        f"{ffs.op(ffs.ClientOpcode.ITEM_CHANGE)}:{int(动作)}:{装备格}"
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


def _打造(会话: ffs.FakeFlashSession) -> None:
    _发(会话, ffs.ItemChangeAction.CHANGE_TO_ORANGE)


def _精炼(会话: ffs.FakeFlashSession) -> None:
    _发(会话, ffs.ItemChangeAction.CHANGE_TALE_ATTRIBUTE)


def _跑(根: Path) -> None:
    # ── ① 紫 10 星 60 级 + 80 块 ⇒ 变橙 + 掷传说 + 扣光 ──
    会话 = _建会话(根)
    件, _ = _铺(会话, 打造石数=80)
    _打造(会话)
    查(件.aptitude == 5, f"① 紫 10 星 60 级该变橙，实测 aptitude={件.aptitude}")
    查(件.tale_attr_value > 0, f"① 变橙该掷出一条传说属性，实测 type={件.tale_attr_type} value={件.tale_attr_value}")
    查(_数量(会话, 材料格) == 0, f"① 80 块打造石该扣光，实测剩 {_数量(会话, 材料格)}")
    查(len(_整件帧(会话)) == 1, f"① 该发一条整件帧，实测 {len(_整件帧(会话))} 条")
    查(len(_清格帧(会话)) == 1, f"① 材料扣光该发一条清格帧，实测 {len(_清格帧(会话))} 条")

    # ── ② 已经是橙 ⇒ 拒 ──
    会话 = _建会话(根)
    件, _ = _铺(会话, aptitude=5, 打造石数=80)
    _打造(会话)
    查(件.aptitude == 5 and 件.tale_attr_value == 0,
       f"② 橙装再打造不该动，实测 aptitude={件.aptitude} tale={件.tale_attr_value}")
    查(_数量(会话, 材料格) == 80, f"② 被拒不该扣料，实测剩 {_数量(会话, 材料格)}")
    查(not 会话.发出的帧, f"② 被拒不该发帧，实测 {会话.发出的帧}")
    查(any("紫色10星" in 话 for 话 in 会话.系统话), f"② 该弹「紫色10星」话，实测 {会话.系统话}")

    # ── ③ 9 星 ⇒ 拒 ──
    会话 = _建会话(根)
    件, _ = _铺(会话, stars=9, 打造石数=80)
    _打造(会话)
    查(件.aptitude == 4, f"③ 9 星不该变橙，实测 aptitude={件.aptitude}")
    查(_数量(会话, 材料格) == 80, f"③ 9 星被拒不该扣料，实测剩 {_数量(会话, 材料格)}")
    查(not 会话.发出的帧, f"③ 9 星被拒不该发帧，实测 {会话.发出的帧}")

    # ── ④ 10 星但 1 级 ⇒ 拒 ──
    会话 = _建会话(根)
    件, _ = _铺(会话, 装备号=低等级装备号, stars=10, 打造石数=80)
    _打造(会话)
    查(件.aptitude == 4, f"④ 1 级 10 星不该变橙，实测 aptitude={件.aptitude}")
    查(_数量(会话, 材料格) == 80, f"④ 1 级被拒不该扣料，实测剩 {_数量(会话, 材料格)}")
    查(not 会话.发出的帧, f"④ 1 级被拒不该发帧，实测 {会话.发出的帧}")

    # ── ⑤ 0 星 ⇒ 拒 ──
    会话 = _建会话(根)
    件, _ = _铺(会话, stars=0, 打造石数=80)
    _打造(会话)
    查(件.aptitude == 4, f"⑤ 0 星不该变橙，实测 aptitude={件.aptitude}")
    查(not 会话.发出的帧, f"⑤ 0 星被拒不该发帧，实测 {会话.发出的帧}")

    # ── ⑥ 精炼紫装 ⇒ 拒 ──
    会话 = _建会话(根)
    件, _ = _铺(会话, aptitude=4, 打造石数=0, 精炼石数=2)
    _精炼(会话)
    查(件.tale_attr_value == 0, f"⑥ 紫装精炼不该掷传说，实测 value={件.tale_attr_value}")
    查(_数量(会话, 材料格 + 1) == 2, f"⑥ 紫装精炼被拒不该扣精炼石，实测剩 {_数量(会话, 材料格 + 1)}")
    查(not 会话.发出的帧, f"⑥ 紫装精炼被拒不该发帧，实测 {会话.发出的帧}")
    查(any("橙装精炼" in 话 for 话 in 会话.系统话), f"⑥ 该弹「橙装精炼」话，实测 {会话.系统话}")

    # ── ⑦ 精炼橙装 ⇒ 成功 ──
    会话 = _建会话(根)
    件, _ = _铺(会话, aptitude=5, 打造石数=0, 精炼石数=2, 传说=(4, 3))
    _精炼(会话)
    查(件.tale_attr_value > 0, f"⑦ 橙装精炼该重掷传说，实测 type={件.tale_attr_type} value={件.tale_attr_value}")
    查(_数量(会话, 材料格 + 1) == 1, f"⑦ 精炼石该 2→1，实测 {_数量(会话, 材料格 + 1)}")
    查(len(_整件帧(会话)) == 1, f"⑦ 该发一条整件帧，实测 {len(_整件帧(会话))} 条")

    # ── ⑧ 没打造石 ⇒ 拒 ──
    会话 = _建会话(根)
    件, _ = _铺(会话, 打造石数=0)
    _打造(会话)
    查(件.aptitude == 4, f"⑧ 没打造石不该变橙，实测 aptitude={件.aptitude}")
    查(not 会话.发出的帧, f"⑧ 没打造石不该发帧，实测 {会话.发出的帧}")
    查(any("传说装备打造石" in 话 for 话 in 会话.系统话),
       f"⑧ 没料该弹「传说装备打造石」话，实测 {会话.系统话}")


def main() -> int:
    with tempfile.TemporaryDirectory() as 临时:
        _跑(Path(临时))
    if 失败:
        for 行 in 失败:
            print("!!! " + 行)
        print(f"橙装打造服务端锤：红 {len(失败)} 条")
        return 1
    print("橙装打造服务端锤：通过（打造自查 10星/60级/紫、精炼自查橙、拒不动料不发帧）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
