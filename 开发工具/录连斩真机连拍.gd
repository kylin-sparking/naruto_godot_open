extends SceneTree
## 有头连拍：在真地图场景 + 真 HUD 里，按玩家视角把连斩底图**每 0.5 秒一张拍满 16 秒**，
## 中途喂三次连斩数（模拟连续击杀 —— 原版每次 setCount 都会把 pastTime 归零）。
##
## 为什么要它：用户 10-12 说"做的还是不对，不是整图消失啊"。我此前只拍了 5 个稀疏档，
## 看不出一段连续过程里"哪一帧整块没了"。连拍才能复现他眼睛看到的东西。
##
## 用法（**不能加 --headless**）：
##     "godot" --path . --script res://开发工具/录连斩真机连拍.gd
const 出目录 := "res://测试/截图/连斩/连拍"
const 块 := Rect2i(185, 15, 230, 200)
const 间隔 := 0.5
const 总秒 := 16.0
const 喂点 := {0.0: 22, 4.0: 23, 8.5: 24}		# 模拟"砍三下"，每次都该把条重置成满黑

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出目录))
	var 狗 := create_timer(120.0, true)
	狗.timeout.connect(func():
		print("看门狗：120 秒没跑完，强退")
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


func _run() -> void:
	var 图 = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(图)
	await _帧(20)
	var 面 := _找面板(root)
	if 面 == null:
		print("连拍：HUD 里没有连斩面板")
		quit(1)
		return
	var 起 := Time.get_ticks_msec()
	var 已喂 := {}
	var k := 0
	var t := 0.0
	while t <= 总秒:
		for 点在 in 喂点.keys():
			if not 已喂.has(点在) and t >= float(点在):
				面.call("收到连斩数", 喂点[点在])
				已喂[点在] = true
				print("  ↑ t=%.1fs 喂进连斩数 %d（该重置成满黑）" % [t, 喂点[点在]])
		await _帧(2)
		t = float(Time.get_ticks_msec() - 起) / 1000.0
		var 红: Control = 面.get("红条")
		var 黑: Control = 面.get("黑底")
		var 窗: Control = 面.get("黑裁")
		## 关键三列：红.x 该恒 0（红不许动）、黑全局左缘该恒等于面板左缘（黑在屏幕上一动不动）、
		## 只有"擦除量"（窗.x）在涨。
		print("拍 %02d t=%4.1fs 可见=%s 红.x=%5.2f 黑全局左缘=%7.2f 擦除量=%6.2f 窗宽=%6.2f 攒=%s" % [
				k, t, str(面.visible), 红.position.x, 黑.get_global_position().x,
				窗.position.x, 窗.size.x, str(int(float(面.get("攒下的毫秒"))))])
		root.get_texture().get_image().get_region(块).save_png("%s/%02d_t%05.1fs.png" % [出目录, k, t])
		k += 1
		var 目标: float = k * 间隔
		while float(Time.get_ticks_msec() - 起) / 1000.0 < 目标:
			await process_frame
	print("连拍完：%d 张 → %s" % [k, 出目录])
	quit(0)
