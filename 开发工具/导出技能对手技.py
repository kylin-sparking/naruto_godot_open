# -*- coding: utf-8 -*-
"""导出「出手技能 → 对手技能名（飘在身上的流水字）」这张小表 → 数据/技能对手技.json。

原版链路（2.2.3优化版，行号现查 `2.2.3/logs/swfprobe/as3_MainLib/scripts/`）
----------------------------------------------------------------------------------------
`DamageHandler.as:107-113`（服务端把伤害算好后发给客户端那条，= 我们的 194 帧）：

    if (!param1.skillTrigger) {
        _loc13_ = AbstractSkillEffect.getPlayerSkillFlowText(_loc3_, _loc2_);
        if (_loc13_) _loc9_.player_addAttriChangeTip(_loc13_, 0, true, CocoStatType.SKILL);
    }

`AbstractSkillEffect.as:501-510 getPlayerSkillFlowText(skillId, charId)`：

    defSkill = SkillDataTool.getDefSkill(skillId);          // 见下
    if (defSkill != 0) text = StringTool.getSkillString(defSkill);   // 默认取 "name"

`SkillDataTool.as:731-735 getDefSkill`：读的是**技能数据里的 `info.desc.oppositeSkill`**；
`StringTool.as:114-119 getSkillString`：读的是 **GameData 顶层 `String` 段的 `Skill` 子表**
（键 = 7 位补零的技能 id）⇒ 我们那张表已经导成 `数据/技能文案.json`。

⇒ 一张两列的小表就够：`出手技能id → {opposite, name}`。
    `opposite == 0` 或名字查不到 ⇒ 原版就是不飘（`if(_loc13_)` 判的是非空串），**不进表**。

颜色与档位在客户端侧：`CocoStatType.SKILL` ⇒ `Character.as:580-582` 盖成 **3316223 = 0x3299FF**；
`num == 0 && tip != ""` ⇒ **只写 tip**（`Character.as:1241`）。

跑法：python 开发工具/导出技能对手技.py
自检：非零 oppositeSkill 的条数、以及"名字查得到/查不到"各多少，都打出来。
"""
import io, json, os, sys

sys.stdout.reconfigure(encoding="utf-8")
项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
源 = os.path.join(项目根, "数据", "技能_原版.json")
文案 = os.path.join(项目根, "数据", "技能文案.json")
产物 = os.path.join(项目根, "数据", "技能对手技.json")


def 读(p):
    return json.loads(io.open(p, encoding="utf-8").read())


def 挖(v):
    """技能记录里 `info.desc.oppositeSkill`；结构不规整时兜底递归找同名键（找到即返回）。"""
    if isinstance(v, dict):
        if "oppositeSkill" in v:
            return v["oppositeSkill"]
        for k in ("info", "desc"):
            if k in v:
                内 = 挖(v[k])
                if 内 is not None:
                    return 内
    return None


def 七位(x) -> str:
    s = str(x).strip()
    return s if len(s) == 7 else s.zfill(7)


def main() -> int:
    技 = 读(源)
    表 = 读(文案)
    出 = {}
    零 = 0
    无名 = []
    for 键, 条 in 技.items():
        if not isinstance(条, dict):
            continue
        对 = 挖(条)
        try:
            对 = int(对)
        except (TypeError, ValueError):
            continue
        if 对 == 0:
            零 += 1
            continue
        名 = (表.get(七位(对)) or {}).get("name")
        if not 名:
            无名.append((键, 对))
            continue
        出[七位(键)] = {"opposite": 对, "name": 名}
    io.open(产物, "w", encoding="utf-8").write(
        json.dumps(出, ensure_ascii=False, indent=1, sort_keys=True))
    print("技能 %d 条：oppositeSkill 非零 %d 条、零/缺 %d 条" % (len(技), len(出) + len(无名), 零))
    print("进了表 %d 条；名字在 String.Skill 表里查不到 ⇒ 原版也不飘：%s" % (len(出), 无名))
    for k, v in sorted(出.items()):
        print("  %s → %s（%s）" % (k, v["opposite"], v["name"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
