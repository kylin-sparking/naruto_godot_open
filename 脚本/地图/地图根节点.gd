extends Node2D

const REPEATING_BACKGROUND_SCRIPT := preload("res://脚本/地图/平铺背景.gd")
## 背景层标记表（`开发工具/识别背景层.py` 生成）。层的**次序与类别不再靠 no/rx 猜**：
##   次序 = 地图数据里的键序，0 在最底 —— 就是原版 `MapRender.drawBack()` 的加入顺序
##          `for each(_loc2_ in this.data.backs) addBack(_loc2_)`，后加的在上。
##   类别 = 纯色底块 / 天空 / 后景，由贴图内容判定（纯色 / 全不透明 / 有透明区）。
const 背景标记路径 := "res://数据/背景层标记.json"
## 手工微调表（**不要**写进自动生成的 背景层标记.json，重跑生成器会覆盖它）。
## 每张图可按类别给「上移 / 缩放 / 居中」，默认全 0/1/关 —— 不影响其它图。
const 背景微调路径 := "res://数据/背景微调.json"
static var _背景微调 := {}

static func _载背景微调() -> void:
	if not _背景微调.is_empty():
		return
	var f := FileAccess.open(背景微调路径, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text().trim_prefix("﻿"))
	if parsed is Dictionary:
		_背景微调 = parsed

## 取某张图、某类别的微调：先与 `_默认` 合并，再被该图的同名键覆盖。
## 有了 `_默认` 就不用给 168 张图各写一遍 —— 例如"所有图的后景一律水平居中"。
func _该图微调(类别: String) -> Dictionary:
	var 默认: Dictionary = ((_背景微调.get("_默认", {}) as Dictionary).get(类别, {}) as Dictionary)
	var 本图: Dictionary = ((_背景微调.get(map_id, {}) as Dictionary).get(类别, {}) as Dictionary)
	if 默认.is_empty():
		return 本图
	var 合 := 默认.duplicate()
	for k in 本图:
		合[k] = 本图[k]
	return 合
static var _背景标记 := {}

static func _载背景标记() -> void:
	if not _背景标记.is_empty():
		return
	var f := FileAccess.open(背景标记路径, FileAccess.READ)
	if f == null:
		push_warning("MapRoot: 读不到 %s，退回按遍历顺序排层" % 背景标记路径)
		return
	var parsed = JSON.parse_string(f.get_as_text().trim_prefix("﻿"))
	if parsed is Dictionary:
		_背景标记 = parsed
	print("MapRoot: 背景层标记表载入 %d 张图" % _背景标记.size())
const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const WEATHER_SCRIPT := preload("res://脚本/地图/天气特效.gd")
const 视野遮罩脚本 := preload("res://脚本/地图/视野遮罩.gd")

# MapRoot: renders the original-style parallax background layers like the Flash
# client's MapBackGroup (factor = 1 + rx/100, vertically anchored to the viewport
# bottom). Groups live in world space, so their world position includes the camera
# position once; Camera2D applies the inverse transform when drawing.
# The sky is a huge ColorRect kept centered on the camera so it always covers
# the viewport.

@export var map_id := "101010000"

const FLASH_BACK_MIN := Vector2(-812.0, -1068.0)

