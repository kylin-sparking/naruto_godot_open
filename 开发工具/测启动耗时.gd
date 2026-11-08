extends SceneTree

## 量加载耗时。分段打点，别只报一个"总耗时" —— 得知道慢在哪一段。
##
## 用法：
##   Godot --headless --path . --script res://开发工具/测启动耗时.gd
##   Godot --path . --resolution 960x560 --script res://开发工具/测启动耗时.gd -- --开窗

var _开窗 := false
var _起点 := 0


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		if 参数 == "--开窗":
			_开窗 = (_开窗 or true)
	_起点 = Time.get_ticks_msec()
	print("[测加载] 进程起到 _initialize：%d ms" % _起点)
	call_deferred("_跑")


func _跑() -> void:
	var t0 := Time.get_ticks_msec()

	# ── 1. 单例初始化（GameData 那几张必读表在 _init 里读）
	print("[测加载] _跑 开始 t=%d" % (t0 - _起点))

	var 包 := load("res://场景/地图/地图场景.tscn") as PackedScene
	var t1 := Time.get_ticks_msec()
	print("[测加载] load(地图场景.tscn)        %6d ms" % (t1 - t0))

	var 场景 := 包.instantiate()
	var t2 := Time.get_ticks_msec()
	print("[测加载] instantiate                 %6d ms" % (t2 - t1))

	root.add_child(场景)
	var t3 := Time.get_ticks_msec()
	print("[测加载] add_child(跨 _ready)         %6d ms" % (t3 - t2))

	# 等 5 帧，让 _process/_ready 里 deferred 的活跑完
	for _i in 5:
		await process_frame
	var t4 := Time.get_ticks_msec()
	print("[测加载] +5 帧                        %6d ms" % (t4 - t3))
	print("[测加载] === 到能玩为止合计 %d ms ===" % (t4 - _起点))

	if not _开窗:
		quit(0)
		return

	# ── 2. 逐页开窗（多窗口：每页各自的实例）
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		print("[测加载] 没有 窗口管理")
		quit(1)
		return
	for 页 in ["人物", "背包", "忍术", "商城", "NPC商店", "排行榜", "宠物", "装备强化"]:
		var a := Time.get_ticks_msec()
		var 窗: Node = 管理.call("取或建窗口", 页)
		窗.call("open_page", 页)
		var b := Time.get_ticks_msec()
		await process_frame
		await process_frame
		var c := Time.get_ticks_msec()
		print("[测加载] 开 %-6s 建窗+渲染 %5d ms   +2帧 %5d ms" % [页, b - a, c - b])

	quit(0)
