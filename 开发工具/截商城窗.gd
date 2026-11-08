extends SceneTree

## 截「商城」与「NPC 商店」两页的图，用来**看**版式对不对（离线示例数据也能看几何）。
##
## 为什么要单独写一个：`测试/功能入口回归测试.gd` 那条路把图存进 `user://`，
## 而 `user://` 是本项目的**红线**（见 开发记录（本地） §3.41.7 第 1 条）。
## 这里存到 `res://测试/截图/商城/`（该目录 `.gitignore` 挡着，属"盘上有、仓里没有"）。
##
## 用法（**不能加 --headless**，无头驱动拿不到视口图像）：
##   Godot --path . --script res://开发工具/截商城窗.gd
## 可选：
##   --出目录=res://测试/截图/商城
##   --调用=_set_shop_tab,3     切到商城的某个页签后再截（下标是 categoryId）
##   --窗宽=1280 --窗高=720     默认 960x560（原版舞台尺寸）

var _出目录 := "res://测试/截图/商城"
var _调用 := ""
var _调用参数 := 0
## `--联机`：先连夹具（`BackendConnection.sync_character()`），截**真数据**的图。
## ⚠️ 不加这个开关截出来的永远是离线示例数据（离线那三条商品是手挑的）。
## 跑之前先起夹具（18684），否则会等超时。
var _联机 := false
var _后端: Node = null
var _联机截止 := 0
var _登录完成 := false
var _截图截止 := 0
## `--点购买`：开完商城后点第一行的「购买」，把购买窗也截进去。
var _点购买 := false
var _已点购买 := false
var _帧 := 0
var _场景: Node = null
var _管理: Node = null
var _窗: Node = null
var _队列: Array[String] = ["商城", "NPC商店"]
var _序号 := 0
var _已就绪 := false
var _待截 := false
var _等待 := 0
var _张数 := 0


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		# ⚠️ 纯开关（没有 `=值`）要先判掉 —— 早先写成"`split("=")` 不到两段就 continue"，
		#    于是 `--联机` 被静默忽略，跑出来还是离线图（2026-09-26 踩过）。
		if 参数 == "--联机":
			_联机 = true
			continue
		if 参数 == "--点购买":
			_点购买 = true
			continue
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() != 2:
			continue
		match 键值[0]:
			"--出目录": _出目录 = 键值[1]
			"--调用":
				var 段 := 键值[1].split(",", false)
				_调用 = 段[0]
				_调用参数 = int(段[1]) if 段.size() > 1 else 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_出目录))
	var 场景脚本 := load("res://场景/地图/地图场景.tscn") as PackedScene
	if 场景脚本 == null:
		push_error("无法加载地图场景")
		quit(1)
		return
	_场景 = 场景脚本.instantiate()
	root.add_child(_场景)


func _process(_delta: float) -> bool:
	_帧 += 1
	if _帧 < 8:
		return false
	if not _已就绪:
		_管理 = _场景.get_node_or_null("窗口管理")
		if _管理 == null:
			push_error("缺少 窗口管理")
			quit(1)
			return true
		if _联机 and not _登录完成:
			# ⚠️ 不能在这里 `await` —— `_process` 是个"每帧返回 bool 的状态机"，
			#    里面挂 await 会把它整个断掉（实测：地图加载完之后什么都不再发生）。
			#    所以分两拍：第一拍只发起连接 + 记截止时间，之后每帧轮询 `in_game`。
			if _后端 == null:
				_后端 = root.get_node_or_null("BackendConnection")
				if _后端 == null:
					push_warning("没有 BackendConnection，按离线截")
					_登录完成 = true
					return false
				_后端.sync_character()
				_联机截止 = Time.get_ticks_msec() + 15000
				return false
			if bool(_后端.in_game):
				print("截商城窗：已连上夹具")
				_登录完成 = true
			elif Time.get_ticks_msec() > _联机截止:
				push_warning("联机超时（%s），按离线截" % _后端.get("detail"))
				_登录完成 = true
			else:
				return false
		_已就绪 = true
		return false
	if _待截:
		if _等待 > 0:
			_等待 -= 1
			return false
		# ⚠️ 联机时**不能按帧等**：无头/窗口模式的帧率都不受 vsync 限制，几帧等于零耗时，
		#    抓到的会是"正在读取商城商品"的空货架（实测踩过）。
		#    改成按**时间**等，并且等到货架真到位（或超时）为止。
		if _点购买 and not _已点购买 and _队列[_序号 - 1] == "商城":
			_已点购买 = true
			var 内容 := _窗.get("_content") as Control
			if 内容 != null and 内容.get_child_count() > 0:
				for 格 in 内容.get_child(0).find_children("购买", "Button", true, false):
					(格 as Button).pressed.emit()
					break
			# 弹窗要过一帧才摆好位置，多等一会
			_截图截止 = Time.get_ticks_msec() + 900
		if _联机:
			if _截图截止 == 0:
				_截图截止 = Time.get_ticks_msec() + 4000
			var 会话 := root.get_node_or_null("GameSession")
			var 就绪 := 会话 != null and not (会话.get("shop_catalog") as Array).is_empty()
			if not 就绪 and Time.get_ticks_msec() < _截图截止:
				return false
		if _截图截止 != 0 and Time.get_ticks_msec() < _截图截止:
			return false
		_待截 = false
		_截图截止 = 0
		_抓图()
		return false
	if _序号 >= _队列.size():
		print("截商城窗：共 %d 张，目录 %s" % [_张数, _出目录])
		quit(0)
		return true
	_开页(_队列[_序号])
	_序号 += 1
	_待截 = true
	_等待 = 4
	return false


func _开页(页名: String) -> void:
	var 窗: Node = _管理.call("取或建窗口", 页名)
	_窗 = 窗
	if 窗 == null:
		push_error("建不出窗口：%s" % 页名)
		return
	窗.call("open_page", 页名)
	if not _调用.is_empty() and 窗.has_method(_调用):
		窗.call(_调用, _调用参数)
	print("截商城窗：已打开 %s" % 页名)


func _抓图() -> void:
	var 图 := root.get_texture().get_image()
	if 图 == null or 图.is_empty():
		push_error("拿不到视口图像 —— 是不是加了 --headless？")
		return
	var 名 := _队列[_序号 - 1]
	var 路径 := "%s/%s%s.png" % [_出目录, 名, "" if _调用.is_empty() else "_%d" % _调用参数]
	if 图.save_png(路径) != OK:
		push_error("存图失败：%s" % 路径)
		return
	_张数 += 1
	print("截商城窗：%s → %s（%dx%d）" % [名, 路径, 图.get_width(), 图.get_height()])