## **有意偏离原版，且只针对天空层**：把 `back no=0` 那层拉伸铺满整图。
## 2.2.3 的背景一律是"固定格子平铺 + 视差跟随"（`MapBackGroup.updatePosition`），
## 没有按地图尺寸的缩放。用户看过两边之后确认**后景的比例本来就是对的**，
## 只有天空要拉满（天空原版就是一张纯色 256x256 平铺，拉满能保证边缘不露底）。
## 后景（no != 0）保持原版口径，关掉 天空拉满 就全部回到原版。
const 天空拉满 := true
## 后景的竖直落点。**已关闭**：把它钉在最低地平面上会导致两个问题 —— 相机抬高时
## 上方露天空（要靠 `_后景铺到顶` 补格），而补格又变成"同一张图上下循环铺满"，
## 用户看到的就是后者（波之国）。原版是**跟着相机竖直走**（`ry=0` → 钉在屏幕底），
## 一行就够覆盖视野、不露也不重复 —— 那才是对的做法。要恢复贴地把它改 true 即可。
## 后景的竖直落点（原版：跟着相机）。
## 最低地平面 = 这张图里最低的一条可站立地面线（脚点段 y1/y2 的最大值）。
## 原版是"跟着相机竖直移动"（`ry=0` 时整层钉在屏幕底），用户要求改成贴地。
const 后景贴最低地面 := false
## 后景比地图矮几个"人物高度"：顶边下移这么多，底边仍贴地图底 —— 于是上方露出天空。
## 一个"人物高度" = 角色贴图高 123px（`Char_00000001_stand_*` 是 70x123，origin.y=122，
## 底边正好落在角色坐标上）。倍数由用户定（"试试低三个人物高度"），不是原版口径。
## 天空与后景**左右各再外扩**这么多（按最终宽的占比）。用户要求"宽过那些装饰物和平台"：
## 先把范围撑到"地图块+物件真正铺到的 x 范围"，再按这个比例多留一点余量。
## 不是原版口径（原版是固定格子平铺 + 视差）。
const 背景外扩比例 := 0.05

var layers := []            # [{group, start_x, start_y, rx, ry}]
## 原版视差基准点：第一层 back 的 (x + 舞台宽/2, y + 舞台高)，见 build_parallax。
var back_start_cam := Vector2.ZERO
## 地图里最低的一条可站立地面线的 y（脚点段 y1/y2 取最大）。后景拿它当底边锚点。
var 最低地平面 := 0.0
var cam_ref: Camera2D = null
var sky_rect: ColorRect = null
var viewport_half := Vector2.ZERO
var vr_left := 0.0
var vr_top := 0.0
var vr_right := 0.0
var vr_bottom := 0.0

func _ready():
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		map_id = str(session.current_map_id)
	# 原版是 World 建好才 playBGM()（World.as:932 开头就判 `if(!this.map) return`），
	# 所以"地图就位"这件事必须由地图自己报给音频，而不是音频在启动时猜。
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.call("on_map_ready", map_id)
	var data: Dictionary = {}
	var info: Dictionary = get_meta("baked_info", {})
	var can_use_baked := get_node_or_null("BakedBackgrounds") != null
	if info.is_empty() or not can_use_baked:
		data = load_json(MAP_RESOURCES.map_data_path(map_id))
		info = data.get("info", {})
	if not can_use_baked:
		var old_sky := get_node_or_null("Sky")
		if old_sky != null:
			old_sky.queue_free()
		var old_backgrounds := get_node_or_null("BakedBackgrounds")
		if old_backgrounds != null:
			old_backgrounds.queue_free()
	vr_left = float(info.get("VRLeft", 0))
	vr_top = float(info.get("VRTop", 0))
	vr_right = float(info.get("VRRight", 0))
	vr_bottom = float(info.get("VRBottom", 0))

	cam_ref = get_node_or_null("WorldCamera")
	if cam_ref is Camera2D:
		viewport_half = get_viewport().get_visible_rect().size * 0.5 / cam_ref.zoom
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	if not restore_baked_static():
		_算最低地平面(data)
		build_sky(data)
		build_parallax(data)
	应用拉满整图()
	_后景铺到顶()
	_重排HUD()
	_挂天气特效()
	_挂视野遮罩()

## 报修 6：把天气特效层挂上（雨雪雾，见 `脚本/地图/天气特效.gd` 的文件头）。
## 用**代码建**而不是写进场景：174 张烘焙场景里没有这个节点，走场景就得全部重烤。
## 层级取 CanvasLayer 10（世界 0 与 小地图面板 20 之间）—— 节点自己设。
func _挂天气特效() -> void:
	if get_node_or_null("天气特效") != null:
		return
	var 节 := WEATHER_SCRIPT.new()
	节.name = "天气特效"
	add_child(节)

