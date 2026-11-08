extends RefCounted

## 原版 UI 换皮辅助。
##
## P2 之后本文件不再承载样式数据 —— 全部样式已迁入 素材/界面/原版主题.tres
## （由 脚本/界面/原版皮肤表.gd 经 开发工具/生成界面主题.gd 生成，全局注册）。
##
## 铁律：add_theme_*_override 无条件压过 Theme。所以这里只保留 Theme 表达不了的
## 部分 —— 逐调用点不同的值（字号/颜色/尺寸）与非主题属性（focus_mode/clip_text）。
## 任何重新加回样式覆盖的改动都会静默钉住外观、让主题改动看起来无效，
## 并被 测试/UI资源回归测试.gd 的残留覆盖检查拦下。

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")

const ORIGINAL_UI := 皮肤表.素材根
const ORIGINAL_BUTTON := 皮肤表.按钮
const ORIGINAL_TAB := 皮肤表.分页未选
const ORIGINAL_SLOT := 皮肤表.物品格
const ORIGINAL_CONTENT := 皮肤表.内容面板
const ORIGINAL_WINDOW_FRAME := 皮肤表.窗口边框
const ORIGINAL_SMALL_WINDOW_FRAME := 皮肤表.小窗口边框
const ORIGINAL_WINDOW_INNER := 皮肤表.窗口内底
const ORIGINAL_SUB_PANEL := 皮肤表.子面板
const ORIGINAL_LIGHT_PANEL := 皮肤表.浅色面板
const ORIGINAL_INPUT := 皮肤表.输入框
const ORIGINAL_SELECTED := 皮肤表.选中条
const ORIGINAL_TAB_ON := 皮肤表.分页选中
const ORIGINAL_BUTTON_DOWN := 皮肤表.按钮按下
const ORIGINAL_CHECKBOX_ON := 皮肤表.复选框选中
const ORIGINAL_CHECKBOX_OFF := 皮肤表.复选框未选
const ORIGINAL_PROGRESS_BG := 皮肤表.进度槽
const ORIGINAL_PROGRESS_FILL := 皮肤表.进度填充
const ORIGINAL_DROPDOWN_ARROW := 皮肤表.下拉箭头

## 别名到皮肤表，避免九宫格边距在两处分叉。
const NINE_SLICE := 皮肤表.九宫格


# ── 面板 ───────────────────────────────────────────────────
## 样式来自 Theme 的 Panel 类型与 OrigLightPanel 变体。
static func configure_panel(panel: Panel, outer := false) -> void:
	if outer:
		panel.theme_type_variation = 皮肤表.变体_浅色面板
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ── 按钮 ───────────────────────────────────────────────────
## 样式/颜色/描边/字号全部来自 Theme 的 Button 类型。
## UIConfig.btn_width_one..seven 见 皮肤表.按钮宽度；57x22 是 按钮.png 原始尺寸。
## `MButtonF`(symbol21) 不设宽时 = `upSkin` 原生 57×22（`MButton3` 非 isScale9Grid 支路）。
## ⚠️ 但宿主**显式设了宽**时（原版到处都是 `btn.width = UIConfig.btn_width_two = 37`、
##    `x = 386 − btn.width`、`isScale9Grid=true ⇒ _width = 文字宽 + 6`）必须把**那个宽**传进来：
##    `custom_minimum_size` 会把控件顶到不小于它，写死 57 就把场景里按原版算的宽全吞了
##    （实测「通灵驯养」的 提示 30 / 购买 37 / 开始提升 54 三颗全被拉成 57 ⇒ 用户打回"按钮样子不对"）。
static func configure_standard_button(button: Button, 尺寸 := Vector2(57.0, 22.0)) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = 尺寸


static func apply_tab_skin(tab: Button) -> void:
	tab.theme_type_variation = 皮肤表.变体_分页
	tab.custom_minimum_size = Vector2.ZERO
	tab.clip_text = true


## 页签的**选中态**：必须**同时**置 `disabled`。
##
## 原版 `MTabButton.as:38` `set enabled(v){selected = !v}` —— **选中那枚走的是 disabled 槽**，
## 显示符号 `MTabButton_disabled`（tag118 = `分页按钮选中.png` 那张**真皮**，不是禁用皮）；
## 而 `pressed` 槽现在接的是 **−40 暗态**（`StyleUtil.as:8-12` 的 `down:−40`，§3.139）。
## ⇒ 只置 `button_pressed` 的页签，选中那枚会渲染成**暗皮**（看着像一直被按着）。
##
## 全工程页签一律走这个入口（§3.139 把 11 处调用点都并了过来）。
static func 选页签(tab: Button, 选中: bool) -> void:
	tab.disabled = 选中
	tab.button_pressed = 选中


static func apply_list_selection_skin(button: Button) -> void:
	button.theme_type_variation = 皮肤表.变体_列表项
	button.flat = false
	button.custom_minimum_size = Vector2.ZERO


