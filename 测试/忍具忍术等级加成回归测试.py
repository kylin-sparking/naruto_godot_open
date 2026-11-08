# -*- coding: utf-8 -*-
"""忍具忍术等级加成回归门（2026-11-01）——进程内锤。

用户点名：「八咫镜的忍术等级提升效果没有实装，在忍术面板不显示」。

真值：`RenJuData.getSpecialAttr` 与 `LingQiData.getSpecialAttr` **完全同构**（两份
`2.2.3/.../RenJuData.as:103-109` / `LingQiData.as:103-109`），都把
`JOB_SKILL_LEVEL` / `WORLD_SKILL_LEVEL` 折成统计 39/40（`CocoStatType.ADD_JOB_SKILL_LEVEL=39`、
`ADD_WORLD_SKILL_LEVEL=40`），再由 `DataCenter.as:2808-2820` 送进 `UI.setSkillData`。

钉的七条腿：
  L1 数据解析：65000002（开光）的 `specialAttr` 解析成 `((39, 3), (40, 3))`；
     65000001（基础）数据里没有 `specialAttr` ⇒ 不许凭空造加成。灵器段的
     `addAttr`（附加属性上限表）也仍在。
  L2 统计号就是 39/40（客户端 `后端连接.gd:3796` 按这个号折 `addJobSkillLevel` /
     `addWorldSkillLevel`；改号而客户端没改 = 整个加成静默消失）。
  L3 槽位：65000002 戴在忍具位（`EquipmentPosition.REN_JU = -24`）⇒ 39/40 各 +3；
     65000001 ⇒ 0。
  L4 背包里的忍具不算（slot 为正，`op(slot)` 不是 -24）。
  L5 叠加：十拳剑 20200001（+2）与开光八咫镜（+3）同时戴 ⇒ 5，不是取大值。
  L6 `_client_base_combat_stats`（= 进图 13764 / 穿脱 `_send_all_stats` 的取值口）
     把 39/40 算成「成长 + 特殊加成」：基线 4/1 ⇒ 7/4；换 65000001 ⇒ 回到 4/1。
  L7 `_effective_skill_level` 吃到加成（基础 5 层 + 3 ⇒ 8 层）——服务端伤害结算与
     `SKILL_CHANGE_TMP` 用的就是它。

为什么对旧代码确定性红：旧服务端只在 `item_family == 20`（灵器）分支解析
`specialAttr`，且加成只扫 `EquipmentPosition.LING_QI`（-23）⇒ L1/L3/L5/L6/L7 全红。

用法（被 `测试/忍具忍术等级加成回归测试.gd` 调，也可手跑）：
    python 测试/忍具忍术等级加成回归测试.py
退出码：0 = 全绿；1 = 有断言不符。
"""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "服务端" / "runtime" / "tools"))

import fake_flash_server as ffs  # noqa: E402

开光八咫镜 = 65000002
基本八咫镜 = 65000001
十拳剑 = 20200001
职位 = ffs.EquipmentPosition
统计 = ffs.StatType
成长 = ffs.CultivationAttribute

失败: list[str] = []


def 查(条件: bool, 说明: str) -> None:
    if not 条件:
        失败.append(说明)


def _建会话(根: Path) -> ffs.FakeFlashSession:
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = ffs.SinglePlayerStore(根 / "save.json")
    会话.wire_mode = "original"
    会话.发出的帧 = []
    会话.send_text = lambda payload: 会话.发出的帧.append(str(payload))
    # `_client_base_combat_stats` 的十一个 `_current_*` 与成长表在别的门里各有钉子；
    # 这里固定已知基线，单看「39/40 = 成长 + 灵器/忍具加成」这一条。
    会话._growth_attribute_bonuses = lambda: {
        属性: 0 for 属性 in ffs.CultivationAttribute
    } | {
        成长.JOB_SKILL_LEVEL: 4,
        成长.WORLD_SKILL_LEVEL: 1,
    }
    for 名 in (
        "_current_max_hp",
        "_current_max_mp",
        "_current_attack",
        "_current_defence",
        "_current_critical",
        "_current_evasion",
        "_current_attack_speed",
        "_current_walk_speed",
        "_current_damage_reflect",
        "_current_damage_reduce",
        "_current_ignore_defence",
    ):
        setattr(会话, 名, lambda: 0)
    return 会话


def _穿(会话: ffs.FakeFlashSession, 表: dict[int, int]) -> None:
    会话.store.state.inventory = {
        ffs.op(槽): ffs.InventoryItem(
            item_id=号, slot=int(槽), quantity=1, unique_id=序号 + 1
        )
        for 序号, (槽, 号) in enumerate(表.items())
    }


def _放背包(会话: ffs.FakeFlashSession, 号: int, 格: int = 5) -> None:
    会话.store.state.inventory = {
        格: ffs.InventoryItem(item_id=号, slot=格, quantity=1, unique_id=991)
    }


def _加成(会话: ffs.FakeFlashSession) -> tuple[int, int]:
    return (
        会话._special_skill_level_bonus(统计.ADD_JOB_SKILL_LEVEL),
        会话._special_skill_level_bonus(统计.ADD_WORLD_SKILL_LEVEL),
    )


