extends SceneTree
# 家族成员管理窗的看图器：主窗垫底 + 壳开成员窗（与实机同构），灌一份假成员表后截图。
# 用法（不能加 --headless）：Godot --path . --script res://开发工具/截家族成员窗.gd
# 出图：测试/截图/家族/家族成员窗_实况.png

const 壳 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 出图 := "res://测试/截图/家族/家族成员窗_实况.png"

## 假成员表：字段口径 = 服务端 `_family_member_summaries`（name/level/rank/contribution/…）
const 假成员 := [
	{"name": "漩涡鸣人", "level": 120, "rank": 1, "contribution": 1200, "channel_id": 1},
	{"name": "宇智波佐助", "level": 118, "rank": 2, "contribution": 900, "channel_id": -1},
	{"name": "春野樱", "level": 115, "rank": 3, "contribution": 700, "channel_id": 1},
	{"name": "奈良鹿丸", "level": 110, "rank": 4, "contribution": 500, "channel_id": -1},
	{"name": "秋道丁次", "level": 105, "rank": 5, "contribution": 300, "channel_id": 1},
]
const 假家族 := {
	"joined": true, "id": 7, "name": "木叶家族", "level": 3,
	"leader": "漩涡鸣人", "leader_id": 10001, "flag_name": "木叶",
	"flag_style": 1004, "notice": "每周三、周日打尾兽，剩余次数别浪费。",
	"members": 5, "contribution": 1200,
	"member_list": 假成员,
}

var _帧 := 0
var _已开 := false
var _宿主: Node


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute("res://测试/截图/家族")
	# ⚠️ 先加主窗、再加宿主（overlay 挂在宿主下）：实机里 overlay 在页面内容**之上**。
	#    反了的话主窗会画在成员窗前面，"透底"看起来比实机重得多（第一版就是这么截错的）。
	var 主窗 := (load("res://场景/界面/窗口/家族/家族窗口.tscn") as PackedScene).instantiate() as Control
	主窗.position = Vector2(60.0, 60.0)
	root.add_child(主窗)
	主窗.call("刷新", 假家族)
	_宿主 = Node.new()
	_宿主.name = "假宿主"
	_宿主.set_script(_宿脚本())
	root.add_child(_宿主)


func _宿脚本() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends Node
class 假会话 extends Node:
	var guild := {}
signal social_changed
var _session := 假会话.new()
var _overlay := Control.new()
func _ready() -> void:
	add_child(_session)
	_overlay.name = "overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
func _show_guild_action(_名: String) -> void:
	pass
"""
	s.reload()
	return s


func _process(_d: float) -> bool:
	_帧 += 1
	if _帧 < 14:
		return false
	if not _已开:
		_已开 = true
		(_宿主.get("_session") as Node).set("guild", 假家族.duplicate(true))
		# 与实机同一条路：壳的开窗表项 `成员信息 → 家族成员窗/成员管理`
		壳.切换(_宿主, "家族成员窗", "成员管理", true)
	if _帧 >= 16:
		root.get_texture().get_image().save_png(出图)
		print("   截图 → %s" % 出图)
		var 根 := (_宿主.get("_overlay") as Control).get_child(0) as Control
		var 页: Control = null
		for 子 in 根.get_children():
			if String(子.name) == "家族成员窗":
				页 = 子
		if 页 == null:
			print("   ✗ 找不到内容页，根的子节点：%s" % [根.get_children().map(func(c): return String(c.name))])
			quit(1)
			return true
		print("   内容根 size=%s  盒=%s" % [页.size, _矩形(页, "盒")])
		print("   列表容器=%s  行数=%d" % [_矩形(页, "列表"), 页.get_node("列表").get_child_count()])
		for i in mini(3, 页.get_node("列表").get_child_count()):
			var 行 := 页.get_node("列表").get_child(i) as Control
			var 首字 := 行.get_child(0) as Label
			print("     %s pos=%s size=%s 全局=%s 可见=%s 文字=[%s] 色=%s" % [
				行.name, 行.position, 行.size,
				行.get_global_transform_with_canvas().origin, 行.visible,
				首字.text, 首字.get_theme_color("font_color")])
		quit(0)
		return true
	return false


func _矩形(页: Control, 节点名: String) -> String:
	var n := 页.get_node_or_null(节点名) as Control
	return "(%s, %s)" % [n.position, n.size] if n != null else "缺"
