extends SceneTree

## 秘笈合成页「放入残卷」的**行为门**（§3.308）。
##
## 为什么要有这条：用户 10-28 报修「既不能从背包拖拽秘籍残卷到合成格里，也不能点放入秘籍
## 选择对应秘籍残卷」。病根 = 本页 10-03 从 `功能窗口.gd` 切件时**漏了给落点认领 `格子归属`**
## ——`残卷放入格` 与 `宝石放入格` 同款走 `super._can_drop_data`，那道闸第一句
## `格子归属.is_empty() ⇒ 拒`（宝石那页在 `功能窗口.gd:2897` 填了）。而旧门
## `秘笈合成页回归测试` 是纯几何 + 源码串（`_判(源.contains("请求放入.connect"))`），
## **真拖放路径一步没走** ⇒ 落点永远拒收它照样绿（假绿 #23 族）。本门钉的是运行时通路：
##   ① **真拖放**：载荷直接喂落点的 `_can_drop_data` / `_drop_data`（照 `勾玉炼制页回归测试`
##      ⑦ 的 `_能拖/_拖` 口径）——有效残卷该**接**、非残卷该**拒**、非背包归属该**拒**；
##      落上写 `秘笈合成窗口._放入格`、按钮换「取出残卷」、格上长出图标。
##   ② **放入钮三分支**（原版 `clickDropBtnHandler:326-340`）：空袋 ⇒ 空态话；有残卷 ⇒
##      游标处弹「残卷选择」清单（`PopupMenu`，一条一堆：名称 ×数量 + 图标），
##      `id_pressed` 一条即放入；已放入 ⇒ 点击取回、图标回空皮、文案回「放入残卷」。
##      ⚠ 清单这支是**用户点名的偏离**（原版 UpShelfCursor 无跟手件可移植），门钉的是移植口径。
##
## 硬口径（记忆里的老规矩）：不落存档（跑前记 `user://玩家数据.json` 字节、跑完断没变）；
## 改状态与断言之间隔帧；探针 lambda 形参类型与信号声明**一字不差**（假绿 #22）——
## `id_pressed` 的接收函数在控制器里（`_选残卷(序: int)`），本门只 emit 不另接探针。
## ⚠ 反馈口径：本页走的是 `_宿主._show_hint`（= `_status.text` + 写文案即显形，§3.107），
##   **不是** `会话.notification_requested`（那是 `_通知()` 那族）——首跑就在这红过一条。
##
## 运行：Godot --headless --path . --script res://测试/秘笈合成放入回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页名 := "技能书"		# `窗口尺寸.json` 的键；`窗口管理.打开("技能书")` 开这扇（背包双击带物同一路）
const 控制器 := preload("res://脚本/界面/窗口/秘笈合成窗口.gd")
const 落点路 := "内容框/放入残卷区/主残卷格"
const 钮路 := "内容框/放入残卷区/放入残卷"
## 两只有配方的残卷 + 一只没配方的材料（负向量）。id/name 与 `数据/物品.json` 同源：
##   08000013《崩掌》残卷 canjuan_book=6000028；09000001《猛击》残卷 canjuan_book=6000044；
##   16000032 手里剑木桩（在表、无 canjuan_book 列）⇒ `残卷放入格.有配方` 恒 false。
const 残卷一 := "08000013"
const 残卷二 := "09000001"
const 非残卷 := "16000032"
## 材料格4 的帮手道具：`秘笈合成配置.json` 的 `help_item`（`Etc.CanJuanHeCheng.help_item`）。
const 幸运符 := "16000015"
## 期望图标名从这张表取（`游戏数据.item_icon` 的数据源），别拿被测代码自己当期望。
const 图标索引路 := "res://数据/物品图标索引.json"

var 管: Node
var 红数 := 0
var 日志: Array[String] = []
var 存档前 := ""


class 假来源格:
	extends Button
	var 槽位号 := 0


func _记(过: bool, 文: String) -> void:
	if not 过:
		红数 += 1
	日志.append("  %s %s" % ["√" if 过 else "!!", 文])


func _等(n: int) -> void:
	for _i in range(n):
		await process_frame


## 提示文案 = 窗壳 `_status.text`（`_show_hint` 那支；§3.107 起"写文案即显形"）。
func _提示() -> String:
	var 窗 := _窗()
	var 标 := 窗.get("_status") as Label if 窗 != null else null
	return 标.text if 标 != null else ""


func _窗() -> Node:
	return 管._窗口们.get(页名) as Node


