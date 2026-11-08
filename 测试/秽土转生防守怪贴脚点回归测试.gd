extends SceneTree

## 秽土转生（410000000）/ 守卫木叶村（407000000）的防守怪必须**沿脚点走**，
## 不许"从刷怪门到目标门拉一条直线"——那正是用户 2026-10-28 报的「小怪浮空走、
## 始终不掉血」（浮空 ⇒ 客户端的技能命中盒按 y 取，框不到怪）。
##
## 原版真值：
##   · `CommandController.tick():60-75` 收 NORMAL 移动段时做的是
##     `grounded = flag.grounded; currFootholdId = foothold`，之后由
##     `AbstractPhysicObject` 每帧按 `currFoothold` 求 y —— 包里的 y 只摆起点，
##     斜段/换层的 y 是**脚点给的**。
##   · 移动包第 13 段就是脚点（服务端 `_broadcast_server_monster_move` 的
##     `max(0, min(0xFFFF, monster.foothold))`），客户端 `_handle_move_monster_text`
##     读到 `state.foothold`。
##   · 防守线是副本配置的 `spec.lines[].portalFrom/portalTo`（`_copy_defence_routes`），
##     怪走到 `portalTo` 70px 内算"进村/接近鸣人"（`COPY_OBJECTIVE_ESCAPE_DISTANCE`）。
##
## 服务端 Python 的部分在 `开发工具/服务端防守怪寻路体检.py` 里真跑 8 条线；
## 本门负责**客户端这一半**（贴脚点、端点夹取、包字段）+ 服务端源码钉（防悄悄回退）。

const 场景路径 := "res://场景/生成/地图_410000000_烘焙.tscn"
const 服务端路 := "res://服务端/runtime/tools/fake_flash_server.py"

## 410000000 的 4 号脚点：从 (1405,1057) 斜到 (1648,946)。数字直接抄地图 JSON，
## 不从被测代码取（自洽比较对改动免疫）。
const 斜段 := {"x1": 1405.0, "y1": 1057.0, "x2": 1648.0, "y2": 946.0}

var _失败: Array[String] = []
var _条数 := 0
var _已收尾 := false
var _超时 := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _process(delta: float) -> bool:
	if _已收尾:
		return false
	_超时 += delta
	if _超时 > 90.0:
		printerr("秽土转生防守怪贴脚点回归测试：超时 90 秒，判红")
		quit(1)
		return true
	return false


func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)


## 取 `起` 到 `止` 之间的源码（`止` 找不到就取到文末）。
func _截段(文: String, 起: String, 止: String) -> String:
	var a := 文.find(起)
	if a < 0:
		return ""
	var b := 文.find(止, a + 起.length())
	return 文.substr(a, b - a) if b > 0 else 文.substr(a)


func _斜段上y( x: float ) -> float:
	return 斜段.y1 + (x - 斜段.x1) / (斜段.x2 - 斜段.x1) * (斜段.y2 - 斜段.y1)


