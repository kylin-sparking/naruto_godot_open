## 真鼠标量具：追踪栏那几行绿字，**用鼠标打上去**到底点不点得动。
## 为什么要它：`追踪栏寻路四修回归测试` 只拿 `_追踪链接点击` 的源码做文本比对，
## 从没把鼠标打到那几个字上 ⇒ "点绿名没反应"这类（用户 2026-10-10 上午又报一次）它照绿。
## 跑法（**不能加 --headless**，无头拿不到视口拾取）：
##   godot --path . --script res://开发工具/量追踪栏点击.gd
extends SceneTree

var 行: Array[String] = []
var 悬停次数 := 0
var 点击次数 := 0
var 出 := "res://测试/截图/追踪栏/真鼠标量具.txt"


func _initialize() -> void:
	call_deferred("_跑")


func _帧(n: int) -> void:
	for i in n:
		await process_frame


func _记(s: String) -> void:
	行.append(s)
	print(s)


func _跑() -> void:
	var 场: Node = (load("res://场景/地图/地图场景.tscn") as PackedScene).instantiate()
	root.add_child(场)
	await _帧(50)
	var 板: Node = 场.find_child("小地图面板", true, false)
	if 板 == null:
		_记("找不到 小地图面板"); _收(); return
	var 列表: VBoxContainer = 板.find_child("任务列表", true, false) as VBoxContainer
	if 列表 == null:
		_记("找不到 任务追踪/任务内容区/任务列表"); _收(); return
	_记("追踪栏行数 = %d" % 列表.get_children().size())
	var 体: RichTextLabel = null
	for 条 in 列表.get_children():
		for 子 in (条 as Node).get_children():
			if 子 is RichTextLabel:
				体 = 子 as RichTextLabel
				break
		if 体 != null:
			break
	if 体 == null:
		_记("行里没有 RichTextLabel（正文行没建出来）"); _收(); return
	_记("正文行 = %s  在树里可见=%s  自身visible=%s" % [体.name, str(体.is_visible_in_tree()), str(体.visible)])
	_记("mouse_filter=%s（0=STOP 才可点、1=IGNORE 不吃鼠标、2=PASS）  全局位=%s  尺寸=%s" % [
			str(体.mouse_filter), str(体.global_position), str(体.size)])
	_记("这一行的 BBCode =%s" % 体.text)
	_记("本行配置 bbcode=%s scroll=%s fit=%s 自动换行=%s" % [
			str(体.bbcode_enabled), str(体.scroll_active), str(体.fit_content), str(体.autowrap_mode)])
	## 最小对照件：同一层、同样 STOP、只放一个 `[url=…]`。它要能悬停/点击，
	## 就说明问题在**这一行自己的配置或排版**，不在量具也不在拾取。
	var 样 := RichTextLabel.new()
	样.bbcode_enabled = true
	样.mouse_filter = Control.MOUSE_FILTER_STOP
	样.size = Vector2(120, 24)
	样.position = Vector2(600, 400)
	样.text = "[url=探针]点我[/url]"
	var 区: Control = 场.find_child("小地图区域", true, false) as Control
	if 区 == null:
		_记("找不到 小地图区域 ⇒ 最小对照件跳过"); 样.free()
	else:
		区.add_child(样)
	var 样悬 := 0
	var 样点 := 0
	样.meta_hover_started.connect(func(_u: String) -> void: 样悬 += 1)
	样.meta_clicked.connect(func(_u: String) -> void: 样点 += 1)
	await _帧(4)
	var 样心 := 样.global_position + 样.size * 0.5
	var 移样 := InputEventMouseMotion.new()
	移样.position = 样心
	移样.global_position = 样心
	root.push_input(移样)
	await _帧(3)
	var 按样 := InputEventMouseButton.new()
	按样.position = 样心
	按样.global_position = 样心
	按样.button_index = MOUSE_BUTTON_LEFT
	按样.pressed = true
	root.push_input(按样)
	await _帧(2)
	按样.pressed = false
	root.push_input(按样)
	await _帧(4)
	_记("最小对照件：拾到=%s 悬停=%d 点击=%d（期望 样 本身 / ≥1 / ≥1）" % [
			str(root.gui_get_hovered_control() == 样), 样悬, 样点])
	样.free()
	# ── 祖先链：谁把鼠标吃掉了，就在这条链上找 ──
	var 父: Node = 体.get_parent()
	var 深 := 0
	while 父 != null and 深 < 14:
		var 信 := "  ↑ %d %s(%s)" % [深, 父.name, 父.get_class()]
		if 父 is Control:
			var c := 父 as Control
			信 += " filter=%s 全局=%s 尺寸=%s 裁=%s" % [
					str(c.mouse_filter), str(c.global_position), str(c.size), str(c.clip_contents)]
		if 父 is CanvasLayer:
			信 += " layer=%d" % (父 as CanvasLayer).layer
		_记(信)
		父 = 父.get_parent()
		深 += 1
	体.meta_hover_started.connect(func(_u: String) -> void: 悬停次数 += 1)
	体.meta_clicked.connect(func(_u: String) -> void: 点击次数 += 1)
	## 谁把鼠标吃了，就把它自己量一遍（全局矩形 + 父链 + filter）。
	var 吃: Node = 场.find_child("RuntimeMinimapCanvas", true, false)
	if 吃 != null:
		var c := 吃 as Control
		_记("小地图画布 全局=%s 尺寸=%s filter=%s 位置=%s" % [
				str(c.global_position), str(c.size), str(c.mouse_filter), str(c.position)])
		var 上: Node = c.get_parent()
		var 层 := 0
		while 上 != null and 层 < 8:
			var 信 := "    ↑ %d %s(%s)" % [层, 上.name, 上.get_class()]
			if 上 is Control:
				信 += " 全局=%s 尺寸=%s" % [str((上 as Control).global_position), str((上 as Control).size)]
			_记(信)
			上 = 上.get_parent()
			层 += 1
	else:
		_记("没有 RuntimeMinimapCanvas")
	# ── 阳性对照：先证明这套打点**能**拾到一样确定可点的东西（页签钮），否则下面全是假阴性 ──
	var 钮: Control = 场.find_child("当前任务页签", true, false) as Control
	if 钮 != null:
		var 钮心 := 钮.global_position + 钮.size * 0.5
		var 移0 := InputEventMouseMotion.new()
		移0.position = 钮心
		移0.global_position = 钮心
		root.push_input(移0)
		await _帧(3)
		var 拾0: Control = root.gui_get_hovered_control()
		_记("阳性对照（页签钮心 %s）视口拾到 = %s(%s) %s" % [
				str(钮心), "(空)" if 拾0 == null else 拾0.name,
				"(空)" if 拾0 == null else 拾0.get_class(),
				"√ 量具可用" if 拾0 == 钮 else "!! 量具自己就不对，下面的结论都别看"])
	# ── 逐点打鼠标：正文行的 2 行文字上各扫 4 个横位 ──
	var 高 := maxf(体.size.y, 8.0)
	for 排 in [0.25, 0.75]:
		for 成 in [0.15, 0.4, 0.65, 0.9]:
			var 点 := 体.global_position + Vector2(体.size.x * 成, 高 * 排)
			var 移 := InputEventMouseMotion.new()
			移.position = 点
			移.global_position = 点
			root.push_input(移)
			await _帧(3)
			var 拾: Control = root.gui_get_hovered_control()
			_记("打点 (%.0f,%.0f) 视口拾到 = %s(%s)  本行被拾=%s  悬停计数=%d" % [
					点.x, 点.y, "(空)" if 拾 == null else 拾.name,
					"(空)" if 拾 == null else 拾.get_class(), str(拾 == 体), 悬停次数])
	# 真点一次（按下 + 抬起）在悬停过的那一点
	var 点 := 体.global_position + Vector2(体.size.x * 0.4, 高 * 0.75)
	var 按 := InputEventMouseButton.new()
	按.global_position = 点
	按.position = 点
	按.button_index = MOUSE_BUTTON_LEFT
	按.pressed = true
	root.push_input(按)
	await _帧(2)
	var 抬 := 按.duplicate() as InputEventMouseButton
	抬.pressed = false
	root.push_input(抬)
	await _帧(4)
	_记("真点一次之后：悬停 %d 次 / meta_clicked %d 次" % [悬停次数, 点击次数])
	var 玩: Node = get_first_node_in_group("player")
	if 玩 != null:
		_记("玩家 click_move_x=%s click_move_y=%s（寻路起来了就不是 0）" % [
				str(玩.get("click_move_x")), str(玩.get("click_move_y"))])
	_记("判读：拾不到本行 ⇒ 有东西盖在上面（看祖先链与 layer）；拾到但悬停 0 ⇒ 那几个字不是 url 区；悬停有、点击 0 ⇒ 按下/抬起被吞")
	_收()


func _收() -> void:
	var f := FileAccess.open(出, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(行) + "\n")
		f.close()
	quit(0)