func _页() -> Control:
	var 窗 := _窗()
	if 窗 == null:
		return null
	var 出: Control = null
	for 子 in (窗.get_node("遮罩/主窗口/页面容器") as Control).get_children():
		if 子 is Control:
			出 = 子 as Control
	return 出


func _载荷(物品id: String, 归属: String, 格号: int) -> Dictionary:
	var 源 := 假来源格.new()
	源.槽位号 = 格号
	return {"归属": 归属, "物品id": 物品id, "来源格": 源}


func _能拖(格: Control, 载荷: Dictionary) -> bool:
	if not 格.has_method("_can_drop_data"):
		return false
	return bool(格.call("_can_drop_data", Vector2.ZERO, 载荷))


func _拖(格: Control, 载荷: Dictionary) -> void:
	if 格.has_method("_drop_data"):
		格.call("_drop_data", Vector2.ZERO, 载荷)


func _存档字节() -> String:
	var f := FileAccess.open("user://玩家数据.json", FileAccess.READ)
	return "" if f == null else f.get_as_text()


func _喂背包(会) -> void:
	会.inventory.clear()
	会.inventory.append({"id": 残卷一, "name": "《崩掌》残卷", "quantity": 1, "slot_index": 3})
	会.inventory.append({"id": 残卷二, "name": "《猛击》残卷", "quantity": 2, "slot_index": 7})
	会.inventory.append({"id": 非残卷, "name": "手里剑木桩", "quantity": 9, "slot_index": 5})


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	root.size = Vector2i(960, 560)		# 不钉这个，无头视口拿不到 GUI 命中
	存档前 = _存档字节()
	var 会 = root.get_node_or_null("/root/GameSession")
	if 会 == null:
		收尾("没有 GameSession 单例")
		return
	控制器._放入格 = -1
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _等(6)
	管 = 场景.get_node_or_null("窗口管理")
	if 管 == null:
		收尾("地图场景下没有 窗口管理")
		return
	管.call("全部关闭")
	管.call("打开", 页名)
	await _等(5)
	await _量落点()
	await _量真拖放(会)
	await _量放入钮(会)
	await _量材料格显示(会)
	await _量悬停详情(会)
	收尾()


## ⓪ 落点存在且被页面**认领**——这一条就是病根本体（旧门只钉源码串，看不见它）。
func _量落点() -> void:
	日志.append("=== 落点：存在 / 被认领（§3.308 病根）===")
	var 窗 := _窗()
	_记(窗 != null, "开窗「%s」成功" % 页名)
	if 窗 == null:
		return
	var 页 := _页()
	_记(页 != null, "页面根挂上（页面容器里有 Control）")
	if 页 == null:
		return
	var 格 := 页.get_node_or_null(落点路) as Button
	_记(格 != null, "主残卷格 = %s（Button 落点件在位）" % 落点路)
	if 格 == null:
		return
	_记(格.has_method("_can_drop_data"), "落点挂的是 `残卷放入格`（有拖放协议方法）")
	_记(String(格.get("格子归属")) != "", "落点被页面认领 `格子归属`（实测「%s」）——"
			% String(格.get("格子归属")) + "空 = 一切拖放死在 `可拖拽格._can_drop_data` 闸一")


## ① 真拖放通路：该收的收、该拒的拒、落上刷视图。
func _量真拖放(会) -> void:
	日志.append("=== 真拖放：准入闸 / 落上换态 / 换件 ===")
	var 快照: Array = (会.inventory as Array).duplicate(true)
	_喂背包(会)
	var 页 := _页()
	if 页 == null:
		收尾("真拖放：没有页")
		return
	var 格 := 页.get_node(落点路) as Button
	_记(_能拖(格, _载荷(残卷一, "背包", 3)), "有配方残卷从背包拖来 ⇒ 该收（修复前恒 false = 病根复现位）")
	_记(not _能拖(格, _载荷(非残卷, "背包", 5)), "没配方的材料（手里剑木桩）⇒ 该拒")
	_记(not _能拖(格, _载荷(残卷一, "仓库", 3)), "非背包归属 ⇒ 该拒")
	_拖(格, _载荷(残卷一, "背包", 3))
	await _等(2)
	_记(控制器._放入格 == 3, "落上写 `_放入格`=来源格 3（实测 %d）" % 控制器._放入格)
	_记(页.get_node(钮路).text == "取出残卷", "按钮文案换「取出残卷」（`DROP_ITEM_BTN_NAMES[3]`）")
	var 图: Texture2D = (格 as Button).icon
	_记(图 != null and 图.resource_path.get_file() != "物品格.png",
			"格上长出残卷图标、不再是空皮（`_刷视图` 现读跟到，实测「%s」）"
			% ("null" if 图 == null else 图.resource_path.get_file()))
	_拖(格, _载荷(残卷二, "背包", 7))
	await _等(2)
	_记(控制器._放入格 == 7, "落第二只 ⇒ 换件到格 7（原版 `dropItemHandler` 无条件换）")
	会.inventory.clear()
	for 件 in 快照:
		会.inventory.append(件)


