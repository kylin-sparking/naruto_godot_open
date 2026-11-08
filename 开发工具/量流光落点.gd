extends SceneTree
## 一次性量具（不进门禁）：选中流光的**实际落点**到底把没把图标框进去。
##
## 做法：把 65 帧逐个钉住 → 抓视口 → 只取"又亮又白"的像素（流光本体是白括号，
## 图标是红的、底板是灰的，用饱和度就能分开）→ 累成一个并集盒，和图标的矩形比。
##
## 跑法（不要加 --headless）：
##   "godot" --path . --script res://开发工具/量流光落点.gd

const 格号 := 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var 会话 = root.get_node_or_null("GameSession")
	var 槽表: Array = []
	for i in range(10):
		槽表.append({})
	槽表[格号] = {"id": "1001001", "name": "火遁·豪火球", "cooldown": 5.0, "icon": "", "level": 80}
	var 图 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(图)
	await process_frame
	for i in range(30):
		await process_frame
	会话.skill_slots.resize(10)
	for i in range(10):
		会话.skill_slots[i] = {}
	会话.skill_slots[格号] = 槽表[格号]
	会话.call("设默认忍术", 1001001)
	会话.emit_signal("skills_changed", 会话.skill_slots.duplicate(true))
	for i in range(6):
		await process_frame

	var 面板: Node = null
	for 候 in 图.find_children("*", "CanvasLayer", true, false):
		if 候.get_node_or_null("技能栏") != null:
			面板 = 候
			break
	var 栏: Control = 面板.get_node("技能栏") as Control
	var 格: Control = 栏.get_node("SkillShortcut%d" % 格号) as Control
	var 皮: Control = 格.get_node("ShortcutFrame") as Control
	var 图标: Control = 格.get_node("ShortcutFrame/SkillIcon") as Control
	var 光: Control = 格.get_node("选中流光") as Control
	print("[矩形] 格=%s 底板=%s 图标=%s 流光节点=%s" % [
		str(格.get_global_rect()), str(皮.get_global_rect()),
		str(图标.get_global_rect()), str(光.get_global_rect())])

	var 动 := 光.texture as AnimatedTexture
	动.pause = true
	## ⚠ 不能只挑"又亮又白"的像素：格子里本来就有一片白（层数「80」、底板的高光边、
	##   图标自己的浅色），那样量出来的盒是脏的。改成**差分**：先把流光藏掉拍一张底片，
	##   再逐帧拍，`亮起来的` 才是流光自己画上去的。
	光.visible = false
	await process_frame
	await process_frame
	var 底: Image = root.get_texture().get_image()
	var x0 := int(皮.global_position.x)
	var y0 := int(皮.global_position.y)
	var 底片: Array = []
	for y in range(44):
		var 行: Array = []
		for x in range(44):
			var p := 底.get_pixel(x0 + x, y0 + y)
			行.append([p.r, p.g, p.b])
		底片.append(行)
	光.visible = true
	var 左 := 100000
	var 上 := 100000
	var 右 := -1
	var 下 := -1
	var 计 := 0
	## 并集盒会被"转角那几颗"拖大 ⇒ 真正要和原版对的是**亮轨四条边**：
	## 元件 115 的 65 帧逐像素数出来亮点只跑画布第 1/34 行、第 0/33 列（其余行列只有 24~32 颗转角）。
	## 所以这里按行、按列累加命中数，报出峰值落在底板局部哪一行/哪一列。
	var 行计: Array = []
	var 列计: Array = []
	for i in range(44):
		行计.append(0)
		列计.append(0)
	for k in range(动.frames):
		动.current_frame = k
		await process_frame
		await process_frame
		var 像: Image = root.get_texture().get_image()
		for y in range(44):
			for x in range(44):
				var p := 像.get_pixel(x0 + x, y0 + y)
				var q: Array = 底片[y][x]
				# 三个通道都被抬起来 ≥0.18 ⇒ 是"往上叠的白"，不是图标本身的颜色
				if p.r - q[0] > 0.18 and p.g - q[1] > 0.18 and p.b - q[2] > 0.18:
					左 = mini(左, x); 上 = mini(上, y)
					右 = maxi(右, x); 下 = maxi(下, y)
					计 += 1
					行计[y] += 1
					列计[x] += 1
	print("[流光差分] 命中 %d 个像素；并集盒(相对底板左上) = x %d..%d, y %d..%d ⇒ %d×%d" % [
		计, 左, 右, 上, 下, 右 - 左 + 1, 下 - 上 + 1])
	var 峰 := func(计表: Array) -> String:
		var 对: Array = []
		for i in range(计表.size()):
			对.append([计表[i], i])
		对.sort_custom(func(a, b): return a[0] > b[0])
		var 出: Array = []
		for i in range(4):
			出.append("%d:%d" % [对[i][1], 对[i][0]])
		return " ".join(出)
	print("[亮轨] 行峰值(局部行:命中) %s" % 峰.call(行计))
	print("[亮轨] 列峰值(局部列:命中) %s" % 峰.call(列计))
	print("[亮轨判据] 原版 flash 同格实拍量到四条边全在底板局部 3..36 ⇒ 这里四个峰值该是 3/36/3/36")
	print("[对照] 图标相对底板 = %s 尺寸 %s ⇒ 图标盒 x %d..%d, y %d..%d" % [
		str(图标.position), str(图标.size),
		int(图标.position.x), int(图标.position.x + 图标.size.x - 1),
		int(图标.position.y), int(图标.position.y + 图标.size.y - 1)])
	print("[结论口径] 要「把图标框进」⇒ 差分盒应**包住**图标盒且四边余量尽量相等；"
			+ "若某一边为负（流光盒缩进图标里）或左右余量差 ≥2 像素，就是歪")
	# 顺手存三张实机裁图（同一枚图标、指定相位），给 Python 拼「元件合成参照 vs 实机」用
	for k in [8, 24, 40]:
		动.current_frame = k
		await process_frame
		await process_frame
		var 视: Image = root.get_texture().get_image()
		视.get_region(Rect2i(x0 - 3, y0 - 3, 46, 46)).save_png(
				ProjectSettings.globalize_path("res://测试/截图/技能栏/") + "/流光实拍_%02d.png" % k)
	图.queue_free()
	await process_frame
	quit(0)
