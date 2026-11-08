extends SceneTree

## 2026-11-04 装备打造面板本轮的客户端回归（用户那一串报修里除橙装窗以外的部分）：
##
##   A 右栏「可打造装备」列表只留标准 12 槽 —— 昆虫/灵器/忍具/徽章/玉链/变身/宠物/羁绊
##     一个都不许混进来（原版 `EquipManager.isStrengthListEquip:254-287` 先 `as EqpData`
##     转不出的全 return false）。旧版只排了 120/121/141 与宠物槽。
##   B 六个子面板的「购买」都是原版 `ItemCaiLiaoBox` 的 37×22，不吃
##     `_configure_standard_button` 默认的 57 宽（用户报"每个购买键都有点偏右"的根因）。
##   C 天生页：天生值 == 基础值后「开始强化」禁用（用户报"满了还能点、还扣钱和料"）；
##     基础值缺失（0）不算满，别把没数据锁死。
##   D 精炼页：11 星（强化星级）与 forge_additive_ratio 500（附加属性）满后禁用；
##     10 星 / 499 仍可点。
##   E 洗附加属性页：点开始重置前记旧列表，装备帧写回新列表后摊出**旧/新两列**
##     （类型和数值逐条比；换类型保持白、不打标记；完全没变则收起对照）。
##
## 运行：Godot --headless --path . --script res://测试/装备打造面板本轮回归测试.gd

const 装备部位 := preload("res://脚本/单例/装备部位.gd")
const 装备打造表 := preload("res://脚本/界面/装备打造表.gd")
const 快照 := "res://测试/基线/装备快照/武器_精炼.json"
const 购买钮尺寸 := Vector2(37.0, 22.0)

var _失败: Array[String] = []
var _受检 := 0
var _会话: Node = null
var _秒 := 0.0


class 打造后端 extends "res://脚本/单例/后端连接.gd":
	var 请求: Array = []
	var 允许发送 := true

	func request_item_change(action: int, args: Array = []) -> bool:
		if not 允许发送:
			return false
		请求.append([action, args.duplicate()])
		return true


func _initialize() -> void:
	call_deferred("_跑")


## 看门狗：_跑 是协程，中途一次运行期错误就会静默停住、SceneTree 永远不退出。
func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		printerr("装备打造面板本轮回归测试：看门狗超时（90s）—— 中途崩了没走到收尾")
		quit(1)
		return true
	return false


