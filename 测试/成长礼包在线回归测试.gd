extends SceneTree

## 成长礼包在线回归门（2026-10-20，用户实机报「背包堆了很多等级礼包」）。
##
## 原版真值：服务端**只发第一只** 5 级成长礼包 `11000001`；礼包第 0 格是
## 下一级礼包（11000001→11000002→…→11000020），玩家每开一个才拿到下一个。
## 旧假服务端 `_grant_due_level_gifts` 按 `range(5,101,5)` 每 5 级各发一只，
## 100 级角色一口气收到 20 只，背包直接堆满 —— 这条门钉四件事：
##   ① 登录时只到 **11000001**，11000002..11000020 一件都不该有；
##   ② 开 11000001 ⇒ **获得 2000 金币**（详情窗底部「金币：」那行是礼包内含的奖励，
##      不是开启成本；只有 libao_fufei 的元宝才是成本）并发下一只 11000002；
##   ③ 开 11000002 ⇒ **获得 4000 金币** 并发 11000003（证明链式关系，而不是每级白送）；
##   ④ 两次开包各只扣一只礼包，且不会凭空多出 11000001。
##
## 夹具：`跑在线用例.ps1` 的 `$夹具额外` 用 `--items "3000001:1"` 整张换掉默认背包；
## 成长礼包由服务端登录时的 `GIFT_INFO` 查询（action 21）发放，不靠夹具塞。
## 端口必须与 `$夹具额外` 的 `--port` 同一条数字（§3.180）。
##
## 运行：`powershell -NoProfile -ExecutionPolicy Bypass -File 开发工具/跑在线用例.ps1 -用例 成长礼包`

const 首包 := 11000001
const 次包 := 11000002
const 三包 := 11000003
const 首包价 := 2000
const 次包价 := 4000
const 夹具端口 := 18722
const 游戏数据 := preload("res://脚本/单例/游戏数据.gd")

var _红数 := 0
var _原端口 := -1
var _秒 := 0.0
var _backend: Node
var _会话: Node


