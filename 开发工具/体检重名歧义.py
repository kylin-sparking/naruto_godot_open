# -*- coding: utf-8 -*-
"""体检：`find_child("X")` / `find_children("X")` 抓的**是不是唯一那枚**。

起因 §3.112：`人物窗口` 用 `find_child("开始提升按钮")` 找提交钮，而寄坏之术页里
**有两枚同名节点** —— 命中的是 `底图/放置区底图/开始提升按钮`（文案「放入昆虫」），
于是"错的那枚"被接到提交上、真提交钮没人接，而**门用的是同一句 find_child ⇒ 恒为真**。
这个错法有个好性质：**它是静态可判的** —— 只要在"脚本挂的那个节点"的子树里数一数同名节点有几枚。

判据：
  · 逐条取 `.gd` 里的 `find_child("字面量", …)` / `find_children("字面量", …)`；
  · 把它放到**这个脚本挂的每个场景/每个挂点**下，展开 `instance=ExtResource` 的子场景后
    数一数子树里同名节点有几枚（支持 `*`/`?` 通配，按 Godot 的 `find_child` 语义只匹配**节点名**）；
  · **>1 枚** 就报 —— 这就是"歧义"：命中哪一枚取决于树序，改一下场景就变。
  · 0 枚也报（`find_child` 返回 null，多半是名字写错了）；但这栏噪声大，单列。

⚠️ 边界：`find_child` 的**第三参 `owned`** 会影响结果（本工程一律传 `false`）；运行期新建的节点
    静态看不见；同一个脚本挂多个场景时**逐个判、任一场景歧义就报**（歧义就是歧义）。

用法：python 开发工具/体检重名歧义.py [--明细 路径]
"""
from __future__ import annotations

import argparse
import fnmatch
import io
import os
import re
import sys

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
扫描目录 = ["脚本", "素材", "场景", "测试"]
块 = re.compile(r"^\[node ([^\]]*)\]\r?\n((?:^(?!\[).*\r?\n?)*)", re.M)
ext_res = re.compile(r'^\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"', re.M)
# ⚠️ **只认不带接收者的 `find_child(...)`**（= `self.find_child`，与"脚本挂在哪个节点"可比）。
#    带接收者的（`seal.find_child("印式*")` 这种循环里逐个容器找）**接收者是运行期变量**，
#    静态判不了 ⇒ 一律跳过（第一版没跳，5 条里 4 条全是这种假阳性）。
查找调用 = re.compile(r'(?<![\w.\)])find_child(?:ren)?\(\s*"([^"*?]+[*?]?[^"]*)"')


