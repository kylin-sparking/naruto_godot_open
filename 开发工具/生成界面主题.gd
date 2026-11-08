extends SceneTree

## 从 脚本/界面/原版皮肤表.gd 生成 素材/界面/原版主题.tres。
##
## 幂等：数据不变则产出一致。改了皮肤表就重跑：
##   Godot --headless --path . --script res://开发工具/生成界面主题.gd
##
## 主题必须由生成器产出、不可手改 —— 手改会在下次生成时丢失，
## 测试/界面主题回归测试.gd 会重跑生成器并比对来抓这种情况。

const 皮肤表 := preload("res://脚本/界面/原版皮肤表.gd")
const 输出路径 := "res://素材/界面/原版主题.tres"


func _initialize() -> void:
	var 主题 := 构建主题()
	if 主题 == null:
		quit(1)
		return
	var 错误 := ResourceSaver.save(主题, 输出路径)
	if 错误 != OK:
		push_error("保存主题失败：%s" % 错误)
		quit(1)
		return
	print("已生成 ", 输出路径, "，类型数=", 主题.get_type_list().size())
	quit(0)


## 供生成与测试共用：只构建不落盘。
static func 构建主题() -> Theme:
	var 主题 := Theme.new()

	var 底字: FontFile = load(皮肤表.字体路径) as FontFile
	if 底字 == null:
		push_error("字体加载失败：%s" % 皮肤表.字体路径)
		return null
	# ⚠ 2026-10-25 晚回滚：`default_font` 必须是**裸 FontFile**。§3.275 曾在这里包一层
	#   FontVariation(embolden=1.5) 想给数字加字重，但合成加粗只作用于走轮廓的 ASCII，
	#   12px 数字/字母整圈边缘被抹成灰 ⇒ 用户实机报「数值方面，数字、字母之类的都模糊了」。
	#   正文与数量字按 AS3 都是常规字重（`ItemWindowCell.as:60-62` 没有 bold），只有窗口
	#   标题是 `MWindow.as:69-74` 的 bold —— 那层单独设在 `变体_窗口标题` 上（见下）。
	主题.default_font = 底字
	主题.default_font_size = 皮肤表.默认字号
	主题.default_base_scale = 1.0

	# 键可能是 String（Theme 类型）或 StringName（变体常量），统一成 String
	for 键: Variant in 皮肤表.类型规格:
		var 类型名 := String(键)
		var 规格: Dictionary = 皮肤表.类型规格[键]

		# 变体：登记基类，Godot 据此继承未覆盖的项
		if 规格.has("继承"):
			主题.set_type_variation(类型名, String(规格["继承"]))

		if 规格.has("样式"):
			for 项名: String in 规格["样式"]:
				主题.set_stylebox(项名, 类型名, _建样式(规格["样式"][项名]))

		if 规格.has("颜色"):
			for 项名: String in 规格["颜色"]:
				主题.set_color(项名, 类型名, _取色(规格["颜色"][项名]))

		if 规格.has("常量"):
			for 项名: String in 规格["常量"]:
				主题.set_constant(项名, 类型名, int(规格["常量"][项名]))

		if 规格.has("图标"):
			for 项名: String in 规格["图标"]:
				var 纹理: Texture2D = load(String(规格["图标"][项名])) as Texture2D
				if 纹理 == null:
					push_error("图标加载失败：%s / %s" % [类型名, 项名])
					return null
				主题.set_icon(项名, 类型名, 纹理)

		if 规格.has("字号"):
			# RichTextLabel 用 normal_font_size 而非 font_size
			var 字号项: String = String(规格.get("字号项", "font_size"))
			主题.set_font_size(字号项, 类型名, int(规格["字号"]))

		# ── 用户 2026-09-26 的**文字硬规则**：游戏内所有文字 ────────────────
		#    描边 开启 / #000000 / 3，阴影 开启 / #00000000。
		# 规格里显式写了的**不覆盖**（Label、RichTextLabel 写着自己那份），
		# 没写的在这里补齐 —— 关键是**变体必须自己写一份**：运行期
		# `Theme.has_color("font_shadow_color", &"OrigListItem")` 实测是 false
		# （基类 Button 明明有），`get_color` 会直接返回不透明的 `Color()`。
		if 规格带文字(规格):
			if not 主题.has_color("font_outline_color", 类型名):
				主题.set_color("font_outline_color", 类型名, 皮肤表.文字规则_描边色)
			if not 主题.has_color("font_shadow_color", 类型名):
				主题.set_color("font_shadow_color", 类型名, 皮肤表.文字规则_阴影色)
			if not 主题.has_constant("outline_size", 类型名):
				主题.set_constant("outline_size", 类型名, 皮肤表.文字规则_描边数值)
			if not 主题.has_constant("shadow_offset_x", 类型名):
				主题.set_constant("shadow_offset_x", 类型名, 0)
			if not 主题.has_constant("shadow_offset_y", 类型名):
				主题.set_constant("shadow_offset_y", 类型名, 0)

	# 窗口标题按原版 `MWindow.as:69-74` 单独加粗（正文/数量字不加粗，见上面的回滚说明）。
	# 只设字重、不换字库：base_font 仍是 `simsun_原版.ttf`，汉字照旧走内嵌点阵。
	if 皮肤表.标题加粗量 > 0.0:
		var 标题字 := FontVariation.new()
		标题字.base_font = 底字
		标题字.variation_embolden = 皮肤表.标题加粗量
		主题.set_font("font", 皮肤表.变体_窗口标题, 标题字)

	return 主题


