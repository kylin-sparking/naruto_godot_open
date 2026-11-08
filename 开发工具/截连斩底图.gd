extends SceneTree
## 有头量具：把连斩底图在**四个进度档**上实拍出来，和原版 GIF 条带并排比。
##
## 为什么要它：`连斩计数回归测试.gd` 判的是"剪影的 x 等于 165×(比例-1)"这个算式，
## 而用户 10-12 拿原版 GIF 打回的是**屏幕上到底填没填**（原版：弹出时整块黑，红色从右往左慢慢填）。
## 算式对 ≠ 画得对（裁剪框没生效 / 底皮被盖死 / 剪影比皮大，都会让"红填黑"看不出来而门照样绿）。
##
## 用法（**不能加 --headless**）：
##     "godot" --path . --script res://开发工具/截连斩底图.gd
const 出目录 := "res://测试/截图/连斩"
const 面板脚本 := "res://脚本/界面/连斩面板.gd"
const 块 := Rect2i(185, 15, 230, 200)		# 面板在 (200,36)，往外留一点余量

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	var 狗 := create_timer(60.0, true)
	狗.timeout.connect(func():
		print("看门狗：60 秒没跑完，强退")
		quit(2))
	call_deferred("_run")


func _帧(n := 1) -> void:
	for i in range(n):
		await process_frame


func _红黑占比(图: Image) -> Dictionary:
	var 红 := 0
	var 黑 := 0
	for y in range(图.get_height()):
		for x in range(图.get_width()):
			var c := 图.get_pixel(x, y)
			var r := int(c.r * 255.0)
			var g := int(c.g * 255.0)
			var b := int(c.b * 255.0)
			if r > 90 and r > g * 2 and r > b * 2:
				红 += 1
			elif r < 45 and g < 45 and b < 45:
				黑 += 1
	return {"红": 红, "黑": 黑}


func _拍(面: Control, 比例: float, 名: String, 存: Array) -> void:
	面.call("放进度", 比例)
	await _帧(3)
	var 图 := root.get_texture().get_image()
	var 裁 := 图.get_region(块)
	裁.save_png("%s/底图_%s.png" % [出目录, 名])
	var 计 := _红黑占比(裁)
	print("档 %s：剪影x=%s 红=%d 黑=%d" % [名, str((面.get("红条") as Control).position.x), 计["红"], 计["黑"]])
	存.append(裁)


func _run() -> void:
	var 包 := load(面板脚本)
	var 面: Control = 包.new() as Control
	root.add_child(面)
	await _帧(4)
	面.set_process(false)		# 手动驱动，别让 _process 自己往前攒时间
	面.call("设连斩数", 4)
	await _帧(2)
	print("面板位=%s 底皮位=%s 底皮尺=%s" % [str(面.position),
			str((面.get("黑底") as Control).position), str((面.get("黑底") as Control).size)])
	var 裁: Control = 面.get("红裁")
	print("裁剪框位=%s 尺=%s clip=%s" % [str(裁.position), str(裁.size), str(裁.clip_contents)])
	var 进: Control = 面.get("红条")
	print("剪影位=%s 尺=%s modulate=%s" % [str(进.position), str(进.size), str(进.self_modulate)])
	var 数: Control = 面.get("数字区")
	print("数字区位=%s 尺=%s 子=%d" % [str(数.position), str(数.size), 数.get_child_count()])
	## 分层实拍：把"底皮"和"涂黑的剪影"各藏一次，看这两层各自的覆盖范围对不对。
	## （10-12 用户拿原版 GIF 打回"红色该在黑底里慢慢填"，先证明是哪一层没盖满。）
	var 底: Control = 面.get("黑底")
	面.set("进度条", 进)
	进.position = Vector2(0.0, 0.0)
	底.visible = false
	await _帧(3)
	root.get_texture().get_image().get_region(Rect2i(185, 15, 230, 200)).save_png("%s/分层_只有黑剪影.png" % 出目录)
	底.visible = true
	进.visible = false
	await _帧(3)
	root.get_texture().get_image().get_region(Rect2i(185, 15, 230, 200)).save_png("%s/分层_只有底皮.png" % 出目录)
	进.visible = true
	print("分层图已出")

	var 存: Array = []
	await _拍(面, 1.0, "满黑_刚弹出", 存)
	await _拍(面, 0.75, "四分之三", 存)
	await _拍(面, 0.5, "一半", 存)
	await _拍(面, 0.25, "四分之一", 存)
	await _拍(面, 0.05, "快收", 存)
	var w: int = int(存[0].get_width())
	var h: int = int(存[0].get_height())
	var 条 := Image.create(w * 存.size(), h, false, Image.FORMAT_RGB8)
	for i in range(存.size()):
		条.blit_rect(存[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	条.save_png("%s/底图_条带_本工程.png" % 出目录)
	print("出条带 %s/底图_条带_本工程.png" % 出目录)
	quit(0)