func _跑() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _序号 in 5:
		await process_frame

	_装快照()
	_会话 = root.get_node_or_null("/root/GameSession")
	if _会话 == null:
		_停("拿不到 GameSession")
		return
	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗 = 管理.call("取或建窗口", "装备强化") if 管理 != null else null
	if 窗 == null:
		_停("拿不到装备强化窗")
		return
	管理.call("打开", "装备强化")
	窗.call("open_page", "装备强化")
	await process_frame

	# —— A：右栏只留标准 12 槽 ——
	var 拒收 := {
		"01310001": "昆虫", "20100001": "灵器", "65000001": "忍具", "01410004": "徽章",
		"01200040": "玉链", "01210441": "变身", "02010060": "宠物装备", "19010001": "羁绊",
	}
	for 号 in 拒收:
		_查(not bool(窗.call("_算不算部位列表装备", {"id": String(号)})),
			"A：%s（%s）不该进右栏打造列表" % [号, 拒收[号]])
	for 号 in ["01010013", "01020013", "01040013"]:
		_查(bool(窗.call("_算不算部位列表装备", {"id": String(号)})),
			"A：标准槽装备 %s 该进右栏（判据不能一刀切）" % 号)
	var 背包: Array[Dictionary] = []
	var 序号 := 0
	for 号 in 拒收:
		序号 += 1
		背包.append({"id": String(号), "name": 拒收[号], "quantity": 1, "slot_index": 序号})
	背包.append({"id": "01010013", "name": "标准武器", "quantity": 1, "slot_index": 99})
	_会话.inventory = 背包
	var 列表: Array = 窗.call("_部位列表物品")
	# 列表 = 先身上、后背包：快照里穿着 1 件标准武器 + 刚才塞进背包的 1 件 = 2 件。
	_查(列表.size() == 2, "A：右栏列表只该剩 2 件标准武器（身上 1 + 背包 1），实测 %d 件" % 列表.size())
	var 全是标准 := true
	for 行 in 列表:
		# 快照里穿着的那件是 01010023、背包里塞的是 01010013，两把都是标准武器；
		# 这里只核"留下的每一件都过得了一道闸门"。
		if not bool(窗.call("_算不算部位列表装备", 行)):
			全是标准 = false
	_查(全是标准, "A：右栏剩的都该是标准武器，实测 %s" % str(列表.map(func(行): return (行 as Dictionary).get("id", ""))))
	_会话.inventory.clear()

	# —— B：每个子面板的「购买」都是 37×22 ——
	# 页签 0 强化 / 4 天生用共用左栏；1、2 洗共用同一面板；3 进阶；5 刻印；6 精炼。
	var 购买路径 := {
		0: ["内容容器/材料框/购买"],
		1: ["面板容器/原版装备洗附加属性页/材料框/材料一/购买",
			"面板容器/原版装备洗附加属性页/材料框/材料二/购买"],
		2: ["面板容器/原版装备洗附加属性页/材料框/材料一/购买"],
		3: ["面板容器/原版装备进阶页/材料一/购买", "面板容器/原版装备进阶页/材料二/购买"],
		4: ["内容容器/材料框/购买"],
		5: ["面板容器/原版装备刻印页/材料框/材料一/购买"],
		6: ["面板容器/原版装备精炼页/材料框/材料一/购买"],
	}
	for 页签 in 购买路径:
		窗.call("_set_strengthen_tab", 页签)
		await process_frame
		var 页 := _页(窗)
		if 页 == null:
			_失败.append("B：页签 %d 取不到页面" % 页签)
			continue
		for 路径 in 购买路径[页签]:
			var 钮 := 页.get_node_or_null(路径) as Button
			if 钮 == null:
				_失败.append("B：页签 %d 找不到购买钮 %s" % [页签, 路径])
				continue
			_查(钮.custom_minimum_size.is_equal_approx(购买钮尺寸),
				"B：页签 %d 的购买钮最小尺寸应是 37×22（原版 btn_width_two），实测 %s"
				% [页签, str(钮.custom_minimum_size)])

	# —— C：天生满后禁用 ——
	窗.call("_set_strengthen_tab", 4)
	await process_frame
	窗.call("_select_strengthen_slot", -1)
	await process_frame
	var 天生页 := _页(窗)
	var 执行钮 := 天生页.get_node_or_null("开始强化") as Button if 天生页 != null else null
	if 执行钮 == null:
		_停("C：天生页找不到执行按钮")
		return
	_查(not 执行钮.disabled, "C：天生 0/116 未满，按钮不该禁用")
	_会话.equipped_items[-1]["born_attr_value"] = 116
	窗.call("_refresh_current")
	await process_frame
	await process_frame
	执行钮 = (_页(窗).get_node("开始强化") as Button)
	_查(执行钮.disabled, "C：天生 116/116 已满，按钮必须禁用（用户报满后还能点）")
	_会话.equipped_items[-1]["born_attr_value"] = 115
	窗.call("_refresh_current")
	await process_frame
	await process_frame
	执行钮 = (_页(窗).get_node("开始强化") as Button)
	_查(not 执行钮.disabled, "C：天生 115/116 未满，按钮该恢复可点")
	_会话.equipped_items[-1]["base_attr_value"] = 0
	_会话.equipped_items[-1]["born_attr_value"] = 0
	窗.call("_refresh_current")
	await process_frame
	await process_frame
	执行钮 = (_页(窗).get_node("开始强化") as Button)
	_查(not 执行钮.disabled, "C：基础值缺失（0）不算满，别把没数据锁死")

	# —— D：精炼两项满级禁用 ——
	_会话.equipped_items[-1]["base_attr_value"] = 116
	_会话.equipped_items[-1]["born_attr_value"] = 0
	_会话.equipped_items[-1]["strengthen"] = 11
	_会话.equipped_items[-1]["forge_additive_ratio"] = 3
	窗.call("_set_strengthen_tab", 6)
	await process_frame
	窗.call("_select_strengthen_slot", -1)
	await process_frame
	窗.set("_精炼项选中", 装备打造表.精炼项_强化星级)
	窗.call("_refresh_current")
	await process_frame
	await process_frame
	var 精炼钮 := _精炼按钮(窗)
	if 精炼钮 == null:
		_停("D：精炼页找不到「精炼」按钮")
		return
	_查(精炼钮.disabled, "D：11 星时「提升强化星级」必须禁用（用户报满 11 星还能点）")
	_会话.equipped_items[-1]["strengthen"] = 10
	窗.call("_refresh_current")
	await process_frame
	await process_frame
	_查(not _精炼按钮(窗).disabled, "D：10 星（11 星封顶前一级）该仍可点")
	_会话.equipped_items[-1]["strengthen"] = 11
	窗.set("_精炼项选中", 装备打造表.精炼项_附加属性)
	_会话.equipped_items[-1]["forge_additive_ratio"] = 500
	窗.call("_refresh_current")
	await process_frame
	await process_frame
	_查(_精炼按钮(窗).disabled, "D：附加属性 ratio 500（满）时必须禁用")
	_会话.equipped_items[-1]["forge_additive_ratio"] = 499
	窗.call("_refresh_current")
	await process_frame
	await process_frame
	_查(not _精炼按钮(窗).disabled, "D：附加属性 ratio 499 该仍可点")

	# —— D2：切精炼下拉只就地刷新，不许整页重建 ——
	# 整页重建会 free 掉面板和它的子节点；外面（包括本门）还攥着旧句柄时就会
	# "previously freed instance" 并把整条门卡死在 `_run` 里（2026-11-07 实测）。
	窗.call("_set_strengthen_tab", 6)
	await process_frame
	窗.call("_select_strengthen_slot", -1)
	await process_frame
	await process_frame
	var 稳页 := _页(窗)
	var 稳面板 := 稳页.get_node_or_null("面板容器/原版装备精炼页") as Control if 稳页 != null else null
	if 稳面板 == null:
		_停("D2：精炼页没建出面板")
		return
	var 稳注意 := 稳面板.get_node("注意") as RichTextLabel
	var 稳下拉 := 稳面板.get_node("材料框/精炼项") as OptionButton
	var 稳自动 := 稳面板.get_node("自动精炼") as Button
	稳下拉.selected = 0
	稳下拉.item_selected.emit(0)
	await process_frame
	_查(is_instance_valid(稳面板), "D2：切精炼下拉后面板被整页重建 free 掉了（应就地刷新）")
	_查(稳自动.text == "自动精炼", "D2：切下拉要先停自动，按钮文案应回「自动精炼」")
	var 附加注意 := 稳注意.text
	稳下拉.selected = 1
	稳下拉.item_selected.emit(1)
	await process_frame
	_查(is_instance_valid(稳面板), "D2：第二次切下拉又把面板重建了")
	_查(稳注意.text != 附加注意, "D2：切到「提升强化星级」后注意段没换")
	_查(_精炼按钮(窗).disabled, "D2：strengthen=11 时切到强化星级，精炼按钮该禁用")
	稳下拉.selected = 0
	稳下拉.item_selected.emit(0)
	await process_frame
	_查(not _精炼按钮(窗).disabled, "D2：ratio=499 时切回附加属性，精炼按钮该恢复可点")

	# —— E：洗附加属性前后对照 ——
	_会话.equipped_items[-1]["plus_attributes"] = [
		{"attribute_type": 4, "attribute_value": 18},
		{"attribute_type": 6, "attribute_value": 5},
	]
	窗.call("_set_strengthen_tab", 1)
	await process_frame
	窗.call("_select_strengthen_slot", -1)
	await process_frame
	await process_frame
	var 洗面板 := _洗属性面板(窗)
	if 洗面板 == null:
		_停("E：洗附加属性页没建出面板")
		return
	_查((洗面板.get_node("说明") as CanvasItem).visible, "E：洗之前该显示说明")
	for 名 in ["原属性", "新属性", "对照区"]:
		_查(not (洗面板.get_node(名) as CanvasItem).visible, "E：洗之前不该显示 %s" % 名)
	窗.call("_开始洗属性对照", _会话.equipped_items[-1])
	await process_frame
	_查((洗面板.get_node("说明") as CanvasItem).visible, "E：刚点重置、还没回包，该继续显示说明")
	_会话.equipped_items[-1]["plus_attributes"] = [
		{"attribute_type": 4, "attribute_value": 20},      # 同类型升到顶（stage2 EquipA atk 上限 18 ⇒ ★）
		{"attribute_type": 7, "attribute_value": 9},       # 类型变了（暴击→闪避）⇒ 白、无标记
	]
	窗.call("_刷新洗属性对照", 洗面板)
	await process_frame
	for 名 in ["原属性", "新属性", "对照区"]:
		_查((洗面板.get_node(名) as CanvasItem).visible, "E：回包后该显示 %s" % 名)
	_查(not (洗面板.get_node("说明") as CanvasItem).visible, "E：回包后说明该让位")
	var 对照 := 洗面板.get_node("对照区") as Control
	_核洗属性行(对照, 0, "攻击", "18", "攻击", "+20", "★", Color("00ff00"))
	_核洗属性行(对照, 1, "暴击", "5", "闪避", "+9", "", Color.WHITE)
	# 洗失败（回包列表 == 洗前快照）⇒ 收起对照，别摊一份假对比
	_会话.equipped_items[-1]["plus_attributes"] = [
		{"attribute_type": 4, "attribute_value": 18},
		{"attribute_type": 6, "attribute_value": 5},
	]
	窗.call("_刷新洗属性对照", 洗面板)
	await process_frame
	for 名 in ["原属性", "新属性", "对照区"]:
		_查(not (洗面板.get_node(名) as CanvasItem).visible, "E：新列表与快照完全相同时该收起 %s" % 名)
	_查((洗面板.get_node("说明") as CanvasItem).visible, "E：收起对照后说明该回来")

	# —— F：洗附加数值页**换件后**放入格图标要跟着换（2026-11-05 用户报）——
	# 根因：`_原地刷新洗数值页` 只刷材料数/对照；点右栏换件也走同一条原地刷新，
	# 面板不重建 ⇒ 槽里一直停着最初那件的图标，看着像"除第一件外都没图标"。
	_会话.inventory.clear()
	_会话.inventory.append(_背包件("01010013", 60))
	_会话.inventory.append(_背包件("01010014", 61))
	窗.call("_set_strengthen_tab", 2)
	await process_frame
	窗.call("_select_strengthen_slot", -1)
	for _i in 3:
		await process_frame
	var 数值页 := _页(窗)
	_查(数值页 != null, "F：洗附加数值页没建出来")
	if 数值页 != null:
		var 右栏 := 数值页.get_node("列表内容") as Control
		# 右栏 = 身上 1（快照武器）+ 背包 2（01010013 / 01010014）
		_查(右栏 != null and 右栏.get_child_count() == 3,
			"F：右栏该有 3 行（身上 1 + 背包 2），实际 %d" % (右栏.get_child_count() if 右栏 != null else -1))
		var 期望 := ["01010013", "01010014"]
		for 序 in 期望.size():
			var 行 := 序 + 1
			数值页 = _页(窗)
			右栏 = 数值页.get_node("列表内容") as Control if 数值页 != null else null
			if 右栏 == null or 行 >= 右栏.get_child_count():
				_失败.append("F：第 %d 行不存在" % 行)
				continue
			var 按钮: Button = null
			for 子 in 右栏.get_child(行).get_children():
				if 子 is Button:
					按钮 = 子
			if 按钮 == null:
				_失败.append("F：第 %d 行没有点击钮" % 行)
				continue
			按钮.pressed.emit()
			for _i in 3:
				await process_frame
			数值页 = _页(窗)
			var 图 := 数值页.get_node("面板容器/原版装备洗附加属性页/装备格/装备图标") as TextureRect \
				if 数值页 != null else null
			var 路 := String(load("res://脚本/单例/游戏数据.gd").item_icon_path(期望[序]))
			_查(图 != null and 图.texture != null and 图.texture.resource_path == 路,
				"F：点第 %d 行（%s）后放入格图标应是 %s，实际 %s" % [行, 期望[序], 路,
					(图.texture.resource_path if 图 != null and 图.texture != null else "null")])

	await _跑自动与连续重置(窗)

	# —— S：服务端满天生闸门 ——
	_跑服务端锤()

	if _失败.is_empty():
		print("装备打造面板本轮回归测试：通过（%d 条断言：右栏 12 槽过滤 / 七页购买钮 37 宽 / "
				% _受检
				+ "天生满值禁用与无数据不锁 / 精炼两项满级禁用 / 洗附加属性前后两列对照 / "
				+ "洗数值换件图标 / 服务端锤）")
		quit(0)
	else:
		for 项 in _失败:
			push_error("装备打造面板本轮测试：失败 - %s" % 项)
		quit(1)


