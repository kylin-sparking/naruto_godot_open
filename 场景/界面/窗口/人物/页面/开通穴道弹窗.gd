extends Control
## 开通穴道弹窗 —— 只负责**纯 UI 行为**：关闭、拖动、「本次操作使用」勾选框联动下拉条。
## 数值 / 文案 / 按脉切形态 等由群主接服务端后填。
##
## 对外可读的两个东西（群主接服务端时直接取，不用改本脚本）：
##   使用八门灵符.button_pressed  —— 是否勾了「本次操作使用」（原版 useTongRen）
##   数量下拉.selected            —— 用几个（0 基，原版 count；选中项文字就是 1..9）
## 未勾选时 数量下拉.disabled = true，这是原版行为：
##   ChongMaiWindow.as 里 `_comboBox.enabled = _checkBox.selected`（初始 enabled = false）。

@onready var _勾选: CheckBox = get_node_or_null("使用八门灵符") as CheckBox
@onready var _下拉: OptionButton = get_node_or_null("数量下拉") as OptionButton

var _拖中 := false
var _拖起 := Vector2.ZERO


func _ready() -> void:
	visible = false   # 编辑器里保持可见方便拖拽排版；进游戏由穴位点击时再打开
	var 关 := get_node_or_null("关闭按钮") as Button
	if 关 != null:
		关.pressed.connect(func(): visible = false)
	var 区 := get_node_or_null("拖动区") as Control
	if 区 != null:
		区.gui_input.connect(_on_拖动区输入)
	if _下拉 != null:
		# 条目本来就该是 1..N，按序号写一遍，不依赖 tscn 里的文案。
		for i in _下拉.item_count:
			_下拉.set_item_text(i, str(i + 1))
		# 把 OptionButton 自带的箭头换成 1×1 全透明：
		#   它会把箭头宽度当作**右侧内部边距**扣掉可用宽度（43 − 样式 padding 25 − 箭头 13 = 5，
		#   而"1"有 6px 宽 → 差 1px 就整段文字都不画，框里空白）。
		#   换成 1×1 后内部边距只剩 1px，文字区 17px，数字正常显示。
		#   视觉上的箭头由同级的「下拉箭头」TextureRect 负责，位置精确可控。
		_下拉.add_theme_icon_override("arrow", ImageTexture.create_from_image(
			Image.create(1, 1, false, Image.FORMAT_RGBA8)))
	if _勾选 != null:
		_勾选.toggled.connect(_on_勾选变化)
		_勾选.button_pressed = false
	_on_勾选变化(false)


## 下拉条跟着勾选框走：没勾就不能点（原版行为）。
func _on_勾选变化(已勾: bool) -> void:
	if _下拉 != null:
		_下拉.disabled = not 已勾


func _on_拖动区输入(事件: InputEvent) -> void:
	if 事件 is InputEventMouseButton and 事件.button_index == MOUSE_BUTTON_LEFT:
		_拖中 = 事件.pressed
		_拖起 = get_global_mouse_position() - position
		accept_event()
	elif 事件 is InputEventMouseMotion and _拖中:
		position = get_global_mouse_position() - _拖起
		accept_event()