func _run() -> void:
	## 烘焙场景的 `map_id` 是 `_ready` 里从 GameSession.current_map_id 拿的（`地图根节点.gd:101`）——
	## 不先设，场景会按默认的 101010000 载脚点。
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_断言(false, "没有 GameSession 自动加载，本门无法进图")
		_finish()
		return
	会话.set("current_map_id", "410000000")

	var 场景包 := load(场景路径) as PackedScene
	if 场景包 == null:
		_断言(false, "410000000 的可玩场景不在盘上")
		_finish()
		return
	var 场景 := 场景包.instantiate()
	root.add_child(场景)
	for _帧 in 12:
		await process_frame

	var 图 := 场景.get_node_or_null("Footholds")
	var 实体 := 场景.get_node_or_null("LifeRoot")
	if 图 == null or 实体 == null:
		_断言(false, "410000000 场景缺 Footholds / LifeRoot")
		_finish()
		return

	# ── ① 地图数据前提：4 号脚点确实是一条斜段 ────────────────────────────
	var 段: Dictionary = (图.get("id_map") as Dictionary).get("4", {})
	_断言(not 段.is_empty(), "410000000 应有 4 号脚点（地图 JSON 里那条斜段）")
	_断言(absf(float(段.get("x1", 0)) - 斜段.x1) < 0.01
			and absf(float(段.get("y1", 0)) - 斜段.y1) < 0.01
			and absf(float(段.get("x2", 0)) - 斜段.x2) < 0.01
			and absf(float(段.get("y2", 0)) - 斜段.y2) < 0.01,
			"4 号脚点应仍是 (1405,1057)-(1648,946)，实得 %s" % str(段))

	# ── ② 服务端生成出来的怪必须挂上地表（`地图实体._spawn_life_entry`）────
	var 怪 = 实体.call("_spawn_life_entry", {
		"type": "m", "id": "5500006", "x": 1500.0, "y": 1000.0,
		"object_id": 6001, "jingying": [],
	}, 0, true)
	_断言(怪 != null, "服务端生成防守怪应成功（模板 5500006）")
	if 怪 == null:
		_finish()
		return
	怪.set_process(false)
	怪.set_physics_process(false)
	_断言(怪.get("地表") == 图, "权威怪必须拿到 Footholds 地表（否则没脚点可贴）")
	_断言(bool(怪.get("authoritative")), "服务端生成的怪应是 authoritative")

	# ── ③ 移动帧里的脚点：y 立刻贴回段上（不用等第一帧积分）───────────────
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1500, "start_y": 1000,
		"vx": 0, "vy": 0, "foothold": 4,
	})
	var 首y := (怪.get("position") as Vector2).y
	_断言(absf(首y - _斜段上y(1500.0)) < 1.0,
			"4 号脚点上的怪 y 应贴到段面 %.1f，实得 %.2f" % [_斜段上y(1500.0), 首y])
	_断言(int(怪.get("_服务器脚点")) == 4, "服务端给的脚点号应记进 _服务器脚点，实得 %s"
			% str(怪.get("_服务器脚点")))

	# ── ④ 两帧之间按速度积分：x 走、y 跟着段面滑（不是冻在起点 y）──────────
	## 步长按**原版 36 帧客户端实际位移**算：200 像素/秒每帧 `floor(200*27/1000)`=
	## `floor(200*28/1000)`=5 像素 ⇒ 一秒 180 像素（`AbstractPhysicObject.applyVelocity:513-543`；
	## 服务端 `_monster_client_walk_velocity` 同一口径）。直接乘 200 会比服务端快，见 §3.317。
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1500, "start_y": roundi(首y),
		"vx": 200, "vy": 0, "foothold": 4,
	})
	怪.call("_process", 1.0 / 60.0)
	var 位 := 怪.get("position") as Vector2
	var 期望x := 1500.0 + 180.0 / 60.0
	_断言(absf(位.x - 期望x) < 0.5, "权威怪按速度自行积分 x，应到 %.2f，实得 %.2f" % [期望x, 位.x])
	_断言(absf(位.y - _斜段上y(期望x)) < 0.6,
			"积分后 y 应仍贴段面 %.2f，实得 %.2f（不贴 = 浮空）" % [_斜段上y(期望x), 位.y])
	_断言(位.y < 首y - 0.5, "往右走上坡段，y 必须往上升方向变小，实得 %.2f → %.2f" % [首y, 位.y])

	# ── ⑤ x 越出段端：夹到端点求 y，不许 INF / 卡在旧值 ─────────────────────
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1700, "start_y": 0,
		"vx": 0, "vy": 0, "foothold": 4,
	})
	_断言(absf((怪.get("position") as Vector2).y - 斜段.y2) < 0.01,
			"x=1700 越出段右端应夹到端点 y=946，实得 %.2f" % (怪.get("position") as Vector2).y)
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1000, "start_y": 0,
		"vx": 0, "vy": 0, "foothold": 4,
	})
	_断言(absf((怪.get("position") as Vector2).y - 斜段.y1) < 0.01,
			"x=1000 越出段左端应夹到端点 y=1057，实得 %.2f" % (怪.get("position") as Vector2).y)

	# ── ⑥ 脚点 0 / 不认识的脚点：y 一律不动（没有可贴的东西就别乱贴）─────
	怪.set("position", Vector2(1500.0, 1234.0))
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1500, "start_y": 1234,
		"vx": 0, "vy": 0, "foothold": 0,
	})
	_断言(absf((怪.get("position") as Vector2).y - 1234.0) < 0.01,
			"脚点 0 时不该动 y，实得 %.2f" % (怪.get("position") as Vector2).y)
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1500, "start_y": 1234,
		"vx": 0, "vy": 0, "foothold": 9999,
	})
	_断言(absf((怪.get("position") as Vector2).y - 1234.0) < 0.01,
			"不认识的脚点号时不该动 y，实得 %.2f" % (怪.get("position") as Vector2).y)

	# ── ⑦ 后端解析：移动包第 13 段要落成 state.foothold ───────────────────
	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_断言(false, "没有 BackendConnection 自动加载，包字段那一腿没验到")
	else:
		var 收到: Array[Dictionary] = []
		后端.connect("monster_moved", func(状态: Dictionary) -> void: 收到.append(状态))
		后端.call("_handle_move_monster_text",
				"138:0:6001:0:0:1500:1014:100:0:2:6:0:4:0:0:0:0:0".split(":"))
		_断言(收到.size() == 1, "一条 MOVE_MONSTER 文本应发出一次 monster_moved（实得 %d）" % 收到.size())
		if not 收到.is_empty():
			var 帧: Dictionary = 收到[0]
			_断言(int(帧.get("foothold", 0)) == 4,
					"第 13 段（fields[12]）应解析成 foothold=4，实得 %s" % str(帧.get("foothold")))
			_断言(int(帧.get("vx", 0)) == 100 and int(帧.get("object_id", 0)) == 6001,
					"vx / object_id 应解析正确，实得 %s" % str(帧))

	# ── ⑧ 服务端源码钉（Python 真跑在 开发工具/服务端防守怪寻路体检.py）───
	var 源 := FileAccess.get_file_as_string(服务端路)
	_断言(not 源.is_empty(), "读不到服务端源码 " + 服务端路)
	if not 源.is_empty():
		var 目标段 := _截段(源, "    def _tick_copy_objectives(", "\n    def ")
		_断言(目标段.contains("_tick_copy_objective_walk("),
				"_tick_copy_objectives 必须走脚点寻路（_tick_copy_objective_walk）")
		## 只看防守怪那一支（护送副本 9 走的是另一条 hypot 分支，合法，不算在内）。
		var 防守支 := _截段(目标段, "escaped: MonsterState | None = None", "self._record_copy_kill()")
		_断言(防守支.length() > 100, "取不到防守怪那一支源码（片段长度 %d）" % 防守支.length())
		_断言(not 防守支.contains("math.hypot(delta_x, delta_y)"),
				"防守怪那一支不许再留直线插值（应交给 _tick_copy_objective_walk）")
		_断言(_截段(源, "    def _walk_copy_objective_straight(", "\n    def ").contains("math.hypot"),
				"没有脚点的兜底 _walk_copy_objective_straight 应保留")
		var 走路段 := _截段(源, "    def _tick_copy_objective_walk(", "\n    def ")
		_断言(走路段.contains("monster_path_next_edge("),
				"换层必须走脚点图的 path edge，实得片段长度 %d" % 走路段.length())
		_断言(走路段.count("_broadcast_server_monster_move(") == 3,
				"走路函数应恰好发三处移动帧（同层 / 到换层点 / 换层后），实得 %d 处"
				% 走路段.count("_broadcast_server_monster_move("))
		## 四处 y 分别对应上面三处移动帧 + 梯子那一帧；任何一处退化成常量都会让条数变少。
		_断言(走路段.count("y_at(") == 4,
				"每一步的 y 都必须由脚点 y_at 给（应有 4 处），实得 %d 处" % 走路段.count("y_at("))
		var 夹取段 := _截段(源, "    def _objective_step_x(", "\n    def ")
		_断言(夹取段.contains("max(floor.left, min(floor.right"),
				"_objective_step_x 必须把走位夹在脚点两端")
		var 刷怪段 := _截段(源, "    def _spawn_next_copy_wave(", "\n    def ")
		_断言(刷怪段.length() > 200, "取不到 _spawn_next_copy_wave 源码（片段长度 %d）" % 刷怪段.length())
		_断言(not 刷怪段.contains("edo_target"),
				"刷怪不许再把目标改写成鸣人脚点（防御线的目标就是 portalTo）")
		_断言(刷怪段.contains("monster.target_x = target_portal.x"),
				"防守怪目标应是线路的 portalTo")
		var 包段 := _截段(源, "    def _broadcast_server_monster_move(", "\n    def ")
		## 二进制包那一格必须原样带脚点（文本包那一行另有一处，`motion_signature` 里还有一处，
		## 所以按具体写法点名，别用 `contains("monster.foothold")` 那种一抓一大片的判据）。
		_断言(包段.count("min(0xFFFF, monster.foothold)") == 1,
				"移动包的二进制载荷必须把脚点号带出去（客户端靠它贴地）")

	_finish()


func _finish() -> void:
	_已收尾 = true
	if _失败.is_empty():
		print("秽土转生防守怪贴脚点回归测试：通过（%d 条断言）" % _条数)
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("秽土转生防守怪贴脚点回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
