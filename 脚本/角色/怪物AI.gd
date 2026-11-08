class_name MonsterAI
extends RefCounted

## 离线怪物的行为状态机 —— 按原版 `com/mxw/roles/ai/` 那套还原。
##
## 覆盖的原版件（都在 `2.2.3/map_extract/out/mainlib_as/scripts/com/mxw/roles/ai/`）：
##   `MonsterBaseControllers.tick()`  主循环：挑状态、挑这一段动作
##   `AIParameter`                    `isInPetrolArea` / `isInChaseArea` / `arrivedAtBirthPt` / `SWING_RANGE`
##   `FreeExecute.MoveFreeLogic`      自由段：站 20~99 帧、按 `walkRate%` 决定动不动
##   `ChaseExecute.MoveChaseLogic`    追击段：|Δx|<20 站住，否则朝目标走
##   `AngroExecute.MoveGetAngroLogic` 高度差 >40 时那套"来回蹭"的接近动作
##   `DirectionManage.getBirthDirection`
##   `MonsterParameter` 的四个状态常量
##
## ⚠️ **只管离线**。在线时怪由服务端权威驱动（`CombatActor.authoritative`），
##    这条路径整个不参与 —— 和 §3.61.4-A1 里说的"在线是服务端权威"一致。
##
## 本文件覆盖 `AttackExecute`/`MobAttackTool` 里离线用得上的那一半：
##   `getAttacks`        把 `mob.info.skill` 的槽位摊成候选招（`skill == 0` 的丢掉）
##   `resetSkill`        按 `skillRate` 累加后**加权抽一个**当 `curSkill`
##   `canFireSkillTo`    不在 CD 里 && 技能命中矩形框到目标
##   `ActionLogic`       播这一槽的 `stance` 动作
##   `recordCd`          CD = 槽位 `time`，没有就 1200ms（原版那条链的最后兜底）
##   `updateAttackCD`    逐帧扣 CD
##   `MonsterAttackEffect.tick()`  `attackAfter` 到点才结算伤害
##
## ⚠️ **没做的**：`SkillDataTool.getSkillCooltime()` 那条链要读技能数据的
##    `info.cool_down`，本工程 `数据/技能.json` **没有这个字段**（它给的是 `cooldown` 秒数，
##    形状不同）⇒ 直接用原版自己的最后兜底 1200ms。`forcedSkills` / `buff_loseMp`
##    那两条分支是服务端驱动的，离线不适用。
## ⚠️ **一处近似**：原版 `canFireSkillTo` 拿技能矩形 ∩ 目标的 `outerBodyRect`，
##    而**人物帧没有 lt/rb**（`数据/角色/动画元数据.json` 里角色帧只有 `delay`/`body`），
##    我们拿不到玩家体型盒 ⇒ 退化成"技能矩形是否框住玩家的**脚点**"。怪的体型盒不受影响。

const STATE_UNKNOWN := -1
const STATE_STAND := 1
const STATE_MOVE_FREE := 2
const STATE_MOVE_BACK := 3
const STATE_ANGRO := 4

## 原版是按帧跑的（`Engine.STAGE_FRAME_RATE = 60`），动作段的"20~99 帧"就是按这个折算。
const 帧 := 1.0 / 60.0
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
## 同 玩家.gd：命中盒几何只有一份，用 preload 免得冷启动时全局类名还没注册。
const SKILL_HITBOX := preload("res://脚本/角色/技能命中盒.gd")
## `AIParameter.isArrivedAtBirthPt()`：`|x - birthPoint.x| < 20`
const 到家距离 := 20.0
## `MonsterBaseControllers.tick()` 里 `GeomUtil.getDistance(...) < 60` 就站住不打
const 贴身距离 := 60.0
## 同一条：`Math.abs(_attackTarget.y - _monster.y) > 40` 才走 AngroExecute 那套
const 高度差阈值 := 40.0
## `AIParameter.MONSTER_SWING_RANGE` = `MathAD.rnd(100,200)`（每次读都重掷）
const 摆动_range下限 := 100.0
const 摆动_range上限 := 200.0

