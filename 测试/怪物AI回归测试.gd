## 离线怪的行为状态机（原版 `com/mxw/roles/ai/`）。
##
## 分两段：
##   A **合成场景** —— 自己造一只宿主怪 + 一只假玩家，**逐帧手动喂 `tick()`**，
##     把四个状态（自由 / 追击 / 回巢 / 站）与"按 mob.speed 折算的步速"钉死。
##     手动喂帧是为了可复现：真等 `_process` 的话受 headless 帧率影响，会偶发红。
##   B **真地图** —— 确认离线怪真的挂上了 AI、挡板取自脚点链、步速是
##     `Physics.WALK_SPEED(125) × 1.4 × speed/100`（与服务端
##     `fake_flash_server._monster_walk_velocity` 同一个公式）。
extends SceneTree

const 战斗角色 := preload("res://脚本/角色/战斗角色.gd")
const 动画精灵 := preload("res://脚本/角色/原始动画精灵.gd")

var _failures: Array[String] = []
var _checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("怪物AI回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)

## 造一只只跑 AI、不跑 `_process` 的怪（出招也被 `_attack_timer` 闸住，免得改到会话状态）。
func _造怪(定义: Dictionary, 精灵: Node = null) -> CombatActor:
	var 怪 := 战斗角色.new() as CombatActor
	怪.kind = "m"
	怪.alive = true
	怪.position = Vector2.ZERO
	root.add_child(怪)
	怪.configure_actor("m", "1", "测试怪", 精灵, -500.0, 500.0)
	怪.configure_monster_ai(定义, Vector2.ZERO, -500.0, 500.0)
	怪.set_process(false)          # 帧由测试自己喂
	怪.set("_attack_timer", 1.0e9)
	return 怪

func _造玩家(位置: Vector2) -> Node2D:
	var 玩家 := Node2D.new()
	玩家.add_to_group("player")
	root.add_child(玩家)
	玩家.global_position = 位置
	return 玩家

func _喂(怪: CombatActor, 玩家: Node2D, 帧数: int) -> void:
	var ai: RefCounted = 怪.get("_ai")
	for _i in 帧数:
		ai.call("tick", 怪, 1.0 / 60.0)

func _基本定义(覆盖 := {}) -> Dictionary:
	var 定义 := {
		"move_range": 10, "area_chase": 0, "area_y": 0, "area_chase_y": 0,
		"walk_rate": 5, "first_attack": false, "boss": 0, "speed": 80,
	}
	for 键 in 覆盖:
		定义[键] = 覆盖[键]
	return 定义

func _run() -> void:
	await _A_合成场景()
	await _C_技能()
	await _B_真地图()
	await _D_伤害数字颜色()
	_finish()

## 伤害数字的红/白（§3.87 在线暴击红字）。真值 `Monster.player_addAttriChangeTip`：
## 普通 `MOB_HP_COMMON`=白、暴击 `MOB_HP_BSK`=16711680 红。以前**颜色从没被任何门钉过**
## （"离线已通"指的是 战斗结算 的暴击**数学**，渲染这一层一直是裸的）。
## 两条入口都要钉：在线 `apply_server_damage(量, 暴击)`（184/243 驱动）
## 与离线 `take_damage(量, 击退, 暴击)`（战斗结算驱动）。
func _D_伤害数字颜色() -> void:
	var 怪 := _造怪(_基本定义())
	怪.apply_server_damage(74, true)
	var 红 := _最后伤害数字(怪)
	_check(红 != null and 红.get_theme_color("font_color") == Color(1.0, 0.0, 0.0),
			"在线暴击的数字该是 MOB_HP_BSK 红（实际 %s）" % _色dump(红))
	怪.apply_server_damage(37, false)
	var 白 := _最后伤害数字(怪)
	_check(白 != null and 白.get_theme_color("font_color") == Color.WHITE,
			"在线普通伤害该是 MOB_HP_COMMON 白（实际 %s）" % _色dump(白))
	_check(白 != null and String(白.text).contains("37"), "数字文本该带伤害值（实际 %s）" % (白.text if 白 != null else "null"))
	# 离线那条走同一个 `_spawn_damage_number`，也要接上暴击位
	var 怪2 := _造怪(_基本定义())
	怪2.hp = 100000
	怪2.max_hp = 100000
	怪2.take_damage(88, 0.0, true)
	var 红2 := _最后伤害数字(怪2)
	_check(红2 != null and 红2.get_theme_color("font_color") == Color(1.0, 0.0, 0.0),
			"离线暴击的数字也该红（take_damage 第三位要通到渲染，实际 %s）" % _色dump(红2))
	# §3.88.4：`apply_server_damage` 的第三位（受击动画）要真被尊重 ——
	# DoT(243) 传 false 不该碰 hit1 僵直；出手(184) 传 true 该碰。用"没被写过的哨兵值"判，
	# 不依赖 hit1 到底多少秒（精灵/元数据缺了会让 `_动作秒数` 返 0，`>0` 判据会假绿）。
	怪2.set("_hit_timer", -5.0)
	怪2.apply_server_damage(30, false, false)
	_check(is_equal_approx(float(怪2.get("_hit_timer")), -5.0),
			"受击动画=false 不该写 _hit_timer（DoT 每跳别僵一下，实际 %s）" % str(怪2.get("_hit_timer")))
	怪2.apply_server_damage(30, false, true)
	_check(not is_equal_approx(float(怪2.get("_hit_timer")), -5.0),
			"受击动画=true 该写 _hit_timer（出手命中要受击，哨兵值没被改动=分支没跑）")
	怪.free()
	怪2.free()

## 找格子上最后挂出来的那条伤害数字（`_spawn_damage_number` 把 伤害数字 Node2D add_child 进来，
## 数字本体是它唯一的 Label 孩子）。按**脚本身份**认，别拿"有孩子的 Node2D"当特征 ——
## 血条也是挂脚本的 Node2D、里面也有 Label， loose 匹配会把血条当成数字（假绿）。
const 伤害数字脚本 := preload("res://脚本/角色/伤害数字.gd")

func _最后伤害数字(怪: Node) -> Label:
	## 飘字现在走原版那条 400 毫秒队列（`Monster.as:435-447` 入列 + `:883` 每 400 毫秒放一条），
	## 投完不排空就读 ⇒ 读到 null（2026-10-11 接完队列这条门 4 条红全是这个）。
	var 队 := 怪.get_node_or_null("飘字队列")
	if 队 != null:
		队.call("全放")
	for i in range(怪.get_child_count() - 1, -1, -1):
		var 子 := 怪.get_child(i) as Node2D
		if 子 == null or 子.get_script() != 伤害数字脚本:
			continue
		if 子.get_child_count() == 0:
			continue
		var 标 := 子.get_child(0) as Label
		if 标 != null:
			return 标
	return null

func _色dump(标: Label) -> String:
	return "null" if 标 == null else str(标.get_theme_color("font_color"))

func _A_合成场景() -> void:
	# ① `firstAttack`：玩家在巡逻区内 → 立刻进追击(4)，并朝玩家走。
	var 玩家 := _造玩家(Vector2(300.0, 0.0))
	var 怪 := _造怪(_基本定义({"first_attack": true}))
	_check(is_equal_approx(float(怪.get("home_left")), -500.0) and is_equal_approx(float(怪.get("home_right")), 500.0),
			"configure_monster_ai 应把脚点挡板写回宿主的 home_left/right")
	_喂(怪, 玩家, 1)
	_check(怪.ai状态 == 4, "firstAttack 的怪、玩家在区内，应进追击态（实际 %d）" % 怪.ai状态)
	var 起x := 怪.position.x
	_喂(怪, 玩家, 60)
	_check(怪.position.x > 起x + 100.0,
			"追击时应朝玩家（+x）走，秒速约 175×speed/100=140（实际走了 %.1f px/秒）" % (怪.position.x - 起x))
	_check(bool(怪.get("仇恨中")), "追击时应落下 angroAtPlayer")

	# ② 玩家跑出追击区（areaChase=2 ⇒ 200px）→ 脱战回巢(3)，朝出生点走。
	玩家.global_position = Vector2(5000.0, 0.0)
	# 一段动作要播完（追/回巢都是 6 帧）才会重新判，喂满一段再断言。
	_喂(怪, 玩家, 8)
	_check(怪.ai状态 == 3, "玩家跑出追击区应转回巢态（实际 %d）" % 怪.ai状态)
	_check(not bool(怪.get("仇恨中")), "脱战回巢应清掉 angroAtPlayer")
	var 脱战x := 怪.position.x
	_喂(怪, 玩家, 30)
	_check(怪.position.x < 脱战x, "回巢应朝出生点（-x）走")

	# ③ 走到出生点附近 → 回到自由态(2)。出生点 x=0，先把它挪过去再喂。
	怪.position.x = 0.0
	_喂(怪, 玩家, 8)
	_check(怪.ai状态 == 2, "回到出生点附近应转自由态（实际 %d）" % 怪.ai状态)
	怪.get_parent().remove_child(怪)
	怪.free()
	玩家.get_parent().remove_child(玩家)
	玩家.free()

	# ④ `walkRate` 的两端：100 ⇒ 自由段一定走；0 ⇒ 一定站。步速按 `speed` 折算。
	玩家 = _造玩家(Vector2(9000.0, 0.0))
	var 走怪 := _造怪(_基本定义({"walk_rate": 100, "speed": 80, "move_range": 100}))
	_喂(走怪, 玩家, 1)
	_check(走怪.get("_ai").get("_本段") == "move", "walkRate=100 时自由段应选走")
	# 自由段的长度是随机的 20~99 帧，**每段结尾那一帧只做决定、不位移** —— 不钉死它，
	# 这条断言就会随段长在 135~140 之间飘。这里把这一段拉长，量的是纯粹的步速。
	走怪.get("_ai").set("_剩余帧", 1.0e9)
	var 走起 := 走怪.position.x
	_喂(走怪, 玩家, 60)
	var 走了 := absf(走怪.position.x - 走起)
	_check(absf(走了 - 140.0) < 3.0,
			"速度应为 Physics.WALK_SPEED(125)×1.4×speed(80)/100 = 140 px/秒（实测 %.1f）" % 走了)
	var 站怪 := _造怪(_基本定义({"walk_rate": 0, "move_range": 100}))
	_喂(站怪, 玩家, 1)
	_check(站怪.get("_ai").get("_本段") == "stand", "walkRate=0 时自由段应选站")
	var 站起 := 站怪.position.x
	_喂(站怪, 玩家, 120)
	_check(is_equal_approx(站怪.position.x, 站起), "站住时不应位移")
	for 清理 in [走怪, 站怪, 玩家]:
		清理.get_parent().remove_child(清理)
		清理.free()

	# ⑤ area=0 的怪（GameData 里有 18 只）判不进巡逻区 ⇒ 回到出生点待着，等于原地不动。
	var 零玩家 := _造玩家(Vector2(9000.0, 0.0))
	var 零怪 := _造怪(_基本定义({"move_range": 0}))
	var 零起 := 零怪.position.x
	_喂(零怪, 零玩家, 60)
	_check(零怪.ai状态 == 2, "area=0 的怪不应乱跑（实际状态 %d）" % 零怪.ai状态)
	_check(absf(零怪.position.x - 零起) < 1.0, "area=0 的怪不应位移")
	for 清理 in [零怪, 零玩家]:
		清理.get_parent().remove_child(清理)
		清理.free()


## 技能侧（原版 `AttackExecute` + `MobAttackTool`）。这里用**真美术**（怪 2000002 有
## attack1..attack4）而不是桩 —— "这套美术有没有这个动作"那条判据才是真跑的。
func _C_技能() -> void:
	var 玩家 := _造玩家(Vector2(40.0, 0.0))
	var 定义 := _基本定义({
		"first_attack": true, "speed": 80,
		"skill": {
			"0": {"skill": 0, "stance": "attack1", "skillRate": 100},
			"2": {"skill": 8000, "level": 1, "stance": "attack1", "skillRate": 0},
			"1": {"skill": 8000, "level": 1, "stance": "attack2", "skillRate": 100, "attackAfter": 600},
		},
	})
	var 精灵 := 动画精灵.new() as Node2D
	var 怪 := _造怪(定义, 精灵)
	怪.add_child(精灵)
	_check(bool(精灵.call("configure", "mob", "2000002", "stand")),
			"测试用怪 2000002 的美术应能加载（否则本条测的就不是真动作表）")
	var ai: RefCounted = 怪.get("_ai")

	# ① `AttackExecute.getAttacks()`：`skill == 0` 的槽丢掉、按 index 排序、`skillRate` 兜底 50
	var 槽: Array = ai.get("技能槽")
	_check(槽.size() == 2, "skill==0 的槽应被丢掉（实际剩 %d 槽）" % 槽.size())
	if 槽.size() == 2:
		_check(int(槽[0]["index"]) == 1 and int(槽[1]["index"]) == 2, "候选招应按槽位 index 排好序")
		_check(int(槽[1]["skillRate"]) == 50, "skillRate 为 0 时应兜底成 50（原版 `int(...) || 50`）")

	# ② `canFireSkillTo` + `ActionLogic`：框得到就播这一槽的 stance，并记 CD
	ai.set("_当前槽", 槽[0])                       # 槽 1 = stance attack2
	_check(bool(怪.call("有动作", "attack2")), "2000002 应有 attack2（否则重抽那条路会挡掉这次出手）")
	ai.call("_尝试出手", 怪, 玩家)
	_check(String(精灵.get("action")) == "attack2",
			"出手应播这一槽的 stance（期望 attack2，实际 %s）" % String(精灵.get("action")))
	_check((ai.get("_技能CD") as Dictionary).size() == 1, "出手后应记一条 CD")
	_check(float(ai.get("_结算倒计时")) > 0.5, "attackAfter=600 时不应立刻结算（原版到点才 applyDamage）")
	_check(ai.get("_待结算玩家") == 玩家, "应记着到点后结算给谁")

	# ③ CD 期间不再出手（原版 `isCding`）
	精灵.set("action", "stand")
	ai.set("_当前槽", 槽[0])
	ai.call("_尝试出手", 怪, 玩家)
	_check(String(精灵.get("action")) == "stand", "CD 没走完不应再出同一招")

	# ④ 走 1.5 秒（兜底 CD 是 1200ms）：CD 与结算倒计时都该清掉，待结算目标清空。
	# 先把玩家挪远 —— 否则怪在这 1.5 秒里会**继续出招**，CD 永远清不掉（第一次就栽在这）。
	玩家.global_position = Vector2(9000.0, 0.0)
	for _i in 90:
		ai.call("tick", 怪, 1.0 / 60.0)
	_check((ai.get("_技能CD") as Dictionary).is_empty(), "1200ms 兜底 CD 走完 1.5 秒后应已清掉")
	_check(float(ai.get("_结算倒计时")) < 0.0, "attackAfter 到点后倒计时应收回 <0")
	_check(ai.get("_待结算玩家") == null, "结算完应把待结算目标清掉")

	# ⑤ 技能框不到目标就不放（原版 `canFireSkillTo` 的最后一条）
	玩家.global_position = Vector2(-4000.0, 0.0)
	精灵.set("action", "stand")
	ai.set("_当前槽", 槽[0])
	ai.set("_技能CD", {})
	ai.call("_尝试出手", 怪, 玩家)
	_check(String(精灵.get("action")) == "stand", "技能框不到玩家时不应出手")

	# ⑥ `_重置技能` 按 skillRate 加权：只留一条候选就必中它
	var 一条 := _造怪(_基本定义({"skill": {"0": {"skill": 8000, "stance": "attack1", "skillRate": 100}}}), null)
	一条.get("_ai").call("_重置技能")
	_check(not (一条.get("_ai").get("_当前槽") as Dictionary).is_empty(),
			"只有一条候选招时 _重置技能 应选中它")

	# ⑦ 没有技能表的怪退回普攻（GameData 里有 18 只这样的）
	var 无招 := _造怪(_基本定义({}), null)
	_check((无招.get("_ai").get("技能槽") as Array).is_empty(), "没有 skill 段的怪候选招应为空")

	for 清理 in [怪, 一条, 无招, 玩家]:
		清理.get_parent().remove_child(清理)
		清理.free()

func _B_真地图() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for _frame in 12:
		await process_frame
	var 脚点 := 场景.get_node_or_null("Footholds")
	var 生怪 := 0
	for 实体 in (场景.get_node_or_null("LifeRoot").get("_entities") as Array):
		var 怪 := 实体 as Node2D
		if 怪 == null or String(怪.get("kind")) != "m":
			continue
		_check(怪.get("_ai") != null, "离线怪应挂上 MonsterAI")
		_check(not bool(怪.get("authoritative")), "离线怪不应是权威态")
		生怪 += 1
		var 定义: Dictionary = (load("res://脚本/单例/游戏数据.gd") as GDScript).monster(怪.get("entity_id"))
		var 期望 := 175.0 * float(maxi(1, int(定义.get("speed", 80)))) / 100.0
		_check(is_equal_approx(float(怪.get("_ai").get("行走速度")), 期望),
				"步速应由 mob.speed 折算（期望 %.1f）" % 期望)
		var 段号 := String((脚点.call("find_click_target", 怪.position) as Dictionary).get("id", ""))
		if 段号 != "":
			var 段: Dictionary = 脚点.id_map[段号]
			_check(float(怪.get("home_left")) <= minf(float(段.x1), float(段.x2)) + 0.01,
					"挡板左端应取到脚点链的真实边界（不再是写死的 ±130）")
	_check(生怪 > 0, "本地图应有离线怪可供检查")
