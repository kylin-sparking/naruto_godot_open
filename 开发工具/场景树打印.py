#!/usr/bin/env python3
"""把 .tscn 的节点树打出来（类型、实例、可见性、位置/尺寸、脚本），用来对比两个工程的结构整洁度。

用法：python 开发工具/场景树打印.py 场景/界面/窗口/人物/人物窗口.tscn [--pos]
"""
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

节点头 = re.compile(r'^\[node(?P<附>[^\]]*)\]')
节点头2 = re.compile(r'^\[(?P<名>ext_resource|sub_resource|connection|editable)\b')
属性 = re.compile(r'^(?P<键>\w+) = (?P<值>.+)$')
键值 = re.compile(r'(?P<键>\w+)="(?P<值>[^"]*)"')


def 解析(路径: Path):
    序 = []
    节 = None
    for 行 in 路径.read_text(encoding="utf-8").splitlines():
        m = 节点头.match(行)
        if m and " name=" in m.group("附"):
            附 = dict(键值.findall(m.group("附")))
            节 = {"名": 附["name"], "类": 附.get("type", ""),
                  "父": 附.get("parent", "."), "实例": 附.get("instance", ""),
                  "属性": {}}
            序.append(节)
            continue
        if 节点头2.match(行) or (行.startswith("[") and 行.endswith("]")):
            节 = None
            continue
        if 节 is None:
            continue
        a = 属性.match(行)
        if a:
            if a.group("值").rstrip().endswith("\\"):
                节["属性"][a.group("键")] = a.group("值").rstrip()[:-1]
                节["续"] = a.group("键")
                continue
            节["属性"][a.group("键")] = a.group("值").strip()
    return 序


def 路径of(父路: str, 名: str) -> str:
    return 名 if 父路 == "." else 父路 + "/" + 名


序 = 解析(Path(sys.argv[1]))
显示位置 = "--pos" in sys.argv
子表 = {}
带路 = {}
根 = []
for n in 序:
    p = 路径of(n["父"], n["名"])
    n["_p"] = p
    带路[p] = n
for n in 序:
    if n["父"] == ".":
        根.append(n)
    子表.setdefault(n["父"], []).append(n)


def 出(n, 层):
    标 = n["名"] + (f' <{n["类"]}>' if n["类"] else "")
    if n["实例"]:
        标 += f' (实例 {n["实例"]})'
    注 = []
    if n["属性"].get("visible") == "false":
        注.append("隐藏")
    if "script" in n["属性"]:
        注.append("脚本")
    if n["属性"].get("mouse_filter"):
        注.append("mf=" + n["属性"]["mouse_filter"])
    if 显示位置:
        v = n["属性"].get("position") or n["属性"].get("anchors_preset")
        s = n["属性"].get("size")
        if v:
            注.append("pos=" + v.replace("Vector2(", "").replace(")", ""))
        if s:
            注.append("sz=" + s.replace("Vector2(", "").replace(")", ""))
    if n["属性"].get("text") and len(str(n["属性"]["text"])) < 40:
        注.append("text=" + n["属性"]["text"])
    if 注:
        标 += "  [" + " ".join(注) + "]"
    print("  " * 层 + 标)
    for c in 子表.get(n["_p"], []):
        出(c, 层 + 1)


for r in 根:
    出(r, 0)

未挂 = [p for p in 带路 if p != "." and not any(p.startswith(x + "/") or x == "." for x in 带路)]
print(f"共 {len(序)} 个节点")
if 未挂:
    print("孤立节点（父路径不存在）：")
    for p in 未挂:
        print("  " + p)
