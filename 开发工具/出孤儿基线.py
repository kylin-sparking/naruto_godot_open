# -*- coding: utf-8 -*-
"""扫出「表里有、代码没人读」的条目，按前缀归组写成基线，给 `数据条目有主回归测试.gd` 当判据。"""
import io, json, os, sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
文 = []
for 根 in ("脚本", "场景"):
    for 子, _, 档 in os.walk(os.path.join(工程, 根)):
        for f in 档:
            if f.endswith((".gd", ".tscn")):
                文.append(io.open(os.path.join(子, f), encoding="utf-8").read())
全部 = "\n".join(文)

组 = [
    ("Effect_", "原版战斗/副本/跨服/经脉/护送奖卡那一族特效（`Etc.mcEffect` + `MCFromDatDefine` 前缀链）。本工程范围是界面与按钮，这些**没有对应玩法可播**；要接战斗表现时再从这里取，别另导一份。"),
    ("maiTong", "经脉图（`maiTong1..17`）。原版是点经脉界面的一串光效，本工程经脉界面未做。"),
    ("No", "品质底图 NoBlue/NoCri/NoRed/NoViolet 各 0/1（装备品质框的「无光」态）。本工程装备格品质框走的是 `原版皮肤表` 那套，不读这几条。"),
    ("bgFlags/", "背景层标记（`Etc.mcEffect.bgFlags`，挂机拾取/攻击旗标）。属挂机玩法。"),
    ("chest", "宝箱开合动画。本工程没有可拾取宝箱实体。"),
    ("aToAttack", "挂机引导「去攻击」指示箭头。属挂机玩法。"),
    ("cToPickup", "挂机引导「去拾取」指示箭头。属挂机玩法。"),
    ("flying", "飞行/坐骑位移特效。本工程没有飞行态。"),
    ("healNew", "组队治疗新样式。属战斗/组队玩法。"),
    ("jobChange", "转职光效。本工程转职走的是对话窗文案 + 属性刷新，没接这条帧。"),
    ("mob", "原版挂在怪物身上的位移/BOSS 标（mobBianyi、mobBoss）。属战斗表现，本工程范围是界面。"),
    ("player", "playerBulb 玩家身上的光球（治疗/护盾指示）。属战斗表现。"),
    ("quest", "questClear 任务完成的小标 —— 与在用的大横幅 `questOverTip` **不是同一张图**，别混。"),
    ("summoned", "召唤兽登场特效。属召唤玩法。"),
    ("teleport", "传送光效。本工程在用的是 `portalPH`/`portalPV` 那两条，这条没接。"),
    ("wang", "wangBossPic 王者 BOSS 图。属玩法，不在界面范围。"),
    ("minimap_mob", "小地图上的怪点（`minimap_mob_skin` / `_mobBoss_skin` / `_mobJingYing_skin`）。原版 `SmallMapWindow` 逐只怪画点，本工程只画传送点 + NPC 任务态 + 自己 ⇒ **未实现**，见 #35。"),
    ("minimap_party", "小地图上的队友/队长点。本工程没有组队。"),
    ("minimap_friend", "小地图上的好友点。好友窗有、小地图联动没做。"),
    ("minimap_flag_", "小地图上的家族旗（红/蓝/黄）。本工程没有家族战领地。"),
    ("minimap_npc", "小地图上按 NPC 种类分的 8 枚普通点（`minimap_npc1..8_skin`）。本工程一律画 `minimap_npc_skin` 或任务态那三枚 ⇒ **未实现按职业分色**。"),
]
出 = {}
for 表路, 段 in ((r"数据\特效.json", "特效"), (r"数据\界面\小地图标记.json", "标记")):
    d = json.load(io.open(os.path.join(工程, 表路), encoding="utf-8"))
    键 = sorted((d[段] if 段 in d else d).keys())
    孤 = [k for k in 键 if k not in 全部]
    for 前, 由 in 组:
        命 = [k for k in 孤 if k.startswith(前)]
        if 命:
            出.setdefault(前, {"理由": 由, "条数": 0, "样例": []})
            出[前]["条数"] += len(命)
            出[前]["样例"] += 命[:3]
    未 = [k for k in 孤 if not any(k.startswith(前) for 前, _ in 组)]
    print("%s：%d 条，孤儿 %d 条，未归组 %d 条 %s" % (表路, len(键), len(孤), len(未), 未[:12]))
io.open(os.path.join(工程, "数据", "界面", "孤儿条目基线.json"), "w", encoding="utf-8").write(
    json.dumps({"说明": "「表里有、代码没人读」的条目按前缀归组 + 为什么没读。"
                       "判据见 测试/数据条目有主回归测试.gd：孤儿必须**全部**落进这张表，"
                       "且每组必须**至少还命中一条**（接完了就要把组删掉）。",
                "组": 出}, ensure_ascii=False, indent=1) + "\n")
print("写了 数据/界面/孤儿条目基线.json，组数", len(出))
