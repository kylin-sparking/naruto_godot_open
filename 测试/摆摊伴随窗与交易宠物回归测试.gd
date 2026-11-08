extends SceneTree
## 摆摊两扇伴随窗（附身宠物选宠 / 货币上架）+ 交易档选宠窗离线门（#218 C2/C3）。
## 逐件真值 = `真值/窗口/随身摊位窗.md` §⑩（`StallWindow.as:606-671`、`SuiShenPet.as`、
## `UpShelfMoneyWindow.as`）与 `真值/窗口/交易与邀请托盘.md`（`TradeWindow2.as:589-592`、
## `UIMain2.as:4745-4758`）。**期望值一律手抄 AS3/服务端字面量**，不从被测页面反查。
##
## 覆盖：
## ① 摊位第 1 页「宠物列表」⇒ 开附身宠物（用途=摆摊、贴摊窗左侧、页根 193×161、三钮）
## ② 切回第 0 页 ⇒ 选宠窗自己收（`selectedBtnHandler:469-535` 的 `setDOShow2(…,false)`）
## ③ 第 2 页「货币上架」⇒ 开货币窗（251×139、默认卖金币、币种/两枚单选/四道输入闸）
## ④ 选宠上架六道闸（满 10 / 不能交易 / 出战 / 附身 / 6 阶 / 有装备）各不发、不开确认窗
## ⑤ 六闸全过 ⇒ 上架单 + 摊位上架页（宠物名/数量 1/图标），确定 ⇒ `1296:5:<uid>:<金>:<宝>`
## ⑥ 关摊位 ⇒ 上架模式与上架单清空、两扇伴随窗一起收（原版随 `StallWindow` 销毁）
## ⑦ 交易「宠物列表」⇒ 开/收附身宠物（用途=交易、贴交易窗旁），选中后「上架」⇒ `119:18`
## ⑧ 交易锁定 ⇒ 选宠窗「上架」灰；解锁再亮（`setShangjiaBtnEnbled` / `setOtherData`）
## ⑨ 关交易窗 ⇒ 只收交易档选宠窗（同用途判定）；`335:8/9` 的 `_on_trade_closed` 两类都收
##
## 跑法：`godot --path . --headless --script res://测试/摆摊伴随窗与交易宠物回归测试.gd`

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 交易场景 := preload("res://场景/界面/窗口/交易/交易窗.tscn")
const 摊位窗 := preload("res://脚本/界面/窗口/摆摊/摊位窗.gd")
const 交易窗 := preload("res://脚本/界面/窗口/交易/交易窗.gd")
const 后端脚本 := preload("res://脚本/单例/后端连接.gd")

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 通知: Array = []


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _结() -> void:
	跑完了 = true
	print("摆摊伴随窗与交易宠物离线门：通过 %d，红 %d" % [通过, 失败])


func _initialize() -> void:
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
		_结()
	quit(1 if 失败 > 0 else 0)


func _矩形(件: Control) -> Array:
	return [件.offset_left,件.offset_top, 件.offset_right - 件.offset_left,
			件.offset_bottom - 件.offset_top]


func _近(实: Array, 参: Array) -> bool:
	if 实.size() != 4:
		return false
	for i in 4:
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true


func _开着(窗) -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


func _找页(窗: Node, 名: String) -> Control:
	var 内容 = 窗.get("_content")
	if 内容 == null:
		return null
	for 子 in (内容 as Control).get_children():
		if String(子.name) == 名:
			return 子 as Control
	return null


## 窗左上（屏幕坐标）。`窗口偏移()` 存的是**相对视口中心**的偏移 ⇒ 反算回去。
func _左上(窗: Node) -> Vector2:
	var 偏: Vector2 = 窗.call("取位置偏移")
	var 尺: Vector2 = 窗.call("取窗口尺寸")
	return 偏 + get_root().get_visible_rect().size * 0.5 - 尺 * 0.5


func _关页(管理: Node, 名: String) -> void:
	var 窗 = 管理.call("取窗口", 名)
	if 窗 != null and bool(窗.call("已打开")):
		窗.call("close")


## `输入确认弹.弹消息` 挂的那层（`mdialog = message`）。摊位上架页的价闸都在这里出话。
func _消息弹(宿主: Node) -> Control:
	var 遮罩 = 宿主.get("_overlay")
	if 遮罩 == null:
		return null
	for 子 in (遮罩 as Control).get_children():
		if String(子.get_meta("mdialog", "")) == "message":
			return 子 as Control
	return null


