extends SceneTree

## 临时量具：写轮眼页那列阶段钮**到底滚不滚得动**。
## 跑：Godot --headless --path . --script res://开发工具/量写轮眼滚不滚.gd

func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _i in 5:
		await process_frame
	var 会话: Node = root.get_node_or_null("/root/GameSession")
	会话.cultivation_states["写轮眼"] = {"stage": 3, "count": 1, "blessing": 0}
	var 管理: Node = 场景.get_node_or_null("窗口管理")
	var 窗 = 管理.call("取或建窗口", "人物")
	管理.call("打开", "人物")
	for _i in 4:
		await process_frame
	窗.call("_set_character_main_tab", 2)
	窗.call("_set_character_sub_tab", 0)
	for _i in 3:
		await process_frame
	var 内容 := 窗.get("_content") as Control
	var 页面 := 内容.find_child("原版人物窗口内容", true, false) as Control
	var 面板 := 页面.get_node_or_null("人物扩展页") as Panel
	var 页: Control = 面板.get_node_or_null("写轮眼内容") as Control if 面板 != null else null
	if 页 == null:
		print("查无写轮眼页")
		quit(1)
		return
	var 滚 := 页.get_node_or_null("滚动按钮列表") as ScrollContainer
	if 滚 == null:
		print("查无 滚动按钮列表")
		quit(1)
		return
	var 内 := 滚.get_node_or_null("阶段列表") as Control
	var 条 := 滚.get_v_scroll_bar() as VScrollBar
	if 内 == null or 条 == null:
		print("缺件：内容=", 内, " 滚动条=", 条)
		quit(1)
		return
	var 首 := 内.get_node_or_null("单勾玉") as Control
	var 末 := 内.get_node_or_null("净眼") as Control
	print("页根 ", 页.name, " 尺寸 ", 页.size)
	print("滚动框 位置 ", 滚.position, " 尺寸 ", 滚.size,
		" 纵模式 ", 滚.vertical_scroll_mode, " 横模式 ", 滚.horizontal_scroll_mode)
	print("内容 位置 ", 内.position, " 尺寸 ", 内.size, " 最小 ", 内.get_combined_minimum_size())
	print("滚动条 min=", 条.min_value, " max=", 条.max_value, " page=", 条.page, " value=", 条.value,
		" 可见=", 条.visible)
	print("框全局矩形 ", 滚.get_global_rect())
	for 试: int in [30, 60, 120, 112, 999]:
		滚.scroll_vertical = 试
		await process_frame
		print("设 ", 试, " ⇒ scroll_vertical=", 滚.scroll_vertical,
			" 条.value=", 条.value, " 内容.position=", 内.position,
			" 首钮全局y=", (null if 首 == null else str(首.global_position.y)),
			" 末钮全局y=", (null if 末 == null else str(末.global_position.y)))
	# 滚轮回事件（玩家用滚轮的那条路）：视口级投递，窗是 CanvasLayer 没有 push_input
	滚.scroll_vertical = 0
	await process_frame
	var 中 := 滚.get_global_rect().get_center()
	var 事 := InputEventMouseButton.new()
	事.button_index = MOUSE_BUTTON_WHEEL_DOWN
	事.position = 中
	事.global_position = 中
	事.pressed = true
	var 前: Vector2 = 内.position
	root.push_input(事, true)
	await process_frame
	print("滚轮一下 内容.position ", 前, " → ", 内.position, " 条.value=", 条.value)
	var 事2 := InputEventMouseButton.new()
	事2.button_index = MOUSE_BUTTON_WHEEL_UP
	事2.position = 中
	事2.global_position = 中
	事2.pressed = true
	root.push_input(事2, true)
	await process_frame
	print("滚轮反向 内容.position ", 内.position)
	# 原版一格滚轮 = `_pageScrollSize` = `lineScrollSize` = 4 像素
	# （Box.as:262 把 lineScrollSize 当 param4 传给 setScrollProperties ⇒ ScrollBar.as:310 存进 _pageScrollSize；
	#   ScrollBar.as:317-319 `pageScrollSize` 非 0 时就用它；Box.as:177 `scrollPosition -= delta * pageScrollSize`）
	滚.scroll_vertical = 0
	滚.scroll_vertical_custom_step = 4.0
	await process_frame
	var 事3 := InputEventMouseButton.new()
	事3.button_index = MOUSE_BUTTON_WHEEL_DOWN
	事3.position = 中
	事3.global_position = 中
	事3.pressed = true
	root.push_input(事3, true)
	await process_frame
	print("自定义步长 4 之后滚轮一下 ⇒ 条.value=", 条.value, " 内容.position=", 内.position)
	滚.scroll_vertical_custom_step = 0.0
	滚.scroll_vertical = 0
	await process_frame
	var 事4 := InputEventMouseButton.new()
	事4.button_index = MOUSE_BUTTON_WHEEL_DOWN
	事4.position = 中
	事4.global_position = 中
	事4.pressed = true
	root.push_input(事4, true)
	await process_frame
	print("自定义步长 0（引擎默认）滚轮一下 ⇒ 条.value=", 条.value)
	quit(0)
