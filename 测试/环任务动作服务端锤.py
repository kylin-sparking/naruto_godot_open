# -*- coding: utf-8 -*-
"""日环 / 周试炼三颗按钮的服务端锤（2026-11-07）。

客户端 `日环任务窗._点立即/_点刷新` 与 `周试炼任务窗._点降/_点提` 现在真发
`QUEST_ACTION(104)` 的 8/9/10；服务端这一段必须和原版一致：

  ① 降难度（8）：难度 > 1、背包有 1 个乾坤密卷才扣 1 并降 1；没材料只提示不扣；
  ② 提回报（9）周：上限 **10** 星、每次扣 1 个乾坤密卷；10 星只提示；
  ③ 提回报（9）日：上限 **5** 星；倒计时没走完收 10 点券/元宝（优先点券）并把
     下次免费时间推到 +600s；倒计时已走完**免费**；
  ④ 立即完成（10）：收 5 点券/元宝，目标填满 → READY(2) → 发闪状态 2 的整条进度
     并走结算；钱不够只提示、状态不动。

纯进程内驱动真 `_handle_ring_quest_action`（`FakeFlashSession.__new__`），结算与
进度广播只记调用（那两段另有门）。由 `测试/富岳两窗回归测试.gd` 调，也可手跑：

    python 测试/环任务动作服务端锤.py

退出码：0 = 全绿；1 = 有断言不符。
"""
from __future__ import annotations

import random
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "服务端" / "runtime" / "tools"))

import fake_flash_server as ffs  # noqa: E402

日模板 = 8003
周模板 = 8004
乾坤密卷 = ffs.RING_ADJUST_ITEM_ID
密卷格 = 1
钱格 = 0

失败: list[str] = []


def 查(条件: bool, 说明: str) -> None:
    if not 条件:
        失败.append(说明)


def _建会话(根: Path) -> ffs.FakeFlashSession:
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = ffs.SinglePlayerStore(根 / "save.json")
    会话.wire_mode = "text"
    会话.发出的帧 = []
    会话.系统话 = []
    会话.全进度 = []
    会话.完成 = []
    会话.send_text = lambda payload: 会话.发出的帧.append(str(payload))
    会话._send_stats = lambda *a, **k: None
    会话._client_base_combat_stats = lambda: {}
    会话._send_system_chat = lambda 话, *a, **k: 会话.系统话.append(str(话))
    会话._send_native_server_message = lambda 话, *a, **k: 会话.系统话.append(str(话))
    会话._send_original_quest_full_progress = (
        lambda d, p, **k: 会话.全进度.append(
            (d.quest_id, ffs.QuestState(p.state).name, k.get("flash_status"))
        )
    )
    会话._refresh_original_quest_progress = lambda d, p: None
    会话._complete_original_quest = lambda *a, **k: 会话.完成.append(True)
    会话.handle_cash_money = lambda *a, **k: None
    会话.store.state.ring_quest_modes = {日模板: "daily", 周模板: "weekly"}
    会话.store.state.coupon_money = 0
    会话.store.state.cash_money = 0
    return 会话


def _建链会话(根: Path) -> ffs.FakeFlashSession:
    """真结算那一支用的会话：**不桩** `_complete_original_quest`（⑫ 量的就是它）。"""
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = ffs.SinglePlayerStore(根 / "链save.json")
    会话.wire_mode = "text"
    会话.发出的帧 = []
    会话.系统话 = []
    会话.send_text = lambda payload: 会话.发出的帧.append(str(payload))
    会话.random = random.Random(7)
    会话._send_stats = lambda *a, **k: None
    会话._client_base_combat_stats = lambda: {}
    会话._send_system_chat = lambda *a, **k: 会话.系统话.append(str(a[0]))
    会话._send_native_server_message = lambda *a, **k: None
    会话._send_inventory_add = lambda *a, **k: None
    会话._send_inventory_update = lambda *a, **k: None
    会话._send_inventory_clear = lambda *a, **k: None
    会话._send_inventory_changes = lambda *a, **k: None
    会话._grant_experience = lambda *a, **k: None
    会话._start_automatic_original_quests = lambda: []
    会话._send_original_can_start_quest_list = lambda: None
    会话._send_original_quest_lists = lambda: None
    会话._trigger_editor_events = lambda *a, **k: None
    会话._send_tutorial_once = lambda *a, **k: None
    会话.npcs = {
        27001: ffs.NpcState(27001, 27, 0, 0, 0, 0, 0, 0, "宇智波富岳", ""),
        39001: ffs.NpcState(39001, 39, 0, 0, 0, 0, 0, 0, "日环交付人", ""),
    }
    会话.character.level = 25
    return 会话


