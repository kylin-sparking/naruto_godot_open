extends SceneTree

## 有头量具：**把"底环常驻 + 灵气裁半"这两层各自画成什么样拍下来**，给人眼看。
##
## 为什么要它：这条特效已经被打回六次，我每次都在改公式、却从没**看过**渲染结果。
## 这一把只产出一件事：同一块屏幕矩形下，① 只留底环（灵气藏掉）② 灵气 1~8 帧逐帧亮出来
## 各自一张，外加每张与①的差异包围盒 —— 飘没飘、飘多少，图上直接能看出来。
##
## 跑：Godot --path . --script res://开发工具/拍两层连拍.gd
## ⚠ 不加 --headless（无头拿不到视口图像）。带看门狗，超时自己 quit，绝不挂死。

const 地图场景 := "res://场景/生成/地图_101010000_烘焙.tscn"
const 出 := "res://测试/截图/打坐/两层连拍/"
const 框半 := 130

var 起毫秒 := 0
var 帧数 := 0


func _看门狗() -> void:
	帧数 += 1
	if Time.get_ticks_msec() - 起毫秒 > 90000:
		print("!! 看门狗超时（%d 帧）" % 帧数)
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
	玩.call("toggle_practise")
	await _帧(8)
	var 环: Node = 玩.get_node_or_null("打坐光环")
	if 环 == null:
		print("!!红 没挂上光环节点"); quit(1); return
	环.set_process(false)
	var 灵气: Sprite2D = 环.get("_画") as Sprite2D
	var 底环: Sprite2D = 环.get("_环画") as Sprite2D
	var 屏 := root.get_viewport().get_canvas_transform() * 玩.global_position
	var 心 := Vector2i(int(round(屏.x)), int(round(屏.y)))
	print("角色注册点屏幕位 = ", 屏, " ⇒ 取样中心 ", 心)
	# ① 只留底环
	灵气.visible = false
	await _帧(4)
	var 基: Image = root.get_texture().get_image()
	基.save_png(出 + "a_只底环.png")
	# ② 底环也藏掉 ⇒ 拿到"没有特效"的地面，用来验底环有没有盖住地面
	底环.visible = false
	await _帧(4)
	var 无: Image = root.get_texture().get_image()
	无.save_png(出 + "b_全藏.png")
	底环.visible = true
	灵气.visible = true
	var 红 := 0
	for 号 in range(1, 9):
		环.call("摆灵气", 号)
		await _帧(4)
		var 图: Image = root.get_texture().get_image()
		图.save_png(出 + ("c_灵气%d.png" % 号))
		var 左 := 99999
		var 上 := 99999
		var 右 := -99999
		var 下 := -99999
		var 亮 := 0
		for y in range(maxi(0, 心.y - 框半), mini(560, 心.y + 框半)):
			for x in range(maxi(0, 心.x - 框半), mini(960, 心.x + 框半)):
				if 基.get_pixel(x, y) != 图.get_pixel(x, y):
					亮 += 1
					左 = mini(左, x); 上 = mini(上, y)
					右 = maxi(右, x); 下 = maxi(下, y)
		print("灵气第 %d 帧：相对「只底环」点亮 %d 个像素，差异盒 相对注册点 (%d,%d)~(%d,%d)" % [
			号, 亮, 左 - 心.x, 上 - 心.y, 右 - 心.x, 下 - 心.y])
		if 亮 == 0:
			红 += 1
			print("!!红 灵气第 %d 帧一个像素都没变 ⇒ 这帧没画出来" % 号)
	# ③ 底环自己会不会动：把它单独跟"全藏"比，两次取样必须逐像素相同
	var 差 := 0
	for y in range(maxi(0, 心.y - 60), mini(560, 心.y + 60)):
		for x in range(maxi(0, 心.x - 110), mini(960, 心.x + 110)):
			底环.visible = true
			if 无.get_pixel(x, y) != 基.get_pixel(x, y):
				差 += 1
	print("底环单独点亮 %d 个像素（>0 = 底环确实画出来了）" % 差)
	print("红 %d / 8 帧" % 红)
	print("图在 ", 出)
	quit(0 if 红 == 0 and 差 > 0 else 1)
