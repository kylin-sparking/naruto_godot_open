extends TextureRect
## 八门 · 单个「穴位点位」（可点击、三态 + 联动穴位名颜色）。
##
##   未开启 = 穴位_暗    （默认）
##   悬停   = 穴位_悬停  （鼠标移入）
##   已开启 = 穴位_亮    ← 需要服务端「已点亮」数据，本轮未接；属性与常量已备好
##
## 同时联动同名穴位名的文字颜色：
##   未开通 → 白色 #ffffff      （原版 PointItem.light 的未开启色）
##   已开通 → 黄色 #ffcc00      （= 当前场景里的颜色）
##
## 用法：把本脚本挂在 12×12 的 TextureRect 上即可。约定：
##   节点名      `点_<穴位名>`
##   父节点名    `穴位点层_<门名>`（挂在 穴位图 下）
##   对应文字    穴位面板/穴位连线_<门名>/穴位组_<穴位名>/文字

const 图_暗 := preload("res://素材/界面/原版窗口/人物/八门/八门/穴位/穴位_暗.png")
const 图_悬停 := preload("res://素材/界面/原版窗口/人物/八门/八门/穴位/穴位_悬停.png")
## 已开启态用图。本轮不启用，留待接「已点亮」时使用。
const 图_亮 := preload("res://素材/界面/原版窗口/人物/八门/八门/穴位/穴位_亮.png")

const 色_未开通 := Color("#ffffff")
const 色_已开通 := Color("#ffcc00")

const 前缀_点 := "点_"
const 前缀_层 := "穴位点层_"

## 点击时发出。参数 = 本节点名（形如 "点_曲差"）。
signal 点击(点位名: String)

var _悬停中 := false
var _穴位名 := ""
var _门名 := ""
var _文字: Label = null

## 已开启态（开通）。接服务端后：点位.已开启 = true
## 注意：带 setter 的变量必须写显式类型，不能用 :=（否则整个脚本解析失败）。
var 已开启: bool = false:
	set(值):
		已开启 = 值
		刷新()


func _ready() -> void:
	_穴位名 = str(name).trim_prefix(前缀_点)
	var 层 := get_parent()
	if 层 != null:
		_门名 = str(层.name).trim_prefix(前缀_层)
		var 面板 := 层.get_parent()
		if 面板 != null:
			面板 = 面板.get_parent()
		if 面板 != null:
			var 组 := 面板.get_node_or_null("穴位连线_%s/穴位组_%s" % [_门名, _穴位名])
			if 组 != null:
				_文字 = 组.get_node_or_null("文字") as Label
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_进入)
	mouse_exited.connect(_on_离开)
	gui_input.connect(_on_输入)
	刷新()


func 刷新() -> void:
	if 已开启:
		texture = 图_亮
	elif _悬停中:
		texture = 图_悬停
	else:
		texture = 图_暗
	if _文字 != null:
		_文字.add_theme_color_override("font_color", 色_已开通 if 已开启 else 色_未开通)


func _on_进入() -> void:
	_悬停中 = true
	刷新()


func _on_离开() -> void:
	_悬停中 = false
	刷新()


func _on_输入(事件: InputEvent) -> void:
	if 事件 is InputEventMouseButton and 事件.pressed and 事件.button_index == MOUSE_BUTTON_LEFT:
		点击.emit(name)
		打开弹窗()
		accept_event()   # 注意：accept_event() 是 Control 的方法，不是 InputEvent 的


## 点开后弹「开通穴道」弹窗。
## 分工：**穴道名由这边填**（点哪个填哪个）；提炼值/加成/消耗/几率等由群主接服务端后补。
func 打开弹窗() -> void:
	var 窗 := _找弹窗()
	if 窗 == null:
		return
	var 值 := 窗.get_node_or_null("行1/值框/值") as Label
	if 值 != null:
		值.text = _穴位名
	窗.visible = true
	# 居中到整页（弹窗 287×288 比 穴位面板 大，按面板居中会跑到负坐标）
	var 页 := 窗.get_parent() as Control
	if 页 != null:
		窗.position = (页.size - 窗.size) * 0.5


## 沿父链找挂在 八门页 下的弹窗实例。
func _找弹窗() -> Control:
	var n: Node = self
	while n != null:
		var 窗 := n.get_node_or_null("开通穴道弹窗") as Control
		if 窗 != null:
			return 窗
		n = n.get_parent()
	return null
