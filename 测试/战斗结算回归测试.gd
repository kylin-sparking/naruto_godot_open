## 离线「我打怪」的伤害结算（原版 `Client.applyClientPveAttack()`，`Client.as:11005-11057`）。
##
## 钉的是**纯函数**：命中率、伤害、暴击、五刀鼠上限、精英倍率 —— 都能手算对。
## `判定()` 里那两次掷骰不手算，只断言"命中/未命中的形状自洽"。
extends SceneTree

const 结算 := preload("res://脚本/角色/战斗结算.gd")
const 战斗角色 := preload("res://脚本/角色/战斗角色.gd")

var _failures: Array[String] = []
var _checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _近(实际: float, 期望: float, 容差 := 0.01) -> bool:
	return absf(实际 - 期望) <= 容差

## 怪打玩家 —— 口径出自夹具服务端 `_apply_server_monster_damage()`（不是原版客户端，
## 离线没有原版可依，见 `战斗结算.gd` 的注释）。
func _C_怪打玩家() -> void:
	# ① 减伤公式：`round(怪攻 × 100 / (100 + 玩家防御))`。怪暴击设 0 ⇒ 掷骰必不中，可手算。
	var 怪 := {"attack": 60, "critical": 0, "fix_damage": 0}
	var 玩家 := {"defense": 18, "dodge": 0}
	_check(结算.怪打玩家(玩家, 怪, [])["伤害"] == 51,
			"60 攻打 18 防应得 round(60×100/118)=51（实际 %d）" % 结算.怪打玩家(玩家, 怪, [])["伤害"])
	_check(结算.怪打玩家({"defense": 0, "dodge": 0}, 怪, [])["伤害"] == 60, "0 防应原样吃满 60")
	_check(结算.怪打玩家({"defense": 100000, "dodge": 0}, 怪, [])["伤害"] == 1,
			"防御再高也保底 1（原版 `MONSTER_MIN_DAMAGE = 1`）")

	# ② `fixDamage` 非 0 ⇒ 直接就是那个数，不走公式（113 只怪有）
	_check(结算.怪打玩家({"defense": 99999, "dodge": 0}, {"attack": 5, "critical": 0, "fix_damage": 999}, [])["伤害"] == 999,
			"fix_damage 非 0 时应直接取它")

	# ③ 精英属性：攻击类型是 4、类型 16(狂暴) 再乘 2
	_check(结算.怪打玩家({"defense": 20, "dodge": 0}, 怪, [{"attr_type": 4, "value": 2}])["伤害"] == 100,
			"精英攻击 ×2 ⇒ 120 攻打 20 防 = 100")
	_check(结算.怪打玩家({"defense": 20, "dodge": 0}, 怪, [{"attr_type": 16}])["伤害"] == 100,
			"精英类型 16 也乘 2")

	# ④ 闪避：per-mille、上限 500 ⇒ 一半。400 次里命中数该在一半附近，且未命中必是 0 伤害
	var 命中数 := 0
	for _i in 400:
		var r: Dictionary = 结算.怪打玩家({"defense": 18, "dodge": 500}, 怪, [])
		if bool(r["命中"]):
			命中数 += 1
			_check(int(r["伤害"]) == 51, "命中时伤害仍是 51")
		else:
			_check(int(r["伤害"]) == 0, "闪避掉应是 0 伤害")
	_check(命中数 > 120 and 命中数 < 280,
			"闪避 500（50%%）时 400 次里命中数该在一半附近（实际 %d）" % 命中数)

