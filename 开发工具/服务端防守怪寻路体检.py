#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""秽土转生 / 守卫木叶村 防守怪寻路的常驻体检（2026-10-29，§3.315）。

用户报修：「秽土转生，一些小怪始终不掉血，会浮空走」。
根因：防守怪的目标被写成"从刷怪门到目标门拉直线"（旧实现是 `math.hypot` 走法，
秽土转生还额外把目标改成鸣人的脚点）——直线 y 与脚下地板 y 不是一回事，
怪就贴着空中走；客户端技能命中盒按 y 框，框不到 ⇒ 永远不掉血。

真值口径：
  * 防守线 = 副本配置 `spec.lines[].portalFrom/portalTo`（`_copy_defence_routes`），
    目标就是 `portalTo`，不是鸣人（`_spawn_next_copy_wave` 里那段 edo_target 特例已删）；
  * 怪沿**脚点图**走：同层按 `foothold.y_at(x)` 给 y，换层走 `monster_path_next_edge`
    （"ground" 换层 / "ladder" 瞬移），每一帧的 y 都等于当前脚点的 y_at；
  * 走到目标 70px 内（`COPY_OBJECTIVE_ESCAPE_DISTANCE`）算进村/接近鸣人。

为什么必须在服务端验：怪的 x/y 全由夹具广播，客户端只负责贴脚点渲染
（客户端那一半在 `测试/秽土转生防守怪贴脚点回归测试.gd`）。

跑法（仓库根）：
    python -X utf8 开发工具/服务端防守怪寻路体检.py
