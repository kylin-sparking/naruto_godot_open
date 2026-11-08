extends Control

@onready var 图标区 = get_node("阵法面板/阶段图标切换区")
@onready var 属性区 = get_node("阵法面板/数值，阶段名称切换区")
@onready var 立绘区 = get_node("阵法面板/视觉切换区")

# ⚠️ 下面这三行的路径请千万核对！
# 如果它们和“阵法面板”平级，路径就是 "上一页"；如果在容器里，就加上容器名。
@onready var 上一页 = get_node("上一页")
@onready var 下一页 = get_node("下一页")
@onready var 页码 = get_node("页码")

var 当前阶段: int = 1

func _ready() -> void:
	# 1. 自动连接 8 个圆形图标按钮
	for i in range(1, 9):
		var 按钮 = 图标区.get_node("阶段" + str(i))
		if 按钮:
			按钮.pressed.connect(_on_阶段按钮_pressed.bind(i))

	# 2. 自动连接左右翻页箭头
	if 上一页:
		上一页.pressed.connect(_on_上一页_pressed)
	if 下一页:
		下一页.pressed.connect(_on_下一页_pressed)

	# 3. 默认显示第一阶段
	_切换阶段(1)

func _on_阶段按钮_pressed(阶段号: int) -> void:
	_切换阶段(阶段号)

func _on_上一页_pressed() -> void:
	_切换阶段(当前阶段 - 1)

func _on_下一页_pressed() -> void:
	_切换阶段(当前阶段 + 1)

func _切换阶段(阶段号: int) -> void:
	# 边界限制：不会小于1，不会大于8
	阶段号 = clampi(阶段号, 1, 8)
	当前阶段 = 阶段号

	# 1. 更新底部页码文字（"1/8"）
	if 页码:
		页码.text = str(当前阶段) + "/8"

	# 🎯 2. 控制左右箭头灰化与禁用（就是新增的这两句！）
	if 上一页:
		上一页.设置是否可用(当前阶段 > 1)
	if 下一页:
		下一页.设置是否可用(当前阶段 < 8)

	# 3. 切换数值和名称
	var 中文数字 = ["一", "二", "三", "四", "五", "六", "七", "八"]
	var 目标属性名 = "第" + 中文数字[阶段号 - 1] + "阶段"
	for child in 属性区.get_children():
		child.visible = (child.name == 目标属性名)

	# 4. 切换立绘
	var 目标立绘名 = "柔拳阶段立绘" + str(阶段号)
	for child in 立绘区.get_children():
		if child.name.begins_with("柔拳阶段立绘"):
			child.visible = (child.name == 目标立绘名)
