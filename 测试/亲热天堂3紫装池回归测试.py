# -*- coding: utf-8 -*-
"""亲热天堂3紫装池回归门（2026-10-31）——进程内锤。

用户点名：「亲热天堂3奖励池要加入高星强化紫装，6~9星」。

钉的五件事：
  ① 类型 4（《亲热天堂3》/ 15008004）的 16 个候选里，装备候选**一定是**
     角色装备（101~112）、资质 4（紫）、强化星级 ∈ {6,7,8,9}，
     且 reqJob ∈ {0, 角色职业}、reqLevel ≤ 角色等级；
  ② 四种星级都会出现（权重 80000/40000/12000/2000），装备占比仍在 13.8% 上下；
  ③ 亲热天堂1/2（类型 2/3）候选里**一件装备都不出**（用户只点名 3）；
  ④ 预览帧（action 17/18 的候选串）与发放帧（action 20 落到背包的那件）同口径：
     `&` 第 10 段 = aptitude=4、第 22 段 = strength ∈ 6..9、strength_value > 0、
     strength_info 长度 = 星级；
  ⑤ 存档重载后 candidate_aptitudes / candidate_strengths 仍在（重连不丢品质）；
  ⑥ 成就福袋与亲热天堂**各占一个交易槽**：一条没领的福袋不能把「显示宝贝」卡成静默无反应
     （用户 2026-10-31 报的原症状），反向也不许；两个槽都活过存档重载；老存档按 mode 迁移；
     动作 18 扣件失败时服务端必须回帧（不吭声 = 客户端「没反应」）；
  ⑦ 发到背包的紫装**必须有 6 条附加词条**，类型只出自该部位候选池（无池走整阶兜底）、
     数值落在各自区间 —— 原来奖励路径一条都不掷，详情框「附加属性」整段是空的；
  ⑧ GM 发 60 级紫装：12 个部位**每件都 6 条**（EquipA/EquipB/EquipL 的候选池只有 3 条，
     照抄表就只能出 3 条，用户 2026-10-31 报「武器、手套词条只有3条」）。

为什么能当门跑：不依赖网络/夹具/Godot —— 纯进程内用 `FakeFlashSession.__new__`
驱动真正的 `handle_fudai`（只桩发送）与 `_draw_treasure_candidates`，读真实
GameData 目录（`Box.baoxiang[4].zhuangbei` + `Box.info.zhuangbei`）。

为什么对旧代码确定性红：旧服务端没有 `TREASURE_EQUIPMENT_TABLES`，候选只从
`items` 抽 ⇒ ①④⑤ 全红；把表清空/改星级/放开 2/3 型/漏写发放属性各能单独抓红
（见编年史反向对照表）。

用法（被 `测试/亲热天堂3紫装池回归测试.gd` 调，也可手跑）：
    python 测试/亲热天堂3紫装池回归测试.py
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

书三 = 15008004
书一 = 15008002
书二 = 15008003
类型三 = 4
类型一 = 2
类型二 = 3
紫 = 4
星集 = {6, 7, 8, 9}
候选数 = 16

失败: list[str] = []


def 查(条件: bool, 说明: str) -> None:
    if not 条件:
        失败.append(说明)


def _建会话(根: Path) -> ffs.FakeFlashSession:
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = ffs.SinglePlayerStore(根 / "save.json")
    会话.random = random.Random(20261031)
    会话.发出的帧 = []
    会话.send_text = lambda payload: 会话.发出的帧.append(str(payload))
    会话._advance_activity = lambda slot, amount=1: None
    会话._broadcast_rare_event = lambda *a, **k: None
    会话._broadcast_display_skill_level = lambda *a, **k: None
    会话._send_inventory_add = lambda *a, **k: None
    会话._send_inventory_update = lambda *a, **k: None
    会话._send_inventory_clear = lambda *a, **k: None
    会话._send_equipment_pickup = lambda *a, **k: None
    会话.pending_equipment_pickups = set()
    return 会话


def _塞书(会话: ffs.FakeFlashSession, 书: int, 格: int = 1, 数量: int = 999) -> None:
    会话.store.state.inventory = {
        格: ffs.InventoryItem(item_id=书, slot=格, quantity=数量, unique_id=格 * 7919)
    }
    会话.store.state.baoxiang_transaction = None


def _开箱(会话: ffs.FakeFlashSession, 类型: int, 格: int = 1):
    会话.store.state.baoxiang_transaction = None
    会话.handle_fudai(f"{ffs.op(ffs.ClientOpcode.FUDAI)}:18:{类型}:{格}")
    return 会话.store.state.baoxiang_transaction


def _物品池(类型: int) -> tuple[int, ...]:
    return tuple(
        item_id
        for item_id in ffs.GAME_DATA_CATALOG.baoxiang_reward_pools.get(类型, ())
        if ffs.GAME_DATA_CATALOG.get_item_definition(item_id) is not None
    )


def _装备定义(装备: int):
    return ffs.GAME_DATA_CATALOG.get_equipment_definition(装备)


def _允许词条(定义) -> dict[int, tuple[str, int, int]]:
    """这件装备能出的附加词条：部位池优先；部位池为空时按整阶去重类型池（同会话兜底）。"""
    rows = ffs.equipment_plus_stage_rows(定义)
    if not rows:
        plus_root = ffs.GAME_DATA_CATALOG.get_equipment_system_config("plus")
        stage_root = plus_root.get(f"stage{定义.stage}")
        seen: dict[str, dict] = {}
        if isinstance(stage_root, dict):
            for _, type_root in sorted(stage_root.items()):
                if not isinstance(type_root, dict):
                    continue
                for _, row in sorted(type_root.items()):
                    if not isinstance(row, dict):
                        continue
                    name = str(row.get("type") or "").lower()
                    if name not in seen:
                        seen[name] = row
        rows = list(seen.values())
    allowed: dict[int, tuple[str, int, int]] = {}
    for row in rows:
        name = str(row.get("type") or "").lower()
        attribute = ffs.EQUIPMENT_ATTRIBUTE_BY_NAME.get(name)
        if attribute is None:
            continue
        low = int(row.get("valueFrom") or 1)
        high = max(low, int(row.get("valueTo") or low))
        旧 = allowed.get(int(attribute))
        allowed[int(attribute)] = (
            name,
            min(low, 旧[1]) if 旧 else low,
            max(high, 旧[2]) if 旧 else high,
        )
    return allowed


def _核对词条(件, 装备编号: int, 前缀: str) -> None:
    定义 = _装备定义(装备编号)
    查(定义 is not None, f"{前缀}：{装备编号} 解不出装备定义（查不了词条）")
    if 定义 is None:
        return
    条数 = len(件.plus_attributes or [])
    查(条数 == 6, f"{前缀}：紫装 {装备编号}（{定义.type_name}）应有 6 条附加词条，实得 {条数}")
    允许 = _允许词条(定义)
    查(len(允许) > 0,
       f"{前缀}：{装备编号}（{定义.type_name}，阶{定义.stage}）在 plus 表里一个候选都没有（查不了）")
    for 属性, 数值 in 件.plus_attributes or []:
        范围 = 允许.get(int(属性))
        查(范围 is not None,
           f"{前缀}：{装备编号} 词条属性 {属性} 不在 {定义.type_name} 的候选类型里（{sorted(允许)}）")
        if 范围 is not None:
            查(范围[1] <= int(数值) <= 范围[2],
               f"{前缀}：{装备编号} 词条 {范围[0]}={数值} 超出区间 [{范围[1]}, {范围[2]}]")


def _抽(会话: ffs.FakeFlashSession, 类型: int):
    return 会话._draw_treasure_candidates(类型, _物品池(类型))


def _单件判据(装备: int, 资质: int, 星级: int, 等级: int, 职业: int, 前缀: str) -> None:
    目录 = ffs.GAME_DATA_CATALOG
    查(目录.is_equipment_item(装备), f"{前缀}：{装备} 不是装备但带了资质/星级（{资质}/{星级}）")
    查(101 <= 装备 // 10_000 <= 112, f"{前缀}：{装备} 不是角色装备（101~112）")
    查(装备 in 目录.box_equipment_ids, f"{前缀}：{装备} 不在 Box.info.zhuangbei 的装备表里")
    查(资质 == 紫, f"{前缀}：{装备} 资质应为紫装 4，实得 {资质}")
    查(星级 in 星集, f"{前缀}：{装备} 星级应在 6~9，实得 {星级}")
    定义 = _装备定义(装备)
    查(定义 is not None, f"{前缀}：{装备} 解不出装备定义")
    if 定义 is not None:
        查(定义.required_level <= 等级, f"{前缀}：{装备} reqLevel={定义.required_level} 超过角色等级 {等级}")
        查(定义.required_job in (0, 职业), f"{前缀}：{装备} reqJob={定义.required_job} 与职业 {职业} 不匹配")


def _逐候选(会话: ffs.FakeFlashSession, 类型: int, 等级: int, 职业: int, 前缀: str):
    """跑 `n` 次会返回 (物品候选数, 装备候选数, 星级计数)。"""
    会话.character.level = 等级
    会话.character.job = 职业
    物品种 = set(_物品池(类型))
    物品数 = 0
    装备数 = 0
    星级计数 = {星: 0 for 星 in 星集}
    for 轮 in range(200):
        候选, 资质表, 星级表 = _抽(会话, 类型)
        查(len(候选) == 候选数, f"{前缀}：第 {轮} 轮候选数是 {len(候选)}，应为 {候选数}")
        查(len(资质表) == len(候选) and len(星级表) == len(候选),
           f"{前缀}：第 {轮} 轮资质/星级表长度 {len(资质表)}/{len(星级表)} 与候选 {len(候选)} 不齐")
        for 下标, 物品 in enumerate(候选):
            资质 = 资质表[下标] if 下标 < len(资质表) else -1
            星级 = 星级表[下标] if 下标 < len(星级表) else -1
            if 资质 or 星级:
                装备数 += 1
                _单件判据(物品, 资质, 星级, 等级, 职业, f"{前缀} 第 {轮} 轮 #{下标}")
                if 星级 in 星级计数:
                    星级计数[星级] += 1
            else:
                物品数 += 1
                查(物品 in 物品种, f"{前缀}：第 {轮} 轮 #{下标} 物品 {物品} 不在奖励池里")
    return 物品数, 装备数, 星级计数


def 主流程() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        根 = Path(tmp)
        会话 = _建会话(根)
        目录 = ffs.GAME_DATA_CATALOG

        # ① 目录与表本身（硬编码用户口径：紫装 4 资质、6~9 星）。
        表 = getattr(ffs, "TREASURE_EQUIPMENT_TABLES", {})
        查(set(表) == {类型三}, f"TREASURE_EQUIPMENT_TABLES 只应含类型 4，实得 {sorted(表)}")
        行 = 表.get(类型三, ())
        查(len(行) == 4, f"类型 4 的装备档应是 4 档，实得 {len(行)}")
        查({星 for _资, 星, _重 in 行} == 星集, f"装备档星级集合应是 {sorted(星集)}，实得 {sorted({星 for _资, 星, _重 in 行})}")
        查({资 for 资, _星, _重 in 行} == {紫}, f"装备档资质应全是 4（紫装），实得 {sorted({资 for 资, _星, _重 in 行})}")
        查(sum(重 for _资, _星, 重 in 行) == 134_000,
           f"装备档总权重应保留原表 134000，实得 {sum(重 for _资, _星, 重 in 行)}")
        查(len(目录.box_equipment_ids) >= 100, f"Box.info.zhuangbei 装备表只解出 {len(目录.box_equipment_ids)} 件")

        # ② 类型 4：全流程 60 轮（action 18 真入口），逐件核对 + 星级覆盖。
        会话.character.level = 100
        会话.character.job = 300
        _塞书(会话, 书三)
        物品种 = set(_物品池(类型三))
        物 = 装 = 0
        星计 = {星: 0 for 星 in 星集}
        装备轮 = 0
        for 轮 in range(60):
            事务 = _开箱(会话, 类型三)
            查(事务 is not None and 事务.mode == "treasure", f"类型 4 第 {轮} 轮 action 18 没开成事务")
            if 事务 is None:
                break
            查(事务.type_id == 类型三, f"类型 4 第 {轮} 轮事务 type_id={事务.type_id}")
            查(len(事务.candidates) == 候选数, f"类型 4 第 {轮} 轮候选 {len(事务.candidates)} 个")
            查(len(事务.candidate_aptitudes) == 候选数 and len(事务.candidate_strengths) == 候选数,
               f"类型 4 第 {轮} 轮资质/星级表落进事务时长度不对")
            for 下标, 物品 in enumerate(事务.candidates):
                资质 = 事务.candidate_aptitudes[下标]
                星级 = 事务.candidate_strengths[下标]
                if 资质 or 星级:
                    装 += 1
                    _单件判据(物品, 资质, 星级, 100, 300, f"类型4 第 {轮} 轮 #{下标}")
                    if 星级 in 星计:
                        星计[星级] += 1
                else:
                    物 += 1
                    查(物品 in 物品种, f"类型4 第 {轮} 轮 #{下标} 物品 {物品} 不在奖励池里")
            装备轮 += 1 if any(事务.candidate_aptitudes) else 0
        # 每轮候选里都会被 `_塞书` 重置事务；上面 `break` 只断了内层 for。
        查(装备轮 > 0, "类型 4 连开 60 轮，一件装备候选都没出（池子没接上）")
        总数 = 物 + 装
        查(总数 == 60 * 候选数, f"类型 4 总候选数应为 {60 * 候选数}，实得 {总数}")
        占比 = 装 / 总数 if 总数 else 0.0
        查(0.07 <= 占比 <= 0.22, f"类型 4 装备候选占比 {占比:.3%} 偏离原表 13.8% 过多")

        # ③ 四种星级在 200 轮直抽里都应出现。
        _, 直装, 直星计 = _逐候选(会话, 类型三, 100, 300, "类型4直抽")
        查(直装 > 0, "类型 4 直抽 200 轮一个装备都没有")
        for 星 in sorted(星集):
            查(直星计[星] > 0, f"类型 4 直抽 200 轮没出过 {星} 星（实得 {直星计}）")

        # ④ 类型 2/3 不出装备（用户只点名亲热天堂3）。
        for 类型 in (类型一, 类型二):
            _, 装备数, _ = _逐候选(会话, 类型, 100, 300, f"类型{类型}直抽")
            查(装备数 == 0, f"类型 {类型} 不该出装备，实得 {装备数} 件")

        # ⑤ 等级/职业过滤：20 级角色只出 reqLevel ≤ 20 的；100 级 100 职业只出 reqJob ∈ {0,100}。
        _, 低装, _ = _逐候选(会话, 类型三, 20, 300, "20级")
        查(低装 > 0, "20 级角色开 200 轮一件可穿装备都没有（过滤太狠）")
        _, 职装, _ = _逐候选(会话, 类型三, 100, 100, "职业100")
        查(职装 > 0, "职业 100 开 200 轮一件可穿装备都没有")

        # ⑥ 预览帧字段位置（客户端 `_parse_item_entry` 依赖）：&10=资质、&22=星级。
        会话.character.level = 100
        会话.character.job = 300
        _塞书(会话, 书三)
        事务 = None
        for _ in range(40):
            事务 = _开箱(会话, 类型三)
            if 事务 is not None and any(事务.candidate_aptitudes):
                break
        查(事务 is not None, "类型 4 40 轮内没开出带装备的候选")
        if 事务 is not None and any(事务.candidate_aptitudes):
            # 这一帧里的**每一件**装备候选都要过，避免只抽查第一件时撞巧。
            for 下标 in [i for i, 级 in enumerate(事务.candidate_aptitudes) if 级]:
                预览件 = 会话._treasure_candidate_item(事务, 下标)
                段 = 会话._encode_item_payload(预览件).split("&")
                查(len(段) > 23, f"预览帧 #{下标} 只有 {len(段)} 段，应 ≥ 24")
                if len(段) <= 23:
                    continue
                查(int(段[10]) == 紫, f"预览帧 #{下标} &10 应是资质 4，实得 {段[10]}")
                查(int(段[22]) == 事务.candidate_strengths[下标],
                   f"预览帧 #{下标} &22 应是星级 {事务.candidate_strengths[下标]}，实得 {段[22]}")
                查(int(段[22]) in 星集, f"预览帧 #{下标} &22 星级 {段[22]} 不在 6~9")
                查(段[23] != "-" and 段[23].count("true") == int(段[22]),
                   f"预览帧 #{下标} &23 strength_info 应等于星级数，实得 {段[23]}")
                查(int(段[16]) > 0, f"预览帧 #{下标} &16 strength_value 应 > 0，实得 {段[16]}")
                定义 = _装备定义(int(事务.candidates[下标]))
                查(定义 is not None, f"预览候选 #{下标} 解不出装备定义")
                if 定义 is not None:
                    查(int(段[14]) == 定义.base_attr_value,
                       f"预览帧 #{下标} &14 base_attr_value 应等于装备定义的 {定义.base_attr_value}（没写基础属性 ⇒ 按默认 40 算），实得 {段[14]}")
                    查(int(段[13]) == 定义.base_attr_type,
                       f"预览帧 #{下标} &13 base_attr_type 应等于装备定义的 {定义.base_attr_type}，实得 {段[13]}")

            # ⑦ 存档重载：资质/星级跟着事务活下来。
            存档事务 = 事务
            会话.store.save()
            重载 = ffs.SinglePlayerStore(根 / "save.json")
            重事 = 重载.state.baoxiang_transaction
            查(重事 is not None and 重事.mode == "treasure", "重载后事务丢了")
            if 重事 is not None:
                查(重事.candidate_aptitudes == 存档事务.candidate_aptitudes,
                   f"重载后 candidate_aptitudes 变了：{重事.candidate_aptitudes} vs {存档事务.candidate_aptitudes}")
                查(重事.candidate_strengths == 存档事务.candidate_strengths,
                   f"重载后 candidate_strengths 变了：{重事.candidate_strengths} vs {存档事务.candidate_strengths}")

        # ⑧ 全流程 18 → 19 → 20：发到背包的装备与预览同口径。
        会话.store.state = ffs.SinglePlayerStore(根 / "save.json").state
        会话.character.level = 100
        会话.character.job = 300
        会话.random = random.Random(20261031)
        收货装备 = 0
        for 轮 in range(80):
            _塞书(会话, 书三)
            事务 = _开箱(会话, 类型三)
            查(事务 is not None, f"发放第 {轮} 轮没开成事务")
            if 事务 is None:
                break
            会话.handle_fudai(f"{ffs.op(ffs.ClientOpcode.FUDAI)}:19")
            下标 = 事务.selected_index
            查(0 <= 下标 < 候选数, f"发放第 {轮} 轮 action 19 没选下标（{下标}）")
            if not (0 <= 下标 < 候选数):
                break
            期望物品 = 事务.candidates[下标]
            期望资质 = 事务.candidate_aptitudes[下标]
            期望星级 = 事务.candidate_strengths[下标]
            会话.handle_fudai(f"{ffs.op(ffs.ClientOpcode.FUDAI)}:20")
            查(会话.store.state.baoxiang_transaction is None, f"发放第 {轮} 轮 action 20 没清事务")
            收货 = next(
                (件 for 件 in 会话.store.state.inventory.values() if 件.item_id == 期望物品 and 件.slot > 0),
                None,
            )
            查(收货 is not None, f"发放第 {轮} 轮背包里找不到奖励 {期望物品}")
            if 收货 is None:
                continue
            if 期望资质 or 期望星级:
                收货装备 += 1
                查(收货.aptitude == 紫, f"发放第 {轮} 轮资质应 4，实得 {收货.aptitude}")
                查(收货.strength_level in 星集, f"发放第 {轮} 轮星级应 6~9，实得 {收货.strength_level}")
                查(len(收货.strength_info) == 收货.strength_level,
                   f"发放第 {轮} 轮 strength_info 长度 {len(收货.strength_info)} ≠ 星级 {收货.strength_level}")
                查(收货.strength_value > 0, f"发放第 {轮} 轮 strength_value 应 > 0，实得 {收货.strength_value}")
                _核对词条(收货, int(期望物品), f"发放第 {轮} 轮")
            else:
                查(not 目录.is_equipment_item(期望物品), f"发放第 {轮} 轮普通物品不该是装备 {期望物品}")
        查(收货装备 > 0, "连开 80 轮没有一次抽中装备，发放腿没走到")

        会话.store.state.baoxiang_transaction = None

        # ⑨ 两条交易各占一个槽（用户 2026-10-31：「点显示宝贝没有反应」）。
        #    合用一个槽时，一条没领的成就福袋会让动作 18 走 `elif transaction.mode != "treasure"`
        #    ⇒ 只回一帧 `state=0` 的预览，屏幕一动不动。这里两个方向都钉。
        会话.store.state = ffs.SinglePlayerStore(根 / "save.json").state
        会话.character.level = 100
        会话.character.job = 300
        会话.store.state.inventory = {
            1: ffs.InventoryItem(item_id=书三, slot=1, quantity=3, unique_id=701),
            2: ffs.InventoryItem(item_id=15008001, slot=2, quantity=3, unique_id=702),
        }
        会话.store.state.fudai_transaction = None
        会话.store.state.baoxiang_transaction = None
        会话.handle_fudai(f"{ffs.op(ffs.ClientOpcode.FUDAI)}:1:2")   # 双击成就福袋
        福袋 = 会话.store.state.fudai_transaction
        查(福袋 is not None and 福袋.mode == "fudai", "⑨ 动作 1 没开出福袋交易（前置没铺上）")
        福袋后数量 = 会话.store.state.inventory[2].quantity
        _开箱(会话, 类型三)                                          # 福袋待领时开宝箱
        查(会话.store.state.baoxiang_transaction is not None,
           "⑨ 福袋待领时「显示宝贝」开不出宝箱（两个系统又共用一个槽了）")
        查(会话.store.state.fudai_transaction is 福袋, "⑨ 开宝箱把待领的福袋交易冲掉了")
        宝箱 = 会话.store.state.baoxiang_transaction
        会话.handle_fudai(f"{ffs.op(ffs.ClientOpcode.FUDAI)}:1:2")   # 宝箱待领时再双击福袋
        查(会话.store.state.baoxiang_transaction is 宝箱, "⑨ 开福袋把待领的宝箱交易冲掉了")
        查(
            会话.store.state.inventory.get(2) is not None
            and 会话.store.state.inventory[2].quantity == 福袋后数量,
            "⑨ 已有待领福袋时再双击福袋，不该再扣一件",
        )

        # ⑩ 两个槽都要活过存档重载。
        会话.store.save()
        重载二 = ffs.SinglePlayerStore(根 / "save.json")
        查(
            重载二.state.fudai_transaction is not None
            and 重载二.state.fudai_transaction.mode == "fudai",
            "⑩ 重载后福袋交易丢了",
        )
        查(
            重载二.state.baoxiang_transaction is not None
            and 重载二.state.baoxiang_transaction.mode == "treasure",
            "⑩ 重载后宝箱交易丢了",
        )

        # ⑪ 老存档只有一个 `fudai_transaction` 槽（两类交易混放）⇒ 读档按 mode 搬回宝箱槽。
        旧档 = {
            "version": 41,
            "character": {"level": 100, "job": 300},
            "fudai_transaction": {
                "item_id": 书三,
                "type_id": 类型三,
                "mode": "treasure",
                "candidates": list(_物品池(类型三))[:候选数],
                "selected_index": -1,
                "source_slot": 1,
                "candidate_aptitudes": [0] * 候选数,
                "candidate_strengths": [0] * 候选数,
            },
        }
        载入 = ffs.SinglePlayerState.from_dict(旧档)
        查(
            载入.baoxiang_transaction is not None
            and 载入.baoxiang_transaction.mode == "treasure",
            "⑪ 老存档里的宝箱交易没搬进 baoxiang_transaction",
        )
        查(载入.fudai_transaction is None, "⑪ 老存档里的宝箱交易还赖在 fudai_transaction 上")

        # ⑫ 扣件失败也要回一帧（服务端一声不吭 = 客户端「没反应」）。
        会话.store.state.baoxiang_transaction = None
        原扣件 = 会话._consume_bag_slot
        会话._consume_bag_slot = lambda *a, **k: (None, False)
        帧前 = len(会话.发出的帧)
        会话.handle_fudai(f"{ffs.op(ffs.ClientOpcode.FUDAI)}:18:{类型三}:1")
        会话._consume_bag_slot = 原扣件
        查(len(会话.发出的帧) > 帧前, "⑫ 扣件失败时服务端不回帧（客户端只能干等）")

        # ⑬ GM 发 60 级紫装：12 个部位**每件都 6 条**。
        #    根因（用户 2026-10-31 报「武器、手套词条只有3条」）：GM 老实现按
        #    `plus.stage<阶>.<部位>` 逐条抄，而 EquipA/EquipB/EquipL 的候选池只有 3 条。
        #    这里同时钉「短池部位确实存在」—— 否则这条腿抓不到「抄表」这种退化。
        gm = __import__("gm_admin")
        每部位: dict[int, tuple] = {}
        for 原始 in ffs.GAME_DATA_CATALOG.shop_item_ids_by_section().get("ZhuangBei", ()):
            编号 = int(原始)
            if not 101 <= 编号 // 10_000 <= 112:
                continue
            定义 = _装备定义(编号)
            物品 = ffs.GAME_DATA_CATALOG.get_item_definition(编号)
            if 定义 is None or 物品 is None:
                continue
            if int(定义.required_job) not in {0, 300} or int(定义.required_level) > 60:
                continue
            位 = int(定义.position)
            名次 = (int(定义.required_level), int(定义.stage), int(定义.required_job) != 0, 编号)
            if 位 not in 每部位 or 名次 > 每部位[位][0]:
                每部位[位] = (名次, 物品, 定义)
        查(len(每部位) == 12, f"⑬ 60 级职业 300 只凑到 {len(每部位)} 个部位（应 12）")
        短池 = 0
        for 位 in sorted(每部位):
            _名次, 物品, 定义 = 每部位[位]
            件 = ffs.InventoryItem(item_id=int(物品.item_id), slot=位 + 200)
            gm._apply_purple_equipment_profile(ffs, 件, 定义)
            查(件.aptitude == 紫, f"⑬ {物品.name} 资质应 4，实得 {件.aptitude}")
            _核对词条(件, int(物品.item_id), f"⑬ {物品.name}")
            if len(ffs.equipment_plus_stage_rows(定义)) < 6:
                短池 += 1
        查(短池 >= 3,
           f"⑬ 60 级套装里候选池不足 6 条的部位只有 {短池} 个（应 ≥3：EquipA/EquipB/EquipL），这条腿才抓得到抄表退化")

    if 失败:
        for 条 in 失败:
            print("!!! " + 条)
        print(f"亲热天堂3紫装池：{len(失败)} 条不符")
        return 1
    print("亲热天堂3紫装池：通过（4档紫装表 / 6~9星覆盖 / 2、3型不出装 / 等级职业过滤 / 预览&发放同口径 / 重载不丢 / 两槽各活各的 / 奖励与GM紫装各6条词条）")
    return 0


if __name__ == "__main__":
    raise SystemExit(主流程())
