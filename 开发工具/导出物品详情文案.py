# -*- coding: utf-8 -*-
"""导出物品的 `detaildesc` —— `数据/物品详情文案.json`。

为什么要单独一张表
------------------
商城商品行（`CashItemCell.as:216-219`）的说明框是**两行两色**：

    "<textformat leading=\"2\"><font color=\"#00ff00\">" + detaildesc
        + "</font><br/><font color=\"#ffffff\">" + desc + "</font></textformat>"

绿字是 `detaildesc`、白字是 `desc`，都取自 `StringTool.getItemStringObject(id)`
（`com/mxw/common/tools/StringTool.as:636`），源头是 GameData 的 `String/<组>/<物品id>`。

⚠️ 我们 `数据/物品.json` 里**没有** `detaildesc`，而且那张表是
`开发工具/导出游戏数据.mjs`（node）从 GameData 生的 —— 2699 条、牵动全项目，
为两个字段去动那条管线不划算。所以这里单独导一张**只放详情文案**的窄表，
和 `数据/装备基础属性.json`、`数据/物品装备元数据.json` 是同一个路数。

实测（2026-09-26）：商城八个 String 组共 2241 条带 `desc` 的物品，其中 **1702 条（75.9%）
`detaildesc` 非空** —— 说明框那行绿字是常态、不是例外，所以值得单独导。
同一次实测还核过：我们的 `description` 与原版 `desc` **1596 条全同、0 条不同**。

用法：
    python 开发工具/导出物品详情文案.py
"""

import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据 as Y  # noqa: E402

产物 = r".\数据\物品详情文案.json"

## 商城会上的八个 String 组。别只导 XiaoHao —— 各分类的货分散在不同组里。
商城组 = ["XiaoHao", "BuffWuPin", "FuZhuWuPin", "ZhuangBei", "BaoShi",
          "LiBao", "TeShuWuPin", "RenWuWuPin"]


def 主() -> int:
    详情: dict[str, str] = {}
    for 组 in 商城组:
        try:
            段 = Y.取字符串段(组)
        except Exception as 错:  # noqa: BLE001
            print("  跳过 String/%s：%s" % (组, 错))
            continue
        if not isinstance(段, dict):
            continue
        本组 = 0
        for 键, 值 in 段.items():
            if not isinstance(值, dict):
                continue
            文本 = 值.get("detaildesc")
            if 文本:
                详情[str(键)] = str(文本)
                本组 += 1
        print("  String/%-14s 收 %d 条" % (组, 本组))

    输出 = {
        "_说明": (
            "物品的 detaildesc（商城商品行说明框里那行**绿字**）。"
            "原版 CashItemCell.as:216-219 的说明框 = 绿 detaildesc + 换行 + 白 desc；"
            "desc 已经在 数据/物品.json 的 description 里（实测 1596 条全同），"
            "detaildesc 项目里没有，故单独导成这张窄表。"
            "取值链：StringTool.getItemStringObject → GameData 的 String/<组>/<物品id>。"
            "本表**只收非空**的 —— 差不到就是没有绿字那行，与 items.json 一样按缺省处理。"
            "配套生成器：开发工具/导出物品详情文案.py。"
        ),
        "_来源": "GameData.dat → String/{XiaoHao,BuffWuPin,FuZhuWuPin,ZhuangBei,BaoShi,LiBao,TeShuWuPin,RenWuWuPin}",
        "详情": dict(sorted(详情.items())),
    }

    os.makedirs(os.path.dirname(产物), exist_ok=True)
    # ⚠️ `newline="\n"`：Windows 默认把 \n 翻成 \r\n，与本仓 .gitattributes 的
    #    `* text=auto eol=lf` 打架，会生成假 diff。
    with io.open(产物, "w", encoding="utf-8", newline="\n") as 文件:
        文件.write(json.dumps(输出, ensure_ascii=False, indent=1))
        文件.write("\n")
    print("已写出 %s（%d 条）" % (产物, len(详情)))
    for 样本 in list(详情.items())[:3]:
        print("  %s = %s" % 样本)
    return 0


if __name__ == "__main__":
    sys.exit(主())
