extends Control
## 意志「格」的拖放件（2026-10-11 §3.102，欠账②）。
##
## 为什么不直接用 `可拖拽格.gd`：那个 **`extends Button`**，而意志窗的格子是场景里的
## **空 `Control`**（`背包容器/格_0..29`、`穿戴容器/格_1..8`；格底皮烘在**容器**上，
## 见 `_填格内容` 的头注）。把 60 个节点的类型从 Control 改成 Button 会动到已对过版式的皮
## ⇒ 另起一个 Control 基的本件，**只保接口同形**（变量名与载荷形状照抄，两者可互通）。
##
## 原版这两件事都在 `YiZhiPackWindow` 里：起拖走全局 `DragManager`，
## 落点判定在 `onUpgradeCellMouseUp:615-637` —— **升级格有货 ⇒ 融合（`rongHeYiZhi`）；
## 没货 ⇒ `requestSpirit_move(slot, 0)`（= `1823` 动作 10，目标槽 0 就是升级槽）**。

## 落点那侧拿到的东西比 `可拖拽格` 多两样：**归属**与**槽位号**。
## 意志的拖放要按"哪个容器的第几槽"换算协议，光有物品 id 不够
## （背包 slot 1..30 / 穿戴 slot -1..-8 / 升级槽 0，三者同一个 id 也可能同时存在）。
signal 拖放(来源格: Control, 目标格: Control, 归属: String, 槽位号: int)

## 页面填：这一格属于哪个容器（`"意志背包"` / `"意志穿戴"` / `"意志升级"`）。空串 = 不参与。
var 格子归属 := ""
## 页面填：**协议里的槽位号**（背包 1..30 / 穿戴 -1..-8 / 升级槽 0）—— 不是格子下标。
var 槽位号 := -1
## 页面填：这一格能不能**被拖出去**。升级格是"只接不吐"（原版从升级格起拖也走的是
## `onUpgradeCellMouseUp` 那一支，没有反向的 `createDragDataProxy`）。
var 可拖拽 := false:
	set(值):
		可拖拽 = 值
		# Godot 的拖放要求源控件 mouse_filter 不是 IGNORE
		mouse_filter = Control.MOUSE_FILTER_STOP if 值 else mouse_filter


func _get_drag_data(_位置: Vector2) -> Variant:
	if not 可拖拽 or 格子归属.is_empty():
		return null
	# AS3 `YiZhiCell.downHandler:82-86`：**有货且有图标**才起拖
	#（`if(_yiZhiData && _icon)`）⇒ 空格/锁格不许当源（原版锁格 `_state=0`，
	# `upHandler:232` 也不收它当落点）。2026-10-19 阶段二补这条：
	# 之前空格也能起拖，拖到哪都被服务端拒，玩家看来"拖了没反应"。
	var 图 := get_node_or_null("格图标") as TextureRect
	if 图 == null or 图.texture == null:
		return null
	# 半透明代理：把格子里挂着的那张图标抬起来（与 `可拖拽格._get_drag_data` 同款）。
	# 图标是 `_填一格层` 运行期挂的 `格图标` —— 上一段已经挡掉"无货不起拖"，
	# 所以走到这里 `图.texture` 必然非空（断言式防御，别退回"空格也拖"）。
	var 预览 := TextureRect.new()
	预览.texture = 图.texture
	预览.size = Vector2(40.0, 40.0)
	预览.modulate = Color(1.0, 1.0, 1.0, 0.5)
	var 宿主 := Control.new()
	宿主.add_child(预览)
	预览.position = Vector2(-20.0, -20.0)
	set_drag_preview(宿主)
	return {"来源格": self, "归属": 格子归属, "槽位号": 槽位号}


func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if 格子归属.is_empty() or mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	if typeof(数据) != TYPE_DICTIONARY:
		return false
	var 字典 := 数据 as Dictionary
	# 只认"意志那几个容器"来的载荷 —— 别把背包件/宝石件也收进来。
	return String(字典.get("归属", "")).begins_with("意志") and 字典.get("来源格", null) != self


func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	var 字典 := 数据 as Dictionary
	拖放.emit(字典["来源格"] as Control, self, String(字典.get("归属", "")), int(字典.get("槽位号", -1)))
