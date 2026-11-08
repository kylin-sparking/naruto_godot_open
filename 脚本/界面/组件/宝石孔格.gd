extends "res://脚本/界面/组件/可拖拽格.gd"

## 镶嵌窗（`StoneCarryWindow`）里的那一格**宝石孔**。
##
## 原版 `StoneCarryWindow`（`com/mxw/uifl/controls/equip/StoneCarryWindow.as`）对每孔挂两个事件：
##   · `inalyStoneHandler`（`:204-221`，MOUSE_UP）：孔是空的 + 正拖着一件**宝石**
##     （`ItemFactory.isItemABaoShi`）→ `requestInlay(装备.position, 宝石.position)`；
##     拖来的不是宝石 → 弹提示、不镶。
##   · `deleteStoneHandler`（`:223-236`，CLICK）：孔里有宝石 → `requestUninlay(装备.position, 孔.position)`；
##     先查背包满（`isPackgeFull` → `TYPE_BAG_FULL`）。
## 孔位 `position` 就是**0 基**的 inlay 下标（`:97-101` `stoneBox.position = 0..4/5`）。
##
## Godot 侧：拖放落点用内置 `_can_drop_data`/`_drop_data`（见 `可拖拽格.gd`）；
## 本组件只负责"接不接这颗宝石"与把意图发出去，**协议由页面脚本发**（组件不认识装备格号）。
## 版式（尺寸/坐标）在 `.tscn` 里，不在这里。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## 孔号（0 基，对应服务端 inlay 数组下标）。页面在装配时填。
var 孔号 := 0

## 落上一颗宝石 → 请求镶嵌（参数 = **本孔号 + 来源宝石格**）。
## ⚠️ 2026-10-02：原来只发 `宝石格` 一个参数，而页面处理函数是 `(孔号, 宝石格)` 两参 ——
##   信号一发就 "Method expected 2 arguments, but called with 1"，**处理函数根本没跑**，
##   表现正是用户报的"拖进去没反应"（拖放落地了、协议没发出去）。孔号一并带上，两边对齐。
signal 请求镶嵌(孔号: int, 宝石格: int)
## 点已镶的孔 → 请求摘除。
signal 请求摘除(孔号: int)

## 孔位显示的是"镶进去的那颗宝石"，**不能再从这儿拖走**（原版这窗里孔格不是拖拽源）。
## 所以 `可拖拽` 保持 false，只当落点 + 可点。

func _ready() -> void:
	# 空格子（没镶宝石）也要能收拖放 → 落点判定归 `_can_drop_data`，这里不 disabled。
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func():
		if not 物品id.is_empty():
			请求摘除.emit(孔号))


## 只接**背包来的宝石**、且**这一格当前是空的**。
func _can_drop_data(位置: Vector2, 数据: Variant) -> bool:
	if not super._can_drop_data(位置, 数据):
		return false
	if not 物品id.is_empty():
		return false                         # 已镶 → 不再收（要换先点摘除，照原版）
	var 字典 := 数据 as Dictionary
	if String(字典.get("归属", "")) != "背包":
		return false
	var 宝石id := String(字典.get("物品id", ""))
	return 是宝石(宝石id)


func _drop_data(位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	var 来源 := 字典.get("来源格") as Button
	if 来源 == null:
		return
	请求镶嵌.emit(孔号, int(来源.槽位号))


## `ItemType.getTypeFromId == 13` 就是宝石类（`getItemMenu`/`isItemABaoShi` 同源）。
static func 是宝石(物品id: String) -> bool:
	if not 物品id.is_valid_int():
		return false
	return int(String(物品id).pad_zeros(8).substr(0, 2)) == 13
