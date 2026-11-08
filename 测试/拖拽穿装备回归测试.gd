extends SceneTree

## 拖拽穿装备：UI 侧的回归（**离线**、无头，不进 `跑在线用例`）。
##
## 为什么单独一条：§3.12.2 那条教训 ——"没被用例走过的链路等于没有"。
## 装备链路此前连一条断言都没有，两个真 bug 躺了很久。这次新加的
## "背包格 → 装备格"拖放判定与转发，**同样没有任何用例走过**，所以先把这几条钉死：
##
##   ① 落在**对的槽**上 → 接，并且真穿上
##   ② 落在**错的槽**上 → `_can_drop_data` 为 false，且什么都没发生
##   ③ 拖到**已在格里的同一件**上 → 不接（原版 `EquipPane.as:979-983` 的短路）
##   ④ 来源不是"背包"（例如仓库） → 不接（原版只认 `dragSource == ITEM_WINDOW`）
##   ⑤ 装备格自己**起不了拖**（原版 `EquipPane.onItemMove` 是死代码）——
##      `_get_drag_data` 必须返回 null，连半透明代理都不该出现
##
## 运行：Godot --headless --path . --script res://测试/拖拽穿装备回归测试.gd

const 装备部位表 := preload("res://脚本/单例/装备部位.gd")
const 物品格场景 := preload("res://场景/界面/组件/物品格.tscn")
## 格子节点名**不在这里抄一份**，直接问窗口自己那张表（`人物窗口.gd` 的 `装备格节点`）。
## 教训：原来这里写死 `装备栏/武器`、`装备栏/忍鞋`，2026-09-26 窗口把节点改名为
## `武器格`/`忍鞋格`（并挪进 `装备格子容器`）之后，这条门就红成"找不到两格" ——
## 同一个事实抄成两份，改一处必漏一处。
const 人物窗口脚本 := preload("res://脚本/界面/窗口/人物窗口.gd")
const 门存档快照 := preload("res://测试/门存档快照.gd")

## 离线示例背包里的武器（`脚本/单例/离线示例数据.gd`）：前四位 101 → 武器槽。
const 武器id := "01010011"

var _failures: Array[String] = []
var _会话 = null
var _人物窗: Node = null
var _武器格: Button = null
var _忍鞋格: Button = null
var _来源: Button = null
## 本门会真穿装备 ⇒ `_save_local_state()` 落盘。开场按字节快照、收尾按字节还原。
var _文件前 := {}


