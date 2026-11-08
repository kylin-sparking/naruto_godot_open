# -*- coding: utf-8 -*-
"""把原版每个怪的**头像**解出来，并生成客户端查表要用的元数据。

为什么单独写
------------
目标提示框（头像面板的「选中人物信息」）里那个圆框，原版放的是怪的头像：
`Client.onTargetInfo()` → `DetailsWindow.setPic()` → `PortraitHead(TYPE_MONSTER).skin = 怪id`
→ `PicTool.getMonsterObject(id).info.portrait` —— 类名就是 `Mob_<id>_info_portrait`，
原版客户端里**每个怪都有一份专门的库** `www/act_web_nya_208_isolated/swf/Mob/Mob_<id>_info_portrait.swf`。

我们这边这张图**一个都没有**（`素材/角色动画/怪物/` 里只有动作帧），
也没有 `info.portrait` 的元数据（`导入怪物动画.mjs` 的 `动作键()` 把 `info` 一起过滤掉了）——
所以框里一直是个空圈（用户 2026-09-27 第七、八段连着报了两次）。

产物
----
1. `素材/原版直解/Mob/<库名>.swf_<chid>_<类名>.png`（沿用直解包的命名口径，导入器直接能扫）
2. `数据/角色/怪物头像.json`  {怪id: {"class": 类名, "origin": {x,y}}}  ← origin 取自 GameData 的
   `Mob[].info.portrait.origin`，是**头像在 PNG 里的注册点**，和角色/ NPC 那套同一口径。

用法
----
    python 开发工具/导出怪物头像.py [--ffdec 路径] [--only 1000001,1000002]
"""

import argparse
import io
import json
import os
import re
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版根 = os.environ.get("NARUTO_GAME_ROOT", r"2.2.3")
默认ffdec = os.path.join(原版根, "ffdec_26.2.1", "ffdec-cli.exe")
头像库目录 = os.path.join(原版根, "www", "act_web_nya_208_isolated", "swf", "Mob")
产物目录 = os.path.join(项目根, "素材", "原版直解", "Mob")
元数据 = os.path.join(项目根, "数据", "角色", "怪物头像.json")


def 取原版头像元数据() -> dict:
    """从 2.2.3 的 GameData 里取每个怪的 `info.portrait`（类名 + 注册点）。"""
    sys.path.insert(0, os.path.join(原版根, "tools"))
    import fake_flash_server as fs  # noqa: PLC0415

    数据文件 = os.path.join(原版根, "www", "act_web_nya_208_isolated", "dat", "GameData.dat")
    with open(数据文件, "rb") as handle:
        根 = fs.Amf3Reader(handle.read()).read_value()
    目录 = fs.GAME_DATA_CATALOG
    Mob段 = 目录._decode_section(根["Mob"])
    结果 = {}
    for 编号, 节点 in Mob段.items():
        记录 = 目录._decode_section(节点)
        if not isinstance(记录, dict):
            continue
        info = 记录.get("info")
        if not isinstance(info, dict):
            continue
        头像 = info.get("portrait")
        if isinstance(头像, dict) and isinstance(头像.get("value"), dict):
            类名 = str(头像["value"].get("className", ""))
            if 类名:
                原点 = 头像.get("origin") or {}
                结果[str(编号)] = {
                    "class": 类名,
                    "origin": {"x": int(原点.get("x", 0)), "y": int(原点.get("y", 0))},
                }
    return 结果


def main() -> int:
    解析 = argparse.ArgumentParser()
    解析.add_argument("--ffdec", default=默认ffdec)
    解析.add_argument("--only", default="", help="逗号分隔的怪编号，只导这些")
    参数 = 解析.parse_args()

    if not os.path.isfile(参数.ffdec):
        print("找不到 ffdec：%s（可用 --ffdec 指定）" % 参数.ffdec)
        return 1
    if not os.path.isdir(头像库目录):
        print("找不到原版头像库目录：%s" % 头像库目录)
        return 1

    只导 = {项.strip() for 项 in 参数.only.split(",") if 项.strip()}
    元数据表 = 取原版头像元数据()
    os.makedirs(产物目录, exist_ok=True)

    成功 = []
    失败 = []
    跳过 = []
    for 编号 in sorted(元数据表):
        if 只导 and 编号 not in 只导:
            continue
        类名 = 元数据表[编号]["class"]
        源 = os.path.join(头像库目录, 类名 + ".swf")
        目标 = os.path.join(产物目录, "%s.swf_1_%s.png" % (类名, 类名))
        if not os.path.isfile(源):
            失败.append((编号, "原版没有这个库"))
            continue
        if os.path.isfile(目标):
            跳过.append(编号)
            continue
        临时 = os.path.join(产物目录, "_tmp_" + 类名)
        os.makedirs(临时, exist_ok=True)
        try:
            subprocess.run(
                [参数.ffdec, "-format", "image:png", "-export", "image",
                 临时.replace("\\", "/"), 源.replace("\\", "/")],
                capture_output=True, timeout=60,
            )
        except Exception as 错:  # noqa: BLE001
            失败.append((编号, str(错)[:60]))
            continue
        # ffdec 会导成 <chid>.png 或 <类名>.png，取里面那张拷成项目口径的名字
        候选 = [f for f in os.listdir(临时) if f.lower().endswith(".png")]
        if not 候选:
            失败.append((编号, "ffdec 没导出 PNG"))
            continue
        最大 = max(候选, key=lambda f: os.path.getsize(os.path.join(临时, f)))
        with open(os.path.join(临时, 最大), "rb") as 源图, open(目标, "wb") as 目标图:
            目标图.write(源图.read())
        for f in 候选:
            os.remove(os.path.join(临时, f))
        os.rmdir(临时)
        成功.append(编号)

    io.open(元数据, "w", encoding="utf-8").write(
        json.dumps(元数据表, ensure_ascii=False, sort_keys=True)
    )
    print("头像元数据 %d 条 -> %s" % (len(元数据表), 元数据))
    print("这次导出 %d 张（已有跳过 %d），失败 %d" % (len(成功), len(跳过), len(失败)))
    if 失败:
        print("失败样本：%s" % 失败[:6])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
