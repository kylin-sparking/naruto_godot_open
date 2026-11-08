extends SceneTree
# 家族旗帜窗「势力对比」的看图器：给窗口灌一份假的族旗表，把三段渐变条画出来。
# 用法（不能加 --headless）：Godot --path . --script res://开发工具/截家族旗帜窗.gd

const 填充 := preload("res://脚本/界面/窗口/家族/家族旗帜填充.gd")
const 出图 := "res://测试/截图/家族/家族旗帜窗_势力对比.png"

## 假族旗表：三个家族，人数 5 / 3 / 1 ⇒ 三段宽度 = 364 × 5/9、3/9、1/9
const 假表 := [
	{"bang_id": 7, "bang_name": "木叶家族"}, {"bang_id": 7, "bang_name": "木叶家族"},
	{"bang_id": 7, "bang_name": "木叶家族"}, {"bang_id": 7, "bang_name": "木叶家族"},
	{"bang_id": 7, "bang_name": "木叶家族"},
	{"bang_id": 9, "bang_name": "砂隐村"}, {"bang_id": 9, "bang_name": "砂隐村"},
	{"bang_id": 9, "bang_name": "砂隐村"},
	{"bang_id": 12, "bang_name": "雾隐村"},
]

var _帧 := 0
var _已填 := false
var _宿主
var _页: Control


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute("res://测试/截图/家族")
	_宿主 = Node.new()
	_宿主.name = "假宿主"
	_宿主.set_script(_宿脚本())
	root.add_child(_宿主)
	var 场 := (load("res://场景/界面/窗口/家族/家族旗帜窗.tscn") as PackedScene).instantiate() as Control
	场.position = Vector2(8.0, 38.0)
	root.add_child(场)
	_页 = 场


func _宿脚本() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends Node
class 假会话 extends Node:
	var guild := {"joined": true, "id": 7, "name": "木叶家族", "level": 3}
var _session := 假会话.new()
func _ready() -> void:
	add_child(_session)
func _show_guild_action(_名: String) -> void:
	pass
"""
	s.reload()
	return s


func _process(_d: float) -> bool:
	_帧 += 1
	if _帧 < 14:
		return false
	# ⚠️ 只填一次：这段在 `_帧 >= 14` 之后每帧都会跑到，重复装配会让
	#    `家族子窗.gd._绑` 的 connect 撞车（刷一屏 "already connected"）。
	if not _已填:
		_已填 = true
		_页.call("装配", _宿主)
		# `_填对比` 读的是后端单例，离线没有（表是空的）⇒ 先灌一份假表再填。
		_灌假表()
	if _帧 >= 16:
		root.get_texture().get_image().save_png(出图)
		print("   截图 → %s" % 出图)
		print("   标题势力=%s" % (_页.get_node("标题势力/势力富文本") as RichTextLabel).text)
		print("   标题计数=%s  上限=%s  已安插=%s" % [
			(_页.get_node("标题计数") as Label).text,
			(_页.get_node("标签旗数上限") as Label).text,
			(_页.get_node("输入旗数") as LineEdit).text])
		var 区 := _页.get_node("区进度条") as Control
		for 条 in 区.get_children():
			print("   段 rect=%s" % Rect2((条 as Control).position, (条 as Control).size))
		quit(0)
		return true
	return false


func _灌假表() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	if 后端 == null:
		push_error("没有 BackendConnection 单例")
		return
	# ⚠️ `authoritative_flag_list` 声明的是 `Array[Dictionary]`，直接塞普通 `Array`
	#    会被类型检查静默拒绝（赋值不生效、也不报错）—— 这里逐项 append。
	var 表: Array[Dictionary] = []
	for 行 in 假表:
		表.append(行)
	后端.set("authoritative_flag_list", 表)
	print("   假表已灌：%d 行，实读 %d 行" % [表.size(), (后端.get("authoritative_flag_list") as Array).size()])
	填充.填(_页, _宿主)
