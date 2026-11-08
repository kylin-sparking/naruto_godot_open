extends Control

@export var stage_sprites: Array[TextureRect] = []
@export var attribute_panel_group: Node
@export var prev_button: BaseButton
@export var next_button: BaseButton
@export var red_outline_material: Material # 关键！必须把红边材质拖进来

## 服务端给的**真实境界**（1 起算，与 `stage` 同口径；8 = 全通过 ⇒ 不灰）。
## 对应原版 `LunHuiYanPanel.currIndex`：`setImageFilters:314-333` —— 阶段号**高于**它的
## 壁画整块套 `StyleUtil.getGrayFilter()`；正在看的那块**再叠**红辉光（AS3 的 filters 是数组，
## 所以"没提升却在翻看它"= 灰 + 红边**同时**）。由 `人物窗口` 在初始化/刷新时写入再调 `_update_ui()`。
var real_stage: int = 8

## `红色描边.gdshader` 的 gray_amount=1 复制（"翻看未达成的阶段"那一格专用），首次用到才建。
var _灰红材: Material = null
## 纯灰材质：直接套项目里那份逐字照抄原版矩阵的 `禁用灰度.gdshader`（柔拳页②c 同源）。
var _灰材: Material = null

var current_index: int = 0
## 服务端那一侧**真开到第几阶**（1 起算）。原版 `LunHuiYanPanel.setImageFilters:304-334`
## 的排序键就是它：`号 > currIndex` 的那些图标一律推 `StyleUtil.getGrayFilter()` ⇒
## 「这一档你还没开启」在画面上是**灰的**，不是隐藏、也不是能点亮着玩。
var 已开阶: int = 1
## 进度条那两个数也只能由宿主从服务端那一帧 + 本地 Etc 表递进来：
## `精魂数` = 2313 帧里的「轮回六道进度」（属性名见 `后端连接.gd:4858`），
## `各阶上限` = `stageN.levelUp.maxJingHun`（**服务端从不下发上限**，
## 原版读 `LunHuiYanManager.allData["stage"+n].maxJingHun`，见 `LunHuiYanPanel.as:412-415`）。
var 精魂数: int = 0
var 各阶上限: Array = []
## 灰化用的就是工程里那一份 Flash `getGrayFilter` 的着色器（不另写第二套公式）。
const 灰度着色器 := preload("res://脚本/界面/组件/禁用灰度.gdshader")
static var _灰度材质: ShaderMaterial = null


static func 灰度材质() -> ShaderMaterial:
	if _灰度材质 == null:
		_灰度材质 = ShaderMaterial.new()
		_灰度材质.shader = 灰度着色器
	return _灰度材质


## 原版每块壁画的**阶段号后缀**（`LunHuiYanPanel.onComplete:404-411` 的创建顺序名）：
## `TianDao_2 … DiYu_7`、背景 `Bg_8`、`WaiDao_9` —— `stage_sprites[0]` 是「六道开启」节点，
## 它拿的正是那块 **Bg** 底图，所以按 8 算：境界 < 8 时连背景也灰（`createLunHuiYanBtn:471-474`），
## 境界==8 时 `createLunHuiYanBtn:475-477` 给 Bg 的例外 + `setImageFilters:328-331` 给
## `WaiDao_9` 的例外 ⇒ 背景和外道一起取消灰。
## 推论：翻看「六道开启」(param1=1) 没有任何一块后缀等于 1 ⇒ **原版此时整幅全灰、不给红边**；
## 翻看「外道」(param1=8) 红边落在 Bg（外道 _9 永远吃不到辉光）。用 i+1 会让背景永远不灰、
## 1 阶就在背景上描一圈红框 —— 2026-10-26 截图核对时逮到，按原版表改。
const 原版阶段号 := [8, 2, 3, 4, 5, 6, 7, 9]

func _ready():
	if prev_button:
		prev_button.pressed.connect(_on_prev_pressed)
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	
	for btn in [prev_button, next_button]:
		if btn:
			btn.mouse_entered.connect(_on_button_hover.bind(btn))
			btn.mouse_exited.connect(_on_button_leave.bind(btn))
			btn.button_down.connect(_on_button_down.bind(btn))
			btn.button_up.connect(_on_button_up.bind(btn))
	
	_update_ui()

func _on_next_pressed():
	# 边界拦截：如果是最后一个阶段，直接返回，不再切换
	if current_index >= stage_sprites.size() - 1:
		return
	current_index += 1
	_update_ui()

