extends SceneTree

## 「梦幻属性符」窗（原版 `MengHuanPropResetWindow`，360×432）回归门（2026-11-03）。
##
## 用户报修：「背包梦幻属性符，功能未实装，显示是材料或人物物品，不能直接使用」。
## 根因：`ItemWindow2.as:953-967` 的梦幻支**当场 return、不发 USE_ITEM**，本工程没有拦截，
## 于是掉进 `use_inventory_slot` ⇒ 在线发一条服务端不认的 USE_ITEM、离线回
## 「是材料或任务物品，不能直接使用」。本轮在 `功能窗口._use_item` 里照原版顺序截走并开窗。
##
## 盯的件（括号里是 AS3 出处）：
##   A. 入口：窗口尺寸 360×432 / 内容底关 / 原点 0,0；`窗口管理.伴随背包` 收它（成对开）；
##      `_use_item` 双击梦幻属性符 ⇒ 只开窗、**一格不发**；普通道具仍走 `use_inventory_slot`。
##   B. 空态版式：页签「附加属性梦幻数值重置」选中；三段文案（说明/标签/需要文）逐字；
##      放入装备=「放入装备」；材料格恒为梦幻属性符、角标 1、**没放装备时按 applyGrayFilter 变灰**。
##   C. 落装备：`validateItem:156-231` 六道闸门按原顺序 —— 非打造装备 / 时装 / 玉链 / 徽章 /
##      破损 / 非紫橙 各回原版那句、**都不收**；紫装收下后按钮翻「取出装备」、图标亮、材料格回不灰。
##   D. 属性行（`PropItem`/`drawPropView`）：左列 `属性名 +当前值`；未满绿「最大可提升至N」+勾、
##      已满橙「【梦幻满值】」+**无勾**；点勾 ⇒ 选中 + 底部预览换成满值。
##   E. 提交（`strengthHandler:337-383`）：没装备/破损/缺材料/非紫橙/没选或已满 各回原版那句、
##      **不发帧**；正常 ⇒ `requestFullPlusValue(装备格, 材料格, 序号)`，序号是 **1 基**。
##   F. 关窗：装备与选择清空（`onremoveFromStage → backItemToEquip`）。
##   S. 服务端锤：`ITEM_CHANGE 20` 的第三字段按 **1 基** 减一后取对应那条并抬到表里的
##      `plus.stage<阶>.<部位>.valueTo`；材料扣 1；越界/0 不动（见 `测试/梦幻属性符服务端锤.py`）。
##
## ⚠️ 本门用假会话/假后端，**不碰 user://**，也不发真协议。
## 运行：Godot --headless --path . --script res://测试/梦幻属性符回归测试.gd

const 窗尺寸表 := "res://数据/界面/窗口尺寸.json"
const 打造表 := preload("res://脚本/界面/装备打造表.gd")
const 窗口管理脚本 := preload("res://脚本/界面/窗口管理.gd")
const 说明 := "<font color='#00ff00'>梦幻属性符可以重置装备附加属性数值到满值\r</font><font color='#ffffff'>1：请放入一件紫色或橙色装备\r2：点选要重置的附加属性\r3：点开始重新开机按钮，100%重置成功</font>"
const 标签文 := "*您所选的属性，在重置后将100%变为【梦幻满值】"
const 需要文 := "本次操作成功几率：100%\r重置后的效果预览："

var 红数 := 0
var 受检 := 0
var _秒 := 0.0


## 窗口管理替身：`_开梦幻属性符窗` 只认「父节点有 打开/取窗口」这两项能力。
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


## 会话替身：只给页面要的那几样（`inventory` / `_占用条` / 四个 use 判定）。
class 假会话 extends Node:
	var inventory: Array = []
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
	var 重置请求: Array = []

	func request_full_plus_value(装备格: int, 材料格: int, 序号: int) -> bool:
		重置请求.append([装备格, 材料格, 序号])
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
		printerr("梦幻属性符回归测试：看门狗超时（120s）—— 中途崩了没走到收尾")
		quit(1)
	return false


