extends SceneTree

## 人物装备格的点击语义（原版 `char/EquipPane.as`）：
##   单击有货格 = **弹菜单**（卸下/发到聊天框，`:254-289`）；双击 = 直接卸下（`:440-450`）；
##   Ctrl+单击 = 发到聊天框（`:239-243`）；空格子点了没反应。
## ⚠️ 我们原来"单击即卸"—— 比原版快一步、还丢了聊天入口。本轮改正。
##
## ⑥⑦⑧（2026-10-25 新加；⚠ 原注释标的「§3.281」是**误标** —— 那一节是数值字体回滚，与本条无关。
##   这批客户端改动当时没编年史条目，2026-10-28 随 §3.302 一起入库，条目待补 §3.304）
##   钉的是**两格多档**那半条，原版就写在同一段里：
##   · 灵器格里的开光十拳剑多「改变外观」（`:258-264` → `:469-471` 发 `2081:4`）—— 已实装，
##     菜单条件那半由 `十拳剑改变外观回归测试.gd` ① 盯着，本门只在 ⑥ 里钉"别污染"；
##   · 忍具格里的**八咫镜**（65000001 未开光 / 65000002 已开光）多四档「切换为火/水/雷/风抗」
##     （`:269-275` → `:472-483` 发 `2082:4:1..4`），**且双击这一格不是卸下**：
##     `:394-402` 先 `requestRenJuResistance(0)`（0 = 服务端按 `YATA_RESISTANCE_CYCLE` 轮下一档）
##     就 `return`。§3.76 把这条记成"后端没有"挂到今天 —— 服务端 `_switch_yata_resistance`
##     早就在，缺的只有客户端三处（菜单项、双击分流、上行），⑦⑧ 就是钉这三处不再退化。
## ⑨ 是两头口径钉：客户端 `RENJU_SWITCH_RESISTANCE` / 帧格式 与 服务端 `RenJuAction` /
##   `YATA_RESISTANCE_NAMES` 必须同一份号（1 火 2 水 3 雷 4 风），少一边改就会静默换错档。
##
## ⚠️ ⑦⑧ 要看**真发出去的帧** ⇒ 开场把 `/root/BackendConnection` 摘掉、换一枚同名的
##   `测试/测试后端连接.gd` 替身（继承真后端、只把 `send_game_request` 改成只记不发，
##   同 `商城开窗发包回归测试.gd:38-43` 的用法）。**替身保持 `in_game = false`**：
##   `游戏会话._online_backend():3881-3888` 认的就是这个字段 ⇒ ①~⑤ 那五条照旧走离线分支
##   （真改本地字典），只有 ⑦⑧ 的新上行落到 `sent_requests`。跑完把真 autoload 换回去。
##
## 两个都花过一轮学费的实测要点（都写在门里，别再踩）：
##   · **disabled 的 Button 用 `pressed.emit()` 照样会跑**（emit 绕过 `_can_click`），
##     而 headless 下 `push_input` **不驱动控件拾取**（`inject_event` 在 Window 上根本没有——
##     都记进了 `开发工具/Godot API 陷阱.md`）。两头都堵死的后果是"真点击"在无头门里做不到，
##     于是空格子那态改测**两层**：运行时挡住点击的是 `disabled` 字段本身 + 处理器的
##     `物品.is_empty()` guard（emit 直达 handler，正好单测这个 guard）。
##   · 装备/卸载变化会**触发会话信号 → 页面重建**，手里的 面板/菜单/格子 全部作废，
##     **每一步都要重新 find**（菜单点"卸下"的那一下尤其：先抓按钮、重建后 emit 的是死节点）。
##   · 两次单击之间要真等 >300ms，否则被双击检测吃掉（同帧连发 = "双击"）。

const 人物窗口脚本 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 装备部位表 := preload("res://脚本/单例/装备部位.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")
const 测试后端连接 := preload("res://测试/测试后端连接.gd")
const 忍具号 := "65000001"
## 原版菜单顺序（`EquipPane.as:274` 的数组顺序）与元素号（`:472-483` 的四发）。
const 抗序 := ["切换为火抗", "切换为水抗", "切换为雷抗", "切换为风抗"]

