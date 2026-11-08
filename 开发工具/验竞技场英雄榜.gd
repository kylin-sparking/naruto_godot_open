extends SceneTree

## 英雄榜自检（#332 第一扇，**有头**）。
##
## 判的是"开窗建得出整扇版式 + `2306:9` 那一帧真的落到行上"：
##   表头四列（排名/玩家姓名/等级/趋势）与三条竖分隔线、一条横分隔线 —— 读**屏幕值**；
##   行 = `PvpRankItemRenderer` 320×23 四列 40/140/80/60，趋势三档 `↑`绿 / `↓`红 / `-`灰；
##   关窗那颗走 `push_input` 真点击。
##
## ⚠ 「开窗即发上行 `2306:4`」这一条**离线判不了**（没连服务端，`send_game_request` 直接 false），
##   归 #333 的在线腿去判（那里能看到服务端真的收到 `2306:4` 并回 `2306:9`）。
##
## 用法：Godot --path . --script res://开发工具/验竞技场英雄榜.gd
##   退出码 0 = 全过；1 = 有红；2 = 前置条件不满足

const 出图 := "res://测试/截图/竞技场/英雄榜.png"
## 服务端 `_send_arena_heroes:29304-29325` 的一行 = `排名&角色号&等级&名字&趋势`
const 榜行 := ["1&301&60&甲一&0", "2&302&58&甲二&1", "7&305&55&甲五&2"]

var _帧 := 0
var _场景: Node = null
var _管理: Node = null
var _后端: Node = null
var _窗: Node = null
var _页: Control = null
var _判: Array = []
var _阶段 := 0
var _等待 := 0
var _钮位 := Vector2.ZERO


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://测试/截图/竞技场"))
	var 场 := load("res://场景/地图/地图场景.tscn") as PackedScene
	if 场 == null:
		push_error("拿不到 地图场景.tscn")
		quit(2)
		return
	_场景 = 场.instantiate()
	root.add_child(_场景)


func _过程(名: String, 过: bool) -> void:
	_判.append([名, 过])


func _节点(路: String) -> Node:
	return _页.get_node_or_null(路) if _页 != null else null


func _文(路: String) -> String:
	var n := _节点(路) as Label
	return n.text if n != null else "〈没有这个件〉"


func _色(路: String) -> Color:
	var n := _节点(路) as Label
	return n.get_theme_color("font_color") if n != null else Color.BLACK


func _矩(路: String, 望: Array) -> bool:
	var n := _节点(路) as Control
	if n == null:
		return false
	var r := n.get_rect()
	return is_equal_approx(r.position.x, 望[0]) and is_equal_approx(r.position.y, 望[1]) \
			and is_equal_approx(r.size.x, 望[2]) and is_equal_approx(r.size.y, 望[3])


func _喂(串: String) -> void:
	_后端.call("_handle_arena_text", PackedStringArray(串.split(":")))