## 蜡烛视野（见 `脚本/地图/视野遮罩.gd` 的文件头）。原版 `World.tickCandleEffect():445-470`
## 只认 403000000，别的图连节点都不建。
func _挂视野遮罩() -> void:
	if map_id != "403000000" or get_node_or_null("视野遮罩") != null:
		return
	var 节 := 视野遮罩脚本.new()
	节.name = "视野遮罩"
	add_child(节)

func restore_baked_static() -> bool:
	var baked_sky := get_node_or_null("Sky") as ColorRect
	var baked_layers := get_node_or_null("BakedBackgrounds")
	if baked_sky == null or baked_layers == null:
		return false
	sky_rect = baked_sky
	# 视差基准点 = **第一层 back**（按 key 排序后的第一层，与原版/参照一致）
	# 的 (x + 舞台宽/2, y + 舞台高)。烘焙产物只存了对齐后的 start_x/start_y，
	# 反推不出原始 x/y，所以这里回读一次地图数据。
	var map_data = load_json(MAP_RESOURCES.map_data_path(map_id))
	_算最低地平面(map_data)
	var back_table: Dictionary = map_data.get("back", {})
	var back_keys: Array = back_table.keys()
	back_keys.sort_custom(func(a, b): return int(a) < int(b) if str(a).is_valid_int() and str(b).is_valid_int() else str(a) < str(b))
	if not back_keys.is_empty():
		var first = back_table[back_keys[0]]
		if first is Dictionary:
			back_start_cam = Vector2(float(first.get("x", 0)) + 480.0, float(first.get("y", 0)) + 560.0)
	print("MapRoot: 视差基准=(%.0f,%.0f) 最低地平面=%.0f" % [back_start_cam.x, back_start_cam.y, 最低地平面])
	for group in baked_layers.get_children():
		if not group is Node2D:
			continue
		layers.append({
			"group": group,
			"no": int(group.get_meta("no", -1)),
			"次序": int(group.get_meta("bg_order", layers.size())),
			"类别": String(group.get_meta("bg_kind", "后景")),
			"start_x": float(group.get_meta("start_x", 0.0)),
			"start_y": float(group.get_meta("start_y", 0.0)),
			"rx": float(group.get_meta("rx", 0.0)),
			"ry": float(group.get_meta("ry", 0.0))
		})
	_应用微调()
	print("MapRoot: using %d baked background layers 类别=%s" % [
		layers.size(), layers.map(func(L): return "%d:%s" % [L.get("次序", -1), L.get("类别", "?")])])
	return true

