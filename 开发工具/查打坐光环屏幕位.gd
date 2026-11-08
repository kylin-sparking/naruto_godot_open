extends SceneTree

## 有头量具：**在游戏里逐引擎帧采样位置**，回答一个问题 ——
## 「同一帧的光环，在屏幕上的位置每次出现是不是同一个」。
##
## 为什么做这个（2026-10-13）：用户在**编辑器**里逐帧切 visible 看九帧，说"都不飘"，
## 但**游戏里**飘。同一批 position 值，编辑器静止、游戏里动 ⇒ 差的一定是"只有运行期才有的东西"：
## 玩家节点自己被物理/落脚点吸附挪（`玩家.gd:1016-1050` 每帧 `position += velocity*delta` 再吸附）、
## 相机每物理帧重算并 `.round()`（`世界相机.gd:116`）、或光环根节点被脚本每帧重摆。
## 这里不认"我推断了什么"，只认采样到的数：**同一帧号出现两次而屏幕位不同 ⇒ 就是它在飘**。
##
## 跑：Godot --path . --script res://开发工具/查打坐光环屏幕位.gd
## ⚠ 不加 --headless（要真实视口与相机）。带看门狗，超时自己 quit。
## ⚠ 会进图 ⇒ 按字节快照 `user://玩家数据.json`、收尾还原并打数。

const 地图场景 := "res://场景/生成/地图_101010000_烘焙.tscn"
const 存档 := "user://玩家数据.json"
## ⚠ **按真实时长采，不按帧数**：第 0 帧自己就要停 12000 毫秒，整圈 12000+7×200=13400。
##   上一版写死"900 拍"，实测那 900 拍只跑了不到 13 秒 ⇒ **全程停在第 0 帧**、
##   一个起气帧都没采到，却报出"位置恒定"的假结论（工具没喂对状态 = 门等于没判）。
const 采样毫秒 := 17000
const 拍上限 := 4000
const 出路 := "res://测试/截图/打坐/运行期采样.txt"

var 起毫秒 := 0
var 帧计数 := 0
var 存前 := PackedByteArray()
var 存前在 := false
var 行们: Array[String] = []


func _看门狗() -> void:
	帧计数 += 1
	if Time.get_ticks_msec() - 起毫秒 > 150000:
		print("!! 看门狗超时（%d 帧）" % 帧计数)
		_写()
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


func _写() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(出路.get_base_dir()))
	var f := FileAccess.open(出路, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行们) + "\n")
		print("采样表 → ", 出路, "（", 行们.size(), " 行）")


func _initialize() -> void:
	起毫秒 = Time.get_ticks_msec()
	_run()


