# -*- coding: utf-8 -*-
"""套装四灯/计数角标的悬停提示所需语言串 → `数据/界面/套装提示_文案.json`。

配方见交接文档 §3.76.5。缺键直接 raise（宁可生成失败，不自造文案）。
跑法：python 开发工具/出套装提示文案.py
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据 as _语言源  # noqa: E402

落 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                  "数据", "界面", "套装提示_文案.json")

# 出处行号都在 `EquipPane.setSeriesIcon()`（char/EquipPane.as:913-947）拼串处
键 = {
    "EQUIPMENT_SERIES_TIP": "EE:934 模板（满 12/等阶灯）",
    "EQUIPMENT_SERIES_TIP2": "EE:940 模板（未满时多两行『下阶状态』）",
    "EQUIPMENT_SERIES_TIP_ACTIVE": "EE:931 【已启动】",
    "EQUIPMENT_SERIES_TIP_UNACTIVE": "EE:931 【未启动】",
    "EQUIP_PANE_YIJIHUO": "EE:937 12/12 满格",
    "EQUIP_PANE_JIHUO_ZHONG_RED": "EE:937 红色 n/12（红=在拼 TIP2 的 %2）",
    "EQUIP_PANE_JIHUO_ZHONG_GRAY": "EE:943 灰色 (n+1)/12",
    "EQUIPMENT_SERIES_DATA_NAME_1": "CN:9938 等阶套装",
    "EQUIPMENT_SERIES_DATA_NAME_2": "CN:9941 全紫套装",
    "EQUIPMENT_SERIES_DATA_NAME_3": "CN:9944 满星套装",
    "EQUIPMENT_SERIES_DATA_NAME_4": "CN:9947 六级满融套装",
    "EQUIPMENT_SERIES_DATA_DESC_1": "CN:9940 启动条件①",
    "EQUIPMENT_SERIES_DATA_DESC_2": "CN:9943 启动条件②",
    "EQUIPMENT_SERIES_DATA_DESC_3": "CN:9946 启动条件③",
    "EQUIPMENT_SERIES_DATA_DESC_4": "CN:9949 启动条件④",
    # 效果行的属性中文名（ItemFactory.SUB_ATTR_TYPE_NAMES :31-35；index0=money 在原版就是空名）
    "ITEM_ATTR_NAME_MAXHP": "IFN:35", "ITEM_ATTR_NAME_MAXMP": "IFN:35",
    "ITEM_ATTR_NAME_MAXTP": "IFN:35", "ITEM_ATTR_NAME_ATK": "IFN:35",
    "ITEM_ATTR_NAME_DEF": "IFN:35", "ITEM_ATTR_NAME_BSK": "IFN:35",
    "ITEM_ATTR_NAME_AVD": "IFN:35", "ITEM_ATTR_NAME_ATK_SPEED": "IFN:35",
    "ITEM_ATTR_NAME_WLK_SPEED": "IFN:35",
    "ITEMFACTORY_SKILL_LEVEL": "IFN:35", "ITEMFACTORY_ATK_TATE": "IFN:35",
    "ITEMFACTORY_DAMAGE_REFLECT": "IFN:35", "ITEMFACTORY_DAMAGE_REDUCE": "IFN:35",
    "ITEMFACTORY_IGNORE_DEF": "IFN:35", "ITEMFACTORY_ANQI_TRIGGER": "IFN:35",
    "ITEMFACTORY_MOB_EXP": "IFN:35",
}

if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    表 = {}
    for 档 in ("core", "ui", "message"):
        for k, v in _语言源.读语言表(档).items():
            if isinstance(v, str):
                表.setdefault(k, v)
    出 = {}
    for k, 处 in 键.items():
        if k not in 表:
            raise SystemExit("语言表缺键：" + k)
        出[k] = {"文": 表[k], "出处": 处}
    with io.open(落, "w", encoding="utf-8") as f:
        json.dump(出, f, ensure_ascii=False, indent=1)
    print("写了 %d 键 → %s" % (len(出), os.path.relpath(落, os.getcwd())))
