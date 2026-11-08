# -*- coding: utf-8 -*-
"""导出忍术详情区要用的全部文案与学习条件 → 数据/技能文案.json。

为什么需要它（纠正一处一直找错了地方的口径）
--------------------------------------------
`docs/体系真值/技能体系.md` §4 写"描述 34/156、客户端 132/150 是 XXXX"，那是**只看了 `Skill` 段**得出的。
原版客户端根本不从 `Skill` 段取名字和描述 —— `DataCenter.as:522` 与 `:535`：

    _loc3_["name"]           = StringTool.getSkillString(_loc4_);          // 名字
    _loc3_["effectInstruction"] = this.getSkillDesc(_loc4_, _loc5_);       // 效果说明

而 `StringTool.getSkillString`（`StringTool.as:114`）读的是
**GameData 顶层 `String` 段下的 `Skill` 子表**（`ImgUtil.getImg(ImgType.String_,"Skill")`），
键是 7 位补零的技能 id。实测那张表有 **96 条**，其中
**5 个页签里出现的 72 条技能全部命中** —— 也就是说详情区要显示的东西原版一直都有，
只是从没被导出过。

「学习方法」那三行同理：
    studyReqLevel       = SkillDataTool.getSkillReqLevel(id)   // 见下
    studyReqSkillId     = SkillDataTool.getSkillReqBook(id)    // = info.open.reqBook
    studyReqInstruction = StringTool.getSkillString(id,"gain") // 来源说明
    《需要秘笈》的名字   = StringTool.getItemString(reqBook)     // = String 段的 JiNengShu 子表

**需要等级的取值不是技能自己的 `open.reqLevel`**：`SkillDataTool.as:609` 写的是
reqBook 为 0 时用 `open.reqLevel`，否则去查**那本技能书道具**的 `info.reqLevel`。
真机已验证：体能强化(0001000) 的 open.reqLevel=7、书 06000038 的 reqLevel=7 → 显示 7；
带土·雷霆豪火球(0009029) 的 open.reqLevel=1、书 06000129 的 reqLevel=60 → 显示 **60**。

**攻击范围显示的是文字不是数字**：`DataCenter.as:534` 是
`CN.SKILL_ATTACK_DISTANCE[SkillDataTool.getSkillRange(id)]`，
`SKILL_ATTACK_DISTANCE_1..5` = 无/近距离/远距离/中距离/超远距离（`CN.as:1298`）。
真机已验证：0001000 range=0 → 显示"无"；0009029 range=2 → 显示"远距离"。

用法
----
    python 开发工具/导出技能文案.py

产物
----
    数据/技能文案.json   {技能id: {name, desc, desc模板, gain, 占位符, reqLevel,
                                  reqBook, reqBookName, skillTypeText, targetText, rangeText}}
"""

import decimal
import io
import json
import os
import re
import sys
from typing import Any

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from 原版数据 import 取字符串段, 取顶层段, 解载荷, 语言  # noqa: E402

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
产物 = os.path.join(项目根, "数据", "技能文案.json")

# 玩家技能所在的分组（其余是宠物技能与特效表）
玩家组 = ("000", "100", "200", "300", "400", "900")

# 两个来自 docs/体系真值/技能体系.md 的字段路径，这里按 AS3 的取值顺序重新实现
技能表路径 = os.path.join(项目根, "数据", "技能_原版.json")


# ---------------------------------------------------------------- 数值格式化

def to_precision(值: Any, 位数: int = 2) -> str:
    """等价于 AS3 `Number.prototype.toPrecision`。

    `DataCenter.getSkillDesc` 里每个占位符都是 `.toPrecision(2)` 出来的，
    而 JS/AS3 的 toPrecision 是**有效数字**不是小数位——
    所以 12 → "12"、2 → "2.0"、200 → "2.0e+2"。
    真机已验证：体能强化 attrLevel=12 显示成"多提高血量上限12点"。
    """
    try:
        数 = decimal.Decimal(str(值))
    except (decimal.InvalidOperation, ValueError):
        return "NaN"
    if 数.is_nan() or 数.is_infinite():
        return "NaN"
    if 数 == 0:
        return "0." + "0" * (位数 - 1) if 位数 > 1 else "0"
    指数 = 数.adjusted()  # floor(log10(|数|))
    if 指数 < -6 or 指数 >= 位数:
        尾数 = 数.scaleb(-指数).quantize(
            decimal.Decimal(1).scaleb(-(位数 - 1)), rounding=decimal.ROUND_HALF_UP
        )
        return "%se%s%d" % (尾数, "+" if 指数 >= 0 else "-", abs(指数))
    return str(数.quantize(
        decimal.Decimal(1).scaleb(-(位数 - 1 - 指数)), rounding=decimal.ROUND_HALF_UP
    ))


