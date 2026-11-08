extends SceneTree

var _received := {"gift": false, "exchange": false, "ranking": false, "achievement": false, "activity": false}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	if backend == null:
		_fail("缺少 BackendConnection 单例")
		return
	backend.gift_state_received.connect(func(state: Dictionary):
		if state.has("gift"): _received.gift = true
	)
	backend.exchange_state_received.connect(func(state: Dictionary):
		if state.has("offers"): _received.exchange = true
	)
	# 福袋（1289）这一支**不在这里测**（#74）：原版 `FudaiProcessor` 只有开(1)/开始(2)/领(3)
	# 三支，**没有"查询"这一支** —— 旧代码那个 `request_fudai_state()` 发的 action 0 会被服务端
	# `handle_fudai` 的 `if action != 3: return`（`服务端/runtime/.../fake_flash_server.py:31929`）静默丢掉，
	# 所以这条腿以前是"必红"而非"真测到"。
	# 而 action 1 会从背包**吃掉一枚福袋**、在服务端建一笔持久事务 ⇒ 它不是无副作用的查询，
	# 端到端交给专门的在线用例 `成就福袋`（夹具 `--items 15008001:1`）。
	backend.ranking_state_received.connect(func(state: Dictionary):
		if not (state.get("entries", []) as Array).is_empty(): _received.ranking = true
	)
	backend.achievement_state_received.connect(func(state: Dictionary):
		if state.has("achievements"): _received.achievement = true
	)
	backend.activity_state_received.connect(func(state: Dictionary):
		if state.has("points"): _received.activity = true
	)
	backend.sync_character()
	var deadline := Time.get_ticks_msec() + 10000
	while not backend.in_game and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if not backend.in_game:
		_fail("未进入真实游戏会话：%s - %s" % [backend.status, backend.detail])
		return
	var requests := [
		["gift", Callable(backend, "request_gift_state")],
		["exchange", Callable(backend, "request_exchange_list")],
		["ranking", Callable(backend, "request_ranking").bind(0)],
		["achievement", Callable(backend, "request_achievements").bind(1, 0, 19, 0)],
		["activity", Callable(backend, "request_activity_state")],
	]
	# ⚠️ **一处失败不要立刻 return** —— 原来就是那样，结果这条用例**一直卡在第一个模块 gift**，
	#    后面的 排行/成就/活跃度 **从来没有被验过**。2026-09-25 实测：
	#    排行榜整个坏掉（客户端发 2329，服务端是 1346）却没人发现，就是这条金丝雀死在第一格。
	#    改成把 6 个模块全跑完、一次报全。
	var 缺失: Array[String] = []
	for request in requests:
		var key := String(request[0])
		if not bool((request[1] as Callable).call()):
			缺失.append("%s（请求没发出去）" % key)
			continue
		deadline = Time.get_ticks_msec() + 4000
		while not bool(_received[key]) and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		if not bool(_received[key]):
			缺失.append(key)
	if 缺失.is_empty():
		print("奖励在线查询回归测试：通过（礼包/兑换/排行/成就/活跃度均由真实服务端返回）")
		backend.disconnect_backend()
		quit(0)
		return
	for key in 缺失:
		push_error("真实服务端未返回奖励查询模块：%s" % key)
	print("奖励在线查询回归测试：失败 %d / %d —— 缺 %s" % [缺失.size(), requests.size(), ", ".join(缺失)])
	backend.disconnect_backend()
	quit(1)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
