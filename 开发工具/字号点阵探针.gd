extends SceneTree
## 字号点阵探针：宋体内嵌点阵在哪些字号上真的存在（1-bit 实心），
## 哪些字号会退回轮廓+灰度抗锯齿（发虚）。
## 用法：Godot_console.exe --path . --script res://开发工具/字号点阵探针.gd

const 文本 := "战斗属性Aa19"
const 文字色 := Color("#fff000")
const 背景色 := Color(0.145, 0.102, 0.078)
const 出图目录 := "res://测试/差异/文字清晰度探针"
const 字号们 := [9, 10, 11, 12, 13, 14, 15, 16, 18, 20]
const 行高 := 30
const 基线顶 := 8


func _字体(名单: Array, 点阵: bool) -> Font:
	var 字体 := SystemFont.new()
	字体.font_names = PackedStringArray(名单)
	字体.disable_embedded_bitmaps = not 点阵
	字体.antialiasing = 1  # 1=Grayscale（0=None、2=LCD 子像素，取值问过引擎的 hint_string）；
	## 对齐 `素材/界面/simsun_原版.ttf.import` 烘的那个 1 —— 原注释把它当"灰度"却写 2，
	## 2 其实是 LCD，量出来的图和实机不是同一条光栅路径。
	return 字体


func _initialize() -> void:
	root.title = "字号点阵探针"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(620, 行高 * 字号们.size() + 30)
	root.position = Vector2i(100, 60)

	var 底板 := ColorRect.new()
	底板.color = 背景色
	底板.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(底板)

	# 左列 = 宋体+内嵌点阵；右列 = 雅黑（对照）
	for i in 字号们.size():
		var 号 := int(字号们[i])
		var y := 基线顶 + i * 行高
		for col in 2:
			var 名单 := ["SimSun", "宋体"] if col == 0 else ["Microsoft YaHei UI"]
			var 标签 := Label.new()
			标签.text = 文本
			标签.position = Vector2(60 + col * 250, y)
			标签.add_theme_font_override("font", _字体(名单, col == 0))
			标签.add_theme_font_size_override("font_size", 号)
			标签.add_theme_color_override("font_color", 文字色)
			标签.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			标签.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			标签.add_theme_constant_override("outline_size", 3)
			root.add_child(标签)
		var 名牌 := Label.new()
		名牌.text = "%dpx" % 号
		名牌.position = Vector2(6, y)
		名牌.add_theme_font_size_override("font_size", 11)
		名牌.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		名牌.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		名牌.add_theme_constant_override("outline_size", 0)
		root.add_child(名牌)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var 图 := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(出图目录)
	var 路径 := 出图目录.path_join("字号探针.png")
	图.save_png(路径)
	print("已保存 %s" % 路径)

	# 就地统计每行两列的实心度
	var bg := 背景色
	var 方向 := Vector3(文字色.r - bg.r, 文字色.g - bg.g, 文字色.b - bg.b)
	var 长度 := 方向.length()
	方向 = 方向 / 长度
	for i in 字号们.size():
		var y := 基线顶 + i * 行高
		var 结果 := []
		for col in 2:
			var 墨 := 0
			var 实心 := 0
			for yy in range(y, y + 行高):
				for xx in range(60 + col * 250, 60 + col * 250 + 240):
					var p := 图.get_pixel(xx, yy)
					var a := Vector3(p.r - bg.r, p.g - bg.g, p.b - bg.b).dot(方向) / 长度
					if a > 0.15:
						墨 += 1
						if a >= 0.90:
							实心 += 1
			结果.append("墨=%4d 实心=%5.1f%%" % [墨, 100.0 * 实心 / max(墨, 1)])
		print("%2dpx  宋体点阵: %s   |   雅黑: %s" % [字号们[i], 结果[0], 结果[1]])
	quit(0)
