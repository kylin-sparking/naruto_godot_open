extends SceneTree
# 设置页运行期截图器（有头）：把重建后的设置页铺在客户端底片上，连拍三态出证据
#   ① 系统设置页（16 复选 + 10 黄字 + 绿字盒，选中页签显示 selectedUpSkin）
#   ② 特殊设置页（6 复选 + 两条音量条：轨道 #333333 / 滑块 #FFCC00 r7）
#   ③ 客户端页（本工程自加层，非原版）
# 跑法（不能加 --headless）：Godot --path . --script res://开发工具/截设置页.gd

const 场景 := "res://场景/界面/窗口/设置/设置窗口.tscn"
const 底片 := "res://测试/截图/A3_木叶村_整机位.png"
const 出图 := "res://测试/截图/设置_对照/"

var _帧 := 0
var _页: Control
var _宿: Node
var _挂 := false
var _红 := 0


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
	_宿 = load("res://测试/假设置宿主.gd").new()
	root.add_child(_宿)
	_页 = (load(场景) as PackedScene).instantiate() as Control
	_页.position = Vector2(0.0, 29.0)		# 整框原点（窗口坐标 − (0, 拖动区高 29)）
	root.add_child(_页)


func _process(_d: float) -> bool:
	if not _挂:
		# 照 `系统窗口._render_settings` 的真实三步走：装配 → 宿主填「客户端」层（它会 more.visible=true）
		# → 页面重摆层收回来。少演一步就等于截图永远拍不到实机那次泄漏。
		_页.call("装配", _宿)
		_宿.call("_render_more_settings", _页, (_宿.get("_session") as Node).get("game_settings"))
		_页.call("重摆层")
		_挂 = true
	_帧 += 1
	match _帧:
		8:
			_拍("设置_主页.png")
		12:
			(_页.get_node("页签特殊设置") as TextureButton).pressed.emit()
		18:
			_拍("设置_特殊设置.png")
			var 钮 := _页.get_node("层特页/条背景音乐音量/钮滑块") as Control
			print("   音量滑块 x=%s（music_volume=0.5 ⇒ 0.5·170−7 = 78）" % 钮.position.x)
			_红 += 0 if absf(钮.position.x - 78.0) < 1.5 else 1
		22:
			(_页.get_node("页签客户端") as TextureButton).pressed.emit()
		28:
			_拍("设置_客户端页.png")
		30:
			(_页.get_node("页签系统设置") as TextureButton).disabled = false
			(_页.get_node("页签系统设置") as TextureButton).pressed.emit()
			(_页.get_node("层主页/复选遮罩其他玩家名字/点击区域") as Button).pressed.emit()
		38:
			_拍("设置_勾了一枚.png")
			var 勾 := (_页.get_node("层主页/复选遮罩其他玩家名字/标记") as CanvasItem).visible
			print("   点完「遮罩其他玩家的名字资讯」⇒ 勾选显示 %s（会话 show_names=false）" % 勾)
			_红 += 0 if 勾 else 1
		42:
			quit(1 if _红 > 0 else 0)
			return true
	return false


func _拍(名: String) -> void:
	root.get_texture().get_image().save_png(出图.path_join(名))
	print("   截图 → %s" % 名)
