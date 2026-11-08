extends SceneTree

## 「开心有礼」六个子页的**在线链路**。
##
## 为什么单开一条：这一页的协议此前是**两头都错**的 ——
## 客户端发 `1344:90` / `1344:91:<kind>`，而服务端 `handle_gift_query`
## 只认 1/2/11/12/21/31/32/41/42/43/51/62，**没有 90/91**；收包侧又按 90/91 解。
## 于是六子页在线时全是烘死的静态档位，点了没反应。2026-09-27 按 `GiftProcessor.as`
## 的真值重写，这条用例把真值钉住。
##
## 覆盖：五条礼包查询（首次登录/周登录/线上有礼/每日签到/等级）、
##       四条充值活动命令（bootstrap/限时大奖/新服有礼/**首杀礼包**）、
##       以及三条会改存档的动作（领每日签到成功、领首杀礼包发奖、重复领不重发）。
##
## ⚠️ 首杀礼包（2026-10-31 用户口径：原「首日礼包」，条件 = 击杀一只 BOSS）按夹具的
##    `--boss-kills` 分两条腿跑**同一个脚本**：
##      `NW_BOSS_KILLS = 0` ⇒ 验「一只都没杀，领不到、背包不变」；
##      `NW_BOSS_KILLS > 0` ⇒ 验「达标能领、击杀数如实下发、重复点不重发」。
##    为什么非要在线：领奖闸在服务端（`state.activity_boss_kills < 1`），离线门只有假后端。
##
## ⚠️ 每条用例都由夹具在 `--reset` 过的隔离存档上跑，所以"签到从 0 变 1"是可复现的。
## ⚠️ 端口走**独立那一对**（18760 达标 / 18762 未达标）：默认口 18684 是用户自己客户端在连的号，
##    而本用例会领签到、领礼包 —— 连错就是在用户存档上发奖。

## 服务端 `FIRST_DAY_GIFT_ITEM_ID`（`fake_flash_server.py` 的模块级常量，键名保留了旧语义）。
const 首杀礼包物品 := 11_010_041

