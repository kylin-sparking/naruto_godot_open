# -*- coding: utf-8 -*-
"""验服务端背包容量：读档补成整页、扩充按整页加；仓库保持原版 +30。

背景（2026-10-31，用户两次报「背包面板上方的占用数/总不对」）：
玩家档 `bag_capacity = 308` —— 30 / 128 / 100 几代页宽攒出来的尾巴。界面现在
90 格/页（10 列 x 9 行），308 在第 4 页只占 38 格，标题写 /308 跟「4 页 x 90」对不上。
两条口径：

* 读档：`page_aligned_capacity` 把存量向上补满当前页（308→360、128→180，封顶 810）；
* 扩充：`expanded_capacity(page_aligned=True)` 同样补齐（308→360、360→450）。

仓库不归一：原版 96 基数本来就带 6 格尾页，逐档 +30（96→126→…→246）才是原版。
算法唯一实现都在 `fake_flash_server`，本锤直接打它。
"""
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(根, "开发工具"))
import 服务端目录  # noqa: E402

f = 服务端目录.加载模块("fake_flash_server")

坏 = 0

# ── ① 纯函数：扩充一档 ────────────────────────────────────────────────────
用例 = [
    # (current, page_size, maximum, page_aligned, 期望, 说明)
    (90, 90, 810, True, 180, "整页 ⇒ 加一整页"),
    (180, 90, 810, True, 270, "整页 ⇒ 加一整页"),
    (270, 90, 810, True, 360, "整页 ⇒ 加一整页"),
    (308, 90, 810, True, 360, "旧档尾巴 308 ⇒ 补齐本页到 360（不是 398）"),
    (350, 90, 810, True, 360, "半页 ⇒ 补齐本页"),
    (800, 90, 810, True, 810, "接近上限 ⇒ 夹到 810"),
    (810, 90, 810, True, 810, "上限不动"),
    (0, 90, 810, True, 90, "空档 ⇒ 一页"),
    (96, 30, 246, False, 126, "仓库原版 96 基数 ⇒ +30（尾页 6 格是原版行为，不许页对齐）"),
    (126, 30, 246, False, 156, "仓库逐档 +30"),
    (216, 30, 246, False, 246, "仓库最后一档夹到上限"),
    (246, 30, 246, False, 246, "仓库上限不动"),
]
for 当前, 页宽, 上限, 对齐, 期望, 说明 in 用例:
    得 = f.expanded_capacity(当前, 页宽, maximum=上限, page_aligned=对齐)
    过 = 得 == 期望
    print(("OK  " if 过 else "BAD ") + "%s：current=%d ⇒ %d（期望 %d）" % (说明, 当前, 得, 期望))
    if not 过:
        坏 += 1

# ── ② 纯函数：读档把存量补成整页（背包专用）────────────────────────────────
读档用例 = [
    (308, 360, "旧档 308 ⇒ 补满第 4 页 360"),
    (128, 180, "128 格/页时代的 128 ⇒ 180"),
    (350, 360, "半页 350 ⇒ 360"),
    (360, 360, "整页不动"),
    (800, 810, "接近上限 ⇒ 810"),
    (810, 810, "上限不动"),
    (1, 90, "低于一页 ⇒ 一页 90"),
    (0, 90, "空档 ⇒ 一页 90"),
    (1000, 810, "超上限 ⇒ 夹到 810"),
]
for 原文, 期望, 说明 in 读档用例:
    得 = f.page_aligned_capacity(原文, f.BAG_PAGE_SIZE,
                                 minimum=f.DEFAULT_BAG_CAPACITY,
                                 maximum=f.MAX_BAG_CAPACITY)
    过 = 得 == 期望
    print(("OK  " if 过 else "BAD ") + "%s：%d ⇒ %d（期望 %d）" % (说明, 原文, 得, 期望))
    if not 过:
        坏 += 1

# ── ③ 端到端：真读档入口 `SinglePlayerState.from_dict` 也要归一 ─────────────
# 只打纯函数的话，`from_dict` 忘了调它照样全绿 —— 而玩家看到的总格数正是读档这一跳来的。
for 原文, 期望, 说明 in 读档用例:
    得 = f.SinglePlayerState.from_dict({"bag_capacity": 原文}).bag_capacity
    过 = 得 == 期望
    print(("OK  " if 过 else "BAD ") + "from_dict %s：%d ⇒ %d（期望 %d）" % (说明, 原文, 得, 期望))
    if not 过:
        坏 += 1

