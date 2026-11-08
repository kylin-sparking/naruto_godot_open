extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	var session := root.get_node_or_null("GameSession")
	if backend == null or session == null:
		_finish(false, "缺少后端连接或游戏会话单例")
		return
	var settings: Dictionary = session.game_settings
	if String(settings.get("backend_account", "")) != "a33047518511@gmail.com":
		_finish(false, "客户端没有加载新默认账号")
		return
	if int(settings.get("backend_port", 0)) != 18684:
		_finish(false, "客户端没有加载一键端 TCP 端口")
		return
	backend.sync_character()
	var deadline := Time.get_ticks_msec() + 10000
	while not backend.in_game and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if not backend.in_game:
		_finish(false, "登录失败：%s - %s" % [backend.status, backend.detail])
		return
	if int(backend.character_id) <= 0:
		_finish(false, "后端未返回角色 ID")
		return
	print("默认账号登录回归测试：通过（%s / %s）" % [settings.backend_account, session.player_stats.name])
	backend.disconnect_backend()
	quit(0)

func _finish(success: bool, message: String) -> void:
	if success:
		print(message)
		quit(0)
		return
	push_error("默认账号登录回归测试：%s" % message)
	quit(1)