func _process(delta: float) -> bool:
	_秒 += delta
	if _秒 > 180.0:
		_红("看门狗超时（180s）—— 中途崩了没走到收尾")
	return false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_backend = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _backend == null or _会话 == null:
		_红("缺单例：BackendConnection=%s GameSession=%s" % [_backend, _会话])
		return
	var 口 := int(OS.get_environment("NARUTO_SERVER_PORT"))
	if 口 == 0:
		口 = 夹具端口
	var 设置: Dictionary = _会话.get("game_settings")
	_原端口 = int(设置.get("backend_port", -1))
	设置["backend_port"] = 口
	print("连夹具端口 %d" % 口)
	_backend.sync_character()
	if not await _等(_进图好了, 15000):
		_红("无法进入真实后端：%s - %s" % [_backend.status, _backend.detail])
		return

	# ① 登录发放：只到首包。给服务端一点时间走 GIFT_INFO:3 → 背包镜像。
	if not await _等(func() -> bool: return _镜像件数(首包) >= 1, 10000):
		_红("登录后镜像里没有 11000001 —— 服务端没发首只成长礼包（或 GIFT_INFO 没被客户端消费）")
		_收尾()
		return
	for 号 in range(11000002, 11000021):
		_查(_镜像件数(号) == 0,
			"登录时背包里已经有 %d（第 %d 只成长礼包）—— 服务端又在按等级逐只发，原版只发 11000001"
				% [号, 号 - 11000000])

	# ② 开首包：获得 2000 金币，拿到 11000002，首包少一只。
	var 金前 := int(_backend.authoritative_stats.get("gold", 0))
	var 首包前 := _镜像件数(首包)
	var 格位 := _格(首包)
	_查(格位 > 0, "镜像里查不到 11000001 的 slot_index（格位 %d）" % 格位)
	if 格位 <= 0:
		_收尾()
		return
	if not bool(_会话.call("use_inventory_slot", 格位)):
		_红("开 11000001 那一发没发出去（在线使用链没接通）")
		_收尾()
		return
	if not await _等(func() -> bool: return _镜像件数(次包) >= 1, 6000):
		_红("开了 11000001 却没收到 11000002 —— 礼包第 0 格的下一只没有进包")
		_收尾()
		return
	_查(_镜像件数(首包) == 首包前 - 1,
		"开 11000001 后它从 %d 只变成 %d 只（一次应只扣一只）" % [首包前, _镜像件数(首包)])
	_查(int(_backend.authoritative_stats.get("gold", 0)) == 金前 + 首包价,
		"开 11000001 后金币 %d → %d，应为 +%d（详情窗「金币：」那行是内含奖励，服务端漏发了）"
			% [金前, int(_backend.authoritative_stats.get("gold", 0)), 首包价])

	# ③ 开次包：获得 4000 金币，拿到 11000003。
	var 次金前 := int(_backend.authoritative_stats.get("gold", 0))
	var 次包前 := _镜像件数(次包)
	var 次格 := _格(次包)
	_查(次格 > 0, "镜像里查不到 11000002 的 slot_index（格位 %d）" % 次格)
	if 次格 <= 0:
		_收尾()
		return
	if not bool(_会话.call("use_inventory_slot", 次格)):
		_红("开 11000002 那一发没发出去")
		_收尾()
		return
	if not await _等(func() -> bool: return _镜像件数(三包) >= 1, 6000):
		_红("开了 11000002 却没收到 11000003 —— 礼包链没有逐级接上")
		_收尾()
		return
	_查(_镜像件数(次包) == 次包前 - 1,
		"开 11000002 后它从 %d 只变成 %d 只（一次应只扣一只）" % [次包前, _镜像件数(次包)])
	_查(int(_backend.authoritative_stats.get("gold", 0)) == 次金前 + 次包价,
		"开 11000002 后金币 %d → %d，应为 +%d"
			% [次金前, int(_backend.authoritative_stats.get("gold", 0)), 次包价])

	# ④ 不会凭空补发首包。
	_查(_镜像件数(首包) == 首包前 - 1,
		"开完礼包后 11000001 又冒出来了（服务端在重复发放首只成长礼包）")
	_收尾()


func _进图好了() -> bool:
	return bool(_backend.in_game) and not _镜像().is_empty()


func _镜像() -> Array:
	return _backend.authoritative_inventory as Array


func _镜像件数(item_id: int) -> int:
	var 总 := 0
	for 件v in _镜像():
		if 件v is Dictionary and int((件v as Dictionary).get("id", 0)) == item_id:
			总 += int((件v as Dictionary).get("quantity", 0))
	return 总


func _格(item_id: int) -> int:
	var 格 := 0
	for 件v in _镜像():
		if 件v is Dictionary and int((件v as Dictionary).get("id", 0)) == item_id:
			格 = int((件v as Dictionary).get("slot_index", 0))
	return 格


func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while not bool(条件.call()) and Time.get_ticks_msec() < 止:
		await create_timer(0.05).timeout
	return bool(条件.call())


func _查(过: bool, 文: String) -> void:
	if not 过:
		_红数 += 1
		print("!! " + 文)


func _红(文: String) -> void:
	_查(false, 文)
	_收尾()


func _收尾() -> void:
	if _原端口 >= 0 and _会话 != null:
		(_会话.get("game_settings") as Dictionary)["backend_port"] = _原端口
		_原端口 = -1
	if _backend != null:
		_backend.call("disconnect_backend")
	if _红数 == 0:
		print("成长礼包在线回归测试：通过（只发 11000001 / 开包得 2000 金币并拿到 11000002 / "
				+ "再开得 4000 金币并拿到 11000003 / 每次只扣一只）")
		quit(0)
	else:
		print("成长礼包在线回归测试：失败 %d 项" % _红数)
		quit(1)
