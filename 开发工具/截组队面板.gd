extends SceneTree
## 有头证据：左侧队伍面板（含队长标/红蓝条）+ 「我的队伍」整窗。
## 跑法：Godot --path . --script res://开发工具/截组队面板.gd（不能 --headless）

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 队伍窗 := preload("res://脚本/界面/窗口/组队/队伍窗.gd")
const 出目录 := "res://测试/截图/组队面板"


func _initialize() -> void:
	call_deferred("_跑")


func _拍() -> Image:
	return root.get_texture().get_image()


func _存(图: Image, 名: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	图.save_png(ProjectSettings.globalize_path(出目录 + "/" + 名))
	print("  saved ", 出目录 + "/" + 名, "  ", 图.get_width(), "x", 图.get_height())


func _跑() -> void:
	var 后 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if 后 == null or 会话 == null:
		print("缺 BackendConnection/GameSession")
		quit(1)
		return
	后.set("character_id", 7)
	会话.set("player_stats", {"id": 7, "name": "甲", "face": 1, "gender": 1,
		"job": 100, "level": 30, "hp": 90, "max_hp": 100, "mp": 40, "max_mp": 60})
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	await create_timer(0.4).timeout
	队伍窗.自己号 = 7
	队伍窗.自己名 = "甲"
	var 行甲 := "7&甲&100&30&-&0&0&1"
	var 行乙 := "8&乙&100&22&-&0&0&1"
	后.call("_handle_party_text", 59,
		PackedStringArray(["59", "15", "77", "8", "小队", 行甲 + "@" + 行乙]))
	后.call("_handle_bridge_text", "203:8:100:100:60:60")
	await create_timer(0.5).timeout
	var 全 := _拍()
	if 全 == null:
		print("拿不到视口图（是不是加了 --headless？）")
		quit(1)
		return
	print("视口 %s" % str(全.get_size()))
	_存(全.get_region(Rect2i(0, 108, 190, 70)), "面板_队长.png")
	var 格 := root.find_child("队伍格8", true, false) as Control
	if 格 != null:
		print("  格8 global=", 格.get_global_rect(), " 星=",
			格.get_node_or_null("队长星").get_global_rect() if 格.get_node_or_null("队长星") else "无")
	# 打开组队窗（真窗口管理路径）
	管理.call("打开", "组队")
	await create_timer(0.8).timeout
	var 主窗 := 管理.find_child("主窗口", true, false) as Control
	if 主窗 != null:
		var 框 := 主窗.get_global_rect()
		print("  主窗口 global=", 框)
		var 图 := _拍()
		_存(图.get_region(Rect2i(int(框.position.x), int(框.position.y),
			int(框.size.x), int(框.size.y))), "整窗.png")
		for 名 in ["自我退队", "添加成员", "任命队长", "请离队伍", "查看资料", "修改宣言钮"]:
			var b := 管理.find_child(名, true, false) as Control
			if b != null:
				print("  %s global=%s vis=%s" % [名, b.get_global_rect(), b.visible])
		for 名 in ["勾选1", "勾选2", "勾选3"]:
			var c := 管理.find_child(名, true, false) as CheckBox
			if c != null:
				print("  %s global=%s text=%s" % [名, c.get_global_rect(), c.text])
	else:
		print("没找到主窗口")
	# 收起态（真鼠标点折叠钮）
	var 折 := 管理.find_child("折叠钮", true, false) as TextureButton
	if 折 != null:
		var 心 := 折.get_global_rect().get_center()
		for 按 in [true, false]:
			var 事 := InputEventMouseButton.new()
			事.button_index = MOUSE_BUTTON_LEFT
			事.pressed = 按
			事.position = 心
			事.global_position = 心
			root.push_input(事)
			await process_frame
		await create_timer(0.2).timeout
		_存(_拍().get_region(Rect2i(0, 108, 190, 28)), "面板_收起.png")
		# 再点回展开
		for 按 in [true, false]:
			var 事 := InputEventMouseButton.new()
			事.button_index = MOUSE_BUTTON_LEFT
			事.pressed = 按
			事.position = 心
			事.global_position = 心
			root.push_input(事)
			await process_frame
		await create_timer(0.2).timeout
	# 普通队员（不是队长 ⇒ 没队长标）
	后.call("_handle_party_text", 59,
		PackedStringArray(["59", "7", "77", "7", "小队", 行甲 + "@" + 行乙]))
	await create_timer(0.3).timeout
	_存(_拍().get_region(Rect2i(0, 108, 190, 70)), "面板_普通.png")
	quit(0)
