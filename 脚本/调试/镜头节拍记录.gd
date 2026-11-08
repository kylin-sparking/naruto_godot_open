extends CanvasLayer

## 镜头节拍记录 + 逻辑节拍开关（调试小工具，正常启动零开销）。
##
## 为什么要有这一条（2026-10-23）：量具 `开发工具/量镜头步进.gd` 在最大化尺寸、4857 宽的图上
## 走满 6 秒量到——**逻辑节拍 60、屏幕节拍 100 ⇒ 48% 的渲染帧镜头一动不动**；把逻辑节拍钉到
## 100 之后那一档降到 0%。但用户在量具窗口里**看不出抖**、在自己实机里看得出，还给了精确描述：
## **盯着角色不抖，视野一大就抖**。这两个现象是同一件事的两面：角色在屏幕上本来就钉住
## （量到的晃动只有 0.8~1.0 像素），淌过去的是背景 ⇒ 盯静止物当然看不出。
## ⇒ 判"抖不抖"必须在**他自己那一局**里量，所以把同一套统计搬进游戏本体。
##
## 节拍跟屏 = **默认就开**（用户 2026-10-23 实测"跟屏无敌了非常流畅"之后点头要的）：
##   开机当场读**这块显示器**的刷新率（`DisplayServer.screen_get_refresh_rate`），把逻辑节拍设成同一个数。
##   ⇒ 打包发给别人也跟着**他的**屏走：100Hz 的人跑 100 拍、260Hz 的人跑 260 拍，工程里不焊任何数值。
##   三条闸：① 读不到（无头给 −1）或落在 [30, 360] 之外 ⇒ **保持工程默认 60，绝不设成 0**；
##   ② **跑门/量具那一族进程（命令行带 `--script`）一律不跟屏** ⇒ 全工程那些按物理拍计数写下来的门
##      不会因为玩家换了高刷屏就集体改数；
##   ③ 窗口被拖到另一块不同刷新率的屏上 ⇒ 每 2 秒复查一次，跟着改。
## 环境变量 `NARUTO_PHYSICS` 只用来**覆盖**默认：`off` / `default` = 回到原版 60 拍；`144` = 指定数；
## `follow` / `auto` = 即使在 `--script` 进程里也强行跟屏（对照实验用）。
## 记录器另算：`NARUTO_CAMLOG=1` 或 **F6** 开关（关时自动存），**F7** 随时存证。
## 左上角那行状态字**正常启动不显示**（用户 2026-10-23 要求）：只有用
## 环境变量 `NARUTO_CAMLOG=1` / `NARUTO_PHYSICS=follow`、带 `--camlog` 启动，
## 或游戏内按 F6 开了录制时才显示。`NARUTO_PHYSICS=off` 之类的对照启动也算"加参数"。
##
## 只用引擎自己的 `get_canvas_transform()` 与 `physics_frame` 计数。没开任何开关时
## `set_process(false)`，每帧零开销；`physics_frame` 那条只做一次自增。

const 出文件前 := "user://镜头节拍_实机_物理"
const 缓存上限 := 1200			# ≈12 秒（100fps 下）；只留环形尾段，够按 F7 之前一直在录
const 位置边距 := 8.0
const 位置高度 := 28.0			# 让开右上角那颗 FPS 浮层
const 节拍下限 := 30
const 节拍上限 := 360			# 260/360Hz 的屏也要跟得住；越界一律不动（宁可不跟）

var _标签: Label
var _录 := false
var _物理拍 := 0
var _上拍 := 0
var _上微秒 := 0
var _采: Array = []
var _改了节拍 := false
var _自动跟屏 := false
var _来源 := "工程默认"
var _末次 := "没按 F7 之前不写文件"


