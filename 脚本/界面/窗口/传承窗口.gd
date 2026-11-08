extends RefCounted

var 窗口

func _init(宿主) -> void:
	窗口 = 宿主

func 渲染() -> void:
	var 根 := VBoxContainer.new()
	根.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	根.add_theme_constant_override("separation", 8)
	窗口._content.add_child(根)
	var 分页 := HBoxContainer.new()
	分页.custom_minimum_size.y = 30.0
	分页.alignment = BoxContainer.ALIGNMENT_CENTER
	根.add_child(分页)
	for 序号 in 4:
		var 按钮 := Button.new()
		按钮.text = ["卡牌收集", "洞窟宝箱", "料理合成", "打坐双修"][序号]
		按钮.toggle_mode = true
		按钮.button_pressed = 窗口._legacy_tab == 序号
		按钮.custom_minimum_size = Vector2(110.0, 27.0)
		窗口._configure_standard_button(按钮)
		按钮.pressed.connect(_切换分页.bind(序号))
		分页.add_child(按钮)
	var 分隔 := HSeparator.new()
	根.add_child(分隔)
	match 窗口._legacy_tab:
		0: _渲染卡牌(根)
		1: _渲染宝箱(根)
		2: _渲染料理(根)
		3: _渲染打坐(根)

func _切换分页(序号: int) -> void:
	窗口._legacy_tab = 序号
	窗口._render_page()
	请求当前页()

func 请求当前页() -> void:
	if 窗口._backend == null or not bool(窗口._backend.in_game):
		return
	match 窗口._legacy_tab:
		0: 窗口._backend.request_card_level(窗口._card_level)
		1: 窗口._backend.request_chest_open(窗口._chest_id)
		3: 窗口._backend.request_heal_state()

func _渲染卡牌(根: VBoxContainer) -> void:
	var 工具栏 := HBoxContainer.new()
	工具栏.add_child(_标签("套卡等级", 12, Color("#f5ead6")))
	var 等级 := OptionButton.new()
	for 值 in [40, 50, 60, 70, 72, 74, 76, 78, 80]:
		等级.add_item("%d 级" % 值, 值)
		if 值 == 窗口._card_level:
			等级.select(等级.item_count - 1)
	等级.item_selected.connect(_选择卡牌等级.bind(等级))
	工具栏.add_child(等级)
	工具栏.add_spacer(false)
	var 查询 := _按钮("刷新套卡", 窗口._backend.request_card_level.bind(窗口._card_level))
	工具栏.add_child(查询)
	根.add_child(工具栏)

	var 状态: Dictionary = 窗口._backend.authoritative_card
	var 节点行 := HBoxContainer.new()
	节点行.custom_minimum_size.y = 34.0
	for 序号 in 5:
		var 节点状态 := _查找节点状态(状态.get("nodes", []), 序号)
		var 文本 := "套卡 %d" % (序号 + 1)
		if bool(节点状态.get("claimed", false)):
			文本 += "  已领"
		elif bool(节点状态.get("committed", false)):
			文本 += "  待领"
		var 节点按钮 := _按钮(文本, _选择卡牌节点.bind(序号))
		节点按钮.toggle_mode = true
		节点按钮.button_pressed = 序号 == 窗口._card_node
		节点按钮.custom_minimum_size.x = 106.0
		节点行.add_child(节点按钮)
	根.add_child(节点行)

	var 详情框 := Panel.new()
	详情框.size_flags_vertical = Control.SIZE_EXPAND_FILL
	窗口._configure_original_panel(详情框)
	根.add_child(详情框)
	var 详情 := VBoxContainer.new()
	详情.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	详情.offset_left = 8.0
	详情.offset_top = 8.0
	详情.offset_right = -8.0
	详情.offset_bottom = -8.0
	详情.add_theme_constant_override("separation", 5)
	详情框.add_child(详情)
	var 当前节点 := int(状态.get("node_id", -1))
	if 当前节点 != 窗口._card_node or int(状态.get("level", -1)) != 窗口._card_level:
		详情.add_child(_标签("选择套卡查看服务器记录。", 12, Color("#cbbda7")))
		return
	详情.add_child(_标签("第 %d 套    奖励属性点：%d" % [窗口._card_node + 1, int(状态.get("gain_ap", 0))], 13, Color("#ffc45c")))
	for 物品 in 状态.get("items", []) as Array:
		var 行 := HBoxContainer.new()
		var 名称 := _物品名(int(物品.get("item_id", 0)))
		# `submitted` = 服务端回帧的**已提交**数（原版 `getCurCount`）；以前这字段叫 `owned`，易误读
		var 已有 := int(物品.get("submitted", 0))
		var 需要 := int(物品.get("required", 0))
		行.add_child(_标签("%s  × %d" % [名称, 需要], 12, Color("#f5ead6"), 330.0))
		行.add_child(_标签("%d / %d" % [已有, 需要], 12, Color("#79dd86") if 已有 >= 需要 else Color("#ff8f7c"), 90.0))
		详情.add_child(行)
	var 操作 := HBoxContainer.new()
	操作.alignment = BoxContainer.ALIGNMENT_END
	var 提交 := _按钮("提交卡片", 窗口._backend.request_card_commit.bind(窗口._card_level, 窗口._card_node))
	提交.disabled = bool(状态.get("committed", false))
	var 领取 := _按钮("领取属性点", 窗口._backend.request_card_claim.bind(窗口._card_level, 窗口._card_node))
	领取.disabled = not bool(状态.get("committed", false)) or bool(状态.get("claimed", false))
	操作.add_child(提交)
	操作.add_child(领取)
	详情.add_child(操作)

