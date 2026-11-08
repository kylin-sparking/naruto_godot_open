extends SceneTree
## 亲热天堂（小地图「藏宝图」，NPC 21 卡卡西）回归门 —— 2026-10-21 #9。
##
## 钉三件事：
##   ① 页面不再是死链：三个书钮、`显示宝贝/开始/停止/领取` 四态钮、16 个候选格全部接上；
##   ② 协议四支（17 查询 / 18 开箱 / 19 开始 / 20 领取）按原版 `FudaiProcessor` 发对，
##      并且 `1289:17` `1289:18` 两帧的文本腿能被解析成状态（这部分直接戳真的后端连接）；
##   ③ 四态机器与动画：停止定格后礼品格 = 候选第 index 个；勾了「兑换后自动领取」会自己领；
##   ④ 亲热天堂3 紫装（2026-10-31）：17 帧里的 `aptitude`/`strengthen` 解得出来，紫装候选格与
##      礼品格都叠 `资质框` + `流光`，普通物品格不叠，换回普通候选时覆盖层被清掉；
##   ⑤ 开箱被拒（服务端只回 state=0）不再静默：点过「显示宝贝」之后那一帧落空要弹提示，
##      进页查询的回帧不算（否则一进页就误报）。
##
## 用**假后端**（只记调用、手动发帧）跑 UI；解析那一段用 autoload 的真 `BackendConnection`
## 直接调 `_handle_fudai_text`（纯解析、不联网）。收尾把背包与勾选恢复。

const 功能窗口场景 := preload("res://场景/界面/功能窗口.tscn")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 书一 := "15008002"
const 书二 := "15008003"
## 亲热天堂3 紫装候选用的一件真实角色装备（reqLevel=1、reqJob=300，见 `Box.info.zhuangbei`）。
const 装备串id := "01010013"


class 假后端 extends Node:
	signal treasure_state_received(state: Dictionary)
	var 调用: Array = []

	func request_treasure_show() -> bool:
		调用.append(["show"])
		return true

	func request_treasure_open(类型: int, 背包格位: int) -> bool:
		调用.append(["open", 类型, 背包格位])
		return true

	func request_treasure_start() -> bool:
		调用.append(["start"])
		return true

	func request_treasure_gain() -> bool:
		调用.append(["gain"])
		return true

	func 发(状态: Dictionary) -> void:
		treasure_state_received.emit(状态)


var _fails: Array[String] = []
var _提示: Array[String] = []
var _会话
var _窗口
var _页: Control
var _假: 假后端


func _initialize() -> void:
	_跑.call_deferred()


func _查(条件: bool, 说明: String) -> void:
	if not 条件:
		_fails.append(说明)


func _找(根: Node, 名: String) -> Node:
	if 根 == null:
		return null
	if String(根.name) == 名:
		return 根
	for 子 in 根.get_children():
		var 命中 := _找(子, 名)
		if 命中 != null:
			return 命中
	return null


func _候选(i: int) -> String:
	return "0&%s&%d&3&0&1&1&0&0&%d" % [书一, 100 + i, 900 + i]


