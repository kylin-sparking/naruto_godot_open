# -*- coding: utf-8 -*-
"""导出忍具（`65000001..65000013`）的名字/文案/图标落点 —— `数据/忍具文案.json`。

为什么要单独一张表
------------------
忍具这一族**不在** `数据/物品.json` 里：那张表由 `开发工具/导出游戏数据.mjs` 从 GameData 的
15 个物品分组成，`RenJu` 不是其中之一（`:312-314` 那句注释记着这件事）。于是 13 件忍具在客户端
只活在 `数据/忍具.json` 的 `info` 里 —— 有属性、有图标符号名，**没有名字、没有文案**。

后果是用户报修 14（#81）实测到的那一副样子：活动大使「兑换忍具」真把 `65000001` 发进背包了
（`忍具兑换在线回归测试.gd` 的 L5 已验：六碎片各扣 1、八咫镜 ×1 进包、窗关掉），但玩家看到的
背包格是 **空图标 + 名字叫「65000001」+ 提示框一片空白** —— 和"这功能没实装"长得一模一样。

原版的取值链是 `RenJuData.as:31-36` 的 `itemDescObj`，源头就是 GameData 的
`String/RenJu/<id>`（`{name, desc, detaildesc}`）；`ItemData.as:100/:263` 里"名字兜底成裸 id"
只是**最后一道兜底**，不是原版的显示值。本工程从没导过这一段 ⇒ 补这张窄表。

⚠️ 别把它并进 `数据/物品.json` / `物品图标索引.json`：
  · `物品图标回归测试.gd` 钉死「索引条数 + 缺失条数 == 物品总数」，多塞 13 条会把它顶红；
  · 物品.json 由 node 管线整份重生成，手改一次、下次导出又没了。
  ⇒ 走 `脚本/单例/游戏数据.gd` 里 `item / item_name / item_detail / item_icon_path` 四处的
     **回退**（查完物品表没有，再查忍具段），和 `数据/物品详情文案.json` 是同一个路数。

图标只收**已直解出来**的那些：`忍具.json` 的 `info.icon.className` 拿去
`数据/原版直解清单.json` 查落点。2026-10-24 实测：13 件里只有 `LingQi_20100002_info_icon`
（= 65000001 八咫镜）那枚符号被手工直解过，其余 12 件的 swf 还没解 ⇒ `icon` 留空串，
`游戏数据.item_icon_path` 就照常回空 —— 那是**素材缺口**，不是代码缺口，别在代码里编图。

用法：
    python 开发工具/导出忍具文案.py
"""

import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据 as Y  # noqa: E402

仓根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
忍具段 = os.path.join(仓根, "数据", "忍具.json")
直解表 = os.path.join(仓根, "数据", "原版直解清单.json")
产物 = os.path.join(仓根, "数据", "忍具文案.json")


def _读(路: str) -> dict:
    with io.open(路, encoding="utf-8") as f:
        return json.loads(f.read().lstrip("\ufeff"))


def 主() -> int:
    段 = Y.取字符串段("RenJu")
    忍具 = _读(忍具段)
    直解 = _读(直解表)

    出: dict[str, dict] = {}
    有图 = 0
    for 号, 文案 in sorted(段.items()):
        号 = str(号)
        if not isinstance(文案, dict):
            continue
        信息 = ((忍具.get(号) or {}).get("info") or {})
        符号 = str(((信息.get("icon") or {}).get("value") or {}).get("className", ""))
        条目 = 直解.get(符号, {}) if 符号 else {}
        落点 = str(条目.get("落点", "")) if str(条目.get("清单", "")) == "物品图标" else ""
        # 键保持**裸号**（`65000001`，与 String/RenJu、忍具.json 一致）；补零形态由查表的回退自己处理。
        出[号] = {
            "name": str(文案.get("name", "")),
            "desc": str(文案.get("desc", "")),
            "detaildesc": str(文案.get("detaildesc", "")),
            "icon": 落点,
            "icon符号": 符号,
        }
        有图 += 1 if 落点 else 0
        print("  %-9s %-14s 图标%s" % (号, 出[号]["name"], "有" if 落点 else "无（swf 未直解）"))

    输出 = {
        "_说明": (
            "忍具（GameData `RenJu` 那 13 件，65000001..65000013）的名字与文案。"
            "这一族不在 数据/物品.json 里（导出管线只并 15 个物品分组，见 开发工具/导出游戏数据.mjs:312-314），"
            "原版客户端是从 GameData 的 String/RenJu/<id> 取 name/desc/detaildesc 的"
            "（RenJuData.as:31-36 的 itemDescObj）。不补这一段，兑换到手的八咫镜在背包里就是"
            "「空图标 + 名字叫 65000001 + 提示框空白」。消费点：脚本/单例/游戏数据.gd 的 "
            "item / item_name / item_detail / item_icon_path 四处回退。"
            "icon 是 info.icon.className 拿去 数据/原版直解清单.json 查到的落点；"
            "只有已直解的符号才有值（2026-10-24：仅 LingQi_20100002_info_icon = 65000001）。"
            "配套生成器：开发工具/导出忍具文案.py。"
        ),
        "_来源": "GameData.dat → String/RenJu + RenJu.info.icon.className × 数据/原版直解清单.json",
        "忍具": 出,
    }
    with io.open(产物, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(输出, ensure_ascii=False, indent=1))
        f.write("\n")
    print("已写出 %s（%d 条，其中 %d 条有已直解图标）" % (产物, len(出), 有图))
    return 0


if __name__ == "__main__":
    sys.exit(主())
