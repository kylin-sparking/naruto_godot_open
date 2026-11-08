extends SceneTree

## 有头量具：**把"镜头一抖一抖"量成直方图**，不再靠眼睛吵。
##
## 起因（2026-10-23）：用户报"镜头跟随移动时一抖一抖"，限 60 帧仍然抖。他自己补了一条关键副证：
## **移动途中截图不糊、非常正常** ⇒ 坏的不是单帧内容（半像素/取整/缩放都排除了），
## 坏的是"帧与帧之间的时间"。这条量具只量时间轴：
##   ① 每个渲染帧之间物理走了几拍（0 拍 = 这一帧和上一帧**一模一样** = 重复帧）
##   ② 相邻渲染帧的屏幕位差几个像素（重复帧率、步长分布、步长方差=忽大忽小的程度）
##   ③ 渲染帧间隔（ms）—— 用来对上显示器刷新周期（本机 1920×1080 只有 50/59/60/75/100 五档，现在 100）
##   ④ 屏幕位的小数部分 —— 用来验"官方物理插值"会不会把世界像素推到两个屏幕像素中间
## ★ 只统计**相机自由跟位那一段**：走到地图边缘时相机被 `_clamp_center_to_map` 夹住、本来就不该动，
##   把那段算进来会压低重复帧率（实测前 150 拍就是这段）。
## ★ `速度=` 只改**夹具这一具**的 move_speed，不动工程里的游戏数值（用户 10-23 令：把移速调高再测）。
##
## 跑（一档一次）：
##   Godot --path . --script res://开发工具/量镜头步进.gd -- 档=甲 毫秒=3000
##     物理钉到刷新率：-- 物理=100        官方插值：-- 插值=1
##     渲染钉 50：-- 帧上限=50            高速：-- 速度=600
## ⚠ 会真开一个窗口 3 秒多；进图 ⇒ 按字节快照 `user://玩家数据.json`、收尾还原。

const 地图场景头 := "res://场景/生成/地图_"
const 地图场景尾 := "_烘焙.tscn"
const 存档 := "user://玩家数据.json"
const 出文件前 := "user://量镜头步进_"

var 档名 := "甲-现状"
var 目标物理帧率 := 0
var 开插值 := false
var 帧上限 := 0
var 采毫秒 := 3000
var 速度 := 0.0
var 保持窗口 := false
var 图号 := "101010000"		# 木叶村只有 2278 宽，最大化下镜头几乎不动；量镜头行程要挑宽图

var 存前 := PackedByteArray()
var 存前在 := false
var 物理拍 := 0
var 上次物理拍 := 0
var 记录: Array = []


func _读参数() -> void:
	var 用: PackedStringArray = OS.get_cmdline_user_args()
	var 键 := {}
	for a in 用:
		var s := String(a)
		var i := s.find("=")
		if i > 0:
			键[s.substr(0, i)] = s.substr(i + 1)
	if 键.has("档"):
		档名 = String(键["档"])
	if 键.has("物理"):
		目标物理帧率 = int(String(键["物理"]))
	if 键.has("插值"):
		开插值 = String(键["插值"]) == "1"
	if 键.has("帧上限"):
		帧上限 = int(String(键["帧上限"]))
	if 键.has("毫秒"):
		采毫秒 = int(String(键["毫秒"]))
	if 键.has("速度"):
		速度 = float(String(键["速度"]))
	if 键.has("图"):
		图号 = String(键["图"])
	if 键.has("窗口"):
		保持窗口 = String(键["窗口"]) == "保持"


func _快照() -> void:
	存前在 = FileAccess.file_exists(存档)
	if 存前在:
		var g := FileAccess.open(存档, FileAccess.READ)
		存前 = g.get_buffer(g.get_length())


func _还原() -> void:
	if not 存前在:
		return
	var 现 := FileAccess.open(存档, FileAccess.READ)
	if 现.get_buffer(现.get_length()) == 存前:
		print("存档没动过")
		return
	var h := FileAccess.open(存档, FileAccess.WRITE)
	h.store_buffer(存前)
	print("存档已按字节还原")


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _看物理拍() -> void:
	物理拍 += 1


func _initialize() -> void:
	_读参数()
	if 目标物理帧率 > 0:
		Engine.physics_ticks_per_second = 目标物理帧率
	if 帧上限 > 0:
		Engine.max_fps = 帧上限
	_快照()
	_run()


