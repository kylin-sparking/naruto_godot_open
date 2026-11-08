extends SceneTree

## 有头探针：**没密卷时点「双倍领取」→ 弹提示 → 点「确定」之后，游戏还响不响**。
##
## 为什么要它（用户 2026-10-22 午后实机：背包里没有修行密卷，点「双倍领取」弹出那句提示，
## 点「确定」之后**卡住**，附图是三扇窗都还挂在屏幕上）。
## 这一支的代码是 `系统窗口._claim_retreat_claim`（B4 = 原版 `LingquBiguanShouyi.drawShouyi:200-207`）：
## 缺卷 ⇒ `输入确认弹.弹消息(遮罩, "很抱歉,你的背包里没有修行密卷", 空回调)` 然后 **return**，
## 上行包根本不发。提示框本体 = `MDialog.showMessageDialog` 的移植，点「确定」走
## `遮罩层.queue_free()` ⇒ 理论上收掉就完了。所以"卡住"必须量出来是谁吞了输入：
## ① 提示框没收掉（残留一枚整屏 STOP）；② 收掉了但**别的**整屏 STOP 留在 `_overlay` 上；
## ③ 帧还在跑但真点什么都落不到件（= 上一条的表现）；④ 进程整个挂住（那这条腿会超时不退出）。
##
## 跑法（**不能加 --headless**，无头拿不到视口拾取）：
##   Godot --path . --script res://开发工具/量双倍领取卡住.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页名 := "领取修行收益"
const 右页根 := "原版领取修行收益内容"
const 密卷号 := "16000003"
## 每段必须钉满的条数（协程被运行期报错打断 ⇒ 后面整段没跑而末行照样打「红 0」）。
const 应判 := 7

var 上一鼠 := Vector2.ZERO
var 红 := 0
var 判数 := 0
var 次 := 0
var 关了 := false


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	call_deferred("_跑")


func _判(对: bool, s: String) -> void:
	判数 += 1
	if not 对:
		红 += 1
	print("%s %s" % ["ok  " if 对 else "红  ", s])


func _记(s: String) -> void:
	print("      %s" % s)


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


## 真鼠标点一枚钮，返回它的 `pressed` 被叫到几次。移鼠标分两跳（同帧两条 motion 视口只认最后一条）。
## ⚠ 计数走实例变量：闭包对局部变量按值捕获，局部 `var 次 := 0` + lambda 里自增 ⇒ 外面永远读到 0。
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
	## 引擎自己指到的那枚是谁 —— 按下落空时这一行直接分出"坐标错"还是"被别人盖住"。
	var 悬 := root.gui_get_hovered_control()
	_记("点 (%s) ⇒ 引擎悬停指到 %s（要的是 %s）" % [str(心),
			_路径(悬) if 悬 != null else "〈空〉", _路径(件)])
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


## 起手那一下容抖：成对开窗之后左页偶尔还在重排（实测有一轮悬停落在 `原版闭关窗口内容`
## 那枚页面根本身上、按下 0 次 —— 它的矩形当时不是窗框那么大）。
## **只给"把提示弹出来"这一步重试**：被判的那两下（提示框的确定、之后的单倍领取）一次都不重试，
## 重试会把要测的东西糊掉（`真事件要重试到钮真的收到` 这条只适用于投递抖，不适用于判据）。
func _点直到(件: Control, 最多: int) -> int:
	for 试 in 最多:
		if not is_instance_valid(件):
			_记("  第 %d 次尝试前那颗已被释放 ⇒ 不再重试" % (试 + 1))
			return 0
		var 得: int = await _点(件)
		if 得 > 0:
			return 得
		_记("  第 %d 下没落到那颗，再试一次（这一步只是把提示弹出来）" % (试 + 1))
	return 0


## 屏幕上**可见**的提示框（`弹消息` 那层，meta `mdialog` = "message"）。
func _可见提示框() -> Array:
	var 出: Array = []
	for 项 in root.find_children("*", "Control", true, false):
		var 控 := 项 as Control
		if 控 != null and 控.visible and String(控.get_meta("mdialog", "")) == "message":
			出.append(控)
	return 出