func _process(_秒: float) -> bool:
	_帧 += 1
	if _帧 < 10:
		return false
	match _阶段:
		0:
			_管理 = _场景.get_node_or_null("窗口管理")
			_后端 = root.get_node_or_null("BackendConnection")
			_过程("窗口管理与后端都在", _管理 != null and _后端 != null)
			if _管理 == null or _后端 == null:
				push_error("前置条件不满足")
				quit(2)
				return true
			_窗 = _管理.call("取或建窗口", "竞技场英雄榜")
			_过程("建得出英雄榜那扇窗", _窗 != null)
			if _窗 == null:
				_收()
				return true
			_窗.call("open_page", "竞技场英雄榜")
			_阶段 = 1
			_等待 = 4
		1:
			if _等待 > 0:
				_等待 -= 1
				return false
			var 容器: Control = _窗.get("_content") as Control
			if 容器 != null:
				for 子 in 容器.get_children():
					if String(子.name).begins_with("竞技场英雄榜页"):
						_页 = 子 as Control
			_过程("页面建出来了（宿主._content 下）", _页 != null)
			if _页 == null:
				_收()
				return true
			## 逐件矩形（页面局部 = AS3 − 29，`整框: true`）
			_过程("内容底 = (8,9) 364×354", _矩("内容底", [8.0, 9.0, 364.0, 354.0]))
			_过程("面板 = (13,24) 354×309", _矩("面板", [13.0, 24.0, 354.0, 309.0]))
			_过程("滚动区 = (18,51) 342×277", _矩("滚动区", [18.0, 51.0, 342.0, 277.0]))
			_过程("关闭钮 = (159,336) 61×22", _矩("关闭钮", [159.0, 336.0, 61.0, 22.0]))
			_过程("表头四列文字（读屏幕值）",
					_文("表头排名") == "排名" and _文("表头名字") == "玩家姓名"
					and _文("表头等级") == "等级" and _文("表头趋势") == "趋势")
			_过程("表头四列宽 40/140/80/60",
					_矩("表头排名", [18.0, 29.0, 40.0, 20.0]) and _矩("表头名字", [58.0, 29.0, 140.0, 20.0])
					and _矩("表头等级", [198.0, 29.0, 80.0, 20.0]) and _矩("表头趋势", [278.0, 29.0, 60.0, 20.0]))
			_过程("三条竖分隔线在列边界 58/198/278（天然 2×20，没拉伸）",
					_矩("竖分隔1", [58.0, 31.0, 2.0, 20.0]) and _矩("竖分隔2", [198.0, 31.0, 2.0, 20.0])
					and _矩("竖分隔3", [278.0, 31.0, 2.0, 20.0]))
			_过程("横分隔线 = (18,49) 342×2（原版把 252 宽拉到 list 宽）", _矩("横分隔线", [18.0, 49.0, 342.0, 2.0]))
			_过程("关子没喂帧 ⇒ 一行都不画（不造空行）", _节点("滚动区/行列").get_child_count() == 0)
			_喂("2306:9:" + "@".join(榜行))
			_阶段 = 2
			_等待 = 4
		2:
			if _等待 > 0:
				_等待 -= 1
				return false
			var 列 := _节点("滚动区/行列")
			_过程("喂帧之后行数 = 3", 列.get_child_count() == 3)
			_过程("第1行 = 1 / 甲一 / 60",
					_文("滚动区/行列/行1/排名") == "1" and _文("滚动区/行列/行1/名字") == "甲一"
					and _文("滚动区/行列/行1/等级") == "60")
			_过程("行高 23、行宽 320、逐行往下排",
					_矩("滚动区/行列/行1", [0.0, 0.0, 320.0, 23.0])
					and _矩("滚动区/行列/行2", [0.0, 23.0, 320.0, 23.0])
					and _矩("滚动区/行列/行3", [0.0, 46.0, 320.0, 23.0]))
			_过程("名字那一列是 UI_ZHONG_SE #FCC399（不是白）",
					_色("滚动区/行列/行1/名字") == Color(0.988235, 0.764706, 0.6))
			_过程("趋势三档：↑绿 / ↓红 / -灰",
					_文("滚动区/行列/行1/趋势") == "↑" and _色("滚动区/行列/行1/趋势") == Color(0, 1, 0)
					and _文("滚动区/行列/行2/趋势") == "↓" and _色("滚动区/行列/行2/趋势") == Color(1, 0, 0)
					and _文("滚动区/行列/行3/趋势") == "-" and _色("滚动区/行列/行3/趋势") == Color(0.8, 0.8, 0.8))
			_过程("行容器高 = max(可视277, 3×23) ⇒ 没数据时也不会塌成 0",
					is_equal_approx(列.custom_minimum_size.y, 277.0))
			_抓图()
			var 钮 := _节点("关闭钮") as Control
			_钮位 = 钮.global_position + 钮.size * 0.5
			_阶段 = 3
			_等待 = 3
		3:
			if _等待 > 0:
				_等待 -= 1
				return false
			_点一下(_钮位)
			_阶段 = 4
			_等待 = 6
		4:
			if _等待 > 0:
				_等待 -= 1
				return false
			_过程("点「关闭」那扇真的关了（真点击，不是 emit_signal）", not bool(_窗.call("已打开")))
			_收()
			return true
	return false


func _点一下(位: Vector2) -> void:
	if 位 == Vector2.ZERO:
		push_error("拿不到关闭那颗的屏幕位 ⇒ 这一条没法判")
		return
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	root.push_input(移)
	var 按 := InputEventMouseButton.new()
	按.position = 位
	按.global_position = 位
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	root.push_input(按)
	var 放 := InputEventMouseButton.new()
	放.position = 位
	放.global_position = 位
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	root.push_input(放)


func _抓图() -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null or 图.is_empty():
		push_error("拿不到视口图像 —— 是不是加了 --headless？")
		return
	if 图.save_png(出图) != OK:
		push_error("存图失败：" + 出图)
		return
	print("英雄榜：%s（%dx%d）" % [出图, 图.get_width(), 图.get_height()])


func _收() -> void:
	var 红 := 0
	for 一 in _判:
		var 过: bool = bool(一[1]) if 一.size() > 1 else false
		if not 过:
			红 += 1
		print("  %-4s  %s" % ["通过" if 过 else "红", 一[0]])
	print("英雄榜自检：判 %d 条，红 %d 条" % [_判.size(), 红])
	quit(0 if 红 == 0 else 1)
