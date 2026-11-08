extends SceneTree
# 好友页「真空底片」客户端图（像素门用）：与 截好友页/截好友子窗 的**看板式截图**分开跑，
# 因为像素门的参照是"元件图皮肤按 §13 边距拉伸后压在一条真空色上"（家族门同一口径），
# 底片换成木叶村地图就没法合成参照。这里只出图 + 记录每扇窗在图里的原点，供
# `开发工具/出好友对照图.py` 裁块。
#
# 跑法（不能加 --headless）：Godot --path . --script res://开发工具/截好友客户端.gd
#   → 测试/截图/好友/客户端_*.png + 客户端位置.json

const 主窗场景 := "res://场景/界面/窗口/好友/好友窗口.tscn"
const 出图 := "res://测试/截图/好友/"
const 目录 := "res://场景/界面/窗口/好友/"
const 子窗壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")

var _帧 := 0
var _页: Control
var _宿: Node
var _挂 := false
var _红 := 0
var _位 := {}
var _瑞 := {"name": "瑞树", "level": 60, "favor": 120, "online": true}


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute(出图)
	_宿 = load("res://测试/假好友宿主.gd").new()
	root.add_child(_宿)
	_页 = (load(主窗场景) as PackedScene).instantiate() as Control
	_页.position = Vector2(8.0, 38.0)		# FW2:207-208 内容区原点
	root.add_child(_页)


func _process(_d: float) -> bool:
	if not _挂:
		var 会: Node = _宿.get_node_or_null("GameSession")
		if 会 == null:
			return false
		_宿.remove_child(会)
		root.add_child(会)
		_页.call("装配", _宿)
		_挂 = true
	_帧 += 1
	match _帧:
		8:
			_拍("客户端_主窗.png", [8, 38], "主窗")		# 页面矩形 = 窗口矩形 − (8,38)
		12:
			_页.call("_发动作", "好友:添加好友钮")
		20:
			_拍窗("客户端_选人.png", "好友选人窗")
			子窗壳.关掉(_宿, "好友选人窗")
		24:
			_页.call("_发动作", "好友:对话")
		32:
			_拍窗("客户端_私聊.png", "好友私聊窗")
			子窗壳.关掉(_宿, "好友私聊窗")
		36:
			_页.call("_发菜单项", "打探", _瑞)
		44:
			_拍窗("客户端_打探.png", "好友打探窗")
		46:
			_页.call("_发菜单项", "删除", _瑞)
		54:
			_拍弹("客户端_确认弹.png")
		56:
			var f := FileAccess.open(出图.path_join("客户端位置.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify(_位))
			print("   原点表 → 客户端位置.json：%s" % _位.keys())
			quit(1 if _红 > 0 else 0)
			return true
	return false


func _拍(名: String, 原点: Array, 键: String) -> void:
	root.get_texture().get_image().save_png(出图.path_join(名))
	_位[键] = 原点
	print("   截图 → %s 原点=%s" % [名, 原点])


## 子窗：原点在 宿主`遮罩` 里居中（`家族子窗壳.切换:104-105`），这里按同一个式子记下来。
func _拍窗(名: String, 窗名: String) -> void:
	var 层: Control = _宿.get("_overlay")
	var 根 := 层.get_node_or_null("家族子窗_" + 窗名) as Control
	if 根 == null:
		_红 += 1
		print("!! 没开出来：%s" % 窗名)
		return
	_拍(名, [int(根.global_position.x), int(根.global_position.y)], 窗名)


func _拍弹(名: String) -> void:
	var 层: Control = _宿.get("_overlay")
	for 子 in 层.get_children():
		if (子 as Object).has_meta("mdialog"):
			var 主 := 子.get_node_or_null("主体") as Control
			if 主 != null:
				_拍(名, [int(主.global_position.x), int(主.global_position.y)], "确认弹")
				return
	_红 += 1
	print("!! 遮罩里没有输入确认框")
