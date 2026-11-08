extends Button

## 下方快捷键栏的一格。**既能接、也能拖** —— 和原版一致。
##
## 原版（`ShortcutColumnPane.as`）：
##   · **落点**：判 `dragSource == SKILL_WINDOW`（从忍术面板拖进来）或 `KEYBOARD_CELL`（栏内互相搬），
##     `_loc7_[格号] = dragData`，并用 `hasRepeatData()` 把"同一技能原来占的那一格"写成
##     `KEY_TYPE_NO`（清掉，:651-664）—— 那条"同一个技能只占一格"在
##     `GameSession.bind_skill_to_slot()` 里已有，这里不重抄；
##   · **起拖**：`onItemMove():120-124` 对格子自己 `createDragDataProxy(..., KEYBOARD_CELL)`；
##   · **拖到空白处**：原版把该格写成 `KEY_TYPE_NO`，即**取消这个快捷键位**。
##
## ⚠️ 用 `Button` 而不是外层 `Control` 当落点，是因为外层是 `mouse_filter = 2`（IGNORE）收不到鼠标；
##    而"空位也要能落"这条又要求按钮**不能 `disabled`**（见 `技能面板._setup_shortcuts`）。
##
## 用法：`按钮.set_script(这本脚本)` 后填 `槽位号`，并接 `绑定完成` 刷新。

signal 绑定完成(槽位: int, 成功: bool)

## 这一格在第几个快捷栏位（0 起，与 `GameSession.skill_slots` 同一套编号）。
var 槽位号 := 0
## 这一格自己有没有起过拖。`NOTIFICATION_DRAG_END` 对**任何**拖拽结束都会发，
## 不记这个标记的话，"从背包拖东西丢在空白处"会顺手把快捷键位也清了。
var _本格起拖 := false

const 来源_忍术面板 := "忍术面板"
const 来源_快捷栏 := "快捷栏"


func _会话() -> Node:
	return get_node_or_null("/root/GameSession")


## 这一格现在绑的是哪个技能（空串 = 空位）。
func 技能编号() -> String:
	var 会话 := _会话()
	if 会话 == null:
		return ""
	var 槽位: Array = 会话.get("skill_slots")
	if 槽位号 < 0 or 槽位号 >= 槽位.size():
		return ""
	return String((槽位[槽位号] as Dictionary).get("id", ""))


func _can_drop_data(_位置: Vector2, 数据: Variant) -> bool:
	if not 数据 is Dictionary:
		return false
	var 来源 := String((数据 as Dictionary).get("来源", ""))
	return 来源 == 来源_忍术面板 or 来源 == 来源_快捷栏


func _drop_data(_位置: Vector2, 数据: Variant) -> void:
	if not _can_drop_data(_位置, 数据):
		return
	var 会话 := _会话()
	if 会话 == null:
		return
	var 编号 := String((数据 as Dictionary).get("技能id", ""))
	if 编号.is_empty():
		return
	# 栏内搬到**同一格** = 什么都不做（原版 `KEYBOARD_CELL` 那一支先判 `keyId` 相同就 return）。
	if String((数据 as Dictionary).get("来源", "")) == 来源_快捷栏 \
			and int((数据 as Dictionary).get("槽位", -1)) == 槽位号:
		return
	绑定完成.emit(槽位号, bool(会话.call("bind_skill_to_slot", 编号, 槽位号)))


func _get_drag_data(_位置: Vector2) -> Variant:
	var 编号 := 技能编号()
	if 编号.is_empty():
		return null
	# 跟着鼠标的那张图：格子里的技能图标（原版 `target.getIconCopy()`）。
	var 预览 := TextureRect.new()
	var 图标 := get_node_or_null("SkillIcon") as TextureRect
	if 图标 != null and 图标.texture != null:
		预览.texture = 图标.texture
	预览.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	预览.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	预览.size = Vector2(32.0, 32.0)
	预览.modulate.a = 0.8
	set_drag_preview(预览)
	_本格起拖 = true
	return {"来源": 来源_快捷栏, "技能id": 编号, "槽位": 槽位号}


## 松开鼠标时如果**没落到任何落点**（拖到空白处）→ 取消这个快捷键位。
## 原版同一件事走的是把格子写成 `KEY_TYPE_NO`；Godot 这边没有"落在空处"的回调，
## 只能靠拖拽结束通知里的 `successful` 判（`Viewport.gui_is_drag_successful()`）。
func _notification(什么: int) -> void:
	if 什么 != NOTIFICATION_DRAG_END:
		return
	if not _本格起拖:
		return          # 不是我起的拖，别动我的绑定
	_本格起拖 = false
	if 技能编号().is_empty():
		return
	var 视口 := get_viewport()
	if 视口 == null or 视口.gui_is_drag_successful():
		return
	var 会话 := _会话()
	if 会话 != null and bool(会话.call("unbind_skill_slot", 槽位号)):
		绑定完成.emit(槽位号, true)
