extends Node2D

## 技能的 **ball 相位**（飞行物）—— 原版 `AbstractThrowSkillEffect` / `MonsterAttackEffect`。
##
## 真值（`com/mxw/skills/effects/AbstractThrowSkillEffect.as`）：
##   · 出手点 `ballFrom = (施法者.x + 50 × 朝向, 施法者.y − 30)`（`:23-24`）；
##   · 速度 `speed:int = 500`（`AbstractSkillEffect.as:73`；`SkillDataTool.getBallSpeed()` 全树
##     **只有声明、没有任何调用点**去覆盖它 ⇒ 恒 500）；
##   · 出场时机 `canBallAppear()`：`ballAfter == 0` 时**等施法特效播完**，否则 `pastTime > ballAfter`
##     （`:48-55`）；
##   · 出场后 alpha 从 0.1 起、每帧 +0.2、加 5 次（`:66-70`）；
##   · 每帧水平走 `speed × Δt`，纵向**追着目标的 y 收敛** `ball.y += (目标y − ball.y) / 10`（`:71-87`）——
##     所以它是一条略微上/下弯的弧线，不是直线；
##   · 越过目标的 x（或目标被打飞）就算命中（`:72-79`）；
##   · 飞行中的动画是**循环**的（`createBall()` 里 `new FrameQueueAnimation(true)`，`AbstractSkillEffect.as:616-622`）。

signal 命中(目标: Node2D)

## `AbstractThrowSkillEffect.as:23-24`
const 出手前移 := 50.0
const 出手抬高 := 30.0
## `AbstractSkillEffect.as:73`
const 速度 := 500.0
## 出场渐显（`:66-70`）
const 渐显起手 := 0.1
const 渐显步长 := 0.2
const 渐显次数 := 5

const 技能动画 := preload("res://脚本/角色/技能动画精灵.gd")

var 目标: Node2D = null
var 朝向 := 1

var _动画: Node2D = null
var _等待毫秒 := 0.0
var _等待施法特效: Node2D = null
var _已现形 := false
var _渐显 := 0
var _上帧y := 0.0

## `施法者` 用来算出手点；`ball_after毫秒` 取自动画元数据的 `ball` 相位（0 ⇒ 等施法特效播完）。
func 配置(skill_id: String, 施法者: Node2D, 目标节点: Node2D, 朝: int,
		ball_after毫秒: int, 施法特效: Node2D = null) -> bool:
	var 动画 := 技能动画.new() as Node2D
	add_child(动画)
	if not bool(动画.call("configure", skill_id, "ball")):
		动画.queue_free()
		return false
	动画.set("循环", true)
	动画.call("set_direction", 朝)
	动画.set("visible", false)
	_动画 = 动画
	目标 = 目标节点
	朝向 = 1 if 朝 >= 0 else -1
	_等待毫秒 = float(maxi(0, ball_after毫秒))
	_原球延迟 = _等待毫秒		# `该现形()` 要按**原始** ballAfter 分两支，`_等待毫秒` 会被扣完
	_等待施法特效 = 施法特效
	global_position = Vector2(施法者.global_position.x + 出手前移 * float(朝向),
			施法者.global_position.y - 出手抬高)
	_上帧y = global_position.y
	return true

## 该不该现形 —— 原版 `AbstractThrowSkillEffect.canBallAppear():48-55` 是**二选一**：
## `ballAfter == 0` ⇒ 等施法特效播完（`effect.actionEnd()`）；
## `ballAfter != 0` ⇒ **只看 `pastTime > ballAfter`，不等特效播完**。
## 原来这里两个条件串在一起等（等满 250ms 之后还要等特效播完），实测同一发要 105 帧才现形，
## 玩家看到的就是"人早就收招了，球才慢慢悠悠出来"。
var _原球延迟 := 0.0

func 该现形() -> bool:
	if _等待毫秒 > 0.0:
		return false
	if _原球延迟 > 0.0:
		return true
	if _等待施法特效 != null and is_instance_valid(_等待施法特效):
		if _等待施法特效.has_method("动作已播完"):
			return bool(_等待施法特效.call("动作已播完"))
		return false
	return true

func _process(delta: float) -> void:
	if 目标 == null or not is_instance_valid(目标):
		queue_free()
		return
	if not _已现形:
		if _等待毫秒 > 0.0:
			_等待毫秒 -= delta * 1000.0
			return
		if not 该现形():
			return
		_已现形 = true
		_动画.set("visible", true)
		modulate.a = 渐显起手
	# 渐显：每帧 +0.2，加 5 次（`AbstractThrowSkillEffect.as:66-70`）
	if _渐显 < 渐显次数:
		modulate.a = minf(1.0, modulate.a + 渐显步长)
		_渐显 += 1
	var 目标点 := Vector2(目标.global_position.x, 目标.global_position.y - 出手抬高)
	var 步 := 速度 * delta * float(朝向)
	global_position.x += 步
	# 纵向追着目标收敛：原版是**每帧** `y += Δy / 10`（60fps），换算成按秒就是 ×6
	if absf(delta) > 0.0:
		global_position.y += (目标点.y - global_position.y) * minf(1.0, delta * 60.0 / 10.0)
	_上帧y = global_position.y
	## ⭐ **第三个条件"目标被打飞 ⇒ 也算命中"不能省**（原版
	## `AbstractThrowSkillEffect.as:72-79`：`ball.x >= target.x || ... || target.isHitAway`
	## 命中就 `applyDamages()` + `removeChild(ball)`）。上一版只写了前两个"越过目标 x"，
	## 于是暴击打死一只怪之后球还在追着一路飞走的尸体 ⇒ 用户 10-15 在旁观端看到的
	## **"怪被击飞了、技能特效也跟着一起飞"**。
	## 为什么只有旁观端看得见：本地那一侧击飞发生在**命中之后**（命中→结算→服务端回包→击飞），
	## 而旁观端是收到 184 当场就把怪抛出去，那颗球还在路上。
	## `目标.get("_飞着") == true`：没有这个字段的节点（比如远程玩家）返回 null ⇒ 比较为假，不误伤。
	## ⚠ 别写成 `bool(目标.get(...))` —— 取不到字段时那是 `bool(null)`，运行时报
	## `Nonexistent 'bool' constructor`（10-15 实测：整条 `_process` 被打断，球反而**永远不命中**）。
	if 该命中了(步, global_position.x, 目标点.x, 目标.get("_飞着") == true):
		命中.emit(目标)
		queue_free()


## 命中判定 = 原版那三个条件（见上面的注释）。**抽成纯函数**是为了让门能直接喂参数判，
## 不必造一只"正在被击飞的怪"（那种夹具要跑完整的服务端回包链，反而更不可信）。
static func 该命中了(步: float, 球x: float, 目标x: float, 目标正被击飞: bool) -> bool:
	if 步 > 0.0 and 球x >= 目标x:
		return true
	if 步 < 0.0 and 球x <= 目标x:
		return true
	return 目标正被击飞