func _跑() -> void:
	_会话 = root.get_node_or_null("GameSession")
	var 后端 := root.get_node_or_null("BackendConnection") as Node
	if _会话 == null or 后端 == null:
		printerr("亲热天堂回归测试：拿不到 GameSession / BackendConnection")
		quit(1)
		return

	# 真后端的两帧解析（纯函数路径，不发包）。
	var 收到: Array = []
	var 接 := func(状态: Dictionary) -> void: 收到.append(状态)
	后端.treasure_state_received.connect(接)
	后端.call("_handle_fudai_text", PackedStringArray(["1289", "17", "1", "-", "%s@%s" % [_候选(0), _候选(1)], "2"]))
	后端.call("_handle_fudai_text", PackedStringArray(["1289", "18", "2", "1"]))
	后端.treasure_state_received.disconnect(接)
	_查(收到.size() == 2, "两帧 17/18 应当各发一次信号（实收 %d）" % 收到.size())
	if 收到.size() == 2:
		var 首: Dictionary = 收到[0]
		var 次: Dictionary = 收到[1]
		_查(int(首.get("action", 0)) == 17 and int(首.get("state", -1)) == 1,
			"17 帧应解出 action=17/state=1，实得 %s" % 首)
		_查((首.get("candidates", []) as Array).size() == 2, "17 帧应解出 2 个候选")
		_查(int(首.get("type", -1)) == 2, "17 帧应解出 type=2")
		_查(int(次.get("action", 0)) == 18 and int(次.get("state", -1)) == 2 and int(次.get("index", -1)) == 1,
			"18 帧应解出 action=18/state=2/index=1，实得 %s" % 次)

	var 原背包: Array[Dictionary] = _会话.inventory.duplicate(true)
	_会话.notification_requested.connect(func(文: String) -> void: _提示.append(文))
	_提示.clear()

	_窗口 = 功能窗口场景.instantiate()
	root.add_child(_窗口)
	await process_frame
	await process_frame
	_假 = 假后端.new()
	_假.name = "假后端"
	root.add_child(_假)
	_窗口.set("_backend", _假)

	# ① 没书：页还能画出来，但按钮禁用、说明用默认第一档。
	_会话.inventory.assign([])
	await _打开藏宝页()
	if _页 == null:
		_fails.append("藏宝图页面没渲染出来（_content 里找不到「原版亲热天堂内容」）")
		await _收尾(原背包)
		return
	var 钮 := _找(_页, "显示宝贝") as Button
	var 书格 := _找(_页, "亲热天堂格") as TextureRect
	var 格子 := _找(_页, "宝物格") as GridContainer
	_查(钮 != null, "页上没有「显示宝贝」钮")
	_查(格子 != null and 格子.get_child_count() == 16, "宝物格应是 16 格（实得 %d）" % (格子.get_child_count() if 格子 != null else -1))
	_查(钮 != null and 钮.disabled, "背包没书时「显示宝贝」应当禁用")
	_查(书格 != null and 书格.get_node_or_null("图标") != null, "亲热天堂格应当带图标子节点")

	# ② 塞一本《亲热天堂1》：按钮亮、书格出图标、《亲热天堂2》钮按下去提示没那本书。
	var 书: Dictionary = {"id": 书一, "quantity": 1}
	var 本: Array[Dictionary] = [书]
	_会话.inventory.assign(本)
	await _打开藏宝页()
	钮 = _找(_页, "显示宝贝") as Button
	书格 = _找(_页, "亲热天堂格") as TextureRect
	格子 = _找(_页, "宝物格") as GridContainer
	_查(钮 != null and not 钮.disabled, "背包有《亲热天堂1》时按钮应当可点")
	var 书图标: TextureRect = 书格.get_node_or_null("图标") if 书格 != null else null
	_查(书图标 != null and 书图标.texture == 游戏数据.item_icon(书一), "亲热天堂格应显示《亲热天堂1》图标")
	var 说明 := _找(_页, "兑换说明") as Label
	_查(说明 != null and 说明.text.contains("亲热天堂1"), "默认说明应是第一档（实得 %s）" % (说明.text if 说明 != null else "null"))
	(_找(_页, "亲热天堂2") as TextureButton).pressed.emit()
	await process_frame
	说明 = _找(_页, "兑换说明") as Label
	_查(说明 != null and 说明.text.contains("亲热天堂2"), "点书钮 2 后说明应换成第二档")
	钮 = _找(_页, "显示宝贝") as Button
	_查(钮 != null and 钮.disabled, "只有《亲热天堂1》时第 2 档按钮应当禁用")
	(_找(_页, "亲热天堂1") as TextureButton).pressed.emit()
	await process_frame
	钮 = _找(_页, "显示宝贝") as Button
	_查(钮 != null and not 钮.disabled, "点回第 1 档后按钮恢复可点")

	# ③ 20 支：点「显示宝贝」发 18（类型=2、格位=1）。
	_假.调用.clear()
	钮.pressed.emit()
	await process_frame
	_查(not _假.调用.is_empty() and String(_假.调用[0][0]) == "open" and int(_假.调用[0][1]) == 2 and int(_假.调用[0][2]) == 1,
		"点「显示宝贝」应发 request_treasure_open(2, 1)，实得 %s" % [_假.调用])

	# ④ 回 state=1 + 16 个候选：按钮变「开始」、格子出图标。
	var 候选: Array = []
	for i in range(16):
		候选.append(本格候选(i))
	_假.发({"action": 17, "state": 1, "candidates": 候选, "gained": {}, "type": 2})
	await process_frame
	钮 = _找(_页, "显示宝贝") as Button
	_查(钮 != null and String(钮.text) == "开始", "state=1 时按钮文案应是「开始」（实得 %s）" % (钮.text if 钮 != null else "null"))
	var 首格 := (格子.get_child(0) as Control)
	var 首图标 := 首格.get_node_or_null("图标") as TextureRect
	var 首数量 := 首格.get_node_or_null("数量") as Label
	_查(首图标 != null and 首图标.texture != null, "候选格应填上图标")
	_查(首数量 != null and String(首数量.text) == "3", "候选数量应是 3（实得 %s）" % (首数量.text if 首数量 != null else "null"))

	# ④b 真解析：17 帧里的装备候选要解出 aptitude / strengthen / strength_value，
	# 普通物品**不带** aptitude 键（`装备品质.覆盖层` 靠 `has("aptitude")` 决定叠不叠）。
	var 收到装: Array = []
	var 接装 := func(状态: Dictionary) -> void: 收到装.append(状态)
	后端.treasure_state_received.connect(接装)
	后端.call("_handle_fudai_text", PackedStringArray([
		"1289", "17", "1", "-", "%s@%s" % [_装备候选串(4, 7), _候选(0)], "4"]))
	后端.treasure_state_received.disconnect(接装)
	var 装备候选: Array = 收到装[0].get("candidates", []) if 收到装.size() == 1 else []
	_查(装备候选.size() == 2, "④b 的 17 帧应解出 2 个候选（实得 %d）" % 装备候选.size())
	if 装备候选.size() == 2:
		var 紫件: Dictionary = 装备候选[0]
		var 素件: Dictionary = 装备候选[1]
		_查(String(紫件.get("id", "")) == 装备串id, "④b 紫装候选 id 应是 %s（实得 %s）" % [装备串id, 紫件.get("id", "")])
		_查(int(紫件.get("aptitude", -1)) == 4, "④b 紫装候选 aptitude 应是 4（实得 %s）" % 紫件.get("aptitude", "缺"))
		_查(int(紫件.get("strengthen", -1)) == 7, "④b 紫装候选 strengthen 应是 7（实得 %s）" % 紫件.get("strengthen", "缺"))
		_查(int(紫件.get("strength_value", 0)) == 21, "④b 紫装候选 strength_value 应是 21（实得 %s）" % 紫件.get("strength_value", "缺"))
		_查(not 素件.has("aptitude"), "④b 普通物品不该带 aptitude 键（实得 %s）" % 素件.get("aptitude", "缺"))

	# ④c 紫装候选格：资质框可见 + 流光在；普通物品格两者都不叠。
	_假.发({"action": 17, "state": 1, "candidates": 装备候选, "gained": {}, "type": 4})
	await process_frame
	var 紫格 := 格子.get_child(0) as Control
	var 紫框 := 紫格.get_node_or_null("资质框") as TextureRect
	_查(紫框 != null and 紫框.visible and 紫框.texture != null, "④c 紫装候选格应叠资质框（不可见/无贴图）")
	var 紫灯 := 紫格.get_node_or_null("流光") as AnimatedSprite2D
	_查(紫灯 != null and 紫灯.visible, "④c 紫装候选格应挂流光")
	var 素格 := 格子.get_child(1) as Control
	var 素框 := 素格.get_node_or_null("资质框") as TextureRect
	_查(素框 == null or not 素框.visible, "④c 普通物品候选格不该有资质框")
	var 素灯 := 素格.get_node_or_null("流光") as AnimatedSprite2D
	_查(素灯 == null or not 素灯.visible, "④c 普通物品候选格不该有流光")

	# ④d 换回普通候选：同一格上的覆盖层要被清掉（不是留着上一次的紫框）。
	_假.发({"action": 17, "state": 1, "candidates": 候选, "gained": {}, "type": 2})
	await process_frame
	var 清框 := (格子.get_child(0) as Control).get_node_or_null("资质框") as TextureRect
	_查(清框 == null or not 清框.visible, "④d 换回普通候选后资质框应清掉")
	钮 = _找(_页, "显示宝贝") as Button
	_查(钮 != null and String(钮.text) == "开始", "④d 恢复 state=1 后按钮文案应回「开始」")

	# ⑤ 点「开始」发 19。
	_假.调用.clear()
	钮.pressed.emit()
	await process_frame
	_查(_假.调用.size() == 1 and String(_假.调用[0][0]) == "start", "点「开始」应发 request_treasure_start()，实得 %s" % [_假.调用])

	# ⑥ 回 action=18/index=5：按钮变「停止」、动画把选中框亮起来。
	_假.发({"action": 18, "state": 2, "index": 5})
	await process_frame
	钮 = _找(_页, "显示宝贝") as Button
	_查(钮 != null and String(钮.text) == "停止", "action=18 后按钮文案应是「停止」")
	await create_timer(0.12).timeout
	var 亮着 := 0
	for 格 in 格子.get_children():
		var 选中 := (格 as Control).get_node_or_null("选中") as Control
		if 选中 != null and 选中.visible:
			亮着 += 1
	_查(亮着 == 1, "动画中应恰有一个选中框亮着（实得 %d）" % 亮着)

	# ⑦ 点「停止」：按钮变「领取」，礼品格 = 候选第 5 个。
	钮.pressed.emit()
	await process_frame
	钮 = _找(_页, "显示宝贝") as Button
	_查(钮 != null and String(钮.text) == "领取", "停止后按钮文案应是「领取」")
	var 礼格 := _找(_页, "礼品格") as TextureRect
	var 礼图标: TextureRect = 礼格.get_node_or_null("图标") if 礼格 != null else null
	_查(礼图标 != null and 礼图标.texture == 游戏数据.item_icon(书一), "礼品格应显示候选第 5 个")

	# ⑧ 点「领取」发 20；回 state=0 后按钮回「显示宝贝」。
	_假.调用.clear()
	钮.pressed.emit()
	await process_frame
	_查(_假.调用.size() == 1 and String(_假.调用[0][0]) == "gain", "点「领取」应发 request_treasure_gain()，实得 %s" % [_假.调用])
	_假.发({"action": 17, "state": 0, "candidates": 候选, "gained": {}, "type": 2})
	await process_frame
	钮 = _找(_页, "显示宝贝") as Button
	_查(钮 != null and String(钮.text) == "显示宝贝", "领完回 state=0 时按钮文案应回「显示宝贝」")

	# ⑨ 勾「兑换后自动领取」：点停止后 0.5 秒自己发 20。
	var 自动 := _找(_页, "兑换后自动领取") as CheckBox
	if 自动 != null:
		自动.set_pressed_no_signal(true)
	_假.发({"action": 17, "state": 1, "candidates": 候选, "gained": {}, "type": 2})
	await process_frame
	_假.发({"action": 18, "state": 2, "index": 7})
	await process_frame
	钮 = _找(_页, "显示宝贝") as Button
	钮.pressed.emit()
	await process_frame
	_假.调用.clear()
	await create_timer(0.8).timeout
	_查(_假.调用.size() == 1 and String(_假.调用[0][0]) == "gain", "勾了自动领取时停止后应自动发 request_treasure_gain()，实得 %s" % [_假.调用])

	# ⑨b 礼品格：停止后奖品是紫装 ⇒ 礼格也叠资质框（与候选格同一条 `_填藏宝格`）。
	var 自动勾 := _找(_页, "兑换后自动领取") as CheckBox
	if 自动勾 != null:
		自动勾.set_pressed_no_signal(false)
	_假.发({"action": 17, "state": 1, "candidates": 装备候选, "gained": {}, "type": 4})
	await process_frame
	_假.发({"action": 18, "state": 2, "index": 0})
	await process_frame
	钮 = _找(_页, "显示宝贝") as Button
	钮.pressed.emit()
	await process_frame
	var 紫礼格 := _找(_页, "礼品格") as TextureRect
	var 紫礼框: TextureRect = 紫礼格.get_node_or_null("资质框") if 紫礼格 != null else null
	_查(紫礼框 != null and 紫礼框.visible and 紫礼框.texture != null, "⑨b 礼品格是紫装时应叠资质框")
	var 紫礼图标: TextureRect = 紫礼格.get_node_or_null("图标") if 紫礼格 != null else null
	_查(紫礼图标 != null and 紫礼图标.texture == 游戏数据.item_icon(装备串id), "⑨b 礼品格应显示紫装图标")

	# ⑩ 离线（没有后端）时按钮给出联网提示，不崩。
	_窗口.set("_backend", null)
	_提示.clear()
	await _打开藏宝页()
	var 离线钮 := _找(_页, "显示宝贝") as Button
	_查(离线钮 != null and not 离线钮.disabled, "离线也应当能点（点了给提示）")
	if 离线钮 != null:
		离线钮.pressed.emit()
	await process_frame
	_查(_提示.size() == 1 and String(_提示[0]).contains("联网"), "离线点按钮应提示联网，实得 %s" % [_提示])

	# ⑪ 开箱被拒不再静默（用户 2026-10-31：「点显示宝贝没有反应」）。
	#    服务端拒了只回一帧 state=0（`_send_treasure_state(None)`），按钮不吭声就等于没接。
	_窗口.set("_backend", _假)
	_提示.clear()
	await _打开藏宝页()
	var 重开钮 := _找(_页, "显示宝贝") as Button
	_查(重开钮 != null and not 重开钮.disabled, "⑪ 有《亲热天堂1》时按钮应可点")
	# 进页那次 17 的回帧（state=0）**不该**被当成「开箱落空」而弹提示。
	_假.发({"action": 17, "state": 0, "candidates": 候选, "gained": {}, "type": 2})
	await process_frame
	_查(_提示.is_empty(), "⑪ 进页查询的回帧不该弹「开箱落空」（实得 %s）" % [_提示])
	_假.调用.clear()
	重开钮.pressed.emit()
	await process_frame
	_查(_假.调用.size() == 1 and String(_假.调用[0][0]) == "open",
		"⑪ 点「显示宝贝」应发 request_treasure_open()，实得 %s" % [_假.调用])
	_假.发({"action": 17, "state": 0, "candidates": 候选, "gained": {}, "type": 2})
	await process_frame
	_查(_提示.size() == 1 and String(_提示[0]).contains("没能开箱"),
		"⑪ 开箱被拒（回 state=0）必须给个说法，实得 %s" % [_提示])

	# ⚠ `_收尾` 里有 `await process_frame`（等窗口真回收）⇒ 调用处必须 await，
	#   否则"还原背包 + 打结论 + quit"会跟外面的流程交错。
	await _收尾(原背包)


