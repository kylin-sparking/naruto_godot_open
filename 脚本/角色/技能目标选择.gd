extends RefCounted

## 放一个技能时**该把哪几只怪报出去** —— 原版这条只有一个判据：技能表 `info.desc.target`。
##
## 真值（2.2.3优化版，逐条到行号）：
##   `com/mxw/skills/skills/AbstractAttackSkill.as:598-637 hitTest()`
##     ```as3
##     switch (SkillDataTool.getSkillTarget(skillId)) {
##        case 3: createSkillMsg(..., API.player);                     // 目标 = 自己
##        case 1: createSkillMsg(..., API.targetHandler.curTarget);    // 单体 = 只发选中的那一只
##        case 2: createSkillMsg(...);                                 // 面积 = 不带目标
##     }
##     ```
##   `com/mxw/roles/mobAttack/SkillDataTool.as:177-181`
##     `getSkillTarget(id) = skillData.info.desc.target` ⇒ 就是 `数据/技能.json` 每条的 `target`。
##
## 三条口径要说清（都是"照抄原版"，不是兜底）：
##  * **单体（1）没有选中怪 ⇒ 不放**（原版 `moveToAttack()` 整条链的前提就是 `curTarget` 在，
##    打不到就先寻路；它从不"框到几只打几只"）。这就是用户 2026-10-10 报的那条
##    「单体攻击只能攻击当前选中的那一只怪物」。
##  * **面积（2）报命中盒框到的全部**：原版这条**不带目标**（`case 2` 那个分支），由服务端按范围结算；
##    本工程服务端只结算客户端报上来的那几只（`fake_flash_server.py:41044-41088` 用 `fields[13]` 的
##    `@` 串授权伤害）⇒ 所以这里把命中盒框到的全部报出去。**这是一处有意的落地差异**，
##    不是自造规则：范围仍然用原版那张命中盒定表（`技能命中盒.gd`）。
##  * **自身（3）不报怪**（隐身 / 二段跳 / 瞬移 / 加血单体 / 莲华 / 伊邪那岐 都是这一档）。
##  * `target=0` 那 56 条（被动/生活技为主）**原版不会走到 hitTest 这个 switch 的任何一个 case**
##    ⇒ 这里一律回空，让调用方退回普攻，而不是猜成单体。

## 输入：`档` = 技能表的 `target`；`框到的` = 命中盒里的怪（数组，顺序即命中盒返回顺序）；
## `选中` = 当前选中的怪（可为 null）。返回要报出去的目标数组。
static func 目标(档: int, 框到的: Array, 选中: Node) -> Array:
	match 档:
		1:
			if 选中 == null or not is_instance_valid(选中):
				return []
			return [选中]
		2:
			return 框到的.duplicate()
		3:
			return []
	return []


## 够不够得着 —— 原版 `AbstractAttackSkill.canReachTarget():388-404`：
## 拿**这个技能**的命中盒去压目标的体型盒，当前朝向压不到就**再按反方向试一次**。
## （不是"距离小于某个常数"，本工程以前那种 `半径 130 + 槽位*18` 是自造的。）
static func 够得着(档: int, 框到的: Array, 选中: Node, 反方向框到的: Array) -> bool:
	match 档:
		3:
			# 自身技不打怪：能不能放由冷却/查克拉判，距离上没有「够不够得着」这一说
			return true
		1, 2:
			if 选中 == null or not is_instance_valid(选中):
				return false
			return 框到的.has(选中) or 反方向框到的.has(选中)
	return false


## 取离玩家**最近**的一个（原版 `CommonAttack.getNearestLifeObj():34-74`：
## 按 `GeomUtil.getDistance(player.x, player.y, obj.x, obj.y)` 直线距离取最小，
## `inLayerNow` 为假的候选先剔掉）。
## ⚠ 原版那个函数会 `splice` 掉它返回的那一个 —— `SkillHandler.switchTarget():1034-1039`
## 正是靠这一点做"轮换"：先取最近者，若它就是当前目标，再取一次 ⇒ 拿到**第二近**的。
## 这里不破坏调用方的数组，直接"排除当前目标后取最近"，是同一件事。
static func 最近(候选: Array, 玩家位: Vector2, 排除: Node) -> Node:
	var 最: Node = null
	var 最短 := INF
	for 客 in 候选:
		if 客 == null or not is_instance_valid(客):
			continue
		if 排除 != null and 客 == 排除:
			continue
		if 客 is CanvasItem and not (客 as CanvasItem).visible:
			continue
		var 距 := (客 as Node2D).global_position.distance_to(玩家位)
		if 距 < 最短:
			最短 = 距
			最 = 客
	return 最


## 按技能键时"命中盒里最近的一只"（原版 `SkillExecute.as:420-436`：
## 先 `getSkillHitRect(技能, 玩家, 朝向)`，再 `getNearestMonsterInArea(怪表, 那个盒)`）。
static func 盒内最近(框到的: Array, 玩家位: Vector2) -> Node:
	return 最近(框到的, 玩家位, null)