def _取(记录: Any, 路径: str) -> Any:
    当前 = 记录
    for 段 in 路径.split("."):
        if not isinstance(当前, dict):
            return None
        当前 = 当前.get(段)
    return 当前


# ---------------------------------------------------------------- AS3 等价实现

占位符路径 = {
    # 占位符名 : GameData 字段路径（`DataCenter.getSkillDesc` 的 _loc5_.._loc12_）
    "valueBase": "info.type_attack.effect.valueBase",
    "valueLevel": "info.type_attack.effect.valueLevel",
    "attrLevel": "info.type_attr.valueLevel",
    "defLevel": "info.type_defence.defProbLevel",
    "probLevel": "info.type_attack.trigger.probLevel",
    "timeLevel": "info.type_attack.effect.timeLevel",
    "triggerSkill": "triggerSkill",
}

# **替换顺序照抄 AS3**，且 AS3 的 `String.replace(字串, 字串)` 只换**第一处**。
替换顺序 = ("valueBase", "valueLevel", "attrLevel", "valueTotal", "defLevel",
            "probLevel", "timeLevel", "triggerSkill")


def 取占位符值(记录: dict) -> dict:
    """把模板占位符的原始取值抠出来（未格式化），供替换与排查用。"""
    值: dict = {}
    for 名, 路径 in 占位符路径.items():
        原值 = _取(记录, 路径)
        if 原值 is None or 原值 == "":
            continue
        if 名 == "triggerSkill":
            值[名] = 原值  # 技能 id，替换时再换成名字
        else:
            try:
                值[名] = float(原值)
            except (TypeError, ValueError):
                continue
    return 值


def 解析描述(模板: str, 占位符: dict, 等级: int, 技能名: dict) -> str:
    """`DataCenter.getSkillDesc(id, level)` 的等价实现。"""
    文本 = 模板
    for 名 in 替换顺序:
        if 名 not in 文本:
            continue
        if 名 == "valueTotal":
            # 只有它随等级变；值取 attrLevel（AS3 的 _loc7_ * param2）
            原值 = float(占位符.get("attrLevel", 0)) * 等级
            文本 = 文本.replace(名, to_precision(原值), 1)
            continue
        if 名 not in 占位符:
            continue
        if 名 == "valueBase":
            文本 = 文本.replace(名, to_precision((float(占位符[名]) + 100) / 100), 1)
        elif 名 == "timeLevel":
            文本 = 文本.replace(名, to_precision(float(占位符[名]) / 1000), 1)
        elif 名 == "triggerSkill":
            文本 = 文本.replace(名, str(技能名.get(str(占位符[名]), "")), 1)
        else:
            文本 = 文本.replace(名, to_precision(占位符[名]), 1)
    return 文本.replace("\r", "")


def 取需要等级(技能记录: dict, 技能书: dict, 书文案: dict) -> int:
    """`SkillDataTool.getSkillReqLevel`：有技能书就查书道具的 reqLevel，否则用技能自己的。"""
    开放 = (_取(技能记录, "info.open") or {})
    书id = 开放.get("reqBook")
    if not 书id or str(书id) == "0":
        return int(开放.get("reqLevel") or 0)
    书 = 取书条目(技能书, 书id)
    if 书 is None:
        # AS3 里此时返回 -1（道具表还没加载完，会触发加载后重算）
        return -1
    return int(_取(书, "info.reqLevel") or 0)


