extends SceneTree

## 「橙装打造 / 橙装精炼」窗（原版 `YellowEquipLianZhiWindow.as`，376×407）回归门（2026-11-04）。
##
## 用户报修：「传说装备打造石，功能未实装，点击显示是材料或人物物品，不能直接使用」。
## 根因：`ItemWindow2.as:979-988` 的 `isItemCanDaZao / isItemCanJingLian` 两支
## 都**当场 return、不发 USE_ITEM**（和梦幻属性符同一类），本工程没拦截 ⇒ 掉进
## `use_inventory_slot`，在线发一条没人处理的 USE_ITEM、离线回「是材料或任务物品」。
##
## 盯的件（括号里是 AS3 出处）：
##   A. 入口：窗口尺寸 376×407 / 内容底关 / 原点 0,0；`窗口管理.伴随背包` 收它（成对开）；
##      双击打造石 / 精炼石分别开 0 / 1 页签，**一格不发**；普通道具仍走 use_inventory_slot。
##   B. 打造页空态：两枚页签、说明/注意/标签逐字、材料=传说装备打造石、数量空、材料格灰、
##      「购买」隐藏（`updateView` case 0 `buyBtn.visible = false`）、消耗行 0 金币 / 100%。
##   C. 落装备（`validateItem:292-330`）：非打造装备 / 时装 / 玉链 / 徽章 / 破损各回原版那句、
##      **都不收**；资质**不在落料时判** —— 蓝件也收（判资质在点「开始打造」时）。
##   D. 打造提交（`strengthHandler:146-198`）：非紫 / 未满 10 星 / 不足 60 级 / 缺料 各自拒、
##      **不发帧**；紫 10 星 60 级 ⇒ `request_change_to_orange(背包格)`。
##   E. 精炼页：说明/注意/标签换成精炼三段；购买键显示；精炼页橙装时消耗行先带「传说属性：」；
##      紫装点精炼 ⇒ JINGLIAN_ERROR、不发帧；橙装 ⇒ `request_change_tale_attribute(背包格)`。
##   F. 换页签先清台面（`selectedBtnHandler` → `backItemToEquip`）；关窗清台面。
##   S. 服务端锤：`ITEM_CHANGE 23` 必须自查 非紫 / 未满 10 星 / 低于 60 级；
##      `ITEM_CHANGE 24` 必须自查 非橙；被拒都不扣料、不发帧（`测试/橙装打造服务端锤.py`）。
##
## ⚠️ 本门用假会话/假后端，**不碰 user://**，也不发真协议。
## 运行：Godot --headless --path . --script res://测试/橙装打造回归测试.gd

const 窗尺寸表 := "res://数据/界面/窗口尺寸.json"
const 打造表 := preload("res://脚本/界面/装备打造表.gd")
const 窗口管理脚本 := preload("res://脚本/界面/窗口管理.gd")

## 语言表原文（`en_US$message_properties.as:295/623/1947/1119/2542/2157`）。
const 打造标签文 := "橙色装备打造成功后，将随机获得一条传说属性"
const 精炼标签文 := "传说属性精炼成功后，将随机重置获得一条新的传说属性"

var 红数 := 0
var 受检 := 0
var _秒 := 0.0


class 假管理 extends Node:
	var 打开过: Array[String] = []
	var 窗: Node = null

	func 打开(页名: String) -> void:
		打开过.append(页名)
		if 窗 != null:
			窗.call("设为单页", 页名, Vector2.ZERO)

	func 取窗口(_页名: String) -> Node:
		return 窗

	func 打开或收起(_页名: String) -> void:
		pass


class 假来源 extends Node:
	var 槽位号 := 0


class 假会话 extends Node:
	var inventory: Array = []
	var player_stats: Dictionary = {"gold": 0}
	var 用过的格: Array[int] = []

	func _占用条(清单: Array, 格: int) -> Dictionary:
		if 格 < 1 or 格 > 清单.size():
			return {}
		return 清单[格 - 1] as Dictionary

	func 是福袋类(_格位: int) -> bool:
		return false

	func 是自选礼包(_格位: int) -> bool:
		return false

	func 是详情礼包(_格位: int) -> bool:
		return false

	func 是技能符(_格位: int) -> bool:
		return false

	func use_inventory_slot(格位: int, _全部 := false, _选择 := {}) -> bool:
		用过的格.append(格位)
		return true


