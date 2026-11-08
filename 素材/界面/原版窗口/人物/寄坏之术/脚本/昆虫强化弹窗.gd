extends Control

# 节点【关闭按钮】是Button类型
@onready var btn_close: Button = $关闭按钮
const SHADER_DARK: Shader = preload("res://素材/界面/原版窗口/人物/柔拳/脚本/去饱和.gdshader")

func _ready():
	btn_close.mouse_entered.connect(_close_hover)
	btn_close.mouse_exited.connect(_close_leave)
	btn_close.button_down.connect(_close_press)
	btn_close.button_up.connect(_close_release)

# 关闭按钮点击，隐藏弹窗
func _on_close_button_pressed():
	visible = false

# 强化寄坏虫按钮点击，打开弹窗
func _on_insect_btn_pressed():
	visible = true
	z_index = 100

# 悬停：恢复原色
func _close_hover():
	btn_close.material = null

# 鼠标离开：去饱和变暗
func _close_leave():
	var mat = ShaderMaterial.new()
	mat.shader = SHADER_DARK
	btn_close.material = mat

# 鼠标按下：更深
func _close_press():
	var mat = ShaderMaterial.new()
	mat.shader = SHADER_DARK
	mat.set_shader_parameter("dark",0.6)
	btn_close.material = mat

# 松开鼠标
func _close_release():
	_close_hover()
