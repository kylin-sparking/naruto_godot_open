# -*- coding: utf-8 -*-
"""导出原版 `GameData.dat` 里 **`BangHui` 整段** —— `数据/家族.json`。

为什么需要它
------------
家族这一块有好几张表，以前**一直以为没有**（都当"运行时图像包/服务端才有"），
其实**就在 `GameData.dat` 的 `BangHui` 段里**（2026-10-01 用户一句"去服务端找啊"找到的）：

| 键 | 是什么 | 谁在用 |
|---|---|---|
| `cost` | **家族令牌窗的判定表**：`contri.item[*].id` = 五种可捐献的书（16000022..16000026） | `ZhuGongLingWindow.validateItem`（`ZGL.as:63-84`） |
| `flagmap` | **家族领域战地图表**：每图的 mapid/x/y/childmaps | `FamillyManager.getFamillyWarMaps`（`FM.as:529-532`）→ 旗帜窗「族旗安插列表」的行 |
| `flag` | 家徽每一级的 `hp/attr/mapattr/cost/info` | 家族升级窗（`FF.as` 的 `getFamillyUpgradeCfg`） |
| `war` | 领域战开放时间、公告文案、掉落 | 旗帜窗/系统提示 |
| `boss` | 家族尾兽的等级段、奖励、开放时间 | 家族守卫窗（`FP.as`） |
| `flagStyle` | **200 个家徽样式 → 图在哪个 swf**（`swfName` + `className`） | `PicTool.getJiaHuiPic`；图标本体见 `开发工具/导出家族家徽.py` |

⚠️ 以前把它们当成"运行时 HTTP 下发的 `dat/BangHui/*.dat`"（`ImgUtil.getImg(ImgType.BangHui, …)`
→ `DatLoadItem.getDatUrl`），而单机包的 `dat/` 里确实没有那几个文件 —— 于是判定为"拿不到"。
**漏的是**：`ImgManager` 那份运行时数据是从服务端拉的，但**同一份表在 `GameData.dat` 里也有**，
客户端启动时会先灌进 `GAME_DATA_CATALOG.raw_banghui`。**先查 GameData 再喊"没有"。**

用法：
    python 开发工具/导出家族配置.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据 as Y  # noqa: E402

产物 = r".\数据\家族.json"

## `BangHui` 段里要留的键（其余的是各等级的行，已含在 `flag` 里）
要的键 = ["cost", "flagmap", "flag", "war", "boss", "flagStyle"]


def 主() -> int:
    段 = Y.取顶层段("BangHui")
    if not isinstance(段, dict):
        print("!! GameData 里没有 BangHui 段（或形状不是字典）")
        return 1
    出: dict = {}
    for 键 in 要的键:
        if 键 not in 段:
            print(f"!! BangHui 里没有 `{键}`")
            continue
        值 = Y.解载荷(段[键])
        # `flagStyle` 的 icon.value 里只有 swfName/className（图本体在 swf 里），原样留。
        出[键] = 值
        print(f"  {键}: {type(值).__name__} "
              f"{len(值) if hasattr(值, '__len__') else 值}")
    # 顺带核一下令牌判定表：这五个 id 就是可以捐的书
    书 = sorted(int(v["id"]) for v in 出.get("cost", {}).get("contri", {}).get("item", {}).values())
    print(f"  可捐献的书（cost.contri）= {书}")
    with open(产物, "w", encoding="utf-8") as f:
        json.dump(出, f, ensure_ascii=False, indent=1)
    print(f"[家族] 已写 {产物}（{os.path.getsize(产物)} 字节）")
    return 0


if __name__ == "__main__":
    sys.exit(主())