## 把各层背景摆成"铺满整图、钉在世界坐标上不动"。
## 按 天空拉满 的开关，把天空层设成"铺满、不参与视差"；后景不动，留给 `_process`。
func 应用拉满整图() -> void:
	if not 天空拉满:
		return
	var 地图 := Rect2(vr_left, vr_top, vr_right - vr_left, vr_bottom - vr_top)
	if 地图.size.x <= 0.0 or 地图.size.y <= 0.0:
		push_warning("MapRoot: 地图 VR 矩形为空，背景拉满整图跳过")
		return
	# 先撑到"地图块+物件真正铺到的 x 范围"（烘焙时记在 baked_content_* 上），
	# 再按比例多留余量 —— 只按 VR 外扩是不够的，实测 411000000 的装饰物比 VR 左右各多
	# 1793 / 1572 px，木叶村也多 142 px。
	var 左 := 地图.position.x
	var 右 := 地图.end.x
	if has_meta("baked_content_left"):
		左 = minf(左, float(get_meta("baked_content_left")))
		# 装饰物锚点还要往左再铺一个图块宽，这里按经验留 1/4 屏幕宽
		左 -= viewport_half.x * 0.5
	if has_meta("baked_content_right"):
		右 = maxf(右, float(get_meta("baked_content_right")))
		右 += viewport_half.x * 0.5
	var 外扩 := (右 - 左) * 背景外扩比例
	# 竖直方向也留出余量：拉满层原本正好等于地图 VR 高度，相机贴到上下边界时
	# 只要有一点取整/越界（用户就见过"地图上方天空没铺满"），就会露出一条底。
	# 天空/纯色底块本来是拉伸的纯色/云彩，多铺半屏不会有任何观感差别。
	var 竖外扩 := viewport_half.y
	var 矩形 := Rect2(左 - 外扩, 地图.position.y - 竖外扩,
		(右 - 左) + 外扩 * 2.0, 地图.size.y + 竖外扩 * 2.0)
	var 拉满数 := 0
	for L in layers:
		var 组 = L.get("group")
		if 组 == null:
			continue
		if not 天空拉满:
			continue
		# 拉满"天空"和"纯色底块"两类；后景留给 `_process` 按原版的平铺 + 视差摆。
		# 纯色底块必须一起拉满：它是垫底的那张纯色，不铺满就会在天空/后景都没盖到的地方
		# 露出一块深蓝（原版 2.2.3 也有这个毛病，用户要求修掉）。
		var 类别 := String(L.get("类别", ""))
		if 类别 != "天空" and 类别 != "纯色底块":
			组.set("拉满整图", false)
			continue
		组.set("拉满整图", true)
		组.set("整图矩形", 矩形)
		组.position = 矩形.position
		组.queue_redraw()
		拉满数 += 1
	print("MapRoot: 天空 %d 层拉满 → %s；其余 %d 层按原版平铺+视差（地图 VR 为 %s）" % [
		拉满数, 矩形, layers.size() - 拉满数, 地图])

## 最低地平面 = 脚点段里 y 的最大值（y 向下为正，所以最大 y 就是最低的那条地面）。
## 竖直线段（x1==x2）是崖边，不算地面。
func _算最低地平面(data: Dictionary) -> void:
	var 最低 := -INF
	for 层 in data.get("foothold", {}).values():
		for 组 in 层.values():
			for 段 in 组.values():
				if float(段.get("x1", 0)) == float(段.get("x2", 0)):
					continue
				最低 = maxf(最低, float(段.get("y1", 0)))
				最低 = maxf(最低, float(段.get("y2", 0)))
	if is_finite(最低):
		最低地平面 = 最低
	else:
		最低地平面 = float((data.get("info", {}) as Dictionary).get("VRBottom", 0))

## 一层背景的内容在竖直方向、从组原点到"最下沿"的距离。
## 平铺类（type 2/3/5/6/7）要算上向下铺的格数；非平铺类就只有半格。
##
## ⚠️ 别在这里"强制竖直铺满"来让后景盖到地图顶 —— 试过，会把 type=0 的单张图
## 整体推到屏幕外（整组被压下去 N 格）。后景该铺几行就是几行。
func _内容下半高(L: Dictionary) -> float:
	var 组 = L.get("group")
	if 组 == null:
		return 0.0
	var 格高: float = float(组.get("cell_size").y) * float(组.get("缩放")) * float(组.get("纵向缩放"))
	if 格高 <= 0.0:
		return 0.0
	return float(int(组.get("tile_radius").y)) * 格高 + 格高 * 0.5

