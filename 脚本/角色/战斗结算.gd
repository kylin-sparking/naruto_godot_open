class_name CombatFormula
extends RefCounted

## 「我打怪」的伤害结算 —— 照原版 `Client.applyClientPveAttack()`（`Client.as:11005-11057`）。
##
## 原版这是**客户端预演**：本地先算一遍（`clientCombatHp`），好让伤害数字立刻出来；
## 真正的权威值由服务端回包。**离线时它就是唯一的结算方**，所以离线打怪的伤害、
## 命中、暴击全按这一份走，不另编公式。
##
## ⚠️ 三处**本工程拿不到**的输入，按"该项不参与"处理，都写在下面每一处：
##   1. `mob.buff_reduceAvd` / `buff_reduceDef` —— 减闪避/减防御的 buff，本工程没建模
##      ⇒ 公式里那两处 `× (100 - reduce)/100` 恒为 ×1；
##   2. `SkillDataTool.getSkillAddedAtk()` 优先读技能数据的 `value2Base/value2Level`，
##      本工程 `数据/技能.json` 只导了 `valueBase/valueLevel`（= `damage`/`damage_growth`）
##      ⇒ **少 value2 那一档**，只有 value2 非 0 的技能会偏低；
##   3. `clientCombatHp` 那层"客户端预演血量"——离线时怪自己的 `hp` 就是权威，不需要预演。

## 战斗率（闪避/暴击这些 per-mille 值）的上限：原版 `COMBAT_RATE_CAP = 500` ⇒ 50%。
const 战斗率上限 := 500
const 战斗率刻度 := 1000
## 原版 `MONSTER_DAMAGE_REDUCTION_BASE = 100`：怪打人的减伤分母常数。
const 减伤基数 := 100

## `Client.isFiveHitMouse()`：这几只怪单次伤害不超过它最大血量的 1/5。
const 五刀鼠段 := [[4100000, 4100019], [4200000, 4200019], [4300000, 4300000]]

static func 是五刀鼠(怪id: int) -> bool:
	for 段 in 五刀鼠段:
		if 怪id >= int(段[0]) and 怪id <= int(段[1]):
			return true
	return false

## `Client.eliteCombatMultiplier()`（`Client.as:10947-10962`）：按精英属性放一个系数。
## ⚠️ 和 `CombatActor.最大血量`（`Monster.clientCombatMaxHp`）**不是同一个函数**：
## 那个 attrType 16 乘 **3**，这个乘 **2**。别把两处的常数并成一个。
static func 精英倍率(精英: Array, 类型: int) -> float:
	var 倍率 := 1.0
	for 项 in 精英:
		if not 项 is Dictionary:
			continue
		var 属性类型 := int((项 as Dictionary).get("attr_type", 0))
		if 属性类型 == 类型:
			倍率 *= maxf(1.0, float((项 as Dictionary).get("value", 1)))
		elif 属性类型 == 16:
			倍率 *= 2.0
	return 倍率

## `_loc10_` —— 命中率（百分数），原版最后夹在 [55, 98] 之间。
static func 命中率(玩家属性: Dictionary, 怪定义: Dictionary) -> float:
	var ap_dex := float(玩家属性.get("ap_dex", 0))
	var 等级 := float(玩家属性.get("level", 1))
	var 闪避 := maxf(0.0, float(怪定义.get("avoidance", 0)))
	var 基 := maxf(100.0, 等级 * 100.0 + maxf(0.0, ap_dex) * 10.0)
	var 值 := 95.0 \
			- roundf(闪避 * 35.0 / maxf(1.0, 闪避 + 基)) \
			- maxf(0.0, float(怪定义.get("level", 1)) - 等级) * 2.0 \
			+ minf(10.0, maxf(0.0, ap_dex) / maxf(1.0, 等级 * 20.0))
	return maxf(55.0, minf(98.0, 值))

