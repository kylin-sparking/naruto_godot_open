extends SceneTree

## 同 `截多窗口.gd`，但**加载运行时真正加载的那个场景**。
##
## 为什么要有这个：`截多窗口.gd` 加载的是 `res://场景/地图/地图场景.tscn`（源场景），
## 而运行时走的是 `地图资源.playable_scene_path()` → `res://场景/生成/地图_<id>_烘焙.tscn`。
## 两者不是同一个文件 —— 2026-09-24 就是拿源场景验的，验了个假：源场景早改好了，
## 烘焙图一张没重烤，实机仍然是"开一个关一个"。
##
## 用法（**不能加 --headless**，要渲染）：
##   Godot --path . --script res://开发工具/截多窗口_烘焙.gd
##   Godot --path . --script res://开发工具/截多窗口_烘焙.gd -- --地图=101010000 --出=res://测试/截图/多窗口_烘焙.png

const 页名们 := ["人物", "背包", "忍术"]

var _出 := "res://测试/截图/多窗口_烘焙.png"
var _地图 := "101010000"
var _场景: Node = null
var _帧 := 0
var _已开 := false
var _待截 := false


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() != 2:
			continue
		if 键值[0] == "--出":
			_出 = 键值[1]
		elif 键值[0] == "--地图":
			_地图 = 键值[1]
	# 刻意走与运行时同一个函数，免得这里又写死一条路径、哪天口径变了没人发现。
	var 路径: String = load("res://脚本/地图/地图资源.gd").playable_scene_path(_地图)
	print("截多窗口_烘焙：加载 ", 路径)
	var 场景资源 := load(路径) as PackedScene
	if 场景资源 == null:
		push_error("无法加载 " + 路径)
		quit(1)
		return
	_场景 = 场景资源.instantiate()
	root.add_child(_场景)


func _process(_delta: float) -> bool:
	_帧 += 1
	if _帧 < 8:
		return false
	if not _已开:
		_开三个面板()
		_已开 = true
		return false
	if not _待截:
		_待截 = true     # set 之后要隔一帧才画进视口
		return false
	_报告()
	quit(0)
	return true


func _报告() -> void:
	var 管理 := _场景.get_node_or_null("窗口管理")
	print("截多窗口_烘焙：窗口管理节点 = ", "有" if 管理 != null else "**没有**（= 还是旧的单窗口换页）")
	if 管理 == null:
		# 旧烘焙图的症状要看旧的单窗口实例：它被底栏的每个按钮都连到 `open_page`，
		# 所以最后停在**最后点的那一页**，前两页被顶掉。这才是用户说的"开一个关一个"。
		var 旧窗 := _场景.get_node_or_null("功能窗口")
		if 旧窗 != null:
			print("截多窗口_烘焙：旧的 `功能窗口` 停在「%s」页，可见=%s —— 三次点击只剩最后点的那个（换页）"
				% [旧窗.get("_current_page"), 旧窗.call("已打开")])
		else:
			print("截多窗口_烘焙：连旧的 `功能窗口` 也没有")
		return
	var 结论: Array[String] = []
	for 页 in 页名们:
		var 窗: Node = 管理.call("取窗口", 页) if 管理 != null else null
		var 开着: bool = 窗 != null and 窗.call("已打开")
		var 标题 := "?"
		var 矩形 := "?"
		if 窗 != null:
			var 标 := 窗.get_node_or_null("遮罩/主窗口/标题") as Label
			var 主 := 窗.get_node_or_null("遮罩/主窗口") as Control
			标题 = 标.text if 标 != null else "?"
			矩形 = str(主.get_global_rect()) if 主 != null else "?"
		结论.append("%s=%s" % [页, "开 标题=%s 矩形=%s" % [标题, 矩形] if 开着 else "**没开**"])
	print("截多窗口_烘焙：", " ｜ ".join(结论))
	if 管理 != null:
		var 同时 := 0
		for 页 in 页名们:
			var 窗: Node = 管理.call("取窗口", 页)
			if 窗 != null and 窗.call("已打开"):
				同时 += 1
		print("截多窗口_烘焙：同时开着 %d / %d 个 —— %s" % [同时, 页名们.size(),
			"✅ 可以同时开" if 同时 == 页名们.size() else "❌ 还是开一个关一个"])
	root.get_texture().get_image().save_png(_出)
	print("截多窗口_烘焙：已存 ", _出)


func _开三个面板() -> void:
	var 底栏 := _场景.get_node_or_null("技能面板/技能栏") as Control
	if 底栏 == null:
		push_error("找不到底栏")
		return
	for 节点 in 底栏.find_children("*", "BaseButton", true, false):
		var 按钮 := 节点 as BaseButton
		if 按钮 == null:
			continue
		if 页名们.has(按钮.tooltip_text):
			按钮.pressed.emit()
			print("截多窗口_烘焙：点了「%s」" % 按钮.tooltip_text)