## 后景必须**从最低地平面往上铺到地图顶**。
##
## 为什么：`后景贴最低地面` 把后景钉在最低地平面上，但原版它们是**跟着相机竖直走**的
## （`ry=0` → 整层钉在屏幕底），所以永远盖住视野。一旦改成贴地，只铺一行的话，
## 玩家站高一点、相机一抬，上方就只剩天空 —— 火之国就是这么"看不到后景"的。
##
## ⚠️ 之前撤过一次这个改动，当时误判成"它把 type=0 的单张图推出屏幕"；那一例的真因是
## `build_parallax` 里 `type=0` 也做了 x 对齐（已修）。别再把它当成坑。
func _后景铺到顶() -> void:
	if not 后景贴最低地面:
		return
	var 高 := maxf(1.0, 最低地平面 - vr_top)
	for L in layers:
		if String(L.get("类别", "")) != "后景":
			continue
		var 组 = L.get("group")
		if 组 == null:
			continue
		var 格高: float = float(组.get("cell_size").y) * float(组.get("缩放")) * float(组.get("纵向缩放"))
		if 格高 <= 0.0:
			continue
		# 对称铺 i∈[-r..r]，覆盖 ±(r+0.5)*格；要让上沿够到地图顶，取 r = ceil(高/格 - 0.5)
		var 需 := maxi(ceili(高 / 格高 - 0.5), 0)
		组.set("竖直铺满", true)
		组.set("tile_radius", Vector2i(int(组.get("tile_radius").x), 需))
		组.queue_redraw()   # 改了格子数要重画，否则 _draw 还是按旧参数画的

func load_json(p):
	var f = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var txt = f.get_as_text()
	f.close()
	if txt.begins_with("\ufeff"):
		txt = txt.substr(1)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func build_sky(data):
	# back no=0 is a solid-color sky in the original (no bitmap); a huge rect
	# that follows the camera acts as the sky/backdrop. Anchored to the camera
	# every frame so it never leaves a gap at the bottom/edges.
	sky_rect = ColorRect.new()
	sky_rect.name = "Sky"
	sky_rect.color = compute_sky_color(data)
	sky_rect.z_index = -1000
	sky_rect.z_as_relative = false
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_rect.size = Vector2(40000, 40000)
	sky_rect.position = -sky_rect.size * 0.5
	add_child(sky_rect)

