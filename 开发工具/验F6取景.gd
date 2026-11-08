extends SceneTree

## 临时验证：**这张场景被 F6 单独跑时，① 特效在不在画面中间 ② 动画是不是照原节奏在播**。
## 用户要的就是"F6 一按，像游戏里打坐那样按顺序播"，所以这两条都得量，缺一条就是白改。
## 跑：Godot --path . --script res://开发工具/验F6取景.gd
## ⚠ 不加 --headless（要真视口图像）。验完可删，不是常驻量具。

const 场景 := "res://场景/角色/打坐光环.tscn"
const 出 := "res://测试/截图/打坐/F6取景.png"
const 采毫秒 := 15000		# 第 0 帧自己停 12000 毫秒 ⇒ 必须采过 12 秒才看得见换帧


func _initialize() -> void:
	root.size = Vector2i(960, 560)
	var 景: Node = (load(场景) as PackedScene).instantiate()
	root.add_child(景)
	current_scene = 景		# ★ 这就是 F6 的形状：场景根自己就是 current_scene
	var 环 := 景 as Node2D
	await process_frame
	var 视 := root.size
	print("视口 = ", 视, "  根 position = ", 环.position, "  全显 = ", 环.get("全显"))

	var 起 := Time.get_ticks_msec()
	var 根位集: Dictionary = {}
	var 帧号计: Dictionary = {}
	var 亮列集: Dictionary = {}
	var 首图: Image = null
	var 尾图: Image = null
	var 尾帧号 := -1
	while Time.get_ticks_msec() - 起 < 采毫秒:
		await process_frame
		根位集[环.position] = int(根位集.get(环.position, 0)) + 1
		var 状: Dictionary = 环.call("状态")
		var 号: int = int(状.get("当前帧", -1))
		帧号计[号] = int(帧号计.get(号, 0)) + 1
		var 亮: Array = []
		for i in range(环.get_child_count()):
			var c := 环.get_child(i) as Sprite2D
			if c != null:
				亮.append(c.visible)
		亮列集[str(亮)] = int(亮列集.get(str(亮), 0)) + 1
		if 首图 == null:
			首图 = root.get_viewport().get_texture().get_image()
		if 号 != 尾帧号 and 号 != 0:
			尾帧号 = 号
			尾图 = root.get_viewport().get_texture().get_image()
	首图.save_png(出)
	if 尾图 != null:
		尾图.save_png(出.replace(".png", "_换帧后.png"))

	print("① 动画在播吗：采到的帧号 = ", 帧号计)
	print("② 根位置稳吗：不同取值 ", 根位集.size(), " 个 → ", 根位集.keys())
	print("③ 同时亮几帧：亮帧组合 ", 亮列集.size(), " 种 → ", 亮列集.keys())

	var 红: Array = []
	if 帧号计.size() < 2:
		红.append("采满 %d 毫秒没换过帧 ⇒ 动画没在播" % 采毫秒)
	if 根位集.size() != 1:
		红.append("根位置在动 ⇒ 取景不稳")
	for k in 亮列集.keys():
		var n := 0
		for ch in String(k):
			if ch == "t":
				n += 1
		if n != 1:
			红.append("有一刻同时亮 %d 帧 ⇒ 不是一次只亮一帧" % n)

	var 图 := 首图
	var 底: Color = 图.get_pixel(1, 1)
	var 尺 := 图.get_size()
	var 左 := 尺.x
	var 上 := 尺.y
	var 右 := -1
	var 下 := -1
	for y in range(0, 尺.y, 2):
		for x in range(0, 尺.x, 2):
			var c := 图.get_pixel(x, y)
			if absf(c.r - 底.r) + absf(c.g - 底.g) + absf(c.b - 底.b) > 0.12:
				左 = mini(左, x)
				右 = maxi(右, x)
				上 = mini(上, y)
				下 = maxi(下, y)
	if 右 < 0:
		红.append("整屏与清屏色一模一样 ⇒ F6 里还是看不见")
	else:
		var 心 := Vector2((左 + 右) * 0.5, (上 + 下) * 0.5)
		var 偏 := 心.distance_to(Vector2(尺.x * 0.5, 尺.y * 0.5))
		print("④ 墨迹盒 = (%d,%d)-(%d,%d) 中心 (%d,%d)，距屏幕中心 %.1f 像素" % [
			左, 上, 右, 下, int(心.x), int(心.y), 偏])
		if 偏 > 60.0:
			红.append("墨迹中心偏屏幕中心 %.0f 像素 ⇒ 没居中" % 偏)
	print("出图 ", 出)
	if 红.is_empty():
		print("⇒ F6 取景与播放都对了")
		quit(0)
	for s in 红:
		print("!!红 ", s)
	quit(1)
