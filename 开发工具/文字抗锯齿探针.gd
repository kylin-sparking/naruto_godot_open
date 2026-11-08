extends SceneTree
## 文字清晰度探针：同一帧里并排渲染多种字体/抗锯齿/内嵌点阵组合，
## 再用 开发工具/_临时_文字清晰度.py 统计「实心度」和与原版截图的形状重合度。
## 用法（不要用 --headless，需要真实窗口才能读到纹理）：
##   Godot_console.exe --path . --script res://开发工具/文字抗锯齿探针.gd

const 文本 := "战斗属性"          # 左列：12px，参与度量
const 长文本 := "战斗属性攻击力9"  # 中列：11px，只看可读性
const 数字文本 := "120 10783 Aa"  # 中列下：12px 纯 ASCII（宋体没有 ASCII 点阵，全走轮廓）
const 字号 := 12
const 文字色 := Color("#fff000")
const 背景色 := Color(0.145, 0.102, 0.078)
const 描边色 := Color(0, 0, 0, 1)
const 出图目录 := "res://测试/差异/文字清晰度探针"

## [名称, antialiasing(-1=继承), hinting(-1), subpixel(-1), outline, 字体名(""=主题默认), 过采样(0=默认), 内嵌点阵(false=禁用)]
const 组合 := [
	["现状LIGHT", -1, -1, -1, 3, "", 0.0, false],
	["原版字体·现状(全提示+灰度)", -1, -1, -1, 3, "", 0.0, false],
	["原版字体·全提示+单色", 0, -1, -1, 3, "", 0.0, false],
	["原版字体·无提示+单色", 0, 0, -1, 3, "", 0.0, false],
	["原版字体·全提示+单色+无描边", 0, -1, -1, 0, "", 0.0, false],
	["原版字体·全提示+灰度+无点阵", -1, -1, -1, 3, "", 0.0, true],
	["原版字体·全提示+灰度+过采样1.0", -1, -1, -1, 3, "", 1.0, false],
	["AA=关闭", 0, -1, -1, 3, "", 0.0, false],
	["AA=关闭+宋体", 0, -1, -1, 3, "SimSun", 0.0, false],
	["AA=单色+宋体+点阵", 3, -1, -1, 3, "SimSun", 0.0, true],
	["AA=关闭+宋体+点阵", 0, -1, -1, 3, "SimSun", 0.0, true],
	["AA=灰度+宋体+点阵", 2, -1, -1, 3, "SimSun", 0.0, true],
	["AA=单色+宋体+点阵+无描边", 3, -1, -1, 0, "SimSun", 0.0, true],
	["AA=单色+点阵+微调关", 3, 0, -1, 3, "SimSun", 0.0, true],
	["AA=单色+雅黑+点阵", 3, -1, -1, 3, "", 0.0, true],
	["AA=单色+宋体+亚像素关", 3, -1, 0, 3, "SimSun", 0.0, true],
]

const 行高 := 26
const 左边距 := 8
const 基线顶 := 10


func _make_font(c: Array) -> Font:
	var 字体: Font
	if String(c[5]) == "":
		字体 = (load("res://素材/界面/原版主题.tres") as Theme).get_default_font().duplicate(true) as Font
	else:
		字体 = SystemFont.new()
		字体.font_names = PackedStringArray([String(c[5]), "宋体"])
	if bool(c[7]):
		字体.disable_embedded_bitmaps = false
	if int(c[1]) >= 0:
		字体.antialiasing = int(c[1])
	if int(c[2]) >= 0:
		字体.hinting = int(c[2])
	if int(c[3]) >= 0:
		字体.subpixel_positioning = int(c[3])
	if float(c[6]) > 0.0:
		字体.oversampling = float(c[6])
	return 字体


func _label(文本内容: String, 位置: Vector2, 字体: Font, 大小: int, 描边: int) -> Label:
	var 标签 := Label.new()
	标签.text = 文本内容
	标签.position = 位置
	标签.add_theme_font_override("font", 字体)
	标签.add_theme_font_size_override("font_size", 大小)
	标签.add_theme_color_override("font_color", 文字色)
	标签.add_theme_color_override("font_outline_color", 描边色)
	标签.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	标签.add_theme_constant_override("outline_size", 描边)
	return 标签


func _initialize() -> void:
	root.title = "文字清晰度探针"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(620, 行高 * 组合.size() + 40)
	root.position = Vector2i(120, 80)

	var 底板 := ColorRect.new()
	底板.color = 背景色
	底板.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(底板)

	for i in 组合.size():
		var c: Array = 组合[i]
		var 字体 := _make_font(c)
		var y := 基线顶 + i * 行高
		root.add_child(_label(文本, Vector2(左边距, y), 字体, 字号, int(c[4])))
		root.add_child(_label(长文本, Vector2(120, y), 字体, 11, int(c[4])))
		root.add_child(_label(数字文本, Vector2(250, y), 字体, 字号, int(c[4])))
		var 名牌 := Label.new()
		名牌.text = "%d.%s" % [i + 1, c[0]]
		名牌.position = Vector2(380, y)
		名牌.add_theme_font_size_override("font_size", 11)
		名牌.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		名牌.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		名牌.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		名牌.add_theme_constant_override("outline_size", 0)
		root.add_child(名牌)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var 图 := root.get_texture().get_image()
	if 图 == null:
		print("截屏失败")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(出图目录)
	var 路径 := 出图目录.path_join("探针.png")
	图.save_png(路径)
	print("已保存 %s  尺寸=%dx%d" % [路径, 图.get_width(), 图.get_height()])
	quit(0)