func build_parallax(data):
	_载背景标记()
	_载背景微调()
	var 标记表: Dictionary = {}
	# ⚠️ Godot 的 JSON 把数字解析成 float，`str(项["键"])` 会得到 "0.0" 而不是 "0"，
	# 查表永远查不中（踩过一次：类别全落到默认值"后景"）。必须过一遍 int()。
	for 项 in (_背景标记.get(map_id, {}) as Dictionary).get("层", []):
		标记表[str(int(项.get("键", -1)))] = 项
	var back = data.get("back", {})
	var 层序 := 0
	# 视差基准：**按 key 排序后的第一层** back 的 (x + 舞台宽/2, y + 舞台高)。
	# 不用字典遍历顺序碰运气 —— 顺序变了基准就变，背景会整层错位。
	var 有序键: Array = back.keys()
	有序键.sort_custom(func(a, b): return int(a) < int(b) if str(a).is_valid_int() and str(b).is_valid_int() else str(a) < str(b))
	if not 有序键.is_empty() and typeof(back[有序键[0]]) == TYPE_DICTIONARY:
		var b0: Dictionary = back[有序键[0]]
		back_start_cam = Vector2(float(b0.get("x", 0)) + 480.0, float(b0.get("y", 0)) + 560.0)
	for key in back.keys():
		var ld: Dictionary = back[key]
		if typeof(ld) != TYPE_DICTIONARY:
			continue
		var no = int(ld.get("no", -1))
		var tex = load_back_texture(no, data)
		if tex == null:
			print("MapRoot: back no=%d -> no usable texture (skipped)" % no)
			continue
		var rx = float(ld.get("rx", 0))
		var ry = float(ld.get("ry", 0))
		var type = int(ld.get("type", 0)) % 8
		var dx = float(ld.get("x", 0))
		var dy = float(ld.get("y", 0))
		var alpha = float(ld.get("a", 255)) / 255.0
		var flip = int(ld.get("f", 0)) != 0
		# Optional per-layer scale: a source PNG upscaled for crispness (e.g. 4x)
		# must be displayed at 1/scale so it keeps the original on-screen size.
		var tex_scale = float(ld.get("scale", 1.0))
		var cell_w = float(tex.get_width()) * tex_scale
		var cell_h = float(tex.get_height()) * tex_scale

		# 起点对齐**按 type 分开**，依据 2.2.3 `MapBackGroup.as` 四个 draw 分支：
		#   drawNormal(0)       L176: startX = data.x             startY = data.y        ← 都不对齐
		#   drawHorizontal(1,4) L72:  startX = 对齐后的 x          startY = data.y        ← 只对齐 x
		#   drawVertical(2,5)   L211: startX = data.x             startY = 对齐后的 y     ← 只对齐 y
		#   drawFullScreen(3,6,7) L142: 两个都对齐
		# 旧实现"x 恒对齐"——对 type 0/2/5 是错的：木叶村 type=0 那层（no=1）
		# align(0,-812,1199) 得 -1199，整层左移 1199px 跑出画面，那块就只剩天空。
		var start_x = dx
		var start_y = dy
		if type == 1 or type == 3 or type == 4 or type == 6 or type == 7:
			start_x = align(dx, FLASH_BACK_MIN.x, cell_w)
		if type == 2 or type == 3 or type == 5 or type == 6 or type == 7:
			start_y = align(dy, FLASH_BACK_MIN.y, cell_h)

		var group := Node2D.new()
		group.set_script(REPEATING_BACKGROUND_SCRIPT)
		group.name = "Back%d" % no
		# 次序与类别都查标记表；查不到（新图还没重跑识别脚本）才退回按遍历顺序。
		var 标记: Dictionary = 标记表.get(str(key), {})
		var 次序 := int(标记.get("次序", 层序))
		var 类别 := String(标记.get("类别", "后景"))
		group.z_index = -100 + 次序
		group.set_meta("bg_kind", 类别)   # 元数据键用 ASCII：中文键名不会被场景序列化保住
		group.z_as_relative = false
		add_child(group)

		# 每层每帧要画几格：**按视野算，不按地图算**，而且取刚好够覆盖的最小格数。
		# `平铺背景.gd` 把格子画在 `i*格 - 格/2`，所以 i ∈ [-r..r] 覆盖的是
		#   ±(r + 0.5) * 格
		# 要盖住视野半径 vh，只需 (r + 0.5) * 格 >= vh，即 r = ceil(vh/格 - 0.5)。
		# 这里**不留额外余量**（原来是 +1 格）—— 用户要求再压小；边界机位已逐张验过不露边。
		# 旧写法 `ceil((vh + 格)/格) + 1` 每边多画 2 格多 —— 木叶村 256 的天空层
		# 就是 9×9 = 81 格（再早按地图算是 29×15 = 435 格），每帧白画。
		var tiles_x = ceili(viewport_half.x / cell_w - 0.5)
		var tiles_y = ceili(viewport_half.y / cell_h - 0.5)
		# 下限是 **0 不是 1**：r=0 就是"只画 1 格"，覆盖 ±0.5*格；格子本身比视野宽时
		# 这一格就够了。写成 maxi(...,1) 会白画成 3×3 = 9 格。
		tiles_x = maxi(tiles_x, 0)
		tiles_y = maxi(tiles_y, 0)
		group.configure(tex, type, Vector2(cell_w, cell_h), Vector2i(tiles_x, tiles_y), alpha, flip)

		var 微调: Dictionary = _该图微调(类别)
		group.set("缩放", float(微调.get("缩放", 1.0)))
		group.set("纵向缩放", float(微调.get("纵向缩放", 1.0)))
		layers.append({"group": group, "start_x": start_x, "start_y": start_y, "rx": rx, "ry": ry,
			"no": no, "次序": 次序, "类别": 类别,
			"上移": float(微调.get("上移", 0.0)), "居中": bool(微调.get("居中", false))})
		层序 += 1
		print("MapRoot: back no=%d 次序=%d 类别=%s type=%d tex=%dx%d start=(%.0f,%.0f) rx=%.0f ry=%.0f z=%d" % [
			no, 次序, 类别, type, int(cell_w), int(cell_h), start_x, start_y, rx, ry, group.z_index])

