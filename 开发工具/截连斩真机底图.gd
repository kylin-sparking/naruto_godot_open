extends SceneTree
## 有头量具：在**真地图场景 + 真 HUD**里看连斩底图随倒计时怎么变。
##
## 为什么还要这一支：`截连斩底图.gd` 是把面板单独 new 出来拍的（背景是纯色），
## 用户 10-12 拿原版 GIF 打回"红该在黑底里慢慢填"——单独 new 那一版**是填的**，
## 所以差异只可能出在"挂进真 HUD 之后"（父层裁剪 / 层级 / modulate / 每帧 delta 太大）。
## 这里就把场景原样跑起来，喂一次 22 连斩，然后在 15 秒窗口里连拍五张。
##
## 用法（**不能加 --headless**）：
##     "godot" --path . --script res://开发工具/截连斩真机底图.gd
const 出目录 := "res://测试/截图/连斩"
const 块 := Rect2i(185, 15, 230, 200)
const 秒点 := [0.1, 3.0, 7.5, 12.0, 14.5]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	var 狗 := create_timer(90.0, true)
	狗.timeout.connect(func():
		print("看门狗：90 秒没跑完，强退")
		quit(2))
	call_deferred("_run")


func _帧(n := 1) -> void:
	for i in range(n):
		await process_frame


func _找面板(节: Node) -> Node:
	var 脚 = 节.get_script()
	if 脚 != null and String(脚.resource_path) == "res://脚本/界面/连斩面板.gd":
		return 节
	for 子 in 节.get_children():
		var 找 := _找面板(子)
		if 找 != null:
			return 找
	return null


func _收面板(节: Node, 出: Array) -> void:
	var 脚 = 节.get_script()
	if 脚 != null and String(脚.resource_path) == "res://脚本/界面/连斩面板.gd":
		出.append(节)
	for 子 in 节.get_children():
		_收面板(子, 出)


func _拍(名: String) -> void:
	root.get_texture().get_image().get_region(块).save_png("%s/真机_%s.png" % [出目录, 名])


func _run() -> void:
	var 图 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(图)
	await _帧(20)
	var 面 := _找面板(root)
	if 面 == null:
		print("真机：HUD 里没找到连斩面板 ⇒ 这一支没接线")
		quit(1)
		return
	print("真机：找到面板，挂在 %s" % str(面.get_path()))
	# ① 树里到底有几个连斩面板（两个叠在一起会互相盖住，看着就像"黑没盖满"）
	var 全: Array = []
	_收面板(root, 全)
	print("真机：树里连斩面板个数 = %d" % 全.size())
	for k in range(全.size()):
		print("   [%d] %s 位=%s 可见=%s" % [k, str(全[k].get_path()), str(全[k].position), str(全[k].visible)])
	# ② 两层的实际全局矩形与父层裁剪
	for 键 in ["黑底", "红裁", "红条"]:
		var 节: Control = 面.get(键)
		print("   %-4s 局=%s 尺=%s 全=%s 父=%s 父clip=%s 父尺=%s" % [键, str(节.position), str(节.size),
				str(节.get_global_rect()), str(节.get_parent().name),
				str(节.get_parent().clip_contents), str((节.get_parent() as Control).size)])
	var 底: Control = 面.get("黑底")
	var 进0: Control = 面.get("红条")
	面.call("收到连斩数", 22)
	await _帧(2)
	底.visible = false
	await _帧(2)
	_拍("分层_只黑剪影")
	底.visible = true
	进0.visible = false
	await _帧(2)
	_拍("分层_只底皮")
	进0.visible = true
	await _帧(2)
	await _帧(2)
	var 起 := Time.get_ticks_msec()
	for s in 秒点:
		var 等: float = s - float(Time.get_ticks_msec() - 起) / 1000.0
		if 等 > 0.0:
			await create_timer(等).timeout
		var 进: Control = 面.get("红条")
		print("t=%.1fs 剪影x=%s 攒=%s 窗口=%s 可见=%s" % [s, str(进.position.x),
				str(面.get("攒下的毫秒")), str(面.get("窗口毫秒")), str(面.visible)])
		_拍("%05.1fs" % s)
	quit(0)
