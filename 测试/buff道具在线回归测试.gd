extends SceneTree

## Buff 道具真事务（在线，需夹具 `--items` 预置五件料）。
##
## 为什么必须在线：离线对 buff 族是**明说要在服务端结算、不扣件**（见 `游戏会话.use_inventory_slot`），
## 所以"这些道具到底实装没有"只能由真服务端回答：
##   · `shuxing`（属性药剂）→ `_use_timed_item_effect` → `ATTRIBUTE_ITEM_EFFECT(1433)` + `_send_all_stats`
##     （`fake_flash_server.py:50396`）；攻击力必须真的涨，效果格必须出现；
##   · `shuangbei`（双倍符）→ `DOUBLE_REWARD`（`:48968-48977`），exp/zq 两种 type 要**各占一格**；
##   · `zidong`（生命灵药）→ `_use_auto_consume_item` → `AUTO_CONSUME(1292)`，不是瞬回药。
## 同时钉客户端限时效果的**多实例键**（旧实现按 kind 存，第二种药剂会顶掉第一种的图标）。
##
## 夹具额外参数（`跑在线用例.ps1` 的 $夹具额外）：
##   --items "15003001:2,15003003:1,15002001:1,15002002:1,15004001:1"
##
## 运行：powershell -File 开发工具/跑在线用例.ps1 -用例 buff道具

const 料 := {
	"15003001": "攻击药剂", "15003003": "防御药剂",
	"15002001": "双倍经验符", "15002002": "双倍查克拉精华符",
	"15004001": "生命灵药", "15038001": "守鹤查克拉封印密卷",
}

var _失败: Array[String] = []
var _后端: Node
var _会话: Node
var _原端口 := -1
var _原通知: Array[String] = []


func _initialize() -> void:
	call_deferred("_跑")


func _跑() -> void:
	_后端 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _后端 == null or _会话 == null:
		_失败.append("缺 BackendConnection / GameSession")
		_收尾()
		return
	# ⚠ 客户端只认 game_settings.backend_port，不读环境变量；缺了就红，绝不回落 18684
	#   （18684 是用户自己那台客户端在连的号，§3.183 踩过）。
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 <= 0:
		_失败.append("夹具没给 NARUTO_SERVER_PORT（这条门只能由 跑在线用例.ps1 起）")
		_收尾()
		return
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	_会话.notification_requested.connect(func(文: String) -> void: _原通知.append(文))
	_后端.sync_character()
	if not await _等待(func(): return bool(_后端.in_game), 15000):
		_失败.append("进不了真实后端：%s - %s" % [_后端.status, _后端.detail])
		_收尾()
		return
	# 背包是分块下发的：等五件料都在镜像里再动手（等不到就说清缺哪件）。
	if not await _等待(_料齐, 15000):
		_失败.append("夹具没发齐 buff 道具：%s" % str(_缺料()))
		_收尾()
		return

	var 攻前 := int((_会话.get("player_stats") as Dictionary).get("attack", 0))
	# ── ① 攻击药剂：服务端属性增益 + 效果格 ────────────────────────────────
	_用("15003001")
	if not await _等待(func(): return not _找效果("攻击药剂").is_empty(), 8000):
		_失败.append("用了攻击药剂后增益栏没出现效果（1433 没解析？）")
	else:
		var 攻 := _找效果("攻击药剂")
		_判(int(攻.get("remaining_seconds", 0)) > 0, "攻击药剂剩余时间不是正数")
		_判(String(攻.get("desc", "")).contains("提升"), "攻击药剂效果没带道具描述")
		_判(int(攻.get("received_at_msec", 0)) > 0, "限时效果没留收到时刻")
	if not await _等待(func(): return int((_会话.get("player_stats") as Dictionary).get("attack", 0)) > 攻前, 5000):
		_失败.append("攻击药剂没让服务端属性真的涨（攻 %d → %d）"
			% [攻前, int((_会话.get("player_stats") as Dictionary).get("attack", 0))])

	# ── ② 防御药剂：两种属性药剂**并存**两格 ────────────────────────────────
	_用("15003003")
	if not await _等待(func(): return not _找效果("防御药剂").is_empty(), 8000):
		_失败.append("用了防御药剂后增益栏没出现第二格")
	else:
		_判(not _找效果("攻击药剂").is_empty(),
				"吃第二瓶属性药剂把第一瓶的格子顶掉了（应并存）")

	# ── ③ 两种双倍符：exp / zq 各一格 ───────────────────────────────────────
	_用("15002001")
	if not await _等待(func(): return not _找效果("双倍经验符").is_empty(), 8000):
		_失败.append("双倍经验符没进增益栏（DOUBLE_REWARD 没解析？）")
	_用("15002002")
	if not await _等待(func(): return not _找效果("双倍查克拉精华符").is_empty(), 8000):
		_失败.append("双倍查克拉精华符没进增益栏（两种 type 应各一格）")
	else:
		_判(not _找效果("双倍经验符").is_empty(),
				"第二种双倍符把第一种顶掉了（应按 type 分键）")

	# ── ④ 生命灵药：走自动补给容量（1292），不是瞬回药 ──────────────────────
	_用("15004001")
	if not await _等待(func(): return not _找效果("生命灵药").is_empty(), 8000):
		_失败.append("生命灵药没进增益栏（AUTO_CONSUME 1292 没解析？）")
	else:
		var 灵 := _找效果("生命灵药")
		_判(String(灵.get("kind", "")) == "auto_consume", "生命灵药的效果种类不是 auto_consume")

	# ── ④b 变身密卷：1433 效果格 + 199 换脸回帧 ─────────────────────────────
	# 服务端 `_use_timed_item_effect` 对 bianshen：发 `ATTRIBUTE_ITEM_EFFECT` 后
	# `_send_all_stats()` + `_send_character_look()`（`fake_flash_server.py:17596`）。
	var 换脸 := [0]
	_后端.char_look_changed.connect(func(角色号: int, _性: int, _色: int, 脸: int, _灵: int, _装: String):
		换脸[0] = 脸)
	_用("15038001")
	if not await _等待(func(): return not _找效果("守鹤查克拉封印密卷").is_empty(), 8000):
		_失败.append("变身密卷没进增益栏（1433 没解析？）")
	if not await _等待(func(): return int(换脸[0]) != 0, 5000):
		_失败.append("变身密卷没收到 199 换脸回帧（char_look_changed 的脸仍是 0）")

	# ── ⑤ 背包件数真的扣过（用掉 4 件：攻/防/灵药/变身 各 1）──────────────
	_判(_数量("15003001") == 1, "攻击药剂应从 2 变 1，实为 %d" % _数量("15003001"))
	_判(_数量("15003003") == 0, "防御药剂应从 1 变 0，实为 %d" % _数量("15003003"))
	_判(_数量("15004001") == 0, "生命灵药应从 1 变 0，实为 %d" % _数量("15004001"))
	_判(_数量("15038001") == 0, "变身密卷应从 1 变 0，实为 %d" % _数量("15038001"))

	_收尾()


