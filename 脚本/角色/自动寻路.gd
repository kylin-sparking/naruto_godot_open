class_name AutoPathfinder
extends RefCounted

var footholds: Node
var ladder_root: Node
var component_by_foothold := {}
var component_segments := {}

func _init(foothold_node: Node, ladder_node: Node) -> void:
	footholds = foothold_node
	ladder_root = ladder_node
	_build_components()

func get_component(foothold_id: String) -> int:
	return int(component_by_foothold.get(foothold_id, -1))

## 起点在出发点那个脚点上的**世界 x**。老接口没有它，代价就只能是"边类型"——
## 于是"绕 5000px 去爬一个近梯子"和"就地爬"一样贵。给上它，代价才是真的**时间**。
func plan(start_foothold_id: String, target_foothold_id: String, target_x: float,
		起点x := INF) -> Array:
	var start_component := get_component(start_foothold_id)
	var target_component := get_component(target_foothold_id)
	if start_component < 0 or target_component < 0:
		return []
	if start_component == target_component:
		return [{"type": "walk", "x": target_x, "target_component": target_component}]

	var graph := 取图()
	if 起点x == INF:
		var 起步: Dictionary = footholds.id_map.get(start_foothold_id, {})
		起点x = float(起步.get("x1", 0.0))
	# 按**耗时（秒）**搜最快的路线。
	#
	# 历史：先是纯 BFS（每步当 1，邻接表按 jump→ladder→drop 建）⇒ 优先绕梯子；
	# 2026-09 改成"边类型权重"（掉落 1 / 跳跃 2 / 爬梯 4）⇒ 修好了"该掉却去爬梯"，
	# 但**仍然与距离无关**：`走 3000px 再跳` 比 `就地爬一个 60px 的梯子` 便宜 ——
	# 用户 2026-10-01 报的"不是最近路径"就是这个。现在每条边给的是真实秒数，
	# 而且**算上在平台内走到这条边入口的那段路**（`入口x` 就是为这个传的）。
	var pending := [start_component]
	var 代价 := {start_component: 0.0}
	var 入口x := {start_component: 起点x}
	var visited := {}
	var previous := {}
	while not pending.is_empty():
		# 取当前代价最小的（图很小，线性找够用）
		var 最小下标 := 0
		for i in range(1, pending.size()):
			if float(代价.get(pending[i], INF)) < float(代价.get(pending[最小下标], INF)):
				最小下标 = i
		var component: int = pending[最小下标]
		pending.remove_at(最小下标)
		if visited.has(component):
			continue
		visited[component] = true
		if component == target_component:
			break
		for edge in graph.get(component, []):
			var destination := int(edge.target_component)
			if visited.has(destination):
				continue
			var 走 := 走路秒(absf(float(edge.get("x", 0.0)) - float(入口x.get(component, 起点x))))
			var 新 := float(代价[component]) + 走 + 边耗时秒(edge)
			if 新 < float(代价.get(destination, INF)):
				代价[destination] = 新
				入口x[destination] = 落点x(edge)
				previous[destination] = {"component": component, "edge": edge}
				pending.append(destination)
	if not previous.has(target_component):
		return []

	var reversed_actions := []
	var cursor := target_component
	while cursor != start_component:
		var step: Dictionary = previous[cursor]
		reversed_actions.append(step.edge)
		cursor = int(step.component)
	reversed_actions.reverse()
	reversed_actions.append({"type": "walk", "x": target_x, "target_component": target_component})
	return reversed_actions

func _build_components() -> void:
	component_by_foothold.clear()
	component_segments.clear()
	var component_id := 0
	for segment in footholds.segments:
		var foothold_id: String = segment.id
		if component_by_foothold.has(foothold_id):
			continue
		var pending := [foothold_id]
		component_segments[component_id] = []
		while not pending.is_empty():
			var candidate_id: String = pending.pop_back()
			if component_by_foothold.has(candidate_id) or not footholds.id_map.has(candidate_id):
				continue
			component_by_foothold[candidate_id] = component_id
			var candidate: Dictionary = footholds.id_map[candidate_id]
			component_segments[component_id].append(candidate)
			for linked_id in [candidate.prev, candidate.next]:
				if linked_id != "" and linked_id != "0" and linked_id != "-1":
					pending.append(linked_id)
		component_id += 1

