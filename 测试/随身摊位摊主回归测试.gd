extends SceneTree
## 随身摊位**摊主侧**（#49）离线门：上行三条（上架 `1296:4:`／下架 `1296:6:`／改名 `1296:3:`）、
## 下行三条增量帧的消费者（`1296:2:` 加一条挂牌／`1296:3:` 摘一条／`1296:4:` 一条出售记录）、
## 上架确认窗（同一个 `StallUpShelfWindow` 的另一档）的四道判式，以及背包那一侧的两条腿
## （底部那颗「随身摊位」= 开关 + 一跳；「物品上架」模式下点背包格 = 上架这一件）。
## 逐件参照值手抄自 `真值/窗口/随身摊位窗.md` §②④⑤⑨，AS3 行号都在那，**不从被测场景反查**。
##
## 覆盖：① 摊主档开窗（`character_id == 摊主号`）⇒ 露 上架/下架/修改、摊名格换成可输入那一件
## ② 点「物品上架」= 模式开（钮按下 + 状态行）、再点 = 收
## ③ `MAX_NUM = 10` 那道**纯客户端闸**（服务端数都不数）
## ④ `背包落一件` 三道闸的**顺序**：满 10 在「不可交易」之前（`showUpShelfWindow:298-314`）
## ⑤ 上架档逐件矩形：两只价栏露面、两只价文隐、钮文字「上架」、标题「物品上架」
## ⑥ 四道判式逐条：两价都 0 / 金币超上限 / 元宝超上限 / 太便宜（**带确定回调**）
## ⑦ 正常上架 ⇒ `4:<类型>:<格>:<数量>:<金>:<宝>` 逐值 + 这扇自关 + 模式**留着**
## ⑧ 下架：没选中一字节不发／背包满只出状态行／正常发 `6:<uid>`
## ⑨ 改名：`洗摊名` 的梯子 + 四道判式（折过东西**回写不发帧**）+ 正常发 `3:<自己号>:<名>`
## ⑩ 三条增量帧各自的消费者（`2:` 只塞摊主自己那扇、`3:` 两档都摘、`4:` 记进那本进程级账）
## ⑪ 关随身摊位窗 ⇒ 模式与上架单一起收（`关窗清态`）
## ⑫ 尺寸表「摊位上架」= 166×186 整框、进 `居中弹`、不进 `伴随背包`
## ⑬ 背包那颗「随身摊位」：开着就收（不发帧）、没开就发 `2:<自己号>`
## ⑭ 上架模式下点背包格 ⇒ 走 `背包落一件`，**不弹物品菜单**
##
## ⚠ 本门**不碰 `user://`**：只喂帧、只点钮、只把窗内控件的字改一改，
##   不调任何 `_save_local_state()`／物品操作（要动 `会话.inventory` 的门是另一类）。
##
## 跑法：Godot --headless --path . --script res://测试/随身摊位摊主回归测试.gd

const 管理场景 := "res://场景/界面/窗口管理.tscn"
const 夹具路径 := "res://数据/界面/摆摊夹具.json"
const 尺寸表路径 := "res://数据/界面/窗口尺寸.json"
const 摊位窗 := preload("res://脚本/界面/窗口/摆摊/摊位窗.gd")
const 购买窗 := preload("res://脚本/界面/窗口/摆摊/购买确认窗.gd")
const 背包窗脚本 := preload("res://脚本/界面/窗口/背包窗口.gd")
const 可拖拽格脚本 := preload("res://脚本/界面/组件/可拖拽格.gd")
const 管理脚本 := preload("res://脚本/界面/窗口管理.gd")
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## 摊位窗页里摊主侧那三枚 + 摊名两件套（页局部 = AS3 − 29，同 §②）
const 摊主件 := {"上架钮": [129.0, 287.0, 61.0, 22.0], "下架钮": [195.0, 287.0, 61.0, 22.0],
				"修改钮": [186.5, 381.0, 37.0, 22.0]}
## 摊名输入那只 LineEdit 与只读 Label 同框（`摊名框` 是 125×21，两件都铺满）
const 摊名框尺 := [0.0, 0.0, 125.0, 21.0]
const 摊名字数 := 15					# `modifyHandler:383` 那句「不能超过15个字符」= 原版 maxChars
## 上架档两只输入框（`StallUpShelfWindow.as:258-267`/`:282-283`，与 `价1底`/`价2底` 同框）
const 价输入尺 := {"价1输入": [56.0, 76.0, 98.0, 21.0], "价2输入": [56.0, 100.0, 98.0, 21.0]}
const 价字数 := 9						# `maxChars = 9`，也正是 `MAX_MONEY` 九位数的来处

var 通过 := 0
var 失败 := 0
var 跑完了 := false
var 夹: Dictionary = {}
var 通知: Array = []


func _判(对: bool, 话: String) -> void:
	if 对:
		通过 += 1
	else:
		失败 += 1
		print("红：%s" % 话)


func _initialize() -> void:
	await _跑()
	if not 跑完了:
		失败 += 1
		print("红：门自己没跑完（协程中途报错），汇总行没打出来")
	quit(1 if 失败 > 0 else 0)


func _矩形(件: Control) -> Array:
	return [件.offset_left, 件.offset_top,
			件.offset_right - 件.offset_left, 件.offset_bottom - 件.offset_top]


func _近(实: Array, 参: Array) -> bool:
	if 实.size() != 4:
		return false
	for i in 4:
		if absf(float(实[i]) - float(参[i])) > 0.51:
			return false
	return true


