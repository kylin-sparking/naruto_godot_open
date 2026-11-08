# -*- coding: utf-8 -*-
"""导出「火影有礼」详情窗（`SelectGiftWindow.as`）需要的 LiBao 预览配置。

真值源：`GameData.dat` 的 `LiBao` 段（每条是 zlib 压缩的 AMF3）。
只导出 `info.preview == 1` 的礼包 —— 原版 `ItemWindow2.as:990-1017`
只在 `StringTool.isPreviewLibao(id)` 为真时才弹详情窗；其余礼包直接使用。

输出 `数据/礼包详情.json`：
    {礼包id: {
        "preview": 1,
        "type": "libao" | "libao_fufei" | "libao_select",
        "req_level": int,
        "money": {"point": int, "cash": int, "cashbind": int, "itemid": int},
        "items": {"0": [{id,count,star,aptitude,weight,bind,pub}, ...], ...}
    }}

`items` 的职业组键是原版数字组（"0"/"100"/"200"/"300"/"400"）；组内按
AVM2 的数字键序排（与 `UI.as` 的 `for(_loc10_ in _loc7_)` 一致）。客户端按
「0 + 本职业组」取，详情窗只展示当前职业能拿到的那一组。
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 原版数据 import 取顶层段, 解载荷  # noqa: E402

根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
输出 = os.path.join(根, "数据", "礼包详情.json")


def _数字键序(键: str) -> tuple[int, int | str]:
    文本 = str(键)
    if 文本.lstrip("-").isdigit():
        return (0, int(文本))
    return (1, 文本)


def _取整(值, 默认: int = 0) -> int:
    try:
        return int(值)
    except (TypeError, ValueError):
        return 默认


def _整理物品组(组) -> dict:
    if not isinstance(组, dict):
        return {}
    出: dict = {}
    for 组名 in sorted(组, key=_数字键序):
        行们 = 组.get(组名)
        if not isinstance(行们, dict):
            continue
        行: list = []
        for 槽号 in sorted(行们, key=_数字键序):
            条 = 行们.get(槽号)
            if not isinstance(条, dict):
                continue
            物号 = _取整(条.get("id"))
            if 物号 <= 0:
                continue
            行.append({
                "slot": _取整(槽号),
                "id": 物号,
                "count": max(1, _取整(条.get("count"), 1)),
                "star": _取整(条.get("star")),
                "aptitude": _取整(条.get("aptitude")),
                "weight": _取整(条.get("weight"), 100),
                "bind": _取整(条.get("bind")),
                "pub": _取整(条.get("pub")),
            })
        出[str(组名)] = 行
    return 出


def main() -> int:
    libao = 取顶层段("LiBao")
    if not isinstance(libao, dict):
        print("LiBao 段不是字典", file=sys.stderr)
        return 1
    出: dict = {}
    for 原始id, 载荷 in libao.items():
        if isinstance(载荷, bytes):
            条 = 解载荷(载荷)
        else:
            条 = 载荷
        if not isinstance(条, dict):
            continue
        info = 条.get("info") if isinstance(条.get("info"), dict) else {}
        spec = 条.get("spec") if isinstance(条.get("spec"), dict) else {}
        if _取整(info.get("preview")) != 1:
            continue
        params = spec.get("params") if isinstance(spec.get("params"), dict) else {}
        money = params.get("money") if isinstance(params.get("money"), dict) else {}
        出[str(原始id)] = {
            "preview": 1,
            "type": str(spec.get("type") or ""),
            "req_level": max(0, _取整(info.get("reqLevel"))),
            "money": {
                "point": _取整(money.get("point")),
                "cash": _取整(money.get("cash")),
                "cashbind": _取整(money.get("cashbind")),
                "itemid": _取整(money.get("itemid")),
            },
            "items": _整理物品组(params.get("items")),
        }
    出 = {键: 出[键] for 键 in sorted(出, key=_数字键序)}
    with open(输出, "w", encoding="utf-8", newline="\n") as 流:
        json.dump(出, 流, ensure_ascii=False, indent=1, sort_keys=False)
        流.write("\n")
    print("已写 %s：%d 条预览礼包" % (输出, len(出)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