def 读(路径: str) -> str:
    try:
        return io.open(路径, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def 绝对(相对: str) -> str:
    return os.path.join(根, 相对.replace("res://", "").replace("/", os.sep))


class 场景:
    """一次扫完：场景 → 节点表；脚本 → 挂点表。（文本只读一遍，别在双层循环里反复读盘。）"""

    def __init__(self) -> None:
        self.节点: dict[str, list[tuple[str, str | None]]] = {}   # 场景 → [(路径, 子场景)]
        self.脚本挂点: dict[str, list[tuple[str, str]]] = {}      # 脚本 → [(场景, 挂点路径)]
        self._展开缓存: dict[str, list[str]] = {}
        self._扫()

    def _扫(self) -> None:
        for 顶层 in 扫描目录:
            基 = os.path.join(根, 顶层)
            if not os.path.isdir(基):
                continue
            for 目录, 子, 文件们 in os.walk(基):
                子[:] = [d for d in 子 if d not in ("__pycache__", ".godot")]
                for 名 in 文件们:
                    全 = os.path.join(目录, 名)
                    相对 = "res://" + os.path.relpath(全, 根).replace("\\", "/")
                    if not (名.endswith(".tscn") or 名.endswith(".gd")):
                        continue
                    文本 = 读(全)
                    if 名.endswith(".tscn"):
                        节点 = self._解(文本)
                        self.节点[相对] = 节点
                        标识到路径 = {i: p for p, i in ext_res.findall(文本)}
                        for 头, 属 in 块.findall(文本):
                            标 = re.search(r'script\s*=\s*ExtResource\("([^"]+)"\)', 属)
                            if 标 is None:
                                continue
                            脚本 = 标识到路径.get(标.group(1), "")
                            if not 脚本.endswith(".gd"):
                                continue
                            名2 = re.search(r'name="([^"]+)"', 头)
                            父 = re.search(r'parent="([^"]*)"', 头)
                            if 名2 is None:
                                continue
                            self.脚本挂点.setdefault(脚本, []).append((相对, _节点路径(名2.group(1), 父.group(1) if 父 else None)))

    @staticmethod
    def _解(文本: str) -> list[tuple[str, str | None]]:
        标识到路径 = {i: p for p, i in ext_res.findall(文本)}
        出 = []
        for 头, _属 in 块.findall(文本):
            名 = re.search(r'name="([^"]+)"', 头)
            父 = re.search(r'parent="([^"]*)"', 头)
            if 名 is None:
                continue
            路径 = _节点路径(名.group(1), 父.group(1) if 父 else None)
            实例 = re.search(r'instance\s*=\s*ExtResource\("([^"]+)"\)', 头)
            出.append((路径, 标识到路径.get(实例.group(1)) if 实例 else None))
        return 出

    def 展开(self, 场景路径: str, 前缀: str = "", 深度: int = 0) -> list[str]:
        """场景 → 全部节点路径（钻 instance 子场景；根记成空串）。带缓存。"""
        if 深度 == 0 and 场景路径 in self._展开缓存:
            return self._展开缓存[场景路径]
        if 深度 > 8:
            return []
        出 = []
        for 路径, 子场景 in self.节点.get(场景路径, []):
            全 = f"{前缀}/{路径}" if (前缀 and 路径) else (前缀 or 路径)
            出.append(全)
            if 子场景:
                出.extend(self.展开(子场景, 全, 深度 + 1))
        if 深度 == 0:
            self._展开缓存[场景路径] = 出
        return 出

    def 子树里同名(self, 场景路径: str, 挂点: str, 模式: str) -> list[str]:
        命中 = []
        for p in self.展开(场景路径):
            if 挂点:
                if not (p.startswith(挂点 + "/")):
                    continue
                名 = p[len(挂点) + 1:].split("/")[-1]
            else:
                名 = p.split("/")[-1]
            if fnmatch.fnmatchcase(名, 模式):
                命中.append(p)
        return 命中


def _节点路径(名: str, 父: str | None) -> str:
    if 父 is None:
        return ""                       # 根节点没有 parent= 属性
    if 父 == ".":
        return 名
    return f"{父}/{名}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--明细", default="")
    参 = ap.parse_args()

    表 = 场景()
    歧义: list[str] = []
    找不到: list[str] = []
    for 脚本 in sorted(表.脚本挂点):
        文本 = 读(绝对(脚本))
        for 序, 行 in enumerate(文本.split("\n"), 1):
            if 行.lstrip().startswith("#"):
                continue
            for 模式 in 查找调用.findall(行):
                if "/" in 模式:
                    continue                    # 带路径的是 get_node 那类，不归这条管
                歧 = []
                空 = []
                for 场景路径, 挂点 in 表.脚本挂点[脚本]:
                    命中 = 表.子树里同名(场景路径, 挂点, 模式)
                    if len(命中) > 1:
                        歧.append((场景路径, 挂点, 命中))
                    elif not 命中:
                        空.append((场景路径, 挂点))
                for 场景路径, 挂点, 命中 in 歧[:2]:
                    歧义.append(f"{脚本}:{序}  find_child(\"{模式}\")  挂在 {场景路径}@{挂点 or '(根)'} "
                              f"⇒ 子树里**同名 {len(命中)} 枚**：{命中[:4]}")
                if not 歧 and 空 and len(空) == len(表.脚本挂点[脚本]):
                    找不到.append(f"{脚本}:{序}  find_child(\"{模式}\")  ⇒ 所有挂点的子树里都找不到")

    if 参.明细:
        io.open(参.明细, "w", encoding="utf-8").write(
            "\n".join(歧义 + ["", "—— 一枚都找不到（多半是名字写错 / 靠运行期新建）——"] + 找不到))
    print(f"⚠️ 有歧义的 find_child：{len(歧义)} 处（同名多枚，命中哪一枚看树序）")
    for 行 in 歧义[:60]:
        print("  " + 行)
    print(f"（附）find_child 一枚都找不到：{len(找不到)} 处 —— 明细看 --明细 文件")
    return 0


if __name__ == "__main__":
    sys.exit(main())
