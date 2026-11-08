extends Control
## 「生命料理」窗两枚投料格的**落点件**（2026-10-23 接投料）。
##
## 为什么不直接用 `可拖拽格.gd`：那个 **`extends Button`**，而这扇窗的三枚格是场景里的
## **`NinePatchRect`**（盒皮 `物品格.png` 烘在它身上；场景由 `开发工具/原版服务窗.py 生成 生命料理`
## 生成、**不许手改 .tscn**）⇒ 照 `徽章放入格` / `勾玉放入格` / `宝石放入格` 的先例另起一个
## **Control 基**的本件，运行期 `set_script` 挂到格上，**只保接口同形**（载荷字段照抄 `可拖拽格`）。
##
## 原版这一格收不收，两道闸分在两个地方（本件只负责第一道）：
##   · 类型闸 = `LiaoLiMadeWindow.validateItem:79`（走光标收集时）与 `dropItemHandler:150`
##     （走拖放时）**同一句** `ItemType.isItemALiaoLiCaiLiao(param1.id)`，
##     而 `ItemType.as:144-147` 的式子是 `int(param1 / 10000) == ItemType.LiaoLiCaiLiao`、
##     `:61` `LiaoLiCaiLiao = 1601` ⇒ **八位号的前四位 1601**（如 `16010011`）。
##     不收时原版弹 `LIAOLIMADEWINDOW_NOT_CAI_LIAO`「只能放入料理材料」——
##     拖放路径下 `_can_drop_data` 返回假 ⇒ 根本落不上去，那句弹话由「放入钮」那支负责说清。
##   · 第二道（**同种料**「只能放入两种不同的料理材料」）要拿"另一格里已经放了什么"才能判 ⇒
##     在页面 `生命料理窗._放料` 里（与 `徽章打造窗.满级或破碎提示` 同一分工）。
##
## ⚠ 判据写成 `int(int(文) / 10000)`：AS3 的 `int(param1 / 10000)` 是**先除再截断**，
##   外层那个 `int()` 不许省 ⇒ 不管 GDScript 这一档给的是 int 还是 float，都等价于原版的截断。
##   （省掉的话，若除法给 float，`16010011 / 10000 = 1601.0011 != 1601` ⇒ 整族拖放静默收不进料。）

## 落上一件合格料 → 请求放入（参数 = **来源背包格号**，1 基；
## 原版提交发的正是 `ItemData.position` = `zhiZuoLiaoLi:64-67` 的 `item0` / `item1`）。
signal 请求放入(背包格: int)
signal 请求取出

var 锁定 := false


func _gui_input(事件: InputEvent) -> void:
	if not 锁定 and 事件 is InputEventMouseButton and 事件.pressed and 事件.button_index == MOUSE_BUTTON_RIGHT:
		请求取出.emit()
		accept_event()


func _get_drag_data(_位置: Vector2) -> Variant:
	var 图标 := get_node_or_null("投料图标") as TextureRect
	if 锁定 or 图标 == null or 图标.texture == null:
		return null
	var 预览 := TextureRect.new()
	预览.texture = 图标.texture
	预览.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	预览.size = size
	预览.modulate.a = 0.5
	set_drag_preview(预览)
	return {"来源格": self, "归属": "料理"}


## 收不收这件（原版 `isItemALiaoLiCaiLiao` 那道类型闸）。做成 static：页面与门都能直接问。
static func 可收(物品id: Variant) -> bool:
	var 文 := str(物品id)		# ⚠ 不许写 `String(物品id)`：传入 int 时是 **Nonexistent 'String' constructor**（运行期才炸、`--check-only` 不报）
	return 文.is_valid_int() and int(int(文) / 10000) == 1601


func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if 锁定 or typeof(数据) != TYPE_DICTIONARY:
		return false
	var 字典 := 数据 as Dictionary
	if str(字典.get("归属", "")) != "背包":
		return false
	return 可收(字典.get("物品id", 0))


func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	var 来源 := 字典.get("来源格") as Node
	if 来源 == null:
		return
	var 槽 := int(来源.get("槽位号"))
	if 槽 > 0:
		请求放入.emit(槽)
