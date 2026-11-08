extends SceneTree

## 查 DisplayServer 里到底哪个方法能读刷新率（4.7.2 没有 get_monitor_refresh_rate）。
## 跑：Godot --path . --script res://开发工具/查刷新率接口.gd

func _initialize() -> void:
	var 命: Array = []
	for m in ClassDB.class_get_method_list("DisplayServer", false):
		var n: String = String(m.get("name", ""))
		if n.contains("refresh") or n.contains("screen_count") or n.contains("window"):
			命.append(n)
	print("DisplayServer 相关方法 = ", 命)
	print("屏幕数 = ", DisplayServer.get_screen_count())
	if DisplayServer.has_method("get_screen_refresh_rate"):
		print("get_screen_refresh_rate(0) = ", DisplayServer.call("get_screen_refresh_rate", 0))
	print("主屏尺寸 = ", DisplayServer.screen_get_size(0), " 可用区 = ", DisplayServer.screen_get_usable_rect(0))
	quit(0)
