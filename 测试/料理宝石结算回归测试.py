from __future__ import annotations

import itertools
import random
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "服务端/runtime/tools"))
import fake_flash_server as game

checks = 0
failures: list[str] = []


def check(condition, message):
    global checks
    checks += 1
    if not condition:
        failures.append(message)


def session(path):
    s = game.FakeFlashSession.__new__(game.FakeFlashSession)
    s.store = game.SinglePlayerStore(path / "save.json")
    s.random = random.Random(7)
    s.wire_mode = "text"
    s.frames = []
    s.messages = []
    s.send_text = lambda text: s.frames.append(str(text))
    s._send_system_chat = lambda text, *a, **k: s.messages.append(text)
    s._send_stats = lambda values: s.frames.append(f"money:{s.store.state.money}")
    s._send_inventory_add = lambda item, **k: s.frames.append(f"add:{item.slot}:{item.item_id}:{item.quantity}")
    s._send_inventory_update = lambda item, **k: s.frames.append(f"update:{item.slot}:{item.item_id}:{item.quantity}")
    s._send_inventory_clear = lambda slot, *a: s.frames.append(f"clear:{slot}")
    s.pending_equipment_pickups = set()
    return s


def seed(s, items, money=1000000, capacity=90):
    s.store.state.inventory = {
        slot: game.InventoryItem(item_id=item_id, slot=slot, quantity=quantity, unique_id=slot)
        for slot, item_id, quantity in items
    }
    s.store.state.money = money
    s.store.state.bag_capacity = capacity
    s.frames.clear()
    s.messages.clear()


def cooking(s):
    for a, b in itertools.combinations(range(16010001, 16010013), 2):
        seed(s, [(1, a, 2), (2, b, 2)])
        result = game.GAME_DATA_CATALOG.cooking_result(a, b)
        check(15003016 <= result <= 15003039, f"料理 {a}+{b} 必须产出配置内料理，实得 {result}")
        check(result == game.GAME_DATA_CATALOG.cooking_result(b, a), f"料理交换次序 {a}+{b}")
        s.handle_buff_he_cheng('1822:1:{"item0":1,"item1":2}')
        check(bool(s.frames) and s.frames[-1] == f"1822:2:{result}", f"料理回帧 {a}+{b}: {s.frames}")
        check(s.store.state.inventory[1].quantity == 1 and s.store.state.inventory[2].quantity == 1, "双槽各扣一份")
        check(s.store.state.money == 998000, "料理扣2000金币")
        check(sum(i.quantity for i in s.store.state.inventory.values() if i.item_id == result) == 1, "料理入包一份")
    check(game.GAME_DATA_CATALOG.cooking_result(16010001, 16010002) == 15003033, "保留旧有效配方香蕉+鲜虾")
    check(game.GAME_DATA_CATALOG.cooking_result(16010001, 16010004) == 15003016, "无共享节点的有效食材也必成")
    for items, money, capacity in [
        ([(1, 16010001, 2), (2, 16010001, 2)], 1000000, 90),
        ([(1, 16010001, 2), (2, 16000011, 2)], 1000000, 90),
        ([(1, 16010001, 2), (2, 16019999, 2)], 1000000, 90),
        ([(1, 16010001, 2), (2, 16010002, 2)], 1999, 90),
        ([(1, 16010001, 2), (2, 16010002, 2)], 1000000, 2),
        ([(1, 16010001, 2), (2, 16010002, 2), (3, 15003033, 9999)], 1000000, 3),
    ]:
        seed(s, items, money, capacity)
        s.handle_buff_he_cheng("1822:1:1:2")
        check(s.frames == ["1822:2:0"], f"无效制作不发库存帧: {s.frames}")
        check(s.store.state.money == money and [(i.slot, i.item_id, i.quantity) for i in s.store.state.inventory.values()] == items, "拒绝制作不得扣钱料")
    seed(s, [(1, 16010001, 1), (2, 16010002, 2)], capacity=2)
    s.handle_buff_he_cheng("1822:1:1:2")
    check(bool(s.frames) and s.frames[-1] == "1822:2:15003033", "满包但原料耗尽腾格应成功")


def stones(s):
    stone, result = 13000000, 13000001
    check(game.GAME_DATA_CATALOG.get_stone_inlay(result) is not None, "一级宝石后继存在")
    # 失败批次回收两颗、退还一颗（原版 `EQUIP_STONE_COMPOSITE_DESCS_1`「合成失败则回收两颗
    # 宝石，退还一颗宝石」）⇒ 剩余 = 余料 + 失败批数，1042 的"剩余"位报这个真实堆叠数。
    for count, rolls, successes in [(11, [True, False, True], 2), (9, [True] * 3, 3), (9, [False] * 3, 0), (3, [True], 1)]:
        seed(s, [(1, stone, count)])
        outcomes = iter(rolls)
        s._roll_forge = lambda *args: next(outcomes)
        s.handle_item_change("1040:0:1")
        batches, remainder = divmod(count, 3)
        failed = batches - successes
        left = remainder + failed
        check(sum(i.quantity for i in s.store.state.inventory.values() if i.item_id == stone) == left, f"整摞 {count} 失败 {failed} 批应退 {failed} 颗、只余 {left}")
        check(sum(i.quantity for i in s.store.state.inventory.values() if i.item_id == result) == successes, f"整摞成功数 {successes}")
        check(s.store.state.money == 1000000 - 800 * batches, f"整摞按批数扣金币 {batches}")
        check(bool(s.frames) and s.frames[-1] == f"1042:{successes}:{result if successes else 0}:2:{failed}:{stone}:1:{left}:{stone}:1", f"整摞汇总回帧: {s.frames}")
    for count, money in [(2, 1000000), (9, 2399)]:
        seed(s, [(1, stone, count)], money=money)
        s.handle_item_change("1040:0:1")
        check(s.store.state.inventory[1].quantity == count and s.store.state.money == money, "数量或金币不足不消耗")
        check(not s.frames, "拒绝合成不发变更帧")
    seed(s, [(1, stone, 9)], capacity=1)
    s._roll_forge = lambda *args: True
    s.handle_item_change("1040:0:1")
    check(s.store.state.inventory[1].item_id == result and s.store.state.inventory[1].quantity == 3, "满包整除可复用源格")
    seed(s, [(1, stone, 11)], capacity=1)
    s.handle_item_change("1040:0:1")
    check(s.store.state.inventory[1].quantity == 11 and not s.frames, "满包有余料必须先拒绝")
    seed(s, [(1, stone, 11), (2, result, 7)], capacity=2)
    s.handle_item_change("1040:0:1")
    check(s.store.state.inventory[2].quantity == 10, "批量成品叠入已有堆")


def main():
    with tempfile.TemporaryDirectory() as tmp:
        s = session(Path(tmp))
        cooking(s)
        stones(s)
    for failure in failures:
        print("失败：" + failure)
    print(f"料理宝石结算回归测试：{'失败' if failures else '通过'}（{checks} 条断言，红 {len(failures)}）")
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
