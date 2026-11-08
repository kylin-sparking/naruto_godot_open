extends SceneTree

## 有头探针：把玩家那条路走一遍 —— 点「购买」⇒ 弹「购买道具」⇒ **那颗 X 点得掉吗**。
##
## 为什么要它（用户 2026-10-20 深夜实机图：中间那扇「购买道具」关不掉）。修前实测两条：
## ① 一发 1079 回包 ⇒ **可见的购买窗 2 枚** —— 因为 `功能窗口.gd:417-418` 是**每个开着的宿主
##    各自**连的消费者，左窗那扇也弹一枚，两枚叠在同一个正中位置；
## ② 上面那枚的 X 收不到按下（`button_down 0 / button_up 0 / pressed 0`，而引擎悬停确实指到它）
##    ⇒ 玩家看到的就是"点了没反应、窗还在那儿"。
## 原版只有一个处理者：`Client.onCashItemInfo:7787-7791` → `UIMain2.addBuyWindow:2906-2913`
## 挂 `_windowMap[UIConfig.BUY_EQP_WINDOW]` 这**一个 key** ⇒ 天生一枚。
##
## 跑法（**不能加 --headless**，无头拿不到视口拾取）：
##   Godot --path . --script res://开发工具/查购买窗关不掉.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页名 := "领取修行收益"
const 右页根 := "原版领取修行收益内容"
## 每段必须钉满的条数（协程被运行期报错打断 ⇒ 后面整段没跑而末行照样打「红 0」）。
const 应判 := 5

var 上一鼠 := Vector2.ZERO
var 红 := 0
var 判数 := 0


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	call_deferred("_跑")


func _判(对: bool, s: String) -> void:
	判数 += 1
	if not 对:
		红 += 1
	print("%s %s" % ["ok  " if 对 else "红  ", s])


func _f(n: int) -> void:
	for i in n:
		await process_frame


func _找管理(节: Node) -> Node:
	if 节.get_script() != null and String(节.get_script().resource_path).ends_with("窗口管理.gd"):
		return 节
	for 子 in 节.get_children():
		var 得 := _找管理(子)
		if 得 != null:
			return 得
	return null


func _路径(节: Node) -> String:
	var 段: Array[String] = []
	var 当 := 节
	while 当 != null:
		段.push_front(当.name)
		当 = 当.get_parent()
	return "/".join(段)


func _名串(们: Array) -> String:
	var 段: Array[String] = []
	for 项 in 们:
		段.append(_路径(项 as Node))
	return "、".join(段)


func _取窗(管: Node, 页: String) -> Node:
	var 表: Variant = 管.get("_窗口们")
	if 表 is Dictionary and (表 as Dictionary).has(页):
		return (表 as Dictionary)[页] as Node
	return null