var 状态 := STATE_UNKNOWN
var 出生点 := Vector2.ZERO
# —— 来自 `数据/怪物.json`（`MobInfo.as` 的字段，`导出游戏数据.mjs` 原样搬过来）
var 巡逻半径 := 0.0        # `info.area` × 100
var 追击半径 := 0.0        # `info.areaChase` × 100；为 0 时**退回巡逻半径**（原版同）
var 巡逻高 := 0.0          # `info.areaY`
var 追击高 := 0.0          # `info.areaChaseY`
var 游走率 := 5.0          # `info.walkRate`（`MobInfo.getFromMobData` 兜底 5）
var 主动攻击 := false      # `info.firstAttack == 1`
var 是首领 := false        # `info.boss`
var 行走速度 := 140.0      # `Physics.WALK_SPEED(125) × 1.4 × speed/100`

# —— 飞行/游走方向上的物理挡板（原版的 `leftBlock`/`rightBlock`）
var 左界 := 0.0
var 右界 := 0.0

# —— 当前这一段动作（原版的 `_crtScript` 一帧一帧播，这里等价成"还剩几帧 + 这段干什么"）
var _剩余帧 := 0.0
var _本段 := "stand"       # stand / move
var _本段方向 := 1.0
var _朝向 := 1.0
## 原版 `Monster.angroAtPlayer` —— 已经拉住了玩家的仇恨。
var _仇恨中 := false

# —— 技能（原版 `AttackExecute` / `MobAttackTool`）
## `mob.info.skill` 的槽位摊平后的候选招。每项：index/skill/level/stance/skillRate/
## attackAfter/hitRect/time。`skill == 0` 的槽在这里就已经丢掉（`AttackExecute.getAttacks():193`）。
var 技能槽: Array = []
## 原版 `Monster.attackCDList`，键 `skillId + index*10000000`，值是**剩余毫秒**。
var _技能CD := {}
## 原版 `Monster.curSkill` —— 加权抽中的那一槽。
var _当前槽: Dictionary = {}
## 原版 `MonsterAttackEffect` 的 `attackAfter` 倒计时（秒）；< 0 表示没在等结算。
var _结算倒计时 := -1.0
var _待结算玩家: Node2D = null
## `recordCd()` 里那条链的最后一档：`getSkillCD`(槽位 `time`) 也没有时用 1200ms。
const 兜底冷却毫秒 := 1200
## `AttackExecute` 之外，原版 `MonsterParameter._dir` 会传给 AngroExecute；tick 开头置 0。
var _dir := 0.0

func 配置(怪定义: Dictionary, 出生: Vector2, 左: float, 右: float) -> void:
	出生点 = 出生
	左界 = 左
	右界 = 右
	巡逻半径 = float(int(怪定义.get("move_range", 0))) * 100.0     # `area` 就是这个
	追击半径 = float(int(怪定义.get("area_chase", 0))) * 100.0
	巡逻高 = float(int(怪定义.get("area_y", 0)))
	追击高 = float(int(怪定义.get("area_chase_y", 0)))
	游走率 = float(怪定义.get("walk_rate", 5))
	主动攻击 = bool(怪定义.get("first_attack", false))
	是首领 = int(怪定义.get("boss", 0)) != 0
	# `Monster.as:1777`：`this.walkSpeedFactor = 1.4 * mobInfo.speed / 100`，
	# 而 `AbstractPhysicObject.walkSpeed = Physics.WALK_SPEED(125) * walkSpeedFactor`
	# ⇒ 125 × 1.4 × speed/100 = 175 × speed/100。角色的 175 是同一个 125×1.4。
	行走速度 = 175.0 * float(maxi(1, int(怪定义.get("speed", 80)))) / 100.0
	_摊平技能槽(怪定义.get("skill", {}))

