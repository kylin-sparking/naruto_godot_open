extends SceneTree
## 十拳剑（开光 20200001）「改变外观」的离线回归门。
##
## 分工（和 `十拳剑改变外观在线回归测试.gd`）：
##   · 本门：菜单第三档的出现条件、`LingQiFaceSelectWindow.as` 的版式/灰行/色块公式、
##           “确定只发不同项”、关窗还原、199 的颜色字段、人物身上那层须佐能乎的颜色与特效。
##   · 在线门：服务端 2081:4/5/6 真回帧、真落盘、真广播 199。
##
## 真值出处：
##   · 菜单条件 `EquipPane.as:258-264`（灵器格 + id == 20200001）；
##   · 窗口 `LingQiFaceSelectWindow.as`（WIN_WIDTH 760 / ITEM_HEIGHT 28 / PADDING 12 /
##     COLUMN_GAP 20 / 列宽 floor(696/3)=232 / 预览 250 / 颜色行宽 floor(224/2)=112 /
##     内容高 520 ⇒ 底高 596 / 确定 (365,562) / 预览身体 (92,226)）；
##   · 颜色块公式 `resolveColorPreview:982-1004`：clamp(int(mul*90+offset),0,255)；
##   · 199 第 13 位颜色是本服文本扩展，老 12 段帧不许动颜色。

const 人物窗口脚本 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 窗口脚本 := preload("res://脚本/界面/窗口/灵器外观选择窗.gd")
const 外观数据 := preload("res://脚本/单例/灵器外观数据.gd")
const 灵器外观脚本 := preload("res://脚本/角色/灵器外观.gd")
const 装备部位 := preload("res://脚本/单例/装备部位.gd")
const 门名 := "十拳剑改变外观回归测试"

const 神威脸 := 10000038
const 十拳脸 := 10000067
const 完全体脸 := 10000074
const 双刃脸 := 10000075

## 与 `灵器外观数据.gd` / 服务端同一份四行脸表。
var 脸表 := [
	{"id": 神威脸, "required_stage": 6, "unlocked": true, "name": "须佐之男·炎"},
	{"id": 十拳脸, "required_stage": 6, "unlocked": true, "name": "须佐之男·十拳剑"},
	{"id": 完全体脸, "required_stage": 7, "unlocked": false, "name": "须佐之男·完全体"},
	{"id": 双刃脸, "required_stage": 8, "unlocked": false, "name": "须佐之男·双刃"},
]

var _失败: Array[String] = []
var _判数 := 0


class 假后端 extends Node:
	signal ling_qi_face_list_received(faces: Array, colors: Array)
	signal ling_qi_appearance_result(action: int, success: bool, value: int)

	var authoritative_stats: Dictionary = {"lingFace": 0, "lingQiColor": 0}
	var 列表请求数 := 0
	var 脸请求: Array = []
	var 色请求: Array = []

	func request_ling_qi_face_list() -> bool:
		列表请求数 += 1
		return true

	func request_ling_qi_change_face(face_id: int) -> bool:
		脸请求.append(face_id)
		return true

	func request_ling_qi_change_color(color_id: int) -> bool:
		色请求.append(color_id)
		return true


func _记(成立: bool, 说明: String) -> void:
	_判数 += 1
	if not 成立:
		_失败.append(说明)


func _色表() -> Array:
	var 表: Array = []
	for 行 in 外观数据.颜色表:
		var 值: Array = 行 as Array
		表.append({
			"id": int(值[0]), "name": "原色" if int(值[0]) == 0 else "颜色%d" % int(值[0]),
			"red_mul": float(值[1]), "green_mul": float(值[2]), "blue_mul": float(值[3]),
			"alpha_mul": float(值[4]),
			"red_offset": int(值[5]), "green_offset": int(值[6]),
			"blue_offset": int(值[7]), "alpha_offset": int(值[8]),
		})
	return 表


