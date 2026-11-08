extends SceneTree

## 同时打开多个功能面板并截图 —— 验证「每个面板一个独立窗口」这条改造。
##
## 背景：原来只有一个 `功能窗口` 实例、`open_page` 是换页，所以人物/背包/忍术
## **结构上不可能同时开**。改成 `窗口管理`（每页一个实例）后，这里点底栏三个按钮，
## 一次截一张，看它们是不是真的同时在。
##
## 用法（**不能加 --headless**）：
##   Godot --path . --script res://开发工具/截多窗口.gd -- --出=res://测试/截图/多窗口.png

const 页名们 := ["人物", "背包", "忍术"]

var _出 := "res://测试/截图/多窗口.png"
var _场景: Node = null
var _帧 := 0
var _已开 := false
var _待截 := false


func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出":
			_出 = 键值[1]
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
	if not _已开:
		_开三个面板()
		_已开 = true
		return false
	if not _待截:
		_待截 = true     # set 之后要隔一帧才画进视口
		return false
	var 管理 := _场景.get_node_or_null("窗口管理")
	var 报告: Array[String] = []
	for 页 in 页名们:
		var 窗 := 管理.call("取窗口", 页) as Node
		var 主 := 窗.get_node_or_null("遮罩/主窗口") as Control if 窗 != null else null
		var 标题 := (窗.get_node_or_null("遮罩/主窗口/标题") as Label) if 窗 != null else null
		报告.append("%s=%s 标题=%s 矩形=%s" % [页,
			"开" if (窗 != null and 窗.call("已打开")) else "**没开**",
			标题.text if 标题 != null else "?",
			主.get_global_rect() if 主 != null else "?"])
	print("截多窗口：", "，".join(报告))
	root.get_texture().get_image().save_png(_出)
	print("截多窗口：已存 ", _出)
	quit(0)
	return true


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
			print("截多窗口：点了「%s」" % 按钮.tooltip_text)
