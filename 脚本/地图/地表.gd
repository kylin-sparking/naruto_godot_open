extends Node2D

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")

# Loads foothold (collision line segments) data for a map. Generic version.
# Coordinates are Y-down (same as Flash / Godot), map x/y used as-is.

@export var map_id := "101010000"

var segments := []
var id_map := {}   # String(id) -> {x1,y1,x2,y2,prev,next,id}
var map_bounds := Rect2()
var spawn_point := Vector2.ZERO
## 原版 `MapData.floor` = **连通脚点链编号**（`MapData.as:392-440`：从每段开始沿 next 走完、
## 再沿 prev 走完，同一条链同号）。⚠ 不是 JSON 顶层的 `layer`：那是渲染层（`ALayerManager` 的下标），
## 木叶村/巢穴之巅这类图整张都是 1 ⇒ 拿它当"层"会把上下两层平台判成同层（10-26 挂机爬梯死循环）。
var _地面号表 := {}
var _地面号已建 := false

func _ready():
	map_id = GameSession.current_map_id
	if not restore_baked_data():
		load_map(MAP_RESOURCES.map_data_path(map_id))

func restore_baked_data() -> bool:
	if not has_meta("baked_segments"):
		return false
	segments.clear()
	for segment_data in get_meta("baked_segments", []):
		if segment_data is Dictionary:
			segments.append(segment_data.duplicate(true))
	map_bounds = get_meta("baked_map_bounds", Rect2())
	spawn_point = get_meta("baked_spawn_point", Vector2.ZERO)
	id_map.clear()
	for segment in segments:
		id_map[str(segment.get("id", ""))] = segment
	_地面号表.clear()
	_地面号已建 = false
	print("Footholds: using %d baked segments; bounds %s; spawn %s" % [segments.size(), map_bounds, spawn_point])
	return true

func load_map(p: String):
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		push_error("Footholds: cannot open " + p)
		return
	var txt = f.get_as_text()
	f.close()
	if txt.begins_with("\ufeff"):
		txt = txt.substr(1)
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Footholds: bad json " + p)
		return

	var info = data.get("info", {})
	var left = float(info.get("VRLeft", 0))
	var top = float(info.get("VRTop", 0))
	var right = float(info.get("VRRight", 0))
	var bottom = float(info.get("VRBottom", 0))
	map_bounds = Rect2(left, top, right - left, bottom - top)

	segments.clear()
	id_map.clear()
	var fh = data.get("foothold", {})
	for i1 in fh:
		var d1: Dictionary = fh[i1]
		for i2 in d1:
			var d2: Dictionary = d1[i2]
			for fid in d2:
				var s: Dictionary = d2[fid]
				var sid = str(int(s.get("id", fid)))
				var seg = {
					"x1": float(s["x1"]), "y1": float(s["y1"]),
					"x2": float(s["x2"]), "y2": float(s["y2"]),
					"id": sid,
					"prev": str(int(s.get("prev", -1))),
					"next": str(int(s.get("next", -1))),
					# 原版 `MapData.as:360` 把 foothold 的**顶层键**记成 index1，角色
					# 的前后层次就是按它进 `ALayerManager.getALayer(index1)`。丢了这一项，
					# 角色就只能用 y 猜层次 —— 那正是"走上去陷进地面"的来源。
					"layer": int(i1)
				}
				segments.append(seg)
				id_map[sid] = seg
	_地面号表.clear()
	_地面号已建 = false
	# spawn point: prefer standing on a ground platform near the horizontal
	# center (same as the demo's main city), so the player starts ON the ground
	# rather than at a high/empty portal location. Fall back to the map's
	# spawn portal, then to the map center.
	spawn_point = compute_center_spawn()
	if spawn_point == Vector2.ZERO:
		var portal = data.get("portal", {})
		for key in portal:
			var pd: Dictionary = portal[key]
			if int(pd.get("pt", 0)) == -1:
				spawn_point = Vector2(float(pd["x"]), float(pd["y"]))
				break
	if spawn_point == Vector2.ZERO:
		spawn_point = map_bounds.get_center()

	print("Footholds: loaded ", segments.size(), " segments; bounds ", map_bounds, "; spawn ", spawn_point)

# Pick the platform whose surface is visually closest to a map click. This
# distinguishes stacked floors that share the same horizontal screen area.
func find_click_target(point: Vector2) -> Dictionary:
	var best_distance := INF
	var best := {"y": INF, "id": ""}
	for segment in segments:
		var ground_y := _ground_y_on(point.x, segment, 6.0)
		if ground_y == INF:
			continue
		var distance := absf(ground_y - point.y)
		if distance < best_distance:
			best_distance = distance
			best = {"y": ground_y, "id": segment.id}
	return best