func _run() -> void:
	set_physics_interpolation_enabled(开插值)
	print("── 档 = " + 档名 + " ── 物理帧率=" + str(Engine.get_physics_ticks_per_second())
			+ " 插值=" + str(is_physics_interpolation_enabled())
			+ " max_fps=" + str(Engine.max_fps)
			+ " vsync=" + str(DisplayServer.window_get_vsync_mode()))
	if not 保持窗口:
		root.size = Vector2i(960, 560)
	var 图路: String = 地图场景头 + 图号 + 地图场景尾
	if not ResourceLoader.exists(图路):
		print("!!红 没有这张烘焙地图场景：" + 图路)
		_还原()
		quit(1)
		return
	var 景: Node = (load(图路) as PackedScene).instantiate()
	root.add_child(景)
	current_scene = 景
	var 们: Array = get_nodes_in_group("player")
	var 试 := 0
	while 们.size() == 0 and 试 < 600:
		await _帧(10)
		们 = get_nodes_in_group("player")
		试 += 10
	if 们.size() == 0:
		print("!!红 拿不到玩家（这条量具要先改找法）")
		_还原()
		quit(1)
		return
	var 玩: Node2D = 们[0] as Node2D
	玩.set("on_ground", true)
	if 速度 > 0.0:
		玩.set("move_speed", 速度)
	await _帧(20)
	var 相: Camera2D = root.get_viewport().get_camera_2d() as Camera2D
	if 相 == null:
		print("!!红 视口里没有当前相机，这些屏幕位数没法解释")
		_还原()
		quit(1)
		return
	var 现速: float = float(玩.get("move_speed"))
	print("   显示器 0 刷新率 = " + str(DisplayServer.call("screen_get_refresh_rate", 0)) + "；窗口=" + str(root.size) + " 内容缩放倍数=" + str(root.content_scale_factor))
	print("   player 组共 " + str(们.size()) + " 具；视口=" + str(root.get_viewport().get_visible_rect().size)
			+ "；相机=" + str(相.get_path()) + " zoom=" + str(相.zoom)
			+ " 平滑=" + str(相.position_smoothing_enabled) + " 回调=" + str(相.process_callback))
	print("   夹具 move_speed = " + str(现速) + " ⇒ 每物理拍该跨 "
			+ str(_f(现速 / float(Engine.get_physics_ticks_per_second()))) + " 像素"
			+ "（带小数 = 取整必抖）；起点世界 x = " + str(_f(玩.global_position.x)))
	## `玩家.gd:1348` 读的是 `Input.is_action_pressed("ui_right")` ⇒ `action_press` 直接改
	## Input 单例的状态就够，不用伪造事件队列（`push_input` 那一族才会踩焦点/吞事件）。
	Input.action_press("ui_right")
	physics_frame.connect(_看物理拍)
	var 起 := Time.get_ticks_msec()
	var 上微秒 := Time.get_ticks_usec()
	while Time.get_ticks_msec() - 起 < 采毫秒:
		await process_frame
		var 现 := Time.get_ticks_usec()
		var c: Transform2D = root.get_viewport().get_canvas_transform()
		记录.append({
			"dt": 现 - 上微秒,
			"ox": c.origin.x, "oy": c.origin.y,
			"拍": 物理拍 - 上次物理拍,
			"wy": 玩.global_position.x,
			"cx": 相.global_position.x,
			"sx": (c * 玩.get_global_position()).x,
			"速": 现速,
		})
		上次物理拍 = 物理拍
		上微秒 = 现
	Input.action_release("ui_right")
	await _帧(5)
	_统计()
	_还原()


func _自由段起点() -> int:
	## 找第一拍"相机自己真的动了"——之前那些拍相机被地图边缘夹住，屏幕位恒 0，不是抖动样本。
	for i in range(1, 记录.size()):
		if absf(float(记录[i]["cx"]) - float(记录[i - 1]["cx"])) > 0.001:
			return i
	return 1


func _表(v) -> String:
	return str(v)


func _f(x) -> String:
	return "%.2f" % float(x)


