# -*- coding: utf-8 -*-
"""从 AS3 语言表 `en_US$message_properties.as` 抽 YIZHI_* 键 → `数据/界面/意志_文案.json`。

为什么单独一个文件：这些串**只许有一份**。控制器、量具、生成器各抄一遍，
迟早和语言表对不上（本工程已经因 `说明原文` 抄两遍写坏过转义）。
运行期/量具都读这个 JSON，键名就是原版键名 ⇒ 一眼能回查出处。

扫描按字符走、认反斜杠转义，不用正则（正则在 shell 里被转过一次就废）。

用法：python 开发工具/出意志文案数据.py
"""
import io
import json
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
## 语言表寻径：优先 NARUTO_LANG_SOURCE，否则按 2.2.3 目录下的两种解包位置找。
原版根 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(工程, "..", "2.2.3")
源候选 = [
    os.environ.get("NARUTO_LANG_SOURCE", ""),
    os.path.join(原版根, "map_extract", "out", "mainlib_as", "scripts", "en_US$message_properties.as"),
    os.path.join(原版根, "tools", "mainlib_scripts", "scripts", "en_US$message_properties.as"),
]
源 = next((p for p in 源候选 if p and os.path.isfile(p)), "")
出 = os.path.join(工程, "数据", "界面", "意志_文案.json")

## 要哪些键（意志学习页 + 它的召唤弹窗/意志背包/意志介绍 全用得上）。
## 少一个键就报错退出，免得运行期才发现"咦这句是编的"。
键表 = [
    "YIZHI_STUDY_WINDOW_TITLE", "YIZHI_TODAY_STUDY_DESC", "YIZHI_LEAVE_DESC",
    "YIZHI_YUELI_ICON_TIP", "YIZHI_OPEN_PACK_TOOLTIP", "YIZHI_SELL_BUTTON_NAME",
    "YIZHI_SHI_QU_BUTTON_NAME", "YIZHI_ZHAOHUAN_BUTTON_NAME",
    "YIZHI_ZHAO_HUAN_NPC_DILOG_TEXT", "YIZHI_ZHAO_HUAN_NPC_DILOG_CHECK_TEXT",
    "YIZHI_NPC_ZHAOHUAN_FINISHED", "YIZHI_ZHAN_HUAN_NPC_TIP", "YIZHI_STUDY_FEI_YONG",
    "YIZHI_PACK_WINDOW_TITLE", "YIZHI_DRAG_PROMPT_LABEL", "YIZHI_INTRODUCE_LABEL",
    "YIZHI_YI_JIAN_HECHENG_BUTTON_NAME", "YIZHI_STUDY_BUTTON_NAME",
    "YIZHI_YIZHILI_LABEL", "YIZHI_YI_ZHI_EXP", "YIZHI_DETALI_TEXT",
    "YIZHI_DETALI_YELLOW_TEXT", "YIZHI_CELL_OPEN_TOOLTIP", "YIZHI_EXPAND_PACK_CELL",
    "YIZHI_NO_ENOUGH_YUANBAO_TIP", "YIZHI_NO_ENOUGH_YUELI_TIP", "YIZHI_RONGHE_TIP",
    "YIZHI_RONGHE_TIP_1", "YIZHI_MAX_LEVEL_NOT_RONGHE",
    "YIZHI_YELLOW_NOT_RONGHE", "YIZHI_YELLOW_NOT_CHUAN_DAI",
    "YIZHI_ZIDONG_HECHENG", "YIZHI_STUDY_BUTTON_NAME",
    # 意志格提示 `YiZhiTip:87` 用的**非 YIZHI 前缀**键（`:969`「价格」）
    "PERSONAL_SHOP_PRICE",
]


def 取值(文, 键):
    """取 `"KEY": "value",` 里的 value 并按 AS3 转义还原。"""
    标 = '"%s"' % 键
    i = 文.find(标)
    if i < 0:
        return None
    j = 文.find(":", i + len(标))
    k = 文.find('"', j)
    出, p, 透 = [], k + 1, False
    while p < len(文):
        c = 文[p]
        if 透:
            出.append({"n": "\n", "r": "\r", "t": "\t"}.get(c, c))
            透 = False
        elif c == "\\":
            透 = True
        elif c == '"':
            return "".join(出)
        else:
            出.append(c)
        p += 1
    return None


def 主():
    if not 源:
        print("!! 找不到语言表 en_US$message_properties.as（候选：%s）" % 源候选)
        raise SystemExit(1)
    print("语言表 = %s" % 源)
    文 = io.open(源, encoding="utf-8", errors="replace").read()
    得, 缺 = {}, []
    for 键 in 键表:
        值 = 取值(文, 键)
        if 值 is None:
            缺.append(键)
        else:
            得[键] = 值
    if 缺:
        print("!! 语言表里没找到这些键：%s" % 缺)
        raise SystemExit(1)
    得["_出处"] = ("原版 AS3 语言表 en_US$message_properties.as，由 "
                    "开发工具/出意志文案数据.py 抽取；别手改本文件")
    os.makedirs(os.path.dirname(出), exist_ok=True)
    io.open(出, "w", encoding="utf-8", newline="\n").write(
            json.dumps(得, ensure_ascii=False, indent=1, sort_keys=True) + "\n")
    print("出 %s：%d 条" % (os.path.relpath(出, 工程), len(得) - 1))
    for 键 in ["YIZHI_ZHAO_HUAN_NPC_DILOG_TEXT", "YIZHI_ZHAO_HUAN_NPC_DILOG_CHECK_TEXT",
               "YIZHI_ZHAN_HUAN_NPC_TIP", "YIZHI_STUDY_FEI_YONG"]:
        print("  %s = %s" % (键, 得[键]))


if __name__ == "__main__":
    主()