## `AttackExecute.getAttacks():186-210`：把 `mob.info.skill` 的每个槽摊成候选招。
## `skill == 0` 的槽丢掉；`skillRate` 缺失或为 0 时**兜底 50**（原版 `int(...) || 50`）。
func _摊平技能槽(表) -> void:
	技能槽.clear()
	if not (表 is Dictionary):
		return
	for 键 in 表:
		var 槽 = 表[键]
		if not (槽 is Dictionary):
			continue
		var 技能号 := int(槽.get("skill", 0))
		if 技能号 == 0:
			continue
		# ⚠️ AS3 的 `int(x) || 50` 是**取值**语义；GDScript 的 `or` 是**逻辑**运算
		# （`0 or 50` 得 true，再 int() 成 1）—— 直接照抄会静默变成权重 1。
		var 权重 := int(槽.get("skillRate", 0))
		if 权重 == 0:
			权重 = 50
		技能槽.append({
			"index": int(键),
			"skill": 技能号,
			"level": int(槽.get("level", 1)),
			"stance": String(槽.get("stance", "")),
			"skillRate": 权重,
			"attackAfter": int(槽.get("attackAfter", 0)),
			"time": int(槽.get("time", 0)),
			"hitRect": 槽.get("hitRect", {}),
		})
	技能槽.sort_custom(func(a, b): return int(a.index) < int(b.index))

## 每帧推进。`怪` 是宿主 `CombatActor`，这里只用它的坐标、朝向与播动作/出招那几个入口。
func tick(怪: CombatActor, delta: float) -> void:
	_dir = 0.0
	# 挡板每帧从宿主读一次 —— 离线「首领挑战」会**现场把宿主挪到玩家旁边并改 home_left/right**
	# （`地图实体.start_boss_encounter`），缓存下来那套就失灵了。
	左界 = minf(怪.home_left, 怪.home_right)
	右界 = maxf(怪.home_left, 怪.home_right)
	_推进技能(怪, delta)
	_剩余帧 -= delta / 帧
	if _剩余帧 > 0.0:
		_应用本段(怪, delta)
	else:
		_挑新段(怪)
	# 回写给宿主（原版 `Monster.aiState`）。必须放在**决策之后** —— 放在前面写的就是上一段的状态。
	怪.ai状态 = 状态

## 每帧推进技能侧的两件事：CD 倒计时（原版 `AttackExecute.updateAttackCD()`）
## 与 `attackAfter` 的伤害结算（原版 `MonsterAttackEffect.tick()`）。
func _推进技能(怪: CombatActor, delta: float) -> void:
	for 键 in _技能CD.keys():
		var 剩 := float(_技能CD[键]) - delta * 1000.0
		if 剩 <= 0.0:
			_技能CD.erase(键)
		else:
			_技能CD[键] = 剩
	if _结算倒计时 >= 0.0:
		_结算倒计时 -= delta
		if _结算倒计时 < 0.0:
			if is_instance_valid(_待结算玩家):
				怪.结算对玩家伤害(_待结算玩家)
			_待结算玩家 = null

## `AttackExecute.resetSkill()`：把 `skillRate` 累加成前缀和，抽一个落在哪一段，
## 那一槽就是这一轮的 `curSkill`（按权重选招，不是均匀选）。
func _重置技能() -> void:
	var 总 := 0
	for 槽 in 技能槽:
		总 += int(槽["skillRate"])
	if 总 <= 0:
		_当前槽 = {}
		return
	var 掷 := randi() % (总 + 1)          # 原版 `MathAD.rnd(0, 总分)` 是**闭区间**
	var 累计 := 0
	for 槽 in 技能槽:
		累计 += int(槽["skillRate"])
		if 累计 >= 掷:
			_当前槽 = 槽
			return
	_当前槽 = 技能槽[技能槽.size() - 1]

## `recordCd()` 那条链：槽位 `time` → `SkillDataTool.getSkillCooltime()` → 1200ms。
## 中间那一档本工程拿不到（`数据/技能.json` 没有 `info.cool_down`，见文件头）。
func _冷却毫秒(槽: Dictionary) -> int:
	var t := int(槽.get("time", 0))
	return t if t > 0 else 兜底冷却毫秒

