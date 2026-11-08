extends SceneTree

## 人物面板下方**四个套装图标**的点亮条件。
##
## 出处 `EquipPane.as:918-927` 的 `setSeriesIcon()` +
## `ItemFactory.isSameStage / isAllPurple / isFullStar / isFullStone`。
## ⚠️ 原版**不是 visible 开关**，是 `filters` 灰化；这里用"换灰版贴图"对应。
## ⚠️ 阈值全是**硬编码**：12 件同阶 / 品质 4 或 5 / 强化 >=10 / 镶嵌 >=5 槽且宝石 >=6 级；
##    而且**件数 <= 11 时四灯全灰**。
##
## 之前只写了逻辑、**没验过**（用户 2026-09-25 问"你有做对应功能匹配吗"）。
## 这条用例就是补这个：灌不同组合的装备，看四个灯该亮的亮、该灰的灰。
##
## 用法：
##   Godot --headless --path . --script res://测试/套装图标回归测试.gd

const 人物窗口脚本 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 部位 := preload("res://脚本/单例/装备部位.gd")
const 灰标 := "_灰.png"

var _失败: Array[String] = []
var _窗口: Node = null
var _会话: Node = null


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_窗口 = (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(_窗口)
	_会话 = root.get_node_or_null("GameSession")
	if _会话 == null:
		_失败.append("没有 GameSession 单例")
		_收尾()
		return
	await process_frame
	_窗口.call("open_page", "人物")
	for _i in 30:
		await process_frame

	# ① 空装 → 四灯全灰
	await _灌({})
	_检亮([])

	# ② 只穿 11 件同阶 → 仍然全灰（原版 `<= 11` 直接全灰）
	var 十一 := {}
	for i in 11:
		十一[部位.标准槽[i]] = _造装备(1, 1, 0, [])
	await _灌(十一)
	_检亮([])

	# ③ 12 件全同阶（阶=5），品质白、无强化、无镶嵌 → 只有「等阶」亮
	var 同阶 := {}
	for 位 in 部位.标准槽:
		同阶[位] = _造装备(5, 1, 0, [])
	await _灌(同阶)
	_检亮(["等阶套装"])

	# ④ 12 件全紫（品质 4），阶各不相同 → 只有「全紫」亮
	var 全紫 := {}
	for i in 部位.标准槽.size():
		全紫[部位.标准槽[i]] = _造装备(i + 1, 4, 0, [])
	await _灌(全紫)
	_检亮(["全紫套装"])

	# ⑤ 12 件全强化 10 → 只有「满星」亮
	var 满星 := {}
	for i in 部位.标准槽.size():
		满星[部位.标准槽[i]] = _造装备(i + 1, 1, 10, [])
	await _灌(满星)
	_检亮(["满星套装"])

	# ⑥ 12 件全镶嵌 5 槽、宝石 6 级 → 只有「满融」亮
	var 满融 := {}
	for i in 部位.标准槽.size():
		满融[部位.标准槽[i]] = _造装备(i + 1, 1, 0, [6, 6, 6, 6, 6])
	await _灌(满融)
	_检亮(["六级满融套装"])

	# ⑦ 宝石只有 5 级 → 不满融
	var 差一级 := {}
	for i in 部位.标准槽.size():
		差一级[部位.标准槽[i]] = _造装备(i + 1, 1, 0, [6, 6, 6, 6, 5])
	await _灌(差一级)
	_检亮([])

	# ⑧ 四样全满足 → 四灯全亮
	var 全亮 := {}
	for 位 in 部位.标准槽:
		全亮[位] = _造装备(7, 4, 10, [6, 6, 6, 6, 6])
	await _灌(全亮)
	_检亮(["等阶套装", "全紫套装", "满星套装", "六级满融套装"])

	# ⑨ ⭐ 六颗宝石、其中一颗 5 级 → 原版 `getInlayState`：**>5 槽容许恰好一颗 <6** ⇒ 满融亮。
	#    （2026-10-01 之前的实现"所有宝石一律 >=6"比原版严，这条就是钉这个差别的。）
	var 六融 := {}
	for i in 部位.标准槽.size():
		六融[部位.标准槽[i]] = _造装备(i + 1, 1, 0, [6, 6, 6, 6, 6, 5])
	await _灌(六融)
	_检亮(["六级满融套装"])

	# ⑩ 六颗里有两颗 5 级 → 低的不止一颗 ⇒ 仍不亮
	var 六融差二 := {}
	for i in 部位.标准槽.size():
		六融差二[部位.标准槽[i]] = _造装备(i + 1, 1, 0, [6, 6, 6, 6, 5, 5])
	await _灌(六融差二)
	_检亮([])

	# ⑪ 计数三角标：空装全隐；12 全紫 → 紫=12；只 6 件紫 → 紫=6、星/融隐
	await _灌({})
	_检计数({})
	var 半紫 := {}
	for i in 6:
		半紫[部位.标准槽[i]] = _造装备(1, 4, 0, [])
	for i in range(6, 12):
		半紫[部位.标准槽[i]] = _造装备(2, 1, 10, [])
	await _灌(半紫)
	_检计数({"紫件数": 6, "满星件数": 6})
	await _灌(全亮)
	_检计数({"紫件数": 12, "满星件数": 12, "满融件数": 12})

	# ⑫ 意志格：数值必须来自 **已穿戴意志的 Σ rongHeExp ÷ 30**
	#    （原版 `YiZhiManager.updateYiZhiLi:284` 推给人物面板那格；公式 `caculateYiZhiLi:168-181`）。
	#    ⚠️ 2026-10-13 修：以前读 `属性.will`（全工程没人写的键）⇒ 那格恒 0，这条就是钉它的。
	#    先拿等级格当对照，证明读数这条链通（否则「读不到」会被当成「值对」）。
	#    ⚠️ 2026-10-21 修（§3.181）：样本必须带 `color`（协议行恒有；单件 rongHeExp =
	#    `common.levelUp.level1[色名] + exp`，见 `YiZhiData.rongHeExp:92-101`）——
	#    老样本没写 color ⇒ 色名查不到 ⇒ rongHeExp 0，而旧公式（只加原始 exp）碰巧能得
	#    (300+150)÷30=15。现在按真值口径给两件蓝意志（基础 60）：(360+210)÷30 = **19**。
	var 等级期望 := str(int(_会话.player_stats.get("level", 1)))
	if _读信息格("等级格") != 等级期望:
		_失败.append("对照：等级格该显示 %s、实测「%s」（读数链不通）" % [等级期望, _读信息格("等级格")])
	_会话.spirit_equipped = [
		{"slot": -1, "color": 3, "exp": 300, "name": "甲", "level": 1},
		{"slot": -2, "color": 3, "exp": 150, "name": "乙", "level": 1}]
	await _灌({})
	if _读信息格("意志格") != "19":
		_失败.append("意志格该显示 19（蓝件 rongHeExp (60+300)+(60+150)=570，÷30），实测「%s」" % _读信息格("意志格"))
	_会话.spirit_equipped = []
	await _灌({})
	if _读信息格("意志格") != "0":
		_失败.append("卸光意志该回到 0，实测「%s」" % _读信息格("意志格"))

	_收尾()


## 人物页「信息区/某格/数值」那枚 Label 的文本（读不到返回空串）。
func _读信息格(格名: String) -> String:
	var 页 := _窗口.get("_content") as Control
	if 页 == null or 页.get_child_count() == 0:
		return ""
	var 面板 := (页.get_child(0) as Control).get_node_or_null("原版人物属性面板") as Control
	if 面板 == null:
		return ""
	var 值 := 面板.get_node_or_null("信息区/%s/数值" % 格名) as Label
	return String(值.text) if 值 != null else ""


func _检计数(期望: Dictionary) -> void:
	var 栏 := _找栏()
	if 栏 == null:
		_失败.append("找不到装备栏，计数角标没法查")
		return
	for 名 in ["紫件数", "满星件数", "满融件数"]:
		var 根 := 栏.get_node_or_null("强化计数/%s" % 名) as Control
		if 根 == null:
			_失败.append("缺少计数角标节点：强化计数/%s" % 名)
			continue
		var 字 := 根.get_node_or_null("数字") as Label
		if 期望.has(名):
			if not 根.visible:
				_失败.append("%s 应可见（件数 %d）" % [名, 期望[名]])
			elif 字 == null or 字.text != str(期望[名]):
				_失败.append("%s 数字应为 %s（实际 %s）" % [名, 期望[名], 字.text if 字 != null else "?"])
		elif 根.visible:
			_失败.append("%s 件数为 0 时应隐藏" % 名)
	# 位置钉一条：原版 strengthIcon1~3 x=103/133/163、y=192 是**格空间**（`EquipPane.as:200-210`），
	# 我方装备栏里 cell0 顶在 y=64 ⇒ 装备栏局部 y=**256**。
	# （第一版直接写了 192，把角标摆到灵器/忍具那两格里去了。）
	if 栏 != null:
		for i in 人物窗口脚本.计数角标名.size():
			var 根i := 栏.get_node_or_null("强化计数/%s" % 人物窗口脚本.计数角标名[i]) as Control
			if 根i != null and 根i.position.y != 256.0:
				_失败.append("%s 的 y 应为 256（格空间 192 + cell0 起点 64），实际 %.0f"
						% [人物窗口脚本.计数角标名[i], 根i.position.y])


## 造一件假装备。字段名照 `人物窗口._更新套装图标` 里读的那几个。
func _造装备(阶: int, 资质: int, 强化: int, 宝石等级们: Array) -> Dictionary:
	var 嵌: Array = []
	for 级 in 宝石等级们:
		嵌.append({"level": int(级)})
	return {"id": "0000000", "stage": 阶, "aptitude": 资质, "strengthen": 强化, "inlays": 嵌}


## 灌进会话并重渲染，然后回读四个图标挂的是彩图还是灰图。
func _灌(装备表: Dictionary) -> void:
	_会话.equipped_items = {}
	for 位 in 装备表:
		_会话.equipped_items[位] = 装备表[位]
	_窗口.call("open_page", "人物")
	for _i in 30:
		await process_frame
	_当前亮 = _读亮灯()


var _当前亮: Array = []


func _读亮灯() -> Array:
	var 出: Array = []
	var 栏 := _找栏()
	if 栏 == null:
		return 出
	for 名 in 人物窗口脚本.套装图标名:
		# 图标在子容器 `套装图标` 里 —— 与被测代码同一个坑（原先查直子层恒 null）。
		var 图 := 栏.get_node_or_null("套装图标/%s" % 名) as TextureRect
		if 图 == null:
			continue
		var 路 := 图.texture.resource_path if 图.texture != null else ""
		出.append([名, not 路.ends_with(灰标)])
	return 出


func _找栏() -> Node:
	var 面 := _窗口.get_node_or_null("遮罩/主窗口/页面容器/原版人物窗口内容/原版人物属性面板")
	return 面.get_node_or_null("装备栏") if 面 != null else null


func _检亮(期望: Array) -> void:
	var 实: Array = []
	for 项 in _当前亮:
		if 项[1]:
			实.append(项[0])
	实.sort()
	var 期 := 期望.duplicate()
	期.sort()
	if 实 != 期:
		var 明细 := []
		for 项 in _当前亮:
			明细.append("%s=%s" % [项[0], "亮" if 项[1] else "灰"])
		_失败.append("期望亮的 %s，实际亮的 %s  （明细 %s）" % [期, 实, 明细])


func _收尾() -> void:
	if _失败.is_empty():
		print("套装图标回归测试：通过（12 种组合：四灯该亮的亮、该灰的灰；计数角标按件数显隐）")
		quit(0)
		return
	for 项 in _失败:
		push_error("套装图标回归测试：失败 - %s" % 项)
	quit(1)
