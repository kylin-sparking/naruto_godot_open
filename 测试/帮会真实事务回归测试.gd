extends SceneTree

var _events: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	if backend == null:
		_fail("缺少后端连接单例")
		return
	backend.guild_state_received.connect(func(state: Dictionary): _events.append(state.duplicate(true)))
	backend.sync_character()
	if not await _wait_until(func(): return backend.in_game and int(backend.authoritative_stats.get("gold", -1)) >= 100000, 10000):
		_fail("无法进入已布置金币的真实后端：%s - %s" % [backend.status, backend.detail])
		return

	# 家族名有 2-12 位限制（服务端 create_family 的校验）。原写法 "CodexGuild"+6 位数字
	# 有 16 字符，会被服务端拒绝并回 1552:2:0:0，表现为"没有返回权威家族摘要"。
	var guild_name := "G%d" % (int(Time.get_unix_time_from_system()) % 1000000)
	var gold_before := int(backend.authoritative_stats.get("gold", 0))
	if not backend.request_guild_create(guild_name):
		_fail("创建家族请求未发送")
		return
	if not await _wait_until(func(): return bool(backend.authoritative_guild.get("joined", false)) and String(backend.authoritative_guild.get("name", "")) == guild_name, 5000):
		_fail("服务端未返回创建后的权威家族摘要")
		return
	if int(backend.authoritative_stats.get("gold", 0)) != gold_before - 1000:
		_fail("创建家族没有由服务端准确扣除 1000 金币")
		return
	var guild_id := int(backend.authoritative_guild.get("id", 0))
	var player_name := String(root.get_node("GameSession").player_stats.get("name", ""))
	if guild_id <= 0 or String(backend.authoritative_guild.get("leader", "")) != player_name:
		_fail("创建后的家族编号或族长不正确")
		return

	if not backend.request_guild_list() or not await _wait_until(func(): return _list_contains(guild_id), 4000):
		_fail("服务端家族列表没有包含新建家族")
		return
	if not backend.request_guild_members(guild_id) or not await _wait_until(func(): return _has_member_action(5), 4000):
		_fail("服务端没有返回真实家族成员与贡献")
		return

	# 服务端的家徽升级扣的是**家族资金 666 + 四种家族材料各 1**，不是玩家金币
	# （见 _handle_multiplayer_family 的 action 10），所以先按服务端的规则捐献。
	# 捐献走 action 12：itemId=0 表示捐金币，itemId>0 捐物品。
	var fund_before := int(backend.authoritative_guild.get("fund", 0))
	if not backend.request_guild_donate([
		[0, 666], [16000023, 1], [16000024, 1], [16000025, 1], [16000026, 1],
	]):
		_fail("家族捐献请求未发送")
		return
	if not await _wait_until(func(): return int(backend.authoritative_guild.get("fund", 0)) >= fund_before + 666, 5000):
		_fail("捐献没有进入家族资金")
		return

	var level_before := int(backend.authoritative_guild.get("level", 0))
	fund_before = int(backend.authoritative_guild.get("fund", 0))
	gold_before = int(backend.authoritative_stats.get("gold", 0))
	if not backend.request_guild_upgrade_flag():
		_fail("家徽升级请求未发送")
		return
	if not await _wait_until(func(): return int(backend.authoritative_guild.get("level", 0)) == level_before + 1, 5000):
		_fail("服务端没有持久化家徽升级")
		return
	# 服务端升级后只推家徽标识（action 4），家族资金要再查一次才刷新（资金随 action 5 下发）。
	if not backend.request_guild_members(guild_id):
		_fail("家族成员/资金查询请求未发送")
		return
	# 服务端模型：升级只扣家族资金 666，玩家金币不变。
	if not await _wait_until(func(): return int(backend.authoritative_guild.get("fund", -1)) == fund_before - 666, 5000):
		_fail("家徽升级没有由服务端准确扣除家族资金 666")
		return
	if int(backend.authoritative_stats.get("gold", 0)) != gold_before:
		_fail("家徽升级不应扣玩家金币")
		return

	if not backend.request_guild_boss_state() or not await _wait_until(func(): return _has_action(200), 4000):
		_fail("服务端没有返回尾兽日程")
		return
	if not backend.request_guild_boss_enter():
		_fail("尾兽进入请求未发送")
		return
	if not await _wait_until(func(): return int(backend.authoritative_map_id) == 404000000 and bool(backend.authoritative_guild_boss.get("active", false)), 6000):
		_fail("服务端没有将角色送入真实尾兽地图")
		return
	if backend.map_monsters.is_empty():
		_fail("尾兽地图没有服务端怪物实体")
		return

	if not backend.request_guild_disband():
		_fail("解散家族请求未发送")
		return
	if not await _wait_until(func(): return not bool(backend.authoritative_guild.get("joined", true)), 5000):
		_fail("服务端没有解散家族并清空权威成员状态")
		return

	print("帮会真实事务回归测试：通过（创建扣款、摘要/列表/成员、家徽升级、尾兽地图、解散）")
	backend.disconnect_backend()
	quit(0)

func _list_contains(guild_id: int) -> bool:
	for item in root.get_node("BackendConnection").authoritative_guild_list:
		if int(item.get("id", 0)) == guild_id:
			return true
	return false

func _has_member_action(action: int) -> bool:
	for event in _events:
		if int(event.get("action", -1)) == action and event.get("members") is Array:
			return not (event.get("members") as Array).is_empty()
	return false

func _has_action(action: int) -> bool:
	for event in _events:
		if int(event.get("action", -1)) == action:
			return true
	return false

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return bool(predicate.call())

func _fail(message: String) -> void:
	push_error("帮会真实事务回归测试：失败 - %s" % message)
	quit(1)