func _清效果() -> void:
	外观数据.呼吸明暗 = false
	外观数据.外发辉光 = false
	外观数据.斜向流光 = false
	外观数据.边缘星闪 = false
	外观数据.雾化底辉 = false


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_清效果()
	_测菜单()
	_测协议解析()
	_测扩包容量()
	_测灵器帧同步()
	await _测窗口()
	await _测人物叠加层()
	_清效果()
	for 条 in _失败:
		printerr("  红 - " + 条)
	print("汇：判 %d 条 / 红 %d 条（%s：%s）" % [_判数, _失败.size(), 门名, "通过" if _失败.is_empty() else "失败"])
	quit(0 if _失败.is_empty() else 1)


# ── ① 装备格菜单：第三档只属于灵器格里的 20200001 ──────────────────────────────
func _测菜单() -> void:
	var 灵器 := 人物窗口脚本.装备菜单项(装备部位.灵器, {"id": "20200001", "name": "开光十拳剑"})
	_记(灵器.size() == 3 and String(灵器[2]) == 人物窗口脚本.改变外观,
			"① 灵器格 + 20200001 ⇒ 三项，第三项是「改变外观」；实得 %s" % [灵器])
	_记(String(灵器[0]) == 人物窗口脚本.卸下 and String(灵器[1]) == 人物窗口脚本.物品菜单组件.发到聊天框,
			"① 前两项仍是「卸下」「发到聊天框」，顺序照 `EquipPane.as:250-264`；实得 %s" % [灵器])

	var 未开光 := 人物窗口脚本.装备菜单项(装备部位.灵器, {"id": "20100001"})
	_记(未开光.size() == 2, "① 灵器格里的未开光十拳剑 20100001 不许出第三项；实得 %s" % [未开光])

	var 别格 := 人物窗口脚本.装备菜单项(装备部位.武器, {"id": "20200001"})
	_记(别格.size() == 2, "① 20200001 挂在别的格（武器 -1）也不许出第三项；实得 %s" % [别格])

	var 数字号 := 人物窗口脚本.装备菜单项(装备部位.灵器, {"id": 20200001})
	_记(数字号.size() == 3, "① 物品 id 是整数不是字符串时也要认（背包字典两种都有）；实得 %s" % [数字号])


# ── ⑤ 背包扩到 180 格、前 96 格全满时，卸下/放件仍要能找到第 97 格 ────────────────
## 真值：原版 `EquipPane.unequip:311-327` 的 `getBagEmptyPositionById` 是按**真实背包格数**
## 找空格。我们这里曾吃 `_首空格` 的 96 默认值 ⇒ 玩档（180 格、前 96 格全满）卸十拳剑
## 时客户端自己先判"背包已满"、报文都不发（2026-10-25 用户报"十拳剑不能卸下"）。
##
## ⚠ 本段只测两个纯函数，**不调 `unequip_item`**：离线那条分支最后会 `_save_local_state()`，
##   不能把玩家的 `user://` 存档当测试场地（规矩见交接文档）。
func _测扩包容量() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 == null:
		_记(false, "⑤ 缺 GameSession 单例")
		return
	var 后端 := root.get_node_or_null("BackendConnection")
	var 旧容量 := int(后端.get("authoritative_bag_capacity")) if 后端 != null else 0
	if 后端 != null:
		后端.set("authoritative_bag_capacity", 0)
	var 旧格数 := int(会话.player_stats.get("common_slots", 0))
	var 旧背包: Array = (会话.inventory as Array).duplicate(true)
	会话.player_stats["common_slots"] = 180

	var 满: Array[Dictionary] = []
	for 格 in range(1, 97):
		满.append({"id": "3000001", "name": "测试", "quantity": 1, "slot_index": 格})
	会话.inventory.assign(满)
	_记(int(会话.call("背包总格数")) == 180,
			"⑤ 背包总格数该读到 180；实得 %s" % 会话.call("背包总格数"))
	var 首空 := int(会话.call("_first_free_inventory_slot"))
	_记(首空 == 97,
			"⑤ 前 96 格全满、总格 180 时首空格该是 97（不许误报满）；实得 %d" % 首空)
	var 剑 := {"id": "20200001", "name": "开光十拳剑", "quantity": 1}
	var 落格 := int(会话.call("_放进空格", 会话.inventory, 剑, 180))
	_记(落格 == 97, "⑤ 放进空格按真实上限该落 97；实得 %d" % 落格)

	会话.inventory.assign(旧背包)
	会话.player_stats["common_slots"] = 旧格数
	if 后端 != null:
		后端.set("authoritative_bag_capacity", 旧容量)


