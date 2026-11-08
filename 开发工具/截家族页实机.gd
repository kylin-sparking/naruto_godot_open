extends SceneTree
# 「列表窗右侧黑带」的**真环境复现**：在真地图场景里点开「家族」（未入族 ⇒ 落列表窗），
# 截一张与原版实机图同条件的图，逐像素比对那条带子到底是不是"游戏世界透过半透窗皮"。
# 用法（不能加 --headless）：
#   Godot --path . --script res://开发工具/截家族页实机.gd

var _场景: Node = null
var _帧 := 0
var _已开 := false
var _待截 := false


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	_场景 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(_场景)


func _process(_delta: float) -> bool:
	_帧 += 1
	if _帧 < 10:
		return false
	if not _已开:
		var 底栏 := _场景.get_node_or_null("技能面板/技能栏") as Control
		if 底栏 == null:
			push_error("找不到底栏"); quit(1); return true
		for 节点 in 底栏.find_children("*", "BaseButton", true, false):
			var 按钮 := 节点 as BaseButton
			if 按钮 != null and 按钮.tooltip_text == "家族":
				按钮.pressed.emit()
				print("   已点「家族」")
		_已开 = true
		return false
	if not _待截:
		_待截 = true
		return false
	DirAccess.make_dir_recursive_absolute("res://测试/截图/家族")
	root.get_texture().get_image().save_png("res://测试/截图/家族/实机_家族列表.png")
	print("   截图 → 测试/截图/家族/实机_家族列表.png")
	var 管理 := _场景.get_node_or_null("窗口管理")
	if 管理 != null:
		var 窗 := 管理.call("取窗口", "家族") as Node
		print("   家族窗口：%s" % ("开" if 窗 != null and 窗.call("已打开") else "**没开**"))
	quit(0)
	return true
