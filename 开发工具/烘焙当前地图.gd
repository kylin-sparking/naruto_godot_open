extends SceneTree

const DEFAULT_MAP_ID := "101010000"
const SOURCE_SCENE := "res://场景/地图/地图场景.tscn"
const OUTPUT_DIR := "res://场景/生成"
const MAP_ROOT_SCRIPT := preload("res://脚本/地图/地图根节点.gd")
const TILE_ROOT_SCRIPT := preload("res://脚本/地图/地图块.gd")
const OBJECT_ROOT_SCRIPT := preload("res://脚本/地图/地图物件.gd")
const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const STATIC_BATCH_SCRIPT := preload("res://脚本/地图/静态绘制批次.gd")
const AVATAR_PANEL_SCENE := preload("res://场景/界面/头像面板.tscn")
const MINIMAP_PANEL_SCENE := preload("res://场景/界面/小地图面板.tscn")
const CHAT_PANEL_SCENE := preload("res://场景/界面/聊天面板.tscn")
const SKILL_PANEL_SCENE := preload("res://场景/界面/技能面板.tscn")
const SYSTEM_MESSAGE_SCENE := preload("res://场景/界面/组件/系统消息.tscn")
const PERFORMANCE_PROBE_SCRIPT := preload("res://脚本/调试/性能探针.gd")
const CHUNK_SIZE := 1024.0
## 10：背景组新增 no 元数据（认天空/后景靠它，不再靠节点名）。
## 9：z 改成"层带 512 + 层内 物件→瓦片→角色"三段（`RenderProfile`）。
const BAKE_VERSION := "10"

func _initialize() -> void:
	var requested := DEFAULT_MAP_ID
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		requested = str(args[0])
	var error := bake_all_maps() if requested == "--all" else bake_map(requested)
	if error == ERR_SKIP:
		error = OK
	if error != OK:
		push_error("BakeMaps: failed with error %d" % error)
	quit(error)

func bake_all_maps() -> Error:
	var ids: Array[String] = []
	for map_id in MAP_RESOURCES.map_ids():
		if FileAccess.file_exists(_tiles_path(map_id)) and FileAccess.file_exists(_objects_path(map_id)):
			ids.append(map_id)
	var baked := 0
	var skipped := 0
	for map_id in ids:
		var result := bake_map(map_id, true)
		if result == ERR_SKIP:
			skipped += 1
		elif result != OK:
			return result
		else:
			baked += 1
	print("BakeMaps: complete discovered=%d baked=%d unchanged=%d" % [ids.size(), baked, skipped])
	return OK

func bake_map(map_id := DEFAULT_MAP_ID, incremental := false) -> Error:
	var output_path := _output_path(map_id)
	var bake_hash := _compute_bake_hash(map_id)
	if bake_hash.is_empty():
		return ERR_FILE_CORRUPT
	if incremental and _is_current(output_path, bake_hash):
		print("BakeMaps: unchanged, skipped map " + map_id)
		return ERR_SKIP
	var source := load(SOURCE_SCENE) as PackedScene
	if source == null:
		return ERR_CANT_OPEN
	var root := source.instantiate()
	root.name = "地图_%s_烘焙" % map_id
	root.map_id = map_id
	root.set_meta("bake_hash", bake_hash)
	root.set_meta("bake_version", BAKE_VERSION)
	_ensure_shared_nodes(root)
	var map_data := _load_json(_map_path(map_id))
	if map_data.is_empty():
		root.free()
		return ERR_FILE_CORRUPT
	bake_gameplay_data(root, map_data)
	bake_backgrounds(root, map_id, map_data)
	bake_tiles(root, map_id)
	bake_objects(root, map_id)
	set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		root.free()
		return pack_error
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var save_error := ResourceSaver.save(packed, output_path)
	var node_count := _count_nodes(root)
	root.free()
	if save_error == OK:
		print("BakeMaps: saved %s nodes=%d" % [output_path, node_count])
	return save_error

func _ensure_shared_nodes(root: Node) -> void:
	var old_hud := root.get_node_or_null("HudRoot")
	if old_hud != null:
		old_hud.queue_free()
	var panels := {
		"头像面板": AVATAR_PANEL_SCENE,
		"小地图面板": MINIMAP_PANEL_SCENE,
		"聊天面板": CHAT_PANEL_SCENE,
		"技能面板": SKILL_PANEL_SCENE,
		"系统消息": SYSTEM_MESSAGE_SCENE,
	}
	for panel_name in panels:
		if root.get_node_or_null(panel_name) == null:
			var panel: Node = panels[panel_name].instantiate()
			panel.name = panel_name
			root.add_child(panel)
	if root.get_node_or_null("PerformanceProbe") == null:
		var probe := Node.new()
		probe.name = "PerformanceProbe"
		probe.set_script(PERFORMANCE_PROBE_SCRIPT)
		root.add_child(probe)

