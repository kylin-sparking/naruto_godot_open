extends SceneTree

## 「洗附加数值」页**旧/新对照 + 保存/取消**的回归。
##
## 为什么要单拎一条：服务端那条路早就通了（动作 2 出预览 → 动作 19 落盘），
## 但**客户端全项目没人调用过动作 19** —— 预览回到界面后被丢进一行状态文字里，
## 玩家看不到、也存不下。这一条钉的就是"回包真的摊成了两列并能提交"。
##
## 真值出处 `EquipPropLianZhiPanel.as`：
##   * `:78-157`  `drawPropView(旧, 新)` —— 每行 20 高；左列 x=0 宽 70、右列 x=75，
##                标记跟在右列之后；左列整条白，右列**只有数值和标记**变色
##                （新<旧 红↓ / 新>旧未满 绿↑ / 到顶 绿★ / 没变 白）。
##                **单参调用**（没有新列表）= 洗完之后的收尾状态：右列留空、不要标记。
##   * `:316-330`  `operationResultHandler` —— 收到预览就藏 `_upgradeBtn`、露出左右两个按钮
##   * `:481-511`  左=保存(`requestSelectPlusValue(pos, true)`)、右=取消(`false`)；
##                两个 handler 都是**先摆按钮再发请求**
##
## 用 `测试/基线/装备快照/武器_精炼.json` —— 它身上是 **6 条**附加属性
## （攻击18 / 暴击5 / 查克拉上限41 / 闪避12 / 属性24=30 / 经验加成8），
## 正好把四种颜色分支都覆盖到。上限表（stage2.EquipA）= atk→18 / bsk→11 / maxmp→41。
##
## 运行：Godot --headless --path . --script res://测试/洗附加数值对照回归测试.gd

const 快照 := "res://测试/基线/装备快照/武器_精炼.json"