func _跑服务端锤() -> void:
	var 工程 := ProjectSettings.globalize_path("res://")
	var 锤 := 工程 + "/测试/梦幻属性符服务端锤.py"
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
	_记(码 == 0, "S：服务端锤退出 %d（1 基序号/抬到上限/扣料/越界不动）" % 码)


func _造装备(格: int, 追加: Dictionary = {}) -> Dictionary:
	var 件 := {"id": "01010011", "name": "测试武器", "quantity": 1, "slot_index": 格,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png",
			"aptitude": 4, "crash_time": 0,
			"plus_attributes": [
				{"attribute_type": 4, "attribute_value": 3},
				{"attribute_type": 6, "attribute_value": 9},
			]}
	件.merge(追加, true)
	return 件


func _符(格: int) -> Dictionary:
	return {"id": "15024001", "name": "梦幻属性符", "quantity": 2, "slot_index": 格,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"}


func _行(page: Control, 序: int) -> Control:
	return (page.get_node("内容容器/属性列表") as Control).get_child(序) as Control


func _行文(行: Control) -> Array[String]:
	var 出: Array[String] = []
	for 子 in 行.get_children():
		if 子 is Label:
			出.append((子 as Label).text)
	return 出


func _行勾数(行: Control) -> int:
	var 数 := 0
	for 子 in 行.get_children():
		if 子 is CheckBox:
			数 += 1
	return 数


func _拖(格: Control, 来源: Node, 物品id: String) -> void:
	var 载荷 := {"归属": "背包", "物品id": 物品id, "来源格": 来源}
	if 格.has_method("_can_drop_data") and bool(格.call("_can_drop_data", Vector2.ZERO, 载荷)):
		格.call("_drop_data", Vector2.ZERO, 载荷)


func _状态(场景: Node) -> String:
	var 标 := 场景.get("_status") as Label
	return 标.text if 标 != null else "<无状态行>"


func _run() -> void:
	# —— A1：窗口尺寸表 ——
	var 尺寸: Variant = JSON.parse_string(FileAccess.get_file_as_string(窗尺寸表))
	var 条: Dictionary = {}
	if typeof(尺寸) == TYPE_DICTIONARY:
		条 = (尺寸 as Dictionary).get("梦幻属性符", {}) as Dictionary
	_记(not 条.is_empty(), "A1：窗口尺寸表该有「梦幻属性符」一条")
	if not 条.is_empty():
		_记(int(条.get("宽", 0)) == 360 and int(条.get("高", 0)) == 432,
				"A1：窗该是原版 360×432，实测 %s×%s" % [条.get("宽"), 条.get("高")])
		_记(条.get("内容底", true) == false, "A1：内容底该关（页面自己烘 MYellow）")
		var 原点: Array = 条.get("原点", []) as Array
		_记(原点.size() == 2 and int(原点[0]) == 0 and int(原点[1]) == 0,
				"A1：原点该是 [0,0]（铺满外框），实测 %s" % str(原点))

	# —— A2：成对开（伴随背包） ——
	var 常量: Dictionary = (窗口管理脚本 as GDScript).get_script_constant_map()
	var 伴随: Dictionary = 常量.get("伴随背包", {}) as Dictionary
	_记(伴随.has("梦幻属性符"),
			"A2：`窗口管理.伴随背包` 该收「梦幻属性符」（原版 centerTwoWindow 先摆对）")

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
	会话.inventory = [_符(1), _造装备(2)]

	# —— A3：双击梦幻属性符 = 只开窗、一格不发 ——
	场景.call("_use_item", 1)
	for _i in 3:
		await process_frame
	_记(管理.打开过 == ["梦幻属性符"], "A3：双击梦幻属性符该只开窗，实测 %s" % str(管理.打开过))
	_记(会话.用过的格.is_empty(), "A3：梦幻属性符**不许发 USE_ITEM**（`ItemWindow2.as:953-967` 当场 return），实测 %s" % str(会话.用过的格))
	_记(int(场景.get("_梦幻_材料格")) == 1, "A3：材料格该记下点的那一格（1 基），实测 %d" % int(场景.get("_梦幻_材料格")))
	_记(String(场景.get("_梦幻_材料id")) == "15024001", "A3：材料 id 该记成梦幻属性符，实测「%s」" % String(场景.get("_梦幻_材料id")))
	_记(打造表.梦幻属性符id() == 15024001, "A3：`plus.fullone.needItemId` 该是 15024001，实测 %d" % 打造表.梦幻属性符id())

	# —— A4：普通道具仍走 use_inventory_slot ——
	会话.inventory.append({"id": "11010001", "name": "测试道具", "quantity": 1, "slot_index": 3})
	场景.call("_use_item", 3)
	await process_frame
	_记(会话.用过的格 == [3], "A4：普通道具仍该进 use_inventory_slot，实测 %s" % str(会话.用过的格))

	# —— B：空态版式 ——
	var page := 场景.find_child("原版梦幻属性符内容", true, false) as Control
	_记(page != null, "B：梦幻属性符页没建出来")
	if page == null:
		quit(1)
		return
	var 页签 := page.get_node("分页/附加属性梦幻数值重置") as Button
	_记(页签.text == "附加属性梦幻数值重置", "B：页签文案该是「附加属性梦幻数值重置」，实测「%s」" % 页签.text)
	_记(页签.disabled and 页签.button_pressed, "B：唯一那枚页签该是选中态（selectedBtnHandler case 0 恒选中）")
	var 说明文 := (page.get_node("内容容器/说明") as RichTextLabel).text
	_记(说明文.contains("梦幻属性符可以重置装备附加属性数值到满值"), "B：说明第一句不对，实测「%s」" % 说明文)
	_记(说明文.contains("[color=#00ff00]") and not 说明文.contains("<font"), "B：说明里的 HTML 要翻成 BBCode（不许原样漏 <font>）")
	_记((page.get_node("内容容器/标签") as Label).text == 标签文, "B：标签文该逐字（AS3 MENGHUANPROPRESETWINDOW_LABEL）")
	var 需要 := (page.get_node("内容容器/材料框/需要文") as RichTextLabel).text
	_记(需要.contains("本次操作成功几率：100%") and 需要.contains("重置后的效果预览："), "B：需要文不对，实测「%s」" % 需要)
	_记((page.get_node("内容容器/放入装备") as Button).text == "放入装备", "B：空态按钮该是「放入装备」")
	_记((page.get_node("内容容器/装备格/装备图标") as TextureRect).texture == null, "B：空态装备格不该有图标")
	_记((page.get_node("内容容器/材料框/材料一/材料名") as Label).text == "梦幻属性符", "B：材料名该是「梦幻属性符」")
	_记((page.get_node("内容容器/材料框/材料一/材料格/材料图标") as TextureRect).texture != null, "B：材料格该挂上梦幻属性符图标")
	_记((page.get_node("内容容器/材料框/材料一/材料格/材料数量") as Label).text == "1",
			"B：材料角标该恒为 1（showPropPanle 的 itemCell.label = \"1\"）")
	_记((page.get_node("内容容器/材料框/材料一/材料格") as TextureRect).material != null,
			"B：没放装备时材料格该灰（updateView → applyGrayFilter）")
	_记((page.get_node("内容容器/属性列表") as Control).get_child_count() == 0, "B：空态不该画属性行")
	_记(not (page.get_node("内容容器/材料框/预览属性") as Control).visible, "B：空态不该亮预览")

	# —— C：六道闸门（每条都**不收**、回原版那句） ——
	var 来源 := 假来源.new()
	来源.槽位号 = 2
	root.add_child(来源)
	var 设备格 := page.get_node("内容容器/装备格") as Control
	_记(设备格.has_method("_can_drop_data"), "C：装备格该挂上落点件（场景是生成物，只能运行期 set_script）")

	var 拒件 := [
		["15024001", "对不起，该物品不能被打造"],
		["01210441", "变身卡"],       # 时装
		["01200040", "玉链"],
		["01410004", "该物品无法进行此操作。"],  # 徽章
	]
	for 项 in 拒件:
		会话.inventory[1] = {"id": String(项[0]), "name": "拒件", "quantity": 1, "slot_index": 2}
		_拖(设备格, 来源, String(项[0]))
		await process_frame
		_记(_状态(场景).contains(String(项[1])), "C：%s 该被拒并提示「%s」，实测「%s」" % [项[0], 项[1], _状态(场景)])
		_记(int(场景.get("_梦幻_装备格")) == 0, "C：%s 被拒后不该收（_梦幻_装备格 仍为 0）" % 项[0])

	会话.inventory[1] = _造装备(2, {"crash_time": 5})
	_拖(设备格, 来源, "01010011")
	await process_frame
	_记(_状态(场景).contains("对不起，该装备已经破损！"), "C：破损件该拒（10[0] 替 10[2]），实测「%s」" % _状态(场景))
	_记(int(场景.get("_梦幻_装备格")) == 0, "C：破损件不该收")

	会话.inventory[1] = _造装备(2, {"aptitude": 3})
	_拖(设备格, 来源, "01010011")
	await process_frame
	_记(_状态(场景).contains("该装备不符合要求，请放入紫色或橙色品质装备"), "C：蓝色件该拒（FANG_RU_ZI_ZHAUNG），实测「%s」" % _状态(场景))
	_记(int(场景.get("_梦幻_装备格")) == 0, "C：蓝色件不该收")

	# —— C/D：紫装收下 ——
	会话.inventory[1] = _造装备(2)
	_拖(设备格, 来源, "01010011")
	for _i in 3:
		await process_frame
	page = 场景.find_child("原版梦幻属性符内容", true, false) as Control
	_记(int(场景.get("_梦幻_装备格")) == 2, "C：紫装该收在背包格 2，实测 %d" % int(场景.get("_梦幻_装备格")))
	_记((page.get_node("内容容器/放入装备") as Button).text == "取出装备", "C：收下后按钮该翻成「取出装备」")
	_记((page.get_node("内容容器/装备格/装备图标") as TextureRect).texture != null, "C：收下后装备格该有图标")
	_记((page.get_node("内容容器/材料框/材料一/材料格") as TextureRect).material == null,
			"C：有装备且背包有符时材料格**不该灰**（ItemCaiLiaoBox.hasItem）")

	var 区 := page.get_node("内容容器/属性列表") as Control
	_记(区.get_child_count() == 2, "D：两条附加属性该画两行，实测 %d" % 区.get_child_count())
	if 区.get_child_count() == 2:
		var 行0 := _行(page, 0)
		var 行1 := _行(page, 1)
		var 文0 := _行文(行0)
		var 文1 := _行文(行1)
		_记(文0.size() == 2 and 文0[0] == "攻击 +3", "D：第一行左列该是「攻击 +3」，实测 %s" % str(文0))
		_记(文0.size() == 2 and 文0[1] == "最大可提升至7", "D：第一行右列该是「最大可提升至7」（stage1/EquipA 的 atk.valueTo），实测 %s" % str(文0))
		_记(_行勾数(行0) == 1, "D：未满行该有勾选框")
		_记(文1.size() == 2 and 文1[0] == "暴击 +9", "D：第二行左列该是「暴击 +9」，实测 %s" % str(文1))
		_记(文1.size() == 2 and 文1[1] == "【梦幻满值】", "D：已满行右列该是「【梦幻满值】」，实测 %s" % str(文1))
		_记(_行勾数(行1) == 0, "D：已满行**不该有勾**（PropItem.updateView 隐藏 checkBox）")

		# 点勾 ⇒ 选中 + 预览
		var 勾 := 行0.get_child(2) as CheckBox
		勾.toggled.emit(true)
		for _i in 3:
			await process_frame
		page = 场景.find_child("原版梦幻属性符内容", true, false) as Control
		_记(int(场景.get("_梦幻_选中")) == 1, "D：点勾后选中序号该是 1（1 基），实测 %d" % int(场景.get("_梦幻_选中")))
		_记((page.get_node("内容容器/材料框/预览属性") as Control).visible, "D：选中一条后预览该亮")
		_记((page.get_node("内容容器/材料框/预览属性/属性值") as Label).text == "攻击 +7",
				"D：预览左列该是「攻击 +7」（满值）")
		_记((page.get_node("内容容器/材料框/预览属性/结果") as Label).text == "【梦幻满值】", "D：预览右列该是「【梦幻满值】」")
		var 勾0 := _行(page, 0).get_child(2) as CheckBox
		_记(勾0.button_pressed, "D：重画后选中那行的勾该是按下态")

	# —— E：提交 ——
	var 执行 := page.get_node("内容容器/开始重置") as Button
	执行.pressed.emit()
	await process_frame
	_记(后端.重置请求 == [[2, 1, 1]], "E：正常提交该发 (装备格2, 材料格1, 序号1)；序号必须 1 基，实测 %s" % str(后端.重置请求))

	# 缺材料
	会话.inventory[0] = {}
	执行.pressed.emit()
	await process_frame
	_记(_状态(场景).contains("很抱歉，你的梦幻属性符不够"), "E：缺符该回原版那句，实测「%s」" % _状态(场景))
	_记(后端.重置请求.size() == 1, "E：缺符**不许发帧**")
	会话.inventory[0] = _符(1)

	# 没选
	场景.set("_梦幻_选中", 0)
	执行.pressed.emit()
	await process_frame
	_记(_状态(场景).contains("请先选择一条附加属性"), "E：没选该回 NO_SELECTED，实测「%s」" % _状态(场景))
	_记(后端.重置请求.size() == 1, "E：没选**不许发帧**")

	# 选了已满那条
	场景.set("_梦幻_选中", 2)
	执行.pressed.emit()
	await process_frame
	_记(_状态(场景).contains("请先选择一条附加属性"), "E：选中已满那条也该按 NO_SELECTED 拒（isFull），实测「%s」" % _状态(场景))
	_记(后端.重置请求.size() == 1, "E：已满行**不许发帧**")

	# 取出后再点
	场景.set("_梦幻_选中", 0)
	(page.get_node("内容容器/放入装备") as Button).pressed.emit()
	for _i in 3:
		await process_frame
	page = 场景.find_child("原版梦幻属性符内容", true, false) as Control
	_记(int(场景.get("_梦幻_装备格")) == 0, "E：点「取出装备」该清空台面（backItemToEquip）")
	_记((page.get_node("内容容器/放入装备") as Button).text == "放入装备", "E：取出后按钮翻回「放入装备」")
	(page.get_node("内容容器/开始重置") as Button).pressed.emit()
	await process_frame
	_记(_状态(场景).contains("请放入装备！"), "E：空台点重置该回 6[0] 替 6[1]，实测「%s」" % _状态(场景))
	_记(后端.重置请求.size() == 1, "E：空台**不许发帧**")

	# —— F：关窗清台面 ——
	会话.inventory[1] = _造装备(2)
	_拖(page.get_node("内容容器/装备格") as Control, 来源, "01010011")
	for _i in 3:
		await process_frame
	_记(int(场景.get("_梦幻_装备格")) == 2, "F：关窗前先确认台上有件")
	场景.call("close")
	await process_frame
	_记(int(场景.get("_梦幻_装备格")) == 0 and int(场景.get("_梦幻_选中")) == 0,
			"F：关窗该清空装备与选择（onremoveFromStage → backItemToEquip）")

	# —— S：服务端锤 ——
	_跑服务端锤()

	if 红数 == 0:
		print("梦幻属性符回归测试：通过（%d 条断言：入口不发帧/空态版式/六道闸门/属性行两态/点勾预览/提交通道 1 基/关窗清台/服务端锤）" % 受检)
		quit(0)
		return
	printerr("梦幻属性符回归测试：红 %d / %d" % [红数, 受检])
	quit(1)