## 一条边**真正要花几秒**。常数与 `玩家`/原版 `Physics.as` 同一套：
## `Physics.WALK_SPEED = 125`、角色 `walkSpeedFactor = 1.4` ⇒ 175；攀爬 `CLIMB_SPEED = 125`；
## `JUMP_SPEED = 555`（注意角色的 `jump_speed` 是 666，跳跃边按 666 算的飞行时间，见 `_add_jump_edges`）；
## `GRAVITY_ACC = 2000`。
const 走速 := 175.0
const 爬速 := 125.0
const 落重力 := 2000.0

func 走路秒(水平距离: float) -> float:
	return absf(水平距离) / 走速

func 边耗时秒(edge: Dictionary) -> float:
	match String(edge.get("type", "")):
		"walk":
			return 走路秒(float(edge.get("x", 0.0)))
		"climb":
			return absf(float(edge.get("距离", 0.0))) / 爬速
		"jump":
			return float(edge.get("flight", 0.0))
		"drop":
			# 自由落体 |Δy| = ½gt² 的一半，再算上落地后走到落点 x 的那一段
			return sqrt(2.0 * absf(float(edge.get("distance", 0.0))) / 落重力) 					+ 走路秒(absf(float(edge.get("落点x", edge.get("x", 0.0))) - float(edge.get("x", 0.0))))
	return 0.0

## 一条路线从头走到尾要几秒（`起点x` 是出发时站的 x）。门与排查都用它。
func _路线秒(路线: Array, 起点x: float) -> float:
	var 总 := 0.0
	var 当前x := 起点x
	for act in 路线:
		var a: Dictionary = act
		if String(a.get("type", "")) == "walk":
			总 += 走路秒(absf(float(a.get("x", 0.0)) - 当前x))
			当前x = float(a.get("x", 0.0))
			continue
		总 += 走路秒(absf(float(a.get("x", 0.0)) - 当前x)) + 边耗时秒(a)
		当前x = 落点x(a)
	return 总

## 走过这条边之后，人所在的 x（下一个分量里"从哪开始算走路"）。
func 落点x(edge: Dictionary) -> float:
	if String(edge.get("type", "")) == "jump":
		return float(edge.get("landing_x", edge.get("x", 0.0)))
	return float(edge.get("x", 0.0))

## 原版 `Joint.makeJoints()` 在重叠区间里取的采样点数（写死 5）。
const 采样数 := 5

## 从 `起y` 落到 `落y` 的途中，有没有**别的**脚点横在中间（原版 `Joint.checkBlocked()`：跳过绳梯，
## 逐个看有没有别的 bodyhold 盖住这个 x 且地面 y 落在 (起y, 落y) 之间）。
func _下落被挡(源分量: int, 目标分量: int, x: float, 起y: float, 落y: float) -> bool:
	for 分量 in component_segments:
		if int(分量) == 源分量 or int(分量) == 目标分量:
			continue
		for 段 in component_segments[分量]:
			var 面: float = footholds.ground_y_on(x, 段)
			if 面 == INF:
				continue
			if 面 > 起y + 0.5 and 面 < 落y - 0.5:
				return true
	return false

## 整张图只建一次。原来 `plan()` 每次都 `_build_graph()` —— 实测**这一句就是全部开销**：
## 101010000 7.75 ms/次、木叶村 14.32 ms/次（`plan()` 与它同速），
## 而接近途中每 0.35s 重排一次、每次落地再重排一次 ⇒ 一帧 16.7ms 里塞进半帧到一帧的活，就是"很卡"。
## 地图内脚点/梯子不会变（换图 = 换场景 = 换一个 AutoPathfinder 实例），所以可以一直用。
var _图缓存: Dictionary = {}
var _已建图 := false
## 建图次数 —— 门里用它钉住"缓存真的生效"，比掐时间稳。
var 构建次数 := 0

func 取图() -> Dictionary:
	if not _已建图:
		_图缓存 = _build_graph()
		_已建图 = true
		构建次数 += 1
	return _图缓存

## 脚点/梯子变了（重新 load_map）时的失效入口。
func 重建地图缓存() -> void:
	_图缓存 = {}
	_已建图 = false

