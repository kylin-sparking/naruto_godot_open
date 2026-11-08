extends "res://脚本/界面/组件/可拖拽格.gd"

## 宝石工艺窗「宝石合成」页里的那个**放入宝石格**（原版 `StoneCompositeWindow._itemDropBox.itemCell`）。
##
## 原版 `ItemDropBox` 的 itemCell 是 `SimpleItemCell`，`dropItemFun = dropItemHandler`
## （`StoneCompositeWindow.as:173-179`）：从背包拖一颗宝石落上来 → 先**清空 成功/退还/剩余 三格**、
## 再 `validateItem(宝石)`（`:181-212`：必须是宝石；`nextId==0`（满级）弹「该宝石已经是最高等级！」
## 并**不放进**；放进后 resultCell 预览 `createSingleItem(nextId)`、按钮文字换「取出宝石」）。
## 非宝石落下 → `MDialog`「对不起，该物品不是宝石」——Godot 侧同镶嵌窗口径：**落点直接拒**
## （`_can_drop_data` 返回 false，代理弹回），"不是宝石"那句由页面处理函数兜（菜单开门那条路也走它）。
##
## 本组件只认"收不收这一格拖来的宝石"，**满级判定/协议全在页面**（组件不认识背包格号语义之外的东西）。
## 版式（尺寸/坐标）在 `.tscn` 里，和 `宝石孔格.gd` 同一家族。

const 宝石孔格 := preload("res://脚本/界面/组件/宝石孔格.gd")

## 落上一颗宝石 → 请求放入（参数 = 来源背包格号，1 基）。
## ⚠️ 信号参数必须和处理函数**一字不差地对上** —— 镶嵌窗那条 `请求镶嵌` 少了一参
##   直接让处理函数根本没跑（§3.85.5 用户报"拖进去没反应"的根因，别再犯）。
signal 请求放入(宝石格: int)


## 只接**背包来的宝石**（类型 13；勾玉也算 —— 原版 `isItemABaoShi` 就是类型 13，
## 菜单那条路才按前三位 131 分流去玉链进阶窗，拖放这里不分流）。
## 放满一颗也**照样能再放**（原版 `dropItemHandler` 无条件 `validateItem` 换件）。
func _can_drop_data(位置: Vector2, 数据: Variant) -> bool:
	if not super._can_drop_data(位置, 数据):
		return false
	var 字典 := 数据 as Dictionary
	if String(字典.get("归属", "")) != "背包":
		return false
	return 宝石孔格.是宝石(String(字典.get("物品id", "")))


func _drop_data(位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	var 来源 := 字典.get("来源格") as Button
	if 来源 == null:
		return
	请求放入.emit(int(来源.槽位号))