var _失败: Array[String] = []
var _受检 := 0
## ⚠️ 本门会真卸/真穿 ⇒ `unequip_item/equip_item` 各自 `_save_local_state()` **落盘 user://**。
##    第一版没做快照，跑一次就把玩家的离线存档改了一次（离线默认"武器穿着"被卸没了，
##    第二轮门直接前提红）。现在：开场快照、收尾**还原并再落盘一次**——门的净效果为零。
##    （`_save_local_state` 走应用自己的序列化，不是手摸文件；"不动 user://"的红线仍然成立。）
var _快照: Dictionary = {}
## 内存态还原后再 `_save_local_state()` 的**字节并不等于磁盘原文件** ⇒ 再加一层文件级快照。
const 门存档快照 := preload("res://测试/门存档快照.gd")
var _文件前 := {}
## ⑦⑧ 记账用的替身后端（`in_game` 恒 false，见文件头那条口径）。
## ⚠ `_替身` **不写类型**：`sent_requests` 是替身脚本上的字段，静态类型 `Node` 会让编译器
##   直接报"Cannot find property"（同 `人物窗口.gd:451` 记过的那类"静态类型挡住成员访问"）。
var _真后端: Node = null
var _替身 = null

func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_run")

func _check(ok: bool, 话: String) -> void:
	_受检 += 1
	if not ok:
		_失败.append(话)

func _run() -> void:
	var 会话 := root.get_node("/root/GameSession")
	_快照 = {
		"player_stats": (会话.player_stats as Dictionary).duplicate(true),
		"inventory": (会话.inventory as Array).duplicate(true),
		"equipped_items": (会话.equipped_items as Dictionary).duplicate(true),
	}
	_换替身后端()
	# ⚠️ **别拿"离线档里默认穿着武器"当前提**（本门原来的写法）。§3.258 把 `user://` 里
	#    那两件脏装备（`-1 竹制忍杖` / `-5 软铠护腰`）清掉了 ⇒ 下一轮全量这条前提直接不成立，
	#    红的不是代码是环境（`门读共享存档` 那一族，§3.166 同型）。和 ⑤ 同一味药：**自己种**。
	_种武器(会话)
	var 窗: Node = await _开窗()
	# ① 有货格真单击 ⇒ 弹菜单、不卸下
	var 状态 := await _取(窗)
	_check(_穿着(会话), "前提：① 开跑时武器位有货")
	_点(状态["格"] as Button, 窗)
	await process_frame
	状态 = await _取(窗)
	_check(bool(状态["菜单"].visible), "单击有货装备格应弹菜单（原版行为）")
	_check(_穿着(会话), "单击绝不能直接卸下（旧行为）")
	var 文案: Array[String] = []
	for 子在 in (状态["菜单"] as Control).get_children():
		var 按 := 子在 as Button
		if 按 != null and 按.visible:
			文案.append(按.text)
	_check(文案.has("卸下") and 文案.has("发到聊天框"), "菜单两项应是 卸下/发到聊天框（实际 %s）" % [文案])

	# ② 收起 → 隔 >300ms 再单击：仍是弹菜单，不触发双击
	(状态["菜单"] as Control).call("收起")
	await _慢()
	_点(状态["格"] as Button, 窗)
	await process_frame
	状态 = await _取(窗)
	_check(bool(状态["菜单"].visible), "隔开的第二次单击仍只是弹菜单")
	(状态["菜单"] as Control).call("收起")

	# ③ 双击 ⇒ 直接卸下、菜单收起
	await _慢()
	_点(状态["格"] as Button, 窗)
	_点(状态["格"] as Button, 窗)
	await process_frame
	_check(not _穿着(会话), "双击应卸下武器")
	状态 = await _取(窗)
	_check(not bool(状态["菜单"].visible), "双击后菜单应收起")

	# ④ 卸下后的空武器格：运行时靠 disabled 挡住（字段要 true），
	#    emit 直达 handler 也要被 `物品.is_empty()` guard 挡住（两层都在本条里钉）。
	_check(bool((状态["格"] as Button).disabled), "卸空后格子应 disabled（真点击被运行时挡）")
	_点(状态["格"] as Button, 窗)
	await process_frame
	状态 = await _取(窗)
	_check(not bool(状态["菜单"].visible), "空格子即使被直达也不该弹（handler 的 guard）")

	# ⑤ 重新穿上 → 弹菜单 → **真点击"卸下"按钮** → 卸下
	# ⚠️ ③ 那一下双击已经把武器卸回背包 ⇒ 这里只需再穿回去；但仍走同一个 `_种武器`
	#    （`equip_item` 是从**背包里找那件**再穿的，玩档不保证背包里有 01010011）。
	_种武器(会话)
	_check(_穿着(会话), "equip_item 应穿上（⑤ 的前提）")
	状态 = await _取(窗)
	_点(状态["格"] as Button, 窗)
	await process_frame
	状态 = await _取(窗)
	var 卸下钮 := _找钮(状态["菜单"] as Control, "卸下")
	if 卸下钮 == null:
		_失败.append("找不到可见的「卸下」按钮")
	else:
		_点(卸下钮, 窗)
		await process_frame
		_check(not _穿着(会话), "菜单点卸下应真的卸下")

	# ⑩ 菜单开着时来一帧库存（生产里任何 `MODIFY_INVENTORY_ITEM` 都会发这条信号）：
	#    页根不许重建 —— 菜单挂在页根下，重建会把它 free 掉，「卸下」那一下就落空。
	await _测菜单扛重建(会话, 窗)
	_测抗性菜单表()
	await _测抗性点击(会话, 窗)
	_测两头口径()

	_还原后端()
	_收尾()

