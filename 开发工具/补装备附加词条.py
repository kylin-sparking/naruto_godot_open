#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给**玩档里已经发出的**人物紫装补足附加词条（2026-10-31 §3.338）。

背景（用户报修）：「上次你给的紫装，武器、手套词条数量不对，只有3条；亲热天堂紫装的
词条数量也不对，似乎没有附带词条；」—— 两处服务端生成逻辑都已修好，但**已经进包的**
那几件不会自己长词条，需要就地补。

口径：
* 只动**人物装备部位 EquipA..EquipL**（部位 -1..-12）的背包/已穿件；
  玉链（EquipS1）、徽章、灵器、忍具、昆虫、宠物装备、变身卡各有自己的属性来源，**不碰**；
* 目标条数 = `equipment_plus_attribute_count(aptitude)` = `min(6, 品质+2)`；
* **保留已有行**，只按「该部位 plus 池」补缺的那些（类型可重复，数值在各自区间）；
* 补出来的行会被门 `测试/亲热天堂3紫装池回归测试.py` 的同一套核对函数验一遍。

硬规矩同 `发放60级紫装.py`：
1. **夹具必须停**（探 18684，通就退出）—— 夹具内存里那份会在下次 `store.save()` 把改动盖回去；
2. 改前**带时间戳逐字节备份**角色档；
3. `--dry-run` 只报不改。

用法（仓库根，夹具停掉后）：
    python -X utf8 开发工具/补装备附加词条.py --root .fixture-play --dry-run
    python -X utf8 开发工具/补装备附加词条.py --root .fixture-play
"""

import argparse
import json
import random
import shutil
import socket
import sys
import time
from pathlib import Path

项目根 = Path(__file__).resolve().parent.parent
人物部位类型 = {"Equip" + 字 for 字 in "ABCDEFGHIJKL"}


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
        (项目根 / ".scratch" / "_out" / "补装备附加词条.txt").write_text(
            "\n".join(报告) + "\n", encoding="utf-8"
        )

    if 端口被占(参数.port):
        说(
            "中止：%d 端口有人听 —— 夹具（或正在玩的客户端）还活着，此刻改存档会被它内存里那份盖回去。"
            % 参数.port
        )
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
    目录 = 服务端.GAME_DATA_CATALOG

    商店, _, 会话 = gm._store(角色编号)
    if 会话 is not None:
        说("中止：角色处于在线会话里（夹具没停干净），改档会被内存覆盖。")
        落盘()
        return 1

    待补 = []
    with 商店.lock:
        for 槽, 件 in 商店.state.inventory.items():
            定义 = 目录.get_equipment_definition(int(件.item_id))
            if 定义 is None or 定义.type_name not in 人物部位类型:
                continue
            想要 = 服务端.equipment_plus_attribute_count(int(件.aptitude), None)
            已有 = len(件.plus_attributes or [])
            if 想要 <= 已有:
                continue
            待补.append((int(槽), 件, 定义, 想要, 已有))

        说("角色 %d：需要补词条的人物装备 %d 件。" % (角色编号, len(待补)))
        for 槽, 件, 定义, 想要, 已有 in 待补:
            物品 = 目录.get_item_definition(int(件.item_id))
            说(
                "  槽 %-4d %-9s %-12s 部位 %-6s 品质 %d 词条 %d→%d"
                % (槽, 件.item_id, 物品.name, 定义.type_name, 件.aptitude, 已有, 想要)
            )

        if 参数.dry_run:
            说("dry-run：未读改存档，也没留备份。")
            落盘()
            return 0
        if not 待补:
            说("没有需要补的件。")
            落盘()
            return 0

        备份 = 角色档.with_name(
            "%s.bak-%s" % (角色档.name, time.strftime("%Y%m%d-%H%M%S"))
        )
        shutil.copyfile(角色档, 备份)
        说("备份 %s（%d 字节）" % (备份.name, 备份.stat().st_size))

        掷 = random.Random()
        for 槽, 件, 定义, 想要, 已有 in 待补:
            补 = 服务端.roll_equipment_plus_attributes(定义, 想要 - 已有, 掷)
            if len(补) != 想要 - 已有:
                说(
                    "!! 槽 %d %s 只掷出 %d 条（要 %d），跳过这件"
                    % (槽, 件.item_id, len(补), 想要 - 已有)
                )
                continue
            件.plus_attributes = [list(行) for 行 in (件.plus_attributes or [])] + 补
            说("  槽 %-4d %-9s 补 %d 条 %s" % (槽, 件.item_id, len(补), 补))
        商店.save()

    新档 = json.loads(角色档.read_text(encoding="utf-8"))
    说("落档核对：")
    错 = 0
    for 槽, 件, 定义, 想要, 已有 in 待补:
        存 = 新档["inventory"].get(str(槽))
        条数 = len(存.get("plus_attributes") or []) if 存 else -1
        说(
            "  槽 %-4d 词条 %d 条（要 %d）%s"
            % (槽, 条数, 想要, "" if 条数 == 想要 else "  ← 不符")
        )
        if 条数 != 想要:
            错 += 1
    落盘()
    return 1 if 错 else 0


if __name__ == "__main__":
    raise SystemExit(main())
