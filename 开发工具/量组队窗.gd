extends SceneTree
## 组队窗运行期几何探针：宿主外框 / 页面容器 / 队伍窗根 / 底部按钮 / 三枚勾选。
## 跑法：Godot --path . --script res://开发工具/量组队窗.gd （无头即可，只读矩形）

const 管理场景 := "res://场景/界面/窗口管理.tscn"


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	var 会话 := root.get_node_or_null("GameSession")
	if 会话 != null:
		var 设置: Dictionary = 会话.get("game_settings")
		设置["backend_port"] = 18718
	var 管理 := (load(管理场景) as PackedScene).instantiate()
	root.add_child(管理)
	await create_timer(0.3).timeout
	if 管理.has_method("打开"):
		管理.call("打开", "组队")
	await create_timer(0.8).timeout
	var 主窗 := 管理.find_child("主窗口", true, false) as Control
	var 框 := 管理.find_child("窗口边框", true, false) as Control
	var 容器 := 管理.find_child("页面容器", true, false) as Control
	for 项 in [["主窗口", 主窗], ["窗口边框", 框], ["页面容器", 容器]]:
		var c: Control = 项[1]
		if c == null:
			print("%s = null" % 项[0])
			continue
		print("%s  pos=%s size=%s min=%s" % [项[0], c.position, c.size, c.get_combined_minimum_size()])
	var 页 := 管理.find_child("原版组队窗口内容", true, false) as Control
	if 页 == null:
		# 名称被宿主改过也认「我的队伍」的祖先
		页 = 管理.find_child("我的队伍", true, false) as Control
		if 页 != null:
			页 = 页.get_parent()
	print("页根 =", 页.name if 页 != null else "null",
		" pos=", 页.position if 页 != null else Vector2.ZERO,
		" size=", 页.size if 页 != null else Vector2.ZERO,
		" min=", 页.get_combined_minimum_size() if 页 != null else Vector2.ZERO)
	var 我的 := 管理.find_child("我的队伍", true, false) as Control
	print("我的队伍 pos=", 我的.position, " size=", 我的.size)
	print("root.size =", root.size, " 窗口全局 =", (主窗.get_global_rect() if 主窗 != null else Rect2()))
	var 内容区 := 管理.find_child("内容区", true, false) as Control
	print("内容区 local=", 内容区.position if 内容区 != null else Vector2.ZERO,
		" size=", 内容区.size if 内容区 != null else Vector2.ZERO,
		" global=", 内容区.get_global_rect() if 内容区 != null else Rect2())
	for 名 in ["自我退队", "添加成员", "自建队伍", "任命队长", "请离队伍", "查看资料", "修改宣言钮", "宣言输入", "勾选1", "勾选2", "勾选3"]:
		var b := 管理.find_child(名, true, false) as Control
		if b == null:
			print("  %s = null" % 名)
			continue
		print("  %s localpos=%s globalrect=%s vis=%s text=%s" % [名, b.position, b.get_global_rect(), b.visible,
			(b as Button).text if b is Button else (b as CheckBox).text if b is CheckBox else ""])
	for 名 in ["勾选1", "勾选2", "勾选3"]:
		var c := 管理.find_child(名, true, false) as CheckBox
		if c == null:
			print("  %s = null" % 名)
			continue
		print("  %s pos=%s size=%s text=%r" % [名, c.position, c.size, c.text])
	# 面板：看它现在在不在、画成什么样
	var 面板 := 管理.find_child("队伍面板", true, false) as Control
	if 面板 == null:
		var 所有 := 管理.find_children("*", "", true, false)
		for n in 所有:
			if n.get_script() != null and String(n.get_script().resource_path).ends_with("队伍面板.gd"):
				面板 = n as Control
				break
	print("队伍面板 =", 面板.name if 面板 != null else "null",
		" vis=", 面板.visible if 面板 != null else false,
		" pos=", 面板.position if 面板 != null else Vector2.ZERO,
		" size=", 面板.size if 面板 != null else Vector2.ZERO)
	quit(0)
