# -*- coding: utf-8 -*-
"""寄坏强化回帧同步门（2026-10-31）——进程内锤。

用户点名：「昆虫强化成功后，昆虫详情框信息不能及时同步，以至于昆虫强化面板的操作
成功几率也没有变化；强化成功后，不管是昆虫强化里的昆虫详情框，还是背包里的，还是
显示的 1 星，再次强化还是 1 星成功，但把昆虫佩戴后，会显示正确的强化等级」。

根因：`_strengthen_kun_chong` 改完件只发 `flag 1`（`UpdateInventorySlotInfo`，
**只带 quantity**）⇒ 客户端镜像里的 `strengthen` / `strength_info` /
`plus_attributes` 全停在发起前：详情框按旧件画、面板按旧星级查 `strength[阶+1]`
算几率、`_lastLevel` 也停在旧值，所以永远「强化 1 星成功」；佩戴那条链路本来就会
送整件，于是「佩戴后才对」。修法与 `_finish_forge:55769-55770` 同一处置：发
**flag 11 整件**（`UpdateEquipSlotInfo`，原版 `Client.onUpdateEquipSlot:5995-6020`
的 `position > 0` 分支就是背包件）。

锤钉的七件事（纯进程内，用 `FakeFlashSession.__new__` 驱动真 `handle_item_change`）：
  ① 背包里的虫强化成功 ⇒ 必须发 `MOV...:11:<槽>:<类型>:<物品体>` 整件帧；
  ② 该整件帧的物品体：第 22 段星级 = 新等级、第 23 段 strength_info 长度 = 星级、
     第 17 段词条数 = `equipment_plus_attribute_count(资质)`；
  ③ 2066 回帧对**背包件**回原槽号、结果 1；
  ④ 身上的虫（-200）整件帧按装备槽发（-200），2066 按原版件序回 **73** ——
     客户端负责把 73..76 折回 -200..-203（`后端连接.gd` 的同轮改动）；
  ⑤ 失败降级（5 星 + failResult=1 ⇒ 4 星）同样必须发整件帧（星级跟着回落）；
  ⑥ 销毁（11 星 + failResult=3）发的是清格帧，不补整件帧；
  ⑦ `strength_value` 跟新星级：round(base_attr_value × addRatio ÷ 100)。

为什么旧代码确定性红：修前这条路径只有 `flag 1` 帧，①③④⑤ 一律找不到整件帧（见
`开发工具/_反向_寄坏强化同步.py` 的 M1）。

用法（被 `测试/寄坏强化同步回归测试.gd` 调，也可手跑）：
    python 测试/寄坏强化同步回归测试.py
退出码：0 = 全绿；1 = 有断言不符。
"""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "服务端" / "runtime" / "tools"))

import fake_flash_server as ffs  # noqa: E402

虫号 = 1310001  # attr: maxhp，六条 authored 词条（KUN_CHONG_SIX_BASE_ATTRIBUTES）
背包格 = 2
身上槽 = int(ffs.EquipmentPosition.KUN_CHONG_A)          # -200
客户端件序 = 73                                          # 原版客户端的槽号（73..76）

失败: list[str] = []


def 查(条件: bool, 说明: str) -> None:
    if not 条件:
        失败.append(说明)


def _建会话(根: Path) -> ffs.FakeFlashSession:
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = ffs.SinglePlayerStore(根 / "save.json")
    会话.random = __import__("random").Random(20261031)
    会话.wire_mode = "text"          # 文本通道才是本端口客户端；original 会走二进制分支
    会话.发出的帧 = []
    会话.send_text = lambda payload: 会话.发出的帧.append(str(payload))
    会话._send_stats = lambda *a, **k: None
    会话._client_base_combat_stats = lambda: {}   # 参数在调用前就构造，桩不掉 `_send_stats`
    会话._send_system_chat = lambda *a, **k: None
    会话._send_equipped_kun_chong = lambda *a, **k: None
    会话.store.state.money = 10_000_000
    return 会话


