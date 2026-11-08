extends Node2D
class_name CombatActor

signal died(actor: CombatActor)

var kind := ""
var entity_id := ""
var object_id := 0
var display_name := ""
var max_hp := 100
var hp := 100
var alive := true
var spawn_position := Vector2.ZERO
var home_left := 0.0
var home_right := 0.0
var move_speed := 52.0
var detection_range := 230.0
var attack_range := 62.0
var attack_cooldown := 1.4
var _attack_timer := 0.0
var _hit_timer := 0.0
## 暴击打死那一下的**击飞**：速度（像素/秒）与"正在飞"标志。见 `_起飞()` / `_飞一拍()`。
var _飞速度 := Vector2.ZERO
var _飞着 := false
## 物理常数（`com/mxw/common/gameCommon/Physics.as`）：`GRAVITY_ACC = 2000`、`FALL_SPEED = 670`。
## 原版算式里 `dt` 是**毫秒**（`_velocity.y + gravityAcc * param1 / 1000`），这里 delta 是秒，
## 所以两处都把 ×1000 约掉了：`vy += 2000 * 秒`、`位移 += 速度 * 秒`。
const 重力加速度 := 2000.0
const 下落限速 := 670.0
var _sprite: Node2D
var _hp_bar: Node2D
var _hp_bar_timer := 0.0
var _direction := 1.0
## 服务端移动帧里给的移动速度（像素/秒，**未量化**）。权威怪按它积分，但积分前要先换算成
## 原版客户端实际走出来的每秒位移 —— 见 `_原版每秒位移`。
var _服务器速度 := Vector2.ZERO
## 原版客户端是**固定 36 帧**（`MainLib` 主循环；服务端 `NYA_MAIN_FRAME_RATE` 同值）。
const 原版帧率 := 36
## 服务端移动帧里的脚点（第 13 段）。原版 `CommandController.tick:60-75` 对 NORMAL 段做的是
## `grounded = flag.grounded; currFootholdId = foothold`，之后由 `AbstractPhysicObject` 每帧
## 按脚点求 y —— 包里的 y 只用来摆起点，**斜地板/换层时的 y 是脚点给的**。
## 只积分 x 不贴脚点 ⇒ 斜段和换层后 y 不动（用户 2026-10-28 报「秽土转生小怪浮空走」）。
var _服务器脚点 := 0
## 权威怪脚下那张脚点表（`地表`）。`地图实体` 生成实体时挂进来。
var 地表: Node = null
## 当前朝向：-1 左 / +1 右。伤害数字的"未命中甩出方向"要用（`Character.as:1277` 是 ±160）。
var _朝向 := 1
var authoritative := false
## 离线怪的 AI（`MonsterAI`）。只在**非权威**怪身上建；在线时怪由服务端驱动，这里保持为 null。
var _ai: RefCounted = null
## 原版 `Monster.angroAtPlayer`。AI 用它记"已经拉住这个玩家"，也是脱战判据。
var 仇恨中 := false
## 精英属性（`jingying`），来自地图 life 段 / 怪物生成包。伤害与血量的精英系数都要读它。
var 精英属性: Array = []
## 原版 `Monster.aiState`（`MonsterParameter` 的四个状态常量），只用于排查/探针。
var ai状态 := 0

