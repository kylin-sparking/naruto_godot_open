extends SceneTree

## 一次性诊断：为什么写轮眼页那 12 枚阶段钮在运行期全叠在同一处（2026-10-25）。

func _initialize() -> void:
	var 页 := (load("res://场景/界面/窗口/人物/页面/写轮眼页.tscn") as PackedScene).instantiate()
	root.add_child(页)
	await process_frame
	await process_frame
	var 列 := 页.find_child("阶段列表", true, false)
	print("列类=", 列.get_class(), " 尺寸=", 列.size, " 全局位=", 列.global_position)
	for 子在 in 列.get_children():
		if 子在 is Control:
			var c := 子在 as Control
			print("  %-14s 声明=%s..%s  实际尺寸=%s 全局=%s 最小=%s 类=%s" % [
				String(c.name), str(Vector2(c.offset_left, c.offset_top)), str(Vector2(c.offset_right, c.offset_bottom)),
				str(c.size), str(c.global_position), str(c.get_combined_minimum_size()), c.get_class()])
	quit(0)
