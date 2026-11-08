extends SceneTree
# 好友主窗运行期截图器（有头跑）：把内容页铺在客户端底片上，连拍三态出证据：
#   ① 好友页（选中枚显示选中皮、两枚底栏钮、两行假数据）
#   ② 切到仇人页（体互斥 + 两行橙字说明压在列表体下面）
#   ③ 点一行弹出行菜单（项宽/底宽按 §6.4 公式）
# 跑法（不能加 --headless）：Godot --path . --script res://开发工具/截好友页.gd

const 场景 := "res://场景/界面/窗口/好友/好友窗口.tscn"
const 底片 := "res://测试/截图/A3_木叶村_整机位.png"
const 出图 := "res://测试/截图/好友_对照/"

var _帧 := 0
var _页: Control
var _宿: Node
var _挂好了 := false


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute(出图)
	if ResourceLoader.exists(底片):
		var 背 := TextureRect.new()
		背.name = "底片"
		背.texture = load(底片) as Texture2D
		背.expand_mode = 1
		背.stretch_mode = 0
		root.add_child(背)
	_宿 = load("res://测试/假好友宿主.gd").new()
	root.add_child(_宿)		# ⚠ _ready（给会话命名 GameSession）要到首帧才跑，别在这里就 get_node
	_页 = (load(场景) as PackedScene).instantiate() as Control
	_页.position = Vector2(8.0, 38.0)		# 内容区原点（FW2:207-208）
	root.add_child(_页)


func _process(_d: float) -> bool:
	if not _挂好了:						# 第 2 帧：会话改名完了，再搬去 /root 下并装配
		var 会: Node = _宿.get_node_or_null("GameSession")
		if 会 == null:
			return false
		_宿.remove_child(会)
		root.add_child(会)				# 控制器按 /root/GameSession 绝对路径取会话
		_页.call("装配", _宿)
		_挂好了 = true
	_帧 += 1
	match _帧:
		10:
			_拍("好友页.png")
		12:
			_页.call("切页", "仇人")
		20:
			_拍("仇人页.png")
		22:
			var 体 := _页.get_node("体仇人/列表/行容器")
			var 行 := 体.get_child(0) as Control
			行.点击.emit({"name": "仇八", "level": 40, "hate": 900, "online": true},
					行.get_global_position() + Vector2(60, 8))
		30:
			_拍("仇人页行菜单.png")
			var 菜 := _页.get_node("行菜单") as Control
			var 项数 := 0
			for 子 in 菜.get_children():
				if 子 is Button:
					项数 += 1
			print("   仇人在线态菜单 %d 项（真值 §4：查看/打探/删除 = 3）" % 项数)
			quit(0 if 项数 == 3 else 1)
			return true
	return false


func _拍(名: String) -> void:
	root.get_texture().get_image().save_png(出图.path_join(名))
	print("   截图 → %s" % 名)