func are_connected(from_id: String, to_id: String) -> bool:
	if from_id == "" or to_id == "" or not id_map.has(from_id) or not id_map.has(to_id):
		return false
	var pending := [from_id]
	var visited := {}
	while not pending.is_empty():
		var candidate_id: String = pending.pop_back()
		if candidate_id == to_id:
			return true
		if visited.has(candidate_id) or not id_map.has(candidate_id):
			continue
		visited[candidate_id] = true
		var segment: Dictionary = id_map[candidate_id]
		for linked_id in [segment.prev, segment.next]:
			if linked_id != "" and linked_id != "0" and linked_id != "-1" and not visited.has(linked_id):
				pending.append(linked_id)
	return false


## 原版 `MapData.floor`：一条**走得通的连续地面**一个号（`MapData.as:392-440` 沿 next 走完再沿 prev 走完）。
## 只按 `prev/next` 连通，**不经梯子/跳点** ⇒ 上下两层平台天然不同号。
## 同号 = 挂机可以走过去打；不同号 = 中间隔着梯子/跳台，挂机不许锁。
func 连通地面号(脚点id: String) -> int:
	if 脚点id == "" or not id_map.has(脚点id):
		return -1
	if not _地面号已建:
		_地面号已建 = true
		_地面号表.clear()
		var 号 := 0
		for 段 in segments:
			var 起 := String((段 as Dictionary).get("id", ""))
			if 起 == "" or _地面号表.has(起):
				continue
			var 待 := [起]
			while not 待.is_empty():
				var 当前 := String(待.pop_back())
				if _地面号表.has(当前) or not id_map.has(当前):
					continue
				_地面号表[当前] = 号
				var 条: Dictionary = id_map[当前]
				for 邻 in [条.get("prev"), 条.get("next")]:
					var 邻号 := String(邻)
					if 邻号 != "" and 邻号 != "0" and 邻号 != "-1" and not _地面号表.has(邻号):
						待.append(邻号)
			号 += 1
	return int(_地面号表.get(脚点id, -1))

func find_platform_below(x: float, feet_y: float, current_id: String) -> Dictionary:
	var best_y := INF
	var best_id := ""
	for segment in segments:
		if current_id != "" and are_connected(current_id, segment.id):
			continue
		var ground_y := _ground_y_on(x, segment)
		if ground_y != INF and ground_y > feet_y + 3.0 and ground_y < best_y:
			best_y = ground_y
			best_id = segment.id
	return {"y": best_y, "id": best_id}

# Follow only the foothold currently under the player and its directly linked
# neighbors. Grounded movement uses this so slopes are followed in both
# directions without falling through to a lower, unrelated platform.
func find_connected_ground(x: float, cur_id: String) -> Dictionary:
	if cur_id == "" or not id_map.has(cur_id):
		return {"y": INF, "id": ""}
	var candidates := [cur_id]
	var current: Dictionary = id_map[cur_id]
	for linked_id in [current.prev, current.next]:
		if linked_id != "" and linked_id != "0" and linked_id != "-1":
			candidates.append(linked_id)
	var best_y := INF
	var best_id := ""
	for candidate_id in candidates:
		if not id_map.has(candidate_id):
			continue
		var segment: Dictionary = id_map[candidate_id]
		var ground_y := _ground_y_on(x, segment, 0.5)
		if ground_y != INF and ground_y < best_y:
			best_y = ground_y
			best_id = candidate_id
	return {"y": best_y, "id": best_id}

# Neighbor-aware lookup: first checks the segment the player is currently
# standing on (cur_id) and its prev/next-connected neighbors. This lets the
# player walk smoothly across segment joints (shared endpoints) without the
# 1-frame gap/stutter that a global search can produce at platform edges.
func find_foothold(x: float, feet_y: float, cur_id: String) -> Dictionary:
	var best := INF
	var best_id := ""
	var cands := []
	if cur_id != "" and id_map.has(cur_id):
		cands.append(cur_id)
		var cs = id_map[cur_id]
		if cs.prev != "" and cs.prev != "-1":
			cands.append(cs.prev)
		if cs.next != "" and cs.next != "-1":
			cands.append(cs.next)
	for cid in cands:
		if not id_map.has(cid):
			continue
		var s = id_map[cid]
		var gy = _ground_y_on(x, s)
		if gy != INF and gy >= feet_y - 1.0 and gy < best:
			best = gy
			best_id = cid
	if best != INF:
		return {"y": best, "id": best_id}
	# Fallback: full scan (used when airborne / first landing).
	for s in segments:
		var gy = _ground_y_on(x, s)
		if gy != INF and gy >= feet_y - 1.0 and gy < best:
			best = gy
			best_id = s.id
	if best == INF:
		return {"y": INF, "id": ""}
	return {"y": best, "id": best_id}