func _移(点: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = 点
	e.global_position = 点
	e.relative = 点 - 上一鼠
	上一鼠 = 点
	root.push_input(e)


## 真鼠标点一枚钮，返回它的 `pressed` 被叫到几次。移鼠标要分两跳：同一帧连发两条 motion
## 视口只按最后一条做拾取 ⇒ 大距离瞬移不触发 `mouse_entered`（这条坑踩过）。
## ⚠ 计数必须走**实例变量**：GDScript 的闭包对局部变量是**按值捕获**，
## 写成局部 `var 次 := 0` + lambda 里 `次 += 1` ⇒ 外面永远读到 0（我第一版就被它骗出两条假红）。
var 次 := 0
var 关了 := false


func _点(件: Control) -> int:
	次 = 0
	var 钮 := 件 as BaseButton
	if 钮 != null:
		钮.pressed.connect(func(): 次 += 1)
	var 心: Vector2 = 件.get_global_rect().get_center()
	_移(Vector2(8.0, 8.0))
	await _f(2)
	_移(心)
	await _f(3)
	var 按 := InputEventMouseButton.new()
	按.position = 心
	按.global_position = 心
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	按.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(按)
	await _f(2)
	var 抬 := 按.duplicate() as InputEventMouseButton
	抬.pressed = false
	抬.button_mask = 0
	root.push_input(抬)
	await _f(4)
	return 次


## 屏幕上**可见**的购买窗有哪几枚（枚数就是这条 bug 的判据）。
func _可见购买窗() -> Array:
	var 出: Array = []
	for 项 in root.find_children("商城购买窗", "", true, false):
		var 控 := 项 as Control
		if 控 != null and 控.visible:
			出.append(控)
	return 出


func _跑() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _f(60)
	var 管 := _找管理(场景)
	if 管 == null:
		_判(false, "地图场景里找不到 窗口管理 ⇒ 后面全部判不了")
		_收()
		return
	管.打开(页名)
	await _f(20)
	var 领 := _取窗(管, 页名)
	if 领 == null:
		_判(false, "查无「%s」窗 ⇒ 后面全部判不了" % 页名)
		_收()
		return
	var 页 := 领.get_node_or_null("遮罩/主窗口/页面容器/" + 右页根) as Control
	var 购买 := 页.get_node_or_null("购买") as Button if 页 != null else null
	if 购买 == null:
		_判(false, "右页里查无「购买」⇒ 后面全部判不了")
		_收()
		return

	## ① 玩家第一下：真点右页那颗「购买」（走 `功能窗口.请求商城商品` ⇒ 举 `_等1079` 旗 + 发 1086）。
	var 第一下: int = await _点(购买)
	_判(第一下 > 0, "真点右页「购买」必须真的按下（实得 %d 次；0 = 这一页还是点不动）" % 第一下)
	## ② 旗必须**只举在问的那一扇**上：成对叫出来的左窗不该跟着举。
	var 伴名 := String(管.get("成对伴随").get(页名, ""))
	var 伴 := _取窗(管, 伴名)
	var 伴旗 := "〈没开〉" if 伴 == null else str(bool(伴.get("_等1079")))
	_判(bool(领.get("_等1079")) and (伴 == null or not bool(伴.get("_等1079"))),
			"点「购买」之后只有右窗举了 1079 旗（右=%s 左(%s)=%s）" % [
			str(领.get("_等1079")), 伴名, 伴旗])

	## ③ 服务端回 1079（真机就是 `后端连接.gd:5064` emit 这一发）⇒ 只该弹**一枚**。
	## 离线这发 1086 并不真出去（`request_cash_item_info` 回 false），所以回包只能自己喂；
	## 旗在 `请求商城商品` 里已经举好，这里**不再**手动举（举了就是夹具替代码圆谎）。
	var 后 := root.get_node_or_null("BackendConnection")
	if 后 == null:
		_判(false, "找不到 /root/BackendConnection ⇒ 枚数判不了")
		_判(false, "同上：X 判不了")
		_判(false, "同上：残留判不了")
		_收()
		return
	后.cash_item_info_received.emit({"sn": 16000003, "id": "16000003", "name": "修行密卷",
			"price": 10, "money_type": 1, "desc": "在领取修行收益时选择使用此密卷，可以获得双倍的收益"})
	await _f(8)
	var 枚 := _可见购买窗()
	_判(枚.size() == 1, "一发 1079 回包之后，屏幕上可见的购买窗必须恰好 1 枚（实得 %d 枚：%s）" % [
			枚.size(), _名串(枚)])
	if 枚.is_empty():
		_判(false, "一枚都没有 ⇒ 根本没弹出来，与「关不掉」是两回事")
		_判(false, "同上：X 点不点得动判不了")
		_收()
		return
	var 窗 := 枚[0] as Control
	var X := 窗.get_node_or_null("关闭") as Button
	if X == null:
		_判(false, "购买窗里没有「关闭」那颗 ⇒ 判不了")
		_判(false, "同上：残留判不了")
		_收()
		return
	## ④ 玩家第二下：真点那枚 X ⇒ 发出「关闭了」，并且屏幕上不再留一枚。
	关了 = false
	窗.关闭了.connect(func(): 关了 = true)
	var 第二下: int = await _点(X)
	_判(第二下 > 0 and 关了, "真点购买窗的 X ⇒ 按下要落到那颗（实得 %d 次）并发出「关闭了」（实得 %s）" % [
			第二下, str(关了)])
	var 剩 := _可见购买窗()
	_判(剩.is_empty(), "点一次 X 之后屏幕上不能再有可见的购买窗（实得剩 %d 枚：%s）—— 还剩就是「关不掉」" % [
			剩.size(), _名串(剩)])
	_收()


func _收() -> void:
	if 判数 < 应判:
		红 += (应判 - 判数)
		print("红   只判了 %d 条，不足 %d 条 ⇒ 中间有段被运行期报错打断" % [判数, 应判])
	print("查购买窗关不掉：判 %d 条 / 红 %d 条" % [判数, 红])
	quit(0 if 红 == 0 else 1)
