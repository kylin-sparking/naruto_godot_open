# -*- coding: utf-8 -*-
"""体检：**服务端回包里用到的"动作号"，客户端那支 `_handle_*_text` 认不认？**

起因（2026-10-14 §3.161）：八门的统计帧服务端发的是动作 **3**（原版 `MaiProcessor` 有自己一套
回包动作号：1 倒计时 / 2 一门已开数 / 3 统计 / 4·5 突破信息），而客户端只认 0/1 ——
整条回包**静默丢掉**，什么也不报。这一族（回包被丢）只能靠对表发现。

做法：静态扫两边 ——
  · 服务端：`send_text(f"{op(ServerOpcode.X)}:…")` 里第二段的动作号（`op(SomeEnum.MEMBER)` 按枚举解值，
    字面数字直接用）；
  · 客户端：`_handle_bridge_text` 的 opcode→函数分派表 + 每个函数认的动作（`action == N` / `match action:` 的 case）。
报"服务端发过、客户端那一支没认"的组合。

**粗粒度体检、不是判据**：动态动作号、非动作型载荷、以及"按 opcode 分派"的函数都会假红/漏报 ——
报出来先人工过一遍。用法：python 开发工具/体检回包动作号.py

⚠️ **不动的一簇**（报出来也别改）：`1552`（家族/帮会）的动作 7/8/9/12/23 ——
家族那部分归**另一位开发者**（用户 2026-10-14 口径），本探针照报，改不改由他那边定。
"""
from __future__ import annotations
import io
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
服 = io.open(os.path.join(根, "服务端", "runtime", "tools", "fake_flash_server.py"),
             encoding="utf-8").read()
客 = io.open(os.path.join(根, "脚本", "单例", "后端连接.gd"), encoding="utf-8").read()

# ── 1) 服务端枚举（块切分：`class X(IntEnum):` 到下一个 `class`）──
枚举: dict[str, dict[str, int]] = {}
for m in re.finditer(r"^class ([A-Za-z_][A-Za-z0-9_]*)\(IntEnum\):\n(.*?)(?=\nclass |\Z)", 服, re.S | re.M):
    值 = {}
    for 行 in m.group(2).splitlines():
        mm = re.match(r"\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([\d_]+)\s*(?:#.*)?$", 行)
        if mm:
            值[mm.group(1)] = int(mm.group(2).replace("_", ""))
    枚举[m.group(1)] = 值
服务端op = 枚举.get("ServerOpcode", {})
if not 服务端op:
    print("!! 解不出 ServerOpcode（服务端枚举格式变了？）")
    raise SystemExit(1)

# ── 2) 客户端 OP_* 常量 + opcode→处理函数 + 每个函数认的动作 ──
客户端op = {m.group(1): int(m.group(2)) for m in re.finditer(r"^const (OP_[A-Z_]+) := (\d+)", 客, re.M)}
块 = re.search(r"func _handle_bridge_text\(text: String\) -> void:(.*?)\nfunc ", 客, re.S)
分派: dict[int, str] = {}
if 块:
    for m in re.finditer(r"\n\t\t((?:[A-Z_0-9_]+(?:\s*,\s*)?)+):\s*\n\t\t\t(_handle_[A-Za-z_0-9]+)", 块.group(1)):
        # ⚠️ `客户端op` 的键**自带 OP_ 前缀**（是整条常量名）—— 别再加一次。
        for 常量 in re.findall(r"[A-Z_0-9_]+", m.group(1)):
            n = 客户端op.get(常量)
            if n is None and ("OP_" + 常量) in 客户端op:
                n = 客户端op["OP_" + 常量]
            if n is not None:
                分派[n] = m.group(2)

def 体(名: str) -> str:
    m = re.search(r"func %s\([^)]*\)[^:]*:\n((?:\t.*\n|\n)*)" % re.escape(名), 客)
    return m.group(1) if m else ""

def 认的动作(t: str) -> set[int]:
    出 = set(int(x) for x in re.findall(r"action == (\d+)", t))
    m = re.search(r"match action:\n((?:\t{2,}.*\n|\n)+)", t)
    if m:
        for 行 in m.group(1).splitlines():
            mm = re.match(r"\s*([\d,\s]+):", 行)
            if mm:
                出.update(int(x) for x in re.findall(r"\d+", mm.group(1)))
    return 出

# 按 opcode 再分派的几支：它们认的动作集跟具体 opcode 有关，合并进同一支会假红 ⇒ 跳过并列出。
多重op = {"_handle_cultivation_text", "_handle_npc_dialog_text", "_handle_item_change_result"}

# ── 3) 扫服务端回包：第一段 opcode、第二段动作号 ──
发 = []
for m in re.finditer(r"send_text\(\s*f?(\"(?:[^\"\\]|\\.)*\")", 服, re.S):
    串 = m.group(1)
    前 = re.match(r'"\{op\(ServerOpcode\.([A-Za-z_0-9]+)\)\}\s*:\s*(.*)$', 串, re.S)
    if not 前:
        continue
    n = 服务端op.get(前.group(1))
    if n is None:
        continue
    余 = 前.group(2)
    mm = re.match(r"\{op\(([A-Za-z_0-9]+)\.([A-Za-z_0-9]+)\)\}", 余)
    动 = None
    if mm and mm.group(1) in 枚举:
        动 = 枚举[mm.group(1)].get(mm.group(2))
    else:
        mm = re.match(r"(\d+)", 余)
        if mm:
            动 = int(mm.group(1))
    if 动 is None:
        continue
    发.append((n, 动, 服[:m.start()].count("\n") + 1))

命中 = []
跳过 = set()
for 数, 动, 行号 in 发:
    f = 分派.get(数)
    if f is None:
        continue
    if f in 多重op:
        跳过.add(f)
        continue
    认 = 认的动作(体(f))
    if 认 and 动 not in 认:
        命中.append((数, 动, 行号, f, sorted(认)))

for 数, 动, 行号, f, 认 in 命中:
    print(f"服务端 :{行号}  回包 opcode={数} 动作 {动} —— 客户端 {f} 只认 {认}")
print(f"\n扫了 {len(发)} 条带动作号的回包、{len(分派)} 个 opcode 分派；"
      f"共 {len(命中)} 处候选（人工复核：动态动作号/非动作载荷会假红）")
if 跳过:
    print("（按 opcode 再分派的支没扫：%s —— 那几支要人眼看）" % ", ".join(sorted(跳过)))