func _ready() -> void:
	layer = 200					# 与帧率浮层同层：盖住 HUD，只读不挡鼠标
	_标签 = Label.new()
	_标签.name = "镜头节拍文字"
	_标签.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_标签.add_theme_font_size_override("font_size", 14)
	_标签.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	_标签.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_标签.add_theme_constant_override("outline_size", 4)
	_标签.position = Vector2(位置边距, 位置高度)
	add_child(_标签)
	var 之 := Engine.get_physics_ticks_per_second()
	var 屏 := _刷新率()
	_改了节拍 = _上节拍(屏, _命令行())
	if _改了节拍:
		## 开机就说一句话：他自己开控制台版能看到"跟到多少、为什么"，出问题第一眼就在这行。
		print("镜头节拍记录：逻辑节拍 " + str(之) + " → "
				+ str(Engine.get_physics_ticks_per_second()) + "（" + _来源
				+ "，屏幕 " + _f(屏) + "Hz，vsync=" + str(DisplayServer.window_get_vsync_mode()) + "）")
	_物理拍 = 0
	get_tree().physics_frame.connect(_看物理拍)
	_录 = OS.get_environment("NARUTO_CAMLOG") == "1" \
			or OS.get_cmdline_user_args().has("--camlog")
	_归零()
	set_process(_录)
	_刷标签(屏)
	if _自动跟屏:
		## 只有"自动跟屏"这一路才挂复查：手动指定过数（`NARUTO_PHYSICS=144`）就永远不许被屏幕顶掉。
		var 时 := Timer.new()
		时.name = "刷新率复查"
		时.wait_time = 2.0
		时.autostart = true
		时.timeout.connect(_复查节拍)
		add_child(时)


func _刷新率() -> float:
	## 4.7.2 没有 `get_monitor_refresh_rate`，能读的是 `screen_get_refresh_rate`（返回 float，
	## 无头模式给 0 ⇒ 只当"读不到"处理，不许拿 0 当刷新率去设节拍）。
	if not DisplayServer.has_method("screen_get_refresh_rate"):
		return 0.0
	return float(DisplayServer.call("screen_get_refresh_rate", DisplayServer.window_get_current_screen()))


func _命令行() -> PackedStringArray:
	## 判"这进程是不是量具/门"要看 `--script`，它在 `--` **之前** ⇒ 必须取整条引擎参数，
	## `get_cmdline_user_args()` 只给 `--` 之后那半（会漏判）。4.7.2 上现查的名字是
	## `OS.get_cmdline_args()`（实测 `--headless --path . --script res://X.gd -- 档=甲` 回
	## `["--script", "res://X.gd"]`；`get_cmdline_raw_array` / `get_cmdline_arguments` **都不存在**，
	## 写错 = 自动加载 parse 失败 = 整个记录器静默不跑，见 开发工具/查命令行内容.gd）。
	return OS.get_cmdline_args()


func _是探针(命令行) -> bool:
	for a in 命令行:
		var s := String(a)
		if s == "--script" or s.begins_with("--script="):
			return true
	return false


func _设节拍(n: int) -> bool:
	if n < 节拍下限 or n > 节拍上限:
		_来源 = "越界不改(" + str(n) + ")"
		return false
	Engine.set_physics_ticks_per_second(n)
	return Engine.get_physics_ticks_per_second() == n


func _上节拍(屏: float, 命令行) -> bool:
	## 返回"节拍真的被改过"；顺带把 `_自动跟屏` 定下来（只有自动那一路才允许复查改数）。
	_自动跟屏 = false
	var 指 := OS.get_environment("NARUTO_PHYSICS").strip_edges().to_lower()
	if 指 == "off" or 指 == "default" or 指 == "no":
		_来源 = "环境变量要的原版 60"
		return false
	if 指.is_valid_int():
		var 硬 := int(指)
		var 成 := _设节拍(硬)
		_来源 = "环境变量指定 " + str(硬)
		return 成
	var 要跟 := (指 == "follow" or 指 == "auto")
	if not 要跟:
		if _是探针(命令行):
			_来源 = "量具/门进程（带 --script）不跟屏"
			return false
		要跟 = true
	if 屏 < float(节拍下限) or 屏 > float(节拍上限):
		_来源 = "读不到刷新率(" + str(屏) + ")，保持默认"
		return false
	_自动跟屏 = true
	var 想 := int(round(屏))
	var 成2 := _设节拍(想)
	_来源 = "自动跟屏 " + str(想)
	return 成2


func _复查节拍() -> void:
	var 屏 := _刷新率()
	if 屏 < float(节拍下限) or 屏 > float(节拍上限):
		return
	var 想 := int(round(屏))
	if Engine.get_physics_ticks_per_second() == 想:
		return
	print("镜头节拍记录：刷新率变了 ⇒ 逻辑节拍 "
			+ str(Engine.get_physics_ticks_per_second()) + " → " + str(想))
	_设节拍(想)
	_刷标签(屏)


