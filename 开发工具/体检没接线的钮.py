# -*- coding: utf-8 -*-
"""体检：场景里**没人认领的交互控件** —— 可见可点，但既没有场景 `[connection]`，
   名字也没在任何 `.gd` 里出现过 ⇒ 点下去大概率什么也不发生（§3.111「扩展兽栏」那个形状）。

判据（刻意的**强信号**筛法，宁可漏报）：
  ① 只看交互类节点：Button / TextureButton / CheckBox / OptionButton / MenuButton / LinkButton / LineEdit；
  ② "有人认领" = 该场景的 `[connection]` 里有以它（或它的祖先）为 `from` 的一条；**或**
     它的**节点名**作为词出现在**任一** `.gd` 里（代码里按名字取节点/接线的都算）。
     ⇒ 只有"名字全工程没人提过、场景里也没连"的才报 —— 这几乎一定是漏接。

⚠️ 会**漏**（这是设计取舍）：靠数组/循环接的（`for 钮 in 容器.get_children()`）、
   靠 `find_child("前缀*")` 接的、父节点统一接的 —— 它们名字可能确实没人单独提，但接上了。
   ⇒ 报出来的是**候选**，逐条去那个场景/脚本里看一眼再定。也**不进门禁**（静态工具）。

用法：python 开发工具/体检没接线的钮.py [--明细 路径]
"""
from __future__ import annotations

import argparse
import io
import os
import re
import sys

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
扫描目录 = ["脚本", "素材", "场景"]
交互类型 = {"Button", "TextureButton", "CheckBox", "OptionButton", "MenuButton", "LinkButton", "LineEdit"}
块 = re.compile(r"^\[node ([^\]]*)\]\r?\n((?:^(?!\[).*\r?\n?)*)", re.M)
连接 = re.compile(r'^\[connection signal="[^"]+" from="([^"]*)"', re.M)


def 读(路径: str) -> str:
    try:
        return io.open(路径, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def 全部文本() -> tuple[str, list[tuple[str, str]]]:
    """(所有 .gd 拼起来的大字符串, [(相对路径, 场景内容)])。"""
    脚本大 = []
    场景们 = []
    for 顶层 in 扫描目录:
        基 = os.path.join(根, 顶层)
        if not os.path.isdir(基):
            continue
        for 目录, 子, 文件们 in os.walk(基):
            子[:] = [d for d in 子 if d not in ("__pycache__", ".godot")]
            for 名 in 文件们:
                全 = os.path.join(目录, 名)
                相对 = os.path.relpath(全, 根).replace("\\", "/")
                if 名.endswith(".gd"):
                    脚本大.append(读(全))
                elif 名.endswith(".tscn"):
                    场景们.append((相对, 读(全)))
    return "\n".join(脚本大), 场景们


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--明细", default="")
    参 = ap.parse_args()

    脚本文本, 场景们 = 全部文本()
    脚本词表 = set(re.findall(r"[A-Za-z_一-鿿][\w一-鿿]*", 脚本文本))

    报 = []
    for 相对, 文本 in 场景们:
        已连 = set(连接.findall(文本))
        for 头, _属性 in 块.findall(文本):
            t = re.search(r'type="([^"]+)"', 头)
            名 = re.search(r'name="([^"]+)"', 头)
            if t is None or 名 is None or t.group(1) not in 交互类型:
                continue
            if 名.group(1) in 脚本词表:
                continue
            if any(p == 名.group(1) or p.endswith("/" + 名.group(1)) for p in 已连):
                continue
            报.append(f"{相对}  [{t.group(1)} 「{名.group(1)}」]  名字在任何 .gd 里都没出现过、场景也没有 [connection]")

    if 参.明细:
        io.open(参.明细, "w", encoding="utf-8").write("\n".join(报))
    print(f"疑似没接线的钮：{len(报)} 个（候选，逐条核对再定）")
    for 行 in 报[:80]:
        print("  " + 行)
    return 0


if __name__ == "__main__":
    sys.exit(main())
