# -*- coding: utf-8 -*-
"""体检：全工程 `.gd` 里**没有任何调用点**的函数（裸函数名/`bind`/连接/场景 [connection] 都算调用）。

为什么要扫这个（§3.111 的教训）：`_expand_pet_slots()` 是**零调用点**的，它提示"确认窗尚未移植，
敬请期待"——而那扇窗**早就移植了**。死函数本身不咬人，**它旁边少掉的那根接线**才咬人：
宠物页那条「扩展兽栏」是"可见可点没接线"的空壳，跟这个死函数是同一个漏项的两种残留。
所以"**零调用点的 UI 处理函数**"是"接线丢了"的**高信噪比探针**。

判据（宽进严出，宁可漏报不误报）：
  · 视作"有调用点"的形态 —— `名(`、`.名(`、`"名"`、`名.bind(`、`.connect(名)`、`.connect("名")`、
    场景 `.tscn` 里的 `method="名"` 与 `"名"`；
  · **白名单**（引擎回调/虚函数/`_` 前缀生命周期/属性访问器/常量集）直接跳过；
  · 只在**本工程**里找（`脚本/`、`素材/`、`场景/`、`测试/`、`开发工具/`）。
    ⚠️ 有几种**正常**的零调用点，报出来要人工过一遍：
      ① 引擎按名字调的（`_ready` 一族已白名单，但 `_get_drag_data` 这种要自己认）；
      ② 只给**外部/打包方**用的 API（`素材/.../脚本/` 下的作者页脚本常有）；
      ③ 门自己会调（`测试/*.gd` 里 `call("名")` —— 字符串调用是算进去的，但如果门用变量拼就不算）；
      ④ 刚写完还没接的功能。

用法：python 开发工具/体检无人调用的函数.py [--全] [--明细 路径]
"""
from __future__ import annotations

import argparse
import io
import os
import re
import sys

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
扫描目录 = ["脚本", "素材", "场景", "测试", "开发工具", "数据", "服务端"]

函数定义 = re.compile(r'^[ \t]*(?:static\s+)?func\s+([A-Za-z_一-鿿][\w一-鿿]*)\s*\(')
# 引擎回调 / 生命周期 / 访问器 / 运算符：按名字调，不算"没人调"
白名单前缀 = ("_ready", "_process", "_physics_process", "_enter_tree", "_exit_tree", "_input",
          "_unhandled_input", "_unhandled_key_input", "_gui_input", "_draw", "_notification",
          "_init", "_to_string", "_get", "_set", "_get_property_list", "_property_can_revert",
          "_property_get_revert", "_get_configuration_warnings", "_shortcut_input",
          "_validate_property", "_get_drag_data", "_can_drop_data", "_drop_data",
          "_make_custom_tooltip", "_get_minimum_size", "_has_point", "_structured_text",
          "set_", "get_")
白名单全名 = {"_ready", "_process", "_draw", "run", "main"}


def 读(路径: str) -> str:
    try:
        return io.open(路径, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def 全文件() -> list[tuple[str, str]]:
    """[(相对路径, 内容)] —— 只在工程内、文本类型。"""
    出 = []
    for 顶层 in 扫描目录:
        基 = os.path.join(根, 顶层)
        if not os.path.isdir(基):
            continue
        for 目录, 子, 文件们 in os.walk(基):
            子[:] = [d for d in 子 if d not in ("__pycache__", ".godot")]
            for 名 in 文件们:
                if not 名.endswith((".gd", ".tscn", ".tres", ".py")):
                    continue
                全 = os.path.join(目录, 名)
                相对 = os.path.relpath(全, 根).replace("\\", "/")
                出.append((相对, 读(全)))
    return 出


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--全", action="store_true", help="连疑似引擎回调也一起列出来")
    ap.add_argument("--明细", default="")
    参 = ap.parse_args()

    文件 = 全文件()
    定义: list[tuple[str, int, str]] = []
    for 相对, 内容 in 文件:
        if not 相对.endswith(".gd"):
            continue
        for i, 行 in enumerate(内容.split("\n"), 1):
            m = 函数定义.match(行)
            if m:
                定义.append((相对, i, m.group(1)))

    # 先把每个文件的**词表**算出来（一次 findall），再按词查 —— 否则"每个定义 × 每个文件的每一行"
    # 在 6 万行的服务端上就是天文数字（第一版这么卡了 10 分钟还没跑完）。
    词表 = [(相对, set(re.findall(r"[A-Za-z_一-鿿][\w一-鿿]*", 内容)), 内容.split("\n"))
           for 相对, 内容 in 文件]

    可疑: list[str] = []
    for 相对, 行号, 名 in 定义:
        if 名 in 白名单全名 or 名.startswith(白名单前缀):
            continue
        模式 = re.compile(r'(?<![\w一-鿿])' + re.escape(名) + r'(?![\w一-鿿])')
        引用 = 0
        在哪 = []
        for 别的相对, 词, 段 in 词表:
            if 名 not in 词:
                continue                # 这个词在这个文件里压根没出现 ⇒ 整份跳过
            for j, l in enumerate(段, 1):
                if 别的相对 == 相对 and j == 行号:
                    continue            # 定义本身不算引用（同文件的递归/信号绑定才算）
                if 模式.search(l):
                    引用 += 1
                    在哪.append(f"{别的相对}:{j}")
        if 引用 == 0:
            可疑.append(f"{相对}:{行号}  func {名}()   —— 全工程零引用")
        elif 引用 <= 1 and 参.全:
            可疑.append(f"{相对}:{行号}  func {名}()   —— 只有 1 处引用：{在哪[:2]}")

    明 = "\n".join(可疑)
    if 参.明细:
        io.open(参.明细, "w", encoding="utf-8").write(明)
    print(f"零调用点函数：{len([x for x in 可疑 if '零引用' in x])} 个"
          + (f"（含单引用 {len(可疑) - len([x for x in 可疑 if '零引用' in x])} 个）" if 参.全 else ""))
    for 行 in 可疑[:80]:
        print("  " + 行)
    return 0


if __name__ == "__main__":
    sys.exit(main())
