extends SceneTree

## 「窗口永远压不到弹窗」的门（用户 2026-10-22 午后实机报「没密卷点双倍领取 ⇒ 弹提示 ⇒
## 点确定之后整屏卡住」）。
##
## 根因（修前实测，取证 = `开发工具/量双倍领取卡住.gd`）：`窗口管理._input:641-652` 在**每一次
## 左键按下**时把命中的那扇窗 `_置顶` —— 而 `_置顶` 会改每一扇宿主那个 CanvasLayer 的 `layer`。
## 提示框（`输入确认弹.弹消息` = 原版 `MDialog.showMessageDialog`）挂在**某一扇窗自己的 `遮罩` 里**
## ⇒ 玩家点「确定」那一点正落在**另一扇**窗的矩形里（提示框是屏幕正中，两扇窗一左一右），
## 于是按下的一瞬间把左边那扇提到 112、把带着提示框的右窗压回 111 ⇒
## ① 确定收不到按下（实测 `pressed 0`，而引擎悬停明明指着它）；
## ② 提示框那枚**整屏 STOP 的遮罩还在**，只是换到别的窗底下 ⇒ 之后点哪儿都不响应 = "卡住"。
##
## 原版为什么没这问题：`UIMain2.bringMWindowToTop:3693-3712` 把置顶目标索引钉在
## `max(0, getChildIndex(scrolledAnnouncePane) − 2)` —— **窗口置顶有上限，永远升不到弹窗之上**
## （弹窗由 `PopUpMananger.showWindow:74-108` 直接挂 `uiMain`，`showSwapDialog:1866-1873`
## 还要再 `setChildIndex(…, numChildren − 1)` 顶一次）。
## 我们的浮层挂在宿主自己的 `遮罩` 里 ⇒ 同一条不变量落成：**身上有浮层的那一扇，层号必须最大**
## （`功能窗口.有浮层()` + `窗口管理.重排层级()` + `功能窗口._bind_scene_nodes()` 那条入树连接）。
##
## 这道门判的是**层序与标记**（无头判得了）。"确定真点得掉、点完还点得动别处"那三条要视口拾取，
## 留在有头的 `开发工具/量双倍领取卡住.gd`（**不能加 --headless**）。
##
## 跑法：Godot --headless --path . --script res://测试/浮层不被压回归测试.gd

const 地图场景路 := "res://场景/地图/地图场景.tscn"
const 输入确认弹 := preload("res://脚本/界面/窗口/输入确认弹.gd")
const 页名 := "领取修行收益"
const 提示件 := "消息确认框"
const 浮层标记 := "overlay_popup"		# 与 `输入确认弹.浮层标记` 同一个键（这里要拿它做阳性对照）
const 应判 := 9

var 红 := 0
var 判数 := 0
var 管: Node


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


func _取窗(页: String) -> Node:
	var 表: Variant = 管.get("_窗口们")
	if 表 is Dictionary and (表 as Dictionary).has(页):
		return (表 as Dictionary)[页] as Node
	return null


## 开着的窗里层号最大的那一枚的名字。**并列最大也算红** —— 层号并列时 Godot 按创建顺序画，
## 谁在上面就不确定了（`窗口管理:615-626` 那条注释记的就是这个）。
func _最大层们() -> Array[String]:
	var 出: Array[String] = []
	var 最高 := -999999
	var 表: Variant = 管.get("_窗口们")
	if not (表 is Dictionary):
		return 出
	for 页 in (表 as Dictionary).keys():
		var 窗 := (表 as Dictionary)[页] as CanvasLayer
		if 窗 == null or not bool(窗.call("已打开")):
			continue
		if 窗.layer > 最高:
			最高 = 窗.layer
			出 = [String(页)]
		elif 窗.layer == 最高:
			出.append(String(页))
	return 出


func _层串() -> String:
	var 段: Array[String] = []
	var 表: Variant = 管.get("_窗口们")
	if not (表 is Dictionary):
		return "〈查无窗口表〉"
	for 页 in (表 as Dictionary).keys():
		var 窗 := (表 as Dictionary)[页] as CanvasLayer
		if 窗 == null or not bool(窗.call("已打开")):
			continue
		段.append("%s=%d" % [页, 窗.layer])
	return "、".join(段)


func _提示框(窗: Node) -> Control:
	var 遮 := 窗.get_node_or_null("遮罩") as Control
	if 遮 == null:
		return null
	var 找 := 遮.get_node_or_null(提示件) as Control
	return 找 if 找 != null and 找.is_visible_in_tree() else null


