# -*- coding: utf-8 -*-
"""意志面板竞态回归测试（2026-10-22，§3.183）——进程内竞态锤。

**钉的 bug**：用户第三次实机报「一键学习/一键拾取/一键卖出点击后没反应」，
服务端 traceback 抓到真凶不是发送链，而是一场**竞态**：

  * 连接线程的 `_pick/_sell_spirit_panel_items` 循环里，
    `spirit_panel_items.pop(p)` 与 `spirit_panel_obtained_at.pop(p)` 是
    **两颗不相邻保护的 pop**（旧实现不持锁）；
  * runtime 线程每 50ms 一跳的 tick（`_run_runtime_loop` → `_runtime_tick` →
    `_expire_spirit_panel_items`）会和它并发跑；
  * tick 一见两表长度不齐就把 `spirit_panel_obtained_at` **截断"修复"**；
  * 它要是落在两颗 pop 之间，挂起的那颗 `obtained_at.pop(p)` 当场越界 ⇒
    IndexError 打死连接线程 ⇒ 客户端「后端：离线」、三钮集体"没反应"。

线上实录（夹具 18699，root `测试/输出/复现夹具`）：
    File "...fake_flash_server.py", line 20853, in _sell_spirit_panel_items
        progression.spirit_panel_obtained_at.pop(position)
    IndexError: pop index out of range

**为什么能当门跑**：不依赖网络/夹具/Godot，纯进程内驱动真实服务端代码
（`SinglePlayerStore` + `FakeFlashSession` 的方法，只桩掉发送）。

**为什么对旧代码确定性红**：把两个面板列表换成 `_竞态放大列表`——
`pop()` 后睡 0.5ms，把两颗 pop 之间的窗口放大（线上那个窗口来自
`_spirit_item_price` 每次全量解码意志表，实测 ≈0.5ms/次；§3.183 给目录加了
缓存后窗口只剩微秒，单靠时序撞不出来，所以这里显式放大）。expire 锤线程
拼命调 `_expire_spirit_panel_items`，旧代码第一轮就撞。

**修复后为什么绿**：`_expire_spirit_panel_items` 整段持 store 锁 +
拾取/卖出循环的成对 pop 持同一把锁 ⇒ tick 永远插不进来。

用法（被 `测试/意志面板竞态回归测试.gd` 调，也可手跑）：
    python 测试/意志面板竞态回归测试.py
退出码：0 = 没撞上竞态；1 = 复现了 IndexError/超时（= 回归）。
"""
from __future__ import annotations

import random
import sys
import tempfile
import threading
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "服务端" / "runtime" / "tools"))

import fake_flash_server as ffs  # noqa: E402

DEADLINE_SECONDS = 60.0
放大窗口秒 = 0.0005
每轮件数 = 3
轮数 = 40


class _竞态放大列表(list):
    """pop 后睡一会：把两颗 pop 之间的窗口放大到亚毫秒级（复现线上撞窗口）。"""

    def pop(self, *args):  # noqa: D102
        值 = super().pop(*args)
        time.sleep(放大窗口秒)
        return 值


def _建会话(根: Path) -> ffs.FakeFlashSession:
    store = ffs.SinglePlayerStore(根 / "save.json")
    会话 = ffs.FakeFlashSession.__new__(ffs.FakeFlashSession)
    会话.store = store
    会话.random = random.Random(20261022)
    会话.send_text = lambda payload: None
    会话._advance_activity = lambda slot, amount=1: None
    会话._broadcast_rare_event = lambda *a, **k: None
    return 会话


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        会话 = _建会话(Path(tmp))
        prog = 会话.store.state.progression
        prog.spirit_npc_status = [1, 0, 0, 0, 0]
        prog.pve_points = 9_999_999
        # 背包上限调到 500：拾取阶段才不会被"包满"挡住（挡住了就没有 pop、
        # 没有窗口，等于没测）。这只是进程内测试状态，不落任何真实存档。
        prog.spirit_pack_limit = 500

        停 = threading.Event()
        命中: list[BaseException] = []
        观测 = {"expire 轮": 0, "见长度不齐": 0}
        观测锁 = threading.Lock()
        截止 = time.monotonic() + DEADLINE_SECONDS

        def 锤过期() -> None:
            # 模仿 runtime 线程的 tick：拼命调 expire（旧实现它只在写回时持锁）
            while not 停.is_set():
                try:
                    前件 = len(prog.spirit_panel_items)
                    前戳 = len(prog.spirit_panel_obtained_at)
                    会话._expire_spirit_panel_items()
                    with 观测锁:
                        观测["expire 轮"] += 1
                        if 前件 != 前戳:
                            观测["见长度不齐"] += 1
                except BaseException as exc:  # noqa: BLE001
                    命中.append(exc)
                    停.set()
                    return

        def 补货() -> None:
            if len(prog.spirit_panel_items) < 5:
                会话._learn_all_spirits()

        def 跑(轮数_: int, 动作) -> None:
            for _ in range(轮数_):
                if 停.is_set() or time.monotonic() >= 截止:
                    return
                try:
                    动作()
                except BaseException as exc:  # noqa: BLE001
                    命中.append(exc)
                    停.set()
                    return
                补货()

        def 尾部位() -> list[int]:
            # ⚠️ 必须挑**尾部**的位置：obtained_at 被 tick 截断后，低位 pop 依然
            # 合法（pop(0) 对 19 元的表没问题），只有高位 pop 才会越界 —— 线上
            # 崩溃与最初那版锤都是 `range(len)` 倒序（从尾部）pop。
            件数 = len(prog.spirit_panel_items)
            return list(range(max(0, 件数 - 每轮件数), 件数))

        def 一键拾取() -> None:
            会话._pick_spirit_panel_items(尾部位())

        def 一键卖出() -> None:
            会话._sell_spirit_panel_items(尾部位(), gray_only=True)

        def 全卖() -> None:
            会话._sell_spirit_panel_items(尾部位())

        # 学满一面板，再把两个列表换成放大版（expire 的写回只在长度不齐时发生，
        # 原子 pop 下永远不会 ⇒ 放大列表不会被普通列表换掉）。
        会话._learn_all_spirits()
        prog.spirit_panel_items = _竞态放大列表(prog.spirit_panel_items)
        prog.spirit_panel_obtained_at = _竞态放大列表(prog.spirit_panel_obtained_at)
        print(f"ready: panel={len(prog.spirit_panel_items)} items, window={放大窗口秒 * 1000:.1f}ms")

        过期线程 = threading.Thread(target=锤过期, name="hammer-expire", daemon=True)
        过期线程.start()
        try:
            跑(轮数, 一键拾取)      # 一键拾取路径
            跑(轮数, 一键卖出)      # 一键卖出（线上崩的这条，gray_only）
            跑(轮数, 全卖)          # 全卖路径
        finally:
            停.set()
            过期线程.join(timeout=5.0)

        print(f"expire hammer: {观测['expire 轮']} rounds, saw length mismatch {观测['见长度不齐']} times")
        if 命中:
            exc = 命中[0]
            print(f"!!! RACE REPRODUCED: {type(exc).__name__}: {exc}")
            print("    (paired pops and expire normalization are not mutually exclusive)")
            return 1
        if time.monotonic() >= 截止:
            print("!!! TIMEOUT: hammer did not finish in time (lock livelock?)")
            return 1
        print("OK: pick/sell ran against concurrent expire hammer, no IndexError, no deadlock")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
