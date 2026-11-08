extends Panel
## 突破瓶颈弹窗 —— 只负责「关闭」这个纯 UI 行为。
##
## 注意：这个窗在原版是**屏幕级窗口**（JingMaiSource.showThroughWindow() →
## `new ThroughAllMaiWindow(); setLocationCenter(); API.ui.content.setDOShow2(...)`，
## 尺寸 UIWindow(443,513)）。打开时 突破瓶颈按钮.gd 会把它搬到屏幕弹窗层并居中，
## 同时铺一层整屏暗幕（游戏窗体底图是半透明的，垫暗幕才"实"）。
## 数值 / 文案 / 成功几率由群主接服务端后填。

func _ready() -> void:
	var 关 := get_node_or_null("关闭按钮") as BaseButton
	if 关 != null:
		关.pressed.connect(收起)
	visible = false


func 收起() -> void:
	visible = false
	var 暗幕 := get_parent().get_node_or_null("突破瓶颈暗幕") as CanvasItem
	if 暗幕 != null:
		暗幕.visible = false