func _跑自动与连续重置(窗: Node) -> void:
	var 原后端: Node = 窗.get("_backend")
	_查(原后端.is_connected("inventory_delta_received", Callable(窗, "_收到打造装备帧")),
		"G：真实后端装备帧信号必须接到打造应答")
	var 后端 := 打造后端.new()
	root.add_child(后端)
	后端.set_process(false)
	后端.in_game = true
	窗.set("_backend", 后端)
	后端.inventory_delta_received.connect(Callable(窗, "_收到打造装备帧"))
	后端.item_change_result_received.connect(Callable(窗, "_on_item_change_result"))
	后端.connection_status_changed.connect(Callable(窗, "_on_backend_status"))

	后端.authoritative_inventory = [{"id": "16000016", "quantity": 5, "slot_index": 1}]
	_会话.inventory = 后端.authoritative_inventory.duplicate(true)
	var 信号内数量: Array = []
	var 收数量 := func(_标志: int, _字段: Array):
		信号内数量.append(装备打造表.拥有数(_会话, 16000016))
	后端.inventory_delta_received.connect(收数量)
	后端.call("_handle_inventory_change", PackedStringArray(["1037", "8", "1", "2"]))
	_查(信号内数量 == [2], "G：库存通知发出前会话应已写入新数量2，不能读到旧数量5")
	后端.inventory_delta_received.disconnect(收数量)

	for 例 in [[0, 0, 5], [4, 0, 15], [6, 1, 21], [6, 0, 22]]:
		await _铺自动(窗, 后端, 例[0], 例[1])
		await _点自动(窗, 例[0])
		_查(后端.请求.size() == 1 and 后端.请求[0][0] == 例[2],
			"G：页%d项%d按钮应只发送对应动作%d一次" % [例[0], 例[1], 例[2]])
		_查(后端.请求.size() == 1 and int(后端.请求[0][1][0]) == -1,
			"G：自动打造必须发原装备槽位-1")
		窗.call("_执行打造", _页(窗))
		_查(后端.请求.size() == 1, "G：等待应答时再次点击不能多发")
		后端.inventory_delta_received.emit(1, ["1037", "1", "2", "16000016", "1", "2"])
		后端.inventory_delta_received.emit(11, ["1037", "11", "-2", "1", "1010023"])
		_查(not (窗.get("_打造请求") as Dictionary).is_empty(), "G：材料帧及其它装备槽位不能结束当前请求")
		if 例[0] == 6:
			后端.inventory_delta_received.emit(11, ["1037", "11", "-1", "1", "1010023"])
			后端.item_change_result_received.emit(2064, {"kind": "wash_plus_value", "equipment_position": -1, "result": 0})
			_查(not (窗.get("_打造请求") as Dictionary).is_empty(), "G：精炼必须等匹配类型的专用结果帧")
		_回打造(后端, 例[0], 例[1], 0)
		_查((窗.get("_打造请求") as Dictionary).is_empty(), "G：失败应答也必须释放在途请求")
		_查(后端.请求.size() == 1, "G：应答不能立即连发下一次")
		var 续计 := 窗.get("_打造自动计时") as SceneTreeTimer
		_查(续计 != null, "G：失败后应安排下一次自动操作")
		if 例[0] == 0:
			await create_timer(1.05).timeout
		else:
			窗.call("_自动打造下一次", 续计)
		_查(后端.请求.size() == 2, "G：每次失败结算后只续发一次")
		窗.call("_自动打造下一次", 续计)
		_查(后端.请求.size() == 2, "G：过期计时器不能重复发请求")
		match int(例[0]):
			0: _会话.equipped_items[-1]["strengthen"] = 10
			4: _会话.equipped_items[-1]["born_attr_value"] = 116
			6:
				_会话.equipped_items[-1]["strengthen"] = 11
				_会话.equipped_items[-1]["forge_additive_ratio"] = 500
		_回打造(后端, 例[0], 例[1], 1)
		窗.call("_自动打造下一次", 窗.get("_打造自动计时"))
		_查(后端.请求.size() == 2 and (窗.get("_打造自动目标") as Dictionary).is_empty(),
			"G：页%d项%d达到上限后不得继续扣料" % [例[0], 例[1]])

	for 原因 in ["材料不足", "金币不足", "取消勾选", "切页", "换件", "取出", "关窗", "断线", "物品被替换"]:
		await _铺自动(窗, 后端, 4, 0)
		await _点自动(窗, 4)
		_回打造(后端, 4, 0, 0)
		var 旧计 := 窗.get("_打造自动计时") as SceneTreeTimer
		match 原因:
			"材料不足": _会话.inventory.clear()
			"金币不足": _会话.player_stats["gold"] = 0
			"取消勾选":
				await _过帧()
				(_页(窗).get_node("内容容器/材料框/自动强化") as CheckBox).button_pressed = false
			"切页": 窗.call("_set_strengthen_tab", 0)
			"换件": 窗.call("_select_strengthen_slot", -1)
			"取出": 窗.call("_清放入")
			"关窗": 窗.call("close")
			"断线":
				后端.in_game = false
				后端.connection_status_changed.emit("断开", "门内断线")
			"物品被替换": _会话.equipped_items[-1]["id"] = "1010013"
		窗.call("_自动打造下一次", 旧计)
		_查(后端.请求.size() == 1 and (窗.get("_打造自动目标") as Dictionary).is_empty(),
			"G：%s后应停止自动操作" % 原因)

	for 原因 in ["应答超时", "取消后迟到应答", "发送失败"]:
		await _铺自动(窗, 后端, 0, 0)
		后端.允许发送 = 原因 != "发送失败"
		await _点自动(窗, 0)
		if 原因 == "应答超时":
			var 超時計 := 窗.get("_打造应答计时") as SceneTreeTimer
			_查(超時計 != null, "G：发出后必须有应答超时保护")
			窗.call("_打造应答超时", 超時計)
		elif 原因 == "取消后迟到应答":
			(_页(窗).get_node("内容容器/材料框/自动强化") as CheckBox).button_pressed = false
			_回打造(后端, 0, 0, 1)
		_查((窗.get("_打造自动目标") as Dictionary).is_empty()
			and (窗.get("_打造请求") as Dictionary).is_empty() and 窗.get("_打造自动计时") == null,
			"G：%s不能留下循环或在途锁" % 原因)

	await _铺自动(窗, 后端, 6, 0)
	await _点自动(窗, 6)
	(_页(窗).get_node("面板容器/原版装备精炼页/自动精炼") as Button).pressed.emit()
	_回打造(后端, 6, 0, 1)
	_查(后端.请求.size() == 1 and 窗.get("_打造自动计时") == null, "G：停止精炼按钮必须取消续跑")

	await _跑连续洗属性(窗, 后端)
	窗.call("_停打造自动")
	窗.set("_backend", 原后端)
	后端.queue_free()
	await _过帧()