## 真鼠标点一下（无头门三条硬口径：钉视口 / 先 motion / position+global_position+button_mask）。
func _点后(件: Control) -> void:
	var 屏: Vector2 = 件.get_global_rect().position + Vector2(
			min(10.0, 件.size.x * 0.5), min(10.0, 件.size.y * 0.5))
	var 移 := InputEventMouseMotion.new()
	移.position = 屏
	移.global_position = 屏
	root.push_input(移)
	await process_frame
	await process_frame
	var 按 := InputEventMouseButton.new()
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	按.position = 屏
	按.global_position = 屏
	root.push_input(按)
	await process_frame
	await process_frame
	var 放 := InputEventMouseButton.new()
	放.button_index = MOUSE_BUTTON_LEFT
	放.pressed = false
	放.position = 屏
	放.global_position = 屏
	root.push_input(放)
	await process_frame
	await process_frame
	await process_frame


## 假后端：只接管出帧那半边（入帧/开窗仍然走真后端与真控制器）。
class 假后 extends Node:
	var character_id := 7001
	var authoritative_stats := {"money": 500, "cash": 100}
	var authoritative_trade: Dictionary = {}
	var 发过: Array = []

	func _记(话: String) -> bool:
		发过.append(话)
		return true

	func request_stall_add_money(是金币: bool, 金币数: int, 元宝数: int) -> bool:
		return _记("1296:8:%d:%d:%d" % [1 if 是金币 else 0, 金币数, 元宝数])

	func request_stall_add_pet(唯一号: int, 金: int, 宝: int) -> bool:
		return _记("1296:5:%d:%d:%d" % [唯一号, 金, 宝])

	func request_trade_set_pet(唯一号: int) -> bool:
		return _记("119:18:%d" % 唯一号)


func _宠(唯一号: int, 物品号: int, 名: String) -> Dictionary:
	return {"id": str(物品号).pad_zeros(8), "unique_id": 唯一号, "item_id": 物品号, "name": 名,
			"level": 30, "aptitude": 2, "can_trade": true, "deployed": false,
			"attached": false, "equipment": [], "skills": []}


