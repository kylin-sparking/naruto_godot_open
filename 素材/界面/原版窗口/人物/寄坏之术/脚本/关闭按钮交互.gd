extends TextureButton

# 正常、悬停、按下的颜色滤镜
var normal_color: Color = Color(1, 1, 1, 1)
var hover_color: Color = Color(1.3, 1.3, 1.3, 1)
var pressed_color: Color = Color(0.6, 0.6, 0.6, 1)

func _ready():
	# 自动连接鼠标信号
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	# 鼠标放上去变手型
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_mouse_entered():
	if not disabled:
		modulate = hover_color

func _on_mouse_exited():
	if not disabled:
		modulate = normal_color

func _on_button_down():
	if not disabled:
		modulate = pressed_color

func _on_button_up():
	if not disabled:
		modulate = hover_color
