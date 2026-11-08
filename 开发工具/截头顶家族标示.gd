extends SceneTree
## 头顶**家族标示**看图器：把「名牌 + 家族牌 + 族徽块」按客户端真实路径画出来、裁大存图。
##
## 为什么需要它：族徽块在角色头顶，尺寸只有 20×20，缩在整张地图截图里根本看不出落点对不对。
## 2026-10-15 用户给了并排图（单机版的族徽块**居中在角色身上、贴在家族牌文字下面**，
## 我们原来贴在名牌左沿）⇒ 这类"位置对不对"的改动只能靠同元素裁图来验收。
##
## 用法（**不能加 --headless**）：
##   Godot --path . --script res://开发工具/截头顶家族标示.gd
## 产物：`测试/截图/家族/头顶家族标示.png`（4 倍放大；样式号写死在 `_样式`）。
##
## ⚠️ 走的是 `地图实体._刷家族标示` 真实函数（不 add_child、手动喂 `_player`/`_session`，
##    与 `测试/家族页回归测试.gd` 同款套路）—— 要拍的就是那个函数本身。

const 倍 := 4
const _样式 := 1002
const 出图 := "res://测试/截图/家族/头顶家族标示.png"

var _帧 := 0
var 实体: Node
var 玩家: Node2D


func _initialize() -> void:
	root.size = Vector2i(220, 110)
	玩家 = Node2D.new()
	玩家.name = "假玩家"
	玩家.position = Vector2(110.0, 34.0)		# 角色"原点"（脚下）
	root.add_child(玩家)
	实体 = (load("res://脚本/地图/地图实体.gd") as GDScript).new()
	实体.set("_player", 玩家)
	实体.set("_session", root.get_node_or_null("GameSession"))
	var 名牌 := Label.new()
	名牌.name = "Nameplate"
	名牌.size = Vector2(160.0, 18.0)
	名牌.position = Vector2(-80.0, 1.0)
	名牌.text = "115"
	名牌.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	名牌.add_theme_font_size_override("font_size", 12)
	名牌.add_theme_color_override("font_color", Color(1, 1, 1))
	名牌.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	名牌.add_theme_constant_override("outline_size", 3)
	玩家.add_child(名牌)


func _process(_d: float) -> bool:
	_帧 += 1
	if _帧 < 6:
		return false
	if _帧 == 6:
		var 会话 := root.get_node_or_null("GameSession")
		if 会话 != null:
			(会话 as Node).set("guild", {"joined": true, "name": "44", "flag_style": _样式, "level": 3})
		实体.call("_刷家族标示")
		return false
	if _帧 < 8:
		return false
	_存图()
	return true


func _存图() -> void:
	var 全 := root.get_texture().get_image()
	# 只取名牌+家族牌+族徽那一块（角色原点上下各留点），再放大
	var 区 := Rect2i(110 - 60, 30 - 8, 120, 70).intersection(Rect2i(Vector2i.ZERO, 全.get_size()))
	var 小 := 全.get_region(区)
	小.resize(小.get_width() * 倍, 小.get_height() * 倍, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute("res://测试/截图/家族")
	小.save_png(出图)
	print("  头顶家族标示看图器 → %s（名牌 / 家族牌 / 族徽块，%d 倍）" % [出图, 倍])
	print("  族徽块位 = %s（真值：x 居中 −10、y = 家族牌**原点** + 行高 + 4 缝 + 内缩 1）"
		% [str((玩家.get_node_or_null("FamilyEmblem") as Sprite2D).position)])
	quit(0)
