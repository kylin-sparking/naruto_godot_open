extends SceneTree
## 量「角色容易卡在梯子上不动」（用户 2026-10-19 实机报）—— 先把卡住的那一支量出来。
##
## 夹具怎么造"一定会爬梯"的一趟（第一版按梯子的 y2 直接摆人，结果 6 把梯子全不出 climb 段，
## 量具空转 —— 因为绳底下那条落脚点未必就是图里那条边的下分量）：
##   ① 照 `_add_ladder_edges`（`自动寻路.gd:194-212`）同一套算式问出这把梯的
##      **上分量 / 下分量**（连它自己建边用的判据一起复现，跳过它自己都连不上边的绳）；
##   ② 在**下分量**里挑一段 x 覆盖住梯子的那条落脚点，把人摆在那条上（脚点 = 那条的 y）；
##   ③ `plan(下 fh → 上 fh)` 出来的段序列里必须有 `climb`，才开跑；没有就把原因打出来。
##
## 两条腿各自独立、红法不一样：
##   甲 纯点击寻路上梯：要能在有限帧内爬到顶并落到上面那层；
##   乙 爬到第 30 帧时把路线取消（挂机的 放招 / 停挂机 那一路就是 `cancel_auto_path()`）⇒
##      看人是不是**钉在梯子上不动**（`climbing` 还真、竖直速度 0、又没人按键）。
##
## 跑法：<godot> --headless --path <工程> --script res://开发工具/量爬梯卡住.gd
const 地图路 := "res://场景/地图/地图场景.tscn"
const 每梯帧数 := 400
const 最多测几把 := 5			# 无头也按 60Hz 走墙钟，梯多了纯耗时间
const 卡住帧数线 := 45			# 连续 45 物理帧（≈0.75 秒）在梯子上位移为 0 = 卡住

var 红: Array[String] = []
var 判数 := 0

func _判(对: bool, 说明: String) -> void:
	判数 += 1
	if not 对:
		红.append(说明)
		prints("红：", 说明)

func _initialize() -> void:
	call_deferred("_跑")

func _帧(n: int) -> void:
	for _i in n:
		await physics_frame