var _失败: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	# ⚠️ 窗口管理不是能单独 `new` 出来的 —— 照 `功能入口回归测试` / `截强化窗` 的做法：
	# **实例化地图场景**，再从它身上取 `窗口管理`。
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _序号 in 5:
		await process_frame

	_装快照()
	var 会话 := root.get_node_or_null("/root/GameSession")
	var 旧条数 := (会话.equipped_items[-1]["plus_attributes"] as Array).size()
	# 屏幕通知（`_通知` 走的就是它）—— 1.1 那条断言要收这条。
	var 通知: Array[String] = []
	会话.notification_requested.connect(func(文: String) -> void: 通知.append(文))

	var 管理 := 场景.get_node_or_null("窗口管理")
	var 窗 = 管理.call("取或建窗口", "装备强化") if 管理 != null else null
	if 窗 == null:
		_停("拿不到装备强化窗")
		return
	管理.call("打开", "装备强化")
	# ⚠️ 2026-10-01：左栏改成像原版那样的**显式放入态**（`_itemData`），
	# 光挪游标不算放进 —— 走真入口 `_select_strengthen_slot`（对位点部位列表的一行穿着件）。
	窗.call("open_page", "装备强化")
	await process_frame
	窗.call("_set_strengthen_tab", 2)          # tab2 = 洗附加数值
	# ⚠️ 2026-10-01：切页签会把放入态**清空**（原版 `selectedBtnHandler:741`），
	# 所以放入要在**定页签之后**做，顺序反了这里就是空槽、对照画不出来。
	窗.call("_select_strengthen_slot", -1)
	for _序号 in 4:
		await process_frame

	var 面板 := _面板(窗)
	if 面板 == null:
		_停("洗附加数值页没建出面板")
		return
	var 对照 := 面板.get_node("对照区") as Control

	# —— 0.1 / 1.2 / 0.3：这一页的版式（用户 2026-11-01 报的）——
	# 0.1 放入格要带品质外框：快照这件 aptitude=4（紫）⇒ `装备品质.挂覆盖层` 挂的
	# `资质框` 应有紫框贴图且可见（框的素材与偏移都归 `装备品质`，这里只验"挂上了"）。
	var 资质框 := 面板.get_node("装备格").get_node_or_null("资质框") as TextureRect
	_查(资质框 != null and 资质框.visible and 资质框.texture != null,
		"0.1 放入装备格应有品质外框（快照 aptitude=4 是紫装）")
	# 1.2 原版这一页（`EquipPropLianZhiPanel(isWashProp = true)`）只建 `_caiLiao1`，
	# 场景共用的材料二 / 幸运符那组四件必须藏掉。
	for 名 in ["材料框/材料二", "材料框/使用幸运符", "材料框/幸运符数量", "材料框/单位"]:
		_查(not (面板.get_node(名) as CanvasItem).visible,
			"1.2 「%s」应隐藏（原版这一页没有）" % 名)
	# 0.3 材料数量角标照背包口径（`背包窗口.gd:779-787`）：14 号白字、右对齐。
	var 数量 := 面板.get_node("材料框/材料一/材料格/材料数量") as Label
	_查(数量.get_theme_font_size("font_size") == 14,
		"0.3 材料数量应是 14 号字，实际 %d" % 数量.get_theme_font_size("font_size"))
	_查(数量.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "0.3 材料数量应右对齐")

	# —— 洗之前：只有说明 + 开始重置 ——
	_查((面板.get_node("说明") as CanvasItem).visible, "洗之前应显示说明")
	_查((面板.get_node("开始重置") as Button).visible, "洗之前应显示「开始重置」")
	for 名 in ["原属性", "新属性", "对照区", "保存", "取消"]:
		_查(not (面板.get_node(名) as CanvasItem).visible, "洗之前不该显示 %s" % 名)

	# —— 灌一份**合成的预览回包**，走 `_on_item_change_result` 那条真实入口 ——
	窗.call("_on_item_change_result", 1819, {
		"kind": "wash_plus_value", "equipment_position": -1, "result": 1,
		"plus_attributes": [
			{"attribute_type": 4, "attribute_value": 6},     # 18→6   降         → 红 ↓
			{"attribute_type": 6, "attribute_value": 9},     # 5→9    升未到顶11 → 绿 ↑
			{"attribute_type": 2, "attribute_value": 41},    # 41→41  没变但到顶  → 绿 ★
			{"attribute_type": 7, "attribute_value": 12},    # 不在上限表、没变   → 白、无标记
			{"attribute_type": 24, "attribute_value": 40},   # 不在上限表、升了   → 绿 ↑
			{"attribute_type": 25, "attribute_value": 3},    # 8→3    降         → 红 ↓
		],
	})
	await process_frame
	await process_frame

	# —— 洗之后：对照那一组出现，说明与开始重置让位 ——
	_查(not (面板.get_node("说明") as CanvasItem).visible, "洗之后说明该让位")
	_查(not (面板.get_node("开始重置") as Button).visible, "洗之后「开始重置」该让位")
	for 名 in ["原属性", "新属性", "对照区", "保存", "取消"]:
		_查((面板.get_node(名) as CanvasItem).visible, "洗之后该显示 %s" % 名)
	_查((面板.get_node("原属性") as Label).text == "原属性", "左列抬头应是「原属性」")
	_查((面板.get_node("新属性") as Label).text == "新属性", "右列抬头应是「新属性」")
	_查((面板.get_node("新属性") as Label).get_theme_color("font_color").is_equal_approx(Color("fff000")),
		"「新属性」抬头该是金色（16773120）")

	# —— 逐行核（行按 y 分组，组内按 x 排序：旧名 / 旧值 / 新名 / 新值 / 标记）——
	# 2026-11-04 起照 AS3 `FormItem2` 拆成**标题列 + 内容列**（§3.366）：
	# 旧件 0..70 标题 / 74..119 内容；新件 124..194 标题 / 198..243 内容；标记贴 243。
	# 旧实现把"名　值"塞进 70 宽一列，6 字名整条溢出压到右列 —— 用户报的"堆叠"。
	_查(_行数(对照) == 旧条数, "对照应 %d 行，实际 %d" % [旧条数, _行数(对照)])
	_核行(对照, 0, "攻击", "18", "+6", "↓", Color("ff0000"), "降")
	_核行(对照, 1, "暴击", "5", "+9", "↑", Color("00ff00"), "升但没到顶")
	_核行(对照, 2, "查克拉上限", "41", "+41", "★", Color("00ff00"), "没变但到顶")
	_核行(对照, 3, "闪避", "12", "+12", "", Color.WHITE, "不在上限表且没变")
	_核行(对照, 4, "属性24", "30", "+40", "↑", Color("00ff00"), "不在上限表但升了")
	_核行(对照, 5, "经验加成", "8", "+3", "↓", Color("ff0000"), "降")
	_查版式(对照, "洗数值对照")

	# —— 两个按钮必须**接了线**（点了要能落盘）——
	for 名 in ["保存", "取消"]:
		_查(not (面板.get_node(名) as Button).pressed.get_connections().is_empty(),
			"「%s」没接接线（点了不会有反应）" % 名)

	# —— 1.3：材料帧到达时**原地刷新**，不整页重建（2026-11-04 用户报"卡顿"的修法）——
	# 真服务端的顺序是「先扣材料发库存帧 → 再发 1819」（`_forge_wash_plus_attributes`），
	# 库存帧会走 `_on_资源帧 → _refresh_current`。旧实现一律整页重建，画面闪一下、
	# 刚摊开的对照被 free；`_原地刷新洗数值页` 现在只改材料数/灰度/消耗行/对照。
	窗.call("_refresh_current")
	for _序号 in 4:
		await process_frame
	var 刷新后 := _面板(窗)
	_查(刷新后 != null and 刷新后 == 面板, "1.3 材料帧该原地刷新：面板不该被重建")
	if 刷新后 != null:
		面板 = 刷新后
		对照 = 面板.get_node("对照区") as Control
		for 名 in ["原属性", "新属性", "对照区", "保存", "取消"]:
			_查((面板.get_node(名) as CanvasItem).visible, "1.3 原地刷新后「%s」应仍显示" % 名)
		_查(_行数(对照) == 旧条数, "1.3 原地刷新后对照仍应是 %d 行，实际 %d" % [旧条数, _行数(对照)])
		_核行(对照, 0, "攻击", "18", "+6", "↓", Color("ff0000"), "原地刷新后第一行")
		_查版式(对照, "原地刷新后")

	# —— 1.4：回包到达时旧面板已被扣材料帧拆掉（`_洗数值面板` 已空）——
	# 这才是用户报的真相顺序：库存帧先到 ⇒ 面板 free、`_洗数值面板` 清空 ⇒ 1819 才到。
	# 修前的判据只看那块面板活不活 ⇒ 直接落进通用分支，**预览连记都没记**；
	# 修后判据看当前页，先把预览存在窗口上，下一次重建再摊出来。
	窗.set("_洗数值面板", null)
	窗.call("_on_item_change_result", 1819, {
		"kind": "wash_plus_value", "equipment_position": -1, "result": 1,
		"plus_attributes": [
			{"attribute_type": 4, "attribute_value": 5},     # 18→5  降
			{"attribute_type": 6, "attribute_value": 6},     # 5→6   升
			{"attribute_type": 2, "attribute_value": 41},    # 到顶不变
			{"attribute_type": 7, "attribute_value": 12},    # 不变
			{"attribute_type": 24, "attribute_value": 30},   # 不变
			{"attribute_type": 25, "attribute_value": 8},    # 不变
		],
	})
	窗.call("_refresh_current")
	for _序号 in 4:
		await process_frame
	var 面板二 := _面板(窗)
	_查(面板二 != null, "1.4 重建后应有面板")
	if 面板二 != null:
		面板 = 面板二
		对照 = 面板.get_node("对照区") as Control
		_查((对照 as CanvasItem).visible, "1.4 回包时面板已空 ⇒ 重建后仍要摊出对照（预览必须存在窗口上）")
		_核行(对照, 0, "攻击", "18", "+5", "↓", Color("ff0000"), "1.4 新预览第一行")

	# —— 取消 → 回到"只画旧值那一列"（**不是**把对照区收起来）——
	(面板.get_node("取消") as Button).pressed.emit()
	await process_frame
	await process_frame
	_查((面板.get_node("开始重置") as Button).visible, "取消之后「开始重置」该回来")
	_查(not (面板.get_node("保存") as CanvasItem).visible, "取消之后「保存」该收起")
	_查(not (面板.get_node("取消") as CanvasItem).visible, "取消之后「取消」自己该收起")
	_查((面板.get_node("对照区") as CanvasItem).visible, "取消之后对照区仍在（只剩旧值那列）")
	_查(not (面板.get_node("说明") as CanvasItem).visible, "取消之后说明仍让位（drawPropView 会关掉它）")
	_查(_行数(对照) == 旧条数, "取消后仍是 %d 行，实际 %d" % [旧条数, _行数(对照)])
	_核行(对照, 0, "攻击", "18", "", "", Color.WHITE, "取消后右列该留空")

	# —— 1.1：预览与旧值**逐条相同**时要给一句解释 ——
	# 服务端 `_wash_plus_values` 对 `旧值 >= 上限` 的条目**原样返回**（页面原话
	# 「达到满属性后再次重置将不会改变」），此时右列没有任何标记，不解释就看起来像
	# "洗练没生效"（用户 2026-11-01 报的 1.1 正是这个观感）。
	# 0.5 顺带在这里验：洗练回包**不该**再往面板状态行写「附加数值洗练结果：…」。
	通知.clear()
	var 该不变: Array = []
	for 条 in (会话.equipped_items[-1]["plus_attributes"] as Array):
		该不变.append({
			"attribute_type": int((条 as Dictionary).get("attribute_type", 0)),
			"attribute_value": int((条 as Dictionary).get("attribute_value", 0)),
		})
	var 状态 := 窗.get("_status") as Label
	if 状态 != null:
		状态.text = "哨兵"
	窗.call("_on_item_change_result", 1819, {
		"kind": "wash_plus_value", "equipment_position": -1, "result": 1,
		"plus_attributes": 该不变,
	})
	await process_frame
	_查(通知.any(func(文: String) -> bool: return 文.contains("没有变化")),
		"1.1 预览与旧值全同时应提示「数值没有变化」，实际通知：%s" % [通知])
	if 状态 != null:
		_查(not 状态.text.contains("结果"),
			"0.5 洗练回包不该往面板状态行写结果，实际「%s」" % 状态.text)

	if _失败.is_empty():
		print("洗附加数值对照回归测试：通过（四列版式不重叠 / 两列对照 / 四种颜色标记 / 保存取消接线 / 取消后只剩旧列 / "
				+ "品质外框与材料数量字号 / 只留一项材料 / 全同预览有解释 / 不写状态行 / 材料帧原地刷新不重建 / "
				+ "回包时面板已空仍留住预览）")
		quit(0)
	else:
		for 项 in _失败:
			push_error("洗附加数值对照测试：失败 - %s" % 项)
		quit(1)