## ── ⑩ 物品菜单开着时收到库存帧 ⇒ 整页重建必须推迟，等菜单收起再补 ────────────────
## 2026-11-01 用户报「装备栏的装备点卸下，无效」。真夹具 + 真鼠标探针实测：
##   开菜单 → 灌一帧 `inventory_changed` → 旧菜单已 free、新菜单 visible=false ⇒
##   点原来「卸下」的位置武器还在身上。机制在 `功能窗口._flush_refresh`：菜单是页根的子节点，
##   `_render_page()` 把它连同「已按下」一起 `remove_child + queue_free`。
## 本段钉两头：① 菜单开着时 `is_instance_valid` 必须还活着（不准重建）；② 收起后补的那次重建
## 不许丢（否则被推迟的刷新就永久丢了，页面停在旧数据）。
func _测菜单扛重建(会话, 窗: Node) -> void:
	await _慢()
	_种武器(会话)
	_check(_穿着(会话), "⑩ 前提：武器位有货")
	var 状态 := await _取(窗)
	_点(状态["格"] as Button, 窗)
	await process_frame
	状态 = await _取(窗)
	var 菜单 := 状态["菜单"] as Control
	var 面板 := 状态["面板"] as Control
	if 菜单 == null or not 菜单.visible:
		_失败.append("⑩ 前提：菜单没弹出来 ⇒ 这一条没量到")
		return
	# 生产帧：库存变更帧走的就是这条信号（`功能窗口.gd` 里它接 `_on_资源帧`）。
	会话.inventory_changed.emit((会话.inventory as Array).duplicate(true))
	for _i in 8:
		await process_frame
	_check(is_instance_valid(菜单) and 菜单.visible,
		"⑩ 菜单开着时来的库存帧**不许**重建页面（菜单会被 free，玩家的「卸下」就落空）")
	_check(is_instance_valid(面板), "⑩ 人物面板实例必须还是同一个（没被整页重建）")
	_check(_穿着(会话), "⑩ 这只是刷新帧，不该把武器弄丢")
	# ② 收起菜单 ⇒ 被推迟的那次重建要补上（旧面板实例应被替换）。
	if is_instance_valid(菜单):
		菜单.call("收起")
	for _i in 8:
		await process_frame
	_check(not is_instance_valid(面板),
		"⑩ 菜单收起后，被推迟的刷新必须补一次重建（否则页面停在旧数据）")
	# ③ 端到端：菜单开着被打断的那一下「卸下」要真的生效。
	await _慢()
	状态 = await _取(窗)
	_点(状态["格"] as Button, 窗)
	await process_frame
	状态 = await _取(窗)
	菜单 = 状态["菜单"] as Control
	var 卸下钮 := _找钮(菜单, "卸下") if 菜单 != null else null
	if 卸下钮 == null:
		_失败.append("⑩ ③ 找不到「卸下」按钮 ⇒ 端到端那条没量到")
		return
	会话.inventory_changed.emit((会话.inventory as Array).duplicate(true))
	for _i in 8:
		await process_frame
	_check(is_instance_valid(卸下钮), "⑩ ③ 刷新帧后「卸下」按钮节点必须还活着（同 ① 的菜单判据）")
	if is_instance_valid(卸下钮):
		卸下钮.pressed.emit()
		await process_frame
	_check(not _穿着(会话), "⑩ ③ 点「卸下」要真的卸下来（用户报的就是这一下没反应）")


