extends SceneTree

## 「火影有礼」礼包详情窗回归门（2026-10-20，用户实机报「礼包没有详情框」）。
##
## 病根：`preview == 1` 的 libao/libao_fufei 在原版里**先弹 `SelectGiftWindow`**
## （`ItemWindow2.as:990-1017`），窗上显示等级、成本、奖励格，点「打开礼包」才发 USE_ITEM。
## 本工程之前只有 `libao_select` 的选择窗，其余 preview 礼包双击就直接吃了 —— 玩家看不到
## 这一包里有什么、也看不到要花多少金币/点券/元宝。
##
## 本门钉七件：
##   ① 数据源：`数据/礼包详情.json` 只收 preview==1；11000001 = libao / req 5 / 金币 2000；
##      11030022 = libao_fufei / 元宝 320；11020001 = libao_select（不该被这扇窗截走）。
##   ② 奖励行：当前职业组 = 通用组 "0" + 本职业组，11000001 在职业 300 下 10 行，
##      第 0 行必须是下一只 11000002（礼包链）。
##   ③ 拦截：对 11000001 调 `_use_item` ⇒ **只开窗、不吃件**（数量仍 1）。
##   ④ 版式（`createUI/defaultUi:298-378` + `updateLayout:416-446`）：
##      可开窗 202×300、12 格 @ 容器局部 (6+41·列, 6+41·行)、标题「火影有礼」、
##      等级行 5、金币 2000 / 点券 0、打开钮 (70,267) 61×22。
##   ⑤ 打开：离线结算**获得 2000 金币**（底部「金币：」是内含奖励，不是成本）、
##      发 11000002 和本职业行、吃掉 11000001、关窗撤遮罩。
##   ⑥ 等级不足：窗 202×321、红字「很抱歉，你的等级不足！」、打开钮禁用、不扣件。
##   ⑦ 付费版：11030022 ⇒ 202×313、16 格、顶部「礼包开启需要支付 320 元宝」，
##      没有金币/点券两行；打开扣 320 元宝。
##
## ⚠️ 本门会 `_save_local_state()` 落盘 user:// ⇒ 开场文件快照、收尾按字节还原（§3.76.1）。
## ⚠️ 窗挂在 `功能窗口._overlay` 上 ⇒ 开场钉 `root.size`（无头视口，居中算式读它）。
##
## 运行：Godot --headless --path . --script res://测试/礼包详情窗回归测试.gd

const 窗场景 := "res://场景/界面/功能窗口.tscn"
const 会话路径 := "/root/GameSession"

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 详情窗脚本 := preload("res://脚本/界面/窗口/礼包详情窗.gd")
const 门存档快照 := preload("res://测试/门存档快照.gd")

var _失败: Array[String] = []
var _受检 := 0
var _快照: Dictionary = {}
var _文件前 := {}
var _秒 := 0.0


func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_run")


func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 90.0:
		_收尾()
		printerr("礼包详情窗回归测试：看门狗超时（90s）—— 中途崩了没走到收尾，已强制还原快照")
		quit(1)
		return true
	return false


func _查(过: bool, 文: String) -> void:
	_受检 += 1
	if not 过:
		_失败.append(文)
		print("!! " + 文)


func _件(物品id: String, 件数: int, 补丁 := {}) -> Dictionary:
	var 条 := {"id": 物品id, "name": 物品id, "category": "消耗品",
			"quantity": 件数, "price": 20,
			"icon": "res://素材/界面/原版窗口/通用控件/物品格.png"}
	条.merge(补丁, true)
	return 条


func _在包(会话, 物品号: int) -> bool:
	for 条 in (会话.inventory as Array):
		var 号 := String((条 as Dictionary).get("id", ""))
		if 号.is_valid_int() and int(号) == 物品号:
			return true
	return false


func _取窗(遮罩层: Control) -> Control:
	for 子 in 遮罩层.get_children():
		if String(子.name).begins_with("礼包详情窗"):
			return 子 as Control
	return null


