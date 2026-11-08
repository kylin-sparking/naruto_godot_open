#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给**玩档**发一整套 **60 级紫色装备**（12 个部位各一件），用于实机点「装备打造」面板。

和 `发放实测道具.py` 同一套硬规矩：
1. **夹具必须停**（探 18684，通就退出）—— 夹具内存里那份会在下次 `store.save()` 把改动整份盖回去；
2. 发放前**带时间戳逐字节备份**角色档；
3. 装备 id 不手抄：按 `数据/物品.json` + `EquipmentDefinition` 现选 ——
   `position`（1..12 部位）× `required_level <= 60` × 职业兼容（`0 / 本职业 / 同族`）里取最高那一件。

品质口径：**紫 = `aptitude 4`**（服务端 `gm_admin._apply_purple_equipment_profile` 与
`_forge_change_to_orange` 的判据一致），由它按**部位候选池逐条抽满 6 条**附加词条
（池里只有 3~4 种类型，允许重复 —— 直接抄表的话武器/手套/斗篷只会出 3 条，见 §3.338）。
星级（`strength_level`）保持 **0**：用户只要"60 级紫装"；要试「打造为橙装」那句话
（只收 60 级以上紫色 **10 星**）时再单独升星。

用法（仓库根，夹具停掉后）：
    python -X utf8 开发工具/发放60级紫装.py --root .fixture-play --dry-run
    python -X utf8 开发工具/发放60级紫装.py --root .fixture-play