func _跑() -> void:
	var 场景: Node = (load(地图场景路) as PackedScene).instantiate()
	root.add_child(场景)
	await _帧(60)
	管 = _找管理(场景)
	if 管 == null:
		for i in 应判:
			_判(false, "找不到 窗口管理 ⇒ 后面全部判不了")
		_收()
		return
	管.打开(页名)
	await _帧(20)
	var 右 := _取窗(页名)
	var 伴名 := String(管.get("成对伴随").get(页名, ""))
	var 左 := _取窗(伴名)
	if 右 == null or 左 == null:
		for i in 应判:
			_判(false, "成对开窗没开出来（右=%s 左(%s)=%s）⇒ 后面全部判不了" % [
					str(右 != null), 伴名, str(左 != null)])
		_收()
		return

	## ① 基线：两扇的层号必须分得出高下（并列 ⇒ 后面几条都是在猜）
	var 基 := _最大层们()
	_判(基.size() == 1, "① 开窗之后层号最大的必须只有一枚（实得 %d 枚：%s｜%s）" % [
			基.size(), "、".join(基), _层串()])

	## ② 弹一枚提示框 ⇒ 带它的那一扇必须**立刻**被顶到最大层号
	## （`功能窗口._bind_scene_nodes()` 里那条 `child_entered_tree` ⇒ `重排层级`）
	var 弹 := 输入确认弹.弹消息(右.get("_overlay") as Control, "很抱歉,你的背包里没有修行密卷",
			func(_码: int) -> void: pass)
	await _帧(4)
	_判(弹 != null and is_instance_valid(弹) and bool(右.call("有浮层")),
			"② 提示框挂上右窗的遮罩之后 `有浮层()` 必须为真（实得 %s）" % str(bool(右.call("有浮层"))))
	var 后1 := _最大层们()
	_判(后1 == [页名], "③ 弹完提示框，带浮层的那一扇必须是层号最大的（实得 %s｜%s）" % [
			"、".join(后1), _层串()])

	## ④ **这条就是修的那一下**：模拟玩家点另一扇窗（`_input` 会 `_置顶` 那一扇）
	## ⇒ 带浮层的右窗不许被压回去（原版 `bringMWindowToTop` 那条上限）
	管.call("_置顶", 伴名)
	await _帧(4)
	var 后2 := _最大层们()
	_判(后2 == [页名], "④ 把另一扇窗置顶之后，带提示框的右窗仍必须是最大层（实得 %s｜%s）—— 这条红了就是玩家说的『点完确定整屏卡住』" % [
			"、".join(后2), _层串()])

	## ⑤⑥ 浮层收掉 ⇒ 保护必须**跟着撤**（否则这条规则会把层序钉死，别的窗再也提不上去）
	弹.queue_free()
	await _帧(6)
	_判(_提示框(右) == null and not bool(右.call("有浮层")),
			"⑤ 提示框收掉之后 `有浮层()` 必须回到假（实得 %s、可见框=%s）" % [
			str(bool(右.call("有浮层"))), str(_提示框(右) != null)])
	管.call("_置顶", 伴名)
	await _帧(4)
	var 后3 := _最大层们()
	_判(后3 == [伴名], "⑥ 没有浮层时把另一扇置顶就该它最大（实得 %s｜%s）" % [
			"、".join(后3), _层串()])

	## ⑦ 同一条保护要盖住**购买道具**那一族（它也是挂在 `遮罩` 上的整屏浮层，
	## 用户 10-20 那张图里"关不掉"的中间那扇就是它）
	右.call("打开商城购买窗", {"sn": 16000003, "id": "16000003", "name": "修行密卷",
			"price": 10, "money_type": 1, "desc": "在领取修行收益时选择使用此密卷"})
	await _帧(6)
	var 后4 := _最大层们()
	_判(bool(右.call("有浮层")) and 后4 == [页名],
			"⑦ 弹出购买道具窗之后也要被保护（有浮层=%s、最大层=%s｜%s）" % [
			str(bool(右.call("有浮层"))), "、".join(后4), _层串()])

	## ⑧ 只藏起来（`收起购买窗` = 玩家点 X 之后的状态）⇒ 不许还算浮层
	右.call("收起购买窗")
	await _帧(4)
	_判(not bool(右.call("有浮层")), "⑧ 购买窗收掉（只是 visible=false）之后 `有浮层()` 必须回到假（实得 %s）" % str(
			bool(右.call("有浮层"))))

	## ⑨ **阳性对照**：把标记摘掉 ⇒ 保护必须失效。少了这条，④⑦ 可能测的是一条恒真的路
	var 购买 := (右.get("_overlay") as Control).get_node_or_null("商城购买窗") as Control
	if 购买 == null:
		_判(false, "⑨ 阳性对照做不了：遮罩下查无购买窗节点")
	else:
		购买.set_meta(浮层标记, false)
		管.call("_置顶", 伴名)
		await _帧(4)
		var 后5 := _最大层们()
		_判(后5 == [伴名], "⑨ 摘掉浮层标记之后保护必须失效（实得最大层=%s｜%s）" % [
				"、".join(后5), _层串()])
	_收()


func _收() -> void:
	if 判数 < 应判:
		红 += (应判 - 判数)
		print("红   只判了 %d 条，不足 %d 条 ⇒ 中间有段被运行期报错打断" % [判数, 应判])
	print("浮层不被压回归测试：判 %d 条 / 红 %d 条" % [判数, 红])
	quit(0 if 红 == 0 else 1)