class 假后端 extends Node:
	var 打造请求: Array = []
	var 精炼请求: Array = []

	func request_change_to_orange(格: int) -> bool:
		打造请求.append(格)
		return true

	func request_change_tale_attribute(格: int) -> bool:
		精炼请求.append(格)
		return true


func _initialize() -> void:
	call_deferred("_run")


func _记(ok: bool, 话: String) -> void:
	受检 += 1
	if not ok:
		红数 += 1
		print("!! " + 话)


func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 120.0:
		printerr("橙装打造回归测试：看门狗超时（120s）—— 中途崩了没走到收尾")
		quit(1)
	return false


func _跑服务端锤() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/橙装打造服务端锤.py"
	if not FileAccess.file_exists(锤):
		_记(false, "S：找不到锤脚本 " + 锤)
		return
	var 候选: Array[String] = [工程 + "/运行时/python/python.exe", "python"]
	var 解释器 := ""
	for 路 in 候选:
		if 路 == "python" or FileAccess.file_exists(路):
			解释器 = 路
			break
	if 解释器 == "":
		_记(false, "S：找不到 Python 解释器（试过 %s）" % str(候选))
		return
	var 输出: Array = []
	var 码 := OS.execute(解释器, ["-X", "utf8", 锤], 输出, true)
	for 行 in 输出:
		print("  | " + String(行))
	_记(码 == 0, "S：服务端锤退出 %d（打造 10 星/60 级/紫、精炼仅橙、被拒不扣料）" % 码)


## 一件测试装备。默认紫 10 星 60 级（01010041 镰鼬忍杖）。
func _造装备(格: int, 追加: Dictionary = {}) -> Dictionary:
	var 件 := {"id": "01010041", "name": "镰鼬忍杖", "quantity": 1, "slot_index": 格,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png",
			"aptitude": 4, "strength": 10, "strengthen": 10, "crash_time": 0,
			"req_level": 60, "tale_attr_type": -1, "tale_attr_value": 0}
	件.merge(追加, true)
	return 件


func _材料(格: int, 物品id: int, 数: int, 名: String) -> Dictionary:
	return {"id": str(物品id), "name": 名, "quantity": 数, "slot_index": 格}


func _拖(格: Control, 来源: Node, 物品id: String) -> void:
	var 载荷 := {"归属": "背包", "物品id": 物品id, "来源格": 来源}
	if 格.has_method("_can_drop_data") and bool(格.call("_can_drop_data", Vector2.ZERO, 载荷)):
		格.call("_drop_data", Vector2.ZERO, 载荷)


func _状态(场景: Node) -> String:
	var 标 := 场景.get("_status") as Label
	return 标.text if 标 != null else "<无状态行>"


func _找页(场景: Node) -> Control:
	return 场景.find_child("原版橙装打造内容", true, false) as Control


