# -*- coding: utf-8 -*-
"""体检：脚本里的 `$节点名` 字面量，在**它挂的那个场景**里存不存在。

起因 §3.109：结印页弹窗的脚本抄了**写轮眼页**的节点名（`$祝福值进度条`），
本页没有那个节点 —— **不报错、不崩溃，只是那个函数永远什么都不做**，
只在运行时往控制台吐 `Node not found`（门跑得多才看得见）。

静态扫法的边界（报出来先人工看一眼，别当铁证）：
  · 只认**字面量**路径；`$印%d阶段` 这种格式化出来的、运行期 `add_child` 的都不算；
  · 路径是**相对脚本所挂节点**的 ⇒ 先确定"这个脚本挂在场景的哪个节点上"；
    一个脚本挂多个场景时**逐个判**，只要有一个对得上就放过（同一脚本常被多个页面复用）；
  · 会**钻进 `instance=ExtResource` 的子场景**（不然砍树的烘焙图会把所有 UI 脚本都报成错）；
  · `$X` **恒等于** `self.get_node(X)` ⇒ 报出来是**真 bug 候选**（同一族就是 §3.109 那个）；
    `get_node("…")` 扫不了（receiver 未知，实测 400+ 假红），`get_node_or_null` 本就是刻意容忍缺件。

用法（先看结论，明细落盘再 grep）：
  python 开发工具/体检脚本节点引用.py [--明细 路径]
"""
from __future__ import annotations

import argparse
import io
import os
import re
import sys

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

场景根 = ["场景", "素材"]
硬 = re.compile(r'\$([A-Za-z0-9_一-鿿/%]+)')
# ⚠️ **只扫 `$路径`**。`get_node("…")` 听着更通用，其实**不可判** —— 它是对**任意接收者**的方法调用
#    （`page.get_node("内容框/…")` 里的 page 是局部变量，跟脚本挂在哪个节点上无关），
#    静态扫必然满屏假红（实测 400+ 处全是这种）。`$X` 才**恒等于 self.get_node(X)**，才是真判据。
ext_res = re.compile(r'^\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', re.M)
# ⚠️ `script = ExtResource(...)` **不在** [node …] 那一行上，而在它下面的属性块里 ⇒
#    必须按"块"解析（从 `[node …]` 到下一行 `[` 为止），别只扫标题行。
块 = re.compile(r"^\[node ([^\]]*)\]\r?\n((?:^(?!\[).*\r?\n?)*)", re.M)