## 微调只改**位置**（缩放由 `平铺背景.gd` 画的时候用），所以放在读表之后、摆位之前。
func _应用微调() -> void:
	_载背景微调()
	for L in layers:
		var 类别 := String(L.get("类别", ""))
		var 微调: Dictionary = _该图微调(类别)
		if 微调.is_empty():
			continue
		var 组 = L.get("group")
		if 组 == null:
			continue
		组.set("缩放", float(微调.get("缩放", 1.0)))
		组.set("纵向缩放", float(微调.get("纵向缩放", 1.0)))
		L["上移"] = float(微调.get("上移", 0.0))
		L["居中"] = bool(微调.get("居中", false))
		if bool(L.get("居中", false)):
			# ⚠️ 居中的层**不再跟着相机走**，横向格子数不能再按"视野"算（那只够盖住
			# 相机附近），必须按**整张地图宽度**算，否则相机走到地图边上就露空。
			var 格宽 := float(组.get("cell_size").x) * float(组.get("缩放"))
			if 格宽 > 0.0:
				var 需 := ceili(((vr_right - vr_left) * 0.5) / 格宽 - 0.5)
				组.set("tile_radius", Vector2i(maxi(需, int(组.get("tile_radius").x)),
					int(组.get("tile_radius").y)))
	print("MapRoot: 背景微调 map=%s 默认=%s 本图=%s" % [
		map_id, _背景微调.get("_默认", {}), _背景微调.get(map_id, "（无）")])

func align(v, minv, cell):
	# original: v - ceil((v - minv) / cell) * cell
	return v - ceili((v - minv) / cell) * cell

func ceili(x):
	return int(ceil(x))

func compute_sky_color(data):
	var back = data.get("back", {})
	for key in back.keys():
		var ld: Dictionary = back[key]
		if typeof(ld) == TYPE_DICTIONARY and int(ld.get("no", -1)) == 0:
			var tex = load_back_texture(int(ld.get("no", -1)), data)
			if tex != null and tex.get_width() > 2:
				var img = tex.get_image()
				if img != null:
					return img.get_pixel(0, 0)
			break
	return Color(0.2, 0.4, 0.8)

func load_back_texture(no, data):
	var bS = "unknown"
	var back = data.get("back", {})
	for key in back.keys():
		var ld: Dictionary = back[key]
		if typeof(ld) == TYPE_DICTIONARY:
			bS = String(ld.get("bS", bS))
			break
	for ext in ["png", "jpg"]:
		var file_name := "Back_%s_back_%d.%s" % [bS, no, ext]
		var path := MAP_RESOURCES.find_asset(map_id, "背景", file_name)
		if path.is_empty():
			continue
		var texture = load(path)
		if texture is Texture2D and texture.get_width() > 2 and texture.get_height() > 2:
			return texture
	return null

func _on_viewport_size_changed() -> void:
	if cam_ref is Camera2D:
		viewport_half = get_viewport().get_visible_rect().size * 0.5 / cam_ref.zoom
	_重排HUD()