func bake_gameplay_data(root: Node, data: Dictionary) -> void:
	var info: Dictionary = data.get("info", {}).duplicate(true)
	root.set_meta("baked_info", info)
	var footholds := root.get_node("Footholds")
	var segments: Array = []
	# 键名必须与 `脚本/地图/地表.gd` 的 load_map 保持一致（layer 是原版的 index1，
	# 角色层次靠它），改一边不改另一边就会静默退化成"只有层 0"。
	for level_one_key in data.get("foothold", {}):
		for level_two in data["foothold"][level_one_key].values():
			for fallback_id in level_two:
				var source: Dictionary = level_two[fallback_id]
				segments.append({
					"x1": float(source.get("x1", 0)), "y1": float(source.get("y1", 0)),
					"x2": float(source.get("x2", 0)), "y2": float(source.get("y2", 0)),
					"id": str(int(source.get("id", fallback_id))),
					"prev": str(int(source.get("prev", -1))), "next": str(int(source.get("next", -1))),
					"layer": int(level_one_key)})
	var bounds := Rect2(float(info.get("VRLeft", 0)), float(info.get("VRTop", 0)),
		float(info.get("VRRight", 0)) - float(info.get("VRLeft", 0)),
		float(info.get("VRBottom", 0)) - float(info.get("VRTop", 0)))
	var spawn := _compute_spawn(segments, bounds, data.get("portal", {}))
	footholds.set_meta("baked_segments", segments)
	footholds.set_meta("baked_map_bounds", bounds)
	footholds.set_meta("baked_spawn_point", spawn)

	var ladders: Array = []
	for source in data.get("ladderRope", {}).values():
		ladders.append({"x": float(source.get("x", 0)), "y1": float(source.get("y1", 0)),
			"y2": float(source.get("y2", 0)), "is_ladder": int(source.get("l", 0)) == 1,
			"page": int(source.get("page", 0))})
	root.get_node("LadderRoot").set_meta("baked_ladders", ladders)

	var portals: Array = []
	var raw_portals: Dictionary = data.get("portal", {})
	for key in raw_portals:
		var portal: Dictionary = raw_portals[key].duplicate(true)
		portal["index"] = int(key)
		portals.append(portal)
	root.get_node("PortalRoot").set_meta("baked_portals", portals)
	print("BakeMaps: gameplay footholds=%d ladders=%d portals=%d spawn=%s" % [segments.size(), ladders.size(), portals.size(), spawn])

func bake_backgrounds(root: Node, map_id: String, data: Dictionary) -> void:
	root.set_meta("baked_info", data.get("info", {}).duplicate(true))
	var helper := MAP_ROOT_SCRIPT.new()
	helper.map_id = map_id
	root.add_child(helper)
	# 从 渲染配置 读，避免与 project.godot 的视口尺寸分叉。960x560 → (480, 280)
	helper.viewport_half = Vector2(RenderProfile.DESIGN_SIZE) * 0.5
	var info: Dictionary = data.get("info", {})
	helper.vr_left = float(info.get("VRLeft", 0))
	helper.vr_top = float(info.get("VRTop", 0))
	helper.vr_right = float(info.get("VRRight", 0))
	helper.vr_bottom = float(info.get("VRBottom", 0))
	helper.build_sky(data)
	helper.sky_rect.reparent(root)
	var backgrounds := Node2D.new()
	backgrounds.name = "BakedBackgrounds"
	root.add_child(backgrounds)
	helper.build_parallax(data)
	var layer_count := helper.layers.size()
	for layer_data in helper.layers:
		var group: Node2D = layer_data.group
		group.set_meta("no", int(layer_data.get("no", -1)))
		group.set_meta("bg_order", int(layer_data.get("次序", 0)))
		group.set_meta("bg_kind", String(layer_data.get("类别", "后景")))
		group.set_meta("start_x", layer_data.start_x)
		group.set_meta("start_y", layer_data.start_y)
		group.set_meta("rx", layer_data.rx)
		group.set_meta("ry", layer_data.ry)
		group.reparent(backgrounds)
	helper.free()
	print("BakeMaps: backgrounds=%d draw_nodes=%d" % [layer_count, backgrounds.get_child_count()])

