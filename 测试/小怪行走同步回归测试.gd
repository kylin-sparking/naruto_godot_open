extends SceneTree

## 权威小怪的**行走速度**必须与客户端渲染口径一致。
##
## 用户 2026-10-31 报：「小怪有时候不受伤害，一直往前走，甚至浮空走，然后消失」。
## 根子：服务端移动帧里带的是**未量化**的速度（175 像素/秒），可它自己按**原版 36 帧
## 客户端实际走出来的每秒位移**步进（144 像素/秒）——`_monster_walk_velocity` 对
## `_monster_client_walk_velocity`。我们客户端拿 175 连续积分，比服务端快 21%：
##   · 同一个移动段里服务端只发**一帧**（`monster_motion_signatures` 不变就不发），
##     于是怪在画面上越走越靠前，服务端那份位置留在后面；
##   · 客户端普攻/技能的选敌是**按怪物体型矩形**求交（`地图实体.get_nearest_enemy_in_rect`），
##     画面上的怪跑出命中盒 ⇒ 这一发根本不发 ⇒ 看着「不受伤害」，它还在往前走；
##   · x 冲出脚点段端后 `_贴脚点` 只夹 y 的查表用的 x，段面不再往下走 ⇒ 「浮空走」；
##   · 下一帧绝对位置（stop/换段/重生）一到，画面上的怪被拽回去/换掉 ⇒ 「然后消失」。
##
## 原版真值：
##   · `AbstractPhysicObject.applyVelocity:513-543`：每帧 `x += v * dt / 1000` 后
##     朝速度方向 `floor`/`ceil` —— 固定 36 帧下 175 像素/秒只走 144。
##   · `CommandController.tick:28-75`：移动段一次吃完，段与段之间由角色自己按速度积分。
##   · `AbstractPhysicObject.checkFoothold:394-455`：贴地走到脚点段端要么并进相邻段、
##     要么被 `leftBlock/rightBlock` 挡住，**不会悬空横着走出去**。
##   · 服务端 `_monster_client_walk_velocity` / `_consume_monster_move_step` / 发帧
##     `direction * _monster_walk_velocity`（本门钉源码，防悄悄改回）。

const 场景路径 := "res://场景/生成/地图_410000000_烘焙.tscn"
const 服务端路 := "res://服务端/runtime/tools/fake_flash_server.py"

## 410000000 的 4 号脚点，数字直接抄地图 JSON（不从被测代码取）。
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
		printerr("小怪行走同步回归测试：超时 90 秒，判红")
		quit(1)
		return true
	return false


func _断言(成立: bool, 说明: String) -> void:
	_条数 += 1
	if not 成立:
		_失败.append(说明)


func _截段(文: String, 起: String, 止: String) -> String:
	var a := 文.find(起)
	if a < 0:
		return ""
	var b := 文.find(止, a + 起.length())
	return 文.substr(a, b - a) if b > 0 else 文.substr(a)


func _斜段上y(x: float) -> float:
	return 斜段.y1 + (x - 斜段.x1) / (斜段.x2 - 斜段.x1) * (斜段.y2 - 斜段.y1)