## ② 放入钮三分支：空袋话 / 弹清单选择 / 已放入取回。
func _量放入钮(会) -> void:
	日志.append("=== 放入钮：空袋话 / 残卷选择清单 / 取出 ===")
	控制器._放入格 = -1
	var 页 := _页()
	if 页 == null:
		收尾("放入钮：没有页")
		return
	var 钮 := 页.get_node(钮路) as Button
	# —— 空袋一支
	var 快照: Array = (会.inventory as Array).duplicate(true)
	会.inventory.clear()
	钮.pressed.emit()
	await _等(2)
	_记(_提示() == "请放入忍术残卷！", "空袋点放入钮 ⇒ 原版空态话（`upgradeHandler:149-152`，实测「%s」" % _提示())
	_记(页.get_node_or_null("残卷选择") == null, "空袋不该弹清单")
	# —— 有残卷一支：弹清单、点一条放入
	_喂背包(会)
	钮.pressed.emit()
	await _等(2)
	var 单 := 页.get_node_or_null("残卷选择") as PopupMenu
	_记(单 != null, "有残卷点放入钮 ⇒ 弹「残卷选择」清单（原版 UpShelfCursor 的等价通道，用户点名偏离）")
	if 单 != null:
		# 清单里只有两只残卷堆（材料 16000032 无配方不进单）——按 id 匹配，不钉堆的先后
		var 词: Array[String] = []
		for i in 单.get_item_count():
			词.append(单.get_item_text(i))
		var joined := " | ".join(词)
		_记(单.get_item_count() == 2, "清单 2 条（两只残卷堆；没配方材料被闸挡在门外），实测 %d 条「%s」"
				% [单.get_item_count(), joined])
		_记(joined.contains("《崩掌》残卷 ×1") and joined.contains("《猛击》残卷 ×2"),
				"清单文案 = 名称 ×数量（逐字 %s）" % joined)
		var 有图 := true
		for i in 单.get_item_count():
			if 单.get_item_icon(i) == null:
				有图 = false
		_记(有图, "每条带图标（`游戏数据.item_icon`）")
		# 点第二条（格 7）——生产就是 `id_pressed` 驱动 `_选残卷`，emit 它 = 走生产处理函数
		单.id_pressed.emit(1)
		await _等(2)
		_记(控制器._放入格 == 7, "点清单第二条 ⇒ 放入格 7（实测 %d）" % 控制器._放入格)
		_记(钮.text == "取出残卷", "放入后按钮态跟进「取出残卷」")
	# —— 已放入一支：再点 = 取出
	钮.pressed.emit()
	await _等(2)
	_记(控制器._放入格 == -1, "已放入再点 ⇒ 取回背包（`backItemToEquip` 支），实测 _放入格=%d" % 控制器._放入格)
	_记(钮.text == "放入残卷", "取出后文案回「放入残卷」（`DROP_ITEM_BTN_NAMES[2]`）")
	var 格 := 页.get_node(落点路) as Button
	_记(格.icon != null and 格.icon.resource_path.get_file() == "物品格.png", "取出后格回空皮")
	会.inventory.clear()
	for 件 in 快照:
		会.inventory.append(件)