func _跑() -> void:
	var 会 = root.get_node_or_null("GameSession")
	_判(会 != null, "取到 游戏会话")
	if 会 == null:
		_收()
		return
	## 挂机先关掉：本量具单独看"点击寻路 + 取消路线"这两条，别让托管在旁边抢方向
	if 会.has_method("request_hang"):
		会.call("request_hang", false)
	var 图 = (load(地图路) as PackedScene).instantiate()
	root.add_child(图)
	await _帧(20)
	var 玩 = get_first_node_in_group("player")
	_判(玩 != null, "场景里没有玩家（这条量具判不了）")
	if 玩 == null:
		_收()
		return
	var 梯根: Node = 玩.get("ladder_root")
	var 脚根: Node = 玩.get("footholds")
	## ⚠ `auto_pathfinder` 是 **RefCounted**（`自动寻路.gd` 不挂树），别写 `: Node` ——
	##   写错是运行期报错，而报错会把这条协程当场打断、`quit()` 永远轮不到（进程挂死）。
	var 路 = 玩.get("auto_pathfinder")
	_判(梯根 != null and 脚根 != null and 路 != null, "玩家上要拿得到 ladder_root / footholds / auto_pathfinder")
	if 梯根 == null or 脚根 == null or 路 == null:
		_收()
		return
	var 梯表: Array = 梯根.get("ladders")
	_判(梯表.size() > 0, "这张图至少要有一把梯子/绳（没有整条量具就是空转）")
	if 梯表.is_empty():
		_收()
		return
	var 分量段: Dictionary = 路.get("component_segments")
	prints("量爬梯：图上一共 %d 把攀爬物、%d 条连通分量" % [梯表.size(), 分量段.size()])
	var 测过的 := 0
	var 卡住的: Array = []
	for 序 in 梯表.size():
		var 梯: Dictionary = 梯表[序]
		var 顶 := float(梯.y1)
		var 底 := float(梯.y2)
		if 底 - 顶 < 24.0:
			continue						# 太短的绳测不出"爬"这个动作
		var 上分量 := int(路.call("_nearest_platform", float(梯.x), 顶, -1, 100.0).get("component", -1))
		var 下分量 := int(路.call("_nearest_platform", float(梯.x), 底, 上分量, 120.0, true).get("component", -1))
		if 上分量 < 0 or 下分量 < 0 or 上分量 == 下分量:
			prints("  梯#%d x=%s 顶=%s 底=%s ⇒ 它自己就不是边（上=%s 下=%s），跳过" % [序, str(梯.x), str(顶), str(底), str(上分量), str(下分量)])
			continue
		var 下点 := 分量里靠近梯x的落脚(分量段.get(下分量, []), 脚根, float(梯.x))
		var 上点 := 分量里靠近梯x的落脚(分量段.get(上分量, []), 脚根, float(梯.x) + 40.0)
		if 下点.is_empty() or 上点.is_empty():
			prints("  梯#%d ⇒ 分量里取不到落脚点（下=%s 上=%s），跳过" % [序, str(下点), str(上点)])
			continue
		await 摆到位(玩, Vector2(float(下点.x), float(下点.y)))
		var 当前fh := String(玩.get("current_fh_id"))
		var 划: Array = 路.call("plan", 当前fh, String(上点.id), float(上点.x), float(下点.x))
		var 段名: Array = []
		var 有爬 := false
		for 段 in 划:
			var 类 := String((段 as Dictionary).get("type", ""))
			段名.append(类)
			if 类 == "climb":
				有爬 = true
		if not 有爬:
			prints("  梯#%d x=%s 下fh=%s 上fh=%s plan=%s ⇒ 路线里 climb 被更近的路顶掉了（例如跳），跳过" % [序, str(梯.x), 当前fh, String(上点.id), str(段名)])
			continue
		## ── 甲：真点一次顶上那层，让路线自己跑（**以运行期那条路线为准**：
		## plan 里有 climb，`走向` 取的目标点可能被 `find_click_target` 挪到另一条落脚点，
		## 那时候这趟根本不会爬梯 ⇒ 不能算测过，否则判据就成了 0 比 0）──
		await 摆到位(玩, Vector2(float(下点.x), float(下点.y)))
		玩.call("走向", Vector2(float(上点.x), float(上点.y) - 12.0), false, false)
		var 真路线: Array = []
		for 段 in (玩.get("auto_actions") as Array):
			var 类 := String((段 as Dictionary).get("type", ""))
			真路线.append(类)
		if not 真路线.has("climb"):
			prints("  梯#%d ⇒ 走向之后运行期路线=%s（没有 climb），这趟不算测过" % [序, str(真路线)])
			continue
		测过的 += 1
		var 结甲: Dictionary = await 跑一段(玩, 顶, 底, false)
		prints("  梯#%d x=%s 顶=%s 底=%s 路线=%s ⇒ 甲 到顶=%s 卡住=%s 末帧=%s" % [
				序, str(梯.x), str(顶), str(底), str(真路线), str(结甲.到顶), str(结甲.卡住), str(结甲.末)])
		if bool(结甲.卡住):
			卡住的.append("甲 梯#%d（爬到一半钉住：%s）" % [序, str(结甲.末)])
		## ── 乙：同样上路，第 30 帧调 cancel_auto_path()（挂机 放招/停挂机 那一路）──
		await 摆到位(玩, Vector2(float(下点.x), float(下点.y)))
		玩.call("走向", Vector2(float(上点.x), float(上点.y) - 12.0), false, false)
		var 结乙: Dictionary = await 跑一段(玩, 顶, 底, true)
		prints("  梯#%d ⇒ 乙 到顶=%s 卡住=%s 末帧=%s" % [序, str(结乙.到顶), str(结乙.卡住), str(结乙.末)])
		if bool(结乙.卡住):
			卡住的.append("乙 梯#%d（取消路线之后钉在梯子上：%s）" % [序, str(结乙.末)])
		if 测过的 >= 最多测几把:
			break
	_判(测过的 >= 1, "夹具：至少要测到 1 把真会爬的梯子（实得 %d ⇒ 量具从头到尾没上过梯，判据全是空转）" % 测过的)
	_判(卡住的.is_empty(), "有梯子把角色钉住了（人不动了）：%s" % str(卡住的))
	_收()

