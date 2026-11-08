extends SceneTree

# 转储设置页动态内容里所有控件的全局矩形，用来定位多余控件。

var _frames := 0
var _done := false
var _page := "设置"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--page="):
			_page = arg.trim_prefix("--page=")
	var scene: PackedScene = load("res://场景/界面/功能窗口.tscn")
	var win := scene.instantiate()
	get_root().add_child(win)
	win.call_deferred("open_page", _page)


func _dump(node: Node, depth: int) -> void:
	if node is Control:
		var c := node as Control
		var r := c.get_global_rect()
		if r.position.y > 470.0 and r.position.x < 700.0:
			print("  ".repeat(depth), node.name, " [", node.get_class(), "] pos=", r.position, " size=", r.size, " vis=", c.visible)
	for child in node.get_children():
		_dump(child, depth + 1)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if _frames < 8:
		return false
	_done = true
	_dump(get_root(), 0)
	return true