## 原版 CD 表的键是 `skillId + index * 10000000`；这里用等价的字符串键，避开大整数。
func _冷却键(槽: Dictionary) -> String:
	return "%d_%d" % [int(槽["skill"]), int(槽["index"])]

## `MobAttackTool.computeSkillHitRect()` 的优先级：槽自带的 `hitRect` 优先，
## 没有才按技能的 `range` 查定表。两者都空 = 这个技能没有自动选敌 → 不放。
## ⚠️ 目标是**点**（玩家的脚点）而不是体型盒，原因见文件头。
func _框得到(怪: CombatActor, 玩家: Node2D, 槽: Dictionary) -> bool:
	var 朝向 := int(怪.get("_朝向"))
	var 盒: Rect2 = SKILL_HITBOX.由槽位(槽, 怪.position, 朝向)
	if 盒.size == Vector2.ZERO:
		盒 = SKILL_HITBOX.由范围(int(GAME_DATA.skill(int(槽["skill"])).get("range", 0)), 怪.position, 朝向)
	if 盒.size == Vector2.ZERO:
		return false
	return 盒.has_point(玩家.global_position)

## `AttackExecute.canFireSkillTo()` + `ActionLogic()` + `recordCd()`。
## 抽中的那一槽这套美术**不一定有那个动作**（怪的 stance 是 attack1..attack6，各怪不全）
## ⇒ 重抽几次；实在没有就退回普攻，不假装放了个技能。
func _尝试出手(怪: CombatActor, 玩家: Node2D) -> void:
	if _结算倒计时 >= 0.0:
		return                                   # 上一招还没结算（原版 `isAttack` 期间不出新招）
	if 技能槽.is_empty():
		怪.尝试攻击(玩家)                          # 没有技能表（GameData 里有 18 只）
		return
	if _当前槽.is_empty():
		_重置技能()
	var 试 := 0
	while 试 < 技能槽.size() and not 怪.有动作(String(_当前槽.get("stance", ""))):
		_重置技能()
		试 += 1
	var 动作 := String(_当前槽.get("stance", ""))
	if 动作 == "" or not 怪.有动作(动作):
		怪.尝试攻击(玩家)
		return
	if _技能CD.has(_冷却键(_当前槽)):
		return
	if not _框得到(怪, 玩家, _当前槽):
		return
	var 毫秒 := 怪.播技能动作(动作)
	if 毫秒 <= 0:
		return
	_技能CD[_冷却键(_当前槽)] = _冷却毫秒(_当前槽)
	# 表现（特效 + 飞行物）。有球时**伤害等命中**，不走 `attackAfter`；这条要在记 CD 之后。
	if 怪.放技能表现("%07d" % int(_当前槽["skill"]), 玩家):
		_待结算玩家 = null
		_结算倒计时 = -1.0
		return
	_结算倒计时 = float(int(_当前槽.get("attackAfter", 0))) / 1000.0
	_待结算玩家 = 玩家
	if _结算倒计时 <= 0.0:
		# 不少普攻槽的 `attackAfter` 就是 0 ⇒ 当帧结算，别留个永远不触发的倒计时
		怪.结算对玩家伤害(玩家)
		_待结算玩家 = null
		_结算倒计时 = -1.0

func _应用本段(怪: CombatActor, delta: float) -> void:
	if _本段 == "move":
		_移动(怪, _本段方向, delta)
	else:
		怪.播状态("stand")

