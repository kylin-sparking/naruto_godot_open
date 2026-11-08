extends SceneTree
## 一次性：`ScrollContainer` 的滚动模式在这版引擎里各个值是什么行为
## （10-25 写轮眼页要恢复"滚轮能翻后面那几枚"，场景里原先写的是 `vertical_scroll_mode = 3`，
##  不能靠猜）。⚠ 别在这脚本里静态调 ClassDB 里不存在的函数 —— 那会让整份 parse 失败。
func _initialize() -> void:
	var s := ScrollContainer.new()
	root.add_child(s)
	print("新建默认：vertical=", s.vertical_scroll_mode, " horizontal=", s.horizontal_scroll_mode)
	for 值 in [0, 1, 2, 3, 4]:
		s.vertical_scroll_mode = 值
		print("  写 ", 值, " → 读回 ", s.vertical_scroll_mode)
	quit(0)