func 本格候选(i: int) -> Dictionary:
	# 只用来凑 16 个候选的显示（真实解析在上面的 17/18 帧里测过）。
	return {"id": 书一, "quantity": 3, "slot_index": 100 + i, "unique_id": 900 + i}


## ④b/④c 的装备候选：按服务端 `_encode_item_payload` 的 33 段装备体拼
## （公共 10 段 + `&10=aptitude / &22=strength_level / &23=strength_info`，
## 客户端 `_parse_item_entry:6170-6191` 就按这个下标读）。
func _装备候选串(资质: int, 星级: int) -> String:
	var 强化: Array = []
	for _i in range(星级):
		强化.append("true")
	var 段: Array = [
		1, 装备串id, 0, 1, 0, 0, 1, "-", 0, 777001,
		资质, 100, 100, 4, 35, 0, 21, "-", -1, 0, 0, "-",
		星级, "!".join(PackedStringArray(强化)) if 星级 > 0 else "-",
		0, 0, 0, 0, 0, "-", 0, 0, 0,
	]
	return "&".join(PackedStringArray(段.map(func(值): return str(值))))


func _打开藏宝页() -> void:
	_窗口.open_page("藏宝图")
	await process_frame
	await process_frame
	_页 = _找(_窗口.get("_content"), "原版亲热天堂内容") as Control


func _收尾(原背包: Array[Dictionary]) -> void:
	_会话.inventory.assign(原背包)
	if _窗口 != null and is_instance_valid(_窗口):
		_窗口.queue_free()
	await process_frame
	if _fails.is_empty():
		print("亲热天堂回归测试：通过（17/18 帧解析 / 四态钮 / 三书钮 / 16 候选格 / 停止定格 / 自动领取 / 紫装资质框与流光 / 离线提示 / 开箱被拒有说法）")
		quit(0)
	else:
		for 条 in _fails:
			printerr("!! " + 条)
		printerr("亲热天堂回归测试：%d 条不符" % _fails.size())
		quit(1)
