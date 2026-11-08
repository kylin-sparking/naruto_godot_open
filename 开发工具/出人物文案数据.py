# -*- coding: utf-8 -*-
"""抽人物信息区九条悬停提示 → `数据/界面/人物_文案.json`。

规矩（和 `出意志文案数据.py` / `出副本文案数据.py` 同一条）：**这些串只许有一份**。
控制器、量具各抄一遍迟早和语言表对不上 ⇒ 运行期/量具都读这个 JSON，
键名就是原版键名，一眼能回查出处。**缺键直接 raise**，宁可生成失败也不自造文案。

出处：`CharPane.as:197-216 setToolTip()` 一共挂十处，其中八处用的就是这里的键
（`CHARACTOR_*_TIP`），另外两处的正文是**带数的动态串**（`EXP_TIP2` / `BREATH_TIP2`，
经 `CN.replaceString` 填 `%1/%2`）。第九条 `YIZHI_YIZHILI_LABEL` 不在这里 ——
它在 `意志_文案.json`，与意志背包窗「意志值框」那条提示**同一份串**，不抄第二遍。

用法：python 开发工具/出人物文案数据.py
"""
import io
import json
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据  # noqa: E402

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
落 = os.path.join(工程, "数据", "界面", "人物_文案.json")

## 键 → AS3 取词处（宿主控件写在注释里，接错宿主一眼能看出来）。
键表 = [
    "CHARACTOR_POPULAR_TIP",	# CharPane:205  fameCell.mInfoLabel
    "CHARACTOR_FAMILY_TIP",		# :206  familyCell.mInfoLabel
    "CHARACTOR_SPOUSE_TIP",		# :207  spouseCell.mInfoLabel
    "CHARACTOR_EXP_TIP",		# :208  expBar.mLabel
    "CHARACTOR_BREATH_TIP",		# :209  breathBar.mLabel
    "CHARACTOR_HP_TIP",			# :210  hpBar.mLabel
    "CHARACTOR_MP_TIP",			# :211  mpBar.mLabel
    "CHARACTOR_EXP_TIP2",		# :81  expBar.tf（%1=current %2=total，MOUSE_OVER 刷新）
    "CHARACTOR_BREATH_TIP2",	# :274  breathBar.tf（同上）
]


def 主():
    表 = 原版数据.读语言表("message")
    得, 缺 = {}, []
    for 键 in 键表:
        值 = 表.get(键)
        if 值 is None:
            缺.append(键)
        else:
            得[键] = 值
    if 缺:
        print("!! 语言表里没找到这些键：%s" % 缺)
        raise SystemExit(1)
    得["_出处"] = ("原版 AS3 语言表 en_US$message_properties.as（%s），由 "
                    "开发工具/出人物文案数据.py 抽取；别手改本文件" % 原版数据.反编译目录)
    os.makedirs(os.path.dirname(落), exist_ok=True)
    io.open(落, "w", encoding="utf-8", newline="\n").write(
            json.dumps(得, ensure_ascii=False, indent=1, sort_keys=True) + "\n")
    print("出 %s：%d 条" % (os.path.relpath(落, 工程), len(得) - 1))
    for 键 in 键表:
        print("  %s = %s" % (键, 得[键]))


if __name__ == "__main__":
    主()