func _渲染宝箱(根: VBoxContainer) -> void:
	var 工具栏 := HBoxContainer.new()
	工具栏.add_child(_标签("宝箱品阶", 12, Color("#f5ead6")))
	var 类型 := OptionButton.new()
	for 项 in [[10001, "D 级宝箱"], [10002, "C 级宝箱"], [10003, "B 级宝箱"]]:
		类型.add_item(项[1], 项[0])
		if int(项[0]) == 窗口._chest_id:
			类型.select(类型.item_count - 1)
	类型.item_selected.connect(_选择宝箱.bind(类型))
	工具栏.add_child(类型)
	工具栏.add_spacer(false)
	工具栏.add_child(_按钮("打开", 窗口._backend.request_chest_open.bind(窗口._chest_id)))
	工具栏.add_child(_按钮("关闭", 窗口._backend.request_chest_close.bind(窗口._chest_id)))
	工具栏.add_child(_按钮("全部领取", 窗口._backend.request_chest_claim_all.bind(窗口._chest_id)))
	根.add_child(工具栏)
	var 状态: Dictionary = 窗口._backend.authoritative_chest
	if int(状态.get("object_id", 0)) != 窗口._chest_id:
		根.add_child(_标签("打开宝箱后，服务器会固定本轮掉落。", 12, Color("#cbbda7")))
		return
	根.add_child(_标签("状态：%s" % ("已全部领取" if bool(状态.get("completed", false)) else "已开启"), 12, Color("#ffc45c")))
	var 列表 := VBoxContainer.new()
	列表.size_flags_vertical = Control.SIZE_EXPAND_FILL
	根.add_child(列表)
	for 物品 in 状态.get("items", []) as Array:
		var 行 := HBoxContainer.new()
		行.custom_minimum_size.y = 31.0
		行.add_child(_标签("%s  × %d" % [_物品名(int(物品.get("item_id", 0))), int(物品.get("quantity", 1))], 12, Color("#f5ead6"), 410.0))
		var 领取 := _按钮("已领取" if bool(物品.get("claimed", false)) else "领取", 窗口._backend.request_chest_claim.bind(窗口._chest_id, int(物品.get("slot", 0))))
		领取.disabled = bool(物品.get("claimed", false))
		行.add_child(领取)
		列表.add_child(行)

func _渲染料理(根: VBoxContainer) -> void:
	根.add_child(_标签("选择两种不同药剂，服务器将消耗 2000 金币并按原版配方制作。", 12, Color("#cbbda7")))
	var 材料 := HBoxContainer.new()
	材料.alignment = BoxContainer.ALIGNMENT_CENTER
	var 第一 := _材料选项(窗口._buff_slot1)
	var 第二 := _材料选项(窗口._buff_slot2)
	第一.item_selected.connect(_选择材料.bind(1, 第一))
	第二.item_selected.connect(_选择材料.bind(2, 第二))
	材料.add_child(第一)
	材料.add_child(_标签(" + ", 18, Color("#ffc45c")))
	材料.add_child(第二)
	根.add_child(材料)
	var 制作 := _按钮("开始制作", _发送料理)
	制作.disabled = 窗口._buff_slot1 <= 0 or 窗口._buff_slot2 <= 0 or 窗口._buff_slot1 == 窗口._buff_slot2
	制作.custom_minimum_size = Vector2(140.0, 32.0)
	var 操作 := HBoxContainer.new()
	操作.alignment = BoxContainer.ALIGNMENT_CENTER
	操作.add_child(制作)
	根.add_child(操作)
	var 状态: Dictionary = 窗口._backend.authoritative_buff_fusion
	if not 状态.is_empty():
		var 结果 := "制作成功：%s" % _物品名(int(状态.get("item_id", 0))) if bool(状态.get("success", false)) else "制作失败：%s" % String(状态.get("code", "unknown"))
		根.add_child(_标签(结果, 13, Color("#79dd86") if bool(状态.get("success", false)) else Color("#ff8f7c")))

