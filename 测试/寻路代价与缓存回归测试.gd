## 点击寻路的两件事：**别每帧重建图**、**代价是时间不是边类型**。
##
## 背景（用户 2026-10-01 报"点上层怪很卡、而且不是最近路径"）：
##   · `plan()` 原本每次都 `_build_graph()`。实测这一句就是全部开销 ——
##     101010000 **7.75 ms/次**、木叶村 **14.32 ms/次**（`plan()` 与它同速），
##     而接近途中每 0.35s 重排一次、每次落地再重排一次 ⇒ 一帧 16.7ms 里塞半帧到一帧的活。
##   · 代价原本是写死的 `掉落1 / 跳跃2 / 爬梯4 / 走路1`，**与距离无关** ⇒
##     "走 3000px 再跳" 被判得比 "就地爬 60px 的梯子" 便宜。
extends SceneTree

var _failures: Array[String] = []
var _checked := 0
## A 段从真地图上拿到的寻路器（`AutoPathfinder` 不能空手造 —— `_init` 会读 `footholds.segments`）。
var _pf: RefCounted = null

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures.append(message)

func _近(实际: float, 期望: float, 容差 := 0.01) -> bool:
	return absf(实际 - 期望) <= 容差

func _run() -> void:
	await _A_缓存与真实地图()
	if _pf != null:
		_B_代价是时间(_pf)
	_finish()

func _A_缓存与真实地图() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for _frame in 12:
		await process_frame
	var 脚点 := 场景.get_node_or_null("Footholds")
	var 玩家 := 场景.get_node_or_null("Player")
	if 脚点 == null or 玩家 == null:
		_check(false, "地图场景缺少 Footholds / Player")
		return
	var pf = 玩家.get("auto_pathfinder")
	_pf = pf
	_check(int(pf.get("构建次数")) == 0, "还没寻过路时不该已经建图")

	# 找一对跨分量的脚点（同分量直接返回一条 walk，测不到图）
	var 起 := ""; var 止 := ""; var 最远 := 0.0
	for a in 脚点.segments:
		for b in 脚点.segments:
			if pf.get_component(String(a.id)) == pf.get_component(String(b.id)):
				continue
			var d: float = absf(float(a.x1) - float(b.x1)) + absf(float(a.y1) - float(b.y1))
			if d > 最远:
				最远 = d; 起 = String(a.id); 止 = String(b.id)
	if 止 == "":
		_check(false, "本地图没有跨分量的一对脚点，本条测不到东西")
		return

	var 起始x := float(脚点.id_map[起].x1)
	var 路线: Array = []
	for _i in 50:
		路线 = pf.plan(起, 止, float(脚点.id_map[止].x1), 起始x)
	_check(int(pf.get("构建次数")) == 1,
			"寻路 50 次只应建一次图（实际 %d 次）—— 这就是「很卡」那条" % int(pf.get("构建次数")))
	_check(not 路线.is_empty(), "跨分量的一对脚点应能排出一条路线")
	# 路线里只该有这四种动作
	var 合法 := true
	for act in 路线:
		if not ["walk", "jump", "climb", "drop"].has(String((act as Dictionary).get("type", ""))):
			合法 = false
	_check(合法, "路线里的动作类型只该是 walk/jump/climb/drop")
	# 秒数应是个正数、有限
	var 秒: float = pf.call("_路线秒", 路线, 起始x)
	_check(秒 > 0.0 and 秒 < 1.0e6, "路线总耗时应是正的有限值（实际 %.2f 秒）" % 秒)

	# ⭐ 台阶：x 区间**重叠**的两块脚点，原版 `Joint.makeJoints()` 的最后一支会建
	# JUMP_UP/JUMP_DOWN（起跳点 == 落点，direction 0）。我们的老实现这一步是 `continue`
	# ⇒ 站在台阶下面根本没有边，只能绕远去爬绳子（用户 2026-10-01 报的就是这个）。
	var 有重叠对 := false
	var 图: Dictionary = pf.call("取图")
	var 分量界 := {}
	for 分量 in 图:
		var lo := INF; var hi := -INF
		for 段 in pf.get("component_segments")[分量]:
			lo = minf(lo, minf(float(段.x1), float(段.x2)))
			hi = maxf(hi, maxf(float(段.x1), float(段.x2)))
		分量界[int(分量)] = [lo, hi]
	for a in 分量界:
		for b in 分量界:
			if a >= b:
				continue
			if minf(float(分量界[a][1]), float(分量界[b][1])) > maxf(float(分量界[a][0]), float(分量界[b][0])):
				有重叠对 = true
	var 垂直边 := 0
	var 向下边: Dictionary = {}
	var 向上边: Dictionary = {}
	for 分量 in 图:
		for e in 图[分量]:
			var ed: Dictionary = e
			if String(ed.get("type", "")) == "jump" and int(ed.get("direction", 9)) == 0:
				垂直边 += 1
				# `down` 标记必须与几何一致：目标在下 ⇒ 带 down（执行侧据此穿台，见下面执行那钉）
				var sx := float(ed.get("x", 0.0))
				var 源y: float = pf.call("_component_surface_at", int(分量), sx)
				var 标y: float = pf.call("_component_surface_at", int(ed.get("target_component", -1)), sx)
				if 源y != INF and 标y != INF:
					_check(bool(ed.get("down", false)) == (标y > 源y),
							"垂直跳边的 down 标记要与几何一致（x=%.1f 源y=%.1f 目标y=%.1f down=%s）"
							% [sx, 源y, 标y, str(ed.get("down", false))])
				if bool(ed.get("down", false)):
					if 向下边.is_empty():
						向下边 = ed
				elif 向上边.is_empty():
					向上边 = ed
	if 有重叠对:
		_check(垂直边 > 0, "本地图有 x 区间重叠的脚点对，就该建出垂直跳边（实际 %d 条）" % 垂直边)
	else:
		print("寻路代价与缓存回归测试：本地图没有 x 重叠的脚点对，台阶那条本轮没验")

	# ⭐ 执行侧那一钉（2026-10-04 用户报"不自己下降平台、一直原地起跳"）：
	#    向下那条边必须**穿台下落**（原版 `jumpDownTarget`：离地、不下上跳）；
	#    向上那条仍是**上跳**，别把修好的上台阶弄反。
	if not 向下边.is_empty():
		var v向下 := _试执行边(玩家, 向下边)
		_check(v向下.y >= 0.0 and not bool(玩家.get("on_ground")),
				"向下的垂直跳边必须走穿台下落（离地、velocity.y>=0 而不是向上跳）；实测 velocity.y=%.1f on_ground=%s"
				% [v向下.y, str(玩家.get("on_ground"))])
	else:
		print("寻路代价与缓存回归测试：本地图没有向下的垂直跳边，穿台执行那条本轮没验")
	if not 向上边.is_empty():
		var v向上 := _试执行边(玩家, 向上边)
		_check(v向上.y < 0.0 and not bool(玩家.get("on_ground")),
				"向上的垂直跳边仍应是上跳（velocity.y<0）；实测 velocity.y=%.1f" % v向上.y)
	else:
		print("寻路代价与缓存回归测试：本地图没有向上的垂直跳边，上跳那条本轮没验")

	# 失效入口：重建后再寻一次，应再建一次图
	pf.call("重建地图缓存")
	_check(int(pf.get("构建次数")) == 1, "只是失效缓存、还没寻路时不该建图")
	pf.plan(起, 止, float(脚点.id_map[止].x1), 起始x)
	_check(int(pf.get("构建次数")) == 2, "失效后再寻一次应重建成图（实际 %d）" % int(pf.get("构建次数")))
	场景.queue_free()
	await process_frame

