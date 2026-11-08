extends Control

signal 选中变了(阶: int)

@export var seal_button_group: Node

func _ready():
	var seals = seal_button_group.get_children()
	for i in range(seals.size()):
		var seal = seals[i]
		var btn = seal.find_child("印式*", true, false)
		if btn is BaseButton:
			btn.pressed.connect(_on_seal_pressed.bind(i))
	
	_update_ui(0)

func _on_seal_pressed(index: int):
	_update_ui(index)

## 宿主把**某个人**的结印阶推过来时用它（1 起算）。
## 原版 `JieYinPanel.onJieYin_updateStatus:222-229` 收到状态帧后：不是当前选中的那一枚就
## `setStage(阶)` ⇒ 亮他那阶、显示对应数值面板。「看别人」那一扇走的正是这一条
## （`CharOtherWindow2.as:392 resetView(jieYinState, jieYinEatCount)`）。
## 只做**显示**，不接任何请求 —— 十二枚印在只读窗里照样可点（原版 `:282` 的 CLICK 监听
## 没有 `isMyJieYin` 判断），要点亮哪一枚由 `_update_ui` 自己处理。
func 选印(阶: int) -> void:
	_update_ui(clampi(阶, 1, seal_button_group.get_child_count()) - 1)

func _update_ui(index: int):
	var seals = seal_button_group.get_children()
	for i in range(seals.size()):
		var seal = seals[i]
		var selected_box = seal.find_child("选中手势框", true, false)
		var default_box = seal.find_child("默认手势框", true, false)
		var container = seal.find_child("数值容器", true, false)
		
		if selected_box:
			selected_box.visible = (i == index)
		if default_box:
			default_box.visible = (i != index)
		if container:
			container.visible = (i == index)
	## 1 起算的「选中了第几印」—— 宿主据此重算数值面板与那颗提升钮
	## （原版 `JieYinPanel.setStage:292-299` 里那句 `updateProp()`）。
	选中变了.emit(index + 1)
