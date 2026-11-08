extends SceneTree

# 把截图指定区域放大保存，方便肉眼比对细节。
func _initialize() -> void:
	var src := ""
	var rect := Rect2i()
	var out := ""
	var scale := 3
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"--src": src = kv[1]
			"--out": out = kv[1]
			"--scale": scale = int(kv[1])
			"--rect":
				var p := kv[1].split(",")
				rect = Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
	var img := Image.load_from_file(src)
	if img == null:
		print("加载失败 ", src)
		quit(1)
		return
	var cut := img.get_region(rect)
	cut.resize(rect.size.x * scale, rect.size.y * scale, Image.INTERPOLATE_NEAREST)
	print("保存=", cut.save_png(out), " ", out)
	quit(0)
