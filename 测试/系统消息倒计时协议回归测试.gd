extends SceneTree

## 「系统消息」（左侧那列活动倒计时）协议回归。
##
## 对应服务端 tools/fake_flash_server.py:27826 _send_huodong_countdowns()：
##   请求 1809（HUODONG_ACTION）字段 0，
##   回应 "1809:2:<描述>&<剩余秒>@<描述>&<剩余秒>…"。
##
## 跑法（需要夹具服务端）：
##   python 开发工具/本地服务端夹具.py --root ./.fixture --reset \
##     --run "res://测试/系统消息倒计时协议回归测试.gd" --godot "<Godot console exe>"

var _failures: Array[String] = []
var _收到: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	var session := root.get_node_or_null("GameSession")
	if backend == null or session == null:
		_fail("缺少后端连接或游戏会话单例")
		return

	backend.huodong_countdowns_received.connect(func(rows: Array): _收到.append(rows))

	backend.sync_character()
	if not await _等到(func(): return backend.in_game, 10000):
		_fail("未能进入原版后端游戏会话：%s - %s" % [backend.status, backend.detail])
		return

	_收到.clear()
	_check(backend.request_huodong_countdowns(), "倒计时请求应发出")
	if not await _等到(func(): return not _收到.is_empty(), 8000):
		_fail("发 1809:0 后没有收到 1809:2 帧")
		return

	var 行: Array = _收到[-1]
	_check(not 行.is_empty(), "服务端应至少下发一条活动倒计时，实际 0 条")
	if 行.is_empty():
		_结束()
		return

	# 每项都要有描述和非负秒数；描述里应带"还有"这类原文（服务端从 openCDDesc 取）
	var 坏项 := 0
	for 项 in 行:
		if not (项 is Dictionary) or String(项.get("text", "")).is_empty() or int(项.get("seconds", -1)) < 0:
			坏项 += 1
	_check(坏项 == 0, "有 %d 项格式不对（缺描述或秒数为负）" % 坏项)

	# 描述原文应能在语言表里找到出处——防止客户端自己编文案
	var 有还有 := false
	for 项 in 行:
		if String(项.get("text", "")).contains("还有"):
			有还有 = true
	_check(有还有, "倒计时描述里应出现「…还有」，实际样本：%s" % [行.slice(0, 3)])

	# 会话里应存下这份列表（含递减用的基准时刻）
	var 存下: Array = session.活动倒计时
	_check(存下.size() == 行.size(), "会话应存下 %d 条，实际 %d 条" % [行.size(), 存下.size()])
	if not 存下.is_empty():
		_check(存下[0].has("text") and 存下[0].has("seconds") and 存下[0].has("基准毫秒"),
			"会话里的项应含 text/seconds/基准毫秒，实际键 %s" % [存下[0].keys()])

	_检查HUD(行)

	if _failures.is_empty():
		print("系统消息倒计时协议回归测试：通过（%d 条活动倒计时，HUD 渲染一致）" % 行.size())
		quit(0)
		return
	_结束()

## HUD 那一段单独校验：原版的秒数是 "H: M: S" 三段、每段两位左补零、段间 " : "。
func _检查HUD(行: Array) -> void:
	var 场景 := load("res://场景/界面/组件/系统消息.tscn") as PackedScene
	if 场景 == null:
		_fail("系统消息.tscn 加载失败")
		return
	var 节点 := 场景.instantiate()
	if not (节点 is CanvasLayer):
		_fail("系统消息根节点应是 CanvasLayer（原版挂在 layer=110）")
		节点.free()
		return
	_check(int((节点 as CanvasLayer).layer) == 110,
		"系统消息的 CanvasLayer layer 应为 110，实际 %d" % int((节点 as CanvasLayer).layer))
	get_root().add_child(节点)

	var 脚本 = 节点.get_script()
	_check(脚本 != null, "系统消息应有脚本")
	# 格式化：与服务端下发的剩余秒对齐成原版写法
	_check(String(脚本.格式化(89 * 3600 + 5 * 60 + 31)) == "89: 05: 31",
		"格式化(89:05:31) 应为 \"89: 05: 31\"，实际 %s" % String(脚本.格式化(89 * 3600 + 5 * 60 + 31)))
	_check(String(脚本.格式化(0)) == "00: 00: 00", "格式化(0) 应为 \"00: 00: 00\"")

	# 喂真帧数据，检查行数与文字
	var 样本: Array = []
	for i in mini(3, 行.size()):
		样本.append({
			"text": String(行[i].get("text", "")),
			"seconds": int(行[i].get("seconds", 0)),
			"基准毫秒": Time.get_ticks_msec(),
		})
	节点.call("_应用", 样本)
	var 列表 := 节点.get_node_or_null("界面区域/系统消息/消息列表") as Control
	_check(列表 != null, "缺消息列表节点")
	if 列表 != null:
		_check(int(节点.get("可见行数")) == 样本.size(),
			"可见行数应为 %d，实际 %s" % [样本.size(), str(节点.get("可见行数"))])
		var 可见 := 0
		for 子 in 列表.get_children():
			if (子 as Control).visible:
				可见 += 1
		_check(可见 == 样本.size(), "列表里可见的 Label 应为 %d 个，实际 %d" % [样本.size(), 可见])
		if 列表.get_child_count() > 0:
			var 首行 := 列表.get_child(0) as Label
			_check(首行.text.begins_with(String(样本[0].text)),
				"首行应以服务端给的描述原文开头，实际 %s" % 首行.text)
			_check(首行.position.y == 0.0, "首行应排在最上，实际 y=%f" % 首行.position.y)
	节点.queue_free()

func _结束() -> void:
	for failure in _failures:
		push_error(failure)
	quit(1)

func _等到(条件: Callable, 超时毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 超时毫秒
	while Time.get_ticks_msec() < 截止:
		if 条件.call():
			return true
		await create_timer(0.05).timeout
	return 条件.call()

func _check(条件: bool, 消息: String) -> void:
	if not 条件:
		_failures.append(消息)

func _fail(消息: String) -> void:
	_failures.append(消息)
	_结束()
