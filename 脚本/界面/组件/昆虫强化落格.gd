extends Control
## 昆虫强化弹窗里那枚「放置格」的**落点件**（2026-10-27 用户报修①「不能手动拖拽背包的昆虫到强化格里」）。
##
## 场景是既有节点（`底图/放置区底图/放置格`，Panel）⇒ 与同族 `昆虫放入格` / `勾玉放入格`
## 一样运行期 `set_script` 挂上（挂同一份脚本时 `set_script` 是 no-op、成员变量留着，
## 所以本件**不放任何需要每轮重置的状态**，页面那一侧的连接也先拆再接）。
##
## 原版真值（本轮逐字重读）：
##   · `SimpleItemCell.as:109-117 dropItemHandler` —— 落点**只认** `dragData` 存在且
##     `dragSource == DragManager.ITEM_WINDOW`（背包），**不看物品类型**；类型闸在落下来之后。
##   · `KunChongStrengthWindow.as:415-418 dropItemHandler` → `:420-439 validateItem` ——
##     `ItemType.isItemAKunChong(id)`（前三位 131）过 ⇒ 这件就是强化目标、按钮文案换「取出昆虫」；
##     不过 ⇒ `MDialog.showMessageDialog(LangUtil.get("KUNCHONG_STRENGTH_NOT_KUNCHONG"))`
##     =「很抱歉，该物品不是昆虫不能强化！」，**目标保持不动**。
##   · 服务端同一条只认前缀：`fake_flash_server.py:54613` `item.item_id // 10_000 != 131`
##     ⇒ 文案逐字相同。**所以这里不补"物品表分类"那道闸** —— 与 `昆虫放入格`（穿虫）不同：
##     那一头服务端认的是装备定义（勾玉没有 ⇒ 拒），这一头服务端只认前缀，勾玉照样能强化。
##     原版就是这么宽，加闸就是偏离原版。
##
## 页面那一侧接 `请求选虫` ⇒ 把背包格记成「携入的虫」（与背包物品菜单「强化」同一个宿主通道
## `_角色携入虫` / `_角色携入位置`），再原地重画这一页 —— 整扇弹窗的图标、文案、消耗两行、
## 两枚勾的可用性全部由 `初始化寄坏之术页` 按新目标重填，本件不参与。

## 落下一件**背包起拖**的件 → 交页面按原版 `validateItem` 判类型。
## 参数 = 来源背包格号（1 基，原版发的是 `dragData.position`）+ 那件的物品 id。
signal 请求选虫(背包格: int, 物品id: String)


func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if typeof(数据) != TYPE_DICTIONARY:
		return false
	var 字典 := 数据 as Dictionary
	if String(字典.get("归属", "")) != "背包":
		return false
	var 来源 := 字典.get("来源格") as Node
	return 来源 != null and 来源 != self


func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	var 来源 := 字典.get("来源格") as Node
	if 来源 == null:
		return
	请求选虫.emit(int(来源.get("槽位号")), String(字典.get("物品id", "")))