## 行数。⚠️ 按 y 归到"第几行"，**不是**去数不同的 y ——
## 标记那个标签在 `y - 2` 上（原版 `drawPropView` 就是 `_loc4_ - 2`），
## 直接数 y 会把它当成单独一行（第一版就数出了 11 行）。
func _行数(对照: Control) -> int:
	var 行集 := {}
	for 子 in 对照.get_children():
		if 子 is Label:
			行集[_行号((子 as Label).position.y)] = true
	return 行集.size()


func _行号(y: float) -> int:
	return int(round(y / 20.0))


## 核一行：旧名 / 旧值 / 新值 / 标记 / 数值颜色。版式另有 `_查版式` 统一钉。
func _核行(对照: Control, 序号: int, 左名: String, 左值: String, 新值: String, 标记: String, 色: Color, 说明: String) -> void:
	var 本行: Array[Label] = []
	for 子 in 对照.get_children():
		if 子 is Label and _行号((子 as Label).position.y) == 序号:
			本行.append(子 as Label)
	本行.sort_custom(func(a: Label, b: Label) -> bool: return a.position.x < b.position.x)
	if 本行.size() < 4:
		_失败.append("%s：第 %d 行只有 %d 个标签" % [说明, 序号, 本行.size()])
		return
	_查(本行[0].text == 左名, "%s：第 %d 行旧名应是「%s」，实际「%s」" % [说明, 序号, 左名, 本行[0].text])
	_查(本行[1].text == 左值, "%s：第 %d 行旧值应是「%s」，实际「%s」" % [说明, 序号, 左值, 本行[1].text])
	_查(本行[2].text == 左名, "%s：第 %d 行新名应与旧名同「%s」，实际「%s」" % [说明, 序号, 左名, 本行[2].text])
	var 期望右值 := 新值 if not 新值.is_empty() else " "
	_查(本行[3].text == 期望右值,
		"%s：第 %d 行新值应是「%s」，实际「%s」" % [说明, 序号, 期望右值, 本行[3].text])
	if not 新值.is_empty():
		_查(本行[3].get_theme_color("font_color").is_equal_approx(色),
			"%s：第 %d 行数值色应是 %s，实际 %s" % [说明, 序号, 色, 本行[3].get_theme_color("font_color")])
	var 实标记 := 本行[4].text if 本行.size() > 4 else ""
	_查(实标记 == 标记, "%s：第 %d 行标记应是「%s」，实际「%s」" % [说明, 序号, 标记, 实标记])