func _build_graph() -> Dictionary:
	var graph := {}
	for component in component_segments:
		graph[component] = []
	_add_jump_edges(graph)
	_add_ladder_edges(graph)
	_add_drop_edges(graph)
	return graph

func _add_ladder_edges(graph: Dictionary) -> void:
	if ladder_root == null:
		return
	for ladder in ladder_root.ladders:
		var top := _nearest_platform(float(ladder.x), float(ladder.y1), -1, 100.0)
		var top_component := int(top.get("component", -1))
		var bottom := _nearest_platform(float(ladder.x), float(ladder.y2), top_component, 120.0, true)
		var bottom_component := int(bottom.get("component", -1))
		if top_component < 0 or bottom_component < 0 or top_component == bottom_component:
			continue
		graph[bottom_component].append({
			"type": "climb", "x": float(ladder.x), "direction": -1.0,
			"ladder": ladder, "target_component": top_component
		})
		graph[top_component].append({
			"type": "climb", "x": float(ladder.x), "direction": 1.0,
			"ladder": ladder, "target_component": bottom_component
		})

func _add_jump_edges(graph: Dictionary) -> void:
	const JUMP_SPEED := 666.0
	const GRAVITY := 2000.0
	const MOVE_SPEED := 175.0
	const MAX_JUMP_UP := 104.0
	const MAX_JUMP_DOWN := 160.0
	const EDGE_INSET := 8.0
	for source_component in component_segments:
		var source_bounds := _component_x_bounds(int(source_component))
		for target_component in component_segments:
			if source_component == target_component:
				continue
			var target_bounds := _component_x_bounds(int(target_component))
			var direction := 0
			var takeoff_x := 0.0
			var landing_x := 0.0
			if float(source_bounds.max_x) < float(target_bounds.min_x):
				direction = 1
				takeoff_x = float(source_bounds.max_x) - EDGE_INSET
				landing_x = float(target_bounds.min_x) + EDGE_INSET
			elif float(target_bounds.max_x) < float(source_bounds.min_x):
				direction = -1
				takeoff_x = float(source_bounds.min_x) + EDGE_INSET
				landing_x = float(target_bounds.max_x) - EDGE_INSET
			else:
				# ⭐ **x 区间重叠** —— 这正是"台阶"那一类：两层脚点在水平方向上是叠着的。
				# 原版 `Joint.makeJoints()`（`map/path/Joint.as:290-338`）的最后一支就在这儿建边：
				#   · 源在上方                       → `JUMP_DOWN`（无高度限制）
				#   · 源在下方且高差 ≤ `jumpLength`  → `JUMP_UP`
				# 两档都在**重叠段里取 5 个采样点**各建一条，起跳/落点 x 相同（垂直跳）。
				# ⚠️ 我们原来在这里 `continue` ⇒ 站在台阶下面时**根本没有边**，
				#    只能绕远去找绳子/梯子 —— 用户 2026-10-01 报的"能跳的台阶不跳、绕一大圈"。
				var 重叠左 := maxf(float(source_bounds.min_x), float(target_bounds.min_x))
				var 重叠右 := minf(float(source_bounds.max_x), float(target_bounds.max_x))
				if 重叠左 > 重叠右:
					continue
				var 步 := (重叠右 - 重叠左) / (采样数 + 1.0)
				for k in range(1, 采样数 + 1):
					var 采样x := 重叠左 + 步 * k
					var 起y := _component_surface_at(int(source_component), 采样x)
					var 落y := _component_surface_at(int(target_component), 采样x)
					if 起y == INF or 落y == INF:
						continue
					var 垂直差: float = 落y - 起y
					if 垂直差 > 0.0:
						# 目标在下面：往下跳（原版对 JUMP_DOWN 会查一次中途是否被挡，这里同义）
						if _下落被挡(int(source_component), int(target_component), 采样x, 起y, 落y):
							continue
						# `down` 标记 = 执行侧据此走**穿台下落**（原版 `KeyController.jumpDownTarget()`：
						# `target.y += 5` 后交给重力），**不是向上跳**。少了它 ⇒ 跳起又落回本层、
						# 动作永不推进 ⇒ 原地反复起跳（2026-10-04 用户报"不自己下降平台"）。
						graph[source_component].append({
							"type": "jump", "x": 采样x, "landing_x": 采样x, "direction": 0,
							"flight": sqrt(2.0 * 垂直差 / GRAVITY), "down": true,
							"target_component": int(target_component)
						})
					elif -垂直差 <= MAX_JUMP_UP:
						# 目标在上面且够得着：往上跳（原版这一支**不查**遮挡）
						graph[source_component].append({
							"type": "jump", "x": 采样x, "landing_x": 采样x, "direction": 0,
							"flight": (JUMP_SPEED + sqrt(maxf(0.0, JUMP_SPEED * JUMP_SPEED + 2.0 * GRAVITY * 垂直差))) / GRAVITY,
							"target_component": int(target_component)
						})
				continue
			var source_surface := _component_surface_at(int(source_component), takeoff_x)
			var target_surface := _component_surface_at(int(target_component), landing_x)
			if source_surface == INF or target_surface == INF:
				continue
			var delta_y: float = target_surface - source_surface
			if delta_y < -MAX_JUMP_UP or delta_y > MAX_JUMP_DOWN:
				continue
			var discriminant: float = JUMP_SPEED * JUMP_SPEED + 2.0 * GRAVITY * delta_y
			if discriminant < 0.0:
				continue
			var flight_time: float = (JUMP_SPEED + sqrt(discriminant)) / GRAVITY
			var reachable_x: float = MOVE_SPEED * flight_time
			if absf(landing_x - takeoff_x) > reachable_x:
				continue
			graph[source_component].append({
				"type": "jump", "x": takeoff_x, "landing_x": landing_x,
				"direction": direction, "target_component": int(target_component)
			})

