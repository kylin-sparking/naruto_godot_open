extends SceneTree

## 打开客户端的「忍术」窗口，把 5 个页签各截一张，用来和原版真机截图并排对证。
##
## 走的是 截窗口页.gd 同一条路径：离线地图场景 → 底栏按钮 → 功能窗口 → 页面，
## 所以**不需要起服务端**。切页签走 `_set_skill_tab`（按钮 press 在脚本模式下不生效，
## 原因见 截窗口页.gd 的注释）。
##
## 用法（**不能加 --headless**，无头驱动拿不到视口图像）：
##   Godot --path . --script res://开发工具/截忍术窗口.gd -- --出目录=res://测试/截图/忍术

const 页签 := ["职业忍术", "世界忍术", "其他忍术", "奥义禁术", "特别技能"]

var _出目录 := "res://测试/截图/忍术"
var _帧 := 0
var _场景: Node = null
var _功能窗口: Node = null
var _序号 := 0
var _已就绪 := false
var _截图数 := 0
var _等帧 := 0
var _选中技能 := ""
var _点境界 := false

func _initialize() -> void:
	for 参数 in OS.get_cmdline_user_args():
		var 键值 := 参数.split("=", true, 1)
		if 键值.size() == 2 and 键值[0] == "--出目录":
			_出目录 = 键值[1]
		# 指定选中哪个技能——跟原版同一个技能做 A/B 用
		if 键值.size() == 2 and 键值[0] == "--选中":
			_选中技能 = 键值[1]
		if 参数 == "--点境界":
			_点境界 = true
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
		if not _打开忍术窗口():
			return true
		_已就绪 = true
		if not _选中技能.is_empty():
			# 注意：`_set_skill_tab` 每次都会把 `_selected_skill_id` 清空，
			# 所以要**先切页签、再选中**（走 `_select_skill`，它会重渲染）。
			_功能窗口.call("_set_skill_tab", 0)
			_功能窗口.call("_select_skill", _选中技能)
			_等帧 = 4
		return false
	# 切页签后必须**多等几帧再截图**：`_set_skill_tab` 只是改了状态，
	# 画面要到下一帧才重画，同帧抓图会抓到上一个页签（这个坑踩过——「其他忍术」拍成了「世界忍术」）。
	if _等帧 > 0:
		_等帧 -= 1
		if _等帧 == 0:
			_切页并截图()
		return false
	if _序号 >= 页签.size():
		print("截忍术窗口：共 %d 张，目录 %s" % [_截图数, _出目录])
		quit(0)
		return true
	_功能窗口.call("_set_skill_tab", _序号)
	# 顺手把「忍术境界」也点开截一张（看它有没有正确滑入）
	if _点境界:
		# 离线样例的总忍术层数只有 5，按钮按原版规则是**隐藏**的（要 ≥50）。
		# 所以这里直接展开面板来看它的渲染，跳过"按钮该不该出现"那一步。
		var 面板 := _功能窗口.find_child("境界面板", true, false) as Control
		if 面板 != null:
			面板.visible = true
			面板.position.x = 0.0
			var 详情 := _功能窗口.find_child("忍术详情", true, false) as Control
			if 详情 != null:
				详情.visible = false
	_等帧 = 4
	return false

func _打开忍术窗口() -> bool:
	_功能窗口 = _场景.get_node_or_null("窗口管理").call("取或建窗口", "忍术")
	var 底栏 := _场景.get_node_or_null("技能面板/技能栏") as Control
	if _功能窗口 == null or 底栏 == null:
		push_error("缺少 功能窗口 或 底栏")
		quit(1)
		return false
	for 节点 in 底栏.find_children("*", "BaseButton", true, false):
		var 按钮 := 节点 as BaseButton
		if 按钮 != null and 按钮.tooltip_text == "忍术":
			按钮.pressed.emit()
			if not _选中技能.is_empty():
				# 必须在**渲染之前**把选中定下来；而且定了还要再渲染一次——
				# 按钮 press 那次渲染已经跑完、认的是列表第一条。
				_功能窗口.set("_selected_skill_id", _选中技能)
			print("截忍术窗口：已打开忍术窗口")
			return true
	push_error("底栏没找到 tooltip=忍术 的按钮")
	quit(1)
	return false

func _切页并截图() -> void:
	var 名称: String = 页签[_序号]
	var 图像 := root.get_texture().get_image()
	if 图像 == null:
		push_error("视口图像为空（不能加 --headless）")
		quit(1)
		return
	if not DirAccess.dir_exists_absolute(_出目录):
		DirAccess.make_dir_recursive_absolute(_出目录)
	图像.save_png("%s/%s.png" % [_出目录, 名称])
	# 顺手把窗口内容区与详情区的全局矩形打出来——比对时要用它裁原版真机截图，
	# 靠肉眼看视口图量原点会一直差十几像素。
	var 详情 := _功能窗口.find_child("忍术详情", true, false) as Control
	if 详情 != null:
		var 矩形 := 详情.get_global_rect()
		print("截忍术窗口：%s 详情区全局矩形 x=%d y=%d w=%d h=%d"
			% [名称, int(矩形.position.x), int(矩形.position.y), int(矩形.size.x), int(矩形.size.y)])
	_截图数 += 1
	print("截忍术窗口：已存 %s" % 名称)
	_序号 += 1
