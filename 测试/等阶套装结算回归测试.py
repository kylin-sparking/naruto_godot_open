from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "服务端/runtime/tools"))
import fake_flash_server as g

checks = 0
failures = []


def check(ok, message):
    global checks
    checks += 1
    if not ok:
        failures.append(message)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        s = g.FakeFlashSession.__new__(g.FakeFlashSession)
        s.store = g.SinglePlayerStore(Path(tmp) / "save.json")
        ids = [1010011, 1020010, 1030011, 1040011, 1050011, 1060011,
               1070010, 1080010, 1090010, 1100010, 1110010, 1120010]
        s.store.state.inventory = {
            -i: g.InventoryItem(item_id=item_id, slot=-i, quantity=1, endure=100, base_attr_value=0,
                                plus_attributes=[[2, 100], [7, 20], [4, 10]])
            for i, item_id in enumerate(ids, 1)
        }
        mp, evasion = g.EquipmentAttribute.MAX_MP, g.EquipmentAttribute.EVASION
        check(s._equipped_attribute_bonus(mp) == 1260, "12件查克拉1200+等阶60")
        check(s._equipped_attribute_bonus(evasion) == 252, "12件闪避240+等阶12")
        check(s._equipped_attribute_bonus(g.EquipmentAttribute.ATTACK) == 120, "等阶不加攻击")
        s._base_attribute_bonuses = lambda: {a: 0 for a in g.CultivationAttribute}
        s._growth_attribute_bonuses = lambda: {a: 0 for a in g.CultivationAttribute}
        s._active_skill_buff_value = lambda *a: 0
        s._active_item_parameter = lambda *a: 0
        s._editor_buff_bonus = lambda *a: 0
        s._scale_edo_stat = lambda value: value
        check(s._current_evasion() == 252, "战斗闪避使用等阶后的总值")
        check(s._current_max_mp() == s.character.max_mp + 1260, "查克拉上限使用等阶后的总值")
        item = s.store.state.inventory[-1]
        item.item_id = 1010021
        check(s._equipped_attribute_bonus(mp) == 1200, "混阶取消加成")
        item.item_id = ids[0]
        item.endure = 0
        check(s._equipped_attribute_bonus(mp) == 1100, "损坏装备不能凑成有效套装")
        item.endure = 100
        del s.store.state.inventory[-1]
        item.slot = 1
        s.store.state.inventory[1] = item
        check(s._equipped_attribute_bonus(mp) == 1100, "卸下一件即取消且背包装不计")
        item.slot = -1
        s.store.state.inventory[-1] = s.store.state.inventory.pop(1)
        s.store.state.inventory[-22] = g.InventoryItem(item_id=1410001, slot=-22, endure=100,
                                                     plus_attributes=[[2, 100]])
        check(s._equipped_attribute_bonus(mp) == 1365, "额外已穿装备计入百分比基数、不影响同阶判定")
    for failure in failures:
        print("失败：" + failure)
    print(f"等阶套装结算回归测试：{'失败' if failures else '通过'}（{checks} 条断言）")
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