## 代价公式本身：按真实秒数，且**算上走到这条边入口的那段路**。
func _B_代价是时间(pf: RefCounted) -> void:
	# ① 同类型的边，距离越远越贵
	_check(_近(pf.call("边耗时秒", {"type": "climb", "距离": 600.0}), 4.8, 0.01),
			"爬 600px 应 4.8 秒（125px/秒）")
	_check(pf.call("边耗时秒", {"type": "climb", "距离": 600.0})
			> pf.call("边耗时秒", {"type": "climb", "距离": 60.0}), "爬得越远越贵")
	_check(pf.call("边耗时秒", {"type": "drop", "distance": 800.0})
			> pf.call("边耗时秒", {"type": "drop", "distance": 80.0}), "落得越深越贵")
	_check(_近(pf.call("走路秒", 175.0), 1.0, 0.001), "走 175px 应 1 秒")

	# ② ⭐ 就是用户报的那条：**近处的短爬梯** 必须胜过 **远处起跳的一次跳跃**。
	#    老模型（爬梯 4 / 跳跃 2）判反了 —— 它会选后者。
	var 近爬梯: Array = [
		{"type": "climb", "x": 100.0, "距离": 60.0, "target_component": 1},
		{"type": "walk", "x": 150.0, "target_component": 1},
	]
	var 远处跳: Array = [
		{"type": "jump", "x": 5992.0, "landing_x": 6062.0, "flight": 0.5, "target_component": 1},
		{"type": "walk", "x": 150.0, "target_component": 1},
	]
	var 近秒: float = pf.call("_路线秒", 近爬梯, 0.0)
	var 远秒: float = pf.call("_路线秒", 远处跳, 0.0)
	_check(近秒 < 远秒,
			"近处短爬梯应快过远处起跳（近 %.2f 秒 vs 远 %.2f 秒）—— 老模型判反了这一条" % [近秒, 远秒])
	_check(_近(近秒, 0.5714 + 0.48 + 0.2857, 0.01), "近路应手算 1.337 秒（实际 %.3f）" % 近秒)

	# ③ 落点 x 要跟着边类型走（跳是 landing_x，其它是 x）
	_check(_近(pf.call("落点x", {"type": "jump", "x": 10.0, "landing_x": 90.0}), 90.0), "跳跃的落点是 landing_x")
	_check(_近(pf.call("落点x", {"type": "climb", "x": 10.0}), 10.0), "爬梯的落点就是梯子 x")

## 把玩家摆到这条边的起跳 x 与地面态，走一帧点击路线，返回执行后的 velocity。
## 只驱执行分支、不跑物理帧 —— 判的就是"这条边被当成穿台还是上跳"。
func _试执行边(玩家: Node, 边: Dictionary) -> Vector2:
	玩家.position.x = float(边.get("x", 0.0))
	玩家.set("auto_actions", [边])
	玩家.set("auto_action_index", 0)
	玩家.set("click_move_active", true)
	玩家.set("on_ground", true)
	玩家.set("velocity", Vector2.ZERO)
	玩家.call("_走点击路线")
	return 玩家.get("velocity")

func _finish() -> void:
	if _failures.is_empty():
		print("寻路代价与缓存回归测试：通过（%d 条断言）" % _checked)
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)