# 仓库读档不归一：96 基数的 6 格尾页是原版行为。
仓库得 = f.SinglePlayerState.from_dict({"bag_capacity": 90, "storage_capacity": 96}).storage_capacity
print(("OK  " if 仓库得 == 96 else "BAD ") + "from_dict 仓库 96 ⇒ %d（期望 96，不许补页）" % 仓库得)
if 仓库得 != 96:
    坏 += 1

# ── ④ 端到端：把 `_extend_item_capacity` 整条跑一遍（386 之外的东西全假）──────
# 只打纯函数的话，调用点写错（`page_aligned=not storage` 被改掉）它照样全绿 ——
# 那正是 S1/S2 两条反向对照要抓的，所以这里必须走真 handler。
import threading  # noqa: E402
from types import SimpleNamespace  # noqa: E402


class 假库:
    def __init__(self, 状态):
        self.state = 状态
        self.lock = threading.Lock()
        self.存档数 = 0

    def save(self):
        self.存档数 += 1


def 跑一次扩容(当前: int, *, storage: bool):
    状态 = SimpleNamespace(bag_capacity=当前, storage_capacity=当前)
    库 = 假库(状态)
    发帧: list[str] = []
    话: list[str] = []
    会话 = object.__new__(f.FakeFlashSession)
    会话.store = 库
    会话._send_system_chat = lambda 文: 话.append(文)
    会话._inventory_item_quantity = lambda 物: 10 ** 9
    会话._consume_inventory_quantity = lambda 物, 数: []
    会话._send_inventory_clear = lambda *a, **k: None
    会话._send_inventory_update = lambda *a, **k: None
    会话.send_text = lambda 文: 发帧.append(文)
    会话._extend_item_capacity(storage=storage)
    return (状态.storage_capacity if storage else 状态.bag_capacity), 发帧, 话, 库.存档数


for 当前, storage, 期望, 说明 in [
    (308, False, 360, "背包 308（旧档尾巴）⇒ 360，容量帧也必须是 360"),
    (90, False, 180, "背包 90 ⇒ 180"),
    (360, False, 450, "背包整页 360 ⇒ 450"),
    (96, True, 126, "仓库 96 ⇒ 126（原版 +30，不许页对齐）"),
    (216, True, 246, "仓库 216 ⇒ 246（到上限）"),
]:
    得, 发帧, 话, 存档数 = 跑一次扩容(当前, storage=storage)
    过 = 得 == 期望 and any(t.endswith(":%d" % 期望) for t in 发帧) and 存档数 == 1
    print(("OK  " if 过 else "BAD ")
          + "%s：capacity=%d，帧=%s，存档 %d 次" % (说明, 得, 发帧, 存档数))
    if not 过:
        坏 += 1

# ── ⑤ 源里口径钉：扩充走 helper、仓库不对齐、旧的硬加写法不许回来 ────────────
源 = open(os.path.join(根, "服务端", "runtime", "tools", "fake_flash_server.py"),
          encoding="utf-8").read()


def 钉(名: str, 对: bool, 明: str) -> None:
    """源口径钉也走 OK/BAD 行 —— 反向对照要能按行数红、点名。"""
    global 坏
    print(("OK  " if 对 else "BAD ") + "%s：%s" % (名, 明))
    if not 对:
        坏 += 1


钉("call_site_uses_helper",
   "capacity = expanded_capacity(current, page_size, maximum=maximum," in 源,
   "扩充仍走 expanded_capacity helper")
钉("storage_not_page_aligned", "page_aligned=not storage" in 源,
   "仓库不按页对齐、背包对齐")
钉("read_path_normalized", "bag_capacity=page_aligned_capacity(" in 源,
   "读档 from_dict 走 page_aligned_capacity")
旧式 = 源.count("capacity = min(maximum, current + page_size)")
钉("old_inline_math_gone", 旧式 == 0, "旧的硬加写法不许回来（命中 %d 次）" % 旧式)

# ── ⑥ 夹具种子只抬不压 ─────────────────────────────────────────────────────
# 玩档根每次启动都会跑 `seed_pets`；直接赋值会把玩家扩充过的容量按回种子值，
# 标题的总格数于是"每启动一次就错一次"（2026-10-31 用户报）。这里钉住 max(...) 写法。
夹具源 = open(os.path.join(根, "开发工具", "本地服务端夹具.py"), encoding="utf-8").read()
夹具钉 = "state.bag_capacity = max(int(state.bag_capacity or 0), MAIN_BAG_CAPACITY)"
钉("fixture_never_lowers", 夹具钉 in 夹具源, "夹具种子只抬不压")

print("RESULT", "PASS" if 坏 == 0 else "FAIL", "bad=%d" % 坏)
raise SystemExit(0 if 坏 == 0 else 1)