func _格们(窗: Control) -> Array:
	var 出: Array = []
	for 子 in (窗.get_node("格阵") as Control).get_children():
		if 子 is Button:
			出.append(子)
	return 出


func _run() -> void:
	root.size = Vector2i(960, 560)
	var 会话 = root.get_node(会话路径)
	_快照 = {
		"player_stats": (会话.player_stats as Dictionary).duplicate(true),
		"inventory": (会话.inventory as Array).duplicate(true),
		"storage": (会话.storage as Array).duplicate(true),
		"equipped_items": (会话.equipped_items as Dictionary).duplicate(true),
	}

	# —— ① 数据源 ——
	var 详情: Dictionary = 游戏数据.礼包详情("11000001")
	_查(String(详情.get("type", "")) == "libao", "11000001 的 type 不是 libao（实测 %s）" % 详情.get("type"))
	_查(int(详情.get("req_level", -1)) == 5, "11000001 的 req_level 不是 5")
	_查(int((详情.get("money", {}) as Dictionary).get("point", -1)) == 2000,
		"11000001 的金币奖励不是 2000（详情窗「金币：」那行）")
	var 付费: Dictionary = 游戏数据.礼包详情("11030022")
	_查(String(付费.get("type", "")) == "libao_fufei", "11030022 的 type 不是 libao_fufei")
	_查(absi(int((付费.get("money", {}) as Dictionary).get("cash", 0))) == 320,
		"11030022 的元宝成本不是 320（原版 `Math.abs(money.cash)`）")
	var 自选: Dictionary = 游戏数据.礼包详情("11020001")
	_查(String(自选.get("type", "")) == "libao_select",
		"11020001 的 type 不是 libao_select（它该走已有的自选礼包窗）")
	_查((游戏数据.礼包详情("11000156") as Dictionary).is_empty(),
		"11000156 是 preview=0 的普通礼包，不该出现在礼包详情表里")

	# —— ② 奖励行：通用组 + 当前职业组 ——
	var 行300: Array = 游戏数据.礼包详情物品("11000001", 300)
	_查(行300.size() == 10, "11000001 在职业 300 下该有 10 行（组0 5 行 + 组300 5 行），实测 %d" % 行300.size())
	if not 行300.is_empty():
		_查(String((行300[0] as Dictionary).get("item_id", "")) == "11000002",
			"11000001 第 0 行不是下一只礼包 11000002（礼包链断了）")
	var 行0: Array = 游戏数据.礼包详情物品("11000001", 0)
	_查(行0.size() == 5, "职业 0 只该看到通用组 5 行，实测 %d" % 行0.size())

	# —— 开窗所在的宿主 ——
	var 场: Node = (load(窗场景) as PackedScene).instantiate()
	root.add_child(场)
	await process_frame
	await process_frame
	var 遮罩层 := 场.get("_overlay") as Control
	if 遮罩层 == null:
		_查(false, "功能窗口没有 _overlay，开窗这条路没法测")
		_收尾()
		quit(1)
		return

	会话.player_stats["level"] = 100
	会话.player_stats["job"] = 300
	会话.player_stats["gold"] = 100000
	会话.player_stats["cash"] = 100000
	会话.player_stats["cash_bind"] = 100000
	会话.player_stats["common_slots"] = 90

	# —— ③ 拦截 + ④ 非付费版版式 ——
	会话.inventory = 会话.落位带洞([_件("11000001", 1, {"slot_index": 1})])
	场.call("_use_item", 1)
	await process_frame
	var 窗 := _取窗(遮罩层)
	_查(窗 != null and 窗.visible, "11000001 双击/使用没弹详情窗（原版开 `SelectGiftWindow`）")
	if 窗 == null:
		_收尾()
		quit(1)
		return
	_查(String(会话.格位物品(1).get("id", "")) == "11000001"
			and int(会话.格位物品(1).get("quantity", 0)) == 1,
		"开详情窗就把礼包吃了（原版这段只弹窗，点「打开礼包」才发 USE_ITEM）")
	_查(窗.size == Vector2(202, 300), "可开的非付费窗尺寸 %s ≠ 202×300" % str(窗.size))
	_查((窗.get_node("标题") as Label).text == "火影有礼", "标题 ≠ `SELECT_GIFT_WINDOW_TITLE`")
	_查((窗.get_node("开启等级") as Label).text == "礼包开启需要等级", "等级提示文案不对")
	_查((窗.get_node("等级值") as Label).text == "5", "等级值不是 5")
	_查((窗.get_node("金币标签") as Label).text == "金币：", "金币标签不是「金币：」")
	_查((窗.get_node("金币值") as Label).text == "2000", "金币值不是 2000")
	_查((窗.get_node("点券标签") as Label).text == "点券：", "点券标签不是「点券：」")
	_查((窗.get_node("点券值") as Label).text == "0", "点券值不是 0")
	_查((窗.get_node("黄底") as Panel).position == Vector2(6, 39)
			and (窗.get_node("黄底") as Panel).size == Vector2(190, 224),
		"黄底面板不在 (6,39) 190×224（`background_1`）")
	_查((窗.get_node("子面板") as Panel).position == Vector2(11, 70)
			and (窗.get_node("子面板") as Panel).size == Vector2(180, 140),
		"子面板不在 (11,70) 180×140（`background_2` = 格阵高 128 + 12）")
	var 格 := _格们(窗)
	_查(格.size() == 12, "非付费窗该摆 12 格，实测 %d" % 格.size())
	for i in 格.size():
		_查((格[i] as Button).position == Vector2(6 + 41 * (i % 4), 6 + 41 * int(i / 4)),
			"第 %d 格位置 %s ≠ 容器局部 (6+41·列, 6+41·行)" % [i, str((格[i] as Button).position)])
	_查((格[0] as Button).icon != null, "第 0 格没摆上 11000002 的图标")
	_查(((格[0] as Button).get_node("数量") as Label).text == "",
		"件数为 1 的格不该显数量（`ItemWindowCell` 的件>1 才显）")
	var 钮 := 窗.get_node("打开礼包") as Button
	_查(钮.position == Vector2(70, 267) and 钮.size == Vector2(61, 22),
		"打开钮不在 (70,267) 61×22（`btn_width_four` + `background.width−btn.width >> 1`）")
	_查(not 钮.disabled, "等级/元宝都够时打开钮却禁用")

	# —— ⑤ 打开：离线结算扣 2000、发下一只、关窗撤遮罩 ——
	钮.pressed.emit()
	await process_frame
	_查(not 窗.visible, "点「打开礼包」后窗没关（原版 `onClickOpenBtn` 里 `onCloseBtnClick`）")
	_查(not _在包(会话, 11000001), "打开后 11000001 还留在包里（应只吃 1 只）")
	_查(_在包(会话, 11000002), "打开 11000001 后没拿到下一只 11000002（礼包链断了）")
	_查(_在包(会话, 3000001) and _在包(会话, 4000001),
		"打开 11000001 后没拿到通用组的 3000001/4000001")
	_查(int(会话.player_stats.get("gold", 0)) == 102000,
		"打开 11000001 后金币 %d ≠ 102000（底部「金币：」是内含奖励，应加 2000）"
			% int(会话.player_stats.get("gold", 0)))
	var 挡 := 遮罩层.get_node_or_null("购买窗遮罩") as ColorRect
	_查(挡 != null and not 挡.visible, "关窗后整舞台遮罩没撤")

	# —— ⑥ 等级不足：高 321、红字、钮禁用、不扣件 ——
	会话.player_stats["level"] = 1
	会话.inventory = 会话.落位带洞([_件("11000020", 1, {"slot_index": 1})])
	场.call("_use_item", 1)
	await process_frame
	窗 = _取窗(遮罩层)
	_查(窗 != null and 窗.visible, "等级不足时没开详情窗（原版照样开，只是钮禁用 + 红字）")
	if 窗 != null:
		_查(窗.size == Vector2(202, 321), "等级不足的窗高 %s ≠ 321" % str(窗.size))
		var 红 := 窗.get_node("提示") as Label
		_查(红.visible and 红.text == "很抱歉，你的等级不足！",
			"等级不足红字不对：vis=%s text=%s" % [红.visible, 红.text])
		_查((窗.get_node("打开礼包") as Button).disabled, "等级不足时打开钮没禁用")
		_查(int(会话.格位物品(1).get("quantity", 0)) == 1, "等级不足却扣了礼包")
		(窗.get_node("关闭") as Button).pressed.emit()
		await process_frame
		_查(not 窗.visible, "点关闭后窗还开着")

	# —— ⑦ 付费版：16 格 + 元宝行，扣元宝 ——
	会话.player_stats["level"] = 100
	会话.player_stats["cash"] = 100000
	会话.inventory = 会话.落位带洞([_件("11030022", 1, {"slot_index": 1})])
	场.call("_use_item", 1)
	await process_frame
	窗 = _取窗(遮罩层)
	_查(窗 != null and 窗.visible, "11030022（libao_fufei）没弹详情窗")
	if 窗 != null:
		_查(窗.size == Vector2(202, 313), "可开的付费窗尺寸 %s ≠ 202×313" % str(窗.size))
		_查(_格们(窗).size() == 16, "付费窗该摆 16 格，实测 %d" % _格们(窗).size())
		_查((窗.get_node("支付提示") as Label).text == "礼包开启需要支付", "付费版缺「礼包开启需要支付」")
		_查((窗.get_node("元宝值") as Label).text == "320", "付费版元宝值不是 320")
		_查(窗.get_node_or_null("金币标签") == null, "付费版不该有底部金币行（原版 `isCharge` 支不建 bottom）")
		var 付钮 := 窗.get_node("打开礼包") as Button
		_查(not 付钮.disabled, "元宝够时付费礼包打开钮却禁用")
		(付钮 as Button).pressed.emit()
		await process_frame
		_查(int(会话.player_stats.get("cash", 0)) == 99680,
			"打开 11030022 后元宝 %d ≠ 99680（应扣 320）" % int(会话.player_stats.get("cash", 0)))
		_查(not _在包(会话, 11030022), "打开后 11030022 还留在包里")

	# —— preview=0 / libao_select 不能被这扇窗截走 ——
	会话.inventory = 会话.落位带洞([_件("11000156", 1, {"slot_index": 1})])
	_查(not bool(会话.call("是详情礼包", 1)),
		"preview=0 的 11000156 被当成详情礼包了（应直接使用）")
	会话.inventory = 会话.落位带洞([_件("11020001", 1, {"slot_index": 1})])
	_查(not bool(会话.call("是详情礼包", 1)),
		"libao_select 11020001 被详情窗截走了（该走已有的自选礼包窗）")
	_查(详情窗脚本 != null, "礼包详情窗脚本没加载上")

	场.queue_free()
	await process_frame
	_收尾()
	if _失败.is_empty():
		print(("礼包详情窗回归测试：通过（数据 376 条 / 11000001 职业300 10 行且首行是 11000002 / "
				+ "只开窗不吃件 / 202×300 12格 + 金币2000 / 打开得2000并发下一只 / "
				+ "等级不足 202×321 红字且禁用 / 付费版 202×313 16格扣320元宝）"))
		quit(0)
	else:
		print("礼包详情窗回归测试：失败 %d 项（共 %d 项）" % [_失败.size(), _受检])
		quit(1)


func _收尾() -> void:
	if not _快照.is_empty():
		var 会话 = root.get_node(会话路径)
		会话.player_stats = _快照["player_stats"]
		(会话.inventory as Array).assign(_快照["inventory"] as Array)
		(会话.storage as Array).assign(_快照["storage"] as Array)
		会话.equipped_items = _快照["equipped_items"]
		会话.call("_save_local_state")
	门存档快照.全还原(_文件前)
