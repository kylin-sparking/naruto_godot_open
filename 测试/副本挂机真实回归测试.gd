extends SceneTree

var _copy_events: Array[Dictionary] = []
var _hang_events: Array[Dictionary] = []
## 1283 回帧（挂机配置）。这一族**只有它有下行**，整条挂机腿的证据都收在这一个字典上。
var _挂配置: Dictionary = {}
## 服务端那两句「自动出售已开启/已关闭」走的下行（`CHAT_MESSAGE` 位置 512 = 头顶黄字飘条）。
## 7779 那一族的证据只能收在这上面 —— 详见下面那段注释（那七个键不在 1283 的回帧里）。
var _通知们: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	if backend == null:
		_fail("缺少后端连接单例")
		return
	backend.copy_state_received.connect(func(state: Dictionary): _copy_events.append(state.duplicate(true)))
	backend.hang_state_received.connect(func(state: Dictionary): _hang_events.append(state.duplicate(true)))
	backend.char_config_received.connect(func(配置: Dictionary): _挂配置 = 配置.duplicate(true))
	## 只收 512 那个位置、发件人「系统」的那几条 ⇒ 玩家聊天/世界公告都不会混进证据里。
	## 用命名函数而不是 lambda：`connect` 的绑定要能看清是哪一个（这条腿以后还要加档）。
	backend.chat_received.connect(_收通知)
	backend.sync_character()
	if not await _wait_until(func(): return backend.in_game, 10000):
		_fail("无法进入真实后端：%s - %s" % [backend.status, backend.detail])
		return

	if not backend.request_copy_history() or not await _wait_until(func(): return _has_copy_action(0), 4000):
		_fail("服务端没有通过 817:0 返回真实副本历史")
		return
	if not backend.request_copy_open(0) or not await _wait_until(func(): return _has_copy_action(1), 4000):
		_fail("服务端没有校验并通过 817:1 返回副本进入倒计时")
		return
	var pending := _last_copy_action(1)
	if int(pending.get("pending_copy_id", -1)) != 0:
		_fail("副本进入回包的 copyId 不正确")
		return
	backend.request_copy_confirm(false)
	if not await _wait_until(func(): return _has_copy_action(6), 4000):
		_fail("取消副本后服务端没有通过 817:6 清理邀请")
		return

	## ── 挂机这一腿的**真契约**（10-18 重写；原来那三条等的是永远不来的回帧）───
	## * `1808` 起/停：原版 `stopGuaJi:735-739` 只派发本地事件、`requestGuaJi` 只有 0/1 两档，
	##   服务端 `handle_hang_action:18326` 也只把 `hang_active` 记一下 ⇒ **整族没有下行**。
	##   以前这里 `request_hang_state()`（发 `"2"`）等一条回帧，等不到就 `_fail` ⇒
	##   那三句"服务端没有确认开始/停止挂机"是**门写错了**，不是服务端坏了。
	## * 有下行的是 `1283`：查询 = 载荷 `0`，服务端回一帧 60 段；保存 = 整个 JSON，逐键覆盖后落存档。
	##   ⇒ 所以"真连服务端跑通"这一腿用 1283 的**写进去再查回来**当证据（这才叫持久化）。
	if not backend.request_hang_config_query() or not await _wait_until(func(): return _挂配置.size() >= 45, 4000):
		_fail("服务端没有用 1283 回帧（查询载荷 = 0；回帧 = 45 值 + keyData + 13 扩展值）")
		return
	var 原血量 := int(_挂配置.get("auotReplyHpValue", 0))
	var 原打坐 := bool(_挂配置.get("autoDaZuo", true))
	var 存: Dictionary = {}
	for 键名 in backend.挂机配置字段:
		存[键名] = _挂配置[键名]
	存["auotReplyHpValue"] = 42
	存["autoDaZuo"] = not 原打坐
	## ⚠ 不发 `keyData`：服务端拿它**整张替换**快捷键表（`handle_char_config:17917-17934`）。
	存.erase("keyData")
	if not backend.request_hang_config_save(存):
		_fail("1283 保存请求没发出去")
		return
	_挂配置.clear()
	if not backend.request_hang_config_query() or not await _wait_until(func(): return _挂配置.size() >= 45, 4000):
		_fail("保存之后重查没有回帧")
		return
	if int(_挂配置.get("auotReplyHpValue", -1)) != 42 or bool(_挂配置.get("autoDaZuo", 原打坐)) == 原打坐:
		_fail("1283 保存没落进服务端存档：血量阈值 %s（要 42）、打坐 %s（要 %s 的反面）" % [
			str(_挂配置.get("auotReplyHpValue")), str(_挂配置.get("autoDaZuo")), str(not 原打坐)])
		return
	## 7779 自动出售。⚠ **这条腿以前拿"1283 查回来"当证据，那条判据是不可达的**
	## （2026-10-18 在线腿就是这么红的：`autoSellEnabled=<null> maxLevel=<null>` —— 红的是门，不是接线）：
	## 服务端确实把七个 `autoSell*` 存进**同一张** character_config
	## （`handle_auto_sell_config:27100-27111`，给 `_run_auto_sell:27124` 的巡检用），
	## 但回帧只按 `CHAR_CONFIG_FIELDS`(45) + `CHAR_CONFIG_EXTENDED_FIELDS`(13) 那 58 段发
	## （`_send_char_config:17801`），这七个键**从来不在里面**；原版客户端也不靠回读，
	## 它把这组值存 `LocalStorageInternal("nyaAutoSell")`（`GuaJiSettingWindow.as:601-636`）。
	## 这条上行**有下行、而且看得见**：`:27116` 走 `_send_system_chat` ⇒ `_send_character_notice`
	## ⇒ `CHAT_MESSAGE:1:512:自动出售已开启。/已关闭。:系统:…` ⇒ 收端 `chat_received`。
	## ⇒ 所以在线证据改成「开与关各收到对应那一句」：它同时证明四个 int 收到了、
	## 位掩码第 0 位被按服务端那条算式解开了（`bool(flags & 0x01)`）。
	_通知们.clear()
	if not backend.request_auto_sell_config(1, 20, 0, 3):
		_fail("7779 自动出售请求没发出去")
		return
	if not await _wait_until(func(): return _有通知("自动出售已开启"), 4000):
		_fail("发了 7779:1 之后没收到「自动出售已开启」，实收到：%s" % str(_通知们))
		return
	_通知们.clear()
	if not backend.request_auto_sell_config(0, 20, 0, 3):
		_fail("7779 关闭那发没发出去")
		return
	if not await _wait_until(func(): return _有通知("自动出售已关闭"), 4000):
		_fail("发了 7779:0 之后没收到「自动出售已关闭」，实收到：%s" % str(_通知们))
		return
	## 1808 两档：只判"发得出去、发完连接没被打断、之后 1283 照样能查"
	## （**不判回帧** —— 原版与服务端都没有这一帧，判了就是把门写成不可达）。
	if not backend.request_hang_start() or not backend.request_hang_stop():
		_fail("1808 起/停没发出去")
		return
	await create_timer(0.4).timeout
	_挂配置.clear()
	if not backend.request_hang_config_query() or not await _wait_until(func(): return _挂配置.size() >= 45, 4000):
		_fail("发过 1808 之后连接/回帧坏了（服务端 handle_hang_action 只记 hang_active，不该有任何副作用）")
		return
	## 还原（**这条用例真改了服务端存档**：1283 那两格 + 自动出售的开关，
	## 否则下一条用例开工时表上还留着这次的值 —— 在线用例之间不许串味）
	var 还原: Dictionary = {}
	for 键名 in backend.挂机配置字段:
		还原[键名] = _挂配置[键名]
	还原["auotReplyHpValue"] = 原血量
	还原["autoDaZuo"] = 原打坐
	## ⚠ 这里**不再往 `还原` 里写 `autoSellEnabled`/`autoSellMaxLevel`**：
	## 服务端 `handle_char_config:17909` 只挑 58 张表里有的键，那两个键发进去是被丢掉的
	## （旧版本这两行是"看着像还原了"的空操作）。自动出售要关只能走 7779，
	## 而这条腿收尾前最后发的那发已经是 `0`（关），服务端侧本来就是关着的状态。
	还原.erase("keyData")
	_挂配置.clear()
	backend.request_hang_config_save(还原)
	await create_timer(0.4).timeout
	if not backend.request_hang_config_query() or not await _wait_until(func(): return _挂配置.size() >= 45, 4000):
		_fail("还原那发 1283 没查到回帧（发出去的那两格会留在服务端存档里）")
		return
	if int(_挂配置.get("auotReplyHpValue", -1)) != 原血量:
		_fail("还原没生效：血量阈值查回来是 %s，要 %d" % [str(_挂配置.get("auotReplyHpValue")), 原血量])
		return

	print("副本挂机真实回归测试：通过（副本历史/进入/取消；1283 写查回来、7779 收到开与关各一句、1808 两档无下行）")
	backend.disconnect_backend()
	quit(0)


## 收服务端那条 512 位置的飘字。发件人固定是「系统」（`_send_character_notice:40421`）。
func _收通知(消息: Dictionary) -> void:
	if int(消息.get("positions", 0)) != 512 or String(消息.get("name", "")) != "系统":
		return
	_通知们.append(String(消息.get("message", "")))


## 服务端那句文案带句号（`自动出售已开启。`），比对只认前缀，别把句号写成承重项。
func _有通知(片段: String) -> bool:
	for 句 in _通知们:
		if 句.contains(片段):
			return true
	return false

func _has_copy_action(action: int) -> bool:
	return not _last_copy_action(action).is_empty()

func _last_copy_action(action: int) -> Dictionary:
	for index in range(_copy_events.size() - 1, -1, -1):
		if int(_copy_events[index].get("action", -1)) == action:
			return _copy_events[index]
	return {}

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return bool(predicate.call())

func _fail(message: String) -> void:
	push_error("副本挂机真实回归测试：失败 - %s" % message)
	quit(1)