func _判(条件: bool, 话: String) -> void:
	if not 条件:
		_失败.append(话)


## 背包镜像里按 8 位 id 找格（1 基）；没有返回 0。
func _找格(id: String) -> int:
	var 背: Array = _会话.get("inventory") as Array
	for i in 背.size():
		var 件 = 背[i]
		if 件 is Dictionary and String((件 as Dictionary).get("id", "")).pad_zeros(8) == id.pad_zeros(8):
			return i + 1
	return 0


func _数量(id: String) -> int:
	var 格 := _找格(id)
	if 格 <= 0:
		return 0
	return int((((_会话.get("inventory") as Array)[格 - 1]) as Dictionary).get("quantity", 0))


func _用(id: String) -> void:
	var 格 := _找格(id)
	if 格 <= 0:
		_失败.append("背包里找不到 %s，无法使用" % id)
		return
	if not bool(_会话.call("use_inventory_slot", 格, false)):
		_失败.append("use_inventory_slot(%d, %s) 返回 false" % [格, id])


func _料齐() -> bool:
	for id in 料:
		if _找格(id) <= 0:
			return false
	return true


func _缺料() -> Array[String]:
	var 缺: Array[String] = []
	for id in 料:
		if _找格(id) <= 0:
			缺.append(id)
	return 缺


func _找效果(名: String) -> Dictionary:
	var 列: Array = (_会话.get("hud_state") as Dictionary).get("effects", []) as Array
	for v in 列:
		var 条 := v as Dictionary
		if String(条.get("name", "")) == 名:
			return 条
	return {}


func _等待(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while not 条件.call() and Time.get_ticks_msec() < 止:
		await create_timer(0.05).timeout
	return bool(条件.call())


func _收尾() -> void:
	if _后端 != null:
		_后端.disconnect_backend()
	if _原端口 >= 0 and _会话 != null:
		(_会话.get("game_settings") as Dictionary)["backend_port"] = _原端口
	if _失败.is_empty():
		print("buff道具在线回归测试：通过（属性药剂×2 并存且真涨攻 · 双倍符 exp/zq 各一格 · 灵药走 1292 · 变身 1433+199 · 件数扣减）")
		quit(0)
		return
	for 条 in _失败:
		push_error("buff道具在线回归测试：失败 - %s" % 条)
	print("buff道具在线回归测试：FAIL %d 条" % _失败.size())
	quit(1)