def _放虫(会话: ffs.FakeFlashSession, 槽: int, 星级: int, 资质: int = 2) -> ffs.InventoryItem:
    件 = ffs.InventoryItem(
        item_id=虫号, slot=槽, quantity=1, unique_id=槽 if 槽 > 0 else 900 + abs(槽),
        aptitude=资质, strength_level=星级,
        strength_info=[True] * 星级,
    )
    会话.store.state.inventory = {槽: 件}
    会话.发出的帧.clear()
    return 件


def _强化(会话: ffs.FakeFlashSession, 槽: int) -> None:
    会话.handle_item_change(
        f"{ffs.op(ffs.ClientOpcode.ITEM_CHANGE)}:{int(ffs.ItemChangeAction.STRENGTH_KUNCHONG)}:{槽}:0:0"
    )


def _整件帧(会话: ffs.FakeFlashSession) -> list[list[str]]:
    前缀 = f"{ffs.op(ffs.ServerOpcode.MODIFY_INVENTORY_ITEM)}:{ffs.op(ffs.InventoryUpdateFlag.UPDATE_EQUIP_SLOT)}:"
    出 = []
    for 帧 in 会话.发出的帧:
        if not 帧.startswith(前缀):
            continue
        段 = 帧.split(":")
        if len(段) >= 5:
            出.append(段)
    return 出


def _数量帧(会话: ffs.FakeFlashSession) -> list[str]:
    前缀 = f"{ffs.op(ffs.ServerOpcode.MODIFY_INVENTORY_ITEM)}:{ffs.op(ffs.InventoryUpdateFlag.UPDATE)}:"
    return [帧 for 帧 in 会话.发出的帧 if 帧.startswith(前缀)]


def _结果帧(会话: ffs.FakeFlashSession) -> list[str]:
    前缀 = f"{ffs.op(ffs.ServerOpcode.KUNCHONG_STRENGTH_RESULT)}:"
    return [帧 for 帧 in 会话.发出的帧 if 帧.startswith(前缀)]


def _物品体(段: list[str]) -> list[str]:
    return 段[4].split("&")


def _核对物品体(件: ffs.InventoryItem, 期望星: int, 前缀: str) -> None:
    体 = _物品体(件) if isinstance(件, list) else []
    if len(体) < 24:
        失败.append(f"{前缀}：整件帧的物品体只有 {len(体)} 段（<24，客户端解析不出装备段）")
        return
    查(int(体[22]) == 期望星, f"{前缀}：物品体第 22 段星级该是 {期望星}，实测 {体[22]}")
    星料 = [值 for 值 in str(体[23]).split("!") if 值 and 值 != "-"]
    查(len(星料) == 期望星, f"{前缀}：strength_info 长度该是 {期望星}，实测 {len(星料)}（{体[23]}）")
    词条 = [] if str(体[17]) in {"", "-"} else [行 for 行 in str(体[17]).split("!") if 行]
    想要 = ffs.equipment_plus_attribute_count(2, None)
    查(len(词条) == 想要, f"{前缀}：附加词条该按资质 2 出 {想要} 条，实测 {len(词条)}（{体[17]}）")


