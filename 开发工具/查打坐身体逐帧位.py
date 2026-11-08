# -*- coding: utf-8 -*-
"""查打坐身体动画的逐帧注册点。

为什么查这个：游戏里那圈光环是**挂在角色身上**的，它相对角色注册点摆位；而身体那张图
**每帧按它自己的注册点重摆**（`脚本/角色/原始动画精灵.gd:249`）。如果打坐这一套身体帧的
注册点自己逐帧在上下移，那"盘相对身体"就会动 —— 而编辑器里没有身体，所以那边切着看不飘、
游戏里飘。这条脚本只读数据、不动工程。

跑：python 开发工具/查打坐身体逐帧位.py
"""
import io
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
表路 = os.path.join(工程, "数据", "角色", "动画元数据.json")
出路 = os.path.join(工程, "开发工具", "_查打坐身体逐帧位.txt")

with io.open(表路, encoding="utf-8") as f:
    表 = json.load(f)

行 = []
动作文 = sys.argv[1] if len(sys.argv) > 1 else "sit0"


def 取帧列表(动):
    """动作的值可能是 {帧号: 帧} 或 [帧, ...]；统一成按帧号排序的列表。"""
    if isinstance(动, dict):
        项 = [(k, v) for k, v in 动.items()]
        项.sort(key=lambda t: int(t[0]) if str(t[0]).isdigit() else 0)
        return [v for _, v in 项]
    if isinstance(动, list):
        return list(动)
    return []


行.append("=== 族 / 角色 / 动作「%s」的逐帧注册点 ===" % 动作文)
总命中 = 0
抖角色 = []
for 族 in ("character", "npc", "mob", "pet"):
    for 号, 角 in (表.get(族, {}) or {}).items():
        if not isinstance(角, dict) or 动作文 not in 角:
            continue
        总命中 += 1
        帧们 = 取帧列表(角[动作文])
        序 = []
        for 帧 in 帧们:
            if not isinstance(帧, dict):
                continue
            # ⚠ 一帧的视觉数据在**层名底下**（实测 `{"0": {"body": {"origin","value"}}}`），
            #   直接取 `帧["origin"]` 会一律拿到默认 0 ⇒ 报出"注册点不动"的假阴性。
            #   所以这里把该帧下所有「带 origin 的层」都展开，一层一条。
            层 = [(k, v) for k, v in 帧.items() if isinstance(v, dict) and "origin" in v]
            if not 层:
                层=[("_", 帧)] if "origin" in 帧 else []
            for 层名, 视 in 层:
                o = 视.get("origin", {}) or {}
                v = 视.get("value", {}) or {}
                序.append((层名, int(o.get("x", 0)), int(o.get("y", 0)),
                           int(v.get("width", 0) or 0), int(v.get("height", 0) or 0),
                           str(v.get("className", ""))))
        if not 序:
            行.append("[%s/%s] 有动作 %s 但取不出带注册点的帧" % (族, 号, 动作文))
            continue
        ys = [s[2] for s in 序]
        xs = [s[1] for s in 序]
        极y = max(ys) - min(ys)
        极x = max(xs) - min(xs)
        标记 = "  ← 注册点逐帧在动" if (极y or 极x) else ""
        行.append("[%s/%s] %d 层帧  origin_y=%s (极差 %d)  origin_x=%s (极差 %d)%s" % (
            族, 号, len(序), ys, 极y, xs, 极x, 标记))
        if 极y or 极x:
            抖角色.append((族, 号, 极y, 极x))
        for i, s in enumerate(序):
            行.append("     %d [%s] 贴图 %dx%s 注册点(%d,%d) ⇒ 身体摆位(%d,%d) %s" % (
                i, s[0], s[3], s[4], s[1], s[2], -s[1], -s[2], s[5]))

行.append("")
行.append("=== 汇总：动作「%s」命中的角色数 = %d，注册点会动的角色数 = %d ===" % (
    动作文, 总命中, len(抖角色)))
for t in 抖角色[:20]:
    行.append("  %s/%s：y 极差 %d、x 极差 %d" % t)

with io.open(出路, "w", encoding="utf-8") as f:
    f.write("\n".join(行) + "\n")
print("写了 %d 行 → %s" % (len(行), 出路))
print("命中 %d 个角色的「%s」，其中注册点逐帧在变的 %d 个" % (总命中, 动作文, len(抖角色)))