func _run() -> void:
	# —— A1：窗口尺寸表 ——
	var 尺寸: Variant = JSON.parse_string(FileAccess.get_file_as_string(窗尺寸表))
	var 条: Dictionary = {}
	if typeof(尺寸) == TYPE_DICTIONARY:
		条 = (尺寸 as Dictionary).get("橙装打造", {}) as Dictionary
	_记(not 条.is_empty(), "A1：窗口尺寸表该有「橙装打造」一条")
	if not 条.is_empty():
		_记(int(条.get("宽", 0)) == 376 and int(条.get("高", 0)) == 407,
				"A1：窗该是原版 376×407，实测 %s×%s" % [条.get("宽"), 条.get("高")])
		_记(条.get("内容底", true) == false, "A1：内容底该关（页面自己烘 MYellow）")
		var 原点: Array = 条.get("原点", []) as Array
		_记(原点.size() == 2 and int(原点[0]) == 0 and int(原点[1]) == 0,
				"A1：原点该是 [0,0]（铺满外框），实测 %s" % str(原点))
		_记(String(条.get("标题", "")) == "装备打造", "A1：标题该是「装备打造」（EQUIP_STRENGTH_WINDOW_TITLE）")

	# —— A2：成对开（伴随背包） ——
	var 常量: Dictionary = (窗口管理脚本 as GDScript).get_script_constant_map()
	var 伴随: Dictionary = 常量.get("伴随背包", {}) as Dictionary
	_记(伴随.has("橙装打造"), "A2：`窗口管理.伴随背包` 该收「橙装打造」（原版 centerTwoWindow 先摆对）")

	# —— 搭台：假管理 + 真窗 + 假会话/假后端 ——
	var 管理 := 假管理.new()
	root.add_child(管理)
	var 场景 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	管理.窗 = 场景
	管理.add_child(场景)
	for _i in 5:
		await process_frame
	var 会话 := 假会话.new()
	root.add_child(会话)
	var 后端 := 假后端.new()
	root.add_child(后端)
	场景.set("_session", 会话)
	场景.set("_backend", 后端)
	var 打造石 := _材料(1, 15029001, 80, "传说装备打造石")
	var 精炼石 := _材料(3, 15028001, 2, "传说精炼石")
	会话.inventory = [打造石, _造装备(2), 精炼石]

	# —— A3：双击打造石 = 只开窗（0 页） ——
	场景.call("_use_item", 1)
	for _i in 3:
		await process_frame
	_记(管理.打开过 == ["橙装打造"], "A3：双击传说装备打造石该只开窗，实测 %s" % str(管理.打开过))
	_记(会话.用过的格.is_empty(), "A3：打造石**不许发 USE_ITEM**（`ItemWindow2.as:979-983` 当场 return），实测 %s" % str(会话.用过的格))
	_记(int(场景.get("_橙装_页")) == 0, "A3：打造石该开第 0 页（橙装打造）")
	_记(打造表.橙装打造石id() == 15029001, "A3：`changeToOrange.needItemId` 该是 15029001，实测 %d" % 打造表.橙装打造石id())

	# —— A4：双击精炼石 = 只开窗（1 页） ——
	会话.inventory[0] = _材料(1, 15028001, 2, "传说精炼石")
	场景.call("_use_item", 1)
	for _i in 3:
		await process_frame
	_记(管理.打开过.size() == 2, "A4：第二次开窗也该走「橙装打造」，实测 %s" % str(管理.打开过))
	_记(int(场景.get("_橙装_页")) == 1, "A4：精炼石该开第 1 页（橙装精炼）")
	_记(会话.用过的格.is_empty(), "A4：精炼石**不许发 USE_ITEM**")
	_记(打造表.橙装精炼石id() == 15028001, "A4：`changeTaleAttribute.needItemId` 该是 15028001，实测 %d" % 打造表.橙装精炼石id())

	# —— A5：普通道具仍走 use_inventory_slot ——
	会话.inventory.append({"id": "11010001", "name": "测试道具", "quantity": 1, "slot_index": 4})
	场景.call("_use_item", 4)
	await process_frame
	_记(会话.用过的格 == [4], "A5：普通道具仍该进 use_inventory_slot，实测 %s" % str(会话.用过的格))

	# —— 回打造页 ——
	会话.inventory[0] = 打造石
	场景.call("_use_item", 1)
	for _i in 3:
		await process_frame
	var page := _找页(场景)
	_记(page != null, "B：橙装打造页没建出来")
	if page == null:
		quit(1)
		return

	# —— B：打造页空态 ——
	_记((page.get_node("分页/橙装打造") as Button).text == "橙装打造"
			and (page.get_node("分页/橙装精炼") as Button).text == "橙装精炼",
			"B：两枚页签文案该是「橙装打造 / 橙装精炼」（YELLOWEQUIP_TABBAR_NAMES）")
	_记((page.get_node("分页/橙装打造") as Button).disabled, "B：当前页签该是选中态（disabled 由 选页签 置上）")
	var 说明文 := (page.get_node("内容容器/说明") as RichTextLabel).text
	_记(说明文.contains("橙色装备打造提示："), "B：打造页说明第一句不对，实测「%s」" % 说明文)
	_记(说明文.contains("传说装备打造石"), "B：说明里的占位符该换成材料名「传说装备打造石」，实测「" + 说明文 + "」")
	_记(说明文.contains("[color=#ff9100]") and not 说明文.contains("<font"), "B：说明里的 HTML 要翻成 BBCode")
	var 注意文 := (page.get_node("内容容器/注意") as RichTextLabel).text
	_记(注意文.contains("只有60级以上的紫色满星装备可以用于打造橙装"), "B：打造页注意文不对，实测「%s」" % 注意文)
	_记((page.get_node("内容容器/标签") as Label).text == 打造标签文, "B：打造页标签该逐字")
	_记((page.get_node("内容容器/放入装备") as Button).text == "放入装备", "B：空态按钮该是「放入装备」")
	_记((page.get_node("内容容器/装备格/装备图标") as TextureRect).texture == null, "B：空态装备格不该有图标")
	_记((page.get_node("内容容器/材料框/材料一/材料名") as Label).text == "传说装备打造石",
			"B：材料名该是「传说装备打造石」")
	_记((page.get_node("内容容器/材料框/材料一/材料格/材料图标") as TextureRect).texture != null,
			"B：材料格该挂上打造石图标")
	_记((page.get_node("内容容器/材料框/材料一/材料格/材料数量") as Label).text.strip_edges().is_empty(),
			"B：没放装备时数量该空（原版 needItemCnt = \" \"）")
	_记((page.get_node("内容容器/材料框/材料一/材料格") as TextureRect).material != null,
			"B：没放装备时材料格该灰（backItemToEquip → applyGrayFilter）")
	_记(not (page.get_node("内容容器/材料框/材料一/购买") as Button).visible,
			"B：打造页该藏「购买」（updateView case 0 buyBtn.visible = false）")
	var 消耗文 := (page.get_node("内容容器/材料框/消耗文本") as RichTextLabel).text
	_记(消耗文.contains("本次操作消耗金币：0") and 消耗文.contains("本次操作成功几率：100%"),
			"B：消耗行该是 0 金币 / 100%，实测「" + 消耗文 + "」")
	_记(not 消耗文.contains("传说属性："), "B：打造页不该带传说属性行")
	_记((page.get_node("内容容器/开始打造") as Button).text == "开始打造", "B：按钮该是「开始打造」")

	# —— C：落料闸门 ——
	var 来源 := 假来源.new()
	来源.槽位号 = 2
	root.add_child(来源)
	var 设备格 := page.get_node("内容容器/装备格") as Control
	_记(设备格.has_method("_can_drop_data"), "C：装备格该挂上落点件（场景是生成物，运行期 set_script）")
	var 拒件 := [
		["15024001", "对不起，该物品不能被打造"],
		["01210441", "变身卡"],                 # 时装
		["01200040", "玉链"],
		["01410004", "该物品无法进行此操作。"],   # 徽章
	]
	for 项 in 拒件:
		会话.inventory[1] = {"id": String(项[0]), "name": "拒件", "quantity": 1, "slot_index": 2}
		_拖(设备格, 来源, String(项[0]))
		await process_frame
		_记(_状态(场景).contains(String(项[1])), "C：%s 该被拒并提示「%s」，实测「%s」" % [项[0], 项[1], _状态(场景)])
		_记(int(场景.get("_橙装_装备格")) == 0, "C：%s 被拒后不该收" % 项[0])

	会话.inventory[1] = _造装备(2, {"crash_time": 5})
	_拖(设备格, 来源, "01010041")
	await process_frame
	_记(_状态(场景).contains("对不起，该装备已经破损！"), "C：破损件该拒（10[0] 替 10[2]），实测「%s」" % _状态(场景))
	_记(int(场景.get("_橙装_装备格")) == 0, "C：破损件不该收")

	# 蓝件也收：原版落料不判资质（validateItem 只拦上述五种）
	会话.inventory[1] = _造装备(2, {"aptitude": 3})
	_拖(设备格, 来源, "01010041")
	for _i in 3:
		await process_frame
	page = _找页(场景)
	_记(int(场景.get("_橙装_装备格")) == 2, "C：蓝件该收下（validateItem 不判资质），实测 %d" % int(场景.get("_橙装_装备格")))
	_记((page.get_node("内容容器/放入装备") as Button).text == "取出装备", "C：收下后按钮该翻成「取出装备」")
	_记((page.get_node("内容容器/装备格/装备图标") as TextureRect).texture != null, "C：收下后装备格该有图标")
	_记((page.get_node("内容容器/材料框/材料一/材料格/材料数量") as Label).text == "80",
			"C：EquipA 打造需要 80 块（changeToOrange.EquipA.needItemCnt）")
	_记((page.get_node("内容容器/材料框/材料一/材料格") as TextureRect).material == null,
			"C：背包有 80 块时材料格**不该灰**（count >= needItemCnt）")

	# —— D：打造提交闸门 ——
	(page.get_node("内容容器/开始打造") as Button).pressed.emit()
	await process_frame
	_记(_状态(场景).contains("该装备不是紫装，不符合橙装打造要求，无法进行打造"),
			"D：蓝件该回 PINGJI_ERROR，实测「%s」" % _状态(场景))
	_记(后端.打造请求.is_empty(), "D：蓝件**不许发帧**")

	会话.inventory[1] = _造装备(2, {"strengthen": 9})
	场景.call("_render_page", true)
	await process_frame
	page = _找页(场景)
	_记(int(场景.get("_橙装_装备格")) == 2, "D：同一格 id 未变，台面该仍认这一件")
	(page.get_node("内容容器/开始打造") as Button).pressed.emit()
	await process_frame
	_记(_状态(场景).contains("该装备非满星状态，不符合橙装打造要求，无法进行打造"),
			"D：9 星该回 XING_ERROR，实测「%s」" % _状态(场景))
	_记(后端.打造请求.is_empty(), "D：9 星**不许发帧**")

	会话.inventory[1] = _造装备(2, {"strengthen": 10, "req_level": 1})
	场景.call("_render_page", true)
	await process_frame
	page = _找页(场景)
	(page.get_node("内容容器/开始打造") as Button).pressed.emit()
	await process_frame
	_记(_状态(场景).contains("该装备等级低于60级，不符合橙装打造要求，无法进行打造"),
			"D：1 级该回 LEVEL_ERROR，实测「%s」" % _状态(场景))
	_记(后端.打造请求.is_empty(), "D：1 级**不许发帧**")

	# 缺料：79 块（需要 80）
	会话.inventory[0] = _材料(1, 15029001, 79, "传说装备打造石")
	会话.inventory[1] = _造装备(2)
	场景.call("_render_page", true)
	await process_frame
	page = _找页(场景)
	_记((page.get_node("内容容器/材料框/材料一/材料格") as TextureRect).material != null,
			"D：只有 79 块时材料格该灰")
	(page.get_node("内容容器/开始打造") as Button).pressed.emit()
	await process_frame
	_记(_状态(场景).contains("很抱歉，你的传说装备打造石不够"), "D：缺料该回 2[0] 替 2[1]，实测「%s」" % _状态(场景))
	_记(后端.打造请求.is_empty(), "D：缺料**不许发帧**")

	# 正常：紫 10 星 60 级 + 80 块
	会话.inventory[0] = _材料(1, 15029001, 80, "传说装备打造石")
	场景.call("_render_page", true)
	await process_frame
	page = _找页(场景)
	(page.get_node("内容容器/开始打造") as Button).pressed.emit()
	await process_frame
	_记(后端.打造请求 == [2], "D：正常打造该发 request_change_to_orange(背包格 2)，实测 %s" % str(后端.打造请求))

	# 空台：取出后点开始
	(page.get_node("内容容器/放入装备") as Button).pressed.emit()
	for _i in 3:
		await process_frame
	page = _找页(场景)
	_记(int(场景.get("_橙装_装备格")) == 0, "D：点「取出装备」该清空台面")
	(page.get_node("内容容器/开始打造") as Button).pressed.emit()
	await process_frame
	_记(_状态(场景).contains("请放入装备！"), "D：空台点打造该回 6[0] 替 6[1]，实测「%s」" % _状态(场景))

	# —— E：精炼页 ——
	会_inv_set(会话, 2, _造装备(2, {"aptitude": 5, "tale_attr_type": 4, "tale_attr_value": 5}))
	_拖(_找页(场景).get_node("内容容器/装备格") as Control, 来源, "01010041")
	for _i in 3:
		await process_frame
	page = _找页(场景)
	_记(int(场景.get("_橙装_装备格")) == 2, "E：精炼页先确认台上有件")
	(page.get_node("分页/橙装精炼") as Button).pressed.emit()
	for _i in 3:
		await process_frame
	page = _找页(场景)
	_记(int(场景.get("_橙装_页")) == 1, "E：点精炼页签该切到第 1 页")
	_记(int(场景.get("_橙装_装备格")) == 0, "E：换页签该先清台面（selectedBtnHandler → backItemToEquip）")

	说明文 = (page.get_node("内容容器/说明") as RichTextLabel).text
	_记(说明文.contains("橙色装备精炼提示："), "E：精炼页说明第一句不对，实测「%s」" % 说明文)
	_记(说明文.contains("传说精炼石"), "E：精炼页说明里的材料名该是「传说精炼石」")
	注意文 = (page.get_node("内容容器/注意") as RichTextLabel).text
	_记(注意文.contains("只有橙色装备才可进行精炼操作"), "E：精炼页注意文不对，实测「%s」" % 注意文)
	_记((page.get_node("内容容器/标签") as Label).text == 精炼标签文, "E：精炼页标签该逐字")
	_记((page.get_node("内容容器/材料框/材料一/购买") as Button).visible, "E：精炼页该显示「购买」（case 1 buyBtn.visible = true）")
	_记((page.get_node("内容容器/材料框/材料一/材料格/材料数量") as Label).text == "1",
			"E：精炼材料数恒为 1（changeTaleAttribute.needItemCnt = 1）")
	_记((page.get_node("内容容器/开始打造") as Button).text == "开始精炼", "E：按钮该是「开始精炼」")

	# 精炼页落紫装（落料不判资质）⇒ 点精炼被 JINGLIAN 拒
	会_inv_set(会话, 2, _造装备(2, {"aptitude": 4}))
	_拖(page.get_node("内容容器/装备格") as Control, 来源, "01010041")
	for _i in 3:
		await process_frame
	page = _找页(场景)
	_记(int(场景.get("_橙装_装备格")) == 2, "E：精炼页紫装也收（落料不判资质）")
	_记(not (page.get_node("内容容器/材料框/消耗文本") as RichTextLabel).text.contains("传说属性："),
			"E：紫装时精炼页不该带传说属性行（aptitude != ORANGE）")
	(page.get_node("内容容器/开始打造") as Button).pressed.emit()
	await process_frame
	_记(_状态(场景).contains("该装备不符合橙装精炼要求，无法进行精炼"),
			"E：紫装点精炼该回 JINGLIAN_ERROR，实测「%s」" % _状态(场景))
	_记(后端.精炼请求.is_empty(), "E：紫装**不许发精炼帧**")

	# 橙装 ⇒ 消耗行带传说属性；提交发 request_change_tale_attribute
	会_inv_set(会话, 2, _造装备(2, {"aptitude": 5, "tale_attr_type": 4, "tale_attr_value": 5}))
	场景.call("_render_page", true)
	await process_frame
	page = _找页(场景)
	消耗文 = (page.get_node("内容容器/材料框/消耗文本") as RichTextLabel).text
	_记(消耗文.contains("传说属性：") and 消耗文.contains("攻击 +5"),
			"E：橙装精炼页消耗行该带「传说属性：攻击 +5」，实测「%s」" % 消耗文)
	(page.get_node("内容容器/开始打造") as Button).pressed.emit()
	await process_frame
	_记(后端.精炼请求 == [2], "E：正常精炼该发 request_change_tale_attribute(背包格 2)，实测 %s" % str(后端.精炼请求))

	# —— F：关窗清台面 ——
	_记(int(场景.get("_橙装_装备格")) == 2, "F：关窗前先确认台上有件")
	场景.call("close")
	await process_frame
	_记(int(场景.get("_橙装_装备格")) == 0 and String(场景.get("_橙装_装备id")).is_empty(),
			"F：关窗该清空台面（onremoveFromStage → backItemToEquip）")

	# —— S：服务端锤 ——
	_跑服务端锤()

	if 红数 == 0:
		print("橙装打造回归测试：通过（%d 条断言：入口不发帧/打造页空态/落料闸门/提交五闸/精炼页两态/换页与关窗清台/服务端锤）" % 受检)
		quit(0)
		return
	printerr("橙装打造回归测试：红 %d / %d" % [红数, 受检])
	quit(1)


## 改背包第 `格` 项（1 基）的内容。
func 会_inv_set(会话: Node, 格: int, 件: Dictionary) -> void:
	var 清单: Array = 会话.get("inventory") as Array
	if 格 < 1 or 格 > 清单.size():
		return
	清单[格 - 1] = 件
