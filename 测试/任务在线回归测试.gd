extends SceneTree

## 任务窗口的**在线数据链路**。
##
## 为什么单开一条：这条线此前是**断的** —— 后端收到 `444` 只发了一个
## `quest_received` 信号，而**全项目一个消费者都没有**；会话里的
## `accepted_quests` / `available_quests` 一直是最开始那份**离线假任务**。
## 于是任务窗口在线时显示的是"服务端上根本不存在的任务"。
##
## 2026-09-27 接上：`443` 请求两份列表 → `444` action 3/4 → 会话覆盖本地两份 → `quests_changed`。
## 这条用例钉住的就是**"会话里那两份 == 服务端那两份"**。

var _已接: Array = []
var _可接: Array = []
var _列表次数 := 0
## 客户端连哪个口**只认** `game_settings.backend_port`（`后端连接.gd:870`），环境变量它不读。
## 跑批器用 --port 给本用例另起夹具时，不写这一键就会连到用户自己那台 18684、动他的存档（硬规矩①）。
var _会话: Node
var _原端口 := -1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	_会话 = 会话
	if backend == null or 会话 == null:
		_fail("缺少 BackendConnection / GameSession 单例")
		return
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 <= 0:
		_fail("缺 NARUTO_SERVER_PORT（在线用例只许跑在夹具的独立端口上，别连用户的 18684）")
		return
	var 设置: Dictionary = 会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	backend.quest_list_received.connect(func(已接: Array, 可接: Array):
		_已接 = 已接
		_可接 = 可接
		_列表次数 += 1
	)
	backend.sync_character()
	if not await _等进入游戏(backend):
		_fail("未进入真实游戏会话：%s - %s" % [backend.status, backend.detail])
		return

	var 缺: Array[String] = []

	# ---- 1. 请求要**真的发出去** ----
	# ⚠️ 这一条是**反向对照逼出来的**：服务端在进游戏时自己会推一次任务列表
	#    （`_send_original_quest_lists`，登录流程里就发了），所以只断言"列表到了"
	#    的话，把 `request_quest_list()` 整个掏空、用例**照样通过**（实测过）。
	#    必须钉住"443:1 + 443:2 两条请求确实发了"。
	#
	# ⚠️ 这里**不能**用离线门那套 `backend.sent_requests` —— 那是测试替身
	#    `测试/测试后端连接.gd` 才有的记录器，**真 autoload 上没有这个属性**
	#    （第一次就是这么写的，用例直接崩在 exit 3221226505）。
	#    真环境能用的凭据是返回值：`request_quest_list()` 两条都发成功才返回 true。
	if not backend.request_quest_list():
		缺.append("request_quest_list 没有把两条 443 发出去（返回 false）")

	# ---- 2. 两份列表都要回来 ----
	var 起点 := _列表次数
	var 截止 := Time.get_ticks_msec() + 6000
	while _列表次数 < 起点 + 2 and Time.get_ticks_msec() < 截止:
		await create_timer(0.05).timeout
	if _列表次数 < 起点 + 2:
		缺.append("443 的两次请求没有各回一帧 444（本轮只收到 %d 帧）" % (_列表次数 - 起点))
	if _可接.is_empty():
		缺.append("可接任务列表是空的（100 级账号上服务端应筛出很多可接任务）")

	# ---- 3. 会话里那两份必须**等于服务端的**，不能还是离线那套 ----
	await create_timer(0.2).timeout
	var 会话可接: Array = 会话.get("available_quests")
	var 会话已接: Array = 会话.get("accepted_quests")
	var 服务端可接 := {}
	for 条 in _可接:
		服务端可接[String((条 as Dictionary).get("id", ""))] = true
	if 会话可接.size() != _可接.size():
		缺.append("会话的可接任务 %d 条，服务端 %d 条 —— 会话没有跟着服务端走"
			% [会话可接.size(), _可接.size()])
	else:
		for 条 in 会话可接:
			if not 服务端可接.has(String((条 as Dictionary).get("id", ""))):
				缺.append("会话里出现了服务端没有的可接任务：%s" % (条 as Dictionary).get("id", "?"))
				break
	if 会话已接.size() != _已接.size():
		缺.append("会话的已接任务 %d 条，服务端 %d 条" % [会话已接.size(), _已接.size()])

	# ---- 4. NPC 头上的任务标记（`513 UPDATE_NPC_QUEST_STATUS`，§3.118）----
	# 原版这一路：`QuestProcessor.handleUpdateQuestStatusPacket` → `NPCHandler.setNpcStatus`
	#   → `SmallMapHandler.setNpcStatus` → `SmallMapWindow.setNpcStatus`（换那枚 NPC 标记的皮）。
	# ⚠️ 我们以前**完全没接 513**（全工程搜不到这个 opcode），NPC 三态一直是客户端
	#    按任务列表自己推的 —— 环任务（8003-8022 按等级）、护送 8100 的起/终点 NPC 那几档
	#    本地根本推不出来。这条就是盯"513 到底有没有进来、编号对不对"。
	await create_timer(0.3).timeout
	var 态表: Dictionary = backend.get("npc_quest_status")
	if 态表.is_empty():
		缺.append("一条 513 都没收到（后端.npc_quest_status 空）—— 服务端进图就推一轮，收不到说明这条线断着")
	else:
		for 对 in 态表.keys():
			var 值 := int(态表[对])
			if 值 < 0 or 值 > 3:
				缺.append("513 的 status 越界（%d）—— 原版 `NpcQuestStatus` 只有 0/1/2/3" % 值)
				break

	backend.disconnect_backend()
	if 缺.is_empty():
		_还原端口()
		print("任务在线回归测试：通过（443 双请求 / 444 两份列表 / 会话跟随服务端）")
		quit(0)
		return
	for 项 in 缺:
		push_error("任务在线：%s" % 项)
	_还原端口()
	print("任务在线回归测试：失败 %d 处 —— %s" % [缺.size(), ", ".join(缺)])
	quit(1)


func _等进入游戏(backend: Node) -> bool:
	var 截止 := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < 截止:
		if bool(backend.get("in_game")):
			return true
		await create_timer(0.05).timeout
	return false


func _还原端口() -> void:
	if _会话 != null and _原端口 >= 0:
		(_会话.get("game_settings") as Dictionary)["backend_port"] = _原端口
		_原端口 = -1


func _fail(message: String) -> void:
	_还原端口()
	push_error(message)
	quit(1)
