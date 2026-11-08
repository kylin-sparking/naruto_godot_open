extends SceneTree

## 「购买道具」窗**全局只该有一枚**的门（用户 2026-10-20 深夜实机报「购买道具页关不掉」）。
##
## 根因（修前实测，取证 = `开发工具/查购买窗关不掉.gd`）：`功能窗口.gd:417-418` 把 1079
## （商城单件详情）回包连到 `打开商城购买窗`，而**每一个开着的功能窗口都连了一遍**
## ⇒ 修行那两扇一起开着时，一发回包弹**两枚**一模一样的购买窗、叠在屏幕正中，
## 点掉上面那枚下面还压着一枚（而且上面那枚的 X 连按下都收不到）⇒ 看起来就是"关不掉"。
## 原版只有一个处理者：`Client.onCashItemInfo:7787-7791` → `UIMain2.addBuyWindow:2906-2913`
## 挂 `_windowMap[UIConfig.BUY_EQP_WINDOW]` 这**一个 key** ⇒ 天生一枚。
##
## 修法：谁发的 1086 谁接回包（`功能窗口._等1079` 旗 + `_收1079`），外加
## `窗口管理.收起其他购买窗` 兜一层（后弹的那枚把先弹的收掉，与原版"按 key 复用"同形）。
##
## 这道门只判**枚数与归属**（无头判得了）；"X 真点得掉"那两条要视口拾取，
## 留在有头的 `开发工具/查购买窗关不掉.gd`（**不能加 --headless**）。
##
## 跑法：Godot --headless --path . --script res://测试/购买窗全局一枚回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 页名 := "领取修行收益"
const 右页根 := "原版领取修行收益内容"
const 应判 := 6

var 红 := 0
var 判数 := 0
var 管: Node
var 后: Node


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	call_deferred("_跑")


func _判(对: bool, s: String) -> void:
	判数 += 1
	if not 对:
		红 += 1
		print("红   " + s)


func _帧(n: int) -> void:
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


func _取窗(页: String) -> Node:
	var 表: Variant = 管.get("_窗口们")
	if 表 is Dictionary and (表 as Dictionary).has(页):
		return (表 as Dictionary)[页] as Node
	return null


func _可见购买窗() -> Array:
	var 出: Array = []
	for 项 in root.find_children("商城购买窗", "", true, false):
		var 控 := 项 as Control
		if 控 != null and 控.visible:
			出.append(控)
	return 出


func _回一帧() -> void:
	后.cash_item_info_received.emit({"sn": 16000003, "id": "16000003", "name": "修行密卷",
			"price": 10, "money_type": 1, "desc": "在领取修行收益时选择使用此密卷，可以获得双倍的收益"})


func _跑() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _帧(60)
	管 = _找管理(场景)
	后 = root.get_node_or_null("BackendConnection")
	if 管 == null or 后 == null:
		_判(false, "找不到 窗口管理 或 BackendConnection ⇒ 后面全部判不了")
		_收()
		return
	管.打开(页名)
	await _帧(20)
	var 右 := _取窗(页名)
	var 伴名 := String(管.get("成对伴随").get(页名, ""))
	var 左 := _取窗(伴名)
	if 右 == null or 左 == null:
		_判(false, "成对开窗没开出来（右=%s 左=%s）⇒ 后面全部判不了" % [
				str(右 != null), str(左 != null)])
		_收()
		return

	## ① 举旗只举在**发请求的那一扇**上：走的就是玩家那颗「购买」背后的同一个出口。
	右.call("请求商城商品", "16000003")
	_判(bool(右.get("_等1079")) and not bool(左.get("_等1079")),
			"① 右窗发 1086 之后只有它举旗（右=%s 左=%s）" % [
			str(右.get("_等1079")), str(左.get("_等1079"))])

	## ② 一发 1079 回包 ⇒ 恰好一枚，而且挂在**举旗那扇**的遮罩下。
	_回一帧()
	await _帧(8)
	var 枚 := _可见购买窗()
	_判(枚.size() == 1, "② 一发 1079 之后可见的购买窗必须恰好 1 枚（实得 %d 枚：%s）" % [
			枚.size(), _名串(枚)])
	var 挂对 := false
	if 枚.size() >= 1:
		挂对 = (枚[0] as Node).get_parent() == (右 as Node).get_node_or_null("遮罩")
	_判(挂对, "③ 那一枚必须挂在**发请求的右窗**的遮罩下（实得 %s）" % (
			_路径((枚[0] as Node).get_parent()) if 枚.size() >= 1 else "〈一枚都没有〉"))

	## ④ 没举旗时再来一发 ⇒ 不许再叠一枚（原版按 key 复用，从来不叠）。
	_回一帧()
	await _帧(8)
	var 二次 := _可见购买窗()
	_判(二次.size() == 1, "④ 没再发请求时第二发回包不许叠第二枚（实得 %d 枚：%s）" % [
			二次.size(), _名串(二次)])

	## ⑤ 收起之后不留可见的那枚（"关得掉"的结构面；真点 X 那两条在有头量具里）。
	if 二次.size() >= 1:
		(二次[0] as Node).get_parent().get_parent().call("收起购买窗")
		await _帧(4)
	_判(_可见购买窗().is_empty(), "⑤ 调 `收起购买窗` 之后不该再有可见的购买窗（实得 %d 枚）" % (
			_可见购买窗().size()))

	## ⑥ 第二道防线：**两扇都举旗**（真机上就是连着点两处「购买」）时再发一帧，
	## 仍然只许一枚 —— 后弹的那枚要把先弹的收掉（`窗口管理.收起其他购买窗`，
	## 与原版"按 key 复用同一扇"同形）。②③④ 各自靠哪一层挡住，由变异实测点名：
	## 撤掉去重 ⇒ ②④⑥ 红；撤掉旗标 ⇒ ③ 红（归属跑到最后连上信号的那一扇）。
	右.set("_等1079", true)
	左.set("_等1079", true)
	_回一帧()
	await _帧(8)
	var 对 := _可见购买窗()
	_判(对.size() == 1, "⑥ 两扇都举旗时再发一帧，仍只许一枚（后弹的收掉先弹的；实得 %d 枚：%s）" % [
			对.size(), _名串(对)])
	_收()


func _收() -> void:
	if 判数 < 应判:
		红 += (应判 - 判数)
		print("红   只判了 %d 条，不足 %d 条 ⇒ 中间有段被运行期报错打断" % [判数, 应判])
	print("购买窗全局一枚回归测试：判 %d 条 / 红 %d 条" % [判数, 红])
	quit(0 if 红 == 0 else 1)