func _开着(窗: Node) -> bool:
	if 窗 == null:
		return false
	var 遮 = 窗.get("_overlay")
	return 遮 != null and (遮 as CanvasItem).visible


## 按名字找页（⚠ `功能窗口` 的根是 CanvasLayer，别 `as Control` 取它）。
## 页面一律是 `_content` 的直接子件，但这里留一次递归兜底：换了嵌套层级也不该让门"找不到页"。
func _找页(窗: Node, 名: String) -> Control:
	var 内容 := 窗.get("_content") as Control
	if 内容 == null:
		return null
	for 子 in 内容.get_children():
		if String(子.name) == 名:
			return 子 as Control
	return 内容.find_child(名, true, false) as Control


func _喂(原文: String) -> void:
	root.get_node("BackendConnection").call("_handle_bridge_text", 原文)


## 某扇窗遮罩上那只「消息确认框」（`输入确认弹.弹消息` 的节点名）。
func _弹框(窗: Node) -> Control:
	var 遮 := 窗.get("_overlay") as Control
	if 遮 == null:
		return null
	return 遮.get_node_or_null("消息确认框") as Control


func _弹文(框: Control) -> String:
	if 框 == null:
		return ""
	return String((框.get_node("主体/正文") as RichTextLabel).get_parsed_text())


## 点掉某扇窗上那只模态弹的「确定」，把它收掉。
## ⚠ **每判完一句弹就必须收**：那层遮罩是 FULL_RECT + `MOUSE_FILTER_STOP`，
## 留着它再去 `_点在` 页面里的钮，点击会被暗层吃掉 ⇒ 下一句弹永远"没弹出来"，
## 看着像产品坏了一串，其实是上一枚弹没收。
func _收弹(窗: Node, 钮名 := "确定") -> void:
	var 框 := _弹框(窗)
	if 框 == null:
		return
	(框.get_node("主体/" + 钮名) as Button).pressed.emit()
	for i in 2:
		await process_frame


## 把这扇窗提到最前（`_置顶` 只改 CanvasLayer 层级，不重渲染页面）。
## ⚠ 无头门里**多扇窗叠着**时这是必须的：`push_input` 走的是真实 GUI 拾取，
## 被上面那扇窗（这里是背包）盖住的钮**点了静默没反应**。
func _置前(管理: Node, 名: String) -> void:
	管理.call("_置顶", 名)
	for i in 2:
		await process_frame


## 真鼠标点一下某个件（无头三门径：钉视口 / 先送 motion / position 与 global_position 都写）。
func _点在(件: Control) -> void:
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


func _红完就退(窗: Node, 名: String) -> bool:
	if 窗 == null:
		_判(false, "%s 没开出来 ⇒ 后面的判据无从跑起" % 名)
		跑完了 = true
		print("随身摊位摊主侧离线门：通过 %d，红 %d" % [通过, 失败])
		return true
	return false


## 假后端：只管**出帧**那半边（入帧走真后端，字段名一律与真后端同名）。
## ⚠ 别在这里覆写 `get()`（Godot 会当成覆写 `Object.get` ⇒ 整脚本 parse 失败）。
class 假后 extends Node:
	var character_id := 1002
	var authoritative_stall: Dictionary = {}
	var authoritative_bag_capacity := 90
	var authoritative_inventory: Array = []
	var authoritative_stats := {"money": 0, "cash": 0}
	var 挂过: Array = []
	var 摘过: Array = []
	var 改名过: Array = []
	var 开摊过: Array = []

	func request_stall_add_item(类型: int, 背包格: int, 数量: int, 金币: int, 元宝: int) -> bool:
		挂过.append([类型, 背包格, 数量, 金币, 元宝])
		return true

	func request_stall_remove_item(uid: int) -> bool:
		摘过.append(uid)
		return true

	func request_stall_rename(角色号: int, 摊名: String) -> bool:
		改名过.append([角色号, 摊名])
		return true

	func request_stall_open(owner_id: int) -> bool:
		开摊过.append(owner_id)
		return true


## 背包里那件"要上架的东西"。`type` 用的是**编码族号**（`ItemFactory.as:1049` 那个 category），
## 不是背包字典里那个中文 `category` —— 报文第 0 段要的就是它。
func 上架样品() -> Dictionary:
	var 路 := 游戏数据.item_icon_path(10000001)
	return {"id": "10000001", "name": "熊皮", "type": 2, "quantity": 5,
			"icon": 路, "can_trade": true, "price": 3000}


