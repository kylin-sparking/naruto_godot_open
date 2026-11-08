extends SceneTree

## 有头量具：**把游戏里真正渲染出来的九帧连拍下来**，拼成一张图给人眼看。
##
## 为什么还要它（`开发工具/叠九帧看阵.py` 已经能叠素材了）：那张叠的是**位图**，
## 钉没钉对最终要看**游戏画出来的是什么**。这条特效被打回七次的根因就是
## "只改公式、没看过渲染结果"（见记忆 feedback-motion-acceptance）。
##
## 跑：Godot --path . --script res://开发工具/拍九帧连拍.gd
## ⚠ 不加 --headless（无头拿不到视口图像）。带看门狗，超时自己 quit，绝不挂死。
## ⚠ 本量具会进图 ⇒ 动手前按字节快照 `user://玩家数据.json`、收尾还原并打数
##   （口径同 `测试/打坐光环与四钮回归测试.gd`，不还原会让邻居门次日假红）。

const 地图场景 := "res://场景/生成/地图_101010000_烘焙.tscn"
const 出 := "res://测试/截图/打坐/九帧连拍/"
const 存档 := "user://玩家数据.json"
const 框 := 150		# 以角色注册点为中心取 300×300（九帧的盘都在这个范围里）

var 起毫秒 := 0
var 帧数 := 0
var 存前 := PackedByteArray()
var 存前在 := false


func _看门狗() -> void:
	帧数 += 1
	if Time.get_ticks_msec() - 起毫秒 > 90000:
		print("!! 看门狗超时（%d 帧）" % 帧数)
		quit(3)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _快照() -> void:
	存前在 = FileAccess.file_exists(存档)
	if 存前在:
		var g := FileAccess.open(存档, FileAccess.READ)
		存前 = g.get_buffer(g.get_length())


func _还原() -> void:
	if not 存前在:
		if FileAccess.file_exists(存档):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(存档))
			print("动手前没有存档 ⇒ 收尾删掉本量具造的那份")
		else:
			print("动手前后都没有存档")
		return
	var 现 := FileAccess.open(存档, FileAccess.READ)
	var 现字 := 现.get_buffer(现.get_length())
	if 现字 == 存前:
		print("存档没动过")
		return
	var h := FileAccess.open(存档, FileAccess.WRITE)
	h.store_buffer(存前)
	print("存档被本量具改过 ⇒ 已按字节还原")


func _initialize() -> void:
	# ⚠ 入口必须是 `_initialize()`（`测试/打坐光环与四钮回归测试.gd` 用的就是它）。
	#   写成 `_init()` + 里面 await 的这版实测跑满 600 帧也拿不到玩家 —— 引擎不会
	#   等 `_init()` 里那条协程，地图的 spawn 链根本没被推起来。
	起毫秒 = Time.get_ticks_msec()
	_run()


func _run() -> void:
	_快照()
	process_frame.connect(_看门狗)
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出))
	var 景: Node = (load(地图场景) as PackedScene).instantiate()
	root.add_child(景)
	current_scene = 景
	# 有头模式下渲染器与地图资源都要时间 ⇒ 轮询到玩家出现为止（最多 ~10 秒），
	# 别照无头那版写死 60 帧（实测有头 60 帧时组里还是 0 个 ⇒ 直接报"拿不到玩家"）。
	var 们: Array = get_nodes_in_group("player")
	var 试 := 0
	while 们.size() == 0 and 试 < 600:
		await _帧(10)
		们 = get_nodes_in_group("player")
		试 += 10
	if 们.size() == 0:
		print("!!红 拿不到玩家（等了 %d 帧）" % 试)
		_还原()
		quit(1)
		return
	var 玩: Node2D = 们[0] as Node2D
	玩.set("on_ground", true)
	await _帧(20)
	玩.call("toggle_practise")
	await _帧(8)
	var 环: Node = 玩.get_node_or_null("打坐光环")
	if 环 == null:
		print("!!红 没挂上光环节点（打坐时身上没有特效）")
		_还原()
		quit(1)
		return
	环.set_process(false)		# 钉住帧号，逐帧手动摆
	var 屏 := root.get_viewport().get_canvas_transform() * 玩.global_position
	var 心 := Vector2i(int(round(屏.x)), int(round(屏.y)))
	print("角色注册点屏幕位 = ", 屏, " ⇒ 取样中心 ", 心)
	# ⚠ 帧数**从帧表读**，不写死 9：第 8 帧已按用户 2026-10-13 令摘掉不播（场景里节点还在，
	#   但动画只走 0~7）⇒ 写死 9 会把不播的那帧也拍进证据图，看着像"游戏里有九帧"。
	var 帧数 := int(环.call("状态").get("帧数", 9))
	var 列 := 4
	var 裁们: Array = []
	for 号 in range(帧数):
		环.call("_落帧", 号)
		await _帧(4)
		var 全 := root.get_texture().get_image()
		var 裁 := Image.create(框 * 2, 框 * 2, false, Image.FORMAT_RGBA8)
		for y in range(框 * 2):
			for x in range(框 * 2):
				var 全x: int = 心.x - 框 + x
				var 全y: int = 心.y - 框 + y
				if 全x >= 0 and 全y >= 0 and 全x < 全.get_width() and 全y < 全.get_height():
					裁.set_pixel(x, y, 全.get_pixel(全x, 全y))
		裁们.append(裁)
		裁.save_png(出 + ("r_%d.png" % 号))
		var 状: Dictionary = 环.call("状态")
		print("第 %d 帧：%s 画布位置 %s" % [号, 状.get("贴图名"), 状.get("画布位置")])
	var 行 := int(ceil(float(帧数) / float(列)))
	var 拼 := Image.create(框 * 2 * 列 + 20, 框 * 2 * 行 + 20, false, Image.FORMAT_RGBA8)
	拼.fill(Color(0.05, 0.06, 0.09, 1.0))
	for 号 in range(帧数):
		var gx: int = 号 % 列
		var gy: int = 号 / 列
		var 裁: Image = 裁们[号]
		for y in range(框 * 2):
			for x in range(框 * 2):
				拼.set_pixel(gx * (框 * 2 + 5) + 5 + x, gy * (框 * 2 + 5) + 5 + y, 裁.get_pixel(x, y))
		for i in range(框 * 2):
			拼.set_pixel(gx * (框 * 2 + 5) + 5 + i, gy * (框 * 2 + 5) + 5 + 框, Color(1, 1, 1, 0.55))
			拼.set_pixel(gx * (框 * 2 + 5) + 5 + 框, gy * (框 * 2 + 5) + 5 + i, Color(1, 1, 1, 0.55))
	拼.save_png(出 + "连拍九宫格.png")
	print("出图：%s连拍九宫格.png（每格十字交点 = 角色注册点 ⇒ 盘应当九格都在同一处）" % 出)
	_还原()
	quit(0)