func _component_x_bounds(component: int) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	for segment in component_segments[component]:
		min_x = minf(min_x, minf(float(segment.x1), float(segment.x2)))
		max_x = maxf(max_x, maxf(float(segment.x1), float(segment.x2)))
	return {"min_x": min_x, "max_x": max_x}

func _component_surface_at(component: int, x: float) -> float:
	var best_y := INF
	for segment in component_segments[component]:
		var ground_y: float = footholds.ground_y_on(x, segment, 1.0)
		if ground_y < best_y:
			best_y = ground_y
	return best_y

func _add_drop_edges(graph: Dictionary) -> void:
	for source_component in component_segments:
		var best_by_destination := {}
		for segment in component_segments[source_component]:
			var x_values := [
				lerpf(float(segment.x1), float(segment.x2), 0.25),
				lerpf(float(segment.x1), float(segment.x2), 0.5),
				lerpf(float(segment.x1), float(segment.x2), 0.75)
			]
			for sample_x in x_values:
				var source_y: float = footholds.ground_y_on(float(sample_x), segment)
				var below := _platform_below_component(float(sample_x), source_y, int(source_component))
				var destination := int(below.get("component", -1))
				if destination < 0:
					continue
				var distance := float(below.y) - source_y
				if not best_by_destination.has(destination) or distance < float(best_by_destination[destination].distance):
					best_by_destination[destination] = {
						"type": "drop", "x": float(sample_x), "distance": distance,
						"落点x": float(sample_x), "target_component": destination
					}
		for destination in best_by_destination:
			graph[source_component].append(best_by_destination[destination])

func _nearest_platform(x: float, y: float, excluded_component := -1, max_distance := INF, require_below := false) -> Dictionary:
	var best_distance := INF
	var best := {}
	for segment in footholds.segments:
		var ground_y: float = footholds.ground_y_on(x, segment, 8.0)
		if ground_y == INF or (require_below and ground_y < y - 12.0):
			continue
		var component := get_component(segment.id)
		if component == excluded_component:
			continue
		var distance := absf(ground_y - y)
		if distance <= max_distance and distance < best_distance:
			best_distance = distance
			best = {"component": component, "y": ground_y, "id": segment.id}
	return best

func _platform_below_component(x: float, y: float, excluded_component: int) -> Dictionary:
	var best_y := INF
	var best := {}
	for segment in footholds.segments:
		var component := get_component(segment.id)
		if component == excluded_component:
			continue
		var ground_y: float = footholds.ground_y_on(x, segment)
		if ground_y != INF and ground_y > y + 6.0 and ground_y < best_y:
			best_y = ground_y
			best = {"component": component, "y": ground_y, "id": segment.id}
	return best
