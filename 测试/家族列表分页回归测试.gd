extends SceneTree
## 「家族列表窗」的**显示分页 / 列头排序 / 每页条数**回归门（离线，假宿主）。
##
## 钉的是原版 `FamillyListWindow.as` 的口径：
##   * 每页条数默认 **10**（`initView` 的 `_yeComboBox.selectedIndex = 0`，`:359`）⇒ 25 条 = 3 页；
##   * 分页四钮真翻页、页码标签跟着走、边界钮置灰（`PageComponent`，`:247-251`）；
##   * 列头点击换排序字段，默认「家徽等级」走 `sortComprareFun`（`:136-156`）；
##     名字类升序、数值类降序（`applySort`，`:290-317`）；
##   * 每页下拉换每页条数后重新分页（`yeBoxChangeHandler`，`:282-286`）。
##
## ⚠️ 为什么非要有这条门：这一窗这几样**原来全是空转控件**（场景里建好了，`装配` 一条没接）。
##    默认每页 10 却又翻不了页 ⇒ 家族一超过 10 个，后面的就永远看不到 ——
##    而用户要的正是"看到所有游戏中已经创建的家族"。光看截图看不出来（夹具里家族本来就少），
##    所以必须用**合成长列表**把切片和排序钉死。

const 壳脚本 := preload("res://脚本/界面/窗口/家族/家族子窗壳.gd")
const 宿主脚本 := preload("res://测试/假家族宿主.gd")

const 总数 := 25
const 每页 := 10

var _失败: Array[String] = []
var _宿主
var _页: Control
var _列: Control


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_宿主 = 宿主脚本.new()
	root.add_child(_宿主)
	await process_frame
	壳脚本.切换(_宿主, "家族列表窗", "家族列表")
	await process_frame
	_页 = 壳脚本.取内容(_宿主, "家族列表窗")
	if _页 == null:
		_失败.append("家族列表窗没开出来")
		_收尾()
		return
	_列 = _页.get_node_or_null("列表窗口/内容列") as Control
	if _列 == null:
		_失败.append("取不到 列表窗口/内容列")
		_收尾()
		return

	_页.call("刷新", _造表(总数))
	await process_frame

	# ① 默认每页 10 ⇒ 25 条 = 3 页，只画 10 行。
	_验页码("1/3", "初始")
	_验行数(每页, "初始")
	_验钮灰("分页/首页", true, "初始首页钮应灰")
	_验钮灰("分页/上一页", true, "初始上一页钮应灰")
	_验钮灰("分页/下一页", false, "初始下一页钮不该灰")
	_验钮灰("分页/末页", false, "初始末页钮不该灰")
	# 默认排序 = 家徽等级降序、同则等级总和降序（`sortComprareFun`）
	_验顺序(_期望默认排序(), "默认排序（家徽等级降序，同则等级总和降序）")

	# ② 下一页 → 2/3，仍是 10 行
	_按键("分页/下一页")
	await process_frame
	_验页码("2/3", "点下一页后")
	_验行数(每页, "第 2 页")

	# ③ 末页 → 3/3，只剩 5 行
	_按键("分页/末页")
	await process_frame
	_验页码("3/3", "点末页后")
	_验行数(总数 - 每页 * 2, "第 3 页")
	_验钮灰("分页/下一页", true, "末页时下一页钮应灰")
	_验钮灰("分页/末页", true, "末页时末页钮应灰")
	_验钮灰("分页/首页", false, "末页时首页钮不该灰")

	# ④ 列头「家族名称」→ 升序（`sortOn("name", CASEINSENSITIVE)`），并且回到第 1 页
	_点列头("家族名称")
	await process_frame
	_验页码("1/3", "换排序后")
	_验顺序(_期望名升序(), "列头「家族名称」升序")
	_验三角("家族名称", true, "「家族名称」的排序三角该亮")
	_验三角("家徽等级", false, "「家徽等级」的排序三角该灭")

	# ⑤ 列头「族中人数」→ 降序（`Array.DESCENDING`）
	_点列头("族中人数")
	await process_frame
	_验顺序(_期望人数降序(), "列头「族中人数」降序")

	# ⑥ 每页下拉换成「100项」→ 一页装得下 25 条
	_开下拉("页下拉")
	await process_frame
	_选下拉项(3)
	await process_frame
	_验页码("1/1", "每页 100 后")
	_验行数(总数, "每页 100 后")
	var 字 := (_页.get_node("页下拉/文字") as Label).text
	if 字 != "100项":
		_失败.append("页下拉文字是 %s，应为 100项" % 字)

	_收尾()


## 合成一份 25 条的家族表：名字、家徽等级、等级总和、人数、BOSS 数都互不相同，
## 这样"排在第几个"本身就是判据，不用去猜稳定排序的细节。
func _造表(n: int) -> Array:
	var 表: Array = []
	for i in n:
		表.append({
			"id": i + 1, "channel_id": 1,
			"name": "族%02d" % (n - i),			# i=0 → 族25 … i=24 → 族01
			"leader": "族长%02d" % (n - i),
			"leader_id": 100 + i,
			"flag_level": (i % 5) + 1,		# 1..5，5 是最高的
			"members": i + 1,
			"capacity": 50,
			"level_sum": i * 3,
			"boss_sum": i * 2,
			"flag_style": 1000 + (i % 20),
			"flag_name": "徽%02d" % i,
		})
	return 表