## ── ⑥ 菜单表（纯函数）：四档只属于「忍具格 + 八咫镜」，顺序与号码照原版 ──────────
func _测抗性菜单表() -> void:
	for 号 in [忍具号, "65000002"]:
		var 镜 := 人物窗口脚本.装备菜单项(装备部位表.忍具, {"id": 号})
		_check(镜.size() == 6,
			"⑥ 忍具格里的 %s 该出六项（卸下/发到聊天框 + 四档），实得 %s" % [号, 镜])
		if 镜.size() != 6:
			continue
		_check(String(镜[0]) == 人物窗口脚本.卸下
				and String(镜[1]) == 人物窗口脚本.物品菜单组件.发到聊天框,
			"⑥ %s 的前两项仍是「卸下」「发到聊天框」（`EquipPane.as:274`），实得 %s" % [号, 镜])
		for i in 抗序.size():
			_check(String(镜[2 + i]) == 抗序[i],
				"⑥ %s 第 %d 档应是「%s」，实得「%s」⇒ 顺序就是原版数组顺序，别按拼音重排"
					% [号, 2 + i, 抗序[i], String(镜[2 + i])])
			var 元素 := int(人物窗口脚本.忍具抗性档.get(抗序[i], -1))
			_check(元素 == i + 1,
				"⑥「%s」该发元素号 %d（`onClickPopupMenu:472-483` = 火1/水2/雷3/风4），实得 %d"
					% [抗序[i], i + 1, 元素])
	# 整数形态也要认：服务端下发的 id 就是整数（`物品菜单.gd:107-114` 记着这条老坑）。
	_check(人物窗口脚本.装备菜单项(装备部位表.忍具, {"id": 65000001}).size() == 6,
		"⑥ 物品 id 是整数不是字符串时四档也要出（在线就是这个形态）")
	_check(人物窗口脚本.装备菜单项(装备部位表.忍具, {"id": "65000003"}).size() == 2,
		"⑥ 别的忍具（65000003）不许出四档：原版条件写死 65000001/65000002（`:272`）")
	_check(人物窗口脚本.装备菜单项(装备部位表.武器, {"id": 忍具号}).size() == 2,
		"⑥ 八咫镜挂在别的格（武器 -1）不该出四档")
	_check(人物窗口脚本.装备菜单项(装备部位表.灵器, {"id": "20200001"}).size() == 3,
		"⑥ 灵器那三项（含「改变外观」）不能被四档污染 —— 两条支是 `elif`，各归各的格")
	_check(人物窗口脚本.抗性轮档 == 0, "⑥ 双击那发是 0（轮下一档），原版 `:398` 写死")

