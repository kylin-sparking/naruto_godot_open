extends Button
## 总览按钮：点击时显示总览页。

## 点这个按钮时要显示/隐藏的页面。检查器里拖入"总览页"。
@export var target_page: Control


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if target_page != null:
		target_page.visible = true