func bake_tiles(root: Node, map_id: String) -> void:
	var tile_root := root.get_node("TileRoot")
	_clear_children(tile_root)
	var data = _load_json_array(_tiles_path(map_id))
	var helper := TILE_ROOT_SCRIPT.new()
	helper.map_id = map_id
	var batches := {}
	var missing := 0
	for value in data:
		if not value is Dictionary:
			continue
		var tile: Dictionary = value
		var texture := helper.load_tile_tex(str(tile.get("tS", "")), str(tile.get("u", "")), int(tile.get("no", 0)))
		if texture == null:
			missing += 1
			continue
		var position := Vector2(float(tile.get("x", 0)) - float(tile.get("ox", 0)), float(tile.get("y", 0)) - float(tile.get("oy", 0)))
		var z := RenderProfile.瓦片z(int(tile.get("layer", 0)), TILE_ROOT_SCRIPT.瓦片描述符z(str(tile.get("tS", "")), str(tile.get("u", "")), int(tile.get("no", 0))))
		_add_to_batch(batches, texture, position, false, z)
		_记录内容x(position.x)
	helper.free()
	_emit_batches(tile_root, batches, "TileBatch")
	_写内容范围(root)
	print("BakeMaps: tiles=%d batches=%d missing=%d" % [data.size(), batches.size(), missing])

func bake_objects(root: Node, map_id: String) -> void:
	var object_root := root.get_node("ObjectRoot")
	_clear_children(object_root)
	var helper := OBJECT_ROOT_SCRIPT.new()
	helper.map_id = map_id
	var data = _load_json_array(_objects_path(map_id))
	var batches := {}
	var static_count := 0
	var animated_count := 0
	for value in data:
		if not value is Dictionary:
			continue
		var object: Dictionary = value
		var base := "Obj_%s_%s_%s_%s" % [object.get("oS", ""), object.get("l0", ""), object.get("l1", ""), int(object.get("l2", 0))]
		var folder := MAP_RESOURCES.find_asset_directory(map_id, "地图物件", base)
		var frames := helper._collect_frames(folder, base)
		if frames.is_empty():
			continue
		var flip := bool(object.get("flip", false))
		var ox := float(object.get("ox", 0))
		var position := Vector2(float(object.get("x", 0)) - ox, float(object.get("y", 0)) - float(object.get("oy", 0)))
		if flip:
			position.x = float(object.get("x", 0)) + ox - float(frames[0].get_width())
		# z 口径与运行时共用 RenderProfile，别在这里再写一个 2000/512（改一处漏一处）。
		var z := RenderProfile.物件z(int(object.get("layer", 0)), clampi(int(object.get("z", 0)), -99, 99))
		if frames.size() == 1:
			_add_to_batch(batches, frames[0], position, flip, z)
			static_count += 1
		else:
			var animation := AnimatedSprite2D.new()
			animation.name = base
			animation.centered = false
			animation.position = position
			animation.flip_h = flip
			animation.z_index = z
			var sprite_frames := SpriteFrames.new()
			for frame in frames:
				sprite_frames.add_frame("default", frame)
			sprite_frames.set_animation_speed("default", 5.0)
			animation.sprite_frames = sprite_frames
			animation.play("default")
			object_root.add_child(animation)
			animated_count += 1
	helper.free()
	_emit_batches(object_root, batches, "ObjectBatch")
	_写内容范围(root)
	print("BakeMaps: objects static=%d animated=%d batches=%d" % [static_count, animated_count, batches.size()])

## 地图块/物件的 x 最大范围。背景要"宽过装饰物和平台"，就得知道它们真正铺到哪 ——
## 实测最夸张的 411000000 比 VR 左右各多出 1793 / 1572 px，按 VR 或按固定比例外扩都不够。
var _内容左 := INF
var _内容右 := -INF

func _记录内容x(x: float) -> void:
	_内容左 = minf(_内容左, x)
	_内容右 = maxf(_内容右, x)

func _写内容范围(root: Node) -> void:
	if not is_finite(_内容左) or not is_finite(_内容右):
		return
	root.set_meta("baked_content_left", _内容左)
	root.set_meta("baked_content_right", _内容右)

func _add_to_batch(batches: Dictionary, texture: Texture2D, position: Vector2, flip: bool, z: int) -> void:
	var chunk := Vector2i(floori(position.x / CHUNK_SIZE), floori(position.y / CHUNK_SIZE))
	var key := "%d:%d:%d" % [z, chunk.x, chunk.y]
	if not batches.has(key):
		batches[key] = {"z": z, "chunk": chunk, "items": []}
	batches[key].items.append({"texture": texture, "position": position, "flip": flip})