func _过帧() -> void:
	for _i in 3:
		await process_frame


func _铺自动(窗: Node, 后端: Node, 页签: int, 项: int) -> void:
	窗.call("_停打造自动")
	窗.set("_打造请求", {})
	窗.set("_打造应答计时", null)
	后端.请求.clear()
	后端.允许发送 = true
	后端.in_game = true
	_装快照()
	_会话.equipped_items[-1]["req_level"] = 120
	_会话.equipped_items[-1]["strengthen"] = (10 if 项 == 1 else 11) if 页签 == 6 else 9
	_会话.equipped_items[-1]["born_attr_value"] = 115
	_会话.equipped_items[-1]["forge_additive_ratio"] = 499
	_会话.player_stats["gold"] = 1000000
	_会话.inventory.assign([
		{"id": "16000016", "quantity": 9999, "slot_index": 1},
		{"id": "16000033", "quantity": 9999, "slot_index": 2},
		{"id": "15028002", "quantity": 9999, "slot_index": 3},
	])
	窗.call("open_page", "装备强化")
	窗.call("_set_strengthen_tab", 页签)
	窗.set("_精炼项选中", 项)
	窗.call("_select_strengthen_slot", -1)
	await _过帧()


func _点自动(窗: Node, 页签: int) -> void:
	if 页签 == 6:
		var 自动 := _页(窗).get_node("面板容器/原版装备精炼页/自动精炼") as Button
		_查(not 自动.disabled, "G：未满精炼时自动按钮必须能点击")
		自动.pressed.emit()
	else:
		var 勾 := _页(窗).get_node("内容容器/材料框/自动强化") as CheckBox
		_查(not 勾.disabled, "G：强化/天生自动勾选必须可用")
		if 页签 == 4:
			_查(勾.text == "自动强化到满天生", "G：天生页不能仍写自动强化到10级")
		勾.button_pressed = true
		await _过帧()
		(_页(窗).get_node("开始强化") as Button).pressed.emit()
	await _过帧()


