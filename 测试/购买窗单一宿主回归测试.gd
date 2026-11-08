extends SceneTree

## 全局弹窗（1079 商品详情 ⇒ 商城购买窗）**只该由最上层那扇窗弹一枚**。
##
## 真事（用户 2026-10-16 实机报）：背包扩充里买过一张扩充券、**再买一次就卡住**。
## 根因：`功能窗口` 是**每页一个实例**、**各有自己的 `遮罩`**，而 1079 是**每个实例都接了**
## （`功能窗口.gd` 的 `_backend.cash_item_info_received.connect(…)`）⇒ 一次回包叠出
## **N 枚购买窗 + N 层遮罩**；玩家关掉看得见的那一枚后，**剩下的遮罩继续吃点击**
## （黑 α0.3、`mouse_filter = STOP`）⇒ 整屏像卡死。第一次没事只是"当时只开着一扇窗"。
##
## 这条门钉两件事：
##   ① 开 N 扇窗 + 一条 1079 ⇒ **恰好 1 枚购买窗、恰好 1 层可见遮罩**；
##   ② **关掉之后全场景一层可见遮罩都不许剩** —— 这才是"卡不卡死"的真正判据
##      （只钉"弹出来了"是钉不住这个 bug 的：修之前它也会弹，只是弹了 N 份）。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")
const 默认地图 := "101010000"
const 购买窗遮罩名 := "购买窗遮罩"

var _failures: Array[String] = []
var _已记 := 0


func _initialize() -> void:
	call_deferred("_run")


func _记(条件: bool, 说明: String) -> void:
	_已记 += 1
	if not 条件:
		_failures.append(说明)


func _run() -> void:
	root.size = Vector2i(960, 560)
	var 打包 := load(地图资源.playable_scene_path(默认地图)) as PackedScene
	if 打包 == null:
		_失败("加载不了烘焙地图场景")
		return
	var 场景 := 打包.instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(5):
		await process_frame

	var 后端 := root.get_node_or_null("BackendConnection")
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 后端 == null or 管理 == null:
		_失败("依赖节点不完整（BackendConnection / 窗口管理）")
		return

	# 开三扇窗（模拟"玩家已经开过几扇窗了" —— 正是复发时的现实）
	for 页 in ["背包", "人物", "商城"]:
		管理.call("打开", 页)
		await process_frame
	var 实例 := _窗口实例们(管理)
	_记(实例.size() >= 3, "只建出 %d 扇窗，样本不够" % 实例.size())

	var 商品 := {"sn": 9001, "id": "16000004", "name": "扩充密卷", "price": 100, "now_price": 100}
	后端.emit_signal("cash_item_info_received", 商品)
	await process_frame
	await process_frame

	# ① 恰好一枚 / 恰好一层
	var 窗数 := 0
	var 遮罩数 := 0
	for 窗 in 实例:
		var 遮 := 窗.get_node_or_null("遮罩") as Control
		if 遮 == null:
			continue
		var 购买窗 := 遮.get_node_or_null("商城购买窗") as Control
		if 购买窗 != null and 购买窗.visible:
			窗数 += 1
		var 罩 := 遮.get_node_or_null(购买窗遮罩名) as Control
		if 罩 != null and 罩.visible:
			遮罩数 += 1
	_记(窗数 == 1, "一次 1079 弹出了 %d 枚商城购买窗（应为 1 —— 每实例各弹一枚就会叠）" % 窗数)
	_记(遮罩数 == 1, "一次 1079 铺了 %d 层可见遮罩（应为 1 —— 多出来的层会一直吃点击＝卡死）" % 遮罩数)

	# ② 关掉之后：全场景不许剩可见遮罩（**这才是"卡不卡死"的真判据**）
	var 购买窗 := _找购买窗(实例)
	if 购买窗 == null:
		_失败("找不到那枚商城购买窗，后面的关闭判据没法做")
		_收尾()
		return
	购买窗.call("隐藏")
	await process_frame
	var 残留 := 0
	for 窗 in _窗口实例们(管理):
		var 遮 := 窗.get_node_or_null("遮罩") as Control
		if 遮 == null:
			continue
		var 罩 := 遮.get_node_or_null(购买窗遮罩名) as Control
		if 罩 != null and 罩.visible:
			残留 += 1
	_记(残留 == 0, "购买窗关掉后还留着 %d 层可见遮罩 —— 玩家点哪儿都没反应（＝卡死）" % 残留)

	# ③ **再开一次**：遮罩必须仍压在窗**下面**。
	#    第二次最容易翻车：`move_child(子, i)` 是**先摘后插**，若遮罩原本在窗**前面**，
	#    摘掉它会让窗前移一格 ⇒ 再按旧下标插回去，遮罩就落到窗上面了
	#    ⇒ 黑 α0.3 盖着窗＝**看着发灰、点哪儿都被遮罩吃掉**（用户实机报的正是"第二次进购买界面就变灰"）。
	后端.emit_signal("cash_item_info_received", 商品)
	await process_frame
	await process_frame
	var 宿主 := _找宿主(实例)
	if 宿主 == null:
		_失败("第二次发 1079 之后没弹出购买窗")
	else:
		var 遮 := 宿主.get_node_or_null("遮罩") as Control
		var 窗2 := 遮.get_node_or_null("商城购买窗") as Control if 遮 != null else null
		var 罩2 := 遮.get_node_or_null(购买窗遮罩名) as Control if 遮 != null else null
		_记(窗2 != null and 窗2.visible, "第二次开之后购买窗没显示")
		_记(罩2 != null and 罩2.visible, "第二次开之后遮罩没显示")
		if 罩2 != null and 窗2 != null:
			_记(罩2.get_index() < 窗2.get_index(),
				"第二次开时**遮罩跑到窗上面了**（罩 idx=%d / 窗 idx=%d）—— 窗会发灰、点不动"
					% [罩2.get_index(), 窗2.get_index()])
	_收尾()