## 原版 `AbstractPhysicObject.checkFoothold():373-389`：离地时拿**这一帧的位移向量**与每一条
## **非竖直**脚点做 `GVector.findIntersection():108-136`，第一条相交的就把人放到交点上、
## `grounded/landed = true`、竖直速度清 0。
## 为什么不能继续只靠 `find_foothold(x, 前y, ...)`：它按**落点那一列**取面，再用 `gy >= 前y-1`
## 过滤 —— 斜坡一帧内抬升超过 1px 时，脚已经从上方面穿到下方，那 1 像素容差却把这一面判掉，
## 人便从斜坡里穿下去、落到下面的平台（用户 2026-11-02 报的「移动跳跃时跳到当前平台下面，
## 一般是有斜坡的地方」；基础走速 175 下全图实测 23 个点会中，例见门里 100010000 段15）。
## 判据逐条照 AS3：
##   · `dot(位移, 法线) < 0`（朝可走面去；上升/横移不认）；
##   · `dot(起点-脚点起点, 法线) <= 0`（起点在面的背面一侧，不能从下面往上接）；
##   · 交点参数 t/u 都落在 [0,1]（只认这一帧线段上、脚点范围内的交点）。
## 多条相交取 t 最小（离起点最近）；原版按数据顺序 break，两者只会在"一帧同时穿过两层"时不同。
func 扫掠落点(起: Vector2, 终: Vector2) -> Dictionary:
	var mvx := 终.x - 起.x
	var mvy := 终.y - 起.y
	if mvx == 0.0 and mvy == 0.0:
		return {}
	var 最近t := INF
	var 最近id := ""
	var 最近点 := Vector2.ZERO
	for 段 in segments:
		if float(段.x1) == float(段.x2):
			continue					# 竖墙走 `玩家._空中撞墙` 那一支
		# 原版 `Foothold.vector = GVector((x2,y2),(x1,y1))`（`Foothold.as:36`）
		var ax := float(段.x2)
		var ay := float(段.y2)
		var fvx := float(段.x1) - ax
		var fvy := float(段.y1) - ay
		if fvx == 0.0 and fvy == 0.0:
			continue
		var 长 := sqrt(fvx * fvx + fvy * fvy)
		# 法线方向 (rx, ry) = (-vy, vx)；AS3 拿**归一化后的方向**点乘位移
		var nx := -fvy / 长
		var ny := fvx / 长
		if mvx * nx + mvy * ny >= 0.0:
			continue
		var sx := ax - 起.x
		var sy := ay - 起.y
		if sx * nx + sy * ny > 0.0:
			continue
		var 分母 := mvx * fvy - mvy * fvx	# perP(位移, 脚点)
		if 分母 == 0.0:
			continue
		var t := (sx * fvy - sy * fvx) / 分母
		if t < 0.0 or t > 1.0:
			continue
		var u := ((起.x - ax) * mvy - (起.y - ay) * mvx) / -分母
		if u < 0.0 or u > 1.0:
			continue
		if t < 最近t:
			最近t = t
			最近id = String(段.id)
			最近点 = 起 + Vector2(mvx, mvy) * t
	if 最近id == "":
		return {}
	return {"x": 最近点.x, "y": 最近点.y, "id": 最近id}

func ground_y_on(x: float, segment: Dictionary, endpoint_epsilon := 0.0) -> float:
	return _ground_y_on(x, segment, endpoint_epsilon)

## 沿 `脚点id` 那一段平移到 `目标x`（夹在段的两端之内）之后的落脚点。
## 这是原版 `MapDataHelper.getRushPositionInfo()` 在"不跨段、只沿当前落脚点平移"
## 这一档的等价物 —— 双修对坐摆位（`HealHandler.as:424`）只要这一种走法。
## 回 `(INF, INF)` 表示这个脚点查无（调用方自己决定不动）。
func 段上落点(脚点id: String, 目标x: float) -> Vector2:
	var 段: Dictionary = id_map.get(脚点id, {})
	if 段.is_empty():
		return Vector2(INF, INF)
	var x := clampf(目标x, minf(float(段.x1), float(段.x2)), maxf(float(段.x1), float(段.x2)))
	return Vector2(x, _ground_y_on(x, 段))

