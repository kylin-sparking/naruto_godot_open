extends Control
## 「梦幻属性符」窗装备格的**落点件**（2026-11-03）。
##
## 原版这一支是 `ItemDropBox.itemCell.dropItemFun = dropItemHandler → validateItem`
## （`MengHuanPropResetWindow.as:111-115 / :171-233`）：**收不收由页面判**，
## 组件只负责"从背包拖过来"并把来源格号交出去（先例：`修复放入格.gd`）。
##
## ⚠️ 不在 `_can_drop_data` 里按物品种类静默拒绝 —— 原版对"不能打造 / 时装 / 玉链 / 徽章 /
## 破损 / 非紫橙"各弹各的话（`validateItem` 六道闸门）。这里只认"归属 = 背包"，
## 其余原样放行，让页面按原版顺序弹话。

## 落上一件背包物品 → 请求放入（参数 = 来源背包格号，1 基）。
signal 请求放入(背包格: int)


func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if typeof(数据) != TYPE_DICTIONARY:
		return false
	return String((数据 as Dictionary).get("归属", "")) == "背包"


func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	var 来源 := 字典.get("来源格") as Node
	if 来源 == null:
		return
	请求放入.emit(int(来源.get("槽位号")))
