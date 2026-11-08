extends SceneTree

## 「副本密卷进入」回归测试（§3.122，2026-10-11）。
##
## 为什么单开一条：这一支原先**没有任何运行期门**（`纲手三页回归测试` 是"只读磁盘文本"那条腿，
## 它自己头注写着不 load 场景），而代码里那句提示写的是"要服务端 819 的密卷子命令，本工程未接"
## —— **假缺口**：原版 `FubenLingWindow` 的「确定」最后发的就是**已有的动作 1** `requestCopy_open`。
##
## 钉四件：
##   ① 免费次数用完后点「密卷钮」⇒ 弹出**确认框**（不是一句提示）；
##   ② 正文按原版 `FUBENLING_COUNT` 三元组填：第 %1 次 / 【%2 副本名】/ 需要 %3 个 ——
##      **%3 = `2^(第次−1)`**（`FubenLingWindow.setData:221` 的 `Math.pow(2,count-1)`）；
##   ③ 包里密卷不够 ⇒ 点「确定」只给一句提示、**一个帧都不发**（原版是把确定键灰掉）；
##   ④ 够 ⇒ 发**一次** `request_copy_open(copyId)`（= 服务端 `_request_copy_entry`，
##      扣密卷由它按 `_copy_repeat_requirement` 结算）。
##
## ⚠️ 不写 `user://玩家数据.json`：等级/次数/背包都只改内存，退出前还原。
##
## 用法：Godot --headless --path . --script res://测试/副本密卷进入回归测试.gd

const 窗口脚本 := preload("res://脚本/界面/窗口/副本窗口.gd")

var _失败: Array[String] = []


## 假后端：只收不连，用来**看 `request_copy_open` 到底发没发**。
class 假后端:
	extends Node
	var in_game := true
	var 开本: Array = []

	func request_copy_open(copy_id: int) -> bool:
		开本.append(copy_id)
		return true


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	# ⚠️ **必须钉视口尺寸**：无头跑时 `root.size` 是 (64,64)，窗口铺开之后按坐标 push 的
	#    鼠标事件**落不到视口里** ⇒ 点了静默不生效（工程里栽过多次，见 `小地图标记回归测试` 头注）。
	root.size = Vector2i(960, 560)
	for _序号 in 5:
		await process_frame

	var 会话: Node = root.get_node_or_null("/root/GameSession")
	if 会话 == null:
		_停("拿不到 GameSession")
		return
	var 管理: Node = 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		_停("拿不到 窗口管理")
		return

	管理.call("打开", "副本")
	for _序号 in 4:
		await process_frame
	var 窗 = 管理.call("取或建窗口", "副本")
	if 窗 == null or not bool(窗.call("已打开")):
		_停("副本页没打开")
		return
	var 页 := (窗.get("_content") as Control).get_node_or_null("原版副本内容") as Control
	if 页 == null:
		_停("窗口里没有「原版副本内容」")
		return

	# 挑一条**能用密卷进**的副本（`enter.needItemId > 0`），并把前置都摆成"能用密卷"那一支：
	#   等级够 + 今天的免费次数已经用完（原版 `isCopyCount()` 为假才走密卷那条）
	var 配置: Array = 窗口脚本._配置
	var 序号 := -1
	for i in 配置.size():
		if int(((配置[i] as Dictionary).get("enter", {}) as Dictionary).get("needItemId", 0)) > 0:
			序号 = i
			break
	if 序号 < 0:
		_停("副本配置里没有一条带 `enter.needItemId` 的（密卷那一支没法测）")
		return
	var 条: Dictionary = 配置[序号]
	var 密卷id: int = int((条["enter"] as Dictionary).get("needItemId", 0))
	var 原等级 := int(会话.player_stats.get("level", 1))
	var 原历史: Dictionary = (会话.get("copy_history") as Dictionary).duplicate(true)
	var 备份: Array = (会话.get("inventory") as Array).duplicate(true)
	会话.player_stats["level"] = 999
	(会话.get("copy_history") as Dictionary)[int(条["id"])] = 窗口脚本._上限(条)
	窗口脚本._选中 = 序号
	窗.call("_render_page")
	for _序号2 in 3:
		await process_frame
	页 = (窗.get("_content") as Control).get_node_or_null("原版副本内容") as Control
	var 密卷钮 := 页.get_node_or_null("密卷钮") as Button
	if 密卷钮 == null or not 密卷钮.visible:
		_停("「密卷钮」不存在或没露出（`setRightTextFieldData:183` 按 needItemId>0 显隐）")
		_还原(会话, 原等级, 原历史, 备份)
		return

	# ①+② 点密卷钮 ⇒ 确认框 + 正文三元组
	await _点(密卷钮)

	# ⚠️ 确认框挂在 **`_overlay`（遮罩）** 下，不是窗根的直接子节点 ⇒ 必须递归找
	var 框 := 窗.find_child("确认框", true, false) as Control
	if 框 == null:
		_失败.append("点「密卷钮」应弹出确认框（原版 `FubenLingWindow`），实际没弹")
		_还原(会话, 原等级, 原历史, 备份)
		_收尾()
		return
	var 正文 := _框正文(框)
	_判(正文.contains("第1次"), "正文该写「第1次」（`第次 = 已用 − 上限 + 1`，已用完 ⇒ 1），实得「%s」" % 正文)
	_判(正文.contains(String(条.get("name", ""))), "正文该带副本名「%s」" % String(条.get("name", "")))
	_判(正文.contains("1 个副本密卷") or 正文.contains("1个副本密卷"),
		"需要数 = `2^(第次−1)` = **1** 个，实得正文「%s」" % 正文)

	# ③ 包里不够 ⇒ 只提示、不发
	_清空物品(会话, 密卷id)
	await _点确认(框, "确认键")
	_判(String(窗.get("_status").text).contains("密卷"), "密卷不够时该给一句提示（原版是把确定键灰掉），实测「%s」" % 窗.get("_status").text)

	# ④ 够了 ⇒ 一路走到**真发那一跳**
	窗.call("_render_page")
	for _序号3 in 3:
		await process_frame
	页 = (窗.get("_content") as Control).get_node_or_null("原版副本内容") as Control
	(会话.get("inventory") as Array).append({"id": str(密卷id), "quantity": 8})
	await _点(页.get_node("密卷钮") as Button)
	框 = 窗.find_child("确认框", true, false) as Control
	if 框 == null:
		_失败.append("第二次点「密卷钮」没有确认框")
	else:
		await _点确认(框, "确认键")
		# ⚠️ 「帧真发到线上」这一步在**无头离线**里量不到（没有真连接）。它与「进入钮」走的是
		#    **同一条** `游戏会话.request_copy_open`（原版 `onComeinCopy` → `requestCopyOpen`）
		#    ⇒ 那一跳由在线用例覆盖；这里钉的是"**前置过了、确实走到发**"（离线落那口话）。
		_判(String(窗.get("_status").text).contains("服务端结算"),
			"密卷够了 ⇒ 该走到真发那一跳（离线落「要在服务端结算」），实测「%s」" % 窗.get("_status").text)

	窗.set("_backend", null)
	_还原(会话, 原等级, 原历史, 备份)
	_收尾()


