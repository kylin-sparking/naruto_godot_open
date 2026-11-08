extends SceneTree

## 查"物理插值"在 4.7.2 上到底挂在哪个口子：ProjectSettings 键 / SceneTree 属性 / Node 属性。
## 纯查询，不碰 user://。
## 跑：Godot --path . --script res://开发工具/查插值口子.gd

func _dump(类: String, 词: Array) -> void:
	var 命中: Array = []
	for p in ClassDB.class_get_property_list(类, true):
		var n: String = String(p.get("name", ""))
		for w in 词:
			if n.contains(w):
				命中.append(n)
				break
	print("  ", 类, " 属性 → ", 命中)
	var 方: Array = []
	for m in ClassDB.class_get_method_list(类, true):
		var n: String = String(m.get("name", ""))
		for w in 词:
			if n.contains(w):
				方.append(n)
				break
	print("  ", 类, " 方法 → ", 方)


func _initialize() -> void:
	for 类 in ["Node", "CanvasItem", "Node2D", "Camera2D", "SceneTree"]:
		_dump(类, ["interp", "physics"])
	print("=== 候选项目设置键 ===")
	for k in ["physics/common/physics_interpolation",
			"physics/interpolation/enable",
			"physics/2d/run_on_render_thread"]:
		print("  ", k, " 存在=", ProjectSettings.has_setting(k))
	quit(0)
