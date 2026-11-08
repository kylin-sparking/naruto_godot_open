extends TextureButton

# 是否解锁（群主以后可以改这个值让按钮灰化）
var 是否解锁: bool = true:
	set(value):
		是否解锁 = value
		_更新视觉效果()

# 颜色定义
const 颜色_常态 = Color(1.0, 1.0, 1.0, 1.0)   # 原图
const 颜色_悬停 = Color(1.3, 1.3, 1.3, 1.0)   # 提亮 30%
const 颜色_按下 = Color(0.6, 0.6, 0.6, 1.0)   # 压暗 40%

# ⚠️ 路径已经按照你截图里的实际位置修改好了！
var 去饱和材质 = preload("res://素材/界面/原版窗口/人物/柔拳/脚本/去饱和.gdshader")

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	_更新视觉效果()

func _on_mouse_entered() -> void:
	if not 是否解锁: return
	modulate = 颜色_悬停

func _on_mouse_exited() -> void:
	if not 是否解锁: return
	modulate = 颜色_常态

func _on_button_down() -> void:
	if not 是否解锁: return
	modulate = 颜色_按下

func _on_button_up() -> void:
	if not 是否解锁: return
	if is_hovered():
		modulate = 颜色_悬停
	else:
		modulate = 颜色_常态

func _更新视觉效果() -> void:
	if 是否解锁:
		modulate = 颜色_常态
		material = null
	else:
		modulate = Color(1, 1, 1, 1)
		var mat = ShaderMaterial.new()
		mat.shader = 去饱和材质
		material = mat