# ── 期望顺序 ───────────────────────────────────────────────────────────
# 直接写成字面表，不在门里重写一遍排序（重写一遍就等于拿同一个错逻辑验自己）。
# 合成表的口径：flag_level = i%5+1、level_sum = i*3、members = i+1、name = "族%02d" % (25−i)。

## 家徽等级降序、同则等级总和降序 ⇒ 先按等级分桶（每桶 5 个，桶内 i 降序）。
func _期望默认排序() -> Array:
	return [24, 19, 14, 9, 4, 23, 18, 13, 8, 3, 22, 17, 12, 7, 2,
		21, 16, 11, 6, 1, 20, 15, 10, 5, 0]


## 名字升序：名字是 "族%02d" % (25−i)，i 越大名字越小 ⇒ i 降序。
func _期望名升序() -> Array:
	return _期望人数降序()


## 人数降序：members = i+1 ⇒ i 降序。
func _期望人数降序() -> Array:
	var 序: Array = []
	for i in range(总数 - 1, -1, -1):
		序.append(i)
	return 序


func _期望名(i: int) -> String:
	return "族%02d" % (总数 - i)


# ── 断言 ───────────────────────────────────────────────────────────────

func _验页码(期望: String, 场景: String) -> void:
	var 节 := _页.get_node_or_null("分页/页码") as Label
	if 节 == null:
		_失败.append("%s：取不到 分页/页码" % 场景)
		return
	if 节.text != 期望:
		_失败.append("%s：页码是 %s，应为 %s" % [场景, 节.text, 期望])


func _验行数(期望: int, 场景: String) -> void:
	var 数 := 0
	for 子 in _列.get_children():
		if String(子.name).begins_with("行"):
			数 += 1
	if 数 != 期望:
		_失败.append("%s：画了 %d 行，应为 %d 行" % [场景, 数, 期望])


func _验顺序(期望序: Array, 场景: String) -> void:
	var 实: Array = []
	for 子 in _列.get_children():
		if not String(子.name).begins_with("行"):
			continue
		var 字 := 子.get_node_or_null("家族名称") as Label
		实.append(String(字.text) if 字 != null else "?")
	var 期: Array = []
	for i in 期望序:
		期.append(_期望名(int(i)))
	var 期截: Array = 期.slice(0, 实.size())
	if 实 != 期截:
		_失败.append("%s：行序不对\n      实=%s\n      期=%s" % [场景, 实, 期截])


func _验钮灰(路径: String, 期望灰: bool, 场景: String) -> void:
	var 钮 := _页.get_node_or_null(路径) as TextureButton
	if 钮 == null:
		_失败.append("%s：取不到 %s" % [场景, 路径])
		return
	if 钮.disabled != 期望灰:
		_失败.append("%s：%s 的 disabled=%s，应为 %s" % [场景, 路径, 钮.disabled, 期望灰])


func _验三角(列: String, 期望亮: bool, 场景: String) -> void:
	var 三 := _页.get_node_or_null("表头/三角%s" % 列) as TextureRect
	if 三 == null:
		_失败.append("%s：取不到 表头/三角%s" % [场景, 列])
		return
	if 三.visible != 期望亮:
		_失败.append("%s：三角%s.visible=%s，应为 %s" % [场景, 列, 三.visible, 期望亮])


func _按键(路径: String) -> void:
	var 钮 := _页.get_node_or_null(路径) as TextureButton
	if 钮 == null:
		_失败.append("取不到 %s" % 路径)
		return
	钮.pressed.emit()


func _点列头(列: String) -> void:
	var 头 := _页.get_node_or_null("表头/%s" % 列) as Label
	if 头 == null:
		_失败.append("取不到 表头/%s" % 列)
		return
	if 头.mouse_filter != Control.MOUSE_FILTER_STOP:
		_失败.append("表头「%s」的 mouse_filter 不是 STOP ⇒ 点不到" % 列)
		return
	var 事件 := InputEventMouseButton.new()
	事件.button_index = MOUSE_BUTTON_LEFT
	事件.pressed = true
	头.gui_input.emit(事件)


func _开下拉(路径: String) -> void:
	var 钮 := _页.get_node_or_null(路径) as TextureButton
	if 钮 == null:
		_失败.append("取不到 %s" % 路径)
		return
	钮.pressed.emit()


func _选下拉项(序: int) -> void:
	var 根 := _页.get_parent()
	var 底 := 根.get_node_or_null("下拉") if 根 != null else null
	if 底 == null:
		_失败.append("下拉没弹出来")
		return
	var 项 := 底.get_node_or_null("项%d" % 序) as Button
	if 项 == null:
		_失败.append("下拉里没有 项%d" % 序)
		return
	项.pressed.emit()


func _收尾() -> void:
	if _失败.is_empty():
		print("家族列表分页回归测试：通过（25 条 / 每页 10 / 3 页；分页·排序·每页下拉全通）")
		quit(0)
		return
	for 条 in _失败:
		print("  !! " + 条)
	print("家族列表分页回归测试：FAIL %d 条" % _失败.size())
	quit(1)
