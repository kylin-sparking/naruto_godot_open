# -*- coding: utf-8 -*-
"""体检：`字典.get("键", 默认)` 里的字面量键，**全工程只出现这一次** ⇒ 极可能是拼错/没人写的键。

为什么值得单拎一把（2026-10-14 第十五回合）：这一族的表现是**不报错、不崩、门还全绿**，
只是"点了没反应"或"显示恒 0/恒假"。本轮 §3.152（灵器/kai_guang、人具、神器那块）、§3.153（好友 is_friend）、
§3.154（洗炼 plus_attr）、§3.156（人物面板 will）、§3.159（变身卡 special_attrs）**五处**都是它逮出来的。

判据（**不是**"出现一次就一定错"）：这个键在**产出侧**有没有人写 ——
① 服务端 python 里写的键（本脚本扫不到）；② 用**裸标识符**读的字段；③ 只在够不着的那一支用的冷键。
所以**报出来先人工过一遍**：三步口诀 = grep 服务端处理函数 → grep 请求侧 → grep 数据表。

⚠️ 计数**别走正则**：`[^"\\\n]` 那种字符类被坑过一次（实测把字母 n 也排除掉了，计数全错），
这里直接 `文本.count('"键"')`。

用法：python 开发工具/体检单次出现的键.py
"""
from __future__ import annotations
import io
import os
import re
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
内容: list[tuple[str, str]] = []
for 顶层 in ("脚本", "素材", "数据"):
    for 目录, _子, 文件们 in os.walk(os.path.join(根, 顶层)):
        for f in 文件们:
            if f.endswith((".gd", ".json", ".tscn")):
                p = os.path.join(目录, f)
                try:
                    内容.append((p, io.open(p, encoding="utf-8", errors="replace").read()))
                except OSError:
                    pass

取 = re.compile(r'\.get\(\s*"([^"\\\n]{1,48})"\s*[,)]')
命中 = 0
for p, t in 内容:
    if not p.endswith(".gd"):
        continue
    for i, 行 in enumerate(t.splitlines(), 1):
        if 行.strip().startswith("#"):
            continue
        for m in 取.finditer(行):
            键 = m.group(1)
            if 键.isdigit() or 键.startswith("_"):     # 调试/私有字段不报
                continue
            次数 = sum(t2.count('"%s"' % 键) for _p2, t2 in 内容)
            if 次数 <= 1:
                命中 += 1
                print("%s:%d  get(\"%s\") —— 全工程只此一次\n    %s"
                      % (os.path.relpath(p, 根).replace(os.sep, "/"), i, 键, 行.strip()[:110]))
print("\n共 %d 处候选（人工核：服务端写的键/裸标识符读的字段/冷键都会假红）" % 命中)
