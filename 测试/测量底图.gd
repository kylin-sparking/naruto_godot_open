extends SceneTree

# 扫描原版系统设置底图，找出两列复选框边框的行位置，用来校准坐标。
# 复选框边框比棕色底稍亮，用相对阈值判断。

func _initialize() -> void:
	var img := Image.load_from_file("res://素材/界面/原版窗口/设置/系统设置底图.png")
	if img == null:
		print("加载失败")
		quit(1)
		return
	print("底图尺寸=", img.get_size())
	for entry in [["左", 22], ["右", 228]]:
		var column_name := String(entry[0])
		var x_start := int(entry[1])
		# 先探测该列的实际亮度分布
		var samples: Array[String] = []
		var rows: Array[int] = []
		var run := -1
		for y in range(60, img.get_height() - 20):
			var peak := 0.0
			for x in range(x_start - 8, x_start + 12):
				if x < 0 or x >= img.get_width():
					continue
				var c := img.get_pixel(x, y)
				peak = maxf(peak, c.r + c.g + c.b)
			var is_box := peak > 0.85
			if is_box and run < 0:
				run = y
			elif not is_box and run >= 0:
				if y - run >= 6:
					rows.append(run)
					samples.append("%d(h=%d)" % [run, y - run])
				run = -1
		print(column_name, "列 行=", ", ".join(samples))
	quit(0)
