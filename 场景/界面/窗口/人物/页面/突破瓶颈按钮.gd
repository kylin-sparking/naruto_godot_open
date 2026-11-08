extends Button
## 突破瓶颈按钮：点击时显示突破弹窗。
##
## 原版行为（JingMaiSource.showThroughWindow）：
##   `new ThroughAllMaiWindow(); _throughWindow.setLocationCenter(); API.ui.content.setDOShow2(...)`
##   → 弹窗是 **UIWindow(443,513) 居中于整个游戏画面** 的独立窗，不是八门页里的一块。
##
## Godot 等价做法：
##   1. 挂到一个高层 CanvasLayer（layer 100）—— 直接放八门页里会被 人物扩展页 的
##      clip_contents 裁掉（"显示不全"），放 root 下又会被 UI 的绘制顺序压住（"不显示"）。
##   2. 打开时铺一层整屏暗幕 —— 游戏窗体底图（内容面板/窗口内底）都是半透明的，
##      原版垫在暗幕上所以看着是实的；顺带挡住后面的点击（模态）。
##   3. 居中于视口（setLocationCenter）。
## 同名旧实例（上一扇人物窗留下的）顺手清掉，避免越攒越多。

## 要显示的弹窗。检查器里拖入"突破瓶颈弹窗"。
@export var popup: Control


func _ready() -> void:
	pressed.connect(_on_pressed)


## 页面被换掉时（`功能窗口._render_page` 每次回帧把整棵 `_content` `queue_free` 重建），
## 把**已经搬进屏幕层的自己那张弹窗**一起收掉、暗幕跟着收起。留在层里的是连着已释放旧页面的
## 僵尸窗：屏幕上还亮着、点「突破瓶颈」却毫无反应，而暗幕是全屏 `MOUSE_FILTER_STOP`，
## 一直亮着就把整屏点击吞掉（同 `手里剑页._exit_tree`，§3.200）。
func _exit_tree() -> void:
	if popup == null or not is_instance_valid(popup):
		return
	var 树 := get_tree()
	if 树 == null:
		return
	var 层 := (树.root as Node).get_node_or_null("屏幕弹窗层") as CanvasLayer
	if 层 == null or popup.get_parent() != 层:
		return
	层.remove_child(popup)
	popup.queue_free()
	var 暗幕 := 层.get_node_or_null("突破瓶颈暗幕") as CanvasItem
	if 暗幕 != null:
		暗幕.visible = false


func _on_pressed() -> void:
	if popup == null:
		return
	popup.visible = not popup.visible
	if popup.visible:
		_搬到屏幕层()
		# 注意别调 reset_size()：Panel 没有最小尺寸，会把它重置成 0x0
		# 居中于**人物属性窗口**（而不是整个画面）——否则弹窗两边露出的页面底不一样宽
		var 窗: Control = null
		var 走: Node = self
		while 走 != null:
			if 走.get_parent() is CanvasLayer:
				窗 = 走 as Control
				break
			走 = 走.get_parent()
		if 窗 != null:
			popup.global_position = (窗.global_position
					+ ((窗.size - popup.size) / 2.0).floor())
		else:
			popup.global_position = ((get_viewport_rect().size - popup.size) / 2.0).floor()
	_暗幕().visible = popup.visible


func _暗幕() -> ColorRect:
	var 层 := _屏幕弹窗层()
	var 暗幕 := 层.get_node_or_null("突破瓶颈暗幕") as ColorRect
	if 暗幕 == null:
		暗幕 = ColorRect.new()
		暗幕.name = "突破瓶颈暗幕"
		暗幕.color = Color(0, 0, 0, 0.45)
		暗幕.mouse_filter = Control.MOUSE_FILTER_STOP
		暗幕.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		层.add_child(暗幕)
		层.move_child(暗幕, 0)
	return 暗幕


func _屏幕弹窗层() -> CanvasLayer:
	var 根 := get_tree().root
	var 层 := 根.get_node_or_null("屏幕弹窗层") as CanvasLayer
	if 层 == null:
		层 = CanvasLayer.new()
		层.name = "屏幕弹窗层"
		层.layer = 120   # 功能窗口(人物属性)在 110，必须比它高
		根.add_child(层)
	return 层


func _搬到屏幕层() -> void:
	var 层 := _屏幕弹窗层()
	var 旧 := 层.get_node_or_null("突破瓶颈弹窗")
	if 旧 != null and 旧 != popup:
		旧.queue_free()
	popup.reparent(层)
