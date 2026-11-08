extends SceneTree

## 「自动升级意志在线」门（2026-10-23 §3.188）——用户实机报「点了升级意志没反应」
## （截图：升级槽有件、锁定勾打上、钮亮，点下去画面纹丝不动）。
##
## 真凶两条叠加：
##   ① **客户端**：`自动升级_开` 建了 Timer 却从没 `start()` ⇒ 除了开跑那一下同步跳
##      （状态 0→1），之后再无 tick ⇒ 状态机永远钉在 1、画面不动。`_自动升级_续跑`
##      只在**收到回帧**时才 start，而开局第一跳（openPanel）还没回帧可等 ⇒ 钟哑了。
##      原版 `scheduleNextAutoUpgradeTick` 是 `reset() + start()`（`YiZhiManager:684-691`）。
##   ② **服务端**：`_gain_spirit_from_teacher` 对 `status==0` 的导师硬挡 ⇒ 状态 1 学的
##      导师 4（`AUTO_UPGRADE_TEACHER = 4`，`YiZhiManager.as:32`）永远学不出 ⇒ 空转 8 轮
##      后停「意志商店暂无可学习的意志」。原版自动升级无脑发 4 且功能可用 ⇒ 原版服务端
##      不因 status 挡（status 只管客户端钮显隐与 is_special 分支）⇒ 已照原版去掉。
##
## 本门（在线、真窗、真点）：起真地图 + 真「遗址」窗 → 拖一件进升级槽 → 勾锁定 →
## 点「自动升级意志」⇒ 8 秒内必须：状态机离开 1、导师 4 真学出货（面板涨）、
## 一路走到拾取/喂件（状态 3→4→5/6），且**不许**停在「遇到异常」。
## 对旧代码确定性红：Timer 没 start ⇒ 6 秒后状态仍钉 1、面板不涨。
##
## 由 `bash 测试/跑在线门.sh 自动升级意志在线回归测试.gd` 调。

const 地图资源 := preload("res://脚本/地图/地图资源.gd")

var _会话 = null
var _后端 = null
var _通知: Array[String] = []
var _失败: Array[String] = []
var _受检 := 0


func _initialize() -> void:
	call_deferred("_跑")


func _查(过: bool, 话: String) -> void:
	_受检 += 1
	if not 过:
		_失败.append(话)


func _印(话: String) -> void:
	print("[自动升级] " + 话)


func _等(条件: Callable, 毫秒: int) -> bool:
	var 止 := Time.get_ticks_msec() + 毫秒
	while Time.get_ticks_msec() < 止:
		if bool(条件.call()):
			return true
		await create_timer(0.05).timeout
	return bool(条件.call())