# ── ⑥ 灵器专属帧（flag 12）卸下后，warp 缓存里那份 -23 不许再并回来 ─────────────
## 真值：原版 `InventoryProcessor.as:201-215` + `ItemManager.moveItem_LingQi:246-304`
## （`exchangeSlots`：src→dst，dst 原有的换回 src）。服务端 `_send_special_equipment_move`
## 发的文本帧段序是 `flag : 物品体 : slotSrc : inventoryType : slotDst`。
##
## 曾经的 bug 不是"没收到帧"——`_handle_inventory_change` 有 12 分支、也搬了件；
## 但 `_apply_inventory_to_session()` 每次都会 `_merge_special_equipment()` 把
## `authoritative_special_equipment`（来自 warp 第 39 截）**重新并回装备表**。
## 于是擦掉 -23 后立刻又被并回来：服务端和背包都知道剑卸下了，人物窗灵器格却还挂着
## （2026-10-25 用户报「十拳剑不能卸下」的第二层）。缓存必须跟着这次搬运一起改。
##
## ⚠ 纯内存模拟：快照后还原后端表的四份状态，不写任何存档。
func _测灵器帧同步() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	var 后端 := root.get_node_or_null("BackendConnection")
	if 会话 == null or 后端 == null:
		_记(false, "⑥ 缺 GameSession/BackendConnection 单例")
		return
	var 旧货: Array = (后端.get("authoritative_inventory") as Array).duplicate(true)
	var 旧装: Dictionary = (后端.get("authoritative_equipment") as Dictionary).duplicate(true)
	var 旧特: Dictionary = (后端.get("authoritative_special_equipment") as Dictionary).duplicate(true)
	var 旧背包: Array = (会话.inventory as Array).duplicate(true)
	var 旧穿: Dictionary = (会话.equipped_items as Dictionary).duplicate(true)
	var 旧权威 := bool(会话.backend_authoritative)

	var 剑 := {"id": "20200001", "name": "十拳剑(已开光)", "type": 6, "slot_index": -23,
		"equip_position": -23, "slot": "灵器", "quantity": 1, "unique_id": 12345}
	(后端.get("authoritative_inventory") as Array).assign([
		{"id": "3000001", "name": "占位", "slot_index": 1, "quantity": 1}])
	后端.set("authoritative_equipment", {-23: 剑.duplicate(true)})
	后端.set("authoritative_special_equipment", {-23: 剑.duplicate(true)})
	会话.equipped_items.clear()
	会话.equipped_items[-23] = 剑.duplicate(true)
	会话.inventory.assign([{"id": "3000001", "name": "占位", "slot_index": 1, "quantity": 1}])

	# 物品体 10 段：type&id&slot&quantity&price&…&canTrade&owner&…&uniqueId
	var 体 := "6&20200001&115&1&0&0&1&测试&0&12345"
	后端.call("_handle_inventory_change",
		PackedStringArray(["32", "12", 体, "-23", "3", "115"]))

	_记(not (后端.get("authoritative_equipment") as Dictionary).has(-23),
			"⑥ flag 12 卸下后装备表 -23 该空；实得 %s" %
			[(后端.get("authoritative_equipment") as Dictionary).get(-23)])
	_记(not (后端.get("authoritative_special_equipment") as Dictionary).has(-23),
			"⑥ warp 特殊装备缓存里 -23 也要清掉（否则 2051 后又并回来）；实得 %s" %
			[(后端.get("authoritative_special_equipment") as Dictionary).get(-23)])
	_记(not (会话.equipped_items as Dictionary).has(-23),
			"⑥ 会话灵器槽 -23 该空；实得 %s" % [(会话.equipped_items as Dictionary).get(-23)])
	var 落格 := -1
	for 条 in 会话.inventory:
		if 条 is Dictionary and str((条 as Dictionary).get("id", "")) == "20200001":
			落格 = int((条 as Dictionary).get("slot_index", -1))
			break
	_记(落格 == 115, "⑥ 剑该落在帧里给的背包格 115；实得 %d" % 落格)

	(后端.get("authoritative_inventory") as Array).assign(旧货)
	后端.set("authoritative_equipment", 旧装)
	后端.set("authoritative_special_equipment", 旧特)
	会话.inventory.assign(旧背包)
	会话.equipped_items.clear()
	for 位 in 旧穿:
		会话.equipped_items[位] = 旧穿[位]
	会话.backend_authoritative = 旧权威