func _归零() -> void:
	_上微秒 = 0
	_上拍 = _物理拍
	_采.clear()


func _看物理拍() -> void:
	_物理拍 += 1


func _process(_delta: float) -> void:
	if not _录:
		return
	var 视 := get_viewport()
	if 视 == null:
		return
	var 相 := 视.get_camera_2d()
	if 相 == null:
		return						# 登录页/换图那一瞬没有相机：这一拍不记，也别拿 0 去算
	var 玩 := get_tree().get_first_node_in_group("player") as Node2D
	if 玩 == null:
		return
	var 现 := Time.get_ticks_usec()
	if _上微秒 == 0:
		_上微秒 = 现
		_上拍 = _物理拍
		return
	var c: Transform2D = 视.get_canvas_transform()
	var 屏位: Vector2 = c * 玩.get_global_position()
	_采.append({
		"dt": 现 - _上微秒,
		"ox": c.origin.x, "oy": c.origin.y,
		"拍": _物理拍 - _上拍,
		"cx": 相.global_position.x,
		"wy": 玩.global_position.x,
		"sx": 屏位.x, "sy": 屏位.y,
	})
	_上拍 = _物理拍
	_上微秒 = 现
	if _采.size() > 缓存上限:
		_采.pop_front()


func _input(事件: InputEvent) -> void:
	if not (事件 is InputEventKey):
		return
	var 键 := 事件 as InputEventKey
	if not (键.pressed and not 键.echo):
		return
	if 键.keycode == KEY_F6:
		_录 = not _录
		if not _录:
			_存证()					# 关录顺手存，免得他关完就没了
		else:
			_归零()
		set_process(_录)
		_刷标签(_刷新率())
	elif 键.keycode == KEY_F7:
		_存证()
		_刷标签(_刷新率())


func _f(x) -> String:
	return "%.2f" % float(x)


func _自由段起点() -> int:
	## 剔掉"相机被地图边缘夹住、本来就不该动"的那几拍：不剔的话重复帧率会被压小。
	for i in range(1, _采.size()):
		if absf(float(_采[i]["cx"]) - float(_采[i - 1]["cx"])) > 0.001:
			return i
	return 1


