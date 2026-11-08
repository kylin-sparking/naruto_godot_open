extends SceneTree
# 好友子窗运行期截图器（有头）：把两扇自成一窗的子窗开进宿主的 `遮罩`（走真实接线：
# 好友页「添加好友钮」→ 选人窗；行"对话"→ 私聊窗），出 `测试/截图/好友_对照/子窗_*.png`。
# 跑法（不能加 --headless）：Godot --path . --script res://开发工具/截好友子窗.gd

const 主窗 := "res://场景/界面/窗口/好友/好友窗口.tscn"
const 底片 := "res://测试/截图/A3_木叶村_整机位.png"
const 出图 := "res://测试/截图/好友_对照/"
const 子窗壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 目录 := "res://场景/界面/窗口/好友/"

var _帧 := 0
var _页: Control
var _宿: Node
var _挂 := false
var _红 := 0
var _瑞 := {"name": "瑞树", "level": 60, "favor": 120, "online": true}


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute(出图)
	if ResourceLoader.exists(底片):
		var 背 := TextureRect.new()
		背.texture = load(底片) as Texture2D
		背.expand_mode = 1
		背.stretch_mode = 0
		root.add_child(背)
	_宿 = load("res://测试/假好友宿主.gd").new()
	root.add_child(_宿)
	_页 = (load(主窗) as PackedScene).instantiate() as Control
	_页.position = Vector2(8.0, 38.0)
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
		6:
			_页.call("_发动作", "好友:添加好友钮")		# → 选人窗（SPW 292×279）
		16:
			_拍("子窗_选人.png")
		18:
			_页.call("_发动作", "好友:对话")				# → 私聊窗（FCW 262×330）
		28:
			_拍("子窗_选人+私聊.png")
			var 数 := 0
			for 子 in (_宿.get("_overlay") as Control).get_children():
				数 += 1
			print("   开了 %d 扇子窗（期望 2）" % 数)
			_红 += 0 if 数 == 2 else 1
			# 关一扇再开一扇：验"开关式"不会漏节点
			子窗壳.关掉(_宿, "好友私聊窗")
		32:
			var 名: Array = []
			for 子 in (_宿.get("_overlay") as Control).get_children():
				名.append(子.name)
			print("   关掉私聊窗后剩：%s" % 名)
			_红 += 0 if 名.size() == 1 else 1
		34:
			子窗壳.关掉(_宿, "好友选人窗")
		38:
			_页.call("_发菜单项", "打探", _瑞)			# → 打探窗（DATAN 294×204，自成一窗）
		46:
			_拍("子窗_打探.png")					# 单独一张：确认弹会压住打探窗的正文，别混在一起看
		48:
			_页.call("_发菜单项", "删除", _瑞)			# → 输入确认弹（MDialog 302×117）
		58:
			_拍("子窗_打探+确认弹.png")
			var 层: Control = _宿.get("_overlay")
			var 弹 := 0
			var 窗 := 0
			for 子 in 层.get_children():
				if (子 as Object).has_meta("mdialog"):
					弹 += 1
				elif String(子.name).ends_with("好友打探窗"):
					窗 += 1
			print("   遮罩里：打探窗 %d 扇、确认弹 %d 扇（各期望 1）" % [窗, 弹])
			_红 += 0 if (窗 == 1 and 弹 == 1) else 1
		62:
			quit(1 if _红 > 0 else 0)
			return true
	return false


func _拍(名: String) -> void:
	root.get_texture().get_image().save_png(出图.path_join(名))
	print("   截图 → %s" % 名)
