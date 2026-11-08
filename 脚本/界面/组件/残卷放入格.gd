extends "res://脚本/界面/组件/可拖拽格.gd"

## 秘笈合成页（`JiNengCompositeWindow`）的**放入残卷格**（原版 `_itemDropBox.itemCell`，
## 2026-10-03 接 `CAN_JUAN_ACTION 1352` 时新建；`宝石放入格.gd` 的同族）。
##
## 原版 `validateItem:356-375`：只有 `ItemType.isItemJiNengCanJuan(id)` 的件能落
## （非残卷 → `MDialog`「对不起，该物品不是忍术残卷」）；落上后按钮文字换「取出残卷」
## （`EQUIP_STRENGTH_DROP_ITEM_BTN_NAMES_4`）。Godot 侧与宝石放入格/镶嵌窗同口径：
## **落点直接拒**（`_can_drop_data` false、代理弹回），拒话由页面兜。
##
## 判据取 `数据/物品.json` 的 `canjuan_book` 列（`导出秘笈合成链.py` 从
## `JiNengCanJuan.spec.merge` 导）—— 与服务端 `skill_fragment_recipe` 同一份数据；
## 没有配方的残卷落了也必被服务端拒 ⇒ 落点直接不收，口径一致。
##
## ⚠️ 信号一参、页面处理函数也必须一参（§3.85.5 arity 教训，别再犯）。

const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

## 落上一件残卷 → 请求放入（参数 = 来源背包格号，1 基）。
signal 请求放入(残卷格: int)


## 有没有产物配方（可参与合成）—— `是秘术残卷` 的判据。
static func 有配方(物品id: Variant) -> bool:
	if not String(物品id).is_valid_int():
		return false
	var 行: Dictionary = 游戏数据.item(物品id)
	return not 行.is_empty() and int(行.get("canjuan_book", 0)) > 0


func _can_drop_data(位置: Vector2, 数据: Variant) -> bool:
	if not super._can_drop_data(位置, 数据):
		return false
	var 字典 := 数据 as Dictionary
	if String(字典.get("归属", "")) != "背包":
		return false
	return 有配方(字典.get("物品id", ""))


func _drop_data(位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	var 来源 := 字典.get("来源格") as Button
	if 来源 == null:
		return
	请求放入.emit(int(来源.槽位号))