var _礼包: Dictionary = {}
var _活动: Dictionary = {}
var _会话: Node = null
var _原端口 := -1
var _预期击杀 := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var backend := root.get_node_or_null("BackendConnection")
	if backend == null:
		_fail("缺少 BackendConnection 单例")
		return
	_会话 = root.get_node_or_null("GameSession")
	_预期击杀 = maxi(0, int(OS.get_environment("NW_BOSS_KILLS")))
	# 客户端不会自己读 NARUTO_SERVER_PORT ⇒ 得写进 `game_settings.backend_port`
	# （写法照 `测试/交付后自动弹对话在线回归测试.gd:117-123`），跑完还原。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 18760
	if _会话 != null:
		var 设置: Dictionary = _会话.get("game_settings")
		_原端口 = int(设置.get("backend_port", -1))
		设置["backend_port"] = 口
	print("连夹具端口 %d（夹具 BOSS 击杀数 %d）" % [口, _预期击杀])
	backend.gift_state_received.connect(func(state: Dictionary):
		if state.get("gift") is Dictionary:
			_礼包 = state["gift"]
	)
	backend.czhuodong_state_received.connect(func(state: Dictionary):
		if state.get("czhuodong") is Dictionary:
			_活动 = state["czhuodong"]
	)
	backend.sync_character()
	if not await _等到(backend, "in_game", 12000):
		_收尾(backend)
		_fail("未进入真实游戏会话：%s - %s" % [backend.status, backend.detail])
		return

	var 缺: Array[String] = []

	# ---- 1. 礼包五条查询 ----
	_礼包 = {}
	backend.request_gift_state()
	await _等字段("_礼包", ["first", "weekly", "monthly", "everyday", "level"], 6000)
	for 键 in ["first", "weekly", "monthly", "everyday"]:
		if not (_礼包.get(键) is Dictionary):
			缺.append("1344 缺 %s 状态" % 键)
	if not _礼包.has("level"):
		缺.append("1344 缺 level 状态（1344:3）")
	else:
		var 线: Dictionary = _礼包.get("monthly", {})
		if not 线.has("gainable") or not 线.has("last_week_minutes"):
			缺.append("1344:4 线上有礼四项没解全")
		var 每: Dictionary = _礼包.get("everyday", {})
		if not 每.has("accumulated"):
			缺.append("1344:5 每日签到没解出累计天数")

	# ---- 2. 充值活动四条命令 ----
	_活动 = {}
	backend.request_czhuodong_bootstrap()
	await _等字段("_活动", ["config", "limit", "xinfu", "first_kill"], 6000)
	for 键 in ["config", "limit", "xinfu", "first_kill"]:
		if not (_活动.get(键) is Dictionary):
			缺.append("1814 缺 %s" % 键)

	# ---- 2b. 限时大奖的活动期必须是**本月月初到月末**（用户 2026-10-31 口径）----
	# 只查年月与「首日 00:00:00」「末日 23:59:59」这两端：当月天数由服务端按日历算，
	# 门里再算一遍天数没有意义，反而在大小月/闰月上容易写成两套口径。
	var 限: Dictionary = _活动.get("limit", {}) if _活动.get("limit") is Dictionary else {}
	var 今: Dictionary = Time.get_datetime_dict_from_system()
	var 今月前缀 := "%04d-%02d-" % [int(今.year), int(今.month)]
	var 起 := String(限.get("beginTime", ""))
	var 止 := String(限.get("endTime", ""))
	if not (起.begins_with(今月前缀) and 起.ends_with("-01 00:00:00")):
		缺.append("限时大奖开始时间不是本月月初（%s，应为 %s…-01 00:00:00）" % [起, 今月前缀])
	if not (止.begins_with(今月前缀) and 止.ends_with(" 23:59:59")):
		缺.append("限时大奖结束时间不是本月月末（%s，应为 %s… 23:59:59）" % [止, 今月前缀])

	# ---- 3. 领每日签到：隔离存档上累计天数应从 0 涨到 1 ----
	# ⚠️ 这里**不能**用"等 `everyday` 这个键出现"当条件 —— 第 1 步早就把它填上了，
	#    等待会立刻返回、断言永远看到旧值（第一版就是这么写的，实测报"0 → 0"假红）。
	#    要等的是**值变了**，或者 `1344:7` 那条领取成功帧到了。
	var 领前 := int((_礼包.get("everyday", {}) as Dictionary).get("accumulated", 0))
	_礼包.erase("claim")
	backend.request_gift_claim("daily")
	var 截止 := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < 截止:
		var 每: Dictionary = _礼包.get("everyday", {}) if _礼包.get("everyday") is Dictionary else {}
		if _礼包.has("claim") or int(每.get("accumulated", 0)) > 领前:
			break
		await create_timer(0.05).timeout
	var 领后 := int((_礼包.get("everyday", {}) as Dictionary).get("accumulated", 0))
	if 领后 <= 领前:
		缺.append("领每日签到后累计天数没涨（%d → %d）" % [领前, 领后])

	# ---- 4. 首杀礼包：击杀一只 BOSS 才可领（2026-10-31 替换「建号当天」规则）----
	# 原版这页是首充礼包（`PrizeFirstCZWindow.as:254-267` 看充值额大于 0 才放行）；
	# 充值已按用户口径整条去掉，现在的闸在服务端 `handle_czhuodong` 的 cmd 4 分支：
	# `state.first_charge_claimed or state.activity_boss_kills < 1` ⇒ 只重发状态、不发奖。
	var 首前: Dictionary = _活动.get("first_kill", {}) if _活动.get("first_kill") is Dictionary else {}
	if int(首前.get("bossKills", -1)) != _预期击杀:
		缺.append("1814 cmd 4 的 bossKills 与夹具不符（收到 %s，夹具 %d）⇒ 击杀数没接进状态帧"
			% [首前.get("bossKills", "无此键"), _预期击杀])
	var 包前 := int(backend.inventory_quantity(首杀礼包物品))
	_活动.erase("first_kill")
	backend.request_czhuodong_gain_first_kill()
	await _等到(backend, "_活动有首杀礼包", 4000)
	var 首: Dictionary = _活动.get("first_kill", {}) if _活动.get("first_kill") is Dictionary else {}
	if 首.is_empty():
		缺.append("领首杀礼包后没有收到 1814 cmd 4 回包")
	elif _预期击杀 < 1:
		# 未达标腿：一只 BOSS 都没杀 ⇒ 必须**拒绝**，背包里不许凭空多一份。
		if int(首.get("active", 0)) != 0:
			缺.append("没杀过 BOSS 却领到了首杀礼包（active=%s）" % 首.get("active"))
		var 包后 := int(backend.inventory_quantity(首杀礼包物品))
		if 包后 != 包前:
			缺.append("没杀过 BOSS 却发了奖（%d 号物品 %d → %d）" % [首杀礼包物品, 包前, 包后])
	else:
		# 达标腿：active 翻成 1，背包里多一份；再点一次必须不重发。
		if int(首.get("active", 0)) != 1:
			缺.append("已击杀 %d 只 BOSS 却领不到首杀礼包（active=%s bossKills=%s）" % [
				_预期击杀, 首.get("active"), 首.get("bossKills")])
		if not await _等到物品数(backend, 首杀礼包物品, 包前 + 1, 3000):
			缺.append("领首杀礼包后背包里没多出 %d 号物品（%d → %d）" % [
				首杀礼包物品, 包前, backend.inventory_quantity(首杀礼包物品)])
		var 包达标后 := int(backend.inventory_quantity(首杀礼包物品))
		_活动.erase("first_kill")
		backend.request_czhuodong_gain_first_kill()
		await 等首杀回包(4000)
		var 再: Dictionary = _活动.get("first_kill", {}) if _活动.get("first_kill") is Dictionary else {}
		if int(再.get("active", 0)) != 1:
			缺.append("重复领首杀礼包后状态回退（active=%s）" % 再.get("active"))
		if int(backend.inventory_quantity(首杀礼包物品)) != 包达标后:
			缺.append("重复领首杀礼包又发了一份（%d → %d）" % [
				包达标后, backend.inventory_quantity(首杀礼包物品)])

	_收尾(backend)
	if 缺.is_empty():
		var 首杀结论 := ("首杀礼包：击杀 %d 只可领且不重发" % _预期击杀) if _预期击杀 > 0 else "首杀礼包：0 只时拒绝且不发奖"
		print("福利在线回归测试：通过（礼包五查询 / 充值活动四命令 / 活动期=本月 / 签到推进 / %s）" % 首杀结论)
		quit(0)
		return
	for 项 in 缺:
		push_error("福利在线：%s" % 项)
	print("福利在线回归测试：失败 %d 处 —— %s" % [缺.size(), ", ".join(缺)])
	quit(1)


