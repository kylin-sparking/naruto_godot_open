## 技能的 **ball 相位**（飞行物）。真值全在 `AbstractThrowSkillEffect.as` / `AbstractSkillEffect.as`：
##   · 出手点 `(施法者.x + 50×朝向, 施法者.y − 30)`；
##   · 速度恒 **500**（`AbstractSkillEffect.as:73` 的 `speed:int = 500`，
##     而 `SkillDataTool.getBallSpeed()` 全树只有声明、没有调用点去覆盖它）；
##   · 出场时机 `ballAfter == 0 ⇒ 等施法特效播完`，否则等够 `ballAfter` 毫秒；
##   · 纵向追着目标收敛（每帧 `Δy/10`），是弧线不是直线；
##   · 越过目标 x 即命中。
extends SceneTree

const 飞行物 := preload("res://脚本/角色/技能飞行物.gd")
const 技能动画 := preload("res://脚本/角色/技能动画精灵.gd")
const 战斗角色 := preload("res://脚本/角色/战斗角色.gd")

var _failures: Array[String] = []
var _checked := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _近(实际: float, 期望: float, 容差 := 0.5) -> bool:
	return absf(实际 - 期望) <= 容差

## 找一个**真有 ball 相位**的技能 id（默认图那批 156 个里 18 个有）。
func _找一个有球的() -> String:
	for id in ["1001002", "1001003", "1001004", "1001005", "1001006", "1001007", "1001008"]:
		if 技能动画.有相位(id, "ball"):
			return id
	return ""

func _造点(位置: Vector2) -> Node2D:
	var n := Node2D.new()
	root.add_child(n)
	n.global_position = 位置
	return n