func _回打造(后端: Node, 页签: int, 项: int, 结果: int) -> void:
	后端.inventory_delta_received.emit(11, ["1037", "11", "-1", "1", "1010023"])
	if 页签 == 6:
		后端.item_change_result_received.emit(2064 if 项 == 1 else 2065,
			{"kind": "forge_strength" if 项 == 1 else "forge_additive", "equipment_position": -1, "result": 结果})


func _跑连续洗属性(窗: Node, 后端: Node) -> void:
	await _铺自动(窗, 后端, 1, 0)
	_会话.equipped_items[-1]["plus_attributes"] = [{"attribute_type": 4, "attribute_value": 18}]
	(_洗属性面板(窗).get_node("开始重置") as Button).pressed.emit()
	await _过帧()
	_查((_洗属性面板(窗).get_node("说明") as CanvasItem).visible, "H：首次应答前仍显示说明")
	_会话.equipped_items[-1]["plus_attributes"] = [{"attribute_type": 4, "attribute_value": 20}]
	_回打造(后端, 1, 0, 1)
	await _过帧()
	_核洗属性行(_洗属性面板(窗).get_node("对照区"), 0, "攻击", "18", "攻击", "+20", "★", Color("00ff00"))
	(_洗属性面板(窗).get_node("开始重置") as Button).pressed.emit()
	_查(not (_洗属性面板(窗).get_node("说明") as CanvasItem).visible, "H：第二次点击不能立即闪回说明")
	窗.call("_on_资源帧")
	await _过帧()
	_查(not (_洗属性面板(窗).get_node("说明") as CanvasItem).visible, "H：材料帧触发重绘也必须保留上一组对照")
	_核洗属性行(_洗属性面板(窗).get_node("对照区"), 0, "攻击", "18", "攻击", "+20", "★", Color("00ff00"))
	(_洗属性面板(窗).get_node("开始重置") as Button).pressed.emit()
	_查(后端.请求.size() == 2, "H：第二次重置未回包时禁止重复发请求")
	_会话.equipped_items[-1]["plus_attributes"] = [{"attribute_type": 4, "attribute_value": 21}]
	_回打造(后端, 1, 0, 1)
	await _过帧()
	_核洗属性行(_洗属性面板(窗).get_node("对照区"), 0, "攻击", "20", "攻击", "+21", "★", Color("00ff00"))
	(_洗属性面板(窗).get_node("开始重置") as Button).pressed.emit()
	_回打造(后端, 1, 0, 0)
	await _过帧()
	_查(not (_洗属性面板(窗).get_node("说明") as CanvasItem).visible, "H：连续重置失败同值也不闪回说明")
	_核洗属性行(_洗属性面板(窗).get_node("对照区"), 0, "攻击", "21", "攻击", "+21", "★", Color("00ff00"))
	窗.call("_select_strengthen_slot", -1)
	await _过帧()
	_查((_洗属性面板(窗).get_node("说明") as CanvasItem).visible, "H：换件必须清理上一件的对照")


