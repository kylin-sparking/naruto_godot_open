# -*- coding: utf-8 -*-
"""境界合计服务端门（2026-11-08）——进程内锤。

用户点名：「忍术境界里的忍术层数合计有计算灵器、忍具、勾玉的层数了，但是境界没有
计算，例如到了 450 层，还是显示上一个境界」。

根因在**服务端**：`_total_skill_level` 只数每门忍术的**基础层**，而客户端
`GameSession.total_skill_level` 数的是「基础层 + 勾玉加成 + 世界/职业加成（39/40，
两条都含八门与灵器/忍具的 specialAttr）」。本人看自己的面板是对的（客户端算的），
别人头顶的境界图标由服务端 `_skill_jingjie_realm` 广播 ⇒ 低一档；`_display_skill_level`
也跟着低。修法：服务端按客户端同口径重算（`Job0.as:293-374`、`DataCenter.as:795-810`）。

锤钉的七件事（纯进程内，`FakeFlashSession.__new__` + 临时 `SinglePlayerStore`）：
  A 只学普通忍术 ⇒ 合计 = 基础层之和（不虚增）；
  B 世界忍术（3000）只吃 40，不吃 39；
  C 职业忍术（1000/1001）只吃 39，不吃 40；
  D 情侣忍术（3301）不吃任何加成（勾玉挂在它身上也不计）；
  E 勾玉按「挂在哪门忍术」逐门加层（3000 +5、普通忍术 +3）；
  F 境界门槛 100/250/450/700/1000/1400/1900 逐档翻；
  G 跨档原场景：基础 95 + 世界忍术 3 + 忍具 40:+7 ⇒ 105，境界从 -1 翻到 0
    （旧代码只数 98 ⇒ 仍 -1，正是用户报的「到了 450 层还显示上一境界」）。

忍具钉 `65000002`（`数据/忍具.json`）：`special_attributes = ((39,3),(40,3))`。
测试再给件实例补 `[[40,4]]` ⇒ 39:+3 / 40:+7，两条腿区分得开。

用法（被 `测试/境界合计服务端回归测试.gd` 调，也可手跑）：
    python 测试/境界合计服务端锤.py
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

普通忍术 = 9_999_001      # 不在世界/职业/情侣任何一张表里
世界忍术 = 3_000          # `Job0.as:338-368 isWorldSkill`
职业忍术甲 = 1_000        # `Job0.as:293-299 isJobSkill`
职业忍术乙 = 1_001
情侣忍术 = 3_301          # `Job0.as:371-374 isCoupleSkill`
忍具号 = 65_000_002       # 特殊属性 39:+3 / 40:+3（数据/忍具.json）
玉链号 = 1_200_001        # item_id // 10_000 == 120 ⇒ 勾玉位只认这个区间

失败: list[str] = []


def 查(条件: bool, 说明: str) -> None:
    if not 条件:
        失败.append(说明)


def _建会话(根: Path) -> ffs.FakeFlashSession:
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = ffs.SinglePlayerStore(根 / "save.json")
    会话.random = random.Random(20261108)
    会话.wire_mode = "text"
    会话.发出的帧 = []
    会话.send_text = lambda payload: 会话.发出的帧.append(str(payload))
    会话._send_stats = lambda *a, **k: None
    _净场(会话)
    return 会话


def _净场(会话: ffs.FakeFlashSession) -> None:
    """清掉新档默认带的东西（意志试用品等），让合计只由本腿摆的件决定。"""
    state = 会话.store.state
    state.skills = {}
    state.inventory = {}
    state.pets = {}
    state.progression.stages = {}
    state.progression.stage_progress = {}
    state.progression.spirit_items = []


def _学(会话: ffs.FakeFlashSession, 表: dict[int, int]) -> None:
    会话.store.state.skills = {
        号: ffs.SkillState(skill_id=号, level=层) for 号, 层 in 表.items()
    }
    会话.store.state.inventory = {}


def _放忍具(会话: ffs.FakeFlashSession) -> None:
    """忍具：模板 39:+3/40:+3，实例再补 40:+4 ⇒ 39:+3 / 40:+7。"""
    件 = ffs.InventoryItem(
        item_id=忍具号,
        slot=int(ffs.EquipmentPosition.REN_JU),
        quantity=1,
        special_attributes=[[40, 4]],
    )
    会话.store.state.inventory[件.slot] = 件


def _放玉链(会话: ffs.FakeFlashSession, 勾玉: list[list[int]]) -> None:
    """勾玉行 `<槽位>,<序号>,<属性>,<忍术号>,<加层>`；合计只读第 3/4 段。"""
    件 = ffs.InventoryItem(
        item_id=玉链号,
        slot=-25,                       # 任意装备位（<0 即「在身上的玉链」）
        quantity=1,
        inlays=[list(行) for 行 in 勾玉],
    )
    会话.store.state.inventory[件.slot] = 件


def _核对(会话: ffs.FakeFlashSession, 标签: str, 期望合计: int, 期望境界: int) -> None:
    合计 = 会话._total_skill_level()
    境界 = 会话._skill_jingjie_realm()
    查(合计 == 期望合计, f"{标签}：合计该是 {期望合计}，实测 {合计}")
    查(境界 == 期望境界, f"{标签}：境界该是 {期望境界}，实测 {境界}")


def _跑(根: Path) -> None:
    会话 = _建会话(根)

    # ── A 只学普通忍术：合计就是基础层，不虚增
    _学(会话, {普通忍术: 40})
    _核对(会话, "A 基础层", 40, -1)
    查(会话._display_skill_level() == 40, "A 未到 100 层时展示层数该是真实合计 40，"
                                          f"实测 {会话._display_skill_level()}")

    # ── B 世界忍术吃 40（+7）、不吃 39（+3）
    _学(会话, {普通忍术: 40, 世界忍术: 10})
    _放忍具(会话)
    _核对(会话, "B 世界忍术", 40 + (10 + 7), -1)

    # ── C 职业忍术吃 39（+3）、不吃 40（+7）
    _学(会话, {普通忍术: 40, 职业忍术甲: 10, 职业忍术乙: 5})
    _放忍具(会话)
    _核对(会话, "C 职业忍术", 40 + (10 + 3) + (5 + 3), -1)

    # ── D 情侣忍术不吃任何加成；挂在它身上的勾玉也不计
    _学(会话, {普通忍术: 40, 情侣忍术: 10})
    _放玉链(会话, [[0, 0, 0, 情侣忍术, 9]])
    _核对(会话, "D 情侣忍术", 40 + 10, -1)

    # ── E 勾玉逐门加层：世界忍术 +5、普通忍术 +3
    _学(会话, {普通忍术: 40, 世界忍术: 10})
    _放忍具(会话)
    _放玉链(会话, [[0, 0, 0, 世界忍术, 5], [1, 0, 0, 普通忍术, 3]])
    _核对(会话, "E 勾玉加层", (40 + 3) + (10 + 7 + 5), -1)

    # ── F 境界门槛逐档翻（只摆一门普通忍术，总层 = 基础层）
    for 层, 期望境界 in (
        (99, -1), (100, 0), (249, 0), (250, 1), (449, 1), (450, 2),
        (699, 2), (700, 3), (999, 3), (1_000, 4), (1_399, 4),
        (1_400, 5), (1_899, 5), (1_900, 6),
    ):
        _学(会话, {普通忍术: 层})
        _核对(会话, f"F {层} 层", 层, 期望境界)

    # ── G 跨档原场景：基础 95 + 世界 3 + 忍具 40:+7 ⇒ 105，境界 0（旧代码 98 ⇒ -1）
    _学(会话, {普通忍术: 95, 世界忍术: 3})
    _放忍具(会话)
    _核对(会话, "G 跨档", 95 + 3 + 7, 0)
    查(会话._display_skill_level() == 100,
       f"G 跨档后展示层数该是 0 阶门槛 100，实测 {会话._display_skill_level()}")


def main() -> int:
    with tempfile.TemporaryDirectory() as 临时:
        _跑(Path(临时))
    if 失败:
        for 行 in 失败:
            print("!!! " + 行)
        print(f"境界合计服务端回归测试：红 {len(失败)} 条")
        return 1
    print("境界合计服务端回归测试：通过（基础/勾玉/世界40/职业39/情侣豁免/七档门槛/跨档）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