func _on_prev_pressed():
	# 边界拦截：如果是第一个阶段，直接返回，不再切换
	if current_index <= 0:
		return
	current_index -= 1
	_update_ui()

func _update_ui():
	# 1. 所有立绘都显示（壁画是分块的，原版也是全在场、只靠滤镜区分）
	for i in range(stage_sprites.size()):
		var sprite = stage_sprites[i]
		sprite.visible = true

		# 2. 原版 `setImageFilters:314-333`：阶段号查 `原版阶段号`（不是 i+1！见常量注释）。
		#    高于 `real_stage` ⇒ 灰；`后缀 == 在看阶段号` 的那块 ⇒ 再叠红边。四格组合：
		#      达成+在看 → 红边；达成+没看 → 无；未达成+在看 → 灰+红边；未达成+没看 → 灰。
		var 阶: int = 原版阶段号[i]
		var 未达成 := 阶 > real_stage
		if 阶 == 9 and real_stage >= 8:
			未达成 = false
		var 在看 := 阶 == current_index + 1
		if 在看 and 未达成:
			if _灰红材 == null and red_outline_material is ShaderMaterial:
				var 材 := (red_outline_material as ShaderMaterial).duplicate() as ShaderMaterial
				材.set_shader_parameter("gray_amount", 1.0)
				_灰红材 = 材
			sprite.material = _灰红材 if _灰红材 != null else red_outline_material
		elif 在看:
			sprite.material = red_outline_material
		elif 未达成:
			if _灰材 == null:
				var 灰 := ShaderMaterial.new()
				灰.shader = load("res://脚本/界面/组件/禁用灰度.gdshader")
				_灰材 = 灰
			sprite.material = _灰材
		else:
			sprite.material = null
	
	# 3. 属性面板切换
	var panels = attribute_panel_group.get_children()
	for i in range(panels.size()):
		if i == current_index:
			panels[i].visible = true
		else:
			panels[i].visible = false

	# 4. 进度条：原版只有一根（挂在画板里），数值跟着**正在看的那一阶**换。
	#    条上的数字也是原版有的：`MBar.setData` 末尾 `tf.text = param1 + "/" + param2`
	#    （`MBar.as:150-178`；`_jinDuBar` 没设 showPercent ⇒ 走这条）。所以 `进度值` 必须显。
	if current_index >= 0 and current_index < panels.size():
		var 组 := panels[current_index] as Control
		if 组 != null:
			var 条 := 组.get_node_or_null("进度") as ProgressBar
			if 条 != null:
				var 数 := 进度对(current_index + 1)
				条.min_value = 0.0
				条.max_value = 数.y
				条.value = 数.x
				var 字 := 组.get_node_or_null("进度值") as Label
				if 字 != null:
					字.text = "%d/%d" % [int(数.x), int(数.y)]
					字.visible = true


## 逐句转写 `LunHuiYanPanel.as:136-167`（`updateInfo` 里 `_jinDuBar` 那三分支）：
##  · 看的是**已经过去的阶**（`param1 < currIndex`）⇒ 直接满；
##  · 看的是**服务端当前那一阶** ⇒ (精魂数, 本阶上限)；
##  · 看的是**还没到的阶** ⇒ 分子 = 前面每一阶上限之和 + 现在的精魂数，
##    分母 = 从第 1 阶一路累加到所看那阶。
## 返回 `Vector2(分子, 分母)`。
func 进度对(阶: int) -> Vector2:
	var 本阶 := 上限(阶)
	if 阶 < 已开阶:
		return Vector2(本阶, 本阶)
	if 阶 == 已开阶:
		return Vector2(float(精魂数), 本阶)
	var 已积 := 0.0
	var k := 1
	while k < 已开阶:
		已积 += 上限(k)
		k += 1
	var 合计 := 0.0
	k = 1
	while k <= 阶:
		合计 += 上限(k)
		k += 1
	return Vector2(已积 + float(精魂数), 合计)


func 上限(阶: int) -> float:
	if 阶 < 1 or 阶 > 各阶上限.size():
		return 0.0
	return float(各阶上限[阶 - 1])

# ================= 按钮交互（无变灰，纯视觉反馈） =================
func _on_button_hover(btn):
	btn.modulate = Color(1.3, 1.3, 1.3, 1)

func _on_button_leave(btn):
	btn.modulate = Color(1, 1, 1, 1)

func _on_button_down(btn):
	btn.modulate = Color(0.6, 0.6, 0.6, 1)

func _on_button_up(btn):
	btn.modulate = Color(1.3, 1.3, 1.3, 1)