def 主() -> int:
    # ── L1 数据解析 ──
    定义 = ffs.GAME_DATA_CATALOG.get_equipment_definition(开光八咫镜)
    查(定义 is not None, "65000002 解析不出装备定义（数据/忍具.json 路径断了）")
    if 定义 is not None:
        查(
            定义.position == 职位.REN_JU,
            "65000002 的槽位是 %s，原版是忍具位 -24" % 定义.position,
        )
        查(
            定义.special_attributes
            == ((int(统计.ADD_JOB_SKILL_LEVEL), 3), (int(统计.ADD_WORLD_SKILL_LEVEL), 3)),
            "65000002 的 specialAttr 应解析成 ((39,3),(40,3))，实际 %s"
            % (定义.special_attributes,),
        )
        查(
            定义.additional_attributes == ((4, 200), (5, 333), (7, 333)),
            "忍具的 addAttr 仍要解析（附加属性上限表），实际 %s"
            % (定义.additional_attributes,),
        )
    基本定义 = ffs.GAME_DATA_CATALOG.get_equipment_definition(基本八咫镜)
    查(
        基本定义 is not None and 基本定义.special_attributes == (),
        "65000001 数据里没有 specialAttr ⇒ 不许凭空造加成，实际 %s"
        % (基本定义.special_attributes if 基本定义 else None,),
    )

    # ── L2 统计号 ──
    查(
        int(统计.ADD_JOB_SKILL_LEVEL) == 39 and int(统计.ADD_WORLD_SKILL_LEVEL) == 40,
        "统计号应是 39/40（客户端 `后端连接.gd:3796` 按号折 addJobSkillLevel/addWorldSkillLevel），"
        "实际 %d/%d" % (int(统计.ADD_JOB_SKILL_LEVEL), int(统计.ADD_WORLD_SKILL_LEVEL)),
    )

    with tempfile.TemporaryDirectory() as 临时:
        会话 = _建会话(Path(临时))

        # ── L3 忍具位 ──
        _穿(会话, {职位.REN_JU: 开光八咫镜})
        查(_加成(会话) == (3, 3), "开光八咫镜戴在忍具位 ⇒ 39/40 各 +3，实际 %s" % (_加成(会话),))
        _穿(会话, {职位.REN_JU: 基本八咫镜})
        查(_加成(会话) == (0, 0), "基础八咫镜没有 specialAttr ⇒ 0/0，实际 %s" % (_加成(会话),))

        # ── L4 背包里的不算 ──
        _放背包(会话, 开光八咫镜)
        查(_加成(会话) == (0, 0), "放在背包（正格位）的八咫镜不许算加成，实际 %s" % (_加成(会话),))

        # ── L5 灵器 + 忍具叠加 ──
        _穿(会话, {职位.REN_JU: 开光八咫镜, 职位.LING_QI: 十拳剑})
        查(_加成(会话) == (5, 5), "十拳剑(+2) 与开光八咫镜(+3) 同时戴 ⇒ 5/5，实际 %s" % (_加成(会话),))

        # ── L6 发给客户端的 39/40 ──
        _穿(会话, {职位.REN_JU: 开光八咫镜})
        表 = 会话._client_base_combat_stats()
        查(
            表[统计.ADD_JOB_SKILL_LEVEL] == 7,
            "职业忍术等级应 = 成长 4 + 忍具 3 = 7，实际 %d"
            % 表[统计.ADD_JOB_SKILL_LEVEL],
        )
        查(
            表[统计.ADD_WORLD_SKILL_LEVEL] == 4,
            "世界忍术等级应 = 成长 1 + 忍具 3 = 4，实际 %d"
            % 表[统计.ADD_WORLD_SKILL_LEVEL],
        )
        _穿(会话, {职位.REN_JU: 基本八咫镜})
        表 = 会话._client_base_combat_stats()
        查(
            表[统计.ADD_JOB_SKILL_LEVEL] == 4 and 表[统计.ADD_WORLD_SKILL_LEVEL] == 1,
            "换回基础八咫镜 ⇒ 只剩成长 4/1，实际 %d/%d"
            % (表[统计.ADD_JOB_SKILL_LEVEL], 表[统计.ADD_WORLD_SKILL_LEVEL]),
        )

        # ── L7 技能层数 ──
        技能 = ffs.SkillState(skill_id=1001, level=5)
        _穿(会话, {职位.REN_JU: 开光八咫镜})
        查(
            会话._effective_skill_level(技能) == 8,
            "基础 5 层 + 忍具 3 ⇒ 有效 8 层，实际 %d" % 会话._effective_skill_level(技能),
        )
        _穿(会话, {职位.REN_JU: 基本八咫镜})
        查(
            会话._effective_skill_level(技能) == 5,
            "基础八咫镜 ⇒ 仍 5 层，实际 %d" % 会话._effective_skill_level(技能),
        )

    if 失败:
        print("忍具忍术等级加成回归测试：红 %d 条" % len(失败))
        for 说明 in 失败:
            print("  !! " + 说明)
        return 1
    print(
        "忍具忍术等级加成回归测试：通过（specialAttr 解析 / 39·40 号 / 忍具位生效 / "
        "背包不算 / 灵器叠加 / 发给客户端的 39·40 / 技能层数 各钉）"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(主())
