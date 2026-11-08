# -*- coding: utf-8 -*-
"""把原版 `com/mxw/data/ExpTable.as` 里那张等级经验表，生成 `脚本/单例/等级经验表.gd`。

为什么要有这个生成器（而不是往 .gd 里手抄一串数）：
* 那张表是**两根经验条的分母**（`DataCenter.as:2443` 与 `:1462` 都用
  `ExpTable.getExpNeededForLevel(stats.level)`）。手抄一次就得保证 121 个数全对，
  抄错哪一个都没有报错，只会让某一级"条子差一点点"。
* 本机有**两份独立来源**逐条相同 ⇒ 生成时当场对一次，对不上直接炸：
    ① `2.2.3优化版` 反编译的 `ExpTable.as`（钉死的数据源，首选）；
    ② 工程内服务端的 `EXP_BY_LEVEL`（`服务端/runtime/tools/fake_flash_server.py:491`，
       升级扣经验用的就是它，见 `:46407 _experience_required_for_level`）。
  ⇒ 客户端和服务端各拿一份手抄表，迟早出现"客户端说还差 20、服务端已经升级了"。

跑法：`python 开发工具/生成等级经验表.py`（幂等：内容不变就不改写文件）。
`--只核不写` 给回归门用：只做解析与两源对照，不落盘。
"""
import io
import os
import re
import sys

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
产物 = os.path.join(工程, "脚本", "单例", "等级经验表.gd")
服务端 = os.path.join(工程, "服务端", "runtime", "tools", "fake_flash_server.py")
# 数据源钉死 2.2.3优化版；查不到再退回 `原版数据.AS文件` 的候选表。
首选 = os.path.join(
    r"2.2.3\logs\swfprobe\as3_MainLib\scripts",
    "com", "mxw", "data", "ExpTable.as")


def 找AS():
    if os.path.isfile(首选):
        return 首选, "2.2.3优化版反编译树"
    sys.path.insert(0, os.path.join(工程, "开发工具"))
    import 原版数据
    路 = 原版数据.AS文件("com/mxw/data/ExpTable.as")
    if not 路 or not os.path.isfile(路):
        raise SystemExit("找不到 com/mxw/data/ExpTable.as（首选 %s）" % 首选)
    return 路, "原版数据.AS文件 候选表"


def 解AS(路):
    文 = io.open(路, encoding="utf-8", errors="replace").read()
    块 = re.search(r"const\s+exp\s*:\s*Array\s*=\s*\[(.*?)\]", 文, re.S)
    if not 块:
        raise SystemExit("%s 里没匹配到 `const exp:Array = [...]`" % 路)
    return [int(x) for x in re.findall(r"-?\d+", 块.group(1))]


def 解服务端(路):
    文 = io.open(路, encoding="utf-8", errors="replace").read()
    块 = re.search(r"EXP_BY_LEVEL\s*=\s*\((.*?)\)", 文, re.S)
    if not 块:
        raise SystemExit("%s 里没匹配到 `EXP_BY_LEVEL = (...)`" % 路)
    return [int(x) for x in re.findall(r"-?\d+", 块.group(1))]


def 自检(表):
    错 = []
    if not 表:
        错.append("表是空的")
    if 表 and 表[0] != 0:
        错.append("表[0] 应为 0，实际 %d" % 表[0])
    if any(v < 0 for v in 表):
        错.append("有负数")
    if any(表[i] >= 表[i + 1] for i in range(len(表) - 1)):
        错.append("不是严格递增（升级所需经验必须一级比一级多）")
    return 错


def 出文本(表, 源, 项数):
    行 = []
    for 起 in range(0, len(表), 10):
        行.append("\t" + ", ".join(str(v) for v in 表[起:起 + 10]) + ",")
    return """extends RefCounted

## 原版 `com/mxw/data/ExpTable.as` 的 `exp` 数组（%d 项，索引 = 等级）。
##
## ⚠ **本文件由 `开发工具/生成等级经验表.py` 生成，别手改。**
## 它是底栏与人物面板那两根经验条的**分母**：原版在
## `DataCenter.as:2443`（收到 CocoStatType.EXP 那一号时）和 `:1462`
## （`getDataForCharacterInfoWindow`）两处都现算 `ExpTable.getExpNeededForLevel(level)`，
## 服务端属性包**从来没有**发过"升级所需经验"这一号 —— 客户端不自己查表就没有分母。
##
## 出处：%s（与工程内服务端 `EXP_BY_LEVEL` 逐条相同，生成时当场对过）

const 项数 := %d
const 最高等级 := %d

const 需要经验 := [
%s
]


## `ExpTable.getExpNeededForLevel`（`ExpTable.as:14-21`）1:1：
## 等级超范围就回**最后一档**（原版这么写，不是我们兜底），负数按 0 级看。
static func 本级所需(等级: int) -> int:
	if 等级 >= 需要经验.size():
		return 需要经验[需要经验.size() - 1]
	if 等级 < 0:
		return 需要经验[0]
	return 需要经验[等级]
""" % (项数, 源, 项数, 项数 - 1, "\n".join(行))


def 主():
    只核 = "--只核不写" in sys.argv
    路, 说明 = 找AS()
    表 = 解AS(路)
    服 = 解服务端(服务端)
    错 = 自检(表)
    if 表 != 服:
        差 = next((i for i in range(max(len(表), len(服)))
                   if (表[i] if i < len(表) else None) != (服[i] if i < len(服) else None)), None)
        错.append("与工程内服务端 EXP_BY_LEVEL 不是同一张表（第 %s 项起不一致：AS=%s 服务端=%s）"
                  % (差, 表[差] if 差 is not None and 差 < len(表) else "?",
                     服[差] if 差 is not None and 差 < len(服) else "?"))
    if 错:
        print("自检没过：")
        for e in 错:
            print("  - " + e)
        raise SystemExit(1)
    新 = 出文本(表, "%s ⇒ %s" % (说明, 路.replace("\\", "/")), len(表))
    旧 = io.open(产物, encoding="utf-8").read() if os.path.isfile(产物) else ""
    if 只核:
        print("核对通过：%d 项，两源逐条一致；产物%s" % (len(表), "与磁盘一致" if 新 == 旧 else "与磁盘不同（该重跑了）"))
        raise SystemExit(0 if 新 == 旧 else 1)
    if 新 == 旧:
        print("已是最新（%d 项，幂等，没改写）" % len(表))
        return
    io.open(产物, "w", encoding="utf-8", newline="\n").write(新)
    print("写出 %s（%d 项）" % (产物, len(表)))


if __name__ == "__main__":
    主()