func _run() -> void:
	_快照()
	process_frame.connect(_看门狗)
	root.size = Vector2i(960, 560)
	var 景: Node = (load(地图场景) as PackedScene).instantiate()
	root.add_child(景)
	current_scene = 景
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
		print("!!红 打坐时身上没挂光环节点")
		_还原()
		quit(1)
		return
	# ★ 动画**照常自己推进**（不调 set_process(false)、不手动 _落帧）—— 这量的是玩家看到的那件事。
	var 相机: Node = _找相机(景)
	行们.append("=== 逐引擎帧采样（动画自己播，采满 %d 毫秒）===" % 采样毫秒)
	行们.append("相机找到了：%s  zoom=%s" % [相机 != null, (相机 as Camera2D).zoom if 相机 != null else Vector2.ZERO])

	# 每帧号 → 该帧出现时"当前帧贴图的左上角屏幕坐标"集合，以及玩家 y 集合
	var 按帧屏幕: Dictionary = {}
	var 按帧世界: Dictionary = {}
	var 玩家y集: Dictionary = {}
	var 根全局集: Dictionary = {}
	var 身体屏幕集: Dictionary = {}
	var 相移次: Array = []		# 记录"同一帧号却出现新的屏幕位"的那些次

	var 采样起 := Time.get_ticks_msec()
	var 拍 := 0
	var 帧号计: Dictionary = {}
	while Time.get_ticks_msec() - 采样起 < 采样毫秒 and 拍 < 拍上限:
		拍 += 1
		await _帧(1)
		var 状: Dictionary = 环.call("状态")
		var 号: int = int(状.get("当前帧", -1))
		帧号计[号] = int(帧号计.get(号, 0)) + 1
		var 子: Node2D = 环.call("_帧节点", 号) as Node2D
		var 视: Viewport = root.get_viewport()
		var ct: Transform2D = 视.get_canvas_transform()
		var 全: Vector2 = 子.get_global_position() if 子 != null else Vector2.INF
		var 屏: Vector2 = ct * 全 if 子 != null else Vector2.INF
		var 根全: Vector2 = 环.get_global_position()
		var 玩位: Vector2 = 玩.get_global_position()
		if not 玩家y集.has(玩位.y):
			玩家y集[玩位.y] = 0
		玩家y集[玩位.y] += 1
		if not 根全局集.has(根全):
			根全局集[根全] = 0
		根全局集[根全] += 1
		# 身体（打坐那一帧贴图）的屏幕位 —— 用来判"人和盘是不是一起动"
		var 身: Node2D = 玩.get_node_or_null("OriginalSprite") as Node2D
		if 身 == null:
			for ch in 玩.get_children():
				if ch.get("sprite") is Node2D:
					身 = ch as Node2D
					break
		var 身屏 := Vector2.INF
		if 身 != null:
			var 身节: Node2D = 身.get("sprite") as Node2D
			if 身节 != null:
				身屏 = ct * 身节.get_global_position()
			if not 身体屏幕集.has(身屏):
				身体屏幕集[身屏] = 0
			身体屏幕集[身屏] += 1
		if not 按帧屏幕.has(号):
			按帧屏幕[号] = {}
			按帧世界[号] = {}
		if not 按帧屏幕[号].has(屏):
			按帧屏幕[号][屏] = 0
			相移次.append("帧号 %d 第 %d 拍：**新出现一个屏幕位 %s**（世界 %s）" % [号, 拍, 屏, 全])
		按帧屏幕[号][屏] += 1
		if not 按帧世界[号].has(全):
			按帧世界[号][全] = 0
		按帧世界[号][全] += 1

	行们.append("")
	行们.append("=== 判据〇 采样期间到底播过哪几帧（这条不成立，后面全是假结论）===")
	行们.append("  共采 %d 拍、实际耗时 %d 毫秒；光环 _process 开着吗：%s" % [
		拍, Time.get_ticks_msec() - 采样起, 环.is_processing()])
	for k in 帧号计.keys():
		行们.append("  第 %s 帧被采到 %d 拍" % [k, 帧号计[k]])
	行们.append("  ⇒ 采到的不同帧号 %d 个（帧表共 %d 帧）" % [帧号计.size(), int(环.call("状态").get("帧数", 0))])
	行们.append("")
	行们.append("=== 判据① 玩家节点在打坐期间的位置有没有变（计数口径：不同值的个数）===")
	for k in 玩家y集.keys():
		行们.append("  y = %s 出现了 %d 拍" % [k, 玩家y集[k]])
	行们.append("  ⇒ y 的不同取值 %d 个%s" % [玩家y集.size(), "（**在动！**）" if 玩家y集.size() > 1 else "（静止）"])
	行们.append("")
	行们.append("=== 判据② 光环根节点全局位置 ===")
	for k in 根全局集.keys():
		行们.append("  全局 %s 出现了 %d 拍" % [k, 根全局集[k]])
	行们.append("  ⇒ 不同取值 %d 个" % 根全局集.size())
	行们.append("")
	行们.append("=== 判据③ 核心：同一帧号在屏幕上是不是只有一个位置 ===")
	var 飘帧: Array = []
	for 号 in 按帧屏幕.keys():
		var 集: Dictionary = 按帧屏幕[号]
		行们.append("  第 %s 帧：屏幕位取值 %d 个 → %s" % [号, 集.size(), 集.keys()])
		行们.append("           世界位取值 %d 个 → %s" % [按帧世界[号].size(), 按帧世界[号].keys()])
		if 集.size() > 1:
			飘帧.append(号)
	行们.append("  ⇒ 屏幕上位置不唯一的帧号：%s" % [飘帧])
	行们.append("")
	行们.append("=== 判据④ 身体贴图的屏幕位（人和盘是不是一起动）===")
	for k in 身体屏幕集.keys():
		行们.append("  身体屏幕位 %s 出现了 %d 拍" % [k, 身体屏幕集[k]])
	行们.append("  ⇒ 不同取值 %d 个" % 身体屏幕集.size())
	行们.append("")
	行们.append("=== 所有「同一帧号却换了屏幕位」的时刻 ===")
	for s in 相移次:
		行们.append("  " + s)
	_写()
	_还原()
	var 全帧 := int(环.call("状态").get("帧数", 0))
	var 没喂全 := 帧号计.size() < 全帧
	var 红 := 飘帧.size() > 0 or 玩家y集.size() > 1 or 根全局集.size() > 1 or 没喂全
	print("结论：采到 %d/%d 帧；同一帧号屏幕位不唯一的帧 %s；玩家 y 取值 %d 个；光环根全局取值 %d 个" % [
		帧号计.size(), 全帧, 飘帧, 玩家y集.size(), 根全局集.size()])
	if 没喂全:
		print("⇒ 采样窗口没覆盖整圈（或动画根本没推进）—— **本结论无效**，把 采样毫秒 调大再看")
	elif 红:
		print("⇒ **运行期确实有个东西在挪**（见上面点名的帧）")
	else:
		print("⇒ 每一帧每次出现都在屏幕同一处 ⇒ 飘不是运行期抖动，是帧与帧之间本身不重合")
	quit(1 if 红 else 0)


## 递归找场景里第一个 Camera2D（地图场景的相机可能不是根的直接子件）。
func _找相机(从: Node) -> Node:
	for c in 从.get_children():
		if c is Camera2D:
			return c
		var 深 := _找相机(c)
		if 深 != null:
			return 深
	return null