func _跑() -> void:
	print("随身摊位摊主侧离线门开始")
	await process_frame
	夹 = JSON.parse_string(去BOM(FileAccess.get_file_as_string(夹具路径))) as Dictionary
	_判(夹 != null and not 夹.is_empty(),
			"夹具读得到（先跑 `python 开发工具/出错摊夹具.py`）")
	if 夹 == null or 夹.is_empty():
		跑完了 = true
		print("随身摊位摊主侧离线门：通过 %d，红 %d" % [通过, 失败])
		return
	var 原 := String(夹["原文"])
	var 摊主号 := int(夹["摊主号"])
	var 后 = root.get_node("BackendConnection")
	后.set("in_game", false)
	后.set("authoritative_stall", {})
	root.size = Vector2i(960, 560)		# ⚠ 不钉视口，无头 push_input 拿不到 GUI 命中
	# 通知直接挂在 autoload `GameSession` 上：每一页各有一个 `功能窗口` 实例，
	# 但 `_session` 全是同一个 ⇒ 从根上连一次就够，别从窗口身上绕。
	var 会 = root.get_node_or_null("GameSession")
	_判(会 != null, "门跑之前 `GameSession` 这个 autoload 必须在（不然 `_通知` 那条判据是零覆盖）")
	if 会 != null:
		会.connect("notification_requested", func(话): 通知.append(String(话)))
	# ⚠ 摊主档的前提是**这一摊是我的** ⇒ 把真后端的角色号改成夹具里那个摊主号再喂帧
	#（`StallDataManager.as:29-37`：`owner_id == stats.id` 才走 `showMyStallWindow`）。
	后.set("character_id", 摊主号)
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	for i in 4:
		await process_frame
	_喂(原)
	var 状: Dictionary = 后.get("authoritative_stall") as Dictionary
	var 窗: Node = 管理._窗口们.get("随身摊位")
	if _红完就退(窗, "摊位窗（摊主档）"):
		return
	var 页 := _找页(窗, "原版随身摊位内容")
	if _红完就退(页, "摊位窗页本体"):
		return
	var 状签 := 窗.get("_status") as Label

	# ① 摊主档：三枚钮露、购买隐、摊名格换成可输入那一件、摊名行改排（`:452-468`+`:220`）
	_判((页.get_node("上架钮") as Button).visible and (页.get_node("下架钮") as Button).visible
			and (页.get_node("修改钮") as Button).visible
			and not (页.get_node("购买钮") as Button).visible,
			"摊主档露 上架/下架/修改、收「购买」（`showView(true)`）")
	for 名 in 摊主件:
		var 子 := 页.get_node_or_null(名) as Control
		_判(子 != null and _近(_矩形(子), 摊主件[名]),
				"摊主档 %s 矩形 = (%s)，实得 (%s)" % [名, 摊主件[名],
					_矩形(子) if 子 != null else "没建"])
	_判(absf((页.get_node("摊名框") as Control).position.x - 53.5) < 0.51
			and absf((页.get_node("修改钮") as Control).position.x - 186.5) < 0.51,
			"摊主档摊名行：框 x = (277−125−37−8)/2 = 53.5、钮 x = 186.5，实得 %.1f/%.1f" % [
				(页.get_node("摊名框") as Control).position.x,
				(页.get_node("修改钮") as Control).position.x])
	var 名文 := 页.get_node("摊名框/摊名文") as Label
	var 名框 := 页.get_node("摊名框/摊名输入") as LineEdit
	_判(名框.visible and not 名文.visible,
			"摊主档露的是可输入那一件、隐掉只读 Label（原版同一个 `MTextInput2` 只差 `enableInput`）")
	## ⚠ 这一件是 **full-rect 锚**（`anchors_preset = 15`）铺在 `摊名框` 里的，
	## 所以 `offset_*` 恒为 0 —— 量它必须用 `position`/`size`（布局算完的真实框），
	## 拿 `_矩形()`（读 offsets）会量出 (0,0,0,0)。其余件是 `layout_mode = 0`，两种读法等价。
	var 名尺 := [名框.position.x, 名框.position.y, 名框.size.x, 名框.size.y]
	_判(_近(名尺, 摊名框尺), "摊名输入铺满那个框，实得 (%s)" % [名尺])
	_判(名框.max_length == 摊名字数, "摊名输入 max_length = 15（`:383` 那句的控件版），实得 %d" % 名框.max_length)
	_判(名框.text == String(夹["摊名"]) and 名文.text == String(夹["摊名"]),
			"两件套都印着同一个摊名（`setStall:558` 一处写），实得「%s」「%s」" % [名框.text, 名文.text])
	_判((页.get_node("日志/日志文") as Label).text == 摊位窗.记录文(),
			"摊主档才把账本写进那一格（`:461` `showView(true)` 里那句 addLog）")

	# ② 点「物品上架」= 进模式；再点 = 收（`:621-624` / `hideCursor():443-449`）
	await _点在(页.get_node("上架钮") as Button)
	_判(摊位窗.上架模式 and (页.get_node("上架钮") as Button).button_pressed,
			"点「物品上架」⇒ 模式开、钮保持按下（实得 模式=%s 按下=%s）" % [
				str(摊位窗.上架模式), str((页.get_node("上架钮") as Button).button_pressed)])
	_判(状签.text == 摊位窗.上架提示, "进模式那句状态行 =「%s」，实得「%s」" % [摊位窗.上架提示, 状签.text])
	await _点在(页.get_node("上架钮") as Button)
	_判(not 摊位窗.上架模式 and not (页.get_node("上架钮") as Button).button_pressed,
			"再点一次 ⇒ 收（模式与钮视觉位**一起**收，别只改一个）")
	_判(状签.text == 摊位窗.退出提示, "收模式那句 =「%s」，实得「%s」" % [摊位窗.退出提示, 状签.text])
	## ⚠ 退出**不弹 `addNotice`**（原版 `hideCursor` 全文没有提示话）⇒ 这里断通知没多出一条。
	_判(通知.is_empty(), "进/退模式都不该发通知条（实得 %s）" % str(通知))

	# ③④ `MAX_NUM = 10` 那道客户端闸 + `背包落一件` 的闸序
	var 十条: Array = []
	for i in 10:
		var 复: Dictionary = (状["listings"] as Array)[0]
		十条.append(复.duplicate())
	var 原桶: Dictionary = 窗.get("_摊位桶")
	窗.set("_摊位桶", {"物品": 十条, "宠物": [], "货币": []})
	通知.clear()
	await _点在(页.get_node("上架钮") as Button)
	_判(not 摊位窗.上架模式, "挂满 10 条 ⇒ 点「物品上架」**不开模式**（`:618` 那一支在开之前）")
	_判(not (页.get_node("上架钮") as Button).button_pressed,
			"满 10 时钮**不许留在按下态**（`toggle_mode` 自己翻过位，得由 `_点上架` 收回）")
	_判(通知.size() == 1 and 通知[0] == 摊位窗.满, "满 10 那句话 = STALL_WINDOW_NOTICE_1（实得 %s）" % str(通知))
	# ④ 满闸在 canTrade 之前：挂满时点一件**绑定物**，原版弹的是「已达到限制」
	通知.clear()
	var 绑定 = 上架样品()
	绑定["can_trade"] = false
	摊位窗.背包落一件(窗, 绑定, 7)
	_判(通知.size() == 1 and 通知[0] == 摊位窗.满,
			"满 10 + 绑定物 ⇒ 先弹「已达到限制」（闸序：`:300-304` 数满、`:307-313` 才判交易）")
	_判(管理._窗口们.get("摊位上架") == null, "被闸拦下时**一扇窗都不该开**")
	窗.set("_摊位桶", 原桶)
	# canTrade 那一支自己（这次没满 ⇒ 走 `MDialog` 模态弹，不是 `addNotice`）
	通知.clear()
	摊位窗.上架模式 = true
	摊位窗.背包落一件(窗, 绑定, 7)
	var 绑框 := _弹框(窗)
	_判(绑框 != null and _弹文(绑框) == 摊位窗.不可交易,
			"绑定物那一句走的是**模态弹**（`:309-313` `showMessageDialog`），实得「%s」" % _弹文(绑框))
	_判(通知.is_empty() and 摊位窗.上架单.is_empty() and 管理._窗口们.get("摊位上架") == null,
			"绑定物：不追通知、不填上架单、不开窗（实得 通知=%s 上架单=%s）" % [str(通知), str(摊位窗.上架单)])
	if 绑框 != null:
		(绑框.get_node("主体/确定") as Button).pressed.emit()
		for i in 2:
			await process_frame
	_判(_弹框(窗) == null, "点完「确定」那只弹就该收掉")

	# ⑭ 上架模式下点背包格 ⇒ 走 `背包落一件`（原文 `onItemClick:440-444` 的**第一支**，不弹菜单）
	管理.call("打开", "背包")
	for i in 3:
		await process_frame
	var 包窗: Node = 管理._窗口们.get("背包")
	if _红完就退(包窗, "背包窗"):
		return
	var 包页 := _找页(包窗, "原版背包内容")
	if _红完就退(包页, "背包页本体"):
		return
	var 格: Button = 可拖拽格脚本.new()
	格.槽位号 = 7
	背包窗脚本._选中格子(包窗, 包页, 格, 上架样品())
	for i in 3:
		await process_frame
	_判(摊位窗.上架单.get("格") == 7
			and String((摊位窗.上架单.get("物品") as Dictionary).get("name", "")) == "熊皮",
			"点背包那一格 ⇒ 上架单收的是**这一格**（格号 7、熊皮），实得 %s" % str(摊位窗.上架单.keys()))
	var 上: Node = 管理._窗口们.get("摊位上架")
	if _红完就退(上, "摊位上架窗"):
		return
	_判(_开着(上), "点背包落一件 ⇒ 上架确认窗自己开出来（`dropValidateFun = showUpShelfWindow`）")
	_判(摊位窗.上架模式, "开完这一扇**模式仍留着**（原版光标还在，能连挂：`hideCursor` 只在换页/再点钮/关窗三支）")
	格.free()

	# ⑤ 上架档逐件：两只价栏露面、两只价文隐、钮文字「上架」、标题「物品上架」
	var 上架页 := _找页(上, "原版摊位购买内容")
	if _红完就退(上架页, "上架确认窗页本体"):
		return
	_判(absf(上架页.size.x - 166.0) < 0.51 and absf(上架页.size.y - 157.0) < 0.51,
			"页 = 166×157（整窗 186 − 标题 29），实得 %.0f×%.0f" % [上架页.size.x, 上架页.size.y])
	## ⚠ `数量标签`/`数量文` 挂在 `数量行` 底下，不是页的直接子件 ⇒ 这两件要带路径去找
	## （`购买窗.矩形` 那张表把两层的框列在一起，是因为 AS3 里它们本来就在同一条算式上）。
	for 名 in 购买窗.矩形:
		var 子 := 上架页.get_node_or_null(名) as Control
		if 子 == null:
			子 = 上架页.get_node_or_null("数量行/" + 名) as Control
		_判(子 != null and _近(_矩形(子), 购买窗.矩形[名]),
				"上架档 %s = (%s)，实得 (%s)" % [名, 购买窗.矩形[名],
					_矩形(子) if 子 != null else "没建"])
	for 名 in 价输入尺:
		var 件 := 上架页.get_node(名) as LineEdit
		_判(件.visible, "上架档 %s 露面（`:152` `enableInput` 那一支）" % 名)
		_判(件.max_length == 价字数, "%s max_length = 9（`maxChars`），实得 %d" % [名, 件.max_length])
	_判(not (上架页.get_node("价1文") as Label).visible
			and not (上架页.get_node("价2文") as Label).visible,
			"买家档那两只只读价文在上架档**隐掉**（同框换件，不是叠着露两层）")
	_判((上架页.get_node("确定钮") as Button).text == 购买窗.上架钮文字,
			"钮文字 =「%s」（`:135`），实得「%s」" % [购买窗.上架钮文字, (上架页.get_node("确定钮") as Button).text])
	_判(String(上.get("_title").text) == "物品上架",
			"标题走尺寸表「摊位上架」那条 =「物品上架」（`:136`），实得「%s」" % String(上.get("_title").text))
	_判((上架页.get_node("名称框/名称文") as Label).text == "熊皮"
			and (上架页.get_node("数量行/数量文") as Label).text == "5",
			"名称/数量填的是背包那一件（`:132` `_itemData = param1`），实得「%s」「%s」" % [
				(上架页.get_node("名称框/名称文") as Label).text,
				(上架页.get_node("数量行/数量文") as Label).text])
	_判((上架页.get_node("价1输入") as LineEdit).text == "0"
			and (上架页.get_node("价2输入") as LineEdit).text == "0",
			"两只价栏初值「0」是原文那两句（`:133-134`），不是占位符")
	_判((上架页.get_node("物品格/图标") as TextureRect).texture != null
			and (上架页.get_node("物品格/数量角标") as Label).text == "5",
			"格子里画的是背包那一件的图标 + 角标 5（`:121` `_icon.label`）")
	## 数字过滤：`restrict = "0-9"` ⇒ 打进去的字母被剔掉、剩下的数字留着。
	## ⚠ 只**过滤**、不**钳上限**（钳了 `MDIALOG_1/2` 那两句就永远弹不出来）。
	## ⚠ 必须把信号**直接发出去**：Godot 的 `件.text = "…"` 与 `insert_text_at_caret()` 
	##   都**不发 `text_changed`**（后者只挪光标、不触发校验，本工程实测过），
	##   而过滤件就挂在那个信号上 ⇒ 只能像玩家敲键那样 `emit` 一次，才算覆盖到真分支。
	var 金框 := 上架页.get_node("价1输入") as LineEdit
	金框.text = "1a2b3"
	金框.text_changed.emit("1a2b3")
	for i in 2:
		await process_frame
	_判(金框.text == "123", "价栏只留数字（`restrict \"0-9\"`），实得「%s」" % 金框.text)

	# ⑥ 四道判式逐条（**顺序照 `upShelf():196-223`**：都 0 → 金超 → 宝超 → 太便宜）
	## ⚠ 每一句弹判完都要 `_收弹` 把它按掉：那层遮罩 FULL_RECT + `MOUSE_FILTER_STOP`，
	##   留着它下一次 `_点在(确钮)` 会被暗层吃掉 ⇒ 后面三句全部"没弹出来"（假坏）。
	var 假 := 假后.new()
	假.character_id = 摊主号
	假.authoritative_stall = 状
	root.add_child(假)
	上.set("_backend", 假)
	var 宝框 := 上架页.get_node("价2输入") as LineEdit
	var 确钮 := 上架页.get_node("确定钮") as Button
	金框.text = "0"
	宝框.text = "0"
	await _点在(确钮)
	_判(假.挂过.is_empty() and _弹文(_弹框(上)) == 购买窗.价未填,
			"两格都是 0 ⇒「%s」且一帧不发（实得弹「%s」发=%s）" % [
				购买窗.价未填, _弹文(_弹框(上)), str(假.挂过)])
	await _收弹(上)
	## 十位数怎么进去：Flash 的 `maxChars` 只钳**打字**，`textField.text = "…"` 不钳；
	## Godot 的 `max_length` 连赋值一起钳（实测塞 10 位只留 9 位）⇒ 门先把 `max_length` 放开、
	## 填完再钉回 9。这里验的是**判式**（超限不发、值不钳），不是控件的钳位行为。
	金框.max_length = 0
	金框.text = "1000000000"
	await _点在(确钮)
	_判(假.挂过.is_empty() and _弹文(_弹框(上)) == 购买窗.金超,
			"金币超上限 ⇒「%s」且不发（数值留在框里让玩家自己改，`:202`）" % 购买窗.金超)
	_判(金框.text == "1000000000", "超限那句**不钳值**（钳成 999999999 就成了另一套语义），实得「%s」" % 金框.text)
	await _收弹(上)
	金框.max_length = 价字数
	金框.text = "0"
	宝框.max_length = 0
	宝框.text = "1000000000"
	await _点在(确钮)
	_判(假.挂过.is_empty() and _弹文(_弹框(上)) == 购买窗.宝超,
			"元宝超上限 ⇒「%s」且不发（`:207`）" % 购买窗.宝超)
	await _收弹(上)
	宝框.max_length = 价字数
	宝框.text = "0"
	# 太便宜：`price` 3000 ⇒ 门槛 1000；给 999 且元宝 0 ⇒ 弹一句**带确定回调**
	金框.text = "999"
	await _点在(确钮)
	var 便框 := _弹框(上)
	_判(假.挂过.is_empty() and _弹文(便框) == 购买窗.太便,
			"低于 `price/3` ⇒「%s」（`:212`），实得「%s」" % [购买窗.太便, _弹文(便框)])
	await _收弹(上, "取消")
	_判(假.挂过.is_empty(), "「太便宜」那句点**取消** ⇒ 不发（`:215` 的回调只在 OK 里发）")
	await _点在(确钮)
	_判(_弹文(_弹框(上)) == 购买窗.太便, "再点一次还是那一句（取消不等于退出上架）")
	await _收弹(上, "确定")
	_判(假.挂过.size() == 1, "「太便宜」那句点**确定** ⇒ 这才发（实发 %s）" % str(假.挂过))

	# ⑦ 正常一支：`4:<类型>:<格>:<数量>:<金>:<宝>` 逐值 + 这扇自关 + 模式留着 + 上架单清空
	## ⚠ 上一支（「太便宜」点确定）**已经把这扇关掉并清空了上架单**（`sureToUpShelf` 发完就自关）
	## ⇒ 这里必须重新走一遍「背包落一件」开**第二扇**，不能拿已经关掉的 `确钮` 再点一次
	##   （窗只藏不删 ⇒ 点了静默没反应，看着像发帧坏了）。
	假.挂过.clear()
	摊位窗.背包落一件(窗, 上架样品(), 7)
	for i in 3:
		await process_frame
	var 上二: Node = 管理._窗口们.get("摊位上架")
	if _红完就退(上二, "第二扇摊位上架窗"):
		return
	_判(_开着(上二) and 管理._窗口们.get("摊位购买") != 上二,
			"模式还开着 ⇒ 再点背包那一格又开出一扇上架窗（原版能连挂）")
	上二.set("_backend", 假)
	var 页二 := _找页(上二, "原版摊位购买内容")
	if _红完就退(页二, "第二扇的页本体"):
		return
	var 金二 := 页二.get_node("价1输入") as LineEdit
	var 宝二 := 页二.get_node("价2输入") as LineEdit
	_判(金二.text == "0" and 宝二.text == "0", "新开这扇两只价栏又是「0」（不是上一扇留下的 999）")
	金二.text = "1200"
	await _点在(页二.get_node("确定钮") as Button)
	for i in 4:
		await process_frame
	_判(假.挂过.size() == 1 and 假.挂过[0] == [2, 7, 5, 1200, 0],
			"发的是 `1296:4:2:7:5:1200:0`（类型=编码族号、格=背包格位），实得 %s" % str(假.挂过))
	_判(not _开着(上二), "发完这扇自己关掉（`sureToUpShelf:190 → onCloseBtnClick`）")
	_判(摊位窗.上架单.is_empty(), "发完把上架单清空（留着会拿上一件再发一遍）")
	_判(摊位窗.上架模式, "模式**不跟着收**（原版光标还在，能连挂第二件）")
	_判(_弹框(上二) == null, "正常那一支不该弹任何确认框")

	# ⑧ 下架：没选中一字节不发／背包满只出状态行／正常发 `6:<uid>`
	## ⚠ 先把摊位窗提回最前：⑭ 那一步把**背包**开在了它上面，而 `push_input` 走真实 GUI 拾取
	## ⇒ 被盖住的「下架／修改」点了静默没反应（这一段最先红成的就是这个原因）。
	await _置前(管理, "随身摊位")
	窗.set("_backend", 假)
	窗.set("_摊位选中", -1)
	await _点在(页.get_node("下架钮") as Button)
	_判(假.摘过.is_empty(), "没选中 ⇒ 点「下架」什么都不发（`:115` 那层 `if (_list.selectedItem)`）")
	窗.set("_摊位选中", 0)
	var 行表: Array = (原桶.get("物品", []) as Array)
	var 首个uid := int((行表[0] as Dictionary).get("uid", 0)) if 行表.size() > 0 else 0
	假.authoritative_bag_capacity = 5
	假.authoritative_inventory = [{}, {}, {}, {}, {}]
	状签.text = ""
	await _点在(页.get_node("下架钮") as Button)
	_判(假.摘过.is_empty() and 状签.text == 摊位窗.背包满,
			"背包满 ⇒ 不发、只出状态行那句「%s」（原版 `MessageTipPane2.TYPE_BAG_FULL`），实得「%s」" % [
				摊位窗.背包满, 状签.text])
	假.authoritative_bag_capacity = 90
	假.authoritative_inventory = []
	await _点在(页.get_node("下架钮") as Button)
	for i in 2:
		await process_frame
	_判(假.摘过.size() == 1 and int(假.摘过[0]) == 首个uid,
			"正常下架发 `1296:6:<挂牌uid=%s>`（**不带摊主号**，服务端只认发这跳的人自己那摊），实得 %s" % [
				首个uid, str(假.摘过)])
	_判(状签.text != "已发送，等待服务器确认" and not 状签.text.contains("下架成功"),
			"摘行由 `1296:3:` 驱动 ⇒ 发成功不许自己演成成功（实得「%s」）" % 状签.text)

	# ⑨ 改名：`洗摊名` 的梯子 + 四道判式 + 正常那一支发 `3:<自己号>:<名>`
	_判(摊位窗.许可码(97) and 摊位窗.许可码(20844) and 摊位窗.许可码(65293)
			and 摊位窗.许可码(12350) and not 摊位窗.许可码(128512) and not 摊位窗.许可码(31),
			"`isAllowedChar:410-413` 四段码区：拉丁/中日韩/全角/注音首段留、表情与控制符滤")
	_判(摊位窗.洗敏感词("系统官方澪") == "****澪",
			"两枚词各自换成**等长**的 `*`（不是删掉，`:415-441`），实得「%s」" % 摊位窗.洗敏感词("系统官方澪"))
	var 洗一: Array = 摊位窗.洗摊名("系统😀澪")
	_判(String(洗一[0]) == "**澪" and bool(洗一[1]) and bool(洗一[2]),
			"两种都动过 ⇒ [串, 洗过敏, 滤过特] = (%s)，实得 (%s)" % [str(["**澪", true, true]), str(洗一)])
	名框.text = ""
	通知.clear()
	await _点在(页.get_node("修改钮") as Button)
	_判(假.改名过.is_empty() and 通知 == [摊位窗.名空],
			"空名 ⇒「%s」且不发（`:361` 硬写那句），实得 %s" % [摊位窗.名空, str(通知)])
	名框.text = "😀😁"
	通知.clear()
	await _点在(页.get_node("修改钮") as Button)
	_判(假.改名过.is_empty() and 通知 == [摊位窗.名全特],
			"全是特殊字符 ⇒「%s」且不发（`:378`），实得 %s" % [摊位窗.名全特, str(通知)])
	## ⚠ 「16 个字」这一句在**原版也点不到**：`_input.textField.maxChars = 15`（`StallWindow.as:225`）
	## 先把打字拦在 15，`:383` 那道 `>15` 是防呆的第二层。Flash 的 `maxChars` 只钳打字、
	## 不钳 `textField.text =` 赋值，而 Godot 的 `max_length` 连赋值一起钳（实测 16 个只剩 15 个）
	## ⇒ 门这里临时放开钳位模拟"赋值进来的一条长名"，判完立刻钉回 15（场景里那个 15 才是真值）。
	名框.max_length = 0
	名框.text = "一二三四五六七八九十一二三四五六"
	通知.clear()
	await _点在(页.get_node("修改钮") as Button)
	_判(假.改名过.is_empty() and 通知 == [摊位窗.名超长],
			"16 个字 ⇒「%s」且不发（`:383`），实得 %s" % [摊位窗.名超长, str(通知)])
	名框.max_length = 摊名字数
	# 折过东西那一支：回写两件套、弹一句、**这一趟不发帧**（原文 `:386-402` 弹完直接 return）
	通知.clear()
	名框.text = "系统摊位"
	await _点在(页.get_node("修改钮") as Button)
	_判(假.改名过.is_empty() and 名框.text == "**摊位" and 名文.text == "**摊位",
			"折过敏感词 ⇒ 回写输入框与 Label、不发帧（`:398-406`），实得「%s」「%s」发=%s" % [
				名框.text, 名文.text, str(假.改名过)])
	_判(通知 == [摊位窗.名折敏], "折过那一句 =「%s」，实得 %s" % [摊位窗.名折敏, str(通知)])
	# 玩家**再点一次**才真发（这就是原文的语义，别替它省那一下）
	await _点在(页.get_node("修改钮") as Button)
	_判(假.改名过.size() == 1 and int(假.改名过[0][0]) == 摊主号
			and String(假.改名过[0][1]) == "**摊位",
			"再点一次 ⇒ 发 `1296:3:<自己号>:<洗过的名>`（角色号是 `stats.id`，不是 `_charId`），实得 %s" % str(假.改名过))

	# ⑩ 三条增量帧的消费者 —— 这半边换回**真后端**（入帧解析 + `窗口管理` 那两个 handler 都在真的一侧）
	窗.set("_backend", 后)
	var 负 := String((行表[0] as Dictionary).get("payload", ""))
	_喂("1296:2:7001:%d:2:1000:0:%s" % [摊主号, 负.replace("&", "@")])
	for i in 3:
		await process_frame
	var 桶二: Dictionary = 窗.get("_摊位桶")
	_判((桶二.get("物品", []) as Array).size() == (原桶.get("物品", []) as Array).size() + 1,
			"收到 `1296:2:`（自己那摊）⇒ 行 +1（`:80-86` `onStallAddItem` 塞的就是 `myStallWindow`）")
	_喂("1296:2:7002:9999:2:1000:0:%s" % 负.replace("&", "@"))
	for i in 3:
		await process_frame
	_判((窗.get("_摊位桶") as Dictionary).get("物品", []) == (桶二.get("物品", []) as Array),
			"摊主号不是我 ⇒ **不塞我这扇**（别人新挂一件，看到的还是点开那一瞬间的表）")
	_喂("1296:3:%d:5001" % 摊主号)
	for i in 3:
		await process_frame
	_判((窗.get("_摊位桶") as Dictionary).get("物品", []).size()
			== (原桶.get("物品", []) as Array).size(),
			"收到 `1296:3:` ⇒ 摘掉那一行、回到原有行数（`:65-78` 两档都调 `downShelf`）")
	_判((窗.get("_摊位行们") as Array).size() == (原桶.get("物品", []) as Array).size(),
			"摘行之后台上的行也少了（重排 = 原版末尾那句 `selectedBtnHandler(null)`）")
	var 记录前 := (摊位窗.摊日志 as Array).size()
	_喂("1296:4:山中井野:熊皮:1000:0")
	for i in 2:
		await process_frame
	_判((摊位窗.摊日志 as Array).size() == 记录前 + 1,
			"`1296:4:` 往**进程级**那本账追一行（`onStallTeadeLog:41-63` 只追不清），实得 %d 条" % (摊位窗.摊日志 as Array).size())
	var 记录 := String((摊位窗.摊日志 as Array)[(摊位窗.摊日志 as Array).size() - 1])
	_判(记录.contains("玩家山中井野购买了熊皮道具，获得了1000块金币和0个元宝"),
			"那句文案逐字 = STALLDATA_MANAGER_SAY（四个占位都填对），实得「%s」" % 记录)
	_判(记录.length() > 9 and 记录[2] == ":" and 记录[5] == ":"
			and 记录.left(2).is_valid_int() and 记录.substr(3, 2).is_valid_int(),
			"行首是**本地钟** HH:MM:SS（原版 `new Date()`，不是服务端时间），实得「%s」" % 记录.left(9))
	_判((页.get_node("日志/日志文") as Label).text == 摊位窗.记录文()
			and (页.get_node("日志/日志文") as Label).text.contains("山中井野"),
			"窗开着 ⇒ 那一格当场重写（买家档不写，见下一条）")
	# 买家档：同一条算式的另一半 —— 摊主号不是我 ⇒ 日志格恒空、三枚钮换「购买」
	# ⚠ 每次喂 `1296:1:` 那一条整帧，`_render_page` 都会**重建页面**（`重灌` 发现旧页已从 `_content`
	#   摘掉就走 `渲染`）⇒ 手上那只 `页` 立刻是**已释放实例**，必须重新按名字取。
	后.set("character_id", 摊主号 + 1)
	_喂(原)
	for i in 3:
		await process_frame
	var 页买 := _找页(窗, "原版随身摊位内容")
	_判(页买 != null, "换成买家档之后页还在（重灌走的是重建那一支）")
	if 页买 != null:
		_判(not (页买.get_node("上架钮") as Button).visible
				and (页买.get_node("购买钮") as Button).visible,
				"同一帧、只是「我」变了 ⇒ 三枚摊主钮换成「购买」（`showView(false)`）")
		_判((页买.get_node("日志/日志文") as Label).text == "",
				"买家档那一格恒空（原版只有 `showView(true)` 才 `addLog(stallLogs)`）")
	_判(摊位窗.记录文().contains("山中井野"), "但账本本身不清（进程级，切档不抹）")
	后.set("character_id", 摊主号)
	_喂(原)
	for i in 3:
		await process_frame

	# ⑪ 关窗 ⇒ 模式与上架单一起收（`关窗清态`；原版销毁整扇）
	摊位窗.上架模式 = true
	摊位窗.上架单 = {"物品": 上架样品(), "格": 9}
	窗.call("close")
	for i in 2:
		await process_frame
	_判(not 摊位窗.上架模式 and 摊位窗.上架单.is_empty(),
			"关掉随身摊位 ⇒ 上架模式与上架单一起收（实得 模式=%s 单=%s）" % [
				str(摊位窗.上架模式), str(摊位窗.上架单)])

	# ⑫ 尺寸表 / 居中弹 / 伴随背包
	var 表: Dictionary = JSON.parse_string(去BOM(FileAccess.get_file_as_string(尺寸表路径))) as Dictionary
	_判(表.has("摊位上架") and int(表["摊位上架"]["宽"]) == 166 and int(表["摊位上架"]["高"]) == 186
			and bool(表["摊位上架"]["整框"]) and String(表["摊位上架"]["标题"]) == "物品上架",
			"尺寸表「摊位上架」= 166×186、整框、标题「物品上架」（`:136`）")
	_判(int(表["摊位上架"]["宽"]) == int(表["摊位购买"]["宽"])
			and int(表["摊位上架"]["高"]) == int(表["摊位购买"]["高"]),
			"两档是**同一个 AS3 类** ⇒ 外框必须同尺寸（不许给上架档另立一套几何）")
	var 居: Dictionary = 管理脚本.居中弹
	var 随: Dictionary = 管理脚本.伴随背包
	_判(居.has("摊位上架"), "`摊位上架` 进 `居中弹`（`:83` `centerWindow(this,true)` 在构造里，两档共用）")
	_判(not 随.has("摊位上架") and not 随.has("随身摊位"),
			"两扇都不进 `伴随背包`（原版这两处没有 `centerTwoWindow`）")

	# ⑬ 背包底部那颗「随身摊位」：开着 ⇒ 只收窗、**一个包都不发**；没开 ⇒ 发 `2:<自己号>`
	包窗.set("_backend", 假)
	假.开摊过.clear()
	管理.call("打开", "随身摊位")
	for i in 3:
		await process_frame
	var 摊钮 := 包页.get_node("随身摊位") as Button
	_判(_开着(窗), "「打开」之后摊位窗在台上（这条是给下一条「开着就收」铺的前提）")
	## ⚠ 「随身摊位」那颗在**背包**页上 ⇒ 点之前要把背包提回最前，不然被刚开的摊位窗盖住。
	await _置前(管理, "背包")
	await _点在(摊钮)
	for i in 2:
		await process_frame
	_判(not _开着(窗) and 假.开摊过.is_empty(),
			"窗开着点它 = `setDOShow(MY_STALL_WINDOW,false)` ⇒ 只收窗、不发帧（实得发=%s）" % str(假.开摊过))
	await _点在(摊钮)
	for i in 2:
		await process_frame
	_判(假.开摊过 == [摊主号],
			"窗没开点它 = `viewStall(stats.id)` ⇒ 发 `1296:2:<自己号=%s>`（实得 %s）" % [摊主号, str(假.开摊过)])
	_判(not _开着(窗), "点它**当场不开窗**（原版开窗的是回帧；这里假后端只记不发，窗自然不该出现）")

	跑完了 = true
	print("随身摊位摊主侧离线门：通过 %d，红 %d" % [通过, 失败])


static func 去BOM(文: String) -> String:
	return 文.trim_prefix("﻿")
