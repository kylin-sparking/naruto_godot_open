extends SceneTree

## 有头量具：**同一个环境，只改窗口模式（窗口 / 全屏），逐引擎帧采"盘的屏幕坐标"**，
## 看全屏会不会让光环逐帧跳像素。
##
## 起因（2026-10-13）：用户报"恢复到默认分辨率就不飘了，我之前一直全屏"。工程是
## `window/stretch/scale_mode="integer"` + 视口 960×560 ⇒ 全屏时缩放倍数取整数、
## 剩余空间按 aspect 处理 ⇒ **世界 1 像素不再等于屏幕 1 像素**，Nearest 采样下
## 半透明的细亮线（八卦阵的边）最容易看出逐帧跳动。这条量具就是把"是不是全屏造成的"钉死。
##
## 跑：Godot --path . --script res://开发工具/查全屏抖不抖.gd
## ⚠ 会真的切全屏几次，会盖住屏幕十几秒 —— 别在写东西时跑。
## ⚠ 会进图 ⇒ 按字节快照 `user://玩家数据.json`、收尾还原。

const 地图场景 := "res://场景/生成/地图_101010000_烘焙.tscn"
const 存档 := "user://玩家数据.json"
const 采毫秒 := 2600		# 三档 ×14.5 秒太久；这一轮要的是"屏幕位落在哪、小数是多少"，2.6 秒足够
const 长采 := false		# 要看整条起气（含换帧）时改成 true

var 存前 := PackedByteArray()
var 存前在 := false
var 起毫秒 := 0
var 拍 := 0


func _看门狗() -> void:
	拍 += 1
	if Time.get_ticks_msec() - 起毫秒 > 200000:
		print("!! 看门狗超时")
		_还原()
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
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if not 存前在:
		return
	var 现 := FileAccess.open(存档, FileAccess.READ)
	if 现.get_buffer(现.get_length()) == 存前:
		print("存档没动过")
		return
	var h := FileAccess.open(存档, FileAccess.WRITE)
	h.store_buffer(存前)
	print("存档已按字节还原")


func _initialize() -> void:
	起毫秒 = Time.get_ticks_msec()
	_run()


## 在当前窗口模式下采一轮：返回 {"屏幕位取值个数": n, "窗口": size, "缩放": canvas 的 x 基}
func _采一轮(环: Node2D, 玩: Node2D, 标签: String) -> Dictionary:
	var 屏集: Dictionary = {}
	var 按帧: Dictionary = {}
	var 小数集: Dictionary = {}		# ★ 真正的病根指标：屏幕位的小数部分。**恒为 .5 = 世界像素被推到
	# 两个屏幕像素正中间** ⇒ Nearest 光栅化每帧各取一边 = 抖。"位置有没有多值"抓不到这种病。
	var 基 := root.get_viewport().get_canvas_transform()
	var 起 := Time.get_ticks_msec()
	var 拍数 := 0
	while Time.get_ticks_msec() - 起 < 采毫秒 and 拍数 < 4000:
		拍数 += 1
		await _帧(1)
		var 状: Dictionary = 环.call("状态")
		var 号: int = int(状.get("当前帧", -1))
		var 子: Node2D = 环.call("_帧节点", 号) as Node2D
		if 子 == null:
			continue
		var 屏: Vector2 = root.get_viewport().get_canvas_transform() * 子.get_global_position()
		屏集[屏] = int(屏集.get(屏, 0)) + 1
		小数集["%.2f/%.2f" % [fposmod(屏.x, 1.0), fposmod(屏.y, 1.0)]] = 1
		if not 按帧.has(号):
			按帧[号] = {}
		按帧[号][屏] = int(按帧[号].get(屏, 0)) + 1
	var 抖帧: Array = []
	for k in 按帧.keys():
		if (按帧[k] as Dictionary).size() > 1:
			抖帧.append("%s:%d种" % [k, (按帧[k] as Dictionary).size()])
	print("── %s ── 窗口=%s  画布基=%s  采 %d 拍" % [标签, root.size, 基, 拍数])
	print("   屏幕位共 %d 种取值；同一帧号却出现多种屏幕位的帧 = %s" % [屏集.size(), 抖帧])
	print("   ★ 屏幕位的小数部分 = %s（{0.00/0.00} = 全落在整数像素上；出现 .5 = 半像素，会抖）" % 小数集.keys())
	return {"窗口": root.size, "屏幕位种数": 屏集.size(), "抖帧": 抖帧, "拍": 拍数,
			"小数": 小数集.keys()}


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
		print("!!红 拿不到玩家")
		_还原()
		quit(1)
		return
	var 玩: Node2D = 们[0] as Node2D
	玩.set("on_ground", true)
	await _帧(20)
	玩.call("toggle_practise")
	await _帧(8)
	var 环: Node2D = 玩.get_node_or_null("打坐光环") as Node2D
	if 环 == null:
		print("!!红 没挂上光环")
		_还原()
		quit(1)
		return

	var 甲 := await _采一轮(环, 玩, "① 窗口 960×560（偶数视口，用户说这样不飘）")
	# ★ 关键对照：**奇数视口**。用户的猜测是"窗口化全屏其实不是 1920×1080，可能是 1908×1080
	#   这类尺寸"⇒ 只要宽或高是奇数，`视口/2` 就带 .5 ⇒ 世界像素被推到两个屏幕像素正中间
	#   ⇒ Nearest 逐帧在两者间取整 = 抖。这一档就是把"奇数"这个变量单独拎出来测。
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(961, 561)
	await _帧(30)
	var 奇 := await _采一轮(环, 玩, "② 窗口 961×561（**奇数视口**，专门造出来做对照）")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await _帧(30)
	var 乙 := await _采一轮(环, 玩, "③ 全屏（用户说这样会飘）")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _帧(20)

	print("")
	print("=== 结论（判据：同一帧号只该有一个屏幕位；出现多种 = 逐帧在跳）===")
	print("偶数视口 960×560 ：屏幕位 %d 种、抖帧 %s" % [甲["屏幕位种数"], 甲["抖帧"]])
	print("奇数视口 961×561 ：屏幕位 %d 种、抖帧 %s" % [奇["屏幕位种数"], 奇["抖帧"]])
	print("全屏 %s ：屏幕位 %d 种、抖帧 %s" % [乙["窗口"], 乙["屏幕位种数"], 乙["抖帧"]])
	var 红: Array = []
	if not 甲["抖帧"].is_empty():
		红.append("偶数视口就在抖 ⇒ 与视口奇偶无关，另找根因")
	if 奇["抖帧"].is_empty():
		红.append("**奇数视口也不抖** ⇒ 要么修复已生效（好），要么这一档没真的变成奇数（看上面打印的窗口尺寸）")
	if 乙["抖帧"] != []:
		红.append("全屏抖 ⇒ 全屏那条假设成立（全屏尺寸=%s，看奇偶）" % 乙["窗口"])
	_还原()
	if 红.is_empty():
		print("⇒ 两种模式都不抖 ⇒ 全屏假设**没被复现**，别再往这条上花时间")
		quit(0)
	for s in 红:
		print("!! " + s)
	quit(1)
