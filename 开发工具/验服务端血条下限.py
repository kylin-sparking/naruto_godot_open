# -*- coding: utf-8 -*-
"""验服务端怪物血量百分比：活着时不得下发 0%（客户端把 0% 当死亡）。

背景（2026-10-26 实机 1342「终极艺术」）：2000020 还剩 3166/796646 = 0.4%，
服务端用 round 下发 0% ⇒ 客户端按原版 MonsterHandler.showMobHp 立刻 _服务端死亡，
最后一刀再也发不出去 ⇒ 服务端收不到击杀 ⇒ 任务永远 0/1。
"""
from __future__ import annotations

import io
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(根, "开发工具"))
import 服务端目录  # noqa: E402

f = 服务端目录.加载模块("fake_flash_server")

坏 = 0
用例 = [
    (3166, 796646, 1),
    (1, 796646, 1),
    (0, 796646, 0),
    (796646, 796646, 100),
    (398323, 796646, 50),
    (398324, 796646, 51),
]
for 血, 满, 期望 in 用例:
    怪 = f.MonsterState(object_id=1, template_id=2000020, max_hp=满, hp=血)
    得 = f.FakeFlashSession._monster_hp_percent(怪)
    过 = 得 == 期望
    print(("OK  " if 过 else "BAD ") + "hp=%d/%d got=%d exp=%d" % (血, 满, 得, 期望))
    if not 过:
        坏 += 1

源 = io.open(os.path.join(根, "服务端", "runtime", "tools", "fake_flash_server.py"),
             encoding="utf-8").read()
旧式 = 源.count("round(monster.hp * 100 / monster.max_hp)") \
    + 源.count("round(actor.hp * 100 / actor.max_hp)")
print("old_round_sites =", 旧式)
if 旧式:
    坏 += 1
公式 = "max(1, int(math.ceil(monster.hp * 100.0 / monster.max_hp)))"
print("helper_formula_present =", 公式 in 源)
if 公式 not in 源:
    坏 += 1

print("RESULT", "PASS" if 坏 == 0 else "FAIL", "bad=%d" % 坏)
raise SystemExit(0 if 坏 == 0 else 1)