# ── ② 协议文本帧：4 回帧、5/6 结果、199 第 13 位颜色 ───────────────────────────
func _脸行串() -> String:
	var 行们: Array[String] = []
	for 行 in 脸表:
		行们.append("%d&%d&%d&%s" % [
			int(行.id), int(行.required_stage), 1 if bool(行.unlocked) else 0, String(行.name)])
	return "@".join(行们)


func _色行串() -> String:
	var 行们: Array[String] = []
	for 行 in _色表():
		行们.append("%d&%s&%s&%s&%s&%s&%d&%d&%d&%d" % [
			int(行.id), String(行.name), str(行.red_mul), str(行.green_mul),
			str(行.blue_mul), str(行.alpha_mul), int(行.red_offset), int(行.green_offset),
			int(行.blue_offset), int(行.alpha_offset)])
	return "@".join(行们)


func _测协议解析() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	_记(后端 != null, "② 缺 BackendConnection 单例")
	if 后端 == null:
		return

	var 收脸: Array = []
	var 收色: Array = []
	var 收表 := func(脸: Array, 色: Array) -> void:
		收脸.assign(脸)
		收色.assign(色)
	后端.ling_qi_face_list_received.connect(收表, CONNECT_ONE_SHOT)
	后端.call("_handle_ling_qi_appearance_text", PackedStringArray([
		"2081", "4", "4", _脸行串(), "33", _色行串()]))
	_记(收脸.size() == 4, "② 2081:4 该解出四张脸；实得 %d" % 收脸.size())
	_记(收色.size() == 33, "② 2081:4 该解出 33 个颜色；实得 %d" % 收色.size())
	if 收脸.size() == 4:
		_记(int(收脸[0].id) == 神威脸 and int(收脸[0].required_stage) == 6 and bool(收脸[0].unlocked)
				and String(收脸[0].name) == "须佐之男·炎",
				"② 第 0 行该是 10000038/6/解锁/须佐之男·炎；实得 %s" % [收脸[0]])
		_记(int(收脸[3].id) == 双刃脸 and int(收脸[3].required_stage) == 8,
				"② 第 3 行该是 10000075/8；实得 %s" % [收脸[3]])
		## 解锁位必须逐行照抄：第一版只判了第 0 行 true，解析器把全表写死 true 也照样绿
		## （反向对照当场发现）⇒ 7/8 阶这两行必须明确为 false。
		_记(bool(收脸[1].unlocked) and not bool(收脸[2].unlocked) and not bool(收脸[3].unlocked),
				"② 解锁位该是 [真,真,假,假]；实得 %s" % [[收脸[0].unlocked, 收脸[1].unlocked, 收脸[2].unlocked, 收脸[3].unlocked]])
	if 收色.size() == 33:
		var 一: Dictionary = 收色[1]
		_记(int(一.id) == 1 and is_equal_approx(float(一.red_mul), 1.18)
				and int(一.red_offset) == 42 and int(一.alpha_offset) == 0,
				"② 颜色 1 的乘/加值要逐值透传（1.18 / +42 / alpha 0）；实得 %s" % [一])

	## 5/6 结果帧：成功才写权威镜像。
	var 结果: Array = []
	var 结果钩 := func(动作: int, 成功: bool, 值: int) -> void:
		结果.append([动作, 成功, 值])
	后端.ling_qi_appearance_result.connect(结果钩)
	后端.set("authoritative_stats", {"lingFace": 0, "lingQiColor": 0})
	后端.call("_handle_ling_qi_appearance_text", PackedStringArray(["2081", "5", "1", "10000038"]))
	var 权: Dictionary = 后端.get("authoritative_stats")
	_记(结果.size() == 1 and int(结果[0][0]) == 5 and bool(结果[0][1]) and int(结果[0][2]) == 10000038,
			"② 2081:5:1:10000038 该发 result(5,true,10000038)；实得 %s" % [结果])
	_记(int(权.get("lingFace", -1)) == 10000038, "② 改脸成功后权威镜像 lingFace 要更新；实得 %s" % 权.get("lingFace"))
	后端.call("_handle_ling_qi_appearance_text", PackedStringArray(["2081", "6", "0", "99"]))
	_记(结果.size() == 2 and not bool(结果[1][1]) and int(权.get("lingQiColor", -1)) == 0,
			"② 2081:6 失败不许写 lingQiColor（失败也回原值）；实得 %s / %s" % [结果, 权])
	后端.call("_handle_ling_qi_appearance_text", PackedStringArray(["2081", "5", "0", "10000075"]))
	_记(int(权.get("lingFace", -1)) == 10000038, "② 5 的失败腿不许把脸写成 10000075；实得 %s" % 权.get("lingFace"))
	后端.ling_qi_appearance_result.disconnect(结果钩)

	## 199：第 13 位颜色只在本服扩展帧里出现；老 12 段帧不动颜色。
	var 后端角色号 := int(后端.get("character_id"))
	后端.set("character_id", 4242)
	后端.set("authoritative_stats", {"face": 1, "gender": 0, "skinColor": 0, "lingFace": 0, "lingQiColor": 7})
	var 颜色帧: Array = []
	var 颜色钩 := func(角色号: int, 色: int) -> void:
		颜色帧.append([角色号, 色])
	后端.ling_color_changed.connect(颜色钩)
	var 基 := ["199", "4242", "0", "0", "0", "0", "1", "0", "0", "-", "-", "10000038"]
	后端.call("_handle_char_look_text", PackedStringArray(基))
	_记(int((后端.get("authoritative_stats") as Dictionary).get("lingFace", -1)) == 10000038,
			"② 199 第 12 位（灵气脸）仍要落进权威镜像")
	_记(int((后端.get("authoritative_stats") as Dictionary).get("lingQiColor", -1)) == 7,
			"② 老 12 段 199 没有颜色位 ⇒ 不许把已有颜色冲成 0；实得 %s"
			% (后端.get("authoritative_stats") as Dictionary).get("lingQiColor"))
	_记(颜色帧.is_empty(), "② 老 12 段 199 不该发 ling_color_changed；实得 %s" % [颜色帧])
	var 新帧 := 基.duplicate()
	新帧.append("5")
	后端.call("_handle_char_look_text", PackedStringArray(新帧))
	_记(int((后端.get("authoritative_stats") as Dictionary).get("lingQiColor", -1)) == 5,
			"② 本服 13 段 199 的颜色位要写进权威镜像；实得 %s"
			% (后端.get("authoritative_stats") as Dictionary).get("lingQiColor"))
	_记(颜色帧.size() == 1 and int(颜色帧[0][0]) == 4242 and int(颜色帧[0][1]) == 5,
			"② 13 段 199 要发 ling_color_changed(4242,5)；实得 %s" % [颜色帧])
	后端.ling_color_changed.disconnect(颜色钩)
	后端.set("character_id", 后端角色号)
	后端.set("authoritative_stats", {})


