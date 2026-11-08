extends SceneTree
## 量「进入游戏」那颗提交转圈**到底几帧在播** —— 用户 2026-10-10 报的是眼睛看到的：
## 「这个特效看起来帧率很低很低」。静态截图量不出来，必须连拍。
##
## 三个数分开量，别混成一个：
##   ① 引擎自身帧率（连拍用了多少秒）—— 整屏卡 ⇒ 特效跟着卡，那不是转圈的锅
##   ② AnimatedTexture 自己报的当前帧号 —— 素材层真正在放第几帧
##   ③ 连拍 36 个引擎帧、每帧裁转圈那块做哈希 —— 画面真的变了几次 = 玩家眼睛拿到的数
##
## 跑法（**不能加 --headless**，无头拿不到视口图像）：
##   Godot --path . --script res://开发工具/量转圈帧率.gd

const 场景路 := "res://场景/界面/窗口/创建角色/创建角色窗.tscn"
const 出目录 := "res://测试/截图/创角"
const 连拍 := 120

var 行: Array[String] = []


func _写() -> void:
	var f := FileAccess.open(出目录 + "/转圈帧率.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()
	for 一 in 行:
		print(一)


func _initialize() -> void:
	_跑()


func _跑() -> void:
	root.size = Vector2i(960, 540)
	var 包 = load(场景路)
	if 包 == null:
		行.append("场景打不开")
		_写()
		quit(1)
		return
	var 窗: Node = 包.instantiate()
	root.add_child(窗)
	for i in 20:
		await process_frame
	var 圈: Node = 窗.get_node_or_null("窗口/提交转圈")
	if 圈 == null:
		行.append("查无 窗口/提交转圈")
		_写()
		quit(1)
		return
	var 皮: Texture = 圈.get("texture")
	行.append("转圈节点 = %s 类=%s 自身矩形=%s" % [圈.name, 圈.get_class(), str(圈.get_rect())])
	行.append("挂的纹理类 = %s  路径 = %s" % [皮.get_class(), str(皮.resource_path)])
	if 皮 is AnimatedTexture:
		var at := 皮 as AnimatedTexture
		# ⚠ 4.7 的 AnimatedTexture **没有** `fps` 这个可直接取属性的键（实测 Invalid access），
		#    一律走 get() 拿 Variant，顺手把属性表打出来 —— 别再照着别的引擎的字段名猜。
		var 名: Array[String] = []
		for p in at.get_property_list():
			var n := str((p as Dictionary).get("name", ""))
			# frame_N/texture|duration 那 512 条不列（会把日志冲掉）；只列开头的标量键
			if not n.begins_with("frame_"):
				名.append(n)
		行.append("AnimatedTexture 的标量属性：%s" % ",".join(名))
		for k in ["frames", "fps", "loop", "frame_duration_mode", "current_frame"]:
			行.append("  %s = %s" % [k, str(at.get(k))])
	var 全: Rect2 = 圈.get_global_rect()
	行.append("全局矩形 = %s" % str(全))
	var 录: Array[String] = []
	var 号录: Array[String] = []
	var 秒零 := Time.get_ticks_msec()
	# ⚠ 4.7 的 Image **没有** get_sha_256()（实测 Nonexistent function）⇒ 直接拿 PNG 字节比，
	#    PackedByteArray 的 == 是逐字节比，够用。
	var 前 := PackedByteArray()
	var 变 := 0
	for i in 连拍:
		await process_frame
		var 图: Image = root.get_texture().get_image()
		var 裁: Image = 图.get_region(Rect2(全.position.round(), 全.size))
		var 块: PackedByteArray = 裁.save_png_to_buffer()
		if i > 0 and 块 != 前:
			变 += 1
		前 = 块
		录.append(str(块.size()))
		号录.append(str((皮 as AnimatedTexture).get("current_frame")) if 皮 is AnimatedTexture else "-")
		if i % 6 == 0:
			图.save_png(出目录 + "/转圈_%02d.png" % i)
	var 秒 := float(Time.get_ticks_msec() - 秒零) / 1000.0
	var 跳 := 0
	for i in range(1, 号录.size()):
		if 号录[i] != 号录[i - 1]:
			跳 += 1
	行.append("连拍 %d 个引擎帧用了 %.2f 秒 ⇒ 引擎帧率 ≈ %.1f（Engine 报 %.1f）"
			% [连拍, 秒, 连拍 / maxf(秒, 0.001), Engine.get_frames_per_second()])
	行.append("画面实际变了 %d 次（占连拍的 %.0f%%）⇒ 眼睛拿到的帧率 ≈ %.1f"
			% [变, 100.0 * 变 / float(连拍), 变 / maxf(秒, 0.001)])
	行.append("纹理帧号推进了 %d 次 ⇒ 素材层 ≈ %.1f fps（场景里钉的是 24）"
			% [跳, 跳 / maxf(秒, 0.001)])
	行.append("帧号序列（前 24 个）：%s" % " ".join(号录.slice(0, 24)))
	_写()
	quit(0)
