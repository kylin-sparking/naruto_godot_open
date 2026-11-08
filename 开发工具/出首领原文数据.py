# -*- coding: utf-8 -*-
"""从 AS3 语言表解出「首领」页用到的原文，落 `数据/界面/首领_文案.json`。

为什么单独一个文件：本页有 **两个 U+3000 全角空格**（`WANG_BOSS_CELL_LEVEL = 等　　级：`）
和一段带 `\"` 转义的 HTML（`WANG_BOSS_TIP`）。把它们抄进 .gd / .tscn 迟早被编辑器吃掉，
所以照 `开发工具/出意志原文数据.py` 的老办法：**语言表是唯一出处**，
量具（`截首领页.gd`）与生成器（`生成首领场景.py`）共读这一份 JSON。

键表来源：`WangBossWindow.as` / `WangBossCell.as` 里出现过的全部 `CN.*` 与 `LangUtil.get("*")`。
`CN.*` 走 `LangUtil.get` ⇒ `message` 资源包（`LangUtil.as:26-38`）；
`en_US$ui_properties.as`（`LangUtilUI` 读的那张）**没有任何 WANG_BOSS 键**（已 grep 核实）。

用法：python 开发工具/出首领原文数据.py
"""
import io
import json
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版根 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(os.path.dirname(工程), "2.2.3")
语言候选 = [
    os.environ.get("NARUTO_LANG_SOURCE", ""),
    os.path.join(原版根, "map_extract", "out", "mainlib_as", "scripts", "en_US$message_properties.as"),
    os.path.join(原版根, "tools", "mainlib_scripts", "scripts", "en_US$message_properties.as"),
]
语言表 = next((p for p in 语言候选 if p and os.path.isfile(p)), "")
出 = os.path.join(工程, "数据", "界面", "首领_文案.json")

# 本页用到的键（顺序即文案表顺序）。值 = 用到的地方（AS3 行号见真值表 §3）。
键表 = {
    "WANG_BOSS_TITLE": "WangBossWindow.as:36 窗口标题",
    "WANG_BOSS_CELL_LEVEL": "WangBossCell.as:190/327 等级标签",
    "WANG_BOSS_REFURBISH_MAP": "WangBossCell.as:205/328 地图标签",
    "WANG_BOSS_REFURBISH_TIMER": "WangBossCell.as:223/329 时间标签",
    "WANG_BOSS_INSTRUCTION": "WangBossCell.as:238/330 爆率标签",
    "WANG_BOSS_CELL_JI": "WangBossCell.as:101 等级数值模板（LangUtil.get，非 CN 常量）",
    "WANG_BOSS_NOT_DIED": "WangBossCell.as:105 时间数值（alive=true）",
    "WANG_BOSS_KILL": "WangBossCell.as:108/112 地图数值与挑战钮的 tooltip",
    "WANG_BOSS_TIP": "WangBossCell.as:133 头像 tooltip（%1=简介 %2=掉落）",
}


def 解串(正文: str, 键: str):
    """取 `"键":"值"` 的值并还原 AS3 转义；返回 (值, 行号)。"""
    m = re.search(r'^\s*"%s"\s*:\s*"((?:[^"\\]|\\.)*)"' % re.escape(键), 正文, re.M)
    if not m:
        return None, None
    原 = m.group(1)
    值 = re.sub(r"\\.", lambda mm: {"n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\"}
                .get(mm.group(0)[1:], mm.group(0)[1:]), 原)
    值 = re.sub(r"\\u([0-9a-fA-F]{4})", lambda mm: chr(int(mm.group(1), 16)), 值)
    return 值, 正文[:m.start()].count("\n") + 1


def 主():
    正文 = io.open(语言表, encoding="utf-8").read()
    文案, 缺 = {}, []
    for 键, 用途 in 键表.items():
        值, 行 = 解串(正文, 键)
        if 值 is None:
            缺.append(键)
            continue
        文案[键] = {"值": 值, "行": 行, "用途": 用途}
    if 缺:
        print("!! 语言表里没找到:", 缺)
        return 1
    # 三条自检：全角空格数、模板占位、HTML 标记 —— 转义还原错了这里就会红
    assert 文案["WANG_BOSS_CELL_LEVEL"]["值"] == "等　　级：", "等级标签的全角空格不对"
    assert "%1" in 文案["WANG_BOSS_TIP"]["值"] and "%2" in 文案["WANG_BOSS_TIP"]["值"]
    assert '"#ff9100"' in 文案["WANG_BOSS_TIP"]["值"], "WANG_BOSS_TIP 的引号没还原"
    出数据 = {
        "说明": "首领（原版 WangBossWindow/WangBossCell）文案。唯一出处 = "
                "`game-client/原版源码/反编译脚本/MainLib/scripts/en_US$message_properties.as`。"
                "由 `开发工具/出首领原文数据.py` 生成，量具与场景生成器共读，别手改。",
        "表": "message（LangUtil.get）；ui 表（LangUtilUI）无本页键",
        "文案": 文案,
    }
    os.makedirs(os.path.dirname(出), exist_ok=True)
    with io.open(出, "w", encoding="utf-8", newline="\n") as f:
        json.dump(出数据, f, ensure_ascii=False, indent=1)
    for 键 in 键表:
        print("%-28s :%s  %s" % (键, 文案[键]["行"], 文案[键]["值"].replace("\n", "\\n")))
    print("写 %s" % os.path.relpath(出, 工程))
    return 0


if __name__ == "__main__":
    sys.exit(主())