func _initialize() -> void:
	_文件前 = 门存档快照.全快照()
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://场景/地图/地图场景.tscn") as PackedScene
	if packed == null:
		_failures.append("无法加载地图场景")
		_finish()
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _帧 in range(5):
		await process_frame

	_会话 = root.get_node_or_null("GameSession")
	var 管理 := scene.get_node_or_null("窗口管理")
	_人物窗 = 管理.call("取或建窗口", "人物") if 管理 != null else null
	if _会话 == null or _人物窗 == null:
		_failures.append("拿不到 GameSession 或人物窗口")
		_finish()
		return

	# 每次拖拽的起点：武器在背包里、身上没有。
	_准备武器()
	if not await _重画():
		_finish()
		return
	if _武器格 == null or _忍鞋格 == null:
		_failures.append("装备栏里找不到 武器 / 忍鞋 两格")
		_finish()
		return
	_来源 = _造来源格("背包")

	# ⑤ 装备格自己起不了拖
	if _武器格.call("_get_drag_data", Vector2.ZERO) != null:
		_failures.append("装备格竟然能当拖拽源（原版 EquipPane.onItemMove 是死代码）")

	# ② 落在错的槽上
	if bool(_忍鞋格.call("_can_drop_data", Vector2.ZERO, _载荷(_来源))):
		_failures.append("武器落在忍鞋槽上竟然被接受")
	_忍鞋格.call("_drop_data", Vector2.ZERO, _载荷(_来源))
	await process_frame
	if _会话.equipped_items.has(装备部位表.忍鞋):
		_failures.append("落在错的槽上竟然真穿上了")

	# ④ 来源不是背包（例如仓库）
	var 仓库来源 := _造来源格("仓库")
	if bool(_武器格.call("_can_drop_data", Vector2.ZERO, _载荷(仓库来源))):
		_failures.append("仓库拖来的物品被装备格接受了（原版只认 ITEM_WINDOW）")

	# ① 落在对的槽上 → 真穿上
	if not bool(_武器格.call("_can_drop_data", Vector2.ZERO, _载荷(_来源))):
		_failures.append("武器落在武器槽上竟然被拒")
	_武器格.call("_drop_data", Vector2.ZERO, _载荷(_来源))
	await process_frame
	var 穿着: Variant = _会话.equipped_items.get(装备部位表.武器, {})
	if 穿着.is_empty():
		_failures.append("落在对的槽上却没穿上")
	elif 装备部位表.位置(String(穿着.get("id", ""))) != 装备部位表.武器:
		_failures.append("武器槽上穿的不是武器：%s" % 穿着.get("id", "?"))

	# ③ 拖到"已经装着同一件"的格子上 —— 要**重画**一次，
	# 装备格的 `物品id` 是渲染时按身上那件填的，不重画就还是空的。
	if not await _重画():
		_finish()
		return
	if String(_武器格.get("物品id")) != String(穿着.get("id", "")):
		_failures.append("重画后武器格的 物品id 与身上那件对不上（%s ≠ %s）"
			% [_武器格.get("物品id"), 穿着.get("id", "")])
	elif bool(_武器格.call("_can_drop_data", Vector2.ZERO, _载荷(_来源))):
		_failures.append("拖到已经装着**同一件**的格子上竟然被接受")

	_finish()


## 重画人物面板并重新取那两个格子节点 —— `open_page` 会把整页重建，旧节点是野指针。
func _重画() -> bool:
	_人物窗.call("open_page", "人物")
	for _帧 in range(4):
		await process_frame
	var 装备容器 := _人物窗.find_child("装备格子容器", true, false)
	if 装备容器 == null:
		_failures.append("重画后找不到 装备格子容器")
		return false
	_武器格 = 装备容器.get_node_or_null(String(人物窗口脚本.装备格节点[装备部位表.武器])) as Button
	_忍鞋格 = 装备容器.get_node_or_null(String(人物窗口脚本.装备格节点[装备部位表.忍鞋])) as Button
	return true


## 造一个"来源格"：真的物品格组件，只填拖放要用的那几个字段。
func _造来源格(归属: String) -> Button:
	var 格 := 物品格场景.instantiate() as Button
	格.set("格子归属", 归属)
	格.set("槽位号", 1)
	格.set("物品id", 武器id)
	格.set("可拖拽", true)
	root.add_child(格)
	return 格


func _载荷(来源: Button) -> Dictionary:
	return {"来源格": 来源, "归属": String(来源.get("格子归属")), "物品id": 武器id}


## 让武器**在背包里且不在身上**，作为每次拖拽的起点。
func _准备武器() -> void:
	_会话.equipped_items.clear()
	for 物品 in _会话.inventory:
		if String((物品 as Dictionary).get("id", "")).lstrip("0") == 武器id.lstrip("0"):
			return
	_会话.inventory.insert(0, {
		"id": 武器id, "name": "小太刀", "category": "装备",
		"quantity": 1, "slot_index": 1, "req_level": 1,
	})


func _finish() -> void:
	门存档快照.全还原(_文件前)
	if _failures.is_empty():
		print("拖拽穿装备回归测试：通过（对槽穿上 / 错槽被拒 / 同件短路 / 非背包来源被拒 / 装备格不起拖）")
		quit(0)
	else:
		for 项 in _failures:
			push_error("拖拽穿装备回归测试：失败 - %s" % 项)
		quit(1)