func _emit_batches(parent: Node, batches: Dictionary, prefix: String) -> void:
	var keys := batches.keys()
	keys.sort()
	for key in keys:
		var data: Dictionary = batches[key]
		var batch := Node2D.new()
		batch.set_script(STATIC_BATCH_SCRIPT)
		batch.name = "%s_%s" % [prefix, key.replace(":", "_")]
		batch.z_index = clampi(
			int(data.z),
			RenderingServer.CANVAS_ITEM_Z_MIN,
			RenderingServer.CANVAS_ITEM_Z_MAX
		)
		batch.z_as_relative = false
		for item in data.items:
			batch.add_item(item.texture, item.position, item.flip)
		parent.add_child(batch)

func _compute_spawn(segments: Array, bounds: Rect2, raw_portals: Dictionary) -> Vector2:
	if not segments.is_empty():
		var center_x := bounds.get_center().x
		var best: Dictionary = segments[0]
		var best_y := -INF
		for segment in segments:
			var midpoint_x := (float(segment.x1) + float(segment.x2)) * 0.5
			var midpoint_y := (float(segment.y1) + float(segment.y2)) * 0.5
			if absf(midpoint_x - center_x) <= 600.0 and midpoint_y > best_y:
				best = segment
				best_y = midpoint_y
		return Vector2((float(best.x1) + float(best.x2)) * 0.5, (float(best.y1) + float(best.y2)) * 0.5 - 80.0)
	for portal in raw_portals.values():
		if int(portal.get("pt", 0)) == -1:
			return Vector2(float(portal.get("x", 0)), float(portal.get("y", 0)))
	return bounds.get_center()

func _compute_bake_hash(map_id: String) -> String:
	return 计算烘焙哈希(map_id)

## 输入清单的口径同上，但**必须是 static**：`测试/地图烘焙回归测试.gd` 要用它复核
## 「盘上这份烘焙产物的哈希，跟当前这些源文件算出来的是不是同一个」。
## 不是 static 就得 `MAP_BAKER.new()` 才调得到，而那是第二个 SceneTree —— 门里造它很危险。
static func 计算烘焙哈希(map_id: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(BAKE_VERSION.to_utf8_buffer())
	for path in [
		_map_path(map_id),
		_tiles_path(map_id),
		_objects_path(map_id),
		"res://数据/地图素材索引.json",
		SOURCE_SCENE,
		"res://场景/界面/头像面板.tscn",
		"res://场景/界面/小地图面板.tscn",
		"res://场景/界面/聊天面板.tscn",
		"res://场景/界面/技能面板.tscn",
		"res://脚本/界面/头像面板.gd",
		"res://脚本/界面/小地图面板.gd",
		"res://脚本/界面/聊天面板.gd",
		"res://脚本/界面/技能面板.gd",
		"res://场景/界面/组件/系统消息.tscn",
		"res://脚本/界面/系统消息.gd",
		# 下面这些直接决定产物里节点的属性（z 口径、背景分层的字段），
		# 不列进来改了就不会重烘，产物里还留着旧值 —— 排查时会被
		# "代码明明改了却没效果"骗一整轮（这坑踩过一次了）。
		"res://脚本/调试/渲染配置.gd",
		"res://脚本/地图/地图根节点.gd",
		"res://脚本/地图/地图块.gd",
		"res://脚本/地图/地图物件.gd",
		"res://脚本/地图/平铺背景.gd",
		"res://数据/背景层标记.json",
		"res://数据/地图块描述符z.json",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("BakeMaps: missing input " + path)
			return ""
		context.update(file.get_buffer(file.get_length()))
	return context.finish().hex_encode()

func _is_current(path: String, expected_hash: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return 'metadata/bake_hash = "%s"' % expected_hash in file.get_as_text()

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
	return parsed if parsed is Dictionary else {}

func _load_json_array(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text().trim_prefix("\ufeff"))
	return parsed if parsed is Array else []

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()

func set_owner_recursive(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		# 嵌套场景必须保留为实例引用；递归改写其后代 owner 会把 UI
		# 展开成烘焙时的静态快照，之后 UI 节点层级更新便无法生效。
		if child.scene_file_path.is_empty():
			set_owner_recursive(child, scene_root)

func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total

## 这三条只拼路径、不碰实例状态，所以必须是 static：
## `计算烘焙哈希()` 要能被 `测试/地图烘焙回归测试.gd` 用脚本名直接调
## （不是 static 就得在门里 `new()` 出第二个 SceneTree，而且 4.7 会**整份编译失败**）。
static func _map_path(map_id: String) -> String:
	return MAP_RESOURCES.map_data_path(map_id)

static func _tiles_path(map_id: String) -> String:
	return MAP_RESOURCES.tile_data_path(map_id)

static func _objects_path(map_id: String) -> String:
	return MAP_RESOURCES.object_data_path(map_id)

func _output_path(map_id: String) -> String:
	return "%s/地图_%s_烘焙.tscn" % [OUTPUT_DIR, map_id]