## `_loc12_` —— 伤害。`暴击` 由调用方掷（`_loc14_`），因为暴击要连同伤害数字一起返回。
static func 伤害(玩家属性: Dictionary, 怪定义: Dictionary, 怪精英: Array,
		技能加成攻击: int, 怪id: int, 暴击: bool) -> int:
	var ap_dex := float(玩家属性.get("ap_dex", 0))
	var 攻击 := float(玩家属性.get("attack", 0))
	var 系数 := maxf(25.0, 100.0 + float(技能加成攻击))
	var 防 := maxf(0.0, float(怪定义.get("defense", 0)) * 精英倍率(怪精英, 5))
	var 伤 := maxi(1, roundi(maxf(1.0, 攻击 - maxf(0.0, 防 - ap_dex / 2.0)) * 系数 / 100.0))
	if 暴击:
		伤 *= 2
	return 伤

## 掷一次完整结算。返回 `{命中, 暴击, 伤害}`；未命中时伤害为 0、暴击为假
## （原版就是 `new MobDamageItem(_loc12_, _loc14_ ? 1 : 0)`，`_loc12_` 保持 0）。
static func 判定(玩家属性: Dictionary, 怪定义: Dictionary, 怪精英: Array,
		技能加成攻击: int, 怪id: int, 怪最大血量: int) -> Dictionary:
	if randf() * 100.0 >= 命中率(玩家属性, 怪定义):
		return {"命中": false, "暴击": false, "伤害": 0}
	var 暴击 := randf() * 1000.0 < minf(500.0, maxf(0.0, float(玩家属性.get("critical", 0))))
	var 伤 := 伤害(玩家属性, 怪定义, 怪精英, 技能加成攻击, 怪id, 暴击)
	if 是五刀鼠(怪id):
		伤 = mini(伤, maxi(1, int(roundf(float(maxi(1, 怪最大血量)) / 5.0))))
	return {"命中": true, "暴击": 暴击, "伤害": 伤}


## **怪打玩家**（离线用）。真值：夹具服务端 `_apply_server_monster_damage()`
## （`2.2.3/tools/fake_flash_server.py:36777-36847`）——
##   `减伤后 = round(怪攻 × 100 / (100 + max(0, 玩家防御)))`
##   → 再乘玩家减伤%；先滚玩家闪避，闪避中了伤害 0；
##   怪的 `fixDamage` 非 0 时**直接就是那个数**；否则滚怪暴击（×2）。
## 精英属性类型与 `Client.eliteCombatMultiplier` 同一套枚举：
## 攻击 4 / 防御 5 / 暴击 6 / 闪避 7 / 16(狂暴) 见到就再乘 2。
##
## ⚠️ 这条**不是原版客户端真值**：原版永远联网，客户端不做这个预演 —— 玩家挨多少血是服务端
##    用 `194` 包直接告诉客户端的（`Client.as` 里根本没有这条公式）。离线没有原版可依，
##    用 2.2.3 服务端那份重实现的口径是**最接近**的选择，所以出处写在这里，别当成原版原文。
##
## ⚠️ 本工程没建模的输入：`ignoreDefence`（无视防御）、`damage_reduce`（玩家减伤）、
##    宠物/技能 buff、无敌帧 —— 都按 0 处理。
static func 怪打玩家(玩家属性: Dictionary, 怪定义: Dictionary, 怪精英: Array) -> Dictionary:
	if randi() % 战斗率刻度 < mini(战斗率上限, maxi(0, int(玩家属性.get("dodge", 0)))):
		return {"命中": false, "暴击": false, "伤害": 0}
	var 固定 := int(怪定义.get("fix_damage", 0))
	if 固定 > 0:
		return {"命中": true, "暴击": false, "伤害": maxi(1, 固定)}
	var 怪攻 := maxf(0.0, float(怪定义.get("attack", 0)) * 精英倍率(怪精英, 4))
	var 防 := maxf(0.0, float(玩家属性.get("defense", 0)))
	var 伤 := 怪攻 * float(减伤基数) / (float(减伤基数) + 防)
	var 怪暴击 := roundf(maxf(0.0, float(怪定义.get("critical", 0)) * 精英倍率(怪精英, 6)))
	var 暴击 := randi() % 战斗率刻度 < mini(战斗率上限, maxi(0, int(怪暴击)))
	if 暴击:
		伤 *= 2.0
	return {"命中": true, "暴击": 暴击, "伤害": maxi(1, roundi(伤))}