def 取条目(表: dict, 编号: Any) -> Any:
    """按 7/8 位补零两种写法找一条记录。

    ⚠️ `JiNengShu` 段里**单条记录自己也是 zlib 压缩的 AMF3 字节串**（不是整段压一次），
    所以取出来还要过一遍 `解载荷`，否则拿到的是 bytes、`info.reqLevel` 永远是 0。
    这一条踩过：体能强化/带土·雷霆豪火球的"需要等级"因此都成了 0。
    """
    键 = str(编号)
    for 候选 in (键, 键.zfill(8), 键.lstrip("0")):
        if 候选 in 表:
            return 解载荷(表[候选])
    return None


def 取书条目(技能书: dict, 书id: Any) -> Any:
    return 取条目(技能书, 书id)


def 取书名称(书文案: dict, 书id: Any) -> str:
    条 = 取条目(书文案, 书id)
    return str(条.get("name", "")) if isinstance(条, dict) else ""


# ---------------------------------------------------------------- 主流程

def main() -> int:
    if not os.path.exists(技能表路径):
        print("找不到 %s，先跑 开发工具/导出技能数据.py" % 技能表路径)
        return 1
    技能表 = json.load(io.open(技能表路径, encoding="utf-8"))
    技能文案 = 取字符串段("Skill")
    技能书文案 = 取字符串段("JiNengShu")
    技能书 = 取顶层段("JiNengShu")

    玩家 = {k: v for k, v in 技能表.items() if v.get("_组") in 玩家组}

    名称表: dict = {}
    for 技能id in 玩家:
        名 = str((技能文案.get(技能id) or {}).get("name", ""))
        if not 名:
            名 = str(_取(玩家[技能id], "info.desc.name") or "")
        名称表[技能id] = 名

    结果: dict = {}
    for 技能id, 记录 in 玩家.items():
        文案 = 技能文案.get(技能id) or {}
        名称 = 名称表[技能id]
        模板 = str(文案.get("desc", "") or "")
        占位符 = 取占位符值(记录)
        开放 = _取(记录, "info.open") or {}
        书id = 开放.get("reqBook")
        书id文本 = "" if not 书id or str(书id) == "0" else str(书id)
        结果[技能id] = {
            "name": 名称,
            "desc": 解析描述(模板, 占位符, 1, 名称表),
            "desc模板": 模板.replace("\r", ""),
            # 身上那条 Buff 图标的描述**不是**技能详情描述：原版
            # `SkillHandler.applyBuff:874` → `SkillDataTool.getSkillBuffDesc(id, level)`
            # 读的是 String/Skill 的 `buffDesc`，再把 valueTotal / duration 换成本次帧的值。
            # 这里只导出**原始模板**（不按 1 级烘死），运行期拿 GIVE_BUFF 的 value/duration 替换。
            "buffDesc": str(文案.get("buffDesc", "") or "").replace("\r", ""),
            "gain": str(文案.get("gain", "") or ""),
            "占位符": {k: (int(v) if float(v).is_integer() else v) for k, v in 占位符.items()},
            "reqLevel": 取需要等级(记录, 技能书, 技能书文案),
            "reqBook": 书id文本.zfill(8) if 书id文本 else "",
            "reqBookName": 取书名称(技能书文案, 书id) if 书id文本 else "",
            # 学习条件第三行（`SkillStudyConditionPane.setData`）：家族贡献 > 0 时显示「需要族贡」，
            # 否则有经脉要求显示「需要八门：贯通N门」，否则有写轮眼要求显示「需要写轮眼：<阶名>」。
            # 三者都归 `info.open`，客户端原来没导 ⇒ 学习方法面板只剩等级/书两行，玩家看不出为什么点不动。
            "reqBangGong": int(开放.get("reqBangGong") or 0),
            "reqMai": int(开放.get("reqMai") or 0),
            "reqXielunyan": int(开放.get("reqXielunyan") or 0),
            "skillTypeText": 技能类型文字(_取(记录, "info.desc.skillType")),
            "targetText": 攻击目标文字(_取(记录, "info.desc.target")),
            "rangeText": 攻击范围文字(_取(记录, "info.desc.range")),
        }

    _写(结果)
    _报覆盖(结果, 技能文案)
    return 0


def 技能类型文字(取值: Any) -> str:
    """`CN.SKILL_TYPES[type]`：SKILL_TYPES_1/2 = 主动忍术/被动忍术。"""
    if 取值 is None:
        return ""
    return 语言("SKILL_TYPES_%d" % (int(取值) + 1))