func _统计() -> Array[String]:
	var 行: Array[String] = []
	var n := _采.size()
	行.append("物理帧率 = " + str(Engine.get_physics_ticks_per_second())
			+ "（NARUTO_PHYSICS=" + str(OS.get_environment("NARUTO_PHYSICS")) + "）"
			+ "  显示器刷新率 = " + _f(_刷新率())
			+ "  max_fps = " + str(Engine.max_fps)
			+ "  vsync = " + str(DisplayServer.window_get_vsync_mode()))
	行.append("录到渲染拍 = " + str(n) + "（环形上限 " + str(缓存上限) + "）")
	if n < 40:
		行.append("!!红 拍数太少 ⇒ 这一局根本没录到（没进图？没在动？F6 没开？），别看后面的数")
		return 行
	var 由 := _自由段起点()
	var 段长: int = n - 由
	行.append("自由段 = 第 " + str(由) + " 拍起（前面 " + str(由 - 1) + " 拍相机被地图边缘夹住，不计入）")
	var 拍表 := {}
	var 拍零 := 0
	for i in range(由, n):
		var k := str(int(_采[i]["拍"]))
		拍表[k] = int(拍表.get(k, 0)) + 1
		if int(_采[i]["拍"]) == 0:
			拍零 += 1
	行.append("★ 每渲染帧夹的物理拍数 = " + str(拍表) + " ⇒ 重复帧 " + str(拍零) + "/" + str(段长)
			+ " = " + _f(100.0 * float(拍零) / float(maxi(1, 段长))) + "%")
	var 步表 := {}
	var 步零 := 0
	var 步和 := 0.0
	var 步方 := 0.0
	var 小数集 := {}
	for i in range(由, n):
		var d: float = float(_采[i]["ox"]) - float(_采[i - 1]["ox"])
		var s := _f(d)
		步表[s] = int(步表.get(s, 0)) + 1
		if absf(d) < 0.001:
			步零 += 1
		步和 += absf(d)
		步方 += d * d
		小数集[_f(fposmod(float(_采[i]["ox"]), 1.0))] = 1
	var 均 := 步和 / float(maxi(1, 段长))
	行.append("★ 镜头在屏幕上的 x 相邻帧位移 = " + str(步表))
	行.append("   镜头不动的渲染帧 = " + str(步零) + "/" + str(段长) + " = "
			+ _f(100.0 * float(步零) / float(maxi(1, 段长))) + "%；平均 " + _f(均)
			+ " 像素/帧；步长方差 " + _f(maxf(0.0, 步方 / float(maxi(1, 段长)) - 均 * 均)))
	行.append("★ 屏幕 x 的小数部分 = " + str(小数集.keys()) + "（只有 0.00 = 全压在整数像素上）")
	var 色表 := {}
	var 色零 := 0
	for i in range(由, n):
		var e: float = float(_采[i]["sx"]) - float(_采[i - 1]["sx"])
		var s2 := _f(e)
		色表[s2] = int(色表.get(s2, 0)) + 1
		if absf(e) < 0.001:
			色零 += 1
	行.append("★ 角色在屏幕上的 x 相邻帧位移 = " + str(色表) + " ⇒ 不动的 " + str(色零) + "/"
			+ str(段长) + " = " + _f(100.0 * float(色零) / float(maxi(1, 段长))) + "%")
	var 隔表 := {}
	var 隔和 := 0
	for i in range(由, n):
		var ms: int = int(roundf(float(_采[i]["dt"]) / 1000.0))
		隔表[ms] = int(隔表.get(ms, 0)) + 1
		隔和 += ms
	行.append("   渲染帧间隔(ms) = " + str(隔表) + "  均 " + _f(float(隔和) / float(maxi(1, 段长))) + " ms")
	var 走: float = absf(float(_采[n - 1]["wy"]) - float(_采[0]["wy"]))
	var 毫秒 := 0.0
	for i in range(1, n):
		毫秒 += float(_采[i]["dt"])
	毫秒 /= 1000.0
	行.append("   自检：这段里角色世界 x 走了 " + _f(走) + " 像素 / " + _f(毫秒)
			+ " ms ⇒ " + _f(走 * 1000.0 / maxf(1.0, 毫秒)) + " 像素/秒（走够长才量得到镜头）")
	行.append("   角色在屏幕上的 x：" + _f(float(_采[由]["sx"])) + " → " + _f(float(_采[n - 1]["sx"]))
			+ "（盯角色看不出抖，就是因为这一行几乎不动）")
	if 步零 > int(段长 * 0.2):
		行.append("判读：镜头有 " + _f(100.0 * float(步零) / float(maxi(1, 段长)))
				+ "% 的渲染帧一动不动 ⇒ 逻辑节拍与屏幕节拍没对齐（这就是抖）")
	else:
		行.append("判读：镜头几乎每帧都在动 ⇒ 这一档节拍对齐了，不该再有重复帧那种抖")
	return 行


func _存证() -> void:
	var 行 := _统计()
	var 出文件: String = 出文件前 + str(Engine.get_physics_ticks_per_second()) + ".txt"
	var f := FileAccess.open(出文件, FileAccess.WRITE)
	if f == null:
		_末次 = "写不进 " + 出文件 + "（错误码 " + str(FileAccess.get_open_error()) + "）"
		for s in 行:
			print(s)
		return
	for s in 行:
		f.store_line(s)
	f.close()
	_末次 = "已写 " + 出文件
	print(_末次)
	for s in 行:
		print(s)


func _刷标签(屏: float) -> void:
	var 态 := "F6 录 " + ("开" if _录 else "关") + "｜F7 存"
	_标签.text = "逻辑节拍 " + str(Engine.get_physics_ticks_per_second()) \
			+ "（" + _来源 + "）｜屏幕 " + _f(屏) + "Hz｜" + 态 + "｜" + _末次
	## 正常启动（没有环境变量、没开录）一律不显示，哪怕逻辑节拍已经跟了高刷屏；
	## 用户 2026-10-23 要的就是"默认干干净净，加参数启动才给调试信息"。
	_标签.visible = _录 or not OS.get_environment("NARUTO_PHYSICS").is_empty()
