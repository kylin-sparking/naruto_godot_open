extends SceneTree
## 一次性量具（不进门禁）：掉落物在地上**真画出来**是什么样子 —— 查用户 10-12 报的三条
##   ① "金币有时图标会直接变纯白" —— 四档钱堆 × 四帧逐张裁下来拼成一张 6 倍图，
##      并且**同位置再拍一张"把图标藏掉"的底片**做差分，才分得清"白"是图标还是背景。
##   ② "大小不对" —— 打图标盒与锚点的关系。原版 `DropItemSprite.render()`：
##      物品 `content.x = -width/2, content.y = -height/2` ⇒ **图标中心 = 锚点**；
##      金币 `content.x = -15, content.y = 15`。锚点 = 落点 y − 15（`:393`）。
##   ③ "不会动" —— 连拍 60 帧看图标的 y 有没有铺开（原版 `tick():478-483`：
##      `contentContainer.y = floor(3*sin(_pastTime/300))`，周期 2π·300ms，
##      落地时 `_pastTime += rnd(0,600)` ⇒ 每枚相位不同）。
##
## 跑法（不要加 --headless，无头拿不到视口图像）：
##   "godot" --path . --script res://开发工具/看掉落物.gd

const 出目录 := "res://测试/截图/掉落物/"
const 表 := [
	{"meso": true, "id": 50}, {"meso": true, "id": 200}, {"meso": true, "id": 700},
	{"meso": true, "id": 1500}, {"meso": false, "id": 16000001}, {"meso": false, "id": 16000135},
	{"meso": false, "id": 99999999},
]
const 格 := 34
const 倍 := 6


func _initialize() -> void:
	call_deferred("_run")


func _找实体(图: Node) -> Node:
	for 候 in 图.find_children("*", "", true, false):
		if 候.has_method("_create_drop_node"):
			return 候
	return null


func _数(像: Image) -> Dictionary:
	var 白 := 0
	var 亮 := 0
	for y in range(像.get_height()):
		for x in range(像.get_width()):
			var c := 像.get_pixel(x, y)
			var M := maxf(c.r, maxf(c.g, c.b))
			if M > 0.55:
				亮 += 1
			if c.r > 0.94 and c.g > 0.94 and c.b > 0.94:
				白 += 1
	return {"白": 白, "亮": 亮}


func _run() -> void:
	var 拼 := Image.create(格 * 倍 * 4, (格 * 倍 + 8) * 表.size(), false, Image.FORMAT_RGBA8)
	拼.fill(Color(0.10, 0.10, 0.12))
	var 图 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(图)
	for i in range(40):
		await process_frame
	var 实体 := _找实体(图)
	if 实体 == null:
		print("[失败] 地图场景里找不到带 `_create_drop_node` 的节点")
		quit(2)
		return
	var 玩家: Node2D = get_first_node_in_group("player") as Node2D
	var 基 := Vector2(400, 300)
	if 玩家 != null:
		基 = 玩家.global_position
	var 排: Array = []
	var 存 = 实体.get("_server_drops")
	for i in range(表.size()):
		var 项: Dictionary = 表[i]
		var 状态 := {
			"object_id": -100 - i, "is_meso": bool(项.meso), "item_id": int(项.id),
			"item_name": "测试物品", "owner_id": 0,
			"x": 基.x - 140 + i * 44, "y": 基.y,
			"from_x": 基.x - 140 + i * 44, "from_y": 基.y, "drop_mode": 0,
		}
		var 掉: Node2D = 实体.call("_create_drop_node", 状态, -100 - i, true)
		实体.get_parent().add_child(掉)
		存[-100 - i] = 掉
		排.append(掉)
	for i in range(70):
		await process_frame
	print("[落地] 锚点 = 掉落物根节点；原版物品的图标**中心**就该落在锚点上")
	for i in range(排.size()):
		var 掉: Node2D = 排[i]
		var 件 := 掉.get_node_or_null("DropIcon") as TextureRect
		var 贴: Texture2D = 件.texture if 件 != null else null
		var 动 := 贴 as AnimatedTexture
		var 尺 := "null"
		if 贴 != null:
			尺 = "%dx%d" % [int(贴.get_width()), int(贴.get_height())]
		var 偏 := 件.global_position - 掉.global_position
		print("  #%d %s id=%-8d 锚点=%s 图标盒=%s 盒左上−锚点=%s 贴图=%s%s" % [
			i, "金币" if bool(表[i].meso) else "物品", int(表[i].id),
			str(掉.global_position), str(件.get_global_rect()), str(偏), 尺,
			"" if 动 == null else "  (AnimatedTexture %d 帧)" % 动.frames])
		var 帧数: int = 1 if 动 == null else 动.frames
		if 动 != null:
			动.pause = true
		for k in range(帧数):
			if 动 != null:
				动.current_frame = k
			await process_frame
			await process_frame
			var 视: Image = root.get_texture().get_image()
			## ⚠ 必须用 `get_screen_position()`：`global_position` 是**画布坐标**，
			##   相机跟着玩家走 ⇒ 拿它去裁视口图会裁到别处（第一版就栽在这，拼出来一片空）。
			var 屏 := 件.get_screen_position()
			var 区 := 视.get_region(Rect2i(int(屏.x), int(屏.y), 格, 格))
			# 底片：把这一枚藏掉再拍，差分出来的才是图标自己
			件.visible = false
			await process_frame
			var 底 := root.get_texture().get_image().get_region(
					Rect2i(int(屏.x), int(屏.y), 格, 格))
			件.visible = true
			var a := _数(区)
			var b := _数(底)
			print("      帧%d 屏上纯白 %3d 亮 %3d | 背景纯白 %3d 亮 %3d ⇒ 图标自己贡献纯白 %3d" % [
				k, a.白, a.亮, b.白, b.亮, maxi(a.白 - b.白, 0)])
			var 块 := 区.duplicate()
			块.convert(Image.FORMAT_RGBA8)
			块.resize(格 * 倍, 格 * 倍, Image.INTERPOLATE_NEAREST)
			拼.blend_rect(块, Rect2i(0, 0, 块.get_width(), 块.get_height()),
					Vector2i(k * 格 * 倍, i * (格 * 倍 + 8)))
		if 动 != null:
			动.pause = false
	var 件0 := 排[0].get_node("DropIcon") as Control
	var 件1 := 排[1].get_node("DropIcon") as Control
	var 取0 := {}
	var 取1 := {}
	## 一圈 = 2π·300 ≈ 1885ms ⇒ 要拍满 120 帧（2 秒）才看得全 ±3 那 6 档
	for k in range(120):
		await process_frame
		取0[roundi(件0.global_position.y)] = true
		取1[roundi(件1.global_position.y)] = true
	var 列 := func(表: Dictionary) -> String:
		var 出: Array = 表.keys()
		出.sort()
		return str(出)
	print("[浮动] 120 帧里第 0 枚图标 y 取值 %s" % 列.call(取0))
	print("[浮动] 同一 120 帧里第 1 枚图标 y 取值 %s" % 列.call(取1))
	print("[浮动判据] 原版 `floor(3*sin(t/300))` ⇒ 一枚该铺开 **6 档**（−3..+2）；"
			+ "两枚的取值集合**不该完全相同**（落地时各加 rnd(0,600) 的随机相位）")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	拼.save_png(ProjectSettings.globalize_path(出目录) + "/掉落物六倍.png")
	print("[出图] %s  %dx%d" % [出目录 + "掉落物六倍.png", 拼.get_width(), 拼.get_height()])
	图.queue_free()
	await process_frame
	quit(0)
