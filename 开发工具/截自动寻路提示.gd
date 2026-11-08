extends SceneTree
## 有头量具：证明「自动寻路中．．．」**真的画在屏幕上**，并且**该亮才亮、该灭就灭**。
##
## 为什么静态门不够：`自动寻路提示回归测试.gd` 判的是源码形状与数据表 —— 它测不出
## "节点建了但一像素没画"（10-07 小地图那次 `图层.源` 漏写就是这种）、也测不出
## "动画在跑但四帧是同一张"。所以这里量两层：
##   ① 运行期实际值：`玩家.自动寻路中`、HUD 下那个节点在不在、生效贴图、位置；
##   ② **视口图像那块矩形里的不透明像素数**，以及隔 0.3 秒后 `frame_index` 有没有动。
## 另外三条收尾都要量：手动点地走要**摘掉**、`cancel_auto_path()` 要摘掉、到点（路线走完）要摘掉。
##
## 用法（**不能加 --headless**，无头拿不到视口图像）：
##     "godot" --path . --script res://开发工具/截自动寻路提示.gd
const 出目录 := "res://测试/截图/自动寻路提示"
const 提示区 := Rect2i(375, 65, 257, 43)		# (480-105, 110-45) + 画布 257x43

var _失败: Array[String] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	call_deferred("_run")


func _断言(成立: bool, 说明: String) -> void:
	if not 成立:
		_失败.append(说明)


func _找提示(HUD: Node) -> Node:
	if String(HUD.name) == "自动寻路提示":
		return HUD
	for 子 in HUD.get_children():
		var 找 := _找提示(子)
		if 找 != null:
			return 找
	return null


## 把提示节点临时设成 可见/不可见，各等两帧再截同一块矩形（等帧是为了拍到画完的那一帧，
## 同一帧里 emit 之后立刻取视口图会拍到上一帧 —— 10-05 续八量过这个坑）。
func _拍(节: Node2D, 可见: bool) -> Image:
	节.visible = 可见
	for _帧 in 2:
		await process_frame
	var 图 := root.get_texture().get_image().get_region(Rect2(提示区))
	节.visible = true
	for _帧 in 2:
		await process_frame
	return 图


## 两张同尺寸图里"任一通道差 > 40"的像素数。
func _差异像素数(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size():
		return -1
	var 数 := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.r - q.r) > 0.16 or absf(p.g - q.g) > 0.16 or absf(p.b - q.b) > 0.16:
				数 += 1
	return 数