func _统计() -> void:
	var n := 记录.size()
	var 现速: float = float(记录[0].get("速", 175.0))
	var 行: Array[String] = []
	行.append("档 = " + 档名 + "   地图=" + 图号 + "   物理帧率=" + str(Engine.get_physics_ticks_per_second())
			+ "  插值=" + str(is_physics_interpolation_enabled())
			+ "  max_fps=" + str(Engine.max_fps) + "  夹具移速=" + str(现速))
	行.append("渲染拍 = " + str(n) + "，采了 " + str(采毫秒) + " ms ⇒ 实测渲染帧率 ≈ "
			+ str(_f(float(n) * 1000.0 / float(采毫秒))) + " fps")
	var 由 := _自由段起点()
	var 段长: int = n - 由
	行.append("自由段 = 第 " + str(由) + " 拍起（前面 " + str(由 - 1) + " 拍相机被地图边缘夹住，不计入）")
	## ① 每渲染帧夹了几拍物理
	var 拍表 := {}
	var 拍零 := 0
	for i in range(由, n):
		var k := str(int(记录[i]["拍"]))
		拍表[k] = int(拍表.get(k, 0)) + 1
		if int(记录[i]["拍"]) == 0:
			拍零 += 1
	行.append("★ 每渲染帧夹的物理拍数 = " + _表(拍表) + " ⇒ 重复帧 " + str(拍零) + "/" + str(段长)
			+ " = " + str(_f(100.0 * float(拍零) / float(maxi(1, 段长)))) + "%")
	## ② 屏幕步长
	var 步表 := {}
	var 步零 := 0
	var 步和 := 0.0
	var 步方 := 0.0
	for i in range(由, n):
		var d: float = float(记录[i]["ox"]) - float(记录[i - 1]["ox"])
		var s := str(_f(d))
		步表[s] = int(步表.get(s, 0)) + 1
		if absf(d) < 0.001:
			步零 += 1
		步和 += absf(d)
		步方 += d * d
	var 均 := 步和 / float(maxi(1, 段长))
	var 差 := maxf(0.0, 步方 / float(maxi(1, 段长)) - 均 * 均)
	行.append("★ 相邻渲染帧屏幕 x 位移 = " + _表(步表))
	行.append("   不动的渲染帧 = " + str(步零) + "/" + str(段长) + " = "
			+ str(_f(100.0 * float(步零) / float(maxi(1, 段长)))) + "%；平均 "
			+ str(_f(均)) + " 像素/帧；步长方差 " + str(_f(差)) + "（越大=忽大忽小）")
	var 小数集 := {}
	for i in range(由, n):
		小数集[str(_f(fposmod(float(记录[i]["ox"]), 1.0)))] = 1
	行.append("★ 屏幕 x 的小数部分 = " + _表(小数集.keys()) + "（只有 0.0 = 全压在整数像素上）")
	## ②b **角色自己**在屏幕上的步长：镜头被地图边缘夹住时，画面里唯一在动的就是这一具，
	##      他实机最大化玩的那一档，镜头全程 0 位移 ⇒ 只统计镜头会整个量瞎。
	var 色表 := {}
	var 色零 := 0
	var 色和 := 0.0
	var 色方 := 0.0
	for i in range(由, n):
		var e: float = float(记录[i]["sx"]) - float(记录[i - 1]["sx"])
		var s2 := str(_f(e))
		色表[s2] = int(色表.get(s2, 0)) + 1
		if absf(e) < 0.001:
			色零 += 1
		色和 += absf(e)
		色方 += e * e
	var 色均 := 色和 / float(maxi(1, 段长))
	var 色差 := maxf(0.0, 色方 / float(maxi(1, 段长)) - 色均 * 色均)
	行.append("★ 角色在屏幕上的 x 相邻帧位移 = " + _表(色表))
	行.append("   角色不动的渲染帧 = " + str(色零) + "/" + str(段长) + " = "
			+ str(_f(100.0 * float(色零) / float(maxi(1, 段长)))) + "%；平均 " + str(_f(色均))
			+ " 像素/帧；步长方差 " + str(_f(色差)))
	## ③ 角色在屏幕上的落点晃多少
	var 屏小 := 1e20
	var 屏大 := -1e20
	for i in range(由, n):
		屏小 = minf(屏小, float(记录[i]["sx"]))
		屏大 = maxf(屏大, float(记录[i]["sx"]))
	行.append("   角色在屏幕上的 x：" + str(_f(屏小)) + " → " + str(_f(屏大))
			+ "（宽 " + str(_f(屏大 - 屏小)) + " 像素）")
	## ④ 帧间隔
	var 隔表 := {}
	var 隔和 := 0
	for i in range(由, n):
		var ms: int = int(roundf(float(记录[i]["dt"]) / 1000.0))
		隔表[ms] = int(隔表.get(ms, 0)) + 1
		隔和 += ms
	行.append("   渲染帧间隔(ms) = " + _表(隔表) + "  均 "
			+ str(_f(float(隔和) / float(maxi(1, 段长)))) + " ms")
	## ⑤ 理论对照：理想情况下每渲染帧该动多少像素
	var 理: float = 现速 / maxf(1.0, float(n) * 1000.0 / float(采毫秒))
	行.append("   对照：移速 " + str(现速) + " ÷ 渲染帧率 = 理想 " + str(_f(理))
			+ " 像素/帧；每物理拍 = " + str(_f(现速 / float(Engine.get_physics_ticks_per_second()))) + " 像素")
	## ⑥ 夹具自检：没真走起来 ⇒ 上面那些"0"全是假的
	var 走: float = absf(float(记录[n - 1]["wy"]) - float(记录[0]["wy"]))
	行.append("   自检：这 " + str(采毫秒) + " ms 玩家世界 x 走了 " + str(_f(走))
			+ " 像素 ⇒ " + str(_f(走 * 1000.0 / float(采毫秒))) + " 像素/秒（夹具移速 " + str(现速) + "）")
	var 红: Array = []
	if 段长 < 60:
		红.append("自由段渲染拍太少（" + str(段长) + "）⇒ 这一档根本没采到，别看上面的数")
	if 走 < 100.0 or 走 < 0.5 * 现速 * float(采毫秒) / 1000.0:
		红.append("玩家没真的走满（只走了 " + str(_f(走)) + " 像素，期望 ≈"
				+ str(_f(现速 * float(采毫秒) / 1000.0)) + "）⇒ 重复帧/步长那些数不可信")
	for s in 红:
		行.append("!!红 " + s)
	for s in 行:
		print(s)
	var 路 := 出文件前 + 档名 + ".txt"
	var f := FileAccess.open(路, FileAccess.WRITE)
	if f != null:
		for s in 行:
			f.store_line(s)
		print("已写 " + 路)
	if not 红.is_empty():
		quit(1)
	quit(0)