func _查(条件: bool, 说明: String) -> void:
	_受检 += 1
	if not 条件:
		_失败.append(说明)


## 天生满值的服务端闸门在 `测试/装备打造满天生服务端锤.py`；这里只负责把它跑起来。
func _跑服务端锤() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/装备打造满天生服务端锤.py"
	if not FileAccess.file_exists(锤):
		_查(false, "S：找不到锤脚本 " + 锤)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		_查(false, "S：找不到 Python 解释器（试过 %s）" % str(候选))
		return
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	_查(码 == 0, "S：满天生服务端锤退出 %d（满值拒不扣料不发帧、未满正常扣、base=0 不锁）" % 码)


func _停(原因: String) -> void:
	push_error("装备打造面板本轮测试：中断 - %s" % 原因)
	quit(1)


func _页(窗: Node) -> Control:
	var 容器 := 窗.get("_content") as Control
	return 容器.find_child("原版装备强化内容", true, false) as Control if 容器 != null else null


func _洗属性面板(窗: Node) -> Control:
	var 页 := _页(窗)
	var 容器 := 页.get_node_or_null("面板容器") as Control if 页 != null else null
	if 容器 == null:
		return null
	for 子 in 容器.get_children():
		if (子 as Control).get_node_or_null("原属性") != null:
			return 子 as Control
	return null


