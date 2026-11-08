extends TextureButton

# ============================================================
# 切页箭头按钮的交互脚本（写轮眼页）
# ------------------------------------------------------------
# 与「柔拳页」的 箭头按钮交互.gd 行为完全一致，只换了个名字放在
# 血继界限的脚本目录下 —— 目的是让两个页面的切页手感统一。
#
# 交互规格（照搬柔拳页，不要改）：
#   常态   原图            modulate = (1.0, 1.0, 1.0)
#   悬停   提亮 30%        modulate = (1.3, 1.3, 1.3)
#   按下   压暗 40%        modulate = (0.6, 0.6, 0.6)
#   禁用   去饱和 shader → 全灰，且光标变回箭头
#
# 为什么要走原生 disabled 状态机而不是自己判断：
#   disabled = true 会同时挡掉 pressed 信号、去掉悬停反馈、
#   并且让 mouse_default_cursor_shape 失效 —— 三层保护一次到位。
#   在节点上手动 if 判断容易出现「看着灰了但还能点」的漏网情况。
# ============================================================

# 颜色定义（保留原色相，只做提亮 / 压暗）
const 颜色_常态 = Color(1.0, 1.0, 1.0, 1.0)   # 原图
const 颜色_悬停 = Color(1.3, 1.3, 1.3, 1.0)   # 提亮 30%
const 颜色_按下 = Color(0.6, 0.6, 0.6, 1.0)   # 压暗 40%

# 预加载去饱和灰化着色器（与柔拳页同一份实现）
var 去饱和材质 = preload("res://素材/界面/原版窗口/人物/手里剑/脚本/去饱和.gdshader")


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	# 初始默认可用
	设置是否可用(true)


# 外部（切换脚本）在翻页后调用这个方法：
#   当前阶段 == 1        → 上一页.设置是否可用(false)
#   当前阶段 == 总阶段数 → 下一页.设置是否可用(false)
func 设置是否可用(可用: bool) -> void:
	disabled = not 可用
	if disabled:
		# 变灰，且退出悬停态（否则可能残留提亮/压暗色）
		modulate = Color(1, 1, 1, 1)
		var 材质 = ShaderMaterial.new()
		材质.shader = 去饱和材质
		material = 材质
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
