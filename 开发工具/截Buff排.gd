extends SceneTree

## 有头证据：把头像面板摆进屏幕，喂与原版截图同样四格（系统双倍经验/精华、单人打坐、浓雾），
## 截 (240,0)-(520,100) 一比一 + 8 倍 NEAREST，另存整屏。
##
## 为什么要有它：离线门只判节点属性；"图标有没有底、排在哪、图标多大"必须看像素。
## 判据：4 格可见；格左上角 = (260 + i*41, 0)；格宽 40；图标 40×40 且居中；
## 天气永久无扇形、系统双倍有扇形。数字全部打印，退出码 0/1。
##
## 用法：
##   Godot --path . --script res://开发工具/截Buff排.gd -- --出目录=res://测试/截图/buff排1025

const 出图 := "res://测试/截图/buff排1025"

var _失败: Array[String] = []
var _断言 := 0
var _出目录 := 出图

func _initialize() -> void:
	_跑()

func _记(条件: bool, 话: String) -> void:
	_断言 += 1
	if not 条件:
		_失败.append(话)

func _参数(名: String) -> String:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--" + 名 + "="):
			return s.split("=", true)[1]
	return ""

func _跑() -> void:
	var 指定的 := _参数("出目录")
	if not 指定的.is_empty():
		_出目录 = 指定的
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_出目录))
	var 视口尺寸 := Vector2(960, 560)
	root.size = Vector2i(int(视口尺寸.x), int(视口尺寸.y))
	await process_frame

	# 背景：给半透明格底一块可见的"世界"，别用黑底假装（黑底看不出 alpha）
	var 背景 := ColorRect.new()
	背景.color = Color(0.22, 0.36, 0.22)
	背景.position = Vector2.ZERO
	背景.size = 视口尺寸
	root.add_child(背景)

	var 面板 := (load("res://场景/界面/头像面板.tscn") as PackedScene).instantiate()
	root.add_child(面板)
	await process_frame
	await process_frame

	var 表: Dictionary = (load("res://脚本/单例/游戏数据.gd") as GDScript).取表("状态图标").get("表", {}) as Dictionary
	var 现在 := Time.get_ticks_msec()
	var 列 := [
		# 原版截图里的前两格：1811 系统双倍经验 / 双倍精华（有限时长 ⇒ 有扇形）
		{"icon": String((表.get("System/0", {}) as Dictionary).get("贴图", "")),
			"name": "系统双倍经验", "desc": "活动时间段内进行打怪或打坐，可获得双倍经验收益。",
			"type": 0, "skill_id": 10000000, "remain_time": 2400, "total_time": 3600,
			"expires_at_msec": 现在 + 2400 * 1000, "kind": "system"},
		{"icon": String((表.get("System/1", {}) as Dictionary).get("贴图", "")),
			"name": "系统双倍精华", "desc": "活动时间段内进行打坐，可获得双倍查克拉精华收益。",
			"type": 0, "skill_id": 10000001, "remain_time": 1200, "total_time": 3600,
			"expires_at_msec": 现在 + 1200 * 1000, "kind": "system"},
		# 单人打坐（Heal/0 与技能图 9000101 同图；这里直接喂图标路径）
		{"icon": "res://素材/状态图标/Buff_Heal_0/Buff_Heal_0_icon.png",
			"name": "单人打坐", "desc": "", "type": 0, "skill_id": 9000101,
			"remain_time": 2100000001, "total_time": 2100000001, "kind": "heal"},
	]
	# 到达序：先到系统双倍 + 打坐，隔两帧再让天气到（原版就是这样一帧一条）
	面板.call("_render_status_effects", -1, 列, [])
	await process_frame
	await process_frame
	OS.delay_msec(4)
	面板.call("_render_status_effects", 9, 列, [])
	await process_frame
	await process_frame

	var 格子: Array = 面板.get("_status_slots")
	_记(格子.size() == 18, "状态格应有 18 个")
	var 容器 := 面板.get_node_or_null("头像区域/状态效果") as GridContainer
	_记(容器 != null and 容器.get_global_rect().position == Vector2(260, 0),
		"状态排屏幕位应为 (260,0)，实为 %s" % (str(容器.get_global_rect().position) if 容器 != null else "缺容器"))
	# 4 格可见、位置 41 步距（天气后到，排第 3 格）
	var 期望图 := [
		"res://素材/状态图标/Buff_System_0/Buff_System_0_icon.png",
		"res://素材/状态图标/Buff_System_1/Buff_System_1_icon.png",
		"res://素材/状态图标/Buff_Heal_0/Buff_Heal_0_icon.png",
		"res://素材/状态图标/Buff_Weather_9/Buff_Weather_9_icon.png",
	]
	for i in 4:
		var 格 := 格子[i] as TextureRect
		_记(bool(格.visible), "第 %d 格不可见" % i)
		var 屏幕位 := 格.get_global_rect().position
		_记(absf(屏幕位.x - float(260 + i * 41)) < 0.01 and absf(屏幕位.y) < 0.01,
			"第 %d 格屏幕位应为 (%d,0)，实为 %s" % [i, 260 + i * 41, str(屏幕位)])
		var 图 := 格.get_node_or_null("图标") as TextureRect
		_记(图 != null and 图.texture != null and String(图.texture.resource_path) == 期望图[i],
			"第 %d 格图标不是预期那张：%s" % [i, 图.texture.resource_path if 图 != null and 图.texture != null else "（空）"])
		if 图 != null:
			_记(Vector2(图.position) == Vector2.ZERO, "第 %d 格 40×40 图标应居中 (0,0)，实为 %s" % [i, str(图.position)])
		var 扇 := 格.get_node_or_null("扇形") as ColorRect
		_记(扇 != null, "第 %d 格缺扇形" % i)
		if 扇 != null:
			if i < 2:
				_记(扇.visible, "第 %d 格（系统双倍）是有限时长，应有扇形" % i)
			else:
				_记(not 扇.visible, "第 %d 格是打坐/天气（永久），不该有扇形" % i)

	# 截图：整屏 + 裁排（**先拍干净的一排**，悬停提示另行一张，别糊在排上）
	await process_frame
	var 图 := root.get_texture().get_image()
	var 整路 := ProjectSettings.globalize_path(_出目录.path_join("整屏.png"))
	图.save_png(整路)
	var 裁 := 图.get_region(Rect2i(240, 0, 280, 100))
	裁.save_png(ProjectSettings.globalize_path(_出目录.path_join("buff排.png")))
	裁.resize(280 * 8, 100 * 8, Image.INTERPOLATE_NEAREST)
	裁.save_png(ProjectSettings.globalize_path(_出目录.path_join("buff排8x.png")))

	# 真悬停：把鼠标推进第一格，原版提示框（MToolTipTextWithTitle）要弹出来。
	# ⚠ 必须用真 InputEventMouseMotion：`mouse_entered.emit()` 是演的，测不到"子节点有没有挡住拾取"。
	var 格0 := 格子[0] as TextureRect
	var 中心 := 格0.get_global_rect().get_center()
	var 先 := InputEventMouseMotion.new()
	先.position = Vector2(2, 2)
	先.global_position = 先.position
	root.push_input(先)
	await process_frame
	var 动 := InputEventMouseMotion.new()
	动.position = 中心
	动.global_position = 中心
	root.push_input(动)
	await process_frame
	await process_frame
	var 提示 := 面板.get_node_or_null("头像区域/buff提示框") as Control
	_记(提示 != null, "缺 buff 提示框节点")
	if 提示 != null:
		_记(bool(提示.visible), "鼠标真移到第一格上，原版提示框没弹出来")
		var 题 := 提示.get_node_or_null("标题") as RichTextLabel
		_记(题 != null and 题.text.contains("系统双倍经验"),
			"悬停提示框标题不是第一格那条：%s" % (题.text if 题 != null else "（缺标题）"))
		await process_frame
		root.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(_出目录.path_join("悬停提示.png")))

	print("出图目录：", ProjectSettings.globalize_path(_出目录))
	print("Buff 排证据：%d 项断言，红 %d 条" % [_断言, _失败.size()])
	for 条 in _失败:
		print("  FAIL " + 条)
	quit(0 if _失败.is_empty() else 1)