## ⚠️ 这一段是"按帧"的：原版每帧读一次 `_crtScript`，我们这里一个 tick 走一次。
func _挑新段(怪: CombatActor) -> void:
	var 玩家 := 怪.get_tree().get_first_node_in_group("player") as Node2D
	# 原版这里还有 `_attackTarget.isDie` 与 `canBeAttack(_monster)`；本工程的玩家"倒下"是
	# 直接传送回出生点（`玩家._on_player_defeated`），没有持续的死亡态，所以只判在不在。
	var 玩家活着 := 玩家 != null
	if not _在区内(怪.position.x, 怪.position.y, 巡逻半径, 巡逻高) and not _仇恨中:
		回巢段(怪)
		return
	if _仇恨中:
		if not 玩家活着:
			_仇恨中 = false
			回巢段(怪)
			return
		if not _在区内(玩家.global_position.x, 玩家.global_position.y, _追击(), 追击高):
			脱战回巢(怪)
			return
		追击段(怪, 玩家)
		return
	if 主动攻击 and 玩家活着 and not _在爬梯(玩家) \
			and _在区内(玩家.global_position.x, 玩家.global_position.y, 巡逻半径, 巡逻高):
		_仇恨中 = true
		状态 = STATE_ANGRO
		追击段(怪, 玩家)
		return
	if 是首领:
		# `MonsterBaseControllers.tick()`：离出生点 >50 就站着并回巢，否则原地站着。
		状态 = STATE_MOVE_FREE
		if 出生点.distance_to(怪.position) > 50.0:
			_剩余帧 = 30.0
			_本段 = "move"
			_本段方向 = 1.0 if 出生点.x > 怪.position.x else -1.0
		else:
			_剩余帧 = 30.0
			_本段 = "stand"
		return
	自由段(怪)

## `AIParameter.isInPetrolArea / isInChaseArea` —— 拿一个点跟**出生点**比。
## `areaY/areaChaseY` 为 0 时用 `半径/2` 做高度判据（原版就是 `_loc3_ / 2`）。
func _在区内(x: float, y: float, 半径: float, 高: float) -> bool:
	if 半径 <= 0.0:
		return false
	var 纵向: bool
	if 高 != 0.0:
		if 高 > 0.0:
			纵向 = 出生点.y <= y + 10.0 and 高 + 出生点.y > y
		else:
			纵向 = 出生点.y >= y - 10.0 and 高 + 出生点.y < y
	else:
		纵向 = absf(y - 出生点.y) < 半径 / 2.0
	return absf(x - 出生点.x) < 半径 and 纵向

## `玩家.climbing` 是 bool 属性；`bool(null)` 在 Godot 里会报 "Nonexistent 'bool' constructor"，
## 所以这里显式比 `== true`（原版那个判据是"目标不在爬梯"）。
func _在爬梯(玩家: Node2D) -> bool:
	return 玩家.get("climbing") == true

func _追击() -> float:
	# 原版：`areaChase * 100` 为 0 时直接退回巡逻区判据
	return 追击半径 if 追击半径 > 0.0 else 巡逻半径

## `FreeExecute.MoveFreeLogic`：方向取"出生方向"，撞到挡板就反向；
## 帧数 = `floor(random*80)+20`；`random() > walkRate/100` 就站住，否则走。
func 自由段(怪: CombatActor) -> void:
	状态 = STATE_MOVE_FREE
	var 方向 := 出生方向(怪)
	if 怪.position.x <= 左界 + 4.0:
		方向 = 1.0
	elif 怪.position.x >= 右界 - 4.0:
		方向 = -1.0
	_剩余帧 = float(int(randf() * 80.0) + 20)
	if randf() > 游走率 / 100.0:
		_本段 = "stand"
	else:
		_本段 = "move"
		_本段方向 = 方向

## `DirectionManage.getBirthDirection`：在出生点左边就朝右（往家走），否则朝左。
func 出生方向(怪: CombatActor) -> float:
	return 1.0 if 怪.position.x < 出生点.x else -1.0