def _跑(根: Path) -> None:
    会话 = _建会话(根)

    # ── ① ③ 背包里的虫：0 → 1 星（strength[1].ratio = 100，确定性）
    件 = _放虫(会话, 背包格, 0)
    _强化(会话, 背包格)
    整件 = _整件帧(会话)
    查(len(整件) == 1, f"① 背包虫强化成功该发**一条** flag 11 整件帧，实测 {len(整件)} 条"
                     f"（帧：{[帧[:60] for 帧 in 会话.发出的帧]}）")
    if 整件:
        查(int(整件[0][2]) == 背包格, f"① 整件帧的槽该是背包格 {背包格}，实测 {整件[0][2]}")
        _核对物品体(整件[0], 1, "② 背包虫 0→1")
        查(int(件.strength_level) == 1, f"⑦ 服务端件的星级该是 1，实测 {件.strength_level}")
        期望值 = round(件.base_attr_value * 30 / 100)
        查(int(件.strength_value) == 期望值,
           f"⑦ strength_value 该是 round({件.base_attr_value}×30/100)={期望值}，实测 {件.strength_value}")
        查(int(_物品体(整件[0])[16]) == 期望值,
           f"⑦ 整件帧第 16 段（strength_value）该是 {期望值}，实测 {_物品体(整件[0])[16]}")
    结果 = _结果帧(会话)
    查(len(结果) == 1, f"③ 该发一条 2066 回帧，实测 {len(结果)} 条")
    if 结果:
        段 = 结果[0].split(":")
        查(int(段[1]) == 背包格 and int(段[2]) == 1,
           f"③ 背包件 2066 该回 `:{背包格}:1`，实测 `{结果[0]}`")
    查(not _数量帧(会话), "⑤ 整件帧之外不该再叠一条 flag 1 数量帧（原版只发 UpdateEquipSlotInfo）")

    # ── ④ 身上的虫（-200）：整件帧按装备槽发，2066 按原版件序回 73
    _放虫(会话, 身上槽, 0)
    _强化(会话, 身上槽)
    整件 = _整件帧(会话)
    查(len(整件) == 1, f"④ 身上虫强化成功该发一条 flag 11 整件帧，实测 {len(整件)} 条")
    if 整件:
        查(int(整件[0][2]) == 身上槽, f"④ 整件帧的槽该是装备位 {身上槽}，实测 {整件[0][2]}")
        _核对物品体(整件[0], 1, "④ 身上虫 0→1")
    结果 = _结果帧(会话)
    if 结果:
        查(int(结果[0].split(":")[1]) == 客户端件序,
           f"④ 身上的虫 2066 该按原版件序回 {客户端件序}（客户端折回 {身上槽}），实测 `{结果[0]}`")
    else:
        失败.append("④ 身上虫强化后没收到 2066")

    # ── ⑤ 失败降级：5 星 + strength[6].failResult=1 ⇒ 回到 4 星，同样得发整件帧
    会话._roll_forge = lambda *a, **k: False
    件 = _放虫(会话, 背包格, 5)
    _强化(会话, 背包格)
    整件 = _整件帧(会话)
    查(len(整件) == 1, f"⑤ 失败降级后也该发一条整件帧，实测 {len(整件)} 条")
    if 整件:
        _核对物品体(整件[0], 4, "⑤ 5→4 降级")
    if _结果帧(会话):
        查(int(_结果帧(会话)[0].split(":")[2]) == 0, "⑤ 失败回帧的结果位该是 0")
    else:
        失败.append("⑤ 失败降级后没收到 2066")

    # ── ⑥ 销毁：11 星 + strength[12].failResult=3 ⇒ 清格，不补整件帧
    件 = _放虫(会话, 背包格, 11)
    _强化(会话, 背包格)
    查(not _整件帧(会话), f"⑥ 件被销毁时不该再发整件帧，实测 {len(_整件帧(会话))} 条")
    清前 = f"{ffs.op(ffs.ServerOpcode.MODIFY_INVENTORY_ITEM)}:{ffs.op(ffs.InventoryUpdateFlag.CLEAR)}:"
    查(any(帧.startswith(清前) for 帧 in 会话.发出的帧), "⑥ 件被销毁该发清格帧")
    查(背包格 not in 会话.store.state.inventory, "⑥ 件该从存档里消失")


def main() -> int:
    with tempfile.TemporaryDirectory() as 临时:
        _跑(Path(临时))
    if 失败:
        for 行 in 失败:
            print("!!! " + 行)
        print(f"寄坏强化同步回归测试：红 {len(失败)} 条")
        return 1
    print("寄坏强化同步回归测试：通过（成功/降级都发整件帧、星级/词条/加值同步、2066 槽位口径）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