func _跑() -> void:
	print("摆摊伴随窗与交易宠物离线门开始")
	await process_frame
	root.size = Vector2i(960, 560)		# ⚠ 不钉视口，无头 push_input 拿不到 GUI 命中
	var 后 = root.get_node("BackendConnection")
	后.set("in_game", false)
	后.set("character_id", 7001)
	## 摊主档要判「摊主号 == 我号」⇒ 这里把我自己当成摊主。
	后.set("authoritative_stall", {"owner_id": 7001, "owner_name": "我",
			"stall_name": "我的摊", "listings": [], "logs": []})
	var 交态: Dictionary = 后端脚本._空交易状态()
	交态["active"] = true
	交态["other_name"] = "对手"
	后.set("authoritative_trade", 交态)
	后.set("authoritative_stats", {"money": 500, "cash": 100})
	var 会 = root.get_node("GameSession")
	var 宠单: Array[Dictionary] = []
	宠单.append(_宠(8801, 101, "忍犬"))
	宠单.append(_宠(8802, 102, "忍犬"))
	会.set("pets", 宠单)
	会.notification_requested.connect(func(文: String) -> void: 通知.append(文))
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	for i in 4:
		await process_frame

	# ── A. 摊位窗（摊主档）───────────────────────────────────────
	管理.call("打开", "随身摊位")
	for i in 3:
		await process_frame
	var 摊宿主 = 管理.call("取窗口", "随身摊位")
	if not _开着(摊宿主):
		_判(false, "随身摊位窗没开出来 ⇒ 后面的判据无从跑起")
		_结()
		return
	var 摊页 := _找页(摊宿主, "原版随身摊位内容")
	if 摊页 == null:
		_判(false, "摊位窗页没建出来（`原版随身摊位内容`）")
		_结()
		return
	_判((摊页.get_node("上架钮") as Button).visible,
			"摊主档露「物品上架」（原版 `showView(true):451-468`）")

	# ① 第 1 页 ⇒ 点「宠物列表」开选宠窗（页签只换行集，开窗的是那颗上架钮）
	await _点后(摊页.get_node("页签条/页签1") as Control)
	await _点后(摊页.get_node("上架钮") as Button)
	var 宠宿 = 管理.call("取窗口", "附身宠物")
	_判(_开着(宠宿), "第 1 页「宠物列表」⇒ 附身宠物窗自己开")
	_判(String(宠宿.get("_附身用途")) == "摆摊",
			"摆摊入口写 `_附身用途 = 摆摊`（实得「%s」）" % String(宠宿.get("_附身用途")))
	var 宠页 := _找页(宠宿, "附身宠物内容")
	if 宠页 == null:
		_判(false, "选宠窗页没建出来（`附身宠物内容`）")
		_结()
		return
	_判(absf(宠页.size.x - 193.0) < 0.51 and absf(宠页.size.y - 161.0) < 0.51,
			"页根 = 193×161（整窗 193×190 − 标题 29），实得 %.0f×%.0f" % [宠页.size.x, 宠页.size.y])
	_判((宠宿.call("取窗口尺寸") as Vector2).is_equal_approx(Vector2(193.0, 190.0)),
			"外框 193×190（`SuiShenPet.as:51-53` 的 `super(…)` 尺寸表那两格）")
	_判(_近(_矩形(宠页.get_node("列表底") as Control), [6.0, 1.0, 183.0, 126.0]),
			"列表底 (6,1) 183×126（`SuiShenPet.as:60-64` 的 AS3 y=30 − 29）")
	for 组 in [["查看钮", [6.0, 133.0, 37.0, 22.0]], ["上架钮", [78.0, 133.0, 37.0, 22.0]],
			["取消钮", [150.0, 133.0, 37.0, 22.0]]]:
		var 钮 := 宠页.get_node(String(组[0])) as Button
		_判(_近(_矩形(钮), 组[1]) and String(钮.text) in ["查看", "上架", "取消"],
				"%s 框 = %s、文字「%s」" % [组[0], 组[1], 钮.text])
	_判(not (宠页.get_node("上架钮") as Button).disabled, "清单非空 ⇒ 「上架」可点")
	var 宠左 := _左上(宠宿)
	var 摊左 := _左上(摊宿主)
	_判(宠左.x < 摊左.x - 1.0 and absf(宠左.y - 摊左.y) < 0.51,
			"摆摊档选宠窗贴摊窗左侧、顶边平齐（摊 %.1f,%.1f / 宠 %.1f,%.1f）" % [摊左.x, 摊左.y, 宠左.x, 宠左.y])

	# ② 切回第 0 页 ⇒ 选宠窗自己收
	await _点后(摊页.get_node("页签条/页签0") as Control)
	_判(not _开着(宠宿), "切回「物品」页 ⇒ 选宠窗自己收（`setDOShow2(…,false)`）")

	# ③ 第 2 页 ⇒ 点「货币上架」开货币窗
	await _点后(摊页.get_node("页签条/页签2") as Control)
	await _点后(摊页.get_node("上架钮") as Button)
	var 币宿 = 管理.call("取窗口", "货币上架")
	_判(_开着(币宿), "第 2 页「货币上架」⇒ 货币上架窗自己开")
	var 币页 := _找页(币宿, "货币上架内容")
	if 币页 == null:
		_判(false, "货币窗页没建出来（`货币上架内容`）")
		_结()
		return
	_判(absf(币页.size.x - 251.0) < 0.51 and absf(币页.size.y - 139.0) < 0.51,
			"页根 = 251×139（整窗 251×168 − 标题 29），实得 %.0f×%.0f" % [币页.size.x, 币页.size.y])
	_判((币宿.call("取窗口尺寸") as Vector2).is_equal_approx(Vector2(251.0, 168.0)),
			"外框 251×168（`UpShelfMoneyWindow.as:60` 的 `super(251,168,false)`）")
	_判(_近(_矩形(币页.get_node("底") as Control), [6.0, 10.0, 239.0, 124.0]),
			"黄底 (6,10) 239×124（`:273-274` + `:297` 反推）")
	_判(_近(_矩形(币页.get_node("数量输入") as Control), [73.0, 47.0, 95.0, 20.0])
			and _近(_矩形(币页.get_node("价格输入") as Control), [73.0, 82.0, 95.0, 20.0])
			and _近(_矩形(币页.get_node("金币单选") as Control), [173.0, 41.0, 19.0, 19.0])
			and _近(_矩形(币页.get_node("元宝单选") as Control), [173.0, 64.0, 19.0, 19.0]),
			"两枚输入 / 两枚单选框按 §⑩ 的表")
	_判(String((币页.get_node("提示") as Label).text) == "请输入要出售的数量",
			"提示 = STALLUPSHELFWINDOW_INPUT_SALE_COUNT（实得「%s」）" % (币页.get_node("提示") as Label).text)
	_判(int(币宿.get("_货币类型")) == 0 and String((币页.get_node("币种") as Label).text) == "商城元宝",
			"`setData():259-269` 默认卖金币 ⇒ 币种列写「商城元宝」（实得「%s」）"
			% (币页.get_node("币种") as Label).text)
	_判((币页.get_node("金币单选") as TextureRect).texture != null
			and (币页.get_node("格/图标") as TextureRect).texture != null,
			"默认档两枚图都挂上（金币复选框选中 / 格内金币图标）")
	var 币左 := _左上(币宿)
	_判(币左.x < 摊左.x - 1.0 and absf(币左.y - 摊左.y) < 0.51,
			"货币窗贴摊窗左侧、顶边平齐（摊 %.1f / 币 %.1f）" % [摊左.x, 币左.x])

	# 点「元宝」⇒ 换档：标签写「游戏金币」、两格清空、两张复选框对调
	(币页.get_node("数量输入") as LineEdit).text = "12"
	(币页.get_node("价格输入") as LineEdit).text = "7"
	await _点后(币页.get_node("元宝单选") as Control)
	_判(int(币宿.get("_货币类型")) == 1 and String((币页.get_node("币种") as Label).text) == "游戏金币",
			"点「商城元宝」⇒ 换档为卖元宝、币种列写「游戏金币」（实得「%s」）"
			% (币页.get_node("币种") as Label).text)
	_判(String((币页.get_node("数量输入") as LineEdit).text).is_empty()
			and String((币页.get_node("价格输入") as LineEdit).text).is_empty(),
			"`onClickRadioBtn():240-257` 换档同时清空两格")
	await _点后(币页.get_node("金币单选") as Control)
	_判(int(币宿.get("_货币类型")) == 0, "点回「游戏金币」⇒ 回到卖金币档")

	## 出帧这半边换假后端（入帧/开窗已用真后端核过）。
	var 币假 := 假后.new()
	币假.authoritative_trade = 交态.duplicate(true)
	币宿.set("_backend", 币假)
	通知.clear()
	(币页.get_node("数量输入") as LineEdit).text = ""
	(币页.get_node("价格输入") as LineEdit).text = "5"
	await _点后(币页.get_node("上架") as Button)
	_判(通知.size() > 0 and String(通知.back()) == "您没有输入要出售货币的数量，请您输入后继续进行上架出售操作。"
			and 币假.发过.is_empty() and _开着(币宿),
			"空数量 ⇒ 只出 NOTICE_1、一帧不发、窗不关（实得「%s」）" % (String(通知.back()) if 通知.size() > 0 else "无"))
	通知.clear()
	(币页.get_node("数量输入") as LineEdit).text = "10"
	(币页.get_node("价格输入") as LineEdit).text = ""
	await _点后(币页.get_node("上架") as Button)
	_判(通知.size() > 0 and String(通知.back()) == "您没有输入出售价格，请您输入后继续进行上架出售操作。"
			and 币假.发过.is_empty(),
			"空价格 ⇒ 只出 NOTICE_2（实得「%s」）" % (String(通知.back()) if 通知.size() > 0 else "无"))
	通知.clear()
	(币页.get_node("数量输入") as LineEdit).text = "600"
	(币页.get_node("价格输入") as LineEdit).text = "3"
	await _点后(币页.get_node("上架") as Button)
	_判(通知.size() > 0 and String(通知.back()) == "您背包中的游戏金币不足，无法上架出售"
			and 币假.发过.is_empty(),
			"数量 > 金币余额 ⇒ 只出 NOTICE_3（实得「%s」）" % (String(通知.back()) if 通知.size() > 0 else "无"))
	通知.clear()
	(币页.get_node("数量输入") as LineEdit).text = "400"
	(币页.get_node("价格输入") as LineEdit).text = "3"
	await _点后(币页.get_node("上架") as Button)
	_判(币假.发过 == ["1296:8:1:400:3"],
			"四道闸全过 ⇒ `1296:8:1:400:3`（是金币 / 金币数 / 元宝数），实得 %s" % [币假.发过])
	_判(not _开着(币宿), "发完自己关窗（`UpShelfMoneyWindow.as:95` 的 `onCloseBtnClick`）")

	# ④ 选宠上架六道闸（第 0 页时切页只会收伴随窗；这里直接调静态闸函数）
	await _点后(摊页.get_node("页签条/页签0") as Control)
	var 原桶: Dictionary = 摊宿主.get("_摊位桶")
	var 好宠 := _宠(8801, 101, "忍犬")
	var 闸例 := [
		["不能交易", _变("can_trade", false, 好宠), "该通灵兽不能交易"],
		["已出战", _变("deployed", true, 好宠), "该通灵兽已经出战，不能上架！"],
		["已附身", _变("attached", true, 好宠), "该通灵兽已经附身，不能上架！"],
		["6 阶", _宠(8803, 106, "忍犬"), "6阶以上的通灵兽不能交易！"],
		["带装备", _变("equipment", [{"槽": 1}], 好宠), "请先卸掉通灵兽的装备再上架！"],
	]
	for 例 in 闸例:
		摊位窗.上架单 = {}
		_关页(管理, "摊位上架")
		通知.clear()
		摊位窗.选宠上架(摊宿主, 例[1])
		_判(摊位窗.上架单.is_empty() and not _开着(管理.call("取窗口", "摊位上架"))
				and 通知.size() > 0 and String(通知.back()) == 例[2],
				"%s 闸 ⇒ 只出「%s」、不开确认窗（实得「%s」）" % [例[0], 例[2],
					String(通知.back()) if 通知.size() > 0 else "无"])
	# 满 10 那道闸数的是**宠物桶**
	摊位窗.上架单 = {}
	_关页(管理, "摊位上架")
	var 满桶: Array = []
	for i in 10:
		满桶.append({"uid": i + 1, "kind": 3})
	摊宿主.set("_摊位桶", {"物品": [], "宠物": 满桶, "货币": []})
	通知.clear()
	摊位窗.选宠上架(摊宿主, 好宠)
	_判(摊位窗.上架单.is_empty() and 通知.size() > 0
			and String(通知.back()) == "对不起，你的上架物品已达到限制，请先下架！",
			"宠物桶满 10 ⇒ 只出 STALL_WINDOW_NOTICE_1（实得「%s」）"
			% (String(通知.back()) if 通知.size() > 0 else "无"))
	摊宿主.set("_摊位桶", 原桶)

	# ⑤ 六闸全过 ⇒ 上架单 + 摊位上架确认页
	摊位窗.上架单 = {}
	_关页(管理, "摊位上架")
	摊位窗.选宠上架(摊宿主, 好宠)
	var 单: Dictionary = 摊位窗.上架单
	_判(not 单.is_empty() and int((单.get("宠物", {}) as Dictionary).get("unique_id", 0)) == 8801,
			"六闸全过 ⇒ 上架单挂上这只（实得 %s）" % [单])
	var 确宿主 = 管理.call("取窗口", "摊位上架")
	_判(_开着(确宿主), "上架单非空 ⇒ 摊位上架页开出来")
	var 确页 := _找页(确宿主, "原版摊位购买内容")
	if 确页 == null:
		_判(false, "摊位上架页没建出来（`原版摊位购买内容`）")
		_结()
		return
	_判(String((确页.get_node("名称框/名称文") as Label).text) == "忍犬"
			and String((确页.get_node("数量行/数量文") as Label).text) == "1",
			"确认页写宠物名/数量 1（`setData:145` 的 `count = 1`），实得「%s」「%s」"
			% [(确页.get_node("名称框/名称文") as Label).text,
				(确页.get_node("数量行/数量文") as Label).text])
	_判((确页.get_node("物品格/图标") as TextureRect).texture != null,
			"格子画的是宠物头像（`PortraitHead(TYPE_PET, itemId)`）")
	var 确假 := 假后.new()
	确假.authoritative_trade = 交态.duplicate(true)
	确宿主.set("_backend", 确假)
	通知.clear()
	await _点后(确页.get_node("确定钮") as Button)
	var 弹 := _消息弹(确宿主)
	var 弹文 := ""
	if 弹 != null:
		var 正文件 := 弹.find_child("正文", true, false) as RichTextLabel
		if 正文件 != null:
			弹文 = String(正文件.text)
	_判(确假.发过.is_empty() and 弹 != null and 弹文 == "请填写要出售物品的价格！",
			"两个价都是 0 ⇒ 弹 MDIALOG_4、一帧不发（实得「%s」）" % 弹文)
	if 弹 != null:
		var 弹确 := 弹.find_child("确定", true, false) as Button
		if 弹确 != null:
			弹确.pressed.emit()
	await process_frame
	(确页.get_node("价1输入") as LineEdit).text = "120"
	(确页.get_node("价2输入") as LineEdit).text = "0"
	await _点后(确页.get_node("确定钮") as Button)
	_判(确假.发过 == ["1296:5:8801:120:0"],
			"宠物档跳过「太便宜」闸、直接 `1296:5:<uid>:<金>:<宝>`（实得 %s）" % [确假.发过])
	_判(摊位窗.上架单.is_empty() and not _开着(确宿主),
			"发完清上架单并自己关窗（`sureToUpShelf:183-194`）")

	# ⑥ 关摊位 ⇒ 上架模式/上架单清空 + 两扇伴随窗一起收
	摊页 = _找页(摊宿主, "原版随身摊位内容")
	await _点后(摊页.get_node("页签条/页签1") as Control)
	摊页 = _找页(摊宿主, "原版随身摊位内容")
	await _点后(摊页.get_node("上架钮") as Control)
	管理.call("打开", "货币上架")
	for i in 3:
		await process_frame
	var 币宿2 = 管理.call("取窗口", "货币上架")
	_判(_开着(宠宿) and _开着(币宿2), "两扇伴随窗可以同时开着（切页只收另一扇，直接开不互斥）")
	摊位窗.上架模式 = true
	摊位窗.上架单 = {"物品": {"name": "残留"}}
	摊宿主.call("close")
	for i in 2:
		await process_frame
	_判(not _开着(宠宿) and not _开着(币宿2),
			"关摊位 ⇒ 选宠窗与货币窗一起收（原版随 `StallWindow` 销毁）")
	_判(not bool(摊位窗.上架模式) and (摊位窗.上架单 as Dictionary).is_empty(),
			"关摊位 ⇒ 上架模式与上架单都清空（`关窗清态`）")

	# ── B. 交易窗（宠物列表 = 选宠窗交易档）─────────────────────
	管理.call("打开", "交易")
	for i in 3:
		await process_frame
	var 交宿主 = 管理.call("取窗口", "交易")
	var 交页 := _找页(交宿主, "原版交易内容")
	if 交页 == null:
		_判(false, "交易窗页没建出来（`原版交易内容`）")
		_结()
		return
	await _点后(交页.get_node("宠物列表钮") as Control)
	var 交宠宿 = 管理.call("取窗口", "附身宠物")
	_判(_开着(交宠宿) and String(交宠宿.get("_附身用途")) == "交易",
			"交易「宠物列表」⇒ 开附身宠物（用途=交易），实得「%s」"
			% String(交宠宿.get("_附身用途")))
	交页 = _找页(交宿主, "原版交易内容")
	var 交宠页 := _找页(交宠宿, "附身宠物内容")
	if 交宠页 == null:
		_判(false, "交易档选宠页没建出来")
		_结()
		return
	var 交左 := _左上(交宿主)
	var 交尺: Vector2 = 交宿主.call("取窗口尺寸")
	var 交宠左 := _左上(交宠宿)
	var 贴左 := absf(交宠左.x - (交左.x - 193.0)) < 0.51
	var 贴右 := absf(交宠左.x - (交左.x + 交尺.x)) < 0.51
	_判(贴左 or 贴右, "交易档选宠窗贴交易窗左/右侧（交 %.1f / 宠 %.1f）" % [交左.x, 交宠左.x])
	_判(absf(交宠左.y - 交左.y) < 0.51, "交易档选宠窗顶边与交易窗平齐")

	# 再点一次收起（`reverseDisplay` 开关，不是每次重开）
	交页 = _找页(交宿主, "原版交易内容")
	await _点后(交页.get_node("宠物列表钮") as Control)
	_判(not _开着(交宠宿), "再点「宠物列表」⇒ 选宠窗收起（`reverseDisplay`）")
	交页 = _找页(交宿主, "原版交易内容")
	await _点后(交页.get_node("宠物列表钮") as Control)
	_判(_开着(交宠宿), "第三次点 ⇒ 又开出来")

	# ⑦ 选中第 0 只 + 「上架」⇒ 119:18
	# 重开时选宠页会重建 ⇒ 指针必须重新取（`_render_page` 清 `_content`）
	交宠宿 = 管理.call("取窗口", "附身宠物")
	交宠页 = _找页(交宠宿, "附身宠物内容")
	if 交宠页 == null:
		_判(false, "第三次开出来的选宠页没建出来")
		_结()
		return
	var 交假 := 假后.new()
	交假.authoritative_trade = 交态.duplicate(true)
	交宠宿.set("_backend", 交假)
	交宠宿.set("_附身选中", 0)
	await _点后(交宠页.get_node("上架钮") as Button)
	_判(交假.发过 == ["119:18:8801"],
			"交易档「上架」⇒ `119:18:<uid>`（实得 %s）" % [交假.发过])

	# ⑧ 锁定 ⇒ 选宠窗「上架」灰；解锁再亮（`_同步选宠钮` 读 `my_locked`）
	var 锁态: Dictionary = 交态.duplicate(true)
	锁态["my_locked"] = true
	后.set("authoritative_trade", 锁态)
	交易窗.重灌(交宿主, 交易场景, 锁态)
	await process_frame
	交宠宿 = 管理.call("取窗口", "附身宠物")
	交宠页 = _找页(交宠宿, "附身宠物内容")
	if 交宠页 == null:
		_判(false, "锁定重灌后选宠页丢了")
		_结()
		return
	_判((交宠页.get_node("上架钮") as Button).disabled,
			"我这半锁定 ⇒ 选宠窗「上架」灰（`setShangjiaBtnEnbled(false)`）")
	锁态["my_locked"] = false
	后.set("authoritative_trade", 锁态)
	交易窗.重灌(交宿主, 交易场景, 锁态)
	await process_frame
	交宠宿 = 管理.call("取窗口", "附身宠物")
	交宠页 = _找页(交宠宿, "附身宠物内容")
	if 交宠页 == null:
		_判(false, "解锁重灌后选宠页丢了")
		_结()
		return
	_判(not (交宠页.get_node("上架钮") as Button).disabled,
			"解锁 ⇒ 选宠窗「上架」再亮（`setOtherData`）")

	# ⑨ 关交易窗 ⇒ 只收交易档选宠窗；`_on_trade_closed` 把交易/背包/选宠一起收
	交宿主.call("close")
	for i in 2:
		await process_frame
	_判(not _开着(交宠宿), "关交易窗 ⇒ 交易档选宠窗跟着关（原版 `suiShenPet` 一起拆）")
	管理.call("打开", "交易")
	for i in 3:
		await process_frame
	交宿主 = 管理.call("取窗口", "交易")
	交页 = _找页(交宿主, "原版交易内容")
	await _点后(交页.get_node("宠物列表钮") as Control)
	交宠宿 = 管理.call("取窗口", "附身宠物")
	_判(_开着(交宠宿), "重开后选宠窗能再开（关窗清干净的旁证）")
	# 原版 `335:8/9` 不看交易窗还开着没，无条件关 `suiShenPet`。这里只藏交易窗
	# （不走本地 close 钩子），单看 `_on_trade_closed` 那三个名字里有没有选宠窗。
	(交宿主.get("_overlay") as CanvasItem).visible = false
	_判(_开着(交宠宿), "交易窗藏起来后选宠窗仍在（隔离前提）")
	管理.call("_on_trade_closed", "成交")
	for i in 2:
		await process_frame
	_判(not _开着(交宿主) and not _开着(交宠宿),
			"`335:8/9` ⇒ `_on_trade_closed` 无条件收交易与选宠窗（`Client.as:7420-7427`）")

	_结()


## 造一个只改一个字段的宠（浅拷贝）。
func _变(键: String, 值, 源: Dictionary) -> Dictionary:
	var 份 := 源.duplicate(true)
	份[键] = 值
	return 份
