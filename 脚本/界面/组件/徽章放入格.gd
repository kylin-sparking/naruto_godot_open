extends Control
## 「徽章打造」窗两个投料盒的**落点件**（2026-10-11 接投料）。
##
## 为什么不直接用 `可拖拽格.gd`：那个 **`extends Button`**，而这扇窗的材料格是场景里的
## **`NinePatchRect`**（盒皮烘在它身上；场景由 `开发工具/原版服务窗.py 生成 徽章打造` 生成、
## **不许手改 .tscn**）⇒ 照 `意志格.gd` 的先例另起一个 **Control 基**的本件，
## 运行期 `set_script` 挂到材料格上，**只保接口同形**（载荷字段照抄 `可拖拽格`）。
##
## 原版两页各有一个 `ItemDropBox.itemCell`，`dropItemFun = dropItemHandler` → `validateItem`：
##   · 页0 `StoneComposePane.validateItem:81-108`：只收 `ItemType.isItemHuiZhangShi`
##     （**前三位 132**），且 `nextId == 0`（满级）弹「该宝石已经是最高等级！」并**不收**；
##   · 页1 `BadgeComposePane.validateItem:78-102`：只收 `ItemType.isHuiZhang`
##     （`getItemEquipPosition == HuiZhang`，四位码 **0141**），破碎（`crashTime > 0`）
##     与 `nextId == 0` 各有各的弹话、都不收。
##
## ⚠️ 本件只管"收不收这一格拖来的料"（原版 `validateItem` 的**类型**那一闸），
## **满级/破碎**那道闸与协议全在页面 —— `徽章打造窗.满级或破碎提示`（2026-10-13 补上，
## 判据 = `物品.json` 的 `stone_next` / `装备库.json` 的 `进阶目标`，两者都**按八位补零**查）。
## 与 `宝石放入格` / `残卷放入格` 同一分工（口径同「宝石工艺」合成页：类型在组件、满级在页面）。

const 装备部位 := preload("res://脚本/单例/装备部位.gd")

## 落上一件合格料 → 请求放入（参数 = **来源背包格号**，1 基；原版提交发的就是这个 `position`）。
signal 请求放入(背包格: int)

## 页面填：这是第几页（0 = 合成徽章石 / 1 = 打造徽章）。
var 本页 := 0


## 这一页收不收这件（原版两个 `validateItem` 的第一道闸门）。
## 判据做成 static：页面/门都能直接问，不必先把件挂上。
static func 可收(物品id: Variant, 页: int) -> bool:
	var 文 := str(物品id)
	if not 文.is_valid_int():
		return false
	var 补零 := 文.pad_zeros(8)
	if 页 == 0:
		return int(补零.substr(0, 3)) == 132          # `isItemHuiZhangShi`：前三位 132
	return 装备部位.位置(补零) == 装备部位.徽章        # `isItemAHuiZhang`：位置 = 徽章(-22)


func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if typeof(数据) != TYPE_DICTIONARY:
		return false
	var 字典 := 数据 as Dictionary
	if str(字典.get("归属", "")) != "背包":
		return false
	return 可收(str(字典.get("物品id", "")), 本页)


func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	var 来源 := 字典.get("来源格") as Node
	if 来源 == null:
		return
	请求放入.emit(int(来源.get("槽位号")))
