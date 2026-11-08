extends SceneTree
# 一次性诊断器：把 `场景/界面/窗口/家族/` 下所有 .tscn 逐个 `load()`，报能不能解析。
# 为什么单独一道：`.tscn` 里写错属性形式（例：`Color("#HEX",1,1,1)` 在 GDScript 合法、
# 在 tscn 的变量解析里只认四个数）会让 `instantiate()` **静默返回 null** ——
# 页面整块不出现、还不崩，最容易骗过"跑起来了"这种判断。
# 跑法：Godot --path . --headless --script res://开发工具/试载入家族场景.gd

const 目录 := "res://场景/界面/窗口/家族/"


func _initialize() -> void:
	var 红 := 0
	for 名 in Array(DirAccess.get_files_at(目录)):
		var 文件 := String(名)
		if not 文件.ends_with(".tscn"):
			continue
		var r: Resource = ResourceLoader.load(目录.path_join(文件))
		var 页: PackedScene = r as PackedScene
		var 根 := 页.instantiate() if 页 != null else null
		if 根 == null:
			红 += 1
			print("FAIL " + 文件)
		else:
			print("OK   %-28s %d 节点" % [文件, 根.get_child_count()])
			根.free()
	print("家族场景解析门：红 %d" % 红)
	quit(1 if 红 > 0 else 0)