func _run() -> void:
	var 球技能 := _找一个有球的()
	if 球技能 == "":
		_check(false, "找不到带 ball 相位的技能，本条测不到东西")
		_finish()
		return
	_check(true, "")

	# ① 相位查询
	_check(技能动画.有相位(球技能, "ball"), "%s 应有 ball 相位" % 球技能)
	_check(not 技能动画.有相位("0008000", "ball"), "没球的技能不该被认成有 ball 相位")

	# ② 出手点：施法者 + (50×朝向, −30)
	var 施法者 := _造点(Vector2(100.0, 200.0))
	var 目标 := _造点(Vector2(600.0, 260.0))
	var 弹 := 飞行物.new() as Node2D
	root.add_child(弹)
	弹.set_process(false)
	_check(bool(弹.call("配置", 球技能, 施法者, 目标, 1, 0, null)), "配置带 ball 的技能应成功")
	_check(_近(弹.global_position.x, 150.0), "出手点 x 应是 施法者.x + 50（实际 %.1f）" % 弹.global_position.x)
	_check(_近(弹.global_position.y, 170.0), "出手点 y 应是 施法者.y − 30（实际 %.1f）" % 弹.global_position.y)

	# ③ 没有 ball 相位的技能配不起来（不该悄悄建一个空飞行物）
	var 空弹 := 飞行物.new() as Node2D
	root.add_child(空弹)
	空弹.set_process(false)
	_check(not bool(空弹.call("配置", "0008000", 施法者, 目标, 1, 0, null)),
			"没有 ball 相位的技能应配置失败")

	# ④ 速度：喂 1 秒，水平该走 ~500
	var 起x := 弹.global_position.x
	# ⚠️ GDScript 的 lambda **按值捕获**局部变量（改的是副本）—— 所以拿数组当可变盒子。
	var 命中数 := [0]
	弹.connect("命中", func(_受击): 命中数[0] += 1)
	for _i in 60:
		弹.call("_process", 1.0 / 60.0)
		# 到点就结束，别继续喂（它已经 queue_free 了）
		if 命中数[0] > 0:
			break
	_check(命中数[0] == 1, "越过目标 x 时应恰好命中一次（实际 %d）" % 命中数[0])
	var 走了 := 弹.global_position.x - 起x
	_check(走了 > 400.0 and 走了 <= 500.0,
			"1 秒内水平应走 400~500（速度 500，越过目标即停；实际 %.0f）" % 走了)
	# ⑤ 纵向是**收敛**到 目标y − 30，不是一步到位
	_check(absf(弹.global_position.y - 170.0) < absf(260.0 - 30.0 - 170.0),
			"纵向应朝 目标y−30 收敛（实际 y=%.1f）" % 弹.global_position.y)

	# ⑥ 朝左：出手点在左边
	var 左弹 := 飞行物.new() as Node2D
	root.add_child(左弹)
	左弹.set_process(false)
	左弹.call("配置", 球技能, 施法者, _造点(Vector2(-400.0, 200.0)), -1, 0, null)
	_check(_近(左弹.global_position.x, 50.0), "朝左时出手点应是 施法者.x − 50（实际 %.1f）" % 左弹.global_position.x)

	# ⑦ `ballAfter` 还没到就不该现形
	var 迟弹 := 飞行物.new() as Node2D
	root.add_child(迟弹)
	迟弹.set_process(false)
	迟弹.call("配置", 球技能, 施法者, 目标, 1, 500, null)
	迟弹.call("_process", 1.0 / 60.0)
	_check(not bool(迟弹.get("_已现形")), "ballAfter 没到就不该现形")
	_check(迟弹.global_position.x == 150.0, "没现形时不该往前飞")

	# ⑧ 怪侧同一套：`CombatActor.放技能表现()`（原版 `MonsterAttackEffect`）
	#    64 个怪技能里只有 12 个有 ball（七位补零查），挑两个真的验一正一反。
	var 怪 := 战斗角色.new() as CombatActor
	怪.kind = "m"
	root.add_child(怪)
	怪.global_position = Vector2(0.0, 100.0)
	var 前数 := root.get_child_count()
	_check(bool(怪.call("放技能表现", "0002000", 目标)),
			"有 ball 的怪技能应抛出飞行物并返回 true（这条决定伤害等不等命中）")
	_check(root.get_child_count() > 前数, "怪放技能时应真的往场景里加了节点（特效/飞行物）")
	_check(not bool(怪.call("放技能表现", "0008000", 目标)),
			"没有 ball 的怪技能不该说在等命中（那样伤害就永远不结算了）")

	# ⑨ **目标被击飞 ⇒ 球当场算命中并消失**（原版 `AbstractThrowSkillEffect.as:72-79` 的
	#    第三个条件 `|| target.isHitAway`；用户 10-15 在旁观端看到"怪被击飞了、技能特效也
	#    跟着一起飞"，就是因为上一版只写了前两个"越过目标 x"）。
	_check(not 飞行物.该命中了(1.0, 100.0, 120.0, false), "没越过目标、也没被打飞 ⇒ 不该算命中")
	_check(飞行物.该命中了(1.0, 130.0, 120.0, false), "向右越过目标 x ⇒ 算命中")
	_check(飞行物.该命中了(-1.0, 110.0, 120.0, false), "向左越过目标 x ⇒ 算命中")
	_check(飞行物.该命中了(1.0, 100.0, 900.0, true),
			"目标正被击飞 ⇒ **还没越过也必须算命中**（少了这条球就追着飞走的怪一路跑）")
	_check(not 飞行物.该命中了(0.0, 100.0, 120.0, false), "步长为 0（还没出手）不该算命中")
	## 再用真节点验一次"接得上"：靶子放到**绝对追不上**的位置、只把 `_飞着` 置真 ⇒
	## 喂一帧球就该消失。位置远是故意的：这样"消失"只能是第三条条件起的效，不是越过了目标。
	var 飞靶 := 战斗角色.new() as CombatActor
	飞靶.kind = "m"
	root.add_child(飞靶)
	飞靶.global_position = Vector2(9000.0, 100.0)
	飞靶.set("_飞着", true)
	var 追 := 飞行物.new() as Node2D
	root.add_child(追)
	_check(bool(追.call("配置", "0002000", 怪, 飞靶, 1, 0, null)), "对被击飞的靶也抛得出球")
	追.call("_process", 1.0 / 60.0)
	_check(追.is_queued_for_deletion() or not is_instance_valid(追),
			"目标 `_飞着=true` 那一拍球就该消失（否则就是跟着怪一起飞的那一下）")
	飞靶.set("_飞着", false)
	var 不追 := 飞行物.new() as Node2D
	root.add_child(不追)
	不追.call("配置", "0002000", 怪, 飞靶, 1, 0, null)
	不追.call("_process", 1.0 / 60.0)
	_check(not 不追.is_queued_for_deletion() and is_instance_valid(不追),
			"反向对照：靶子没被打飞、也还没越过 ⇒ 球必须还在飞（否则这条判据是恒真的）")

	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("技能飞行物回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		if not failure.is_empty():
			printerr(failure)
	quit(1)
