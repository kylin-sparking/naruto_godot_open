# -*- coding: utf-8 -*-
"""导出原版「背包/仓库扩容」每页要几个密卷 → `数据/界面/扩容需求.json`。

真值来源
--------
2.2.3 的 `dat/GameData.dat` 顶层 `Etc` 段里的两个子段：

    BeibaoKuozhan   行囊（背包）扩容
    CangKuKuoZhan   仓库扩容

各是一条 zlib 压的记录，解出来两个字段（两边取值相同）：

    itemid   = 16000004          「扩充密卷」（`数据/物品.json` 里同名同 id）
    itemCnt  = "2;6;18;54;162;496;1458;4374;13122;39366;118098;354294;1062882;3188646"

下标怎么用（以**服务端为准**，`fake_flash_server.py:25967-25968`）：

    page_index = max(0, ceil(当前容量 / 30) - 1)
    required   = costs[min(page_index, len(costs)-1)]

即**从 1 页扩到 2 页要 2 个密卷**，之后 6 / 18 / 54 …

用法
----
    python 开发工具/导出扩容需求.py
"""

import importlib.util
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
产物 = os.path.join(项目根, "数据", "界面", "扩容需求.json")
段名 = {"背包": "BeibaoKuozhan", "仓库": "CangKuKuoZhan"}


def _载入原版数据():
    路径 = os.path.join(项目根, "开发工具", "原版数据.py")
    spec = importlib.util.spec_from_file_location("原版数据", 路径)
    模块 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(模块)
    return 模块


def 主() -> int:
    工具 = _载入原版数据()
    etc = 工具.取顶层段("Etc")
    if not isinstance(etc, dict):
        raise SystemExit("GameData 里读不到 Etc 段")
    出 = {}
    for 归属, 段 in 段名.items():
        if 段 not in etc:
            raise SystemExit("Etc 段里没有 %s" % 段)
        记录 = 工具.解载荷(etc[段])
        if not isinstance(记录, dict):
            raise SystemExit("%s 解出来不是字典：%r" % (段, 记录))
        密卷id = str(记录.get("itemid", ""))
        数量串 = str(记录.get("itemCnt", ""))
        需求 = [int(项) for 项 in 数量串.split(";") if 项.strip()]
        if not 密卷id or not 需求:
            raise SystemExit("%s 缺 itemid 或 itemCnt：%r" % (段, 记录))
        出[归属] = {"密卷id": 密卷id, "每页需求": 需求}
        print("%s ← Etc.%s：密卷 %s，%d 档 %s" % (归属, 段, 密卷id, len(需求), 需求[:5]))

    os.makedirs(os.path.dirname(产物), exist_ok=True)
    内容 = {
        "_说明": "原版「格数扩展」每页要几个扩充密卷。真值来自 2.2.3 GameData 顶层 Etc 段的 "
                 "BeibaoKuozhan / CangKuKuoZhan 两条。下标用法以服务端为准："
                 "page_index = max(0, ceil(当前容量/30)-1)，required = 每页需求[page_index]。",
        "_来源": "开发工具/导出扩容需求.py",
        **出,
    }
    with open(产物, "w", encoding="utf-8", newline="\n") as 文件:
        json.dump(内容, 文件, ensure_ascii=False, indent=2)
        文件.write("\n")
    print("→", 产物)
    return 0


if __name__ == "__main__":
    sys.exit(主())
