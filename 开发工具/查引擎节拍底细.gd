extends SceneTree

## 一次性查引擎底细：这台机器/这个版本的物理帧率、vsync、有没有官方的"物理插值"口子。
## 纯查询，不碰 user://、不写盘。
## 跑：Godot --path . --script res://开发工具/查引擎节拍底细.gd

func _initialize() -> void:
	print("=== 引擎 ===")
	print("Godot ", Engine.get_version_info().string)
	print("物理帧率 physics_ticks_per_second = ", Engine.get_physics_ticks_per_second())
	print("max_fps = ", Engine.get_max_fps())
	print("")
	print("=== 工程设置里跟节拍有关的键 ===")
	var 键表 := [
		"physics/common/physics_ticks_per_second",
		"physics/common/physics_jitter_fix",
		"physics/common/physics_interpolation",
		"physics/interpolation/enable",
		"physics/interpolation/max_steps",
		"physics/interpolation/allowed_skew",
		"physics/interpolation/angle_limit",
		"rendering/2d/snap/snap_2d_transforms_to_pixel",
		"rendering/2d/snap/snap_2d_vertices_to_pixel",
		"display/window/size/vsync_via_compositor",
		"application/run/max_fps",
	]
	for k in 键表:
		print("  %-52s 存在=%s 值=%s" % [k, ProjectSettings.has_setting(k),
				ProjectSettings.get_setting(k) if ProjectSettings.has_setting(k) else "-"])
	print("")
	print("=== 节点上带 interp/smooth 的属性 ===")
	for 类 in ["CanvasItem", "Node2D", "Camera2D", "AnimatedSprite2D"]:
		var 命中: Array = []
		for p in ClassDB.class_get_property_list(类, true):
			var n: String = String(p.get("name", ""))
			if n.contains("interp") or n.contains("smooth") or n.contains("tick"):
				命中.append(n)
		print("  ", 类, " → ", 命中)
	print("")
	print("=== 当前 vsync ===")
	print("  DisplayServer.window_get_vsync_mode() = ", DisplayServer.window_get_vsync_mode())
	print("  （0=DISABLED 1=ENABLED 2=RELAXED）")
	quit(0)
