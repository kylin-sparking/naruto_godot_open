extends Node2D

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const GAME_DATA := preload("res://脚本/单例/游戏数据.gd")
const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const EFFECT_PLAYER := preload("res://脚本/表现/特效播放器.gd")

const PORTAL_Z_INDEX := 4000
const PORTAL_LABEL_Z_INDEX := 4001
# 原来这里手抄过两组逐帧 origin（PORTAL_PV_ORIGINS / PORTAL_PH_ORIGINS，8 + 7 个 Vector2）。
# 它们的值与 Etc.effects.portalPV/portalPH 里每帧的 origin 逐字节一致 —— 但那是抄的，
# 现在由 数据/特效.json 提供，特效播放器按同一份真值钉位。

var map_id := "101010000"
var portals: Array[Dictionary] = []

func _ready() -> void:
	map_id = GameSession.current_map_id
	# ⚠️ 原来这里写的是 `map_id == "101010000" and has_meta("baked_portals")` —— 那是个
	#    **按内容特例**的分支（§3.28.1 第 1 条禁的那类）。已改成和兄弟脚本一致的**能力判断**：
	#      `地表`/`攀爬物`/`地图块`/`地图物件` 全都是 `has_meta(...)` / `get_node_or_null(...)`，
	#      没有一处看 map_id。这里是唯一的例外。
	#    安全性：烘焙器写 `baked_portals` 的来源就是 `地图.json` 的 `portal` 段
	#    （`烘焙当前地图.gd:145-151`），与下面的 `load_portals()` 兜底路**算法逐行相同**
	#    （都遍历 `portal`、加 `index`、筛 `pt in [2,7,10]`）→ **等价是构造性的**。
	#    168/168 张烘焙产物都有这个 meta，所以改完所有图都走烘焙路（本来就是烘焙器的意图）。
	if has_meta("baked_portals"):
		portals.clear()
		for portal_data in get_meta("baked_portals", []):
			if portal_data is Dictionary:
				portals.append(portal_data.duplicate(true))
		var rendered_count := 0
		for portal in portals:
			if int(portal.get("pt", -1)) in [2, 7, 10] and create_portal_render(portal):
				rendered_count += 1
		print("PortalRoot: using %d baked portals, rendered %d" % [portals.size(), rendered_count])
	else:
		load_portals()

func load_portals() -> void:
	var path := MAP_RESOURCES.map_data_path(map_id)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("PortalRoot: cannot read " + path)
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var raw = data.get("portal", {})
	var rendered_count := 0
	for key in raw:
		var d: Dictionary = raw[key].duplicate()
		d["index"] = int(key)
		portals.append(d)
		if int(d.get("pt", -1)) in [2, 7, 10]:
			if create_portal_render(d):
				rendered_count += 1
	print("PortalRoot: loaded %d portals, rendered %d" % [portals.size(), rendered_count])

func create_portal_render(portal: Dictionary) -> bool:
	var pt := int(portal.get("pt", -1))
	# 帧数（垂直 8 / 水平 7）、每帧 250ms、逐帧 origin 都在 数据/特效.json 里（源：Etc.effects.portalPV/portalPH）。
	# 原来这里是 3 处手抄：frame_count 三元、set_animation_speed 4.0（=250ms）、两组 origin 表。
	var effect_key := "portalPH" if pt == 10 else "portalPV"
	if not EFFECT_PLAYER.has_effect(effect_key):
		return false
	var animation := EFFECT_PLAYER.new()
	animation.position = Vector2(float(portal.get("x", 0)), float(portal.get("y", 0)))
	animation.z_index = PORTAL_Z_INDEX
	add_child(animation)
	animation.play(effect_key)

	if pt in [2, 7]:
		var label := Label.new()
		label.text = _target_map_name(portal)
		label.position = Vector2(float(portal.get("x", 0)) - 80.0, float(portal.get("y", 0)) + 8.0)
		label.size = Vector2(160.0, 18.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("#c8f0a0"))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 皮肤表.文字规则_描边数值)
		label.z_index = PORTAL_LABEL_Z_INDEX
		add_child(label)
	return true

## 原版传送门下方显示目标地图名；tm 从 JSON 读出来是浮点，先转整再补零查表
func _target_map_name(portal: Dictionary) -> String:
	var target_id := int(portal.get("tm", 0))
	if target_id <= 0:
		return ""
	var padded := str(target_id).pad_zeros(9)
	var display := GAME_DATA.map_name(padded)
	if display == padded:
		display = GAME_DATA.map_name(str(target_id))
	return "" if display == str(target_id) else display

func get_entry_position(portal_name: String) -> Vector2:
	var fallback := Vector2.ZERO
	for portal in portals:
		if str(portal.get("pn", "")) == portal_name:
			return Vector2(float(portal.get("x", 0)), float(portal.get("y", 0)) - 5.0)
		if str(portal.get("pn", "")) == "sp":
			fallback = Vector2(float(portal.get("x", 0)), float(portal.get("y", 0)) - 5.0)
	return fallback

func get_portal_at(world_position: Vector2) -> Dictionary:
	for portal in portals:
		if int(portal.get("pt", -1)) not in [2, 7, 10]:
			continue
		var portal_position := Vector2(float(portal.get("x", 0)), float(portal.get("y", 0)))
		if world_position.distance_to(portal_position) < 20.0:
			return portal
	return {}

func enter_portal(portal: Dictionary) -> bool:
	# 原来这里放 `play_effect("portal")`（自造 wav）—— 原版进门没有音效，按"原版没有的不许加"删掉。
	var pt := int(portal.get("pt", -1))
	if pt in [2, 7]:
		# 在线模式下换图必须由服务端授权：它校验门、决定落点，再用 WARP 帧驱动场景重载
		# （见 游戏会话.apply_backend_map_state）。原先这里直接调本地的
		# GameSession.request_map_change，只换了客户端场景、从不通知服务端——
		# 结果服务端仍认为玩家在旧地图，实体/掉落/战斗全对不上。
		var backend := get_node_or_null("/root/BackendConnection")
		if backend != null and backend.in_game and backend.request_portal_enter(int(portal.get("index", -1))):
			return true
		# 离线示例（没有在线会话）退回本地换图。
		GameSession.request_map_change(str(int(portal.get("tm", 0))), str(portal.get("tn", "sp")))
		return true
	if pt == 10:
		var target_name := str(portal.get("tn", ""))
		for target in portals:
			if str(target.get("pn", "")) == target_name:
				var player := get_tree().get_first_node_in_group("player")
				if player != null:
					player.position = Vector2(float(target.get("x", 0)), float(target.get("y", 0)) - 5.0)
				return true
	return false