## 2026-11-04 版式钉（AS3 `FormItem2`）：旧件标题 0..70 / 内容 74..119、
## 新件标题 124..194 / 内容 198..243、标记 243..263；相邻两列必须**不重叠**。
## 用户报的"排版不整齐、有堆叠"就是旧版 70 宽列装不下 6 字名导致的越界。
func _查版式(对照: Control, 说明: String) -> void:
	var 期望 := [
		[0.0, 70.0], [74.0, 45.0], [124.0, 70.0], [198.0, 45.0], [243.0, 20.0],
	]
	var 行集 := {}
	for 子 in 对照.get_children():
		if 子 is Label:
			行集[_行号((子 as Label).position.y)] = true
	for 行号 in 行集:
		var 本行: Array[Label] = []
		for 子 in 对照.get_children():
			if 子 is Label and _行号((子 as Label).position.y) == 行号:
				本行.append(子 as Label)
		本行.sort_custom(func(a: Label, b: Label) -> bool: return a.position.x < b.position.x)
		for i in mini(本行.size(), 期望.size()):
			_查(is_equal_approx(本行[i].position.x, 期望[i][0]),
				"%s：第 %d 行第 %d 列 x 应是 %.0f，实际 %.1f" % [说明, 行号, i + 1, 期望[i][0], 本行[i].position.x])
			_查(is_equal_approx(本行[i].size.x, 期望[i][1]),
				"%s：第 %d 行第 %d 列宽应是 %.0f，实际 %.1f" % [说明, 行号, i + 1, 期望[i][1], 本行[i].size.x])
		for i in 本行.size() - 1:
			_查(本行[i].position.x + 本行[i].size.x <= 本行[i + 1].position.x + 0.01,
				"%s：第 %d 行第 %d 列右沿 %.1f 压到第 %d 列 %.1f（堆叠）"
				% [说明, 行号, i + 1, 本行[i].position.x + 本行[i].size.x, i + 2, 本行[i + 1].position.x])


## 洗附加数值页那个面板（复用 装备洗附加属性页.tscn）—— 认它身上独有的那一组对照节点。
func _面板(窗) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	var 根 := 内容.find_child("原版装备强化内容", true, false) as Control
	var 容器 := 根.get_node_or_null("面板容器") as Control if 根 != null else null
	if 容器 == null:
		return null
	for 子 in 容器.get_children():
		if (子 as Control).get_node_or_null("原属性") != null:
			return 子 as Control
	return null


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


func _查(条件: bool, 说明: String) -> void:
	if not 条件:
		_失败.append(说明)


func _停(原因: String) -> void:
	push_error("洗附加数值对照回归测试：中断 - %s" % 原因)
	quit(1)
