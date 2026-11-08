#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 2.2.3 原版 GameData 导出**宠物模板表**与**宠物技能表**。

## 为什么需要它
宠物面板显示的每一项数值（生命/攻击/梦幻度/价值/潜力条/升级经验/升阶消耗/融魂材料）
**都不在协议帧里** —— 帧只给潜力值、悟性、技能等级这类"存量"，显示值全部由
`PetAddValue.as` 现算，而算式要吃 GameData `Pet` 段的模板行。
客户端原先没有这张表，所以旧宠物窗（§3.61 病根四"自造物"）用 `stage*2` 之类假公式糊弄。

## 为什么**原样导出**，不做字段改名
同 `导出装备强化表.py` 的理由：翻成中文键 = 把同一份真值抄成两份，
服务端/原版改字段名时客户端**静默**错。整段原样落盘，客户端按原字段名读。

## 权威读法（以服务端自己的读写器为准，fake_flash_server.py）
```
模板行     = GAME_DATA_CATALOG.get_pet_config(id)          # :7515（八位补零键 + 编辑覆盖）
进化消耗   = info.evolution                                 # _fuse_pet_soul/_advance_pet :39270/:7527
融魂材料   = 九尾(404) evolution.needItemId=16000178 ×6000 + 30,000,000 金币（见对照图同源验算）
梦幻度     = savvy/10 + 四项潜力 real/total 比×100/3 + 技能数×1.25 + dream   # :48533
潜力上下限 = info.potential.values.apt<资质>.{min,max}       # get_pet_potential_bounds
宠物技能   = Skill 段 PetSkill 子表（getPetSkillData，SkillDataTool.as:510）
技能加成   = info.type_attr.{type,valueLevel} × skillLevel  # FightValue.computePetPsvSkillAttribute
喂食       = info.food.{foodid,foodvalue}（4 阶忍犬=5000001×10）
```

## 已做的反向验算（对照图 `.scratch/对比图/原版宠物界面.png`，4 阶忍犬）
- 四条潜力条 868/868 = values.apt4.min ✓；成长潜力总值 3472 = 868×4 ✓
- 价值 3573 = 3472 + 悟性1 + 2 技能×50（caculatePetPrice）✓
- 右侧进阶页「消耗金币 781 / 成功几率 20% / 进阶符×3 / 记忆符」= evolution 行 ✓

## 用法
    运行时/python/python.exe 开发工具/导出宠物数据.py

输出：`数据/宠物.json`（templates 46 行 + common{extend,expTable,skillAddRatio}）
      `数据/宠物技能.json`（Skill.PetSkill 33 行，id 为不带补零的技能号）
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from 原版数据 import 取顶层段, 取字符串段, 解载荷  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
根目录 = os.path.dirname(HERE)

模板 = 取顶层段('Pet')
if not isinstance(模板, dict) or 'common' not in 模板:
    raise SystemExit('GameData 的 Pet 段缺 common，口径变了，先核服务端再改这里')

templates = {}
for 键, 行 in sorted(模板.items()):
    if 键 == 'common':
        continue
    解 = 解载荷(行)
    if not isinstance(解, dict):
        raise SystemExit('模板行 %s 解出来不是 dict：%s' % (键, 解.__class__.__name__))
    templates[键] = 解
common = 解载荷(模板['common'])

技能 = {}
# 注意：顶层 'Skill' 值是**不压缩**的子表字典（和 Pet 段不同），只有每个子表再压了一层
Pet技能 = 解载荷(取顶层段('Skill')['PetSkill'])
for 键, 行 in Pet技能.items():
    解 = 解载荷(行)
    if isinstance(解, dict):
        技能[键] = 解

# 名字/描述在 **String 段的 PetSkill 子表**（StringTool.getPetSkillString，:1648 附近），
# 不在 Skill 段本体里 —— 漏了它就会得到 33 条"技能 101"这种占位名。
文案 = 取字符串段('PetSkill')
for 键, 行 in 文案.items():
    if 键 in 技能 and isinstance(行, dict):
        技能[键]['name'] = 行.get('name', '')
        技能[键]['desc'] = 行.get('desc', '')
        # 身上那条宠物 Buff 图标的描述（`SkillHandler.applyBuff:870` →
        # `SkillDataTool.getPetSkillBuffDesc:375` 读 String/PetSkill 的 `buffDesc`）。
        # 与玩家技能同一口径：只存模板，运行期用帧里的 value/duration 替换占位符。
        技能[键]['buff_desc'] = str(行.get('buffDesc', '') or '').replace('\r', '')
缺失 = [k for k in 技能 if not 技能[k].get('name')]
if 缺失:
    raise SystemExit('String.PetSkill 缺名字：%s —— 口径变了，先核原版' % 缺失)

out1 = os.path.join(根目录, '数据', '宠物.json')
out2 = os.path.join(根目录, '数据', '宠物技能.json')
with open(out1, 'w', encoding='utf-8') as f:
    json.dump({'templates': templates, 'common': common}, f, ensure_ascii=False, indent=1, sort_keys=True)
with open(out2, 'w', encoding='utf-8') as f:
    json.dump(技能, f, ensure_ascii=False, indent=1, sort_keys=True)
print('数据/宠物.json：%d 个模板 + common(%s)' % (len(templates), ','.join(sorted(common.keys()))))
print('数据/宠物技能.json：%d 条' % len(技能))
