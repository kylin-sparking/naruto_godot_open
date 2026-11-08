extends Node2D

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const OBJECT_Z_MIN := -99
const OBJECT_Z_MAX := 99
const OBJECT_FPS := 5

var map_id := "101010000"

func _ready() -> void:
	if get_node_or_null("/root/GameSession") != null:
		map_id = str(get_node("/root/GameSession").current_map_id)
	if get_child_count() == 0:
		load_objects()
	else:
		print("ObjectRoot: using %d baked objects for map %s" % [get_child_count(), map_id])

func load_objects() -> void:
	var file := FileAccess.open(MAP_RESOURCES.object_data_path(map_id), FileAccess.READ)
	if file == null:
		push_warning("Object layout missing for map %s" % map_id)
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Array:
		push_error("Invalid object layout for map %s" % map_id)
		return

	var loaded := 0
	for value in data:
		if not value is Dictionary:
			continue
		var object: Dictionary = value
		var base := "Obj_%s_%s_%s_%s" % [object.get("oS", ""), object.get("l0", ""), object.get("l1", ""), int(object.get("l2", 0))]
		var folder := MAP_RESOURCES.find_asset_directory(map_id, "地图物件", base)
		var frames := _collect_frames(folder, base)
		if frames.is_empty():
			continue

		var flip := bool(object.get("flip", false))
		var x := float(object.get("x", 0.0))
		var y := float(object.get("y", 0.0))
		var ox := float(object.get("ox", 0.0))
		var oy := float(object.get("oy", 0.0))
		var layer := int(object.get("layer", 0))
		var local_z := clampi(int(object.get("z", 0)), OBJECT_Z_MIN, OBJECT_Z_MAX)
		var z := RenderProfile.物件z(layer, local_z)

		var node: Node2D
		if frames.size() == 1:
			var sprite := Sprite2D.new()
			sprite.texture = frames[0]
			sprite.centered = false
			node = sprite
		else:
			# Multiple frames -> play them as a looping animation (butterflies,
			# waterfalls, bubbling pots, etc.).
			var anim := AnimatedSprite2D.new()
			anim.centered = false
			var sf := SpriteFrames.new()
			# SpriteFrames already ships with a "default" animation in Godot 4,
			# so just add frames to it instead of re-adding the animation.
			for fr in frames:
				sf.add_frame("default", fr)
			sf.set_animation_speed("default", OBJECT_FPS)
			anim.frames = sf
			anim.play("default")
			node = anim

		if node is Sprite2D:
			node.flip_h = flip
		elif node is AnimatedSprite2D:
			node.flip_h = flip
		if flip:
			var logical_width := 0.0
			if frames[0] is Texture2D:
				logical_width = frames[0].get_width()
			node.position = Vector2(x + ox - logical_width, y - oy)
		else:
			node.position = Vector2(x - ox, y - oy)
		node.z_index = z
		node.name = base
		add_child(node)
		loaded += 1
	print("ObjectRoot: loaded %d/%d objects for map %s" % [loaded, data.size(), map_id])

# Collect every animation frame for an object. Frame files are named
# "<base>_<n>.<ext>" (n = 0,1,2,...). A lone "<base>.<ext>" (no number) is
# treated as frame 0 when no explicit _0 file exists, matching the exporter's
# output for single-frame objects.
func _collect_frames(folder: String, base: String) -> Array:
	var result := {}
	var dir := DirAccess.open(folder)
	if dir == null:
		return []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			# Frame files are named "<base>_<n>.<ext>" (n = digits). A lone
			# "<base>.<ext>" (no number) is handled below as frame 0.
			if fname.begins_with(base + "_") and _is_frame_ext(fname):
				var body := fname.substr(base.length() + 1)  # text after "base_"
				var dot := body.rfind(".")
				if dot > 0:
					var num_str := body.substr(0, dot)
					if num_str.is_valid_int():
						var p := folder.path_join(fname)
						var tex := load(p) as Texture2D
						if tex != null:
							var n := num_str.to_int()
							if not result.has(n):
								result[n] = tex
		fname = dir.get_next()
	dir.list_dir_end()
	if not result.has(0):
		for ext in ["png", "jpg", "jpeg"]:
			var p := "%s/%s.%s" % [folder, base, ext]
			if FileAccess.file_exists(p):
				var tex := load(p) as Texture2D
				if tex != null:
					result[0] = tex
				break
	var out := []
	var keys := result.keys()
	keys.sort()
	for k in keys:
		out.append(result[k])
	return out

func _is_frame_ext(fname: String) -> bool:
	return fname.ends_with(".png") or fname.ends_with(".jpg") or fname.ends_with(".jpeg")