"""

import argparse
import json
import shutil
import socket
import sys
import time
from pathlib import Path

项目根 = Path(__file__).resolve().parent.parent
目标等级 = 60


def 指向隔离存档(root: Path, port: int) -> None:
    import os
    os.environ["NARUTO_MULTIPLAYER_ROOT"] = str(root / "multiplayer")
    os.environ["NARUTO_SAVE_PATH"] = str(root / "save.json")
    os.environ["NARUTO_SERVER_PORT"] = str(port)
    os.environ["NARUTO_NATIVE_LOGIN_PORT"] = str(port)
    os.environ["NARUTO_CHANNEL_PORT"] = str(port)


def 端口被占(port: int) -> bool:
    with socket.socket() as 探测:
        探测.settimeout(0.5)
        return 探测.connect_ex(("127.0.0.1", port)) == 0


def 读角色编号(root: Path) -> int:
    状态 = root / "state.json"
    if 状态.is_file():
        数据 = json.loads(状态.read_text(encoding="utf-8"))
        for 键 in ("main_character_id", "character_id", "characterId"):
            if 数据.get(键):
                return int(数据[键])
    return 0


def 选套装(服务端, 职业: int) -> list:
    """每个 `position` 取一件：`required_level <= 60`、职业兼容里等级/阶最高的那件。"""
    家族 = (int(职业) // 100) * 100 if int(职业) >= 100 else int(职业)
    相容 = {0, int(职业), 家族}
    目录 = 服务端.GAME_DATA_CATALOG
    每部位: dict = {}
    for 原始 in 目录.shop_item_ids_by_section().get("ZhuangBei", ()):
        编号 = int(原始)
        if not 101 <= 编号 // 10_000 <= 112:
            continue
        装备 = 目录.get_equipment_definition(编号)
        物品 = 目录.get_item_definition(编号)
        if 装备 is None or 物品 is None:
            continue
        if int(装备.required_job) not in 相容 or int(装备.required_level) > 目标等级:
            continue
        位 = int(装备.position)
        名次 = (int(装备.required_level), int(装备.stage), int(装备.required_job) != 0, 编号)
        if 位 not in 每部位 or 名次 > 每部位[位][0]:
            每部位[位] = (名次, 物品, 装备)
    return [每部位[位] for 位 in sorted(每部位)]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    解析 = argparse.ArgumentParser()
    解析.add_argument("--root", required=True)
    解析.add_argument("--port", type=int, default=18684)
    解析.add_argument("--character-id", type=int, default=0)
    解析.add_argument("--dry-run", action="store_true")
    参数 = 解析.parse_args()

    root = Path(参数.root)
    报告 = []

    def 说(文本: str) -> None:
        报告.append(文本)
        print(文本)

    def 落盘() -> None:
        (项目根 / ".scratch" / "_out" / "发放60级紫装.txt").write_text(
            "\n".join(报告) + "\n", encoding="utf-8")

    if 端口被占(参数.port):
        说("中止：%d 端口有人听 —— 夹具（或正在玩的客户端）还活着，此刻改存档会被它内存里那份盖回去。"
           % 参数.port)
        落盘()
        return 1

    角色编号 = 参数.character_id or 读角色编号(root)
    if 角色编号 <= 0:
        说("拿不到角色编号：用 --character-id 指定")
        落盘()
        return 1
    角色档 = root / "multiplayer" / "characters" / ("%d.json" % 角色编号)
    if not 角色档.is_file():
        说("角色档不存在：%s" % 角色档)
        落盘()
        return 1

    指向隔离存档(root, 参数.port)
    sys.path.insert(0, str(项目根 / "开发工具"))
    import 服务端目录
    gm = 服务端目录.加载模块("gm_admin")
    服务端 = 服务端目录.加载模块("fake_flash_server")

    原档 = json.loads(角色档.read_text(encoding="utf-8"))
    职业 = int(原档["character"].get("job", 0))
    套装 = 选套装(服务端, 职业)
    说("角色 %d（职业 %d），选到 %d 件 60 级紫色装备：" % (角色编号, 职业, len(套装)))
    for _名次, 物品, 装备 in 套装:
        说("  部位 %-3s %-8s %-12s lv%-3s 阶%s job%s %s"
           % (装备.position, 物品.item_id, 物品.name, 装备.required_level,
              装备.stage, 装备.required_job, 装备.type_name))
    if len(套装) != 12:
        说("中止：应凑齐 12 个部位，实际 %d 件（不拿残缺套装去测面板）" % len(套装))
        落盘()
        return 1

    背包 = {int(格) for 格 in 原档.get("inventory", {}) if int(格) > 0}
    容量 = int(原档.get("bag_capacity", 0))
    说("背包占用 %d / %d，空闲 %d 格" % (len(背包), 容量, 容量 - len(背包)))
    if 容量 - len(背包) < len(套装):
        说("中止：背包空位不足 %d 格" % len(套装))
        落盘()
        return 1

    if 参数.dry_run:
        说("dry-run：未读改存档，也没留备份。")
        落盘()
        return 0

    备份 = 角色档.with_name("%s.bak-%s" % (角色档.name, time.strftime("%Y%m%d-%H%M%S")))
    shutil.copyfile(角色档, 备份)
    说("备份 %s（%d 字节）" % (备份.name, 备份.stat().st_size))

    商店, _, 会话 = gm._store(角色编号)
    发放 = []
    with 商店.lock:
        for _名次, 物品, 装备 in 套装:
            if 会话 is not None:
                件, _新建 = 会话._add_inventory_item(int(物品.item_id), 1)
            else:
                件 = gm._add_offline_item(服务端, 商店, int(物品.item_id), 1)
            gm._apply_purple_equipment_profile(服务端, 件, 装备)
            发放.append(件)
        正文 = "GM向您发放了60级紫色装备一整套，共%d件，已放入背包。" % len(发放)
        gm._append_notification_locked(商店, kind="equipment", title="GM紫装发放", body=正文)
        商店.save()
    说("发放 %d 件。" % len(发放))

    新档 = json.loads(角色档.read_text(encoding="utf-8"))
    说("落档核对：")
    for 件 in 发放:
        存 = 新档["inventory"].get(str(件.slot))
        说("  槽 %-4s %-12s aptitude=%s 附加词条 %s 条 星级=%s"
           % (件.slot, 服务端.GAME_DATA_CATALOG.get_item_definition(int(件.item_id)).name,
              存.get("aptitude") if 存 else "?",
              len(存.get("plus_attributes") or []) if 存 else "?",
              存.get("strength_level") if 存 else "?"))
    正格 = {int(格) for 格 in 新档["inventory"] if int(格) > 0}
    说("背包占用 %d / %d" % (len(正格), 容量))
    落盘()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