static func configure_overlay_button(button: Button, button_size: Vector2) -> void:
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.flat = not button.toggle_mode
	if button.toggle_mode:
		button.custom_minimum_size = Vector2.ZERO
		apply_tab_skin(button)
	else:
		button.theme_type_variation = 皮肤表.变体_浮层按钮


# ── 输入与通用控件 ──────────────────────────────────────────
## 以下四个的样式全部由 Theme 覆盖，无逐调用点差异，故为空。
## 保留函数是为了不动约 30 个调用点；P3 之后可整体删除。
static func configure_value_input(_input: LineEdit) -> void:
	pass


static func configure_checkbox(_check: CheckBox) -> void:
	pass


static func configure_option_button(_option: OptionButton) -> void:
	pass


static func configure_progress_bar(_bar: ProgressBar, _force := false) -> void:
	pass


## SpinBox 图标来自 Theme；居中对齐不是 Theme 项，必须逐控件设。
static func configure_spin_box(spin: SpinBox) -> void:
	spin.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_CENTER


## CheckBox/ProgressBar/OptionButton 已由 Theme 全覆盖，只剩 SpinBox 需要走一遍。
static func apply_common_control_skins(node: Node) -> void:
	if node is SpinBox:
		configure_spin_box(node as SpinBox)
	for child in node.get_children():
		apply_common_control_skins(child)


# ── 作为值消费的 StyleBox ───────────────────────────────────
## 这些是被赋给场景属性或返回给调用点的 StyleBox 值，不是控件覆盖。
## 直接从全局主题取，保证与 Theme 同源。
static func window_panel() -> StyleBox:
	return _主题样式(皮肤表.变体_窗口边框, "panel")


static func title_bar_panel() -> StyleBox:
	return StyleBoxEmpty.new()


static func content_panel() -> StyleBox:
	return _主题样式(皮肤表.变体_内容面板, "panel")


static func sub_panel_style() -> StyleBox:
	return _主题样式("Panel", "panel")


static func _主题样式(类型: StringName, 项: StringName) -> StyleBox:
	var 主题: Theme = ThemeDB.get_project_theme()
	if 主题 != null and 主题.has_stylebox(项, 类型):
		return 主题.get_stylebox(项, 类型)
	push_warning("主题缺样式 %s/%s，退回空样式" % [类型, 项])
	return StyleBoxEmpty.new()


## 九宫格纹理样式工厂。仍有 16 处调用点用它做主题未覆盖的一次性表面。
static func texture_style(path: String, tint := Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path) as Texture2D
	style.modulate_color = tint
	var slice: Variant = NINE_SLICE.get(path)
	if slice != null:
		var margins: Array = slice
		style.texture_margin_left = float(margins[0])
		style.texture_margin_right = float(margins[1])
		style.texture_margin_top = float(margins[2])
		style.texture_margin_bottom = float(margins[3])
	return style


# ── 节点工厂 ───────────────────────────────────────────────
static func make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	configure_label(label, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


static func make_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	configure_standard_button(button)
	return button


static func make_quantity_picker(maximum: int) -> SpinBox:
	var picker := SpinBox.new()
	picker.min_value = 1
	picker.max_value = maxi(1, maximum)
	picker.step = 1
	picker.value = 1
	picker.custom_minimum_size.x = 66.0
	picker.tooltip_text = "操作数量"
	configure_spin_box(picker)
	return picker


static func icon_rect(path: String, icon_size: Vector2) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = icon_size
	frame.theme_type_variation = 皮肤表.变体_物品格
	if not path.is_empty() and ResourceLoader.exists(path):
		var icon := TextureRect.new()
		icon.texture = load(path) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)
	return frame


## 字号与颜色逐调用点不同（143 处），Theme 表达不了，故这两项按调用点覆盖。
## 描边/阴影这里也照样重写一遍（见下面三行）—— 不是重复设置：主题是"没写 override 的那批"的兜底，
## 走漏斗的这批按规则值显式写死，两边不许各改各的（对账腿见 `测试/字体清晰回归测试.gd` 腿 J）。
static func configure_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	# 用户 2026-09-25 复述的硬规则：**所有文字黑描边、阴影关掉（00000000）**。
	# 主题现在烘的也就是这一套（`原版主题.tres` 的 Label：`outline_size = 2`、
	# `font_shadow_color` alpha 0、阴影偏移 (0,0)）；老注释写的"主题默认 outline_size = 0 +
	# 阴影 alpha 0.8"是 §3.52.3(d) 之前的状态，早就不成立了。
	#
	# ⚠️ 描边**数值**读 `皮肤表.文字规则_描边数值`，别写死：它是会漂的规则值
	#    （09-26 是 3、09-27 用户报"暗淡"后改成 2，见 开发记录（本地） §3.52.3(d)）。
	#    这里原先硬写 3，于是"主题给的 2"和"这个兜底给的 3"长期打架。
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 皮肤表.文字规则_描边数值)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
