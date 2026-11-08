extends SceneTree
# 快捷键设置窗运行期截图器（有头）：铺底片出两张证据
#   ① 开窗默认态（86 键位格 + 34 列表格 + 4 操作钮 + 5 方案钮 + 保存方案）
#   ② 绑过一次后的态（「人物」绑到 B、「背包」绑到 V，格上/列表上两处文字都该跟着变）
# 跑法（不能加 --headless）：Godot --path . --script res://开发工具/截快捷键窗.gd

const 场景 := "res://场景/界面/窗口/设置/快捷键窗.tscn"
const 底片 := "res://测试/截图/A3_木叶村_整机位.png"
const 出图 := "res://测试/截图/设置_对照/"

var _帧 := 0
var _窗: Control
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
	var 宿: Node = load("res://测试/假设置宿主.gd").new()
	root.add_child(宿)
	_窗 = (load(场景) as PackedScene).instantiate() as Control
	_窗.position = Vector2(120.0, 40.0)
	root.add_child(_窗)
	_窗.call("装配", 宿)
	_挂 = true


func _process(_d: float) -> bool:
	_帧 += 1
	match _帧:
		8:
			_拍("快捷键_开窗.png")
			var 不吃了: int = 0
			for 子 in _窗.get_children():
				if (子 is Control) and String(子.name).begins_with("格") \
						and (子 as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE:
					不吃了 += 1
			print("   不可绑格（吃鼠标被关掉）%d 枚（真值 26 条 canSet=false）" % 不吃了)
		12:
			_窗.call("_放格", "b", Vector2.ZERO, {"类": "槽", "键": "KEYBOARD_SHORTCUT_KEY_CHAR"})
			_窗.call("_放格", "v", Vector2.ZERO, {"类": "槽", "键": "KEYBOARD_SHORTCUT_KEY_BAG"})
		20:
			_拍("快捷键_绑过.png")
			var b牌 := (_窗.get_node("格bCell/牌/牌字") as Label).text
			var v牌 := (_窗.get_node("格vCell/牌/牌字") as Label).text
			var c亮 := (_窗.get_node("格cCell/牌") as TextureRect).visible
			var b键 := (_窗.get_node("格bCell/字bCell") as Label).text
			print("   b 牌「%s」、v 牌「%s」、c 牌仍亮=%s、b 键名「%s」" % [b牌, v牌, c亮, b键])
			# 期望：人物→b、背包→v，人物 原占的 c 灭牌；格上小字恒为键名，不被动作名顶掉
			_红 += 0 if (b牌 == 牌文("人物") and v牌 == 牌文("背包") and not c亮 and b键 == "B") else 1
		24:
			quit(1 if _红 > 0 else 0)
			return true
	return false


## `KeyboardShortcurIcon.as:31-44` 宋体分支（与控制器同名同口径）。
func 牌文(名: String) -> String:
	if 名.length() == 2:
		return "\n" + 名
	if 名.length() == 3:
		return "　" + 名
	return 名


func _拍(名: String) -> void:
	root.get_texture().get_image().save_png(出图.path_join(名))
	print("   截图 → %s" % 名)