## 这个类型的规格（或它 `继承` 的任一祖先）声明了文字颜色吗？
## 变体自己不写 `font_color`（继承基类的），所以必须沿 `继承` 往上找 —— 生成器与门共用这一份判据。
static func 规格带文字(规格: Dictionary, 深度 := 0) -> bool:
	if 深度 > 8:
		return false
	if 规格.has("颜色"):
		for 项名: Variant in 规格["颜色"]:
			var 名 := String(项名)
			if 名.begins_with("font") or 名 == "default_color":
				return true
	if 规格.has("继承"):
		return 规格带文字(皮肤表.类型规格.get(String(规格["继承"]), {}), 深度 + 1)
	return false


## null → StyleBoxEmpty；数组 → 九宫格纹理样式。
## 数组格式 [路径, tint?, content?, 转置?]，转置=true 时交换九宫格的横竖边距
## （HScrollBar 复用竖向美术）。
static func _建样式(值: Variant) -> StyleBox:
	if 值 == null:
		return StyleBoxEmpty.new()

	var 参数: Array = 值
	var 路径 := String(参数[0])
	var 样式 := StyleBoxTexture.new()
	样式.texture = load(路径) as Texture2D
	if 样式.texture == null:
		push_error("纹理加载失败：%s" % 路径)

	if 参数.size() > 1:
		样式.modulate_color = _取色(参数[1])

	var 边距: Variant = 皮肤表.九宫格.get(路径)
	if 边距 != null:
		var 组: Array = 边距
		var 左 := float(组[0])
		var 右 := float(组[1])
		var 上 := float(组[2])
		var 下 := float(组[3])
		if 参数.size() > 3 and bool(参数[3]):
			样式.texture_margin_left = 上
			样式.texture_margin_right = 下
			样式.texture_margin_top = 左
			样式.texture_margin_bottom = 右
		else:
			样式.texture_margin_left = 左
			样式.texture_margin_right = 右
			样式.texture_margin_top = 上
			样式.texture_margin_bottom = 下

	# content_margin 默认全 0；仅在规格显式给出时设置
	var 内容: Array = []
	if 参数.size() > 2 and 参数[2] is Array:
		内容 = 参数[2]
	if 内容.size() == 4:
		样式.content_margin_left = float(内容[0])
		样式.content_margin_right = float(内容[1])
		样式.content_margin_top = float(内容[2])
		样式.content_margin_bottom = float(内容[3])
	else:
		样式.content_margin_left = 0.0
		样式.content_margin_right = 0.0
		样式.content_margin_top = 0.0
		样式.content_margin_bottom = 0.0
	return 样式


static func _取色(值: Variant) -> Color:
	if 值 is Color:
		return 值
	return Color(String(值))