def 攻击目标文字(取值: Any) -> str:
    """`CN.SKILL_ATTACK_RANGES[target]`：_1.._4 = 无/单体/范围/自己（键名叫 RANGES，索引的是 target）。"""
    if 取值 is None:
        return ""
    return 语言("SKILL_ATTACK_RANGES_%d" % (int(取值) + 1))


def 攻击范围文字(取值: Any) -> str:
    """`CN.SKILL_ATTACK_DISTANCE[range]`：_1.._5 = 无/近距离/远距离/中距离/超远距离。"""
    if 取值 is None:
        return ""
    return 语言("SKILL_ATTACK_DISTANCE_%d" % (int(取值) + 1))


def _写(结果: dict) -> None:
    说明 = (
        "忍术详情区的文案与学习条件，权威源是 2.2.3 的 GameData.dat —— "
        "名字/描述/来源取自顶层 String 段的 Skill 子表（原版 DataCenter.as:522/535 就是这么取的），"
        "学习条件取自 Skill 段 info.open 与顶层 JiNengShu（技能书道具）段，"
        "三个枚举文字取自语言表。生成工具：开发工具/导出技能文案.py。"
        "desc 已按 DataCenter.getSkillDesc 的规则替换占位符（1 级口径）；desc模板 是替换前的原文。"
    )
    输出 = {"_说明": 说明}
    输出.update(结果)
    os.makedirs(os.path.dirname(产物), exist_ok=True)
    io.open(产物, "w", encoding="utf-8").write(
        json.dumps(输出, ensure_ascii=False, indent=1, sort_keys=True)
    )


def _报覆盖(结果: dict, 技能文案: dict) -> None:
    页签路径 = os.path.join(项目根, "数据", "界面", "技能分页.json")
    页签id: list = []
    if os.path.exists(页签路径):
        分页 = json.load(io.open(页签路径, encoding="utf-8"))
        for 清单 in (分页.get("页签", {}) or {}).values():
            页签id += [x for x in 清单 if x]
        for 清单 in (分页.get("职业普攻", {}) or {}).values():
            页签id += list(清单)
    页签id = sorted(set(页签id))

    print("玩家技能 %d 条 -> %s" % (len(结果), 产物))
    for 字段 in ("name", "desc", "gain", "reqBookName"):
        数 = sum(1 for v in 结果.values() if v[字段])
        print("  %-12s %3d / %d" % (字段, 数, len(结果)))
    有书 = sum(1 for v in 结果.values() if v["reqBook"])
    有等级 = sum(1 for v in 结果.values() if v["reqLevel"] >= 0)
    print("  %-12s %3d / %d（其中 %d 条没有技能书，取技能自己的 open.reqLevel）"
          % ("reqLevel", 有等级, len(结果), len(结果) - 有书))
    print("  三个枚举：类型 %d / 目标 %d / 范围 %d 有文字"
          % tuple(sum(1 for v in 结果.values() if v[k]) for k in ("skillTypeText", "targetText", "rangeText")))

    if 页签id:
        缺 = [i for i in 页签id if i not in 结果]
        空名 = [i for i in 页签id if i in 结果 and not 结果[i]["name"]]
        空述 = [i for i in 页签id if i in 结果 and not 结果[i]["desc"]]
        残 = [i for i in 页签id if i in 结果 and re.search(r"[A-Za-z]+Level|valueBase|valueTotal", 结果[i]["desc"])]
        无书 = [i for i in 页签id if i in 结果 and 结果[i]["reqBook"] and not 结果[i]["reqBookName"]]
        无级 = [i for i in 页签id if i in 结果 and 结果[i]["reqLevel"] < 0]
        print("页签技能 %d 条（这是详情区真正会显示的集合）：" % len(页签id))
        print("  不在技能表里的     %s" % (缺 or "无"))
        print("  名字为空的         %s" % (空名 or "无"))
        print("  描述为空的         %s" % (空述 or "无"))
        print("  仍有占位符的       %s" % (残 or "无"))
        print("  有书但书名为空的   %s" % (无书 or "无"))
        print("  需要等级取不到的   %s" % (无级 or "无"))


if __name__ == "__main__":
    sys.exit(main())