# ── ③ 窗口版式/灰行/颜色块/确定只发差异/关窗还原 ───────────────────────────────
func _测窗口() -> void:
	var 根 := Control.new()
	根.size = Vector2(1280, 720)
	root.add_child(根)
	await process_frame
	var 后端 := 假后端.new()
	root.add_child(后端)
	var 遮罩 := Control.new()
	遮罩.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	根.add_child(遮罩)
	await process_frame

	var 窗 = 窗口脚本.弹出(遮罩, 后端)
	_记(窗 != null, "③ 弹出() 该建出一层")
	if 窗 == null:
		根.queue_free()
		return
	_记(后端.列表请求数 == 1, "③ 打开即发 2081:4 一次；实得 %d" % 后端.列表请求数)
	_记(窗.get_node_or_null("暗层") != null, "③ 回帧之前先铺暗层（挡住下面的装备窗）")

	后端.emit_signal("ling_qi_face_list_received", 脸表, _色表())
	await process_frame
	var 主体: Control = 窗.get("_主体")
	_记(主体 != null, "③ 收到脸表后该建主体")
	if 主体 == null:
		窗.queue_free()
		根.queue_free()
		return

	## 底高 = 28(列表 y) + 520(内容高) + 14 + 22(钮高) + 12 = 596；确定 x=(760-30)/2=365。
	var 底: Control = 主体.get_node_or_null("底")
	_记(底 != null and 底.size == Vector2(760, 596),
			"③ 底板该是 760×596（`buildList:452` 的 bottomY + 钮高 + 12）；实得 %s" % (底.size if 底 else "无底"))
	var 列表: Control = 主体.get_node_or_null("列表")
	_记(列表 != null and 列表.position == Vector2(12, 28), "③ 列表起点该是 (12,28)；实得 %s" % (列表.position if 列表 else "无"))
	var 确定: Control = 主体.get_node_or_null("确定")
	_记(确定 != null and 确定.position == Vector2(365, 562) and 确定.size == Vector2(30, 22),
			"③ 确定钮该在 (365,562)、30×22；实得 %s / %s" % [确定.position if 确定 else "无", 确定.size if 确定 else "无"])
	_记(主体.position == Vector2(260, 62),
			"③ 舞台 1280×720 居中 ⇒ 主体 (260,62)；实得 %s" % 主体.position)

	var 脸列: Control = 列表.get_node_or_null("脸列")
	var 色列: Control = 列表.get_node_or_null("色列")
	var 特效列: Control = 列表.get_node_or_null("特效列")
	_记(脸列 != null and 脸列.position.x == 0 and 色列.position.x == 252 and 特效列.position.x == 504,
			"③ 三列 x 该是 0/252/504（列宽 232 + 隙 20）；实得 %s/%s/%s"
			% [脸列.position.x if 脸列 else "无", 色列.position.x if 色列 else "无", 特效列.position.x if 特效列 else "无"])

	var 炎: CheckBox = 脸列.get_node_or_null("脸_%d" % 神威脸)
	var 十拳: CheckBox = 脸列.get_node_or_null("脸_%d" % 十拳脸)
	var 完全: CheckBox = 脸列.get_node_or_null("脸_%d" % 完全体脸)
	var 双刃: CheckBox = 脸列.get_node_or_null("脸_%d" % 双刃脸)
	_记(炎 != null and 十拳 != null and 完全 != null and 双刃 != null, "③ 四行脸勾该都建出来")
	if 炎 != null and 完全 != null and 双刃 != null:
		_记(not 炎.disabled and not 十拳.disabled, "③ 写轮眼 6 阶 ⇒ 前两档可点")
		_记(完全.disabled and 双刃.disabled, "③ 7/8 阶那两档该 disabled（灰、点不动）")
		_记(完全.text == "须佐之男·完全体  (需写轮眼7阶)" and 双刃.text == "须佐之男·双刃  (需写轮眼8阶)",
				"③ 未解锁行文案要追加「  (需写轮眼N阶)」；实得 %s / %s" % [完全.text, 双刃.text])
		_记(完全.get_theme_color("font_disabled_color") == 窗口脚本.锁定色,
				"③ 未解锁用 #666666（6710886）；实得 %s" % 完全.get_theme_color("font_disabled_color"))
		_记(炎.position == Vector2(0, 26) and 双刃.position == Vector2(0, 110),
				"③ 脸行 y 该按 28 递增（首行 = 节题 24 + 行内 2）；实得 %s/%s" % [炎.position, 双刃.position])

	var 单元 := 色列.get_node_or_null("色_0") as Control
	var 单元一 := 色列.get_node_or_null("色_1") as Control
	_记(单元 != null and 单元.position == Vector2(0, 44),
			"③ 颜色首行该在 y=44（节题 24 + 20）；实得 %s" % (单元.position if 单元 else "无"))
	_记(单元一 != null and 单元一.position == Vector2(112, 44),
			"③ 颜色第二列 x=112（floor((232-8)/2)）；实得 %s" % (单元一.position if 单元一 else "无"))
	_记(窗口脚本._色块颜色(_色表()[0]) == Color8(90, 90, 90),
			"③ 色块公式 int(mul*90+off)：原色行该是 (90,90,90)；实得 %s" % 窗口脚本._色块颜色(_色表()[0]))
	var 行一: Dictionary = (_色表()[1] as Dictionary)
	_记(窗口脚本._色块颜色(行一) == Color8(148, 73, 73),
			"③ 颜色 1 该是 (int(1.18*90+42), int(0.82*90), int(0.82*90)) = (148,73,73)；实得 %s"
			% 窗口脚本._色块颜色(行一))

	var 预览: Control = 脸列.get_node_or_null("预览")
	_记(预览 != null and 预览.position.y == 188,
			"③ 预览区 y 该是 24 + 4×28 + 10 + 42 = 188；实得 %s" % (预览.position.y if 预览 else "无"))
	var 身体: OriginalSprite = 预览.get_node_or_null("预览层/身体") if 预览 != null else null
	_记(身体 != null and 身体.position == Vector2(92, 226),
			"③ 预览身体该在 (92,226)（`createOrUpdatePreviewSprite:1090`）；实得 %s" % (身体.position if 身体 else "无"))

	for 名 in ["呼吸明暗", "外发辉光", "斜向流光", "边缘星闪", "雾化底辉"]:
		var 勾: CheckBox = 特效列.get_node_or_null(名)
		_记(勾 != null and not 勾.button_pressed, "③ 特效「%s」默认关（UIConfig 静态值默认 false）" % 名)

	## 选择即时预览 + 关窗还原（未提交）。
	窗.call("_脸勾选", true, 神威脸)
	窗.call("_色勾选", true, 5)
	窗.call("_特效勾选", true, "呼吸明暗")
	_记(int(窗.get("_选脸")) == 神威脸 and int(窗.get("_选色")) == 5,
			"③ 勾脸/勾色要立即改预览选择；实得 %s/%s" % [窗.get("_选脸"), 窗.get("_选色")])
	var 预览灵: Node = 窗.get("_预览灵器")
	_记(预览灵 != null and int(预览灵.get("_脸")) == 神威脸 and int(预览灵.get("_色")) == 5,
			"③ 预览叠层要跟着换脸/换色")
	_记(外观数据.呼吸明暗, "③ 勾特效要**立即**写进 UIConfig（原版 applySelectedEffectsToConfig）")
	窗.call("_关闭")
	await process_frame
	_记(not 外观数据.呼吸明暗, "③ 有未提交的脸/色改动 ⇒ 关窗要把特效还原（`destroy:1121-1129`）")

	## 只发差异 + 提交后特效保留。
	后端.脸请求.clear()
	后端.色请求.clear()
	窗 = 窗口脚本.弹出(遮罩, 后端)
	后端.emit_signal("ling_qi_face_list_received", 脸表, _色表())
	await process_frame
	窗.call("_脸勾选", true, 神威脸)
	窗.call("_色勾选", true, 5)
	窗.call("_特效勾选", true, "外发辉光")
	窗.call("_确定")
	await process_frame
	_记(后端.脸请求 == [神威脸], "③ 确定只发改了的脸 ⇒ [10000038]；实得 %s" % [后端.脸请求])
	_记(后端.色请求 == [5], "③ 确定只发改了的色 ⇒ [5]；实得 %s" % [后端.色请求])
	_记(外观数据.外发辉光, "③ 提交后特效开关保留（原版 else 分支 applySelectedEffectsToConfig）")

	## 原值提交 ⇒ 一个包都不发。
	后端.脸请求.clear()
	后端.色请求.clear()
	窗 = 窗口脚本.弹出(遮罩, 后端)
	后端.emit_signal("ling_qi_face_list_received", 脸表, _色表())
	await process_frame
	窗.call("_确定")
	await process_frame
	_记(后端.脸请求.is_empty() and 后端.色请求.is_empty(),
			"③ 没改动就确定 ⇒ 脸/色一个包都不发；实得 %s/%s" % [后端.脸请求, 后端.色请求])

	根.queue_free()
	await process_frame