func _精炼按钮(窗: Node) -> Button:
	var 页 := _页(窗)
	var 面板 := 页.get_node_or_null("面板容器/原版装备精炼页") as Control if 页 != null else null
	return 面板.get_node_or_null("精炼") as Button if 面板 != null else null


## 核洗附加属性一行：旧名 / 旧值 / 新名 / 新值 / 标记 / 新值颜色。
## 版式与「洗附加数值」一致（AS3 FormItem2），这里只核文本与颜色，版式由洗数值门钉。
func _核洗属性行(对照: Control, 序号: int, 旧名: String, 旧值: String, 新名: String,
		新值: String, 标记: String, 色: Color) -> void:
	var 本行: Array[Label] = []
	for 子 in 对照.get_children():
		if 子 is Label and int(round((子 as Label).position.y / 20.0)) == 序号:
			本行.append(子 as Label)
	本行.sort_custom(func(a: Label, b: Label) -> bool: return a.position.x < b.position.x)
	if 本行.size() < 4:
		_失败.append("E：第 %d 行只有 %d 个标签" % [序号, 本行.size()])
		return
	_查(本行[0].text == 旧名, "E：第 %d 行旧名应是「%s」，实际「%s」" % [序号, 旧名, 本行[0].text])
	_查(本行[1].text == 旧值, "E：第 %d 行旧值应是「%s」，实际「%s」" % [序号, 旧值, 本行[1].text])
	_查(本行[2].text == 新名, "E：第 %d 行新名应是「%s」，实际「%s」" % [序号, 新名, 本行[2].text])
	_查(本行[3].text == 新值, "E：第 %d 行新值应是「%s」，实际「%s」" % [序号, 新值, 本行[3].text])
	_查(本行[3].get_theme_color("font_color").is_equal_approx(色),
		"E：第 %d 行新值色应是 %s，实际 %s" % [序号, 色, 本行[3].get_theme_color("font_color")])
	var 实标记 := 本行[4].text if 本行.size() > 4 else ""
	_查(实标记 == 标记, "E：第 %d 行标记应是「%s」，实际「%s」" % [序号, 标记, 实标记])


## F 段用的背包件：紫装、120 级 —— 洗附加数值页的两道放入门槛（非白 / ≥60 级）都过得了。
func _背包件(号: String, 格: int) -> Dictionary:
	return {"id": 号, "name": "测试" + 号, "quantity": 1, "slot_index": 格,
		"icon": String(load("res://脚本/单例/游戏数据.gd").item_icon_path(号)),
		"aptitude": 4, "req_level": 120, "strengthen": 0,
		"plus_attributes": [{"type": 1, "value": 9}], "stage": 2}


func _装快照() -> void:
	var 解析: Variant = JSON.parse_string(FileAccess.get_file_as_string(快照))
	if typeof(解析) != TYPE_DICTIONARY:
		_停("快照解析失败：%s" % 快照)
		return
	var 会话 := root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		_停("拿不到 GameSession")
		return
	会话.equipped_items.clear()
	for 键 in 解析:
		会话.equipped_items[int(键)] = (解析[键] as Dictionary).duplicate(true)
