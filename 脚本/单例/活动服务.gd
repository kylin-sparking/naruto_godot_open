extends Node

signal activity_changed(state: Dictionary)

const SAVE_PATH := "user://活动数据.json"
const PK_MODES := ["和平", "组队", "家族", "全体"]
# ⚠️ 这里原来还有一张 `REDEEM_CODES`（硬编码的兑换码与奖励）—— 已删：兑换走服务端
#    `request_gift_code`，本地那份只是编的假码表。

var state := {
	"daily_day": -1,
	"last_check_in_day": -1,
	"check_in_streak": 0,
	"benefit_claimed_day": -1,
	"redeemed_codes": [],
	"pk_mode": "和平",
	"mining_attempts": 3,
	"treasure_scrolls": 1,
	"boss_attempts": 1,
	"boss_active": false,
	"ruins_attempts": 1,
	"ruins_remaining": 0,
}

var _session: Node

func _ready() -> void:
	_session = get_node_or_null("/root/GameSession")
	var backend := get_node_or_null("/root/BackendConnection")
	if backend != null and backend.has_signal("gift_state_received"):
		backend.gift_state_received.connect(_on_backend_gift_state)
	_load_state()
	if bool(state.boss_active):
		state.boss_active = false
		state.boss_attempts = mini(1, int(state.boss_attempts) + 1)
	_reset_daily_if_needed()

## 离线（未进入游戏会话）时，服务端权威的操作一律拒绝。
## ⚠️ 别再在这里写"本地兜底奖励" —— 这个文件里原来那 7 条全是编的
## （签到 `20+连签×5`、福利 50/150、挖矿 25/80、藏宝 100/200、首领 400/300、遗址 250/200），
## 而 `游戏逻辑回归测试` 又把它们钉住了 —— 方向是反的（改服务端规则测试不红、改这里测试红）。
## 完整清单见 开发记录（本地） §3.29.6。
## `静默`：打怪路径调的那些（首领完成 / 遗址进度）不要弹提示，否则离线打怪会刷屏。
func _离线拒绝(操作: String, 静默 := false) -> void:
	if not 静默:
		_notify("未连接服务器，「%s」不可用" % 操作)

func check_in() -> bool:
	var backend := _online_backend()
	if backend != null:
		return backend.request_gift_claim("daily")
	_离线拒绝("签到")
	return false

func claim_daily_benefit() -> bool:
	var backend := _online_backend()
	if backend != null:
		return backend.request_gift_claim("benefit")
	_离线拒绝("领取每日福利")
	return false

func redeem_code(code: String) -> bool:
	var backend := _online_backend()
	if backend != null:
		return backend.request_gift_code(code)
	_离线拒绝("礼包兑换")
	return false

func cycle_pk_mode() -> String:
	var index := PK_MODES.find(String(state.pk_mode))
	state.pk_mode = PK_MODES[(index + 1) % PK_MODES.size()]
	_notify("当前战斗状态：%s" % state.pk_mode)
	_commit()
	return String(state.pk_mode)

func mine() -> bool:
	_离线拒绝("挖矿")
	return false

func explore_treasure() -> bool:
	_离线拒绝("藏宝")
	return false

func start_boss_challenge() -> bool:
	_离线拒绝("首领挑战")
	return false

func complete_boss_challenge() -> void:
	# 打怪路径调它 —— 离线时**静默**拒绝，别每杀一只就弹一次提示。
	_离线拒绝("首领挑战结算", true)

func cancel_boss_challenge() -> void:
	_离线拒绝("取消首领挑战", true)

func start_ruins_challenge() -> bool:
	_离线拒绝("遗址探索")
	return false

func progress_ruins() -> void:
	# 打怪路径调它 —— 同上，静默。
	_离线拒绝("遗址探索进度", true)

func _reset_daily_if_needed() -> void:
	var today := _today()
	if int(state.daily_day) == today:
		return
	state.daily_day = today
	state.mining_attempts = 3
	state.treasure_scrolls = 1
	state.boss_attempts = 1
	state.boss_active = false
	state.ruins_attempts = 1
	state.ruins_remaining = 0
	_commit()

func _notify(message: String) -> void:
	if _session != null:
		_session.notification_requested.emit(message)

func _commit() -> void:
	_save_state()
	activity_changed.emit(state.duplicate(true))

func _today() -> int:
	return int(Time.get_unix_time_from_system()) / 86400

func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state, "\t", false))

func _load_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		state.merge(parsed, true)

func _online_backend() -> Node:
	var backend := get_node_or_null("/root/BackendConnection")
	return backend if backend != null and bool(backend.in_game) else null

## 服务端的礼包状态到了 → 折进本地这份 `state`，让「每日签到」页离线/在线读同一处。
## ⚠️ 键名对照是 2026-09-27 按 `GiftProcessor.as` 的真值改的：
##    旧代码读 `daily_streak` / `daily_claimed` / `benefit_claimed` ——
##    那是我们自造的 `1344:90` 帧里的字段，**服务端从不下发**，所以这三个值在线恒为 0/-1。
##    真值是 `1344:5:<今日已领 0/1>:<累计天数>`（`_send_everyday_gift_status`，即"每日签到"）。
func _on_backend_gift_state(payload: Dictionary) -> void:
	var gift: Variant = payload.get("gift")
	if gift is Dictionary:
		var 每日: Variant = (gift as Dictionary).get("everyday")
		if 每日 is Dictionary:
			state["check_in_streak"] = int((每日 as Dictionary).get("accumulated", 0))
			state["last_check_in_day"] = _today() if bool((每日 as Dictionary).get("claimed", false)) else -1
		activity_changed.emit(state.duplicate(true))
	# `1344:7` = 每日礼包领取成功（无载荷，纯信号）；`1344:6` = 兑换码结果。
	var action := int(payload.get("action", -1))
	if action == 7:
		_notify("奖励已到账")
	elif action == 6:
		var code := String((gift as Dictionary).get("code", "")) if gift is Dictionary else ""
		_notify("奖励已到账" if code.is_empty() or code == "-" else _reward_error(code))

func _reward_error(code: String) -> String:
	return {
		"already_claimed": "该奖励已经领取", "invalid_code": "兑换码无效或已过期",
		"backpack_full": "背包空间不足", "level_locked": "等级尚未达到领取条件",
	}.get(code, "奖励领取失败")