def _铺(
    会话: ffs.FakeFlashSession,
    *,
    难度: int = 5,
    星: int = 1,
    密卷: int = 0,
    点券: int = 0,
    元宝: int = 0,
    免费时刻: int = 0,
) -> ffs.OriginalQuestProgress:
    会话.store.state.inventory = {}
    if 密卷 > 0:
        会话.store.state.inventory[密卷格] = ffs.InventoryItem(
            item_id=乾坤密卷, slot=密卷格, quantity=密卷, unique_id=密卷格,
        )
    会话.store.state.coupon_money = 点券
    会话.store.state.cash_money = 元宝
    进度 = ffs.OriginalQuestProgress(
        state=int(ffs.QuestState.ACTIVE),
        difficulty_level=难度,
        rich_degree=星,
        refresh_available_at=免费时刻,
    )
    会话.发出的帧.clear()
    会话.系统话.clear()
    会话.全进度.clear()
    会话.完成.clear()
    return 进度


def _发(会话: ffs.FakeFlashSession, 模板: int, 动作: ffs.QuestAction) -> None:
    定义 = ffs.GAME_DATA_CATALOG.get_quest_definition(模板)
    assert 定义 is not None, f"任务 {模板} 不在定义表里"
    进度 = 会话.store.state.original_quests.get(模板)
    assert 进度 is not None, f"任务 {模板} 没有进度对象"
    会话._handle_ring_quest_action(定义, 进度, 动作)


def _备(会话: ffs.FakeFlashSession, 模板: int, **铺) -> ffs.OriginalQuestProgress:
    进度 = _铺(会话, **铺)
    会话.store.state.original_quests = {模板: 进度}
    return 进度


def _剩密卷(会话: ffs.FakeFlashSession) -> int:
    return 会话._inventory_item_quantity(乾坤密卷)