退出码：红 > 0 ⇒ 非 0。判决只看最后一行 `汇：判 N 条 / 红 M 条`。
"""
from __future__ import annotations

import inspect
import sys
import time
from pathlib import Path

根 = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(根 / "开发工具"))

红: list[str] = []
判 = 0

## 副本 → (地图, 模板等级、取 common 那一档)。
## 秽土转生 requiredLevel 55，守卫木叶村 50 —— 取那一档的 common 怪，
## 既真实又保证 `_monster_walk_velocity` 有真实速度数据。
副本表 = {
    4: (410000000, 5500006),
    3: (407000000, 5500001),
}


def 查(条件: bool, 说明: str) -> None:
    global 判
    判 += 1
    if not 条件:
        红.append(说明)


def 造会话(夹具, 地图, 副本号: int):
    会话 = object.__new__(夹具.FakeFlashSession)
    会话.current_map = 地图
    会话.hub = None
    会话.entered_game = False
    会话.monsters = {}
    会话.active_copy_id = 副本号
    return 会话


def 走一条线(会话, 模板号: int, 源门, 目标门, 最长帧数: int = 3000):
    """从 `源门` 的地板起步，逐帧推进，返回 (帧序列, 是否到达)。"""
    地图 = 会话.current_map
    起x, 起y, 起fh = 地图.ground_position(源门.x, 源门.y, 0)
    怪 = 会话.夹具MonsterState(
        object_id=6001,
        template_id=模板号,
        x=起x,
        y=起y,
        foothold=起fh,
        target_x=目标门.x,
        target_y=目标门.y,
    )
    帧 = []
    now = time.monotonic()
    for _ in range(最长帧数):
        到 = 会话._tick_copy_objective_walk(怪, now, 0.2)
        now += 0.2
        帧.append((怪.foothold, 怪.x, 怪.y))
        if 到:
            return 帧, True
    return 帧, False


def 主() -> None:
    import 服务端目录

    夹具 = 服务端目录.加载()
    目录 = 夹具.GAME_DATA_CATALOG

    for 副本号, (地图号, 模板号) in 副本表.items():
        配置 = 目录.copy_config(副本号)
        spec = 配置.get("raw", {}).get("spec", {}) if 配置 else {}
        线表 = spec.get("lines", {}) if isinstance(spec, dict) else {}
        查(isinstance(线表, dict) and len(线表) >= 4,
           f"副本 {副本号} 应有 4 条防守线，实得 {线表 if not isinstance(线表, dict) else len(线表)}")
        地图 = 目录.get_map(地图号)
        查(地图 is not None, f"地图 {地图号} 应在 GameData 里")
        if not isinstance(线表, dict) or 地图 is None:
            continue
        会话 = 造会话(夹具, 地图, 副本号)
        会话.夹具MonsterState = 夹具.MonsterState

        for 线名, 线 in 线表.items():
            if not isinstance(线, dict):
                continue
            源 = 地图.portal_named(str(线.get("portalFrom") or ""))
            目标 = 地图.portal_named(str(线.get("portalTo") or ""))
            查(源 is not None and 目标 is not None,
               f"{副本号}/{线名} 的 portalFrom/portalTo 应都在本图上，实得 {源} → {目标}")
            if 源 is None or 目标 is None:
                continue

            # ① 目标就是线路的 portalTo（不是别的坐标）。
            查(目标.name == str(线.get("portalTo")),
               f"{副本号}/{线名} 的目标应正好是 portalTo {线.get('portalTo')}，实得 {目标.name}")

            帧, 到 = 走一条线(会话, 模板号, 源, 目标)
            查(len(帧) >= 3, f"{副本号}/{线名} 应至少走几帧，实得 {len(帧)} 帧")
            查(到, f"{副本号}/{线名} 应走到目标 70px 内（没到 ⇒ 防守失败永远不会触发）")

            # ② 每一帧的 y 等于当前脚点的 y_at —— 这是"不许浮空"的核心口径。
            离地 = []
            for 脚点号, x, y in 帧:
                地板 = 地图.footholds.get(脚点号)
                if 地板 is None:
                    离地.append((脚点号, x, y, "无此脚点"))
                elif 地板.y_at(x) != y:
                    离地.append((脚点号, x, y, 地板.y_at(x)))
            查(not 离地, f"{副本号}/{线名} 有 {len(离地)} 帧不在脚点上（前 3 条 {离地[:3]}）")

            # ③ 换了脚点必须换到真实存在的段（经过 path edge 才许换）。
            走过 = []
            for 脚点号, _, _ in 帧:
                if not 走过 or 走过[-1] != 脚点号:
                    走过.append(脚点号)
            查(all(号 in 地图.footholds for 号 in 走过),
               f"{副本号}/{线名} 走过不存在的脚点 {走过}")
            查(len(走过) >= 1, f"{副本号}/{线名} 应至少走过一块地板，实得 {走过}")

        # ④ 兜底：没有地图时才允许直线走；有地图时不该走它。
        源代码 = inspect.getsource(夹具.FakeFlashSession._tick_copy_objectives)
        查("_tick_copy_objective_walk(" in 源代码,
           f"副本 {副本号} 的防守怪必须走脚点寻路")
        查("edo_target" not in inspect.getsource(夹具.FakeFlashSession._spawn_next_copy_wave),
           f"副本 {副本号} 刷怪不许再改写目标（edo_target 已删）")

    # ⑤ 两条边界：夹取与"到点"的距离口径。
    地图 = 目录.get_map(410000000)
    地板 = 地图.footholds[6]
    会话 = 造会话(夹具, 地图, 4)
    查(会话._objective_step_x(30, -1000, 500, 地板) == 地板.left,
       "左边越界应夹到脚点左端")
    查(会话._objective_step_x(3900, 9999, 500, 地板) == 地板.right,
       "右边越界应夹到脚点右端")
    查(会话.COPY_OBJECTIVE_ESCAPE_DISTANCE == 70,
       f"到点距离应沿用 70px，实得 {会话.COPY_OBJECTIVE_ESCAPE_DISTANCE}")

    print(f"汇：判 {判} 条 / 红 {len(红)} 条")
    for 条 in 红:
        print(f"!! {条}")
    sys.exit(1 if 红 else 0)


if __name__ == "__main__":
    主()
