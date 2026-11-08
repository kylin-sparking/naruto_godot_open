extends Node
## 真窗口点击诊断：打开说明窗，发一次**真实**鼠标事件，看 GUI 到底把点击判给了谁。
##
## 用法（必须真窗口，不能 --headless）：
##   Godot --path <工程> res://开发工具/真窗口点击诊断.tscn
##
## 关键输出：
##   hovered=谁  ⇒ 引擎认为鼠标正悬停在哪个控件上
##   ⇒ 如果不是那颗钮，就说明有东西压在上面（或被判给页面根）—— 与用户报的现象对照。

func _ready() -> void:
	_跑()


func 打通可见(根: Node) -> void:
	if 根 is CanvasItem:
		(根 as CanvasItem).visible = true
	for 子 in 根.get_children():
		打通可见(子)


func _跑() -> void:
	print("=== 真窗口点击诊断开始 ===")
	print("视口=%s 窗口=%s" % [str(get_viewport().get_visible_rect().size), str(DisplayServer.window_get_size())])

	var 场 := load("res://场景/界面/功能窗口.tscn") as PackedScene
	var 窗: Node = 场.instantiate()
	add_child(窗)
	await get_tree().process_frame
	打通可见(窗)

	# 关掉"下次跳过本说明"，保证走说明窗那条路（结束不还原：这是诊断场景，用的是临时存档）
	var 会话 := get_node_or_null("/root/GameSession")
	if 会话 != null:
		会话.call("update_setting", "family_flag_help_skip", false)
	await get_tree().process_frame

	窗.call("_show_guild_action", "家族旗帜")
	await get_tree().process_frame
	await get_tree().process_frame
	打通可见(窗)

	var 壳: GDScript = load("res://脚本/界面/窗口/家族/家族子窗壳.gd") as GDScript
	var 页: Control = 壳.取内容(窗, "家族旗帜帮助窗") as Control
	if 页 == null:
		print("!! 说明窗没开"); get_tree().quit(1); return
	var 钮 := 页.get_node_or_null("钮进入旗帜") as BaseButton
	if 钮 == null:
		print("!! 找不到钮进入旗帜"); get_tree().quit(1); return

	var 心 := (钮 as Control).get_global_rect().get_center()
	print("钮 rect=%s 心=%s 可见=%s 禁用=%s" % [
		str((钮 as Control).get_global_rect()), str(心),
		(钮 as Control).is_visible_in_tree(), 钮.disabled])

	# ① 鼠标移过去的真实事件
	var 移 := InputEventMouseMotion.new()
	移.position = 心
	移.global_position = 心
	Input.parse_input_event(移)
	await get_tree().process_frame
	await get_tree().process_frame
	var 悬 := get_viewport().gui_get_hovered_control()
	print("① 移过去后 hovered = %s（期望是 钮进入旗帜）" % (str(悬.name) if 悬 != null else "（null）"))
	if 悬 != null:
		print("   hovered 的类型=%s rect=%s mouse_filter=%s" % [
			悬.get_class(), str((悬 as Control).get_global_rect()),
			(悬 as Control).mouse_filter])

	# ② 按下 + 抬起（真实管线）
	var 下 := InputEventMouseButton.new()
	下.button_index = MOUSE_BUTTON_LEFT
	下.pressed = true
	下.position = 心
	下.global_position = 心
	Input.parse_input_event(下)
	await get_tree().process_frame
	var 上 := InputEventMouseButton.new()
	上.button_index = MOUSE_BUTTON_LEFT
	上.pressed = false
	上.position = 心
	上.global_position = 心
	Input.parse_input_event(上)
	await get_tree().process_frame
	await get_tree().process_frame
	print("② 真实点击后 ⇒ 旗帜窗已开=%s（true=点击真的到了钮）" % 壳.已开(窗, "家族旗帜窗"))

	print("=== 诊断结束 ===")
	get_tree().quit(0)
