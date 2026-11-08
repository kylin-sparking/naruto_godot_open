extends TextureButton

# 颜色定义（保留原色相，只做提亮/压暗）
const 颜色_常态 = Color(1.0, 1.0, 1.0, 1.0)   # 原图
const 颜色_悬停 = Color(1.3, 1.3, 1.3, 1.0)   # 提亮 30%
const 颜色_按下 = Color(0.6, 0.6, 0.6, 1.0)   # 压暗 40%

# 预加载去饱和灰化着色器（路径和你截图里完全一致）
var 去饱和材质 = preload("res://素材/界面/原版窗口/人物/柔拳/脚本/去饱和.gdshader")

func _ready() -> void:
	# 连接信号
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	# 初始默认按钮可用
	设置是否可用(true)

# 🎯 核心方法：群主切换页码时，只需要调用这个方法
func 设置是否可用(可用: bool) -> void:
	disabled = not 可用
	if disabled:
		# 变灰，且拔掉手型光标（走正规 disabled 状态机）
		modulate = Color(1, 1, 1, 1)
		var mat = ShaderMaterial.new()
		mat.shader = 去饱和材质
		material = mat
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	else:
		# 恢复原色，开启手型
		modulate = 颜色_常态
		material = null
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_mouse_entered() -> void:
	if disabled: return
	modulate = 颜色_悬停

func _on_mouse_exited() -> void:
	if disabled: return
	modulate = 颜色_常态

func _on_button_down() -> void:
	if disabled: return
	modulate = 颜色_按下

func _on_button_up() -> void:
	if disabled: return
	if is_hovered(): modulate = 颜色_悬停
	else: modulate = 颜色_常态