## ── ⑦⑧ 真点击：六项弹出来、点一档只发一包不卸装、双击发 0 也不卸装 ──────────────
func _测抗性点击(会话, 窗: Node) -> void:
	_种忍具(会话)
	_check(_穿着槽(会话, 装备部位表.忍具), "⑦ 前提：八咫镜穿在忍具格上（`equip_item` 没穿上？）")
	# 原版这两支**一句本地提示都没有**（`onClickPopupMenu:472-483` 只发包；收端
	# `RenJuProcessor.handleRenJuOperationResult:65-73` 只 switch 0/3，压根没有 4 这一档）。
	# 判据取行为：从这两下点完到 ⑧ 结束，会话一句提示都不许发（离线没有服务端回帧 ⇒ 屏上该安静）。
	var 提示数 := [0]
	var 记账 := func(文本: String) -> void: 提示数[0] += 1
	会话.notification_requested.connect(记账)
	var 状态 := await _取(窗)
	var 镜格 := 状态["忍具格"] as Button
	if 镜格 == null:
		_失败.append("⑦ 场景里找不到「装备栏/装备格子容器/忍具格」⇒ 下面两条没地方点")
		return
	_替身.sent_requests.clear()
	_点(镜格, 窗)
	await process_frame
	状态 = await _取(窗)
	var 文案: Array[String] = []
	for 子在 in (状态["菜单"] as Control).get_children():
		var 按 := 子在 as Button
		if 按 != null and 按.visible:
			文案.append(按.text)
	_check(文案.size() == 6 and 文案[2] == 抗序[0] and 文案[5] == 抗序[3],
		"⑦ 真单击忍具格该弹出六项、四档齐全且按原版顺序，实得 %s" % [文案])
	var 雷钮 := _找钮(状态["菜单"] as Control, 人物窗口脚本.切换为雷抗)
	if 雷钮 == null:
		_失败.append("⑦ 菜单里没有可见的「切换为雷抗」⇒ 后面两条没东西可点")
	else:
		_替身.sent_requests.clear()
		_点(雷钮, 窗)
		await process_frame
		_check(_发了([{ "opcode": 2082, "content": "4:3" }]),
			"⑦ 点「切换为雷抗」只该发恰好一包 `2082:4:3`，实得 %s" % [str(_替身.sent_requests)])
		_check(_穿着槽(会话, 装备部位表.忍具),
			"⑦ 点抗性档**绝不能**把八咫镜卸下来（原版 `onClickPopupMenu` 里根本没有 unequip）")
	# ⑧ 双击：等过 300ms 再连点两下，走的是 `:394-402` 那支（发 0 轮档、不卸下）。
	await _慢()
	var 格2 := (await _取(窗))["忍具格"] as Button
	if 格2 == null:
		_失败.append("⑧ 页面重建后找不到忍具格")
		return
	_替身.sent_requests.clear()
	_点(格2, 窗)
	_点(格2, 窗)
	await process_frame
	_check(_发了([{ "opcode": 2082, "content": "4:0" }]),
		"⑧ 双击八咫镜该发恰好一包 `2082:4:0`（轮下一档），实得 %s" % [str(_替身.sent_requests)])
	_check(_穿着槽(会话, 装备部位表.忍具),
		"⑧ 双击八咫镜**不是卸下**（原版 `:398` 发完就 `return`，`unequip` 走不到）")
	状态 = await _取(窗)
	_check(not bool(状态["菜单"].visible), "⑧ 双击后菜单要收起（与 ③ 武器格同规）")
	会话.notification_requested.disconnect(记账)
	_check(int(提示数[0]) == 0,
		"⑦⑧ 点一档 + 双击轮档这两下**一句本地提示都不该发**（原版没有），实发 %d 条" % int(提示数[0]))

## ── ⑨ 两头口径钉：客户端与服务端的动作号/元素号必须是同一份 ────────────────────
func _测两头口径() -> void:
	var 客户 := _读文件("res://脚本/单例/后端连接.gd")
	_check("const RENJU_SWITCH_RESISTANCE := 4" in 客户,
		"⑨ `后端连接.gd` 里动作号常量必须写死 4（服务端 `RenJuAction.SWITCH_RESISTANCE = 4`）")
	_check("send_game_request(OP_RENJU, \"%d:%d\" % [RENJU_SWITCH_RESISTANCE, element])" in 客户,
		"⑨ 上行帧格式仍是 `4:<元素>` 两格（漏了元素号 ⇒ 服务端永远只读到 0、每下都轮档）")
	var 服务 := _读文件("res://服务端/runtime/tools/fake_flash_server.py")
	_check('YATA_RESISTANCE_NAMES = {1: "火", 2: "水", 3: "雷", 4: "风"}' in 服务,
		"⑨ 服务端元素名表还是 1 火 / 2 水 / 3 雷 / 4 风？改了这里就得回来重判 `忍具抗性档`")
	_check("SWITCH_RESISTANCE = 4" in 服务, "⑨ 服务端 `RenJuAction.SWITCH_RESISTANCE` 仍是 4")
	_check("self._switch_yata_resistance(fields)" in 服务,
		"⑨ 服务端 `handle_renju` 仍把动作 4 分派给 `_switch_yata_resistance`（不认了就是玩家点了没反应）")
	# 原版收端**没有** 4 这一档 ⇒ 客户端也不许冒出一个"等 2082:4 回帧"的消费者。
	# ⚠ 这条负钉**只框 `_发忍具抗性` 那 5 行**，不能对整份 `人物窗口.gd` 判：
	#    「已发送」在那个文件里本来就有 16 处（`_发请求` 那个 dispatcher 的局部变量名），
	#    整文件判第一次跑就恒红（2026-10-26 门自己撞出来的）。行为层 ⑦⑧ 已经钉过
	#    "这两下一句提示都不发"，这里补的是**源码层**那一刀：改这个函数的人最先被拦。
	var 发抗性 := _函数体(_读文件("res://脚本/界面/窗口/人物窗口.gd"), "_发忍具抗性")
	_check("request_renju_resistance" in 发抗性,
		"⑨ `_发忍具抗性` 要真的调上行，否则玩家点了六项里的四档等于死入口")
	_check("已发送" not in 发抗性 and "提示" not in 发抗性,
		"⑨ 忍具抗性这两支不许加本地占位提示（原版一句都不发，`RenJuProcessor:65-73` 只 switch 0/3）")