## `MonsterBaseControllers.tick()` 里"出区/目标死了 → `_crtScript = [AddFrame_MoveBack(...)]`
## + `_pathFindPt = birthPoint`"，回到 `|x-birth.x| < 20` 为止。
func 回巢段(怪: CombatActor) -> void:
	状态 = STATE_MOVE_BACK
	_仇恨中 = false
	怪.仇恨中 = false
	if absf(怪.position.x - 出生点.x) < 到家距离:
		_剩余帧 = 10.0
		_本段 = "stand"
		状态 = STATE_MOVE_FREE
		return
	_剩余帧 = 6.0
	_本段 = "move"
	_本段方向 = 1.0 if 出生点.x > 怪.position.x else -1.0

func 脱战回巢(怪: CombatActor) -> void:
	_仇恨中 = false
	怪.仇恨中 = false
	回巢段(怪)

## `ChaseExecute.MoveChaseLogic` + `MonsterBaseControllers` ANGLO 分支的站定/近身判据。
func 追击段(怪: CombatActor, 玩家: Node2D) -> void:
	状态 = STATE_ANGRO
	怪.仇恨中 = true
	var 目标 := 玩家.global_position
	var 水平差 := 目标.x - 怪.position.x
	if absf(水平差) < 20.0:
		_剩余帧 = 6.0
		_本段 = "stand"
		怪.播状态("stand")
		怪.面向(目标.x)
		return
	var 距离 := 怪.position.distance_to(目标)
	if 距离 < 贴身距离:
		_剩余帧 = 6.0
		_本段 = "stand"
		怪.播状态("stand")
		怪.面向(目标.x)
		_尝试出手(怪, 玩家)
		return
	if absf(目标.y - 怪.position.y) > 高度差阈值:
		# `AngroExecute.MoveGetAngroLogic`：高度差大时那套"按朝向和摆动距离来回蹭"的动作
		_剩余帧 = 6.0
		状态 = STATE_ANGRO
		var 方向 := _接近方向(怪, 目标.x)
		if 方向 == 0.0:
			return
		_本段 = "move"
		_本段方向 = 方向
		return
	# 同层：`ChaseExecute` 一路朝目标的 x 走
	_剩余帧 = 6.0
	_本段 = "move"
	_本段方向 = 1.0 if 水平差 > 0.0 else -1.0
	if 距离 < 60.0:
		_尝试出手(怪, 玩家)

## `AngroExecute.MoveGetAngroLogic`（`param3 == 0` 那一支）。
## 返回 0 表示"这一帧先不动"（原版会走 MoveBack 分支）。
func _接近方向(怪: CombatActor, 目标x: float) -> float:
	var 摆动 := randf_range(摆动_range下限, 摆动_range上限)
	var 朝右 := _朝向 > 0.0
	var 方向 := 0.0
	if 朝右:
		if 怪.position.x > 目标x:
			方向 = -1.0 if 怪.position.x - 目标x >= 摆动 else 1.0
			if 方向 > 0.0 and 怪.position.x >= 右界 - 4.0:
				方向 = -1.0
		else:
			方向 = 1.0
			if 怪.position.x >= 右界 - 4.0:
				return 0.0
	elif 怪.position.x < 目标x:
		方向 = 1.0 if 目标x - 怪.position.x >= 摆动 else -1.0
		if 方向 < 0.0 and 怪.position.x <= 左界 + 4.0:
			方向 = 1.0
	else:
		方向 = -1.0
		if 怪.position.x <= 左界 + 4.0:
			return 0.0
	return 方向

func _移动(怪: CombatActor, 方向: float, delta: float) -> void:
	if 方向 == 0.0:
		怪.播状态("stand")
		return
	_朝向 = 方向
	var 新x := 怪.position.x + 方向 * 行走速度 * delta
	# 原版靠 `leftBlock/rightBlock` 停住；离线这边没有碰撞体，用脚点两端当挡板。
	var 夹 := clampf(新x, minf(左界, 右界), maxf(左界, 右界))
	if not is_equal_approx(夹, 新x):
		_剩余帧 = 0.0    # 撞挡板 → 下一帧重挑（原版 `resetScript()`）
	新x = 夹
	怪.position.x = 新x
	怪.面向(_朝向)
	怪.播状态("move")
