extends Button

## 忍术面板里「能拖到下方快捷键栏」的那一格。
##
## 原版起拖端：`SkillCell.as:58`（以及 `SkillPane1..5.as` 各自的同款一句）
##     this.dragManager.createDragDataProxy(stage, param1.currentTarget.icon,
##                                          param1.currentTarget.getCellValue(),
##                                          DragManager.SKILL_WINDOW);
## 落点端：`ShortcutColumnPane` 判 `dragSource == DragManager.SKILL_WINDOW` 就收，
## 并把 **同一个技能已有的那个格位清空**（`hasRepeatData` → `KEY_TYPE_NO`，:651-664）。
##
## Godot 这边换成内置拖放；**载荷只带技能 id**，绑定规则留在
## `GameSession.bind_skill_to_slot()`（它已经实现了"同一个技能只占一格"那条）。
##
## 用法：`格子.set_script(这本脚本)` 之后填 `技能id` / `可拖`。
## 只重写 `_get_drag_data` —— `pressed` 之类的原有信号连接不受影响。

## 这一格代表的技能 id（7 位字符串）。空 = 不能拖。
var 技能id := ""
## 学过的技能才拖得动（未学的是灰图标，原版那格没有 `SkillCell` 的拖拽监听）。
var 可拖 := false


func _get_drag_data(_位置: Vector2) -> Variant:
	if not 可拖 or 技能id.is_empty():
		return null
	# 拖动时跟着鼠标的那张图：直接用格子里的技能图标（原版 `getIconCopy()`）。
	var 预览 := TextureRect.new()
	var 图标 := get_node_or_null("图标") as TextureRect
	if 图标 != null and 图标.texture != null:
		预览.texture = 图标.texture
	else:
		预览.texture = get_theme_icon("image", "EditorIcons")
	预览.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	预览.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	预览.size = Vector2(32.0, 32.0)
	预览.modulate.a = 0.8
	set_drag_preview(预览)
	return {"来源": "忍术面板", "技能id": 技能id}