## 抠出某个函数从 `func 名字(` 起、到下一个 `func `/`static func `/`## ` 文档块为止的那段源码。
## 负向源码钉得先框住范围 —— 整文件判 `not in` 会把无关的同名文字算进来。
func _函数体(源码: String, 函数名: String) -> String:
	var 起 := 源码.find("func %s(" % 函数名)
	if 起 < 0:
		_失败.append("⑨ 源码里找不到 %s ⇒ 这一条没量到" % 函数名)
		return ""
	var 止 := -1
	for 标记 in ["\nfunc ", "\nstatic func ", "\n## "]:
		var 找 := 源码.find(标记, 起 + 1)
		if 找 > 0 and (止 < 0 or 找 < 止):
			止 = 找
	return 源码.substr(起, (止 - 起) if 止 > 0 else -1)

func _读文件(路径: String) -> String:
	var f := FileAccess.open(路径, FileAccess.READ)
	if f == null:
		_失败.append("⑨ 读不到 %s ⇒ 这一条没量到" % 路径)
		return ""
	return f.get_as_text()

## 替身收到的帧**恰好等于**给定的那一串（顺序、条数、opcode 与 content 全对）。
func _发了(期望: Array) -> bool:
	var 实 := _替身.sent_requests as Array
	if 实.size() != 期望.size():
		return false
	for i in 期望.size():
		var 一 := 实[i] as Dictionary
		var 望 := 期望[i] as Dictionary
		if int(一.get("opcode", -1)) != int(望["opcode"]) or String(一.get("content", "")) != String(望["content"]):
			return false
	return true

## 开场把真 autoload 换成替身（**必须在开窗之前**：`功能窗口._ready` 那时就抓 `/root/BackendConnection`）。
func _换替身后端() -> void:
	_真后端 = root.get_node_or_null("BackendConnection")
	if _真后端 == null:
		_失败.append("拿不到 BackendConnection 单例 ⇒ ⑦⑧ 没地方记帧")
		return
	root.remove_child(_真后端)
	_替身 = 测试后端连接.new()
	_替身.name = "BackendConnection"
	# ⚠ 别把它设成 true：一设就满足 `_online_backend()`，①~⑤ 的"卸下"改成只发包、
	#    本地字典不动 ⇒ 那五条全红（红得像是产品坏了）。
	_替身.in_game = false
	root.add_child(_替身)

func _还原后端() -> void:
	if _真后端 == null or _替身 == null:
		return
	root.remove_child(_替身)
	root.add_child(_真后端)

## 门自己把武器位弄成"有货"：**背包里没有就种一件，穿着位空着就穿上去**。
## ⚠️ 不做成 `async`：`equip_item` 是同步改字典 + 发信号，页面重建由下一步 `_取` 开头那帧吃掉；
##     helper 里一旦 `await`，调用点少写一个 `await` 就变成"协程对象被丢弃、什么都没干"（§3.227 同型坑）。
func _种武器(会话) -> void:
	var 有杖 := false
	for 件 in 会话.inventory:
		var 条 := 件 as Dictionary
		if not 条.is_empty() and String(条.get("id", 条.get("item_id", ""))) == "01010011":
			有杖 = true
			break
	if not 有杖:
		var 杖: Dictionary = (load("res://脚本/单例/游戏数据.gd").item("01010011") as Dictionary).duplicate(true)
		_check(not 杖.is_empty(), "种子的武器 01010011 从物品表里取得到")
		if not 杖.is_empty():
			会话.inventory.append(杖)
	if not _穿着(会话):
		会话.call("equip_item", "01010011")

