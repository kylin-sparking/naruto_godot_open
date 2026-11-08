# -*- coding: utf-8 -*-
"""抽「纲手三窗」要用的语言表键 → `数据/界面/副本_文案.json`。

规矩（和 `出意志文案数据.py` 同一条）：**这些串只许有一份**。控制器、量具、生成器
各抄一遍迟早和语言表对不上 ⇒ 三方都读这个 JSON，键名就是原版键名，一眼能回查出处。
**缺键直接 raise**，宁可生成失败也不自造文案。

`CN.replaceString(串, a, b)` 的占位符是 `%1` / `%2`（`CN.as`），运行期替换。

用法：python 开发工具/出副本文案数据.py
"""
import io
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据  # noqa: E402

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
落 = os.path.join(工程, "数据", "界面", "副本_文案.json")

## 三扇窗 + 它的行/格控件全用得上。注释里是 AS3 取词处。
键表 = [
    "COPY_WINDOW_TITLE",		# CopyWindow.as:138  title
    "COPY_NAME",			# :139  列头「副本名称」
    "PETWINDOW_LEVEL",		# :142  列头「等级」
    "TROOP_TITLE",			# :145  列头「组队」
    "COPYWINDOW_COUNT",		# :148  列头「次数」
    "COPY_MEED",			# :157  「副本内奖励丰厚度：」
    "COPY_TONGGUAN_JIANGLI",		# :186  「通关奖励：」
    "COPY_MCHECK",			# :222  「只显示我可以参与的副本」
    "COPY_JINRU",			# :239  「进入」
    "COPY_MIJUAN_JINRU",		# :247  「副本密卷进入」
    "FUBENLING_COUNT",			# FubenLingWindow.as:221 「你今天是第%1次使用副本密卷进入【%2】本次进入需要%3个副本密卷。」
    "FUBENLING_WINDOW_TITLE",		# :2200 「副本密卷」（窗口标题）
    "COPY_PAIHANG",			# :231  隐藏那枚「查看副本竞速榜」
    "COPY_CELL_SINGLE",		# CopyWindowCell.as:138
    "COPY_CELL_TEAM",			# :141
    "COPY_CELL_TROOP",		# :144
    "COPY_CELL_COUNT",		# :152  「%1/%2次」
    "COPY_DENGJI_TAIDI",		# CopyWindow.as:402 点进入时等级不够
    "COPY_MINGTIAN_JIXU",		# :572  次数用完
    "COPY_SHIYONG_WANMIJUAN_JINRU",	# :407  还能免费进时不许用密卷
    "COPY_BUNENG_MIJUAN_JINRU",		# :397  该副本不能用密卷进
    "ELITECOPY_WINDOW_TITLE",		# EliteCopyWindow.as:383
    "ELITECOPY_WINDOW_COPYNAME",	# :302  左侧绿名 + 蓝（%2级）
    "CHAPTER",			# EliteCopyWindowCell.as:56 「第%1章」
    "ELITE_COPY_CELL_COUNT",		# :57  「（%1/%2次）」
    "FAMILLY_MANAGER_WU",		# CopyWindow.as:520  无奖励时显示「无」
]


def 主():
    表 = 原版数据.读语言表("message")
    出 = {}
    缺 = []
    for 键 in 键表:
        if 键 in 表:
            出[键] = 表[键]
        else:
            缺.append(键)
    if 缺:
        raise SystemExit("语言表里缺这些键，不许自造文案：%s" % "、".join(缺))
    体 = {"_说明": "由 `开发工具/出副本文案数据.py` 从 `en_US$message_properties.as` 抽，"
                    "键名 = 原版键名，别手改。取词处见脚本头的行号。",
          "_源": 原版数据.反编译目录}
    体.update(出)
    io.open(落, "w", encoding="utf-8", newline="\n").write(
        json.dumps(体, ensure_ascii=False, indent=1))
    print("出 %s：%d 条文案" % (os.path.relpath(落, 工程), len(出)))
    for 键 in 键表:
        print("  %-30s %s" % (键, 出[键].replace("\n", "\\n")))


if __name__ == "__main__":
    主()