## ③ 材料格显示（用户 2026-11-02 报「辅残券、幸运符的显示都没有正确接入」）。
## 真值 `JiNengCompositeWindow.as`：
##   `updateView:84-109`  fu1 = 主残卷同款 itemData；fu2/fu3 的 `_loc2_/_loc3_` **从未赋值**（恒空）；
##                        fu4 = `createSingleItem(helpItemId)`；
##   `updateXingYunRatio:392-396`  fu1.label = `needCnt - 1`、fu4.label = 背包拥有数、
##                        fu4.hasItem() 在拥有 0 时打灰；
##   `itemDatachanged:312` 背包一变补 fu4 拥有数。
## 崩掌残卷 `canjuan_need = 3`（`数据/物品.json`）⇒ 辅残卷格该写 **2**。
func _量材料格显示(会) -> void:
	日志.append("=== 材料格：辅残卷角标 / 幸运符图标与拥有数 ===")
	var 快照: Array = (会.inventory as Array).duplicate(true)
	控制器._放入格 = -1
	会.inventory.clear()
	会.inventory.append({"id": 残卷一, "name": "《崩掌》残卷", "quantity": 2, "slot_index": 3})
	会.inventory.append({"id": 幸运符, "name": "幸运符", "quantity": 5, "slot_index": 11})
	var 页 := _页()
	if 页 == null:
		收尾("材料格显示：没有页")
		return
	var 落点 := 页.get_node(落点路) as Button
	_拖(落点, _载荷(残卷一, "背包", 3))
	await _等(2)
	var 图1 := 页.get_node_or_null("内容框/材料格1/物品格") as TextureRect
	var 标1 := 页.get_node_or_null("内容框/材料格1/数量") as Label
	_记(图1 != null and _图标名(图1) == _索引图名(残卷一),
		"辅残卷1 长出主残卷同款图标（`_fu1.itemCell.itemData = _itemData`，实测「%s」）"
		% ("<null>" if 图1 == null else _图标名(图1)))
	_记(标1 != null and 标1.text == "2",
		"辅残卷1 角标 = needCnt − 1 = 2（`updateXingYunRatio:392`；崩掌 canjuan_need=3，实测「%s」）"
		% ("<null>" if 标1 == null else 标1.text))
	for i in [2, 3]:
		var 图 := 页.get_node_or_null("内容框/材料格%d/物品格" % i) as TextureRect
		var 标 := 页.get_node_or_null("内容框/材料格%d/数量" % i) as Label
		_记(图 != null and _图标名(图) == "物品格.png",
			"辅残卷%d 原版 itemData 恒 null ⇒ 保持空皮（实测「%s」）" % [i, "<null>" if 图 == null else _图标名(图)])
		_记(标 != null and 标.text == "",
			"辅残卷%d 不写数字（实测「%s」）" % [i, "<null>" if 标 == null else 标.text])
	var 图4 := 页.get_node_or_null("内容框/材料格4/物品格") as TextureRect
	var 标4 := 页.get_node_or_null("内容框/材料格4/数量") as Label
	_记(图4 != null and _图标名(图4) == _索引图名(幸运符),
		"幸运符格图标 = helpItemId 16000015 的图标（实测「%s」）" % ("<null>" if 图4 == null else _图标名(图4)))
	_记(标4 != null and 标4.text == "5",
		"幸运符角标 = 背包拥有数 5（`_fu4.itemCell.label`，实测「%s」）" % ("<null>" if 标4 == null else 标4.text))
	_记(标4 != null and 标4.material == null and 图4 != null and 图4.material == null,
		"拥有 5 > 0 ⇒ 幸运符格不打灰（`hasItem()` 只在拥有 0 时套灰）")
	# 拥有归零 ⇒ 数变 0、图标+数字一起打灰（生产由背包帧刷新；这里直接走刷视图函数）
	for j in range(会.inventory.size() - 1, -1, -1):
		if String((会.inventory[j] as Dictionary).get("id", "")) == 幸运符:
			会.inventory.remove_at(j)
	控制器._刷视图()
	await _等(2)
	图4 = 页.get_node_or_null("内容框/材料格4/物品格") as TextureRect
	标4 = 页.get_node_or_null("内容框/材料格4/数量") as Label
	_记(标4 != null and 标4.text == "0", "幸运符没了 ⇒ 角标 0（实测「%s」）" % ("<null>" if 标4 == null else 标4.text))
	_记(图4 != null and 图4.material != null and 标4 != null and 标4.material != null,
		"拥有 0 ⇒ 幸运符格图标+数字一起打灰（`ItemCaiLiaoBox.hasItem`）")
	控制器._放入格 = -1
	会.inventory.clear()
	for 件 in 快照:
		会.inventory.append(件)
	控制器._刷视图()
	await _等(2)