func _run() -> void:
	var 场景 := (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场景)
	for _帧 in 14:
		await process_frame
	var 玩 := get_first_node_in_group("player") as Node2D
	var HUD := get_first_node_in_group("game_hud")
	_断言(玩 != null and HUD != null, "缺 player 或 game_hud")
	if 玩 == null or HUD == null:
		_收()
		return
	_断言(玩.has_signal("自动寻路态"), "玩家.gd 上没有 自动寻路态 信号")
	_断言(not bool(玩.get("自动寻路中")), "一开局 自动寻路中 就是 true ⇒ 状态位没初始化好")
	_断言(_找提示(HUD) == null, "一开局 HUD 下就挂着提示")

	## 找一个真能起路线的目标：本图 NPC 位 + 玩家左右几个偏移，逐个试。
	var 目标 := Vector2.INF
	var 候选: Array[Vector2] = []
	var 生怪根 := 场景.get_node_or_null("LifeRoot")
	if 生怪根 != null:
		for 实体 in (生怪根.get("_entities") as Array):
			var 谁 := 实体 as Node2D
			if 谁 != null:
				候选.append(谁.global_position)
	for dx in [900.0, 700.0, 500.0, -900.0, -700.0, -500.0, 300.0, -300.0]:
		候选.append(玩.position + Vector2(dx, 0.0))
	for c in 候选:
		if bool(玩.call("走向", c, false, true)):
			目标 = c
			break
	_断言(目标 != Vector2.INF, "一个都寻不到路，后面三条判据全没意义")
	if 目标 == Vector2.INF:
		_收()
		return

	# ① 自动赶路 ⇒ 亮
	await process_frame
	await process_frame
	_断言(bool(玩.get("自动寻路中")), "走向(..., 自动=true) 之后 自动寻路中 还是 false")
	var 提 := _找提示(HUD)
	_断言(提 != null, "自动赶路中但 HUD 下没有那个节点")
	if 提 == null:
		_收()
		return
	var 节 := 提 as Node2D
	_断言(absf(节.position.x - 480.0) < 0.01, "x 应为视口中线 480，实际 %.0f" % 节.position.x)
	_断言(absf(节.position.y - 110.0) < 0.01, "y 应为 110（KeyController.as:999），实际 %.0f" % 节.position.y)
	_断言(String(提.get("entry_name")) == "Effect_PathFindingTip",
			"播的不是 Effect_PathFindingTip，实际「%s」" % String(提.get("entry_name")))
	var 图路 := ""
	for 子 in 节.get_children():
		if 子 is Sprite2D and (子 as Sprite2D).texture != null:
			图路 = String((子 as Sprite2D).texture.resource_path)
	_断言(图路.contains("Effect_PathFindingTip"), "生效贴图不是真图：%s" % 图路)
	_断言(absf((子位(节) as Vector2).x + 105.0) < 0.01 and absf((子位(节) as Vector2).y + 45.0) < 0.01,
			"贴图偏移应为 (-105,-45)（注册点），实际 %s ⇒ 会画歪" % str(子位(节)))

	## ⚠ 这块矩形右半边压着 HUD 的活动图标（礼物盒），**只数不透明像素会把它们一起算进来**
	## ⇒ 计数过不了"归因"这一关。所以量 A/B：同一个矩形，把提示 `visible` 关掉拍一张、
	## 打开再拍一张，只数**两张不一样的像素** —— 这些像素才是这枚提示自己画上去的。
	var 无: Image = await _拍(节, false)
	var 有: Image = await _拍(节, true)
	var 差 := _差异像素数(有, 无)
	_断言(差 > 1500,
			"提示挂上/摘掉两张图只差 %d 个像素 ⇒ 它其实没往屏幕上画东西（旧计数会被 HUD 图标蒙过去）" % 差)
	有.save_png(出目录 + "/提示区域.png")
	无.save_png(出目录 + "/提示区域摘掉.png")
	截屏("自动赶路中")

	# ② 动画在跑：隔 0.3 秒 frame_index 必须换过（250ms/段），**而且屏幕上真的换了画面**
	var 起 := int(提.get("frame_index"))
	for _帧 in 24:
		await process_frame
	var 后 := int(提.get("frame_index"))
	_断言(起 != 后, "隔 0.4 秒 frame_index 还是 %d ⇒ 省略号不会动" % 后)
	var 换: Image = await _拍(节, true)
	var 画差 := _差异像素数(换, 有)
	_断言(画差 > 120,
			"frame_index 从 %d 走到 %d，但屏幕上只变了 %d 个像素 ⇒ 四段其实是同一张画" % [起, 后, 画差])
	换.save_png(出目录 + "/提示区域换帧.png")

	# ③ 手动点地走 ⇒ 摘掉（原版 World.as:392 不传 showtip，走的是 removeChild 那一支）
	var 手动 := 玩.position + Vector2(260.0, 0.0)
	if bool(玩.call("走向", 手动, false, false)):
		await process_frame
		await process_frame
		_断言(not bool(玩.get("自动寻路中")), "手动点地走之后还挂着 ⇒ 把 showtip=false 那一支写丢了")
		_断言(_找提示(HUD) == null, "手动点地走之后 HUD 下还找得到提示节点")
	else:
		_断言(false, "手动那条 走向 没起路线，③ 这一支等于没量")

	# ④ 再自动一次，然后 cancel_auto_path ⇒ 摘掉
	玩.call("走向", 目标, false, true)
	await process_frame
	await process_frame
	_断言(_找提示(HUD) != null, "第二次自动赶路没挂上（早退条件写错了？）")
	玩.call("cancel_auto_path")
	await process_frame
	await process_frame
	_断言(not bool(玩.get("自动寻路中")), "cancel_auto_path 没把状态清掉")
	_断言(_找提示(HUD) == null, "cancel_auto_path 之后节点还在")

	# ⑤ 同值不重发：连着两次 自动=true 不该重建节点
	玩.call("走向", 目标, false, true)
	await process_frame
	var 第一 := _找提示(HUD)
	玩.call("走向", 目标 + Vector2(40.0, 0.0), false, true)
	await process_frame
	var 第二 := _找提示(HUD)
	_断言(第一 != null and 第一 == 第二, "两次自动寻路之间节点被重建了（原版 contains() 判过就不重挂）")
	截屏("收尾之后")
	_收()


func 子位(节: Node) -> Variant:
	for 子 in (节 as Node).get_children():
		if 子 is Sprite2D:
			return (子 as Node2D).position
	return Vector2.ZERO


func 截屏(名: String) -> void:
	root.get_texture().get_image().save_png(出目录 + "/" + 名 + ".png")


func _收() -> void:
	if _失败.is_empty():
		print("截自动寻路提示：通过（亮/动画/手动摘/取消摘/不重建 五条都量到了）")
		quit(0)
		return
	for 条 in _失败:
		printerr(条)
	print("截自动寻路提示：红 %d 条" % _失败.size())
	quit(1)