# ── ④ 人物身上那层：脸/色/粗细特效跟身体，不改身体本身 ────────────────────────
func _测人物叠加层() -> void:
	var 身体 := OriginalSprite.new()
	root.add_child(身体)
	_记(身体.configure("character", "00000001", "stand"), "④ 前提：普通角色身体 00000001 能建")
	var 层: Node2D = 灵器外观脚本.new()
	root.add_child(层)
	层.call("绑定", 身体)
	await process_frame

	层.call("设外观", 神威脸, 1)
	await process_frame
	var 底: OriginalSprite = 层.get("底")
	_记(bool(层.get("visible")), "④ 脸 10000038 该让叠加层可见")
	_记(底 != null and 底.sprite.texture != null and String(底.sprite.texture.resource_path).contains("10000038"),
			"④ 叠层贴图要来自 10000038 那一套；实得 %s"
			% (String(底.sprite.texture.resource_path) if 底 != null and 底.sprite.texture else "无"))
	_记(底 != null and is_equal_approx(底.sprite.self_modulate.a, 0.7),
			"④ 默认无特效时残影 alpha = 0.7（`reanderLingQi`）；实得 %s"
			% (底.sprite.self_modulate.a if 底 != null else "无"))

	## 颜色走 ColorTransform：tint_mul = (1.18,.82,.82)、tint_add = (42/255,0,0)。
	var 材: ShaderMaterial = null
	if 底 != null and 底.sprite != null:
		材 = 底.sprite.material as ShaderMaterial
	_记(材 != null, "④ 叠层该挂颜色着色器")
	if 材 != null:
		var 乘: Vector3 = 材.get_shader_parameter("tint_mul")
		var 加: Vector3 = 材.get_shader_parameter("tint_add")
		_记(乘.is_equal_approx(Vector3(1.18, 0.82, 0.82)) and 加.is_equal_approx(Vector3(42.0 / 255.0, 0.0, 0.0)),
				"④ 颜色 1 的乘/加该逐值进着色器；实得 %s / %s" % [乘, 加])

	## 动作/帧/朝向跟身体；缺帧保留上一张。
	身体.set_direction(-1)
	await process_frame
	_记(is_equal_approx((层.get("容器") as Node2D).scale.x, -1.0),
			"④ 身体朝左（character 套 scale.x=-1）时叠层要一起翻；实得 %s"
			% [(层.get("容器") as Node2D).scale.x])
	var 原贴 := 底.sprite.texture
	_记(not bool(底.call("显示帧", "根本不存在的动作", 0)) and 底.sprite.texture == 原贴,
			"④ 灵器那套缺这一帧 ⇒ 显示帧返回 false 且保留上一张（原版 reanderLingQi 同语义）")

	## 五个特效：开关即生效；全关回到 0.7 / 1。
	外观数据.呼吸明暗 = true
	层.call("_process", 0.016)
	var 呼吸透 := 底.sprite.self_modulate.a
	var 呼吸缩 := 底.scale.x
	_记(呼吸透 >= 0.54 - 0.001 and 呼吸透 <= 0.74 + 0.001,
			"④ 呼吸明暗 alpha 该落在 0.54+p*0.2；实得 %s" % 呼吸透)
	_记(呼吸缩 >= 1.0 - 0.001 and 呼吸缩 <= 1.025 + 0.001,
			"④ 呼吸明暗 scale 该落在 1+p*0.025；实得 %s" % 呼吸缩)
	外观数据.外发辉光 = true
	层.call("_process", 0.016)
	_记((层.get("辉光") as Sprite2D).visible, "④ 外发辉光开启后辉光层该可见")
	_记((层.get("辉光") as Sprite2D).texture == 底.sprite.texture,
			"④ 辉光用同一帧贴图（不另取美术）")
	_清效果()
	层.call("_process", 0.016)
	_记(is_equal_approx(底.sprite.self_modulate.a, 0.7) and 底.scale.is_equal_approx(Vector2.ONE),
			"④ 五个特效全关 ⇒ 回到 0.7 / scale 1；实得 %s / %s"
			% [底.sprite.self_modulate.a, 底.scale])

	层.call("设外观", 0, 1)
	_记(not bool(层.get("visible")), "④ 脸 0 ⇒ 叠层隐藏（原版没有灵器外观时不出层）")

	层.queue_free()
	身体.queue_free()
	await process_frame