func _窗口实例们(管理: Node) -> Array[Node]:
	var 出: Array[Node] = []
	for 子 in 管理.get_children():
		if 子.has_method("设为单页"):
			出.append(子)
	return 出


## 哪个实例的遮罩上挂着**可见**的购买窗（＝这次是谁弹的）。
func _找宿主(实例: Array[Node]) -> Node:
	for 窗 in 实例:
		var 遮 := 窗.get_node_or_null("遮罩") as Control
		if 遮 == null:
			continue
		var 购买窗 := 遮.get_node_or_null("商城购买窗") as Control
		if 购买窗 != null and 购买窗.visible:
			return 窗
	return null


## ⚠️ 必须找**可见**的那一枚（同 `_找宿主`）：一发 1079 每个宿主都会建出一枚，
## `收起其他购买窗` 只把别人那枚 `visible = false`。按"第一个有节点的"取会拿到
## 先建后被收掉的那枚，`隐藏()` 见它已不可见直接 return ⇒ 真正亮着的那层遮罩永远不落
## ⇒ 门报"关掉后还留着 1 层"（2026-10-22 全并后宿主顺序一变就踩到了）。
func _找购买窗(实例: Array[Node]) -> Control:
	for 窗 in 实例:
		var 遮 := 窗.get_node_or_null("遮罩") as Control
		if 遮 == null:
			continue
		var 购买窗 := 遮.get_node_or_null("商城购买窗") as Control
		if 购买窗 != null and 购买窗.visible:
			return 购买窗
	return null


func _失败(说明: String) -> void:
	push_error("购买窗单一宿主：" + 说明)
	quit(1)


func _收尾() -> void:
	if _failures.is_empty():
		print("购买窗单一宿主回归测试：通过（%d 条断言：只弹一枚 / 只铺一层 / 关掉零残留 / 再开遮罩仍在窗下）" % _已记)
		quit(0)
		return
	for 项 in _failures:
		push_error("购买窗单一宿主：" + 项)
	print("购买窗单一宿主回归测试：失败 %d / %d 条 —— %s" % [_failures.size(), _已记, ", ".join(_failures)])
	quit(1)