def _跑(根: Path) -> None:
    # ── ① 降难度：没材料 ⇒ 拒，难度不动、不广播 ──
    会话 = _建会话(根)
    进度 = _备(会话, 日模板, 难度=5, 密卷=0)
    _发(会话, 日模板, ffs.QuestAction.DECREASE_REQUIREMENT)
    查(进度.difficulty_level == 5, f"① 没密卷不该降难度，实测 {进度.difficulty_level}")
    查(_剩密卷(会话) == 0, "① 没密卷也不该扣出负数")
    查(not 会话.全进度, f"① 被拒不该广播整条进度，实测 {会话.全进度}")
    查(any("乾坤密卷" in 话 for 话 in 会话.系统话), f"① 该提示缺密卷，实测 {会话.系统话}")

    # ── ② 降难度：有材料 ⇒ 扣 1、难度 −1、发清格 + 整条进度 ──
    会话 = _建会话(根)
    进度 = _备(会话, 日模板, 难度=5, 密卷=1)
    _发(会话, 日模板, ffs.QuestAction.DECREASE_REQUIREMENT)
    查(进度.difficulty_level == 4, f"② 有密卷该降 1 级，实测 {进度.difficulty_level}")
    查(_剩密卷(会话) == 0, f"② 该扣掉那 1 个密卷，实测剩 {_剩密卷(会话)}")
    清格前缀 = (f"{ffs.op(ffs.ServerOpcode.MODIFY_INVENTORY_ITEM)}:"
              f"{ffs.op(ffs.InventoryUpdateFlag.CLEAR)}:")
    查(len(会话.发出的帧) == 1 and 会话.发出的帧[0].startswith(清格前缀),
       f"② 扣光一格该发一条清格帧（{清格前缀}…），实测 {会话.发出的帧}")
    查(会话.全进度 == [(日模板, "ACTIVE", None)], f"② 该广播整条进度，实测 {会话.全进度}")

    # ── ③ 降难度：已最小 ⇒ 只提示 ──
    会话 = _建会话(根)
    进度 = _备(会话, 日模板, 难度=1, 密卷=1)
    _发(会话, 日模板, ffs.QuestAction.DECREASE_REQUIREMENT)
    查(进度.difficulty_level == 1 and _剩密卷(会话) == 1,
       f"③ 难度 1 不该扣密卷，实测难度 {进度.difficulty_level} / 密卷 {_剩密卷(会话)}")
    查(any("最低" in 话 for 话 in 会话.系统话), f"③ 该提示已最低，实测 {会话.系统话}")

    # ── ④ 周：9 星 ⇒ 扣 1 密卷、到 10 星 ──
    会话 = _建会话(根)
    进度 = _备(会话, 周模板, 星=9, 密卷=1)
    _发(会话, 周模板, ffs.QuestAction.INCREASE_REWARD_LEVEL)
    查(进度.rich_degree == 10, f"④ 周 9→10 该加 1 星，实测 {进度.rich_degree}")
    查(_剩密卷(会话) == 0, f"④ 周提升该扣 1 个密卷，实测剩 {_剩密卷(会话)}")
    查(会话.全进度 == [(周模板, "ACTIVE", None)], f"④ 该广播整条进度，实测 {会话.全进度}")

    # ── ⑤ 周：10 星封顶 ⇒ 只提示、不扣 ──
    会话 = _建会话(根)
    进度 = _备(会话, 周模板, 星=10, 密卷=1)
    _发(会话, 周模板, ffs.QuestAction.INCREASE_REWARD_LEVEL)
    查(进度.rich_degree == 10 and _剩密卷(会话) == 1,
       f"⑤ 10 星不该再扣，实测星 {进度.rich_degree} / 密卷 {_剩密卷(会话)}")
    查(any("10星" in 话 for 话 in 会话.系统话), f"⑤ 该提示 10 星上限，实测 {会话.系统话}")

    # ── ⑥ 周：没密卷 ⇒ 拒 ──
    会话 = _建会话(根)
    进度 = _备(会话, 周模板, 星=9, 密卷=0)
    _发(会话, 周模板, ffs.QuestAction.INCREASE_REWARD_LEVEL)
    查(进度.rich_degree == 9, f"⑥ 没密卷周提升不该生效，实测 {进度.rich_degree}")
    查(any("乾坤密卷" in 话 for 话 in 会话.系统话), f"⑥ 该提示缺密卷，实测 {会话.系统话}")

    # ── ⑦ 日：倒计时没走完 ⇒ 收 10 点券、+600s ──
    会话 = _建会话(根)
    现在 = int(time.time())
    进度 = _备(会话, 日模板, 星=4, 点券=100, 免费时刻=现在 + 300)
    _发(会话, 日模板, ffs.QuestAction.INCREASE_REWARD_LEVEL)
    查(进度.rich_degree == 5, f"⑦ 日 4→5 该加 1 星，实测 {进度.rich_degree}")
    查(会话.store.state.coupon_money == 90, f"⑦ 该收 10 点券，实测 {会话.store.state.coupon_money}")
    查(abs(进度.refresh_available_at - (int(time.time()) + 600)) <= 2,
       f"⑦ 免费时刻该推到约 +600s，实测 {进度.refresh_available_at - int(time.time())}s")
    查(not 会话.发出的帧, f"⑦ 日提升不扣背包，不该发库存帧，实测 {会话.发出的帧}")

    # ── ⑧ 日：倒计时已走完 ⇒ 免费，不扣钱 ──
    会话 = _建会话(根)
    进度 = _备(会话, 日模板, 星=1, 点券=100, 元宝=100, 免费时刻=int(time.time()) - 1)
    _发(会话, 日模板, ffs.QuestAction.INCREASE_REWARD_LEVEL)
    查(进度.rich_degree == 2, f"⑧ 免费刷新该加 1 星，实测 {进度.rich_degree}")
    查(会话.store.state.coupon_money == 100 and 会话.store.state.cash_money == 100,
       f"⑧ 免费支不该扣钱，实测点券 {会话.store.state.coupon_money} / 元宝 {会话.store.state.cash_money}")

    # ── ⑨ 日：5 星封顶（不是周那个 10）──
    会话 = _建会话(根)
    进度 = _备(会话, 日模板, 星=5, 点券=100)
    _发(会话, 日模板, ffs.QuestAction.INCREASE_REWARD_LEVEL)
    查(进度.rich_degree == 5 and 会话.store.state.coupon_money == 100,
       f"⑨ 日 5 星封顶，实测星 {进度.rich_degree} / 点券 {会话.store.state.coupon_money}")
    查(any("5星" in 话 for 话 in 会话.系统话), f"⑨ 该提示 5 星上限，实测 {会话.系统话}")

    # ── ⑩ 立即完成：收 5、目标填满、READY(2)、广播 + 结算 ──
    会话 = _建会话(根)
    进度 = _备(会话, 日模板, 点券=12)
    定义 = ffs.GAME_DATA_CATALOG.get_quest_definition(日模板)
    _发(会话, 日模板, ffs.QuestAction.COMPLETE_LOOP)
    查(会话.store.state.coupon_money == 7, f"⑩ 该收 5 点券，实测 {会话.store.state.coupon_money}")
    查(进度.state == int(ffs.QuestState.READY_TO_COMPLETE), f"⑩ 状态该转 2，实测 {进度.state}")
    查(all(值 > 0 for 值 in 进度.progress.values()) and 进度.progress,
       f"⑩ 目标该被填满，实测 {进度.progress}")
    查(会话.全进度 == [(日模板, "READY_TO_COMPLETE", 2)],
       f"⑩ 该以 flash_status=2 广播，实测 {会话.全进度}")
    查(会话.完成 == [True], f"⑩ 该走结算，实测 {会话.完成}")

    # ── ⑪ 立即完成：钱不够 ⇒ 拒、状态不动、不结算 ──
    会话 = _建会话(根)
    进度 = _备(会话, 日模板, 点券=4)
    _发(会话, 日模板, ffs.QuestAction.COMPLETE_LOOP)
    查(进度.state == int(ffs.QuestState.ACTIVE), f"⑪ 钱不够不该转状态，实测 {进度.state}")
    查(会话.store.state.coupon_money == 4, "⑪ 钱不够不该扣出负数")
    查(not 会话.全进度 and not 会话.完成, f"⑪ 被拒不该广播/结算，实测 {会话.全进度} {会话.完成}")
    查(any("不足" in 话 for 话 in 会话.系统话), f"⑪ 该提示钱不足，实测 {会话.系统话}")

    # ── ⑫ 交完一环：下一环自动接上、推包装 8001、富岳 513 变进行中(3) ──
    # ⑩ 桩掉了 `_complete_original_quest`，所以这里用**真结算**另起一炉：
    # 用户报的「交完不接下一环 / 富岳还是感叹号」就落在这一段。
    会话 = _建链会话(根)
    会话.store.state.original_quests = {
        日模板: ffs.OriginalQuestProgress(
            state=int(ffs.QuestState.READY_TO_COMPLETE), finish_count=0,
        )
    }
    会话.store.state.ring_quest_modes = {日模板: "daily"}
    会话.store.state.ring_daily_count = 0
    会话.store.state.ring_active_mode = "daily"
    定义 = ffs.GAME_DATA_CATALOG.get_quest_definition(日模板)
    查(会话._complete_original_quest(定义, 定义.end_npc_id),
       "⑫ 交付到正确 NPC 该落账")
    查(会话.store.state.ring_daily_count == 1,
       f"⑫ 今日完成数该 +1，实测 {会话.store.state.ring_daily_count}")
    下一环 = [
        q for q, p in 会话.store.state.original_quests.items()
        if q != 日模板 and int(p.state) == int(ffs.QuestState.ACTIVE)
    ]
    查(len(下一环) == 1,
       f"⑫ 该自动接上正好一条下一环（ACTIVE），实测 {会话.store.state.original_quests}")
    if len(下一环) == 1:
        查(会话.store.state.ring_quest_modes.get(下一环[0]) == "daily",
           f"⑫ 下一环该归日环模式，实测 {会话.store.state.ring_quest_modes}")
    帧 = 会话.发出的帧
    查(any(f.startswith(f"{ffs.op(ffs.ServerOpcode.SHOW_STATUS_INFO)}:1:8001:1:0") for f in 帧),
       f"⑫ 该推包装 8001 的接取通知（42:1:8001:1:0），实测 {帧[:6]}")
    查(any(f.startswith(f"{ffs.op(ffs.ServerOpcode.QUEST_INFO_UPDATE)}:2:8001:1:") for f in 帧),
       f"⑫ 该推 444:2 让开着的那扇窗换到新任务，实测 {帧[:6]}")
    查("513:27001:3" in 帧,
       "⑫ 交完一环后富岳该变进行中问号（513:27001:3），实测 513 帧 "
       + str([f for f in 帧 if f.startswith("513:")]))


def main() -> int:
    with tempfile.TemporaryDirectory() as 临时:
        _跑(Path(临时))
    if 失败:
        for 行 in 失败:
            print("!!! " + 行)
        print(f"环任务动作服务端锤：红 {len(失败)} 条")
        return 1
    print("环任务动作服务端锤：通过（降难度扣密卷 / 周10星 / 日5星与免费刷新 / 完成扣5 / 交完自动接下一环）")
    return 0


if __name__ == "__main__":
    sys.exit(main())