def 读(路径: str) -> str:
    try:
        return io.open(路径, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def 绝对到仓(相对: str) -> str:
    return os.path.join(根, 相对.replace("res://", "").replace("/", os.sep))


class 场景表:
    """场景路径 → {节点相对路径: 子场景路径 or None}。"""

    def __init__(self) -> None:
        self.表: dict[str, dict[str, str | None]] = {}
        self._扫()

    def _扫(self) -> None:
        for 顶层 in 场景根:
            for 目录, _子, 文件们 in os.walk(os.path.join(根, 顶层)):
                for 文件名 in 文件们:
                    if not 文件名.endswith(".tscn"):
                        continue
                    全 = os.path.join(目录, 文件名)
                    相对 = "res://" + os.path.relpath(全, 根).replace("\\", "/")
                    self.表[相对] = self._解(读(全))

    @staticmethod
    def _解(文本: str) -> dict[str, str | None]:
        标识到路径 = {i: p for p, i in ext_res.findall(文本)}
        结果: dict[str, str | None] = {}
        for 头, _属性 in 块.findall(文本):
            名 = re.search(r'name="([^"]+)"', 头)
            父 = re.search(r'parent="([^"]*)"', 头)
            if 名 is None:
                continue
            路径 = _节点路径(名.group(1), 父.group(1) if 父 else None)
            实例 = re.search(r'instance\s*=\s*ExtResource\("([^"]+)"\)', 头)
            结果[路径] = 标识到路径.get(实例.group(1)) if 实例 else None
        return 结果

    def 有(self, 场景路径: str, 路径: str, 深度: int = 0) -> bool:
        表 = self.表.get(场景路径)
        if 表 is None or 深度 > 8:
            return False
        if 路径 in 表:
            return True
        候选 = [p for p in 表 if 路径.startswith(p + "/")]
        if not 候选:
            return False
        最长 = max(候选, key=len)
        子 = 表[最长]
        if 子 is None:
            return False
        return self.有(子, 路径[len(最长) + 1:], 深度 + 1)

    def 挂点(self, 场景路径: str) -> dict[str, list[str]]:
        """脚本路径 → 它在这个场景里挂到的节点路径（一个脚本可能挂多处）。"""
        文本 = 读(绝对到仓(场景路径))
        标识到路径 = {i: p for p, i in ext_res.findall(文本)}
        结果: dict[str, list[str]] = {}
        for 头, 属性 in 块.findall(文本):
            名 = re.search(r'name="([^"]+)"', 头)
            父 = re.search(r'parent="([^"]*)"', 头)
            if 名 is None:
                continue
            # ⚠️ .tscn 里的路径是**从场景根算**的：根节点没有 `parent=` 属性
            #    （≠ `parent="."`，后者是根的直接子节点）⇒ 根自己记成空串，
            #    否则"脚本挂在根上、引用 `遮罩`"会被解析成 `功能窗口/遮罩` ⇒ 全假红。
            节点路径 = _节点路径(名.group(1), 父.group(1) if 父 else None)
            标 = re.search(r'script\s*=\s*ExtResource\("([^"]+)"\)', 属性)
            if 标 is None:
                continue
            脚本 = 标识到路径.get(标.group(1), "")
            if 脚本.endswith(".gd"):
                结果.setdefault(脚本, []).append(节点路径)
        return 结果


def _节点路径(名: str, 父: str | None) -> str:
    """.tscn 的 `[node name=… parent=…]` → **从场景根算起**的路径（根 = 空串）。"""
    if 父 is None:
        return ""                       # 根节点：没有 parent= 属性
    if 父 == ".":
        return 名                        # 根的直接子节点
    return f"{父}/{名}"


def 解析(路径: str, 基: str) -> str | None:
    段 = [s for s in 基.split("/") if s]
    for 部件 in 路径.split("/"):
        if 部件 in ("", "."):
            continue
        if 部件 == "..":
            if not 段:
                return None
            段.pop()
        else:
            段.append(部件)
    return "/".join(段)


def 主() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--明细", default="")
    参 = ap.parse_args()

    表 = 场景表()
    脚本到挂点: dict[str, list[tuple[str, list[str]]]] = {}
    for 场景路径 in sorted(表.表):
        for 脚本, 挂点们 in 表.挂点(场景路径).items():
            脚本到挂点.setdefault(脚本, []).append((场景路径, 挂点们))

    硬报: list[str] = []
    for 脚本 in sorted(脚本到挂点):
        全 = 绝对到仓(脚本)
        if not os.path.exists(全):
            continue
        for 序号, 行 in enumerate(读(全).split("\n"), 1):
            if 行.lstrip().startswith("#"):
                continue
            净 = re.sub(r'"(?:[^"\\]|\\.)*"', '""', 行)      # 去掉字符串字面量（`"$占位"` 之类别误伤）
            净 = re.sub(r"(?<!:)#.*$", "", 净)              # 再去行尾注释
            for 模式, 桶, 标签 in ((硬, 硬报, "$"),):
                for 引用 in 模式.findall(净):
                    命中 = False
                    for 场景路径, 挂点们 in 脚本到挂点[脚本]:
                        for 挂点 in 挂点们:
                            绝对 = 解析(引用, 挂点)
                            if 绝对 is not None and 表.有(场景路径, 绝对):
                                命中 = True
                                break
                        if 命中:
                            break
                    if not 命中:
                        落点 = " / ".join(f"{s}@{','.join(挂)}" if len(挂) < 4 else f"{s}@{挂[0]}…"
                                        for s, 挂 in 脚本到挂点[脚本][:3])
                        桶.append(f"{脚本}:{序号}  [{标签} {引用}]  挂在 {落点} ⇒ 那些场景里都没有")

    明 = "\n".join(硬报)
    if 参.明细:
        io.open(参.明细, "w", encoding="utf-8").write(明)
    print(f"`$节点` 对不上：{len(硬报)} 处")
    for 行 in 硬报[:60]:
        print("  " + 行)
    return 0


if __name__ == "__main__":
    sys.exit(主())