func _渲染打坐(根: VBoxContainer) -> void:
	var 状态: Dictionary = 窗口._backend.authoritative_heal
	var 模式 := int(状态.get("state", 0))
	根.add_child(_标签("当前状态：%s    心法：%d" % [["未打坐", "单人打坐", "双修打坐"][clampi(模式, 0, 2)], int(状态.get("xinfa_id", 0))], 13, Color("#ffc45c")))
	var 基础 := HBoxContainer.new()
	基础.add_child(_按钮("开始打坐", 窗口._backend.request_heal_start))
	基础.add_child(_按钮("停止打坐", 窗口._backend.request_heal_stop))
	基础.add_spacer(false)
	基础.add_child(_标签("心法编号", 12, Color("#f5ead6")))
	var 心法 := SpinBox.new()
	心法.min_value = 0
	心法.max_value = 9999
	心法.value = int(状态.get("xinfa_id", 0))
	心法.custom_minimum_size.x = 100.0
	基础.add_child(心法)
	基础.add_child(_按钮("切换", _切换心法.bind(心法)))
	根.add_child(基础)
	var 邀请 := HBoxContainer.new()
	邀请.add_child(_标签("同地图角色 ID", 12, Color("#f5ead6")))
	var 目标 := SpinBox.new()
	目标.min_value = 1
	目标.max_value = 2147483647
	目标.value = maxi(1, 窗口._heal_target)
	目标.custom_minimum_size.x = 150.0
	目标.value_changed.connect(func(值): 窗口._heal_target = int(值))
	邀请.add_child(目标)
	邀请.add_child(_按钮("邀请双修", _邀请双修.bind(目标)))
	根.add_child(邀请)
	var 邀请者 := int(状态.get("pending_inviter_id", 0))
	if 邀请者 > 0:
		var 待处理 := HBoxContainer.new()
		待处理.add_child(_标签("%s（ID %d）邀请你双修" % [String(状态.get("pending_inviter_name", "玩家")), 邀请者], 12, Color("#79dd86"), 350.0))
		待处理.add_child(_按钮("接受", 窗口._backend.request_double_heal_accept.bind(邀请者)))
		待处理.add_child(_按钮("拒绝", 窗口._backend.request_double_heal_deny.bind(邀请者)))
		根.add_child(待处理)

func _选择卡牌等级(index: int, 选项: OptionButton) -> void:
	窗口._card_level = 选项.get_item_id(index)
	窗口._card_node = 0
	窗口._backend.request_card_level(窗口._card_level)

func _选择卡牌节点(节点: int) -> void:
	窗口._card_node = 节点
	窗口._backend.request_card_node(窗口._card_level, 节点)

func _选择宝箱(index: int, 选项: OptionButton) -> void:
	窗口._chest_id = 选项.get_item_id(index)
	窗口._render_page()

func _选择材料(index: int, 序号: int, 选项: OptionButton) -> void:
	var 槽位 := 选项.get_item_id(index)
	if 序号 == 1:
		窗口._buff_slot1 = 槽位
	else:
		窗口._buff_slot2 = 槽位
	窗口._render_page()

func _发送料理() -> void:
	窗口._backend.request_buff_fusion(窗口._buff_slot1, 窗口._buff_slot2)

func _切换心法(心法: SpinBox) -> void:
	窗口._backend.request_xinfa_change(int(心法.value))

func _邀请双修(目标: SpinBox) -> void:
	窗口._heal_target = int(目标.value)
	窗口._backend.request_double_heal_invite(窗口._heal_target)

func _查找节点状态(节点列表: Array, 节点: int) -> Dictionary:
	for 状态 in 节点列表:
		if int((状态 as Dictionary).get("node_id", -1)) == 节点:
			return 状态
	return {}

func _材料选项(当前槽位: int) -> OptionButton:
	var 选项 := OptionButton.new()
	选项.custom_minimum_size = Vector2(220.0, 30.0)
	选项.add_item("选择背包药剂", 0)
	for 物品 in 窗口._session.inventory:
		var 字典 := 物品 as Dictionary
		var 物品编号 := int(字典.get("numeric_id", 字典.get("item_id", 字典.get("id", 0))))
		if 物品编号 not in [15003001, 15003002, 15003003, 15003004, 15003009, 15003010, 15003011, 15003012]:
			continue
		var 槽位 := int(字典.get("slot_index", 字典.get("position", 0)))
		选项.add_item("%s  × %d（槽 %d）" % [String(字典.get("name", _物品名(物品编号))), int(字典.get("quantity", 1)), 槽位], 槽位)
		if 槽位 == 当前槽位:
			选项.select(选项.item_count - 1)
	return 选项

func _物品名(物品编号: int) -> String:
	if 窗口._session != null:
		for 物品 in 窗口._session.inventory:
			var 字典 := 物品 as Dictionary
			if int(字典.get("numeric_id", 字典.get("item_id", 字典.get("id", 0)))) == 物品编号:
				return String(字典.get("name", "物品 %d" % 物品编号))
	return "物品 %d" % 物品编号

func _按钮(文本: String, 回调: Callable) -> Button:
	var 按钮 := Button.new()
	按钮.text = 文本
	按钮.custom_minimum_size = Vector2(92.0, 27.0)
	窗口._configure_standard_button(按钮)
	按钮.pressed.connect(回调)
	return 按钮

func _标签(文本: String, 字号: int, 颜色: Color, 最小宽: float = 0.0) -> Label:
	var 标签 := Label.new()
	标签.text = 文本
	标签.custom_minimum_size.x = 最小宽
	窗口._configure_label(标签, 字号, 颜色)
	return 标签
