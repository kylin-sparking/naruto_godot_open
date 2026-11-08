extends SceneTree
## 家徽**看图器**：按客户端真实渲染路径把"家族页家徽格"与"创建窗预览格"画出来，
## 各裁一块放大存图 —— 用来跟原版/单机版实机图**同元素比对**（§0.0c 红线②：并排全景不能替代单件放大）。
##
## 为什么需要它：族徽有 **200 个样式**，而界面里同时只看得见 1 个；改素材（染色/尺寸/底框）之后
## 光看门是看不出"像不像原版"的 —— 得把那一格单独裁出来放大看。200 个样式的全貌另见
## `开发工具/出族徽总览.py`（离线拼图，不需要跑游戏）。
##
## 用法（**不能加 --headless**）：
##   Godot --path . --script res://开发工具/截家徽图.gd
## 产物：`测试/截图/家族/家徽_客户端.png`（左＝家族页家徽格 6 倍，右＝创建窗预览格 6 倍；
## 底图是中灰，透明处才看得清）。样式号写死在 `_样式`，要换就改它。

const 倍 := 6
const _样式 := 1000
const 出图 := "res://测试/截图/家族/家徽_客户端.png"
const 创建填充 := preload("res://脚本/界面/窗口/家族/家族创建填充.gd")

var _帧 := 0
var _窗: Control
var _创: Control
var _左: Image
var _右: Image


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	_窗 = (load("res://场景/界面/窗口/家族/家族窗口.tscn") as PackedScene).instantiate() as Control
	_窗.position = Vector2(8.0, 38.0)
	root.add_child(_窗)
	_创 = (load("res://场景/界面/窗口/家族/家族创建窗.tscn") as PackedScene).instantiate() as Control
	_创.position = Vector2(8.0, 400.0)
	root.add_child(_创)


func _process(_d: float) -> bool:
	_帧 += 1
	if _帧 == 14:
		# 创建窗后加 ⇒ 画在上面，先把它的格子截了再收起来，免得两扇窗互相盖
		_创.position = Vector2(8.0, 38.0)
		_创.set_meta(创建填充.页键, _页号())
		创建填充._填家徽(_创, null)
		_窗.call("装配", _假宿主())
		return false
	if _帧 == 20:
		_左 = _裁(root.get_texture().get_image(), _创.get_node_or_null("格家徽图") as Control)
		_创.visible = false
		return false
	if _帧 == 22:
		_右 = _裁(root.get_texture().get_image(), _窗.get_node_or_null("家徽区/家徽格") as Control)
		return false
	return false if _帧 < 26 else _存图()


func _页号() -> int:
	var 表 := _样式表()
	return 表.find(_样式) if 表.has(_样式) else 0


func _样式表() -> Array[int]:
	var 出: Array[int] = []
	var 文件 := DirAccess.get_files_at("res://素材/界面/原版窗口/家族/")
	for 名 in 文件:
		if 名.begins_with("家徽_") and 名.ends_with(".png"):
			var 尾 := 名.trim_prefix("家徽_").trim_suffix(".png")
			if 尾.is_valid_int():
				出.append(int(尾))
	出.sort()
	return 出


func _存图() -> bool:
	var 宽 := maxi(_左.get_width(), _右.get_width()) * 2 + 24
	var 高 := maxi(_左.get_height(), _右.get_height()) + 12
	var 画 := Image.create(宽, 高, false, Image.FORMAT_RGBA8)
	画.fill(Color(0.45, 0.45, 0.47, 1.0))		# 中灰底：透明边角才看得见
	画.blit_rect(_左, Rect2i(Vector2i.ZERO, _左.get_size()), Vector2i(12, 6))
	画.blit_rect(_右, Rect2i(Vector2i.ZERO, _右.get_size()), Vector2i(24 + _左.get_width(), 6))
	DirAccess.make_dir_recursive_absolute("res://测试/截图/家族")
	画.save_png(出图)
	print("  家徽看图器 → %s（左＝创建窗预览格，右＝家族页家徽格，都放大 %d 倍）" % [出图, 倍])
	quit(0)
	return true


## 把某个控件所在的屏幕矩形裁出来并放大（`Image.get_region` + `resize`）。
## ⚠️ 控件为空/尺寸为 0 时返回一张 1×1 的占位 —— 看图器不该因为少一处就整张失败。
func _裁(全: Image, 节: Control) -> Image:
	if 节 == null or 节.size.x < 1.0:
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var 角 := 节.get_global_transform_with_canvas().origin
	var 矩 := Rect2i(Vector2i(int(round(角.x)), int(round(角.y))), Vector2i(int(节.size.x), int(节.size.y)))
	矩 = 矩.intersection(Rect2i(Vector2i.ZERO, 全.get_size()))
	if 矩.size.x < 1 or 矩.size.y < 1:
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var 小 := 全.get_region(矩)
	小.resize(小.get_width() * 倍, 小.get_height() * 倍, Image.INTERPOLATE_NEAREST)
	return 小


## 假宿主：口径抄 `开发工具/截家族页.gd`（只提供 `_session.guild` 与 `_show_guild_action`）。
func _假宿主() -> Object:
	var 宿 := Node.new()
	宿.name = "假宿主"
	宿.set_script(_宿脚本())
	return 宿


func _宿脚本() -> GDScript:
	var s := GDScript.new()
	s.source_code = """extends Node
var _session := 数据.new()
func _show_guild_action(_名: String) -> void:
	pass
class 数据 extends Node:
	var guild := {"joined": true, "name": "木叶", "leader": "鸣人", "flag_name": "火之意志",
		"level": 3, "members": 5, "contribution": 120, "notice": "团结协作",
		"flag_style": %d,
		"member_list": [{"name": "鸣人", "level": 60, "rank": 5, "contribution": 900,
			"weekly_contribution": 30}]}
""" % _样式
	s.reload()
	return s
