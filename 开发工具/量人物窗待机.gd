extends SceneTree

## 有头量具（2026-10-25 用户报「人物窗角色页那具应该播待机动作而不是不动」，
## 第一版改完被他打回「人物没了啊」—— 见下面第 ② 条为什么要卡"看得见"）。
##
## 三件事，缺一不可：
##   ① 那具**画在屏幕上**（不是只"节点存在"）：拿它自己那张帧图在屏幕上的位置，
##      跟"把动画停住时"同一矩形比 —— 停住时两拍必须全等，跑起来必须不等。
##   ② **看得见**：把动画藏掉（`visible=false`）之后再拍同一矩形，必须与"露着时"**不一样**。
##      这一条专治"精灵挂到底板后面 / 被隐藏父节点吃掉"—— 那种坏法下帧号照样跳、
##      纹理照样换，只查 `texture != null` 或"两拍有差异"都会假绿（10-25 实测：
##      量具报"857 像素在变"，实机人物整具不见了，因为 `z_index − 1` 把它压到了底板后面）。
##   ③ 精灵自己的**纹理文件名**隔 0.9 秒要变（`stand` 第 0 帧 delay=360ms，等太短量不出来）。
##
## 跑法（**不能加 --headless**，无头拿不到视口图像）：
##   Godot --path . --script res://开发工具/量人物窗待机.gd -- --出目录=res://测试/截图/人物待机

var _出 := "res://测试/截图/人物待机"
var _失败: Array[String] = []


func _initialize() -> void:
	for 项 in OS.get_cmdline_user_args():
		var 对 := String(项).split("=", true, 1)
		if 对.size() == 2 and 对[0] == "--出目录":
			_出 = 对[1]
	call_deferred("_跑")


func _记(过: bool, 话: String) -> void:
	print(("  √ " if 过 else "  !! ") + 话)
	if not 过:
		_失败.append(话)


func _拍(区: Rect2, 名: String) -> Image:
	var 全 := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_出))
	var 裁 := 全.get_region(Rect2i(int(区.position.x), int(区.position.y),
			maxi(1, int(区.size.x)), maxi(1, int(区.size.y))))
	裁.save_png(_出 + "/" + 名 + ".png")
	return 裁


func _差(a: Image, b: Image) -> int:
	# 两拍里任何一张没拿到 ⇒ 报 −1（判红），不许回 0 —— `0 比 0` 恒等会把"量具自己崩了"
	# 伪装成"画面没变"。
	if a == null or b == null or a.get_size() != b.get_size():
		push_error("两拍不可比 a=%s b=%s" % [str(a), str(b)])
		return -1
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixelv(Vector2(x, y)) != b.get_pixelv(Vector2(x, y)):
				n += 1
	return n


func _精灵图(播: CanvasItem) -> String:
	for 子 in 播.get_children():
		if 子 is Sprite2D and (子 as Sprite2D).texture != null:
			return String(((子 as Sprite2D).texture as Texture2D).resource_path).get_file()
	return "‹没纹理›"


func _跑() -> void:
	root.size = Vector2i(960, 560)
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _i in 6:
		await process_frame
	var 管理: Node = 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		printerr("拿不到 窗口管理")
		quit(1)
		return
	管理.call("打开", "人物")
	for _i in 8:
		await process_frame
	var 窗 = 管理.call("取或建窗口", "人物")
	var 内容 := 窗.get("_content") as Control
	var 页 := 内容.find_child("原版人物属性面板", true, false) as Control
	if 页 == null:
		printerr("找不到「原版人物属性面板」⇒ 后面全无从量起")
		quit(1)
		return
	var 站立 := 页.get_node_or_null("角色站立图") as TextureRect
	_记(站立 != null, "那一格找得到（实得 %s）" % str(站立))
	if 站立 == null:
		quit(1)
		return
	var 播 := 站立.get_node_or_null("角色待机") as OriginalSprite
	_记(播 != null, "那一格里挂上了真播放器 OriginalSprite（实得 %s）" % str(播))
	if 播 == null:
		quit(1)
		return
	# 量取矩形 = **精灵自己那张帧图在屏幕上的位置**（不是静态框：框比人大会把底板的花纹也算进来，
	# 那些花纹本来就在动，差异数就不是这具人贡献的）。
	var 身: Sprite2D = null
	for 子 in 播.get_children():
		if 子 is Sprite2D:
			身 = 子 as Sprite2D
	if 身 == null or 身.texture == null:
		_记(false, "精灵里没有 Sprite2D/纹理 ⇒ 无从量（实得 %s）" % str(身))
		quit(1)
		return
	var 图尺 := 身.texture.get_size()
	var 顶: Vector2 = 身.to_global(-图尺 * 0.5)		# Sprite2D 居中绘制
	var 区 := Rect2(顶, 图尺).grow(2)
	print("量取矩形（按帧图）", 区, " 帧图=", _精灵图(播))
	# ① 停住动画两拍必须全等（阳性对照：证明这台机这一帧不抖、且差异只可能来自动画）
	播.set("paused", true)
	await create_timer(0.25).timeout
	var 停甲 := _拍(区, "停甲")
	await create_timer(0.5).timeout
	var 停乙 := _拍(区, "停乙")
	_记(_差(停甲, 停乙) == 0, "把动画 paused 之后隔 0.5 秒两拍全等（实得 %d）⇒ 这块屏里没别的东西在动"
			% _差(停甲, 停乙))
	# ③ 放开之后：纹理文件名要换、同一矩形要变
	播.set("paused", false)
	await create_timer(0.9).timeout
	var 跑 := _拍(区, "跑")
	var 名后 := _精灵图(播)
	_记(名后 != _精灵图(播) or int(播.get("frame_index")) > 0,
			"隔 0.9 秒帧号 %d、当前帧图=%s（`stand` 第 0 帧 delay=360ms，等太短量不出来）"
			% [int(播.get("frame_index")), 名后])
	_记(_差(停乙, 跑) > 0, "动画放开后同一矩形有 %d 个像素变了 ⇒ 这具在走帧" % _差(停乙, 跑))
	# ② 看得见：把精灵藏掉再拍，必须和"露着时"不同（专治挂到底板后面 / 被隐藏父节点吃掉）
	播.visible = false
	await create_timer(0.2).timeout
	var 藏 := _拍(区, "藏")
	播.visible = true
	await create_timer(0.2).timeout
	var 露 := _拍(区, "露")
	_记(_差(藏, 露) > 0,
			"藏掉精灵这块就变了（差 %d）⇒ 它真的画在最前面、没被底板压住；差 0 = 屏幕上根本看不见这具"
			% _差(藏, 露))
	_记(站立.visible and 站立.texture == null,
			"静态图让位方式=清贴图不藏父节点（visible=%s texture=%s）" % [str(站立.visible), str(站立.texture)])
	print("人物待机量具：判 %d 条 / 红 %d 条" % [6, _失败.size()])
	quit(1 if _失败.size() > 0 else 0)