## 在某条连通分量里挑一段"横向覆盖住这个 x"的落脚点，取它上面那个点当脚点。
## ⚠ `component_segments[分量]` 里存的是**落脚点段本体**（字典，不是 id），
##   而一段是斜的 ⇒ y 要用 `地表.ground_y_on(x, 段)` 插值，不能拿 `y1` 当常数。
func 分量里靠近梯x的落脚(段表: Array, 脚根: Node, 目标x: float) -> Dictionary:
	var 最近 := {}
	var 最近距 := INF
	for 段v in 段表:
		if not (段v is Dictionary):
			continue
		var 段: Dictionary = 段v
		var x1 := float(段.get("x1", 0.0))
		var x2 := float(段.get("x2", 0.0))
		var 左 := minf(x1, x2)
		var 右 := maxf(x1, x2)
		var 覆 := 目标x >= 左 and 目标x <= 右
		var 取x := clampf(目标x, 左 + 6.0, maxf(左 + 6.0, 右 - 6.0))
		var 距 := 0.0 if 覆 else absf((左 + 右) * 0.5 - 目标x)
		if 距 < 最近距:
			最近距 = 距
			最近 = {"id": String(段.get("id", "")), "x": 取x,
					"y": float(脚根.call("ground_y_on", 取x, 段))}
	return 最近

## 把玩家**硬摆**到某个脚点并等它落稳（绕开上一段留下的状态）。
func 摆到位(玩: Node, 位: Vector2) -> void:
	玩.set("climbing", false)
	玩.call("cancel_auto_path")
	玩.set("position", 位)
	玩.set("velocity", Vector2.ZERO)
	玩.set("on_ground", false)
	玩.set("current_fh_id", "")
	玩.set("ladder_cooldown", 0.0)
	for _i in 10:
		await physics_frame

## 逐帧盯：到顶（在地面且脚点 ≤ 顶+3）算成功；在梯上连续 45 帧位移 < 0.05 像素算卡住。
## 第四参 中途取消=true ⇒ 第 30 帧调一次 `cancel_auto_path()`（挂机的 放招/停挂机 都走它）。
func 跑一段(玩: Node, 顶: float, 底: float, 中途取消: bool) -> Dictionary:
	var 静止 := 0
	var 上次: Vector2 = 玩.get("position")
	var 末 := {}
	var 取消过 := false
	for 帧 in 每梯帧数:
		if 中途取消 and not 取消过 and 帧 == 30:
			玩.call("cancel_auto_path")
			取消过 = true
		await physics_frame
		var 位: Vector2 = 玩.get("position")
		var 在爬: bool = bool(玩.get("climbing"))
		var 在地面: bool = bool(玩.get("on_ground"))
		末 = {"帧": 帧, "位": 位, "在爬": 在爬, "速度": 玩.get("velocity"), "在地面": 在地面,
				"取消过": 取消过, "路线在走": bool(玩.get("click_move_active")),
				"爬向": float(玩.get("click_climb_direction")),
				"步": int(玩.get("auto_action_index")), "冷却": float(玩.get("ladder_cooldown"))}
		if 在爬 and 位.distance_to(上次) < 0.05:
			静止 += 1
		else:
			静止 = 0
		上次 = 位
		if 静止 >= 卡住帧数线:
			return {"到顶": false, "卡住": true, "末": 末}
		if not 在爬 and 在地面 and 位.y <= 顶 + 3.0:
			return {"到顶": true, "卡住": false, "末": 末}
		if not 在爬 and 在地面 and 位.y > 底 - 2.0 and 帧 > 300:
			return {"到顶": false, "卡住": false, "末": 末}	# 掉回原地：没爬上去，另一码事
	return {"到顶": false, "卡住": 静止 >= 卡住帧数线, "末": 末}

func _收() -> void:
	if 红.is_empty():
		prints("量爬梯卡住：通过（%d 条判据）" % 判数)
		quit(0)
		return
	prints("量爬梯卡住：%d 条判据，红 %d 条" % [判数, 红.size()])
	quit(1)