## 只还原自己动过的那一个键，别顺手整份覆盖 `game_settings`。
func _收尾(backend: Node) -> void:
	if _会话 != null and _原端口 >= 0:
		var 设置: Dictionary = _会话.get("game_settings")
		设置["backend_port"] = _原端口
	backend.disconnect_backend()


## 轮询直到 `_礼包`/`_活动` 里出现全部 `键`，或超时。
func _等字段(_哪个: String, 键: Array, 毫秒: int) -> void:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 截止:
		var 表: Dictionary = _礼包 if _哪个 == "_礼包" else _活动
		var 齐 := true
		for 键名 in 键:
			if not 表.has(键名):
				齐 = false
				break
		if 齐:
			return
		await create_timer(0.05).timeout


## 等 `first_kill` 桶被服务端重新填上（领奖回包就是 cmd 4 状态帧）。
func 等首杀回包(毫秒: int) -> void:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 截止:
		if _活动.get("first_kill") is Dictionary:
			return
		await create_timer(0.05).timeout


## 等背包里某件物品的权威数量达到 `至少`（发奖走变更帧，与状态帧是两条腿，不能当同步）。
func _等到物品数(backend: Node, 物品: int, 至少: int, 毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 截止:
		if int(backend.inventory_quantity(物品)) >= 至少:
			return true
		await create_timer(0.05).timeout
	return false


func _等到(_backend: Node, 什么: String, 毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 截止:
		if 什么 == "in_game":
			if bool(_backend.get("in_game")):
				return true
		elif 什么 == "_活动有首杀礼包":
			if _活动.get("first_kill") is Dictionary:
				return true
		await create_timer(0.05).timeout
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