func _跑() -> void:
	root.size = Vector2i(960, 560)
	_后端 = root.get_node_or_null("BackendConnection")
	_会话 = root.get_node_or_null("GameSession")
	if _会话 == null or _后端 == null:
		_停("缺单例")
		return
	var 端口 := OS.get_environment("NARUTO_TEST_PORT")
	if not 端口.is_empty():
		_会话.game_settings["backend_port"] = int(端口)
	_后端.sync_character()
	if not await _等(func(): return bool(_后端.in_game), 25000):
		_停("进不了后端")
		return
	_会话.notification_requested.connect(func(文: String) -> void: _通知.append(文))

	var 场景路径: String = 地图资源.playable_scene_path(String(_会话.current_map_id))
	var 场景 := (load(场景路径) as PackedScene).instantiate()
	root.add_child(场景)
	current_scene = 场景
	for _帧 in range(10):
		await process_frame
	var 管理 := 场景.get_node_or_null("窗口管理")
	if 管理 == null:
		_停("地图场景里没有 窗口管理")
		return
	var 窗: Node = 管理.call("取或建窗口", "遗址")
	if 窗 == null:
		_停("建不出遗址窗")
		return
	窗.call("打开")
	for _帧 in range(40):
		await process_frame

	# —— 拖一件进升级槽（源 = 包里第一件 slot>0）——
	var 源槽 := 0
	for 行 in _会话.spirit_bag:
		var d := 行 as Dictionary
		if int(d.get("slot", 0)) > 0:
			源槽 = int(d.get("slot", 0))
			break
	_印("包内可选源槽=%d（包 %d 件）" % [源槽, _会话.spirit_bag.size()])
	if 源槽 == 0:
		_停("包里没件可拖")
		return
	_印("spirit_move(%d, 0) 返回=%s" % [源槽, str(_会话.spirit_move(源槽, 0))])
	if not await _等(func(): return _找槽(0) != null, 6000):
		_停("升级槽 6 秒没货（move 被挡？）")
		return
	_印("升级槽有货了：%s" % JSON.stringify(_找槽(0)))

	# —— 找页上的勾与钮（页每次重渲都新建 ⇒ 从页面容器末子节点拿）——
	var 页: Node = _页面根(窗)
	var 勾 := _递归找(页, "锁定勾选") as CheckBox
	var 钮 := _递归找(页, "自动升级钮") as BaseButton
	_印("勾=%s 钮=%s" % [str(勾 != null), str(钮 != null)])
	if 勾 == null or 钮 == null:
		_停("页上找不到勾或钮")
		return
	勾.button_pressed = true
	勾.toggled.emit(true)
	for _帧 in range(2):
		await process_frame
	_印("勾后：钮 disabled=%s" % str(钮.disabled))

	# —— 真点（emit；命中测试另说）——
	var 点前: Variant = _会话.get("自动升级跑着")
	_印("点前 跑着=%s 状态=%s" % [str(点前), str(_会话.get("_自动升级状态"))])
	钮.pressed.emit()
	for _帧 in range(2):
		await process_frame
	_印("点后立刻：跑着=%s 状态=%s 提示=%s" % [
		str(_会话.get("自动升级跑着")), str(_会话.get("_自动升级状态")),
		str(_会话.get("自动升级提示"))])
	# —— 观察 8 秒（状态机 0.5s 一跳）——
	var 见过状态 := {}
	var 学出了 := false
	var 面板峰: int = _会话.spirit_panel.size()
	var 异停 := false
	for _秒 in range(8):
		await create_timer(1.0).timeout
		var 态 := int(_会话.get("_自动升级状态"))
		见过状态[态] = true
		if _会话.spirit_panel.size() > 面板峰:
			面板峰 = _会话.spirit_panel.size()
			学出了 = true
		if str(_会话.get("自动升级提示")).contains("遇到异常"):
			异停 = true
		_印("t+%ds：跑着=%s 状态=%d 面板=%d 包=%d limit=%d 空转=%s 等待=%s 提示=%s" % [
			_秒 + 1, str(_会话.get("自动升级跑着")), 态,
			_会话.spirit_panel.size(), _会话.spirit_bag.size(),
			int(_会话.spirit_pack_limit),
			str(_会话.get("_自动升级空转")), str(_会话.get("_自动升级等待跳")),
			str(_会话.get("自动升级提示"))])
	# ⚠️ 不断言「见过状态 2」：状态 2 只活半跳（0.5s），1 秒采样可能整帧错过；
	#    「学出了」已经是"状态 1→2→回帧"走通的证据（回帧推进就发生在 2 上）。
	_查(学出了, "8 秒内导师 4 一件都没学出来（Timer 没 start 或服务端 status 挡？）")
	_查(见过状态.has(3) or 见过状态.has(4) or 见过状态.has(5) or 见过状态.has(6),
			"状态机没走到拾取/喂件段（3/4/5/6 一个都没见过）——钉在 1 就是用户报的「没反应」")
	_查(not 异停, "自动升级异常停了：%s" % str(_会话.get("自动升级提示")))
	_收尾()


func _找槽(槽: int) -> Variant:
	for 表 in [_会话.spirit_bag, _会话.spirit_equipped]:
		for 行 in 表:
			if typeof(行) == TYPE_DICTIONARY and int((行 as Dictionary).get("slot", -999)) == 槽:
				return 行
	return null


func _页面根(窗: Node) -> Node:
	return 窗.get_node_or_null("遮罩/主窗口/页面容器")


func _递归找(n: Node, 名: String) -> Node:
	if n == null:
		return null
	if String(n.name) == 名:
		return n
	for c in n.get_children():
		var 果 := _递归找(c, 名)
		if 果 != null:
			return 果
	return null


func _停(话: String) -> void:
	printerr("自动升级意志在线回归测试：中断 - " + 话)
	quit(1)


func _收尾() -> void:
	if _失败.is_empty():
		print("自动升级意志在线：通过（%d 条断言）" % _受检)
		quit(0)
		return
	for 条 in _失败:
		printerr("自动升级意志在线：" + 条)
	quit(1)
