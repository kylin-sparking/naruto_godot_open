extends Control

## 「拖到空处松手」的接盘 —— 挂在**页面根**上（现只挂背包页）。
##
## 原版的机制：起拖时 `DragManager.createTransparentSprite` 铺一层全屏透明层
## （`UIMain2.__onTransparentSpriteClick:5462-5482`）——松手没落在任何格子上时，
## **这层接住**并按 `dragSource` 分流：ITEM_WINDOW/FORGE_WINDOW → `ItemWindow2.destroyItem(dragData)`
## （背包件拖空 = 销毁链）；EQUIP_WINDOW → 只是收起代理。
##
## Godot 等价：拖放落点找不到会**沿父链上溯**找第一个 `can_drop_data()==true` 的控件，
## 页面根实现该虚函数就是这层"透明层"。子级格子（物品格/页签/按钮）在树里更靠前，
## 该谁收谁收；只有落在**空白**（格间隙、面板底、按钮以外）才会走到这里。
## 落在**窗外**接不到（原版在舞台上无处不可，这是有意登记的差距，见 §3.80.4）。
##
## ⚠️ 宿主页面的根 `mouse_filter` 必须是 PASS/STOP（IGNORE 时 `gui_find_control`
## 直接跳过整棵页面树，父链上溯轮不到我们）—— 背包页根在 tscn 里已改 PASS。
##
## 仓库页**不挂**：原版拖空对 STORAGE_WINDOW 走的是另一条（`StorageWindowEvent.ITEM_DROP`），
## 本轮不做，挂在这的人只会收到背包件的松手。

signal 落在空白(载荷: Dictionary)

func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if typeof(数据) != TYPE_DICTIONARY:
		return false
	var 字典 := 数据 as Dictionary
	# 载荷形状见 `可拖拽格._get_drag_data`：{来源格, 归属, 物品id}
	return String(字典.get("归属", "")) == "背包" and 字典.get("来源格", null) != null

func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	落在空白.emit(数据 as Dictionary)