## ④ 悬停详情：主残卷格（`ItemDropBox.itemCell`）+ 四枚材料格（`ItemCaiLiaoBox`）在原版
## 都填 `itemData`（`JiNengCompositeWindow.as:107-122`），`SimpleItemCell.as:220` 一有 itemData
## 就挂 MToolTipItem。2026-11-02 巡检：本页原缺这一段（与生命料理/通灵驯养同族）。
## 空态（fu2/fu3 的 itemData 恒 null）悬停必须把框收掉，不能留着上一件的。
func _量悬停详情(会) -> void:
	日志.append("=== 悬停详情：落点 / 辅残卷1 / 空格 / 幸运符 ===")
	var 快照: Array = (会.inventory as Array).duplicate(true)
	控制器._放入格 = -1
	会.inventory.clear()
	会.inventory.append({"id": 残卷一, "name": "《崩掌》残卷", "quantity": 2, "slot_index": 3})
	会.inventory.append({"id": 幸运符, "name": "幸运符", "quantity": 5, "slot_index": 11})
	var 页 := _页()
	if 页 == null:
		收尾("悬停详情：没有页")
		return
	var 框 := 页.get_node_or_null("物品提示框") as Control
	_记(框 != null, "页面该在运行期挂上 物品提示框（原版每枚 itemCell 都带 MToolTipItem）")
	if 框 != null:
		var 落点 := 页.get_node(落点路) as Control
		_拖(落点, _载荷(残卷一, "背包", 3))
		await _等(2)
		# 空态：fu2 的 itemData 恒 null ⇒ 先把框强行点亮，悬停应把它收掉
		框.visible = true
		var 空格 := 页.get_node_or_null("内容框/材料格2/物品格") as Control
		_记(空格 != null and 空格.mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"材料格2 的物品格被接成可悬停（PASS；空格子也要收框）")
		if 空格 != null:
			空格.mouse_entered.emit()
			_记(not 框.visible, "悬停空材料格 ⇒ 详情框收起（itemData=null 那一态）")
		# 主残卷格：itemData = 放进去的那一摞
		落点.mouse_entered.emit()
		var 标题 := 框.get_node("标题") as Label
		_记(框.visible and String(标题.text) == "《崩掌》残卷",
			"悬停主残卷格 ⇒ 弹该残卷详情（实测「%s」）" % (标题.text if 框.visible else "<没弹>"))
		落点.mouse_exited.emit()
		_记(not 框.visible, "移开主残卷格 ⇒ 详情框收起")
		# 辅残卷1 = 主残卷同款 itemData
		var 图1 := 页.get_node_or_null("内容框/材料格1/物品格") as Control
		if 图1 != null:
			图1.mouse_entered.emit()
		_记(图1 != null and 框.visible and String(标题.text) == "《崩掌》残卷",
			"悬停辅残卷1 ⇒ 弹主残卷详情（`_fu1.itemCell.itemData = this._itemData`）")
		if 图1 != null:
			图1.mouse_exited.emit()
		# 幸运符格 = createSingleItem(helpItemId)
		var 图4 := 页.get_node_or_null("内容框/材料格4/物品格") as Control
		if 图4 != null:
			图4.mouse_entered.emit()
		_记(图4 != null and 框.visible and String(标题.text) == "幸运符",
			"悬停材料格4 ⇒ 弹「幸运符」详情（实测「%s」）" % (标题.text if 框.visible else "<没弹>"))
		if 图4 != null:
			图4.mouse_exited.emit()
		_记(not 框.visible, "移开材料格4 ⇒ 详情框收起")
	控制器._放入格 = -1
	会.inventory.clear()
	for 件 in 快照:
		会.inventory.append(件)
	控制器._刷视图()
	await _等(2)


func _图标名(图: TextureRect) -> String:
	var 纹 := 图.texture
	return "<null>" if 纹 == null else 纹.resource_path.get_file()


func _索引图名(物品id: String) -> String:
	var 解: Variant = JSON.parse_string(FileAccess.get_file_as_string(图标索引路))
	if 解 is Dictionary:
		return String((解 as Dictionary).get(物品id, "")).get_file()
	return ""


func 收尾(致命: String = "") -> void:
	if 致命 != "":
		日志.append("!! %s" % 致命)
		红数 += 1
	控制器._放入格 = -1
	控制器._选择清单 = []
	var 现 := _存档字节()
	_记(现 == 存档前, "跑完 `user://玩家数据.json` **字节没变**（本门不落存档）")
	if 现 != 存档前:
		日志.append("   ⇒ 说明这一族里有支会写档：查 `存档.保存()` 调用链")
	for 一 in 日志:
		print(一)
	print("秘笈合成放入回归：%s（断言 %d，红 %d 项）" % ["通过" if 红数 == 0 else "不通过", 日志.size(), 红数])
	quit(1 if 红数 > 0 else 0)