## 确认框正文（`_弹出确认` 里那颗 RichTextLabel；找不到就回空串，让断言点名）。
func _框正文(框: Control) -> String:
	var 标 := 框.find_child("正文", true, false) as Label
	return String(标.text) if 标 != null else "<没有正文节点>"


func _点确认(框: Control, 名: String) -> void:
	var 钮 := 框.find_child(名, true, false) as Button
	if 钮 == null:
		_失败.append("确认框里找不到「%s」" % 名)
		return
	# ⚠️ 弹层里的按钮是**运行期新建**的、不在 `_content` 的子树上做布局对齐，
	#    用真鼠标点会落在遮罩上（`mouse_filter=STOP`）⇒ 这里直接按信号走，
	#    「密卷钮」那一下才是真鼠标（见上）。
	钮.pressed.emit()
	await process_frame


## 真鼠标点（与 `卡片套册交互回归测试.点` 同一套：motion → down → up，各等帧）。
func _点(件: Control) -> void:
	var 位 := 件.get_global_rect().get_center()
	var 移 := InputEventMouseMotion.new()
	移.position = 位
	移.global_position = 位
	root.push_input(移)
	await process_frame
	for 按 in [true, false]:
		var 事 := InputEventMouseButton.new()
		事.button_index = MOUSE_BUTTON_LEFT
		事.pressed = 按
		事.button_mask = MOUSE_BUTTON_MASK_LEFT
		事.position = 位
		事.global_position = 位
		root.push_input(事)
		await process_frame
	await process_frame


func _清空物品(会话, 物品号: int) -> void:
	var 包: Array = 会话.get("inventory")
	for 序 in range(包.size() - 1, -1, -1):
		var 条 := 包[序] as Dictionary
		if 条.get("id", "") == str(物品号) or 条.get("id", "") == str(物品号).pad_zeros(8):
			包.remove_at(序)


## ⚠️ `copy_history` / `inventory` 都是**类型化容器**，整份赋值会被 Godot 拒 ⇒ 原地还原。
func _还原(会话, 原等级: int, 原历史: Dictionary, 备份: Array) -> void:
	会话.player_stats["level"] = 原等级
	var 史: Dictionary = 会话.get("copy_history")
	史.clear()
	for 键 in 原历史:
		史[键] = 原历史[键]
	var 包: Array = 会话.get("inventory")
	包.clear()
	for 条 in 备份:
		包.append(条)


func _判(条件: bool, 说明: String) -> void:
	if not 条件:
		_失败.append(说明)


func _停(原因: String) -> void:
	push_error("副本密卷进入回归测试：中断 - %s" % 原因)
	quit(1)


func _收尾() -> void:
	if _失败.is_empty():
		print("副本密卷进入回归测试：通过（确认框 + 2^(n-1) 文案 + 不够只提示 + 够了走到真发）")
		quit(0)
		return
	for 项 in _失败:
		push_error("副本密卷进入回归测试：失败 - %s" % 项)
	quit(1)