## 屏幕上**可见的整屏吞输入件**（宽≥视口宽、且 `mouse_filter` = STOP）——"卡住"的嫌疑人。
func _整屏遮罩() -> Array:
	var 出: Array = []
	var 屏 := Vector2(root.size)
	for 项 in root.find_children("*", "Control", true, false):
		var 控 := 项 as Control
		if 控 == null or not 控.is_visible_in_tree() or 控.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue
		var 框 := 控.get_global_rect()
		if 框.size.x >= 屏.x * 0.98 and 框.size.y >= 屏.y * 0.98:
			出.append(控)
	return 出


## 每扇开着的窗：它的 CanvasLayer 层号 + 主窗矩形。"确定点不到"到底是谁压上来，看这两列就够了。
func _层号(管: Node) -> void:
	var 表: Variant = 管.get("_窗口们")
	if not (表 is Dictionary):
		return
	for 页名 in (表 as Dictionary).keys():
		var 窗 := (表 as Dictionary)[页名] as CanvasLayer
		if 窗 == null or not bool(窗.call("已打开")):
			continue
		_记("  %s → layer=%d  窗口矩形=%s" % [页名, 窗.layer, str(窗.call("窗口矩形") as Rect2)])


func _跑() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _f(60)
	var 管 := _找管理(场景)
	if 管 == null:
		for i in 7:
			_判(false, "地图场景里找不到 窗口管理 ⇒ 后面全部判不了")
		_收()
		return
	管.打开(页名)
	await _f(20)
	var 领 := _取窗(管, 页名)
	var 页 := 领.get_node_or_null("遮罩/主窗口/页面容器/" + 右页根) as Control if 领 != null else null
	var 双倍 := 页.get_node_or_null("双倍领取") as Button if 页 != null else null
	if 双倍 == null:
		for i in 7:
			_判(false, "右页里查无「双倍领取」⇒ 后面全部判不了")
		_收()
		return

	## ── 夹具：把背包里的修行密卷**清干净**（用户报的就是"没有密卷"这一档）──
	var 会 := root.get_node_or_null("GameSession")
	if 会 == null:
		for i in 7:
			_判(false, "找不到 /root/GameSession ⇒ 密卷清不掉，后面全部判不了")
		_收()
		return
	var 留: Array = []
	var 摘掉 := 0
	for 物品 in 会.inventory:
		if String((物品 as Dictionary).get("id", "")) == 密卷号:
			摘掉 += 1
			continue
		留.append(物品)
	(会.inventory as Array[Dictionary]).clear()
	for 物品 in 留:
		(会.inventory as Array[Dictionary]).append(物品 as Dictionary)
	会.inventory_changed.emit(会.inventory)
	await _f(6)
	_记("夹具：从背包摘掉 %d 件密卷（摘完背包里 %d 件，密卷号=%s）" % [摘掉, 会.inventory.size(), 密卷号])
	_判(摘掉 > 0 or 会.inventory.size() >= 0, "夹具说话：密卷已清（摘掉 %d 件；本来就没有也算这一档成立）" % 摘掉)

	## ──  玩家第一下：真点「双倍领取」──
	_记("第一下之前的层序=%s" % str(管.get("_顺序")))
	_层号(管)
	## 两页**页面根节点**的实际矩形：它比窗框大 ⇒ 谁在最上就在谁那里吞掉窗外的点击
	## （实机表现为"同一页有时点得动、有时点不动"，取决于刚才点过哪扇窗）。
	for 项 in 管.get("_窗口们").keys():
		var 窗 := _取窗(管, String(项))
		var 容器 := 窗.get_node_or_null("遮罩/主窗口/页面容器") as Control if 窗 != null else null
		if 容器 == null or 容器.get_child_count() == 0:
			continue
		var 根 := 容器.get_child(0) as Control
		_记("  %s 页面根=%s 矩形=%s mouse_filter=%d" % [项, 根.name, str(根.get_global_rect()), 根.mouse_filter])
	var 第一 := await _点直到(双倍, 3)
	_判(第一 > 0, "真点「双倍领取」必须真的按下（实得 %d 次；0 = 这一页还是点不动，与「卡住」是两回事）" % 第一)

	## ── ② 缺卷 ⇒ 提示框必须弹出来（原版 `drawShouyi:204` 那句 showMessageDialog）──
	var 提 := _可见提示框()
	_判(提.size() == 1, "没有密卷时点双倍领取 ⇒ 屏幕上必须恰好一枚提示框（实得 %d 枚：%s）" % [
			提.size(), _名串(提)])
	if 提.is_empty():
		for i in 5:
			_判(false, "提示框一枚都没有 ⇒ 「点确定后卡住」判不了")
		_收()
		return
	var 框 := 提[0] as Control
	var 确定 := 框.get_node("主体/确定") as Button
	if 确定 == null:
		for i in 5:
			_判(false, "提示框里没有「确定」那颗 ⇒ 判不了")
		_收()
		return
	## 现场几何先打一遍：按下落不到那颗的时候，只有实际矩形说得清是"摆错"还是"被盖住"。
	_记("遮罩(_overlay) 尺寸=%s 可见=%s mouse_filter=%d" % [
			str((框.get_parent() as Control).size), str((框.get_parent() as Control).visible),
			(框.get_parent() as Control).mouse_filter])
	_记("提示框 遮罩层矩形=%s  z=%d" % [str(框.get_global_rect()), 框.z_index])
	_记("主体矩形=%s   确定矩形=%s   取消矩形=%s" % [
			str((框.get_node("主体") as Control).get_global_rect()),
			str(确定.get_global_rect()), str((框.get_node("主体/取消") as Control).get_global_rect())])
	_记("提示框挂在哪个宿主：%s  它的 CanvasLayer.layer=%d" % [
			_路径(框.get_parent().get_parent()),
			(框.get_parent().get_parent() as CanvasLayer).layer])
	_记("按下前的开窗顺序=%s" % str(管.get("_顺序")))
	_层号(管)

	## ── ③ 玩家第二下：真点提示框的「确定」──
	var 第二: int = await _点(确定)
	_记("按下「确定」之后：开窗顺序=%s" % str(管.get("_顺序")))
	_层号(管)
	_判(第二 > 0, "真点提示框的「确定」必须真的按下（实得 %d 次）" % 第二)
	await _f(8)
	var 残 := _可见提示框()
	_判(残.is_empty(), "点完「确定」提示框必须收掉（实得剩 %d 枚：%s）—— 还剩就是「卡住」的第一嫌疑人" % [
			残.size(), _名串(残)])

	## ── ④ 屏幕上不能再留"整屏吞输入"的隐形件（"卡住"的第二嫌疑人）──
	var 吞 := _整屏遮罩()
	_记("点完确定之后，整屏 STOP 的可见件：%s" % _名串(吞))
	_判(吞.size() <= 1, "整屏吞输入的可见件最多只该剩窗口层那一枚（实得 %d 枚：%s）" % [吞.size(), _名串(吞)])

	## ── ⑤ 硬判据：点完确定，游戏必须**还点得动**（再真点一次「单倍领取」）──
	var 单倍 := 页.get_node_or_null("单倍领取") as Button
	if 单倍 == null or not is_instance_valid(单倍):
		_判(false, "「单倍领取」查无或已被释放 ⇒ 响应性判不了")
	else:
		var 第三: int = await _点(单倍)
		_判(第三 > 0, "点完提示框的「确定」之后再点「单倍领取」必须还按得下（实得 %d 次；0 = 玩家说的「卡住」）" % 第三)
	_收()


func _收() -> void:
	if 判数 < 应判:
		红 += (应判 - 判数)
		print("红   只判了 %d 条，不足 %d 条 ⇒ 中间有段被运行期报错打断" % [判数, 应判])
	print("量双倍领取卡住：判 %d 条 / 红 %d 条" % [判数, 红])
	quit(0 if 红 == 0 else 1)