func _run() -> void:
	# 一组离线默认属性（`离线示例数据.player_stats`）+ 一只小怪（`怪物.json` 1000001）
	var 玩家 := {"level": 80, "ap_dex": 5, "attack": 25, "critical": 5}
	var 怪 := {"level": 2, "defense": 5, "avoidance": 10}

	# ① 命中率：手算 —— 闪避 10、基 = max(100, 80*100+5*10) = 8050
	#    95 - round(10*35/8060) - max(0, 2-80)*2 + min(10, 5/1600)
	#    = 95 - 0 - 0 + 0.003125
	_check(_近(结算.命中率(玩家, 怪), 95.003125, 0.001),
			"命中率应手算得 95.003125（实际 %.6f）" % 结算.命中率(玩家, 怪))

	# ② 伤害：防 5、系数 max(25,100+0)=100 ⇒ max(1, 25 - max(0, 5-2.5)) = 22.5 → 23
	_check(结算.伤害(玩家, 怪, [], 0, 1000001, false) == 23,
			"普攻伤害应手算得 23（实际 %d）" % 结算.伤害(玩家, 怪, [], 0, 1000001, false))
	# 暴击 ×2（原版 `if(_loc14_) _loc12_ *= 2`）
	_check(结算.伤害(玩家, 怪, [], 0, 1000001, true) == 46, "暴击应把伤害乘 2")
	# 系数：技能加成攻击 100 ⇒ 系数 200 ⇒ 22.5 * 2 = 45
	_check(结算.伤害(玩家, 怪, [], 100, 1000001, false) == 45,
			"技能加成 100 时系数应为 200（实际 %d）" % 结算.伤害(玩家, 怪, [], 100, 1000001, false))
	# 系数下限 25（原版 `Math.max(25, 100 + _loc6_)`）
	_check(结算.伤害(玩家, 怪, [], -200, 1000001, false) == 6,
			"系数应夹在 25 以上（22.5×0.25=5.625→6，实际 %d）" % 结算.伤害(玩家, 怪, [], -200, 1000001, false))
	# 伤害下限 1（原版 `Math.max(1, ...)`）
	_check(结算.伤害({"level": 1, "ap_dex": 0, "attack": 1, "critical": 0},
			{"level": 1, "defense": 9999, "avoidance": 0}, [], 0, 1000001, false) == 1,
			"伤害不应低于 1")

	# ③ `ap_DEX/2` 抵扣防御：防 10、dex 20 ⇒ 有效防 = 0 ⇒ 攻击原样过
	_check(结算.伤害({"level": 1, "ap_dex": 20, "attack": 50, "critical": 0},
			{"level": 1, "defense": 10, "avoidance": 0}, [], 0, 1000001, false) == 50,
			"ap_DEX/2 应抵扣防御（50 - max(0, 10-10) = 50）")

	# ④ 五刀鼠（`Client.isFiveHitMouse():10967-10970`）
	_check(结算.是五刀鼠(4100000) and 结算.是五刀鼠(4100019), "4100000~4100019 是五刀鼠")
	_check(结算.是五刀鼠(4200000) and 结算.是五刀鼠(4300000), "4200000 段与 4300000 也是五刀鼠")
	_check(not 结算.是五刀鼠(4100020) and not 结算.是五刀鼠(4300001), "段外不是五刀鼠")
	# 上限 = 最大血量/5：把攻击堆到必超上限，验证被夹住
	var 猛 := {"level": 999, "ap_dex": 9999, "attack": 999999, "critical": 0}
	var 鼠 := 结算.判定(猛, {"level": 1, "defense": 0, "avoidance": 0}, [], 0, 4100000, 50)
	if bool(鼠["命中"]):
		_check(int(鼠["伤害"]) <= 10, "五刀鼠单次伤害不应超过最大血量的 1/5（50/5=10）")

	# ⑤ 精英倍率（`Client.eliteCombatMultiplier():10947-10962`）—— attrType 16 乘 **2**
	_check(_近(结算.精英倍率([{"attr_type": 5, "value": 3}], 5), 3.0), "同类型精英属性应按 value 乘")
	_check(_近(结算.精英倍率([{"attr_type": 5, "value": 3}], 7), 1.0), "类型不匹配时不乘")
	_check(_近(结算.精英倍率([{"attr_type": 16, "value": 9}], 5), 2.0), "attrType 16 乘 2")
	# ⚠️ 和 `CombatActor.最大血量`（`Monster.clientCombatMaxHp`）**不是同一个函数**：
	#    那个 attrType 16 乘 **3**。这条断言就是防"两处常数被并成一个"。
	_check(战斗角色.最大血量(100, [{"attr_type": 16}]) == 300,
			"血量那条 attrType 16 应乘 3（两处常数不同，别并）")
	_check(战斗角色.最大血量(100, [{"attr_type": 1, "value": 5}]) == 500,
			"血量那条 attrType 1 应按 value 乘")

	# ⑥ `判定()` 的形状自洽：命中则伤害 ≥1，未命中则伤害 0 且不暴击
	# 暴击那一档要拉满：`critical` 5 时暴击率是 5/1000，400 次里一次暴击都不出的概率约 15%
	# —— 那种断言是**偶发红**。拉到 500（原版上限 `min(500, bsk)`）⇒ 五成暴击。
	var 高暴 := {"level": 80, "ap_dex": 5, "attack": 25, "critical": 500}
	var 命中数 := 0
	var 暴击数 := 0
	for _i in 400:
		var r: Dictionary = 结算.判定(高暴, 怪, [], 0, 1000001, 120)
		if bool(r["命中"]):
			命中数 += 1
			if bool(r["暴击"]):
				暴击数 += 1
			_check(int(r["伤害"]) >= 1, "命中时伤害应 ≥ 1")
		else:
			_check(int(r["伤害"]) == 0 and not bool(r["暴击"]), "未命中时应是 0 伤害且不暴击")
	# ⚠️ 消息里那个 `95%%` 要写两个百分号 —— 单个 `%` 会被 `%` 格式化当成格式符，
	#    整个 `_check(...)` 当场抛错、**这条断言被静默跳过**（第一次就踩了）。
	_check(命中数 > 300 and 命中数 < 400, "命中率约 95%%，400 次里不该全中或全不中（实际 %d）" % 命中数)
	_check(暴击数 > 0, "暴击率 5/1000，400 次里应出现过（实际 %d）" % 暴击数)

	_C_怪打玩家()

	if _failures.is_empty():
		print("战斗结算回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