const 怪物AI脚本 := preload("res://脚本/角色/怪物AI.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const COMBAT_FORMULA := preload("res://脚本/角色/战斗结算.gd")
const 技能动画 := preload("res://脚本/角色/技能动画精灵.gd")
const 飞行物脚本 := preload("res://脚本/角色/技能飞行物.gd")
const 怪物血条脚本 := preload("res://脚本/角色/怪物血条.gd")
const 伤害数字脚本 := preload("res://脚本/角色/伤害数字.gd")
const 飘字队列脚本 := preload("res://脚本/角色/飘字队列.gd")	## 每个角色一条 400 毫秒的飘字队（原版节奏）
## `Monster.as:842` setTimeout(hideMobHpBar, 10000)
const 血条停留秒 := 10.0
## `CommonHpBar.BAR_WIDTH` / `BAR_HEIGHT`（CommonHpBar.as:11-13）
const 血条宽 := 54.0
const 血条高 := 11.0
## `Monster.as:201-208`：mobBmdHeight = Math.min(200, -ci.bmp.y)，而 ci.bmp.y = -origin.y
const 血条最高基准 := 200.0

func configure_actor(p_kind: String, p_id: String, p_name: String, p_sprite: Node2D, foothold_left: float, foothold_right: float) -> void:
	kind = p_kind
	entity_id = p_id
	display_name = p_name
	_sprite = p_sprite
	spawn_position = position
	home_left = foothold_left
	home_right = foothold_right
	if kind == "m":
		max_hp = 120
		hp = max_hp
		set_process(true)
	else:
		set_process(false)

## 离线怪的行为参数 —— 由 `地图实体._configure_actor` 从 `数据/怪物.json` 喂进来。
## ⚠️ 权威（服务端）怪**不建 AI**：它的每一步位移都由 `apply_server_movement` 给。
func configure_monster_ai(怪定义: Dictionary, 出生: Vector2, 左: float, 右: float) -> void:
	if kind != "m":
		return
	_ai = 怪物AI脚本.new()
	_ai.call("配置", 怪定义, 出生, 左, 右)
	home_left = 左
	home_right = 右
	spawn_position = 出生

## 下面三个是 `MonsterAI` 回调宿主的入口（原版那边是 `_monster.setVelocity` /
## `movementAction` / `AttackExecute`，我们是直接调宿主的方法）。
func 播状态(名: String) -> void:
	_play_state(名)

func 面向(x: float) -> void:
	_face_toward(x)

func 尝试攻击(玩家: Node2D) -> void:
	if _attack_timer <= 0.0:
		_attack(玩家)

## 这套美术有没有这个动作名（原版 `allActions`）。怪的技能 `stance` 是 attack1..attack6，
## 但具体某只怪不一定六个都有 —— 放之前先问一句，免得"自以为在出招"。
func 有动作(名: String) -> bool:
	return _sprite != null and _sprite.has_method("有动作") and bool(_sprite.call("有动作", 名))

## 播一次技能姿态（原版 `AttackExecute.ActionLogic()` 那条 `AddFrame_Attack`）。
## 返回这段动作的毫秒时长；**0 表示这套美术没有这个动作**，调用方不该记 CD。
func 播技能动作(名: String) -> int:
	if not 有动作(名):
		return 0
	_play_state_once(名)
	_attack_timer = attack_cooldown
	return _sprite.call("动作时长毫秒", 名)

## 怪放技能时的那套**表现**（原版 `MonsterAttackEffect.as:88-110`）：
## 技能自己的 `effect` 锚在**怪自己的脚点**、朝向按怪的朝向；`ball` 从怪身前 50px（y−30）
## 抛出飞向目标，越过目标 x 才算命中。
##
## 返回 true 表示**伤害由飞行物命中时结算** —— 调用方就别再按 `attackAfter` 结算了
## （原版 `MonsterAttackEffect` 里也是 `attackAfter < pastedTime` 与球的到达二选一）。
## ⚠️ 怪的技能 id 在动画元数据里是**七位补零**的形式（`0002000` 这种），调用方自己补零。
## ⚠️ 64 个怪技能里只有 17 个有 `effect`、12 个有 `ball`（其余只有 `info`，没有美术）——
##    没有就什么都不放，不假装有。
func 放技能表现(skill_id: String, 目标: Node2D) -> bool:
	var 特效: Node2D = null
	if 技能动画.有相位(skill_id, "effect"):
		特效 = 技能动画.new() as Node2D
		get_parent().add_child(特效)
		特效.global_position = global_position
		特效.call("set_direction", _朝向)
		if not bool(特效.call("configure", skill_id, "effect")):
			特效.queue_free()
			特效 = null
	if 目标 == null or not 技能动画.有相位(skill_id, "ball"):
		return false
	var 弹 := 飞行物脚本.new() as Node2D
	get_parent().add_child(弹)
	if not bool(弹.call("配置", skill_id, self, 目标, _朝向,
			技能动画.相位参数(skill_id, "ball", "ballAfter", 0), 特效)):
		弹.queue_free()
		return false
	弹.connect("命中", func(受击: Node2D) -> void: 结算对玩家伤害(受击))
	return true

## 技能到点后的伤害结算 —— 原版在 `MonsterAttackEffect.tick()` 里
## `attackAfter < pastedTime` 时调 `applyDamage()`。只做伤害，不重播动作
## （姿态在 `播技能动作` 里已经播过了）。
func 结算对玩家伤害(玩家: Node2D) -> void:
	_攻击伤害(玩家)

func _process(delta: float) -> void:
	if _hp_bar != null and _hp_bar.visible:
		_更新血条位置()
		_hp_bar_timer -= delta
		if _hp_bar_timer <= 0.0:
			hide_hp()
	_更新头顶挂件位置()
	if kind != "m":
		return
	## 飞着的怪**先**走物理，别管它权不权威 —— 在线那批怪全是权威怪（服务端只发 HP 包、
	## 死了之后不会再来移动帧），把这段放在权威分支后面就等于**在线永远飞不起来**。
	## 对应原版 `isHitAway` 把 `Monster.tick():1358-1363` 那个"走不走地面逻辑"的开关按死。
	if _飞着:
		_飞一拍(delta)
		return
	if authoritative:
		# 权威怪的位移由服务端的**速度**驱动，在两帧之间自己积分（见 `_权威走一拍`）。
		# ⚠ 积分步长必须按**原版 36 帧客户端实际走出来的每秒位移**算，不能拿线上的
		#   原始速度直接乘 delta：包里的速度是未量化的，服务端步进用的却是量化值。
		if alive and _服务器速度 != Vector2.ZERO:
			_权威走一拍(delta)
		return
	if not alive:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_hit_timer = maxf(0.0, _hit_timer - delta)
	if _hit_timer > 0.0:
		return
	# 2026-10-01：原来这里的几十行「半径内直线追 / 否则在 ±130 之间来回踱步」是自造的，
	# 换成了按原版 `roles/ai/` 还原的状态机（巡逻 / 追击 / 脱战回巢 / `firstAttack`），
	# 见 `脚本/角色/怪物AI.gd`。受击僵直与出招闸门仍在这里（原版 `synchroCheck()` 同义）。
	if _ai == null:
		return
	_ai.call("tick", self, delta)


## 死亡时**连同名字牌一起藏掉**。
## 原版怪死是 `MonsterHandler.beginPendingMonsterDeath` → `monster.die()` → 之后整个对象被移除，
## 名字牌是它的子节点、跟着一起没了。我们这边为复活留着 actor，只把 `_sprite.visible = false`，
## 名字牌是**兄弟节点**（`地图实体._add_nameplate` 挂在 actor 上）→ 于是"模型没了、名字还杵在原地"
## （用户 2026-09-27 报的第 5 条）。这里按"藏之前记一份可见性、复活时原样还原"处理，
## 免得把 `show_names` 关掉的玩家复活后名字被强行打开。
## 原版 `Monster.tick:1406-1408` 那句 `bianyiOrBossEffect.visible = !_loc2_ && !isDie` ⇒ **怪一死光环就没了**，
## 复活再亮（本工程复活会重发出生帧 ⇒ `地图实体._挂精英外观` 重建一次）。
const 附属件 := ["Nameplate", "NameplateTitle", "QuestMarker", "SelectionMarker", "精英外观"]

var _附属原可见 := {}

func _藏附属件() -> void:
	if not _附属原可见.is_empty():
		return
	_附属原可见.clear()
	for 名 in 附属件:
		var 节点 := get_node_or_null(名) as CanvasItem
		if 节点 != null:
			_附属原可见[名] = 节点.visible
			节点.visible = false

func _还原附属件() -> void:
	for 名 in _附属原可见:
		var 节点 := get_node_or_null(名) as CanvasItem
		if 节点 != null:
			节点.visible = bool(_附属原可见[名])
	_附属原可见.clear()

func take_damage(amount: int, knockback_direction := 0.0, 暴击 := false) -> void:
	if not alive or kind != "m":
		return
	if authoritative:
		return
	## ⭐ **未命中（`damage == 0`）只飘一条「未命中」**，不掉血、不播受击动作、不位移
	## （`AbstractSkillEffect.as:276-284` 那一支里除了 `player_addAttriChangeTip("",0,...)`
	## 和"怪是无敌的就拉一下仇恨"以外什么都没干）。以前这里照命中一样播 `hit1`、还推 12px。
	if amount <= 0:
		_spawn_damage_number(0, false)
		return
	hp = maxi(0, hp - amount)
	show_hp(float(hp) / maxf(1.0, float(max_hp)))
	_spawn_damage_number(amount, 暴击)
	# 这里原来放 `play_effect("hit")` —— 原版**怪物/角色受击没有音效**；`Sound_Pouf` 是
	# "假怪消失"(Monster.as:620) 和"召唤技能"(MonsterAttackEffect:108)，不是挨打声，不能拿来顶。
	if hp > 0:
		## ⭐ 受击僵直**不是每下都有**：`AbstractSkillEffect.as:217-229` —— 只有"这一包打完还活着"
		## 才掷 `MathAD.rnd(1,100)`（`MathAD.as:27-30` 是**闭区间** [1,100]），
		## **普通怪 `< 11` 才 `monster.hit()`、boss `< 40`**。以前这里是每下都播 `hit1`。
		if randi() % 100 + 1 < _僵直概率():
			_受击()
	elif 暴击 and not _是boss():
		## ⭐ **击飞 = 只有"这一发是暴击、并且把它打死了、而且它不是 boss"才发生**
		## （`AbstractSkillEffect.as:245-274`：`else if(!damage.alive && param1.bsk && !boss)`）。
		## 速度：`x = 打者在它左边 +3000 / 在右边 −3000`（用打者的 `x` 比，取不到才退回朝向），
		## `y = −2000`，同时 `currFoothold=null`、`grounded=false`、`isHitAway=true`。
		_起飞(3000.0 * (1.0 if knockback_direction > 0.0 else -1.0), -2000.0)
	if hp <= 0:
		_die()

## 受击僵直 = `hit1` 这个动作**整条播完**（`Monster.tickHitAndDie():1166-1179`：
## 播 `hit1` 且 `_toLoopThisAction=false`，到尾帧才 `setAction(stand)`）。以前写死 0.24 秒。
func _受击() -> void:
	_play_state_once("hit1")
	_hit_timer = _动作秒数("hit1")

func _是boss() -> bool:
	return int(GAME_DATA.monster(entity_id).get("boss", 0)) != 0

## 受击僵直的掷骰上限：普通怪 **11**、boss **40**
## （`AbstractSkillEffect.as:220-224`：`_loc3_ = MathAD.rnd(1,100)`，boss 那一支 `< 40`、
## 否则 `< 11`，掷中了才 `monster.hit()`）。单独成函数是为了让门能量这条概率、也让
## `take_damage` 里那两个分支读得懂 —— 以前这里是"每下都播 `hit1`"。
func _僵直概率() -> int:
	return 40 if _是boss() else 11

## 起飞 = 原版那一支的四件事一起发生（`AbstractSkillEffect.as:265-274`）：
## 脱离落脚点、离开地面、`isHitAway=true`、给一个 `(±3000, −2000)` 的速度。
## `isHitAway` 在原版的作用是**强制这一帧走重力+碰撞+位移**（`Monster.tick():1358-1363`
## 把 `_loc3_` 按死成 false），我们这边对应"飞的时候不跑 AI、只跑物理"。
func _起飞(水平速度: float, 竖直速度: float) -> void:
	_飞速度 = Vector2(水平速度, 竖直速度)
	_飞着 = true

func _飞一拍(delta: float) -> void:
	## `applyGravity():99-107`：`vy += 2000 * dt/1000`，**紧接着**就在同一步里
	## `vy = min(vy, FALL_SPEED=670)` —— 上限在这一帧的位移之前就已经吃掉了。
	_飞速度.y = minf(_飞速度.y + 重力加速度 * delta, 下落限速)
	position += _飞速度 * delta

func _attack(player: Node2D) -> void:
	_attack_timer = attack_cooldown
	_play_state_once("attack1")
	_攻击伤害(player)

## 一次普通攻击/技能落在玩家身上的伤害。**离线**按夹具服务端
## `_apply_server_monster_damage()` 的口径算（`战斗结算.怪打玩家`，出处与缺口见那边）。
## 在线走不到这里 —— 权威怪不建 AI、`_attack` 不会被调，伤害由服务端 `194` 包给。
## （原来这里是写死的 `attack_damage = 8`，自造的。）
func _攻击伤害(player: Node2D) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null or not session.has_method("damage_player"):
		return
	var 结果 := COMBAT_FORMULA.怪打玩家(session.get("player_stats"), GAME_DATA.monster(entity_id), 精英属性)
	session.call("damage_player", int(结果["伤害"]))
	## 玩家身上那条数字 —— 原版 `DamageHandler.as:92-106` 三档：
	##   挨打且暴击 → 前缀「**致命**」（`FIGHT_ZHIMING`，`en_US$core_properties.as:81`；
	##     注意**打别人**时同一档写的是「暴击」`:100`，只有打在**自己**身上才写「致命」）、
	##   挨普通打 → 空前缀，两档颜色都是 16711680（红，`Character.as:573-575`）；
	##   **闪开了 → 也要飘字**：`player_addAttriChangeTip("", 0, ...)` ⇒ 「我闪」绿字
	##   （`Character.as:1244-1256` + `:584-586`）。以前这里 `if not 命中: return`，
	##   闪避时**屏幕上什么都不出**，而且暴击位整个丢掉。
	var 根 := get_parent()
	if 根 == null or not 根.has_method("_播放玩家伤害数字"):
		return
	var 精灵 := player.get("player_sprite") as Node2D
	var 锚点 := 0.0
	if 精灵 != null and 精灵.has_method("当前贴图高度"):
		锚点 = float(精灵.call("当前贴图高度"))
	根.call("_播放玩家伤害数字", 锚点, int(结果["伤害"]),
			"致命" if bool(结果["暴击"]) else "")

func _face_toward(target_x: float) -> void:
	_set_facing(signf(target_x - global_position.x))

## 朝向交给 `原始动画精灵.set_direction` —— 怪物/NPC 的美术默认朝左、角色朝右，
## 两套口径在那边一处收口（`Animation.as:55-66` vs `CharacterSprite.as:1718-1732`）。
func _set_facing(direction: float) -> void:
	if _sprite == null or direction == 0.0:
		return
	_朝向 = 1 if direction > 0.0 else -1
	if _sprite.has_method("set_direction"):
		_sprite.call("set_direction", _朝向)
		return
	_sprite.scale.x = absf(_sprite.scale.x) * (-1.0 if direction < 0.0 else 1.0)

func _play_state(state: String) -> void:
	if _sprite != null and _sprite.has_method("play_state"):
		_sprite.call("play_state", state)

## 播一次就停住的动作（原版 attack1 / hit1 / die1 都是 `_toLoopThisAction = false`）。
func _play_state_once(state: String) -> void:
	if _sprite != null and _sprite.has_method("play_once"):
		_sprite.call("play_once", state)
	elif _sprite != null and _sprite.has_method("play_state"):
		_sprite.call("play_state", state)

func _动作秒数(state: String) -> float:
	if _sprite != null and _sprite.has_method("动作时长毫秒"):
		return float(_sprite.call("动作时长毫秒", state)) / 1000.0
	return 0.2

## 死亡即**整只移除** —— 原版客户端看到的就是这个：`MonsterHandler.beginPendingMonsterDeath`
## → `monster.die()` → 之后对象从场景里消失；**"什么时候再刷一只"是服务端的活**
## （`fake_flash_server.py:11074-11076` `NORMAL 10s / ELITE 20s / BOSS 60s`），
## 客户端只会收到新的一条生成包。
## 原来这里自己留 5 秒再 `_respawn()` 把同一只放出来 —— 那是**离线自造的**，
## 而且正是"怪死了名字牌还杵在原地"的根源（对象没走，只是藏了 sprite）。
## 离线那条改由 `地图实体` 按服务端那套延时**重新生成一只新的**（见 `_排下一只`）。
func _die() -> void:
	alive = false
	_play_state_once("die1")
	hide_hp()
	_藏附属件()
	# 原版是等 `die1` 播完（`Monster.tickHitAndDie():1204`）再收，不是写死 0.8 秒
	await get_tree().create_timer(maxf(0.1, _动作秒数("die1"))).timeout
	if not alive:
		died.emit(self)      # 死亡动画播完才真正"消失"，与 `Monster.tickHitAndDie():1204` 一致
		queue_free()

## 原版血条**不是常显**：只有收到血量包才建、才显示（`MonsterHandler.showMobHp` → `Monster.showHp`），
## 满血站着不显示；显示后 10 秒自动隐藏（`Monster.as:818-843`）。
func show_hp(比例: float) -> void:
	if kind != "m":
		return
	_确保血条()
	_hp_bar.set("_比例", clampf(比例, 0.0, 1.0))
	_hp_bar.queue_redraw()
	_hp_bar.visible = true
	_hp_bar_timer = 血条停留秒
	_更新血条位置()

func hide_hp() -> void:
	_hp_bar_timer = 0.0
	if _hp_bar != null:
		_hp_bar.visible = false

func _确保血条() -> void:
	if _hp_bar != null:
		return
	_hp_bar = 怪物血条脚本.new()
	_hp_bar.name = "HpBar"
	_hp_bar.visible = false
	add_child(_hp_bar)

## `Monster.as:838-840`：
##   _mobHpBar.x = -CommonHpBar.BAR_WIDTH / 2
##   _mobHpBar.y = -mobBmdHeight - CommonHpBar.BAR_HEIGHT - 2
## 而 `mobBmdHeight = Math.min(200, -ci.bmp.y) = Math.min(200, 当帧 origin.y)` ——
## 所以血条**跟着当帧注册点走**，攻击前冲那一帧它会跟着抬/落。
func _更新血条位置() -> void:
	if _hp_bar == null:
		return
	var 原点y := 0.0
	if _sprite != null and _sprite.has_method("当前原点"):
		原点y = float((_sprite.call("当前原点") as Vector2).y)
	_hp_bar.position = Vector2(-血条宽 * 0.5, -minf(血条最高基准, 原点y) - 血条高 - 2.0)

## 原版伤害数字（`Monster.as:879-941`）：锚点是 `mobBmdHeight = min(200, 当帧 origin.y)`。
## 颜色按属性类型：普通 `MOB_HP_COMMON` 白、暴击 `MOB_HP_BSK` 红（`16711680`）。
##
## ⚠️ **在线那条暴击还接不上**：文本桥 `243:<object_id>:<damage>` 帧里没有 bsk 位
##    （原版 `MobDamageItem(damage, bsk)` 是两位），等服务端补。**离线**这条现在能给了 ——
##    伤害由 `脚本/角色/战斗结算.gd` 本地算出，暴击位是现成的。见 §3.68。
func _spawn_damage_number(amount: int, 暴击 := false) -> void:
	## ⭐ 不再"来一条立刻砸一条"：原版每个角色**自己一条飘字队列**，每 400 毫秒只放一条
	## （`Monster.as:435-447` 入列 + `while(length > 50) shift()` 溢出丢**最旧**的；
	##   `Monster.as:883+` / `Character.as:2591-2598` 放完把 `timeLeftAttriChangeTip` 置回 400）。
	## 连打时以前满屏叠成一坨，现在错开成一串 —— 与原版同形。
	## 锚点也**等到真放的那一刻再算**（原版 `Monster.as:921-923` 就是放的时候才读 `mobBmdHeight`，
	## 这 0.4 秒里怪换了动画帧，提前算就会错开一截）。
	var 动作 := func() -> void:
		var 数字 := 伤害数字脚本.new() as Node2D
		add_child(数字)
		## ⚠ 数值传**负数**：`伤害数字.播放()` 那个正负号是照 `数值 > 0` 现算的（与原版同一套），
		## 原来这里传 `absi()` ⇒ 怪物掉血飘出来是「+123」。
		## ⚠ 暴击那一发原版**带字**：`AbstractSkillEffect.as:199-200`
		##   `player_addAttriChangeTip(CNCore.FIGHT_BSK, damage, false, MOB_HP_BSK)`，
		##   `FIGHT_BSK` = 语言包「暴击」（`en_US$core_properties.as:39`）、
		##   颜色 `Monster.as:419-420` = 16711680 ⇒ 屏上是「暴击  -123」红字，不是光一个红数字。
		var 颜色 := Color(1.0, 0.0, 0.0) if 暴击 else Color.WHITE
		数字.call("播放", _血条锚点(), -absi(amount), "暴击" if 暴击 else "", 颜色, _朝向 < 0)
	飘字队列脚本.排队于(self, 动作)

## 当前帧贴图的高度（`ci.bmd.height`）。任务标记挂它，见 `_更新任务标记位置()`。
func 贴图高() -> float:
	if _sprite != null and _sprite.has_method("当前贴图高度"):
		return float(_sprite.call("当前贴图高度"))
	return 0.0

## 任务标记的 y —— `NPCSprite.as:385`（`set cy()` 里）：
##     `this._npcQuestIcon.y = -this.ci.bmd.height - 5;`
## 也就是**贴图顶再往上 5px**，x = 0（`:260`）。它在 `set cy()` 里算，而 `cy` 每帧都设 ⇒ **它跟帧走**
## （和血条同一档，不是世界名字那种常量）。
## ⚠ 我们原来写死 `-122`。那个数大约等于本图 NPC 美术高 117 时的值 —— 正是
##    "硬编码量出来的常数"：换一张图、换一套 NPC 美术就错位。
## 标记现在是 `EffectPlayer`（原版那张 TickMovie 的真图），**注册点由 `数据/特效.json` 的 `原点`
## 定**（贴图位置 = −原点），所以这里只钉挂载点，不再叠任何自造偏移。
## 两枚挂件都归这个函数管（原来只管任务标记，箭头把 y 写死在 .tscn 的 -108 里）。
func _更新头顶挂件位置() -> void:
	var 标记 := get_node_or_null("QuestMarker") as Node2D
	if 标记 != null:
		标记.position = Vector2(0.0, -贴图高() - 5.0)
	## 选中箭头：`Monster.as:810-812` / `NPC.as:45-47` 都是 `x = 0; y = -贴图高 - 8`
	var 箭头 := get_node_or_null("SelectionMarker") as Node2D
	if 箭头 != null:
		箭头.position = Vector2(0.0, -贴图高() - 8.0)

## `mobBmdHeight`：`Monster.as:201-208` `Math.min(200, -ci.bmp.y)`，而 `ci.bmp.y = -origin.y`。
func _血条锚点() -> float:
	var 原点y := 0.0
	if _sprite != null and _sprite.has_method("当前原点"):
		原点y = float((_sprite.call("当前原点") as Vector2).y)
	return minf(血条最高基准, 原点y)

func configure_authoritative(server_object_id: int, server_max_hp: int = 100, 精英: Array = []) -> void:
	authoritative = true
	# 权威怪的每一步位移都由服务端给（`apply_server_movement`）⇒ 把离线 AI 撤掉，
	# 否则两套会打架（AI 按本地速度积分、服务端又把它拽回去）。
	_ai = null
	仇恨中 = false
	object_id = server_object_id
	max_hp = 最大血量(server_max_hp, 精英)
	hp = max_hp

## 原版 `Monster.clientCombatMaxHp:846-863`：基础最大血量再乘一遍精英属性 ——
## `attrType == 1` 乘 `value`（下限 1）、`attrType == 16` 乘 3，最后取整。
## 精英属性来自怪物生成包（`jingying`），等于原版的 `jingyings`。
## 不做这一步，精英/BOSS 的分母就偏小：血条比例、目标框里的"当前/上限"全跟着错。
static func 最大血量(基础: int, 精英: Array) -> int:
	var 值 := float(maxi(1, 基础))
	for 项 in 精英:
		if not 项 is Dictionary:
			continue
		var 类型 := int((项 as Dictionary).get("attr_type", 0))
		if 类型 == 1:
			值 *= maxf(1.0, float((项 as Dictionary).get("value", 1)))
		elif 类型 == 16:
			值 *= 3.0
	return maxi(1, roundi(值))

## 在线受击：伤害数字由服务端出手/DoT 帧驱动。`暴击` 位来自 **184** 的 `damage*bsk`
## （见 `后端连接._handle_mob_attack_info_text`；原版 `243 = onDamageMonster(int,int)` 只有两 int、
## 恒白字 —— 红字真身在 184，§3.87）。缺位（别的构造）默认非暴击、显白字。
## `播受击` = 这条伤害要不要带 `hit1` 僵直：**184（出手命中）要**、**243（中毒/相位每跳一点）不要**。
## 真值：原版 `MonsterHandler.addMonsterDamage`（243 的消费端）只画数字，受击动画走
## `Monster.tickHitAndDie` 里 `isHit` 那条（由出手特效置位）—— 中毒的怪不该每秒抽一下。
## 在线那一档的击飞入口：服务端 184 出手帧说"这包打完它不活着了"且那一发是暴击，
## 就按原版同一套把它抛出去（`AbstractSkillEffect.as:245-274`，与离线共用 `_起飞`）。
## boss 不飞这条判断在 `_起飞` 的调用方各判一次 —— 这里也判，因为在线不走 `take_damage`。
func 服务端击飞(水平速度: float) -> void:
	if _是boss():
		return
	_起飞(水平速度, -2000.0)


func apply_server_damage(amount: int, 暴击 := false, 播受击 := true) -> void:
	if not alive or kind != "m":
		return
	if 播受击:
		_play_state_once("hit1")
		_hit_timer = _动作秒数("hit1")
	_spawn_damage_number(maxi(0, amount), 暴击)

func apply_server_hp_percent(hp_percent: int) -> void:
	var 百分比 := clampi(hp_percent, 0, 100)
	hp = roundi(float(max_hp) * 百分比 / 100.0)
	show_hp(float(百分比) / 100.0)
	# ⭐ **血包到 0 就当场死**，不等 KILL 包。原版 `MonsterHandler.showMobHp():366-382`：
	#     `_loc3_.showHp(param2); if(param2 <= 0) { this.beginPendingMonsterDeath(param1); }`
	#     —— beginPendingMonsterDeath 里就 `monster.die()`。
	# 我们原来只在收到 KILL(239) 时才死，于是"血已经 0 了、它还在攻击/移动"
	# （用户 2026-09-27 报）。`_服务端死亡()` 自己带"只死一次"的守卫，KILL 包随后到达是空操作。
	if 百分比 <= 0:
		_服务端死亡()

## 服务端移动帧给的是**速度**（`[7]vx [8]vy`）与**这一段的起点**，
## 原版 `onMoveMonster` → `MonsterHandler.addMonsterMovement()` 把它当"移动段"播，
## 两个包之间由客户端按速度积分 —— 服务端只在**移动段变化**时才发下一帧。
##
## ⚠️ 我们原来把包里的第 12 段当时长（那其实是常量 0）→ `max(1,0)` = 1 毫秒 →
## 补间 0.001 秒 → **怪瞬移**（用户 2026-09-27 报的第 1 条）。
## 现在改成：对齐到这一段起点 + 按速度逐帧积分（见 `_权威走一拍`）。
func apply_server_movement(state: Dictionary) -> void:
	if not alive:
		return
	_服务器速度 = Vector2(float(state.get("vx", 0)), float(state.get("vy", 0)))
	_服务器脚点 = int(state.get("foothold", 0))
	if state.has("start_x"):
		position = Vector2(float(state.get("start_x")), float(state.get("start_y")))
	if _服务器速度.x != 0.0:
		_set_facing(signf(_服务器速度.x))
	_贴脚点()
	if _服务器速度 == Vector2.ZERO:
		_play_state("stand")
	else:
		_play_state("move")

## 原版每秒实际位移：原版客户端是**固定 36 帧**、每帧 `x += v * dt / 1000` 后
## `floor`/`ceil` 取整（`AbstractPhysicObject.applyVelocity:513-543`）。所以线上 175
## 像素/秒的怪，原版一秒钟其实只走 144 像素。服务端**按这个量化值步进**
## （`_monster_client_walk_velocity` / `_consume_monster_move_step`），移动帧里带的却是
## 未量化的速度；我们若照 175 连续积分，就比服务端快 21%：小怪越走越靠前、冲出脚点段端
## （浮空走），客户端按体型矩形选敌也框不到它（不受伤害），下一帧绝对位置一到又像"消失"
## —— 用户 2026-10-31 报的那三条。这里把线上速度换算成原版每秒实际位移再积分。
static func _原版每秒位移(速度: float) -> float:
	var 幅 := absf(速度)
	if 幅 <= 0.0:
		return 0.0
	var 短帧毫秒 := floori(1_000.0 / float(原版帧率))	# 27
	var 长帧数 := 1_000 % 原版帧率						# 28
	var 短帧数 := 原版帧率 - 长帧数						# 8
	var 每秒 := float(短帧数 * floori(幅 * float(短帧毫秒) / 1_000.0)
			+ 长帧数 * floori(幅 * float(短帧毫秒 + 1) / 1_000.0))
	return signf(速度) * 每秒

## 权威怪两个移动帧之间的那一拍：x 按 `_原版每秒位移` 积分；贴地走到脚点段端就停住。
## 原版 `AbstractPhysicObject.checkFoothold:394-455`：走到段端要么并进相邻脚点、要么被
## `leftBlock/rightBlock` 挡住，**绝不会悬空横着走出去**；换层/转向由服务端下一帧交代。
## 只夹"从段内走向段外"那一侧 —— 服务端本来就把怪摆在段外时（世界 boss 的 authored
## 脚点号等）不该硬拽回来。
func _权威走一拍(delta: float) -> void:
	var 步x := _原版每秒位移(_服务器速度.x) * delta
	if 步x != 0.0:
		var 目标x := position.x + 步x
		var 段 := _服务器脚点段()
		if not 段.is_empty():
			var 左 := minf(float(段.x1), float(段.x2))
			var 右 := maxf(float(段.x1), float(段.x2))
			if position.x >= 左 and position.x <= 右:
				var 夹 := clampf(目标x, 左, 右)
				if 夹 != 目标x:
					_服务器速度.x = 0.0
					目标x = 夹
		position.x = 目标x
	position.y += _服务器速度.y * delta
	_贴脚点()

func _服务器脚点段() -> Dictionary:
	if _服务器脚点 == 0 or 地表 == null or not is_instance_valid(地表):
		return {}
	return (地表.get("id_map") as Dictionary).get(str(_服务器脚点), {})

## 把 y 贴回服务端指定的脚点（见 `_服务器脚点` 的注释）。x 越出段端时夹到端点上，
## 只差一帧的越界不该退回 INF 让 y 卡在上一层的旧值。
func _贴脚点() -> void:
	var 段 := _服务器脚点段()
	if 段.is_empty():
		return
	var 左 := minf(float(段.x1), float(段.x2))
	var 右 := maxf(float(段.x1), float(段.x2))
	position.y = float(地表.call("ground_y_on", clampf(position.x, 左, 右), 段))

func apply_server_attack(direction: int) -> void:
	if not alive:
		return
	_set_facing(float(direction))
	_play_state("attack1")

func apply_server_kill() -> void:
	_服务端死亡()

## 服务端侧的死亡（血包到 0，或 KILL 包）。**只走一次** —— 两条来路都会调它，
## 谁先到谁生效，后到的被 `alive` 挡住（原版也是这个形状：`beginPendingMonsterDeath`
## 里判 `if(!_loc2_.isDie)`）。
func _服务端死亡() -> void:
	if not alive:
		return
	alive = false
	hp = 0
	_服务器速度 = Vector2.ZERO
	hide_hp()
	_藏附属件()
	_play_state_once("die1")
	await get_tree().create_timer(maxf(0.1, _动作秒数("die1"))).timeout
	# 死亡动画播完就把自己摘掉 —— 对齐离线 `_die()`（它也 queue_free）。
	# ⚠️ 但**不 emit `died`**：那是离线自算那套（爆金币/任务计数）的信号，
	#   在线的掉落/任务由服务端包驱动，从这儿放出去会双算。
	# ⚠️ 服务端**不会**为怪发 `REMOVE_MAP_ENTITY(163)`（只有 KILL 239），所以没有别的
	#   人来 free 它 —— 不在这儿 free，尸体就永久留在 `_entities` 里（2026-10-03 探针实测：
	#   在线连杀多只，实体数 31→31 一动不动）。
	if not alive and _sprite != null:
		_sprite.visible = false
	if not alive:
		queue_free()
