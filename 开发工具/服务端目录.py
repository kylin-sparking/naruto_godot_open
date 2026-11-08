#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""服务端寻径的**唯一真源**（2026-10-03，见 §3.89）。

背景：以前每个 import 服务端的脚本各写一份 `SERVER_TOOLS = r"2.2.3\\tools"`
（或 `GAME_ROOT / "tools"`），运行时直接吃 2.2.3 的代码 —— 而 2.2.3 是"原版参考"目录。
服务端现已整体复刻进 `naruto_godot/服务端/runtime/`（`README.md` 有目录形状与唯一改动说明）。
本模块把寻径收口到一处，并做两件防御：
  1. `sys.path.insert(0, 服务端 tools 目录)` 后再 import，确保拿到的是**项目内那份**；
  2. 从 `sys.path` 里**剔除任何 2.2.3 的 tools 目录**，并断言加载到的 `fake_flash_server.__file__`
     在项目内 —— 万一哪天解释器又自动把 2.2.3 挂进 path（比如误用 2.2.3 的捆绑 python、
     其 `python313._pth` 硬写了 `..\\..\\tools`），这里会**立刻响亮报错**而不是静默用错那份。

用法（导出器/夹具通用）：
    import 服务端目录
    fake_flash_server = 服务端目录.加载()        # 返回已 import 且已校验的模块
    目录 = 服务端目录.tools目录()                # 只要路径（如拼 GameData.dat）
"""
from __future__ import annotations

import sys
from pathlib import Path

# 本文件在 开发工具/，项目根是它的上一级。
项目根 = Path(__file__).resolve().parents[1]


def tools目录() -> Path:
    """服务端 .py 所在目录（= 运行期真正 import 的那份）。"""
    return 项目根 / "服务端" / "runtime" / "tools"


def 剔除外部服务端路径() -> None:
    """把 sys.path 里**外来的服务端 tools 目录**（如 2.2.3\\tools）去掉，只留项目内那份。

    ⚠️ 不能按"路径含 2.2.3"一刀切：用 2.2.3 的捆绑解释器跑时，它自己的标准库
    （`...\\2.2.3\\runtime\\python` 与 `python313.zip`）路径里也含 2.2.3，一刀切会把 stdlib
    也剔掉 → 连 `import base64` 都找不到（2026-10-03 稳健性测试实测踩到）。
    所以只剔"目录名是 tools、且不在项目内"的外来服务端目录。
    """
    保留 = []
    for p in sys.path:
        名 = str(p)
        try:
            是服务端tools = Path(名).name.lower() == "tools"
            在项目内 = Path(名).resolve().is_relative_to(项目根)
        except OSError:
            保留.append(p)
            continue
        if 是服务端tools and not 在项目内:
            continue  # 外来服务端目录（2.2.3 等）→ 丢
        保留.append(p)
    sys.path[:] = 保留


_服务端模块 = {"fake_flash_server", "multiplayer_backend", "editor_runtime_config",
              "gm_state", "gm_admin", "storage_backend"}


def 加载模块(名字: str):
    """把项目内服务端 tools 目录放到 sys.path 最前，import 并校验加载的确实是项目内那份。

    `名字` ∈ {fake_flash_server, gm_admin, ...}。防御：万一解释器又自动挂了 2.2.3\\tools
    （比如误用 2.2.3 的捆绑 python），这里会报错而不是静默用错那份。
    """
    剔除外部服务端路径()
    tools = str(tools目录())
    if tools not in sys.path:
        sys.path.insert(0, tools)
    # 该模块（或其依赖）之前可能已从别处加载 → 逐出重载，保证拿的是项目内这份
    for 名 in _服务端模块:
        既有 = sys.modules.get(名)
        if 既有 is not None and not Path(getattr(既有, "__file__", "")).resolve().is_relative_to(项目根):
            sys.modules.pop(名, None)
    module = __import__(名字)
    落在 = Path(module.__file__).resolve()
    if not 落在.is_relative_to(项目根):
        raise RuntimeError(
            f"{名字} 加载到了项目外的副本：{落在}\n"
            f"应为：{tools目录() / (名字 + '.py')}\n"
            f"多半是用了 2.2.3 的捆绑解释器（其 ._pth 自动挂了 2.2.3\\tools）——"
            f"改用 运行时/python/python.exe，或删掉那个 ._pth 里的 ..\\..\\tools 行。")
    return module


def 加载():
    """import 并返回项目内的 fake_flash_server（等价 加载模块("fake_flash_server")）。"""
    return 加载模块("fake_flash_server")


if __name__ == "__main__":
    m = 加载()
    print("tools 目录 :", tools目录())
    print("PROJECT_ROOT:", m.PROJECT_ROOT)
    print("GameData   :", m.GAME_DATA_PATH, m.GAME_DATA_PATH.exists())
    print("catalog 段 :", len(m.GAME_DATA_CATALOG.raw_item_sections))