## HUD 重排 —— **照原版 `UIMain2.resize()`（`UIMain2.as:3372-3475`）逐条搬**。
##
## 原版的模型（2026-09-27 用户纠正两次才定下来）：
## `Config.STAGE_WIDTH/HEIGHT` **只是默认值**，`Game.as:76-93` 的 `onResizeHandler`
## 会把它设成**真实窗口尺寸**（钳到 600~2000 / 400~1200），然后调 `ui.resize()` ——
## **UI 不缩放、只重排**：元素各自锚到真实舞台的某条边/中线，尺寸恒定。
## 所以窗口变大 = 地图多露出来 + HUD 分布到四周，而不是整块画布被放大。
##
## ⚠️ 别改成 `stretch/mode="canvas_items"` 去"放大省事" —— 那是把位图放大，素材会糊，
##    而且原版从不这么干（§3.54 记过这次返工）。
##
## AS3 原文 → 我们节点的对照（只搬这台客户端有的那几个）：
##   `chatPane`        y = H - 266（x 不动）              → 聊天面板
##   `menuPane`        x = (W - w) >> 1, y = H - h       → 技能面板（底部居中）
##   `smallMapWindow`  x = W - w, y = 0                  → 小地图面板（右上）
##   `noticePnl`       x = W - 250, y = H - 125          → 系统消息（右下）
##   `charactorInfoPane` **不在 resize 里** —— 原版就不动它 → 头像面板保持左上原位
func _重排HUD() -> void:
	var 视口 := get_viewport().get_visible_rect().size
	var 配对 := [
		["技能面板", "menuPane", "底部居中"],
		["小地图面板", "smallMapWindow", "右上"],
		["系统消息", "noticePnl", "右下"],
		["聊天面板", "chatPane", "左下"],
	]
	for 项 in 配对:
		var 节 := get_node_or_null(String(项[0])) as Control
		if 节 == null:
			continue
		match String(项[2]):
			"底部居中":
				节.position = Vector2(int(视口.x - 节.size.x) >> 1, 视口.y - 节.size.y)
			"右上":
				节.position = Vector2(视口.x - 节.size.x, 0.0)
			"右下":
				节.position = Vector2(视口.x - 250.0, 视口.y - 125.0)
			"左下":
				节.position = Vector2(节.position.x, 视口.y - 266.0)

func _process(_dt):
	if cam_ref == null:
		return
	var stage_size := get_viewport().get_visible_rect().size
	var canvas_inv := get_viewport().get_canvas_transform().affine_inverse()
	var effective_center := canvas_inv * (stage_size * 0.5)
	var cam_x := effective_center.x
	var cam_bottom := effective_center.y + viewport_half.y
	if sky_rect != null:
		sky_rect.global_position = effective_center - sky_rect.size * 0.5
	for L in layers:
		var 组 = L.get("group")
		if 组 != null and bool(组.get("拉满整图")):
			continue   # 这层被拉满铺死了，不参与视差
		# 落点（世界空间）。2.2.3 的 render_frame.py 画在**屏幕空间**，公式是
		#     gx_screen = startCamX + startX + (camCx - startCamX) * rx/100
		# 而本项目的背景组是**世界空间**节点（见文件头注释），屏幕坐标要再加一次相机矩形原点：
		#     gx_world = gx_screen + (camCx - 舞台宽/2)
		#              = startX + camCx + (camCx - 舞台宽/2) * rx/100      ← 化简后即下式
		# 两者等价，**不要**把屏幕空间的公式直接搬过来：那样会少掉一次相机位移，
		# 把 rx≠0 的层（如木叶村的火影岩壁）整层推出屏幕。
		# 基准点必须是**本图第一层 back 的 (x + 舞台宽/2, y + 舞台高)**（原版
		# `MapRender.as:349` 的 startCameraX/Y），**不是写死的 (480,560)**。全地图里有
		# 5 张（112010000/112020000/112030000/112040000/411000000）的 backs[0].y = -600，
		# 即 startCameraY = -40 —— 写死 560 会让这 5 张的竖直视差整整差 600px。
		var dx := cam_x - back_start_cam.x
		var dy := cam_bottom - back_start_cam.y
		var gx = L.start_x + cam_x + dx * (L.rx / 100.0)
		var gy = L.start_y + cam_bottom + dy * (L.ry / 100.0)
		if 后景贴最低地面:
			# 底边贴最低地平面，往上铺。横向仍走原版的公式。
			gy = 最低地平面 - _内容下半高(L)
		if float(L.get("上移", 0.0)) != 0.0:
			gy -= float(L.get("上移"))
		if bool(L.get("居中", false)):
			# `平铺背景.gd` 是把格子**以组原点为中心**画的（cell_origin = i*格 - 格/2），
			# 所以组原点就是格子中心，居中只需把组原点摆到地图中心。
			# （减半宽是错的：那会把整张图再右移半张。）
			gx = (vr_left + vr_right) * 0.5
		L.group.position = Vector2(gx, gy)
