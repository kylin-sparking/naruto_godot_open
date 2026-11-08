extends SceneTree

## **实机录制器**：像平时一样登录、进图、点打坐，它把"这圈光环在屏幕上的位置"逐引擎帧记下来。
##
## 为什么需要它（2026-10-13）：我这边所有量具都是**直接摆地图场景 + 代码里调 toggle_practise()**，
## 而你那边是走登录 → 选角 → 进图 → 点按钮 → 服务端回帧。用户实测反馈"你启动游戏实测没有飘、
## 我进入游戏就有了"⇒ 说明差异藏在**我这套环境没有的那部分**（服务端驱动、真实进图链、你站的地点、
## 身上别的特效）。在这种环境里量出来的"位置恒定"证明不了你那边的情况 ⇒ 只能把量具送到现场。
##
## 怎么用：直接跑下面这条，像平时一样进游戏打坐，看个十几秒，
## 然后正常关掉窗口。把 `测试/截图/打坐/实机采样.csv` 给我就行。
##   Godot --path . --script res://开发工具/录打坐屏幕位.gd
##
## ⚠ 不加 --headless（要真实渲染与相机）。⚠ 只往工程目录写一个 csv，**不碰 user://**。

const 登录场景 := "res://场景/界面/登录界面.tscn"
const 出路 := "测试/截图/打坐/实机采样.csv"

var 行们: Array[String] = []
var 拍 := 0
var 起毫秒 := 0
var 上次写 := 0
var 环在 := false


func _initialize() -> void:
	起毫秒 = Time.get_ticks_msec()
	# ⚠ **不写 root.size** —— 这个量具的目的就是"在你自己的窗口尺寸/全屏/DPI 下量"，
	#   把它钉成 960×560 就等于把我那台机器的环境搬过来，量了也白量。
	print("实机录制器已挂上：像平时一样登录进图、点打坐，看十几秒后关掉窗口即可")
	print("现场参数：屏幕=", DisplayServer.screen_get_size(), " 窗口=", root.size,
			" 内容缩放(DPI)=", root.content_scale_factor,
			" 窗口模式=", DisplayServer.window_get_mode())
	行们.append("毫秒,帧号,贴图,玩家x,玩家y,环根x,环根y,当前帧x,当前帧y,屏幕x,屏幕y,相机x,相机y,同时亮几帧,窗口宽,窗口高,画布缩放")
	行们.append("# 屏幕=%s 窗口=%s DPI内容缩放=%s 窗口模式=%s 拉伸=%s/%s" % [
		str(DisplayServer.screen_get_size()), str(root.size), str(root.content_scale_factor),
		str(DisplayServer.window_get_mode()),
		str(ProjectSettings.get_setting("window/stretch/mode", "(未设=disabled)")),
		str(ProjectSettings.get_setting("window/stretch/scale_mode", "(未设)"))])
	change_scene_to_file(登录场景)
	process_frame.connect(_每拍)


func _找玩家() -> Node2D:
	for p in get_nodes_in_group("player"):
		if p is Node2D and is_instance_valid(p):
			return p as Node2D
	return null


func _每拍() -> void:
	拍 += 1
	var 玩 := _找玩家()
	if 玩 == null:
		return
	var 环 := 玩.get_node_or_null("打坐光环") as Node2D
	if 环 == null:
		if 环在:
			行们.append("%d,-------- 光环被摘掉（停止打坐）--------" % (Time.get_ticks_msec() - 起毫秒))
			环在 = false
		return
	if not 环在:
		行们.append("%d,-------- 光环挂上（开始打坐）--------" % (Time.get_ticks_msec() - 起毫秒))
		环在 = true
	var 状: Dictionary = 环.call("状态")
	var 号: int = int(状.get("当前帧", -1))
	var 子: Node2D = 环.call("_帧节点", 号) as Node2D
	var 亮 := 0
	for c in 环.get_children():
		if c is Sprite2D and (c as CanvasItem).visible:
			亮 += 1
	var 全: Vector2 = 子.get_global_position() if 子 != null else Vector2.INF
	var 屏: Vector2 = root.get_viewport().get_canvas_transform() * 全 if 子 != null else Vector2.INF
	var 机 := root.get_viewport().get_camera_2d()
	var 机位 := 机.global_position if 机 != null else Vector2.INF
	行们.append("%d,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%d,%d,%s" % [
		Time.get_ticks_msec() - 起毫秒, 号, String(状.get("贴图名", "")),
		玩.global_position.x, 玩.global_position.y,
		环.global_position.x, 环.global_position.y,
		全.x, 全.y, 屏.x, 屏.y, 机位.x, 机位.y, 亮,
		root.size.x, root.size.y,
		str(root.get_viewport().get_canvas_transform().x.x)])
	# 每 60 拍落一次盘：他随时关窗口也不会把最后十几秒丢掉
	if 拍 - 上次写 > 60:
		上次写 = 拍
		_写()


func _写() -> void:
	var 路 := ProjectSettings.globalize_path("res://") + 出路
	DirAccess.make_dir_recursive_absolute(路.get_base_dir())
	var f := FileAccess.open(路, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行们) + "\n")


func _exit_tree() -> void:
	_写()
	print("采样已写 → ", ProjectSettings.globalize_path("res://") + 出路, "（", 行们.size(), " 行）")
