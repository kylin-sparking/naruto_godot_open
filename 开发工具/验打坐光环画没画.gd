extends SceneTree

## 有头量具（不是门禁）：**打坐时光环到底画没画到屏幕上**。
##
## 为什么要有它：`测试/打坐光环与四钮回归测试.gd` 里"贴图挂上了"判的是
## `_画.texture != null` —— 那是**节点属性**，不是**像素**。用户实机反馈"没看到特效"，
## 而门全绿 ⇒ 判据没覆盖到渲染层（"门全绿≠做完"那一族，10-12 连斩也栽过一次）。
## 这一把只认一件事：**同一块屏幕矩形，坐下前 / 坐下后，差了多少个像素**。差 0 = 没画出来。
##
## 跑：Godot --path . --script res://开发工具/验打坐光环画没画.gd
## ⚠ 不加 --headless（无头拿不到视口图像）。带看门狗：超时会自己 quit，绝不挂死。

const 地图场景 := "res://场景/生成/地图_101010000_烘焙.tscn"
const 出 := "res://测试/截图/打坐/画没画/"
const 框半 := 130					# 以角色注册点为中心，左右各取这么多像素

var 拍过的帧 := 0
var 起毫秒 := 0


## ⚠ `extends SceneTree` 的脚本**不许定义 `_process`** —— SceneTree 自己有一个
## `_process(float) -> bool`，签名对不上会直接 parse 失败（实测报
## "The function signature doesn't match the parent"）。看门狗挂到 `process_frame` 信号上。
func _看门狗() -> void:
	拍过的帧 += 1
	if Time.get_ticks_msec() - 起毫秒 > 90000:
		print("!! 看门狗超时（跑了 %d 帧 / 90 秒）⇒ 强制退出，绝不挂死" % 拍过的帧)
		quit(3)


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	起毫秒 = Time.get_ticks_msec()
	process_frame.connect(_看门狗)
	root.size = Vector2i(960, 560)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出))
	var 景: Node = (load(地图场景) as PackedScene).instantiate()
	root.add_child(景)
	current_scene = 景
	await _帧(60)
	var 们 := get_nodes_in_group("player")
	if 们.size() == 0:
		print("!!红 拿不到玩家"); quit(1); return
	var 玩: Node2D = 们[0] as Node2D
	玩.set("on_ground", true)
	await _帧(20)

	var 屏 := root.get_viewport().get_canvas_transform() * 玩.global_position
	var 心 := Vector2i(int(屏.x), int(屏.y))
	print("角色注册点屏幕位 =", 屏, " 取样框 = 中心 ±", 框半)

	# ── 拍"坐下前" ──
	var 前 := root.get_texture().get_image()
	前.save_png(出 + "1_坐下前.png")
	# 把世界藏起来再拍一张"只有背景"的？不用——这里只比同一块矩形。

	# ── 坐下 ──
	玩.call("toggle_practise")
	await _帧(4)
	var 环 := 玩.get_node_or_null("打坐光环")
	print("光环节点在不在：", 环 != null)
	if 环 == null:
		print("!!红 根本没挂上光环节点（那是接线问题，不是渲染问题）"); quit(1); return
	# 这一张停在第 0 帧（原版那一帧本来停 12 秒），所以"坐下前后"的差异只可能是光环画出来的
	var 后 := root.get_texture().get_image()
	后.save_png(出 + "2_坐下后第0帧.png")

	var 状: Dictionary = 环.call("状态")
	print("光环状态：", 状)
	print("全局位=", (环 as Node2D).global_position, " 变换=", (环 as Node2D).global_transform,
			" 在树里可见=", (环 as CanvasItem).is_visible_in_tree(),
			" modulate=", (环 as CanvasItem).modulate, " self=", (环 as CanvasItem).self_modulate,
			" z=", (环 as CanvasItem).z_index, " 层=", (环 as CanvasItem).get_parent().name)
	var 画: Sprite2D = 环.get("_画") as Sprite2D
	print("里面那张图：有效=", is_instance_valid(画), " id=", 画.get_instance_id(),
			" 局部位=", 画.position, " 全局位=", 画.global_position,
			" texture=", 画.texture, " 可见=", 画.visible, " 在树可见=", 画.is_visible_in_tree(),
			" z=", 画.z_index, " self_modulate=", 画.self_modulate,
			" 中心=", 画.centered, " 父=", 画.get_parent(), " 父的父=", 画.get_parent().get_parent())
	print("  子件清单：", 环.get_children())
	# 角色本体那一坨的屏幕范围，用来核对"光环应该落在哪"
	var 身: Node2D = 玩.get("player_sprite") as Node2D
	if 身 != null:
		print("身体精灵：全局位=", 身.global_position, " 局部位=", 身.position, " z=", 身.z_index,
				" 纹理=", 身.get("texture"))

	# ── 同一块矩形逐像素比 ──
	var 差 := 0
	var 判 := 0
	var 差包: Rect2i = Rect2i()
	for y in range(maxi(0, 心.y - 框半), mini(560, 心.y + 框半)):
		for x in range(maxi(0, 心.x - 框半), mini(960, 心.x + 框半)):
			判 += 1
			if 前.get_pixel(x, y) != 后.get_pixel(x, y):
				差 += 1
				if 差 == 1:
					差包 = Rect2i(x, y, 0, 0)
				else:
					差包 = 差包.expand(Vector2i(x, y))
	print("取样 %d 个像素，坐下前后不同 = %d 个（%.2f%%）" % [判, 差, 100.0 * 差 / maxf(1.0, float(判))])
	if 差 > 0:
		print("   差异包围盒：", 差包)
	var 过 := 差 > 判 / 40.0
	print(("ok  " if 过 else "!!红 ") + "坐下前后同一块屏幕差 %d 个像素（取样 %d 的 %.1f%%，门槛 2.5%%）⇒ %s" % [差, 判, 100.0 * 差 / float(判), "画出来了" if 过 else "光环根本没画到屏幕上"])

	# 再逼它换到第 1 帧（最大那一圈），又拍一次
	环.set_process(true)
	环.set("_剩毫秒", 1.0)
	await _帧(5)
	var 又 := root.get_texture().get_image()
	又.save_png(出 + "3_第1帧.png")
	var 差2 := 0
	for y in range(maxi(0, 心.y - 框半), mini(560, 心.y + 框半)):
		for x in range(maxi(0, 心.x - 框半), mini(960, 心.x + 框半)):
			if 后.get_pixel(x, y) != 又.get_pixel(x, y):
				差2 += 1
	print("第0帧→第1帧 同一块矩形差异像素 = %d（换帧到底有没有改变画面）" % 差2)
	print("图在 ", 出)
	quit(0 if 过 else 1)
