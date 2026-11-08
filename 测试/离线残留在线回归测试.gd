extends SceneTree

## ⭐ 在线门：**进游戏之后，会话里不许再残留离线默认值**。
##
## 为什么要单开一条：离线/在线共用同一套状态，靠 `backend_authoritative` 在零散几处切换行为。
## 哪一处没查标志，离线那一套就**悄悄**进在线会话、**不报错**。到 2026-09-27 已经栽过三次
## （点券恒 0 / 离线编的技能被发出去 / 离线公式盖掉服务端属性），**三次都是用户实机发现的**。
## 判据与说明都在 `游戏会话.离线默认残留()`。
##
## 用法（**必须先起夹具**，见 `开发工具/本地服务端夹具.py`）：
##   Godot --headless --path . --script 测试/离线残留在线回归测试.gd

const MAP_RESOURCES := preload("res://脚本/地图/地图资源.gd")
const OFFLINE_DATA := preload("res://脚本/单例/离线示例数据.gd")

var _失败: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var 后端 := root.get_node_or_null("BackendConnection")
	var 会话 := root.get_node_or_null("GameSession")
	if 后端 == null or 会话 == null:
		_报错("缺少 BackendConnection / GameSession 单例")
		_结束()
		return

	后端.sync_character()
	if not await _等到(func(): return bool(后端.in_game), 10000):
		_报错("未能进入游戏：%s - %s" % [后端.status, 后端.detail])
		_结束()
		return

	# 等"服务端已经把该给的都给了"：属性包与技能包都到齐再判 —— 早判会把"还没收到"当成"漏了"。
	if not await _等到(func(): return not (后端.authoritative_stats as Dictionary).is_empty(), 5000):
		_报错("服务端没有下发属性包（authoritative_stats 为空）")
		_结束()
		return
	if not await _等到(func(): return 会话.backend_authoritative, 5000):
		_报错("会话没有进入权威模式（backend_authoritative 仍为 false）")
		_结束()
		return
	# 再等一拍，让同一批包里的技能/背包也落地。
	await create_timer(1.0).timeout

	print("服务端已给：属性 %d 项 / 技能 %d 项 / 背包 %d 项" % [
		(后端.authoritative_stats as Dictionary).size(),
		(后端.authoritative_skills as Dictionary).size(),
		(后端.authoritative_inventory as Array).size(),
	])
	var 残留: Array = 会话.call("离线默认残留")
	if 残留.is_empty():
		print("会话里没有离线默认值残留")
	else:
		for 项 in 残留:
			_报错("离线残留：" + String(项))

	# ⭐ **反向对照**：新写的守卫必须拿一个"它本该抓住"的样本试一次，否则它可能是个假绿的摆设。
	#    这里**故意注入**一条离线残留（把 mp 改回离线默认值），守卫必须报出来。
	var 默认mp = (OFFLINE_DATA.create().player_stats as Dictionary).get("mp")
	if 会话.player_stats.has("mp") and 默认mp != null:
		var 原值 = 会话.player_stats["mp"]
		会话.player_stats["mp"] = 默认mp
		var 反向: Array = 会话.call("离线默认残留")
		会话.player_stats["mp"] = 原值
		var 抓到了 := false
		for 项 in 反向:
			if "mp" in String(项):
				抓到了 = true
		if 抓到了:
			print("反向对照通过：注入离线 mp=%s 后守卫报出了 %d 条" % [默认mp, 反向.size()])
		else:
			_报错("守卫是假绿的：故意把 mp 改回离线默认值 %s，它一条都没报" % 默认mp)
	_结束()

func _等到(条件: Callable, 毫秒: int) -> bool:
	var 截止 := Time.get_ticks_msec() + 毫秒
	while not 条件.call() and Time.get_ticks_msec() < 截止:
		await create_timer(0.05).timeout
	return bool(条件.call())

func _报错(说明: String) -> void:
	_失败.append(说明)
	push_error(说明)

func _结束() -> void:
	if _失败.is_empty():
		quit(0)
	else:
		print("离线残留在线回归测试：失败 %d 项" % _失败.size())
		quit(1)
