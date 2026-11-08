extends SceneTree

## 打开若干页，把 `遮罩/主窗口` 的锚点 / 偏移 / 尺寸 / 全局矩形逐项打出来。
##
## 为什么要有它：截多窗口那边量到的矩形比 `数据/界面/窗口尺寸.json` 里的真值小
## （背包 215x355 vs 275x394、忍术 342x388 vs 462x466，而人物 517x440 却是对的），
## 差的量又像 `错开步长` 的整数倍。窗口是内容撑出来的、开窗那一刻可能还没定稿，
## 所以要看到"什么时候读到的尺寸是多少"，不能只看最终矩形。
##
## 用法：
##   Godot --headless --path . --script res://开发工具/窗口几何诊断.gd [-- --页=人物,背包,忍术]

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 功能窗口脚本 := preload("res://脚本/界面/功能窗口.gd")

var _页们: Array[String] = ["人物", "背包", "忍术"]
var _场景: Node = null
var _管理: Node = null


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--页":
			_页们.clear()
			for 项 in 键值[1].split(",", false):
				_页们.append(项)
	call_deferred("_跑")


func _跑() -> void:
	var 路径: String = 地图资源.playable_scene_path("101010000")
	var 包 := load(路径) as PackedScene
	_场景 = 包.instantiate()
	root.add_child(_场景)
	_管理 = _场景.get_node_or_null("窗口管理")

	print("=== 视口 ===")
	print("  root.get_visible_rect().size = ", root.get_visible_rect().size)
	print("  root.size = ", root.size)
	print("  DisplayServer 屏幕 = ", DisplayServer.screen_get_size())
	# 无头下视口是 64x64（不是 960x560），钳制会失真。试试能不能顶掉。
	root.size = Vector2i(960, 560)
	await process_frame
	print("  设 root.size=(960,560) 后 get_visible_rect = ", root.get_visible_rect().size, "  root.size = ", root.size)
	var 内容缩放 := root.content_scale_size
	print("  content_scale_size = ", 内容缩放)
	var 遮罩尺寸 := "（还没建窗）"
	if _管理.get_child_count() > 0:
		var 遮罩 := _管理.get_child(0).get_node_or_null("遮罩") as Control
		if 遮罩 != null:
			遮罩尺寸 = str(遮罩.size)
	print("  遮罩 尺寸 = ", 遮罩尺寸)

	var 表 := 功能窗口脚本._取窗口尺寸表()
	for 页 in _页们:
		print("=== %s ===" % 页)
		print("  尺寸表真值 = %sx%s" % [表.get(页, {}).get("宽"), 表.get(页, {}).get("高")])
		_管理.call("打开", 页)
		await process_frame
		_打("  开窗后第1帧", 页)
		await process_frame
		_打("  第2帧", 页)
		await process_frame
		_打("  第3帧", 页)
		var 主窗 := _主窗(页)
		if 主窗 != null:
			print("  锚点 = (%.1f,%.1f)-(%.1f,%.1f)" % [主窗.anchor_left, 主窗.anchor_top, 主窗.anchor_right, 主窗.anchor_bottom])
			print("  偏移 = L%.1f T%.1f R%.1f B%.1f" % [主窗.offset_left, 主窗.offset_top, 主窗.offset_right, 主窗.offset_bottom])
			print("  父(遮罩) 尺寸 = ", (主窗.get_parent() as Control).size)
			print("  子节点数 = %d" % 主窗.get_child_count())
			for 子 in 主窗.get_children():
				if 子 is Control:
					var 控 := 子 as Control
					print("    - %-10s %s size=%s min=%s" % [控.name, 控.get_global_rect(), 控.size, 控.custom_minimum_size])
	quit(0)


func _主窗(页名: String) -> Control:
	var 窗: Node = _管理.call("取窗口", 页名)
	if 窗 == null:
		return null
	return 窗.get_node_or_null("遮罩/主窗口") as Control


func _打(前缀: String, 页名: String) -> void:
	var 主窗 := _主窗(页名)
	if 主窗 == null:
		print(前缀, " 主窗=null")
		return
	print("%s size=%s global=%s" % [前缀, 主窗.size, 主窗.get_global_rect()])
