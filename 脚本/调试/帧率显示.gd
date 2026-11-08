extends CanvasLayer

## 可选帧率浮层（小工具，不参与正常游戏表现）。
##
## 打开方式（二选一）：
##   · 设环境变量 `NARUTO_FPS=1` 后启动（夹具/存档口径完全不变）；
##   · 游戏内按 **F8** 随时开关（F9 已被族旗诊断占用，F8 空闲）。
##
## 只用引擎的 `Engine.get_frames_per_second()` / 实际帧时间，不自己算"游戏逻辑帧"——
## 玩家看到的卡顿就是这两项。正常启动（没设环境变量、没按 F8）时
## `set_process(false)`，每帧零开销，也不和 HUD 抢输入。

const 刷新间隔 := 0.25
const 位置边距 := 8.0

var _标签: Label
var _开关 := false
var _累计 := 0.0


func _ready() -> void:
	layer = 200                      # 盖在 HUD/窗口之上，但只读不挡鼠标
	_标签 = Label.new()
	_标签.name = "帧率文字"
	_标签.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_标签.add_theme_font_size_override("font_size", 14)
	_标签.add_theme_color_override("font_color", Color(1.0, 1.0, 0.35))
	_标签.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_标签.add_theme_constant_override("outline_size", 4)
	add_child(_标签)
	_开关 = OS.get_environment("NARUTO_FPS") == "1" or OS.get_cmdline_user_args().has("--fps")
	_标签.visible = _开关
	set_process(_开关)
	var 视口 := get_viewport()
	if 视口 != null:
		视口.size_changed.connect(_摆位)
	_刷新()
	_摆位()


func _process(delta: float) -> void:
	_累计 += delta
	if _累计 < 刷新间隔:
		return
	_累计 = 0.0
	_刷新()


func _刷新() -> void:
	var fps := Engine.get_frames_per_second()
	var 毫秒 := 1000.0 / maxf(1.0, float(fps))
	_标签.text = "FPS %d   %.1f ms" % [fps, 毫秒]
	_标签.reset_size()
	if _开关:
		_摆位()                      # 文字宽度变了，右边缘跟着重贴（否则会慢慢偏）


func _摆位() -> void:
	if _标签 == null:
		return
	var 视口 := get_viewport()
	var 尺寸: Vector2 = 视口.get_visible_rect().size if 视口 != null else Vector2(960, 560)
	_标签.position = Vector2(尺寸.x - _标签.size.x - 位置边距, 位置边距)


func _input(事件: InputEvent) -> void:
	if not (事件 is InputEventKey):
		return
	var 键 := 事件 as InputEventKey
	if 键.pressed and not 键.echo and 键.keycode == KEY_F8:
		_开关 = not _开关
		_标签.visible = _开关
		set_process(_开关)
		if _开关:
			_累计 = 刷新间隔
			_刷新()