func _run() -> void:
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
	var 段表: Dictionary = (图.get("id_map") as Dictionary).get("4", {})
	_断言(not 段表.is_empty()
			and absf(float(段表.get("x1", 0)) - 斜段.x1) < 0.01
			and absf(float(段表.get("x2", 0)) - 斜段.x2) < 0.01,
			"410000000 的 4 号脚点应仍是 (1405,1057)-(1648,946)，实得 %s" % str(段表))

	var 怪 = 实体.call("_spawn_life_entry", {
		"type": "m", "id": "5500006", "x": 1500.0, "y": 1000.0,
		"object_id": 6001, "jingying": [],
	}, 0, true)
	_断言(怪 != null, "服务端生成防守怪应成功（模板 5500006）")
	if 怪 == null:
		_finish()
		return
	# 手动逐拍调 `_process`，别让引擎再自动跑一份（两套积分会重叠）。
	怪.set_process(false)
	怪.set_physics_process(false)

	# ── ① 线上速度 → 原版每秒实际位移（36 帧量化）────────────────────────────
	var 换算 := [
		[175.0, 144.0], [200.0, 180.0], [125.0, 108.0],
		[300.0, 288.0], [-175.0, -144.0], [0.0, 0.0],
	]
	for 对 in 换算:
		var 得 := float(怪.call("_原版每秒位移", 对[0]))
		_断言(absf(得 - float(对[1])) < 0.001,
				"_原版每秒位移(%s) 应为 %s，实得 %s" % [对[0], 对[1], 得])
	_断言(absf(float(怪.call("_原版每秒位移", 175.0)) - 175.0) > 20.0,
			"175 像素/秒必须被量化掉一截（原版 36 帧只走 144），否则又是「客户端比服务端快」")

	# ── ② 服务端源码钉：发帧用未量化、步进用量化 ────────────────────────────
	var 源 := FileAccess.get_file_as_string(服务端路)
	_断言(not 源.is_empty(), "读不到服务端源码 " + 服务端路)
	if not 源.is_empty():
		var 发帧段 := _截段(源, "    def _broadcast_server_monster_move(", "\n    def ")
		_断言(发帧段.contains("direction * self._monster_walk_velocity(monster)"),
				"移动帧应继续带**未量化**速度（原版客户端靠每帧取整自己消化）")
		_断言(not 发帧段.contains("_monster_client_walk_velocity"),
				"移动帧里不许改用步进用的量化速度（Flash 端会因此慢 8 像素/秒）")
		var 量化段 := _截段(源, "    def _monster_client_walk_velocity(", "\n    def ")
		_断言(量化段.contains("divmod(1_000, frame_rate)")
				and 量化段.contains("// 1_000"),
				"_monster_client_walk_velocity 应仍是「36 帧逐帧取整」的口径")
		var 步进段 := _截段(源, "    def _tick_server_monsters(", "def _tick_muye_battle")
		_断言(步进段.contains("_consume_monster_move_step("),
				"服务端步进应仍按量化速度（_consume_monster_move_step）")
		var 帧率段 := _截段(源, "    NYA_MAIN_FRAME_RATE", "\n")
		_断言(帧率段.contains("36"), "服务端帧率常量应仍是 36，实得 %s" % 帧率段.strip_edges())

	# ── ③ 60 帧跑 1 秒：只许走 144，不许走 175 ──────────────────────────────
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1500, "start_y": roundi(_斜段上y(1500.0)),
		"vx": 175, "vy": 0, "foothold": 4,
	})
	_断言(absf(float((怪.get("_服务器速度") as Vector2).x) - 175.0) < 0.001,
			"包里的原始速度应原样记着（换算在积分那一拍做），实得 %s" % str(怪.get("_服务器速度")))
	for _帧 in 60:
		怪.call("_process", 1.0 / 60.0)
	var 一秒位 := 怪.get("position") as Vector2
	_断言(absf(一秒位.x - 1644.0) < 0.2,
			"175 像素/秒跑 1 秒应到 1644.0（=1500+144），实得 %.2f（跑到 1675 就是按原速积分，§3.317）"
			% 一秒位.x)
	_断言(absf(一秒位.y - _斜段上y(1644.0)) < 0.6,
			"一路上 y 应贴在 4 号斜段上（%.2f），实得 %.2f" % [_斜段上y(1644.0), 一秒位.y])

	# ── ④ 帧率无关：30 帧跑 1 秒也是 144 ────────────────────────────────────
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1500, "start_y": roundi(_斜段上y(1500.0)),
		"vx": 175, "vy": 0, "foothold": 4,
	})
	for _帧 in 30:
		怪.call("_process", 1.0 / 30.0)
	var 半频位 := 怪.get("position") as Vector2
	_断言(absf(半频位.x - 1644.0) < 0.2,
			"30 帧跑 1 秒也必须走 144（每秒位移口径，不是逐帧取整），实得 %.2f" % 半频位.x)

	# ── ⑤ 走到段端就停住：不许悬空横着走出去 ────────────────────────────────
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1600, "start_y": roundi(_斜段上y(1600.0)),
		"vx": 300, "vy": 0, "foothold": 4,
	})
	for _帧 in 30:   # 0.5 秒 × 288 = 144 像素，不夹的话会到 1744
		怪.call("_process", 1.0 / 60.0)
	var 端位 := 怪.get("position") as Vector2
	_断言(端位.x <= 斜段.x2 + 0.001,
			"走到 4 号脚点右端必须停住（x≤1648），实得 %.2f" % 端位.x)
	_断言(端位.x >= 斜段.x2 - 0.5, "应一路走到右端而不是提前停，实得 %.2f" % 端位.x)
	_断言(absf(float((怪.get("_服务器速度") as Vector2).x)) < 0.001,
			"到端后本地速度应清零，等服务的下一帧，实得 %s" % str(怪.get("_服务器速度")))
	_断言(端位.y <= 斜段.y2 + 0.001,
			"到端时 y 应是段端高度（%.1f），实得 %.2f" % [斜段.y2, 端位.y])

	# ── ⑥ 下一帧照常走（夹取不锁死）──────────────────────────────────────────
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1648, "start_y": roundi(斜段.y2),
		"vx": -175, "vy": 0, "foothold": 4,
	})
	怪.call("_process", 1.0 / 60.0)
	var 回位 := 怪.get("position") as Vector2
	_断言(回位.x < 1648.0 and absf(回位.x - (1648.0 - 2.4)) < 0.1,
			"反向帧来了应立刻接着走（1648-2.4），实得 %.2f" % 回位.x)

	# ── ⑦ 服务端把怪摆在段外时不许硬拽回来（世界 boss 的 authored 脚点号）───
	怪.call("apply_server_movement", {
		"object_id": 6001, "start_x": 1700, "start_y": roundi(斜段.y2),
		"vx": 175, "vy": 0, "foothold": 4,
	})
	怪.call("_process", 1.0 / 60.0)
	var 外位 := 怪.get("position") as Vector2
	_断言(absf(外位.x - (1700.0 + 2.4)) < 0.2,
			"起点本来就在段外时应照常积分（不许夹回 1648），实得 %.2f" % 外位.x)

	# ── ⑧ 包字段那一腿没被改坏：vx/foothold 照样解析 ────────────────────────
	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		_断言(false, "没有 BackendConnection 自动加载，包字段那一腿没验到")
	else:
		var 收到: Array[Dictionary] = []
		后端.connect("monster_moved", func(状态: Dictionary) -> void: 收到.append(状态))
		后端.call("_handle_move_monster_text",
				"138:0:6001:0:0:1500:1014:175:0:2:6:0:4:0:0:0:0:0".split(":"))
		_断言(收到.size() == 1, "一条 MOVE_MONSTER 文本应发出一次 monster_moved（实得 %d）" % 收到.size())
		if not 收到.is_empty():
			_断言(int(收到[0].get("vx", 0)) == 175 and int(收到[0].get("foothold", 0)) == 4,
					"vx / foothold 应原样解析，实得 %s" % str(收到[0]))

	_finish()


func _finish() -> void:
	_已收尾 = true
	if _失败.is_empty():
		print("小怪行走同步回归测试：通过（%d 条断言）" % _条数)
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("小怪行走同步回归测试：共 %d 条，红 %d 条" % [_条数, _失败.size()])
	quit(1)