## 把忍具格弄成"穿着八咫镜"：背包里没有就种一件，槽空着就穿上去（同 `_种武器`）。
## ⚠ 忍具这一族**不在** `数据/物品.json`（`游戏数据.gd:214-216` 回退到 `String/RenJu` 那份窄表），
##   那张记录里**没有 `id` 键** ⇒ 必须自己补上，`_inventory_index` 与 `是装备` 都读它。
func _种忍具(会话) -> void:
	var 有镜 := false
	for 件 in 会话.inventory:
		var 条 := 件 as Dictionary
		if not 条.is_empty() and String(条.get("id", 条.get("item_id", ""))) == 忍具号:
			有镜 = true
			break
	if not 有镜:
		var 镜: Dictionary = (游戏数据.忍具物品记录(忍具号) as Dictionary).duplicate(true)
		_check(not 镜.is_empty(), "⑦ 种子：忍具表里取得到 %s（取不到就是 `数据/忍具文案.json` 坏了）" % 忍具号)
		if 镜.is_empty():
			return
		镜["id"] = 忍具号
		镜["quantity"] = 1
		会话.inventory.append(镜)
	if not _穿着槽(会话, 装备部位表.忍具):
		会话.call("equip_item", 忍具号)

func _找钮(菜单: Control, 文字: String) -> Button:
	for 子在 in 菜单.get_children():
		var 按 := 子在 as Button
		if 按 != null and 按.visible and 按.text == 文字:
			return 按
	return null

## 无头门的"点"= 直接 emit（见文件头：headless 下没有能驱动拾取的真输入路径）。
## 对**有货格**这已是端到端（pressed → handler → 弹菜单/卸装）；对空格子它绕过了
## disabled，所以那一态另测 disabled 字段 + guard。
func _点(钮: Button, _窗: Node) -> void:
	钮.pressed.emit()

func _取(窗: Node) -> Dictionary:
	await process_frame
	var 面板: Control = 窗.find_child("原版人物属性面板", true, false)
	var 菜单: Control = null
	var 格: Button = null
	var 忍具: Button = null
	if 面板 != null:
		菜单 = 面板.get_parent().get_node_or_null("物品菜单") as Control
		格 = 面板.get_node_or_null("装备栏/装备格子容器/武器格") as Button
		忍具 = 面板.get_node_or_null("装备栏/装备格子容器/忍具格") as Button
	return {"面板": 面板, "菜单": 菜单, "格": 格, "忍具格": 忍具}

## ⚠️ `unequip_item` 是**留键置空**（`游戏会话.gd:499` `equipped_items[位置] = {}`）——
##    判"穿着没穿着"必须看**值空不空**，`has()` 会一直 true（本门第一版就栽在 `has` 上，
##    ③④⑤ 连环假红）。
func _穿着(会话) -> bool:
	return _穿着槽(会话, _武器位())

func _穿着槽(会话, 位置: int) -> bool:
	var 物 = 会话.equipped_items.get(位置, null)
	return 物 is Dictionary and not (物 as Dictionary).is_empty()

func _武器位() -> int:
	return int(load("res://脚本/单例/装备部位.gd").武器)

func _慢() -> void:
	await create_timer(0.4).timeout

func _开窗() -> Node:
	var 场景 := (load("res://场景/界面/功能窗口.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	await process_frame
	场景.call("open_page", "人物")
	for _i in 30:
		await process_frame
	return 场景

func _收尾() -> void:
	if not _快照.is_empty():
		var 会话 := root.get_node("/root/GameSession")
		会话.player_stats = _快照["player_stats"]
		# ⚠️ `inventory` 是 `Array[Dictionary]`：直接 `会话.inventory = _快照["inventory"]`（普通 `Array`）
		#    会 `Invalid assignment` **报错但不中断**、库存根本没还原（§3.196 同型坑）⇒ 走 `assign`。
		(会话.inventory as Array).assign(_快照["inventory"] as Array)
		会话.equipped_items = _快照["equipped_items"]
		会话.call("_save_local_state")
	# 文件级还原放在最后：`_save_local_state()` 重写的字节与原档不必一致。
	门存档快照.全还原(_文件前)
	if _失败.is_empty():
		print("装备格点击回归测试：通过（%d 条断言）" % _受检)
		quit(0)
		return
	for 项 in _失败:
		printerr("装备格点击回归测试：" + 项)
	quit(1)