## 原版 `AbstractPhysicObject.checkAbyss():722-736` 的第二半：`mapData.helper.getLowestYByX(x)`
## = 这一列**最低的那块水平地面**。数据来自 `MapData.processFootholds():79-147` 的 `lowest`
## 列表（按 y 从深到浅扫，被更深的段完全盖住 x 区间的段不再入选）＋
## `PathHelper.getLowestFoothold():47-72`（在覆盖该 x 的段里取 y 最大的一段）。
## 直接对所有水平段取「覆盖该 x 的最大 y」与那套剪枝等价：被盖住的段一定更浅，不可能赢。
## 竖墙（x1 == x2）不是地面，原版 `isVertical` 也把它们排除在外。
## 回 INF = 这一列没有水平地面（例如地图左右两侧的空档）。
func 最低地面y(x: float) -> float:
	var 最低 := -INF
	for 段 in segments:
		if float(段.x1) == float(段.x2):
			continue
		var gy := _ground_y_on(x, 段)
		if gy != INF and gy > 最低:
			最低 = gy
	return 最低 if 最低 != -INF else INF

func _ground_y_on(x: float, s: Dictionary, endpoint_epsilon := 0.0) -> float:
	var minx = min(s.x1, s.x2)
	var maxx = max(s.x1, s.x2)
	if x < minx - endpoint_epsilon or x > maxx + endpoint_epsilon:
		return INF
	var t = 0.0
	if s.x2 != s.x1:
		var sample_x := clampf(x, minx, maxx)
		t = (sample_x - s.x1) / (s.x2 - s.x1)
	return s.y1 + t * (s.y2 - s.y1)

## 角色在这个脚点上的 z_index。
## 原版：角色进 `ALayer[脚点层号]`，层内排在该层**所有地形之后**，角色之间按 foothodY
## （= 所站脚点的 y1）排。见 `RenderProfile` 里 世界层带 那段注释。
## 上一次解析出来的层号。角色**离地时**（`current_fh_id` 为空 —— 跳跃/爬梯/爬绳途中）
## 必须沿用离地前那一层；否则会退回层 0，被上一层（比如木叶村的层 2 街景）的装饰物盖住。
## 原版也是这个语义：`AbstractPhysicObject.currFoothold` 为空时用的是 `oldFoothold`
## 和 `_foothodY`（上次的值），不是从头算。
var _上次层号 := 0
var _上次脚点y := 0.0

func 角色z(脚点id: String, 兜底y: float) -> int:
	var 段: Dictionary = id_map.get(脚点id, {})
	if 段.is_empty():
		return RenderProfile.角色z(_上次层号, _层内序(_上次脚点y))
	_上次层号 = int(段.get("layer", 0))
	_上次脚点y = float(段.get("y1", 兜底y))
	var 层 := int(段.get("layer", 0))
	return RenderProfile.角色z(层, _层内序(float(段.get("y1", 兜底y))))

func _层内序(脚下y: float) -> int:
	var 顶 := map_bounds.position.y
	var 高 := maxf(1.0, map_bounds.size.y)
	return clampi(int((脚下y - 顶) / 高 * 255.0), 0, 255)

func get_spawn() -> Vector2:
	if spawn_point != Vector2.ZERO:
		return spawn_point
	if segments.is_empty():
		return map_bounds.get_center()
	var cx = map_bounds.get_center().x
	var best = segments[0]
	var best_score = INF
	for s in segments:
		var mx = (s.x1 + s.x2) * 0.5
		var seg_my = (s.y1 + s.y2) * 0.5
		var d = abs(mx - cx)
		if d > 600:
			continue
		var score = d * 0.001 + seg_my
		if score < best_score:
			best_score = score
			best = s
	var spawn_y = (best.y1 + best.y2) * 0.5
	return Vector2((best.x1 + best.x2) * 0.5, spawn_y - 80)

func compute_center_spawn() -> Vector2:
	if segments.is_empty():
		return map_bounds.get_center()
	var cx = map_bounds.get_center().x
	# Pick the main ground platform: within 600px of horizontal center and as
	# low (large y) as possible. This lands the player on the main floor rather
	# than a high platform (which would look empty / far from the action).
	var best = segments[0]
	var best_my = -INF
	for s in segments:
		var mx = (s.x1 + s.x2) * 0.5
		var segment_y = (s.y1 + s.y2) * 0.5
		var d = abs(mx - cx)
		if d > 600:
			continue
		if segment_y > best_my:
			best_my = segment_y
			best = s
	var spawn_y = (best.y1 + best.y2) * 0.5
	return Vector2((best.x1 + best.x2) * 0.5, spawn_y - 80)
